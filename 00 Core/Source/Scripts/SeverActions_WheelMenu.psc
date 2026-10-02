Scriptname SeverActions_WheelMenu extends Quest
{Legacy shim of the quick wheel. The DLL's QuickWheelBridge is the only wheel (D8): it takes the
 key, draws the radial and routes a pick through HotkeySink (strArg wheel:<id>). This script keeps
 the key's legacy host property and the safe-exit stubs an older build's frames need; it registers
 nothing and names no module type.}

int Property WheelMenuKey = -1 Auto Hidden
{Legacy host of the WheelMenuKey settings row (the DLL owns the key). -1 = unset.}

bool Property IsRegistered = false Auto Hidden

; The code an older build registered for the UIExtensions wheel (-1 none, 0 a save from before
; the ownership fix). Unused; kept for that build's frames. Key registrations are form-keyed and
; Hotkeys shares quest 0D62, so never UnregisterForAllKeys here.
int RegisteredWheelKey = 0

; Option indices by wheel position.
int Property OPT_TOGGLE_FOLLOW = 0 AutoReadOnly
int Property OPT_DISMISS = 1 AutoReadOnly
int Property OPT_STAND_UP = 2 AutoReadOnly
int Property OPT_YIELD = 3 AutoReadOnly
int Property OPT_UNDRESS = 4 AutoReadOnly
int Property OPT_DRESS = 5 AutoReadOnly
int Property OPT_WAIT = 6 AutoReadOnly
int Property OPT_SET_COMPANION = 7 AutoReadOnly

Event OnInit()
    Debug.Trace("[SeverActions_WheelMenu] Initialized")
    RegisterWheelKey()
EndEvent

; No load handler: the DLL syncs the wheel key at session start (KernelSession).

Function RegisterWheelKey()
    ; M-I-STUB 3.9.14-beta25 (P4-04): the DLL owns the wheel key (P4-03) and syncs it with the settings file at
    ; session start (KernelSession -> QuickWheelBridge::SyncKeyFromSave); nothing is registered here.
EndFunction

bool Function IsUIExtensionsInstalled()
    ; M-I-STUB 3.9.14-beta25 (P4-03): the UIExtensions wheel is gone (D8); nothing asks any more.
    return false
EndFunction

Function OpenWheelMenu()
    ; M-I-STUB 3.9.14-beta25 (P4-03): the UIExtensions wheel is gone (D8) - the DLL's QuickWheelBridge draws the only
    ; wheel. A frame resumed in the old body finds no HandleWheelSelection (fomod/removed_functions.json): the VM
    ; logs it and answers a default, so the frame still runs to its end.
EndFunction

SeverActions_WheelMenu Function GetInstance() Global
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_WheelMenu
EndFunction