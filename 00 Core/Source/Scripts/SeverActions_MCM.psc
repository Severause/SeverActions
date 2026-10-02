Scriptname SeverActions_MCM extends SKI_ConfigBase
{The MCM, rendered from the layout table (M-D): OnPageReset draws the rows Mcm_PageRows serves (generated
 Native/src/McmLayout.h) and each option event maps the clicked option back to its row, whose setting contract
 says how to read and write it. Hand-written because no table holds them: GateOpen, ComputedLabel / ComputedValue,
 the Do*Action dispatchers and the Modular-only Modules page. The MCM names no module type (D34, check 17):
 presence comes from Module_IsUsable, state from natives, Papyrus-only reads and redrawn actions from the
 synchronous provider services (DR13), and fire-and-forget writes go through Verb_Send.}

; =============================================================================
; SETTINGS PROPERTIES: the legacy hosts of the settings table's K/M rows, kept so an old save still has a value to
; migrate. Only the DLL writes them (check 22c fails a Papyrus write); deleting one deletes that save's only copy.
; =============================================================================

; Currency
bool Property AllowConjuredGold = false Auto

; Dialogue animations
bool Property DialogueAnimEnabled = true Auto Hidden
int Property SilenceChance = 50 Auto Hidden

; Mannequin renderer fallback: the UI viewport renders the live NPC as a cutout instead. Read and written by the
; native settings gatherer/handler; no MCM row.
bool Property MannequinRenderDisabled = false Auto Hidden

; Followers auto-stand from furniture at this distance (0 = off). FurnitureManager holds only a volatile copy;
; the Authority's per-save replay pushes it on load.
Float Property FurnitureAutoStandDistance = 500.0 Auto Hidden

; Outfit auto-switch stability threshold in SECONDS; the native takes milliseconds (the row's liveApply scale is
; 1000) and is RAM-only, so the Authority replays it.
Float Property FMStabilityDelay = 5.0 Auto Hidden

; Speaker tags (mirrored to StorageUtil for the prompts by Init's M-X service)
bool Property TagCompanionEnabled = true Auto Hidden
bool Property TagEngagedEnabled = true Auto Hidden
bool Property TagInSceneEnabled = true Auto Hidden

; Inventory limits
int Property InvLimit_Weapons = 10 Auto Hidden
int Property InvLimit_Armor = 10 Auto Hidden
int Property InvLimit_Potions = 10 Auto Hidden
int Property InvLimit_Ingredients = 5 Auto Hidden
int Property InvLimit_Books = 10 Auto Hidden
int Property InvLimit_Scrolls = 5 Auto Hidden
int Property InvLimit_Ammo = 5 Auto Hidden
int Property InvLimit_Keys = 5 Auto Hidden
int Property InvLimit_Misc = 5 Auto Hidden

; Hotkey codes. The DLL's input sink matches the Authority's codes; these are the legacy hosts.
int Property FollowToggleKey = -1 Auto Hidden
int Property DismissKey = -1 Auto Hidden
int Property StandUpKey = -1 Auto Hidden
int Property UseFurnitureKey = -1 Auto Hidden
int Property YieldKey = -1 Auto Hidden
int Property UndressKey = -1 Auto Hidden
int Property DressKey = -1 Auto Hidden
int Property SetCompanionKey = -1 Auto Hidden
int Property CompanionWaitKey = -1 Auto Hidden
int Property AssignHomeKey = -1 Auto Hidden
int Property ClearHomeKey = -1 Auto Hidden
int Property SetupCampKey = -1 Auto Hidden
int Property DropMarkerKey = -1 Auto Hidden
int Property TieUntieKey = -1 Auto Hidden
int Property TargetMode = 0 Auto Hidden
float Property NearestNPCRadius = 500.0 Auto Hidden

; Quick wheel
int Property WheelMenuKey = -1 Auto Hidden

; Config menu (opens the Magelight/PrismaUI config view)
int Property ConfigMenuKey = -1 Auto Hidden
bool Property ConfigMenuRequireShift = true Auto Hidden

; The Enterprises debug harness; must not ship enabled (ENTERPRISES.md). While on, the layout's enterprisesDebug
; variant page is drawn instead of the Enterprises page.
bool Property EnableEnterpriseDebug = false Auto

; =============================================================================
; ROW PAYLOAD: one pipe-delimited string per row, decoded with SeverActions_ModuleBase.VerbField. The indices
; mirror McmPayload::Field (Native/src/McmPayloadCore.h), which only appends: an insert would shift every index here.
; =============================================================================

Int Property ROW_TYPE = 0 AutoReadOnly          ; header | empty | text | setting | keymap | action | dynamic | state
Int Property ROW_CONTROL = 1 AutoReadOnly       ; "" | toggle | slider | menu | keymap | button
Int Property ROW_ID = 2 AutoReadOnly            ; settings key / hotkey id / action id
Int Property ROW_SOURCE = 3 AutoReadOnly        ; a dynamic row's list
Int Property ROW_LABEL = 4 AutoReadOnly
Int Property ROW_VALUE = 5 AutoReadOnly         ; "" when the value is built at draw time
Int Property ROW_FORMAT = 6 AutoReadOnly        ; a slider's format string
Int Property ROW_TOOLTIP = 7 AutoReadOnly
Int Property ROW_VERB = 8 AutoReadOnly
Int Property ROW_FLAGS = 9 AutoReadOnly
Int Property ROW_SMIN = 10 AutoReadOnly
Int Property ROW_SMAX = 11 AutoReadOnly
Int Property ROW_SSTEP = 12 AutoReadOnly
Int Property ROW_SDEF = 13 AutoReadOnly         ; where the slider DIALOG opens
Int Property ROW_MENULIST = 14 AutoReadOnly     ; a compile-time option list (Mcm_MenuOptions)
Int Property ROW_MENUSOURCE = 15 AutoReadOnly   ; a RUNTIME option list (a dynamic source)
Int Property ROW_GATES = 16 AutoReadOnly        ; comma-joined atoms, '!' negating one
Int Property ROW_TIER = 17 AutoReadOnly         ; K | M | P
Int Property ROW_READ = 18 AutoReadOnly         ; authority | property
Int Property ROW_WRITE = 19 AutoReadOnly        ; handler | set | property
Int Property ROW_HOST = 20 AutoReadOnly         ; "Script.Property"
Int Property ROW_VALUETYPE = 21 AutoReadOnly    ; bool | int | float | string
Int Property ROW_HANDLERPAGE = 22 AutoReadOnly
Int Property ROW_LIVECALL = 23 AutoReadOnly
Int Property ROW_LIVESCALE = 24 AutoReadOnly
Int Property ROW_CLAMPSIB = 25 AutoReadOnly
Int Property ROW_CLAMPRULE = 26 AutoReadOnly    ; raisesMax | lowersMin
Int Property ROW_DEFAULT = 27 AutoReadOnly      ; what the Reset key restores (the table's DR18 default)

Int Property FLAG_CONFIRM = 1 AutoReadOnly
Int Property FLAG_DISABLED = 2 AutoReadOnly
Int Property FLAG_CONDITIONAL = 4 AutoReadOnly
Int Property FLAG_COMPUTEDVALUE = 8 AutoReadOnly
Int Property FLAG_DISABLEDWHEN = 16 AutoReadOnly
Int Property FLAG_LIVEREFRESH = 32 AutoReadOnly
Int Property FLAG_COMPUTEDLABEL = 64 AutoReadOnly

; SkyUI's ceiling: AddOption advances the cursor by the fill mode and returns -1 silently from slot 128 on.
; TOP_TO_BOTTOM (2) fills the even slots, so the left column holds 64 rows and SetCursorPosition(1) starts the
; right one (as SKI_ConfigMenu does). A row past 128 is logged, not dropped silently.
Int Property SKYUI_COLUMN_ROWS = 64 AutoReadOnly
Int Property SKYUI_MAX_ROWS = 128 AutoReadOnly

; =============================================================================
; RENDERER STATE  (per page reset - never read outside the page it was built for)
; =============================================================================

String _pageId                  ; the layout page being drawn ("" before the first reset)
String[] _rows                  ; its row payloads, in draw order
String[] _sources               ; the dynamic-source table, fetched once per menu session (see SourceField)
Int[] _slotRow                  ; option slot -> index into _rows, -1 when the slot is not ours
Int[] _slotEntry                ; option slot -> the dynamic entry that slot draws, -1 on a static row
Int _optionsUsed                ; how many options this reset has spent (the ceiling bookkeeping)
Int _optionsDropped
String _modulesPageLabel        ; the Modules page's name in Pages, "" outside Modular (BuildPageList)
Int _leftoverSlot = -1          ; the Modules page's leftover-files line (its info text is the whole sentence), -1 when not drawn
String _leftoverInfo

; =============================================================================
; PAGE STATE  (rebuilt by RefreshPageState before the rows are drawn)
; =============================================================================

; Followers
Actor[] CachedManagedFollowers
String[] CachedPresetNames
int SelectedCompanionIdx = 0
Actor _selCompanion
String _selCompanionHome
String _selCompanionSituation

; Outfits
Actor[] CachedPresetActors
String[] CachedOutfitPresetNames
int SelectedOutfitNPCIdx = 0
Actor _selPresetActor

; Survival
Actor[] CachedFollowers

; Homes
Actor[] CachedHomedNPCs
Actor[] CachedDismissedFollowers
int SelectedDismissedIdx = 0
Actor _selDismissed

; Economy
int _debtPlayerOwes
int _debtOwedToPlayer
String[] _debtOwesDetails
String[] _debtOwedDetails

; Bio Blocks
string[] BioTabs
int BioTabIdx = 0
string[] BioBlockTitles
int[] BioBlockIds
int BioBlockIdx = 0
Actor BioTargetActor
string[] BioAssignedTitles
int[] BioAssignedIds
string[] BioTargetFactions
string[] BioRuleNames

; Enterprises (debug harness). The option lists are the layout's enterpriseJob / enterpriseArrangement menuLists;
; the picked INDEX goes straight to Venture_DebugAdd, so it must match the enums in VentureStore.h.
int EntJob = 0
int EntArrangement = 0
int EntWage = 200

; =============================================================================
; INITIALIZATION
; =============================================================================

Int Function GetVersion()
    {Override SKI_ConfigBase. SkyUI compares this against the saved version to trigger OnVersionUpdate.}
    Return 124
EndFunction

Event OnConfigOpen()
    ; Rebuilt on every open (SkyUI reads Pages right after this event): OnGameReload never fires on quest
    ; 0x000D62, so SkyUI's OnVersionUpdate never runs. _sources rides the save, so drop it too, or a table an older DLL served would be used for the save's life.
    _sources = PapyrusUtil.StringArray(0)
    BuildPageList()
EndEvent

Event OnConfigInit()
    BuildPageList()
EndEvent

Event OnVersionUpdate(int newVersion)
    Debug.Trace("[SeverActions_MCM] Updating from version " + CurrentVersion + " to " + newVersion)
    BuildPageList()
EndEvent

Function BuildPageList()
    {Build Pages (order and names) from the layout table. A variant page is drawn instead of its base page, so it
     gets no entry of its own.}
    ModName = "SeverActions"
    CurrentVersion = 124
    _modulesPageLabel = ""

    String[] served = SeverActionsNativeExt2.Mcm_Pages()
    If !served || served.Length == 0
        ; An older DLL or an empty table (Init's ABI handshake reports real skew). An empty Pages would show no
        ; pages at all.
        Debug.Trace("[SeverActions_MCM] Mcm_Pages served nothing - the MCM has no pages to draw")
        Pages = new String[1]
        Pages[0] = "$SA_Interface"
        Return
    EndIf


    Int kept = 0
    Int i = 0
    While i < served.Length
        If SeverActions_ModuleBase.VerbField(served[i], 2) == ""
            kept += 1
        EndIf
        i += 1
    EndWhile

    Pages = PapyrusUtil.StringArray(kept)
    Int n = 0
    i = 0
    While i < served.Length
        If SeverActions_ModuleBase.VerbField(served[i], 2) == ""
            Pages[n] = SeverActions_ModuleBase.VerbField(served[i], 1)
            n += 1
        EndIf
        i += 1
    EndWhile

    ; Modular's own page, drawn by hand (DrawModulesPage), so Legacy keeps exactly the table's pages (DR7).
    If SeverActionsNativeExt2.Module_IsModular()
        _modulesPageLabel = SeverActionsNativeExt2.Native_L10n("mcm.modulesPage")
        If _modulesPageLabel == "" || _modulesPageLabel == "mcm.modulesPage"
            _modulesPageLabel = "Modules"
        EndIf
        Pages = PapyrusUtil.PushString(Pages, _modulesPageLabel)
    EndIf
EndFunction

SeverActions_MCM Function GetInstance() Global
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_MCM
EndFunction

; =============================================================================
; THE RENDER LOOP
; =============================================================================

Event OnPageReset(string page)
    SetCursorFillMode(TOP_TO_BOTTOM)
    _optionsUsed = 0
    _optionsDropped = 0
    _leftoverSlot = -1
    _slotRow = new Int[128]
    _slotEntry = new Int[128]
    Int s = 0
    While s < 128
        _slotRow[s] = -1
        _slotEntry[s] = -1
        s += 1
    EndWhile

    If _modulesPageLabel != "" && page == _modulesPageLabel
        _pageId = ""
        _rows = PapyrusUtil.StringArray(0)
        DrawModulesPage()
        Return
    EndIf

    _pageId = PageIdForLabel(page)
    If _pageId == ""
        ; Say so on the page too: a blank page reads as "empty", not "the lookup failed".
        AddTextOption("", "$SA_ERROR_Script_not_linked", OPTION_FLAG_DISABLED)
        _rows = PapyrusUtil.StringArray(0)
        Debug.Trace("[SeverActions_MCM] OnPageReset: no layout page for '" + page + "'")
        TracePageDiag(page)
        Return
    EndIf

    _rows = SeverActionsNativeExt2.Mcm_PageRows(_pageId)
    If !_rows || _rows.Length == 0
        AddTextOption("", "$SA_ERROR_Script_not_linked", OPTION_FLAG_DISABLED)
        Debug.Trace("[SeverActions_MCM] OnPageReset: the layout page '" + _pageId + "' served no rows")
        TracePageDiag(page)
        Return
    EndIf

    RefreshPageState()

    Int i = 0
    While i < _rows.Length
        i = DrawRun(i)
    EndWhile

    If _optionsDropped > 0
        ; SkyUI's AddOption drops a row past the ceiling without a word; log it.
        Debug.Trace("[SeverActions_MCM] page '" + _pageId + "': " + _optionsDropped + " row(s) past SkyUI's " + SKYUI_MAX_ROWS + "-option ceiling were not drawn")
    EndIf
EndEvent

String Function PageIdForLabel(String asLabel)
    {The layout page id behind the page name SkyUI hands OnPageReset, or its live variant; "" (SkyUI's first
     open) means the first page. The name arrives as the raw $SA_ key from Pages, and Papyrus == folds case, so
     the match is safe. The returned id may come back re-cased by the BSFixedString pool; the DLL folds case on
     input (Native/src/IdCase.h), so never "correct" it here.}
    String[] served = SeverActionsNativeExt2.Mcm_Pages()
    If !served || served.Length == 0
        Return ""
    EndIf
    String want = asLabel
    If want == ""
        want = SeverActions_ModuleBase.VerbField(served[0], 1)
    EndIf

    String baseId = ""
    Int i = 0
    While i < served.Length
        If SeverActions_ModuleBase.VerbField(served[i], 1) == want && SeverActions_ModuleBase.VerbField(served[i], 2) == ""
            baseId = SeverActions_ModuleBase.VerbField(served[i], 0)
            i = served.Length
        Else
            i += 1
        EndIf
    EndWhile
    If baseId == ""
        Return ""
    EndIf

    ; a variant is drawn INSTEAD of the page it varies, when its own switch is on
    i = 0
    While i < served.Length
        String variantOf = SeverActions_ModuleBase.VerbField(served[i], 2)
        If variantOf == baseId
            String variantId = SeverActions_ModuleBase.VerbField(served[i], 0)
            If VariantActive(variantId)
                Return variantId
            EndIf
        EndIf
        i += 1
    EndWhile
    Return baseId
EndFunction

Function TracePageDiag(String asPage)
    {Log what a failed page lookup saw, raw payload included: the served id and the id Papyrus hands back can
     differ in case alone (see PageIdForLabel).}
    String[] served = SeverActionsNativeExt2.Mcm_Pages()
    Int n = 0
    If served
        n = served.Length
    EndIf
    String line = "[SeverActions_MCM] page diag: arg='" + asPage + "' resolved='" + _pageId + "' served=" + n
    Int i = 0
    While i < n && i < 3
        line += " [" + i + "]='" + served[i] + "'"
        i += 1
    EndWhile
    Debug.Trace(line)
EndFunction

Bool Function VariantActive(String asVariantId)
    {Whether a variant page is drawn instead of its base page. The debug harness must be off in a public
     release (ENTERPRISES.md), so its switch is the gate.}
    If asVariantId == "enterprisesDebug"
        Return EnableEnterpriseDebug
    EndIf
    Return false
EndFunction

Function DrawModulesPage()
    {The Modular-only Modules page: the install mode, how many modules are installed, and each module's state
     under its installer option name, verbatim (never translated: the player looks for it in the installer).
     Every option is bound to no row, so no option event acts on it.}
    String[] mods = SeverActionsNativeExt2.Mcm_ModuleRows()
    Int total = 0
    If mods
        total = mods.Length
    EndIf
    Int installed = 0
    String leftover = ""
    Int i = 0
    While i < total
        String modState = SeverActions_ModuleBase.VerbField(mods[i], 2)
        If modState == "Installed"
            installed += 1
        ElseIf modState == "PresentNotSelected"
            If leftover != ""
                leftover += ", "
            EndIf
            leftover += SeverActions_ModuleBase.VerbField(mods[i], 1)
        EndIf
        i += 1
    EndWhile

    BindSlot(AddHeaderOptionAt(_modulesPageLabel), -1, -1)
    AddTextOptionSlotted(-1, -1, SeverActionsNativeExt2.Native_L10n("mcm.installMode"), SeverActionsNativeExt2.Native_L10n("mcm.installModeModular"), OPTION_FLAG_DISABLED)
    AddTextOptionSlotted(-1, -1, SeverActionsNativeExt2.Native_L10n("mcm.modulesInstalled"), installed + " / " + total, OPTION_FLAG_DISABLED)
    BindSlot(AddEmptyOptionAt(), -1, -1)
    i = 0
    While i < total
        String optionName = SeverActions_ModuleBase.VerbField(mods[i], 1)
        String stateText = SeverActionsNativeExt2.Native_L10n("mcm.moduleState" + SeverActions_ModuleBase.VerbField(mods[i], 2))
        AddTextOptionSlotted(-1, -1, optionName, stateText, OPTION_FLAG_DISABLED)
        i += 1
    EndWhile
    If leftover != ""
        ; an option holds about 45 characters: the line is the short form, highlighting it shows the sentence
        _leftoverInfo = SeverActionsNativeExt2.Native_L10nFmt("module.leftoverFiles", leftover)
        Int opt = AddTextOptionAt("", SeverActionsNativeExt2.Native_L10n("mcm.leftoverFilesShort"), OPTION_FLAG_NONE)
        BindSlot(opt, -1, -1)
        If opt >= 0
            _leftoverSlot = opt % 256
        EndIf
    EndIf
EndFunction

Int Function DrawRun(Int aiFirst)
    {Draw the run of rows starting at aiFirst; returns where the next run starts. A run is one row plus any
     consecutive rows from the same dynamic source, and the run repeats per entry, so a pair such as the Homes
     page's "<name> / Clear Home" stays together.}
    String first = _rows[aiFirst]
    String type = SeverActions_ModuleBase.VerbField(first, ROW_TYPE)
    If type != "dynamic"
        If GatesOpen(SeverActions_ModuleBase.VerbField(first, ROW_GATES), 0)
            DrawOne(aiFirst, first, type, 0)
        EndIf
        Return aiFirst + 1
    EndIf

    String source = SeverActions_ModuleBase.VerbField(first, ROW_SOURCE)
    Int last = aiFirst
    While last + 1 < _rows.Length && SeverActions_ModuleBase.VerbField(_rows[last + 1], ROW_TYPE) == "dynamic" \
        && SeverActions_ModuleBase.VerbField(_rows[last + 1], ROW_SOURCE) == source
        last += 1
    EndWhile

    ; A per-slot source already has one row per entry (the nine holds, the three schedule pools): each row is
    ; drawn once, for the slot at its position in the run.
    If SourcePerSlot(source)
        Int k = aiFirst
        While k <= last
            If GatesOpen(SeverActions_ModuleBase.VerbField(_rows[k], ROW_GATES), k - aiFirst)
                DrawOne(k, _rows[k], "dynamic", k - aiFirst)
            EndIf
            k += 1
        EndWhile
        Return last + 1
    EndIf

    ; A source a SELECTOR picks one entry of: the run is drawn once, for the pick.
    If !SourcePerEntry(source)
        DrawRunAt(aiFirst, last, SelectedEntryFor(source))
        Return last + 1
    EndIf

    Int total = EntryCount(source)
    Int shown = total
    Int cap = SourceCap(source)
    If cap > 0 && shown > cap
        shown = cap
    EndIf
    Int e = 0
    While e < shown
        DrawRunAt(aiFirst, last, e)
        e += 1
    EndWhile
    If shown < total
        ; Say the list was cut, or the player cannot tell it ended at the cap.
        AddTextOptionSlotted(-1, -1, "", "$SA_ShowingNOfM{" + shown + "}{" + total + "}", OPTION_FLAG_DISABLED)
    EndIf
    Return last + 1
EndFunction

Function DrawRunAt(Int aiFirst, Int aiLast, Int aiEntry)
    {Every row of a run, for one entry. A row whose gates are shut for this entry is skipped (how the schedule
     pools draw one of their two alternative lines).}
    Int k = aiFirst
    While k <= aiLast
        If GatesOpen(SeverActions_ModuleBase.VerbField(_rows[k], ROW_GATES), aiEntry)
            DrawOne(k, _rows[k], "dynamic", aiEntry)
        EndIf
        k += 1
    EndWhile
EndFunction

Function DrawOne(Int aiRow, String asRow, String asType, Int aiEntry)
    {One option for one row, at the next free slot.}
    String control = SeverActions_ModuleBase.VerbField(asRow, ROW_CONTROL)
    String label = RowLabel(asRow, aiEntry)
    Int flags = RowFlags(asRow, asType, aiEntry)

    If asType == "header"
        BindSlot(AddHeaderOptionAt(label), aiRow, aiEntry)
    ElseIf asType == "empty"
        BindSlot(AddEmptyOptionAt(), aiRow, aiEntry)
    ElseIf control == "toggle"
        BindSlot(AddToggleOptionAt(label, RowBool(asRow, aiEntry), flags), aiRow, aiEntry)
    ElseIf control == "slider"
        BindSlot(AddSliderOptionAt(label, RowFloat(asRow, aiEntry), SeverActions_ModuleBase.VerbField(asRow, ROW_FORMAT), flags), aiRow, aiEntry)
    ElseIf control == "menu"
        BindSlot(AddMenuOptionAt(label, RowValue(asRow, aiEntry), flags), aiRow, aiEntry)
    ElseIf asType == "keymap"
        BindSlot(AddKeyMapOptionAt(label, RowKeyCode(asRow), flags), aiRow, aiEntry)
    Else
        ; text, action and the button/text dynamic rows are all a text option; the action ones are clickable
        BindSlot(AddTextOptionAt(label, RowValue(asRow, aiEntry), flags), aiRow, aiEntry)
    EndIf
EndFunction

; --- the ceiling bookkeeping -------------------------------------------------
; Every Add* goes through these so the column jump and drop count live in one place; a direct SkyUI call would
; spend a slot the map never learns about.

Function BeforeAdd()
    If _optionsUsed == SKYUI_COLUMN_ROWS
        SetCursorPosition(1)   ; fill mode 2 walked the EVEN slots; this starts the odd ones
    EndIf
EndFunction

Int Function AddHeaderOptionAt(String asLabel)
    BeforeAdd()
    Return AddHeaderOption(asLabel)
EndFunction

Int Function AddEmptyOptionAt()
    BeforeAdd()
    Return AddEmptyOption()
EndFunction

Int Function AddTextOptionAt(String asLabel, String asValue, Int aiFlags)
    BeforeAdd()
    Return AddTextOption(asLabel, asValue, aiFlags)
EndFunction

Int Function AddToggleOptionAt(String asLabel, Bool abValue, Int aiFlags)
    BeforeAdd()
    Return AddToggleOption(asLabel, abValue, aiFlags)
EndFunction

Int Function AddSliderOptionAt(String asLabel, Float afValue, String asFormat, Int aiFlags)
    BeforeAdd()
    Return AddSliderOption(asLabel, afValue, asFormat, aiFlags)
EndFunction

Int Function AddMenuOptionAt(String asLabel, String asValue, Int aiFlags)
    BeforeAdd()
    Return AddMenuOption(asLabel, asValue, aiFlags)
EndFunction

Int Function AddKeyMapOptionAt(String asLabel, Int aiKeyCode, Int aiFlags)
    BeforeAdd()
    Return AddKeyMapOption(asLabel, aiKeyCode, aiFlags)
EndFunction

Function AddTextOptionSlotted(Int aiRow, Int aiEntry, String asLabel, String asValue, Int aiFlags)
    {A line the renderer adds itself (the "showing N of M" note), bound to no table row.}
    BindSlot(AddTextOptionAt(asLabel, asValue, aiFlags), aiRow, aiEntry)
EndFunction

Function BindSlot(Int aiOption, Int aiRow, Int aiEntry)
    {Remember which row an option belongs to. SkyUI returns pos + pageNum * 256, so `option % 256` is the cursor
     slot.}
    If aiOption < 0
        _optionsDropped += 1
        Return
    EndIf
    _optionsUsed += 1
    Int slot = aiOption % 256
    If slot >= 0 && slot < 128
        _slotRow[slot] = aiRow
        _slotEntry[slot] = aiEntry
    EndIf
EndFunction

Int Function RowAt(Int aiOption)
    {The table row an option belongs to, or -1.}
    If !_slotRow
        Return -1
    EndIf
    Int slot = aiOption % 256
    If slot < 0 || slot >= 128
        Return -1
    EndIf
    Int row = _slotRow[slot]
    If row < 0 || !_rows || row >= _rows.Length
        Return -1
    EndIf
    Return row
EndFunction

Int Function EntryAt(Int aiOption)
    Int slot = aiOption % 256
    If !_slotEntry || slot < 0 || slot >= 128
        Return 0
    EndIf
    Int e = _slotEntry[slot]
    If e < 0
        Return 0
    EndIf
    Return e
EndFunction

Int Function RowFlags(String asRow, String asType, Int aiEntry)
    {The SkyUI option flags a row is drawn with: the table's static flag, or a computed disabled state.}
    Int f = SeverActions_ModuleBase.VerbField(asRow, ROW_FLAGS) as Int
    If Math.LogicalAnd(f, FLAG_DISABLED) != 0
        Return OPTION_FLAG_DISABLED
    EndIf
    If Math.LogicalAnd(f, FLAG_DISABLEDWHEN) != 0 && RowDisabledNow(SeverActions_ModuleBase.VerbField(asRow, ROW_ID))
        Return OPTION_FLAG_DISABLED
    EndIf
    If asType == "keymap" && KeymapAbsentModule(asRow) != ""
        Return OPTION_FLAG_DISABLED
    EndIf
    Return OPTION_FLAG_NONE
EndFunction

String Function KeymapAbsentModule(String asRow)
    {The player-facing module whose absence refuses a keymap row's hotkey, "" when it works or the row is no
     keymap. Only a Modular install asks the DLL: nothing is refused outside it (DR7).}
    If SeverActions_ModuleBase.VerbField(asRow, ROW_TYPE) != "keymap" || !SeverActionsNativeExt2.Module_IsModular()
        Return ""
    EndIf
    ; a keymap row's id is its hotkey id
    Return SeverActionsNativeExt2.Hotkey_AbsentModule(SeverActions_ModuleBase.VerbField(asRow, ROW_ID))
EndFunction

Bool Function RowDisabledNow(String asRowId)
    {The rows whose greying-out is a runtime test rather than a fixed table flag.}
    If asRowId == "bioApply" || asRowId == "bioGrantFaction"
        ; both need a crosshair target AND a real selected block
        Return !BioTargetActor || !BioBlockTitles || BioBlockTitles[BioBlockIdx] == ""
    ElseIf asRowId == "followerExclude"
        ; Greyed out while survival is off (its update loop early-outs on !Enabled); the choices are kept.
        ; Enabled is read as GateOpen's survival switches read it.
        Return !SeverActionsNativeExt2.Module_IsUsable("survival") || !SeverActionsNativeExt2.Script_GetBool("SeverActions_Survival", "Enabled", true)
    EndIf
    Return false
EndFunction

; =============================================================================
; GATES: a conditional row carries the atoms it is drawn under (all must hold). Each atom's source condition is
; beside the row in Native/data/mcm_layout.json; check 13 (f) fails an atom GateOpen does not answer, and a
; branch no row is gated on.
; =============================================================================

Bool Function GatesOpen(String asGates, Int aiEntry)
    If asGates == ""
        Return true
    EndIf
    Int pos = 0
    Int len = StringUtil.GetLength(asGates)
    While pos < len
        String atom
        Int comma = StringUtil.Find(asGates, ",", pos)
        If comma < 0
            atom = StringUtil.Substring(asGates, pos)
            pos = len
        Else
            atom = StringUtil.Substring(asGates, pos, comma - pos)
            pos = comma + 1
        EndIf
        Bool want = true
        If StringUtil.GetNthChar(atom, 0) == "!"
            want = false
            atom = StringUtil.Substring(atom, 1)
        EndIf
        If GateOpen(atom, aiEntry) != want
            Return false
        EndIf
    EndWhile
    Return true
EndFunction

Bool Function GateOpen(String asGate, Int aiEntry)
    {One gate atom. aiEntry is the dynamic-list entry being drawn, which a few atoms need (one schedule pool,
     one follower's survival exclusion).}

    ; --- the module a page needs: the registry (Legacy: every id Installed, DR7) ---
    ; Atom names are the old owner-script names; each asks for the module that owns the rows.
    If asGate == "followerManager"
        Return SeverActionsNativeExt2.Module_IsUsable("followers")
    ElseIf asGate == "survival"
        Return SeverActionsNativeExt2.Module_IsUsable("survival")
    ElseIf asGate == "combat"
        Return SeverActionsNativeExt2.Module_IsUsable("combat")
    ElseIf asGate == "enterprises"
        ; The Enterprises page, and the camp-takeover row on Combat & Outlaws: enterprises owns that setting though
        ; SeverActions_Combat hosts it, and an absent owner refuses the write (the toggle would snap back).
        Return SeverActionsNativeExt2.Module_IsUsable("enterprises")
    ElseIf asGate == "companions"
        ; The Off-Screen Life page's rows are the companions module's.
        Return SeverActionsNativeExt2.Module_IsUsable("companions")
    ElseIf asGate == "arrest"
        Return SeverActionsNativeExt2.Module_IsUsable("arrest")
    ElseIf asGate == "travel"
        Return SeverActionsNativeExt2.Module_IsUsable("travel")
    ElseIf asGate == "outfit"
        Return SeverActionsNativeExt2.Module_IsUsable("outfit")
    ElseIf asGate == "hotkeySink"
        ; The DLL's input sink is the hotkey system. Never ask for the Hotkeys shim: naming a Legacy-shim type
        ; breaks the link on a Modular install.
        Return SeverActionsNativeExt2.Hotkey_SinkInstalled()
    ElseIf asGate == "spellTeach"
        Return SeverActionsNativeExt2.Module_IsUsable("items")
    ElseIf asGate == "loot"
        Return SeverActionsNativeExt2.Module_IsUsable("items")
    ElseIf asGate == "debt"
        ; SeverActions_Debt is the economy module's; it does not depend on followers.
        Return SeverActionsNativeExt2.Module_IsUsable("economy")
    ElseIf asGate == "social"
        ; The social module's rows on the Followers and Interface pages: an absent owner refuses the write.
        Return SeverActionsNativeExt2.Module_IsUsable("social")

    ; --- is the list this row belongs to non-empty ---
    ElseIf asGate == "hasCompanions"
        Return CachedManagedFollowers && CachedManagedFollowers.Length > 0
    ElseIf asGate == "hasDismissed"
        Return CachedDismissedFollowers && CachedDismissedFollowers.Length > 0
    ElseIf asGate == "hasPresetActors"
        Return CachedPresetActors && CachedPresetActors.Length > 0
    ElseIf asGate == "hasHomedNpcs"
        Return CachedHomedNPCs && CachedHomedNPCs.Length > 0
    ElseIf asGate == "hasSurvivalFollowers"
        Return CachedFollowers && CachedFollowers.Length > 0
    ElseIf asGate == "hasCompanionPresets"
        Return CachedPresetNames && CachedPresetNames.Length > 0
    ElseIf asGate == "hasOutfitPresets"
        Return CachedOutfitPresetNames && CachedOutfitPresetNames.Length > 0
    ElseIf asGate == "hasBioTabs"
        Return BioTabs && BioTabs.Length > 0
    ElseIf asGate == "hasBioAssigned"
        Return BioAssignedTitles && BioAssignedTitles.Length > 0
    ElseIf asGate == "hasBioRules"
        Return BioRuleNames && BioRuleNames.Length > 0

    ; --- does the actor this row is about resolve ---
    ElseIf asGate == "companionSelected"
        Return RowActor(aiEntry) != None
    ElseIf asGate == "dismissedSelected"
        Return _selDismissed != None
    ElseIf asGate == "presetActorSelected"
        Return _selPresetActor != None
    ElseIf asGate == "bioTarget"
        Return BioTargetActor != None

    ; --- that actor's state ---
    ElseIf asGate == "companionHasHome"
        Return _selCompanionHome != ""
    ElseIf asGate == "companionHasSituation"
        Return _selCompanionSituation != ""
    ElseIf asGate == "companionOutfitLocked"
        Return _selCompanion != None && SeverActionsNativeExt.Native_Outfit_IsLockActive(_selCompanion)
    ElseIf asGate == "companionExcluded"
        ; the exclusion lives in the survival module's StorageUtil key: the provider service reads it
        Return SeverActionsNativeExt2.Module_IsUsable("survival") && RowActor(aiEntry) != None && SeverActions_ModuleBase.CallBool("survival", "isFollowerExcluded", RowActor(aiEntry))

    ; --- module switches the page branches on ---
    ; The four survival switches are tier-P rows: read the owner property through the ScriptObjectAccess gate,
    ; never Settings_Get* (a P row is never migrated). The fallback is the runtime default (DR18: true). Every
    ; row they gate is also gated 'survival'.
    ElseIf asGate == "survivalOn"
        Return SeverActionsNativeExt2.Script_GetBool("SeverActions_Survival", "Enabled", true)
    ElseIf asGate == "survivalHunger"
        Return SeverActionsNativeExt2.Script_GetBool("SeverActions_Survival", "HungerEnabled", true)
    ElseIf asGate == "survivalFatigue"
        Return SeverActionsNativeExt2.Script_GetBool("SeverActions_Survival", "FatigueEnabled", true)
    ElseIf asGate == "survivalCold"
        Return SeverActionsNativeExt2.Script_GetBool("SeverActions_Survival", "ColdEnabled", true)
    ElseIf asGate == "schedMigrated"
        Return SeverActionsNativeExt2.Module_IsUsable("followers") && SeverActionsNativeExt.Native_GetAliasesMigrated()
    ElseIf asGate == "schedPoolFull"
        ; the sticky exhaustion flag is FollowerManager's StorageUtil key: the provider service reads it
        Return SeverActions_ModuleBase.CallBool("followers", "schedPoolExhausted", None, None, "", aiEntry as Float)
    ElseIf asGate == "playerOwes"
        Return _debtPlayerOwes > 0
    ElseIf asGate == "owedToPlayer"
        Return _debtOwedToPlayer > 0

    ; --- platform and binding probes ---
    ElseIf asGate == "modular"
        ; The notice rows an absent module leaves: Legacy never draws them, so check 13 (g) skips them.
        Return SeverActionsNativeExt2.Module_IsModular()
    ElseIf asGate == "vr"
        Return SeverActionsNativeExt2.Native_IsVRRuntime()
    ElseIf asGate == "wheelNative"
        Return SeverActionsNativeExt2.Wheel_IsNative()
    ElseIf asGate == "wheelBound"
        ; VR can open the wheel from the controller chord as well as the key (a VRIK gesture can send the key)
        Bool bound = SeverActionsNativeExt2.Settings_GetInt("WheelMenuKey") > 0
        If !bound && SeverActionsNativeExt2.Native_IsVRRuntime()
            bound = SeverActionsNativeExt2.Native_GetVRChord("wheelButton") > 0
        EndIf
        Return bound
    ElseIf asGate == "targetModeNearest"
        Return SeverActionsNativeExt2.Settings_GetInt("targetMode") == 1
    EndIf

    Debug.Trace("[SeverActions_MCM] GateOpen: no branch for the gate '" + asGate + "' - the row is not drawn")
    Return false
EndFunction

Actor Function RowActor(Int aiEntry)
    {The actor a row on the page in hand is about: the selected companion on the Followers page, the aiEntry-th
     tracked follower on Survival. One concept, two lists.}
    If _pageId == "survival"
        If CachedFollowers && aiEntry < CachedFollowers.Length
            Return CachedFollowers[aiEntry]
        EndIf
        Return None
    EndIf
    Return _selCompanion
EndFunction

; =============================================================================
; PAGE STATE
; =============================================================================

Function RefreshPageState()
    {Gather everything the page's rows read at draw time, once, so a gate and the row it guards read the same
     list.}
    If _pageId == "followers"
        RefreshFollowersState()
    ElseIf _pageId == "outfits"
        RefreshOutfitsState()
    ElseIf _pageId == "survival"
        CachedFollowers = PapyrusUtil.ActorArray(0)
        If SeverActionsNativeExt2.Module_IsUsable("survival")
            ; SeverActions_Survival.GetCurrentFollowers' native branch
            Actor[] got = SeverActionsNative.Survival_GetCurrentFollowers()
            If got
                CachedFollowers = got
            EndIf
        EndIf
    ElseIf _pageId == "homes"
        RefreshHomesState()
    ElseIf _pageId == "economy"
        RefreshEconomyState()
    ElseIf _pageId == "bioBlocks"
        RefreshBioState()
    EndIf
EndFunction

Function RefreshFollowersState()
    CachedManagedFollowers = PapyrusUtil.ActorArray(0)
    CachedPresetNames = PapyrusUtil.StringArray(0)
    _selCompanion = None
    _selCompanionHome = ""
    _selCompanionSituation = ""
    If !SeverActionsNativeExt2.Module_IsUsable("followers")
        Return
    EndIf
    ; FollowerManager.GetAllFollowers is this one native call
    Actor[] roster = SeverActionsNativeExt.Native_GetActiveFollowerRoster()
    If roster
        CachedManagedFollowers = roster
    EndIf
    If CachedManagedFollowers.Length == 0
        Return
    EndIf
    If SelectedCompanionIdx < 0 || SelectedCompanionIdx >= CachedManagedFollowers.Length
        SelectedCompanionIdx = 0
    EndIf
    _selCompanion = CachedManagedFollowers[SelectedCompanionIdx]
    If !_selCompanion
        Return
    EndIf
    _selCompanionHome = SeverActionsNative.Native_GetHome(_selCompanion)   ; FollowerManager.GetAssignedHome's body
    If SeverActionsNativeExt2.Module_IsUsable("outfit")
        _selCompanionSituation = SeverActionsNative.Native_Outfit_GetCurrentSituation(_selCompanion)
        CachedPresetNames = VisiblePresetNames(_selCompanion)
    EndIf
EndFunction

Function RefreshOutfitsState()
    CachedPresetActors = PapyrusUtil.ActorArray(0)
    CachedOutfitPresetNames = PapyrusUtil.StringArray(0)
    _selPresetActor = None
    If !SeverActionsNativeExt2.Module_IsUsable("outfit")
        Return
    EndIf
    ; Registered followers are managed on the Followers page, so they are left out (only when the Followers
    ; module is installed). Same natives as Outfit.GetPresetActors and FollowerManager.IsRegisteredFollower.
    Actor[] all = SeverActionsNative.Native_Outfit_GetActorsWithPresets()
    Bool haveFollowers = SeverActionsNativeExt2.Module_IsUsable("followers")
    If all
        Int f = 0
        While f < all.Length
            If all[f] && (!haveFollowers || !SeverActionsNativeExt.Native_GetIsFollower(all[f]))
                CachedPresetActors = PapyrusUtil.PushActor(CachedPresetActors, all[f])
            EndIf
            f += 1
        EndWhile
    EndIf
    If CachedPresetActors.Length == 0
        Return
    EndIf
    If SelectedOutfitNPCIdx < 0 || SelectedOutfitNPCIdx >= CachedPresetActors.Length
        SelectedOutfitNPCIdx = 0
    EndIf
    _selPresetActor = CachedPresetActors[SelectedOutfitNPCIdx]
    If _selPresetActor
        CachedOutfitPresetNames = VisiblePresetNames(_selPresetActor)
    EndIf
EndFunction

Function RefreshHomesState()
    CachedHomedNPCs = PapyrusUtil.ActorArray(0)
    CachedDismissedFollowers = PapyrusUtil.ActorArray(0)
    _selDismissed = None
    If !SeverActionsNativeExt2.Module_IsUsable("followers")
        Return
    EndIf
    ; Homed NPCs in ASSIGNMENT order, from FollowerManager's FormList (its sharedKeys row in fomod/modules.json
    ; names this reader); GetAllHomedNPCs' filter, read-only - FollowerManager prunes on its schedule tick. Not a
    ; native list: FollowerDataStore is an unordered map and would reorder the page.
    Int n = StorageUtil.FormListCount(None, "SeverActions_HomedNPCs")
    Int i = 0
    While i < n
        Actor homed = StorageUtil.FormListGet(None, "SeverActions_HomedNPCs", i) as Actor
        If homed && !homed.IsDeleted() && SeverActionsNative.Native_GetHome(homed) != ""
            CachedHomedNPCs = PapyrusUtil.PushActor(CachedHomedNPCs, homed)
        EndIf
        i += 1
    EndWhile
    ; Dismissed NPCs who keep a home (FollowerManager.GetDismissedWithHomes' filter: every tracked actor has a
    ; home; drop the player and registered followers).
    Actor player = Game.GetPlayer()
    Actor[] tracked = SeverActionsNative.Native_GetAllTrackedFollowers()
    If tracked
        Int t = 0
        While t < tracked.Length
            If tracked[t] && tracked[t] != player && !SeverActionsNativeExt.Native_GetIsFollower(tracked[t])
                CachedDismissedFollowers = PapyrusUtil.PushActor(CachedDismissedFollowers, tracked[t])
            EndIf
            t += 1
        EndWhile
    EndIf
    If CachedDismissedFollowers.Length == 0
        Return
    EndIf
    If SelectedDismissedIdx < 0 || SelectedDismissedIdx >= CachedDismissedFollowers.Length
        SelectedDismissedIdx = 0
    EndIf
    _selDismissed = CachedDismissedFollowers[SelectedDismissedIdx]
EndFunction

Function RefreshEconomyState()
    _debtPlayerOwes = 0
    _debtOwedToPlayer = 0
    _debtOwesDetails = PapyrusUtil.StringArray(0)
    _debtOwedDetails = PapyrusUtil.StringArray(0)
    If !SeverActionsNativeExt2.Module_IsUsable("economy")
        Return
    EndIf
    ; SeverActions_Debt's GetTotalOwedBy / GetTotalOwedTo are these natives; the lines are the World page's
    ; formatter, in GetPlayerOwesDetails' format
    Actor player = Game.GetPlayer()
    _debtPlayerOwes = SeverActionsNativeExt.Native_Debt_SumOwedBy(player)
    _debtOwedToPlayer = SeverActionsNativeExt.Native_Debt_SumOwedTo(player)
    If _debtPlayerOwes > 0
        String[] owes = SeverActionsNativeExt2.Native_Debt_GetPlayerViewLines(false)
        If owes
            _debtOwesDetails = owes
        EndIf
    EndIf
    If _debtOwedToPlayer > 0
        String[] owed = SeverActionsNativeExt2.Native_Debt_GetPlayerViewLines(true)
        If owed
            _debtOwedDetails = owed
        EndIf
    EndIf
EndFunction

Function RefreshBioState()
    BioTabs = SeverActionsNativeExt2.Native_BioBlock_TabList()
    BioBlockTitles = PapyrusUtil.StringArray(0)
    BioAssignedTitles = PapyrusUtil.StringArray(0)
    BioTargetFactions = PapyrusUtil.StringArray(0)
    BioRuleNames = SeverActionsNativeExt2.Native_BioBlock_FactionRuleNames()
    BioTargetActor = Game.GetCurrentCrosshairRef() as Actor
    If BioTargetActor
        BioTargetFactions = SeverActionsNativeExt2.Native_BioBlock_TargetFactionNames(BioTargetActor)
    EndIf
    If !BioTabs || BioTabs.Length == 0
        Return
    EndIf
    If BioTabIdx < 0 || BioTabIdx >= BioTabs.Length
        BioTabIdx = 0
    EndIf
    BioBlockTitles = SeverActionsNativeExt2.Native_BioBlock_BlockTitlesInTab(BioTabs[BioTabIdx])
    BioBlockIds = SeverActionsNativeExt2.Native_BioBlock_BlockIdsInTab(BioTabs[BioTabIdx])
    ; An empty tab returns a length-0 array (the shipped library's first tab is one), and BioBlockTitles[BioBlockIdx]
    ; would then read out of bounds.
    If !BioBlockTitles || BioBlockTitles.Length == 0
        BioBlockTitles = new string[1]
        BioBlockTitles[0] = ""
    EndIf
    If BioBlockIdx < 0 || BioBlockIdx >= BioBlockTitles.Length
        BioBlockIdx = 0
    EndIf
    If BioTargetActor
        BioAssignedTitles = SeverActionsNativeExt2.Native_BioBlock_AssignedTitles(BioTargetActor)
        BioAssignedIds = SeverActionsNativeExt2.Native_BioBlock_AssignedIds(BioTargetActor)
    EndIf
EndFunction

; =============================================================================
; DYNAMIC SOURCES
; =============================================================================

Bool Function SourcePerEntry(String asSource)
    {Whether a dynamic run draws once per entry (false: a selector picks one entry). Read from the served table,
     so the renderer and the ceiling report count the same thing.}
    Return SourceField(asSource, 4) != ""
EndFunction

Bool Function SourcePerSlot(String asSource)
    {Whether the table carries one ROW per entry of this source, so each row draws once instead of the run
     repeating.}
    Return SourceField(asSource, 3) != ""
EndFunction

Int Function SelectedEntryFor(String asSource)
    If asSource == "companionRoster"
        Return SelectedCompanionIdx
    ElseIf asSource == "dismissedWithHomes"
        Return SelectedDismissedIdx
    EndIf
    Return 0
EndFunction

String Function SourceField(String asSource, Int aiField)
    {One field of a dynamic source's row in the table the DLL serves, so the drawn list and check 13 (f)'s
     ceiling report agree on a cap. Cached until the menu next opens (OnConfigOpen drops it).}
    If !_sources || _sources.Length == 0
        _sources = SeverActionsNativeExt2.Mcm_Sources()
    EndIf
    If !_sources || _sources.Length == 0
        Return ""
    EndIf
    Int i = 0
    While i < _sources.Length
        If SeverActions_ModuleBase.VerbField(_sources[i], 0) == asSource
            Return SeverActions_ModuleBase.VerbField(_sources[i], aiField)
        EndIf
        i += 1
    EndWhile
    Debug.Trace("[SeverActions_MCM] SourceField: the dynamic source '" + asSource + "' is not in the served table")
    Return ""
EndFunction

Int Function SourceCap(String asSource)
    {How many entries of a source may be drawn, 0 for no cap.}
    Return SourceField(asSource, 1) as Int
EndFunction

Int Function EntryCount(String asSource)
    {How many entries the source has RIGHT NOW.}
    If asSource == "companionRoster"
        Return ArrayLen(CachedManagedFollowers)
    ElseIf asSource == "companionPresets"
        Return StrArrayLen(CachedPresetNames)
    ElseIf asSource == "followerExclusions"
        Return ArrayLen(CachedFollowers)
    ElseIf asSource == "outfitPresets"
        Return StrArrayLen(CachedOutfitPresetNames)
    ElseIf asSource == "outfitPresetActors"
        Return ArrayLen(CachedPresetActors)
    ElseIf asSource == "homedNpcs"
        Return ArrayLen(CachedHomedNPCs)
    ElseIf asSource == "dismissedWithHomes"
        Return ArrayLen(CachedDismissedFollowers)
    ElseIf asSource == "bioBlockRules"
        Return StrArrayLen(BioRuleNames)
    ElseIf asSource == "appliedBioBlocks"
        Return StrArrayLen(BioAssignedTitles)
    ElseIf asSource == "bioTabs"
        Return StrArrayLen(BioTabs)
    ElseIf asSource == "bioBlocksInTab"
        Return StrArrayLen(BioBlockTitles)
    ElseIf asSource == "bioTargetFactions"
        Return StrArrayLen(BioTargetFactions)
    ElseIf asSource == "schedulePools"
        Return 3
    ElseIf asSource == "travelJourneys"
        ; The orchestrator's player-ordered journeys, all of them: DrawRun caps the drawn rows at the layout's
        ; cap and adds the "showing N of M" line. The module test stays: DrawRun asks for the count before any
        ; gate, and that line is drawn ungated.
        If !SeverActionsNativeExt2.Module_IsUsable("travel")
            Return 0
        EndIf
        Return JourneyCount()
    ElseIf asSource == "holdBounties"
        Return 9
    ElseIf asSource == "debtsPlayerOwes"
        Return StrArrayLen(_debtOwesDetails)
    ElseIf asSource == "debtsOwedToPlayer"
        Return StrArrayLen(_debtOwedDetails)
    EndIf
    Debug.Trace("[SeverActions_MCM] EntryCount: no branch for the dynamic source '" + asSource + "'")
    Return 0
EndFunction

Int Function ArrayLen(Actor[] akList)
    If !akList
        Return 0
    EndIf
    Return akList.Length
EndFunction

Int Function StrArrayLen(String[] asList)
    If !asList
        Return 0
    EndIf
    Return asList.Length
EndFunction

Faction Function HoldFactionAt(Int aiEntry)
    {The nine crime factions in holdBounties order, as Skyrim.esm FormID literals (DR3; the same values as
     SeverActions_Arrest's CrimeFaction* fills and HoldResolver's seed). The rows are gated 'arrest'.}
    Int fid = 0
    If aiEntry == 0
        fid = 0x000267EA   ; CrimeFactionWhiterun
    ElseIf aiEntry == 1
        fid = 0x0002816B   ; CrimeFactionRift
    ElseIf aiEntry == 2
        fid = 0x00029DB0   ; CrimeFactionHaafingar
    ElseIf aiEntry == 3
        fid = 0x000267E3   ; CrimeFactionEastmarch
    ElseIf aiEntry == 4
        fid = 0x0002816C   ; CrimeFactionReach
    ElseIf aiEntry == 5
        fid = 0x00028170   ; CrimeFactionFalkreath
    ElseIf aiEntry == 6
        fid = 0x0002816E   ; CrimeFactionPale
    ElseIf aiEntry == 7
        fid = 0x0002816D   ; CrimeFactionHjaalmarch
    ElseIf aiEntry == 8
        fid = 0x0002816F   ; CrimeFactionWinterhold
    Else
        Return None
    EndIf
    Return Game.GetFormFromFile(fid, "Skyrim.esm") as Faction
EndFunction

String Function HoldNameAt(Int aiEntry)
    If aiEntry == 0
        Return "Whiterun"
    ElseIf aiEntry == 1
        Return "The Rift"
    ElseIf aiEntry == 2
        Return "Haafingar"
    ElseIf aiEntry == 3
        Return "Eastmarch"
    ElseIf aiEntry == 4
        Return "The Reach"
    ElseIf aiEntry == 5
        Return "Falkreath"
    ElseIf aiEntry == 6
        Return "The Pale"
    ElseIf aiEntry == 7
        Return "Hjaalmarch"
    ElseIf aiEntry == 8
        Return "Winterhold"
    EndIf
    Return ""
EndFunction

; =============================================================================
; LABELS AND VALUES: a translation-key row draws straight from the table; a row built at draw time carries a
; computed flag and is built here by id.
; =============================================================================

String Function RowLabel(String asRow, Int aiEntry)
    String label = SeverActions_ModuleBase.VerbField(asRow, ROW_LABEL)
    If Math.LogicalAnd(SeverActions_ModuleBase.VerbField(asRow, ROW_FLAGS) as Int, FLAG_COMPUTEDLABEL) == 0
        Return label
    EndIf
    String built = ComputedLabel(SeverActions_ModuleBase.VerbField(asRow, ROW_ID), SeverActions_ModuleBase.VerbField(asRow, ROW_SOURCE), aiEntry)
    If built != ""
        Return built
    EndIf
    Return label
EndFunction

String Function RowValue(String asRow, Int aiEntry)
    String value = SeverActions_ModuleBase.VerbField(asRow, ROW_VALUE)
    String control = SeverActions_ModuleBase.VerbField(asRow, ROW_CONTROL)
    String type = SeverActions_ModuleBase.VerbField(asRow, ROW_TYPE)

    If control == "menu" && type == "setting"
        Return MenuValueText(asRow)
    EndIf
    If Math.LogicalAnd(SeverActions_ModuleBase.VerbField(asRow, ROW_FLAGS) as Int, FLAG_COMPUTEDVALUE) != 0
        Return ComputedValue(SeverActions_ModuleBase.VerbField(asRow, ROW_ID), SeverActions_ModuleBase.VerbField(asRow, ROW_SOURCE), aiEntry)
    EndIf
    Return value
EndFunction

String Function ComputedLabel(String asRowId, String asSource, Int aiEntry)
    {A row whose LABEL is built at draw time, by row id. "" falls back to the table's label key.}
    If asRowId == "fmCompanionHeader"
        If _selCompanion
            Return _selCompanion.GetDisplayName()
        EndIf
        Return ""
    ElseIf asRowId == "outfitActorHeader"
        If _selPresetActor
            Return _selPresetActor.GetDisplayName()
        EndIf
        Return ""
    ElseIf asRowId == "fmDeletePreset"
        Return "Delete '" + CachedPresetNames[aiEntry] + "'"
    ElseIf asRowId == "fmPresetLine"
        Return CachedPresetNames[aiEntry]
    ElseIf asRowId == "outfitDeletePreset"
        Return "Delete '" + CachedOutfitPresetNames[aiEntry] + "'"
    ElseIf asRowId == "outfitPresetLine"
        Return CachedOutfitPresetNames[aiEntry]
    ElseIf asRowId == "followerExclude"
        Actor f = RowActor(aiEntry)
        If f
            Return f.GetDisplayName()
        EndIf
        Return ""
    ElseIf asRowId == "bioRule"
        Return BioRuleNames[aiEntry]
    ElseIf asRowId == "bioAssignedLine"
        Return "  - " + BioAssignedTitles[aiEntry]
    ElseIf asRowId == "debtOwesLine"
        Return "  " + _debtOwesDetails[aiEntry]
    ElseIf asRowId == "travelJourneyLine"
        ; "<name>: Traveling to <place>" / "<name>: Waiting at <place>" - SeverActions_Travel.GetJourneyLine
        ; through the travel provider ("" without the module)
        Return SeverActions_ModuleBase.CallString("travel", "journeyLine", None, None, "", aiEntry as Float)
    ElseIf asRowId == "debtOwedLine"
        Return "  " + _debtOwedDetails[aiEntry]
    ElseIf asRowId == "clearNPCHome" || asRowId == "homedNpcLine"
        If CachedHomedNPCs && aiEntry < CachedHomedNPCs.Length && CachedHomedNPCs[aiEntry]
            Return CachedHomedNPCs[aiEntry].GetDisplayName()
        EndIf
        Return ""
    ElseIf asRowId == "schedPoolLine" || asRowId == "schedPoolFullLine"
        Return SchedPoolName(aiEntry) + " aliases"
    EndIf
    Debug.Trace("[SeverActions_MCM] ComputedLabel: no branch for the row '" + asRowId + "'")
    Return ""
EndFunction

String Function SchedPoolName(Int aiEntry)
    {The schedule pool's name (FollowerManager.GetSchedTypeName, HOME / WORK / PLAY = 0 / 1 / 2). Frozen in saves -
     the pool-exhaustion StorageUtil key is built from it - so the literal cannot drift (DR3).}
    If aiEntry == 0
        Return "home"
    ElseIf aiEntry == 1
        Return "work"
    ElseIf aiEntry == 2
        Return "relax"
    EndIf
    Return "unknown"
EndFunction

String Function ComputedValue(String asRowId, String asSource, Int aiEntry)
    {A row whose VALUE is built at draw time.}

    ; --- an absent module's notice rows, by id prefix: modNotice-<module>-<where> / modHowTo-<module>-<where>;
    ; each draws a short line and OnOptionHighlight shows the whole notice ---
    If StringUtil.Find(asRowId, "modNotice-") == 0
        Return ModuleNoticeLine(ModuleOfRowId(asRowId))
    ElseIf StringUtil.Find(asRowId, "modHowTo-") == 0
        Return SeverActionsNativeExt2.Native_L10nFmt("mcm.moduleHowToShort", SeverActionsNativeExt2.Module_Option(ModuleOfRowId(asRowId)))
    EndIf

    ; --- the selected companion ---
    If asRowId == "fmCompanionSelect"
        If _selCompanion
            Return _selCompanion.GetDisplayName()
        EndIf
        Return ""
    ElseIf asRowId == "fmRapport"
        ; the four relationship values: FollowerManager's Get<X> are these natives
        Return "" + SeverActionsNative.Native_GetRapport(_selCompanion)
    ElseIf asRowId == "fmTrust"
        Return "" + SeverActionsNative.Native_GetTrust(_selCompanion)
    ElseIf asRowId == "fmLoyalty"
        Return "" + SeverActionsNative.Native_GetLoyalty(_selCompanion)
    ElseIf asRowId == "fmMood"
        Return "" + SeverActionsNative.Native_GetMood(_selCompanion)
    ElseIf asRowId == "fmCombatStyle"
        Return CompanionCombatStyle(_selCompanion)
    ElseIf asRowId == "fmCompanionCount"
        Return CachedManagedFollowers.Length + " recruited"
    ElseIf asRowId == "fmHome"
        Return _selCompanionHome
    ElseIf asRowId == "fmSituation"
        ; Names the ACTIVE preset, not the one mapped to this situation: they differ whenever something else
        ; dressed the companion last.
        String preset = SeverActionsNative.Native_Outfit_GetActivePreset(_selCompanion)
        If preset != ""
            Return _selCompanionSituation + " (" + preset + ")"
        EndIf
        Return _selCompanionSituation
    ElseIf asRowId == "fmPresetLine"
        Return PresetItemCount(_selCompanion, CachedPresetNames[aiEntry]) + " items"
    ElseIf asRowId == "fmHunger"
        ; SeverActions_Survival.GetFollower<Need> is the native truncated to Int; the word is its
        ; Get<Need>LevelName table (0 hunger / 1 fatigue / 2 cold)
        Int hunger = SeverActionsNative.Native_Survival_GetHunger(_selCompanion) as Int
        Return hunger + "% (" + SeverActionsNativeExt2.Native_Survival_GetSeverityLabel(0, hunger) + ")"
    ElseIf asRowId == "fmFatigue"
        Int fatigue = SeverActionsNative.Native_Survival_GetFatigue(_selCompanion) as Int
        Return fatigue + "% (" + SeverActionsNativeExt2.Native_Survival_GetSeverityLabel(1, fatigue) + ")"
    ElseIf asRowId == "fmCold"
        Int cold = SeverActionsNative.Native_Survival_GetCold(_selCompanion) as Int
        Return cold + "% (" + SeverActionsNativeExt2.Native_Survival_GetSeverityLabel(2, cold) + ")"
    ElseIf asRowId == "fmOutfitLock"
        Form[] locked = SeverActionsNative.Native_Outfit_GetLockedItems(_selCompanion)
        Int itemCount = 0
        If locked
            itemCount = locked.Length
        EndIf
        Return "Active (" + itemCount + " items)"

    ; --- outfits ---
    ElseIf asRowId == "outfitNPCSelect"
        If _selPresetActor
            Return _selPresetActor.GetDisplayName()
        EndIf
        Return ""
    ElseIf asRowId == "outfitActorCount"
        Return CachedPresetActors.Length + " tracked"
    ElseIf asRowId == "outfitPresetLine"
        Return PresetItemCount(_selPresetActor, CachedOutfitPresetNames[aiEntry]) + " items"

    ; --- survival ---
    ElseIf asRowId == "survivalFollowerCount"
        ; tracked / total: the difference IS the excluded followers, which is what the line is for
        Return SeverActions_ModuleBase.CallInt("survival", "trackedFollowerCount") + " / " + CachedFollowers.Length

    ; --- travel ---
    ElseIf asRowId == "travelJourneyCount"
        Return "" + JourneyCount()

    ; --- crime ---
    ElseIf asSource == "holdBounties"
        Return GetBountyDisplayText(HoldFactionAt(aiEntry))

    ; --- homes ---
    ElseIf asRowId == "homedNpcLine"
        If CachedHomedNPCs && aiEntry < CachedHomedNPCs.Length && CachedHomedNPCs[aiEntry]
            Return SeverActionsNative.Native_GetHome(CachedHomedNPCs[aiEntry])   ; FollowerManager.GetAssignedHome's body
        EndIf
        Return ""
    ElseIf asRowId == "fmDismissedSelect"
        If _selDismissed
            Return _selDismissed.GetDisplayName()
        EndIf
        Return ""
    ElseIf asRowId == "fmDismissedCount"
        Return CachedDismissedFollowers.Length + " NPCs"
    ElseIf asRowId == "fmDismissedHome"
        If _selDismissed
            Return SeverActionsNative.Native_GetHome(_selDismissed)
        EndIf
        Return ""
    ElseIf asRowId == "schedPoolLine" || asRowId == "schedPoolFullLine"
        String tail = ""
        If asRowId == "schedPoolFullLine"
            tail = " - FULL!"
        EndIf
        ; FollowerManager.GetSchedPoolUsed: 0..300 for a valid pool, -1 otherwise
        Int used = -1
        If aiEntry >= 0 && aiEntry <= 2
            Int[] usage = SeverActionsNativeExt.Native_GetSchedPoolUsage()
            If usage && usage.Length >= 3
                used = usage[aiEntry]
            EndIf
        EndIf
        Return used + " / 300" + tail

    ; --- hotkeys ---
    ElseIf asRowId == "wheelStatus"
        Return SeverActionsNativeExt2.Native_L10n("hud.uiNotInstalled")

    ; --- economy ---
    ElseIf asRowId == "debtOwesLine" || asRowId == "debtOwedLine"
        Return ""

    ElseIf asRowId == "debtActiveCount"
        Return "" + SeverActionsNativeExt.Native_Debt_GetCount()   ; SeverActions_Debt.GetDebtCount's body
    ElseIf asRowId == "debtPlayerOwes"
        Return _debtPlayerOwes + " gold"
    ElseIf asRowId == "debtOwedToPlayer"
        Return _debtOwedToPlayer + " gold"

    ; --- bio blocks ---
    ElseIf asRowId == "bioTarget"
        If BioTargetActor
            Return BioTargetActor.GetDisplayName()
        EndIf
        Return "(none - aim at an NPC)"
    ElseIf asRowId == "bioTab"
        Return BioTabs[BioTabIdx]
    ElseIf asRowId == "bioBlock"
        If BioBlockTitles[BioBlockIdx] != ""
            Return BioBlockTitles[BioBlockIdx]
        EndIf
        Return "(no blocks in this tab)"

    ; --- hotkeys ---
    ; The N/A placeholder. Not "nearestNPCRadius": ids that differ from the setting key nearestNpcRadius only
    ; in case collide after the BSFixedString fold (IdCase.h).
    ElseIf asRowId == "nearestRadiusNA"
        Return MenuEntryAt("targetMode", SeverActionsNativeExt2.Settings_GetInt("targetMode"))
    ; --- enterprises (debug harness) ---
    ElseIf asRowId == "entTarget"
        Actor t = Game.GetCurrentCrosshairRef() as Actor
        If t
            Return t.GetDisplayName()
        EndIf
        Return "(none)"
    ElseIf asRowId == "entJob"
        Return MenuEntryAt("enterpriseJob", EntJob)
    ElseIf asRowId == "entArrangement"
        Return MenuEntryAt("enterpriseArrangement", EntArrangement)
    ElseIf asRowId == "entWage"
        Return "" + EntWage
    ElseIf asRowId == "entCount"
        Return "" + SeverActionsNativeExt2.Venture_Count()
    ElseIf asRowId == "entTestLetter"
        Return "" + SeverActionsNativeExt.Letter_Count() + " archived"
    EndIf

    Debug.Trace("[SeverActions_MCM] ComputedValue: no branch for the row '" + asRowId + "' (source '" + asSource + "')")
    Return ""
EndFunction

String Function ModuleOfRowId(String asRowId)
    {The module a notice row names: the text between the first and second '-' of its id.}
    Int first = StringUtil.Find(asRowId, "-")
    If first < 0
        Return ""
    EndIf
    Int second = StringUtil.Find(asRowId, "-", first + 1)
    If second < 0
        Return StringUtil.Substring(asRowId, first + 1)
    EndIf
    Return StringUtil.Substring(asRowId, first + 1, second - first - 1)
EndFunction

String Function ModuleNoticeLine(String asModule)
    {A notice row's line, "<module>: not installed": an option holds about 45 characters, so the reason and
     the installer option are ModuleNoticeInfo's, shown when the row is highlighted.}
    Return SeverActionsNativeExt2.Native_L10nFmt("mcm.moduleNoticeShort", SeverActionsNativeExt2.Native_L10n("module.name." + asModule))
EndFunction

String Function ModuleNoticeInfo(String asModule)
    {Why a module is absent and, in a Modular install, how to add it, for the info text. The module name is
     translated; the option never is, since the player looks for it verbatim in the installer.}
    String opt = SeverActionsNativeExt2.Module_Option(asModule)
    If SeverActionsNativeExt2.Module_State(asModule) == "ScriptMissing"
        Return SeverActionsNativeExt2.Native_L10nFmt("mcm.moduleScriptsMissing", opt)
    EndIf
    String line = SeverActionsNativeExt2.Native_L10nFmt("mcm.moduleNotInstalled", SeverActionsNativeExt2.Native_L10n("module.name." + asModule), opt)
    If SeverActionsNativeExt2.Module_IsModular()
        line += " " + SeverActionsNativeExt2.Native_L10nFmt("mcm.moduleHowTo", opt)
    EndIf
    Return line
EndFunction

; =============================================================================
; THE CONTRACT: reading and writing a setting row
; =============================================================================

Bool Function RowBool(String asRow, Int aiEntry)
    String type = SeverActions_ModuleBase.VerbField(asRow, ROW_TYPE)
    If type == "setting"
        Return SettingBool(SeverActions_ModuleBase.VerbField(asRow, ROW_ID), SeverActions_ModuleBase.VerbField(asRow, ROW_READ), SeverActions_ModuleBase.VerbField(asRow, ROW_HOST))
    EndIf
    Return StateBool(SeverActions_ModuleBase.VerbField(asRow, ROW_ID), aiEntry)
EndFunction

Float Function RowFloat(String asRow, Int aiEntry)
    String type = SeverActions_ModuleBase.VerbField(asRow, ROW_TYPE)
    If type == "setting"
        Return SettingFloat(SeverActions_ModuleBase.VerbField(asRow, ROW_ID), SeverActions_ModuleBase.VerbField(asRow, ROW_READ), SeverActions_ModuleBase.VerbField(asRow, ROW_HOST), SeverActions_ModuleBase.VerbField(asRow, ROW_VALUETYPE), SeverActions_ModuleBase.VerbField(asRow, ROW_LIVESCALE) as Float)
    EndIf
    Return StateFloat(SeverActions_ModuleBase.VerbField(asRow, ROW_ID), aiEntry)
EndFunction

Bool Function SettingBool(String asKey, String asRead, String asHost)
    If asRead == "property"
        Return SeverActionsNativeExt2.Script_GetBool(HostScript(asHost), HostProp(asHost), false)
    EndIf
    Return SeverActionsNativeExt2.Settings_GetBool(asKey)
EndFunction

Int Function SettingInt(String asKey, String asRead, String asHost)
    If asRead == "property"
        Return SeverActionsNativeExt2.Script_GetInt(HostScript(asHost), HostProp(asHost), 0)
    EndIf
    Return SeverActionsNativeExt2.Settings_GetInt(asKey)
EndFunction

Float Function SettingFloat(String asKey, String asRead, String asHost, String asValueType, Float afLiveScale)
    {A slider's value (an int row drawn as a float). A row whose live call takes another unit is stored in the
     slider's unit; ApplyLive scales it on the way out.}
    Float v
    If asValueType == "int"
        v = SettingInt(asKey, asRead, asHost) as Float
    ElseIf asRead == "property"
        v = SeverActionsNativeExt2.Script_GetFloat(HostScript(asHost), HostProp(asHost), 0.0)
    Else
        v = SeverActionsNativeExt2.Settings_GetFloat(asKey)
    EndIf
    Return v
EndFunction

String Function HostScript(String asHost)
    Int dot = StringUtil.Find(asHost, ".")
    If dot < 0
        Return ""
    EndIf
    Return StringUtil.Substring(asHost, 0, dot)
EndFunction

String Function HostProp(String asHost)
    Int dot = StringUtil.Find(asHost, ".")
    If dot < 0
        Return ""
    EndIf
    Return StringUtil.Substring(asHost, dot + 1)
EndFunction

Function WriteSetting(String asRow, String asValueText)
    {The one write path for a setting row, then ApplyLive:
       handler  - Native_SettingsApply: host property, live push, global settings file and Authority in one call.
       set      - Settings_Set: the Authority row alone, for a K/M key the handler has no branch for (it would
                  be lost in the handler's final else).
       property - Script_Set*: a tier-P key, whose owner property is its only record.}
    String settingKey = SeverActions_ModuleBase.VerbField(asRow, ROW_ID)
    String write = SeverActions_ModuleBase.VerbField(asRow, ROW_WRITE)

    If write == "handler"
        SeverActionsNativeExt2.Native_SettingsApply(SeverActions_ModuleBase.VerbField(asRow, ROW_HANDLERPAGE), settingKey, asValueText)
    ElseIf write == "set"
        SeverActionsNativeExt2.Settings_Set(settingKey, asValueText)
    ElseIf write == "property"
        WriteProperty(SeverActions_ModuleBase.VerbField(asRow, ROW_HOST), SeverActions_ModuleBase.VerbField(asRow, ROW_VALUETYPE), asValueText)
    Else
        Debug.Trace("[SeverActions_MCM] WriteSetting: the row '" + settingKey + "' has no write contract")
        Return
    EndIf

    ApplyLive(asRow, asValueText)
EndFunction

Function WriteProperty(String asHost, String asValueType, String asValueText)
    {A tier-P row's write to its owner's property, through the ScriptObjectAccess gate. The setter follows the
     table's valueType, not the text, so "0" reaches an Int row as 0 and a String row as "0".}
    If asValueType == "bool"
        SeverActionsNativeExt2.Script_SetBool(HostScript(asHost), HostProp(asHost), asValueText == "true")
    ElseIf asValueType == "int"
        SeverActionsNativeExt2.Script_SetInt(HostScript(asHost), HostProp(asHost), asValueText as Int)
    ElseIf asValueType == "float"
        SeverActionsNativeExt2.Script_SetFloat(HostScript(asHost), HostProp(asHost), asValueText as Float)
    Else
        SeverActionsNativeExt2.Script_SetString(HostScript(asHost), HostProp(asHost), asValueText)
    EndIf
EndFunction

Function ApplyLive(String asRow, String asValueText)
    {The live call a row needs beyond its write path, then the page refresh some rows ask for. Check 13 (f)
     fails a liveApply call with no branch here.}
    String call = SeverActions_ModuleBase.VerbField(asRow, ROW_LIVECALL)
    Float scale = SeverActions_ModuleBase.VerbField(asRow, ROW_LIVESCALE) as Float
    If scale == 0.0
        scale = 1.0
    EndIf

    If call == "SeverActionsNativeExt.SituationMonitor_SetEnabled"
        SeverActionsNativeExt.SituationMonitor_SetEnabled(asValueText == "true")
    ElseIf call == "SeverActionsNativeExt.SituationMonitor_SetStabilityThreshold"
        SeverActionsNativeExt.SituationMonitor_SetStabilityThreshold(((asValueText as Float) * scale) as Int)
    ElseIf call == "SeverActionsNativeExt.Native_Outfit_SetDeferBondage"
        SeverActionsNativeExt.Native_Outfit_SetDeferBondage(asValueText == "true")
    ElseIf call == "SeverActionsNativeExt2.Venture_SetEnabled"
        SeverActionsNativeExt2.Venture_SetEnabled(asValueText == "true")
    ElseIf call != ""
        Debug.Trace("[SeverActions_MCM] ApplyLive: no branch for the call '" + call + "'")
    EndIf

    If Math.LogicalAnd(SeverActions_ModuleBase.VerbField(asRow, ROW_FLAGS) as Int, FLAG_LIVEREFRESH) != 0
        ForcePageReset()
    EndIf
EndFunction

Bool Function ApplyClamp(String asRow, Float afValue)
    {Move a min/max row's sibling so neither passes the other; true when it moved. The sibling is a settings
     key, not necessarily on this page, so its contract comes from Mcm_Contract.}
    String sibling = SeverActions_ModuleBase.VerbField(asRow, ROW_CLAMPSIB)
    If sibling == ""
        Return false
    EndIf
    String rule = SeverActions_ModuleBase.VerbField(asRow, ROW_CLAMPRULE)
    String c = SeverActionsNativeExt2.Mcm_Contract(sibling)
    If c == ""
        Return false
    EndIf
    ; Mcm_Contract serves the payload's contract tail, so each field sits at ROW_<X> - ROW_TIER.
    String read = SeverActions_ModuleBase.VerbField(c, ROW_READ - ROW_TIER)
    String host = SeverActions_ModuleBase.VerbField(c, ROW_HOST - ROW_TIER)
    String vtype = SeverActions_ModuleBase.VerbField(c, ROW_VALUETYPE - ROW_TIER)
    Float other = SettingFloat(sibling, read, host, vtype, 0.0)

    If rule == "raisesMax" && other >= afValue
        Return false
    EndIf
    If rule == "lowersMin" && other <= afValue
        Return false
    EndIf
    WriteSettingByKey(sibling, c, FloatText(afValue, vtype))
    Return true
EndFunction

Function WriteSettingByKey(String asKey, String asContract, String asValueText)
    {Write a setting reached by key rather than row (a clamp sibling), by its contract tail.}
    String write = SeverActions_ModuleBase.VerbField(asContract, ROW_WRITE - ROW_TIER)
    If write == "handler"
        SeverActionsNativeExt2.Native_SettingsApply(SeverActions_ModuleBase.VerbField(asContract, ROW_HANDLERPAGE - ROW_TIER), asKey, asValueText)
    ElseIf write == "set"
        SeverActionsNativeExt2.Settings_Set(asKey, asValueText)
    ElseIf write == "property"
        WriteProperty(SeverActions_ModuleBase.VerbField(asContract, ROW_HOST - ROW_TIER), SeverActions_ModuleBase.VerbField(asContract, ROW_VALUETYPE - ROW_TIER), asValueText)
    EndIf
EndFunction

String Function FloatText(Float afValue, String asValueType)
    {A slider value as settings text; an int row must not arrive as "5.000000".}
    If asValueType == "int"
        Return "" + (afValue as Int)
    EndIf
    Return "" + afValue
EndFunction

; =============================================================================
; MENUS
; =============================================================================

String[] Function MenuEntries(String asRow)
    {The option list a menu row offers: a compile-time list from the table, or a runtime one this page built.}
    String list = SeverActions_ModuleBase.VerbField(asRow, ROW_MENULIST)
    If list != ""
        Return SeverActionsNativeExt2.Mcm_MenuOptions(list)
    EndIf
    Return RuntimeMenuEntries(SeverActions_ModuleBase.VerbField(asRow, ROW_MENUSOURCE))
EndFunction

String[] Function RuntimeMenuEntries(String asSource)
    If asSource == "companionRoster"
        Return DisplayNames(CachedManagedFollowers)
    ElseIf asSource == "dismissedWithHomes"
        Return DisplayNames(CachedDismissedFollowers)
    ElseIf asSource == "outfitPresetActors"
        Return DisplayNames(CachedPresetActors)
    ElseIf asSource == "bioTabs"
        Return BioTabs
    ElseIf asSource == "bioBlocksInTab"
        Return BioBlockTitles
    ElseIf asSource == "appliedBioBlocks"
        Return BioAssignedTitles
    ElseIf asSource == "bioTargetFactions"
        Return BioTargetFactions
    EndIf
    Debug.Trace("[SeverActions_MCM] RuntimeMenuEntries: no branch for the source '" + asSource + "'")
    Return PapyrusUtil.StringArray(0)
EndFunction

String[] Function DisplayNames(Actor[] akList)
    Int n = ArrayLen(akList)
    String[] out = PapyrusUtil.StringArray(n)
    Int i = 0
    While i < n
        If akList[i]
            out[i] = akList[i].GetDisplayName()
        EndIf
        i += 1
    EndWhile
    Return out
EndFunction

String Function MenuEntryAt(String asListId, Int aiIndex)
    String[] entries = SeverActionsNativeExt2.Mcm_MenuOptions(asListId)
    If !entries || aiIndex < 0 || aiIndex >= entries.Length
        Return ""
    EndIf
    Return entries[aiIndex]
EndFunction

String Function MenuValueText(String asRow)
    {What a setting menu row shows: the entry its stored value selects. A VR chord button/modifier row stores a
     controller CODE (0/1/7/2/32/33/35), not an index; MenuStartIndex converts it.}
    String settingKey = SeverActions_ModuleBase.VerbField(asRow, ROW_ID)
    Return EntryTextAt(asRow, MenuStartIndex(asRow, 0))
EndFunction

String Function VRChordSlot(String asKey)
    {The Native_GetVRChord / Native_SetVRChord slot name behind a vr* settings key.}
    If asKey == "vrMenuHand"
        Return "menuHand"
    ElseIf asKey == "vrMenuModifier"
        Return "menuModifier"
    ElseIf asKey == "vrMenuButton"
        Return "menuButton"
    ElseIf asKey == "vrWheelHand"
        Return "wheelHand"
    ElseIf asKey == "vrWheelModifier"
        Return "wheelModifier"
    ElseIf asKey == "vrWheelButton"
        Return "wheelButton"
    EndIf
    Return ""
EndFunction

Bool Function IsVRChordKey(String asKey)
    Return VRChordSlot(asKey) != ""
EndFunction

; =============================================================================
; OPTION EVENTS: each finds the row behind the clicked option and acts on what it says; a non-setting row falls
; through to DoAction / DoSliderAction / DoMenuAction / DoDefaultAction.
; =============================================================================

Event OnOptionSelect(int option)
    Int row = RowAt(option)
    If row < 0
        Return
    EndIf
    String r = _rows[row]
    String type = SeverActions_ModuleBase.VerbField(r, ROW_TYPE)
    Int entry = EntryAt(option)

    If type == "setting" && SeverActions_ModuleBase.VerbField(r, ROW_CONTROL) == "toggle"
        Bool newValue = !SettingBool(SeverActions_ModuleBase.VerbField(r, ROW_ID), SeverActions_ModuleBase.VerbField(r, ROW_READ), SeverActions_ModuleBase.VerbField(r, ROW_HOST))
        WriteSetting(r, BoolToStr(newValue))
        SetToggleOptionValue(option, newValue)
        Return
    EndIf

    DoAction(SeverActions_ModuleBase.VerbField(r, ROW_ID), entry, option)
EndEvent

Event OnOptionSliderOpen(int option)
    Int row = RowAt(option)
    If row < 0
        Return
    EndIf
    String r = _rows[row]
    SetSliderDialogStartValue(RowFloat(r, EntryAt(option)))
    SetSliderDialogRange(SeverActions_ModuleBase.VerbField(r, ROW_SMIN) as Float, SeverActions_ModuleBase.VerbField(r, ROW_SMAX) as Float)
    SetSliderDialogInterval(SeverActions_ModuleBase.VerbField(r, ROW_SSTEP) as Float)
    SetSliderDialogDefaultValue(SeverActions_ModuleBase.VerbField(r, ROW_SDEF) as Float)
EndEvent

Event OnOptionSliderAccept(int option, float value)
    Int row = RowAt(option)
    If row < 0
        Return
    EndIf
    String r = _rows[row]
    String format = SeverActions_ModuleBase.VerbField(r, ROW_FORMAT)

    If SeverActions_ModuleBase.VerbField(r, ROW_TYPE) == "setting"
        WriteSetting(r, FloatText(value, SeverActions_ModuleBase.VerbField(r, ROW_VALUETYPE)))
        SetSliderOptionValue(option, value, format)
        ; Only when the sibling moved: a reset on every accept would close the slider the player is using.
        If ApplyClamp(r, value)
            ForcePageReset()
        EndIf
        Return
    EndIf

    DoSliderAction(SeverActions_ModuleBase.VerbField(r, ROW_ID), EntryAt(option), option, value, format)
EndEvent

Event OnOptionMenuOpen(int option)
    Int row = RowAt(option)
    If row < 0
        Return
    EndIf
    String r = _rows[row]
    String[] entries = MenuEntries(r)
    If !entries || entries.Length == 0
        Return
    EndIf
    SetMenuDialogOptions(entries)
    SetMenuDialogStartIndex(MenuStartIndex(r, EntryAt(option)))
    SetMenuDialogDefaultIndex(MenuDefaultIndex(r))
EndEvent

Int Function MenuStartIndex(String asRow, Int aiEntry)
    String settingKey = SeverActions_ModuleBase.VerbField(asRow, ROW_ID)
    If SeverActions_ModuleBase.VerbField(asRow, ROW_TYPE) == "setting"
        ; chord button/modifier rows store a controller CODE; the hand rows store the index
        If IsVRChordKey(settingKey) && settingKey != "vrMenuHand" && settingKey != "vrWheelHand"
            Return VRChordIndexOf(SeverActionsNativeExt2.Native_GetVRChord(VRChordSlot(settingKey)))
        EndIf
        If IsVRChordKey(settingKey)
            Return SeverActionsNativeExt2.Native_GetVRChord(VRChordSlot(settingKey))
        EndIf
        Return SettingInt(settingKey, SeverActions_ModuleBase.VerbField(asRow, ROW_READ), SeverActions_ModuleBase.VerbField(asRow, ROW_HOST))
    EndIf
    Return StateMenuIndex(settingKey, aiEntry)
EndFunction

Int Function MenuDefaultIndex(String asRow)
    String settingKey = SeverActions_ModuleBase.VerbField(asRow, ROW_ID)
    String def = SeverActions_ModuleBase.VerbField(asRow, ROW_DEFAULT)
    If def == ""
        Return 0
    EndIf
    If IsVRChordKey(settingKey) && settingKey != "vrMenuHand" && settingKey != "vrWheelHand"
        Return VRChordIndexOf(def as Int)
    EndIf
    Return def as Int
EndFunction

Event OnOptionMenuAccept(int option, int index)
    Int row = RowAt(option)
    If row < 0
        Return
    EndIf
    String r = _rows[row]
    String settingKey = SeverActions_ModuleBase.VerbField(r, ROW_ID)

    If SeverActions_ModuleBase.VerbField(r, ROW_TYPE) == "setting"
        If IsVRChordKey(settingKey)
            Int code = index
            If settingKey != "vrMenuHand" && settingKey != "vrWheelHand"
                code = VRChordCodeAt(index)
            EndIf
            SetVRChord(settingKey, code, option)
            Return
        EndIf
        WriteSetting(r, "" + index)
        SetMenuOptionValue(option, EntryTextAt(r, index))
        Return
    EndIf

    DoMenuAction(settingKey, EntryAt(option), option, index, EntryTextAt(r, index))
EndEvent

String Function EntryTextAt(String asRow, Int aiIndex)
    {The text of the aiIndex-th entry of the option list a menu row offers.}
    String[] entries = MenuEntries(asRow)
    If !entries || aiIndex < 0 || aiIndex >= entries.Length
        Return ""
    EndIf
    Return entries[aiIndex]
EndFunction

Event OnOptionKeyMapChange(int option, int keyCode, string conflictControl, string conflictName)
    Int row = RowAt(option)
    If row < 0
        Return
    EndIf
    String r = _rows[row]
    If SeverActions_ModuleBase.VerbField(r, ROW_TYPE) != "keymap"
        Return
    EndIf
    String hotkeyId = SeverActions_ModuleBase.VerbField(r, ROW_ID)

    If conflictControl != ""
        String msg = "$SA_ThisKeyIsAlreadyUsedBy{" + conflictControl + "}"
        If conflictName != ""
            msg = "$SA_ThisKeyIsAlreadyUsedByFrom{" + conflictControl + "}{" + conflictName + "}"
        EndIf
        If !ShowMessage(msg, true, "$SA_Yes", "$SA_No")
            Return
        EndIf
    EndIf

    ; The code IS the setting (rule 17): Hotkey_SetCode feeds the Authority row the DLL's input sink reads.
    SeverActionsNativeExt2.Hotkey_SetCode(hotkeyId, keyCode)
    SetKeyMapOptionValue(option, keyCode)
EndEvent


Event OnOptionHighlight(int option)
    If _leftoverSlot >= 0 && option % 256 == _leftoverSlot
        SetInfoText(_leftoverInfo)
        Return
    EndIf
    Int row = RowAt(option)
    If row < 0
        SetInfoText("")
        Return
    EndIf
    ; a notice row draws a short line (ComputedValue); its whole text is the info text
    String rowId = SeverActions_ModuleBase.VerbField(_rows[row], ROW_ID)
    If StringUtil.Find(rowId, "modNotice-") == 0
        SetInfoText(ModuleNoticeInfo(ModuleOfRowId(rowId)))
        Return
    ElseIf StringUtil.Find(rowId, "modHowTo-") == 0
        SetInfoText(SeverActionsNativeExt2.Native_L10nFmt("mcm.moduleHowTo", SeverActionsNativeExt2.Module_Option(ModuleOfRowId(rowId))))
        Return
    EndIf
    ; a greyed hotkey row says which module it needs instead of what the hotkey does (see RowFlags)
    String absent = KeymapAbsentModule(_rows[row])
    If absent != ""
        SetInfoText(ModuleNoticeInfo(absent))
        Return
    EndIf
    SetInfoText(RowTooltip(_rows[row], EntryAt(option)))
EndEvent

String Function RowTooltip(String asRow, Int aiEntry)
    ; A row's info text. Eight tooltips name the actor or preset they are about: the table holds the constant
    ; part (a $SA_ key SkyUI substitutes into, so the closing brace is added here) and this completes it. Not a
    ; doc string: a brace inside one ends it.
    String tip = SeverActions_ModuleBase.VerbField(asRow, ROW_TOOLTIP)
    If tip == ""
        Return ""
    EndIf
    String rowId = SeverActions_ModuleBase.VerbField(asRow, ROW_ID)

    If rowId == "fmRapport" || rowId == "fmTrust" || rowId == "fmLoyalty" || rowId == "fmCombatStyle"
        Return tip + CompanionName() + "}"
    ElseIf rowId == "fmMood"
        Return CompanionName() + tip
    ElseIf rowId == "fmDeletePreset"
        Return tip + CachedPresetNames[aiEntry] + "}"
    ElseIf rowId == "outfitDeletePreset"
        Return tip + CachedOutfitPresetNames[aiEntry] + "}"
    ElseIf rowId == "followerExclude"
        Actor f = RowActor(aiEntry)
        If f
            Return f.GetDisplayName() + tip
        EndIf
        Return tip
    EndIf
    Return tip
EndFunction

String Function CompanionName()
    If _selCompanion
        Return _selCompanion.GetDisplayName()
    EndIf
    Return ""
EndFunction

Event OnOptionDefault(int option)
    Int row = RowAt(option)
    If row < 0
        Return
    EndIf
    String r = _rows[row]
    String type = SeverActions_ModuleBase.VerbField(r, ROW_TYPE)
    String control = SeverActions_ModuleBase.VerbField(r, ROW_CONTROL)
    Int entry = EntryAt(option)

    If type == "setting"
        ; the table's DR18 runtime default; a slider's dialog default is only where its dialog opens
        String def = SeverActions_ModuleBase.VerbField(r, ROW_DEFAULT)
        String settingKey = SeverActions_ModuleBase.VerbField(r, ROW_ID)
        If IsVRChordKey(settingKey)
            SetVRChord(settingKey, def as Int, option)
            Return
        EndIf
        WriteSetting(r, def)
        If control == "toggle"
            SetToggleOptionValue(option, def == "true")
        ElseIf control == "slider"
            SetSliderOptionValue(option, def as Float, SeverActions_ModuleBase.VerbField(r, ROW_FORMAT))
            ApplyClamp(r, def as Float)
        ElseIf control == "menu"
            SetMenuOptionValue(option, EntryTextAt(r, def as Int))
        EndIf
        Return
    EndIf

    If type == "keymap"
        SeverActionsNativeExt2.Hotkey_SetCode(SeverActions_ModuleBase.VerbField(r, ROW_ID), -1)
        SetKeyMapOptionValue(option, -1)
        Return
    EndIf

    DoDefaultAction(SeverActions_ModuleBase.VerbField(r, ROW_ID), entry, option)
EndEvent

; =============================================================================
; BESPOKE ROWS: what an action, selector or per-entry row reads and does. The layout's `calls` column records
; the functions each reaches; check 13 (f) fails a call whose script no longer declares it.
; =============================================================================

Bool Function StateBool(String asRowId, Int aiEntry)
    {A non-setting toggle's value.}
    If asRowId == "fmPerActorAutoSwitch"
        Return _selCompanion != None && SeverActionsNative.Native_Outfit_GetAutoSwitchEnabled(_selCompanion)
    ElseIf asRowId == "outfitLock"
        ; SeverActions_Outfit.HasNonFollowerOutfitLock's test through the natives (not a cross site, check 17)
        Return _selPresetActor != None && SeverActionsNativeExt.Native_Outfit_IsLockActive(_selPresetActor) && !SeverActionsNativeExt.Native_Outfit_IsFollowerLock(_selPresetActor)
    ElseIf asRowId == "followerExclude"
        ; the toggle reads INCLUDED, so it is the negation of the exclusion
        Return SeverActionsNativeExt2.Module_IsUsable("survival") && RowActor(aiEntry) != None && !SeverActions_ModuleBase.CallBool("survival", "isFollowerExcluded", RowActor(aiEntry))
    EndIf
    Debug.Trace("[SeverActions_MCM] StateBool: no branch for the row '" + asRowId + "'")
    Return false
EndFunction

Float Function StateFloat(String asRowId, Int aiEntry)
    {A non-setting slider's value.}
    If asRowId == "fmRapport"
        Return SeverActionsNative.Native_GetRapport(_selCompanion)
    ElseIf asRowId == "fmTrust"
        Return SeverActionsNative.Native_GetTrust(_selCompanion)
    ElseIf asRowId == "fmLoyalty"
        Return SeverActionsNative.Native_GetLoyalty(_selCompanion)
    ElseIf asRowId == "fmMood"
        Return SeverActionsNative.Native_GetMood(_selCompanion)
    ElseIf asRowId == "entWage"
        Return EntWage as Float
    EndIf
    Debug.Trace("[SeverActions_MCM] StateFloat: no branch for the row '" + asRowId + "'")
    Return 0.0
EndFunction

Int Function StateMenuIndex(String asRowId, Int aiEntry)
    {Where a non-setting menu's dialog opens.}
    If asRowId == "fmCompanionSelect"
        Return SelectedCompanionIdx
    ElseIf asRowId == "fmDismissedSelect"
        Return SelectedDismissedIdx
    ElseIf asRowId == "outfitNPCSelect"
        Return SelectedOutfitNPCIdx
    ElseIf asRowId == "fmCombatStyle"
        Return CombatStyleIndexFromString(CompanionCombatStyle(_selCompanion))
    ElseIf asRowId == "bioTab"
        Return BioTabIdx
    ElseIf asRowId == "bioBlock"
        Return BioBlockIdx
    ElseIf asRowId == "entJob"
        Return EntJob
    ElseIf asRowId == "entArrangement"
        Return EntArrangement
    ElseIf asRowId == "bioGrantFaction" || asRowId == "bioRemoveBlock"
        ; pick-and-act: no standing selection, so the dialog opens at the top and the pick performs the action
        Return 0
    EndIf
    Return 0
EndFunction

Function DoAction(String asRowId, Int aiEntry, Int aiOption)
    {A button press.}

    ; --- followers ---
    If asRowId == "fmPerActorAutoSwitch"
        If _selCompanion
            ; Outfit state, not a setting: the verb reaches the module that owns the native flag and its per-actor
            ; StorageUtil mirror. Verb_Send's args are the 7-field tail target|target2|str|int|str2|targetFid|
            ; target2Fid: the value rides in str, the actor as the sender.
            Bool newVal = !SeverActionsNative.Native_Outfit_GetAutoSwitchEnabled(_selCompanion)
            SeverActionsNativeExt2.Verb_Send("outfit", "setActorAutoSwitch", "||" + BoolToStr(newVal), _selCompanion)
            SetToggleOptionValue(aiOption, newVal)
        EndIf

    ; Actions the page redraws from go through a provider service: CallBool runs synchronously, so the
    ; ForcePageReset after it draws the new state (DR13; a verb is queued and would still be pending). CallBool
    ; answers False without the module.
    ElseIf asRowId == "fmDismissFollower"
        If SeverActionsNativeExt2.Module_IsUsable("followers") && _selCompanion
            If ShowMessage("$SA_DismissX{" + _selCompanion.GetDisplayName() + "}", true, "$SA_Yes", "$SA_No")
                ; FollowerManager.DismissCompanion with send-home and a deliberate exit, so NFF's alias seat comes
                ; down with our roster entry (otherwise the follower is left undismissable).
                SeverActions_ModuleBase.CallBool("followers", "dismiss", _selCompanion)
                ForcePageReset()
            EndIf
        EndIf

    ElseIf asRowId == "fmAssignHome" || asRowId == "fmAssignHomeUnset"
        ; two ids, one action: Assign Home draws under the current home or in its place, and an id is the
        ; dispatch key
        If SeverActionsNativeExt2.Module_IsUsable("followers") && _selCompanion
            Location currentLoc = Game.GetPlayer().GetCurrentLocation()
            If currentLoc && currentLoc.GetName() != ""
                SeverActions_ModuleBase.CallBool("followers", "assignHome", _selCompanion, None, currentLoc.GetName())
                ForcePageReset()
            ElseIf currentLoc
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.currentLocationNoName"))
            Else
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.noLocationDetected"))
            EndIf
        EndIf

    ElseIf asRowId == "fmClearHome"
        If SeverActionsNativeExt2.Module_IsUsable("followers") && _selCompanion
            SeverActions_ModuleBase.CallBool("followers", "clearHome", _selCompanion)
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.homeCleared", ("" + _selCompanion.GetDisplayName())))
            ForcePageReset()
        EndIf

    ElseIf asRowId == "fmForceRemove"
        If SeverActionsNativeExt2.Module_IsUsable("followers") && _selCompanion
            String fName = _selCompanion.GetDisplayName()
            If ShowMessage("$SA_ForceRemoveXThisErases{" + fName + "}", true, "$SA_Yes", "$SA_No")
                ; the whole removal is the service's (FollowerManager.ForceRemoveFollower: the combat style
                ; back, PurgeFollower, then the native follower and outfit rows, in that order)
                SeverActions_ModuleBase.CallBool("followers", "purge", _selCompanion)
                ForcePageReset()
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.forceRemoved", ("" + fName)))
            EndIf
        EndIf

    ElseIf asRowId == "fmDeletePreset"
        If SeverActionsNativeExt2.Module_IsUsable("outfit") && _selCompanion && CachedPresetNames && aiEntry < CachedPresetNames.Length
            If ShowMessage("Delete outfit preset '" + CachedPresetNames[aiEntry] + "' for " + _selCompanion.GetDisplayName() + "?", true, "$SA_Yes", "$SA_No")
                ; the STORED name, verbatim - never re-normalised
                SeverActions_ModuleBase.CallBool("outfit", "deletePreset", _selCompanion, None, CachedPresetNames[aiEntry])
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.deletedPreset", ("" + CachedPresetNames[aiEntry])))
                ForcePageReset()
            EndIf
        EndIf

    ElseIf asRowId == "fmResetAll"
        If SeverActionsNativeExt2.Module_IsUsable("followers")
            If ShowMessage("$SA_This_will_dismiss_ALL_companions_and_clear_all_r", true, "$SA_Yes", "$SA_No")
                ; Every rostered follower is dismissed without send-home or a deliberate exit (so
                ; NFF keeps its followers).
                SeverActions_ModuleBase.CallBool("followers", "resetAll")
                ForcePageReset()
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.allCompanionsDismissed"))
            EndIf
        EndIf

    ; --- outfits ---
    ElseIf asRowId == "outfitLock"
        If SeverActionsNativeExt2.Module_IsUsable("outfit") && _selPresetActor
            ; HasNonFollowerOutfitLock's test, as in StateBool
            Bool currentLock = SeverActionsNativeExt.Native_Outfit_IsLockActive(_selPresetActor) && !SeverActionsNativeExt.Native_Outfit_IsFollowerLock(_selPresetActor)
            ; Turning the lock ON needs the outfit system, the global Outfit Lock toggle and armor to capture, or
            ; SetNonFollowerOutfitLock refuses; so the toggle is drawn from the store AFTER the call. Neither switch
            ; has an MCM row, so the notice points to the Magelight Settings page.
            If !currentLock && !SeverActionsNativeExt2.Native_Outfit_IsSystemEnabled()
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.outfitSystemOff"))
            ElseIf !currentLock && !SeverActionsNativeExt2.Script_GetBool("SeverActions_Outfit", "OutfitLockEnabled", false)   ; tier-P property through the kernel gate, not a cross site (check 17)
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.outfitLockOff"))
            EndIf
            ; SeverActions_Outfit.SetNonFollowerOutfitLock, synchronously
            Float want = 1.0
            If currentLock
                want = 0.0
            EndIf
            SeverActions_ModuleBase.CallBool("outfit", "setNonFollowerLock", _selPresetActor, None, "", want)
            Bool nowLocked = SeverActionsNativeExt.Native_Outfit_IsLockActive(_selPresetActor) && !SeverActionsNativeExt.Native_Outfit_IsFollowerLock(_selPresetActor)
            SetToggleOptionValue(aiOption, nowLocked)
            If !currentLock && !nowLocked
                Debug.Trace("[SeverActions_MCM] outfitLock: no lock written for " + _selPresetActor.GetDisplayName() + " (Outfit Lock or the outfit system is off, or nothing is worn)")
            EndIf
            ; an outfit alias seat only for a lock that exists
            If nowLocked
                SeverActions_ModuleBase.CallBool("outfit", "assignOutfitSlot", _selPresetActor)
            Else
                SeverActions_ModuleBase.CallBool("outfit", "clearOutfitSlot", _selPresetActor)
            EndIf
        EndIf

    ElseIf asRowId == "outfitDeletePreset"
        If SeverActionsNativeExt2.Module_IsUsable("outfit") && _selPresetActor && CachedOutfitPresetNames && aiEntry < CachedOutfitPresetNames.Length
            If ShowMessage("Delete outfit preset '" + CachedOutfitPresetNames[aiEntry] + "' for " + _selPresetActor.GetDisplayName() + "?", true, "$SA_Yes", "$SA_No")
                ; the STORED name, verbatim - never re-normalised
                SeverActions_ModuleBase.CallBool("outfit", "deletePreset", _selPresetActor, None, CachedOutfitPresetNames[aiEntry])
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.deletedPreset", ("" + CachedOutfitPresetNames[aiEntry])))
                ForcePageReset()
            EndIf
        EndIf

    ; --- survival ---
    ElseIf asRowId == "followerExclude"
        Actor f = RowActor(aiEntry)
        If SeverActionsNativeExt2.Module_IsUsable("survival") && f
            ; the service toggles and answers the NEW exclusion
            Bool isExcluded = SeverActions_ModuleBase.CallBool("survival", "toggleExcluded", f)
            SetToggleOptionValue(aiOption, !isExcluded)
            If isExcluded
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.excludedFromSurvival", ("" + f.GetDisplayName())))
            Else
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.includedInSurvival", ("" + f.GetDisplayName())))
            EndIf
        EndIf

    ; --- crime ---
    ElseIf asRowId == "bountyWhiterun" || asRowId == "bountyRift" || asRowId == "bountyHaafingar" || asRowId == "bountyEastmarch" || asRowId == "bountyReach" || asRowId == "bountyFalkreath" || asRowId == "bountyPale" || asRowId == "bountyHjaalmarch" || asRowId == "bountyWinterhold"
        ClearBountyWithConfirm(HoldFactionAt(aiEntry), HoldNameAt(aiEntry))

    ElseIf asRowId == "clearAllBounties"
        ClearAllBountiesWithConfirm()

    ; --- travel ---
    ElseIf asRowId == "travelJourneyLine"
        CancelJourneyWithConfirm(aiEntry)

    ElseIf asRowId == "resetTravelSlots"
        If ShowMessage("$SA_This_will_cancel_ALL_active_NPC_travel_restore_f", true, "$SA_Yes", "$SA_No") && SeverActionsNativeExt2.Module_IsUsable("travel")
            ; SeverActions_Travel.ForceResetAllSlots(true) through the travel provider: 1.0 restores followers
            SeverActions_ModuleBase.CallBool("travel", "cancelAllJourneys", None, None, "", 1.0)
            ForcePageReset()
        EndIf

    ; --- homes ---
    ElseIf asRowId == "clearNPCHome"
        If SeverActionsNativeExt2.Module_IsUsable("followers") && CachedHomedNPCs && aiEntry < CachedHomedNPCs.Length && CachedHomedNPCs[aiEntry]
            SeverActions_ModuleBase.CallBool("followers", "clearHome", CachedHomedNPCs[aiEntry])
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.homeCleared", ("" + CachedHomedNPCs[aiEntry].GetDisplayName())))
            ForcePageReset()
        EndIf

    ElseIf asRowId == "fmDismissedClearHome"
        If SeverActionsNativeExt2.Module_IsUsable("followers") && _selDismissed
            SeverActions_ModuleBase.CallBool("followers", "clearHome", _selDismissed)
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.homeCleared", ("" + _selDismissed.GetDisplayName())))
            ForcePageReset()
        EndIf

    ElseIf asRowId == "fmDismissedReRecruit"
        If SeverActionsNativeExt2.Module_IsUsable("followers") && _selDismissed
            If ShowMessage("$SA_ReRecruitX{" + _selDismissed.GetDisplayName() + "}", true, "$SA_Yes", "$SA_No")
                ; the existing "rerecruit" service: FollowerManager.RegisterFollower
                SeverActions_ModuleBase.CallBool("followers", "rerecruit", _selDismissed)
                ForcePageReset()
            EndIf
        EndIf

    ; --- bio blocks ---
    ElseIf asRowId == "bioApply"
        If BioTargetActor && BioBlockIds && BioBlockIds.Length > 0 && BioBlockIdx < BioBlockIds.Length
            If SeverActionsNativeExt2.Native_BioBlock_Apply(BioTargetActor, BioBlockIds[BioBlockIdx])
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.bioBlockApplied", ("" + BioTargetActor.GetDisplayName())))
            Else
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.bioBlocksAlreadyApplied"))
            EndIf
            ForcePageReset()
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.bioBlocksAimNpc"))
        EndIf

    ElseIf asRowId == "bioRule"
        If BioRuleNames && aiEntry < BioRuleNames.Length
            If SeverActionsNativeExt2.Native_BioBlock_RemoveFactionRule(aiEntry)
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.factionRuleRemoved"))
            EndIf
            ForcePageReset()
        EndIf

    ; --- enterprises (debug harness) ---
    ElseIf asRowId == "entHire"
        Actor entT = Game.GetCurrentCrosshairRef() as Actor
        If entT
            SeverActionsNativeExt2.Venture_DebugAdd(entT, EntJob, EntArrangement, EntWage)
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.enterprisesAimNpc"))
        EndIf
        ForcePageReset()

    ElseIf asRowId == "entRemove"
        Actor entR = Game.GetCurrentCrosshairRef() as Actor
        If entR
            SeverActionsNativeExt2.Venture_DebugRemove(entR)
        EndIf
        ForcePageReset()

    ElseIf asRowId == "entSettle"
        SeverActionsNativeExt2.Venture_ForceSettle()
        ForcePageReset()

    ElseIf asRowId == "entDump"
        SeverActionsNativeExt2.Venture_Dump()

    ElseIf asRowId == "entCollect"
        Actor entC = Game.GetCurrentCrosshairRef() as Actor
        If entC
            SeverActionsNativeExt2.Venture_Collect(entC)
            ForcePageReset()
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.enterprisesAimRetainer"))
        EndIf

    ElseIf asRowId == "entCollectAll"
        SeverActionsNativeExt2.Venture_CollectAll()
        ForcePageReset()

    ElseIf asRowId == "entForceArrest"
        Actor entA = Game.GetCurrentCrosshairRef() as Actor
        If entA
            SeverActionsNativeExt2.Venture_ForceArrest(entA)
            ForcePageReset()
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.enterprisesAimFence"))
        EndIf

    ElseIf asRowId == "entBail"
        Actor entB = Game.GetCurrentCrosshairRef() as Actor
        If entB
            SeverActionsNativeExt2.Venture_Bail(entB)
            ForcePageReset()
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.enterprisesAimJailed"))
        EndIf

    ElseIf asRowId == "entTestLetter"
        int letterId = SeverActionsNativeExt.Letter_DebugDeliverTest()
        If letterId > 0
            Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.courierLetterInInventory", ("" + letterId)))
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.letterDeliveryFailed"))
        EndIf
        ForcePageReset()

    ElseIf asRowId == "entTestCourier"
        DoCourierTest()

    ElseIf asRowId == "entTestCourierLLM"
        DoCourierLLMTest()

    ElseIf asRowId == "entForceAmbush"
        ; Fire a grudge thug ambush now (no delay/cooldown/location checks), arming a grudge if none is pending.
        ; The ambush listener is SeverActions_Ambush's own, registered on every load.
        If SeverActionsNativeExt2.Venture_DebugForceAmbush()
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.thugsOnTheirWay"))
        Else
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.noRetainersToAmbush"))
        EndIf

    ElseIf asRowId != ""
        Debug.Trace("[SeverActions_MCM] DoAction: no branch for the row '" + asRowId + "'")
    EndIf
EndFunction

Function DoCourierTest()
    {Send a sample letter by walking courier to test the walk-up / handoff loop; a random retainer is the named
     sender.}
    Actor letterSender = None
    int retCount = SeverActionsNativeExt2.Venture_Count()
    If retCount > 0
        letterSender = SeverActionsNativeExt2.Venture_GetAssigneeAt(Utility.RandomInt(0, retCount - 1))
    EndIf
    String subj = "A Word, When You Can"
    String body = "I'll keep this short, since paper costs me what little I've got.\n\nThe work goes - not well, not poorly, just on. But there's a matter I'd rather put to you in person than trust to a courier's pocket. Come find me when your road bends back this way.\n\nDon't make me send another of these. They're dear."
    ; The couriers provider's dispatchCourier: reason, subject and body joined by newlines. Without the
    ; bundle (Modular) the player gets the unavailable notice.
    If !SeverActions_ModuleBase.IsBound("couriers")
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.courierSystemUnavailable"))
        Return
    EndIf
    int dispatched = SeverActions_ModuleBase.CallInt("couriers", "dispatchCourier", letterSender, None, "meet\n" + subj + "\n" + body, 0.0)
    If dispatched <= 0
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.courierDispatchFailed"))
    ElseIf letterSender != None
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.courierOnWayFrom", ("" + letterSender.GetDisplayName())))
    Else
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.courierOnWayUnsigned"))
    EndIf
EndFunction

Function DoCourierLLMTest()
    {Force a real LLM-written letter from a random retainer; a courier brings it when the model returns.}
    int rc = SeverActionsNativeExt2.Venture_Count()
    If rc <= 0
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.noRetainersHire"))
        Return
    EndIf
    Actor r = SeverActionsNativeExt2.Venture_GetAssigneeAt(Utility.RandomInt(0, rc - 1))
    If r == None
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.couldNotResolveRetainer"))
        Return
    EndIf
    ; The letter listener is SeverActions_Courier's own, registered on every load.
    SeverActionsNativeExt2.Venture_DebugRequestLetter(r)
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.penningLetter", ("" + r.GetDisplayName())))
EndFunction

Function DoSliderAction(String asRowId, Int aiEntry, Int aiOption, Float afValue, String asFormat)
    {A slider that is not a settings row.}
    ; the four relationship values: FollowerManager's Set<X> are one-line forwarders to these natives
    If asRowId == "fmRapport"
        SeverActionsNativeExt.Native_SetRapport(_selCompanion, afValue)
        SetSliderOptionValue(aiOption, afValue, asFormat)
    ElseIf asRowId == "fmTrust"
        SeverActionsNativeExt.Native_SetTrust(_selCompanion, afValue)
        SetSliderOptionValue(aiOption, afValue, asFormat)
    ElseIf asRowId == "fmLoyalty"
        SeverActionsNativeExt.Native_SetLoyalty(_selCompanion, afValue)
        SetSliderOptionValue(aiOption, afValue, asFormat)
    ElseIf asRowId == "fmMood"
        SeverActionsNativeExt.Native_SetMood(_selCompanion, afValue)
        SetSliderOptionValue(aiOption, afValue, asFormat)
    ElseIf asRowId == "entWage"
        EntWage = afValue as Int
        SetSliderOptionValue(aiOption, afValue, asFormat)
    Else
        Debug.Trace("[SeverActions_MCM] DoSliderAction: no branch for the row '" + asRowId + "'")
    EndIf
EndFunction

Function DoMenuAction(String asRowId, Int aiEntry, Int aiOption, Int aiIndex, String asPick)
    {A menu that is not a settings row: a selector, or a one-shot pick that acts on its pick. asPick is the
     chosen entry's text.}
    If asRowId == "fmCompanionSelect"
        SelectedCompanionIdx = aiIndex
        ForcePageReset()

    ElseIf asRowId == "fmDismissedSelect"
        SelectedDismissedIdx = aiIndex
        ForcePageReset()

    ElseIf asRowId == "outfitNPCSelect"
        SelectedOutfitNPCIdx = aiIndex
        ForcePageReset()

    ElseIf asRowId == "fmCombatStyle"
        If SeverActionsNativeExt2.Module_IsUsable("followers") && _selCompanion
            ; Fire-and-forget, so a verb (FollowerManager.SetCombatStyle): nothing reads the row back and the drawn
            ; text is the pick. Args as in DoAction's fmPerActorAutoSwitch.
            SeverActionsNativeExt2.Verb_Send("followers", "setCombatStyle", "||" + asPick, _selCompanion)
            SetMenuOptionValue(aiOption, asPick)
        EndIf

    ElseIf asRowId == "bioTab"
        If BioTabs && aiIndex < BioTabs.Length
            BioTabIdx = aiIndex
            BioBlockIdx = 0
            SetMenuOptionValue(aiOption, asPick)
            ForcePageReset()
        EndIf

    ElseIf asRowId == "bioBlock"
        If BioBlockTitles && aiIndex < BioBlockTitles.Length
            BioBlockIdx = aiIndex
            SetMenuOptionValue(aiOption, asPick)
        EndIf

    ElseIf asRowId == "bioGrantFaction"
        If BioTargetActor && BioTargetFactions && aiIndex < BioTargetFactions.Length && BioBlockIds && BioBlockIdx < BioBlockIds.Length
            If SeverActionsNativeExt2.Native_BioBlock_GrantTargetFaction(BioTargetActor, aiIndex, BioBlockIds[BioBlockIdx])
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.blockGrantedTo", ("" + BioTargetFactions[aiIndex])))
            Else
                Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.bioBlocksCouldNotGrant"))
            EndIf
            ForcePageReset()
        EndIf

    ElseIf asRowId == "bioRemoveBlock"
        If BioTargetActor && BioAssignedIds && aiIndex < BioAssignedIds.Length
            SeverActionsNativeExt2.Native_BioBlock_Unapply(BioTargetActor, BioAssignedIds[aiIndex])
            Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.blockRemoved"))
            ForcePageReset()
        EndIf

    ElseIf asRowId == "entJob"
        EntJob = aiIndex
        SetMenuOptionValue(aiOption, asPick)

    ElseIf asRowId == "entArrangement"
        EntArrangement = aiIndex
        SetMenuOptionValue(aiOption, asPick)

    Else
        Debug.Trace("[SeverActions_MCM] DoMenuAction: no branch for the row '" + asRowId + "'")
    EndIf
EndFunction

Function DoDefaultAction(String asRowId, Int aiEntry, Int aiOption)
    {The Reset key on a row that is not a settings row.}
    If asRowId == "fmRapport"
        SeverActionsNativeExt.Native_SetRapport(_selCompanion, 0.0)
        SetSliderOptionValue(aiOption, 0.0, "{0}")
    ElseIf asRowId == "fmTrust"
        SeverActionsNativeExt.Native_SetTrust(_selCompanion, 25.0)
        SetSliderOptionValue(aiOption, 25.0, "{0}")
    ElseIf asRowId == "fmLoyalty"
        SeverActionsNativeExt.Native_SetLoyalty(_selCompanion, 50.0)
        SetSliderOptionValue(aiOption, 50.0, "{0}")
    ElseIf asRowId == "fmMood"
        SeverActionsNativeExt.Native_SetMood(_selCompanion, 50.0)
        SetSliderOptionValue(aiOption, 50.0, "{0}")
    ElseIf asRowId == "fmCombatStyle"
        If _selCompanion
            SeverActionsNativeExt2.Verb_Send("followers", "setCombatStyle", "||balanced", _selCompanion)
        EndIf
        SetMenuOptionValue(aiOption, "$SA_balanced")
    ElseIf asRowId == "fmPerActorAutoSwitch"
        If _selCompanion
            SeverActionsNativeExt2.Verb_Send("outfit", "setActorAutoSwitch", "||true", _selCompanion)
            SetToggleOptionValue(aiOption, true)
        EndIf
    ElseIf asRowId == "outfitLock"
        If SeverActionsNativeExt2.Module_IsUsable("outfit") && _selPresetActor
            SeverActions_ModuleBase.CallBool("outfit", "setNonFollowerLock", _selPresetActor, None, "", 0.0)
            SetToggleOptionValue(aiOption, false)
            SeverActions_ModuleBase.CallBool("outfit", "clearOutfitSlot", _selPresetActor)
        EndIf
    ElseIf asRowId == "entWage"
        EntWage = 200
        SetSliderOptionValue(aiOption, 200.0, "{0}g")
    EndIf
EndFunction

; =============================================================================
; HELPERS
; =============================================================================

String Function GetBountyDisplayText(Faction akCrimeFaction)
    {A hold's bounty as display text. SeverActions_ArrestBounty.GetTrackedBounty is this native behind a None
     guard, and the native answers 0 for None.}
    If !SeverActionsNativeExt2.Module_IsUsable("arrest")
        Return "N/A"
    EndIf
    Int bounty = SeverActionsNativeExt.Native_Bounty_Get(akCrimeFaction)
    If bounty > 0
        Return bounty + " gold"
    EndIf
    Return "None"
EndFunction

Function CancelJourneyWithConfirm(Int aiIndex)
    {Cancel one of the orchestrator's journeys after confirmation.}
    If !SeverActionsNativeExt2.Module_IsUsable("travel")
        Return
    EndIf
    ; Resolve the actor before the dialog: the journey list is a map walk whose indices shift if a journey ends
    ; meanwhile. (SeverActions_Travel.GetJourneyActor is this list's aiIndex-th entry.)
    Actor a = None
    Actor[] js = SeverActionsNativeExt2.Travel_GetOrderedJourneyActors()
    If js && aiIndex >= 0 && aiIndex < js.Length
        a = js[aiIndex]
    EndIf
    String line = ComputedLabel("travelJourneyLine", "travelJourneys", aiIndex)   ; the row's own text
    If !a || line == ""
        Return
    EndIf
    String confirmMsg = "Cancel this journey? " + line + ". This will end the travel and restore follower status if the trip dismissed them."
    If ShowMessage(confirmMsg, true, "$SA_Yes", "$SA_No")
        ShowMessage("Cancelling travel for " + a.GetDisplayName(), false)
        ; SeverActions_Travel.CancelTravel(a, true), synchronously, so the reset below draws the list without it
        ; (1.0 = restore follower status)
        SeverActions_ModuleBase.CallBool("travel", "cancelJourney", a, None, "", 1.0)
        ForcePageReset()
    EndIf
EndFunction

Function ClearTravelSlotWithConfirm(Int slotIndex)
    {Safe-exit stub; see CancelJourneyWithConfirm.}
    ; M-I-STUB 3.9.14-beta25 (P8-01): the five travel slots retired (CancelJourneyWithConfirm), plan P8
EndFunction

Function ClearBountyWithConfirm(Faction akCrimeFaction, String holdName)
    {Clear one hold's bounty after confirmation. ArrestBounty's Get/ClearTrackedBounty are these natives behind a
     None guard.}
    If !SeverActionsNativeExt2.Module_IsUsable("arrest") || !akCrimeFaction
        Return
    EndIf

    Int bounty = SeverActionsNativeExt.Native_Bounty_Get(akCrimeFaction)
    If bounty <= 0
        ShowMessage("$SA_YouHaveNoBountyIn{" + holdName + "}", false)
        Return
    EndIf

    String confirmMsg = "Clear your " + bounty + " gold bounty in " + holdName + "?"
    If ShowMessage(confirmMsg, true, "$SA_Yes", "$SA_No")
        SeverActionsNativeExt.Native_Bounty_Clear(akCrimeFaction)
        ForcePageReset()
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("mcm.bountyClearedIn", ("" + holdName)))
    EndIf
EndFunction

Function ClearAllBountiesWithConfirm()
    {Clear the nine holds' bounties after confirmation. Not Native_Bounty_GetTotal / ClearAll: those cover every
     faction in the store.}
    If !SeverActionsNativeExt2.Module_IsUsable("arrest")
        Return
    EndIf

    Int totalBounty = 0
    Int h = 0
    While h < 9
        totalBounty += SeverActionsNativeExt.Native_Bounty_Get(HoldFactionAt(h))
        h += 1
    EndWhile

    If totalBounty <= 0
        ShowMessage("$SA_You_have_no_bounties_in_any_hold", false)
        Return
    EndIf

    String confirmMsg = "Clear ALL bounties across all holds? Total: " + totalBounty + " gold."
    If ShowMessage(confirmMsg, true, "$SA_Yes", "$SA_No")
        h = 0
        While h < 9
            Faction hold = HoldFactionAt(h)
            If hold
                SeverActionsNativeExt.Native_Bounty_Clear(hold)   ; ClearTrackedBounty's None guard
            EndIf
            h += 1
        EndWhile
        ForcePageReset()
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.allBountiesCleared"))
    EndIf
EndFunction

String[] Function VisiblePresetNames(Actor akActor)
    {The user-visible preset names in store order (SeverActions_Outfit.GetPresetNames' filter): '_' entries
     ("_default") are the situation system's auto-saved baselines.}
    String[] out = PapyrusUtil.StringArray(0)
    If !akActor
        Return out
    EndIf
    Int count = SeverActionsNative.Native_Outfit_GetPresetCount(akActor)
    Int i = 0
    While i < count
        String name = SeverActionsNative.Native_Outfit_GetPresetNameAt(akActor, i)
        If name != "" && StringUtil.GetNthChar(name, 0) != "_"
            out = PapyrusUtil.PushString(out, name)
        EndIf
        i += 1
    EndWhile
    Return out
EndFunction

Int Function PresetItemCount(Actor akActor, String asPreset)
    {How many items a saved preset holds, 0 when not found (SeverActions_Outfit.GetPresetItemCount's body).}
    If !akActor || asPreset == ""
        Return 0
    EndIf
    Form[] items = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, asPreset)
    If items
        Return items.Length
    EndIf
    Return 0
EndFunction

String Function CompanionCombatStyle(Actor akActor)
    {A companion's combat style as FollowerManager.GetCombatStyle answers it: "no combat style" for None, no
     style, or the legacy "balanced" value old saves still hold.}
    If !akActor
        Return "no combat style"
    EndIf
    String s = SeverActionsNative.Native_GetCombatStyle(akActor)
    If s == "" || s == "balanced"
        Return "no combat style"
    EndIf
    Return s
EndFunction

Int Function JourneyCount()
    {How many player-ordered journeys are live, on the road or waiting (SeverActions_TravelCore.DoJourneyCount).}
    Actor[] js = SeverActionsNativeExt2.Travel_GetOrderedJourneyActors()
    If !js
        Return 0
    EndIf
    Return js.Length
EndFunction

Int Function EffectiveConfigMenuKey()
    {The config-menu key in force: the Authority row (synced with the settings file at session start, fed by
     every rebind). ConfigMenuKey is a display copy.}
    Int inForce = SeverActionsNativeExt2.Settings_GetInt("ConfigMenuKey")
    If inForce > 0
        return inForce
    EndIf
    return ConfigMenuKey
EndFunction

Int Function RowKeyCode(String asRow)
    {The code a keymap row draws: the Authority's, which the DLL's input sink matches (rule 17).}
    Return SeverActionsNativeExt2.Hotkey_GetCode(SeverActions_ModuleBase.VerbField(asRow, ROW_ID))
EndFunction

; --- VR controller chords -----------------------------------------------------

Int Function VRChordCodeAt(Int index)
    if index == 1
        return 1        ; B / Y
    elseif index == 2
        return 7        ; A / X
    elseif index == 3
        return 2        ; Grip
    elseif index == 4
        return 32       ; Stick click
    elseif index == 5
        return 33       ; Trigger
    elseif index == 6
        return 35       ; Touchpad
    endif
    return 0            ; None
EndFunction

Int Function VRChordIndexOf(Int code)
    if code == 1
        return 1
    elseif code == 7
        return 2
    elseif code == 2
        return 3
    elseif code == 32
        return 4
    elseif code == 33
        return 5
    elseif code == 35
        return 6
    endif
    return 0
EndFunction

String Function VRChordName(Int code)
    return MenuEntryAt("vrChordButton", VRChordIndexOf(code))
EndFunction

String Function VRHandName(Int hand)
    if hand < 0 || hand > 2
        hand = 0
    endif
    return MenuEntryAt("vrHand", hand)
EndFunction

Function SetVRChord(String settingKey, Int code, Int oid)
    {Write one chord half through the settings handler (global file and live rebind), then warn when the two
     chords collide: the wheel refuses to bind over the config menu's chord.}
    SeverActionsNativeExt2.Native_SettingsApply("settings", settingKey, code as String)
    if settingKey == "vrMenuHand" || settingKey == "vrWheelHand"
        SetMenuOptionValue(oid, VRHandName(code))
    else
        SetMenuOptionValue(oid, VRChordName(code))
    endif
    Int menuBtn = SeverActionsNativeExt2.Native_GetVRChord("menuButton")
    Int menuMod = SeverActionsNativeExt2.Native_GetVRChord("menuModifier")
    Int menuHand = SeverActionsNativeExt2.Native_GetVRChord("menuHand")
    Int wheelBtn = SeverActionsNativeExt2.Native_GetVRChord("wheelButton")
    Int wheelMod = SeverActionsNativeExt2.Native_GetVRChord("wheelModifier")
    Int wheelHand = SeverActionsNativeExt2.Native_GetVRChord("wheelHand")
    if settingKey == "vrMenuButton"
        menuBtn = code
    elseif settingKey == "vrMenuModifier"
        menuMod = code
    elseif settingKey == "vrMenuHand"
        menuHand = code
    elseif settingKey == "vrWheelButton"
        wheelBtn = code
    elseif settingKey == "vrWheelModifier"
        wheelMod = code
    elseif settingKey == "vrWheelHand"
        wheelHand = code
    endif
    Bool handsOverlap = (menuHand == 0 || wheelHand == 0 || menuHand == wheelHand)
    if menuBtn > 0 && menuBtn == wheelBtn && menuMod == wheelMod && handsOverlap
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("mcm.quickWheelChordMatches"))
    endif
EndFunction

String Function BoolToStr(Bool b)
    {A bool as the "true"/"false" text the settings surfaces expect.}
    If b
        Return "true"
    EndIf
    Return "false"
EndFunction

Int Function CombatStyleIndexFromString(String style)
    {Convert combat style string to dropdown index}
    If style == "balanced"
        Return 0
    ElseIf style == "aggressive"
        Return 1
    ElseIf style == "defensive"
        Return 2
    ElseIf style == "ranged"
        Return 3
    ElseIf style == "healer"
        Return 4
    ElseIf style == "coward"
        Return 5
    EndIf
    Return 0
EndFunction


; -----------------------------------------------------------------------------
; Safe-exit stubs (M-I, check 20): removed functions a saved frame can still call by name (F7). Never remove
; one; the registry is fomod/safe_exit_stubs.json.
; -----------------------------------------------------------------------------

Event OnGameReload()
    parent.OnGameReload()
    RunLoadDuties()
EndEvent

Function RunLoadDuties()
    ; M-I-STUB 3.9.14-beta25 (P4-04): the courier-letter registration runs from Travel.RegisterEvents (the
    ; travelcore provider's stage 1); the page rebuild SyncAllSettings carried is OnConfigOpen's.
EndFunction

Function PullCurrencySettings()
    ; M-I-STUB 3.9.14-beta25 (P4-04): the Economy page draws AllowConjuredGold from the Authority row; no load
    ; sync pulls it any more (SyncAllSettings, its only caller, is a stub).
EndFunction

Function PullNativeMenuKeys()
    ; M-I-STUB 3.9.14-beta25 (P4-04): the DLL syncs both menu keys with the settings file at session start and the
    ; Authority rows hold the keys in force; the Hotkeys page draws its copies from the rows.
EndFunction

Function SyncAllSettings()
    ; M-I-STUB 3.9.14-beta25 (P4-04, C8/R8): nothing calls this any more. The Settings Authority's per-save replay
    ; pushes dialogueAnimEnabled and outfitStabilityDelay (and furnitureAutoStandDistance since P2-08) natively,
    ; Init's M-X service writes the silence-chance and speaker-tag StorageUtil mirrors, the DLL syncs the menu keys
    ; and matches the hotkeys, and the display copies this used to pull are read from the Authority when drawn.
EndFunction

Function ApplyCurrencySettings()
    {Safe-exit stub: the currency settings replay through the Settings Authority.}
    ; M-I-STUB 3.9.14-beta25 (P3-08): the currency settings replay through the Settings Authority (P2-08, c98e4cb3)
EndFunction
