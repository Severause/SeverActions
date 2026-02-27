#pragma once

// SeverActionsNative - Survival Utilities
// Native SKSE functions for Follower Survival System integration
// - Food consumption detection via TESEquipEvent
// - Weather/region-based cold calculation
// - Keyword-based heat source detection
// - Efficient follower tracking
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_map>
#include <unordered_set>
#include <mutex>
#include <chrono>

namespace SeverActionsNative
{
    // Data structure for tracked follower survival stats
    struct FollowerSurvivalData
    {
        RE::FormID actorFormID;
        float lastAteGameTime;      // Game time when last ate (in game hours * 3631)
        float lastSleptGameTime;    // Game time when last slept
        float lastWarmedGameTime;   // Game time when last warmed up
        int32_t hungerLevel;        // 0-100
        int32_t fatigueLevel;       // 0-100
        int32_t coldLevel;          // 0-100
    };

    // Food consumption event data (for mod callback)
    struct FoodConsumedEvent
    {
        RE::FormID actorFormID;
        RE::FormID foodFormID;
        bool isFood;
        bool isPotion;
        bool isIngredient;
    };

    /**
     * SurvivalUtils - Native survival system utilities
     *
     * Provides:
     * 1. TESEquipEvent sink for real-time food consumption detection
     * 2. Weather-based cold calculation (uses TESWeather classification)
     * 3. Keyword-based heat source detection (campfires, forges, etc.)
     * 4. Efficient follower tracking and enumeration
     * 5. Native StorageUtil-like per-actor data storage
     *
     * This eliminates Papyrus polling and provides instant callbacks
     * when followers eat food from their inventory.
     */
    class SurvivalUtils :
        public RE::BSTEventSink<RE::TESEquipEvent>
    {
    public:
        static SurvivalUtils* GetSingleton();

        // Initialize event sinks
        void Initialize();

        // ====================================================================
        // FOLLOWER TRACKING
        // ====================================================================

        // Start/stop tracking a follower for survival
        bool StartTracking(RE::Actor* actor);
        void StopTracking(RE::Actor* actor);
        bool IsTracked(RE::Actor* actor);

        // Get all tracked followers as an array
        std::vector<RE::Actor*> GetTrackedFollowers();
        int32_t GetTrackedCount();

        // Get all current followers (uses CurrentFollowerFaction)
        std::vector<RE::Actor*> GetCurrentFollowers();

        // ====================================================================
        // FOOD CONSUMPTION DETECTION
        // ====================================================================

        // Event handler for TESEquipEvent
        RE::BSEventNotifyControl ProcessEvent(
            const RE::TESEquipEvent* a_event,
            RE::BSTEventSource<RE::TESEquipEvent>* a_eventSource) override;

        // Check if a form is food that should reduce hunger
        static bool IsFoodItem(RE::TESForm* form);

        // Get food restoration value (estimates hunger reduction)
        static int32_t GetFoodRestoreValue(RE::TESForm* form);

        // ====================================================================
        // WEATHER & COLD CALCULATION
        // ====================================================================

        // Get current weather cold factor (0.0 = warm, 1.0 = freezing)
        static float GetWeatherColdFactor();

        // Get weather classification (0=Pleasant, 1=Cloudy, 2=Rainy, 3=Snow)
        static int32_t GetWeatherClassification();

        // Check if current weather is snowing
        static bool IsSnowingWeather();

        // Check if actor is in a cold region (based on worldspace/location)
        static bool IsInColdRegion(RE::Actor* actor);

        // Calculate cold exposure for an actor (considers weather, region, interior, armor)
        static float CalculateColdExposure(RE::Actor* actor);

        // ====================================================================
        // ARMOR WARMTH
        // ====================================================================

        // Get armor warmth factor for an actor (0.0 = naked, 1.0 = fully insulated)
        // Considers: body coverage, warm keywords (fur, hide), cold materials (metal)
        static float GetArmorWarmthFactor(RE::Actor* actor);

        // ====================================================================
        // HEAT SOURCE DETECTION
        // ====================================================================

        // Check if actor is near a heat source (campfire, forge, hearth)
        // Uses keyword-based detection for better performance
        static bool IsNearHeatSource(RE::Actor* actor, float radius = 512.0f);

        // Get distance to nearest heat source (-1 if none found)
        static float GetDistanceToNearestHeatSource(RE::Actor* actor, float maxRadius = 1024.0f);

        // Check specific heat source types
        static bool IsNearCampfire(RE::Actor* actor, float radius = 512.0f);
        static bool IsNearForge(RE::Actor* actor, float radius = 512.0f);
        static bool IsNearHearth(RE::Actor* actor, float radius = 512.0f);

        // Check if actor is in a warm interior
        static bool IsInWarmInterior(RE::Actor* actor);

        // ====================================================================
        // SURVIVAL DATA STORAGE (Per-Actor)
        // ====================================================================

        // Get/Set survival values for tracked actors
        // These are cached in native memory for fast access
        float GetLastAteTime(RE::Actor* actor);
        void SetLastAteTime(RE::Actor* actor, float gameTime);

        float GetLastSleptTime(RE::Actor* actor);
        void SetLastSleptTime(RE::Actor* actor, float gameTime);

        float GetLastWarmedTime(RE::Actor* actor);
        void SetLastWarmedTime(RE::Actor* actor, float gameTime);

        int32_t GetHungerLevel(RE::Actor* actor);
        void SetHungerLevel(RE::Actor* actor, int32_t level);

        int32_t GetFatigueLevel(RE::Actor* actor);
        void SetFatigueLevel(RE::Actor* actor, int32_t level);

        int32_t GetColdLevel(RE::Actor* actor);
        void SetColdLevel(RE::Actor* actor, int32_t level);

        // Clear all data for an actor
        void ClearActorData(RE::Actor* actor);

        // ====================================================================
        // UTILITY FUNCTIONS
        // ====================================================================

        // Get current game time in seconds (compatible with Papyrus format)
        static float GetGameTimeInSeconds();

        // Convert game hours to seconds
        static float GameHoursToSeconds(float hours);

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        // Follower tracking
        static bool Papyrus_StartTracking(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_StopTracking(RE::StaticFunctionTag*, RE::Actor* actor);
        static bool Papyrus_IsTracked(RE::StaticFunctionTag*, RE::Actor* actor);
        static int32_t Papyrus_GetTrackedCount(RE::StaticFunctionTag*);
        static std::vector<RE::Actor*> Papyrus_GetTrackedFollowers(RE::StaticFunctionTag*);
        static std::vector<RE::Actor*> Papyrus_GetCurrentFollowers(RE::StaticFunctionTag*);

        // Food detection
        static bool Papyrus_IsFoodItem(RE::StaticFunctionTag*, RE::TESForm* form);
        static int32_t Papyrus_GetFoodRestoreValue(RE::StaticFunctionTag*, RE::TESForm* form);

        // Weather & cold
        static float Papyrus_GetWeatherColdFactor(RE::StaticFunctionTag*);
        static int32_t Papyrus_GetWeatherClassification(RE::StaticFunctionTag*);
        static bool Papyrus_IsSnowingWeather(RE::StaticFunctionTag*);
        static bool Papyrus_IsInColdRegion(RE::StaticFunctionTag*, RE::Actor* actor);
        static float Papyrus_CalculateColdExposure(RE::StaticFunctionTag*, RE::Actor* actor);
        static float Papyrus_GetArmorWarmthFactor(RE::StaticFunctionTag*, RE::Actor* actor);

        // Heat sources
        static bool Papyrus_IsNearHeatSource(RE::StaticFunctionTag*, RE::Actor* actor, float radius);
        static float Papyrus_GetDistanceToNearestHeatSource(RE::StaticFunctionTag*, RE::Actor* actor, float maxRadius);
        static bool Papyrus_IsNearCampfire(RE::StaticFunctionTag*, RE::Actor* actor, float radius);
        static bool Papyrus_IsNearForge(RE::StaticFunctionTag*, RE::Actor* actor, float radius);
        static bool Papyrus_IsNearHearth(RE::StaticFunctionTag*, RE::Actor* actor, float radius);
        static bool Papyrus_IsInWarmInterior(RE::StaticFunctionTag*, RE::Actor* actor);

        // Survival data
        static float Papyrus_GetLastAteTime(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_SetLastAteTime(RE::StaticFunctionTag*, RE::Actor* actor, float gameTime);
        static float Papyrus_GetLastSleptTime(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_SetLastSleptTime(RE::StaticFunctionTag*, RE::Actor* actor, float gameTime);
        static float Papyrus_GetLastWarmedTime(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_SetLastWarmedTime(RE::StaticFunctionTag*, RE::Actor* actor, float gameTime);
        static int32_t Papyrus_GetHungerLevel(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_SetHungerLevel(RE::StaticFunctionTag*, RE::Actor* actor, int32_t level);
        static int32_t Papyrus_GetFatigueLevel(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_SetFatigueLevel(RE::StaticFunctionTag*, RE::Actor* actor, int32_t level);
        static int32_t Papyrus_GetColdLevel(RE::StaticFunctionTag*, RE::Actor* actor);
        static void Papyrus_SetColdLevel(RE::StaticFunctionTag*, RE::Actor* actor, int32_t level);
        static void Papyrus_ClearActorData(RE::StaticFunctionTag*, RE::Actor* actor);

        // Utility
        static float Papyrus_GetGameTimeInSeconds(RE::StaticFunctionTag*);

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName);

    private:
        SurvivalUtils() = default;
        ~SurvivalUtils() = default;
        SurvivalUtils(const SurvivalUtils&) = delete;
        SurvivalUtils& operator=(const SurvivalUtils&) = delete;

        // Internal: Send food consumed event to Papyrus
        void SendFoodConsumedEvent(RE::Actor* actor, RE::TESForm* food);

        // Internal: Check if a reference is a heat source
        static bool IsHeatSourceReference(RE::TESObjectREFR* ref);

        // Internal: Get heat source keywords (cached)
        static const std::unordered_set<RE::FormID>& GetHeatSourceKeywords();

        // Tracked followers: ActorFormID -> SurvivalData
        std::unordered_map<RE::FormID, FollowerSurvivalData> m_trackedFollowers;
        mutable std::mutex m_mutex;

        bool m_initialized = false;

        // Cache for CurrentFollowerFaction
        RE::TESFaction* m_currentFollowerFaction = nullptr;

        // Game time constant (seconds per game hour)
        static constexpr float SECONDS_PER_GAME_HOUR = 3631.0f;

        // Cold region keywords/locations to check
        static const std::unordered_set<std::string>& GetColdRegionNames();

        // Warm/cold armor keyword lists
        static const std::unordered_set<std::string>& GetWarmArmorKeywords();
        static const std::unordered_set<std::string>& GetColdArmorKeywords();
    };
}
