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
{Default travel package (walk speed) - also used as fallback.}

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

Int Property TravelPackagePriority = 100 Auto
{Priority for travel/sandbox package overrides.}

Float Property DefaultWaitTime = 48.0 Auto
Float Property MinWaitTime = 6.0 Auto
Float Property MaxWaitTime = 168.0 Auto

Bool Property EnableDebugMessages = false Auto

; =============================================================================
; CONSTANTS
; =============================================================================

Int Property MAX_SLOTS = 5 AutoReadOnly

; Orchestrator option bitfield (see SeverActionsNative.psc TRAVEL ORCHESTRATOR
; comment block). 4 = kTravelOpt_AbortOnDegraded (recommended on).
Int Property TRAVEL_OPTIONS_DEFAULT = 4 AutoReadOnly
; Named-place travel is usually long-range: the destination lives in an UNLOADED cell,
; where the orchestrator's CanNavigateToPosition pre-flight can't find a path and
; false-rejects the whole trip ("Begin pre-flight rejected -> no travel"). 4|8 adds
; kTravelOpt_SkipPreflight — the marker is already validated by ResolvePlace, and the
; orchestrator's leapfrog/teleport recovery is what carries a cross-cell journey.
Int Property TRAVEL_OPTIONS_LONGRANGE = 12 AutoReadOnly

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

; GetSlotState is the existing public accessor (further down) — reused, not duplicated.
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
    RegisterForSingleUpdate(UpdateInterval)
EndEvent

Event OnPlayerLoadGame()
    DebugMsg("OnPlayerLoadGame")

    ; Slot state is StorageUtil-backed now — no member arrays to initialize/heal.
    RegisterEvents()
    RegisterSpeedPackages()
    RecoverExistingTravelers()
    ; A standoff that was live when this save was made can't survive a reload (the
    ; native ambush-thug set is in-memory only), so tear it down cleanly instead of
    ; stranding the player with unresolvable neutral thugs.
    AbandonAmbushOnLoad()
    RegisterForSingleUpdate(UpdateInterval)
EndEvent

Function RegisterEvents()
    ; Orchestrator completion + PrismaUI controls. All ModEvent-based —
    ; DispatchMethodCall silently fails for cross-script signaling.
    RegisterForModEvent("SeverActions_TravelComplete", "OnTravelComplete")
    RegisterForModEvent("SeverActions_PrismaClearTravel", "OnPrismaClearTravel")
    RegisterForModEvent("SeverActions_PrismaResetTravel", "OnPrismaResetTravel")
    ; Non-pausing travel popup → player-confirmed destination starts the trip.
    RegisterForModEvent("SeverActions_TravelPromptResult", "OnTravelPromptResult")
    EnsureCourierEvents()
EndFunction

Function EnsureCourierEvents()
    {Idempotent registration for the Enterprises courier events. Exposed so a
     reliably-loaded caller (the MCM) can guarantee they're registered even on
     saves where this quest's OnPlayerLoadGame didn't re-fire.}
    RegisterForModEvent("SeverActions_VentureLetter", "OnVentureLetter")
    RegisterForModEvent("SeverActions_VentureAmbush", "OnVentureAmbush")
    ; Shared with the arrest flow — both gate on their own active state.
    RegisterForModEvent("SeverActions_PersuasionFailed", "OnAmbushPersuasionFailed")
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
    String subj   = SeverActionsNativeExt.Venture_LetterSubject(retainer)
    String body   = SeverActionsNativeExt.Venture_LetterBody(retainer)
    String reason = SeverActionsNativeExt.Venture_LetterReason(retainer)
    SeverActionsNativeExt.Venture_ClearLetter(retainer)
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
    If thugList == None
        Debug.Trace("[SeverActions] OnVentureAmbush: thug leveled list missing")
        Return
    EndIf

    ; Pull the lead thug's letter once (queued by the native, keyed by deserter).
    String subj = ""
    String body = ""
    If deserter != None
        subj = SeverActionsNativeExt.Venture_LetterSubject(deserter)
        body = SeverActionsNativeExt.Venture_LetterBody(deserter)
        SeverActionsNativeExt.Venture_ClearLetter(deserter)
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
    AmbushThugs = new Actor[5]
    Int n = 0
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
                If jog != None
                    ActorUtil.AddPackageOverride(t, jog, TravelPackagePriority, 1)
                EndIf
                t.EvaluatePackage()
            EndIf
            k += 1
        EndWhile
        RegisterForSingleUpdate(1.0)   ; poll for arrival
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
            SkyrimNetApi.RegisterPackage(t, "FollowPlayer", 100, 0, true)
            t.EvaluatePackage()
            SeverActionsNativeExt.Venture_RegisterAmbushThug(t)        ; gates the standoff actions
            SeverActionsNativeExt.Venture_StageThugDirective(t, AmbushDeserter)  ; hold/parley bias
        EndIf
        i += 1
    EndWhile

    ; Hand the lootable letter to the lead now that we know who it is (the
    ; first-arriver, promoted in CheckAmbushApproach) - so the thug who speaks is
    ; the one carrying the letter naming who sent them.
    If AmbushLead != None && AmbushLetterBody != ""
        SeverActionsNativeExt.Letter_DeliverToCourier(AmbushDeserter, AmbushLead, AmbushLetterSubj, AmbushLetterBody, "thug")
        AmbushLetterSubj = ""
        AmbushLetterBody = ""
    EndIf

    ; NOTE: the lead deliberately does NOT also get TalkToPlayer - it's already on
    ; FollowPlayer (above), and stacking two SkyrimNet packages causes the
    ; dual-package AI flicker the FollowerManager warns about. FollowPlayer keeps
    ; the lead on the player; the taunt below fires via DirectNarration regardless
    ; of which package is running.
    String taunt = SeverActionsNativeExt.Venture_AmbushTaunt(AmbushDeserter)
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
                ActorUtil.AddPackageOverride(t, leavePkg, TravelPackagePriority, 1)
            EndIf
            t.EvaluatePackage()
        EndIf
        i += 1
    EndWhile
    ; Reset bookkeeping ONLY — do NOT call ClearAmbushState here, it would strip
    ; the walk-off package we just applied.
    ResetAmbushBookkeeping()
    Debug.Trace("[SeverActions] Ambush: thugs stood down and walked off")
EndFunction

Function ThugAttack_Execute(Actor akActor)
    {SkyrimNet action: the thugs reject the player and attack.}
    If !AmbushActive
        Return
    EndIf
    ResolveAmbushCombat()
    Debug.Trace("[SeverActions] Ambush: thugs attack (rejected)")
EndFunction

Event OnAmbushPersuasionFailed(String asEventName, String asReason, Float afUnused, Form akSender)
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

Function ResetAmbushBookkeeping()
    {Reset the ambush flags + clear the standoff-action eligibility — WITHOUT
     touching packages (callers that just applied a resolve package, e.g. the
     stand-down walk-off, rely on this not stripping it).}
    SeverActionsNativeExt.Venture_ClearAmbushThugs()
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
     VentureMonitor) is in-memory only and is EMPTY after a load, so a standoff that
     was live when the save was made can never be resolved (the standoff actions go
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
     set up the slot arrays + event/speed-package registration, but on some existing
     saves OnPlayerLoadGame doesn't re-fire (stale Papyrus load-event binding),
     leaving the script uninitialized: slot arrays None ("Cannot access an element
     of a None array") and the native speed-package / OrphanCleanup-traveler
     registries empty. Running the same setup on first use makes travel work
     regardless of whether the load event fired. All idempotent + cheap.}
    ; Guard EVERY slot array individually (create only the missing ones, preserve
    ; populated ones). NOT InitializeSlotArrays() — that wipes all 7 fresh, which
    ; would erase live per-slot data if called mid-travel (e.g. from
    ; OnTravelComplete). On this class of save, some arrays persist non-None while
    ; others (added in later script versions) load as None, so a single SlotStates
    ; check isn't enough — each must be guarded.
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
                        Package pkg = SeverActionsNativeExt.Travel_GetSpeedPackage(GetSlotSpeed(i))
                        If pkg != None
                            ActorUtil.AddPackageOverride(npc, pkg, TravelPackagePriority, 1)
                            npc.EvaluatePackage()
                            DebugMsg("Recovered traveling slot " + i + " (handle=" + handle + ")")
                        EndIf
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
                    DebugMsg("Recovered waiting slot " + i)
                Else
                    ClearSlot(i, false)
                EndIf
            Else
                ; Empty/dead — zero out array entries without invoking ClearSlot
                ; (alias may already be empty; nothing to remove).
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

    ; (Thug-ambush arrival is detected by the OnUpdate proximity poll now, not the
    ; orchestrator — see CheckAmbushApproach. No "ambush" tag rides the orchestrator.)

    If StringUtil.GetLength(tag) < 6 || StringUtil.Substring(tag, 0, 5) != "slot_"
        Return  ; Not one of ours — Arrest or future callers use different tags.
    EndIf
    Int slot = (StringUtil.Substring(tag, 5, 0)) as Int
    If slot < 0 || slot >= MAX_SLOTS
        Return
    EndIf

    ; The completion event can fire on a save where the slot arrays loaded as
    ; None (OnPlayerLoadGame didn't run). Ensure they exist before any indexing
    ; below / in OnArrived. EnsureReady preserves populated arrays, so this does
    ; NOT wipe the in-flight slot data.
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
        ; CancelTravel/CancelAllTravel path already cleared the slot — nothing to do.
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

; =============================================================================
; COURIER — letter delivery NPC (Enterprises Phase 3)
;
; Spawns a WICourierNPC that walks up to the player and hands over a letter.
; Routing reuses the travel package override + orchestrator (tag "courier");
; the spawn + despawn live in the native CourierManager. The pending letter is
; stashed on the courier (StorageUtil) until it reaches the player, so a
; moving/interrupted delivery never loses the text.
; =============================================================================

Int Function DispatchCourier(Actor akSender, String asSubject, String asBody, String asReason)
    {Dispatch a courier to bring the player a letter. Short walk-up in the open;
     an at-your-side handoff indoors (cramped navmesh strands walkers). Returns
     1 on dispatch, 0 on failure.}
    EnsureReady()
    Actor player = Game.GetPlayer()
    If player == None || asBody == ""
        Return 0
    EndIf

    ; Spawn well out in the exterior so the courier actually travels in, rather
    ; than popping up next to the player. Indoors there's no room for that, so
    ; fall back to an at-side handoff.
    Float spawnDist = 3000.0
    Bool atSide = player.IsInInterior()
    If atSide
        spawnDist = 0.0
    EndIf

    Actor courier = SeverActionsNativeExt.Courier_Spawn(player, spawnDist)
    If courier == None
        DebugMsg("DispatchCourier: spawn failed")
        Return 0
    EndIf

    ; Stash the pending letter on the courier until it reaches the player.
    StorageUtil.SetFormValue(courier, "SA_CourierSender", akSender)
    StorageUtil.SetStringValue(courier, "SA_CourierSubject", asSubject)
    StorageUtil.SetStringValue(courier, "SA_CourierBody", asBody)
    StorageUtil.SetStringValue(courier, "SA_CourierReason", asReason)

    If atSide
        DeliverCourierLetter(courier)   ; already beside the player
        Return 1
    EndIf

    ; Travel in from afar. Apply the jog travel package + drive the orchestrator;
    ; OnTravelComplete fires when within arrival range and routes to
    ; DeliverCourierLetter, which forces a SkyrimNet TalkToPlayer package for the
    ; final approach + face, then hands the letter over. 300s cap; on timeout/abort
    ; OnTravelComplete still delivers (the letter is never lost).
    Package travelPkg = GetTravelPackageForSpeed(SPEED_JOG)
    If travelPkg != None
        ActorUtil.AddPackageOverride(courier, travelPkg, TravelPackagePriority, 1)
        courier.EvaluatePackage()
    EndIf
    SeverActionsNativeExt.Travel_Begin(courier, player, TravelTargetKeyword, 400.0, "courier", TRAVEL_OPTIONS_DEFAULT, 300, SPEED_JOG)
    DebugMsg("DispatchCourier: courier en route from afar")
    Return 1
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
        note = SeverActionsNativeExt.Letter_DeliverToCourier(sender, akCourier, subj, body, reason)
    EndIf

    ; End the travel package, then force SkyrimNet's TalkToPlayer package: the
    ; courier turns to the player, closes the last gap, and HOLDS there to speak
    ; — instead of stopping short on a default "stay" package. (SkyrimNet's own
    ; controller applies "TalkToPlayer" the same way for live dialogue.)
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
        String narration = "*A courier catches up to " + player.GetDisplayName() + ", a little out of breath, and holds out a sealed letter"
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

    Debug.Notification("A courier hands you a letter.")

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

Bool Function TravelToPlace(Actor akNPC, String placeName, Float waitHours = 0.0, Bool stopFollowing = true, Int speed = 0)
    {Action entry (executionFunctionName). Offers a non-pausing PrismaUI popup so the
     player can confirm or redirect the destination; on confirm the trip starts via
     DoTravelToPlace (routed through OnTravelPromptResult). Cancel/timeout/Escape =
     no travel. If PrismaUI isn't available, a popup's already up, or another view
     has focus, it falls back to travelling directly to the LLM's pick.}
    If akNPC == None
        Return false
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
        DebugMsg("TravelToPlace: opened travel popup for " + akNPC.GetDisplayName() + " (prefill '" + placeName + "')")
        Return true
    EndIf
    Return DoTravelToPlace(akNPC, placeName, waitHours, stopFollowing, speed)
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
    StorageUtil.UnsetFloatValue(npc, "SeverTravel_PendingWait")
    StorageUtil.UnsetIntValue(npc, "SeverTravel_PendingStopFollow")
    StorageUtil.UnsetIntValue(npc, "SeverTravel_PendingSpeed")
    DoTravelToPlace(npc, strArg, waitHours, stopFollowing, speed)
EndEvent

Bool Function DoTravelToPlace(Actor akNPC, String placeName, Float waitHours = 0.0, Bool stopFollowing = true, Int speed = 0)
    {Send an NPC to a named place. Returns true if travel started.
     speed: 0=walk, 1=jog, 2=run.}

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
        Return false
    EndIf

    ; If destination is a door to an interior, follow through to the interior marker.
    ObjectReference finalDest = destMarker
    If destMarker.GetBaseObject().GetType() == 29
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(destMarker)
        If interiorMarker != None
            finalDest = interiorMarker
            DebugMsg("Door resolved to interior marker for '" + placeName + "'")
        EndIf
        ; Unlock the door so AI pathfinding isn't blocked.
        If destMarker.IsLocked()
            destMarker.Lock(false)
        EndIf
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

    ActorUtil.AddPackageOverride(akNPC, travelPkg, TravelPackagePriority, 1)

    ; Hand off to the orchestrator. callbackTag carries the slot index so
    ; OnTravelComplete can route back here. options=4 enables degraded-state abort.
    Int handle = SeverActionsNativeExt.Travel_Begin(akNPC, finalDest, TravelTargetKeyword, ArrivalDistance, "slot_" + slot, TRAVEL_OPTIONS_LONGRANGE, 0, speed)
    If handle <= 0
        DebugMsg("TravelToPlace: orchestrator rejected (handle=0)")
        ActorUtil.RemovePackageOverride(akNPC, travelPkg)
        theAlias.Clear()
        Return false
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

    NotifyPlayer(akNPC.GetDisplayName() + " traveling to " + placeName)
    RegisterForSingleUpdate(UpdateInterval)
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

    ActorUtil.AddPackageOverride(akNPC, travelPkg, TravelPackagePriority, 1)

    Int handle = SeverActionsNativeExt.Travel_Begin(akNPC, finalDest, TravelTargetKeyword, ArrivalDistance, "slot_" + slot, TRAVEL_OPTIONS_LONGRANGE, 0, speed)
    If handle <= 0
        DebugMsg("TravelNPCToReference: orchestrator rejected")
        ActorUtil.RemovePackageOverride(akNPC, travelPkg)
        theAlias.Clear()
        Return false
    EndIf

    SetSlotState(slot, 1)
    SetSlotSandbox(slot, akSandboxOverride)
    ; ALSO persist the arrival sandbox override in StorageUtil (per-actor, cosave-
    ; backed). The SlotSandboxOverrides member array can come back None across the
    ; OnTravelComplete dispatch on fragile saves, losing the camp package; the
    ; StorageUtil copy is the robust source OnArrived reads.
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

    RegisterForSingleUpdate(UpdateInterval)
    Return true
EndFunction

; =============================================================================
; ARRIVAL / WAITING
; =============================================================================

Function OnArrived(Int slot, Actor akNPC, String placeName)
    {Called from OnTravelComplete with status "arrived". Apply sandbox and
     transition the slot to waiting state.}

    RemoveAllTravelPackages(akNPC)

    If TravelTargetKeyword
        ObjectReference dest = GetSlotDest(slot)
        If dest != None
            SeverActionsNative.LinkedRef_Set(akNPC, dest, TravelTargetKeyword)
        EndIf
    EndIf

    ; Sandbox override (per-slot) wins over the default SandboxPackage so a
    ; camp-bound follower joins the campfire crowd rather than picking SA's
    ; generic sandbox. Falls through to SandboxPackage when no override set.
    ; Read the per-slot override from StorageUtil first (robust), falling back to
    ; the member array, then to the default SandboxPackage. This is what makes the
    ; camp sandbox actually apply on arrival even when the member array reset.
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
    RegisterForSingleUpdate(UpdateInterval)
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
                String narration = "*" + npc.GetDisplayName() + " notices the player approaching and turns to greet them, having been waiting here in " + placeName + "*"
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
    NotifyPlayer(akNPC.GetDisplayName() + " is glad to see you!")
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

Function OnWaitTimeout(Int slot, Actor akNPC)
    StorageUtil.SetStringValue(akNPC, "SeverTravel_State", "timeout")
    SeverActionsNative.Native_SetTravelState(akNPC, "timeout", "")
    StorageUtil.SetStringValue(akNPC, "SeverTravel_Result", "timeout")
    NotifyPlayer(akNPC.GetDisplayName() + "'s patience ran out!")
    ClearSlot(slot, false)
EndFunction

; =============================================================================
; UPDATE LOOP — waiting slots only
; =============================================================================

Event OnUpdate()
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
        RegisterForSingleUpdate(1.0)
    ElseIf AmbushActive
        RegisterForSingleUpdate(2.0)
    ElseIf hasWaiting
        RegisterForSingleUpdate(UpdateInterval)
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
    {Change speed mid-journey. Updates both the package override and the
     orchestrator's catch-up estimator.}
    If akNPC == None
        Return false
    EndIf
    Int slot = FindSlotByActor(akNPC)
    If slot < 0
        Return false
    EndIf
    If GetSlotState(slot) != 1
        Return false
    EndIf
    If speed < 0
        speed = 0
    ElseIf speed > 2
        speed = 2
    EndIf
    If GetSlotSpeed(slot) == speed
        Return true
    EndIf

    Package newPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(speed)
    If newPkg == None
        DebugMsg("SetTravelSpeed: no package for speed " + speed)
        Return false
    EndIf

    Package oldPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(GetSlotSpeed(slot))
    If oldPkg != None
        ActorUtil.RemovePackageOverride(akNPC, oldPkg)
    EndIf
    ActorUtil.AddPackageOverride(akNPC, newPkg, TravelPackagePriority, 1)
    akNPC.EvaluatePackage()

    SetSlotSpeed(slot, speed)
    StorageUtil.SetIntValue(akNPC, "SeverTravel_Speed", speed)
    If GetSlotHandle(slot) > 0
        SeverActionsNativeExt.Travel_SetSpeed(GetSlotHandle(slot), speed)
    EndIf
    Return true
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
    StorageUtil.SetIntValue(akNPC, "SeverTravel_WasFollower", isFollower as Int)
    If isFollower
        akNPC.SetPlayerTeammate(false)
        ; SetPlayerTeammate(false) alone is NOT enough — the SA follow alias package
        ; keeps chasing the player via the FollowerFollowKW linked-ref, which outranks
        ; the travel package, so she never paths (the orchestrator then leapfrogs her,
        ; which looks like teleporting). Clear the follow link so travel is unopposed.
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
