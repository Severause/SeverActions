#pragma once

// SeverActionsNative - Stuck Detector
// Tracks NPC movement to detect when they're stuck during travel/escort
// Supports progressive recovery escalation levels
// Author: Severause

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_map>
#include <mutex>
#include <chrono>

namespace SeverActionsNative
{
    struct MovementTracker
    {
        RE::FormID actorFormId;
        float lastX = 0.0f;
        float lastY = 0.0f;
        float lastZ = 0.0f;
        int stuckTicks = 0;          // Consecutive ticks with no significant movement
        int escalationLevel = 0;     // 0=normal, 1=nudge, 2=leapfrog, 3=teleport
        float totalStuckTime = 0.0f; // Total seconds stuck
        bool active = false;

        // Departure detection: baseline position recorded when tracking starts
        float baselineX = 0.0f;
        float baselineY = 0.0f;
        float baselineZ = 0.0f;
        int departureTicks = 0;      // Ticks since tracking started (for grace period)
        bool departed = false;       // True once NPC moved beyond departure threshold
    };

    /**
     * Native stuck detection for traveling/escorted NPCs
     *
     * Papyrus calls StartTracking() when an NPC begins traveling
     * Then calls CheckStuckStatus() every few seconds
     * Returns escalation level:
     *   0 = Moving normally
     *   1 = Possibly stuck (minor nudge recommended - re-evaluate packages)
     *   2 = Stuck (moderate recovery - leapfrog teleport toward destination)
     *   3 = Very stuck (force teleport to destination)
     *
     * Call StopTracking() when travel completes or is cancelled
     */
    class StuckDetector
    {
    public:
        static StuckDetector& GetInstance()
        {
            static StuckDetector instance;
            return instance;
        }

        /**
         * Start tracking an actor's movement
         * @param actor The actor to track
         */
        void StartTracking(RE::Actor* actor)
        {
            if (!actor) return;

            std::lock_guard<std::mutex> lock(m_mutex);

            RE::FormID formId = actor->GetFormID();
            auto pos = actor->GetPosition();

            MovementTracker tracker;
            tracker.actorFormId = formId;
            tracker.lastX = pos.x;
            tracker.lastY = pos.y;
            tracker.lastZ = pos.z;
            tracker.stuckTicks = 0;
            tracker.escalationLevel = 0;
            tracker.totalStuckTime = 0.0f;
            tracker.active = true;
            // Record baseline for departure detection
            tracker.baselineX = pos.x;
            tracker.baselineY = pos.y;
            tracker.baselineZ = pos.z;
            tracker.departureTicks = 0;
            tracker.departed = false;

            m_trackers[formId] = tracker;

            SKSE::log::info("StuckDetector: Started tracking actor {:X}", formId);
        }

        /**
         * Stop tracking an actor
         */
        void StopTracking(RE::Actor* actor)
        {
            if (!actor) return;

            std::lock_guard<std::mutex> lock(m_mutex);

            RE::FormID formId = actor->GetFormID();
            m_trackers.erase(formId);

            SKSE::log::info("StuckDetector: Stopped tracking actor {:X}", formId);
        }

        /**
         * Check if an actor is stuck and return escalation level
         * @param actor The actor to check
         * @param checkInterval How many seconds since last check (typically 3.0)
         * @param moveThreshold Minimum distance to count as "moving" (default 50 units)
         * @return 0=moving, 1=nudge, 2=leapfrog, 3=teleport
         */
        int CheckStuckStatus(RE::Actor* actor, float checkInterval = 3.0f, float moveThreshold = 50.0f)
        {
            if (!actor) return 0;

            std::lock_guard<std::mutex> lock(m_mutex);

            RE::FormID formId = actor->GetFormID();
            auto it = m_trackers.find(formId);
            if (it == m_trackers.end() || !it->second.active) return 0;

            MovementTracker& tracker = it->second;
            auto pos = actor->GetPosition();

            // Calculate distance moved since last check
            float dx = pos.x - tracker.lastX;
            float dy = pos.y - tracker.lastY;
            float dz = pos.z - tracker.lastZ;
            float distMoved = std::sqrt(dx * dx + dy * dy + dz * dz);

            // Update position
            tracker.lastX = pos.x;
            tracker.lastY = pos.y;
            tracker.lastZ = pos.z;

            if (distMoved >= moveThreshold) {
                // NPC is moving - reset stuck counter
                tracker.stuckTicks = 0;
                tracker.totalStuckTime = 0.0f;
                // Gradually de-escalate
                if (tracker.escalationLevel > 0) {
                    tracker.escalationLevel--;
                }
                return 0;
            }

            // NPC hasn't moved enough
            tracker.stuckTicks++;
            tracker.totalStuckTime += checkInterval;

            // Escalation thresholds (in stuck ticks, assuming 3s intervals):
            //   3 ticks (9s)  -> Level 1: Nudge (re-evaluate packages)
            //   6 ticks (18s) -> Level 2: Leapfrog (progressive teleport)
            //  10 ticks (30s) -> Level 3: Force teleport
            if (tracker.stuckTicks >= 10) {
                tracker.escalationLevel = 3;
            } else if (tracker.stuckTicks >= 6) {
                tracker.escalationLevel = 2;
            } else if (tracker.stuckTicks >= 3) {
                tracker.escalationLevel = 1;
            }

            if (tracker.escalationLevel > 0) {
                SKSE::log::info("StuckDetector: Actor {:X} stuck for {:.1f}s, level {}, moved {:.1f} units",
                    formId, tracker.totalStuckTime, tracker.escalationLevel, distMoved);
            }

            return tracker.escalationLevel;
        }

        /**
         * Get progressive teleport distance based on escalation
         * Each call increases the distance for progressive leapfrogging
         * @return Distance to teleport toward destination
         */
        float GetTeleportDistance(RE::Actor* actor)
        {
            if (!actor) return 0.0f;

            std::lock_guard<std::mutex> lock(m_mutex);

            RE::FormID formId = actor->GetFormID();
            auto it = m_trackers.find(formId);
            if (it == m_trackers.end()) return 0.0f;

            // Progressive distances: 200 → 500 → 1000 → 2000
            switch (it->second.escalationLevel) {
                case 1: return 200.0f;
                case 2: return 500.0f;
                case 3: return 2000.0f;
                default: return 0.0f;
            }
        }

        /**
         * Check if an actor is being tracked
         */
        bool IsTracked(RE::Actor* actor)
        {
            if (!actor) return false;
            std::lock_guard<std::mutex> lock(m_mutex);
            auto it = m_trackers.find(actor->GetFormID());
            return (it != m_trackers.end() && it->second.active);
        }

        /**
         * Reset escalation for an actor (after successful recovery)
         */
        void ResetEscalation(RE::Actor* actor)
        {
            if (!actor) return;
            std::lock_guard<std::mutex> lock(m_mutex);
            auto it = m_trackers.find(actor->GetFormID());
            if (it != m_trackers.end()) {
                it->second.stuckTicks = 0;
                it->second.escalationLevel = 0;
                it->second.totalStuckTime = 0.0f;
            }
        }

        /**
         * Check if a tracked actor has moved from their starting position.
         * Used for departure verification: after applying a travel package,
         * confirm the NPC actually started moving within a grace period.
         *
         * @param actor The actor to check
         * @param departureThreshold Minimum distance from baseline to count as "departed" (default 100)
         * @return 0=too_early (grace period), 1=departed successfully, 2=soft recovery needed
         */
        int CheckDeparture(RE::Actor* actor, float departureThreshold = 100.0f)
        {
            if (!actor) return 0;

            std::lock_guard<std::mutex> lock(m_mutex);

            RE::FormID formId = actor->GetFormID();
            auto it = m_trackers.find(formId);
            if (it == m_trackers.end() || !it->second.active) return 0;

            MovementTracker& tracker = it->second;

            // Already confirmed departed — fast return
            if (tracker.departed) return 1;

            // Increment departure tick counter
            tracker.departureTicks++;

            // Grace period: AI needs time to evaluate packages and start pathfinding
            // 5 ticks × 3s interval = 15 seconds grace
            if (tracker.departureTicks < 5) return 0;

            // Check distance from baseline position (2D only — XY)
            auto pos = actor->GetPosition();
            float dx = pos.x - tracker.baselineX;
            float dy = pos.y - tracker.baselineY;
            float distFromStart = std::sqrt(dx * dx + dy * dy);

            if (distFromStart >= departureThreshold) {
                tracker.departed = true;
                SKSE::log::info("StuckDetector: Actor {:X} departed (moved {:.0f} units from baseline)", formId, distFromStart);
                return 1;
            }

            // Extended wait without movement — soft recovery needed
            // 10 ticks × 3s = 30 seconds without departing
            if (tracker.departureTicks >= 10) {
                SKSE::log::warn("StuckDetector: Actor {:X} failed to depart after {}s (moved only {:.0f} units)",
                    formId, tracker.departureTicks * 3, distFromStart);
                // Reset departure ticks so we don't spam recovery every tick
                tracker.departureTicks = 5;
                return 2;
            }

            return 0;
        }

        /**
         * Clear all tracking data (for cleanup on cell change etc.)
         */
        void ClearAll()
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_trackers.clear();
        }

        int GetTrackedCount()
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            return static_cast<int>(m_trackers.size());
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static void Papyrus_StartTracking(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            GetInstance().StartTracking(actor);
        }

        static void Papyrus_StopTracking(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            GetInstance().StopTracking(actor);
        }

        static int32_t Papyrus_CheckStuckStatus(RE::StaticFunctionTag*, RE::Actor* actor, float checkInterval, float moveThreshold)
        {
            return GetInstance().CheckStuckStatus(actor, checkInterval, moveThreshold);
        }

        static float Papyrus_GetTeleportDistance(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return GetInstance().GetTeleportDistance(actor);
        }

        static bool Papyrus_IsStuckTracked(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return GetInstance().IsTracked(actor);
        }

        static void Papyrus_ResetEscalation(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            GetInstance().ResetEscalation(actor);
        }

        static void Papyrus_ClearAllTracking(RE::StaticFunctionTag*)
        {
            GetInstance().ClearAll();
        }

        static int32_t Papyrus_CheckDeparture(RE::StaticFunctionTag*, RE::Actor* actor, float departureThreshold)
        {
            return GetInstance().CheckDeparture(actor, departureThreshold);
        }

        static int32_t Papyrus_GetStuckTrackedCount(RE::StaticFunctionTag*)
        {
            return GetInstance().GetTrackedCount();
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("Stuck_StartTracking", scriptName, Papyrus_StartTracking);
            a_vm->RegisterFunction("Stuck_StopTracking", scriptName, Papyrus_StopTracking);
            a_vm->RegisterFunction("Stuck_CheckStatus", scriptName, Papyrus_CheckStuckStatus);
            a_vm->RegisterFunction("Stuck_GetTeleportDistance", scriptName, Papyrus_GetTeleportDistance);
            a_vm->RegisterFunction("Stuck_IsTracked", scriptName, Papyrus_IsStuckTracked);
            a_vm->RegisterFunction("Stuck_ResetEscalation", scriptName, Papyrus_ResetEscalation);
            a_vm->RegisterFunction("Stuck_ClearAll", scriptName, Papyrus_ClearAllTracking);
            a_vm->RegisterFunction("Stuck_GetTrackedCount", scriptName, Papyrus_GetStuckTrackedCount);
            a_vm->RegisterFunction("Stuck_CheckDeparture", scriptName, Papyrus_CheckDeparture);

            SKSE::log::info("Registered stuck detector functions");
        }

    private:
        StuckDetector() = default;
        StuckDetector(const StuckDetector&) = delete;
        StuckDetector& operator=(const StuckDetector&) = delete;

        std::unordered_map<RE::FormID, MovementTracker> m_trackers;
        std::mutex m_mutex;
    };
}
