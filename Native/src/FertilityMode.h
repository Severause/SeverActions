#pragma once

// SeverActionsNative - Fertility Mode Integration
// Native decorator functions for Fertility Mode Reloaded data access
// Uses cached data from Papyrus bridge + native GlobalVariable lookups
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <string>
#include <unordered_map>
#include <mutex>
#include <cmath>

#include "StringUtils.h"

namespace SeverActionsNative
{
    /**
     * Native Fertility Mode data access - Hybrid approach
     *
     * Strategy:
     * 1. The Papyrus bridge (SeverActions_FertilityMode_Bridge) runs on a timer
     *    and caches raw FM data into our native cache via SetCachedData calls
     * 2. Native decorators read from the cache (O(1) hash lookup)
     * 3. GlobalVariable values are cached on initialization
     *
     * This avoids:
     * - Per-call Game.GetModByName() checks
     * - Per-call Game.GetFormFromFile() lookups
     * - Per-call O(n) TrackedActors.Find() searches
     * - Per-call GlobalVariable lookups
     */
    class FertilityMode
    {
    public:
        // Cached actor data structure
        struct ActorFertilityData
        {
            float lastConception = 0.0f;
            float lastBirth = 0.0f;
            float babyAdded = 0.0f;
            float lastOvulation = 0.0f;
            float lastGameHours = 0.0f;
            int lastGameHoursDelta = 0;
            std::string currentFather;
            bool isTracked = false;
        };

        static FertilityMode& GetInstance()
        {
            static FertilityMode instance;
            return instance;
        }

        /**
         * Check if Fertility Mode is installed and initialize if so
         * Called on game load to set up caching
         */
        bool Initialize()
        {
            std::lock_guard<std::mutex> lock(m_mutex);

            m_initialized = false;
            m_actorCache.clear();

            // Check if Fertility Mode is installed
            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            if (!dataHandler) {
                SKSE::log::info("FertilityMode: DataHandler not available");
                return false;
            }

            // Look for Fertility Mode.esm
            const RE::TESFile* fmFile = dataHandler->LookupModByName("Fertility Mode.esm");
            if (!fmFile) {
                SKSE::log::info("FertilityMode: Fertility Mode.esm not found - integration disabled");
                return false;
            }

            m_fmModIndex = fmFile->GetCompileIndex();
            SKSE::log::info("FertilityMode: Found Fertility Mode.esm at index {:02X}", m_fmModIndex);

            // Cache GlobalVariable FormIDs (modIndex << 24 | localFormID)
            m_cycleDurationGlobalId = (m_fmModIndex << 24) | 0x000D67;
            m_pregnancyDurationGlobalId = (m_fmModIndex << 24) | 0x000D66;
            m_recoveryDurationGlobalId = (m_fmModIndex << 24) | 0x0058D1;
            m_babyDurationGlobalId = (m_fmModIndex << 24) | 0x00EAA6;
            m_mensBeginGlobalId = (m_fmModIndex << 24) | 0x000D68;
            m_mensEndGlobalId = (m_fmModIndex << 24) | 0x000D69;
            m_ovulBeginGlobalId = (m_fmModIndex << 24) | 0x000D6A;
            m_ovulEndGlobalId = (m_fmModIndex << 24) | 0x000D6B;

            // Load cached values from GlobalVariables
            RefreshGlobalCache();

            m_initialized = true;
            SKSE::log::info("FertilityMode: Initialization complete");
            return true;
        }

        /**
         * Refresh cached GlobalVariable values
         */
        void RefreshGlobalCache()
        {
            m_cycleDuration = GetGlobalValue(m_cycleDurationGlobalId, 28);
            m_pregnancyDuration = GetGlobalValue(m_pregnancyDurationGlobalId, 30.0f);
            m_recoveryDuration = GetGlobalValue(m_recoveryDurationGlobalId, 10.0f);
            m_babyDuration = GetGlobalValue(m_babyDurationGlobalId, 7.0f);
            m_mensBegin = GetGlobalValue(m_mensBeginGlobalId, 0);
            m_mensEnd = GetGlobalValue(m_mensEndGlobalId, 7);
            m_ovulBegin = GetGlobalValue(m_ovulBeginGlobalId, 8);
            m_ovulEnd = GetGlobalValue(m_ovulEndGlobalId, 16);

            SKSE::log::debug("FertilityMode: Cached globals - cycle:{}, pregnancy:{}, recovery:{}",
                m_cycleDuration, m_pregnancyDuration, m_recoveryDuration);
        }

        /**
         * Set cached data for an actor (called from Papyrus bridge)
         */
        void SetCachedData(RE::Actor* actor, float lastConception, float lastBirth,
                          float babyAdded, float lastOvulation, float lastGameHours,
                          int lastGameHoursDelta, const std::string& currentFather)
        {
            if (!actor) return;

            std::lock_guard<std::mutex> lock(m_mutex);

            RE::FormID formId = actor->GetFormID();
            ActorFertilityData& data = m_actorCache[formId];
            data.lastConception = lastConception;
            data.lastBirth = lastBirth;
            data.babyAdded = babyAdded;
            data.lastOvulation = lastOvulation;
            data.lastGameHours = lastGameHours;
            data.lastGameHoursDelta = lastGameHoursDelta;
            data.currentFather = currentFather;
            data.isTracked = true;
        }

        /**
         * Clear cached data for an actor
         */
        void ClearCachedData(RE::Actor* actor)
        {
            if (!actor) return;

            std::lock_guard<std::mutex> lock(m_mutex);
            m_actorCache.erase(actor->GetFormID());
        }

        /**
         * Clear all cached actor data
         */
        void ClearAllCache()
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_actorCache.clear();
        }

        // ====================================================================
        // DECORATOR IMPLEMENTATIONS
        // ====================================================================

        /**
         * Get fertility state for an actor
         * Returns: "normal", "menstruating", "ovulating", "fertile", "pms",
         *          "first_trimester", "second_trimester", "third_trimester", "recovery"
         */
        std::string GetFertilityState(RE::Actor* actor)
        {
            if (!m_initialized || !actor) return "normal";

            // Only check female actors
            auto* actorBase = actor->GetActorBase();
            if (!actorBase || actorBase->GetSex() != RE::SEX::kFemale) {
                return "normal";
            }

            // Get cached data
            ActorFertilityData data;
            {
                std::lock_guard<std::mutex> lock(m_mutex);
                auto it = m_actorCache.find(actor->GetFormID());
                if (it == m_actorCache.end() || !it->second.isTracked) {
                    return "normal";
                }
                data = it->second;
            }

            float now = GetCurrentGameTime();

            // Check pregnancy first
            if (data.lastConception > 0.0f) {
                float pregnantDays = now - data.lastConception;
                float progress = (pregnantDays / m_pregnancyDuration) * 100.0f;

                if (progress >= 66.0f) {
                    return "third_trimester";
                } else if (progress >= 33.0f) {
                    return "second_trimester";
                } else {
                    return "first_trimester";
                }
            }

            // Check recovery
            if (data.lastBirth > 0.0f) {
                float daysSinceBirth = now - data.lastBirth;
                if (daysSinceBirth < m_recoveryDuration) {
                    return "recovery";
                }
            }

            // Calculate cycle day
            int cycleDay = (static_cast<int>(std::ceil(data.lastGameHours + data.lastGameHoursDelta))) % (m_cycleDuration + 1);

            // Determine cycle phase
            bool hasEgg = (data.lastOvulation > 0.0f);

            if (cycleDay >= m_mensBegin && cycleDay <= m_mensEnd) {
                return "menstruating";
            } else if (hasEgg || (cycleDay >= m_ovulBegin && cycleDay <= m_ovulEnd)) {
                return "ovulating";
            } else if (cycleDay > m_ovulEnd) {
                return "pms";
            }

            return "fertile";
        }

        /**
         * Get father name if actor is pregnant
         */
        std::string GetFertilityFather(RE::Actor* actor)
        {
            if (!m_initialized || !actor) return "";

            auto* actorBase = actor->GetActorBase();
            if (!actorBase || actorBase->GetSex() != RE::SEX::kFemale) {
                return "";
            }

            std::lock_guard<std::mutex> lock(m_mutex);
            auto it = m_actorCache.find(actor->GetFormID());
            if (it == m_actorCache.end() || !it->second.isTracked) {
                return "";
            }

            // Only return father if pregnant
            if (it->second.lastConception <= 0.0f) {
                return "";
            }

            return it->second.currentFather;
        }

        /**
         * Get current cycle day
         */
        int GetCycleDay(RE::Actor* actor)
        {
            if (!m_initialized || !actor) return -1;

            auto* actorBase = actor->GetActorBase();
            if (!actorBase || actorBase->GetSex() != RE::SEX::kFemale) {
                return -1;
            }

            std::lock_guard<std::mutex> lock(m_mutex);
            auto it = m_actorCache.find(actor->GetFormID());
            if (it == m_actorCache.end() || !it->second.isTracked) {
                return -1;
            }

            const auto& data = it->second;
            return (static_cast<int>(std::ceil(data.lastGameHours + data.lastGameHoursDelta))) % (m_cycleDuration + 1);
        }

        /**
         * Get days pregnant
         */
        int GetPregnantDays(RE::Actor* actor)
        {
            if (!m_initialized || !actor) return 0;

            auto* actorBase = actor->GetActorBase();
            if (!actorBase || actorBase->GetSex() != RE::SEX::kFemale) {
                return 0;
            }

            std::lock_guard<std::mutex> lock(m_mutex);
            auto it = m_actorCache.find(actor->GetFormID());
            if (it == m_actorCache.end() || !it->second.isTracked) {
                return 0;
            }

            if (it->second.lastConception <= 0.0f) {
                return 0;
            }

            float now = GetCurrentGameTime();
            return static_cast<int>(now - it->second.lastConception);
        }

        /**
         * Check if actor has a baby
         */
        bool GetHasBaby(RE::Actor* actor)
        {
            if (!m_initialized || !actor) return false;

            auto* actorBase = actor->GetActorBase();
            if (!actorBase || actorBase->GetSex() != RE::SEX::kFemale) {
                return false;
            }

            std::lock_guard<std::mutex> lock(m_mutex);
            auto it = m_actorCache.find(actor->GetFormID());
            if (it == m_actorCache.end() || !it->second.isTracked) {
                return false;
            }

            if (it->second.babyAdded <= 0.0f) {
                return false;
            }

            float now = GetCurrentGameTime();
            float daysSinceBaby = now - it->second.babyAdded;

            return (daysSinceBaby < m_babyDuration);
        }

        bool IsInitialized() const { return m_initialized; }
        bool IsFMInstalled() const { return m_initialized; }
        size_t GetCachedActorCount() const { return m_actorCache.size(); }

        /**
         * Batch function - get all fertility data in one call
         * Returns: [state, father, cycleDay, pregnantDays, hasBaby]
         * Much more efficient than 5 separate calls (single cache lookup)
         */
        void GetFertilityDataBatch(RE::Actor* actor,
                                   std::string& outState,
                                   std::string& outFather,
                                   std::string& outCycleDay,
                                   std::string& outPregnantDays,
                                   std::string& outHasBaby)
        {
            // Default values
            outState = "normal";
            outFather = "";
            outCycleDay = "-1";
            outPregnantDays = "0";
            outHasBaby = "false";

            if (!m_initialized || !actor) return;

            // Only check female actors
            auto* actorBase = actor->GetActorBase();
            if (!actorBase || actorBase->GetSex() != RE::SEX::kFemale) {
                return;
            }

            // Single cache lookup for all data
            ActorFertilityData data;
            {
                std::lock_guard<std::mutex> lock(m_mutex);
                auto it = m_actorCache.find(actor->GetFormID());
                if (it == m_actorCache.end() || !it->second.isTracked) {
                    return;
                }
                data = it->second;
            }

            float now = GetCurrentGameTime();

            // Calculate cycle day (used by multiple outputs)
            int cycleDay = (static_cast<int>(std::ceil(data.lastGameHours + data.lastGameHoursDelta))) % (m_cycleDuration + 1);
            outCycleDay = std::to_string(cycleDay);

            // Calculate state
            if (data.lastConception > 0.0f) {
                float pregnantDays = now - data.lastConception;
                float progress = (pregnantDays / m_pregnancyDuration) * 100.0f;

                if (progress >= 66.0f) {
                    outState = "third_trimester";
                } else if (progress >= 33.0f) {
                    outState = "second_trimester";
                } else {
                    outState = "first_trimester";
                }

                // Set father and pregnant days (only when pregnant)
                outFather = data.currentFather;
                outPregnantDays = std::to_string(static_cast<int>(pregnantDays));
            }
            else if (data.lastBirth > 0.0f && (now - data.lastBirth) < m_recoveryDuration) {
                outState = "recovery";
            }
            else {
                // Cycle phase
                bool hasEgg = (data.lastOvulation > 0.0f);
                if (cycleDay >= m_mensBegin && cycleDay <= m_mensEnd) {
                    outState = "menstruating";
                } else if (hasEgg || (cycleDay >= m_ovulBegin && cycleDay <= m_ovulEnd)) {
                    outState = "ovulating";
                } else if (cycleDay > m_ovulEnd) {
                    outState = "pms";
                } else {
                    outState = "fertile";
                }
            }

            // Check baby status
            if (data.babyAdded > 0.0f && (now - data.babyAdded) < m_babyDuration) {
                outHasBaby = "true";
            }
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static RE::BSFixedString Papyrus_GetFertilityState(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return GetInstance().GetFertilityState(actor).c_str();
        }

        static RE::BSFixedString Papyrus_GetFertilityFather(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return GetInstance().GetFertilityFather(actor).c_str();
        }

        static RE::BSFixedString Papyrus_GetCycleDay(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return std::to_string(GetInstance().GetCycleDay(actor)).c_str();
        }

        static RE::BSFixedString Papyrus_GetPregnantDays(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return std::to_string(GetInstance().GetPregnantDays(actor)).c_str();
        }

        static RE::BSFixedString Papyrus_GetHasBaby(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return GetInstance().GetHasBaby(actor) ? "true" : "false";
        }

        /**
         * Batch function - returns all fertility data as pipe-delimited string
         * Returns: "state|father|cycleDay|pregnantDays|hasBaby"
         * 5x faster than making 5 separate calls (single cache lookup + single Papyrus call)
         * Use split('|') in Jinja to parse
         */
        static RE::BSFixedString Papyrus_GetFertilityDataBatch(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            std::string state, father, cycleDay, pregnantDays, hasBaby;
            GetInstance().GetFertilityDataBatch(actor, state, father, cycleDay, pregnantDays, hasBaby);

            // Return pipe-delimited string: "state|father|cycleDay|pregnantDays|hasBaby"
            std::string result = state + "|" + father + "|" + cycleDay + "|" + pregnantDays + "|" + hasBaby;
            return result.c_str();
        }

        static bool Papyrus_IsFMInstalled(RE::StaticFunctionTag*)
        {
            return GetInstance().IsFMInstalled();
        }

        static bool Papyrus_InitializeFM(RE::StaticFunctionTag*)
        {
            return GetInstance().Initialize();
        }

        static void Papyrus_RefreshFMCache(RE::StaticFunctionTag*)
        {
            GetInstance().RefreshGlobalCache();
        }

        /**
         * Set cached FM data for an actor (called from Papyrus bridge)
         * This is the key function that populates native cache from Papyrus
         */
        static void Papyrus_SetActorFMData(RE::StaticFunctionTag*, RE::Actor* actor,
                                           float lastConception, float lastBirth,
                                           float babyAdded, float lastOvulation,
                                           float lastGameHours, int32_t lastGameHoursDelta,
                                           RE::BSFixedString currentFather)
        {
            std::string fatherStr = currentFather.data() ? currentFather.data() : "";
            GetInstance().SetCachedData(actor, lastConception, lastBirth, babyAdded,
                                        lastOvulation, lastGameHours, lastGameHoursDelta, fatherStr);
        }

        static void Papyrus_ClearActorFMData(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            GetInstance().ClearCachedData(actor);
        }

        static void Papyrus_ClearAllFMCache(RE::StaticFunctionTag*)
        {
            GetInstance().ClearAllCache();
        }

        static int32_t Papyrus_GetCachedActorCount(RE::StaticFunctionTag*)
        {
            return static_cast<int32_t>(GetInstance().GetCachedActorCount());
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            // Decorator functions (called by SkyrimNet)
            a_vm->RegisterFunction("FM_GetFertilityState", scriptName, Papyrus_GetFertilityState);
            a_vm->RegisterFunction("FM_GetFertilityFather", scriptName, Papyrus_GetFertilityFather);
            a_vm->RegisterFunction("FM_GetCycleDay", scriptName, Papyrus_GetCycleDay);
            a_vm->RegisterFunction("FM_GetPregnantDays", scriptName, Papyrus_GetPregnantDays);
            a_vm->RegisterFunction("FM_GetHasBaby", scriptName, Papyrus_GetHasBaby);
            a_vm->RegisterFunction("FM_GetFertilityDataBatch", scriptName, Papyrus_GetFertilityDataBatch);

            // Initialization and cache management
            a_vm->RegisterFunction("FM_IsInstalled", scriptName, Papyrus_IsFMInstalled);
            a_vm->RegisterFunction("FM_Initialize", scriptName, Papyrus_InitializeFM);
            a_vm->RegisterFunction("FM_RefreshCache", scriptName, Papyrus_RefreshFMCache);

            // Cache population (called from Papyrus bridge)
            a_vm->RegisterFunction("FM_SetActorData", scriptName, Papyrus_SetActorFMData);
            a_vm->RegisterFunction("FM_ClearActorData", scriptName, Papyrus_ClearActorFMData);
            a_vm->RegisterFunction("FM_ClearAllCache", scriptName, Papyrus_ClearAllFMCache);
            a_vm->RegisterFunction("FM_GetCachedActorCount", scriptName, Papyrus_GetCachedActorCount);

            SKSE::log::info("Registered Fertility Mode native functions");
        }

    private:
        FertilityMode() = default;
        FertilityMode(const FertilityMode&) = delete;
        FertilityMode& operator=(const FertilityMode&) = delete;

        // ====================================================================
        // HELPER FUNCTIONS
        // ====================================================================

        float GetGlobalValue(RE::FormID formId, float defaultValue)
        {
            RE::TESForm* form = RE::TESForm::LookupByID(formId);
            if (!form) return defaultValue;

            RE::TESGlobal* global = form->As<RE::TESGlobal>();
            if (!global) return defaultValue;

            return global->value;
        }

        int GetGlobalValue(RE::FormID formId, int defaultValue)
        {
            return static_cast<int>(GetGlobalValue(formId, static_cast<float>(defaultValue)));
        }

        float GetCurrentGameTime()
        {
            auto* calendar = RE::Calendar::GetSingleton();
            if (!calendar) return 0.0f;
            return calendar->GetCurrentGameTime();
        }

        // Cached data
        bool m_initialized = false;
        uint8_t m_fmModIndex = 0;

        // GlobalVariable FormIDs
        RE::FormID m_cycleDurationGlobalId = 0;
        RE::FormID m_pregnancyDurationGlobalId = 0;
        RE::FormID m_recoveryDurationGlobalId = 0;
        RE::FormID m_babyDurationGlobalId = 0;
        RE::FormID m_mensBeginGlobalId = 0;
        RE::FormID m_mensEndGlobalId = 0;
        RE::FormID m_ovulBeginGlobalId = 0;
        RE::FormID m_ovulEndGlobalId = 0;

        // Cached GlobalVariable values
        int m_cycleDuration = 28;
        float m_pregnancyDuration = 30.0f;
        float m_recoveryDuration = 10.0f;
        float m_babyDuration = 7.0f;
        int m_mensBegin = 0;
        int m_mensEnd = 7;
        int m_ovulBegin = 8;
        int m_ovulEnd = 16;

        // Actor FormID -> cached data mapping
        std::unordered_map<RE::FormID, ActorFertilityData> m_actorCache;

        mutable std::mutex m_mutex;
    };
}
