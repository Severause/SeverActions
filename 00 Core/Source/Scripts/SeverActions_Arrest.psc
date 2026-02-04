Scriptname SeverActions_Arrest extends Quest

{
    Guard Arrest System for SeverActions

    Allows guards to:
    - Add bounty to player for crimes
    - Arrest NPCs and escort them to jail
    - Walk up to target with weapon drawn
    - Escort prisoner to appropriate hold jail

    Self-contained travel logic - does not depend on SeverActions_Travel.

    Required CK Setup:
    - Create factions: SeverActions_WaitingArrest, SeverActions_Arrested, SeverActions_Jailed
    - Create keyword: SeverActions_EscortTargetKeyword
    - Create reference aliases: ArrestTarget (for approach), JailDestination (for escort), ArrestingGuard
    - Create packages: SeverActions_ApproachTarget (Travel), SeverActions_GuardEscortToJail (Travel),
                       SeverActions_PrisonerFollow (Follow), SeverActions_JailSandbox (Sandbox)
    - Fill properties in CK
}

; =============================================================================
; PROPERTIES - Factions (Create in CK)
; =============================================================================

Faction Property SeverActions_WaitingArrest Auto
{Faction for NPCs waiting to be arrested (in bleedout/subdued state)}

Faction Property SeverActions_Arrested Auto
{Faction for NPCs currently being escorted to jail}

Faction Property SeverActions_Jailed Auto
{Faction for NPCs who have been delivered to jail}

Faction Property dunPrisonerFaction Auto
{Vanilla faction - prevents guards from attacking prisoner. FormID: 0x0003B08B}

; =============================================================================
; PROPERTIES - Crime Factions (Vanilla - Fill in CK)
; =============================================================================

Faction Property CrimeFactionWhiterun Auto
Faction Property CrimeFactionRift Auto
Faction Property CrimeFactionHaafingar Auto
Faction Property CrimeFactionEastmarch Auto
Faction Property CrimeFactionReach Auto
Faction Property CrimeFactionFalkreath Auto
Faction Property CrimeFactionPale Auto
Faction Property CrimeFactionHjaalmarch Auto
Faction Property CrimeFactionWinterhold Auto

; =============================================================================
; PROPERTIES - Keywords & Packages (Create in CK)
; =============================================================================

Keyword Property SeverActions_EscortTargetKeyword Auto
{Keyword used to link prisoner to guard for follow package, and prisoner to jail marker for sandbox}

Package Property SeverActions_ApproachTarget Auto
{Travel package for guard to walk to ArrestTarget alias (approach phase)}

Package Property SeverActions_GuardEscortToJail Auto
{Travel package for guard to walk to JailDestination alias (escort phase)}

Package Property SeverActions_PrisonerFollow Auto
{Follow package for prisoner - follows their linked ref (the guard).
Setup: Type=Follow, Follow Target=Linked Ref with SeverActions_EscortTargetKeyword}

Package Property SeverActions_JailSandbox Auto
{Sandbox package for prisoners in jail - sandboxes near their linked ref (jail marker)}

; =============================================================================
; PROPERTIES - Items & Outfits (Vanilla or Create in CK)
; =============================================================================

Armor Property SeverActions_PrisonerCuffs Auto
{Bound hands armor item. Can use vanilla or create custom.}

Armor Property SeverActions_PrisonerRags Auto
{Prison clothing. Can use vanilla ClothesJailor or create custom.}

Outfit Property SeverActions_PrisonerOutfit Auto
{Outfit containing prison clothes. Setting this on the NPC makes it persist through cell reloads.
Create an Outfit in CK containing the prison rags.}

MiscObject Property Gold001 Auto
{Gold coin - set to Gold001 (0x0000000F) in CK, or leave empty for auto-lookup}

; =============================================================================
; PROPERTIES - Idle Animation (Vanilla)
; =============================================================================

Idle Property OffsetBoundStandingStart Auto
{Vanilla idle for bound standing pose}

Idle Property IdleGive Auto
{Vanilla idle for give/hand-over gesture - used when freeing prisoners}

; =============================================================================
; PROPERTIES - Jail Markers (Interior cell XMarkers - must set in CK)
; The faction's crimeData.factionJailMarker is an EXTERIOR marker (where player
; teleports when choosing jail), not the actual cell interior. These must be
; placed manually inside each jail cell.
; =============================================================================

ObjectReference Property JailMarker_Whiterun Auto
{XMarker inside Dragonsreach Dungeon jail cell}

ObjectReference Property JailMarker_Riften Auto
{XMarker inside Riften Jail cell}

ObjectReference Property JailMarker_Solitude Auto
{XMarker inside Castle Dour Dungeon cell}

ObjectReference Property JailMarker_Windhelm Auto
{XMarker inside Windhelm Bloodworks jail cell}

ObjectReference Property JailMarker_Markarth Auto
{XMarker inside Cidhna Mine}

ObjectReference Property JailMarker_Falkreath Auto
{XMarker inside Falkreath Jail cell}

ObjectReference Property JailMarker_Dawnstar Auto
{XMarker inside Dawnstar Barracks jail cell}

ObjectReference Property JailMarker_Morthal Auto
{XMarker inside Morthal Guardhouse jail cell}

ObjectReference Property JailMarker_Winterhold Auto
{XMarker inside The Chill}

; =============================================================================
; PROPERTIES - Reference Aliases (Create in Quest)
; =============================================================================

ReferenceAlias Property ArrestTarget Auto
{Reference alias for the NPC being approached/arrested. Guard approach package targets this.}

ReferenceAlias Property JailDestination Auto
{Reference alias for the jail marker. Guard escort package targets this.}

ReferenceAlias Property ArrestingGuard Auto
{Reference alias for the guard performing the arrest. Prisoner follow package targets this.}

; =============================================================================
; PROPERTIES - Settings
; =============================================================================

Float Property ApproachDistance = 150.0 Auto
{Distance guard needs to be from target to perform arrest}

Float Property ArrivalDistance = 500.0 Auto
{Distance to consider guard arrived at jail}

Float Property UpdateInterval = 1.0 Auto
{How often to check progress (seconds)}

Int Property PackagePriority = 100 Auto
{Priority for arrest packages}

Bool Property EnableDebugMessages = true Auto
{Show debug notifications in-game}

Bool Property DisablePrisonerOnArrival = false Auto
{If true, disable prisoner after jailing. If false, they sandbox in jail (recommended).}

; =============================================================================
; PROPERTIES - Player Arrest Settings
; =============================================================================

Int Property ArrestBountyThreshold = 300 Auto
{Minimum bounty required for arrest option. Below this, guard demands fine payment only.}

Float Property BribeMultiplier = 1.5 Auto
{Multiplier for bribe cost (bounty * multiplier)}

Float Property PersuasionTimeLimit = 90.0 Auto
{Time in seconds player has to convince guard during persuasion}

Float Property PersuasionFollowDistance = 300.0 Auto
{Max distance guard will follow player during persuasion before giving up}

Int Property ResistBountyIncrease = 500 Auto
{Additional bounty added when player resists arrest}

Float Property ArrestPlayerCooldown = 60.0 Auto
{Cooldown in seconds before ArrestPlayer can be used again after a confrontation starts}

Package Property SeverActions_GuardFollowPlayer Auto
{Follow package for guard during persuasion - follows linked ref (player).
Setup: Type=Follow, Follow Target=Linked Ref with SeverActions_EscortTargetKeyword}

; =============================================================================
; STATE TRACKING
; =============================================================================

; Active arrest tracking (supports one arrest at a time for simplicity)
Actor CurrentGuard
Actor CurrentPrisoner
ObjectReference CurrentJailMarker
String CurrentJailName
Int ArrestState ; 0=none, 1=approaching, 2=arresting, 3=escorting, 4=arrived

; Jailed NPC tracking (for freeing later)
Actor[] JailedNPCs

; Player arrest state tracking
Actor ConfrontingGuard          ; Guard currently confronting player
Faction ConfrontingFaction      ; Crime faction for current confrontation
Int ConfrontingBounty           ; Bounty amount at time of confrontation
Bool PersuadeAttempted          ; True if player already tried persuade (can't retry)
Bool PaymentFailed              ; True if player tried to pay/bribe but couldn't afford it
Bool InPersuasionMode           ; True if currently in persuasion conversation
Float PersuasionStartTime       ; Game time when persuasion started
Float LastArrestTime            ; Real time when last arrest confrontation started (for cooldown)
Float LastNPCArrestTime         ; Real time when last NPC arrest started (for cooldown)

; MessageBox tracking
Int PlayerArrestMenuID          ; Menu ID for player arrest messagebox

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Arrest] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    {Auto-lookup Gold001 if not set in CK, register for game load events}
    if Gold001 == None
        Gold001 = Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as MiscObject
        if Gold001 == None
            Debug.Trace("[SeverActions_Arrest] ERROR: Could not find Gold001!")
        else
            Debug.Trace("[SeverActions_Arrest] Gold001 found via auto-lookup")
        endif
    endif

    ; Register for game load event to verify prisoner positions
    RegisterForModEvent("OnPlayerLoadGame", "OnPlayerLoadGame")

    ; Register for player cell change to verify prisoners after fast travel
    RegisterForTrackedStatsEvent()
EndFunction

Event OnPlayerLoadGame()
    {Called when player loads a saved game. Verify all jailed NPCs are in position.}
    Debug.Trace("[SeverActions_Arrest] Game loaded - verifying prisoner positions")
    VerifyJailedNPCs()
EndEvent

Event OnTrackedStatsEvent(String asStat, Int aiValue)
    {Use tracked stats as proxy for game activity - verify on location discovery or fast travel count changes}
    If asStat == "Locations Discovered" || asStat == "Days Passed"
        ; Verify prisoner positions after fast travel/time passage
        VerifyJailedNPCs()
    EndIf
EndEvent

; =============================================================================
; MAIN API - ArrestNPC
; =============================================================================

Bool Function ArrestNPC_Internal(Actor akGuard, Actor akTarget)
    {Main arrest function called by SkyrimNet action.
     Guard will walk up to target, arrest them, then escort to jail.
     Returns true if arrest sequence started successfully.}

    ; Validate inputs
    If akGuard == None
        DebugMsg("ERROR: ArrestNPC called with None guard")
        Return false
    EndIf

    If akTarget == None
        DebugMsg("ERROR: ArrestNPC called with None target")
        Return false
    EndIf

    If akTarget == Game.GetPlayer()
        DebugMsg("ERROR: Cannot arrest player with this function - use ArrestPlayer")
        Return false
    EndIf

    If akGuard.IsDead() || akTarget.IsDead()
        DebugMsg("ERROR: Guard or target is dead")
        Return false
    EndIf

    ; Check cooldown (300 seconds / 5 minutes)
    Float currentTime = Utility.GetCurrentRealTime()
    If (currentTime - LastNPCArrestTime) < 300.0
        DebugMsg("ArrestNPC on cooldown, ignoring (" + (300.0 - (currentTime - LastNPCArrestTime)) + "s remaining)")
        Return false
    EndIf

    ; Check if already processing an arrest
    If ArrestState != 0
        DebugMsg("WARNING: Already processing an arrest, canceling previous")
        CancelCurrentArrest()
    EndIf

    ; Determine jail destination based on guard's crime faction
    ObjectReference jailMarker = GetJailMarkerForGuard(akGuard)
    String jailName = GetJailNameForGuard(akGuard)

    If jailMarker == None
        DebugMsg("ERROR: Could not determine jail marker for guard - check properties!")
        Return false
    EndIf

    DebugMsg("Starting arrest: " + akGuard.GetDisplayName() + " arresting " + akTarget.GetDisplayName())
    DebugMsg("Destination: " + jailName)

    ; Store state
    CurrentGuard = akGuard
    CurrentPrisoner = akTarget
    CurrentJailMarker = jailMarker
    CurrentJailName = jailName
    ArrestState = 1 ; approaching
    LastNPCArrestTime = Utility.GetCurrentRealTime() ; Set cooldown timer

    ; Draw weapon initially (packages may override this - see CK package flags)
    akGuard.DrawWeapon()

    ; Check if already close enough
    Float dist = akGuard.GetDistance(akTarget)
    If dist <= ApproachDistance
        ; Already close, skip approach phase
        DebugMsg("Guard already close to target, proceeding to arrest")
        PerformArrest()
    Else
        ; Start approach phase
        DebugMsg("Guard approaching target (distance: " + dist + ")")
        StartApproachPhase()
    EndIf

    Return true
EndFunction

; =============================================================================
; APPROACH PHASE - Guard walks to target
; =============================================================================

Function StartApproachPhase()
    {Guard walks toward target with weapon drawn}

    If CurrentGuard == None || CurrentPrisoner == None
        DebugMsg("ERROR: StartApproachPhase - invalid state")
        Return
    EndIf

    ; Fill reference aliases for approach
    ArrestTarget.ForceRefTo(CurrentPrisoner)
    ArrestingGuard.ForceRefTo(CurrentGuard)

    DebugMsg("Filled ArrestTarget alias with: " + CurrentPrisoner.GetDisplayName())

    ; Apply approach package to guard (targets ArrestTarget alias)
    If SeverActions_ApproachTarget
        ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_ApproachTarget, PackagePriority, 1)
        CurrentGuard.EvaluatePackage()
        DebugMsg("Applied approach package to guard")
    Else
        DebugMsg("WARNING: No approach package defined!")
    EndIf

    ; Start monitoring for arrival
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Event OnUpdate()
    ; Check current state and act accordingly

    ; NPC arrest states
    If ArrestState == 1
        ; Approaching target
        CheckApproachProgress()
    ElseIf ArrestState == 3
        ; Escorting to jail
        CheckEscortProgress()
    EndIf

    ; Player persuasion mode
    If InPersuasionMode
        CheckPersuasionProgress()
    EndIf
EndEvent

Function CheckApproachProgress()
    {Check if guard has reached the target}

    If CurrentGuard == None || CurrentPrisoner == None
        DebugMsg("ERROR: CheckApproachProgress - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ; Check if guard or prisoner died
    If CurrentGuard.IsDead()
        DebugMsg("Guard died during approach")
        CancelCurrentArrest()
        Return
    EndIf

    If CurrentPrisoner.IsDead()
        DebugMsg("Target died during approach")
        CancelCurrentArrest()
        Return
    EndIf

    Float dist = CurrentGuard.GetDistance(CurrentPrisoner)

    If dist <= ApproachDistance
        ; Arrived at target - perform arrest
        DebugMsg("Guard reached target, performing arrest")

        ; Remove approach package
        If SeverActions_ApproachTarget
            ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_ApproachTarget)
        EndIf

        PerformArrest()
    Else
        ; Still approaching, keep checking
        RegisterForSingleUpdate(UpdateInterval)
    EndIf
EndFunction

; =============================================================================
; ARREST PHASE - Subdue and restrain target
; =============================================================================

Function PerformArrest()
    {Actually arrest the target - pacify, cuff, prepare for escort}

    If CurrentGuard == None || CurrentPrisoner == None
        DebugMsg("ERROR: PerformArrest - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ArrestState = 2 ; arresting

    Actor prisoner = CurrentPrisoner
    Actor guard = CurrentGuard

    DebugMsg("Performing arrest on " + prisoner.GetDisplayName())

    ; Stop any combat
    prisoner.StopCombat()
    prisoner.StopCombatAlarm()

    ; Pacify the prisoner
    prisoner.SetAV("Aggression", 0)
    prisoner.SetAV("Confidence", 0)

    ; Add to factions
    prisoner.AddToFaction(dunPrisonerFaction)      ; Guards won't attack
    prisoner.AddToFaction(SeverActions_Arrested)   ; Triggers follow package

    ; Equip restraints
    If SeverActions_PrisonerCuffs
        prisoner.EquipItem(SeverActions_PrisonerCuffs, true, true) ; abPreventRemoval, abSilent
    EndIf

    ; Play bound idle animation
    If OffsetBoundStandingStart
        prisoner.PlayIdle(OffsetBoundStandingStart)
    EndIf

    ; Reduce healing so they stay subdued
    prisoner.SetAV("HealRate", 0.1)

    ; Link prisoner to guard so follow package works
    PO3_SKSEFunctions.SetLinkedRef(prisoner, guard, SeverActions_EscortTargetKeyword)
    DebugMsg("Linked prisoner to guard for follow")

    ; Apply follow package to prisoner
    If SeverActions_PrisonerFollow
        ActorUtil.AddPackageOverride(prisoner, SeverActions_PrisonerFollow, PackagePriority, 1)
        prisoner.EvaluatePackage()
        DebugMsg("Applied follow package to prisoner")
    EndIf

    ; Notification
    Debug.Notification(guard.GetDisplayName() + " arrested " + prisoner.GetDisplayName())

    ; Direct narration for prisoner to react to being arrested
    String narration = "*" + guard.GetDisplayName() + " places " + prisoner.GetDisplayName() + " under arrest and binds their hands.*"
    SkyrimNetApi.DirectNarration(narration, prisoner, guard)

    ; Register persistent event for SkyrimNet - guard arrested prisoner
    String arrestMessage = guard.GetDisplayName() + " has arrested " + prisoner.GetDisplayName() + " and is escorting them to " + CurrentJailName + "."
    SkyrimNetApi.RegisterPersistentEvent(arrestMessage, guard, None)

    ; Small delay for animations/packages to settle
    Utility.Wait(1.0)

    ; Start escort phase
    StartEscortPhase()
EndFunction

; =============================================================================
; ESCORT PHASE - Guard travels to jail, prisoner follows
; =============================================================================

Function StartEscortPhase()
    {Guard travels to jail with prisoner following via separate packages}

    If CurrentGuard == None || CurrentPrisoner == None || CurrentJailMarker == None
        DebugMsg("ERROR: StartEscortPhase - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ArrestState = 3 ; escorting

    Debug.Notification(CurrentGuard.GetDisplayName() + " is escorting " + CurrentPrisoner.GetDisplayName() + " to " + CurrentJailName)
    DebugMsg("Starting escort to " + CurrentJailName)

    ; Fill JailDestination alias with the jail marker
    JailDestination.ForceRefTo(CurrentJailMarker)
    DebugMsg("Filled JailDestination alias with: " + CurrentJailMarker)

    ; Apply travel package to guard (targets JailDestination alias)
    If SeverActions_GuardEscortToJail
        ActorUtil.AddPackageOverride(CurrentGuard, SeverActions_GuardEscortToJail, PackagePriority, 1)
        CurrentGuard.EvaluatePackage()
        DebugMsg("Applied travel package to guard")
    Else
        DebugMsg("WARNING: No guard travel package defined!")
    EndIf

    ; Start monitoring for arrival
    RegisterForSingleUpdate(UpdateInterval)
EndFunction

Function CheckEscortProgress()
    {Check if guard has arrived at jail}

    If CurrentGuard == None || CurrentPrisoner == None || CurrentJailMarker == None
        DebugMsg("ERROR: CheckEscortProgress - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ; Check if guard or prisoner died during escort
    If CurrentGuard.IsDead()
        DebugMsg("Guard died during escort")
        ReleasePrisoner(CurrentPrisoner)
        CancelCurrentArrest()
        Return
    EndIf

    If CurrentPrisoner.IsDead()
        DebugMsg("Prisoner died during escort")
        CancelCurrentArrest()
        Return
    EndIf

    ; Check distance to jail marker
    Float dist = CurrentGuard.GetDistance(CurrentJailMarker)

    If dist <= ArrivalDistance
        ; Arrived at jail
        DebugMsg("Guard arrived at jail (distance: " + dist + ")")
        OnArrivedAtJail()
    Else
        ; Still traveling
        RegisterForSingleUpdate(UpdateInterval)
    EndIf
EndFunction

; =============================================================================
; ARRIVAL - Process prisoner at jail
; =============================================================================

Function OnArrivedAtJail()
    {Guard and prisoner have arrived at jail - finalize arrest}

    If CurrentGuard == None || CurrentPrisoner == None
        DebugMsg("ERROR: OnArrivedAtJail - invalid state")
        CancelCurrentArrest()
        Return
    EndIf

    ArrestState = 4 ; arrived

    ; Store local references before clearing state
    Actor prisoner = CurrentPrisoner
    Actor guard = CurrentGuard
    ObjectReference jailMarker = CurrentJailMarker
    String jailName = CurrentJailName

    DebugMsg("Processing prisoner at jail: " + prisoner.GetDisplayName())

    ; Remove guard's travel package
    If SeverActions_GuardEscortToJail
        ActorUtil.RemovePackageOverride(guard, SeverActions_GuardEscortToJail)
    EndIf

    ; Remove prisoner's follow package
    If SeverActions_PrisonerFollow
        ActorUtil.RemovePackageOverride(prisoner, SeverActions_PrisonerFollow)
    EndIf

    ; Clear prisoner's linked ref to guard (was used for follow)
    PO3_SKSEFunctions.SetLinkedRef(prisoner, None, SeverActions_EscortTargetKeyword)

    ; Clear reference aliases
    ArrestTarget.Clear()
    JailDestination.Clear()
    ArrestingGuard.Clear()

    ; Update factions
    prisoner.RemoveFromFaction(SeverActions_Arrested)
    prisoner.AddToFaction(SeverActions_Jailed)

    ; Move prisoner to jail cell with verification
    ; MoveTo can fail silently when player is in a different cell
    If jailMarker
        ; First attempt
        prisoner.MoveTo(jailMarker, 0.0, 0.0, 0.0)
        Utility.Wait(0.5)

        ; Verify the move worked - check if prisoner is near the jail marker
        Float distToJail = prisoner.GetDistance(jailMarker)
        Int attempts = 1

        ; If prisoner is too far from jail marker, retry the teleport
        While distToJail > 500.0 && attempts < 5
            DebugMsg("MoveTo failed (distance: " + distToJail + "), retrying attempt " + (attempts + 1))

            ; Try disabling and re-enabling to force cell load
            prisoner.Disable()
            Utility.Wait(0.1)
            prisoner.MoveTo(jailMarker, 0.0, 0.0, 0.0)
            Utility.Wait(0.1)
            prisoner.Enable()
            Utility.Wait(0.5)

            distToJail = prisoner.GetDistance(jailMarker)
            attempts += 1
        EndWhile

        If distToJail <= 500.0
            DebugMsg("Moved prisoner to jail marker (distance: " + distToJail + ", attempts: " + attempts + ")")
        Else
            DebugMsg("WARNING: Failed to move prisoner to jail after " + attempts + " attempts (distance: " + distToJail + ")")
        EndIf
    EndIf

    ; Change to prison clothes (use faction's jail outfit if available)
    Faction crimeFaction = GetCrimeFactionForGuard(guard)
    ChangeToJailClothes(prisoner, crimeFaction)

    ; Track this jailed NPC and store their jail marker for verification later
    AddJailedNPC(prisoner)
    StorageUtil.SetFormValue(prisoner, "SeverActions_JailMarker", jailMarker)

    If DisablePrisonerOnArrival
        ; Simple approach: just disable the prisoner
        ; They're "in jail" but removed from the world
        Utility.Wait(0.5)
        prisoner.Disable()
        DebugMsg("Prisoner disabled (jailed)")
    Else
        ; Keep prisoner active with sandbox package
        If SeverActions_JailSandbox && jailMarker
            ; Link prisoner to their jail marker for sandbox (per-actor, supports multiple prisoners)
            PO3_SKSEFunctions.SetLinkedRef(prisoner, jailMarker, SeverActions_EscortTargetKeyword)
            ActorUtil.AddPackageOverride(prisoner, SeverActions_JailSandbox, PackagePriority + 10, 1)
            prisoner.EvaluatePackage()
            DebugMsg("Prisoner sandboxing in jail (linked to marker)")
        Else
            ; No sandbox package - prisoner may wander
            DebugMsg("WARNING: No jail sandbox package or marker - prisoner may escape!")
            prisoner.EvaluatePackage()
        EndIf
    EndIf

    ; Guard sheathes weapon and returns to normal
    guard.SheatheWeapon()
    guard.EvaluatePackage()

    ; Direct narration for prisoner to react to being put in the cell
    String cellNarration = "*" + guard.GetDisplayName() + " locks " + prisoner.GetDisplayName() + " in a jail cell.*"
    SkyrimNetApi.DirectNarration(cellNarration, prisoner, guard)

    ; Register persistent event for SkyrimNet - prisoner delivered to jail
    String jailMessage = prisoner.GetDisplayName() + " has been jailed in " + jailName + "."
    SkyrimNetApi.RegisterPersistentEvent(jailMessage, prisoner, None)

    ; Clear state (do this last since we stored local copies)
    ClearArrestState()

    Debug.Notification(prisoner.GetDisplayName() + " has been jailed")
    DebugMsg("Arrest complete - prisoner delivered to " + jailName)
EndFunction

Function ChangeToJailClothes(Actor akPrisoner, Faction akCrimeFaction)
    {Strip prisoner and give them jail clothes using SetOutfit for persistence.
     Uses the faction's jail outfit if available, falls back to property.}

    ; Remove cuffs (they're in jail now)
    If SeverActions_PrisonerCuffs
        akPrisoner.UnequipItem(SeverActions_PrisonerCuffs, false, true)
        akPrisoner.RemoveItem(SeverActions_PrisonerCuffs, 1, true)
    EndIf

    ; Try to get the faction's jail outfit first (from crime data)
    Outfit jailOutfit = None
    If akCrimeFaction
        jailOutfit = SeverActionsNative.GetFactionJailOutfit(akCrimeFaction)
        If jailOutfit
            DebugMsg("Using faction jail outfit for " + akCrimeFaction.GetName())
        EndIf
    EndIf

    ; Fall back to property if faction has no outfit
    If !jailOutfit
        jailOutfit = SeverActions_PrisonerOutfit
    EndIf

    ; Set prisoner outfit - this persists through cell reloads
    If jailOutfit
        ; Store the original outfit so we can restore it when freed
        ; Uses StorageUtil to track per-actor data
        Outfit originalOutfit = akPrisoner.GetActorBase().GetOutfit()
        If originalOutfit
            StorageUtil.SetFormValue(akPrisoner, "SeverActions_OriginalOutfit", originalOutfit)
            DebugMsg("Stored original outfit for " + akPrisoner.GetDisplayName())
        EndIf

        akPrisoner.SetOutfit(jailOutfit)
        DebugMsg("Set prisoner outfit on " + akPrisoner.GetDisplayName())
    ElseIf SeverActions_PrisonerRags
        ; Fallback: just equip the armor directly (won't persist)
        akPrisoner.UnequipAll()
        akPrisoner.EquipItem(SeverActions_PrisonerRags, false, true)
        DebugMsg("WARNING: No jail outfit available, using direct equip (won't persist)")
    EndIf
EndFunction

; =============================================================================
; JAIL LOOKUP - Determine jail from guard's crime faction
; =============================================================================

ObjectReference Function GetJailMarkerForGuard(Actor akGuard)
    {Get the interior jail cell marker based on guard's crime faction}

    If akGuard.IsInFaction(CrimeFactionWhiterun)
        Return JailMarker_Whiterun
    ElseIf akGuard.IsInFaction(CrimeFactionRift)
        Return JailMarker_Riften
    ElseIf akGuard.IsInFaction(CrimeFactionHaafingar)
        Return JailMarker_Solitude
    ElseIf akGuard.IsInFaction(CrimeFactionEastmarch)
        Return JailMarker_Windhelm
    ElseIf akGuard.IsInFaction(CrimeFactionReach)
        Return JailMarker_Markarth
    ElseIf akGuard.IsInFaction(CrimeFactionFalkreath)
        Return JailMarker_Falkreath
    ElseIf akGuard.IsInFaction(CrimeFactionPale)
        Return JailMarker_Dawnstar
    ElseIf akGuard.IsInFaction(CrimeFactionHjaalmarch)
        Return JailMarker_Morthal
    ElseIf akGuard.IsInFaction(CrimeFactionWinterhold)
        Return JailMarker_Winterhold
    EndIf

    ; Default to Whiterun
    DebugMsg("WARNING: Could not determine guard's hold, defaulting to Whiterun")
    Return JailMarker_Whiterun
EndFunction

String Function GetJailNameForGuard(Actor akGuard)
    {Get human-readable jail name for notifications}

    If akGuard.IsInFaction(CrimeFactionWhiterun)
        Return "Dragonsreach Dungeon"
    ElseIf akGuard.IsInFaction(CrimeFactionRift)
        Return "Riften Jail"
    ElseIf akGuard.IsInFaction(CrimeFactionHaafingar)
        Return "Castle Dour Dungeon"
    ElseIf akGuard.IsInFaction(CrimeFactionEastmarch)
        Return "Windhelm Jail"
    ElseIf akGuard.IsInFaction(CrimeFactionReach)
        Return "Cidhna Mine"
    ElseIf akGuard.IsInFaction(CrimeFactionFalkreath)
        Return "Falkreath Jail"
    ElseIf akGuard.IsInFaction(CrimeFactionPale)
        Return "Dawnstar Jail"
    ElseIf akGuard.IsInFaction(CrimeFactionHjaalmarch)
        Return "Morthal Jail"
    ElseIf akGuard.IsInFaction(CrimeFactionWinterhold)
        Return "The Chill"
    EndIf

    Return "jail"
EndFunction

; =============================================================================
; CANCEL / CLEANUP
; =============================================================================

Function CancelCurrentArrest()
    {Cancel the current arrest in progress}

    DebugMsg("Canceling current arrest")

    If CurrentGuard
        ; Remove guard packages
        If SeverActions_ApproachTarget
            ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_ApproachTarget)
        EndIf
        If SeverActions_GuardEscortToJail
            ActorUtil.RemovePackageOverride(CurrentGuard, SeverActions_GuardEscortToJail)
        EndIf
        CurrentGuard.SheatheWeapon()
        CurrentGuard.EvaluatePackage()
    EndIf

    If CurrentPrisoner && ArrestState >= 2
        ; Prisoner was already arrested, release them
        ReleasePrisoner(CurrentPrisoner)
    EndIf

    ; Clear reference aliases
    ArrestTarget.Clear()
    JailDestination.Clear()
    ArrestingGuard.Clear()

    ClearArrestState()
EndFunction

Function ReleasePrisoner(Actor akPrisoner)
    {Release a prisoner - remove restraints and factions}

    If akPrisoner == None
        Return
    EndIf

    DebugMsg("Releasing prisoner: " + akPrisoner.GetDisplayName())

    ; Remove factions
    akPrisoner.RemoveFromFaction(SeverActions_WaitingArrest)
    akPrisoner.RemoveFromFaction(SeverActions_Arrested)
    akPrisoner.RemoveFromFaction(SeverActions_Jailed)
    akPrisoner.RemoveFromFaction(dunPrisonerFaction)

    ; Remove restraints
    If SeverActions_PrisonerCuffs
        akPrisoner.UnequipItem(SeverActions_PrisonerCuffs, false, true)
        akPrisoner.RemoveItem(SeverActions_PrisonerCuffs, 1, true)
    EndIf

    ; Remove any packages
    If SeverActions_PrisonerFollow
        ActorUtil.RemovePackageOverride(akPrisoner, SeverActions_PrisonerFollow)
    EndIf
    If SeverActions_JailSandbox
        ActorUtil.RemovePackageOverride(akPrisoner, SeverActions_JailSandbox)
    EndIf

    ; Clear any linked ref (guard or jail marker)
    PO3_SKSEFunctions.SetLinkedRef(akPrisoner, None, SeverActions_EscortTargetKeyword)

    ; Restore normal behavior (they may become hostile again)
    akPrisoner.RestoreAV("HealRate", 100)
    akPrisoner.EvaluatePackage()
EndFunction

Function ClearArrestState()
    {Clear all tracking state}

    CurrentGuard = None
    CurrentPrisoner = None
    CurrentJailMarker = None
    CurrentJailName = ""
    ArrestState = 0

    UnregisterForUpdate()
EndFunction

; =============================================================================
; BOUNTY API - Add bounty to player
; =============================================================================

Function AddBountyToPlayer_Internal(Actor akGuard, Int bountyAmount, String crimeType)
    {Guard adds bounty to player for observed crime.
     Uses tracked bounty system instead of vanilla crime gold to prevent
     vanilla guard arrest dialogue from triggering.
     crimeType: "assault", "theft", "murder", "trespass", "pickpocket"}

    If akGuard == None
        DebugMsg("ERROR: AddBountyToPlayer called with None guard")
        Return
    EndIf

    If bountyAmount <= 0
        DebugMsg("ERROR: Invalid bounty amount")
        Return
    EndIf

    ; Determine which crime faction based on guard
    Faction crimeFaction = GetCrimeFactionForGuard(akGuard)

    If crimeFaction == None
        DebugMsg("WARNING: Could not determine guard's crime faction")
        Return
    EndIf

    ; Add to tracked bounty (NOT vanilla crime gold - keeps vanilla at 0)
    ModTrackedBounty(crimeFaction, bountyAmount)

    String holdName = GetHoldNameForGuard(akGuard)
    Int totalBounty = GetTrackedBounty(crimeFaction)
    DebugMsg("Added " + bountyAmount + " tracked bounty for " + crimeType + " in " + holdName + " (total: " + totalBounty + ")")
    Debug.Notification("Bounty added: " + bountyAmount + " gold in " + holdName)

    ; Register persistent event so NPCs remember this crime
    String eventMsg = akGuard.GetDisplayName() + " witnessed the player commit " + crimeType + " and added " + bountyAmount + " gold to their bounty in " + holdName + ". Total bounty is now " + totalBounty + " gold."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, Game.GetPlayer())
EndFunction

Faction Function GetCrimeFactionForGuard(Actor akGuard)
    {Get the crime faction the guard belongs to}

    If akGuard.IsInFaction(CrimeFactionWhiterun)
        Return CrimeFactionWhiterun
    ElseIf akGuard.IsInFaction(CrimeFactionRift)
        Return CrimeFactionRift
    ElseIf akGuard.IsInFaction(CrimeFactionHaafingar)
        Return CrimeFactionHaafingar
    ElseIf akGuard.IsInFaction(CrimeFactionEastmarch)
        Return CrimeFactionEastmarch
    ElseIf akGuard.IsInFaction(CrimeFactionReach)
        Return CrimeFactionReach
    ElseIf akGuard.IsInFaction(CrimeFactionFalkreath)
        Return CrimeFactionFalkreath
    ElseIf akGuard.IsInFaction(CrimeFactionPale)
        Return CrimeFactionPale
    ElseIf akGuard.IsInFaction(CrimeFactionHjaalmarch)
        Return CrimeFactionHjaalmarch
    ElseIf akGuard.IsInFaction(CrimeFactionWinterhold)
        Return CrimeFactionWinterhold
    EndIf

    Return None
EndFunction

String Function GetHoldNameForGuard(Actor akGuard)
    {Get hold name for notifications}

    If akGuard.IsInFaction(CrimeFactionWhiterun)
        Return "Whiterun"
    ElseIf akGuard.IsInFaction(CrimeFactionRift)
        Return "The Rift"
    ElseIf akGuard.IsInFaction(CrimeFactionHaafingar)
        Return "Haafingar"
    ElseIf akGuard.IsInFaction(CrimeFactionEastmarch)
        Return "Eastmarch"
    ElseIf akGuard.IsInFaction(CrimeFactionReach)
        Return "The Reach"
    ElseIf akGuard.IsInFaction(CrimeFactionFalkreath)
        Return "Falkreath"
    ElseIf akGuard.IsInFaction(CrimeFactionPale)
        Return "The Pale"
    ElseIf akGuard.IsInFaction(CrimeFactionHjaalmarch)
        Return "Hjaalmarch"
    ElseIf akGuard.IsInFaction(CrimeFactionWinterhold)
        Return "Winterhold"
    EndIf

    Return "unknown hold"
EndFunction

; =============================================================================
; UTILITY
; =============================================================================

Function DebugMsg(String msg)
    Debug.Trace("SeverArrest: " + msg)
    If EnableDebugMessages
        Debug.Notification("Arrest: " + msg)
    EndIf
EndFunction

; =============================================================================
; TRACKED BOUNTY SYSTEM
; Stores bounty separately from vanilla crime gold to prevent vanilla guard
; arrest dialogue from triggering. Vanilla crime gold stays at 0.
; =============================================================================

String Function GetBountyStorageKey(Faction akCrimeFaction)
    {Get the StorageUtil key for a crime faction's tracked bounty}

    If akCrimeFaction == CrimeFactionWhiterun
        Return "SeverActions_Bounty_Whiterun"
    ElseIf akCrimeFaction == CrimeFactionRift
        Return "SeverActions_Bounty_Rift"
    ElseIf akCrimeFaction == CrimeFactionHaafingar
        Return "SeverActions_Bounty_Haafingar"
    ElseIf akCrimeFaction == CrimeFactionEastmarch
        Return "SeverActions_Bounty_Eastmarch"
    ElseIf akCrimeFaction == CrimeFactionReach
        Return "SeverActions_Bounty_Reach"
    ElseIf akCrimeFaction == CrimeFactionFalkreath
        Return "SeverActions_Bounty_Falkreath"
    ElseIf akCrimeFaction == CrimeFactionPale
        Return "SeverActions_Bounty_Pale"
    ElseIf akCrimeFaction == CrimeFactionHjaalmarch
        Return "SeverActions_Bounty_Hjaalmarch"
    ElseIf akCrimeFaction == CrimeFactionWinterhold
        Return "SeverActions_Bounty_Winterhold"
    EndIf

    Return ""
EndFunction

Int Function GetTrackedBounty(Faction akCrimeFaction)
    {Get the tracked bounty for a crime faction (not vanilla crime gold)}

    String storageKey = GetBountyStorageKey(akCrimeFaction)
    If storageKey == ""
        Return 0
    EndIf

    Return StorageUtil.GetIntValue(Game.GetPlayer(), storageKey, 0)
EndFunction

Function SetTrackedBounty(Faction akCrimeFaction, Int aiAmount)
    {Set the tracked bounty for a crime faction}

    String storageKey = GetBountyStorageKey(akCrimeFaction)
    If storageKey == ""
        Return
    EndIf

    If aiAmount <= 0
        StorageUtil.UnsetIntValue(Game.GetPlayer(), storageKey)
    Else
        StorageUtil.SetIntValue(Game.GetPlayer(), storageKey, aiAmount)
    EndIf
EndFunction

Function ModTrackedBounty(Faction akCrimeFaction, Int aiAmount)
    {Add to (or subtract from) the tracked bounty for a crime faction}

    Int current = GetTrackedBounty(akCrimeFaction)
    SetTrackedBounty(akCrimeFaction, current + aiAmount)
EndFunction

Function ClearTrackedBounty(Faction akCrimeFaction)
    {Clear the tracked bounty for a crime faction}

    SetTrackedBounty(akCrimeFaction, 0)
EndFunction

Function ApplyTrackedBountyToVanilla(Faction akCrimeFaction)
    {Transfer tracked bounty to vanilla crime gold (for jail/combat)}

    Int bounty = GetTrackedBounty(akCrimeFaction)
    If bounty > 0
        akCrimeFaction.SetCrimeGold(bounty)
        ClearTrackedBounty(akCrimeFaction)
        DebugMsg("Applied " + bounty + " tracked bounty to vanilla system")
    EndIf
EndFunction

Int Function GetTrackedBountyForGuard(Actor akGuard)
    {Get the tracked bounty for the hold a guard belongs to}

    Faction crimeFaction = GetCrimeFactionForGuard(akGuard)
    If crimeFaction
        Return GetTrackedBounty(crimeFaction)
    EndIf
    Return 0
EndFunction

; =============================================================================
; FREE NPC API - Release jailed NPCs
; =============================================================================

Bool Function FreeNPC_Internal(Actor akGuard, Actor akTarget)
    {Free a jailed NPC. Guard will approach and release the prisoner.
     Called by SkyrimNet FreeNPC action.
     akGuard: The guard or authority figure doing the freeing
     akTarget: The jailed NPC to free}

    If akGuard == None
        DebugMsg("ERROR: FreeNPC called with None guard")
        Return false
    EndIf

    If akTarget == None
        DebugMsg("ERROR: FreeNPC called with None target")
        Return false
    EndIf

    ; Check if this NPC is actually jailed
    If !akTarget.IsInFaction(SeverActions_Jailed)
        DebugMsg("ERROR: " + akTarget.GetDisplayName() + " is not jailed")
        Return false
    EndIf

    DebugMsg(akGuard.GetDisplayName() + " is freeing prisoner: " + akTarget.GetDisplayName())

    ; Re-enable prisoner if disabled
    If akTarget.IsDisabled()
        akTarget.Enable()
        Utility.Wait(0.5)
    EndIf

    ; Check distance - if guard is far from prisoner, have them approach first
    Float distance = akGuard.GetDistance(akTarget)
    If distance > 200.0
        DebugMsg("Guard approaching prisoner (distance: " + distance + ")")

        ; Link guard to prisoner for approach package
        PO3_SKSEFunctions.SetLinkedRef(akGuard, akTarget, SeverActions_EscortTargetKeyword)

        ; Fill the ArrestTarget alias with the prisoner for the approach package
        ArrestTarget.ForceRefTo(akTarget)

        ; Apply approach package to guard
        If SeverActions_ApproachTarget
            ActorUtil.AddPackageOverride(akGuard, SeverActions_ApproachTarget, PackagePriority, 1)
            akGuard.EvaluatePackage()
        EndIf

        ; Wait for guard to approach (with timeout)
        Float timeout = 15.0
        Float elapsed = 0.0
        While akGuard.GetDistance(akTarget) > 150.0 && elapsed < timeout
            Utility.Wait(0.5)
            elapsed += 0.5
        EndWhile

        ; Remove approach package
        If SeverActions_ApproachTarget
            ActorUtil.RemovePackageOverride(akGuard, SeverActions_ApproachTarget)
        EndIf
        ArrestTarget.Clear()
        PO3_SKSEFunctions.SetLinkedRef(akGuard, None, SeverActions_EscortTargetKeyword)

        DebugMsg("Guard reached prisoner (elapsed: " + elapsed + "s)")
    EndIf

    ; Play give/release gesture animation
    If IdleGive
        akGuard.PlayIdle(IdleGive)
        Utility.Wait(1.5)
    EndIf

    ; Remove from jailed faction
    akTarget.RemoveFromFaction(SeverActions_Jailed)
    akTarget.RemoveFromFaction(dunPrisonerFaction)

    ; Remove jail sandbox package and clear linked ref
    If SeverActions_JailSandbox
        ActorUtil.RemovePackageOverride(akTarget, SeverActions_JailSandbox)
        PO3_SKSEFunctions.SetLinkedRef(akTarget, None, SeverActions_EscortTargetKeyword)
    EndIf

    ; Restore original outfit if we stored one
    Outfit originalOutfit = StorageUtil.GetFormValue(akTarget, "SeverActions_OriginalOutfit") as Outfit
    If originalOutfit
        akTarget.SetOutfit(originalOutfit)
        StorageUtil.UnsetFormValue(akTarget, "SeverActions_OriginalOutfit")
        DebugMsg("Restored original outfit for " + akTarget.GetDisplayName())
    ElseIf SeverActions_PrisonerRags
        ; Fallback: just remove prison rags if no outfit was stored
        akTarget.UnequipItem(SeverActions_PrisonerRags, false, true)
        akTarget.RemoveItem(SeverActions_PrisonerRags, 1, true)
    EndIf

    ; Restore normal stats
    akTarget.RestoreAV("Aggression", 100)
    akTarget.RestoreAV("Confidence", 100)
    akTarget.RestoreAV("HealRate", 100)

    ; Force re-evaluation so prisoner returns to normal AI
    akTarget.EvaluatePackage()
    akGuard.EvaluatePackage()

    ; Remove from tracking
    RemoveJailedNPC(akTarget)

    ; Clear stored jail marker
    StorageUtil.UnsetFormValue(akTarget, "SeverActions_JailMarker")

    ; Direct narration for the release
    String narration = "*" + akGuard.GetDisplayName() + " unlocks the cell door and gestures for " + akTarget.GetDisplayName() + " to leave.* \"You're free to go.\""
    SkyrimNetApi.DirectNarration(narration, akGuard, akTarget)

    Debug.Notification(akTarget.GetDisplayName() + " has been freed from jail")
    DebugMsg("Prisoner freed: " + akTarget.GetDisplayName())

    Return true
EndFunction

Function FreePrisonerDirect(Actor akTarget)
    {Free a prisoner directly without guard approach - used by FreeAllPrisoners.
     Does not play animations or approach, just releases the prisoner immediately.}

    If akTarget == None
        Return
    EndIf

    ; Re-enable prisoner if disabled
    If akTarget.IsDisabled()
        akTarget.Enable()
    EndIf

    ; Remove from jailed faction
    akTarget.RemoveFromFaction(SeverActions_Jailed)
    akTarget.RemoveFromFaction(dunPrisonerFaction)

    ; Remove jail sandbox package and clear linked ref
    If SeverActions_JailSandbox
        ActorUtil.RemovePackageOverride(akTarget, SeverActions_JailSandbox)
        PO3_SKSEFunctions.SetLinkedRef(akTarget, None, SeverActions_EscortTargetKeyword)
    EndIf

    ; Restore original outfit if we stored one
    Outfit originalOutfit = StorageUtil.GetFormValue(akTarget, "SeverActions_OriginalOutfit") as Outfit
    If originalOutfit
        akTarget.SetOutfit(originalOutfit)
        StorageUtil.UnsetFormValue(akTarget, "SeverActions_OriginalOutfit")
    ElseIf SeverActions_PrisonerRags
        akTarget.UnequipItem(SeverActions_PrisonerRags, false, true)
        akTarget.RemoveItem(SeverActions_PrisonerRags, 1, true)
    EndIf

    ; Restore normal stats
    akTarget.RestoreAV("Aggression", 100)
    akTarget.RestoreAV("Confidence", 100)
    akTarget.RestoreAV("HealRate", 100)

    ; Clear stored jail marker
    StorageUtil.UnsetFormValue(akTarget, "SeverActions_JailMarker")

    ; Force re-evaluation
    akTarget.EvaluatePackage()

    DebugMsg("Prisoner freed directly: " + akTarget.GetDisplayName())
EndFunction

Function FreeAllPrisoners()
    {Free all currently jailed NPCs (direct release, no guard approach)}

    If JailedNPCs == None || JailedNPCs.Length == 0
        DebugMsg("No prisoners to free")
        Return
    EndIf

    Int i = JailedNPCs.Length - 1
    While i >= 0
        Actor prisoner = JailedNPCs[i]
        If prisoner != None
            FreePrisonerDirect(prisoner)
        EndIf
        i -= 1
    EndWhile

    ; Clear the array
    JailedNPCs = PapyrusUtil.ActorArray(0)
    DebugMsg("All prisoners freed")
EndFunction

; =============================================================================
; JAILED NPC TRACKING
; =============================================================================

Function AddJailedNPC(Actor akNPC)
    {Add an NPC to the jailed tracking list}

    If akNPC == None
        Return
    EndIf

    ; Initialize array if needed
    If JailedNPCs == None
        JailedNPCs = PapyrusUtil.ActorArray(0)
    EndIf

    ; Check if already tracked
    Int i = 0
    While i < JailedNPCs.Length
        If JailedNPCs[i] == akNPC
            Return ; Already tracked
        EndIf
        i += 1
    EndWhile

    ; Add to array using PapyrusUtil if available, otherwise manual resize
    JailedNPCs = PapyrusUtil.PushActor(JailedNPCs, akNPC)
    DebugMsg("Tracking jailed NPC: " + akNPC.GetDisplayName() + " (total: " + JailedNPCs.Length + ")")
EndFunction

Function RemoveJailedNPC(Actor akNPC)
    {Remove an NPC from the jailed tracking list}

    If akNPC == None || JailedNPCs == None
        Return
    EndIf

    ; Find and remove
    Int i = 0
    While i < JailedNPCs.Length
        If JailedNPCs[i] == akNPC
            JailedNPCs = PapyrusUtil.RemoveActor(JailedNPCs, akNPC)
            DebugMsg("Removed from jailed tracking: " + akNPC.GetDisplayName())
            Return
        EndIf
        i += 1
    EndWhile
EndFunction

Actor[] Function GetJailedNPCs()
    {Get array of all currently jailed NPCs}

    If JailedNPCs == None
        Return PapyrusUtil.ActorArray(0)
    EndIf
    Return JailedNPCs
EndFunction

Int Function GetJailedCount()
    {Get count of jailed NPCs}

    If JailedNPCs == None
        Return 0
    EndIf
    Return JailedNPCs.Length
EndFunction

Bool Function IsNPCJailed(Actor akNPC)
    {Check if an NPC is currently jailed}

    If akNPC == None || JailedNPCs == None
        Return false
    EndIf

    Int i = 0
    While i < JailedNPCs.Length
        If JailedNPCs[i] == akNPC
            Return true
        EndIf
        i += 1
    EndWhile

    Return false
EndFunction

Function VerifyJailedNPCs()
    {Verify all jailed NPCs are actually at their jail markers.
     Called on game load to fix prisoners who got displaced during fast travel or time advancement.}

    If JailedNPCs == None || JailedNPCs.Length == 0
        Return
    EndIf

    DebugMsg("Verifying " + JailedNPCs.Length + " jailed NPCs...")
    Int fixedCount = 0

    Int i = 0
    While i < JailedNPCs.Length
        Actor prisoner = JailedNPCs[i]
        If prisoner != None && !prisoner.IsDead()
            ; Get stored jail marker
            ObjectReference jailMarker = StorageUtil.GetFormValue(prisoner, "SeverActions_JailMarker") as ObjectReference
            If jailMarker != None
                Float distance = prisoner.GetDistance(jailMarker)
                ; If prisoner is more than 500 units from jail marker, teleport them back
                If distance > 500.0
                    DebugMsg("Prisoner " + prisoner.GetDisplayName() + " is " + distance + " units from jail, fixing...")

                    ; Use Disable/Enable/MoveTo pattern for reliable cross-cell teleport
                    prisoner.Disable()
                    Utility.Wait(0.1)
                    prisoner.MoveTo(jailMarker, 0.0, 0.0, 0.0)
                    Utility.Wait(0.1)
                    prisoner.Enable()

                    ; Re-apply jail sandbox package in case it got removed
                    If SeverActions_JailSandbox
                        PO3_SKSEFunctions.SetLinkedRef(prisoner, jailMarker, SeverActions_EscortTargetKeyword)
                        ActorUtil.AddPackageOverride(prisoner, SeverActions_JailSandbox, PackagePriority + 10, 1)
                        prisoner.EvaluatePackage()
                    EndIf

                    fixedCount += 1
                EndIf
            Else
                ; No stored marker - try to re-derive it from their faction
                DebugMsg("WARNING: No stored jail marker for " + prisoner.GetDisplayName())
            EndIf
        EndIf
        i += 1
    EndWhile

    If fixedCount > 0
        DebugMsg("Fixed position of " + fixedCount + " prisoners")
    EndIf
EndFunction

; =============================================================================
; PLAYER ARREST API
; =============================================================================

Bool Function ArrestPlayer_Internal(Actor akGuard)
    {Guard confronts player about their bounty.
     Shows MessageBox with options based on bounty amount.
     Returns true if confrontation started successfully.}

    If akGuard == None
        DebugMsg("ERROR: ArrestPlayer called with None guard")
        Return false
    EndIf

    If akGuard.IsDead()
        DebugMsg("ERROR: Guard is dead")
        Return false
    EndIf

    ; Block if already in an active confrontation (prevents stacking messageboxes)
    If ConfrontingGuard != None
        DebugMsg("Already in confrontation with " + ConfrontingGuard.GetDisplayName() + ", ignoring new arrest request")
        Return false
    EndIf

    ; Check cooldown - prevent spamming arrest during persuasion or shortly after
    Float currentTime = Utility.GetCurrentRealTime()
    If LastArrestTime > 0.0 && (currentTime - LastArrestTime) < ArrestPlayerCooldown
        Float remaining = ArrestPlayerCooldown - (currentTime - LastArrestTime)
        DebugMsg("ArrestPlayer on cooldown, " + remaining + " seconds remaining")
        Return false
    EndIf

    ; Get the crime faction for this guard
    Faction crimeFaction = GetCrimeFactionForGuard(akGuard)
    If crimeFaction == None
        DebugMsg("ERROR: Could not determine guard's crime faction")
        Return false
    EndIf

    ; Get current tracked bounty (not vanilla crime gold which stays at 0)
    Int bounty = GetTrackedBounty(crimeFaction)
    If bounty <= 0
        ; Auto-add 300 bounty if guard is arresting with no existing bounty
        ; This handles cases where ReportCrime wasn't used first
        bounty = 300
        SetTrackedBounty(crimeFaction, bounty)
        String holdName = GetHoldNameForGuard(akGuard)
        DebugMsg("Auto-added " + bounty + " bounty for arrest in " + holdName)
        Debug.Notification("Bounty added: " + bounty + " gold in " + holdName)

        ; Register persistent event so NPCs know about this
        String eventMsg = akGuard.GetDisplayName() + " is arresting the player and added " + bounty + " gold bounty in " + holdName + "."
        SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, Game.GetPlayer())
    EndIf

    ; Check if already in a confrontation
    If ConfrontingGuard != None
        DebugMsg("WARNING: Already in a confrontation, canceling previous")
        CancelPlayerConfrontation()
    EndIf

    ; Store confrontation state
    ConfrontingGuard = akGuard
    ConfrontingFaction = crimeFaction
    ConfrontingBounty = bounty
    LastArrestTime = Utility.GetCurrentRealTime() ; Start cooldown

    String holdName = GetHoldNameForGuard(akGuard)
    DebugMsg("Guard confronting player - Tracked Bounty: " + bounty + " in " + holdName)

    ; Show appropriate MessageBox based on bounty
    ShowPlayerArrestMenu()

    Return true
EndFunction

Function ShowPlayerArrestMenu()
    {Display the appropriate MessageBox based on bounty and state.
     Uses SkyMessage for proper button support.
     Pay/bribe options hidden after player fails to afford them once.}

    If ConfrontingGuard == None || ConfrontingFaction == None
        DebugMsg("ERROR: ShowPlayerArrestMenu - invalid state")
        Return
    EndIf

    Int bounty = ConfrontingBounty
    Int bribeCost = (bounty as Float * BribeMultiplier) as Int

    String holdName = GetHoldNameForGuard(ConfrontingGuard)
    String resultStr

    If bounty < ArrestBountyThreshold
        ; Low bounty - fine or refuse (no jail option for minor offenses)
        If PaymentFailed
            ; Already failed to pay - only submit or refuse
            String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + ".\n\nThe guard won't accept payment attempts anymore."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Refuse", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            Else
                HandleResistArrest()
            EndIf
        Else
            ; Can still try to pay
            String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + ".\n\nPay your fine or face the consequences."
            resultStr = SkyMessage.Show(bodyText, "Pay Fine (" + bounty + " gold)", "Refuse", getIndex = true)

            If resultStr == "0"
                HandlePayFine()
            Else
                HandleResistArrest()
            EndIf
        EndIf
    Else
        ; High bounty - arrest options
        String bodyText = "You have a bounty of " + bounty + " gold in " + holdName + "."

        If PaymentFailed && PersuadeAttempted
            ; No payment, no persuade - only submit or resist
            bodyText += "\n\nThe guard has lost all patience. Submit or resist."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            Else
                HandleResistArrest()
            EndIf

        ElseIf PaymentFailed && !PersuadeAttempted
            ; No payment, but can persuade
            bodyText += "\n\nThe guard won't accept payment anymore."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Persuade", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            Else
                HandlePersuade()
            EndIf

        ElseIf !PaymentFailed && PersuadeAttempted
            ; Can bribe, but no persuade
            bodyText += "\n\nThe guard has lost patience. Make your choice now."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Bribe (" + bribeCost + " gold)", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            Else
                HandleBribe()
            EndIf

        Else
            ; All options available
            bodyText += "\n\nSubmit to arrest or face the consequences."
            resultStr = SkyMessage.Show(bodyText, "Submit to Arrest", "Resist Arrest", "Bribe (" + bribeCost + " gold)", "Persuade", getIndex = true)

            If resultStr == "0"
                HandleSubmitToArrest()
            ElseIf resultStr == "1"
                HandleResistArrest()
            ElseIf resultStr == "2"
                HandleBribe()
            Else
                HandlePersuade()
            EndIf
        EndIf
    EndIf
EndFunction

Function HandlePayFine()
    {Player pays the fine - clear bounty, or guard gets angry if can't afford}

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int bounty = ConfrontingBounty
    Int playerGold = player.GetGoldAmount()

    Maintenance() ; Ensure Gold001 is available

    If playerGold >= bounty && Gold001
        ; Player can afford - pay the fine
        player.RemoveItem(Gold001, bounty, true)
        ClearTrackedBounty(ConfrontingFaction)

        ; Direct narration - guard accepts fine
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " accepts the " + bounty + " gold fine and pockets it.*"
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("Paid " + bounty + " gold fine")
        DebugMsg("Player paid fine: " + bounty)

        ClearPlayerConfrontationState()
    Else
        ; Player can't afford - guard gets angry, no more payment options
        PaymentFailed = true

        ; Direct narration - guard is angry
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " scowls as the player fumbles through their coin purse, coming up short.* \"You waste my time with empty pockets? Don't try that again!\""
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("The guard won't accept payment attempts anymore!")
        DebugMsg("Player couldn't afford fine, payment options removed")

        ; Show menu again without payment options
        ShowPlayerArrestMenu()
    EndIf
EndFunction

; =============================================================================
; PLAYER ARREST - Option Handlers
; =============================================================================

Function HandleSubmitToArrest()
    {Player submits to arrest - send to jail}

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    DebugMsg("Player submitted to arrest")

    ; Apply tracked bounty to vanilla system so jail works correctly
    ApplyTrackedBountyToVanilla(ConfrontingFaction)

    ; Use vanilla jail system
    ConfrontingFaction.SendPlayerToJail(true, true) ; removeInventory, realJail

    ClearPlayerConfrontationState()
EndFunction

Function HandleResistArrest()
    {Player resists arrest - guard becomes hostile, bounty increases}

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    DebugMsg("Player resisting arrest")

    ; Add resist bounty to tracked system
    ModTrackedBounty(ConfrontingFaction, ResistBountyIncrease)

    ; Apply all tracked bounty to vanilla so guards naturally become hostile
    ApplyTrackedBountyToVanilla(ConfrontingFaction)

    ; Make guard hostile
    ConfrontingGuard.SetAV("Aggression", 2) ; Aggressive
    ConfrontingGuard.StartCombat(Game.GetPlayer())

    Debug.Notification("Bounty increased by " + ResistBountyIncrease + " gold!")

    ClearPlayerConfrontationState()
EndFunction

Function HandleBribe()
    {Player bribes guard - pay extra to clear bounty, or guard gets angry if can't afford}

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int bribeCost = (ConfrontingBounty as Float * BribeMultiplier) as Int
    Int playerGold = player.GetGoldAmount()

    Maintenance() ; Ensure Gold001 is available

    If playerGold >= bribeCost && Gold001
        ; Player can afford - bribe successful
        player.RemoveItem(Gold001, bribeCost, true)
        ClearTrackedBounty(ConfrontingFaction) ; Clear our tracked bounty

        ; Direct narration - guard takes bribe
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " glances around, then quietly takes the " + bribeCost + " gold bribe, looking the other way.*"
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("Bribed guard with " + bribeCost + " gold")
        DebugMsg("Player bribed guard: " + bribeCost)

        ClearPlayerConfrontationState()
    Else
        ; Player can't afford - guard gets angry, no more payment options
        PaymentFailed = true

        ; Direct narration - guard is insulted by pathetic bribe attempt
        String narration = "*" + ConfrontingGuard.GetDisplayName() + " looks at the player's meager coin purse with contempt.* \"You think you can bribe me with that pitiful amount? Don't insult me again!\""
        SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, player)

        Debug.Notification("The guard won't accept payment attempts anymore!")
        DebugMsg("Player couldn't afford bribe, payment options removed")

        ; Show menu again without payment options
        ShowPlayerArrestMenu()
    EndIf
EndFunction

Function HandlePersuade()
    {Player attempts to persuade guard - start conversation mode}

    If ConfrontingGuard == None || ConfrontingFaction == None
        Return
    EndIf

    DebugMsg("Player starting persuasion attempt")

    ; Mark that persuade has been attempted
    PersuadeAttempted = true
    InPersuasionMode = true
    PersuasionStartTime = Utility.GetCurrentRealTime()

    ; Link guard to player so follow package works
    PO3_SKSEFunctions.SetLinkedRef(ConfrontingGuard, Game.GetPlayer(), SeverActions_EscortTargetKeyword)

    ; Apply follow package to guard
    If SeverActions_GuardFollowPlayer
        ActorUtil.AddPackageOverride(ConfrontingGuard, SeverActions_GuardFollowPlayer, PackagePriority, 1)
        ConfrontingGuard.EvaluatePackage()
        DebugMsg("Guard following player for persuasion")
    EndIf

    ; Direct narration to start the conversation
    String holdName = GetHoldNameForGuard(ConfrontingGuard)
    String narration = "*" + ConfrontingGuard.GetDisplayName() + " pauses, willing to hear what the player has to say about their " + ConfrontingBounty + " gold bounty in " + holdName + ".*"
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    ; Register persistent event so SkyrimNet knows the context
    String eventMsg = "The player is trying to convince " + ConfrontingGuard.GetDisplayName() + " to overlook their " + ConfrontingBounty + " gold bounty in " + holdName + ". The guard is listening but skeptical."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification("You have " + (PersuasionTimeLimit as Int) + " seconds to convince the guard...")

    ; Start timer for persuasion timeout
    RegisterForSingleUpdate(1.0)
EndFunction

; =============================================================================
; PLAYER ARREST - Persuasion System
; =============================================================================

Function CheckPersuasionProgress()
    {Check if persuasion time has expired or player moved too far}

    If !InPersuasionMode || ConfrontingGuard == None
        Return
    EndIf

    Float elapsed = Utility.GetCurrentRealTime() - PersuasionStartTime
    Float distance = ConfrontingGuard.GetDistance(Game.GetPlayer())

    ; Check timeout
    If elapsed >= PersuasionTimeLimit
        DebugMsg("Persuasion timed out")
        OnPersuasionFailed("timeout")
        Return
    EndIf

    ; Check distance
    If distance > PersuasionFollowDistance
        DebugMsg("Player moved too far during persuasion")
        OnPersuasionFailed("distance")
        Return
    EndIf

    ; Check if guard died
    If ConfrontingGuard.IsDead()
        DebugMsg("Guard died during persuasion")
        ClearPlayerConfrontationState()
        Return
    EndIf

    ; Still in progress, keep checking
    RegisterForSingleUpdate(1.0)
EndFunction

; =============================================================================
; PLAYER ARREST - Persuasion Actions (for SkyrimNet)
; =============================================================================

Bool Function CanUsePersuasionAction(Actor akGuard)
    {Eligibility function for persuasion actions (AcceptPersuasion, RejectPersuasion).
     Returns true only if this guard is the one confronting the player in persuasion mode.}

    If !InPersuasionMode
        Return false
    EndIf

    If akGuard == None
        Return false
    EndIf

    If akGuard != ConfrontingGuard
        Return false
    EndIf

    Return true
EndFunction

Bool Function AcceptPersuasion_Internal(Actor akGuard)
    {Called by SkyrimNet when the AI decides the player's argument is convincing.
     Clears bounty and ends persuasion successfully.
     Returns true if successful.}

    If !InPersuasionMode
        DebugMsg("ERROR: AcceptPersuasion called but not in persuasion mode")
        Return false
    EndIf

    If akGuard != ConfrontingGuard
        DebugMsg("ERROR: AcceptPersuasion called with wrong guard")
        Return false
    EndIf

    DebugMsg("Guard accepted persuasion!")

    ; Clear tracked bounty (vanilla is already 0)
    ClearTrackedBounty(ConfrontingFaction)

    ; Remove follow package
    If SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(ConfrontingGuard, SeverActions_GuardFollowPlayer)
    EndIf
    PO3_SKSEFunctions.SetLinkedRef(ConfrontingGuard, None, SeverActions_EscortTargetKeyword)
    ConfrontingGuard.EvaluatePackage()

    ; Direct narration
    String narration = "*" + ConfrontingGuard.GetDisplayName() + " sighs and nods reluctantly.* \"Fine. Get out of here before I change my mind.\""
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    ; Persistent event for success
    String holdName = GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = "The player convinced " + ConfrontingGuard.GetDisplayName() + " to overlook their " + ConfrontingBounty + " gold bounty in " + holdName + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, Game.GetPlayer(), ConfrontingGuard)

    Debug.Notification("The guard lets you go with a warning")

    ClearPlayerConfrontationState()
    Return true
EndFunction

Bool Function RejectPersuasion_Internal(Actor akGuard)
    {Called by SkyrimNet when the AI decides the player's argument is NOT convincing.
     Ends persuasion mode and forces the player to choose: submit or resist.
     Returns true if successful.}

    If !InPersuasionMode
        DebugMsg("ERROR: RejectPersuasion called but not in persuasion mode")
        Return false
    EndIf

    If akGuard != ConfrontingGuard
        DebugMsg("ERROR: RejectPersuasion called with wrong guard")
        Return false
    EndIf

    DebugMsg("Guard rejected persuasion attempt")

    ; Remove follow package
    If SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(ConfrontingGuard, SeverActions_GuardFollowPlayer)
    EndIf
    PO3_SKSEFunctions.SetLinkedRef(ConfrontingGuard, None, SeverActions_EscortTargetKeyword)
    ConfrontingGuard.EvaluatePackage()

    InPersuasionMode = false

    ; The guard will provide their own narration via SkyrimNet dialogue
    ; Just register the persistent event
    String holdName = GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = ConfrontingGuard.GetDisplayName() + " was not convinced by the player's arguments and demands they face justice for their " + ConfrontingBounty + " gold bounty in " + holdName + "."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification("The guard is not convinced!")

    ; Show menu again without persuade option (since they already tried)
    ShowPlayerArrestMenu()
    Return true
EndFunction

Function OnPersuasionFailed(String reason)
    {Called when persuasion fails (timeout or distance)}

    If !InPersuasionMode || ConfrontingGuard == None
        Return
    EndIf

    DebugMsg("Persuasion failed: " + reason)

    ; Remove follow package
    If SeverActions_GuardFollowPlayer
        ActorUtil.RemovePackageOverride(ConfrontingGuard, SeverActions_GuardFollowPlayer)
    EndIf
    PO3_SKSEFunctions.SetLinkedRef(ConfrontingGuard, None, SeverActions_EscortTargetKeyword)
    ConfrontingGuard.EvaluatePackage()

    InPersuasionMode = false

    ; Direct narration - guard annoyed
    String narration
    If reason == "timeout"
        narration = "*" + ConfrontingGuard.GetDisplayName() + " grows impatient.* \"Enough talk! Make your choice now.\""
    Else
        narration = "*" + ConfrontingGuard.GetDisplayName() + " catches up, clearly annoyed.* \"Trying to run? That's it, no more games!\""
    EndIf
    SkyrimNetApi.DirectNarration(narration, ConfrontingGuard, Game.GetPlayer())

    ; Persistent event for failure
    String holdName = GetHoldNameForGuard(ConfrontingGuard)
    String eventMsg = ConfrontingGuard.GetDisplayName() + " grew tired of the player's excuses and demanded they submit to arrest."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, ConfrontingGuard, Game.GetPlayer())

    Debug.Notification("The guard has lost patience!")

    ; Show menu again without persuade option
    ShowPlayerArrestMenu()
EndFunction

; =============================================================================
; PLAYER ARREST - Cleanup
; =============================================================================

Function CancelPlayerConfrontation()
    {Cancel current player confrontation}

    DebugMsg("Canceling player confrontation")

    If InPersuasionMode && ConfrontingGuard
        ; Remove follow package
        If SeverActions_GuardFollowPlayer
            ActorUtil.RemovePackageOverride(ConfrontingGuard, SeverActions_GuardFollowPlayer)
        EndIf
        PO3_SKSEFunctions.SetLinkedRef(ConfrontingGuard, None, SeverActions_EscortTargetKeyword)
        ConfrontingGuard.EvaluatePackage()
    EndIf

    ClearPlayerConfrontationState()
EndFunction

Function ClearPlayerConfrontationState()
    {Clear all player confrontation state}

    ConfrontingGuard = None
    ConfrontingFaction = None
    ConfrontingBounty = 0
    PersuadeAttempted = false
    PaymentFailed = false
    InPersuasionMode = false
    PersuasionStartTime = 0.0

    UnregisterForUpdate()
EndFunction

Bool Function IsPlayerInConfrontation()
    {Check if player is currently being confronted by a guard}

    Return ConfrontingGuard != None
EndFunction

Bool Function IsPlayerInPersuasion()
    {Check if player is currently in persuasion mode}

    Return InPersuasionMode
EndFunction
