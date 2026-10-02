Scriptname SeverActions_Hotkeys extends Quest
{Legacy shim of the hotkey system. The DLL's input sink matches and dispatches the hotkeys (HotkeySink, M-K);
 this script keeps ConfigMenuKey / ConfigMenuRequireShift as the legacy hosts of their settings rows, dead copies
 of the other keys and the target mode (their rows' legacy host is SeverActions_MCM; nothing outside this
 script reads them), and the safe-exit stubs older frames need. It registers nothing and names no module type.}

; === Hotkey settings: dead copies except the two ConfigMenu rows (Hotkey_GetCode reads the live codes) ===

int Property FollowToggleKey = -1 Auto Hidden
{Key code for toggling follow state. -1 = unset/disabled}

int Property DismissKey = -1 Auto Hidden
{Key code for dismissing target companion. -1 = unset/disabled}

int Property StandUpKey = -1 Auto Hidden
{Key code for making target NPC stand up from furniture. -1 = unset/disabled}

int Property UseFurnitureKey = -1 Auto Hidden
{Key code for the two-step "use furniture" hotkey (aim at the NPC, then at the furniture). -1 = unset.}

; Unused two-step use-furniture state: the travel module's hotkey dispatcher keeps the pending pick.
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
{Key code for the Tie / Untie toggle: frees the aimed-at captive (whoever bound them) or restrains an unbound
 NPC with the player as captor. -1 = unset/disabled}

int Property ConfigMenuKey = 9 Auto Hidden
{Key code for opening the SeverActions menu. Default: 9 (the 8 key). -1 = disabled}

bool Property ConfigMenuRequireShift = true Auto Hidden
{If true, Shift must be held with ConfigMenuKey. Default: true (Shift+8)}

int Property TargetMode = 0 Auto Hidden
{0 = Crosshair, 1 = Nearest NPC, 2 = Last talked to (see GetLastTalkedTo)}

float Property NearestNPCRadius = 500.0 Auto Hidden
{Radius to search for nearest NPC when using TargetMode 1}

Actor LastTalkedTo = None
bool Property IsRegistered = false Auto Hidden

; Key codes an older build registered (rides the save). Key registrations are form-keyed, shared by every
; script on 0D62, so never UnregisterForAllKeys (DR9). Nothing registers or releases a key now.
int[] RegisteredKeyCodes
; Never assigned: the value that clears RegisteredKeyCodes (an array is never set to None, check 6). Unused
; since RegisterKeys became a stub.
int[] NoCodes

Event OnInit()
    Debug.Trace("[SeverActions_Hotkeys] Initialized")
    RegisterKeys()
EndEvent

; No OnPlayerLoadGame here: a quest script never receives it (the load-time key sync is the DLL's, see below).

Function RegisterKeys()
    ; M-I-STUB 3.9.14-beta25 (P4-04): the DLL matches the hotkey codes (P4-02) and syncs the config-menu key with
    ; the settings file at session start (KernelSession); nothing registers or releases a key here any more (an
    ; older build's registrations stay in the save unheard).
EndFunction


Function SyncMenuKeyOnLoad()
    ; M-I-STUB 3.9.14-beta25 (P4-04): the DLL syncs the config-menu key with the settings file at session start
    ; (KernelSession -> MagelightBridge::SyncMenuKeyFromSave, the Authority rows ConfigMenuKey /
    ; configMenuRequireShift take the key in force).
EndFunction


; === Target acquisition: no caller in the pack (HotkeySink resolves hotkey targets natively) ===

Actor Function GetTargetActor()
    if TargetMode == 0
        return GetCrosshairTarget()
    elseif TargetMode == 1
        return GetNearestNPC()
    elseif TargetMode == 2
        return GetLastTalkedTo()
    endif
    
    return GetCrosshairTarget()
EndFunction

Actor Function GetCrosshairTarget()
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
    {TargetMode 2: the DLL's last dialogue partner (DialoguePartnerTracker.h; vanilla dialogue or SkyrimNet,
     whichever is newer), remembered in LastTalkedTo so there is a target right after a load.}
    Actor partner = SeverActionsNativeExt2.Native_GetLastDialoguePartner()
    if partner && partner != Game.GetPlayer()
        LastTalkedTo = partner
    endif
    if LastTalkedTo && !LastTalkedTo.IsDead()
        return LastTalkedTo
    endif
    return None
EndFunction

Function SetLastTalkedTo(Actor akActor)
    {Manual override; no caller. GetLastTalkedTo replaces it whenever the DLL knows a partner.}
    LastTalkedTo = akActor
EndFunction

SeverActions_Hotkeys Function GetInstance() Global
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Hotkeys
EndFunction

String Function BoolToStr(Bool b)
    {The "true"/"false" text a bool row's Authority feed takes. No caller; kept for an older build's frames.}
    If b
        Return "true"
    EndIf
    Return "false"
EndFunction
