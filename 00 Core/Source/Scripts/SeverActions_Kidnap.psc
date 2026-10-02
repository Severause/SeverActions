Scriptname SeverActions_Kidnap extends Quest
{The arrest module's captivity system: KidnapNPC, RestrainNPC, MoveCaptive, DemandRansom,
 InterrogateCaptive, the furniture tie, UntieCaptive, ReleaseCaptive. State lives in the native
 KidnapStore ('KDNP'), read by the kidnap decorators; FollowerManager keeps an M-I-STUB per moved
 function (P6-01, F7). Nothing runs from OnInit (DR20): arrest provider stage 1 runs
 KidnapMaintenance. Reaches SeverActions_Arrest by cast (own module), travel via natives and
 TravelCore, the followers provider's sandbox services, leashlib / furniturelib statically (DR3).}

; ── Travel constants: SeverActions_Travel's runtime values (C11, DR18) ──
Int Property SPEED_JOG = 1 AutoReadOnly
{SeverActions_Travel.SPEED_JOG: the speed index of the kidnap legs.}
Int Property TRAVEL_OPTIONS_LONGRANGE = 12 AutoReadOnly
{SeverActions_Travel.TRAVEL_OPTIONS_LONGRANGE: the grab leg's orchestrator options.}
Int Property TRAVEL_PACKAGE_PRIORITY = 85 AutoReadOnly
{SeverActions_Travel.TravelPackagePriority's VMAD fill: the grab leg's override priority.}
Int Property TRAVEL_TARGET_KEYWORD_FORMID = 0x00076F5F AutoReadOnly
{SeverActions_Travel.TravelTargetKeyword's fill, SeverTravelKeyword (SeverActions.esp).}

; ── Furniture-tie tunables ──
Float Property TieAnchorSlack = 100.0 AutoReadOnly
{The framework MIN for a furniture chain (where pulling stops). Must exceed where the captive
 stands (TieStandOffset, plus TieAnchorHeight vertically), or the rope hauls at a pinned
 prisoner and they walk on the spot.}

Float Property TieAnchorLength = 160.0 AutoReadOnly
{How far a captive tied to furniture may drift from it before the rope goes taut.}

Float Property TieAnchorHeight = 40.0 AutoReadOnly
{Chain anchor height above the furniture origin (zero runs the rope through the floor).}

Float Property TieStandOffset = 60.0 AutoReadOnly
{How far in front of the furniture the captive stands. Never seat a bound NPC in it: they
 freeze, and the low-process Sit package CTDs.}

Float Property TieReachDistance = 70.0 AutoReadOnly
{Leave the captive where they stand when already this close. MUST stay under TieAnchorSlack
 by more than TieAnchorHeight (70 + 40 vertical = 81 diagonal, inside the 100 slack): a
 captive left in place beyond the slack gets the walk-on-the-spot rope haul.}

Float Property TieArrivalDistance = 160.0 AutoReadOnly
{How close the speaker gets to the furniture before tying; inside this, tie on the spot.
 Matches the restrain walk-up's arrival threshold (the alias-targeting Jog closes to contact).}

Float Property PlayerTieReachDistance = 400.0 AutoReadOnly
{How close the player stands to the furniture to tie the captive they lead to it
 (PlayerTieLedCaptive). The crosshair only picks what is within activation reach anyway.}

Float Property DegradedArrivalDistance = 300.0 AutoReadOnly
{Arrival for a walk-up on FollowGuard_Prisoner (the dispatch aliases are busy): that package
 settles at its 200/256 follow radii and never reaches 160, so arrival fires out here and
 _CloseDegradedGap paths the rest of the way.}

Float Property DegradedBindReach = 200.0 AutoReadOnly
{After the degraded gap-close, the farthest a restrainer may be from the target and still bind.}

; ── Kidnap: KidnapNPC / ReleaseCaptive (opt-in, default off) ──
; A follower abducts a named NPC (resolvable off-screen) and delivers them bound and hooded,
; kneeling on a vanilla BoundCaptiveMarker, to a destination from the travel resolver.

; Vanilla Skyrim.esm records: 0x05A9E3 ExecutionHoodDB (the shack captives' hood),
; 0x0A19E2 IdleBoundKneesExit (getting up), 0x0A19DF BoundCaptiveMarker.
Int Property KIDNAP_HOOD_FORMID        = 0x0005A9E3 AutoReadOnly
Int Property KIDNAP_IDLE_KNEEL_EXIT    = 0x000A19E2 AutoReadOnly
Int Property KIDNAP_MARKER_FORMID      = 0x000A19DF AutoReadOnly
{BoundCaptiveMarker FURN, the shack captives' kneeling furniture. Driven only by the SitTarget
 package (KIDNAP_SIT_PKG_FORMID) through the FurnitureTargetKW linked ref, NEVER a sandbox
 package: a sandbox's Activate procedure on a runtime-placed marker furniture CTDs.}
Int Property KIDNAP_SIT_PKG_FORMID     = 0x0016567A AutoReadOnly
{SeverActions_BoundCaptiveSit v2: the vanilla SitTarget template (0x0A9277), Target =
 LinkedRef(FurnitureTargetKW), byte-matching the DB02 shack captive packages. A hand-built
 procedure tree is never treated as valid (the captive's default AI wins).}
Int Property KIDNAP_GUARD_PKG_FORMID   = 0x00165679 AutoReadOnly
{SeverActions_KidnapGuardSandbox: sandbox r=180 at LinkedRef(SandboxAnchorKW); PrisonerSandBox's
 r=350 leaked the guard out through small-shop doors.}
Int Property TIE_HOLD_PKG_FORMID       = 0x0005DA58 AutoReadOnly
{The furniture tie's hold: SeverActions_WaitPackage, a hold position at radius 0 where the package
 starts (conditions: not in combat or a scene, not riding, 3D loaded). SetDontMove alone pins the
 body while the captive's own AI keeps choosing packages that walk, so they jog in place.}

; ── Captive-hold alias pool (KDNP v6) ──
; The kneel hold also seats its sit package through SeverActions_CaptiveQuest aliases: an alias
; package re-applies on cell load, where the priority-95 ActorUtil override drops on 3D unload.
; The override and the tick heals stay as backstops. The restraint hold is not package-driven.
Int Property CAPTIVE_QUEST_FORMID    = 0x0016A78B AutoReadOnly
{SeverActions_CaptiveQuest: 16 ReferenceAliases (Captive_00..15), each carrying
 SeverActions_CaptiveSit (0x0016A78C, cloned by GenerateCaptiveAliases.pas). Quest DNAM priority
 105 sets the alias-package precedence (TES5 PACKs have none): above 100 so foreign overrides
 cannot preempt; SkyrimNet's eval hook still wins.}
Int Property CAPTIVE_ALIAS_POOL_SIZE = 16 AutoReadOnly
Quest _captiveQuest = None
Bool _captiveQuestResolved = false
Int _captiveCursor = 0

; ── Consequences ──
Int Property KIDNAP_BOUNTY             = 1000 AutoReadOnly
{Vanilla kidnapping bounty, charged once per captivity: at the grab when witnessed, otherwise
 on release (the freed victim reports it).}
Float Property KIDNAP_GOSSIP_DAYS      = 2.0 AutoReadOnly
{Game days held before the victim's home hold starts talking.}
Float Property KIDNAP_SEARCH_DAYS      = 4.0 AutoReadOnly
{Game days held before hired searchers can track the captive to the hold
 site (prominent victims only — those with a home-hold crime faction).}
; Native_Kidnap_SetFlag/GetFlag bit values — keep in sync with KidnapStore::Flag.
Int Property KIDNAP_FLAG_WITNESSED     = 1 AutoReadOnly
Int Property KIDNAP_FLAG_GOSSIP        = 2 AutoReadOnly
Int Property KIDNAP_FLAG_SEARCH        = 4 AutoReadOnly
Int Property KIDNAP_FLAG_RESTRAINT     = 8 AutoReadOnly
{RESTRAIN, not an abduction: an open, ordered hold with no hood, bounty, gossip, search or
 ransom (grabTime stays 0, so the consequence timers never arm). Keep in sync with
 KidnapStore::kFlagRestraint.}
Int Property KIDNAP_FLAG_INTERROGATED  = 16 AutoReadOnly
Int Property KIDNAP_FLAG_UNBOUND       = 32 AutoReadOnly
Int Property KIDNAP_FLAG_LEASHED       = 64 AutoReadOnly
{Hands bound, walking behind a leader on the escort-follow package instead of pinned to the
 hold marker (LeashCaptive / UnleashCaptive).}
Int Property KIDNAP_FLAG_PHYSLEASH     = 128 AutoReadOnly
{Leash Framework rope attached; mirrored into the store for the kidnap_context /
 sever_kidnap_leash decorators.}
Int Property KIDNAP_FLAG_LEASH_CHAIN   = 256 AutoReadOnly
Int Property KIDNAP_FLAG_LEASH_RUNES   = 512 AutoReadOnly
Int Property KIDNAP_FLAG_TIED          = 1024 AutoReadOnly
{Tied to furniture: mirrors SeverKidnap_TiedTo for kidnap_context.}
Int Property KIDNAP_FLAG_RETAKE        = 2048 AutoReadOnly
{Set natively by RekeyIfHeld (a held captive re-taken by MoveCaptive); nothing here reads it.}

Int Property LEASH_HAND_CHAIN_FORMID   = 0x000D69 AutoReadOnly
{Leash.esm Leash_hand_chain (slot 39), the 1.1.1 hand leash: worn by the HOLDER, its far end
 tied to the captive's wrist. Absent on 1.1.0 (what LeashWristAvailable tests for).}
; The off-screen fast-forward teleport is skipped while the player is within this range of
; the marching pair, so the player can intercept on the road.
Float Property KIDNAP_ROADSIDE_RADIUS  = 12000.0 AutoReadOnly

; Last KidnapTick game time: a gap of >= 1 game hour (wait, sleep, fast travel) counts as
; elapsed march time for an in-flight leg.
Float KidnapLastTickGT = 0.0

; ── Ransom ──
; Ransom states — keep in sync with KidnapStore::RansomState.
Int Property KIDNAP_RANSOM_PENDING     = 1 AutoReadOnly
Int Property KIDNAP_RANSOM_PAID       = 2 AutoReadOnly
Int Property KIDNAP_RANSOM_REFUSED    = 3 AutoReadOnly
Float Property KIDNAP_RANSOM_RESOLVE_DAYS = 1.5 AutoReadOnly
{Game days between the demand going out and the steward's answer.}
Float Property KIDNAP_RANSOM_GRACE_DAYS   = 1.0 AutoReadOnly
{After a PAID ransom: game days the payers wait for the release before hiring searchers
 anyway.}
Float Property KIDNAP_RANSOM_REOPEN_DAYS  = 2.0 AutoReadOnly
{After a refused ransom whose searchers are spent (dead or talked down): game days before the
 court reopens negotiation and the ransom slate resets.}

; ── Captivity life ──
Float Property KIDNAP_GUARD_RADIUS     = 1000.0 AutoReadOnly
{A guard within this distance (same cell) keeps the captive from working their bonds: the
 player, the kidnapper, any registered follower, any Enterprises retainer.}
Float Property KIDNAP_ESCAPE_ROLL_HOURS = 6.0 AutoReadOnly
{Unguarded game hours between escape rolls (one roll each time the unguarded clock passes
 the last roll by this much).}
Int Property KIDNAP_ESCAPE_CHANCE      = 5 AutoReadOnly
{Escape chance (%) per roll; doubled while untied.}

; ── Local helpers ──

SeverActions_Arrest Function _Arrest()
    {The arrest script on this quest (this module's own type, A7).}
    Return (Self as Quest) as SeverActions_Arrest
EndFunction

Function DebugMsg(String msg)
    If SeverActionsNativeExt2.Settings_GetBool("debugMode")
        Debug.Trace("[SeverActions_Kidnap] " + msg)
    EndIf
EndFunction

Bool Function _IsFollower(Actor akActor)
    {Registered-follower test through the native FollowerDataStore.}
    Return akActor && SeverActionsNativeExt.Native_GetIsFollower(akActor)
EndFunction

ObjectReference Function _ResolvePlace(Actor akNPC, String placeName)
    {Resolve a place name through the native travel resolver; None when it does not resolve.}
    If !SeverActionsNative.IsLocationResolverReady()
        DebugMsg("_ResolvePlace: LocationResolver not initialized")
        Return None
    EndIf
    ObjectReference marker = SeverActionsNative.ResolveDestination(akNPC, placeName)
    If marker == None
        DebugMsg("Could not resolve '" + placeName + "'")
    EndIf
    Return marker
EndFunction

Function _CancelTravel(Actor akActor)
    {End akActor's journey or wait without restoring them as a follower (TravelCore's cancel,
     synchronous; a raw orchestrator leg with no journey keys is simply ended).}
    If akActor == None
        Return
    EndIf
    SeverActions_TravelCore.CancelJourney(akActor, false)
EndFunction

Function _AppendGossip(String locationName, String gossipText)
    {Append to a location's gossip ring (the SeverGossip_<location> StorageUtil string,
     pipe-delimited, max 3, oldest dropped) and list the place in SeverGossip_Places. A copy of
     SeverActions_CompanionLife.AppendGossip.}
    String gossipKey = "SeverGossip_" + locationName
    ; The 0185 gossip prompt finds each ring through this index of place names.
    StorageUtil.StringListAdd(None, "SeverGossip_Places", locationName, false)
    String existing = StorageUtil.GetStringValue(None, gossipKey, "")

    If existing == ""
        StorageUtil.SetStringValue(None, gossipKey, gossipText)
        Return
    EndIf

    Int count = 1
    Int searchPos = 0
    Int pipePos = StringUtil.Find(existing, "|", searchPos)
    While pipePos >= 0
        count += 1
        searchPos = pipePos + 1
        pipePos = StringUtil.Find(existing, "|", searchPos)
    EndWhile

    If count >= 3
        ; Drop the oldest item
        Int firstPipe = StringUtil.Find(existing, "|")
        If firstPipe >= 0
            existing = StringUtil.Substring(existing, firstPipe + 1)
        Else
            existing = ""
        EndIf
    EndIf

    If existing != ""
        StorageUtil.SetStringValue(None, gossipKey, existing + "|" + gossipText)
    Else
        StorageUtil.SetStringValue(None, gossipKey, gossipText)
    EndIf
EndFunction

Function _RetractVanishedGossip(Actor akVictim, String asNews)
    {The captivity is over: drop akVictim's "vanished" line from their home hold's gossip ring
     (rings never expire) and append asNews when it is not "". Reads the entry, so call it
     before Native_Kidnap_Clear.}
    If !akVictim || !SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_GOSSIP)
        Return
    EndIf
    String vHold = SeverActionsNativeExt.Hold_GetHoldName(akVictim)
    If vHold == ""
        Return
    EndIf
    String gossipKey = "SeverGossip_" + vHold
    String ring = StorageUtil.GetStringValue(None, gossipKey, "")
    If ring != ""
        ; The line KidnapTick wrote when the hold started talking.
        String vanished = akVictim.GetDisplayName() + " has vanished without a trace"
        String[] items = StringUtil.Split(ring, "|")
        String kept = ""
        Int i = 0
        While i < items.Length
            If items[i] != "" && StringUtil.Find(items[i], vanished) != 0
                If kept != ""
                    kept += "|"
                EndIf
                kept += items[i]
            EndIf
            i += 1
        EndWhile
        StorageUtil.SetStringValue(None, gossipKey, kept)
    EndIf
    If asNews != ""
        _AppendGossip(vHold, asNews)
    EndIf
EndFunction

; ── The chronometer tick ──

Bool _kidnapTickInFlight = false
Float _kidnapTickStartedRT = 0.0

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick (unique event and callback names; a re-arm
     replaces the pending tick; ticks do not survive a load, so KidnapMaintenance re-arms).}
    RegisterForModEvent("SeverActions_Tick_Kidnap", "OnChronoTick_Kidnap")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Kidnap", afSeconds)
EndFunction

Event OnChronoTick_Kidnap(String eventName, String strArg, Float numArg, Form sender)
    {The 30 s captivity pass. Re-arms FIRST: the re-arm is what Init K4's watchdog counts
     (SeverActions_Mod_Arrest.ChronoTickNames lists this chain), so never a quiet exit. Then
     skips while a previous pass is still in flight, with a 120 s real-time ceiling so a frame
     lost to a save/load cannot wedge the guard.}
    ChronoArm(30.0)
    If _kidnapTickInFlight
        ; GetCurrentRealTime counts from the executable's launch: a stamp saved by an earlier
        ; process reads as a negative delta, i.e. expired. KidnapMaintenance also clears the flag.
        Float inFlightFor = Utility.GetCurrentRealTime() - _kidnapTickStartedRT
        If inFlightFor >= 0.0 && inFlightFor < 120.0
            Return
        EndIf
        Debug.Trace("[SeverActions_Kidnap] OnChronoTick_Kidnap: in-flight guard STUCK (" + inFlightFor + " s) - previous pass died mid-body, clearing")
    EndIf
    _kidnapTickInFlight = true
    _kidnapTickStartedRT = Utility.GetCurrentRealTime()
    KidnapTick()
    _kidnapTickInFlight = false
EndEvent

; ── Shared native events (M-E canonical callbacks; OnArrival is further down) ──

Event OnTravelComplete(String eventName, String strArg, Float numArg, Form sender)
    {Shared orchestrator completion (M-E), strArg <callbackTag>|<status>: answers only the
     kidnap_* legs.}
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String tag = StringUtil.Substring(strArg, 0, pipePos)
    If StringUtil.GetLength(tag) < 7 || StringUtil.Substring(tag, 0, 7) != "kidnap_"
        Return
    EndIf
    Actor kidnapNpc = sender as Actor
    If kidnapNpc
        HandleKidnapTravelComplete(kidnapNpc, tag, StringUtil.Substring(strArg, pipePos + 1, 0))
    EndIf
EndEvent

Event OnCellLoadedReapplyHome(String eventName, String strArg, Float numArg, Form sender)
    {Shared cell-load event (M-E): kidnap's half is the bound-pose re-assert; FollowerManager
     handles the sandbox-rescue and home halves.}
    ReposeBoundCaptivesOnCellLoad()
EndEvent

; ── Leash Framework wrappers (gated static calls into SeverActions_LeashLib) ──

Bool Function LeashFrameworkActive()
    {Setting on AND the framework present (DLL loaded + Leash.esm).}
    Return SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled() && SeverActions_LeashLib.Active()
EndFunction

Bool Function LeashWristAvailable()
    {The 1.1.1 hand leash is installed: lead by the wrists instead of the neck.}
    Return SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled() && SeverActions_LeashLib.WristAvailable()
EndFunction

Armor Function _LeashArmorForStyle(Int aiStyle)
    {The Leash.esm collar for a style index (0 rope / 1 chain / 2 runes).}
    Armor collar
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        collar = SeverActions_LeashLib.ArmorForStyle(aiStyle)
    EndIf
    Return collar
EndFunction

Function _RemoveHandLeashFrom(Actor akHolder)
    {Take the hand chain off a holder who is no longer leading anyone.}
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.RemoveHandLeashFrom(akHolder)
    EndIf
EndFunction

Function _RemoveLeashArmor(Actor akVictim)
    {Strip every collar variant (the style may have changed mid-leash).}
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.RemoveLeashArmor(akVictim)
    EndIf
EndFunction

Bool Function _AttachPhysicalLeash(Actor akVictim, Actor akHolder)
    {Rope from a HOLDER to a captive, by whichever of the two attachments the
     installed framework supports (the why is on SeverActions_LeashLib.Attach).}
    Return SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled() && SeverActions_LeashLib.Attach(akVictim, akHolder)
EndFunction

Function _DetachPhysicalLeash(Actor akVictim)
    {Rope off and collar out of the inventory, marks and store mirror cleared; without the
     framework the library is never touched and only the marks are cleared.}
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.Detach(akVictim)
    Else
        _ClearLeashMarks(akVictim)
    EndIf
EndFunction

; ── Captivity ──

Function ReposeBoundCaptivesOnCellLoad()
    {A cell transition resets the behaviour graph and drops the hands-behind-back offset, so
     this re-poses whatever the posed flag says. Re-poses only the STANDING bound (on the
     march, leashed, tied to furniture, or a restraint hold), never the hooded kneel, whose
     pose comes from the sit furniture. Runs off the natively debounced cell-load event.}
    Actor[] caps = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !caps || caps.Length == 0
        Return
    EndIf
    SeverActions_Arrest arrestCl = _Arrest()
    If !arrestCl || !arrestCl.OffsetBoundStandingStart
        Return
    EndIf
    Int ci = 0
    While ci < caps.Length
        Actor cap = caps[ci]
        If cap && !cap.IsDead() && cap.Is3DLoaded() \
            && !SeverActionsNativeExt.Native_Kidnap_GetFlag(cap, KIDNAP_FLAG_UNBOUND)
            Int capPhase = SeverActionsNativeExt.Native_Kidnap_GetPhase(cap)
            Bool standingBound = (capPhase == 2) \
                || (capPhase == 3 \
                    && (SeverActionsNativeExt.Native_Kidnap_GetFlag(cap, KIDNAP_FLAG_RESTRAINT) \
                        || SeverActionsNativeExt.Native_Kidnap_GetFlag(cap, KIDNAP_FLAG_LEASHED) \
                        || _GetFurnitureTie(cap)))
            If standingBound
                If cap.PlayIdle(arrestCl.OffsetBoundStandingStart)
                    StorageUtil.SetIntValue(cap, "SeverRestrain_Posed", 1)
                Else
                    ; 3D still settling: one short retry, else leave the flag
                    ; clear so the kidnap tick re-poses them later.
                    StorageUtil.SetIntValue(cap, "SeverRestrain_Posed", 0)
                    Utility.Wait(1.5)
                    If cap && !cap.IsDead() && cap.Is3DLoaded() \
                        && cap.PlayIdle(arrestCl.OffsetBoundStandingStart)
                        StorageUtil.SetIntValue(cap, "SeverRestrain_Posed", 1)
                    EndIf
                EndIf
            EndIf
        EndIf
        ci += 1
    EndWhile
EndFunction

Function KidnapMaintenance()
    {Load recovery (arrest provider stage 1): push the kidnap / restrain toggles into the
     native flags the decorators read (false until pushed), register the shared native events
     under their canonical callbacks (M-E, check 18; keyed per form and event, so a sibling's
     registration of the same pair is this one), reconcile the alias pool, re-assert held
     captives and arm the 30 s tick. The Leash Framework version notice is the arrest provider's.}
    ; No chronometer wake survives a load: clear a guard a dead stack left set in the save.
    _kidnapTickInFlight = false
    _kidnapTickStartedRT = 0.0
    SeverActionsNativeExt.Native_Kidnap_SetEnabled(SeverActionsNativeExt2.Settings_GetBool("kidnapEnabled"))
    SeverActionsNativeExt.Native_Restrain_SetEnabled(SeverActionsNativeExt2.Settings_GetBool("restrainEnabled"))
    ; The framework reports a leash it dropped (holder died, recovery gave up, another mod
    ; replaced it). Shared with arrest's escort rope (check 18), so each handler filters to
    ; its own subjects. Harmless without the framework.
    RegisterForModEvent("LeashFramework_OnUnleash", "OnLeashFrameworkUnleash")
    ; Pull events -> SkyrimNet: fired once per pull start; _NarrateLeashPull rate-limits
    ; the plain tug.
    RegisterForModEvent("LeashFramework_OnActorPulled", "OnLeashFrameworkPulled")
    RegisterForModEvent("LeashFramework_OnActorRagdollPulled", "OnLeashFrameworkRagdollPulled")
    RegisterForModEvent("SeverActionsNative_OnArrival", "OnArrival")
    RegisterForModEvent("SeverActions_TravelComplete", "OnTravelComplete")
    RegisterForModEvent("SeverActions_CellLoaded", "OnCellLoadedReapplyHome")
    ; Guard-recall listener, needed while any kidnap is live (re-registration is idempotent).
    Actor[] activeVictims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If activeVictims && activeVictims.Length > 0
        RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")
        ; A restrain walk-up cannot survive a save: its ArrivalMonitor registration is not
        ; cosaved, so restrain_arrived would never fire. Nothing has happened to the target
        ; yet, so abort quietly.
        Int avi = 0
        While avi < activeVictims.Length
            Actor av = activeVictims[avi]
            If av && SeverActionsNativeExt.Native_Kidnap_GetPhase(av) == 1 \
                && SeverActionsNativeExt.Native_Kidnap_GetFlag(av, KIDNAP_FLAG_RESTRAINT) \
                && SeverActionsNativeExt.Native_Kidnap_GetDestLabel(av) == ""
                _AbortRestrainApproach(av)
            EndIf
            avi += 1
        EndWhile
    EndIf
    SweepCaptiveAliasesOnLoad()
    KidnapTick(true)  ; load pass — re-pose standing-bound restraint captives
    ChronoArm(30.0)
EndFunction

; ── Captive-hold alias pool (KDNP v6) ──

Quest Function GetCaptiveQuest()
    {Lazy-resolve the captive-hold alias quest by FormID; retried each call until it resolves.
     None while the ESP predates the pool (the priority-95 override then holds alone).}
    If _captiveQuestResolved
        Return _captiveQuest
    EndIf
    _captiveQuest = Game.GetFormFromFile(CAPTIVE_QUEST_FORMID, "SeverActions.esp") as Quest
    If !_captiveQuest
        Debug.Trace("[SeverActions] CAPTIVE ALIAS POOL UNAVAILABLE — SeverActions_CaptiveQuest failed to resolve from SeverActions.esp (outdated ESP?). Alias-held captivity disabled; the priority-95 override remains the hold.")
        Return None
    EndIf
    _captiveQuestResolved = true
    Return _captiveQuest
EndFunction

ReferenceAlias Function GetCaptiveAlias(Int aiIndex)
    If aiIndex < 0 || aiIndex >= CAPTIVE_ALIAS_POOL_SIZE
        Return None
    EndIf
    Quest q = GetCaptiveQuest()
    If !q
        Return None
    EndIf
    Return q.GetNthAlias(aiIndex) as ReferenceAlias
EndFunction

Int Function FindFreeCaptiveAlias()
    {Rotating-cursor scan for an empty captive alias; -1 when the pool is full or unavailable.}
    Quest q = GetCaptiveQuest()
    If !q
        Return -1
    EndIf
    Int n = 0
    While n < CAPTIVE_ALIAS_POOL_SIZE
        Int idx = _captiveCursor + n
        If idx >= CAPTIVE_ALIAS_POOL_SIZE
            idx -= CAPTIVE_ALIAS_POOL_SIZE
        EndIf
        ReferenceAlias al = q.GetNthAlias(idx) as ReferenceAlias
        If al && al.GetReference() == None
            _captiveCursor = idx + 1
            If _captiveCursor >= CAPTIVE_ALIAS_POOL_SIZE
                _captiveCursor = 0
            EndIf
            Return idx
        EndIf
        n += 1
    EndWhile
    Return -1
EndFunction

Function _FreeCaptiveAlias(Actor akVictim)
    {Empty the victim's captive alias (index-verified, no pool scan) and drop the cosaved
     index. Idempotent. No EvaluatePackage: the caller's teardown batches it.}
    If !akVictim
        Return
    EndIf
    Int idx = SeverActionsNativeExt.Native_Kidnap_GetAliasIndex(akVictim)
    If idx < 0
        Return
    EndIf
    ReferenceAlias al = GetCaptiveAlias(idx)
    If al && al.GetReference() == akVictim
        al.Clear()
    EndIf
    ; Drop the index even when stale (alias repurposed); SweepCaptiveAliasesOnLoad
    ; cross-checks the pool.
    SeverActionsNativeExt.Native_Kidnap_SetAliasIndex(akVictim, -1)
    DebugMsg("CaptiveAlias: freed alias " + idx + " for " + akVictim.GetDisplayName())
EndFunction

Function SweepCaptiveAliasesOnLoad()
    {Load reconciliation of the captive-alias pool: every filled slot must hold a live held
     entry and every recorded index must point at its victim. Drift is emptied and logged;
     the override hold carries the captive until the next bind reseats them.}
    Quest q = GetCaptiveQuest()
    If !q
        Return
    EndIf
    ; Pass 1 (pool side): empty a slot holding a deleted/disabled actor or one with no live
    ; held entry.
    Int i = 0
    While i < CAPTIVE_ALIAS_POOL_SIZE
        ReferenceAlias al = q.GetNthAlias(i) as ReferenceAlias
        If al
            Actor a = al.GetReference() as Actor
            If a
                If a.IsDeleted() || a.IsDisabled()
                    al.Clear()
                    Debug.Trace("[SeverActions_Kidnap] CaptiveAlias: load sweep emptied alias " + i + " (deleted/disabled holder)")
                ElseIf SeverActionsNativeExt.Native_Kidnap_GetPhase(a) != 3
                    al.Clear()
                    Debug.Trace("[SeverActions_Kidnap] CaptiveAlias: load sweep emptied alias " + i + " (no live held entry)")
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile
    ; Pass 2 (entry side): drop indices whose alias no longer points at the victim.
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims
        Return
    EndIf
    Int vi = 0
    While vi < victims.Length
        Actor v = victims[vi]
        If v
            Int idx = SeverActionsNativeExt.Native_Kidnap_GetAliasIndex(v)
            If idx >= 0
                ReferenceAlias held = GetCaptiveAlias(idx)
                If !held || held.GetReference() != v
                    SeverActionsNativeExt.Native_Kidnap_SetAliasIndex(v, -1)
                    Debug.Trace("[SeverActions_Kidnap] CaptiveAlias: load sweep dropped stale index " + idx + " for " + v.GetDisplayName())
                EndIf
            EndIf
        EndIf
        vi += 1
    EndWhile
    DebugMsg("CaptiveAlias: load sweep complete")
EndFunction

Function KidnapTick(Bool abFromLoad = false)
    {Per-captive pass: re-assert the bound state (restraint and idles don't survive 3D
     reloads), advance the legs and run the captivity timers. Every ~30 s from
     OnChronoTick_Kidnap, and once from KidnapMaintenance with abFromLoad true (only the load
     pass forces the standing-bound idle re-play; every tick would twitch). Also heals holds
     left by older builds (the furniture-sandbox package, non-persistent markers).}
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    Keyword furnKW = SeverActions_FurnitureLib.TargetKeyword()
    Package furnPkg = SeverActions_FurnitureLib.UsePackage()
    Float kidnapNowGT = Utility.GetCurrentGameTime()
    ; >= 1 game hour between 30s-real ticks = a wait/sleep/fast-travel skip.
    Bool kidnapTimeJumped = KidnapLastTickGT > 0.0 && (kidnapNowGT - KidnapLastTickGT) >= 0.042
    KidnapLastTickGT = kidnapNowGT
    Int i = 0
    While i < victims.Length
        Actor v = victims[i]
        Int phase = 0
        If v && v.IsDead()
            ; Death in captivity is murder: consequences + cleanup.
            _OnCaptiveDied(v)
        ElseIf v
            phase = SeverActionsNativeExt.Native_Kidnap_GetPhase(v)
        EndIf

        ; A SkyrimNet package on a captive rides the eval hook and outranks the whole hold:
        ; FollowPlayer (the LLM's own StartFollow; is_kidnap_victim gates only SA actions) or
        ; TalkToPlayer (lands when anyone talks to them). Clear the SkyrimNet stack every
        ; tick; the sit package / pin re-asserts on re-eval.
        If phase >= 2 && (SkyrimNetApi.HasPackage(v, "FollowPlayer") > 0 || SkyrimNetApi.HasPackage(v, "TalkToPlayer") > 0)
            SkyrimNetApi.ClearAllPackages(v)
            SkyrimNetApi.CancelPendingPackageTasks(v)
            v.EvaluatePackage()
        EndIf

        If phase == 3
            ; Legacy heal, a no-op on new binds: drop the old sandbox-on-furniture package.
            If furnPkg
                ActorUtil.RemovePackageOverride(v, furnPkg)
            EndIf

            ; Marker-schema heal: pre-v2 markers are not persistent, unload with their cell,
            ; and the Sit package then CTDs in low process. Strip the hold at once, re-bind
            ; once loaded.
            If SeverActionsNativeExt.Native_Kidnap_GetMarkerSchema(v) < 2
                Package sitPkgHeal = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
                If sitPkgHeal
                    ActorUtil.RemovePackageOverride(v, sitPkgHeal)
                EndIf
                If furnKW
                    SeverActionsNative.LinkedRef_Clear(v, furnKW)
                EndIf
                ObjectReference oldMarker = SeverActionsNativeExt.Native_Kidnap_GetMarker(v)
                If oldMarker
                    oldMarker.Disable()
                    oldMarker.Delete()
                    SeverActionsNativeExt.Native_Kidnap_SetHeld(v, None)
                EndIf
                If v.Is3DLoaded()
                    Actor healKd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(v)
                    If healKd
                        Debug.Trace("[SeverActions_Kidnap] Kidnap: v2 marker heal - re-binding " + v.GetDisplayName())
                        _BindCaptive(v, healKd)
                    EndIf
                EndIf
                ; Not loaded: stays hooded but packageless (no CTD surface); retried
                ; every tick until loaded.

            ElseIf v.Is3DLoaded()
                ; A tie can be ordered on any held captive, and a tie walk that never
                ; arrives holds the SHARED arrest dispatch aliases (every later arrest and
                ; restrain walk-up degrades), so expire it here, ahead of the branch chain.
                _ExpireStaleTie(v)
                If _GetFurnitureTie(v)
                    ; Chained to furniture. Must precede the branch chain: the tie clears
                    ; kFlagLeashed, so a KIDNAP captive would fall to the Else arm, which
                    ; unpins them every pass. Hold them like the restraint arm: pinned, posed
                    ; on the loaded edge, never unpinned. The tie bit is re-asserted here for
                    ; kidnap_context (a save can hold a tie without it).
                    SeverActionsNativeExt.Native_Kidnap_SetFlag(v, KIDNAP_FLAG_TIED, True)
                    v.SetRestrained(false)
                    v.SetDontMove(true)
                    ; The hold package too: flags 0, since 1 resets the AI (and drops the pose)
                    ; every tick. A cut that ran since TiedTo was read has unset it first, so a
                    ; re-read after the add undoes a hold the cut would otherwise leave behind.
                    Package tieHoldTick = Game.GetFormFromFile(TIE_HOLD_PKG_FORMID, "SeverActions.esp") as Package
                    If tieHoldTick
                        ActorUtil.AddPackageOverride(v, tieHoldTick, 95, 0)
                        If !_GetFurnitureTie(v) || SeverActionsNativeExt.Native_Kidnap_GetPhase(v) != 3
                            ActorUtil.RemovePackageOverride(v, tieHoldTick)
                            v.EvaluatePackage()
                        ElseIf !v.IsInCombat() && !v.IsInDialogueWithPlayer() && v.GetCurrentPackage() != tieHoldTick
                            ; Their own AI had them: re-pick, and re-pose below (the package that
                            ; ran has most likely dropped the bound offset).
                            v.EvaluatePackage()
                            StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 0)
                        EndIf
                    EndIf
                    If StorageUtil.GetIntValue(v, "SeverRestrain_Posed", 0) == 0
                        _PlayBoundPose(v)
                    EndIf
                ElseIf SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_LEASHED)
                    ; Leashed: the escort-follow package walks them; never pin. A gone
                    ; leader falls back to a pin where they stand (UnleashCaptive).
                    v.SetDontMove(false)
                    Actor leashLd = StorageUtil.GetFormValue(v, "SeverKidnap_LeashLeader") as Actor
                    If !leashLd || leashLd.IsDead()
                        UnleashCaptive(v)
                    Else
                        ; Leash Framework reconcile (never trust a third party's rope is
                        ; still there): re-attach when active, the leader is loaded and we
                        ; hold no live rope, capped at three refusals so a rejected leash
                        ; cannot loop; detach when the setting was turned off mid-leash.
                        If LeashFrameworkActive()
                            If StorageUtil.GetIntValue(v, "SeverKidnap_PhysLeash", 0) == 0 \
                                && leashLd.Is3DLoaded() \
                                && StorageUtil.GetIntValue(v, "SeverKidnap_PhysLeashFails", 0) < 3
                                _AttachPhysicalLeash(v, leashLd)
                            EndIf
                        ElseIf StorageUtil.GetIntValue(v, "SeverKidnap_PhysLeash", 0) == 1
                            _DetachPhysicalLeash(v)
                        EndIf
                        ; No vanilla bound-WALK idle exists: the follow package's walk
                        ; cancels the hands-behind-back state. Re-pose on the
                        ; moving->stopped edge (posed flag), never every tick (twitch);
                        ; the cuffs carry the look while moving.
                        SeverActions_Arrest arrestLsh = _Arrest()
                        Float leashSpd = v.GetAnimationVariableFloat("Speed")
                        If leashSpd < 5.0
                            If StorageUtil.GetIntValue(v, "SeverRestrain_Posed", 0) == 0                                 && arrestLsh && arrestLsh.OffsetBoundStandingStart
                                If v.PlayIdle(arrestLsh.OffsetBoundStandingStart)
                                    StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 1)
                                EndIf
                            EndIf
                        Else
                            ; Moving: clear the flag so the next stop re-poses.
                            StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 0)
                        EndIf
                    EndIf
                ElseIf SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_UNBOUND)
                    ; Loose captivity (UntieCaptive): the hold-anchored sandbox does the
                    ; holding; keep them unpinned.
                    v.SetRestrained(false)
                    v.SetDontMove(false)
                ElseIf SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_RESTRAINT)
                    ; Standing-bound restraint: re-pin every tick (idempotent). The bound
                    ; offset idle does not survive a 3D reload, so re-play it on the
                    ; unloaded->loaded edge via the posed flag (cleared while unloaded and
                    ; on the load pass). Proximity gate: a relocated captive may still be
                    ; trailing the escort (_BindCaptive deferred the pin), so pin only at
                    ; the marker; the kept escort-follow package closes the gap, with a
                    ; MoveTo after 4 ticks as the pathing backstop.
                    ObjectReference pinM = SeverActionsNativeExt.Native_Kidnap_GetMarker(v)
                    Bool atHold = !pinM || (v.GetParentCell() == pinM.GetParentCell() && v.GetDistance(pinM) <= 300.0)
                    If !atHold && StorageUtil.GetIntValue(v, "SeverRestrain_TrailTicks", 0) >= 4
                        v.MoveTo(pinM)
                        atHold = true
                    EndIf
                    If atHold
                        StorageUtil.UnsetIntValue(v, "SeverRestrain_TrailTicks")
                        SeverActions_Arrest arrestHeal = _Arrest()
                        ; Finish a deferred trailing bind: strip the escort-follow
                        ; remnant (idempotent), then pin.
                        If arrestHeal && arrestHeal.SeverActions_FollowGuard_Prisoner
                            ActorUtil.RemovePackageOverride(v, arrestHeal.SeverActions_FollowGuard_Prisoner)
                        EndIf
                        If arrestHeal && arrestHeal.SeverActions_FollowTargetKW
                            SeverActionsNative.LinkedRef_Clear(v, arrestHeal.SeverActions_FollowTargetKW)
                        EndIf
                        v.SetDontMove(true)
                        If abFromLoad
                            StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 0)
                        EndIf
                        If StorageUtil.GetIntValue(v, "SeverRestrain_Posed", 0) == 0
                            If arrestHeal && arrestHeal.OffsetBoundStandingStart
                                If v.PlayIdle(arrestHeal.OffsetBoundStandingStart)
                                    StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 1)
                                EndIf
                            EndIf
                        EndIf
                    Else
                        StorageUtil.SetIntValue(v, "SeverRestrain_TrailTicks", StorageUtil.GetIntValue(v, "SeverRestrain_TrailTicks", 0) + 1)
                    EndIf
                Else
                    v.SetRestrained(false)
                    v.SetDontMove(false)
                    ; The kneel (furniture) hold: not seated -> re-evaluate so the
                    ; package re-seats them (post-load hiccups).
                    If v.GetSitState() == 0
                        v.EvaluatePackage()
                    EndIf
                EndIf
            ElseIf SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_RESTRAINT)
                ; Unloaded restraint captive: the idle is gone; arm the re-pose.
                StorageUtil.SetIntValue(v, "SeverRestrain_Posed", 0)
            EndIf

            ; Captive-on-hold heal: a captive outside the hold cell (a TalkToPlayer window
            ; can walk them out) is re-posted to the marker once unloaded, never visibly;
            ; the hold re-takes them on re-eval.
            ObjectReference holdHealM = SeverActionsNativeExt.Native_Kidnap_GetMarker(v)
            If holdHealM && !v.Is3DLoaded() && v.GetParentCell() != holdHealM.GetParentCell()
                Debug.Trace("[SeverActions_Kidnap] Kidnap: captive " + v.GetDisplayName() + " off the hold - re-posting to the marker")
                v.MoveTo(holdHealM)
                v.EvaluatePackage()
            EndIf

            ; Guard-on-station heal: an on-guard kidnapper off the hold cell AND unloaded
            ; (teammate drag on fast travel, sandbox door leaks) is re-posted to the marker.
            Actor guardKd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(v)
            If guardKd && !guardKd.IsDead() \
                && StorageUtil.GetIntValue(guardKd, "SeverKidnap_OnGuard", 0) == 1
                ObjectReference stationM = SeverActionsNativeExt.Native_Kidnap_GetMarker(v)
                If stationM && guardKd.GetParentCell() != stationM.GetParentCell() \
                    && !guardKd.Is3DLoaded()
                    Debug.Trace("[SeverActions_Kidnap] Kidnap: guard " + guardKd.GetDisplayName() + " off station - re-posting to the hold")
                    guardKd.MoveTo(stationM)
                    guardKd.EvaluatePackage()
                EndIf
            EndIf

            ; A pending ransom comes due.
            Int rState = SeverActionsNativeExt.Native_Kidnap_GetRansomState(v)
            If rState == KIDNAP_RANSOM_PENDING \
                && Utility.GetCurrentGameTime() - SeverActionsNativeExt.Native_Kidnap_GetRansomTime(v) >= KIDNAP_RANSOM_RESOLVE_DAYS
                _ResolveRansom(v)
                rState = SeverActionsNativeExt.Native_Kidnap_GetRansomState(v)
            EndIf

            ; Consequences (one-shot flags).
            Float grabT = SeverActionsNativeExt.Native_Kidnap_GetGrabTime(v)
            If grabT > 0.0
                Float heldDays = Utility.GetCurrentGameTime() - grabT
                ; Disappearance gossip in the victim's home hold (the hold-scoped pool the
                ; 0185 gossip prompt reads).
                If heldDays >= KIDNAP_GOSSIP_DAYS && !SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_GOSSIP)
                    SeverActionsNativeExt.Native_Kidnap_SetFlag(v, KIDNAP_FLAG_GOSSIP, true)
                    String vHold = SeverActionsNativeExt.Hold_GetHoldName(v)
                    If vHold != ""
                        _AppendGossip(vHold, v.GetDisplayName() + " has vanished without a trace - no one has seen them for days, and people are starting to ask questions")
                        Debug.Trace("[SeverActions_Kidnap] Kidnap: disappearance gossip fired in " + vHold)
                    EndIf
                EndIf
                ; Search party: a long-held PROMINENT victim (one with a home-hold crime
                ; faction) is tracked to the hold. Fires only while the player is AT the
                ; site (the standoff spawns around them); the native gates the ambush
                ; toggle, cooldown and player state. A refused ransom, or a paid one
                ; still held past the grace window, arms it at once.
                Bool searchDue = heldDays >= KIDNAP_SEARCH_DAYS
                If !searchDue
                    If rState == KIDNAP_RANSOM_REFUSED
                        searchDue = true
                    ElseIf rState == KIDNAP_RANSOM_PAID
                        searchDue = Utility.GetCurrentGameTime() - SeverActionsNativeExt.Native_Kidnap_GetRansomTime(v) \
                            >= KIDNAP_RANSOM_RESOLVE_DAYS + KIDNAP_RANSOM_GRACE_DAYS
                    EndIf
                EndIf
                If searchDue && !SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_SEARCH)
                    If SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(v)
                        ObjectReference holdSite = SeverActionsNativeExt.Native_Kidnap_GetMarker(v)
                        If holdSite && Game.GetPlayer().GetParentCell() == holdSite.GetParentCell()
                            If SeverActionsNativeExt2.Venture_FireKidnapSearch(v)
                                SeverActionsNativeExt.Native_Kidnap_SetFlag(v, KIDNAP_FLAG_SEARCH, true)
                                Debug.Trace("[SeverActions_Kidnap] Kidnap: search party fired for " + v.GetDisplayName())
                            EndIf
                        EndIf
                    EndIf
                EndIf
                ; Reopen: a refused ransom must not dead-end once the hold's steel is
                ; spent (SA_KidnapSteelSpentGT, stamped by SeverActions_Ambush when the
                ; searchers fight or stand down, or by _ResolveRansom when a refusal
                ; follows their visit). After the reopen window the ransom slate resets
                ; so a fresh demand can go out, priced with the desperation premium.
                If rState == KIDNAP_RANSOM_REFUSED
                    Float steelSpentGT = StorageUtil.GetFloatValue(v, "SA_KidnapSteelSpentGT", 0.0)
                    If steelSpentGT > 0.0 && Utility.GetCurrentGameTime() - steelSpentGT >= KIDNAP_RANSOM_REOPEN_DAYS
                        StorageUtil.UnsetFloatValue(v, "SA_KidnapSteelSpentGT")
                        Actor roSteward = _GetHoldSteward(SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(v))
                        String roStewardName = ""
                        If roSteward
                            roStewardName = roSteward.GetDisplayName()
                        EndIf
                        String roHold = SeverActionsNativeExt.Hold_GetHoldName(v)
                        If roHold == ""
                            roHold = "The captive's people"
                        EndIf
                        ; Cut-losses roll: first the court weighs what the captive is
                        ; worth to the hold (the pay odds' standing signals, condensed).
                        Int abandonChance = 30
                        Faction roFacJarl      = Game.GetFormFromFile(0x00050920, "Skyrim.esm") as Faction
                        Faction roFacSteward   = Game.GetFormFromFile(0x00050922, "Skyrim.esm") as Faction
                        Faction roFacMerchant  = Game.GetFormFromFile(0x00051596, "Skyrim.esm") as Faction
                        Faction roFacInnkeeper = Game.GetFormFromFile(0x0005091B, "Skyrim.esm") as Faction
                        Faction roFacBeggar    = Game.GetFormFromFile(0x00060028, "Skyrim.esm") as Faction
                        Faction roFacDrunk     = Game.GetFormFromFile(0x00060027, "Skyrim.esm") as Faction
                        If (roFacJarl && v.IsInFaction(roFacJarl)) || (roFacSteward && v.IsInFaction(roFacSteward))
                            abandonChance -= 25
                        ElseIf (roFacMerchant && v.IsInFaction(roFacMerchant)) || (roFacInnkeeper && v.IsInFaction(roFacInnkeeper))
                            abandonChance -= 10
                        EndIf
                        If (roFacBeggar && v.IsInFaction(roFacBeggar)) || (roFacDrunk && v.IsInFaction(roFacDrunk))
                            abandonChance += 45
                        EndIf
                        ActorBase roBase = v.GetActorBase()
                        If roBase && roBase.IsEssential()
                            abandonChance -= 15
                        EndIf
                        If abandonChance < 5
                            abandonChance = 5
                        ElseIf abandonChance > 85
                            abandonChance = 85
                        EndIf
                        If Utility.RandomInt(0, 99) < abandonChance
                            ; Written off: no more coin or steel. State stays REFUSED
                            ; (no fresh demand) and the spent clock is consumed, so
                            ; this fires once; escape and the bounty still apply.
                            SeverActionsNativeExt.Native_Kidnap_RequestRansomReopenLetter(v, roStewardName, true)
                            If roSteward
                                SeverActionsNative.Native_AddMemory(roSteward, \
                                    "I closed the matter of " + v.GetDisplayName() + " - the hold has spent blades enough, and I will not bleed the treasury for them. I signed it, and I will carry it: we left one of our own in a captor's hands.", \
                                    0.8, "EXPERIENCE", "grim", "", "[\"ransom\"]", "[]")
                            EndIf
                            SkyrimNetApi.RegisterPersistentEvent( \
                                roHold + " has cut its losses: their court has written that no ransom will be paid and no more blades hired for " + v.GetDisplayName() + ". The hold has washed its hands of the matter.", \
                                Game.GetPlayer(), v)
                            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.cutsTheirLossesNoRansom", ("" + roHold), ("" + v.GetDisplayName())))
                            Debug.Trace("[SeverActions_Kidnap] Kidnap: ransom WRITTEN OFF for " + v.GetDisplayName() + " (abandonChance=" + abandonChance + ")")
                        Else
                            ; SA_KidnapSteelFailed stays set: the next resolve prices
                            ; in the failed force.
                            SeverActionsNativeExt.Native_Kidnap_SetRansomState(v, 0)
                            SeverActionsNativeExt.Native_Kidnap_RequestRansomReopenLetter(v, roStewardName)
                            If roSteward
                                SeverActionsNative.Native_AddMemory(roSteward, \
                                    "The blades I hired to bring " + v.GetDisplayName() + " home availed us nothing. I have written that the hold will hear ransom terms after all - it cost me my pride to sign it, but pride does not bring people home.", \
                                    0.8, "EXPERIENCE", "resigned", "", "[\"ransom\"]", "[]")
                            EndIf
                            SkyrimNetApi.RegisterPersistentEvent( \
                                roHold + "'s attempt to reclaim " + v.GetDisplayName() + " by force has failed, and their court has written that they will hear ransom terms again.", \
                                Game.GetPlayer(), v)
                            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.givesUpOnSteel", ("" + roHold), ("" + v.GetDisplayName())))
                            Debug.Trace("[SeverActions_Kidnap] Kidnap: ransom negotiation REOPENED for " + v.GetDisplayName())
                        EndIf
                    EndIf
                EndIf
            EndIf

            ; Escape watch, LAST in the held branch (it can clear the entry): an unwatched
            ; captive works their bonds loose (guards: KIDNAP_GUARD_RADIUS). One roll per
            ; KIDNAP_ESCAPE_ROLL_HOURS of UNGUARDED game time (anchor-tracked), never per
            ; tick - a per-tick roll makes escape near-certain within minutes.
            Bool kdGuarded = _IsCaptiveGuarded(v)
            Float unguardedH = SeverActionsNativeExt.Native_Kidnap_TickUnguarded(v, kdGuarded, Utility.GetCurrentGameTime())
            If kdGuarded
                ; A guard resets the native unguarded clock; reset the roll anchor too.
                StorageUtil.SetFloatValue(v, "SeverKidnap_EscAnchor", 0.0)
            Else
                Float escAnchor = StorageUtil.GetFloatValue(v, "SeverKidnap_EscAnchor", 0.0)
                If unguardedH >= escAnchor + KIDNAP_ESCAPE_ROLL_HOURS
                    Int escChance = KIDNAP_ESCAPE_CHANCE
                    If SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_UNBOUND)
                        escChance += KIDNAP_ESCAPE_CHANCE  ; untied: no bonds to work loose - twice the odds
                    EndIf
                    StorageUtil.SetFloatValue(v, "SeverKidnap_EscAnchor", unguardedH)
                    If Utility.RandomInt(0, 99) < escChance
                        _EscapeCaptive(v)
                    EndIf
                EndIf
            EndIf

        ElseIf phase == 1
            ; Restrain walk-up (no destination): arrival belongs to ArrivalMonitor ->
            ; restrain_arrived -> HandleRestrainArrived, so the tick runs only the deadline
            ; watchdog. The grab logic below would hijack it (grabArrived is instantly true
            ; in a shared interior: grab info, a bounty for a no-crime act, a MoveTo yank).
            ; A restraint captive being MOVED has a destLabel and takes the Else.
            If SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_RESTRAINT) \
                && SeverActionsNativeExt.Native_Kidnap_GetDestLabel(v) == ""
                ; Past the deadline (pathing failure, target gone, combat), unwind.
                Float restrainDl = SeverActionsNativeExt.Native_Kidnap_GetLegDeadline(v)
                If restrainDl > 0.0 && Utility.GetCurrentGameTime() > restrainDl
                    _AbortRestrainApproach(v)
                EndIf
            Else
                Actor kdnp = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(v)
                If kdnp && !kdnp.IsDead()
                    ; Arrived: in the victim's interior cell, or within 300u in the
                    ; same exterior cell.
                    Cell kCell = kdnp.GetParentCell()
                    Bool grabArrived = false
                    If kCell && kCell == v.GetParentCell()
                        grabArrived = kCell.IsInterior() || kdnp.GetDistance(v) <= 300.0
                    EndIf
                    If grabArrived
                        Debug.Trace("[SeverActions_Kidnap] Kidnap: kidnapper reached the victim - grab resolves")
                        _OnKidnapGrabResolved(kdnp)
                    Else
                        _KidnapLegWatchdog(kdnp, v, v, kidnapTimeJumped)
                    EndIf
                Else
                    ; Kidnapper dead or unresolvable mid-approach: nothing else cleans
                    ; up (the entry would wedge, holding the dispatch aliases). Nothing
                    ; has happened to the victim yet, so unwind quietly.
                    _AbortKidnapForVictim(v, kdnp)
                EndIf
            EndIf

        ElseIf phase == 2
            Actor kdnp2 = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(v)
            If kdnp2 && !kdnp2.IsDead()
                ; Leash reconcile for the march, as in the phase-3 leashed branch (both
                ; ends loaded). Off-screen the travel machinery moves the pair, not the rope.
                If LeashFrameworkActive()
                    If StorageUtil.GetIntValue(v, "SeverKidnap_PhysLeash", 0) == 0 \
                        && kdnp2.Is3DLoaded() && v.Is3DLoaded() \
                        && StorageUtil.GetIntValue(v, "SeverKidnap_PhysLeashFails", 0) < 3
                        _AttachPhysicalLeash(v, kdnp2)
                    EndIf
                ElseIf StorageUtil.GetIntValue(v, "SeverKidnap_PhysLeash", 0) == 1
                    _DetachPhysicalLeash(v)
                EndIf
                ObjectReference destRef = SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(v)
                ; No destination anchor (KidnapStore::Load zeroes an unresolvable
                ; destAnchorID while phase and aliasMode survive): the march can never
                ; arrive, and the alias watchdog returns on a None goal before its
                ; deadline check. Bind in place (_OnKidnapTransportResolved handles it).
                If !destRef
                    ; (No Return here — this runs inside the per-victim loop.)
                    Debug.Trace("[SeverActions_Kidnap] Kidnap: transport has no destination anchor - binding in place")
                    _OnKidnapTransportResolved(kdnp2, "arrived")
                Else
                    Bool atDest = false
                    If kdnp2.GetParentCell() == destRef.GetParentCell()
                        atDest = kdnp2.GetParentCell().IsInterior() || kdnp2.GetDistance(destRef) <= 400.0
                    EndIf
                    If atDest
                        Debug.Trace("[SeverActions_Kidnap] Kidnap: kidnapper reached the destination - binding")
                        _OnKidnapTransportResolved(kdnp2, "arrived")
                    ElseIf SeverActionsNativeExt.Native_Kidnap_GetAliasMode(v)
                        _KidnapLegWatchdog(kdnp2, v, destRef, kidnapTimeJumped)
                    Else
                        ; Journey-fallback transport (two TravelCore journeys): poll the
                        ; travel state; "waiting" is the core's arrival. The log text keeps
                        ; its slot-era wording because the kit rows quote it.
                        String travelSt = SeverActionsNativeExt2.Native_GetTravelState(kdnp2)
                        If travelSt == "waiting" || travelSt == "complete"
                            Debug.Trace("[SeverActions_Kidnap] Kidnap: slot travel state '" + travelSt + "' - binding")
                            _OnKidnapTransportResolved(kdnp2, "arrived")
                        ElseIf travelSt == "timeout"
                            _OnKidnapTransportResolved(kdnp2, "timedout")
                        ElseIf travelSt == ""
                            If SeverActionsNativeExt.Native_Kidnap_BumpNoTravelStrikes(v, false) >= 2
                                SeverActionsNativeExt.Native_Kidnap_BumpNoTravelStrikes(v, true)
                                Debug.Trace("[SeverActions_Kidnap] Kidnap: slot travel state lost - aborting kidnap")
                                _AbortKidnap(kdnp2)
                            EndIf
                        Else
                            SeverActionsNativeExt.Native_Kidnap_BumpNoTravelStrikes(v, true)
                        EndIf
                    EndIf
                EndIf
            Else
                ; Kidnapper dead or unresolvable mid-transport: the seized victim walks
                ; free, with consequences (they were taken). _AbortKidnap keyed off the
                ; victim instead of the captor, who cannot narrate an abort.
                _AbortKidnapForVictim(v, kdnp2)
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function KidnapNPC(Actor akKidnapper, String targetName, String destination)
    {A follower abducts a named NPC and delivers them, bound and hooded, to a destination.
     SkyrimNet action (kidnapnpc.yaml); opt-in via the kidnapEnabled setting.}
    If !akKidnapper || akKidnapper.IsDead()
        Return
    EndIf
    If !SeverActionsNativeExt2.Settings_GetBool("kidnapEnabled")
        ; Explicit feedback: the Prisma Actions page lands here too, and a silent no-op
        ; reads as a broken button.
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("followermanager.kidnapActionsDisabled"))
        Return
    EndIf
    If _RejectIfBoundActor(akKidnapper, "abduct anyone")
        Return
    EndIf
    If _RejectIfActorOccupied(akKidnapper, "abduct anyone")
        Return
    EndIf

    ; Global form-table scan, so an off-screen unique NPC resolves too.
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindActorByName(targetName)
    If !victim
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akKidnapper.GetDisplayName() + " could not find anyone called " + targetName + " to abduct.", \
            akKidnapper, None)
        Return
    EndIf
    If victim == akKidnapper || victim == Game.GetPlayer()
        Return
    EndIf
    If _IsFollower(victim)
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akKidnapper.GetDisplayName() + " will not abduct one of " + Game.GetPlayer().GetDisplayName() + "'s own companions.", \
            akKidnapper, None)
        Return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 0
        Return  ; already being kidnapped
    EndIf
    If _RejectInvalidCaptiveTarget(akKidnapper, victim, "abduct")
        Return
    EndIf

    ; The travel resolver (the names TravelToPlace accepts).
    ObjectReference destMarker = _ResolvePlace(akKidnapper, destination)
    If !destMarker
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akKidnapper.GetDisplayName() + " does not know how to reach " + destination + ".", \
            akKidnapper, None)
        Return
    EndIf
    ; Door destination: unlock the DOOR first (before the swap), then use its interior
    ; marker, so pathing isn't blocked.
    If destMarker.GetBaseObject().GetType() == 29
        If destMarker.IsLocked()
            destMarker.Lock(false)
        EndIf
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(destMarker)
        If interiorMarker != None
            destMarker = interiorMarker
        EndIf
    EndIf

    ; Essential NPCs can be kidnapped; warn once at order time.
    ActorBase vBase = victim.GetActorBase()
    If vBase && vBase.IsEssential()
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isQuestProtectedHolding", ("" + victim.GetDisplayName())))
    EndIf

    ; The entry lives in KidnapStore; SeverKidnap_* StorageUtil keys hold only per-actor
    ; markers (EscAnchor / MovePin / OnGuard / LeashLeader).
    If !SeverActionsNativeExt.Native_Kidnap_BeginIfFree(victim, akKidnapper, destination, false)
        Return  ; victim claimed by a concurrent action, or this kidnapper already has a job
    EndIf
    ; Steel bookkeeping is per captivity: a previous kidnapping's flags must not pre-arm the
    ; reopen clock or the desperation premium.
    StorageUtil.UnsetFloatValue(victim, "SA_KidnapSteelSpentGT")
    StorageUtil.UnsetIntValue(victim, "SA_KidnapSteelFailed")
    SeverActionsNativeExt.Native_Kidnap_SetDestAnchor(victim, destMarker)
    Debug.Trace("[SeverActions_Kidnap] Kidnap: leg 1 begins - " + akKidnapper.GetDisplayName() + " -> " + victim.GetDisplayName() + " (dest '" + destination + "')")

    _LaunchGrabLeg(akKidnapper, victim, destination)

    ; Recall: the player calling the kidnapper binds the victim on the spot.
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")

    SkyrimNetApi.RegisterPersistentEvent( \
        akKidnapper.GetDisplayName() + " sets out to quietly abduct " + victim.GetDisplayName() + " and bring them to " + destination + ".", \
        akKidnapper, Game.GetPlayer())
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.setsOutToAbduct", ("" + akKidnapper.GetDisplayName()), ("" + victim.GetDisplayName())))
EndFunction

Function _LaunchGrabLeg(Actor akKidnapper, Actor victim, String destination)
    {Leg 1, shared by KidnapNPC and MoveCaptive. Borrows the arrest dispatch aliases (both
     actors stay high-process unloaded) and gives the kidnapper the alias-targeting Jog, so he
     pursues the victim wherever she goes; the transport leg re-points the target alias at the
     destination. Handed back at bind, abort or release. Falls back to a raw orchestrator leg
     while a real arrest holds the aliases.}
    SeverActions_Arrest arrestK = _Arrest()
    ; (The walk cuffs equip at SEIZURE in _OnKidnapGrabResolved, never at launch.)
    Bool aliasMode = false
    If arrestK && arrestK.DispatchGuardAlias && arrestK.DispatchTargetAlias \
        && arrestK.SeverActions_DispatchJog \
        && arrestK.DispatchGuardAlias.GetReference() == None \
        && arrestK.DispatchTargetAlias.GetReference() == None
        arrestK.DispatchGuardAlias.ForceRefTo(akKidnapper)
        arrestK.DispatchTargetAlias.ForceRefTo(victim)
        ActorUtil.AddPackageOverride(akKidnapper, arrestK.SeverActions_DispatchJog, arrestK.PackagePriority, 1)
        akKidnapper.EvaluatePackage()
        SeverActionsNative.Native_SetTravelState(akKidnapper, "traveling", destination)
        SeverActionsNativeExt.Native_Kidnap_SetAliasMode(victim, true)
        ; Game-time leg deadline (the wait menu advances it): 12 game hours, then
        ; KidnapTick force-resolves off-screen.
        SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(victim, Utility.GetCurrentGameTime() + 0.5)
        ; Native contact detection (1 s checks) resolves the grab promptly; the 30 s tick poll
        ; is the off-screen fallback, and _OnKidnapGrabResolved's 1->2 CAS makes the double
        ; path harmless.
        If !SeverActionsNativeExt.Arrival_IsTracked(akKidnapper)
            SeverActionsNativeExt.Arrival_Register(akKidnapper, victim, 200.0, "kidnap_grab_arrived")
        EndIf
        aliasMode = true
    EndIf
    Debug.Trace("[SeverActions_Kidnap] Kidnap: grab leg aliasMode=" + aliasMode)

    If !aliasMode
        ; Fallback while a real arrest holds the aliases: raw orchestrator leg + KidnapTick's
        ; off-screen fast-forward.
        SeverActionsNativeExt.Native_Kidnap_SetAliasMode(victim, false)
        Package kidnapTravelPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(SPEED_JOG)
        ; Registered so the orphan scanner, when on (orphanCleanupEnabled), does not report the travel LinkedRef.
        SeverActionsNative.OrphanCleanup_RegisterTraveler(akKidnapper)
        ; travelState gates the follower teleport/catch-up systems.
        SeverActionsNative.Native_SetTravelState(akKidnapper, "traveling", destination)
        Int kHandle = SeverActionsNativeExt.Travel_Begin(akKidnapper, victim, Game.GetFormFromFile(TRAVEL_TARGET_KEYWORD_FORMID, "SeverActions.esp") as Keyword, \
            250.0, "kidnap_grab", TRAVEL_OPTIONS_LONGRANGE, 180, SPEED_JOG)
        ; The Traveler_NN pool alias (priority 106) drives the walk; the override is only
        ; the fallback for an exhausted pool or a failed Begin.
        If kidnapTravelPkg && (kHandle <= 0 || !SeverActionsNativeExt2.Travel_HasAlias(kHandle))
            ActorUtil.AddPackageOverride(akKidnapper, kidnapTravelPkg, TRAVEL_PACKAGE_PRIORITY, 1)
            akKidnapper.EvaluatePackage()
        EndIf
    EndIf
EndFunction

Function NarrateRestrainedInPlace(Actor akVictim, Actor akCaptor)
    {The plain bound-and-left-standing narration. Separate from _BindCaptive so a caller that
     defers it (the tie-and-lead flow) can fall back to it when the lead half refuses.}
    If !akVictim || !akCaptor
        Return
    EndIf
    SkyrimNetApi.RegisterPersistentEvent( \
        akCaptor.GetDisplayName() + " has restrained " + akVictim.GetDisplayName() + " - hands bound, held standing in plain sight until someone decides what happens to them.", \
        akCaptor, akVictim)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasBeenRestrained", ("" + akVictim.GetDisplayName())))
EndFunction

Bool Function PlayerRestrainOnSpot(Actor akVictim, Bool abDeferNarration = false)
    {Hotkey restrain: bind akVictim on the spot with the PLAYER as captor (RestrainNPC's
     restraint entry and bind, without the walk-up). True once bound; every refusal notifies
     itself. abDeferNarration skips the restrained-in-place event; a caller that defers owns
     the narration (see NarrateRestrainedInPlace).}
    Actor player = Game.GetPlayer()
    If !akVictim || akVictim == player || akVictim.IsDead()
        Return False
    EndIf
    If _RejectInvalidCaptiveTarget(player, akVictim, "restrain")
        Return False
    EndIf
    If !akVictim.Is3DLoaded() || player.GetDistance(akVictim) > 400.0
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isTooFarToTake", ("" + akVictim.GetDisplayName())))
        Return False
    EndIf
    ; Atomic claim: the authoritative guard against a concurrent action.
    If !SeverActionsNativeExt.Native_Kidnap_BeginIfFree(akVictim, player, "", True)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.cannotBeRestrainedRightNow", ("" + akVictim.GetDisplayName())))
        Return False
    EndIf
    StorageUtil.UnsetFloatValue(akVictim, "SA_KidnapSteelSpentGT")
    StorageUtil.UnsetIntValue(akVictim, "SA_KidnapSteelFailed")
    SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(akVictim, 0.0)

    ; Bind flourish, then the shared pacify + bind; TOCTOU re-check after the wait.
    SeverActions_Arrest arrestH = _Arrest()
    If arrestH && arrestH.IdleGive
        player.PlayIdle(arrestH.IdleGive)
        Utility.Wait(1.2)
        If SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim) != 1
            Return False
        EndIf
    EndIf
    _PacifyCaptive(akVictim)
    _BindCaptive(akVictim, player, False, abDeferNarration)   ; abGuard False: the player isn't posted on guard duty
    Return True
EndFunction

Function RestrainNPC(Actor akRestrainer, String targetName)
    {RESTRAIN: the speaker walks to a named same-scene NPC, binds their hands and takes them
     in hand - no hood, kneel, abduction legs or crime (an open, ordered act). The captive then
     uses the kidnap machinery (MoveCaptive, ReleaseCaptive, the guard/escape sim; kidnap_context
     reads kFlagRestraint). SkyrimNet action (restrainnpc.yaml): any NPC can be the restrainer.
     An already-held captive is taken in hand instead.}
    If !akRestrainer || akRestrainer.IsDead()
        Return
    EndIf
    If !SeverActionsNativeExt2.Settings_GetBool("restrainEnabled")
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("followermanager.restrainActionDisabled"))
        Return
    EndIf
    If _RejectIfBoundActor(akRestrainer, "restrain anyone")
        Return
    EndIf
    If _RejectIfActorOccupied(akRestrainer, "restrain anyone")
        Return
    EndIf
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindActorByName(targetName)
    If !victim || victim == akRestrainer || victim == Game.GetPlayer() || victim.IsDead()
        Return
    EndIf
    If _IsFollower(victim)
        SkyrimNetApi.RegisterEvent("restrain_failed", \
            akRestrainer.GetDisplayName() + " will not restrain one of " + Game.GetPlayer().GetDisplayName() + "'s own companions.", \
            akRestrainer, None)
        Return
    EndIf
    ; Already held: take them in hand instead. With the LeashCaptive action retired this is
    ; the only way to pick a captive back up (standing bound, tied, or at another's heel),
    ; and BeginIfFree below would refuse them anyway. LeashCaptive cuts a furniture tie
    ; silently and narrates the hand-off.
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) == 3 \
        && !SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_UNBOUND)
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_LEASHED) \
            && StorageUtil.GetFormValue(victim, "SeverKidnap_LeashLeader") as Actor == akRestrainer
            Debug.Notification(akRestrainer.GetDisplayName() + " already has " + victim.GetDisplayName() + " in hand.")
            Return
        EndIf
        If !LeashCaptive(victim, akRestrainer)
            SkyrimNetApi.RegisterEvent("restrain_failed", \
                akRestrainer.GetDisplayName() + " cannot take hold of " + victim.GetDisplayName() + " right now.", \
                akRestrainer, None)
        EndIf
        Return
    EndIf
    If _RejectInvalidCaptiveTarget(akRestrainer, victim, "restrain")
        Return
    EndIf
    ; ArrivalMonitor keeps ONE registration per actor: registering restrain_arrived would
    ; kill a live arrest approach/escort watch (guards are typical restrainers). Refuse.
    If SeverActionsNativeExt.Arrival_IsTracked(akRestrainer)
        SkyrimNetApi.RegisterEvent("restrain_failed",             akRestrainer.GetDisplayName() + " has their hands full and cannot restrain anyone right now.",             akRestrainer, None)
        Return
    EndIf
    ; Availability is claimed atomically by BeginIfFree below (a separate pre-check races).
    ; Same-scene only: a restraint has no off-screen leg.
    If !victim.Is3DLoaded() || !akRestrainer.Is3DLoaded() \
        || akRestrainer.GetDistance(victim) > 4000.0
        SkyrimNetApi.RegisterEvent("restrain_failed", \
            akRestrainer.GetDisplayName() + " cannot restrain " + targetName + " - they are not here.", \
            akRestrainer, None)
        Return
    EndIf

    ; Open the restraint-flagged entry in the approach phase (kidnap_context narrates the
    ; walk-up). No grab info, so the gossip/search/ransom timers never arm.
    If !SeverActionsNativeExt.Native_Kidnap_BeginIfFree(victim, akRestrainer, "", true)
        Return  ; target already held, or the restrainer already has a captive (atomic claim)
    EndIf
    StorageUtil.UnsetFloatValue(victim, "SA_KidnapSteelSpentGT")
    StorageUtil.UnsetIntValue(victim, "SA_KidnapSteelFailed")
    ; Recall listener: without it a player recall during the session's first restrain
    ; walk-up is ignored, and the stale approach can bind the target later.
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")
    ; Approach watchdog: KidnapTick unwinds after ~2.4 game hours (GetCurrentGameTime is in days).
    SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(victim, Utility.GetCurrentGameTime() + 0.1)

    ; Walk over on the dispatch aliases + alias-targeting Jog when free: it closes to CONTACT,
    ; whereas a Follow-template package stops at its follow radius, far wider than the 160u
    ; arrival. ArrivalMonitor fires restrain_arrived, answered by this script's OnArrival.
    StorageUtil.UnsetIntValue(akRestrainer, "SeverKidnap_DegradedWalk")
    SeverActions_Arrest arrest = _Arrest()
    If arrest && arrest.DispatchGuardAlias && arrest.DispatchTargetAlias \
        && arrest.SeverActions_DispatchJog \
        && arrest.DispatchGuardAlias.GetReference() == None \
        && arrest.DispatchTargetAlias.GetReference() == None
        arrest.DispatchGuardAlias.ForceRefTo(akRestrainer)
        arrest.DispatchTargetAlias.ForceRefTo(victim)
        ActorUtil.AddPackageOverride(akRestrainer, arrest.SeverActions_DispatchJog, arrest.PackagePriority, 1)
        akRestrainer.EvaluatePackage()
        SeverActionsNativeExt.Native_Kidnap_SetAliasMode(victim, true)
    ElseIf arrest && arrest.SeverActions_FollowTargetKW && arrest.SeverActions_FollowGuard_Prisoner
        ; Degraded walk-up while a real arrest holds the aliases (see DegradedArrivalDistance).
        SeverActionsNative.LinkedRef_Set(akRestrainer, victim, arrest.SeverActions_FollowTargetKW)
        ActorUtil.AddPackageOverride(akRestrainer, arrest.SeverActions_FollowGuard_Prisoner, 95, 1)
        akRestrainer.EvaluatePackage()
        StorageUtil.SetIntValue(akRestrainer, "SeverKidnap_DegradedWalk", 1)
    EndIf
    Float restrainArrival = 160.0
    If StorageUtil.GetIntValue(akRestrainer, "SeverKidnap_DegradedWalk") == 1
        restrainArrival = DegradedArrivalDistance
    EndIf
    SeverActionsNativeExt.Arrival_Register(akRestrainer, victim, restrainArrival, "restrain_arrived")
    Debug.Trace("[SeverActions_Kidnap] Restrain: " + akRestrainer.GetDisplayName() + " moving to restrain " + victim.GetDisplayName())
EndFunction

Event OnArrival(String eventName, String strArg, Float numArg, Form sender)
    {Shared native arrival (M-E): every consumer's OnArrival fires for every arrival, so answer
     only the restrain, tie and kidnap-grab tags. KidnapMaintenance registers it.}
    Actor arrived = sender as Actor
    If arrived == None
        Return
    EndIf
    If strArg == "restrain_arrived"
        HandleRestrainArrived(arrived)
    ElseIf strArg == "tie_arrived"
        HandleTieArrived(arrived)
    ElseIf strArg == "kidnap_grab_arrived"
        HandleKidnapGrabArrived(arrived)
    EndIf
EndEvent

Function HandleRestrainArrived(Actor akRestrainer)
    {restrain_arrived: re-validate (the async event may land after the world moved on), play
     the bind flourish, pacify (undone by _UnbindCaptive), bind and take the captive in hand.}
    If !akRestrainer
        Return
    EndIf
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akRestrainer)
    If !victim
        Return
    EndIf
    If !SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT) \
        || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 1
        Return  ; not a restrain approach (or already bound) — stale event
    EndIf
    Bool degraded = StorageUtil.GetIntValue(akRestrainer, "SeverKidnap_DegradedWalk") == 1
    _EndRestrainApproach(akRestrainer)
    If victim.IsDead()
        SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(victim, 0.0)
        SeverActionsNativeExt.Native_Kidnap_Clear(victim)
        Return
    EndIf
    If degraded
        _CloseDegradedGap(akRestrainer, victim)
        ; The walk takes real time: re-validate as after the flourish below.
        If victim.IsDead() || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 1 \
            || SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akRestrainer) != victim
            Return
        EndIf
        If akRestrainer.IsDead()
            _AbortRestrainApproach(victim)
            Return
        EndIf
        If !_InSameSpace(akRestrainer, victim) || akRestrainer.GetDistance(victim) > DegradedBindReach
            SkyrimNetApi.RegisterEvent("restrain_failed", \
                akRestrainer.GetDisplayName() + " could not get close enough to " + victim.GetDisplayName() + " to restrain them.", \
                akRestrainer, None)
            _AbortRestrainApproach(victim)
            Return
        EndIf
    EndIf
    SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(victim, 0.0)

    ; Bind flourish: the arrest evidence-handoff idle reads as tying the wrists at this range.
    SeverActions_Arrest arrestR = _Arrest()
    If arrestR && arrestR.IdleGive
        akRestrainer.PlayIdle(arrestR.IdleGive)
        Utility.Wait(1.2)
        ; TOCTOU: if anything resolved the entry during the flourish (tick, release, death),
        ; a second bind would place a second persistent marker and leak the first.
        If SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 1
            Return
        EndIf
    EndIf

    _PacifyCaptive(victim)

    ; Bind AND take in hand, as the tie hotkey does: a pinned restraint froze both actors for
    ; the scene (moving on needed a second LeashCaptive the model might never call). Leashed,
    ; the captive is no freer, just follows; UnleashCaptive pins on purpose.
    ; abGuard false: leading, not standing watch. abSilent true: LeashCaptive narrates both.
    _BindCaptive(victim, akRestrainer, false, true)
    If !LeashCaptive(victim, akRestrainer, true)
        ; Lead half refused: fall back to the pin and the plain restrained line (deferred
        ; narration must never be lost).
        victim.SetDontMove(true)
        NarrateRestrainedInPlace(victim, akRestrainer)
    EndIf
EndFunction

Function HandleKidnapGrabArrived(Actor akKidnapper)
    {kidnap_grab_arrived: the grab leg's native contact detection (see _LaunchGrabLeg);
     _OnKidnapGrabResolved's 1->2 CAS makes a stale or duplicate event a no-op.}
    If akKidnapper
        _OnKidnapGrabResolved(akKidnapper)
    EndIf
EndFunction

Function _EndRestrainApproach(Actor akRestrainer)
    {Strip the walk-up apparatus from the restrainer: the dispatch-alias Jog and the degraded
     path's follow package + LinkedRef. Safe in any state; never clears a real arrest's aliases.}
    SeverActions_Arrest arrest = _Arrest()
    If arrest
        If arrest.SeverActions_DispatchJog
            ActorUtil.RemovePackageOverride(akRestrainer, arrest.SeverActions_DispatchJog)
        EndIf
        If arrest.DispatchGuardAlias && arrest.DispatchGuardAlias.GetReference() == akRestrainer
            arrest.DispatchGuardAlias.Clear()
            If arrest.DispatchTargetAlias
                arrest.DispatchTargetAlias.Clear()
            EndIf
        EndIf
        If arrest.SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(akRestrainer, arrest.SeverActions_FollowGuard_Prisoner)
        EndIf
        If arrest.SeverActions_FollowTargetKW
            SeverActionsNative.LinkedRef_Clear(akRestrainer, arrest.SeverActions_FollowTargetKW)
        EndIf
    EndIf
    StorageUtil.UnsetIntValue(akRestrainer, "SeverKidnap_DegradedWalk")
    akRestrainer.EvaluatePackage()
EndFunction

Function _CloseDegradedGap(Actor akWalker, ObjectReference akTarget)
    {After a degraded walk-up's wide arrival, walk the rest of the way (latent, holds the
     caller's thread). Callers strip the follow package first and re-validate afterwards.}
    If _InSameSpace(akWalker, akTarget) && akWalker.GetDistance(akTarget) > TieArrivalDistance
        akWalker.PathToReference(akTarget, 0.5)
    EndIf
EndFunction

Bool Function _InSameSpace(ObjectReference akA, ObjectReference akB)
    {Same interior cell, or the same exterior worldspace (where two refs a few steps apart can
     sit in different 4096u cells).}
    If akA.IsInInterior() || akB.IsInInterior()
        Return akA.GetParentCell() == akB.GetParentCell()
    EndIf
    Return akA.GetWorldSpace() == akB.GetWorldSpace()
EndFunction

Function _AbortRestrainApproach(Actor akVictim)
    {Abort a restrain walk-up (the tick's deadline watchdog, or a load): unwind the restrainer
     and drop the entry. Nothing happened to the target, so no memory or consequences.}
    Actor restrainer = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    If restrainer
        SeverActionsNativeExt.Arrival_Cancel(restrainer)
        _EndRestrainApproach(restrainer)
    EndIf
    SeverActionsNativeExt.Native_Kidnap_Clear(akVictim)
    Debug.Trace("[SeverActions_Kidnap] Restrain: approach timed out for " + akVictim.GetDisplayName() + " - unwound")
EndFunction

Function MoveCaptive(Actor akEscort, String targetName, String destination)
    {Relocate a held captive with KidnapNPC's two-leg flow (the escort walks to the captive,
     marches them to the new hold, re-binds). akEscort may differ from the original kidnapper.
     SkyrimNet action (movecaptive.yaml) and the Prisma Actions page.}
    ; Kidnap OR restrain enabled: restraint is default-on and kidnap default-off, and a
    ; restrained captive must be movable under default settings.
    If !akEscort || akEscort.IsDead() || (!SeverActionsNativeExt2.Settings_GetBool("kidnapEnabled") && !SeverActionsNativeExt2.Settings_GetBool("restrainEnabled"))
        Return
    EndIf
    If _RejectIfBoundActor(akEscort, "escort a captive anywhere")
        Return
    EndIf
    ; The occupancy guard matters most here: _LaunchGrabLeg borrows the arrest dispatch
    ; aliases, so a guard mid-arrest would evict their own arrest.
    If _RejectIfActorOccupied(akEscort, "escort a captive anywhere")
        Return
    EndIf

    ; Resolve among ACTIVE captives only.
    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && targetName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        Return  ; only HELD captives can be moved
    EndIf

    ObjectReference destMarker = _ResolvePlace(akEscort, destination)
    If !destMarker
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akEscort.GetDisplayName() + " does not know how to reach " + destination + ".", \
            akEscort, None)
        Return
    EndIf
    If destMarker.GetBaseObject().GetType() == 29
        ; Door: unlock it before swapping to its interior marker (as KidnapNPC).
        If destMarker.IsLocked()
            destMarker.Lock(false)
        EndIf
        ObjectReference interiorMarker = SeverActionsNative.FindInteriorMarkerForDoor(destMarker)
        If interiorMarker != None
            destMarker = interiorMarker
        EndIf
    EndIf

    ; Release the OLD guard (may be another NPC) and tear down the hold, keeping the hood,
    ; pacify faction and entry.
    Actor oldKidnapper = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(victim)
    ; ATOMIC re-key: under one mutex hold RekeyIfHeld refuses a captive no longer held (a
    ; racing ReleaseCaptive) and an escort already mid-job for another victim. markerID
    ; survives, so _TearDownHold can still delete the old hold marker.
    If !SeverActionsNativeExt.Native_Kidnap_RekeyIfHeld(victim, akEscort, destination)
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akEscort.GetDisplayName() + " cannot move " + victim.GetDisplayName() + " right now - the captive is spoken for, or the escort already has their hands full.", \
            akEscort, None)
        Return
    EndIf
    ; Always end guard duty, even when the guard is the new escort: the 110-priority
    ; KidnapGuardSandbox anchored to the old hold marker outranks the 100-priority march
    ; packages and would pin them there. No-op without a guard package.
    If oldKidnapper
        _EndGuardDuty(oldKidnapper)
    EndIf
    _TearDownHold(victim)

    ; Same two-leg flow (leg 1 resolves instantly if the escort is adjacent); the entry was
    ; re-keyed above, so no Begin.
    SeverActionsNativeExt.Native_Kidnap_SetDestAnchor(victim, destMarker)
    _LaunchGrabLeg(akEscort, victim, destination)
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")

    SkyrimNetApi.RegisterPersistentEvent( \
        akEscort.GetDisplayName() + " sets out to move the captive " + victim.GetDisplayName() + " to " + destination + ".", \
        akEscort, victim)
    Debug.Notification(akEscort.GetDisplayName() + " is moving " + victim.GetDisplayName() + " to " + destination)
EndFunction

Function MoveCaptiveHere(Actor akEscort, String captiveName)
    {PrismaUI Arrests view, Move here: the entry's CURRENT kidnapper re-takes the held captive
     with MoveCaptive's two-leg flow and binds them at a force-persistent pin dropped at the
     player's position. akEscort (the row's kidnapper) is only a hint.}
    If !akEscort || akEscort.IsDead() || (!SeverActionsNativeExt2.Settings_GetBool("kidnapEnabled") && !SeverActionsNativeExt2.Settings_GetBool("restrainEnabled"))
        Return
    EndIf

    ; Resolve among ACTIVE captives only (same pattern as MoveCaptive).
    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && captiveName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), captiveName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim
        Return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.onlyHeldCaptiveCanBeMoved", ("" + victim.GetDisplayName())))
        Return  ; only HELD captives can be moved
    EndIf

    ; The escort is the entry's current kidnapper (akEscort may be stale): no living
    ; escort, no move.
    Actor escort = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(victim)
    If !escort || escort.IsDead()
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.noLivingKidnapperCanBring", ("" + victim.GetDisplayName())))
        Return
    EndIf
    If _RejectIfBoundActor(escort, "escort a captive anywhere")
        Return
    EndIf
    ; Occupancy guard as in MoveCaptive (leg 1 borrows the dispatch aliases).
    If _RejectIfActorOccupied(escort, "escort a captive anywhere")
        Return
    EndIf
    ; Player in combat: the march would walk escort and captive into the fight. Refuse.
    If Game.GetPlayer().IsInCombat()
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("followermanager.notInMiddleOfFight"))
        Return
    EndIf

    ; The pin is the destination: resolve it before any state changes. abForcePersist TRUE
    ; is load-bearing, as for the hold marker: a default PlaceAtMe ref unloads with its cell
    ; and the captive's low-process AI dereferences the gone anchor (BGSProcedureSit CTD).
    Form pinBase = Game.GetFormFromFile(0x00000034, "Skyrim.esm")   ; XMarkerHeading
    If !pinBase
        Return
    EndIf
    ; Sweep a pin left by an aborted move-here: force-persistent refs never unload.
    ObjectReference oldPin = StorageUtil.GetFormValue(victim, "SeverKidnap_MovePin") as ObjectReference
    If oldPin
        oldPin.Disable()
        oldPin.Delete()
        StorageUtil.UnsetFormValue(victim, "SeverKidnap_MovePin")
    EndIf
    ObjectReference pin = Game.GetPlayer().PlaceAtMe(pinBase, 1, true, false)
    If !pin
        Return
    EndIf
    StorageUtil.SetFormValue(victim, "SeverKidnap_MovePin", pin)

    String hereLabel = _PlaceLabel(Game.GetPlayer())
    ; ATOMIC re-key, as in MoveCaptive.
    If !SeverActionsNativeExt.Native_Kidnap_RekeyIfHeld(victim, escort, hereLabel)
        pin.Disable()
        pin.Delete()
        StorageUtil.UnsetFormValue(victim, "SeverKidnap_MovePin")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.cannotMoveRightNow", ("" + escort.GetDisplayName()), ("" + victim.GetDisplayName())))
        Return
    EndIf
    ; End guard duty: the escort IS the guarding kidnapper here (see MoveCaptive).
    _EndGuardDuty(escort)
    _TearDownHold(victim)

    ; Same two-leg flow; _BindCaptive deletes the pin once the hold marker stands there.
    SeverActionsNativeExt.Native_Kidnap_SetDestAnchor(victim, pin)
    _LaunchGrabLeg(escort, victim, hereLabel)
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")

    DebugMsg("MoveCaptiveHere: " + escort.GetDisplayName() + " re-taking " + victim.GetDisplayName() + " to the player's position (pin=" + pin + ")")
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isBringingToYou", ("" + escort.GetDisplayName()), ("" + victim.GetDisplayName())))
EndFunction

Function DemandRansom(Actor akSpeaker, String targetName, Int aiAmount = 0)
    {Send a ransom demand for a HELD captive to their home hold's crime faction (the steward
     abstraction, also the bounty jurisdiction). _ResolveRansom answers by courier after
     KIDNAP_RANSOM_RESOLVE_DAYS: payment, or a refusal that arms the search party.
     aiAmount 0 = a fair price from the victim's standing; a named amount is clamped to
     100-10000, and overreaching the fair price docks the pay chance. Rounded to 50s. Called by
     demandransom.yaml and the Prisma Actions page.}
    If !akSpeaker || akSpeaker.IsDead() || !SeverActionsNativeExt2.Settings_GetBool("kidnapEnabled")
        Return
    EndIf
    If _RejectIfBoundActor(akSpeaker, "demand ransom for anyone")
        Return
    EndIf

    ; Resolve among HELD captives only (same pattern as MoveCaptive).
    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && targetName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        Return  ; only HELD captives can be ransomed
    EndIf
    ; RESTRAINT captives have no ransom market (KIDNAP_FLAG_RESTRAINT). Must precede the grab-record
    ; heal below, which would stamp a grab time and arm the gossip / search / release-bounty timers.
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
        SkyrimNetApi.RegisterEvent("kidnap_ransom_failed",             akSpeaker.GetDisplayName() + " considers it, but no one pays ransom for someone held openly in plain sight.",             akSpeaker, None)
        Return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetRansomState(victim) != 0
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.ransomAlreadyDemanded", ("" + victim.GetDisplayName())))
        Return
    EndIf

    ; The payer: the victim's home-hold crime faction. Heal a missing grab record (pre-v3
    ; captivity) so a refusal's search party has a jurisdiction.
    Faction payerFac = SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(victim)
    If !payerFac
        payerFac = SeverActionsNativeExt.Hold_GetCrimeFaction(victim)
        If payerFac && SeverActionsNativeExt.Native_Kidnap_GetGrabTime(victim) <= 0.0
            SeverActionsNativeExt.Native_Kidnap_SetGrabInfo(victim, payerFac, Utility.GetCurrentGameTime())
        EndIf
    EndIf
    If !payerFac
        SkyrimNetApi.RegisterEvent("kidnap_ransom_failed", \
            "No one of standing would pay a ransom for " + victim.GetDisplayName() + " - the demand has nowhere to go.", \
            akSpeaker, victim)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.noOneOfStandingWillPay", ("" + victim.GetDisplayName())))
        Return
    EndIf

    ; Fair price scales with the victim's standing: level + quest protection.
    Int amount = 400 + victim.GetLevel() * 30
    ActorBase vBase = victim.GetActorBase()
    If vBase && vBase.IsEssential()
        amount += 600
    EndIf
    If amount > 4000
        amount = 4000
    EndIf
    ; Wealth (carried coin, a home of their own) raises it. MIRRORED in _ResolveRansom's
    ; greed-dock recompute - keep the two in sync.
    amount += (victim.GetItemCount(Game.GetForm(0x0000000F)) / 2)
    If SeverActionsNative.GetActorHomeCellName(victim) != ""
        amount += 400
    EndIf
    If amount > 4500
        amount = 4500
    EndIf

    ; Player-named amount: clamped; _ResolveRansom's greed dock punishes overreach.
    If aiAmount > 0
        amount = aiAmount
        If amount < 100
            amount = 100
        ElseIf amount > 10000
            amount = 10000
        EndIf
    EndIf
    amount = (amount / 50) * 50

    SeverActionsNativeExt.Native_Kidnap_SetRansom(victim, amount, Utility.GetCurrentGameTime())

    String holdName = SeverActionsNativeExt.Hold_GetHoldName(victim)
    If holdName == ""
        holdName = victim.GetDisplayName() + "'s people"
    EndIf
    SkyrimNetApi.RegisterPersistentEvent( \
        akSpeaker.GetDisplayName() + " has sent word to " + holdName + " demanding " + amount + " gold for the safe return of " + victim.GetDisplayName() + ". The answer will take a day or two to come back.", \
        akSpeaker, victim)
    Debug.Notification("Ransom demanded for " + victim.GetDisplayName() + ": " + amount + " gold.")
    Debug.Trace("[SeverActions_Kidnap] Kidnap: ransom demanded for " + victim.GetDisplayName() + " (" + amount + "g, payer hold '" + holdName + "')")
EndFunction

Function _ResolveRansom(Actor akVictim)
    {The steward's answer, KIDNAP_RANSOM_RESOLVE_DAYS after the demand: a weighted pay roll.
     The letter is composed natively (Native_Kidnap_RequestRansomLetter, sever_letter_writer
     with a templated fallback) and arrives by courier; paid gold goes straight to the player
     (the ledger's gold-delta monitor records it).}
    Int amount = SeverActionsNativeExt.Native_Kidnap_GetRansomAmount(akVictim)
    String vName = akVictim.GetDisplayName()
    String plName = Game.GetPlayer().GetDisplayName()

    ; The payer hold's real steward signs the letter and carries the memory of the exchange.
    Actor steward = _GetHoldSteward(SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(akVictim))
    String stewardName = ""
    If steward
        stewardName = steward.GetDisplayName()
    EndIf

    ; Pay chance: base 55, weighed by who the captive is to the hold (court, commerce, bard,
    ; beggar/drunk, essential), wealth, a witnessed grab (steel tempts more than coin), failed
    ; searchers and greed. Captives with no hold crime faction never get here: DemandRansom refused.
    Int payChance = 55
    ActorBase vBase = akVictim.GetActorBase()
    If vBase && vBase.IsEssential()
        payChance += 15
    EndIf
    Faction facJarl      = Game.GetFormFromFile(0x00050920, "Skyrim.esm") as Faction
    Faction facSteward   = Game.GetFormFromFile(0x00050922, "Skyrim.esm") as Faction
    Faction facMerchant  = Game.GetFormFromFile(0x00051596, "Skyrim.esm") as Faction
    Faction facInnkeeper = Game.GetFormFromFile(0x0005091B, "Skyrim.esm") as Faction
    Faction facBard      = Game.GetFormFromFile(0x00053514, "Skyrim.esm") as Faction
    Faction facBeggar    = Game.GetFormFromFile(0x00060028, "Skyrim.esm") as Faction
    Faction facDrunk     = Game.GetFormFromFile(0x00060027, "Skyrim.esm") as Faction
    If (facJarl && akVictim.IsInFaction(facJarl)) || (facSteward && akVictim.IsInFaction(facSteward))
        payChance += 25
    ElseIf (facMerchant && akVictim.IsInFaction(facMerchant)) || (facInnkeeper && akVictim.IsInFaction(facInnkeeper))
        payChance += 15
    ElseIf facBard && akVictim.IsInFaction(facBard)
        payChance += 5
    EndIf
    If (facBeggar && akVictim.IsInFaction(facBeggar)) || (facDrunk && akVictim.IsInFaction(facDrunk))
        payChance -= 45
    EndIf
    Int vGold = akVictim.GetItemCount(Game.GetForm(0x0000000F))
    Bool vHasHome = SeverActionsNative.GetActorHomeCellName(akVictim) != ""
    If vGold >= 300
        payChance += 10
    ElseIf vGold >= 100
        payChance += 5
    EndIf
    If vHasHome
        payChance += 10
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_WITNESSED)
        payChance -= 20
    EndIf
    ; Desperation premium: the hold's searchers already failed (dead or talked down).
    If StorageUtil.GetIntValue(akVictim, "SA_KidnapSteelFailed", 0) == 1
        payChance += 25
    EndIf
    ; Greed dock: recompute the fair price (MIRRORS DemandRansom's formula, wealth terms
    ; included); over 1.5x fair costs 15, over 3x costs 35.
    Int fairAmount = 400 + akVictim.GetLevel() * 30
    If vBase && vBase.IsEssential()
        fairAmount += 600
    EndIf
    If fairAmount > 4000
        fairAmount = 4000
    EndIf
    fairAmount += vGold / 2
    If vHasHome
        fairAmount += 400
    EndIf
    If fairAmount > 4500
        fairAmount = 4500
    EndIf
    If amount > fairAmount * 3
        payChance -= 35
    ElseIf amount * 2 > fairAmount * 3
        payChance -= 15
    EndIf

    If payChance < 5
        payChance = 5
    ElseIf payChance > 95
        payChance = 95
    EndIf
    Debug.Trace("[SeverActions_Kidnap] Kidnap: ransom resolve for " + vName + " - payChance=" + payChance)

    If Utility.RandomInt(0, 99) < payChance
        SeverActionsNativeExt.Native_Kidnap_SetRansomState(akVictim, KIDNAP_RANSOM_PAID)
        Game.GetPlayer().AddItem(Game.GetForm(0x0000000F), amount, true)
        SeverActionsNativeExt.Native_Kidnap_RequestRansomLetter(akVictim, true, stewardName)
        If steward
            SeverActionsNative.Native_AddMemory(steward, \
                "As steward I handled the ransom of " + vName + " - I arranged payment of " + amount + " gold to " + plName + "'s go-between for " + vName + "'s safe return, and I signed the letter that went with it myself. The hold expects " + vName + " released promptly and whole; if they are not, I will see steel sent instead of coin.", \
                0.8, "EXPERIENCE", "grim", "", "[\"ransom\"]", "[]")
        EndIf
        SkyrimNetApi.RegisterPersistentEvent( \
            "The ransom for " + vName + " has been paid - " + amount + " gold delivered to " + plName + ". " + vName + "'s people now expect their prompt release; keeping them would be a betrayal of the bargain.", \
            Game.GetPlayer(), akVictim)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.ransomWasPaid", ("" + vName), ("" + amount)))
        Debug.Trace("[SeverActions_Kidnap] Kidnap: ransom PAID (" + amount + "g) for " + vName)
    Else
        SeverActionsNativeExt.Native_Kidnap_SetRansomState(akVictim, KIDNAP_RANSOM_REFUSED)
        SeverActionsNativeExt.Native_Kidnap_RequestRansomLetter(akVictim, false, stewardName)
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_SEARCH)
            ; Their searchers already came and went: steel is spent, so the give-up clock
            ; starts now.
            StorageUtil.SetFloatValue(akVictim, "SA_KidnapSteelSpentGT", Utility.GetCurrentGameTime())
            StorageUtil.SetIntValue(akVictim, "SA_KidnapSteelFailed", 1)
        EndIf
        If steward
            SeverActionsNative.Native_AddMemory(steward, \
                "As steward I refused the ransom demanded for " + vName + " - " + amount + " gold to brigands buys nothing but more brigands. I signed the refusal myself, and I would sooner spend that coin on hired steel to bring " + vName + " home.", \
                0.8, "EXPERIENCE", "defiant", "", "[\"ransom\"]", "[]")
        EndIf
        SkyrimNetApi.RegisterPersistentEvent( \
            "The ransom demand for " + vName + " was refused - their people would sooner hire steel than pay coin.", \
            Game.GetPlayer(), akVictim)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.ransomDemandRefused", ("" + vName)))
        Debug.Trace("[SeverActions_Kidnap] Kidnap: ransom REFUSED for " + vName)
    EndIf
EndFunction

Actor Function _GetHoldSteward(Faction akCrimeFac)
    {The real steward NPC of a vanilla hold's crime faction, found by NAME (NND/rename
     tolerant); None for modded holds or when unresolvable, and callers fall back to the
     faceless steward. The FormIDs are verified against the load order: they are not one
     contiguous block, so never guess one.}
    If !akCrimeFac
        Return None
    EndIf
    Int fid = akCrimeFac.GetFormID()
    String sName = ""
    If fid == 0x000267EA        ; CrimeFactionWhiterun
        sName = "Proventus Avenicci"
    ElseIf fid == 0x000267E3    ; CrimeFactionEastmarch
        sName = "Jorleif"
    ElseIf fid == 0x00029DB0    ; CrimeFactionHaafingar
        sName = "Falk Firebeard"
    ElseIf fid == 0x00028170    ; CrimeFactionFalkreath
        sName = "Nenya"
    ElseIf fid == 0x0002816F    ; CrimeFactionWinterhold
        sName = "Malur Seloth"
    ElseIf fid == 0x0002816E    ; CrimeFactionPale
        sName = "Bulfrek"
    ElseIf fid == 0x0002816D    ; CrimeFactionHjaalmarch
        sName = "Aslfur"
    ElseIf fid == 0x0002816C    ; CrimeFactionReach
        sName = "Raerek"
    ElseIf fid == 0x0002816B    ; CrimeFactionRift
        sName = "Anuriel"
    EndIf
    If sName == ""
        Return None
    EndIf
    Return SeverActionsNativeExt.Native_Kidnap_FindActorByName(sName)
EndFunction

Function _TearDownHold(Actor akVictim)
    {Remove ONLY the hold pieces (furniture tie, sit package, alias seat, furniture LinkedRef,
     placed marker, loose-captivity sandbox, the pin and pose); the hood, pacify faction,
     captured AVs and the store entry stay. Used when re-taking or re-binding a held captive.}
    ; Re-taking cuts a furniture tie: a stale SeverKidnap_TiedTo would make _BindCaptive skip
    ; every rope teardown at the new hold.
    _ClearFurnitureTie(akVictim)
    Keyword furnKW = SeverActions_FurnitureLib.TargetKeyword()
    Package sitPkg = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
    If sitPkg
        ActorUtil.RemovePackageOverride(akVictim, sitPkg)
    EndIf
    ; The alias seat goes with the hold (re-binds refill a fresh slot).
    _FreeCaptiveAlias(akVictim)
    If furnKW
        SeverActionsNative.LinkedRef_Clear(akVictim, furnKW)
    EndIf
    ObjectReference oldMarker = SeverActionsNativeExt.Native_Kidnap_GetMarker(akVictim)
    If oldMarker
        oldMarker.Disable()
        oldMarker.Delete()
    EndIf
    ; Loose-captivity pieces: UntieCaptive's marker-anchored PrisonerSandBox and its LinkedRef
    ; (the guard sandbox too). Safe no-ops otherwise.
    Package guardPkgTD = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
    If guardPkgTD
        ActorUtil.RemovePackageOverride(akVictim, guardPkgTD)
    EndIf
    SeverActions_Arrest arrTD = _Arrest()
    If arrTD && arrTD.SeverActions_PrisonerSandBox
        ActorUtil.RemovePackageOverride(akVictim, arrTD.SeverActions_PrisonerSandBox)
    EndIf
    If arrTD && arrTD.SeverActions_SandboxAnchorKW
        SeverActionsNative.LinkedRef_Clear(akVictim, arrTD.SeverActions_SandboxAnchorKW)
    EndIf
    SeverActionsNativeExt.Native_Kidnap_SetHeld(akVictim, None)
    ; Release the standing-bound pin so a moved restraint captive can walk the relocation leg
    ; (a no-op for kidnap captives); IdleForceDefaultState drops the bound offset.
    akVictim.SetDontMove(false)
    Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
    ; The pose is gone: clear the posed flag, or it suppresses every later re-play.
    StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 0)
    akVictim.EvaluatePackage()
EndFunction

Function HandleKidnapTravelComplete(Actor npc, String tag, String status)
    {Called by this script's canonical OnTravelComplete for the kidnap_* tags (M-E), which
     splits strArg's "<tag>|<status>"; status is "arrived", "cancelled" or another terminal word.}
    If !npc
        Return
    EndIf

    ; A "cancelled" completion only counts while its leg is still the current phase: in
    ; journey-fallback mode leg 2's BeginJourney cancels the still-live leg-1 handle, and that
    ; async kidnap_grab|cancelled must not unwind the grab that just succeeded.
    Actor tcVictim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(npc)
    If tag == "kidnap_grab"
        If status == "cancelled"
            If tcVictim && SeverActionsNativeExt.Native_Kidnap_GetPhase(tcVictim) == 1
                _AbortKidnap(npc)
            EndIf
        Else
            ; Any other terminal status: the grab resolves off-screen regardless.
            _OnKidnapGrabResolved(npc)
        EndIf
    ElseIf tag == "kidnap_transport"
        If status == "cancelled"
            If tcVictim && SeverActionsNativeExt.Native_Kidnap_GetPhase(tcVictim) == 2
                _AbortKidnap(npc)
            EndIf
        Else
            _OnKidnapTransportResolved(npc, status)
        EndIf
    EndIf
EndFunction

Function _KidnapLegWatchdog(Actor akKidnapper, Actor akVictim, ObjectReference akGoal, Bool abTimeJumped = false)
    {Progress backstops for an in-flight leg (alias or orchestrator mode), each teleporting the
     kidnapper to the goal only while unloaded and outside the roadside radius: (1) 4
     consecutive unobserved ticks (~2 min); (2) the leg's game-time deadline (while loaded, they
     give up instead); (3) abTimeJumped (a wait, sleep or fast travel of >= 1 game hour) skips
     the 4-tick patience.}
    If !akGoal
        Return
    EndIf
    Float deadline = SeverActionsNativeExt.Native_Kidnap_GetLegDeadline(akVictim)
    Bool deadlinePassed = deadline > 0.0 && Utility.GetCurrentGameTime() > deadline
    If akKidnapper.Is3DLoaded() && !deadlinePassed
        SeverActionsNativeExt.Native_Kidnap_BumpOffscreenTicks(akVictim, true)
        Return
    EndIf
    ; Loaded past the deadline: an on-screen pathing failure (blocked door, navmesh dead end)
    ; would stall forever, and teleporting in view is not an option, so they give up.
    If akKidnapper.Is3DLoaded() && deadlinePassed
        Debug.Trace("[SeverActions_Kidnap] Kidnap: leg deadline passed while loaded - giving up")
        _AbortKidnap(akKidnapper)
        Return
    EndIf
    If !akKidnapper.Is3DLoaded()
        Int ticks = SeverActionsNativeExt.Native_Kidnap_BumpOffscreenTicks(akVictim, false)
        If ticks < 4 && !deadlinePassed && !abTimeJumped
            Return
        EndIf
        ; Roadside hold: with the player near the pair (persistent actors keep real positions
        ; off-screen), keep them walking so the player can intercept. Ticks are NOT reset, so
        ; the fast-forward resumes once the player leaves. Cross-worldspace GetDistance is huge
        ; and falls through to the teleport.
        If akKidnapper.GetDistance(Game.GetPlayer()) <= KIDNAP_ROADSIDE_RADIUS
            Debug.Trace("[SeverActions_Kidnap] Kidnap: watchdog hold - player near the march, letting them walk")
            Return
        EndIf
        SeverActionsNativeExt.Native_Kidnap_BumpOffscreenTicks(akVictim, true)
        Debug.Trace("[SeverActions_Kidnap] Kidnap: watchdog fast-forward (deadline=" + deadlinePassed + ")")
        akKidnapper.MoveTo(akGoal)
        ; Escorted victim rides along off-screen so the pair doesn't strand.
        If akVictim && !akVictim.Is3DLoaded() && akVictim.GetParentCell() != akKidnapper.GetParentCell()
            akVictim.MoveTo(akKidnapper)
        EndIf
    EndIf
EndFunction

Function _EndDispatchAliases(Actor akKidnapper, Actor akVictim)
    {Hand the borrowed arrest-dispatch apparatus back: remove the alias-
     targeting travel package and clear any dispatch alias WE filled (only
     ours — checked by reference, so a real arrest's fills are untouched).}
    If !akKidnapper
        Return
    EndIf
    SeverActions_Arrest arrest = _Arrest()
    If arrest
        If arrest.SeverActions_DispatchJog
            ActorUtil.RemovePackageOverride(akKidnapper, arrest.SeverActions_DispatchJog)
        EndIf
        If arrest.SeverActions_DispatchWalk
            ActorUtil.RemovePackageOverride(akKidnapper, arrest.SeverActions_DispatchWalk)
        EndIf
        If arrest.DispatchGuardAlias && arrest.DispatchGuardAlias.GetReference() == akKidnapper
            arrest.DispatchGuardAlias.Clear()
            ; Target alias is ours too if the guard slot was ours (it holds
            ; either the victim or our destination marker).
            If arrest.DispatchTargetAlias
                arrest.DispatchTargetAlias.Clear()
            EndIf
        EndIf
        If akVictim && arrest.DispatchPrisonerAlias && arrest.DispatchPrisonerAlias.GetReference() == akVictim
            arrest.DispatchPrisonerAlias.Clear()
        EndIf
    EndIf
    ; Grab-leg arrival watch: fired registrations self-clear; this catches
    ; aborts and unwinds that end the borrow before contact.
    SeverActionsNativeExt.Arrival_Cancel(akKidnapper)
    If akVictim
        SeverActionsNativeExt.Native_Kidnap_SetAliasMode(akVictim, false)
        SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(akVictim, 0.0)
        SeverActionsNativeExt.Native_Kidnap_BumpOffscreenTicks(akVictim, true)
    EndIf
EndFunction

Function _EndGuardDuty(Actor akKidnapper)
    {Drop the anchored guard package + LinkedRef from a kidnapper. Safe
     no-op when they never guarded. The Sandbox() relax state is handled by
     the normal resume paths (StopSandbox / StartFollowing).}
    If !akKidnapper
        Return
    EndIf
    SeverActions_Arrest arrest = _Arrest()
    StorageUtil.UnsetIntValue(akKidnapper, "SeverKidnap_OnGuard")
    Package guardPkg = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
    If guardPkg
        ActorUtil.RemovePackageOverride(akKidnapper, guardPkg)
    EndIf
    If arrest
        ; PrisonerSandBox: UntieCaptive's loosened watch (older builds guarded with it too).
        If arrest.SeverActions_PrisonerSandBox
            ActorUtil.RemovePackageOverride(akKidnapper, arrest.SeverActions_PrisonerSandBox)
        EndIf
        If arrest.SeverActions_SandboxAnchorKW
            SeverActionsNative.LinkedRef_Clear(akKidnapper, arrest.SeverActions_SandboxAnchorKW)
        EndIf
    EndIf
    akKidnapper.EvaluatePackage()
EndFunction

Event OnKidnapGuardRecall(string eventName, string strArg, float numArg, Form sender)
    {The player called an NPC (follow, recruit, onboarding, wait or dismiss). A guarding
     kidnapper (phase 3) drops the guard package and the captive stays bound; mid-march
     (phase 2) they bind the victim on the spot and answer the call (MoveCaptive can relocate
     them later); pre-grab (phase 1) the kidnap aborts.}
    Actor a = sender as Actor
    If !a
        Return
    EndIf
    Actor jobVictim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(a)
    If !jobVictim
        Return
    EndIf
    Int jobPhase = SeverActionsNativeExt.Native_Kidnap_GetPhase(jobVictim)
    If jobPhase == 3
        Debug.Trace("[SeverActions_Kidnap] Kidnap: guard " + a.GetDisplayName() + " recalled from duty - captive stays bound")
        _EndGuardDuty(a)
    ElseIf jobPhase == 2
        ; With no destination anchor _BindCaptive places the marker where they stand;
        ; abGuard=false skips guard duty.
        Debug.Trace("[SeverActions_Kidnap] Kidnap: kidnapper recalled mid-march - binding on the spot")
        SeverActionsNativeExt.Native_Kidnap_SetDestAnchor(jobVictim, None)
        _BindCaptive(jobVictim, a, false)
    ElseIf jobPhase == 1
        Debug.Trace("[SeverActions_Kidnap] Kidnap: kidnapper recalled pre-grab - aborting")
        _AbortKidnap(a)
    EndIf
EndEvent

Function _EndKidnapTravel(Actor akKidnapper)
    {Remove the kidnap travel override + orphan-scan traveler registration.
     Safe no-op when nothing is applied. The follower-registry entry
     (OrphanCleanup_RegisterFollower) is a separate map and is untouched.}
    Package kidnapTravelPkg = SeverActionsNativeExt.Travel_GetSpeedPackage(SPEED_JOG)
    If kidnapTravelPkg
        ActorUtil.RemovePackageOverride(akKidnapper, kidnapTravelPkg)
    EndIf
    SeverActionsNative.OrphanCleanup_UnregisterTraveler(akKidnapper)
    ; Clear the traveling mark so the follower teleport/catch-up systems
    ; resume normal handling of this actor.
    SeverActionsNative.Native_SetTravelState(akKidnapper, "", "")
    akKidnapper.EvaluatePackage()
EndFunction

Function _OnKidnapGrabResolved(Actor akKidnapper)
    {Leg 1 done: seize the victim and start the march. Called from both the orchestrator
     completion (fallback mode) and KidnapTick (alias mode / same-cell detection).}
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akKidnapper)
    ; ATOMIC claim: the two resolution paths can both get here across suspension points, so
    ; compare-and-set phase 1 -> 2 under the store mutex and the loser returns.
    If victim && !victim.IsDead() && !SeverActionsNativeExt.Native_Kidnap_TryAdvancePhase(victim, 1, 2)
        Return  ; already resolved/claimed by the other path
    EndIf
    If !victim || victim.IsDead()
        If victim
            _DeleteKidnapHomeMarker(victim)
            SeverActionsNativeExt.Native_Kidnap_Clear(victim)
        EndIf
        _EndKidnapTravel(akKidnapper)
        _EndDispatchAliases(akKidnapper, victim)
        Return
    EndIf

    ; The grab-leg arrival watch may still be live if the tick or the travel completion
    ; resolved first; drop it so it cannot fire mid-march.
    SeverActionsNativeExt.Arrival_Cancel(akKidnapper)

    ; Re-taking a held captive (MoveCaptive): drop the old hold pieces. A re-take re-ties, so
    ; clear the loose-captivity flag too.
    If SeverActionsNativeExt.Native_Kidnap_GetMarker(victim)
        _TearDownHold(victim)
    EndIf
    SeverActionsNativeExt.Native_Kidnap_SetFlag(victim, KIDNAP_FLAG_UNBOUND, false)

    ; A fresh grab drops a persistent home marker at the pre-grab spot, BEFORE the pull: an
    ; escaped captive flees back here. Best-effort (PlaceAtMe off an unloaded actor can
    ; misplace); with no marker an escapee stays put.
    If SeverActionsNativeExt.Native_Kidnap_GetGrabTime(victim) <= 0.0 \
        && !SeverActionsNativeExt.Native_Kidnap_GetHomeMarker(victim)
        Static xmBase = Game.GetFormFromFile(0x00003B, "Skyrim.esm") as Static
        If xmBase
            ObjectReference homeM = victim.PlaceAtMe(xmBase, 1, true, false)
            If homeM
                SeverActionsNativeExt.Native_Kidnap_SetHomeMarker(victim, homeM)
            EndIf
        EndIf
    EndIf

    ; Off-screen grab: pull the victim to the kidnapper (for an unreachable interior target
    ; this IS the abduction).
    If victim.GetParentCell() != akKidnapper.GetParentCell() || victim.GetDistance(akKidnapper) > 400.0
        victim.MoveTo(akKidnapper)
    EndIf

    ; Pacify via the shared helper (capture-then-zero + prisoner faction).
    _PacifyCaptive(victim)
    SeverActions_Arrest arrest = _Arrest()

    ; Cuffs for the walk, equipped at SEIZURE, never at leg-1 launch (the victim would wear them
    ; about their day before the grab). Re-equipping a cuffed captive is a no-op. The kneel at
    ; _BindCaptive strips them; _UnbindCaptive removes them at release.
    If arrest && arrest.SeverActions_PrisonerCuffs
        victim.EquipItem(arrest.SeverActions_PrisonerCuffs, true, true)  ; abPreventRemoval, abSilent
    EndIf

    ; Consequences: stamp the grab record ONCE (a MoveCaptive re-take keeps the original).
    ; Jurisdiction = the victim's own crime faction (vanilla citizens belong to their hold's),
    ; so it resolves off-screen; bandits and wilderness spawns resolve None and draw no bounty,
    ; gossip or search. A moved RESTRAINT captive stamps nothing (KIDNAP_FLAG_RESTRAINT).
    If SeverActionsNativeExt.Native_Kidnap_GetGrabTime(victim) <= 0.0 \
        && !SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
        Faction grabCrimeFac = SeverActionsNativeExt.Hold_GetCrimeFaction(victim)
        SeverActionsNativeExt.Native_Kidnap_SetGrabInfo(victim, grabCrimeFac, Utility.GetCurrentGameTime())
        ; Witnessed: a third party (not the victim, not a follower) saw it; the hold knows now.
        If SeverActionsNativeExt.Native_Kidnap_IsGrabWitnessed(akKidnapper, victim, 1500.0)
            SeverActionsNativeExt.Native_Kidnap_SetFlag(victim, KIDNAP_FLAG_WITNESSED, true)
            If grabCrimeFac
                ; The DOER carries the bounty: the kidnapper's own tracked bounty, not the player's.
                SeverActionsNativeExt.Native_Bounty_ModFor(akKidnapper, grabCrimeFac, KIDNAP_BOUNTY)
                SeverActionsNativeExt.Native_Bounty_AddEventFor(akKidnapper, grabCrimeFac, KIDNAP_BOUNTY, "kidnapping", "")
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.abductionWitnessedBounty", ("" + KIDNAP_BOUNTY), ("" + akKidnapper.GetDisplayName())))
            EndIf
            SkyrimNetApi.RegisterEvent("kidnap_witnessed", \
                "Bystanders witnessed " + akKidnapper.GetDisplayName() + " seizing " + victim.GetDisplayName() + " - word of the abduction will spread.", \
                akKidnapper, victim)
            Debug.Trace("[SeverActions_Kidnap] Kidnap: grab was WITNESSED")
        EndIf
    EndIf

    ; Victim trails the kidnapper (the arrest escort): follow package on a LinkedRef, at 110 so
    ; it outranks the travel package (TRAVEL_PACKAGE_PRIORITY) while loaded.
    If arrest && arrest.SeverActions_FollowGuard_Prisoner && arrest.SeverActions_FollowTargetKW
        SeverActionsNative.LinkedRef_Set(victim, akKidnapper, arrest.SeverActions_FollowTargetKW)
        ActorUtil.AddPackageOverride(victim, arrest.SeverActions_FollowGuard_Prisoner, 110, 1)
        victim.EvaluatePackage()
    EndIf
    SeverActionsNativeExt.Native_Kidnap_SetPhase(victim, 2)  ; no-op: phase already claimed 1->2 at entry

    ; Leg 2 — march to the destination.
    If SeverActionsNativeExt.Native_Kidnap_GetAliasMode(victim) && arrest
        ; ALIAS MODE (the arrest return-leg trick): re-point the target alias at the destination.
        ; The victim rides DispatchPrisonerAlias so her escort AI keeps running unloaded and the
        ; pair emerges from interiors together.
        ObjectReference aliasDest = SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(victim)
        If aliasDest
            arrest.DispatchTargetAlias.Clear()
            arrest.DispatchTargetAlias.ForceRefTo(aliasDest)
            If arrest.DispatchPrisonerAlias && arrest.DispatchPrisonerAlias.GetReference() == None
                arrest.DispatchPrisonerAlias.ForceRefTo(victim)
            EndIf
            ; SWITCH packages (Jog -> Walk): a running procedure caches its target ref, so
            ; re-pointing the alias alone leaves the kidnapper chasing the victim. The new package
            ; forces a fresh evaluation (the arrest return leg swaps the same way).
            If arrest.SeverActions_DispatchJog
                ActorUtil.RemovePackageOverride(akKidnapper, arrest.SeverActions_DispatchJog)
            EndIf
            If arrest.SeverActions_DispatchWalk
                ActorUtil.AddPackageOverride(akKidnapper, arrest.SeverActions_DispatchWalk, arrest.PackagePriority, 1)
            EndIf
            akKidnapper.EvaluatePackage()
            SeverActionsNativeExt.Native_Kidnap_SetLegDeadline(victim, Utility.GetCurrentGameTime() + 0.5)
            Debug.Trace("[SeverActions_Kidnap] Kidnap: leg 2 (alias mode) - target alias re-pointed + Jog->Walk package swap")
        Else
            ; No destination survived — bind where they stand.
            _BindCaptive(victim, akKidnapper)
            Return
        EndIf
    Else
        ; FALLBACK: two journeys on the travel core to the destination anchor resolved at kidnap
        ; start. The victim's own journey keeps her high-process (Traveler pool alias),
        ; with the escort override on top. No greet on approach. KidnapTick detects arrival
        ; through Native_GetTravelState ("waiting").
        _EndKidnapTravel(akKidnapper)  ; strip the leg-1 override/registration
        String destName = SeverActionsNativeExt.Native_Kidnap_GetDestLabel(victim)
        ObjectReference legDest = SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(victim)
        Bool started = false
        If legDest && destName != ""
            started = SeverActions_TravelCore.BeginJourney(akKidnapper, legDest, destName, 48.0, false, SPEED_JOG, false, None)
            If started
                SeverActions_TravelCore.BeginJourney(victim, legDest, destName, 48.0, false, SPEED_JOG, false, None)
                ; Re-assert the escort on top of her journey's travel package.
                If arrest && arrest.SeverActions_FollowGuard_Prisoner
                    ActorUtil.AddPackageOverride(victim, arrest.SeverActions_FollowGuard_Prisoner, 110, 1)
                    victim.EvaluatePackage()
                EndIf
            EndIf
        EndIf
        Debug.Trace("[SeverActions_Kidnap] Kidnap: leg 2 (journey fallback) started=" + started + " dest '" + destName + "'")
        If !started
            ; No anchor or label, or the orchestrator refused: bind where they stand.
            _BindCaptive(victim, akKidnapper)
            Return
        EndIf
    EndIf

    ; March rope (Leash Framework, if present), over the walk package. The bind-in-place paths
    ; above Return first, so only a real march is roped; _BindCaptive takes it off.
    _AttachPhysicalLeash(victim, akKidnapper)

    ; The cuffs alone do not pose the hands: add the standing-bound offset idle (as
    ; PerformArrest does), AFTER the package work so no EvaluatePackage drops it.
    If arrest && arrest.OffsetBoundStandingStart
        victim.PlayIdle(arrest.OffsetBoundStandingStart)
    EndIf

    If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
        SkyrimNetApi.RegisterPersistentEvent( \
            akKidnapper.GetDisplayName() + " is openly escorting the restrained " + victim.GetDisplayName() + " to a new place of holding.", \
            akKidnapper, victim)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isMoving", ("" + akKidnapper.GetDisplayName()), ("" + victim.GetDisplayName())))
    Else
        SkyrimNetApi.RegisterPersistentEvent( \
            akKidnapper.GetDisplayName() + " has seized " + victim.GetDisplayName() + " and is marching them off.", \
            akKidnapper, victim)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasSeized", ("" + akKidnapper.GetDisplayName()), ("" + victim.GetDisplayName())))
    EndIf
EndFunction

Function _OnKidnapTransportResolved(Actor akKidnapper, String status)
    {Leg 2 done: bind and hood at the destination. A non-arrived terminal status
     force-finalizes (teleport the pair to the marker, then bind). "arrived" relocates too when
     the kidnapper is not actually there: an interior destination gives the arrival monitor
     cross-cell distance garbage, and it can report arrival seconds in.}
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akKidnapper)
    If !victim || victim.IsDead()
        If victim
            _DeleteKidnapHomeMarker(victim)
            SeverActionsNativeExt.Native_Kidnap_Clear(victim)
        EndIf
        _EndKidnapTravel(akKidnapper)
        _EndDispatchAliases(akKidnapper, victim)
        _CancelTravel(akKidnapper)
        Return
    EndIf
    ; End the kidnapper's journey BEFORE the bind so its arrival sandbox does not fight the
    ; guard anchor (_BindCaptive ends the victim's). The handle is already terminal, so no
    ; "cancelled" event comes back.
    _CancelTravel(akKidnapper)
    ObjectReference destMarker = SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(victim)
    If destMarker
        Bool needsRelocate = (status != "arrived")
        If !needsRelocate
            needsRelocate = (akKidnapper.GetParentCell() != destMarker.GetParentCell()) \
                || (akKidnapper.GetDistance(destMarker) > 600.0)
        EndIf
        If needsRelocate
            akKidnapper.MoveTo(destMarker)
        EndIf
    EndIf
    If victim.GetParentCell() != akKidnapper.GetParentCell() || victim.GetDistance(akKidnapper) > 400.0
        victim.MoveTo(akKidnapper)
    EndIf
    _BindCaptive(victim, akKidnapper)
EndFunction

Function _BindCaptive(Actor akVictim, Actor akKidnapper, Bool abGuard = true, Bool abSilent = false)
    {The single bind choke point. Kidnap: a force-persistent BoundCaptiveMarker at the
     destination anchor, the Sit package via the FurnitureTargetKW LinkedRef, and the Execution
     Hood. Restraint: pinned standing bound, no hood. abGuard=false skips guard duty (a recalled
     kidnapper answers the call instead); abSilent leaves the restraint narration to the caller.}
    ; The kidnapper's job is done: drop their travel override and hand back the borrowed
    ; dispatch aliases.
    _EndKidnapTravel(akKidnapper)
    _EndDispatchAliases(akKidnapper, akVictim)

    ; Double-bind guard: several async callers reach here and SetHeld stores one marker, so a
    ; second bind would orphan the first force-persistent marker. Tear an existing hold down.
    If SeverActionsNativeExt.Native_Kidnap_GetMarker(akVictim)
        _TearDownHold(akVictim)
    EndIf

    SeverActions_Arrest arrest = _Arrest()
    ; Binding re-ties: drop the loose-captivity flag (no-op when never untied).
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_UNBOUND, false)
    Bool bindIsRestraint = SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
    ; Trailing (restraint relocation): the bind fires on the ESCORT's arrival while the captive
    ; may still be walking in. Pinning them would strand them short of the hold, so keep the
    ; escort-follow package and let the phase-3 tick pin and pose them once they close in.
    ; Measured against where the hold goes (the destination anchor, else the captor below).
    ObjectReference trailRef = SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(akVictim)
    If !trailRef
        trailRef = akKidnapper
    EndIf
    Bool bindTrailing = bindIsRestraint && akVictim.Is3DLoaded() \
        && (!_InSameSpace(akVictim, trailRef) || akVictim.GetDistance(trailRef) > 300.0)
    ; March over: the transport rope comes off (a HELD captive is roped only by LeashCaptive).
    ; A trailing captive keeps it until the tick's deferred pin routes back here. A FURNITURE
    ; TIE keeps its rope: this is also the phase-3 tick's re-pin, and the tie is cut only by
    ; _ClearFurnitureTie on the paths that free or re-take the captive.
    If !bindTrailing && !_GetFurnitureTie(akVictim)
        _DetachPhysicalLeash(akVictim)
    EndIf

    ; End the escort-follow (kept on a trailing captive: it walks them the last stretch) and
    ; the victim's own persistence journey.
    If arrest && !bindTrailing
        If arrest.SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(akVictim, arrest.SeverActions_FollowGuard_Prisoner)
        EndIf
        If arrest.SeverActions_FollowTargetKW
            SeverActionsNative.LinkedRef_Clear(akVictim, arrest.SeverActions_FollowTargetKW)
        EndIf
    EndIf
    _CancelTravel(akVictim)

    ; The BoundCaptiveMarker driven the vanilla way (a pure Sit package on the FurnitureTargetKW
    ; linked ref), so the pose self-restores on cell reload. NOT registered with
    ; FurnitureManager (its distance auto-cleanup would free the captive); the OnOrphanCleanup
    ; handlers skip kidnap participants instead.
    ObjectReference holdMarker = None
    Keyword furnKW = SeverActions_FurnitureLib.TargetKeyword()
    Furniture markerBase = Game.GetFormFromFile(KIDNAP_MARKER_FORMID, "Skyrim.esm") as Furniture
    Package sitPkg = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
    ; Place the marker AT THE DESTINATION ANCHOR (a persistent, navmeshed ref): PlaceAtMe from a
    ; persistent world ref works loaded or not, where PlaceAtMe off an unloaded ACTOR misplaces.
    ; abForcePersist=TRUE is load-bearing: a default PlaceAtMe ref unloads with its cell, and the
    ; captive's low-process Sit package then dereferences the gone furniture (BGSProcedureSit CTD).
    ObjectReference destAnchor = SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(akVictim)
    ; No anchor (recall bind, degraded binds): stop kidnap_context narrating the ordered
    ; destination.
    If !destAnchor
        SeverActionsNativeExt.Native_Kidnap_SetDestLabel(akVictim, _PlaceLabel(akVictim))
    EndIf
    If markerBase && sitPkg && furnKW
        If destAnchor
            holdMarker = destAnchor.PlaceAtMe(markerBase, 1, true)
        EndIf
        ; No destination: place at the CAPTOR (a reachable navmesh spot). A marker under the
        ; victim puts them inside the furniture volume, where furniture entry fails to seat them.
        If !holdMarker
            holdMarker = akKidnapper.PlaceAtMe(markerBase, 1, true)
        EndIf
        If !holdMarker
            holdMarker = akVictim.PlaceAtMe(markerBase, 1, true)
        EndIf
        If holdMarker
            ; KIDNAP (kneel) is furniture-driven: EvaluatePackage below paths the victim INTO the
            ; furniture entry, which is what engages the kneel. Teleporting onto the marker puts
            ; them inside the volume and entry no-ops, so MoveTo only when genuinely far.
            ; RESTRAIN (standing bound) skips the furniture (a busy NPC froze instead of
            ; kneeling): pin them in place and play the standing offset idle after
            ; EvaluatePackage. Re-pinned every tick, re-posed on load; _UnbindCaptive releases.
            If bindIsRestraint
                If !bindTrailing
                    akVictim.SetDontMove(true)
                EndIf
            Else
                If akVictim.GetParentCell() != holdMarker.GetParentCell() || akVictim.GetDistance(holdMarker) > 300.0
                    akVictim.MoveTo(holdMarker)
                EndIf
                SeverActionsNativeExt.LinkedRef_SetPermanent(akVictim, holdMarker, furnKW)
                ActorUtil.AddPackageOverride(akVictim, sitPkg, 95, 1)
                ; Also seat the sit package through the captive-alias pool (see
                ; CAPTIVE_QUEST_FORMID). The override stays, and so does the LinkedRef: the alias
                ; package anchors through it too.
                Int captiveAliasIdx = FindFreeCaptiveAlias()
                If captiveAliasIdx >= 0
                    ReferenceAlias cal = GetCaptiveAlias(captiveAliasIdx)
                    If cal
                        cal.ForceRefTo(akVictim)
                        SeverActionsNativeExt.Native_Kidnap_SetAliasIndex(akVictim, captiveAliasIdx)
                        DebugMsg("CaptiveAlias: seated " + akVictim.GetDisplayName() + " in alias " + captiveAliasIdx)
                    EndIf
                ElseIf GetCaptiveQuest()
                    DebugMsg("CaptiveAlias: pool exhausted (" + CAPTIVE_ALIAS_POOL_SIZE + " slots) — " + akVictim.GetDisplayName() + " stays on the override hold")
                EndIf
            EndIf
            ; The guard anchors to the marker (at the captor) in either style. Only a guard: a
            ; captor who is not standing watch (UnleashCaptive's may be elsewhere, or dead)
            ; stays put.
            If abGuard && akKidnapper.GetParentCell() != holdMarker.GetParentCell()
                akKidnapper.MoveTo(holdMarker)
            EndIf
            ; Marker schema 2 = persistent marker; KidnapTick strips and re-binds pre-v2 holds.
            SeverActionsNativeExt.Native_Kidnap_SetMarkerSchema(akVictim, 2)
        EndIf
    EndIf
    Debug.Trace("[SeverActions_Kidnap] Kidnap: binding " + akVictim.GetDisplayName() + " (marker=" + holdMarker + ", cell match=" + (akVictim.GetParentCell() == akKidnapper.GetParentCell()) + ")")

    ; Hood, equip-locked; a RESTRAINT hold stays bare-headed (kidnap_context narrates that).
    If !bindIsRestraint
        ; Kneel: the furniture supplies the bound-hands pose, so drop the march's offset (it
        ; would layer over the kneel) and the walk cuffs. The standing restraint keeps both.
        Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
        If arrest && arrest.SeverActions_PrisonerCuffs
            akVictim.UnequipItem(arrest.SeverActions_PrisonerCuffs, false, true)
            akVictim.RemoveItem(arrest.SeverActions_PrisonerCuffs, 1, true)
        EndIf
        Armor hood = Game.GetFormFromFile(KIDNAP_HOOD_FORMID, "Skyrim.esm") as Armor
        If hood
            akVictim.EquipItem(hood, true, true)  ; abPreventRemoval, abSilent
        EndIf
    EndIf

    akVictim.EvaluatePackage()
    ; Standing restraint: play the offset LAST so the package re-eval cannot overwrite it. The
    ; posed flag pairs with KidnapTick's unloaded->loaded re-play.
    If bindIsRestraint
        If bindTrailing
            ; Deferred to the phase-3 tick (flag left 0; the march offset holds the look).
            StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 0)
        ElseIf arrest && arrest.OffsetBoundStandingStart
            If akVictim.PlayIdle(arrest.OffsetBoundStandingStart)
                StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 1)
            Else
                StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 0)
            EndIf
        EndIf
    EndIf
    SeverActionsNativeExt.Native_Kidnap_SetHeld(akVictim, holdMarker)

    ; Delete the MoveCaptiveHere pin: it was only the march's destination anchor, and a
    ; force-persistent ref would leak forever. Every move-here bind passes here exactly once.
    ObjectReference movePin = StorageUtil.GetFormValue(akVictim, "SeverKidnap_MovePin") as ObjectReference
    If movePin
        movePin.Disable()
        movePin.Delete()
        StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_MovePin")
    EndIf

    If abGuard
        ; The kidnapper stands guard, ANCHORED: KidnapGuardSandbox (r=180) on the hold marker keeps
        ; them in the room. A follower also gets Sandbox() for the relax-state bookkeeping
        ; (WaitingForPlayer, waiting faction, recall paths); a non-follower restrainer (guard,
        ; housecarl) must stay out of follower machinery. Released by _EndGuardDuty.
        If _IsFollower(akKidnapper)
            SeverActions_ModuleBase.CallBool("followers", "sandbox", akKidnapper)
        EndIf
        Package guardPkg = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
        If holdMarker && guardPkg && arrest && arrest.SeverActions_SandboxAnchorKW
            SeverActionsNativeExt.LinkedRef_SetPermanent(akKidnapper, holdMarker, arrest.SeverActions_SandboxAnchorKW)
            ; Re-bind after loose captivity: drop the wide watch sandbox so
            ; the tight guard package is unambiguous at its priority.
            If arrest.SeverActions_PrisonerSandBox
                ActorUtil.RemovePackageOverride(akKidnapper, arrest.SeverActions_PrisonerSandBox)
            EndIf
            ActorUtil.AddPackageOverride(akKidnapper, guardPkg, 110, 1)
            akKidnapper.EvaluatePackage()
            ; While set, KidnapTick's station heal re-posts a strayed guard (teammate drag on
            ; fast travel, door leaks); _EndGuardDuty clears it.
            StorageUtil.SetIntValue(akKidnapper, "SeverKidnap_OnGuard", 1)
        EndIf
    EndIf
    ; Recall hook (see OnKidnapGuardRecall). No other script on this quest registers the event
    ; (one ModEvent name per quest form); Hearth's listener is on its own form.
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnKidnapGuardRecall")

    If bindIsRestraint
        ; abSilent: the caller narrates a larger act this bind is half of (the tie-and-lead
        ; hotkey), where "held standing in plain sight" would contradict being led away.
        If !abSilent
            NarrateRestrainedInPlace(akVictim, akKidnapper)
        EndIf
    Else
        SkyrimNetApi.RegisterPersistentEvent( \
            akKidnapper.GetDisplayName() + " has delivered " + akVictim.GetDisplayName() + ", now bound and hooded, as instructed.", \
            akKidnapper, akVictim)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasBeenBoundAndHooded", ("" + akVictim.GetDisplayName())))
    EndIf
EndFunction

Function _FireKidnapReleaseConsequences(Actor akVictim)
    {A victim actually SEIZED (phase 2+) walks free: a grudge memory, and for an unwitnessed
     grab (and no paid ransom) they report it and the bounty lands now. The hold's "vanished"
     gossip gives way to word they turned up. A pre-grab abort is a non-event. Call BEFORE
     Native_Kidnap_Clear (reads the entry).}
    If !akVictim
        Return
    EndIf
    ; Ahead of the phase gate: a re-taken captive (phase 1) keeps the gossip flag.
    _RetractVanishedGossip(akVictim, akVictim.GetDisplayName() + " has turned up alive after days missing - people want to know where they were")
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim) < 2
        Return
    EndIf

    Actor kd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    String kdName = "someone"
    If kd
        kdName = kd.GetDisplayName()
    EndIf
    String plName = Game.GetPlayer().GetDisplayName()
    Bool relRansomPaid = SeverActionsNativeExt.Native_Kidnap_GetRansomState(akVictim) == KIDNAP_RANSOM_PAID
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
        ; Restraint: indignity, not abduction trauma, so a lower weight.
        SeverActionsNative.Native_AddMemory(akVictim, \
            "I was restrained by " + kdName + " - my hands bound, made to stand helpless in front of everyone until they saw fit to release me. I know exactly who did it, and I remember how it felt.", \
            0.6, "EXPERIENCE", "indignant", "", "[\"restrained\"]", "[]")
    ElseIf relRansomPaid
        ; Ransomed home per the bargain: still a grudge, but the deal was honored, so the LLM
        ; must not play them as intending to report it.
        SeverActionsNative.Native_AddMemory(akVictim, \
            "I was abducted by " + kdName + " and held for ransom on " + plName + "'s orders. My people paid for my return, and - I will grant this much - the bargain was honored: I was released as agreed. The coin settled the matter in the law's eyes, but I remember every hour of it.", \
            0.8, "EXPERIENCE", "bitter", "", "[\"kidnap\",\"grudge\"]", "[]")
    Else
        SeverActionsNative.Native_AddMemory(akVictim, \
            "I was abducted by " + kdName + " - seized, bound, and hooded, held against my will on " + plName + "'s orders. I know " + kdName + "'s voice and face, and I will not forgive or forget what was done to me.", \
            0.9, "EXPERIENCE", "traumatized", "", "[\"kidnap\",\"grudge\"]", "[]")
    EndIf

    ; Retire the interrogation directive: it is present-tense and would shape every
    ; post-release conversation. Supersede it with a past-tense record.
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_INTERROGATED)
        SeverActionsNative.Native_AddMemory(akVictim, \
            "While I was held, I was interrogated and gave up things I knew under duress. That is over now - I am free, and I owe my captors nothing further.", \
            0.6, "EXPERIENCE", "resentful", "", "[\"interrogation\"]", "[]")
    EndIf

    If relRansomPaid
        ; A paid ransom + release honors the bargain: the coin settled it, so no report. A
        ; witnessed grab keeps the bounty it charged at the grab.
        Debug.Trace("[SeverActions_Kidnap] Kidnap: release completes a PAID ransom - no report, the coin settled it")
    ElseIf !SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_WITNESSED)
        Faction repFac = SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(akVictim)
        If repFac
            ; The freed victim names the DOER; kd None falls back to the player entry inside the
            ; native.
            SeverActionsNativeExt.Native_Bounty_ModFor(kd, repFac, KIDNAP_BOUNTY)
            SeverActionsNativeExt.Native_Bounty_AddEventFor(kd, repFac, KIDNAP_BOUNTY, "kidnapping", "")
            Debug.Notification(akVictim.GetDisplayName() + " reported the abduction. +" + KIDNAP_BOUNTY + " bounty on " + kdName + ".")
            Debug.Trace("[SeverActions_Kidnap] Kidnap: released victim reported the crime")
        EndIf
    EndIf
EndFunction

Bool Function _IsCaptiveGuarded(Actor akVictim)
    {Is anyone watching this captive: the player, the kidnapper, a registered follower or an
     Enterprises retainer (a jailer assigned to work at the hold), in the same cell within
     KIDNAP_GUARD_RADIUS. Unloaded persistent actors keep their parked positions, so this
     works while the player is away.}
    Cell c = akVictim.GetParentCell()
    If !c
        Return true  ; indeterminate — fail safe, no escape credit
    EndIf
    Actor player = Game.GetPlayer()
    If player.GetParentCell() == c && player.GetDistance(akVictim) <= KIDNAP_GUARD_RADIUS
        Return true
    EndIf
    Actor kd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    If kd && !kd.IsDead() && kd.GetParentCell() == c && kd.GetDistance(akVictim) <= KIDNAP_GUARD_RADIUS
        Return true
    EndIf
    Actor[] fl = SeverActionsNativeExt.Native_GetActiveFollowerRoster()
    Int i = 0
    While i < fl.Length
        If fl[i] && fl[i] != kd && fl[i] != akVictim && !fl[i].IsDead() \
            && fl[i].GetParentCell() == c && fl[i].GetDistance(akVictim) <= KIDNAP_GUARD_RADIUS
            Return true
        EndIf
        i += 1
    EndWhile
    Int rc = SeverActionsNativeExt2.Venture_Count()
    i = 0
    While i < rc
        Actor r = SeverActionsNativeExt2.Venture_GetAssigneeAt(i)
        ; r != akVictim: a kidnapped retainer would count as their own jailer.
        If r && r != akVictim && !r.IsDead() && r.GetParentCell() == c && r.GetDistance(akVictim) <= KIDNAP_GUARD_RADIUS
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

Function _DeleteKidnapHomeMarker(Actor akVictim)
    {Delete the persistent pre-grab home marker. Call before every
     Native_Kidnap_Clear — a cleared entry orphans the ref forever.}
    ObjectReference hm = SeverActionsNativeExt.Native_Kidnap_GetHomeMarker(akVictim)
    If hm
        hm.Disable()
        hm.Delete()
    EndIf
EndFunction

Function _EscapeCaptive(Actor akVictim)
    {An unguarded captive's escape roll passed: they work loose and flee home (the pre-grab
     marker). Full release consequences fire.}
    Debug.Trace("[SeverActions_Kidnap] Kidnap: " + akVictim.GetDisplayName() + " ESCAPES (unguarded)")
    ; Capture narration state BEFORE the entry is cleared below.
    Bool escRestraint = SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
    Bool escRansomPending = SeverActionsNativeExt.Native_Kidnap_GetRansomState(akVictim) == KIDNAP_RANSOM_PENDING
    Actor kd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    _FireKidnapReleaseConsequences(akVictim)
    If kd
        _EndGuardDuty(kd)
        _EndDispatchAliases(kd, akVictim)
    EndIf
    _FreeCaptiveAlias(akVictim)  ; _UnbindCaptive does this too — explicit for clarity
    _UnbindCaptive(akVictim)
    ; Flee home, teleporting only while unloaded (never in front of the player).
    ObjectReference home = SeverActionsNativeExt.Native_Kidnap_GetHomeMarker(akVictim)
    If home && !akVictim.Is3DLoaded()
        akVictim.MoveTo(home)
    EndIf
    _DeleteKidnapHomeMarker(akVictim)
    SeverActionsNativeExt.Native_Kidnap_Clear(akVictim)

    If escRestraint
        ; Restraint: no "fled home" (a never-moved restraint has no home marker).
        SkyrimNetApi.RegisterPersistentEvent( \
            akVictim.GetDisplayName() + " slipped their bonds - left unwatched too long, they worked their hands free and walked off.", \
            Game.GetPlayer(), akVictim)
    Else
        SkyrimNetApi.RegisterPersistentEvent( \
            akVictim.GetDisplayName() + " has escaped captivity - left unguarded too long, they worked free of their bonds and fled home.", \
            Game.GetPlayer(), akVictim)
    EndIf
    If escRansomPending
        ; A pending ransom collapses: the player was told an answer would come.
        SkyrimNetApi.RegisterPersistentEvent( \
            "Word spreads that " + akVictim.GetDisplayName() + " is free - the ransom demand collapses unanswered.", \
            Game.GetPlayer(), akVictim)
    EndIf
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasEscapedCaptivity", ("" + akVictim.GetDisplayName())))
EndFunction

Function _OnCaptiveDied(Actor akVictim)
    {A captive died. When the hold knows (witnessed grab or gossip) it is charged as murder on
     the captor's bounty; a quiet captivity leaves no legal trail. Cleans up all state.}
    String vName = akVictim.GetDisplayName()
    Int diedPhase = SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim)
    Bool diedRansomPending = SeverActionsNativeExt.Native_Kidnap_GetRansomState(akVictim) == KIDNAP_RANSOM_PENDING
    Debug.Trace("[SeverActions_Kidnap] Kidnap: " + vName + " DIED in captivity (phase " + diedPhase + ")")

    Faction fac = SeverActionsNativeExt.Native_Kidnap_GetGrabFaction(akVictim)
    Bool holdKnows = SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_WITNESSED) \
        || SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_GOSSIP)
    _RetractVanishedGossip(akVictim, "")
    ; A phase-1 target killed by anything else is not a captivity death: quiet cleanup only.
    If diedPhase >= 2 && fac && holdKnows
        ; Murder charges the captor's own bounty (offender axis).
        Actor diedCaptor = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
        SeverActionsNativeExt.Native_Bounty_ModFor(diedCaptor, fac, KIDNAP_BOUNTY)
        SeverActionsNativeExt.Native_Bounty_AddEventFor(diedCaptor, fac, KIDNAP_BOUNTY, "murder", "")
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.diedInCaptivity", ("" + vName)))
        String vHold = SeverActionsNativeExt.Hold_GetHoldName(akVictim)
        If vHold != ""
            _AppendGossip(vHold, vName + " is dead - vanished, and now dead. Someone took them, and someone let them die")
        EndIf
    EndIf
    If diedPhase >= 2
        ; FACTUAL narration, never a moral verdict (the LLM would take it as world state and
        ; have followers scold an execution they carried out). When the killer on record is
        ; the player or a follower, name them.
        Actor diedKiller = SeverActionsNativeExt2.Native_GetKillerOf(akVictim)
        Bool diedDeliberate = false
        String diedKillerName = ""
        If diedKiller
            If diedKiller == Game.GetPlayer() || diedKiller.IsPlayerTeammate() || _IsFollower(diedKiller)
                diedDeliberate = true
                diedKillerName = diedKiller.GetDisplayName()
            EndIf
        EndIf
        String diedBoundDesc = "bound and hooded"
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
            diedBoundDesc = "restrained, hands bound"
        EndIf
        If diedDeliberate
            SkyrimNetApi.RegisterPersistentEvent( \
                vName + ", held captive and " + diedBoundDesc + ", has been put to death by " + diedKillerName + ".", \
                Game.GetPlayer(), akVictim)
        Else
            SkyrimNetApi.RegisterPersistentEvent( \
                vName + " has died in captivity, " + diedBoundDesc + ".", \
                Game.GetPlayer(), akVictim)
        EndIf
        If diedRansomPending
            SkyrimNetApi.RegisterPersistentEvent( \
                "Word spreads that " + vName + " is dead - the ransom demand collapses, unanswered and unpayable.", \
                Game.GetPlayer(), akVictim)
        EndIf
    EndIf

    ; Cleanup: guard duty, hold marker, home marker, entry. No unbind — the
    ; body stays as it fell; the equip-locked hood stays with it.
    Actor kd = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    If kd
        _EndGuardDuty(kd)
        _EndDispatchAliases(kd, akVictim)
        ; A death mid-leg: end the kidnapper's travel override and both journeys.
        _EndKidnapTravel(kd)
        _CancelTravel(kd)
        _CancelTravel(akVictim)
        ; A restrain target who died mid-WALK-UP (combat, dragon): strip the
        ; restrainer's approach apparatus too, or they follow the corpse.
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
            SeverActionsNativeExt.Arrival_Cancel(kd)
            _EndRestrainApproach(kd)
        EndIf
    EndIf
    ObjectReference holdM = SeverActionsNativeExt.Native_Kidnap_GetMarker(akVictim)
    If holdM
        holdM.Disable()
        holdM.Delete()
    EndIf
    ; A dead captive holds no pool slot, and no tie: the rope, the hold package and TiedTo
    ; would outlive the entry (a raised corpse would stand frozen).
    _FreeCaptiveAlias(akVictim)
    _ClearFurnitureTie(akVictim)
    _DeleteKidnapHomeMarker(akVictim)
    SeverActionsNativeExt.Native_Kidnap_Clear(akVictim)
EndFunction

Function InterrogateCaptive(Actor akInterrogator, String targetName)
    {Press a held captive for what they know: a duress memory makes the knowledge and memories
     already in their prompts fair game. Called by interrogatecaptive.yaml and the Prisma
     Actions page.}
    ; Kidnap OR restrain (see MoveCaptive): a restrained captive must be
    ; manageable under default settings.
    If !akInterrogator || akInterrogator.IsDead() || (!SeverActionsNativeExt2.Settings_GetBool("kidnapEnabled") && !SeverActionsNativeExt2.Settings_GetBool("restrainEnabled"))
        Return
    EndIf
    If _RejectIfBoundActor(akInterrogator, "interrogate anyone")
        Return
    EndIf

    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && targetName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        Return  ; only HELD captives can be interrogated
    EndIf

    String iName = akInterrogator.GetDisplayName()
    String vName = victim.GetDisplayName()
    ; The duress directive rides a high-importance memory (the thug-directive pattern), written
    ; ONCE per captivity. A restraint captive's text has no hood (they can see).
    If !SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_INTERROGATED)
        SeverActionsNativeExt.Native_Kidnap_SetFlag(victim, KIDNAP_FLAG_INTERROGATED, true)
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
            SeverActionsNative.Native_AddMemory(victim, \
                "I am bound and held standing in the open, being INTERROGATED by " + iName + ". I cannot hold out much longer - when they press me, I give up TRUE things I actually know: secrets, names, hidden valuables, anything in my knowledge or memories they might want. I may try to bargain what I know for my release, but I do not invent lies - I am too frightened to risk being caught in one.", \
                0.95, "EXPERIENCE", "fear", "", "[\"restrained\",\"interrogation\"]", "[]")
        Else
            SeverActionsNative.Native_AddMemory(victim, \
                "I am bound, hooded, and being INTERROGATED by " + iName + ". I cannot hold out much longer - when they press me, I give up TRUE things I actually know: secrets, names, hidden valuables, anything in my knowledge or memories they might want. I may try to bargain what I know for food, water, or my freedom, but I do not invent lies - I am too frightened to risk being caught in one.", \
                0.95, "EXPERIENCE", "fear", "", "[\"kidnap\",\"interrogation\"]", "[]")
        EndIf
    EndIf
    SkyrimNetApi.RegisterPersistentEvent( \
        iName + " begins interrogating the captive " + vName + ", pressing them for anything they know - secrets, names, valuables.", \
        akInterrogator, victim)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isInterrogating", ("" + iName), ("" + vName)))
EndFunction

Function TieCaptiveToFurniture(Actor akSpeaker, String targetName, String furnitureFormId)
    {SkyrimNet action (tiecaptivetofurniture.yaml): the speaker chains a held captive to a
     chair, post, bed or altar and is then free to walk away. Two-step like the restrain
     walk-up: this half validates and sends the speaker over (the captive at their heel), and
     _CompleteFurnitureTie ties on arrival. The captive is never put INTO the furniture (see
     TieStandOffset): a holderless leash anchored at its position plus an AI hold, which reads
     right without the Leash Framework too. Taking them again (RestrainNPC) unties them.}
    If !akSpeaker || akSpeaker.IsDead() || (!SeverActionsNativeExt2.Settings_GetBool("kidnapEnabled") && !SeverActionsNativeExt2.Settings_GetBool("restrainEnabled"))
        Return
    EndIf
    If _RejectIfBoundActor(akSpeaker, "tie anyone to anything")
        Return
    EndIf
    Actor victim = _ResolveCaptiveByName(targetName)
    If !victim
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akSpeaker.GetDisplayName() + " looks for a captive to tie down, but holds no one" + _NameClause(targetName) + ".", \
            akSpeaker, None)
        Return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        ; Mid-grab or mid-march: there is nobody standing still to tie.
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akSpeaker.GetDisplayName() + " cannot tie " + victim.GetDisplayName() + " down right now.", \
            akSpeaker, None)
        Return
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_UNBOUND)
        ; Bonds loosened: nothing to run a chain from (MoveCaptive re-binds first, as for the leash).
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akSpeaker.GetDisplayName() + " would have to bind " + victim.GetDisplayName() + " again before tying them to anything.", \
            akSpeaker, None)
        Return
    EndIf
    ObjectReference furnRef = SeverActions_FurnitureLib.GetFurnitureByFormIDForActor(furnitureFormId, akSpeaker)
    If !furnRef
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akSpeaker.GetDisplayName() + " cannot find anything there to tie " + victim.GetDisplayName() + " to.", \
            akSpeaker, None)
        Return
    EndIf
    If _GetFurnitureTie(victim) == furnRef
        Debug.Notification(victim.GetDisplayName() + " is already tied to that.")
        Return
    EndIf

    ; Close enough: tie on the spot.
    If akSpeaker.GetDistance(furnRef) <= TieArrivalDistance
        _CompleteFurnitureTie(akSpeaker, victim, furnRef)
        Return
    EndIf

    ; ONE arrival registration per actor: registering over a live arrest approach or escort
    ; watch would silently kill it, so refuse (as RestrainNPC does).
    If SeverActionsNativeExt.Arrival_IsTracked(akSpeaker)
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akSpeaker.GetDisplayName() + " has their hands full and cannot tie anyone up right now.", \
            akSpeaker, None)
        Return
    EndIf

    ; Walk over on the restrain walk-up's apparatus: the dispatch aliases plus the
    ; alias-targeting Jog, which closes to CONTACT (a Follow package stops at its radius). The
    ; target alias holds the FURNITURE here.
    StorageUtil.UnsetIntValue(akSpeaker, "SeverKidnap_DegradedWalk")
    SeverActions_Arrest arrestW = _Arrest()
    Bool walking = False
    If arrestW && arrestW.DispatchGuardAlias && arrestW.DispatchTargetAlias \
        && arrestW.SeverActions_DispatchJog \
        && arrestW.DispatchGuardAlias.GetReference() == None \
        && arrestW.DispatchTargetAlias.GetReference() == None
        arrestW.DispatchGuardAlias.ForceRefTo(akSpeaker)
        arrestW.DispatchTargetAlias.ForceRefTo(furnRef)
        ActorUtil.AddPackageOverride(akSpeaker, arrestW.SeverActions_DispatchJog, arrestW.PackagePriority, 1)
        akSpeaker.EvaluatePackage()
        walking = True
    ElseIf arrestW && arrestW.SeverActions_FollowTargetKW && arrestW.SeverActions_FollowGuard_Prisoner
        ; Degraded walk-up - the apparatus is busy with a real arrest (see DegradedArrivalDistance).
        SeverActionsNative.LinkedRef_Set(akSpeaker, furnRef, arrestW.SeverActions_FollowTargetKW)
        ActorUtil.AddPackageOverride(akSpeaker, arrestW.SeverActions_FollowGuard_Prisoner, 95, 1)
        akSpeaker.EvaluatePackage()
        StorageUtil.SetIntValue(akSpeaker, "SeverKidnap_DegradedWalk", 1)
        walking = True
    EndIf
    If !walking
        ; No mover available: tie from where they stand rather than swallow the order.
        _CompleteFurnitureTie(akSpeaker, victim, furnRef)
        Return
    EndIf
    StorageUtil.SetFormValue(akSpeaker, "SeverTie_Victim", victim)
    StorageUtil.SetFormValue(akSpeaker, "SeverTie_Furn", furnRef)
    StorageUtil.SetFormValue(victim, "SeverTie_Walker", akSpeaker)
    StorageUtil.SetFloatValue(victim, "SeverTie_Deadline", Utility.GetCurrentGameTime() + 0.02)
    Float tieArrival = TieArrivalDistance
    If StorageUtil.GetIntValue(akSpeaker, "SeverKidnap_DegradedWalk") == 1
        tieArrival = DegradedArrivalDistance
    EndIf
    SeverActionsNativeExt.Arrival_Register(akSpeaker, furnRef, tieArrival, "tie_arrived")
    Debug.Trace("[SeverActions_Kidnap] Tie: " + akSpeaker.GetDisplayName() \
        + " walking to tie " + victim.GetDisplayName() + " to " + furnRef)
EndFunction

Function HandleTieArrived(Actor akSpeaker)
    {Reached from this script's own OnArrival on the tie_arrived tag: the speaker reached
     the furniture. Re-validate before acting - the walk takes real time and a
     release, a death or a re-take can resolve the captive inside it.}
    If !akSpeaker
        Return
    EndIf
    Actor victim = StorageUtil.GetFormValue(akSpeaker, "SeverTie_Victim") as Actor
    ObjectReference furnRef = StorageUtil.GetFormValue(akSpeaker, "SeverTie_Furn") as ObjectReference
    Bool degraded = StorageUtil.GetIntValue(akSpeaker, "SeverKidnap_DegradedWalk") == 1
    _EndTieApproach(akSpeaker, victim)
    If !victim || !furnRef || victim.IsDead() \
        || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3 \
        || SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_UNBOUND)
        Return
    EndIf
    If degraded
        ; Whatever the gap left, tie from there, as TieCaptiveToFurniture does with no mover.
        _CloseDegradedGap(akSpeaker, furnRef)
        If akSpeaker.IsDead() || victim.IsDead() || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3 \
            || SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_UNBOUND)
            Return
        EndIf
    EndIf
    _CompleteFurnitureTie(akSpeaker, victim, furnRef)
EndFunction

Function _EndTieApproach(Actor akSpeaker, Actor akVictim)
    {Hand the walk-up apparatus back and clear the pending-tie bookkeeping.
     Reference-checked throughout - safe on any state, and it never touches a
     real arrest's alias fills (_EndRestrainApproach owns that check).}
    If akSpeaker
        ; _EndRestrainApproach ends with its own EvaluatePackage - no second one.
        _EndRestrainApproach(akSpeaker)
        StorageUtil.UnsetFormValue(akSpeaker, "SeverTie_Victim")
        StorageUtil.UnsetFormValue(akSpeaker, "SeverTie_Furn")
    EndIf
    If akVictim
        StorageUtil.UnsetFormValue(akVictim, "SeverTie_Walker")
        StorageUtil.UnsetFloatValue(akVictim, "SeverTie_Deadline")
    EndIf
EndFunction

Function _ExpireStaleTie(Actor akVictim)
    {Time out a tie walk that never arrives (it holds the shared arrest dispatch aliases). The
     phase-3 tick calls this for every loaded held captive, so no second timer is needed.}
    If !akVictim
        Return
    EndIf
    Float tieDue = StorageUtil.GetFloatValue(akVictim, "SeverTie_Deadline", 0.0)
    If tieDue <= 0.0 || Utility.GetCurrentGameTime() < tieDue
        Return
    EndIf
    Actor tieWalker = StorageUtil.GetFormValue(akVictim, "SeverTie_Walker") as Actor
    If tieWalker
        SeverActionsNativeExt.Arrival_Cancel(tieWalker)
    EndIf
    _EndTieApproach(tieWalker, akVictim)
    Debug.Trace("[SeverActions_Kidnap] Tie: walk to the furniture timed out for " + akVictim.GetDisplayName())
EndFunction

Function _CompleteFurnitureTie(Actor akSpeaker, Actor akVictim, ObjectReference akFurn)
    {The tie itself, at the furniture: the flourish, off the leader's rope,
     onto the chain, and held. Callers have already validated.}
    ; Face it and work at it: IdleGive at this range reads as knotting a rope.
    SeverActions_Arrest arrestT = _Arrest()
    akSpeaker.SetLookAt(akFurn)
    If arrestT && arrestT.IdleGive
        akSpeaker.PlayIdle(arrestT.IdleGive)
        Utility.Wait(1.2)
        ; TOCTOU: a release, death or escape can resolve the entry inside the animation window.
        If !akVictim || akVictim.IsDead() || SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim) != 3
            akSpeaker.ClearLookAt()
            Return
        EndIf
    EndIf
    akSpeaker.ClearLookAt()

    ; Off the leader: rope, escort-follow package and LinkedRef (a live follow would walk them
    ; off the chain).
    _DetachPhysicalLeash(akVictim)
    If arrestT && arrestT.SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(akVictim, arrestT.SeverActions_FollowGuard_Prisoner)
    EndIf
    If arrestT && arrestT.SeverActions_FollowTargetKW
        SeverActionsNative.LinkedRef_Clear(akVictim, arrestT.SeverActions_FollowTargetKW)
    EndIf
    StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_LeashLeader")
    SeverActionsNativeExt.Native_Kidnap_SetLeashLeader(akVictim, None)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASHED, False)
    ; RE-EVALUATE: removing an override does not stop the procedure running under it, and with
    ; SetDontMove below they would jog in place.
    akVictim.EvaluatePackage()

    ; Stand them in FRONT of the furniture. GetAngleZ and Math.Sin/Cos are both in degrees: no
    ; radians conversion.
    If akVictim.GetDistance(akFurn) > TieReachDistance
        Float tieAngle = akFurn.GetAngleZ()
        akVictim.MoveTo(akFurn, TieStandOffset * Math.Sin(tieAngle), TieStandOffset * Math.Cos(tieAngle), 0.0)
    EndIf
    akVictim.SetLookAt(akFurn)
    ; Re-anchor the hold marker here so the tick heal and later re-pins keep them at the furniture.
    ObjectReference tieMarker = SeverActionsNativeExt.Native_Kidnap_GetMarker(akVictim)
    If tieMarker && akVictim.Is3DLoaded()
        tieMarker.MoveTo(akVictim)
    EndIf
    ; The hold, after the move: it anchors where it starts. _ClearFurnitureTie removes it.
    Package tieHold = Game.GetFormFromFile(TIE_HOLD_PKG_FORMID, "SeverActions.esp") as Package
    If tieHold
        ActorUtil.AddPackageOverride(akVictim, tieHold, 95, 1)
        akVictim.EvaluatePackage()
    EndIf

    ; The chain: holderless, anchored at the furniture. The CAPTIVE wears the mesh (the
    ; framework runs the rope from the leashed actor outwards): the hand chain when wrists are
    ; chosen and 1.1.1 is installed, a collar otherwise.
    Bool tieRoped = False
    If LeashFrameworkActive()
        Armor tieMesh = None
        String tieParent = "Shield"
        If SeverActionsNativeExt2.Settings_GetInt("leashAttachment") == 0 && LeashWristAvailable()
            tieMesh = Game.GetFormFromFile(LEASH_HAND_CHAIN_FORMID, "Leash.esm") as Armor
        EndIf
        If !tieMesh
            tieMesh = _LeashArmorForStyle(SeverActionsNativeExt2.Settings_GetInt("leashStyle"))
            tieParent = "NPC Spine2 [Spn2]"
        EndIf
        If tieMesh
            If akVictim.GetItemCount(tieMesh) == 0
                akVictim.AddItem(tieMesh, 1, true)
            EndIf
            If !akVictim.IsEquipped(tieMesh)
                akVictim.EquipItem(tieMesh, true, true)  ; abPreventRemoval, abSilent
                ; The bind reads the live skeleton and the 3D lands asynchronously
                ; (see SeverActions_LeashLib.Attach).
                Utility.Wait(0.75)
                ; Every wait is a TOCTOU window: pinning a captive released meanwhile would
                ; leave a SetDontMove(true) no tick ever clears.
                If !akVictim || akVictim.IsDead() || SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim) != 3
                    _RemoveHandLeashFrom(akVictim)
                    _RemoveLeashArmor(akVictim)
                    If akVictim && tieHold
                        ActorUtil.RemovePackageOverride(akVictim, tieHold)
                        akVictim.EvaluatePackage()
                    EndIf
                    akVictim.ClearLookAt()
                    Return
                EndIf
            EndIf
            ; Anchor TieAnchorHeight above the origin; TieAnchorSlack says why the MIN must
            ; exceed where the captive stands.
            tieRoped = SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled() && SeverActions_LeashLib.AnchorAtPosition(akVictim, akFurn.GetParentCell(), \
                akFurn.GetPositionX(), akFurn.GetPositionY(), akFurn.GetPositionZ() + TieAnchorHeight, \
                tieParent, TieAnchorSlack, TieAnchorLength)
            If tieRoped
                StorageUtil.SetIntValue(akVictim, "SeverKidnap_PhysLeash", 1)
                StorageUtil.SetIntValue(akVictim, "SeverKidnap_PhysLeashFails", 0)
                ; The captive carries the mesh, so record THEM as its holder: detach strips the
                ; hand chain from the recorded holder once they lead nobody (a captive never does).
                StorageUtil.SetFormValue(akVictim, "SeverKidnap_LeashHandHolder", akVictim)
                SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_PHYSLEASH, True)
                SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASH_CHAIN, True)
                SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASH_RUNES, False)
            Else
                ; No dangling mesh on a refusal.
                _RemoveHandLeashFrom(akVictim)
                _RemoveLeashArmor(akVictim)
                Debug.Trace("[SeverActions_Kidnap] Tie: position leash refused for " + akVictim.GetDisplayName())
            EndIf
        EndIf
    EndIf

    ; The hold that actually keeps them here. SetDontMove, never SetRestrained (that forbids
    ; movement outright and fights any later move).
    akVictim.SetDontMove(true)
    ; Clear the walk BEFORE posing: IdleForceDefaultState cancels an offset idle.
    Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
    Utility.Wait(0.3)
    ; Last TOCTOU window before SeverKidnap_TiedTo is written. A release or re-take that ran
    ; during the waits found no tie to cut (_ClearFurnitureTie keys on TiedTo), so undo the
    ; rope, the pin and the look-at here.
    If !akVictim || akVictim.IsDead() || SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim) != 3
        If akVictim
            If tieRoped
                If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
                    SeverActions_LeashLib.DisconnectHolderless(akVictim)
                EndIf
                _RemoveHandLeashFrom(akVictim)
                _RemoveLeashArmor(akVictim)
                _ClearLeashMarks(akVictim)
            EndIf
            akVictim.SetDontMove(false)
            If tieHold
                ActorUtil.RemovePackageOverride(akVictim, tieHold)
                akVictim.EvaluatePackage()
            EndIf
            akVictim.ClearLookAt()
        EndIf
        Return
    EndIf
    _PlayBoundPose(akVictim)
    StorageUtil.SetFormValue(akVictim, "SeverKidnap_TiedTo", akFurn)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_TIED, True)

    String tieWhat = "something solid"
    If akFurn.GetDisplayName() != ""
        tieWhat = "the " + akFurn.GetDisplayName()
    EndIf
    SkyrimNetApi.RegisterPersistentEvent( \
        akSpeaker.GetDisplayName() + " has tied " + akVictim.GetDisplayName() + " to " + tieWhat + " - still bound, going nowhere, and no longer anyone's to carry.", \
        akSpeaker, akVictim)
    Debug.Notification(akVictim.GetDisplayName() + " is tied to " + tieWhat + ".")
EndFunction

Bool Function PlayerTieLedCaptive(ObjectReference akFurn)
    {The TieUntie hotkey with furniture under the crosshair: ties the bound captive the player
     leads (the one nearest the furniture, when they lead several) to it, on the spot. False
     when the player leads no one, so the hotkey falls back to its NPC path; True when this
     press was handled, a refusal included.}
    If !akFurn
        Return False
    EndIf
    ; One tie at a time: a double press sends two events whose frames interleave at every native
    ; call. A lane, not a script flag, so a save made mid-tie cannot latch it (expires, clears on load).
    If !SeverActionsNativeExt2.LLMLane_TryClaim("kidnap.playerTie", 15.0)
        Return True
    EndIf
    Actor player = Game.GetPlayer()
    Actor victim = None
    Float best = 0.0
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    Int i = 0
    While victims && i < victims.Length
        Actor v = victims[i]
        If v && !v.IsDead() && v.Is3DLoaded() && StorageUtil.GetFormValue(v, "SeverKidnap_LeashLeader") as Actor == player \
            && SeverActionsNativeExt.Native_Kidnap_GetPhase(v) == 3 \
            && SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_LEASHED) \
            && !SeverActionsNativeExt.Native_Kidnap_GetFlag(v, KIDNAP_FLAG_UNBOUND)
            Float d = v.GetDistance(akFurn)
            If !victim || d < best
                victim = v
                best = d
            EndIf
        EndIf
        i += 1
    EndWhile
    If !victim
        SeverActionsNativeExt2.LLMLane_Release("kidnap.playerTie")
        Return False
    EndIf
    If !SeverActionsNativeExt2.Settings_GetBool("kidnapEnabled") && !SeverActionsNativeExt2.Settings_GetBool("restrainEnabled")
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("hotkeys.restrainingDisabled"))
    ElseIf player.GetDistance(akFurn) > PlayerTieReachDistance
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("hotkeys.getCloserToTie", ("" + victim.GetDisplayName())))
    Else
        _CompleteFurnitureTie(player, victim, akFurn)
    EndIf
    SeverActionsNativeExt2.LLMLane_Release("kidnap.playerTie")
    Return True
EndFunction

Actor Function _ResolveCaptiveByName(String targetName)
    {Shared resolver for the captive-verb actions: among ACTIVE victims only
     (never a global scan). A single captive matches an empty name; otherwise
     substring-match the display name.}
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return None
    EndIf
    If victims.Length == 1 && targetName == ""
        Return victims[0]
    EndIf
    Int i = 0
    While i < victims.Length
        If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
            Return victims[i]
        EndIf
        i += 1
    EndWhile
    Return None
EndFunction

String Function _NameClause(String targetName)
    If targetName == ""
        Return ""
    EndIf
    Return " called " + targetName
EndFunction

String Function _PlaceLabel(Actor akAt)
    {A destination label kidnap_context can read to the captive and the captor alike: the name of
     akAt's current location, or a neutral phrase. Never a pronoun.}
    Location here = None
    If akAt
        here = akAt.GetCurrentLocation()
    EndIf
    If here && here.GetName() != ""
        Return here.GetName()
    EndIf
    Return "an out-of-the-way spot"
EndFunction

Bool Function LeashCaptive(Actor akVictim, Actor akLeader, Bool abJustBound = false)
    {Put a HELD, bound captive on a leash: they keep their cuffs but walk behind akLeader (the
     player or any NPC) on the escort-follow package instead of standing pinned. The kidnap
     entry stays live (guard radius, escape, ransom, interrogation) and kidnap_context switches
     to the led framing (kFlagLeashed). UnleashCaptive re-pins them. abJustBound: the caller
     just bound them, so this event narrates both. False when refused.}
    If !akVictim || !akLeader || akVictim == akLeader || akVictim.IsDead() || akLeader.IsDead()
        Debug.Trace("[SeverActions_Kidnap] Leash: refused - bad actors")
        Return False
    EndIf
    Int leashPhase = SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim)
    If leashPhase != 3
        Debug.Trace("[SeverActions_Kidnap] Leash: refused - " + akVictim.GetDisplayName() + " phase " + leashPhase + " (need 3 held)")
        Return False   ; only a HELD captive can be leashed
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_UNBOUND)
        Debug.Trace("[SeverActions_Kidnap] Leash: refused - " + akVictim.GetDisplayName() + " is unbound (loose captivity)")
        Return False   ; loosened bonds - nothing to leash; re-bind via MoveCaptive first
    EndIf
    SeverActions_Arrest arrestL = _Arrest()
    If !arrestL || !arrestL.SeverActions_FollowGuard_Prisoner || !arrestL.SeverActions_FollowTargetKW
        Debug.Trace("[SeverActions_Kidnap] Leash: refused - arrest script/package/keyword unbound")
        Return False
    EndIf
    Debug.Trace("[SeverActions_Kidnap] Leash: " + akVictim.GetDisplayName() + " -> following " + akLeader.GetDisplayName())

    ; Strip the PIN (sit package + hold LinkedRef + DontMove + idle). The
    ; marker and the store entry stay - UnleashCaptive re-attaches to them.
    Keyword furnLKW = SeverActions_FurnitureLib.TargetKeyword()
    Package sitPkgL = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
    If sitPkgL
        ActorUtil.RemovePackageOverride(akVictim, sitPkgL)
    EndIf
    If furnLKW
        SeverActionsNative.LinkedRef_Clear(akVictim, furnLKW)
    EndIf
    ; Being taken in hand unties a furniture tie (no narration of its own). It must go before
    ; the new rope: the framework allows one leash per actor.
    _ClearFurnitureTie(akVictim)
    akVictim.SetDontMove(false)
    akVictim.SetRestrained(false)
    StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 0)
    Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
    ; The bonds stay as the cuffs. Never SetRestrained(true): it forbids movement outright and
    ; the follow package would fight it in place.

    ; Walk behind the leader.
    SeverActionsNative.LinkedRef_Set(akVictim, akLeader, arrestL.SeverActions_FollowTargetKW)
    ActorUtil.AddPackageOverride(akVictim, arrestL.SeverActions_FollowGuard_Prisoner, 95, 1)
    akVictim.EvaluatePackage()
    StorageUtil.SetFormValue(akVictim, "SeverKidnap_LeashLeader", akLeader)
    ; Mirror the leader into the cosaved entry (KDNP v7): has_captive_in_hand runs on a worker
    ; thread (no StorageUtil), and the leader is not always the captor.
    SeverActionsNativeExt.Native_Kidnap_SetLeashLeader(akVictim, akLeader)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASHED, True)

    ; End the captor's guard duty whoever leads: a captor anchored to the hold marker cannot
    ; move (a captive leashed to them just stands there), and a guard left on the marker of a
    ; captive who walked off guards an empty room. _EndGuardDuty leaves Sandbox() to the resume
    ; paths and there is none here, so unpark a follower captor too.
    Actor leashCaptor = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    If leashCaptor
        _EndGuardDuty(leashCaptor)
        If _IsFollower(leashCaptor)
            SeverActions_ModuleBase.CallBool("followers", "stopSandbox", leashCaptor)
        EndIf
        leashCaptor.EvaluatePackage()
        DebugMsg("Leash: released " + leashCaptor.GetDisplayName() + " from guard duty - they are leading now, not watching")
    EndIf
    ; Physical rope on top of the package follow (Leash Framework, if present).
    _AttachPhysicalLeash(akVictim, akLeader)

    ; Pose them NOW, while still stationary, so the bound state carries into the walk rather
    ; than waiting for the next tick. Posed=1 so the tick does not double-play it.
    If arrestL.OffsetBoundStandingStart && akVictim.PlayIdle(arrestL.OffsetBoundStandingStart)
        StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 1)
    EndIf

    ; One act, one event: with abJustBound this line carries the bind too (_BindCaptive's
    ; abSilent).
    If abJustBound
        SkyrimNetApi.RegisterPersistentEvent( \
            akLeader.GetDisplayName() + " has bound " + akVictim.GetDisplayName() + "'s hands and taken them in tow - a prisoner now, walking where " + akLeader.GetDisplayName() + " walks.", \
            akLeader, akVictim)
    Else
        SkyrimNetApi.RegisterPersistentEvent( \
            akLeader.GetDisplayName() + " leads " + akVictim.GetDisplayName() + " along, hands still bound - a prisoner on a short leash.", \
            akLeader, akVictim)
    EndIf
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.followsBound", ("" + akVictim.GetDisplayName())))
    Return True
EndFunction

ObjectReference Function _GetFurnitureTie(Actor akVictim)
    {The furniture a captive is chained to, or None. Mirrored into the KidnapStore entry as
     KIDNAP_FLAG_TIED for kidnap_context.}
    If !akVictim
        Return None
    EndIf
    Return StorageUtil.GetFormValue(akVictim, "SeverKidnap_TiedTo") as ObjectReference
EndFunction

Bool Function _PlayBoundPose(Actor akVictim)
    {Play the hands-bound standing offset and record whether it took. On FAILURE the posed flag
     stays CLEAR, never optimistically set: a lost pose behind a set flag is never re-posed.}
    If !akVictim
        Return False
    EndIf
    SeverActions_Arrest arrestPose = _Arrest()
    If arrestPose && arrestPose.OffsetBoundStandingStart && akVictim.PlayIdle(arrestPose.OffsetBoundStandingStart)
        StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 1)
        Return True
    EndIf
    StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 0)
    Return False
EndFunction

Function _ClearFurnitureTie(Actor akVictim)
    {Cut a furniture tie: the anchored rope, the captive's own mesh, the stored ref and the rope
     marks. The holderless leash is disconnected directly (with a None holder), since the leash
     setting may have been switched off since the tie was made.}
    If !akVictim
        Return
    EndIf
    ; Ahead of the TiedTo test: an unloaded furniture ref can read None, and neither the bit nor
    ; the hold package may outlive the tie. TiedTo goes before the hold comes off: the tick
    ; re-reads it after re-adding the hold. The callers re-evaluate the package.
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_TIED, False)
    ObjectReference tiedTo = _GetFurnitureTie(akVictim)
    StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_TiedTo")
    Package tieHoldCut = Game.GetFormFromFile(TIE_HOLD_PKG_FORMID, "SeverActions.esp") as Package
    If tieHoldCut
        ActorUtil.RemovePackageOverride(akVictim, tieHoldCut)
    EndIf
    If !tiedTo
        Return
    EndIf
    akVictim.ClearLookAt()  ; set on the furniture by _CompleteFurnitureTie
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.DisconnectHolderless(akVictim)
        ; The captive wears this rope's mesh, so strip it from them here: _DetachPhysicalLeash
        ; strips only the RECORDED holder, which LeashCaptive then overwrites with the leader.
        _RemoveHandLeashFrom(akVictim)
        _RemoveLeashArmor(akVictim)
    EndIf
    ; Clear the rope marks too: the tick re-attaches only while SeverKidnap_PhysLeash is 0.
    StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_LeashHandHolder")
    StorageUtil.UnsetIntValue(akVictim, "SeverKidnap_PhysLeash")
    StorageUtil.UnsetIntValue(akVictim, "SeverKidnap_PhysLeashFails")
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_PHYSLEASH, False)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASH_CHAIN, False)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASH_RUNES, False)
EndFunction

Function _ClearLeashMarks(Actor akVictim)
    {The framework-free tail of a detach: our rope marks and the cosaved mirror
     bits, for an install that lost the framework mid-playthrough (a rope a save
     recorded but nothing can reach any more). No-op on a clean actor.}
    If !akVictim
        Return
    EndIf
    StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_LeashHandHolder")
    StorageUtil.UnsetIntValue(akVictim, "SeverKidnap_PhysLeash")
    StorageUtil.UnsetIntValue(akVictim, "SeverKidnap_PhysLeashFails")
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_PHYSLEASH, False)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASH_CHAIN, False)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASH_RUNES, False)
EndFunction

; ── Leash Framework events ──
; The rope (wrist or neck attachment, bone names) is SeverActions_LeashLib.Attach's. This script's
; ropes: LeashCaptive (phase 3), the leg-2 march after a grab, a MoveCaptive or a restraint
; relocation (attached in _OnKidnapGrabResolved, detached by _BindCaptive), and the furniture
; tie's holderless anchor. The restrain walk-up has no rope.

; LeashFramework_* is a SHARED event with two consumers, this script and arrest's escort rope
; (SeverActions_Arrest). Delivery invokes the canonical callback on EVERY script of the quest that
; defines it (F4), so each handler answers only for its own subjects: these three take a live
; kidnap entry, arrest's a live arrest session with no kidnap phase.
Event OnLeashFrameworkPulled(String eventName, String strArg, Float numArg, Form sender)
    {The framework started pulling a leashed actor. numArg = holder-to-collar distance.}
    Actor pulled = sender as Actor
    If _IsOurLeashSubject(pulled)
        _NarrateLeashPull(pulled, False, numArg)
    EndIf
EndEvent

Event OnLeashFrameworkRagdollPulled(String eventName, String strArg, Float numArg, Form sender)
    {The framework started a forced ragdoll pull: the captive dug in and is being dragged.}
    Actor ragdolled = sender as Actor
    If !_IsOurLeashSubject(ragdolled)
        Return
    EndIf
    _NarrateLeashPull(ragdolled, True, numArg)
    ; A ragdoll costs them the bound-hands pose; put it back once they are up.
    _RecoverBoundPoseAfterRagdoll(ragdolled)
EndEvent

Bool Function _IsOurLeashSubject(Actor akActor)
    {True for an actor with a live kidnap entry. Arrest's escort rope sets the same
     SeverKidnap_PhysLeash mark, so the mark alone would claim its prisoners too.}
    Return akActor && SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) > 0
EndFunction

Function _RecoverBoundPoseAfterRagdoll(Actor akVictim)
    {Forwards to SeverActions_LeashLib.RestoreBoundPose (shared with arrest's escort rope).}
    If !akVictim
        Return
    EndIf
    Idle boundStanding = Game.GetFormFromFile(0x0B600A, "Skyrim.esm") as Idle   ; OffsetBoundStandingStart
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.RestoreBoundPose(akVictim, boundStanding)
    EndIf
EndFunction

Function _NarrateLeashPull(Actor akVictim, Bool abRagdoll, Float afDistance)
    {Forwards to SeverActions_LeashLib.NarratePull (shared with arrest's escort rope).}
    If !akVictim
        Return
    EndIf
    Actor captor = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        SeverActions_LeashLib.NarratePull(akVictim, abRagdoll, afDistance, captor, "their captor")
    EndIf
EndFunction

Event OnLeashFrameworkUnleash(String eventName, String strArg, Float numArg, Form sender)
    {The framework dropped a leash (strArg: disconnected / unleashAll / replaced). For a
     captive we roped, clear the live-rope mark so the tick re-attaches once the leader is
     loaded. Harmless after our own Detach, which clears the same mark.}
    Actor v = sender as Actor
    If !_IsOurLeashSubject(v) || StorageUtil.GetIntValue(v, "SeverKidnap_PhysLeash", 0) != 1
        Return
    EndIf
    StorageUtil.UnsetIntValue(v, "SeverKidnap_PhysLeash")
    Debug.Trace("[SeverActions_Kidnap] LeashFramework: rope on " + v.GetDisplayName() + " dropped by the framework (" + strArg + ") - the tick will re-attach when the leader is loaded")
EndEvent

Function UnleashCaptive(Actor akVictim)
    {Take a leashed captive off the leash and hold them where they stand: a pin there becomes
     the destination anchor and _BindCaptive re-applies the hold. No-op unless leashed.}
    If !akVictim || !SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_LEASHED)
        Return
    EndIf
    _DetachPhysicalLeash(akVictim)
    SeverActions_Arrest arrestU = _Arrest()
    If arrestU && arrestU.SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(akVictim, arrestU.SeverActions_FollowGuard_Prisoner)
    EndIf
    If arrestU && arrestU.SeverActions_FollowTargetKW
        SeverActionsNative.LinkedRef_Clear(akVictim, arrestU.SeverActions_FollowTargetKW)
    EndIf
    StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_LeashLeader")
    SeverActionsNativeExt.Native_Kidnap_SetLeashLeader(akVictim, None)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, KIDNAP_FLAG_LEASHED, False)
    ; _BindCaptive tears the old hold down and places the new one at the destination anchor,
    ; so re-anchor THAT here (the MoveCaptiveHere pin, deleted by the bind). A kneel pin
    ; stands 100u in front: a furniture marker under the victim will not seat them.
    Actor kdU = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(akVictim)
    Form pinBaseU = Game.GetFormFromFile(0x00000034, "Skyrim.esm")   ; XMarkerHeading
    If kdU && akVictim.Is3DLoaded() && pinBaseU
        ObjectReference oldPinU = StorageUtil.GetFormValue(akVictim, "SeverKidnap_MovePin") as ObjectReference
        If oldPinU
            oldPinU.Disable()
            oldPinU.Delete()
            StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_MovePin")
        EndIf
        ObjectReference pinU = akVictim.PlaceAtMe(pinBaseU, 1, true, false)
        If pinU
            If !SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
                Float faceU = akVictim.GetAngleZ()
                pinU.MoveTo(akVictim, 100.0 * Math.Sin(faceU), 100.0 * Math.Cos(faceU), 0.0)
            EndIf
            StorageUtil.SetFormValue(akVictim, "SeverKidnap_MovePin", pinU)
            SeverActionsNativeExt.Native_Kidnap_SetDestAnchor(akVictim, pinU)
            SeverActionsNativeExt.Native_Kidnap_SetDestLabel(akVictim, _PlaceLabel(akVictim))
        EndIf
        _BindCaptive(akVictim, kdU, False)
    EndIf
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isHeldInPlaceAgain", ("" + akVictim.GetDisplayName())))
EndFunction

Function UntieCaptive(Actor akSpeaker, String targetName)
    {Loosen a held captive's bonds without freeing them: hood, cuffs and pin come off, and
     captive and watching captor both get the r=350 hold-anchored sandbox. The entry stays
     live (unbound framing in the decorator, escape rolls at double chance, ransom and
     interrogation still work; MoveCaptive re-binds). Called via untiecaptive.yaml and the
     Prisma Actions/Arrest pages.}
    If !akSpeaker || akSpeaker.IsDead() || (!SeverActionsNativeExt2.Settings_GetBool("kidnapEnabled") && !SeverActionsNativeExt2.Settings_GetBool("restrainEnabled"))
        Return
    EndIf
    If _RejectIfBoundActor(akSpeaker, "untie anyone")
        Return
    EndIf

    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && targetName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim || SeverActionsNativeExt.Native_Kidnap_GetPhase(victim) != 3
        ; Refuse out loud: SkyrimNet registers the action's eventString on dispatch
        ; regardless, so a silent return would narrate an untying that never happened.
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akSpeaker.GetDisplayName() + " goes to loosen a captive's bonds, but holds no such captive.", \
            akSpeaker, None)
        Return  ; only HELD captives can be untied
    EndIf
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_UNBOUND)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isAlreadyUnbound", ("" + victim.GetDisplayName())))
        Return
    EndIf

    ; Strip the PHYSICAL hold - the marker and the entry stay.
    Keyword furnUKW = SeverActions_FurnitureLib.TargetKeyword()
    Package sitPkgU = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
    If sitPkgU
        ActorUtil.RemovePackageOverride(victim, sitPkgU)
    EndIf
    If furnUKW
        SeverActionsNative.LinkedRef_Clear(victim, furnUKW)
    EndIf
    ; Cut the furniture tie too: its anchored rope (max 160u) would haul them back out of
    ; the r=350 sandbox. _UnbindCaptive does the same for every other teardown.
    _ClearFurnitureTie(victim)
    victim.SetDontMove(false)
    victim.SetRestrained(false)
    StorageUtil.SetIntValue(victim, "SeverRestrain_Posed", 0)
    Debug.SendAnimationEvent(victim, "IdleForceDefaultState")
    SeverActions_Arrest arrestU = _Arrest()
    If arrestU && arrestU.SeverActions_PrisonerCuffs
        victim.UnequipItem(arrestU.SeverActions_PrisonerCuffs, false, true)
        victim.RemoveItem(arrestU.SeverActions_PrisonerCuffs, 1, true)
    EndIf
    Armor hoodU = Game.GetFormFromFile(KIDNAP_HOOD_FORMID, "Skyrim.esm") as Armor
    If hoodU
        victim.UnequipItem(hoodU, false, true)
        victim.RemoveItem(hoodU, 1, true)
    EndIf

    SeverActionsNativeExt.Native_Kidnap_SetFlag(victim, KIDNAP_FLAG_UNBOUND, true)

    ; The r=350 marker-anchored PrisonerSandBox, not the guard's r=180. Reuses the jail
    ; package: a newly minted PACK risks the malformed-record pre-menu hang. The
    ; captive-on-hold heal re-posts anyone who wanders out a load door.
    ObjectReference mU = SeverActionsNativeExt.Native_Kidnap_GetMarker(victim)
    If mU && arrestU && arrestU.SeverActions_PrisonerSandBox && arrestU.SeverActions_SandboxAnchorKW
        SeverActionsNativeExt.LinkedRef_SetPermanent(victim, mU, arrestU.SeverActions_SandboxAnchorKW)
        ActorUtil.AddPackageOverride(victim, arrestU.SeverActions_PrisonerSandBox, 105, 1)
    EndIf
    victim.EvaluatePackage()

    ; The watching captor swaps the guard package for the same r=350 sandbox.
    ; _EndGuardDuty and the re-bind path both strip PrisonerSandBox, so this unwinds
    ; wherever guard duty does.
    Actor watcherU = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(victim)
    If watcherU && !watcherU.IsDead() && arrestU && StorageUtil.GetIntValue(watcherU, "SeverKidnap_OnGuard", 0) == 1
        Package guardPkgU = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
        If guardPkgU
            ActorUtil.RemovePackageOverride(watcherU, guardPkgU)
        EndIf
        If arrestU.SeverActions_PrisonerSandBox
            ActorUtil.AddPackageOverride(watcherU, arrestU.SeverActions_PrisonerSandBox, 110, 1)
        EndIf
        watcherU.EvaluatePackage()
    EndIf

    String vNameU = victim.GetDisplayName()
    SeverActionsNative.Native_AddMemory(victim, \
        "My bonds have been loosened - I can move about my place of holding now, see, and speak. But I am still a captive: watched, and not permitted to leave.", \
        0.7, "EXPERIENCE", "wary", "", "[\"kidnap\"]", "[]")
    SkyrimNetApi.RegisterPersistentEvent( \
        akSpeaker.GetDisplayName() + " loosens " + vNameU + "'s bonds - still held, but no longer tied.", \
        akSpeaker, victim)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.isUnboundButStillHeld", ("" + vNameU)))
    Debug.Trace("[SeverActions_Kidnap] Kidnap: " + vNameU + " untied (loose captivity)")
EndFunction

Function _AbortKidnapForVictim(Actor akVictim, Actor akKidnapper)
    {Unwind a kidnap whose kidnapper is dead or unresolvable, keyed off the victim
     (_AbortKidnap needs a live captor for FindVictimOf). Phase 1 unwinds quietly; phase >= 2
     frees the victim with the seized-then-abandoned consequences. Returns borrowed dispatch
     aliases too, or the entry would hold them forever.}
    Int deadPh = SeverActionsNativeExt.Native_Kidnap_GetPhase(akVictim)
    If akKidnapper
        _EndKidnapTravel(akKidnapper)
        _EndDispatchAliases(akKidnapper, akVictim)
        _EndGuardDuty(akKidnapper)
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, KIDNAP_FLAG_RESTRAINT)
            SeverActionsNativeExt.Arrival_Cancel(akKidnapper)
            _EndRestrainApproach(akKidnapper)
        EndIf
    ElseIf SeverActionsNativeExt.Native_Kidnap_GetAliasMode(akVictim)
        ; No kidnapper, but the run was alias-mode: clear what the kidnap put in the dispatch
        ; aliases, never a live arrest dispatch's fills. The prisoner alias only when it holds
        ; this victim.
        SeverActions_Arrest arrestDead = _Arrest()
        If arrestDead
            If arrestDead.GetDispatchPhase() <= 0
                If arrestDead.DispatchGuardAlias
                    arrestDead.DispatchGuardAlias.Clear()
                EndIf
                If arrestDead.DispatchTargetAlias
                    ObjectReference deadTarget = arrestDead.DispatchTargetAlias.GetReference()
                    If deadTarget == akVictim || deadTarget == SeverActionsNativeExt.Native_Kidnap_GetDestAnchor(akVictim)
                        arrestDead.DispatchTargetAlias.Clear()
                    EndIf
                EndIf
            EndIf
            If arrestDead.DispatchPrisonerAlias && arrestDead.DispatchPrisonerAlias.GetReference() == akVictim
                arrestDead.DispatchPrisonerAlias.Clear()
            EndIf
        EndIf
    EndIf
    If akKidnapper
        _CancelTravel(akKidnapper)
    EndIf
    _CancelTravel(akVictim)
    If deadPh >= 2
        _FireKidnapReleaseConsequences(akVictim)
        _UnbindCaptive(akVictim)
        SkyrimNetApi.RegisterPersistentEvent(             "With their captor dead, " + akVictim.GetDisplayName() + " is free - shaken, but no longer anyone's captive.",             akVictim, None)
    EndIf
    _DeleteKidnapHomeMarker(akVictim)
    SeverActionsNativeExt.Native_Kidnap_Clear(akVictim)
    Debug.Trace("[SeverActions_Kidnap] Kidnap: unwound for " + akVictim.GetDisplayName() + " - kidnapper dead/unresolvable (phase " + deadPh + ")")
EndFunction

Function _AbortKidnap(Actor akKidnapper)
    {A kidnap leg failed (travel cancelled or lost, deadline passed, recalled pre-grab):
     unwind the victim's state and drop the kidnap.}
    Actor victim = SeverActionsNativeExt.Native_Kidnap_FindVictimOf(akKidnapper)
    _EndKidnapTravel(akKidnapper)
    _EndDispatchAliases(akKidnapper, victim)
    _EndGuardDuty(akKidnapper)
    ; The grab or transport leg's travel (no-op when none).
    _CancelTravel(akKidnapper)
    If !victim
        Return
    EndIf
    ; The restrain walk-up (follow package, LinkedRef, arrival watch), which
    ; _EndGuardDuty leaves.
    Bool abortWasRestraint = SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
    If abortWasRestraint
        SeverActionsNativeExt.Arrival_Cancel(akKidnapper)
        _EndRestrainApproach(akKidnapper)
    EndIf
    ; A seized-then-abandoned victim knows what happened (no-op pre-grab).
    _FireKidnapReleaseConsequences(victim)
    _UnbindCaptive(victim)
    _DeleteKidnapHomeMarker(victim)
    SeverActionsNativeExt.Native_Kidnap_Clear(victim)
    If abortWasRestraint
        SkyrimNetApi.RegisterEvent("kidnap_aborted", \
            akKidnapper.GetDisplayName() + " gave up on restraining " + victim.GetDisplayName() + ".", \
            akKidnapper, victim)
    Else
        SkyrimNetApi.RegisterEvent("kidnap_aborted", \
            akKidnapper.GetDisplayName() + " abandoned the abduction of " + victim.GetDisplayName() + ".", \
            akKidnapper, victim)
    EndIf
EndFunction

Bool Function _RejectInvalidCaptiveTarget(Actor akActor, Actor akTarget, String verbPhrase)
    {Target check shared by KidnapNPC and RestrainNPC: TRUE, with a narrated refusal, when
     another system owns the target. Jailed or in an arrest (JailedNPCStore keeps tracking
     them, and a release would destroy the shared SandboxAnchorKW jail anchor); a live ambush
     thug (a despawn leaves a live KDNP entry); or mid SexLab/OStim scene.}
    Bool owned = false
    SeverActions_Arrest arrestX = _Arrest()
    ; IsActorInArrest, not HasSession: HasSession is keyed by prisoner and misses the
    ; arresting guard (taking them strands the arrest mid-escort).
    If SeverActionsNativeExt.Native_Jailed_IsJailed(akTarget)         || SeverActionsNative.Native_ArrestSession_IsActorInArrest(akTarget)
        owned = true
    ElseIf SeverActionsNativeExt2.Venture_IsAmbushThug(akTarget)
        owned = true
    EndIf
    If owned
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akActor.GetDisplayName() + " cannot " + verbPhrase + " " + akTarget.GetDisplayName() + " - the law (or worse) already has its hands on them.",             akActor, None)
        Return true
    EndIf
    ; Mid-scene targets (SexLab / OStim): eligibility gates only the speaker, and the
    ; seize would re-package an actor the animation framework owns.
    If SeverActionsNative.Native_Outfit_IsInAnimationScene(akTarget)
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akActor.GetDisplayName() + " cannot " + verbPhrase + " " + akTarget.GetDisplayName() + " - they are rather occupied at the moment.",             akActor, None)
        Return true
    EndIf
    Return false
EndFunction

Bool Function _RejectIfActorOccupied(Actor akActor, String verbPhrase)
    {Speaker-side twin of _RejectInvalidCaptiveTarget: TRUE, with a narrated refusal, when
     the would-be captor is in an arrest on either side (two FSMs would fight over their
     packages and captured AVs) or in a SexLab/OStim scene. Hard guard behind the
     kidnapnpc/restrainnpc.yaml eligibility rules, for the Prisma Actions page and any
     eligibility miss. Reads our own arrest state, not SkyrimNet's is_busy (v6+, false when absent).}
    If !akActor
        Return false
    EndIf
    If SeverActionsNative.Native_ArrestSession_IsActorInArrest(akActor)
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akActor.GetDisplayName() + " is in the middle of an arrest and cannot " + verbPhrase + ".",             akActor, None)
        Return true
    EndIf
    If SeverActionsNative.Native_Outfit_IsInAnimationScene(akActor)
        SkyrimNetApi.RegisterEvent("kidnap_failed",             akActor.GetDisplayName() + " is rather occupied and cannot " + verbPhrase + ".",             akActor, None)
        Return true
    EndIf
    Return false
EndFunction

Function _PacifyCaptive(Actor akVictim)
    {Capture, then zero Aggression/Confidence (zeroing without the capture pacifies them for
     good), and add the prisoner faction so guards stay out. Shared by the kidnap grab and the
     restrain bind; _UnbindCaptive undoes both (-1 = AVs never captured).}
    SeverActionsNativeExt.Native_Kidnap_CaptureAVs(akVictim, akVictim.GetAV("Aggression"), akVictim.GetAV("Confidence"))
    akVictim.SetAV("Aggression", 0)
    akVictim.SetAV("Confidence", 0)
    SeverActions_Arrest arrestP = _Arrest()
    If arrestP && arrestP.dunPrisonerFaction
        akVictim.AddToFaction(arrestP.dunPrisonerFaction)
    EndIf
    ; SkyrimNet applies its packages from a package-eval hook that outranks every ActorUtil
    ; override and alias package (its priority only ranks SkyrimNet's own), so a victim
    ; carrying its FollowPlayer walks to the player whenever unpinned. Clear SkyrimNet's
    ; stack; KidnapTick heals a mid-captivity re-issue.
    SkyrimNetApi.ClearAllPackages(akVictim)
    SkyrimNetApi.CancelPendingPackageTasks(akVictim)
EndFunction

Bool Function _RejectIfBoundActor(Actor akActor, String verbPhrase)
    {TRUE, with a narrated refusal, when akActor is themselves a bound kidnap/restraint
     victim (phase >= 2), so a captive can neither free themselves nor take captives. Phase 1
     (only being approached) has no bonds yet. Hard guard behind the is_kidnap_victim
     eligibility rule, for the Prisma Actions page and any eligibility miss.}
    If !akActor || SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) < 2
        Return false
    EndIf
    SkyrimNetApi.RegisterEvent("kidnap_failed", \
        akActor.GetDisplayName() + " strains against their bonds, but a bound captive cannot " + verbPhrase + ".", \
        akActor, None)
    Return true
EndFunction

Function ReleaseCaptive(Actor akActor, String targetName)
    {Free a held (or in-transit) kidnap victim. Called by SkyrimNet via
     releasecaptive.yaml — akActor is whoever unties them.}
    If !akActor
        Return
    EndIf
    If _RejectIfBoundActor(akActor, "free anyone, least of all themselves")
        Return
    EndIf

    ; Resolve among ACTIVE victims only (never a global scan here).
    Actor victim = None
    Actor[] victims = SeverActionsNativeExt.Native_Kidnap_ListVictims()
    If !victims || victims.Length == 0
        Return
    EndIf
    If victims.Length == 1 && targetName == ""
        victim = victims[0]
    Else
        Int i = 0
        While i < victims.Length && !victim
            If victims[i] && StringUtil.Find(victims[i].GetDisplayName(), targetName) >= 0
                victim = victims[i]
            EndIf
            i += 1
        EndWhile
    EndIf
    If !victim
        ; Refuse out loud (see UntieCaptive).
        SkyrimNetApi.RegisterEvent("kidnap_failed", \
            akActor.GetDisplayName() + " looks for a captive called " + targetName + " to free, but holds no one by that name.", \
            akActor, None)
        Return
    EndIf
    Int relPhase = SeverActionsNativeExt.Native_Kidnap_GetPhase(victim)

    Actor kidnapper = SeverActionsNativeExt.Native_Kidnap_GetKidnapper(victim)
    If kidnapper
        _EndGuardDuty(kidnapper)
        _EndDispatchAliases(kidnapper, victim)
        ; A restrain released mid-approach: strip the restrainer's walk-up, which
        ; _EndGuardDuty leaves, or they trail the freed target forever.
        If SeverActionsNativeExt.Native_Kidnap_GetFlag(victim, KIDNAP_FLAG_RESTRAINT)
            SeverActionsNativeExt.Arrival_Cancel(kidnapper)
            _EndRestrainApproach(kidnapper)
        EndIf
        ; A journey in progress (no-op when not travelling).
        _CancelTravel(kidnapper)
    EndIf
    ; Consequences BEFORE the entry is cleared (reads grab record + flags).
    _FireKidnapReleaseConsequences(victim)
    _FreeCaptiveAlias(victim)  ; also done by _UnbindCaptive
    _UnbindCaptive(victim)
    _DeleteKidnapHomeMarker(victim)
    SeverActionsNativeExt.Native_Kidnap_Clear(victim)

    If relPhase == 1
        ; Approach-only: no bonds yet, so no "freed from captivity".
        SkyrimNetApi.RegisterEvent("kidnap_aborted", \
            akActor.GetDisplayName() + " called off the attempt on " + victim.GetDisplayName() + " before anything happened.", \
            akActor, victim)
        Return
    EndIf
    SkyrimNetApi.RegisterPersistentEvent( \
        akActor.GetDisplayName() + " has freed " + victim.GetDisplayName() + " from captivity.", \
        akActor, victim)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("followermanager.hasBeenFreed", ("" + victim.GetDisplayName())))
EndFunction

Function _UnbindCaptive(Actor akVictim)
    {Tear down all kidnap state on the victim: ropes, restraint, hood, cuffs, packages,
     LinkedRefs, prisoner faction, captured AVs, hold marker. Safe in any phase (each step
     no-ops when absent). The furniture package/keyword lines heal legacy captives from the
     removed furniture-sandbox hold (a cell-attach CTD).}
    ; Ropes first (the furniture tie's holderless one and the leash), so nothing tugs a
    ; freed captive once the packages come off.
    _ClearFurnitureTie(akVictim)
    _DetachPhysicalLeash(akVictim)
    ; Leash remnants (kFlagLeashed): the escort-follow package and its LinkedRef.
    SeverActions_Arrest arrestLz = _Arrest()
    If arrestLz && arrestLz.SeverActions_FollowGuard_Prisoner
        ActorUtil.RemovePackageOverride(akVictim, arrestLz.SeverActions_FollowGuard_Prisoner)
    EndIf
    If arrestLz && arrestLz.SeverActions_FollowTargetKW
        SeverActionsNative.LinkedRef_Clear(akVictim, arrestLz.SeverActions_FollowTargetKW)
    EndIf
    StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_LeashLeader")
    SeverActions_Arrest arrest = _Arrest()
    Keyword furnKW = SeverActions_FurnitureLib.TargetKeyword()
    Package furnPkg = SeverActions_FurnitureLib.UsePackage()

    ; The victim's own journey (the leg-2 fallback); no-op when none.
    _CancelTravel(akVictim)

    ; Release the restraint + play the getting-up animation.
    akVictim.SetDontMove(false)
    akVictim.SetRestrained(false)
    StorageUtil.UnsetIntValue(akVictim, "SeverRestrain_Posed")
    Idle kneelExit = Game.GetFormFromFile(KIDNAP_IDLE_KNEEL_EXIT, "Skyrim.esm") as Idle
    If kneelExit
        akVictim.PlayIdle(kneelExit)
    EndIf

    ; The hold: BoundCaptiveSit package, captive alias, and the legacy furniture-sandbox
    ; package + LinkedRef.
    Package sitPkgRel = Game.GetFormFromFile(KIDNAP_SIT_PKG_FORMID, "SeverActions.esp") as Package
    If sitPkgRel
        ActorUtil.RemovePackageOverride(akVictim, sitPkgRel)
    EndIf
    _FreeCaptiveAlias(akVictim)
    ; The guard sandbox (normally only the captor carries it). UntieCaptive's PrisonerSandBox
    ; and its SandboxAnchorKW LinkedRef go with the anchor block below.
    Package guardPkgRel = Game.GetFormFromFile(KIDNAP_GUARD_PKG_FORMID, "SeverActions.esp") as Package
    If guardPkgRel
        ActorUtil.RemovePackageOverride(akVictim, guardPkgRel)
    EndIf
    If furnPkg
        ActorUtil.RemovePackageOverride(akVictim, furnPkg)
    EndIf
    If furnKW
        SeverActionsNative.LinkedRef_Clear(akVictim, furnKW)
    EndIf
    If arrest
        If arrest.SeverActions_FollowGuard_Prisoner
            ActorUtil.RemovePackageOverride(akVictim, arrest.SeverActions_FollowGuard_Prisoner)
        EndIf
        If arrest.SeverActions_FollowTargetKW
            SeverActionsNative.LinkedRef_Clear(akVictim, arrest.SeverActions_FollowTargetKW)
        EndIf
        ; The hold anchor: the bind's jail-pattern pin, or UntieCaptive's loose sandbox.
        If arrest.SeverActions_PrisonerSandBox
            ActorUtil.RemovePackageOverride(akVictim, arrest.SeverActions_PrisonerSandBox)
        EndIf
        If arrest.SeverActions_SandboxAnchorKW
            SeverActionsNative.LinkedRef_Clear(akVictim, arrest.SeverActions_SandboxAnchorKW)
        EndIf
        If arrest.dunPrisonerFaction
            akVictim.RemoveFromFaction(arrest.dunPrisonerFaction)
        EndIf
    EndIf

    ; Hood off + out of inventory.
    Armor hood = Game.GetFormFromFile(KIDNAP_HOOD_FORMID, "Skyrim.esm") as Armor
    If hood
        akVictim.UnequipItem(hood, false, true)
        akVictim.RemoveItem(hood, 1, true)
    EndIf

    ; Cuffs off (equipped at the seizure by _OnKidnapGrabResolved).
    If arrest && arrest.SeverActions_PrisonerCuffs
        akVictim.UnequipItem(arrest.SeverActions_PrisonerCuffs, false, true)
        akVictim.RemoveItem(arrest.SeverActions_PrisonerCuffs, 1, true)
    EndIf

    ; Restore the captured AVs (sentinel -1 = never captured — leave alone).
    Float origAggr = SeverActionsNativeExt.Native_Kidnap_GetOrigAggression(akVictim)
    If origAggr >= 0.0
        akVictim.SetAV("Aggression", origAggr)
    EndIf
    Float origConf = SeverActionsNativeExt.Native_Kidnap_GetOrigConfidence(akVictim)
    If origConf >= 0.0
        akVictim.SetAV("Confidence", origConf)
    EndIf

    ; Delete the placed bound-captive marker.
    ObjectReference marker = SeverActionsNativeExt.Native_Kidnap_GetMarker(akVictim)
    If marker
        marker.Disable()
        marker.Delete()
    EndIf

    ; Break the furniture/idle lock so they actually stand up.
    Debug.SendAnimationEvent(akVictim, "IdleForceDefaultState")
    akVictim.EvaluatePackage()
EndFunction

Event OnInit()
    ; No setup here (DR20, F35): KidnapMaintenance runs from the arrest provider's stage 1
    ; on every load and new game.
    Debug.Trace("[SeverActions] SeverActions_Kidnap: bound")
EndEvent
