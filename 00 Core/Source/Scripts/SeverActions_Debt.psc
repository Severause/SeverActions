Scriptname SeverActions_Debt extends Quest
{Debt tracking system for SeverActions — tracks gold obligations between actors.
 Supports one-time debts (tabs, loans) and recurring arrangements (rent, protection money).
 Integrates with SkyrimNet via StorageUtil per-actor summary strings read natively
 by papyrus_util in prompt templates. No custom decorator registration needed.}

; =============================================================================
; PROPERTIES
; =============================================================================

SeverActions_Currency Property CurrencyScript Auto
{Reference to the Currency system for gold transfers during debt settlement}

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
 is created, removed when all debts are paid or forgiven. Used by YAML eligibility
 rules so SettleDebt only appears for actors involved in debts.
 Create in CK with EditorID: SeverActions_DebtorFaction}

Faction Property CreditorFaction Auto
{Faction for actors who are currently owed money. Managed automatically — added when
 debt is created, removed when all debts are settled or forgiven. Used by YAML
 eligibility rules so ForgiveDebt only appears for actors who are owed money.
 Create in CK with EditorID: SeverActions_CreditorFaction}

; =============================================================================
; CONSTANTS
; =============================================================================

String Property KEY_COUNT = "SeverDebt_Count" AutoReadOnly
String Property KEY_ACTOR_INFO = "SeverDebt_Info" AutoReadOnly
String Property KEY_COMPLAINTS = "SeverDebt_Complaints" AutoReadOnly

Float Property SECONDS_PER_GAME_HOUR = 3631.0 AutoReadOnly

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Debt] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    {Called on init and game load. Rebuilds all per-actor summary strings
     so papyrus_util reads return current data after load.}
    DebugMsg("Maintenance — rebuilding debt summaries")
    RebuildAllSummaries()
EndFunction

; =============================================================================
; INTERNAL HELPERS
; =============================================================================

Float Function GetGameTimeInSeconds()
    {Convert current game time to seconds — same formula as FollowerManager}
    Return Utility.GetCurrentGameTime() * 24.0 * SECONDS_PER_GAME_HOUR
EndFunction

String Function GetDebtKey(Int index, String suffix)
    {Build a StorageUtil key for a debt field, e.g. SeverDebt_0_Amount}
    Return "SeverDebt_" + index + "_" + suffix
EndFunction

Function DebugMsg(String msg)
    If DebugMode
        Debug.Trace("[SeverActions_Debt] " + msg)
    EndIf
EndFunction

; =============================================================================
; CORE CRUD OPERATIONS
; =============================================================================

Int Function GetDebtCount()
    Return StorageUtil.GetIntValue(self, KEY_COUNT, 0)
EndFunction

Int Function AddDebt(Actor creditor, Actor debtor, Int amount, String reason, Float dueTimeSeconds, Bool isRecurring, Float recurringIntervalHours, Int creditLimit = 0)
    {Create a new debt record. Returns the index of the new debt, or -1 on failure.
     creditLimit: max gold this debt can reach (0 = unlimited).}
    If !creditor || !debtor || amount <= 0
        DebugMsg("AddDebt failed — invalid params")
        Return -1
    EndIf
    If creditor == debtor
        DebugMsg("AddDebt failed — creditor == debtor")
        Return -1
    EndIf

    Int index = GetDebtCount()
    Float currentTime = GetGameTimeInSeconds()

    StorageUtil.SetFormValue(self, GetDebtKey(index, "Creditor"), creditor)
    StorageUtil.SetFormValue(self, GetDebtKey(index, "Debtor"), debtor)
    StorageUtil.SetIntValue(self, GetDebtKey(index, "Amount"), amount)
    StorageUtil.SetStringValue(self, GetDebtKey(index, "Reason"), reason)
    StorageUtil.SetFloatValue(self, GetDebtKey(index, "CreatedTime"), currentTime)
    StorageUtil.SetFloatValue(self, GetDebtKey(index, "DueTime"), dueTimeSeconds)
    StorageUtil.SetIntValue(self, GetDebtKey(index, "CreditLimit"), creditLimit)

    If isRecurring
        StorageUtil.SetIntValue(self, GetDebtKey(index, "IsRecurring"), 1)
        StorageUtil.SetFloatValue(self, GetDebtKey(index, "RecurringInterval"), recurringIntervalHours)
        StorageUtil.SetFloatValue(self, GetDebtKey(index, "LastRecurred"), currentTime)
    Else
        StorageUtil.SetIntValue(self, GetDebtKey(index, "IsRecurring"), 0)
        StorageUtil.SetFloatValue(self, GetDebtKey(index, "RecurringInterval"), 0.0)
        StorageUtil.SetFloatValue(self, GetDebtKey(index, "LastRecurred"), 0.0)
    EndIf

    StorageUtil.SetIntValue(self, GetDebtKey(index, "OverdueNotified"), 0)
    StorageUtil.SetIntValue(self, GetDebtKey(index, "ReportedToGuards"), 0)
    StorageUtil.SetIntValue(self, KEY_COUNT, index + 1)

    DebugMsg("Added debt #" + index + ": " + creditor.GetDisplayName() + " <- " + debtor.GetDisplayName() + " " + amount + "g (" + reason + ")")

    ; Update per-actor summaries for both parties
    RebuildDebtSummary(creditor)
    RebuildDebtSummary(debtor)

    Return index
EndFunction

Bool Function RemoveDebt(Int index)
    {Remove a debt by swapping with the last entry. Returns true on success.}
    Int count = GetDebtCount()
    If index < 0 || index >= count
        DebugMsg("RemoveDebt failed — index " + index + " out of range (count=" + count + ")")
        Return false
    EndIf

    ; Get actors before removal for summary rebuild
    Actor creditor = StorageUtil.GetFormValue(self, GetDebtKey(index, "Creditor"), None) as Actor
    Actor debtor = StorageUtil.GetFormValue(self, GetDebtKey(index, "Debtor"), None) as Actor

    Int lastIndex = count - 1

    If index != lastIndex
        ; Swap with last entry
        CopyDebt(lastIndex, index)
    EndIf

    ; Clear the last slot
    ClearDebtSlot(lastIndex)
    StorageUtil.SetIntValue(self, KEY_COUNT, lastIndex)

    DebugMsg("Removed debt #" + index + " (count now " + lastIndex + ")")

    ; Rebuild summaries for affected actors
    If creditor
        RebuildDebtSummary(creditor)
    EndIf
    If debtor
        RebuildDebtSummary(debtor)
    EndIf

    Return true
EndFunction

Function CopyDebt(Int fromIndex, Int toIndex)
    {Copy all fields from one debt slot to another}
    StorageUtil.SetFormValue(self, GetDebtKey(toIndex, "Creditor"), StorageUtil.GetFormValue(self, GetDebtKey(fromIndex, "Creditor"), None))
    StorageUtil.SetFormValue(self, GetDebtKey(toIndex, "Debtor"), StorageUtil.GetFormValue(self, GetDebtKey(fromIndex, "Debtor"), None))
    StorageUtil.SetIntValue(self, GetDebtKey(toIndex, "Amount"), StorageUtil.GetIntValue(self, GetDebtKey(fromIndex, "Amount"), 0))
    StorageUtil.SetStringValue(self, GetDebtKey(toIndex, "Reason"), StorageUtil.GetStringValue(self, GetDebtKey(fromIndex, "Reason"), ""))
    StorageUtil.SetFloatValue(self, GetDebtKey(toIndex, "CreatedTime"), StorageUtil.GetFloatValue(self, GetDebtKey(fromIndex, "CreatedTime"), 0.0))
    StorageUtil.SetFloatValue(self, GetDebtKey(toIndex, "DueTime"), StorageUtil.GetFloatValue(self, GetDebtKey(fromIndex, "DueTime"), 0.0))
    StorageUtil.SetIntValue(self, GetDebtKey(toIndex, "CreditLimit"), StorageUtil.GetIntValue(self, GetDebtKey(fromIndex, "CreditLimit"), 0))
    StorageUtil.SetIntValue(self, GetDebtKey(toIndex, "IsRecurring"), StorageUtil.GetIntValue(self, GetDebtKey(fromIndex, "IsRecurring"), 0))
    StorageUtil.SetFloatValue(self, GetDebtKey(toIndex, "RecurringInterval"), StorageUtil.GetFloatValue(self, GetDebtKey(fromIndex, "RecurringInterval"), 0.0))
    StorageUtil.SetFloatValue(self, GetDebtKey(toIndex, "LastRecurred"), StorageUtil.GetFloatValue(self, GetDebtKey(fromIndex, "LastRecurred"), 0.0))
    StorageUtil.SetIntValue(self, GetDebtKey(toIndex, "RecurringCharge"), StorageUtil.GetIntValue(self, GetDebtKey(fromIndex, "RecurringCharge"), 0))
    StorageUtil.SetIntValue(self, GetDebtKey(toIndex, "OverdueNotified"), StorageUtil.GetIntValue(self, GetDebtKey(fromIndex, "OverdueNotified"), 0))
    StorageUtil.SetIntValue(self, GetDebtKey(toIndex, "ReportedToGuards"), StorageUtil.GetIntValue(self, GetDebtKey(fromIndex, "ReportedToGuards"), 0))
EndFunction

Function ClearDebtSlot(Int index)
    {Clear all StorageUtil keys for a debt slot}
    StorageUtil.UnsetFormValue(self, GetDebtKey(index, "Creditor"))
    StorageUtil.UnsetFormValue(self, GetDebtKey(index, "Debtor"))
    StorageUtil.UnsetIntValue(self, GetDebtKey(index, "Amount"))
    StorageUtil.UnsetStringValue(self, GetDebtKey(index, "Reason"))
    StorageUtil.UnsetFloatValue(self, GetDebtKey(index, "CreatedTime"))
    StorageUtil.UnsetFloatValue(self, GetDebtKey(index, "DueTime"))
    StorageUtil.UnsetIntValue(self, GetDebtKey(index, "CreditLimit"))
    StorageUtil.UnsetIntValue(self, GetDebtKey(index, "IsRecurring"))
    StorageUtil.UnsetFloatValue(self, GetDebtKey(index, "RecurringInterval"))
    StorageUtil.UnsetFloatValue(self, GetDebtKey(index, "LastRecurred"))
    StorageUtil.UnsetIntValue(self, GetDebtKey(index, "RecurringCharge"))
    StorageUtil.UnsetIntValue(self, GetDebtKey(index, "OverdueNotified"))
    StorageUtil.UnsetIntValue(self, GetDebtKey(index, "ReportedToGuards"))
EndFunction

; =============================================================================
; QUERY FUNCTIONS
; =============================================================================

Int Function FindDebt(Actor creditor, Actor debtor, String reason)
    {Find the first debt matching creditor + debtor + reason. Returns -1 if not found.}
    Int count = GetDebtCount()
    Int i = 0
    While i < count
        Actor c = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        Actor d = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor
        If c == creditor && d == debtor
            String r = StorageUtil.GetStringValue(self, GetDebtKey(i, "Reason"), "")
            If r == reason
                Return i
            EndIf
        EndIf
        i += 1
    EndWhile
    Return -1
EndFunction

Int Function FindRecurringDebt(Actor creditor, Actor debtor)
    {Find the first recurring debt matching creditor + debtor. Returns -1 if not found.}
    Int count = GetDebtCount()
    Int i = 0
    While i < count
        Int isRecurring = StorageUtil.GetIntValue(self, GetDebtKey(i, "IsRecurring"), 0)
        If isRecurring == 1
            Actor c = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
            Actor d = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor
            If c == creditor && d == debtor
                Return i
            EndIf
        EndIf
        i += 1
    EndWhile
    Return -1
EndFunction

Int Function FindAnyDebt(Actor actorA, Actor actorB)
    {Find the first debt between two actors (either direction). Returns -1 if not found.}
    Int count = GetDebtCount()
    Int i = 0
    While i < count
        Actor c = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        Actor d = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor
        If (c == actorA && d == actorB) || (c == actorB && d == actorA)
            Return i
        EndIf
        i += 1
    EndWhile
    Return -1
EndFunction

Int Function GetAmountOwed(Actor creditor, Actor debtor)
    {Total gold debtor owes creditor across all matching debts}
    Int count = GetDebtCount()
    Int total = 0
    Int i = 0
    While i < count
        Actor c = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        Actor d = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor
        If c == creditor && d == debtor
            total += StorageUtil.GetIntValue(self, GetDebtKey(i, "Amount"), 0)
        EndIf
        i += 1
    EndWhile
    Return total
EndFunction

Int Function GetTotalOwedBy(Actor debtor)
    {Total gold this actor owes everyone}
    Int count = GetDebtCount()
    Int total = 0
    Int i = 0
    While i < count
        Actor d = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor
        If d == debtor
            total += StorageUtil.GetIntValue(self, GetDebtKey(i, "Amount"), 0)
        EndIf
        i += 1
    EndWhile
    Return total
EndFunction

Int Function GetTotalOwedTo(Actor creditor)
    {Total gold owed to this actor by everyone}
    Int count = GetDebtCount()
    Int total = 0
    Int i = 0
    While i < count
        Actor c = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        If c == creditor
            total += StorageUtil.GetIntValue(self, GetDebtKey(i, "Amount"), 0)
        EndIf
        i += 1
    EndWhile
    Return total
EndFunction

Bool Function HasAnyDebt(Actor akActor)
    {Check if the actor is involved in any debt (as creditor or debtor)}
    Int count = GetDebtCount()
    Int i = 0
    While i < count
        Actor c = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        Actor d = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor
        If c == akActor || d == akActor
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

Bool Function IsCreditorOnAnyDebt(Actor akActor)
    {Check if the actor is owed money by anyone}
    Int count = GetDebtCount()
    Int i = 0
    While i < count
        Actor c = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        If c == akActor
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

Bool Function ModifyDebtAmount(Int index, Int deltaAmount)
    {Increase or decrease a debt's amount. Removes the debt if amount hits 0 or below.
     Enforces credit limit on positive deltas — clamps at limit and fires event if reached.
     Returns false if index out of range or if already at credit limit (no change made).}
    Int count = GetDebtCount()
    If index < 0 || index >= count
        Return false
    EndIf

    Int currentAmount = StorageUtil.GetIntValue(self, GetDebtKey(index, "Amount"), 0)
    Int creditLimit = StorageUtil.GetIntValue(self, GetDebtKey(index, "CreditLimit"), 0)

    ; Enforce credit limit on increases
    If deltaAmount > 0 && creditLimit > 0
        If currentAmount >= creditLimit
            ; Already at limit — reject the increase
            Actor creditor = StorageUtil.GetFormValue(self, GetDebtKey(index, "Creditor"), None) as Actor
            Actor debtor = StorageUtil.GetFormValue(self, GetDebtKey(index, "Debtor"), None) as Actor
            String reason = StorageUtil.GetStringValue(self, GetDebtKey(index, "Reason"), "")
            If creditor && debtor
                SkyrimNetApi.RegisterShortLivedEvent( \
                    "debt_limit_" + index, "debt_credit_limit_reached", \
                    debtor.GetDisplayName() + " has reached the " + creditLimit + " gold credit limit with " + creditor.GetDisplayName() + " for " + reason, \
                    "", 300000, creditor, debtor)
            EndIf
            DebugMsg("ModifyDebtAmount: credit limit reached on debt #" + index + " (" + currentAmount + "/" + creditLimit + "g)")
            Return false
        EndIf
        ; Clamp the increase so it doesn't exceed the limit
        Int maxIncrease = creditLimit - currentAmount
        If deltaAmount > maxIncrease
            deltaAmount = maxIncrease
        EndIf
    EndIf

    Int newAmount = currentAmount + deltaAmount

    If newAmount <= 0
        RemoveDebt(index)
    Else
        StorageUtil.SetIntValue(self, GetDebtKey(index, "Amount"), newAmount)
        ; Rebuild summaries
        Actor creditor = StorageUtil.GetFormValue(self, GetDebtKey(index, "Creditor"), None) as Actor
        Actor debtor = StorageUtil.GetFormValue(self, GetDebtKey(index, "Debtor"), None) as Actor
        If creditor
            RebuildDebtSummary(creditor)
        EndIf
        If debtor
            RebuildDebtSummary(debtor)
        EndIf

        ; Check if we just hit the credit limit after this change
        If creditLimit > 0 && newAmount >= creditLimit && creditor && debtor
            String reason = StorageUtil.GetStringValue(self, GetDebtKey(index, "Reason"), "")
            SkyrimNetApi.RegisterShortLivedEvent( \
                "debt_limit_" + index, "debt_credit_limit_reached", \
                debtor.GetDisplayName() + " has reached the " + creditLimit + " gold credit limit with " + creditor.GetDisplayName() + " for " + reason, \
                "", 300000, creditor, debtor)
            DebugMsg("ModifyDebtAmount: credit limit reached on debt #" + index + " (" + newAmount + "/" + creditLimit + "g)")
        EndIf
    EndIf

    Return true
EndFunction

; =============================================================================
; PER-ACTOR SUMMARY CACHE (for papyrus_util native reads)
; =============================================================================

Function RebuildDebtSummary(Actor akActor)
    {Rebuilds the SeverDebt_Info string stored on the actor via StorageUtil.
     The prompt template reads this natively via papyrus_util("GetStringValue", npc.UUID, "SeverDebt_Info", "").
     No Papyrus decorator needed — zero caching, always current.}
    If !akActor
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int count = GetDebtCount()
    String result = ""
    Float currentTime = GetGameTimeInSeconds()
    Int debtsFound = 0
    Bool isAnyCreditor = false
    Bool isAnyDebtor = false

    Int i = 0
    While i < count
        Actor creditor = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        Actor debtor = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor

        If creditor == akActor || debtor == akActor
            Int amount = StorageUtil.GetIntValue(self, GetDebtKey(i, "Amount"), 0)
            String reason = StorageUtil.GetStringValue(self, GetDebtKey(i, "Reason"), "")
            Int isRecurring = StorageUtil.GetIntValue(self, GetDebtKey(i, "IsRecurring"), 0)
            Float dueTime = StorageUtil.GetFloatValue(self, GetDebtKey(i, "DueTime"), 0.0)
            Float recurringInterval = StorageUtil.GetFloatValue(self, GetDebtKey(i, "RecurringInterval"), 0.0)
            Int creditLimit = StorageUtil.GetIntValue(self, GetDebtKey(i, "CreditLimit"), 0)

            ; Determine the "other" actor relative to akActor
            Actor otherActor
            Bool akActorIsCreditor
            If creditor == akActor
                otherActor = debtor
                akActorIsCreditor = true
                isAnyCreditor = true
            Else
                otherActor = creditor
                akActorIsCreditor = false
                isAnyDebtor = true
            EndIf

            ; Build the name of the other party
            String otherName
            If otherActor == player
                otherName = player.GetDisplayName()
            Else
                otherName = otherActor.GetDisplayName()
            EndIf

            ; Format the amount — "X/Y gold" if credit limit exists, "X gold" otherwise
            String amountStr
            If creditLimit > 0
                amountStr = amount + "/" + creditLimit + " gold"
            Else
                amountStr = amount + " gold"
            EndIf

            ; Build the debt line
            String line = "- "

            If isRecurring == 1
                ; Recurring debt
                Int intervalDays = Math.Floor(recurringInterval / 24.0) as Int
                String intervalStr
                If intervalDays <= 1
                    intervalStr = "daily"
                ElseIf intervalDays == 7
                    intervalStr = "weekly"
                ElseIf intervalDays == 30
                    intervalStr = "monthly"
                Else
                    intervalStr = "every " + intervalDays + " days"
                EndIf

                Int chargeAmount = StorageUtil.GetIntValue(self, GetDebtKey(i, "RecurringCharge"), 0)
                String chargeStr = ""
                If chargeAmount > 0
                    chargeStr = " (" + chargeAmount + " gold/cycle)"
                EndIf

                If akActorIsCreditor
                    line += intervalStr + ": " + otherName + " owes you " + amountStr + " for " + reason + chargeStr
                Else
                    line += intervalStr + ": You owe " + otherName + " " + amountStr + " for " + reason + chargeStr
                EndIf
            Else
                ; One-time debt
                If akActorIsCreditor
                    line += otherName + " owes you " + amountStr + " (" + reason + ")"
                Else
                    line += "You owe " + otherName + " " + amountStr + " (" + reason + ")"
                EndIf
            EndIf

            ; Credit limit reached indicator
            If creditLimit > 0 && amount >= creditLimit
                line += " [credit limit reached]"
            EndIf

            ; Due date / overdue info
            If dueTime > 0.0
                If currentTime > dueTime
                    Float overdueHours = (currentTime - dueTime) / SECONDS_PER_GAME_HOUR
                    Int overdueDays = Math.Floor(overdueHours / 24.0) as Int
                    If overdueDays > 0
                        line += " — " + overdueDays + " days overdue"
                    Else
                        line += " — overdue"
                    EndIf
                Else
                    Float remainingHours = (dueTime - currentTime) / SECONDS_PER_GAME_HOUR
                    Int remainingDays = Math.Floor(remainingHours / 24.0) as Int
                    If remainingDays > 0
                        line += " — due in " + remainingDays + " days"
                    Else
                        line += " — due today"
                    EndIf
                EndIf
            EndIf

            If debtsFound > 0
                result += "\n"
            EndIf
            result += line
            debtsFound += 1
        EndIf

        i += 1
    EndWhile

    If debtsFound > 0
        StorageUtil.SetStringValue(akActor, KEY_ACTOR_INFO, result)
    Else
        StorageUtil.UnsetStringValue(akActor, KEY_ACTOR_INFO)
    EndIf

    ; Update faction membership based on debt involvement
    If DebtorFaction
        If isAnyDebtor
            akActor.AddToFaction(DebtorFaction)
        Else
            akActor.RemoveFromFaction(DebtorFaction)
        EndIf
    EndIf
    If CreditorFaction
        If isAnyCreditor
            akActor.AddToFaction(CreditorFaction)
        Else
            akActor.RemoveFromFaction(CreditorFaction)
        EndIf
    EndIf
EndFunction

Function RebuildAllSummaries()
    {Rebuild summary strings for all actors involved in any debt.
     Called during Maintenance (game load) to ensure papyrus_util reads are fresh.}
    Int count = GetDebtCount()

    ; Collect unique actors — Papyrus has no Set type, so use a fixed-size array
    ; with manual dedup. Max realistic unique actors across all debts.
    If count <= 0
        Return
    EndIf
    Actor[] actors = new Actor[40]
    Int actorCount = 0

    Int i = 0
    While i < count
        Actor creditor = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        Actor debtor = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor

        If creditor
            If !ArrayContainsActor(actors, actorCount, creditor)
                If actorCount < 40
                    actors[actorCount] = creditor
                    actorCount += 1
                EndIf
            EndIf
        EndIf
        If debtor
            If !ArrayContainsActor(actors, actorCount, debtor)
                If actorCount < 40
                    actors[actorCount] = debtor
                    actorCount += 1
                EndIf
            EndIf
        EndIf

        i += 1
    EndWhile

    ; Rebuild each actor's summary
    i = 0
    While i < actorCount
        RebuildDebtSummary(actors[i])
        i += 1
    EndWhile

    DebugMsg("RebuildAllSummaries — refreshed " + actorCount + " actors across " + count + " debts")

    ; Also rebuild guard complaint summary for player debts
    RebuildComplaintSummary()
EndFunction

Function RebuildComplaintSummary()
    {Rebuild the SeverDebt_Complaints string stored on the player.
     Guards read this via papyrus_util in the bounty prompt.
     Only includes debts where the player is debtor AND ReportedToGuards == 1.}
    Actor player = Game.GetPlayer()
    If !player
        Return
    EndIf

    Int count = GetDebtCount()
    String result = ""
    Float currentTime = GetGameTimeInSeconds()
    Int complaintsFound = 0

    Int i = 0
    While i < count
        Actor debtor = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor
        If debtor == player
            Int reported = StorageUtil.GetIntValue(self, GetDebtKey(i, "ReportedToGuards"), 0)
            If reported == 1
                Actor creditor = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
                Int amount = StorageUtil.GetIntValue(self, GetDebtKey(i, "Amount"), 0)
                String reason = StorageUtil.GetStringValue(self, GetDebtKey(i, "Reason"), "")
                Float dueTime = StorageUtil.GetFloatValue(self, GetDebtKey(i, "DueTime"), 0.0)

                String line = "- "
                If creditor
                    line += creditor.GetDisplayName()
                Else
                    line += "Unknown creditor"
                EndIf
                line += " is owed " + amount + " gold for " + reason

                If dueTime > 0.0 && currentTime > dueTime
                    Float overdueHours = (currentTime - dueTime) / SECONDS_PER_GAME_HOUR
                    Int overdueDays = (overdueHours / 24.0) as Int
                    If overdueDays > 0
                        line += " — " + overdueDays + " days overdue"
                    Else
                        line += " — overdue"
                    EndIf
                EndIf

                If complaintsFound > 0
                    result += "\n"
                EndIf
                result += line
                complaintsFound += 1
            EndIf
        EndIf
        i += 1
    EndWhile

    If complaintsFound > 0
        StorageUtil.SetStringValue(player, KEY_COMPLAINTS, result)
    Else
        StorageUtil.UnsetStringValue(player, KEY_COMPLAINTS)
    EndIf

    DebugMsg("RebuildComplaintSummary — " + complaintsFound + " active complaints")
EndFunction

Bool Function ArrayContainsActor(Actor[] arr, Int arrLen, Actor target)
    Int i = 0
    While i < arrLen
        If arr[i] == target
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

; =============================================================================
; TICK PROCESSING (called from FollowerManager OnUpdate)
; =============================================================================

Function TickDebts(Float gameHoursPassed)
    {Process recurring charges and overdue notifications.
     Called every 30 real seconds when >= 0.5 game hours have passed.}
    Int count = GetDebtCount()
    If count == 0
        Return
    EndIf

    Float currentTime = GetGameTimeInSeconds()
    Bool anySummaryChanged = false

    ; Process in reverse order since RemoveDebt swaps with last
    Int i = count - 1
    While i >= 0
        ; --- Recurring charges ---
        Int isRecurring = StorageUtil.GetIntValue(self, GetDebtKey(i, "IsRecurring"), 0)
        If isRecurring == 1
            Float lastRecurred = StorageUtil.GetFloatValue(self, GetDebtKey(i, "LastRecurred"), 0.0)
            Float intervalHours = StorageUtil.GetFloatValue(self, GetDebtKey(i, "RecurringInterval"), 0.0)
            Float intervalSeconds = intervalHours * SECONDS_PER_GAME_HOUR

            If intervalSeconds > 0.0 && (currentTime - lastRecurred) >= intervalSeconds
                ; Add recurring charge — respects credit limits
                Int amount = StorageUtil.GetIntValue(self, GetDebtKey(i, "Amount"), 0)
                Int creditLimit = StorageUtil.GetIntValue(self, GetDebtKey(i, "CreditLimit"), 0)

                ; Check if already at credit limit
                If creditLimit > 0 && amount >= creditLimit
                    ; At limit — skip this cycle's charge, just update timestamp
                    StorageUtil.SetFloatValue(self, GetDebtKey(i, "LastRecurred"), currentTime)
                    DebugMsg("Recurring charge skipped: debt #" + i + " at credit limit (" + amount + "/" + creditLimit + "g)")
                Else
                    ; Read the per-cycle charge from a dedicated field
                    Int chargeAmount = StorageUtil.GetIntValue(self, GetDebtKey(i, "RecurringCharge"), 0)
                    If chargeAmount <= 0
                        ; Fallback for debts created before this field existed — use current amount
                        chargeAmount = amount
                        StorageUtil.SetIntValue(self, GetDebtKey(i, "RecurringCharge"), chargeAmount)
                    EndIf

                    ; Clamp charge to credit limit if set
                    Int newAmount = amount + chargeAmount
                    If creditLimit > 0 && newAmount > creditLimit
                        newAmount = creditLimit
                    EndIf

                    StorageUtil.SetIntValue(self, GetDebtKey(i, "Amount"), newAmount)
                    StorageUtil.SetFloatValue(self, GetDebtKey(i, "LastRecurred"), currentTime)
                    anySummaryChanged = true

                    Actor creditor = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
                    Actor debtor = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor
                    String reason = StorageUtil.GetStringValue(self, GetDebtKey(i, "Reason"), "")

                    DebugMsg("Recurring charge: +" + chargeAmount + "g on debt #" + i + " (" + reason + "), now " + newAmount + "g total")

                    ; Short-lived event for scene context (5 min TTL)
                    If creditor && debtor
                        String eventDesc = creditor.GetDisplayName() + " is owed another " + chargeAmount + " gold by " + debtor.GetDisplayName() + " for " + reason + " (recurring charge)"
                        SkyrimNetApi.RegisterShortLivedEvent( \
                            "debt_recurring_" + i, "debt_recurring", eventDesc, "", 300000, creditor, debtor)

                        ; Fire credit limit event if we just hit it
                        If creditLimit > 0 && newAmount >= creditLimit
                            SkyrimNetApi.RegisterShortLivedEvent( \
                                "debt_limit_" + i, "debt_credit_limit_reached", \
                                debtor.GetDisplayName() + " has reached the " + creditLimit + " gold credit limit with " + creditor.GetDisplayName() + " for " + reason, \
                                "", 300000, creditor, debtor)
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf

        ; --- Overdue notifications ---
        If EnableOverdueReminders
            Float dueTime = StorageUtil.GetFloatValue(self, GetDebtKey(i, "DueTime"), 0.0)
            Int alreadyNotified = StorageUtil.GetIntValue(self, GetDebtKey(i, "OverdueNotified"), 0)

            If dueTime > 0.0 && alreadyNotified == 0
                Float gracePeriodSeconds = OverdueGracePeriodHours * SECONDS_PER_GAME_HOUR
                If currentTime > (dueTime + gracePeriodSeconds)
                    Actor creditor = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
                    Actor debtor = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor
                    Int amount = StorageUtil.GetIntValue(self, GetDebtKey(i, "Amount"), 0)
                    String reason = StorageUtil.GetStringValue(self, GetDebtKey(i, "Reason"), "")

                    StorageUtil.SetIntValue(self, GetDebtKey(i, "OverdueNotified"), 1)

                    If creditor && debtor
                        String eventContent = debtor.GetDisplayName() + " is overdue on " + amount + " gold owed to " + creditor.GetDisplayName() + " for " + reason
                        SkyrimNetApi.RegisterPersistentEvent(eventContent, creditor, debtor)
                        DebugMsg("Overdue: debt #" + i + " — " + eventContent)
                    EndIf
                EndIf
            EndIf
        EndIf

        ; --- Guard report filing (severe overdue) ---
        Float dueTime_r = StorageUtil.GetFloatValue(self, GetDebtKey(i, "DueTime"), 0.0)
        Int alreadyReported = StorageUtil.GetIntValue(self, GetDebtKey(i, "ReportedToGuards"), 0)

        If dueTime_r > 0.0 && alreadyReported == 0
            Float reportSeconds = ReportThresholdHours * SECONDS_PER_GAME_HOUR
            If currentTime > (dueTime_r + reportSeconds)
                Actor debtor_r = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor
                ; Only file reports against the player
                If debtor_r == Game.GetPlayer()
                    Actor creditor_r = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
                    ; Only when creditor is NOT near the player (3D not loaded = player is away)
                    If creditor_r && !creditor_r.Is3DLoaded()
                        StorageUtil.SetIntValue(self, GetDebtKey(i, "ReportedToGuards"), 1)
                        anySummaryChanged = true

                        Int amount_r = StorageUtil.GetIntValue(self, GetDebtKey(i, "Amount"), 0)
                        String reason_r = StorageUtil.GetStringValue(self, GetDebtKey(i, "Reason"), "")
                        String reportMsg = creditor_r.GetDisplayName() + " has reported " + debtor_r.GetDisplayName() + " to the authorities for an unpaid debt of " + amount_r + " gold (" + reason_r + ")"
                        SkyrimNetApi.RegisterPersistentEvent(reportMsg, creditor_r, debtor_r)
                        DebugMsg("Debt reported to guards: debt #" + i + " — " + reportMsg)
                    EndIf
                EndIf
            EndIf
        EndIf

        i -= 1
    EndWhile

    ; Rebuild affected summaries if anything changed
    If anySummaryChanged
        RebuildAllSummaries()
    EndIf
EndFunction

; =============================================================================
; ACTION EXECUTION FUNCTIONS (called by YAML actions)
; =============================================================================

Function CreateDebt_Execute(Actor akSpeaker, Actor akCreditor, Actor akDebtor, Int aiAmount, String asReason, Int aiDueDays, Int aiCreditLimit)
    {Create a one-time debt. Player confirmation via SkyMessage if player is involved.
     aiDueDays: days until due (0 = open-ended). aiCreditLimit: max gold (0 = unlimited).}
    If !akSpeaker || !akCreditor || !akDebtor || aiAmount <= 0
        DebugMsg("CreateDebt_Execute failed — invalid params")
        Return
    EndIf

    ; Duplicate prevention — reject if same creditor+debtor+reason already exists
    Int existingIndex = FindDebt(akCreditor, akDebtor, asReason)
    If existingIndex >= 0
        DebugMsg("CreateDebt: Duplicate rejected — " + akDebtor.GetDisplayName() + " already owes " + akCreditor.GetDisplayName() + " for " + asReason)
        SkyrimNetApi.RegisterEvent("debt_create_failed", akDebtor.GetDisplayName() + " already has an outstanding debt to " + akCreditor.GetDisplayName() + " for " + asReason, akSpeaker, akCreditor)
        Return
    EndIf

    ; Calculate due time in game seconds (0 = no deadline)
    Float dueTimeSeconds = 0.0
    If aiDueDays > 0
        dueTimeSeconds = GetGameTimeInSeconds() + (aiDueDays as Float * 24.0 * SECONDS_PER_GAME_HOUR)
    EndIf

    ; Clamp initial amount to credit limit if set
    If aiCreditLimit > 0 && aiAmount > aiCreditLimit
        aiAmount = aiCreditLimit
    EndIf

    Actor player = Game.GetPlayer()

    ; Build prompt details for due date and credit limit
    String extraDetails = ""
    If aiDueDays > 0
        extraDetails += " Due in " + aiDueDays + " days."
    EndIf
    If aiCreditLimit > 0
        extraDetails += " Credit limit: " + aiCreditLimit + " gold."
    EndIf

    ; Player confirmation
    If akDebtor == player
        ; Player is being told they owe money
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
        ; Someone acknowledges owing the player money
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
        ; NPC-to-NPC debt — no player confirmation needed
        AddDebt(akCreditor, akDebtor, aiAmount, asReason, dueTimeSeconds, false, 0.0, aiCreditLimit)
        SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " now owes " + akCreditor.GetDisplayName() + " " + aiAmount + " gold for " + asReason, akCreditor, akDebtor)
    EndIf
EndFunction

Function CreateRecurringDebt_Execute(Actor akSpeaker, Actor akCreditor, Actor akDebtor, Int aiAmount, String asReason, Int aiIntervalDays, Int aiCreditLimit)
    {Create a recurring debt. interval = aiIntervalDays x 24 game hours.
     aiCreditLimit: max gold this recurring debt can accumulate to (0 = unlimited).}
    If !akSpeaker || !akCreditor || !akDebtor || aiAmount <= 0 || aiIntervalDays <= 0
        DebugMsg("CreateRecurringDebt_Execute failed — invalid params")
        Return
    EndIf

    ; Duplicate prevention — only one recurring arrangement per creditor+debtor pair
    Int existingIndex = FindRecurringDebt(akCreditor, akDebtor)
    If existingIndex >= 0
        String existingReason = StorageUtil.GetStringValue(self, GetDebtKey(existingIndex, "Reason"), "")
        DebugMsg("CreateRecurringDebt: Duplicate rejected — recurring debt already exists between " + akCreditor.GetDisplayName() + " and " + akDebtor.GetDisplayName() + " for " + existingReason)
        SkyrimNetApi.RegisterEvent("debt_create_failed", akDebtor.GetDisplayName() + " already has a recurring payment arrangement with " + akCreditor.GetDisplayName() + " for " + existingReason, akSpeaker, akCreditor)
        Return
    EndIf

    Float intervalHours = aiIntervalDays as Float * 24.0
    Actor player = Game.GetPlayer()

    ; Build interval description for player prompts
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

    ; Build credit limit info for prompts
    String limitInfo = ""
    If aiCreditLimit > 0
        limitInfo = " Credit limit: " + aiCreditLimit + " gold."
    EndIf

    ; Player confirmation
    If akDebtor == player
        String promptText = akCreditor.GetDisplayName() + " wants you to pay " + aiAmount + " gold " + intervalDesc + " for " + asReason + "." + limitInfo + " Accept?"
        String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")

        If result == "Yes"
            Int debtIndex = AddDebt(akCreditor, akDebtor, aiAmount, asReason, 0.0, true, intervalHours, aiCreditLimit)
            If debtIndex >= 0
                ; Store the per-cycle charge for tick processing
                StorageUtil.SetIntValue(self, GetDebtKey(debtIndex, "RecurringCharge"), aiAmount)
            EndIf
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
            Int debtIndex = AddDebt(akCreditor, akDebtor, aiAmount, asReason, 0.0, true, intervalHours, aiCreditLimit)
            If debtIndex >= 0
                StorageUtil.SetIntValue(self, GetDebtKey(debtIndex, "RecurringCharge"), aiAmount)
            EndIf
            SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " will pay " + akCreditor.GetDisplayName() + " " + aiAmount + " gold " + intervalDesc + " for " + asReason, akCreditor, akDebtor)
        ElseIf result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " declined the payment arrangement", akDebtor)
        Else
            DebugMsg("CreateRecurringDebt: Player silently declined recurring debt from " + akDebtor.GetDisplayName())
        EndIf

    Else
        ; NPC-to-NPC
        Int debtIndex = AddDebt(akCreditor, akDebtor, aiAmount, asReason, 0.0, true, intervalHours, aiCreditLimit)
        If debtIndex >= 0
            StorageUtil.SetIntValue(self, GetDebtKey(debtIndex, "RecurringCharge"), aiAmount)
        EndIf
        SkyrimNetApi.RegisterEvent("debt_created", akDebtor.GetDisplayName() + " will pay " + akCreditor.GetDisplayName() + " " + aiAmount + " gold " + intervalDesc + " for " + asReason, akCreditor, akDebtor)
    EndIf
EndFunction

Function ReduceDebtByPayment(Actor akCollector, Actor akPayer, Int aiAmountPaid)
    {Reduce debts where akCollector is creditor and akPayer is debtor by the paid amount.
     Called automatically by CollectPayment after gold transfers.
     Removes debts that reach 0. Rebuilds summaries and complaint cache.}
    If !akCollector || !akPayer || aiAmountPaid <= 0
        Return
    EndIf

    Int totalOwed = GetAmountOwed(akCollector, akPayer)
    If totalOwed <= 0
        Return ; No debt in this direction
    EndIf

    Int remaining = aiAmountPaid
    If remaining > totalOwed
        remaining = totalOwed
    EndIf

    Int count = GetDebtCount()
    Int i = 0
    While i < count && remaining > 0
        Actor c = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        Actor d = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor

        If c == akCollector && d == akPayer
            Int debtAmount = StorageUtil.GetIntValue(self, GetDebtKey(i, "Amount"), 0)
            If remaining >= debtAmount
                remaining -= debtAmount
                RemoveDebt(i)
                ; After removal, the swapped-in debt is now at index i, so don't increment
                count = GetDebtCount()
            Else
                StorageUtil.SetIntValue(self, GetDebtKey(i, "Amount"), debtAmount - remaining)
                remaining = 0
                ; Rebuild summaries for the partial payment
                RebuildDebtSummary(akCollector)
                RebuildDebtSummary(akPayer)
                i += 1
            EndIf
        Else
            i += 1
        EndIf
    EndWhile

    ; Determine how much debt was actually reduced
    Int actualReduction = aiAmountPaid
    If actualReduction > totalOwed
        actualReduction = totalOwed
    EndIf

    ; Register debt-specific events
    If actualReduction >= totalOwed
        SkyrimNetApi.RegisterEvent("debt_settled", akPayer.GetDisplayName() + " paid off their " + totalOwed + " gold debt with " + akCollector.GetDisplayName(), akCollector, akPayer)
    Else
        Int newTotal = totalOwed - actualReduction
        SkyrimNetApi.RegisterEvent("debt_partial_payment", akPayer.GetDisplayName() + " paid " + actualReduction + " gold toward debt with " + akCollector.GetDisplayName() + " (" + newTotal + " remaining)", akCollector, akPayer)
    EndIf

    ; Rebuild guard complaints in case a reported debt was settled
    RebuildComplaintSummary()
    DebugMsg("ReduceDebtByPayment: " + akPayer.GetDisplayName() + " paid " + actualReduction + "g toward debt with " + akCollector.GetDisplayName() + " (was " + totalOwed + "g)")
EndFunction

Function ForgiveDebt_Execute(Actor akSpeaker, Actor akTarget)
    {Speaker forgives what target owes them. Speaker must be the creditor.}
    If !akSpeaker || !akTarget
        DebugMsg("ForgiveDebt_Execute failed — invalid params")
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int totalOwed = GetAmountOwed(akSpeaker, akTarget)

    If totalOwed <= 0
        DebugMsg("ForgiveDebt: " + akTarget.GetDisplayName() + " doesn't owe " + akSpeaker.GetDisplayName() + " anything")
        SkyrimNetApi.RegisterEvent("debt_forgive_failed", akTarget.GetDisplayName() + " doesn't owe " + akSpeaker.GetDisplayName() + " anything", akSpeaker, akTarget)
        Return
    EndIf

    ; Player confirmation only if player is forgiving (giving up money owed to them)
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

    ; Remove all debts where speaker is creditor and target is debtor
    Int count = GetDebtCount()
    Int i = count - 1
    While i >= 0
        Actor c = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        Actor d = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor

        If c == akSpeaker && d == akTarget
            RemoveDebt(i)
        EndIf

        i -= 1
    EndWhile

    SkyrimNetApi.RegisterEvent("debt_forgiven", akSpeaker.GetDisplayName() + " forgave " + akTarget.GetDisplayName() + "'s debt of " + totalOwed + " gold", akSpeaker, akTarget)
    DebugMsg("ForgiveDebt: " + akSpeaker.GetDisplayName() + " forgave " + totalOwed + "g from " + akTarget.GetDisplayName())

    ; Rebuild guard complaints in case a reported debt was forgiven
    RebuildComplaintSummary()
EndFunction

; =============================================================================
; ACTION: AddToDebt — add charges to an existing debt
; =============================================================================

Function AddToDebt_Execute(Actor akSpeaker, Actor akTarget, Int aiAmount, String asReason)
    {Add charges to an existing debt between speaker and target.
     asReason helps match a specific debt. If empty or no match, uses first debt found.
     Respects credit limits. Player confirmation if player is the debtor.}
    If !akSpeaker || !akTarget || aiAmount <= 0
        DebugMsg("AddToDebt_Execute failed — invalid params")
        Return
    EndIf

    ; Try to find the debt — first by specific reason, then any debt between them
    Int debtIndex = -1

    ; Try both directions: speaker as creditor, or speaker as debtor
    If asReason != ""
        debtIndex = FindDebt(akSpeaker, akTarget, asReason)
        If debtIndex < 0
            debtIndex = FindDebt(akTarget, akSpeaker, asReason)
        EndIf
    EndIf

    ; Fallback: find any debt between the two actors
    If debtIndex < 0
        debtIndex = FindAnyDebt(akSpeaker, akTarget)
    EndIf

    If debtIndex < 0
        DebugMsg("AddToDebt: No debt found between " + akSpeaker.GetDisplayName() + " and " + akTarget.GetDisplayName())
        SkyrimNetApi.RegisterEvent("debt_add_failed", "No existing debt between " + akSpeaker.GetDisplayName() + " and " + akTarget.GetDisplayName() + " to add charges to", akSpeaker, akTarget)
        Return
    EndIf

    ; Read debt details
    Actor creditor = StorageUtil.GetFormValue(self, GetDebtKey(debtIndex, "Creditor"), None) as Actor
    Actor debtor = StorageUtil.GetFormValue(self, GetDebtKey(debtIndex, "Debtor"), None) as Actor
    String reason = StorageUtil.GetStringValue(self, GetDebtKey(debtIndex, "Reason"), "")
    Int currentAmount = StorageUtil.GetIntValue(self, GetDebtKey(debtIndex, "Amount"), 0)
    Int creditLimit = StorageUtil.GetIntValue(self, GetDebtKey(debtIndex, "CreditLimit"), 0)

    ; Check if already at credit limit
    If creditLimit > 0 && currentAmount >= creditLimit
        DebugMsg("AddToDebt: Credit limit already reached on debt #" + debtIndex)
        SkyrimNetApi.RegisterShortLivedEvent( \
            "debt_limit_" + debtIndex, "debt_credit_limit_reached", \
            debtor.GetDisplayName() + " has reached the " + creditLimit + " gold credit limit with " + creditor.GetDisplayName() + " for " + reason, \
            "", 300000, creditor, debtor)
        Return
    EndIf

    Actor player = Game.GetPlayer()

    ; Player confirmation if player is the debtor (being charged more)
    If debtor == player
        String limitStr = ""
        If creditLimit > 0
            limitStr = " (limit: " + creditLimit + "g)"
        EndIf
        String promptText = creditor.GetDisplayName() + " is adding " + aiAmount + " gold to your " + reason + " debt (currently " + currentAmount + "g" + limitStr + "). Accept?"
        String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")

        If result == "No"
            SkyrimNetApi.DirectNarration(player.GetDisplayName() + " refused the additional charge of " + aiAmount + " gold on the " + reason, creditor)
            Return
        ElseIf result != "Yes"
            DebugMsg("AddToDebt: Player silently declined additional charge")
            Return
        EndIf
    EndIf

    ; Apply the increase (ModifyDebtAmount handles credit limit clamping)
    Bool success = ModifyDebtAmount(debtIndex, aiAmount)

    If success
        Int newAmount = StorageUtil.GetIntValue(self, GetDebtKey(debtIndex, "Amount"), 0)
        SkyrimNetApi.RegisterEvent("debt_increased", aiAmount + " gold added to " + debtor.GetDisplayName() + "'s debt with " + creditor.GetDisplayName() + " for " + reason + " (now " + newAmount + "g)", creditor, debtor)
        DebugMsg("AddToDebt: +" + aiAmount + "g on debt #" + debtIndex + " (" + reason + "), now " + newAmount + "g")
    Else
        DebugMsg("AddToDebt: ModifyDebtAmount returned false for debt #" + debtIndex)
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

    ; Find a debt where the giver is the creditor and receiver is the debtor
    ; This is the "tab" pattern: innkeeper (creditor) gives item to player (debtor)
    Int count = GetDebtCount()
    Int bestIndex = -1
    Int i = 0
    While i < count
        Actor c = StorageUtil.GetFormValue(self, GetDebtKey(i, "Creditor"), None) as Actor
        Actor d = StorageUtil.GetFormValue(self, GetDebtKey(i, "Debtor"), None) as Actor

        If c == akGiver && d == akReceiver
            ; Prefer non-recurring debts (one-time tabs) over recurring arrangements
            Int isRecurring = StorageUtil.GetIntValue(self, GetDebtKey(i, "IsRecurring"), 0)
            If isRecurring == 0
                bestIndex = i
                i = count ; Break — found a non-recurring match
            ElseIf bestIndex < 0
                bestIndex = i ; Use recurring as fallback
            EndIf
        EndIf

        i += 1
    EndWhile

    If bestIndex < 0
        ; No matching debt — giver isn't a creditor to receiver, nothing to do
        Return
    EndIf

    ; Check credit limit before adding
    Int currentAmount = StorageUtil.GetIntValue(self, GetDebtKey(bestIndex, "Amount"), 0)
    Int creditLimit = StorageUtil.GetIntValue(self, GetDebtKey(bestIndex, "CreditLimit"), 0)

    If creditLimit > 0 && currentAmount >= creditLimit
        ; Already at limit — don't auto-add
        DebugMsg("AutoAddToDebt: Credit limit already reached, skipping auto-charge of " + goldValue + "g")
        Return
    EndIf

    ; Apply the increase (ModifyDebtAmount handles clamping)
    Bool success = ModifyDebtAmount(bestIndex, goldValue)

    If success
        String reason = StorageUtil.GetStringValue(self, GetDebtKey(bestIndex, "Reason"), "")
        Int newAmount = StorageUtil.GetIntValue(self, GetDebtKey(bestIndex, "Amount"), 0)

        ; Short-lived event so the NPC knows the tab grew
        SkyrimNetApi.RegisterShortLivedEvent( \
            "debt_autocharge_" + bestIndex, "debt_auto_charged", \
            goldValue + " gold added to " + akReceiver.GetDisplayName() + "'s " + reason + " with " + akGiver.GetDisplayName() + " (now " + newAmount + "g)", \
            "", 300000, akGiver, akReceiver)
        DebugMsg("AutoAddToDebt: +" + goldValue + "g on debt #" + bestIndex + " (" + reason + "), now " + newAmount + "g")
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
; UTILITY — GetInstance for Global access from YAML action scripts
; =============================================================================

SeverActions_Debt Function GetInstance() Global
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Debt
EndFunction
