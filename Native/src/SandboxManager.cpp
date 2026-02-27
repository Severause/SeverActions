// SeverActionsNative - Sandbox Manager Implementation
// Author: Severause

#include "SandboxManager.h"

namespace SeverActionsNative
{
    SandboxManager* SandboxManager::GetSingleton()
    {
        static SandboxManager singleton;
        return &singleton;
    }

    void SandboxManager::Initialize()
    {
        if (m_initialized) {
            return;
        }

        // Register for cell events
        auto* eventSource = RE::ScriptEventSourceHolder::GetSingleton();
        if (eventSource) {
            eventSource->AddEventSink<RE::TESCellFullyLoadedEvent>(this);
            eventSource->AddEventSink<RE::TESCellAttachDetachEvent>(this);
            SKSE::log::info("SandboxManager: Registered for cell events");
        }

        // Register for input events (fires every frame - most reliable update mechanism)
        auto* inputDeviceManager = RE::BSInputDeviceManager::GetSingleton();
        if (inputDeviceManager) {
            inputDeviceManager->AddEventSink(this);
            SKSE::log::info("SandboxManager: Registered for input events");
        }

        m_lastUpdateTime = std::chrono::steady_clock::now();
        m_initialized = true;
        SKSE::log::info("SandboxManager initialized");
    }

    bool SandboxManager::RegisterSandboxUser(
        RE::Actor* actor,
        RE::TESPackage* package,
        float autoStandDistance)
    {
        if (!actor || !package) {
            SKSE::log::warn("SandboxManager::RegisterSandboxUser - Invalid actor or package");
            return false;
        }

        std::lock_guard<std::mutex> lock(m_mutex);

        RE::FormID actorID = actor->GetFormID();

        // Get player's current cell for tracking
        RE::FormID currentCellID = 0;
        auto* player = RE::PlayerCharacter::GetSingleton();
        if (player && player->GetParentCell()) {
            currentCellID = player->GetParentCell()->GetFormID();
        }

        SandboxUserData data{
            .actorFormID = actorID,
            .packageFormID = package->GetFormID(),
            .autoStandDistance = autoStandDistance > 0 ? autoStandDistance : 2000.0f,
            .registeredCellFormID = currentCellID
        };

        m_registeredActors[actorID] = data;

        SKSE::log::info("SandboxManager: Registered actor {:X} with distance threshold {:.0f}",
            actorID, data.autoStandDistance);

        return true;
    }

    void SandboxManager::UnregisterSandboxUser(RE::Actor* actor)
    {
        if (!actor) {
            return;
        }

        std::lock_guard<std::mutex> lock(m_mutex);

        RE::FormID actorID = actor->GetFormID();
        auto it = m_registeredActors.find(actorID);
        if (it != m_registeredActors.end()) {
            m_registeredActors.erase(it);
            SKSE::log::info("SandboxManager: Unregistered actor {:X}", actorID);
        }
    }

    void SandboxManager::CleanupActor(RE::Actor* actor, const SandboxUserData& data)
    {
        if (!actor) {
            return;
        }

        SKSE::log::info("SandboxManager: Cleaning up actor {:X} (package {:X})",
            actor->GetFormID(), data.packageFormID);

        // Dispatch cleanup on the game thread
        SKSE::GetTaskInterface()->AddTask([actorFormID = actor->GetFormID()]() {
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(actorFormID);
            if (!actor) {
                SKSE::log::warn("SandboxManager: Actor {:X} no longer exists during cleanup", actorFormID);
                return;
            }

            // Send mod event for Papyrus to handle the actual cleanup
            auto* eventSource = SKSE::GetModCallbackEventSource();
            if (eventSource) {
                SKSE::ModCallbackEvent modEvent;
                modEvent.eventName = "SeverActionsNative_SandboxCleanup";
                modEvent.strArg = "";
                modEvent.numArg = static_cast<float>(actorFormID);
                modEvent.sender = actor;
                eventSource->SendEvent(&modEvent);

                SKSE::log::info("SandboxManager: Sent cleanup event for actor {:X}", actorFormID);
            }

            actor->EvaluatePackage();

            SKSE::log::info("SandboxManager: Called EvaluatePackage for actor {:X}", actorFormID);
        });
    }

    void SandboxManager::ForceAllStopSandbox()
    {
        std::lock_guard<std::mutex> lock(m_mutex);

        SKSE::log::info("SandboxManager: Forcing all {} registered actors to stop sandbox",
            m_registeredActors.size());

        for (auto& [formID, data] : m_registeredActors) {
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(formID);
            if (actor) {
                CleanupActor(actor, data);
            }
        }

        m_registeredActors.clear();
    }

    bool SandboxManager::IsRegistered(RE::Actor* actor)
    {
        if (!actor) {
            return false;
        }

        std::lock_guard<std::mutex> lock(m_mutex);
        return m_registeredActors.contains(actor->GetFormID());
    }

    int32_t SandboxManager::GetRegisteredCount()
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        return static_cast<int32_t>(m_registeredActors.size());
    }

    void SandboxManager::ProcessDistanceChecks()
    {
        auto* player = RE::PlayerCharacter::GetSingleton();
        if (!player) {
            return;
        }

        RE::NiPoint3 playerPos = player->GetPosition();
        RE::TESObjectCELL* playerCell = player->GetParentCell();
        RE::FormID playerCellID = playerCell ? playerCell->GetFormID() : 0;

        std::lock_guard<std::mutex> lock(m_mutex);

        // Collect actors to cleanup (can't modify map while iterating)
        std::vector<RE::FormID> toCleanup;

        for (auto& [formID, data] : m_registeredActors) {
            // Primary cell check: compare player's current cell against where
            // the actor was registered. This works even if the actor is unloaded.
            if (playerCellID != 0 && data.registeredCellFormID != 0 &&
                playerCellID != data.registeredCellFormID) {
                SKSE::log::info("SandboxManager: Actor {:X} - player left registered cell ({:X} -> {:X})",
                    formID, data.registeredCellFormID, playerCellID);
                toCleanup.push_back(formID);
                continue;
            }

            auto* actor = RE::TESForm::LookupByID<RE::Actor>(formID);
            if (!actor) {
                toCleanup.push_back(formID);
                continue;
            }

            // Check if actor is dead or in combat
            if (actor->IsDead() || actor->IsInCombat()) {
                toCleanup.push_back(formID);
                continue;
            }

            // Secondary cell check: actor's actual cell vs player's cell
            // Catches cases where actor wandered into a different cell
            RE::TESObjectCELL* actorCell = actor->GetParentCell();
            if (playerCell && actorCell && playerCell != actorCell) {
                SKSE::log::info("SandboxManager: Actor {:X} in different cell than player",
                    formID);
                toCleanup.push_back(formID);
                continue;
            }

            // Actor cell unloaded but player cell is valid - actor left behind
            if (playerCell && !actorCell) {
                SKSE::log::info("SandboxManager: Actor {:X} cell unloaded, cleaning up",
                    formID);
                toCleanup.push_back(formID);
                continue;
            }

            // Same cell - check distance
            RE::NiPoint3 actorPos = actor->GetPosition();
            float dx = playerPos.x - actorPos.x;
            float dy = playerPos.y - actorPos.y;
            float dz = playerPos.z - actorPos.z;
            float distSq = dx * dx + dy * dy + dz * dz;
            float thresholdSq = data.autoStandDistance * data.autoStandDistance;

            if (distSq > thresholdSq) {
                SKSE::log::info("SandboxManager: Actor {:X} exceeded distance threshold ({:.0f} > {:.0f})",
                    formID, std::sqrt(distSq), data.autoStandDistance);
                toCleanup.push_back(formID);
            }
        }

        // Cleanup collected actors
        for (RE::FormID formID : toCleanup) {
            auto it = m_registeredActors.find(formID);
            if (it != m_registeredActors.end()) {
                auto* actor = RE::TESForm::LookupByID<RE::Actor>(formID);
                if (actor) {
                    CleanupActor(actor, it->second);
                }
                m_registeredActors.erase(it);
            }
        }
    }

    RE::BSEventNotifyControl SandboxManager::ProcessEvent(
        const RE::TESCellFullyLoadedEvent* a_event,
        RE::BSTEventSource<RE::TESCellFullyLoadedEvent>*)
    {
        if (!a_event || !a_event->cell) {
            return RE::BSEventNotifyControl::kContinue;
        }

        // Update last known player cell if this is the player's cell
        auto* player = RE::PlayerCharacter::GetSingleton();
        if (player) {
            auto* playerCell = player->GetParentCell();
            if (playerCell && playerCell == a_event->cell) {
                RE::FormID newCellID = playerCell->GetFormID();
                if (m_lastPlayerCellFormID != 0 && m_lastPlayerCellFormID != newCellID) {
                    SKSE::log::info("SandboxManager: Player cell changed from {:X} to {:X}",
                        m_lastPlayerCellFormID, newCellID);
                    ForceAllStopSandbox();
                }
                m_lastPlayerCellFormID = newCellID;
            }
        }

        // Also run distance/cell checks on any cell load - catches transitions
        // where playerCell hasn't updated yet but the new cell is loading
        ProcessDistanceChecks();

        return RE::BSEventNotifyControl::kContinue;
    }

    RE::BSEventNotifyControl SandboxManager::ProcessEvent(
        const RE::TESCellAttachDetachEvent* a_event,
        RE::BSTEventSource<RE::TESCellAttachDetachEvent>*)
    {
        if (!a_event) {
            return RE::BSEventNotifyControl::kContinue;
        }

        // Only care about attach events
        if (!a_event->attached) {
            return RE::BSEventNotifyControl::kContinue;
        }

        // Process distance checks whenever a cell attaches
        // This handles exterior cell transitions smoothly
        ProcessDistanceChecks();

        return RE::BSEventNotifyControl::kContinue;
    }

    RE::BSEventNotifyControl SandboxManager::ProcessEvent(
        RE::InputEvent* const*,
        RE::BSTEventSource<RE::InputEvent*>*)
    {
        // Input events fire every frame - use as heartbeat for periodic checks
        OnUpdate();
        return RE::BSEventNotifyControl::kContinue;
    }

    void SandboxManager::OnUpdate()
    {
        // Skip if no registered actors
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            if (m_registeredActors.empty()) {
                return;
            }
        }

        // Throttle updates to every UPDATE_INTERVAL_MS
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - m_lastUpdateTime).count();
        if (elapsed < UPDATE_INTERVAL_MS) {
            return;
        }
        m_lastUpdateTime = now;

        // Check for cell changes
        auto* player = RE::PlayerCharacter::GetSingleton();
        if (player) {
            auto* playerCell = player->GetParentCell();
            if (playerCell) {
                RE::FormID currentCellID = playerCell->GetFormID();
                if (m_lastPlayerCellFormID != 0 && m_lastPlayerCellFormID != currentCellID) {
                    SKSE::log::info("SandboxManager: OnUpdate detected cell change {:X} -> {:X}",
                        m_lastPlayerCellFormID, currentCellID);
                    ForceAllStopSandbox();
                }
                m_lastPlayerCellFormID = currentCellID;
            }
        }

        // Process distance checks
        ProcessDistanceChecks();
    }

    // ========================================================================
    // PAPYRUS NATIVE FUNCTION WRAPPERS
    // ========================================================================

    bool SandboxManager::Papyrus_RegisterSandboxUser(
        RE::StaticFunctionTag*,
        RE::Actor* actor,
        RE::TESPackage* package,
        float autoStandDistance)
    {
        return GetSingleton()->RegisterSandboxUser(actor, package, autoStandDistance);
    }

    void SandboxManager::Papyrus_UnregisterSandboxUser(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        GetSingleton()->UnregisterSandboxUser(actor);
    }

    void SandboxManager::Papyrus_ForceAllStopSandbox(RE::StaticFunctionTag*)
    {
        GetSingleton()->ForceAllStopSandbox();
    }

    bool SandboxManager::Papyrus_IsRegistered(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->IsRegistered(actor);
    }

    int32_t SandboxManager::Papyrus_GetRegisteredCount(RE::StaticFunctionTag*)
    {
        return GetSingleton()->GetRegisteredCount();
    }

    void SandboxManager::RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        a_vm->RegisterFunction("RegisterSandboxUser", scriptName, Papyrus_RegisterSandboxUser);
        a_vm->RegisterFunction("UnregisterSandboxUser", scriptName, Papyrus_UnregisterSandboxUser);
        a_vm->RegisterFunction("ForceAllSandboxUsersStop", scriptName, Papyrus_ForceAllStopSandbox);
        a_vm->RegisterFunction("IsSandboxUserRegistered", scriptName, Papyrus_IsRegistered);
        a_vm->RegisterFunction("GetSandboxUserCount", scriptName, Papyrus_GetRegisteredCount);

        SKSE::log::info("Registered SandboxManager Papyrus functions");
    }
}
