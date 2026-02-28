#pragma once

// SeverActionsNative - Dialogue Animation Manager
// Plays conversation idle animations on actors using SkyrimNet's
// TalkToPlayer/TalkToNPC dialogue packages. Uses the input event
// loop (same pattern as SandboxManager) to periodically check
// loaded actors' current packages and send animation events.
// Uses vanilla dialogue animation events from Skyrim's behavior graph.
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_map>
#include <mutex>
#include <chrono>
#include <random>

namespace SeverActionsNative
{
    class DialogueAnimManager :
        public RE::BSTEventSink<RE::InputEvent*>
    {
    public:
        static DialogueAnimManager* GetSingleton();

        void Initialize();

        // Event handler (fires every frame - used as heartbeat)
        RE::BSEventNotifyControl ProcessEvent(
            RE::InputEvent* const* a_event,
            RE::BSTEventSource<RE::InputEvent*>* a_eventSource) override;

        void OnUpdate();

        // Papyrus control functions
        static void Papyrus_SetEnabled(RE::StaticFunctionTag*, bool enabled);
        static bool Papyrus_IsEnabled(RE::StaticFunctionTag*);

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName);

    private:
        DialogueAnimManager() = default;
        ~DialogueAnimManager() = default;
        DialogueAnimManager(const DialogueAnimManager&) = delete;
        DialogueAnimManager& operator=(const DialogueAnimManager&) = delete;

        // Resolve SkyrimNet dialogue packages by editor ID (cached after first lookup)
        void CacheDialoguePackages();

        // Check if actor's current package is a dialogue package
        bool IsInDialoguePackage(RE::Actor* actor);

        // Send a random conversation animation to the actor
        void PlayConversationIdle(RE::Actor* actor);

        // Cached dialogue package FormIDs
        RE::FormID m_talkToPlayerPackageID = 0;
        RE::FormID m_talkToNPCPackageID = 0;
        bool m_packagesCached = false;

        // Track which actors are currently animating (to avoid spamming)
        // Maps actor FormID -> time when their current animation expires
        std::unordered_map<RE::FormID, std::chrono::steady_clock::time_point> m_animatingActors;
        mutable std::mutex m_mutex;

        bool m_initialized = false;
        bool m_enabled = true;

        // Timing
        std::chrono::steady_clock::time_point m_lastUpdateTime;
        static constexpr int UPDATE_INTERVAL_MS = 2000;  // Check every 2 seconds

        // Animation duration range (seconds)
        static constexpr float ANIM_DURATION_MIN = 3.0f;
        static constexpr float ANIM_DURATION_MAX = 6.0f;

        // RNG
        std::mt19937 m_rng;

        // Vanilla dialogue animation events from Skyrim's behavior graph
        // Sourced directly from TESIdleForm ENAM fields in Skyrim.esm
        static constexpr const char* DIALOGUE_ANIM_EVENTS[] = {
            "IdleDialogueStart",            // Talking - generic conversation gestures
            "IdleDialogueAngryStart",       // TalkingAngry - angry/assertive gestures
            "IdleDialogueExpressiveStart",  // TalkingExpressive - animated gestures
            "IdleDialogueHappyStart"        // TalkingHappy - happy/friendly gestures
        };
        static constexpr size_t NUM_DIALOGUE_ANIMS = 4;
    };
}
