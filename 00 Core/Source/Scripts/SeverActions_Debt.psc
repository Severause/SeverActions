Scriptname SeverActions_Debt extends Quest
{Debt tracking system for SeverActions — gold obligations between actors.
 Data lives in the native DebtStore (cosave 'DEBT'), reached via
 SeverActionsNativeExt.Native_Debt_*. Prompt-context strings come from the
 debt_context / debt_complaints SkyrimNet decorators, which read live from
 DebtStore.
 This script holds: action _Execute handlers, TickDebts, the one-time
 StorageUtil → native migration, the PrismaUI clear-by-name handler,
 and the MCM detail formatters.}

; =============================================================================
; PROPERTIES
; =============================================================================

Bool Property DebugMode = false Auto
{Enable debug tracing for troubleshooting}

Bool Property EnableOverdueReminders = true Auto
{Fire persistent events when debts pass their due date}

Float Property OverdueGracePeriodHours = 24.0 Auto
{Game hours after due date before overdue events fire. Default 24 (1 game day).}

Float Property ReportThresholdHours = 72.0 Auto
{Game hours after due date before the creditor reports the debt to guards.
 Default 72 (3 game days). Only triggers when creditor is NOT near the player.}

Faction Property DebtorFaction Auto
{Faction for actors who currently owe money. Managed automatically — added when debt
 is created, removed when all debts are paid or forgiven.
 Create in CK with EditorID: SeverActions_DebtorFaction}

Faction Property CreditorFaction Auto
{Faction for actors who are currently owed money. Managed automatically — added when
 debt is created, removed when all debts are settled or forgiven.
 Create in CK with EditorID: SeverActions_CreditorFaction}

; =============================================================================
; CONSTANTS
; =============================================================================

String Property KEY_COUNT = "SeverDebt_Count" AutoReadOnly
{Legacy StorageUtil count key. Read once during one-time migration, then unset.}

String Property KEY_ACTOR_INFO = "SeverDebt_Info" AutoReadOnly
{Legacy per-actor summary StorageUtil key. Phase 4 stopped writing it;
 retained as a constant so the migration path can unset any pre-update
 leftovers in DrainLegacySummaryKeys().}

String Property KEY_COMPLAINTS = "SeverDebt_Complaints" AutoReadOnly
{Legacy per-player complaint StorageUtil key. Phase 4 stopped writing it;
 retained as a constant for the same DrainLegacySummaryKeys() cleanup.}

String Property KEY_MIGRATED = "SeverDebt_Migrated_V1" AutoReadOnly
{One-shot flag: when set to 1, Phase 3a migration has run. Stored on self.}

Float Property SECONDS_PER_GAME_HOUR = 3631.0 AutoReadOnly
Float Property SECONDS_PER_GAME_DAY = 87144.0 AutoReadOnly
{24 * SECONDS_PER_GAME_HOUR. Converts native game-days <-> legacy seconds units.}

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Debt] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    {Called on init and game load. Runs one-time StorageUtil → native migration
     on first invocation. Phase 4 retired the per-actor summary cache — the
     prompt templates now read via the debt_context / debt_complaints native
     decorators, so no rebuild step is needed on load.}
    DebugMsg("Maintenance - checking migration")
    MigrateFromStorageUtilIfNeeded()
    DrainLegacySummaryKeys()

    ; Register for PrismaUI debt clear events
    UnRegisterForModEvent("SeverActions_PrismaClearDebt")
    RegisterForModEvent("SeverActions_PrismaClearDebt", "OnPrismaClearDebt")
    ; Per-debt Pay / Forgive buttons (replaced the name-keyed Clear)
    UnRegisterForModEvent("SeverActions_PrismaPayDebt")
    RegisterForModEvent("SeverActions_PrismaPayDebt", "OnPrismaPayDebt")
    UnRegisterForModEvent("SeverActions_PrismaForgiveDebt")
    RegisterForModEvent("SeverActions_PrismaForgiveDebt", "OnPrismaForgiveDebt")
EndFunction

Function DrainLegacySummaryKeys()
    {Phase 4 cleanup — pre-Phase-4 saves left SeverDebt_Info on every actor
     and SeverDebt_Complaints on the player. They're harmless but stale; we
     unset the player's keys here once (the per-actor leftovers fade naturally
     as actors get touched).}
    Actor player = Game.GetPlayer()
    If player
        StorageUtil.UnsetStringValue(player, KEY_ACTOR_INFO)
        StorageUtil.UnsetStringValue(player, KEY_COMPLAINTS)
    EndIf
EndFunction

Event OnPrismaClearDebt(String eventName, String strArg, Float numArg, Form sender)
    {Clear all debts involving the named counterparty. Called from the PrismaUI
     "Clear" button.

     strArg encoding: "actorName|debtName". The PrismaUIActionHandler::SendModEvent
     helper unconditionally prepends "actorName|" to strArg (resolving the FormID
     it gets passed — 0 here, since clearDebt has no actor context — to a literal
     "0" via its int32 fallback). Splitting on "|" recovers the intended name.}
    Int pipePos = StringUtil.Find(strArg, "|")
    String targetName = strArg
    If pipePos >= 0
        targetName = StringUtil.Substring(strArg, pipePos + 1)
    EndIf
    DebugMsg("OnPrismaClearDebt: rawStrArg='" + strArg + "' parsedName='" + targetName + "'")
    If targetName == ""
        Return
    EndIf

    Int removed = SeverActionsNativeExt.Native_Debt_RemoveDebtsInvolvingName(targetName)
    DebugMsg("OnPrismaClearDebt: cleared " + removed + " debt(s) for '" + targetName + "'")
EndEvent

Int Function _ParseDebtIdFromPrisma(String strArg)
    {The PrismaUIActionHandler SendModEvent helper unconditionally prepends
     "actorName|" to strArg ("0|" here, no actor context) — recover the id
     after the pipe. Returns 0 on anything unparseable.}
    Int pipePos = StringUtil.Find(strArg, "|")
    String idStr = strArg
    If pipePos >= 0
        idStr = StringUtil.Substring(strArg, pipePos + 1)
    EndIf
    Return idStr as Int
EndFunction

Event OnPrismaPayDebt(String eventName, String strArg, Float numArg, Form sender)
    {Pay ONE debt the player owes, with real gold — the ledger's Pay button
     (replaced the name-keyed Clear, which wiped every debt involving the
     counterparty: meli report #3). Payment is capped at the gold the player
     carries; a shortfall pays what it can and leaves the rest owed. The
     creditor learns of it through the SAME debt_settled /
     debt_partial_payment events the in-dialogue payment path fires.}
    Int debtId = _ParseDebtIdFromPrisma(strArg)
    If debtId <= 0
        Return
    EndIf
    Actor player = Game.GetPlayer()
    Actor creditor = SeverActionsNativeExt.Native_Debt_GetCreditor(debtId)
    Actor debtor = SeverActionsNativeExt.Native_Debt_GetDebtor(debtId)
    If !creditor || debtor != player
        DebugMsg("OnPrismaPayDebt: id=" + debtId + " is not a debt the player owes")
        Return
    EndIf
    Int amount = SeverActionsNativeExt.Native_Debt_GetAmount(debtId)
    If amount <= 0
        Return
    EndIf
    Form gold = Game.GetForm(0x0000000F)
    Int goldOnHand = player.GetItemCount(gold)
    Int pay = amount
    If goldOnHand < pay
        pay = goldOnHand
    EndIf
    If pay <= 0
        Debug.Notification("You don't have the gold to pay " + creditor.GetDisplayName())
        Return
    EndIf
    player.RemoveItem(gold, pay, true)
    creditor.AddItem(gold, pay, true)
    Int newAmount = SeverActionsNativeExt.Native_Debt_ModifyAmount(debtId, -pay)
    If newAmount <= 0
        SeverActionsNativeExt.Native_Debt_Remove(debtId)
        SkyrimNetApi.RegisterEvent("debt_settled", player.GetDisplayName() + " paid off their " + amount + " gold debt with " + creditor.GetDisplayName(), creditor, player)
        Debug.Notification("Paid " + pay + " gold to " + creditor.GetDisplayName() + " — debt settled")
    Else
        SkyrimNetApi.RegisterEvent("debt_partial_payment", player.GetDisplayName() + " paid " + pay + " gold toward debt with " + creditor.GetDisplayName() + " (" + newAmount + " remaining)", creditor, player)
        Debug.Notification("Paid " + pay + " gold toward your debt to " + creditor.GetDisplayName() + " (" + newAmount + "g remaining)")
    EndIf
    SyncDebtFactionsForActor(creditor)
    SyncDebtFactionsForActor(player)
    DebugMsg("OnPrismaPayDebt: id=" + debtId + " paid=" + pay + " remaining=" + newAmount)
EndEvent

Event OnPrismaForgiveDebt(String eventName, String strArg, Float numArg, Form sender)
    {Cancel ONE debt owed TO the player — the ledger's Forgive button on the
     "Owed to you" column. No gold moves; the debtor learns of the mercy via
     the same debt_forgiven event the in-dialogue forgive action fires.}
    Int debtId = _ParseDebtIdFromPrisma(strArg)
    If debtId <= 0
        Return
    EndIf
    Actor player = Game.GetPlayer()
    Actor creditor = SeverActionsNativeExt.Native_Debt_GetCreditor(debtId)
    Actor debtor = SeverActionsNativeExt.Native_Debt_GetDebtor(debtId)
    If creditor != player || !debtor
        DebugMsg("OnPrismaForgiveDebt: id=" + debtId + " is not a debt owed to the player")
        Return
    EndIf
    Int amount = SeverActionsNativeExt.Native_Debt_GetAmount(debtId)
    SeverActionsNativeExt.Native_Debt_Remove(debtId)
    SkyrimNetApi.RegisterEvent("debt_forgiven", player.GetDisplayName() + " forgave " + debtor.GetDisplayName() + "'s debt of " + amount + " gold", player, debtor)
    Debug.Notification("Forgave " + debtor.GetDisplayName() + "'s debt of " + amount + " gold")
    SyncDebtFactionsForActor(player)
    SyncDebtFactionsForActor(debtor)
    DebugMsg("OnPrismaForgiveDebt: id=" + debtId + " amount=" + amount)
EndEvent

; =============================================================================
; MIGRATION (Phase 3a) — read legacy StorageUtil slots into the native store
; =============================================================================

Function MigrateFromStorageUtilIfNeeded()
    {One-shot migration from the SeverDebt_<i>_<field> StorageUtil layout to
     the native DebtStore. Idempotent — sets KEY_MIGRATED once it runs.

     Legacy time fields were "seconds equivalent" (gameDays * 24 * 3631); the
     native side stores game DAYS, so we divide by SECONDS_PER_GAME_DAY here.
     The legacy "RecurringInterval" was in HOURS; native uses days, so divide
     by 24.}
    If StorageUtil.GetIntValue(self, KEY_MIGRATED, 0) == 1
        Return
    EndIf

    Int oldCount = StorageUtil.GetIntValue(self, KEY_COUNT, 0)
    If oldCount <= 0
        ; Nothing to migrate — mark done and exit.
        StorageUtil.SetIntValue(self, KEY_MIGRATED, 1)
        StorageUtil.UnsetIntValue(self, KEY_COUNT)
        DebugMsg("Migration: no legacy debts found; marked migrated.")
        Return
    EndIf

    DebugMsg("Migration: porting " + oldCount + " legacy debts to native store")

    Int migrated = 0
    Int i = 0
    While i < oldCount
        Actor creditor = StorageUtil.GetFormValue(self, GetLegacyKey(i, "Creditor"), None) as Actor
        Actor debtor   = StorageUtil.GetFormValue(self, GetLegacyKey(i, "Debtor"), None) as Actor
        Int amount     = StorageUtil.GetIntValue(self, GetLegacyKey(i, "Amount"), 0)

        Bool slotMigrated = false
        Bool slotEmpty = !(creditor && debtor && amount > 0)

        If !slotEmpty
            String reason = StorageUtil.GetStringValue(self, GetLegacyKey(i, "Reason"), "")
            Float dueSec  = StorageUtil.GetFloatValue(self, GetLegacyKey(i, "DueTime"), 0.0)
            Int creditLim = StorageUtil.GetIntValue(self, GetLegacyKey(i, "CreditLimit"), 0)
            Bool isRecur  = StorageUtil.GetIntValue(self, GetLegacyKey(i, "IsRecurring"), 0) == 1
            Float intHrs  = StorageUtil.GetFloatValue(self, GetLegacyKey(i, "RecurringInterval"), 0.0)
            Int chargeAmt = StorageUtil.GetIntValue(self, GetLegacyKey(i, "RecurringCharge"), 0)
            Bool overdueN = StorageUtil.GetIntValue(self, GetLegacyKey(i, "OverdueNotified"), 0) == 1
            Bool reported = StorageUtil.GetIntValue(self, GetLegacyKey(i, "ReportedToGuards"), 0) == 1
            ; PR #85 review fix: preserve LastRecurred. Without this, every
            ; migrated recurring debt skips one charge cycle because the
            ; native Add() sets lastRecurredGameDays = now.
            Float lastRecSec = StorageUtil.GetFloatValue(self, GetLegacyKey(i, "LastRecurred"), 0.0)

            Float dueDays = 0.0
            If dueSec > 0.0
                dueDays = dueSec / SECONDS_PER_GAME_DAY
            EndIf
            Float intDays = 0.0
            If intHrs > 0.0
                intDays = intHrs / 24.0
            EndIf

            Int id = SeverActionsNativeExt.Native_Debt_Add( \
                creditor, debtor, amount, reason, dueDays, isRecur, intDays, creditLim, chargeAmt)
            If id > 0
                If overdueN
                    SeverActionsNativeExt.Native_Debt_SetOverdueNotified(id, true)
                EndIf
                If reported
                    SeverActionsNativeExt.Native_Debt_SetReportedToGuards(id, true)
                EndIf
                ; Restore the recurring cursor (only meaningful for isRecur,
                ; but harmless on non-recurring entries — MarkRecurred is a
                ; pure setter).
                If isRecur && lastRecSec > 0.0
                    SeverActionsNativeExt.Native_Debt_MarkRecurred(id, lastRecSec / SECONDS_PER_GAME_DAY)
                EndIf
                migrated += 1
                slotMigrated = true
            EndIf
        EndIf

        ; PR #85 review fix: only clear legacy keys when migration succeeded
        ; OR when the slot was already empty/unmigrateable. If Native_Debt_Add
        ; returned 0 on a slot with valid creditor/debtor/amount, the entry
        ; is preserved so a future migration pass can retry — better than
        ; silently wiping the data while no native entry exists.
        If slotMigrated || slotEmpty
            ClearLegacySlot(i)
        Else
            DebugMsg("Migration: slot " + i + " has valid data but native Add returned 0 - keeping legacy keys for retry")
        EndIf
        i += 1
    EndWhile

    ; Only mark the migration "done" if EVERY slot was either migrated or
    ; legitimately empty. Otherwise leave KEY_MIGRATED unset and KEY_COUNT
    ; intact so a future Maintenance pass can retry the holdouts.
    ; Count how many of the unmigrated were valid-but-failed (legacy keys still present)
    Int retryable = 0
    Int k = 0
    While k < oldCount
        If StorageUtil.GetFormValue(self, GetLegacyKey(k, "Creditor"), None) as Actor
            retryable += 1
        EndIf
        k += 1
    EndWhile

    If retryable == 0
        StorageUtil.UnsetIntValue(self, KEY_COUNT)
        StorageUtil.SetIntValue(self, KEY_MIGRATED, 1)
        DebugMsg("Migration: " + migrated + "/" + oldCount + " legacy debts migrated to native (complete)")
    Else
        DebugMsg("Migration: " + migrated + "/" + oldCount + " migrated; " + retryable + " kept for retry next Maintenance")
    EndIf
EndFunction

String Function GetLegacyKey(Int index, String suffix)
    {Build the legacy StorageUtil key — only used by migration.}
    Return "SeverDebt_" + index + "_" + suffix
EndFunction

Function ClearLegacySlot(Int index)
    {Wipe every legacy field at a slot, including the spurious "Created" key
     that the dead CreateOffScreenDebt path left behind on some saves.}
    StorageUtil.UnsetFormValue(self,   GetLegacyKey(index, "Creditor"))
    StorageUtil.UnsetFormValue(self,   GetLegacyKey(index, "Debtor"))
    StorageUtil.UnsetIntValue(self,    GetLegacyKey(index, "Amount"))
    StorageUtil.UnsetStringValue(self, GetLegacyKey(index, "Reason"))
    StorageUtil.UnsetFloatValue(self,  GetLegacyKey(index, "CreatedTime"))
    StorageUtil.UnsetFloatValue(self,  GetLegacyKey(index, "Created"))
    StorageUtil.UnsetFloatValue(self,  GetLegacyKey(index, "DueTime"))
    StorageUtil.UnsetIntValue(self,    GetLegacyKey(index, "CreditLimit"))
    StorageUtil.UnsetIntValue(self,    GetLegacyKey(index, "IsRecurring"))
    StorageUtil.UnsetFloatValue(self,  GetLegacyKey(index, "RecurringInterval"))
    StorageUtil.UnsetFloatValue(self,  GetLegacyKey(index, "LastRecurred"))
    StorageUtil.UnsetIntValue(self,    GetLegacyKey(index, "RecurringCharge"))
    StorageUtil.UnsetIntValue(self,    GetLegacyKey(index, "OverdueNotified"))
    StorageUtil.UnsetIntValue(self,    GetLegacyKey(index, "ReportedToGuards"))
EndFunction

; =============================================================================
; INTERNAL HELPERS
; =============================================================================

Float Function GetGameTimeInSeconds()
    {Convert current game time to the "seconds-equivalent" unit Papyrus has
     historically used here. Native stores game DAYS; this conversion keeps
     the public formatting helpers (FormatTimeRemaining etc.) source-compatible
     with PrismaUI's existing call sites.}
    Return Utility.GetCurrentGameTime() * SECONDS_PER_GAME_DAY
EndFunction

Float Function DaysFromSeconds(Float seconds)
    If seconds <= 0.0
        Return 0.0
    EndIf
    Return seconds / SECONDS_PER_GAME_DAY
EndFunction

Float Function SecondsFromDays(Float days)
    If days <= 0.0
        Return 0.0
    EndIf
    Return days * SECONDS_PER_GAME_DAY
EndFunction

Function DebugMsg(String msg)
    If DebugMode
        Debug.Trace("[SeverActions_Debt] " + msg)
    EndIf
EndFunction

; =============================================================================
; PUBLIC API — thin wrappers around the native store
; =============================================================================

Int Function GetDebtCount()
    Return SeverActionsNativeExt.Native_Debt_GetCount()
EndFunction

Int Function GetAmountOwed(Actor creditor, Actor debtor)
    {Total gold debtor owes creditor across all matching debts.}
    Return SeverActionsNativeExt.Native_Debt_SumOwed(creditor, debtor)
EndFunction

Int Function GetTotalOwedBy(Actor debtor)
    Return SeverActionsNativeExt.Native_Debt_SumOwedBy(debtor)
EndFunction

Int Function GetTotalOwedTo(Actor creditor)
    Return SeverActionsNativeExt.Native_Debt_SumOwedTo(creditor)
EndFunction

Bool Function HasAnyDebt(Actor akActor)
    Return SeverActionsNativeExt.Native_Debt_HasAnyDebt(akActor)
EndFunction

Bool Function IsCreditorOnAnyDebt(Actor akActor)
    Return SeverActionsNativeExt.Native_Debt_IsCreditorOnAnyDebt(akActor)
EndFunction

Int Function AddDebt(Actor creditor, Actor debtor, Int amount, String reason, Float dueTimeSeconds, Bool isRecurring, Float recurringIntervalHours, Int creditLimit = 0)
    {Create a new debt. Returns the assigned native id (>= 1), or 0 on failure.
     Converts legacy unit conventions at the boundary: dueTime is in
     seconds-equivalent; recurringInterval is in hours; native uses days.}
    If !creditor || !debtor || amount <= 0 || creditor == debtor
        DebugMsg("AddDebt rejected - invalid params")
        Return 0
    EndIf

    Float dueDays  = DaysFromSeconds(dueTimeSeconds)
    Float intDays  = 0.0
    If isRecurring && recurringIntervalHours > 0.0
        intDays = recurringIntervalHours / 24.0
    EndIf
    ; Pass 0 for recurringCharge — native defaults it to amount for recurring debts.
    Int id = SeverActionsNativeExt.Native_Debt_Add(creditor, debtor, amount, reason, dueDays, isRecurring, intDays, creditLimit, 0)
    If id > 0
        DebugMsg("AddDebt id=" + id + ": " + creditor.GetDisplayName() + " <- " + debtor.GetDisplayName() + " " + amount + "g (" + reason + ")")
        SyncDebtFactionsForActor(creditor)
        SyncDebtFactionsForActor(debtor)
    EndIf
    Return id
EndFunction

Bool Function RemoveDebt(Int debtId)
    {Remove a debt by native id. Returns true on success.}
    If debtId <= 0
        Return false
    EndIf
    Actor creditor = SeverActionsNativeExt.Native_Debt_GetCreditor(debtId)
    Actor debtor   = SeverActionsNativeExt.Native_Debt_GetDebtor(debtId)
    Bool removed = SeverActionsNativeExt.Native_Debt_Remove(debtId)
    If removed
        DebugMsg("RemoveDebt id=" + debtId)
        If creditor
            SyncDebtFactionsForActor(creditor)
        EndIf
        If debtor
            SyncDebtFactionsForActor(debtor)
        EndIf
    EndIf
    Return removed
EndFunction

Bool Function ModifyDebtAmount(Int debtId, Int deltaAmount)
    {Increase or decrease a debt's amount. Removes the debt if amount hits 0
     or below. Enforces credit limit on positive deltas — clamps at limit and
     fires the debt_credit_limit_reached event if reached. Returns false if
     the debt was already at limit (no change made) or the id is invalid.}
    If debtId <= 0
        Return false
    EndIf

    ; PR #85 review fix: snapshot creditor/debtor BEFORE the mutation. When
    ; newAmount drops to 0 the native side erases the entry, and a post-call
    ; Native_Debt_GetCreditor returns None — leaving faction membership stale
    ; unless we sync it from the snapshot taken here.
    Actor preCreditor = SeverActionsNativeExt.Native_Debt_GetCreditor(debtId)
    Actor preDebtor   = SeverActionsNativeExt.Native_Debt_GetDebtor(debtId)

    Int newAmount = SeverActionsNativeExt.Native_Debt_ModifyAmount(debtId, deltaAmount)
    If newAmount < 0
        ; Already at credit limit — fire the limit-reached event so the NPC reacts.
        If preCreditor && preDebtor
            String reason = SeverActionsNativeExt.Native_Debt_GetReason(debtId)
            Int creditLimit = SeverActionsNativeExt.Native_Debt_GetCreditLimit(debtId)
            SkyrimNetApi.RegisterShortLivedEvent( \
                "debt_" + debtId + "_limit", "debt_credit_limit_reached", \
                preDebtor.GetDisplayName() + " has reached the " + creditLimit + " gold credit limit with " + preCreditor.GetDisplayName() + " for " + reason, \
                "", 300000, preCreditor, preDebtor)
        EndIf
        DebugMsg("ModifyDebtAmount: credit limit reached on debt #" + debtId)
        Return false
    EndIf

    ; Rebuild summaries for BOTH parties using the pre-snapshot — covers the
    ; newAmount==0 case where the native entry is now erased.
    Actor creditor2 = preCreditor
    Actor debtor2   = preDebtor
    If creditor2
        SyncDebtFactionsForActor(creditor2)
    EndIf
    If debtor2
        SyncDebtFactionsForActor(debtor2)
    EndIf

    ; If we just hit the credit limit after this change, fire the event.
    If creditor2 && debtor2 && newAmount > 0
        Int creditLimit2 = SeverActionsNativeExt.Native_Debt_GetCreditLimit(debtId)
        If creditLimit2 > 0 && newAmount >= creditLimit2
            String reason2 = SeverActionsNativeExt.Native_Debt_GetReason(debtId)
            SkyrimNetApi.RegisterShortLivedEvent( \
                "debt_" + debtId + "_limit", "debt_credit_limit_reached", \
                debtor2.GetDisplayName() + " has reached the " + creditLimit2 + " gold credit limit with " + creditor2.GetDisplayName() + " for " + reason2, \
                "", 300000, creditor2, debtor2)
        EndIf
    EndIf

    Return true
EndFunction

; =============================================================================
; FORMATTING HELPERS — used by MCM, PrismaUI, and the prompt summary builders
; =============================================================================

String Function FormatRecurringRate(Int amount, Float intervalHours)
    {Format a recurring rate into a human-readable string like "50g/day" or "100g/week".}
    If intervalHours <= 0.0
        Return amount + "g/cycle"
    ElseIf intervalHours <= 24.0
        Return amount + "g/day"
    ElseIf intervalHours <= 168.0
        Int days = (intervalHours / 24.0) as Int
        If days == 7
            Return amount + "g/week"
        Else
            Return amount + "g/" + days + " days"
        EndIf
    Else
        Int days = (intervalHours / 24.0) as Int
        Return amount + "g/" + days + " days"
    EndIf
EndFunction

String Function FormatTimeRemaining(Float dueTime, Float currentTime)
    {Format the time remaining or overdue status for a debt.
     Both inputs are in the seconds-equivalent unit (gameDays * 87144).
     Returns "" for open-ended debts (dueTime == 0), "overdue" or "due in X days/hours".}
    If dueTime <= 0.0
        Return ""
    EndIf
    Float diffSeconds = dueTime - currentTime
    If diffSeconds <= 0.0
        Float overdueHours = (currentTime - dueTime) / SECONDS_PER_GAME_HOUR
        If overdueHours >= 48.0
            Int days = (overdueHours / 24.0) as Int
            Return "overdue " + days + " days"
        ElseIf overdueHours >= 24.0
            Return "overdue 1 day"
        Else
            Int hours = overdueHours as Int
            If hours < 1
                Return "overdue"
            Else
                Return "overdue " + hours + "h"
            EndIf
        EndIf
    Else
        Float remainHours = diffSeconds / SECONDS_PER_GAME_HOUR
        If remainHours >= 48.0
            Int days = (remainHours / 24.0) as Int
            Return "due in " + days + " days"
        ElseIf remainHours >= 24.0
            Return "due in 1 day"
        Else
            Int hours = remainHours as Int
            If hours < 1
                Return "due soon"
            Else
                Return "due in " + hours + "h"
            EndIf
        EndIf
    EndIf
EndFunction

; =============================================================================
; MCM SUMMARY API — used by the Currency MCM page
; =============================================================================

String[] Function GetPlayerDebtDetails(Bool abPlayerIsCreditor)
    {Formatted "Name: Xg (rate, reason, timeframe)" lines for the MCM.
     abPlayerIsCreditor=true  → debts owed TO the player (counterparty = debtor).
     abPlayerIsCreditor=false → debts the player owes  (counterparty = creditor).}
    Actor player = Game.GetPlayer()
    String[] result = PapyrusUtil.StringArray(0)
    Float currentTime = GetGameTimeInSeconds()
    Int[] ids = SeverActionsNativeExt.Native_Debt_GetAllIDs()
    Int n = ids.Length
    Int i = 0
    While i < n
        Int debtId = ids[i]
        Actor creditor = SeverActionsNativeExt.Native_Debt_GetCreditor(debtId)
        Actor debtor   = SeverActionsNativeExt.Native_Debt_GetDebtor(debtId)

        Actor counterparty = None
        If abPlayerIsCreditor && creditor == player && debtor
            counterparty = debtor
        ElseIf !abPlayerIsCreditor && debtor == player && creditor
            counterparty = creditor
        EndIf

        If counterparty
            Int amount     = SeverActionsNativeExt.Native_Debt_GetAmount(debtId)
            String reason  = SeverActionsNativeExt.Native_Debt_GetReason(debtId)
            Bool isRecur   = SeverActionsNativeExt.Native_Debt_GetIsRecurring(debtId)
            Float dueSec   = SecondsFromDays(SeverActionsNativeExt.Native_Debt_GetDueGameDays(debtId))
            String line = counterparty.GetDisplayName() + ": " + amount + "g"

            String details = ""
            If isRecur
                Int chargeAmount = SeverActionsNativeExt.Native_Debt_GetRecurringCharge(debtId)
                Float intervalHours = SeverActionsNativeExt.Native_Debt_GetIntervalDays(debtId) * 24.0
                If chargeAmount > 0
                    details = FormatRecurringRate(chargeAmount, intervalHours)
                Else
                    details = FormatRecurringRate(amount, intervalHours)
                EndIf
            EndIf
            If reason != ""
                If details != ""
                    details += ", " + reason
                Else
                    details = reason
                EndIf
            EndIf
            String timeStr = FormatTimeRemaining(dueSec, currentTime)
            If timeStr != ""
                If details != ""
                    details += ", " + timeStr
                Else
                    details = timeStr
                EndIf
            EndIf
            If details != ""
                line += " (" + details + ")"
            EndIf
            result = PapyrusUtil.PushString(result, line)
        EndIf
        i += 1
    EndWhile
    Return result
EndFunction

String[] Function GetPlayerOwesDetails()
    Return GetPlayerDebtDetails(false)
EndFunction

String[] Function GetOwedToPlayerDetails()
    Return GetPlayerDebtDetails(true)
EndFunction

; =============================================================================
; FACTION MEMBERSHIP SYNC
; =============================================================================
;
; The prompt templates read live via the debt_context / debt_complaints
; decorators, so no per-actor summary cache lives here. Faction membership
; management still does, because the YAML eligibility rules (CollectPayment /
; ForgiveDebt / AddToDebt) consult SeverActions_*Faction and adding/removing
; membership has side effects (package re-eval) we don't want native
; triggering implicitly.

Function SyncDebtFactionsForActor(Actor akActor)
    {Add/remove the actor from DebtorFaction / CreditorFaction so its current
     membership matches whether they're listed as debtor / creditor on any
     live debt. Only mutates when state differs from desired (Phase 1 A15).}
    If !akActor
        Return
    EndIf

    Bool isAnyCreditor = false
    Bool isAnyDebtor   = false
    Int[] ids = SeverActionsNativeExt.Native_Debt_GetAllIDs()
    Int n = ids.Length
    Int i = 0
    While i < n
        Int debtId = ids[i]
        Actor creditor = SeverActionsNativeExt.Native_Debt_GetCreditor(debtId)
        Actor debtor   = SeverActionsNativeExt.Native_Debt_GetDebtor(debtId)
        If creditor == akActor
            isAnyCreditor = true
        EndIf
        If debtor == akActor
            isAnyDebtor = true
        EndIf
        If isAnyCreditor && isAnyDebtor
            i = n ; both already known — short-circuit
        Else
            i += 1
        EndIf
    EndWhile

    If DebtorFaction
        Bool isInDebtor = akActor.IsInFaction(DebtorFaction)
        If isAnyDebtor && !isInDebtor
            akActor.AddToFaction(DebtorFaction)
        ElseIf !isAnyDebtor && isInDebtor
            akActor.RemoveFromFaction(DebtorFaction)
        EndIf
    EndIf
    If CreditorFaction
        Bool isInCreditor = akActor.IsInFaction(CreditorFaction)
        If isAnyCreditor && !isInCreditor
            akActor.AddToFaction(CreditorFaction)
        ElseIf !isAnyCreditor && isInCreditor
            akActor.RemoveFromFaction(CreditorFaction)
        EndIf
    EndIf
EndFunction

; =============================================================================
; TICK PROCESSING (called from FollowerManager OnUpdate)
; =============================================================================

Function TickDebts()
    {The recurring-charge / overdue / guard-report walk lives in the native
     DebtStore::Tick. Papyrus only drains the side-effect queue here, because
     SkyrimNet's PublicAPI doesn't expose event registration to C++ callers —
     only Papyrus can call SkyrimNetApi.Register*Event.

     Tick kinds (mirrors DebtStore::DebtEventKind):
       0 = Regular       — RegisterEvent(name, content, creditor, debtor)
       1 = ShortLived    — RegisterShortLivedEvent(key, name, content, "", ttl, creditor, debtor)
       2 = Persistent    — RegisterPersistentEvent(content, creditor, debtor)
       3 = Collection ask — DirectNarration(content, creditor, debtor)

     The native side converts MCM-tunable hours to days so the data layer
     stays unit-consistent (everything in Calendar days).}
    Float graceDays  = OverdueGracePeriodHours / 24.0
    Float reportDays = ReportThresholdHours / 24.0
    Int pending = SeverActionsNativeExt.Native_Debt_Tick(EnableOverdueReminders, graceDays, reportDays)
    If pending <= 0
        Return
    EndIf

    Int i = 0
    While i < pending
        Int kind        = SeverActionsNativeExt.Native_Debt_PendingEvent_Kind(i)
        String eventName = SeverActionsNativeExt.Native_Debt_PendingEvent_Name(i)
        String content   = SeverActionsNativeExt.Native_Debt_PendingEvent_Content(i)
        String dedupKey  = SeverActionsNativeExt.Native_Debt_PendingEvent_Key(i)
        Int ttlMs        = SeverActionsNativeExt.Native_Debt_PendingEvent_TTL(i)
        Actor creditor   = SeverActionsNativeExt.Native_Debt_PendingEvent_Creditor(i)
        Actor debtor     = SeverActionsNativeExt.Native_Debt_PendingEvent_Debtor(i)

        If kind == 1
            SkyrimNetApi.RegisterShortLivedEvent(dedupKey, eventName, content, "", ttlMs, creditor, debtor)
            DebugMsg("Tick short-lived: " + content)
        ElseIf kind == 2
            SkyrimNetApi.RegisterPersistentEvent(content, creditor, debtor)
            DebugMsg("Tick persistent: " + content)
        ElseIf kind == 3
            ; Collection ask (meli report #2): the creditor is loaded near the
            ; player with an overdue debt — DirectNarration makes them actually
            ; raise it, once per creditor per session (native-side latch).
            SkyrimNetApi.DirectNarration(content, creditor, debtor)
            DebugMsg("Tick collection ask: " + content)
        Else
            SkyrimNetApi.RegisterEvent(eventName, content, creditor, debtor)
            DebugMsg("Tick regular: " + content)
        EndIf

        i += 1
    EndWhile

    SeverActionsNativeExt.Native_Debt_ClearPendingEvents()
EndFunction

; =============================================================================
; ACTION EXECUTION FUNCTIONS (called by YAML actions)
; =============================================================================

Function CreateDebt_Execute(Actor akSpeaker, Actor akCreditor, Actor akDebtor, Int aiAmount, String asReason, Int aiDueDays, Int aiCreditLimit)
    {Create a one-time debt. Player confirmation via SkyMessage if player is involved.
     aiDueDays: days until due (0 = open-ended). aiCreditLimit: max gold (0 = unlimited).}
    If !akSpeaker || !akCreditor || !akDebtor || aiAmount <= 0
        DebugMsg("CreateDebt_Execute failed - invalid params")
        Return
    EndIf

    ; Duplicate prevention
    Int existingId = SeverActionsNativeExt.Native_Debt_FindByTriple(akCreditor, akDebtor, asReason)
    If existingId > 0
        DebugMsg("CreateDebt: Duplicate rejected - " + akDebtor.GetDisplayName() + " already owes " + akCreditor.GetDisplayName() + " for " + asReason)
        SkyrimNetApi.RegisterEvent("debt_create_failed", akDebtor.GetDisplayName() + " already has an outstanding debt to " + akCreditor.GetDisplayName() + " for " + asReason, akSpeaker, akCreditor)
        Return
    EndIf

    ; Calculate due time in game seconds (0 = no deadline)
    Float dueTimeSeconds = 0.0
    If aiDueDays > 0
        dueTimeSeconds = GetGameTimeInSeconds() + (aiDueDays as Float * SECONDS_PER_GAME_DAY)
    EndIf

    If aiCreditLimit > 0 && aiAmount > aiCreditLimit
        aiAmount = aiCreditLimit
    EndIf

    Actor player = Game.GetPlayer()

    String extraDetails = ""
    If aiDueDays > 0
        extraDetails += " Due in " + aiDueDays + " days."
    EndIf
    If aiCreditLimit > 0
        extraDetails += " Credit limit: " + aiCreditLimit + " gold."
    EndIf

    ; Non-pausing PrismaUI confirm first when the player is a party (public
    ; issue #16): the SkyMessage modal below does NOT render while the
    ; dialogue menu is up — the NPC verbally confirmed the debt while the
    ; confirm box silently never appeared, so nothing was recorded (reported
    ; for the player-as-creditor case; the debtor branch had the same hole).
    ; The overlay renders over dialogue exactly like the trade prompt.
    ; SkyMessage stays as the fallback when the prompt view is unavailable.
    If akDebtor == player || akCreditor == player
        If SeverActionsNativeExt2.PrismaUI_IsDebtPromptAvailable() && !SeverActionsNativeExt2.PrismaUI_IsDebtPromptOpen()
            Actor npcParty = akCreditor
            If akCreditor == player
                npcParty = akDebtor
            EndIf
            ; Lazy ModEvent registration — same rationale as the trade prompt's.
            RegisterForModEvent("SeverActions_DebtChoice", "OnDebtChoice")
            PendingDebtCreditor = akCreditor
            PendingDebtDebtor = akDebtor
            PendingDebtAmount = aiAmount
            PendingDebtReason = asReason
            PendingDebtDueSeconds = dueTimeSeconds
            PendingDebtCreditLimit = aiCreditLimit
            If SeverActionsNativeExt2.PrismaUI_OpenDebtPrompt(npcParty, aiAmount, asReason, aiDueDays, aiCreditLimit, akCreditor == player, 20000)
                ; Choice arrives asynchronously via OnDebtChoice.
                Return
            EndIf
            ; Open refused (another prompt up / view focus) — fall through to
            ; the legacy modal below.
        EndIf
    EndIf

    If akDebtor == player
        String promptText = akCreditor.GetDisplayName() + " claims you owe them " + aiAmount + " gold for " + asReason + "." + extraDetails + " Accept this debt?"
        String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")
        If result == "Yes"
            AddDebt(akCreditor, akDebtor, aiAmount, asReason, dueTimeSeconds, false, 0.0, aiCreditLimit)
            SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " now owes " + akCreditor.GetDisplayName() + " " + aiAmount + " gold for " + asReason, akCreditor, akDebtor)
        ElseIf result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " refused to accept the debt of " + aiAmount + " gold for " + asReason, akCreditor)
        Else
            DebugMsg("CreateDebt: Player silently declined debt to " + akCreditor.GetDisplayName())
        EndIf

    ElseIf akCreditor == player
        String promptText = akDebtor.GetDisplayName() + " acknowledges owing you " + aiAmount + " gold for " + asReason + "." + extraDetails + " Accept?"
        String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")
        If result == "Yes"
            AddDebt(akCreditor, akDebtor, aiAmount, asReason, dueTimeSeconds, false, 0.0, aiCreditLimit)
            SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " now owes " + akCreditor.GetDisplayName() + " " + aiAmount + " gold for " + asReason, akCreditor, akDebtor)
        ElseIf result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " declined to record the debt", akDebtor)
        Else
            DebugMsg("CreateDebt: Player silently declined recording debt from " + akDebtor.GetDisplayName())
        EndIf

    Else
        AddDebt(akCreditor, akDebtor, aiAmount, asReason, dueTimeSeconds, false, 0.0, aiCreditLimit)
        SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " now owes " + akCreditor.GetDisplayName() + " " + aiAmount + " gold for " + asReason, akCreditor, akDebtor)
    EndIf
EndFunction

; ── Debt confirm prompt state (public issue #16) ─────────────────────────────
; One pending debt at a time — matches the bridge's one-in-flight rule. The
; full pending terms are stashed HERE before opening; the ModEvent only
; carries the verdict (strArg) and the amount (numArg).
Actor PendingDebtCreditor
Actor PendingDebtDebtor
Int PendingDebtAmount
String PendingDebtReason
Float PendingDebtDueSeconds
Int PendingDebtCreditLimit

Event OnDebtChoice(String asEventName, String asChoice, Float afAmount, Form akSender)
    {The non-pausing debt prompt resolved. accept = record the debt exactly as
     the modal Yes did; deny = spoken refusal (DirectNarration so the NPC
     hears it); denySilent/dismiss = walk away, nothing recorded or said.}
    Actor cred = PendingDebtCreditor
    Actor debt = PendingDebtDebtor
    Int amount = PendingDebtAmount
    String reason = PendingDebtReason
    Float dueSeconds = PendingDebtDueSeconds
    Int creditLimit = PendingDebtCreditLimit
    PendingDebtCreditor = None
    PendingDebtDebtor = None

    If !cred || !debt || amount <= 0
        Return
    EndIf

    Actor player = Game.GetPlayer()
    If asChoice == "accept"
        AddDebt(cred, debt, amount, reason, dueSeconds, false, 0.0, creditLimit)
        SkyrimNetApi.RegisterEvent("debt_created", debt.GetDisplayName() + " now owes " + cred.GetDisplayName() + " " + amount + " gold for " + reason, cred, debt)
    ElseIf asChoice == "deny"
        If debt == player
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " refused to accept the debt of " + amount + " gold for " + reason, cred)
        Else
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " declined to record the debt", debt)
        EndIf
    Else
        DebugMsg("OnDebtChoice: silently declined (" + asChoice + ")")
    EndIf
EndEvent

Function CreateRecurringDebt_Execute(Actor akSpeaker, Actor akCreditor, Actor akDebtor, Int aiAmount, String asReason, Int aiIntervalDays, Int aiCreditLimit)
    {Create a recurring debt. interval = aiIntervalDays x 24 game hours.
     aiCreditLimit: max gold this recurring debt can accumulate to (0 = unlimited).}
    If !akSpeaker || !akCreditor || !akDebtor || aiAmount <= 0 || aiIntervalDays <= 0
        DebugMsg("CreateRecurringDebt_Execute failed - invalid params")
        Return
    EndIf

    Int existingId = SeverActionsNativeExt.Native_Debt_FindRecurringPair(akCreditor, akDebtor)
    If existingId > 0
        String existingReason = SeverActionsNativeExt.Native_Debt_GetReason(existingId)
        DebugMsg("CreateRecurringDebt: Duplicate rejected - recurring debt already exists between " + akCreditor.GetDisplayName() + " and " + akDebtor.GetDisplayName() + " for " + existingReason)
        SkyrimNetApi.RegisterEvent("debt_create_failed", akDebtor.GetDisplayName() + " already has a recurring payment arrangement with " + akCreditor.GetDisplayName() + " for " + existingReason, akSpeaker, akCreditor)
        Return
    EndIf

    Float intervalHours = aiIntervalDays as Float * 24.0
    Actor player = Game.GetPlayer()

    String intervalDesc
    If aiIntervalDays == 1
        intervalDesc = "daily"
    ElseIf aiIntervalDays == 7
        intervalDesc = "weekly"
    ElseIf aiIntervalDays == 30
        intervalDesc = "monthly"
    Else
        intervalDesc = "every " + aiIntervalDays + " days"
    EndIf

    String limitInfo = ""
    If aiCreditLimit > 0
        limitInfo = " Credit limit: " + aiCreditLimit + " gold."
    EndIf

    If akDebtor == player
        String promptText = akCreditor.GetDisplayName() + " wants you to pay " + aiAmount + " gold " + intervalDesc + " for " + asReason + "." + limitInfo + " Accept?"
        String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")
        If result == "Yes"
            AddDebt(akCreditor, akDebtor, aiAmount, asReason, 0.0, true, intervalHours, aiCreditLimit)
            SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " agreed to pay " + akCreditor.GetDisplayName() + " " + aiAmount + " gold " + intervalDesc + " for " + asReason, akCreditor, akDebtor)
        ElseIf result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " refused the recurring payment arrangement for " + asReason, akCreditor)
        Else
            DebugMsg("CreateRecurringDebt: Player silently declined recurring debt to " + akCreditor.GetDisplayName())
        EndIf

    ElseIf akCreditor == player
        String promptText = akDebtor.GetDisplayName() + " agrees to pay you " + aiAmount + " gold " + intervalDesc + " for " + asReason + "." + limitInfo + " Accept?"
        String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")
        If result == "Yes"
            AddDebt(akCreditor, akDebtor, aiAmount, asReason, 0.0, true, intervalHours, aiCreditLimit)
            SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " will pay " + akCreditor.GetDisplayName() + " " + aiAmount + " gold " + intervalDesc + " for " + asReason, akCreditor, akDebtor)
        ElseIf result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " declined the payment arrangement", akDebtor)
        Else
            DebugMsg("CreateRecurringDebt: Player silently declined recurring debt from " + akDebtor.GetDisplayName())
        EndIf

    Else
        AddDebt(akCreditor, akDebtor, aiAmount, asReason, 0.0, true, intervalHours, aiCreditLimit)
        SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " will pay " + akCreditor.GetDisplayName() + " " + aiAmount + " gold " + intervalDesc + " for " + asReason, akCreditor, akDebtor)
    EndIf
EndFunction

Function ReduceDebtByPayment(Actor akCollector, Actor akPayer, Int aiAmountPaid)
    {Reduce debts where akCollector is creditor and akPayer is debtor by the paid amount.
     Called automatically by CollectPayment after gold transfers.
     Removes debts that reach 0. Syncs debtor/creditor faction membership for both parties.}
    If !akCollector || !akPayer || aiAmountPaid <= 0
        Return
    EndIf

    Int totalOwed = SeverActionsNativeExt.Native_Debt_SumOwed(akCollector, akPayer)
    If totalOwed <= 0
        Return
    EndIf

    Int reduced = SeverActionsNativeExt.Native_Debt_ReduceForPayment(akCollector, akPayer, aiAmountPaid)

    If reduced >= totalOwed
        SkyrimNetApi.RegisterEvent("debt_settled", akPayer.GetDisplayName() + " paid off their " + totalOwed + " gold debt with " + akCollector.GetDisplayName(), akCollector, akPayer)
    ElseIf reduced > 0
        Int newTotal = totalOwed - reduced
        SkyrimNetApi.RegisterEvent("debt_partial_payment", akPayer.GetDisplayName() + " paid " + reduced + " gold toward debt with " + akCollector.GetDisplayName() + " (" + newTotal + " remaining)", akCollector, akPayer)
    EndIf

    SyncDebtFactionsForActor(akCollector)
    SyncDebtFactionsForActor(akPayer)
    DebugMsg("ReduceDebtByPayment: " + akPayer.GetDisplayName() + " paid " + reduced + "g toward debt with " + akCollector.GetDisplayName() + " (was " + totalOwed + "g)")
EndFunction

Function ReduceDebt_Execute(Actor akSpeaker, Actor akTarget, Int aiAmount)
    {The speaker knocks an arbitrary amount off what the target owes them, with
     NO gold changing hands - a favour repaid, work done, goods handed over, or
     plain generosity.

     Distinct from ForgiveDebt (all-or-nothing) and from a repayment (which
     reduces by what was actually paid). Reuses Native_Debt_ReduceForPayment
     because the arithmetic is identical - only the reason differs - so the
     ledger, the credit limits and the faction sync all behave exactly as they
     do for a real payment.}
    If !akSpeaker || !akTarget || aiAmount <= 0
        DebugMsg("ReduceDebt_Execute failed - invalid params")
        Return
    EndIf

    Int totalOwed = SeverActionsNativeExt.Native_Debt_SumOwed(akSpeaker, akTarget)
    If totalOwed <= 0
        DebugMsg("ReduceDebt: " + akTarget.GetDisplayName() + " doesn't owe " + akSpeaker.GetDisplayName() + " anything")
        Return
    EndIf

    ; Never write off more than is owed - a reduction past zero would read as
    ; the creditor now owing THEM, which is a different transaction entirely.
    Int amount = aiAmount
    If amount > totalOwed
        amount = totalOwed
    EndIf

    Int reduced = SeverActionsNativeExt.Native_Debt_ReduceForPayment(akSpeaker, akTarget, amount)
    Int remaining = SeverActionsNativeExt.Native_Debt_SumOwed(akSpeaker, akTarget)

    If remaining <= 0
        SkyrimNetApi.RegisterEvent("debt_reduced", akSpeaker.GetDisplayName() + " wrote off the last " + reduced + " gold of " + akTarget.GetDisplayName() + "'s debt - the tab is clear", akSpeaker, akTarget)
    Else
        SkyrimNetApi.RegisterEvent("debt_reduced", akSpeaker.GetDisplayName() + " knocked " + reduced + " gold off " + akTarget.GetDisplayName() + "'s debt - " + remaining + " gold still owed", akSpeaker, akTarget)
    EndIf
    DebugMsg("ReduceDebt: " + akSpeaker.GetDisplayName() + " reduced " + akTarget.GetDisplayName() + " by " + reduced + "g (" + remaining + "g left)")

    SyncDebtFactionsForActor(akSpeaker)
    SyncDebtFactionsForActor(akTarget)
EndFunction

Function ForgiveDebt_Execute(Actor akSpeaker, Actor akTarget)
    {Speaker forgives what target owes them. Speaker must be the creditor.}
    If !akSpeaker || !akTarget
        DebugMsg("ForgiveDebt_Execute failed - invalid params")
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int totalOwed = SeverActionsNativeExt.Native_Debt_SumOwed(akSpeaker, akTarget)

    If totalOwed <= 0
        DebugMsg("ForgiveDebt: " + akTarget.GetDisplayName() + " doesn't owe " + akSpeaker.GetDisplayName() + " anything")
        SkyrimNetApi.RegisterEvent("debt_forgive_failed", akTarget.GetDisplayName() + " doesn't owe " + akSpeaker.GetDisplayName() + " anything", akSpeaker, akTarget)
        Return
    EndIf

    If akSpeaker == player
        String promptText = "Forgive " + akTarget.GetDisplayName() + "'s debt of " + totalOwed + " gold?"
        String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")
        If result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " decided not to forgive the debt", akTarget)
            Return
        ElseIf result != "Yes"
            DebugMsg("ForgiveDebt: Player silently declined forgiving " + akTarget.GetDisplayName())
            Return
        EndIf
    EndIf

    ; Remove every speaker→target debt. Iterate via native ids — collect first
    ; so we mutate cleanly.
    Int[] ids = SeverActionsNativeExt.Native_Debt_GetAllIDs()
    Int n = ids.Length
    Int i = 0
    While i < n
        Int debtId = ids[i]
        Actor c = SeverActionsNativeExt.Native_Debt_GetCreditor(debtId)
        Actor d = SeverActionsNativeExt.Native_Debt_GetDebtor(debtId)
        If c == akSpeaker && d == akTarget
            SeverActionsNativeExt.Native_Debt_Remove(debtId)
        EndIf
        i += 1
    EndWhile

    SkyrimNetApi.RegisterEvent("debt_forgiven", akSpeaker.GetDisplayName() + " forgave " + akTarget.GetDisplayName() + "'s debt of " + totalOwed + " gold", akSpeaker, akTarget)
    DebugMsg("ForgiveDebt: " + akSpeaker.GetDisplayName() + " forgave " + totalOwed + "g from " + akTarget.GetDisplayName())

    SyncDebtFactionsForActor(akSpeaker)
    SyncDebtFactionsForActor(akTarget)
EndFunction

Function AddToDebt_Execute(Actor akSpeaker, Actor akTarget, Int aiAmount, String asReason)
    {Add charges to an existing debt where speaker is the creditor and target is the debtor.
     asReason helps match a specific debt; falls back to the first speaker→target debt found.
     Respects credit limits. Player confirmation if player is the debtor.}
    If !akSpeaker || !akTarget || aiAmount <= 0
        DebugMsg("AddToDebt_Execute failed - invalid params")
        Return
    EndIf

    Int debtId = 0
    If asReason != ""
        debtId = SeverActionsNativeExt.Native_Debt_FindByTriple(akSpeaker, akTarget, asReason)
    EndIf
    If debtId <= 0
        debtId = SeverActionsNativeExt.Native_Debt_FindFirstPair(akSpeaker, akTarget)
    EndIf

    If debtId <= 0
        DebugMsg("AddToDebt: No speaker->target debt found (" + akSpeaker.GetDisplayName() + " -> " + akTarget.GetDisplayName() + ")")
        SkyrimNetApi.RegisterEvent("debt_add_failed", akTarget.GetDisplayName() + " has no open debt with " + akSpeaker.GetDisplayName() + " to add charges to", akSpeaker, akTarget)
        Return
    EndIf

    String reason     = SeverActionsNativeExt.Native_Debt_GetReason(debtId)
    Int currentAmount = SeverActionsNativeExt.Native_Debt_GetAmount(debtId)
    Int creditLimit   = SeverActionsNativeExt.Native_Debt_GetCreditLimit(debtId)

    If creditLimit > 0 && currentAmount >= creditLimit
        DebugMsg("AddToDebt: Credit limit already reached on debt #" + debtId)
        SkyrimNetApi.RegisterShortLivedEvent( \
            "debt_" + debtId + "_limit", "debt_credit_limit_reached", \
            akTarget.GetDisplayName() + " has reached the " + creditLimit + " gold credit limit with " + akSpeaker.GetDisplayName() + " for " + reason, \
            "", 300000, akSpeaker, akTarget)
        Return
    EndIf

    Actor player = Game.GetPlayer()
    If akTarget == player
        String limitStr = ""
        If creditLimit > 0
            limitStr = " (limit: " + creditLimit + "g)"
        EndIf
        String promptText = akSpeaker.GetDisplayName() + " is adding " + aiAmount + " gold to your " + reason + " debt (currently " + currentAmount + "g" + limitStr + "). Accept?"
        String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")
        If result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " refused the additional charge of " + aiAmount + " gold on the " + reason, akSpeaker)
            Return
        ElseIf result != "Yes"
            DebugMsg("AddToDebt: Player silently declined additional charge")
            Return
        EndIf
    EndIf

    Bool success = ModifyDebtAmount(debtId, aiAmount)
    If success
        Int newAmount = SeverActionsNativeExt.Native_Debt_GetAmount(debtId)
        ; PR #175 review fix (M2): report the amount actually added, not the
        ; requested aiAmount — ModifyDebtAmount clamps to the credit limit, so
        ; "added X" would overstate when the charge was partially absorbed.
        Int actualAdded = newAmount - currentAmount
        SkyrimNetApi.RegisterEvent("debt_increased", actualAdded + " gold added to " + akTarget.GetDisplayName() + "'s debt with " + akSpeaker.GetDisplayName() + " for " + reason + " (now " + newAmount + "g)", akSpeaker, akTarget)
        DebugMsg("AddToDebt: +" + actualAdded + "g on debt #" + debtId + " (" + reason + "), now " + newAmount + "g")
    EndIf
EndFunction

; =============================================================================
; AUTO-GROWTH: called from GiveItem when items transfer between debtors/creditors
; =============================================================================

Function AutoAddToDebt(Actor akGiver, Actor akReceiver, Int goldValue)
    {Called from GiveItem_Execute when items are transferred between actors with a debt.
     If the giver is a creditor and receiver is a debtor, adds item gold value to the debt.
     Respects credit limits. No player confirmation — the item was already given.
     Fires short-lived event for NPC scene awareness.}
    If !akGiver || !akReceiver || goldValue <= 0
        Return
    EndIf

    Int debtId = SeverActionsNativeExt.Native_Debt_FindBestForGiveItem(akGiver, akReceiver)
    If debtId <= 0
        Return ; No matching debt
    EndIf

    Int currentAmount = SeverActionsNativeExt.Native_Debt_GetAmount(debtId)
    Int creditLimit   = SeverActionsNativeExt.Native_Debt_GetCreditLimit(debtId)

    If creditLimit > 0 && currentAmount >= creditLimit
        DebugMsg("AutoAddToDebt: Credit limit already reached, skipping auto-charge of " + goldValue + "g")
        Return
    EndIf

    Bool success = ModifyDebtAmount(debtId, goldValue)
    If success
        String reason = SeverActionsNativeExt.Native_Debt_GetReason(debtId)
        Int newAmount = SeverActionsNativeExt.Native_Debt_GetAmount(debtId)

        SkyrimNetApi.RegisterShortLivedEvent( \
            "debt_" + debtId + "_autocharge", "debt_auto_charged", \
            goldValue + " gold added to " + akReceiver.GetDisplayName() + "'s " + reason + " with " + akGiver.GetDisplayName() + " (now " + newAmount + "g)", \
            "", 300000, akGiver, akReceiver)
        DebugMsg("AutoAddToDebt: +" + goldValue + "g on debt #" + debtId + " (" + reason + "), now " + newAmount + "g")
    EndIf
EndFunction

; =============================================================================
; ELIGIBILITY FUNCTIONS (called by YAML or internally)
; =============================================================================

Bool Function CreateDebt_IsEligible(Actor akSpeaker)
    If !akSpeaker || akSpeaker.IsDead() || akSpeaker.IsInCombat()
        Return false
    EndIf
    Return true
EndFunction

Bool Function ForgiveDebt_IsEligible(Actor akSpeaker)
    If !akSpeaker || akSpeaker.IsDead() || akSpeaker.IsInCombat()
        Return false
    EndIf
    Return IsCreditorOnAnyDebt(akSpeaker)
EndFunction

; =============================================================================
; UTILITY — GetInstance for Global access from other scripts
; =============================================================================

SeverActions_Debt Function GetInstance() Global
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Debt
EndFunction
