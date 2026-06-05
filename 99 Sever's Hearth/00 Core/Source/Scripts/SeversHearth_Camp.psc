ScriptName SeversHearth_Camp extends Quest
{Sever's Hearth - core camp lifecycle. Member functions called by SkyrimNet actions.}

; ============================================================================
; Sandbox wiring (user-provided package, applied via PapyrusUtil's ActorUtil).
;
; To enable follower sandboxing while a camp is active:
;
;   1. Create a Package record in SeversHearth.esp:
;      - Type: Sandbox
;      - Target: Self (simplest — sandbox-around-actor; the actor stays in
;        camp because we only apply the package while camp is up). If you'd
;        rather sandbox-around-fire later, switch Target to a Reference Alias
;        and we can add the matching alias on a future pass.
;      - Radius: ~500-700u (camp footprint is ~440 × 400)
;      - Sandbox flags: Sit / Sleep / Cook / Use Idle Markers as desired
;      - No conditions needed — Papyrus owns lifecycle
;      - Any EditorID — we reference the Form directly, not by name
;
;   2. Pick the package from CK's dropdown on this script's Properties tab:
;      - CampSandboxPackage = your new Package
;
; Runtime: ActorUtil.AddPackageOverride / RemovePackageOverride (PapyrusUtil)
; apply the package directly to each occupant. PapyrusUtil is a near-universal
; soft dep (required by SkyUI MCM, SexLab, NFF). If the package isn't picked
; or PapyrusUtil isn't loaded, the layer no-ops silently and the camp
; lifecycle still works (followers fall back to their normal AI).
;
; Tracked actors are remembered in a fixed-capacity instance array so
; BreakCamp can remove the override from each even if the camp spans a
; save/reload.
; ============================================================================

Package Property CampSandboxPackage Auto
{User-created Sandbox package, picked from CK's dropdown. None = layer disabled.

Applied at runtime via PapyrusUtil's ActorUtil.AddPackageOverride.}

; ── IntelEngine "the camp" travel integration ────────────────────────────
; User creates a BGSLocation record in CK:
;   EditorID: SeversHearth_CampLocation
;   FullName: "The Camp"   (or any name IntelEngine should fuzzy-match against)
; and picks it on this Property in the script's Properties tab.
;
; At runtime, after the camp marker spawns, we point this Location's
; worldLocMarker at the marker so IntelEngine's ResolveAnyDestination
; resolves "the camp" → BGSLocation → worldLocMarker → our XMarkerHeading.
; Cleared on BreakCamp so IntelEngine doesn't try to route to a stale ref.
;
; None = integration disabled (no Location bound); camp lifecycle still
; works, NPCs just won't be able to travel to it via the "go to the camp"
; intent. Querying the marker directly via Native_Camp_GetCenterMarker()
; remains available regardless.
Location Property CampLocation Auto
{User-created Location form. Bound at runtime to the camp marker so
 IntelEngine and other location-aware mods can find the camp by name.}

; ── Fast-travel map marker ────────────────────────────────────────────────
; CK setup required:
;   1. In SeversHearth.esp, navigate to a worldspace cell (any persistent
;      cell, doesn't matter where — it'll be MoveTo'd at runtime).
;   2. Place an XMarker.
;   3. On the placement's MapMarker tab: enable, set type = Camp (icon 5),
;      Name = "Camp", check Can Travel To, check Visible.
;   4. Set the placement's flag: Initially Disabled.
;   5. Save the ESP, open the SeversHearth quest, fill the
;      CampMapMarker property with this placement.
;
; At runtime: MarkOnMap calls MoveTo(centerMarker) + Enable, UnmarkFromMap
; calls Disable. The marker's worldspace updates automatically with MoveTo,
; so one placement covers every possible camp location.
;
; None = feature disabled — Mark/Unmark functions no-op silently and the
; button on PrismaUI's Survival page does nothing (state stays "unmarked").
ObjectReference Property CampMapMarker Auto
{User-created MapMarker placement (XMarker with MapMarkerData configured
 in CK). Initially disabled; MoveTo'd to the camp position on demand.}

; Tracking — sandboxed actors so we can unregister on BreakCamp. Fixed
; capacity is 16 slots — vanilla follower cap is 2 but NFF / Nether's /
; Ultimate Follower Overhaul push it to 8+, and party-management mods
; routinely have 12+ tagalongs commanded by the player.
;
; MUST be declared as Auto Hidden Properties, not script-scope variables.
; Papyrus's instance-variable type registration is unreliable for typed arrays:
; assigning `new Actor[N]` to a non-Property Actor[] variable fails at runtime
; with "Cannot create an array into a non-array variable" (verified empirically
; against a Papyrus.0.log dump). Properties get proper type metadata baked into
; the PEX header.
Actor[] Property SandboxedActorTracking Auto Hidden
{Internal — tracking array for sandboxed actors (cap 16). Do not set in CK.}

Int Property SandboxedActorCount = 0 Auto Hidden
{Internal — current count in SandboxedActorTracking.}

; ── SeverActions integration tuning ──────────────────────────────────────
; Per-tick restoration deltas applied to each camp occupant. NEGATIVE
; values reduce the need (good — actor is being fed / rested / warmed).
; Cold gets a bigger reduction than hunger/fatigue to make camping near
; the fire feel meaningfully different from sleeping rough.
;
; Per-tick cadence is set by Native_Camp_SetTickIntervalSeconds (default
; 60 real-seconds ≈ 20 game-minutes at vanilla 20:1 time scale).
Float Property CampRestoreHungerDelta  = -2.0 Auto Hidden
{Hunger restoration per camp tick (negative reduces need). Default -2.0.}

Float Property CampRestoreFatigueDelta = -4.0 Auto Hidden
{Fatigue restoration per camp tick. Higher than hunger — rest restores
 faster than a single meal would. Default -4.0.}

Float Property CampRestoreColdDelta    = -8.0 Auto Hidden
{Cold reduction per camp tick. Highest of the three — the campfire is
 actively warming nearby actors. Default -8.0.}

; ── Camp footprint tuning ───────────────────────────────────────────────
; Lateral tent offset from camp center (used by both _SpawnCampStructures
; and the clearance check below). Hoisted to a property so the layout
; geometry and the pre-camp blocked-position check stay in sync — change
; this and both update.
Float Property TentSideOffset = 200.0 Auto Hidden
{Lateral distance from camp center to each tent's spawn position.
 Kept in sync with CampPlacement.h's spawn offsets — bumped from 180
 to 200 to give followers more lateral breathing room between tents
 and the central fire/seating zone.}

Float Property TreeBlockRadius = 70.0 Auto Hidden
{A tree within this radius of a tent's spawn point counts as "blocking"
 and the camp aborts. ~70u clears a 30u trunk + ~40u tent breathing room.}

Float Property FireBlockRadius = 50.0 Auto Hidden
{A tree within this radius of the fire position blocks the camp.
 Smaller than tent radius — the fire footprint is tighter.}

; ── Lifecycle: register for the SeversHearth_CampTick ModEvent that
; CampSurvivalTick.h fires from the InputEvent heartbeat. Without this
; the heartbeat fires harmlessly and no restoration happens. ────────────

Event OnInit()
    RegisterCampEvents()
EndEvent

Event OnPlayerLoadGame()
    RegisterCampEvents()
    ; Cosave survives saves but PrismaUI doesn't — re-pin the dashboard
    ; rest-stop + camp badge if the player loaded into an active camp.
    ; Sandboxed-actor tracking is a per-script instance array (also
    ; cosave-backed via the Auto Hidden properties) so the badge count
    ; reflects the original session's occupants.
    If Native_Camp_IsActive()
        _PinCampRestStop()
        Debug.Trace("[SeversHearth] OnPlayerLoadGame: re-pinned active camp")
    EndIf
EndEvent

Function RegisterCampEvents()
    {Idempotent — RegisterForModEvent is safe to call multiple times for
     the same event/handler pair (later registrations replace earlier).}
    RegisterForModEvent("SeversHearth_CampTick", "OnCampTickEvent")
    ; SeverActions Survival page dispatches these when the player clicks the
    ; camp action buttons. Safe to register even if SA isn't installed —
    ; events that nobody dispatches just never fire.
    RegisterForModEvent("SeverActions_PrismaBreakCamp",       "OnPrismaBreakCamp")
    RegisterForModEvent("SeverActions_PrismaTravelToCamp",    "OnPrismaTravelToCamp")
    RegisterForModEvent("SeverActions_PrismaToggleCampMarker","OnPrismaToggleCampMarker")
    ; Player-directed follower commands (recruit / follow / wait) — release
    ; the actor from the camp sandbox so they respond to the call instead
    ; of staying pinned to the fire.
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnFollowerCalledByPlayer")
    ; SA's travel orchestrator fires on arrival — used to park GoToCamp-
    ; dispatched followers (WaitingForPlayer=1) when they reach the fire,
    ; so they don't engine-teleport with the player later.
    RegisterForModEvent("SeverActions_TravelComplete", "OnTravelCompleteFromSA")
    Debug.Trace("[SeversHearth] Registered camp tick + PrismaUI button + follower lifecycle ModEvents")
EndFunction

Event OnFollowerCalledByPlayer(string eventName, string strArg, float numArg, Form sender)
    {SeverActions fires this when the player issues a recruit/follow/wait
     command on an actor. If the actor is in our camp sandbox tracking,
     release them so they leave the fire.

     Dismiss intentionally does NOT fire this — a dismissed follower is
     supposed to stay where they are (often that IS the camp).}
    Actor a = sender as Actor
    If !a || !_IsAlreadySandboxed(a)
        Return
    EndIf
    Debug.Trace("[SeversHearth] OnFollowerCalledByPlayer: releasing " + a.GetDisplayName() + " (verb=" + strArg + ")")
    _ReleaseFromCampSandbox(a)
EndEvent

Event OnPrismaToggleCampMarker(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: "Mark / Unmark on Map" button. SA's PrismaUIActionHandler
     prepends "<actorName-or-formID>|" to the strArg payload before sending,
     so what arrives is "0|on" or "0|off" (no actor scope). We split on "|"
     and read the trailing verb. Anything not literally "off" is treated as
     a mark request.}
    Debug.Trace("[SeversHearth] OnPrismaToggleCampMarker fired: strArg='" + strArg + "'")
    If !Native_Camp_IsActive()
        Debug.Trace("[SeversHearth] OnPrismaToggleCampMarker: no active camp, ignoring")
        Return
    EndIf
    ; Extract the verb after the trailing "|" (SA's encoding convention).
    String verb = strArg
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos >= 0
        verb = StringUtil.Substring(strArg, pipePos + 1, 0)
    EndIf
    If verb == "off"
        UnmarkCampOnMap()
    Else
        MarkCampOnMap()
    EndIf
EndEvent

Function MarkCampOnMap()
    {Move the CK-placed CampMapMarker to the camp position, enable it, and
     give it a location-aware name. No-op if CampMapMarker isn't filled
     (CK setup pending) or no camp is active.}
    If !CampMapMarker
        Debug.Trace("[SeversHearth] MarkCampOnMap: CampMapMarker property unfilled — see script docs")
        Debug.Notification("Map marker unavailable: CampMapMarker not configured in CK")
        Return
    EndIf
    ObjectReference center = Native_Camp_GetCenterMarker()
    If !center
        Return
    EndIf
    String locName = Native_Camp_GetLocationName()
    String displayName = "Camp"
    If locName != ""
        displayName = "Camp near " + locName
    EndIf
    CampMapMarker.MoveTo(center)
    CampMapMarker.Enable()
    CampMapMarker.SetDisplayName(displayName, True)
    StorageUtil.SetIntValue(self, "SeversHearth_CampOnMap", 1)
    _PushCampMarkedToPrisma(True)
    Debug.Notification("Camp marked on map.")
EndFunction

Function UnmarkCampOnMap()
    {Disable the CampMapMarker so it no longer appears on the world map.
     The placement stays alive (just hidden) for the next MarkOnMap.}
    If !CampMapMarker
        Return
    EndIf
    CampMapMarker.Disable()
    StorageUtil.SetIntValue(self, "SeversHearth_CampOnMap", 0)
    _PushCampMarkedToPrisma(False)
    Debug.Notification("Camp removed from map.")
EndFunction

Function _PushCampMarkedToPrisma(Bool marked)
    {Push the marker state to SA so the Survival page renders the right
     button label ("Mark on Map" vs "Unmark from Map"). No-op without SA.}
    If !_SeverActionsInstalled()
        Return
    EndIf
    SeverActionsNativeExt.PrismaUI_SetCampMarked(marked)
EndFunction

Event OnTravelCompleteFromSA(string eventName, string strArg, float numArg, Form sender)
    {SA fires this when a travel session ends. For actors we tracked at
     GoToCamp dispatch time, when they arrive at the fire, park them via
     the WaitingForPlayer ActorValue so the engine's auto-pull on cell
     change doesn't yank them back to the player. Keeps teammate flag
     intact so everything downstream of it (SA's Survival page, NFF,
     `is_follower` decorator, vanilla combat assistance) keeps working.

     strArg format is "<tag>|<status>"; only act on status == "arrived".}
    Actor a = sender as Actor
    If !a || !_IsAlreadySandboxed(a)
        Return
    EndIf
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String status = StringUtil.Substring(strArg, pipePos + 1, 0)
    If status != "arrived"
        Return
    EndIf
    a.SetAV("WaitingForPlayer", 1)
    Debug.Trace("[SeversHearth] OnTravelComplete: parked " + a.GetDisplayName() + " at camp (wait=1)")
EndEvent

Event OnPrismaBreakCamp(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Break Camp button. Routes to the existing BreakCamp flow with
     the player as the actor (mimicking a player-initiated breakdown).}
    If !Native_Camp_IsActive()
        Return
    EndIf
    Actor PlayerRef = Game.GetPlayer()
    If PlayerRef
        BreakCamp(PlayerRef)
    EndIf
EndEvent

Event OnPrismaTravelToCamp(string eventName, string strArg, float numArg, Form sender)
    {PrismaUI: Travel to Camp button. Follower-only — routes either a single
     follower (strArg = formID hex) or every player teammate in the player's
     cell (strArg = "all"). Player-targeted travel doesn't fit the use case
     ("send Lydia ahead while I finish here") so it's not supported here.}
    If !Native_Camp_IsActive()
        Return
    EndIf
    If strArg == "all"
        Actor PlayerRef = Game.GetPlayer()
        If !PlayerRef
            Return
        EndIf
        ; Use the same native-side cell scan that the establish-time fan-out
        ; uses so we catch every follower framework's teammates. 1000u is a
        ; loose "in the player's vicinity" radius.
        Actor[] teammates = Native_Camp_FindNearbyTeammates(1000.0)
        If !teammates
            Return
        EndIf
        Int i = 0
        Int dispatched = 0
        While i < teammates.Length
            Actor candidate = teammates[i]
            If candidate && candidate != PlayerRef
                GoToCamp(candidate, 1)
                dispatched += 1
            EndIf
            i += 1
        EndWhile
        Debug.Notification("Sent " + dispatched + " follower" + PluralS(dispatched) + " to camp.")
    Else
        ; Single follower: strArg is the formID in hex string form.
        ; Defer the parse to SA's native HexToInt — ~10000x faster than the
        ; equivalent Papyrus character loop, and the result is bit-for-bit
        ; identical to what the dispatcher encoded with snprintf("%X", fid).
        Int formID = SeverActionsNative.HexToInt(strArg)
        If formID == 0
            Debug.Trace("[SeversHearth] OnPrismaTravelToCamp: invalid strArg '" + strArg + "'")
            Return
        EndIf
        Form f = Game.GetFormEx(formID)
        Actor target = f as Actor
        If target
            GoToCamp(target, 1)
        EndIf
    EndIf
EndEvent

; ============================================================================
; SkyrimNet action entry points (member functions).
; CLAUDE.md rule: executionFunctionName MUST be a member function - SkyrimNet
; calls instance.Function(args) on the quest. Globals never reach.
; ============================================================================

Function EstablishCamp(Actor akActor)
    If Native_Camp_IsActive()
        Debug.Notification("You already have an active camp.")
        Return
    EndIf

    ; Defensive: clear any stale sandbox state left over from a prior camp
    ; that didn't tear down cleanly (crash, manual ref deletion, etc.).
    _ClearCampSandbox()

    Actor PlayerRef = Game.GetPlayer()
    Float angleZ = PlayerRef.GetAngleZ()

    ; Pre-flight clearance peek — runs the same tree-iteration test the
    ; spawn function uses, but does NOT touch cosave state. Lets us
    ; narrate a rejection cleanly without rolling back an Establish.
    If !Native_Camp_IsClearForCamp(angleZ, FireBlockRadius, TreeBlockRadius, TentSideOffset)
        If akActor != None && akActor != PlayerRef
            String narration = "{{ npc.name }} looks around at the trees pressing in, " + \
                               "then shakes their head at {{ player.name }}. " + \
                               "'Not here — the ground's too crowded for the tents. " + \
                               "We'd best find more open ground.'"
            SkyrimNetApi.DirectNarration(narration, akActor, PlayerRef)
        Else
            Debug.Notification("Too crowded here — find a more open spot.")
        EndIf
        Return
    EndIf

    _EstablishCampFlow(akActor, PlayerRef)
EndFunction

; ============================================================================
; GoToCamp — route an NPC to the active camp using SeverActions's travel
; pipeline. Works without IntelEngine (or any other travel mod) so long as
; SeverActions is installed. SA is already a soft dep for survival/PrismaUI;
; without it, the action surfaces a notification and no-ops.
;
; Travel routes through SA's TravelNPCToReference (orchestrator-driven), which
; inherits SA's slot management, anti-stuck recovery, alias plumbing, time-skip
; catch-up, and speed control. The marker is resolved live via
; Native_Camp_GetCenterMarker so we always route to the current camp's marker
; (which can move between camps).
; ============================================================================

SeverActions_Travel Function _GetSATravelScript()
    {Resolve SA's main quest and cast to its travel script. Returns None
     if SA isn't installed or the cast fails.}
    If !_SeverActionsInstalled()
        Return None
    EndIf
    Quest saQuest = Quest.GetQuest("SeverActions")
    Return saQuest as SeverActions_Travel
EndFunction

Function GoToCamp(Actor akNPC, Int speed = 1)
    {SkyrimNet action entry point. The LLM triggers this for phrases like
     "go back to camp" / "head to camp" / "return to the camp". Speed:
     0 = walk, 1 = jog, 2 = run.}
    If !akNPC
        Return
    EndIf
    If !Native_Camp_IsActive()
        Debug.Notification("There is no active camp to travel to.")
        Return
    EndIf
    ObjectReference marker = Native_Camp_GetCenterMarker()
    If !marker
        Debug.Trace("[SeversHearth] GoToCamp: marker missing despite active camp")
        Return
    EndIf

    SeverActions_Travel travelScript = _GetSATravelScript()
    If !travelScript
        Debug.Notification("Travel requires SeverActions to be installed.")
        Debug.Trace("[SeversHearth] GoToCamp: SA travel script unavailable")
        Return
    EndIf

    ; Pass our CampSandboxPackage as the post-arrival override so the
    ; arrived follower joins the campfire crowd rather than falling into
    ; SA's generic sandbox (which would just leave them standing on the
    ; marker). SA applies the override in OnArrived; SA's ClearSlot
    ; removes it on cancel/timeout/teardown.
    travelScript.TravelNPCToReference(akNPC, marker, 0.0, false, speed, CampSandboxPackage)
    ; Register the arriving follower in our sandbox tracking so BreakCamp's
    ; _ClearCampSandbox sweeps them along with the rest. Tracking-only —
    ; the package itself is applied by SA on arrival, not now.
    _TrackForCleanup(akNPC)
    Debug.Trace("[SeversHearth] GoToCamp: dispatched " + akNPC.GetDisplayName() + " (speed=" + speed + ")")
EndFunction

Function BreakCamp(Actor akActor)
    If !Native_Camp_IsActive()
        Debug.Notification("No active camp to break down.")
        Return
    EndIf
    Actor PlayerRef = Game.GetPlayer()
    _BreakCampFlow(akActor, PlayerRef)
EndFunction

; ============================================================================
; Lifecycle — single function for establish, one for break. Phase argument
; matters: a cinematic flow (follower-initiated) wraps the spawn in a
; fade-to-black; a quick flow (player-initiated) doesn't.
;
; Phase transitions (driven here, observable via Native_Camp_GetPhase):
;   Idle → Building → Active     (Establish)
;   Active → Breaking → Idle     (Break)
;
; The Building / Breaking phases are the windows during which the
; survival tick MUST NOT fire — `Native_Camp_IsTickable()` (= phase ==
; Active) is what gates it on the native side.
; ============================================================================

Function _EstablishCampFlow(Actor follower, Actor PlayerRef)
    ; Re-register event handlers every Establish. Saves made before a new
    ; event handler was added bind to the OLD script signature on load —
    ; OnInit/OnPlayerLoadGame fire against the cached binding set, so newly-
    ; added events (e.g. OnPrismaToggleCampMarker, OnFollowerCalledByPlayer)
    ; silently never fire on existing saves. Calling RegisterCampEvents here
    ; refreshes the bindings every camp lifecycle without requiring a new game.
    ; RegisterForModEvent is idempotent so this is safe to call repeatedly.
    RegisterCampEvents()

    Float angleZ = PlayerRef.GetAngleZ()
    Bool cinematic = (follower != None && follower != PlayerRef)

    If cinematic
        _StartFadeToBlack()
        Utility.Wait(1.0)            ; -> t≈1.0s
    EndIf

    ; Establish first so AddPlacedRef registers each spawned ref. Phase
    ; is set to Building by the native — tick is gated off until Active.
    If !Native_Camp_EstablishAtPlayer(angleZ)
        If cinematic
            _EndFadeToBlack()
        EndIf
        Debug.Notification("Failed to establish camp.")
        Return
    EndIf

    If cinematic
        _PlayConstructionSound()
        Utility.Wait(1.5)            ; -> t≈2.5s
        _PlayConstructionSound()
        Utility.Wait(1.5)            ; -> t≈4.0s (spawn window)
        _PlayConstructionSound()
    EndIf

    Int placed = Native_Camp_SpawnStructures(angleZ, FireBlockRadius, TreeBlockRadius, TentSideOffset)
    If placed <= 0
        Native_Camp_Break()
        If cinematic
            _EndFadeToBlack()
        EndIf
        Debug.Notification("Failed to spawn camp structures.")
        Return
    EndIf

    ; AI sandbox transitions happen during the dim window so package
    ; override + EvaluatePackage churn isn't visible.
    If cinematic
        _ApplyCampSandbox(follower)
    EndIf
    _FanOutSandboxToTeammates(PlayerRef, 1000.0)

    ; Flip to Active so the survival tick can start firing.
    Native_Camp_SetPhase(2)  ; CampPhase::Active

    If cinematic
        Utility.Wait(1.5)            ; -> t≈5.5s
        _EndFadeToBlack()
        Utility.Wait(1.5)            ; -> t≈7.0s (screen fully clear)
    EndIf

    _PinCampRestStop()
    Native_Camp_ForceTick()

    ; Auto-place the world-map marker on every Establish. Previously
    ; required a manual Prisma click; the player almost always wants the
    ; marker, so default to "on" and let them Unmark if they want a
    ; stealth camp. No-op if CampMapMarker isn't configured.
    MarkCampOnMap()

    ; IntelEngine integration: point the camp's BGSLocation at the marker
    ; so "go to the camp" resolves correctly. Soft dep — no-op if the
    ; user hasn't picked a Location in CK or IntelEngine isn't installed.
    _BindCampLocationToMarker()

    If cinematic
        String narration = "{{ npc.name }} clears a flat patch of ground near {{ player.name }}, " + \
                           "raises two tents, drives in stakes, kindles a fire, and lays out bedrolls. " + \
                           "A cooking spit is set over the flames and the camp settles into a steady rhythm."
        SkyrimNetApi.DirectNarration(narration, follower, PlayerRef)
    EndIf

    Debug.Notification("Camp established (" + placed + " structure" + PluralS(placed) + ").")
EndFunction

; ============================================================================
; Breakdown flows
;
; A black fade masks the multi-ref despawn — without it 7-9 structures pop
; out of existence simultaneously, which looks like a script crash. Player
; path is brief and silent; follower path is held longer with narration so
; the LLM can reference the teardown afterwards.
; ============================================================================

Function _BreakCampFlow(Actor follower, Actor PlayerRef)
    Bool cinematic = (follower != None && follower != PlayerRef)

    ; Flip to Breaking FIRST so the survival tick can't fire restoration
    ; during the fade window (Native_Camp_IsTickable returns false for
    ; non-Active phases). Sandbox + PrismaUI teardown also happens here
    ; so package overrides clear before refs vanish — no beat where AI
    ; points at a deleted bench.
    Native_Camp_SetPhase(3)  ; CampPhase::Breaking
    _ClearCampRestStop()
    _ClearCampSandbox()
    ; Hide the map marker if the player had it enabled. Disables only —
    ; the CK-placed placement stays alive for re-use by the next camp.
    UnmarkCampOnMap()
    ; Unbind IntelEngine BEFORE the native Break() despawns the marker —
    ; otherwise we'd race with Break clearing centerMarkerID.
    _UnbindCampLocation()

    _StartFadeToBlack()
    Utility.Wait(1.0)            ; -> t≈1.0s

    _PlayConstructionSound()
    Utility.Wait(1.5)            ; -> t≈2.5s
    _PlayConstructionSound()
    Utility.Wait(1.5)            ; -> t≈4.0s
    _PlayConstructionSound()
    Utility.Wait(1.5)            ; -> t≈5.5s — despawn window

    Native_Camp_DespawnPlacedRefs()
    Native_Camp_Break()  ; Breaking -> Idle; clears cosave fields.

    _EndFadeToBlack()

    If cinematic
        Utility.Wait(1.5)        ; -> t≈7.0s (screen fully clear)
        String narration = "{{ npc.name }} dismantles the tent, scatters and snuffs the embers, " + \
                           "rolls up the bedroll, packs the gear, and leaves only flattened grass " + \
                           "where the camp had stood."
        SkyrimNetApi.DirectNarration(narration, follower, PlayerRef)
    EndIf

    Debug.Notification("Camp broken down.")
EndFunction

; ============================================================================
; Sound helpers
; ============================================================================

; Plays vanilla NPCHumanWoodChop (Skyrim.esm 0x0006D1CA) at the player.
; One-shot, non-blocking; safe to call multiple times in sequence to layer
; "construction effort" audio during the black-screen window. Falls through
; silently if the form can't resolve (e.g. wrong base game version).
Function _PlayConstructionSound()
    Sound chop = Game.GetFormFromFile(0x0006D1CA, "Skyrim.esm") as Sound
    If chop
        chop.Play(Game.GetPlayer())
    EndIf
EndFunction

; ============================================================================
; Fade-to-black (Game.FadeOutGame path — Community-Shaders compatible).
;
; The vanilla three-IMOD stack (0x000F756D/E/F) is broken under Community
; Shaders' replacement post-process pipeline — the Apply calls fire but
; never reach the final tonemap. FadeOutGame uses different machinery
; (the loading-screen blackout path) that CS lets through.
;
; Trade-off: FadeOutGame locks player controls during the transition.
; For camp construction this is correct — the player shouldn't wander
; mid-build.
; ============================================================================

Bool Property UseFadeToBlack = True Auto Hidden
{If True, the establish/break flows fade the screen to black while structures
 spawn/despawn. Toggle off via MCM (future) or script for cinematic-free
 testing. Defaults True to preserve the camera-cut UX.}

; Fade-duration tuning.
;
; FadeOutSeconds is the fade-OUT ANIMATION duration. FadeOutGame doesn't
; naturally hold black after its animation completes (it releases under
; Community Shaders; vanilla behaviour is also inconsistent). The trick:
; make the animation long enough to span the whole camp setup sequence
; (~5.5s — initial 1.0s wait + three 1.5s sound spacings). While the
; animation is in-flight, the screen is held in its current interpolated
; state — never reaching "completion" and never releasing.
;
; Visual: the screen darkens progressively over the duration rather than
; snapping at 1s. The early construction is dimly visible (~30% dark at
; t=2s, ~70% at t=4s) and effectively hidden by t=5s. Plays as a
; "twilight closes over the camp" effect rather than a hard cut. Tune
; via the property below if a snappier vs slower transition is desired.
;
; v1d-5 attempted to keep the fade snappy via an OnUpdate refresh loop
; that re-applied FadeOutGame every 0.5s. That made the screen flicker
; on every refresh (each call re-animated rather than holding), so it's
; gone in v1d-6.
Float Property FadeOutSeconds = 6.0 Auto Hidden
Float Property FadeInSeconds  = 1.5 Auto Hidden

; Start the fade. Locks player controls and animates the screen to black
; over FadeOutSeconds. _EndFadeToBlack interrupts the in-flight
; animation when the camp setup completes.
Function _StartFadeToBlack()
    If !UseFadeToBlack
        Return
    EndIf
    Debug.Trace("[SeversHearth] _StartFadeToBlack: FadeOutGame out=" + FadeOutSeconds + "s")
    Game.FadeOutGame(true, true, 0.0, FadeOutSeconds)
EndFunction

; Interrupt the in-flight fade-out animation and transition back to
; clear over FadeInSeconds. bFadingOut=false reverses direction
; regardless of where the previous fade was in its animation, so
; calling this at any point during the camp setup works cleanly.
Function _EndFadeToBlack()
    If !UseFadeToBlack
        Return
    EndIf
    Debug.Trace("[SeversHearth] _EndFadeToBlack: FadeOutGame in=" + FadeInSeconds + "s")
    Game.FadeOutGame(false, true, 0.0, FadeInSeconds)
EndFunction

; ============================================================================
; Sandbox helpers
;
; PO3 PapyrusExtenderSSE exposes AddPackageOverride/RemovePackageOverride as
; globals taking (Actor, Package, ...) — fills the gap left by vanilla, which
; has no Papyrus surface for runtime package overrides. We pass the Package
; Form directly; no EditorID string lookup, no SkyrimNet round-trip.
;
; EvaluatePackage forces immediate AI re-evaluation so the transition happens
; during the fade, not on the next vanilla tick (which can be many seconds).
;
; Both helpers no-op silently if CampSandboxPackage is None or po3 isn't
; loaded — camp lifecycle stays robust regardless.
; ============================================================================

Function _ApplyCampSandbox(Actor occupant)
    If !occupant || !CampSandboxPackage
        ; Silent at the per-actor level — _FanOutSandboxToTeammates and the
        ; cinematic call site hoist the diagnostic so the player sees one
        ; notification per camp, not one per follower.
        Return
    EndIf
    ; Idempotent — don't double-add the same actor (the speaker often appears
    ; in the commanded-actors set too, so the fan-out path would re-add).
    If _IsAlreadySandboxed(occupant)
        Return
    EndIf

    ; Lazy-init the tracking array. Cap chosen large enough for NFF/UFO/etc.
    ; Truthiness check (`If !arr`) is the safe idiom for typed-array None
    ; tests in Papyrus — explicit `== None` against a typed array property
    ; throws "Cannot cast from None to Actor[]" at runtime when loaded
    ; from a save that pre-dates the property's existence.
    If !SandboxedActorTracking
        SandboxedActorTracking = new Actor[16]
        SandboxedActorCount = 0
    EndIf

    ; Refuse-past-cap: do NOT apply an override we can't unregister later.
    ; The prior version applied the override before the capacity check, so
    ; over-cap followers got a permanent stuck package on BreakCamp.
    If SandboxedActorCount >= SandboxedActorTracking.Length
        Debug.Trace("[SeversHearth] Sandbox capacity reached (" + SandboxedActorCount + ") — skipping " + occupant)
        Return
    EndIf

    ; Park the actor via the vanilla WaitingForPlayer ActorValue — same
    ; mechanism SA's CompanionWait uses, same mechanism Skyrim's own
    ; DialogueFollower "Wait here" dialog uses. Engine sees this flag and
    ; skips the auto-pull on cell change without us touching teammate
    ; status. That preserves combat assistance, follower-count globals,
    ; `is_follower` decorator behavior, NFF framework detection, and SA's
    ; own follower-store identification — none of which we'd want to
    ; collateral-damage just to keep someone at the fire.
    occupant.SetAV("WaitingForPlayer", 1)

    ActorUtil.AddPackageOverride(occupant, CampSandboxPackage, 100, 0)
    occupant.EvaluatePackage()
    SandboxedActorTracking[SandboxedActorCount] = occupant
    SandboxedActorCount += 1
EndFunction

Function _ReleaseFromCampSandbox(Actor a)
    {Release a single actor from the camp sandbox without breaking the whole
     camp. Removes the package override, restores their prior teammate state,
     and removes them from the tracking array.

     Called from OnFollowerCalledByPlayer when SA fires the recruit/follow/wait
     handshake — lets the player take one follower along while leaving the rest
     at the fire.}
    If !a
        Return
    EndIf
    If CampSandboxPackage
        ActorUtil.RemovePackageOverride(a, CampSandboxPackage)
    EndIf
    ; Clear the wait flag — symmetric with the WaitingForPlayer=1 we set in
    ; _ApplyCampSandbox. Resume vanilla follower behavior.
    a.SetAV("WaitingForPlayer", 0)
    a.EvaluatePackage()

    ; Compact the tracking array: shift later entries down, drop count.
    Int i = 0
    Bool found = False
    While i < SandboxedActorCount
        If !found && SandboxedActorTracking[i] == a
            found = True
        EndIf
        If found && i + 1 < SandboxedActorCount
            SandboxedActorTracking[i] = SandboxedActorTracking[i + 1]
        EndIf
        i += 1
    EndWhile
    If found
        SandboxedActorTracking[SandboxedActorCount - 1] = None
        SandboxedActorCount -= 1
    EndIf
EndFunction

Function _TrackForCleanup(Actor a)
    {Register an actor in SandboxedActorTracking without applying any
     package override. Used when SA's travel orchestrator will apply the
     CampSandboxPackage on arrival (via the TravelNPCToReference override
     param) — we still need to track the actor so _ClearCampSandbox sweeps
     them on BreakCamp.}
    If !a || _IsAlreadySandboxed(a)
        Return
    EndIf
    If !SandboxedActorTracking
        SandboxedActorTracking = new Actor[16]
        SandboxedActorCount = 0
    EndIf
    If SandboxedActorCount >= SandboxedActorTracking.Length
        Debug.Trace("[SeversHearth] _TrackForCleanup: cap reached, skipping " + a)
        Return
    EndIf
    SandboxedActorTracking[SandboxedActorCount] = a
    SandboxedActorCount += 1
EndFunction

Bool Function _IsAlreadySandboxed(Actor a)
    If !SandboxedActorTracking || SandboxedActorCount == 0
        Return False
    EndIf
    Int i = 0
    While i < SandboxedActorCount
        If SandboxedActorTracking[i] == a
            Return True
        EndIf
        i += 1
    EndWhile
    Return False
EndFunction

; Fan the sandbox out to every nearby player-teammate. Uses the native
; cell-scan in CampPlacement.h which finds every IsPlayerTeammate() actor
; within radius — works across vanilla / NFF / AFT / UFO / Inigo / Lucien
; without needing per-framework integration, because IsPlayerTeammate is
; the canonical flag every framework respects.
;
; Prior version used PO3's GetCommandedActors which only returned vanilla-
; commanded actors and missed NFF-managed followers in particular.
;
; Called by both establish flows so player-driven camps also populate.
Function _FanOutSandboxToTeammates(Actor playerRef, Float maxDistance)
    If !playerRef
        Return
    EndIf

    ; Loud diagnostic for the common "followers don't sandbox" symptom — the
    ; root cause is almost always an unfilled CampSandboxPackage property in
    ; the SeversHearth quest. Surfaces ONCE per fan-out (not per follower).
    If !CampSandboxPackage
        Debug.Trace("[SeversHearth] ERROR: CampSandboxPackage property is None — fix the SeversHearth quest in CK")
        Debug.Notification("Camp sandbox unavailable: CampSandboxPackage missing")
        Return
    EndIf

    Actor[] teammates = Native_Camp_FindNearbyTeammates(maxDistance)
    If !teammates || teammates.Length == 0
        Debug.Trace("[SeversHearth] Fan-out: no nearby teammates within " + maxDistance + "u")
        Return
    EndIf

    Int applied = 0
    Int i = 0
    While i < teammates.Length
        Actor candidate = teammates[i]
        If candidate && candidate != playerRef
            _ApplyCampSandbox(candidate)
            applied += 1
        EndIf
        i += 1
    EndWhile
    Debug.Trace("[SeversHearth] Fan-out: sandboxed " + applied + " teammates")
EndFunction

Function _ClearCampSandbox()
    If !SandboxedActorTracking || SandboxedActorCount == 0
        Return
    EndIf

    Int i = 0
    While i < SandboxedActorCount
        Actor a = SandboxedActorTracking[i]
        If a
            If CampSandboxPackage
                ActorUtil.RemovePackageOverride(a, CampSandboxPackage)
            EndIf
            ; Clear the wait flag — they should resume normal follower
            ; behavior now that the camp is breaking down.
            a.SetAV("WaitingForPlayer", 0)

            ; Cancel any in-flight SA travel for this actor. Catches the
            ; case where BreakCamp fires while a GoToCamp dispatch is still
            ; traveling — SA's CancelByActor also tears down the per-slot
            ; sandbox override on its side. Safe-call: no-op if SA isn't
            ; installed or the actor has no active travel.
            If _SeverActionsInstalled()
                SeverActionsNativeExt.Travel_CancelByActor(a)
            EndIf
            a.EvaluatePackage()
            SandboxedActorTracking[i] = None
        EndIf
        i += 1
    EndWhile
    SandboxedActorCount = 0
EndFunction

; ============================================================================
; SeverActions integration — survival restoration tick + rest stop pin.
;
; CampSurvivalTick.h (native InputEvent heartbeat) fires the
; SeversHearth_CampTick ModEvent every ~60 real-seconds while a camp is
; active. The handler below iterates every tracked sandboxed actor and
; calls SeverActions's Native_Survival_AdjustNeeds with the per-tick
; deltas (CampRestoreHungerDelta / FatigueDelta / ColdDelta).
;
; The whole integration is gated on SeverActions actually being
; installed — if `Game.GetModByName("SeverActions.esp") == 255` the
; calls never fire and SeversHearth runs in pure-camp mode (no
; restoration, but the sandbox / lifecycle still works).
;
; The rest-stop pin sets the dashboard's "Pinned rest stop" label so the
; Hearth Ledger surface shows "Camp near <location>" while the camp is
; up. Cleared on BreakCamp.
; ============================================================================

Bool Function _SeverActionsInstalled()
    {Cached enough — Game.GetModByName is a hash lookup, fast.}
    Return Game.GetModByName("SeverActions.esp") != 255
EndFunction

Bool Function _IntelEngineInstalled()
    {Same pattern as SeverActions install check.}
    Return Game.GetModByName("IntelEngine.esp") != 255
EndFunction

; Wire / unwire the runtime location → marker association that lets
; IntelEngine resolve "go to the camp". No-op if the user hasn't bound a
; CampLocation in CK, OR if there's no live marker, OR if IntelEngine
; isn't installed (the last gate covers only the RebuildLocationIndex
; call — the worldLocMarker write is harmless regardless).
Function _BindCampLocationToMarker()
    If !CampLocation
        Debug.Trace("[SeversHearth] CampLocation property not bound; IntelEngine integration skipped")
        Return
    EndIf
    ObjectReference marker = Native_Camp_GetCenterMarker()
    If !marker
        Debug.Trace("[SeversHearth] No active marker to bind CampLocation against")
        Return
    EndIf
    If Native_Camp_BindLocationToMarker(CampLocation, marker)
        If _IntelEngineInstalled()
            IntelEngine.RebuildLocationIndex()
            Debug.Trace("[SeversHearth] CampLocation bound; IntelEngine index rebuilt")
        Else
            Debug.Trace("[SeversHearth] CampLocation bound (IntelEngine not installed; rebuild skipped)")
        EndIf
    EndIf
EndFunction

Function _UnbindCampLocation()
    If !CampLocation
        Return
    EndIf
    Native_Camp_UnbindLocation(CampLocation)
    If _IntelEngineInstalled()
        IntelEngine.RebuildLocationIndex()
    EndIf
    Debug.Trace("[SeversHearth] CampLocation unbound from marker")
EndFunction

; Maximum distance (units) from the camp center an actor can be while still
; counting as "at camp" for the restoration tick. ~700u is loosely the camp
; footprint (440x400) plus a generous margin for furniture interaction.
Float Property CampOccupantMaxDistance = 700.0 Auto Hidden
{Actors farther than this from the camp center don't get tick restoration.}

Event OnCampTickEvent(string eventName, string strArg, float numArg, Form sender)
    If !Native_Camp_IsActive() || !_SeverActionsInstalled()
        Return
    EndIf

    Float cx = Native_Camp_GetPosX()
    Float cy = Native_Camp_GetPosY()
    Float cz = Native_Camp_GetPosZ()
    Float maxDist = CampOccupantMaxDistance

    Int restored = 0

    ; Player first — gated by distance to the stored camp center so the
    ; player can't wander off and still be "resting".
    Actor PlayerRef = Game.GetPlayer()
    If PlayerRef && _IsActorAtCamp(PlayerRef, cx, cy, cz, maxDist)
        SeverActionsNative.Native_Survival_AdjustNeeds(PlayerRef, \
            CampRestoreHungerDelta, CampRestoreFatigueDelta, CampRestoreColdDelta)
        restored += 1
    EndIf

    ; Sandboxed followers — same distance gate; a follower lagging behind
    ; on a horse shouldn't get restoration.
    If SandboxedActorTracking && SandboxedActorCount > 0
        Int i = 0
        While i < SandboxedActorCount
            Actor occupant = SandboxedActorTracking[i]
            If occupant && _IsActorAtCamp(occupant, cx, cy, cz, maxDist)
                SeverActionsNative.Native_Survival_AdjustNeeds(occupant, \
                    CampRestoreHungerDelta, CampRestoreFatigueDelta, CampRestoreColdDelta)
                restored += 1
            EndIf
            i += 1
        EndWhile
    EndIf

    Debug.Trace("[SeversHearth] CampTick: restored " + restored + " occupants at camp")

    ; Push live camp meta + threats to the SeverActions Survival page. These
    ; are safe to call repeatedly — SA stores them in a singleton mutex-guarded
    ; struct. Cleared automatically when SetCampStatus(false) fires on break.
    _PushCampMetaToPrisma()
EndEvent

Function _PushCampMetaToPrisma()
    {Push live meta (hours since established, player-to-camp distance) to
     SeverActions's Survival page. No-op if SA isn't installed. Called from
     the camp tick and after EstablishCamp.

     Threats are NOT pushed from here — CampThreatWatch.h drives those
     natively from TESCombatEvent + TESCellAttachDetachEvent, so the banner
     reacts the moment hostiles spawn or engage rather than waiting for the
     next ~60s tick. Avoids the polling overhead entirely.}
    If !_SeverActionsInstalled()
        Return
    EndIf
    Float hours = Native_Camp_HoursSinceEstablished()
    Float distance = Native_Camp_DistanceFromPlayer()
    SeverActionsNativeExt.PrismaUI_SetCampMeta(hours, distance)
EndFunction

Bool Function _IsActorAtCamp(Actor a, Float cx, Float cy, Float cz, Float maxDist)
    Float dx = a.GetPositionX() - cx
    Float dy = a.GetPositionY() - cy
    Float dz = a.GetPositionZ() - cz
    Return (dx * dx + dy * dy + dz * dz) <= (maxDist * maxDist)
EndFunction

Function _PinCampRestStop()
    {Set the dashboard rest-stop label AND the Survival page camp badge.
     Called after a successful EstablishCamp. No-op if SeverActions
     isn't installed.}
    If !_SeverActionsInstalled()
        Return
    EndIf
    String loc = Native_Camp_GetLocationName()
    String label
    If loc != ""
        label = "Camp near " + loc
    Else
        label = "Wilderness camp"
    EndIf
    SeverActionsNative.PrismaUI_SetPinnedRestStop(label)

    ; Survival-page badge — the occupant count is (sandboxed followers + 1
    ; for the player). Location uses the bare location name (no "Camp near"
    ; prefix) so the badge reads "🏕 At Camp · N resting · Whiterun".
    Int occupants = SandboxedActorCount + 1
    SeverActionsNative.PrismaUI_SetCampStatus(true, loc, occupants)
    ; Seed meta immediately so the Survival page detail section has real
    ; data on first render, not 60s later on the first tick.
    _PushCampMetaToPrisma()
    ; Kick a fresh threat scan — CampThreatWatch otherwise waits for the
    ; next combat / cell-attach event, which won't fire for latent hostiles
    ; that were already nearby when the camp was pitched.
    Native_Camp_KickThreatScan()

    Debug.Trace("[SeversHearth] Pinned rest stop + camp badge: '" + label + "' (" + occupants + " occupants)")
EndFunction

Function _ClearCampRestStop()
    {Clear the dashboard rest-stop label AND the Survival page camp
     badge. Called from BreakCamp.}
    If !_SeverActionsInstalled()
        Return
    EndIf
    SeverActionsNative.PrismaUI_SetPinnedRestStop("")
    SeverActionsNative.PrismaUI_SetCampStatus(false, "", 0)
    Debug.Trace("[SeversHearth] Cleared rest stop pin + camp badge")
EndFunction

; ============================================================================
; Helpers
; ============================================================================

String Function PluralS(Int n)
    If n == 1
        Return ""
    EndIf
    Return "s"
EndFunction

; ============================================================================
; Native bindings (registered by SeversHearthNative.dll).
; ============================================================================

Bool Function Native_Camp_EstablishAtPlayer(Float angleZ) Global Native
Function Native_Camp_Break() Global Native
Bool Function Native_Camp_IsActive() Global Native
; Phase: 0=Idle, 1=Building, 2=Active, 3=Breaking. Native sets Building
; on Establish; Papyrus side flips to Active once spawn completes, then
; to Breaking at top of teardown so the survival tick stops firing.
Int  Function Native_Camp_GetPhase() Global Native
Function Native_Camp_SetPhase(Int phase) Global Native
Float Function Native_Camp_GetPosX() Global Native
Float Function Native_Camp_GetPosY() Global Native
Float Function Native_Camp_GetPosZ() Global Native
Float Function Native_Camp_GetAngleZ() Global Native
Float Function Native_Camp_HoursSinceEstablished() Global Native
Float Function Native_Camp_DistanceFromPlayer() Global Native
String Function Native_Camp_GetLocationName() Global Native
Function Native_Camp_RegisterPlacedRef(ObjectReference akRef) Global Native
Function Native_Camp_DespawnPlacedRefs() Global Native
Int Function Native_Camp_GetPlacedRefCount() Global Native
Float Function Native_Camp_GetTerrainZ(Float x, Float y, Float fallbackZ) Global Native

; Returns the short narrative threats tag — mirrors the SkyrimNet
; camp_threats_nearby decorator. Empty when no camp / no hostiles.
; Kept as a query API; the actual Survival-page push is event-driven
; via CampThreatWatch (see Native_Camp_KickThreatScan).
String Function Native_Camp_GetThreatsText() Global Native

; Immediately re-run the threat scan and push the result to SA. Called
; after EstablishCamp so an already-hostile camp neighborhood shows on
; the banner without waiting for the next TESCombatEvent. CampThreatWatch
; otherwise drives this from combat + cell-attach events natively.
Function Native_Camp_KickThreatScan() Global Native

; (Map marker is handled via the CampMapMarker property + MoveTo/Enable/Disable.
;  The runtime ExtraMapMarker attachment route requires SKSE address-library
;  lookups that CommonLib-NG doesn't expose by default — not worth the depth
;  for a one-marker feature when a CK-placed marker MoveTo'd around works.)

; Returns the per-camp XMarkerHeading at the fire position. Use this as the
; target of an AI Travel package (or pass to other plugins) to route NPCs to
; the camp. Returns None when no camp is active.
;
; Companion ModEvents fired by the native side:
;   SeversHearth_CampEstablished  (sender: marker ref)  - on Establish
;   SeversHearth_CampBroken       (sender: marker ref)  - on Break (sender
;     is valid for the listener's first frame, then despawned)
ObjectReference Function Native_Camp_GetCenterMarker() Global Native

; Sets BGSLocation::worldLocMarker on a runtime Location so IntelEngine
; (and any other location-aware plugin) can resolve "the camp" to the
; marker. Returns false if the cast fails or args are None.
Bool Function Native_Camp_BindLocationToMarker(Form locForm, ObjectReference markerRef) Global Native

; Clears worldLocMarker so callers don't resolve a stale/deleted ref
; between camps.
Function Native_Camp_UnbindLocation(Form locForm) Global Native

; Survival-tick bindings — CampSurvivalTick.h worker thread.
Function Native_Camp_ForceTick() Global Native
Function Native_Camp_SetTickIntervalSeconds(Int seconds) Global Native
Function Native_Camp_SetTickEnabled(Bool enabled) Global Native

; CampPlacement.h — spawn pipeline. Caller must Native_Camp_EstablishAtPlayer
; first so AddPlacedRef registers each ref. fireBlockRadius/treeBlockRadius
; are kept in the signature for binding ABI stability but are unused by
; the spawn (only by the clearance peek below).
Int Function Native_Camp_SpawnStructures(Float angleZ, Float fireBlockRadius, Float treeBlockRadius, Float tentSideOffset) Global Native

; Pre-flight clearance peek — no side effects. Returns false if a tree
; blocks the planned fire or tent positions. Cheaper than running the
; spawn-and-rollback path.
Bool Function Native_Camp_IsClearForCamp(Float angleZ, Float fireBlockRadius, Float treeBlockRadius, Float tentSideOffset) Global Native

; Returns every IsPlayerTeammate() actor within `radius` of the player.
; Excludes the player and dead/disabled refs. Used by the sandbox
; fan-out to populate every nearby follower regardless of which follower
; framework (NFF / AFT / UFO / vanilla) manages them.
Actor[] Function Native_Camp_FindNearbyTeammates(Float radius) Global Native
