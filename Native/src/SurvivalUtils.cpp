// SeverActionsNative - Survival Utilities Implementation
// Native SKSE functions for Follower Survival System
// Author: Severause

#include "SurvivalUtils.h"
#include "StringUtils.h"

namespace SeverActionsNative
{
    SurvivalUtils* SurvivalUtils::GetSingleton()
    {
        static SurvivalUtils singleton;
        return &singleton;
    }

    void SurvivalUtils::Initialize()
    {
        if (m_initialized) {
            return;
        }

        // Register for equip events (fires when items are equipped/used)
        auto* eventSource = RE::ScriptEventSourceHolder::GetSingleton();
        if (eventSource) {
            eventSource->AddEventSink<RE::TESEquipEvent>(this);
            SKSE::log::info("SurvivalUtils: Registered for TESEquipEvent");
        }

        // Cache CurrentFollowerFaction for efficient lookups
        auto* dataHandler = RE::TESDataHandler::GetSingleton();
        if (dataHandler) {
            m_currentFollowerFaction = RE::TESForm::LookupByEditorID<RE::TESFaction>("CurrentFollowerFaction");
            if (m_currentFollowerFaction) {
                SKSE::log::info("SurvivalUtils: Cached CurrentFollowerFaction");
            } else {
                SKSE::log::warn("SurvivalUtils: Could not find CurrentFollowerFaction");
            }
        }

        m_initialized = true;
        SKSE::log::info("SurvivalUtils initialized");
    }

    // ========================================================================
    // FOLLOWER TRACKING
    // ========================================================================

    bool SurvivalUtils::StartTracking(RE::Actor* actor)
    {
        if (!actor) {
            return false;
        }

        std::lock_guard<std::mutex> lock(m_mutex);

        RE::FormID actorID = actor->GetFormID();

        // Check if already tracked
        if (m_trackedFollowers.contains(actorID)) {
            return true;
        }

        // Initialize survival data
        FollowerSurvivalData data{
            .actorFormID = actorID,
            .lastAteGameTime = GetGameTimeInSeconds(),
            .lastSleptGameTime = GetGameTimeInSeconds(),
            .lastWarmedGameTime = GetGameTimeInSeconds(),
            .hungerLevel = 0,
            .fatigueLevel = 0,
            .coldLevel = 0
        };

        m_trackedFollowers[actorID] = data;

        SKSE::log::info("SurvivalUtils: Started tracking actor {:X}", actorID);
        return true;
    }

    void SurvivalUtils::StopTracking(RE::Actor* actor)
    {
        if (!actor) {
            return;
        }

        std::lock_guard<std::mutex> lock(m_mutex);

        RE::FormID actorID = actor->GetFormID();
        auto it = m_trackedFollowers.find(actorID);
        if (it != m_trackedFollowers.end()) {
            m_trackedFollowers.erase(it);
            SKSE::log::info("SurvivalUtils: Stopped tracking actor {:X}", actorID);
        }
    }

    bool SurvivalUtils::IsTracked(RE::Actor* actor)
    {
        if (!actor) {
            return false;
        }

        std::lock_guard<std::mutex> lock(m_mutex);
        return m_trackedFollowers.contains(actor->GetFormID());
    }

    std::vector<RE::Actor*> SurvivalUtils::GetTrackedFollowers()
    {
        std::vector<RE::Actor*> result;

        std::lock_guard<std::mutex> lock(m_mutex);

        for (const auto& [formID, data] : m_trackedFollowers) {
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(formID);
            if (actor && !actor->IsDead()) {
                result.push_back(actor);
            }
        }

        return result;
    }

    int32_t SurvivalUtils::GetTrackedCount()
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        return static_cast<int32_t>(m_trackedFollowers.size());
    }

    std::vector<RE::Actor*> SurvivalUtils::GetCurrentFollowers()
    {
        std::vector<RE::Actor*> result;

        if (!m_currentFollowerFaction) {
            // Try to get it again
            m_currentFollowerFaction = RE::TESForm::LookupByEditorID<RE::TESFaction>("CurrentFollowerFaction");
            if (!m_currentFollowerFaction) {
                SKSE::log::warn("SurvivalUtils::GetCurrentFollowers - CurrentFollowerFaction not found");
                return result;
            }
        }

        // Get player for reference
        auto* player = RE::PlayerCharacter::GetSingleton();
        if (!player) {
            return result;
        }

        // Iterate through all actors in loaded cells
        auto* processLists = RE::ProcessLists::GetSingleton();
        if (!processLists) {
            return result;
        }

        // Check high-process actors (nearby NPCs)
        for (auto& handle : processLists->highActorHandles) {
            auto actor = handle.get();
            if (!actor) continue;

            auto* actorPtr = actor.get();
            if (!actorPtr || actorPtr->IsDead()) continue;

            // Check if in CurrentFollowerFaction
            if (actorPtr->IsInFaction(m_currentFollowerFaction)) {
                result.push_back(actorPtr);
            }
        }

        return result;
    }

    // ========================================================================
    // FOOD CONSUMPTION DETECTION
    // ========================================================================

    RE::BSEventNotifyControl SurvivalUtils::ProcessEvent(
        const RE::TESEquipEvent* a_event,
        RE::BSTEventSource<RE::TESEquipEvent>*)
    {
        if (!a_event || !a_event->equipped) {
            // Only care about equip (use) events, not unequip
            return RE::BSEventNotifyControl::kContinue;
        }

        // Get the actor
        auto actor = a_event->actor.get();
        if (!actor) {
            return RE::BSEventNotifyControl::kContinue;
        }

        auto* actorPtr = actor->As<RE::Actor>();
        if (!actorPtr) {
            return RE::BSEventNotifyControl::kContinue;
        }

        // Check if this is a tracked follower
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            if (!m_trackedFollowers.contains(actorPtr->GetFormID())) {
                return RE::BSEventNotifyControl::kContinue;
            }
        }

        // Get the item that was equipped/used
        auto* form = RE::TESForm::LookupByID(a_event->baseObject);
        if (!form) {
            return RE::BSEventNotifyControl::kContinue;
        }

        // Check if it's food
        if (IsFoodItem(form)) {
            SKSE::log::info("SurvivalUtils: Follower {:X} consumed food {:X} ({})",
                actorPtr->GetFormID(), form->GetFormID(), form->GetName());

            // Update last ate time
            SetLastAteTime(actorPtr, GetGameTimeInSeconds());

            // Calculate hunger reduction
            int32_t restoreValue = GetFoodRestoreValue(form);
            int32_t currentHunger = GetHungerLevel(actorPtr);
            int32_t newHunger = std::max(0, currentHunger - restoreValue);
            SetHungerLevel(actorPtr, newHunger);

            SKSE::log::info("SurvivalUtils: Hunger reduced by {} (was {}, now {})",
                restoreValue, currentHunger, newHunger);

            // Send mod event for Papyrus notification
            SendFoodConsumedEvent(actorPtr, form);
        }

        return RE::BSEventNotifyControl::kContinue;
    }

    bool SurvivalUtils::IsFoodItem(RE::TESForm* form)
    {
        if (!form) return false;

        // Check if it's an AlchemyItem (potions, food, etc.)
        auto* alch = form->As<RE::AlchemyItem>();
        if (alch) {
            // Food items have the IsFood flag
            if (alch->IsFood()) {
                return true;
            }
        }

        // Ingredients can also be eaten raw
        if (form->As<RE::IngredientItem>()) {
            return true;
        }

        return false;
    }

    int32_t SurvivalUtils::GetFoodRestoreValue(RE::TESForm* form)
    {
        if (!form) return 0;

        // Default restoration values based on food type
        int32_t baseRestore = 15;  // Default for unknown food

        auto* alch = form->As<RE::AlchemyItem>();
        if (alch) {
            // Check for restore health/stamina effects to estimate food quality
            for (auto* effect : alch->effects) {
                if (!effect || !effect->baseEffect) continue;

                auto* baseEffect = effect->baseEffect;
                auto archetype = baseEffect->GetArchetype();

                // Restore Health, Restore Stamina, Fortify Health
                if (archetype == RE::EffectSetting::Archetype::kValueModifier ||
                    archetype == RE::EffectSetting::Archetype::kPeakValueModifier) {

                    // Get the magnitude as an indicator of food quality
                    float magnitude = effect->effectItem.magnitude;
                    if (magnitude > 0) {
                        // Scale: 10 magnitude = 15 hunger restore, 50 magnitude = 30 restore
                        baseRestore = static_cast<int32_t>(15 + magnitude * 0.3f);
                        baseRestore = std::min(50, baseRestore);  // Cap at 50
                    }
                }
            }
        }

        // Ingredients provide less sustenance
        if (form->As<RE::IngredientItem>()) {
            baseRestore = 10;
        }

        return baseRestore;
    }

    void SurvivalUtils::SendFoodConsumedEvent(RE::Actor* actor, RE::TESForm* food)
    {
        // Send mod event for Papyrus to handle
        auto* eventSource = SKSE::GetModCallbackEventSource();
        if (!eventSource) {
            return;
        }

        SKSE::ModCallbackEvent modEvent;
        modEvent.eventName = "SeverActionsNative_FoodConsumed";
        modEvent.strArg = food ? food->GetName() : "";
        modEvent.numArg = static_cast<float>(food ? food->GetFormID() : 0);
        modEvent.sender = actor;

        eventSource->SendEvent(&modEvent);

        SKSE::log::info("SurvivalUtils: Sent FoodConsumed event for actor {:X}",
            actor->GetFormID());
    }

    // ========================================================================
    // WEATHER & COLD CALCULATION
    // ========================================================================

    float SurvivalUtils::GetWeatherColdFactor()
    {
        auto* sky = RE::Sky::GetSingleton();
        if (!sky || !sky->currentWeather) {
            return 0.0f;  // No weather = neutral
        }

        auto* weather = sky->currentWeather;
        auto flags = weather->data.flags;

        // Map weather flags to cold factor
        // Check flags in order of coldest to warmest
        if (flags.any(RE::TESWeather::WeatherDataFlag::kSnow)) {
            return 1.0f;  // Snow is coldest
        }
        if (flags.any(RE::TESWeather::WeatherDataFlag::kRainy)) {
            return 0.5f;  // Rain makes you cold
        }
        if (flags.any(RE::TESWeather::WeatherDataFlag::kCloudy)) {
            return 0.2f;
        }
        if (flags.any(RE::TESWeather::WeatherDataFlag::kPleasant)) {
            return 0.0f;
        }

        return 0.0f;  // Default to neutral
    }

    int32_t SurvivalUtils::GetWeatherClassification()
    {
        auto* sky = RE::Sky::GetSingleton();
        if (!sky || !sky->currentWeather) {
            return 0;  // Pleasant
        }

        auto flags = sky->currentWeather->data.flags;

        // Return classification as int: 0=Pleasant, 1=Cloudy, 2=Rainy, 3=Snow
        if (flags.any(RE::TESWeather::WeatherDataFlag::kSnow)) {
            return 3;
        }
        if (flags.any(RE::TESWeather::WeatherDataFlag::kRainy)) {
            return 2;
        }
        if (flags.any(RE::TESWeather::WeatherDataFlag::kCloudy)) {
            return 1;
        }
        return 0;  // Pleasant or none
    }

    bool SurvivalUtils::IsSnowingWeather()
    {
        auto* sky = RE::Sky::GetSingleton();
        if (!sky || !sky->currentWeather) {
            return false;
        }

        return sky->currentWeather->data.flags.any(RE::TESWeather::WeatherDataFlag::kSnow);
    }

    const std::unordered_set<std::string>& SurvivalUtils::GetColdRegionNames()
    {
        static std::unordered_set<std::string> coldRegions = {
            // Skyrim cold regions
            "winterhold", "windhelm", "dawnstar", "pale", "hjaalmarch",
            "eastmarch", "winterhold hold", "the pale", "dawnstar",
            // Mountains and specific cold areas
            "throat of the world", "high hrothgar", "bleak falls",
            "snow", "frost", "ice", "frozen"
        };
        return coldRegions;
    }

    bool SurvivalUtils::IsInColdRegion(RE::Actor* actor)
    {
        if (!actor) return false;

        // Check if in interior (usually not cold)
        auto* cell = actor->GetParentCell();
        if (cell && cell->IsInteriorCell()) {
            return false;  // Interiors handled separately
        }

        // Check location name
        auto* location = actor->GetCurrentLocation();
        if (location) {
            const char* locName = location->GetFullName();
            if (locName) {
                std::string lowerName = StringUtils::ToLower(locName);
                for (const auto& coldRegion : GetColdRegionNames()) {
                    if (lowerName.find(coldRegion) != std::string::npos) {
                        return true;
                    }
                }
            }
        }

        // Check worldspace
        auto* worldspace = actor->GetWorldspace();
        if (worldspace) {
            const char* wsName = worldspace->GetFullName();
            if (wsName) {
                std::string lowerName = StringUtils::ToLower(wsName);
                // Check for cold indicators in worldspace name
                if (lowerName.find("snow") != std::string::npos ||
                    lowerName.find("frost") != std::string::npos ||
                    lowerName.find("ice") != std::string::npos ||
                    lowerName.find("frozen") != std::string::npos) {
                    return true;
                }
            }
        }

        return false;
    }

    // ========================================================================
    // ARMOR WARMTH CALCULATION
    // ========================================================================

    const std::unordered_set<std::string>& SurvivalUtils::GetWarmArmorKeywords()
    {
        // Keywords that indicate warm/insulating armor
        static std::unordered_set<std::string> warmKeywords = {
            // Vanilla and common mod keywords (lowercase for comparison)
            "armorclothing",        // Clothing (light insulation)
            "clothingbody",
            "clothinghead",
            "clothinghands",
            "clothingfeet",
            // Warm material keywords
            "warmarmor",
            "warmclothing",
            "furarmor",
            "hidearmor",
            "fur",
            "hide",
            "wolf",
            "bear",
            "sabrecat",
            // Frostfall/Survival mode keywords (if present)
            "frostfallwarmthkeyword",
            "survivalmodewarmth",
            "_survivalwarm",
            "armorwarm"
        };
        return warmKeywords;
    }

    const std::unordered_set<std::string>& SurvivalUtils::GetColdArmorKeywords()
    {
        // Keywords/materials that provide less warmth (metal armor)
        static std::unordered_set<std::string> coldKeywords = {
            "armorheavy",           // Heavy armor (metal) is cold
            "armorsteel",
            "armorebony",
            "armordragon",
            "armordaedric",
            "armordwarven",
            "armororcish",
            "armorimperial",
            "armorstormcloak",
            "daedricarmor",
            "steelarmor",
            "ironarmor",
            "ebonyarmor",
            "dragonbonearmor",
            "dragonscalearmor"
        };
        return coldKeywords;
    }

    float SurvivalUtils::GetArmorWarmthFactor(RE::Actor* actor)
    {
        if (!actor) return 0.0f;

        float warmth = 0.0f;
        bool hasBodyCovering = false;
        bool hasHeadCovering = false;
        bool hasHandsCovering = false;
        bool hasFeetCovering = false;

        // Biped slots for body parts
        // 32 = Body, 30 = Head, 33 = Hands, 37 = Feet
        constexpr RE::BIPED_MODEL::BipedObjectSlot kBody = RE::BIPED_MODEL::BipedObjectSlot::kBody;
        constexpr RE::BIPED_MODEL::BipedObjectSlot kHead = RE::BIPED_MODEL::BipedObjectSlot::kHead;
        constexpr RE::BIPED_MODEL::BipedObjectSlot kHands = RE::BIPED_MODEL::BipedObjectSlot::kHands;
        constexpr RE::BIPED_MODEL::BipedObjectSlot kFeet = RE::BIPED_MODEL::BipedObjectSlot::kFeet;
        constexpr RE::BIPED_MODEL::BipedObjectSlot kCirclet = RE::BIPED_MODEL::BipedObjectSlot::kCirclet;
        constexpr RE::BIPED_MODEL::BipedObjectSlot kHair = RE::BIPED_MODEL::BipedObjectSlot::kHair;

        const auto& warmKeywords = GetWarmArmorKeywords();
        const auto& coldKeywords = GetColdArmorKeywords();

        // Helper lambda to check armor piece warmth
        auto checkArmorPiece = [&](RE::TESObjectARMO* armor) -> float {
            if (!armor) return 0.0f;

            float pieceWarmth = 0.0f;
            bool isWarm = false;
            bool isCold = false;

            // Check armor name for material hints
            const char* armorName = armor->GetName();
            if (armorName) {
                std::string lowerName = StringUtils::ToLower(armorName);

                // Warm materials
                if (lowerName.find("fur") != std::string::npos ||
                    lowerName.find("hide") != std::string::npos ||
                    lowerName.find("leather") != std::string::npos ||
                    lowerName.find("wool") != std::string::npos ||
                    lowerName.find("cloth") != std::string::npos ||
                    lowerName.find("robes") != std::string::npos ||
                    lowerName.find("warm") != std::string::npos ||
                    lowerName.find("winter") != std::string::npos ||
                    lowerName.find("nordic") != std::string::npos ||
                    lowerName.find("stormcloak") != std::string::npos) {
                    isWarm = true;
                }

                // Cold materials (metal)
                if (lowerName.find("steel") != std::string::npos ||
                    lowerName.find("iron") != std::string::npos ||
                    lowerName.find("ebony") != std::string::npos ||
                    lowerName.find("daedric") != std::string::npos ||
                    lowerName.find("dwarven") != std::string::npos ||
                    lowerName.find("orcish") != std::string::npos ||
                    lowerName.find("glass") != std::string::npos ||
                    lowerName.find("elven") != std::string::npos ||
                    lowerName.find("dragonplate") != std::string::npos) {
                    isCold = true;
                }
            }

            // Check keywords
            if (armor->HasKeywordString("ArmorLight")) {
                // Light armor - moderate warmth
                pieceWarmth += 0.05f;
            }
            if (armor->HasKeywordString("ArmorHeavy")) {
                // Heavy armor - less warmth (metal is cold)
                isCold = true;
            }
            if (armor->HasKeywordString("ArmorClothing")) {
                // Clothing - decent warmth
                pieceWarmth += 0.08f;
            }

            // Check for specific warm/cold keywords via BGSKeywordForm
            auto* keywordForm = armor->As<RE::BGSKeywordForm>();
            if (keywordForm) {
                for (uint32_t i = 0; i < keywordForm->numKeywords; ++i) {
                    auto* kw = keywordForm->keywords[i];
                    if (!kw) continue;

                    const char* kwEditorID = kw->GetFormEditorID();
                    if (kwEditorID) {
                        std::string lowerKw = StringUtils::ToLower(kwEditorID);

                        // Check warm keywords
                        for (const auto& warmKw : warmKeywords) {
                            if (lowerKw.find(warmKw) != std::string::npos) {
                                isWarm = true;
                                break;
                            }
                        }

                        // Check cold keywords
                        for (const auto& coldKw : coldKeywords) {
                            if (lowerKw.find(coldKw) != std::string::npos) {
                                isCold = true;
                                break;
                            }
                        }
                    }
                }
            }

            // Calculate warmth contribution
            if (isWarm) {
                pieceWarmth += 0.10f;  // Warm armor bonus
            } else if (isCold) {
                pieceWarmth = 0.02f;   // Metal armor provides minimal warmth
            } else {
                pieceWarmth += 0.05f;  // Base armor provides some warmth
            }

            return pieceWarmth;
        };

        // Get equipped items from container changes
        auto* changes = actor->GetInventoryChanges();
        if (changes && changes->entryList) {
            for (auto* entry : *changes->entryList) {
                if (!entry || !entry->object) continue;

                auto* armor = entry->object->As<RE::TESObjectARMO>();
                if (!armor) continue;

                // Check if this item is equipped
                bool isEquipped = false;
                if (entry->extraLists) {
                    for (auto* extraList : *entry->extraLists) {
                        if (extraList && extraList->HasType(RE::ExtraDataType::kWorn)) {
                            isEquipped = true;
                            break;
                        }
                    }
                }

                if (!isEquipped) continue;

                // Check which slots this covers
                auto slots = armor->GetSlotMask();

                // Use underlying enum value with bitwise check
                auto slotsValue = static_cast<uint32_t>(slots);

                if (slotsValue & static_cast<uint32_t>(kBody)) {
                    hasBodyCovering = true;
                    warmth += checkArmorPiece(armor) * 2.0f;  // Body is most important
                }
                if ((slotsValue & static_cast<uint32_t>(kHead)) ||
                    (slotsValue & static_cast<uint32_t>(kCirclet)) ||
                    (slotsValue & static_cast<uint32_t>(kHair))) {
                    hasHeadCovering = true;
                    warmth += checkArmorPiece(armor);
                }
                if (slotsValue & static_cast<uint32_t>(kHands)) {
                    hasHandsCovering = true;
                    warmth += checkArmorPiece(armor);
                }
                if (slotsValue & static_cast<uint32_t>(kFeet)) {
                    hasFeetCovering = true;
                    warmth += checkArmorPiece(armor);
                }
            }
        }

        // Bonus for full coverage
        if (hasBodyCovering && hasHeadCovering && hasHandsCovering && hasFeetCovering) {
            warmth += 0.1f;  // Full coverage bonus
        }

        // Penalty for exposed extremities in cold
        if (!hasHeadCovering) warmth -= 0.05f;
        if (!hasHandsCovering) warmth -= 0.03f;
        if (!hasFeetCovering) warmth -= 0.03f;

        // Clamp between 0 and 1
        return std::clamp(warmth, 0.0f, 1.0f);
    }

    float SurvivalUtils::CalculateColdExposure(RE::Actor* actor)
    {
        if (!actor) return 0.0f;

        float exposure = 0.0f;

        // Base weather factor
        float weatherFactor = GetWeatherColdFactor();
        exposure += weatherFactor * 0.5f;

        // Region factor
        if (IsInColdRegion(actor)) {
            exposure += 0.3f;
        }

        // Interior check - warm interiors reduce exposure
        if (IsInWarmInterior(actor)) {
            exposure = 0.0f;  // No cold exposure in warm interiors
        }

        // Near heat source reduces exposure
        if (IsNearHeatSource(actor)) {
            exposure = std::max(0.0f, exposure - 0.5f);
        }

        // Armor warmth reduces exposure
        // Warmth of 0.5 = 50% reduction in cold exposure
        // Warmth of 1.0 = nearly full protection
        float armorWarmth = GetArmorWarmthFactor(actor);
        exposure = exposure * (1.0f - armorWarmth * 0.8f);  // Armor can reduce up to 80% of exposure

        return std::min(1.0f, std::max(0.0f, exposure));  // Clamp 0-1
    }

    // ========================================================================
    // HEAT SOURCE DETECTION
    // ========================================================================

    const std::unordered_set<RE::FormID>& SurvivalUtils::GetHeatSourceKeywords()
    {
        // Cache heat source keyword FormIDs
        static std::unordered_set<RE::FormID> keywords;
        static bool initialized = false;

        if (!initialized) {
            // Try to find common heat-related keywords
            const char* keywordNames[] = {
                "isSmithingWorkbench",    // Forges
                "FurnitureForge",
                "isEnchantingWorkbench",  // Some enchanting setups have braziers
                "CraftingCookpot",        // Cooking fires
                "CraftingFireplace",
                "CraftingOven",
                "isCampfireFurniture",    // Campfire mod
                "Campfire_Keyword",
                "CampfireKeyword"
            };

            for (const char* name : keywordNames) {
                auto* keyword = RE::TESForm::LookupByEditorID<RE::BGSKeyword>(name);
                if (keyword) {
                    keywords.insert(keyword->GetFormID());
                    SKSE::log::info("SurvivalUtils: Found heat source keyword: {}", name);
                }
            }

            initialized = true;
        }

        return keywords;
    }

    bool SurvivalUtils::IsHeatSourceReference(RE::TESObjectREFR* ref)
    {
        if (!ref) return false;

        auto* baseForm = ref->GetBaseObject();
        if (!baseForm) return false;

        // Check by name (case-insensitive)
        const char* name = ref->GetName();
        if (!name) {
            name = baseForm->GetName();
        }

        if (name && name[0] != '\0') {
            std::string lowerName = StringUtils::ToLower(name);

            // Heat source name patterns
            if (lowerName.find("fire") != std::string::npos ||
                lowerName.find("campfire") != std::string::npos ||
                lowerName.find("hearth") != std::string::npos ||
                lowerName.find("forge") != std::string::npos ||
                lowerName.find("brazier") != std::string::npos ||
                lowerName.find("bonfire") != std::string::npos ||
                lowerName.find("cookfire") != std::string::npos ||
                lowerName.find("firepit") != std::string::npos ||
                lowerName.find("fire pit") != std::string::npos ||
                lowerName.find("torch") != std::string::npos) {
                return true;
            }
        }

        // Check by keyword
        auto* keywordForm = baseForm->As<RE::BGSKeywordForm>();
        if (keywordForm) {
            const auto& heatKeywords = GetHeatSourceKeywords();
            for (uint32_t i = 0; i < keywordForm->numKeywords; ++i) {
                auto* kw = keywordForm->keywords[i];
                if (kw && heatKeywords.contains(kw->GetFormID())) {
                    return true;
                }
            }
        }

        // Check for light-emitting objects that might be fires
        if (auto* light = baseForm->As<RE::TESObjectLIGH>()) {
            // Fires typically have a reddish/orange tint
            // Check if light color is warm (high red, medium green, low blue)
            // Note: This is a heuristic
            if (light->data.color.red > 200 &&
                light->data.color.green < 200 &&
                light->data.color.blue < 150) {
                // Probably a fire-type light
                return true;
            }
        }

        return false;
    }

    bool SurvivalUtils::IsNearHeatSource(RE::Actor* actor, float radius)
    {
        return GetDistanceToNearestHeatSource(actor, radius) >= 0.0f;
    }

    float SurvivalUtils::GetDistanceToNearestHeatSource(RE::Actor* actor, float maxRadius)
    {
        if (!actor) return -1.0f;

        auto* cell = actor->GetParentCell();
        if (!cell) return -1.0f;

        RE::NiPoint3 actorPos = actor->GetPosition();
        float nearestDistSq = maxRadius * maxRadius + 1.0f;  // Start beyond max

        // Search all references in cell (campfires, hearths, etc.)
        for (const auto& refPtr : cell->GetRuntimeData().references) {
            auto* ref = refPtr.get();
            if (!ref || ref == actor) continue;

            // Check if this is a heat source
            if (IsHeatSourceReference(ref)) {
                RE::NiPoint3 refPos = ref->GetPosition();
                float dx = actorPos.x - refPos.x;
                float dy = actorPos.y - refPos.y;
                float dz = actorPos.z - refPos.z;
                float distSq = dx * dx + dy * dy + dz * dz;

                if (distSq < nearestDistSq) {
                    nearestDistSq = distSq;
                }
            }
        }

        if (nearestDistSq <= maxRadius * maxRadius) {
            return std::sqrt(nearestDistSq);
        }

        return -1.0f;  // Not found
    }

    bool SurvivalUtils::IsNearCampfire(RE::Actor* actor, float radius)
    {
        if (!actor) return false;

        auto* cell = actor->GetParentCell();
        if (!cell) return false;

        RE::NiPoint3 actorPos = actor->GetPosition();
        float radiusSq = radius * radius;

        for (const auto& refPtr : cell->GetRuntimeData().references) {
            auto* ref = refPtr.get();
            if (!ref) continue;

            // Check name for campfire specifically
            const char* name = ref->GetName();
            if (!name) {
                auto* baseForm = ref->GetBaseObject();
                if (baseForm) name = baseForm->GetName();
            }

            if (name && name[0] != '\0') {
                std::string lowerName = StringUtils::ToLower(name);
                if (lowerName.find("campfire") != std::string::npos ||
                    lowerName.find("bonfire") != std::string::npos) {

                    RE::NiPoint3 refPos = ref->GetPosition();
                    float dx = actorPos.x - refPos.x;
                    float dy = actorPos.y - refPos.y;
                    float dz = actorPos.z - refPos.z;
                    float distSq = dx * dx + dy * dy + dz * dz;

                    if (distSq <= radiusSq) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    bool SurvivalUtils::IsNearForge(RE::Actor* actor, float radius)
    {
        if (!actor) return false;

        auto* cell = actor->GetParentCell();
        if (!cell) return false;

        RE::NiPoint3 actorPos = actor->GetPosition();
        float radiusSq = radius * radius;

        for (const auto& refPtr : cell->GetRuntimeData().references) {
            auto* ref = refPtr.get();
            if (!ref) continue;

            const char* name = ref->GetName();
            if (!name) {
                auto* baseForm = ref->GetBaseObject();
                if (baseForm) name = baseForm->GetName();
            }

            if (name && name[0] != '\0') {
                std::string lowerName = StringUtils::ToLower(name);
                if (lowerName.find("forge") != std::string::npos ||
                    lowerName.find("smithing") != std::string::npos) {

                    RE::NiPoint3 refPos = ref->GetPosition();
                    float dx = actorPos.x - refPos.x;
                    float dy = actorPos.y - refPos.y;
                    float dz = actorPos.z - refPos.z;
                    float distSq = dx * dx + dy * dy + dz * dz;

                    if (distSq <= radiusSq) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    bool SurvivalUtils::IsNearHearth(RE::Actor* actor, float radius)
    {
        if (!actor) return false;

        auto* cell = actor->GetParentCell();
        if (!cell) return false;

        RE::NiPoint3 actorPos = actor->GetPosition();
        float radiusSq = radius * radius;

        for (const auto& refPtr : cell->GetRuntimeData().references) {
            auto* ref = refPtr.get();
            if (!ref) continue;

            const char* name = ref->GetName();
            if (!name) {
                auto* baseForm = ref->GetBaseObject();
                if (baseForm) name = baseForm->GetName();
            }

            if (name && name[0] != '\0') {
                std::string lowerName = StringUtils::ToLower(name);
                if (lowerName.find("hearth") != std::string::npos ||
                    lowerName.find("fireplace") != std::string::npos) {

                    RE::NiPoint3 refPos = ref->GetPosition();
                    float dx = actorPos.x - refPos.x;
                    float dy = actorPos.y - refPos.y;
                    float dz = actorPos.z - refPos.z;
                    float distSq = dx * dx + dy * dy + dz * dz;

                    if (distSq <= radiusSq) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    bool SurvivalUtils::IsInWarmInterior(RE::Actor* actor)
    {
        if (!actor) return false;

        auto* cell = actor->GetParentCell();
        if (!cell) return false;

        // Only interiors can be "warm interiors"
        if (!cell->IsInteriorCell()) {
            return false;
        }

        // Check if there's a heat source in the interior
        // Most interiors with NPCs have a fire somewhere
        for (const auto& refPtr : cell->GetRuntimeData().references) {
            auto* ref = refPtr.get();
            if (!ref) continue;

            if (IsHeatSourceReference(ref)) {
                return true;  // Interior has a fire = warm
            }
        }

        // No fire found, but still an interior - moderately warm
        // We'll consider it warm if it has NPCs living there
        // (indicated by having containers, beds, etc.)
        // For now, assume all interiors are at least partially warm
        return true;
    }

    // ========================================================================
    // SURVIVAL DATA STORAGE
    // ========================================================================

    float SurvivalUtils::GetLastAteTime(RE::Actor* actor)
    {
        if (!actor) return 0.0f;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            return it->second.lastAteGameTime;
        }
        return 0.0f;
    }

    void SurvivalUtils::SetLastAteTime(RE::Actor* actor, float gameTime)
    {
        if (!actor) return;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            it->second.lastAteGameTime = gameTime;
        }
    }

    float SurvivalUtils::GetLastSleptTime(RE::Actor* actor)
    {
        if (!actor) return 0.0f;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            return it->second.lastSleptGameTime;
        }
        return 0.0f;
    }

    void SurvivalUtils::SetLastSleptTime(RE::Actor* actor, float gameTime)
    {
        if (!actor) return;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            it->second.lastSleptGameTime = gameTime;
        }
    }

    float SurvivalUtils::GetLastWarmedTime(RE::Actor* actor)
    {
        if (!actor) return 0.0f;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            return it->second.lastWarmedGameTime;
        }
        return 0.0f;
    }

    void SurvivalUtils::SetLastWarmedTime(RE::Actor* actor, float gameTime)
    {
        if (!actor) return;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            it->second.lastWarmedGameTime = gameTime;
        }
    }

    int32_t SurvivalUtils::GetHungerLevel(RE::Actor* actor)
    {
        if (!actor) return 0;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            return it->second.hungerLevel;
        }
        return 0;
    }

    void SurvivalUtils::SetHungerLevel(RE::Actor* actor, int32_t level)
    {
        if (!actor) return;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            it->second.hungerLevel = std::clamp(level, 0, 100);
        }
    }

    int32_t SurvivalUtils::GetFatigueLevel(RE::Actor* actor)
    {
        if (!actor) return 0;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            return it->second.fatigueLevel;
        }
        return 0;
    }

    void SurvivalUtils::SetFatigueLevel(RE::Actor* actor, int32_t level)
    {
        if (!actor) return;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            it->second.fatigueLevel = std::clamp(level, 0, 100);
        }
    }

    int32_t SurvivalUtils::GetColdLevel(RE::Actor* actor)
    {
        if (!actor) return 0;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            return it->second.coldLevel;
        }
        return 0;
    }

    void SurvivalUtils::SetColdLevel(RE::Actor* actor, int32_t level)
    {
        if (!actor) return;

        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_trackedFollowers.find(actor->GetFormID());
        if (it != m_trackedFollowers.end()) {
            it->second.coldLevel = std::clamp(level, 0, 100);
        }
    }

    void SurvivalUtils::ClearActorData(RE::Actor* actor)
    {
        StopTracking(actor);
    }

    // ========================================================================
    // UTILITY FUNCTIONS
    // ========================================================================

    float SurvivalUtils::GetGameTimeInSeconds()
    {
        auto* calendar = RE::Calendar::GetSingleton();
        if (!calendar) return 0.0f;

        // GetCurrentGameTime returns days, convert to game seconds
        // 24 hours per day * 3631 seconds per game hour
        return calendar->GetCurrentGameTime() * 24.0f * SECONDS_PER_GAME_HOUR;
    }

    float SurvivalUtils::GameHoursToSeconds(float hours)
    {
        return hours * SECONDS_PER_GAME_HOUR;
    }

    // ========================================================================
    // PAPYRUS NATIVE FUNCTION WRAPPERS
    // ========================================================================

    bool SurvivalUtils::Papyrus_StartTracking(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->StartTracking(actor);
    }

    void SurvivalUtils::Papyrus_StopTracking(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        GetSingleton()->StopTracking(actor);
    }

    bool SurvivalUtils::Papyrus_IsTracked(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->IsTracked(actor);
    }

    int32_t SurvivalUtils::Papyrus_GetTrackedCount(RE::StaticFunctionTag*)
    {
        return GetSingleton()->GetTrackedCount();
    }

    std::vector<RE::Actor*> SurvivalUtils::Papyrus_GetTrackedFollowers(RE::StaticFunctionTag*)
    {
        return GetSingleton()->GetTrackedFollowers();
    }

    std::vector<RE::Actor*> SurvivalUtils::Papyrus_GetCurrentFollowers(RE::StaticFunctionTag*)
    {
        return GetSingleton()->GetCurrentFollowers();
    }

    bool SurvivalUtils::Papyrus_IsFoodItem(RE::StaticFunctionTag*, RE::TESForm* form)
    {
        return IsFoodItem(form);
    }

    int32_t SurvivalUtils::Papyrus_GetFoodRestoreValue(RE::StaticFunctionTag*, RE::TESForm* form)
    {
        return GetFoodRestoreValue(form);
    }

    float SurvivalUtils::Papyrus_GetWeatherColdFactor(RE::StaticFunctionTag*)
    {
        return GetWeatherColdFactor();
    }

    int32_t SurvivalUtils::Papyrus_GetWeatherClassification(RE::StaticFunctionTag*)
    {
        return GetWeatherClassification();
    }

    bool SurvivalUtils::Papyrus_IsSnowingWeather(RE::StaticFunctionTag*)
    {
        return IsSnowingWeather();
    }

    bool SurvivalUtils::Papyrus_IsInColdRegion(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return IsInColdRegion(actor);
    }

    float SurvivalUtils::Papyrus_CalculateColdExposure(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return CalculateColdExposure(actor);
    }

    float SurvivalUtils::Papyrus_GetArmorWarmthFactor(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetArmorWarmthFactor(actor);
    }

    bool SurvivalUtils::Papyrus_IsNearHeatSource(RE::StaticFunctionTag*, RE::Actor* actor, float radius)
    {
        return IsNearHeatSource(actor, radius);
    }

    float SurvivalUtils::Papyrus_GetDistanceToNearestHeatSource(RE::StaticFunctionTag*, RE::Actor* actor, float maxRadius)
    {
        return GetDistanceToNearestHeatSource(actor, maxRadius);
    }

    bool SurvivalUtils::Papyrus_IsNearCampfire(RE::StaticFunctionTag*, RE::Actor* actor, float radius)
    {
        return IsNearCampfire(actor, radius);
    }

    bool SurvivalUtils::Papyrus_IsNearForge(RE::StaticFunctionTag*, RE::Actor* actor, float radius)
    {
        return IsNearForge(actor, radius);
    }

    bool SurvivalUtils::Papyrus_IsNearHearth(RE::StaticFunctionTag*, RE::Actor* actor, float radius)
    {
        return IsNearHearth(actor, radius);
    }

    bool SurvivalUtils::Papyrus_IsInWarmInterior(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return IsInWarmInterior(actor);
    }

    float SurvivalUtils::Papyrus_GetLastAteTime(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->GetLastAteTime(actor);
    }

    void SurvivalUtils::Papyrus_SetLastAteTime(RE::StaticFunctionTag*, RE::Actor* actor, float gameTime)
    {
        GetSingleton()->SetLastAteTime(actor, gameTime);
    }

    float SurvivalUtils::Papyrus_GetLastSleptTime(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->GetLastSleptTime(actor);
    }

    void SurvivalUtils::Papyrus_SetLastSleptTime(RE::StaticFunctionTag*, RE::Actor* actor, float gameTime)
    {
        GetSingleton()->SetLastSleptTime(actor, gameTime);
    }

    float SurvivalUtils::Papyrus_GetLastWarmedTime(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->GetLastWarmedTime(actor);
    }

    void SurvivalUtils::Papyrus_SetLastWarmedTime(RE::StaticFunctionTag*, RE::Actor* actor, float gameTime)
    {
        GetSingleton()->SetLastWarmedTime(actor, gameTime);
    }

    int32_t SurvivalUtils::Papyrus_GetHungerLevel(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->GetHungerLevel(actor);
    }

    void SurvivalUtils::Papyrus_SetHungerLevel(RE::StaticFunctionTag*, RE::Actor* actor, int32_t level)
    {
        GetSingleton()->SetHungerLevel(actor, level);
    }

    int32_t SurvivalUtils::Papyrus_GetFatigueLevel(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->GetFatigueLevel(actor);
    }

    void SurvivalUtils::Papyrus_SetFatigueLevel(RE::StaticFunctionTag*, RE::Actor* actor, int32_t level)
    {
        GetSingleton()->SetFatigueLevel(actor, level);
    }

    int32_t SurvivalUtils::Papyrus_GetColdLevel(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return GetSingleton()->GetColdLevel(actor);
    }

    void SurvivalUtils::Papyrus_SetColdLevel(RE::StaticFunctionTag*, RE::Actor* actor, int32_t level)
    {
        GetSingleton()->SetColdLevel(actor, level);
    }

    void SurvivalUtils::Papyrus_ClearActorData(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        GetSingleton()->ClearActorData(actor);
    }

    float SurvivalUtils::Papyrus_GetGameTimeInSeconds(RE::StaticFunctionTag*)
    {
        return GetGameTimeInSeconds();
    }

    void SurvivalUtils::RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        // Follower tracking
        a_vm->RegisterFunction("Survival_StartTracking", scriptName, Papyrus_StartTracking);
        a_vm->RegisterFunction("Survival_StopTracking", scriptName, Papyrus_StopTracking);
        a_vm->RegisterFunction("Survival_IsTracked", scriptName, Papyrus_IsTracked);
        a_vm->RegisterFunction("Survival_GetTrackedCount", scriptName, Papyrus_GetTrackedCount);
        a_vm->RegisterFunction("Survival_GetTrackedFollowers", scriptName, Papyrus_GetTrackedFollowers);
        a_vm->RegisterFunction("Survival_GetCurrentFollowers", scriptName, Papyrus_GetCurrentFollowers);

        // Food detection
        a_vm->RegisterFunction("Survival_IsFoodItem", scriptName, Papyrus_IsFoodItem);
        a_vm->RegisterFunction("Survival_GetFoodRestoreValue", scriptName, Papyrus_GetFoodRestoreValue);

        // Weather & cold
        a_vm->RegisterFunction("Survival_GetWeatherColdFactor", scriptName, Papyrus_GetWeatherColdFactor);
        a_vm->RegisterFunction("Survival_GetWeatherClassification", scriptName, Papyrus_GetWeatherClassification);
        a_vm->RegisterFunction("Survival_IsSnowingWeather", scriptName, Papyrus_IsSnowingWeather);
        a_vm->RegisterFunction("Survival_IsInColdRegion", scriptName, Papyrus_IsInColdRegion);
        a_vm->RegisterFunction("Survival_CalculateColdExposure", scriptName, Papyrus_CalculateColdExposure);
        a_vm->RegisterFunction("Survival_GetArmorWarmthFactor", scriptName, Papyrus_GetArmorWarmthFactor);

        // Heat sources
        a_vm->RegisterFunction("Survival_IsNearHeatSource", scriptName, Papyrus_IsNearHeatSource);
        a_vm->RegisterFunction("Survival_GetDistanceToNearestHeatSource", scriptName, Papyrus_GetDistanceToNearestHeatSource);
        a_vm->RegisterFunction("Survival_IsNearCampfire", scriptName, Papyrus_IsNearCampfire);
        a_vm->RegisterFunction("Survival_IsNearForge", scriptName, Papyrus_IsNearForge);
        a_vm->RegisterFunction("Survival_IsNearHearth", scriptName, Papyrus_IsNearHearth);
        a_vm->RegisterFunction("Survival_IsInWarmInterior", scriptName, Papyrus_IsInWarmInterior);

        // Survival data storage
        a_vm->RegisterFunction("Survival_GetLastAteTime", scriptName, Papyrus_GetLastAteTime);
        a_vm->RegisterFunction("Survival_SetLastAteTime", scriptName, Papyrus_SetLastAteTime);
        a_vm->RegisterFunction("Survival_GetLastSleptTime", scriptName, Papyrus_GetLastSleptTime);
        a_vm->RegisterFunction("Survival_SetLastSleptTime", scriptName, Papyrus_SetLastSleptTime);
        a_vm->RegisterFunction("Survival_GetLastWarmedTime", scriptName, Papyrus_GetLastWarmedTime);
        a_vm->RegisterFunction("Survival_SetLastWarmedTime", scriptName, Papyrus_SetLastWarmedTime);
        a_vm->RegisterFunction("Survival_GetHungerLevel", scriptName, Papyrus_GetHungerLevel);
        a_vm->RegisterFunction("Survival_SetHungerLevel", scriptName, Papyrus_SetHungerLevel);
        a_vm->RegisterFunction("Survival_GetFatigueLevel", scriptName, Papyrus_GetFatigueLevel);
        a_vm->RegisterFunction("Survival_SetFatigueLevel", scriptName, Papyrus_SetFatigueLevel);
        a_vm->RegisterFunction("Survival_GetColdLevel", scriptName, Papyrus_GetColdLevel);
        a_vm->RegisterFunction("Survival_SetColdLevel", scriptName, Papyrus_SetColdLevel);
        a_vm->RegisterFunction("Survival_ClearActorData", scriptName, Papyrus_ClearActorData);

        // Utility
        a_vm->RegisterFunction("Survival_GetGameTimeInSeconds", scriptName, Papyrus_GetGameTimeInSeconds);

        SKSE::log::info("Registered SurvivalUtils Papyrus functions");
    }
}
