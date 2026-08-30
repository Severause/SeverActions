Scriptname SeverActions_Travel extends Quest

{
    NPC Travel & Errand System — v6 (orchestrator-driven)

    Travel-to-arrival is owned by the native TravelOrchestrator. This script
    handles the action entry points, the post-arrival sandbox/waiting/greet
    phase, follower bookkeeping, and MCM/PrismaUI introspection.

    Required CK Setup:
    - Create 5 ReferenceAliases named TravelAlias00 through TravelAlias04
    - Each alias should be Optional, Allow Reuse, Initially Cleared
    - Attach TravelPackage to each alias (Travel to LinkedRef with TravelTargetKeyword)
    - Attach SandboxPackage to each alias (Sandbox at current location)
    - Create TravelTargetKeyword for linked ref targeting
}

; =============================================================================
; PROPERTIES - Aliases
; =============================================================================

ReferenceAlias Property TravelAlias00 Auto
ReferenceAlias Property TravelAlias01 Auto
ReferenceAlias Property TravelAlias02 Auto
ReferenceAlias Property TravelAlias03 Auto
ReferenceAlias Property TravelAlias04 Auto

; =============================================================================
; PROPERTIES - Packages & Keywords
; =============================================================================

Keyword Property TravelTargetKeyword Auto
{Keyword used to link NPC to their travel destination via SetLinkedRef.}

Package Property TravelPackage Auto
{Default/run travel package - also used as fallback.}

Package Property TravelPackageWalk Auto
Package Property TravelPackageJog Auto
Package Property TravelPackageRun Auto

Package Property SandboxPackage Auto
{Sandbox package - applied when NPC arrives at destination.}

; =============================================================================
; SPEED CONSTANTS — mirror SeverActionsNative TravelSpeed enum
; =============================================================================

Int Property SPEED_WALK = 0 AutoReadOnly
Int Property SPEED_JOG = 1 AutoReadOnly
Int Property SPEED_RUN = 2 AutoReadOnly

; =============================================================================
; PROPERTIES - Settings
; =============================================================================

Float Property ArrivalDistance = 300.0 Auto
{Distance in units to consider NPC "arrived". Interior cells need larger values.}

Float Property UpdateInterval = 3.0 Auto
{How often to check waiting slots (seconds).}

; Courier worldspace blacklist - built lazily once per session (see
; CourierBlockedWorldspace).
Form[] CourierWsBlacklist
Bool CourierWsBlacklistBuilt = false

Int Property TravelPackagePriority = 100 Auto
{Priority for travel/sandbox package overrides.}

Float Property DefaultWaitTime = 48.0 Auto
Float Property MinWaitTime = 6.0 Auto
Float Property MaxWaitTime = 168.0 Auto

Bool Property EnableDebugMessages = false Auto

Bool Property TravelMapMarkersEnabled = True Auto
{Vanilla-style objective map markers for travelers underway. The native
 orchestrator fires SeverActions_TravelSlotClaimed/Released per Traveler_NN
 pool slot; the handlers below display/undisplay the matching objective on
 SeverActions_TravelQuest (0x16AC00) so the player can see where a traveler
 is headed. Disabling stops NEW markers; releases always clear.}

; =============================================================================
; CONSTANTS
; =============================================================================

Int Property MAX_SLOTS = 5 AutoReadOnly

Int Property TravelActionCooldownSeconds = 120 Auto
{How long after one TravelToPlace before the LLM may pick it again, in real
 seconds. The anti-spam backstop for location-mention misfires - genuine
 travel is not something anyone orders twice a minute. 0 disables.}

; Orchestrator option bitfield (see SeverActionsNative.psc TRAVEL ORCHESTRATOR
; comment block). 4 = kTravelOpt_AbortOnDegraded (recommended on).
Int Property TRAVEL_OPTIONS_DEFAULT = 4 AutoReadOnly
; Named-place travel is usually long-range: the destination lives in an UNLOADED cell,
; where the orchestrator's CanNavigateToPosition pre-flight can't find a path and
; false-rejects the whole trip ("Begin pre-flight rejected -> no travel"). 4|8 adds
; kTravelOpt_SkipPreflight — the marker is already validated by ResolvePlace, and the
; orchestrator's leapfrog/teleport recovery is what carries a cross-cell journey.
Int Property TRAVEL_OPTIONS_LONGRANGE = 12 AutoReadOnly
; Long-range AND silent: 12|32 adds kTravelOpt_Quiet, which suppresses the
; Traveler_NN quest objective and its map marker. For errands the world runs
; on its own and the player was never told about - a hold steward walking out
; to look in on one of their retainers (ai_docs/STEWARD_VISITS.md).
Int Property TRAVEL_OPTIONS_QUIETLONG = 44 AutoReadOnly

; =============================================================================
; STEWARD VISITS (ai_docs/STEWARD_VISITS.md)
;
; Native decides WHO and WHEN and owns the cosaved state (VSTR v6); this script
; owns every package touch, because ActorUtil lives here. Three events:
;   SeverActions_StewardVisitTravel  sender=steward, strArg=retainer FormID
;   SeverActions_StewardVisitArrived sender=steward, strArg=retainer FormID
;   SeverActions_StewardVisitEnd     sender=steward
; The journey rides the orchestrator with the "stewardvisit" tag, so
; OnTravelComplete routes the leg's outcome back to native.
;
; The posting on arrival is the Final Audit's escort shape: LinkedRef the
; steward to the RETAINER under WorkAnchorKeyword, then the WorkSandbox
; package makes them mill about that person. The sandbox is NOT left on while
; they travel - a sandbox does not chase a moving anchor, which is what
; stranded the audit's battlemages in the road.
; =============================================================================

Int Property StewardVisitPriority = 110 AutoReadOnly
{Above the guard-duty alias pool (105) and the traveler pool (106), so a
 steward who also holds a person-duty posting still keeps the visit.}

Float Property AuditFollowHandoff = 1000.0 AutoReadOnly
{Where the Final Audit's walk ends and the follow package takes over. Mirrors
 VentureMonitor::kAuditFollowHandoff - keep the two in step. Deliberately much
 wider than ArrivalDistance: route steering is coarse, and the final approach
 wants the follow package's own beeline at the player.}

; =============================================================================
; TRACKING STATE
;
; Slots only track the *waiting* phase from the script's perspective — the
; orchestrator owns the *traveling* phase. SlotStates: 0=empty, 1=traveling
; (orchestrator handle in flight), 2=waiting (post-arrival sandbox).
; =============================================================================

; Per-slot travel state is StorageUtil-backed (cosave keys), NOT Papyrus member
; arrays. Member arrays corrupted across script recompiles ("Cannot create an array
; into a non-array variable" — unrecoverable, EnsureReady couldn't heal it), which
; left arrival unable to read the slot and so never removed the travel package /
; applied the sandbox. Cosave-keyed values can't suffer that. Keyed per slot (0..4):
;   State  0=empty 1=traveling 2=waiting
;   Sandbox override (e.g. SeversHearth's CampSandboxPackage); None = default SandboxPackage.

Function SetSlotState(Int s, Int v)
    StorageUtil.SetIntValue(None, "SeverTravel_SlotState_" + s, v)
EndFunction

String Function GetSlotPlaceName(Int s)
    Return StorageUtil.GetStringValue(None, "SeverTravel_SlotPlace_" + s, "")
EndFunction
Function SetSlotPlaceName(Int s, String v)
    StorageUtil.SetStringValue(None, "SeverTravel_SlotPlace_" + s, v)
EndFunction

ObjectReference Function GetSlotDest(Int s)
    Return StorageUtil.GetFormValue(None, "SeverTravel_SlotDest_" + s) as ObjectReference
EndFunction
Function SetSlotDest(Int s, ObjectReference v)
    StorageUtil.SetFormValue(None, "SeverTravel_SlotDest_" + s, v)
EndFunction

Float Function GetSlotWaitDeadline(Int s)
    Return StorageUtil.GetFloatValue(None, "SeverTravel_SlotWait_" + s, 0.0)
EndFunction
Function SetSlotWaitDeadline(Int s, Float v)
    StorageUtil.SetFloatValue(None, "SeverTravel_SlotWait_" + s, v)
EndFunction

Int Function GetSlotSpeed(Int s)
    Return StorageUtil.GetIntValue(None, "SeverTravel_SlotSpeed_" + s, 0)
EndFunction
Function SetSlotSpeed(Int s, Int v)
    StorageUtil.SetIntValue(None, "SeverTravel_SlotSpeed_" + s, v)
EndFunction

Int Function GetSlotHandle(Int s)
    Return StorageUtil.GetIntValue(None, "SeverTravel_SlotHandle_" + s, 0)
EndFunction
Function SetSlotHandle(Int s, Int v)
    StorageUtil.SetIntValue(None, "SeverTravel_SlotHandle_" + s, v)
EndFunction

Package Function GetSlotSandbox(Int s)
    Return StorageUtil.GetFormValue(None, "SeverTravel_SlotSandbox_" + s) as Package
EndFunction
Function SetSlotSandbox(Int s, Package v)
    StorageUtil.SetFormValue(None, "SeverTravel_SlotSandbox_" + s, v)
EndFunction

Function ClearSlotData(Int s)
    StorageUtil.UnsetIntValue(None, "SeverTravel_SlotState_" + s)
    StorageUtil.UnsetStringValue(None, "SeverTravel_SlotPlace_" + s)
    StorageUtil.UnsetFormValue(None, "SeverTravel_SlotDest_" + s)
    StorageUtil.UnsetFloatValue(None, "SeverTravel_SlotWait_" + s)
    StorageUtil.UnsetIntValue(None, "SeverTravel_SlotSpeed_" + s)
    StorageUtil.UnsetIntValue(None, "SeverTravel_SlotHandle_" + s)
    StorageUtil.UnsetFormValue(None, "SeverTravel_SlotSandbox_" + s)
EndFunction

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    DebugMsg("OnInit")
    InitializeSlotArrays()
    RegisterEvents()
    RegisterSpeedPackages()
    ChronoArm(UpdateInterval)
EndEvent

Function OnGameLoaded()
    {Load-time recovery. Called by SeverActions_Init.RunLoadRecovery() on
     every load — Quest scripts NEVER receive OnPlayerLoadGame, so this must
     be a called function, not an event handler: an OnPlayerLoadGame here
     would never fire, leaving in-flight travelers unrecovered (orphan-cleaned
     ~5s after load) and the ambush save/load teardown skipped.}
    DebugMsg("OnGameLoaded")

    ; Slot state is StorageUtil-backed now — no member arrays to initialize/heal.
    RegisterEvents()
    RegisterSpeedPackages()
    RecoverExistingTravelers()
    ; Belt for the ForceClear ModEvent's load-order race: the native load
    ; sweep can ask for clears BEFORE RegisterEvents above re-armed the
    ; listener (the VM is saturated for 30-60s after load on heavy lists),
    ; so also sweep the pool directly - any seated actor with NO live
    ; journey gets a vanilla Clear() right here.
    SweepStalePoolSeats()
    ; A standoff that was live when this save was made can't survive a reload (the
    ; native ambush-thug set is in-memory only), so tear it down cleanly instead of
    ; stranding the player with unresolvable neutral thugs.
    AbandonAmbushOnLoad()
    ChronoArm(UpdateInterval)
EndFunction

Function RegisterEvents()
    ; Orchestrator completion + PrismaUI controls. All ModEvent-based —
    ; DispatchMethodCall silently fails for cross-script signaling.
    RegisterForModEvent("SeverActions_TravelComplete", "OnTravelComplete")
    RegisterForModEvent("SeverActions_PrismaClearTravel", "OnPrismaClearTravel")
    RegisterForModEvent("SeverActions_PrismaResetTravel", "OnPrismaResetTravel")
    RegisterForModEvent("SeverActions_PrismaStripTravel", "OnPrismaStripTravel")
    ; Non-pausing travel popup → player-confirmed destination starts the trip.
    RegisterForModEvent("SeverActions_TravelPromptResult", "OnTravelPromptResult")
    ; Traveler map markers — native fires these per Traveler_NN pool slot
    ; (claimed on a verified alias fill + re-fired by the load sweep;
    ; released when the journey ends). Registered here so BOTH init paths
    ; cover them: OnInit and OnGameLoaded each call RegisterEvents().
    ; Grep-verified unique event names (one ModEvent name per quest FORM —
    ; a sibling script registering the same name would be silently dead).
    RegisterForModEvent("SeverActions_TravelSlotClaimed", "OnTravelSlotClaimed")
    RegisterForModEvent("SeverActions_TravelSlotReleased", "OnTravelSlotReleased")
    RegisterForModEvent("SeverActions_TravelMarkersToggle", "OnTravelMarkersToggle")
    RegisterForModEvent("SeverActions_TravelAliasForceClear", "OnTravelAliasForceClear")
    ; Steward visits — grep-verified unique names (one ModEvent name per quest
    ; FORM: a sibling script registering any of these would be silently dead).
    RegisterForModEvent("SeverActions_StewardVisitTravel", "OnStewardVisitTravel")
    RegisterForModEvent("SeverActions_StewardVisitArrived", "OnStewardVisitArrived")
    RegisterForModEvent("SeverActions_StewardVisitEnd", "OnStewardVisitEnd")
    ; The Final Audit walks to the player now. Travel lives here; the audit's
    ; own package work stays in SeverActions_Currency.
    RegisterForModEvent("SeverActions_FinalAuditTravel", "OnFinalAuditTravel")
    RegisterForModEvent("SeverActions_FinalAuditTravelAbort", "OnFinalAuditTravelAbort")
    EnsureCourierEvents()
EndFunction

; =============================================================================
; TRAVELER POOL (Traveler_NN) — pre-flight teardown, map markers, seat sweep
; =============================================================================

Function DisengageOverridesForTravel(Actor akNPC, String asTag)
    {Free the traveler from anything that fights the travel package BEFORE the
     journey starts (the Rin cooking-pot loop, 2026-08-09): a traveler bound to
     furniture never yields to the travel package - the StuckDetector leapfrogs
     them forward and the furniture pull walks them straight back, forever.
     The furniture teardown clears SA's override + linked ref and fires
     IdleForceDefaultState (which also unsticks vanilla/sandbox seating); the
     craft cancel drops the CraftAtForge override the same way (TermCancelled
     runs the usual cleanup). The NEXT override class that fights travel gets
     added HERE, once - both travel entry points call this.}
    If SeverActions_Furniture.StopUsingFurniture_Global_IsEligible(akNPC)
        DebugMsg(asTag + ": standing " + akNPC.GetDisplayName() + " up from furniture before travel")
        SeverActions_Furniture.StopUsingFurniture_Global_Execute(akNPC)
    EndIf
    If SeverActionsNativeExt2.Craft_CancelByActor(akNPC) > 0
        DebugMsg(asTag + ": cancelled in-flight crafting for " + akNPC.GetDisplayName() + " before travel")
    EndIf
EndFunction

Quest Function GetTravelPoolQuest()
    {The 24-alias traveler pool quest SeverActions_TravelQuest — resolved by
     FormID (never EditorID; VR strips runtime EditorIDs).}
    Return Game.GetFormFromFile(0x0016AC00, "SeverActions.esp") as Quest
EndFunction

Function SweepStalePoolSeats()
    {Load-recovery belt (Irileth field report, 2026-08-09): free any actor
     seated in a Traveler_NN alias with no live journey behind it. The
     engine-thunk empty does not take for us, and the ForceClear ModEvent
     can race this script's registration on load - a direct VM sweep is the
     one path with no ordering dependency. Clear() is the vanilla teardown.}
    Quest pool = GetTravelPoolQuest()
    If pool == None
        Return
    EndIf
    Int slot = 0
    While slot < 24
        ReferenceAlias ra = pool.GetAlias(slot) as ReferenceAlias
        If ra != None
            Actor held = ra.GetActorReference()
            If held != None && !SeverActionsNativeExt2.Travel_IsTravelingByActor(held)
                ra.Clear()
                held.EvaluatePackage()
                Debug.Trace("[SeverActions_Travel] Load sweep freed stale pool slot " + slot + " (" + held.GetDisplayName() + ")")
            EndIf
        EndIf
        slot += 1
    EndWhile
EndFunction

Event OnTravelSlotClaimed(String eventName, String strArg, Float numArg, Form sender)
    {A traveler was seated in pool slot numArg (0-23). Display that slot's
     objective — objective index is slot + 1 (QOBJ 1..24; vanilla never uses
     index 0). abForce=true re-shows the HUD line for a fresh journey after
     an earlier display/undisplay cycle on the same slot.}
    If !TravelMapMarkersEnabled
        Return
    EndIf
    Int slot = numArg as Int
    If slot < 0 || slot > 23
        Return
    EndIf
    Quest pool = GetTravelPoolQuest()
    If pool == None
        Return
    EndIf
    pool.SetObjectiveDisplayed(slot + 1, true, true)
EndEvent

Event OnTravelAliasForceClear(String eventName, String strArg, Float numArg, Form sender)
    {Native asked us to empty pool slot numArg via the VM: the engine-thunk
     null path (ForceRefIntoAlias) does not actually clear for us (Irileth
     field report, 2026-08-09 - an actor stayed pinned in her Traveler alias
     through 8 retries AND a quest bounce). ReferenceAlias.Clear() is the
     vanilla-sanctioned teardown and works where the thunk does not. sender
     is the actor the native EXPECTS in the slot - if someone else holds it
     now, a newer journey displaced the release and the slot is not ours.}
    Int slot = numArg as Int
    If slot < 0 || slot > 23
        Return
    EndIf
    Quest pool = GetTravelPoolQuest()
    If pool == None
        Return
    EndIf
    ReferenceAlias ra = pool.GetAlias(slot) as ReferenceAlias
    If ra == None
        Return
    EndIf
    Actor held = ra.GetActorReference()
    If held == None
        Return ; already empty - the native retry will read that back
    EndIf
    Actor expected = sender as Actor
    If expected != None && held != expected
        Return ; displaced by a newer journey - not ours to clear
    EndIf
    ra.Clear()
    held.EvaluatePackage()
    Debug.Trace("[SeverActions_Travel] Force-cleared travel pool slot " + slot + " via Papyrus Clear (" + held.GetDisplayName() + ")")
EndEvent

Event OnTravelSlotReleased(String eventName, String strArg, Float numArg, Form sender)
    {Pool slot numArg's journey is over (arrived, cancelled, aborted — or the
     alias refused to empty; the marker comes down either way). Deliberately
     NOT gated on TravelMapMarkersEnabled so toggling the setting off mid-
     journey can never strand a stale marker.}
    Int slot = numArg as Int
    If slot < 0 || slot > 23
        Return
    EndIf
    Quest pool = GetTravelPoolQuest()
    If pool == None
        Return
    EndIf
    pool.SetObjectiveDisplayed(slot + 1, false)
EndEvent

Event OnTravelMarkersToggle(String eventName, String strArg, Float numArg, Form sender)
    {PrismaUI Settings toggle for traveler quest-objective markers. With
     ambient NPCs now picking TravelToPlace on their own, a journal entry
     pinpointing every random traveler is clutter (field request 2026-08-08).
     Disabling ALSO takes down every currently-displayed marker immediately —
     the per-slot release handler stays as the steady-state cleanup, but the
     user should not wait out in-flight journeys to get a clean journal.}
    TravelMapMarkersEnabled = (numArg as Int) == 1
    If !TravelMapMarkersEnabled
        Quest pool = GetTravelPoolQuest()
        If pool != None
            Int i = 1
            While i <= 24
                pool.SetObjectiveDisplayed(i, false)
                i += 1
            EndWhile
        EndIf
    EndIf
    Debug.Trace("[SeverActions_Travel] traveler map markers " + TravelMapMarkersEnabled)
EndEvent

Event OnVentureDeparted(String eventName, String strArg, Float numArg, Form sender)
    {A retainer left the player's service (deserted, quit over terms, or escaped).
     strArg is the ready-made line; sender is the ex-retainer. Their venture entry
     stays cosaved so the sever_former_retainer decorator can tell them WHY when
     the player next speaks to them - and so a deserter can be taken back on.}
    If strArg != ""
        Debug.Notification(strArg)
    EndIf
EndEvent

Function EnsureCourierEvents()
    {Idempotent registration for the Enterprises courier events. Exposed so a
     reliably-loaded caller (the MCM) can guarantee they're registered even on
     saves where this quest's OnPlayerLoadGame didn't re-fire.}
    RegisterForModEvent("SeverActions_VentureLetter", "OnVentureLetter")
    RegisterForModEvent("SeverActions_VentureAmbush", "OnVentureAmbush")
    ; Someone left the player's service. The weekly settle runs off-screen, so
    ; without this the only sign was a faded card next time they opened the
    ; board. C++ has no notification primitive - this is the Papyrus half.
    RegisterForModEvent("SeverActions_VentureDeparted", "OnVentureDeparted")
    ; Shared with the arrest flow — both gate on their own active state.
    ; SHARED with SeverActions_ArrestPlayer: all SA scripts live on one quest
    ; form and SKSE keeps ONE callback per (form, event) - two different
    ; callback names meant one listener was silently dead (audit H3). Both
    ; scripts now register the SAME callback name; name-dispatch reaches both
    ; handlers and each gates on its own active state.
    RegisterForModEvent("SeverActions_PersuasionFailed", "OnPersuasionFailedEvent")
    ; A standoff thug entered combat by ANY path (incl. the generic AttackTarget) —
    ; normalize the whole pack to a real fight so the player's follower can hit them.
    RegisterForModEvent("SeverActions_VentureThugCombat", "OnVentureThugCombat")
EndFunction

Event OnVentureLetter(string eventName, string strArg, float numArg, Form sender)
    {A retainer (sender) has a pending courier letter from this week's settlement.
     Pull it from the native queue and dispatch a courier to bring it.}
    Actor retainer = sender as Actor
    Debug.Trace("[SeverActions] OnVentureLetter fired, sender=" + retainer)
    If retainer == None
        Return
    EndIf
    String subj   = SeverActionsNativeExt2.Venture_LetterSubject(retainer)
    String body   = SeverActionsNativeExt2.Venture_LetterBody(retainer)
    String reason = SeverActionsNativeExt2.Venture_LetterReason(retainer)
    SeverActionsNativeExt2.Venture_ClearLetter(retainer)
    If body != ""
        DispatchCourier(retainer, subj, body, reason)
    EndIf
EndEvent

; ── Retainer-grudge thug ambush (standoff) state ─────────────────────────────
; One ambush at a time (native enforces a cooldown). Outdoors the thugs spawn
; OFF-SCREEN and jog in as a pack (courier-style); on arrival the lead states why
; they're here, weapons come out (UNAGGRESSIVE), and a persuasion window opens:
; the player talks it out (SkyrimNet picks ThugStandDown/ThugAttack) or trips the
; window (draws/flees/timeout -> they strike). Indoors (debug only) they spawn
; close since there's no room to travel in.
Actor[] AmbushThugs
Actor AmbushLead
Actor AmbushDeserter
Bool AmbushActive = False
Bool AmbushApproaching = False
ObjectReference AmbushAwayMarker   ; the stand-down walk-off waypoint, deleted on the next stand-down so it doesn't accumulate
Float AmbushApproachStart = 0.0   ; real-time the approach began (poll timeout anchor)
; Letter is held back until the standoff opens, then handed to whichever thug
; reached the player first (the one who actually speaks) - so the narrator and
; the lootable letter are the same actor.
String AmbushLetterSubj = ""
String AmbushLetterBody = ""

Event OnVentureAmbush(string eventName, string strArg, float numArg, Form sender)
    {A wronged deserter (sender) hired thugs. Spawn them (off-screen outdoors, close
     indoors), give the lead the lootable threat letter, march them in, then open the
     standoff. Fired by the native grudge scheduler or the MCM debug button.}
    Actor player = Game.GetPlayer()
    If player == None
        Return
    EndIf
    ; Resolve any leftover standoff/approach first (defensive).
    If AmbushActive || AmbushApproaching
        ClearAmbushState()
    EndIf

    Actor deserter = sender as Actor
    Int count = numArg as Int
    If count < 1
        count = 2
    ElseIf count > 5
        count = 5
    EndIf

    ; Generic melee-bandit leveled character (Skyrim.esm LCharBanditMeleeAny,
    ; 0x0003DECD — resolved via HouseCARL). The load order's winner applies
    ; (Bandit War's rebalance is fine). PlaceAtMe on a LeveledCharacter spawns a
    ; concrete actor.
    Form thugList = Game.GetForm(0x0003DECD)
    If !thugList  ; not '== None' - the None-compare logs a cosmetic cast error
        Debug.Trace("[SeverActions] OnVentureAmbush: thug leveled list missing")
        Return
    EndIf

    ; Pull the lead thug's letter once (queued by the native, keyed by deserter).
    String subj = ""
    String body = ""
    If deserter != None
        subj = SeverActionsNativeExt2.Venture_LetterSubject(deserter)
        body = SeverActionsNativeExt2.Venture_LetterBody(deserter)
        SeverActionsNativeExt2.Venture_ClearLetter(deserter)
    EndIf
    ; Stash it; it gets handed to the first-arriving thug when the standoff opens.
    AmbushLetterSubj = subj
    AmbushLetterBody = body

    ; Outdoors: spawn off-screen and travel in. Indoors: no room — spawn close.
    Bool fromAfar = !player.IsInInterior()
    Float baseAng = Utility.RandomFloat(0.0, 360.0)

    ; Convert each spawn from a hostile bandit into a NEUTRAL hired blade:
    ; pull them out of BanditFaction (the player-hostility source) and into our own
    ; neutral SeverActions_HiredBladeFaction. Neutral is what lets the proper
    ; GuardFollowPlayer Follow package run (a Follow package obeys hostility - a
    ; bandit can't follow an enemy) AND stops the player's follower from swinging on
    ; them mid-parley. They only become hostile again on ResolveAmbushCombat.
    Faction banditFaction = GetBanditFaction()
    Faction bladeFaction = GetHiredBladeFaction()

    ; v15: a HOSTILE ex-retainer leads their own ambush. The native passes their
    ; FormID as a signed-decimal strArg ("" = hired blades only). They take slot
    ; 0 — they ARE the wronged party, so they lead the parley (AmbushLead =
    ; AmbushThugs[0]) and carry their own letter. Neutral-converted like the
    ; blades so the standoff can talk before it swings; every resolve path
    ; (stand-off walk-off, combat, teardown) already treats slot members
    ; uniformly, so no special casing downstream.
    Actor leader = None
    If strArg != ""
        Int leaderFid = strArg as Int
        If leaderFid != 0
            leader = Game.GetFormEx(leaderFid) as Actor
        EndIf
    EndIf

    AmbushThugs = new Actor[5]
    Int n = 0
    If leader != None && !leader.IsDead() && !leader.IsDisabled()
        leader.StopCombat()
        leader.SetActorValue("Aggression", 0)
        If bladeFaction != None
            leader.AddToFaction(bladeFaction)
        EndIf
        If fromAfar
            leader.MoveTo(player, 2800.0 * Math.Cos(baseAng), 2800.0 * Math.Sin(baseAng), 0.0)
        Else
            leader.MoveTo(player, 220.0, 0.0, 0.0)
        EndIf
        AmbushThugs[0] = leader
        n = 1
        Debug.Trace("[SeverActions] OnVentureAmbush: hostile ex-retainer " + leader + " leads the ambush")
    EndIf
    Int i = 0
    While i < count && n < 5
        ObjectReference ref = player.PlaceAtMe(thugList, 1)
        Actor thug = ref as Actor
        If thug
            thug.StopCombat()
            thug.SetActorValue("Aggression", 0)  ; won't swing on their own; the standoff resolves them
            If banditFaction != None
                thug.RemoveFromFaction(banditFaction)
            EndIf
            If bladeFaction != None
                thug.AddToFaction(bladeFaction)
            EndIf
            If fromAfar
                ; Off-screen, clustered in ONE direction so they read as a pack
                ; closing in rather than surrounding the player.
                Float ang = baseAng + (n as Float) * 12.0
                Float dist = 2800.0 + (n as Float) * 160.0
                thug.MoveTo(player, dist * Math.Cos(ang), dist * Math.Sin(ang), 0.0)
            Else
                Float ang = (n as Float) * 90.0
                thug.MoveTo(player, 220.0 * Math.Cos(ang), 220.0 * Math.Sin(ang), 0.0)
            EndIf
            AmbushThugs[n] = thug
            n += 1
        EndIf
        i += 1
    EndWhile

    If n == 0
        Debug.Trace("[SeverActions] OnVentureAmbush: no thugs spawned")
        Return
    EndIf

    AmbushLead = AmbushThugs[0]
    AmbushDeserter = deserter

    If fromAfar
        ; March the pack in: every thug jogs to the player via the SA travel
        ; package (linked-ref target — same package the courier/travel system uses,
        ; but WITHOUT the orchestrator, whose arrival callback proved unreliable for
        ; a placed actor chasing a moving player). We detect arrival ourselves in
        ; OnUpdate by proximity and then open the standoff (BeginAmbushStandoff) —
        ; that's where weapons/narration/persuasion happen. Actions aren't eligible
        ; until then, so nobody acts during the approach.
        AmbushApproaching = True
        AmbushApproachStart = Utility.GetCurrentRealTime()
        Package jog = GetTravelPackageForSpeed(SPEED_JOG)
        Int k = 0
        While k < AmbushThugs.Length
            Actor t = AmbushThugs[k]
            If t
                SeverActionsNative.LinkedRef_Set(t, player, TravelTargetKeyword)
                ; Register with OrphanCleanup or its ~5s scan sees the travel
                ; LinkedRef with no registry entry and strips the jog mid-
                ; approach (the pack froze off-screen and only the 12s
                ; standoff fallback masked it). Unregistered again when the
                ; approach resolves (BeginAmbushStandoff / StripThugPackages).
                SeverActionsNative.OrphanCleanup_RegisterTraveler(t)
                If jog != None
                    ; A hostile leader is a schedule-managed NPC: their prio-110
                    ; work package would beat the standard prio-100 jog, so their
                    ; override goes in above it. Removal is by package identity
                    ; (StripThugPackages), so the higher priority strips clean.
                    Int prio = TravelPackagePriority
                    If t == leader
                        prio = TravelPackagePriority + 20
                    EndIf
                    ActorUtil.AddPackageOverride(t, jog, prio, 1)
                EndIf
                t.EvaluatePackage()
            EndIf
            k += 1
        EndWhile
        ChronoArm(1.0)   ; poll for arrival
        Debug.Trace("[SeverActions] OnVentureAmbush: " + n + " thugs closing in from off-screen (deserter " + deserter + ")")
    Else
        BeginAmbushStandoff()
    EndIf
EndEvent

Actor Function GetNearestThug(Actor player)
    {The live thug closest to the player (skips dead/none). Used to detect arrival
     and to pick the speaker - whoever reaches the player first leads the parley.}
    Actor best = None
    Float bestDist = 0.0
    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t != None && !t.IsDead()
            Float d = t.GetDistance(player as ObjectReference)
            If best == None || d < bestDist
                best = t
                bestDist = d
            EndIf
        EndIf
        i += 1
    EndWhile
    Return best
EndFunction

Function CheckAmbushApproach()
    {Poll (from OnUpdate) while the pack jogs in. Opens the standoff as soon as the
     FIRST thug reaches the player (not the spawn-order lead, which often lags), or
     after a timeout so a bad-navmesh spawn can't strand the encounter. The arriving
     thug is promoted to lead so the one the player sees first is the one who speaks.}
    If !AmbushApproaching
        Return
    EndIf
    Actor player = Game.GetPlayer()
    If player == None
        BeginAmbushStandoff()   ; degenerate — just open it where they are
        Return
    EndIf
    Actor nearest = GetNearestThug(player)
    Float elapsed = Utility.GetCurrentRealTime() - AmbushApproachStart
    Bool arrived = False
    If nearest != None
        Float dist = nearest.GetDistance(player as ObjectReference)
        ; Distance alone - do NOT also require the same parent cell. Exterior cells
        ; are ~4096u across, so a thug that has jogged right up to the player near a
        ; cell boundary can sit ~200u away yet be in the adjacent cell; the old
        ; same-cell guard then failed and the standoff only opened on the 12s
        ; fallback (the "walk up, stand there, THEN narrate + draw" delay). Being
        ; within 700u already means they are physically on top of the player.
        If dist <= 700.0
            arrived = True
        EndIf
    EndIf
    If arrived || elapsed >= 12.0
        ; The closest thug leads the parley + carries the letter.
        If nearest != None
            AmbushLead = nearest
        EndIf
        BeginAmbushStandoff()
    EndIf
EndFunction

Function BeginAmbushStandoff()
    {Arrival beat: the pack has reached the player. Halt their approach, draw
     weapons (still unaggressive), make the standoff actions eligible, have the
     lead state why they're here, and open the persuasion window.}
    If AmbushActive
        Return   ; already begun — guard against a double trigger
    EndIf
    Actor player = Game.GetPlayer()
    If player == None
        ClearAmbushState()
        Return
    EndIf
    AmbushApproaching = False
    AmbushActive = True
    Package jog = GetTravelPackageForSpeed(SPEED_JOG)
    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t && !t.IsDead()
            t.StopCombat()
            ; Aggression 1 (Aggressive) - SAFE now that they're neutral: Aggression
            ; only drives attacking FACTION ENEMIES, and a neutral hired blade has
            ; none, so they still won't swing on the player. The win is the stance:
            ; an Aggression-0 actor is treated as "stood down" and the AI re-sheathes
            ; it (the old "weapon out for a second then away" flicker), whereas an
            ; Aggressive actor holds the combat-ready/weapon-out posture naturally -
            ; the same reason arrest guards keep weapons drawn through the parley.
            t.SetActorValue("Aggression", 1)
            ; Belt-and-suspenders: force the drawn/alert stance and re-assert it each
            ; tick in OnUpdate so the weapon stays out for the whole standoff.
            t.DrawWeapon()
            t.SetAlert(true)
            ; Hold ON the player with SkyrimNet's FollowPlayer package - the SAME
            ; mechanism the SA follow action uses (SeverActions_Follow), which is
            ; CONFIRMED to work on these exact actors (manually following one
            ; mid-standoff worked). The ESP GuardFollowPlayer override via
            ; AddPackageOverride did NOT stick (the thugs idled on
            ; DefaultMasterPackage); RegisterPackage routes through SkyrimNet's own
            ; package controller, which applies + holds it reliably. They follow the
            ; player 100% of the time until stand-down or combat. Drop the approach
            ; jog + its linked ref first so nothing competes.
            If jog != None
                ActorUtil.RemovePackageOverride(t, jog)
            EndIf
            SeverActionsNative.LinkedRef_Clear(t, TravelTargetKeyword)
            ; Approach leg over — pair with the RegisterTraveler at dispatch.
            SeverActionsNative.OrphanCleanup_UnregisterTraveler(t)
            SkyrimNetApi.RegisterPackage(t, "FollowPlayer", 100, 0, true)
            t.EvaluatePackage()
            SeverActionsNativeExt2.Venture_RegisterAmbushThug(t)        ; gates the standoff actions
            SeverActionsNativeExt2.Venture_StageThugDirective(t, AmbushDeserter)  ; hold/parley bias
        EndIf
        i += 1
    EndWhile

    ; Hand the lootable letter to the lead now that we know who it is (the
    ; first-arriver, promoted in CheckAmbushApproach) - so the thug who speaks is
    ; the one carrying the letter naming who sent them.
    If AmbushLead != None && AmbushLetterBody != ""
        String desertNm = ""
        If AmbushDeserter
            desertNm = AmbushDeserter.GetDisplayName()
        EndIf
        SeverActionsNativeExt.Letter_DeliverToCourier(AmbushDeserter, AmbushLead, AmbushLetterSubj, AmbushLetterBody, "thug", desertNm)
        AmbushLetterSubj = ""
        AmbushLetterBody = ""
    EndIf

    ; NOTE: the lead deliberately does NOT also get TalkToPlayer - it's already on
    ; FollowPlayer (above), and stacking two SkyrimNet packages causes the
    ; dual-package AI flicker the FollowerManager warns about. FollowPlayer keeps
    ; the lead on the player; the taunt below fires via DirectNarration regardless
    ; of which package is running.
    String taunt = SeverActionsNativeExt2.Venture_AmbushTaunt(AmbushDeserter)
    If taunt != "" && AmbushLead != None
        SkyrimNetApi.DirectNarration(taunt, AmbushLead, player)
    EndIf
    If AmbushLead != None
        SeverActionsNative.Native_Persuasion_Begin(AmbushLead, player, 30.0, 600.0)
    EndIf
    Debug.Trace("[SeverActions] Ambush: standoff begun")
EndFunction

Faction Function GetBanditFaction()
    {Vanilla BanditFaction (Skyrim.esm 0x0001BCC0) — the player-hostility source thugs
     are pulled OUT of for the neutral parley and put back INTO on combat. Single
     resolver so the FormID isn't duplicated across spawn/resolve (mirrors
     GetHiredBladeFaction).}
    Return Game.GetFormFromFile(0x0001BCC0, "Skyrim.esm") as Faction
EndFunction

Faction Function GetHiredBladeFaction()
    {Our neutral standoff faction (SeverActions.esp 0x165674). Thugs are moved into
     it (out of BanditFaction) for the parley so they read as neutral hired blades -
     the player's follower won't swing on them and SkyrimNet's FollowPlayer holds.
     Single resolver so the FormID isn't duplicated across spawn/resolve/teardown.}
    Return Game.GetFormFromFile(0x165674, "SeverActions.esp") as Faction
EndFunction

Function StripThugPackages(Actor t)
    {Remove the approach jog override + linked ref + the SkyrimNet hold packages from
     a thug, so a resolve (walk-off / combat / teardown) starts from a clean AI slate.
     The standoff hold is SkyrimNet's FollowPlayer (RegisterPackage), so that's what
     we unregister - the old ESP GuardFollowPlayer / CourierLoiter overrides were
     never actually applied to thugs and don't need stripping.}
    If t == None
        Return
    EndIf
    Package jog = GetTravelPackageForSpeed(SPEED_JOG)
    If jog != None
        ActorUtil.RemovePackageOverride(t, jog)
    EndIf
    SeverActionsNative.LinkedRef_Clear(t, TravelTargetKeyword)
    ; Drop any orphan-registry entry from the approach/walk-off legs — the
    ; travel link is gone, so the scanner has nothing left to police.
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(t)
    SkyrimNetApi.UnregisterPackage(t, "TalkToPlayer")
    SkyrimNetApi.UnregisterPackage(t, "FollowPlayer")
EndFunction

Function ThugStandDown_Execute(Actor akActor)
    {SkyrimNet action: the player talked the thugs down (persuaded / intimidated /
     bought off). End the standoff peacefully — they sheathe and WALK OFF on foot
     (not a fade-out): a far waypoint is dropped and each thug is pointed at it
     with the travel package, reusing the courier walk pattern.}
    If !AmbushActive
        Return
    EndIf
    MarkKidnapSteelSpent()
    Actor player = Game.GetPlayer()
    SeverActionsNative.Native_Persuasion_End()

    ; Drop a far waypoint for them to leave toward. XMarkerHeading (Skyrim.esm 0x34).
    ; Delete the previous stand-down marker first so repeated ambushes don't leak a
    ; trail of XMarkers (they're non-persistent, but bound it to one at a time).
    If AmbushAwayMarker != None
        AmbushAwayMarker.Disable()
        AmbushAwayMarker.Delete()
        AmbushAwayMarker = None
    EndIf
    ObjectReference awayMarker = None
    If player != None
        Form xm = Game.GetForm(0x00000034)
        If xm != None
            awayMarker = player.PlaceAtMe(xm, 1)
            If awayMarker != None
                awayMarker.MoveTo(player, 5000.0, 5000.0, 0.0)
                AmbushAwayMarker = awayMarker   ; tracked for cleanup on the next stand-down
            EndIf
        EndIf
    EndIf
    Package leavePkg = GetTravelPackageForSpeed(SPEED_JOG)
    Faction bladeFaction = GetHiredBladeFaction()

    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t && !t.IsDead()
            StripThugPackages(t)               ; clear the standoff hold/TalkToPlayer first
            ; Undo the neutral conversion so they don't walk off permanently stuck in
            ; our hired-blade faction (they leave peacefully - no need to re-add
            ; BanditFaction).
            If bladeFaction != None
                t.RemoveFromFaction(bladeFaction)
            EndIf
            t.StopCombat()
            t.SetAlert(false)                  ; drop the combat-ready stance so they sheathe and stay sheathed
            t.SheatheWeapon()
            t.SetActorValue("Aggression", 0)
            t.SetActorValue("Confidence", 0)   ; cowardly — won't turn back to fight
            If awayMarker != None && leavePkg != None
                ; Walk to the waypoint via the SA travel package (linked-ref target,
                ; same mechanism couriers use). Non-blocking; they jog off and leave.
                SeverActionsNative.LinkedRef_Set(t, awayMarker, TravelTargetKeyword)
                ; Registered or the orphan scan strips the walk-off package a
                ; few steps out (they froze in place forever); the departing
                ; list below despawns them once they're genuinely gone —
                ; nothing else ever cleaned up these spawns.
                SeverActionsNative.OrphanCleanup_RegisterTraveler(t)
                ActorUtil.AddPackageOverride(t, leavePkg, TravelPackagePriority, 1)
            EndIf
            StorageUtil.FormListAdd(self, "SeverTravel_DepartingThugs", t, false)
            t.EvaluatePackage()
        EndIf
        i += 1
    EndWhile
    StorageUtil.SetFloatValue(self, "SeverTravel_ThugDepartStart", Utility.GetCurrentRealTime())
    ; Reset bookkeeping ONLY — do NOT call ClearAmbushState here, it would strip
    ; the walk-off package we just applied.
    ResetAmbushBookkeeping()
    ChronoArm(UpdateInterval)   ; keep the loop alive for the despawn poll
    Debug.Trace("[SeverActions] Ambush: thugs stood down and walked off")
EndFunction

Function ProcessDepartingThugs()
    {Despawn walked-off ambush thugs once they're genuinely gone. We spawned
     them (PlaceAtMe) and nothing else owns them — without this they persisted
     forever as neutral, cowardly bandits loitering wherever the walk-off
     package stranded them. Dead thugs are left as lootable corpses.}
    Int count = StorageUtil.FormListCount(self, "SeverTravel_DepartingThugs")
    If count == 0
        Return
    EndIf
    Float started = StorageUtil.GetFloatValue(self, "SeverTravel_ThugDepartStart", 0.0)
    Float elapsed = Utility.GetCurrentRealTime() - started
    If elapsed < 0.0
        ; GetCurrentRealTime resets per app session — a deadline saved last
        ; session reads as negative now. Re-baseline instead of waiting forever.
        StorageUtil.SetFloatValue(self, "SeverTravel_ThugDepartStart", Utility.GetCurrentRealTime())
        elapsed = 0.0
    EndIf
    Actor player = Game.GetPlayer()
    Int i = count - 1
    While i >= 0
        Actor t = StorageUtil.FormListGet(self, "SeverTravel_DepartingThugs", i) as Actor
        Bool gone = (t == None) || t.IsDead()
        If !gone
            ; Grace period so they visibly walk away first, then despawn once
            ; out of sight (unloaded or far). The hard cap despawns a
            ; navmesh-stuck thug regardless so the list can't wedge.
            Bool outOfSight = !t.Is3DLoaded()
            If !outOfSight && player != None
                outOfSight = t.GetDistance(player as ObjectReference) > 3500.0
            EndIf
            If (elapsed >= 20.0 && outOfSight) || elapsed >= 300.0
                SeverActionsNative.OrphanCleanup_UnregisterTraveler(t)
                t.Disable()
                t.Delete()
                gone = True
            EndIf
        EndIf
        If gone
            StorageUtil.FormListRemoveAt(self, "SeverTravel_DepartingThugs", i)
        EndIf
        i -= 1
    EndWhile
    If StorageUtil.FormListCount(self, "SeverTravel_DepartingThugs") == 0
        StorageUtil.UnsetFloatValue(self, "SeverTravel_ThugDepartStart")
    EndIf
EndFunction

Function ThugAttack_Execute(Actor akActor)
    {SkyrimNet action: the thugs reject the player and attack.}
    If !AmbushActive
        Return
    EndIf
    ResolveAmbushCombat()
    Debug.Trace("[SeverActions] Ambush: thugs attack (rejected)")
EndFunction

Event OnPersuasionFailedEvent(String asEventName, String asReason, Float afUnused, Form akSender)
    {Shared SeverActions_PersuasionFailed ModEvent (the arrest flow uses it too).
     Only act when WE have a live ambush — the player drew a weapon, fled, or the
     window timed out, so the thugs strike.}
    If !AmbushActive
        Return
    EndIf
    ResolveAmbushCombat()
    Debug.Trace("[SeverActions] Ambush: persuasion failed (" + asReason + ") - thugs attack")
EndEvent

Event OnVentureThugCombat(String asEventName, String asReason, Float afUnused, Form akSender)
    {A standoff thug actually entered combat (fired by the native combat-enter hook
     for ANY path, incl. the generic AttackTarget that bypasses our resolve). Turn
     the whole standoff into a real fight: ResolveAmbushCombat raises every thug to
     full aggression + strips the hold packages, so they're hostile to the player's
     follower too and her hits land (no more teammate-no-damage phasing).}
    If !AmbushActive
        Return
    EndIf
    ResolveAmbushCombat()
    Debug.Trace("[SeverActions] Ambush: a thug entered combat - normalizing pack to full fight")
EndEvent

Function ResolveAmbushCombat()
    {Turn the standoff into a fight: clear the hold packages, go aggressive, engage.
     They stay spawned (real corpses to loot — the lead still carries the letter).}
    MarkKidnapSteelSpent()
    Actor player = Game.GetPlayer()
    Faction banditFaction = GetBanditFaction()
    Faction bladeFaction = GetHiredBladeFaction()
    SeverActionsNative.Native_Persuasion_End()
    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t && !t.IsDead()
            StripThugPackages(t)               ; drop the hold/TalkToPlayer so combat AI is clean
            ; Undo the neutral conversion: back into BanditFaction, out of the neutral
            ; hired-blade faction, so they read as hostile and the player's follower
            ; engages them (her hits land) instead of treating them as neutrals.
            If bladeFaction != None
                t.RemoveFromFaction(bladeFaction)
            EndIf
            If banditFaction != None
                t.AddToFaction(banditFaction)
            EndIf
            t.SetActorValue("Aggression", 2)
            t.SetAlert(true)
            t.StartCombat(player)
        EndIf
        i += 1
    EndWhile
    ResetAmbushBookkeeping()
EndFunction

Function MarkKidnapSteelSpent()
    {If this standoff was the hold's hired searchers for a REFUSED ransom,
     any resolution - a fight (the player kills them) or a stand-down (they
     walk off empty-handed) - means the hold's steel is SPENT to no effect.
     Stamp the victim so the kidnap tick can reopen negotiation after the
     dust settles; the flag also feeds the desperation premium on the next
     ransom resolve. Venture-grudge ambushes no-op here (their sender is a
     retainer with no kidnap ransom state).}
    If AmbushDeserter == None
        Return
    EndIf
    ; 3 = KIDNAP_RANSOM_REFUSED (KidnapStore::RansomState).
    If SeverActionsNativeExt.Native_Kidnap_GetRansomState(AmbushDeserter) == 3
        StorageUtil.SetFloatValue(AmbushDeserter, "SA_KidnapSteelSpentGT", Utility.GetCurrentGameTime())
        StorageUtil.SetIntValue(AmbushDeserter, "SA_KidnapSteelFailed", 1)
        Debug.Trace("[SeverActions] Ambush: hold steel spent for refused-ransom captive " + AmbushDeserter.GetDisplayName())
    EndIf
EndFunction

Function ResetAmbushBookkeeping()
    {Reset the ambush flags + clear the standoff-action eligibility — WITHOUT
     touching packages (callers that just applied a resolve package, e.g. the
     stand-down walk-off, rely on this not stripping it).}
    SeverActionsNativeExt2.Venture_ClearAmbushThugs()
    AmbushActive = False
    AmbushApproaching = False
    AmbushLead = None
    AmbushDeserter = None
    AmbushLetterSubj = ""
    AmbushLetterBody = ""
EndFunction

Function ClearAmbushState()
    {Full teardown (re-fire safety / defensive): strip every thug's packages, undo the
     neutral-faction conversion, then reset bookkeeping.}
    Faction bladeFaction = GetHiredBladeFaction()
    If AmbushThugs != None
        Int i = 0
        While i < AmbushThugs.Length
            Actor t = AmbushThugs[i]
            StripThugPackages(t)
            If t != None && bladeFaction != None
                t.RemoveFromFaction(bladeFaction)
            EndIf
            i += 1
        EndWhile
    EndIf
    ResetAmbushBookkeeping()
EndFunction

Function AbandonAmbushOnLoad()
    {Save/reload safety: the native ambush-thug eligibility set (m_ambushThugs in
     VentureMonitor) is transient and is cleared by the SKSE revert callback on
     every load (VentureMonitor::ResetTransientState), so a standoff that was
     live when the save was made can never be resolved (the standoff actions go
     ineligible and the combat-enter hook can't recognize the thugs). Rather than
     leave the player trailed by unresolvable neutral thugs forever, tear the
     encounter down on load: strip packages, undo the faction conversion, and
     despawn the orphaned spawns.}
    If !AmbushActive && !AmbushApproaching
        Return
    EndIf
    SeverActionsNative.Native_Persuasion_End()
    Faction bladeFaction = GetHiredBladeFaction()
    If AmbushThugs != None
        Int i = 0
        While i < AmbushThugs.Length
            Actor t = AmbushThugs[i]
            If t != None
                StripThugPackages(t)
                If bladeFaction != None
                    t.RemoveFromFaction(bladeFaction)
                EndIf
                t.Disable()
                t.Delete()
            EndIf
            i += 1
        EndWhile
    EndIf
    ResetAmbushBookkeeping()
    Debug.Trace("[SeverActions] Ambush: abandoned a standoff that was live across a save/reload")
EndFunction

Function RegisterSpeedPackages()
    ; Hand the speed packages to the orchestrator so other callers (PrismaUI,
    ; MCM, future natives) can resolve walk/jog/run without re-implementing the lookup.
    ;
    ; IMPORTANT: the CK-filled TravelPackageWalk / TravelPackageRun properties point at
    ; a LEGACY package family (SeverActions_TravelWalk/Run, 0x2B051/0x2B053) whose
    ; location keyword is 0x2B050 — but the native orchestrator only ever links the
    ; TravelTargetKeyword (0x76F5F). So a walk/run traveller got NO travel target and
    ; just stood there; the orchestrator's stuck-recovery then leapfrogged them, which
    ; reads as "teleporting between navmesh points". Register the SeverTravelToAction*
    ; family instead — every one targets 0x76F5F (matched the working default + jog).
    ; Resolved by FormID so a stale property fill can't reintroduce the wrong keyword.
    Package walkPkg = Game.GetFormFromFile(0x07C068, "SeverActions.esp") as Package  ; SeverTravelToActionWalk (0x76F5F)
    Package jogPkg  = Game.GetFormFromFile(0x07C069, "SeverActions.esp") as Package  ; SeverTravelToActionJog  (0x76F5F)
    Package runPkg  = Game.GetFormFromFile(0x076F60, "SeverActions.esp") as Package  ; SeverTravelToAction Run (0x76F5F)
    If !walkPkg
        walkPkg = TravelPackageJog   ; jog is the one correctly-keyworded property — safe fallback
    EndIf
    If !jogPkg
        jogPkg = TravelPackageJog
    EndIf
    If !runPkg
        runPkg = TravelPackage
    EndIf
    SeverActionsNativeExt.Travel_RegisterSpeedPackages(walkPkg, jogPkg, runPkg, runPkg)
EndFunction

Function EnsureReady()
    {Lazy-init guard for the public entry points. OnInit/OnPlayerLoadGame normally
     re-register the ModEvents + native speed packages, but on some existing saves
     OnPlayerLoadGame doesn't re-fire (stale Papyrus load-event binding), leaving the
     native speed-package / OrphanCleanup-traveler registries empty. Running the same
     setup on first use makes travel work regardless of whether the load event fired.
     All idempotent + cheap.}
    ; Slot state is StorageUtil-backed now (cosave keys) - nothing to allocate or heal here.
    RegisterEvents()
    RegisterSpeedPackages()
EndFunction

Function InitializeSlotArrays()
    ; New game / reset: clear every slot's StorageUtil-backed state.
    Int i = 0
    While i < MAX_SLOTS
        ClearSlotData(i)
        i += 1
    EndWhile
EndFunction

Function RecoverExistingTravelers()
    ; On load: aliases still hold the actors, orchestrator cosave restored its
    ; TRVL records and re-applied LinkedRefs in plugin.cpp.
    ;
    ;  - Traveling slots: verify the orchestrator still has a live handle. If
    ;    yes, re-apply the speed package (PO3 overrides don't always survive
    ;    save/load cleanly). If no, clean the slot.
    ;  - Waiting slots: re-apply the sandbox package so the actor keeps sandboxing
    ;    after load. Wait deadline is already in StorageUtil.
    Int i = 0
    While i < MAX_SLOTS
        ReferenceAlias theAlias = GetAliasForSlot(i)
        If theAlias
            Actor npc = theAlias.GetActorReference()
            If npc && !npc.IsDead()
                If GetSlotState(i) == 1
                    Int handle = GetSlotHandle(i)
                    If handle > 0 && SeverActionsNativeExt.Travel_IsActive(handle)
                        ; plugin.cpp clears the orphan registry at kPostLoadGame
                        ; ("Papyrus will re-register active travelers") — without
                        ; this call the 5s OrphanCleanup scan sees the restored
                        ; travel LinkedRef with an empty registry and strips the
                        ; package mid-journey. Mirrors Follow.psc's re-register.
                        SeverActionsNative.OrphanCleanup_RegisterTraveler(npc)
                        ; Phase 2: the Traveler_NN pool alias re-applies its own
                        ; package natively on cell load (the whole reason the pool
                        ; exists), so an aliased traveler needs NO override re-apply
                        ; here — doing so would re-create the two-package split.
                        ; Only a pool-exhausted traveler (no alias) gets the override.
                        If !SeverActionsNativeExt2.Travel_HasAlias(handle)
                            Package pkg = SeverActionsNativeExt.Travel_GetSpeedPackage(GetSlotSpeed(i))
                            If pkg != None
                                ActorUtil.AddPackageOverride(npc, pkg, TravelPackagePriority, 1)
                                npc.EvaluatePackage()
                            EndIf
                        EndIf
                        DebugMsg("Recovered traveling slot " + i + " (handle=" + handle + ")")
                    Else
                        DebugMsg("Slot " + i + " orchestrator handle lost - clearing")
                        ClearSlot(i, false)
                    EndIf
                ElseIf GetSlotState(i) == 2
                    ; Resolve the per-slot sandbox override (e.g. SeversHearth's camp)
                    ; the same way OnArrived does, so a reload while a follower is in the
                    ; waiting phase keeps them on their camp/destination sandbox instead
                    ; of the generic SandboxPackage.
                    Package recSandbox = StorageUtil.GetFormValue(npc, "SeverTravel_SandboxOverride") as Package
                    If recSandbox == None
                        recSandbox = GetSlotSandbox(i)
                    EndIf
                    If recSandbox == None
                        recSandbox = SandboxPackage
                    EndIf
                    If recSandbox
                        ActorUtil.AddPackageOverride(npc, recSandbox, TravelPackagePriority, 1)
                        npc.EvaluatePackage()
                    EndIf
                    ; Clear any stale real-time greet baseline — see bug #2.
                    StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
                    StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
                    ; Waiting NPCs still hold the travel LinkedRef (cleared only
                    ; when the wait resolves) — re-register with OrphanCleanup so
                    ; the post-load scan doesn't strip their sandbox.
                    SeverActionsNative.OrphanCleanup_RegisterTraveler(npc)
                    DebugMsg("Recovered waiting slot " + i)
                Else
                    ClearSlot(i, false)
                EndIf
            Else
                ; Empty/dead — zero out the slot's cosave state without invoking
                ; ClearSlot (alias may already be empty; nothing to remove).
                SetSlotState(i, 0)
                SetSlotPlaceName(i, "")
                SetSlotDest(i, None)
                SetSlotWaitDeadline(i, 0.0)
                SetSlotSpeed(i, 0)
                SetSlotHandle(i, 0)
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; ModEvent HANDLERS
; =============================================================================

Event OnTravelComplete(string eventName, string strArg, float numArg, Form sender)
    {Orchestrator completion. strArg = "<callbackTag>|<status>".
     Our callback tag is "slot_<n>" so we can route back to slot bookkeeping.}

    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String tag = StringUtil.Substring(strArg, 0, pipePos)
    String status = StringUtil.Substring(strArg, pipePos + 1, 0)

    ; Courier deliveries ride the orchestrator with the "courier" tag — on
    ; arrival (or any non-cancel terminal status) the courier hands over the
    ; letter; cancelled just despawns.
    If tag == "courier"
        Actor courierNpc = sender as Actor
        If courierNpc != None
            If status != "cancelled"
                DeliverCourierLetter(courierNpc)
            Else
                SeverActionsNativeExt.Courier_Release(courierNpc)
            EndIf
        EndIf
        Return
    EndIf

    ; A hold steward walking out to look in on one of their retainers. Only a
    ; real arrival posts them; anything else (gave up, timed out, the player
    ; turned them back from the travel page) drops the visit rather than
    ; leaving them sandboxing around nobody. Native owns the state either way.
    If tag == "stewardvisit"
        Actor stewardNpc = sender as Actor
        If stewardNpc
            SeverActionsNativeExt2.Steward_VisitLegDone(stewardNpc, status == "arrived")
            If status != "arrived"
                EndStewardVisit(stewardNpc)
            EndIf
        EndIf
        Return
    EndIf

    ; The Imperial Final Audit walking the player down. Native owns the state
    ; machine and decides what an arrival means; all this does is clean up the
    ; journey and report the leg. On a real arrival native fires
    ; SeverActions_FinalAuditApproach and the follow package closes the last
    ; stretch; on any failure it stages the detail behind the player instead,
    ; so the encounter always happens.
    If tag == "finalaudit"
        Actor legateNpc = sender as Actor
        If legateNpc
            ; The journey is over on EVERY terminal status: stop the orphan
            ; scanner treating him as a traveler and drop any pool-exhaustion
            ; fallback override + travel LinkedRef, so nothing competes with
            ; the follow package native is about to send. Quietly - this
            ; journey was never announced. (Idempotent with the abort
            ; handler's identical cleanup.)
            SeverActionsNative.OrphanCleanup_UnregisterTraveler(legateNpc)
            ClearTravelPackagesQuietly(legateNpc)
        EndIf
        SeverActionsNativeExt2.Venture_Audit_TravelLegDone(status == "arrived")
        Return
    EndIf

    ; (Thug-ambush arrival is detected by the OnUpdate proximity poll now, not the
    ; orchestrator — see CheckAmbushApproach. No "ambush" tag rides the orchestrator.)

    ; Kidnap legs (kidnap_grab / kidnap_transport) — forward to FollowerManager.
    ; SKSE keeps ONE ModEvent callback per (form, event), and every SA script
    ; shares this quest form, so FollowerManager can NOT register its own
    ; SeverActions_TravelComplete listener (a second RegisterForModEvent for an
    ; event a sibling script already holds is silently dead — this handler owns
    ; the registration for the whole quest). Route by tag instead.
    If StringUtil.GetLength(tag) >= 7 && StringUtil.Substring(tag, 0, 7) == "kidnap_"
        SeverActions_FollowerManager fmKidnap = (Self as Quest) as SeverActions_FollowerManager
        Actor kidnapNpc = sender as Actor
        If fmKidnap && kidnapNpc
            fmKidnap.HandleKidnapTravelComplete(kidnapNpc, tag, status)
        EndIf
        Return
    EndIf

    If StringUtil.GetLength(tag) < 6 || StringUtil.Substring(tag, 0, 5) != "slot_"
        Return  ; Not one of ours — Arrest or future callers use different tags.
    EndIf
    Int slot = (StringUtil.Substring(tag, 5, 0)) as Int
    If slot < 0 || slot >= MAX_SLOTS
        Return
    EndIf

    ; EnsureReady(): re-arm event + speed-package registration in case the load
    ; path never ran on this save (idempotent; touches no in-flight slot data).
    EnsureReady()

    Actor npc = sender as Actor
    DebugMsg("OnTravelComplete slot=" + slot + " status=" + status)

    ; Free the handle slot regardless — orchestrator is done with it.
    SetSlotHandle(slot, 0)

    If status == "arrived"
        If npc != None
            OnArrived(slot, npc, GetSlotPlaceName(slot))
        Else
            ClearSlot(slot, true)
        EndIf
    ElseIf status == "cancelled"
        ; Two cancel paths reach here and only ONE pre-clears the slot:
        ;  - Papyrus CancelTravel/CancelAllTravel -> ClearSlot THEN Travel_Cancel
        ;    -> this event. Slot already empty; ClearSlot below is a no-op.
        ;  - Native "Turn back" (PrismaUI travel page -> cancelJourney ->
        ;    CancelByActor -> Cancel -> FireCompletionEvent) NEVER runs ClearSlot;
        ;    it only releases the Traveler_NN pool alias. The legacy slot's
        ;    package override + LinkedRef would survive and the actor keeps
        ;    walking (the "turn back does nothing" field report).
        ; ClearSlot is idempotent — on the already-cleared path the alias holds
        ; no actor, so it skips the package/follower work (no double restore).
        ClearSlot(slot, true)
    Else
        ; aborted | gaveup | timedout — terminal failure, restore follower.
        String npcName = "Traveler"
        If npc != None
            npcName = npc.GetDisplayName()
        EndIf
        NotifyPlayer(npcName + " gave up traveling.")
        ClearSlot(slot, true)
    EndIf
EndEvent

Event OnPrismaClearTravel(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Clear a specific travel slot. strArg = "slotIndex|".}
    Int pipePos = StringUtil.Find(strArg, "|")
    Int slot = 0
    If pipePos >= 0
        slot = StringUtil.Substring(strArg, 0, pipePos) as Int
    EndIf
    ClearSlotFromMCM(slot)
EndEvent

Event OnPrismaResetTravel(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Cancel all active travel.}
    CancelAllTravel()
EndEvent

Event OnPrismaStripTravel(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: strip a STRAY SeverActions travel package from an NPC the
     Travel tab's ground-truth scan surfaced (override present, no live
     orchestrator entry - a leak from an old save or a lost completion
     event; the SnS "SeverTravelToActionWalk forever" field report).
     Sender = the actor.}
    Actor npc = sender as Actor
    If npc
        StripStrayTravelPackages(npc)
    EndIf
EndEvent

Function StripStrayTravelPackages(Actor akNPC)
    {Remove EVERY travel-family package override this mod has ever applied:
     the current SeverTravelToAction* family (resolved by FormID exactly
     like RegisterSpeedPackages, so stale CK property fills cannot miss)
     plus the CK-filled legacy properties. RemovePackageOverride is a safe
     no-op for packages the actor never held. Also ends any hidden
     orchestrator session and clears the travel LinkedRef so nothing is
     left for OrphanCleanup to chase. The NPC returns to their own AI.}
    If !akNPC
        Return
    EndIf
    EnsureReady()
    Package p = Game.GetFormFromFile(0x07C068, "SeverActions.esp") as Package  ; SeverTravelToActionWalk
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    p = Game.GetFormFromFile(0x07C069, "SeverActions.esp") as Package          ; SeverTravelToActionJog
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    p = Game.GetFormFromFile(0x076F60, "SeverActions.esp") as Package          ; SeverTravelToAction (run)
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    ; Legacy family / CK-property fills (old saves carried these).
    If TravelPackage
        ActorUtil.RemovePackageOverride(akNPC, TravelPackage)
    EndIf
    If TravelPackageWalk
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageWalk)
    EndIf
    If TravelPackageJog
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageJog)
    EndIf
    If TravelPackageRun
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageRun)
    EndIf
    ; End a hidden orchestrator session if one somehow exists (safe no-op),
    ; and drop the travel LinkedRef the package steered by.
    SeverActionsNativeExt.Travel_CancelByActor(akNPC)
    SeverActionsNative.LinkedRef_Clear(akNPC, TravelTargetKeyword)
    akNPC.EvaluatePackage()
    NotifyPlayer(akNPC.GetDisplayName() + " is released from their travel package.")
    Debug.Trace("[SeverActions_Travel] StripStrayTravelPackages: cleared " + akNPC.GetDisplayName())
EndFunction

; =============================================================================
; COURIER — letter delivery NPC (Enterprises Phase 3)
;
; Spawns a WICourierNPC that walks up to the player and hands over a letter.
; Routing reuses the travel package override + orchestrator (tag "courier");
; the spawn + despawn live in the native CourierManager. The pending letter is
; stashed on the courier (StorageUtil) until it reaches the player, so a
; moving/interrupted delivery never loses the text.
; =============================================================================

; Single-courier rule (field report 2026-08-09: TEN couriers surrounding the
; player after a settle week). At most ONE courier exists at a time, and at
; most one per CourierMinIntervalDays; every letter QUEUES, the courier
; ceremonially hands over the first and delivers the WHOLE queue on arrival
; (the week's mailbag). Urgent letters (ransom) bypass the cooldown, never
; the one-at-a-time rule.
Float Property CourierMinIntervalDays = 7.0 Auto Hidden
{Minimum game days between courier dispatches. 7 = one courier per week.}

Int Function DispatchCourier(Actor akSender, String asSubject, String asBody, String asReason)
    {Queue a letter for courier delivery. The actual dispatch is gated by
     TryDispatchQueuedCourier (single courier, weekly cooldown, outdoors only)
     — callers never spawn couriers directly anymore. Returns 1 on queue, 0
     on bad args.}
    EnsureReady()
    Actor player = Game.GetPlayer()
    If player == None || asBody == ""
        Return 0
    EndIf
    QueueCourierLetter(akSender, asSubject, asBody, asReason)
    ChronoArm(UpdateInterval)  ; keep the queue poll alive
    TryDispatchQueuedCourier()
    Return 1
EndFunction

Bool Function ActiveCourierLive()
    {Is a dispatched courier still on the job? Frees the lock when the courier
     died, got deleted, or has been unloaded-and-silent for over 6 game hours
     (native despawn ate them without a delivery).}
    Actor c = StorageUtil.GetFormValue(self, "SeverTravel_ActiveCourier") as Actor
    If c == None
        Return false
    EndIf
    Bool stale = (!c.Is3DLoaded()) && \
        (Utility.GetCurrentGameTime() - StorageUtil.GetFloatValue(self, "SeverTravel_ActiveCourierGT", 0.0)) > 0.25
    If c.IsDead() || c.IsDeleted() || stale
        StorageUtil.UnsetFormValue(self, "SeverTravel_ActiveCourier")
        Return false
    EndIf
    Return true
EndFunction

Bool Function QueueHasUrgent()
    Int i = 0
    Int n = StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Reason")
    While i < n
        If StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Reason", i) == "ransom"
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

Bool Function TryDispatchQueuedCourier()
    {Gatekeeper for every courier spawn. Pops the FIRST queued letter onto the
     courier (the ceremonial handoff item); the REST stay queued and are handed
     over together at delivery — a lost courier costs at most one letter,
     exactly like the old single-letter flow. Returns true when a courier was
     dispatched.}
    If StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body") == 0
        Return false
    EndIf
    Actor player = Game.GetPlayer()
    If player == None || player.IsInInterior() || CourierBlockedWorldspace(player)
        Return false
    EndIf
    If ActiveCourierLive()
        Return false   ; their arrival hands over the whole queue anyway
    EndIf
    Float nowGT = Utility.GetCurrentGameTime()
    If nowGT - StorageUtil.GetFloatValue(self, "SeverTravel_LastCourierGT", -100.0) < CourierMinIntervalDays && !QueueHasUrgent()
        Return false   ; one courier per week at the maximum (urgent bypasses)
    EndIf

    ; Read (don't pop yet — pop only after a successful spawn) letter 0.
    Actor akSender = Game.GetFormEx(StorageUtil.StringListGet(self, "SeverTravel_CourierQ_SenderFid", 0) as Int) as Actor
    String asSubject = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Subject", 0)
    String asBody    = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Body", 0)
    String asReason  = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Reason", 0)
    String senderNm  = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_SenderName", 0)
    If senderNm == "" && akSender != None
        senderNm = akSender.GetDisplayName()
    EndIf

    ; Spawn well out in the exterior so the courier actually travels in,
    ; rather than popping up next to the player.
    Float spawnDist = 3000.0
    Actor courier = SeverActionsNativeExt.Courier_Spawn(player, spawnDist)
    If courier == None
        DebugMsg("TryDispatchQueuedCourier: spawn failed - letters stay queued")
        Return false
    EndIf
    StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_SenderFid", 0)
    StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Subject", 0)
    StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Body", 0)
    StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Reason", 0)
    StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_SenderName", 0)
    StorageUtil.SetFormValue(self, "SeverTravel_ActiveCourier", courier)
    StorageUtil.SetFloatValue(self, "SeverTravel_ActiveCourierGT", nowGT)
    StorageUtil.SetFloatValue(self, "SeverTravel_LastCourierGT", nowGT)

    ; Stash the pending letter on the courier until it reaches the player.
    StorageUtil.SetFormValue(courier, "SA_CourierSender", akSender)
    ; Snapshot the NAME too, while the sender is known-good. The letter writer
    ; is by definition away, and if their ref is gone by the time the courier
    ; reaches the player the letter view drops its -a letter from X- line and
    ; the player has no idea who wrote (user report 2026-08-03).
    StorageUtil.SetStringValue(courier, "SA_CourierSenderName", senderNm)
    StorageUtil.SetStringValue(courier, "SA_CourierSubject", asSubject)
    StorageUtil.SetStringValue(courier, "SA_CourierBody", asBody)
    StorageUtil.SetStringValue(courier, "SA_CourierReason", asReason)

    ; Travel in from afar. Apply the jog travel package + drive the orchestrator;
    ; OnTravelComplete fires when within arrival range and routes to
    ; DeliverCourierLetter, which forces a SkyrimNet TalkToPlayer package for the
    ; final approach + face, then hands the letter over. 300s cap; on timeout/abort
    ; OnTravelComplete still delivers (the letter is never lost).
    Package travelPkg = GetTravelPackageForSpeed(SPEED_JOG)
    Int cHandle = SeverActionsNativeExt.Travel_Begin(courier, player, TravelTargetKeyword, 400.0, "courier", TRAVEL_OPTIONS_DEFAULT, 300, SPEED_JOG)
    ; Phase 2: the Traveler_NN pool alias (a clone of travelPkg, priority 106)
    ; drives the jog. The legacy override applies ONLY as the pool-exhaustion
    ; fallback (or if Begin failed) — no second competing package otherwise.
    If travelPkg != None && (cHandle <= 0 || !SeverActionsNativeExt2.Travel_HasAlias(cHandle))
        ActorUtil.AddPackageOverride(courier, travelPkg, TravelPackagePriority, 1)
        courier.EvaluatePackage()
    EndIf
    ; Register with OrphanCleanup — the ~3000u jog spans multiple 5s scan
    ; windows and the scanner otherwise strips the travel package mid-
    ; delivery (the courier stuttered/teleported in on stuck-recovery).
    ; Unregistered in DeliverCourierLetter once the travel leg ends.
    SeverActionsNative.OrphanCleanup_RegisterTraveler(courier)
    DebugMsg("TryDispatchQueuedCourier: courier en route from afar (" \
        + StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body") + " more letter(s) ride the same delivery)")
    Return true
EndFunction

; =============================================================================
; STEWARD VISITS — the journey out, the posting, the stand-down
; =============================================================================

Event OnStewardVisitTravel(String eventName, String strArg, Float numArg, Form sender)
    {Native picked a retainer for this steward to go and see. sender = the
     steward; strArg = the retainer's FormID as SIGNED DECIMAL (never a float
     numArg - floats are exact only to 2^24 and higher FormIDs corrupt).
     Start the orchestrator journey; OnTravelComplete reports the leg back.}
    Actor steward = sender as Actor
    Actor target = Game.GetFormEx(strArg as Int) as Actor
    If !steward || !target
        Debug.Trace("[SeverActions_Travel] steward visit: steward or retainer did not resolve")
        Return
    EndIf
    EnsureReady()
    ; Free them from anything that fights a travel package first (furniture,
    ; in-flight crafting) - the same pre-flight every other journey does.
    DisengageOverridesForTravel(steward, "StewardVisit")
    ; The DESTINATION IS THE RETAINER'S OWN REF: the orchestrator reads a ref
    ; destination's position live each tick, so the walk tracks a person who
    ; moves rather than aiming at a spot they have wandered away from.
    ; Quiet: no journal objective and no map marker (this is the world's own
    ; errand, not something the player ordered).
    Int handle = SeverActionsNativeExt.Travel_Begin(steward, target, TravelTargetKeyword, \
        ArrivalDistance, "stewardvisit", TRAVEL_OPTIONS_QUIETLONG, 0, SPEED_WALK)
    If handle <= 0
        ; Begin refused (unresolvable destination, rollback). Tell native the
        ; leg is done and failed so the seat does not sit in Traveling until
        ; its backstop expires.
        Debug.Trace("[SeverActions_Travel] steward visit: Travel_Begin refused for " + steward.GetDisplayName())
        SeverActionsNativeExt2.Steward_VisitLegDone(steward, false)
        Return
    EndIf
    ; Pool-exhaustion fallback ONLY, exactly like the courier: the Traveler_NN
    ; alias package already drives the walk when a slot was claimed, and adding
    ; the override too would be a second competing package.
    Package travelPkg = GetTravelPackageForSpeed(SPEED_WALK)
    If travelPkg != None && !SeverActionsNativeExt2.Travel_HasAlias(handle)
        ActorUtil.AddPackageOverride(steward, travelPkg, TravelPackagePriority, 1)
        steward.EvaluatePackage()
    EndIf
    ; A cross-hold walk spans many 5s orphan-scan windows; without this the
    ; scanner strips the travel package mid-journey (the courier's lesson).
    SeverActionsNative.OrphanCleanup_RegisterTraveler(steward)
    DebugMsg("StewardVisit: " + steward.GetDisplayName() + " is walking out to " + target.GetDisplayName())
EndEvent

Event OnStewardVisitArrived(String eventName, String strArg, Float numArg, Form sender)
    {The steward has reached their retainer. Post them on that PERSON - the
     Final Audit's escort shape: LinkedRef under the work-anchor keyword, then
     the WorkSandbox package mills them about whoever is linked.}
    Actor steward = sender as Actor
    Actor target = Game.GetFormEx(strArg as Int) as Actor
    If !steward || !target
        Return
    EndIf
    PostStewardVisit(steward, target)
EndEvent

Function PostStewardVisit(Actor akSteward, Actor akTarget)
    {Anchor the steward to the retainer and sandbox them around that person.
     Idempotent - PO3 cosaves overrides, so re-applying is harmless.

     THE ANCHOR IS SHARED WITH THE WORK SYSTEM. WorkAnchorKeyword (0x165675)
     is the same link a retainer's own work sandbox steers by, so pointing it
     at the visited retainer CLOBBERS the steward's workplace anchor. That is
     fine only because the stand-down restores it from Native_GetWorkLoc,
     which is the authoritative record of their work marker - without that
     restore the steward would come home and never work again.}
    Package sandboxPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Keyword anchorKw = Game.GetFormFromFile(0x00165675, "SeverActions.esp") as Keyword
    If !sandboxPkg || !anchorKw
        Debug.Trace("[SeverActions_Travel] steward visit: WorkSandbox package/keyword missing - run GenerateWorkSandbox.pas")
        Return
    EndIf
    ; The travel leg is over: stop the orphan scanner watching them as a
    ; traveler and drop any fallback travel override, or it competes with the
    ; sandbox for the rest of the visit. Done QUIETLY - deliberately not
    ; StripStrayTravelPackages, which posts a player-facing notification and
    ; would announce a journey the player was never told about in the first
    ; place (the whole point of the quiet travel option).
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(akSteward)
    ClearTravelPackagesQuietly(akSteward)
    ; Permanent so OrphanCleanup's staleness prune can never strip the anchor
    ; mid-visit and leave the sandbox with nothing to mill about.
    SeverActionsNativeExt.LinkedRef_SetPermanent(akSteward, akTarget, anchorKw)
    ActorUtil.AddPackageOverride(akSteward, sandboxPkg, StewardVisitPriority, 1)
    akSteward.EvaluatePackage()
    DebugMsg("StewardVisit: " + akSteward.GetDisplayName() + " is now keeping company with " + akTarget.GetDisplayName())
EndFunction

; =============================================================================
; THE FINAL AUDIT'S APPROACH — a real walk, not a teleport
; =============================================================================

Event OnFinalAuditTravel(String eventName, String strArg, Float numArg, Form sender)
    {The grace has lapsed and the General sets out from Dragonsreach on foot.
     sender = the General. He walks the WHOLE way under the orchestrator - the
     Traveler_NN pool alias makes him persistent so the engine's low-process
     sim carries him while unloaded, which is what makes a cross-Skyrim walk
     possible at all (it was not, before that pool existed).

     Only he travels. The two battlemages hold their Follow package on him, so
     the formation carries itself and exactly one actor is ever steered.}
    Actor legate = sender as Actor
    Actor player = Game.GetPlayer()
    If !legate || !player
        SeverActionsNativeExt2.Venture_Audit_TravelLegDone(false)
        Return
    EndIf
    EnsureReady()
    DisengageOverridesForTravel(legate, "FinalAudit")
    ; DROP THE COURT SANDBOX BEFORE THE WALK. It sits at priority 100 with a
    ; LinkedRef anchored to the marker AT DRAGONSREACH - leaving it on is what
    ; sent the General sandbox-walking home mid-standoff in the first field
    ; test, the moment the travel package came off and nothing outranked it.
    ; ApplyFinalAuditApproachPackages re-strips it too, but the walk must not
    ; depend on that event landing.
    Package courtPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    If courtPkg
        ActorUtil.RemovePackageOverride(legate, courtPkg)
    EndIf
    ; Quiet: no journal objective and no map marker. Being FOUND is the whole
    ; drama of the encounter - a quest arrow announcing the taxman would give
    ; the game away before he is over the horizon.
    ;
    ; The threshold is deliberately wide (1000u, not the usual arrival
    ; distance): route steering is coarse by design, and the last stretch
    ; belongs to the follow package's own beeline. Native takes it from there.
    Int handle = SeverActionsNativeExt.Travel_Begin(legate, player, TravelTargetKeyword, \
        AuditFollowHandoff, "finalaudit", TRAVEL_OPTIONS_QUIETLONG, 0, SPEED_JOG)
    If handle <= 0
        Debug.Trace("[SeverActions_Travel] Final Audit: Travel_Begin refused - native will stage instead")
        SeverActionsNativeExt2.Venture_Audit_TravelLegDone(false)
        Return
    EndIf
    ; Pool-exhaustion fallback only - the Traveler_NN alias package drives the
    ; walk when a slot was claimed, and a second override would fight it.
    Package travelPkg = GetTravelPackageForSpeed(SPEED_JOG)
    If travelPkg != None && !SeverActionsNativeExt2.Travel_HasAlias(handle)
        ActorUtil.AddPackageOverride(legate, travelPkg, TravelPackagePriority, 1)
        legate.EvaluatePackage()
    EndIf
    SeverActionsNative.OrphanCleanup_RegisterTraveler(legate)
    DebugMsg("FinalAudit: the General is on the road to the player")
EndEvent

Event OnFinalAuditTravelAbort(String eventName, String strArg, Float numArg, Form sender)
    {Native wants the walk to stop - it overran its ceiling, or he reached the
     player early. Cancelling fires the orchestrator's completion event with
     status "cancelled", which routes back through OnTravelComplete and tells
     native the leg failed; native then stages and sends the march packages.}
    Actor legate = sender as Actor
    If !legate
        Return
    EndIf
    SeverActionsNativeExt.Travel_CancelByActor(legate)
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(legate)
    ClearTravelPackagesQuietly(legate)
    legate.EvaluatePackage()
EndEvent

Function ClearTravelPackagesQuietly(Actor akNPC)
    {The silent half of StripStrayTravelPackages: drop the travel-family
     overrides and the travel LinkedRef with no notification and no trace
     spam. For journeys the player was never told about.

     MUST strip the LEGACY CK-property family too, not just the three
     FormID-resolved packages. GetTravelPackageForSpeed falls back to
     TravelPackageJog / TravelPackage when the FormID lookups fail
     (RegisterSpeedPackages' self-heal), so in that path the pool-exhaustion
     fallback override applied at journey start is one of THESE forms - and a
     cleanup that only knew about the FormID trio could never remove it. The
     steward or the General would then carry a travel package for the rest of
     the session. RemovePackageOverride is a safe no-op for a package the
     actor never held, so stripping both families always is free.}
    Package p = Game.GetFormFromFile(0x07C068, "SeverActions.esp") as Package  ; walk
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    p = Game.GetFormFromFile(0x07C069, "SeverActions.esp") as Package          ; jog
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    p = Game.GetFormFromFile(0x076F60, "SeverActions.esp") as Package          ; run
    If p
        ActorUtil.RemovePackageOverride(akNPC, p)
    EndIf
    ; Legacy CK-property fills - the fallback family RegisterSpeedPackages
    ; self-heals to. Mirrors StripStrayTravelPackages.
    If TravelPackage
        ActorUtil.RemovePackageOverride(akNPC, TravelPackage)
    EndIf
    If TravelPackageWalk
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageWalk)
    EndIf
    If TravelPackageJog
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageJog)
    EndIf
    If TravelPackageRun
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageRun)
    EndIf
    SeverActionsNative.LinkedRef_Clear(akNPC, TravelTargetKeyword)
EndFunction

Event OnStewardVisitEnd(String eventName, String strArg, Float numArg, Form sender)
    {The visit is over (dwell elapsed, the retainer left the books, the seat
     was vacated, the journey was lost). Release the anchor, drop the override,
     and hand the steward back to their own schedule.}
    Actor steward = sender as Actor
    If steward
        EndStewardVisit(steward)
    EndIf
EndEvent

Function EndStewardVisit(Actor akSteward)
    {Undo PostStewardVisit. Idempotent, and safe to call on a steward who was
     only ever mid-journey (nothing was posted yet - the cancel below is the
     part that matters then).}
    Package sandboxPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Keyword anchorKw = Game.GetFormFromFile(0x00165675, "SeverActions.esp") as Keyword
    ; Kill any travel leg still running (an end that arrives while they are
    ; still walking: a lost completion, a dismissal, the retainer leaving).
    SeverActionsNativeExt.Travel_CancelByActor(akSteward)
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(akSteward)
    ClearTravelPackagesQuietly(akSteward)
    If sandboxPkg
        ActorUtil.RemovePackageOverride(akSteward, sandboxPkg)
    EndIf
    If anchorKw
        ; RESTORE THE WORK ANCHOR, never just clear it. The visit borrowed the
        ; work system's own keyword; clearing it outright would leave the
        ; steward's work sandbox with no target and they would never return to
        ; their post. Native_GetWorkLoc is the authoritative marker record.
        ObjectReference workMarker = SeverActionsNative.Native_GetWorkLoc(akSteward)
        If workMarker
            SeverActionsNativeExt.LinkedRef_SetPermanent(akSteward, workMarker, anchorKw)
        Else
            SeverActionsNative.LinkedRef_Clear(akSteward, anchorKw)
        EndIf
    EndIf
    akSteward.EvaluatePackage()
    DebugMsg("StewardVisit: " + akSteward.GetDisplayName() + " is released - back to their books")
EndFunction

Bool Function CourierBlockedWorldspace(Actor akPlayer)
    {Exterior worldspaces a courier could never plausibly reach - underground
     mega-zones (Blackreach, Darkfall Passage), other planes (Sovngarde, Soul
     Cairn, Apocrypha), and roadless hidden areas (Forgotten Vale, Skuldafn,
     Ancestor Glade, Forebears' Holdout, the Boneyard, Volkihar's courtyard).
     IsInInterior() covers real interiors; these are technically exteriors.
     Resolved by FormID, never EditorID (runtime EditorIDs are stripped
     without po3 Tweaks - the VR lesson); DLC lookups return None harmlessly
     when the master is absent (SA does not require the DLC).}
    WorldSpace ws = akPlayer.GetWorldSpace()
    If !ws
        Return false
    EndIf
    If !CourierWsBlacklistBuilt
        Form[] bl = new Form[11]
        bl[0]  = Game.GetFormFromFile(0x01EE62, "Skyrim.esm")      ; Blackreach
        bl[1]  = Game.GetFormFromFile(0x02EE41, "Skyrim.esm")      ; Sovngarde
        bl[2]  = Game.GetFormFromFile(0x0278DD, "Skyrim.esm")      ; SkuldafnWorld
        bl[3]  = Game.GetFormFromFile(0x001408, "Dawnguard.esm")   ; DLC01SoulCairn
        bl[4]  = Game.GetFormFromFile(0x000BB5, "Dawnguard.esm")   ; DLC01FalmerValley (Forgotten Vale)
        bl[5]  = Game.GetFormFromFile(0x004BEA, "Dawnguard.esm")   ; DLC1DarkfallPassageWorld
        bl[6]  = Game.GetFormFromFile(0x002F64, "Dawnguard.esm")   ; DLC1ForebearsHoldout
        bl[7]  = Game.GetFormFromFile(0x0048C7, "Dawnguard.esm")   ; DLC1AncestorsGladeWorld
        bl[8]  = Game.GetFormFromFile(0x00528D, "Dawnguard.esm")   ; DLC01Boneyard
        bl[9]  = Game.GetFormFromFile(0x007202, "Dawnguard.esm")   ; DLC1VampireCastleCourtyard
        bl[10] = Game.GetFormFromFile(0x01C0B2, "Dragonborn.esm")  ; DLC2ApocryphaWorld
        CourierWsBlacklist = bl
        CourierWsBlacklistBuilt = true
    EndIf
    Return CourierWsBlacklist.Find(ws as Form) >= 0
EndFunction

Function QueueCourierLetter(Actor akSender, String asSubject, String asBody, String asReason)
    {FIFO of letters waiting for the player to step outside. Parallel
     StorageUtil string lists on self; the sender rides as a FormID string
     because a None entry in a FormList would silently desync the parallel
     lists (senders can be gone by delivery time - resolved best-effort).}
    Int senderFid = 0
    If akSender
        senderFid = akSender.GetFormID()
    EndIf
    StorageUtil.StringListAdd(self, "SeverTravel_CourierQ_SenderFid", senderFid as String)
    StorageUtil.StringListAdd(self, "SeverTravel_CourierQ_Subject", asSubject)
    StorageUtil.StringListAdd(self, "SeverTravel_CourierQ_Body", asBody)
    StorageUtil.StringListAdd(self, "SeverTravel_CourierQ_Reason", asReason)
    ; Snapshot the sender NAME while the ref is known-good — senders can be
    ; gone by delivery time and the letter view needs its from-line.
    String qSenderNm = ""
    If akSender
        qSenderNm = akSender.GetDisplayName()
    EndIf
    StorageUtil.StringListAdd(self, "SeverTravel_CourierQ_SenderName", qSenderNm)
EndFunction

Bool Function ProcessCourierQueue()
    {OnUpdate poll: try the single batch courier whenever the gates clear
     (outdoors, no live courier, weekly cooldown elapsed). Returns whether
     anything still needs the loop alive — queued letters waiting on a gate,
     or an en-route courier whose staleness check wants polling.}
    TryDispatchQueuedCourier()
    Return StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body") > 0 || ActiveCourierLive()
EndFunction

Function DeliverCourierLetter(Actor akCourier)
    {Hand the stashed letter to the player, have the courier announce it via
     direct narration, then send them off to despawn.}
    If akCourier == None
        Return
    EndIf
    Actor player = Game.GetPlayer()
    Actor sender = StorageUtil.GetFormValue(akCourier, "SA_CourierSender") as Actor
    String subj = StorageUtil.GetStringValue(akCourier, "SA_CourierSubject")
    String body = StorageUtil.GetStringValue(akCourier, "SA_CourierBody")
    String reason = StorageUtil.GetStringValue(akCourier, "SA_CourierReason")

    ; Put the letter in the COURIER's pack (not the player's) so they can
    ; physically hand it over with the give animation, and get the form back.
    Form note = None
    If body != ""
        note = SeverActionsNativeExt.Letter_DeliverToCourier(sender, akCourier, subj, body, reason,             StorageUtil.GetStringValue(akCourier, "SA_CourierSenderName"))
    EndIf

    ; End the travel package, then force SkyrimNet's TalkToPlayer package: the
    ; courier turns to the player, closes the last gap, and HOLDS there to speak
    ; — instead of stopping short on a default "stay" package. (SkyrimNet's own
    ; controller applies "TalkToPlayer" the same way for live dialogue.)
    ;
    ; Do NOT unregister the traveler here (2026-08-01 statue-courier fix):
    ; the loiter below re-anchors on the SAME TravelTargetKeyword LinkedRef,
    ; and an actor holding that keyword while unregistered is exactly what
    ; OrphanCleanup's 5s scan strips — anchor gone, sandbox dead, courier
    ; frozen in place until despawn. They stay registered for their whole
    ; life; the native CourierManager deregisters at actual despawn.
    RemoveAllTravelPackages(akCourier)
    If player != None
        SkyrimNetApi.RegisterPackage(akCourier, "TalkToPlayer", 100, 0, false)
        akCourier.EvaluatePackage()
    EndIf

    ; Speak — SkyrimNet turns this scene narration into the courier's line,
    ; referencing the sender for context.
    If player != None
        String senderName = ""
        If sender != None
            senderName = sender.GetDisplayName()
        EndIf
        If reason == "ransom" && sender != None
            ; Pool letters are keyed by the CAPTIVE, so 'sender' here is the
            ; victim - and a courier announcing a letter *from Hulda* while
            ; Hulda sits bound reads as a mistake. The ransom answer comes
            ; from the victim's hold court (the steward who signed it).
            String ransomHold = SeverActionsNativeExt.Hold_GetHoldName(sender)
            If ransomHold != ""
                senderName = "the court of " + ransomHold + ", concerning " + sender.GetDisplayName()
            Else
                senderName = sender.GetDisplayName() + "'s people"
            EndIf
        EndIf
        ; Single-courier rule: this courier carries the whole queued mailbag,
        ; so the narration matches what's about to be handed over.
        Int pendingExtra = StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body")
        String letterWord = "a sealed letter"
        If pendingExtra > 0
            letterWord = "a small bundle of letters, the topmost"
        EndIf
        String narration = "*A courier catches up to " + player.GetDisplayName() + ", a little out of breath, and holds out " + letterWord
        If senderName != ""
            narration += " from " + senderName
        EndIf
        narration += ". They explain they were paid to put it into the player's own hands, and urge the player to read it before long.*"
        SkyrimNetApi.DirectNarration(narration, akCourier, player)
    EndIf

    ; Give the courier a moment to close the gap + turn, then physically hand the
    ; letter over with the give animation (by FORM — the note is runtime-retitled
    ; so a name lookup wouldn't find it).
    Utility.Wait(2.5)
    If note != None && player != None
        SeverActions_Loot lootScript = (Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest) as SeverActions_Loot
        If lootScript != None
            lootScript.GiveItemForm_Execute(akCourier, player, note, 1)
        Else
            akCourier.RemoveItem(note, 1, false, player)
        EndIf
    EndIf

    ; BATCH: hand over every letter still queued — the single-courier rule
    ; means this courier carries the week's whole mailbag. Each queued letter
    ; becomes a real note in the player's inventory (silent transfer; the
    ; ceremony above covered the first one).
    Int extraDelivered = 0
    While StorageUtil.StringListCount(self, "SeverTravel_CourierQ_Body") > 0
        Actor qSnd = Game.GetFormEx(StorageUtil.StringListGet(self, "SeverTravel_CourierQ_SenderFid", 0) as Int) as Actor
        String qSubj   = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Subject", 0)
        String qBody   = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Body", 0)
        String qReason = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_Reason", 0)
        String qName   = StorageUtil.StringListGet(self, "SeverTravel_CourierQ_SenderName", 0)
        StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_SenderFid", 0)
        StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Subject", 0)
        StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Body", 0)
        StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_Reason", 0)
        StorageUtil.StringListRemoveAt(self, "SeverTravel_CourierQ_SenderName", 0)
        If qBody != ""
            If qName == "" && qSnd != None
                qName = qSnd.GetDisplayName()
            EndIf
            Form qNote = SeverActionsNativeExt.Letter_DeliverToCourier(qSnd, akCourier, qSubj, qBody, qReason, qName)
            If qNote != None && player != None
                akCourier.RemoveItem(qNote, 1, true, player)
                extraDelivered += 1
            EndIf
        EndIf
    EndWhile

    ; This delivery is done — free the single-courier lock.
    StorageUtil.UnsetFormValue(self, "SeverTravel_ActiveCourier")

    If extraDelivered > 0
        Debug.Notification("A courier hands you " + (extraDelivered + 1) + " letters.")
    Else
        Debug.Notification("A courier hands you a letter.")
    EndIf

    ; Done speaking — sandbox AROUND THE PLAYER for the linger (IntelEngine-style):
    ; CourierLoiter is a sandbox anchored to the TravelTargetKeyword linked ref,
    ; so pointing that at the player makes the courier mill around them (and pull
    ; in if they stopped short) rather than freeze on a fixed spot. Set the linked
    ; ref + add the sandbox BEFORE dropping the talk package so there's no
    ; default-AI gap to "stand around" in.
    If player != None
        SeverActionsNative.LinkedRef_Set(akCourier, player, TravelTargetKeyword)
    EndIf
    Package courierLoiterPkg = Game.GetFormFromFile(0x165673, "SeverActions.esp") as Package
    If courierLoiterPkg != None
        ActorUtil.AddPackageOverride(akCourier, courierLoiterPkg, 100, 1)
    ElseIf SandboxPackage != None
        ActorUtil.AddPackageOverride(akCourier, SandboxPackage, TravelPackagePriority, 1)
    EndIf
    If player != None
        SkyrimNetApi.UnregisterPackage(akCourier, "TalkToPlayer")
    EndIf
    akCourier.EvaluatePackage()

    ; Clear the stash so a recycled FormID can't re-deliver.
    StorageUtil.UnsetFormValue(akCourier, "SA_CourierSender")
    StorageUtil.UnsetStringValue(akCourier, "SA_CourierSenderName")
    StorageUtil.UnsetStringValue(akCourier, "SA_CourierSubject")
    StorageUtil.UnsetStringValue(akCourier, "SA_CourierBody")
    StorageUtil.UnsetStringValue(akCourier, "SA_CourierReason")

    ; Sandbox here; despawn once the player leaves the cell (native-side).
    SeverActionsNativeExt.Courier_Release(akCourier)
EndFunction

; =============================================================================
; PLACE RESOLUTION
; =============================================================================

ObjectReference Function ResolvePlace(Actor akNPC, String placeName)
    {Native LocationResolver handles the full chain: semantic terms,
     city aliases, exact/editor-ID match, fuzzy, Levenshtein.}
    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("ResolvePlace: LocationResolver not initialized")
        Return None
    EndIf
    ObjectReference marker = SeverActionsNative.ResolveDestination(akNPC, placeName)
    If marker == None
        DebugMsg("Could not resolve '" + placeName + "'")
    EndIf
    Return marker
EndFunction

ObjectReference Function ResolvePlaceLegacy(String placeName)
    {Legacy wrapper kept for any external script — prefer the actor-aware form.}
    Return ResolvePlace(Game.GetPlayer(), placeName)
EndFunction

; =============================================================================
; MAIN API
; =============================================================================

Bool Function TravelToPlace(Actor akNPC, String placeName, Float waitHours = 0.0, Bool stopFollowing = true, Int speed = 0, Bool waitForPlayer = true)
    {Action entry (executionFunctionName). Offers a non-pausing PrismaUI popup so the
     player can confirm or redirect the destination; on confirm the trip starts via
     DoTravelToPlace (routed through OnTravelPromptResult). Cancel/timeout/Escape =
     no travel. If PrismaUI isn't available, a popup's already up, or another view
     has focus, it falls back to travelling directly to the LLM's pick.}
    If akNPC == None
        Return false
    EndIf
    ; Mid-encounter setup (NSFW pairing): the scene system owns this NPC's
    ; movement - never let the LLM march them off "to start the scene" and
    ; spam the popup. No-op when the NSFW add-on isn't installed (nothing
    ; ever stamps the flag). The traveltoplace.yaml eligibility gate normally
    ; stops the action being offered at all; this is the belt-and-suspenders
    ; for a stale action the LLM emits before eligibility re-checks.
    If SeverActionsNativeExt.Native_SceneBound_IsBound(akNPC)
        DebugMsg("TravelToPlace: suppressed - " + akNPC.GetDisplayName() + " is mid-encounter setup")
        Return false
    EndIf
    ; Anti-spam cooldown (user report: NPCs fire this whenever a location is
    ; so much as MENTIONED, and the confirm popup mid-conversation got as
    ; annoying as the misfire). The yaml description now carries hard
    ; criteria, but a description is advice the LLM can ignore - this is the
    ; mechanical backstop: once ANY travel fires (or even opens the popup),
    ; the action leaves the eligible list for TravelActionCooldownSeconds.
    ; Genuine travel is not something anyone does twice a minute.
    SkyrimNetApi.SetActionCooldown("TravelToPlace", TravelActionCooldownSeconds)
    ; User setting: skip the confirm popup entirely and just send them off.
    If !SeverActionsNative.PrismaUI_IsTravelPopupEnabled()
        Return DoTravelToPlace(akNPC, placeName, waitHours, stopFollowing, speed, waitForPlayer)
    EndIf
    ; User setting: popup only for the player's own followers - a random
    ; citizen deciding to go somewhere is not the player's call to redirect.
    If SeverActionsNative.PrismaUI_IsTravelPopupFollowersOnly() && !IsPopupWorthyTraveler(akNPC)
        Return DoTravelToPlace(akNPC, placeName, waitHours, stopFollowing, speed, waitForPlayer)
    EndIf
    ; Guarantee the confirm handler is registered before the popup can fire it — on
    ; saves where this quest's OnPlayerLoadGame didn't re-fire, RegisterEvents() never
    ; ran, so the native SeverActions_TravelPromptResult would land on a dead listener
    ; (the player clicks Go and nothing happens). RegisterForModEvent is idempotent.
    RegisterForModEvent("SeverActions_TravelPromptResult", "OnTravelPromptResult")
    If SeverActionsNativeExt.PrismaUI_IsTravelPromptAvailable() \
        && SeverActionsNativeExt.PrismaUI_OpenTravelPrompt(akNPC, placeName, 60000)
        ; Stash the action's params so the confirm handler starts the trip with them.
        StorageUtil.SetFloatValue(akNPC, "SeverTravel_PendingWait", waitHours)
        StorageUtil.SetIntValue(akNPC, "SeverTravel_PendingStopFollow", stopFollowing as Int)
        StorageUtil.SetIntValue(akNPC, "SeverTravel_PendingSpeed", speed)
        StorageUtil.SetIntValue(akNPC, "SeverTravel_PendingWaitForPlayer", waitForPlayer as Int)
        DebugMsg("TravelToPlace: opened travel popup for " + akNPC.GetDisplayName() + " (prefill '" + placeName + "')")
        Return true
    EndIf
    Return DoTravelToPlace(akNPC, placeName, waitHours, stopFollowing, speed, waitForPlayer)
EndFunction

Bool Function IsPopupWorthyTraveler(Actor akNPC)
    {Followers-only popup scope: teammates and SA-registered followers
     (including track-only) count as the player's people; anyone else
     travels without asking.}
    If akNPC.IsPlayerTeammate()
        Return true
    EndIf
    SeverActions_FollowerManager fm = (self as Quest) as SeverActions_FollowerManager
    If fm == None
        Return false
    EndIf
    Return fm.IsRegisteredFollower(akNPC)
EndFunction

Event OnTravelPromptResult(string eventName, string strArg, float numArg, Form sender)
    {Player confirmed a destination in the non-pausing travel popup — strArg is the
     chosen place, sender is the NPC. Cancel / timeout / Escape never fire this.}
    Actor npc = sender as Actor
    If !npc || strArg == ""
        Return
    EndIf
    Float waitHours = StorageUtil.GetFloatValue(npc, "SeverTravel_PendingWait", 0.0)
    Bool stopFollowing = StorageUtil.GetIntValue(npc, "SeverTravel_PendingStopFollow", 1) != 0
    Int speed = StorageUtil.GetIntValue(npc, "SeverTravel_PendingSpeed", 0)
    Bool waitForPlayer = StorageUtil.GetIntValue(npc, "SeverTravel_PendingWaitForPlayer", 1) != 0
    StorageUtil.UnsetFloatValue(npc, "SeverTravel_PendingWait")
    StorageUtil.UnsetIntValue(npc, "SeverTravel_PendingStopFollow")
    StorageUtil.UnsetIntValue(npc, "SeverTravel_PendingSpeed")
    StorageUtil.UnsetIntValue(npc, "SeverTravel_PendingWaitForPlayer")
    DoTravelToPlace(npc, strArg, waitHours, stopFollowing, speed, waitForPlayer)
EndEvent

Bool Function DoTravelToPlace(Actor akNPC, String placeName, Float waitHours = 0.0, Bool stopFollowing = true, Int speed = 0, Bool waitForPlayer = true)
    {Send an NPC to a named place. Returns true if travel started.
     speed: 0=walk, 1=jog, 2=run.
     waitForPlayer: true = they are meeting the player there (greet on
     approach, patience timeout); false = a self-errand - they arrive, do
     their business for waitHours, then drift back to their normal life.}

    If akNPC == None
        DebugMsg("TravelToPlace: None actor")
        Return false
    EndIf
    If akNPC.IsDead()
        DebugMsg("TravelToPlace: dead actor")
        Return false
    EndIf
    If placeName == ""
        DebugMsg("TravelToPlace: empty placeName")
        Return false
    EndIf

    EnsureReady()

    ; Clamp speed
    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf

    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("TravelToPlace: LocationResolver not initialized")
        Return false
    EndIf

    ; Resolve BEFORE cancelling — a bad placeName must not nuke active travel.
    ObjectReference destMarker = ResolvePlace(akNPC, placeName)
    If destMarker == None
        ; Close the silent-failure loop: tell the NPC's LLM the place did not
        ; resolve so they can say so and ask for the proper name, instead of
        ; announcing a trip and then standing still.
        SkyrimNetApi.RegisterShortLivedEvent("travelfail_" + akNPC.GetFormID(), \
            "travel_failed", \
            akNPC.GetDisplayName() + " meant to set out for '" + placeName + "' but realizes they do not actually know where that is. They should admit it and ask for the place's proper name.", \
            "", 30000, akNPC, Game.GetPlayer())
        Return false
    EndIf

    ; Exterior intent ("outside/beside <place>"): the resolver stamped this
    ; actor because the phrase asked for the ENTRANCE, not the inside. Consume
    ; the stamp and keep the exterior door as the destination - they arrive,
    ; sandbox, and loiter around the entrance instead of walking in.
    Bool exteriorIntent = SeverActionsNativeExt.Native_TravelExteriorIntent(akNPC)

    ; If destination is a door to an interior, follow through to the interior marker.
    ObjectReference finalDest = destMarker
    If destMarker.GetBaseObject().GetType() == 29 && !exteriorIntent
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(destMarker, akNPC)
        If interiorMarker != None
            finalDest = interiorMarker
            DebugMsg("Door resolved to interior marker for '" + placeName + "'")
        EndIf
        ; Unlock the door so AI pathfinding isn't blocked.
        If destMarker.IsLocked()
            destMarker.Lock(false)
        EndIf
    ElseIf exteriorIntent
        DebugMsg("Exterior intent for '" + placeName + "' - stopping at the entrance")
    EndIf

    ; Resolve the speed package BEFORE cancelling — if the package is missing
    ; (CK property not filled) we don't want to lose the current travel as a
    ; side effect of misconfiguration.
    Package travelPkg = GetTravelPackageForSpeed(speed)
    If travelPkg == None
        DebugMsg("TravelToPlace: no package for speed " + speed)
        Return false
    EndIf

    ; Now safe to cancel any existing travel for this NPC.
    CancelTravel(akNPC)

    DisengageOverridesForTravel(akNPC, "TravelToPlace")

    Int slot = FindFreeSlot()
    If slot < 0
        DebugMsg("TravelToPlace: no free slots")
        Return false
    EndIf

    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias == None
        DebugMsg("TravelToPlace: no alias for slot " + slot)
        Return false
    EndIf

    ; Wait deadline (uses default if 0)
    If waitHours <= 0.0
        waitHours = DefaultWaitTime
    EndIf
    waitHours = ClampFloat(waitHours, MinWaitTime, MaxWaitTime)
    Float waitUntil = Utility.GetCurrentGameTime() + (waitHours / 24.0)

    theAlias.ForceRefTo(akNPC)

    If stopFollowing
        DismissFollower(akNPC)
    EndIf

    ; Hand off to the orchestrator — it sets the LinkedRef target, evaluates, and
    ; claims a Traveler_NN pool alias whose package (a QNAM-retargeted clone of
    ; travelPkg, priority 106 — above the actor's own AI) drives BOTH the loaded
    ; and unloaded leg. Phase 2: no AddPackageOverride in the common case — the
    ; pool alias IS the package, so pace/cancel/turn-back all operate on one
    ; thing. callbackTag carries the slot index so OnTravelComplete routes back.
    Int handle = SeverActionsNativeExt.Travel_Begin(akNPC, finalDest, TravelTargetKeyword, ArrivalDistance, "slot_" + slot, TRAVEL_OPTIONS_LONGRANGE, 0, speed)
    If handle <= 0
        DebugMsg("TravelToPlace: orchestrator rejected (handle=0)")
        theAlias.Clear()
        Return false
    EndIf
    ; Pool-exhaustion fallback ONLY (>24 concurrent travelers): with no free
    ; Traveler_NN alias, the legacy override drives the trip. Mirrors the
    ; follow/guard pools, which keep their override for exactly this case.
    If !SeverActionsNativeExt2.Travel_HasAlias(handle)
        ActorUtil.AddPackageOverride(akNPC, travelPkg, TravelPackagePriority, 1)
        akNPC.EvaluatePackage()
    EndIf

    ; Record state
    SetSlotState(slot, 1)
    SetSlotPlaceName(slot, placeName)
    SetSlotDest(slot, finalDest)
    SetSlotWaitDeadline(slot, waitUntil)
    SetSlotSpeed(slot, speed)
    SetSlotHandle(slot, handle)

    ; Mark this NPC as an actively-tracked traveler so OrphanCleanup's keyword
    ; scan doesn't see the travel LinkedRef as a stale orphan and tear it down
    ; mid-journey. Cleared in ClearSlot. (Without this, m_trackedTravelers stays
    ; empty and OrphanCleanup cancels every travel ~5s after it starts.)
    SeverActionsNative.OrphanCleanup_RegisterTraveler(akNPC)

    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "traveling")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Destination", placeName)
    SeverActionsNative.Native_SetTravelState(akNPC, "traveling", placeName)
    StorageUtil.SetFloatValue(akNPC, "SeverTravel_WaitUntil", waitUntil)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Slot", slot)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", speed)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_WaitForPlayer", waitForPlayer as Int)

    NotifyPlayer(akNPC.GetDisplayName() + " traveling to " + placeName)
    ChronoArm(UpdateInterval)
    Return true
EndFunction

Bool Function TravelNPCToReference(Actor akNPC, ObjectReference akDestination, Float waitHours = 0.0, Bool stopFollowing = false, Int speed = 1, Package akSandboxOverride = None)
    {Send an NPC directly to an ObjectReference destination (door, marker, NPC,
     follower's camp center, etc.). Skips name resolution. Orchestrator-driven
     equivalent of the old TravelToReference. Used by SeversHearth's GoToCamp
     and any other external caller routing by ref.
     speed: 0=walk, 1=jog (default), 2=run.
     akSandboxOverride: optional Package applied on arrival instead of the
     default SandboxPackage property. Lets the caller swap in a destination-
     specific sandbox (e.g. SeversHearth's CampSandboxPackage so the NPC
     joins the campfire crowd rather than sandboxing generically).}

    If akNPC == None
        DebugMsg("TravelNPCToReference: None actor")
        Return false
    EndIf
    If akNPC.IsDead()
        DebugMsg("TravelNPCToReference: dead actor")
        Return false
    EndIf
    If akDestination == None
        DebugMsg("TravelNPCToReference: None destination")
        Return false
    EndIf

    EnsureReady()

    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf

    ; Door → interior marker (same handling as TravelToPlace).
    ObjectReference finalDest = akDestination
    If akDestination.GetBaseObject().GetType() == 29
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(akDestination)
        If interiorMarker != None
            finalDest = interiorMarker
        EndIf
        If akDestination.IsLocked()
            akDestination.Lock(false)
        EndIf
    EndIf

    Package travelPkg = GetTravelPackageForSpeed(speed)
    If travelPkg == None
        DebugMsg("TravelNPCToReference: no package for speed " + speed)
        Return false
    EndIf

    CancelTravel(akNPC)

    DisengageOverridesForTravel(akNPC, "TravelNPCToReference")

    Int slot = FindFreeSlot()
    If slot < 0
        DebugMsg("TravelNPCToReference: no free slots")
        Return false
    EndIf

    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias == None
        Return false
    EndIf

    If waitHours <= 0.0
        waitHours = DefaultWaitTime
    EndIf
    waitHours = ClampFloat(waitHours, MinWaitTime, MaxWaitTime)
    Float waitUntil = Utility.GetCurrentGameTime() + (waitHours / 24.0)

    theAlias.ForceRefTo(akNPC)

    If stopFollowing
        DismissFollower(akNPC)
    EndIf

    Int handle = SeverActionsNativeExt.Travel_Begin(akNPC, finalDest, TravelTargetKeyword, ArrivalDistance, "slot_" + slot, TRAVEL_OPTIONS_LONGRANGE, 0, speed)
    If handle <= 0
        DebugMsg("TravelNPCToReference: orchestrator rejected")
        theAlias.Clear()
        Return false
    EndIf
    ; Phase 2: the Traveler_NN pool alias package (priority 106) drives the trip;
    ; the legacy override is applied ONLY as the pool-exhaustion fallback.
    If !SeverActionsNativeExt2.Travel_HasAlias(handle)
        ActorUtil.AddPackageOverride(akNPC, travelPkg, TravelPackagePriority, 1)
        akNPC.EvaluatePackage()
    EndIf

    SetSlotState(slot, 1)
    SetSlotSandbox(slot, akSandboxOverride)
    ; ALSO persist the arrival sandbox override in StorageUtil (per-actor, cosave-
    ; backed). The per-actor copy is the robust source OnArrived reads first.
    StorageUtil.SetFormValue(akNPC, "SeverTravel_SandboxOverride", akSandboxOverride)
    ; Use a synthetic place label since ref-targeted travel has no user-facing name.
    String label = "dispatch_target"
    If finalDest != None
        Form base = finalDest.GetBaseObject()
        If base != None
            String baseName = base.GetName()
            If baseName != ""
                label = baseName
            EndIf
        EndIf
    EndIf
    SetSlotPlaceName(slot, label)
    SetSlotDest(slot, finalDest)
    SetSlotWaitDeadline(slot, waitUntil)
    SetSlotSpeed(slot, speed)
    SetSlotHandle(slot, handle)

    ; See TravelToPlace: register as a tracked traveler so OrphanCleanup doesn't
    ; tear down the active travel LinkedRef as an orphan. Cleared in ClearSlot.
    SeverActionsNative.OrphanCleanup_RegisterTraveler(akNPC)

    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "traveling")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Destination", label)
    SeverActionsNative.Native_SetTravelState(akNPC, "traveling", label)
    StorageUtil.SetFloatValue(akNPC, "SeverTravel_WaitUntil", waitUntil)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Slot", slot)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", speed)

    ChronoArm(UpdateInterval)
    Return true
EndFunction

; =============================================================================
; ARRIVAL / WAITING
; =============================================================================

Function OnArrived(Int slot, Actor akNPC, String placeName)
    {Called from OnTravelComplete with status "arrived". Apply sandbox and
     transition the slot to waiting state.

     Traveled-together: some players escort the traveler the whole way. If the
     player is right there at the moment of arrival, entering the waiting/greet
     flow reads absurd (the NPC greets them as if they had been waiting).
     Complete immediately with an arrived-together beat instead. A near-miss
     (player a few steps behind, or trailing through a load door) is covered by
     the grace window in CheckWaitingSlot via the arrival timestamp below.}

    RemoveAllTravelPackages(akNPC)

    Bool waitsForPlayer = StorageUtil.GetIntValue(akNPC, "SeverTravel_WaitForPlayer", 1) == 1
    If waitsForPlayer
        Actor playerRef = Game.GetPlayer()
        Bool together = false
        If playerRef
            If playerRef.GetParentCell() == akNPC.GetParentCell()
                together = akNPC.GetDistance(playerRef) <= 2500.0
            ElseIf playerRef.GetWorldSpace() != None && playerRef.GetWorldSpace() == akNPC.GetWorldSpace()
                together = akNPC.GetDistance(playerRef) <= 2500.0
            EndIf
        EndIf
        If together
            StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "complete")
            SeverActionsNative.Native_SetTravelState(akNPC, "complete", "")
            StorageUtil.SetStringValue(akNPC, "SeverTravel_Result", "arrived_together")
            SkyrimNetApi.DirectNarration("*" + akNPC.GetDisplayName() + " arrives at " + placeName + " with " + playerRef.GetDisplayName() + " at their side*", akNPC, playerRef)
            NotifyPlayer(akNPC.GetDisplayName() + " arrived at " + placeName)
            ClearSlot(slot, true)
            Return
        EndIf
        ; Not together at arrival - stamp the moment so the greet can tell a
        ; player who catches up within a minute from one who shows up an hour
        ; later. Real-time; the reader guards against save/load resets.
        StorageUtil.SetFloatValue(akNPC, "SeverTravel_ArrivedRT", Utility.GetCurrentRealTime())
    EndIf

    If TravelTargetKeyword
        ObjectReference dest = GetSlotDest(slot)
        If dest != None
            SeverActionsNative.LinkedRef_Set(akNPC, dest, TravelTargetKeyword)
        EndIf
    EndIf

    ; Sandbox override (per-slot) wins over the default SandboxPackage so a
    ; camp-bound follower joins the campfire crowd rather than picking SA's
    ; generic sandbox. Falls through to SandboxPackage when no override set.
    ; StorageUtil per-actor copy first, per-slot cosave key second, default
    ; SandboxPackage last. This is what makes the camp sandbox apply on arrival.
    Package sandboxToApply = StorageUtil.GetFormValue(akNPC, "SeverTravel_SandboxOverride") as Package
    If sandboxToApply == None
        sandboxToApply = GetSlotSandbox(slot)
    EndIf
    If sandboxToApply == None
        sandboxToApply = SandboxPackage
    EndIf
    If sandboxToApply
        ActorUtil.AddPackageOverride(akNPC, sandboxToApply, TravelPackagePriority, 1)
    EndIf
    akNPC.EvaluatePackage()

    SetSlotState(slot, 2)
    SetSlotHandle(slot, 0)
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "waiting")
    SeverActionsNative.Native_SetTravelState(akNPC, "waiting", placeName)

    NotifyPlayer(akNPC.GetDisplayName() + " arrived at " + placeName)
    ChronoArm(UpdateInterval)
EndFunction

Function CheckWaitingSlot(Int slot)
    {Polls a waiting slot for player arrival or timeout. The greet-on-approach
     flow uses real-time elapsed for the SkyrimNet dialogue gap; we sanity-
     check it against save/load resets.}

    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias == None
        ClearSlot(slot)
        Return
    EndIf

    Actor npc = theAlias.GetActorReference()
    If npc == None || npc.IsDead()
        ClearSlot(slot)
        Return
    EndIf

    Float currentTime = Utility.GetCurrentGameTime()
    Float deadline = GetSlotWaitDeadline(slot)
    String placeName = GetSlotPlaceName(slot)

    ; Self-errand travelers (waitForPlayer=false) are not waiting for anyone:
    ; no greet-on-approach, no spoken-to completion, no patience framing.
    ; Their stay simply ends at the deadline. Default 1 keeps every legacy
    ; and external caller (Hearth, kidnap slot-fallback) on the old behavior.
    If StorageUtil.GetIntValue(npc, "SeverTravel_WaitForPlayer", 1) == 0
        If currentTime >= deadline
            OnStayComplete(slot, npc)
        EndIf
        Return
    EndIf

    ; --- Check 1: external SpokenTo flag ---
    Bool spokenTo = StorageUtil.GetIntValue(npc, "SeverTravel_SpokenTo") as Bool
    If spokenTo
        StorageUtil.UnsetIntValue(npc, "SeverTravel_SpokenTo")
        StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
        OnPlayerArrived(slot, npc)
        Return
    EndIf

    ; --- Check 2: detect player proximity, trigger SkyrimNet greeting ---
    Actor player = Game.GetPlayer()
    If player != None
        Cell playerCell = player.GetParentCell()
        Cell npcCell = npc.GetParentCell()

        If playerCell != None && npcCell != None && playerCell == npcCell
            Float dist = npc.GetDistance(player as ObjectReference)
            Int greetedState = StorageUtil.GetIntValue(npc, "SeverTravel_Greeted")

            If greetedState == 0 && dist <= 300.0 && npc.HasLOS(player as ObjectReference)
                StorageUtil.SetIntValue(npc, "SeverTravel_Greeted", 1)
                StorageUtil.SetFloatValue(npc, "SeverTravel_GreetTime", Utility.GetCurrentRealTime())
                ; Grace window: a player who walks in within a minute of the
                ; NPC's own arrival almost certainly traveled WITH them (a few
                ; steps behind, a load door between them) - greet as catching
                ; up, not as if the NPC had been camped here waiting. Bogus
                ; elapsed (save/load reset real time) falls back to waited.
                Float arrivedRT = StorageUtil.GetFloatValue(npc, "SeverTravel_ArrivedRT", -1.0)
                Float sinceArrival = -1.0
                If arrivedRT >= 0.0
                    sinceArrival = Utility.GetCurrentRealTime() - arrivedRT
                EndIf
                String narration
                If sinceArrival >= 0.0 && sinceArrival <= 60.0
                    narration = "*" + npc.GetDisplayName() + " reaches " + placeName + " just ahead of " + player.GetDisplayName() + ", and turns as they catch up*"
                Else
                    narration = "*" + npc.GetDisplayName() + " spots " + player.GetDisplayName() + " coming into " + placeName + " and moves to meet them*"
                EndIf
                SkyrimNetApi.DirectNarration(narration, npc, player)
                Return
            EndIf

            If greetedState == 1
                Float greetTime = StorageUtil.GetFloatValue(npc, "SeverTravel_GreetTime")
                Float elapsed = Utility.GetCurrentRealTime() - greetTime

                ; GetCurrentRealTime is process-uptime — it resets on game load.
                ; A save/load between greet and arrival makes elapsed negative or
                ; bogus-large; re-seed and try again next tick.
                If elapsed < 0.0 || elapsed > 600.0
                    StorageUtil.SetFloatValue(npc, "SeverTravel_GreetTime", Utility.GetCurrentRealTime())
                    Return
                EndIf

                If elapsed >= 12.0
                    Int queueSize = SkyrimNetApi.GetSpeechQueueSize()
                    If queueSize == 0
                        StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
                        StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
                        OnPlayerArrived(slot, npc)
                        Return
                    EndIf
                EndIf
            EndIf
        Else
            ; Player left the cell — reset greet state so it fires again on return.
            If StorageUtil.GetIntValue(npc, "SeverTravel_Greeted") > 0
                StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
                StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
            EndIf
        EndIf
    EndIf

    ; --- Check 3: timeout ---
    If currentTime >= deadline
        StorageUtil.UnsetIntValue(npc, "SeverTravel_Greeted")
        StorageUtil.UnsetFloatValue(npc, "SeverTravel_GreetTime")
        OnWaitTimeout(slot, npc)
    EndIf
EndFunction

Function OnPlayerArrived(Int slot, Actor akNPC)
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "complete")
    SeverActionsNative.Native_SetTravelState(akNPC, "complete", "")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Result", "player_arrived")
    ; No HUD line here - the greet DirectNarration in CheckWaitingSlot already
    ; played the moment they spotted the player (field feedback: the old
    ; "is glad to see you!" notification read as canned and broke the scene).
    DebugMsg(akNPC.GetDisplayName() + " travel completed - player arrived")
    ClearSlot(slot, true)
EndFunction

Function NotifyTravelSpokenTo(Actor akNPC)
    {External-facing: tag a traveling NPC as having been spoken to. The next
     CheckWaitingSlot tick will complete the travel.}
    If akNPC == None
        Return
    EndIf
    Int slot = FindSlotByActor(akNPC)
    If slot >= 0 && GetSlotState(slot) == 2
        StorageUtil.SetIntValue(akNPC, "SeverTravel_SpokenTo", 1)
    EndIf
EndFunction

Function OnStayComplete(Int slot, Actor akNPC)
    {A self-errand traveler's stay ran out - no waiting drama, they finish
     their business and drift back to their normal life. restoreFollower
     false mirrors OnWaitTimeout: whoever wants them back re-summons.}
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "complete")
    SeverActionsNative.Native_SetTravelState(akNPC, "complete", "")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Result", "stay_ended")
    NotifyPlayer(akNPC.GetDisplayName() + " has finished their business at " + GetSlotPlaceName(slot))
    ClearSlot(slot, false)
EndFunction

Function OnWaitTimeout(Int slot, Actor akNPC)
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "timeout")
    SeverActionsNative.Native_SetTravelState(akNPC, "timeout", "")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Result", "timeout")
    NotifyPlayer(akNPC.GetDisplayName() + "'s patience ran out!")
    ClearSlot(slot, false)
EndFunction

; =============================================================================
; UPDATE LOOP — waiting slots, ambush approach/standoff, departing thugs, courier queue
; =============================================================================

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick - replaces the FORM-keyed
     RegisterForSingleUpdate (canonical explanation: the Chronometer block in
     SeverActionsNativeExt2.psc + the CLAUDE.md lesson). Event name AND
     callback name are unique per script - both, always. Re-arm replaces the
     pending tick; ticks do NOT survive save/load (load paths re-arm); at
     most one already-in-flight wake can land after Cancel/Clear, so keep
     the handler state-guarded.}
    RegisterForModEvent("SeverActions_Tick_Travel", "OnChronoTick_Travel")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Travel", afSeconds)
EndFunction

Event OnChronoTick_Travel(String eventName, String strArg, Float numArg, Form sender)
    ; Ambush approach poll — open the standoff once the pack reaches the player.
    If AmbushApproaching
        CheckAmbushApproach()
    EndIf

    ; While the standoff is live, keep the thugs weapon-out and alert. The AI
    ; re-sheathes an Aggression-0 actor that perceives no threat, so we re-assert
    ; the combat-ready stance every tick until the standoff resolves.
    If AmbushActive
        ReassertThugStance()
    EndIf

    ; Despawn walked-off ambush thugs once out of sight.
    ProcessDepartingThugs()
    Bool hasDeparting = StorageUtil.FormListCount(self, "SeverTravel_DepartingThugs") > 0

    ; Courier letters deferred while the player was indoors.
    Bool hasQueuedCourier = ProcessCourierQueue()

    Bool hasWaiting = false
    Int i = 0
    While i < MAX_SLOTS
        If GetSlotState(i) == 2
            CheckWaitingSlot(i)
            hasWaiting = true
        EndIf
        i += 1
    EndWhile

    ; Keep ticking fast while a pack is approaching (snappy arrival) or holding the
    ; standoff (to keep weapons out); otherwise the normal waiting-slot cadence.
    If AmbushApproaching
        ChronoArm(1.0)
    ElseIf AmbushActive
        ChronoArm(2.0)
    ElseIf hasWaiting || hasDeparting || hasQueuedCourier
        ChronoArm(UpdateInterval)
    EndIf
EndEvent

Function ReassertThugStance()
    {Keep every live thug weapon-out + alert AND following the player for the whole
     standoff. Cheap guards (IsWeaponDrawn / HasPackage) skip the redundant calls.}
    Int i = 0
    While i < AmbushThugs.Length
        Actor t = AmbushThugs[i]
        If t != None && !t.IsDead()
            If !t.IsWeaponDrawn()
                t.SetAlert(true)
                t.DrawWeapon()
            EndIf
            ; Guarantee they keep following 100% of the time - re-register if
            ; SkyrimNet ever drops the FollowPlayer package out from under them.
            If !SkyrimNetApi.HasPackage(t, "FollowPlayer")
                SkyrimNetApi.RegisterPackage(t, "FollowPlayer", 100, 0, true)
                t.EvaluatePackage()
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; SLOT MANAGEMENT
; =============================================================================

ReferenceAlias Function GetAliasForSlot(Int slot)
    If slot == 0
        Return TravelAlias00
    ElseIf slot == 1
        Return TravelAlias01
    ElseIf slot == 2
        Return TravelAlias02
    ElseIf slot == 3
        Return TravelAlias03
    ElseIf slot == 4
        Return TravelAlias04
    EndIf
    Return None
EndFunction

Int Function FindFreeSlot()
    Int i = 0
    While i < MAX_SLOTS
        If GetSlotState(i) == 0
            Return i
        EndIf
        i += 1
    EndWhile
    Return -1
EndFunction

Int Function FindSlotByActor(Actor akNPC)
    If akNPC == None
        Return -1
    EndIf
    Int i = 0
    While i < MAX_SLOTS
        If GetSlotState(i) != 0
            ReferenceAlias theAlias = GetAliasForSlot(i)
            If theAlias && theAlias.GetActorReference() == akNPC
                Return i
            EndIf
        EndIf
        i += 1
    EndWhile
    Return -1
EndFunction

Function ClearSlot(Int slot, Bool restoreFollower = false)
    {Tear down a slot. Cancels any active orchestrator handle, removes packages,
     restores follower if requested, clears all SeverTravel_* StorageUtil keys,
     and releases the alias.}

    If slot < 0 || slot >= MAX_SLOTS
        Return
    EndIf

    Int handle = GetSlotHandle(slot)
    If handle > 0
        SeverActionsNativeExt.Travel_Cancel(handle)
    EndIf

    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias
        Actor npc = theAlias.GetActorReference()
        If npc
            RemoveAllTravelPackages(npc)
            If SandboxPackage
                ActorUtil.RemovePackageOverride(npc, SandboxPackage)
            EndIf
            ; Also remove any per-slot sandbox override (set by
            ; TravelNPCToReference callers like SeversHearth's GoToCamp).
            ; Safe-call — RemovePackageOverride no-ops if the actor never had it.
            Package overridePkg = GetSlotSandbox(slot)
            If overridePkg
                ActorUtil.RemovePackageOverride(npc, overridePkg)
            EndIf
            If TravelTargetKeyword
                SeverActionsNative.LinkedRef_Clear(npc, TravelTargetKeyword)
            EndIf
            ; Stop OrphanCleanup tracking this NPC as an active traveler (paired
            ; with the OrphanCleanup_RegisterTraveler at travel start).
            SeverActionsNative.OrphanCleanup_UnregisterTraveler(npc)

            If restoreFollower
                Bool wasFollower = StorageUtil.GetIntValue(npc, "SeverTravel_WasFollower") as Bool
                If wasFollower
                    ReinstateFollower(npc)
                EndIf
            EndIf

            ClearTravelStorage(npc)
            npc.EvaluatePackage()
        EndIf
        theAlias.Clear()
    EndIf

    SetSlotState(slot, 0)
    SetSlotPlaceName(slot, "")
    SetSlotDest(slot, None)
    SetSlotWaitDeadline(slot, 0.0)
    SetSlotSpeed(slot, 0)
    SetSlotHandle(slot, 0)
    SetSlotSandbox(slot, None)
EndFunction

Function ClearTravelStorage(Actor akNPC)
    {Single source of truth for tearing down the SeverTravel_* StorageUtil keys.
     ClearSlot and any cleanup paths route through here so we don't drift.}
    StorageUtil.UnsetStringValue(akNPC, "SeverTravel_State")
    StorageUtil.UnsetStringValue(akNPC, "SeverTravel_Destination")
    SeverActionsNative.Native_SetTravelState(akNPC, "", "")
    StorageUtil.UnsetStringValue(akNPC, "SeverTravel_Result")
    StorageUtil.UnsetFloatValue(akNPC, "SeverTravel_WaitUntil")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_Slot")
    StorageUtil.UnsetFormValue(akNPC, "SeverTravel_SandboxOverride")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_WasFollower")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_Speed")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_SpokenTo")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_Greeted")
    StorageUtil.UnsetFloatValue(akNPC, "SeverTravel_GreetTime")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_WaitForPlayer")
    StorageUtil.UnsetFloatValue(akNPC, "SeverTravel_ArrivedRT")
    StorageUtil.UnsetFloatValue(akNPC, "SeverTravel_PendingWait")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_PendingStopFollow")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_PendingSpeed")
    StorageUtil.UnsetIntValue(akNPC, "SeverTravel_PendingWaitForPlayer")
EndFunction

Function ForceResetAllSlots(Bool restoreFollowers = true)
    {Emergency reset — cancel every orchestrator handle and tear down every slot.}
    DebugMsg("=== FORCE RESET ALL SLOTS ===")
    NotifyPlayer("Resetting all travel slots...")
    Int i = 0
    While i < MAX_SLOTS
        ClearSlot(i, restoreFollowers)
        i += 1
    EndWhile
    DebugMsg("=== FORCE RESET COMPLETE ===")
    NotifyPlayer("All travel slots have been reset.")
EndFunction

Int Function GetActiveTravelCount()
    Int count = 0
    Int i = 0
    While i < MAX_SLOTS
        If GetSlotState(i) != 0
            count += 1
        EndIf
        i += 1
    EndWhile
    Return count
EndFunction

Int Function GetSlotState(Int slot)
    If slot < 0 || slot >= MAX_SLOTS
        Return 0
    EndIf
    Return StorageUtil.GetIntValue(None, "SeverTravel_SlotState_" + slot, 0)
EndFunction

Function ClearSlotFromMCM(Int slot, Bool restoreFollower = true)
    If slot < 0 || slot >= MAX_SLOTS
        Return
    EndIf
    If GetSlotState(slot) == 0
        Return
    EndIf
    ReferenceAlias theAlias = GetAliasForSlot(slot)
    If theAlias
        Actor npc = theAlias.GetActorReference()
        If npc
            NotifyPlayer("Clearing travel for " + npc.GetDisplayName())
        EndIf
    EndIf
    ClearSlot(slot, restoreFollower)
EndFunction

String Function GetSlotDestination(Int slot)
    If slot < 0 || slot >= MAX_SLOTS
        Return ""
    EndIf
    Return GetSlotPlaceName(slot)
EndFunction

String Function GetSlotStatusText(Int slot)
    If slot < 0 || slot >= MAX_SLOTS
        Return "Invalid"
    EndIf
    If GetSlotState(slot) == 1
        If GetSlotPlaceName(slot) != ""
            Return "Traveling: " + GetSlotPlaceName(slot)
        EndIf
        Return "Traveling (unknown)"
    ElseIf GetSlotState(slot) == 2
        If GetSlotPlaceName(slot) != ""
            Return "Waiting: " + GetSlotPlaceName(slot)
        EndIf
        Return "Waiting (unknown)"
    ElseIf GetSlotState(slot) != 0
        Return "UNKNOWN: " + GetSlotState(slot)
    EndIf
    Return "Empty"
EndFunction

; =============================================================================
; CANCEL
; =============================================================================

Function CancelTravel(Actor akNPC, Bool restoreFollower = true)
    {Cancel travel for one NPC. Routes through the slot if found; falls back to
     orchestrator-by-actor to catch any non-slot session.}
    If akNPC == None
        Return
    EndIf
    Int slot = FindSlotByActor(akNPC)
    If slot >= 0
        ClearSlot(slot, restoreFollower)
    Else
        ; Defensive — catch any stray orchestrator session not tracked locally.
        SeverActionsNativeExt.Travel_CancelByActor(akNPC)
    EndIf
EndFunction

Function CancelAllTravel(Bool restoreFollowers = true)
    Int i = 0
    While i < MAX_SLOTS
        If GetSlotState(i) != 0
            ClearSlot(i, restoreFollowers)
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; SPEED CONTROL
; =============================================================================

Bool Function SetTravelSpeed(Actor akNPC, Int speed)
    {Change speed mid-journey. ACTOR-KEYED so it works for pool-only journeys
     too (no legacy slot required — the Actions-page travel-pace bug). The native
     Travel_SetSpeedByActor re-bands the Traveler_NN pool alias (unloaded pace)
     and updates the catch-up estimator; when a legacy slot exists we ALSO swap
     the loaded package override so the on-screen pace changes immediately.}
    If akNPC == None
        Return false
    EndIf
    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf

    ; --- Pool re-band (native): the Traveler_NN alias package IS the pace, so
    ;     this moves the traveler to the new speed band and BOTH the loaded and
    ;     unloaded leg follow. Works with or without a legacy slot. ---
    Bool applied = SeverActionsNativeExt2.Travel_SetSpeedByActor(akNPC, speed)

    ; --- Legacy slot bookkeeping + the pool-EXHAUSTION override case only ---
    Int slot = FindSlotByActor(akNPC)
    If slot >= 0 && GetSlotState(slot) == 1
        If GetSlotSpeed(slot) != speed
            ; Only a pool-exhausted traveler (override fallback, no alias) needs a
            ; package swap here — an aliased traveler was already re-banded above,
            ; and adding an override on top would reintroduce the two-package split.
            Int handle = GetSlotHandle(slot)
            If handle > 0 && !SeverActionsNativeExt2.Travel_HasAlias(handle)
                Package newPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(speed)
                If newPkg != None
                    Package oldPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(GetSlotSpeed(slot))
                    If oldPkg != None
                        ActorUtil.RemovePackageOverride(akNPC, oldPkg)
                    EndIf
                    ActorUtil.AddPackageOverride(akNPC, newPkg, TravelPackagePriority, 1)
                    akNPC.EvaluatePackage()
                EndIf
            EndIf
            SetSlotSpeed(slot, speed)
            StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", speed)
        EndIf
        applied = true
    EndIf

    If !applied
        DebugMsg("SetTravelSpeed: no live journey for " + akNPC.GetDisplayName())
    EndIf
    Return applied
EndFunction

Bool Function SetTravelSpeedNatural(Actor akNPC, String speedText)
    Return SetTravelSpeed(akNPC, SeverActionsNativeExt.Travel_ParseSpeedFromText(speedText))
EndFunction

Package Function GetTravelPackageForSpeed(Int speed)
    Package pkg = SeverActionsNativeExt.Travel_GetSpeedPackage(speed)
    If pkg == None
        ; Self-heal: an empty native speed registry means RegisterSpeedPackages()
        ; never ran this session — happens on older saves where the script's
        ; OnPlayerLoadGame doesn't re-fire (stale Papyrus load-event binding), so
        ; travel silently no-ops ("no package for speed"). The Package properties
        ; are ESP-set, so re-register from them and retry. Idempotent + cheap;
        ; once it runs, the native registry persists for all later travel calls.
        RegisterSpeedPackages()
        pkg = SeverActionsNativeExt.Travel_GetSpeedPackage(speed)
    EndIf
    Return pkg
EndFunction

Function RemoveAllTravelPackages(Actor akNPC)
    If TravelPackage
        ActorUtil.RemovePackageOverride(akNPC, TravelPackage)
    EndIf
    If TravelPackageWalk
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageWalk)
    EndIf
    If TravelPackageJog
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageJog)
    EndIf
    If TravelPackageRun
        ActorUtil.RemovePackageOverride(akNPC, TravelPackageRun)
    EndIf
    ; Also remove the SeverTravelToAction* family we actually register now (walk=07C068
    ; isn't covered by the legacy properties above — jog/run/default overlap with them).
    Package realWalk = Game.GetFormFromFile(0x07C068, "SeverActions.esp") as Package
    If realWalk
        ActorUtil.RemovePackageOverride(akNPC, realWalk)
    EndIf
    Package realDefault = Game.GetFormFromFile(0x076F60, "SeverActions.esp") as Package
    If realDefault
        ActorUtil.RemovePackageOverride(akNPC, realDefault)
    EndIf
EndFunction

String Function GetSpeedName(Int speed)
    Return SeverActionsNativeExt.Travel_GetSpeedName(speed)
EndFunction

Int Function GetTravelSpeed(Actor akNPC)
    If akNPC == None
        Return -1
    EndIf
    Int slot = FindSlotByActor(akNPC)
    If slot < 0
        Return -1
    EndIf
    Return GetSlotSpeed(slot)
EndFunction

; =============================================================================
; FOLLOWERS
; =============================================================================

Keyword FollowerFollowKWCache

Keyword Function GetFollowerFollowKW()
    {SeverActions_FollowerFollowKW (0x0EB706) — the linked-ref keyword the SA follow
     alias package chases. Clearing it parks the follower so travel can take over.}
    If !FollowerFollowKWCache
        FollowerFollowKWCache = Game.GetFormFromFile(0x0EB706, "SeverActions.esp") as Keyword
    EndIf
    Return FollowerFollowKWCache
EndFunction

Function DismissFollower(Actor akNPC)
    Bool isFollower = akNPC.IsPlayerTeammate()
    ; Track-only followers (NFF / custom-AI / nwsIgnoreToken) have an external
    ; framework that OWNS their teammate flag — toggling it invites that
    ; framework (and our own TeammateMonitor) to treat the trip as a real
    ; dismissal. Leave their flag alone and record WasFollower=0 so
    ; ReinstateFollower won't force it back on arrival either.
    SeverActions_FollowerManager fm = (self as Quest) as SeverActions_FollowerManager
    Bool trackOnly = fm && fm.IsTrackOnlyFollower(akNPC)
    If trackOnly
        StorageUtil.SetIntValue(akNPC, "SeverTravel_WasFollower", 0)
    Else
        StorageUtil.SetIntValue(akNPC, "SeverTravel_WasFollower", isFollower as Int)
    EndIf
    If isFollower
        If !trackOnly
            akNPC.SetPlayerTeammate(false)
        EndIf
        ; SetPlayerTeammate(false) alone is NOT enough — the SA follow alias package
        ; keeps chasing the player via the FollowerFollowKW linked-ref, which outranks
        ; the travel package, so she never paths (the orchestrator then leapfrogs her,
        ; which looks like teleporting). Clear the follow link so travel is unopposed.
        ; (Clearing is safe for track-only too — the link is SA-owned state and a
        ; no-op when SA never set it.)
        Keyword followKw = GetFollowerFollowKW()
        If followKw
            SeverActionsNative.LinkedRef_Clear(akNPC, followKw)
        EndIf
        akNPC.EvaluatePackage()
    EndIf
EndFunction

Function ReinstateFollower(Actor akNPC)
    ; Restore teammate + re-point the follow package at the player (we cleared the
    ; FollowerFollowKW link when dismissing for the trip).
    Keyword followKw = GetFollowerFollowKW()
    If followKw
        SeverActionsNative.LinkedRef_Set(akNPC, Game.GetPlayer(), followKw)
    EndIf
    akNPC.SetPlayerTeammate(true)
    akNPC.EvaluatePackage()
EndFunction

; =============================================================================
; UTILITIES
; =============================================================================

Function DebugMsg(String msg)
    Debug.Trace("SeverTravel: " + msg)
    If EnableDebugMessages
        Debug.Notification("Travel: " + msg)
    EndIf
EndFunction

Function NotifyPlayer(String msg)
    Debug.Trace("SeverTravel: " + msg)
    Debug.Notification(msg)
EndFunction

Float Function ClampFloat(Float value, Float minVal, Float maxVal)
    If value < minVal
        Return minVal
    ElseIf value > maxVal
        Return maxVal
    EndIf
    Return value
EndFunction

; =============================================================================
; DEBUG / TESTING
; =============================================================================

Function TestMarkerResolution(String placeName)
    DebugMsg("Testing resolution for: " + placeName)
    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("FAIL: LocationResolver not initialized")
        Return
    EndIf
    ObjectReference marker = SeverActionsNative.ResolveDestination(Game.GetPlayer(), placeName)
    If marker == None
        DebugMsg("FAIL: Could not resolve '" + placeName + "'")
        Return
    EndIf
    DebugMsg("SUCCESS: " + marker)
EndFunction

Function ShowStatus()
    DebugMsg("=== Travel System Status ===")
    DebugMsg("LocationResolver ready: " + SeverActionsNative.IsLocationResolverReady())
    DebugMsg("Orchestrator active: " + SeverActionsNativeExt.Travel_GetActiveCount())
    Int i = 0
    Int activeCount = 0
    While i < MAX_SLOTS
        If GetSlotState(i) != 0
            activeCount += 1
            ReferenceAlias theAlias = GetAliasForSlot(i)
            String npcName = "None"
            If theAlias
                Actor npc = theAlias.GetActorReference()
                If npc
                    npcName = npc.GetDisplayName()
                EndIf
            EndIf
            String stateStr = "unknown"
            If GetSlotState(i) == 1
                stateStr = "traveling"
            ElseIf GetSlotState(i) == 2
                stateStr = "waiting"
            EndIf
            DebugMsg("Slot " + i + ": " + npcName + " - " + stateStr + " @ " + GetSlotPlaceName(i) + " (handle=" + GetSlotHandle(i) + ")")
        EndIf
        i += 1
    EndWhile
    DebugMsg("Active slots: " + activeCount + "/" + MAX_SLOTS)
EndFunction

Bool Function IsNPCTraveling(Actor akNPC)
    Return FindSlotByActor(akNPC) >= 0
EndFunction

String Function GetNPCTravelState(Actor akNPC)
    Int slot = FindSlotByActor(akNPC)
    If slot < 0
        Return ""
    EndIf
    If GetSlotState(slot) == 1
        Return "traveling"
    ElseIf GetSlotState(slot) == 2
        Return "waiting"
    EndIf
    Return ""
EndFunction
