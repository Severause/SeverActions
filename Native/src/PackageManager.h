#pragma once

// SeverActionsNative - Package Manager
// Native LinkedRef management with SKSE cosave persistence.
// Drop-in replacement for PO3_SKSEFunctions.SetLinkedRef with auto-tracking.
//
// Key features:
//   - Sets/clears LinkedRefs natively via RE::ExtraLinkedRef
//   - Tracks all active LinkedRefs in a map
//   - Persists to SKSE cosave — survives save/load automatically
//   - Auto-restores all LinkedRefs on kPostLoadGame
//   - Auto-cleans on actor death (TESDeathEvent)
//   - Native EvaluatePackage() for minor Papyrus VM overhead reduction
//
// Does NOT replace ActorUtil.AddPackageOverride/RemovePackageOverride —
// PO3's package override system hooks into SKSE internals and should not
// be duplicated.
//
// Thread safety: m_tracked map protected by mutex. Native LinkedRef
// manipulation runs on game thread (Papyrus calls + cosave restore).
//
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <unordered_map>
#include <vector>
#include <mutex>

namespace SeverActionsNative
{
    /**
     * Tracked LinkedRef entry for cosave persistence
     * Each entry represents one actor -> target link via a keyword
     */
    struct LinkedRefEntry
    {
        RE::FormID actorFormID;
        RE::FormID targetFormID;
        RE::FormID keywordFormID;
    };

    /**
     * PackageManager — Native LinkedRef management with cosave persistence
     *
     * Replaces PO3_SKSEFunctions.SetLinkedRef across all SeverActions scripts.
     * Every Set/Clear call is tracked in m_tracked map and serialized to the
     * SKSE cosave. On game load, all tracked LinkedRefs are automatically
     * restored, eliminating the need for Papyrus Maintenance() re-link code.
     *
     * Death auto-cleanup: When a tracked actor dies, all their LinkedRef
     * entries are removed from the tracking map and the native ExtraLinkedRef
     * data is cleared. This prevents orphaned linked refs if the actor is
     * later revived (console, mods, essential bleedout).
     */
    class PackageManager :
        public RE::BSTEventSink<RE::TESDeathEvent>
    {
    public:
        static PackageManager* GetSingleton();

        // Initialize — register for TESDeathEvent. Call from plugin.cpp kDataLoaded.
        void Initialize();

        // ====================================================================
        // LINKED REF OPERATIONS
        // ====================================================================

        /**
         * Set a LinkedRef on an actor. Replaces PO3_SKSEFunctions.SetLinkedRef.
         * Automatically tracked for cosave persistence.
         */
        void LinkedRef_Set(RE::Actor* actor, RE::TESObjectREFR* target, RE::BGSKeyword* keyword);

        /**
         * Clear a LinkedRef on an actor. Removes from persistence tracking.
         */
        void LinkedRef_Clear(RE::Actor* actor, RE::BGSKeyword* keyword);

        /**
         * Clear ALL tracked LinkedRefs on an actor.
         * Used during full cleanup (e.g. dismiss follower, cancel arrest).
         */
        void LinkedRef_ClearAll(RE::Actor* actor);

        /**
         * Check if an actor has any tracked LinkedRefs. Debug/diagnostic.
         */
        bool LinkedRef_HasAny(RE::Actor* actor) const;

        /**
         * Get total count of tracked LinkedRef entries across all actors. Debug.
         */
        int32_t LinkedRef_GetTrackedCount() const;

        /**
         * Call EvaluatePackage natively. Avoids Papyrus VM overhead.
         */
        static void NativeEvaluatePackage(RE::Actor* actor);

        // ====================================================================
        // COSAVE RESTORE
        // ====================================================================

        /**
         * Restore all tracked LinkedRefs from cosave data.
         * Call on kPostLoadGame — by this point all forms are loaded.
         * Safe to call on kNewGame too (no-ops if map is empty).
         */
        void RestoreAllLinkedRefs();

        // ====================================================================
        // SKSE COSAVE CALLBACKS (static)
        // ====================================================================

        static void OnSave(SKSE::SerializationInterface* a_intfc);
        static void OnLoad(SKSE::SerializationInterface* a_intfc);
        static void OnRevert(SKSE::SerializationInterface* a_intfc);

        // Serialization constants
        static constexpr std::uint32_t kUniqueID = 'SVAN';            // SeverActionsNative
        static constexpr std::uint32_t kLinkedRefRecord = 'LREF';     // LinkedRef tracking
        static constexpr std::uint32_t kSerializationVersion = 1;

        // ====================================================================
        // DEATH EVENT HANDLER
        // ====================================================================

        RE::BSEventNotifyControl ProcessEvent(
            const RE::TESDeathEvent* a_event,
            RE::BSTEventSource<RE::TESDeathEvent>* a_eventSource) override;

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static void Papyrus_LinkedRef_Set(RE::StaticFunctionTag*,
            RE::Actor* actor, RE::TESObjectREFR* target, RE::BGSKeyword* keyword);
        static void Papyrus_LinkedRef_Clear(RE::StaticFunctionTag*,
            RE::Actor* actor, RE::BGSKeyword* keyword);
        static void Papyrus_LinkedRef_ClearAll(RE::StaticFunctionTag*,
            RE::Actor* actor);
        static bool Papyrus_LinkedRef_HasAny(RE::StaticFunctionTag*,
            RE::Actor* actor);
        static int32_t Papyrus_LinkedRef_GetTrackedCount(RE::StaticFunctionTag*);
        static void Papyrus_NativeEvaluatePackage(RE::StaticFunctionTag*,
            RE::Actor* actor);

        /**
         * Register all package manager functions with Papyrus VM
         */
        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName);

    private:
        PackageManager() = default;
        ~PackageManager() = default;
        PackageManager(const PackageManager&) = delete;
        PackageManager& operator=(const PackageManager&) = delete;

        /**
         * Native LinkedRef manipulation via RE::ExtraLinkedRef
         * Sets or clears a LinkedRef on a reference's extra data list.
         * Must be called on the game thread.
         *
         * @param ref     The reference to modify
         * @param target  The target to link to (nullptr to clear)
         * @param keyword The keyword identifying this link type
         */
        static void NativeSetLinkedRef(RE::TESObjectREFR* ref,
            RE::TESObjectREFR* target, RE::BGSKeyword* keyword);

        // Tracking map: actorFormID -> vector of LinkedRefEntries (one per keyword)
        std::unordered_map<RE::FormID, std::vector<LinkedRefEntry>> m_tracked;

        mutable std::mutex m_mutex;
        bool m_initialized = false;
    };
}
