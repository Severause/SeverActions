#pragma once

// SeverActionsNative - Guard Finder
// Native nearby guard search replacing Papyrus cell iteration + faction checks
// Pre-resolves guard factions at kDataLoaded for O(1) lookup
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <vector>

namespace SeverActionsNative
{
    /**
     * Native guard finder
     *
     * Replaces the Papyrus FindNearestGuard() which:
     *   - Builds a 9-element faction array per call
     *   - Iterates GetNumRefs(43) + GetNthRef() on the cell
     *   - Checks IsInFaction() 9 times per candidate
     *
     * Native version:
     *   - Pre-resolves guard factions once at kDataLoaded
     *   - Single ForEachReferenceInRange pass
     *   - Early exit on first faction match per candidate
     */
    class GuardFinder
    {
    public:
        static GuardFinder& GetInstance()
        {
            static GuardFinder instance;
            return instance;
        }

        /**
         * Initialize by resolving guard faction FormIDs from Skyrim.esm
         * Called once at kDataLoaded
         */
        void Initialize()
        {
            m_guardFactions.clear();

            auto* handler = RE::TESDataHandler::GetSingleton();
            if (!handler) {
                SKSE::log::error("GuardFinder: TESDataHandler not available");
                return;
            }

            // Vanilla guard factions from Skyrim.esm
            // These are the actual guard factions (NOT crime factions which include all citizens)
            struct FactionDef {
                RE::FormID formId;
                const char* name;
            };

            static constexpr FactionDef kGuardFactions[] = {
                { 0x0002BE39, "GuardFactionWhiterun" },
                { 0x000D27F2, "GuardFactionRiften" },
                { 0x0002EBEE, "GuardFactionSolitude" },
                { 0x000367BA, "GuardFactionHaafingar" },
                { 0x000D27F3, "GuardFactionWindhelm" },
                { 0x00018AAC, "GuardFactionMarkarth" },
                { 0x0002EBEC, "GuardFactionFalkreath" },
                { 0x0003B693, "GuardFactionDawnstar" },
                // Winterhold has no vanilla guard faction
            };

            for (const auto& def : kGuardFactions) {
                auto* faction = RE::TESForm::LookupByID<RE::TESFaction>(def.formId);
                if (faction) {
                    m_guardFactions.push_back(faction);
                    SKSE::log::trace("GuardFinder: Resolved {} (0x{:08X})", def.name, def.formId);
                } else {
                    SKSE::log::warn("GuardFinder: Could not resolve {} (0x{:08X})", def.name, def.formId);
                }
            }

            SKSE::log::info("GuardFinder: Initialized with {} guard factions", m_guardFactions.size());
        }

        /**
         * Find the nearest guard within searchRadius of the given actor
         *
         * Criteria:
         *   - 3D loaded, not disabled
         *   - Not dead
         *   - Not in combat
         *   - In at least one vanilla guard faction
         *   - Not the search actor itself
         *
         * @param akNearActor  Actor to search around
         * @param searchRadius Maximum search distance (default 3000)
         * @return Nearest valid guard Actor, or nullptr
         */
        RE::Actor* FindNearestGuard(RE::Actor* akNearActor, float searchRadius = 3000.0f)
        {
            if (!akNearActor) return nullptr;

            if (m_guardFactions.empty()) {
                SKSE::log::warn("GuardFinder: No guard factions loaded — was Initialize() called?");
                return nullptr;
            }

            auto* cell = akNearActor->GetParentCell();
            if (!cell) return nullptr;

            auto searchPos = akNearActor->GetPosition();
            RE::Actor* bestGuard = nullptr;
            float bestDist = searchRadius + 1.0f;

            cell->ForEachReferenceInRange(searchPos, searchRadius, [&](RE::TESObjectREFR& ref) -> RE::BSContainer::ForEachResult {
                // Skip non-actors, disabled, unloaded
                if (&ref == akNearActor || ref.IsDisabled() || !ref.Is3DLoaded()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                auto* actor = ref.As<RE::Actor>();
                if (!actor) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                // Skip dead and in-combat
                if (actor->IsDead() || actor->IsInCombat()) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                // Check if this actor is in any guard faction
                bool isGuard = false;
                for (auto* faction : m_guardFactions) {
                    if (actor->IsInFaction(faction)) {
                        isGuard = true;
                        break;
                    }
                }

                if (!isGuard) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                // Valid guard — check distance (2D, no Z)
                auto guardPos = actor->GetPosition();
                float dx = searchPos.x - guardPos.x;
                float dy = searchPos.y - guardPos.y;
                float dist = std::sqrt(dx * dx + dy * dy);

                if (dist < bestDist) {
                    bestDist = dist;
                    bestGuard = actor;
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            if (bestGuard) {
                SKSE::log::info("GuardFinder: Found guard {} (0x{:08X}) at distance {:.0f}",
                    bestGuard->GetDisplayFullName(), bestGuard->GetFormID(), bestDist);
            } else {
                SKSE::log::trace("GuardFinder: No guard found within {:.0f} of {} (0x{:08X})",
                    searchRadius, akNearActor->GetDisplayFullName(), akNearActor->GetFormID());
            }

            return bestGuard;
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static RE::Actor* Papyrus_FindNearestGuard(RE::StaticFunctionTag*, RE::Actor* akNearActor, float searchRadius)
        {
            return GetInstance().FindNearestGuard(akNearActor, searchRadius);
        }

        /**
         * Register all guard finder functions with Papyrus VM
         */
        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("FindNearestGuard", scriptName, Papyrus_FindNearestGuard);

            SKSE::log::info("Registered guard finder functions");
        }

    private:
        GuardFinder() = default;
        ~GuardFinder() = default;
        GuardFinder(const GuardFinder&) = delete;
        GuardFinder& operator=(const GuardFinder&) = delete;

        std::vector<RE::TESFaction*> m_guardFactions;  // Pre-resolved guard factions
    };
}
