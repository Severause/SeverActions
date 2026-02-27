#pragma once

// SeverActionsNative - Furniture Manager
// Handles automatic package cleanup for furniture-using actors
// - Auto-removes package when player changes cells
// - Auto-removes package when player moves away (distance threshold)
// - No Papyrus polling required - uses native event hooks and frame updates
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_map>
#include <mutex>
#include <chrono>

namespace SeverActionsNative
{
    struct FurnitureUserData
    {
        RE::FormID actorFormID;
        RE::FormID packageFormID;
        RE::FormID furnitureFormID;
        RE::FormID linkedRefKeywordFormID;
        float autoStandDistance;
        RE::FormID registeredCellFormID;  // Cell they were in when registered
    };

    /**
     * FurnitureManager - Native furniture package management
     *
     * Eliminates Papyrus polling by:
     * 1. Hooking player cell change events
     * 2. Using periodic updates via menu open/close events (fires frequently)
     * 3. Checking distances every ~500ms during gameplay
     *
     * When player leaves cell or moves too far:
     * - Sends mod event for Papyrus to handle cleanup
     * - Actor naturally stands up and returns to normal AI
     */
    class FurnitureManager :
        public RE::BSTEventSink<RE::TESCellFullyLoadedEvent>,
        public RE::BSTEventSink<RE::TESCellAttachDetachEvent>,
        public RE::BSTEventSink<RE::MenuOpenCloseEvent>,
        public RE::BSTEventSink<RE::InputEvent*>
    {
    public:
        static FurnitureManager* GetSingleton();

        // Initialize event sinks
        void Initialize();

        // Register an actor as using furniture
        // Returns true if successfully registered
        bool RegisterFurnitureUser(
            RE::Actor* actor,
            RE::TESPackage* package,
            RE::TESObjectREFR* furniture,
            RE::BGSKeyword* linkedRefKeyword,
            float autoStandDistance = 500.0f
        );

        // Unregister an actor (call when they stand up normally)
        void UnregisterFurnitureUser(RE::Actor* actor);

        // Force all registered actors to stand up (e.g., on cell change)
        void ForceAllStandUp();

        // Check if an actor is registered
        bool IsRegistered(RE::Actor* actor);

        // Get/Set global auto-stand distance (default for new registrations)
        float GetDefaultAutoStandDistance() const { return m_defaultAutoStandDistance; }
        void SetDefaultAutoStandDistance(float distance) { m_defaultAutoStandDistance = distance; }

        // Process distance checks for all registered actors
        // Called from game loop hook
        void ProcessDistanceChecks();

        // Event handlers
        RE::BSEventNotifyControl ProcessEvent(
            const RE::TESCellFullyLoadedEvent* a_event,
            RE::BSTEventSource<RE::TESCellFullyLoadedEvent>* a_eventSource) override;

        RE::BSEventNotifyControl ProcessEvent(
            const RE::TESCellAttachDetachEvent* a_event,
            RE::BSTEventSource<RE::TESCellAttachDetachEvent>* a_eventSource) override;

        RE::BSEventNotifyControl ProcessEvent(
            const RE::MenuOpenCloseEvent* a_event,
            RE::BSTEventSource<RE::MenuOpenCloseEvent>* a_eventSource) override;

        RE::BSEventNotifyControl ProcessEvent(
            RE::InputEvent* const* a_event,
            RE::BSTEventSource<RE::InputEvent*>* a_eventSource) override;

        // Called from game update hook
        void OnUpdate();

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static bool Papyrus_RegisterFurnitureUser(
            RE::StaticFunctionTag*,
            RE::Actor* actor,
            RE::TESPackage* package,
            RE::TESObjectREFR* furniture,
            RE::BGSKeyword* linkedRefKeyword,
            float autoStandDistance
        );

        static void Papyrus_UnregisterFurnitureUser(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_ForceAllStandUp(RE::StaticFunctionTag*);
        static bool Papyrus_IsRegistered(RE::StaticFunctionTag*, RE::Actor* actor);
        static float Papyrus_GetDefaultAutoStandDistance(RE::StaticFunctionTag*);
        static void Papyrus_SetDefaultAutoStandDistance(RE::StaticFunctionTag*, float distance);
        static int32_t Papyrus_GetRegisteredCount(RE::StaticFunctionTag*);

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName);

    private:
        FurnitureManager() = default;
        ~FurnitureManager() = default;
        FurnitureManager(const FurnitureManager&) = delete;
        FurnitureManager& operator=(const FurnitureManager&) = delete;

        // Internal: Remove package and cleanup for a single actor
        void CleanupActor(RE::Actor* actor, const FurnitureUserData& data);

        // Track actors using furniture: ActorFormID -> UserData
        std::unordered_map<RE::FormID, FurnitureUserData> m_registeredActors;
        mutable std::mutex m_mutex;

        float m_defaultAutoStandDistance = 500.0f;
        bool m_initialized = false;

        // Cache player's last known cell for change detection
        RE::FormID m_lastPlayerCellFormID = 0;

        // Timing for periodic updates
        std::chrono::steady_clock::time_point m_lastUpdateTime;
        static constexpr int UPDATE_INTERVAL_MS = 500;  // Check every 500ms
    };
}
