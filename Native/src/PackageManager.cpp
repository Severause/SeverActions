// SeverActionsNative - Package Manager Implementation
// Native LinkedRef management with SKSE cosave persistence.
// Replaces PO3_SKSEFunctions.SetLinkedRef with auto-tracking and restore.
//
// Author: Severause

#include "PackageManager.h"

namespace SeverActionsNative
{
    PackageManager* PackageManager::GetSingleton()
    {
        static PackageManager singleton;
        return &singleton;
    }

    void PackageManager::Initialize()
    {
        if (m_initialized) {
            return;
        }

        // Register for death events — auto-cleanup tracked entries on actor death
        auto* eventSource = RE::ScriptEventSourceHolder::GetSingleton();
        if (eventSource) {
            eventSource->AddEventSink<RE::TESDeathEvent>(this);
            SKSE::log::info("PackageManager: Registered for TESDeathEvent");
        } else {
            SKSE::log::error("PackageManager: Failed to get ScriptEventSourceHolder");
            return;
        }

        m_initialized = true;
        SKSE::log::info("PackageManager: Initialized — cosave persistence active");
    }

    // ========================================================================
    // NATIVE LINKED REF MANIPULATION
    // ========================================================================

    void PackageManager::NativeSetLinkedRef(RE::TESObjectREFR* ref,
        RE::TESObjectREFR* target, RE::BGSKeyword* keyword)
    {
        if (!ref || !keyword) return;

        // Call the engine's native SetLinkedRef via address library relocation.
        // This is the same approach PO3_SKSEFunctions uses — the engine handles
        // ExtraLinkedRef creation/modification/clearing internally and safely.
        // Our previous manual approach (BSExtraData::Create + ExtraDataList::Add)
        // crashed because Create() zero-initializes without calling the constructor,
        // leaving BSTSmallArray in an invalid state.
        using func_t = void(RE::ExtraDataList::*)(RE::TESObjectREFR*, RE::BGSKeyword*);
        static REL::Relocation<func_t> SetLinkedRef{ RELOCATION_ID(11633, 11779) };
        SetLinkedRef(&ref->extraList, target, keyword);
    }

    // ========================================================================
    // LINKED REF OPERATIONS
    // ========================================================================

    void PackageManager::LinkedRef_Set(RE::Actor* actor, RE::TESObjectREFR* target, RE::BGSKeyword* keyword)
    {
        if (!actor || !target || !keyword) return;

        RE::FormID actorID = actor->GetFormID();
        RE::FormID targetID = target->GetFormID();
        RE::FormID keywordID = keyword->GetFormID();

        // Set the native LinkedRef on the actor
        NativeSetLinkedRef(actor, target, keyword);

        // Track for cosave persistence
        {
            std::lock_guard<std::mutex> lock(m_mutex);

            auto& entries = m_tracked[actorID];

            // Update existing entry for this keyword, or add new
            for (auto& entry : entries) {
                if (entry.keywordFormID == keywordID) {
                    entry.targetFormID = targetID;
                    SKSE::log::info("PackageManager: LinkedRef_Set updated {:08X} -> {:08X} (keyword: {:08X})",
                        actorID, targetID, keywordID);
                    return;
                }
            }

            entries.push_back({ actorID, targetID, keywordID });
        }

        SKSE::log::info("PackageManager: LinkedRef_Set {:08X} -> {:08X} (keyword: {:08X})",
            actorID, targetID, keywordID);
    }

    void PackageManager::LinkedRef_Clear(RE::Actor* actor, RE::BGSKeyword* keyword)
    {
        if (!actor || !keyword) return;

        RE::FormID actorID = actor->GetFormID();
        RE::FormID keywordID = keyword->GetFormID();

        // Clear the native LinkedRef
        NativeSetLinkedRef(actor, nullptr, keyword);

        // Remove from tracking
        {
            std::lock_guard<std::mutex> lock(m_mutex);

            auto it = m_tracked.find(actorID);
            if (it != m_tracked.end()) {
                auto& entries = it->second;
                for (auto entryIt = entries.begin(); entryIt != entries.end(); ++entryIt) {
                    if (entryIt->keywordFormID == keywordID) {
                        entries.erase(entryIt);
                        break;
                    }
                }

                // Clean up empty actor entries
                if (entries.empty()) {
                    m_tracked.erase(it);
                }
            }
        }

        SKSE::log::info("PackageManager: LinkedRef_Clear {:08X} (keyword: {:08X})",
            actorID, keywordID);
    }

    void PackageManager::LinkedRef_ClearAll(RE::Actor* actor)
    {
        if (!actor) return;

        RE::FormID actorID = actor->GetFormID();

        // Collect keywords to clear, then remove actor from tracking
        std::vector<RE::FormID> keywordsToRemove;
        {
            std::lock_guard<std::mutex> lock(m_mutex);

            auto it = m_tracked.find(actorID);
            if (it != m_tracked.end()) {
                for (auto& entry : it->second) {
                    keywordsToRemove.push_back(entry.keywordFormID);
                }
                m_tracked.erase(it);
            }
        }

        // Clear native LinkedRefs outside the lock
        for (auto kwID : keywordsToRemove) {
            auto* keyword = RE::TESForm::LookupByID<RE::BGSKeyword>(kwID);
            if (keyword) {
                NativeSetLinkedRef(actor, nullptr, keyword);
            }
        }

        if (!keywordsToRemove.empty()) {
            SKSE::log::info("PackageManager: LinkedRef_ClearAll {:08X} — cleared {} entries",
                actorID, keywordsToRemove.size());
        }
    }

    bool PackageManager::LinkedRef_HasAny(RE::Actor* actor) const
    {
        if (!actor) return false;
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_tracked.contains(actor->GetFormID());
    }

    int32_t PackageManager::LinkedRef_GetTrackedCount() const
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        int32_t count = 0;
        for (const auto& [_, entries] : m_tracked) {
            count += static_cast<int32_t>(entries.size());
        }
        return count;
    }

    void PackageManager::NativeEvaluatePackage(RE::Actor* actor)
    {
        if (actor) {
            actor->EvaluatePackage();
        }
    }

    // ========================================================================
    // COSAVE RESTORE — Called on kPostLoadGame
    // ========================================================================

    void PackageManager::RestoreAllLinkedRefs()
    {
        std::lock_guard<std::mutex> lock(m_mutex);

        if (m_tracked.empty()) {
            SKSE::log::info("PackageManager: No LinkedRefs to restore from cosave");
            return;
        }

        SKSE::log::info("PackageManager: Restoring LinkedRefs from cosave...");

        int restored = 0;
        int failed = 0;

        for (auto it = m_tracked.begin(); it != m_tracked.end(); ) {
            auto& entries = it->second;

            for (auto entryIt = entries.begin(); entryIt != entries.end(); ) {
                auto* actor = RE::TESForm::LookupByID<RE::Actor>(entryIt->actorFormID);
                auto* target = RE::TESForm::LookupByID<RE::TESObjectREFR>(entryIt->targetFormID);
                auto* keyword = RE::TESForm::LookupByID<RE::BGSKeyword>(entryIt->keywordFormID);

                if (actor && target && keyword) {
                    NativeSetLinkedRef(actor, target, keyword);
                    restored++;
                    SKSE::log::trace("PackageManager: Restored {:08X} -> {:08X} (keyword: {:08X})",
                        entryIt->actorFormID, entryIt->targetFormID, entryIt->keywordFormID);
                    ++entryIt;
                } else {
                    SKSE::log::warn("PackageManager: Failed to restore — actor:{:08X} target:{:08X} keyword:{:08X} (form lookup failed)",
                        entryIt->actorFormID, entryIt->targetFormID, entryIt->keywordFormID);
                    entryIt = entries.erase(entryIt);
                    failed++;
                }
            }

            // Clean up empty actor entries
            if (entries.empty()) {
                it = m_tracked.erase(it);
            } else {
                ++it;
            }
        }

        SKSE::log::info("PackageManager: Restored {} LinkedRefs from cosave ({} failed)",
            restored, failed);
    }

    // ========================================================================
    // SKSE COSAVE CALLBACKS
    // ========================================================================

    void PackageManager::OnSave(SKSE::SerializationInterface* a_intfc)
    {
        auto* inst = GetSingleton();
        std::lock_guard<std::mutex> lock(inst->m_mutex);

        if (!a_intfc->OpenRecord(kLinkedRefRecord, kSerializationVersion)) {
            SKSE::log::error("PackageManager: Failed to open LREF record for save");
            return;
        }

        // Count total entries across all actors
        std::uint32_t totalEntries = 0;
        for (const auto& [_, entries] : inst->m_tracked) {
            totalEntries += static_cast<std::uint32_t>(entries.size());
        }

        a_intfc->WriteRecordData(totalEntries);

        for (const auto& [actorID, entries] : inst->m_tracked) {
            for (const auto& entry : entries) {
                a_intfc->WriteRecordData(entry.actorFormID);
                a_intfc->WriteRecordData(entry.targetFormID);
                a_intfc->WriteRecordData(entry.keywordFormID);
            }
        }

        SKSE::log::info("PackageManager: Saved {} LinkedRef entries to cosave", totalEntries);
    }

    void PackageManager::OnLoad(SKSE::SerializationInterface* a_intfc)
    {
        auto* inst = GetSingleton();

        // Clear before processing any records — ensures stale data from previous
        // load in the same session is discarded exactly once, not per-record.
        {
            std::lock_guard<std::mutex> lock(inst->m_mutex);
            inst->m_tracked.clear();
        }

        std::uint32_t type, version, length;
        while (a_intfc->GetNextRecordInfo(type, version, length)) {
            if (type != kLinkedRefRecord) {
                SKSE::log::warn("PackageManager: Unknown record type {:08X} in cosave", type);
                continue;
            }

            if (version != kSerializationVersion) {
                SKSE::log::warn("PackageManager: Cosave version mismatch (got {}, expected {})",
                    version, kSerializationVersion);
                continue;
            }

            std::uint32_t count = 0;
            if (!a_intfc->ReadRecordData(count)) {
                SKSE::log::error("PackageManager: Failed to read entry count from cosave");
                continue;
            }

            std::lock_guard<std::mutex> lock(inst->m_mutex);

            std::uint32_t loaded = 0;
            for (std::uint32_t i = 0; i < count; i++) {
                RE::FormID savedActor, savedTarget, savedKeyword;
                if (!a_intfc->ReadRecordData(savedActor) ||
                    !a_intfc->ReadRecordData(savedTarget) ||
                    !a_intfc->ReadRecordData(savedKeyword)) {
                    SKSE::log::error("PackageManager: Truncated cosave record at entry {}/{}", i, count);
                    break;
                }

                // Resolve form IDs — handles load order changes between saves
                RE::FormID resolvedActor, resolvedTarget, resolvedKeyword;
                if (!a_intfc->ResolveFormID(savedActor, resolvedActor)) {
                    SKSE::log::trace("PackageManager: Failed to resolve actor {:08X}", savedActor);
                    continue;
                }
                if (!a_intfc->ResolveFormID(savedTarget, resolvedTarget)) {
                    SKSE::log::trace("PackageManager: Failed to resolve target {:08X}", savedTarget);
                    continue;
                }
                if (!a_intfc->ResolveFormID(savedKeyword, resolvedKeyword)) {
                    SKSE::log::trace("PackageManager: Failed to resolve keyword {:08X}", savedKeyword);
                    continue;
                }

                LinkedRefEntry entry{ resolvedActor, resolvedTarget, resolvedKeyword };
                inst->m_tracked[resolvedActor].push_back(entry);
                loaded++;
            }

            SKSE::log::info("PackageManager: Loaded {} of {} LinkedRef entries from cosave",
                loaded, count);
        }

        // NOTE: Actual LinkedRef restoration happens in RestoreAllLinkedRefs(),
        // called from plugin.cpp on kPostLoadGame when all forms are loaded.
    }

    void PackageManager::OnRevert(SKSE::SerializationInterface*)
    {
        auto* inst = GetSingleton();
        std::lock_guard<std::mutex> lock(inst->m_mutex);
        inst->m_tracked.clear();
        SKSE::log::info("PackageManager: Cosave reverted — cleared all tracking");
    }

    // ========================================================================
    // DEATH EVENT HANDLER
    // ========================================================================

    RE::BSEventNotifyControl PackageManager::ProcessEvent(
        const RE::TESDeathEvent* a_event,
        RE::BSTEventSource<RE::TESDeathEvent>*)
    {
        if (!a_event || !a_event->actorDying) {
            return RE::BSEventNotifyControl::kContinue;
        }

        RE::FormID actorID = a_event->actorDying->GetFormID();

        // Collect keyword IDs under lock, then clear native LinkedRefs outside lock.
        // Same pattern as LinkedRef_ClearAll — prevents orphaned ExtraLinkedRef data
        // if the actor is later revived (console, mods, essential bleedout).
        std::vector<RE::FormID> keywordsToClear;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            auto it = m_tracked.find(actorID);
            if (it != m_tracked.end()) {
                SKSE::log::info("PackageManager: Actor {:08X} died — clearing {} LinkedRef entries",
                    actorID, it->second.size());
                for (const auto& entry : it->second) {
                    keywordsToClear.push_back(entry.keywordFormID);
                }
                m_tracked.erase(it);
            }
        }

        // Clear native ExtraLinkedRef data outside the lock
        if (!keywordsToClear.empty()) {
            for (auto kwID : keywordsToClear) {
                auto* keyword = RE::TESForm::LookupByID<RE::BGSKeyword>(kwID);
                if (keyword) {
                    NativeSetLinkedRef(a_event->actorDying.get(), nullptr, keyword);
                }
            }
        }

        return RE::BSEventNotifyControl::kContinue;
    }

    // ========================================================================
    // PAPYRUS WRAPPERS
    // ========================================================================

    void PackageManager::Papyrus_LinkedRef_Set(RE::StaticFunctionTag*,
        RE::Actor* actor, RE::TESObjectREFR* target, RE::BGSKeyword* keyword)
    {
        GetSingleton()->LinkedRef_Set(actor, target, keyword);
    }

    void PackageManager::Papyrus_LinkedRef_Clear(RE::StaticFunctionTag*,
        RE::Actor* actor, RE::BGSKeyword* keyword)
    {
        GetSingleton()->LinkedRef_Clear(actor, keyword);
    }

    void PackageManager::Papyrus_LinkedRef_ClearAll(RE::StaticFunctionTag*,
        RE::Actor* actor)
    {
        GetSingleton()->LinkedRef_ClearAll(actor);
    }

    bool PackageManager::Papyrus_LinkedRef_HasAny(RE::StaticFunctionTag*,
        RE::Actor* actor)
    {
        return GetSingleton()->LinkedRef_HasAny(actor);
    }

    int32_t PackageManager::Papyrus_LinkedRef_GetTrackedCount(RE::StaticFunctionTag*)
    {
        return GetSingleton()->LinkedRef_GetTrackedCount();
    }

    void PackageManager::Papyrus_NativeEvaluatePackage(RE::StaticFunctionTag*,
        RE::Actor* actor)
    {
        NativeEvaluatePackage(actor);
    }

    // ========================================================================
    // PAPYRUS REGISTRATION
    // ========================================================================

    void PackageManager::RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        a_vm->RegisterFunction("LinkedRef_Set", scriptName, Papyrus_LinkedRef_Set);
        a_vm->RegisterFunction("LinkedRef_Clear", scriptName, Papyrus_LinkedRef_Clear);
        a_vm->RegisterFunction("LinkedRef_ClearAll", scriptName, Papyrus_LinkedRef_ClearAll);
        a_vm->RegisterFunction("LinkedRef_HasAny", scriptName, Papyrus_LinkedRef_HasAny);
        a_vm->RegisterFunction("LinkedRef_GetTrackedCount", scriptName, Papyrus_LinkedRef_GetTrackedCount);
        a_vm->RegisterFunction("NativeEvaluatePackage", scriptName, Papyrus_NativeEvaluatePackage);

        SKSE::log::info("PackageManager: Registered Papyrus functions (6 functions)");
    }
}
