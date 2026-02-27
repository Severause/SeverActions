#pragma once

// SeverActionsNative - Papyrus Native Functions
// High-performance native implementations for SeverActions
// Author: Severause
//
// Usage in Papyrus:
//   Import SeverActionsNative
//
//   ; String utilities (2000-10000x faster than Papyrus)
//   string lower = SeverActionsNative.StringToLower("IRON SWORD")
//   int formId = SeverActionsNative.HexToInt("0x12EB7")
//   string trimmed = SeverActionsNative.TrimString("  hello  ")
//   string escaped = SeverActionsNative.EscapeJsonString("test\"quote")
//   bool contains = SeverActionsNative.StringContains("Iron Sword", "sword")
//   bool equals = SeverActionsNative.StringEquals("sword", "SWORD")
//
//   ; Crafting database (500x faster lookups)
//   bool loaded = SeverActionsNative.LoadCraftingDatabase("Data/SKSE/Plugins/SeverActions/CraftingDB/")
//   Form item = SeverActionsNative.FindCraftableByName("iron sword")
//   Form fuzzy = SeverActionsNative.FuzzySearchCraftable("iron")
//
//   ; Travel database (2000x faster lookups)
//   bool loaded = SeverActionsNative.LoadTravelDatabase("Data/SKSE/Plugins/SeverActions/TravelDB/TravelMarkersVanilla.json")
//   string cellId = SeverActionsNative.FindCellId("whiterun")
//   ObjectReference marker = SeverActionsNative.ResolvePlace("Bannered Mare")
//
//   ; Inventory helpers (100-200x faster)
//   Form item = SeverActionsNative.FindItemByName(actor, "health potion")
//   int value = SeverActionsNative.GetFormGoldValue(item)
//   bool consumable = SeverActionsNative.IsConsumable(item)
//
//   ; Nearby search (single pass vs 10 calls)
//   ObjectReference item = SeverActionsNative.FindNearbyItemOfType(actor, "sword", 1000.0)
//   ObjectReference forge = SeverActionsNative.FindNearbyForge(actor, 2000.0)
//
//   ; Fertility Mode integration (5000-15000x faster decorators)
//   bool fmInstalled = SeverActionsNative.FM_IsInstalled()
//   bool fmInit = SeverActionsNative.FM_Initialize()
//   string state = SeverActionsNative.FM_GetFertilityState(actor)  ; "normal", "ovulating", "pregnant", etc
//   string father = SeverActionsNative.FM_GetFertilityFather(actor)
//   string cycleDay = SeverActionsNative.FM_GetCycleDay(actor)
//   string pregDays = SeverActionsNative.FM_GetPregnantDays(actor)
//   string hasBaby = SeverActionsNative.FM_GetHasBaby(actor)
//   ; Cache management (called from Papyrus bridge)
//   SeverActionsNative.FM_SetActorData(actor, lastConception, lastBirth, babyAdded, lastOvulation, lastGameHours, lastGameHoursDelta, currentFather)
//   SeverActionsNative.FM_ClearActorData(actor)
//   SeverActionsNative.FM_ClearAllCache()
//   int cachedCount = SeverActionsNative.FM_GetCachedActorCount()

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>

namespace SeverActionsNative
{
    class Papyrus
    {
    public:
        /**
         * Register all Papyrus native functions with the VM
         */
        static bool RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm);

    private:
        // Plugin info
        static RE::BSFixedString GetPluginVersion(RE::StaticFunctionTag*);
    };
}
