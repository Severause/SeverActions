Scriptname SeverActions_ArrestBounty Extends Quest
{Tracked per-hold bounty in the native BountyStore ('BNTY', keyed by crime
 faction FormID) instead of vanilla CrimeGold, so vanilla guard-arrest dialogue
 never fires on its own and the SeverActions arrest pipeline owns apprehension.
 Hold lookups go to the kernel's HoldResolver. Also hosts the AddBountyToPlayer
 action and paying off an NPC's bounty. Attached to quest 0x000D62.}

SeverActions_Arrest Property ArrestScript Auto
{The main arrest script: DebugMsg and the nine CrimeFaction properties the
 legacy migration drains. Resolved in Maintenance() when the CK leaves it unfilled.}

; --- Lifecycle ---

Function Maintenance()
    {Resolves ArrestScript and registers the bounty-pay popup listener. Called
     from SeverActions_Arrest.Maintenance, which calls MigrateLegacyStorage itself.}
    ; The popup's choice (MagelightBountyPromptBridge). Registered on the load
    ; path: OnInit never re-fires on an existing save.
    RegisterForModEvent("SeverActions_BountyPayChoice", "OnBountyPayChoice")
    If !ArrestScript
        Quest q = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If q
            ArrestScript = q as SeverActions_Arrest
        EndIf
    EndIf
EndFunction

Function MigrateLegacyStorage()
    {One-shot drain of the old "SeverActions_Bounty_<Hold>" StorageUtil keys on
     the player into BountyStore; each drained key is unset. The done flag
     "SeverActions_BountyStore_Migrated" on the quest stops a reload re-draining.
     The flag is set even when nothing drained, so this relies on HoldResolver's
     bounty keys being seeded first (they are, at kDataLoaded).}

    If StorageUtil.GetIntValue(Self, "SeverActions_BountyStore_Migrated", 0) == 1
        Return
    EndIf

    If !ArrestScript
        ; No crime factions to enumerate: leave the migration pending.
        Return
    EndIf

    Actor player = Game.GetPlayer()
    Int migrated = 0

    migrated += DrainLegacyFaction(player, ArrestScript.CrimeFactionWhiterun)
    migrated += DrainLegacyFaction(player, ArrestScript.CrimeFactionRift)
    migrated += DrainLegacyFaction(player, ArrestScript.CrimeFactionHaafingar)
    migrated += DrainLegacyFaction(player, ArrestScript.CrimeFactionEastmarch)
    migrated += DrainLegacyFaction(player, ArrestScript.CrimeFactionReach)
    migrated += DrainLegacyFaction(player, ArrestScript.CrimeFactionFalkreath)
    migrated += DrainLegacyFaction(player, ArrestScript.CrimeFactionPale)
    migrated += DrainLegacyFaction(player, ArrestScript.CrimeFactionHjaalmarch)
    migrated += DrainLegacyFaction(player, ArrestScript.CrimeFactionWinterhold)

    StorageUtil.SetIntValue(Self, "SeverActions_BountyStore_Migrated", 1)

    If migrated > 0
        ArrestScript.DebugMsg("BountyStore migration: drained " + migrated + " legacy hold(s) into native store")
    EndIf
EndFunction

Int Function DrainLegacyFaction(Actor akPlayer, Faction akCrimeFaction)
    {Drains one hold's legacy key into BountyStore and unsets it. Returns 1 when
     a positive value moved, else 0.}
    If akCrimeFaction == None || akPlayer == None
        Return 0
    EndIf

    String storageKey = SeverActionsNativeExt.Hold_GetBountyKeyForCrime(akCrimeFaction)
    If storageKey == ""
        Return 0
    EndIf

    Int legacy = StorageUtil.GetIntValue(akPlayer, storageKey, 0)
    StorageUtil.UnsetIntValue(akPlayer, storageKey)

    If legacy > 0
        SeverActionsNativeExt.Native_Bounty_Set(akCrimeFaction, legacy)
        Return 1
    EndIf
    Return 0
EndFunction

; --- Tracked bounty: wrappers over the native BountyStore ---
; The store drops an entry whose amount falls to <= 0.

Int Function GetTrackedBounty(Faction akCrimeFaction)
    {Get the tracked bounty for a crime faction (not vanilla crime gold).}

    If akCrimeFaction == None
        Return 0
    EndIf
    Return SeverActionsNativeExt.Native_Bounty_Get(akCrimeFaction)
EndFunction

Function SetTrackedBounty(Faction akCrimeFaction, Int aiAmount)
    {Sets the tracked bounty; zero or negative clears the entry.}

    If akCrimeFaction == None
        Return
    EndIf
    SeverActionsNativeExt.Native_Bounty_Set(akCrimeFaction, aiAmount)
EndFunction

Function ModTrackedBounty(Faction akCrimeFaction, Int aiAmount)
    {Adds aiAmount to the tracked bounty (read-modify-write under the store's
     mutex, so concurrent witness events do not race).}

    If akCrimeFaction == None
        Return
    EndIf
    SeverActionsNativeExt.Native_Bounty_Mod(akCrimeFaction, aiAmount)
EndFunction

Function ClearTrackedBounty(Faction akCrimeFaction)
    {Clear the tracked bounty for a crime faction.}

    If akCrimeFaction == None
        Return
    EndIf
    SeverActionsNativeExt.Native_Bounty_Clear(akCrimeFaction)
EndFunction

Function ApplyTrackedBountyToVanilla(Faction akCrimeFaction)
    {Moves the tracked bounty into vanilla crime gold, for the vanilla paths
     that need CrimeGold (resist-arrest combat, the vanilla jail).}

    Int bounty = GetTrackedBounty(akCrimeFaction)
    If bounty > 0
        ; ADD, never Set: the engine may already hold witnessed bounty for this
        ; faction. The tracked bounty is one non-violent pool, so violent crime
        ; gold is left alone.
        akCrimeFaction.ModCrimeGold(bounty)
        ClearTrackedBounty(akCrimeFaction)
        If ArrestScript
            ArrestScript.DebugMsg("Applied " + bounty + " tracked bounty to vanilla system")
        EndIf
    EndIf
EndFunction

Int Function GetTrackedBountyForGuard(Actor akGuard)
    {Tracked bounty for the hold a guard belongs to. Asks the kernel HoldResolver
     directly, so it does not depend on ArrestScript being resolved.}

    Faction crimeFaction = SeverActionsNativeExt.Hold_GetCrimeFaction(akGuard)
    If crimeFaction
        Return GetTrackedBounty(crimeFaction)
    EndIf
    Return 0
EndFunction

; --- SkyrimNet action (addbountytoplayer.yaml) ---

String Function NormalizeCrimeType(String asRaw)
    {Maps an LLM crime label onto addbountytoplayer.yaml's enum (assault, theft,
     murder, trespass, pickpocket, contempt, abuse_of_power) so qualifiers such
     as "murder spree" never reach persistent memory. Substring match; anything
     unrecognised becomes "assault".}

    If asRaw == "" || asRaw == "None"
        Return "assault"
    EndIf
    String lc = asRaw  ; no ToLower: each token is tested lower-case and capitalised
    If StringUtil.Find(lc, "abuse") >= 0 || StringUtil.Find(lc, "Abuse") >= 0
        Return "abuse_of_power"
    EndIf
    If StringUtil.Find(lc, "murder") >= 0 || StringUtil.Find(lc, "Murder") >= 0 || StringUtil.Find(lc, "kill") >= 0 || StringUtil.Find(lc, "Kill") >= 0
        Return "murder"
    EndIf
    If StringUtil.Find(lc, "pickpocket") >= 0 || StringUtil.Find(lc, "Pickpocket") >= 0
        Return "pickpocket"
    EndIf
    If StringUtil.Find(lc, "trespass") >= 0 || StringUtil.Find(lc, "Trespass") >= 0
        Return "trespass"
    EndIf
    If StringUtil.Find(lc, "theft") >= 0 || StringUtil.Find(lc, "Theft") >= 0 || StringUtil.Find(lc, "steal") >= 0 || StringUtil.Find(lc, "Steal") >= 0
        Return "theft"
    EndIf
    If StringUtil.Find(lc, "contempt") >= 0 || StringUtil.Find(lc, "Contempt") >= 0 || StringUtil.Find(lc, "disrespect") >= 0 || StringUtil.Find(lc, "Disrespect") >= 0
        Return "contempt"
    EndIf
    If StringUtil.Find(lc, "assault") >= 0 || StringUtil.Find(lc, "Assault") >= 0 || StringUtil.Find(lc, "attack") >= 0 || StringUtil.Find(lc, "Attack") >= 0 || StringUtil.Find(lc, "batter") >= 0 || StringUtil.Find(lc, "Batter") >= 0
        Return "assault"
    EndIf
    Return "assault"
EndFunction

Function AddBountyToPlayer_Internal(Actor akGuard, Int bountyAmount, String crimeType)
    {A guard adds bounty for a crime they saw. Uses the tracked bounty, not
     vanilla crime gold, so vanilla arrest dialogue stays quiet. crimeType goes
     through NormalizeCrimeType.}

    If !ArrestScript
        ; The rest logs through ArrestScript.DebugMsg: fail loudly so a missing
        ; back-reference shows.
        Debug.Trace("[SeverActions_ArrestBounty] ERROR: ArrestScript reference is None")
        Return
    EndIf

    If akGuard == None
        ArrestScript.DebugMsg("ERROR: AddBountyToPlayer called with None guard")
        Return
    EndIf

    If bountyAmount <= 0
        ArrestScript.DebugMsg("ERROR: Invalid bounty amount")
        Return
    EndIf

    Faction crimeFaction = SeverActionsNativeExt.Hold_GetCrimeFaction(akGuard)

    If crimeFaction == None
        ArrestScript.DebugMsg("WARNING: Could not determine guard's crime faction")
        Return
    EndIf

    String normalizedCrime = NormalizeCrimeType(crimeType)

    ModTrackedBounty(crimeFaction, bountyAmount)

    String holdName = SeverActionsNativeExt.Hold_GetHoldName(akGuard)
    If holdName == ""
        holdName = "unknown hold"
    EndIf

    ; The store's event ring is bounded (32 rows per faction, FIFO).
    SeverActionsNativeExt.Native_Bounty_AddEvent(crimeFaction, bountyAmount, normalizedCrime, holdName)

    Int totalBounty = GetTrackedBounty(crimeFaction)
    ArrestScript.DebugMsg("Added " + bountyAmount + " tracked bounty for " + normalizedCrime + " in " + holdName + " (total: " + totalBounty + ")")
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrestbounty.bountyAdded", ("" + bountyAmount), ("" + holdName)))

    String eventMsg = akGuard.GetDisplayName() + " witnessed " + Game.GetPlayer().GetDisplayName() + " commit " + normalizedCrime + " and added " + bountyAmount + " gold to their bounty in " + holdName + ". Total bounty is now " + totalBounty + " gold."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, Game.GetPlayer())
EndFunction

Function PayNpcBountyToGuard_Internal(Actor akGuard, String offenderName)
    {The player pays off a NAMED offender's bounty through a hold authority: a
     follower's or NPC's tracked bounty, or an Enterprises fence's illicit
     bounty. The native resolves the name in this guard's hold, so the offender
     need not be present. Confirms through a non-pausing popup when one can open.}
    If akGuard == None || offenderName == ""
        Return
    EndIf
    Actor player = Game.GetPlayer()
    Int owed = SeverActionsNativeExt.Native_ResolveHoldBountyByName(akGuard, offenderName)
    If owed <= 0
        SkyrimNetApi.RegisterEvent("bounty_pay_none",             akGuard.GetDisplayName() + " checks the books: no one named " + offenderName + " carries a bounty in this hold. There is nothing to pay off.",             akGuard, player)
        Return
    EndIf

    ; The choice ModEvent carries only the guard and amount, so the offender
    ; name waits on the guard.
    StorageUtil.SetStringValue(akGuard, "SeverBounty_PendingOffender", offenderName)

    ; When the popup cannot open (no UI host, another view focused, a prompt
    ; already open) pay directly.
    RegisterForModEvent("SeverActions_BountyPayChoice", "OnBountyPayChoice")
    If SeverActionsNativeExt.Magelight_IsBountyPromptAvailable()         && SeverActionsNativeExt.Magelight_OpenBountyPrompt(akGuard, owed, offenderName, 20000)
        Return   ; choice arrives via OnBountyPayChoice
    EndIf
    StorageUtil.UnsetStringValue(akGuard, "SeverBounty_PendingOffender")
    _DoPayBounty(akGuard, offenderName)
EndFunction

Event OnBountyPayChoice(String asEventName, String asChoice, Float afAmount, Form akSender)
    {The player confirmed or declined the bounty-pay popup. sender = the guard.}
    Actor guard = akSender as Actor
    If guard == None
        Return
    EndIf
    String offenderName = StorageUtil.GetStringValue(guard, "SeverBounty_PendingOffender", "")
    StorageUtil.UnsetStringValue(guard, "SeverBounty_PendingOffender")
    If asChoice == "accept" && offenderName != ""
        _DoPayBounty(guard, offenderName)
    EndIf
EndEvent

Function _DoPayBounty(Actor akGuard, String offenderName)
    {Commits the payment (popup accept or the no-popup path). The native
     returns >0 paid, 0 no match, -1 cannot afford.}
    Actor player = Game.GetPlayer()
    Int paid = SeverActionsNativeExt.Native_PayHoldBountyByName(akGuard, offenderName)
    If paid > 0
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrestbounty.paidOff", ("" + offenderName), ("" + paid)))
        String msg = player.GetDisplayName() + " paid off " + offenderName + "'s bounty of " + paid + " gold to " + akGuard.GetDisplayName() + ". The law has no more claim on them in this hold."
        SkyrimNetApi.RegisterPersistentEvent(msg, akGuard, player)
    ElseIf paid < 0
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("arrestbounty.cantAfford", ("" + offenderName)))
        SkyrimNetApi.RegisterEvent("bounty_pay_failed",             player.GetDisplayName() + " offered to pay off " + offenderName + "'s bounty but does not have the coin on hand. " + akGuard.GetDisplayName() + " turns them away until they do.",             akGuard, player)
    EndIf
EndFunction