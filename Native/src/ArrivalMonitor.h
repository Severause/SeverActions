#pragma once

// SeverActionsNative - Arrival Monitor
// Monitors actor-to-destination distance natively and fires a ModCallbackEvent
// when the actor arrives within threshold. Replaces Papyrus OnUpdate polling
// loops for approach, escort, and dispatch travel phases.
//
// Approach: Periodic scanning (every ~1 second) via InputEvent heartbeat
// (same pattern as TeammateMonitor/SandboxManager). Checks distance between
// tracked actors and their destinations using live positions when 3D-loaded,
// or ActorFinder position snapshots when unloaded.
//
// One-shot semantics: auto-unregisters after firing callback.
// Safety: auto-cancels on actor death, 2-second grace period after registration.
// Thread safety: Mod events dispatched on game thread via AddTask.
//
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_map>
#include <mutex>
#include <chrono>
#include <string>
#include <variant>

namespace SeverActionsNative
{
    // ========================================================================
    // DESTINATION TYPES
    // ========================================================================

    /// Destination is an ObjectReference (marker, door, actor, etc.)
    struct DestinationRef
    {
        RE::FormID refFormID;  // The ObjectReference to track distance to
    };

    /// Destination is raw XY coordinates (for cases where no ref exists)
    struct DestinationXY
    {
        float x;
        float y;
    };

    /// A destination can be either a ref or raw coordinates
    using Destination = std::variant<DestinationRef, DestinationXY>;

    // ========================================================================
    // ARRIVAL ENTRY
    // ========================================================================

    /// One tracked actor-to-destination registration
    struct ArrivalEntry
    {
        RE::FormID actorFormID;            // The actor being monitored
        Destination destination;            // Where they're heading
        float distanceThreshold;            // Arrival distance (units)
        std::string callbackTag;            // e.g. "approach", "escort", "dispatch_travel"
        std::chrono::steady_clock::time_point registeredAt;  // For grace period
        bool graceExpired = false;          // True after 2-second grace period
    };

    // ========================================================================
    // ARRIVAL MONITOR SINGLETON
    // ========================================================================

    /**
     * ArrivalMonitor - Native distance monitoring with automatic ModEvent callbacks
     *
     * On each scan (~1 second intervals via InputEvent heartbeat):
     * 1. Iterates all tracked entries
     * 2. Checks if grace period (2s) has expired
     * 3. Checks if actor is dead -> auto-cancel
     * 4. Calculates distance using best available method:
     *    a. Both 3D loaded -> live GetPosition(), 2D distance (XY only)
     *    b. Actor loaded, dest unloaded -> actor live, dest snapshot
     *    c. Actor unloaded, dest loaded -> actor snapshot, dest live
     *    d. Both unloaded -> both snapshots via ActorFinder
     *    e. No data available -> skip this tick (return -1)
     * 5. If distance <= threshold -> fire "SeverActionsNative_OnArrival" and remove entry
     *
     * ModEvent format:
     *   eventName = "SeverActionsNative_OnArrival"
     *   strArg    = callbackTag
     *   numArg    = final distance at detection time
     *   sender    = the tracked actor (Form)
     */
    class ArrivalMonitor :
        public RE::BSTEventSink<RE::InputEvent*>
    {
    public:
        static ArrivalMonitor* GetSingleton();

        // Initialize event sink - call from plugin.cpp kDataLoaded
        void Initialize();

        // ====================================================================
        // CORE API (called from Papyrus wrappers or internally)
        // ====================================================================

        /// Register an actor to monitor distance to an ObjectReference
        /// Overwrites any existing registration for this actor (one actor = one tracking)
        void Register(RE::FormID actorFormID, RE::FormID destRefFormID,
                      float distanceThreshold, const std::string& callbackTag);

        /// Register an actor to monitor distance to raw XY coordinates
        void RegisterXY(RE::FormID actorFormID, float destX, float destY,
                        float distanceThreshold, const std::string& callbackTag);

        /// Cancel tracking for an actor. No event fires.
        void Cancel(RE::FormID actorFormID);

        /// Check if an actor is currently being monitored
        bool IsTracked(RE::FormID actorFormID) const;

        /// Get current distance to tracked destination. Returns -1 if not tracked.
        float GetDistance(RE::FormID actorFormID) const;

        /// Clear all tracked entries (call on new game / load)
        void ClearAll();

        /// Get count of monitored actors
        int32_t GetTrackedCount() const;

        // ====================================================================
        // UPDATE LOOP
        // ====================================================================

        /// Check all arrivals - called from OnUpdate at throttled interval
        void CheckAllArrivals();

        /// Event handler (input events = frame-rate heartbeat)
        RE::BSEventNotifyControl ProcessEvent(
            RE::InputEvent* const* a_event,
            RE::BSTEventSource<RE::InputEvent*>* a_eventSource) override;

        /// Periodic update check (throttled)
        void OnUpdate();

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static void Papyrus_Register(RE::StaticFunctionTag*,
            RE::Actor* akActor, RE::TESObjectREFR* akDestination,
            float distanceThreshold, RE::BSFixedString callbackTag);

        static void Papyrus_RegisterXY(RE::StaticFunctionTag*,
            RE::Actor* akActor, float destX, float destY,
            float distanceThreshold, RE::BSFixedString callbackTag);

        static void Papyrus_Cancel(RE::StaticFunctionTag*, RE::Actor* akActor);

        static bool Papyrus_IsTracked(RE::StaticFunctionTag*, RE::Actor* akActor);

        static float Papyrus_GetDistance(RE::StaticFunctionTag*, RE::Actor* akActor);

        static void Papyrus_ClearAll(RE::StaticFunctionTag*);

        static int32_t Papyrus_GetTrackedCount(RE::StaticFunctionTag*);

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName);

    private:
        ArrivalMonitor() = default;
        ~ArrivalMonitor() = default;
        ArrivalMonitor(const ArrivalMonitor&) = delete;
        ArrivalMonitor& operator=(const ArrivalMonitor&) = delete;

        // ====================================================================
        // DISTANCE CALCULATION
        // ====================================================================

        /// Calculate 2D (XY) distance between actor and destination
        /// Returns -1.0f if no position data available for either side
        float CalculateDistance(const ArrivalEntry& entry) const;

        /// Get position for the actor side (live or snapshot)
        /// Returns false if no position available
        bool GetActorPosition(RE::FormID actorFormID, RE::NiPoint3& outPos) const;

        /// Get position for the destination side (ref or XY)
        /// Returns false if no position available
        bool GetDestinationPosition(const Destination& dest, RE::NiPoint3& outPos) const;

        // ====================================================================
        // EVENT DISPATCH
        // ====================================================================

        /// Fire the arrival ModEvent on the game thread
        void FireArrivalEvent(RE::FormID actorFormID, const std::string& callbackTag, float finalDistance);

        // ====================================================================
        // MEMBER DATA
        // ====================================================================

        /// One actor = one entry. FormID key = actor's runtime FormID.
        std::unordered_map<RE::FormID, ArrivalEntry> m_tracked;

        mutable std::mutex m_mutex;

        bool m_initialized = false;

        // Timing for periodic updates
        std::chrono::steady_clock::time_point m_lastCheckTime;

        static constexpr int CHECK_INTERVAL_MS = 1000;   // Check every 1 second
        static constexpr int GRACE_PERIOD_MS   = 2000;   // 2-second grace before first check
    };
}
