#pragma once

// SeverActionsNative - Orphan Package Cleanup
// Detects actors with SeverActions LinkedRef keywords that are NOT tracked
// by any management system (travel, furniture, follow). These "orphans"
// occur when a Papyrus script crashes mid-execution, leaving the LinkedRef
// set but no script managing the actor. The game engine creates FE runtime
// packages from these stale LinkedRefs, causing NPCs to stand around.
//
// Approach: Periodic scanning (every ~5 seconds) of loaded actors via
// InputEvent heartbeat (same pattern as TeammateMonitor). Checks each
// actor's LinkedRef for our keywords, cross-references against tracked
// sets, and fires cleanup mod events for Papyrus to handle.
//
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_set>
#include <mutex>
#include <chrono>

namespace SeverActionsNative
{
    class OrphanCleanup :
        public RE::BSTEventSink<RE::InputEvent*>
    {
    public:
        static OrphanCleanup* GetSingleton();

        // Initialize event sink - call from plugin.cpp kDataLoaded
        void Initialize();

        // Scan for orphaned LinkedRefs on loaded actors
        void ScanForOrphans();

        // Clear all tracking (call on new game / load)
        void ClearTracking();

        // ====================================================================
        // TRACKING REGISTRATION (called from Papyrus)
        // ====================================================================

        // Set keywords to scan for (call once from Papyrus init)
        void SetKeywords(RE::BGSKeyword* travelKW, RE::BGSKeyword* furnitureKW, RE::BGSKeyword* followKW);

        // Travel tracking
        void RegisterTraveler(RE::Actor* actor);
        void UnregisterTraveler(RE::Actor* actor);

        // Follow tracking
        void RegisterFollower(RE::Actor* actor);
        void UnregisterFollower(RE::Actor* actor);

        // Furniture → cross-reference FurnitureManager (no registration needed)

        // Event handler (input events = frame-rate heartbeat)
        RE::BSEventNotifyControl ProcessEvent(
            RE::InputEvent* const* a_event,
            RE::BSTEventSource<RE::InputEvent*>* a_eventSource) override;

        // Periodic update check
        void OnUpdate();

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static void Papyrus_Initialize(RE::StaticFunctionTag*,
            RE::BGSKeyword* travelKW, RE::BGSKeyword* furnitureKW, RE::BGSKeyword* followKW);
        static void Papyrus_RegisterTraveler(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_UnregisterTraveler(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_RegisterFollower(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_UnregisterFollower(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_SetEnabled(RE::StaticFunctionTag*, bool enabled);
        static bool Papyrus_IsEnabled(RE::StaticFunctionTag*);
        static void Papyrus_ClearTracking(RE::StaticFunctionTag*);

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName);

    private:
        OrphanCleanup() = default;
        ~OrphanCleanup() = default;
        OrphanCleanup(const OrphanCleanup&) = delete;
        OrphanCleanup& operator=(const OrphanCleanup&) = delete;

        // Send mod event on game thread for Papyrus cleanup
        void SendCleanupEvent(RE::FormID actorFormID, const char* keywordType);

        // Keywords to check (set via Papyrus)
        RE::FormID m_travelKeywordID = 0;
        RE::FormID m_furnitureKeywordID = 0;
        RE::FormID m_followKeywordID = 0;
        bool m_keywordsSet = false;

        // Tracked actors
        std::unordered_set<RE::FormID> m_trackedTravelers;
        std::unordered_set<RE::FormID> m_trackedFollowers;

        mutable std::mutex m_mutex;

        bool m_initialized = false;
        bool m_enabled = true;

        // Timing
        std::chrono::steady_clock::time_point m_lastScanTime;
        static constexpr int SCAN_INTERVAL_MS = 5000;  // Every 5 seconds
    };
}
