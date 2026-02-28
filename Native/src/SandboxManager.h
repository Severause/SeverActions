#pragma once

// SeverActionsNative - Sandbox Manager
// Handles automatic package cleanup for sandboxing actors
// - Auto-removes package when player changes cells
// - Auto-removes package when player moves away (distance threshold)
// - Separate from FurnitureManager to avoid event conflicts
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_map>
#include <mutex>
#include <chrono>

namespace SeverActionsNative
{
    struct SandboxUserData
    {
        RE::FormID actorFormID;
        RE::FormID packageFormID;
        float autoStandDistance;
        RE::FormID registeredCellFormID;  // Cell they were in when registered
    };

    /**
     * SandboxManager - Native sandbox package management
     *
     * Mirrors FurnitureManager but for sandbox packages:
     * 1. Hooks player cell change events
     * 2. Uses periodic updates via input events (fires frequently)
     * 3. Checks distances every ~500ms during gameplay
     *
     * When player leaves cell or moves too far:
     * - Sends "SeverActionsNative_SandboxCleanup" mod event
     * - Papyrus handler removes package and resumes follow AI
     */
    class SandboxManager :
        public RE::BSTEventSink<RE::TESCellFullyLoadedEvent>,
        public RE::BSTEventSink<RE::TESCellAttachDetachEvent>,
        public RE::BSTEventSink<RE::InputEvent*>
    {
    public:
        static SandboxManager* GetSingleton();

        // Initialize event sinks
        void Initialize();

        // Register an actor as sandboxing
        bool RegisterSandboxUser(
            RE::Actor* actor,
            RE::TESPackage* package,
            float autoStandDistance = 2000.0f
        );

        // Unregister an actor (call when sandbox is stopped normally)
        void UnregisterSandboxUser(RE::Actor* actor);

        // Force all registered actors to stop sandboxing (e.g., on cell change)
        void ForceAllStopSandbox();

        // Check if an actor is registered
        bool IsRegistered(RE::Actor* actor);

        // Get registered count
        int32_t GetRegisteredCount();

        // Process distance checks for all registered actors
        void ProcessDistanceChecks();

        // Event handlers
        RE::BSEventNotifyControl ProcessEvent(
            const RE::TESCellFullyLoadedEvent* a_event,
            RE::BSTEventSource<RE::TESCellFullyLoadedEvent>* a_eventSource) override;

        RE::BSEventNotifyControl ProcessEvent(
            const RE::TESCellAttachDetachEvent* a_event,
            RE::BSTEventSource<RE::TESCellAttachDetachEvent>* a_eventSource) override;

        RE::BSEventNotifyControl ProcessEvent(
            RE::InputEvent* const* a_event,
            RE::BSTEventSource<RE::InputEvent*>* a_eventSource) override;

        // Called from game update hook
        void OnUpdate();

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static bool Papyrus_RegisterSandboxUser(
            RE::StaticFunctionTag*,
            RE::Actor* actor,
            RE::TESPackage* package,
            float autoStandDistance
        );

        static void Papyrus_UnregisterSandboxUser(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_ForceAllStopSandbox(RE::StaticFunctionTag*);
        static bool Papyrus_IsRegistered(RE::StaticFunctionTag*, RE::Actor* actor);
        static int32_t Papyrus_GetRegisteredCount(RE::StaticFunctionTag*);

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName);

    private:
        SandboxManager() = default;
        ~SandboxManager() = default;
        SandboxManager(const SandboxManager&) = delete;
        SandboxManager& operator=(const SandboxManager&) = delete;

        // Internal: Send cleanup event for a single actor
        void CleanupActor(RE::Actor* actor, const SandboxUserData& data);

        // Track sandboxing actors: ActorFormID -> UserData
        std::unordered_map<RE::FormID, SandboxUserData> m_registeredActors;
        mutable std::mutex m_mutex;

        bool m_initialized = false;

        // Cache player's last known cell for change detection
        RE::FormID m_lastPlayerCellFormID = 0;

        // Timing for periodic updates
        std::chrono::steady_clock::time_point m_lastUpdateTime;
        static constexpr int UPDATE_INTERVAL_MS = 500;  // Check every 500ms
    };
}
