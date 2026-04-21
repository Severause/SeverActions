Scriptname SeverActions_Follow extends Quest
{Multi-follower system with two distinct follow modes:

 1. Casual Follow (StartFollowing/StopFollowing) — uses SkyrimNet's built-in follow package
    via RegisterPackage. For guards, random NPCs, anyone the LLM decides should follow
    temporarily. No alias slots, no LinkedRef, no persistence across save/load.

 2. Companion Follow (CompanionStartFollowing/CompanionStopFollowing) — uses our CK alias-based
    follow package. For formal companions recruited through SetCompanion. Alias slot + LinkedRef
    + package attached to alias. Persists across save/load natively (only LinkedRef needs reapply).}

; =============================================================================
; PROPERTIES
; =============================================================================

int Property FollowPackagePriority = 50 AutoReadOnly
{Priority for SkyrimNet's casual follow package. Kept low so it doesn't
overtake important packages from other mods. Companions use CK alias
packages instead which don't use this priority.}

ReferenceAlias[] Property FollowerSlots Auto
{Array of 20 ReferenceAlias slots for companion follow package persistence.
Each alias has SeverActions_FollowPlayerPackage attached in CK.
When ForceRefTo fills an alias, the follow package auto-applies.
Alias state persists in save data, so packages survive save/load.}

Keyword Property SeverActions_FollowerFollowKW Auto
{Dedicated keyword for companion linked ref targeting. Created in CK for this system only.
Set on companion pointing to the player, so FollowPlayerPackage knows who to follow.}

Faction Property SeverActions_ActivelyFollowing Auto
{Dynamic faction: added when a companion is actively following the player,
removed when they wait, sandbox, stop following, or get dismissed.
Used by SkyrimNet target selector prompts to identify engaged companions
who should have a lower threshold to speak in conversations.
Create in CK — just a new faction, no special setup needed.}

Faction Property SeverActions_WaitingFaction Auto
{Dynamic faction: added when an NPC is told to wait (sandbox in place).
Removed when they resume following. Allows other mods like IntelEngine
to blacklist waiting NPCs from seeking out the player.
Create in CK — just a new faction, no special setup needed.}

Package Property SandboxPackage Auto
{Manual sandbox package (wait/sandbox action) for relaxing in place — NPC wanders
and interacts with nearby furniture.}

Package Property SafeInteriorSandboxPackage Auto
{Distinct sandbox package for AUTO safe-interior sandbox (entering inns, player
homes, etc.). Lets users visually tell the two flows apart when debugging which
package is active. Falls back to SandboxPackage if not assigned in CK.}

int Property SandboxPackagePriority = 55 AutoReadOnly
{Above follow (50) so sandbox overrides the FollowPlayer package immediately.
 SkyrimNet's UnregisterPackage is queued/async in 0.15.4+, so the FollowPlayer
 package may still be active when sandbox is applied. Priority 55 ensures
 sandbox wins without waiting for the queue. All cleanup paths (StopSandbox,
 OnNativeSandboxCleanup, StartFollowing, CompanionStartFollowing) explicitly
 remove the sandbox package override, so orphans are handled properly.}

float Property SandboxAutoStandDistance = 2000.0 Auto
{Distance at which sandboxing actors auto-resume following when player moves away}

int Property SafeInteriorSandboxPriority = 55 AutoReadOnly
{Same priority as regular sandbox — overrides follow package.}

; =============================================================================
; INIT
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Follow] Initialized")
    RegisterForModEvent("SeverActionsNative_SandboxCleanup", "OnNativeSandboxCleanup")
    RegisterForModEvent("SeverActions_SafeInteriorReEval", "OnSafeInteriorReEval")
EndEvent

; Resolve which sandbox package to use for auto safe-interior. Prefers the distinct
; SafeInteriorSandboxPackage (Phase 5 Fix D) so users can visually tell the manual
; wait sandbox and the auto safe-interior sandbox apart. Falls back to the shared
; SandboxPackage when SafeInteriorSandboxPackage isn't assigned in CK.
Package Function GetSafeInteriorPackage()
    If SafeInteriorSandboxPackage
        Return SafeInteriorSandboxPackage
    EndIf
    Return SandboxPackage
EndFunction

; Called on game load to re-register events and restore state
Function Maintenance()
    RegisterForModEvent("SeverActionsNative_SandboxCleanup", "OnNativeSandboxCleanup")
    RegisterForModEvent("SeverActions_SafeInteriorChanged", "OnSafeInteriorChanged")
    RegisterForModEvent("SeverActions_SafeInteriorToggle", "OnSafeInteriorToggle")
    RegisterForModEvent("SeverActions_PauseOnOpenToggle",  "OnPauseOnOpenToggle")
    RegisterForModEvent("SeverActions_FriendlyFireToggle", "OnFriendlyFireToggle")
    ; Phase 5 Fix C — deferred safe-interior re-evaluation: C++ fires this ~500ms
    ; after the initial enter event so the engine picks up our override even if the
    ; first EvaluatePackage raced with a cell transition / AI busy state.
    RegisterForModEvent("SeverActions_SafeInteriorReEval", "OnSafeInteriorReEval")

    ; Restore safe interior sandbox setting from StorageUtil → push to C++
    Quest SeverActionsQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    If SeverActionsQuest
        ; Phase 10 — default to DISABLED (0) if key never written. The feature
        ; races with Skyrim's door-transition timing in ways that cause
        ; FF runtime fallback packages and exit stickiness. Users who want it
        ; can enable via PrismaUI. Existing users who had it on keep their
        ; setting — the StorageUtil key persists across game loads.
        Bool savedEnabled = StorageUtil.GetIntValue(SeverActionsQuest, "SeverActions_SafeInteriorEnabled", 0) == 1
        SeverActionsNative.SituationMonitor_SetSafeInteriorEnabled(savedEnabled)
        Debug.Trace("[SeverActions_Follow] Restored safe interior sandbox: " + savedEnabled)

        ; Restore PrismaUI pause-on-open setting. Default 1 (paused) preserves legacy
        ; behavior — only users who have explicitly disabled it see the unpaused path.
        Bool savedPauseOnOpen = StorageUtil.GetIntValue(SeverActionsQuest, "SeverActions_PauseOnOpen", 1) == 1
        SeverActionsNative.PrismaUI_SetPauseOnOpen(savedPauseOnOpen)
        Debug.Trace("[SeverActions_Follow] Restored PrismaUI pause on open: " + savedPauseOnOpen)

        ; Restore follower friendly-fire prevention. Default 1 (enabled) —
        ; users who have explicitly disabled it keep their 0 in StorageUtil;
        ; everyone else gets protection on by default. When on, also re-apply
        ; the raised ally-hit thresholds since game settings reset to ESP/INI
        ; defaults on load and we can't cosave them.
        Bool savedFriendlyFire = StorageUtil.GetIntValue(SeverActionsQuest, "SeverActions_PreventFollowerFF", 1) == 1
        SeverActionsNative.FriendlyFireMonitor_SetEnabled(savedFriendlyFire)
        If savedFriendlyFire
            Game.SetGameSettingInt("iAllyHitCombatAllowed", 100)
            Game.SetGameSettingInt("iAllyHitNonCombatAllowed", 50)
        EndIf
        Debug.Trace("[SeverActions_Follow] Restored follower friendly-fire prevention: " + savedFriendlyFire)
    EndIf
EndFunction

; =============================================================================
; SANDBOX STATE HELPERS
; StorageUtil-based tracking replaces the broken SkyrimNetApi.HasPackage("Sandbox").
; "Sandbox" isn't in SkyrimNet's PackageFormCache, so RegisterPackage always fails
; and HasPackage returns false. StorageUtil flags are immediate and reliable.
; =============================================================================

Bool Function IsSandboxing(Actor akActor)
    return akActor && StorageUtil.GetIntValue(akActor, "SeverActions_IsSandboxing") == 1
EndFunction

Function SetSandboxFlag(Actor akActor, Bool active)
    If active
        StorageUtil.SetIntValue(akActor, "SeverActions_IsSandboxing", 1)
    Else
        StorageUtil.UnsetIntValue(akActor, "SeverActions_IsSandboxing")
    EndIf
    SeverActionsNative.Native_SetSandboxing(akActor, active)
EndFunction

; =============================================================================
; NATIVE SANDBOX CLEANUP EVENT HANDLER
; Called by native SandboxManager when player changes cells or moves too far
; =============================================================================

Event OnNativeSandboxCleanup(string eventName, string strArg, float numArg, Form sender)
    Actor akActor = sender as Actor
    if !akActor
        akActor = Game.GetFormEx(numArg as int) as Actor
    endif

    if !akActor
        return
    endif

    ; Only handle actors that are sandboxing through our system
    if !IsSandboxing(akActor)
        return
    endif

    Debug.Trace("[SeverActions_Follow] Native sandbox cleanup for: " + akActor.GetDisplayName())

    ; Clear waiting state FIRST — so the follow package becomes eligible
    ; before the sandbox override is removed, preventing FF-prefix runtime sandbox.
    akActor.SetAV("WaitingForPlayer", 0)

    ; Clear sandbox state
    SetSandboxFlag(akActor, false)

    ; Now safe to remove sandbox package
    if SandboxPackage
        ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
    endif

    ; Back to actively following — AI resumes follow naturally, no forced eval
    SetActivelyFollowing(akActor, true)

    Debug.Notification(akActor.GetDisplayName() + " stopped relaxing.")
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " stops relaxing and catches up with " + Game.GetPlayer().GetDisplayName() + ".", akActor, Game.GetPlayer())
EndEvent

; =============================================================================
; SAFE INTERIOR AUTO-SANDBOX
; Fired by native SituationMonitor when a following companion enters/exits
; a safe interior (inn, home, shop, temple, town interior).
; =============================================================================

Event OnSafeInteriorChanged(String eventName, String strArg, Float numArg, Form sender)
    ; strArg format: "enter|0xFormID" or "exit|0xFormID"
    Int pipePos = StringUtil.Find(strArg, "|")
    If pipePos < 0
        Return
    EndIf

    String changeType = StringUtil.Substring(strArg, 0, pipePos)
    String formIdStr = StringUtil.Substring(strArg, pipePos + 1)
    Int formId = SeverActionsNative.HexToInt(formIdStr)
    Actor akActor = Game.GetForm(formId) as Actor
    If !akActor
        Return
    EndIf

    ; Don't override manual sandbox/wait commands or home-sandboxing NPCs
    If akActor.GetAV("WaitingForPlayer") > 0
        Return
    EndIf
    ; Skip dismissed NPCs sandboxing at home — they're not active followers,
    ; the safe interior system shouldn't touch their home sandbox package.
    ; Active followers with homes assigned should still get safe interior sandbox.
    If SeverActionsNative.Native_GetHomeMarkerSlot(akActor) >= 0
        SeverActions_FollowerManager fm = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
        If fm && !fm.IsRegisteredFollower(akActor)
            Return
        EndIf
    EndIf

    If changeType == "enter"
        Package interiorPkg = GetSafeInteriorPackage()
        If interiorPkg && !IsSandboxing(akActor)
            ; Phase 5 Fix A — match manual Sandbox() ordering so casual followers'
            ; SkyrimNet package doesn't race with our override (SkyrimNet's hook
            ; returns its own FollowPlayer regardless of PO3 priority, causing
            ; the FE/FF fallback when the follower is in a door transition).
            ;
            ; Apply override FIRST so there's always a valid high-priority package.
            ActorUtil.AddPackageOverride(akActor, interiorPkg, SafeInteriorSandboxPriority, 1)

            ; Kill the SkyrimNet FollowPlayer registration for casual followers.
            ; Safe no-op for companions (they use CK alias package, not SkyrimNet).
            SkyrimNetApi.UnregisterPackage(akActor, "FollowPlayer")

            ; Kill the CK alias follow package's eligibility condition
            ; (SeverActions_FollowPlayerPackage gates on WaitingForPlayer == 0).
            akActor.SetAV("WaitingForPlayer", 1)

            SetSandboxFlag(akActor, true)
            StorageUtil.SetIntValue(akActor, "SeverActions_InSafeInteriorSandbox", 1)
            SeverActionsNative.Native_SetSandboxing(akActor, true)
            SetActivelyFollowing(akActor, false)

            ; (Phase 7 note: we used to write SeverActions_SafeInteriorPkgMode
            ; here to remember which package variant was applied, but the exit
            ; path always removes BOTH variants in a multi-remove loop so the
            ; stored mode was never read. Dropped — the round-trip was dead.)

            ; Add the waiting faction so other mods (IntelEngine, etc.) treat
            ; a safe-interior-sandboxing follower the same way they treat a
            ; manually waiting one — consistent external signal.
            If SeverActions_WaitingFaction
                akActor.AddToFaction(SeverActions_WaitingFaction)
            EndIf

            akActor.EvaluatePackage()
            Debug.Trace("[SeverActions_Follow] Safe interior sandbox: " + akActor.GetDisplayName() + " is relaxing")
        EndIf
    ElseIf changeType == "exit"
        If StorageUtil.GetIntValue(akActor, "SeverActions_InSafeInteriorSandbox", 0) == 1
            StorageUtil.UnsetIntValue(akActor, "SeverActions_InSafeInteriorSandbox")
            SetSandboxFlag(akActor, false)
            SeverActionsNative.Native_SetSandboxing(akActor, false)

            ; Phase 7 — aggressive multi-remove.
            ; User testing of Phase 6 found that `resetai` on a stuck companion
            ; returns them to the sandbox package and they walk back inside.
            ; That means the sandbox override is STILL on the actor after a
            ; single RemovePackageOverride — either because the enter path
            ; fired multiple times (SituationMonitor flap across door threshold),
            ; or the engine's ExtraPackage state held on to the reference past
            ; the first removal, or some other cause we haven't yet isolated.
            ;
            ; Calling RemovePackageOverride multiple times is cheap, safe (no-op
            ; when already removed), and covers all the failure modes: we do
            ; both package variants, multiple iterations, so any lingering stack
            ; is gone by the time we hand control back to the AI.
            Int removeIter = 0
            While removeIter < 5
                If SafeInteriorSandboxPackage
                    ActorUtil.RemovePackageOverride(akActor, SafeInteriorSandboxPackage)
                EndIf
                If SandboxPackage
                    ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
                EndIf
                removeIter += 1
            EndWhile

            ; Clear WaitingForPlayer FIRST so the CK alias follow package's
            ; condition becomes valid before we re-register SkyrimNet follow,
            ; preventing an engine fallback in the gap.
            akActor.SetAV("WaitingForPlayer", 0)

            ; Remove waiting faction
            If SeverActions_WaitingFaction
                akActor.RemoveFromFaction(SeverActions_WaitingFaction)
            EndIf

            ; Re-register SkyrimNet follow for casual followers only.
            ; Companions use CK alias and don't need re-registration.
            If !IsInFollowerSlot(akActor)
                SkyrimNetApi.RegisterPackage(akActor, "FollowPlayer", FollowPackagePriority, 0, true)
            Else
                ; Phase 8 Fix B — companion-specific re-assertion.
                ; User reported that even after Phase 7's multi-remove + resetAI,
                ; the companion could still walk back to the home because the
                ; SandboxPackage was STILL on them — and `SetCompanion` action
                ; was the only thing that reliably recovered them.
                ;
                ; SetCompanion does two things our exit path wasn't doing:
                ; re-setting the FollowerFollowKW LinkedRef to player, and
                ; re-registering OrphanCleanup_RegisterFollower. Both are
                ; defensive — but both matter because safe-interior enter/exit
                ; cycles can leave the CK alias follow package without a valid
                ; LinkedRef target, making it non-eligible. Re-setting forces
                ; the alias package into eligibility just like SetCompanion does.
                If SeverActions_FollowerFollowKW
                    SeverActionsNative.LinkedRef_Set(akActor, Game.GetPlayer(), SeverActions_FollowerFollowKW)
                EndIf
                SeverActionsNative.OrphanCleanup_RegisterFollower(akActor)
            EndIf

            SetActivelyFollowing(akActor, true)
            ; Teleport to player so they don't get stuck inside the house
            akActor.MoveTo(Game.GetPlayer())

            ; Phase 7 — escalating re-eval chain (immediate + 500ms + 1000ms resetAI).
            ; The follower is teleported-adjacent to the player at this point
            ; and not in combat (they were safe-interior sandboxing), so the
            ; AI-clearing side effects of resetAI are harmless here. Shorter
            ; resetAI delay than the home-sandbox paths (1000 vs 1500) because
            ; the companion is still local and user expects quick resume.
            SeverActionsNative.EscalatedReEvaluate(akActor, 1000)

            Debug.Trace("[SeverActions_Follow] Safe interior sandbox ended: " + akActor.GetDisplayName() + " teleported to player and resumes following")
        EndIf
    EndIf
EndEvent

; Phase 5 Fix C — deferred re-evaluation handler.
; C++ SituationMonitor fires SeverActions_SafeInteriorReEval ~500ms after
; ApplySafeInteriorSandboxNative so the engine picks up our override even if
; the first EvaluatePackage raced with a cell transition or AI busy state.
Event OnSafeInteriorReEval(String eventName, String strArg, Float numArg, Form sender)
    Actor akActor = sender as Actor
    If !akActor
        akActor = Game.GetFormEx(numArg as Int) as Actor
    EndIf
    If !akActor
        Return
    EndIf
    ; Only re-eval if this actor is still flagged as safe-interior sandboxing.
    ; Covers the case where the player exits during the 500ms delay — we don't
    ; want to force a re-eval on someone who is now mid-exit-teleport.
    If StorageUtil.GetIntValue(akActor, "SeverActions_InSafeInteriorSandbox", 0) != 1
        Return
    EndIf
    akActor.EvaluatePackage()
    Debug.Trace("[SeverActions_Follow] Safe interior deferred re-eval: " + akActor.GetDisplayName())
EndEvent

; =============================================================================
; SAFE INTERIOR TOGGLE PERSISTENCE
; Fired by PrismaUI (via C++) when user toggles the safe interior setting.
; Persists to StorageUtil so it survives save/load.
; =============================================================================

Event OnSafeInteriorToggle(String eventName, String strArg, Float numArg, Form sender)
    Quest SeverActionsQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    If SeverActionsQuest
        Int val = 0
        If numArg >= 1.0
            val = 1
        EndIf
        StorageUtil.SetIntValue(SeverActionsQuest, "SeverActions_SafeInteriorEnabled", val)
        Debug.Trace("[SeverActions_Follow] Safe interior sandbox toggle persisted: " + val)
    EndIf
EndEvent

Event OnPauseOnOpenToggle(String eventName, String strArg, Float numArg, Form sender)
    {Fired by PrismaUIBridge when user toggles the "pause on open" setting.
     Persists to StorageUtil so the value survives save/load. On next load,
     Maintenance reads it back and pushes to the C++ atomic via Native_SetPauseOnOpen.}
    Quest SeverActionsQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    If SeverActionsQuest
        Int val = 0
        If numArg >= 1.0
            val = 1
        EndIf
        StorageUtil.SetIntValue(SeverActionsQuest, "SeverActions_PauseOnOpen", val)
        Debug.Trace("[SeverActions_Follow] PrismaUI pause-on-open toggle persisted: " + val)
    EndIf
EndEvent

Event OnFriendlyFireToggle(String eventName, String strArg, Float numArg, Form sender)
    {Fired by PrismaUISettingsHandler when user toggles "Prevent Follower Friendly Fire".
     C++ side is already updated synchronously by the handler. Here we:
       1. Persist the value to StorageUtil so it survives save/load.
       2. Adjust the engine's ally-hit aggro thresholds. Skyrim fires aggro
          on allies after iAllyHitCombatAllowed=3 / iAllyHitNonCombatAllowed=0
          hits by default. Raising them stops AoE spam / stray arrows from
          flipping follower aggression even when IgnoreFriendlyHits drops.
          Note: these are GLOBAL game settings — raising them also makes
          bandit-on-bandit aggro slower, which is generally invisible.}
    Quest SeverActionsQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    If SeverActionsQuest
        Int val = 0
        If numArg >= 1.0
            val = 1
        EndIf
        StorageUtil.SetIntValue(SeverActionsQuest, "SeverActions_PreventFollowerFF", val)
        If val == 1
            Game.SetGameSettingInt("iAllyHitCombatAllowed", 100)
            Game.SetGameSettingInt("iAllyHitNonCombatAllowed", 50)
        Else
            Game.SetGameSettingInt("iAllyHitCombatAllowed", 3)
            Game.SetGameSettingInt("iAllyHitNonCombatAllowed", 0)
        EndIf
        Debug.Trace("[SeverActions_Follow] Follower friendly-fire prevention persisted: " + val + " (ally hit thresholds adjusted)")
    EndIf
EndEvent

; =============================================================================
; HELPER - Check if actor has follow package
; =============================================================================

Bool Function HasFollowPackage(Actor akActor)
    return SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
EndFunction

; =============================================================================
; ACTIVELY FOLLOWING FACTION — dynamic state for SkyrimNet prompt integration
; =============================================================================

Function SetActivelyFollowing(Actor akActor, Bool active)
    {Add or remove the SeverActions_ActivelyFollowing faction.
     Called whenever a companion's follow state changes.}
    If !SeverActions_ActivelyFollowing || !akActor
        Return
    EndIf
    If active
        akActor.AddToFaction(SeverActions_ActivelyFollowing)
    Else
        akActor.RemoveFromFaction(SeverActions_ActivelyFollowing)
    EndIf
EndFunction

; =============================================================================
; COMPANION ALIAS SLOT MANAGEMENT
; =============================================================================

Function AssignFollowerSlot(Actor akActor)
    {Find an empty follower alias slot and assign the actor to it.
     The alias's CK-attached follow package will auto-apply.}
    If !FollowerSlots
        Debug.Trace("[SeverActions_Follow] WARNING: FollowerSlots array not set - alias follow disabled")
        Return
    EndIf

    ; Check if actor is already in a slot (avoid duplicates)
    Int i = 0
    While i < FollowerSlots.Length
        If FollowerSlots[i] && FollowerSlots[i].GetActorRef() == akActor
            Debug.Trace("[SeverActions_Follow] " + akActor.GetDisplayName() + " already in FollowerSlot" + i)
            Return
        EndIf
        i += 1
    EndWhile

    ; Find first empty slot
    i = 0
    While i < FollowerSlots.Length
        If FollowerSlots[i] && !FollowerSlots[i].GetActorRef()
            FollowerSlots[i].ForceRefTo(akActor)
            Debug.Trace("[SeverActions_Follow] Assigned " + akActor.GetDisplayName() + " to FollowerSlot" + i)
            Return
        EndIf
        i += 1
    EndWhile
    Debug.Trace("[SeverActions_Follow] WARNING: No empty follower slots available for " + akActor.GetDisplayName())
EndFunction

Function ClearFollowerSlot(Actor akActor)
    {Find and clear the follower alias slot for this actor.
     Removing from alias auto-removes the CK-attached follow package.}
    If !FollowerSlots
        Return
    EndIf
    Int i = 0
    While i < FollowerSlots.Length
        If FollowerSlots[i] && FollowerSlots[i].GetActorRef() == akActor
            FollowerSlots[i].Clear()
            Debug.Trace("[SeverActions_Follow] Cleared " + akActor.GetDisplayName() + " from FollowerSlot" + i)
            Return
        EndIf
        i += 1
    EndWhile
EndFunction

Bool Function IsInFollowerSlot(Actor akActor)
    {Check if an actor is currently in one of the companion alias slots.
     Used to distinguish companions (CK alias follow) from casual followers (SkyrimNet follow).}
    If !FollowerSlots || !akActor
        Return false
    EndIf
    Int i = 0
    While i < FollowerSlots.Length
        If FollowerSlots[i] && FollowerSlots[i].GetActorRef() == akActor
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

; =============================================================================
; SAVE/LOAD PERSISTENCE (Companions only)
; =============================================================================

Function ReapplyFollowTracking(Actor[] followers)
    {Re-apply runtime-only data for companions after save/load.
     The CK alias packages persist natively — this only restores:
     - LinkedRef (now persists via native cosave — auto-restores on game load)
     - Sandbox overrides for waiting companions
     Does NOT register with SkyrimNet — companion eligibility uses faction.}
    Actor player = Game.GetPlayer()
    Int i = 0
    While i < followers.Length
        Actor akActor = followers[i]
        If akActor && !akActor.IsDead()
            ; Clean up any stale SkyrimNet FollowPlayer package that may have been
            ; layered on companions from prior versions. Companions use CK alias
            ; packages — a dual FollowPlayer causes AI flicker. Safe no-op if none exists.
            If IsInFollowerSlot(akActor) && SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
                SkyrimNetApi.UnregisterPackage(akActor, "FollowPlayer")
                Debug.Trace("[SeverActions_Follow] Cleaned stale SkyrimNet FollowPlayer from companion: " + akActor.GetDisplayName())
            EndIf

            ; Defensive LinkedRef re-assertion — not just redundant.
            ; The native cosave restores LinkedRefs on kPostLoadGame, but Papyrus
            ; scripts on quest OnInit / alias OnLoad run BEFORE kPostLoadGame and
            ; can cache null GetLinkedRef results if they query during that window.
            ; Re-setting here guarantees the ref is live by the time Maintenance()
            ; completes, even if the cosave was stale, corrupted, or lost.
            ; Also handles cell-transition scenarios where the engine may drop
            ; ExtraLinkedRef from the actor's active extra data.
            If SeverActions_FollowerFollowKW
                SeverActionsNative.LinkedRef_Set(akActor, player, SeverActions_FollowerFollowKW)
                ; Re-register with the native OrphanCleanup scanner. Its in-memory
                ; m_trackedFollowers map is cleared on every kPostLoadGame (see
                ; plugin.cpp), so without this call the scanner flags the companion
                ; as an orphan ~5s after load and OnOrphanCleanup (in FollowerManager)
                ; clears the LinkedRef — breaking follow on every reload.
                SeverActionsNative.OrphanCleanup_RegisterFollower(akActor)
            EndIf

            Bool isWaiting = akActor.GetAV("WaitingForPlayer") > 0
            ; If they were waiting/sandboxing, re-apply sandbox package + tracking
            If isWaiting && SandboxPackage
                ActorUtil.AddPackageOverride(akActor, SandboxPackage, SandboxPackagePriority, 1)
                SetSandboxFlag(akActor, true)
            EndIf

            ; Re-apply actively following faction based on current state
            SetActivelyFollowing(akActor, !isWaiting)

            ; Update native follow state for PrismaUI status badge
            SeverActionsNative.Native_SetPackageState(akActor, !isWaiting, false, false)

            akActor.EvaluatePackage()
            Debug.Trace("[SeverActions_Follow] Reapplied companion follow tracking for: " + akActor.GetDisplayName() + " (waiting=" + isWaiting + ")")
        EndIf
        i += 1
    EndWhile
EndFunction

; =============================================================================
; CASUAL FOLLOW — SkyrimNet package (guards, random NPCs, temporary)
; Called by startfollowing.yaml / stopfollowing.yaml
; =============================================================================

Function StartFollowing(Actor akActor)
    {Start casual following via SkyrimNet's built-in follow package.
     For any NPC the LLM decides should follow temporarily.
     Does NOT use alias slots or LinkedRef — purely SkyrimNet managed.}
    if !akActor || akActor.IsDead()
        return
    endif

    ; Clear waiting state FIRST — prevents the engine from creating an FF-prefix
    ; runtime sandbox in the gap between sandbox removal and follow package registration.
    akActor.SetAV("WaitingForPlayer", 0)

    ; Now safe to remove sandbox — follow package registration below will take over.
    ; Don't gate on IsSandboxing — if tracking was lost (save/load, timing),
    ; the PO3 override would stay forever. These are all safe no-ops if nothing is active.
    SetSandboxFlag(akActor, false)
    SeverActionsNative.UnregisterSandboxUser(akActor)
    if SandboxPackage
        ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
    endif

    ; Register SkyrimNet's built-in follow package
    ; NOTE: SkyrimNet 0.15.4+ queues package operations and calls EvaluatePackage
    ; internally when the queue processes — do NOT call EvaluatePackage here or the
    ; actor evaluates against a stale package stack before the queue applies the override.
    SkyrimNetApi.RegisterPackage(akActor, "FollowPlayer", FollowPackagePriority, 0, true)
    SeverActionsNative.Native_SetPackageState(akActor, true, false, false)

    ; Mark as actively following for ENGAGED tag in prompts
    SetActivelyFollowing(akActor, true)

    Debug.Notification(akActor.GetDisplayName() + " is now following you.")
EndFunction

Function StopFollowing(Actor akActor)
    {Stop casual following — removes SkyrimNet's follow package.}
    if !akActor
        return
    endif

    ; Always clean up sandbox state unconditionally (defensive)
    SetSandboxFlag(akActor, false)
    SeverActionsNative.UnregisterSandboxUser(akActor)
    if SandboxPackage
        ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
    endif

    ; Unregister SkyrimNet's follow package
    ; Queue handles package removal + EvaluatePackage internally (0.15.4+)
    SkyrimNetApi.UnregisterPackage(akActor, "FollowPlayer")
    SeverActionsNative.Native_SetPackageState(akActor, false, false, false)

    ; Remove actively following state
    SetActivelyFollowing(akActor, false)

    Debug.Notification(akActor.GetDisplayName() + " stopped following you.")
    SkyrimNetApi.RegisterEvent("follower_left", akActor.GetDisplayName() + " stopped following " + Game.GetPlayer().GetDisplayName(), akActor, Game.GetPlayer())
EndFunction

; =============================================================================
; COMPANION FOLLOW — CK alias-based package (formal companions only)
; Called internally by FollowerManager.RegisterFollower / UnregisterFollower
; =============================================================================

Function CompanionStartFollowing(Actor akActor)
    {Start companion following via our CK alias-based follow package.
     Assigns alias slot (auto-applies CK package) + sets LinkedRef to player.
     Only for formal companions recruited through SetCompanion.}
    if !akActor || akActor.IsDead()
        return
    endif

    ; Clear waiting state FIRST — so the CK alias follow package condition
    ; (WaitingForPlayer == 0) becomes valid BEFORE we remove the sandbox override.
    ; This prevents the engine from creating an FF-prefix runtime sandbox in the
    ; gap between sandbox removal and follow package activation.
    akActor.SetAV("WaitingForPlayer", 0)

    ; Now safe to remove sandbox — CK follow package is already eligible
    SetSandboxFlag(akActor, false)
    SeverActionsNative.UnregisterSandboxUser(akActor)
    if SandboxPackage
        ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
    endif

    ; Also clean up any stale casual FollowPlayer package (shouldn't be here
    ; for companions, but defensive cleanup in case of prior bugs)
    SkyrimNetApi.UnregisterPackage(akActor, "FollowPlayer")

    ; Set linked ref to player (so CK follow package knows who to follow)
    If SeverActions_FollowerFollowKW
        SeverActionsNative.LinkedRef_Set(akActor, Game.GetPlayer(), SeverActions_FollowerFollowKW)
    Else
        Debug.Trace("[SeverActions_Follow] WARNING: FollowerFollowKW not set!")
    EndIf

    ; Assign to alias slot — CK package auto-applies (persists across save/load)
    AssignFollowerSlot(akActor)

    ; No SkyrimNetApi.RegisterPackage — our CK alias package handles the AI.
    ; Companion eligibility uses SeverActions_FollowerFaction, not HasPackage.

    ; Mark as actively following for SkyrimNet prompt integration
    SetActivelyFollowing(akActor, true)

    ; Update native follow state for PrismaUI status badge
    SeverActionsNative.Native_SetPackageState(akActor, true, false, false)

    ; Register with native orphan cleanup so stale follow packages get detected
    SeverActionsNative.OrphanCleanup_RegisterFollower(akActor)

    akActor.EvaluatePackage()
EndFunction

Function CompanionStopFollowing(Actor akActor, Bool evaluateAfter = true)
    {Stop companion following — clears alias slot (auto-removes CK package) and LinkedRef.
     Pass evaluateAfter=false when the caller will apply a new package immediately after
     (e.g., dismiss→SendHome), to avoid a zero-package EvaluatePackage gap that creates
     an FF-prefix fallback package.}
    if !akActor
        return
    endif

    ; Always clean up sandbox state unconditionally (defensive)
    SetSandboxFlag(akActor, false)
    SeverActionsNative.UnregisterSandboxUser(akActor)
    if SandboxPackage
        ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
    endif

    ; Clear alias slot — CK package auto-removes
    ClearFollowerSlot(akActor)

    ; Unregister from orphan cleanup tracking
    SeverActionsNative.OrphanCleanup_UnregisterFollower(akActor)

    ; Clear ALL tracked LinkedRefs — not just our follow keyword.
    ; If the actor had active travel, furniture, or arrest LinkedRefs when dismissed,
    ; per-keyword Clear only removes the follow entry. ClearAll catches everything,
    ; preventing stale LinkedRefs from persisting in the cosave and restoring on load.
    ; Each subsystem still clears its own keyword on normal completion — this is the
    ; belt-and-suspenders final sweep for crash/interrupt scenarios.
    SeverActionsNative.LinkedRef_ClearAll(akActor)

    ; Also unregister from SkyrimNet in case they had a casual follow registered too
    SkyrimNetApi.UnregisterPackage(akActor, "FollowPlayer")

    ; No longer actively following
    SetActivelyFollowing(akActor, false)

    ; Update native follow state for PrismaUI status badge
    SeverActionsNative.Native_SetPackageState(akActor, false, false, false)

    If evaluateAfter
        akActor.EvaluatePackage()
    EndIf
EndFunction

; =============================================================================
; SHARED FUNCTIONS — Work for both casual and companion follow
; =============================================================================

Function WaitHere(Actor akActor)
    if !akActor
        return
    endif

    ; Set waiting state - package condition will make them stop following
    akActor.SetAV("WaitingForPlayer", 1)

    ; No longer actively following (waiting in place)
    SetActivelyFollowing(akActor, false)

    akActor.EvaluatePackage()

    Debug.Notification(akActor.GetDisplayName() + " is waiting here.")
    SkyrimNetApi.RegisterEvent("follower_waiting", akActor.GetDisplayName() + " is waiting for " + Game.GetPlayer().GetDisplayName(), akActor, Game.GetPlayer())
EndFunction

Function Sandbox(Actor akActor)
    if !akActor || akActor.IsDead()
        return
    endif

    if !SandboxPackage
        Debug.Trace("[SeverActions_Follow] Sandbox: No SandboxPackage assigned!")
        return
    endif

    ; Apply sandbox package FIRST so there's always a valid high-priority package
    ; on the actor. If we set WaitingForPlayer before this, the CK alias follow
    ; package drops and the engine creates a fallback runtime sandbox (FF-prefix)
    ; in the gap before our override is applied.
    ; Priority 55 > FollowPlayer's 50 — sandbox wins immediately.
    ActorUtil.AddPackageOverride(akActor, SandboxPackage, SandboxPackagePriority, 1)

    ; NOW safe to disable the CK follow package — sandbox is already covering
    SkyrimNetApi.UnregisterPackage(akActor, "FollowPlayer")
    akActor.SetAV("WaitingForPlayer", 1)

    ; Track sandbox state via StorageUtil (reliable, immediate).
    ; We skip SkyrimNet's RegisterPackage("Sandbox") entirely — "Sandbox" isn't in
    ; PackageFormCache so it always fails. Our StorageUtil flag replaces it.
    SetSandboxFlag(akActor, true)

    ; No SandboxManager registration — the wait action means "stay here" permanently.
    ; Player manually resumes via StopSandbox/hotkey when they want the NPC back.

    ; No longer actively following (relaxing in place)
    SetActivelyFollowing(akActor, false)

    ; Add waiting faction so other mods (e.g., IntelEngine) can blacklist waiting NPCs
    If SeverActions_WaitingFaction
        akActor.AddToFaction(SeverActions_WaitingFaction)
    EndIf
    ; No EvaluatePackage — faction add doesn't need forced eval, AI picks it up naturally

    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " decides to relax and wander around the area.", akActor, Game.GetPlayer())
EndFunction

Function StopSandbox(Actor akActor)
    if !akActor
        return
    endif

    ; Clear waiting state FIRST — so the CK alias follow package condition
    ; (WaitingForPlayer == 0) becomes valid BEFORE we remove the sandbox override.
    ; For casual followers, this ensures SkyrimNet's FollowPlayer (re-registered below)
    ; isn't competing with an FF-prefix runtime sandbox the engine creates in the gap.
    akActor.SetAV("WaitingForPlayer", 0)

    ; Clear sandbox state
    SetSandboxFlag(akActor, false)

    ; Remove waiting faction
    If SeverActions_WaitingFaction
        akActor.RemoveFromFaction(SeverActions_WaitingFaction)
    EndIf

    ; Unregister from native SandboxManager
    SeverActionsNative.UnregisterSandboxUser(akActor)

    ; Now safe to remove sandbox override — follow package is already eligible
    if SandboxPackage
        ActorUtil.RemovePackageOverride(akActor, SandboxPackage)
    endif

    ; Re-apply follow package only for casual followers.
    ; Companions use CK alias-based packages which auto-reassert when WaitingForPlayer clears.
    ; Registering SkyrimNet FollowPlayer on a companion creates dual-package AI flicker.
    If !IsInFollowerSlot(akActor)
        SkyrimNetApi.RegisterPackage(akActor, "FollowPlayer", FollowPackagePriority, 0, true)
    Else
        akActor.EvaluatePackage()
    EndIf

    ; Back to actively following
    SetActivelyFollowing(akActor, true)

    Debug.Notification(akActor.GetDisplayName() + " stopped relaxing.")
    SkyrimNetApi.RegisterPersistentEvent(akActor.GetDisplayName() + " stops relaxing and is ready to move.", akActor, Game.GetPlayer())
EndFunction

; =============================================================================
; GLOBAL API FOR ACTIONS
; =============================================================================

; --- StartFollowing Action (Casual) ---

Bool Function StartFollowing_IsEligible(Actor akActor) Global
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif

    ; Don't allow vanilla followers
    Faction factionCompanion = Game.GetFormFromFile(0x084D1B, "Skyrim.esm") as Faction
    if factionCompanion && akActor.IsInFaction(factionCompanion)
        return false
    endif

    ; Check both casual (SkyrimNet package) and companion (alias slot) follow state
    Bool hasPackage = SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    Bool isCompanion = instance && instance.IsInFollowerSlot(akActor)
    Bool isWaiting = akActor.GetAV("WaitingForPlayer") > 0
    Bool isSandboxing = StorageUtil.GetIntValue(akActor, "SeverActions_IsSandboxing") == 1

    ; Companions who are waiting/sandboxing — eligible (will route to CompanionStartFollowing)
    If isCompanion
        return isWaiting || isSandboxing
    EndIf

    ; Casual followers already actively following — not eligible
    if hasPackage && !isWaiting && !isSandboxing
        return false
    endif

    return true
EndFunction

Function StartFollowing_Execute(Actor akActor) Global
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    if instance
        ; If this actor is a formal companion (in alias slot), route to the companion
        ; follow path instead of casual. Prevents dual-package AI flicker and ensures
        ; the CK alias package is used (not SkyrimNet's FollowPlayer).
        If instance.IsInFollowerSlot(akActor)
            instance.CompanionStartFollowing(akActor)
        Else
            instance.StartFollowing(akActor)
        EndIf
    endif
EndFunction

; --- StopFollowing Action (Casual) ---

Bool Function StopFollowing_IsEligible(Actor akActor) Global
    if !akActor
        return false
    endif

    return SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
EndFunction

Function StopFollowing_Execute(Actor akActor) Global
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    if instance
        If instance.IsInFollowerSlot(akActor)
            instance.CompanionStopFollowing(akActor)
        Else
            instance.StopFollowing(akActor)
        EndIf
    endif
EndFunction

; --- WaitHere Action ---

Bool Function WaitHere_IsEligible(Actor akActor) Global
    if !akActor
        return false
    endif

    ; Must be following (casual or companion) and not already waiting
    Bool hasPackage = SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
    If !hasPackage
        SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
        If !instance || !instance.IsInFollowerSlot(akActor)
            return false
        EndIf
    EndIf
    Bool isWaiting = akActor.GetAV("WaitingForPlayer") > 0

    return !isWaiting
EndFunction

Function WaitHere_Execute(Actor akActor) Global
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    if instance
        instance.WaitHere(akActor)
    endif
EndFunction

; --- Sandbox Action ---

Bool Function Sandbox_IsEligible(Actor akActor) Global
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif

    ; Must be a follower — check both casual (SkyrimNet package) and companion (alias slot)
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    Bool hasFollowPkg = SkyrimNetApi.HasPackage(akActor, "FollowPlayer")
    Bool isCompanion = instance && instance.IsInFollowerSlot(akActor)
    if !hasFollowPkg && !isCompanion
        return false
    endif

    ; Must not already be sandboxing
    if StorageUtil.GetIntValue(akActor, "SeverActions_IsSandboxing") == 1
        return false
    endif

    return true
EndFunction

Function Sandbox_Execute(Actor akActor) Global
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    if instance
        instance.Sandbox(akActor)
    endif
EndFunction

; --- StopSandbox Action ---

Bool Function StopSandbox_IsEligible(Actor akActor) Global
    if !akActor
        return false
    endif

    return StorageUtil.GetIntValue(akActor, "SeverActions_IsSandboxing") == 1
EndFunction

Function StopSandbox_Execute(Actor akActor) Global
    SeverActions_Follow instance = Game.GetFormFromFile(0x000800, "SeverActions.esp") as SeverActions_Follow
    if instance
        instance.StopSandbox(akActor)
    endif
EndFunction