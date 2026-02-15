Scriptname SeverActions_FollowerManager extends Quest

{
    SkyrimNet-Native Follower Framework for SeverActions

    Central manager for the follower roster, relationship tracking,
    home assignments, combat style preferences, and relationship decay.

    Replaces traditional follower menus with SkyrimNet's LLM-driven
    conversation - followers are recruited, dismissed, and managed
    through natural dialogue instead of static menu options.

    Follower framework integration (priority order):
    1. Nether's Follower Framework (NFF) - if nwsFollowerFramework.esp is loaded,
       recruitment/dismissal routes through NFF's controller for proper alias
       slots, faction tracking, and compatibility with NFF's systems.
    2. Extensible Follower Framework (EFF) - if EFFCore.esm is loaded,
       recruitment/dismissal routes through EFF's XFL_AddFollower/XFL_RemoveFollower
       for proper alias slots, faction tracking, and EFF plugin compatibility.
    3. Vanilla - if neither framework is installed, uses vanilla Skyrim follower
       mechanics (SetPlayerTeammate + CurrentFollowerFaction).

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

Int Property MaxFollowers = 10 Auto
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

SeverActions_Outfit Property OutfitScript Auto
{Reference to the Outfit system for outfit persistence across cell transitions}

ReferenceAlias[] Property OutfitSlots Auto
{Array of 10 ReferenceAlias slots for per-follower outfit persistence.
 Each slot has SeverActions_OutfitAlias attached, which handles OnLoad/OnCellLoad
 events to re-equip locked outfits instantly. Fill in CK.}

Faction Property SeverActions_FollowerFaction Auto
{Our own follower faction — dedicated to SeverActions.
 Added on recruit, removed on dismiss. Provides fast, unambiguous
 "is this our follower?" checks without StorageUtil lookups.
 Does not conflict with NFF/EFF/vanilla faction systems.
 Create in CK — just a new faction, no special setup needed.}

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

; Key for tracking custom-framework followers (Serana, Inigo, Lucien, etc.)
; Set to 1 on recruit if the actor was already IsPlayerTeammate() before we touched them.
; On dismiss, if this is 1, we skip SetPlayerTeammate(false) to avoid breaking their mod's AI.
String Property KEY_WAS_ALREADY_TEAMMATE = "SeverFollower_WasAlreadyTeammate" AutoReadOnly

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

    ; Register for native teammate detection events (instant onboarding)
    RegisterForModEvent("SeverActions_NewTeammateDetected", "OnNativeTeammateDetected")
    RegisterForModEvent("SeverActions_TeammateRemoved", "OnNativeTeammateRemoved")

    ; Auto-detect followers recruited outside our system (vanilla dialogue, NFF, other mods)
    DetectExistingFollowers()

    ; Re-assign outfit alias slots after load (ForceRefTo doesn't survive save/load)
    ReassignOutfitSlots()

    ; Re-apply follow tracking after load (LinkedRef and SkyrimNet tracking are runtime-only)
    ; The CK alias packages persist natively, but LinkedRef must be re-set
    ; Skip if NFF or EFF is managing packages — they handle their own persistence
    If !HasNFF() && !HasEFF()
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            Actor[] followers = GetAllFollowers()
            followSys.ReapplyFollowTracking(followers)
        EndIf
    EndIf

    If HasNFF()
        Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - NFF detected, using NFF integration")
    ElseIf HasEFF()
        Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - EFF detected, using EFF integration")
    Else
        Debug.Trace("[SeverActions_FollowerManager] Maintenance complete - no follower framework found, using vanilla follower system")
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
     Does NOT touch faction/teammate status - they're already followers.

     NFF quirk: NFF sets CurrentFollowerFaction rank to -1 on dismiss
     instead of removing from the faction. We must check faction rank >= 0
     to avoid detecting dismissed NFF followers as active.}
    Actor player = Game.GetPlayer()
    Cell playerCell = player.GetParentCell()
    If !playerCell
        Return
    EndIf

    Faction currentFollowerFaction = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction

    ; Also check EFF's faction if EFF is installed
    Faction effFollowerFaction = None
    EFFCore effController = GetEFFController()
    If effController
        effFollowerFaction = effController.XFL_FollowerFaction
    EndIf

    Int numRefs = playerCell.GetNumRefs(43) ; 43 = kNPC
    Int detected = 0
    Int i = 0

    While i < numRefs
        ObjectReference ref = playerCell.GetNthRef(i, 43)
        Actor actorRef = ref as Actor

        If actorRef && actorRef != player && !actorRef.IsDead()
            ; Check if they're a follower but NOT in our system yet
            Bool isGameFollower = actorRef.IsPlayerTeammate()

            ; Check CurrentFollowerFaction — but require rank >= 0
            ; NFF sets rank to -1 on dismiss instead of removing from faction,
            ; so IsInFaction alone would false-positive on dismissed NFF followers
            If !isGameFollower && currentFollowerFaction
                If actorRef.IsInFaction(currentFollowerFaction) && actorRef.GetFactionRank(currentFollowerFaction) >= 0
                    isGameFollower = true
                EndIf
            EndIf

            If !isGameFollower && effFollowerFaction
                isGameFollower = actorRef.IsInFaction(effFollowerFaction)
            EndIf

            ; Also check our own faction — catches followers whose StorageUtil
            ; co-save data hasn't loaded yet or got corrupted
            If !isGameFollower && SeverActions_FollowerFaction
                If actorRef.IsInFaction(SeverActions_FollowerFaction)
                    isGameFollower = true
                EndIf
            EndIf

            If isGameFollower && !IsRegisteredFollower(actorRef)
                ; Found an untracked follower - fully onboard them into our system.
                ; These are actors recruited via vanilla dialogue, another mod, or before
                ; our plugin was installed. They already have a working follow system,
                ; so we treat them like custom-framework followers: track everything
                ; but don't override their AI packages.

                ; --- StorageUtil tracking keys ---
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

                ; Mark as already-teammate so dismiss path doesn't undo their teammate status
                StorageUtil.SetIntValue(actorRef, KEY_WAS_ALREADY_TEAMMATE, 1)

                ; --- Faction ---
                ; Add to our faction for fast detection (doesn't conflict with anything)
                If SeverActions_FollowerFaction
                    actorRef.AddToFaction(SeverActions_FollowerFaction)
                EndIf

                ; --- Outfit alias slot ---
                ; Gives them outfit persistence via OnLoad/OnCellLoad events
                AssignOutfitSlot(actorRef)

                ; --- Follow system ---
                ; If NFF/EFF is managing packages, just register SkyrimNet tracking.
                ; Otherwise, bring them into our full alias-based follow system —
                ; this replaces whatever vanilla/mod follow package they had with
                ; our persistent alias package (better save/load survival).
                ; If no follower framework, bring them into our alias-based companion follow.
                ; NFF/EFF handle their own packages — we just track those.
                If !HasNFF() && !effController
                    SeverActions_Follow followSys = GetFollowScript()
                    If followSys
                        followSys.CompanionStartFollowing(actorRef)
                    EndIf
                EndIf

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
; NATIVE TEAMMATE DETECTION EVENT HANDLERS
; Fired by TeammateMonitor in the DLL when SetPlayerTeammate(true/false) is detected
; =============================================================================

Event OnNativeTeammateDetected(string eventName, string strArg, float numArg, Form sender)
    {Instant follower onboarding — fired ~1 second after any mod/vanilla dialogue
     calls SetPlayerTeammate(true) on an actor we're not already tracking.}
    Actor akActor = sender as Actor
    if !akActor
        akActor = Game.GetFormEx(numArg as int) as Actor
    endif

    if !akActor || akActor.IsDead()
        return
    endif

    ; Already in our system? Skip.
    If IsRegisteredFollower(akActor)
        return
    EndIf

    ; Already in our faction? Also skip (co-save data might not be loaded yet).
    If SeverActions_FollowerFaction && akActor.IsInFaction(SeverActions_FollowerFaction)
        return
    EndIf

    ; This is a new teammate we don't know about — onboard them.
    ; Same logic as DetectExistingFollowers but for a single actor.
    Debug.Trace("[SeverActions_FollowerManager] Native teammate detected: " + akActor.GetDisplayName())

    ; --- StorageUtil tracking keys ---
    StorageUtil.SetIntValue(akActor, KEY_IS_FOLLOWER, 1)
    StorageUtil.SetFloatValue(akActor, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

    ; Only set defaults if they've never been in our system before
    Int timesRecruited = StorageUtil.GetIntValue(akActor, KEY_TIMES_RECRUITED, 0)
    If timesRecruited == 0
        StorageUtil.SetFloatValue(akActor, KEY_RAPPORT, DEFAULT_RAPPORT)
        StorageUtil.SetFloatValue(akActor, KEY_TRUST, DEFAULT_TRUST)
        StorageUtil.SetFloatValue(akActor, KEY_LOYALTY, DEFAULT_LOYALTY)
        StorageUtil.SetFloatValue(akActor, KEY_MOOD, DEFAULT_MOOD)
        StorageUtil.SetStringValue(akActor, KEY_COMBAT_STYLE, "balanced")
    EndIf

    ; Snapshot vanilla Morality AV for prompt context
    StorageUtil.SetIntValue(akActor, KEY_MORALITY, akActor.GetAV("Morality") as Int)

    ; Mark as already-teammate so dismiss path doesn't undo their teammate status
    StorageUtil.SetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE, 1)

    ; --- Faction ---
    If SeverActions_FollowerFaction
        akActor.AddToFaction(SeverActions_FollowerFaction)
    EndIf

    ; --- Outfit alias slot ---
    AssignOutfitSlot(akActor)

    ; --- Follow system ---
    ; If NFF/EFF is managing packages, they handle follow.
    ; Otherwise, bring them into our alias-based companion follow.
    If !HasNFF() && !HasEFF()
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.CompanionStartFollowing(akActor)
        EndIf
    EndIf

    If ShowNotifications
        Debug.Notification(akActor.GetDisplayName() + " detected as new companion.")
    EndIf

    SkyrimNetApi.RegisterEvent("follower_recruited", \
        akActor.GetDisplayName() + " has been detected and onboarded as a companion.", \
        akActor, Game.GetPlayer())

    DebugMsg("Native teammate detected and onboarded: " + akActor.GetDisplayName())
EndEvent

Event OnNativeTeammateRemoved(string eventName, string strArg, float numArg, Form sender)
    {Fired when SetPlayerTeammate(false) is detected on a tracked actor.
     Optional — our dismiss path already handles cleanup. This catches
     cases where another mod dismisses a follower without going through us.}
    Actor akActor = sender as Actor
    if !akActor
        akActor = Game.GetFormEx(numArg as int) as Actor
    endif

    if !akActor
        return
    endif

    ; Only react if this is one of our followers
    If !IsRegisteredFollower(akActor)
        return
    EndIf

    ; If the actor is still a teammate (e.g., our own code just set it to false
    ; then back to true during framework routing), don't react.
    If akActor.IsPlayerTeammate()
        return
    EndIf

    Debug.Trace("[SeverActions_FollowerManager] Native teammate removal detected: " + akActor.GetDisplayName())

    ; Another mod removed this actor's teammate status — clean up our tracking.
    ; Use sendHome=false since the other mod is presumably handling where they go.
    UnregisterFollower(akActor, false)

    DebugMsg("Native teammate removal detected and cleaned up: " + akActor.GetDisplayName())
EndEvent

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
; EFF INTEGRATION
; =============================================================================

Bool Function HasEFF()
    {Check if Extensible Follower Framework is installed}
    Return Game.GetModByName("EFFCore.esm") != 255
EndFunction

EFFCore Function GetEFFController()
    {Get the EFF controller script instance. Returns None if EFF not installed.}
    If !HasEFF()
        Return None
    EndIf
    Quest effQuest = Game.GetFormFromFile(0x00000EFF, "EFFCore.esm") as Quest
    If !effQuest
        Debug.Trace("[SeverActions_FollowerManager] WARNING: EFFCore.esm found but controller quest missing")
        Return None
    EndIf
    EFFCore controller = effQuest as EFFCore
    If !controller
        Debug.Trace("[SeverActions_FollowerManager] WARNING: EFF quest found but controller script cast failed")
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
; OUTFIT SLOT MANAGEMENT - ReferenceAlias-based outfit persistence
; =============================================================================

Function AssignOutfitSlot(Actor akActor)
    {Find an empty ReferenceAlias outfit slot and assign the actor to it.
     The alias script (SeverActions_OutfitAlias) handles OnLoad/OnCellLoad
     events to re-equip locked outfits with zero flicker.}
    If !OutfitSlots
        DebugMsg("WARNING: OutfitSlots array not set - outfit persistence disabled")
        Return
    EndIf

    Int i = 0
    While i < OutfitSlots.Length
        If OutfitSlots[i] && !OutfitSlots[i].GetActorRef()
            OutfitSlots[i].ForceRefTo(akActor)
            DebugMsg("Outfit slot " + i + " assigned to " + akActor.GetDisplayName())

            ; If the actor's 3D is already loaded (e.g. reassignment after save/load),
            ; OnLoad won't fire again, so immediately reapply the locked outfit now.
            If akActor.Is3DLoaded()
                SeverActions_Outfit outfitSys = GetOutfitScript()
                If outfitSys
                    outfitSys.ReapplyLockedOutfit(akActor)
                EndIf
            EndIf
            Return
        EndIf
        i += 1
    EndWhile

    DebugMsg("WARNING: No free outfit slots for " + akActor.GetDisplayName())
EndFunction

Function ClearOutfitSlot(Actor akActor)
    {Find and clear the ReferenceAlias outfit slot for this actor.}
    If !OutfitSlots
        Return
    EndIf

    Int i = 0
    While i < OutfitSlots.Length
        If OutfitSlots[i] && OutfitSlots[i].GetActorRef() == akActor
            OutfitSlots[i].Clear()
            DebugMsg("Outfit slot " + i + " cleared for " + akActor.GetDisplayName())
            Return
        EndIf
        i += 1
    EndWhile
EndFunction

Function ReassignOutfitSlots()
    {Re-assign outfit alias slots after a game load.
     ForceRefTo is runtime-only and doesn't survive save/load, so we need to
     repopulate the alias slots every time Maintenance() runs.
     Covers both active followers AND dismissed actors with outfit locks.}
    If !OutfitSlots
        Return
    EndIf

    ; Clear any stale alias data first
    Int i = 0
    While i < OutfitSlots.Length
        If OutfitSlots[i]
            OutfitSlots[i].Clear()
        EndIf
        i += 1
    EndWhile

    Int totalAssigned = 0

    ; Re-assign slots for all current followers
    Actor[] followers = GetAllFollowers()
    i = 0
    While i < followers.Length
        If followers[i]
            AssignOutfitSlot(followers[i])
            totalAssigned += 1
        EndIf
        i += 1
    EndWhile

    ; Also assign slots for dismissed actors who still have active outfit locks.
    ; Without this, dismissed followers lose alias events on save/load and go naked.
    SeverActions_Outfit outfitSys = GetOutfitScript()
    If outfitSys
        Actor[] lockedActors = outfitSys.GetOutfitLockedActors()
        i = 0
        While i < lockedActors.Length
            If lockedActors[i]
                ; Skip actors already assigned (they're still active followers)
                Bool alreadyAssigned = false
                Int j = 0
                While j < followers.Length
                    If followers[j] == lockedActors[i]
                        alreadyAssigned = true
                        j = followers.Length ; break
                    EndIf
                    j += 1
                EndWhile

                If !alreadyAssigned
                    AssignOutfitSlot(lockedActors[i])
                    totalAssigned += 1
                    DebugMsg("Outfit slot assigned for dismissed actor: " + lockedActors[i].GetDisplayName())
                EndIf
            EndIf
            i += 1
        EndWhile
    EndIf

    If totalAssigned > 0
        DebugMsg("Reassigned outfit slots for " + totalAssigned + " actor(s) after load (" + followers.Length + " followers + " + (totalAssigned - followers.Length) + " dismissed with outfits)")
    EndIf
EndFunction

; =============================================================================
; ROSTER MANAGEMENT
; =============================================================================

Function RegisterFollower(Actor akActor)
    {Add an actor to the follower roster and start them following.
     Routes through NFF/EFF when available, otherwise uses vanilla mechanics.}
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

    ; --- Our own tracking (always, regardless of framework) ---
    StorageUtil.SetIntValue(akActor, KEY_IS_FOLLOWER, 1)
    StorageUtil.SetFloatValue(akActor, KEY_RECRUIT_TIME, GetGameTimeInSeconds())
    StorageUtil.SetFloatValue(akActor, KEY_LAST_INTERACTION, GetGameTimeInSeconds())

    ; Add to our own faction for fast, unambiguous detection
    If SeverActions_FollowerFaction
        akActor.AddToFaction(SeverActions_FollowerFaction)
    EndIf

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
    ; Check if this actor is already a teammate BEFORE we touch anything.
    ; If they are, they likely have their own follow system (custom follower mod,
    ; Serana's DawnguardFollowerScript, Inigo, Lucien, etc.) — we should track them
    ; for our purposes but NOT override their existing follow packages.
    Bool wasAlreadyTeammate = akActor.IsPlayerTeammate()

    ; Priority: NFF > EFF > Custom (already teammate) > Vanilla
    nwsFollowerControllerScript nffController = GetNFFController()
    EFFCore effController = None
    If !nffController
        effController = GetEFFController()
    EndIf

    If nffController
        ; NFF path: let NFF handle SetPlayerTeammate, factions, alias slots, packages
        DebugMsg("NFF detected - recruiting " + akActor.GetDisplayName() + " through NFF")
        nffController.RecruitFollower(akActor)
        ; NFF's RecruitFollower defers via RegisterForSingleUpdate(0.2)
    ElseIf effController
        ; EFF path: let EFF handle SetPlayerTeammate, factions, alias slots, relationship ranks
        DebugMsg("EFF detected - recruiting " + akActor.GetDisplayName() + " through EFF")
        effController.XFL_AddFollower(akActor as Form)
    ElseIf wasAlreadyTeammate
        ; Custom framework path: actor is already a teammate from another mod
        ; (Serana, Inigo, Lucien, Sofia, etc.) — they have their own follow packages.
        ; We just track them for relationship/MCM/outfit purposes, don't touch their AI.
        ; Store the flag so UnregisterFollower knows not to undo SetPlayerTeammate.
        StorageUtil.SetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE, 1)
        DebugMsg("Custom follower detected - " + akActor.GetDisplayName() + " is already a teammate, tracking only")
    Else
        ; Vanilla path: handle follower mechanics ourselves
        DebugMsg("No follower framework - recruiting " + akActor.GetDisplayName() + " via vanilla mechanics")

        ; Clear any stale custom-follower flag (in case they were previously custom and re-recruited)
        StorageUtil.UnsetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE)

        ; Save original AI values so we can restore on dismissal
        StorageUtil.SetFloatValue(akActor, KEY_ORIG_AGGRESSION, akActor.GetAV("Aggression"))
        StorageUtil.SetFloatValue(akActor, KEY_ORIG_CONFIDENCE, akActor.GetAV("Confidence"))

        ; SetPlayerTeammate handles combat alliance, sneak sync, weapon draw sync, crime sharing.
        ; We intentionally do NOT add to CurrentFollowerFaction — that faction is monitored by
        ; NFF (8-second CheckFollowers tick) and other mods. Adding to it causes conflicts if
        ; a user later installs a follower framework. Our own SeverActions_FollowerFaction
        ; handles detection instead.
        akActor.SetPlayerTeammate(true)
        akActor.IgnoreFriendlyHits(true)
    EndIf

    ; Start companion following via our CK alias-based package
    ; Skip for NFF/EFF (they manage their own packages) and custom followers
    ; (they already have follow packages from their mod)
    If !nffController && !effController && !wasAlreadyTeammate
        SeverActions_Follow followSys = GetFollowScript()
        If followSys
            followSys.CompanionStartFollowing(akActor)
        EndIf
    EndIf

    ; Assign an outfit alias slot for zero-flicker outfit persistence
    AssignOutfitSlot(akActor)

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

    ; --- Keep outfit alias slot active so outfit lock persists after dismiss ---
    ; ClearOutfitSlot is NOT called here. The alias stays linked so OnCellLoad
    ; can re-apply the locked outfit when the NPC loads at their home location.
    ; The slot is only freed when the outfit lock is explicitly cleared (Dress action).

    ; --- Our own tracking cleanup (always, regardless of framework) ---
    StorageUtil.SetIntValue(akActor, KEY_IS_FOLLOWER, 0)

    ; Remove from our faction
    If SeverActions_FollowerFaction
        akActor.RemoveFromFaction(SeverActions_FollowerFaction)
    EndIf

    ; Dismissal rapport hit
    ModifyRapport(akActor, -3.0)
    ModifyTrust(akActor, -1.0)

    ; --- Remove proper follower status ---
    ; Priority: NFF > EFF > Custom (was already teammate) > Vanilla
    nwsFollowerControllerScript nffController = GetNFFController()
    EFFCore effController = None
    If !nffController
        effController = GetEFFController()
    EndIf

    ; Check if this was a custom-framework follower (Serana, Inigo, Lucien, etc.)
    ; who was already a teammate before we recruited them.
    Bool wasAlreadyTeammate = StorageUtil.GetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE, 0) == 1

    If nffController
        ; NFF path: let NFF handle SetPlayerTeammate, factions, alias cleanup
        DebugMsg("NFF detected - dismissing " + akActor.GetDisplayName() + " through NFF")
        nffController.RemoveFollower(akActor, -1, 0)
        ; -1 = no message (we handle our own notification), 0 = no say line
        StorageUtil.UnsetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE)
    ElseIf effController
        ; EFF path: let EFF handle SetPlayerTeammate, factions, alias cleanup
        DebugMsg("EFF detected - dismissing " + akActor.GetDisplayName() + " through EFF")
        effController.XFL_RemoveFollower(akActor as Form, 0, 0)
        ; 0 = standard dismiss message, 0 = no say line (we handle our own notification)
        StorageUtil.UnsetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE)
    ElseIf wasAlreadyTeammate
        ; Custom framework path: this actor was already a teammate from another mod
        ; (Serana, Inigo, Lucien, Sofia, etc.) when we recruited them.
        ; Do NOT undo SetPlayerTeammate or IgnoreFriendlyHits — their mod manages that.
        ; We only clean up our tracking layer.
        DebugMsg("Custom follower dismiss - " + akActor.GetDisplayName() + " was already a teammate, leaving teammate status intact")
        StorageUtil.UnsetIntValue(akActor, KEY_WAS_ALREADY_TEAMMATE)
    Else
        ; Vanilla path: clean up follower mechanics ourselves
        DebugMsg("No follower framework - dismissing " + akActor.GetDisplayName() + " via vanilla mechanics")

        akActor.SetPlayerTeammate(false)
        akActor.IgnoreFriendlyHits(false)

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

    ; NOTE: We intentionally do NOT clear the outfit lock on dismiss.
    ; If the player told them to wear something, they should keep it
    ; even after being sent home.

    ; Stop companion following via our alias system
    ; CompanionStopFollowing clears alias slot + LinkedRef.
    ; Safe to call for NFF/EFF/custom followers — ClearFollowerSlot finds nothing and returns.
    SeverActions_Follow followSys = GetFollowScript()
    If followSys
        followSys.CompanionStopFollowing(akActor)
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
    {Get all currently registered followers.
     Scans two sources:
     1. Current cell — finds followers physically nearby
     2. Follower alias slots — finds followers in other cells (aliases persist across save/load)
     Both sources are filtered to actors with our IsFollower StorageUtil flag.}
    Actor player = Game.GetPlayer()
    Actor[] result = PapyrusUtil.ActorArray(0)

    ; Source 1: Scan current cell for registered followers
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

    ; Source 2: Check follower alias slots (catches followers in other cells)
    SeverActions_Follow followSys = GetFollowScript()
    If followSys && followSys.FollowerSlots
        Int i = 0
        While i < followSys.FollowerSlots.Length
            If followSys.FollowerSlots[i]
                Actor slotActor = followSys.FollowerSlots[i].GetActorRef()
                If slotActor && slotActor != player && !slotActor.IsDead() && IsRegisteredFollower(slotActor)
                    ; Check if already in result (avoid duplicates from cell scan)
                    Bool alreadyFound = false
                    Int j = 0
                    While j < result.Length
                        If result[j] == slotActor
                            alreadyFound = true
                            j = result.Length ; break
                        EndIf
                        j += 1
                    EndWhile
                    If !alreadyFound
                        result = PapyrusUtil.PushActor(result, slotActor)
                    EndIf
                EndIf
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
    {Tell any NPC to wait and sandbox at the current location.
     Called by SkyrimNet via companionwait.yaml. Works for both companions and non-companions.
     Unlike Relax (followSys.Sandbox), this does NOT register with SandboxManager,
     so there is no distance check — the NPC stays put until told otherwise.
     Cleanup is handled by StartFollowing() or UnregisterFollower().}
    If !akActor
        Return
    EndIf

    SeverActions_Follow followSys = GetFollowScript()
    If followSys && followSys.SandboxPackage
        ; Set waiting state so follow package yields
        akActor.SetAV("WaitingForPlayer", 1)

        ; Apply sandbox package — NPC wanders, sits, interacts with furniture for immersion
        ; No SandboxManager registration = no distance-based auto-return
        ActorUtil.AddPackageOverride(akActor, followSys.SandboxPackage, followSys.SandboxPackagePriority, 1)

        ; Register with SkyrimNet for package tracking (so StartFollowing cleanup finds it)
        SkyrimNetApi.RegisterPackage(akActor, "Sandbox", followSys.SandboxPackagePriority, 0, false)

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
        ; CompanionStartFollowing handles: clear sandbox, clear WaitingForPlayer, re-set LinkedRef + alias
        followSys.CompanionStartFollowing(akActor)
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

SeverActions_Outfit Function GetOutfitScript()
    If OutfitScript
        Return OutfitScript
    EndIf
    ; Fallback: try to find on the quest
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Outfit
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
