// SeverActionsNative - Dialogue Animation Manager Implementation
// Author: Severause

#include "DialogueAnimManager.h"

namespace SeverActionsNative
{
    DialogueAnimManager* DialogueAnimManager::GetSingleton()
    {
        static DialogueAnimManager singleton;
        return &singleton;
    }

    void DialogueAnimManager::Initialize()
    {
        if (m_initialized) {
            return;
        }

        // Seed RNG
        m_rng.seed(static_cast<unsigned int>(
            std::chrono::steady_clock::now().time_since_epoch().count()));

        // Register for input events (fires every frame - heartbeat)
        auto* inputDeviceManager = RE::BSInputDeviceManager::GetSingleton();
        if (inputDeviceManager) {
            inputDeviceManager->AddEventSink(this);
            SKSE::log::info("DialogueAnimManager: Registered for input events");
        }

        SKSE::log::info("DialogueAnimManager: Using {} vanilla dialogue animation events", NUM_DIALOGUE_ANIMS);
        for (size_t i = 0; i < NUM_DIALOGUE_ANIMS; ++i) {
            SKSE::log::info("DialogueAnimManager:   [{}] {}", i, DIALOGUE_ANIM_EVENTS[i]);
        }

        m_lastUpdateTime = std::chrono::steady_clock::now();
        m_initialized = true;
        SKSE::log::info("DialogueAnimManager initialized");
    }

    void DialogueAnimManager::CacheDialoguePackages()
    {
        if (m_packagesCached) {
            return;
        }

        // Look up SkyrimNet's dialogue packages by editor ID
        auto* talkToPlayer = RE::TESForm::LookupByEditorID<RE::TESPackage>("SkyrimNet_PlayerDialoguePackage");
        if (talkToPlayer) {
            m_talkToPlayerPackageID = talkToPlayer->GetFormID();
            SKSE::log::info("DialogueAnimManager: Cached TalkToPlayer package {:X}", m_talkToPlayerPackageID);
        } else {
            SKSE::log::warn("DialogueAnimManager: Could not find SkyrimNet_PlayerDialoguePackage - is SkyrimNet installed?");
        }

        auto* talkToNPC = RE::TESForm::LookupByEditorID<RE::TESPackage>("SkyrimNet_NPCDialoguePackage");
        if (talkToNPC) {
            m_talkToNPCPackageID = talkToNPC->GetFormID();
            SKSE::log::info("DialogueAnimManager: Cached TalkToNPC package {:X}", m_talkToNPCPackageID);
        } else {
            SKSE::log::warn("DialogueAnimManager: Could not find SkyrimNet_NPCDialoguePackage");
        }

        m_packagesCached = true;
    }

    bool DialogueAnimManager::IsInDialoguePackage(RE::Actor* actor)
    {
        if (!actor) {
            return false;
        }

        auto* currentPackage = actor->GetCurrentPackage();
        if (!currentPackage) {
            return false;
        }

        RE::FormID packageID = currentPackage->GetFormID();
        return (packageID == m_talkToPlayerPackageID && m_talkToPlayerPackageID != 0) ||
               (packageID == m_talkToNPCPackageID && m_talkToNPCPackageID != 0);
    }

    void DialogueAnimManager::PlayConversationIdle(RE::Actor* actor)
    {
        if (!actor || !actor->Is3DLoaded()) {
            return;
        }

        // Don't animate if in combat or dead
        if (actor->IsInCombat() || actor->IsDead()) {
            return;
        }

        // Pick a random dialogue animation event
        std::uniform_int_distribution<size_t> animDist(0, NUM_DIALOGUE_ANIMS - 1);
        size_t index = animDist(m_rng);
        RE::BSFixedString animEvent(DIALOGUE_ANIM_EVENTS[index]);

        // Send the animation event via the behavior graph
        actor->NotifyAnimationGraph(animEvent);

        SKSE::log::trace("DialogueAnimManager: Playing '{}' on actor {:X}",
            DIALOGUE_ANIM_EVENTS[index], actor->GetFormID());
    }

    RE::BSEventNotifyControl DialogueAnimManager::ProcessEvent(
        RE::InputEvent* const*,
        RE::BSTEventSource<RE::InputEvent*>*)
    {
        OnUpdate();
        return RE::BSEventNotifyControl::kContinue;
    }

    void DialogueAnimManager::OnUpdate()
    {
        if (!m_enabled) {
            return;
        }

        // Throttle to every UPDATE_INTERVAL_MS
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            now - m_lastUpdateTime).count();
        if (elapsed < UPDATE_INTERVAL_MS) {
            return;
        }
        m_lastUpdateTime = now;

        // Cache packages on first real update (forms are loaded by now)
        CacheDialoguePackages();

        // Skip if we couldn't find either package
        if (m_talkToPlayerPackageID == 0 && m_talkToNPCPackageID == 0) {
            return;
        }

        // Dispatch the actual work to the game thread
        SKSE::GetTaskInterface()->AddTask([this, now]() {
            auto* processLists = RE::ProcessLists::GetSingleton();
            if (!processLists) {
                return;
            }

            std::lock_guard<std::mutex> lock(m_mutex);

            // Clean up expired animation entries
            for (auto it = m_animatingActors.begin(); it != m_animatingActors.end(); ) {
                if (now >= it->second) {
                    it = m_animatingActors.erase(it);
                } else {
                    ++it;
                }
            }

            // Iterate loaded (high-process) actors
            for (auto& handle : processLists->highActorHandles) {
                auto actorPtr = handle.get();
                if (!actorPtr) {
                    continue;
                }

                auto* actor = actorPtr.get();
                if (!actor || !actor->Is3DLoaded()) {
                    continue;
                }

                // Check if actor is running a dialogue package
                if (!IsInDialoguePackage(actor)) {
                    // If they were animating but no longer in dialogue, clean up tracking
                    RE::FormID actorID = actor->GetFormID();
                    if (m_animatingActors.contains(actorID)) {
                        m_animatingActors.erase(actorID);
                    }
                    continue;
                }

                RE::FormID actorID = actor->GetFormID();

                // Skip if already animating (not expired yet)
                if (m_animatingActors.contains(actorID) && now < m_animatingActors[actorID]) {
                    continue;
                }

                // Play a conversation idle
                PlayConversationIdle(actor);

                // Set expiry so we don't spam animations
                std::uniform_real_distribution<float> durationDist(ANIM_DURATION_MIN, ANIM_DURATION_MAX);
                float duration = durationDist(m_rng);
                m_animatingActors[actorID] = now + std::chrono::milliseconds(
                    static_cast<int>(duration * 1000.0f));
            }
        });
    }

    // ========================================================================
    // PAPYRUS NATIVE FUNCTION WRAPPERS
    // ========================================================================

    void DialogueAnimManager::Papyrus_SetEnabled(RE::StaticFunctionTag*, bool enabled)
    {
        GetSingleton()->m_enabled = enabled;
        SKSE::log::info("DialogueAnimManager: {}", enabled ? "Enabled" : "Disabled");
    }

    bool DialogueAnimManager::Papyrus_IsEnabled(RE::StaticFunctionTag*)
    {
        return GetSingleton()->m_enabled;
    }

    void DialogueAnimManager::RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        a_vm->RegisterFunction("SetDialogueAnimEnabled", scriptName, Papyrus_SetEnabled);
        a_vm->RegisterFunction("IsDialogueAnimEnabled", scriptName, Papyrus_IsEnabled);

        SKSE::log::info("Registered DialogueAnimManager Papyrus functions");
    }
}
