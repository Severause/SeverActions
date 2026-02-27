#pragma once

// SeverActionsNative - Recipe Database
// Scans all BGSConstructibleObject records at game load to build
// native databases for cooking, smithing, smelting, and tanning
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
    // Known workbench keyword FormIDs
    namespace WorkbenchKeywords
    {
        constexpr RE::FormID CraftingSmithingForge = 0x00088105;
        constexpr RE::FormID CraftingCookpot = 0x000A5CB3;
        constexpr RE::FormID CraftingSmelter = 0x000A5CCE;
        constexpr RE::FormID CraftingTanningRack = 0x000493BD;
        constexpr RE::FormID CraftingSmithingSharpeningWheel = 0x00088108;
        constexpr RE::FormID CraftingSmithingArmorTable = 0x000ADB78;
        // Hearthfire oven - baked goods (apple pie, crostatas, dumplings, etc.)
        constexpr RE::FormID BYOHCraftingOven = 0x000117F7;  // HearthFires.esm
        // Skyrim doesn't use COBJ for alchemy - it's hard-coded
    }

    // Recipe categories
    enum class RecipeCategory
    {
        Unknown,
        Smithing,      // Forge - weapons, armor
        Cooking,       // Cooking pot - food
        Smelting,      // Smelter - ore to ingots
        Tanning,       // Tanning rack - leather
        Tempering,     // Grindstone/Workbench - improve items
    };

    // Represents a single craftable recipe
    struct Recipe
    {
        std::string name;              // Display name of created item
        std::string normalizedName;    // Lowercase for searching
        RE::FormID createdItemId;      // FormID of the result
        RE::FormID recipeId;           // FormID of the COBJ record
        uint16_t quantity;             // Number created
        RecipeCategory category;       // What workbench type
        bool isOvenRecipe = false;     // True if this uses BYOHCraftingOven (not CraftingCookpot)

        // Ingredient info (for display/AI context)
        struct Ingredient
        {
            std::string name;
            uint32_t count;
            RE::FormID formId;
        };
        std::vector<Ingredient> ingredients;
    };

    /**
     * High-performance recipe database
     *
     * Scans all BGSConstructibleObject records on kDataLoaded
     * and builds categorized lookup tables for instant access.
     */
    class RecipeDB
    {
    public:
        static RecipeDB& GetInstance()
        {
            static RecipeDB instance;
            return instance;
        }

        /**
         * Scan all COBJ records and build the database
         * Should be called on kDataLoaded event
         */
        bool Initialize()
        {
            std::unique_lock<std::shared_mutex> lock(m_mutex);
            if (m_initialized) {
                SKSE::log::info("RecipeDB: Already initialized, skipping");
                return true;
            }

            SKSE::log::info("RecipeDB: Scanning constructible objects...");

            auto dataHandler = RE::TESDataHandler::GetSingleton();
            if (!dataHandler) {
                SKSE::log::error("RecipeDB: Could not get TESDataHandler");
                return false;
            }

            // Clear any existing data
            m_allRecipes.clear();
            m_cookingRecipes.clear();
            m_smithingRecipes.clear();
            m_smeltingRecipes.clear();
            m_tanningRecipes.clear();
            m_temperingRecipes.clear();
            m_nameLookup.clear();

            // Get all constructible objects
            auto& cobjArray = dataHandler->GetFormArray<RE::BGSConstructibleObject>();

            int totalScanned = 0;
            int cooking = 0, smithing = 0, smelting = 0, tanning = 0, tempering = 0, other = 0;

            for (auto* cobj : cobjArray) {
                if (!cobj) continue;
                totalScanned++;

                // Skip if no created item
                if (!cobj->createdItem) continue;

                // Determine category from workbench keyword
                RecipeCategory category = GetCategoryFromKeyword(cobj->benchKeyword);

                // Check if this is specifically an oven recipe (BYOHCraftingOven)
                bool ovenRecipe = IsOvenKeyword(cobj->benchKeyword);

                // If category is unknown but the created item is a weapon or armor,
                // default to Smithing - this catches modded items with custom keywords
                if (category == RecipeCategory::Unknown) {
                    auto formType = cobj->createdItem->GetFormType();
                    if (formType == RE::FormType::Weapon || formType == RE::FormType::Armor) {
                        category = RecipeCategory::Smithing;
                    }
                }

                // Build recipe entry
                Recipe recipe;
                recipe.recipeId = cobj->GetFormID();
                recipe.createdItemId = cobj->createdItem->GetFormID();
                recipe.quantity = cobj->data.numConstructed;
                recipe.category = category;
                recipe.isOvenRecipe = ovenRecipe;

                // Get created item name
                if (auto* boundObj = cobj->createdItem->As<RE::TESBoundObject>()) {
                    recipe.name = boundObj->GetName();
                } else {
                    recipe.name = cobj->createdItem->GetName();
                }

                if (recipe.name.empty()) {
                    // Skip items with no name
                    continue;
                }

                recipe.normalizedName = StringUtils::ToLower(recipe.name);

                // Extract ingredients
                if (cobj->requiredItems.numContainerObjects > 0 && cobj->requiredItems.containerObjects) {
                    for (uint32_t i = 0; i < cobj->requiredItems.numContainerObjects; i++) {
                        auto* containerObj = cobj->requiredItems.containerObjects[i];
                        if (containerObj && containerObj->obj) {
                            Recipe::Ingredient ing;
                            ing.formId = containerObj->obj->GetFormID();
                            ing.count = containerObj->count;
                            ing.name = containerObj->obj->GetName();
                            recipe.ingredients.push_back(std::move(ing));
                        }
                    }
                }

                // Add to master list
                size_t index = m_allRecipes.size();
                m_allRecipes.push_back(std::move(recipe));

                // Add to category-specific list
                switch (category) {
                    case RecipeCategory::Cooking:
                        m_cookingRecipes.push_back(index);
                        cooking++;
                        break;
                    case RecipeCategory::Smithing:
                        m_smithingRecipes.push_back(index);
                        smithing++;
                        break;
                    case RecipeCategory::Smelting:
                        m_smeltingRecipes.push_back(index);
                        smelting++;
                        break;
                    case RecipeCategory::Tanning:
                        m_tanningRecipes.push_back(index);
                        tanning++;
                        break;
                    case RecipeCategory::Tempering:
                        m_temperingRecipes.push_back(index);
                        tempering++;
                        break;
                    default:
                        other++;
                        break;
                }

                // Add to name lookup (handle duplicates by preferring first found)
                if (m_nameLookup.find(m_allRecipes.back().normalizedName) == m_nameLookup.end()) {
                    m_nameLookup[m_allRecipes.back().normalizedName] = index;
                }
            }

            m_initialized = true;

            // Release excess vector capacity now that init is done
            m_allRecipes.shrink_to_fit();
            m_cookingRecipes.shrink_to_fit();
            m_smithingRecipes.shrink_to_fit();
            m_smeltingRecipes.shrink_to_fit();
            m_tanningRecipes.shrink_to_fit();
            m_temperingRecipes.shrink_to_fit();

            SKSE::log::info("RecipeDB: Scanned {} COBJ records", totalScanned);
            SKSE::log::info("RecipeDB: Found {} recipes total:", m_allRecipes.size());
            SKSE::log::info("  - Cooking: {}", cooking);
            SKSE::log::info("  - Smithing: {}", smithing);
            SKSE::log::info("  - Smelting: {}", smelting);
            SKSE::log::info("  - Tanning: {}", tanning);
            SKSE::log::info("  - Tempering: {}", tempering);
            SKSE::log::info("  - Other/Unknown: {}", other);

            return true;
        }

        // ============================================
        // Lookup Functions
        // ============================================

        /**
         * Find a recipe by exact name (case-insensitive)
         * Returns nullptr if not found
         */
        const Recipe* FindByName(const std::string& name) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized) return nullptr;

            std::string normalized = StringUtils::ToLower(name);
            auto it = m_nameLookup.find(normalized);
            if (it != m_nameLookup.end()) {
                return &m_allRecipes[it->second];
            }
            return nullptr;
        }

        /**
         * Find a recipe by multi-stage fuzzy search with scoring.
         * Optionally filter by category.
         *
         * Search stages (in priority order):
         *   1. Exact match (case-insensitive) — "apple cabbage stew" → exact hit
         *   2. Prefix match — "apple cab" → matches "apple cabbage stew"
         *   3. Contains match (best-fit scored) — "cabbage stew" → matches, shorter names preferred
         *   4. Word match — all search words appear in the name in any order
         *   5. Levenshtein distance ≤ 2 — "aple cabage stew" → typo tolerance
         */
        const Recipe* FuzzySearch(const std::string& searchTerm, RecipeCategory categoryFilter = RecipeCategory::Unknown) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized || searchTerm.empty()) return nullptr;

            std::string normalized = StringUtils::ToLower(searchTerm);

            // --- Stage 1: Exact match ---
            auto exactIt = m_nameLookup.find(normalized);
            if (exactIt != m_nameLookup.end()) {
                const Recipe& r = m_allRecipes[exactIt->second];
                if (categoryFilter == RecipeCategory::Unknown || r.category == categoryFilter) {
                    SKSE::log::info("RecipeDB: Exact match for '{}' -> '{}'", searchTerm, r.name);
                    return &r;
                }
            }

            // Build the iterator list for the active category
            // We iterate indices and check the master list
            auto iterateCategory = [&](auto callback) {
                if (categoryFilter != RecipeCategory::Unknown) {
                    const std::vector<size_t>* list = GetCategoryList(categoryFilter);
                    if (list) {
                        for (size_t idx : *list) {
                            callback(idx, m_allRecipes[idx]);
                        }
                    }
                } else {
                    for (size_t i = 0; i < m_allRecipes.size(); i++) {
                        callback(i, m_allRecipes[i]);
                    }
                }
            };

            // --- Stage 2: Prefix match (name starts with search term) ---
            {
                const Recipe* bestPrefix = nullptr;
                size_t bestLen = 99999;

                iterateCategory([&](size_t /*idx*/, const Recipe& recipe) {
                    if (recipe.normalizedName.length() >= normalized.length() &&
                        recipe.normalizedName.compare(0, normalized.length(), normalized) == 0) {
                        // Prefer shorter names (more specific match)
                        if (recipe.normalizedName.length() < bestLen) {
                            bestLen = recipe.normalizedName.length();
                            bestPrefix = &recipe;
                        }
                    }
                });

                if (bestPrefix) {
                    SKSE::log::info("RecipeDB: Prefix match for '{}' -> '{}'", searchTerm, bestPrefix->name);
                    return bestPrefix;
                }
            }

            // --- Stage 3: Contains match (search term appears anywhere in name, scored) ---
            {
                const Recipe* bestContains = nullptr;
                int bestScore = -1;

                iterateCategory([&](size_t /*idx*/, const Recipe& recipe) {
                    if (recipe.normalizedName.find(normalized) != std::string::npos) {
                        // Score: prefer shorter names (less noise) and earlier position
                        size_t pos = recipe.normalizedName.find(normalized);
                        // Higher score = better match
                        // Bonus for match at start of a word boundary
                        int score = kFuzzyBaseScore;
                        if (pos == 0) score += kFuzzyStartBonus;  // starts with
                        else if (pos > 0 && recipe.normalizedName[pos - 1] == ' ') score += kFuzzyWordBoundaryBonus;  // word boundary
                        // Penalty for longer names (less specific)
                        score -= static_cast<int>(recipe.normalizedName.length() - normalized.length());

                        if (score > bestScore) {
                            bestScore = score;
                            bestContains = &recipe;
                        }
                    }
                });

                if (bestContains) {
                    SKSE::log::info("RecipeDB: Contains match for '{}' -> '{}' (score={})", searchTerm, bestContains->name, bestScore);
                    return bestContains;
                }
            }

            // --- Stage 4: Word match (all words in search term appear in name, any order) ---
            // Handles "stew cabbage apple" matching "apple cabbage stew"
            {
                std::vector<std::string> searchWords;
                std::istringstream iss(normalized);
                std::string word;
                while (iss >> word) {
                    if (!word.empty()) searchWords.push_back(word);
                }

                if (searchWords.size() > 1) {
                    const Recipe* bestWord = nullptr;
                    size_t bestLen = 99999;

                    iterateCategory([&](size_t /*idx*/, const Recipe& recipe) {
                        bool allFound = true;
                        for (const auto& w : searchWords) {
                            if (recipe.normalizedName.find(w) == std::string::npos) {
                                allFound = false;
                                break;
                            }
                        }
                        if (allFound && recipe.normalizedName.length() < bestLen) {
                            bestLen = recipe.normalizedName.length();
                            bestWord = &recipe;
                        }
                    });

                    if (bestWord) {
                        SKSE::log::info("RecipeDB: Word match for '{}' -> '{}'", searchTerm, bestWord->name);
                        return bestWord;
                    }
                }
            }

            // --- Stage 5: Levenshtein distance for typo tolerance ---
            // Accept matches with edit distance ≤ 2, prefer lowest distance then shortest name
            {
                const Recipe* bestLev = nullptr;
                int bestDist = 999;
                size_t bestLen = 99999;

                iterateCategory([&](size_t /*idx*/, const Recipe& recipe) {
                    // Skip if length difference is too large (can't be within distance 2)
                    int lenDiff = static_cast<int>(recipe.normalizedName.length()) - static_cast<int>(normalized.length());
                    if (lenDiff < -kLevenshteinLengthTolerance || lenDiff > kLevenshteinLengthTolerance) return;

                    int dist = StringUtils::LevenshteinDistance(normalized, recipe.normalizedName);
                    if (dist <= kLevenshteinMaxDistance && (dist < bestDist || (dist == bestDist && recipe.normalizedName.length() < bestLen))) {
                        bestDist = dist;
                        bestLen = recipe.normalizedName.length();
                        bestLev = &recipe;
                    }
                });

                if (bestLev) {
                    SKSE::log::info("RecipeDB: Levenshtein match for '{}' -> '{}' (distance={})", searchTerm, bestLev->name, bestDist);
                    return bestLev;
                }
            }

            // --- Stage 5b: Levenshtein on individual words ---
            // For multi-word searches like "aple cabage stew", check if each word
            // fuzzy-matches a word in the recipe name
            {
                std::vector<std::string> searchWords;
                std::istringstream iss(normalized);
                std::string word;
                while (iss >> word) {
                    if (!word.empty()) searchWords.push_back(word);
                }

                if (searchWords.size() > 1) {
                    const Recipe* bestWordLev = nullptr;
                    int bestTotalDist = 999;
                    size_t bestLen = 99999;

                    iterateCategory([&](size_t /*idx*/, const Recipe& recipe) {
                        // Split recipe name into words
                        std::vector<std::string> recipeWords;
                        std::istringstream riss(recipe.normalizedName);
                        std::string rw;
                        while (riss >> rw) {
                            if (!rw.empty()) recipeWords.push_back(rw);
                        }

                        // For each search word, find the best matching recipe word
                        int totalDist = 0;
                        bool allMatched = true;
                        for (const auto& sw : searchWords) {
                            int bestWordDist = 999;
                            for (const auto& rwrd : recipeWords) {
                                int lenDiff = static_cast<int>(rwrd.length()) - static_cast<int>(sw.length());
                                if (lenDiff < -kLevenshteinMaxDistance || lenDiff > kLevenshteinMaxDistance) continue;
                                int d = StringUtils::LevenshteinDistance(sw, rwrd);
                                if (d < bestWordDist) bestWordDist = d;
                            }
                            if (bestWordDist > kLevenshteinMaxDistance) {
                                allMatched = false;
                                break;
                            }
                            totalDist += bestWordDist;
                        }

                        if (allMatched && (totalDist < bestTotalDist ||
                            (totalDist == bestTotalDist && recipe.normalizedName.length() < bestLen))) {
                            bestTotalDist = totalDist;
                            bestLen = recipe.normalizedName.length();
                            bestWordLev = &recipe;
                        }
                    });

                    if (bestWordLev && bestTotalDist <= kLevenshteinMaxTotalWordDist) {
                        SKSE::log::info("RecipeDB: Word-level Levenshtein match for '{}' -> '{}' (totalDist={})",
                            searchTerm, bestWordLev->name, bestTotalDist);
                        return bestWordLev;
                    }
                }
            }

            SKSE::log::info("RecipeDB: No match found for '{}' (category={})", searchTerm, (int)categoryFilter);
            return nullptr;
        }

        /**
         * Find a cooking recipe by name
         */
        const Recipe* FindCookingRecipe(const std::string& name) const
        {
            return FuzzySearch(name, RecipeCategory::Cooking);
        }

        /**
         * Check if a cooking recipe requires an oven (not a cooking pot)
         * Returns true if the recipe uses BYOHCraftingOven keyword
         */
        bool IsOvenRecipe(const std::string& name) const
        {
            const Recipe* recipe = FuzzySearch(name, RecipeCategory::Cooking);
            if (recipe) {
                return recipe->isOvenRecipe;
            }
            return false;
        }

        /**
         * Find a smithing recipe by name
         */
        const Recipe* FindSmithingRecipe(const std::string& name) const
        {
            return FuzzySearch(name, RecipeCategory::Smithing);
        }

        /**
         * Find a smelting recipe by name
         */
        const Recipe* FindSmeltingRecipe(const std::string& name) const
        {
            return FuzzySearch(name, RecipeCategory::Smelting);
        }

        /**
         * Get all recipes in a category
         */
        std::vector<const Recipe*> GetRecipesByCategory(RecipeCategory category) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            std::vector<const Recipe*> result;
            if (!m_initialized) return result;

            const std::vector<size_t>* list = GetCategoryList(category);
            if (list) {
                result.reserve(list->size());
                for (size_t idx : *list) {
                    result.push_back(&m_allRecipes[idx]);
                }
            }
            return result;
        }

        /**
         * Get the actual TESForm for a recipe's created item
         */
        RE::TESForm* GetCreatedItem(const Recipe* recipe) const
        {
            if (!recipe) return nullptr;
            return RE::TESForm::LookupByID(recipe->createdItemId);
        }

        // Statistics
        size_t GetCookingCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_cookingRecipes.size(); }
        size_t GetSmithingCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_smithingRecipes.size(); }
        size_t GetSmeltingCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_smeltingRecipes.size(); }
        size_t GetTanningCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_tanningRecipes.size(); }
        size_t GetTemperingCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_temperingRecipes.size(); }
        size_t GetTotalCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_allRecipes.size(); }
        bool IsInitialized() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_initialized; }

        // ============================================
        // Papyrus Native Function Wrappers
        // ============================================

        static RE::TESForm* Papyrus_FindCookingRecipe(RE::StaticFunctionTag*, RE::BSFixedString name)
        {
            if (!name.data()) return nullptr;
            const Recipe* recipe = GetInstance().FindCookingRecipe(name.data());
            return recipe ? GetInstance().GetCreatedItem(recipe) : nullptr;
        }

        static RE::TESForm* Papyrus_FindSmithingRecipe(RE::StaticFunctionTag*, RE::BSFixedString name)
        {
            if (!name.data()) return nullptr;
            const Recipe* recipe = GetInstance().FindSmithingRecipe(name.data());
            return recipe ? GetInstance().GetCreatedItem(recipe) : nullptr;
        }

        static RE::TESForm* Papyrus_FindSmeltingRecipe(RE::StaticFunctionTag*, RE::BSFixedString name)
        {
            if (!name.data()) return nullptr;
            const Recipe* recipe = GetInstance().FindSmeltingRecipe(name.data());
            return recipe ? GetInstance().GetCreatedItem(recipe) : nullptr;
        }

        static RE::BSFixedString Papyrus_GetRecipeDBStats(RE::StaticFunctionTag*)
        {
            auto& db = GetInstance();
            std::string stats = "Cooking: " + std::to_string(db.GetCookingCount()) +
                              ", Smithing: " + std::to_string(db.GetSmithingCount()) +
                              ", Smelting: " + std::to_string(db.GetSmeltingCount()) +
                              ", Tanning: " + std::to_string(db.GetTanningCount()) +
                              ", Tempering: " + std::to_string(db.GetTemperingCount());
            return stats.c_str();
        }

        static bool Papyrus_IsRecipeDBLoaded(RE::StaticFunctionTag*)
        {
            return GetInstance().IsInitialized();
        }

        static bool Papyrus_IsOvenRecipe(RE::StaticFunctionTag*, RE::BSFixedString name)
        {
            if (!name.data()) return false;
            return GetInstance().IsOvenRecipe(name.data());
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("FindCookingRecipe", scriptName, Papyrus_FindCookingRecipe);
            a_vm->RegisterFunction("FindSmithingRecipe", scriptName, Papyrus_FindSmithingRecipe);
            a_vm->RegisterFunction("FindSmeltingRecipe", scriptName, Papyrus_FindSmeltingRecipe);
            a_vm->RegisterFunction("GetRecipeDBStats", scriptName, Papyrus_GetRecipeDBStats);
            a_vm->RegisterFunction("IsRecipeDBLoaded", scriptName, Papyrus_IsRecipeDBLoaded);
            a_vm->RegisterFunction("IsOvenRecipe", scriptName, Papyrus_IsOvenRecipe);

            SKSE::log::info("Registered recipe database functions");
        }

    private:
        RecipeDB() = default;
        RecipeDB(const RecipeDB&) = delete;
        RecipeDB& operator=(const RecipeDB&) = delete;

        /**
         * Check if a workbench keyword is specifically the Hearthfire oven
         */
        bool IsOvenKeyword(RE::BGSKeyword* keyword) const
        {
            if (!keyword) return false;

            RE::FormID baseId = keyword->GetFormID() & 0x00FFFFFF;
            if (baseId == (WorkbenchKeywords::BYOHCraftingOven & 0x00FFFFFF)) {
                return true;
            }

            // Name fallback for modded ovens
            std::string kwName = keyword->GetFormEditorID();
            if (kwName.find("Oven") != std::string::npos && kwName.find("Cook") == std::string::npos) {
                return true;
            }

            return false;
        }

        RecipeCategory GetCategoryFromKeyword(RE::BGSKeyword* keyword) const
        {
            if (!keyword) return RecipeCategory::Unknown;

            RE::FormID kwId = keyword->GetFormID();

            // Mask off the mod index for comparison with base game FormIDs
            // Base game forms have indices 00-04, so we check the lower 24 bits
            RE::FormID baseId = kwId & 0x00FFFFFF;

            if (baseId == (WorkbenchKeywords::CraftingCookpot & 0x00FFFFFF) ||
                baseId == (WorkbenchKeywords::BYOHCraftingOven & 0x00FFFFFF)) {
                return RecipeCategory::Cooking;
            }
            if (baseId == (WorkbenchKeywords::CraftingSmithingForge & 0x00FFFFFF)) {
                return RecipeCategory::Smithing;
            }
            if (baseId == (WorkbenchKeywords::CraftingSmelter & 0x00FFFFFF)) {
                return RecipeCategory::Smelting;
            }
            if (baseId == (WorkbenchKeywords::CraftingTanningRack & 0x00FFFFFF)) {
                return RecipeCategory::Tanning;
            }
            if (baseId == (WorkbenchKeywords::CraftingSmithingSharpeningWheel & 0x00FFFFFF) ||
                baseId == (WorkbenchKeywords::CraftingSmithingArmorTable & 0x00FFFFFF)) {
                return RecipeCategory::Tempering;
            }

            // Check keyword name as fallback for modded workbenches
            std::string kwName = keyword->GetFormEditorID();
            if (kwName.find("Cookpot") != std::string::npos || kwName.find("Cook") != std::string::npos ||
                kwName.find("Oven") != std::string::npos) {
                return RecipeCategory::Cooking;
            }
            if (kwName.find("Forge") != std::string::npos || kwName.find("Smithing") != std::string::npos) {
                return RecipeCategory::Smithing;
            }
            if (kwName.find("Smelter") != std::string::npos) {
                return RecipeCategory::Smelting;
            }
            if (kwName.find("Tanning") != std::string::npos) {
                return RecipeCategory::Tanning;
            }

            return RecipeCategory::Unknown;
        }

        /**
         * Get the index list for a specific category
         */
        const std::vector<size_t>* GetCategoryList(RecipeCategory category) const
        {
            switch (category) {
                case RecipeCategory::Cooking:    return &m_cookingRecipes;
                case RecipeCategory::Smithing:   return &m_smithingRecipes;
                case RecipeCategory::Smelting:   return &m_smeltingRecipes;
                case RecipeCategory::Tanning:    return &m_tanningRecipes;
                case RecipeCategory::Tempering:  return &m_temperingRecipes;
                default: return nullptr;
            }
        }


        // Data storage
        std::vector<Recipe> m_allRecipes;
        std::vector<size_t> m_cookingRecipes;     // Indices into m_allRecipes
        std::vector<size_t> m_smithingRecipes;
        std::vector<size_t> m_smeltingRecipes;
        std::vector<size_t> m_tanningRecipes;
        std::vector<size_t> m_temperingRecipes;
        std::unordered_map<std::string, size_t> m_nameLookup;  // normalized name -> index
        bool m_initialized = false;
        mutable std::shared_mutex m_mutex;
    };
}
