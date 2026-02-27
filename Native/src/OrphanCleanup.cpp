// SeverActionsNative - Orphan Package Cleanup Implementation
// Periodically scans loaded actors for orphaned SeverActions LinkedRef keywords.
// Fires SKSE mod events for Papyrus to handle package removal and LinkedRef clearing.
//
// Author: Severause

#include "OrphanCleanup.h"
#include "FurnitureManager.h"

namespace SeverActionsNative
{
    OrphanCleanup* OrphanCleanup::GetSingleton()
    {
        static OrphanCleanup singleton;
        return &singleton;
    }

    void OrphanCleanup::Initialize()
    {
        if (m_initialized) {
            return;
        }

        auto* inputDeviceManager = RE::BSInputDeviceManager::GetSingleton();
        if (inputDeviceManager) {
            inputDeviceManager->AddEventSink(this);
            SKSE::log::info("OrphanCleanup: Registered for input events");
        } else {
            SKSE::log::error("OrphanCleanup: Failed to get BSInputDeviceManager");
            return;
        }

        m_lastScanTime = std::chrono::steady_clock::now();
        m_initialized = true;
        SKSE::log::info("OrphanCleanup initialized (scan interval: {}ms)", SCAN_INTERVAL_MS);
    }

    void OrphanCleanup::ClearTracking()
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_trackedTravelers.clear();
        m_trackedFollowers.clear();
        SKSE::log::info("OrphanCleanup: Cleared all tracking data");
    }

    // ========================================================================
    // KEYWORD REGISTRATION
    // ========================================================================

    void OrphanCleanup::SetKeywords(RE::BGSKeyword* travelKW, RE::BGSKeyword* furnitureKW, RE::BGSKeyword* followKW)
    {
        m_travelKeywordID = travelKW ? travelKW->GetFormID() : 0;
        m_furnitureKeywordID = furnitureKW ? furnitureKW->GetFormID() : 0;
        m_followKeywordID = followKW ? followKW->GetFormID() : 0;
        m_keywordsSet = (m_travelKeywordID != 0 || m_furnitureKeywordID != 0 || m_followKeywordID != 0);

        SKSE::log::info("OrphanCleanup: Keywords set — travel:{:08X} furniture:{:08X} follow:{:08X}",
            m_travelKeywordID, m_furnitureKeywordID, m_followKeywordID);
    }

    // ========================================================================
    // TRACKING REGISTRATION
    // ========================================================================

    void OrphanCleanup::RegisterTraveler(RE::Actor* actor)
    {
        if (!actor) return;
        std::lock_guard<std::mutex> lock(m_mutex);
        m_trackedTravelers.insert(actor->GetFormID());
    }

    void OrphanCleanup::UnregisterTraveler(RE::Actor* actor)
    {
        if (!actor) return;
        std::lock_guard<std::mutex> lock(m_mutex);
        m_trackedTravelers.erase(actor->GetFormID());
    }

    void OrphanCleanup::RegisterFollower(RE::Actor* actor)
    {
        if (!actor) return;
        std::lock_guard<std::mutex> lock(m_mutex);
        m_trackedFollowers.insert(actor->GetFormID());
    }

    void OrphanCleanup::UnregisterFollower(RE::Actor* actor)
    {
        if (!actor) return;
        std::lock_guard<std::mutex> lock(m_mutex);
        m_trackedFollowers.erase(actor->GetFormID());
    }

    // ========================================================================
    // ORPHAN SCANNING
    // ========================================================================

    void OrphanCleanup::ScanForOrphans()
    {
        if (!m_enabled || !m_keywordsSet) {
            return;
        }

        auto* processLists = RE::ProcessLists::GetSingleton();
        if (!processLists) {
            return;
        }

        // Cache keyword lookups
        RE::BGSKeyword* travelKW = m_travelKeywordID ?
            RE::TESForm::LookupByID<RE::BGSKeyword>(m_travelKeywordID) : nullptr;
        RE::BGSKeyword* furnitureKW = m_furnitureKeywordID ?
            RE::TESForm::LookupByID<RE::BGSKeyword>(m_furnitureKeywordID) : nullptr;
        RE::BGSKeyword* followKW = m_followKeywordID ?
            RE::TESForm::LookupByID<RE::BGSKeyword>(m_followKeywordID) : nullptr;

        // Take a snapshot of tracked sets under lock
        std::unordered_set<RE::FormID> travelers;
        std::unordered_set<RE::FormID> followers;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            travelers = m_trackedTravelers;
            followers = m_trackedFollowers;
        }

        auto scanHandles = [&](RE::BSTArray<RE::ActorHandle>& handles) {
            for (auto& handle : handles) {
                auto actorPtr = handle.get();
                if (!actorPtr) {
                    continue;
                }
                auto* actor = actorPtr.get();
                if (!actor || actor->IsPlayerRef() || actor->IsDead()) {
                    continue;
                }

                RE::FormID formID = actor->GetFormID();

                // --- TRAVEL orphan check ---
                if (travelKW) {
                    auto* linkedRef = actor->GetLinkedRef(travelKW);
                    if (linkedRef && !travelers.contains(formID)) {
                        SKSE::log::info("OrphanCleanup: Travel orphan detected — {} ({:08X})",
                            actor->GetName(), formID);
                        SendCleanupEvent(formID, "travel");
                    }
                }

                // --- FURNITURE orphan check ---
                if (furnitureKW) {
                    auto* linkedRef = actor->GetLinkedRef(furnitureKW);
                    if (linkedRef) {
                        auto* furnMgr = FurnitureManager::GetSingleton();
                        if (furnMgr && !furnMgr->IsRegistered(actor)) {
                            SKSE::log::info("OrphanCleanup: Furniture orphan detected — {} ({:08X})",
                                actor->GetName(), formID);
                            SendCleanupEvent(formID, "furniture");
                        }
                    }
                }

                // --- FOLLOW orphan check ---
                if (followKW) {
                    auto* linkedRef = actor->GetLinkedRef(followKW);
                    if (linkedRef && !followers.contains(formID)) {
                        SKSE::log::info("OrphanCleanup: Follow orphan detected — {} ({:08X})",
                            actor->GetName(), formID);
                        SendCleanupEvent(formID, "follow");
                    }
                }
            }
        };

        scanHandles(processLists->highActorHandles);
        scanHandles(processLists->middleHighActorHandles);
    }

    void OrphanCleanup::SendCleanupEvent(RE::FormID actorFormID, const char* keywordType)
    {
        std::string kwType(keywordType);

        SKSE::GetTaskInterface()->AddTask([actorFormID, kwType]() {
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(actorFormID);
            if (!actor) {
                SKSE::log::warn("OrphanCleanup: Actor {:08X} no longer exists during cleanup dispatch",
                    actorFormID);
                return;
            }

            auto* eventSource = SKSE::GetModCallbackEventSource();
            if (eventSource) {
                SKSE::ModCallbackEvent modEvent;
                modEvent.eventName = "SeverActions_OrphanCleanup";
                modEvent.strArg = kwType;
                modEvent.numArg = static_cast<float>(actorFormID);
                modEvent.sender = actor;
                eventSource->SendEvent(&modEvent);

                SKSE::log::info("OrphanCleanup: Sent cleanup event for {} ({:08X}) type={}",
                    actor->GetName(), actorFormID, kwType);
            }
        });
    }

    // ========================================================================
    // EVENT HANDLER
    // ========================================================================

    RE::BSEventNotifyControl OrphanCleanup::ProcessEvent(
        RE::InputEvent* const*,
        RE::BSTEventSource<RE::InputEvent*>*)
    {
        OnUpdate();
        return RE::BSEventNotifyControl::kContinue;
    }

    void OrphanCleanup::OnUpdate()
    {
        if (!m_enabled || !m_keywordsSet) {
            return;
        }

        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            now - m_lastScanTime).count();
        if (elapsed < SCAN_INTERVAL_MS) {
            return;
        }
        m_lastScanTime = now;

        ScanForOrphans();
    }

    // ========================================================================
    // PAPYRUS WRAPPERS
    // ========================================================================

    void OrphanCleanup::Papyrus_Initialize(RE::StaticFunctionTag*,
        RE::BGSKeyword* travelKW, RE::BGSKeyword* furnitureKW, RE::BGSKeyword* followKW)
    {
        GetSingleton()->SetKeywords(travelKW, furnitureKW, followKW);
    }

    void OrphanCleanup::Papyrus_RegisterTraveler(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        GetSingleton()->RegisterTraveler(actor);
    }

    void OrphanCleanup::Papyrus_UnregisterTraveler(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        GetSingleton()->UnregisterTraveler(actor);
    }

    void OrphanCleanup::Papyrus_RegisterFollower(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        GetSingleton()->RegisterFollower(actor);
    }

    void OrphanCleanup::Papyrus_UnregisterFollower(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        GetSingleton()->UnregisterFollower(actor);
    }

    void OrphanCleanup::Papyrus_SetEnabled(RE::StaticFunctionTag*, bool enabled)
    {
        GetSingleton()->m_enabled = enabled;
        SKSE::log::info("OrphanCleanup: {} by Papyrus", enabled ? "Enabled" : "Disabled");
    }

    bool OrphanCleanup::Papyrus_IsEnabled(RE::StaticFunctionTag*)
    {
        return GetSingleton()->m_enabled;
    }

    void OrphanCleanup::Papyrus_ClearTracking(RE::StaticFunctionTag*)
    {
        GetSingleton()->ClearTracking();
    }

    // ========================================================================
    // PAPYRUS REGISTRATION
    // ========================================================================

    void OrphanCleanup::RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        a_vm->RegisterFunction("OrphanCleanup_Initialize", scriptName, Papyrus_Initialize);
        a_vm->RegisterFunction("OrphanCleanup_RegisterTraveler", scriptName, Papyrus_RegisterTraveler);
        a_vm->RegisterFunction("OrphanCleanup_UnregisterTraveler", scriptName, Papyrus_UnregisterTraveler);
        a_vm->RegisterFunction("OrphanCleanup_RegisterFollower", scriptName, Papyrus_RegisterFollower);
        a_vm->RegisterFunction("OrphanCleanup_UnregisterFollower", scriptName, Papyrus_UnregisterFollower);
        a_vm->RegisterFunction("OrphanCleanup_SetEnabled", scriptName, Papyrus_SetEnabled);
        a_vm->RegisterFunction("OrphanCleanup_IsEnabled", scriptName, Papyrus_IsEnabled);
        a_vm->RegisterFunction("OrphanCleanup_ClearTracking", scriptName, Papyrus_ClearTracking);

        SKSE::log::info("OrphanCleanup: Registered Papyrus functions (8 functions)");
    }
}
