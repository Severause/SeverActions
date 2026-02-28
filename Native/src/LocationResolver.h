#pragma once

// SeverActionsNative - Location Resolver
// Dynamic location resolution replacing JSON-based TravelDB
// Auto-indexes all BGSLocation, TESCell, and door records at game load
// Supports fuzzy matching, semantic terms (outside/upstairs), and city aliases
// Author: Severause

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <string>
#include <unordered_map>
#include <vector>
#include <mutex>
#include <shared_mutex>
#include <algorithm>

#include "StringUtils.h"
#include "ActorFinder.h"

namespace SeverActionsNative
{
    // Skyrim.esm base form IDs for interior cell markers
    constexpr RE::FormID kXMarkerHeading = 0x00000034;  // XMarkerHeading — has facing direction
    constexpr RE::FormID kXMarker        = 0x0000003B;  // XMarker — position only

    // Location-specific tuning constants
    constexpr float  kLocationSearchRadius  = 5000.0f;  // Max distance for semantic door search
    constexpr float  kZAxisThreshold        = 100.0f;   // Vertical offset for upstairs/downstairs
    constexpr size_t kMinLocationNameLength  = 3;        // Minimum name length to index a location

    struct LocationEntry
    {
        std::string name;           // Display name (lowercase for matching)
        std::string displayName;    // Original display name
        std::string editorId;       // Editor ID
        RE::FormID formId;          // Form ID for lookup
        bool isInterior;            // Interior cell
        enum class Type { Cell, Location, Door } type;
    };

    /**
     * Dynamic location resolver - replaces TravelDB
     *
     * On kDataLoaded:
     *   - Scans all TESObjectCELL records for named interior/exterior cells
     *   - Scans all BGSLocation records for named locations
     *   - Builds hash maps for O(1) exact lookup + fast fuzzy search
     *   - Builds city/town alias table
     *
     * At runtime:
     *   - ResolveDestination() handles named places, fuzzy matching, semantic terms
     *   - No JSON files needed
     */
    class LocationResolver
    {
    public:
        static LocationResolver& GetInstance()
        {
            static LocationResolver instance;
            return instance;
        }

        /**
         * Initialize by scanning all game records
         * Called on kDataLoaded
         */
        void Initialize()
        {
            std::unique_lock<std::shared_mutex> lock(m_mutex);

            SKSE::log::info("LocationResolver: Scanning game records...");

            m_entries.clear();
            m_exactLookup.clear();
            m_editorIdLookup.clear();
            m_aliasLookup.clear();
            m_doorIndex.clear();
            m_cellFormToIndex.clear();
            m_nameOccurrences.clear();

            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            if (!dataHandler) {
                SKSE::log::error("LocationResolver: DataHandler not available");
                return;
            }

            // Scan all interior cells with names
            // NOTE: Cells are NOT in the standard form array (GetFormArray<TESObjectCELL> returns empty).
            // Interior cells are stored in dataHandler->interiorCells (NiTPrimitiveArray).
            //
            // Two-pass approach for duplicate name disambiguation:
            // Pass 1: Collect all cells and count name occurrences
            // Pass 2: For duplicate names, create disambiguated entries with parent location
            int cellCount = 0;
            auto& interiorCells = dataHandler->interiorCells;

            // Pass 1: Count name occurrences and collect cell data
            struct CellInfo {
                std::string name;           // lowercase name
                std::string displayName;    // original name
                std::string editorId;
                RE::FormID formId;
                std::string parentLocName;  // parent BGSLocation name for disambiguation
            };
            std::vector<CellInfo> cellInfos;
            std::unordered_map<std::string, int> nameCounts;  // lowercase name -> count

            for (std::uint16_t ci = 0; ci < interiorCells.size(); ++ci) {
                auto* cell = interiorCells[ci];
                if (!cell) continue;

                const char* name = cell->GetFullName();
                const char* editorId = cell->GetFormEditorID();
                if (!name || name[0] == '\0') continue;

                std::string nameStr(name);
                if (nameStr.length() < kMinLocationNameLength) continue;

                CellInfo info;
                info.name = StringUtils::ToLower(nameStr);
                info.displayName = nameStr;
                info.editorId = editorId ? editorId : "";
                info.formId = cell->GetFormID();

                // Get parent location name for disambiguation
                auto* parentLoc = cell->GetLocation();
                if (parentLoc) {
                    const char* locName = parentLoc->GetName();
                    if (locName && locName[0] != '\0') {
                        info.parentLocName = locName;
                    }
                }

                nameCounts[info.name]++;
                cellInfos.push_back(std::move(info));
            }

            int duplicatesDisambiguated = 0;

            // Pass 2: Add entries with disambiguation for duplicates
            for (auto& info : cellInfos) {
                LocationEntry entry;
                entry.name = info.name;
                entry.displayName = info.displayName;
                entry.editorId = info.editorId;
                entry.formId = info.formId;
                entry.isInterior = true;
                entry.type = LocationEntry::Type::Cell;

                size_t idx = m_entries.size();
                m_entries.push_back(std::move(entry));

                // Build reverse lookup and name occurrence count
                m_cellFormToIndex[info.formId] = idx;
                m_nameOccurrences[info.name] = nameCounts[info.name];

                // Index by base name (first-wins for backward compat)
                if (m_exactLookup.find(m_entries[idx].name) == m_exactLookup.end()) {
                    m_exactLookup[m_entries[idx].name] = idx;
                }

                // For duplicate names, also create a disambiguated entry: "cellar (bannered mare)"
                if (nameCounts[info.name] > 1 && !info.parentLocName.empty()) {
                    std::string disambiguated = info.name + " (" + StringUtils::ToLower(info.parentLocName) + ")";
                    if (m_exactLookup.find(disambiguated) == m_exactLookup.end()) {
                        m_exactLookup[disambiguated] = idx;
                        duplicatesDisambiguated++;
                    }
                }

                // Index by editor ID
                if (!m_entries[idx].editorId.empty()) {
                    std::string lowerEditorId = StringUtils::ToLower(m_entries[idx].editorId);
                    if (m_editorIdLookup.find(lowerEditorId) == m_editorIdLookup.end()) {
                        m_editorIdLookup[lowerEditorId] = idx;
                    }
                }

                cellCount++;
            }

            // Scan all BGSLocation records
            int locationCount = 0;
            for (auto* location : dataHandler->GetFormArray<RE::BGSLocation>()) {
                if (!location) continue;

                const char* name = location->GetName();
                const char* editorId = location->GetFormEditorID();
                if (!name || name[0] == '\0') continue;

                std::string nameStr(name);
                if (nameStr.length() < kMinLocationNameLength) continue;

                LocationEntry entry;
                entry.name = StringUtils::ToLower(nameStr);
                entry.displayName = nameStr;
                entry.editorId = editorId ? editorId : "";
                entry.formId = location->GetFormID();
                entry.isInterior = false;
                entry.type = LocationEntry::Type::Location;

                size_t idx = m_entries.size();
                m_entries.push_back(std::move(entry));

                // Index by name (don't overwrite cells - cells are more specific)
                if (m_exactLookup.find(m_entries[idx].name) == m_exactLookup.end()) {
                    m_exactLookup[m_entries[idx].name] = idx;
                }

                // Index by editor ID
                if (!m_entries[idx].editorId.empty()) {
                    std::string lowerEditorId = StringUtils::ToLower(m_entries[idx].editorId);
                    if (m_editorIdLookup.find(lowerEditorId) == m_editorIdLookup.end()) {
                        m_editorIdLookup[lowerEditorId] = idx;
                    }
                }

                locationCount++;
            }

            // Build city aliases
            BuildAliases();

            // Build prefix index for fuzzy search
            BuildPrefixIndex();

            // Build door-to-cell index: scan ALL worldspace cells for teleport doors
            // This maps interior cell FormID -> exterior door FormID for O(1) lookup
            BuildDoorIndex(dataHandler);

            m_initialized = true;

            // Release excess vector capacity now that init is done
            m_entries.shrink_to_fit();

            SKSE::log::info("LocationResolver: Indexed {} cells ({} disambiguated), {} locations, {} total entries, {} door mappings",
                cellCount, duplicatesDisambiguated, locationCount, m_entries.size(), m_doorIndex.size());
        }

        /**
         * Main resolution function - handles everything
         * @param actor The actor who needs to travel (for semantic context like "outside")
         * @param destination The place name, semantic term, or fuzzy query
         * @return ObjectReference to travel to, or nullptr
         */
        RE::TESObjectREFR* ResolveDestination(RE::Actor* actor, const std::string& destination)
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized || destination.empty()) {
                SKSE::log::warn("LocationResolver: ResolveDestination called but {} (dest='{}')",
                    !m_initialized ? "not initialized" : "empty destination", destination);
                return nullptr;
            }
            std::string lowerDest = StringUtils::ToLower(StringUtils::TrimString(destination));
            SKSE::log::info("LocationResolver: Resolving '{}' (lowered: '{}')", destination, lowerDest);

            // 1. Semantic terms (outside, upstairs, downstairs)
            RE::TESObjectREFR* semantic = ResolveSemanticTerm(actor, lowerDest);
            if (semantic) return semantic;

            // 2. Exact name match
            auto exactIt = m_exactLookup.find(lowerDest);
            if (exactIt != m_exactLookup.end()) {
                SKSE::log::info("LocationResolver: Exact match found: '{}' (formId={:08X}, type={}, interior={})",
                    m_entries[exactIt->second].displayName, m_entries[exactIt->second].formId,
                    (int)m_entries[exactIt->second].type, m_entries[exactIt->second].isInterior);
                RE::TESObjectREFR* ref = GetReferenceForEntry(m_entries[exactIt->second]);
                if (ref) return ref;
                SKSE::log::warn("LocationResolver: Exact match '{}' found but GetReferenceForEntry returned null", m_entries[exactIt->second].displayName);
            } else {
                SKSE::log::info("LocationResolver: No exact match for '{}'", lowerDest);
            }

            // 3. City/town alias
            auto aliasIt = m_aliasLookup.find(lowerDest);
            if (aliasIt != m_aliasLookup.end()) {
                SKSE::log::info("LocationResolver: Alias found: '{}' -> '{}'", lowerDest, aliasIt->second);
                auto resolvedIt = m_exactLookup.find(aliasIt->second);
                if (resolvedIt != m_exactLookup.end()) {
                    SKSE::log::info("LocationResolver: Alias resolved to entry: '{}' (formId={:08X}, type={}, interior={})",
                        m_entries[resolvedIt->second].displayName, m_entries[resolvedIt->second].formId,
                        (int)m_entries[resolvedIt->second].type, m_entries[resolvedIt->second].isInterior);
                    RE::TESObjectREFR* ref = GetReferenceForEntry(m_entries[resolvedIt->second]);
                    if (ref) return ref;
                    SKSE::log::warn("LocationResolver: Alias target '{}' found but GetReferenceForEntry returned null", m_entries[resolvedIt->second].displayName);
                } else {
                    SKSE::log::info("LocationResolver: Alias target '{}' not found in exact lookup", aliasIt->second);
                }
                // Try editor ID lookup for alias target
                auto editorIt = m_editorIdLookup.find(aliasIt->second);
                if (editorIt != m_editorIdLookup.end()) {
                    SKSE::log::info("LocationResolver: Alias target found via editor ID: '{}'", m_entries[editorIt->second].editorId);
                    RE::TESObjectREFR* ref = GetReferenceForEntry(m_entries[editorIt->second]);
                    if (ref) return ref;
                    SKSE::log::warn("LocationResolver: Alias editor ID target returned null from GetReferenceForEntry");
                }
            } else {
                SKSE::log::info("LocationResolver: No alias for '{}'", lowerDest);
            }

            // 4. Editor ID match
            auto editorIt = m_editorIdLookup.find(lowerDest);
            if (editorIt != m_editorIdLookup.end()) {
                SKSE::log::info("LocationResolver: Editor ID match: '{}'", m_entries[editorIt->second].editorId);
                RE::TESObjectREFR* ref = GetReferenceForEntry(m_entries[editorIt->second]);
                if (ref) return ref;
            }

            // 5. Fuzzy search - prefix then contains
            SKSE::log::info("LocationResolver: Trying fuzzy resolve for '{}'", lowerDest);
            RE::TESObjectREFR* fuzzy = FuzzyResolve(lowerDest);
            if (fuzzy) return fuzzy;

            // 6. Levenshtein distance for typo tolerance (top 5 candidates)
            SKSE::log::info("LocationResolver: Trying Levenshtein resolve for '{}'", lowerDest);
            RE::TESObjectREFR* levenshtein = LevenshteinResolve(lowerDest);
            if (levenshtein) return levenshtein;

            SKSE::log::warn("LocationResolver: FAILED to resolve '{}' — tried semantic, exact, alias, editorID, fuzzy, and Levenshtein", destination);
            return nullptr;
        }

        /**
         * Find nearest furniture/object matching a semantic category
         * Uses the same cell scanning pattern as NearbySearch but for location resolution
         */
        RE::TESObjectREFR* FindNearbySemanticLocation(RE::Actor* actor, const std::string& category)
        {
            auto* cell = actor->GetParentCell();
            if (!cell) return nullptr;

            auto pos = actor->GetPosition();
            float radius = 3000.0f;
            RE::TESObjectREFR* bestMatch = nullptr;
            float bestDistance = radius + 1.0f;

            auto* dh = RE::TESDataHandler::GetSingleton();
            if (!dh) return nullptr;

            // Pre-lookup keywords based on category
            RE::BGSKeyword* targetKeyword = nullptr;
            RE::BGSKeyword* secondaryKeyword = nullptr;
            std::vector<std::string> namePatterns;
            bool matchContainers = false;
            bool matchDoors = false;
            bool matchBeds = false;

            if (category == "bar") {
                targetKeyword = dh->LookupForm<RE::BGSKeyword>(0x000F5078, "Skyrim.esm");
                namePatterns = {"bar", "counter", "mead barrel"};
            } else if (category == "kitchen" || category == "cooking") {
                targetKeyword = dh->LookupForm<RE::BGSKeyword>(0x000A5CB3, "Skyrim.esm");
                secondaryKeyword = dh->LookupForm<RE::BGSKeyword>(0x00068ADA, "Skyrim.esm");
                namePatterns = {"cooking", "cook", "spit", "pot"};
            } else if (category == "forge" || category == "smithy") {
                targetKeyword = dh->LookupForm<RE::BGSKeyword>(0x00088105, "Skyrim.esm");
                namePatterns = {"forge", "anvil", "blacksmith"};
            } else if (category == "shrine" || category == "altar") {
                namePatterns = {"shrine", "altar"};
            } else if (category == "bed") {
                matchBeds = true;
            } else if (category == "fireplace" || category == "hearth" || category == "fire") {
                namePatterns = {"fireplace", "hearth", "campfire"};
            } else if (category == "table") {
                namePatterns = {"table"};
            } else if (category == "enchanter" || category == "enchanting") {
                targetKeyword = dh->LookupForm<RE::BGSKeyword>(0x000BAD0D, "Skyrim.esm");
                namePatterns = {"enchant"};
            } else if (category == "alchemy") {
                targetKeyword = dh->LookupForm<RE::BGSKeyword>(0x0004F6E6, "Skyrim.esm");
                namePatterns = {"alchemy", "alchemist"};
            } else if (category == "chest" || category == "storage") {
                matchContainers = true;
            } else if (category == "door" || category == "entrance") {
                matchDoors = true;
            } else {
                return nullptr;
            }

            cell->ForEachReferenceInRange(pos, radius, [&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                if (&ref == actor || ref.IsDisabled() || !ref.Is3DLoaded())
                    return RE::BSContainer::ForEachResult::kContinue;

                auto* baseObj = ref.GetBaseObject();
                if (!baseObj) return RE::BSContainer::ForEachResult::kContinue;

                bool isMatch = false;

                // Bed matching: check furniture by name/editorID for bed/bedroll types
                if (matchBeds) {
                    auto* furn = baseObj->As<RE::TESFurniture>();
                    if (furn) {
                        const char* name = baseObj->GetName();
                        if (name) {
                            std::string lowerName = StringUtils::ToLower(name);
                            if (lowerName.find("bed") != std::string::npos ||
                                lowerName.find("bedroll") != std::string::npos ||
                                lowerName.find("coffin") != std::string::npos ||
                                lowerName.find("hay") != std::string::npos) {
                                isMatch = true;
                            }
                        }
                        if (!isMatch) {
                            const char* editorId = baseObj->GetFormEditorID();
                            if (editorId) {
                                std::string lowerEd = StringUtils::ToLower(editorId);
                                if (lowerEd.find("bed") != std::string::npos ||
                                    lowerEd.find("bedroll") != std::string::npos ||
                                    lowerEd.find("coffin") != std::string::npos) {
                                    isMatch = true;
                                }
                            }
                        }
                    }
                }

                // Container matching
                if (matchContainers && !isMatch) {
                    if (baseObj->As<RE::TESObjectCONT>()) {
                        isMatch = true;
                    }
                }

                // Door matching
                if (matchDoors && !isMatch) {
                    if (baseObj->GetFormType() == RE::FormType::Door) {
                        isMatch = true;
                    }
                }

                // Keyword matching on furniture and activators
                if (!isMatch && targetKeyword) {
                    auto* furn = baseObj->As<RE::TESFurniture>();
                    if (furn) isMatch = furn->HasKeyword(targetKeyword);
                    if (!isMatch) {
                        auto* acti = baseObj->As<RE::TESObjectACTI>();
                        if (acti) isMatch = acti->HasKeyword(targetKeyword);
                    }
                }

                // Secondary keyword (e.g., cooking spit as fallback for kitchen)
                if (!isMatch && secondaryKeyword) {
                    auto* furn = baseObj->As<RE::TESFurniture>();
                    if (furn) isMatch = furn->HasKeyword(secondaryKeyword);
                    if (!isMatch) {
                        auto* acti = baseObj->As<RE::TESObjectACTI>();
                        if (acti) isMatch = acti->HasKeyword(secondaryKeyword);
                    }
                }

                // Name-based fallback (display name then editor ID)
                if (!isMatch && !namePatterns.empty()) {
                    const char* name = baseObj->GetName();
                    if (name) {
                        std::string lowerName = StringUtils::ToLower(name);
                        for (const auto& pat : namePatterns) {
                            if (lowerName.find(pat) != std::string::npos) {
                                isMatch = true;
                                break;
                            }
                        }
                    }
                    if (!isMatch) {
                        const char* editorId = baseObj->GetFormEditorID();
                        if (editorId) {
                            std::string lowerEd = StringUtils::ToLower(editorId);
                            for (const auto& pat : namePatterns) {
                                if (lowerEd.find(pat) != std::string::npos) {
                                    isMatch = true;
                                    break;
                                }
                            }
                        }
                    }
                }

                if (isMatch) {
                    float dist = pos.GetDistance(ref.GetPosition());
                    if (dist < bestDistance) {
                        bestDistance = dist;
                        bestMatch = &ref;
                    }
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            if (bestMatch) {
                SKSE::log::info("LocationResolver: FindNearbySemanticLocation('{}') found '{}' at distance {:.0f}",
                    category, bestMatch->GetBaseObject() ? bestMatch->GetBaseObject()->GetName() : "unknown",
                    bestDistance);
            }

            return bestMatch;
        }

        /**
         * Resolve semantic directional terms and furniture-based locations
         */
        RE::TESObjectREFR* ResolveSemanticTerm(RE::Actor* actor, const std::string& term)
        {
            if (!actor) return nullptr;

            auto* cell = actor->GetParentCell();
            if (!cell) return nullptr;

            // --- Door-based semantic directions ---

            // "outside" / "go outside" / "leave"
            if (term == "outside" || term == "go outside" || term == "leave" ||
                term == "exit" || term == "go out") {
                return FindExteriorDoor(actor, cell);
            }

            // "inside" / "go inside" / "enter"
            if (term == "inside" || term == "go inside" || term == "enter") {
                return FindNearestInteriorDoor(actor, cell);
            }

            // "upstairs" / "go upstairs" / "go up"
            if (term == "upstairs" || term == "go upstairs" || term == "go up") {
                return FindDoorByZAxis(actor, cell, true);
            }

            // "downstairs" / "go downstairs" / "go down"
            if (term == "downstairs" || term == "go downstairs" || term == "go down") {
                return FindDoorByZAxis(actor, cell, false);
            }

            // --- Furniture-based semantic locations ---
            static const std::unordered_map<std::string, std::string> furnitureTerms = {
                // Bar / Tavern counter
                {"bar", "bar"}, {"the bar", "bar"}, {"bar counter", "bar"},
                // Kitchen / Cooking area
                {"kitchen", "kitchen"}, {"the kitchen", "kitchen"},
                {"cooking", "cooking"}, {"cooking area", "kitchen"},
                // Forge / Smithy
                {"forge", "forge"}, {"the forge", "forge"},
                {"smithy", "forge"}, {"the smithy", "forge"},
                // Shrine / Altar
                {"shrine", "shrine"}, {"the shrine", "shrine"},
                {"altar", "shrine"}, {"the altar", "shrine"}, {"pray", "shrine"},
                // Bed
                {"bed", "bed"}, {"my bed", "bed"}, {"a bed", "bed"},
                // Fireplace / Hearth
                {"fireplace", "fireplace"}, {"the fireplace", "fireplace"},
                {"hearth", "fireplace"}, {"the hearth", "fireplace"},
                {"the fire", "fireplace"}, {"campfire", "fireplace"},
                // Table
                {"table", "table"}, {"the table", "table"}, {"dining table", "table"},
                // Enchanting
                {"enchanter", "enchanter"}, {"enchanting table", "enchanter"},
                {"arcane enchanter", "enchanter"},
                // Alchemy
                {"alchemy lab", "alchemy"}, {"alchemy table", "alchemy"},
                // Storage
                {"chest", "chest"}, {"the chest", "chest"}, {"storage", "chest"},
                // Door / Entrance
                {"door", "door"}, {"the door", "door"},
                {"entrance", "door"}, {"the entrance", "door"},
            };

            auto furnIt = furnitureTerms.find(term);
            if (furnIt != furnitureTerms.end()) {
                SKSE::log::info("LocationResolver: Semantic furniture term '{}' -> category '{}'",
                    term, furnIt->second);
                return FindNearbySemanticLocation(actor, furnIt->second);
            }

            return nullptr;
        }

        /**
         * Get display name for a resolved location
         */
        std::string GetLocationName(const std::string& destination)
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized) return destination;
            std::string lowerDest = StringUtils::ToLower(destination);

            auto exactIt = m_exactLookup.find(lowerDest);
            if (exactIt != m_exactLookup.end()) {
                return m_entries[exactIt->second].displayName;
            }

            auto aliasIt = m_aliasLookup.find(lowerDest);
            if (aliasIt != m_aliasLookup.end()) {
                auto resolvedIt = m_exactLookup.find(aliasIt->second);
                if (resolvedIt != m_exactLookup.end()) {
                    return m_entries[resolvedIt->second].displayName;
                }
            }

            return destination;
        }

        bool IsInitialized() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_initialized; }
        size_t GetEntryCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_entries.size(); }

        /**
         * Get a disambiguated display name for a cell FormID.
         * If the cell has a duplicate name, returns "CellName (ParentLocation)".
         * Otherwise returns just the cell name.
         * Returns empty string if cell not found in index.
         */
        std::string GetDisambiguatedCellName(RE::FormID cellFormId)
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized) return "";

            auto it = m_cellFormToIndex.find(cellFormId);
            if (it == m_cellFormToIndex.end()) return "";

            const auto& entry = m_entries[it->second];

            // Check if this name is duplicated
            auto countIt = m_nameOccurrences.find(entry.name);
            if (countIt != m_nameOccurrences.end() && countIt->second > 1) {
                // Look up parent location for disambiguation
                auto* cell = RE::TESForm::LookupByID<RE::TESObjectCELL>(cellFormId);
                if (cell) {
                    auto* parentLoc = cell->GetLocation();
                    if (parentLoc) {
                        const char* locName = parentLoc->GetName();
                        if (locName && locName[0] != '\0') {
                            return entry.displayName + " (" + std::string(locName) + ")";
                        }
                    }
                }
            }

            return entry.displayName;
        }

        /**
         * Get a disambiguated display name for a cell by name string.
         * If the name has duplicates, tries to resolve using the cell's parent location.
         * Falls back to exact match display name if not duplicated.
         */
        std::string GetDisambiguatedCellNameByName(const std::string& cellName, RE::TESObjectCELL* cell = nullptr)
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized || cellName.empty()) return cellName;
            std::string lowerName = StringUtils::ToLower(cellName);

            auto countIt = m_nameOccurrences.find(lowerName);
            if (countIt == m_nameOccurrences.end() || countIt->second <= 1) {
                // Not duplicated, return as-is
                return cellName;
            }

            // Duplicated name - try to disambiguate
            if (cell) {
                auto* parentLoc = cell->GetLocation();
                if (parentLoc) {
                    const char* locName = parentLoc->GetName();
                    if (locName && locName[0] != '\0') {
                        return cellName + " (" + std::string(locName) + ")";
                    }
                }
            }

            return cellName;
        }

        std::string GetStats() const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized) return "LocationResolver not initialized";
            int cells = 0, locations = 0;
            for (const auto& e : m_entries) {
                if (e.type == LocationEntry::Type::Cell) cells++;
                else if (e.type == LocationEntry::Type::Location) locations++;
            }

            return "Cells: " + std::to_string(cells) +
                   ", Locations: " + std::to_string(locations) +
                   ", Aliases: " + std::to_string(m_aliasLookup.size()) +
                   ", DoorMappings: " + std::to_string(m_doorIndex.size());
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static RE::TESObjectREFR* Papyrus_ResolveDestination(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString destination)
        {
            if (!actor || !destination.data()) return nullptr;
            return GetInstance().ResolveDestination(actor, destination.data());
        }

        static RE::BSFixedString Papyrus_GetLocationName(RE::StaticFunctionTag*, RE::BSFixedString destination)
        {
            if (!destination.data()) return "";
            return GetInstance().GetLocationName(destination.data()).c_str();
        }

        static bool Papyrus_IsLocationResolverReady(RE::StaticFunctionTag*)
        {
            return GetInstance().IsInitialized();
        }

        static int32_t Papyrus_GetLocationCount(RE::StaticFunctionTag*)
        {
            return static_cast<int32_t>(GetInstance().GetEntryCount());
        }

        static RE::BSFixedString Papyrus_GetLocationResolverStats(RE::StaticFunctionTag*)
        {
            return GetInstance().GetStats().c_str();
        }

        static RE::BSFixedString Papyrus_GetDisambiguatedCellName(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            if (!actor) return "";

            // Try runtime parent cell first
            auto* cell = actor->GetParentCell();
            if (cell && cell->IsInteriorCell()) {
                auto result = GetInstance().GetDisambiguatedCellName(cell->GetFormID());
                if (!result.empty()) return result.c_str();
            }

            // Try save parent cell for unloaded actors
            auto* saveCell = actor->GetSaveParentCell();
            if (saveCell && saveCell->IsInteriorCell()) {
                auto result = GetInstance().GetDisambiguatedCellName(saveCell->GetFormID());
                if (!result.empty()) return result.c_str();
            }

            return "";
        }

        static RE::TESObjectREFR* Papyrus_FindDoorToActorCell(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            if (!actor) return nullptr;

            auto& locResolver = GetInstance();
            std::shared_lock<std::shared_mutex> readLock(locResolver.m_mutex);

            RE::TESObjectCELL* cell = nullptr;

            // 1. Try runtime parent cell first
            cell = actor->GetParentCell();
            if (cell && cell->IsInteriorCell()) {
                SKSE::log::info("LocationResolver: FindDoorToActorCell - actor in interior cell '{}' (runtime)",
                    cell->GetFullName() ? cell->GetFullName() : "unknown");
                auto* door = locResolver.FindDoorLeadingToCell(cell);
                if (door) {
                    SKSE::log::info("LocationResolver: FindDoorToActorCell - found door {:08X}", door->GetFormID());
                    return door;
                }
            }

            // 2. Try save parent cell (persists for unloaded actors)
            auto* saveCell = actor->GetSaveParentCell();
            if (saveCell && saveCell != cell && saveCell->IsInteriorCell()) {
                SKSE::log::info("LocationResolver: FindDoorToActorCell - trying save parent cell '{}' for unloaded actor",
                    saveCell->GetFullName() ? saveCell->GetFullName() : "unknown");
                auto* door = locResolver.FindDoorLeadingToCell(saveCell);
                if (door) {
                    SKSE::log::info("LocationResolver: FindDoorToActorCell - found door {:08X} via save cell", door->GetFormID());
                    return door;
                }
            }

            // 3. Try editor location cell (where NPC was placed in CK)
            {
                RE::NiPoint3 outPos, outRot;
                RE::TESForm* outWorldOrCell = nullptr;
                if (actor->GetEditorLocation2(outPos, outRot, outWorldOrCell, nullptr) && outWorldOrCell) {
                    auto* editorCell = outWorldOrCell->As<RE::TESObjectCELL>();
                    if (editorCell && editorCell != cell && editorCell != saveCell && editorCell->IsInteriorCell()) {
                        SKSE::log::info("LocationResolver: FindDoorToActorCell - trying editor cell '{}' for unloaded actor",
                            editorCell->GetFullName() ? editorCell->GetFullName() : "unknown");
                        auto* door = locResolver.FindDoorLeadingToCell(editorCell);
                        if (door) {
                            SKSE::log::info("LocationResolver: FindDoorToActorCell - found door {:08X} via editor cell", door->GetFormID());
                            return door;
                        }
                    }
                }
            }

            // 4. Try the ActorFinder's pre-built NPC-to-cell index
            // This was built at kDataLoaded by scanning which NPCs are placed in which interior cells
            {
                auto* npcBase = actor->GetActorBase();
                if (npcBase) {
                    auto& actorFinder = ActorFinder::GetInstance();
                    RE::FormID npcBaseId = npcBase->GetFormID();

                    // 4a. Try cell FormID index (guaranteed TESObjectCELL)
                    RE::FormID indexedCellId = actorFinder.GetIndexedCellFormID(npcBaseId);
                    if (indexedCellId != 0) {
                        auto* indexedCell = RE::TESForm::LookupByID<RE::TESObjectCELL>(indexedCellId);
                        if (indexedCell && indexedCell->IsInteriorCell()) {
                            SKSE::log::info("LocationResolver: FindDoorToActorCell - trying NPC-indexed cell '{}' for unloaded actor",
                                indexedCell->GetFullName() ? indexedCell->GetFullName() : "unknown");
                            auto* door = locResolver.FindDoorLeadingToCell(indexedCell);
                            if (door) {
                                SKSE::log::info("LocationResolver: FindDoorToActorCell - found door {:08X} via NPC cell index", door->GetFormID());
                                return door;
                            }
                        }
                    }

                    // 4b. Try location FormID index and find a cell within that location
                    RE::FormID indexedLocId = actorFinder.GetIndexedLocationFormID(npcBaseId);
                    if (indexedLocId != 0) {
                        auto* indexedLoc = RE::TESForm::LookupByID<RE::BGSLocation>(indexedLocId);
                        if (indexedLoc) {
                            SKSE::log::info("LocationResolver: FindDoorToActorCell - trying NPC-indexed location '{}' for unloaded actor",
                                indexedLoc->GetName() ? indexedLoc->GetName() : "unknown");
                            // Search for a named cell that matches this location via our location index
                            std::string locName = StringUtils::ToLower(indexedLoc->GetName() ? indexedLoc->GetName() : "");
                            if (!locName.empty()) {
                                auto exactIt = locResolver.m_exactLookup.find(locName);
                                if (exactIt != locResolver.m_exactLookup.end()) {
                                    auto& entry = locResolver.m_entries[exactIt->second];
                                    if (entry.type == LocationEntry::Type::Cell && entry.isInterior) {
                                        auto* locCell = RE::TESForm::LookupByID<RE::TESObjectCELL>(entry.formId);
                                        if (locCell && locCell->IsInteriorCell()) {
                                            auto* door = locResolver.FindDoorLeadingToCell(locCell);
                                            if (door) {
                                                SKSE::log::info("LocationResolver: FindDoorToActorCell - found door {:08X} via location->cell lookup", door->GetFormID());
                                                return door;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // If we got here with a valid cell that's exterior, log it
            if (cell && !cell->IsInteriorCell()) {
                SKSE::log::info("LocationResolver: FindDoorToActorCell - actor is in exterior cell, no door needed");
            } else if (!cell) {
                SKSE::log::warn("LocationResolver: FindDoorToActorCell - actor has no parent cell and no fallback found");
            } else {
                SKSE::log::warn("LocationResolver: FindDoorToActorCell - no door found for any cell");
            }

            return nullptr;
        }

        /**
         * Find the exterior door leading to an NPC's home cell.
         * Chains ActorFinder::GetActorHomeCell (sleep package index) with FindDoorLeadingToCell.
         * Works for unloaded NPCs — data comes from AI packages scanned at kDataLoaded.
         * Returns nullptr if no home cell is known or no door exists.
         */
        static RE::TESObjectREFR* Papyrus_FindDoorToActorHome(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            if (!actor) return nullptr;

            // Get the home cell from ActorFinder's sleep package index
            auto* homeCell = ActorFinder::GetActorHomeCell(actor);
            if (!homeCell) {
                auto* npc = actor->GetActorBase();
                SKSE::log::info("LocationResolver: FindDoorToActorHome - no home cell for '{}' ({:08X})",
                    npc ? (npc->GetName() ? npc->GetName() : "null") : "null",
                    npc ? npc->GetFormID() : 0);
                return nullptr;
            }

            if (!homeCell->IsInteriorCell()) {
                SKSE::log::info("LocationResolver: FindDoorToActorHome - home cell '{}' is exterior, no door needed",
                    homeCell->GetFullName() ? homeCell->GetFullName() : "unknown");
                return nullptr;
            }

            auto& locResolver = GetInstance();
            std::shared_lock<std::shared_mutex> readLock(locResolver.m_mutex);

            auto* door = locResolver.FindDoorLeadingToCell(homeCell);
            if (door) {
                SKSE::log::info("LocationResolver: FindDoorToActorHome - found door {:08X} to home cell '{}'",
                    door->GetFormID(), homeCell->GetFullName() ? homeCell->GetFullName() : "unknown");
            } else {
                SKSE::log::info("LocationResolver: FindDoorToActorHome - no door found for home cell '{}'",
                    homeCell->GetFullName() ? homeCell->GetFullName() : "unknown");
            }

            return door;
        }

        /**
         * Find the interior door in an actor's current cell that leads to an exterior.
         * Used when a guard is inside an interior (e.g. Bannered Mare) and needs to exit.
         * Scans the actor's parent cell for doors with ExtraTeleport linking to exterior cells.
         * Returns the interior door reference (inside the cell), or nullptr if not found.
         */
        static RE::TESObjectREFR* Papyrus_FindExitDoorFromCell(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            if (!actor) return nullptr;

            auto* cell = actor->GetParentCell();
            if (!cell) {
                SKSE::log::info("LocationResolver: FindExitDoorFromCell - actor has no parent cell");
                return nullptr;
            }

            if (!cell->IsInteriorCell()) {
                SKSE::log::info("LocationResolver: FindExitDoorFromCell - actor is in exterior cell, no exit door needed");
                return nullptr;
            }

            SKSE::log::info("LocationResolver: FindExitDoorFromCell - scanning interior cell '{}' for exit doors",
                cell->GetFullName() ? cell->GetFullName() : "unknown");

            RE::TESObjectREFR* exitDoor = nullptr;
            cell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                auto* extraTeleport = ref.extraList.GetByType<RE::ExtraTeleport>();
                if (!extraTeleport || !extraTeleport->teleportData) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto destDoorPtr = extraTeleport->teleportData->linkedDoor.get();
                if (!destDoorPtr) return RE::BSContainer::ForEachResult::kContinue;

                // Check if this door links to an exterior cell
                auto* destCell = destDoorPtr->GetParentCell();
                if (destCell && !destCell->IsInteriorCell()) {
                    exitDoor = &ref;
                    SKSE::log::info("LocationResolver: FindExitDoorFromCell - found exit door {:08X} linking to exterior",
                        ref.GetFormID());
                    return RE::BSContainer::ForEachResult::kStop;
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            if (!exitDoor) {
                SKSE::log::info("LocationResolver: FindExitDoorFromCell - no exit door found in cell '{}'",
                    cell->GetFullName() ? cell->GetFullName() : "unknown");
            }

            return exitDoor;
        }

        /**
         * Find an XMarkerHeading or XMarker inside an interior cell.
         * Prefers XMarkerHeading (0x34) since it has orientation data for NPC facing.
         * Falls back to XMarker (0x3B). Returns nullptr for exterior cells or if none found.
         * Works on unloaded cells — ForEachReference iterates stored ref data.
         */
        RE::TESObjectREFR* FindInteriorMarkerForCell(RE::TESObjectCELL* cell)
        {
            if (!cell || !cell->IsInteriorCell()) return nullptr;

            RE::TESObjectREFR* xmarkerHeading = nullptr;
            RE::TESObjectREFR* xmarker = nullptr;

            cell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                if (ref.IsDisabled()) return RE::BSContainer::ForEachResult::kContinue;

                auto* baseObj = ref.GetBaseObject();
                if (!baseObj) return RE::BSContainer::ForEachResult::kContinue;

                RE::FormID baseId = baseObj->GetFormID();

                // XMarkerHeading = 0x34 in Skyrim.esm (preferred — has facing direction)
                if (baseId == kXMarkerHeading && !xmarkerHeading) {
                    xmarkerHeading = &ref;
                    // Keep searching in case there's a better one, but heading is preferred
                    if (xmarker) return RE::BSContainer::ForEachResult::kStop;  // Have both, done
                }
                // XMarker = 0x3B in Skyrim.esm
                else if (baseId == kXMarker && !xmarker) {
                    xmarker = &ref;
                    if (xmarkerHeading) return RE::BSContainer::ForEachResult::kStop;  // Have both, done
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            auto* result = xmarkerHeading ? xmarkerHeading : xmarker;
            if (result) {
                SKSE::log::info("LocationResolver: FindInteriorMarkerForCell '{}' -> {} {:08X}",
                    cell->GetFullName() ? cell->GetFullName() : "unknown",
                    xmarkerHeading ? "XMarkerHeading" : "XMarker",
                    result->GetFormID());
            } else {
                SKSE::log::info("LocationResolver: FindInteriorMarkerForCell '{}' -> no markers found",
                    cell->GetFullName() ? cell->GetFullName() : "unknown");
            }
            return result;
        }

        /**
         * Find an interior marker (XMarkerHeading/XMarker) inside an NPC's home cell.
         * Chains ActorFinder::GetActorHomeCell with FindInteriorMarkerForCell.
         * Returns a reference INSIDE the home, suitable for MoveTo.
         * Returns nullptr if no home cell or no markers exist.
         */
        static RE::TESObjectREFR* Papyrus_FindHomeInteriorMarker(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            if (!actor) return nullptr;

            auto* homeCell = ActorFinder::GetActorHomeCell(actor);
            if (!homeCell) {
                auto* npc = actor->GetActorBase();
                SKSE::log::info("LocationResolver: FindHomeInteriorMarker - no home cell for '{}' ({:08X})",
                    npc ? (npc->GetName() ? npc->GetName() : "null") : "null",
                    npc ? npc->GetFormID() : 0);
                return nullptr;
            }

            if (!homeCell->IsInteriorCell()) {
                SKSE::log::info("LocationResolver: FindHomeInteriorMarker - home cell '{}' is exterior",
                    homeCell->GetFullName() ? homeCell->GetFullName() : "unknown");
                return nullptr;
            }

            auto& locResolver = GetInstance();
            std::shared_lock<std::shared_mutex> readLock(locResolver.m_mutex);

            return locResolver.FindInteriorMarkerForCell(homeCell);
        }

        /**
         * Find an interior marker (XMarkerHeading/XMarker) inside the cell a door leads to.
         * Follows the door's teleport link to find the destination interior cell,
         * then scans for markers inside it.
         * Returns nullptr if ref is not a door, has no teleport data, or leads to exterior.
         */
        static RE::TESObjectREFR* Papyrus_FindInteriorMarkerForDoor(RE::StaticFunctionTag*, RE::TESObjectREFR* doorRef)
        {
            if (!doorRef) return nullptr;

            // Follow the door's teleport link to find the destination cell
            auto* extraTeleport = doorRef->extraList.GetByType<RE::ExtraTeleport>();
            if (!extraTeleport || !extraTeleport->teleportData) {
                SKSE::log::info("LocationResolver: FindInteriorMarkerForDoor - ref {:08X} has no teleport data",
                    doorRef->GetFormID());
                return nullptr;
            }

            auto destDoorPtr = extraTeleport->teleportData->linkedDoor.get();
            if (!destDoorPtr) {
                SKSE::log::info("LocationResolver: FindInteriorMarkerForDoor - ref {:08X} teleport has no linked door",
                    doorRef->GetFormID());
                return nullptr;
            }

            auto* destCell = destDoorPtr->GetParentCell();
            if (!destCell || !destCell->IsInteriorCell()) {
                SKSE::log::info("LocationResolver: FindInteriorMarkerForDoor - ref {:08X} leads to exterior or null cell",
                    doorRef->GetFormID());
                return nullptr;
            }

            SKSE::log::info("LocationResolver: FindInteriorMarkerForDoor - door {:08X} leads to interior cell '{}'",
                doorRef->GetFormID(), destCell->GetFullName() ? destCell->GetFullName() : "unknown");

            auto& locResolver = GetInstance();
            std::shared_lock<std::shared_mutex> readLock(locResolver.m_mutex);

            return locResolver.FindInteriorMarkerForCell(destCell);
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("ResolveDestination", scriptName, Papyrus_ResolveDestination);
            a_vm->RegisterFunction("GetLocationName", scriptName, Papyrus_GetLocationName);
            a_vm->RegisterFunction("IsLocationResolverReady", scriptName, Papyrus_IsLocationResolverReady);
            a_vm->RegisterFunction("GetLocationCount", scriptName, Papyrus_GetLocationCount);
            a_vm->RegisterFunction("GetLocationResolverStats", scriptName, Papyrus_GetLocationResolverStats);
            a_vm->RegisterFunction("FindDoorToActorCell", scriptName, Papyrus_FindDoorToActorCell);
            a_vm->RegisterFunction("FindDoorToActorHome", scriptName, Papyrus_FindDoorToActorHome);
            a_vm->RegisterFunction("FindExitDoorFromCell", scriptName, Papyrus_FindExitDoorFromCell);
            a_vm->RegisterFunction("FindHomeInteriorMarker", scriptName, Papyrus_FindHomeInteriorMarker);
            a_vm->RegisterFunction("FindInteriorMarkerForDoor", scriptName, Papyrus_FindInteriorMarkerForDoor);
            a_vm->RegisterFunction("GetDisambiguatedCellName", scriptName, Papyrus_GetDisambiguatedCellName);

            SKSE::log::info("Registered location resolver functions");
        }

    private:
        LocationResolver() = default;
        LocationResolver(const LocationResolver&) = delete;
        LocationResolver& operator=(const LocationResolver&) = delete;

        /**
         * Get a usable ObjectReference for a location entry
         * For cells: find the first XMarker or door leading to that cell
         * For locations: find a reference in that location
         */
        RE::TESObjectREFR* GetReferenceForEntry(const LocationEntry& entry)
        {
            SKSE::log::info("LocationResolver: GetReferenceForEntry('{}', formId={:08X}, type={}, interior={})",
                entry.displayName, entry.formId, (int)entry.type, entry.isInterior);

            auto* form = RE::TESForm::LookupByID(entry.formId);
            if (!form) {
                SKSE::log::warn("LocationResolver: LookupByID({:08X}) returned null!", entry.formId);
                return nullptr;
            }

            // If it's a cell, find a door leading TO this cell from the exterior
            // Interior cells are usually not loaded, so ForEachReference won't work
            // Instead, find the exterior door that teleports into this cell
            if (entry.type == LocationEntry::Type::Cell) {
                auto* cell = form->As<RE::TESObjectCELL>();
                if (!cell) {
                    SKSE::log::warn("LocationResolver: Form {:08X} is not a TESObjectCELL!", entry.formId);
                    return nullptr;
                }

                SKSE::log::info("LocationResolver: Cell '{}' isInterior={}",
                    cell->GetName() ? cell->GetName() : "null", cell->IsInteriorCell());

                // For interior cells, find the exterior door that leads into them
                if (cell->IsInteriorCell()) {
                    RE::TESObjectREFR* entranceDoor = FindDoorLeadingToCell(cell);
                    if (entranceDoor) {
                        SKSE::log::info("LocationResolver: Found entrance door for '{}' -> refId={:08X}",
                            entry.displayName, entranceDoor->GetFormID());
                        return entranceDoor;
                    }
                    SKSE::log::warn("LocationResolver: FindDoorLeadingToCell returned null for '{}'", entry.displayName);
                }

                // Fallback for exterior cells or if no door found:
                // Try to find XMarker or any reference inside the cell
                RE::TESObjectREFR* xmarker = nullptr;
                RE::TESObjectREFR* anyRef = nullptr;

                cell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                    auto* baseObj = ref.GetBaseObject();
                    if (baseObj) {
                        // XMarker base form ID is 0x3B in Skyrim.esm
                        if (baseObj->GetFormID() == kXMarker && !xmarker) {
                            xmarker = &ref;
                            return RE::BSContainer::ForEachResult::kStop;
                        }
                    }
                    if (!anyRef && !ref.IsDisabled()) {
                        anyRef = &ref;
                    }
                    return RE::BSContainer::ForEachResult::kContinue;
                });

                return xmarker ? xmarker : anyRef;
            }

            // If it's a BGSLocation, find a MapMarker or door in that location
            if (entry.type == LocationEntry::Type::Location) {
                auto* location = form->As<RE::BGSLocation>();
                if (!location) return nullptr;

                // Search ALL worldspace persistent cells for references matching this location
                // This handles Tamriel, Solstheim, and any modded worldspaces
                auto* dataHandler = RE::TESDataHandler::GetSingleton();
                if (!dataHandler) return nullptr;

                for (auto* worldSpace : dataHandler->GetFormArray<RE::TESWorldSpace>()) {
                    if (!worldSpace) continue;

                    auto* persistCell = worldSpace->persistentCell;
                    if (!persistCell) continue;

                    RE::TESObjectREFR* mapMarker = nullptr;
                    persistCell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                        if (ref.IsInitiallyDisabled()) {
                            return RE::BSContainer::ForEachResult::kContinue;
                        }

                        // Check if this ref's location matches
                        auto* refLoc = ref.GetCurrentLocation();
                        if (refLoc && refLoc->GetFormID() == location->GetFormID()) {
                            mapMarker = &ref;
                            return RE::BSContainer::ForEachResult::kStop;
                        }

                        return RE::BSContainer::ForEachResult::kContinue;
                    });

                    if (mapMarker) return mapMarker;
                }
            }

            return nullptr;
        }

        /**
         * Find an exterior door that teleports into the target interior cell.
         *
         * Strategy: Interior cells always have doors with ExtraTeleport pointing
         * to the paired exterior door. We iterate the interior cell's own references
         * to find these doors, then return the LINKED (exterior) door as the
         * travel destination. This works even when the cell isn't loaded because
         * the cell's reference data is still accessible in memory.
         *
         * Fallback: If that fails, search the Tamriel worldspace persistent cell
         * for doors whose destination matches our target cell.
         */
        RE::TESObjectREFR* FindDoorLeadingToCell(RE::TESObjectCELL* targetCell)
        {
            if (!targetCell) return nullptr;

            auto targetFormId = targetCell->GetFormID();

            // Strategy 0: Pre-built door index (O(1) lookup, built during Initialize)
            // Note: Caller must hold shared_lock on m_mutex, or data must be immutable
            {
                auto indexIt = m_doorIndex.find(targetFormId);
                if (indexIt != m_doorIndex.end()) {
                    auto* doorRef = RE::TESForm::LookupByID<RE::TESObjectREFR>(indexIt->second);
                    if (doorRef) {
                        SKSE::log::info("LocationResolver: Found door via pre-built index for '{}' -> door {:08X}",
                            targetCell->GetFullName() ? targetCell->GetFullName() : "unknown", doorRef->GetFormID());
                        return doorRef;
                    } else {
                        SKSE::log::warn("LocationResolver: Door index had entry for '{}' but LookupByID({:08X}) returned null",
                            targetCell->GetFullName() ? targetCell->GetFullName() : "unknown", indexIt->second);
                    }
                } else {
                    SKSE::log::info("LocationResolver: No pre-built index entry for cell {:08X} '{}'",
                        targetFormId, targetCell->GetFullName() ? targetCell->GetFullName() : "unknown");
                }
            }

            // Strategy 1: Search INSIDE the target cell for doors that lead OUT
            // Then return the linked exterior door (the one NPCs can walk to)
            {
                RE::TESObjectREFR* exteriorDoor = nullptr;
                targetCell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                    auto* extraTeleport = ref.extraList.GetByType<RE::ExtraTeleport>();
                    if (!extraTeleport || !extraTeleport->teleportData) {
                        return RE::BSContainer::ForEachResult::kContinue;
                    }

                    // This door inside the target cell links to an exterior door
                    auto destDoorPtr = extraTeleport->teleportData->linkedDoor.get();
                    if (!destDoorPtr) return RE::BSContainer::ForEachResult::kContinue;

                    // Check if the linked door is in an exterior cell
                    auto* destCell = destDoorPtr->GetParentCell();
                    if (destCell && !destCell->IsInteriorCell()) {
                        // Found it — the exterior door that leads into our target
                        exteriorDoor = destDoorPtr.get();
                        return RE::BSContainer::ForEachResult::kStop;
                    }

                    return RE::BSContainer::ForEachResult::kContinue;
                });

                if (exteriorDoor) {
                    SKSE::log::info("LocationResolver: Found exterior door via interior scan for '{}'",
                        targetCell->GetName() ? targetCell->GetName() : "unknown");
                    return exteriorDoor;
                }
            }

            // Strategy 2: Search ALL worldspace persistent cells for doors
            // whose teleport destination matches our target cell
            // This handles Tamriel, Solstheim, and any modded worldspaces
            {
                auto* dataHandler = RE::TESDataHandler::GetSingleton();
                if (!dataHandler) return nullptr;

                for (auto* worldSpace : dataHandler->GetFormArray<RE::TESWorldSpace>()) {
                    if (!worldSpace) continue;

                    auto* persistCell = worldSpace->persistentCell;
                    if (!persistCell) continue;

                    RE::TESObjectREFR* bestDoor = nullptr;

                    persistCell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                        auto* extraTeleport = ref.extraList.GetByType<RE::ExtraTeleport>();
                        if (!extraTeleport || !extraTeleport->teleportData) {
                            return RE::BSContainer::ForEachResult::kContinue;
                        }

                        auto destDoorPtr = extraTeleport->teleportData->linkedDoor.get();
                        if (!destDoorPtr) return RE::BSContainer::ForEachResult::kContinue;

                        auto* destCell = destDoorPtr->GetParentCell();
                        if (!destCell) return RE::BSContainer::ForEachResult::kContinue;

                        if (destCell->GetFormID() == targetFormId) {
                            bestDoor = &ref;
                            return RE::BSContainer::ForEachResult::kStop;
                        }

                        return RE::BSContainer::ForEachResult::kContinue;
                    });

                    if (bestDoor) {
                        SKSE::log::info("LocationResolver: Found door via worldspace '{}' persistent cell for '{}'",
                            worldSpace->GetName() ? worldSpace->GetName() : "unknown",
                            targetCell->GetName() ? targetCell->GetName() : "unknown");
                        return bestDoor;
                    }
                }
            }

            SKSE::log::warn("LocationResolver: Could not find entrance door for '{}'",
                targetCell->GetName() ? targetCell->GetName() : "unknown");
            return nullptr;
        }

        /**
         * Find exterior door in current cell
         */
        RE::TESObjectREFR* FindExteriorDoor(RE::Actor* actor, RE::TESObjectCELL* cell)
        {
            if (!cell || !cell->IsInteriorCell()) return nullptr;

            RE::TESObjectREFR* bestDoor = nullptr;
            float bestDist = 999999.0f;
            auto actorPos = actor->GetPosition();

            cell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                // Check if this is a teleport door
                auto* extraTeleport = ref.extraList.GetByType<RE::ExtraTeleport>();
                if (!extraTeleport || !extraTeleport->teleportData) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                // Check if destination is exterior
                auto destDoorPtr = extraTeleport->teleportData->linkedDoor.get();
                if (!destDoorPtr) return RE::BSContainer::ForEachResult::kContinue;

                auto* destCell = destDoorPtr->GetParentCell();
                if (!destCell) return RE::BSContainer::ForEachResult::kContinue;

                // We want doors leading to exterior cells
                if (!destCell->IsInteriorCell()) {
                    float dist = actorPos.GetDistance(ref.GetPosition());
                    if (dist < bestDist) {
                        bestDist = dist;
                        bestDoor = &ref;
                    }
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            return bestDoor;
        }

        /**
         * Find nearest interior door from exterior
         */
        RE::TESObjectREFR* FindNearestInteriorDoor(RE::Actor* actor, RE::TESObjectCELL* cell)
        {
            RE::TESObjectREFR* bestDoor = nullptr;
            float bestDist = kLocationSearchRadius;
            auto actorPos = actor->GetPosition();

            cell->ForEachReferenceInRange(actorPos, kLocationSearchRadius, [&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                auto* extraTeleport = ref.extraList.GetByType<RE::ExtraTeleport>();
                if (!extraTeleport || !extraTeleport->teleportData) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto destDoorPtr = extraTeleport->teleportData->linkedDoor.get();
                if (!destDoorPtr) return RE::BSContainer::ForEachResult::kContinue;

                auto* destCell = destDoorPtr->GetParentCell();
                if (!destCell) return RE::BSContainer::ForEachResult::kContinue;

                // We want doors leading to interior cells
                if (destCell->IsInteriorCell()) {
                    float dist = actorPos.GetDistance(ref.GetPosition());
                    if (dist < bestDist) {
                        bestDist = dist;
                        bestDoor = &ref;
                    }
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            return bestDoor;
        }

        /**
         * Find door leading up or down based on Z-axis comparison
         */
        RE::TESObjectREFR* FindDoorByZAxis(RE::Actor* actor, RE::TESObjectCELL* cell, bool goUp)
        {
            RE::TESObjectREFR* bestDoor = nullptr;
            float bestDist = kLocationSearchRadius;
            auto actorPos = actor->GetPosition();
            float actorZ = actorPos.z;

            cell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                auto* extraTeleport = ref.extraList.GetByType<RE::ExtraTeleport>();
                if (!extraTeleport || !extraTeleport->teleportData) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto destDoorPtr = extraTeleport->teleportData->linkedDoor.get();
                if (!destDoorPtr) return RE::BSContainer::ForEachResult::kContinue;

                // Compare Z positions of destination vs current
                float destZ = destDoorPtr->GetPosition().z;

                bool matches = goUp ? (destZ > actorZ + kZAxisThreshold) : (destZ < actorZ - kZAxisThreshold);

                if (matches) {
                    float dist = actorPos.GetDistance(ref.GetPosition());
                    if (dist < bestDist) {
                        bestDist = dist;
                        bestDoor = &ref;
                    }
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            return bestDoor;
        }

        /**
         * Fuzzy resolve using prefix index then contains search
         */
        RE::TESObjectREFR* FuzzyResolve(const std::string& lowerDest)
        {
            // Try prefix match first (first 3 chars)
            if (lowerDest.length() >= 3) {
                std::string prefix = lowerDest.substr(0, 3);
                auto prefixIt = m_prefixIndex.find(prefix);
                if (prefixIt != m_prefixIndex.end()) {
                    for (size_t idx : prefixIt->second) {
                        const auto& entry = m_entries[idx];
                        if (entry.name.find(lowerDest) != std::string::npos ||
                            StringUtils::ToLower(entry.editorId).find(lowerDest) != std::string::npos) {
                            RE::TESObjectREFR* ref = GetReferenceForEntry(entry);
                            if (ref) return ref;
                        }
                    }
                }
            }

            // Full contains scan
            for (const auto& entry : m_entries) {
                if (entry.name.find(lowerDest) != std::string::npos) {
                    RE::TESObjectREFR* ref = GetReferenceForEntry(entry);
                    if (ref) return ref;
                }
            }

            return nullptr;
        }

        /**
         * Levenshtein distance resolve for typo tolerance
         */
        RE::TESObjectREFR* LevenshteinResolve(const std::string& lowerDest)
        {
            int bestDistance = 999;
            size_t bestIdx = 0;
            bool found = false;

            // Only check entries with similar length (±3 chars)
            for (size_t i = 0; i < m_entries.size(); i++) {
                const auto& entry = m_entries[i];
                int lenDiff = static_cast<int>(entry.name.length()) - static_cast<int>(lowerDest.length());
                if (lenDiff < -kLevenshteinLengthTolerance || lenDiff > kLevenshteinLengthTolerance) continue;

                int dist = StringUtils::LevenshteinDistance(lowerDest, entry.name);
                if (dist <= kLevenshteinMaxDistance && dist < bestDistance) {
                    bestDistance = dist;
                    bestIdx = i;
                    found = true;
                }
            }

            if (found) {
                SKSE::log::info("LocationResolver: Fuzzy matched '{}' -> '{}' (distance={})",
                    lowerDest, m_entries[bestIdx].displayName, bestDistance);
                return GetReferenceForEntry(m_entries[bestIdx]);
            }

            return nullptr;
        }


        /**
         * Build a pre-computed index mapping interior cell FormIDs to exterior door FormIDs.
         *
         * Scans ALL worldspace cells (not just the persistent cell) for doors with ExtraTeleport
         * that lead into interior cells. This is necessary because building entrance doors
         * (like the Bannered Mare door) are in regular exterior grid cells, not the persistent cell.
         *
         * The index allows O(1) lookup in FindDoorLeadingToCell instead of scanning at runtime.
         */
        void BuildDoorIndex(RE::TESDataHandler* dataHandler)
        {
            if (!dataHandler) return;

            SKSE::log::info("LocationResolver: Building door-to-cell index...");

            int doorsScanned = 0;
            int mappingsFound = 0;

            // Iterate all worldspaces
            for (auto* worldSpace : dataHandler->GetFormArray<RE::TESWorldSpace>()) {
                if (!worldSpace) continue;

                // 1. Scan the persistent cell (always loaded, contains some doors)
                auto* persistCell = worldSpace->persistentCell;
                if (persistCell) {
                    persistCell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                        IndexDoorReference(ref, doorsScanned, mappingsFound);
                        return RE::BSContainer::ForEachResult::kContinue;
                    });
                }

                // 2. Scan all loaded exterior grid cells in this worldspace
                // cellMap contains all the exterior cells that have been processed by the engine
                // At kDataLoaded time, this should have the cell data available
                auto& cellMap = worldSpace->cellMap;
                for (auto& cellPair : cellMap) {
                    auto* cell = cellPair.second;
                    if (!cell || cell->IsInteriorCell()) continue;

                    cell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                        IndexDoorReference(ref, doorsScanned, mappingsFound);
                        return RE::BSContainer::ForEachResult::kContinue;
                    });
                }
            }

            // 3. Also scan interior cells themselves for doors that lead OUT
            // Then record the reverse mapping: the linked exterior door -> this interior cell
            auto& interiorCells = dataHandler->interiorCells;
            for (std::uint16_t ci = 0; ci < interiorCells.size(); ++ci) {
                auto* cell = interiorCells[ci];
                if (!cell) continue;

                auto cellFormId = cell->GetFormID();

                cell->ForEachReference([&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                    auto* extraTeleport = ref.extraList.GetByType<RE::ExtraTeleport>();
                    if (!extraTeleport || !extraTeleport->teleportData) {
                        return RE::BSContainer::ForEachResult::kContinue;
                    }

                    doorsScanned++;

                    auto destDoorHandle = extraTeleport->teleportData->linkedDoor;
                    auto destDoorPtr = destDoorHandle.get();
                    if (!destDoorPtr) return RE::BSContainer::ForEachResult::kContinue;

                    auto* destCell = destDoorPtr->GetParentCell();
                    if (!destCell) return RE::BSContainer::ForEachResult::kContinue;

                    // If this interior door leads to an exterior cell, record the mapping:
                    // this interior cell -> that exterior door
                    if (!destCell->IsInteriorCell()) {
                        if (m_doorIndex.find(cellFormId) == m_doorIndex.end()) {
                            m_doorIndex[cellFormId] = destDoorPtr->GetFormID();
                            mappingsFound++;
                        }
                    }

                    return RE::BSContainer::ForEachResult::kContinue;
                });
            }

            SKSE::log::info("LocationResolver: Door index built - scanned {} doors, found {} interior->exterior mappings",
                doorsScanned, mappingsFound);
        }

        /**
         * Helper: check if a reference is a teleport door leading to an interior cell,
         * and if so, add it to the door index (exterior door -> interior cell mapping)
         */
        void IndexDoorReference(RE::TESObjectREFR& ref, int& doorsScanned, int& mappingsFound)
        {
            auto* extraTeleport = ref.extraList.GetByType<RE::ExtraTeleport>();
            if (!extraTeleport || !extraTeleport->teleportData) return;

            doorsScanned++;

            auto destDoorHandle = extraTeleport->teleportData->linkedDoor;
            auto destDoorPtr = destDoorHandle.get();
            if (!destDoorPtr) return;

            auto* destCell = destDoorPtr->GetParentCell();
            if (!destCell) return;

            // We want exterior doors that lead INTO interior cells
            if (destCell->IsInteriorCell()) {
                auto interiorCellId = destCell->GetFormID();
                if (m_doorIndex.find(interiorCellId) == m_doorIndex.end()) {
                    m_doorIndex[interiorCellId] = ref.GetFormID();
                    mappingsFound++;
                }
            }
        }

        void BuildAliases()
        {
            // Major cities -> their central location name (lowercase)
            // These map to the cell/location name, not editor ID
            m_aliasLookup["whiterun"] = "whiterun";
            m_aliasLookup["solitude"] = "solitude";
            m_aliasLookup["windhelm"] = "windhelm";
            m_aliasLookup["riften"] = "riften";
            m_aliasLookup["markarth"] = "markarth";
            m_aliasLookup["falkreath"] = "falkreath";
            m_aliasLookup["morthal"] = "morthal";
            m_aliasLookup["dawnstar"] = "dawnstar";
            m_aliasLookup["winterhold"] = "winterhold";

            // Towns
            m_aliasLookup["riverwood"] = "riverwood";
            m_aliasLookup["ivarstead"] = "ivarstead";
            m_aliasLookup["rorikstead"] = "rorikstead";
            m_aliasLookup["dragon bridge"] = "dragon bridge";
            m_aliasLookup["kynesgrove"] = "kynesgrove";

            // Common shorthand
            m_aliasLookup["bannered mare"] = "the bannered mare";
            m_aliasLookup["the mare"] = "the bannered mare";
            m_aliasLookup["winking skeever"] = "the winking skeever";
            m_aliasLookup["bee and barb"] = "the bee and barb";
            m_aliasLookup["candlehearth hall"] = "candlehearth hall";
            m_aliasLookup["silver-blood inn"] = "silver-blood inn";
            m_aliasLookup["sleeping giant"] = "sleeping giant inn";
            m_aliasLookup["sleeping giant inn"] = "sleeping giant inn";
            m_aliasLookup["dragonsreach"] = "dragonsreach";
            m_aliasLookup["palace of the kings"] = "palace of the kings";
            m_aliasLookup["blue palace"] = "blue palace";
            m_aliasLookup["understone keep"] = "understone keep";
            m_aliasLookup["mistveil keep"] = "mistveil keep";

            // Shops and stores (common names without "the" or with apostrophes)
            m_aliasLookup["warmaidens"] = "warmaiden's";
            m_aliasLookup["warmaiden's"] = "warmaiden's";
            m_aliasLookup["warmaidens shop"] = "warmaiden's";
            m_aliasLookup["belethor"] = "belethor's general goods";
            m_aliasLookup["belethors"] = "belethor's general goods";
            m_aliasLookup["belethor's"] = "belethor's general goods";
            m_aliasLookup["arcadia"] = "arcadia's cauldron";
            m_aliasLookup["arcadias"] = "arcadia's cauldron";
            m_aliasLookup["arcadia's"] = "arcadia's cauldron";
            m_aliasLookup["the drunken huntsman"] = "the drunken huntsman";
            m_aliasLookup["drunken huntsman"] = "the drunken huntsman";
            m_aliasLookup["breezehome"] = "breezehome";
            m_aliasLookup["jorrvaskr"] = "jorrvaskr";
            m_aliasLookup["companions"] = "jorrvaskr";
            m_aliasLookup["the companions"] = "jorrvaskr";
            m_aliasLookup["radiant raiment"] = "radiant raiment";
            m_aliasLookup["bits and pieces"] = "bits and pieces";
            m_aliasLookup["the scorched hammer"] = "the scorched hammer";
            m_aliasLookup["scorched hammer"] = "the scorched hammer";
            m_aliasLookup["the pawned prawn"] = "the pawned prawn";
            m_aliasLookup["pawned prawn"] = "the pawned prawn";
            m_aliasLookup["angelines aromatics"] = "angeline's aromatics";
            m_aliasLookup["angeline's aromatics"] = "angeline's aromatics";
            m_aliasLookup["angeline's"] = "angeline's aromatics";

            // "home" aliases could be resolved contextually in Papyrus
            // based on player's owned houses
        }

        void BuildPrefixIndex()
        {
            m_prefixIndex.clear();
            for (size_t i = 0; i < m_entries.size(); i++) {
                const std::string& name = m_entries[i].name;
                if (name.length() >= 3) {
                    m_prefixIndex[name.substr(0, 3)].push_back(i);
                }
            }
        }

        std::vector<LocationEntry> m_entries;
        std::unordered_map<std::string, size_t> m_exactLookup;       // name -> index
        std::unordered_map<std::string, size_t> m_editorIdLookup;    // editorId -> index
        std::unordered_map<std::string, std::string> m_aliasLookup;  // alias -> target name
        std::unordered_map<std::string, std::vector<size_t>> m_prefixIndex; // 3-char prefix -> indices
        std::unordered_map<RE::FormID, RE::FormID> m_doorIndex;      // interior cell FormID -> exterior door FormID
        std::unordered_map<RE::FormID, size_t> m_cellFormToIndex;    // cell FormID -> entry index (for disambiguation)
        std::unordered_map<std::string, int> m_nameOccurrences;      // lowercase name -> count of cells with that name
        mutable std::shared_mutex m_mutex;
        bool m_initialized = false;
    };
}
