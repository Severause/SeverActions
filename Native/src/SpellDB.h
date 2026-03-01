#pragma once

// SeverActionsNative - Spell Database
// Scans all SpellItem records at game load to build a native database
// for spell name resolution, fuzzy search, and spell teaching actions.
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <shared_mutex>
#include <sstream>
#include <string>
#include <map>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "StringUtils.h"

namespace SeverActionsNative
{
    // Represents a single castable spell in the database
    struct SpellEntry
    {
        std::string name;              // Display name
        std::string normalizedName;    // Lowercase for search
        RE::FormID formId;
        std::string school;            // "Destruction", "Restoration", etc. or "None"
        std::string spellTypeStr;      // "Spell", "Power", "LesserPower"
        std::string castingTypeStr;    // "FireAndForget", "Concentration", "ConstantEffect"
        std::string deliveryStr;       // "Self", "Contact", "Aimed", etc.
        bool isHostile;
        int difficulty;                // 0=Novice, 1=Apprentice, 2=Adept, 3=Expert, 4=Master
        int minimumSkillLevel;         // Raw from first effect's EffectSetting
    };

    /**
     * High-performance spell database
     *
     * Scans all SpellItem forms on kDataLoaded and builds categorized
     * lookup tables for instant fuzzy name resolution.
     * Filters to castable types only (Spell, Power, LesserPower).
     */
    class SpellDB
    {
    public:
        static SpellDB& GetInstance()
        {
            static SpellDB instance;
            return instance;
        }

        /**
         * Scan all SpellItem records and build the database.
         * Should be called on kDataLoaded event.
         */
        bool Initialize()
        {
            std::unique_lock<std::shared_mutex> lock(m_mutex);
            if (m_initialized) {
                SKSE::log::info("SpellDB: Already initialized, skipping");
                return true;
            }

            SKSE::log::info("SpellDB: Scanning spell items...");

            auto dataHandler = RE::TESDataHandler::GetSingleton();
            if (!dataHandler) {
                SKSE::log::error("SpellDB: Could not get TESDataHandler");
                return false;
            }

            // Clear any existing data
            m_allSpells.clear();
            m_destructionSpells.clear();
            m_restorationSpells.clear();
            m_alterationSpells.clear();
            m_illusionSpells.clear();
            m_conjurationSpells.clear();
            m_enchantingSpells.clear();
            m_otherSpells.clear();
            m_nameLookup.clear();
            m_formIdLookup.clear();

            // Get all spell items
            auto& spellArray = dataHandler->GetFormArray<RE::SpellItem>();

            int totalScanned = 0;
            int destruction = 0, restoration = 0, alteration = 0;
            int illusion = 0, conjuration = 0, enchanting = 0, other = 0;
            int filtered = 0;

            for (auto* spell : spellArray) {
                if (!spell) continue;
                totalScanned++;

                // Filter to castable spell types only
                if (!IsTeachableType(spell)) {
                    filtered++;
                    continue;
                }

                // Skip spells with no name
                const char* spellName = spell->GetName();
                if (!spellName || spellName[0] == '\0') continue;

                SpellEntry entry;
                entry.formId = spell->GetFormID();
                entry.name = spellName;
                entry.normalizedName = StringUtils::ToLower(entry.name);
                entry.school = DetectSchool(spell);
                entry.spellTypeStr = SpellTypeToString(spell->data.spellType);
                entry.castingTypeStr = CastingTypeToString(spell->data.castingType);
                entry.deliveryStr = DeliveryToString(spell->data.delivery);
                entry.isHostile = IsSpellHostile(spell);
                entry.minimumSkillLevel = GetMinimumSkillLevel(spell);
                entry.difficulty = SkillLevelToDifficulty(entry.minimumSkillLevel, spell);

                // Add to master list
                size_t index = m_allSpells.size();
                m_allSpells.push_back(std::move(entry));

                // Add to school-specific list
                const std::string& school = m_allSpells.back().school;
                if (school == "Destruction") { m_destructionSpells.push_back(index); destruction++; }
                else if (school == "Restoration") { m_restorationSpells.push_back(index); restoration++; }
                else if (school == "Alteration") { m_alterationSpells.push_back(index); alteration++; }
                else if (school == "Illusion") { m_illusionSpells.push_back(index); illusion++; }
                else if (school == "Conjuration") { m_conjurationSpells.push_back(index); conjuration++; }
                else if (school == "Enchanting") { m_enchantingSpells.push_back(index); enchanting++; }
                else { m_otherSpells.push_back(index); other++; }

                // Name lookup (prefer first found for duplicates)
                if (m_nameLookup.find(m_allSpells.back().normalizedName) == m_nameLookup.end()) {
                    m_nameLookup[m_allSpells.back().normalizedName] = index;
                }

                // FormID lookup for quick actor spell checks
                m_formIdLookup[m_allSpells.back().formId] = index;
            }

            m_initialized = true;

            // Release excess vector capacity
            m_allSpells.shrink_to_fit();
            m_destructionSpells.shrink_to_fit();
            m_restorationSpells.shrink_to_fit();
            m_alterationSpells.shrink_to_fit();
            m_illusionSpells.shrink_to_fit();
            m_conjurationSpells.shrink_to_fit();
            m_enchantingSpells.shrink_to_fit();
            m_otherSpells.shrink_to_fit();

            SKSE::log::info("SpellDB: Scanned {} spell records, filtered {} non-castable", totalScanned, filtered);
            SKSE::log::info("SpellDB: Indexed {} castable spells:", m_allSpells.size());
            SKSE::log::info("  - Destruction: {}", destruction);
            SKSE::log::info("  - Restoration: {}", restoration);
            SKSE::log::info("  - Alteration: {}", alteration);
            SKSE::log::info("  - Illusion: {}", illusion);
            SKSE::log::info("  - Conjuration: {}", conjuration);
            SKSE::log::info("  - Enchanting: {}", enchanting);
            SKSE::log::info("  - Other/None: {}", other);

            return true;
        }

        // ============================================
        // Lookup Functions
        // ============================================

        /**
         * Find a spell by exact name (case-insensitive)
         */
        const SpellEntry* FindByName(const std::string& name) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized) return nullptr;

            std::string normalized = StringUtils::ToLower(name);
            auto it = m_nameLookup.find(normalized);
            if (it != m_nameLookup.end()) {
                return &m_allSpells[it->second];
            }
            return nullptr;
        }

        /**
         * Multi-stage fuzzy search across all spells.
         *
         * Stages (in priority order):
         *   1. Exact match (case-insensitive)
         *   2. Prefix match — shorter names preferred
         *   3. Contains match (scored) — word boundary + shorter preferred
         *   4. Word match — all search words appear in name, any order
         *   5. Levenshtein distance <= 2 on full name
         *   5b. Levenshtein <= 2 per word (total <= 4)
         */
        const SpellEntry* FuzzySearch(const std::string& searchTerm) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized || searchTerm.empty()) return nullptr;

            std::string normalized = StringUtils::ToLower(searchTerm);

            // --- Stage 1: Exact match ---
            auto exactIt = m_nameLookup.find(normalized);
            if (exactIt != m_nameLookup.end()) {
                SKSE::log::info("SpellDB: Exact match '{}' -> '{}'", searchTerm, m_allSpells[exactIt->second].name);
                return &m_allSpells[exactIt->second];
            }

            // --- Stage 2: Prefix match ---
            {
                const SpellEntry* best = nullptr;
                size_t bestLen = 99999;
                for (const auto& spell : m_allSpells) {
                    if (spell.normalizedName.length() >= normalized.length() &&
                        spell.normalizedName.compare(0, normalized.length(), normalized) == 0) {
                        if (spell.normalizedName.length() < bestLen) {
                            bestLen = spell.normalizedName.length();
                            best = &spell;
                        }
                    }
                }
                if (best) {
                    SKSE::log::info("SpellDB: Prefix match '{}' -> '{}'", searchTerm, best->name);
                    return best;
                }
            }

            // --- Stage 3: Contains match (scored) ---
            {
                const SpellEntry* best = nullptr;
                int bestScore = -1;
                for (const auto& spell : m_allSpells) {
                    size_t pos = spell.normalizedName.find(normalized);
                    if (pos != std::string::npos) {
                        int score = kFuzzyBaseScore;
                        if (pos == 0) score += kFuzzyStartBonus;
                        else if (pos > 0 && spell.normalizedName[pos - 1] == ' ') score += kFuzzyWordBoundaryBonus;
                        score -= static_cast<int>(spell.normalizedName.length() - normalized.length());
                        if (score > bestScore) {
                            bestScore = score;
                            best = &spell;
                        }
                    }
                }
                if (best) {
                    SKSE::log::info("SpellDB: Contains match '{}' -> '{}' (score={})", searchTerm, best->name, bestScore);
                    return best;
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
                    const SpellEntry* best = nullptr;
                    size_t bestLen = 99999;
                    for (const auto& spell : m_allSpells) {
                        bool allFound = true;
                        for (const auto& w : searchWords) {
                            if (spell.normalizedName.find(w) == std::string::npos) {
                                allFound = false;
                                break;
                            }
                        }
                        if (allFound && spell.normalizedName.length() < bestLen) {
                            bestLen = spell.normalizedName.length();
                            best = &spell;
                        }
                    }
                    if (best) {
                        SKSE::log::info("SpellDB: Word match '{}' -> '{}'", searchTerm, best->name);
                        return best;
                    }
                }
            }

            // --- Stage 5: Levenshtein distance <= 2 on full name ---
            {
                const SpellEntry* best = nullptr;
                int bestDist = 999;
                size_t bestLen = 99999;
                for (const auto& spell : m_allSpells) {
                    int lenDiff = static_cast<int>(spell.normalizedName.length()) - static_cast<int>(normalized.length());
                    if (lenDiff < -kLevenshteinLengthTolerance || lenDiff > kLevenshteinLengthTolerance) continue;
                    int dist = StringUtils::LevenshteinDistance(normalized, spell.normalizedName);
                    if (dist <= kLevenshteinMaxDistance &&
                        (dist < bestDist || (dist == bestDist && spell.normalizedName.length() < bestLen))) {
                        bestDist = dist;
                        bestLen = spell.normalizedName.length();
                        best = &spell;
                    }
                }
                if (best) {
                    SKSE::log::info("SpellDB: Levenshtein match '{}' -> '{}' (distance={})", searchTerm, best->name, bestDist);
                    return best;
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
                    const SpellEntry* best = nullptr;
                    int bestTotalDist = 999;
                    size_t bestLen = 99999;

                    for (const auto& spell : m_allSpells) {
                        std::vector<std::string> spellWords;
                        std::istringstream riss(spell.normalizedName);
                        std::string rw;
                        while (riss >> rw) {
                            if (!rw.empty()) spellWords.push_back(rw);
                        }

                        int totalDist = 0;
                        bool allMatched = true;
                        for (const auto& sw : searchWords) {
                            int bestWordDist = 999;
                            for (const auto& spw : spellWords) {
                                int ld = static_cast<int>(spw.length()) - static_cast<int>(sw.length());
                                if (ld < -kLevenshteinMaxDistance || ld > kLevenshteinMaxDistance) continue;
                                int d = StringUtils::LevenshteinDistance(sw, spw);
                                if (d < bestWordDist) bestWordDist = d;
                            }
                            if (bestWordDist > kLevenshteinMaxDistance) { allMatched = false; break; }
                            totalDist += bestWordDist;
                        }

                        if (allMatched && (totalDist < bestTotalDist ||
                            (totalDist == bestTotalDist && spell.normalizedName.length() < bestLen))) {
                            bestTotalDist = totalDist;
                            bestLen = spell.normalizedName.length();
                            best = &spell;
                        }
                    }

                    if (best && bestTotalDist <= kLevenshteinMaxTotalWordDist) {
                        SKSE::log::info("SpellDB: Word-level Levenshtein match '{}' -> '{}' (totalDist={})",
                            searchTerm, best->name, bestTotalDist);
                        return best;
                    }
                }
            }

            SKSE::log::info("SpellDB: No match found for '{}'", searchTerm);
            return nullptr;
        }

        /**
         * Find a spell known by a specific actor using fuzzy name matching.
         * Uses the global spell database + actor->HasSpell() for verification.
         * This properly resolves spells from ALL sources: NPC record, templates,
         * race, and runtime additions.
         * Returns the SpellItem form if found, nullptr otherwise.
         */
        RE::SpellItem* FindSpellOnActor(RE::Actor* actor, const std::string& spellName) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized || !actor || spellName.empty()) return nullptr;

            std::string normalized = StringUtils::ToLower(spellName);

            // Strategy: fuzzy match against the global DB, then verify with HasSpell.
            // This handles NPCs with template-inherited spell lists that don't appear
            // in actorBase->actorEffects directly.

            RE::SpellItem* bestMatch = nullptr;
            int bestScore = -1;

            for (const auto& entry : m_allSpells) {
                int score = -1;

                // Stage 1: Exact match
                if (entry.normalizedName == normalized) {
                    score = 10000;
                }
                // Stage 2: Prefix match
                else if (entry.normalizedName.length() >= normalized.length() &&
                         entry.normalizedName.compare(0, normalized.length(), normalized) == 0) {
                    score = 5000 - static_cast<int>(entry.normalizedName.length());
                }
                // Stage 3: Contains match
                else {
                    size_t pos = entry.normalizedName.find(normalized);
                    if (pos != std::string::npos) {
                        score = kFuzzyBaseScore;
                        if (pos == 0) score += kFuzzyStartBonus;
                        else if (pos > 0 && entry.normalizedName[pos - 1] == ' ') score += kFuzzyWordBoundaryBonus;
                        score -= static_cast<int>(entry.normalizedName.length() - normalized.length());
                    }
                }
                // Stage 4: Levenshtein fallback
                if (score < 0) {
                    int lenDiff = static_cast<int>(entry.normalizedName.length()) - static_cast<int>(normalized.length());
                    if (lenDiff >= -kLevenshteinLengthTolerance && lenDiff <= kLevenshteinLengthTolerance) {
                        int dist = StringUtils::LevenshteinDistance(normalized, entry.normalizedName);
                        if (dist <= kLevenshteinMaxDistance) {
                            score = kLevenshteinMaxDistance - dist;
                        }
                    }
                }

                if (score <= bestScore) continue;

                // Verify the actor actually has this spell via engine's HasSpell
                // (resolves templates, race spells, and runtime additions)
                auto* spell = GetSpellItem(&entry);
                if (spell && actor->HasSpell(spell)) {
                    bestScore = score;
                    bestMatch = spell;
                    // Exact match — no need to keep searching
                    if (score >= 10000) break;
                }
            }

            if (bestMatch) {
                SKSE::log::info("SpellDB: Found '{}' on actor -> '{}' (score={})",
                    spellName, bestMatch->GetName(), bestScore);
            } else {
                SKSE::log::info("SpellDB: '{}' not found on actor", spellName);
            }

            return bestMatch;
        }

        /**
         * Get JSON of spells teacher knows that learner doesn't, grouped by school.
         * Uses the global DB + HasSpell() for both actors to properly resolve
         * template-inherited and race spells.
         * Output format: {"Destruction":[{"name":"Fireball","difficulty":2}], ...}
         */
        std::string GetTeachableSpells(RE::Actor* teacher, RE::Actor* learner) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_initialized || !teacher || !learner) return "{}";

            struct TeachableInfo {
                std::string name;
                int difficulty;
            };
            std::map<std::string, std::vector<TeachableInfo>> bySchool;

            // Iterate every spell in the global database.
            // Check: teacher has it AND learner doesn't.
            for (const auto& entry : m_allSpells) {
                auto* spell = GetSpellItem(&entry);
                if (!spell) continue;

                if (teacher->HasSpell(spell) && !learner->HasSpell(spell)) {
                    std::string school = (entry.school == "None") ? "Other" : entry.school;
                    bySchool[school].push_back({entry.name, entry.difficulty});
                }
            }

            // Build JSON output
            if (bySchool.empty()) return "{}";

            std::string json = "{";
            bool firstSchool = true;
            for (const auto& [school, spells] : bySchool) {
                if (!firstSchool) json += ",";
                firstSchool = false;
                json += "\"" + StringUtils::EscapeJson(school) + "\":[";
                bool firstSpell = true;
                for (const auto& sp : spells) {
                    if (!firstSpell) json += ",";
                    firstSpell = false;
                    json += "{\"name\":\"" + StringUtils::EscapeJson(sp.name) +
                            "\",\"difficulty\":" + std::to_string(sp.difficulty) + "}";
                }
                json += "]";
            }
            json += "}";

            return json;
        }

        /**
         * Get the actual SpellItem form for a database entry
         */
        RE::SpellItem* GetSpellItem(const SpellEntry* entry) const
        {
            if (!entry) return nullptr;
            auto* form = RE::TESForm::LookupByID(entry->formId);
            return form ? form->As<RE::SpellItem>() : nullptr;
        }

        // Statistics
        size_t GetDestructionCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_destructionSpells.size(); }
        size_t GetRestorationCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_restorationSpells.size(); }
        size_t GetAlterationCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_alterationSpells.size(); }
        size_t GetIllusionCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_illusionSpells.size(); }
        size_t GetConjurationCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_conjurationSpells.size(); }
        size_t GetTotalCount() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_allSpells.size(); }
        bool IsInitialized() const { std::shared_lock<std::shared_mutex> lock(m_mutex); return m_initialized; }

        // ============================================
        // Papyrus Native Function Wrappers
        // ============================================

        static bool Papyrus_IsSpellDBLoaded(RE::StaticFunctionTag*)
        {
            return GetInstance().IsInitialized();
        }

        static RE::TESForm* Papyrus_FindSpellByName(RE::StaticFunctionTag*, RE::BSFixedString spellName)
        {
            if (!spellName.data()) return nullptr;
            const SpellEntry* entry = GetInstance().FuzzySearch(spellName.data());
            return entry ? GetInstance().GetSpellItem(entry) : nullptr;
        }

        static RE::TESForm* Papyrus_FindSpellOnActor(RE::StaticFunctionTag*, RE::Actor* akActor, RE::BSFixedString spellName)
        {
            if (!akActor || !spellName.data()) return nullptr;
            return GetInstance().FindSpellOnActor(akActor, spellName.data());
        }

        static RE::BSFixedString Papyrus_GetTeachableSpells(RE::StaticFunctionTag*, RE::Actor* akTeacher, RE::Actor* akLearner)
        {
            if (!akTeacher || !akLearner) return "{}";
            return GetInstance().GetTeachableSpells(akTeacher, akLearner).c_str();
        }

        static RE::BSFixedString Papyrus_GetSpellDBStats(RE::StaticFunctionTag*)
        {
            auto& db = GetInstance();
            std::string stats = "Total: " + std::to_string(db.GetTotalCount()) +
                              " (Destruction: " + std::to_string(db.GetDestructionCount()) +
                              ", Restoration: " + std::to_string(db.GetRestorationCount()) +
                              ", Alteration: " + std::to_string(db.GetAlterationCount()) +
                              ", Illusion: " + std::to_string(db.GetIllusionCount()) +
                              ", Conjuration: " + std::to_string(db.GetConjurationCount()) + ")";
            return stats.c_str();
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("IsSpellDBLoaded", scriptName, Papyrus_IsSpellDBLoaded);
            a_vm->RegisterFunction("FindSpellByName", scriptName, Papyrus_FindSpellByName);
            a_vm->RegisterFunction("FindSpellOnActor", scriptName, Papyrus_FindSpellOnActor);
            a_vm->RegisterFunction("GetTeachableSpells", scriptName, Papyrus_GetTeachableSpells);
            a_vm->RegisterFunction("GetSpellDBStats", scriptName, Papyrus_GetSpellDBStats);

            SKSE::log::info("Registered spell database functions");
        }

    private:
        SpellDB() = default;
        SpellDB(const SpellDB&) = delete;
        SpellDB& operator=(const SpellDB&) = delete;

        // ============================================
        // Spell Classification Helpers
        // ============================================

        /**
         * Check if a spell type is teachable/castable.
         * Includes: Spell, Power, LesserPower
         * Excludes: Ability, Disease, Poison, Enchantment, Potion, VoicePower, etc.
         */
        static bool IsTeachableType(RE::SpellItem* spell)
        {
            if (!spell) return false;
            auto type = spell->data.spellType;
            return type == RE::MagicSystem::SpellType::kSpell ||
                   type == RE::MagicSystem::SpellType::kPower ||
                   type == RE::MagicSystem::SpellType::kLesserPower;
        }

        /**
         * Map ActorValue enum to school name string
         */
        static std::string ActorValueToSchool(RE::ActorValue av)
        {
            switch (av) {
                case RE::ActorValue::kDestruction: return "Destruction";
                case RE::ActorValue::kRestoration: return "Restoration";
                case RE::ActorValue::kAlteration: return "Alteration";
                case RE::ActorValue::kConjuration: return "Conjuration";
                case RE::ActorValue::kIllusion: return "Illusion";
                case RE::ActorValue::kEnchanting: return "Enchanting";
                default: return "None";
            }
        }

        /**
         * Detect the magic school for a spell.
         * Primary: spell->GetAssociatedSkill()
         * Fallback: first effect's base effect associated skill
         */
        static std::string DetectSchool(RE::SpellItem* spell)
        {
            if (!spell) return "None";

            // Primary: spell-level associated skill
            auto av = spell->GetAssociatedSkill();
            if (av != RE::ActorValue::kNone) {
                return ActorValueToSchool(av);
            }

            // Fallback: check first effect's base effect
            if (spell->effects.size() > 0 && spell->effects[0] && spell->effects[0]->baseEffect) {
                auto* eff = spell->effects[0]->baseEffect;
                auto effAV = eff->GetMagickSkill();
                if (effAV != RE::ActorValue::kNone) {
                    return ActorValueToSchool(effAV);
                }
            }

            return "None";
        }

        /**
         * Get the minimum skill level from the spell's first effect.
         * Returns 0 if not available.
         */
        static int GetMinimumSkillLevel(RE::SpellItem* spell)
        {
            if (!spell) return 0;
            if (spell->effects.size() > 0 && spell->effects[0] && spell->effects[0]->baseEffect) {
                return spell->effects[0]->baseEffect->data.minimumSkill;
            }
            return 0;
        }

        /**
         * Convert minimum skill level to difficulty tier.
         * Falls back to gold value if skill level is 0.
         */
        static int SkillLevelToDifficulty(int minSkill, RE::SpellItem* spell)
        {
            // Use minimum skill level if available
            if (minSkill > 0) {
                if (minSkill < 25) return 0;        // Novice
                else if (minSkill < 50) return 1;   // Apprentice
                else if (minSkill < 75) return 2;   // Adept
                else if (minSkill < 100) return 3;  // Expert
                else return 4;                      // Master
            }

            // Fallback to gold value (same tiers as SeverActions_SpellTeach.psc)
            if (spell) {
                int goldValue = spell->GetGoldValue();
                if (goldValue <= 50) return 0;
                else if (goldValue <= 150) return 1;
                else if (goldValue <= 350) return 2;
                else if (goldValue <= 700) return 3;
                else return 4;
            }

            return 0;
        }

        /**
         * Check if any of a spell's effects are hostile
         */
        static bool IsSpellHostile(RE::SpellItem* spell)
        {
            if (!spell) return false;
            for (auto* effect : spell->effects) {
                if (effect && effect->IsHostile()) return true;
            }
            return false;
        }

        static std::string SpellTypeToString(RE::MagicSystem::SpellType type)
        {
            switch (type) {
                case RE::MagicSystem::SpellType::kSpell: return "Spell";
                case RE::MagicSystem::SpellType::kPower: return "Power";
                case RE::MagicSystem::SpellType::kLesserPower: return "LesserPower";
                default: return "Unknown";
            }
        }

        static std::string CastingTypeToString(RE::MagicSystem::CastingType type)
        {
            switch (type) {
                case RE::MagicSystem::CastingType::kFireAndForget: return "FireAndForget";
                case RE::MagicSystem::CastingType::kConcentration: return "Concentration";
                case RE::MagicSystem::CastingType::kConstantEffect: return "ConstantEffect";
                default: return "Unknown";
            }
        }

        static std::string DeliveryToString(RE::MagicSystem::Delivery type)
        {
            switch (type) {
                case RE::MagicSystem::Delivery::kSelf: return "Self";
                case RE::MagicSystem::Delivery::kTouch: return "Touch";
                case RE::MagicSystem::Delivery::kAimed: return "Aimed";
                case RE::MagicSystem::Delivery::kTargetActor: return "TargetActor";
                case RE::MagicSystem::Delivery::kTargetLocation: return "TargetLocation";
                default: return "Unknown";
            }
        }

        // Data storage
        std::vector<SpellEntry> m_allSpells;
        std::vector<size_t> m_destructionSpells;     // Indices into m_allSpells
        std::vector<size_t> m_restorationSpells;
        std::vector<size_t> m_alterationSpells;
        std::vector<size_t> m_illusionSpells;
        std::vector<size_t> m_conjurationSpells;
        std::vector<size_t> m_enchantingSpells;
        std::vector<size_t> m_otherSpells;
        std::unordered_map<std::string, size_t> m_nameLookup;   // normalized name -> index
        std::unordered_map<RE::FormID, size_t> m_formIdLookup;  // FormID -> index
        bool m_initialized = false;
        mutable std::shared_mutex m_mutex;
    };
}
