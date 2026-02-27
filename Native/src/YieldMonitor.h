#pragma once

// SeverActionsNative - Yield Monitor
// Monitors hits on surrendered actors via TESHitEvent.
// When a yielded actor takes enough hits (threshold), automatically reverts
// the surrender — restoring aggression, removing from SeverSurrenderedFaction,
// and firing a mod event for Papyrus to clean up StorageUtil keys.
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_map>
#include <mutex>

namespace SeverActionsNative
{
    // Per-actor tracking data for yielded actors
    struct YieldedActorData
    {
        int hitCount = 0;
        float originalAggression = 1.0f;  // Stored from Papyrus at registration
    };

    /**
     * YieldMonitor - TESHitEvent sink for surrendered actor monitoring
     *
     * When Yield_Execute makes an actor surrender (Aggression=0, SeverSurrenderedFaction),
     * the Papyrus side calls RegisterYieldedActor to start monitoring.
     *
     * ProcessEvent counts incoming hits on tracked actors. After m_hitThreshold hits,
     * RevertSurrender fires:
     *   1. C++ restores aggression + removes surrendered faction (instant, engine-level)
     *   2. SKSE mod event notifies Papyrus to restore hostile factions + cleanup StorageUtil
     *
     * Zero cost when no actors are yielded (empty-map early exit).
     */
    class YieldMonitor :
        public RE::BSTEventSink<RE::TESHitEvent>
    {
    public:
        static YieldMonitor* GetSingleton();

        // Initialize event sink — call from plugin.cpp kDataLoaded
        void Initialize();

        // ====================================================================
        // ACTOR TRACKING
        // ====================================================================

        // Start monitoring a yielded actor for hits
        // surrenderedFaction is cached on first call for later removal
        void RegisterYieldedActor(RE::Actor* actor, float originalAggression,
                                  RE::TESFaction* surrenderedFaction);

        // Stop monitoring (called by ReturnToCrime, FullCleanup, etc.)
        void UnregisterYieldedActor(RE::Actor* actor);

        // Check if an actor is being monitored
        bool IsMonitored(RE::Actor* actor);

        // Get current hit count for a monitored actor
        int GetHitCount(RE::Actor* actor);

        // Set the hit threshold (default: 3)
        void SetHitThreshold(int threshold);

        // Clear all tracking data
        void ClearAll();

        // ====================================================================
        // EVENT HANDLER
        // ====================================================================

        RE::BSEventNotifyControl ProcessEvent(
            const RE::TESHitEvent* a_event,
            RE::BSTEventSource<RE::TESHitEvent>* a_eventSource) override;

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static void Papyrus_RegisterYieldedActor(RE::StaticFunctionTag*,
            RE::Actor* actor, float originalAggression, RE::TESFaction* surrenderedFaction);
        static void Papyrus_UnregisterYieldedActor(RE::StaticFunctionTag*, RE::Actor* actor);
        static bool Papyrus_IsYieldMonitored(RE::StaticFunctionTag*, RE::Actor* actor);
        static int32_t Papyrus_GetYieldHitCount(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_SetYieldHitThreshold(RE::StaticFunctionTag*, int32_t threshold);

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName);

    private:
        YieldMonitor() = default;
        ~YieldMonitor() = default;
        YieldMonitor(const YieldMonitor&) = delete;
        YieldMonitor& operator=(const YieldMonitor&) = delete;

        // Revert a surrendered actor — restore aggression, remove faction, fire mod event
        void RevertSurrender(RE::Actor* actor, const YieldedActorData& data);

        // Tracked yielded actors: FormID -> YieldedActorData
        std::unordered_map<RE::FormID, YieldedActorData> m_yieldedActors;
        mutable std::mutex m_mutex;

        // Cached faction pointer — set on first RegisterYieldedActor call
        RE::TESFaction* m_surrenderedFaction = nullptr;

        // Hit threshold before auto-reverting surrender
        int m_hitThreshold = 3;

        bool m_initialized = false;
    };
}
