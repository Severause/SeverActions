// SeverActionsNative - Papyrus Native Functions Implementation
// High-performance native implementations for SeverActions
// Author: Severause

#include "papyrus.h"
#include "StringUtils.h"
#include "CraftingDB.h"
#include "TravelDB.h"
#include "LocationResolver.h"
#include "ActorFinder.h"
#include "StuckDetector.h"
#include "InventoryUtils.h"
#include "NearbySearch.h"
#include "FurnitureManager.h"
#include "SandboxManager.h"
#include "DialogueAnimManager.h"
#include "FertilityMode.h"
#include "RecipeDB.h"
#include "AlchemyDB.h"
#include "CrimeUtils.h"
#include "SurvivalUtils.h"
#include "NsfwUtils.h"
#include "CollisionUtils.h"
#include "BookUtils.h"
#include "DBFBridge.h"
#include "YieldMonitor.h"
#include "OffScreenTracker.h"
#include "TeammateMonitor.h"
#include "OrphanCleanup.h"
#include "SkyrimNetBridge.h"

namespace SeverActionsNative
{
    bool Papyrus::RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm) {
            SKSE::log::error("Failed to register Papyrus functions: VM is null");
            return false;
        }

        const char* scriptName = "SeverActionsNative";

        // Register plugin info
        a_vm->RegisterFunction("GetPluginVersion", scriptName, GetPluginVersion);

        // Register all module functions
        StringUtils::RegisterFunctions(a_vm, scriptName);
        CraftingDB::RegisterFunctions(a_vm, scriptName);
        TravelDB::RegisterFunctions(a_vm, scriptName);
        LocationResolver::RegisterFunctions(a_vm, scriptName);
        ActorFinder::RegisterFunctions(a_vm, scriptName);
        StuckDetector::RegisterFunctions(a_vm, scriptName);
        InventoryUtils::RegisterFunctions(a_vm, scriptName);
        NearbySearch::RegisterFunctions(a_vm, scriptName);
        FurnitureManager::RegisterFunctions(a_vm, scriptName);
        SandboxManager::RegisterFunctions(a_vm, scriptName);
        DialogueAnimManager::RegisterFunctions(a_vm, scriptName);
        FertilityMode::RegisterFunctions(a_vm, scriptName);
        RecipeDB::RegisterFunctions(a_vm, scriptName);
        AlchemyDB::RegisterFunctions(a_vm, scriptName);
        CrimeUtils::RegisterFunctions(a_vm, scriptName);
        SurvivalUtils::RegisterFunctions(a_vm, scriptName);
        NsfwUtils::RegisterFunctions(a_vm, scriptName);
        CollisionUtils::RegisterFunctions(a_vm, scriptName);
        BookUtils::RegisterFunctions(a_vm, scriptName);
        DBFBridge::RegisterFunctions(a_vm, scriptName);
        YieldMonitor::RegisterFunctions(a_vm, scriptName);
        OffScreenTracker::RegisterFunctions(a_vm, scriptName);
        TeammateMonitor::RegisterFunctions(a_vm, scriptName);
        OrphanCleanup::RegisterFunctions(a_vm, scriptName);
        SkyrimNetBridge::RegisterFunctions(a_vm, scriptName);

        SKSE::log::info("Registered all Papyrus native functions for {}", scriptName);
        return true;
    }

    RE::BSFixedString Papyrus::GetPluginVersion(RE::StaticFunctionTag*)
    {
        return PLUGIN_VERSION;
    }
}
