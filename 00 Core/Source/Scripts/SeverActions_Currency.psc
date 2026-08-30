Scriptname SeverActions_Currency extends Quest
{Currency/gold action handlers for SkyrimNet integration - by Severause}

; =============================================================================
; PROPERTIES
; =============================================================================

MiscObject Property Gold001 Auto
{Gold coin - set to Gold001 (0x0000000F) in CK, or leave empty for auto-lookup}

Idle Property IdleGive Auto
{Animation for giving gold}

Idle Property IdleTake Auto
{Animation for taking/receiving gold}

Idle Property IdleThreaten Auto
{Animation for threatening/demanding (optional)}

Sound Property GoldSound Auto
{Sound effect for gold transactions}

Bool Property UseGiveAnimation = True Auto
Bool Property UseTakeAnimation = True Auto
Bool Property UseThreatenAnimation = True Auto
Bool Property UseGoldSound = True Auto
Float Property AnimDelay = 0.6 Auto

; Conjured Gold - allows NPCs to give gold they don't have.
; Ships OFF as of dev141 (user decision: with retainers, camps, stewards and
; the NPC labor economy all minting real coin, defaulting the money printer
; on no longer makes sense). Existing saves keep whatever the player chose -
; this default only governs new games / fresh installs.
Bool Property AllowConjuredGold = False Auto

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Currency] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    if Gold001 == None
        Gold001 = Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as MiscObject
        if Gold001 == None
            Debug.Trace("[SeverActions_Currency] ERROR: Could not find Gold001!")
        else
            Debug.Trace("[SeverActions_Currency] Gold001 found via auto-lookup")
        endif
    endif

    ; CollectPayment now prefers a non-pausing PrismaUI overlay over
    ; SkyMessage when PrismaUI is available; the bridge posts the player's
    ; choice back via SeverActions_CollectPaymentChoice. Register on every
    ; Maintenance pass — RegisterForModEvent is idempotent and the script
    ; instance can lose its registration across save/load on edge cases.
    RegisterForModEvent("SeverActions_CollectPaymentChoice", "OnCollectPaymentChoice")
    ; The Final Audit / Levy listeners are registered in ONE place - OnGameLoaded,
    ; which RunLoadRecovery calls on both new games and loads. Do not add a
    ; partial copy here: an incomplete duplicate list is how a new listener ends
    ; up bound in only one place and silently never fires.
EndFunction

Function OnGameLoaded()
    {Load recovery (SeverActions_Init.RunLoadRecovery). Maintenance() is only
     ever called from OnInit, which never re-fires on an existing save, so the
     Final Audit listeners registered there were DEAD for every current player
     - the native side logged its deploy and Papyrus never heard it. Register
     here, and re-apply the court package directly so the detail's AI never
     depends on an event landing at all.}
    RegisterForModEvent("SeverActions_FinalAuditArrived", "OnFinalAuditArrived")
    RegisterForModEvent("SeverActions_FinalAuditDeployed", "OnFinalAuditDeployed")
    RegisterForModEvent("SeverActions_FinalAuditApproach", "OnFinalAuditApproach")
    RegisterForModEvent("SeverActions_FinalAuditStandDown", "OnFinalAuditStandDown")
    RegisterForModEvent("SeverActions_FinalAuditEscortMode", "OnFinalAuditEscortMode")
    RegisterForModEvent("SeverActions_LevySquadDwell", "OnLevySquadDwell")
    String auditState = SeverActionsNativeExt2.Venture_Audit_State()
    If auditState == "casebuilding"
        ApplyFinalAuditCourtPackage()
    ElseIf auditState == "approaching" || auditState == "demanding"
        ; Mid-approach or mid-standoff across a save boundary: put the march
        ; packages back, not the court sandbox.
        ;
        ; UNLESS HE IS STILL WALKING. The approach is a real orchestrator
        ; journey now, and it survives a save: the follow package sits at
        ; priority 110 while the Traveler_NN pool alias is 106, so applying
        ; the march here would outrank the travel package and stop the walk
        ; dead a hold away from the player. Native answers from ground truth
        ; (does the General have a live travel session), not a cosaved flag,
        ; and fires SeverActions_FinalAuditApproach itself when he arrives.
        If !SeverActionsNativeExt2.Venture_Audit_IsTraveling()
            ApplyFinalAuditApproachPackages()
        Else
            Debug.Trace("[SeverActions] Final Audit: the General is still on the road - march packages held back")
        EndIf
    ElseIf auditState == "paid"
        ; Paid is terminal, so the native tick stops looking at the detail
        ; entirely - if the stand-down event was ever dropped they would keep
        ; the priority-110 march overrides and drawn weapons FOREVER. Re-run
        ; the stand-down on every load; it is idempotent.
        StandDownFinalAudit()
    EndIf
EndFunction

Function ApplyFinalAuditCourtPackage()
    {Give the GENERAL the court sandbox as a package override, and post the
     escort on him via EnsureFinalAuditEscort
     (priority 100, the home-sandbox tier). An override is REQUIRED: their
     TPLT template makes the engine ignore the base record's own package list
     and serve the chain's DefaultStayAtEditorLocationSkipFallout instead.
     Idempotent - PO3 cosaves overrides and re-adding the same package is
     harmless, so both the load path and the deploy event may call this.}
    Package courtPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    If !courtPkg
        Debug.Trace("[SeverActions] Final Audit: court package 0x165676 missing")
        Return
    EndIf
    ; THE GENERAL ONLY. The court sandbox used to go on all three, and that is
    ; what left the two Legates standing in the road after a payment: their
    ; formation LinkedRef anchors to CASSIUS, not to the court marker, so the
    ; work sandbox told them to mill about wherever Cassius happened to be
    ; standing at the instant it was applied - and a sandbox does not chase a
    ; moving anchor, so when he walked off to Dragonsreach they simply stayed.
    ; The escort keeps the Follow package instead (see EnsureFinalAuditEscort).
    Actor general = SeverActionsNativeExt2.Venture_Audit_Collector(0)
    If general && !general.IsDead()
        ActorUtil.AddPackageOverride(general, courtPkg, 100, 1)
        general.EvaluatePackage()
    EndIf
    EnsureFinalAuditEscort()
    PostFinalAuditGarrisons()
    Debug.Trace("[SeverActions] Final Audit: court package on the General, escort following him, garrisons posted")
EndFunction

Int Function FinalAuditEscortSize() Global
    {How far the ESCORT loops run over Venture_Audit_Collector: the trio only.
     0 is the General (escorted, not escorting), 1-2 are the Legates.

     The twelve seconded soldiers are indices 3-14 and are deliberately NOT in
     these loops - they garrison five holds and never march, draw, or follow.
     Their orders are PostFinalAuditGarrisons().}
    Return 3
EndFunction

Int Function FinalAuditGarrisonFirst() Global
    {First Venture_Audit_Collector index of the twelve.}
    Return 3
EndFunction

Int Function FinalAuditGarrisonLast() Global
    {One past the last garrison index.}
    Return 15
EndFunction

Function PostFinalAuditGarrisons()
    {Hand the twelve over to their PATROL ALIASES by clearing the standing
     overrides off them.

     They are templated (Traits) with NO package list of their own, so the
     engine would otherwise serve the template chain's
     DefaultStayAtEditorLocationSkipFallout and they would stand where they were
     put forever. That used to be answered with a work-sandbox override; it is
     now answered by alias packages on SeverActions_LevyPatrolQuest (16AC46) -
     the five leaders carry their city's patrol package, the other seven a
     follow package aimed at their leader, and native seats them in the pool.

     WHY THE OVERRIDE HAS TO GO, not just change: alias-package precedence comes
     from the owning quest's DNAM priority, which is 95 here. A priority-100
     override outranks it, so leaving 16AC45 applied would mean the patrols
     never run and the twelve would look exactly as they did before - the most
     confusing possible failure, because every log line would say the pool was
     seated correctly.

     The dwell is the same mechanism in reverse: native re-applies 16AC45's
     sibling (16AC4B, same r4096 sandbox retargeted at the patrol quest) at
     priority 100 for a couple of game hours, which outranks the patrol on
     purpose, then removes it and the squad moves off again. See
     OnLevySquadDwell.

     Idempotent - PO3 cosaves overrides, so the load path and the deploy event
     may both call this.}
    ; Both historical overrides come off: 165676 (the r1200 court sandbox the
    ; first garrison build handed them) and 16AC45 (the r4096 replacement).
    ; RemovePackageOverride on an absent package is a no-op, so this is safe on
    ; a save that never had either.
    Package courtPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Package workPkg = Game.GetFormFromFile(0x0016AC45, "SeverActions.esp") as Package
    Int i = FinalAuditGarrisonFirst()
    Int last = FinalAuditGarrisonLast()
    Int posted = 0
    While i < last
        Actor s = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If s && !s.IsDead()
            If courtPkg
                ActorUtil.RemovePackageOverride(s, courtPkg)
            EndIf
            If workPkg
                ActorUtil.RemovePackageOverride(s, workPkg)
            EndIf
            s.EvaluatePackage()
            posted += 1
        EndIf
        i += 1
    EndWhile
    Debug.Trace("[SeverActions] Levy garrison: " + posted + " soldiers released to their patrol aliases")
EndFunction

Event OnLevySquadDwell(String eventName, String strArg, Float numArg, Form sender)
    {A squad settles for a couple of game hours, or moves off again. One event
     per soldier, sender being that soldier - native decides who is in which
     squad and this handler never re-derives it, so the two sides cannot drift
     on that rule.

     The dwell package is 16AC4B, the same r4096 work sandbox as 16AC45 but with
     its QNAM on the patrol quest. Applied at priority 100 it outranks the
     alias patrol (quest priority 95), which is exactly the point; removing it
     drops the soldier straight back onto their patrol or follow package with no
     second call needed. Native moves the squad's hold anchor onto the leader
     first, so they mill around wherever the patrol actually stopped rather than
     being pulled back to the city's map marker.}
    Actor s = sender as Actor
    If !s || s.IsDead()
        Return
    EndIf
    Package dwellPkg = Game.GetFormFromFile(0x0016AC4B, "SeverActions.esp") as Package
    If !dwellPkg
        Debug.Trace("[SeverActions] Levy dwell: package 0x16AC4B missing")
        Return
    EndIf
    If strArg == "dwell"
        ActorUtil.AddPackageOverride(s, dwellPkg, 100, 1)
    Else
        ActorUtil.RemovePackageOverride(s, dwellPkg)
    EndIf
    s.EvaluatePackage()
EndEvent

Function EnsureFinalAuditEscort()
    {THE TWO LEGATES ONLY. They follow Cassius always - marching, standing,
     holding court, walking home. There is no state in which his personal
     escort should be somewhere other than where their General is.

     THE TWELVE SECONDED SOLDIERS ARE NOT IN THIS FUNCTION and must not be
     added to it. They garrison five holds and patrol their own cities from
     alias packages on SeverActions_LevyPatrolQuest; see
     PostFinalAuditGarrisons and OnLevySquadDwell. The loop below bounds on
     FinalAuditEscortSize() (3) precisely to exclude them - the twelve are
     indices 3-14 and are reached through FinalAuditGarrisonFirst/Last instead.

     Do not "fix" that bound to match a comment. Anchoring the twelve to
     Cassius was the first design and it was wrong: the work sandbox mills an
     actor around whatever it is linked to, so linking all twelve to the
     General collapsed the entire garrison into whichever room he settled in,
     which is the opposite of the point of having them.

     The package is the vanilla Follow template (SeverActions_GuardBodyguard,
     0x165677 -> Skyrim.esm 0x019B2C), which already behaves the way a follower
     does: close the distance when the target moves off, mill about near them
     when the target stops. That is the follow/sandbox split by itself, from
     the engine, with nothing for us to tick - the user asked for NFF's
     follow-then-sandbox feel and this template IS that behaviour.

     Idempotent: PO3 cosaves overrides, so re-adding the same package is a
     no-op and every audit path may call this.}
    Package guardPkg = Game.GetFormFromFile(0x00165677, "SeverActions.esp") as Package
    Keyword followKw = Game.GetFormFromFile(0x00030155, "SeverActions.esp") as Keyword
    Actor cassius    = SeverActionsNativeExt2.Venture_Audit_Collector(0)
    If !guardPkg || !followKw || !cassius
        Debug.Trace("[SeverActions] Final Audit: escort package/keyword/General missing")
        Return
    EndIf
    ; Do not post an escort on a corpse. If the General fell, the Follow package
    ; has nothing to close on and the audit is over anyway - leave whatever is
    ; left of the detail to the "dead" branch of their orders.
    If cassius.IsDead()
        Debug.Trace("[SeverActions] Final Audit: General is dead - escort left as-is")
        Return
    EndIf
    Int i = 1
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor escort = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If escort && !escort.IsDead()
            SeverActionsNativeExt.LinkedRef_SetPermanent(escort, cassius, followKw)
            ActorUtil.AddPackageOverride(escort, guardPkg, 110, 1)
            escort.EvaluatePackage()
        EndIf
        i += 1
    EndWhile
EndFunction

Event OnFinalAuditEscortMode(String eventName, String strArg, Float numArg, Form sender)
    {The General started moving, or has settled. strArg = "follow" | "sandbox".
     Native watches his position and fires this only on a CHANGE, so this does
     not re-apply overrides every second.}
    SetFinalAuditEscortSandbox(strArg == "sandbox")
EndEvent

Function SetFinalAuditEscortSandbox(Bool abSandbox)
    {Swap the escort between marching and standing easy.

     Vanilla's Follow template does NOT sandbox when its target stops - a
     vanilla follower just stands there, which is exactly how the two Legates
     ended up at attention in front of a seated Cassius. So the idle half is a
     package swap rather than something the Follow package gives us.

     The sandbox needs no new record. The escort's formation LinkedRef already
     anchors them to CASSIUS under the work-anchor keyword, so the court
     WorkSandbox makes them mill about HIM wherever he happens to be. That same
     anchoring is why it cannot simply be left on: a sandbox does not chase a
     moving anchor, which is what stranded them in the road when he walked home.

     One override must be REMOVED for the other to win - both would otherwise
     stack and the higher priority (Follow, 110) would always take it.}
    Package courtPkg = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Package guardPkg = Game.GetFormFromFile(0x00165677, "SeverActions.esp") as Package
    Actor cassius    = SeverActionsNativeExt2.Venture_Audit_Collector(0)
    If !courtPkg || !guardPkg || !cassius || cassius.IsDead()
        Return
    EndIf
    Int i = 1
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor escort = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If escort && !escort.IsDead()
            If abSandbox
                ActorUtil.RemovePackageOverride(escort, guardPkg)
                ActorUtil.AddPackageOverride(escort, courtPkg, 100, 1)
            Else
                ActorUtil.RemovePackageOverride(escort, courtPkg)
                ActorUtil.AddPackageOverride(escort, guardPkg, 110, 1)
            EndIf
            escort.EvaluatePackage()
        EndIf
        i += 1
    EndWhile
    If abSandbox
        Debug.Trace("[SeverActions] Final Audit escort standing easy - sandboxing around the General")
    Else
        Debug.Trace("[SeverActions] Final Audit escort marching - following the General")
    EndIf
EndFunction

Event OnFinalAuditDeployed(String eventName, String strArg, Float numArg, Form sender)
    {The detail just deployed mid-session (case opened). Same application the
     load path uses.}
    ApplyFinalAuditCourtPackage()
EndEvent

Function ApplyFinalAuditApproachPackages()
    {The march: Cassius takes the close-follow package on the player and walks
     them down; the two Legates take the bodyguard package linked to Cassius,
     so the formation holds on its own and only ONE actor is ever steered.
     Priority 110 outranks the court sandbox (100) - the sandbox override is
     also removed so nothing competes.}
    Package courtPkg  = Game.GetFormFromFile(0x00165676, "SeverActions.esp") as Package
    Package followPkg = Game.GetFormFromFile(0x0016567C, "SeverActions.esp") as Package
    Package guardPkg  = Game.GetFormFromFile(0x00165677, "SeverActions.esp") as Package
    Keyword followKw  = Game.GetFormFromFile(0x00030155, "SeverActions.esp") as Keyword
    If !followPkg || !guardPkg || !followKw
        Debug.Trace("[SeverActions] Final Audit: approach packages/keyword missing")
        Return
    EndIf
    Actor cassius = SeverActionsNativeExt2.Venture_Audit_Collector(0)
    If cassius && !cassius.IsDead()
        If courtPkg
            ActorUtil.RemovePackageOverride(cassius, courtPkg)
        EndIf
        ActorUtil.AddPackageOverride(cassius, followPkg, 110, 1)
        cassius.EvaluatePackage()
    EndIf
    ; The escort needs no state change - they already follow him, and the
    ; formation holds because only ONE actor is ever steered. Strip any court
    ; sandbox left on them by an older save, then re-assert the Follow package.
    Int i = 1
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor escort = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If escort && !escort.IsDead() && courtPkg
            ActorUtil.RemovePackageOverride(escort, courtPkg)
        EndIf
        i += 1
    EndWhile
    EnsureFinalAuditEscort()
    Debug.Trace("[SeverActions] Final Audit approach packages applied - the detail is marching")
EndFunction

Event OnFinalAuditApproach(String eventName, String strArg, Float numArg, Form sender)
    {Grace lapsed - they set out for the player.}
    ApplyFinalAuditApproachPackages()
EndEvent

Event OnFinalAuditStandDown(String eventName, String strArg, Float numArg, Form sender)
    {Paid, or the audit withdrew unresolved. Hand the detail back to the court.}
    StandDownFinalAudit()
EndEvent

Function StandDownFinalAudit()
    {Sheathe, drop the march packages, and restore the court sandbox so the
     detail walks home to Dragonsreach. Idempotent - both the stand-down event
     and the load path call it.}
    Package followPkg = Game.GetFormFromFile(0x0016567C, "SeverActions.esp") as Package
    ; No guardPkg here any more - the escort KEEPS its Follow package through
    ; stand-down, so there is nothing to strip and nothing to resolve.
    Int i = 0
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor c = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If c && !c.IsDead()
            c.SheatheWeapon()
            ; Only the GENERAL gives up his march package. Stripping the escort's
            ; Follow here is what stranded them: it left the two Legates with no
            ; package of their own at the exact moment Cassius set off walking.
            If i == 0 && followPkg
                ActorUtil.RemovePackageOverride(c, followPkg)
            EndIf
        EndIf
        i += 1
    EndWhile
    ApplyFinalAuditCourtPackage()
EndFunction

Event OnFinalAuditArrived(String eventName, String strArg, Float numArg, Form sender)
    {The detail has closed on the player. strArg = the assessed demand.
     Weapons come out (the standoff posture - unaggressive, but armed) and
     the General OPENS the conversation: DirectNarration forces an immediate
     LLM response, where RegisterEvent only files context and leaves him
     standing there until spoken to.}
    Actor player = Game.GetPlayer()
    Actor cassius = SeverActionsNativeExt2.Venture_Audit_Collector(0)
    Int i = 0
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor c = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If c && !c.IsDead()
            c.DrawWeapon()
        EndIf
        i += 1
    EndWhile
    If !cassius || cassius.IsDead()
        Return
    EndIf
    ; Tell the player WHO this is before the General opens his mouth.
    ; DirectNarration forces an LLM response, and that round trip is seconds
    ; long - so this notification used to land AFTER it, leaving the player
    ; staring at an armed stranger with no idea why he had stopped them. The
    ; drawn weapons above and this line are the two instant cues; his actual
    ; words follow when the model returns.
    Debug.Notification("The Imperial Final Audit has found you")
    SkyrimNetApi.DirectNarration(         "General Cassius Vero of the Imperial Treasury steps into " + player.GetDisplayName() + "'s path and stops them, his two Legates fanning out at his shoulders with weapons drawn and spells banked. He has tracked them down deliberately. He states the Treasury's business without preamble: the Empire has assessed " + strArg + " septims in back-taxes against " + player.GetDisplayName() + "'s enterprises - untaxed coin the ledgers never saw - and he has come to collect the full sum here and now. He is courteous, unhurried, and absolutely certain, and he does not intend to ask twice.",         cassius, player)
EndEvent

; =============================================================================
; HELPER FUNCTIONS
; =============================================================================

Function PlayGiveAnimation(Actor akActor)
    if akActor && UseGiveAnimation && IdleGive
        akActor.PlayIdle(IdleGive)
        Utility.Wait(AnimDelay)
    endif
EndFunction

Function PlayTakeAnimation(Actor akActor)
    if akActor && UseTakeAnimation && IdleTake
        akActor.PlayIdle(IdleTake)
        Utility.Wait(AnimDelay)
    endif
EndFunction

Function PlayThreatenAnimation(Actor akActor)
    if akActor && UseThreatenAnimation && IdleThreaten
        akActor.PlayIdle(IdleThreaten)
        Utility.Wait(AnimDelay)
    endif
EndFunction

Function PlayGoldSound(Actor akActor)
    if akActor && UseGoldSound && GoldSound
        GoldSound.Play(akActor)
    endif
EndFunction

; =============================================================================
; HELPER: _LogToLedger — Ledger expansion Phase 2 (gold-flow ingest)
; =============================================================================
; Invoked from each currency action's success path. Only logs when the
; player is one of the two parties — NPC↔NPC transactions are atmospheric
; and don't belong in the player's ledger. Direction follows the player's
; gold flow (True = gold flowed away from player). Native_Ledger_RecordEvent
; itself drops empty source / non-positive amount, so the inner guards
; there protect against malformed calls.

Function _LogToLedger(Actor akSender, Actor akReceiver, Int aiAmount, String asSource, String asReason = "")
    If aiAmount <= 0 || !akSender || !akReceiver
        Return
    EndIf
    Actor player = Game.GetPlayer()
    If akSender == player
        SeverActionsNativeExt.Native_Ledger_RecordEvent(aiAmount, True,  asSource, akReceiver, "", asReason, 0)
    ElseIf akReceiver == player
        SeverActionsNativeExt.Native_Ledger_RecordEvent(aiAmount, False, asSource, akSender,   "", asReason, 0)
    EndIf
EndFunction

Int Function TransferGold(Actor akFrom, Actor akTo, Int aiAmount, Bool abAllowConjure = False)
    if !akFrom || !akTo || aiAmount <= 0 || !Gold001
        return 0
    endif
    if akFrom.IsDead() || akTo.IsDead()
        return 0
    endif

    Int available = akFrom.GetItemCount(Gold001)
    Int moved = aiAmount
    
    if abAllowConjure && AllowConjuredGold
        akTo.AddItem(Gold001, moved, False)
        PlayGoldSound(akTo)
        return moved
    endif
    
    if moved > available
        moved = available
    endif
    if moved <= 0
        return 0
    endif

    akFrom.RemoveItem(Gold001, moved, False, akTo)
    PlayGoldSound(akTo)
    return moved
EndFunction

; =============================================================================
; ACTION: GiveGold - NPC voluntarily gives gold to another actor
; Use for: gifts, tips, charity, rewards, generosity
; =============================================================================

Bool Function GiveGold_IsEligible(Actor akGiver, Actor akRecipient, Int aiAmount)
    if !akGiver || !akRecipient || aiAmount <= 0 || !Gold001
        return False
    endif
    if akGiver == akRecipient
        return False
    endif
    if akGiver.IsDead() || akRecipient.IsDead()
        return False
    endif
    
    if AllowConjuredGold
        return True
    endif
    
    return (akGiver.GetItemCount(Gold001) >= aiAmount)
EndFunction

Function GiveGold_Execute(Actor akGiver, Actor akRecipient, Int aiAmount)
    if !akGiver || !akRecipient || !Gold001
        return
    endif
    
    Debug.Trace("[SeverActions_Currency] GiveGold: " + akGiver.GetDisplayName() + " giving " + aiAmount + " gold to " + akRecipient.GetDisplayName())
    
    PlayGiveAnimation(akGiver)
    Int moved = TransferGold(akGiver, akRecipient, aiAmount, True)
    
    if moved > 0
        SkyrimNetApi.RegisterEvent("gold_given", akGiver.GetDisplayName() + " gave " + moved + " gold to " + akRecipient.GetDisplayName(), akGiver, akRecipient)
        _LogToLedger(akGiver, akRecipient, moved, "give_gold")
        ; Auto-reduce debt if giver owes recipient
        SeverActions_Debt debtScript = SeverActions_Debt.GetInstance()
        if debtScript
            debtScript.ReduceDebtByPayment(akRecipient, akGiver, moved)
        endif
    else
        SkyrimNetApi.RegisterEvent("gold_failed", akGiver.GetDisplayName() + " has no gold to give", akGiver, akRecipient)
    endif
EndFunction

; =============================================================================
; ACTION: RepayDebt - the DEBTOR pays back what they owe (debtor-initiated)
; The direction-symmetric partner of CollectPayment (creditor-initiated).
; Added from the LLM text audit (sec.7-19): a debtor saying "here's what I
; owe you" had no action whose description matched - GiveGold says "nothing
; expected in return" and CollectPayment is for the party who is OWED. The
; machinery already existed (GiveGold auto-reduces via ReduceDebtByPayment);
; this is the semantically-correct front door. Amount is CLAMPED to the sum
; actually owed so a hallucinated figure can never overpay the books;
; 0/omitted means "pay everything owed".
; =============================================================================

Function RepayDebt_Execute(Actor akDebtor, Actor akCreditor, Int aiAmount)
    if !akDebtor || !akCreditor || !Gold001
        return
    endif
    if akDebtor == akCreditor
        return
    endif

    Int owed = SeverActionsNativeExt.Native_Debt_SumOwed(akCreditor, akDebtor)
    if owed <= 0
        SkyrimNetApi.RegisterEvent("repay_debt_failed", akDebtor.GetDisplayName() + " owes " + akCreditor.GetDisplayName() + " nothing", akDebtor, akCreditor)
        return
    endif

    ; 0/negative = pay it all; clamp so the payment never exceeds the debt.
    if aiAmount <= 0 || aiAmount > owed
        aiAmount = owed
    endif

    Debug.Trace("[SeverActions_Currency] RepayDebt: " + akDebtor.GetDisplayName() + " paying " + aiAmount + " of " + owed + " gold owed to " + akCreditor.GetDisplayName())

    PlayGiveAnimation(akDebtor)
    ; Same conjure policy as GiveGold - the global toggle governs whether an
    ; NPC debtor short on carried coin can still pay.
    Int moved = TransferGold(akDebtor, akCreditor, aiAmount, True)

    if moved > 0
        SkyrimNetApi.RegisterEvent("debt_repaid", akDebtor.GetDisplayName() + " paid " + moved + " gold toward their debt to " + akCreditor.GetDisplayName(), akDebtor, akCreditor)
        _LogToLedger(akDebtor, akCreditor, moved, "repay_debt")
        SeverActions_Debt debtScript = SeverActions_Debt.GetInstance()
        if debtScript
            debtScript.ReduceDebtByPayment(akCreditor, akDebtor, moved)
        endif
    else
        SkyrimNetApi.RegisterEvent("repay_debt_failed", akDebtor.GetDisplayName() + " has no gold to pay with", akDebtor, akCreditor)
    endif
EndFunction

; =============================================================================
; ACTION: CollectPayment - NPC receives gold owed to them
; Use for: receiving payment after sales, services, trades, settling debts
; The PAYER (target) gives gold to the COLLECTOR (actor)
; If payer is the player, shows a confirmation popup
; =============================================================================

Bool Function CollectPayment_IsEligible(Actor akCollector, Actor akPayer, Int aiAmount)
    if !akCollector || !akPayer || aiAmount <= 0 || !Gold001
        return False
    endif
    if akCollector == akPayer
        return False
    endif
    if akCollector.IsDead() || akPayer.IsDead()
        return False
    endif
    
    ; Payer needs to have gold
    return (akPayer.GetItemCount(Gold001) > 0)
EndFunction

Function CollectPayment_Execute(Actor akCollector, Actor akPayer, Int aiAmount)
    if !akCollector || !akPayer || !Gold001
        return
    endif

    ; FINAL AUDIT REDIRECT. The LLM reaches for CollectPayment when a tax
    ; collector takes tax money, and it is not wrong to: it is an Economy
    ; action named exactly what is happening. Fighting that with prompt text
    ; loses, so the action is wired to the assessment instead (user call,
    ; 2026-08-11 - "can we just make it so CollectPayment also works").
    ;
    ; It routes to CollectAuthorizedTaxes rather than paying aiAmount, because
    ; the assessed sum is NOT the LLM's to choose - it is 40% of the purse,
    ; fixed when the case opened, and the whole point is that it is not
    ; negotiable. Letting a hallucinated figure through here would be a
    ; back door around the one rule the encounter has.
    if SeverActionsNativeExt2.Venture_Audit_IsCollector(akCollector) && \
       SeverActionsNativeExt2.Venture_Audit_State() == "demanding" && \
       akPayer == Game.GetPlayer()
        Debug.Trace("[SeverActions_Currency] CollectPayment on a Final Audit collector -> routing to the assessment (LLM asked for " + aiAmount + ")")
        CollectAuthorizedTaxes(akCollector)
        return
    endif

    ; Lazy ModEvent registration. Maintenance() only fires from OnInit on
    ; fresh install — players updating from a save that predates the
    ; CollectPaymentChoice handler would otherwise never bind it, and the
    ; bridge's ModEvent would fall on the floor (silent "Pay" click).
    ; RegisterForModEvent is deduped by SKSE so calling on every dispatch
    ; is cheap; the registration then persists across save/load.
    RegisterForModEvent("SeverActions_CollectPaymentChoice", "OnCollectPaymentChoice")

    Debug.Trace("[SeverActions_Currency] CollectPayment: " + akCollector.GetDisplayName() + " collecting " + aiAmount + " gold from " + akPayer.GetDisplayName())
    
    ; If payer is the player, prefer the non-pausing PrismaUI overlay
    ; over SkyMessage. The bridge posts the choice back via
    ; SeverActions_CollectPaymentChoice (handled by OnCollectPaymentChoice
    ; below). When PrismaUI isn't available OR another prompt is in flight,
    ; fall through to the legacy SkyMessage modal so the action still works
    ; out-of-the-box for users without PrismaUI installed.
    Actor player = Game.GetPlayer()
    if akPayer == player
        String collectorName = akCollector.GetDisplayName()

        if SeverActionsNative.PrismaUI_IsPaymentPromptAvailable() && \
           !SeverActionsNative.PrismaUI_IsPaymentPromptOpen()
            if SeverActionsNative.PrismaUI_OpenPaymentPrompt(akCollector, aiAmount, collectorName, 20000)
                ; Choice arrives asynchronously via OnCollectPaymentChoice.
                return
            endif
        endif

        ; Legacy / fallback path — modal SkyMessage. Same three-option UX.
        _CollectPaymentPlayerModal(akCollector, aiAmount, collectorName)
        return
    endif

    ; Non-player payer - proceed as normal
    PlayTakeAnimation(akCollector)
    Int moved = TransferGold(akPayer, akCollector, aiAmount, False)

    if moved > 0
        if moved < aiAmount
            SkyrimNetApi.RegisterEvent("payment_collected", akCollector.GetDisplayName() + " collected " + moved + " gold from " + akPayer.GetDisplayName() + " (partial payment)", akCollector, akPayer)
        else
            SkyrimNetApi.RegisterEvent("payment_collected", akCollector.GetDisplayName() + " collected " + moved + " gold from " + akPayer.GetDisplayName(), akCollector, akPayer)
        endif
        _LogToLedger(akPayer, akCollector, moved, "collect_payment")
        ; Auto-reduce debt if payer owes collector
        SeverActions_Debt debtScript = SeverActions_Debt.GetInstance()
        if debtScript
            debtScript.ReduceDebtByPayment(akCollector, akPayer, moved)
        endif
    else
        SkyrimNetApi.RegisterEvent("payment_failed", akPayer.GetDisplayName() + " has no gold to pay", akCollector, akPayer)
    endif
EndFunction

; =============================================================================
; CollectPayment — choice dispatch
; -----------------------------------------------------------------------------
; Shared by both prompt paths (PrismaUI overlay → OnCollectPaymentChoice;
; legacy modal → _CollectPaymentPlayerModal) so the transaction/narration/
; ledger/debt logic lives in exactly one place. The choice strings match
; the JS payload from PromptPanel ("accept" / "deny" / "denySilent").
; =============================================================================

Function _ApplyCollectPaymentChoice(Actor akCollector, Actor akPayer, Int aiAmount, String asChoice, String asCollectorName)
    if asChoice == "accept"
        PlayTakeAnimation(akCollector)
        Int moved = TransferGold(akPayer, akCollector, aiAmount, False)

        if moved > 0
            if moved < aiAmount
                SkyrimNetApi.RegisterEvent("payment_collected", asCollectorName + " collected " + moved + " gold from " + akPayer.GetDisplayName() + " (partial payment)", akCollector, akPayer)
            else
                SkyrimNetApi.RegisterEvent("payment_collected", asCollectorName + " collected " + moved + " gold from " + akPayer.GetDisplayName(), akCollector, akPayer)
            endif
            _LogToLedger(akPayer, akCollector, moved, "collect_payment")
            SeverActions_Debt debtScript = SeverActions_Debt.GetInstance()
            if debtScript
                debtScript.ReduceDebtByPayment(akCollector, akPayer, moved)
            endif
        else
            SkyrimNetApi.RegisterEvent("payment_failed", akPayer.GetDisplayName() + " has no gold to pay", akCollector, akPayer)
        endif

    elseif asChoice == "deny"
        ; Player refuses — narrate so NPC reacts.
        SkyrimNetApi.DirectNarration(akPayer.GetDisplayName() + " refused to pay " + asCollectorName, akCollector)

    elseif asChoice == "denySilent"
        ; Silent decline — no event, no narration. Matches legacy "No (Silent)".
        Debug.Trace("[SeverActions_Currency] CollectPayment: Player silently declined payment to " + asCollectorName)

    else
        Debug.Trace("[SeverActions_Currency] CollectPayment: unknown choice '" + asChoice + "'")
    endif
EndFunction

; Legacy modal path — used when PrismaUI is unavailable or another prompt
; is already open. Preserves the exact original UX so users without
; PrismaUI installed (or anyone hitting the fallback for any reason) see
; the same three-option SkyMessage they always did.
Function _CollectPaymentPlayerModal(Actor akCollector, Int aiAmount, String asCollectorName)
    String promptText = asCollectorName + " is requesting " + aiAmount + " gold. Pay them?"
    String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")

    String choice = "denySilent"
    if result == "Yes"
        choice = "accept"
    elseif result == "No"
        choice = "deny"
    endif

    _ApplyCollectPaymentChoice(akCollector, Game.GetPlayer(), aiAmount, choice, asCollectorName)
EndFunction

; ModEvent handler — fired by PrismaUICollectPaymentBridge when the player
; clicks a button or the auto-accept timer expires. strArg carries the
; choice ("accept" / "deny" / "denySilent"); numArg carries the original
; amount (round-tripped from the bridge so we don't depend on cached
; script state); sender is the collector actor.
Event OnCollectPaymentChoice(String asEventName, String asChoice, Float afAmount, Form akSender)
    Actor akCollector = akSender as Actor
    if !akCollector
        Debug.Trace("[SeverActions_Currency] OnCollectPaymentChoice: sender is not an Actor - ignoring")
        return
    endif

    Int aiAmount = afAmount as Int
    if aiAmount <= 0
        Debug.Trace("[SeverActions_Currency] OnCollectPaymentChoice: invalid amount " + afAmount + " - ignoring")
        return
    endif

    _ApplyCollectPaymentChoice(akCollector, Game.GetPlayer(), aiAmount, asChoice, akCollector.GetDisplayName())
EndEvent

; =============================================================================
; ACTION: ExtortGold - NPC forcibly takes gold through intimidation/threats
; Use for: robbery, mugging, demanding tribute, protection money, coercion
; =============================================================================

Bool Function ExtortGold_IsEligible(Actor akExtorter, Actor akVictim, Int aiAmount)
    if !akExtorter || !akVictim || aiAmount <= 0 || !Gold001
        return False
    endif
    if akExtorter == akVictim
        return False
    endif
    if akExtorter.IsDead() || akVictim.IsDead()
        return False
    endif
    
    ; Victim needs to have gold to extort
    return (akVictim.GetItemCount(Gold001) > 0)
EndFunction

Function ExtortGold_Execute(Actor akExtorter, Actor akVictim, Int aiAmount)
    if !akExtorter || !akVictim || !Gold001
        return
    endif
    
    Debug.Trace("[SeverActions_Currency] ExtortGold: " + akExtorter.GetDisplayName() + " extorting " + aiAmount + " gold from " + akVictim.GetDisplayName())
    
    ; Threaten first, then take
    PlayThreatenAnimation(akExtorter)
    PlayTakeAnimation(akExtorter)
    Int moved = TransferGold(akVictim, akExtorter, aiAmount, False)
    
    if moved > 0
        if moved < aiAmount
            SkyrimNetApi.RegisterEvent("gold_extorted", akExtorter.GetDisplayName() + " extorted " + moved + " gold from " + akVictim.GetDisplayName() + " (all they had)", akExtorter, akVictim)
        else
            SkyrimNetApi.RegisterEvent("gold_extorted", akExtorter.GetDisplayName() + " extorted " + moved + " gold from " + akVictim.GetDisplayName(), akExtorter, akVictim)
        endif
        _LogToLedger(akVictim, akExtorter, moved, "extort_gold")
    else
        SkyrimNetApi.RegisterEvent("extortion_failed", akVictim.GetDisplayName() + " has no gold to take", akExtorter, akVictim)
    endif
EndFunction

; =============================================================================
; ACTIONS: BuyItem / SellItem - atomic item-for-gold transactions
;
; Patches the UX gap where the LLM would fire GiveGold but then need a second
; prompt to fire GiveItem (or vice versa), leaving the player with the gold
; gone but no goods (or the reverse). BuyItem / SellItem package both halves
; into a single action call.
;
; BuyItem  — the SPEAKER is the buyer (pays gold, receives item).
; SellItem — the SPEAKER is the seller (gives item, receives gold).
;
; Both delegate to the same internal _DoItemTransaction so the actual logic
; lives in one place. Deliberately does NOT call SeverActions_Debt — a
; purchase is not the same as settling an outstanding tab, even if one
; happens to exist between these two actors. Use CollectPayment / GiveGold
; explicitly when you want to interact with the debt ledger.
; =============================================================================

SeverActions_Loot Function _GetLootScript()
    Return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Loot
EndFunction

Bool Function BuyItem_IsEligible(Actor akBuyer, Actor akSeller, String asItemName, Int aiQuantity, Int aiTotalGold)
    Return _Transaction_IsEligible(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Function BuyItem_Execute(Actor akBuyer, Actor akSeller, String asItemName, Int aiQuantity, Int aiTotalGold)
    _BeginItemTransaction(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Bool Function SellItem_IsEligible(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    Return _Transaction_IsEligible(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

Function SellItem_Execute(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    _BeginItemTransaction(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
EndFunction

; =============================================================================
; Trade confirmation (dev141) - when the PLAYER is a party to a BuyItem/
; SellItem, a non-pausing PrismaUI popup shows exactly what changes hands
; (item, count, gold) with Accept / Refuse / Refuse silently - the same UX
; as CollectPayment/Arrest. Auto-timeout REFUSES (never move the player's
; gold or goods without a click). NPC-to-NPC trades commit directly.
; One pending trade at a time - matches the bridge's one-in-flight rule.
; =============================================================================

Actor PendingTradeSeller
Actor PendingTradeBuyer
String PendingTradeItem
Int PendingTradeQty
Int PendingTradeGold

Function _BeginItemTransaction(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    ; Same-actor guard (public issue #16): the LLM sometimes fills both
    ; parties with the speaker ("Balgruuf buys dragon bones from Balgruuf").
    ; Fail loudly with a correction the model can act on next round instead
    ; of falling into the generic invalid-parameters event downstream.
    If akSeller && akBuyer && akSeller == akBuyer
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akBuyer.GetDisplayName() + " cannot trade with themselves - the buyer and the seller must be two different people (was the other party meant to be the player?)", \
            akSeller, akBuyer)
        Return
    EndIf

    Actor player = Game.GetPlayer()
    If akSeller != player && akBuyer != player
        ; NPC-to-NPC - nothing of the player's moves; commit directly.
        _DoItemTransaction(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
        Return
    EndIf

    ; Lazy ModEvent registration - same rationale as CollectPayment's.
    RegisterForModEvent("SeverActions_TradeChoice", "OnTradeChoice")

    PendingTradeSeller = akSeller
    PendingTradeBuyer = akBuyer
    PendingTradeItem = asItemName
    PendingTradeQty = aiQuantity
    PendingTradeGold = aiTotalGold

    Bool playerBuys = (akBuyer == player)
    Actor counterparty = akSeller
    If !playerBuys
        counterparty = akBuyer
    EndIf
    String counterpartyName = counterparty.GetDisplayName()

    If SeverActionsNativeExt.PrismaUI_IsTradePromptAvailable() && \
       !SeverActionsNativeExt.PrismaUI_IsTradePromptOpen()
        If SeverActionsNativeExt.PrismaUI_OpenTradePrompt(counterparty, aiTotalGold, counterpartyName, asItemName, aiQuantity, playerBuys, 20000)
            ; Choice arrives asynchronously via OnTradeChoice.
            Return
        EndIf
    EndIf

    ; Legacy / fallback path - modal SkyMessage, same three options.
    String qtyStr = ""
    If aiQuantity > 1
        qtyStr = aiQuantity + "x "
    EndIf
    String promptText
    If playerBuys
        promptText = counterpartyName + " offers " + qtyStr + asItemName + " for " + aiTotalGold + " gold. Buy?"
    Else
        promptText = counterpartyName + " offers " + aiTotalGold + " gold for your " + qtyStr + asItemName + ". Sell?"
    EndIf
    String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")
    String choice = "denySilent"
    If result == "Yes"
        choice = "accept"
    ElseIf result == "No"
        choice = "deny"
    EndIf
    _ApplyTradeChoice(choice)
EndFunction

Event OnTradeChoice(String asEventName, String asChoice, Float afAmount, Form akSender)
    _ApplyTradeChoice(asChoice)
EndEvent

Function _ApplyTradeChoice(String asChoice)
    Actor tSeller = PendingTradeSeller
    Actor tBuyer = PendingTradeBuyer
    String tItem = PendingTradeItem
    Int tQty = PendingTradeQty
    Int tGold = PendingTradeGold
    ; Clear FIRST so a re-entrant prompt can't double-commit the same trade.
    PendingTradeSeller = None
    PendingTradeBuyer = None
    PendingTradeItem = ""
    PendingTradeQty = 0
    PendingTradeGold = 0

    If !tSeller || !tBuyer
        Return
    EndIf

    If asChoice == "accept"
        _DoItemTransaction(tSeller, tBuyer, tItem, tQty, tGold)
    ElseIf asChoice == "deny"
        ; Player refuses out loud - narrate so the NPC reacts.
        Actor player = Game.GetPlayer()
        Actor counterparty = tSeller
        If tSeller == player
            counterparty = tBuyer
        EndIf
        SkyrimNetApi.DirectNarration(player.GetDisplayName() + " declined the trade of " + tItem + " with " + counterparty.GetDisplayName(), counterparty)
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            player.GetDisplayName() + " declined to trade " + tItem + " with " + counterparty.GetDisplayName(), \
            tSeller, tBuyer)
    EndIf
    ; denySilent / dismiss - nothing happens, nothing is said.
EndFunction

Bool Function _Transaction_IsEligible(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    {Shared eligibility — same checks regardless of which side is the speaker.}
    If !akSeller || !akBuyer || asItemName == "" || aiQuantity < 1 || aiTotalGold < 0
        Return False
    EndIf
    If akSeller == akBuyer
        Return False
    EndIf
    If akSeller.IsDead() || akBuyer.IsDead()
        Return False
    EndIf
    If !Gold001
        Return False
    EndIf
    ; PR #103 review fix, refined dev141: the PLAYER-buyer ALWAYS pays from
    ; real coin — a player-buyer with 0 gold could otherwise BuyItem for free
    ; (the conjure path in TransferGold just AddItems to the seller without
    ; debiting the buyer). An NPC buyer, though, may come up short when
    ; buying FROM the player: with AllowConjuredGold on, the shortfall is
    ; minted so the sale still goes through — the trade popup showed the
    ; player the real amount, and refusing an NPC's coin because their
    ; pockets are light is exactly what conjured gold exists to smooth over.
    If akBuyer == Game.GetPlayer() || !AllowConjuredGold
        If akBuyer.GetItemCount(Gold001) < aiTotalGold
            Return False
        EndIf
    EndIf
    Return True
EndFunction

Function _DoItemTransaction(Actor akSeller, Actor akBuyer, String asItemName, Int aiQuantity, Int aiTotalGold)
    {Atomic item-for-gold transaction. Resolves the item, pre-checks stock + gold,
     walks the seller to the buyer, swaps the items + the gold, then fires a
     single item_purchased event. On any failure path, fires item_purchase_failed
     with a reason string and returns without mutating either inventory.}

    If !_Transaction_IsEligible(akSeller, akBuyer, asItemName, aiQuantity, aiTotalGold)
        ; Null-guard: when eligibility fails because an actor is None, don't
        ; build a malformed " could not buy X from " event — just log.
        If !akSeller || !akBuyer
            Debug.Trace("[SeverActions_Currency] _DoItemTransaction: missing actor - skipping")
            Return
        EndIf
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akBuyer.GetDisplayName() + " could not complete the purchase of " + asItemName + " from " + akSeller.GetDisplayName() + " (invalid parameters or insufficient gold)", \
            akSeller, akBuyer)
        Return
    EndIf

    SeverActions_Loot lootSys = _GetLootScript()
    If !lootSys
        Debug.Trace("[SeverActions_Currency] BuyItem/SellItem: SeverActions_Loot quest unavailable")
        Return
    EndIf

    ; Resolve the item (personal inventory or merchant chest).
    Form itemForm = SeverActions_Loot.ResolveItemForTransaction(akSeller, asItemName)
    If !itemForm
        ; Self-correction hint (public issue #16): on localized games the LLM
        ; often passes the English canonical name while the inventory holds
        ; the localized one - echo the seller's closest-matching item names so
        ; the model can retry with a name that actually resolves. Only fuzzy
        ; MATCHES are listed; a total miss keeps the guidance textual.
        String closeNames = SeverActionsNativeExt2.Native_ClosestInventoryNames(akSeller, asItemName, 5)
        String failText = akSeller.GetDisplayName() + " doesn't have any '" + asItemName + "' to sell to " + akBuyer.GetDisplayName()
        If closeNames != ""
            failText += " - they do carry: " + closeNames + ". Retry with the item's exact in-game name."
        Else
            failText += " - no similar item in their inventory. Use the item's exact in-game (localized) name as it appears in the inventory."
        EndIf
        SkyrimNetApi.RegisterEvent("item_purchase_failed", failText, akSeller, akBuyer)
        Return
    EndIf

    ; Pre-check stock so we don't walk the seller and play the give animation
    ; just to discover they only had 1 of the 5 requested.
    Int available = SeverActions_Loot.GetTransactionAvailableQty(akSeller, itemForm)
    If available < aiQuantity
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akSeller.GetDisplayName() + " only has " + available + " " + itemForm.GetName() + " - not enough for " + akBuyer.GetDisplayName() + "'s " + aiQuantity, \
            akSeller, akBuyer)
        Return
    EndIf

    ; PR #103 review fix: gold-first ordering. The item transfer involves a
    ; walk + animation (up to ~15s) where a save/load/crash/cell-unload could
    ; orphan the gold half if we did it last. Move the gold first (instant);
    ; if the subsequent item transfer fails, refund the gold. Worst case is
    ; one fallible step (refund) instead of two with no rollback.
    ; dev141: an NPC buyer pays every REAL coin they have first, and only
    ; the shortfall is minted (TransferGold's own conjure path mints the
    ; whole sum without debiting the payer - right for gifts, wrong for a
    ; trade). The player-buyer always pays real coin in full (PR #103).
    Bool conjureOK = (akBuyer != Game.GetPlayer()) && AllowConjuredGold
    Int paid = TransferGold(akBuyer, akSeller, aiTotalGold, False)
    If paid < aiTotalGold && conjureOK
        akSeller.AddItem(Gold001, aiTotalGold - paid, False)
        Debug.Trace("[SeverActions_Currency] Trade: conjured " + (aiTotalGold - paid) + "g shortfall for " + akBuyer.GetDisplayName())
        paid = aiTotalGold
    EndIf
    If paid != aiTotalGold
        ; Eligibility already verified the buyer has the gold, so a partial
        ; transfer here means something raced us between the check and the
        ; move. Bail without firing the item half.
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akBuyer.GetDisplayName() + " could not finish paying " + akSeller.GetDisplayName() + " for " + asItemName + " (only " + paid + " of " + aiTotalGold + " gold moved)", \
            akSeller, akBuyer)
        Return
    EndIf

    ; Item half. TransferItemForTransaction handles the walk + animation + the
    ; personal-vs-merchant-chest source selection.
    Int transferred = lootSys.TransferItemForTransaction(akSeller, akBuyer, itemForm, aiQuantity)
    If transferred <= 0
        ; Refund the gold the buyer just paid. Seller has at least aiTotalGold
        ; right now (we just gave it to them), so this transfer is safe.
        TransferGold(akSeller, akBuyer, aiTotalGold, False)
        SkyrimNetApi.RegisterEvent("item_purchase_failed", \
            akSeller.GetDisplayName() + " could not hand over " + asItemName + " to " + akBuyer.GetDisplayName() + " - " + aiTotalGold + " gold refunded", \
            akSeller, akBuyer)
        Return
    EndIf

    ; PR #175 review fix (M3): a race between the stock pre-check and the
    ; transfer can leave `transferred` short of aiQuantity (the items already
    ; moved to the buyer, so we don't claw them back). Refund the unfilled
    ; remainder pro-rata so the buyer is charged only for what they received,
    ; never the full price for partial goods. Full transfers keep the exact
    ; agreed total (no rounding drift from the per-unit split).
    Int chargedGold = aiTotalGold
    If transferred < aiQuantity
        Int pricePerUnit = aiTotalGold / aiQuantity
        Int refund = aiTotalGold - (pricePerUnit * transferred)
        If refund > 0
            TransferGold(akSeller, akBuyer, refund, False)
            chargedGold = aiTotalGold - refund
        EndIf
    EndIf

    ; Build the unified transaction event.
    String itemLabel = itemForm.GetName()
    If transferred > 1
        itemLabel = transferred + " " + itemLabel
    EndIf
    String eventMsg = akBuyer.GetDisplayName() + " bought " + itemLabel + " from " + akSeller.GetDisplayName() + " for " + chargedGold + " gold"
    SkyrimNetApi.RegisterEvent("item_purchased", eventMsg, akSeller, akBuyer)

    ; Ledger: source key depends on which side the player is on. _LogToLedger
    ; only fires when the player is involved; for NPC↔NPC item swaps it
    ; silently no-ops. The item label rides along as the row's `reason`
    ; so the recent-transactions view can show "bought 3 Iron Ingot".
    Actor player = Game.GetPlayer()
    String src = "buy_item"   ; default when neither side is player (no-op anyway)
    If akSeller == player
        src = "sell_item"
    EndIf
    _LogToLedger(akBuyer, akSeller, chargedGold, src, itemLabel)
EndFunction

; =============================================================================
; ENTERPRISES — SkyrimNet dialogue actions (Phase 4)
; The retainer economy lives natively (VentureMonitor / VentureStore); these
; thin member functions are the LLM-callable entry points. Hosted here (the
; economy script) rather than a dedicated quest-attached script to avoid a
; Mutagen re-serialize of the 27-script SeverActions quest.
; =============================================================================

Bool Function HireRetainer(Actor akActor, String job, String arrangement)
    {The speaker agrees to work for the player as a retainer. Opens the assign-
     retainer popup (prefilled with the agreed job/arrangement + the workplace
     autocomplete) so the player finalizes where they work and the terms, then
     the popup commits the hire. Falls back to a direct hire (job + arrangement
     as agreed) if PrismaUI is unavailable. Returns false if already a retainer.}
    If !akActor
        Return false
    EndIf
    If SeverActionsNativeExt2.Venture_IsRetainer(akActor)
        Return false
    EndIf
    ; Preferred: open the popup, prefilled from the agreed terms. HireRetainer is
    ; LLM-driven in conversation (no menu open), so the non-pausing popup shows.
    If SeverActionsNativeExt.PrismaUI_IsRetainerAssignPromptAvailable() \
        && SeverActionsNativeExt.PrismaUI_OpenRetainerAssignPrompt(akActor, "", job, arrangement, 90000)
        Return true
    EndIf
    ; Fallback (PrismaUI absent / suppressed): hire directly with the agreed terms.
    Return SeverActionsNativeExt2.Venture_Hire(akActor, job, arrangement)
EndFunction

; ─── Camp takeover (Phase 4) ────────────────────────────────────────────────
; Two ways an outlaw camp ends up working for the player, and one way to let it
; go. The natives own every guard - Camp_Swear refuses a non-leader on the
; agree route and refuses a camp whose chief is still breathing on the recruit
; route - so these stay thin. The YAML eligibility gates mirror the same rules
; so the action never surfaces when it would only be refused.

Bool Function SwearCampToPlayer(Actor akActor)
    {Route B: the camp's LEADER agrees to serve the player, and their word binds
     the whole camp. Enrolls every member on the Enterprises board as one
     holding under Partnership terms. Refused by the native if the speaker does
     not actually lead the camp.}
    If !akActor
        Return false
    EndIf
    Bool ok = SeverActionsNativeExt2.Camp_Swear(akActor, true)
    If ok
        Debug.Notification("The camp has sworn to you.")
    EndIf
    Return ok
EndFunction

Bool Function RecruitLeaderlessCamp(Actor akActor)
    {Route A: nobody is in charge - the chief was killed, or the location never
     designated one - and the members throw in one at a time. Same end state as
     SwearCampToPlayer, harsher terms (Vassalage).

     THREE OUTCOMES, and false is the ordinary one:
       true             - the vote carried and the camp is sworn.
       false + a tally  - this member's agreement was recorded; more needed.
       false + no tally - refused (chief alive, already sworn, takeover off).}
    If !akActor
        Return false
    EndIf
    Bool ok = SeverActionsNativeExt2.Camp_Swear(akActor, false)
    If ok
        ; The vote carried. This event replaces the action's old eventString,
        ; which fired on EVERY call and announced the takeover on votes that
        ; had not settled anything.
        SkyrimNetApi.RegisterEvent("camp_sworn_by_consensus",         akActor.GetDisplayName() + " gives the last word needed - with nobody in charge to speak for them, enough of the camp has now agreed that it is settled. They answer to " + Game.GetPlayer().GetDisplayName() + " from here.",         akActor, Game.GetPlayer())
        Debug.Notification("What is left of the camp answers to you.")
        Return true
    EndIf

    ; NOT a failure - a leaderless camp is won a person at a time, and this was
    ; one voice of several. Nobody without a chief can hand over a camp they do
    ; not command, so the native records the agreement and only swears the camp
    ; when enough of them have said yes. Narrate the vote so the player can see
    ; it moving, and so the REST of the crew hears who just broke ranks - that
    ; is the whole point of deciding it together.
    String tally = SeverActionsNativeExt2.Camp_ConsentTally(akActor)
    If tally != ""
        SkyrimNetApi.RegisterEvent("camp_consent_given",             akActor.GetDisplayName() + " gives their word to " + Game.GetPlayer().GetDisplayName() +             " - but with nobody in charge here, one voice does not settle it. That is " + tally +             " of the camp agreed. The others heard exactly who said yes, and what they think of " +             akActor.GetDisplayName() + " colours what they do next.", akActor, Game.GetPlayer())
        Debug.Notification("They agree - " + tally + " of the camp.")
    EndIf
    Return false
EndFunction

Bool Function ReleaseCampFromService(Actor akActor)
    {Let a sworn camp go: drops every venture belonging to it and thaws the
     respawn freeze, so the location behaves like an ordinary camp again.}
    If !akActor
        Return false
    EndIf
    Bool ok = SeverActionsNativeExt2.Camp_Release(akActor)
    If ok
        Debug.Notification("You release the camp from your service.")
    EndIf
    Return ok
EndFunction

Bool Function RenounceCampOath(Actor akActor)
    {The CHIEF breaks the camp's oath to the player: every venture closes,
     the camp reverts to an ordinary outlaw camp, and the whole crew turns
     hostile together (the truce layer's group break). The native refuses
     anyone who is not the camp's leader, so a mistaken LLM call from a
     lackey does nothing.}
    If !akActor
        Return false
    EndIf
    Bool ok = SeverActionsNativeExt2.Camp_Renounce(akActor)
    If ok
        Debug.Notification(akActor.GetDisplayName() + "'s camp has turned on you!")
    EndIf
    Return ok
EndFunction

Bool Function MusterCamp(Actor akActor)
    {The CHIEF rallies their sworn camp to the player's side as a war band -
     every living member seats in the follow pool, turns teammate, and comes
     to the player at once. The YAML gates this to the sworn camp's leader;
     the store refuses non-sworn camps as the backstop. The seating itself
     runs in SeverActions_Follow (the pool's owner) via the same path the
     UI button uses.}
    If !akActor
        Return false
    EndIf
    Int campId = SeverActionsNativeExt2.Camp_CampIdOf(akActor)
    If campId == 0
        Return false
    EndIf
    If !SeverActionsNativeExt2.Camp_SetMustered(campId, true)
        Return false
    EndIf
    SeverActions_Follow f = (Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest) as SeverActions_Follow
    If f
        f.MusterCampById(campId)
    EndIf
    Return true
EndFunction

Bool Function SendCampHome(Actor akActor)
    {The CHIEF dismisses the war band - seating clears and everyone returns
     to the camp. Counterpart of MusterCamp, same routing.}
    If !akActor
        Return false
    EndIf
    Int campId = SeverActionsNativeExt2.Camp_CampIdOf(akActor)
    If campId == 0
        Return false
    EndIf
    SeverActionsNativeExt2.Camp_SetMustered(campId, false)
    SeverActions_Follow f = (Game.GetFormFromFile(0x000D62, "SeverActions.esp") as Quest) as SeverActions_Follow
    If f
        f.SendCampHomeById(campId)
    EndIf
    Return true
EndFunction

Bool Function CollectFromRetainer(Actor akActor)
    {Collect the speaker-retainer's pending payout (gold + goods) for the player.
     In-person path: this is spoken face to face, so it also reaches a DEFIANT
     Tribute retainer's withheld coin (the board's Collect button cannot) and
     breaks the standoff - they back down and hand it over. If this retainer is
     also a hold steward, the hold vault they keep hands over in the same
     conversation - no second ask.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_CollectInPerson(akActor)
    If SeverActionsNativeExt2.Steward_HoldNameOf(akActor) != ""
        Int vault = SeverActionsNativeExt2.Steward_Collect(akActor)
        If vault > 0
            Debug.Notification(akActor.GetDisplayName() + " hands over the hold vault: " + vault + " gold.")
        EndIf
    EndIf
    Return true
EndFunction

Bool Function HireSteward(Actor akActor, Int aiWeeklyWage = 100)
    {Appoint the speaker-retainer as steward of their hold. From the next
     settlement on, every retainer in that hold pays their take into the
     steward's vault instead of holding it themselves - one stop to collect a
     whole hold. The steward draws their own weekly wage FROM that vault (an
     empty vault means an unpaid, increasingly bitter steward). One steward
     per hold; fails if the seat is taken or the speaker is not a retainer.}
    If !akActor
        Return false
    EndIf
    If aiWeeklyWage <= 0
        aiWeeklyWage = 100
    EndIf
    String holdName = SeverActionsNativeExt2.Steward_Appoint(akActor, aiWeeklyWage)
    If holdName == ""
        Return false
    EndIf
    Debug.Notification(akActor.GetDisplayName() + " now stewards " + holdName + " (" + aiWeeklyWage + " gold/week).")
    Return true
EndFunction

Bool Function DismissSteward(Actor akActor)
    {Relieve the speaker of their stewardship. Whatever sits in the hold vault
     is handed back to the player on the spot; the hold's retainers go back to
     holding their own takings until a new steward is appointed. They stay a
     retainer - only the stewardship ends.}
    If !akActor
        Return false
    EndIf
    String holdName = SeverActionsNativeExt2.Steward_HoldNameOf(akActor)
    If holdName == ""
        Return false
    EndIf
    Int remainder = SeverActionsNativeExt2.Steward_Dismiss(akActor)
    If remainder > 0
        Debug.Notification(akActor.GetDisplayName() + " steps down as steward of " + holdName + " and hands back " + remainder + " gold.")
    Else
        Debug.Notification(akActor.GetDisplayName() + " steps down as steward of " + holdName + ".")
    EndIf
    Return true
EndFunction

Bool Function CollectFromSteward(Actor akActor)
    {Collect the hold vault from the speaker-steward: every gold piece their
     hold's retainers have paid in since the last collection, in one handover.
     Their own pending retainer payout (if any) is separate - CollectFromRetainer
     covers both at once.}
    If !akActor
        Return false
    EndIf
    String holdName = SeverActionsNativeExt2.Steward_HoldNameOf(akActor)
    If holdName == ""
        Return false
    EndIf
    Int vault = SeverActionsNativeExt2.Steward_Collect(akActor)
    If vault > 0
        Debug.Notification(akActor.GetDisplayName() + " hands over " + holdName + "'s takings: " + vault + " gold.")
    Else
        Debug.Notification(holdName + "'s vault is empty this week.")
    EndIf
    Return true
EndFunction

Bool Function PayArrears(Actor akActor)
    {Pay the back-wages the player owes this retainer, from the player's gold.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_PayArrears(akActor)
    Return true
EndFunction

Bool Function DismissRetainer(Actor akActor)
    {End the speaker-retainer's service amicably.}
    If !akActor
        Return false
    EndIf
    Return SeverActionsNativeExt2.Venture_Dismiss(akActor)
EndFunction

Bool Function GrantLoan(Actor akActor)
    {The player agrees in conversation to lend this retainer the coin they asked
     for. Real money: it leaves the player's purse now, a DebtStore entry backs
     it, and repayment is garnished from the retainer's OWN weekly take - never
     from the player's cut. Silently no-ops if the ask has already been answered
     or the player cannot cover it.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_GrantLoan(akActor)
    Return true
EndFunction

Bool Function RefuseLoan(Actor akActor)
    {The player turns down this retainer's request for a loan. Costs loyalty and
     puts the ask on a cooldown - they will not come back to it for a good while.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_RefuseLoan(akActor)
    Return true
EndFunction

Bool Function ForgiveLoan(Actor akActor)
    {The player writes off what this retainer still owes on a loan. Clears the
     balance and the backing DebtStore entry (so the debt pipeline stops pursuing
     them) and buys real loyalty. Works on a defaulted loan too - that is the
     point of it.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_ForgiveLoan(akActor)
    Return true
EndFunction

Bool Function ReassureRetainer(Actor akActor)
    {Temper hearing SUCCESS - the retainer was genuinely heard out, face to
     face. Consensual terms: real morale lift, withdraws a standing notice.
     Coerced terms: cows them for exactly one settle - fear management, no
     morale repair. Resolves an armed Send-Word meeting; also callable
     organically in conversation (native cooldown stops wage-substitute spam).}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_Reassure(akActor)
    Return true
EndFunction

Bool Function GrantTaxRelief(Actor akActor)
    {Hold taxes (P1): the jarl, persuaded in person, eases their hold's
     enterprise tax by 5 points (accumulated adjust clamped natively).}
    If !akActor
        Return false
    EndIf
    Int newRate = SeverActionsNativeExt2.Venture_AdjustHoldTaxForJarl(akActor, -5)
    If newRate < 0
        Return false
    EndIf
    Debug.Notification(akActor.GetDisplayName() + " eases the hold's enterprise tax (~" + newRate + "%)")
    Return true
EndFunction

Bool Function RaiseHoldTaxes(Actor akActor)
    {Hold taxes (P1): the jarl, angered or unimpressed, raises their hold's
     enterprise tax by 5 points.}
    If !akActor
        Return false
    EndIf
    Int newRate = SeverActionsNativeExt2.Venture_AdjustHoldTaxForJarl(akActor, 5)
    If newRate < 0
        Return false
    EndIf
    Debug.Notification(akActor.GetDisplayName() + " raises the hold's enterprise tax (~" + newRate + "%)")
    Return true
EndFunction

Bool Function CollectAuthorizedTaxes(Actor akActor)
    {Final Audit (P2): the player agreed to pay. The full assessed sum leaves
     their purse, the audit latches PAID (terminal), and the detail's anchor
     returns to Dragonsreach - the formation walks itself home.}
    If !akActor || !SeverActionsNativeExt2.Venture_Audit_IsCollector(akActor)
        Return false
    EndIf
    Int demand = SeverActionsNativeExt2.Venture_Audit_Demand()
    Actor player = Game.GetPlayer()
    If player.GetGoldAmount() < demand
        SkyrimNetApi.RegisterEvent("final_audit_short",             player.GetDisplayName() + " agreed to pay but cannot produce the full " + demand + " septims the Treasury has assessed. " + akActor.GetDisplayName() + " notes the shortfall without surprise - the demand stands, in full, and the detail is not leaving.",             akActor, None)
        Return false
    EndIf
    If !SeverActionsNativeExt2.Venture_Audit_Collect()
        Return false
    EndIf
    If !Gold001
        Debug.Trace("[SeverActions] Final Audit: Gold001 unresolved - payment aborted")
        Return false
    EndIf
    player.RemoveItem(Gold001, demand, false)
    SkyrimNetApi.RegisterEvent("final_audit_paid",         player.GetDisplayName() + " paid the Imperial Treasury " + demand + " septims in back-taxes. " + akActor.GetDisplayName() + " records the sum, thanks them for their compliance, and the Final Audit withdraws toward Dragonsreach - the ledger balanced, the debt closed for good.",         akActor, None)
    Return true
EndFunction

Bool Function PressTheDemand(Actor akActor)
    {Final Audit (P2): refusal. The audit latches REFUSED (terminal) and the
     detail attacks. Papyrus starts the fights so the engine books a normal
     combat - three real actors versus the player, no scripting beyond this.
     The twelve are garrisoned in other holds and take no part.}
    If !akActor || !SeverActionsNativeExt2.Venture_Audit_IsCollector(akActor)
        Return false
    EndIf
    If !SeverActionsNativeExt2.Venture_Audit_Refuse()
        Return false
    EndIf
    Actor player = Game.GetPlayer()
    Int i = 0
    Int detail = FinalAuditEscortSize()
    While i < detail
        Actor collector = SeverActionsNativeExt2.Venture_Audit_Collector(i)
        If collector && !collector.IsDead()
            collector.StartCombat(player)
        EndIf
        i += 1
    EndWhile
    Return true
EndFunction

Bool Function BrushOffRetainer(Actor akActor)
    {Temper hearing FAILURE - the player dismissed the retainer's grievance to
     their face. Worse than never coming: morale drops hard, an aggrieved
     consensual retainer gives notice on the spot, a Tribute retainer turns
     openly defiant. Resolves the armed meeting.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_BrushOff(akActor)
    Return true
EndFunction

Bool Function NegotiateTerms(Actor akActor)
    {The player haggles a pending raise ask down the middle instead of granting
     it outright or refusing it. Splits the difference on wage or share, gives
     a smaller loyalty/morale bump than a full grant, and clears the ask so
     they stop pressing. No-op when nothing is pending. Consumes an armed
     hearing the same way GrantRetainerRaise does.}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_NegotiateRaise(akActor)
    Return true
EndFunction

Bool Function GrantRetainerRaise(Actor akActor)
    {The player agrees in conversation to raise this retainer's pay (or ease
     coerced terms). Actually moves the terms - not just words: grants the
     pending ask, re-grants refused terms, or applies a standard raise; skim
     stops, refusals clear, morale up, notice withdrawn. Consumes an armed
     hearing. Not for Enslaved (no wage or cut to move - change the
     arrangement instead).}
    If !akActor
        Return false
    EndIf
    SeverActionsNativeExt2.Venture_GrantRaiseInPerson(akActor)
    Return true
EndFunction