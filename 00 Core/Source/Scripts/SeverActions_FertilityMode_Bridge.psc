Scriptname SeverActions_FertilityMode_Bridge extends Quest
; Bridges Fertility Mode Reloaded data to SkyrimNet via native decorators
; Requires: Fertility Mode Reloaded source files (_JSW_BB_Storage.psc, _JSW_BB_Utility.psc) to compile
; Uses hybrid native approach: Papyrus reads FM arrays, pushes to native cache for O(1) lookups

Actor Property PlayerRef Auto
Bool Property Enabled = True Auto
Float Property UpdateInterval = 60.0 Auto

; Cached references
_JSW_BB_Storage FertStorage
_JSW_BB_Utility FertUtil
Bool bInitialized = False
Bool bNativeAvailable = False
; Real-time deadline after a None TrackedActors read — the scan sleeps until it
; passes so FM's benign per-read log line can't repeat every 3s while FM is idle.
Float fNoneReadBackoffUntil = 0.0

Event OnInit()
    ; Delay on first init to ensure all mods are loaded
    Utility.Wait(2.0)
    Maintenance()
EndEvent

; No OnPlayerLoadGame handler — Quest scripts never receive that event
; (Actor/alias-only). SeverActions_Init's InitializeBridge() calls
; Maintenance() on every load instead.

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick - replaces the FORM-keyed
     RegisterForSingleUpdate (canonical explanation: the Chronometer block in
     SeverActionsNativeExt2.psc + the CLAUDE.md lesson). Event name AND
     callback name are unique per script - both, always. Re-arm replaces the
     pending tick; ticks do NOT survive save/load (load paths re-arm); at
     most one already-in-flight wake can land after Cancel/Clear, so keep
     the handler state-guarded.}
    RegisterForModEvent("SeverActions_Tick_Fertility", "OnChronoTick_Fertility")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Fertility", afSeconds)
EndFunction

Event OnChronoTick_Fertility(String eventName, String strArg, Float numArg, Form sender)
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
    ChronoArm(UpdateInterval)
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

    ; Scan cadence floor: fertility state changes over game DAYS (cycle day,
    ; pregnancy progress) — a 3s poll bought nothing but log noise, since every
    ; read of an FM array that happens to be None logs a cast error the bridge
    ; can neither prevent nor silence (FM-internal). 60s keeps prompt data
    ; effectively fresh at 1/20th the reads. Applied HERE, not at the property
    ; default, because Auto property defaults bake into existing saves — the
    ; floor is what upgrades a save carrying the old 3.0.
    if UpdateInterval < 60.0
        UpdateInterval = 60.0
    endif

    ; Start the update loop
    ChronoArm(UpdateInterval)
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

    ; No narration on insemination — intentional. Data above is still
    ; recorded for prompt/decorator access.

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

Function UpdateActorFertilityData(Actor akActor, Form[] akTrackedActors = None)
    ; Is3DLoaded guards the transient-actor CTD window: an actor mid-detach during a
    ; cell transition passes the !akActor check but null-derefs inside the
    ; FM_SetActorData native below. NPCs arrive pre-filtered by
    ; Native_ScanPlayerCellFemales3DLoaded, but the player branch (and any future
    ; caller) is not — so this is the final gate right before the native. Skipping a
    ; transient actor is harmless: the 3s scan re-reads them once they settle.
    ; (|| short-circuits, so Is3DLoaded is never called on a None akActor.)
    if !akActor || !akActor.Is3DLoaded() || !bInitialized || !FertStorage
        return
    endif

    ; TrackedActors: prefer the list UpdateNearbyActors already read this scan
    ; (passed in) so we do NOT re-trigger FM's throwing getter once per actor — that
    ; per-actor repetition was the bulk of the "Cannot cast from None to Form[]"
    ; spam. Fall back to a direct read only for a caller that didn't supply it.
    ; Truthiness (`!arr`), never `== None` — the equality form does not detect a
    ; None array (field-proven 2026-08-30; see the scan-level guard).
    Form[] trackedActors = akTrackedActors
    if !trackedActors
        trackedActors = FertStorage.TrackedActors
    endif
    if !trackedActors || trackedActors.Length == 0
        return
    endif

    ; Find actor in FM's tracked array
    int actorIndex = trackedActors.Find(akActor)
    if actorIndex == -1
        return
    endif

    ; Extract raw data from FM arrays.
    ; Cache each array locally to avoid repeated property access and potential
    ; "Cannot cast from None to <type>[]" errors if FM is mid-reinitialization.
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

    ; Suppress the whole scan during a cell transition. The player — and the actors
    ; around them — can be mid-detach, which is the CTD window the FM_SetActorData
    ; native falls into. The chronometer re-arm in OnChronoTick_Fertility fires
    ; unconditionally AFTER this call, so a skipped tick simply retries next interval.
    if !PlayerRef || !PlayerRef.Is3DLoaded()
        return
    endif

    ; None-read backoff: when FM has nothing tracked, its TrackedActors getter
    ; logs one "Cannot cast from None to Form[]" per read (FM-internal, benign,
    ; caught below — present with bone-stock SA too). Reading every 3s turned
    ; that into steady log spam, so after a None read the whole scan sleeps 60s
    ; before probing again. Real time, session-local; resets naturally on load.
    if fNoneReadBackoffUntil > 0.0 && Utility.GetCurrentRealTime() < fNoneReadBackoffUntil
        return
    endif

    ; Read FM's tracked-actor list ONCE per scan and gate everything on it — one
    ; potential log line per scan instead of one per female, and the cached list
    ; is passed down to UpdateActorFertilityData so it never re-triggers the
    ; getter. NOTE deliberately NO FertStorage.UpdateStorage() call here: an
    ; earlier revision called it per scan to heal FM's parallel-array desync, but
    ; the INSTALLED FM Reloaded (v1.0.3) re-initializes its SpawnedChildActorRefs
    ; array on EVERY UpdateStorage call whenever its length disagrees with
    ; AdultChildren (an FM-internal cap bug we cannot fix from here), so a per-
    ; scan call churned FM-owned state every 3s (field log 2026-08-30). FM's own
    ; handler calls UpdateStorage at load/its own cadence — array sizing is its
    ; job, not the bridge's.
    ; TRUTHINESS, not == None: field-proven 2026-08-30 that `arr == None` does
    ; NOT detect a None array in Papyrus — execution sailed past this guard with
    ; a None list every scan, so the backoff never armed and the per-actor calls
    ; each logged their own cast error. `if !arr` is the form the per-field
    ; guards already use, and the one that works.
    Form[] trackedActors = FertStorage.TrackedActors
    if !trackedActors || trackedActors.Length == 0
        fNoneReadBackoffUntil = Utility.GetCurrentRealTime() + 300.0
        return
    endif

    ; Update player if female
    if PlayerRef.GetActorBase().GetSex() == 1
        UpdateActorFertilityData(PlayerRef, trackedActors)
    endif

    ; Update nearby female NPCs. The cell scan + female + Is3DLoaded filter
    ; now lives in C++ (Native_ScanPlayerCellFemales3DLoaded) to avoid the
    ; per-tick GetNumRefs(43) + GetNthRef + GetSex + Is3DLoaded round-trips at
    ; UpdateInterval (60s floor). UpdateActorFertilityData stays Papyrus — it reads FM's
    ; external store.
    Actor[] females = SeverActionsNativeExt.Native_ScanPlayerCellFemales3DLoaded()
    if females
        int i = 0
        while i < females.Length
            UpdateActorFertilityData(females[i], trackedActors)
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
