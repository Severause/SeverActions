Scriptname SeverActions_ArrestBounty Extends Quest
{Tracked-bounty subsystem (Wave 5b extraction, migrated to BountyStore).

 Stores per-hold bounty separately from vanilla CrimeGold so that vanilla
 guard-arrest dialogue does NOT trigger on its own — the SeverActions arrest
 pipeline owns the apprehension flow.

 Storage backend: cosave-backed native BountyStore (record 'BNTY'), keyed by
 the crime faction's FormID. Replaces the previous StorageUtil-on-player
 layer ("SeverActions_Bounty_<Hold>" keys), which was migrated on first load
 after the BountyStore landing — see MigrateLegacyStorage() below.

 Extracted from SeverActions_Arrest.psc to keep that file's FSM concerns
 isolated from this purely-data subsystem. Crime faction properties + the
 GetCrimeFactionForGuard / GetHoldNameForGuard helpers REMAIN on the arrest
 script because they're shared by dispatch / jail / persuasion logic;
 BountyScript reaches them via the ArrestScript back-reference below.

 Public API (also exposed via the AddBountyToPlayer YAML action):
   - GetBountyStorageKey, GetTrackedBounty, SetTrackedBounty,
     ModTrackedBounty, ClearTrackedBounty, ApplyTrackedBountyToVanilla
   - GetTrackedBountyForGuard
   - AddBountyToPlayer_Internal

 Attached to the same SeverActions quest (FormID 0x000D62) as every other
 sub-script. Resolve via `quest as SeverActions_ArrestBounty` from any
 caller — no explicit CK property fill is strictly required, only the
 ArrestScript back-reference below.}

; =============================================================================
; SCRIPT REFERENCES
; =============================================================================

SeverActions_Arrest Property ArrestScript Auto
{Back-reference to the main arrest script — needed to read the
 CrimeFactionWhiterun / GetCrimeFactionForGuard / GetHoldNameForGuard /
 DebugMsg helpers that legitimately stay on the parent FSM. Filled at
 runtime via Maintenance(); CK fill optional.}

; =============================================================================
; LIFECYCLE
; =============================================================================

Function Maintenance()
    {Resolve the ArrestScript back-reference at runtime if CK didn't fill it.
     Called from the parent SeverActions_Arrest.Maintenance after that script
     finishes its own setup so we know the parent is alive.

     IMPORTANT: this function does NOT run the legacy-storage migration.
     The drain in MigrateLegacyStorage() resolves hold metadata via
     SeverActionsNativeExt.Hold_GetBountyKeyForCrime(), which depends on
     ArrestScript's Hold_Register chain having run first. Since
     SeverActions_Arrest.Maintenance() calls THIS function (line ~630)
     BEFORE its Hold_Register block (line ~665), running the migration
     here would see an empty HoldResolver, silently no-op the drain for
     every faction, still commit the sentinel, and permanently lose the
     legacy bounty data.

     ArrestScript.Maintenance() invokes MigrateLegacyStorage() explicitly
     AFTER its Hold_Register chain completes — that's the safe site.}
    If !ArrestScript
        Quest q = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
        If q
            ArrestScript = q as SeverActions_Arrest
        EndIf
    EndIf
EndFunction

Function MigrateLegacyStorage()
    {One-shot drain of the pre-BountyStore StorageUtil keys
     ("SeverActions_Bounty_<Hold>" on the player) into the native
     BountyStore. Idempotent — the second call is guarded by a quest-level
     flag so reloads don't re-drain anything the user has legitimately
     cleared since.

     Per-faction algorithm:
       1. Read the legacy StorageUtil value on the player.
       2. If non-zero, push it into BountyStore.Set (which auto-clears
          when amount drops to <= 0, so 0/negative values silently no-op).
       3. Unset the legacy key so subsequent reads through the new path
          don't accidentally double-count.

     Migration completion flag lives on Self (the quest) under
     "SeverActions_BountyStore_Migrated" so it persists with the quest
     state rather than the player container.}

    If StorageUtil.GetIntValue(Self, "SeverActions_BountyStore_Migrated", 0) == 1
        Return
    EndIf

    If !ArrestScript
        ; Without ArrestScript we can't enumerate the crime factions — try
        ; again on the next maintenance tick. Don't set the flag so the
        ; migration stays pending.
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
    {Drain one legacy StorageUtil key into BountyStore. Returns 1 if a
     non-zero value was migrated, 0 otherwise. Helper for MigrateLegacyStorage
     above — kept private-by-convention (Papyrus has no access modifiers).}
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

; =============================================================================
; STORAGE-KEY MAP
; =============================================================================

String Function GetBountyStorageKey(Faction akCrimeFaction)
    {Get the legacy StorageUtil key name for a crime faction.

     Retained for migration/diagnostic purposes only — live reads and writes
     now go through BountyStore via the CRUD functions below. The string this
     returns no longer corresponds to any value Papyrus reads; it just names
     the legacy slot for log lines and the one-shot migration in
     MigrateLegacyStorage() above.}

    Return SeverActionsNativeExt.Hold_GetBountyKeyForCrime(akCrimeFaction)
EndFunction

; =============================================================================
; CRUD — thin delegations to the native BountyStore
; =============================================================================
;
; All four operate by crime-faction FormID under the hood. The native side
; auto-removes entries when the amount drops to <= 0, so the same "no key
; when zero" invariant the legacy StorageUtil path maintained is preserved
; without any explicit unset dance on this side.

Int Function GetTrackedBounty(Faction akCrimeFaction)
    {Get the tracked bounty for a crime faction (not vanilla crime gold).}

    If akCrimeFaction == None
        Return 0
    EndIf
    Return SeverActionsNativeExt.Native_Bounty_Get(akCrimeFaction)
EndFunction

Function SetTrackedBounty(Faction akCrimeFaction, Int aiAmount)
    {Set the absolute tracked bounty for a crime faction. Negative or zero
     clears the entry in the native store.}

    If akCrimeFaction == None
        Return
    EndIf
    SeverActionsNativeExt.Native_Bounty_Set(akCrimeFaction, aiAmount)
EndFunction

Function ModTrackedBounty(Faction akCrimeFaction, Int aiAmount)
    {Atomically add aiAmount to the tracked bounty for a crime faction.
     The native store handles the read-modify-write under its own mutex,
     so concurrent guard-witness events no longer race on the StorageUtil
     read.}

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
    {Transfer tracked bounty to vanilla crime gold (for jail/combat).
     Used at the moment we hand off to vanilla code paths that need
     CrimeGold to be present (resist-arrest combat, vanilla jail menu).}

    Int bounty = GetTrackedBounty(akCrimeFaction)
    If bounty > 0
        akCrimeFaction.SetCrimeGold(bounty)
        ClearTrackedBounty(akCrimeFaction)
        If ArrestScript
            ArrestScript.DebugMsg("Applied " + bounty + " tracked bounty to vanilla system")
        EndIf
    EndIf
EndFunction

Int Function GetTrackedBountyForGuard(Actor akGuard)
    {Get the tracked bounty for the hold a guard belongs to.}

    If !ArrestScript
        Return 0
    EndIf
    Faction crimeFaction = ArrestScript.GetCrimeFactionForGuard(akGuard)
    If crimeFaction
        Return GetTrackedBounty(crimeFaction)
    EndIf
    Return 0
EndFunction

; =============================================================================
; ACTION ENTRY POINT — wired via addbountytoplayer.yaml
; =============================================================================

String Function NormalizeCrimeType(String asRaw)
    {Map an LLM-supplied crime label onto the canonical 7-value enum from
     addbountytoplayer.yaml: assault, theft, murder, trespass, pickpocket,
     contempt, abuse_of_power.

     LLMs append qualifiers ("murder spree", "assault and battery", "petty
     theft") and the previous code path concatenated those verbatim into
     SkyrimNetApi.RegisterPersistentEvent, polluting persistent memory.
     Match on substring against canonical tokens; fall back to "assault"
     so the event still narrates sensibly rather than leaking the raw
     unknown string into long-term memory.}

    If asRaw == "" || asRaw == "None"
        Return "assault"
    EndIf
    String lc = asRaw  ; Papyrus has no ToLower; rely on substring tolerance
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
    {Guard adds bounty to player for an observed crime.
     Uses tracked bounty system instead of vanilla crime gold to prevent
     vanilla guard arrest dialogue from triggering.
     crimeType is normalized to one of: assault, theft, murder, trespass,
     pickpocket, contempt, abuse_of_power (see NormalizeCrimeType).}

    If !ArrestScript
        ; Without ArrestScript we can't resolve faction or hold name; bail
        ; loudly so a CK misconfiguration is visible at runtime.
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

    ; Determine which crime faction based on guard
    Faction crimeFaction = ArrestScript.GetCrimeFactionForGuard(akGuard)

    If crimeFaction == None
        ArrestScript.DebugMsg("WARNING: Could not determine guard's crime faction")
        Return
    EndIf

    ; Normalize the LLM-supplied label before it touches persistent memory.
    String normalizedCrime = NormalizeCrimeType(crimeType)

    ; Add to tracked bounty (NOT vanilla crime gold - keeps vanilla at 0)
    ModTrackedBounty(crimeFaction, bountyAmount)

    String holdName = ArrestScript.GetHoldNameForGuard(akGuard)

    ; Ledger expansion Phase 4 — log the crime as a BountyStore event row.
    ; The event ring is bounded per faction (32 entries, FIFO) so a
    ; rampage-prone playthrough won't unbound-grow the cosave.
    SeverActionsNativeExt.Native_Bounty_AddEvent(crimeFaction, bountyAmount, normalizedCrime, holdName)

    Int totalBounty = GetTrackedBounty(crimeFaction)
    ArrestScript.DebugMsg("Added " + bountyAmount + " tracked bounty for " + normalizedCrime + " in " + holdName + " (total: " + totalBounty + ")")
    Debug.Notification("Bounty added: " + bountyAmount + " gold in " + holdName)

    ; Register persistent event so NPCs remember this crime
    String eventMsg = akGuard.GetDisplayName() + " witnessed the player commit " + normalizedCrime + " and added " + bountyAmount + " gold to their bounty in " + holdName + ". Total bounty is now " + totalBounty + " gold."
    SkyrimNetApi.RegisterPersistentEvent(eventMsg, akGuard, Game.GetPlayer())
EndFunction
