#pragma once

// SeverActionsNative - Inventory Utility Functions
// Fast inventory searching and item operations
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <sstream>
#include <string>
#include <vector>

#include "StringUtils.h"

namespace SeverActionsNative
{
    /**
     * High-performance inventory utilities
     *
     * Papyrus: O(n) loop with GetNthForm + type casts + string comparisons
     * Native: Direct container access with type filtering
     */
    class InventoryUtils
    {
    public:
        /**
         * Find an item in an actor's inventory by name (case-insensitive)
         * Much faster than Papyrus GetNthForm loop
         *
         * GetInventory returns: std::map<TESBoundObject*, pair<int32_t, unique_ptr<InventoryEntryData>>>
         * where pair.first is count, pair.second is entry data
         */
        static RE::TESForm* FindItemByName(RE::Actor* actor, const std::string& itemName)
        {
            if (!actor || itemName.empty()) return nullptr;

            std::string lowerSearch = StringUtils::ToLower(itemName);
            auto inventory = actor->GetInventory();

            for (const auto& [form, data] : inventory) {
                if (!form) continue;
                // data.first is count
                if (data.first <= 0) continue;

                const char* formName = form->GetName();
                if (!formName || formName[0] == '\0') continue;

                std::string lowerName = StringUtils::ToLower(formName);
                if (lowerName.find(lowerSearch) != std::string::npos) {
                    return form;
                }
            }

            return nullptr;
        }

        /**
         * Find an item in a container by name
         */
        static RE::TESForm* FindItemInContainer(RE::TESObjectREFR* container, const std::string& itemName)
        {
            if (!container || itemName.empty()) return nullptr;

            std::string lowerSearch = StringUtils::ToLower(itemName);
            auto inventory = container->GetInventory();

            for (const auto& [form, data] : inventory) {
                if (!form) continue;
                if (data.first <= 0) continue;

                const char* formName = form->GetName();
                if (!formName || formName[0] == '\0') continue;

                std::string lowerName = StringUtils::ToLower(formName);
                if (lowerName.find(lowerSearch) != std::string::npos) {
                    return form;
                }
            }

            return nullptr;
        }

        /**
         * Check if actor has item by name
         */
        static bool ActorHasItemByName(RE::Actor* actor, const std::string& itemName)
        {
            return FindItemByName(actor, itemName) != nullptr;
        }

        /**
         * Find a currently worn/equipped item by name (case-insensitive substring)
         * Uses InventoryChanges entryList with IsWorn() check — much faster than
         * iterating 18 armor slots in Papyrus with GetWornForm + string comparisons
         *
         * Also checks equipped weapons (right and left hand)
         */
        static RE::TESForm* FindWornItemByName(RE::Actor* actor, const std::string& itemName)
        {
            if (!actor || itemName.empty()) return nullptr;

            std::string lowerSearch = StringUtils::ToLower(itemName);

            // Check worn armor/clothing via InventoryChanges
            auto* invChanges = actor->GetInventoryChanges();
            if (invChanges && invChanges->entryList) {
                for (auto* entry : *invChanges->entryList) {
                    if (!entry || !entry->IsWorn()) continue;

                    // Access 'object' member directly to avoid Windows GetObject macro conflict
                    auto* obj = entry->object;
                    if (!obj) continue;

                    const char* formName = obj->GetName();
                    if (!formName || formName[0] == '\0') continue;

                    std::string lowerName = StringUtils::ToLower(formName);
                    if (lowerName.find(lowerSearch) != std::string::npos) {
                        return obj;
                    }
                }
            }

            // Check equipped weapons (right hand, then left hand)
            for (bool leftHand : {false, true}) {
                auto* equipped = actor->GetEquippedObject(leftHand);
                if (!equipped) continue;

                const char* formName = equipped->GetName();
                if (!formName || formName[0] == '\0') continue;

                std::string lowerName = StringUtils::ToLower(formName);
                if (lowerName.find(lowerSearch) != std::string::npos) {
                    return equipped;
                }
            }

            return nullptr;
        }

        /**
         * Equip multiple items from inventory by comma-separated name list
         * Splits the string, searches inventory for each item, equips via ActorEquipManager
         * Single Papyrus→C++ crossing for batch operations
         * Returns count of items successfully equipped
         */
        static int32_t EquipItemsByName(RE::Actor* actor, const std::string& itemNames)
        {
            if (!actor || itemNames.empty()) return 0;

            auto* equipManager = RE::ActorEquipManager::GetSingleton();
            if (!equipManager) return 0;

            // Get inventory once — reuse for all searches
            auto inventory = actor->GetInventory();
            int32_t equippedCount = 0;

            // Split by comma and process each item
            std::istringstream stream(itemNames);
            std::string token;
            while (std::getline(stream, token, ',')) {
                // Trim whitespace
                size_t start = token.find_first_not_of(" \t");
                size_t end = token.find_last_not_of(" \t");
                if (start == std::string::npos) continue;
                std::string trimmed = token.substr(start, end - start + 1);
                if (trimmed.empty()) continue;

                std::string lowerSearch = StringUtils::ToLower(trimmed);

                // Search inventory for match
                for (const auto& [form, data] : inventory) {
                    if (!form || data.first <= 0) continue;

                    const char* formName = form->GetName();
                    if (!formName || formName[0] == '\0') continue;

                    std::string lowerName = StringUtils::ToLower(formName);
                    if (lowerName.find(lowerSearch) != std::string::npos) {
                        equipManager->EquipObject(actor, form);
                        equippedCount++;
                        SKSE::log::trace("EquipItemsByName: Equipped '{}'", formName);
                        break;  // Found match for this token, move to next
                    }
                }
            }

            SKSE::log::info("EquipItemsByName: Equipped {} items on {}",
                equippedCount, actor->GetName());
            return equippedCount;
        }

        /**
         * Unequip multiple worn items by comma-separated name list
         * Splits the string, searches worn items for each, unequips via ActorEquipManager
         * Returns count of items successfully unequipped
         */
        static int32_t UnequipItemsByName(RE::Actor* actor, const std::string& itemNames)
        {
            if (!actor || itemNames.empty()) return 0;

            auto* equipManager = RE::ActorEquipManager::GetSingleton();
            if (!equipManager) return 0;

            int32_t unequippedCount = 0;

            // Split by comma and process each item
            std::istringstream stream(itemNames);
            std::string token;
            while (std::getline(stream, token, ',')) {
                // Trim whitespace
                size_t start = token.find_first_not_of(" \t");
                size_t end = token.find_last_not_of(" \t");
                if (start == std::string::npos) continue;
                std::string trimmed = token.substr(start, end - start + 1);
                if (trimmed.empty()) continue;

                std::string lowerSearch = StringUtils::ToLower(trimmed);

                // Search worn items via InventoryChanges
                auto* invChanges = actor->GetInventoryChanges();
                if (invChanges && invChanges->entryList) {
                    bool found = false;
                    for (auto* entry : *invChanges->entryList) {
                        if (!entry || !entry->IsWorn()) continue;

                        auto* obj = entry->object;
                        if (!obj) continue;

                        const char* formName = obj->GetName();
                        if (!formName || formName[0] == '\0') continue;

                        std::string lowerName = StringUtils::ToLower(formName);
                        if (lowerName.find(lowerSearch) != std::string::npos) {
                            equipManager->UnequipObject(actor, obj);
                            unequippedCount++;
                            SKSE::log::trace("UnequipItemsByName: Unequipped '{}'", formName);
                            found = true;
                            break;
                        }
                    }
                    if (found) continue;
                }

                // Check equipped weapons
                for (bool leftHand : {false, true}) {
                    auto* equipped = actor->GetEquippedObject(leftHand);
                    if (!equipped) continue;

                    const char* formName = equipped->GetName();
                    if (!formName || formName[0] == '\0') continue;

                    std::string lowerName = StringUtils::ToLower(formName);
                    if (lowerName.find(lowerSearch) != std::string::npos) {
                        auto* boundObj = equipped->As<RE::TESBoundObject>();
                        if (boundObj) {
                            equipManager->UnequipObject(actor, boundObj);
                            unequippedCount++;
                            SKSE::log::trace("UnequipItemsByName: Unequipped weapon '{}'", formName);
                        }
                        break;
                    }
                }
            }

            SKSE::log::info("UnequipItemsByName: Unequipped {} items from {}",
                unequippedCount, actor->GetName());
            return unequippedCount;
        }

        /**
         * Get the gold value of any form
         * Replaces the Papyrus type-checking cascade
         */
        static int32_t GetFormGoldValue(RE::TESForm* form)
        {
            if (!form) return 0;

            // Try TESValueForm which many items inherit from
            if (auto valueForm = form->As<RE::TESValueForm>()) {
                return valueForm->value;
            }

            // Specific type checks for items that don't use TESValueForm
            if (auto weapon = form->As<RE::TESObjectWEAP>()) {
                return weapon->GetGoldValue();
            }
            if (auto armor = form->As<RE::TESObjectARMO>()) {
                return armor->GetGoldValue();
            }
            if (auto ammo = form->As<RE::TESAmmo>()) {
                return ammo->GetGoldValue();
            }
            if (auto alch = form->As<RE::AlchemyItem>()) {
                return alch->GetGoldValue();
            }
            if (auto ingr = form->As<RE::IngredientItem>()) {
                return ingr->GetGoldValue();
            }
            if (auto book = form->As<RE::TESObjectBOOK>()) {
                return book->GetGoldValue();
            }
            if (auto misc = form->As<RE::TESObjectMISC>()) {
                return misc->GetGoldValue();
            }
            if (auto soul = form->As<RE::TESSoulGem>()) {
                return soul->GetGoldValue();
            }

            return 0;
        }

        /**
         * Find all valuable items in a container (above threshold)
         */
        static std::vector<RE::TESForm*> FindValuableItems(RE::TESObjectREFR* container, int32_t minValue = 50)
        {
            std::vector<RE::TESForm*> result;
            if (!container) return result;

            auto inventory = container->GetInventory();

            for (const auto& [form, data] : inventory) {
                if (!form) continue;
                if (data.first <= 0) continue;

                int32_t value = GetFormGoldValue(form);
                if (value >= minValue) {
                    result.push_back(form);
                }
            }

            return result;
        }

        /**
         * Get total inventory count (number of unique item types)
         */
        static int32_t GetInventoryItemCount(RE::TESObjectREFR* container)
        {
            if (!container) return 0;

            auto inventory = container->GetInventory();
            int32_t count = 0;

            for (const auto& [form, data] : inventory) {
                if (form && data.first > 0) {
                    count++;
                }
            }

            return count;
        }

        /**
         * Check if a form is consumable (potion, food, ingredient)
         */
        static bool IsConsumable(RE::TESForm* form)
        {
            if (!form) return false;

            // Potions (includes food, drinks, poisons)
            if (form->As<RE::AlchemyItem>()) return true;

            // Ingredients (can be eaten raw)
            if (form->As<RE::IngredientItem>()) return true;

            return false;
        }

        /**
         * Check if a form is food specifically
         */
        static bool IsFood(RE::TESForm* form)
        {
            if (!form) return false;

            auto alch = form->As<RE::AlchemyItem>();
            if (!alch) return false;

            return alch->IsFood();
        }

        /**
         * Check if a form is a poison
         */
        static bool IsPoison(RE::TESForm* form)
        {
            if (!form) return false;

            auto alch = form->As<RE::AlchemyItem>();
            if (!alch) return false;

            return alch->IsPoison();
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static RE::TESForm* Papyrus_FindItemByName(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString itemName)
        {
            if (!actor || !itemName.data()) return nullptr;
            return FindItemByName(actor, itemName.data());
        }

        static RE::TESForm* Papyrus_FindItemInContainer(RE::StaticFunctionTag*, RE::TESObjectREFR* container, RE::BSFixedString itemName)
        {
            if (!container || !itemName.data()) return nullptr;
            return FindItemInContainer(container, itemName.data());
        }

        static bool Papyrus_ActorHasItemByName(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString itemName)
        {
            if (!actor || !itemName.data()) return false;
            return ActorHasItemByName(actor, itemName.data());
        }

        static RE::TESForm* Papyrus_FindWornItemByName(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString itemName)
        {
            if (!actor || !itemName.data()) return nullptr;
            return FindWornItemByName(actor, itemName.data());
        }

        static int32_t Papyrus_EquipItemsByName(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString itemNames)
        {
            if (!actor || !itemNames.data()) return 0;
            return EquipItemsByName(actor, itemNames.data());
        }

        static int32_t Papyrus_UnequipItemsByName(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString itemNames)
        {
            if (!actor || !itemNames.data()) return 0;
            return UnequipItemsByName(actor, itemNames.data());
        }

        static int32_t Papyrus_GetFormGoldValue(RE::StaticFunctionTag*, RE::TESForm* form)
        {
            return GetFormGoldValue(form);
        }

        static int32_t Papyrus_GetInventoryItemCount(RE::StaticFunctionTag*, RE::TESObjectREFR* container)
        {
            return GetInventoryItemCount(container);
        }

        static bool Papyrus_IsConsumable(RE::StaticFunctionTag*, RE::TESForm* form)
        {
            return IsConsumable(form);
        }

        static bool Papyrus_IsFood(RE::StaticFunctionTag*, RE::TESForm* form)
        {
            return IsFood(form);
        }

        static bool Papyrus_IsPoison(RE::StaticFunctionTag*, RE::TESForm* form)
        {
            return IsPoison(form);
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("FindItemByName", scriptName, Papyrus_FindItemByName);
            a_vm->RegisterFunction("FindItemInContainer", scriptName, Papyrus_FindItemInContainer);
            a_vm->RegisterFunction("ActorHasItemByName", scriptName, Papyrus_ActorHasItemByName);
            a_vm->RegisterFunction("FindWornItemByName", scriptName, Papyrus_FindWornItemByName);
            a_vm->RegisterFunction("EquipItemsByName", scriptName, Papyrus_EquipItemsByName);
            a_vm->RegisterFunction("UnequipItemsByName", scriptName, Papyrus_UnequipItemsByName);
            a_vm->RegisterFunction("GetFormGoldValue", scriptName, Papyrus_GetFormGoldValue);
            a_vm->RegisterFunction("GetInventoryItemCount", scriptName, Papyrus_GetInventoryItemCount);
            a_vm->RegisterFunction("IsConsumable", scriptName, Papyrus_IsConsumable);
            a_vm->RegisterFunction("IsFood", scriptName, Papyrus_IsFood);
            a_vm->RegisterFunction("IsPoison", scriptName, Papyrus_IsPoison);

            SKSE::log::info("Registered inventory utility functions");
        }
    };
}
