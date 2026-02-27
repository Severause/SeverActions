#pragma once

// SeverActionsNative - Travel Database
// Fast travel location lookup replacing JContainers-based Papyrus implementation
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <string>
#include <unordered_map>
#include <vector>
#include <filesystem>
#include <fstream>
#include <nlohmann/json.hpp>

#include "StringUtils.h"

namespace SeverActionsNative
{
    using json = nlohmann::json;

    /**
     * Represents a travel marker/destination
     */
    struct TravelMarker
    {
        std::string cellEditorId;    // The cell's editor ID (key in database)
        std::string displayName;      // Human-readable name
        std::string markerFormIdStr;  // FormID string for the XMarker
        bool isInterior;              // Interior cell flag
    };

    /**
     * High-performance travel database
     *
     * Papyrus implementation: O(n) iteration with JMap.nextKey() + fuzzy matching
     * Native implementation: O(1) hash lookup + indexed aliases
     */
    class TravelDB
    {
    public:
        static TravelDB& GetInstance()
        {
            static TravelDB instance;
            return instance;
        }

        /**
         * Load travel markers from JSON file
         */
        bool LoadFromFile(const std::string& filePath)
        {
            SKSE::log::info("TravelDB: Loading from {}", filePath);

            // Clear existing data
            m_markers.clear();
            m_exactLookup.clear();
            m_aliasLookup.clear();

            try {
                std::ifstream file(filePath);
                if (!file.is_open()) {
                    SKSE::log::error("TravelDB: Could not open {}", filePath);
                    return false;
                }

                json data = json::parse(file);

                if (!data.contains("cellMarkers") || !data["cellMarkers"].is_object()) {
                    SKSE::log::error("TravelDB: No cellMarkers section found");
                    return false;
                }

                for (auto& [cellId, cellData] : data["cellMarkers"].items()) {
                    TravelMarker marker;
                    marker.cellEditorId = cellId;
                    marker.displayName = cellData.value("name", cellId);
                    marker.markerFormIdStr = cellData.value("markerFormID", "");
                    marker.isInterior = cellData.value("isInterior", true);

                    std::string lowerCellId = StringUtils::ToLower(cellId);
                    std::string lowerName = StringUtils::ToLower(marker.displayName);

                    size_t idx = m_markers.size();
                    m_markers.push_back(std::move(marker));

                    // Index by editor ID
                    m_exactLookup[lowerCellId] = idx;

                    // Also index by display name if different
                    if (lowerName != lowerCellId) {
                        m_exactLookup[lowerName] = idx;
                    }
                }

                // Build city aliases
                BuildCityAliases();

                m_initialized = true;
                SKSE::log::info("TravelDB: Loaded {} markers", m_markers.size());
                return true;
            }
            catch (const std::exception& e) {
                SKSE::log::error("TravelDB: Error loading: {}", e.what());
                return false;
            }
        }

        /**
         * Find cell ID by place name
         * Uses exact match, then alias lookup, then fuzzy search
         */
        std::string FindCellId(const std::string& placeName)
        {
            if (!m_initialized) return "";

            std::string lowerName = StringUtils::ToLower(placeName);

            // 1. Exact match
            auto exactIt = m_exactLookup.find(lowerName);
            if (exactIt != m_exactLookup.end()) {
                return m_markers[exactIt->second].cellEditorId;
            }

            // 2. City alias (e.g., "whiterun" -> "WhiterunBanneredMare")
            auto aliasIt = m_aliasLookup.find(lowerName);
            if (aliasIt != m_aliasLookup.end()) {
                return aliasIt->second;
            }

            // 3. Fuzzy search (contains)
            for (const auto& marker : m_markers) {
                std::string lowerCellId = StringUtils::ToLower(marker.cellEditorId);
                std::string lowerDisplayName = StringUtils::ToLower(marker.displayName);

                if (lowerCellId.find(lowerName) != std::string::npos ||
                    lowerDisplayName.find(lowerName) != std::string::npos) {
                    return marker.cellEditorId;
                }
            }

            return "";
        }

        /**
         * Get the marker reference for a cell
         */
        RE::TESObjectREFR* GetMarkerForCell(const std::string& cellId)
        {
            if (!m_initialized) return nullptr;

            std::string lowerCellId = StringUtils::ToLower(cellId);
            auto it = m_exactLookup.find(lowerCellId);
            if (it == m_exactLookup.end()) return nullptr;

            const TravelMarker& marker = m_markers[it->second];
            return ResolveMarker(marker.markerFormIdStr);
        }

        /**
         * Resolve place name directly to marker
         * Combines FindCellId + GetMarkerForCell
         */
        RE::TESObjectREFR* ResolvePlace(const std::string& placeName)
        {
            std::string cellId = FindCellId(placeName);
            if (cellId.empty()) return nullptr;
            return GetMarkerForCell(cellId);
        }

        /**
         * Get all available destination names (for validation/autocomplete)
         */
        std::vector<std::string> GetAllDestinations() const
        {
            std::vector<std::string> result;
            result.reserve(m_markers.size());

            for (const auto& marker : m_markers) {
                result.push_back(marker.displayName);
            }

            return result;
        }

        bool IsInitialized() const { return m_initialized; }
        size_t GetMarkerCount() const { return m_markers.size(); }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static RE::BSFixedString Papyrus_FindCellId(RE::StaticFunctionTag*, RE::BSFixedString placeName)
        {
            if (!placeName.data()) return "";
            return GetInstance().FindCellId(placeName.data()).c_str();
        }

        static RE::TESObjectREFR* Papyrus_GetMarkerForCell(RE::StaticFunctionTag*, RE::BSFixedString cellId)
        {
            if (!cellId.data()) return nullptr;
            return GetInstance().GetMarkerForCell(cellId.data());
        }

        static RE::TESObjectREFR* Papyrus_ResolvePlace(RE::StaticFunctionTag*, RE::BSFixedString placeName)
        {
            if (!placeName.data()) return nullptr;
            return GetInstance().ResolvePlace(placeName.data());
        }

        static bool Papyrus_LoadTravelDB(RE::StaticFunctionTag*, RE::BSFixedString filePath)
        {
            if (!filePath.data()) return false;
            return GetInstance().LoadFromFile(filePath.data());
        }

        static bool Papyrus_IsTravelDBLoaded(RE::StaticFunctionTag*)
        {
            return GetInstance().IsInitialized();
        }

        static int32_t Papyrus_GetTravelDBMarkerCount(RE::StaticFunctionTag*)
        {
            return static_cast<int32_t>(GetInstance().GetMarkerCount());
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("FindCellId", scriptName, Papyrus_FindCellId);
            a_vm->RegisterFunction("GetMarkerForCell", scriptName, Papyrus_GetMarkerForCell);
            a_vm->RegisterFunction("ResolvePlace", scriptName, Papyrus_ResolvePlace);
            a_vm->RegisterFunction("LoadTravelDatabase", scriptName, Papyrus_LoadTravelDB);
            a_vm->RegisterFunction("IsTravelDatabaseLoaded", scriptName, Papyrus_IsTravelDBLoaded);
            a_vm->RegisterFunction("GetTravelMarkerCount", scriptName, Papyrus_GetTravelDBMarkerCount);

            SKSE::log::info("Registered travel database functions");
        }

    private:
        TravelDB() = default;
        TravelDB(const TravelDB&) = delete;
        TravelDB& operator=(const TravelDB&) = delete;

        void BuildCityAliases()
        {
            // Major cities -> their main inn
            m_aliasLookup["whiterun"] = "WhiterunBanneredMare";
            m_aliasLookup["solitude"] = "SolitudeWinkingSkeever";
            m_aliasLookup["windhelm"] = "WindhelmCandlehearthHall";
            m_aliasLookup["riften"] = "RiftenBeeandBarb";
            m_aliasLookup["markarth"] = "MarkarthSilverBloodInn";
            m_aliasLookup["falkreath"] = "FalkreathDeadMansDrink";
            m_aliasLookup["morthal"] = "MorthalMoorsideInn";
            m_aliasLookup["dawnstar"] = "DawnstarWindpeakInn";
            m_aliasLookup["winterhold"] = "WinterholdTheFrozenHearth";

            // Towns
            m_aliasLookup["riverwood"] = "RiverwoodSleepingGiantInn";
            m_aliasLookup["ivarstead"] = "IvarsteadVilemyrInn";
            m_aliasLookup["rorikstead"] = "RoriksteadFrostfruitInn";
            m_aliasLookup["dragon bridge"] = "DragonBridgeFourShieldsTavern";
            m_aliasLookup["kynesgrove"] = "KynesgroveBraidwoodInn";

            // Standalone inns
            m_aliasLookup["nightgate"] = "NightgateInn";
            m_aliasLookup["old hroldan"] = "OldHroldanInn";
        }

        RE::TESObjectREFR* ResolveMarker(const std::string& formIdStr)
        {
            if (formIdStr.empty()) return nullptr;

            int32_t formId = StringUtils::HexToInt(formIdStr);
            if (formId == 0) return nullptr;

            RE::TESForm* form = RE::TESForm::LookupByID(formId);
            if (!form) return nullptr;

            return form->As<RE::TESObjectREFR>();
        }

        std::vector<TravelMarker> m_markers;
        std::unordered_map<std::string, size_t> m_exactLookup;  // lowercase name/cellId -> index
        std::unordered_map<std::string, std::string> m_aliasLookup;  // city name -> default cell
        bool m_initialized = false;
    };
}
