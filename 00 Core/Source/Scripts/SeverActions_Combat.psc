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
; =============================================================================
; TRUCE SETTINGS (Phase 2)
; =============================================================================
Bool Property TruceEnabled = False Auto
{Master toggle for the Truce layer: bandits (and any opted-in factions) do not
attack on sight, and turn hostile only when provoked. Ships OFF - it is
game-changing (non-hostile bandits), so players opt in knowingly via Settings.
Existing saves keep whatever value they hold and are never re-migrated. Turning
it off restores every pacified actor immediately and STICKS.}

Bool Property TruceLeaders = True Auto
{Include named camp leaders / bosses in the truce. ON by default - being able
to negotiate with the chief is the point. Quest-critical, essential, frenzied
and quest-faction NPCs are still excluded regardless of this.}

Bool Property TruceQuestNPCs = True Auto
{Include outlaws a RUNNING quest is using. ON by default - camp chiefs are often
radiant quest targets, and excluding them meant the chief charged while his camp
stood calm. Attacking still breaks the truce for the whole camp, so kill/clear
objectives behave as vanilla. Turn OFF if a quest needing an NPC to strike first
ever stalls.}

Bool Property TruceDungeons = False Auto
{Include outlaws HOLDING a dungeon - a barrow, a crypt, a Dwemer ruin - as
opposed to living in a camp. OFF by default (user call, 2026-08-12, after
Bleak Falls Barrow stood down inside and out): a place you delve should still
be a fight, while camps, forts and the open road stay negotiable.

The cost of OFF, stated plainly: those bandits go back to shoot-on-sight, so
SkyrimNet dialogue with them is unreachable again - which is the whole reason
the truce exists. Turn it ON to be able to talk to anyone, anywhere.

A CAMP IS NOT A DUNGEON here even though the game tags most camps as both:
Silent Moons and Halted Stream carry LocTypeDungeon alongside LocTypeBanditCamp,
exactly as Bleak Falls does, so the lair keyword is what separates them and it
is always checked first. Sworn camps can never be broken by this setting.}

Bool Property TruceNecromancers = True Auto
{Include NecromancerFaction in the Truce scope. Note their raised thralls are a
separate faction and still fight - summon inheritance is not built yet.}

Bool Property TruceForsworn = True Auto
{Include ForswornFaction. Quest-scoped Forsworn (the Markarth chain's MS01/MS02
factions) are excluded automatically by the eligibility gates.}

Bool Property TruceVampires = True Auto
{Include VampireFaction - but ONLY while the player is a vampire themselves.
Set it when you are not one and nothing happens.}

Float Property TruceRadius = 8000.0 Auto
{How far from the player the Truce sweep reaches, in units. 512-12000.
Must comfortably exceed the range at which bandits NOTICE you and start
closing - at 4000 a fort garrison was pacified one bandit at a time as you
walked in, and the ones not yet reached charged first.}

; ---------------------------------------------------------------------------
; CAMP CHALLENGE - "what's your business in here?"
; ---------------------------------------------------------------------------
; Native CampChallenge decides WHEN a challenge is owed and WHO issues it;
; this script owns the walk over, the card, and the parley clock.

Bool Property CampChallengeEnabled = True Auto
{Master switch for the camp challenge encounter. Native-side gate lives in
 CampChallenge::SetEnabled - re-pushed on every init/load like the truce ones.}

Float Property ChallengeApproachDistance = 220.0 Auto
{How close the challenger walks before speaking. Wider than the arrest's
 approach: they are asking a question, not making an arrest.}

Bool Property CampChallengeCardEnabled = False Auto
{Show the PrismaUI card when the challenger arrives. OFF by default: the
 intended feel is an outlaw walking up and asking, answered in dialogue like
 anyone else. The card is the clarity option for players who want the choice
 spelled out, not the default experience.}

Float Property ChallengeParleySeconds = 120.0 Auto
{How long the player has to talk once the parley opens. Running out is a
 refusal - a question asked to your face does not expire politely. Two minutes
 is enough for a real conversation without letting the standoff become
 furniture.}

Float Property ChallengeParleyDistance = 1400.0 Auto
{Walk further than this from the challenger mid-parley and it counts as
 walking away. Generous enough to back up and talk, not to leave the room.}

; The challenge in flight, if any. Papyrus-side mirror of the native pending
; slot - kept so the arrival/choice handlers can reject a stale event without
; a native round-trip.
Actor CurrentChallenger = None

Bool Property CampTakeoverEnabled = True Auto
{Allow outlaw camps to be taken over - the chief agreeing, or the survivors
throwing in after you kill them. Turning this off leaves the Truce standoff
intact but removes the takeover actions entirely.}

Bool Property CampFreezeRespawn = True Auto
{When a camp swears to you, freeze its encounter zone so it stops repopulating
with fresh hostiles. On by default - without it a camp you took refills within
a couple of in-game weeks and the takeover reads as broken.}

; TRUCE PROBE (Phase 1) - read-only verification surface
; =============================================================================
; A MEMBER function on purpose: the underlying natives are Globals on
; SeverActionsNativeExt, which isn't attached to the quest, so nothing could
; call them in-game. SkyrimNet's execute_quest_function dispatches to quest
; script MEMBERS, so this wrapper is what makes the gate library testable
; without a hotkey, a button, or a console command.
;
; Mutates NOTHING. Reports which nearby NPCs the Truce layer would pacify and,
; for each one it wouldn't, which of the five gates refused them. Full detail
; goes to the Papyrus/SKSE log; the summary comes back as the return value and
; on screen.
String Function TruceProbe(Float afRadius = 3000.0, Bool abNecromancers = false, Bool abForsworn = false, Bool abVampires = false)
    String result = SeverActionsNativeExt.Native_Truce_ExplainNearby(afRadius, abNecromancers, abForsworn, abVampires)
    Debug.Notification("Truce probe: " + result)
    Debug.Trace("[SeverActions_Combat] Truce probe: " + result)
    Return result
EndFunction

String Function CampProbe()
    {Read-only: list every camp discovered so far with its leader and state.}
    String result = SeverActionsNativeExt.Native_Camp_Probe()
    Debug.Notification("Camps: " + result)
    Return result
EndFunction

String Function CampFreezeHere()
    {Freeze respawn for the camp you are standing in - the Phase 1 claim that
     has to be proven before takeover is built on it.}
    String result = SeverActionsNativeExt.Native_Camp_FreezeHere()
    Debug.Notification(result)
    Return result
EndFunction

String Function CampSwearHere(Bool abViaLeader = true)
    {Phase 2 test hook: make the camp you are standing in swear to you. Picks
     any living member as the speaker for the leaderless route; for the leader
     route it uses the camp's actual leader, so the native's own guard is
     exercised rather than bypassed.}
    Actor speaker = None
    If abViaLeader
        speaker = SeverActionsNativeExt2.Camp_LeaderAtPlayer()
    Else
        speaker = SeverActionsNativeExt2.Camp_AnyMemberAtPlayer()
    EndIf
    If !speaker
        Debug.Notification("No camp member found here")
        Return "no camp member here"
    EndIf
    Bool ok = SeverActionsNativeExt2.Camp_Swear(speaker, abViaLeader)
    If ok
        Debug.Notification("The camp has sworn to you")
        Return "sworn"
    EndIf
    Debug.Notification("Camp refused to swear - see log")
    Return "refused"
EndFunction

String Function CampThawHere()
    {Undo CampFreezeHere for the camp you are standing in.}
    String result = SeverActionsNativeExt.Native_Camp_ThawHere()
    Debug.Notification(result)
    Return result
EndFunction

; Single-target flavour - whoever is under the crosshair. Handy for checking
; one specific NPC (a named boss, a quest forsworn) rather than a whole camp.
String Function TruceProbeTarget(Bool abNecromancers = false, Bool abForsworn = false, Bool abVampires = false)
    String result = SeverActionsNativeExt.Native_Truce_ExplainTarget(abNecromancers, abForsworn, abVampires)
    Debug.Notification(result)
    Debug.Trace("[SeverActions_Combat] Truce probe (crosshair): " + result)
    Return result
EndFunction


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
; SeverCombat_CooldownEnd - Float (superseded by the native CombatCooldownStore; no longer written)
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
    RegisterForModEvent("SeverActions_CampChallenge", "OnCampChallenge")
    RegisterForModEvent("SeverActions_CampChallengeChoice", "OnCampChallengeChoice")
    ; NOT registered for SeverActions_PersuasionFailed — deliberate, do not re-add.
    ; SKSE keys ModEvent registrations per (form, event), and every Quest-extending
    ; SeverActions script shares quest 0x000D62. SeverActions_ArrestPlayer and
    ; SeverActions_Travel both register that event under the SAME callback name
    ; (OnPersuasionFailedEvent) so name-dispatch reaches both handlers; registering
    ; it here under a DIFFERENT name could only ever take the slot from them.
    ; The camp-challenge refusal is routed natively instead — PersuasionMonitor
    ; calls CampChallenge_OnPersuasionFailed directly, which fires
    ; SeverActions_CampChallengeCleanup (registered below under its own name).
    RegisterForModEvent("SeverActions_CampChallengeCleanup", "OnCampChallengeCleanup")
    RegisterForModEvent("SeverActions_CampHoardPlundered", "OnCampHoardPlundered")

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
    Else
        ; AUDIT (Phase 1 of the Truce work): this property is DECLARED here but
        ; never bound in the ESP - the quest's VMAD carries 17 properties for
        ; this script and SeverHostileFactions is not among them. So the
        ; ceasefire/yield hostile-faction stripping has never actually run; both
        ; systems rely on the aggression zero and the surrendered-faction add.
        ; Logged rather than silently skipped so it stops being invisible.
        Debug.Trace("[SeverActions_Combat] SeverHostileFactions is unbound - ceasefire/yield will not strip hostile factions")
    EndIf
    PushTruceConfigToNative()
EndFunction

Function PushTruceConfigToNative()
    {Boot-sync the Truce layer. C++ defaults to OFF with bandits-only scope;
     push the player's saved choices so a reload doesn't silently re-arm or
     disarm the feature. Order matters: scope and radius first, so the very
     first sweep after SetEnabled already uses the right settings.}
    ; One-shot: raise the old 4000 default to 8000. Auto properties persist in
    ; the save, so changing the default in this script does NOTHING for anyone
    ; already playing - and 4000 is the value that let a fort garrison charge
    ; before the sweep reached them. Only the exact old default is moved, so a
    ; radius the player chose themselves is left alone.
    ; One-shot: necromancers, Forsworn and vampires now default ON. Auto
    ; properties persist in the save, so a changed default reaches nobody who
    ; is already playing without this. Vampires stays gated on the player being
    ; one themselves, so turning it on cannot surprise a non-vampire.
    ;
    ; NOTE: this DOES overwrite a deliberate off for anyone who had turned them
    ; off before the change - a bool cannot distinguish untouched from chosen.
    ; It runs exactly once; re-disable in Settings and it will stick.
    If StorageUtil.GetIntValue(None, "SeverActions_TruceScopeMigDone", 0) < 1
        StorageUtil.SetIntValue(None, "SeverActions_TruceScopeMigDone", 1)
        TruceNecromancers = True
        TruceForsworn     = True
        TruceVampires     = True
        Debug.Trace("[SeverActions] Truce scope migrated - nec/forsworn/vampires default ON")
    EndIf
    If StorageUtil.GetIntValue(None, "SeverActions_TruceRadiusMigDone", 0) < 1
        StorageUtil.SetIntValue(None, "SeverActions_TruceRadiusMigDone", 1)
        If TruceRadius > 3999.0 && TruceRadius < 4001.0
            TruceRadius = 8000.0
            Debug.Trace("[SeverActions] Truce radius migrated 4000 -> 8000")
        EndIf
    EndIf
    ; One-shot: camp cut retune (dev149, user call) - Partnership 40 -> 20,
    ; Vassalage 60 -> 40. The native only touches ventures still at the exact
    ; old defaults; renegotiated deals stay. Required because kCampFairCutPct
    ; moved with the defaults - without this an existing AGREED camp at the
    ; old 40 would suddenly read as coerced and grind unhappy.
    If StorageUtil.GetIntValue(None, "SeverActions_CampCutMigDone", 0) < 1
        StorageUtil.SetIntValue(None, "SeverActions_CampCutMigDone", 1)
        Int cutsMoved = SeverActionsNativeExt2.Venture_MigrateCampCuts()
        If cutsMoved > 0
            Debug.Trace("[SeverActions] Camp cuts migrated to 20/40 for " + cutsMoved + " venture(s)")
        EndIf
    EndIf
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
    ; Defense-in-depth: an actor whose fight just resolved via Yield or
    ; CeaseFire must NOT be FullCleanup'd here — that would re-add their
    ; hostile factions and wipe WasSurrendered moments after the surrender
    ; ("bandit yields, then stands back up hostile"). Yield/CeaseFire now
    ; clear the native inForcedCombat flag BEFORE stopping combat so this
    ; event normally never fires for them; this guard covers older saves
    ; and racy interleavings where the combat-end beat the flag clear.
    If StorageUtil.GetIntValue(a, "SeverCombat_WasSurrendered", 0) == 1 || SeverActionsNative.IsYieldMonitored(a) || SeverActionsNative.Ceasefire_IsMonitored(a)
        Debug.Trace("[SeverCombat] ForcedCombatEnded for " + a.GetDisplayName() + " - skipped (yield/ceasefire owns this actor's state)")
        Return
    EndIf
    Debug.Trace("[SeverCombat] ForcedCombatEnded for " + a.GetDisplayName() + " - running FullCleanup")
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

    ; ── Camp oath auto-break ─────────────────────────────────────────
    ; The chief ordering an attack on the player (or the player's
    ; follower) IS renouncing the oath — the LLM sometimes reaches for
    ; AttackTarget instead of RenounceCampOath, and the intent is
    ; unambiguous either way. Route through the same cascade as the
    ; explicit action (ventures disband, camp released, group truce
    ; break) so the whole crew turns hostile together instead of the
    ; chief fighting alone beside pacified kin. Camp_Renounce natively
    ; refuses non-leaders; the sworn-state gate (2 = sworn) keeps wild
    ; camps on the normal truce rules — their hostility is
    ; TruceMonitor's business, not an oath's.
    If akTarget == Game.GetPlayer() || akTarget.IsPlayerTeammate()
        If SeverActionsNativeExt2.Camp_State(akAttacker) == 2 && SeverActionsNativeExt2.Camp_IsLeader(akAttacker)
            If SeverActionsNativeExt2.Camp_Renounce(akAttacker)
                Debug.Trace("[SeverCombat] AttackTarget: sworn chief " + akAttacker.GetDisplayName() + " turned on the player - oath renounced, camp hostile")
                Debug.Notification(akAttacker.GetDisplayName() + "'s camp has turned on you!")
                SkyrimNetApi.RegisterEvent("camp_oath_broken", akAttacker.GetDisplayName() + " turned on " + akTarget.GetDisplayName() + " - the camp's oath to the player is broken and the whole crew turns hostile", akAttacker, akTarget)
            EndIf
        EndIf
    EndIf

    ; ── Camp challenge answered with steel ───────────────────────────
    ; Same shape as the oath block above: the LLM sometimes reaches for
    ; AttackTarget instead of RunThemOff during a live challenge, and the
    ; intent is unambiguous - attacking the person you are questioning IS
    ; the verdict. Native NoteAttack refuses the challenge (breaking the
    ; WHOLE camp by roster, both sides of the door) when the attacker is
    ; the pending challenger or any member of the questioned camp; the
    ; attack itself then proceeds normally. Field case 2026-08-03: the
    ; challenger attacked, the player killed him, walked outside past a
    ; camp that never found out.
    If akTarget == Game.GetPlayer() || akTarget.IsPlayerTeammate()
        If SeverActionsNativeExt2.Camp_ChallengeNoteAttack(akAttacker)
            Debug.Trace("[SeverCombat] AttackTarget: during a live challenge - verdict is refusal, camp broken")
            Debug.Notification(akAttacker.GetDisplayName() + "'s camp turns on you!")
            If CurrentChallenger == akAttacker
                CurrentChallenger = None
            EndIf
            SeverActionsNative.Native_Persuasion_End()
            CleanUpChallengeWalk(akAttacker)
        EndIf
    EndIf

    ; If either actor is currently surrendered or ceasefire'd, fully reset
    ; them first. Without this, we'd add them to the attack/target faction
    ; while they're still in SeverSurrenderedFaction and tracked by the yield
    ; or ceasefire monitor — the next incidental hit would fire YieldBroken/
    ; CeasefireBroken mid-scripted-combat and leave dual-faction state.
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

    ; Store original values for attacker (confidence only)
    StoreOriginalValues(akAttacker)

    ; Store original relationship ranks (both directions) — but never
    ; overwrite mid-fight: a repeat AttackTarget on an actor already in
    ; forced combat would snapshot the forced -4 as "original" and the
    ; eventual restore would bake the hostility in permanently.
    If StorageUtil.GetIntValue(akAttacker, "SeverCombat_InForcedCombat", 0) == 0
        StorageUtil.SetIntValue(akAttacker, "SeverCombat_OriginalRelationship", akAttacker.GetRelationshipRank(akTarget))
    EndIf
    If StorageUtil.GetIntValue(akTarget, "SeverCombat_InForcedCombat", 0) == 0
        StorageUtil.SetIntValue(akTarget, "SeverCombat_OriginalRelationship", akTarget.GetRelationshipRank(akAttacker))
    EndIf

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
    ; Factions are deliberately NOT manipulated here — doing so made other
    ; actors (especially followers) go hostile to unintended targets.
    ; StartCombat() + relationship rank is enough to force combat between
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

    ; Clear the forced-combat flag BEFORE the native combat stop below —
    ; PropagateGroup stops combat, and if ForcedCombatMonitor sees the
    ; combat-end with the flag still set it fires ForcedCombatEnded →
    ; FullCleanup force-breaks the ceasefire we're in the middle of
    ; negotiating.
    SeverActionsNative.Native_SetInForcedCombat(akActor1, false)
    StorageUtil.UnsetIntValue(akActor1, "SeverCombat_InForcedCombat")
    If akStoredTarget
        SeverActionsNative.Native_SetInForcedCombat(akStoredTarget, false)
        StorageUtil.UnsetIntValue(akStoredTarget, "SeverCombat_InForcedCombat")
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

    ; If this fight was started by AttackTarget, undo its per-actor edits the
    ; same way Yield does: restore Confidence + drop the AIO Attack/Target
    ; factions (RestoreOriginalValues), restore the forced -4 relationship
    ; ranks from the stored originals, and clear the combat-pair keys so
    ; they don't linger through the truce. Previously none of this ran on
    ; the ceasefire path — Confidence=3 and the faction memberships stuck,
    ; and the pair stayed archenemies under the truce.
    RestoreOriginalValues(akActor1)
    If akStoredTarget
        RestoreOriginalValues(akStoredTarget)
        Int origRank1 = StorageUtil.GetIntValue(akActor1, "SeverCombat_OriginalRelationship", 0)
        Int origRank2 = StorageUtil.GetIntValue(akStoredTarget, "SeverCombat_OriginalRelationship", 0)
        akActor1.SetRelationshipRank(akStoredTarget, origRank1)
        akStoredTarget.SetRelationshipRank(akActor1, origRank2)
        ClearAllCombatState(akStoredTarget)
    EndIf
    ClearAllCombatState(akActor1)

    ; Apply cooldown (prevents immediate re-attack action)
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

    ; Resolve the partner and clear the forced-combat flag BEFORE StopCombat:
    ; the combat-end event otherwise reaches ForcedCombatMonitor with the
    ; flag still set, and its ForcedCombatEnded → FullCleanup re-hostiles
    ; the freshly-surrendered actor ("bandit yields, then stands back up").
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

    ; StorageUtil mirror of original aggression — kept so YieldAlias.psc's
    ; OnLoad re-register path keeps working.
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

    ; YieldSlot persistence — Papyrus-side.
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

    ; Release yield persistence alias — no longer surrendered.
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

    ; Restore the relationship ranks AttackTarget forced to -4. This was the
    ; one terminal path that unset the stored original WITHOUT restoring it —
    ; any forced fight ending by flee/calm/separation left the pair as
    ; permanent archenemies (only the yield path restored). Idempotent for
    ; the double-cleanup case (both actors get ForcedCombatEnded): each call
    ; restores its own direction, restores the partner's direction while the
    ; partner's key still exists, and only unsets its own keys below.
    Actor rankPartner = StorageUtil.GetFormValue(akActor, "SeverCombat_CombatTarget") as Actor
    If rankPartner && StorageUtil.HasIntValue(akActor, "SeverCombat_OriginalRelationship")
        akActor.SetRelationshipRank(rankPartner, StorageUtil.GetIntValue(akActor, "SeverCombat_OriginalRelationship", 0))
        If StorageUtil.HasIntValue(rankPartner, "SeverCombat_OriginalRelationship")
            rankPartner.SetRelationshipRank(akActor, StorageUtil.GetIntValue(rankPartner, "SeverCombat_OriginalRelationship", 0))
        EndIf
        Debug.Trace("[SeverCombat] Restored relationship ranks between " + akActor.GetDisplayName() + " and " + rankPartner.GetDisplayName())
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
    ; YieldBroken is a prompt-flavor flag ("attacked after surrendering")
    ; that nothing ever cleared — it stuck on the actor forever. A full
    ; wipe is the natural place to retire it.
    StorageUtil.UnsetIntValue(akActor, "SeverCombat_YieldBroken")
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

Function OnGameLoaded()
    {Load-time recovery. Called by SeverActions_Init.RunLoadRecovery() on
     every load — this is a Quest script, and Quest scripts NEVER receive
     OnPlayerLoadGame (Actor/alias-only event), so hanging this body off
     that event left it dead code for every existing save.}
    ; Re-register for native mod events
    RegisterForModEvent("SeverActionsNative_YieldBroken", "OnYieldBroken")
    RegisterForModEvent("SeverActionsNative_CeasefireBroken", "OnCeasefireBroken")
    RegisterForModEvent("SeverActions_ForcedCombatEnded", "OnForcedCombatEnded")
    RegisterForModEvent("SeverActions_CampChallenge", "OnCampChallenge")
    RegisterForModEvent("SeverActions_CampChallengeChoice", "OnCampChallengeChoice")
    ; NOT registered for SeverActions_PersuasionFailed — deliberate, do not re-add.
    ; See the OnInit note above for the (form, event) slot-sharing reason; the
    ; camp-challenge refusal is routed natively via PersuasionMonitor instead.
    RegisterForModEvent("SeverActions_CampChallengeCleanup", "OnCampChallengeCleanup")
    RegisterForModEvent("SeverActions_CampHoardPlundered", "OnCampHoardPlundered")
    ; A challenge cannot survive a reload: the walk, the card and the parley
    ; clock are all session state. A stale slot here would silently DROP every
    ; future challenge (-a challenge is already in flight-), so clear it.
    CurrentChallenger = None

    ; Re-assign yield persistence aliases (ForceRefTo doesn't survive save/load)
    ReassignYieldSlots()
    ; Ceasefire'd actors are restored from the C++ cosave ('CEAS' record in
    ; CeasefireMonitor); no Papyrus-side re-registration is needed.
    ; Re-push the faction config in case the cosave was clobbered or the
    ; load order shifted.
    PushCeasefireConfigToNative()
EndFunction

Event OnCeasefireBroken(String eventName, String strArg, Float numArg, Form sender)
    {Native CeasefireMonitor detected a player hit on a ceasefire'd actor and
     already did the heavy lifting in C++: restored Aggression, removed from
     SeverSurrenderedFaction, re-added the hostile factions, called
     EvaluatePackage. (Relationship ranks are NOT touched in C++ — CLib NG
     doesn't expose them; the pair's mutual ranks were already restored on
     the Papyrus side when the ceasefire was negotiated in CeaseFire_Execute,
     so a broken truce turns them on the player, not back on each other.)

     This handler exists only to clean up the Papyrus-side StorageUtil keys
     the prompt template reads, and to clear any legacy keys from saves
     made before the Phase 5 migration.}
    Actor akActor = sender as Actor
    If !akActor
        Return
    EndIf

    Debug.Trace("[SeverCombat] CeasefireBroken: " + akActor.GetDisplayName() + " - clearing prompt-side state")

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

                ; YieldMonitor is cosave-backed ('YELD' record) — it already
                ; restored this actor with the correct original aggression.
                ; Only re-register when the native side genuinely lost them
                ; (pre-cosave save), or the StorageUtil 1.0 default would
                ; stomp the cosaved original.
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

; ============================================================================
; CAMP CHALLENGE
; ============================================================================
; Flow, end to end:
;   native CampChallenge   -> SeverActions_CampChallenge  (challenger picked)
;   OnCampChallenge        -> walk them to the player     (follow pkg + Arrival)
;   HandleChallengeArrived -> the card                    (PrismaUI prompt)
;   OnCampChallengeChoice  -> posture                     (parley / refuse)
;   parley                 -> the OUTLAW decides in dialogue via the
;                             LetThemPass / RunThemOff actions
;
; Fail-open is the rule throughout. Every path that cannot complete the
; encounter (no challenger, no UI, a walk that never finishes) ALLOWS rather
; than refuses: a plumbing failure must never start a fight the player had no
; chance to avoid. Only a real answer - or a real refusal to give one - turns
; the camp.

Function CleanUpChallengeWalk(Actor akChallenger)
    {Drop everything the approach put on them. Safe to call twice.}
    If akChallenger == None
        Return
    EndIf
    SeverActionsNativeExt.Arrival_Cancel(akChallenger)
    SeverActionsNativeExt.Stuck_StopTracking(akChallenger)
    SeverActions_Arrest arrestRef = (Self as Quest) as SeverActions_Arrest
    If arrestRef && arrestRef.SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(akChallenger, arrestRef.SeverActions_GuardFollowPlayer)
        akChallenger.EvaluatePackage()
    EndIf
EndFunction

Event OnCampChallenge(String eventName, String strArg, Float numArg, Form sender)
    {Native picked a challenger. Walk them over to the player.

     The walk reuses the arrest's follow-player package (Target = LinkedRef
     with FollowTargetKW), borrowed off the Arrest script - same quest, so the
     property is right there and there is no second package to keep in sync.}

    Actor challenger = sender as Actor
    Debug.Trace("[SeverActions] OnCampChallenge fired, challenger=" + challenger)
    If challenger == None
        Debug.Trace("[SeverActions] OnCampChallenge: sender did not resolve to an Actor - allowing")
        SeverActionsNativeExt2.Camp_ChallengeAllow()
        Return
    EndIf

    ; A challenge already in flight wins; this one is dropped rather than
    ; stacking two walkers on one player.
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

    SeverActions_Arrest arrestRef = (Self as Quest) as SeverActions_Arrest
    If arrestRef == None || arrestRef.SeverActions_GuardFollowPlayer == None
        ; No package to walk them with - ask from where they stand rather
        ; than dropping the encounter.
        Debug.Trace("[SeverActions] OnCampChallenge: no follow package available - asking from where they stand")
        HandleChallengeArrived(challenger)
        Return
    EndIf

    SeverActionsNative.LinkedRef_Set(challenger, player, arrestRef.SeverActions_FollowTargetKW)
    ActorUtil.AddPackageOverride(challenger, arrestRef.SeverActions_GuardFollowPlayer, arrestRef.PackagePriority, 1)
    challenger.EvaluatePackage()

    SeverActionsNativeExt.Stuck_StartTracking(challenger)
    SeverActionsNativeExt.Arrival_Register(challenger, player, ChallengeApproachDistance, "camp_challenge_arrived")
    Debug.Trace("[SeverActions] OnCampChallenge: " + challenger.GetDisplayName() + " walking in from " + startDist)
EndEvent

Function HandleChallengeArrived(Actor akChallenger)
    {The challenger reached the player. Put the card up.

     Routed here from SeverActions_Arrest's OnArrival - that script owns the
     quest's one OnArrival callback and forwards by tag.}

    Debug.Trace("[SeverActions] HandleChallengeArrived: " + akChallenger)
    If akChallenger == None || CurrentChallenger != akChallenger
        Debug.Trace("[SeverActions] HandleChallengeArrived: stale (slot holds " + CurrentChallenger + ") - ignoring")
        Return
    EndIf
    ; The world may have moved on during the walk (killed, camp broken by
    ; something else, player left). Native is the authority.
    If !SeverActionsNativeExt2.Camp_ChallengeIsPending(akChallenger)
        Debug.Trace("[SeverActions] HandleChallengeArrived: native no longer has this challenge pending - dropping")
        CleanUpChallengeWalk(akChallenger)
        CurrentChallenger = None
        Return
    EndIf

    ; Stop the ARRIVAL machinery but KEEP the follow package and LinkedRef.
    ; The first live test removed everything here, and the challenger sandbox-
    ; walked straight home mid-question - the split-second-run-then-leave
    ; report. Like the arrest plea, the follow holds through the parley (they
    ; track the player, weapon out) and is stripped only by the verdict paths.
    SeverActionsNativeExt.Arrival_Cancel(akChallenger)
    SeverActionsNativeExt.Stuck_StopTracking(akChallenger)
    akChallenger.SetLookAt(Game.GetPlayer())
    akChallenger.DrawWeapon()

    ; Tell native the handoff COMPLETED - the watchdog stands down. Without
    ; this it declared the challenge dropped 45s into the 120s parley and
    ; re-dispatched the same bandit every 48 seconds.
    SeverActionsNativeExt2.Camp_ChallengeEngaged()

    ; Say it in the scene, not just the corner of the screen.
    SkyrimNetApi.DirectNarration("*" + akChallenger.GetDisplayName() + " plants themselves in " + Game.GetPlayer().GetDisplayName() + "'s path, weapon in hand - demanding to know their business here.*", akChallenger, Game.GetPlayer())

    String campName = SeverActionsNativeExt2.Camp_Name(akChallenger)
    Int timeoutMs = (ChallengeParleySeconds * 1000.0) as Int

    ; The card is opt-in. With it off the outlaw simply stands there having
    ; asked, and the player answers in dialogue - which is where the verdict
    ; is decided either way. The card only ever states the question; it never
    ; decides anything the parley would not.
    ; No corner-of-screen notification on either path - the direct narration
    ; above IS the announcement, and the outlaw standing on the player with
    ; steel out says the rest (user call, 2026-08-03).
    If !CampChallengeCardEnabled
        BeginChallengeParley(akChallenger)
    ElseIf !SeverActionsNativeExt2.PrismaUI_OpenChallengePrompt(akChallenger, campName, timeoutMs)
        ; Card wanted but unavailable (PrismaUI missing, or another view holds
        ; focus). Same fallback - never swallow the challenge.
        BeginChallengeParley(akChallenger)
    EndIf
EndFunction

Function BeginChallengeParley(Actor akChallenger)
    {The player chose to answer. Start the clock and let the outlaw decide.

     Nothing is granted here - the verdict comes from the challenger, in
     dialogue, through LetThemPass / RunThemOff. The clock only exists so
     that walking away mid-question counts as the refusal it obviously is.}

    If akChallenger == None
        Return
    EndIf
    ; The persuasion monitor is a singleton shared with the arrest plea. If
    ; one is already running we simply skip the clock: a live parley without
    ; a timer is far better than stomping an arrest in progress.
    If !SeverActionsNative.Native_Persuasion_IsActive()
        SeverActionsNative.Native_Persuasion_Begin(akChallenger, Game.GetPlayer(), ChallengeParleySeconds, ChallengeParleyDistance)
        Debug.Trace("[SeverActions] BeginChallengeParley: clock started, " + ChallengeParleySeconds + "s")
    Else
        Debug.Trace("[SeverActions] BeginChallengeParley: persuasion already active (arrest plea?) - no clock")
    EndIf
EndFunction

Event OnCampChallengeChoice(String eventName, String strArg, Float numArg, Form sender)
    {The player's posture from the card. Not the verdict - see the header.}

    Actor challenger = sender as Actor
    If challenger == None || CurrentChallenger != challenger
        Return
    EndIf
    If !SeverActionsNativeExt2.Camp_ChallengeIsPending(challenger)
        CurrentChallenger = None
        Return
    EndIf

    If strArg == "accept"
        BeginChallengeParley(challenger)
        ; CurrentChallenger stays set - the parley is still this encounter.

    ElseIf strArg == "denySilent"
        ; Answered with a drawn weapon.
        CurrentChallenger = None
        SeverActionsNative.Native_Persuasion_End()
        SeverActionsNativeExt2.Camp_ChallengeRefuse("the player answered with a drawn weapon")
        Game.GetPlayer().DrawWeapon()

    Else
        ; deny, a dismiss, or an expired card - all the same answer.
        CurrentChallenger = None
        SeverActionsNative.Native_Persuasion_End()
        SeverActionsNativeExt2.Camp_ChallengeRefuse("the player pushed past without answering")
        CleanUpChallengeWalk(challenger)
        challenger.StartCombat(Game.GetPlayer())
    EndIf
EndEvent

; ----------------------------------------------------------------------------
; The verdict - given by the CHALLENGER, in dialogue
; ----------------------------------------------------------------------------
; Both are gated on the camp_challenge_pending decorator, so only the outlaw
; actually doing the challenging can end it. Everyone else in the camp reads
; empty and never sees these in their eligible list.

Function LetThemPass_Execute(Actor akSpeaker)
    {The outlaw is satisfied. The truce holds for this visit.}
    If akSpeaker == None || !SeverActionsNativeExt2.Camp_ChallengeIsPending(akSpeaker)
        Return
    EndIf
    CurrentChallenger = None
    SeverActionsNative.Native_Persuasion_End()
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
    SeverActionsNative.Native_Persuasion_End()
    CleanUpChallengeWalk(akSpeaker)
    SeverActionsNativeExt2.Camp_ChallengeRefuse("the outlaw refused the player passage")
    ; The one who gave the verdict leads the charge - see the cleanup event
    ; for why restore alone is not enough for a passive-by-record challenger.
    akSpeaker.StartCombat(Game.GetPlayer())
EndFunction

Event OnCampChallengeCleanup(String eventName, String strArg, Float numArg, Form sender)
    {Native refused the challenge (persuasion timeout or the player walking
     off - routed natively because this quest form's second registration of
     SeverActions_PersuasionFailed never fires; see PersuasionMonitor.h).
     The camp is already broken; this handles the walk teardown, says the
     patience ran out IN THE SCENE, and puts the challenger into the fight.}
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

    ; Say it before the swing - the player watched a silent NPC walk off and
    ; then the room aggro. Two flavors: the clock ran out to their face, or
    ; the player walked off mid-question.
    Actor player = Game.GetPlayer()
    If StringUtil.Find(strArg, "walked away") >= 0
        SkyrimNetApi.DirectNarration("*" + challenger.GetDisplayName() + " watches " + player.GetDisplayName() + " walk off mid-question. That answer suits the camp fine - blades come out.*", challenger, player)
    Else
        SkyrimNetApi.DirectNarration("*" + challenger.GetDisplayName() + "'s patience runs out. Silence is an answer too - and the whole camp draws the same conclusion.*", challenger, player)
    EndIf

    ; The membership break restores everyone to their ORIGINAL aggression -
    ; which is faithful, and exactly why a passive-by-record challenger
    ; (Fort Greymoor's caretaker holds the bandit faction at aggression 0)
    ; shrugged and walked away while the room aggro'd around her. The one
    ; who asked the question does not get to sit the answer out: force the
    ; engagement. StartCombat is the Papyrus-only half the native break
    ; deliberately leaves to us.
    challenger.StartCombat(player)
EndEvent

Event OnCampHoardPlundered(String eventName, String strArg, Float numArg, Form sender)
    {The player emptied a camp's boss chest and the camp turned (native
     CampLoot broke it by roster). This writes the WHY into SkyrimNet's
     persistent record - without it the outlaws attacked with no idea what
     changed, which read as random aggression. strArg = camp name,
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
