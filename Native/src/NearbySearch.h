#pragma once

// SeverActionsNative - Nearby Object Search
// Optimized spatial queries replacing multiple PO3_SKSEFunctions calls
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <string>
#include <vector>
#include <algorithm>

#include "StringUtils.h"

namespace SeverActionsNative
{
    /**
     * Optimized nearby object searching
     *
     * Papyrus: 10+ sequential calls to FindAllReferencesOfFormType
     * Native: Single pass through nearby references with parallel type checking
     */
    class NearbySearch
    {
    public:
        /**
         * Find nearby item of a specific type (by name)
         * Replaces the cascading CheckFormType calls in Papyrus
         */
        static RE::TESObjectREFR* FindNearbyItemOfType(RE::Actor* actor, const std::string& itemType, float radius = 1000.0f)
        {
            if (!actor) return nullptr;

            std::string lowerType = StringUtils::ToLower(itemType);
            RE::TESObjectREFR* bestMatch = nullptr;
            float bestDistance = radius + 1.0f;

            auto* cell = actor->GetParentCell();
            if (!cell) return nullptr;

            auto pos = actor->GetPosition();

            // Process all references in the cell
            // Note: Lambda takes TESObjectREFR& not TESObjectREFR*
            cell->ForEachReferenceInRange(pos, radius, [&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                if (&ref == actor || ref.IsDisabled() || !ref.Is3DLoaded()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto baseObj = ref.GetBaseObject();
                if (!baseObj) return RE::BSContainer::ForEachResult::kContinue;

                // Check if this is an item type we care about
                if (!IsPickupableItem(baseObj)) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                // Check name match
                const char* name = baseObj->GetName();
                if (!name || name[0] == '\0') {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                std::string lowerName = StringUtils::ToLower(name);
                if (lowerName.find(lowerType) != std::string::npos) {
                    float dist = actor->GetPosition().GetDistance(ref.GetPosition());
                    if (dist < bestDistance) {
                        bestDistance = dist;
                        bestMatch = &ref;
                    }
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            return bestMatch;
        }

        /**
         * Find the nearest container of a specific type
         */
        static RE::TESObjectREFR* FindNearbyContainer(RE::Actor* actor, const std::string& containerType, float radius = 1000.0f)
        {
            if (!actor) return nullptr;

            std::string lowerType = StringUtils::ToLower(containerType);
            bool anyContainer = (lowerType.empty() || lowerType == "any");

            RE::TESObjectREFR* bestMatch = nullptr;
            float bestDistance = radius + 1.0f;

            auto* cell = actor->GetParentCell();
            if (!cell) return nullptr;

            auto pos = actor->GetPosition();

            cell->ForEachReferenceInRange(pos, radius, [&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                if (&ref == actor || ref.IsDisabled()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto baseObj = ref.GetBaseObject();
                if (!baseObj) return RE::BSContainer::ForEachResult::kContinue;

                // Check if it's a container
                if (!baseObj->As<RE::TESObjectCONT>()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                // Check if it has items
                if (ref.GetInventory().empty()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                // Check name match (if not "any")
                if (!anyContainer) {
                    const char* name = baseObj->GetName();
                    if (!name || name[0] == '\0') {
                        return RE::BSContainer::ForEachResult::kContinue;
                    }

                    std::string lowerName = StringUtils::ToLower(name);
                    if (lowerName.find(lowerType) == std::string::npos) {
                        return RE::BSContainer::ForEachResult::kContinue;
                    }
                }

                float dist = actor->GetPosition().GetDistance(ref.GetPosition());
                if (dist < bestDistance) {
                    bestDistance = dist;
                    bestMatch = &ref;
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            return bestMatch;
        }

        /**
         * Find the nearest forge/smithing station
         * Note: Forges in Skyrim can be TESFurniture OR TESObjectACTI (activators)
         */
        static RE::TESObjectREFR* FindNearbyForge(RE::Actor* actor, float radius = 2000.0f)
        {
            if (!actor) return nullptr;

            RE::TESObjectREFR* bestMatch = nullptr;
            float bestDistance = radius + 1.0f;

            auto* cell = actor->GetParentCell();
            if (!cell) return nullptr;

            auto pos = actor->GetPosition();

            // Get the forge keyword
            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            RE::BGSKeyword* forgeKeyword = nullptr;
            if (dataHandler) {
                forgeKeyword = dataHandler->LookupForm<RE::BGSKeyword>(0x00088105, "Skyrim.esm"); // CraftingSmithingForge
            }

            cell->ForEachReferenceInRange(pos, radius, [&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                if (&ref == actor || ref.IsDisabled() || !ref.Is3DLoaded()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto baseObj = ref.GetBaseObject();
                if (!baseObj) return RE::BSContainer::ForEachResult::kContinue;

                bool isForge = false;

                // Check if it's furniture with forge keyword
                auto furn = baseObj->As<RE::TESFurniture>();
                if (furn && forgeKeyword) {
                    isForge = furn->HasKeyword(forgeKeyword);
                }

                // Also check activators - many forges are activators, not furniture
                if (!isForge) {
                    auto acti = baseObj->As<RE::TESObjectACTI>();
                    if (acti && forgeKeyword) {
                        isForge = acti->HasKeyword(forgeKeyword);
                    }
                }

                // Check by name as fallback
                if (!isForge) {
                    const char* name = baseObj->GetName();
                    if (name) {
                        std::string lowerName = StringUtils::ToLower(name);
                        if (lowerName.find("forge") != std::string::npos ||
                            lowerName.find("anvil") != std::string::npos) {
                            isForge = true;
                        }
                    }
                }

                // Check by editor ID as final fallback
                if (!isForge) {
                    const char* editorId = baseObj->GetFormEditorID();
                    if (editorId) {
                        std::string lowerEditorId = StringUtils::ToLower(editorId);
                        if (lowerEditorId.find("forge") != std::string::npos ||
                            lowerEditorId.find("blacksmith") != std::string::npos ||
                            lowerEditorId.find("smithing") != std::string::npos) {
                            isForge = true;
                        }
                    }
                }

                if (isForge) {
                    float dist = actor->GetPosition().GetDistance(ref.GetPosition());
                    if (dist < bestDistance) {
                        bestDistance = dist;
                        bestMatch = &ref;
                    }
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            return bestMatch;
        }

        /**
         * Find the nearest cooking pot or oven
         * Note: Cooking pots/ovens can be TESFurniture OR TESObjectACTI
         */
        static RE::TESObjectREFR* FindNearbyCookingPot(RE::Actor* actor, float radius = 2000.0f)
        {
            if (!actor) return nullptr;

            RE::TESObjectREFR* bestMatch = nullptr;
            float bestDistance = radius + 1.0f;

            auto* cell = actor->GetParentCell();
            if (!cell) return nullptr;

            auto pos = actor->GetPosition();

            // Get cooking pot and oven keywords
            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            RE::BGSKeyword* cookpotKeyword = nullptr;
            RE::BGSKeyword* ovenKeyword = nullptr;
            if (dataHandler) {
                cookpotKeyword = dataHandler->LookupForm<RE::BGSKeyword>(0x000A5CB3, "Skyrim.esm"); // CraftingCookpot
                ovenKeyword = dataHandler->LookupForm<RE::BGSKeyword>(0x000117F7, "HearthFires.esm"); // BYOHCraftingOven
            }

            cell->ForEachReferenceInRange(pos, radius, [&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                if (&ref == actor || ref.IsDisabled() || !ref.Is3DLoaded()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto baseObj = ref.GetBaseObject();
                if (!baseObj) return RE::BSContainer::ForEachResult::kContinue;

                bool isCookingPot = false;

                // Check if it's furniture with cooking/oven keyword
                auto furn = baseObj->As<RE::TESFurniture>();
                if (furn) {
                    if (cookpotKeyword && furn->HasKeyword(cookpotKeyword)) {
                        isCookingPot = true;
                    }
                    if (!isCookingPot && ovenKeyword && furn->HasKeyword(ovenKeyword)) {
                        isCookingPot = true;
                    }
                }

                // Also check activators
                if (!isCookingPot) {
                    auto acti = baseObj->As<RE::TESObjectACTI>();
                    if (acti) {
                        if (cookpotKeyword && acti->HasKeyword(cookpotKeyword)) {
                            isCookingPot = true;
                        }
                        if (!isCookingPot && ovenKeyword && acti->HasKeyword(ovenKeyword)) {
                            isCookingPot = true;
                        }
                    }
                }

                // Check by name as fallback
                if (!isCookingPot) {
                    const char* name = baseObj->GetName();
                    if (name) {
                        std::string lowerName = StringUtils::ToLower(name);
                        if (lowerName.find("cooking") != std::string::npos ||
                            lowerName.find("cook pot") != std::string::npos ||
                            lowerName.find("cookpot") != std::string::npos ||
                            lowerName.find("spit") != std::string::npos ||
                            lowerName.find("oven") != std::string::npos) {
                            isCookingPot = true;
                        }
                    }
                }

                // Check by editor ID for unmarked pots
                if (!isCookingPot) {
                    const char* editorId = baseObj->GetFormEditorID();
                    if (editorId) {
                        std::string lowerEditorId = StringUtils::ToLower(editorId);
                        if (lowerEditorId.find("cooking") != std::string::npos ||
                            lowerEditorId.find("cookpot") != std::string::npos ||
                            lowerEditorId.find("spit") != std::string::npos ||
                            lowerEditorId.find("oven") != std::string::npos) {
                            isCookingPot = true;
                        }
                    }
                }

                if (isCookingPot) {
                    float dist = actor->GetPosition().GetDistance(ref.GetPosition());
                    if (dist < bestDistance) {
                        bestDistance = dist;
                        bestMatch = &ref;
                    }
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            return bestMatch;
        }

        /**
         * Find the nearest oven (Hearthfire BYOHCraftingOven only, NOT cooking pots)
         * Used for baked goods recipes that require an oven workstation
         */
        static RE::TESObjectREFR* FindNearbyOven(RE::Actor* actor, float radius = 2000.0f)
        {
            if (!actor) return nullptr;

            RE::TESObjectREFR* bestMatch = nullptr;
            float bestDistance = radius + 1.0f;

            auto* cell = actor->GetParentCell();
            if (!cell) return nullptr;

            auto pos = actor->GetPosition();

            // Get the oven keyword from HearthFires.esm
            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            RE::BGSKeyword* ovenKeyword = nullptr;
            if (dataHandler) {
                ovenKeyword = dataHandler->LookupForm<RE::BGSKeyword>(0x000117F7, "HearthFires.esm"); // BYOHCraftingOven
            }

            cell->ForEachReferenceInRange(pos, radius, [&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                if (&ref == actor || ref.IsDisabled() || !ref.Is3DLoaded()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto baseObj = ref.GetBaseObject();
                if (!baseObj) return RE::BSContainer::ForEachResult::kContinue;

                bool isOven = false;

                // Check if it's furniture with oven keyword
                auto furn = baseObj->As<RE::TESFurniture>();
                if (furn && ovenKeyword) {
                    isOven = furn->HasKeyword(ovenKeyword);
                }

                // Also check activators
                if (!isOven) {
                    auto acti = baseObj->As<RE::TESObjectACTI>();
                    if (acti && ovenKeyword) {
                        isOven = acti->HasKeyword(ovenKeyword);
                    }
                }

                // Check by name as fallback (for modded ovens without the keyword)
                if (!isOven) {
                    const char* name = baseObj->GetName();
                    if (name) {
                        std::string lowerName = StringUtils::ToLower(name);
                        if (lowerName.find("oven") != std::string::npos) {
                            isOven = true;
                        }
                    }
                }

                // Check by editor ID
                if (!isOven) {
                    const char* editorId = baseObj->GetFormEditorID();
                    if (editorId) {
                        std::string lowerEditorId = StringUtils::ToLower(editorId);
                        if (lowerEditorId.find("oven") != std::string::npos) {
                            isOven = true;
                        }
                    }
                }

                if (isOven) {
                    float dist = actor->GetPosition().GetDistance(ref.GetPosition());
                    if (dist < bestDistance) {
                        bestDistance = dist;
                        bestMatch = &ref;
                    }
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            return bestMatch;
        }

        /**
         * Find the nearest alchemy lab
         * Note: Alchemy labs can be TESFurniture OR TESObjectACTI
         */
        static RE::TESObjectREFR* FindNearbyAlchemyLab(RE::Actor* actor, float radius = 2000.0f)
        {
            if (!actor) return nullptr;

            RE::TESObjectREFR* bestMatch = nullptr;
            float bestDistance = radius + 1.0f;

            auto* cell = actor->GetParentCell();
            if (!cell) return nullptr;

            auto pos = actor->GetPosition();

            // Get the alchemy workbench keyword
            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            RE::BGSKeyword* alchemyKeyword = nullptr;
            if (dataHandler) {
                alchemyKeyword = dataHandler->LookupForm<RE::BGSKeyword>(0x0004F6E6, "Skyrim.esm"); // CraftingAlchemyWorkbench
            }

            cell->ForEachReferenceInRange(pos, radius, [&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                if (&ref == actor || ref.IsDisabled() || !ref.Is3DLoaded()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto baseObj = ref.GetBaseObject();
                if (!baseObj) return RE::BSContainer::ForEachResult::kContinue;

                bool isAlchemyLab = false;

                // Check if it's furniture with alchemy keyword
                auto furn = baseObj->As<RE::TESFurniture>();
                if (furn && alchemyKeyword) {
                    isAlchemyLab = furn->HasKeyword(alchemyKeyword);
                }

                // Also check activators
                if (!isAlchemyLab) {
                    auto acti = baseObj->As<RE::TESObjectACTI>();
                    if (acti && alchemyKeyword) {
                        isAlchemyLab = acti->HasKeyword(alchemyKeyword);
                    }
                }

                // Check by name as fallback
                if (!isAlchemyLab) {
                    const char* name = baseObj->GetName();
                    if (name) {
                        std::string lowerName = StringUtils::ToLower(name);
                        if (lowerName.find("alchemy") != std::string::npos ||
                            lowerName.find("alchemist") != std::string::npos) {
                            isAlchemyLab = true;
                        }
                    }
                }

                // Check by editor ID
                if (!isAlchemyLab) {
                    const char* editorId = baseObj->GetFormEditorID();
                    if (editorId) {
                        std::string lowerEditorId = StringUtils::ToLower(editorId);
                        if (lowerEditorId.find("alchemy") != std::string::npos) {
                            isAlchemyLab = true;
                        }
                    }
                }

                if (isAlchemyLab) {
                    float dist = actor->GetPosition().GetDistance(ref.GetPosition());
                    if (dist < bestDistance) {
                        bestDistance = dist;
                        bestMatch = &ref;
                    }
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            return bestMatch;
        }

        /**
         * Find the most "suspicious" item in a loaded cell near an actor.
         * Scores items by how incriminating they look as evidence:
         *   - Stolen items (ExtraOwnership mismatch): highest score
         *   - Poisons/Skooma: high score (illegal substances)
         *   - Lockpicks: high score
         *   - Weapons lying loose: medium score
         *   - Jewelry/gems: medium score (valuable = suspicious)
         *   - Books/notes: low-medium score (potential evidence)
         *   - High-value misc items: low score
         * Returns the highest-scoring item reference, or nullptr if nothing found.
         * Only works in loaded cells (guard + player present).
         */
        static RE::TESObjectREFR* FindSuspiciousItem(RE::Actor* actor, float radius = 2000.0f)
        {
            if (!actor) return nullptr;

            auto* cell = actor->GetParentCell();
            if (!cell) return nullptr;

            auto pos = actor->GetPosition();

            RE::TESObjectREFR* bestMatch = nullptr;
            int bestScore = 0;
            float bestDistance = radius + 1.0f;

            cell->ForEachReferenceInRange(pos, radius, [&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                if (&ref == actor || ref.IsDisabled() || !ref.Is3DLoaded()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto* baseObj = ref.GetBaseObject();
                if (!baseObj) return RE::BSContainer::ForEachResult::kContinue;

                // Must be a pickupable item
                if (!IsPickupableItem(baseObj)) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                // Must have a name
                const char* name = baseObj->GetName();
                if (!name || name[0] == '\0') {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                int score = 0;
                auto formType = baseObj->GetFormType();
                std::string lowerName = StringUtils::ToLower(name);

                // === Scoring ===

                // Stolen items: check ExtraOwnership — if owned by someone else, it's suspicious
                auto* ownerForm = ref.GetOwner();
                if (ownerForm) {
                    // Item has an owner — if the guard is searching someone else's home,
                    // any owned item that ISN'T the homeowner's is suspicious
                    score += 5;  // Base: owned items are notable
                }

                // Poisons and Skooma (illegal substances)
                if (formType == RE::FormType::AlchemyItem) {
                    auto* alchItem = baseObj->As<RE::AlchemyItem>();
                    if (alchItem) {
                        if (alchItem->IsPoison()) {
                            score += 30;  // Poisons are very suspicious
                        }
                        // Check for skooma/illegal substance by name
                        if (lowerName.find("skooma") != std::string::npos ||
                            lowerName.find("sleeping tree") != std::string::npos ||
                            lowerName.find("moon sugar") != std::string::npos ||
                            lowerName.find("redwater") != std::string::npos) {
                            score += 40;  // Drugs are extremely suspicious
                        }
                    }
                }

                // Lockpicks
                if (formType == RE::FormType::Misc) {
                    if (lowerName.find("lockpick") != std::string::npos) {
                        score += 25;  // Lockpicks = thief tools
                    }
                }

                // Weapons lying around in someone's home
                if (formType == RE::FormType::Weapon) {
                    auto* weapon = baseObj->As<RE::TESObjectWEAP>();
                    if (weapon) {
                        score += 10;  // Any loose weapon is noteworthy
                        // Daggers are more suspicious (assassination tools)
                        if (lowerName.find("dagger") != std::string::npos) {
                            score += 10;
                        }
                    }
                }

                // Jewelry and gems (valuable = motive)
                if (formType == RE::FormType::Armor) {
                    auto* armor = baseObj->As<RE::TESObjectARMO>();
                    if (armor) {
                        if (lowerName.find("ring") != std::string::npos ||
                            lowerName.find("necklace") != std::string::npos ||
                            lowerName.find("circlet") != std::string::npos ||
                            lowerName.find("amulet") != std::string::npos) {
                            score += 15;  // Jewelry is suspicious
                        }
                    }
                }

                // Soul gems (dark magic implications)
                if (formType == RE::FormType::SoulGem) {
                    score += 20;
                    if (lowerName.find("black") != std::string::npos) {
                        score += 15;  // Black soul gems = very dark
                    }
                }

                // Books and notes (evidence of correspondence)
                if (formType == RE::FormType::Book) {
                    score += 8;
                    // Look for suspicious book names
                    if (lowerName.find("letter") != std::string::npos ||
                        lowerName.find("note") != std::string::npos ||
                        lowerName.find("journal") != std::string::npos ||
                        lowerName.find("orders") != std::string::npos ||
                        lowerName.find("contract") != std::string::npos) {
                        score += 12;  // Written evidence
                    }
                }

                // Keys (access to places they shouldn't have)
                if (formType == RE::FormType::KeyMaster) {
                    score += 18;
                }

                // High gold value boosts score for any item
                auto* valueable = baseObj->As<RE::TESValueForm>();
                if (valueable && valueable->value > 100) {
                    score += 5;
                }
                if (valueable && valueable->value > 500) {
                    score += 10;
                }

                // Gems (misc items with gem-like names)
                if (formType == RE::FormType::Misc) {
                    if (lowerName.find("gem") != std::string::npos ||
                        lowerName.find("diamond") != std::string::npos ||
                        lowerName.find("ruby") != std::string::npos ||
                        lowerName.find("sapphire") != std::string::npos ||
                        lowerName.find("emerald") != std::string::npos ||
                        lowerName.find("amethyst") != std::string::npos ||
                        lowerName.find("garnet") != std::string::npos) {
                        score += 15;  // Gems are suspicious loot
                    }
                }

                // Only consider items with some suspicion score
                if (score > 0) {
                    float dist = actor->GetPosition().GetDistance(ref.GetPosition());
                    // Prefer higher score; break ties by distance
                    if (score > bestScore || (score == bestScore && dist < bestDistance)) {
                        bestScore = score;
                        bestDistance = dist;
                        bestMatch = &ref;
                    }
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            if (bestMatch) {
                SKSE::log::info("NearbySearch: FindSuspiciousItem - best match '{}' (score={}, dist={:.0f})",
                    bestMatch->GetBaseObject() ? bestMatch->GetBaseObject()->GetName() : "unknown",
                    bestScore, bestDistance);
            }

            return bestMatch;
        }

        /**
         * Generate a contextual evidence item for off-screen investigation.
         * When the guard searches a home while the player isn't there,
         * we can't scan loaded references. Instead, pick an appropriate
         * base form from the game's item data based on the target NPC's
         * class, factions, and name.
         *
         * Returns a TESBoundObject* base form (NOT a reference — caller does AddItem).
         * Returns nullptr if no suitable item can be determined.
         *
         * Categories:
         *   - Mage NPC → soul gem, scroll, or spell tome
         *   - Thief NPC → lockpick, jewel, or dagger
         *   - Warrior NPC → weapon or piece of armor
         *   - Merchant NPC → gold, jewel, or valuable misc
         *   - Default fallback → letter, note, or common potion
         */
        static RE::TESBoundObject* GenerateContextualEvidence(RE::Actor* targetNPC)
        {
            if (!targetNPC) return nullptr;

            auto* npc = targetNPC->GetActorBase();
            if (!npc) return nullptr;

            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            if (!dataHandler) return nullptr;

            // Determine NPC archetype from class
            enum class Archetype { Warrior, Mage, Thief, Merchant, Default };
            Archetype archetype = Archetype::Default;

            auto* npcClass = npc->npcClass;
            if (npcClass) {
                const char* className = npcClass->GetName();
                if (className) {
                    std::string lowerClass = StringUtils::ToLower(className);
                    if (lowerClass.find("mage") != std::string::npos ||
                        lowerClass.find("wizard") != std::string::npos ||
                        lowerClass.find("sorcerer") != std::string::npos ||
                        lowerClass.find("necromancer") != std::string::npos ||
                        lowerClass.find("conjurer") != std::string::npos ||
                        lowerClass.find("destruction") != std::string::npos ||
                        lowerClass.find("mystic") != std::string::npos ||
                        lowerClass.find("priest") != std::string::npos ||
                        lowerClass.find("hagraven") != std::string::npos) {
                        archetype = Archetype::Mage;
                    } else if (lowerClass.find("thief") != std::string::npos ||
                               lowerClass.find("assassin") != std::string::npos ||
                               lowerClass.find("bandit") != std::string::npos ||
                               lowerClass.find("nightblade") != std::string::npos ||
                               lowerClass.find("scout") != std::string::npos) {
                        archetype = Archetype::Thief;
                    } else if (lowerClass.find("warrior") != std::string::npos ||
                               lowerClass.find("soldier") != std::string::npos ||
                               lowerClass.find("knight") != std::string::npos ||
                               lowerClass.find("barbarian") != std::string::npos ||
                               lowerClass.find("guard") != std::string::npos) {
                        archetype = Archetype::Warrior;
                    } else if (lowerClass.find("merchant") != std::string::npos ||
                               lowerClass.find("vendor") != std::string::npos ||
                               lowerClass.find("trader") != std::string::npos ||
                               lowerClass.find("shopkeeper") != std::string::npos ||
                               lowerClass.find("innkeeper") != std::string::npos ||
                               lowerClass.find("bard") != std::string::npos) {
                        archetype = Archetype::Merchant;
                    }
                }
            }

            // Also check combat style as a fallback for archetype detection
            if (archetype == Archetype::Default) {
                auto* combatStyle = npc->GetCombatStyle();
                if (combatStyle) {
                    const char* csEditorId = combatStyle->GetFormEditorID();
                    if (csEditorId) {
                        std::string lowerCS = StringUtils::ToLower(csEditorId);
                        if (lowerCS.find("magic") != std::string::npos ||
                            lowerCS.find("mage") != std::string::npos) {
                            archetype = Archetype::Mage;
                        } else if (lowerCS.find("missile") != std::string::npos ||
                                   lowerCS.find("sneak") != std::string::npos ||
                                   lowerCS.find("assassin") != std::string::npos) {
                            archetype = Archetype::Thief;
                        }
                    }
                }
            }

            SKSE::log::info("NearbySearch: GenerateContextualEvidence - NPC '{}', archetype={}",
                npc->GetName() ? npc->GetName() : "unknown", static_cast<int>(archetype));

            // Use a simple pseudo-random based on NPC FormID to get variety
            uint32_t seed = npc->GetFormID();

            // Pick from hardcoded vanilla FormIDs based on archetype
            // These are all guaranteed to exist in Skyrim.esm
            struct EvidenceItem {
                RE::FormID formId;
                const char* plugin;
            };

            // Mage evidence: soul gems, scrolls
            static const EvidenceItem mageItems[] = {
                {0x0002E4E2, "Skyrim.esm"},  // Grand Soul Gem (empty)
                {0x0002E4F4, "Skyrim.esm"},  // Black Soul Gem (empty)
                {0x000A44AB, "Skyrim.esm"},  // Scroll of Fireball
                {0x000FF7F1, "Skyrim.esm"},  // Void Salts
                {0x0003AD5B, "Skyrim.esm"},  // Human Heart
                {0x0003AD61, "Skyrim.esm"},  // Daedra Heart
            };

            // Thief evidence: lockpicks, daggers, gems
            static const EvidenceItem thiefItems[] = {
                {0x0000000A, "Skyrim.esm"},  // Lockpick
                {0x0001397E, "Skyrim.esm"},  // Iron Dagger
                {0x00063B45, "Skyrim.esm"},  // Flawless Ruby
                {0x00063B46, "Skyrim.esm"},  // Flawless Sapphire
                {0x00068523, "Skyrim.esm"},  // Gold Ring
                {0x00063B42, "Skyrim.esm"},  // Flawless Diamond
            };

            // Warrior evidence: weapons, armor pieces
            static const EvidenceItem warriorItems[] = {
                {0x00013989, "Skyrim.esm"},  // Steel Sword
                {0x00013952, "Skyrim.esm"},  // Hide Shield
                {0x0001397E, "Skyrim.esm"},  // Iron Dagger
                {0x000139A1, "Skyrim.esm"},  // Steel Battleaxe
                {0x00013950, "Skyrim.esm"},  // Iron Helmet
                {0x00013948, "Skyrim.esm"},  // Iron Armor
            };

            // Merchant evidence: gems, gold, valuables
            static const EvidenceItem merchantItems[] = {
                {0x00063B45, "Skyrim.esm"},  // Flawless Ruby
                {0x00063B46, "Skyrim.esm"},  // Flawless Sapphire
                {0x00068523, "Skyrim.esm"},  // Gold Ring
                {0x00049828, "Skyrim.esm"},  // Gold Necklace
                {0x00063B42, "Skyrim.esm"},  // Flawless Diamond
                {0x00063B44, "Skyrim.esm"},  // Flawless Emerald
            };

            // Default/generic evidence: notes, potions, misc
            static const EvidenceItem defaultItems[] = {
                {0x0000000A, "Skyrim.esm"},  // Lockpick
                {0x00039BE5, "Skyrim.esm"},  // Potion of Healing
                {0x00063B45, "Skyrim.esm"},  // Flawless Ruby
                {0x0001397E, "Skyrim.esm"},  // Iron Dagger
                {0x0002E4E2, "Skyrim.esm"},  // Grand Soul Gem (empty)
                {0x00068523, "Skyrim.esm"},  // Gold Ring
            };

            const EvidenceItem* items = nullptr;
            size_t count = 0;

            switch (archetype) {
                case Archetype::Mage:
                    items = mageItems;
                    count = sizeof(mageItems) / sizeof(mageItems[0]);
                    break;
                case Archetype::Thief:
                    items = thiefItems;
                    count = sizeof(thiefItems) / sizeof(thiefItems[0]);
                    break;
                case Archetype::Warrior:
                    items = warriorItems;
                    count = sizeof(warriorItems) / sizeof(warriorItems[0]);
                    break;
                case Archetype::Merchant:
                    items = merchantItems;
                    count = sizeof(merchantItems) / sizeof(merchantItems[0]);
                    break;
                default:
                    items = defaultItems;
                    count = sizeof(defaultItems) / sizeof(defaultItems[0]);
                    break;
            }

            // Pick based on seed (NPC FormID) for deterministic but varied results
            size_t index = seed % count;
            auto& chosen = items[index];

            auto* form = dataHandler->LookupForm(chosen.formId, chosen.plugin);
            if (form) {
                auto* boundObj = form->As<RE::TESBoundObject>();
                if (boundObj) {
                    SKSE::log::info("NearbySearch: GenerateContextualEvidence - picked '{}' ({:08X}) for '{}'",
                        boundObj->GetName() ? boundObj->GetName() : "unknown",
                        boundObj->GetFormID(),
                        npc->GetName() ? npc->GetName() : "unknown");
                    return boundObj;
                }
            }

            // Absolute fallback: try lockpick
            form = dataHandler->LookupForm(0x0000000A, "Skyrim.esm");
            if (form) {
                return form->As<RE::TESBoundObject>();
            }

            return nullptr;
        }

        /**
         * Generate evidence based on the investigation reason string.
         * Uses keyword matching on the reason to pick thematically appropriate items.
         * Falls back to GenerateContextualEvidence(targetNPC) if no reason keywords match.
         *
         * Examples:
         *   "dibella worship" → Dibella statue, Amulet of Dibella
         *   "thieving" / "stolen goods" → lockpicks, gems, gold ring
         *   "skooma" / "moon sugar" → skooma, moon sugar
         *   "necromancy" / "dark magic" → black soul gem, human skull, bone meal
         *   "daedra" → daedra heart, void salts
         *   "poisoning" → various poisons, deathbell, nightshade
         *   "weapons" / "smuggling arms" → weapons
         */
        static RE::TESBoundObject* GenerateEvidenceForReason(const std::string& reason, RE::Actor* targetNPC)
        {
            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            if (!dataHandler) return nullptr;

            std::string lowerReason = StringUtils::ToLower(reason);

            struct EvidenceItem {
                RE::FormID formId;
                const char* plugin;
            };

            // ---- Keyword → item table mapping ----

            // Dibella / religion
            static const EvidenceItem dibellaItems[] = {
                {0x000731E1, "Skyrim.esm"},  // Amulet of Dibella
                {0x000D992E, "Skyrim.esm"},  // Dibella Statue (misc item)
                {0x000877C7, "Skyrim.esm"},  // The Lusty Argonian Maid
                {0x000F5CB6, "Skyrim.esm"},  // Amulet of Dibella (temple)
            };

            // Talos worship (banned in the Empire)
            static const EvidenceItem talosItems[] = {
                {0x000CC846, "Skyrim.esm"},  // Amulet of Talos
                {0x000F257E, "Skyrim.esm"},  // Talos Shrine (misc)
            };

            // Thieving / stolen goods / burglary
            static const EvidenceItem thievingItems[] = {
                {0x0000000A, "Skyrim.esm"},  // Lockpick
                {0x00063B45, "Skyrim.esm"},  // Flawless Ruby
                {0x00063B46, "Skyrim.esm"},  // Flawless Sapphire
                {0x00063B42, "Skyrim.esm"},  // Flawless Diamond
                {0x00068523, "Skyrim.esm"},  // Gold Ring
                {0x00049828, "Skyrim.esm"},  // Gold Necklace
            };

            // Skooma / drugs / moon sugar
            static const EvidenceItem skoomaItems[] = {
                {0x00057A7A, "Skyrim.esm"},  // Skooma
                {0x00065C9E, "Skyrim.esm"},  // Double-Distilled Skooma
                {0x0003AD60, "Skyrim.esm"},  // Moon Sugar
            };

            // Necromancy / dark magic / undead
            static const EvidenceItem necromancyItems[] = {
                {0x0002E4F4, "Skyrim.esm"},  // Black Soul Gem (empty)
                {0x0003AD5B, "Skyrim.esm"},  // Human Heart
                {0x00034CDD, "Skyrim.esm"},  // Bone Meal
                {0x0003AD64, "Skyrim.esm"},  // Human Flesh
                {0x000FF7F1, "Skyrim.esm"},  // Void Salts
            };

            // Daedra worship / daedric
            static const EvidenceItem daedraItems[] = {
                {0x0003AD61, "Skyrim.esm"},  // Daedra Heart
                {0x000FF7F1, "Skyrim.esm"},  // Void Salts
                {0x0003AD5E, "Skyrim.esm"},  // Fire Salts
                {0x0003AD60, "Skyrim.esm"},  // Moon Sugar (used in rituals)
                {0x0002E4F4, "Skyrim.esm"},  // Black Soul Gem (empty)
            };

            // Poisoning / alchemy crimes
            static const EvidenceItem poisonItems[] = {
                {0x00065A63, "Skyrim.esm"},  // Poison of Lingering Damage Health
                {0x0003AD5F, "Skyrim.esm"},  // Nightshade
                {0x000516C8, "Skyrim.esm"},  // Deathbell
                {0x00063B5F, "Skyrim.esm"},  // Jarrin Root (if available)
                {0x0003AD56, "Skyrim.esm"},  // Imp Stool
            };

            // Weapons smuggling / illegal arms
            static const EvidenceItem weaponItems[] = {
                {0x000139A1, "Skyrim.esm"},  // Steel Battleaxe
                {0x00013989, "Skyrim.esm"},  // Steel Sword
                {0x00013986, "Skyrim.esm"},  // Steel Greatsword
                {0x0001397E, "Skyrim.esm"},  // Iron Dagger
                {0x000139A5, "Skyrim.esm"},  // Steel War Axe
            };

            // Vampire / vampirism
            static const EvidenceItem vampireItems[] = {
                {0x0003AD5B, "Skyrim.esm"},  // Human Heart
                {0x0003AD64, "Skyrim.esm"},  // Human Flesh
                {0x0002E4F4, "Skyrim.esm"},  // Black Soul Gem (empty)
                {0x00034CDD, "Skyrim.esm"},  // Bone Meal
            };

            // Forsworn / hagravens / old gods
            static const EvidenceItem forswornItems[] = {
                {0x0003AD5B, "Skyrim.esm"},  // Human Heart
                {0x000A9198, "Skyrim.esm"},  // Briar Heart
                {0x0003AD5E, "Skyrim.esm"},  // Fire Salts
                {0x000727DE, "Skyrim.esm"},  // Hagraven Feathers
                {0x000727E0, "Skyrim.esm"},  // Hagraven Claw
            };

            // Keyword matching — try each category
            struct ReasonMapping {
                const char** keywords;
                size_t keywordCount;
                const EvidenceItem* items;
                size_t itemCount;
            };

            // Dibella
            static const char* dibellaKeywords[] = {"dibella", "lust", "promiscui", "indecen"};
            // Talos
            static const char* talosKeywords[] = {"talos", "heresy", "heretic", "stormcloak worship"};
            // Thieving
            static const char* thievingKeywords[] = {"thiev", "steal", "stolen", "burgl", "robbery", "larcen", "pickpocket", "fence"};
            // Skooma
            static const char* skoomaKeywords[] = {"skooma", "moon sugar", "drug", "narcotic", "smuggl"};
            // Necromancy
            static const char* necroKeywords[] = {"necromancy", "necromancer", "undead", "reanimate", "dark magic", "raise dead", "soul trap"};
            // Daedra
            static const char* daedraKeywords[] = {"daedra", "daedric", "oblivion", "dremora", "molag", "mehrunes", "namira", "boethia", "sanguine", "nocturnal", "hircine", "vaermina"};
            // Poison
            static const char* poisonKeywords[] = {"poison", "toxin", "venom", "assassin"};
            // Weapons
            static const char* weaponKeywords[] = {"weapon", "smuggl", "arms deal", "illegal arms", "contraband weapon"};
            // Vampire
            static const char* vampireKeywords[] = {"vampire", "vampir", "blood ritual", "undeath"};
            // Forsworn
            static const char* forswornKeywords[] = {"forsworn", "hagraven", "old gods", "briar"};

            // Build mappings array
            struct CategoryMapping {
                const char* const* keywords;
                size_t keywordCount;
                const EvidenceItem* items;
                size_t itemCount;
            };

            static const CategoryMapping categories[] = {
                {dibellaKeywords,   sizeof(dibellaKeywords) / sizeof(dibellaKeywords[0]),     dibellaItems,    sizeof(dibellaItems) / sizeof(dibellaItems[0])},
                {talosKeywords,     sizeof(talosKeywords) / sizeof(talosKeywords[0]),         talosItems,      sizeof(talosItems) / sizeof(talosItems[0])},
                {thievingKeywords,  sizeof(thievingKeywords) / sizeof(thievingKeywords[0]),   thievingItems,   sizeof(thievingItems) / sizeof(thievingItems[0])},
                {skoomaKeywords,    sizeof(skoomaKeywords) / sizeof(skoomaKeywords[0]),       skoomaItems,     sizeof(skoomaItems) / sizeof(skoomaItems[0])},
                {necroKeywords,     sizeof(necroKeywords) / sizeof(necroKeywords[0]),         necromancyItems, sizeof(necromancyItems) / sizeof(necromancyItems[0])},
                {daedraKeywords,    sizeof(daedraKeywords) / sizeof(daedraKeywords[0]),       daedraItems,     sizeof(daedraItems) / sizeof(daedraItems[0])},
                {poisonKeywords,    sizeof(poisonKeywords) / sizeof(poisonKeywords[0]),       poisonItems,     sizeof(poisonItems) / sizeof(poisonItems[0])},
                {weaponKeywords,    sizeof(weaponKeywords) / sizeof(weaponKeywords[0]),       weaponItems,     sizeof(weaponItems) / sizeof(weaponItems[0])},
                {vampireKeywords,   sizeof(vampireKeywords) / sizeof(vampireKeywords[0]),     vampireItems,    sizeof(vampireItems) / sizeof(vampireItems[0])},
                {forswornKeywords,  sizeof(forswornKeywords) / sizeof(forswornKeywords[0]),   forswornItems,   sizeof(forswornItems) / sizeof(forswornItems[0])},
            };

            // Search for first matching category
            for (const auto& cat : categories) {
                for (size_t k = 0; k < cat.keywordCount; k++) {
                    if (lowerReason.find(cat.keywords[k]) != std::string::npos) {
                        // Found a match — pick a random item from this category
                        // Use a seed based on reason + target NPC for variety
                        uint32_t seed = 0;
                        for (char c : lowerReason) seed = seed * 31 + static_cast<uint32_t>(c);
                        if (targetNPC) {
                            auto* npc = targetNPC->GetActorBase();
                            if (npc) seed ^= npc->GetFormID();
                        }
                        size_t index = seed % cat.itemCount;
                        auto& chosen = cat.items[index];

                        auto* form = dataHandler->LookupForm(chosen.formId, chosen.plugin);
                        if (form) {
                            auto* boundObj = form->As<RE::TESBoundObject>();
                            if (boundObj) {
                                SKSE::log::info("NearbySearch: GenerateEvidenceForReason - reason='{}', matched keyword='{}', picked '{}' ({:08X})",
                                    reason, cat.keywords[k],
                                    boundObj->GetName() ? boundObj->GetName() : "unknown",
                                    boundObj->GetFormID());
                                return boundObj;
                            }
                        }
                        // If form lookup failed, continue to try other items in same category
                        for (size_t i = 0; i < cat.itemCount; i++) {
                            if (i == index) continue;
                            form = dataHandler->LookupForm(cat.items[i].formId, cat.items[i].plugin);
                            if (form) {
                                auto* boundObj = form->As<RE::TESBoundObject>();
                                if (boundObj) return boundObj;
                            }
                        }
                    }
                }
            }

            SKSE::log::info("NearbySearch: GenerateEvidenceForReason - no keyword match for reason '{}', falling back to NPC class", reason);

            // No keyword match — fall back to NPC class-based evidence
            if (targetNPC) {
                return GenerateContextualEvidence(targetNPC);
            }

            return nullptr;
        }

        /**
         * Get direction string from actor to target
         */
        static std::string GetDirectionString(RE::Actor* actor, RE::TESObjectREFR* target)
        {
            if (!actor || !target) return "unknown";

            // GetHeadingAngle takes NiPoint3, not TESObjectREFR*
            float heading = actor->GetHeadingAngle(target->GetPosition(), false);

            if (heading > -45.0f && heading < 45.0f) {
                return "ahead";
            } else if (heading >= 45.0f && heading < 135.0f) {
                return "to the right";
            } else if (heading <= -45.0f && heading > -135.0f) {
                return "to the left";
            } else {
                return "behind";
            }
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static RE::TESObjectREFR* Papyrus_FindNearbyItemOfType(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString itemType, float radius)
        {
            if (!actor || !itemType.data()) return nullptr;
            return FindNearbyItemOfType(actor, itemType.data(), radius);
        }

        static RE::TESObjectREFR* Papyrus_FindNearbyContainer(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString containerType, float radius)
        {
            if (!actor) return nullptr;
            std::string type = containerType.data() ? containerType.data() : "";
            return FindNearbyContainer(actor, type, radius);
        }

        static RE::TESObjectREFR* Papyrus_FindNearbyForge(RE::StaticFunctionTag*, RE::Actor* actor, float radius)
        {
            if (!actor) return nullptr;
            return FindNearbyForge(actor, radius);
        }

        static RE::TESObjectREFR* Papyrus_FindNearbyCookingPot(RE::StaticFunctionTag*, RE::Actor* actor, float radius)
        {
            if (!actor) return nullptr;
            return FindNearbyCookingPot(actor, radius);
        }

        static RE::TESObjectREFR* Papyrus_FindNearbyOven(RE::StaticFunctionTag*, RE::Actor* actor, float radius)
        {
            if (!actor) return nullptr;
            return FindNearbyOven(actor, radius);
        }

        static RE::TESObjectREFR* Papyrus_FindNearbyAlchemyLab(RE::StaticFunctionTag*, RE::Actor* actor, float radius)
        {
            if (!actor) return nullptr;
            return FindNearbyAlchemyLab(actor, radius);
        }

        static RE::BSFixedString Papyrus_GetDirectionString(RE::StaticFunctionTag*, RE::Actor* actor, RE::TESObjectREFR* target)
        {
            return GetDirectionString(actor, target).c_str();
        }

        static RE::TESObjectREFR* Papyrus_FindSuspiciousItem(RE::StaticFunctionTag*, RE::Actor* actor, float radius)
        {
            if (!actor) return nullptr;
            return FindSuspiciousItem(actor, radius);
        }

        static RE::TESForm* Papyrus_GenerateContextualEvidence(RE::StaticFunctionTag*, RE::Actor* targetNPC)
        {
            if (!targetNPC) return nullptr;
            return GenerateContextualEvidence(targetNPC);
        }

        static RE::TESForm* Papyrus_GenerateEvidenceForReason(RE::StaticFunctionTag*, RE::BSFixedString reason, RE::Actor* targetNPC)
        {
            std::string reasonStr = reason.data() ? reason.data() : "";
            return GenerateEvidenceForReason(reasonStr, targetNPC);
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("FindNearbyItemOfType", scriptName, Papyrus_FindNearbyItemOfType);
            a_vm->RegisterFunction("FindNearbyContainer", scriptName, Papyrus_FindNearbyContainer);
            a_vm->RegisterFunction("FindNearbyForge", scriptName, Papyrus_FindNearbyForge);
            a_vm->RegisterFunction("FindNearbyCookingPot", scriptName, Papyrus_FindNearbyCookingPot);
            a_vm->RegisterFunction("FindNearbyOven", scriptName, Papyrus_FindNearbyOven);
            a_vm->RegisterFunction("FindNearbyAlchemyLab", scriptName, Papyrus_FindNearbyAlchemyLab);
            a_vm->RegisterFunction("GetDirectionString", scriptName, Papyrus_GetDirectionString);
            a_vm->RegisterFunction("FindSuspiciousItem", scriptName, Papyrus_FindSuspiciousItem);
            a_vm->RegisterFunction("GenerateContextualEvidence", scriptName, Papyrus_GenerateContextualEvidence);
            a_vm->RegisterFunction("GenerateEvidenceForReason", scriptName, Papyrus_GenerateEvidenceForReason);

            SKSE::log::info("Registered nearby search functions (including evidence collection)");
        }

    private:
        /**
         * Check if a base object is a pickupable item
         */
        static bool IsPickupableItem(RE::TESBoundObject* obj)
        {
            if (!obj) return false;

            // Check form type
            switch (obj->GetFormType()) {
                case RE::FormType::Weapon:
                case RE::FormType::Armor:
                case RE::FormType::AlchemyItem:
                case RE::FormType::Book:
                case RE::FormType::Ingredient:
                case RE::FormType::Scroll:
                case RE::FormType::Ammo:
                case RE::FormType::KeyMaster:
                case RE::FormType::SoulGem:
                case RE::FormType::Misc:
                    return true;
                default:
                    return false;
            }
        }
    };
}
