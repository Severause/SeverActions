Scriptname SeverActions_Combat extends Quest
{Combat actions for SkyrimNet - handles attack commands, yield/surrender with faction conversion, and combat state tracking via StorageUtil}

; ============================================================================
; PROPERTIES
; ============================================================================

; DEPRECATED: These factions are no longer used for attack actions.
; They caused issues where followers would become hostile to unintended targets.
; Kept for backwards compatibility - cleanup code will remove actors from these
; factions if they were added by older versions of the mod.
Faction Property CombatAggressorFaction Auto
{DEPRECATED - No longer used. Kept for backwards compatibility cleanup.}

Faction Property CombatVictimFaction Auto
{DEPRECATED - No longer used. Kept for backwards compatibility cleanup.}

; Vanilla follower faction - used for reference only now
Faction Property CurrentFollowerFaction Auto
{Set to CurrentFollowerFaction from Skyrim.esm}

; SkyrimNet follower faction (optional)
Faction Property SkyrimNetFollowerFaction Auto
{Set to SkyrimNet_FollowingPlayerFaction from SkyrimNet.esp if using SkyrimNet followers}

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

; Individual faction properties as fallback if FormList not set
; These are the main hostile factions from vanilla Skyrim
Faction Property BanditFaction Auto
{Main bandit faction - 0x0001BCC0}

Faction Property ForswornFaction Auto
{Forsworn faction - 0x00043599}

Faction Property VampireFaction Auto
{Vampire faction - 0x00027242}

Faction Property WarlockFaction Auto
{Warlock/hostile mage faction - 0x00026724}

Faction Property SilverHandFaction Auto
{Silver Hand werewolf hunters - 0x000AA0A4}

Faction Property ThalmorFaction Auto
{Thalmor faction - 0x00039F26}

Faction Property NecromancerFaction Auto
{Necromancer faction - 0x00034B74}

Faction Property DraugrFaction Auto
{Draugr faction - 0x0002430D}

Faction Property HagravenFaction Auto
{Hagraven faction - 0x0004359E}

Faction Property DLC1VampireFaction Auto
{Dawnguard vampire faction - 0x02003376}

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
; SeverCombat_CooldownEnd - Float (game time when cooldown ends)
; SeverCombat_WasSurrendered - Int (1 = this actor has surrendered)
; SeverCombat_OriginalFaction - Form (the hostile faction they were removed from)
; SeverCombat_OriginalFactions - FormList ID (if they were in multiple hostile factions)
; SeverCombat_NeedsAggroRestore - Int (1 = aggression was zeroed, needs delayed restore)
; SeverCombat_CeasefirePartner - Form (the other actor in the ceasefire pair)
;
; DEPRECATED KEYS (cleaned up for backwards compatibility):
; - SeverCombat_AddedToFaction - No longer used, we don't add to combat factions anymore
; - SeverCombat_AddedToVictimFaction - No longer used, we don't add to victim factions anymore
; - SeverCombat_RecentCeasefire - Replaced by SeverCombat_CeasefireTime

; ============================================================================
; SINGLETON
; ============================================================================

SeverActions_Combat Function GetInstance() Global
    Quest kQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    Return kQuest as SeverActions_Combat
EndFunction

; ============================================================================
; CEASEFIRE DELAYED RESTORE STATE
; ============================================================================

; Actors that need aggression restored after ceasefire cooldown expires
Actor CeasefireActor1
Actor CeasefireActor2

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
    
    ; Clear any recent ceasefire/yield state
    StorageUtil.UnsetFloatValue(akAttacker, "SeverCombat_CeasefireTime")
    StorageUtil.UnsetFloatValue(akTarget, "SeverCombat_CeasefireTime")
    StorageUtil.UnsetFloatValue(akAttacker, "SeverCombat_YieldTime")
    StorageUtil.UnsetFloatValue(akTarget, "SeverCombat_YieldTime")
    StorageUtil.UnsetFormValue(akAttacker, "SeverCombat_YieldedTo")
    StorageUtil.UnsetFormValue(akTarget, "SeverCombat_YieldedTo")
    StorageUtil.UnsetFormValue(akAttacker, "SeverCombat_ReceivedYieldFrom")
    StorageUtil.UnsetFormValue(akTarget, "SeverCombat_ReceivedYieldFrom")
    ; Also clear legacy flag if present
    StorageUtil.UnsetIntValue(akAttacker, "SeverCombat_RecentCeasefire")
    StorageUtil.UnsetIntValue(akTarget, "SeverCombat_RecentCeasefire")
    
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
{Forces two actors to stop fighting each other and restores their relationship.
 CRITICAL: Must zero Aggression BEFORE calling StopCombat, otherwise the engine
 immediately re-enters combat on EvaluatePackage for hostile-faction NPCs.
 Aggression is restored after a delay to allow the ceasefire to "stick".}

    If !akActor1
        Debug.Trace("[SeverCombat] CeaseFire: Actor1 is None")
        Return
    EndIf

    Debug.Trace("[SeverCombat] CeaseFire: " + akActor1.GetDisplayName() + " and " + akActor2.GetDisplayName())

    ; Get stored combat target if akActor2 wasn't provided
    Actor akStoredTarget = akActor2
    If !akStoredTarget
        akStoredTarget = StorageUtil.GetFormValue(akActor1, "SeverCombat_CombatTarget") as Actor
    EndIf

    ; ========================================================================
    ; STEP 1: Store original aggression BEFORE we zero it
    ; This is critical - we need to save what they were before the ceasefire
    ; ========================================================================
    Float origAggression1 = akActor1.GetActorValue("Aggression")
    StorageUtil.SetFloatValue(akActor1, "SeverCombat_OriginalAggression", origAggression1)
    Debug.Trace("[SeverCombat] Stored aggression for " + akActor1.GetDisplayName() + ": " + origAggression1)

    If akStoredTarget
        Float origAggression2 = akStoredTarget.GetActorValue("Aggression")
        StorageUtil.SetFloatValue(akStoredTarget, "SeverCombat_OriginalAggression", origAggression2)
        Debug.Trace("[SeverCombat] Stored aggression for " + akStoredTarget.GetDisplayName() + ": " + origAggression2)
    EndIf

    ; ========================================================================
    ; STEP 2: Zero aggression BEFORE stopping combat
    ; Without this, StopCombat + EvaluatePackage immediately re-triggers combat
    ; because hostile factions (BanditFaction etc.) + Aggression > 0 = attack on sight
    ; ========================================================================
    akActor1.SetActorValue("Aggression", 0)
    If akStoredTarget
        akStoredTarget.SetActorValue("Aggression", 0)
    EndIf

    ; ========================================================================
    ; STEP 3: Stop combat for both (now safe - aggression is 0)
    ; ========================================================================
    akActor1.StopCombatAlarm()
    akActor1.StopCombat()

    If akStoredTarget
        akStoredTarget.StopCombatAlarm()
        akStoredTarget.StopCombat()
    EndIf

    ; ========================================================================
    ; STEP 4: Set temporary positive relationship to override faction hostility
    ; Faction disposition (BanditFaction = Enemy to Player) can override
    ; individual relationship ranks, but rank 1+ helps prevent re-aggro
    ; ========================================================================
    If akStoredTarget
        ; Store original relationship ranks for later restore
        Int origRankA1 = StorageUtil.GetIntValue(akActor1, "SeverCombat_OriginalRelationship", 0)
        Int origRankA2 = StorageUtil.GetIntValue(akStoredTarget, "SeverCombat_OriginalRelationship", 0)

        ; If they were enemies (e.g. from AttackTarget setting -4), bump to neutral/friendly
        ; If they were already neutral or friendly, leave as-is
        If origRankA1 < 0
            akActor1.SetRelationshipRank(akStoredTarget, 0)
        Else
            akActor1.SetRelationshipRank(akStoredTarget, origRankA1)
        EndIf

        If origRankA2 < 0
            akStoredTarget.SetRelationshipRank(akActor1, 0)
        Else
            akStoredTarget.SetRelationshipRank(akActor1, origRankA2)
        EndIf
    EndIf

    ; ========================================================================
    ; STEP 5: Clean up deprecated faction memberships (backwards compatibility)
    ; ========================================================================
    If CombatAggressorFaction && StorageUtil.GetIntValue(akActor1, "SeverCombat_AddedToFaction", 0) == 1
        akActor1.RemoveFromFaction(CombatAggressorFaction)
        StorageUtil.UnsetIntValue(akActor1, "SeverCombat_AddedToFaction")
    EndIf
    If CombatVictimFaction && StorageUtil.GetIntValue(akActor1, "SeverCombat_AddedToVictimFaction", 0) == 1
        akActor1.RemoveFromFaction(CombatVictimFaction)
        StorageUtil.UnsetIntValue(akActor1, "SeverCombat_AddedToVictimFaction")
    EndIf

    If akStoredTarget
        If CombatAggressorFaction && StorageUtil.GetIntValue(akStoredTarget, "SeverCombat_AddedToFaction", 0) == 1
            akStoredTarget.RemoveFromFaction(CombatAggressorFaction)
            StorageUtil.UnsetIntValue(akStoredTarget, "SeverCombat_AddedToFaction")
        EndIf
        If CombatVictimFaction && StorageUtil.GetIntValue(akStoredTarget, "SeverCombat_AddedToVictimFaction", 0) == 1
            akStoredTarget.RemoveFromFaction(CombatVictimFaction)
            StorageUtil.UnsetIntValue(akStoredTarget, "SeverCombat_AddedToVictimFaction")
        EndIf
    EndIf

    ; Restore confidence (but NOT aggression - that stays at 0 for now)
    RestoreOriginalValues(akActor1)
    If akStoredTarget
        RestoreOriginalValues(akStoredTarget)
    EndIf

    ; Clear all combat state
    ClearAllCombatState(akActor1)
    If akStoredTarget
        ClearAllCombatState(akStoredTarget)
    EndIf

    ; Set ceasefire timestamp for prompt awareness (same format as gameTimeNumeric)
    Float ceasefireTime = Utility.GetCurrentGameTime() * 24 * 3631
    StorageUtil.SetFloatValue(akActor1, "SeverCombat_CeasefireTime", ceasefireTime)
    If akStoredTarget
        StorageUtil.SetFloatValue(akStoredTarget, "SeverCombat_CeasefireTime", ceasefireTime)
    EndIf

    ; Apply cooldown
    ApplyCooldown(akActor1, akStoredTarget)

    ; ========================================================================
    ; STEP 6: Force AI re-evaluate (safe now - aggression is 0)
    ; ========================================================================
    akActor1.EvaluatePackage()
    If akStoredTarget
        akStoredTarget.EvaluatePackage()
    EndIf

    ; ========================================================================
    ; STEP 7: Mark actors for delayed aggression restore
    ; After CombatCooldownDuration seconds, aggression will be restored
    ; so they don't stay permanently pacified
    ; ========================================================================
    StorageUtil.SetFormValue(akActor1, "SeverCombat_CeasefirePartner", akStoredTarget)
    StorageUtil.SetIntValue(akActor1, "SeverCombat_NeedsAggroRestore", 1)
    If akStoredTarget
        StorageUtil.SetFormValue(akStoredTarget, "SeverCombat_CeasefirePartner", akActor1)
        StorageUtil.SetIntValue(akStoredTarget, "SeverCombat_NeedsAggroRestore", 1)
    EndIf

    ; Register a delayed callback to restore aggression after cooldown
    ; We use a RegisterForSingleUpdate on the quest itself
    CeasefireActor1 = akActor1
    CeasefireActor2 = akStoredTarget
    RegisterForSingleUpdate(CombatCooldownDuration)

    Debug.Trace("[SeverCombat] CeaseFire complete - aggression zeroed, will restore in " + CombatCooldownDuration + "s")
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
{Makes an actor yield/surrender. Removes them from hostile factions and adds to surrendered faction.}
    
    If !akYielder
        Debug.Trace("[SeverCombat] Yield: Yielder is None")
        Return
    EndIf
    
    Debug.Trace("[SeverCombat] Yield: " + akYielder.GetDisplayName() + " is yielding")
    
    ; Stop combat
    akYielder.StopCombatAlarm()
    akYielder.StopCombat()
    
    ; Get stored combat target
    Actor akStoredTarget = StorageUtil.GetFormValue(akYielder, "SeverCombat_CombatTarget") as Actor
    If akStoredTarget
        akStoredTarget.StopCombatAlarm()
        akStoredTarget.StopCombat()
    EndIf
    
    ; Clean up deprecated faction memberships (backwards compatibility)
    If CombatAggressorFaction && StorageUtil.GetIntValue(akYielder, "SeverCombat_AddedToFaction", 0) == 1
        akYielder.RemoveFromFaction(CombatAggressorFaction)
        StorageUtil.UnsetIntValue(akYielder, "SeverCombat_AddedToFaction")
    EndIf
    If CombatVictimFaction && StorageUtil.GetIntValue(akYielder, "SeverCombat_AddedToVictimFaction", 0) == 1
        akYielder.RemoveFromFaction(CombatVictimFaction)
        StorageUtil.UnsetIntValue(akYielder, "SeverCombat_AddedToVictimFaction")
    EndIf
    
    If akStoredTarget
        If CombatAggressorFaction && StorageUtil.GetIntValue(akStoredTarget, "SeverCombat_AddedToFaction", 0) == 1
            akStoredTarget.RemoveFromFaction(CombatAggressorFaction)
            StorageUtil.UnsetIntValue(akStoredTarget, "SeverCombat_AddedToFaction")
        EndIf
        If CombatVictimFaction && StorageUtil.GetIntValue(akStoredTarget, "SeverCombat_AddedToVictimFaction", 0) == 1
            akStoredTarget.RemoveFromFaction(CombatVictimFaction)
            StorageUtil.UnsetIntValue(akStoredTarget, "SeverCombat_AddedToVictimFaction")
        EndIf
    EndIf
    
    ; Restore original values for both (confidence only)
    RestoreOriginalValues(akYielder)
    If akStoredTarget
        RestoreOriginalValues(akStoredTarget)
    EndIf
    
    ; Restore original relationships
    If akStoredTarget
        Int origRankYielder = StorageUtil.GetIntValue(akYielder, "SeverCombat_OriginalRelationship", 0)
        Int origRankAttacker = StorageUtil.GetIntValue(akStoredTarget, "SeverCombat_OriginalRelationship", 0)
        akYielder.SetRelationshipRank(akStoredTarget, origRankYielder)
        akStoredTarget.SetRelationshipRank(akYielder, origRankAttacker)
        
        ; Set yield flags for prompt awareness
        StorageUtil.SetFormValue(akYielder, "SeverCombat_YieldedTo", akStoredTarget)
        StorageUtil.SetFormValue(akStoredTarget, "SeverCombat_ReceivedYieldFrom", akYielder)
        
        ; Set yield timestamp for prompt awareness (same format as gameTimeNumeric)
        Float yieldTime = Utility.GetCurrentGameTime() * 24 * 3631
        StorageUtil.SetFloatValue(akYielder, "SeverCombat_YieldTime", yieldTime)
        StorageUtil.SetFloatValue(akStoredTarget, "SeverCombat_YieldTime", yieldTime)
    EndIf
    
    ; Clear all combat state for both
    ClearAllCombatState(akYielder)
    If akStoredTarget
        ClearAllCombatState(akStoredTarget)
    EndIf
    
    ; Store original aggression before modifying (for followers and special NPCs)
    StorageUtil.SetFloatValue(akYielder, "SeverCombat_OriginalAggression", akYielder.GetActorValue("Aggression"))
    
    ; Make yielder non-aggressive (will be restored by ReturnToCrime or FullCleanup)
    akYielder.SetActorValue("Aggression", 0)
    
    ; ========================================================================
    ; FACTION CONVERSION - Replace hostile faction with surrendered faction
    ; ========================================================================
    ConvertToSurrendered(akYielder)
    
    ; Apply cooldown to both
    ApplyCooldown(akYielder, akStoredTarget)
    
    ; Force AI to re-evaluate
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

Function ConvertToSurrendered(Actor akActor)
{Remove actor from hostile factions and add to surrendered faction.
 Stores original faction for potential reversal via ReturnToCrime.}
    
    If !akActor
        Return
    EndIf
    
    ; Skip if no surrendered faction is set
    If !SeverSurrenderedFaction
        Debug.Trace("[SeverCombat] ConvertToSurrendered: No SeverSurrenderedFaction set, skipping faction conversion")
        Return
    EndIf
    
    ; Skip if already surrendered
    If akActor.IsInFaction(SeverSurrenderedFaction)
        Debug.Trace("[SeverCombat] ConvertToSurrendered: " + akActor.GetDisplayName() + " already surrendered")
        Return
    EndIf
    
    Bool wasConverted = False
    Faction firstRemovedFaction = None
    
    ; Try FormList first (preferred method - allows runtime configuration)
    If SeverHostileFactions
        Int i = 0
        While i < SeverHostileFactions.GetSize()
            Faction hostileFaction = SeverHostileFactions.GetAt(i) as Faction
            If hostileFaction && akActor.IsInFaction(hostileFaction)
                Debug.Trace("[SeverCombat] Removing " + akActor.GetDisplayName() + " from faction: " + hostileFaction)
                
                ; Store the first faction for reversal (they might be in multiple)
                If !firstRemovedFaction
                    firstRemovedFaction = hostileFaction
                EndIf
                
                ; Store in array for complete reversal later
                StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", hostileFaction, false)
                
                akActor.RemoveFromFaction(hostileFaction)
                wasConverted = True
            EndIf
            i += 1
        EndWhile
    Else
        ; Fallback: Check individual faction properties
        Debug.Trace("[SeverCombat] ConvertToSurrendered: Using individual faction properties (FormList not set)")
        
        ; Bandit
        If BanditFaction && akActor.IsInFaction(BanditFaction)
            If !firstRemovedFaction
                firstRemovedFaction = BanditFaction
            EndIf
            StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", BanditFaction, false)
            akActor.RemoveFromFaction(BanditFaction)
            wasConverted = True
        EndIf
        
        ; Forsworn
        If ForswornFaction && akActor.IsInFaction(ForswornFaction)
            If !firstRemovedFaction
                firstRemovedFaction = ForswornFaction
            EndIf
            StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", ForswornFaction, false)
            akActor.RemoveFromFaction(ForswornFaction)
            wasConverted = True
        EndIf
        
        ; Vampire
        If VampireFaction && akActor.IsInFaction(VampireFaction)
            If !firstRemovedFaction
                firstRemovedFaction = VampireFaction
            EndIf
            StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", VampireFaction, false)
            akActor.RemoveFromFaction(VampireFaction)
            wasConverted = True
        EndIf
        
        ; Warlock
        If WarlockFaction && akActor.IsInFaction(WarlockFaction)
            If !firstRemovedFaction
                firstRemovedFaction = WarlockFaction
            EndIf
            StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", WarlockFaction, false)
            akActor.RemoveFromFaction(WarlockFaction)
            wasConverted = True
        EndIf
        
        ; Silver Hand
        If SilverHandFaction && akActor.IsInFaction(SilverHandFaction)
            If !firstRemovedFaction
                firstRemovedFaction = SilverHandFaction
            EndIf
            StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", SilverHandFaction, false)
            akActor.RemoveFromFaction(SilverHandFaction)
            wasConverted = True
        EndIf
        
        ; Thalmor
        If ThalmorFaction && akActor.IsInFaction(ThalmorFaction)
            If !firstRemovedFaction
                firstRemovedFaction = ThalmorFaction
            EndIf
            StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", ThalmorFaction, false)
            akActor.RemoveFromFaction(ThalmorFaction)
            wasConverted = True
        EndIf
        
        ; Necromancer
        If NecromancerFaction && akActor.IsInFaction(NecromancerFaction)
            If !firstRemovedFaction
                firstRemovedFaction = NecromancerFaction
            EndIf
            StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", NecromancerFaction, false)
            akActor.RemoveFromFaction(NecromancerFaction)
            wasConverted = True
        EndIf
        
        ; Draugr
        If DraugrFaction && akActor.IsInFaction(DraugrFaction)
            If !firstRemovedFaction
                firstRemovedFaction = DraugrFaction
            EndIf
            StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", DraugrFaction, false)
            akActor.RemoveFromFaction(DraugrFaction)
            wasConverted = True
        EndIf
        
        ; Hagraven
        If HagravenFaction && akActor.IsInFaction(HagravenFaction)
            If !firstRemovedFaction
                firstRemovedFaction = HagravenFaction
            EndIf
            StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", HagravenFaction, false)
            akActor.RemoveFromFaction(HagravenFaction)
            wasConverted = True
        EndIf
        
        ; DLC1 Vampire
        If DLC1VampireFaction && akActor.IsInFaction(DLC1VampireFaction)
            If !firstRemovedFaction
                firstRemovedFaction = DLC1VampireFaction
            EndIf
            StorageUtil.FormListAdd(akActor, "SeverCombat_RemovedFactions", DLC1VampireFaction, false)
            akActor.RemoveFromFaction(DLC1VampireFaction)
            wasConverted = True
        EndIf
    EndIf
    
    ; Add to surrendered faction
    If wasConverted
        akActor.AddToFaction(SeverSurrenderedFaction)
        akActor.SetFactionRank(SeverSurrenderedFaction, 0)
        StorageUtil.SetIntValue(akActor, "SeverCombat_WasSurrendered", 1)
        StorageUtil.SetFormValue(akActor, "SeverCombat_OriginalFaction", firstRemovedFaction)
        Debug.Trace("[SeverCombat] " + akActor.GetDisplayName() + " converted to surrendered (was in " + firstRemovedFaction + ")")
    Else
        ; Not in any hostile faction - still add to surrendered for relationship purposes
        akActor.AddToFaction(SeverSurrenderedFaction)
        akActor.SetFactionRank(SeverSurrenderedFaction, 0)
        StorageUtil.SetIntValue(akActor, "SeverCombat_WasSurrendered", 1)
        Debug.Trace("[SeverCombat] " + akActor.GetDisplayName() + " added to surrendered (wasn't in hostile faction)")
    EndIf
EndFunction

Function ReturnToCrime_Execute(Actor akActor)
{Revert a surrendered actor back to their original hostile faction(s).
 Use this for betrayal scenarios or if they "return to their old ways".}
    
    If !akActor
        Return
    EndIf
    
    ; Check if they were ever surrendered
    If StorageUtil.GetIntValue(akActor, "SeverCombat_WasSurrendered", 0) != 1
        Debug.Trace("[SeverCombat] ReturnToCrime: " + akActor.GetDisplayName() + " was never surrendered")
        Return
    EndIf
    
    Debug.Trace("[SeverCombat] ReturnToCrime: " + akActor.GetDisplayName() + " returning to hostile faction")
    
    ; Remove from surrendered faction
    If SeverSurrenderedFaction && akActor.IsInFaction(SeverSurrenderedFaction)
        akActor.RemoveFromFaction(SeverSurrenderedFaction)
    EndIf
    
    ; Restore all original factions
    Int factionCount = StorageUtil.FormListCount(akActor, "SeverCombat_RemovedFactions")
    Int i = 0
    While i < factionCount
        Faction originalFaction = StorageUtil.FormListGet(akActor, "SeverCombat_RemovedFactions", i) as Faction
        If originalFaction
            akActor.AddToFaction(originalFaction)
            akActor.SetFactionRank(originalFaction, 0)
            Debug.Trace("[SeverCombat] Restored to faction: " + originalFaction)
        EndIf
        i += 1
    EndWhile
    
    ; Clear the stored factions list
    StorageUtil.FormListClear(akActor, "SeverCombat_RemovedFactions")
    
    ; Restore aggression - use stored value if available, otherwise default to 1
    Float originalAggression = StorageUtil.GetFloatValue(akActor, "SeverCombat_OriginalAggression", -1.0)
    If originalAggression >= 0.0
        akActor.SetActorValue("Aggression", originalAggression)
        Debug.Trace("[SeverCombat] Restored aggression to: " + originalAggression)
    Else
        ; Default to 1 (Aggressive) for NPCs returning to hostile behavior
        akActor.SetActorValue("Aggression", 1)
        Debug.Trace("[SeverCombat] Set aggression to default: 1")
    EndIf
    
    ; Clear surrender flags
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_OriginalFaction")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasSurrendered")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_YieldedTo")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalAggression")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_YieldTime")
    
    ; Force AI update
    akActor.EvaluatePackage()
    
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
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_AddedToFaction")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_AddedToVictimFaction")
    
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
EndFunction

; ============================================================================
; COOLDOWN
; ============================================================================

Function ApplyCooldown(Actor akActor, Actor akPartner)
{Apply cooldown to prevent immediate re-engagement}
    Float cooldownEnd = Utility.GetCurrentGameTime() + (CombatCooldownDuration / 24.0 / 60.0)
    StorageUtil.SetFloatValue(akActor, "SeverCombat_CooldownEnd", cooldownEnd)
    If akPartner
        StorageUtil.SetFloatValue(akPartner, "SeverCombat_CooldownEnd", cooldownEnd)
    EndIf
EndFunction

Bool Function IsActorInCooldown(Actor akActor)
{Check if actor is in cooldown period}
    Float cooldownEnd = StorageUtil.GetFloatValue(akActor, "SeverCombat_CooldownEnd", 0.0)
    If cooldownEnd == 0.0
        Return False
    EndIf
    
    Float currentTime = Utility.GetCurrentGameTime()
    If currentTime < cooldownEnd
        Return True
    Else
        StorageUtil.UnsetFloatValue(akActor, "SeverCombat_CooldownEnd")
        Return False
    EndIf
EndFunction

Function ClearCooldownState(Actor akActor)
{Manually clear cooldown for an actor}
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_CooldownEnd")
EndFunction

; ============================================================================
; UTILITY
; ============================================================================

Function StopActorCombat(Actor akActor)
{Utility to stop combat for a single actor}
    If akActor
        akActor.StopCombatAlarm()
        akActor.StopCombat()
        akActor.EvaluatePackage()
    EndIf
EndFunction

Function ClearCeasefireFlag(Actor akActor)
{Clear the ceasefire timestamp - no longer needed with time-based expiry, kept for compatibility}
    If akActor
        StorageUtil.UnsetFloatValue(akActor, "SeverCombat_CeasefireTime")
        ; Also clear legacy flag if present
        StorageUtil.UnsetIntValue(akActor, "SeverCombat_RecentCeasefire")
    EndIf
EndFunction

Function ClearYieldFlags(Actor akActor)
{Clear yield-related data - no longer needed with time-based expiry, kept for compatibility}
    If akActor
        StorageUtil.UnsetFloatValue(akActor, "SeverCombat_YieldTime")
        StorageUtil.UnsetFormValue(akActor, "SeverCombat_YieldedTo")
        StorageUtil.UnsetFormValue(akActor, "SeverCombat_ReceivedYieldFrom")
    EndIf
EndFunction

Function FullCleanup(Actor akActor)
{Nuclear option - completely wipe ALL combat state for an actor and restore to normal}
    If !akActor
        Return
    EndIf
    
    Debug.Trace("[SeverCombat] FullCleanup starting for " + akActor.GetDisplayName())
    
    ; Stop any combat
    akActor.StopCombatAlarm()
    akActor.StopCombat()
    
    ; Remove from aggressor faction (backwards compatibility)
    If CombatAggressorFaction && akActor.IsInFaction(CombatAggressorFaction)
        akActor.RemoveFromFaction(CombatAggressorFaction)
    EndIf
    
    ; Remove from victim faction (backwards compatibility)
    If CombatVictimFaction && akActor.IsInFaction(CombatVictimFaction)
        akActor.RemoveFromFaction(CombatVictimFaction)
    EndIf
    
    ; Remove from surrendered faction if present
    If SeverSurrenderedFaction && akActor.IsInFaction(SeverSurrenderedFaction)
        akActor.RemoveFromFaction(SeverSurrenderedFaction)
    EndIf
    
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
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_AddedToFaction")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_AddedToVictimFaction")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalAggression")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalConfidence")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_CeasefireTime")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_YieldTime")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_YieldedTo")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_ReceivedYieldFrom")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_CooldownEnd")
    ; Also clear legacy flags if present
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_RecentCeasefire")
    
    ; Clear surrender state
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasSurrendered")
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
    ; Check if there are actors that need aggression restored from a ceasefire
    ; that was in progress when the game was saved
    If CeasefireActor1 && StorageUtil.GetIntValue(CeasefireActor1, "SeverCombat_NeedsAggroRestore", 0) == 1
        Debug.Trace("[SeverCombat] Game loaded with pending ceasefire restore, scheduling...")
        RegisterForSingleUpdate(5.0) ; Short delay on load
    EndIf
EndEvent

Event OnUpdate()
    {Delayed aggression restore after ceasefire cooldown expires.
     Without this, hostile NPCs (bandits etc.) would stay permanently pacified
     at Aggression=0 after a ceasefire.}

    Debug.Trace("[SeverCombat] OnUpdate: Restoring aggression after ceasefire cooldown")

    RestoreCeasefireAggression(CeasefireActor1)
    RestoreCeasefireAggression(CeasefireActor2)

    ; Clear references
    CeasefireActor1 = None
    CeasefireActor2 = None
EndEvent

Function RestoreCeasefireAggression(Actor akActor)
    {Restore a single actor's aggression after ceasefire cooldown.
     Only restores if the actor still has the NeedsAggroRestore flag set
     (i.e., hasn't been re-engaged in new combat or had FullCleanup called).}

    If !akActor
        Return
    EndIf

    If StorageUtil.GetIntValue(akActor, "SeverCombat_NeedsAggroRestore", 0) != 1
        Return
    EndIf

    ; Restore original aggression
    Float origAggression = StorageUtil.GetFloatValue(akActor, "SeverCombat_OriginalAggression", -1.0)
    If origAggression >= 0.0
        akActor.SetActorValue("Aggression", origAggression)
        Debug.Trace("[SeverCombat] Restored aggression for " + akActor.GetDisplayName() + " to " + origAggression)
    Else
        ; Default to 1 (Aggressive) - standard for most hostile NPCs
        akActor.SetActorValue("Aggression", 1)
        Debug.Trace("[SeverCombat] Restored aggression for " + akActor.GetDisplayName() + " to default 1")
    EndIf

    ; Restore original relationship rank (undo the ceasefire neutral override)
    Actor partner = StorageUtil.GetFormValue(akActor, "SeverCombat_CeasefirePartner") as Actor
    If partner
        Int origRank = StorageUtil.GetIntValue(akActor, "SeverCombat_OriginalRelationship", 0)
        akActor.SetRelationshipRank(partner, origRank)
        Debug.Trace("[SeverCombat] Restored relationship rank for " + akActor.GetDisplayName() + " -> " + partner.GetDisplayName() + " to " + origRank)
    EndIf

    ; Clean up ceasefire-specific state
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_NeedsAggroRestore")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_CeasefirePartner")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalAggression")

    ; DON'T call EvaluatePackage here - let the NPC naturally decide
    ; whether to re-engage based on distance and perception
    ; If the player has walked away during the cooldown, they won't re-aggro
EndFunction
