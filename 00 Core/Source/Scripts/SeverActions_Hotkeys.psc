Scriptname SeverActions_Hotkeys extends Quest
{Hotkey handler for SeverActions - manages key bindings for quick actions}

; =============================================================================
; PROPERTIES - Set in CK
; =============================================================================

SeverActions_Follow Property FollowScript Auto
{Reference to the follow system script}

SeverActions_Furniture Property FurnitureScript Auto
{Reference to the furniture system script}

SeverActions_Combat Property CombatScript Auto
{Reference to the combat system script}

SeverActions_Outfit Property OutfitScript Auto
{Reference to the outfit system script}

SeverActions_FollowerManager Property FollowerManagerScript Auto
{Reference to the follower manager script}

; =============================================================================
; HOTKEY SETTINGS - Configured via MCM
; =============================================================================

int Property FollowToggleKey = -1 Auto Hidden
{Key code for toggling follow state. -1 = unset/disabled}

int Property DismissKey = -1 Auto Hidden
{Key code for dismissing target companion. -1 = unset/disabled}

int Property StandUpKey = -1 Auto Hidden
{Key code for making target NPC stand up from furniture. -1 = unset/disabled}

int Property UseFurnitureKey = -1 Auto Hidden
{Key code for the two-step "use furniture" hotkey. Press 1 on an NPC to select
 them, press 2 on a piece of furniture to send them to use it. -1 = unset.}

; Two-step use-furniture state: the NPC picked on the first press, awaiting a
; furniture target on the second. Cleared after use or on timeout.
Actor PendingFurnitureUser = None
Float PendingFurnitureTime = 0.0
float Property PendingFurnitureWindow = 30.0 AutoReadOnly
{Seconds the selected NPC stays "pending" before the two-step flow resets.}

int Property YieldKey = -1 Auto Hidden
{Key code for making target NPC yield/surrender. -1 = unset/disabled}

int Property UndressKey = -1 Auto Hidden
{Key code for undressing target NPC. -1 = unset/disabled}

int Property DressKey = -1 Auto Hidden
{Key code for dressing target NPC. -1 = unset/disabled}

int Property SetCompanionKey = -1 Auto Hidden
{Key code for making target NPC a companion. -1 = unset/disabled}

int Property CompanionWaitKey = -1 Auto Hidden
{Key code for toggling wait state on target NPC. -1 = unset/disabled}

int Property AssignHomeKey = -1 Auto Hidden
{Key code for assigning NPC's home to current location. -1 = unset/disabled}
int Property ClearHomeKey = -1 Auto Hidden
{Key code for clearing NPC's home assignment. -1 = unset/disabled}

int Property SetupCampKey = -1 Auto Hidden
{Key code for entering camp placement mode (Sever's Hearth). -1 = unset/disabled}

int Property DropMarkerKey = -1 Auto Hidden
{Key code for dropping a named travel marker at the player's feet (ai_docs/NAMED_MARKERS.md). -1 = unset/disabled}

int Property TieUntieKey = -1 Auto Hidden
{Key code for the Tie / Untie toggle (2026-08-23, Shrike field report). Aim at an
 NPC and press: a bound captive is FREED - no matter who bound them, an NPC
 restrainer included - and an unbound NPC is restrained on the spot with you as
 the captor. Each press narrates what happened to SkyrimNet directly, so it never
 depends on the LLM picking the right action. -1 = unset/disabled}

int Property ConfigMenuKey = 9 Auto Hidden
{Key code for opening the PrismaUI config menu. Default: 9 (the 8 key). -1 = disabled}

bool Property ConfigMenuRequireShift = true Auto Hidden
{If true, Shift must be held when pressing ConfigMenuKey to open PrismaUI. Default: true (Shift+8)}

; =============================================================================
; TARGET MODE SETTINGS
; =============================================================================

int Property TargetMode = 0 Auto Hidden
{0 = Crosshair, 1 = Nearest NPC, 2 = Last talked to}

float Property NearestNPCRadius = 500.0 Auto Hidden
{Radius to search for nearest NPC when using TargetMode 1}

; =============================================================================
; STATE
; =============================================================================

Actor LastTalkedTo = None
bool Property IsRegistered = false Auto Hidden

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Hotkeys] Initialized")
    RegisterKeys()
EndEvent

; No OnPlayerLoadGame handler here: Quest scripts never receive that event
; (Actor/alias-only). Load re-registration runs from SeverActions_Init's
; InitializeHotkeySystem(), which calls RegisterKeys() on every load.

; =============================================================================
; KEY REGISTRATION
; =============================================================================

Function RegisterKeys()
    ; Unregister all first to avoid duplicates
    UnregisterForAllKeys()
    IsRegistered = false

    ; Heal ANY hotkey sharing the config-menu key code (saves bound before the
    ; MCM refused the collision): such a bind can never fire — OnKeyDown yields
    ; to the native config handler — so clear it loudly, not leave it dead.
    ; Runs BEFORE the registrations below so a healed key never registers.
    FollowToggleKey  = HealConfigCollision(FollowToggleKey,  "Follow Toggle")
    DismissKey       = HealConfigCollision(DismissKey,       "Dismiss")
    StandUpKey       = HealConfigCollision(StandUpKey,       "Stand Up")
    UseFurnitureKey  = HealConfigCollision(UseFurnitureKey,  "Use Furniture")
    YieldKey         = HealConfigCollision(YieldKey,         "Yield")
    UndressKey       = HealConfigCollision(UndressKey,       "Undress")
    DressKey         = HealConfigCollision(DressKey,         "Dress")
    SetCompanionKey  = HealConfigCollision(SetCompanionKey,  "Set Companion")
    CompanionWaitKey = HealConfigCollision(CompanionWaitKey, "Companion Wait")
    AssignHomeKey    = HealConfigCollision(AssignHomeKey,    "Assign Home")
    ClearHomeKey     = HealConfigCollision(ClearHomeKey,     "Clear Home")
    SetupCampKey     = HealConfigCollision(SetupCampKey,     "Set Up Camp")
    DropMarkerKey    = HealConfigCollision(DropMarkerKey,    "Drop Marker")
    TieUntieKey      = HealConfigCollision(TieUntieKey,      "Tie / Untie")

    ; Register follow toggle key (only if set)
    if FollowToggleKey > 0
        RegisterForKey(FollowToggleKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered follow toggle key: " + FollowToggleKey)
    endif
    
    ; Register dismiss key (only if set)
    if DismissKey > 0
        RegisterForKey(DismissKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered dismiss key: " + DismissKey)
    endif
    
    ; Register stand up key (only if set)
    if StandUpKey > 0
        RegisterForKey(StandUpKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered stand up key: " + StandUpKey)
    endif

    ; Register use-furniture key (only if set)
    if UseFurnitureKey > 0
        RegisterForKey(UseFurnitureKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered use furniture key: " + UseFurnitureKey)
    endif

    ; Register yield key (only if set)
    if YieldKey > 0
        RegisterForKey(YieldKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered yield key: " + YieldKey)
    endif
    
    ; Register undress key (only if set)
    if UndressKey > 0
        RegisterForKey(UndressKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered undress key: " + UndressKey)
    endif
    
    ; Register dress key (only if set)
    if DressKey > 0
        RegisterForKey(DressKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered dress key: " + DressKey)
    endif

    ; Register set companion key (only if set)
    if SetCompanionKey > 0
        RegisterForKey(SetCompanionKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered set companion key: " + SetCompanionKey)
    endif

    ; Register companion wait key (only if set)
    if CompanionWaitKey > 0
        RegisterForKey(CompanionWaitKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered companion wait key: " + CompanionWaitKey)
    endif

    ; Register assign home key (only if set)
    if AssignHomeKey > 0
        RegisterForKey(AssignHomeKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered assign home key: " + AssignHomeKey)
    endif

    ; Register clear home key (only if set)
    if ClearHomeKey > 0
        RegisterForKey(ClearHomeKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered clear home key: " + ClearHomeKey)
    endif

    ; Register setup camp key (only if set)
    if SetupCampKey > 0
        RegisterForKey(SetupCampKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered setup camp key: " + SetupCampKey)
    endif

    if DropMarkerKey > 0
        RegisterForKey(DropMarkerKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered drop marker key: " + DropMarkerKey)
    endif

    if TieUntieKey > 0
        RegisterForKey(TieUntieKey)
        Debug.Trace("[SeverActions_Hotkeys] Registered tie/untie key: " + TieUntieKey)
    endif

    ; Config menu key is NATIVE now — no RegisterForKey. The Papyrus VM is
    ; saturated for 30-60s after a load on heavy lists, and key events queued
    ; behind load recovery made the menu feel dead the whole time. The DLL's
    ; InputEvent sink handles the key with zero VM involvement; this push
    ; syncs the binding (and the DLL persists it, so later launches are live
    ; at kDataLoaded before any Papyrus runs).
    PushMenuKeyToNative()

    IsRegistered = true
EndFunction

; Sync the config-menu binding to the DLL's native input sink. Called from
; RegisterKeys() (every load recovery), UpdateConfigMenuKey(), and the MCM's
; shift-requirement toggle path.
Function PushMenuKeyToNative()
    SeverActionsNative.PrismaUI_SetMenuKey(ConfigMenuKey, ConfigMenuRequireShift)
    Debug.Trace("[SeverActions_Hotkeys] Pushed config menu key to native: " + ConfigMenuKey + " shift=" + ConfigMenuRequireShift)
EndFunction

Function UpdateFollowToggleKey(int newKey)
    ; Unregister old key if it was valid
    if FollowToggleKey > 0 && FollowToggleKey != newKey
        UnregisterForKey(FollowToggleKey)
    endif
    
    FollowToggleKey = newKey
    
    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated follow toggle key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Follow toggle key cleared")
    endif
EndFunction

Function UpdateDismissKey(int newKey)
    ; Unregister old key if it was valid
    if DismissKey > 0 && DismissKey != newKey
        UnregisterForKey(DismissKey)
    endif

    DismissKey = newKey

    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated dismiss key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Dismiss key cleared")
    endif
EndFunction

Function UpdateStandUpKey(int newKey)
    ; Unregister old key if it was valid
    if StandUpKey > 0 && StandUpKey != newKey
        UnregisterForKey(StandUpKey)
    endif
    
    StandUpKey = newKey
    
    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated stand up key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Stand up key cleared")
    endif
EndFunction

Function UpdateUseFurnitureKey(int newKey)
    ; Unregister old key if it was valid
    if UseFurnitureKey > 0 && UseFurnitureKey != newKey
        UnregisterForKey(UseFurnitureKey)
    endif

    UseFurnitureKey = newKey

    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated use furniture key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Use furniture key cleared")
    endif
EndFunction

Function UpdateYieldKey(int newKey)
    ; Unregister old key if it was valid
    if YieldKey > 0 && YieldKey != newKey
        UnregisterForKey(YieldKey)
    endif

    YieldKey = newKey

    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated yield key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Yield key cleared")
    endif
EndFunction

Function UpdateUndressKey(int newKey)
    ; Unregister old key if it was valid
    if UndressKey > 0 && UndressKey != newKey
        UnregisterForKey(UndressKey)
    endif
    
    UndressKey = newKey
    
    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated undress key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Undress key cleared")
    endif
EndFunction

Function UpdateDressKey(int newKey)
    ; Unregister old key if it was valid
    if DressKey > 0 && DressKey != newKey
        UnregisterForKey(DressKey)
    endif
    
    DressKey = newKey
    
    ; Register new key (only if valid)
    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated dress key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Dress key cleared")
    endif
EndFunction

Function UpdateSetCompanionKey(int newKey)
    if SetCompanionKey > 0 && SetCompanionKey != newKey
        UnregisterForKey(SetCompanionKey)
    endif

    SetCompanionKey = newKey

    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated set companion key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Set companion key cleared")
    endif
EndFunction

Function UpdateCompanionWaitKey(int newKey)
    if CompanionWaitKey > 0 && CompanionWaitKey != newKey
        UnregisterForKey(CompanionWaitKey)
    endif

    CompanionWaitKey = newKey

    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated companion wait key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Companion wait key cleared")
    endif
EndFunction

Function UpdateAssignHomeKey(int newKey)
    if AssignHomeKey > 0 && AssignHomeKey != newKey
        UnregisterForKey(AssignHomeKey)
    endif

    AssignHomeKey = newKey

    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated assign home key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Assign home key cleared")
    endif
EndFunction

Function UpdateClearHomeKey(int newKey)
    if ClearHomeKey > 0 && ClearHomeKey != newKey
        UnregisterForKey(ClearHomeKey)
    endif

    ClearHomeKey = newKey

    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated clear home key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Clear home key cleared")
    endif
EndFunction

Function UpdateSetupCampKey(int newKey)
    if SetupCampKey > 0 && SetupCampKey != newKey
        UnregisterForKey(SetupCampKey)
    endif

    SetupCampKey = newKey

    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated setup camp key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Setup camp key cleared")
    endif
EndFunction

int Function HealConfigCollision(int aiKey, string label)
    {A hotkey sharing the config-menu key code is a dead bind (OnKeyDown
     always yields that code to the native config handler) - clear it with
     a notification so the user rebinds instead of wondering why it's dead.}
    if aiKey > 0 && aiKey == ConfigMenuKey
        Debug.Trace("[SeverActions_Hotkeys] " + label + " key " + aiKey + " collided with config menu key - cleared")
        Debug.Notification(label + " hotkey cleared - it shared the config menu key. Rebind it in the MCM.")
        return -1
    endif
    return aiKey
EndFunction

Function UpdateDropMarkerKey(int newKey)
    if newKey > 0 && newKey == ConfigMenuKey
        ; Collision with the native config-menu key: the bind could never fire
        ; (OnKeyDown yields to the config handler), so treat it as a clear.
        ; The MCM refuses this bind now; this catches stale re-pushes from
        ; ApplyHotkeySettings on saves that stored the collision earlier.
        Debug.Trace("[SeverActions_Hotkeys] Drop marker key " + newKey + " collides with config menu key - clearing instead")
        newKey = -1
    endif
    if DropMarkerKey > 0 && DropMarkerKey != newKey
        UnregisterForKey(DropMarkerKey)
    endif

    DropMarkerKey = newKey

    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated drop marker key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Drop marker key cleared")
    endif
EndFunction

Function UpdateTieUntieKey(int newKey)
    if newKey > 0 && newKey == ConfigMenuKey
        Debug.Trace("[SeverActions_Hotkeys] Tie/untie key " + newKey + " collides with config menu key - clearing instead")
        newKey = -1
    endif
    if TieUntieKey > 0 && TieUntieKey != newKey
        UnregisterForKey(TieUntieKey)
    endif

    TieUntieKey = newKey

    if newKey > 0
        RegisterForKey(newKey)
        Debug.Trace("[SeverActions_Hotkeys] Updated tie/untie key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Tie/untie key cleared")
    endif
EndFunction

Function UpdateConfigMenuKey(int newKey)
    ; Native-owned key: no Papyrus registration; just record + push.
    ConfigMenuKey = newKey
    PushMenuKeyToNative()
    if newKey > 0
        Debug.Trace("[SeverActions_Hotkeys] Updated config menu key to: " + newKey)
    else
        Debug.Trace("[SeverActions_Hotkeys] Config menu key cleared")
    endif
EndFunction

; =============================================================================
; KEY EVENT HANDLING
; =============================================================================

Event OnKeyDown(int keyCode)
    if keyCode <= 0
        return
    endif

    ; Config menu key: handled NATIVELY (PrismaUIBridge's InputEvent sink).
    ; If another hotkey SHARES its code, this event DOES fire for that press —
    ; the config key must win outright, or opening/closing the Prisma UI also
    ; triggers the sharing hotkey (field-hit: DropMarkerKey bound to the same
    ; key dropped a phantom marker on every menu toggle, 2026-08-09).
    if keyCode == ConfigMenuKey
        return
    endif

    ; All other hotkeys: ignore if in menu mode
    if Utility.IsInMenuMode()
        return
    endif

    ; ...and ignore while the Prisma UI itself is open. It is NOT engine menu
    ; mode (with pause-on-open disabled IsInMenuMode() stays false), so typing
    ; in a Prisma text field would otherwise fire any letter-bound hotkey.
    if SeverActionsNativeExt2.Prisma_IsMenuOpen()
        return
    endif

    Actor player = Game.GetPlayer()

    ; Ignore if player is in dialogue, dead, or incapacitated.
    ; (IsInDialogueWithPlayer() on the player is always false -- the Dialogue
    ; Menu check is the real vanilla-dialogue guard.)
    if UI.IsMenuOpen("Dialogue Menu") || player.IsDead() || player.GetSitState() == 3
        return
    endif

    if keyCode == FollowToggleKey && FollowToggleKey > 0
        HandleFollowToggle()
    elseif keyCode == DismissKey && DismissKey > 0
        HandleDismiss()
    elseif keyCode == StandUpKey && StandUpKey > 0
        HandleStandUp()
    elseif keyCode == UseFurnitureKey && UseFurnitureKey > 0
        HandleUseFurniture()
    elseif keyCode == YieldKey && YieldKey > 0
        HandleYield()
    elseif keyCode == UndressKey && UndressKey > 0
        HandleUndress()
    elseif keyCode == DressKey && DressKey > 0
        HandleDress()
    elseif keyCode == SetCompanionKey && SetCompanionKey > 0
        HandleSetCompanion()
    elseif keyCode == CompanionWaitKey && CompanionWaitKey > 0
        HandleCompanionWait()
    elseif keyCode == AssignHomeKey && AssignHomeKey > 0
        HandleAssignHome()
    elseif keyCode == ClearHomeKey && ClearHomeKey > 0
        HandleClearHome()
    elseif keyCode == SetupCampKey && SetupCampKey > 0
        HandleSetupCamp()
    elseif keyCode == DropMarkerKey && DropMarkerKey > 0
        HandleDropMarker()
    elseif keyCode == TieUntieKey && TieUntieKey > 0
        HandleTieUntie()
    endif
EndEvent

; =============================================================================
; TIE / UNTIE HANDLER
; =============================================================================

Function HandleTieUntie()
    {One key, two directions, decided by the crosshair NPC's state:
       BOUND  -> free them. Routes through ReleaseCaptive (the kidnap/restrain
                 system's real unbind), which resolves among ACTIVE captives and
                 doesn't care who the captor was - an NPC restrainer's captive
                 is freed exactly like the player's. This is the Shrike case
                 (2026-08-23): an NPC restrained another mid-conversation and
                 'I am untying your hands' never triggered the untie action.
       UNBOUND-> restrain them, the player as captor. Same store entry + bind
                 the NPC-driven RestrainNPC lands in (restraint flag, no hood,
                 no crime), minus the walk-up - you are already standing there.
     Every outcome is narrated straight to SkyrimNet via RegisterEvent, so the
     NPCs react to what happened regardless of which model is driving dialogue.}
    if !FollowerManagerScript
        FollowerManagerScript = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
        if !FollowerManagerScript
            Debug.Notification("SeverActions: Follower manager not available")
            return
        endif
    endif

    Actor player = Game.GetPlayer()
    Actor target = GetTargetActor()
    if !target
        Debug.Notification("Aim at someone to tie or untie them")
        return
    endif
    if target == player
        Debug.Notification("You cannot tie yourself up")
        return
    endif
    if target.IsDead()
        Debug.Notification(target.GetDisplayName() + " is beyond tying")
        return
    endif

    ; ── UNTIE: any held captive, any captor ──────────────────────────────
    ; Phase 3 = held/bound (the only state with something to untie). Phases
    ; 1-2 are an in-flight approach/grab; aborting those from a hotkey would
    ; race the restrainer's own leg, so only a standing bind is actionable.
    int phase = SeverActionsNativeExt.Native_Kidnap_GetPhase(target)
    if phase == 3
        string capName = target.GetDisplayName()
        FollowerManagerScript.ReleaseCaptive(player, capName)
        ; ReleaseCaptive clears the entry on success; re-read to confirm
        ; before narrating a freeing that a refusal may have blocked.
        if SeverActionsNativeExt.Native_Kidnap_GetPhase(target) == 0
            SkyrimNetApi.RegisterEvent("captive_untied", \
                player.GetDisplayName() + " unties " + capName + "'s hands and lets them go free.", \
                player, target)
            Debug.Notification("You untie " + capName)
        endif
        return
    elseif phase == 1 || phase == 2
        Debug.Notification(target.GetDisplayName() + " is being taken - wait until they are held")
        return
    endif

    ; ── TIE: restrain the crosshair NPC, player as captor ────────────────
    if !FollowerManagerScript.EnableRestrainAction
        Debug.Notification("Restraining is disabled (Settings > Followers > Behavior)")
        return
    endif
    if FollowerManagerScript.IsRegisteredFollower(target)
        Debug.Notification("You will not bind one of your own companions")
        return
    endif
    if !FollowerManagerScript.PlayerRestrainOnSpot(target)
        ; The helper already narrated/notified the specific refusal.
        return
    endif
    ; No extra RegisterEvent here: _BindCaptive already fires the persistent
    ; has-RESTRAINED event, and a second transient one read as a duplicate in
    ; the Recent Events list (2026-08-23). Notification only.
    Debug.Notification("You bind " + target.GetDisplayName() + "'s hands")
    ; You tied them standing right here - lead them along rather than leave
    ; them rooted to the spot (user request). Leash to the player.
    FollowerManagerScript.LeashCaptive(target, player)
EndFunction

; =============================================================================
; DROP MARKER HANDLER
; =============================================================================

Function HandleDropMarker()
    {Drop a named travel marker at the player's feet (M0: auto-named "Spot N";
     rename via Marker_Rename / the future Markers page). The at-feet placement
     IS the navmesh mitigation - the player is standing on it.}
    Actor player = Game.GetPlayer()
    Int markerId = SeverActionsNativeExt2.Marker_DropHere(player, "")
    If markerId > 0
        String markerName = SeverActionsNativeExt2.Marker_GetName(markerId)
        Debug.Notification("Marker dropped: " + markerName + " (" + SeverActionsNativeExt2.Marker_Count() + " total)")
    Else
        Debug.Notification("Could not drop a marker here.")
    EndIf
EndFunction

; =============================================================================
; SETUP CAMP HANDLER
; =============================================================================

Function HandleSetupCamp()
    ; Fire the same ModEvent the Survival page's "Set Up Camp" button uses.
    ; Decoupled from Hearth's ESP — if Hearth isn't installed nothing listens
    ; and this no-ops. SeversHearth_Camp opens the live ghost placement mode.
    Int evt = ModEvent.Create("SeverActions_PrismaSetupCamp")
    If evt
        ModEvent.PushString(evt, "SeverActions_PrismaSetupCamp")
        ModEvent.PushString(evt, "")
        ModEvent.PushFloat(evt, 0.0)
        ModEvent.PushForm(evt, None)
        ModEvent.Send(evt)
    Else
        Debug.Notification("SeverActions: couldn't start camp placement.")
    EndIf
EndFunction

; =============================================================================
; FOLLOW TOGGLE HANDLER
; =============================================================================

Function HandleFollowToggle()
    if !FollowScript
        Debug.Notification("SeverActions: Follow script not configured!")
        return
    endif
    
    Actor target = GetTargetActor()
    
    if !target
        Debug.Notification("No valid target found")
        return
    endif
    
    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif
    
    ; Check current follow state and toggle
    ; Also check sandboxing — sandboxing NPCs had FollowPlayer unregistered so
    ; HasFollowPackage returns false, but they're still in our "paused follow" state
    ; Registered companions route through the companion verbs, exactly like
    ; the wheel menu - the casual StartFollowing path would layer a SkyrimNet
    ; FollowPlayer package (and hasFollowPkg) over the alias system, and for
    ; track-only companions would poison the native monitors (audit H8).
    if !FollowerManagerScript
        FollowerManagerScript = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
    endif
    if FollowerManagerScript && FollowerManagerScript.IsRegisteredFollower(target)
        bool isHeld = (target.GetAV("WaitingForPlayer") > 0) || FollowScript.IsSandboxing(target)
        if isHeld
            FollowerManagerScript.CompanionFollow(target)
        else
            FollowerManagerScript.CompanionWait(target)
        endif
        return
    endif

    bool isCurrentlyFollowing = FollowScript.HasFollowPackage(target)
    bool isSandboxing = FollowScript.IsSandboxing(target)

    if isCurrentlyFollowing || isSandboxing
        ; Following or sandboxing (paused follow) — stop entirely
        ; StopFollowing already cleans up sandbox state defensively
        FollowScript.StopFollowing(target)
    else
        ; Not following - start following
        if SeverActions_Follow.StartFollowing_IsEligible(target)
            FollowScript.StartFollowing(target)
        endif
    endif
EndFunction

; =============================================================================
; DISMISS HANDLER (single target)
; =============================================================================

Function HandleDismiss()
    if !FollowerManagerScript
        FollowerManagerScript = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
    endif

    if !FollowerManagerScript
        Debug.Notification("SeverActions: Follower Manager not configured!")
        return
    endif

    Actor target = GetTargetActor()

    if !target
        Debug.Notification("No valid target found")
        return
    endif

    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif

    ; Check if the target is a registered companion
    if !SeverActionsNativeExt.Native_GetIsFollower(target)
        Debug.Notification(target.GetDisplayName() + " is not your companion")
        return
    endif

    FollowerManagerScript.DismissCompanion(target)
EndFunction

; =============================================================================
; STAND UP HANDLER
; =============================================================================

Function HandleStandUp()
    if !FurnitureScript
        Debug.Notification("SeverActions: Furniture script not configured!")
        return
    endif
    
    Actor target = GetTargetActor()
    
    if !target
        Debug.Notification("No valid target found")
        return
    endif
    
    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif
    
    ; Check if they're using furniture
    if SeverActions_Furniture.StopUsingFurniture_IsEligible(target)
        FurnitureScript.StopUsingFurniture_Execute(target)
        ; Notification is handled by the furniture script via SkyrimNet event
    else
        Debug.Notification(target.GetDisplayName() + " is not using furniture")
    endif
EndFunction

; =============================================================================
; USE FURNITURE HANDLER (two-step: aim at NPC, then aim at furniture)
; =============================================================================

Function HandleUseFurniture()
    if !FurnitureScript
        Debug.Notification("SeverActions: Furniture script not configured!")
        return
    endif

    Actor player = Game.GetPlayer()
    ObjectReference ref = Game.GetCurrentCrosshairRef()
    Actor crosshairActor = ref as Actor

    ; Is a selection still live (NPC picked recently, awaiting furniture)?
    Bool pendingLive = PendingFurnitureUser != None && !PendingFurnitureUser.IsDead() \
        && (Utility.GetCurrentRealTime() - PendingFurnitureTime) < PendingFurnitureWindow

    if pendingLive
        ; STEP 2 — aiming at furniture sends the selected NPC to use it.
        if ref && (ref.GetBaseObject() as Furniture) && crosshairActor == None
            if ref.IsFurnitureInUse()
                Debug.Notification("That furniture is already in use")
                return
            endif
            Actor user = PendingFurnitureUser
            PendingFurnitureUser = None
            FurnitureScript.UseFurnitureRef_Execute(user, ref)
            Debug.Notification(user.GetDisplayName() + " is heading to " + ref.GetBaseObject().GetName())
            return
        elseif crosshairActor != None && crosshairActor != player && !crosshairActor.IsDead()
            ; Re-aimed at a different NPC — switch the selection instead.
            PendingFurnitureUser = crosshairActor
            PendingFurnitureTime = Utility.GetCurrentRealTime()
            Debug.Notification("Selected " + crosshairActor.GetDisplayName() + " - now aim at furniture and press again")
            return
        else
            Debug.Notification("Aim at a piece of furniture, then press again")
            return
        endif
    endif

    ; STEP 1 — pick the NPC under the crosshair.
    if crosshairActor != None && crosshairActor != player && !crosshairActor.IsDead()
        PendingFurnitureUser = crosshairActor
        PendingFurnitureTime = Utility.GetCurrentRealTime()
        Debug.Notification("Selected " + crosshairActor.GetDisplayName() + " - now aim at furniture and press again")
    else
        Debug.Notification("Aim at an NPC, then press again on furniture")
    endif
EndFunction

; =============================================================================
; YIELD HANDLER
; =============================================================================

Function HandleYield()
    if !CombatScript
        Debug.Notification("SeverActions: Combat script not configured!")
        return
    endif

    Actor target = GetTargetActor()

    if !target
        Debug.Notification("No valid target found")
        return
    endif

    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif

    ; Check if yield can be performed (must be in combat)
    if CombatScript.Yield_IsEligible(target)
        CombatScript.Yield_Execute(target)
        Debug.Notification(target.GetDisplayName() + " has surrendered")
    else
        Debug.Notification(target.GetDisplayName() + " is not in combat")
    endif
EndFunction

; =============================================================================
; UNDRESS HANDLER
; =============================================================================

Function HandleUndress()
    if !OutfitScript
        Debug.Notification("SeverActions: Outfit script not configured!")
        return
    endif
    
    Actor target = GetTargetActor()
    
    if !target
        Debug.Notification("No valid target found")
        return
    endif
    
    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif
    
    ; Check if undress can be performed
    if OutfitScript.Undress_IsEligible(target)
        OutfitScript.Undress_Execute(target)
        Debug.Notification(target.GetDisplayName() + " - undressed")
    else
        Debug.Notification(target.GetDisplayName() + " cannot be undressed")
    endif
EndFunction

; =============================================================================
; DRESS HANDLER
; =============================================================================

Function HandleDress()
    if !OutfitScript
        Debug.Notification("SeverActions: Outfit script not configured!")
        return
    endif
    
    Actor target = GetTargetActor()
    
    if !target
        Debug.Notification("No valid target found")
        return
    endif
    
    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif
    
    ; Check if dress can be performed (has stored clothing)
    if OutfitScript.Dress_IsEligible(target)
        OutfitScript.Dress_Execute(target)
        Debug.Notification(target.GetDisplayName() + " - dressed")
    else
        Debug.Notification(target.GetDisplayName() + " has no stored clothing")
    endif
EndFunction

; =============================================================================
; SET COMPANION HANDLER
; =============================================================================

Function HandleSetCompanion()
    if !FollowerManagerScript
        ; Fallback: try to get instance
        FollowerManagerScript = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
    endif

    if !FollowerManagerScript
        Debug.Notification("SeverActions: Follower Manager script not configured!")
        return
    endif

    Actor target = GetTargetActor()

    if !target
        Debug.Notification("No valid target found")
        return
    endif

    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif

    ; Register as companion
    FollowerManagerScript.RegisterFollower(target)
EndFunction

; =============================================================================
; COMPANION WAIT HANDLER
; =============================================================================

Function HandleCompanionWait()
    if !FollowerManagerScript
        FollowerManagerScript = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
    endif

    if !FollowerManagerScript
        Debug.Notification("SeverActions: Follower Manager not configured!")
        return
    endif

    Actor target = GetTargetActor()

    if !target
        Debug.Notification("No valid target found")
        return
    endif

    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif

    ; Custom AI followers (Inigo, Lucien, Kaidan, Daegon-keyworded, etc.) — their
    ; own mods manage AI packages, so we MUST NOT apply SA's sandbox/follow on
    ; top. Without this short-circuit they fall into isCasual below, which calls
    ; FollowScript.Sandbox / StopSandbox directly — that bypasses the track-only
    ; branch in CompanionWait/CompanionFollow and either traps them in SA's
    ; sandbox (stand in place) or strips it on resume and lets SkyrimNet's
    ; FollowPlayer package fill the void. Route them through the FollowerManager
    ; helpers, which call CompanionStopFollowing + StopSandbox for cleanup and
    ; toggle the vanilla WaitingForPlayer AV that the custom mod's own package
    ; respects via standard DialogueFollower hooks.
    if FollowerManagerScript.IsTrackOnlyFollower(target)
        if target.GetAV("WaitingForPlayer") > 0
            FollowerManagerScript.CompanionFollow(target)
        else
            FollowerManagerScript.CompanionWait(target)
        endif
        return
    endif

    ; Route casual followers directly through FollowScript to avoid intermediary issues.
    ; Companions go through FollowerManager which handles alias/LinkedRef concerns.
    Bool isCasual = FollowScript && FollowScript.HasFollowPackage(target) && !FollowerManagerScript.IsRegisteredFollower(target)
    Bool isSandboxing = FollowScript && FollowScript.IsSandboxing(target)

    if isSandboxing
        ; Currently sandboxing — resume
        if isCasual || !FollowerManagerScript.IsRegisteredFollower(target)
            FollowScript.StopSandbox(target)
        else
            FollowerManagerScript.CompanionFollow(target)
        endif
    elseif target.GetAV("WaitingForPlayer") > 0
        ; Waiting (companion path) — resume
        FollowerManagerScript.CompanionFollow(target)
    else
        ; Not waiting — sandbox them
        if isCasual
            FollowScript.Sandbox(target)
        else
            FollowerManagerScript.CompanionWait(target)
        endif
    endif
EndFunction

; =============================================================================
; ASSIGN HOME HANDLER
; =============================================================================

Function HandleClearHome()
    {Crosshair-target Clear Home: wipe the home assignment of whatever NPC you
     are looking at, regardless of list state - a follower, a dismissed NPC, an
     NFF/track-only companion, or a townsperson the LLM home-assigned by mistake.
     Routes through FollowerManager.ClearHome (native SetHome "", sandbox/marker/
     bed release), so a stuck home sandbox lets go and NFF (or the NPC's own AI)
     takes back over.}
    if !FollowerManagerScript
        FollowerManagerScript = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
    endif
    if !FollowerManagerScript
        Debug.Notification("SeverActions: Follower Manager not configured!")
        return
    endif
    Actor target = GetTargetActor()
    if !target
        Debug.Notification("No valid target found")
        return
    endif
    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif
    if FollowerManagerScript.GetAssignedHome(target) == ""
        Debug.Notification(target.GetDisplayName() + " has no home assigned")
        return
    endif
    FollowerManagerScript.ClearHome(target)
    Debug.Notification("Cleared " + target.GetDisplayName() + "'s home")
EndFunction

Function HandleAssignHome()
    if !FollowerManagerScript
        FollowerManagerScript = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_FollowerManager
    endif

    if !FollowerManagerScript
        Debug.Notification("SeverActions: Follower Manager not configured!")
        return
    endif

    Actor target = GetTargetActor()
    if !target
        Debug.Notification("No valid target found")
        return
    endif

    if target == Game.GetPlayer()
        Debug.Notification("Cannot target yourself")
        return
    endif

    Location currentLoc = Game.GetPlayer().GetCurrentLocation()
    if currentLoc
        String locName = currentLoc.GetName()
        if locName != ""
            FollowerManagerScript.AssignHome(target, locName)
        else
            Debug.Notification("Current location has no name")
        endif
    else
        Debug.Notification("No location detected - try from inside a named area.")
    endif
EndFunction

; =============================================================================
; TARGET ACQUISITION
; =============================================================================

Actor Function GetTargetActor()
    if TargetMode == 0
        return GetCrosshairTarget()
    elseif TargetMode == 1
        return GetNearestNPC()
    elseif TargetMode == 2
        return GetLastTalkedTo()
    endif
    
    ; Default to crosshair
    return GetCrosshairTarget()
EndFunction

Actor Function GetCrosshairTarget()
    ; Get whatever the player is looking at
    ObjectReference crosshairRef = Game.GetCurrentCrosshairRef()
    
    if crosshairRef
        Actor target = crosshairRef as Actor
        if target && !target.IsDead()
            return target
        endif
    endif
    
    return None
EndFunction

Actor Function GetNearestNPC()
    Actor player = Game.GetPlayer()
    Actor nearest = None
    float nearestDist = NearestNPCRadius + 1.0
    
    Cell currentCell = player.GetParentCell()
    if currentCell
        int numRefs = currentCell.GetNumRefs(43) ; kActorCharacter
        int i = 0
        while i < numRefs
            Actor npc = currentCell.GetNthRef(i, 43) as Actor
            if npc && npc != player && !npc.IsDead() && npc.Is3DLoaded()
                float dist = player.GetDistance(npc)
                if dist < nearestDist
                    nearestDist = dist
                    nearest = npc
                endif
            endif
            i += 1
        endwhile
    endif
    
    return nearest
EndFunction

Actor Function GetLastTalkedTo()
    if LastTalkedTo && !LastTalkedTo.IsDead()
        return LastTalkedTo
    endif
    return None
EndFunction

; =============================================================================
; DIALOGUE TRACKING - Call from dialogue events to track last talked to
; =============================================================================

Function SetLastTalkedTo(Actor akActor)
    LastTalkedTo = akActor
EndFunction

; =============================================================================
; SINGLETON ACCESS
; =============================================================================

SeverActions_Hotkeys Function GetInstance() Global
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Hotkeys
EndFunction