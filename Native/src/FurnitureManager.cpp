// SeverActionsNative - Furniture Manager Implementation
// Author: Severause

#include "FurnitureManager.h"

namespace SeverActionsNative
{
    FurnitureManager* FurnitureManager::GetSingleton()
    {
        static FurnitureManager singleton;
        return &singleton;
    }

    void FurnitureManager::Initialize()
    {
        if (m_initialized) {
            return;
        }

        // Register for cell events
        auto* eventSource1 = RE::ScriptEventSourceHolder::GetSingleton();
        if (eventSource1) {
            eventSource1->AddEventSink<RE::TESCellFullyLoadedEvent>(this);
            eventSource1->AddEventSink<RE::TESCellAttachDetachEvent>(this);
            SKSE::log::info("FurnitureManager: Registered for cell events");
        }

        // Register for menu events (backup for periodic updates)
        auto* ui = RE::UI::GetSingleton();
        if (ui) {
            ui->AddEventSink<RE::MenuOpenCloseEvent>(this);
            SKSE::log::info("FurnitureManager: Registered for menu events");
        }

        // Register for input events (fires every frame - most reliable update mechanism)
        auto* inputDeviceManager = RE::BSInputDeviceManager::GetSingleton();
        if (inputDeviceManager) {
            inputDeviceManager->AddEventSink(this);
            SKSE::log::info("FurnitureManager: Registered for input events");
        }

        m_lastUpdateTime = std::chrono::steady_clock::now();
        m_initialized = true;
        SKSE::log::info("FurnitureManager initialized");
    }

    bool FurnitureManager::RegisterFurnitureUser(
        RE::Actor* actor,
        RE::TESPackage* package,
        RE::TESObjectREFR* furniture,
        RE::BGSKeyword* linkedRefKeyword,
        float autoStandDistance)
    {
        if (!actor || !package) {
            SKSE::log::warn("FurnitureManager::RegisterFurnitureUser - Invalid actor or package");
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

        FurnitureUserData data{
            .actorFormID = actorID,
            .packageFormID = package->GetFormID(),
            .furnitureFormID = furniture ? furniture->GetFormID() : 0,
            .linkedRefKeywordFormID = linkedRefKeyword ? linkedRefKeyword->GetFormID() : 0,
            .autoStandDistance = autoStandDistance > 0 ? autoStandDistance : m_defaultAutoStandDistance,
            .registeredCellFormID = currentCellID
        };

        m_registeredActors[actorID] = data;

        SKSE::log::info("FurnitureManager: Registered actor {:X} with distance threshold {:.0f}",
            actorID, data.autoStandDistance);

        return true;
    }

    void FurnitureManager::UnregisterFurnitureUser(RE::Actor* actor)
    {
        if (!actor) {
            return;
        }

        std::lock_guard<std::mutex> lock(m_mutex);

        RE::FormID actorID = actor->GetFormID();
        auto it = m_registeredActors.find(actorID);
        if (it != m_registeredActors.end()) {
            m_registeredActors.erase(it);
            SKSE::log::info("FurnitureManager: Unregistered actor {:X}", actorID);
        }
    }

    void FurnitureManager::CleanupActor(RE::Actor* actor, const FurnitureUserData& data)
    {
        if (!actor) {
            return;
        }

        SKSE::log::info("FurnitureManager: Cleaning up actor {:X} (package {:X})",
            actor->GetFormID(), data.packageFormID);

        // Use SKSE's task interface to dispatch cleanup on the game thread
        // This ensures we're in a safe context for game state modifications
        SKSE::GetTaskInterface()->AddTask([actorFormID = actor->GetFormID(),
                                           packageFormID = data.packageFormID,
                                           keywordFormID = data.linkedRefKeywordFormID]() {
            // Re-lookup actor since we're now on a different thread/time
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(actorFormID);
            if (!actor) {
                SKSE::log::warn("FurnitureManager: Actor {:X} no longer exists during cleanup", actorFormID);
                return;
            }

            // Send mod event for Papyrus to handle the actual cleanup
            // The Papyrus script will call ActorUtil.RemovePackageOverride
            auto* eventSource = SKSE::GetModCallbackEventSource();
            if (eventSource) {
                SKSE::ModCallbackEvent modEvent;
                modEvent.eventName = "SeverActionsNative_FurnitureCleanup";
                modEvent.strArg = "";
                modEvent.numArg = static_cast<float>(actorFormID);
                modEvent.sender = actor;
                eventSource->SendEvent(&modEvent);

                SKSE::log::info("FurnitureManager: Sent cleanup event for actor {:X}", actorFormID);
            }

            // Always call EvaluatePackage to make the actor re-evaluate their AI
            actor->EvaluatePackage();

            SKSE::log::info("FurnitureManager: Called EvaluatePackage for actor {:X}", actorFormID);
        });
    }

    void FurnitureManager::ForceAllStandUp()
    {
        // Snapshot and clear under lock, then cleanup outside lock
        std::vector<FurnitureUserData> snapshot;
        {
            std::lock_guard<std::mutex> lock(m_mutex);

            SKSE::log::info("FurnitureManager: Forcing all {} registered actors to stand up",
                m_registeredActors.size());

            snapshot.reserve(m_registeredActors.size());
            for (auto& [formID, data] : m_registeredActors) {
                snapshot.push_back(data);
            }
            m_registeredActors.clear();
        }

        // Dispatch cleanup without holding the lock
        for (auto& data : snapshot) {
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(data.actorFormID);
            if (actor) {
                CleanupActor(actor, data);
            }
        }
    }

    bool FurnitureManager::IsRegistered(RE::Actor* actor)
    {
        if (!actor) {
            return false;
        }

        std::lock_guard<std::mutex> lock(m_mutex);
        return m_registeredActors.contains(actor->GetFormID());
    }

    void FurnitureManager::ProcessDistanceChecks()
    {
        auto* player = RE::PlayerCharacter::GetSingleton();
        if (!player) {
            return;
        }

        RE::NiPoint3 playerPos = player->GetPosition();

        // Snapshot registered data under the lock, then release it
        // so the expensive LookupByID / distance math runs lock-free
        std::vector<FurnitureUserData> snapshot;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            if (m_registeredActors.empty()) return;
            snapshot.reserve(m_registeredActors.size());
            for (auto& [formID, data] : m_registeredActors) {
                snapshot.push_back(data);
            }
        }

        // Evaluate each actor without holding the lock
        std::vector<RE::FormID> toCleanup;

        for (auto& data : snapshot) {
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(data.actorFormID);
            if (!actor) {
                // Actor no longer exists
                toCleanup.push_back(data.actorFormID);
                continue;
            }

            // Check if actor is dead or in combat
            if (actor->IsDead() || actor->IsInCombat()) {
                toCleanup.push_back(data.actorFormID);
                continue;
            }

            // Check distance
            RE::NiPoint3 actorPos = actor->GetPosition();
            float dx = playerPos.x - actorPos.x;
            float dy = playerPos.y - actorPos.y;
            float dz = playerPos.z - actorPos.z;
            float distSq = dx * dx + dy * dy + dz * dz;
            float thresholdSq = data.autoStandDistance * data.autoStandDistance;

            if (distSq > thresholdSq) {
                SKSE::log::info("FurnitureManager: Actor {:X} exceeded distance threshold ({:.0f} > {:.0f})",
                    data.actorFormID, std::sqrt(distSq), data.autoStandDistance);
                toCleanup.push_back(data.actorFormID);
            }
        }

        // Re-acquire lock only for the cleanup/removal phase
        if (!toCleanup.empty()) {
            std::lock_guard<std::mutex> lock(m_mutex);
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
    }

    RE::BSEventNotifyControl FurnitureManager::ProcessEvent(
        const RE::TESCellFullyLoadedEvent* a_event,
        RE::BSTEventSource<RE::TESCellFullyLoadedEvent>*)
    {
        if (!a_event || !a_event->cell) {
            return RE::BSEventNotifyControl::kContinue;
        }

        // Check if this is the player's cell
        auto* player = RE::PlayerCharacter::GetSingleton();
        if (!player) {
            return RE::BSEventNotifyControl::kContinue;
        }

        auto* playerCell = player->GetParentCell();
        if (!playerCell || playerCell != a_event->cell) {
            return RE::BSEventNotifyControl::kContinue;
        }

        RE::FormID newCellID = a_event->cell->GetFormID();

        // Check if cell actually changed
        if (m_lastPlayerCellFormID != 0 && m_lastPlayerCellFormID != newCellID) {
            SKSE::log::info("FurnitureManager: Player cell changed from {:X} to {:X}",
                m_lastPlayerCellFormID, newCellID);

            // Force all registered actors to stand up
            ForceAllStandUp();
        }

        m_lastPlayerCellFormID = newCellID;

        return RE::BSEventNotifyControl::kContinue;
    }

    RE::BSEventNotifyControl FurnitureManager::ProcessEvent(
        const RE::TESCellAttachDetachEvent* a_event,
        RE::BSTEventSource<RE::TESCellAttachDetachEvent>*)
    {
        // This event fires when cells attach/detach during loading
        // We use it as a backup for cell change detection
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

    RE::BSEventNotifyControl FurnitureManager::ProcessEvent(
        const RE::MenuOpenCloseEvent* a_event,
        RE::BSTEventSource<RE::MenuOpenCloseEvent>*)
    {
        // Menu events - backup trigger for updates
        if (!a_event) {
            return RE::BSEventNotifyControl::kContinue;
        }

        OnUpdate();
        return RE::BSEventNotifyControl::kContinue;
    }

    RE::BSEventNotifyControl FurnitureManager::ProcessEvent(
        RE::InputEvent* const* a_event,
        RE::BSTEventSource<RE::InputEvent*>*)
    {
        // Input events fire every frame - this is our main update mechanism
        // We don't care about the actual input, just use it as a heartbeat
        OnUpdate();
        return RE::BSEventNotifyControl::kContinue;
    }

    void FurnitureManager::OnUpdate()
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
                    SKSE::log::info("FurnitureManager: OnUpdate detected cell change {:X} -> {:X}",
                        m_lastPlayerCellFormID, currentCellID);
                    ForceAllStandUp();
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

    bool FurnitureManager::Papyrus_RegisterFurnitureUser(
        RE::StaticFunctionTag*,
        RE::Actor* actor,
        RE::TESPackage* package,
        RE::TESObjectREFR* furniture,
        RE::BGSKeyword* linkedRefKeyword,
        float autoStandDistance)
    {
        return GetSingleton()->RegisterFurnitureUser(
            actor, package, furniture, linkedRefKeyword, autoStandDistance);
    }

    void FurnitureManager::Papyrus_UnregisterFurnitureUser(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        GetSingleton()->UnregisterFurnitureUser(actor);
    }

    void FurnitureManager::Papyrus_ForceAllStandUp(RE::StaticFunctionTag*)
    {
        GetSingleton()->ForceAllStandUp();
    }

    bool FurnitureManager::Papyrus_IsRegistered(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->IsRegistered(actor);
    }

    float FurnitureManager::Papyrus_GetDefaultAutoStandDistance(RE::StaticFunctionTag*)
    {
        return GetSingleton()->GetDefaultAutoStandDistance();
    }

    void FurnitureManager::Papyrus_SetDefaultAutoStandDistance(RE::StaticFunctionTag*, float distance)
    {
        GetSingleton()->SetDefaultAutoStandDistance(distance);
    }

    int32_t FurnitureManager::Papyrus_GetRegisteredCount(RE::StaticFunctionTag*)
    {
        auto* mgr = GetSingleton();
        std::lock_guard<std::mutex> lock(mgr->m_mutex);
        return static_cast<int32_t>(mgr->m_registeredActors.size());
    }

    void FurnitureManager::RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        a_vm->RegisterFunction("RegisterFurnitureUser", scriptName, Papyrus_RegisterFurnitureUser);
        a_vm->RegisterFunction("UnregisterFurnitureUser", scriptName, Papyrus_UnregisterFurnitureUser);
        a_vm->RegisterFunction("ForceAllFurnitureUsersStandUp", scriptName, Papyrus_ForceAllStandUp);
        a_vm->RegisterFunction("IsFurnitureUserRegistered", scriptName, Papyrus_IsRegistered);
        a_vm->RegisterFunction("GetDefaultAutoStandDistance", scriptName, Papyrus_GetDefaultAutoStandDistance);
        a_vm->RegisterFunction("SetDefaultAutoStandDistance", scriptName, Papyrus_SetDefaultAutoStandDistance);
        a_vm->RegisterFunction("GetFurnitureUserCount", scriptName, Papyrus_GetRegisteredCount);

        SKSE::log::info("Registered FurnitureManager Papyrus functions");
    }
}
