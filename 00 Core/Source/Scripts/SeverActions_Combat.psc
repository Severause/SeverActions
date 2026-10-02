Scriptname SeverActions_Combat extends Quest
{Combat actions for SkyrimNet - handles attack commands, yield/surrender with faction conversion, and combat state tracking via StorageUtil}

; === PROPERTIES ===

; Neither follower faction is read by this script.
Faction Property CurrentFollowerFaction Auto
{Set to CurrentFollowerFaction from Skyrim.esm}

Faction Property SkyrimNetFollowerFaction Auto
{Set to SkyrimNet_FollowingPlayerFaction from SkyrimNet.esp if using SkyrimNet followers}

; Held during AttackTarget so the AIO flee patch suppresses flee packages;
; removed by RestoreOriginalValues and FullCleanup.
Faction Property SeverActions_AttackFaction Auto
{Added to the attacker during AttackTarget. Suppresses AIO flee.}

Faction Property SeverActions_TargetFaction Auto
{Added to the target during AttackTarget. Suppresses AIO flee.}

Float Property CombatCooldownDuration = 30.0 Auto
{Real seconds an actor stays on cooldown after a ceasefire or yield; while it runs AttackTarget and a
 brawl challenge involving them are refused. The quest VMAD fills 100, so 100 is the runtime value (DR18).}

; === SURRENDER FACTION SYSTEM ===

Faction Property SeverSurrenderedFaction Auto
{Faction for NPCs who have surrendered. Set as Ally to PlayerFaction in CK.}

; Has no VMAD fill: the natives fall back to TruceEligibility's hardcoded list
; (see PushCeasefireConfigToNative).
FormList Property SeverHostileFactions Auto

{FormList containing factions that should be replaced on surrender (Bandit, Forsworn, etc.)}
; === TRUCE SETTINGS ===
Bool Property TruceEnabled = False Auto
{Master toggle for the Truce layer: bandits (and opted-in factions) hold fire
until provoked. Ships OFF (game-changing, so an opt-in); never migrated.
Turning it off restores every pacified actor at once.}

Bool Property TruceLeaders = True Auto
{Include named camp leaders / bosses, so the chief can be negotiated with.
Quest-critical, essential, frenzied and quest-faction NPCs stay excluded.}

Bool Property TruceQuestNPCs = True Auto
{Include outlaws a RUNNING quest is using (camp chiefs are often radiant
targets). Attacking still breaks the truce camp-wide, so kill/clear objectives
work. Turn OFF if a quest needing an NPC to strike first stalls.}

Bool Property TruceDungeons = False Auto
{Include outlaws HOLDING a dungeon (barrow, crypt, Dwemer ruin) rather than a
camp. OFF by default: a place you delve stays a fight, at the cost of SkyrimNet
dialogue with those outlaws. Most camps also carry LocTypeDungeon, so the lair
keyword is checked first; sworn camps are never broken by this setting.}

Bool Property TruceNecromancers = True Auto
{Include NecromancerFaction. Their raised thralls are a separate faction and
still fight (no summon inheritance).}

Bool Property TruceForsworn = True Auto
{Include ForswornFaction. Quest-scoped Forsworn (the Markarth chain's MS01/MS02
factions) are excluded automatically by the eligibility gates.}

Bool Property TruceVampires = True Auto
{Include VampireFaction - ONLY while the player is a vampire themselves.}

Float Property TruceRadius = 8000.0 Auto
{How far from the player the Truce sweep reaches, in units. 512-12000.
Must exceed the range at which bandits notice you and close, or a garrison is
pacified one at a time as you walk in and the rest charge.}

; --- CAMP CHALLENGE ---
; Native CampChallenge decides WHEN a challenge is owed and WHO issues it;
; this script owns the walk over, the card, and the parley clock.

Bool Property CampChallengeEnabled = True Auto
{Master switch for the camp challenge encounter (native CampChallenge::SetEnabled,
 re-pushed on every load).}

Float Property ChallengeApproachDistance = 220.0 Auto
{How close the challenger walks before speaking. Wider than the arrest's
 approach: they are asking a question, not making an arrest.}

Bool Property CampChallengeCardEnabled = False Auto
{Show the Magelight card when the challenger arrives. OFF by default: the
 challenge is meant to be answered in dialogue; the card is an opt-in.}

Float Property ChallengeParleySeconds = 120.0 Auto
{How long the player has to talk once the parley opens. Running out is a
 refusal.}

Float Property ChallengeParleyDistance = 1400.0 Auto
{Walk further than this from the challenger mid-parley and it counts as
 walking away.}

; A cache of the native pending slot, not the authority: both handlers confirm
; against Camp_ChallengeIsPending.
Actor CurrentChallenger = None

Bool Property CampTakeoverEnabled = True Auto
{Allow outlaw camps to be taken over (the chief agreeing, or the survivors
throwing in). Off keeps the Truce standoff but removes the takeover actions.}

Bool Property CampFreezeRespawn = True Auto
{When a camp swears to you, freeze its encounter zone so it stops repopulating
with fresh hostiles.}

; === TRUCE PROBE (read-only test hooks) ===
; MEMBER functions on purpose: the natives are Globals on the unattached
; SeverActionsNativeExt, and SkyrimNet's execute_quest_function only calls quest
; script members.
; TruceProbe mutates nothing: it reports which nearby NPCs the Truce layer would
; pacify and which gate refused the rest (full detail in the SKSE log).
String Function TruceProbe(Float afRadius = 3000.0, Bool abNecromancers = false, Bool abForsworn = false, Bool abVampires = false)
    String result = SeverActionsNativeExt.Native_Truce_ExplainNearby(afRadius, abNecromancers, abForsworn, abVampires)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("combat.truceProbe", ("" + result)))
    Debug.Trace("[SeverActions_Combat] Truce probe: " + result)
    Return result
EndFunction

String Function CampProbe()
    {Read-only: list every camp discovered so far with its leader and state.}
    String result = SeverActionsNativeExt.Native_Camp_Probe()
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("combat.camps", ("" + result)))
    Return result
EndFunction

String Function CampFreezeHere()
    {Test hook: freeze respawn for the camp you are standing in.}
    String result = SeverActionsNativeExt.Native_Camp_FreezeHere()
    Debug.Notification(result)
    Return result
EndFunction

String Function CampSwearHere(Bool abViaLeader = true)
    {Test hook: make the camp you are standing in swear to you. The leader route
     uses the camp's actual leader, so the native's own guard is exercised; the
     leaderless route picks any living member.}
    ; Swearing enrolls the camp as an Enterprises Tribute venture (papyrus.cpp EnrollCamp):
    ; without that module the camp would be sworn with no venture behind it (C17).
    If !SeverActionsNativeExt2.Module_IsUsable("enterprises")
        ; Name from the manifest: the Papyrus string table folds case, so a literal
        ; "Enterprises" would print as the lowercase id interned just above.
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hud.moduleNotInstalled", "Swearing a camp", SeverActionsNativeExt2.Module_Name("enterprises")))
        Return "enterprises module not installed"
    EndIf
    Actor speaker = None
    If abViaLeader
        speaker = SeverActionsNativeExt2.Camp_LeaderAtPlayer()
    Else
        speaker = SeverActionsNativeExt2.Camp_AnyMemberAtPlayer()
    EndIf
    If !speaker
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("combat.noCampMemberFound"))
        Return "no camp member here"
    EndIf
    Bool ok = SeverActionsNativeExt2.Camp_Swear(speaker, abViaLeader)
    If ok
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("combat.theCampHasSworn"))
        Return "sworn"
    EndIf
    Debug.Notification(SeverActionsNativeExt2.Native_L10n("combat.campRefusedToSwear"))
    Return "refused"
EndFunction

String Function CampThawHere()
    {Undo CampFreezeHere for the camp you are standing in.}
    String result = SeverActionsNativeExt.Native_Camp_ThawHere()
    Debug.Notification(result)
    Return result
EndFunction

; TruceProbe for the actor under the crosshair.
String Function TruceProbeTarget(Bool abNecromancers = false, Bool abForsworn = false, Bool abVampires = false)
    String result = SeverActionsNativeExt.Native_Truce_ExplainTarget(abNecromancers, abForsworn, abVampires)
    Debug.Notification(result)
    Debug.Trace("[SeverActions_Combat] Truce probe (crosshair): " + result)
    Return result
EndFunction


; === YIELD PERSISTENCE ALIASES ===

ReferenceAlias[] Property YieldSlots Auto
{5 ReferenceAlias slots (SeverActions_YieldAlias attached, for OnDeath cleanup)
 holding surrendered generic hostiles so the engine does not recycle them
 across cells. Optional, Allow Reuse, Initially Cleared.}

Bool Property YieldPersistenceEnabled = true Auto
{Enable/disable yield alias persistence. When disabled, yielded generic NPCs
 may be recycled by the engine when crossing cells. Default: true.}

; === STORAGEUTIL KEYS (per actor) ===
; SeverCombat_CeasefireTime - Float (game hours x 3631 at the ceasefire, not gameTimeNumeric; 0160 expires it)
; SeverCombat_YieldTime - Float (game hours x 3631 at the yield, not gameTimeNumeric; 0160 expires it)
; SeverCombat_YieldedTo - Form (who this actor yielded to)
; SeverCombat_ReceivedYieldFrom - Form (who yielded to this actor)
; SeverCombat_InForcedCombat - Int (1 = currently in forced combat)
; SeverCombat_OriginalConfidence - Float (stored confidence value)
; SeverCombat_OriginalAggression - Float (stored aggression value)
; SeverCombat_OriginalRelationship - Int
; SeverCombat_CombatTarget - Form (who they're fighting)
; SeverCombat_CooldownEnd - RETIRED (native CombatCooldownStore)
; SeverCombat_WasSurrendered - Int (1 = this actor has surrendered)
; SeverCombat_WasNormallyHostile - Int (1 = held a hostile faction at yield/ceasefire
;     time; the prompt lets bandits fall back to hostility while guards/civilians stand down)
; SeverCombat_OriginalFaction - RETIRED, nothing writes it; the Unset calls only clear legacy saves
; SeverCombat_RemovedFactions - FormList, legacy (pre-native yield saves)
; SeverCombat_CeasefireRemovedFactions - FormList, legacy (pre-native ceasefire saves)
; SeverCombat_CeasefireFactionSwapped - Int, legacy (1 = restore the list above on break)
; SeverCombat_NeedsAggroRestore - RETIRED, nothing writes it
; SeverCombat_CeasefirePartner - RETIRED, nothing writes it
; SeverCombat_YieldBroken - Int (1 = surrender was broken, set by OnYieldBroken)
; SeverCombat_YieldBrokenTime - Float (game hours x 3631 at the break; 0160 shows the betrayal for a game day)
; On None: SeverCombat_YieldedGenericActors - FormList (yielded generics needing a slot)

SeverActions_Combat Function GetInstance() Global
    Quest kQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    Return kQuest as SeverActions_Combat
EndFunction

; === INITIALIZATION ===

Event OnInit()
    ; The same entry the provider's stage 0 uses on every load (C11).
    RegisterEvents()
EndEvent

Function PushCeasefireConfigToNative()
    If SeverSurrenderedFaction
        SeverActionsNativeExt.Ceasefire_SetSurrenderedFaction(SeverSurrenderedFaction)
        SeverActionsNativeExt.Yield_SetSurrenderedFaction(SeverSurrenderedFaction)
    EndIf
    If SeverHostileFactions
        SeverActionsNativeExt.Ceasefire_SetHostileFactionsList(SeverHostileFactions)
        SeverActionsNativeExt.Yield_SetHostileFactionsList(SeverHostileFactions)
    Else
        ; The ESP never fills this property; CeasefireMonitor and YieldMonitor then use
        ; TruceEligibility's hardcoded list. Logged so a reader of either side finds the other.
        Debug.Trace("[SeverActions_Combat] SeverHostileFactions is unbound (never filled in the ESP) - the native fallback list does the stripping")
    EndIf
    PushTruceConfigToNative()
EndFunction

Function PushTruceConfigToNative()
    {Push the saved Truce and camp settings into the natives (C++ defaults to OFF,
     bandits-only). Scope and radius go before SetEnabled so the first sweep
     already uses them.}
    ; One-shot: necromancers, Forsworn and vampires default ON now, and auto
    ; properties keep their saved value, so existing saves need this. It also
    ; overrides an earlier deliberate off (a bool cannot tell untouched from chosen).
    ; Ledger claim (rule 15): a sentinel gate alone re-runs wherever StorageUtil drops
    ; values (R14); the sentinel stays as the adopted done signal, still written for an older pex.
    String scopeMig = "TruceScopeDefaultOn"
    Bool scopeSentinel = StorageUtil.GetIntValue(None, "SeverActions_TruceScopeMigDone", 0) >= 1
    If !SeverActionsNativeExt2.Migration_AdoptSentinel(scopeMig, 1, scopeSentinel) && SeverActionsNativeExt2.Migration_TryClaim(scopeMig, 1)
        TruceNecromancers = True
        TruceForsworn     = True
        TruceVampires     = True
        Debug.Trace("[SeverActions] Truce scope migrated - nec/forsworn/vampires default ON")
        StorageUtil.SetIntValue(None, "SeverActions_TruceScopeMigDone", 1)
        SeverActionsNativeExt2.Migration_MarkDone(scopeMig, 1)
    EndIf
    ; One-shot: move the old 4000 default to 8000 (too short: garrisons charged
    ; before the sweep reached them). A radius the player chose is left alone,
    ; except a chosen 4000, which reads as the old default.
    String radiusMig = "TruceRadius8000"
    Bool radiusSentinel = StorageUtil.GetIntValue(None, "SeverActions_TruceRadiusMigDone", 0) >= 1
    If !SeverActionsNativeExt2.Migration_AdoptSentinel(radiusMig, 1, radiusSentinel) && SeverActionsNativeExt2.Migration_TryClaim(radiusMig, 1)
        If TruceRadius > 3999.0 && TruceRadius < 4001.0
            TruceRadius = 8000.0
            Debug.Trace("[SeverActions] Truce radius migrated 4000 -> 8000")
        EndIf
        StorageUtil.SetIntValue(None, "SeverActions_TruceRadiusMigDone", 1)
        SeverActionsNativeExt2.Migration_MarkDone(radiusMig, 1)
    EndIf
    ; The camp-cut migration lives in SeverActions_Enterprises (C17).
    SeverActionsNativeExt.Native_Truce_SetScope(TruceNecromancers, TruceForsworn, TruceVampires)
    SeverActionsNativeExt.Native_Truce_SetIncludeLeaders(TruceLeaders)
    SeverActionsNativeExt.Native_Truce_SetIncludeQuestNPCs(TruceQuestNPCs)
    SeverActionsNativeExt2.Native_Truce_SetDungeons(TruceDungeons)
    SeverActionsNativeExt.Native_Truce_SetRadius(TruceRadius)
    SeverActionsNativeExt.Native_Truce_SetEnabled(TruceEnabled)
    SeverActionsNativeExt2.Camp_SetTakeoverEnabled(CampTakeoverEnabled)
    SeverActionsNativeExt2.Camp_SetFreezeRespawn(CampFreezeRespawn)
    SeverActionsNativeExt2.Camp_ChallengeSetEnabled(CampChallengeEnabled)
    SeverActionsNativeExt2.Camp_ChallengeSetCard(CampChallengeCardEnabled)
    SeverActionsNativeExt2.Camp_ChallengeSetSeconds(ChallengeParleySeconds)
EndFunction

; === FORCED COMBAT END HOOK ===
; ForcedCombatMonitor (TESCombatEvent sink) clears the native InForcedCombat flag
; and fires this when a flagged actor leaves combat. FullCleanup restores the
; Confidence, Aggression, ranks and factions AttackTarget changed.

Event OnForcedCombatEnded(String eventName, String strArg, Float numArg, Form sender)
    Actor a = sender as Actor
    If !a
        Return
    EndIf
    ; Never FullCleanup an actor that just yielded or ceasefired: it would re-add
    ; their hostile factions. Yield/CeaseFire clear the forced flag before
    ; stopping combat; this guard covers a combat-end that beat the flag clear.
    If StorageUtil.GetIntValue(a, "SeverCombat_WasSurrendered", 0) == 1 || SeverActionsNative.IsYieldMonitored(a) || SeverActionsNative.Ceasefire_IsMonitored(a)
        Debug.Trace("[SeverCombat] ForcedCombatEnded for " + a.GetDisplayName() + " - skipped (yield/ceasefire owns this actor's state)")
        Return
    EndIf
    Debug.Trace("[SeverCombat] ForcedCombatEnded for " + a.GetDisplayName() + " - running FullCleanup")
    FullCleanup(a)
EndEvent

; === MAIN ATTACK FUNCTION ===

Function AttackTarget_Execute(Actor akAttacker, Actor akTarget)
{The AttackTarget action: a companion who attacks the player or another companion leaves the
 player's service first (LeaveServiceToAttack), then _AttackTarget.}
    _AttackTarget(akAttacker, akTarget, True)
EndFunction

Function _AttackTarget(Actor akAttacker, Actor akTarget, Bool abLeaveService)
{ForceAttack, refused while the cooldown of a ceasefire, yield or brawl holds either party
 (AttackOnCooldown). The Actions-page verb passes abLeaveService False: an attack the player
 orders keeps the attacker in their service.}
    If !akAttacker || !akTarget
        Debug.Trace("[SeverCombat] AttackTarget: Invalid actor(s)")
        Return
    EndIf
    If AttackOnCooldown(akAttacker, akTarget)
        Debug.Trace("[SeverCombat] AttackTarget REFUSED: " + akAttacker.GetDisplayName() + " -> " + akTarget.GetDisplayName() + " - cooldown active")
        ; The cooldown is per actor: name whoever holds it, not a truce between the two.
        String refusal = akAttacker.GetDisplayName() + " is in no state to start another fight so soon."
        If !IsActorInCooldown(akAttacker)
            refusal = akTarget.GetDisplayName() + " has only just come out of a fight, and " + akAttacker.GetDisplayName() + " holds back."
        EndIf
        SkyrimNetApi.RegisterEvent("attack_refused", refusal, akAttacker, akTarget)
        Return
    EndIf
    If abLeaveService
        LeaveServiceToAttack(akAttacker, akTarget)
    EndIf
    ForceAttack(akAttacker, akTarget)
EndFunction

Function LeaveServiceToAttack(Actor akAttacker, Actor akTarget)
{A rostered companion attacking the player or another companion leaves the player's service
 (the followers module's "leaveToAttack"), so the friendly-fire guard lets the fight happen.
 NFF tears its seat down asynchronously: settle before combat starts, as the brawl does.}
    Actor player = Game.GetPlayer()
    ; ForceAttack's own refusals first: nobody leaves for an attack that will not happen.
    If akAttacker == akTarget || akAttacker.IsDead() || akTarget.IsDead()
        Return
    EndIf
    If akAttacker == player || !SeverActionsNativeExt.Native_GetIsFollower(akAttacker)
        Return
    EndIf
    If akTarget != player && !SeverActionsNativeExt2.FriendlyFire_IsProtected(akTarget)
        Return
    EndIf
    Bool wasNFF = SeverActionsNativeExt2.Native_IsNFFManaged(akAttacker)
    If SeverActions_ModuleBase.CallBool("followers", "leaveToAttack", akAttacker, akTarget) && wasNFF
        Utility.Wait(2.0)
    EndIf
EndFunction

Bool Function AttackOnCooldown(Actor akAttacker, Actor akTarget)
{True while the attacker, or a target other than the player, is on cooldown. The player's own
 cooldown does not protect them: every yield or ceasefire made with them sets it.}
    If IsActorInCooldown(akAttacker)
        Return True
    EndIf
    Return akTarget && akTarget != Game.GetPlayer() && IsActorInCooldown(akTarget)
EndFunction

Function ForceAttack(Actor akAttacker, Actor akTarget)
{Forces akAttacker to attack akTarget, and akTarget to fight back. No cooldown check: a brawl
 that broke into real combat is handed here right after its cooldown is set.}
    
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

    ; Camp oath auto-break: a sworn chief attacking the player or a teammate
    ; renounces the oath (the LLM may pick AttackTarget over RenounceCampOath),
    ; through the same cascade, so the whole crew turns together. Camp_State
    ; 2 = sworn; wild camps stay on the truce rules.
    If akTarget == Game.GetPlayer() || akTarget.IsPlayerTeammate()
        If SeverActionsNativeExt2.Camp_State(akAttacker) == 2 && SeverActionsNativeExt2.Camp_IsLeader(akAttacker)
            If SeverActionsNativeExt2.Camp_Renounce(akAttacker)
                Debug.Trace("[SeverCombat] AttackTarget: sworn chief " + akAttacker.GetDisplayName() + " turned on the player - oath renounced, camp hostile")
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("combat.campHasTurnedOn", ("" + akAttacker.GetDisplayName())))
                SkyrimNetApi.RegisterEvent("camp_oath_broken", akAttacker.GetDisplayName() + " turned on " + akTarget.GetDisplayName() + " - the camp's oath to " + Game.GetPlayer().GetDisplayName() + " is broken and the whole crew turns hostile", akAttacker, akTarget)
            EndIf
        EndIf
    EndIf

    ; Camp challenge answered with steel: attacking during a live challenge is
    ; the refusal verdict (the LLM may pick AttackTarget over RunThemOff).
    ; NoteAttack breaks the whole camp by roster when the attacker is the
    ; challenger or a member of the questioned camp; the attack then proceeds.
    If akTarget == Game.GetPlayer() || akTarget.IsPlayerTeammate()
        If SeverActionsNativeExt2.Camp_ChallengeNoteAttack(akAttacker)
            Debug.Trace("[SeverCombat] AttackTarget: during a live challenge - verdict is refusal, camp broken")
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("combat.campTurnsOnYou", ("" + akAttacker.GetDisplayName())))
            ; The parley clock is the challenger's (the attacker may be another member).
            Actor challenger = CurrentChallenger
            If challenger == None
                challenger = akAttacker
            EndIf
            ; NoteAttack refused the challenge, so the slot is spent whoever swung; the walk is
            ; the challenger's.
            CurrentChallenger = None
            SeverActionsNativeExt2.Native_Persuasion_EndFor(challenger)
            CleanUpChallengeWalk(challenger)
        EndIf
    EndIf

    ; Fully reset a surrendered or ceasefired actor first, or the monitor still
    ; tracking them fires YieldBroken/CeasefireBroken mid-fight and leaves
    ; dual-faction state.
    If StorageUtil.GetIntValue(akAttacker, "SeverCombat_WasSurrendered", 0) == 1 || SeverActionsNative.Ceasefire_IsMonitored(akAttacker) || SeverActionsNative.IsYieldMonitored(akAttacker)
        Debug.Trace("[SeverCombat] AttackTarget: attacker " + akAttacker.GetDisplayName() + " was surrendered/ceasefire'd - running FullCleanup first")
        FullCleanup(akAttacker)
    EndIf
    If StorageUtil.GetIntValue(akTarget, "SeverCombat_WasSurrendered", 0) == 1 || SeverActionsNative.Ceasefire_IsMonitored(akTarget) || SeverActionsNative.IsYieldMonitored(akTarget)
        Debug.Trace("[SeverCombat] AttackTarget: target " + akTarget.GetDisplayName() + " was surrendered/ceasefire'd - running FullCleanup first")
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

    ; Both actors: FullCleanup restores whichever one ForcedCombatMonitor sees leave combat.
    StoreOriginalValues(akAttacker)
    StoreOriginalValues(akTarget)

    ; Snapshot the original ranks, never mid-fight: a repeat AttackTarget would
    ; store the forced -4 as the original and make the hostility permanent.
    If StorageUtil.GetIntValue(akAttacker, "SeverCombat_InForcedCombat", 0) == 0
        StorageUtil.SetIntValue(akAttacker, "SeverCombat_OriginalRelationship", akAttacker.GetRelationshipRank(akTarget))
    EndIf
    If StorageUtil.GetIntValue(akTarget, "SeverCombat_InForcedCombat", 0) == 0
        StorageUtil.SetIntValue(akTarget, "SeverCombat_OriginalRelationship", akTarget.GetRelationshipRank(akAttacker))
    EndIf

    StorageUtil.SetFormValue(akAttacker, "SeverCombat_CombatTarget", akTarget)
    StorageUtil.SetFormValue(akTarget, "SeverCombat_CombatTarget", akAttacker)
    StorageUtil.SetIntValue(akAttacker, "SeverCombat_InForcedCombat", 1)
    StorageUtil.SetIntValue(akTarget, "SeverCombat_InForcedCombat", 1)
    SeverActionsNative.Native_SetInForcedCombat(akAttacker, true)
    SeverActionsNative.Native_SetInForcedCombat(akTarget, true)
    ; The friendly-fire guard exempts this pair only (IsDeliberate).
    SeverActionsNativeExt2.Native_SetForcedCombatPartner(akAttacker, akTarget)
    SeverActionsNativeExt2.Native_SetForcedCombatPartner(akTarget, akAttacker)

    ; The AIO flee-suppression factions.
    If SeverActions_AttackFaction
        akAttacker.AddToFaction(SeverActions_AttackFaction)
    EndIf
    If SeverActions_TargetFaction
        akTarget.AddToFaction(SeverActions_TargetFaction)
    EndIf

    ; Prepare attacker for combat (confidence boost only)
    PrepareForCombat(akAttacker)
    
    ; Relationship rank + StartCombat only: changing factions here turned
    ; bystanders (followers especially) hostile.
    akAttacker.SetRelationshipRank(akTarget, -4)
    akTarget.SetRelationshipRank(akAttacker, -4)
    
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
    Return !AttackOnCooldown(akAttacker, akTarget)
EndFunction

; === CEASEFIRE FUNCTION ===

Function CeaseFire_Execute(Actor akActor1, Actor akActor2)
{Stop two actors fighting and extend the ceasefire to nearby faction allies
 (native CeasefireMonitor::PropagateGroup does the per-actor work). Indefinite:
 aggression stays 0 until the player attacks them or an NPC calls AttackTarget.}

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

    ; Clear the forced-combat flag BEFORE PropagateGroup stops combat, or
    ; ForcedCombatEnded -> FullCleanup breaks the ceasefire being made.
    SeverActionsNative.Native_SetInForcedCombat(akActor1, false)
    StorageUtil.UnsetIntValue(akActor1, "SeverCombat_InForcedCombat")
    If akStoredTarget
        SeverActionsNative.Native_SetInForcedCombat(akStoredTarget, false)
        StorageUtil.UnsetIntValue(akStoredTarget, "SeverCombat_InForcedCombat")
    EndIf

    ; Initiator + partner + nearby combat-active faction allies; returns the affected actors.
    Actor[] affected = SeverActionsNativeExt.Ceasefire_PropagateGroup(akActor1, akStoredTarget, 4096.0)

    ; The prompt reads these two keys through papyrus_util(), so they live in StorageUtil.
    Float ceasefireTime = Utility.GetCurrentGameTime() * 24 * 3631
    If affected
        Int i = 0
        While i < affected.Length
            Actor a = affected[i]
            If a
                StorageUtil.SetFloatValue(a, "SeverCombat_CeasefireTime", ceasefireTime)
                StorageUtil.UnsetIntValue(a, "SeverCombat_YieldBroken")
                If SeverActionsNativeExt.Ceasefire_IsWasNormallyHostile(a)
                    StorageUtil.SetIntValue(a, "SeverCombat_WasNormallyHostile", 1)
                EndIf
            EndIf
            i += 1
        EndWhile
        Debug.Trace("[SeverCombat] CeaseFire: native affected " + affected.Length + " actor(s)")
    EndIf

    ; Undo AttackTarget's edits as Yield does: Confidence and the Attack/Target
    ; factions, the forced -4 ranks, and the combat-pair keys.
    RestoreOriginalValues(akActor1)
    If akStoredTarget
        RestoreOriginalValues(akStoredTarget)
        ; Only a forced fight stored a rank: a fight that flared on its own changed none.
        If StorageUtil.HasIntValue(akActor1, "SeverCombat_OriginalRelationship")
            akActor1.SetRelationshipRank(akStoredTarget, StorageUtil.GetIntValue(akActor1, "SeverCombat_OriginalRelationship", 0))
        EndIf
        If StorageUtil.HasIntValue(akStoredTarget, "SeverCombat_OriginalRelationship")
            akStoredTarget.SetRelationshipRank(akActor1, StorageUtil.GetIntValue(akStoredTarget, "SeverCombat_OriginalRelationship", 0))
        EndIf
        ClearAllCombatState(akStoredTarget)
    EndIf
    ClearAllCombatState(akActor1)

    ; Cooldown: refuses AttackTarget and a brawl challenge for a while.
    ApplyCooldown(akActor1, akStoredTarget)

    Debug.Trace("[SeverCombat] CeaseFire complete - group ceasefire active, indefinite until player attacks or NPC re-engages")
EndFunction

Bool Function CeaseFire_IsEligible(Actor akActor1, Actor akActor2)
    If !akActor1
        Return False
    EndIf
    ; At least one must be in combat
    Return akActor1.IsInCombat() || (akActor2 && akActor2.IsInCombat())
EndFunction

; === YIELD / SURRENDER FUNCTION ===

Function Yield_Execute(Actor akYielder)
{Makes an actor yield/surrender. Native Yield_ConvertToSurrendered swaps
 factions, zeroes aggression and registers the monitor; Papyrus stops combat,
 restores relationship ranks (CommonLibSSE-NG has no rank API), and keeps the
 prompt keys, the yield slot and the cooldown.}

    If !akYielder
        Debug.Trace("[SeverCombat] Yield: Yielder is None")
        Return
    EndIf

    Debug.Trace("[SeverCombat] Yield: " + akYielder.GetDisplayName() + " is yielding")

    ; Clear the forced-combat flag BEFORE StopCombat, or ForcedCombatEnded ->
    ; FullCleanup re-hostiles the freshly surrendered actor.
    Actor akStoredTarget = StorageUtil.GetFormValue(akYielder, "SeverCombat_CombatTarget") as Actor
    SeverActionsNative.Native_SetInForcedCombat(akYielder, false)
    If akStoredTarget
        SeverActionsNative.Native_SetInForcedCombat(akStoredTarget, false)
    EndIf

    akYielder.StopCombatAlarm()
    akYielder.StopCombat()
    If akStoredTarget
        akStoredTarget.StopCombatAlarm()
        akStoredTarget.StopCombat()
    EndIf

    RestoreOriginalValues(akYielder)
    If akStoredTarget
        RestoreOriginalValues(akStoredTarget)
    EndIf

    If akStoredTarget
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

    ; Read by FullCleanup, and by ReassignYieldSlots when the native monitor lost this actor.
    StorageUtil.SetFloatValue(akYielder, "SeverCombat_OriginalAggression", akYielder.GetActorValue("Aggression"))

    ; The native keeps the removed factions in its YieldedActorData entry, which
    ; OnYieldBroken / ReturnToCrime / FullCleanup restore from.
    Bool wasHostile = SeverActionsNativeExt.Yield_ConvertToSurrendered(akYielder)
    StorageUtil.SetIntValue(akYielder, "SeverCombat_WasSurrendered", 1)
    ; A new surrender replaces an old broken one (0160's Betrayed Surrender).
    StorageUtil.UnsetIntValue(akYielder, "SeverCombat_YieldBroken")
    If wasHostile
        StorageUtil.SetIntValue(akYielder, "SeverCombat_WasNormallyHostile", 1)
    EndIf
    SeverActionsNative.Native_SetSurrendered(akYielder, true)

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

; === FACTION CONVERSION SYSTEM ===

Function RestoreHostileFactions(Actor akActor, String storageKey)
{Legacy restore for saves from before the native yield/ceasefire stores (used by
 FullCleanup): removes SeverSurrenderedFaction, re-adds every faction in the
 named StorageUtil FormList, then clears the list.}
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
{Revert a surrendered actor to their hostile faction(s). Yield_ReturnToCrime
 does the restore and the unregister; Papyrus clears the prompt-side keys.}

    If !akActor
        Return
    EndIf

    If StorageUtil.GetIntValue(akActor, "SeverCombat_WasSurrendered", 0) != 1
        Debug.Trace("[SeverCombat] ReturnToCrime: " + akActor.GetDisplayName() + " was never surrendered")
        Return
    EndIf

    Debug.Trace("[SeverCombat] ReturnToCrime: " + akActor.GetDisplayName() + " returning to hostile faction")

    ClearYieldSlot(akActor)

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

; === HELPER FUNCTIONS ===

Function ClearAllCombatState(Actor akActor)
{Completely clear all combat-related StorageUtil keys for an actor}
    ; Clear combat tracking
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_CombatTarget")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_InForcedCombat")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_OriginalRelationship")

    ; Clear stored original values (already restored by this point)
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_OriginalConfidence")
    
    ; Deliberately kept: the prompt keys (CeasefireTime, YieldTime, YieldedTo,
    ; ReceivedYieldFrom; the prompt expires them by time) and the surrender keys
    ; (WasSurrendered, OriginalAggression, legacy RemovedFactions), which
    ; ReturnToCrime / OnYieldBroken / FullCleanup clear.
EndFunction

Function PrepareForCombat(Actor akActor)
{Set actor values for combat - only boost confidence so they don't flee}
    ; Aggression is left alone: a raised value that is never restored makes the
    ; NPC attack unintended targets.

    ; Confidence: 0=Cowardly, 1=Cautious, 2=Average, 3=Brave, 4=Foolhardy
    akActor.SetActorValue("Confidence", 3)

    akActor.EvaluatePackage()
EndFunction

Function StoreOriginalValues(Actor akActor)
{Store the actor's original Confidence and Aggression in StorageUtil (FullCleanup restores both).}
    ; Skipped mid-fight, so a forced value is never stored as the original.
    If StorageUtil.GetIntValue(akActor, "SeverCombat_InForcedCombat", 0) == 0
        StorageUtil.SetFloatValue(akActor, "SeverCombat_OriginalConfidence", akActor.GetActorValue("Confidence"))
        StorageUtil.SetFloatValue(akActor, "SeverCombat_OriginalAggression", akActor.GetActorValue("Aggression"))
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

    ; Drop the AIO flee-suppression factions. TRUE removal: RemoveFromFaction leaves a
    ; rank -1 entry, and the AIO patch's GetInFaction package conditions are rank-blind,
    ; so the survivor still could not flee (see Follow.ClearWaitingFaction).
    _DropFactionClean(akActor, SeverActions_AttackFaction)
    _DropFactionClean(akActor, SeverActions_TargetFaction)
EndFunction

Function _DropFactionClean(Actor akActor, Faction akFaction)
{Erase a runtime membership outright; on a survivor (issue #437) fall back to RemoveFromFaction.}
    If !akFaction
        Return
    EndIf
    SeverActionsNativeExt2.Faction_RemoveClean(akActor, akFaction)
    If akActor.GetFactionRank(akFaction) >= 0
        Debug.Trace("[SeverCombat] WARNING: " + akFaction.GetName() + " survived Faction_RemoveClean on " + akActor.GetDisplayName() + " - RemoveFromFaction fallback applied")
        akActor.RemoveFromFaction(akFaction)
    EndIf
EndFunction

; === COOLDOWN ===

Function ApplyCooldown(Actor akActor, Actor akPartner)
{Put both actors on cooldown (native CombatCooldownStore, cosaved FormID -> expiry); AttackTarget
 (AttackOnCooldown) and ChallengeBrawl_Execute refuse while it runs.}
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

    akActor.StopCombatAlarm()
    akActor.StopCombat()

    ; Yield_ForceBreak = ReturnToCrime: restore aggression and factions, unregister.
    If SeverActionsNative.IsYieldMonitored(akActor)
        SeverActionsNativeExt.Yield_ForceBreak(akActor)
        SeverActionsNative.Native_SetSurrendered(akActor, false)
    ElseIf StorageUtil.GetIntValue(akActor, "SeverCombat_WasSurrendered", 0) == 1
        ; Surrendered but unmonitored (a pre-native save): the legacy restore.
        RestoreHostileFactions(akActor, "SeverCombat_RemovedFactions")
        SeverActionsNative.UnregisterYieldedActor(akActor)
    Else
        ; Not surrendered: still make sure they are out of SeverSurrenderedFaction
        ; (a ceasefire swap puts them there without WasSurrendered).
        If SeverSurrenderedFaction && akActor.IsInFaction(SeverSurrenderedFaction)
            akActor.RemoveFromFaction(SeverSurrenderedFaction)
        EndIf
        SeverActionsNative.UnregisterYieldedActor(akActor)
    EndIf

    ; A live ceasefire: Ceasefire_ForceBreak restores aggression and factions
    ; without the CeasefireBroken ModEvent, so OnCeasefireBroken does not run mid-wipe.
    If SeverActionsNative.Ceasefire_IsMonitored(akActor)
        SeverActionsNativeExt.Ceasefire_ForceBreak(akActor)
    EndIf

    ; Legacy: a pre-native ceasefire save restores through StorageUtil.
    If StorageUtil.GetIntValue(akActor, "SeverCombat_CeasefireFactionSwapped", 0) == 1
        RestoreHostileFactions(akActor, "SeverCombat_CeasefireRemovedFactions")
        StorageUtil.UnsetIntValue(akActor, "SeverCombat_CeasefireFactionSwapped")
    EndIf

    ; Always clear the native surrendered flag: the two flags can disagree after a
    ; partial write, and a stuck native flag keeps decorators reporting a surrender.
    SeverActionsNative.Native_SetSurrendered(akActor, false)

    ; Restore the ranks AttackTarget forced to -4. Safe when both actors get
    ; ForcedCombatEnded: each call restores both directions while the partner's
    ; key exists and unsets only its own keys.
    Actor rankPartner = StorageUtil.GetFormValue(akActor, "SeverCombat_CombatTarget") as Actor
    If rankPartner && StorageUtil.HasIntValue(akActor, "SeverCombat_OriginalRelationship")
        akActor.SetRelationshipRank(rankPartner, StorageUtil.GetIntValue(akActor, "SeverCombat_OriginalRelationship", 0))
        If StorageUtil.HasIntValue(rankPartner, "SeverCombat_OriginalRelationship")
            rankPartner.SetRelationshipRank(akActor, StorageUtil.GetIntValue(rankPartner, "SeverCombat_OriginalRelationship", 0))
        EndIf
        Debug.Trace("[SeverCombat] Restored relationship ranks between " + akActor.GetDisplayName() + " and " + rankPartner.GetDisplayName())
    EndIf

    ; Restore aggression if stored; otherwise leave it.
    Float originalAggression = StorageUtil.GetFloatValue(akActor, "SeverCombat_OriginalAggression", -1.0)
    If originalAggression >= 0.0
        akActor.SetActorValue("Aggression", originalAggression)
        Debug.Trace("[SeverCombat] Restored aggression to stored value: " + originalAggression)
    Else
        ; SetActorValue writes the BASE, so a guessed default would re-tune the NPC for good.
        Debug.Trace("[SeverCombat] No stored aggression for " + akActor.GetDisplayName() + " - leaving it as is")
    EndIf
    
    ; Restore confidence if stored; otherwise leave it.
    Float originalConfidence = StorageUtil.GetFloatValue(akActor, "SeverCombat_OriginalConfidence", -1.0)
    If originalConfidence >= 0.0
        akActor.SetActorValue("Confidence", originalConfidence)
        Debug.Trace("[SeverCombat] Restored confidence to stored value: " + originalConfidence)
    Else
        Debug.Trace("[SeverCombat] No stored confidence for " + akActor.GetDisplayName() + " - leaving it as is")
    EndIf

    ; Also drops the AIO flee-suppression factions: a fight that ended on its own left
    ; the survivor unable to flee under the AIO patch for good.
    RestoreOriginalValues(akActor)

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
    SeverActionsNativeExt.Cooldown_Clear(akActor)

    ; Clear surrender state
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasSurrendered")
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasNormallyHostile")
    StorageUtil.UnsetFormValue(akActor, "SeverCombat_OriginalFaction")
    ; The YieldBroken prompt flag (a new yield or ceasefire also clears it).
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_YieldBroken")
    StorageUtil.UnsetFloatValue(akActor, "SeverCombat_YieldBrokenTime")
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

Function HealPlayerAggression()
    {Reset the player's Aggression to 0 (combat provider, stage 1, every load).
     Pre-2.1.8 AttackTarget could leave it at 2 in the save, which makes Calm NPCs
     flee on sight; a no-op on healthy saves.}
    Actor playerRef = Game.GetPlayer()
    If !playerRef
        Return
    EndIf
    Float currentAggression = playerRef.GetActorValue("Aggression")
    If currentAggression > 0.0
        playerRef.SetActorValue("Aggression", 0.0)
        Debug.Trace("[SeverActions] Healed corrupted player aggression: " + currentAggression + " -> 0")
    EndIf
EndFunction

Function RegisterEvents()
    {Event registrations and native pushes, before any recovery runs. Called from
     the combat provider's stage 0 (plan 3.4) and from OnInit; registrations live
     here, not in the provider, so they stay keyed to the quest handle old saves
     hold (DR16). Idempotent.}
    RegisterForModEvent("SeverActionsNative_YieldBroken", "OnYieldBroken")
    RegisterForModEvent("SeverActionsNative_CeasefireBroken", "OnCeasefireBroken")
    RegisterForModEvent("SeverActions_ForcedCombatEnded", "OnForcedCombatEnded")
    RegisterForModEvent("SeverActions_CampChallenge", "OnCampChallenge")
    RegisterForModEvent("SeverActions_CampChallengeChoice", "OnCampChallengeChoice")
    ; NOT registered for SeverActions_PersuasionFailed - do not add: the first (form, event)
    ; registration wins, so another callback name here would never fire. ArrestPlayer and
    ; Ambush share its canonical callback; the camp-challenge refusal is routed natively
    ; (PersuasionMonitor -> SeverActions_CampChallengeCleanup).
    ; Combat and brawl verbs from the DLL's verb table (M-V).
    RegisterForModEvent("SeverActions_Verb_Combat", "OnVerb_Combat")
    RegisterForModEvent("SeverActions_Hotkey_Combat", "OnHotkey_Combat")   ; the Yield hotkey (M-K)
    RegisterForModEvent("SeverActions_CampChallengeCleanup", "OnCampChallengeCleanup")
    RegisterForModEvent("SeverActions_CampHoardPlundered", "OnCampHoardPlundered")
    ; The challenge walk's arrival: shared event, canonical callback (M-E).
    RegisterForModEvent("SeverActionsNative_OnArrival", "OnArrival")
    ; Re-push the owner-hosted properties on every load (the native config can drift).
    ; This also runs PushTruceConfigToNative - do not call that again here.
    PushCeasefireConfigToNative()
EndFunction

Function OnGameLoaded()
    {Load-time recovery, from the combat provider's stage 1 on every load (plan 3.4;
     registrations are RegisterEvents' at stage 0). A Quest script never receives
     OnPlayerLoadGame.}
    ; The native challenge (pending slot, parley window, arrival watch) does not survive a load,
    ; but the walk's package override and LinkedRef do: tear down the saved challenger's walk, or
    ; they trail the player with a drawn weapon. A challenge the sweep re-issued before this check
    ; is kept (one re-issued to the same chief mid-teardown stalls until the native watchdog
    ; drops it and the sweep asks again); a stale slot would drop every later challenge.
    Actor savedChallenger = CurrentChallenger
    If savedChallenger && !SeverActionsNativeExt2.Camp_ChallengeIsPending(savedChallenger)
        If CurrentChallenger == savedChallenger
            CurrentChallenger = None
        EndIf
        Debug.Trace("[SeverActions] Combat OnGameLoaded: challenge walk dropped from " + savedChallenger.GetDisplayName() + " (saved mid-challenge)")
        CleanUpChallengeWalk(savedChallenger)
        If !savedChallenger.IsInCombat()
            savedChallenger.SheatheWeapon()
        EndIf
    EndIf

    ReassignYieldSlots()
    ; Ceasefires restore from CeasefireMonitor's 'CEAS' cosave record.
EndFunction

Event OnCeasefireBroken(String eventName, String strArg, Float numArg, Form sender)
    {A player hit broke a ceasefire. CeasefireMonitor already restored aggression
     and factions (ranks were restored when the ceasefire was made, so the pair
     turns on the player, not each other); this clears the prompt and legacy keys.}
    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf

    Debug.Trace("[SeverCombat] CeasefireBroken: " + akActor.GetDisplayName() + " - clearing prompt-side state")

    ; Legacy keys from pre-native ceasefire saves.
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

; === YIELD BROKEN EVENT HANDLER ===

Event OnYieldBroken(string eventName, string strArg, float numArg, Form sender)
    {YieldMonitor: a yielded actor took enough hits to break surrender. C++ already
     restored aggression and factions; this clears the yield's prompt keys (not the
     hostile-tone flag), stamps the YieldBroken flag and fires the SkyrimNet event.}
    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf

    Debug.Trace("[SeverCombat] YieldBroken: " + akActor.GetDisplayName() + " was attacked after surrendering")

    ClearYieldSlot(akActor)

    ; Prompt-side state cleanup. SeverCombat_WasNormallyHostile stays: 0160 reads it
    ; beside SeverCombat_YieldBroken for the betrayed-surrender tone, and FullCleanup
    ; clears the two together.
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_WasSurrendered")
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
    StorageUtil.SetFloatValue(akActor, "SeverCombat_YieldBrokenTime", Utility.GetCurrentGameTime() * 24 * 3631)

    If playerRef
        SkyrimNetApi.RegisterEvent("yield_broken", \
            akActor.GetDisplayName() + " was attacked after surrendering and is fighting back against " + playerRef.GetDisplayName(), \
            akActor, playerRef)
    EndIf

    Debug.Trace("[SeverCombat] YieldBroken complete for " + akActor.GetDisplayName())
EndEvent

; === YIELD PERSISTENCE (alias slots for generic NPCs) ===

Function AssignYieldSlot(Actor akActor)
    {Seat the actor in an empty YieldSlot and add them to the tracking list that
     ReassignYieldSlots refills from on load.}
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

    Debug.Trace("[SeverCombat] WARNING: No free yield slots for " + akActor.GetDisplayName() + " - NPC may not persist across cells")
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
    {Refill the yield slots from SeverCombat_YieldedGenericActors on every load,
     pruning dead or no-longer-surrendered entries.}
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

                ; YieldMonitor restores from its 'YLDD' cosave record; re-register only
                ; when it lost the actor, or the 1.0 default here would stomp the original.
                If !SeverActionsNative.IsYieldMonitored(npc)
                    Float origAggro = StorageUtil.GetFloatValue(npc, "SeverCombat_OriginalAggression", 1.0)
                    SeverActionsNative.RegisterYieldedActor(npc, origAggro, SeverSurrenderedFaction)
                EndIf

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

; === CAMP CHALLENGE ===
; Flow:
;   native CampChallenge   -> SeverActions_CampChallenge  (challenger picked)
;   OnCampChallenge        -> walk them to the player     (follow pkg + Arrival)
;   HandleChallengeArrived -> the card                    (Magelight prompt)
;   OnCampChallengeChoice  -> posture                     (parley / refuse)
;   parley                 -> the OUTLAW decides in dialogue via the
;                             LetThemPass / RunThemOff actions
;
; Fail-open throughout: a path that cannot complete the encounter (no
; challenger, no UI, a walk that never finishes) ALLOWS, so plumbing never
; starts a fight. Only a real answer, or a refusal to give one, turns the camp.

; The walk borrows the arrest's follow-player package, by FormID: combat may not
; name the arrest module's type (DR2).
Package Function ChallengeFollowPackage() Global
    {SeverActions_GuardFollowPlayer - Target = LinkedRef with FollowTargetKW.}
    Return Game.GetFormFromFile(0x0AEAF6, "SeverActions.esp") as Package
EndFunction

Keyword Function ChallengeFollowKeyword() Global
    {SeverActions_FollowTargetKW - the LinkedRef keyword that package follows.}
    Return Game.GetFormFromFile(0x030155, "SeverActions.esp") as Keyword
EndFunction

Event OnArrival(String eventName, String strArg, Float numArg, Form sender)
    {Shared native arrival (M-E): every consumer's OnArrival fires for every arrival,
     so answer only our own tag.}
    If strArg != "camp_challenge_arrived"
        Return
    EndIf
    Actor arrived = sender as Actor
    If arrived
        HandleChallengeArrived(arrived)
    EndIf
EndEvent

Function CleanUpChallengeWalk(Actor akChallenger)
    {Drop the walk: the arrival and stuck watches, the look-at, the follow override and, unless
     another system holds them, the FollowTargetKW link. The drawn weapon and the parley window
     are the caller's. Safe to call twice.}
    If akChallenger == None
        Return
    EndIf
    SeverActionsNativeExt.Arrival_Cancel(akChallenger)
    SeverActionsNativeExt.Stuck_StopTracking(akChallenger)
    akChallenger.ClearLookAt()
    ; Brawl's challenge walk uses the same package; its own teardown removes it.
    Package followPkg = ChallengeFollowPackage()
    If followPkg && !SeverActionsNative.Native_BrawlChallenge_IsActive(akChallenger)
        ActorUtil.RemovePackageOverride(akChallenger, followPkg)
    EndIf
    ; The link is cosaved (LREF) and re-applied on every load, so it goes too, unless another
    ; system has since taken them on the same keyword.
    Keyword followKW = ChallengeFollowKeyword()
    If followKW && !_WalkClaimedElsewhere(akChallenger)
        SeverActionsNative.LinkedRef_Clear(akChallenger, followKW)
    EndIf
    akChallenger.EvaluatePackage()
EndFunction

Bool Function _WalkClaimedElsewhere(Actor akActor)
    {True while another system holds akActor on FollowTargetKW: an arrest session or task, the
     Final Audit, a bodyguard post, a kidnap or a brawl challenge (the holders
     SeverActions_Arrest.ClearStaleArrestState also exempts).}
    Return SeverActionsNative.Native_ArrestSession_HasSession(akActor) \
        || SeverActionsNativeExt2.Native_ArrestSession_IsGuardOnTask(akActor) \
        || SeverActionsNativeExt2.Venture_Audit_IsCollector(akActor) \
        || (SeverActionsNative.Native_GetWorkLoc(akActor) as Actor) != None \
        || SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) != 0 \
        || SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akActor) != None \
        || SeverActionsNative.Native_BrawlChallenge_IsActive(akActor)
EndFunction

Event OnCampChallenge(String eventName, String strArg, Float numArg, Form sender)
    {Native picked a challenger. Walk them over to the player (see
     ChallengeFollowPackage).}

    Actor challenger = sender as Actor
    Debug.Trace("[SeverActions] OnCampChallenge fired, challenger=" + challenger)
    If challenger == None
        Debug.Trace("[SeverActions] OnCampChallenge: sender did not resolve to an Actor - allowing")
        SeverActionsNativeExt2.Camp_ChallengeAllow()
        Return
    EndIf
    ; A traveler does not leave the road to challenge anyone.
    If SeverActionsNativeExt2.Travel_GetPhaseByActor(challenger) == 1
        Debug.Trace("[SeverActions] OnCampChallenge: " + challenger.GetDisplayName() + " is traveling - allowing")
        SeverActionsNativeExt2.Camp_ChallengeAllow()
        Return
    EndIf

    ; A challenge in flight wins over a new one, but first drop a slot the native
    ; watchdog already expired, or it would swallow every later challenge.
    If CurrentChallenger != None && !SeverActionsNativeExt2.Camp_ChallengeIsPending(CurrentChallenger)
        Actor expired = CurrentChallenger
        CurrentChallenger = None
        ; The watchdog tells Papyrus nothing, so the expired challenger may still be on the walk.
        CleanUpChallengeWalk(expired)
    EndIf
    If CurrentChallenger != None && CurrentChallenger != challenger
        Debug.Trace("[SeverActions] OnCampChallenge: a challenge is already in flight (" + CurrentChallenger + ") - dropping this one")
        Return
    EndIf

    CurrentChallenger = challenger
    Actor player = Game.GetPlayer()

    ; Already face to face - skip the walk entirely.
    Float startDist = challenger.GetDistance(player)
    If startDist <= ChallengeApproachDistance
        Debug.Trace("[SeverActions] OnCampChallenge: already within " + startDist + " - skipping the walk")
        HandleChallengeArrived(challenger)
        Return
    EndIf

    Package followPkg = ChallengeFollowPackage()
    Keyword followKW = ChallengeFollowKeyword()
    If followPkg == None || followKW == None
        ; No package: ask from where they stand rather than drop the encounter.
        Debug.Trace("[SeverActions] OnCampChallenge: no follow package available - asking from where they stand")
        HandleChallengeArrived(challenger)
        Return
    EndIf

    SeverActionsNative.LinkedRef_Set(challenger, player, followKW)
    ; 100 is Arrest.PackagePriority, which has no VMAD fill - the .psc default is the runtime value.
    ActorUtil.AddPackageOverride(challenger, followPkg, 100, 1)
    challenger.EvaluatePackage()

    SeverActionsNativeExt.Stuck_StartTracking(challenger)
    SeverActionsNativeExt.Arrival_Register(challenger, player, ChallengeApproachDistance, "camp_challenge_arrived")
    Debug.Trace("[SeverActions] OnCampChallenge: " + challenger.GetDisplayName() + " walking in from " + startDist)
EndEvent

Function HandleChallengeArrived(Actor akChallenger)
    {The challenger reached the player (or needed no walk): open the card or the
     parley.}

    Debug.Trace("[SeverActions] HandleChallengeArrived: " + akChallenger)
    If akChallenger == None || CurrentChallenger != akChallenger
        Debug.Trace("[SeverActions] HandleChallengeArrived: stale (slot holds " + CurrentChallenger + ") - ignoring")
        Return
    EndIf
    ; The world may have moved on during the walk; native is the authority.
    If !SeverActionsNativeExt2.Camp_ChallengeIsPending(akChallenger)
        Debug.Trace("[SeverActions] HandleChallengeArrived: native no longer has this challenge pending - dropping")
        CleanUpChallengeWalk(akChallenger)
        CurrentChallenger = None
        Return
    EndIf

    ; Stop the arrival machinery but KEEP the follow package and LinkedRef, or the
    ; challenger walks home mid-question; only the verdict paths strip them.
    SeverActionsNativeExt.Arrival_Cancel(akChallenger)
    SeverActionsNativeExt.Stuck_StopTracking(akChallenger)
    akChallenger.SetLookAt(Game.GetPlayer())
    akChallenger.DrawWeapon()

    ; Handoff complete: stands down the native watchdog, which would otherwise
    ; drop the challenge mid-parley and re-dispatch it.
    SeverActionsNativeExt2.Camp_ChallengeEngaged()

    ; Say it in the scene, not just the corner of the screen.
    SkyrimNetApi.DirectNarration("*" + akChallenger.GetDisplayName() + " plants themselves in " + Game.GetPlayer().GetDisplayName() + "'s path, weapon in hand - demanding to know their business here.*", akChallenger, Game.GetPlayer())

    String campName = SeverActionsNativeExt2.Camp_Name(akChallenger)
    Int timeoutMs = (ChallengeParleySeconds * 1000.0) as Int

    ; The verdict is decided in dialogue either way; the opt-in card only states
    ; the question. No notification: the narration above is the announcement.
    If !CampChallengeCardEnabled
        BeginChallengeParley(akChallenger)
    ElseIf !SeverActionsNativeExt2.Magelight_OpenChallengePrompt(akChallenger, campName, timeoutMs)
        ; Card unavailable (no Magelight, or another view has focus): same fallback.
        BeginChallengeParley(akChallenger)
    EndIf
EndFunction

Function BeginChallengeParley(Actor akChallenger)
    {Start the parley clock. Nothing is granted here: the challenger gives the
     verdict in dialogue (LetThemPass / RunThemOff); the clock makes a timeout or
     walking away count as a refusal.}

    If akChallenger == None
        Return
    EndIf
    ; The challenger's own window: an arrest plea or ambush keeps its own clock.
    SeverActionsNative.Native_Persuasion_Begin(akChallenger, Game.GetPlayer(), ChallengeParleySeconds, ChallengeParleyDistance)
    Debug.Trace("[SeverActions] BeginChallengeParley: clock started, " + ChallengeParleySeconds + "s")
EndFunction

Event OnCampChallengeChoice(String eventName, String strArg, Float numArg, Form sender)
    {The player's posture from the card. Not the verdict - see the header.}

    Actor challenger = sender as Actor
    If challenger == None || CurrentChallenger != challenger
        Return
    EndIf
    If !SeverActionsNativeExt2.Camp_ChallengeIsPending(challenger)
        CurrentChallenger = None
        CleanUpChallengeWalk(challenger)
        Return
    EndIf

    If strArg == "accept"
        BeginChallengeParley(challenger)
        ; CurrentChallenger stays set - the parley is still this encounter.

    ElseIf strArg == "denySilent"
        ; Answered with a drawn weapon.
        CurrentChallenger = None
        SeverActionsNativeExt2.Native_Persuasion_EndFor(challenger)
        SeverActionsNativeExt2.Camp_ChallengeRefuse("the player answered with a drawn weapon")
        CleanUpChallengeWalk(challenger)
        Game.GetPlayer().DrawWeapon()

    Else
        ; deny, a dismiss, or an expired card - all the same answer.
        CurrentChallenger = None
        SeverActionsNativeExt2.Native_Persuasion_EndFor(challenger)
        SeverActionsNativeExt2.Camp_ChallengeRefuse("the player pushed past without answering")
        CleanUpChallengeWalk(challenger)
        challenger.StartCombat(Game.GetPlayer())
    EndIf
EndEvent

; --- The verdict, given by the CHALLENGER in dialogue ---
; Both actions gate on the camp_challenge_pending decorator, so only the
; challenger is offered them.

Function LetThemPass_Execute(Actor akSpeaker)
    {The outlaw is satisfied. The truce holds for this visit.}
    If akSpeaker == None || !SeverActionsNativeExt2.Camp_ChallengeIsPending(akSpeaker)
        Return
    EndIf
    CurrentChallenger = None
    SeverActionsNativeExt2.Native_Persuasion_EndFor(akSpeaker)
    CleanUpChallengeWalk(akSpeaker)
    akSpeaker.SheatheWeapon()
    SeverActionsNativeExt2.Camp_ChallengeAllow()
EndFunction

Function RunThemOff_Execute(Actor akSpeaker)
    {The outlaw did not buy it. The camp turns, on both sides of the door.}
    If akSpeaker == None || !SeverActionsNativeExt2.Camp_ChallengeIsPending(akSpeaker)
        Return
    EndIf
    CurrentChallenger = None
    SeverActionsNativeExt2.Native_Persuasion_EndFor(akSpeaker)
    CleanUpChallengeWalk(akSpeaker)
    SeverActionsNativeExt2.Camp_ChallengeRefuse("the outlaw refused the player passage")
    ; The challenger leads the charge (see OnCampChallengeCleanup).
    akSpeaker.StartCombat(Game.GetPlayer())
EndFunction

Event OnCampChallengeCleanup(String eventName, String strArg, Float numArg, Form sender)
    {Native refused the challenge (parley timeout or the player walked off; routed
     natively, see RegisterEvents). The camp is already broken: tear down the walk,
     narrate it, and put the challenger into the fight.}
    Actor challenger = sender as Actor
    Debug.Trace("[SeverActions] OnCampChallengeCleanup: " + challenger + " (" + strArg + ")")
    If challenger == None
        Return
    EndIf
    If CurrentChallenger == challenger
        CurrentChallenger = None
    EndIf
    CleanUpChallengeWalk(challenger)
    If challenger.IsDead()
        Return
    EndIf

    ; Narrate before the swing: the player walked off, or the clock ran out.
    Actor player = Game.GetPlayer()
    If StringUtil.Find(strArg, "walked away") >= 0
        SkyrimNetApi.DirectNarration("*" + challenger.GetDisplayName() + " watches " + player.GetDisplayName() + " walk off mid-question. That answer suits the camp fine - blades come out.*", challenger, player)
    Else
        SkyrimNetApi.DirectNarration("*" + challenger.GetDisplayName() + "'s patience runs out. Silence is an answer too - and the whole camp draws the same conclusion.*", challenger, player)
    EndIf

    ; The native break restores ORIGINAL aggression, so a challenger passive by
    ; record (aggression 0) would sit the fight out; StartCombat is left to Papyrus.
    challenger.StartCombat(player)
EndEvent

Event OnCampHoardPlundered(String eventName, String strArg, Float numArg, Form sender)
    {The player emptied a camp's boss chest and native CampLoot turned the camp;
     record why in SkyrimNet so the outlaws know. strArg = camp name,
     numArg = members turned, sender = the chief when one stands.}
    String campName = strArg
    If campName == ""
        campName = "the camp"
    EndIf
    Actor chief = sender as Actor
    String playerName = Game.GetPlayer().GetDisplayName()
    SkyrimNetApi.RegisterPersistentEvent(playerName + " plundered the war chest of " + campName + " under truce - the crew watched their hoard walk out the door, and the whole camp has turned on " + playerName + " for it.", chief, Game.GetPlayer())
    Debug.Trace("[SeverActions] OnCampHoardPlundered: " + campName + " (" + (numArg as Int) + " turned)")
EndEvent

; === M-V VERB DISPATCHER (plan 3.0 M-V, DR10) ===
; Verbs this module dispatches (Native/data/verb_table.json) arrive as
; SeverActions_Verb_Combat with the 8 pipe fields. This is the ONE script that
; defines OnVerb_Combat (F4); RegisterEvents registers it.
Event OnVerb_Combat(String eventName, String strArg, Float numArg, Form sender)
    String actionId = SeverActions_ModuleBase.VerbField(strArg, 0)
    String targetName = SeverActions_ModuleBase.VerbField(strArg, 1)
    String target2Name = SeverActions_ModuleBase.VerbField(strArg, 2)
    String strParam = SeverActions_ModuleBase.VerbField(strArg, 3)
    Int intParam = SeverActions_ModuleBase.VerbField(strArg, 4) as Int
    String str2Param = SeverActions_ModuleBase.VerbField(strArg, 5)
    Int targetFid = SeverActions_ModuleBase.VerbField(strArg, 6) as Int
    Int target2Fid = SeverActions_ModuleBase.VerbField(strArg, 7) as Int
    Debug.Trace("[SeverActions_Combat] OnVerb_Combat: " + actionId + " target=" + targetName + " target2=" + target2Name \
        + " str=" + strParam + " int=" + intParam + " str2=" + str2Param + " fid=" + targetFid + " fid2=" + target2Fid)

    ; Sender, then the encoded FormID, then the fuzzy name; names are then
    ; re-canonicalized to display names.
    Actor target = SeverActions_ModuleBase.VerbActor(sender, targetFid, targetName)
    If !target
        Debug.Trace("[SeverActions_Combat] OnVerb_Combat: could not resolve target '" + targetName + "' for " + actionId)
        Return
    EndIf
    targetName = target.GetDisplayName()
    Actor target2 = SeverActions_ModuleBase.VerbActor(None, target2Fid, target2Name)
    If target2
        target2Name = target2.GetDisplayName()
    ElseIf target2Name != ""
        Debug.Trace("[SeverActions_Combat] OnVerb_Combat: target2 name '" + target2Name + "' did not resolve to an actor (action=" + actionId + ")")
    EndIf

    ; -- Combat (own code) --
    If actionId == "ceaseFire"
        CeaseFire_Execute(target, None)

    ElseIf actionId == "attackTarget"
        If target2
            _AttackTarget(target, target2, False)
        EndIf

    ElseIf actionId == "yield"
        Yield_Execute(target)

    ; -- Brawl (sibling script; mirrors the YAML entry points 1:1).
    ;    target = the acting participant, target2 = the other one.
    ElseIf actionId == "challengeBrawl"
        SeverActions_Brawl brawlChallenge = (Self as Quest) as SeverActions_Brawl
        If brawlChallenge && target2
            brawlChallenge.ChallengeBrawl_Execute(target, target2)
        EndIf

    ElseIf actionId == "acceptBrawl"
        ; target2 may be None: AcceptBrawl_Execute finds the pending challenge natively.
        SeverActions_Brawl brawlAccept = (Self as Quest) as SeverActions_Brawl
        If brawlAccept
            brawlAccept.AcceptBrawl_Execute(target, target2)
        EndIf

    ElseIf actionId == "declineBrawl"
        SeverActions_Brawl brawlDecline = (Self as Quest) as SeverActions_Brawl
        If brawlDecline
            brawlDecline.DeclineBrawl_Execute(target, target2)
        EndIf

    ElseIf actionId == "forfeitBrawl"
        SeverActions_Brawl brawlForfeit = (Self as Quest) as SeverActions_Brawl
        If brawlForfeit
            brawlForfeit.ForfeitBrawl_Execute(target)
        EndIf

    Else
        Debug.Trace("[SeverActions_Combat] OnVerb_Combat: unknown actionId '" + actionId + "' (not a row this dispatcher carries)")
    EndIf

    ; Refresh after the forwarded call returns: the DLL's own refresh fires one
    ; frame after routing, before this Papyrus work lands.
    SeverActionsNative.Magelight_RefreshPage("world")
    SeverActionsNative.Magelight_RefreshPage("enterprises")
EndEvent

; === M-K HOTKEY DISPATCHER (plan 3.0 M-K, DR10) ===
; SeverActions_Hotkey_Combat from the DLL's input sink: strArg = hotkey id,
; sender = the target resolved by targetMode, or None. The sink already applied
; the global gates (menus, dialogue, dead, sitting); branches keep the per-key rules.
Event OnHotkey_Combat(String eventName, String strArg, Float numArg, Form sender)
    ; "wheel:<id>" = the quick wheel's pick of the same hotkey (fromWheel is unused here).
    String hotkeyId = strArg
    Bool fromWheel = false
    If StringUtil.Substring(strArg, 0, 6) == "wheel:"
        fromWheel = true
        hotkeyId = StringUtil.Substring(strArg, 6)
    EndIf
    Actor target = sender as Actor
    Actor player = Game.GetPlayer()
    Debug.Trace("[SeverActions_Combat] OnHotkey_Combat: " + hotkeyId + " target=" + target)

    If hotkeyId == "Yield"
        If !target
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.noValidTarget"))
        ElseIf target == player
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.cannotTargetYourself"))
        ElseIf Yield_IsEligible(target)
            Yield_Execute(target)
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.hasSurrendered", ("" + target.GetDisplayName())))
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.isNotInCombat", ("" + target.GetDisplayName())))
        EndIf

    Else
        Debug.Trace("[SeverActions_Combat] OnHotkey_Combat: unknown hotkeyId '" + hotkeyId + "' (not a row this dispatcher carries)")
    EndIf
EndEvent
