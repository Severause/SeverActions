#pragma once

// SeverActionsNative - Collision Utilities
// Toggles NPC-NPC collision for traveling actors so they clip through other NPCs
// instead of getting blocked. Uses bhkCharacterController::kNoCharacterCollisions flag.
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>

namespace SeverActionsNative
{
    class CollisionUtils
    {
    public:
        /**
         * Set whether an actor can be bumped/blocked by other actors.
         * @param actor The actor to modify
         * @param bumpable true = normal collision (default), false = clip through other NPCs
         */
        static void SetBumpable(RE::Actor* actor, bool bumpable)
        {
            if (!actor) {
                SKSE::log::warn("CollisionUtils::SetBumpable - actor is null");
                return;
            }

            auto* charController = actor->GetCharController();
            if (!charController) {
                // Character controller is null when 3D isn't loaded (NPC in unloaded cell)
                // This is expected for cross-cell travel — not an error
                SKSE::log::debug("CollisionUtils::SetBumpable - no character controller for {:X} (3D not loaded)",
                    actor->GetFormID());
                return;
            }

            if (bumpable) {
                // Restore normal collision — clear the no-collision flag
                charController->flags.reset(RE::CHARACTER_FLAGS::kNoCharacterCollisions);
                SKSE::log::debug("CollisionUtils: Enabled NPC collision for {:X}", actor->GetFormID());
            } else {
                // Disable NPC-NPC collision — set the no-collision flag
                charController->flags.set(RE::CHARACTER_FLAGS::kNoCharacterCollisions);
                SKSE::log::debug("CollisionUtils: Disabled NPC collision for {:X}", actor->GetFormID());
            }
        }

        /**
         * Check if an actor currently has normal NPC-NPC collision enabled.
         * @param actor The actor to check
         * @return true if bumpable (normal), false if clipping through NPCs
         */
        static bool IsBumpable(RE::Actor* actor)
        {
            if (!actor) return true;

            auto* charController = actor->GetCharController();
            if (!charController) return true;  // Assume normal if no controller

            // If the no-collision flag is set, the actor is NOT bumpable
            return !charController->flags.any(RE::CHARACTER_FLAGS::kNoCharacterCollisions);
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static void Papyrus_SetActorBumpable(RE::StaticFunctionTag*, RE::Actor* actor, bool bumpable)
        {
            SetBumpable(actor, bumpable);
        }

        static bool Papyrus_IsActorBumpable(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return IsBumpable(actor);
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("SetActorBumpable", scriptName, Papyrus_SetActorBumpable);
            a_vm->RegisterFunction("IsActorBumpable", scriptName, Papyrus_IsActorBumpable);

            SKSE::log::info("Registered collision utility functions");
        }
    };
}
