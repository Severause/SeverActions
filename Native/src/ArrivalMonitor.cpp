// SeverActionsNative - Arrival Monitor Implementation
// Native distance monitoring with automatic ModEvent callbacks.
// Replaces Papyrus OnUpdate distance polling for approach, escort, and dispatch phases.
//
// Author: Severause

#include "ArrivalMonitor.h"
#include "ActorFinder.h"

namespace SeverActionsNative
{
    ArrivalMonitor* ArrivalMonitor::GetSingleton()
    {
        static ArrivalMonitor singleton;
        return &singleton;
    }

    void ArrivalMonitor::Initialize()
    {
        if (m_initialized) {
            return;
        }

        // Register for input events (fires every frame - most reliable update mechanism)
        auto* inputDeviceManager = RE::BSInputDeviceManager::GetSingleton();
        if (inputDeviceManager) {
            inputDeviceManager->AddEventSink(this);
            SKSE::log::info("ArrivalMonitor: Registered for input events");
        } else {
            SKSE::log::error("ArrivalMonitor: Failed to get BSInputDeviceManager");
            return;
        }

        m_lastCheckTime = std::chrono::steady_clock::now();
        m_initialized = true;
        SKSE::log::info("ArrivalMonitor initialized (check interval: {}ms, grace: {}ms)",
            CHECK_INTERVAL_MS, GRACE_PERIOD_MS);
    }

    // ========================================================================
    // CORE API
    // ========================================================================

    void ArrivalMonitor::Register(RE::FormID actorFormID, RE::FormID destRefFormID,
                                  float distanceThreshold, const std::string& callbackTag)
    {
        std::lock_guard<std::mutex> lock(m_mutex);

        ArrivalEntry entry;
        entry.actorFormID = actorFormID;
        entry.destination = DestinationRef{destRefFormID};
        entry.distanceThreshold = distanceThreshold;
        entry.callbackTag = callbackTag;
        entry.registeredAt = std::chrono::steady_clock::now();
        entry.graceExpired = false;

        // Overwrite any existing registration for this actor
        m_tracked[actorFormID] = std::move(entry);

        SKSE::log::info("ArrivalMonitor: Registered {:08X} -> ref {:08X}, threshold={:.0f}, tag='{}'",
            actorFormID, destRefFormID, distanceThreshold, callbackTag);
    }

    void ArrivalMonitor::RegisterXY(RE::FormID actorFormID, float destX, float destY,
                                     float distanceThreshold, const std::string& callbackTag)
    {
        std::lock_guard<std::mutex> lock(m_mutex);

        ArrivalEntry entry;
        entry.actorFormID = actorFormID;
        entry.destination = DestinationXY{destX, destY};
        entry.distanceThreshold = distanceThreshold;
        entry.callbackTag = callbackTag;
        entry.registeredAt = std::chrono::steady_clock::now();
        entry.graceExpired = false;

        m_tracked[actorFormID] = std::move(entry);

        SKSE::log::info("ArrivalMonitor: Registered {:08X} -> XY({:.0f}, {:.0f}), threshold={:.0f}, tag='{}'",
            actorFormID, destX, destY, distanceThreshold, callbackTag);
    }

    void ArrivalMonitor::Cancel(RE::FormID actorFormID)
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_tracked.find(actorFormID);
        if (it != m_tracked.end()) {
            SKSE::log::info("ArrivalMonitor: Cancelled {:08X} (tag='{}')",
                actorFormID, it->second.callbackTag);
            m_tracked.erase(it);
        }
    }

    bool ArrivalMonitor::IsTracked(RE::FormID actorFormID) const
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_tracked.contains(actorFormID);
    }

    float ArrivalMonitor::GetDistance(RE::FormID actorFormID) const
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_tracked.find(actorFormID);
        if (it == m_tracked.end()) {
            return -1.0f;
        }
        return CalculateDistance(it->second);
    }

    void ArrivalMonitor::ClearAll()
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        auto count = m_tracked.size();
        m_tracked.clear();
        if (count > 0) {
            SKSE::log::info("ArrivalMonitor: Cleared all tracking ({} entries)", count);
        }
    }

    int32_t ArrivalMonitor::GetTrackedCount() const
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        return static_cast<int32_t>(m_tracked.size());
    }

    // ========================================================================
    // ARRIVAL CHECKING
    // ========================================================================

    void ArrivalMonitor::CheckAllArrivals()
    {
        std::lock_guard<std::mutex> lock(m_mutex);

        if (m_tracked.empty()) {
            return;  // Nothing to check — fast path
        }

        auto now = std::chrono::steady_clock::now();
        std::vector<RE::FormID> toRemove;

        for (auto& [actorFormID, entry] : m_tracked) {
            // --- Grace period check ---
            if (!entry.graceExpired) {
                auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
                    now - entry.registeredAt).count();
                if (elapsed < GRACE_PERIOD_MS) {
                    continue;  // Still in grace period, skip
                }
                entry.graceExpired = true;
            }

            // --- Death check ---
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(actorFormID);
            if (actor && actor->IsDead()) {
                SKSE::log::info("ArrivalMonitor: Actor {:08X} is dead — auto-cancelling (tag='{}')",
                    actorFormID, entry.callbackTag);
                toRemove.push_back(actorFormID);
                continue;
            }

            // --- Distance check ---
            float dist = CalculateDistance(entry);
            if (dist < 0.0f) {
                // No position data available this tick — skip
                continue;
            }

            if (dist <= entry.distanceThreshold) {
                // ARRIVED!
                SKSE::log::info("ArrivalMonitor: ARRIVED {:08X} tag='{}' dist={:.0f} (threshold={:.0f})",
                    actorFormID, entry.callbackTag, dist, entry.distanceThreshold);
                toRemove.push_back(actorFormID);

                // Fire event (copies data before entry is erased)
                FireArrivalEvent(actorFormID, entry.callbackTag, dist);
            }
        }

        // Remove completed/dead entries
        for (RE::FormID id : toRemove) {
            m_tracked.erase(id);
        }
    }

    // ========================================================================
    // DISTANCE CALCULATION
    // ========================================================================

    float ArrivalMonitor::CalculateDistance(const ArrivalEntry& entry) const
    {
        RE::NiPoint3 actorPos;
        RE::NiPoint3 destPos;

        if (!GetActorPosition(entry.actorFormID, actorPos)) {
            return -1.0f;
        }

        if (!GetDestinationPosition(entry.destination, destPos)) {
            return -1.0f;
        }

        // 2D distance (XY only, no Z) — Z variance is unreliable in Skyrim
        // (e.g., actors on different floors of the same building)
        float dx = actorPos.x - destPos.x;
        float dy = actorPos.y - destPos.y;
        return std::sqrt(dx * dx + dy * dy);
    }

    bool ArrivalMonitor::GetActorPosition(RE::FormID actorFormID, RE::NiPoint3& outPos) const
    {
        auto* actor = RE::TESForm::LookupByID<RE::Actor>(actorFormID);
        if (!actor) {
            // Actor doesn't exist anymore — can't get position
            return false;
        }

        // Try live position first (3D loaded = actor is nearby and rendered)
        if (actor->Is3DLoaded()) {
            outPos = actor->GetPosition();
            return true;
        }

        // Fallback: ActorFinder position snapshot (captured on cell detach)
        auto pos = ActorFinder::GetInstance().GetActorLastKnownPosition(actor);
        if (pos.x != 0.0f || pos.y != 0.0f) {
            outPos = pos;
            return true;
        }

        return false;
    }

    bool ArrivalMonitor::GetDestinationPosition(const Destination& dest, RE::NiPoint3& outPos) const
    {
        if (std::holds_alternative<DestinationXY>(dest)) {
            // Raw XY coordinates — always available
            const auto& xy = std::get<DestinationXY>(dest);
            outPos = {xy.x, xy.y, 0.0f};
            return true;
        }

        // Destination is an ObjectReference
        const auto& ref = std::get<DestinationRef>(dest);
        auto* destForm = RE::TESForm::LookupByID<RE::TESObjectREFR>(ref.refFormID);
        if (!destForm) {
            return false;
        }

        // Try live position
        if (destForm->Is3DLoaded()) {
            outPos = destForm->GetPosition();
            return true;
        }

        // If the destination is an Actor, try ActorFinder snapshot
        auto* destActor = destForm->As<RE::Actor>();
        if (destActor) {
            auto pos = ActorFinder::GetInstance().GetActorLastKnownPosition(destActor);
            if (pos.x != 0.0f || pos.y != 0.0f) {
                outPos = pos;
                return true;
            }
        }

        // For non-actor refs (markers, doors): try GetPosition() even if not 3D loaded
        // Static markers often have valid position data from their placement in the cell
        auto pos = destForm->GetPosition();
        if (pos.x != 0.0f || pos.y != 0.0f) {
            outPos = pos;
            return true;
        }

        return false;
    }

    // ========================================================================
    // EVENT DISPATCH
    // ========================================================================

    void ArrivalMonitor::FireArrivalEvent(RE::FormID actorFormID, const std::string& callbackTag, float finalDistance)
    {
        // Copy data for the lambda (entry may be erased by the time the task runs)
        std::string tag = callbackTag;

        SKSE::GetTaskInterface()->AddTask([actorFormID, tag, finalDistance]() {
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(actorFormID);
            if (!actor) {
                SKSE::log::warn("ArrivalMonitor: Actor {:08X} no longer exists during event dispatch",
                    actorFormID);
                return;
            }

            auto* eventSource = SKSE::GetModCallbackEventSource();
            if (eventSource) {
                SKSE::ModCallbackEvent modEvent;
                modEvent.eventName = "SeverActionsNative_OnArrival";
                modEvent.strArg = tag;
                modEvent.numArg = finalDistance;
                modEvent.sender = actor;
                eventSource->SendEvent(&modEvent);

                SKSE::log::info("ArrivalMonitor: Sent OnArrival event for {} ({:08X}), tag='{}', dist={:.0f}",
                    actor->GetName(), actorFormID, tag, finalDistance);
            } else {
                SKSE::log::warn("ArrivalMonitor: Failed to get ModCallbackEventSource");
            }
        });
    }

    // ========================================================================
    // EVENT HANDLER
    // ========================================================================

    RE::BSEventNotifyControl ArrivalMonitor::ProcessEvent(
        RE::InputEvent* const*,
        RE::BSTEventSource<RE::InputEvent*>*)
    {
        // Input events fire every frame — use as heartbeat for periodic checks
        OnUpdate();
        return RE::BSEventNotifyControl::kContinue;
    }

    void ArrivalMonitor::OnUpdate()
    {
        // Throttle checks to every CHECK_INTERVAL_MS
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            now - m_lastCheckTime).count();
        if (elapsed < CHECK_INTERVAL_MS) {
            return;
        }
        m_lastCheckTime = now;

        CheckAllArrivals();
    }

    // ========================================================================
    // PAPYRUS WRAPPERS
    // ========================================================================

    void ArrivalMonitor::Papyrus_Register(RE::StaticFunctionTag*,
        RE::Actor* akActor, RE::TESObjectREFR* akDestination,
        float distanceThreshold, RE::BSFixedString callbackTag)
    {
        if (!akActor) {
            SKSE::log::warn("ArrivalMonitor: Papyrus_Register called with null actor");
            return;
        }
        if (!akDestination) {
            SKSE::log::warn("ArrivalMonitor: Papyrus_Register called with null destination");
            return;
        }

        GetSingleton()->Register(
            akActor->GetFormID(),
            akDestination->GetFormID(),
            distanceThreshold,
            callbackTag.data() ? callbackTag.data() : ""
        );
    }

    void ArrivalMonitor::Papyrus_RegisterXY(RE::StaticFunctionTag*,
        RE::Actor* akActor, float destX, float destY,
        float distanceThreshold, RE::BSFixedString callbackTag)
    {
        if (!akActor) {
            SKSE::log::warn("ArrivalMonitor: Papyrus_RegisterXY called with null actor");
            return;
        }

        GetSingleton()->RegisterXY(
            akActor->GetFormID(),
            destX, destY,
            distanceThreshold,
            callbackTag.data() ? callbackTag.data() : ""
        );
    }

    void ArrivalMonitor::Papyrus_Cancel(RE::StaticFunctionTag*, RE::Actor* akActor)
    {
        if (!akActor) {
            return;
        }
        GetSingleton()->Cancel(akActor->GetFormID());
    }

    bool ArrivalMonitor::Papyrus_IsTracked(RE::StaticFunctionTag*, RE::Actor* akActor)
    {
        if (!akActor) {
            return false;
        }
        return GetSingleton()->IsTracked(akActor->GetFormID());
    }

    float ArrivalMonitor::Papyrus_GetDistance(RE::StaticFunctionTag*, RE::Actor* akActor)
    {
        if (!akActor) {
            return -1.0f;
        }
        return GetSingleton()->GetDistance(akActor->GetFormID());
    }

    void ArrivalMonitor::Papyrus_ClearAll(RE::StaticFunctionTag*)
    {
        GetSingleton()->ClearAll();
    }

    int32_t ArrivalMonitor::Papyrus_GetTrackedCount(RE::StaticFunctionTag*)
    {
        return GetSingleton()->GetTrackedCount();
    }

    // ========================================================================
    // PAPYRUS REGISTRATION
    // ========================================================================

    void ArrivalMonitor::RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        a_vm->RegisterFunction("Arrival_Register",        scriptName, Papyrus_Register);
        a_vm->RegisterFunction("Arrival_RegisterXY",      scriptName, Papyrus_RegisterXY);
        a_vm->RegisterFunction("Arrival_Cancel",           scriptName, Papyrus_Cancel);
        a_vm->RegisterFunction("Arrival_IsTracked",        scriptName, Papyrus_IsTracked);
        a_vm->RegisterFunction("Arrival_GetDistance",      scriptName, Papyrus_GetDistance);
        a_vm->RegisterFunction("Arrival_ClearAll",         scriptName, Papyrus_ClearAll);
        a_vm->RegisterFunction("Arrival_GetTrackedCount",  scriptName, Papyrus_GetTrackedCount);

        SKSE::log::info("ArrivalMonitor: Registered Papyrus functions (7 arrival monitoring)");
    }
}
