Scriptname SeverActions_FertilityMode_Bridge extends Quest
; Bridges Fertility Mode Reloaded data to SkyrimNet via native decorators
; Requires: Fertility Mode Reloaded source files (_JSW_BB_Storage.psc, _JSW_BB_Utility.psc) to compile
; Uses hybrid native approach: Papyrus reads FM arrays, pushes to native cache for O(1) lookups

Actor Property PlayerRef Auto
Bool Property Enabled = True Auto
Float Property UpdateInterval = 3.0 Auto

; Cached references
_JSW_BB_Storage FertStorage
_JSW_BB_Utility FertUtil
Bool bInitialized = False
Bool bNativeAvailable = False

Event OnInit()
    ; Delay on first init to ensure all mods are loaded
    Utility.Wait(2.0)
    Maintenance()
EndEvent

Event OnPlayerLoadGame()
    Maintenance()
EndEvent

Event OnUpdate()
    ; Only run update loop if FM is actually installed and initialized
    if !bInitialized || !FertStorage
        return
    endif

    ; Double-check FM is still installed (user may have removed it mid-save)
    if Game.GetModByName("Fertility Mode.esm") == 255
        Debug.Trace("[SeverActions_FM] Fertility Mode no longer installed - stopping update loop")
        bInitialized = False
        FertStorage = None
        FertUtil = None
        return
    endif

    if Enabled
        UpdateNearbyActors()
    endif
    RegisterForSingleUpdate(UpdateInterval)
EndEvent

Function Maintenance()
    PlayerRef = Game.GetPlayer()

    ; Check if Fertility Mode is installed
    if Game.GetModByName("Fertility Mode.esm") == 255
        Debug.Trace("[SeverActions_FM] Fertility Mode not found")
        return
    endif

    ; Initialize native FM module first
    bNativeAvailable = SeverActionsNative.FM_Initialize()
    if bNativeAvailable
        Debug.Trace("[SeverActions_FM] Native FM module initialized")
    else
        Debug.Trace("[SeverActions_FM] Native FM module not available, using Papyrus fallback")
    endif

    ; Get the handler quest from Fertility Mode Reloaded
    ; FormID 0x0D62 is _JSW_BB_HandlerQuest which has BOTH Storage and Utility scripts
    Quest handlerQuest = Game.GetFormFromFile(0x0D62, "Fertility Mode.esm") as Quest
    if !handlerQuest
        Debug.Trace("[SeverActions_FM] Could not find FM handler quest at 0x0D62")
        return
    endif

    ; Cast to BOTH script types from the same quest
    FertStorage = handlerQuest as _JSW_BB_Storage
    FertUtil = handlerQuest as _JSW_BB_Utility

    if !FertStorage
        Debug.Trace("[SeverActions_FM] Could not cast to _JSW_BB_Storage")
        return
    endif

    bInitialized = True
    Debug.Trace("[SeverActions_FM] Initialized successfully")

    ; Register for FM events
    RegisterForModEvent("FertilityModeAddSperm", "OnFertilityModeAddSperm")
    RegisterForModEvent("FertilityModeConception", "OnFertilityModeConception")

    ; Start the update loop
    RegisterForSingleUpdate(UpdateInterval)
    Debug.Trace("[SeverActions_FM] Update loop started with interval: " + UpdateInterval)
EndFunction

; ============================================================================
; MOD EVENTS
; ============================================================================

Event OnFertilityModeAddSperm(Form akTarget, String fatherName, Form father)
    if !Enabled
        return
    endif

    Actor targetActor = akTarget as Actor
    Actor fatherActor = father as Actor

    if !targetActor
        return
    endif

    String targetName = targetActor.GetDisplayName()
    String actualFatherName = fatherName
    if fatherActor
        actualFatherName = fatherActor.GetDisplayName()
    endif

    ; Store insemination data in StorageUtil for prompt access
    StorageUtil.SetStringValue(targetActor, "SkyrimNet_FM_InsemFather", actualFatherName)
    StorageUtil.SetFloatValue(targetActor, "SkyrimNet_FM_InsemTime", Utility.GetCurrentGameTime())

    ; Send narration
    String content = "*" + actualFatherName + " releases inside " + targetName + ".*"
    SkyrimNetApi.DirectNarration(content, targetActor, fatherActor)

    Debug.Trace("[SeverActions_FM] Insemination: " + actualFatherName + " -> " + targetName)
EndEvent

Event OnFertilityModeConception(String eventName, Form akSender, String motherName, String fatherName, Int trackingIndex)
    if !Enabled
        return
    endif

    Actor mother = akSender as Actor
    if mother
        String content = "*" + motherName + " has conceived " + fatherName + "'s child.*"
        SkyrimNetApi.DirectNarration(content, mother, None)
        Debug.Trace("[SeverActions_FM] Conception: " + motherName + " by " + fatherName)
    endif
EndEvent

; ============================================================================
; NATIVE CACHE UPDATE FUNCTIONS - Pushes FM data to native module
; ============================================================================

Function UpdateActorFertilityData(Actor akActor)
    if !akActor || !bInitialized || !FertStorage
        return
    endif

    ; Safety check - FM's arrays may not be initialized yet or FM was removed
    if FertStorage.TrackedActors == None
        Debug.Trace("[SeverActions_FM] TrackedActors array is None - FM may not be fully loaded")
        return
    endif

    ; Find actor in FM's tracked array
    int actorIndex = FertStorage.TrackedActors.Find(akActor)
    if actorIndex == -1
        return
    endif

    ; Extract raw data from FM arrays
    float lastConception = 0.0
    float lastBirth = 0.0
    float babyAdded = 0.0
    float lastOvulation = 0.0
    float lastGameHours = 0.0
    int lastGameHoursDelta = 0
    String currentFather = ""

    if actorIndex < FertStorage.LastConception.Length
        lastConception = FertStorage.LastConception[actorIndex]
    endif
    if actorIndex < FertStorage.LastBirth.Length
        lastBirth = FertStorage.LastBirth[actorIndex]
    endif
    if actorIndex < FertStorage.BabyAdded.Length
        babyAdded = FertStorage.BabyAdded[actorIndex]
    endif
    if actorIndex < FertStorage.LastOvulation.Length
        lastOvulation = FertStorage.LastOvulation[actorIndex]
    endif
    if actorIndex < FertStorage.LastGameHours.Length
        lastGameHours = FertStorage.LastGameHours[actorIndex]
    endif
    if actorIndex < FertStorage.LastGameHoursDelta.Length
        lastGameHoursDelta = FertStorage.LastGameHoursDelta[actorIndex]
    endif
    if actorIndex < FertStorage.CurrentFather.Length
        currentFather = FertStorage.CurrentFather[actorIndex]
    endif

    ; Push to native cache if available
    if bNativeAvailable
        SeverActionsNative.FM_SetActorData(akActor, lastConception, lastBirth, babyAdded, lastOvulation, lastGameHours, lastGameHoursDelta, currentFather)
    endif

    ; Also store processed values in StorageUtil for native decorator access
    String fertState = GetFertilityStateFromData(akActor, lastConception, lastBirth, babyAdded, lastOvulation, lastGameHours, lastGameHoursDelta)
    StorageUtil.SetStringValue(akActor, "SkyrimNet_FM_State", fertState)
    StorageUtil.SetStringValue(akActor, "SkyrimNet_FM_Father", currentFather)

    ; Store cycle day
    int cycleDuration = 28
    GlobalVariable cycleGlobal = Game.GetFormFromFile(0x000D67, "Fertility Mode.esm") as GlobalVariable
    if cycleGlobal
        cycleDuration = cycleGlobal.GetValueInt()
    endif
    int cycleDay = (Math.Ceiling(lastGameHours + lastGameHoursDelta) as int) % (cycleDuration + 1)
    StorageUtil.SetIntValue(akActor, "SkyrimNet_FM_CycleDay", cycleDay)

    ; Store pregnant days
    int pregnantDays = 0
    if lastConception > 0.0
        float now = Utility.GetCurrentGameTime()
        pregnantDays = Math.Floor(now - lastConception) as int
        if pregnantDays < 0
            pregnantDays = 0
        endif
    endif
    StorageUtil.SetIntValue(akActor, "SkyrimNet_FM_PregnantDays", pregnantDays)

    ; Store has baby flag
    int hasBaby = 0
    if babyAdded > 0.0
        hasBaby = 1
    endif
    StorageUtil.SetIntValue(akActor, "SkyrimNet_FM_HasBaby", hasBaby)

    ; Mark as tracked
    StorageUtil.SetIntValue(akActor, "SkyrimNet_FM_IsTracked", 1)
EndFunction

Function UpdateNearbyActors()
    if !bInitialized || !Enabled || !FertStorage
        return
    endif

    ; Verify FM arrays are available before scanning
    if FertStorage.TrackedActors == None
        Debug.Trace("[SeverActions_FM] TrackedActors array is None - skipping nearby scan")
        return
    endif

    ; Update player if female
    if PlayerRef.GetActorBase().GetSex() == 1
        UpdateActorFertilityData(PlayerRef)
    endif

    ; Update nearby female NPCs using cell scan
    Cell currentCell = PlayerRef.GetParentCell()
    if currentCell
        int numRefs = currentCell.GetNumRefs(43) ; 43 = kActorCharacter
        int i = 0
        while i < numRefs
            Actor npc = currentCell.GetNthRef(i, 43) as Actor
            if npc && npc != PlayerRef && npc.GetActorBase().GetSex() == 1
                if npc.Is3DLoaded()
                    UpdateActorFertilityData(npc)
                endif
            endif
            i += 1
        endwhile
    endif
EndFunction

; Helper function to compute state from raw data (used for StorageUtil fallback)
String Function GetFertilityStateFromData(Actor akActor, float lastConception, float lastBirth, float babyAdded, float lastOvulation, float lastGameHours, int lastGameHoursDelta)
    float now = Utility.GetCurrentGameTime()

    ; Check pregnancy first
    if lastConception > 0.0
        float pregnantDays = now - lastConception
        float pregnancyDuration = 30.0
        GlobalVariable durationGlobal = Game.GetFormFromFile(0x000D66, "Fertility Mode.esm") as GlobalVariable
        if durationGlobal
            pregnancyDuration = durationGlobal.GetValue()
        endif

        float progress = (pregnantDays / pregnancyDuration) * 100.0
        if progress >= 66.0
            return "third_trimester"
        elseif progress >= 33.0
            return "second_trimester"
        else
            return "first_trimester"
        endif
    endif

    ; Check recovery
    if lastBirth > 0.0
        float daysSinceBirth = now - lastBirth
        float recoveryDuration = 10.0
        GlobalVariable recoveryGlobal = Game.GetFormFromFile(0x0058D1, "Fertility Mode.esm") as GlobalVariable
        if recoveryGlobal
            recoveryDuration = recoveryGlobal.GetValue()
        endif
        if daysSinceBirth < recoveryDuration
            return "recovery"
        endif
    endif

    ; Cycle phase calculation
    int cycleDuration = 28
    int menstruationBegin = 0
    int menstruationEnd = 7
    int ovulationBegin = 8
    int ovulationEnd = 16

    GlobalVariable cycleGlobal = Game.GetFormFromFile(0x000D67, "Fertility Mode.esm") as GlobalVariable
    GlobalVariable mensBeginGlobal = Game.GetFormFromFile(0x000D68, "Fertility Mode.esm") as GlobalVariable
    GlobalVariable mensEndGlobal = Game.GetFormFromFile(0x000D69, "Fertility Mode.esm") as GlobalVariable
    GlobalVariable ovulBeginGlobal = Game.GetFormFromFile(0x000D6A, "Fertility Mode.esm") as GlobalVariable
    GlobalVariable ovulEndGlobal = Game.GetFormFromFile(0x000D6B, "Fertility Mode.esm") as GlobalVariable

    if cycleGlobal
        cycleDuration = cycleGlobal.GetValueInt()
    endif
    if mensBeginGlobal
        menstruationBegin = mensBeginGlobal.GetValueInt()
    endif
    if mensEndGlobal
        menstruationEnd = mensEndGlobal.GetValueInt()
    endif
    if ovulBeginGlobal
        ovulationBegin = ovulBeginGlobal.GetValueInt()
    endif
    if ovulEndGlobal
        ovulationEnd = ovulEndGlobal.GetValueInt()
    endif

    int cycleDay = (Math.Ceiling(lastGameHours + lastGameHoursDelta) as int) % (cycleDuration + 1)
    bool hasEgg = (lastOvulation > 0.0)

    if cycleDay >= menstruationBegin && cycleDay <= menstruationEnd
        return "menstruating"
    elseif hasEgg || (cycleDay >= ovulationBegin && cycleDay <= ovulationEnd)
        return "ovulating"
    elseif cycleDay > ovulationEnd
        return "pms"
    else
        return "fertile"
    endif
EndFunction

; ============================================================================
; DECORATOR FUNCTIONS - Called by SkyrimNet prompts
; Now delegate to native functions for O(1) performance
; ============================================================================

String Function GetFertilityState(Actor akActor) Global
    if !akActor
        return "normal"
    endif

    ; Only check female actors
    if akActor.GetActorBase().GetSex() != 1
        return "normal"
    endif

    ; Direct native call - native handles FM not installed case
    return SeverActionsNative.FM_GetFertilityState(akActor)
EndFunction

String Function GetFertilityFather(Actor akActor) Global
    if !akActor
        return ""
    endif

    if akActor.GetActorBase().GetSex() != 1
        return ""
    endif

    ; Direct native call - native handles FM not installed case
    return SeverActionsNative.FM_GetFertilityFather(akActor)
EndFunction

String Function GetCycleDay(Actor akActor) Global
    if !akActor
        return "-1"
    endif

    if akActor.GetActorBase().GetSex() != 1
        return "-1"
    endif

    ; Direct native call - native handles FM not installed case
    return SeverActionsNative.FM_GetCycleDay(akActor)
EndFunction

String Function GetPregnantDays(Actor akActor) Global
    if !akActor
        return "0"
    endif

    if akActor.GetActorBase().GetSex() != 1
        return "0"
    endif

    ; Direct native call - native handles FM not installed case
    return SeverActionsNative.FM_GetPregnantDays(akActor)
EndFunction

String Function GetHasBaby(Actor akActor) Global
    if !akActor
        return "false"
    endif

    if akActor.GetActorBase().GetSex() != 1
        return "false"
    endif

    ; Direct native call - native handles FM not installed case
    return SeverActionsNative.FM_GetHasBaby(akActor)
EndFunction

; Batch function - gets all fertility data in one call (5x faster)
; Returns pipe-delimited string: "state|father|cycleDay|pregnantDays|hasBaby"
; Use split('|') in Jinja template to parse
String Function GetFertilityDataBatch(Actor akActor) Global
    if !akActor || akActor.GetActorBase().GetSex() != 1
        return "normal|||-1|0|false"
    endif

    return SeverActionsNative.FM_GetFertilityDataBatch(akActor)
EndFunction
