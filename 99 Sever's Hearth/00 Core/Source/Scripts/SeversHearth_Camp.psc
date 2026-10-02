ScriptName SeversHearth_Camp extends Quest
{Sever's Hearth - core camp lifecycle. Member functions called by SkyrimNet actions.}

; Camp occupants are parked with CampSandboxPackage (a Sandbox package in
; SeversHearth.esp with no conditions: this script owns its lifetime), applied
; through PapyrusUtil's ActorUtil package overrides. Occupants are kept in the
; tracking arrays below so a break can remove every override, across a
; save/reload too.

Package Property CampSandboxPackage Auto
{The camp sandbox package. None = no sandboxing.}

Bool Property SandboxOnEstablish = True Auto
{Sandbox the establishing follower and nearby teammates when a camp goes up.
 Set from SA's Settings page (SeverActions_MagelightCampSandboxPref); saved
 here. GoToCamp's arrival sandbox ignores it.}

; IntelEngine "the camp": this Location's worldLocMarker is pointed at the
; camp marker while a camp stands and cleared on break. None = no binding.
Location Property CampLocation Auto
{The camp's Location form. Bound to the camp marker so IntelEngine and other
 location-aware mods can find the camp by name.}

; Fast-travel map marker: one placed XMarker set up as a travelable map marker
; and Initially Disabled (a runtime ExtraMapMarker needs lookups CommonLib-NG
; does not expose). Marking MoveTo's it onto the camp and enables it;
; unmarking disables it. None = no map marker.
ObjectReference Property CampMapMarker Auto
{The placed camp map marker. Initially disabled; MoveTo'd to the camp on demand.}

; Sandboxed occupants, so a break can release each one. These MUST stay Auto
; Hidden properties: assigning `new Actor[N]` to a script-scope Actor[]
; variable failed at runtime ("Cannot create an array into a non-array
; variable").
Actor[] Property SandboxedActorTracking Auto Hidden
{Internal - the field camp's sandboxed actors (cap 16). Do not set in CK.}

Int Property SandboxedActorCount = 0 Auto Hidden
{Internal - current count in SandboxedActorTracking.}

Actor[] Property BaseSandboxedActorTracking Auto Hidden
{Internal - the base's sandboxed actors, kept apart from the field camp's so
 breaking one camp never releases the other's. Cap 24. Do not set in CK.}

Int Property BaseSandboxedActorCount = 0 Auto Hidden
{Internal - current count in BaseSandboxedActorTracking.}

; Per-tick survival deltas for each occupant (negative = the need drops). The
; tick interval is Native_Camp_SetTickIntervalSeconds (default 60 real seconds,
; ~20 game minutes at timescale 20).
Float Property CampRestoreHungerDelta  = -2.0 Auto Hidden
{Hunger change per camp tick. Default -2.0.}

Float Property CampRestoreFatigueDelta = -4.0 Auto Hidden
{Fatigue change per camp tick. Default -4.0.}

Float Property CampRestoreColdDelta    = -8.0 Auto Hidden
{Cold change per camp tick, the largest (the fire warms). Default -8.0.}

; Camp footprint.
Float Property TentSideOffset = 200.0 Auto Hidden
{Unused: the layout (CampPlacement.h kPieces, from Hearth/Native/tools/camp_eval.py)
 ignores it; it is passed through only to keep the native ABI.}

Float Property TreeBlockRadius = 70.0 Auto Hidden
{Margin added to each tent's canvas half-extents: a tree inside that grown,
 oriented, tent-scaled rectangle blocks the camp. Used by the clearance peek,
 the base's tier fit and the upgrade pre-check; Native_Base_Upgrade's own
 re-check uses 70.}

Float Property FireBlockRadius = 50.0 Auto Hidden
{A tree within this radius of the fire position blocks the camp
 (Native_Base_Upgrade's re-check uses 50).}

; Placement state, transient: the "postload" tick resets it (the native ghost
; refs do not survive a reload).
Int PlacementMode = 0                ; 0 idle, 1 field-camp ghost, 2 base ghost
Float PlacementRotateOffset = 0.0    ; Q/E rotation on top of facing (deg)
Int PlacementConfirmKey = 28         ; resolved Activate key, or Enter on collision
Float PlacementBannerCooldown = 0.0  ; seconds until the next banner reminder

; One upgrade at a time: the button, the LLM action and a second companion can
; all call UpgradeBase during its ~5 s of fades and waits, and a second call
; would pay the old tier's price for the next tier. Cleared by the postload tick.
Bool _UpgradeInProgress = False

Event OnInit()
    RegisterCampEvents()
EndEvent

; Load recovery: a Quest script gets no OnPlayerLoadGame, so the DLL fires
; SeversHearth_CampTick with strArg "postload" ~3 s after kPostLoadGame and
; re-fires it (at most 3 times, 20 s apart) until OnCampTickEvent acks with
; Native_Camp_AckPostLoad (R24). It rides the already-registered tick event, so
; old saves need no new registration.

Function RegisterCampEvents()
    {Idempotent (a re-registration replaces the old one).}
    RegisterForModEvent("SeversHearth_CampTick", "OnCampTickEvent")
    ; SA's Survival page buttons. Harmless without SA: nothing sends them.
    RegisterForModEvent("SeverActions_MagelightBreakCamp",       "OnPrismaBreakCamp")
    RegisterForModEvent("SeverActions_MagelightTravelToCamp",    "OnPrismaTravelToCamp")
    RegisterForModEvent("SeverActions_MagelightToggleCampMarker","OnPrismaToggleCampMarker")
    ; Placement: the Survival page buttons and SA's setup-camp hotkey.
    RegisterForModEvent("SeverActions_MagelightSetupCamp",       "OnPrismaSetupCamp")
    RegisterForModEvent("SeverActions_MagelightSetupSmallCamp",  "OnPrismaSetupSmallCamp")
    RegisterForModEvent("SeverActions_MagelightRepositionCamp",  "OnPrismaRepositionCamp")
    ; A player recruit / follow / wait / dismiss releases the actor from its camp
    ; or base sandbox.
    RegisterForModEvent("SeverActions_FollowerCalledByPlayer", "OnFollowerCalledByPlayer")
    ; Arrival of a GoToCamp / GoToBase journey parks the actor at the fire.
    RegisterForModEvent("SeverActions_TravelComplete", "OnTravelCompleteFromSA")
    ; Settings toggle for SandboxOnEstablish (SA sends, this script stores it).
    RegisterForModEvent("SeverActions_MagelightCampSandboxPref", "OnPrismaCampSandboxPref")
    ; The base's buttons and the tent-pattern setting.
    RegisterForModEvent("SeverActions_MagelightSetupBase",        "OnPrismaSetupBase")
    RegisterForModEvent("SeverActions_MagelightRepositionBase",   "OnPrismaRepositionBase")
    RegisterForModEvent("SeverActions_MagelightBreakBase",        "OnPrismaBreakBase")
    RegisterForModEvent("SeverActions_MagelightPromoteToBase",    "OnPrismaPromoteToBase")
    RegisterForModEvent("SeverActions_MagelightTravelToBase",     "OnPrismaTravelToBase")
    RegisterForModEvent("SeverActions_MagelightUpgradeBase",      "OnPrismaUpgradeBase")
    RegisterForModEvent("SeverActions_MagelightCampFactionSkin",  "OnPrismaCampFactionSkin")
    If _SeverActionsInstalled()
        SeverActionsNativeExt2.Magelight_SetCampFactionSkin(Native_Camp_GetFactionSkin())
    EndIf
    ; Mirror the saved preference so SA's Settings toggle shows it after a load.
    SeverActionsNativeExt.Magelight_SetCampSandboxPref(SandboxOnEstablish)
    Debug.Trace("[SeversHearth] Registered camp tick + menu button + follower lifecycle ModEvents")
EndFunction

Event OnPrismaCampSandboxPref(string eventName, string strArg, float numArg, Form sender)
    {SeverActions Settings page toggled sandbox-on-establish.}
    SandboxOnEstablish = (strArg == "true")
    SeverActionsNativeExt.Magelight_SetCampSandboxPref(SandboxOnEstablish)
    Debug.Trace("[SeversHearth] SandboxOnEstablish = " + SandboxOnEstablish)
EndEvent

Event OnFollowerCalledByPlayer(string eventName, string strArg, float numArg, Form sender)
    {SeverActions sends this on a player recruit / follow / wait / dismiss
     (strArg = the verb). Releases the actor from the camp or base sandbox.}
    Actor a = sender as Actor
    If !a
        Return
    EndIf
    If _IsAlreadySandboxed(a)
        Debug.Trace("[SeversHearth] OnFollowerCalledByPlayer: releasing " + a.GetDisplayName() + " (verb=" + strArg + ")")
        _ReleaseFromCampSandbox(a)
    ElseIf _IsBaseSandboxed(a)
        Debug.Trace("[SeversHearth] OnFollowerCalledByPlayer: releasing " + a.GetDisplayName() + " from the base (verb=" + strArg + ")")
        _ReleaseFromBaseSandbox(a)
    ElseIf SkyrimNetApi.HasPackage(a, "CampSandbox")
        ; An override applied but missing from tracking (a save/load edge, a
        ; travel hand-off race). The SkyrimNet registration exists only where
        ; a camp sandbox was applied, so it is the detector.
        Debug.Trace("[SeversHearth] OnFollowerCalledByPlayer: releasing ORPHANED camp sandbox on " + a.GetDisplayName() + " (verb=" + strArg + ")")
        If CampSandboxPackage
            ActorUtil.RemovePackageOverride(a, CampSandboxPackage)
        EndIf
        SkyrimNetApi.UnregisterPackage(a, "CampSandbox")
        If a.GetAV("WaitingForPlayer") == 1.0
            a.SetAV("WaitingForPlayer", 0)
        EndIf
        a.EvaluatePackage()
    EndIf
EndEvent

Event OnPrismaToggleCampMarker(string eventName, string strArg, float numArg, Form sender)
    {The Mark / Unmark on Map button. SA's action handler prefixes every strArg
     with "<actor>|", so this arrives as "0|on" or "0|off"; anything but "off"
     marks.}
    Debug.Trace("[SeversHearth] OnPrismaToggleCampMarker fired: strArg='" + strArg + "'")
    If !Native_Camp_IsActive()
        Debug.Trace("[SeversHearth] OnPrismaToggleCampMarker: no active camp, ignoring")
        Return
    EndIf
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
    {Move CampMapMarker onto the camp, enable it and name it after the
     location. Does nothing without the property or a camp, or for a camp
     indoors (the world map cannot show an interior).}
    If Native_Camp_IsInterior()
        Debug.Notification("A camp made indoors can't be marked on the map.")
        Return
    EndIf
    If !CampMapMarker
        Debug.Trace("[SeversHearth] MarkCampOnMap: CampMapMarker property unfilled - see script docs")
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
    {Hide CampMapMarker from the world map (disabled, kept for the next mark).}
    If !CampMapMarker
        Return
    EndIf
    CampMapMarker.Disable()
    StorageUtil.SetIntValue(self, "SeversHearth_CampOnMap", 0)
    _PushCampMarkedToPrisma(False)
    Debug.Notification("Camp removed from map.")
EndFunction

Function _PushCampMarkedToPrisma(Bool marked)
    {Push the marker state to SA's Survival page (the Mark / Unmark label).}
    If !_SeverActionsInstalled()
        Return
    EndIf
    SeverActionsNativeExt.Magelight_SetCampMarked(marked)
EndFunction

Event OnTravelCompleteFromSA(string eventName, string strArg, float numArg, Form sender)
    {A journey Hearth started to a camp. strArg is "<tag>|<status>". "waiting" (the
     arrival wait began, in the journey's CampSandboxPackage): WaitingForPlayer so the
     engine does not pull them to the player on a cell change. A journey that ends at
     the fire ("arrived", "waitdone" = the player reached them, "waittimeout") leaves
     them an occupant under Hearth's own sandbox until told to follow. One that ends away
     from it (cancelled, stay ended, gave up) drops them from the lists. Every other
     journey of a listed actor is ignored.}
    Actor a = sender as Actor
    If !a || (!_IsAlreadySandboxed(a) && !_IsBaseSandboxed(a))
        Return
    EndIf
    If StorageUtil.GetIntValue(a, JOURNEY_TRACKED_KEY, 0) != 1
        Return
    EndIf
    ; numArg is the journey's handle: another journey's event (an older one of this actor's)
    ; is not ours.
    Int mine = StorageUtil.GetIntValue(a, JOURNEY_HANDLE_KEY, 0)
    If mine > 0 && (numArg as Int) != mine
        Return
    EndIf
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf
    String status = StringUtil.Substring(strArg, pipePos + 1, 0)
    If status == "waiting"
        a.SetAV("WaitingForPlayer", 1)
        Debug.Trace("[SeversHearth] OnTravelComplete: " + a.GetDisplayName() + " waiting at camp (wait=1)")
        Return
    EndIf
    ; Our journey ended at the fire with no newer one under way: an occupant. Anything else
    ; (ended away, or replaced by another journey - say a trip elsewhere) drops them.
    Bool atFire = status == "arrived" || status == "waitdone" || status == "waittimeout"
    If atFire && SeverActionsNativeExt2.Travel_GetPhaseByActor(a) == 0
        _ParkAfterJourney(a)
    Else
        a.SetAV("WaitingForPlayer", 0)   ; undo Hearth's park from the arrival wait
        _ForgetTracked(a)
        Debug.Trace("[SeversHearth] OnTravelComplete: " + a.GetDisplayName() + " " + status + " - no longer at camp")
    EndIf
EndEvent

Function _ParkAfterJourney(Actor a)
    {The journey ended at the fire: Hearth's own sandbox holds them as an occupant. The
     travel core's teardown answers the same event and removes the journey's
     CampSandboxPackage override (the same form), so park only once it is done.}
    Int tries = 0
    While SeverActionsNativeExt2.Native_GetTravelState(a) != "" && tries < 40
        Utility.Wait(0.5)
        tries += 1
    EndWhile
    If SeverActionsNativeExt2.Native_GetTravelState(a) != ""
        ; The teardown has not run after 20 s (a VM backlog): park anyway, and say so, since a
        ; late teardown would take this park's package off again.
        Debug.Trace("[SeversHearth] _ParkAfterJourney: " + a.GetDisplayName() + " - travel teardown still pending, parking anyway")
    EndIf
    ; Released, re-sent or dropped while the teardown ran: not ours to park.
    If StorageUtil.GetIntValue(a, JOURNEY_TRACKED_KEY, 0) != 1 || (!_IsAlreadySandboxed(a) && !_IsBaseSandboxed(a))
        Return
    EndIf
    If SeverActionsNativeExt2.Travel_GetPhaseByActor(a) != 0
        Return
    EndIf
    If CampSandboxPackage
        ActorUtil.AddPackageOverride(a, CampSandboxPackage, 100, 0)
    EndIf
    SkyrimNetApi.RegisterPackage(a, "CampSandbox", 100, 0, false)
    a.SetAV("WaitingForPlayer", 1)
    a.EvaluatePackage()
    _SetJourneyTracked(a, False)   ; Hearth's own sandbox now
    Debug.Trace("[SeversHearth] OnTravelComplete: " + a.GetDisplayName() + " parked at camp as an occupant")
EndFunction

Event OnPrismaBreakCamp(string eventName, string strArg, float numArg, Form sender)
    {The Break Camp button: BreakCamp as the player.}
    If !Native_Camp_IsActive()
        Return
    EndIf
    Actor PlayerRef = Game.GetPlayer()
    If PlayerRef
        BreakCamp(PlayerRef)
    EndIf
EndEvent

Event OnPrismaTravelToCamp(string eventName, string strArg, float numArg, Form sender)
    {The Travel to Camp button, followers only: "0|all" sends every teammate
     near the player, "0|<hex formID>" one follower. The "<actor>|" prefix
     (see OnPrismaToggleCampMarker) must be stripped before either test.}
    If !Native_Camp_IsActive()
        Return
    EndIf
    If Native_Camp_IsInterior()
        Debug.Notification("The camp is indoors - companions return to it with you.")
        Return
    EndIf
    String payload = strArg
    Int payloadPipe = StringUtil.Find(strArg, "|")
    If payloadPipe >= 0
        payload = StringUtil.Substring(strArg, payloadPipe + 1, 0)
    EndIf
    If payload == "all"
        Actor PlayerRef = Game.GetPlayer()
        If !PlayerRef
            Return
        EndIf
        ; The fan-out's teammate scan (every follower framework), 1000u.
        Actor[] teammates = Native_Camp_FindNearbyTeammates(1000.0)
        If !teammates
            Return
        EndIf
        Int i = 0
        Int dispatched = 0
        While i < teammates.Length
            Actor candidate = teammates[i]
            If candidate && candidate != PlayerRef && !_IsParkedAtCamp(candidate)
                GoToCamp(candidate, 1)
                dispatched += 1
            EndIf
            i += 1
        EndWhile
        Debug.Notification("Sent " + dispatched + " follower" + PluralS(dispatched) + " to camp.")
    Else
        ; One follower: the sender wrote the formID with "%X"; HexToInt reverses it.
        Int formID = SeverActionsNative.HexToInt(payload)
        If formID == 0
            Debug.Trace("[SeversHearth] OnPrismaTravelToCamp: invalid payload '" + strArg + "'")
            Return
        EndIf
        Form f = Game.GetFormEx(formID)
        Actor target = f as Actor
        If target
            GoToCamp(target, 1)
        EndIf
    EndIf
EndEvent

; SkyrimNet action entry points. They must stay MEMBER functions: SkyrimNet
; calls instance.Function(args) and never reaches a Global.

Function EstablishCamp(Actor akActor)
    If Native_Camp_IsActive()
        Debug.Notification("You already have an active camp.")
        Return
    EndIf

    ; Clear sandbox state a prior camp left behind.
    _ClearCampSandbox()

    Actor PlayerRef = Game.GetPlayer()
    Float angleZ = PlayerRef.GetAngleZ()

    ; Outdoors only. This must come first: the clearance peek passes in interiors.
    Cell playerCell = PlayerRef.GetParentCell()
    If playerCell && playerCell.IsInterior()
        If akActor != None && akActor != PlayerRef
            String indoorNarration = akActor.GetDisplayName() + " glances around the enclosed space, " + \
                                     "then shakes their head at " + PlayerRef.GetDisplayName() + \
                                     ": there is no pitching the camp's tents in here. The party needs open ground outside, " + \
                                     "unless " + PlayerRef.GetDisplayName() + " lays out a small camp of bedrolls by the fire."
            SkyrimNetApi.DirectNarration(indoorNarration, akActor, PlayerRef)
        Else
            Debug.Notification("You can't pitch a full camp indoors - make a small camp, or find open ground outside.")
        EndIf
        Return
    EndIf

    ; Tree clearance before anything is established, so a refusal has nothing
    ; to roll back.
    If !Native_Camp_IsClearForCamp(angleZ, FireBlockRadius, TreeBlockRadius, TentSideOffset)
        If akActor != None && akActor != PlayerRef
            String narration = akActor.GetDisplayName() + " looks around at the trees pressing in, " + \
                               "then shakes their head at " + PlayerRef.GetDisplayName() + \
                               ": the ground here is too crowded for the tents, and the party had best find more open ground."
            SkyrimNetApi.DirectNarration(narration, akActor, PlayerRef)
        Else
            Debug.Notification("Too crowded here - find a more open spot.")
        EndIf
        Return
    EndIf

    ; The first camp IS the base; while a base stands this pitches the field camp.
    If !Native_Base_IsActive()
        _EstablishBaseFlow(akActor, PlayerRef)
        Return
    EndIf
    _EstablishCampFlow(akActor, PlayerRef)
EndFunction

; GoToCamp / GoToBase travel through a STATIC call to
; SeverActions_TravelCore.BeginJourney (D7): the travel core is in hearth's
; install closure and the travel module is not, so never name
; SeverActions_Travel here. The core runs the journey and its arrival wait and
; applies CampSandboxPackage on arrival. The marker is read live, since it
; moves with each camp.

Function _DisengageForTravel(Actor akNPC, String asTag)
    {Free the traveler from what would fight the travel package: the furniture use
     package (FurnitureLib's Activate package, seated or on the way; in hearth's
     closure through travelcore) and an in-flight crafting session.}
    If SeverActions_FurnitureLib.CanStop(akNPC)
        Debug.Trace("[SeversHearth] " + asTag + ": standing " + akNPC.GetDisplayName() + " up from furniture before travel")
        SeverActions_FurnitureLib.Stop(akNPC)
    EndIf
    If SeverActionsNativeExt2.Craft_CancelByActor(akNPC) > 0
        Debug.Trace("[SeversHearth] " + asTag + ": cancelled in-flight crafting for " + akNPC.GetDisplayName() + " before travel")
    EndIf
EndFunction

Function GoToCamp(Actor akNPC, Int speed = 1)
    {SkyrimNet action: send akNPC to the camp. Speed 0 walk, 1 jog, 2 run.}
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
    ; An indoor camp is not a journey's end: a companion comes back to it with the player.
    If Native_Camp_IsInterior()
        Actor player = Game.GetPlayer()
        If akNPC != player
            SkyrimNetApi.DirectNarration(akNPC.GetDisplayName() + " stays with " + player.GetDisplayName() + \
                                         ": the camp is made inside, and there is no going back to it alone.", akNPC, player)
        EndIf
        Debug.Notification("The camp is indoors - companions return to it with you.")
        Return
    EndIf

    If !_SeverActionsInstalled()
        Debug.Notification("Travel requires SeverActions to be installed.")
        Debug.Trace("[SeversHearth] GoToCamp: SeverActions absent")
        Return
    EndIf

    ; Already an occupant here: no journey (its teardown would take Hearth's package off).
    If _IsParkedAtCamp(akNPC)
        Debug.Trace("[SeversHearth] GoToCamp: " + akNPC.GetDisplayName() + " is already at the camp")
        Return
    EndIf
    ; CampSandboxPackage replaces the core's default arrival sandbox (which
    ; leaves them standing on the marker); the core applies it when the wait
    ; begins and removes it when the journey ends, after which Hearth parks them
    ; under its own (OnTravelCompleteFromSA). Default 48 h wait, still following,
    ; and a meeting (the player is expected at the fire).
    _DisengageForTravel(akNPC, "GoToCamp")
    Bool started = SeverActions_TravelCore.BeginJourney(akNPC, marker, "the camp", 0.0, false, speed, true, CampSandboxPackage)
    ; Track now (the package comes on arrival) so a break releases them too. Not a refused
    ; journey: the actor never left, and a listed actor with no journey reads as parked.
    If started
        _TrackForCleanup(akNPC)
        _SetJourneyTracked(akNPC, True)
    EndIf
    Debug.Trace("[SeversHearth] GoToCamp: dispatched " + akNPC.GetDisplayName() + " (speed=" + speed + ", started=" + started + ")")
EndFunction

Function BreakCamp(Actor akActor)
    If !Native_Camp_IsActive()
        Debug.Notification("No active camp to break down.")
        Return
    EndIf
    Actor PlayerRef = Game.GetPlayer()
    _BreakCampFlow(akActor, PlayerRef)
EndFunction

; Player-driven placement: a ghost of the whole camp follows the player's view;
; Q/E rotate, Enter/Activate confirms, Tab cancels. Confirm deletes the ghost
; and spawns the real camp where it stood (a moved static's collision does not
; follow it). Reposition first tears the camp down, keeping the stash chest.
; A 0.1 s update tick re-projects the ghost; DisablePlayerControls blocks
; menus / activate / fighting so the keys do not double-fire, leaving movement
; and looking on for aiming.

Event OnPrismaSetupCamp(string eventName, string strArg, float numArg, Form sender)
    EnterPlacementMode(False)
EndEvent

Event OnPrismaSetupSmallCamp(string eventName, string strArg, float numArg, Form sender)
    EnterPlacementMode(False, True)
EndEvent

Event OnPrismaRepositionCamp(string eventName, string strArg, float numArg, Form sender)
    EnterPlacementMode(True)
EndEvent

Function EnterPlacementMode(Bool reposition, Bool smallCamp = False)
    {Begin positioning the camp ghost. reposition=true tears the current camp
     down first (chest preserved) and keeps its kit; false requires no camp
     yet. A fresh full camp while no base stands is placed as the base. A small
     camp (smallCamp) is always a field camp, and the only one the player can
     make indoors.}
    If PlacementMode != 0
        Return                       ; already positioning
    EndIf
    If reposition
        smallCamp = Native_Camp_IsSmall()
    EndIf
    If !reposition && !smallCamp && !Native_Base_IsActive()
        EnterBasePlacementMode(False)
        Return
    EndIf
    Actor PlayerRef = Game.GetPlayer()
    If !PlayerRef
        Return
    EndIf

    ; A full camp outdoors only; a small one anywhere.
    Cell playerCell = PlayerRef.GetParentCell()
    If !smallCamp && playerCell && playerCell.IsInterior()
        Debug.Notification("You can't pitch a full camp indoors - make a small camp, or find open ground outside.")
        Return
    EndIf

    If reposition
        If !Native_Camp_IsActive()
            Debug.Notification("No camp to reposition. Set one up first.")
            Return
        EndIf
        _QuietBreakForReposition()
    ElseIf Native_Camp_IsActive()
        Debug.Notification("You already have a camp - break or reposition it.")
        Return
    EndIf

    RegisterCampEvents()             ; refresh bindings on older saves

    Bool started
    If smallCamp
        started = Native_Camp_StartSmallPreview()
    Else
        started = Native_Camp_StartPreview(TentSideOffset)
    EndIf
    If !started
        Debug.Notification("Can't start camp placement here.")
        Return
    EndIf

    PlacementMode = 1
    PlacementRotateOffset = 0.0
    PlacementBannerCooldown = 0.0
    _BeginPlacementInput()
    _ShowPlacementBanner()
    RegisterForSingleUpdate(0.1)
EndFunction

Event OnUpdate()
    If PlacementMode == 0
        Return
    EndIf
    Native_Camp_UpdatePreview(PlacementRotateOffset)
    PlacementBannerCooldown -= 0.1
    If PlacementBannerCooldown <= 0.0
        _ShowPlacementBanner()
    EndIf
    RegisterForSingleUpdate(0.1)
EndEvent

Event OnKeyDown(Int keyCode)
    If PlacementMode == 0
        Return
    EndIf
    If keyCode == 16                 ; Q — rotate left
        PlacementRotateOffset -= 15.0
        Native_Camp_UpdatePreview(PlacementRotateOffset)
    ElseIf keyCode == 18             ; E — rotate right
        PlacementRotateOffset += 15.0
        Native_Camp_UpdatePreview(PlacementRotateOffset)
    ElseIf keyCode == 15             ; Tab — cancel
        CancelPlacement()
    ElseIf keyCode == 28 || keyCode == PlacementConfirmKey   ; Enter / Activate — confirm
        ConfirmPlacement()
    EndIf
EndEvent

Function ConfirmPlacement()
    ; The ghost was started against its slot (field or base), so the commit
    ; lands there; only the Papyrus finish differs.
    Bool forBase = (PlacementMode == 2)
    Int placed = Native_Camp_CommitPreview()
    _EndPlacementMode()
    If placed > 0
        If forBase
            _FinishBaseCommit(Game.GetPlayer())
            Debug.Notification("Base established (" + placed + " structure" + PluralS(placed) + ").")
        Else
            _FinishCommit(Game.GetPlayer())
            If Native_Camp_IsSmall()
                Debug.Notification("Small camp made (" + placed + " piece" + PluralS(placed) + ").")
            Else
                Debug.Notification("Camp established (" + placed + " structure" + PluralS(placed) + ").")
            EndIf
        EndIf
    Else
        ; 0: the native established the slot, then spawned nothing - break it, or it stays
        ; Building and blocks the next camp. -1: nothing was committed.
        If placed == 0
            If forBase
                Native_Base_DespawnPlacedRefs()
                Native_Base_BreakKeepTier()   ; a failed reposition keeps its tier
            Else
                Native_Camp_DespawnPlacedRefs()
                Native_Camp_Break()
                If Native_Base_IsActive()
                    _PinBaseAsCamp()
                EndIf
            EndIf
        EndIf
        If forBase
            Debug.Notification("Base placement failed.")
        Else
            Debug.Notification("Camp placement failed.")
        EndIf
    EndIf
EndFunction

Function CancelPlacement()
    Bool forBase = (PlacementMode == 2)
    Native_Camp_CancelPreview()
    _EndPlacementMode()
    If forBase
        Debug.Notification("Base placement cancelled.")
    Else
        Debug.Notification("Camp placement cancelled.")
    EndIf
EndFunction

; The tail of _EstablishCampFlow, without the fade and the speaker's sandbox.
Function _FinishCommit(Actor PlayerRef)
    If SandboxOnEstablish
        _FanOutSandboxToTeammates(PlayerRef, 1000.0)
    EndIf
    Native_Camp_SetPhase(2)          ; CampPhase::Active
    _PinCampRestStop()
    Native_Camp_ForceTick()
    ; An indoor camp is neither on the map nor a travel destination (GoToCamp refuses it).
    If !Native_Camp_IsInterior()
        MarkCampOnMap()
        _BindCampLocationToMarker()
    EndIf
    Native_Camp_KickThreatScan()
EndFunction

; Reposition's silent teardown (no fade or sound) so the ghost replaces the
; camp at once. The native Break keeps the stash chest.
Function _QuietBreakForReposition()
    Native_Camp_SetPhase(3)          ; CampPhase::Breaking - the tick skips the field half
    _ClearCampSandbox()
    UnmarkCampOnMap()
    _UnbindCampLocation()
    Native_Camp_DespawnPlacedRefs()
    Native_Camp_Break()
    _ClearCampRestStop()
    ; After the clear, or it would wipe the base's label again. The base carries the surfaces
    ; until a new field camp commits (a Tab cancel or a failed preview/commit leaves it so).
    If Native_Base_IsActive()
        _PinBaseAsCamp()
    EndIf
EndFunction

Function _BeginPlacementInput()
    ; Activate also confirms, unless it collides with Q/E/Tab (the default E
    ; does); then only Enter does.
    PlacementConfirmKey = Input.GetMappedKey("Activate")
    If PlacementConfirmKey == 16 || PlacementConfirmKey == 18 || PlacementConfirmKey == 15 || PlacementConfirmKey <= 0
        PlacementConfirmKey = 28
    EndIf
    RegisterForKey(16)               ; Q — rotate left
    RegisterForKey(18)               ; E — rotate right
    RegisterForKey(15)               ; Tab — cancel
    RegisterForKey(28)               ; Enter — confirm
    RegisterForKey(PlacementConfirmKey)
    ; Disables fighting, menu, activate and journal tabs; movement, camera,
    ; looking and sneaking stay on.
    Game.DisablePlayerControls(False, True, False, False, False, True, True, True)
EndFunction

Function _EndPlacementInput()
    UnregisterForKey(16)
    UnregisterForKey(18)
    UnregisterForKey(15)
    UnregisterForKey(28)
    UnregisterForKey(PlacementConfirmKey)
    Game.EnablePlayerControls()
EndFunction

Function _EndPlacementMode()
    PlacementMode = 0
    PlacementRotateOffset = 0.0
    _EndPlacementInput()
    UnregisterForUpdate()
EndFunction

Function _ShowPlacementBanner()
    Debug.Notification("Camp placement - aim with your view, Q/E rotate, Enter/Activate confirms, Tab cancels")
    PlacementBannerCooldown = 3.0
EndFunction

; Establish / break flows. A follower-initiated ("cinematic") flow runs behind
; a fade with narration; a player-initiated one does not.
; Phases: Idle -> Building -> Active (establish), Active -> Breaking -> Idle
; (break). The native survival tick fires while the field camp or the base is
; Active (CampStore::IsTickable).

Function _EstablishCampFlow(Actor follower, Actor PlayerRef)
    ; Re-register every establish, so a save made before a handler existed
    ; picks it up.
    RegisterCampEvents()

    Float angleZ = PlayerRef.GetAngleZ()
    Bool cinematic = (follower != None && follower != PlayerRef)

    If cinematic
        _StartFadeToBlack()
        Utility.Wait(1.0)            ; -> t≈1.0s
    EndIf

    ; Establish first so the spawn can register each ref; the native sets
    ; Building.
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

    ; Sandbox while the screen is dark, so the AI churn is not seen.
    If SandboxOnEstablish
        If cinematic
            _ApplyCampSandbox(follower)
        EndIf
        _FanOutSandboxToTeammates(PlayerRef, 1000.0)
    EndIf

    Native_Camp_SetPhase(2)  ; CampPhase::Active - the survival tick may fire

    If cinematic
        Utility.Wait(1.5)            ; -> t≈5.5s
        _EndFadeToBlack()
        Utility.Wait(1.5)            ; -> t≈7.0s (screen fully clear)
    EndIf

    _PinCampRestStop()
    Native_Camp_ForceTick()

    ; Marked by default; the player can unmark it.
    MarkCampOnMap()

    ; So IntelEngine's "go to the camp" resolves.
    _BindCampLocationToMarker()

    If cinematic
        String narration = follower.GetDisplayName() + " clears a flat patch of ground near " + PlayerRef.GetDisplayName() + ", " + \
                           "raises the tents about the fire, drives in stakes, kindles it, and lays out bedrolls. " + \
                           "A cooking spit is set over the flames and the camp settles into a steady rhythm."
        SkyrimNetApi.DirectNarration(narration, follower, PlayerRef)
    EndIf

    Debug.Notification("Camp established (" + placed + " structure" + PluralS(placed) + ").")
EndFunction

; Breaking always fades: without it the structures vanish all at once, which
; reads as a script crash. The follower path adds narration so the LLM can
; refer to the teardown.

Function _BreakCampFlow(Actor follower, Actor PlayerRef)
    Bool cinematic = (follower != None && follower != PlayerRef)

    ; Breaking first, so no survival tick lands during the fade, and the
    ; sandbox comes off before the refs vanish (no AI aimed at a deleted bench).
    Native_Camp_SetPhase(3)  ; CampPhase::Breaking
    _ClearCampRestStop()
    _ClearCampSandbox()
    UnmarkCampOnMap()
    ; Unbind before the native Break despawns the marker and clears its id.
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
    If Native_Base_IsActive()
        _PinBaseAsCamp()             ; the base is the camp again
    EndIf

    _EndFadeToBlack()

    If cinematic
        Utility.Wait(1.5)        ; -> t≈7.0s (screen fully clear)
        String narration = follower.GetDisplayName() + " dismantles the tent, scatters and snuffs the embers, " + \
                           "rolls up the bedroll, packs the gear, and leaves only flattened grass " + \
                           "where the camp had stood."
        SkyrimNetApi.DirectNarration(narration, follower, PlayerRef)
    EndIf

    Debug.Notification("Camp broken down.")
EndFunction

; The BASE, the company's persistent command camp
; (ai_docs/DESIGN_HearthCommandCamp.md). The field camp above is tonight's
; bivouac; the base is a second, persistent slot followers can be sent to and
; live at. The first camp pitched IS the base; one pitched while a base stands
; is the field camp. The base has tiers 1-3 (see UpgradeBase). The one stash
; chest belongs to the base whenever one stands (a native rule).

Function EstablishBase(Actor akActor)
    {SkyrimNet action entry point. Pitch the company's base here.}
    If Native_Base_IsActive()
        Debug.Notification("You already have a base - reposition or break it first.")
        Return
    EndIf
    Actor PlayerRef = Game.GetPlayer()
    Float angleZ = PlayerRef.GetAngleZ()
    Cell playerCell = PlayerRef.GetParentCell()
    If playerCell && playerCell.IsInterior()
        If akActor != None && akActor != PlayerRef
            String indoorNarration = akActor.GetDisplayName() + " glances around the enclosed space, " + \
                                     "then shakes their head at " + PlayerRef.GetDisplayName() + \
                                     ": a base needs open ground, and there is no raising tents in here."
            SkyrimNetApi.DirectNarration(indoorNarration, akActor, PlayerRef)
        Else
            Debug.Notification("You can't raise a base indoors - find open ground outside.")
        EndIf
        Return
    EndIf
    If !Native_Camp_IsClearForCamp(angleZ, FireBlockRadius, TreeBlockRadius, TentSideOffset)
        If akActor != None && akActor != PlayerRef
            String narration = akActor.GetDisplayName() + " looks around at the trees pressing in, " + \
                               "then shakes their head at " + PlayerRef.GetDisplayName() + \
                               ": a base needs more room than this, and the party had best find open ground."
            SkyrimNetApi.DirectNarration(narration, akActor, PlayerRef)
        Else
            Debug.Notification("Too crowded here - find a more open spot for the base.")
        EndIf
        Return
    EndIf
    _EstablishBaseFlow(akActor, PlayerRef)
EndFunction

Function BreakBase(Actor akActor)
    {SkyrimNet action entry point. Strike the base. The chest's contents are
     kept (the chest is disabled, never deleted).}
    If !Native_Base_IsActive()
        Debug.Notification("There is no base to break down.")
        Return
    EndIf
    Actor PlayerRef = Game.GetPlayer()
    _BreakBaseFlow(akActor, PlayerRef)
EndFunction

Function PromoteCampToBase(Actor akActor)
    {SkyrimNet action entry point. The standing field camp becomes the base in
     place (the native moves refs, marker and position; the field slot
     empties). No fade: nothing is rebuilt.}
    If !Native_Camp_IsActive()
        Debug.Notification("There is no camp to promote - pitch one first.")
        Return
    EndIf
    If Native_Base_IsActive()
        Debug.Notification("You already have a base. Break it before naming a new one.")
        Return
    EndIf
    Actor PlayerRef = Game.GetPlayer()
    If Native_Camp_IsSmall()
        If akActor != None && akActor != PlayerRef
            SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " looks over the bedrolls round the fire and shakes their head at " + \
                                         PlayerRef.GetDisplayName() + ": a night's stop this small is no base. A full camp is needed for that.", \
                                         akActor, PlayerRef)
        EndIf
        Debug.Notification("A small camp can't become the base - pitch a full camp for that.")
        Return
    EndIf
    ; The native first: a promote that loses a race (a double click) returns before touching
    ; the winner's marker and binding.
    If !Native_Camp_PromoteFieldToBase()
        Debug.Notification("Could not promote the camp.")
        Return
    EndIf
    ; The field camp's bookkeeping stands down, and its occupants move to the base's list,
    ; so a later BreakCamp cannot release them.
    _ClearCampRestStop()
    UnmarkCampOnMap()
    _UnbindCampLocation()
    _MoveFieldSandboxToBase()
    _PinBaseStatus()
    _PinBaseAsCamp()
    If akActor != None && akActor != PlayerRef
        String narration = akActor.GetDisplayName() + " walks the camp's edge with " + PlayerRef.GetDisplayName() + ", " + \
                           "marking where the tents will stay. This is not a night's stop any more - " + \
                           "it is where the company lives now."
        SkyrimNetApi.DirectNarration(narration, akActor, PlayerRef)
    EndIf
    Debug.Notification("The camp is now your base.")
EndFunction

Function GoToBase(Actor akNPC, Int speed = 1)
    {SkyrimNet action: GoToCamp aimed at the base. Speed 0 walk, 1 jog, 2 run.}
    If !akNPC
        Return
    EndIf
    If !Native_Base_IsActive()
        Debug.Notification("There is no base to travel to.")
        Return
    EndIf
    ObjectReference marker = Native_Base_GetCenterMarker()
    If !marker
        Debug.Trace("[SeversHearth] GoToBase: marker missing despite active base")
        Return
    EndIf
    If !_SeverActionsInstalled()
        Debug.Notification("Travel requires SeverActions to be installed.")
        Return
    EndIf
    ; Already an occupant here: no journey (its teardown would take Hearth's package off).
    If _IsParkedAtBase(akNPC)
        Debug.Trace("[SeversHearth] GoToBase: " + akNPC.GetDisplayName() + " is already at the base")
        Return
    EndIf
    ; A full base refuses before the journey: arriving untracked, no break would release them.
    If !_IsBaseSandboxed(akNPC) && !_BaseHasRoom()
        Debug.Notification("The base has no room for anyone else.")
        Return
    EndIf
    ; The same journey as GoToCamp (see there).
    _DisengageForTravel(akNPC, "GoToBase")
    Bool started = SeverActions_TravelCore.BeginJourney(akNPC, marker, "the base", 0.0, false, speed, true, CampSandboxPackage)
    If started   ; not a refused journey (see GoToCamp)
        _TrackForBaseCleanup(akNPC)
        _SetJourneyTracked(akNPC, True)
    EndIf
    Debug.Trace("[SeversHearth] GoToBase: dispatched " + akNPC.GetDisplayName() + " (speed=" + speed + ", started=" + started + ")")
EndFunction

; ── The Base card's buttons (SA's Survival page) ─────────────────────────

Event OnPrismaSetupBase(string eventName, string strArg, float numArg, Form sender)
    EnterBasePlacementMode(False)
EndEvent

Event OnPrismaRepositionBase(string eventName, string strArg, float numArg, Form sender)
    EnterBasePlacementMode(True)
EndEvent

Event OnPrismaBreakBase(string eventName, string strArg, float numArg, Form sender)
    If !Native_Base_IsActive()
        Return
    EndIf
    Actor PlayerRef = Game.GetPlayer()
    If PlayerRef
        BreakBase(PlayerRef)
    EndIf
EndEvent

Event OnPrismaPromoteToBase(string eventName, string strArg, float numArg, Form sender)
    Actor PlayerRef = Game.GetPlayer()
    If PlayerRef
        PromoteCampToBase(PlayerRef)
    EndIf
EndEvent

Event OnPrismaTravelToBase(string eventName, string strArg, float numArg, Form sender)
    {Same payload shape as OnPrismaTravelToCamp: "0|all" or "0|<hex formID>".}
    If !Native_Base_IsActive()
        Return
    EndIf
    String payload = strArg
    Int payloadPipe = StringUtil.Find(strArg, "|")
    If payloadPipe >= 0
        payload = StringUtil.Substring(strArg, payloadPipe + 1, 0)
    EndIf
    If payload == "all"
        Actor PlayerRef = Game.GetPlayer()
        If !PlayerRef
            Return
        EndIf
        Actor[] teammates = Native_Camp_FindNearbyTeammates(1000.0)
        If !teammates
            Return
        EndIf
        Int i = 0
        Int dispatched = 0
        While i < teammates.Length
            Actor candidate = teammates[i]
            If candidate && candidate != PlayerRef && !_IsParkedAtBase(candidate)
                GoToBase(candidate, 1)
                dispatched += 1
            EndIf
            i += 1
        EndWhile
        Debug.Notification("Sent " + dispatched + " follower" + PluralS(dispatched) + " to the base.")
    Else
        Int formID = SeverActionsNative.HexToInt(payload)
        If formID == 0
            Return
        EndIf
        Actor target = Game.GetFormEx(formID) as Actor
        If target
            GoToBase(target, 1)
        EndIf
    EndIf
EndEvent


; ── Upgrading the base ───────────────────────────────────────────────────
; Tier 1 bivouac -> 2 encampment -> 3 command camp (DESIGN §9). Paid in
; materials, stash chest first, then the player's pack; the new tier's whole
; kit goes up in place behind a fade.

Int Function _UpgradeCostWood(Int newTier)
    If newTier >= 3
        Return 30
    EndIf
    Return 20
EndFunction

Int Function _UpgradeCostLeather(Int newTier)
    If newTier >= 3
        Return 15
    EndIf
    Return 10
EndFunction

Int Function _UpgradeCostIron(Int newTier)
    If newTier >= 3
        Return 10
    EndIf
    Return 5
EndFunction

String Function _TierName(Int tier)
    If tier >= 3
        Return "command camp"
    ElseIf tier == 2
        Return "encampment"
    EndIf
    Return "bivouac"
EndFunction

Int Function _CountMaterial(ObjectReference chest, Actor PlayerRef, Form item)
    Int n = 0
    If chest
        n += chest.GetItemCount(item)
    EndIf
    If PlayerRef
        n += PlayerRef.GetItemCount(item)
    EndIf
    Return n
EndFunction

Function _RefundMaterial(ObjectReference chest, Actor PlayerRef, Form item, Int count)
    {Give back a refused build's materials: to the stash chest, or the
     player's pack if the chest is gone.}
    If count <= 0 || !item
        Return
    EndIf
    If chest
        chest.AddItem(item, count, true)
    ElseIf PlayerRef
        PlayerRef.AddItem(item, count, true)
    EndIf
EndFunction

Function _TakeMaterial(ObjectReference chest, Actor PlayerRef, Form item, Int count)
    {Chest first, then the player's pack. Removing by FormID is safe here:
     firewood, leather and ingots are never player-enchanted pieces.}
    If count <= 0 || !item
        Return
    EndIf
    Int left = count
    If chest
        Int inChest = chest.GetItemCount(item)
        If inChest > 0
            Int take = inChest
            If take > left
                take = left
            EndIf
            chest.RemoveItem(item, take, true, None)
            left -= take
        EndIf
    EndIf
    If left > 0 && PlayerRef
        PlayerRef.RemoveItem(item, left, true, None)
    EndIf
EndFunction

Function UpgradeBase(Actor akActor)
    {SkyrimNet action entry point and the Base card's Upgrade button. One
     upgrade at a time: no external call sits between the check and the set,
     so they run under the script's lock.}
    If _UpgradeInProgress
        Debug.Notification("The company is already building the base out.")
        Return
    EndIf
    _UpgradeInProgress = True
    _UpgradeBaseImpl(akActor)
    _UpgradeInProgress = False
EndFunction

Function _UpgradeBaseImpl(Actor akActor)
    If !Native_Base_IsActive()
        Debug.Notification("There is no base to upgrade.")
        Return
    EndIf
    Int tier = Native_Base_GetTier()
    If tier >= 3
        Debug.Notification("The base is already a command camp.")
        Return
    EndIf
    Int newTier = tier + 1
    Actor PlayerRef = Game.GetPlayer()
    Bool cinematic = (akActor != None && akActor != PlayerRef)
    ; The player must be at the base: the rebuild spawns at the player, and
    ; the tree scan reads only cells loaded around them (and passes indoors).
    ; Distance alone passes in a city worldspace or an interior overlapping
    ; the base, hence IsPlayerAtBase; checked here so the refusal says why.
    Float dist = Native_Base_DistanceFromPlayer()
    If dist < 0.0 || dist > 2000.0 || !Native_Base_IsPlayerAtBase()
        If cinematic
            SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " shakes their head: the party would have to be at the base to build it out.", akActor, PlayerRef)
        Else
            Debug.Notification("You need to be at the base to upgrade it.")
        EndIf
        Return
    EndIf
    If !Native_Base_IsClearForUpgrade(FireBlockRadius, TreeBlockRadius, TentSideOffset)
        If cinematic
            SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " paces the ground around the base and comes back shaking their head: the trees stand too close for more tents, and the base would have to move to grow.", akActor, PlayerRef)
        Else
            Debug.Notification("No room here for a larger camp - reposition the base to more open ground first.")
        EndIf
        Return
    EndIf
    Form wood    = Game.GetFormFromFile(0x0006F993, "Skyrim.esm")   ; Firewood01
    Form leather = Game.GetFormFromFile(0x000DB5D2, "Skyrim.esm")   ; Leather01
    Form iron    = Game.GetFormFromFile(0x0005ACE4, "Skyrim.esm")   ; IngotIron
    ObjectReference chest = Native_Camp_GetChest()
    Int needWood    = _UpgradeCostWood(newTier)
    Int needLeather = _UpgradeCostLeather(newTier)
    Int needIron    = _UpgradeCostIron(newTier)
    ; A tier already built once (the earned tier) is rebuilt for free.
    Bool rebuild = newTier <= Native_Base_GetEarnedTier()
    If rebuild
        needWood = 0
        needLeather = 0
        needIron = 0
    EndIf
    Int haveWood    = _CountMaterial(chest, PlayerRef, wood)
    Int haveLeather = _CountMaterial(chest, PlayerRef, leather)
    Int haveIron    = _CountMaterial(chest, PlayerRef, iron)
    If haveWood < needWood || haveLeather < needLeather || haveIron < needIron
        String short = ""
        If haveWood < needWood
            short += (needWood - haveWood) + " firewood"
        EndIf
        If haveLeather < needLeather
            If short != ""
                short += ", "
            EndIf
            short += (needLeather - haveLeather) + " leather"
        EndIf
        If haveIron < needIron
            If short != ""
                short += ", "
            EndIf
            short += (needIron - haveIron) + " iron"
        EndIf
        If cinematic
            SkyrimNetApi.DirectNarration(akActor.GetDisplayName() + " checks the stash and shakes their head at " + PlayerRef.GetDisplayName() + ": not enough to build with yet - still short " + short + ".", akActor, PlayerRef)
        Else
            Debug.Notification("Short " + short + " for the upgrade (chest or pack).")
        EndIf
        Return
    EndIf
    _TakeMaterial(chest, PlayerRef, wood, needWood)
    _TakeMaterial(chest, PlayerRef, leather, needLeather)
    _TakeMaterial(chest, PlayerRef, iron, needIron)
    ; Occupants keep their sandbox (the package is on them, not the refs).
    _StartFadeToBlack()
    Utility.Wait(1.0)
    _PlayConstructionSound()
    Utility.Wait(1.5)
    _PlayConstructionSound()
    Utility.Wait(1.5)
    _PlayConstructionSound()
    Int placed = Native_Base_Upgrade(TentSideOffset)
    Utility.Wait(1.0)
    _EndFadeToBlack()
    If placed <= 0
        ; A negative result returns before anything comes down: the base stands
        ; as it was, so refund. 0 means the kit's forms failed to resolve after
        ; the teardown (the native logs which) with the tier already raised: no
        ; refund.
        Debug.Trace("[SeversHearth] UpgradeBase: native returned " + placed)
        If placed < 0
            _RefundMaterial(chest, PlayerRef, wood, needWood)
            _RefundMaterial(chest, PlayerRef, leather, needLeather)
            _RefundMaterial(chest, PlayerRef, iron, needIron)
            Debug.Notification("The upgrade could not be built here - the materials are back in the stash.")
        Else
            Debug.Notification("The upgrade could not be built here.")
        EndIf
        _PinBaseStatus()
        Return
    EndIf
    _PinBaseStatus()
    _PinBaseAsCamp()                 ; the marker was respawned by the native
    If cinematic
        Utility.Wait(1.0)
        String narration = ""
        If newTier == 2
            narration = akActor.GetDisplayName() + " and the company strike the two small tents and raise a barracks tent on each flank, plant a banner at the door of " + PlayerRef.GetDisplayName() + "'s tent, set up a mess table with its provisions and a big woodpile, and roll another barrel over to the stores - the base is an encampment now, room for the whole company."
        Else
            narration = akActor.GetDisplayName() + " and the company raise a war tent beside " + PlayerRef.GetDisplayName() + "'s, lay its plank floor and carry the war table in, map spread and weighted under a lit candle, pitch a small tent in the far corner and a hunter's lean-to with its hay at the edge, raise the second banner and the flags at the way in, and set up a smithy - an anvil and grindstone by the fire, an armor bench by the stores. The base is a command camp now."
        EndIf
        SkyrimNetApi.DirectNarration(narration, akActor, PlayerRef)
    EndIf
    If rebuild
        Debug.Notification("Base rebuilt as " + _TierName(newTier) + " - no materials needed (" + placed + " structure" + PluralS(placed) + ").")
    Else
        Debug.Notification("Base upgraded to " + _TierName(newTier) + " (" + placed + " structure" + PluralS(placed) + ").")
    EndIf
EndFunction

Event OnPrismaUpgradeBase(string eventName, string strArg, float numArg, Form sender)
    Actor PlayerRef = Game.GetPlayer()
    If PlayerRef
        UpgradeBase(PlayerRef)
    EndIf
EndEvent

Event OnPrismaCampFactionSkin(string eventName, string strArg, float numArg, Form sender)
    {Settings page tent pattern: 0 auto (follows the civil war), 1 Nord,
     2 Imperial. Applies from the next build; standing tents keep theirs. SA's
     settings handler sends the bare value; an "<actor>|" prefix is tolerated.}
    String payload = strArg
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos >= 0
        payload = StringUtil.Substring(strArg, pipePos + 1, 0)
    EndIf
    Int skin = payload as Int
    If skin < 0 || skin > 2
        skin = 0
    EndIf
    Native_Camp_SetFactionSkin(skin)
    If _SeverActionsInstalled()
        SeverActionsNativeExt2.Magelight_SetCampFactionSkin(skin)
    EndIf
    Debug.Trace("[SeversHearth] CampFactionSkin = " + skin)
EndEvent

; ── Placement (the same ghost, committed to the base slot) ───────────────

Function EnterBasePlacementMode(Bool reposition)
    {Begin positioning the base ghost. reposition=true strikes the current
     base first (chest preserved); false requires no base to exist yet.}
    If PlacementMode != 0
        Return
    EndIf
    Actor PlayerRef = Game.GetPlayer()
    If !PlayerRef
        Return
    EndIf
    Cell playerCell = PlayerRef.GetParentCell()
    If playerCell && playerCell.IsInterior()
        Debug.Notification("You can't raise a base indoors - find open ground outside.")
        Return
    EndIf
    If reposition
        If !Native_Base_IsActive()
            Debug.Notification("No base to reposition. Establish one first.")
            Return
        EndIf
        _QuietBreakBaseForReposition()
    ElseIf Native_Base_IsActive()
        Debug.Notification("You already have a base - reposition or break it.")
        Return
    EndIf
    RegisterCampEvents()
    If !Native_Base_StartPreview(TentSideOffset)
        Debug.Notification("Can't start base placement here.")
        Return
    EndIf
    PlacementMode = 2
    PlacementRotateOffset = 0.0
    PlacementBannerCooldown = 0.0
    _BeginPlacementInput()
    _ShowPlacementBanner()
    RegisterForSingleUpdate(0.1)
EndFunction

Function _FinishBaseCommit(Actor PlayerRef)
    If SandboxOnEstablish
        _FanOutBaseSandboxToTeammates(PlayerRef, 1000.0)
    EndIf
    Native_Base_SetPhase(2)          ; CampPhase::Active
    _PinBaseStatus()
    _PinBaseAsCamp()
EndFunction

Function _QuietBreakBaseForReposition()
    Native_Base_SetPhase(3)          ; CampPhase::Breaking
    _ClearBaseSandbox()
    _ReleaseBaseAsCamp()
    Native_Base_DespawnPlacedRefs()
    Native_Base_BreakKeepTier()      ; the tier survives the move
    _ClearBaseStatus()
EndFunction

; ── The base as THE camp ─────────────────────────────────────────────────
; While no field camp stands the base carries the camp surfaces: the dashboard
; rest-stop label, the one CampMapMarker and the CampLocation binding. A field
; camp takes them over when pitched and hands them back when broken.

Function _PinBaseAsCamp()
    {Give the base the rest stop, map marker and location binding. No-op while
     a field camp stands.}
    If Native_Camp_IsActive()
        Return
    EndIf
    _PinBaseRestStop()
    _MarkBaseOnMap()
    _BindBaseLocationToMarker()
EndFunction

Function _ReleaseBaseAsCamp()
    {The base stops carrying the camp surfaces - on break and reposition.
     No-op while a field camp stands (it owns them).}
    If Native_Camp_IsActive()
        Return
    EndIf
    If _SeverActionsInstalled()
        SeverActionsNative.Magelight_SetPinnedRestStop("")
    EndIf
    If CampMapMarker
        CampMapMarker.Disable()
    EndIf
    _UnbindCampLocation()
EndFunction

Function _PinBaseRestStop()
    If !_SeverActionsInstalled() || Native_Camp_IsActive()
        Return
    EndIf
    String loc = Native_Base_GetLocationName()
    If loc != ""
        SeverActionsNative.Magelight_SetPinnedRestStop("Base near " + loc)
    Else
        SeverActionsNative.Magelight_SetPinnedRestStop("Wilderness base")
    EndIf
EndFunction

Function _MarkBaseOnMap()
    {The one CampMapMarker shows the field camp when one stands, else the
     base. The Camp card's Mark / Unmark toggle stays the field camp's.}
    If !CampMapMarker || Native_Camp_IsActive()
        Return
    EndIf
    ObjectReference center = Native_Base_GetCenterMarker()
    If !center
        Return
    EndIf
    String locName = Native_Base_GetLocationName()
    String displayName = "Base"
    If locName != ""
        displayName = "Base near " + locName
    EndIf
    CampMapMarker.MoveTo(center)
    CampMapMarker.Enable()
    CampMapMarker.SetDisplayName(displayName, True)
EndFunction

Function _BindBaseLocationToMarker()
    If !CampLocation || Native_Camp_IsActive()
        Return
    EndIf
    ObjectReference marker = Native_Base_GetCenterMarker()
    If !marker
        Return
    EndIf
    If Native_Camp_BindLocationToMarker(CampLocation, marker)
        If _IntelEngineInstalled()
            IntelEngine.RebuildLocationIndex()
        EndIf
        Debug.Trace("[SeversHearth] CampLocation bound to the base's marker")
    EndIf
EndFunction

; ── Flows (mirror the field camp's, against the base slot) ───────────────

Function _EstablishBaseFlow(Actor follower, Actor PlayerRef)
    RegisterCampEvents()
    Float angleZ = PlayerRef.GetAngleZ()
    Bool cinematic = (follower != None && follower != PlayerRef)
    If cinematic
        _StartFadeToBlack()
        Utility.Wait(1.0)
    EndIf
    If !Native_Base_EstablishAtPlayer(angleZ)
        If cinematic
            _EndFadeToBlack()
        EndIf
        Debug.Notification("Failed to establish the base.")
        Return
    EndIf
    If cinematic
        _PlayConstructionSound()
        Utility.Wait(1.5)
        _PlayConstructionSound()
        Utility.Wait(1.5)
        _PlayConstructionSound()
    EndIf
    Int placed = Native_Base_SpawnStructures(angleZ, FireBlockRadius, TreeBlockRadius, TentSideOffset)
    If placed <= 0
        Native_Base_Break()
        If cinematic
            _EndFadeToBlack()
        EndIf
        Debug.Notification("Failed to raise the base.")
        Return
    EndIf
    If SandboxOnEstablish
        If cinematic
            _ApplyBaseSandbox(follower)
        EndIf
        _FanOutBaseSandboxToTeammates(PlayerRef, 1000.0)
    EndIf
    Native_Base_SetPhase(2)
    If cinematic
        Utility.Wait(1.5)
        _EndFadeToBlack()
        Utility.Wait(1.5)
    EndIf
    _PinBaseStatus()
    _PinBaseAsCamp()
    If cinematic
        String narration = follower.GetDisplayName() + " paces out the ground with " + PlayerRef.GetDisplayName() + " and the company " + \
                           "raises the tents about the fire - " + PlayerRef.GetDisplayName() + "'s own at the head " + \
                           "of the camp with a proper bed and the stash chest inside - drives in stakes " + \
                           "and kindles the fire. This one is meant to stand - a base to come back to."
        SkyrimNetApi.DirectNarration(narration, follower, PlayerRef)
    EndIf
    Debug.Notification("Base established (" + placed + " structure" + PluralS(placed) + ").")
    If Native_Base_GetTier() < Native_Base_GetEarnedTier()
        Debug.Notification("Not enough open ground here for the " + _TierName(Native_Base_GetEarnedTier()) + " - raised the " + _TierName(Native_Base_GetTier()) + " instead. Upgrading back costs nothing.")
    EndIf
EndFunction

Function _BreakBaseFlow(Actor follower, Actor PlayerRef)
    Bool cinematic = (follower != None && follower != PlayerRef)
    Native_Base_SetPhase(3)
    _ClearBaseStatus()
    _ClearBaseSandbox()
    _StartFadeToBlack()
    Utility.Wait(1.0)
    _PlayConstructionSound()
    Utility.Wait(1.5)
    _PlayConstructionSound()
    Utility.Wait(1.5)
    _PlayConstructionSound()
    Utility.Wait(1.5)
    _ReleaseBaseAsCamp()
    Native_Base_DespawnPlacedRefs()
    Native_Base_Break()
    _EndFadeToBlack()
    If cinematic
        Utility.Wait(1.5)
        String narration = follower.GetDisplayName() + " and the company strike the base - tents down, fire out, " + \
                           "stakes pulled. The stash is packed with care; the ground keeps only the " + \
                           "flattened grass where the company lived."
        SkyrimNetApi.DirectNarration(narration, follower, PlayerRef)
    EndIf
    Debug.Notification("Base broken down.")
EndFunction

; ── Base sandbox tracking (separate list; same package) ──────────────────

Function _ApplyBaseSandbox(Actor occupant)
    If !occupant || !CampSandboxPackage
        Return
    EndIf
    If _IsBaseSandboxed(occupant)
        Return
    EndIf
    ; Before the release: at the cap a field-camp occupant stays in the field camp's sandbox.
    If !_BaseHasRoom()
        Debug.Trace("[SeversHearth] Base sandbox capacity reached (" + BaseSandboxedActorCount + ") - skipping " + occupant)
        Return
    EndIf
    If _IsAlreadySandboxed(occupant)
        _ReleaseFromCampSandbox(occupant)   ; moving from the field camp to the base
    EndIf
    occupant.SetAV("WaitingForPlayer", 1)
    ActorUtil.AddPackageOverride(occupant, CampSandboxPackage, 100, 0)
    occupant.EvaluatePackage()
    SkyrimNetApi.RegisterPackage(occupant, "CampSandbox", 100, 0, false)
    BaseSandboxedActorTracking[BaseSandboxedActorCount] = occupant
    BaseSandboxedActorCount += 1
    _SetJourneyTracked(occupant, False)   ; Hearth's own sandbox now
EndFunction

Function _ReleaseFromBaseSandbox(Actor a)
    If !a
        Return
    EndIf
    If CampSandboxPackage
        ActorUtil.RemovePackageOverride(a, CampSandboxPackage)
    EndIf
    SkyrimNetApi.UnregisterPackage(a, "CampSandbox")
    a.SetAV("WaitingForPlayer", 0)
    a.EvaluatePackage()
    BaseSandboxedActorCount = _RemoveFromList(BaseSandboxedActorTracking, BaseSandboxedActorCount, a)
    _SetJourneyTracked(a, False)
EndFunction

; Per actor: 1 = listed while on a journey Hearth started (that journey's teardown owns the
; CampSandboxPackage override until it ends), unset = parked under Hearth's own sandbox, or not
; listed. Only the first answers a travel event.
String Property JOURNEY_TRACKED_KEY = "SeversHearth_JourneyTracked" AutoReadOnly
; The journey's orchestrator handle (the travel core's SeverTravel_Handle), matched against
; each travel event's numArg.
String Property JOURNEY_HANDLE_KEY = "SeversHearth_JourneyHandle" AutoReadOnly

Function _SetJourneyTracked(Actor a, Bool tracked)
    If !a
        Return
    EndIf
    If tracked
        StorageUtil.SetIntValue(a, JOURNEY_TRACKED_KEY, 1)
        StorageUtil.SetIntValue(a, JOURNEY_HANDLE_KEY, StorageUtil.GetIntValue(a, "SeverTravel_Handle", 0))
    Else
        StorageUtil.UnsetIntValue(a, JOURNEY_TRACKED_KEY)
        StorageUtil.UnsetIntValue(a, JOURNEY_HANDLE_KEY)
    EndIf
EndFunction

Bool Function _IsParkedAtCamp(Actor a)
    {On the field camp's list under Hearth's own sandbox (not on a journey there).}
    Return _IsAlreadySandboxed(a) && StorageUtil.GetIntValue(a, JOURNEY_TRACKED_KEY, 0) != 1
EndFunction

Bool Function _IsParkedAtBase(Actor a)
    {On the base's list under Hearth's own sandbox (not on a journey there).}
    Return _IsBaseSandboxed(a) && StorageUtil.GetIntValue(a, JOURNEY_TRACKED_KEY, 0) != 1
EndFunction

Function _TrackForBaseCleanup(Actor a)
    {Register an actor as a base occupant without applying the package -
     the travel core applies CampSandboxPackage on arrival.}
    If !a || _IsBaseSandboxed(a)
        Return
    EndIf
    ; Before the release, like _ApplyBaseSandbox (GoToBase already refused a full base).
    If !_BaseHasRoom()
        Debug.Trace("[SeversHearth] _TrackForBaseCleanup: cap reached, skipping " + a)
        Return
    EndIf
    If _IsAlreadySandboxed(a)
        _ReleaseFromCampSandbox(a)
    EndIf
    BaseSandboxedActorTracking[BaseSandboxedActorCount] = a
    BaseSandboxedActorCount += 1
EndFunction

Bool Function _BaseHasRoom()
    {Allocate the base list if needed, drop empty and dead entries, and report a free slot.}
    If !BaseSandboxedActorTracking
        BaseSandboxedActorTracking = new Actor[24]
        BaseSandboxedActorCount = 0
    EndIf
    _PruneBaseList()
    Return BaseSandboxedActorCount < BaseSandboxedActorTracking.Length
EndFunction

Int Function _RemoveFromList(Actor[] list, Int count, Actor a)
    {Remove every a from the first count slots of list, keeping order and emptying the tail;
     returns the new count. Arrays are references, so the caller's list changes.}
    If !list
        Return count
    EndIf
    Int w = 0
    Int r = 0
    While r < count
        If list[r] != a
            list[w] = list[r]
            w += 1
        EndIf
        r += 1
    EndWhile
    Int kept = w
    While w < count
        list[w] = None
        w += 1
    EndWhile
    Return kept
EndFunction

Function _PruneBaseList()
    {Drop empty and dead entries from the base list, keeping its order.}
    If !BaseSandboxedActorTracking
        Return
    EndIf
    Int w = 0
    Int r = 0
    While r < BaseSandboxedActorCount
        Actor e = BaseSandboxedActorTracking[r]
        If e && !e.IsDead()
            BaseSandboxedActorTracking[w] = e
            w += 1
        EndIf
        r += 1
    EndWhile
    Int k = w
    While k < BaseSandboxedActorCount
        BaseSandboxedActorTracking[k] = None
        k += 1
    EndWhile
    BaseSandboxedActorCount = w
EndFunction

Function _ForgetTracked(Actor a)
    {Drop a from both camps' lists with no package change: the travel core already tore its
     journey down (the caller undoes Hearth's own WaitingForPlayer). Order kept.}
    BaseSandboxedActorCount = _RemoveFromList(BaseSandboxedActorTracking, BaseSandboxedActorCount, a)
    SandboxedActorCount = _RemoveFromList(SandboxedActorTracking, SandboxedActorCount, a)
    _SetJourneyTracked(a, False)
EndFunction

Bool Function _IsBaseSandboxed(Actor a)
    If !BaseSandboxedActorTracking || BaseSandboxedActorCount == 0
        Return False
    EndIf
    Int i = 0
    While i < BaseSandboxedActorCount
        If BaseSandboxedActorTracking[i] == a
            Return True
        EndIf
        i += 1
    EndWhile
    Return False
EndFunction

Function _FanOutBaseSandboxToTeammates(Actor playerRef, Float maxDistance)
    If !playerRef || !CampSandboxPackage
        Return
    EndIf
    Actor[] teammates = Native_Camp_FindNearbyTeammates(maxDistance)
    If !teammates || teammates.Length == 0
        Return
    EndIf
    Int i = 0
    While i < teammates.Length
        Actor candidate = teammates[i]
        If candidate && candidate != playerRef
            _ApplyBaseSandbox(candidate)
        EndIf
        i += 1
    EndWhile
EndFunction

Function _ClearBaseSandbox()
    If !BaseSandboxedActorTracking || BaseSandboxedActorCount == 0
        Return
    EndIf
    Int i = 0
    While i < BaseSandboxedActorCount
        Actor a = BaseSandboxedActorTracking[i]
        If a
            If CampSandboxPackage
                ActorUtil.RemovePackageOverride(a, CampSandboxPackage)
            EndIf
            SkyrimNetApi.UnregisterPackage(a, "CampSandbox")
            a.SetAV("WaitingForPlayer", 0)
            If _SeverActionsInstalled()
                SeverActionsNativeExt.Travel_CancelByActor(a)
            EndIf
            a.EvaluatePackage()
            _SetJourneyTracked(a, False)
            BaseSandboxedActorTracking[i] = None
        EndIf
        i += 1
    EndWhile
    BaseSandboxedActorCount = 0
EndFunction

Function _MoveFieldSandboxToBase()
    {On promotion the field camp's occupants become the base's. Packages
     stay on; only the bookkeeping list changes.}
    If !SandboxedActorTracking || SandboxedActorCount == 0
        Return
    EndIf
    If !BaseSandboxedActorTracking
        BaseSandboxedActorTracking = new Actor[24]
        BaseSandboxedActorCount = 0
    EndIf
    Int i = 0
    While i < SandboxedActorCount
        Actor a = SandboxedActorTracking[i]
        If a && BaseSandboxedActorCount < BaseSandboxedActorTracking.Length
            BaseSandboxedActorTracking[BaseSandboxedActorCount] = a
            BaseSandboxedActorCount += 1
        EndIf
        SandboxedActorTracking[i] = None
        i += 1
    EndWhile
    SandboxedActorCount = 0
EndFunction

; ── Base status on SA's Survival page ────────────────────────────────────

Function _PinBaseStatus(Bool pushMeta = true)
    If !_SeverActionsInstalled()
        Return
    EndIf
    String loc = Native_Base_GetLocationName()
    SeverActionsNativeExt2.Magelight_SetBaseStatus(true, loc, Native_Base_GetTier(), BaseSandboxedActorCount)
    SeverActionsNativeExt2.Magelight_SetBaseBeds(Native_Base_GetBedrolls())
    If pushMeta
        _PushBaseMetaToPrisma()
    EndIf
EndFunction

Function _ClearBaseStatus()
    If !_SeverActionsInstalled()
        Return
    EndIf
    SeverActionsNativeExt2.Magelight_SetBaseStatus(false, "", 0, 0)
EndFunction

Function _PushBaseMetaToPrisma()
    If !_SeverActionsInstalled()
        Return
    EndIf
    SeverActionsNativeExt2.Magelight_SetBaseMeta(Native_Base_HoursSinceEstablished(), Native_Base_DistanceFromPlayer())
EndFunction

; Vanilla NPCHumanWoodChop (Skyrim.esm 0x0006D1CA) at the player, one-shot;
; the flows layer three of them behind the fade.
Function _PlayConstructionSound()
    Sound chop = Game.GetFormFromFile(0x0006D1CA, "Skyrim.esm") as Sound
    If chop
        chop.Play(Game.GetPlayer())
    EndIf
EndFunction

; Fade-to-black via Game.FadeOutGame. The vanilla fade IMODs (0x000F756D/E/F)
; never reach the final tonemap under Community Shaders; FadeOutGame does. It
; also locks player controls during the build, which is wanted.

Bool Property UseFadeToBlack = True Auto Hidden
{If True, the establish / break / upgrade flows fade to black while
 structures spawn or despawn. Off for fade-free testing.}

; FadeOutGame does not hold black after its animation ends, so FadeOutSeconds
; is set to outlast the whole build sequence (~5.5 s): the screen darkens
; gradually and never "completes". Do not re-apply it from an update loop -
; each call restarts the animation and the screen flickers.
Float Property FadeOutSeconds = 6.0 Auto Hidden
Float Property FadeInSeconds  = 1.5 Auto Hidden

; Animate to black over FadeOutSeconds; _EndFadeToBlack interrupts it.
Function _StartFadeToBlack()
    If !UseFadeToBlack
        Return
    EndIf
    Debug.Trace("[SeversHearth] _StartFadeToBlack: FadeOutGame out=" + FadeOutSeconds + "s")
    Game.FadeOutGame(true, true, 0.0, FadeOutSeconds)
EndFunction

; Fade back in over FadeInSeconds from wherever the fade-out has reached.
Function _EndFadeToBlack()
    If !UseFadeToBlack
        Return
    EndIf
    Debug.Trace("[SeversHearth] _EndFadeToBlack: FadeOutGame in=" + FadeInSeconds + "s")
    Game.FadeOutGame(false, true, 0.0, FadeInSeconds)
EndFunction

; Sandbox helpers. The package goes on through PapyrusUtil's ActorUtil
; override; EvaluatePackage makes the switch happen during the fade rather
; than on the next AI tick.

Function _ApplyCampSandbox(Actor occupant)
    If !occupant || !CampSandboxPackage
        ; Silent here: the fan-out reports a missing package once per camp.
        Return
    EndIf
    ; The speaker is usually among the fanned-out teammates too.
    If _IsAlreadySandboxed(occupant)
        Return
    EndIf

    ; Test a typed array with `If !arr`, never `== None` (a runtime cast error).
    If !SandboxedActorTracking
        SandboxedActorTracking = new Actor[16]
        SandboxedActorCount = 0
    EndIf

    ; Check the cap BEFORE applying: an untracked override is never removed.
    If SandboxedActorCount >= SandboxedActorTracking.Length
        Debug.Trace("[SeversHearth] Sandbox capacity reached (" + SandboxedActorCount + ") - skipping " + occupant)
        Return
    EndIf

    ; Park with WaitingForPlayer (vanilla "wait here"): the engine stops pulling
    ; them along on cell changes while they stay a teammate, so combat help,
    ; follower frameworks and SA's follower tracking are untouched.
    occupant.SetAV("WaitingForPlayer", 1)

    ActorUtil.AddPackageOverride(occupant, CampSandboxPackage, 100, 0)
    occupant.EvaluatePackage()
    ; Also registered with SkyrimNet (shows in its package UI) under
    ; "CampSandbox", the EditorID less its "Package" suffix; the ActorUtil
    ; override stays authoritative. Not persistent. OnFollowerCalledByPlayer
    ; uses it to find orphaned overrides.
    SkyrimNetApi.RegisterPackage(occupant, "CampSandbox", 100, 0, false)
    SandboxedActorTracking[SandboxedActorCount] = occupant
    SandboxedActorCount += 1
    _SetJourneyTracked(occupant, False)   ; Hearth's own sandbox now
EndFunction

Function _ReleaseFromCampSandbox(Actor a)
    {Release one actor from the field camp's sandbox (package off,
     WaitingForPlayer cleared, dropped from tracking) and leave the rest. Used
     by OnFollowerCalledByPlayer and when an actor moves to the base.}
    If !a
        Return
    EndIf
    If CampSandboxPackage
        ActorUtil.RemovePackageOverride(a, CampSandboxPackage)
    EndIf
    SkyrimNetApi.UnregisterPackage(a, "CampSandbox")
    a.SetAV("WaitingForPlayer", 0)
    a.EvaluatePackage()
    SandboxedActorCount = _RemoveFromList(SandboxedActorTracking, SandboxedActorCount, a)
    _SetJourneyTracked(a, False)
EndFunction

Function _TrackForCleanup(Actor a)
    {Track an actor without applying the package (the travel core applies it
     on arrival), so a break still releases them.}
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

; Sandbox every player teammate near the player. The native scan keys on
; IsPlayerTeammate, which every follower framework sets; PO3's
; GetCommandedActors would miss NFF-managed followers.
Function _FanOutSandboxToTeammates(Actor playerRef, Float maxDistance)
    If !playerRef
        Return
    EndIf

    ; Report an unfilled CampSandboxPackage once per fan-out.
    If !CampSandboxPackage
        Debug.Trace("[SeversHearth] ERROR: CampSandboxPackage property is None - fix the SeversHearth quest in CK")
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
        ; A teammate on an SA journey keeps walking: the camp's hold would outrank the walk.
        If candidate && candidate != playerRef && SeverActionsNativeExt2.Travel_GetPhaseByActor(candidate) == 0
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
            SkyrimNetApi.UnregisterPackage(a, "CampSandbox")
            a.SetAV("WaitingForPlayer", 0)

            ; A GoToCamp journey still under way: cancelling it also removes
            ; the travel core's arrival sandbox override. No-op without one.
            If _SeverActionsInstalled()
                SeverActionsNativeExt.Travel_CancelByActor(a)
            EndIf
            a.EvaluatePackage()
            _SetJourneyTracked(a, False)
            SandboxedActorTracking[i] = None
        EndIf
        i += 1
    EndWhile
    SandboxedActorCount = 0
EndFunction

; SeverActions integration: the survival tick and the rest-stop pin.
; CampSurvivalTick.h's worker thread fires SeversHearth_CampTick every
; interval (default 60 s) while the field camp or the base is Active; the handler
; below applies the per-tick deltas to every occupant at each camp through
; Native_Survival_AdjustNeeds. The rest-stop pin is the dashboard's "Camp near
; <location>" label. SA calls check _SeverActionsInstalled first.

Bool Function _SeverActionsInstalled()
    {True when SeverActions.esp is loaded (a cheap lookup).}
    Return Game.GetModByName("SeverActions.esp") != 255
EndFunction

Bool Function _IntelEngineInstalled()
    {True when IntelEngine.esp is loaded.}
    Return Game.GetModByName("IntelEngine.esp") != 255
EndFunction

; Bind / unbind CampLocation to the camp marker so IntelEngine resolves "go to
; the camp". The worldLocMarker write is harmless without IntelEngine; only the
; index rebuild needs it.
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

; Never read: an Auto property keeps its saved value (700, too short for the layout's beds).
; Declared so an existing save's value loads without a skipped-variable warning.
Float Property CampOccupantMaxDistance = 700.0 Auto Hidden

; Measured from the fire (the camp's position), horizontally within a height band: the layout's
; beds stand up to ~850u out (CampPlacement.h kPieces). The occupant count behind the
; camp_occupant_count decorator (CampStore.h CountOccupants, kOccupantRadius) uses the same
; radius and test.
Float Property CAMP_OCCUPANT_RADIUS = 1000.0 AutoReadOnly
{Horizontal units from the camp center within which an actor counts as at camp for the
 survival tick.}

Event OnCampTickEvent(string eventName, string strArg, float numArg, Form sender)
    ; Post-load recovery (see RegisterCampEvents): refresh the registrations,
    ; re-pin SA's camp and base cards (SA's CampStatus is per-session) and drop
    ; stale placement state. No survival pulse, so loading at camp grants none.
    If strArg == "postload"
        ; The ack comes LAST so a recovery that dies midway is re-fired; every
        ; step is idempotent, so a duplicate delivery only re-pins.
        RegisterCampEvents()
        _UpgradeInProgress = False
        If Native_Camp_IsActive()
            _PinCampRestStop(False)
            Debug.Trace("[SeversHearth] Post-load repin: restored camp badge")
        EndIf
        If Native_Base_IsActive()
            _PinBaseStatus()
            _PinBaseAsCamp()
            Debug.Trace("[SeversHearth] Post-load repin: restored base card")
        EndIf
        ; A save made mid-placement loads without its ghost; release the
        ; controls, keys and update loop.
        If PlacementMode != 0
            PlacementMode = 0
            _EndPlacementInput()
            UnregisterForUpdate()
        EndIf
        Native_Camp_AckPostLoad()
        Return
    EndIf

    If !_SeverActionsInstalled()
        Return
    EndIf
    ; The tick fires while either slot is Active; each half runs only while its
    ; own slot is (2 = CampPhase::Active), never during a Building / Breaking fade.
    If Native_Base_GetPhase() == 2
        _TickBase()
    EndIf
    If Native_Camp_GetPhase() != 2
        Return
    EndIf

    Float cx = Native_Camp_GetPosX()
    Float cy = Native_Camp_GetPosY()
    Float cz = Native_Camp_GetPosZ()
    Float maxDist = CAMP_OCCUPANT_RADIUS

    Int restored = 0

    ; The player and the occupants count only within range of the camp center.
    Actor PlayerRef = Game.GetPlayer()
    If PlayerRef && _IsActorAtCamp(PlayerRef, cx, cy, cz, maxDist)
        SeverActionsNative.Native_Survival_AdjustNeeds(PlayerRef, \
            CampRestoreHungerDelta, CampRestoreFatigueDelta, CampRestoreColdDelta)
        restored += 1
    EndIf

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

    ; Re-pin the whole camp card every tick (idempotent): it also heals a lost
    ; post-load re-pin. False = no threat-scan kick (CampThreatWatch has it).
    _PinCampRestStop(False)
EndEvent

Function _TickBase()
    Float bx = Native_Base_GetPosX()
    Float by = Native_Base_GetPosY()
    Float bz = Native_Base_GetPosZ()
    Float maxDist = CAMP_OCCUPANT_RADIUS
    Int restored = 0
    Actor PlayerRef = Game.GetPlayer()
    If PlayerRef && _IsActorAtCamp(PlayerRef, bx, by, bz, maxDist, True)
        SeverActionsNative.Native_Survival_AdjustNeeds(PlayerRef, \
            CampRestoreHungerDelta, CampRestoreFatigueDelta, CampRestoreColdDelta)
        restored += 1
    EndIf
    If BaseSandboxedActorTracking && BaseSandboxedActorCount > 0
        Int i = 0
        While i < BaseSandboxedActorCount
            Actor occupant = BaseSandboxedActorTracking[i]
            If occupant && _IsActorAtCamp(occupant, bx, by, bz, maxDist, True)
                SeverActionsNative.Native_Survival_AdjustNeeds(occupant, \
                    CampRestoreHungerDelta, CampRestoreFatigueDelta, CampRestoreColdDelta)
                restored += 1
            EndIf
            i += 1
        EndWhile
    EndIf
    _PinBaseStatus()
    _PinBaseRestStop()               ; self-heals like the field camp's pin
EndFunction

Function _PushCampMetaToPrisma()
    {Push hours since established and the player's distance to SA's Survival
     page. Threats are not pushed here: CampThreatWatch.h pushes them natively
     on combat and cell-attach events.}
    If !_SeverActionsInstalled()
        Return
    EndIf
    Float hours = Native_Camp_HoursSinceEstablished()
    Float distance = Native_Camp_DistanceFromPlayer()
    SeverActionsNativeExt.Magelight_SetCampMeta(hours, distance)
EndFunction

Bool Function _IsActorAtCamp(Actor a, Float cx, Float cy, Float cz, Float maxDist, Bool abBase = False)
    {Horizontal distance, like the occupant decorator, so a slope does not shrink the camp; a
     loose height bound keeps a different floor or a cliff top out. Only where the camp's (abBase:
     the base's) coordinates apply: interiors overlap one another.}
    If !Native_Camp_IsActorInCampSpace(a, abBase)
        Return False
    EndIf
    Float dz = a.GetPositionZ() - cz
    If dz > 512.0 || dz < -512.0
        Return False
    EndIf
    Float dx = a.GetPositionX() - cx
    Float dy = a.GetPositionY() - cy
    Return (dx * dx + dy * dy) <= (maxDist * maxDist)
EndFunction

Function _PinCampRestStop(Bool kickThreatScan = true)
    {Set the dashboard rest-stop label, the Survival page camp badge and its
     meta. kickThreatScan on establish; the tick and post-load pass False.}
    If !_SeverActionsInstalled()
        Return
    EndIf
    String loc = Native_Camp_GetLocationName()
    String label
    If Native_Camp_IsInterior()
        label = "Small camp"
        If loc != ""
            label = "Small camp in " + loc
        EndIf
    ElseIf loc != ""
        label = "Camp near " + loc
    Else
        label = "Wilderness camp"
    EndIf
    SeverActionsNative.Magelight_SetPinnedRestStop(label)

    ; The badge takes the bare location name and occupants + 1 (the player).
    Int occupants = SandboxedActorCount + 1
    SeverActionsNative.Magelight_SetCampStatus(true, loc, occupants)
    ; 0 a full camp, 1 small, 2 small and indoors: the card's label and which buttons it offers.
    Int kit = 0
    If Native_Camp_IsSmall()
        kit = 1
        If Native_Camp_IsInterior()
            kit = 2
        EndIf
    EndIf
    SeverActionsNativeExt2.Magelight_SetCampKit(kit)
    _PushCampMetaToPrisma()
    If kickThreatScan
        ; Hostiles already nearby raise no combat / cell-attach event.
        Native_Camp_KickThreatScan()
    EndIf

    Debug.Trace("[SeversHearth] Pinned rest stop + camp badge: '" + label + "' (" + occupants + " occupants)")
EndFunction

Function _ClearCampRestStop()
    {Clear the dashboard rest-stop label and the Survival page camp badge.}
    If !_SeverActionsInstalled()
        Return
    EndIf
    SeverActionsNative.Magelight_SetPinnedRestStop("")
    SeverActionsNative.Magelight_SetCampStatus(false, "", 0)
    Debug.Trace("[SeversHearth] Cleared rest stop pin + camp badge")
EndFunction

String Function PluralS(Int n)
    If n == 1
        Return ""
    EndIf
    Return "s"
EndFunction

; Native bindings (SeversHearthNative.dll).

Bool Function Native_Camp_EstablishAtPlayer(Float angleZ) Global Native
Function Native_Camp_Break() Global Native
Bool Function Native_Camp_IsActive() Global Native
; Phase: 0 Idle, 1 Building (set by Establish), 2 Active, 3 Breaking; this
; script sets Active after the spawn and Breaking at the start of a teardown.
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

; The camp_threats_nearby decorator's text; empty with no camp or hostiles.
; A query only: the Survival page gets threats from CampThreatWatch.
String Function Native_Camp_GetThreatsText() Global Native

; Re-run the threat scan now and push the result to SA.
Function Native_Camp_KickThreatScan() Global Native

; The camp's XMarkerHeading at the fire, a travel target; None with no camp.
; The native also fires SeversHearth_CampEstablished / _CampBroken with this
; marker as sender (on a break it is valid only for the listener's first frame).
ObjectReference Function Native_Camp_GetCenterMarker() Global Native

; Point a Location's worldLocMarker at the marker ("the camp" for IntelEngine
; and other location-aware mods). False on a failed cast or a None argument.
Bool Function Native_Camp_BindLocationToMarker(Form locForm, ObjectReference markerRef) Global Native

; Clear worldLocMarker so nothing resolves a deleted marker between camps.
Function Native_Camp_UnbindLocation(Form locForm) Global Native

; The survival tick (CampSurvivalTick.h worker thread).
Function Native_Camp_ForceTick() Global Native
Function Native_Camp_AckPostLoad() Global Native
Function Native_Camp_SetTickIntervalSeconds(Int seconds) Global Native
Function Native_Camp_SetTickEnabled(Bool enabled) Global Native

; Spawn the field camp (call Native_Camp_EstablishAtPlayer first). Returns the
; structure count, -1 with no player. The two block radii are unused, kept for the ABI.
Int Function Native_Camp_SpawnStructures(Float angleZ, Float fireBlockRadius, Float treeBlockRadius, Float tentSideOffset) Global Native

; No side effects: false when a tree blocks the tier-1 footprint here.
Bool Function Native_Camp_IsClearForCamp(Float angleZ, Float fireBlockRadius, Float treeBlockRadius, Float tentSideOffset) Global Native

; Every living, enabled IsPlayerTeammate() actor within `radius` of the
; player, the player excluded; covers every follower framework. Searches the
; loaded area, so a follower across a cell border counts.
Actor[] Function Native_Camp_FindNearbyTeammates(Float radius) Global Native

; ── Placement preview (CampPlacement.h) ────────────────────────────────
; StartPreview spawns the ghost ahead of the player; UpdatePreview re-projects
; and ground-snaps it (rotateOffsetDeg = the Q/E rotation on top of facing);
; CommitPreview deletes the ghost, spawns the real camp at its last transform
; (keeping the stash chest) and returns the structure count; CancelPreview
; deletes the ghost.
Bool Function Native_Camp_StartPreview(Float tentSideOffset) Global Native
Function Native_Camp_UpdatePreview(Float rotateOffsetDeg) Global Native
Int Function Native_Camp_CommitPreview() Global Native
Function Native_Camp_CancelPreview() Global Native
Bool Function Native_Camp_IsPreviewing() Global Native
; The small field camp's ghost (indoors without its tent); the commit records the kit.
Bool Function Native_Camp_StartSmallPreview() Global Native
; The field camp is a small one / stands in an interior cell (False with no camp).
Bool Function Native_Camp_IsSmall() Global Native
Bool Function Native_Camp_IsInterior() Global Native
; The actor stands where the field camp's (abBase: the base's) coordinates apply.
Bool Function Native_Camp_IsActorInCampSpace(Actor akActor, Bool abBase) Global Native

; ── The base slot (CampStore.h / CampPlacement.h) ────────────────────────
; Same shapes as their Native_Camp_* twins, pointed at the persistent base.
Bool Function Native_Base_EstablishAtPlayer(Float angleZ) Global Native
Function Native_Base_Break() Global Native
Bool Function Native_Base_IsActive() Global Native
Int Function Native_Base_GetPhase() Global Native
Function Native_Base_SetPhase(Int phase) Global Native
ObjectReference Function Native_Base_GetCenterMarker() Global Native
Float Function Native_Base_GetPosX() Global Native
Float Function Native_Base_GetPosY() Global Native
Float Function Native_Base_GetPosZ() Global Native
Float Function Native_Base_HoursSinceEstablished() Global Native
Float Function Native_Base_DistanceFromPlayer() Global Native
String Function Native_Base_GetLocationName() Global Native
Function Native_Base_DespawnPlacedRefs() Global Native
Int Function Native_Base_GetPlacedRefCount() Global Native
; 0 none, 1 bivouac, 2 encampment, 3 command camp.
Int Function Native_Base_GetTier() Global Native
; The highest tier ever built; it survives a break, so a new base goes up at
; it (or the largest tier that fits) and upgrading back to it is free.
Int Function Native_Base_GetEarnedTier() Global Native
; Unlike the field spawn, uses the block radii: steps down from the earned
; tier to the largest one whose footprint is clear.
Int Function Native_Base_SpawnStructures(Float angleZ, Float fireBlockRadius, Float treeBlockRadius, Float tentSideOffset) Global Native
Bool Function Native_Base_StartPreview(Float tentSideOffset) Global Native
; The field camp becomes the base in place (refs, marker, mask, chest).
Bool Function Native_Camp_PromoteFieldToBase() Global Native
; Tent/banner pattern: 0 auto (follows the civil war), 1 Nord, 2 Imperial.
Int Function Native_Camp_GetFactionSkin() Global Native
Function Native_Camp_SetFactionSkin(Int skin) Global Native
Int Function Native_Camp_ResolveFactionSkin() Global Native
; In order: a break that keeps the tier (reposition); the bedroll count of the
; last base build; the one stash chest; the upgrade's footprint check.
Function Native_Base_BreakKeepTier() Global Native
Int Function Native_Base_GetBedrolls() Global Native
ObjectReference Function Native_Camp_GetChest() Global Native
Bool Function Native_Base_IsClearForUpgrade(Float fireBlockRadius, Float treeBlockRadius, Float tentSideOffset) Global Native
; Returns the structure count; -1 no base / already tier 3; -2 not at the base
; (an interior or another worldspace) or footprint blocked. Both negatives
; come back before anything is torn down.
Int Function Native_Base_Upgrade(Float tentSideOffset) Global Native
; Outside, in the base's own worldspace (false with no base).
Bool Function Native_Base_IsPlayerAtBase() Global Native
