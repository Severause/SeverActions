Scriptname SeverActions_SpellCast extends Quest
{Dispatcher for CastSpell action. Resolves spell + target, allocates a free
per-slot caster alias, and hands off to SeverActions_SpellCastAlias which
drives the animated cast through a usemagic AI package.}

; =============================================================================
; PROPERTIES
; =============================================================================

ReferenceAlias Property SpellCastCaster00 Auto
ReferenceAlias Property SpellCastCaster01 Auto
ReferenceAlias Property SpellCastCaster02 Auto
ReferenceAlias Property SpellCastCaster03 Auto

Static Property XMarkerBase Auto
{FormID 0x3B from Skyrim.esm. Spawn template for aim markers.}

Int Property MaxAimDistance = 120 AutoReadOnly
{How far in front of the caster the aim marker is placed, in game units.}

; =============================================================================
; SINGLETON
; =============================================================================

SeverActions_SpellCast Function GetInstance() Global
    Quest kQuest = Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest
    Return kQuest as SeverActions_SpellCast
EndFunction

; =============================================================================
; MAIN ENTRY
; =============================================================================

Function CastSpell_Execute(Actor akCaster, String spellName, String targetName, Bool bDualCasting, Bool bHealToFull, Bool bUseMagicka)
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] CastSpell_Execute ENTRY caster=" + akCaster + " spellName='" + spellName + "' target='" + targetName + "'")
    If !akCaster || akCaster.IsDead()
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] caster invalid or dead — abort")
        Return
    EndIf
    If akCaster.IsInCombat()
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] " + akCaster.GetDisplayName() + " in combat — abort")
        SkyrimNetApi.DirectNarration(akCaster.GetDisplayName() + " won't stop to cast a spell while fighting.", akCaster)
        Return
    EndIf

    ; Spell must be known by the caster — prevents the LLM from summoning
    ; spells the NPC doesn't actually have.
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
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] no target resolved — placing aim marker")
        targetRef = PlaceAimMarker(akCaster)
        markerPlaced = (targetRef != None)
    EndIf
    If !targetRef
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] no target AND no aim marker — abort")
        Return
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] target=" + targetRef + " markerPlaced=" + markerPlaced)

    ; The cast is visible in-game (animation + projectile + sound), so we
    ; deliberately DON'T register a SkyrimNet event here. Doing so would
    ; pollute the LLM context with a redundant "X casts Y" line for every
    ; cast — the engine's own anim graph already tells the LLM something
    ; happened via the action invocation. Failure paths still narrate via
    ; DirectNarration so the player knows WHY a cast didn't happen.
    _DispatchOneCast(akCaster, spellToCast, targetRef, bDualCasting, bUseMagicka, bHealToFull, markerPlaced)
EndFunction

; =============================================================================
; SLOT DISPATCH
; =============================================================================

; Returns true if the cast actually started (alias filled, package bound,
; injection succeeded, polling armed). Returns false on full slots or any
; precondition failure.
;
; CRITICAL ORDER (mirrors bosn's clonePackageSpell pattern, comment in his
; _bosnCustomActions_CastSpell.psc:39 — "Need to change package before
; filling the alias"):
;   1. Magicka pre-check
;   2. Resolve the live SlotPackage and bind it to the alias property
;   3. Inject the spell into the package
;   4. Fill the target alias
;   5. ONLY THEN fill the caster alias (ForceRefTo)
;   6. Hand off to StartCast for polling-state init
;
; Filling the caster alias triggers the engine's package re-evaluation
; immediately. If the package still has the placeholder Healing spell at
; that moment, the UseMagic procedure starts with the wrong data and the
; cast silently aborts. Same for the target alias — must be filled before
; the engine evaluates so it has a valid target.
Bool Function _DispatchOneCast(Actor akCaster, Spell akSpell, ObjectReference akTarget, Bool bDualCasting, Bool bUseMagicka, Bool bHealToFull, Bool bMarkerIsTarget)
    ReferenceAlias slot = FindFreeSlot()
    If !slot
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] FindFreeSlot returned None — all 4 slots busy")
        SkyrimNetApi.DirectNarration(akCaster.GetDisplayName() + " is too busy to cast right now.", akCaster)
        Return false
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] _DispatchOneCast: assigned slot " + slot + " to " + akCaster.GetDisplayName())

    ; (1) Magicka pre-check — abort early if we can't pay the cost. Done
    ; here (instead of inside StartCast) so we don't pollute alias state
    ; with a half-set-up cast.
    If bUseMagicka
        Int spellCost = SeverActionsNative.Native_GetEffectiveMagickaCost(akCaster, akSpell, bDualCasting)
        If spellCost > akCaster.GetActorValue("Magicka")
            SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] " + akCaster.GetDisplayName() + " low magicka (" + akCaster.GetActorValue("Magicka") + " < " + spellCost + ") — abort")
            SkyrimNetApi.DirectNarration(akCaster.GetDisplayName() + " doesn't have enough magicka to cast that.", akCaster)
            Return false
        EndIf
    EndIf

    ; (2) Bind the live SlotPackage on the alias property. Reads the LIVE
    ; ESP every time so this is robust to package FormKey churn across
    ; regenerations (Papyrus alias properties get baked into the save).
    SeverActions_SpellCastAlias slotAlias = slot as SeverActions_SpellCastAlias
    Package livePackage = GetPackageForSlot(slot)
    If !livePackage
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] could not resolve live SlotPackage for slot " + slot)
        Return false
    EndIf
    slotAlias.SlotPackage = livePackage
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] rebound SlotPackage -> " + livePackage)

    ; (3) Clone the spell into a fresh runtime form, then inject the clone
    ; into the package. The original Requiem-distributed spell carries state
    ; (perk gates, hand-locked equipSlot, possibly engine-cached "won't cast"
    ; decisions) that prevents the UseMagic procedure from dispatching to
    ; MagicCaster::CastSpell — the procedure runs silently and the magic
    ; casters stay in state=0. The clone has the casting perk dropped and
    ; equipSlot set to EitherHand, mirroring bosn's clonePackageSpell.
    Spell castSpell = SeverActionsNative.Native_CloneSpellForCast(akCaster, akSpell, bDualCasting)
    If !castSpell
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] CloneSpellForCast returned None — falling back to original")
        castSpell = akSpell
    Else
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] cloned spell: " + castSpell)
    EndIf

    If !SeverActionsNative.Native_InjectSpellIntoPackage(livePackage, castSpell)
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] Native_InjectSpellIntoPackage returned false — abort")
        Return false
    EndIf
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] spell injected: " + castSpell)

    ; Drop dialogue packages so the cast package can take precedence.
    SkyrimNetApi.UnregisterPackage(akCaster, "TalkToPlayer")

    ; (4) Fill target alias BEFORE caster fill — engine looks up alias 120
    ; for UID 4 (Target) at evaluation time, which happens the moment we
    ; fill the caster alias next.
    If slotAlias.TargetAlias
        slotAlias.TargetAlias.ForceRefTo(akTarget)
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] target alias filled with " + akTarget)
    Else
        SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] WARNING TargetAlias not bound on slot")
    EndIf

    ; (5) NOW fill the caster alias. Engine re-evaluates packages
    ; immediately and the UseMagic procedure has the correct spell + target
    ; from the start.
    slot.ForceRefTo(akCaster)
    SeverActionsNative.Native_OutfitSlot_Log("[SpellCast] caster alias filled — engine should pick up package")

    ; (6) Hand off to alias for polling-state init. Pass the CLONED spell
    ; so heal-to-full and other downstream logic uses the same form the
    ; engine sees in the package.
    Return slotAlias.StartCastTracking(castSpell, akTarget, bDualCasting, bUseMagicka, bHealToFull, bMarkerIsTarget)
EndFunction

; Returns the live Package record for the given slot alias. Hard-codes the
; cast package FormIDs for SeverActions.esp — these are stable post-2.2.4.
; If they ever change again, update this map (or move to GetFormFromFile by
; EditorID via a native helper).
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

; Called by the alias when a heal-to-full cycle finishes and conditions are
; still right for another pass. Allocates a fresh slot since the completing
; alias just cleared itself.
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

; =============================================================================
; TARGET RESOLUTION
; =============================================================================

ObjectReference Function ResolveTarget(Actor akCaster, Spell spellToCast, String targetName)
    ; Self-delivered spells ignore targetName entirely
    If SeverActionsNative.Native_IsSelfDeliveredSpell(spellToCast)
        return akCaster as ObjectReference
    EndIf

    String trimmed = SeverActionsNative.TrimString(targetName)

    ; "self" or the caster's own display name => target is the caster.
    ; Previously "self" was lumped with "" and "none" and fell through to the
    ; aim-marker path, so "cast Healing on self" fired forward into space.
    If SeverActionsNative.StringEquals(trimmed, "self") || SeverActionsNative.StringEquals(trimmed, akCaster.GetDisplayName())
        return akCaster as ObjectReference
    EndIf

    ; Empty / "none" / "0" => no named target; caller places aim marker.
    If trimmed == "" || trimmed == "0" || SeverActionsNative.StringEquals(trimmed, "none")
        return None
    EndIf

    ; Try actor lookup first — ActorFinder handles nearby + NND + fuzzy
    Actor asActor = SeverActionsNative.FindActorByName(trimmed)
    If asActor
        return asActor as ObjectReference
    EndIf

    ; No named match. Caller will place an aim marker, which lets the caster
    ; fire an aimed spell at whatever they're looking at (including training
    ; dummies, corpses, etc. directly in front of them).
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
    Float angle = akCaster.GetAngleZ() * 0.0174533  ; degrees to radians
    Float dx = MaxAimDistance * Math.Sin(angle)
    Float dy = MaxAimDistance * Math.Cos(angle)
    marker.MoveTo(akCaster, dx, dy, akCaster.GetHeight() - 35.0)
    return marker
EndFunction
