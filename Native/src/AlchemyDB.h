#pragma once

// SeverActionsNative - Alchemy Database
// Scans all AlchemyItem records to build a database of potions and poisons
// Since alchemy recipes aren't stored as COBJ, we scan existing items instead
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <shared_mutex>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

#include "StringUtils.h"

namespace SeverActionsNative
{
    // Alchemy item types
    enum class AlchemyItemType
    {
        Unknown,
        Potion,      // Beneficial effects
        Poison,      // Harmful effects (applied to weapons)
        Food,        // Consumable food items (not cooked - those are in RecipeDB)
        Drink,       // Beverages
        Ingredient   // Raw alchemy ingredients
    };

    // Represents an alchemy item (potion, poison, food, ingredient)
    struct AlchemyEntry
    {
        std::string name;              // Display name
        std::string normalizedName;    // Lowercase for searching
        RE::FormID formId;             // FormID
        AlchemyItemType type;          // Classification
        int32_t goldValue;             // Base gold value
        bool isFood;                   // Is flagged as food
        bool isPoison;                 // Is flagged as poison

        // Effect information for context
        struct Effect
        {
            std::string name;
            float magnitude;
            uint32_t duration;
            bool isHostile;
        };
        std::vector<Effect> effects;
    };

    /**
     * High-performance alchemy database
     *
     * Scans all AlchemyItem and Ingredient forms on kDataLoaded
     * Provides fast lookup for "brew me a health potion" style requests
     */
    class AlchemyDB
    {
    public:
        static AlchemyDB& GetInstance()
        {
            static AlchemyDB instance;
            return instance;
        }

        /**
         * Scan all alchemy items and ingredients
         * Should be called on kDataLoaded event
         */
        bool Initialize()
        {
            std::unique_lock<std::shared_mutex> lock(m_mutex);
            if (m_initialized) {
                SKSE::log::info("AlchemyDB: Already initialized, skipping");
                return true;
            }

            SKSE::log::info("AlchemyDB: Scanning alchemy items...");

            auto dataHandler = RE::TESDataHandler::GetSingleton();
            if (!dataHandler) {
                SKSE::log::error("AlchemyDB: Could not get TESDataHandler");
                return false;
            }

            // Clear existing data
            m_allItems.clear();
            m_potions.clear();
            m_poisons.clear();
            m_foods.clear();
            m_drinks.clear();
            m_ingredients.clear();
            m_nameLookup.clear();

            // Scan AlchemyItem forms (potions, poisons, food, drinks)
            auto& alchArray = dataHandler->GetFormArray<RE::AlchemyItem>();

            int potions = 0, poisons = 0, foods = 0, drinks = 0;

            for (auto* alchItem : alchArray) {
                if (!alchItem) continue;

                // Skip items with no name
                const char* itemName = alchItem->GetName();
                if (!itemName || itemName[0] == '\0') continue;

                AlchemyEntry entry;
                entry.formId = alchItem->GetFormID();
                entry.name = itemName;
                entry.normalizedName = StringUtils::ToLower(entry.name);
                entry.goldValue = alchItem->GetGoldValue();
                entry.isFood = alchItem->IsFood();
                entry.isPoison = alchItem->IsPoison();

                // Classify the item
                entry.type = ClassifyAlchemyItem(alchItem);

                // Extract effects
                if (alchItem->effects.size() > 0) {
                    for (auto* effect : alchItem->effects) {
                        if (effect && effect->baseEffect) {
                            AlchemyEntry::Effect eff;
                            eff.name = effect->baseEffect->GetFullName();
                            eff.magnitude = effect->effectItem.magnitude;
                            eff.duration = effect->effectItem.duration;
                            eff.isHostile = effect->IsHostile();
                            entry.effects.push_back(std::move(eff));
                        }
                    }
                }

                // Add to master list
                size_t index = m_allItems.size();
                m_allItems.push_back(std::move(entry));

                // Add to category list
                switch (m_allItems.back().type) {
                    case AlchemyItemType::Potion:
                        m_potions.push_back(index);
                        potions++;
                        break;
                    case AlchemyItemType::Poison:
                        m_poisons.push_back(index);
                        poisons++;
                        break;
                    case AlchemyItemType::Food:
                        m_foods.push_back(index);
                        foods++;
                        break;
                    case AlchemyItemType::Drink:
                        m_drinks.push_back(index);
                        drinks++;
                        break;
                    default:
                        break;
                }

                // Add to name lookup
                if (m_nameLookup.find(m_allItems.back().normalizedName) == m_nameLookup.end()) {
                    m_nameLookup[m_allItems.back().normalizedName] = index;
                }
            }

            // Scan Ingredient forms
            auto& ingredientArray = dataHandler->GetFormArray<RE::IngredientItem>();
            int ingredients = 0;

            for (auto* ingredient : ingredientArray) {
                if (!ingredient) continue;

                const char* itemName = ingredient->GetName();
                if (!itemName || itemName[0] == '\0') continue;

                AlchemyEntry entry;
                entry.formId = ingredient->GetFormID();
                entry.name = itemName;
                entry.normalizedName = StringUtils::ToLower(entry.name);
                entry.goldValue = ingredient->GetGoldValue();
                entry.isFood = false;
                entry.isPoison = false;
                entry.type = AlchemyItemType::Ingredient;

                // Note: IngredientItem effect extraction is more complex due to different structure
                // For now, we skip effect extraction for ingredients since we primarily need
                // potions/poisons for the brewing actions
                // TODO: Add proper effect extraction for ingredients if needed

                size_t index = m_allItems.size();
                m_allItems.push_back(std::move(entry));
                m_ingredients.push_back(index);
                ingredients++;

                if (m_nameLookup.find(m_allItems.back().normalizedName) == m_nameLookup.end()) {
                    m_nameLookup[m_allItems.back().normalizedName] = index;
                }
            }

            m_initialized = true;

            // Release excess vector capacity now that init is done
            m_allItems.shrink_to_fit();
            m_potions.shrink_to_fit();
            m_poisons.shrink_to_fit();
            m_foods.shrink_to_fit();
            m_drinks.shrink_to_fit();
            m_ingredients.shrink_to_fit();

            SKSE::log::info("AlchemyDB: Scan complete");
            SKSE::log::info("  - Potions: {}", potions);
            SKSE::log::info("  - Poisons: {}", poisons);
            SKSE::log::info("  - Foods: {}", foods);
            SKSE::log::info("  - Drinks: {}", drinks);
            SKSE::log::info("  - Ingredients: {}", ingredients);
            SKSE::log::info("  - Total: {}", m_allItems.size());

            return true;
        }

        // ============================================
        // Lookup Functions
        // ============================================

        /**
         * Find an alchemy item by exact name
         */
        const AlchemyEntry* FindByName(const std::string& name) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized) return nullptr;

            std::string normalized = StringUtils::ToLower(name);
            auto it = m_nameLookup.find(normalized);
            if (it != m_nameLookup.end()) {
                return &m_allItems[it->second];
            }
            return nullptr;
        }

        /**
         * Find a potion by name (partial match supported)
         */
        const AlchemyEntry* FindPotion(const std::string& searchTerm) const
        {
            return FuzzySearchCategory(searchTerm, m_potions);
        }

        /**
         * Find a poison by name
         */
        const AlchemyEntry* FindPoison(const std::string& searchTerm) const
        {
            return FuzzySearchCategory(searchTerm, m_poisons);
        }

        /**
         * Find a food item by name
         */
        const AlchemyEntry* FindFood(const std::string& searchTerm) const
        {
            return FuzzySearchCategory(searchTerm, m_foods);
        }

        /**
         * Find an ingredient by name
         */
        const AlchemyEntry* FindIngredient(const std::string& searchTerm) const
        {
            return FuzzySearchCategory(searchTerm, m_ingredients);
        }

        /**
         * Find any potion/poison that provides a specific effect
         * e.g., "restore health", "fortify smithing"
         */
        const AlchemyEntry* FindByEffect(const std::string& effectName, bool potionOnly = true) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized) return nullptr;

            std::string normalized = StringUtils::ToLower(effectName);

            const std::vector<size_t>& searchList = potionOnly ? m_potions : m_poisons;

            for (size_t idx : searchList) {
                const AlchemyEntry& entry = m_allItems[idx];
                for (const auto& effect : entry.effects) {
                    std::string effName = StringUtils::ToLower(effect.name);
                    if (effName.find(normalized) != std::string::npos) {
                        return &entry;
                    }
                }
            }

            return nullptr;
        }

        /**
         * Get the actual TESForm for an alchemy entry
         */
        RE::TESForm* GetForm(const AlchemyEntry* entry) const
        {
            if (!entry) return nullptr;
            return RE::TESForm::LookupByID(entry->formId);
        }

        /**
         * Get AlchemyItem specifically
         */
        RE::AlchemyItem* GetAlchemyItem(const AlchemyEntry* entry) const
        {
            if (!entry) return nullptr;
            auto* form = RE::TESForm::LookupByID(entry->formId);
            return form ? form->As<RE::AlchemyItem>() : nullptr;
        }

        // Statistics
        size_t GetPotionCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_potions.size(); }
        size_t GetPoisonCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_poisons.size(); }
        size_t GetFoodCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_foods.size(); }
        size_t GetDrinkCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_drinks.size(); }
        size_t GetIngredientCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_ingredients.size(); }
        size_t GetTotalCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_allItems.size(); }
        bool IsInitialized() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_initialized; }

        // ============================================
        // Papyrus Native Function Wrappers
        // ============================================

        static RE::AlchemyItem* Papyrus_FindPotion(RE::StaticFunctionTag*, RE::BSFixedString name)
        {
            if (!name.data()) return nullptr;
            const AlchemyEntry* entry = GetInstance().FindPotion(name.data());
            return entry ? GetInstance().GetAlchemyItem(entry) : nullptr;
        }

        static RE::AlchemyItem* Papyrus_FindPoison(RE::StaticFunctionTag*, RE::BSFixedString name)
        {
            if (!name.data()) return nullptr;
            const AlchemyEntry* entry = GetInstance().FindPoison(name.data());
            return entry ? GetInstance().GetAlchemyItem(entry) : nullptr;
        }

        static RE::AlchemyItem* Papyrus_FindPotionByEffect(RE::StaticFunctionTag*, RE::BSFixedString effectName)
        {
            if (!effectName.data()) return nullptr;
            const AlchemyEntry* entry = GetInstance().FindByEffect(effectName.data(), true);
            return entry ? GetInstance().GetAlchemyItem(entry) : nullptr;
        }

        static RE::AlchemyItem* Papyrus_FindPoisonByEffect(RE::StaticFunctionTag*, RE::BSFixedString effectName)
        {
            if (!effectName.data()) return nullptr;
            const AlchemyEntry* entry = GetInstance().FindByEffect(effectName.data(), false);
            return entry ? GetInstance().GetAlchemyItem(entry) : nullptr;
        }

        static RE::BSFixedString Papyrus_GetAlchemyDBStats(RE::StaticFunctionTag*)
        {
            auto& db = GetInstance();
            std::string stats = "Potions: " + std::to_string(db.GetPotionCount()) +
                              ", Poisons: " + std::to_string(db.GetPoisonCount()) +
                              ", Foods: " + std::to_string(db.GetFoodCount()) +
                              ", Ingredients: " + std::to_string(db.GetIngredientCount());
            return stats.c_str();
        }

        static bool Papyrus_IsAlchemyDBLoaded(RE::StaticFunctionTag*)
        {
            return GetInstance().IsInitialized();
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("FindPotion", scriptName, Papyrus_FindPotion);
            a_vm->RegisterFunction("FindPoison", scriptName, Papyrus_FindPoison);
            a_vm->RegisterFunction("FindPotionByEffect", scriptName, Papyrus_FindPotionByEffect);
            a_vm->RegisterFunction("FindPoisonByEffect", scriptName, Papyrus_FindPoisonByEffect);
            a_vm->RegisterFunction("GetAlchemyDBStats", scriptName, Papyrus_GetAlchemyDBStats);
            a_vm->RegisterFunction("IsAlchemyDBLoaded", scriptName, Papyrus_IsAlchemyDBLoaded);

            SKSE::log::info("Registered alchemy database functions");
        }

    private:
        AlchemyDB() = default;
        AlchemyDB(const AlchemyDB&) = delete;
        AlchemyDB& operator=(const AlchemyDB&) = delete;

        AlchemyItemType ClassifyAlchemyItem(RE::AlchemyItem* item) const
        {
            if (!item) return AlchemyItemType::Unknown;

            // Check poison flag first
            if (item->IsPoison()) {
                return AlchemyItemType::Poison;
            }

            // Check if it's food
            if (item->IsFood()) {
                // Distinguish between food and drinks by checking name patterns
                std::string name = StringUtils::ToLower(item->GetName());
                if (name.find("ale") != std::string::npos ||
                    name.find("wine") != std::string::npos ||
                    name.find("mead") != std::string::npos ||
                    name.find("water") != std::string::npos ||
                    name.find("milk") != std::string::npos ||
                    name.find("brew") != std::string::npos ||
                    name.find("drink") != std::string::npos ||
                    name.find("skooma") != std::string::npos ||
                    name.find("juice") != std::string::npos) {
                    return AlchemyItemType::Drink;
                }
                return AlchemyItemType::Food;
            }

            // Default to potion for non-food, non-poison alchemy items
            return AlchemyItemType::Potion;
        }

        /**
         * Multi-stage fuzzy search within a category list.
         *
         * Stages (in priority order):
         *   1. Exact match (case-insensitive)
         *   2. Prefix match — search term at start of name, prefer shorter
         *   3. Contains match (scored) — substring anywhere, prefer word boundary + shorter
         *   4. Word match — all search words found in name, any order
         *   5. Levenshtein ≤ 2 on full name
         *   5b. Levenshtein ≤ 2 per word (total ≤ 4)
         */
        const AlchemyEntry* FuzzySearchCategory(const std::string& searchTerm, const std::vector<size_t>& categoryList) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized || searchTerm.empty()) return nullptr;

            std::string normalized = StringUtils::ToLower(searchTerm);

            // --- Stage 1: Exact match ---
            auto exactIt = m_nameLookup.find(normalized);
            if (exactIt != m_nameLookup.end()) {
                for (size_t idx : categoryList) {
                    if (idx == exactIt->second) {
                        SKSE::log::info("AlchemyDB: Exact match for '{}' -> '{}'", searchTerm, m_allItems[idx].name);
                        return &m_allItems[idx];
                    }
                }
            }

            // --- Stage 2: Prefix match ---
            {
                const AlchemyEntry* bestPrefix = nullptr;
                size_t bestLen = 99999;

                for (size_t idx : categoryList) {
                    const AlchemyEntry& entry = m_allItems[idx];
                    if (entry.normalizedName.length() >= normalized.length() &&
                        entry.normalizedName.compare(0, normalized.length(), normalized) == 0) {
                        if (entry.normalizedName.length() < bestLen) {
                            bestLen = entry.normalizedName.length();
                            bestPrefix = &entry;
                        }
                    }
                }

                if (bestPrefix) {
                    SKSE::log::info("AlchemyDB: Prefix match for '{}' -> '{}'", searchTerm, bestPrefix->name);
                    return bestPrefix;
                }
            }

            // --- Stage 3: Contains match (scored) ---
            {
                const AlchemyEntry* bestContains = nullptr;
                int bestScore = -1;

                for (size_t idx : categoryList) {
                    const AlchemyEntry& entry = m_allItems[idx];
                    size_t pos = entry.normalizedName.find(normalized);
                    if (pos != std::string::npos) {
                        int score = kFuzzyBaseScore;
                        if (pos == 0) score += kFuzzyStartBonus;
                        else if (pos > 0 && entry.normalizedName[pos - 1] == ' ') score += kFuzzyWordBoundaryBonus;
                        score -= static_cast<int>(entry.normalizedName.length() - normalized.length());

                        if (score > bestScore) {
                            bestScore = score;
                            bestContains = &entry;
                        }
                    }
                }

                if (bestContains) {
                    SKSE::log::info("AlchemyDB: Contains match for '{}' -> '{}' (score={})", searchTerm, bestContains->name, bestScore);
                    return bestContains;
                }
            }

            // --- Stage 4: Word match (all words in search appear in name, any order) ---
            {
                std::vector<std::string> searchWords;
                std::istringstream iss(normalized);
                std::string word;
                while (iss >> word) {
                    if (!word.empty()) searchWords.push_back(word);
                }

                if (searchWords.size() > 1) {
                    const AlchemyEntry* bestWord = nullptr;
                    size_t bestLen = 99999;

                    for (size_t idx : categoryList) {
                        const AlchemyEntry& entry = m_allItems[idx];
                        bool allFound = true;
                        for (const auto& w : searchWords) {
                            if (entry.normalizedName.find(w) == std::string::npos) {
                                allFound = false;
                                break;
                            }
                        }
                        if (allFound && entry.normalizedName.length() < bestLen) {
                            bestLen = entry.normalizedName.length();
                            bestWord = &entry;
                        }
                    }

                    if (bestWord) {
                        SKSE::log::info("AlchemyDB: Word match for '{}' -> '{}'", searchTerm, bestWord->name);
                        return bestWord;
                    }
                }
            }

            // --- Stage 5: Levenshtein distance ≤ 2 on full name ---
            {
                const AlchemyEntry* bestLev = nullptr;
                int bestDist = 999;
                size_t bestLen = 99999;

                for (size_t idx : categoryList) {
                    const AlchemyEntry& entry = m_allItems[idx];
                    int lenDiff = static_cast<int>(entry.normalizedName.length()) - static_cast<int>(normalized.length());
                    if (lenDiff < -kLevenshteinLengthTolerance || lenDiff > kLevenshteinLengthTolerance) continue;

                    int dist = StringUtils::LevenshteinDistance(normalized, entry.normalizedName);
                    if (dist <= kLevenshteinMaxDistance && (dist < bestDist || (dist == bestDist && entry.normalizedName.length() < bestLen))) {
                        bestDist = dist;
                        bestLen = entry.normalizedName.length();
                        bestLev = &entry;
                    }
                }

                if (bestLev) {
                    SKSE::log::info("AlchemyDB: Levenshtein match for '{}' -> '{}' (distance={})", searchTerm, bestLev->name, bestDist);
                    return bestLev;
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
                    const AlchemyEntry* bestWordLev = nullptr;
                    int bestTotalDist = 999;
                    size_t bestLen = 99999;

                    for (size_t idx : categoryList) {
                        const AlchemyEntry& entry = m_allItems[idx];

                        std::vector<std::string> entryWords;
                        std::istringstream riss(entry.normalizedName);
                        std::string rw;
                        while (riss >> rw) {
                            if (!rw.empty()) entryWords.push_back(rw);
                        }

                        int totalDist = 0;
                        bool allMatched = true;
                        for (const auto& sw : searchWords) {
                            int bestWordDist = 999;
                            for (const auto& ew : entryWords) {
                                int ld = static_cast<int>(ew.length()) - static_cast<int>(sw.length());
                                if (ld < -kLevenshteinMaxDistance || ld > kLevenshteinMaxDistance) continue;
                                int d = StringUtils::LevenshteinDistance(sw, ew);
                                if (d < bestWordDist) bestWordDist = d;
                            }
                            if (bestWordDist > kLevenshteinMaxDistance) { allMatched = false; break; }
                            totalDist += bestWordDist;
                        }

                        if (allMatched && (totalDist < bestTotalDist ||
                            (totalDist == bestTotalDist && entry.normalizedName.length() < bestLen))) {
                            bestTotalDist = totalDist;
                            bestLen = entry.normalizedName.length();
                            bestWordLev = &entry;
                        }
                    }

                    if (bestWordLev && bestTotalDist <= kLevenshteinMaxTotalWordDist) {
                        SKSE::log::info("AlchemyDB: Word-level Levenshtein match for '{}' -> '{}' (totalDist={})",
                            searchTerm, bestWordLev->name, bestTotalDist);
                        return bestWordLev;
                    }
                }
            }

            SKSE::log::info("AlchemyDB: No match found for '{}'", searchTerm);
            return nullptr;
        }


        // Data storage
        std::vector<AlchemyEntry> m_allItems;
        std::vector<size_t> m_potions;
        std::vector<size_t> m_poisons;
        std::vector<size_t> m_foods;
        std::vector<size_t> m_drinks;
        std::vector<size_t> m_ingredients;
        std::unordered_map<std::string, size_t> m_nameLookup;
        bool m_initialized = false;
        mutable std::shared_mutex m_mutex;
    };
}
