Scriptname SeverActions_Combat extends Quest
{Combat actions for SkyrimNet - handles attack commands, yield/surrender with faction conversion, and combat state tracking via StorageUtil}

; ============================================================================
; PROPERTIES
; ============================================================================

; Vanilla follower faction - used for reference only now
Faction Property CurrentFollowerFaction Auto
{Set to CurrentFollowerFaction from Skyrim.esm}

; SkyrimNet follower faction (optional)
Faction Property SkyrimNetFollowerFaction Auto
{Set to SkyrimNet_FollowingPlayerFaction from SkyrimNet.esp if using SkyrimNet followers}

; Attack/Target factions — added to actors during AttackTarget so the AIO flee
; patch can suppress flee packages for NPCs actively engaged in forced combat.
; Removed when combat ends via RestoreOriginalValues.
Faction Property SeverActions_AttackFaction Auto
{Added to the attacker during AttackTarget. Suppresses AIO flee.}

Faction Property SeverActions_TargetFaction Auto
{Added to the target during AttackTarget. Suppresses AIO flee.}

; Cooldown duration in seconds
Float Property CombatCooldownDuration = 30.0 Auto
{How long before actors can be forced into combat again}

; ============================================================================
; SURRENDER FACTION SYSTEM
; ============================================================================

; Faction for surrendered enemies - set up in CK with player-friendly relations
Faction Property SeverSurrenderedFaction Auto
{Faction for NPCs who have surrendered. Set as Ally to PlayerFaction in CK.}

; FormList of hostile factions to replace when surrendering
; This allows adding/removing factions without recompiling
FormList Property SeverHostileFactions Auto
{FormList containing factions that should be replaced on surrender (Bandit, Forsworn, etc.)}

; ============================================================================
; YIELD PERSISTENCE ALIASES
; ============================================================================

ReferenceAlias[] Property YieldSlots Auto
{Array of 5 ReferenceAlias slots for yielded generic NPC persistence.
 When a hostile NPC (bandit, necromancer, etc.) surrenders, they're placed
 into a YieldSlot to prevent the engine from recycling them across cells.
 Each slot has SeverActions_YieldAlias attached for OnDeath cleanup.
 Fill in CK: Optional, Allow Reuse, Initially Cleared.}

Bool Property YieldPersistenceEnabled = true Auto
{Enable/disable yield alias persistence. When disabled, yielded generic NPCs
 may be recycled by the engine when crossing cells. Default: true.}

; ============================================================================
; STORAGEUTIL KEYS
; ============================================================================
; SeverCombat_CeasefireTime - Float (gameTimeNumeric when ceasefire occurred, auto-expires)
; SeverCombat_YieldTime - Float (gameTimeNumeric when yield occurred, auto-expires)
; SeverCombat_YieldedTo - Form (who this actor yielded to)
; SeverCombat_ReceivedYieldFrom - Form (who yielded to this actor)
; SeverCombat_InForcedCombat - Int (1 = currently in forced combat)
; SeverCombat_OriginalConfidence - Float (stored confidence value)
; SeverCombat_OriginalAggression - Float (stored aggression value for followers)
; SeverCombat_OriginalRelationship - Int
; SeverCombat_CombatTarget - Form (who they're fighting)
; SeverCombat_CooldownEnd - Float (LEGACY; replaced Phase 6 by native CombatCooldownStore)
; SeverCombat_WasSurrendered - Int (1 = this actor has surrendered)
; SeverCombat_WasNormallyHostile - Int (1 = at yield/ceasefire time they were
;     in a SeverHostileFactions member. Drives prompt-side guidance for
;     post-truce behaviour — bandits fall back to base hostility, guards/
;     housecarls/civilians get explicit "resolved conflict" stand-down.)
; SeverCombat_OriginalFaction - Form (the hostile faction they were removed from)
; SeverCombat_RemovedFactions - FormList (hostile factions removed during ConvertToSurrendered)
; SeverCombat_CeasefireRemovedFactions - FormList (hostile factions removed during ceasefire)
; SeverCombat_CeasefireFactionSwapped - Int (1 = faction swap occurred, restore on break)
; SeverCombat_NeedsAggroRestore - Int (1 = aggression was zeroed, needs delayed restore)
; SeverCombat_CeasefirePartner - Form (the other actor in the ceasefire pair)
; SeverCombat_YieldBroken - Int (1 = surrender was broken, set by OnYieldBroken)
;
; YIELD PERSISTENCE KEYS (stored on None via StorageUtil):
; SeverCombat_YieldedGenericActors - FormList (all yielded generic NPCs needing persistence)

; ============================================================================
; SINGLETON
; ============================================================================

SeverActions_Combat Function GetInstance() Global
    Quest kQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    Return kQuest as SeverActions_Combat
EndFunction

; ============================================================================
; INITIALIZATION
; ============================================================================

Event OnInit()
    RegisterForModEvent("SeverActionsNative_YieldBroken", "OnYieldBroken")
    RegisterForModEvent("SeverActionsNative_CeasefireBroken", "OnCeasefireBroken")
    RegisterForModEvent("SeverActions_ForcedCombatEnded", "OnForcedCombatEnded")

    ; Phase 5 — hand the configured factions to native CeasefireMonitor so
    ; it can do the full apply/restore cycle without Papyrus round-trips.
    ; Both are persisted in the C++ cosave, but we re-set on every init/load
    ; to cover fresh-game/reorder/upgrade cases.
    PushCeasefireConfigToNative()
EndEvent

Function PushCeasefireConfigToNative()
    If SeverSurrenderedFaction
        SeverActionsNativeExt.Ceasefire_SetSurrenderedFaction(SeverSurrenderedFaction)
        SeverActionsNativeExt.Yield_SetSurrenderedFaction(SeverSurrenderedFaction)
    EndIf
    If SeverHostileFactions
        SeverActionsNativeExt.Ceasefire_SetHostileFactionsList(SeverHostileFactions)
        SeverActionsNativeExt.Yield_SetHostileFactionsList(SeverHostileFactions)
    EndIf
EndFunction

; ============================================================================
; FORCED COMBAT END HOOK
; ============================================================================
; Native ForcedCombatMonitor (Native/src/ForcedCombatMonitor.h) sinks
; TESCombatEvent and fires this ModEvent when an actor flagged as
; InForcedCombat exits combat (target killed, escaped, scripted disengage,
; etc.). Without this hook, AttackTarget left stale state on the actor:
; Confidence=3, AttackFaction membership, InForcedCombat flag, stored
; relationship rank — and dismissed followers would walk off and re-engage
; other NPCs because the AIO patch and combat AI both still saw them as
; "in attack mode". FullCleanup is the existing nuclear-option restore that
; Yield and Ceasefire flows already call.

Event OnForcedCombatEnded(String eventName, String strArg, Float numArg, Form sender)
    Actor a = sender as Actor
    If !a
        Return
    EndIf
    Debug.Trace("[SeverCombat] ForcedCombatEnded for " + a.GetDisplayName() + " — running FullCleanup")
    FullCleanup(a)
EndEvent

; ============================================================================
; MAIN ATTACK FUNCTION
; ============================================================================

Function AttackTarget_Execute(Actor akAttacker, Actor akTarget)
{Forces akAttacker to attack akTarget. Also makes akTarget fight back.}
    
    If !akAttacker || !akTarget
        Debug.Trace("[SeverCombat] AttackTarget: Invalid actor(s)")
        Return
    EndIf
    
    If akAttacker.IsDead() || akTarget.IsDead()
        Debug.Trace("[SeverCombat] AttackTarget: One or both actors are dead")
        Return
    EndIf
    
    If akAttacker == akTarget
        Debug.Trace("[SeverCombat] AttackTarget: Cannot attack self")
        Return
    EndIf
    
    Debug.Trace("[SeverCombat] AttackTarget: " + akAttacker.GetDisplayName() + " -> " + akTarget.GetDisplayName())

    ; If either actor is currently surrendered or ceasefire'd, fully reset
    ; them first. Without this, we'd add them to the attack/target faction
    ; while they're still in SeverSurrenderedFaction and tracked by the yield
    ; or ceasefire monitor — the next incidental hit would fire YieldBroken/
    ; CeasefireBroken mid-scripted-combat and leave dual-faction state.
    If StorageUtil.GetIntValue(akAttacker, "SeverCombat_WasSurrendered", 0) == 1 || SeverActionsNative.Ceasefire_IsMonitored(akAttacker) || SeverActionsNative.IsYieldMonitored(akAttacker)
        Debug.Trace("[SeverCombat] AttackTarget: attacker " + akAttacker.GetDisplayName() + " was surrendered/ceasefire'd — running FullCleanup first")
        FullCleanup(akAttacker)
    EndIf
    If StorageUtil.GetIntValue(akTarget, "SeverCombat_WasSurrendered", 0) == 1 || SeverActionsNative.Ceasefire_IsMonitored(akTarget) || SeverActionsNative.IsYieldMonitored(akTarget)
        Debug.Trace("[SeverCombat] AttackTarget: target " + akTarget.GetDisplayName() + " was surrendered/ceasefire'd — running FullCleanup first")
        FullCleanup(akTarget)
    EndIf

    ; Clear any recent ceasefire/yield state
    StorageUtil.UnsetFloatValue(akAttacker, "SeverCombat_CeasefireTime")
    StorageUtil.UnsetFloatValue(akTarget, "SeverCombat_CeasefireTime")
    StorageUtil.UnsetFloatValue(akAttacker, "SeverCombat_YieldTime")
    StorageUtil.UnsetFloatValue(akTarget, "SeverCombat_YieldTime")
    StorageUtil.UnsetFormValue(akAttacker, "SeverCombat_YieldedTo")
    StorageUtil.UnsetFormValue(akTarget, "SeverCombat_YieldedTo")
    StorageUtil.UnsetFormValue(akAttacker, "SeverCombat_ReceivedYieldFrom")
    StorageUtil.UnsetFormValue(akTarget, "SeverCombat_ReceivedYieldFrom")

    ; Store original values for attacker (confidence only)
    StoreOriginalValues(akAttacker)

    ; Store original relationship ranks (both directions)
    Int origRankAtoT = akAttacker.GetRelationshipRank(akTarget)
    Int origRankTtoA = akTarget.GetRelationshipRank(akAttacker)
    StorageUtil.SetIntValue(akAttacker, "SeverCombat_OriginalRelationship", origRankAtoT)
    StorageUtil.SetIntValue(akTarget, "SeverCombat_OriginalRelationship", origRankTtoA)

    ; Store combat target references
    StorageUtil.SetFormValue(akAttacker, "SeverCombat_CombatTarget", akTarget)
    StorageUtil.SetFormValue(akTarget, "SeverCombat_CombatTarget", akAttacker)
    StorageUtil.SetIntValue(akAttacker, "SeverCombat_InForcedCombat", 1)
    StorageUtil.SetIntValue(akTarget, "SeverCombat_InForcedCombat", 1)
    SeverActionsNative.Native_SetInForcedCombat(akAttacker, true)
    SeverActionsNative.Native_SetInForcedCombat(akTarget, true)

    ; Add to attack/target factions so AIO flee patch can suppress flee packages
    If SeverActions_AttackFaction
        akAttacker.AddToFaction(SeverActions_AttackFaction)
    EndIf
    If SeverActions_TargetFaction
        akTarget.AddToFaction(SeverActions_TargetFaction)
    EndIf

    ; Prepare attacker for combat (confidence boost only)
    PrepareForCombat(akAttacker)
    
    ; Make them personal enemies - this is sufficient for combat
    ; NOTE: We no longer manipulate factions here. Faction changes caused issues
    ; where other actors (especially followers) would become hostile to unintended
    ; targets. StartCombat() + relationship rank is enough to force combat between
    ; these two specific actors without affecting anyone else.
    akAttacker.SetRelationshipRank(akTarget, -4)
    akTarget.SetRelationshipRank(akAttacker, -4)
    
    ; Start combat - attacker initiates
    akAttacker.StartCombat(akTarget)
    
    ; Make victim fight back
    Utility.Wait(0.2)
    akTarget.StartCombat(akAttacker)
    
    Debug.Trace("[SeverCombat] AttackTarget complete")
EndFunction

Bool Function AttackTarget_IsEligible(Actor akAttacker, Actor akTarget)
    If !akAttacker || !akTarget
        Return False
    EndIf
    If akAttacker.IsDead() || akTarget.IsDead()
        Return False
    EndIf
    If akAttacker == akTarget
        Return False
    EndIf
    If IsActorInCooldown(akAttacker)
        Return False
    EndIf
    Return True
EndFunction

; ============================================================================
; CEASEFIRE FUNCTION
; ============================================================================

Function CeaseFire_Execute(Actor akActor1, Actor akActor2)
{Forces two actors to stop fighting and propagates ceasefire to all nearby faction allies.
 Ceasefire is INDEFINITE — aggression stays at 0 until the player attacks them (monitored
 by native CeasefireMonitor) or an NPC calls AttackTarget (which clears ceasefire state).

 Phase 5: the per-actor faction-swap / aggression-zero / combat-stop /
 relationship-rank / monitor-registration sequence — previously ~80 lines
 of Papyrus repeated per affected actor — now lives in native
 CeasefireMonitor::PropagateGroup. We keep only the Papyrus-side timestamp
 bookkeeping the prompt template reads.}

    If !akActor1
        Debug.Trace("[SeverCombat] CeaseFire: Actor1 is None")
        Return
    EndIf

    Debug.Trace("[SeverCombat] CeaseFire: " + akActor1.GetDisplayName() + " initiated ceasefire")

    ; If akActor2 wasn't provided, fall back to the stored combat target.
    Actor akStoredTarget = akActor2
    If !akStoredTarget
        akStoredTarget = StorageUtil.GetFormValue(akActor1, "SeverCombat_CombatTarget") as Actor
    EndIf

    ; Single native call does the lot: apply to initiator + partner + nearby
    ; combat-active faction allies, returning the list of affected actors.
    Actor[] affected = SeverActionsNativeExt.Ceasefire_PropagateGroup(akActor1, akStoredTarget, 4096.0)

    ; Mirror per-actor prompt state into StorageUtil — the prompt template
    ; reads SeverCombat_CeasefireTime and SeverCombat_WasNormallyHostile
    ; directly via papyrus_util(), so they have to live on the Papyrus side.
    Float ceasefireTime = Utility.GetCurrentGameTime() * 24 * 3631
    If affected
        Int i = 0
        While i < affected.Length
            Actor a = affected[i]
            If a
                StorageUtil.SetFloatValue(a, "SeverCombat_CeasefireTime", ceasefireTime)
                If SeverActionsNativeExt.Ceasefire_IsWasNormallyHostile(a)
                    StorageUtil.SetIntValue(a, "SeverCombat_WasNormallyHostile", 1)
                EndIf
            EndIf
            i += 1
        EndWhile
        Debug.Trace("[SeverCombat] CeaseFire: native affected " + affected.Length + " actor(s)")
    EndIf

    ; Clear forced combat flag — combat is over
    SeverActionsNative.Native_SetInForcedCombat(akActor1, false)
    StorageUtil.UnsetIntValue(akActor1, "SeverCombat_InForcedCombat")
    If akStoredTarget
        SeverActionsNative.Native_SetInForcedCombat(akStoredTarget, false)
        StorageUtil.UnsetIntValue(akStoredTarget, "SeverCombat_InForcedCombat")
    EndIf

    ; Apply cooldown (prevents immediate re-attack action)
    ApplyCooldown(akActor1, akStoredTarget)

    Debug.Trace("[SeverCombat] CeaseFire complete — group ceasefire active, indefinite until player attacks or NPC re-engages")
EndFunction

Bool Function CeaseFire_IsEligible(Actor akActor1, Actor akActor2)
    If !akActor1
        Return False
    EndIf
    ; At least one must be in combat
    Return akActor1.IsInCombat() || (akActor2 && akActor2.IsInCombat())
EndFunction

; ============================================================================
; YIELD / SURRENDER FUNCTION
; ============================================================================

Function Yield_Execute(Actor akYielder)
{Makes an actor yield/surrender. Phase 6: faction-swap + aggression-zero +
 monitor-register all happen in one native call (Yield_ConvertToSurrendered).
 Papyrus owns: stop combat, relationship-rank restore (CLib NG doesn't expose
 those methods), yield prompt flags + timestamp, yield-slot persistence,
 cooldown, EvaluatePackage.}

    If !akYielder
        Debug.Trace("[SeverCombat] Yield: Yielder is None")
        Return
    EndIf

    Debug.Trace("[SeverCombat] Yield: " + akYielder.GetDisplayName() + " is yielding")

    akYielder.StopCombatAlarm()
    akYielder.StopCombat()

    Actor akStoredTarget = StorageUtil.GetFormValue(akYielder, "SeverCombat_CombatTarget") as Actor
    If akStoredTarget
        akStoredTarget.StopCombatAlarm()
        akStoredTarget.StopCombat()
    EndIf

    RestoreOriginalValues(akYielder)
    If akStoredTarget
        RestoreOriginalValues(akStoredTarget)
    EndIf

    If akStoredTarget
        ; Relationship-rank restore stays Papyrus-side — CommonLibSSE-NG
        ; doesn't expose GetRelationshipRank / SetRelationshipRank on Actor.
        Int origRankYielder = StorageUtil.GetIntValue(akYielder, "SeverCombat_OriginalRelationship", 0)
        Int origRankAttacker = StorageUtil.GetIntValue(akStoredTarget, "SeverCombat_OriginalRelationship", 0)
        akYielder.SetRelationshipRank(akStoredTarget, origRankYielder)
        akStoredTarget.SetRelationshipRank(akYielder, origRankAttacker)

        StorageUtil.SetFormValue(akYielder, "SeverCombat_YieldedTo", akStoredTarget)
        StorageUtil.SetFormValue(akStoredTarget, "SeverCombat_ReceivedYieldFrom", akYielder)

        Float yieldTime = Utility.GetCurrentGameTime() * 24 * 3631
        StorageUtil.SetFloatValue(akYielder, "SeverCombat_YieldTime", yieldTime)
        StorageUtil.SetFloatValue(akStoredTarget, "SeverCombat_YieldTime", yieldTime)
    EndIf

    ClearAllCombatState(akYielder)
    If akStoredTarget
        ClearAllCombatState(akStoredTarget)
    EndIf

    ; StorageUtil mirror of original aggression — kept for Phase 6 only so the
    ; existing YieldAlias.psc OnLoad re-register path keeps working. Phase 7
    ; deletes the alias and this mirror can go with it.
    StorageUtil.SetFloatValue(akYielder, "SeverCombat_OriginalAggression", akYielder.GetActorValue("Aggression"))

    ; Phase 6: one native call replaces the Papyrus ConvertToSurrendered loop
    ; + manual aggression zero + WasSurrendered flag write + Native_SetSurrendered.
    ; The native side stores the removed-factions list directly in the
    ; YieldedActorData entry; OnYieldBroken / ReturnToCrime / FullCleanup
    ; restore them from there without Papyrus FormList round-trips.
    Bool wasHostile = SeverActionsNativeExt.Yield_ConvertToSurrendered(akYielder)
    StorageUtil.SetIntValue(akYielder, "SeverCombat_WasSurrendered", 1)
    If wasHostile
        StorageUtil.SetIntValue(akYielder, "SeverCombat_WasNormallyHostile", 1)
    EndIf
    SeverActionsNative.Native_SetSurrendered(akYielder, true)

    ; YieldSlot persistence — still Papyrus for Phase 6, Phase 7 replaces this
    ; with C++ kPersistent flag manipulation.
    If YieldPersistenceEnabled && wasHostile
        AssignYieldSlot(akYielder)
    EndIf

    ApplyCooldown(akYielder, akStoredTarget)

    akYielder.EvaluatePackage()
    If akStoredTarget
        akStoredTarget.EvaluatePackage()
    EndIf
EndFunction

Bool Function Yield_IsEligible(Actor akYielder)
    If !akYielder
        Return False
    EndIf
    Return akYielder.IsInCombat()
EndFunction

; ============================================================================
; FACTION CONVERSION SYSTEM
; ============================================================================

Function RestoreHostileFactions(Actor akActor, String storageKey)
{Inverse of ConvertToSurrendered's faction loop. Removes akActor from
 SeverSurrenderedFaction (if present), re-adds every faction stored in the
 named FormList, then clears the list. Shared by ReturnToCrime,
 OnYieldBroken, OnCeasefireBroken, and FullCleanup — previously each of
 those duplicated the same loop with subtly different surrounding cleanup.}
    If !akActor
        Return
    EndIf

    If SeverSurrenderedFaction && akActor.IsInFaction(SeverSurrenderedFaction)
        akActor.RemoveFromFaction(SeverSurrenderedFaction)
    EndIf

    Int factionCount = StorageUtil.FormListCount(akActor, storageKey)
    Int i = 0
    While i < factionCount
        Faction f = StorageUtil.FormListGet(akActor, storageKey, i) as Faction
        If f
            akActor.AddToFaction(f)
            akActor.SetFactionRank(f, 0)
            Debug.Trace("[SeverCombat] RestoreHostileFactions(" + storageKey + "): " + akActor.GetDisplayName() + " -> " + f)
        EndIf
        i += 1
    EndWhile

    StorageUtil.FormListClear(akActor, storageKey)
EndFunction

Function ReturnToCrime_Execute(Actor akActor)
{Revert a surrendered actor back to their original hostile faction(s).
 Phase 6: aggression restore + surrendered-faction removal + hostile-faction
 re-add + monitor unregister all happen in Yield_ReturnToCrime. Papyrus
 only clears the prompt-side StorageUtil keys.}

    If !akActor
        Return
    EndIf

    If StorageUtil.GetIntValue(akActor, "SeverCombat_WasSurrendered", 0) != 1
        Debug.Trace("[SeverCombat] ReturnToCrime: " + akActor.GetDisplayName() + " was never surrendered")
        Return
    EndIf

    Debug.Trace("[SeverCombat] ReturnToCrime: " + akActor.GetDisplayName() + " returning to hostile faction")

    ; Release yield persistence alias — no longer surrendered (Phase 7 will
    ; replace alias plumbing with C++ kPersistent manipulation).
    ClearYieldSlot(akActor)

    ; One native call does the whole restore (aggression / factions / unregister).
    SeverActionsNativeExt.Yield_ReturnToCrime(akActor)
    SeverActionsNative.Native_SetSurrendered(akActor, false)

    ; Clear prompt-side state + legacy keys.
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_OriginalFaction")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasSurrendered")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasNormallyHostile")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_YieldedTo")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalAggression")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_YieldTime")
    StorageUtil.FormListClear(akActor, "SeverCombat_RemovedFactions")  ; legacy

    Debug.Trace("[SeverCombat] ReturnToCrime complete for " + akActor.GetDisplayName())
EndFunction

Bool Function ReturnToCrime_IsEligible(Actor akActor)
{Check if an actor is eligible to return to crime (must be surrendered)}
    If !akActor
        Return False
    EndIf
    Return StorageUtil.GetIntValue(akActor, "SeverCombat_WasSurrendered", 0) == 1
EndFunction

Bool Function IsSurrendered(Actor akActor)
{Check if an actor has surrendered and is in the surrendered faction}
    If !akActor
        Return False
    EndIf
    If !SeverSurrenderedFaction
        Return False
    EndIf
    Return akActor.IsInFaction(SeverSurrenderedFaction)
EndFunction

; ============================================================================
; HELPER FUNCTIONS
; ============================================================================

Function ClearAllCombatState(Actor akActor)
{Completely clear all combat-related StorageUtil keys for an actor}
    ; Clear combat tracking
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_CombatTarget")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_InForcedCombat")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_OriginalRelationship")

    ; Clear stored original values (already restored by this point)
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalConfidence")
    
    ; NOTE: We do NOT clear these here - they're for prompt awareness and auto-expire:
    ; - SeverCombat_CeasefireTime (auto-expires based on time comparison in prompt)
    ; - SeverCombat_YieldTime (auto-expires based on time comparison in prompt)
    ; - SeverCombat_YieldedTo (used with YieldTime for prompt)
    ; - SeverCombat_ReceivedYieldFrom (used with YieldTime for prompt)
    ; - SeverCombat_CooldownEnd (only gates AttackTarget calls)
    ; - SeverCombat_WasSurrendered (persistent until ReturnToCrime)
    ; - SeverCombat_OriginalFaction (persistent until ReturnToCrime)
    ; - SeverCombat_RemovedFactions (persistent until ReturnToCrime)
    ; - SeverCombat_OriginalAggression (persistent until ReturnToCrime or FullCleanup)
EndFunction

Function PrepareForCombat(Actor akActor)
{Set actor values for combat - only boost confidence so they don't flee}
    ; NOTE: We intentionally do NOT modify Aggression here.
    ; Setting high aggression can cause NPCs to attack unintended targets
    ; if combat ends abnormally and values aren't restored.
    ; StartCombat() + relationship rank changes are sufficient.

    ; Confidence: 0=Cowardly, 1=Cautious, 2=Average, 3=Brave, 4=Foolhardy
    akActor.SetActorValue("Confidence", 3)

    akActor.EvaluatePackage()
EndFunction

Function StoreOriginalValues(Actor akActor)
{Store actor's original combat values in StorageUtil}
    ; Only store if not already stored (don't overwrite during ongoing combat)
    If StorageUtil.GetIntValue(akActor, "SeverCombat_InForcedCombat", 0) == 0
        ; Store confidence
        StorageUtil.SetFloatValue(akActor, "SeverCombat_OriginalConfidence", akActor.GetActorValue("Confidence"))
    EndIf
EndFunction

Function RestoreOriginalValues(Actor akActor)
{Restore actor's original combat values from StorageUtil}
    ; Restore confidence
    Float origConfidence = StorageUtil.GetFloatValue(akActor, "SeverCombat_OriginalConfidence", -1.0)
    If origConfidence >= 0.0
        akActor.SetActorValue("Confidence", origConfidence)
        StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalConfidence")
    EndIf

    ; Remove from attack/target factions (kept — AIO flee-suppression patch
    ; depends on these being toggled on/off around forced-combat windows)
    If SeverActions_AttackFaction && akActor.IsInFaction(SeverActions_AttackFaction)
        akActor.RemoveFromFaction(SeverActions_AttackFaction)
    EndIf
    If SeverActions_TargetFaction && akActor.IsInFaction(SeverActions_TargetFaction)
        akActor.RemoveFromFaction(SeverActions_TargetFaction)
    EndIf
EndFunction

; ============================================================================
; COOLDOWN
; ============================================================================

Function ApplyCooldown(Actor akActor, Actor akPartner)
{Apply cooldown to prevent immediate re-engagement. Phase 6: backed by
 native CombatCooldownStore (cosave-persisted FormID->expiry map) instead
 of the SeverCombat_CooldownEnd StorageUtil key.}
    If akActor
        SeverActionsNativeExt.Cooldown_Set(akActor, CombatCooldownDuration)
    EndIf
    If akPartner
        SeverActionsNativeExt.Cooldown_Set(akPartner, CombatCooldownDuration)
    EndIf
EndFunction

Bool Function IsActorInCooldown(Actor akActor)
{Check if actor is in cooldown period. Reads the native store; lazily
 clears expired entries inside Cooldown_IsActive.}
    If !akActor
        Return False
    EndIf
    Return SeverActionsNativeExt.Cooldown_IsActive(akActor)
EndFunction

Function ClearCooldownState(Actor akActor)
{Manually clear cooldown for an actor.}
    If akActor
        SeverActionsNativeExt.Cooldown_Clear(akActor)
    EndIf
EndFunction

Function FullCleanup(Actor akActor)
{Nuclear option - completely wipe ALL combat state for an actor and restore to normal}
    If !akActor
        Return
    EndIf
    
    Debug.Trace("[SeverCombat] FullCleanup starting for " + akActor.GetDisplayName())

    ; Release yield persistence alias if active
    ClearYieldSlot(akActor)

    ; Stop any combat
    akActor.StopCombatAlarm()
    akActor.StopCombat()

    ; Phase 6: if the native yield monitor is still tracking this actor,
    ; tell C++ to restore aggression + factions + unregister silently.
    ; ForceBreak is equivalent to ReturnToCrime but reads better at the
    ; FullCleanup call site.
    If SeverActionsNative.IsYieldMonitored(akActor)
        SeverActionsNativeExt.Yield_ForceBreak(akActor)
        SeverActionsNative.Native_SetSurrendered(akActor, false)
    ElseIf StorageUtil.GetIntValue(akActor, "SeverCombat_WasSurrendered", 0) == 1
        ; Surrendered but not in monitor (pre-Phase-6 save) — use the legacy
        ; StorageUtil-driven restore path so old saves don't break.
        RestoreHostileFactions(akActor, "SeverCombat_RemovedFactions")
        SeverActionsNative.UnregisterYieldedActor(akActor)
    Else
        ; Not surrendered — just make sure they're not stuck in
        ; SeverSurrenderedFaction (rare edge: ceasefire faction-swap that
        ; never set WasSurrendered, FullCleanup invoked while still in it).
        If SeverSurrenderedFaction && akActor.IsInFaction(SeverSurrenderedFaction)
            akActor.RemoveFromFaction(SeverSurrenderedFaction)
        EndIf
        SeverActionsNative.UnregisterYieldedActor(akActor)
    EndIf

    ; Phase 5: if the native monitor is still tracking a ceasefire on this
    ; actor (e.g. FullCleanup invoked from OnForcedCombatEnded before any
    ; player hit broke it), tell C++ to restore aggression / factions
    ; silently. ForceBreak skips the SeverActionsNative_CeasefireBroken
    ; ModEvent so we don't trigger our own OnCeasefireBroken handler mid-wipe.
    If SeverActionsNative.Ceasefire_IsMonitored(akActor)
        SeverActionsNativeExt.Ceasefire_ForceBreak(akActor)
    EndIf

    ; Legacy: if a pre-Phase-5 save still has the CeasefireFactionSwapped
    ; flag, restore via the Papyrus path.
    If StorageUtil.GetIntValue(akActor, "SeverCombat_CeasefireFactionSwapped", 0) == 1
        RestoreHostileFactions(akActor, "SeverCombat_CeasefireRemovedFactions")
        StorageUtil.UnsetIntValue(akActor, "SeverCombat_CeasefireFactionSwapped")
    EndIf

    ; Always clear the native surrendered flag, regardless of whether the
    ; StorageUtil "WasSurrendered" key was set. Belt-and-suspenders against
    ; partial-state cleanup (crash between SetIntValue and Native_SetSurrendered,
    ; older save with the native flag set but the Papyrus flag already unset,
    ; etc.). Native flag stuck true would keep decorators reporting the actor
    ; as surrendered for the rest of the session.
    SeverActionsNative.Native_SetSurrendered(akActor, false)

    ; Restore aggression - use stored value if available, otherwise default to 1
    Float originalAggression = StorageUtil.GetFloatValue(akActor, "SeverCombat_OriginalAggression", -1.0)
    If originalAggression >= 0.0
        akActor.SetActorValue("Aggression", originalAggression)
        Debug.Trace("[SeverCombat] Restored aggression to stored value: " + originalAggression)
    Else
        ; Default to 1 (Aggressive) - normal for most NPCs
        akActor.SetActorValue("Aggression", 1)
        Debug.Trace("[SeverCombat] Set aggression to default: 1")
    EndIf
    
    ; Restore confidence - use stored value if available, otherwise default to 3
    Float originalConfidence = StorageUtil.GetFloatValue(akActor, "SeverCombat_OriginalConfidence", -1.0)
    If originalConfidence >= 0.0
        akActor.SetActorValue("Confidence", originalConfidence)
        Debug.Trace("[SeverCombat] Restored confidence to stored value: " + originalConfidence)
    Else
        ; Default to 3 (Brave) - typical for most NPCs
        akActor.SetActorValue("Confidence", 3)
        Debug.Trace("[SeverCombat] Set confidence to default: 3")
    EndIf
    
    ; Clear ALL StorageUtil keys
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_CombatTarget")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_InForcedCombat")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_OriginalRelationship")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalAggression")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalConfidence")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_CeasefireTime")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_YieldTime")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_YieldedTo")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_ReceivedYieldFrom")
    SeverActionsNativeExt.Cooldown_Clear(akActor)  ; Phase 6: native-backed (was SeverCombat_CooldownEnd)

    ; Clear surrender state
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasSurrendered")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasNormallyHostile")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_OriginalFaction")
    StorageUtil.FormListClear(akActor, "SeverCombat_RemovedFactions")

    akActor.EvaluatePackage()
    Debug.Trace("[SeverCombat] FullCleanup complete for " + akActor.GetDisplayName())
EndFunction

Bool Function FullCleanup_IsEligible(Actor akActor)
{Check if an actor can have cleanup performed - basically any living actor}
    If !akActor
        Return False
    EndIf
    If akActor.IsDead()
        Return False
    EndIf
    Return True
EndFunction

Event OnPlayerLoadGame()
    ; Re-register for native mod events
    RegisterForModEvent("SeverActionsNative_YieldBroken", "OnYieldBroken")
    RegisterForModEvent("SeverActionsNative_CeasefireBroken", "OnCeasefireBroken")
    RegisterForModEvent("SeverActions_ForcedCombatEnded", "OnForcedCombatEnded")

    ; Re-assign yield persistence aliases (ForceRefTo doesn't survive save/load)
    ReassignYieldSlots()
    ; Ceasefire'd actors are restored from the C++ cosave ('CEAS' record in
    ; CeasefireMonitor); no Papyrus-side re-registration is needed.
    ; Re-push the faction config in case the cosave was clobbered or the
    ; load order shifted.
    PushCeasefireConfigToNative()
EndEvent

Event OnCeasefireBroken(String eventName, String strArg, Float numArg, Form sender)
    {Native CeasefireMonitor detected a player hit on a ceasefire'd actor and
     already did the heavy lifting in C++: restored Aggression, removed from
     SeverSurrenderedFaction, re-added the hostile factions, restored the
     relationship rank vs. the stored partner, called EvaluatePackage.

     This handler exists only to clean up the Papyrus-side StorageUtil keys
     the prompt template reads, and to clear any legacy keys from saves
     made before the Phase 5 migration.}
    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf

    Debug.Trace("[SeverCombat] CeasefireBroken: " + akActor.GetDisplayName() + " — clearing prompt-side state")

    ; Legacy keys (Phase 4 and earlier): clear if any old save still has them.
    ; Phase 5 onward, the C++ side owns the faction list + partner.
    If StorageUtil.GetIntValue(akActor, "SeverCombat_CeasefireFactionSwapped", 0) == 1
        StorageUtil.FormListClear(akActor, "SeverCombat_CeasefireRemovedFactions")
        StorageUtil.UnsetIntValue(akActor, "SeverCombat_CeasefireFactionSwapped")
    EndIf
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_CeasefirePartner")

    ; Current prompt-side state cleanup.
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_NeedsAggroRestore")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalAggression")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_CeasefireTime")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasNormallyHostile")

    ; Clear forced combat flag — combat is resuming naturally.
    SeverActionsNative.Native_SetInForcedCombat(akActor, false)
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_InForcedCombat")
EndEvent

; ============================================================================
; YIELD BROKEN EVENT HANDLER
; ============================================================================

Event OnYieldBroken(string eventName, string strArg, float numArg, Form sender)
    {Called by native YieldMonitor when a yielded actor takes enough hits to
     break surrender. Phase 6: C++ already restored aggression, removed from
     SeverSurrenderedFaction, AND re-added the hostile factions (data lives
     in the YieldedActorData entry). This handler only clears prompt-side
     StorageUtil keys, sets the YieldBroken prompt flag, and fires the
     SkyrimNet event.}
    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf

    Debug.Trace("[SeverCombat] YieldBroken: " + akActor.GetDisplayName() + " was attacked after surrendering")

    ClearYieldSlot(akActor)

    ; Prompt-side state cleanup.
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasSurrendered")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasNormallyHostile")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_OriginalFaction")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalAggression")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_YieldTime")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_YieldedTo")
    StorageUtil.FormListClear(akActor, "SeverCombat_RemovedFactions")  ; legacy

    Actor playerRef = Game.GetPlayer()
    If playerRef
        StorageUtil.UnsetFormValue(playerRef, "SeverCombat_ReceivedYieldFrom")
    EndIf

    StorageUtil.SetIntValue(akActor, "SeverCombat_YieldBroken", 1)

    If playerRef
        SkyrimNetApi.RegisterEvent("yield_broken", \
            akActor.GetDisplayName() + " was attacked after surrendering and is fighting back against " + playerRef.GetDisplayName(), \
            akActor, playerRef)
    EndIf

    Debug.Trace("[SeverCombat] YieldBroken complete for " + akActor.GetDisplayName())
EndEvent

; ============================================================================
; YIELD PERSISTENCE - Alias slot management for generic NPCs
; ============================================================================

Function AssignYieldSlot(Actor akActor)
    {Find an empty YieldSlot and assign the actor to it for persistence.
     Also adds the actor to the global tracking FormList so the slot can
     be re-assigned after save/load (ForceRefTo is runtime-only).}
    If !akActor || !YieldSlots
        Return
    EndIf

    ; Don't double-assign — check if already in a yield slot
    Int j = 0
    While j < YieldSlots.Length
        If YieldSlots[j] && YieldSlots[j].GetActorRef() == akActor
            Debug.Trace("[SeverCombat] YieldSlot: " + akActor.GetDisplayName() + " already in slot " + j)
            Return
        EndIf
        j += 1
    EndWhile

    ; Find an empty slot
    Int i = 0
    While i < YieldSlots.Length
        If YieldSlots[i] && !YieldSlots[i].GetActorRef()
            YieldSlots[i].ForceRefTo(akActor)

            ; Track in StorageUtil for save/load re-assignment
            StorageUtil.FormListAdd(None, "SeverCombat_YieldedGenericActors", akActor, false)

            Debug.Trace("[SeverCombat] YieldSlot " + i + " assigned to " + akActor.GetDisplayName() + " (now persistent)")
            Return
        EndIf
        i += 1
    EndWhile

    Debug.Trace("[SeverCombat] WARNING: No free yield slots for " + akActor.GetDisplayName() + " — NPC may not persist across cells")
EndFunction

Function ClearYieldSlot(Actor akActor)
    {Find and clear the YieldSlot for this actor. Removes from tracking FormList.}
    If !akActor || !YieldSlots
        Return
    EndIf

    ; Remove from global tracking list
    StorageUtil.FormListRemove(None, "SeverCombat_YieldedGenericActors", akActor)

    ; Find and clear their alias slot
    Int i = 0
    While i < YieldSlots.Length
        If YieldSlots[i] && YieldSlots[i].GetActorRef() == akActor
            YieldSlots[i].Clear()
            Debug.Trace("[SeverCombat] YieldSlot " + i + " cleared for " + akActor.GetDisplayName())
            Return
        EndIf
        i += 1
    EndWhile
EndFunction

Function ReassignYieldSlots()
    {Re-assign yield alias slots after a game load.
     ForceRefTo is runtime-only and doesn't survive save/load, so we need to
     repopulate the alias slots every time the game loads.
     Uses the StorageUtil FormList to track which actors need persistence.}
    If !YieldSlots || !YieldPersistenceEnabled
        Return
    EndIf

    ; Clear any stale alias data first
    Int i = 0
    While i < YieldSlots.Length
        If YieldSlots[i]
            YieldSlots[i].Clear()
        EndIf
        i += 1
    EndWhile

    ; Get the list of yielded generic actors
    Int count = StorageUtil.FormListCount(None, "SeverCombat_YieldedGenericActors")
    If count == 0
        Return
    EndIf

    Int assigned = 0
    Int slotIdx = 0
    i = count - 1 ; Iterate backwards since we may remove entries

    While i >= 0
        Actor npc = StorageUtil.FormListGet(None, "SeverCombat_YieldedGenericActors", i) as Actor

        ; Clean up invalid entries (dead, None, or no longer surrendered)
        If !npc || npc.IsDead() || StorageUtil.GetIntValue(npc, "SeverCombat_WasSurrendered", 0) != 1
            StorageUtil.FormListRemoveAt(None, "SeverCombat_YieldedGenericActors", i)
            If npc
                Debug.Trace("[SeverCombat] YieldSlot: Removing invalid entry: " + npc.GetDisplayName())
            EndIf
        Else
            ; Find an empty slot and assign
            While slotIdx < YieldSlots.Length && (!YieldSlots[slotIdx] || YieldSlots[slotIdx].GetActorRef())
                slotIdx += 1
            EndWhile

            If slotIdx < YieldSlots.Length
                YieldSlots[slotIdx].ForceRefTo(npc)
                assigned += 1

                ; Re-zero aggression — generic NPCs can have actor values reset by template on load
                npc.SetActorValue("Aggression", 0)

                ; Re-register with C++ yield monitor (runtime-only map, doesn't survive save/load)
                Float origAggro = StorageUtil.GetFloatValue(npc, "SeverCombat_OriginalAggression", 1.0)
                SeverActionsNative.RegisterYieldedActor(npc, origAggro, SeverSurrenderedFaction)

                Debug.Trace("[SeverCombat] YieldSlot " + slotIdx + " reassigned to " + npc.GetDisplayName() + " after load (Aggression=0, monitor re-registered)")
                slotIdx += 1
            Else
                Debug.Trace("[SeverCombat] WARNING: Not enough yield slots for all yielded NPCs")
            EndIf
        EndIf

        i -= 1
    EndWhile

    If assigned > 0
        Debug.Trace("[SeverCombat] Reassigned " + assigned + " yield slot(s) after load")
    EndIf
EndFunction
