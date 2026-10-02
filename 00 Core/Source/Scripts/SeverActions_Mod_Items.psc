Scriptname SeverActions_Mod_Items extends SeverActions_ModuleBase
{Provider of the "items" module (Items, Magic & Property): alias 266 of quest 0x000D62 (plan 3.0
 M-P). Init K3 runs its idempotent OnModuleLoad stages on every load (DR20); they forward to the
 module's host scripts, which register their own events (DR16). Loot's and SpellTeach's ticks
 arm on demand, so no tick name is watched.}

String Function BundleId()
    Return "items"
EndFunction

Int Function ContractVersion()
    ; A literal, never kContractVersion (see SeverActions_ModuleBase.kContractVersion).
    Return 1
EndFunction

Function OnModuleLoad(Int aiStage, Bool abNewGame)
    Parent.OnModuleLoad(aiStage, abNewGame)
    Quest q = GetOwningQuest()
    If !q
        Return
    EndIf
    If aiStage == 0
        ; The diary-viewer ModEvent registrations.
        SeverActions_Loot loot = q as SeverActions_Loot
        If loot
            loot.InitializeDiaryEvents()
        EndIf
    EndIf
    If aiStage == 1
        ; The pending-paralysis sweep: a save inside the alteration-failure window
        ; would otherwise bake Paralysis=1 in.
        SeverActions_SpellTeach spellTeach = q as SeverActions_SpellTeach
        If spellTeach
            spellTeach.Maintenance()
            Debug.Trace("[SeverActions] SpellTeach System initialized (pending-paralysis sweep run)")
        EndIf
    EndIf
EndFunction

Bool Function ServiceBool(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {"giveItem": akA walks to akB and hands over asArg (afArg = count, minimum 1), with the
     give animation. A caller without this module transfers the item directly instead.
     "giveItemForm": the same for a form given by FormID in asArg (signed decimal, GetFormEx),
     for an item a name lookup cannot find (the courier's retitled letter). False when the id
     resolves to nothing, so the caller hands it over directly.
     "useItem": akA eats or drinks the item named asArg from their own pack through
     Loot.UseItem_Execute (animation, SkyrimNet event, the survival.ateFood / survival.drank
     verb). Survival's auto-eat eats directly when this module is absent.}
    If asSvc != "giveItem" && asSvc != "useItem" && asSvc != "giveItemForm"
        Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
    EndIf
    SeverActions_Loot loot = GetOwningQuest() as SeverActions_Loot
    If asSvc == "useItem"
        Actor eater = akA as Actor
        If !loot || !eater || asArg == ""
            Return False
        EndIf
        ; UseItem_Execute returns nothing: resolve the name first, the way it will, so False
        ; means "eat it yourself" rather than a meal that never happened (True reads as fed).
        Form item = SeverActions_Loot.GetItemFormByName(eater, asArg)
        If !item || eater.GetItemCount(item) <= 0
            Return False
        EndIf
        loot.UseItem_Execute(eater, asArg)
        Return True
    EndIf
    Actor giver = akA as Actor
    Actor receiver = akB as Actor
    If !loot || !giver || !receiver || asArg == ""
        Return False
    EndIf
    Int count = afArg as Int
    If count < 1
        count = 1
    EndIf
    If asSvc == "giveItemForm"
        Form item = Game.GetFormEx(asArg as Int)
        If !item
            Return False
        EndIf
        loot.GiveItemForm_Execute(giver, receiver, item, count)
        Return True
    EndIf
    loot.GiveItem_Execute(giver, receiver, asArg, count)
    Return True
EndFunction

Event OnInit()
    ; Log only: setup runs from the load stages, since a re-added script gets no OnInit (DR20, F35).
    Debug.Trace("[SeverActions] provider items: bound (alias 266)")
EndEvent
