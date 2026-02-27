#pragma once

// SeverActionsNative - Actor Finder
// Find NPCs by name anywhere in the game world
// Supports fuzzy matching with Levenshtein distance for typo tolerance
// Used by guard dispatch, kidnap actions, and follower errand systems
// Author: Severause

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <mutex>
#include <algorithm>

#include "StringUtils.h"
#include "NND_API.h"

namespace SeverActionsNative
{
    struct ActorEntry
    {
        std::string name;           // Display name (lowercase)
        std::string displayName;    // Original display name
        RE::FormID formId;          // Actor base form ID
        bool isUnique;              // Unique NPC flag
    };

    // Position snapshot for tracking NPC locations even when unloaded
    struct PositionSnapshot
    {
        RE::NiPoint3 position{0.0f, 0.0f, 0.0f};  // Last known (x, y, z) coordinates
        RE::FormID worldspaceId{0};                  // TESWorldSpace FormID (0 if interior)
        RE::FormID cellId{0};                        // TESObjectCELL FormID
        float gameTime{0.0f};                        // Game time when snapshot was taken
        bool valid{false};                           // True if this snapshot has been populated
    };

    // Tracks how an NPC's location was resolved for diagnostics
    enum class MappingSource : uint8_t {
        None = 0,
        ExtraPersistentCell,
        ParentCell,
        SaveParentCell,
        ExtraStartingWorldOrCell,
        CurrentLocation,
        EditorLocation,
        PackageLocation,      // NEW: from AI package data
        PostLoadRescan         // NEW: from post-load rescan
    };

    /**
     * Native NPC finder
     *
     * On kDataLoaded:
     *   - Scans all TESNPC records for named, unique NPCs
     *   - Builds hash map for O(1) exact lookup
     *   - Supports fuzzy matching for typo tolerance
     *
     * At runtime:
     *   - FindActorByName() returns the Actor reference
     *   - GetActorLocation() returns where an actor currently is
     *   - Tracks last known position/worldspace for unloaded NPCs
     *     via cell detach events and FindByName piggyback snapshots
     */
    class ActorFinder
        : public RE::BSTEventSink<RE::TESCellAttachDetachEvent>
    {
    public:
        static ActorFinder& GetInstance()
        {
            static ActorFinder instance;
            return instance;
        }

        /**
         * Initialize by scanning all NPC records
         * Called on kDataLoaded
         */
        void Initialize()
        {
            std::lock_guard<std::mutex> lock(m_mutex);

            SKSE::log::info("ActorFinder: Scanning NPC records...");

            m_entries.clear();
            m_exactLookup.clear();
            m_actorCellIndex.clear();
            m_actorCellFormIndex.clear();
            m_actorLocationFormIndex.clear();
            m_mappingSources.clear();
            m_unmappedNPCs.clear();
            m_npcRefFormIds.clear();

            // Clear position snapshots (separate mutex)
            {
                std::lock_guard<std::mutex> snapLock(m_snapshotMutex);
                m_positionSnapshots.clear();
            }

            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            if (!dataHandler) {
                SKSE::log::error("ActorFinder: DataHandler not available");
                return;
            }

            int count = 0;
            int mannequinsSkipped = 0;
            int duplicateNamesResolved = 0;
            for (auto* npc : dataHandler->GetFormArray<RE::TESNPC>()) {
                if (!npc) continue;

                const char* name = npc->GetName();
                if (!name || name[0] == '\0') continue;

                std::string nameStr(name);
                if (nameStr.length() < 2) continue;

                if (npc->IsDeleted()) continue;

                // Skip mannequin NPCs entirely — they can share names with real NPCs
                // (e.g. ManakinRace, SOS_FemaleMannequinRace) and should never be findable
                if (IsMannequinBase(npc)) {
                    mannequinsSkipped++;
                    continue;
                }

                // Skip mod-generated clone NPCs that duplicate vanilla characters.
                // These are created by mods like "Skyrim On Skooma" with prefixed editor IDs
                // (e.g. sos_Hulda, sos_Belethor) and sit in unloaded void cells.
                {
                    const char* editorID = npc->GetFormEditorID();
                    if (editorID && editorID[0] != '\0') {
                        std::string lowerEditorID = StringUtils::ToLower(editorID);
                        if (lowerEditorID.substr(0, 4) == "sos_") {
                            mannequinsSkipped++;
                            continue;
                        }
                    }
                }

                ActorEntry entry;
                entry.name = StringUtils::ToLower(nameStr);
                entry.displayName = nameStr;
                entry.formId = npc->GetFormID();
                entry.isUnique = npc->IsUnique();

                size_t idx = m_entries.size();
                m_entries.push_back(std::move(entry));

                if (npc->IsUnique()) {
                    auto existingIt = m_exactLookup.find(m_entries[idx].name);
                    if (existingIt == m_exactLookup.end()) {
                        // First unique NPC with this name — store it
                        m_exactLookup[m_entries[idx].name] = idx;
                    } else {
                        // Duplicate name! Prefer the NPC with the lower FormID.
                        // Lower FormID = earlier in load order = more likely to be the
                        // original vanilla/DLC NPC rather than a mod-added duplicate.
                        // Vanilla Skyrim.esm uses 00xxxxxx, DLCs use 01-04xxxxxx,
                        // mods use higher prefixes.
                        RE::FormID existingFormId = m_entries[existingIt->second].formId;
                        RE::FormID newFormId = npc->GetFormID();

                        if (newFormId < existingFormId) {
                            SKSE::log::warn("ActorFinder: Duplicate unique NPC name '{}' - replacing {:08X} with {:08X} (lower FormID = more original)",
                                nameStr, existingFormId, newFormId);
                            existingIt->second = idx;
                            duplicateNamesResolved++;
                        } else {
                            SKSE::log::warn("ActorFinder: Duplicate unique NPC name '{}' - keeping {:08X} over {:08X} (lower FormID = more original)",
                                nameStr, existingFormId, newFormId);
                            duplicateNamesResolved++;
                        }
                    }
                }

                count++;
            }

            if (mannequinsSkipped > 0) {
                SKSE::log::info("ActorFinder: Skipped {} mannequin NPC records from name index", mannequinsSkipped);
            }
            if (duplicateNamesResolved > 0) {
                SKSE::log::info("ActorFinder: Resolved {} duplicate unique NPC name conflicts (preferred lower FormID)", duplicateNamesResolved);
            }

            // Build NPC-to-cell index by scanning ALL forms in the game
            int npcCellMappings = 0;
            int refsScanned = 0;
            int npcRefsFound = 0;
            int totalForms = 0;
            {
                auto [allForms, formLock] = RE::TESForm::GetAllForms();
                RE::BSReadWriteLock readLock{ formLock };

                if (allForms) {
                    totalForms = static_cast<int>(allForms->size());
                    SKSE::log::info("ActorFinder: Scanning {} total forms for NPC placement...", totalForms);

                    for (auto& [formId, form] : *allForms) {
                        if (!form) continue;

                        auto formType = form->GetFormType();
                        if (formType != RE::FormType::ActorCharacter) continue;

                        auto* ref = form->As<RE::TESObjectREFR>();
                        if (!ref) continue;
                        refsScanned++;

                        auto* baseObj = ref->GetBaseObject();
                        if (!baseObj) continue;

                        auto* npcBase = baseObj->As<RE::TESNPC>();
                        if (!npcBase) continue;
                        if (!npcBase->IsUnique()) continue;

                        auto npcFormId = npcBase->GetFormID();

                        // Skip if we already have a cell mapping for this NPC
                        if (m_actorCellIndex.find(npcFormId) != m_actorCellIndex.end()) continue;

                        npcRefsFound++;

                        // Store the actor ref FormID for later rescan attempts
                        if (m_npcRefFormIds.find(npcFormId) == m_npcRefFormIds.end()) {
                            m_npcRefFormIds[npcFormId] = ref->GetFormID();
                        }

                        RE::TESObjectCELL* foundCell = nullptr;
                        RE::BGSLocation* foundLocation = nullptr;
                        std::string locationName;
                        MappingSource source = MappingSource::None;

                        // Strategy 1: ExtraPersistentCell
                        auto* extraPersist = ref->extraList.GetByType<RE::ExtraPersistentCell>();
                        if (extraPersist && extraPersist->persistentCell) {
                            foundCell = extraPersist->persistentCell;
                            source = MappingSource::ExtraPersistentCell;
                        }

                        // Strategy 2: parentCell
                        if (!foundCell) {
                            foundCell = ref->GetParentCell();
                            if (foundCell) source = MappingSource::ParentCell;
                        }

                        // Strategy 3: GetSaveParentCell
                        if (!foundCell) {
                            foundCell = ref->GetSaveParentCell();
                            if (foundCell) source = MappingSource::SaveParentCell;
                        }

                        // Strategy 4: ExtraStartingWorldOrCell
                        if (!foundCell) {
                            auto* extraStart = ref->extraList.GetByType<RE::ExtraStartingWorldOrCell>();
                            if (extraStart && extraStart->startingWorldOrCell) {
                                foundCell = extraStart->startingWorldOrCell->As<RE::TESObjectCELL>();
                                if (foundCell) source = MappingSource::ExtraStartingWorldOrCell;
                            }
                        }

                        // Strategy 5: BGSLocation from the ref
                        if (!foundLocation) {
                            foundLocation = ref->GetCurrentLocation();
                            if (foundLocation) source = (source == MappingSource::None) ? MappingSource::CurrentLocation : source;
                        }
                        if (!foundLocation) {
                            foundLocation = ref->GetEditorLocation();
                            if (foundLocation) source = (source == MappingSource::None) ? MappingSource::EditorLocation : source;
                        }

                        // Determine the best location name
                        if (foundCell) {
                            const char* cellName = foundCell->GetFullName();
                            if (cellName && cellName[0] != '\0') {
                                locationName = cellName;
                            } else if (!foundCell->IsInteriorCell()) {
                                auto* cellLoc = foundCell->GetLocation();
                                if (cellLoc) {
                                    const char* locName = cellLoc->GetName();
                                    if (locName && locName[0] != '\0') {
                                        locationName = locName;
                                        foundLocation = cellLoc;
                                    }
                                }
                            }
                        }

                        if (locationName.empty() && foundLocation) {
                            const char* locName = foundLocation->GetName();
                            if (locName && locName[0] != '\0') {
                                locationName = locName;
                            }
                        }

                        // Strategy 6 (NEW): Scan NPC's AI packages for location references
                        // Package data often has cell/location info even when the ref itself doesn't
                        if (locationName.empty()) {
                            auto packageResult = ScanNPCPackagesForLocation(npcBase);
                            if (!packageResult.first.empty()) {
                                locationName = packageResult.first;
                                if (!foundCell && packageResult.second) {
                                    foundCell = packageResult.second;
                                }
                                source = MappingSource::PackageLocation;
                            }
                        }

                        // Record the mapping
                        if (!locationName.empty()) {
                            RecordNPCMapping(npcFormId, locationName, foundCell, foundLocation, source);
                            npcCellMappings++;
                        } else {
                            // Track unmapped NPCs for post-load rescan
                            const char* npcName = npcBase->GetName();
                            if (npcName) {
                                m_unmappedNPCs.insert(npcFormId);
                                SKSE::log::info("ActorFinder: Could not map '{}' (base {:08X}) at kDataLoaded - queued for post-load rescan",
                                    npcName, npcFormId);
                            }
                        }
                    }
                } else {
                    SKSE::log::warn("ActorFinder: GetAllForms() returned null!");
                }
            }

            SKSE::log::info("ActorFinder: NPC-to-cell index: {} total forms, scanned {} actor refs, found {} unique NPC refs, mapped {} to locations, {} unmapped (queued for rescan)",
                totalForms, refsScanned, npcRefsFound, npcCellMappings, m_unmappedNPCs.size());

            // Build home index from sleep packages
            // Scans every unique NPC's AI packages for sleep-type packages
            m_homeIndex.clear();
            int homesMapped = 0;
            for (auto* npc : dataHandler->GetFormArray<RE::TESNPC>()) {
                if (!npc || !npc->IsUnique()) continue;
                if (npc->IsDeleted()) continue;

                const char* npcName = npc->GetName();
                if (!npcName || npcName[0] == '\0') continue;

                auto npcFormId = npc->GetFormID();

                auto homeResult = ScanNPCPackagesForHome(npc);

                // Fallback: if sleep package scan failed (kNearSelf, kNearLinkedReference, etc.),
                // use the NPC's placement cell from our NPC-to-cell index as their "home."
                // This is where the NPC was placed in the CK, which for townfolk is their home.
                if (homeResult.first.empty()) {
                    auto cellIt = m_actorCellFormIndex.find(npcFormId);
                    if (cellIt != m_actorCellFormIndex.end()) {
                        auto* fallbackCell = RE::TESForm::LookupByID<RE::TESObjectCELL>(cellIt->second);
                        if (fallbackCell) {
                            // Only use interior cells as homes (exterior cells are streets/wilderness)
                            if (fallbackCell->IsInteriorCell()) {
                                const char* cellName = fallbackCell->GetFullName();
                                if (cellName && cellName[0] != '\0') {
                                    homeResult = {cellName, fallbackCell};
                                    SKSE::log::info("ActorFinder: Home index fallback - '{}' -> '{}' (from placement cell)",
                                        npc->GetName() ? npc->GetName() : "unknown", cellName);
                                }
                            }
                        }
                    }
                }

                if (!homeResult.first.empty()) {
                    HomeInfo info;
                    info.cellName = homeResult.first;

                    if (homeResult.second) {
                        info.cellFormId = homeResult.second->GetFormID();
                        // Build disambiguated name
                        info.disambiguatedName = DisambiguateCellName(
                            homeResult.first.c_str(), homeResult.second);
                    } else {
                        info.disambiguatedName = homeResult.first;
                    }

                    m_homeIndex[npcFormId] = std::move(info);
                    homesMapped++;
                }
            }

            SKSE::log::info("ActorFinder: Home index: mapped {} unique NPCs to home cells via sleep packages", homesMapped);

            // Register for cell detach events to snapshot NPC positions before unload
            // Only register once — AddEventSink does NOT deduplicate, so calling it
            // again on reload would fire ProcessEvent multiple times per event
            if (!m_eventSinkRegistered) {
                auto* eventSource = RE::ScriptEventSourceHolder::GetSingleton();
                if (eventSource) {
                    eventSource->AddEventSink<RE::TESCellAttachDetachEvent>(this);
                    m_eventSinkRegistered = true;
                    SKSE::log::info("ActorFinder: Registered for cell detach events (position snapshots)");
                }
            }

            m_initialized = true;

            // Release excess vector capacity now that init is done
            m_entries.shrink_to_fit();

            SKSE::log::info("ActorFinder: Indexed {} NPCs ({} unique, {} cell-mapped)", count,
                m_exactLookup.size(), npcCellMappings);
        }

        /**
         * Post-load rescan: called on kPostLoadGame/kNewGame when save data is available.
         * Re-attempts mapping for NPCs that failed at kDataLoaded.
         * After a save loads, GetSaveParentCell() and GetCurrentLocation() become
         * available for actors that didn't have this data at initial scan time.
         */
        void PostLoadRescan()
        {
            if (!m_initialized) return;

            std::lock_guard<std::mutex> lock(m_mutex);

            if (m_unmappedNPCs.empty()) {
                SKSE::log::info("ActorFinder: PostLoadRescan - no unmapped NPCs to rescan");
                return;
            }

            SKSE::log::info("ActorFinder: PostLoadRescan - attempting to map {} previously unmapped NPCs...", m_unmappedNPCs.size());

            int newMappings = 0;
            std::vector<RE::FormID> nowMapped;

            for (RE::FormID npcBaseId : m_unmappedNPCs) {
                // Skip if somehow already mapped
                if (m_actorCellIndex.find(npcBaseId) != m_actorCellIndex.end()) {
                    nowMapped.push_back(npcBaseId);
                    continue;
                }

                // Find the actor ref for this NPC base
                RE::Actor* actor = FindActorReferenceUnlocked(npcBaseId);
                if (!actor) continue;

                RE::TESObjectCELL* foundCell = nullptr;
                RE::BGSLocation* foundLocation = nullptr;
                std::string locationName;

                // After a save load, these should now be populated:
                // 1. GetSaveParentCell - persisted from save
                foundCell = actor->GetSaveParentCell();
                if (foundCell) {
                    const char* cellName = foundCell->GetFullName();
                    if (cellName && cellName[0] != '\0') {
                        locationName = cellName;
                    }
                }

                // 2. GetParentCell - may now be set
                if (locationName.empty()) {
                    foundCell = actor->GetParentCell();
                    if (foundCell) {
                        const char* cellName = foundCell->GetFullName();
                        if (cellName && cellName[0] != '\0') {
                            locationName = cellName;
                        }
                    }
                }

                // 3. GetCurrentLocation - runtime location
                if (locationName.empty()) {
                    foundLocation = actor->GetCurrentLocation();
                    if (foundLocation) {
                        const char* locName = foundLocation->GetName();
                        if (locName && locName[0] != '\0') {
                            locationName = locName;
                        }
                    }
                }

                // 4. GetEditorLocation
                if (locationName.empty()) {
                    foundLocation = actor->GetEditorLocation();
                    if (foundLocation) {
                        const char* locName = foundLocation->GetName();
                        if (locName && locName[0] != '\0') {
                            locationName = locName;
                        }
                    }
                }

                // 5. GetEditorLocation2 (returns cell/worldspace form directly)
                if (locationName.empty()) {
                    RE::NiPoint3 outPos, outRot;
                    RE::TESForm* outWorldOrCell = nullptr;
                    if (actor->GetEditorLocation2(outPos, outRot, outWorldOrCell, nullptr) && outWorldOrCell) {
                        auto* editorCell = outWorldOrCell->As<RE::TESObjectCELL>();
                        if (editorCell) {
                            foundCell = editorCell;
                            const char* name = editorCell->GetFullName();
                            if (name && name[0] != '\0') {
                                locationName = name;
                            }
                        }
                    }
                }

                if (!locationName.empty()) {
                    RecordNPCMapping(npcBaseId, locationName, foundCell, foundLocation, MappingSource::PostLoadRescan);
                    nowMapped.push_back(npcBaseId);
                    newMappings++;

                    auto* npcBase = RE::TESForm::LookupByID<RE::TESNPC>(npcBaseId);
                    SKSE::log::info("ActorFinder: PostLoadRescan - mapped '{}' -> '{}'",
                        npcBase ? npcBase->GetName() : "unknown", locationName);
                }
            }

            // Remove successfully mapped NPCs from unmapped set
            for (RE::FormID id : nowMapped) {
                m_unmappedNPCs.erase(id);
            }

            SKSE::log::info("ActorFinder: PostLoadRescan complete - {} new mappings, {} still unmapped",
                newMappings, m_unmappedNPCs.size());

            // Log remaining unmapped NPCs for debugging
            if (!m_unmappedNPCs.empty() && m_unmappedNPCs.size() <= 50) {
                for (RE::FormID id : m_unmappedNPCs) {
                    auto* npc = RE::TESForm::LookupByID<RE::TESNPC>(id);
                    if (npc) {
                        SKSE::log::warn("ActorFinder: Still unmapped after post-load: '{}' ({:08X})",
                            npc->GetName() ? npc->GetName() : "null", id);
                    }
                }
            }
        }

        // ====================================================================
        // POSITION SNAPSHOT SYSTEM
        // Captures NPC coordinates on cell detach and FindByName lookups
        // ====================================================================

        /**
         * Reference detach event handler - snapshot unique NPCs as they unload
         * TESCellAttachDetachEvent fires per-reference, not per-cell.
         * When attached==false, the reference is being unloaded.
         */
        RE::BSEventNotifyControl ProcessEvent(
            const RE::TESCellAttachDetachEvent* a_event,
            RE::BSTEventSource<RE::TESCellAttachDetachEvent>*) override
        {
            if (!a_event || !m_initialized) {
                return RE::BSEventNotifyControl::kContinue;
            }

            // Only care about detach events (reference unloading)
            if (a_event->attached) {
                return RE::BSEventNotifyControl::kContinue;
            }

            auto* ref = a_event->reference;
            if (!ref) {
                return RE::BSEventNotifyControl::kContinue;
            }

            // Only snapshot actor references
            auto* actor = ref->As<RE::Actor>();
            if (!actor) {
                return RE::BSEventNotifyControl::kContinue;
            }

            // Only snapshot unique NPCs
            auto* npcBase = actor->GetActorBase();
            if (!npcBase || !npcBase->IsUnique()) {
                return RE::BSEventNotifyControl::kContinue;
            }

            SnapshotActorPosition(actor);

            return RE::BSEventNotifyControl::kContinue;
        }

        /**
         * Take a position snapshot of an actor
         * Records position, worldspace, cell, and game time
         */
        void SnapshotActorPosition(RE::Actor* actor)
        {
            if (!actor) return;

            auto* npcBase = actor->GetActorBase();
            if (!npcBase) return;

            RE::FormID baseId = npcBase->GetFormID();
            PositionSnapshot snap;

            // Get position
            snap.position = actor->GetPosition();

            // Get cell
            auto* parentCell = actor->GetParentCell();
            if (parentCell) {
                snap.cellId = parentCell->GetFormID();

                // Get worldspace (only for exterior cells)
                if (!parentCell->IsInteriorCell()) {
                    auto* worldspace = parentCell->GetRuntimeData().worldSpace;
                    if (worldspace) {
                        snap.worldspaceId = worldspace->GetFormID();
                    }
                }
            }

            // Get game time
            auto* calendar = RE::Calendar::GetSingleton();
            if (calendar) {
                snap.gameTime = calendar->GetCurrentGameTime();
            }

            snap.valid = true;

            // Store snapshot (thread-safe)
            std::lock_guard<std::mutex> lock(m_snapshotMutex);
            m_positionSnapshots[baseId] = snap;
        }

        /**
         * Get the last known position snapshot for an NPC
         * Returns a snapshot with valid=false if no snapshot exists
         */
        PositionSnapshot GetPositionSnapshot(RE::FormID npcBaseId) const
        {
            std::lock_guard<std::mutex> lock(m_snapshotMutex);
            auto it = m_positionSnapshots.find(npcBaseId);
            if (it != m_positionSnapshots.end()) {
                return it->second;
            }
            return PositionSnapshot{};  // valid = false
        }

        /**
         * Get the last known position for an actor
         * If loaded, returns live position and takes a fresh snapshot.
         * If unloaded, returns the last snapshot.
         * Returns {0,0,0} if no data available.
         */
        RE::NiPoint3 GetActorLastKnownPosition(RE::Actor* actor)
        {
            if (!actor) return {0.0f, 0.0f, 0.0f};

            // If loaded, snapshot and return live position
            if (actor->Is3DLoaded()) {
                SnapshotActorPosition(actor);
                return actor->GetPosition();
            }

            // Unloaded - check snapshot
            auto* npcBase = actor->GetActorBase();
            if (npcBase) {
                auto snap = GetPositionSnapshot(npcBase->GetFormID());
                if (snap.valid) {
                    return snap.position;
                }
            }

            return {0.0f, 0.0f, 0.0f};
        }

        /**
         * Get the worldspace name for a given worldspace FormID
         * Returns empty string if not found or interior
         */
        static std::string GetWorldspaceName(RE::FormID worldspaceId)
        {
            if (worldspaceId == 0) return "";

            auto* form = RE::TESForm::LookupByID(worldspaceId);
            if (!form) return "";

            auto* worldspace = form->As<RE::TESWorldSpace>();
            if (!worldspace) return "";

            const char* name = worldspace->GetName();
            if (name && name[0] != '\0') {
                return name;
            }

            return "";
        }

        /**
         * Find an actor reference by name
         * Searches loaded actors first, then falls back to base form
         * @param name The NPC name to search for
         * @return The Actor reference, or nullptr
         */
        RE::Actor* FindByName(const std::string& name)
        {
            if (!m_initialized || name.empty()) return nullptr;

            std::string lowerName = StringUtils::ToLower(name);

            // Check the player first — the player is NOT in process lists
            auto* player = RE::PlayerCharacter::GetSingleton();
            if (player) {
                const char* playerName = player->GetName();
                if (playerName && StringUtils::ToLower(playerName) == lowerName) {
                    return player;
                }
            }

            // First: search all currently loaded actors (most reliable)
            RE::Actor* loadedResult = FindLoadedActorByName(lowerName);
            if (loadedResult) {
                // Piggyback snapshot: capture position while actor is loaded
                SnapshotActorPosition(loadedResult);
                return loadedResult;
            }

            // Second: exact match in database, then find their reference
            // FindActorReference now scores candidates to handle duplicates
            auto exactIt = m_exactLookup.find(lowerName);
            if (exactIt != m_exactLookup.end()) {
                RE::Actor* actor = FindActorReference(m_entries[exactIt->second].formId);
                if (actor) return actor;
            }

            // Third: try ALL entries with an exact name match (handles cases where
            // the exactLookup entry failed but another NPC base with the same name exists)
            // This catches mod-duplicated NPCs where the "preferred" base form has no
            // valid actor reference but another base form does
            {
                RE::Actor* bestActor = nullptr;
                int bestScore = -999;

                for (size_t i = 0; i < m_entries.size(); i++) {
                    if (!m_entries[i].isUnique) continue;
                    if (m_entries[i].name != lowerName) continue;

                    // Skip the entry we already tried in the exact lookup
                    if (exactIt != m_exactLookup.end() && i == exactIt->second) continue;

                    RE::Actor* actor = FindActorReference(m_entries[i].formId);
                    if (actor) {
                        int score = ScoreActorReference(actor, m_entries[i].formId);
                        if (score > bestScore) {
                            bestActor = actor;
                            bestScore = score;
                        }
                    }
                }

                if (bestActor) {
                    SKSE::log::info("ActorFinder: FindByName - found '{}' via alternate base form (score={})",
                        name, bestScore);
                    return bestActor;
                }
            }

            // Fourth: fuzzy match (contains + Levenshtein)
            int bestDistance = 999;
            size_t bestIdx = 0;
            bool found = false;

            for (size_t i = 0; i < m_entries.size(); i++) {
                if (!m_entries[i].isUnique) continue;

                // Contains check first (fast)
                if (m_entries[i].name.find(lowerName) != std::string::npos ||
                    lowerName.find(m_entries[i].name) != std::string::npos) {
                    RE::Actor* actor = FindActorReference(m_entries[i].formId);
                    if (actor) return actor;
                }

                // Levenshtein for typos
                int lenDiff = static_cast<int>(m_entries[i].name.length()) - static_cast<int>(lowerName.length());
                if (lenDiff >= -3 && lenDiff <= 3) {
                    int dist = LevenshteinDistance(lowerName, m_entries[i].name);
                    if (dist <= 2 && dist < bestDistance) {
                        bestDistance = dist;
                        bestIdx = i;
                        found = true;
                    }
                }
            }

            if (found) {
                SKSE::log::info("ActorFinder: Fuzzy matched '{}' -> '{}' (distance={})",
                    name, m_entries[bestIdx].displayName, bestDistance);
                return FindActorReference(m_entries[bestIdx].formId);
            }

            SKSE::log::warn("ActorFinder: Could not find actor '{}'", name);
            return nullptr;
        }

        /**
         * Get the current cell/location of an actor
         * Returns an ObjectReference at the actor's position
         * Works even for actors in unloaded cells (uses persisted position)
         */
        static RE::TESObjectCELL* GetActorCell(RE::Actor* actor)
        {
            if (!actor) return nullptr;
            return actor->GetParentCell();
        }

        /**
         * Get the current location name for an actor.
         * For interior cells with generic names (e.g. "Cellar"), appends parent location
         * for disambiguation: "Cellar (Bannered Mare)".
         */
        static std::string GetActorLocationName(RE::Actor* actor)
        {
            if (!actor) return "unknown";

            // 1. Try runtime current location (works for loaded NPCs)
            auto* location = actor->GetCurrentLocation();
            if (location) {
                const char* name = location->GetName();
                if (name && name[0] != '\0') {
                    SKSE::log::info("ActorFinder: GetActorLocationName - got current location: '{}'", name);
                    return name;
                }
            }

            // 2. Try runtime parent cell name (works for loaded NPCs)
            auto* cell = actor->GetParentCell();
            if (cell) {
                const char* name = cell->GetFullName();
                if (name && name[0] != '\0') {
                    std::string result = DisambiguateCellName(name, cell);
                    SKSE::log::info("ActorFinder: GetActorLocationName - got parent cell: '{}'", result);
                    return result;
                }
            }

            // 3. Try the editor location (persists even for unloaded NPCs)
            // This is the BGSLocation the NPC was placed in by the Creation Kit
            auto* editorLoc = actor->GetEditorLocation();
            if (editorLoc) {
                const char* name = editorLoc->GetName();
                if (name && name[0] != '\0') {
                    SKSE::log::info("ActorFinder: GetActorLocationName - got editor location: '{}'", name);
                    return name;
                }
            }

            // 4. Try GetEditorLocation1 (direct virtual, returns editorLocation member)
            auto* editorLoc1 = actor->GetEditorLocation1();
            if (editorLoc1 && editorLoc1 != editorLoc) {
                const char* name = editorLoc1->GetName();
                if (name && name[0] != '\0') {
                    SKSE::log::info("ActorFinder: GetActorLocationName - got editor location1: '{}'", name);
                    return name;
                }
            }

            // 5. Try the save-game parent cell (persisted across saves for unloaded actors)
            auto* saveCell = actor->GetSaveParentCell();
            if (saveCell) {
                const char* name = saveCell->GetFullName();
                if (name && name[0] != '\0') {
                    std::string result = DisambiguateCellName(name, saveCell);
                    SKSE::log::info("ActorFinder: GetActorLocationName - got save parent cell: '{}'", result);
                    return result;
                }
            }

            // 6. Try the pre-built NPC-to-cell index (built at kDataLoaded by scanning all actor refs)
            // This is the most reliable method for unloaded NPCs
            {
                auto* npcBase = actor->GetActorBase();
                if (npcBase) {
                    auto npcBaseId = npcBase->GetFormID();
                    auto& inst = GetInstance();
                    auto indexIt = inst.m_actorCellIndex.find(npcBaseId);
                    if (indexIt != inst.m_actorCellIndex.end()) {
                        SKSE::log::info("ActorFinder: GetActorLocationName - got cell from NPC index: '{}' (npcBase {:08X})",
                            indexIt->second, npcBaseId);
                        return indexIt->second;
                    } else {
                        // NPC base not in index - might be a mod-replaced NPC (different base form, same name)
                        // Try to find an NPC with the same name in our index
                        const char* npcName = npcBase->GetName();
                        if (npcName && npcName[0] != '\0') {
                            std::string lowerName = StringUtils::ToLower(npcName);
                            for (const auto& [indexedFormId, cellName] : inst.m_actorCellIndex) {
                                // Look up the NPC base form to compare names
                                auto* indexedNpc = RE::TESForm::LookupByID<RE::TESNPC>(indexedFormId);
                                if (indexedNpc) {
                                    const char* indexedName = indexedNpc->GetName();
                                    if (indexedName && StringUtils::ToLower(indexedName) == lowerName) {
                                        SKSE::log::info("ActorFinder: GetActorLocationName - found name match '{}' in index via NPC {:08X} -> '{}'",
                                            npcName, indexedFormId, cellName);
                                        return cellName;
                                    }
                                }
                            }
                        }
                        SKSE::log::info("ActorFinder: GetActorLocationName - NPC base {:08X} ('{}') not in cell index ({} entries), no name match found",
                            npcBaseId, npcName ? npcName : "null", inst.m_actorCellIndex.size());
                    }
                }
            }

            // 7. Last resort: Try GetEditorLocation2 to get the world/cell form directly
            {
                RE::NiPoint3 outPos, outRot;
                RE::TESForm* outWorldOrCell = nullptr;
                if (actor->GetEditorLocation2(outPos, outRot, outWorldOrCell, nullptr)) {
                    if (outWorldOrCell) {
                        auto* editorCell = outWorldOrCell->As<RE::TESObjectCELL>();
                        if (editorCell) {
                            const char* name = editorCell->GetFullName();
                            if (name && name[0] != '\0') {
                                std::string result = DisambiguateCellName(name, editorCell);
                                SKSE::log::info("ActorFinder: GetActorLocationName - got editor cell via GetEditorLocation2: '{}'", result);
                                return result;
                            }
                        }
                        // Could be a worldspace instead of a cell
                        auto* editorWS = outWorldOrCell->As<RE::TESWorldSpace>();
                        if (editorWS) {
                            const char* name = editorWS->GetName();
                            if (name && name[0] != '\0') {
                                SKSE::log::info("ActorFinder: GetActorLocationName - got editor worldspace: '{}'", name);
                                return name;
                            }
                        }
                    }
                }
            }

            SKSE::log::warn("ActorFinder: GetActorLocationName - could not determine location for actor {:08X}", actor->GetFormID());
            return "unknown";
        }

        /**
         * Disambiguate a cell name by appending its parent location.
         * For generic names like "Cellar", "Hall", etc., appends " (ParentLocation)"
         * to help the LLM distinguish between identically-named cells.
         *
         * e.g. "Cellar" with parent location "BanneredMareLocation" -> "Cellar (The Bannered Mare)"
         */
        static std::string DisambiguateCellName(const char* cellName, RE::TESObjectCELL* cell)
        {
            if (!cellName || !cell) return cellName ? cellName : "unknown";

            std::string name(cellName);

            // Only disambiguate interior cells with short/generic names
            if (!cell->IsInteriorCell()) return name;

            // Generic cell name heuristic: names <= 15 chars that are common duplicates
            // This covers "Cellar", "Hall", "Bedroom", "Kitchen", etc.
            // Longer unique names like "Dragonsreach" don't need disambiguation
            static const std::unordered_set<std::string> genericNames = {
                "cellar", "hall", "bedroom", "kitchen", "basement",
                "barracks", "dungeon", "jail", "mine", "cave",
                "tower", "keep", "temple", "chapel", "crypt",
                "warehouse", "store", "shop", "house"
            };

            std::string lowerName = StringUtils::ToLower(name);
            bool isGeneric = genericNames.find(lowerName) != genericNames.end();

            if (!isGeneric) return name;

            // Get parent location name
            auto* parentLoc = cell->GetLocation();
            if (parentLoc) {
                const char* locName = parentLoc->GetName();
                if (locName && locName[0] != '\0') {
                    return name + " (" + std::string(locName) + ")";
                }
            }

            return name;
        }

        /**
         * Find the "home" location of an NPC.
         *
         * Strategy (in priority order):
         * 1. Pre-built home index (sleep package scan at kDataLoaded) — works for ALL NPCs
         *    Returns the home cell TESObjectCELL* (caller can use LocationResolver for door).
         * 2. Bed ownership scan — only works if NPC is loaded, searches their current cell
         *    for furniture they own. Returns the bed reference directly.
         */
        static RE::TESObjectREFR* FindActorHome(RE::Actor* actor)
        {
            if (!actor) return nullptr;

            auto* npc = actor->GetActorBase();
            if (!npc) return nullptr;

            RE::FormID npcBaseId = npc->GetFormID();

            // Strategy 1: Search current cell for owned beds (if loaded)
            // This is the most direct result — an actual bed in the NPC's vicinity
            auto* cell = actor->GetParentCell();
            if (cell) {
                RE::TESObjectREFR* ownedBed = nullptr;

                cell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                    auto* baseObj = ref.GetBaseObject();
                    if (!baseObj) return RE::BSContainer::ForEachResult::kContinue;

                    auto* furn = baseObj->As<RE::TESFurniture>();
                    if (!furn) return RE::BSContainer::ForEachResult::kContinue;

                    auto* ownerForm = ref.GetOwner();
                    if (ownerForm) {
                        // Direct NPC ownership
                        if (ownerForm->GetFormID() == npcBaseId) {
                            ownedBed = &ref;
                            return RE::BSContainer::ForEachResult::kStop;
                        }

                        // Faction ownership
                        auto* ownerFaction = ownerForm->As<RE::TESFaction>();
                        if (ownerFaction && npc->IsInFaction(ownerFaction)) {
                            ownedBed = &ref;
                            // Don't stop - keep looking for direct ownership
                        }
                    }

                    return RE::BSContainer::ForEachResult::kContinue;
                });

                if (ownedBed) {
                    SKSE::log::info("ActorFinder: FindActorHome - found owned bed {:08X} in current cell for '{}'",
                        ownedBed->GetFormID(), npc->GetName() ? npc->GetName() : "unknown");
                    return ownedBed;
                }
            }

            SKSE::log::info("ActorFinder: FindActorHome - no owned bed found for '{}' ({:08X}), use GetActorHomeCell for index lookup",
                npc->GetName() ? npc->GetName() : "unknown", npcBaseId);
            return nullptr;
        }

        /**
         * Get the home cell for an NPC from the pre-built sleep package index.
         * Returns the TESObjectCELL* where this NPC sleeps.
         * Works for unloaded NPCs — data is built at kDataLoaded from AI packages.
         * Returns nullptr if no home is known.
         */
        static RE::TESObjectCELL* GetActorHomeCell(RE::Actor* actor)
        {
            if (!actor) return nullptr;

            auto* npc = actor->GetActorBase();
            if (!npc) return nullptr;

            auto& inst = GetInstance();
            auto homeIt = inst.m_homeIndex.find(npc->GetFormID());
            if (homeIt != inst.m_homeIndex.end() && homeIt->second.cellFormId != 0) {
                return RE::TESForm::LookupByID<RE::TESObjectCELL>(homeIt->second.cellFormId);
            }

            return nullptr;
        }

        /**
         * Get the home cell name for an NPC (human-readable, disambiguated).
         * Uses the pre-built home index from sleep package scanning.
         * Returns empty string if no home is known.
         */
        static std::string GetActorHomeCellName(RE::Actor* actor)
        {
            if (!actor) return "";

            auto* npc = actor->GetActorBase();
            if (!npc) return "";

            auto& inst = GetInstance();
            auto homeIt = inst.m_homeIndex.find(npc->GetFormID());
            if (homeIt != inst.m_homeIndex.end()) {
                return homeIt->second.disambiguatedName;
            }

            return "";
        }

        bool IsInitialized() const { return m_initialized; }
        size_t GetEntryCount() const { return m_entries.size(); }

        /**
         * Set the NPC Names Distributor API pointer (soft dependency).
         * Called from plugin.cpp during kPostLoad if NND is installed.
         */
        void SetNNDAPI(NND_API::IVNND1* api) { m_nndAPI = api; }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static RE::Actor* Papyrus_FindActorByName(RE::StaticFunctionTag*, RE::BSFixedString name)
        {
            if (!name.data()) return nullptr;
            return GetInstance().FindByName(name.data());
        }

        static RE::BSFixedString Papyrus_GetActorLocationName(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return GetActorLocationName(actor).c_str();
        }

        static RE::TESObjectREFR* Papyrus_FindActorHome(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return FindActorHome(actor);
        }

        static RE::BSFixedString Papyrus_GetActorHomeCellName(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return GetActorHomeCellName(actor).c_str();
        }

        static bool Papyrus_IsActorFinderReady(RE::StaticFunctionTag*)
        {
            return GetInstance().IsInitialized();
        }

        static RE::BSFixedString Papyrus_GetActorIndexedCellName(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            if (!actor) return "";

            auto* npcBase = actor->GetActorBase();
            if (!npcBase) return "";

            auto& inst = GetInstance();
            auto indexIt = inst.m_actorCellIndex.find(npcBase->GetFormID());
            if (indexIt != inst.m_actorCellIndex.end()) {
                return indexIt->second.c_str();
            }

            return "";
        }

        /**
         * Look up the pre-built NPC-to-cell FormID index
         * Returns the interior cell FormID for a given NPC base FormID, or 0 if not found
         * Used by LocationResolver to find doors to unloaded NPC cells
         */
        RE::FormID GetIndexedCellFormID(RE::FormID npcBaseFormId) const
        {
            // First try the cell-specific index (guaranteed TESObjectCELL)
            auto it = m_actorCellFormIndex.find(npcBaseFormId);
            if (it != m_actorCellFormIndex.end()) {
                return it->second;
            }
            return 0;
        }

        /**
         * Look up the NPC-to-location FormID index
         * Returns the BGSLocation FormID for a given NPC, or 0 if not found
         * Separate from cell index to avoid type confusion
         */
        RE::FormID GetIndexedLocationFormID(RE::FormID npcBaseFormId) const
        {
            auto it = m_actorLocationFormIndex.find(npcBaseFormId);
            if (it != m_actorLocationFormIndex.end()) {
                return it->second;
            }
            return 0;
        }

        /**
         * Get diagnostic stats about NPC mapping coverage
         */
        std::string GetMappingStats() const
        {
            int total = 0, mapped = 0;
            int byPersist = 0, byParent = 0, bySave = 0, byStart = 0;
            int byLocation = 0, byEditor = 0, byPackage = 0, byRescan = 0;

            for (const auto& [formId, source] : m_mappingSources) {
                mapped++;
                switch (source) {
                    case MappingSource::ExtraPersistentCell: byPersist++; break;
                    case MappingSource::ParentCell: byParent++; break;
                    case MappingSource::SaveParentCell: bySave++; break;
                    case MappingSource::ExtraStartingWorldOrCell: byStart++; break;
                    case MappingSource::CurrentLocation: byLocation++; break;
                    case MappingSource::EditorLocation: byEditor++; break;
                    case MappingSource::PackageLocation: byPackage++; break;
                    case MappingSource::PostLoadRescan: byRescan++; break;
                    default: break;
                }
            }

            // Count total unique NPCs
            for (const auto& entry : m_entries) {
                if (entry.isUnique) total++;
            }

            return "Total unique: " + std::to_string(total) +
                   ", Mapped: " + std::to_string(mapped) +
                   ", Unmapped: " + std::to_string(m_unmappedNPCs.size()) +
                   " | Sources - Persist: " + std::to_string(byPersist) +
                   ", Parent: " + std::to_string(byParent) +
                   ", Save: " + std::to_string(bySave) +
                   ", Start: " + std::to_string(byStart) +
                   ", Location: " + std::to_string(byLocation) +
                   ", Editor: " + std::to_string(byEditor) +
                   ", Package: " + std::to_string(byPackage) +
                   ", Rescan: " + std::to_string(byRescan);
        }

        /**
         * Get the number of unmapped unique NPCs
         */
        int GetUnmappedCount() const
        {
            return static_cast<int>(m_unmappedNPCs.size());
        }

        static RE::BSFixedString Papyrus_GetActorFinderStats(RE::StaticFunctionTag*)
        {
            return GetInstance().GetMappingStats().c_str();
        }

        static int32_t Papyrus_GetUnmappedNPCCount(RE::StaticFunctionTag*)
        {
            return GetInstance().GetUnmappedCount();
        }

        static void Papyrus_ForceRescan(RE::StaticFunctionTag*)
        {
            GetInstance().PostLoadRescan();
        }

        // ====================================================================
        // POSITION SNAPSHOT - Papyrus Wrappers
        // ====================================================================

        static std::vector<float> Papyrus_GetActorLastKnownPosition(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            std::vector<float> result = {0.0f, 0.0f, 0.0f};
            if (!actor) return result;

            auto pos = GetInstance().GetActorLastKnownPosition(actor);
            result[0] = pos.x;
            result[1] = pos.y;
            result[2] = pos.z;
            return result;
        }

        static RE::BSFixedString Papyrus_GetActorWorldspaceName(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            if (!actor) return "";

            auto* npcBase = actor->GetActorBase();
            if (!npcBase) return "";

            // If loaded, check live worldspace
            if (actor->Is3DLoaded()) {
                auto* cell = actor->GetParentCell();
                if (cell && !cell->IsInteriorCell()) {
                    auto* ws = cell->GetRuntimeData().worldSpace;
                    if (ws) {
                        const char* name = ws->GetName();
                        if (name && name[0] != '\0') return name;
                    }
                }
                return "";  // Interior cell = no worldspace
            }

            // Unloaded - check snapshot
            auto snap = GetInstance().GetPositionSnapshot(npcBase->GetFormID());
            if (snap.valid && snap.worldspaceId != 0) {
                auto wsName = GetWorldspaceName(snap.worldspaceId);
                if (!wsName.empty()) return wsName.c_str();
            }

            return "";
        }

        static bool Papyrus_IsActorInExterior(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            if (!actor) return false;

            // If loaded, check live cell
            if (actor->Is3DLoaded()) {
                auto* cell = actor->GetParentCell();
                if (cell) return !cell->IsInteriorCell();
            }

            // Unloaded - check snapshot
            auto* npcBase = actor->GetActorBase();
            if (!npcBase) return false;

            auto snap = GetInstance().GetPositionSnapshot(npcBase->GetFormID());
            if (snap.valid) {
                return snap.worldspaceId != 0;  // Has worldspace = exterior
            }

            return false;
        }

        static float Papyrus_GetActorSnapshotGameTime(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            if (!actor) return 0.0f;

            auto* npcBase = actor->GetActorBase();
            if (!npcBase) return 0.0f;

            auto snap = GetInstance().GetPositionSnapshot(npcBase->GetFormID());
            return snap.valid ? snap.gameTime : 0.0f;
        }

        static bool Papyrus_HasPositionSnapshot(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            if (!actor) return false;

            auto* npcBase = actor->GetActorBase();
            if (!npcBase) return false;

            auto snap = GetInstance().GetPositionSnapshot(npcBase->GetFormID());
            return snap.valid;
        }

        static float Papyrus_GetDistanceBetweenActors(RE::StaticFunctionTag*, RE::Actor* actor1, RE::Actor* actor2)
        {
            if (!actor1 || !actor2) return -1.0f;

            auto& inst = GetInstance();

            // Get snapshots to check worldspace/cell compatibility
            auto* npcBase1 = actor1->GetActorBase();
            auto* npcBase2 = actor2->GetActorBase();
            if (!npcBase1 || !npcBase2) return -1.0f;

            // Snapshot both actors (updates if loaded, uses cached if not)
            auto pos1 = inst.GetActorLastKnownPosition(actor1);
            auto pos2 = inst.GetActorLastKnownPosition(actor2);

            // Check if both positions are valid (not origin)
            if (pos1.x == 0.0f && pos1.y == 0.0f && pos1.z == 0.0f) return -1.0f;
            if (pos2.x == 0.0f && pos2.y == 0.0f && pos2.z == 0.0f) return -1.0f;

            // Get snapshots for worldspace/cell comparison
            auto snap1 = inst.GetPositionSnapshot(npcBase1->GetFormID());
            auto snap2 = inst.GetPositionSnapshot(npcBase2->GetFormID());

            if (snap1.valid && snap2.valid) {
                // Different worldspaces = incomparable (Tamriel vs Solstheim, etc.)
                if (snap1.worldspaceId != snap2.worldspaceId) {
                    SKSE::log::info("ActorFinder: GetDistanceBetweenActors - different worldspaces ({:08X} vs {:08X}), returning -1",
                        snap1.worldspaceId, snap2.worldspaceId);
                    return -1.0f;
                }

                // Both interior (worldspaceId == 0) but different cells = incomparable
                if (snap1.worldspaceId == 0 && snap2.worldspaceId == 0 &&
                    snap1.cellId != snap2.cellId) {
                    SKSE::log::info("ActorFinder: GetDistanceBetweenActors - different interior cells ({:08X} vs {:08X}), returning -1",
                        snap1.cellId, snap2.cellId);
                    return -1.0f;
                }
            }

            float dx = pos1.x - pos2.x;
            float dy = pos1.y - pos2.y;
            float dz = pos1.z - pos2.z;
            return std::sqrt(dx * dx + dy * dy + dz * dz);
        }

        static int32_t Papyrus_GetPositionSnapshotCount(RE::StaticFunctionTag*)
        {
            std::lock_guard<std::mutex> lock(GetInstance().m_snapshotMutex);
            return static_cast<int32_t>(GetInstance().m_positionSnapshots.size());
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("FindActorByName", scriptName, Papyrus_FindActorByName);
            a_vm->RegisterFunction("GetActorLocationName", scriptName, Papyrus_GetActorLocationName);
            a_vm->RegisterFunction("FindActorHome", scriptName, Papyrus_FindActorHome);
            a_vm->RegisterFunction("GetActorHomeCellName", scriptName, Papyrus_GetActorHomeCellName);
            a_vm->RegisterFunction("IsActorFinderReady", scriptName, Papyrus_IsActorFinderReady);
            a_vm->RegisterFunction("GetActorIndexedCellName", scriptName, Papyrus_GetActorIndexedCellName);
            a_vm->RegisterFunction("GetActorFinderStats", scriptName, Papyrus_GetActorFinderStats);
            a_vm->RegisterFunction("GetUnmappedNPCCount", scriptName, Papyrus_GetUnmappedNPCCount);
            a_vm->RegisterFunction("ActorFinder_ForceRescan", scriptName, Papyrus_ForceRescan);

            // Position snapshot functions
            a_vm->RegisterFunction("GetActorLastKnownPosition", scriptName, Papyrus_GetActorLastKnownPosition);
            a_vm->RegisterFunction("GetActorWorldspaceName", scriptName, Papyrus_GetActorWorldspaceName);
            a_vm->RegisterFunction("IsActorInExterior", scriptName, Papyrus_IsActorInExterior);
            a_vm->RegisterFunction("GetActorSnapshotGameTime", scriptName, Papyrus_GetActorSnapshotGameTime);
            a_vm->RegisterFunction("HasPositionSnapshot", scriptName, Papyrus_HasPositionSnapshot);
            a_vm->RegisterFunction("GetDistanceBetweenActors", scriptName, Papyrus_GetDistanceBetweenActors);
            a_vm->RegisterFunction("GetPositionSnapshotCount", scriptName, Papyrus_GetPositionSnapshotCount);

            SKSE::log::info("Registered actor finder functions (including position snapshots)");
        }

    private:
        ActorFinder() = default;
        ActorFinder(const ActorFinder&) = delete;
        ActorFinder& operator=(const ActorFinder&) = delete;

        /**
         * Record an NPC-to-location mapping, keeping cell and location FormIDs separate
         */
        void RecordNPCMapping(RE::FormID npcFormId, const std::string& locationName,
                              RE::TESObjectCELL* cell, RE::BGSLocation* location,
                              MappingSource source)
        {
            m_actorCellIndex[npcFormId] = locationName;
            m_mappingSources[npcFormId] = source;

            // Only store actual TESObjectCELL FormIDs in the cell index
            if (cell) {
                m_actorCellFormIndex[npcFormId] = cell->GetFormID();
            }

            // Store BGSLocation FormIDs separately
            if (location) {
                m_actorLocationFormIndex[npcFormId] = location->GetFormID();
            }
        }

        /**
         * Scan an NPC's AI packages for location/cell references.
         * Package data contains cell references for sleep, sandbox, eat, etc. locations.
         * This is CK-authored data so it's always available at kDataLoaded.
         * Returns pair of (locationName, cell pointer or nullptr)
         *
         * API: TESNPC -> TESActorBase -> TESAIForm::aiPackages (PackageList)
         *      PackageList::packages (BSSimpleList<TESPackage*>)
         *      TESPackage::packLoc (PackageLocation*)
         *      PackageLocation::locType, data.object (TESForm*)
         */
        std::pair<std::string, RE::TESObjectCELL*> ScanNPCPackagesForLocation(RE::TESNPC* npc)
        {
            if (!npc) return {"", nullptr};

            // TESAIForm::aiPackages is a PackageList containing BSSimpleList<TESPackage*>
            auto& packageList = npc->aiPackages;

            for (auto* package : packageList.packages) {
                if (!package) continue;

                // Check the package's location pointer
                auto* packLoc = package->packLoc;
                if (!packLoc) continue;

                auto locType = packLoc->locType.get();

                // We care about packages that reference specific cells/locations
                if (locType == RE::PackageLocation::Type::kNearReference ||
                    locType == RE::PackageLocation::Type::kInCell ||
                    locType == RE::PackageLocation::Type::kNearEditorLocation ||
                    locType == RE::PackageLocation::Type::kObjectID) {

                    auto* locForm = packLoc->data.object;
                    if (!locForm) continue;

                    // Try as TESObjectCELL (direct cell reference)
                    auto* cellForm = locForm->As<RE::TESObjectCELL>();
                    if (cellForm) {
                        const char* cellName = cellForm->GetFullName();
                        if (cellName && cellName[0] != '\0') {
                            return {cellName, cellForm};
                        }
                    }

                    // Try as BGSLocation
                    auto* locRef = locForm->As<RE::BGSLocation>();
                    if (locRef) {
                        const char* locName = locRef->GetName();
                        if (locName && locName[0] != '\0') {
                            return {locName, nullptr};
                        }
                    }

                    // Try as ObjectReference (e.g., a marker or furniture)
                    auto* objRef = locForm->As<RE::TESObjectREFR>();
                    if (objRef) {
                        auto* refCell = objRef->GetParentCell();
                        if (refCell) {
                            const char* cellName = refCell->GetFullName();
                            if (cellName && cellName[0] != '\0') {
                                return {cellName, refCell};
                            }
                        }
                        auto* refLoc = objRef->GetCurrentLocation();
                        if (!refLoc) refLoc = objRef->GetEditorLocation();
                        if (refLoc) {
                            const char* locName = refLoc->GetName();
                            if (locName && locName[0] != '\0') {
                                return {locName, nullptr};
                            }
                        }
                    }
                }
            }

            return {"", nullptr};
        }

        /**
         * Scan an NPC's AI packages specifically for sleep packages.
         * Sleep packages reference the cell where an NPC sleeps — their "home."
         * Returns a pair of (cell name, cell pointer or nullptr).
         *
         * Checks packData.packType == kSleep, then extracts location from packLoc.
         * Falls back to checking package editor ID for "sleep" substring if type check fails.
         */
        std::pair<std::string, RE::TESObjectCELL*> ScanNPCPackagesForHome(RE::TESNPC* npc)
        {
            if (!npc) return {"", nullptr};

            auto& packageList = npc->aiPackages;

            for (auto* package : packageList.packages) {
                if (!package) continue;

                // Check if this is a sleep package
                bool isSleepPackage = (package->packData.packType == RE::PACKAGE_PROCEDURE_TYPE::kSleep);

                // Fallback: check editor ID for "sleep" substring
                if (!isSleepPackage) {
                    const char* editorId = package->GetFormEditorID();
                    if (editorId) {
                        std::string edId = StringUtils::ToLower(editorId);
                        if (edId.find("sleep") != std::string::npos) {
                            isSleepPackage = true;
                        }
                    }
                }

                if (!isSleepPackage) continue;

                // Extract the location from this sleep package
                auto* packLoc = package->packLoc;
                if (!packLoc) continue;

                auto locType = packLoc->locType.get();

                // Types with a location object we can resolve
                if (locType == RE::PackageLocation::Type::kNearReference ||
                    locType == RE::PackageLocation::Type::kInCell ||
                    locType == RE::PackageLocation::Type::kNearEditorLocation ||
                    locType == RE::PackageLocation::Type::kObjectID ||
                    locType == RE::PackageLocation::Type::kAlias_Reference ||
                    locType == RE::PackageLocation::Type::kAlias_Location) {

                    auto* locForm = packLoc->data.object;
                    if (!locForm) continue;

                    // Try as TESObjectCELL (direct cell reference)
                    auto* cellForm = locForm->As<RE::TESObjectCELL>();
                    if (cellForm) {
                        const char* cellName = cellForm->GetFullName();
                        if (cellName && cellName[0] != '\0') {
                            return {cellName, cellForm};
                        }
                    }

                    // Try as ObjectReference (bed, marker, etc.) — get its parent cell
                    auto* objRef = locForm->As<RE::TESObjectREFR>();
                    if (objRef) {
                        auto* refCell = objRef->GetParentCell();
                        if (refCell) {
                            const char* cellName = refCell->GetFullName();
                            if (cellName && cellName[0] != '\0') {
                                return {cellName, refCell};
                            }
                        }
                        // Try the ref's extra persistent cell
                        auto* extraPersist = objRef->extraList.GetByType<RE::ExtraPersistentCell>();
                        if (extraPersist && extraPersist->persistentCell) {
                            auto* pCell = extraPersist->persistentCell;
                            const char* cellName = pCell->GetFullName();
                            if (cellName && cellName[0] != '\0') {
                                return {cellName, pCell};
                            }
                        }
                    }

                    // Try as BGSLocation — less precise but still useful
                    auto* locRef = locForm->As<RE::BGSLocation>();
                    if (locRef) {
                        const char* locName = locRef->GetName();
                        if (locName && locName[0] != '\0') {
                            return {locName, nullptr};
                        }
                    }
                }

                // Types without a resolvable location object (kNearSelf, kNearLinkedReference, etc.)
                // We know this is a sleep package, so just mark that we found one.
                // The caller's fallback (placement cell from NPC-to-cell index) will handle resolution.
                // Log it so we know why home index falls through to the fallback.
                if (locType == RE::PackageLocation::Type::kNearSelf ||
                    locType == RE::PackageLocation::Type::kNearLinkedReference ||
                    locType == RE::PackageLocation::Type::kNearPackageStartLocation) {
                    SKSE::log::info("ActorFinder: ScanNPCPackagesForHome - '{}' has sleep package with locType={} (no cell data), deferring to fallback",
                        npc->GetName() ? npc->GetName() : "unknown", static_cast<int>(locType));
                }
            }

            return {"", nullptr};
        }

        /**
         * Check if an actor matches a search name, including NPC Names Distributor names.
         * Checks: base game name, full NND display name, and NND name portion (before title bracket).
         * NND format 3 example: "Harold [Bandit]" — matches "harold", "harold [bandit]", "harold [bandit]"
         */
        /**
         * Check if an actor is a mannequin (display dummy, not a real NPC).
         * Mannequins use ManakinRace (Bethesda's spelling) and should be excluded
         * from name searches to prevent matching mannequins named after real NPCs.
         */
        static bool IsMannequin(RE::Actor* actorPtr)
        {
            if (!actorPtr) return false;

            auto* race = actorPtr->GetRace();
            if (!race) return false;

            const char* editorID = race->GetFormEditorID();
            if (editorID) {
                // Vanilla mannequin race: ManakinRace (Bethesda misspelling)
                if (_stricmp(editorID, "ManakinRace") == 0) return true;
                // Some mods use alternate spellings
                if (_stricmp(editorID, "MannequinRace") == 0) return true;
                // SOS mannequin race (displays as "Nord" but is a mannequin)
                if (_stricmp(editorID, "SOS_FemaleMannequinRace") == 0) return true;

                // Catch-all: any race with "mannequin" or "manakin" in the editor ID
                std::string lowerEditorID = StringUtils::ToLower(editorID);
                if (lowerEditorID.find("mannequin") != std::string::npos) return true;
                if (lowerEditorID.find("manakin") != std::string::npos) return true;
            }

            return false;
        }

        /**
         * Check if an NPC base form uses a mannequin race.
         * Used during Initialize() to filter mannequin NPC records from the name index.
         */
        static bool IsMannequinBase(RE::TESNPC* npc)
        {
            if (!npc) return false;

            auto* race = npc->GetRace();
            if (!race) return false;

            const char* editorID = race->GetFormEditorID();
            if (editorID) {
                if (_stricmp(editorID, "ManakinRace") == 0) return true;
                if (_stricmp(editorID, "MannequinRace") == 0) return true;
                if (_stricmp(editorID, "SOS_FemaleMannequinRace") == 0) return true;

                std::string lowerEditorID = StringUtils::ToLower(editorID);
                if (lowerEditorID.find("mannequin") != std::string::npos) return true;
                if (lowerEditorID.find("manakin") != std::string::npos) return true;
            }

            return false;
        }

        bool ActorMatchesName(RE::Actor* actorPtr, const std::string& lowerName)
        {
            if (!actorPtr) return false;

            // Skip mannequins — they can have NPC names but aren't real actors
            if (IsMannequin(actorPtr)) return false;

            // Skip mod-generated clone NPCs (e.g. sos_Hulda from Skyrim On Skooma)
            auto* actorBase = actorPtr->GetActorBase();
            if (actorBase) {
                const char* editorID = actorBase->GetFormEditorID();
                if (editorID && editorID[0] != '\0') {
                    std::string lowerEditorID = StringUtils::ToLower(editorID);
                    if (lowerEditorID.substr(0, 4) == "sos_") return false;
                }
            }

            // Check base game name first (fastest path)
            const char* baseName = actorPtr->GetName();
            if (baseName) {
                std::string lowerBase = StringUtils::ToLower(baseName);
                if (lowerBase == lowerName) return true;
            }

            // Check NND name if the mod is installed
            if (m_nndAPI) {
                std::string_view nndName = m_nndAPI->GetName(actorPtr, NND_API::NameContext::kOther);
                if (!nndName.empty()) {
                    std::string lowerNND = StringUtils::ToLower(std::string(nndName));

                    // Exact match on full NND name (e.g. "harold [bandit]")
                    if (lowerNND == lowerName) return true;

                    // Match just the name portion before the title bracket
                    // NND formats: "Name [Title]", "Name (Title)", "Name, Title", "Name; Title", "Name. Title"
                    // Extract the first word/name part by finding common delimiters
                    size_t bracketPos = lowerNND.find(" [");
                    if (bracketPos == std::string::npos) bracketPos = lowerNND.find(" (");
                    if (bracketPos == std::string::npos) bracketPos = lowerNND.find(", ");
                    if (bracketPos == std::string::npos) bracketPos = lowerNND.find("; ");

                    if (bracketPos != std::string::npos) {
                        std::string nameOnly = lowerNND.substr(0, bracketPos);
                        if (nameOnly == lowerName) return true;
                    }

                    // Also check if the search term is contained within the NND name
                    // (handles partial matches like searching "harold" matching "harold stormwall")
                    if (lowerNND.find(lowerName) == 0) return true;
                }
            }

            return false;
        }

        /**
         * Search currently loaded actors for a name match.
         * Checks both base game names and NPC Names Distributor names.
         */
        RE::Actor* FindLoadedActorByName(const std::string& lowerName)
        {
            auto* processLists = RE::ProcessLists::GetSingleton();
            if (!processLists) return nullptr;

            for (auto& handle : processLists->highActorHandles) {
                auto actor = handle.get();
                if (!actor || !actor.get()) continue;
                if (ActorMatchesName(actor.get(), lowerName)) return actor.get();
            }

            for (auto& handle : processLists->middleHighActorHandles) {
                auto actor = handle.get();
                if (!actor || !actor.get()) continue;
                if (ActorMatchesName(actor.get(), lowerName)) return actor.get();
            }

            for (auto& handle : processLists->lowActorHandles) {
                auto actor = handle.get();
                if (!actor || !actor.get()) continue;
                if (ActorMatchesName(actor.get(), lowerName)) return actor.get();
            }

            return nullptr;
        }

        /**
         * Score an actor reference to determine if it's the "real" NPC or an orphaned duplicate.
         * Higher score = more likely to be the legitimate, CK-placed reference.
         *
         * Duplicate actors (from mods, leftover references, etc.) tend to:
         * - Have no parent cell, or be in unnamed/test cells
         * - Have no ExtraPersistentCell (not placed by CK)
         * - Be disabled or deleted
         * - Be at position (0,0,0) — the void
         *
         * Real NPCs tend to:
         * - Be in named, inhabited cells
         * - Have ExtraPersistentCell set
         * - Have valid positions
         * - Be enabled and not deleted
         */
        int ScoreActorReference(RE::Actor* actor, RE::FormID baseFormId) const
        {
            if (!actor) return -1000;

            int score = 0;

            // Mannequins are never the right answer
            if (IsMannequin(actor)) return -1000;

            // Check if this is a mod-generated clone (e.g. sos_ prefix NPCs)
            auto* npcBase = actor->GetActorBase();
            if (npcBase) {
                const char* editorID = npcBase->GetFormEditorID();
                if (editorID && editorID[0] != '\0') {
                    std::string lowerEditorID = StringUtils::ToLower(editorID);
                    if (lowerEditorID.substr(0, 4) == "sos_") return -1000;
                }
            }

            // Disabled or deleted actors are almost certainly not the real one
            if (actor->IsDisabled()) score -= 100;
            if (actor->IsDeleted()) return -1000;

            // 3D loaded = currently active in the game world (best signal)
            if (actor->Is3DLoaded()) score += 50;

            // Has a parent cell = exists somewhere real
            auto* parentCell = actor->GetParentCell();
            if (parentCell) {
                score += 20;

                // Cell has a name = not a test/void cell
                const char* cellName = parentCell->GetFullName();
                if (cellName && cellName[0] != '\0') {
                    score += 10;
                }

                // Interior cell with a name is a strong signal (shops, homes, etc.)
                if (parentCell->IsInteriorCell() && cellName && cellName[0] != '\0') {
                    score += 10;
                }
            }

            // Has ExtraPersistentCell = CK-placed reference (very strong signal)
            auto* extraPersist = actor->extraList.GetByType<RE::ExtraPersistentCell>();
            if (extraPersist && extraPersist->persistentCell) {
                score += 30;
            }

            // Has a save parent cell = existed in the save game (real NPC)
            auto* saveCell = actor->GetSaveParentCell();
            if (saveCell) {
                score += 20;
            }

            // Has a current location = Skyrim's AI system knows about this actor
            auto* currentLoc = actor->GetCurrentLocation();
            if (currentLoc) {
                score += 15;
            }

            // Has an editor location = CK-placed
            auto* editorLoc = actor->GetEditorLocation();
            if (editorLoc) {
                score += 15;
            }

            // Is in our NPC-to-cell index = we mapped this ref during kDataLoaded
            auto indexIt = m_actorCellIndex.find(baseFormId);
            if (indexIt != m_actorCellIndex.end()) {
                // Check if this actor's cell matches the indexed cell
                auto cellFormIt = m_actorCellFormIndex.find(baseFormId);
                if (cellFormIt != m_actorCellFormIndex.end() && parentCell) {
                    if (parentCell->GetFormID() == cellFormIt->second) {
                        score += 25;  // In the exact cell we expect
                    }
                }
            }

            // Position at (0,0,0) is suspicious — likely an orphaned reference
            auto pos = actor->GetPosition();
            if (pos.x == 0.0f && pos.y == 0.0f && pos.z == 0.0f) {
                score -= 50;
            }

            // Check if reference FormID matches our cached "known good" ref
            auto refIt = m_npcRefFormIds.find(baseFormId);
            if (refIt != m_npcRefFormIds.end() && actor->GetFormID() == refIt->second) {
                score += 10;  // Slight preference for the ref we saw during init
            }

            return score;
        }

        /**
         * Find actor reference from base NPC form ID.
         * Searches process lists first (loaded actors), then falls back to global form map.
         *
         * DUPLICATE HANDLING: When multiple actor references share the same NPC base form
         * (common with mod-added duplicates), scores each candidate and returns the one
         * most likely to be the "real" NPC — preferring loaded actors, actors in named cells,
         * CK-placed references, and actors with valid positions over orphaned duplicates.
         */
        RE::Actor* FindActorReference(RE::FormID baseFormId)
        {
            // First try ProcessLists (fast, for loaded actors)
            // Loaded actors in process lists are almost always the real ones
            auto* processLists = RE::ProcessLists::GetSingleton();
            if (processLists) {
                auto checkList = [&](auto& handles) -> RE::Actor* {
                    for (auto& handle : handles) {
                        auto actor = handle.get();
                        if (!actor || !actor.get()) continue;

                        auto* actorPtr = actor.get();
                        if (IsMannequin(actorPtr)) continue;
                        auto* base = actorPtr->GetActorBase();
                        if (base && base->GetFormID() == baseFormId) {
                            return actorPtr;
                        }
                    }
                    return nullptr;
                };

                RE::Actor* result = checkList(processLists->highActorHandles);
                if (result) return result;

                result = checkList(processLists->middleHighActorHandles);
                if (result) return result;

                result = checkList(processLists->lowActorHandles);
                if (result) return result;
            }

            // Not loaded — search global form map and score ALL candidates
            // to pick the best one (handles mod duplicates)
            RE::Actor* bestCandidate = nullptr;
            int bestScore = -999;
            int candidateCount = 0;

            // Try cached ref first as a starting candidate
            {
                auto refIt = m_npcRefFormIds.find(baseFormId);
                if (refIt != m_npcRefFormIds.end()) {
                    auto* form = RE::TESForm::LookupByID(refIt->second);
                    if (form) {
                        auto* actor = form->As<RE::Actor>();
                        if (actor) {
                            int score = ScoreActorReference(actor, baseFormId);
                            if (score > bestScore) {
                                bestCandidate = actor;
                                bestScore = score;
                            }
                            candidateCount++;
                        }
                    }
                }
            }

            // Scan global form map for ALL matching actors
            {
                auto [allForms, formLock] = RE::TESForm::GetAllForms();
                if (allForms) {
                    RE::BSReadWriteLock readLock{ formLock };
                    for (auto& [formId, form] : *allForms) {
                        if (!form) continue;
                        if (form->GetFormType() != RE::FormType::ActorCharacter) continue;

                        auto* actor = form->As<RE::Actor>();
                        if (!actor) continue;

                        auto* base = actor->GetActorBase();
                        if (!base || base->GetFormID() != baseFormId) continue;

                        // Skip if this is the same ref we already scored from cache
                        if (bestCandidate && actor->GetFormID() == bestCandidate->GetFormID()) continue;

                        candidateCount++;
                        int score = ScoreActorReference(actor, baseFormId);

                        if (score > bestScore) {
                            bestCandidate = actor;
                            bestScore = score;
                        }
                    }
                }
            }

            if (candidateCount > 1) {
                auto* npcBase = RE::TESForm::LookupByID<RE::TESNPC>(baseFormId);
                SKSE::log::warn("ActorFinder: FindActorReference - found {} candidates for '{}' ({:08X}), picked ref {:08X} with score {}",
                    candidateCount, npcBase ? npcBase->GetName() : "unknown", baseFormId,
                    bestCandidate ? bestCandidate->GetFormID() : 0, bestScore);

                // Update cached ref to the winning candidate so future lookups are fast
                if (bestCandidate) {
                    m_npcRefFormIds[baseFormId] = bestCandidate->GetFormID();
                }
            }

            return bestCandidate;
        }

        /**
         * Same as FindActorReference but does NOT acquire m_mutex (for use from methods that already hold it).
         * Uses the same duplicate-aware scoring system.
         */
        RE::Actor* FindActorReferenceUnlocked(RE::FormID baseFormId)
        {
            // Try ProcessLists first (loaded actors are best)
            auto* processLists = RE::ProcessLists::GetSingleton();
            if (processLists) {
                auto checkList = [&](auto& handles) -> RE::Actor* {
                    for (auto& handle : handles) {
                        auto actor = handle.get();
                        if (!actor || !actor.get()) continue;
                        auto* actorPtr = actor.get();
                        if (IsMannequin(actorPtr)) continue;
                        auto* base = actorPtr->GetActorBase();
                        if (base && base->GetFormID() == baseFormId) return actorPtr;
                    }
                    return nullptr;
                };

                RE::Actor* result = checkList(processLists->highActorHandles);
                if (result) return result;
                result = checkList(processLists->middleHighActorHandles);
                if (result) return result;
                result = checkList(processLists->lowActorHandles);
                if (result) return result;
            }

            // Not loaded — score ALL candidates from global form map
            RE::Actor* bestCandidate = nullptr;
            int bestScore = -999;

            // Try cached ref as starting candidate
            auto refIt = m_npcRefFormIds.find(baseFormId);
            if (refIt != m_npcRefFormIds.end()) {
                auto* form = RE::TESForm::LookupByID(refIt->second);
                if (form) {
                    auto* actor = form->As<RE::Actor>();
                    if (actor) {
                        bestCandidate = actor;
                        bestScore = ScoreActorReference(actor, baseFormId);
                    }
                }
            }

            // Scan all forms for candidates
            auto [allForms, formLock] = RE::TESForm::GetAllForms();
            if (allForms) {
                RE::BSReadWriteLock readLock{ formLock };
                for (auto& [formId, form] : *allForms) {
                    if (!form) continue;
                    if (form->GetFormType() != RE::FormType::ActorCharacter) continue;
                    auto* actor = form->As<RE::Actor>();
                    if (!actor) continue;
                    auto* base = actor->GetActorBase();
                    if (!base || base->GetFormID() != baseFormId) continue;
                    if (bestCandidate && actor->GetFormID() == bestCandidate->GetFormID()) continue;

                    int score = ScoreActorReference(actor, baseFormId);
                    if (score > bestScore) {
                        bestCandidate = actor;
                        bestScore = score;
                    }
                }
            }

            // Update cache if we found a better candidate
            if (bestCandidate) {
                m_npcRefFormIds[baseFormId] = bestCandidate->GetFormID();
            }

            return bestCandidate;
        }

        static int LevenshteinDistance(const std::string& a, const std::string& b)
        {
            const size_t m = a.length();
            const size_t n = b.length();

            std::vector<std::vector<int>> dp(m + 1, std::vector<int>(n + 1));

            for (size_t i = 0; i <= m; i++) dp[i][0] = static_cast<int>(i);
            for (size_t j = 0; j <= n; j++) dp[0][j] = static_cast<int>(j);

            for (size_t i = 1; i <= m; i++) {
                for (size_t j = 1; j <= n; j++) {
                    int cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
                    dp[i][j] = (std::min)({
                        dp[i - 1][j] + 1,
                        dp[i][j - 1] + 1,
                        dp[i - 1][j - 1] + cost
                    });
                }
            }

            return dp[m][n];
        }

        std::vector<ActorEntry> m_entries;
        std::unordered_map<std::string, size_t> m_exactLookup;           // name -> index (unique only)
        std::unordered_map<RE::FormID, std::string> m_actorCellIndex;    // NPC base FormID -> location name
        std::unordered_map<RE::FormID, RE::FormID> m_actorCellFormIndex; // NPC base FormID -> TESObjectCELL FormID (ONLY cells)
        std::unordered_map<RE::FormID, RE::FormID> m_actorLocationFormIndex; // NPC base FormID -> BGSLocation FormID
        std::unordered_map<RE::FormID, MappingSource> m_mappingSources;  // NPC base FormID -> how it was mapped
        std::unordered_map<RE::FormID, RE::FormID> m_npcRefFormIds;      // NPC base FormID -> actor ref FormID (for fast lookup)
        std::unordered_set<RE::FormID> m_unmappedNPCs;                   // NPCs that couldn't be mapped (for post-load rescan)

        // Home index: NPC base FormID -> home cell info (built from sleep packages at kDataLoaded)
        struct HomeInfo {
            RE::FormID cellFormId{0};       // Interior cell FormID where NPC sleeps
            std::string cellName;           // Display name of that cell
            std::string disambiguatedName;  // Disambiguated name e.g. "Cellar (Bannered Mare)"
        };
        std::unordered_map<RE::FormID, HomeInfo> m_homeIndex;  // NPC base FormID -> home info

        std::mutex m_mutex;
        bool m_initialized = false;
        bool m_eventSinkRegistered = false;  // Prevents duplicate event sink registration on reload

        // NPC Names Distributor integration (soft dependency — nullptr if mod not installed)
        NND_API::IVNND1* m_nndAPI = nullptr;

        // Position snapshot system
        std::unordered_map<RE::FormID, PositionSnapshot> m_positionSnapshots;  // NPC base FormID -> last known position
        mutable std::mutex m_snapshotMutex;                                     // Separate mutex for snapshot reads/writes
    };
}
