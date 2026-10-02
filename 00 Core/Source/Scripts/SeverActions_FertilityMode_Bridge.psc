Scriptname SeverActions_FertilityMode_Bridge extends Quest
; Bridges Fertility Mode Reloaded to SkyrimNet: a periodic scan reads FM's arrays and
; pushes them to the native cache (the fertility_* decorators) and to StorageUtil
; (read by the 0250_severactions_fertility prompt). Compiling needs FM Reloaded's
; _JSW_BB_Storage.psc and _JSW_BB_Utility.psc.

Actor Property PlayerRef Auto
Bool Property Enabled = True Auto
Float Property UpdateInterval = 60.0 Auto

_JSW_BB_Storage FertStorage
_JSW_BB_Utility FertUtil
Bool bInitialized = False
Bool bNativeAvailable = False
; Real-time deadline after an empty TrackedActors read; the scan skips until it
; passes (see UpdateNearbyActors).
Float fNoneReadBackoffUntil = 0.0

Event OnInit()
    ; Let the other mods finish loading.
    Utility.Wait(2.0)
    Maintenance()
EndEvent

; Load path (a Quest script gets no OnPlayerLoadGame): SeverActions_Mod_Fertility
; calls RegisterDecorators + InitializeNative at stage 0 and Maintenance at stage 1
; on every load and new game.

Function RegisterDecorators()
    {Registers the Fertility Mode decorators when the esm is loaded.
     Idempotent: SkyrimNet replaces a same-name registration.}
    If Game.GetModByName("Fertility Mode.esm") == 255
        Debug.Trace("[SeverActions] Fertility Mode not installed - skipping FM decorators")
        Return
    EndIf
    Int result
    ; Batch decorator: every field in one call.
    result = SkyrimNetApi.RegisterDecorator("fertility_data_batch", "SeverActions_FertilityMode_Bridge", "GetFertilityDataBatch")
    Debug.Trace("[SeverActions] fertility_data_batch: " + (result == 0) as String)
    ; Per-field decorators, kept for compatibility.
    result = SkyrimNetApi.RegisterDecorator("fertility_state", "SeverActions_FertilityMode_Bridge", "GetFertilityState")
    Debug.Trace("[SeverActions] fertility_state: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("fertility_father", "SeverActions_FertilityMode_Bridge", "GetFertilityFather")
    Debug.Trace("[SeverActions] fertility_father: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("fertility_cycle_day", "SeverActions_FertilityMode_Bridge", "GetCycleDay")
    Debug.Trace("[SeverActions] fertility_cycle_day: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("fertility_pregnant_days", "SeverActions_FertilityMode_Bridge", "GetPregnantDays")
    Debug.Trace("[SeverActions] fertility_pregnant_days: " + (result == 0) as String)
    result = SkyrimNetApi.RegisterDecorator("fertility_has_baby", "SeverActions_FertilityMode_Bridge", "GetHasBaby")
    Debug.Trace("[SeverActions] fertility_has_baby: " + (result == 0) as String)
    Debug.Trace("[SeverActions] Fertility Mode decorators registered")
EndFunction

Function InitializeNative()
    {Initializes the native FM module ahead of Maintenance. No-op without the esm.}
    If Game.GetModByName("Fertility Mode.esm") == 255
        Debug.Trace("[SeverActions] Fertility Mode not installed - skipping FM initialization")
        Return
    EndIf
    If SeverActionsNative.FM_Initialize()
        Debug.Trace("[SeverActions] Native FM module initialized")
    Else
        Debug.Trace("[SeverActions] Native FM module init returned false (may already be initialized)")
    EndIf
EndFunction

Function ChronoArm(Float afSeconds)
    {Arms this script's one-shot chronometer tick (see the Chronometer block in
     SeverActionsNativeExt2.psc; event and callback names are unique per
     script). Re-arm replaces the pending tick; ticks do not survive a load.
     A wake already in flight can land after the loop stops, so the handler
     checks bInitialized first.}
    RegisterForModEvent("SeverActions_Tick_Fertility", "OnChronoTick_Fertility")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Fertility", afSeconds)
EndFunction

Event OnChronoTick_Fertility(String eventName, String strArg, Float numArg, Form sender)
    if !bInitialized || !FertStorage
        return
    endif

    ; FM removed from a running save: stop the loop.
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
    ChronoArm(UpdateInterval)
EndEvent

Function Maintenance()
    PlayerRef = Game.GetPlayer()
    ; The backoff deadline is in GetCurrentRealTime seconds, which restart at each launch,
    ; but the variable is saved: every load starts without one.
    fNoneReadBackoffUntil = 0.0

    if Game.GetModByName("Fertility Mode.esm") == 255
        Debug.Trace("[SeverActions_FM] Fertility Mode not found")
        return
    endif

    bNativeAvailable = SeverActionsNative.FM_Initialize()
    if bNativeAvailable
        Debug.Trace("[SeverActions_FM] Native FM module initialized")
    else
        Debug.Trace("[SeverActions_FM] Native FM module not available, using Papyrus fallback")
    endif

    ; FM's _JSW_BB_HandlerQuest (0x0D62) carries both the Storage and the Utility script.
    Quest handlerQuest = Game.GetFormFromFile(0x0D62, "Fertility Mode.esm") as Quest
    if !handlerQuest
        Debug.Trace("[SeverActions_FM] Could not find FM handler quest at 0x0D62")
        return
    endif

    FertStorage = handlerQuest as _JSW_BB_Storage
    FertUtil = handlerQuest as _JSW_BB_Utility

    if !FertStorage
        Debug.Trace("[SeverActions_FM] Could not cast to _JSW_BB_Storage")
        return
    endif

    bInitialized = True
    Debug.Trace("[SeverActions_FM] Initialized successfully")

    RegisterForModEvent("FertilityModeAddSperm", "OnFertilityModeAddSperm")
    RegisterForModEvent("FertilityModeConception", "OnFertilityModeConception")

    ; 60 s floor: FM state moves over game days, and every read of a None FM
    ; array logs a cast error we cannot prevent. Enforced here, not at the
    ; property default, because Auto defaults bake into existing saves.
    if UpdateInterval < 60.0
        UpdateInterval = 60.0
    endif

    ChronoArm(UpdateInterval)
    Debug.Trace("[SeverActions_FM] Update loop started with interval: " + UpdateInterval)
EndFunction

; --- FM mod events ---

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

    ; Recorded for prompts (no shipped prompt reads these keys); no narration on
    ; insemination, by design.
    StorageUtil.SetStringValue(targetActor, "SkyrimNet_FM_InsemFather", actualFatherName)
    StorageUtil.SetFloatValue(targetActor, "SkyrimNet_FM_InsemTime", Utility.GetCurrentGameTime())

    Debug.Trace("[SeverActions_FM] Insemination: " + actualFatherName + " -> " + targetName)
EndEvent

Event OnFertilityModeConception(String eventName, Form akSender, String motherName, String fatherName, Int trackingIndex)
    if !Enabled
        return
    endif

    Actor mother = akSender as Actor
    if mother
        Debug.Trace("[SeverActions_FM] Conception: " + motherName + " by " + fatherName)
    endif
EndEvent

; --- Scan: FM arrays -> native cache + StorageUtil ---

Function UpdateActorFertilityData(Actor akActor, Form[] akTrackedActors = None)
    ; Is3DLoaded is the last gate before FM_SetActorData, which null-derefs on an
    ; actor mid-detach in a cell transition. NPCs arrive pre-filtered; the player
    ; does not. A skipped actor is re-read on the next scan. (|| short-circuits, so
    ; a None actor never reaches Is3DLoaded.)
    if !akActor || !akActor.Is3DLoaded() || !bInitialized || !FertStorage
        return
    endif

    ; Prefer the list the scan already read: each read of FM's getter while its
    ; array is None logs a cast error. Test arrays by truthiness, never `== None`
    ; (see UpdateNearbyActors).
    Form[] trackedActors = akTrackedActors
    if !trackedActors
        trackedActors = FertStorage.TrackedActors
    endif
    if !trackedActors || trackedActors.Length == 0
        return
    endif

    int actorIndex = trackedActors.Find(akActor)
    if actorIndex == -1
        return
    endif

    ; Each FM array is read once into a local; FM can be mid-reinitialisation, and
    ; a None read logs a cast error.
    float lastConception = 0.0
    float lastBirth = 0.0
    float babyAdded = 0.0
    float lastOvulation = 0.0
    float lastGameHours = 0.0
    int lastGameHoursDelta = 0
    String currentFather = ""

    float[] arrConception = FertStorage.LastConception
    float[] arrBirth = FertStorage.LastBirth
    float[] arrBabyAdded = FertStorage.BabyAdded
    float[] arrOvulation = FertStorage.LastOvulation
    float[] arrGameHours = FertStorage.LastGameHours
    int[] arrGameHoursDelta = FertStorage.LastGameHoursDelta
    string[] arrFather = FertStorage.CurrentFather

    if arrConception && actorIndex < arrConception.Length
        lastConception = arrConception[actorIndex]
    endif
    if arrBirth && actorIndex < arrBirth.Length
        lastBirth = arrBirth[actorIndex]
    endif
    if arrBabyAdded && actorIndex < arrBabyAdded.Length
        babyAdded = arrBabyAdded[actorIndex]
    endif
    if arrOvulation && actorIndex < arrOvulation.Length
        lastOvulation = arrOvulation[actorIndex]
    endif
    if arrGameHours && actorIndex < arrGameHours.Length
        lastGameHours = arrGameHours[actorIndex]
    endif
    if arrGameHoursDelta && actorIndex < arrGameHoursDelta.Length
        lastGameHoursDelta = arrGameHoursDelta[actorIndex]
    endif
    if arrFather && actorIndex < arrFather.Length
        currentFather = arrFather[actorIndex]
    endif

    if bNativeAvailable
        SeverActionsNative.FM_SetActorData(akActor, lastConception, lastBirth, babyAdded, lastOvulation, lastGameHours, lastGameHoursDelta, currentFather)
    endif

    ; The 0250_severactions_fertility prompt reads these SkyrimNet_FM_* keys.
    String fertState = GetFertilityStateFromData(akActor, lastConception, lastBirth, babyAdded, lastOvulation, lastGameHours, lastGameHoursDelta)
    StorageUtil.SetStringValue(akActor, "SkyrimNet_FM_State", fertState)
    StorageUtil.SetStringValue(akActor, "SkyrimNet_FM_Father", currentFather)

    int cycleDuration = 28
    GlobalVariable cycleGlobal = Game.GetFormFromFile(0x000D67, "Fertility Mode.esm") as GlobalVariable
    if cycleGlobal
        cycleDuration = cycleGlobal.GetValueInt()
    endif
    int cycleDay = (Math.Ceiling(lastGameHours + lastGameHoursDelta) as int) % (cycleDuration + 1)
    StorageUtil.SetIntValue(akActor, "SkyrimNet_FM_CycleDay", cycleDay)

    int pregnantDays = 0
    if lastConception > 0.0
        float now = Utility.GetCurrentGameTime()
        pregnantDays = Math.Floor(now - lastConception) as int
        if pregnantDays < 0
            pregnantDays = 0
        endif
    endif
    StorageUtil.SetIntValue(akActor, "SkyrimNet_FM_PregnantDays", pregnantDays)

    int hasBaby = 0
    if babyAdded > 0.0
        hasBaby = 1
    endif
    StorageUtil.SetIntValue(akActor, "SkyrimNet_FM_HasBaby", hasBaby)

    StorageUtil.SetIntValue(akActor, "SkyrimNet_FM_IsTracked", 1)
EndFunction

Function UpdateNearbyActors()
    if !bInitialized || !Enabled || !FertStorage
        return
    endif

    ; Skip the scan during a cell transition (the FM_SetActorData CTD window). The
    ; tick handler re-arms after this call, so the next interval retries.
    if !PlayerRef || !PlayerRef.Is3DLoaded()
        return
    endif

    ; With nothing tracked, every read of FM's TrackedActors logs one benign
    ; "Cannot cast from None to Form[]" (FM-internal), so an empty read backs the
    ; whole scan off for 300 s. Per session: Maintenance clears it on every load.
    if fNoneReadBackoffUntil > 0.0 && Utility.GetCurrentRealTime() < fNoneReadBackoffUntil
        return
    endif

    ; Read the tracked list ONCE per scan and pass it down, so the getter logs at
    ; most once per scan. Test it by truthiness: `arr == None` does not detect a
    ; None array in Papyrus.
    ; Deliberately NO FertStorage.UpdateStorage() here: FM Reloaded 1.0.3
    ; re-initializes SpawnedChildActorRefs on every call whose length disagrees
    ; with AdultChildren, so calling it per scan churns FM-owned state. FM sizes
    ; its own arrays.
    Form[] trackedActors = FertStorage.TrackedActors
    if !trackedActors || trackedActors.Length == 0
        fNoneReadBackoffUntil = Utility.GetCurrentRealTime() + 300.0
        return
    endif
    fNoneReadBackoffUntil = 0.0

    if PlayerRef.GetActorBase().GetSex() == 1
        UpdateActorFertilityData(PlayerRef, trackedActors)
    endif

    ; The cell scan with its female + Is3DLoaded filter is native;
    ; UpdateActorFertilityData stays Papyrus because it reads FM's script arrays.
    Actor[] females = SeverActionsNativeExt.Native_ScanPlayerCellFemales3DLoaded()
    if females
        int i = 0
        while i < females.Length
            UpdateActorFertilityData(females[i], trackedActors)
            i += 1
        endwhile
    endif
EndFunction

; The state token written to SkyrimNet_FM_State. Pregnancy wins, then post-birth
; recovery, then the cycle phase; FM's own globals override the defaults below,
; which are FM Reloaded's shipped values.
String Function GetFertilityStateFromData(Actor akActor, float lastConception, float lastBirth, float babyAdded, float lastOvulation, float lastGameHours, int lastGameHoursDelta)
    float now = Utility.GetCurrentGameTime()

    if lastConception > 0.0
        float pregnantDays = now - lastConception
        float pregnancyDuration = 10.0
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

    int cycleDuration = 28
    int menstruationBegin = 0
    int menstruationEnd = 6
    int ovulationBegin = 7
    int ovulationEnd = 13

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

; --- SkyrimNet decorators (see RegisterDecorators) ---
; Female actors only; the native cache answers, and handles FM being absent.

String Function GetFertilityState(Actor akActor) Global
    if !akActor
        return "normal"
    endif

    if akActor.GetActorBase().GetSex() != 1
        return "normal"
    endif

    return SeverActionsNative.FM_GetFertilityState(akActor)
EndFunction

String Function GetFertilityFather(Actor akActor) Global
    if !akActor
        return ""
    endif

    if akActor.GetActorBase().GetSex() != 1
        return ""
    endif

    return SeverActionsNative.FM_GetFertilityFather(akActor)
EndFunction

String Function GetCycleDay(Actor akActor) Global
    if !akActor
        return "-1"
    endif

    if akActor.GetActorBase().GetSex() != 1
        return "-1"
    endif

    return SeverActionsNative.FM_GetCycleDay(akActor)
EndFunction

String Function GetPregnantDays(Actor akActor) Global
    if !akActor
        return "0"
    endif

    if akActor.GetActorBase().GetSex() != 1
        return "0"
    endif

    return SeverActionsNative.FM_GetPregnantDays(akActor)
EndFunction

String Function GetHasBaby(Actor akActor) Global
    if !akActor
        return "false"
    endif

    if akActor.GetActorBase().GetSex() != 1
        return "false"
    endif

    return SeverActionsNative.FM_GetHasBaby(akActor)
EndFunction

; fertility_data_batch: "state|father|cycleDay|pregnantDays|hasBaby", the five
; fields of FM_GetFertilityDataBatch.
String Function GetFertilityDataBatch(Actor akActor) Global
    if !akActor || akActor.GetActorBase().GetSex() != 1
        return "normal||-1|0|false"
    endif

    return SeverActionsNative.FM_GetFertilityDataBatch(akActor)
EndFunction
