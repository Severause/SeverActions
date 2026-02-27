// SeverActionsNative - Teammate Monitor Implementation
// Periodically scans loaded actors for kPlayerTeammate flag changes.
// Fires SKSE mod events for Papyrus to handle instant follower onboarding.
//
// Author: Severause

#include "TeammateMonitor.h"

namespace SeverActionsNative
{
    TeammateMonitor* TeammateMonitor::GetSingleton()
    {
        static TeammateMonitor singleton;
        return &singleton;
    }

    void TeammateMonitor::Initialize()
    {
        if (m_initialized) {
            return;
        }

        // Register for input events (fires every frame - most reliable update mechanism)
        auto* inputDeviceManager = RE::BSInputDeviceManager::GetSingleton();
        if (inputDeviceManager) {
            inputDeviceManager->AddEventSink(this);
            SKSE::log::info("TeammateMonitor: Registered for input events");
        } else {
            SKSE::log::error("TeammateMonitor: Failed to get BSInputDeviceManager");
            return;
        }

        m_lastScanTime = std::chrono::steady_clock::now();
        m_initialized = true;
        SKSE::log::info("TeammateMonitor initialized (scan interval: {}ms)", SCAN_INTERVAL_MS);
    }

    void TeammateMonitor::ClearTracking()
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_knownTeammates.clear();
        SKSE::log::info("TeammateMonitor: Cleared all tracking data");
    }

    // ========================================================================
    // TEAMMATE SCANNING
    // ========================================================================

    void TeammateMonitor::ScanForTeammateChanges()
    {
        if (!m_enabled) {
            return;
        }

        auto* processLists = RE::ProcessLists::GetSingleton();
        if (!processLists) {
            return;
        }

        // Build a set of currently-loaded teammates by scanning high + middle-high actors
        // (these are the actors with active AI processing - the ones near the player)
        std::unordered_set<RE::FormID> currentTeammates;

        auto scanHandles = [&](RE::BSTArray<RE::ActorHandle>& handles) {
            for (auto& handle : handles) {
                auto actorPtr = handle.get();
                if (!actorPtr) {
                    continue;
                }
                auto* actor = actorPtr.get();
                if (!actor || actor->IsPlayerRef()) {
                    continue;
                }
                if (actor->IsPlayerTeammate()) {
                    currentTeammates.insert(actor->GetFormID());
                }
            }
        };

        scanHandles(processLists->highActorHandles);
        scanHandles(processLists->middleHighActorHandles);

        // Compare against our tracked set
        std::lock_guard<std::mutex> lock(m_mutex);

        // Check for new teammates (in current but not in known)
        for (RE::FormID formID : currentTeammates) {
            if (!m_knownTeammates.contains(formID)) {
                // New teammate detected!
                SKSE::log::info("TeammateMonitor: New teammate detected - FormID {:08X}", formID);
                SendTeammateEvent(formID, true);
            }
        }

        // Check for removed teammates (in known but not in current)
        // Only check actors we've tracked - if they're just unloaded (out of range),
        // don't fire removal. We keep them in knownTeammates unless they genuinely
        // lose the teammate flag while loaded.
        std::vector<RE::FormID> toRemove;
        for (RE::FormID formID : m_knownTeammates) {
            // Only fire removal if the actor is currently loaded AND no longer a teammate
            auto* form = RE::TESForm::LookupByID<RE::Actor>(formID);
            if (form && !form->IsPlayerTeammate()) {
                SKSE::log::info("TeammateMonitor: Teammate removed - FormID {:08X}", formID);
                SendTeammateEvent(formID, false);
                toRemove.push_back(formID);
            }
        }

        // Update known set: add all current, remove confirmed removals
        for (RE::FormID formID : currentTeammates) {
            m_knownTeammates.insert(formID);
        }
        for (RE::FormID formID : toRemove) {
            m_knownTeammates.erase(formID);
        }
    }

    void TeammateMonitor::SendTeammateEvent(RE::FormID actorFormID, bool becameTeammate)
    {
        // Dispatch on the game thread for safety
        SKSE::GetTaskInterface()->AddTask([actorFormID, becameTeammate]() {
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(actorFormID);
            if (!actor) {
                SKSE::log::warn("TeammateMonitor: Actor {:08X} no longer exists during event dispatch",
                    actorFormID);
                return;
            }

            auto* eventSource = SKSE::GetModCallbackEventSource();
            if (eventSource) {
                SKSE::ModCallbackEvent modEvent;
                modEvent.eventName = becameTeammate
                    ? "SeverActions_NewTeammateDetected"
                    : "SeverActions_TeammateRemoved";
                modEvent.strArg = "";
                modEvent.numArg = static_cast<float>(actorFormID);
                modEvent.sender = actor;
                eventSource->SendEvent(&modEvent);

                SKSE::log::info("TeammateMonitor: Sent {} event for {} ({:08X})",
                    becameTeammate ? "NewTeammateDetected" : "TeammateRemoved",
                    actor->GetName(), actorFormID);
            } else {
                SKSE::log::warn("TeammateMonitor: Failed to get ModCallbackEventSource");
            }
        });
    }

    // ========================================================================
    // EVENT HANDLER
    // ========================================================================

    RE::BSEventNotifyControl TeammateMonitor::ProcessEvent(
        RE::InputEvent* const*,
        RE::BSTEventSource<RE::InputEvent*>*)
    {
        // Input events fire every frame - use as heartbeat for periodic scans
        OnUpdate();
        return RE::BSEventNotifyControl::kContinue;
    }

    void TeammateMonitor::OnUpdate()
    {
        if (!m_enabled) {
            return;
        }

        // Throttle scans to every SCAN_INTERVAL_MS
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            now - m_lastScanTime).count();
        if (elapsed < SCAN_INTERVAL_MS) {
            return;
        }
        m_lastScanTime = now;

        ScanForTeammateChanges();
    }

    // ========================================================================
    // PAPYRUS WRAPPERS
    // ========================================================================

    void TeammateMonitor::Papyrus_SetEnabled(RE::StaticFunctionTag*, bool enabled)
    {
        GetSingleton()->m_enabled = enabled;
        SKSE::log::info("TeammateMonitor: {} by Papyrus",
            enabled ? "Enabled" : "Disabled");
    }

    bool TeammateMonitor::Papyrus_IsEnabled(RE::StaticFunctionTag*)
    {
        return GetSingleton()->m_enabled;
    }

    int32_t TeammateMonitor::Papyrus_GetTrackedTeammateCount(RE::StaticFunctionTag*)
    {
        std::lock_guard<std::mutex> lock(GetSingleton()->m_mutex);
        return static_cast<int32_t>(GetSingleton()->m_knownTeammates.size());
    }

    void TeammateMonitor::Papyrus_ClearTracking(RE::StaticFunctionTag*)
    {
        GetSingleton()->ClearTracking();
    }

    // ========================================================================
    // PAPYRUS REGISTRATION
    // ========================================================================

    void TeammateMonitor::RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        // Core monitoring
        a_vm->RegisterFunction("TeammateMonitor_SetEnabled", scriptName, Papyrus_SetEnabled);
        a_vm->RegisterFunction("TeammateMonitor_IsEnabled", scriptName, Papyrus_IsEnabled);
        a_vm->RegisterFunction("TeammateMonitor_GetTrackedCount", scriptName, Papyrus_GetTrackedTeammateCount);
        a_vm->RegisterFunction("TeammateMonitor_ClearTracking", scriptName, Papyrus_ClearTracking);

        SKSE::log::info("TeammateMonitor: Registered Papyrus functions (4 core monitoring)");
    }
}
