#pragma once

// SeverActionsNative - Teammate Monitor
// Detects when any actor becomes or stops being a player teammate.
// Fires SKSE mod events so Papyrus can instantly onboard new followers
// without waiting for the next save/load cycle.
//
// Approach: Periodic scanning (every ~1 second) of loaded actors via
// InputEvent heartbeat (same pattern as SandboxManager). Checks the
// kPlayerTeammate bool flag and compares against a tracked set.
// Lightweight: empty-set early exit, no scanning when no teammates change.
//
// Thread safety: Mod events are dispatched on the game thread via AddTask.
//
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_set>
#include <mutex>
#include <chrono>

namespace SeverActionsNative
{
    /**
     * TeammateMonitor - Instant follower detection via periodic teammate scanning
     *
     * On each scan (~1 second intervals via InputEvent heartbeat):
     * 1. Iterates loaded actors (ProcessLists high + middle actors)
     * 2. Checks kPlayerTeammate bool flag on each
     * 3. Compares against m_knownTeammates set
     * 4. New teammate detected -> fires "SeverActions_NewTeammateDetected" mod event
     * 5. Teammate removed -> fires "SeverActions_TeammateRemoved" mod event
     * 6. Papyrus handler onboards/offboards the actor immediately
     *
     * The faction check (is actor in SeverActions_FollowerFaction?) is done
     * Papyrus-side to keep the C++ simple and avoid hardcoding faction FormIDs.
     */
    class TeammateMonitor :
        public RE::BSTEventSink<RE::InputEvent*>
    {
    public:
        static TeammateMonitor* GetSingleton();

        // Initialize event sink - call from plugin.cpp kDataLoaded
        void Initialize();

        // Process teammate scan
        void ScanForTeammateChanges();

        // Clear all tracked teammates (call on new game / load)
        void ClearTracking();

        // Event handler (input events = frame-rate heartbeat)
        RE::BSEventNotifyControl ProcessEvent(
            RE::InputEvent* const* a_event,
            RE::BSTEventSource<RE::InputEvent*>* a_eventSource) override;

        // Periodic update check
        void OnUpdate();

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static void Papyrus_SetEnabled(RE::StaticFunctionTag*, bool enabled);
        static bool Papyrus_IsEnabled(RE::StaticFunctionTag*);
        static int32_t Papyrus_GetTrackedTeammateCount(RE::StaticFunctionTag*);
        static void Papyrus_ClearTracking(RE::StaticFunctionTag*);

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName);

    private:
        TeammateMonitor() = default;
        ~TeammateMonitor() = default;
        TeammateMonitor(const TeammateMonitor&) = delete;
        TeammateMonitor& operator=(const TeammateMonitor&) = delete;

        // Send mod event on game thread
        void SendTeammateEvent(RE::FormID actorFormID, bool becameTeammate);

        // Known teammates: FormIDs of actors we've seen with kPlayerTeammate
        std::unordered_set<RE::FormID> m_knownTeammates;

        mutable std::mutex m_mutex;

        bool m_initialized = false;
        bool m_enabled = true;

        // Timing for periodic updates
        std::chrono::steady_clock::time_point m_lastScanTime;
        static constexpr int SCAN_INTERVAL_MS = 1000;  // Check every 1 second
    };
}
