Scriptname SeverActions_Init extends ReferenceAlias
{The kernel's load manager, on alias 0 (the player) of quest 0x000D62: the only script that gets
 OnPlayerLoadGame (quest scripts never do) and, on VR, the only Papyrus door of a new game (F21).
 Every load and new game runs K0 the DLL ABI handshake, K1 the kernel seeds and prompt mirrors,
 K2 provider discovery, K3 the providers' OnModuleLoad stages 0-2 (every module's load recovery and
 first-time setup, idempotent, DR20) and K4 the chronometer watchdog. Init names no module or
 Legacy-shim type (DR1); the menu keys and the MCM's old load duties are the DLL's (KernelSession).}

; === Initialization ===

; K0: bumped together with the DLL's KernelSession::kAbiVersion whenever a native's signature or
; meaning changes in a way an older pex must not run against. 23: FollowerManager calls Sched_HoldYield,
; Sched_NoteHold and Sched_GetAssignedRows, and Sched_GetTransitionDue returns relax-only NPCs; an older
; DLL has neither.
Int Property KERNEL_ABI = 23 AutoReadOnly

Event OnInit()
    Debug.Trace("[SeverActions] OnInit - First time initialization")
    ; The native session-start tasks (settings replay, cosave re-seats, seeds) run from SKSE's
    ; kNewGame, which SKSEVR never sends: a VR new game gets them only here. They run once per
    ; session, so this is a no-op where kNewGame already ran them (R15).
    SeverActionsNativeExt2.Kernel_OnSessionStart()
    ; Let the quest scripts' OnInit run first.
    Utility.Wait(0.5)
    Initialize(true)
EndEvent

Event OnPlayerLoadGame()
    ; First opcode of the load, so a watchdog OnUpdate persisted in the save finds it disarmed
    ; (see WatchdogArmed; Initialize resets the rest).
    WatchdogArmed = false
    Debug.Trace("[SeverActions] OnPlayerLoadGame - Save game loaded")
    Initialize(false)
EndEvent

Function Initialize(Bool isFirstInit)
    Debug.Trace("[SeverActions] Initializing SeverActions...")

    ; Disarm the watchdog first: its state and pending update persist in a save (see WatchdogArmed).
    UnregisterForUpdate()
    WatchdogKicked = false
    WatchdogArmed = false
    WatchdogInitBase = 0
    WatchedTicks = new String[1]
    WatchedOwners = new String[1]
    WatchedBase = new Int[1]
    WatchedCount = 0

    ; K0 ABI handshake. The box text is a literal: the localization table lives in the DLL that is
    ; missing or stale here.
    Int abi = SeverActionsNativeExt2.Kernel_AbiVersion()
    If abi != KERNEL_ABI
        String abiMsg
        ; 0 = no DLL, or one from before the handshake (the public 3.9.14 and beta25 DLLs), where the
        ; native is unbound and returns the default. Nothing can tell those apart, so one text.
        If abi == 0
            abiMsg = "SeverActions: SeverActionsNative.dll is missing, did not load, or is older than this version's scripts. Reinstall SeverActions with Replace so the DLL and the scripts come from the same build, and check the SKSE log if the box comes back."
        Else
            abiMsg = "SeverActions: SeverActionsNative.dll does not match this version's scripts (DLL kernel ABI " + abi + ", scripts expect " + KERNEL_ABI + "). Reinstall SeverActions with Replace so the DLL and the scripts come from the same build."
        EndIf
        Debug.MessageBox(abiMsg)
        Debug.Trace("[SeverActions] K0 ABI handshake failed: DLL " + abi + ", scripts " + KERNEL_ABI + " - initialization stopped")
        Return
    EndIf

    ; SkyrimNet API floor: the DLL dispatches the quest-awareness summaries on API v8+ and the
    ; completion memories on v5+, so below v8 the summaries are off - said on every load.
    ; 0 = SkyrimNet not loaded.
    Int snApi = SeverActionsNativeExt2.Kernel_SkyrimNetApiVersion()
    If snApi > 0 && snApi < 8
        String floorMsg
        If snApi >= 5
            floorMsg = "SeverActions: SkyrimNet API v" + snApi + " is below the v8 floor - followers' quest summaries are off (completion notes still land) until SkyrimNet is updated"
        Else
            floorMsg = "SeverActions: SkyrimNet API v" + snApi + " is below the v8 floor - followers' quest summaries and completion memories are off until SkyrimNet is updated"
        EndIf
        Debug.Notification(floorMsg)
        Debug.Trace("[SeverActions] " + floorMsg)
    EndIf

    ; K1: the 'CAIO' seed, before any subsystem classifies a follower (so no track-only memo needs
    ; invalidating).
    SeedCustomAIOverrides()
    ; K1: the StorageUtil-hosted settings rows into the Authority, then the prompt mirrors (M-X);
    ; live changes arrive on SeverActions_SettingsMirror.
    SeedSettingsFromStorageUtil()
    RegisterForModEvent("SeverActions_SettingsMirror", "OnSettingsMirror_Init")
    ; UI item transfers are the kernel's: the Inventory page that raises them is a kernel surface and
    ; stays installed when the module that would own them is absent.
    RegisterForModEvent("SeverActions_MagelightItemMoved", "OnPrismaItemMoved")
    WriteSettingsMirrors()

    ; The menu needs nothing from Papyrus (the DataGatherer resolves its own quest refs) and is
    ; usable by now, so say so early.
    Debug.Notification(SeverActionsNativeExt2.Native_L10n("init.severActionsMenuReady"))

    ; K2 + K3: every module's load work runs from its provider, stage by stage in ProviderBundleIds
    ; order (see SeverActions_ModuleBase). Cross-module orders are stage placements: Travel's recovery
    ; first, from travelcore's stage 1 (R23); FollowerManager's recovery at stage 2, after Arrest's and
    ; Travel's; Outfit at stage 2, after the roster.
    String[] bound = DiscoverProviders()
    RunProviderStages(bound, isFirstInit)

    ; K4: the chronometer watchdog.
    ArmWatchdog(bound)

    ; Mirrors again: the kPostLoadGame replays are not ordered against this event and may have fed
    ; rows during the K1 pass; this closes the window a late feed left.
    WriteSettingsMirrors()

    ; Last, so timing audits read it as the completion time.
    Debug.Trace("[SeverActions] Initialization complete!")
EndFunction

; === K2: provider discovery ===

String[] Function DiscoverProviders()
    {Returns the provider ids whose alias on 0x000D62 holds a bound provider answering its own id and
     this kernel's contract, and reports them to the registry (Module_ReportBound). Reaches a provider
     only through SeverActions_ModuleBase.Provider, never its own type.}
    String[] ids = SeverActions_ModuleBase.ProviderBundleIds()
    String[] bound = new String[16]
    Int n = 0
    Int i = 0
    While i < ids.Length
        String id = ids[i]
        SeverActions_ModuleBase p = SeverActions_ModuleBase.Provider(id)
        If !p
            Debug.Trace("[SeverActions] K2 provider " + id + ": not bound (alias " + SeverActions_ModuleBase.ProviderAliasId(id) + ")")
            ; An installed module (every one, in Legacy) without its provider pex is a broken install:
            ; its load work is skipped, so say so.
            If SeverActionsNativeExt2.Module_IsUsable(id)
                Debug.Notification("SeverActions: module '" + id + "' is installed but its provider script did not load - reinstall with Replace")
            EndIf
        ElseIf p.BundleId() != id
            Debug.Trace("[SeverActions] K2 provider " + id + ": alias " + SeverActions_ModuleBase.ProviderAliasId(id) + " answers '" + p.BundleId() + "' - skipped")
        ElseIf p.ContractVersion() != p.kContractVersion
            Debug.Trace("[SeverActions] K2 provider " + id + ": contract " + p.ContractVersion() + ", kernel " + p.kContractVersion + " - skipped")
        ElseIf n < bound.Length
            bound[n] = id
            n += 1
        EndIf
        i += 1
    EndWhile
    ; Zero providers is a one-element array holding "": a never-assigned array is None, which must
    ; never reach a native (B-36). The stages and the registry skip an empty id.
    String[] result
    If n > 0
        result = Utility.ResizeStringArray(bound, n)
        Debug.Trace("[SeverActions] K2: " + n + " of " + ids.Length + " providers bound")
    Else
        result = new String[1]
        Debug.Trace("[SeverActions] K2: no provider bound - no module installed (or every provider pex missing)")
        Debug.Notification("SeverActions: no modules installed")
    EndIf
    SeverActionsNativeExt2.Module_ReportBound(result)
    Return result
EndFunction

; === K3: the provider stages ===

Function RunProviderStages(String[] asBound, Bool abNewGame)
    {Stage 0, then 1, then 2, each over every bound provider in the static
     order. Every stage is idempotent and runs on every load and new game: a
     module's first-time setup on an existing save is simply its first pass.}
    If !asBound
        Return
    EndIf
    Int stage = 0
    While stage <= 2
        Int i = 0
        While i < asBound.Length
            If asBound[i] != ""
                SeverActions_ModuleBase p = SeverActions_ModuleBase.Provider(asBound[i])
                If p
                    p.OnModuleLoad(stage, abNewGame)
                EndIf
            EndIf
            i += 1
        EndWhile
        Debug.Trace("[SeverActions] K3 stage " + stage + " complete (" + asBound.Length + " providers)")
        stage += 1
    EndWhile
EndFunction

; === K1: kernel seeds and prompt mirrors ===

Function SeedCustomAIOverrides()
    {Seed the 'CAIO' record (the "treat as a normal follower" overrides) once per save from the
     StorageUtil list SeverActions_CustomAIOverrideList, under a 'MIGR' claim (DR14). Seeding only
     adds, so a cleared override never returns through here. FollowerManager.ReconcileCustomAIOverrides
     still pushes the list on every load as a belt (R2).}
    String mig = "CustomAIOverrideSeed"
    Int migVersion = 1
    If SeverActionsNativeExt2.Migration_IsDone(mig, migVersion)
        Return
    EndIf
    If !SeverActionsNativeExt2.Migration_TryClaim(mig, migVersion)
        ; Claimed by another caller this session (none today); the claimant records done. (A DLL
        ; without the ledger never gets here: K0 stops Initialize first.)
        Return
    EndIf
    Int n = StorageUtil.FormListCount(None, "SeverActions_CustomAIOverrideList")
    Int seeded = 0
    Int i = 0
    While i < n
        Actor ovA = StorageUtil.FormListGet(None, "SeverActions_CustomAIOverrideList", i) as Actor
        If ovA && SeverActionsNativeExt2.CustomAI_SeedOverride(ovA)
            seeded += 1
        EndIf
        i += 1
    EndWhile
    SeverActionsNativeExt2.Migration_MarkDone(mig, migVersion)
    Debug.Trace("[SeverActions] K1 custom-AI override seed done: " + seeded + " of " + n + " listed actor(s) added to the native record")
EndFunction

Function SeedSettingsFromStorageUtil()
    {K1 (R21): seed the Settings Authority from the rows whose per-save value lives only in
     StorageUtil; Settings_PendingSeeds lists the rows this save lacks as "key|storageKey|type|holder".
     The seeding rules (once per save, the global file wins, a claim per row) are
     Settings_SeedFromStorageUtil's.}
    String[] pending = SeverActionsNativeExt2.Settings_PendingSeeds()
    Int seeded = 0
    Int i = 0
    While i < pending.Length
        String[] parts = StringUtil.Split(pending[i], "|")
        If parts.Length == 4
            String rowKey = parts[0]
            String storageKey = parts[1]
            String typ = parts[2]
            Form holder = None
            If parts[3] == "quest"
                holder = GetOwningQuest()
            EndIf
            String value = ""
            Bool has = false
            If typ == "float"
                has = StorageUtil.HasFloatValue(holder, storageKey)
                If has
                    value = "" + StorageUtil.GetFloatValue(holder, storageKey)
                EndIf
            ElseIf typ == "string"
                has = StorageUtil.HasStringValue(holder, storageKey)
                If has
                    value = StorageUtil.GetStringValue(holder, storageKey)
                EndIf
            Else
                has = StorageUtil.HasIntValue(holder, storageKey)
                If has
                    If typ == "bool"
                        If StorageUtil.GetIntValue(holder, storageKey) != 0
                            value = "true"
                        Else
                            value = "false"
                        EndIf
                    Else
                        value = "" + StorageUtil.GetIntValue(holder, storageKey)
                    EndIf
                EndIf
            EndIf
            If has && SeverActionsNativeExt2.Settings_SeedFromStorageUtil(rowKey, value)
                seeded += 1
            EndIf
        EndIf
        i += 1
    EndWhile
    Debug.Trace("[SeverActions] K1 settings seed: " + seeded + " of " + pending.Length + " StorageUtil-hosted row(s) seeded into the Authority")
EndFunction

Function WriteSettingsMirrors()
    {K1 (M-X): write every prompt-mirror StorageUtil key of an installed owner from the Settings
     Authority (the rows come from Settings_MirrorRows, which leaves out a row whose mirror slot is
     its own seed source until it is settled). Prompts read them through papyrus_util, which C++
     cannot write.}
    String[] mirrors = SeverActionsNativeExt2.Settings_MirrorRows()
    Int i = 0
    While i < mirrors.Length
        WriteSettingsMirror(mirrors[i])
        i += 1
    EndWhile
EndFunction

Function WriteSettingsMirror(String asRow)
    {One mirror row "key|storageKey|type": the StorageUtil key takes the
     Authority's value (a Bool as 0/1, an Int, a Float, a String; holder None).}
    String[] parts = StringUtil.Split(asRow, "|")
    If parts.Length != 3
        Return
    EndIf
    String rowKey = parts[0]
    String storageKey = parts[1]
    String typ = parts[2]
    If typ == "bool"
        StorageUtil.SetIntValue(None, storageKey, SeverActionsNativeExt2.Settings_GetBool(rowKey) as Int)
    ElseIf typ == "int"
        StorageUtil.SetIntValue(None, storageKey, SeverActionsNativeExt2.Settings_GetInt(rowKey))
    ElseIf typ == "float"
        StorageUtil.SetFloatValue(None, storageKey, SeverActionsNativeExt2.Settings_GetFloat(rowKey))
    Else
        StorageUtil.SetStringValue(None, storageKey, SeverActionsNativeExt2.Settings_GetString(rowKey))
    EndIf
EndFunction

Event OnSettingsMirror_Init(String eventName, String strArg, Float numArg, Form sender)
    {SeverActions_SettingsMirror (strArg = the row), sent by the DLL on every live change of a
     mirrored setting. The callback name is unique to the kernel.}
    WriteSettingsMirror(strArg)
EndEvent

; === Safe-exit stubs of the old shim inits (see Safe-exit stubs below) ===

Function InitializeHotkeySystem()
    ; M-I-STUB 3.9.14-beta25 (P4-04): the DLL matches the hotkey codes (P4-02) and syncs the config-menu key with
    ; the settings file at session start (KernelSession); an older build's key registrations stay in the save
    ; unheard (no OnKeyDown remains on quest 0x000D62).
EndFunction

Function InitializeWheelMenuSystem()
    ; M-I-STUB 3.9.14-beta25 (P4-04): the DLL owns the wheel key (P4-03) and syncs it with the settings file at
    ; session start (KernelSession).
EndFunction

; === K4: chronometer watchdog (R13) ===
; Every periodic system re-arms from its own tick handler, so a stale or missing DLL stops them all
; with only a papyrus log line to show. This alias-hosted engine timer (legal here: Init owns its
; form handle) checks ~90 s after load, by the service's per-name acknowledged-tick counts
; (Chrono_TickCountSinceLoad, reset on every load). Watched: the tick names the bound providers
; return from ChronoTickNames(), always-on chains only (an on-demand chain's zero is normal). A
; module chain's zero alone does not implicate the DLL (a live service can lose a first tick), so
; Init also arms its own probe; only a probe that never lands, even after a re-arm, boxes. The
; timer is armed before the probe request, which may be an unbound native.

Function ArmWatchdog(String[] asBound)
    {Collect the bound providers' tick names, arm the timer and the probe.}
    String[] names = new String[16]
    String[] owners = new String[16]
    Int n = 0
    Int i = 0
    While asBound && i < asBound.Length
        If asBound[i] != ""
            SeverActions_ModuleBase p = SeverActions_ModuleBase.Provider(asBound[i])
            If p
                String[] ticks = p.ChronoTickNames()
                Int t = 0
                While ticks && t < ticks.Length
                    If ticks[t] != "" && n < names.Length
                        names[n] = ticks[t]
                        owners[n] = asBound[i]
                        n += 1
                    EndIf
                    t += 1
                EndWhile
            EndIf
        EndIf
        i += 1
    EndWhile
    WatchedTicks = names
    WatchedOwners = owners
    WatchedBase = new Int[16]
    WatchedCount = n
    WatchdogKicked = false
    WatchdogArmed = true
    RegisterForSingleUpdate(90.0)
    ArmChronoProbe()
    Debug.Trace("[SeverActions] K4 watchdog armed over " + n + " tick name(s)")
EndFunction

; Set once OnUpdate has restarted the dead chains; the next pass judges.
Bool WatchdogKicked = false
; True from ArmWatchdog to the verdict. It persists in a save together with the pending update, and
; a stale OnUpdate on reload would judge counts the revert zeroed and box on a healthy install. So
; OnPlayerLoadGame and Initialize clear it first thing, and the verdict re-checks it after a 1 s wait.
Bool WatchdogArmed = false
; Init's probe count after the first pass re-arms it. A Chrono_Request answering a fired tick counts
; as its ack, and the kicks and the re-arm are requests, so the second pass judges growth past this
; and WatchedBase, not > 0.
Int WatchdogInitBase = 0
; The watched chains (tick name, owning provider id, base count) in up to 16 slots. They persist in
; the save; Initialize resets them and ArmWatchdog refills them every load.
String[] WatchedTicks
String[] WatchedOwners
Int[] WatchedBase
Int WatchedCount = 0

Function ArmChronoProbe()
    {Request a one-shot chronometer tick for Init itself. Event and callback
     names are unique to this script (the Chronometer naming rule).}
    RegisterForModEvent("SeverActions_Tick_Init", "OnChronoTick_Init")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Init", 5.0)
EndFunction

Event OnChronoTick_Init(String eventName, String strArg, Float numArg, Form sender)
    ; The Cancel is the ack the service counts; it also stops the retries.
    SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_Init")
EndEvent

Event OnUpdate()
    {The K4 watchdog. First pass (~90 s): every watched chain with no acknowledged tick since load is
     restarted once through its provider's OnChronoDead (a first-tick ModEvent can be lost to
     post-load congestion) and Init's probe is re-armed. Second pass (~90 s later): a probe that still
     never landed boxes; a chain that stays dead over a live service is only logged. With no watched
     chain the probe alone judges.}
    If !WatchdogArmed
        Return
    EndIf
    Int initCount = SeverActionsNativeExt2.Chrono_TickCountSinceLoad("SeverActions_Tick_Init")
    If !WatchdogKicked
        WatchdogKicked = true
        Int dead = 0
        Int i = 0
        While i < WatchedCount
            If SeverActionsNativeExt2.Chrono_TickCountSinceLoad(WatchedTicks[i]) == 0
                dead += 1
                Debug.Trace("[SeverActions_Init] CHRONOMETER WATCHDOG: " + WatchedTicks[i] + " acknowledged no tick ~90s after load - asking " + WatchedOwners[i] + " to restart the chain (first-tick ModEvent likely lost to load congestion)")
                SeverActions_ModuleBase p = SeverActions_ModuleBase.Provider(WatchedOwners[i])
                If p
                    p.OnChronoDead(WatchedTicks[i])
                EndIf
            EndIf
            i += 1
        EndWhile
        If dead == 0 && WatchedCount > 0
            ; Every watched chain is alive: the service delivers.
            WatchdogArmed = false
            Return
        EndIf
        RegisterForSingleUpdate(90.0)
        If WatchedCount == 0
            Debug.Trace("[SeverActions_Init] CHRONOMETER WATCHDOG: no module chain to watch - judging the service by Init's own probe")
        EndIf
        ; Re-arm the probe even if it landed: its Cancel erased the slot, so this request counts no
        ; phantom ack, and the verdict needs a landing in the second window (count > base).
        ArmChronoProbe()
        ; The kicks and the probe can count as acks: take the bases after them.
        i = 0
        While i < WatchedCount
            WatchedBase[i] = SeverActionsNativeExt2.Chrono_TickCountSinceLoad(WatchedTicks[i])
            i += 1
        EndWhile
        WatchdogInitBase = SeverActionsNativeExt2.Chrono_TickCountSinceLoad("SeverActions_Tick_Init")
        Return
    EndIf
    ; A stale OnUpdate from the save can land here in the first opcodes of a reload: give the load's
    ; OnPlayerLoadGame / Initialize a moment to clear WatchdogArmed, then look again.
    Utility.Wait(1.0)
    If !WatchdogArmed
        Return
    EndIf
    WatchdogArmed = false
    ; A chain that grew past its base proves the service too: never box over a live chain.
    Bool chronoProbeLanded = initCount > WatchdogInitBase
    Bool anyChainAlive = false
    Int i = 0
    While i < WatchedCount
        If SeverActionsNativeExt2.Chrono_TickCountSinceLoad(WatchedTicks[i]) > WatchedBase[i]
            anyChainAlive = true
        EndIf
        i += 1
    EndWhile
    If chronoProbeLanded || anyChainAlive
        i = 0
        While i < WatchedCount
            If SeverActionsNativeExt2.Chrono_TickCountSinceLoad(WatchedTicks[i]) <= WatchedBase[i]
                Debug.Trace("[SeverActions_Init] CHRONOMETER WATCHDOG: the service delivers ticks (" + (initCount > WatchdogInitBase) as String + " probe landed) but " + WatchedTicks[i] + " (" + WatchedOwners[i] + ") never acknowledged one after the restart - not a DLL problem, no warning")
            EndIf
            i += 1
        EndWhile
        Return
    EndIf
    ; The L10n table lives in the DLL this box is about: a missing DLL returns "", one without the
    ; key returns the key. The fallback stays byte-identical to the en entry in SeverActions_L10n.json.
    String msgKey = "init.periodicTickNeverStarted"
    String msg = SeverActionsNativeExt2.Native_L10n(msgKey)
    If msg == "" || msg == msgKey
        msg = "SeverActions: the periodic tick service never started, and a restart attempt did not take. SeverActionsNative.dll is likely out of date or missing - update it to match this version's scripts, or every periodic system (followers, travel, arrests, survival) will stay frozen."
    EndIf
    Debug.MessageBox(msg)
    Debug.Trace("[SeverActions_Init] CHRONOMETER WATCHDOG: Init's own chronometer probe never landed, even after a re-arm - stale or missing SeverActionsNative.dll")
EndEvent

; === Safe-exit stubs of the old shim and MCM inits (see Safe-exit stubs below) ===

Function InitializePrismaUI()
    ; M-I-STUB 3.9.14-beta25 (P4-10, R8 CLOSED): this cast the quest to the Legacy shim
    ; SeverActions_PrismaUI and called RegisterForPrismaEvents on it. Never name a shim type in the
    ; kernel again: a Modular install carries no shims, and a kernel script naming one fails to link
    ; on the stock VM and takes all of Init with it (F3/F31, D43).
EndFunction

Function SyncMCMSettings()
    ; M-I-STUB 3.9.14-beta25 (P4-04, C8/R8): the Settings Authority's per-save replay pushes the RAM-only natives
    ; (dialogueAnimEnabled, outfitStabilityDelay, furnitureAutoStandDistance), Init's M-X service writes the prompt
    ; mirrors, the courier registration is SeverActions_Courier.Maintenance's and the MCM reads the Authority.
EndFunction

; === Safe-exit stubs (M-I, R17) ===
; A save made while the old Initialize was running resumes its SAVED bytecode on this alias and
; calls these by name (F7). Each is a void no-op with no typed local, so the old frame walks through
; them; their work runs from the providers (K3) on the same load. The Get<X>System getters are gone:
; only the old bodies of these stubs called them, and a call to a missing function returns None and
; continues (F2).
; The old frame also reads the deleted LootSystem property after InitializeHearthCamp; whether the VM
; yields None or drops the frame there, nothing after it is unique to that frame. Check 20 forbids
; removing a marked stub.

Function RegisterDecorators()
    ; M-I-STUB 3.9.14-beta25 (P3-04): the SLO and Fertility decorators register from their providers' stage 0.
EndFunction

Function InitializeBridge()
    ; M-I-STUB 3.9.14-beta25 (P3-04): the fertility provider's stages 0 and 1.
EndFunction

Function InitializeTravelSystem(Bool isFirstInit)
    ; M-I-STUB 3.9.14-beta25 (P3-04): the travel provider's stage 1 (the recovery itself runs from travelcore, R23).
EndFunction

Function InitializeFurnitureSystem()
    ; M-I-STUB 3.9.14-beta25 (P3-04): the travel provider's stage 1.
EndFunction

Function InitializeFollowSystem()
    ; M-I-STUB 3.9.14-beta25 (P3-04): the followers provider's stage 1.
EndFunction

Function InitializeFollowerManagerSystem()
    ; M-I-STUB 3.9.14-beta25 (P3-04): the followers provider's stage 1.
EndFunction

Function InitializeDebtSystem()
    ; M-I-STUB 3.9.14-beta25 (P3-04): the economy provider's stage 1.
EndFunction

Function InitializeArrestSystem()
    ; M-I-STUB 3.9.14-beta25 (P3-04): the arrest provider's stage 1.
EndFunction

Function RunLoadRecovery()
    ; M-I-STUB 3.9.14-beta25 (P3-04): the providers' stages 1 and 2 and ArmWatchdog.
EndFunction

Function InitializeSpellTeachSystem()
    ; M-I-STUB 3.9.14-beta25 (P3-04): the items provider's stage 1.
EndFunction

Function InitializeSurvivalSystem()
    ; M-I-STUB 3.9.14-beta25 (P3-04): the survival provider's stage 1.
EndFunction

Function InitializeHearthCamp()
    ; M-I-STUB 3.9.14-beta25 (P3-04): Hearth heals its own load recovery (the R24 belt, P3-03); the kernel names no Hearth type.
EndFunction

; Removed functions that shipped in v3.9.14-beta25, kept for a suspended frame that calls them by
; name (F7). Never remove one; the registry is fomod/safe_exit_stubs.json.

Function SyncPluginConfig()
    {Safe-exit stub: unreachable at beta25, kept because check 20's union rule does not read call sites.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): unreachable at beta25 (call sites commented out), deleted by P2-08 (c98e4cb3)
EndFunction


; === UI item transfers ===

Event OnPrismaItemMoved(String eventName, String strArg, Float numArg, Form sender)
    {Registers an item the player moved on the Inventory page (transferItems) or granted from the
     Catalog (giveItem) as an item_given / item_taken event, as the spoken GiveItem / TakeItem
     actions do: SkyrimNet's own container_changed event for these is ephemeral and reaction-free.
     strArg = "fromFid|toFid|itemFid|count", FormIDs as signed decimal (never float numArg, the
     2^24 rule); fromFid 0 = the catalog.}
    Int fromFid = SeverActions_ModuleBase.VerbField(strArg, 0) as Int
    Int toFid   = SeverActions_ModuleBase.VerbField(strArg, 1) as Int
    Int itemFid = SeverActions_ModuleBase.VerbField(strArg, 2) as Int
    Int count   = SeverActions_ModuleBase.VerbField(strArg, 3) as Int
    Form item = Game.GetFormEx(itemFid)
    Actor toActor = Game.GetFormEx(toFid) as Actor
    If !item || !toActor
        Return
    EndIf
    Actor player = Game.GetPlayer()
    Actor fromActor = None
    If fromFid != 0
        fromActor = Game.GetFormEx(fromFid) as Actor
    EndIf
    If fromActor == None
        fromActor = player   ; a catalog grant is the player's gift
    EndIf
    ; A Catalog grant to the player (from 0, read as the player; the Catalog's default target) is a
    ; spawn, not a hand-over: it would log "<player> took N <item> from <player>".
    If fromActor == toActor
        Return
    EndIf
    ; The player's renamed/enchanted piece keeps the name they gave it - a
    ; base FormID does not identify an item.
    String itemName = item.GetName()
    String customName = SeverActionsNativeExt2.GetCustomItemName(toActor, item)
    If customName != ""
        itemName = customName
    EndIf
    String qty = ""
    If count > 1
        qty = count + " "
    EndIf
    If toActor == player
        SkyrimNetApi.RegisterEvent("item_taken", player.GetDisplayName() + " took " + qty + itemName + " from " + fromActor.GetDisplayName(), player, fromActor)
    Else
        SkyrimNetApi.RegisterEvent("item_given", fromActor.GetDisplayName() + " gave " + qty + itemName + " to " + toActor.GetDisplayName(), fromActor, toActor)
    EndIf
EndEvent
