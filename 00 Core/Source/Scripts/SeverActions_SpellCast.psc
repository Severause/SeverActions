Scriptname SeverActions_SpellCast extends Quest
{Dispatcher for CastSpell action. Resolves spell + target, allocates a free
per-slot caster alias, and hands off to SeverActions_SpellCastAlias which
drives the animated cast through a usemagic AI package.}

ReferenceAlias Property SpellCastCaster00 Auto
ReferenceAlias Property SpellCastCaster01 Auto
ReferenceAlias Property SpellCastCaster02 Auto
ReferenceAlias Property SpellCastCaster03 Auto

Static Property XMarkerBase Auto
{FormID 0x3B from Skyrim.esm. Spawn template for aim markers.}

Int Property MaxAimDistance = 120 AutoReadOnly
{How far in front of the caster the aim marker is placed, in game units.}

SeverActions_SpellCast Function GetInstance() Global
    Quest kQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    Return kQuest as SeverActions_SpellCast
EndFunction

; The CastSpell action's entry (castspell.yaml).
Function CastSpell_Execute(Actor akCaster, String spellName, String targetName, Bool bDualCasting, Bool bHealToFull, Bool bUseMagicka)
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] CastSpell_Execute ENTRY caster=" + akCaster + " spellName='" + spellName + "' target='" + targetName + "'")
    If !akCaster || akCaster.IsDead()
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] caster invalid or dead - abort")
        Return
    EndIf
    If akCaster.IsInCombat()
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] " + akCaster.GetDisplayName() + " in combat - abort")
        SkyrimNetApi.DirectNarration(akCaster.GetDisplayName() + " won't stop to cast a spell while fighting.", akCaster)
        Return
    EndIf

    ; Only a spell the caster knows, so the LLM cannot invent one.
    Spell spellToCast = SeverActionsNative.FindSpellOnActor(akCaster, spellName) as Spell
    If !spellToCast
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] " + akCaster.GetDisplayName() + " doesn't know spell '" + spellName + "'")
        SkyrimNetApi.DirectNarration(akCaster.GetDisplayName() + " doesn't know the spell '" + spellName + "'.", akCaster)
        Return
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] resolved spell: " + spellToCast.GetName())

    ObjectReference targetRef = ResolveTarget(akCaster, spellToCast, targetName)
    Bool markerPlaced = false
    If !targetRef
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] no target resolved - placing aim marker")
        targetRef = PlaceAimMarker(akCaster)
        markerPlaced = (targetRef != None)
    EndIf
    If !targetRef
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] no target AND no aim marker - abort")
        Return
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] target=" + targetRef + " markerPlaced=" + markerPlaced)

    ; No SkyrimNet event for a cast: it is visible in game and the action call already reached the LLM,
    ; so an event would only add a redundant line. Failures narrate so the player learns why.
    _DispatchOneCast(akCaster, spellToCast, targetRef, bDualCasting, bUseMagicka, bHealToFull, markerPlaced)
EndFunction

; === Slot dispatch ===

; Starts one cast on a free slot: TRUE once the alias is armed, FALSE when all slots are busy or a
; precondition fails. ORDER MATTERS (bosn's clonePackageSpell pattern): bind the package and inject the
; spell, fill the target alias, and only then fill the caster alias. The caster fill re-evaluates packages
; at once; if the package still holds its placeholder spell or the target alias is empty, UseMagic starts
; with the wrong data and the cast silently aborts.
Bool Function _DispatchOneCast(Actor akCaster, Spell akSpell, ObjectReference akTarget, Bool bDualCasting, Bool bUseMagicka, Bool bHealToFull, Bool bMarkerIsTarget)
    ReferenceAlias slot = FindFreeSlot()
    If !slot
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] FindFreeSlot returned None - all 4 slots busy")
        SkyrimNetApi.DirectNarration(akCaster.GetDisplayName() + " is too busy to cast right now.", akCaster)
        _AbortCastCleanup(akCaster, akTarget, bMarkerIsTarget, None)
        Return false
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] _DispatchOneCast: assigned slot " + slot + " to " + akCaster.GetDisplayName())

    ; (1) Magicka pre-check, before any alias state is touched.
    If bUseMagicka
        Int spellCost = SeverActionsNativeExt.Native_GetEffectiveMagickaCost(akCaster, akSpell, bDualCasting)
        If spellCost > akCaster.GetActorValue("Magicka")
            SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] " + akCaster.GetDisplayName() + " low magicka (" + akCaster.GetActorValue("Magicka") + " < " + spellCost + ") - abort")
            SkyrimNetApi.DirectNarration(akCaster.GetDisplayName() + " doesn't have enough magicka to cast that.", akCaster)
            _AbortCastCleanup(akCaster, akTarget, bMarkerIsTarget, None)
            Return false
        EndIf
    EndIf

    ; (2) Rebind the alias's SlotPackage to the live package (see GetPackageForSlot).
    SeverActions_SpellCastAlias slotAlias = slot as SeverActions_SpellCastAlias
    Package livePackage = GetPackageForSlot(slot)
    If !livePackage
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] could not resolve live SlotPackage for slot " + slot)
        _AbortCastCleanup(akCaster, akTarget, bMarkerIsTarget, None)
        Return false
    EndIf
    slotAlias.SlotPackage = livePackage
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] rebound SlotPackage -> " + livePackage)

    ; (3) Inject a runtime clone, not the original: a distributed spell's (e.g. Requiem's) casting perk or
    ; hand-locked equip slot can stop UseMagic from ever reaching MagicCaster::CastSpell (it runs silently,
    ; the casters stay in state 0). The clone drops the perk and uses the EitherHand slot.
    Spell castSpell = SeverActionsNativeExt.Native_CloneSpellForCast(akCaster, akSpell, bDualCasting)
    Bool usedClone = (castSpell != None)
    If !castSpell
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] CloneSpellForCast returned None - falling back to original")
        castSpell = akSpell
    Else
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] cloned spell: " + castSpell)
    EndIf

    ; Tell SpellCastAlias.CleanupCast whether this is a clone: its RemoveSpell on the original would delete
    ; the NPC's real spell. Set or unset once per cast so no stale flag leaks in.
    If usedClone
        StorageUtil.SetIntValue(akCaster, "SeverSpellCast_WasCloned", 1)
    Else
        StorageUtil.UnsetIntValue(akCaster, "SeverSpellCast_WasCloned")
    EndIf

    If !SeverActionsNativeExt.Native_InjectSpellIntoPackage(livePackage, castSpell)
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] Native_InjectSpellIntoPackage returned false - abort")
        Spell cloneToRemove = None
        If usedClone
            cloneToRemove = castSpell
        EndIf
        _AbortCastCleanup(akCaster, akTarget, bMarkerIsTarget, cloneToRemove)
        Return false
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] spell injected: " + castSpell)

    ; Drop dialogue packages so the cast package can take precedence.
    SkyrimNetApi.UnregisterPackage(akCaster, "TalkToPlayer")

    ; (4) Target alias first: the package's Target (UID 4) resolves through the slot's target alias
    ; (ids 120-123) when the caster fill below triggers evaluation.
    If slotAlias.TargetAlias
        slotAlias.TargetAlias.ForceRefTo(akTarget)
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] target alias filled with " + akTarget)
    Else
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] WARNING TargetAlias not bound on slot")
    EndIf

    ; (5) Now the caster alias.
    slot.ForceRefTo(akCaster)
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] caster alias filled - engine should pick up package")
    ; The schedule quests (priority 101) outrank this caster alias: a caster the schedule holds comes off it, and the
    ; reconcile keeps her off while she holds the slot.
    SeverActions_ModuleBase.CallBool("followers", "leaveSchedule", akCaster)

    ; ForceRefTo should re-evaluate by itself, but on a registered companion (whose follow alias package
    ; competes) the engine can keep the old package until the next AI tick. Harmless when it already switched.
    akCaster.EvaluatePackage()

    ; (6) Hand off to the alias for polling, with the spell the package holds.
    Return slotAlias.StartCastTracking(castSpell, akTarget, bDualCasting, bUseMagicka, bHealToFull, bMarkerIsTarget)
EndFunction

; Early-return cleanup for _DispatchOneCast: until StartCastTracking arms the alias nothing else owns what
; we created, so delete our aim marker (a persistent XMarker would leak per failed cast) and remove the clone.
Function _AbortCastCleanup(Actor akCaster, ObjectReference akTarget, Bool bMarkerIsTarget, Spell akClone)
    If bMarkerIsTarget && akTarget
        akTarget.Disable()
        akTarget.Delete()
    EndIf
    If akClone && akCaster
        akCaster.RemoveSpell(akClone)
        StorageUtil.UnsetIntValue(akCaster, "SeverSpellCast_WasCloned")
    EndIf
EndFunction

; The slot's cast package, read from the ESP by FormID on every cast: the alias's SlotPackage property is
; baked into the save and goes stale if the packages are regenerated. Update this map if their FormIDs move.
Package Function GetPackageForSlot(ReferenceAlias slot)
    If slot == SpellCastCaster00
        return Game.GetFormFromFile(0x00156039, "SeverActions.esp") as Package
    ElseIf slot == SpellCastCaster01
        return Game.GetFormFromFile(0x0015603A, "SeverActions.esp") as Package
    ElseIf slot == SpellCastCaster02
        return Game.GetFormFromFile(0x0015603B, "SeverActions.esp") as Package
    ElseIf slot == SpellCastCaster03
        return Game.GetFormFromFile(0x0015603C, "SeverActions.esp") as Package
    EndIf
    return None
EndFunction

; SpellCastAlias calls this for the next heal-to-full pass. Takes any free slot: the finishing alias has
; already cleared itself.
Function RecastSameSlot(Actor akCaster, Spell akSpell, ObjectReference akTarget, Bool bDualCasting, Bool bUseMagicka, Bool bHealToFull)
    If !akCaster || !akSpell || !akTarget
        Return
    EndIf
    _DispatchOneCast(akCaster, akSpell, akTarget, bDualCasting, bUseMagicka, bHealToFull, false)
EndFunction

ReferenceAlias Function FindFreeSlot()
    If SpellCastCaster00 && !SpellCastCaster00.GetActorRef()
        return SpellCastCaster00
    EndIf
    If SpellCastCaster01 && !SpellCastCaster01.GetActorRef()
        return SpellCastCaster01
    EndIf
    If SpellCastCaster02 && !SpellCastCaster02.GetActorRef()
        return SpellCastCaster02
    EndIf
    If SpellCastCaster03 && !SpellCastCaster03.GetActorRef()
        return SpellCastCaster03
    EndIf
    return None
EndFunction

; === Target resolution ===

ObjectReference Function ResolveTarget(Actor akCaster, Spell spellToCast, String targetName)
    ; Self-delivered spells ignore targetName.
    If SeverActionsNativeExt.Native_IsSelfDeliveredSpell(spellToCast)
        return akCaster as ObjectReference
    EndIf

    String trimmed = SeverActionsNative.TrimString(targetName)

    ; "self" or the caster's own name => the caster (not the aim-marker path below).
    If SeverActionsNative.StringEquals(trimmed, "self") || SeverActionsNative.StringEquals(trimmed, akCaster.GetDisplayName())
        return akCaster as ObjectReference
    EndIf

    ; Empty / "none" / "0" => no named target; caller places aim marker.
    If trimmed == "" || trimmed == "0" || SeverActionsNative.StringEquals(trimmed, "none")
        return None
    EndIf

    ; FindActorByName covers nearby actors, NND names and fuzzy matches.
    Actor asActor = SeverActionsNative.FindActorByName(trimmed)
    If asActor
        return asActor as ObjectReference
    EndIf

    ; No match: the caller places an aim marker, so the spell fires at whatever is in front of the caster.
    return None
EndFunction

ObjectReference Function PlaceAimMarker(Actor akCaster)
    If !XMarkerBase
        XMarkerBase = Game.GetFormFromFile(0x00003B, "Skyrim.esm") as Static
    EndIf
    If !XMarkerBase
        return None
    EndIf
    ObjectReference marker = akCaster.PlaceAtMe(XMarkerBase, 1, true, false)
    If !marker
        return None
    EndIf
    ; Math.Sin/Cos take DEGREES, as GetAngleZ returns: no radians conversion.
    Float angle = akCaster.GetAngleZ()
    Float dx = MaxAimDistance * Math.Sin(angle)
    Float dy = MaxAimDistance * Math.Cos(angle)
    marker.MoveTo(akCaster, dx, dy, akCaster.GetHeight() - 35.0)
    return marker
EndFunction
