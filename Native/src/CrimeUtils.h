#pragma once

// SeverActionsNative - Crime Utility Functions
// Access crime faction data not exposed to Papyrus
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>

namespace SeverActionsNative
{
    class CrimeUtils
    {
    public:
        // ====================================================================
        // FACTION CRIME DATA ACCESS
        // These functions expose TESFaction crime data not available in Papyrus
        // ====================================================================

        /**
         * Get the jail marker (interior) for a crime faction
         * This is where prisoners are sent when arrested
         * @param faction The crime faction to query
         * @return The jail marker ObjectReference, or nullptr if not set
         */
        static RE::TESObjectREFR* GetFactionJailMarker(RE::TESFaction* faction)
        {
            if (!faction) {
                SKSE::log::warn("GetFactionJailMarker: faction is null");
                return nullptr;
            }

            // Access the crime data struct within the faction
            // TESFaction::crimeData.factionJailMarker
            auto& crimeData = faction->crimeData;
            return crimeData.factionJailMarker;
        }

        /**
         * Get the exterior jail marker (wait marker) for a crime faction
         * This is where the player/NPCs appear after serving time
         * @param faction The crime faction to query
         * @return The wait marker ObjectReference, or nullptr if not set
         */
        static RE::TESObjectREFR* GetFactionWaitMarker(RE::TESFaction* faction)
        {
            if (!faction) {
                SKSE::log::warn("GetFactionWaitMarker: faction is null");
                return nullptr;
            }

            auto& crimeData = faction->crimeData;
            return crimeData.factionWaitMarker;
        }

        /**
         * Get the stolen goods container for a crime faction
         * @param faction The crime faction to query
         * @return The stolen goods container ObjectReference, or nullptr if not set
         */
        static RE::TESObjectREFR* GetFactionStolenGoodsContainer(RE::TESFaction* faction)
        {
            if (!faction) {
                SKSE::log::warn("GetFactionStolenGoodsContainer: faction is null");
                return nullptr;
            }

            auto& crimeData = faction->crimeData;
            return crimeData.factionStolenContainer;
        }

        /**
         * Get the player inventory container for a crime faction
         * @param faction The crime faction to query
         * @return The player inventory container ObjectReference, or nullptr if not set
         */
        static RE::TESObjectREFR* GetFactionPlayerInventoryContainer(RE::TESFaction* faction)
        {
            if (!faction) {
                SKSE::log::warn("GetFactionPlayerInventoryContainer: faction is null");
                return nullptr;
            }

            auto& crimeData = faction->crimeData;
            return crimeData.factionPlayerInventoryContainer;
        }

        /**
         * Get the jail outfit for a crime faction
         * @param faction The crime faction to query
         * @return The jail outfit, or nullptr if not set
         */
        static RE::BGSOutfit* GetFactionJailOutfit(RE::TESFaction* faction)
        {
            if (!faction) {
                SKSE::log::warn("GetFactionJailOutfit: faction is null");
                return nullptr;
            }

            auto& crimeData = faction->crimeData;
            return crimeData.jailOutfit;
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static RE::TESObjectREFR* Papyrus_GetFactionJailMarker(RE::StaticFunctionTag*, RE::TESFaction* faction)
        {
            return GetFactionJailMarker(faction);
        }

        static RE::TESObjectREFR* Papyrus_GetFactionWaitMarker(RE::StaticFunctionTag*, RE::TESFaction* faction)
        {
            return GetFactionWaitMarker(faction);
        }

        static RE::TESObjectREFR* Papyrus_GetFactionStolenGoodsContainer(RE::StaticFunctionTag*, RE::TESFaction* faction)
        {
            return GetFactionStolenGoodsContainer(faction);
        }

        static RE::TESObjectREFR* Papyrus_GetFactionPlayerInventoryContainer(RE::StaticFunctionTag*, RE::TESFaction* faction)
        {
            return GetFactionPlayerInventoryContainer(faction);
        }

        static RE::BGSOutfit* Papyrus_GetFactionJailOutfit(RE::StaticFunctionTag*, RE::TESFaction* faction)
        {
            return GetFactionJailOutfit(faction);
        }

        /**
         * Register all crime utility functions with Papyrus VM
         */
        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("GetFactionJailMarker", scriptName, Papyrus_GetFactionJailMarker);
            a_vm->RegisterFunction("GetFactionWaitMarker", scriptName, Papyrus_GetFactionWaitMarker);
            a_vm->RegisterFunction("GetFactionStolenGoodsContainer", scriptName, Papyrus_GetFactionStolenGoodsContainer);
            a_vm->RegisterFunction("GetFactionPlayerInventoryContainer", scriptName, Papyrus_GetFactionPlayerInventoryContainer);
            a_vm->RegisterFunction("GetFactionJailOutfit", scriptName, Papyrus_GetFactionJailOutfit);

            SKSE::log::info("Registered crime utility functions");
        }
    };
}
