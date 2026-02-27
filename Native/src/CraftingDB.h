#pragma once

// SeverActionsNative - Crafting Database
// Fast item lookup system replacing JContainers-based Papyrus implementation
// Author: Severause

// Prevent Windows min/max macros from interfering with std::min/std::max
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <shared_mutex>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>
#include <filesystem>
#include <fstream>
#include <algorithm>
#include <nlohmann/json.hpp>

#include "StringUtils.h"

namespace SeverActionsNative
{
    using json = nlohmann::json;

    /**
     * Represents a craftable item entry
     * Stores multiple FormID strings for mod fallback support
     */
    struct CraftableItem
    {
        std::string name;                    // Normalized name (lowercase)
        std::string displayName;             // Original display name
        std::string category;                // "weapons", "armor", "misc"
        std::vector<std::string> formIds;    // FormID strings with plugin names
    };

    /**
     * High-performance crafting database
     *
     * Papyrus implementation: O(n) fuzzy search through all items
     * Native implementation: O(1) hash lookup + O(n) prefix search only when needed
     */
    class CraftingDB
    {
    public:
        // Singleton access
        static CraftingDB& GetInstance()
        {
            static CraftingDB instance;
            return instance;
        }

        /**
         * Load all JSON database files from a folder
         * Called on game load / data loaded event
         */
        bool LoadFromFolder(const std::string& folderPath)
        {
            std::unique_lock<std::shared_mutex> lock(m_mutex);
            SKSE::log::info("CraftingDB: Loading databases from {}", folderPath);

            // Clear existing data
            m_items.clear();
            m_exactLookup.clear();
            m_prefixIndex.clear();

            bool loadedAny = false;

            try {
                std::filesystem::path dbPath(folderPath);

                if (!std::filesystem::exists(dbPath)) {
                    SKSE::log::warn("CraftingDB: Folder does not exist: {}", folderPath);
                    return false;
                }

                for (const auto& entry : std::filesystem::directory_iterator(dbPath)) {
                    if (entry.path().extension() == ".json") {
                        if (LoadFile(entry.path().string())) {
                            loadedAny = true;
                        }
                    }
                }
            }
            catch (const std::exception& e) {
                SKSE::log::error("CraftingDB: Error loading folder: {}", e.what());
                return false;
            }

            if (loadedAny) {
                BuildPrefixIndex();
                SKSE::log::info("CraftingDB: Loaded {} items total", m_items.size());
            }

            m_initialized = loadedAny;
            return loadedAny;
        }

        /**
         * Find item by exact name (case-insensitive)
         * O(1) lookup
         */
        RE::TESForm* FindByName(const std::string& itemName)
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized) return nullptr;

            std::string searchName = StringUtils::ToLower(itemName);

            auto it = m_exactLookup.find(searchName);
            if (it == m_exactLookup.end()) {
                return nullptr;
            }

            // Try each FormID until one resolves
            const CraftableItem& item = m_items[it->second];
            return ResolveFirstValidForm(item.formIds);
        }

        /**
         * Find item by multi-stage fuzzy search with scoring.
         *
         * Stages (in priority order):
         *   1. Exact match (case-insensitive)
         *   2. Prefix match — search term at start of name, prefer shorter
         *   3. Contains match (scored) — substring anywhere, prefer word boundary + shorter
         *   4. Word match — all search words found in name, any order
         *   5. Levenshtein ≤ 2 on full name
         *   5b. Levenshtein ≤ 2 per word (total ≤ 4)
         */
        RE::TESForm* FuzzySearch(const std::string& searchTerm)
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized || searchTerm.empty()) return nullptr;

            std::string normalized = StringUtils::ToLower(searchTerm);

            // --- Stage 1: Exact match ---
            auto exactIt = m_exactLookup.find(normalized);
            if (exactIt != m_exactLookup.end()) {
                RE::TESForm* form = ResolveFirstValidForm(m_items[exactIt->second].formIds);
                if (form) {
                    SKSE::log::info("CraftingDB: Exact match for '{}' -> '{}'", searchTerm, m_items[exactIt->second].displayName);
                    return form;
                }
            }

            // --- Stage 2: Prefix match ---
            {
                const CraftableItem* bestPrefix = nullptr;
                size_t bestLen = 99999;

                for (const auto& item : m_items) {
                    if (item.name.length() >= normalized.length() &&
                        item.name.compare(0, normalized.length(), normalized) == 0) {
                        if (item.name.length() < bestLen) {
                            bestLen = item.name.length();
                            bestPrefix = &item;
                        }
                    }
                }

                if (bestPrefix) {
                    RE::TESForm* form = ResolveFirstValidForm(bestPrefix->formIds);
                    if (form) {
                        SKSE::log::info("CraftingDB: Prefix match for '{}' -> '{}'", searchTerm, bestPrefix->displayName);
                        return form;
                    }
                }
            }

            // --- Stage 3: Contains match (scored) ---
            {
                const CraftableItem* bestContains = nullptr;
                int bestScore = -1;

                for (const auto& item : m_items) {
                    size_t pos = item.name.find(normalized);
                    if (pos != std::string::npos) {
                        int score = kFuzzyBaseScore;
                        if (pos == 0) score += kFuzzyStartBonus;
                        else if (pos > 0 && item.name[pos - 1] == ' ') score += kFuzzyWordBoundaryBonus;
                        score -= static_cast<int>(item.name.length() - normalized.length());

                        if (score > bestScore) {
                            bestScore = score;
                            bestContains = &item;
                        }
                    }
                }

                if (bestContains) {
                    RE::TESForm* form = ResolveFirstValidForm(bestContains->formIds);
                    if (form) {
                        SKSE::log::info("CraftingDB: Contains match for '{}' -> '{}' (score={})", searchTerm, bestContains->displayName, bestScore);
                        return form;
                    }
                }
            }

            // --- Stage 4: Word match ---
            {
                std::vector<std::string> searchWords;
                std::istringstream iss(normalized);
                std::string word;
                while (iss >> word) {
                    if (!word.empty()) searchWords.push_back(word);
                }

                if (searchWords.size() > 1) {
                    const CraftableItem* bestWord = nullptr;
                    size_t bestLen = 99999;

                    for (const auto& item : m_items) {
                        bool allFound = true;
                        for (const auto& w : searchWords) {
                            if (item.name.find(w) == std::string::npos) {
                                allFound = false;
                                break;
                            }
                        }
                        if (allFound && item.name.length() < bestLen) {
                            bestLen = item.name.length();
                            bestWord = &item;
                        }
                    }

                    if (bestWord) {
                        RE::TESForm* form = ResolveFirstValidForm(bestWord->formIds);
                        if (form) {
                            SKSE::log::info("CraftingDB: Word match for '{}' -> '{}'", searchTerm, bestWord->displayName);
                            return form;
                        }
                    }
                }
            }

            // --- Stage 5: Levenshtein ≤ 2 ---
            {
                const CraftableItem* bestLev = nullptr;
                int bestDist = 999;
                size_t bestLen = 99999;

                for (const auto& item : m_items) {
                    int lenDiff = static_cast<int>(item.name.length()) - static_cast<int>(normalized.length());
                    if (lenDiff < -kLevenshteinLengthTolerance || lenDiff > kLevenshteinLengthTolerance) continue;

                    int dist = StringUtils::LevenshteinDistance(normalized, item.name);
                    if (dist <= kLevenshteinMaxDistance && (dist < bestDist || (dist == bestDist && item.name.length() < bestLen))) {
                        bestDist = dist;
                        bestLen = item.name.length();
                        bestLev = &item;
                    }
                }

                if (bestLev) {
                    RE::TESForm* form = ResolveFirstValidForm(bestLev->formIds);
                    if (form) {
                        SKSE::log::info("CraftingDB: Levenshtein match for '{}' -> '{}' (distance={})", searchTerm, bestLev->displayName, bestDist);
                        return form;
                    }
                }
            }

            // --- Stage 5b: Levenshtein per word ---
            {
                std::vector<std::string> searchWords;
                std::istringstream iss(normalized);
                std::string word;
                while (iss >> word) {
                    if (!word.empty()) searchWords.push_back(word);
                }

                if (searchWords.size() > 1) {
                    const CraftableItem* bestWordLev = nullptr;
                    int bestTotalDist = 999;
                    size_t bestLen = 99999;

                    for (const auto& item : m_items) {
                        std::vector<std::string> itemWords;
                        std::istringstream riss(item.name);
                        std::string rw;
                        while (riss >> rw) {
                            if (!rw.empty()) itemWords.push_back(rw);
                        }

                        int totalDist = 0;
                        bool allMatched = true;
                        for (const auto& sw : searchWords) {
                            int bestWordDist = 999;
                            for (const auto& iw : itemWords) {
                                int ld = static_cast<int>(iw.length()) - static_cast<int>(sw.length());
                                if (ld < -kLevenshteinMaxDistance || ld > kLevenshteinMaxDistance) continue;
                                int d = StringUtils::LevenshteinDistance(sw, iw);
                                if (d < bestWordDist) bestWordDist = d;
                            }
                            if (bestWordDist > kLevenshteinMaxDistance) { allMatched = false; break; }
                            totalDist += bestWordDist;
                        }

                        if (allMatched && (totalDist < bestTotalDist ||
                            (totalDist == bestTotalDist && item.name.length() < bestLen))) {
                            bestTotalDist = totalDist;
                            bestLen = item.name.length();
                            bestWordLev = &item;
                        }
                    }

                    if (bestWordLev && bestTotalDist <= kLevenshteinMaxTotalWordDist) {
                        RE::TESForm* form = ResolveFirstValidForm(bestWordLev->formIds);
                        if (form) {
                            SKSE::log::info("CraftingDB: Word-level Levenshtein match for '{}' -> '{}' (totalDist={})",
                                searchTerm, bestWordLev->displayName, bestTotalDist);
                            return form;
                        }
                    }
                }
            }

            SKSE::log::info("CraftingDB: No match found for '{}'", searchTerm);
            return nullptr;
        }

        /**
         * Search within a specific category using the same multi-stage fuzzy search.
         */
        RE::TESForm* SearchCategory(const std::string& category, const std::string& searchTerm)
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized || searchTerm.empty()) return nullptr;

            std::string normalized = StringUtils::ToLower(searchTerm);
            std::string lowerCategory = StringUtils::ToLower(category);

            // Build a filtered index list for this category
            std::vector<size_t> categoryIndices;
            for (size_t i = 0; i < m_items.size(); i++) {
                if (m_items[i].category == lowerCategory) {
                    categoryIndices.push_back(i);
                }
            }

            if (categoryIndices.empty()) return nullptr;

            // Stage 1: Exact
            auto exactIt = m_exactLookup.find(normalized);
            if (exactIt != m_exactLookup.end() && m_items[exactIt->second].category == lowerCategory) {
                RE::TESForm* form = ResolveFirstValidForm(m_items[exactIt->second].formIds);
                if (form) return form;
            }

            // Stage 2: Prefix
            {
                const CraftableItem* bestPrefix = nullptr;
                size_t bestLen = 99999;
                for (size_t idx : categoryIndices) {
                    const auto& item = m_items[idx];
                    if (item.name.length() >= normalized.length() &&
                        item.name.compare(0, normalized.length(), normalized) == 0 &&
                        item.name.length() < bestLen) {
                        bestLen = item.name.length();
                        bestPrefix = &item;
                    }
                }
                if (bestPrefix) {
                    RE::TESForm* form = ResolveFirstValidForm(bestPrefix->formIds);
                    if (form) return form;
                }
            }

            // Stage 3: Contains (scored)
            {
                const CraftableItem* bestContains = nullptr;
                int bestScore = -1;
                for (size_t idx : categoryIndices) {
                    const auto& item = m_items[idx];
                    size_t pos = item.name.find(normalized);
                    if (pos != std::string::npos) {
                        int score = kFuzzyBaseScore;
                        if (pos == 0) score += kFuzzyStartBonus;
                        else if (pos > 0 && item.name[pos - 1] == ' ') score += kFuzzyWordBoundaryBonus;
                        score -= static_cast<int>(item.name.length() - normalized.length());
                        if (score > bestScore) { bestScore = score; bestContains = &item; }
                    }
                }
                if (bestContains) {
                    RE::TESForm* form = ResolveFirstValidForm(bestContains->formIds);
                    if (form) return form;
                }
            }

            // Stage 4: Word match
            {
                std::vector<std::string> searchWords;
                std::istringstream iss(normalized);
                std::string word;
                while (iss >> word) { if (!word.empty()) searchWords.push_back(word); }

                if (searchWords.size() > 1) {
                    const CraftableItem* bestWord = nullptr;
                    size_t bestLen = 99999;
                    for (size_t idx : categoryIndices) {
                        const auto& item = m_items[idx];
                        bool allFound = true;
                        for (const auto& w : searchWords) {
                            if (item.name.find(w) == std::string::npos) { allFound = false; break; }
                        }
                        if (allFound && item.name.length() < bestLen) { bestLen = item.name.length(); bestWord = &item; }
                    }
                    if (bestWord) {
                        RE::TESForm* form = ResolveFirstValidForm(bestWord->formIds);
                        if (form) return form;
                    }
                }
            }

            // Stage 5: Levenshtein
            {
                const CraftableItem* bestLev = nullptr;
                int bestDist = 999;
                size_t bestLen = 99999;
                for (size_t idx : categoryIndices) {
                    const auto& item = m_items[idx];
                    int lenDiff = static_cast<int>(item.name.length()) - static_cast<int>(normalized.length());
                    if (lenDiff < -kLevenshteinLengthTolerance || lenDiff > kLevenshteinLengthTolerance) continue;
                    int dist = StringUtils::LevenshteinDistance(normalized, item.name);
                    if (dist <= kLevenshteinMaxDistance && (dist < bestDist || (dist == bestDist && item.name.length() < bestLen))) {
                        bestDist = dist; bestLen = item.name.length(); bestLev = &item;
                    }
                }
                if (bestLev) {
                    RE::TESForm* form = ResolveFirstValidForm(bestLev->formIds);
                    if (form) return form;
                }
            }

            return nullptr;
        }

        /**
         * Get database statistics
         */
        std::string GetStats() const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized) return "Database not loaded";

            int weapons = 0, armor = 0, misc = 0;
            for (const auto& item : m_items) {
                if (item.category == "weapons") weapons++;
                else if (item.category == "armor") armor++;
                else if (item.category == "misc") misc++;
            }

            return "Weapons: " + std::to_string(weapons) +
                   ", Armor: " + std::to_string(armor) +
                   ", Misc: " + std::to_string(misc);
        }

        bool IsInitialized() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_initialized; }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static RE::TESForm* Papyrus_FindCraftableByName(RE::StaticFunctionTag*, RE::BSFixedString itemName)
        {
            if (!itemName.data()) return nullptr;
            return GetInstance().FindByName(itemName.data());
        }

        static RE::TESForm* Papyrus_FuzzySearchCraftable(RE::StaticFunctionTag*, RE::BSFixedString searchTerm)
        {
            if (!searchTerm.data()) return nullptr;
            return GetInstance().FuzzySearch(searchTerm.data());
        }

        static RE::TESForm* Papyrus_SearchCategory(RE::StaticFunctionTag*, RE::BSFixedString category, RE::BSFixedString searchTerm)
        {
            if (!category.data() || !searchTerm.data()) return nullptr;
            return GetInstance().SearchCategory(category.data(), searchTerm.data());
        }

        static bool Papyrus_LoadCraftingDB(RE::StaticFunctionTag*, RE::BSFixedString folderPath)
        {
            if (!folderPath.data()) return false;
            return GetInstance().LoadFromFolder(folderPath.data());
        }

        static RE::BSFixedString Papyrus_GetCraftingDBStats(RE::StaticFunctionTag*)
        {
            return GetInstance().GetStats().c_str();
        }

        static bool Papyrus_IsCraftingDBLoaded(RE::StaticFunctionTag*)
        {
            return GetInstance().IsInitialized();
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("FindCraftableByName", scriptName, Papyrus_FindCraftableByName);
            a_vm->RegisterFunction("FuzzySearchCraftable", scriptName, Papyrus_FuzzySearchCraftable);
            a_vm->RegisterFunction("SearchCraftableCategory", scriptName, Papyrus_SearchCategory);
            a_vm->RegisterFunction("LoadCraftingDatabase", scriptName, Papyrus_LoadCraftingDB);
            a_vm->RegisterFunction("GetCraftingDatabaseStats", scriptName, Papyrus_GetCraftingDBStats);
            a_vm->RegisterFunction("IsCraftingDatabaseLoaded", scriptName, Papyrus_IsCraftingDBLoaded);

            SKSE::log::info("Registered crafting database functions");
        }

    private:
        CraftingDB() = default;
        CraftingDB(const CraftingDB&) = delete;
        CraftingDB& operator=(const CraftingDB&) = delete;

        bool LoadFile(const std::string& filePath)
        {
            try {
                std::ifstream file(filePath);
                if (!file.is_open()) {
                    SKSE::log::warn("CraftingDB: Could not open {}", filePath);
                    return false;
                }

                json data = json::parse(file);

                // Process each category
                ProcessCategory(data, "weapons");
                ProcessCategory(data, "armor");
                ProcessCategory(data, "misc");

                SKSE::log::info("CraftingDB: Loaded {}", filePath);
                return true;
            }
            catch (const std::exception& e) {
                SKSE::log::error("CraftingDB: Error parsing {}: {}", filePath, e.what());
                return false;
            }
        }

        void ProcessCategory(const json& data, const std::string& category)
        {
            if (!data.contains(category) || !data[category].is_object()) {
                return;
            }

            for (auto& [key, value] : data[category].items()) {
                // Skip comment keys
                if (!key.empty() && key[0] == '_') continue;

                std::string normalizedName = StringUtils::ToLower(key);

                // Check if item already exists (for merging)
                auto existingIt = m_exactLookup.find(normalizedName);

                if (existingIt != m_exactLookup.end()) {
                    // Add this FormID to existing item (at front for priority)
                    if (value.is_string()) {
                        m_items[existingIt->second].formIds.insert(
                            m_items[existingIt->second].formIds.begin(),
                            value.get<std::string>()
                        );
                    }
                } else {
                    // Create new item
                    CraftableItem item;
                    item.name = normalizedName;
                    item.displayName = key;
                    item.category = category;

                    if (value.is_string()) {
                        item.formIds.push_back(value.get<std::string>());
                    } else if (value.is_array()) {
                        for (const auto& v : value) {
                            if (v.is_string()) {
                                item.formIds.push_back(v.get<std::string>());
                            }
                        }
                    }

                    size_t idx = m_items.size();
                    m_items.push_back(std::move(item));
                    m_exactLookup[normalizedName] = idx;
                }
            }
        }

        void BuildPrefixIndex()
        {
            m_prefixIndex.clear();

            for (size_t i = 0; i < m_items.size(); i++) {
                const std::string& name = m_items[i].name;
                if (name.length() >= 3) {
                    std::string prefix = name.substr(0, 3);
                    m_prefixIndex[prefix].push_back(i);
                }
            }
        }

        RE::TESForm* ResolveFirstValidForm(const std::vector<std::string>& formIds)
        {
            for (const std::string& formIdStr : formIds) {
                RE::TESForm* form = ResolveFormIdString(formIdStr);
                if (form) return form;
            }
            return nullptr;
        }

        RE::TESForm* ResolveFormIdString(const std::string& formIdStr)
        {
            // Format: "PluginName.esp|0x00012EB7" or just "0x00012EB7"
            size_t pipePos = formIdStr.find('|');

            if (pipePos != std::string::npos) {
                std::string pluginName = formIdStr.substr(0, pipePos);
                std::string formIdPart = formIdStr.substr(pipePos + 1);

                // Check if plugin is loaded
                auto* dataHandler = RE::TESDataHandler::GetSingleton();
                if (!dataHandler) return nullptr;

                const RE::TESFile* modFile = dataHandler->LookupModByName(pluginName);
                if (!modFile) return nullptr;

                int32_t localFormId = StringUtils::HexToInt(formIdPart);
                return dataHandler->LookupForm(localFormId, pluginName);
            } else {
                // Raw FormID (runtime)
                int32_t formId = StringUtils::HexToInt(formIdStr);
                return RE::TESForm::LookupByID(formId);
            }
        }


        // Data storage
        std::vector<CraftableItem> m_items;
        std::unordered_map<std::string, size_t> m_exactLookup;  // name -> index
        std::unordered_map<std::string, std::vector<size_t>> m_prefixIndex;  // 3-char prefix -> indices
        bool m_initialized = false;
        mutable std::shared_mutex m_mutex;
    };
}
