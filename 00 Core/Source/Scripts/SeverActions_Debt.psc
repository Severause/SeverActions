Scriptname SeverActions_Debt extends Quest
{Gold debts between actors. The data lives in the native DebtStore (cosave 'DEBT',
 SeverActionsNativeExt.Native_Debt_*); prompts read it through the debt_context /
 debt_complaints decorators. This script holds the action _Execute handlers, the tick
 drain, the debt confirm overlay, the ledger's Pay / Forgive handlers and the one-time
 StorageUtil -> native migration.}

; ===== PROPERTIES =====

Bool Property DebugMode = false Auto
{Trace debug messages to the Papyrus log.}

Bool Property EnableOverdueReminders = true Auto
{Fire the overdue event and the creditor's collection ask once a debt is past due
 (the guard report ignores this switch).}

Float Property OverdueGracePeriodHours = 24.0 Auto
{Game hours past the due date before the overdue event fires.}

Float Property ReportThresholdHours = 72.0 Auto
{Game hours past the due date before the creditor reports the player's debt to the
 guards; filed only while the creditor is not loaded.}

Faction Property DebtorFaction Auto
{SeverActions_DebtorFaction: held while the actor owes on any debt (SyncDebtFactionsForActor).}

Faction Property CreditorFaction Auto
{SeverActions_CreditorFaction: held while the actor is owed on any debt (SyncDebtFactionsForActor).}

; ===== CONSTANTS =====

String Property KEY_COUNT = "SeverDebt_Count" AutoReadOnly
{Legacy StorageUtil debt count; read by the migration, then unset.}

String Property KEY_ACTOR_INFO = "SeverDebt_Info" AutoReadOnly
{Legacy per-actor summary key, no longer written; only unset (DrainLegacySummaryKeys).}

String Property KEY_COMPLAINTS = "SeverDebt_Complaints" AutoReadOnly
{Legacy player complaint key, no longer written; only unset (DrainLegacySummaryKeys).}

String Property KEY_MIGRATED = "SeverDebt_Migrated_V1" AutoReadOnly
{Set to 1 on self once the StorageUtil -> native migration has completed.}

Float Property SECONDS_PER_GAME_HOUR = 3631.0 AutoReadOnly
Float Property SECONDS_PER_GAME_DAY = 87144.0 AutoReadOnly
{24 * SECONDS_PER_GAME_HOUR: the legacy seconds-equivalent unit per native game day.}

; ===== INITIALIZATION =====

Event OnInit()
    Debug.Trace("[SeverActions_Debt] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    {Runs on init and on every load (the economy provider's stage 1): the one-time
     migration, the ledger button registrations and the tick chain.}
    DebugMsg("Maintenance - checking migration")
    MigrateFromStorageUtilIfNeeded()
    DrainLegacySummaryKeys()

    ; The ledger's per-debt Pay / Forgive buttons. The old name-keyed Clear has
    ; no sender any more, so its registration is dropped.
    UnRegisterForModEvent("SeverActions_PrismaClearDebt")
    UnRegisterForModEvent("SeverActions_MagelightPayDebt")
    RegisterForModEvent("SeverActions_MagelightPayDebt", "OnPrismaPayDebt")
    UnRegisterForModEvent("SeverActions_MagelightForgiveDebt")
    RegisterForModEvent("SeverActions_MagelightForgiveDebt", "OnPrismaForgiveDebt")

    ; Short first wake so the chain acknowledges inside Init's K4 watchdog window;
    ; then every two minutes (DebtStore::Tick is game-time based).
    ChronoArm(20.0)
EndFunction

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick (unique event and callback names).
     Re-arming replaces the pending tick; ticks do not survive a load, so Maintenance
     re-arms.}
    RegisterForModEvent("SeverActions_Tick_Debt", "OnChronoTick_Debt")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_Debt", afSeconds)
EndFunction

Bool _debtTickInFlight = False
Float _debtTickInFlightSince = 0.0

Event OnChronoTick_Debt(String eventName, String strArg, Float numArg, Form sender)
    ; Re-arm FIRST: the Request is the chronometer's acknowledgement, so its
    ; at-least-once heal never re-sends this wake mid-drain. The in-flight guard (real-time ceiling) keeps
    ; DebtStore::Tick single-caller, as its contract requires, when wakes stack up
    ; after a long menu pause.
    ChronoArm(120.0)
    Float now = Utility.GetCurrentRealTime()
    If _debtTickInFlight && (now - _debtTickInFlightSince) < 120.0
        Return
    EndIf
    _debtTickInFlight = True
    _debtTickInFlightSince = now
    TickDebts()
    _debtTickInFlight = False
EndEvent

Function DrainLegacySummaryKeys()
    {Unset the stale legacy summary keys on the player. Other actors' leftover
     SeverDebt_Info keys are harmless and left alone.}
    Actor player = Game.GetPlayer()
    If player
        StorageUtil.UnsetStringValue(player, KEY_ACTOR_INFO)
        StorageUtil.UnsetStringValue(player, KEY_COMPLAINTS)
    EndIf
EndFunction

Int Function _ParseDebtIdFromPrisma(String strArg)
    {The debt id from a ledger button's strArg: MagelightActionHandler's SendModEvent
     always prepends "actorName|" ("0|" here). Returns 0 when unparseable.}
    Int pipePos = StringUtil.Find(strArg, "|")
    String idStr = strArg
    If pipePos >= 0
        idStr = StringUtil.Substring(strArg, pipePos + 1)
    EndIf
    Return idStr as Int
EndFunction

Event OnPrismaPayDebt(String eventName, String strArg, Float numArg, Form sender)
    {The ledger's Pay button: pay ONE debt the player owes with real gold, capped at
     what the player carries (a shortfall leaves the rest owed). Fires the same
     debt_settled / debt_partial_payment events as the in-dialogue payment.}
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
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("debt.youDontHaveGold", ("" + creditor.GetDisplayName())))
        Return
    EndIf
    player.RemoveItem(gold, pay, true)
    creditor.AddItem(gold, pay, true)
    Int newAmount = SeverActionsNativeExt.Native_Debt_ModifyAmount(debtId, -pay)
    If newAmount <= 0
        SeverActionsNativeExt.Native_Debt_Remove(debtId)
        SkyrimNetApi.RegisterEvent("debt_settled", player.GetDisplayName() + " paid off their " + amount + " gold debt with " + creditor.GetDisplayName(), creditor, player)
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("debt.paidGoldToSettled", ("" + pay), ("" + creditor.GetDisplayName())))
    Else
        SkyrimNetApi.RegisterEvent("debt_partial_payment", player.GetDisplayName() + " paid " + pay + " gold toward debt with " + creditor.GetDisplayName() + " (" + newAmount + " remaining)", creditor, player)
        Debug.Notification("Paid " + pay + " gold toward your debt to " + creditor.GetDisplayName() + " (" + newAmount + "g remaining)")
    EndIf
    SyncDebtFactionsForActor(creditor)
    SyncDebtFactionsForActor(player)
    DebugMsg("OnPrismaPayDebt: id=" + debtId + " paid=" + pay + " remaining=" + newAmount)
EndEvent

Event OnPrismaForgiveDebt(String eventName, String strArg, Float numArg, Form sender)
    {The ledger's Forgive button: cancel ONE debt owed to the player. No gold moves;
     fires the same debt_forgiven event as the in-dialogue forgive.}
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
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("debt.forgaveDebtOf", ("" + debtor.GetDisplayName()), ("" + amount)))
    SyncDebtFactionsForActor(player)
    SyncDebtFactionsForActor(debtor)
    DebugMsg("OnPrismaForgiveDebt: id=" + debtId + " amount=" + amount)
EndEvent

; ===== MIGRATION: legacy StorageUtil slots -> the native store =====

Function MigrateFromStorageUtilIfNeeded()
    {Port the legacy SeverDebt_<i>_<field> StorageUtil slots into the native
     DebtStore; sets KEY_MIGRATED once every slot is ported. Legacy times are in
     seconds-equivalent and RecurringInterval in hours; native stores game days.}
    If StorageUtil.GetIntValue(self, KEY_MIGRATED, 0) == 1
        Return
    EndIf

    Int oldCount = StorageUtil.GetIntValue(self, KEY_COUNT, 0)
    If oldCount <= 0
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
            ; Carry LastRecurred over: native Add() sets it to now, which would
            ; skip one charge cycle.
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
                If isRecur && lastRecSec > 0.0
                    SeverActionsNativeExt.Native_Debt_MarkRecurred(id, lastRecSec / SECONDS_PER_GAME_DAY)
                EndIf
                migrated += 1
                slotMigrated = true
            EndIf
        EndIf

        ; Clear a slot only once ported or when it holds nothing portable; a valid
        ; slot whose native Add failed keeps its keys for a retry.
        If slotMigrated || slotEmpty
            ClearLegacySlot(i)
        Else
            DebugMsg("Migration: slot " + i + " has valid data but native Add returned 0 - keeping legacy keys for retry")
        EndIf
        i += 1
    EndWhile

    ; Mark done only when no slot kept its keys; otherwise KEY_COUNT stays and the
    ; next Maintenance retries the holdouts.
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
    {The legacy StorageUtil key for slot index's field (migration only).}
    Return "SeverDebt_" + index + "_" + suffix
EndFunction

Function ClearLegacySlot(Int index)
    {Unset every legacy field of a slot, including the stray "Created" key some
     saves carry.}
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

; ===== INTERNAL HELPERS =====

Float Function GetGameTimeInSeconds()
    {The current game time in the legacy seconds-equivalent unit the Papyrus
     helpers take (native stores game days).}
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

; ===== PUBLIC API: thin wrappers around the native store =====

Int Function GetDebtCount()
    Return SeverActionsNativeExt.Native_Debt_GetCount()
EndFunction

Int Function GetAmountOwed(Actor creditor, Actor debtor)
    {Total gold debtor owes creditor across all matching debts.}
    Return SeverActionsNativeExt.Native_Debt_SumOwed(creditor, debtor)
EndFunction

Int Function GetTotalOwedBy(Actor debtor)
    {Total gold debtor owes across all their debts. No SeverActions caller (the MCM
     reads Native_Debt_SumOwedBy); kept for old saves' frames and third parties.}
    Return SeverActionsNativeExt.Native_Debt_SumOwedBy(debtor)
EndFunction

Int Function GetTotalOwedTo(Actor creditor)
    {Total gold owed to creditor across all their debts. No SeverActions caller (the
     MCM reads Native_Debt_SumOwedTo); kept for old saves' frames and third parties.}
    Return SeverActionsNativeExt.Native_Debt_SumOwedTo(creditor)
EndFunction

Bool Function HasAnyDebt(Actor akActor)
    Return SeverActionsNativeExt.Native_Debt_HasAnyDebt(akActor)
EndFunction

Bool Function IsCreditorOnAnyDebt(Actor akActor)
    Return SeverActionsNativeExt.Native_Debt_IsCreditorOnAnyDebt(akActor)
EndFunction

Int Function AddDebt(Actor creditor, Actor debtor, Int amount, String reason, Float dueTimeSeconds, Bool isRecurring, Float recurringIntervalHours, Int creditLimit = 0)
    {Create a debt and sync both parties' factions. Returns the native id (>= 1) or 0.
     dueTimeSeconds is an absolute seconds-equivalent time (0 = open-ended);
     recurringIntervalHours is in game hours.}
    If !creditor || !debtor || amount <= 0 || creditor == debtor
        DebugMsg("AddDebt rejected - invalid params")
        Return 0
    EndIf

    Float dueDays  = DaysFromSeconds(dueTimeSeconds)
    Float intDays  = 0.0
    If isRecurring && recurringIntervalHours > 0.0
        intDays = recurringIntervalHours / 24.0
    EndIf
    ; recurringCharge 0: native uses the amount for a recurring debt.
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
    {Change a debt's amount by deltaAmount (native removes it at 0 or below and clamps
     a rise at the credit limit) and fire debt_credit_limit_reached when the limit is
     hit. Returns false for id <= 0 or a debt already at its limit (no change); an
     unknown id returns true, since native answers 0 for it.}
    If debtId <= 0
        Return false
    EndIf

    ; Snapshot the parties BEFORE the change: a debt that reaches 0 is erased, and
    ; the factions must still be synced for both.
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

    Actor creditor2 = preCreditor
    Actor debtor2   = preDebtor
    If creditor2
        SyncDebtFactionsForActor(creditor2)
    EndIf
    If debtor2
        SyncDebtFactionsForActor(debtor2)
    EndIf

    ; This change reached the limit.
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

; ===== FORMATTING HELPERS =====

String Function FormatRecurringRate(Int amount, Float intervalHours)
    {A recurring rate as text: "50g/day", "100g/week", "30g/3 days".}
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
    {A debt's deadline as text ("due in 2 days", "overdue 5h", ...); "" when open-ended
     (dueTime 0). Both inputs are seconds-equivalent (game days * SECONDS_PER_GAME_DAY).}
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

; ===== SUMMARY API (no SeverActions caller; kept for old saves and third parties) =====

String[] Function GetPlayerDebtDetails(Bool abPlayerIsCreditor)
    {One "Name: Xg (rate, reason, timeframe)" line per player debt: owed TO the player
     when abPlayerIsCreditor, else owed BY the player. The MCM now reads the same format
     from SeverActionsNativeExt2.Native_Debt_GetPlayerViewLines.}
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
    {GetPlayerDebtDetails(false).}
    Return GetPlayerDebtDetails(false)
EndFunction

String[] Function GetOwedToPlayerDetails()
    {GetPlayerDebtDetails(true).}
    Return GetPlayerDebtDetails(true)
EndFunction

; ===== FACTION MEMBERSHIP SYNC =====
; SeverActions_DebtorFaction / _CreditorFaction mirror the debt store for readers outside SA; no
; shipped YAML gates on them (the debt actions read sever_is_creditor / sever_is_debtor by FormID).
; Kept in Papyrus, not natively, because membership changes have side effects (package re-evaluation).

Function SyncDebtFactionsForActor(Actor akActor)
    {Put the actor in DebtorFaction / CreditorFaction exactly while they are a
     debtor / creditor on a live debt; changes membership only when it differs.}
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
            i = n ; both known: stop
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

; ===== TICK PROCESSING (OnChronoTick_Debt) =====

Function TickDebts()
    {Run the native DebtStore::Tick (recurring charges, overdue, collection ask,
     guard report) and drain its event queue: SkyrimNet's event registration is
     Papyrus-only. The kinds mirror DebtStore::DebtEventKind: 0 RegisterEvent,
     1 RegisterShortLivedEvent, 2 RegisterPersistentEvent, 3 DirectNarration.
     The hour settings are passed to native in game days.}
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
            ; Collection ask: a creditor the player owes past due, loaded near the
            ; player, raises the debt; native latches it once per creditor per session.
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

; ===== ACTION EXECUTION (YAML actions) =====

Function CreateDebt_Execute(Actor akSpeaker, Actor akCreditor, Actor akDebtor, Int aiAmount, String asReason, Int aiDueDays, Int aiCreditLimit)
    {Create a one-time debt; the player confirms when they are a party.
     aiDueDays: days until due (0 = open-ended). aiCreditLimit: max gold (0 = unlimited).}
    If !akSpeaker || !akCreditor || !akDebtor || aiAmount <= 0
        DebugMsg("CreateDebt_Execute failed - invalid params")
        Return
    EndIf

    Int existingId = SeverActionsNativeExt.Native_Debt_FindByTriple(akCreditor, akDebtor, asReason)
    If existingId > 0
        DebugMsg("CreateDebt: Duplicate rejected - " + akDebtor.GetDisplayName() + " already owes " + akCreditor.GetDisplayName() + " for " + asReason)
        SkyrimNetApi.RegisterEvent("debt_create_failed", akDebtor.GetDisplayName() + " already has an outstanding debt to " + akCreditor.GetDisplayName() + " for " + asReason, akSpeaker, akCreditor)
        Return
    EndIf

    ; Seconds-equivalent due time (0 = no deadline).
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

    ; The non-pausing overlay first when the player is a party: the SkyMessage
    ; modal below does not render while the dialogue menu is up, so the debt would
    ; go unrecorded. The modal stays as the fallback when the overlay cannot open.
    If akDebtor == player || akCreditor == player
        If _OpenDebtConfirm(DEBT_CONFIRM_CREATE, akCreditor, akDebtor, aiAmount, asReason, aiDueDays, aiCreditLimit, 0, dueTimeSeconds, "", 0)
            ; Choice arrives asynchronously via OnDebtChoice.
            Return
        EndIf
    EndIf

    If akDebtor == player
        String promptText = akCreditor.GetDisplayName() + " claims you owe them " + aiAmount + " gold for " + asReason + "." + extraDetails + " Accept this debt?"
        String result = ""
        If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
            result = SeverActions_SkyMessageLib.Show(promptText, "Yes", "No", "No (Silent)")
        EndIf
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
        String result = ""
        If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
            result = SeverActions_SkyMessageLib.Show(promptText, "Yes", "No", "No (Silent)")
        EndIf
        If result == "Yes"
            AddDebt(akCreditor, akDebtor, aiAmount, asReason, dueTimeSeconds, false, 0.0, aiCreditLimit)
            SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " now owes " + akCreditor.GetDisplayName() + " " + aiAmount + " gold for " + asReason, akCreditor, akDebtor)
        ElseIf result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " waves it off - " + akDebtor.GetDisplayName() + " owes them nothing for " + asReason + ".", akDebtor)
        Else
            DebugMsg("CreateDebt: Player silently declined recording debt from " + akDebtor.GetDisplayName())
        EndIf

    Else
        AddDebt(akCreditor, akDebtor, aiAmount, asReason, dueTimeSeconds, false, 0.0, aiCreditLimit)
        SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " now owes " + akCreditor.GetDisplayName() + " " + aiAmount + " gold for " + asReason, akCreditor, akDebtor)
    EndIf
EndFunction

; ----- Debt confirm overlay state -----
; One pending confirm at a time (the bridge allows one in flight), shared by
; CreateDebt, CreateRecurringDebt, ForgiveDebt and AddToDebt. The terms are
; stashed here; the ModEvent carries only the verdict (strArg), the amount
; (numArg) and the NPC (sender).
Actor PendingDebtCreditor
Actor PendingDebtDebtor
Int PendingDebtAmount
String PendingDebtReason
Float PendingDebtDueSeconds
Int PendingDebtCreditLimit
; A DEBT_CONFIRM_* value; 0 (CREATE) is also what an older save's pending confirm reads as.
Int PendingDebtMode
Float PendingDebtIntervalHours
String PendingDebtIntervalDesc
Int PendingDebtId

Int Property DEBT_CONFIRM_CREATE    = 0 AutoReadOnly
Int Property DEBT_CONFIRM_RECURRING = 1 AutoReadOnly
Int Property DEBT_CONFIRM_FORGIVE   = 2 AutoReadOnly
Int Property DEBT_CONFIRM_ADD       = 3 AutoReadOnly

Bool Function _OpenDebtConfirm(Int aiMode, Actor akCreditor, Actor akDebtor, Int aiAmount, String asReason, Int aiDays, Int aiCreditLimit, Int aiCurrentAmount, Float afTimeValue, String asIntervalDesc, Int aiDebtId)
    {Open the non-pausing confirm for a DEBT_CONFIRM_* operation and stash its terms
     for OnDebtChoice. Returns false, and the caller falls back to its SkyMessage
     modal, when the overlay is unavailable or already open (stash untouched) or the
     bridge refuses the open.
     aiDays: due days (create) or interval days (recurring). aiCurrentAmount: the
     debt's total (add). afTimeValue: seconds-equivalent due time (create) or interval
     hours (recurring). aiDebtId: the debt being charged (add). Unused ones are 0.}
    If !SeverActionsNativeExt2.Magelight_IsDebtPromptAvailable() || SeverActionsNativeExt2.Magelight_IsDebtPromptOpen()
        Return false
    EndIf
    Actor player = Game.GetPlayer()
    Actor npcParty = akCreditor
    If akCreditor == player
        npcParty = akDebtor
    EndIf
    ; Registered on demand (SKSE dedups the call; the registration persists in the save).
    RegisterForModEvent("SeverActions_DebtChoice", "OnDebtChoice")
    ; Stash BEFORE opening: in VR immersive mode the bridge resolves the confirm
    ; without showing it.
    PendingDebtMode = aiMode
    PendingDebtCreditor = akCreditor
    PendingDebtDebtor = akDebtor
    PendingDebtAmount = aiAmount
    PendingDebtReason = asReason
    PendingDebtCreditLimit = aiCreditLimit
    PendingDebtDueSeconds = 0.0
    PendingDebtIntervalHours = 0.0
    If aiMode == DEBT_CONFIRM_CREATE
        PendingDebtDueSeconds = afTimeValue
    ElseIf aiMode == DEBT_CONFIRM_RECURRING
        PendingDebtIntervalHours = afTimeValue
    EndIf
    PendingDebtIntervalDesc = asIntervalDesc
    PendingDebtId = aiDebtId

    If aiMode == DEBT_CONFIRM_CREATE
        Return SeverActionsNativeExt2.Magelight_OpenDebtPrompt(npcParty, aiAmount, asReason, aiDays, aiCreditLimit, akCreditor == player, 20000)
    EndIf
    String modeName = "add"
    If aiMode == DEBT_CONFIRM_RECURRING
        modeName = "recurring"
    ElseIf aiMode == DEBT_CONFIRM_FORGIVE
        modeName = "forgive"
    EndIf
    Return SeverActionsNativeExt2.Magelight_OpenDebtPromptMode(npcParty, modeName, aiAmount, asReason, aiDays, aiCreditLimit, aiCurrentAmount, akCreditor == player, 20000)
EndFunction

Event OnDebtChoice(String asEventName, String asChoice, Float afAmount, Form akSender)
    {The debt overlay resolved. accept = commit the stashed operation as the modal's
     Yes does; deny = a refusal the NPC hears (DirectNarration); anything else
     (denySilent, dismiss) = nothing recorded or said.}
    Int mode = PendingDebtMode
    Actor cred = PendingDebtCreditor
    Actor debt = PendingDebtDebtor
    Int amount = PendingDebtAmount

    If !cred || !debt || amount <= 0
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Actor npcParty = cred
    If cred == player
        npcParty = debt
    EndIf
    ; The bridge closes the overlay before this event arrives, so a new confirm can
    ; re-stash in between: a verdict whose NPC or amount does not match the stash
    ; belongs to the replaced confirm and is dropped.
    If (akSender && akSender != npcParty as Form) || (afAmount as Int) != amount
        DebugMsg("OnDebtChoice: '" + asChoice + "' verdict does not match the pending confirm - ignored")
        Return
    EndIf

    String reason = PendingDebtReason
    Float dueSeconds = PendingDebtDueSeconds
    Int creditLimit = PendingDebtCreditLimit
    Float intervalHours = PendingDebtIntervalHours
    String intervalDesc = PendingDebtIntervalDesc
    Int debtId = PendingDebtId
    PendingDebtCreditor = None
    PendingDebtDebtor = None
    PendingDebtMode = DEBT_CONFIRM_CREATE

    If asChoice != "accept" && asChoice != "deny"
        DebugMsg("OnDebtChoice: silently declined (" + asChoice + ")")
        Return
    EndIf
    Bool accepted = (asChoice == "accept")

    If mode == DEBT_CONFIRM_RECURRING
        If accepted
            _CommitRecurringDebt(cred, debt, amount, reason, intervalHours, creditLimit, intervalDesc)
        ElseIf debt == player
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " refused the recurring payment arrangement for " + reason, cred)
        Else
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " turns down " + debt.GetDisplayName() + "'s offer to pay " + amount + " gold " + intervalDesc + " for " + reason + ".", debt)
        EndIf
    ElseIf mode == DEBT_CONFIRM_FORGIVE
        If accepted
            _CommitForgiveDebt(cred, debt)
        Else
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " decided not to forgive the debt", debt)
        EndIf
    ElseIf mode == DEBT_CONFIRM_ADD
        If accepted
            _CommitAddToDebt(debtId, cred, debt, amount)
        Else
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " refused the additional charge of " + amount + " gold on the " + reason, cred)
        EndIf
    ElseIf accepted
        AddDebt(cred, debt, amount, reason, dueSeconds, false, 0.0, creditLimit)
        SkyrimNetApi.RegisterEvent("debt_created", debt.GetDisplayName() + " now owes " + cred.GetDisplayName() + " " + amount + " gold for " + reason, cred, debt)
    ElseIf debt == player
        SkyrimNetApi.DirectNarration(player.GetDisplayName() + " refused to accept the debt of " + amount + " gold for " + reason, cred)
    Else
        SkyrimNetApi.DirectNarration(player.GetDisplayName() + " waves it off - " + debt.GetDisplayName() + " owes them nothing for " + reason + ".", debt)
    EndIf
EndEvent

Function CreateRecurringDebt_Execute(Actor akSpeaker, Actor akCreditor, Actor akDebtor, Int aiAmount, String asReason, Int aiIntervalDays, Int aiCreditLimit)
    {Create a recurring charge of aiAmount every aiIntervalDays game days, at most one
     per creditor/debtor pair. aiCreditLimit: the most it can accumulate (0 = unlimited).}
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

    ; Overlay first, SkyMessage modal as the fallback (see CreateDebt_Execute).
    If akDebtor == player || akCreditor == player
        If _OpenDebtConfirm(DEBT_CONFIRM_RECURRING, akCreditor, akDebtor, aiAmount, asReason, aiIntervalDays, aiCreditLimit, 0, intervalHours, intervalDesc, 0)
            ; Choice arrives asynchronously via OnDebtChoice.
            Return
        EndIf
    EndIf

    If akDebtor == player
        String promptText = akCreditor.GetDisplayName() + " wants you to pay " + aiAmount + " gold " + intervalDesc + " for " + asReason + "." + limitInfo + " Accept?"
        String result = ""
        If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
            result = SeverActions_SkyMessageLib.Show(promptText, "Yes", "No", "No (Silent)")
        EndIf
        If result == "Yes"
            _CommitRecurringDebt(akCreditor, akDebtor, aiAmount, asReason, intervalHours, aiCreditLimit, intervalDesc)
        ElseIf result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " refused the recurring payment arrangement for " + asReason, akCreditor)
        Else
            DebugMsg("CreateRecurringDebt: Player silently declined recurring debt to " + akCreditor.GetDisplayName())
        EndIf

    ElseIf akCreditor == player
        String promptText = akDebtor.GetDisplayName() + " agrees to pay you " + aiAmount + " gold " + intervalDesc + " for " + asReason + "." + limitInfo + " Accept?"
        String result = ""
        If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
            result = SeverActions_SkyMessageLib.Show(promptText, "Yes", "No", "No (Silent)")
        EndIf
        If result == "Yes"
            _CommitRecurringDebt(akCreditor, akDebtor, aiAmount, asReason, intervalHours, aiCreditLimit, intervalDesc)
        ElseIf result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " turns down " + akDebtor.GetDisplayName() + "'s offer to pay " + aiAmount + " gold " + intervalDesc + " for " + asReason + ".", akDebtor)
        Else
            DebugMsg("CreateRecurringDebt: Player silently declined recurring debt from " + akDebtor.GetDisplayName())
        EndIf

    Else
        AddDebt(akCreditor, akDebtor, aiAmount, asReason, 0.0, true, intervalHours, aiCreditLimit)
        SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " will pay " + akCreditor.GetDisplayName() + " " + aiAmount + " gold " + intervalDesc + " for " + asReason, akCreditor, akDebtor)
    EndIf
EndFunction

Function _CommitRecurringDebt(Actor akCreditor, Actor akDebtor, Int aiAmount, String asReason, Float afIntervalHours, Int aiCreditLimit, String asIntervalDesc)
    {Record a player-confirmed recurring debt. Re-checks one-per-pair: another
     arrangement can land while the 20 s overlay is up.}
    If SeverActionsNativeExt.Native_Debt_FindRecurringPair(akCreditor, akDebtor) > 0
        DebugMsg("CreateRecurringDebt: an arrangement between " + akCreditor.GetDisplayName() + " and " + akDebtor.GetDisplayName() + " was created while the confirm was open - not duplicated")
        Return
    EndIf
    AddDebt(akCreditor, akDebtor, aiAmount, asReason, 0.0, true, afIntervalHours, aiCreditLimit)
    If akDebtor == Game.GetPlayer()
        SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " agreed to pay " + akCreditor.GetDisplayName() + " " + aiAmount + " gold " + asIntervalDesc + " for " + asReason, akCreditor, akDebtor)
    Else
        SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " will pay " + akCreditor.GetDisplayName() + " " + aiAmount + " gold " + asIntervalDesc + " for " + asReason, akCreditor, akDebtor)
    EndIf
EndFunction

Function ReduceDebtByPayment(Actor akCollector, Actor akPayer, Int aiAmountPaid)
    {Apply aiAmountPaid gold, already transferred, to what akPayer owes akCollector;
     debts that reach 0 are removed and both parties' factions synced. Called by
     Currency's GiveGold / RepayDebt / CollectPayment, and by SeverActions_Loot.TakeGoldFrom
     through the economy provider's reduceDebtByPayment service (Loot may not name this
     type, DR2).}
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
    {The speaker writes aiAmount off what the target owes them with no gold changing
     hands (a favour, work, goods). Unlike ForgiveDebt it is partial; it uses the
     payment arithmetic (Native_Debt_ReduceForPayment).}
    If !akSpeaker || !akTarget || aiAmount <= 0
        DebugMsg("ReduceDebt_Execute failed - invalid params")
        Return
    EndIf

    Int totalOwed = SeverActionsNativeExt.Native_Debt_SumOwed(akSpeaker, akTarget)
    If totalOwed <= 0
        DebugMsg("ReduceDebt: " + akTarget.GetDisplayName() + " doesn't owe " + akSpeaker.GetDisplayName() + " anything")
        Return
    EndIf

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
        ; Overlay first, SkyMessage modal as the fallback (see CreateDebt_Execute).
        If _OpenDebtConfirm(DEBT_CONFIRM_FORGIVE, akSpeaker, akTarget, totalOwed, "", 0, 0, 0, 0.0, "", 0)
            ; Choice arrives asynchronously via OnDebtChoice.
            Return
        EndIf
        String promptText = "Forgive " + akTarget.GetDisplayName() + "'s debt of " + totalOwed + " gold?"
        String result = ""
        If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
            result = SeverActions_SkyMessageLib.Show(promptText, "Yes", "No", "No (Silent)")
        EndIf
        If result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " decided not to forgive the debt", akTarget)
            Return
        ElseIf result != "Yes"
            DebugMsg("ForgiveDebt: Player silently declined forgiving " + akTarget.GetDisplayName())
            Return
        EndIf
    EndIf

    _CommitForgiveDebt(akSpeaker, akTarget)
EndFunction

Function _CommitForgiveDebt(Actor akSpeaker, Actor akTarget)
    {Remove every speaker->target debt and announce it. Re-reads the total, since a
     payment can land while the confirm is up.}
    Int totalOwed = SeverActionsNativeExt.Native_Debt_SumOwed(akSpeaker, akTarget)
    If totalOwed <= 0
        DebugMsg("ForgiveDebt: " + akTarget.GetDisplayName() + " no longer owes " + akSpeaker.GetDisplayName() + " anything")
        Return
    EndIf

    ; GetAllIDs returns a snapshot, so removing while walking it is safe.
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
    {Add aiAmount to a debt the target owes the speaker: the one matching asReason,
     else the first between them. Respects the credit limit; the player confirms when
     they are the debtor.}
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
        ; Overlay first, SkyMessage modal as the fallback (see CreateDebt_Execute).
        If _OpenDebtConfirm(DEBT_CONFIRM_ADD, akSpeaker, akTarget, aiAmount, reason, 0, creditLimit, currentAmount, 0.0, "", debtId)
            ; Choice arrives asynchronously via OnDebtChoice.
            Return
        EndIf
        String promptText = akSpeaker.GetDisplayName() + " is adding " + aiAmount + " gold to your " + reason + " debt (currently " + currentAmount + "g" + limitStr + "). Accept?"
        String result = ""
        If SeverActionsNativeExt2.Native_IsSkyMessageInstalled()
            result = SeverActions_SkyMessageLib.Show(promptText, "Yes", "No", "No (Silent)")
        EndIf
        If result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " refused the additional charge of " + aiAmount + " gold on the " + reason, akSpeaker)
            Return
        ElseIf result != "Yes"
            DebugMsg("AddToDebt: Player silently declined additional charge")
            Return
        EndIf
    EndIf

    _CommitAddToDebt(debtId, akSpeaker, akTarget, aiAmount)
EndFunction

Function _CommitAddToDebt(Int aiDebtId, Actor akSpeaker, Actor akTarget, Int aiAmount)
    {Apply a charge to debt aiDebtId. Re-validates first, since the debt can be paid
     off or forgiven while a confirm is up (ids are never reused, so a live id with
     the same parties is the same debt).}
    If !SeverActionsNativeExt.Native_Debt_Exists(aiDebtId) || SeverActionsNativeExt.Native_Debt_GetCreditor(aiDebtId) != akSpeaker || SeverActionsNativeExt.Native_Debt_GetDebtor(aiDebtId) != akTarget
        DebugMsg("AddToDebt: debt #" + aiDebtId + " closed before the charge was applied - charge dropped")
        Return
    EndIf
    String reason     = SeverActionsNativeExt.Native_Debt_GetReason(aiDebtId)
    Int currentAmount = SeverActionsNativeExt.Native_Debt_GetAmount(aiDebtId)

    Bool success = ModifyDebtAmount(aiDebtId, aiAmount)
    If success
        Int newAmount = SeverActionsNativeExt.Native_Debt_GetAmount(aiDebtId)
        ; Report what was actually added: ModifyDebtAmount clamps at the credit limit.
        Int actualAdded = newAmount - currentAmount
        SkyrimNetApi.RegisterEvent("debt_increased", actualAdded + " gold added to " + akTarget.GetDisplayName() + "'s debt with " + akSpeaker.GetDisplayName() + " for " + reason + " - " + newAmount + " gold owed in all", akSpeaker, akTarget)
        DebugMsg("AddToDebt: +" + actualAdded + "g on debt #" + aiDebtId + " (" + reason + "), now " + newAmount + "g")
    EndIf
EndFunction

; ===== AUTO-GROWTH (GiveItem) =====

Function AutoAddToDebt(Actor akGiver, Actor akReceiver, Int goldValue)
    {When the giver is owed by the receiver, add the given items' gold value to that
     debt (up to the credit limit; no confirm, the item is already given) and fire a
     short-lived event. Reached from SeverActions_Loot.GiveItem_Execute through the
     economy provider's autoAddToDebt service (Loot may not name this type, DR2).}
    If !akGiver || !akReceiver || goldValue <= 0
        Return
    EndIf

    Int debtId = SeverActionsNativeExt.Native_Debt_FindBestForGiveItem(akGiver, akReceiver)
    If debtId <= 0
        Return
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
            goldValue + " gold added to " + akReceiver.GetDisplayName() + "'s " + reason + " with " + akGiver.GetDisplayName() + " - " + newAmount + " gold owed in all", \
            "", 300000, akGiver, akReceiver)
        DebugMsg("AutoAddToDebt: +" + goldValue + "g on debt #" + debtId + " (" + reason + "), now " + newAmount + "g")
    EndIf
EndFunction

; ===== ELIGIBILITY =====

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

; ===== INSTANCE =====

SeverActions_Debt Function GetInstance() Global
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Debt
EndFunction
