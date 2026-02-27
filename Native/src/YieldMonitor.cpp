// SeverActionsNative - Yield Monitor Implementation
// TESHitEvent sink that monitors hits on surrendered actors.
// After threshold hits, reverts the surrender and fires a mod event
// for Papyrus to handle StorageUtil cleanup and faction restoration.
// Author: Severause

#include "YieldMonitor.h"

namespace SeverActionsNative
{
    YieldMonitor* YieldMonitor::GetSingleton()
    {
        static YieldMonitor singleton;
        return &singleton;
    }

    void YieldMonitor::Initialize()
    {
        if (m_initialized) {
            return;
        }

        // Register for hit events
        auto* eventSource = RE::ScriptEventSourceHolder::GetSingleton();
        if (eventSource) {
            eventSource->AddEventSink<RE::TESHitEvent>(this);
            SKSE::log::info("YieldMonitor: Registered for TESHitEvent");
        } else {
            SKSE::log::error("YieldMonitor: Failed to get ScriptEventSourceHolder");
            return;
        }

        m_initialized = true;
        SKSE::log::info("YieldMonitor initialized (hit threshold: {})", m_hitThreshold);
    }

    // ========================================================================
    // ACTOR TRACKING
    // ========================================================================

    void YieldMonitor::RegisterYieldedActor(RE::Actor* actor, float originalAggression,
                                            RE::TESFaction* surrenderedFaction)
    {
        if (!actor) {
            return;
        }

        // Cache the surrendered faction on first call
        if (!m_surrenderedFaction && surrenderedFaction) {
            m_surrenderedFaction = surrenderedFaction;
            SKSE::log::info("YieldMonitor: Cached SeverSurrenderedFaction {:X}",
                surrenderedFaction->GetFormID());
        }

        std::lock_guard<std::mutex> lock(m_mutex);

        RE::FormID actorID = actor->GetFormID();

        // Don't re-register if already monitored (reset hit count instead)
        auto it = m_yieldedActors.find(actorID);
        if (it != m_yieldedActors.end()) {
            it->second.hitCount = 0;
            it->second.originalAggression = originalAggression;
            SKSE::log::info("YieldMonitor: Re-registered {} ({:X}), reset hit count",
                actor->GetName(), actorID);
            return;
        }

        YieldedActorData data{
            .hitCount = 0,
            .originalAggression = originalAggression
        };

        m_yieldedActors[actorID] = data;

        SKSE::log::info("YieldMonitor: Registered {} ({:X}), originalAggression={:.1f}",
            actor->GetName(), actorID, originalAggression);
    }

    void YieldMonitor::UnregisterYieldedActor(RE::Actor* actor)
    {
        if (!actor) {
            return;
        }

        std::lock_guard<std::mutex> lock(m_mutex);

        RE::FormID actorID = actor->GetFormID();
        auto it = m_yieldedActors.find(actorID);
        if (it != m_yieldedActors.end()) {
            m_yieldedActors.erase(it);
            SKSE::log::info("YieldMonitor: Unregistered {} ({:X})",
                actor->GetName(), actorID);
        }
    }

    bool YieldMonitor::IsMonitored(RE::Actor* actor)
    {
        if (!actor) {
            return false;
        }

        std::lock_guard<std::mutex> lock(m_mutex);
        return m_yieldedActors.contains(actor->GetFormID());
    }

    int YieldMonitor::GetHitCount(RE::Actor* actor)
    {
        if (!actor) {
            return 0;
        }

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_yieldedActors.find(actor->GetFormID());
        if (it != m_yieldedActors.end()) {
            return it->second.hitCount;
        }
        return 0;
    }

    void YieldMonitor::SetHitThreshold(int threshold)
    {
        if (threshold < 1) {
            threshold = 1;
        }
        m_hitThreshold = threshold;
        SKSE::log::info("YieldMonitor: Hit threshold set to {}", m_hitThreshold);
    }

    void YieldMonitor::ClearAll()
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_yieldedActors.clear();
        SKSE::log::info("YieldMonitor: Cleared all tracked actors");
    }

    // ========================================================================
    // HIT EVENT HANDLER
    // ========================================================================

    RE::BSEventNotifyControl YieldMonitor::ProcessEvent(
        const RE::TESHitEvent* a_event,
        RE::BSTEventSource<RE::TESHitEvent>*)
    {
        if (!a_event) {
            return RE::BSEventNotifyControl::kContinue;
        }

        // Fast path: if no actors are being monitored, skip everything
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            if (m_yieldedActors.empty()) {
                return RE::BSEventNotifyControl::kContinue;
            }
        }

        // Get the target actor
        auto target = a_event->target.get();
        if (!target) {
            return RE::BSEventNotifyControl::kContinue;
        }

        auto* targetActor = target->As<RE::Actor>();
        if (!targetActor) {
            return RE::BSEventNotifyControl::kContinue;
        }

        RE::FormID targetID = targetActor->GetFormID();

        // Check if this actor is in our yield-monitoring map
        YieldedActorData data;
        bool shouldRevert = false;

        {
            std::lock_guard<std::mutex> lock(m_mutex);

            auto it = m_yieldedActors.find(targetID);
            if (it == m_yieldedActors.end()) {
                // Not a yielded actor we're tracking — ignore
                return RE::BSEventNotifyControl::kContinue;
            }

            // Increment hit count
            it->second.hitCount++;

            SKSE::log::debug("YieldMonitor: {} hit count now {} / {}",
                targetActor->GetName(), it->second.hitCount, m_hitThreshold);

            // Check threshold
            if (it->second.hitCount >= m_hitThreshold) {
                // Copy data before we modify the map
                data = it->second;
                shouldRevert = true;
                // Remove from tracking immediately to prevent double-trigger
                m_yieldedActors.erase(it);
            }
        }

        // Revert surrender outside the lock to avoid deadlock from mod events
        if (shouldRevert) {
            SKSE::log::info("YieldMonitor: Yield broken for {} ({:X}) after {} hits",
                targetActor->GetName(), targetID, data.hitCount);
            RevertSurrender(targetActor, data);
        }

        return RE::BSEventNotifyControl::kContinue;
    }

    // ========================================================================
    // SURRENDER REVERT
    // ========================================================================

    void YieldMonitor::RevertSurrender(RE::Actor* actor, const YieldedActorData& data)
    {
        if (!actor) {
            return;
        }

        // ================================================================
        // STEP 1: Restore aggression (instant, engine-level)
        // This is the critical part — without aggression, the NPC won't fight
        // Use AsActorValueOwner() for AE compatibility
        // ================================================================
        float aggressionToRestore = data.originalAggression;
        if (aggressionToRestore <= 0.0f) {
            // Default to 1 (Aggressive) if stored value was 0 or invalid
            aggressionToRestore = 1.0f;
        }
        auto* avOwner = actor->AsActorValueOwner();
        if (avOwner) {
            avOwner->SetActorValue(RE::ActorValue::kAggression, aggressionToRestore);
            SKSE::log::info("YieldMonitor: Restored aggression for {} to {:.1f}",
                actor->GetName(), aggressionToRestore);
        }

        // ================================================================
        // STEP 2: Remove from SeverSurrenderedFaction (if cached)
        // Setting rank to -1 is equivalent to Papyrus RemoveFromFaction
        // ================================================================
        if (m_surrenderedFaction && actor->IsInFaction(m_surrenderedFaction)) {
            actor->AddToFaction(m_surrenderedFaction, -1);
            SKSE::log::info("YieldMonitor: Removed {} from SeverSurrenderedFaction",
                actor->GetName());
        }

        // ================================================================
        // STEP 3: Re-evaluate AI packages
        // With aggression restored and hostile faction back, the engine
        // should trigger combat against the player
        // ================================================================
        actor->EvaluatePackage();

        // ================================================================
        // STEP 4: Fire mod event for Papyrus cleanup
        // Papyrus handles: restore hostile factions from StorageUtil,
        // clean up keys, set YieldBroken flag, fire SkyrimNet event
        // ================================================================
        auto* eventSource = SKSE::GetModCallbackEventSource();
        if (eventSource) {
            SKSE::ModCallbackEvent modEvent;
            modEvent.eventName = "SeverActionsNative_YieldBroken";
            modEvent.strArg = "";
            modEvent.numArg = 0.0f;
            modEvent.sender = actor;
            eventSource->SendEvent(&modEvent);

            SKSE::log::info("YieldMonitor: Sent YieldBroken event for {} ({:X})",
                actor->GetName(), actor->GetFormID());
        } else {
            SKSE::log::warn("YieldMonitor: Failed to get ModCallbackEventSource");
        }
    }

    // ========================================================================
    // PAPYRUS WRAPPERS
    // ========================================================================

    void YieldMonitor::Papyrus_RegisterYieldedActor(RE::StaticFunctionTag*,
        RE::Actor* actor, float originalAggression, RE::TESFaction* surrenderedFaction)
    {
        GetSingleton()->RegisterYieldedActor(actor, originalAggression, surrenderedFaction);
    }

    void YieldMonitor::Papyrus_UnregisterYieldedActor(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        GetSingleton()->UnregisterYieldedActor(actor);
    }

    bool YieldMonitor::Papyrus_IsYieldMonitored(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->IsMonitored(actor);
    }

    int32_t YieldMonitor::Papyrus_GetYieldHitCount(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return static_cast<int32_t>(GetSingleton()->GetHitCount(actor));
    }

    void YieldMonitor::Papyrus_SetYieldHitThreshold(RE::StaticFunctionTag*, int32_t threshold)
    {
        GetSingleton()->SetHitThreshold(static_cast<int>(threshold));
    }

    // ========================================================================
    // PAPYRUS REGISTRATION
    // ========================================================================

    void YieldMonitor::RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        a_vm->RegisterFunction("RegisterYieldedActor", scriptName, Papyrus_RegisterYieldedActor);
        a_vm->RegisterFunction("UnregisterYieldedActor", scriptName, Papyrus_UnregisterYieldedActor);
        a_vm->RegisterFunction("IsYieldMonitored", scriptName, Papyrus_IsYieldMonitored);
        a_vm->RegisterFunction("GetYieldHitCount", scriptName, Papyrus_GetYieldHitCount);
        a_vm->RegisterFunction("SetYieldHitThreshold", scriptName, Papyrus_SetYieldHitThreshold);

        SKSE::log::info("YieldMonitor: Registered Papyrus functions");
    }
}
