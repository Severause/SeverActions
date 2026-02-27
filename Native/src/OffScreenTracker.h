#pragma once

// SeverActionsNative - Off-Screen Travel Estimator
// Estimates travel time for unloaded NPCs based on distance to destination.
// When estimated game-time elapses, Papyrus can teleport-complete the travel.
// Author: Severause

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_map>
#include <mutex>
#include <cmath>
#include <algorithm>

namespace SeverActionsNative
{
    struct OffScreenData
    {
        float estimatedArrivalGameTime = 0.0f;  // Game time when NPC should arrive
        RE::FormID destinationFormId = 0;        // For debug reference
    };

    /**
     * Lightweight off-screen travel time estimator.
     *
     * When a guard (or any NPC) leaves the loaded area during a dispatch,
     * we can't rely on Skyrim's AI to pathfind them to the destination.
     * Instead, we estimate how long the trip should take based on distance,
     * and when that game-time elapses, Papyrus teleports them to the destination.
     *
     * Usage:
     *   1. Call InitTracking() when dispatch starts (or when NPC goes off-screen)
     *   2. Call CheckArrival() each tick with current game time
     *   3. When CheckArrival returns 1, teleport NPC to destination
     *   4. Call StopTracking() on completion or cancellation
     *
     * Math:
     *   NPC walk speed in Skyrim is ~300 units/second
     *   1 real second = ~20 game minutes at default timescale (20)
     *   So 1 game-hour = 3 real minutes = ~54,000 walked units
     *   We use a conservative estimate: ~18,000 units per game-hour
     *   (accounting for doors, pathing inefficiency, obstacles)
     */
    class OffScreenTracker
    {
    public:
        static OffScreenTracker& GetInstance()
        {
            static OffScreenTracker instance;
            return instance;
        }

        // Approximate units an NPC walks per game-hour (conservative)
        static constexpr float UNITS_PER_GAME_HOUR = 18000.0f;

        /**
         * Start tracking off-screen travel for an actor.
         * Calculates estimated arrival based on 2D distance to destination.
         * @param actor The traveling NPC
         * @param destination Where they're going
         * @param minHours Minimum travel time in game-hours (default 0.5)
         * @param maxHours Maximum travel time in game-hours (default 18.0)
         * @return Estimated arrival in game-time format (days since epoch)
         */
        float InitTracking(RE::Actor* actor, RE::TESObjectREFR* destination,
                          float minHours = 0.5f, float maxHours = 18.0f)
        {
            if (!actor) return 0.0f;

            RE::FormID actorId = actor->GetFormID();
            RE::FormID destId = destination ? destination->GetFormID() : 0;

            // Calculate 2D distance (XY only — Z is irrelevant for travel time)
            float distance = 0.0f;
            bool havePositions = false;

            if (actor->Is3DLoaded() && destination && destination->Is3DLoaded()) {
                auto actorPos = actor->GetPosition();
                auto destPos = destination->GetPosition();
                float dx = actorPos.x - destPos.x;
                float dy = actorPos.y - destPos.y;
                distance = std::sqrt(dx * dx + dy * dy);
                havePositions = true;
            }

            // Estimate travel hours
            float travelHours;
            if (havePositions && distance > 0.0f) {
                travelHours = distance / UNITS_PER_GAME_HOUR;
            } else {
                // Can't calculate distance (one or both unloaded) — use conservative middle
                travelHours = (minHours + maxHours) / 2.0f;
            }

            // Clamp to bounds
            travelHours = std::clamp(travelHours, minHours, maxHours);

            // Get current game time and add travel duration
            // Game time is in days, so convert hours to days
            auto* calendar = RE::Calendar::GetSingleton();
            float currentGameTime = calendar ? calendar->GetCurrentGameTime() : 0.0f;
            float estimatedArrival = currentGameTime + (travelHours / 24.0f);

            // Store tracking data
            {
                std::lock_guard<std::mutex> lock(m_mutex);
                OffScreenData data;
                data.estimatedArrivalGameTime = estimatedArrival;
                data.destinationFormId = destId;
                m_tracked[actorId] = data;
            }

            SKSE::log::info("OffScreenTracker: Actor {:X} → dest {:X}, dist={:.0f}, est={:.2f}h, arrival={:.4f}",
                actorId, destId, distance, travelHours, estimatedArrival);

            return estimatedArrival;
        }

        /**
         * Check if estimated travel time has elapsed.
         * @param actor The traveling NPC
         * @param currentGameTime Current game time (from Utility.GetCurrentGameTime())
         * @return 0=in_transit, 1=estimated arrival (time to teleport)
         */
        int CheckArrival(RE::Actor* actor, float currentGameTime)
        {
            if (!actor) return 0;

            std::lock_guard<std::mutex> lock(m_mutex);

            auto it = m_tracked.find(actor->GetFormID());
            if (it == m_tracked.end()) return 0;

            if (currentGameTime >= it->second.estimatedArrivalGameTime) {
                SKSE::log::info("OffScreenTracker: Actor {:X} estimated arrival reached (time={:.4f} >= est={:.4f})",
                    actor->GetFormID(), currentGameTime, it->second.estimatedArrivalGameTime);
                return 1;
            }

            return 0;
        }

        /**
         * Stop tracking an actor.
         */
        void StopTracking(RE::Actor* actor)
        {
            if (!actor) return;

            std::lock_guard<std::mutex> lock(m_mutex);
            auto it = m_tracked.find(actor->GetFormID());
            if (it != m_tracked.end()) {
                SKSE::log::info("OffScreenTracker: Stopped tracking actor {:X}", actor->GetFormID());
                m_tracked.erase(it);
            }
        }

        /**
         * Get estimated arrival time for a tracked actor.
         * @return Game-time of estimated arrival, or 0 if not tracked.
         */
        float GetEstimatedArrival(RE::Actor* actor)
        {
            if (!actor) return 0.0f;

            std::lock_guard<std::mutex> lock(m_mutex);
            auto it = m_tracked.find(actor->GetFormID());
            if (it == m_tracked.end()) return 0.0f;
            return it->second.estimatedArrivalGameTime;
        }

        /**
         * Clear all tracking data.
         */
        void ClearAll()
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_tracked.clear();
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static float Papyrus_InitTracking(RE::StaticFunctionTag*, RE::Actor* actor,
                                          RE::TESObjectREFR* destination, float minHours, float maxHours)
        {
            return GetInstance().InitTracking(actor, destination, minHours, maxHours);
        }

        static int32_t Papyrus_CheckArrival(RE::StaticFunctionTag*, RE::Actor* actor, float currentGameTime)
        {
            return GetInstance().CheckArrival(actor, currentGameTime);
        }

        static void Papyrus_StopTracking(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            GetInstance().StopTracking(actor);
        }

        static float Papyrus_GetEstimatedArrival(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return GetInstance().GetEstimatedArrival(actor);
        }

        static void Papyrus_ClearAll(RE::StaticFunctionTag*)
        {
            GetInstance().ClearAll();
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("OffScreen_InitTracking", scriptName, Papyrus_InitTracking);
            a_vm->RegisterFunction("OffScreen_CheckArrival", scriptName, Papyrus_CheckArrival);
            a_vm->RegisterFunction("OffScreen_StopTracking", scriptName, Papyrus_StopTracking);
            a_vm->RegisterFunction("OffScreen_GetEstimatedArrival", scriptName, Papyrus_GetEstimatedArrival);
            a_vm->RegisterFunction("OffScreen_ClearAll", scriptName, Papyrus_ClearAll);

            SKSE::log::info("Registered off-screen tracker functions");
        }

    private:
        OffScreenTracker() = default;
        OffScreenTracker(const OffScreenTracker&) = delete;
        OffScreenTracker& operator=(const OffScreenTracker&) = delete;

        std::unordered_map<RE::FormID, OffScreenData> m_tracked;
        std::mutex m_mutex;
    };
}
