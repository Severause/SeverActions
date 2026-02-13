Scriptname SeverActions_FollowerManager extends Quest

{
    SkyrimNet-Native Follower Framework for SeverActions

    Central manager for the follower roster, relationship tracking,
    home assignments, combat style preferences, and relationship decay.

    Replaces traditional follower menus with SkyrimNet's LLM-driven
    conversation - followers are recruited, dismissed, and managed
    through natural dialogue instead of static menu options.

    Integrates with Nether's Follower Framework (NFF) when available:
    - If NFF is installed, recruitment/dismissal routes through NFF's
      controller so followers get proper alias slots, faction tracking,
      and compatibility with NFF's systems.
    - If NFF is NOT installed, uses vanilla Skyrim follower mechanics
      (SetPlayerTeammate + CurrentFollowerFaction).

    Data is stored per-follower via StorageUtil:
    - SeverFollower_IsFollower (1 = active follower)
    - SeverFollower_Rapport (-100 to 100, how they feel about the player)
    - SeverFollower_Trust (0 to 100, willingness to obey dangerous orders)
    - SeverFollower_Loyalty (0 to 100, commitment to staying)
    - SeverFollower_Mood (-100 to 100, current temperament)
    - SeverFollower_CombatStyle (aggressive/defensive/ranged/healer/balanced)
    - SeverFollower_HomeLocation (named location for dismissal)
}

; =============================================================================
; PROPERTIES - Settings (Can be modified via MCM)
; =============================================================================

Int Property MaxFollowers = 5 Auto
{Maximum number of followers allowed at once}

Float Property RapportDecayRate = 1.0 Auto
{How fast rapport decays from neglect (points per 6 game hours without conversation)}

Bool Property AllowAutonomousLeaving = true Auto
{Can followers leave on their own if rapport is too low?}

Float Property LeavingThreshold = -60.0 Auto
{Rapport level at which followers may decide to leave}

Bool Property ShowNotifications = true Auto
{Show notifications for recruitment, dismissal, relationship changes}

Bool Property DebugMode = false Auto
{Enable debug tracing for troubleshooting}

; =============================================================================
; SCRIPT REFERENCES
; =============================================================================

SeverActions_Follow Property FollowScript Auto
{Reference to the Follow system for starting/stopping follow packages}

SeverActions_Travel Property TravelScript Auto
{Reference to the Travel system for send-home functionality}

; =============================================================================
; CONSTANTS
; =============================================================================

Float Property DEFAULT_RAPPORT = 0.0 AutoReadOnly
Float Property DEFAULT_TRUST = 25.0 AutoReadOnly
Float Property DEFAULT_LOYALTY = 50.0 AutoReadOnly
Float Property DEFAULT_MOOD = 50.0 AutoReadOnly

Float Property RAPPORT_MIN = -100.0 AutoReadOnly
Float Property RAPPORT_MAX = 100.0 AutoReadOnly
Float Property TRUST_MIN = 0.0 AutoReadOnly
Float Property TRUST_MAX = 100.0 AutoReadOnly
Float Property LOYALTY_MIN = 0.0 AutoReadOnly
Float Property LOYALTY_MAX = 100.0 AutoReadOnly
Float Property MOOD_MIN = -100.0 AutoReadOnly
Float Property MOOD_MAX = 100.0 AutoReadOnly

Float Property MOOD_DECAY_RATE = 2.0 AutoReadOnly
{Mood points per game hour drifting toward baseline}

; Time conversion constant: 3631 seconds per game hour at default 20:1 timescale
Float Property SECONDS_PER_GAME_HOUR = 3631.0 AutoReadOnly

Float Property NEGLECT_HOURS = 6.0 AutoReadOnly
{Game hours without conversation before rapport starts decaying}

; StorageUtil key names
String Property KEY_IS_FOLLOWER = "SeverFollower_IsFollower" AutoReadOnly
String Property KEY_RECRUIT_TIME = "SeverFollower_RecruitTime" AutoReadOnly
String Property KEY_RAPPORT = "SeverFollower_Rapport" AutoReadOnly
String Property KEY_TRUST = "SeverFollower_Trust" AutoReadOnly
String Property KEY_LOYALTY = "SeverFollower_Loyalty" AutoReadOnly
String Property KEY_MOOD = "SeverFollower_Mood" AutoReadOnly
String Property KEY_HOME_LOCATION = "SeverFollower_HomeLocation" AutoReadOnly
String Property KEY_HOME_MARKER = "SeverFollower_HomeMarker" AutoReadOnly
String Property KEY_COMBAT_STYLE = "SeverFollower_CombatStyle" AutoReadOnly
String Property KEY_LAST_INTERACTION = "SeverFollower_LastInteraction" AutoReadOnly
String Property KEY_TIMES_RECRUITED = "SeverFollower_TimesRecruited" AutoReadOnly
String Property KEY_ORDERS_REFUSED = "SeverFollower_OrdersRefused" AutoReadOnly
String Property KEY_ORDERS_OBEYED = "SeverFollower_OrdersObeyed" AutoReadOnly

; Morality key (snapshot of vanilla Morality AV for prompt context)
String Property KEY_MORALITY = "SeverFollower_Morality" AutoReadOnly

; Keys for saving/restoring original AI values (vanilla path only)
String Property KEY_ORIG_AGGRESSION = "SeverFollower_OrigAggression" AutoReadOnly
String Property KEY_ORIG_CONFIDENCE = "SeverFollower_OrigConfidence" AutoReadOnly

; =============================================================================
; INTERNAL STATE
; =============================================================================

Float LastTickTime
Bool IsUpdating = false

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_FollowerManager] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    {Called on init and game load to set up the update loop}
    LastTickTime = GetGameTimeInSeconds()
    RegisterForSingleUpdate(30.0)

    ; Auto-detect followers recruited outside our system (vanilla dialogue, NFF, other mods)
    DetectExistingFollowers()

    If HasNFF()
        Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - NFF detected, using NFF integration")
    Else
        Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - NFF not found, using vanilla follower system")
    EndIf
EndFunction

; =============================================================================
; AUTO-DETECTION OF EXISTING FOLLOWERS
; =============================================================================

Function DetectExistingFollowers()
    {Scan the player's cell for actors who are already followers (in
     CurrentFollowerFaction or IsPlayerTeammate) but don't have our
     SeverFollower_IsFollower tracking flag. Sets up our StorageUtil
     keys so the MCM and relationship system recognize them.
     Does NOT touch faction/teammate status - they're already followers.}
    Actor player = Game.GetPlayer()
    Cell playerCell = player.GetParentCell()
    If !playerCell
        Return
    EndIf

    Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    Int numRefs = playerCell.GetNumRefs(43) ; 43 = kNPC
    Int detected = 0
    Int i = 0

    While i < numRefs
        ObjectReference ref = playerCell.GetNthRef(i, 43)
        Actor actorRef = ref as Actor

        If actorRef && actorRef != player && !actorRef.IsDead()
            ; Check if they're a follower but NOT in our system yet
            Bool isGameFollower = actorRef.IsPlayerTeammate()
            If !isGameFollower && currentFollowerFaction
                isGameFollower = actorRef.IsInFaction(currentFollowerFaction)
            EndIf

            If isGameFollower && !IsRegisteredFollower(actorRef)
                ; Found an untracked follower - set up our tracking keys
                StorageUtil.SetIntValue(actorRef, KEY_IS_FOLLOWER, 1)
                StorageUtil.SetFloatValue(actorRef, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
                StorageUtil.SetFloatValue(actorRef, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

                ; Only set defaults if they've never been in our system before
                Int timesRecruited = StorageUtil.GetIntValue(actorRef, KEY_TIMES_RECRUITED, 0)
                If timesRecruited == 0
                    StorageUtil.SetFloatValue(actorRef, KEY_RAPPORT, DEFAULT_RAPPORT)
                    StorageUtil.SetFloatValue(actorRef, KEY_TRUST, DEFAULT_TRUST)
                    StorageUtil.SetFloatValue(actorRef, KEY_LOYALTY, DEFAULT_LOYALTY)
                    StorageUtil.SetFloatValue(actorRef, KEY_MOOD, DEFAULT_MOOD)
                    StorageUtil.SetStringValue(actorRef, KEY_COMBAT_STYLE, "balanced")
                EndIf

                ; Snapshot vanilla Morality AV for prompt context
                StorageUtil.SetIntValue(actorRef, KEY_MORALITY, actorRef.GetAV("Morality") as Int)

                detected += 1
                Debug.Trace("[SeverActions_FollowerManager] Auto-detected existing follower: " + actorRef.GetDisplayName())
            EndIf
        EndIf

        i += 1
    EndWhile

    If detected > 0
        Debug.Trace("[SeverActions_FollowerManager] Auto-detected " + detected + " existing follower(s)")
        If ShowNotifications
            Debug.Notification(detected + " existing companion(s) detected by SeverActions.")
        EndIf
    EndIf
EndFunction

; =============================================================================
; NFF INTEGRATION
; =============================================================================

Bool Function HasNFF()
    {Check if Nether's Follower Framework is installed}
    Return Game.GetModByName("nwsFollowerFramework.esp") != 255
EndFunction

nwsFollowerControllerScript Function GetNFFController()
    {Get the NFF controller script instance. Returns None if NFF not installed.}
    If !HasNFF()
        Return None
    EndIf
    Quest nwsFF = Game.GetFormFromFile(0x0000434F, "nwsFollowerFramework.esp") as Quest
    If !nwsFF
        Debug.Trace("[SeverActions_FollowerManager] WARNING: NFF ESP found but controller quest missing")
        Return None
    EndIf
    nwsFollowerControllerScript controller = nwsFF as nwsFollowerControllerScript
    If !controller
        Debug.Trace("[SeverActions_FollowerManager] WARNING: NFF quest found but controller script cast failed")
        Return None
    EndIf
    Return controller
EndFunction

; =============================================================================
; UPDATE LOOP - Relationship decay and mood drift
; =============================================================================

Event OnUpdate()
    If IsUpdating
        RegisterForSingleUpdate(30.0)
        Return
    EndIf

    IsUpdating = true

    Float currentTime = GetGameTimeInSeconds()
    Float secondsPassed = currentTime - LastTickTime
    Float hoursPassed = secondsPassed / SECONDS_PER_GAME_HOUR

    ; Only update if meaningful time has passed (at least 0.5 game hours)
    If hoursPassed >= 0.5
        TickRelationships(hoursPassed)
        LastTickTime = currentTime
    EndIf

    IsUpdating = false
    RegisterForSingleUpdate(30.0)
EndEvent

Function TickRelationships(Float hoursPassed)
    {Update mood decay and rapport neglect for all followers}
    Actor player = Game.GetPlayer()
    Actor[] followers = GetAllFollowers()

    Int i = 0
    While i < followers.Length
        Actor follower = followers[i]
        If follower && !follower.IsDead()
            TickFollowerRelationship(follower, hoursPassed)
        EndIf
        i += 1
    EndWhile
EndFunction

Function TickFollowerRelationship(Actor akFollower, Float hoursPassed)
    {Update a single follower's relationship values}

    ; --- Mood Decay ---
    ; Mood drifts toward a baseline derived from rapport
    Float rapport = GetRapport(akFollower)
    Float mood = GetMood(akFollower)
    Float baseline = rapport * 0.5  ; Baseline mood is half of rapport

    Float moodDiff = baseline - mood
    Float moodChange = MOOD_DECAY_RATE * hoursPassed

    If Math.Abs(moodDiff) <= moodChange
        SetMood(akFollower, baseline)
    Else
        If moodDiff > 0
            ModifyMood(akFollower, moodChange)
        Else
            ModifyMood(akFollower, -moodChange)
        EndIf
    EndIf

    ; --- Rapport Neglect ---
    ; If the player hasn't talked to this follower in a while, rapport decays
    Float lastInteraction = StorageUtil.GetFloatValue(akFollower, KEY_LAST_INTERACTION, 0.0)
    Float currentTime = GetGameTimeInSeconds()
    Float hoursSinceInteraction = (currentTime - lastInteraction) / SECONDS_PER_GAME_HOUR

    If hoursSinceInteraction > NEGLECT_HOURS
        Float neglectPeriods = (hoursSinceInteraction - NEGLECT_HOURS) / NEGLECT_HOURS
        Float rapportLoss = RapportDecayRate * (hoursPassed / NEGLECT_HOURS)
        If rapportLoss > 0.0
            ModifyRapport(akFollower, -rapportLoss)
        EndIf
    EndIf

    ; --- Autonomous Leaving Check ---
    If AllowAutonomousLeaving
        rapport = GetRapport(akFollower) ; Re-read after potential decay
        If rapport <= LeavingThreshold
            ; Only fire the persistent event once per unhappy episode
            ; Prevents spamming SkyrimNet's event buffer every 30-second tick
            If StorageUtil.GetIntValue(akFollower, "SeverFollower_LeaveWarned", 0) == 0
                StorageUtil.SetIntValue(akFollower, "SeverFollower_LeaveWarned", 1)
                SkyrimNetApi.RegisterPersistentEvent( \
                    akFollower.GetDisplayName() + " is deeply unhappy and considering leaving " + Game.GetPlayer().GetDisplayName() + "'s service.", \
                    akFollower, Game.GetPlayer())
            EndIf
        Else
            ; Rapport recovered above threshold — reset the warning flag
            If StorageUtil.GetIntValue(akFollower, "SeverFollower_LeaveWarned", 0) == 1
                StorageUtil.SetIntValue(akFollower, "SeverFollower_LeaveWarned", 0)
            EndIf
        EndIf
    EndIf

    If DebugMode
        Debug.Trace("[SeverActions_FollowerManager] Tick: " + akFollower.GetDisplayName() + \
            " rapport=" + GetRapport(akFollower) + \
            " trust=" + GetTrust(akFollower) + \
            " mood=" + GetMood(akFollower))
    EndIf
EndFunction

; =============================================================================
; ROSTER MANAGEMENT
; =============================================================================

Function RegisterFollower(Actor akActor)
    {Add an actor to the follower roster and start them following.
     Routes through NFF when available, otherwise uses vanilla mechanics.}
    If !akActor || akActor.IsDead()
        Return
    EndIf

    If !CanRecruitMore()
        Debug.Notification("You have too many followers already.")
        SkyrimNetApi.RegisterEvent("follower_recruit_failed", \
            akActor.GetDisplayName() + " cannot join because " + Game.GetPlayer().GetDisplayName() + " already has too many companions.", \
            akActor, Game.GetPlayer())
        Return
    EndIf

    ; --- Our own tracking (always) ---
    StorageUtil.SetIntValue(akActor, KEY_IS_FOLLOWER, 1)
    StorageUtil.SetFloatValue(akActor, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

    ; Increment recruitment count
    Int timesRecruited = StorageUtil.GetIntValue(akActor, KEY_TIMES_RECRUITED, 0)
    StorageUtil.SetIntValue(akActor, KEY_TIMES_RECRUITED, timesRecruited + 1)

    ; Set default relationship values (only if first time)
    If timesRecruited == 0
        StorageUtil.SetFloatValue(akActor, KEY_RAPPORT, DEFAULT_RAPPORT)
        StorageUtil.SetFloatValue(akActor, KEY_TRUST, DEFAULT_TRUST)
        StorageUtil.SetFloatValue(akActor, KEY_LOYALTY, DEFAULT_LOYALTY)
        StorageUtil.SetFloatValue(akActor, KEY_MOOD, DEFAULT_MOOD)
        StorageUtil.SetStringValue(akActor, KEY_COMBAT_STYLE, "balanced")
    EndIf

    ; Snapshot vanilla Morality AV for prompt context (0=Any Crime, 1=Violence, 2=Property, 3=None)
    StorageUtil.SetIntValue(akActor, KEY_MORALITY, akActor.GetAV("Morality") as Int)

    ; Recruitment rapport bonus
    ModifyRapport(akActor, 5.0)
    ModifyTrust(akActor, 5.0)

    ; --- Make them a proper follower ---
    nwsFollowerControllerScript nffController = GetNFFController()

    If nffController
        ; NFF path: let NFF handle SetPlayerTeammate, factions, alias slots, packages
        DebugMsg("NFF detected - recruiting " + akActor.GetDisplayName() + " through NFF")
        nffController.RecruitFollower(akActor)
        ; NFF's RecruitFollower defers via RegisterForSingleUpdate(0.2)
        ; Our follow package will layer on top of NFF's package stack
    Else
        ; Vanilla path: handle follower mechanics ourselves
        DebugMsg("No NFF - recruiting " + akActor.GetDisplayName() + " via vanilla mechanics")

        ; Save original AI values so we can restore on dismissal
        StorageUtil.SetFloatValue(akActor, KEY_ORIG_AGGRESSION, akActor.GetAV("Aggression"))
        StorageUtil.SetFloatValue(akActor, KEY_ORIG_CONFIDENCE, akActor.GetAV("Confidence"))

        akActor.SetPlayerTeammate(true)
        Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
        If currentFollowerFaction
            akActor.AddToFaction(currentFollowerFaction)
        EndIf
    EndIf

    ; Start following via the SeverActions Follow system (works on top of NFF or vanilla)
    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.StartFollowing(akActor)
    EndIf

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " has joined you as a companion.")
    EndIf

    SkyrimNetApi.RegisterEvent("follower_recruited", \
        akActor.GetDisplayName() + " has been recruited as a companion by " + Game.GetPlayer().GetDisplayName() + ".", \
        akActor, Game.GetPlayer())

    DebugMsg("Registered follower: " + akActor.GetDisplayName() + " (recruited " + (timesRecruited + 1) + " times)")
EndFunction

Function UnregisterFollower(Actor akActor, Bool sendHome = true)
    {Remove an actor from the follower roster.
     Routes through NFF when available, otherwise uses vanilla mechanics.}
    If !akActor
        Return
    EndIf

    ; --- Our own tracking cleanup (always) ---
    StorageUtil.SetIntValue(akActor, KEY_IS_FOLLOWER, 0)

    ; Dismissal rapport hit
    ModifyRapport(akActor, -3.0)
    ModifyTrust(akActor, -1.0)

    ; --- Remove proper follower status ---
    nwsFollowerControllerScript nffController = GetNFFController()

    If nffController
        ; NFF path: let NFF handle SetPlayerTeammate, factions, alias cleanup
        DebugMsg("NFF detected - dismissing " + akActor.GetDisplayName() + " through NFF")
        nffController.RemoveFollower(akActor, -1, 0)
        ; -1 = no message (we handle our own notification), 0 = no say line
    Else
        ; Vanilla path: clean up follower mechanics ourselves
        DebugMsg("No NFF - dismissing " + akActor.GetDisplayName() + " via vanilla mechanics")

        akActor.SetPlayerTeammate(false)
        Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
        If currentFollowerFaction
            akActor.RemoveFromFaction(currentFollowerFaction)
        EndIf

        ; Restore original AI values
        Float origAggression = StorageUtil.GetFloatValue(akActor, KEY_ORIG_AGGRESSION, -1.0)
        Float origConfidence = StorageUtil.GetFloatValue(akActor, KEY_ORIG_CONFIDENCE, -1.0)
        If origAggression >= 0.0
            akActor.SetAV("Aggression", origAggression)
        EndIf
        If origConfidence >= 0.0
            akActor.SetAV("Confidence", origConfidence)
        EndIf
    EndIf

    ; Clear waiting state if set
    akActor.SetAV("WaitingForPlayer", 0)

    ; Stop following via our system
    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.StopFollowing(akActor)
    EndIf

    ; Send home or sandbox
    If sendHome
        SendHome(akActor)
    EndIf

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " is no longer your companion.")
    EndIf

    SkyrimNetApi.RegisterEvent("follower_dismissed", \
        akActor.GetDisplayName() + " is no longer traveling with " + Game.GetPlayer().GetDisplayName() + ".", \
        akActor, Game.GetPlayer())

    DebugMsg("Unregistered follower: " + akActor.GetDisplayName())
EndFunction

Bool Function IsRegisteredFollower(Actor akActor)
    If !akActor
        Return false
    EndIf
    Return StorageUtil.GetIntValue(akActor, KEY_IS_FOLLOWER, 0) == 1
EndFunction

Int Function GetFollowerCount()
    Actor[] followers = GetAllFollowers()
    Return followers.Length
EndFunction

Bool Function CanRecruitMore()
    Return GetFollowerCount() < MaxFollowers
EndFunction

Actor[] Function GetAllFollowers()
    {Get all currently registered followers by scanning nearby teammates}
    ; Use the Survival system's approach - scan cell for player teammates,
    ; then filter to those with our IsFollower flag
    Actor player = Game.GetPlayer()
    Actor[] result = PapyrusUtil.ActorArray(0)

    ; First check nearby actors
    Cell playerCell = player.GetParentCell()
    If playerCell
        Int numRefs = playerCell.GetNumRefs(43) ; 43 = kNPC
        Int i = 0
        While i < numRefs
            ObjectReference ref = playerCell.GetNthRef(i, 43)
            Actor actorRef = ref as Actor
            If actorRef && actorRef != player && IsRegisteredFollower(actorRef)
                result = PapyrusUtil.PushActor(result, actorRef)
            EndIf
            i += 1
        EndWhile
    EndIf

    Return result
EndFunction

; =============================================================================
; RELATIONSHIP SYSTEM
; =============================================================================

Function ModifyRapport(Actor akActor, Float amount)
    Float current = StorageUtil.GetFloatValue(akActor, KEY_RAPPORT, DEFAULT_RAPPORT)
    Float newVal = ClampFloat(current + amount, RAPPORT_MIN, RAPPORT_MAX)
    StorageUtil.SetFloatValue(akActor, KEY_RAPPORT, newVal)
    DebugMsg(akActor.GetDisplayName() + " rapport: " + current + " -> " + newVal + " (" + amount + ")")
EndFunction

Function ModifyTrust(Actor akActor, Float amount)
    Float current = StorageUtil.GetFloatValue(akActor, KEY_TRUST, DEFAULT_TRUST)
    Float newVal = ClampFloat(current + amount, TRUST_MIN, TRUST_MAX)
    StorageUtil.SetFloatValue(akActor, KEY_TRUST, newVal)
EndFunction

Function ModifyLoyalty(Actor akActor, Float amount)
    Float current = StorageUtil.GetFloatValue(akActor, KEY_LOYALTY, DEFAULT_LOYALTY)
    Float newVal = ClampFloat(current + amount, LOYALTY_MIN, LOYALTY_MAX)
    StorageUtil.SetFloatValue(akActor, KEY_LOYALTY, newVal)
EndFunction

Function ModifyMood(Actor akActor, Float amount)
    Float current = StorageUtil.GetFloatValue(akActor, KEY_MOOD, DEFAULT_MOOD)
    Float newVal = ClampFloat(current + amount, MOOD_MIN, MOOD_MAX)
    StorageUtil.SetFloatValue(akActor, KEY_MOOD, newVal)
EndFunction

Function SetRapport(Actor akActor, Float value)
    StorageUtil.SetFloatValue(akActor, KEY_RAPPORT, ClampFloat(value, RAPPORT_MIN, RAPPORT_MAX))
EndFunction

Function SetTrust(Actor akActor, Float value)
    StorageUtil.SetFloatValue(akActor, KEY_TRUST, ClampFloat(value, TRUST_MIN, TRUST_MAX))
EndFunction

Function SetLoyalty(Actor akActor, Float value)
    StorageUtil.SetFloatValue(akActor, KEY_LOYALTY, ClampFloat(value, LOYALTY_MIN, LOYALTY_MAX))
EndFunction

Function SetMood(Actor akActor, Float value)
    StorageUtil.SetFloatValue(akActor, KEY_MOOD, ClampFloat(value, MOOD_MIN, MOOD_MAX))
EndFunction

Float Function GetRapport(Actor akActor)
    Return StorageUtil.GetFloatValue(akActor, KEY_RAPPORT, DEFAULT_RAPPORT)
EndFunction

Float Function GetTrust(Actor akActor)
    Return StorageUtil.GetFloatValue(akActor, KEY_TRUST, DEFAULT_TRUST)
EndFunction

Float Function GetLoyalty(Actor akActor)
    Return StorageUtil.GetFloatValue(akActor, KEY_LOYALTY, DEFAULT_LOYALTY)
EndFunction

Float Function GetMood(Actor akActor)
    Return StorageUtil.GetFloatValue(akActor, KEY_MOOD, DEFAULT_MOOD)
EndFunction

; Called when the follower has a conversation with the player
Function OnFollowerInteraction(Actor akActor)
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())
EndFunction

; =============================================================================
; HOME ASSIGNMENT
; =============================================================================

Function AssignHome(Actor akActor, String locationName)
    {Assign a named location as this follower's home}
    If !akActor || locationName == ""
        Return
    EndIf

    ; Use native location resolver for fuzzy matching
    ObjectReference marker = SeverActionsNative.ResolveDestination(akActor, locationName)

    If !marker
        Debug.Notification("Could not find location: " + locationName)
        SkyrimNetApi.RegisterEvent("home_assign_failed", \
            akActor.GetDisplayName() + " couldn't find the location '" + locationName + "' to call home.", \
            akActor, Game.GetPlayer())
        Return
    EndIf

    StorageUtil.SetStringValue(akActor, KEY_HOME_LOCATION, locationName)
    StorageUtil.SetFormValue(akActor, KEY_HOME_MARKER, marker)

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " will now call " + locationName + " home.")
    EndIf

    SkyrimNetApi.RegisterPersistentEvent( \
        akActor.GetDisplayName() + " now considers " + locationName + " their home.", \
        akActor, Game.GetPlayer())

    DebugMsg("Home assigned for " + akActor.GetDisplayName() + ": " + locationName)
EndFunction

Function SendHome(Actor akActor)
    {Send a follower to their assigned home, or sandbox at current location}
    If !akActor
        Return
    EndIf

    String homeLoc = StorageUtil.GetStringValue(akActor, KEY_HOME_LOCATION, "")

    If homeLoc != ""
        ; Use the existing Travel system to send them home
        SeverActions_Travel travelSys = GetTravelScript()
        If travelSys
            travelSys.TravelToPlace(akActor, homeLoc, 48, false, 0)
            DebugMsg("Sending " + akActor.GetDisplayName() + " home to " + homeLoc)
            Return
        EndIf
    EndIf

    ; No home or no travel system - sandbox at current location
    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.Sandbox(akActor)
    EndIf
    DebugMsg(akActor.GetDisplayName() + " sandboxing at current location (no home assigned)")
EndFunction

String Function GetAssignedHome(Actor akActor)
    If !akActor
        Return ""
    EndIf
    Return StorageUtil.GetStringValue(akActor, KEY_HOME_LOCATION, "")
EndFunction

Function ClearHome(Actor akActor)
    {Remove home assignment}
    If !akActor
        Return
    EndIf
    StorageUtil.UnsetStringValue(akActor, KEY_HOME_LOCATION)
    StorageUtil.UnsetFormValue(akActor, KEY_HOME_MARKER)
    DebugMsg("Home cleared for " + akActor.GetDisplayName())
EndFunction

; =============================================================================
; COMBAT STYLE
; =============================================================================

Function SetCombatStyle(Actor akActor, String style)
    {Set follower's preferred combat approach}
    If !akActor
        Return
    EndIf

    ; Normalize the style string
    String normalized = SeverActionsNative.StringToLower(style)

    If normalized == "aggressive" || normalized == "defensive" || normalized == "ranged" || normalized == "healer" || normalized == "balanced"
        StorageUtil.SetStringValue(akActor, KEY_COMBAT_STYLE, normalized)

        ; Apply actor value adjustments based on style
        ; (NFF saves/restores originals on its own; for vanilla, we saved them on recruit)
        If normalized == "aggressive"
            akActor.SetAV("Confidence", 4) ; Foolhardy
            akActor.SetAV("Aggression", 1) ; Aggressive
        ElseIf normalized == "defensive"
            akActor.SetAV("Confidence", 2) ; Average
            akActor.SetAV("Aggression", 0) ; Unaggressive
        ElseIf normalized == "healer"
            akActor.SetAV("Confidence", 2) ; Average
            akActor.SetAV("Aggression", 0) ; Unaggressive
        Else ; balanced or ranged
            akActor.SetAV("Confidence", 3) ; Brave
            akActor.SetAV("Aggression", 1) ; Aggressive
        EndIf

        If ShowNotifications
            Debug.Notification(akActor.GetDisplayName() + " will now fight " + normalized + "ly.")
        EndIf

        SkyrimNetApi.RegisterPersistentEvent( \
            akActor.GetDisplayName() + " will now approach combat in a " + normalized + " style.", \
            akActor, Game.GetPlayer())

        DebugMsg("Combat style set for " + akActor.GetDisplayName() + ": " + normalized)
    Else
        Debug.Notification("Unknown combat style: " + style)
    EndIf
EndFunction

String Function GetCombatStyle(Actor akActor)
    If !akActor
        Return "balanced"
    EndIf
    Return StorageUtil.GetStringValue(akActor, KEY_COMBAT_STYLE, "balanced")
EndFunction

; =============================================================================
; MEMBER ACTION FUNCTIONS (Called by SkyrimNet YAML action configs)
;
; SkyrimNet calls executionFunctionName as a MEMBER function on the quest
; script instance - NOT as a Global. These must be non-Global with parameter
; signatures matching the YAML parameterMapping exactly.
; =============================================================================

Function AdjustRelationship(Actor akActor, Int rapportChange, Int trustChange, Int loyaltyChange, Int moodChange)
    {LLM-driven relationship adjustment. Called by SkyrimNet via adjustrelationship.yaml.
     The LLM decides how each interaction should affect the relationship based on
     conversation tone and content. Values are clamped by the Modify* functions.}
    If !akActor || !IsRegisteredFollower(akActor)
        Return
    EndIf

    ; Apply adjustments (Modify* functions handle clamping to valid ranges)
    If rapportChange != 0
        ModifyRapport(akActor, rapportChange as Float)
    EndIf
    If trustChange != 0
        ModifyTrust(akActor, trustChange as Float)
    EndIf
    If loyaltyChange != 0
        ModifyLoyalty(akActor, loyaltyChange as Float)
    EndIf
    If moodChange != 0
        ModifyMood(akActor, moodChange as Float)
    EndIf

    ; Also refresh the last interaction timestamp so neglect decay resets
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

    ; Build a summary for the event system
    String summary = akActor.GetDisplayName() + " relationship shift:"
    If rapportChange != 0
        summary += " rapport " + rapportChange
    EndIf
    If trustChange != 0
        summary += " trust " + trustChange
    EndIf
    If loyaltyChange != 0
        summary += " loyalty " + loyaltyChange
    EndIf
    If moodChange != 0
        summary += " mood " + moodChange
    EndIf

    SkyrimNetApi.RegisterEvent("relationship_adjusted", summary, akActor, Game.GetPlayer())

    DebugMsg(summary)
EndFunction

Function DismissCompanion(Actor akActor)
    {Dismiss a companion. Called by SkyrimNet via dismissfollower.yaml.
     Always sends home (uses default sendHome=true).}
    UnregisterFollower(akActor)
EndFunction

Function CompanionWait(Actor akActor)
    {Tell a companion to wait and sandbox at the current location permanently.
     Called by SkyrimNet via companionwait.yaml.
     Unlike Relax (followSys.Sandbox), this does NOT register with SandboxManager,
     so there is no distance check — the companion stays put until told otherwise.
     Cleanup is handled by StartFollowing() or UnregisterFollower().}
    If !akActor
        Return
    EndIf

    SeverActions_Follow followSys = GetFollowScript()
    If followSys && followSys.SandboxPackage
        ; Set waiting state so follow package yields
        akActor.SetAV("WaitingForPlayer", 1)

        ; Apply sandbox package directly — no SandboxManager registration means
        ; no distance-based auto-return. They stay here until player says otherwise.
        ActorUtil.AddPackageOverride(akActor, followSys.SandboxPackage, 90, 1)

        ; Register with SkyrimNet for package tracking (so StartFollowing cleanup finds it)
        SkyrimNetApi.RegisterPackage(akActor, "Sandbox", 90, 0, false)

        akActor.EvaluatePackage()
    Else
        ; Fallback: just set waiting flag if Follow system unavailable
        akActor.SetAV("WaitingForPlayer", 1)
        akActor.EvaluatePackage()
    EndIf

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " is waiting here for you.")
    EndIf

    SkyrimNetApi.RegisterEvent("companion_waiting", \
        akActor.GetDisplayName() + " is waiting for " + Game.GetPlayer().GetDisplayName() + " at the current location.", \
        akActor, Game.GetPlayer())
EndFunction

Function CompanionFollow(Actor akActor)
    {Tell a waiting companion to resume following. Called by SkyrimNet via companionfollow.yaml.
     Clears the wait sandbox and restarts the follow package.}
    If !akActor
        Return
    EndIf

    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        ; StartFollowing already handles: clear sandbox, clear WaitingForPlayer, re-register follow package
        followSys.StartFollowing(akActor)
    Else
        ; Fallback: just clear waiting flag
        akActor.SetAV("WaitingForPlayer", 0)
        akActor.EvaluatePackage()
    EndIf

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " is following you again.")
    EndIf

    SkyrimNetApi.RegisterEvent("companion_resumed_following", \
        akActor.GetDisplayName() + " stopped waiting and is following " + Game.GetPlayer().GetDisplayName() + " again.", \
        akActor, Game.GetPlayer())
EndFunction

Function FollowerLeaves(Actor akActor)
    {A companion decides to leave on their own. Called by SkyrimNet via followerleaves.yaml.
     This is a dramatic, rare moment after sustained mistreatment.}
    If !akActor
        Return
    EndIf

    ; This is a dramatic moment - the follower is choosing to leave
    SkyrimNetApi.RegisterEvent("follower_left_voluntarily", \
        akActor.GetDisplayName() + " has decided to leave " + Game.GetPlayer().GetDisplayName() + "'s service.", \
        akActor, Game.GetPlayer())

    UnregisterFollower(akActor)
EndFunction

; =============================================================================
; GLOBAL WRAPPER FUNCTIONS (Legacy - kept for external script calls)
; =============================================================================

Function SetCompanion_Execute(Actor akActor) Global
    SeverActions_FollowerManager instance = GetInstance()
    If instance
        instance.RegisterFollower(akActor)
    EndIf
EndFunction

Function DismissFollower_Execute(Actor akActor) Global
    SeverActions_FollowerManager instance = GetInstance()
    If instance
        instance.UnregisterFollower(akActor)
    EndIf
EndFunction

Function AssignHome_Execute(Actor akActor, String locationName) Global
    SeverActions_FollowerManager instance = GetInstance()
    If instance
        instance.AssignHome(akActor, locationName)
    EndIf
EndFunction

Function SetCombatStyle_Execute(Actor akActor, String style) Global
    SeverActions_FollowerManager instance = GetInstance()
    If instance
        instance.SetCombatStyle(akActor, style)
    EndIf
EndFunction

Function CompanionWait_Execute(Actor akActor) Global
    SeverActions_FollowerManager instance = GetInstance()
    If !instance || !akActor
        Return
    EndIf
    instance.CompanionWait(akActor)
EndFunction

Function FollowerLeaves_Execute(Actor akActor) Global
    SeverActions_FollowerManager instance = GetInstance()
    If instance
        instance.FollowerLeaves(akActor)
    EndIf
EndFunction

; =============================================================================
; GLOBAL ELIGIBILITY FUNCTIONS (Called by YAML eligibility rules)
; =============================================================================

Bool Function RecruitFollower_IsEligible(Actor akActor) Global
    If !akActor || akActor.IsDead() || akActor.IsInCombat()
        Return false
    EndIf

    SeverActions_FollowerManager instance = GetInstance()
    If !instance
        Return false
    EndIf

    ; Already a follower?
    If instance.IsRegisteredFollower(akActor)
        Return false
    EndIf

    ; At max capacity?
    If !instance.CanRecruitMore()
        Return false
    EndIf

    Return true
EndFunction

Bool Function DismissFollower_IsEligible(Actor akActor) Global
    If !akActor
        Return false
    EndIf

    SeverActions_FollowerManager instance = GetInstance()
    If !instance
        Return false
    EndIf

    Return instance.IsRegisteredFollower(akActor)
EndFunction

; =============================================================================
; HELPER FUNCTIONS
; =============================================================================

Float Function GetGameTimeInSeconds()
    {Convert current game time to seconds for precise tracking}
    ; GetCurrentGameTime() returns days as float
    ; Multiply by 24 to get hours, then by 3631 to get game seconds
    Return Utility.GetCurrentGameTime() * 24.0 * SECONDS_PER_GAME_HOUR
EndFunction

SeverActions_FollowerManager Function GetInstance() Global
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
EndFunction

SeverActions_Follow Function GetFollowScript()
    If FollowScript
        Return FollowScript
    EndIf
    ; Fallback: try to find via FormID
    Return Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
EndFunction

SeverActions_Travel Function GetTravelScript()
    If TravelScript
        Return TravelScript
    EndIf
    ; Fallback: try to find on the quest
    Quest myQuest = Self as Quest
    If myQuest
        Return myQuest as SeverActions_Travel
    EndIf
    Return None
EndFunction

Float Function ClampFloat(Float value, Float minVal, Float maxVal)
    If value < minVal
        Return minVal
    ElseIf value > maxVal
        Return maxVal
    Else
        Return value
    EndIf
EndFunction

Function DebugMsg(String msg)
    If DebugMode
        Debug.Trace("[SeverActions_FollowerManager] " + msg)
    EndIf
EndFunction
