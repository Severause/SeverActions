Scriptname SeverActions_SpellTeach extends Quest
{Teaches spells between actors (with school-specific failures) and Words of Power to the player - by Severause}

; ===== Properties =====

Idle Property IdleTeaching Auto
Idle Property IdleLearning Auto
Idle Property IdleForceDefaultState Auto

; The three IMODs are unused: the fade runs through Game.FadeOutGame (see _StartFadeToBlack). Kept bindable.
ImageSpaceModifier Property FadeToBlackImod Auto
{ISFadeToBlackImod - fades screen to black}

ImageSpaceModifier Property FadeToBlackHoldImod Auto
{ISFadeToBlackHoldImod - holds the black screen}

ImageSpaceModifier Property FadeToBlackBackImod Auto
{ISFadeToBlackBackImod - fades screen back from black}

; Tunables. EnableFailureSystem / FailureDifficultyMult are tier-P settings rows (spellFailEnabled /
; spellFailDifficulty, MCM and web); the rest have no UI.
Float Property LearningDurationBase = 5.0 Auto Hidden
{Base duration in seconds for spell transfer}

Float Property ExhaustionPercentage = 0.15 Auto Hidden
{Percentage of max magicka drained from learner (0.15 = 15%)}

Bool Property RequireSkillCheck = False Auto Hidden
{If true, learning can fail based on skill level}

Bool Property GrantSkillXP = True Auto Hidden
{If true, learner gains skill XP in the spell's school}

Float Property SkillXPAmount = 25.0 Auto Hidden
{Base XP granted when learning a spell}

Bool Property UseFadeToBlack = True Auto Hidden
{If true, screen fades to black during spell transfer}

Bool Property EnableFailureSystem = True Auto Hidden
{If true, spell learning can fail with school-specific consequences}

Float Property FailureDifficultyMult = 1.0 Auto Hidden
{Multiplier for failure chance (0.5 = easier, 2.0 = harder)}

ObjectReference Property PendingCleanupCreature = None Auto Hidden
{Internal: creature from a failed Conjuration lesson, despawned by the tick after 10 s (partial) / 30 s (full failure)}

EffectShader Property SpellLearnedFXS Auto
{Optional EffectShader played on the learner on success (any EFSH).}

; ===== Spell school and difficulty =====

String Function GetSpellSchool(Spell akSpell)
    {Returns the magic school name for a spell}
    if !akSpell
        return "Unknown"
    endif
    
    MagicEffect firstEffect = akSpell.GetNthEffectMagicEffect(0)
    if !firstEffect
        return "Unknown"
    endif
    
    String school = firstEffect.GetAssociatedSkill()
    if school == ""
        return "Unknown"
    endif
    return school
EndFunction

String Function GetActorValueForSchool(String school)
    {Maps school name to ActorValue name}
    if school == "Destruction"
        return "Destruction"
    elseif school == "Restoration"
        return "Restoration"
    elseif school == "Alteration"
        return "Alteration"
    elseif school == "Illusion"
        return "Illusion"
    elseif school == "Conjuration"
        return "Conjuration"
    endif
    return ""
EndFunction

Int Function GetSpellDifficulty(Spell akSpell)
    {Returns difficulty tier: 0=Novice, 1=Apprentice, 2=Adept, 3=Expert, 4=Master}
    if !akSpell
        return 0
    endif
    
    Int baseCost = akSpell.GetGoldValue()
    
    ; Rough tiers by spell-tome price bands
    if baseCost <= 50
        return 0  ; Novice
    elseif baseCost <= 150
        return 1  ; Apprentice
    elseif baseCost <= 350
        return 2  ; Adept
    elseif baseCost <= 700
        return 3  ; Expert
    else
        return 4  ; Master
    endif
EndFunction

Int Function GetSkillRequirement(Int difficulty)
    {Returns minimum skill level for a given difficulty tier}
    if difficulty == 0
        return 0   ; Novice - anyone can learn
    elseif difficulty == 1
        return 25  ; Apprentice
    elseif difficulty == 2
        return 50  ; Adept
    elseif difficulty == 3
        return 75  ; Expert
    else
        return 90  ; Master
    endif
EndFunction

Float Function GetLearningDuration(Int difficulty)
    {Longer learning time for more difficult spells}
    return LearningDurationBase + (difficulty * 2.0)
EndFunction

; ===== Failure chance and outcome roll =====

Float Function CalculateFailureChance(Actor learner, Spell akSpell)
    {Calculate probability of failure (0.0 to 0.95) based on skill gap and difficulty}
    Int difficulty = GetSpellDifficulty(akSpell)

    ; Novice spells always succeed
    if difficulty == 0
        return 0.0
    endif

    ; 5% per tier, even when the skill requirement is met
    Float failChance = difficulty * 0.05

    ; +1% per skill point below the requirement
    String school = GetSpellSchool(akSpell)
    String avName = GetActorValueForSchool(school)
    if avName != ""
        Int required = GetSkillRequirement(difficulty)
        Float currentSkill = learner.GetActorValue(avName)
        if currentSkill < required
            Float gap = (required as Float) - currentSkill
            failChance += gap * 0.01
        endif
    endif

    failChance = failChance * FailureDifficultyMult

    ; Cap at 95%: never impossible
    if failChance > 0.95
        failChance = 0.95
    endif

    return failChance
EndFunction

Int Function RollOutcome(Float failChance)
    {Roll for outcome: 0=Full Failure, 1=Partial Success, 2=Full Success}
    if failChance <= 0.0
        return 2
    endif

    Float roll = Utility.RandomFloat(0.0, 1.0)

    if roll <= failChance * 0.5
        return 0  ; Full failure (half of all failures)
    elseif roll <= failChance
        return 1  ; Partial success
    else
        return 2
    endif
EndFunction

; ===== Internal helpers =====

Bool Function _CanLearn(Actor learner, Spell akSpell)
    if learner == None || akSpell == None
        return False
    endif
    if learner.HasSpell(akSpell)
        return False
    endif
    return True
EndFunction

Bool Function _MeetsSkillRequirement(Actor learner, Spell akSpell)
    {Check if learner has sufficient skill to learn the spell}
    if !RequireSkillCheck
        return True
    endif
    
    String school = GetSpellSchool(akSpell)
    String avName = GetActorValueForSchool(school)
    
    if avName == ""
        return True  ; Unknown school: allow
    endif
    
    Int difficulty = GetSpellDifficulty(akSpell)
    Int required = GetSkillRequirement(difficulty)
    Float currentSkill = learner.GetActorValue(avName)
    
    return currentSkill >= required
EndFunction

Function _ApplyExhaustion(Actor learner, Spell akSpell)
    {Drain magicka from learner based on spell difficulty}
    if ExhaustionPercentage <= 0.0
        return
    endif
    
    Int difficulty = GetSpellDifficulty(akSpell)
    ; Base value as the maximum: GetActorValue is the current, already-drained magicka.
    Float maxMagicka = learner.GetBaseActorValue("Magicka")
    Float drainAmount = maxMagicka * ExhaustionPercentage * (1.0 + (difficulty * 0.25))
    
    learner.DamageActorValue("Magicka", drainAmount)
EndFunction

Function _GrantSkillExperience(Actor learner, Spell akSpell)
    {Award skill XP in the appropriate school}
    if !GrantSkillXP
        return
    endif
    
    String school = GetSpellSchool(akSpell)
    String avName = GetActorValueForSchool(school)
    
    if avName == ""
        return
    endif
    
    Int difficulty = GetSpellDifficulty(akSpell)
    Float xpAmount = SkillXPAmount * (1.0 + (difficulty * 0.5))
    
    Game.AdvanceSkill(avName, xpAmount)
EndFunction

Function _ResetIdles(Actor actor1, Actor actor2)
    if IdleForceDefaultState
        if actor1
            actor1.PlayIdle(IdleForceDefaultState)
        endif
        if actor2
            actor2.PlayIdle(IdleForceDefaultState)
        endif
    endif
EndFunction

; ===== Fade to black =====

; Game.FadeOutGame, not the FadeToBlack IMODs: Community Shaders drops the IMOD stage.
; FadeOutGame does not hold black, so the fade-out runs for LongFadeOutSeconds (the screen
; stays mid-animation, dimming gradually) and _EndFadeToBlack interrupts it with the reverse
; fade. A snap-and-hold does not hold and a refresh loop flickers. FadeOutGame also locks
; player controls, which is wanted mid-lesson.

; Must outlast the lesson (about 6-14 s at the defaults), or the screen releases mid-lesson.
Float Property LongFadeOutSeconds = 30.0 Auto Hidden
Float Property FadeBackSeconds    = 1.5  Auto Hidden

Function _StartFadeToBlack()
    {Begin the fade to black effect}
    if !UseFadeToBlack
        return
    endif
    ; abFadingOut = to black, abBlackFade = black (not white)
    Game.FadeOutGame(true, true, 0.0, LongFadeOutSeconds)
EndFunction

Function _HoldFadeToBlack()
    {No-op: the long fade-out holds the black (see LongFadeOutSeconds).}
EndFunction

Function _EndFadeToBlack()
    {Interrupt the in-flight fade-out and reverse direction to clear}
    if !UseFadeToBlack
        return
    endif
    Game.FadeOutGame(false, true, 0.0, FadeBackSeconds)
EndFunction

; ===== Failure consequences, per school =====

Function _ApplyFailureConsequence(Actor teacher, Actor learner, String school, Int difficulty, Int outcome)
    {Dispatch to school-specific consequence}
    if school == "Destruction"
        _ApplyDestructionFailure(teacher, learner, difficulty, outcome)
    elseif school == "Conjuration"
        _ApplyConjurationFailure(learner, difficulty, outcome)
    elseif school == "Restoration"
        _ApplyRestorationFailure(learner, difficulty, outcome)
    elseif school == "Illusion"
        _ApplyIllusionFailure(learner, difficulty, outcome)
    elseif school == "Alteration"
        _ApplyAlterationFailure(learner, difficulty, outcome)
    else
        ; Unknown school - generic stagger + magicka drain
        Debug.SendAnimationEvent(learner, "staggerStart")
        learner.DamageActorValue("Magicka", learner.GetActorValue("Magicka") * 0.25)
    endif
EndFunction

Function _ApplyDestructionFailure(Actor teacher, Actor learner, Int difficulty, Int outcome)
    {Magical energy explodes outward - spell impact explosion + controlled HP damage}

    ; A spell cast at the learner for the impact visual: small for low tiers, AoE for high.
    Spell explosionSpell = None
    if difficulty <= 2
        explosionSpell = Game.GetFormFromFile(0x0007E56D, "Skyrim.esm") as Spell  ; TrapFirebolt01 (fire-and-forget)
    else
        explosionSpell = Game.GetFormFromFile(0x0001C789, "Skyrim.esm") as Spell  ; Fireball
    endif

    ; Ghost the teacher against the splash. Not the learner: the spell must hit them for the VFX.
    Bool teacherWasGhost = teacher.IsGhost()
    if !teacherWasGhost
        teacher.SetGhost(true)
    endif

    ; Cast from an XMarker 200 units above the learner, so no actor plays a cast animation.
    ObjectReference marker = None
    Form xMarker = Game.GetFormFromFile(0x0000003B, "Skyrim.esm")  ; XMarker
    if xMarker
        marker = learner.PlaceAtMe(xMarker)
        if marker
            marker.MoveTo(learner, 0.0, 0.0, 200.0)
        endif
    endif

    if explosionSpell && marker
        explosionSpell.Cast(marker, learner)
    endif

    Game.ShakeCamera(None, 1.0 + (difficulty as Float))

    Debug.SendAnimationEvent(learner, "staggerStart")

    ; Let the projectile land before un-ghosting the teacher
    Utility.Wait(1.0)

    if !teacherWasGhost
        teacher.SetGhost(false)
    endif

    if marker
        marker.Disable()
        marker.Delete()
    endif

    ; Scripted HP damage on top of the spell's own
    Float maxHP = learner.GetBaseActorValue("Health")
    Float damagePercent = 0.10 + (difficulty * 0.05)  ; 10% to 30%
    if outcome == 0
        damagePercent = damagePercent * 1.5
    endif
    Float damage = maxHP * damagePercent

    ; Floor at 10% max HP, counting the spell's damage
    Float currentHP = learner.GetActorValue("Health")
    Float minHP = maxHP * 0.10
    if (currentHP - damage) < minHP
        damage = currentHP - minHP
    endif
    if damage > 0.0
        learner.DamageActorValue("Health", damage)
    endif

    ; The spell alone may have gone below the floor: heal back to it
    currentHP = learner.GetActorValue("Health")
    if currentHP < minHP
        learner.RestoreActorValue("Health", minHP - currentHP)
    endif
EndFunction

Function _ApplyConjurationFailure(Actor learner, Int difficulty, Int outcome)
    {A hostile creature tears through the failed conjuration with purple vortex VFX}
    _CleanupSpawnedCreature()

    ; One untemplated Enc* ActorBase per tier.
    Form creatureForm = None
    if difficulty <= 1
        creatureForm = Game.GetFormFromFile(0x00023AB7, "Skyrim.esm")  ; EncSkeever
    elseif difficulty == 2
        creatureForm = Game.GetFormFromFile(0x0002D1DE, "Skyrim.esm")  ; EncSkeleton01Melee1H
    elseif difficulty == 3
        creatureForm = Game.GetFormFromFile(0x00023AA7, "Skyrim.esm")  ; EncAtronachFrost
    else
        creatureForm = Game.GetFormFromFile(0x00023A95, "Skyrim.esm")  ; EncDremoraMelee01
    endif

    if !creatureForm
        ; Form missing: stagger + magicka drain
        Debug.SendAnimationEvent(learner, "staggerStart")
        learner.DamageActorValue("Magicka", learner.GetActorValue("Magicka") * 0.3)
        return
    endif

    ActorBase creatureBase = creatureForm as ActorBase
    if !creatureBase
        ; An override made it something else: the same punishment as a missing form
        Debug.SendAnimationEvent(learner, "staggerStart")
        learner.DamageActorValue("Magicka", learner.GetActorValue("Magicka") * 0.3)
        return
    endif

    ; The vanilla summon vortex; it disables and deletes itself (MGRitual03EffectScript's pattern).
    Form portalForm = Game.GetFormFromFile(0x0007CD55, "Skyrim.esm")  ; SummonTargetFXActivator
    if portalForm
        learner.PlaceAtMe(portalForm)
    endif

    ; Let the portal appear first (vanilla waits 0.33 s)
    Utility.Wait(0.5)

    Actor creature = learner.PlaceActorAtMe(creatureBase)
    if creature
        if outcome == 0
            ; Full failure: it attacks; despawned after 30 s
            creature.StartCombat(learner)
            PendingCleanupCreature = creature as ObjectReference
            ChronoArm(30.0)
        else
            ; Partial success: no StartCombat, despawned after 10 s (its own AI may still attack)
            PendingCleanupCreature = creature as ObjectReference
            ChronoArm(10.0)
        endif
    endif

    Game.ShakeCamera(None, 1.5)
EndFunction

Function _ApplyRestorationFailure(Actor learner, Int difficulty, Int outcome)
    {Healing energy inverts - drains HP and Stamina}
    Debug.SendAnimationEvent(learner, "staggerStart")

    Float maxHP = learner.GetBaseActorValue("Health")
    Float hpDrain = maxHP * (0.08 + (difficulty * 0.04))  ; 8% to 24%
    if outcome == 0
        hpDrain = hpDrain * 1.5
    endif

    ; Floor at 10% max HP
    Float currentHP = learner.GetActorValue("Health")
    if (currentHP - hpDrain) < (maxHP * 0.10)
        hpDrain = currentHP - (maxHP * 0.10)
    endif
    if hpDrain > 0.0
        learner.DamageActorValue("Health", hpDrain)
    endif

    Float maxStamina = learner.GetBaseActorValue("Stamina")
    Float staminaDrain = maxStamina * (0.15 + (difficulty * 0.10))  ; 15% to 55%
    learner.DamageActorValue("Stamina", staminaDrain)
EndFunction

Function _ApplyIllusionFailure(Actor learner, Int difficulty, Int outcome)
    {Mental backlash - stagger + stamina drain for player, fear/frenzy for NPCs}
    Actor player = Game.GetPlayer()

    if learner == player
        ; No fear/frenzy on the player: stagger and drains only
        Debug.SendAnimationEvent(learner, "staggerStart")
        Float maxStamina = learner.GetBaseActorValue("Stamina")
        Float drain = maxStamina * (0.20 + (difficulty * 0.15))  ; 20% to 80%
        learner.DamageActorValue("Stamina", drain)
        learner.DamageActorValue("Magicka", learner.GetActorValue("Magicka") * 0.2)
    else
        ; NPC, full failure: 4DEEF Rout (fear) for low tiers, 4DEEE Frenzy for high. A partial
        ; success only staggers: the lesson resumes on this NPC.
        Debug.SendAnimationEvent(learner, "staggerStart")
        if outcome >= 1
            return
        endif
        if difficulty <= 2
            Spell fearSpell = Game.GetFormFromFile(0x0004DEEF, "Skyrim.esm") as Spell
            if fearSpell
                fearSpell.Cast(learner, learner)
            endif
        else
            Spell frenzySpell = Game.GetFormFromFile(0x0004DEEE, "Skyrim.esm") as Spell
            if frenzySpell
                frenzySpell.Cast(learner, learner)
            endif
        endif
    endif
EndFunction

Function _ApplyAlterationFailure(Actor learner, Int difficulty, Int outcome)
    {Reality warps around the learner - push or paralysis}
    if difficulty <= 2
        ; Low tier: stagger; an NPC is pushed away, the player loses stamina
        Debug.SendAnimationEvent(learner, "staggerStart")
        Game.ShakeCamera(None, 1.0)
        Actor player = Game.GetPlayer()
        if learner != player
            player.PushActorAway(learner, 2.0)
        else
            learner.DamageActorValue("Stamina", learner.GetActorValue("Stamina") * 0.3)
        endif
    else
        ; High tier: paralysis, 3 s (5 s at Master)
        Float paralyzeTime = 3.0
        if difficulty >= 4
            paralyzeTime = 5.0
        endif
        ; Persist the pending reset BEFORE paralyzing: a save made inside the window would
        ; otherwise keep Paralysis=1 (possibly on the player) for good, since the suspended
        ; Wait is not guaranteed to resume. Maintenance() clears the list on load; the tick
        ; re-checks it after the window.
        StorageUtil.FormListAdd(Self, "SeverSpellTeach_PendingParalyze", learner, false)
        StorageUtil.SetFloatValue(learner, "SeverSpellTeach_ParalyzeUntil", Utility.GetCurrentRealTime() + paralyzeTime)
        learner.SetActorValue("Paralysis", 1.0)
        ChronoArm(paralyzeTime + 0.5)
        Utility.Wait(paralyzeTime)
        ; Normal path; the tick's sweep then finds nothing.
        _ClearPendingParalysis(learner)
    endif
EndFunction

; ===== Failure narration (SkyrimNet event text) =====

String Function _GetFailureNarration(String teacherName, String learnerName, String spellName, String school, Int difficulty, Int outcome)
    {Generate school-specific failure narration for SkyrimNet events}
    String diffName = _DifficultyName(difficulty)

    if outcome == 0
        ; Full failure narrations
        if school == "Destruction"
            return "The " + spellName + " spell spirals out of control! Raw destructive energy erupts from " + learnerName + "'s hands, scorching them with their own misfired magic. " + teacherName + " shields their face from the blast. The " + diffName + "-level spell proves too volatile."
        elseif school == "Conjuration"
            return "The " + spellName + " spell tears open an unstable rift! Instead of controlled summoning, a hostile creature claws through the breach. " + teacherName + " shouts a warning as the botched " + diffName + "-level conjuration goes terribly wrong."
        elseif school == "Restoration"
            return "The healing energies of " + spellName + " invert violently! What should have been restorative magic drains " + learnerName + "'s vitality instead. " + teacherName + " watches in alarm as the " + diffName + "-level restoration backfires."
        elseif school == "Illusion"
            return "The mental energies of " + spellName + " rebound into " + learnerName + "'s mind! The " + diffName + "-level illusion creates a psychic backlash that leaves them staggered and disoriented. " + teacherName + " steadies them."
        elseif school == "Alteration"
            return "Reality warps uncontrollably as " + learnerName + " attempts " + spellName + "! The " + diffName + "-level alteration magic twists space around them. " + teacherName + " watches helplessly."
        else
            return learnerName + " loses control of the " + spellName + " spell. The " + diffName + "-level magic proves too difficult, and the misfire leaves them weakened."
        endif
    else
        ; Partial success narrations
        if school == "Destruction"
            return "Sparks of wild energy burst from " + learnerName + "'s hands as they struggle with " + spellName + ". " + teacherName + " helps them regain control, though not before the misfired magic singes them. Despite the rough practice, the " + diffName + "-level spell takes hold."
        elseif school == "Conjuration"
            return "The practice of " + spellName + " briefly tears open an unintended rift, and something hostile slips through before " + teacherName + " can seal it. Despite the dangerous mishap, " + learnerName + " grasps the " + diffName + "-level conjuration."
        elseif school == "Restoration"
            return "The restorative energies of " + spellName + " fluctuate wildly, alternating between healing and harm. " + teacherName + " guides " + learnerName + " through the turbulent practice. The " + diffName + "-level spell is learned, but at a physical cost."
        elseif school == "Illusion"
            return "Learning " + spellName + " sends a psychic shockwave through " + learnerName + "'s mind. " + teacherName + " talks them through the mental storm. The " + diffName + "-level illusion is mastered, though the mental strain lingers."
        elseif school == "Alteration"
            return "Space ripples dangerously as " + learnerName + " practices " + spellName + ". " + teacherName + " quickly corrects the misalignment before reality snaps back. The " + diffName + "-level alteration is learned through the mishap."
        else
            return learnerName + " struggles with " + spellName + " but manages to learn it with " + teacherName + "'s guidance, though not without some painful magical feedback."
        endif
    endif
EndFunction

; ===== Creature cleanup and the chrono tick =====

Function _CleanupSpawnedCreature()
    {Clean up any pending conjuration failure creature}
    if PendingCleanupCreature
        Actor creature = PendingCleanupCreature as Actor
        if creature
            creature.Disable()
            creature.Delete()
        endif
        PendingCleanupCreature = None
    endif
EndFunction

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick (see the Chronometer block in SeverActionsNativeExt2.psc).
     Event and callback names are unique to this script. Re-arm replaces the pending tick; ticks do
     not survive a load; one in-flight tick can land after a Cancel, so the handler stays state-guarded.}
    RegisterForModEvent("SeverActions_Tick_SpellTeach", "OnChronoTick_SpellTeach")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_SpellTeach", afSeconds)
    _TickRearmed = true
EndFunction

; Set by ChronoArm, cleared at the top of the tick. A tick that did not re-arm must Cancel:
; a fired tick is acknowledged only by a re-Request or a Cancel, else the DLL re-sends it.
Bool _TickRearmed = false

Event OnChronoTick_SpellTeach(String eventName, String strArg, Float numArg, Form sender)
    ; One tick serves the creature despawn and the paralysis sweep: whichever deadline fires
    ; first runs both (so the creature can go early).
    _TickRearmed = false
    _CleanupSpawnedCreature()
    _SweepPendingParalysis(false)
    If !_TickRearmed
        SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_SpellTeach")
    EndIf
EndEvent

; ===== Paralysis reset (see _ApplyAlterationFailure) =====

Function Maintenance()
    {Load recovery, called from SeverActions_Mod_Items stage 1. Clears every pending paralysis
     (real-time deadlines mean nothing after a load) and arms one tick for a creature left from the save.}
    ChronoArm(1.0)
    _SweepPendingParalysis(true)
EndFunction

Function _SweepPendingParalysis(Bool abForce)
    {Reset Paralysis on every actor whose pending window has expired (or on
     all of them when abForce). Re-arms the tick for windows still open.}
    Int i = StorageUtil.FormListCount(Self, "SeverSpellTeach_PendingParalyze")
    if i <= 0
        return
    endif

    Float now = Utility.GetCurrentRealTime()
    Float nextWait = 0.0
    while i > 0
        i -= 1
        Actor pending = StorageUtil.FormListGet(Self, "SeverSpellTeach_PendingParalyze", i) as Actor
        if !pending
            ; Stale entry: drop it
            StorageUtil.FormListRemoveAt(Self, "SeverSpellTeach_PendingParalyze", i)
        else
            Float deadline = StorageUtil.GetFloatValue(pending, "SeverSpellTeach_ParalyzeUntil", 0.0)
            if abForce || now >= deadline
                _ClearPendingParalysis(pending)
            else
                Float remaining = deadline - now
                if nextWait == 0.0 || remaining < nextWait
                    nextWait = remaining
                endif
            endif
        endif
    endwhile

    if nextWait > 0.0
        ; A window is still open (the tick fired early, e.g. the creature's): re-arm for it
        ChronoArm(nextWait + 0.1)
    endif
EndFunction

Function _ClearPendingParalysis(Actor akActor)
    {Reset the failure paralysis and drop its pending entry. Idempotent.}
    if !akActor
        return
    endif
    akActor.SetActorValue("Paralysis", 0.0)
    StorageUtil.UnsetFloatValue(akActor, "SeverSpellTeach_ParalyzeUntil")
    StorageUtil.FormListRemove(Self, "SeverSpellTeach_PendingParalyze", akActor, true)
EndFunction

; ===== Narration sync =====

Function _WaitForNarrationComplete()
    {Block until DirectNarration audio has played (it enters the speech queue, then the queue
     drains), so consequences do not fire while the teacher is still talking.}

    ; Enter the queue: up to 10 s (TTS typically 1-5 s)
    int waitForQueue = 0
    while SkyrimNetApi.GetSpeechQueueSize() == 0 && waitForQueue < 20
        Utility.Wait(0.5)
        waitForQueue += 1
    endwhile

    ; Drain: up to 60 s (narration typically 5-15 s)
    int waitForDrain = 0
    while SkyrimNetApi.GetSpeechQueueSize() > 0 && waitForDrain < 120
        Utility.Wait(0.5)
        waitForDrain += 1
    endwhile
EndFunction

; ===== Spell transfer (shared by TeachSpell and LearnSpell) =====

Bool Function TransferSpell_IsEligible(Actor teacher, Actor learner, Spell akSpell)
    {Teacher knows it, learner does not, neither in combat, skill gate if enabled}
    if !teacher || !learner || !akSpell
        return false
    endif
    
    if !teacher.HasSpell(akSpell)
        return false
    endif
    
    if !_CanLearn(learner, akSpell)
        return false
    endif
    
    if teacher.IsInCombat() || learner.IsInCombat()
        return false
    endif
    
    if RequireSkillCheck && !_MeetsSkillRequirement(learner, akSpell)
        return false
    endif
    
    return true
EndFunction

Function TransferSpell_Execute(Actor teacher, Actor learner, Spell akSpell)
    {Runs the lesson: fade, idles, a mid-lesson failure roll, then the spell, exhaustion and XP}
    if !teacher || !learner || !akSpell
        return
    endif

    ; Magic overhauls give NPCs hand-locked copies (MAG_FireboltRightHand) with the same name as
    ; the tome's either-hand spell: teach the PLAYER the tome version, or they can use it in one
    ; hand only. Player only: an NPC keeps the teacher's exact variant, since another one can need
    ; a perk the NPC lacks (SA's CastSpell casts a perk-free clone, see SpellCastManager::CloneSpellForCast).
    if learner == Game.GetPlayer()
        Spell learnable = SeverActionsNative.GetLearnableSpellVariant(akSpell) as Spell
        if learnable && learnable != akSpell
            Debug.Trace("[SeverActions_SpellTeach] Teaching the player the unrestricted variant of "                 + akSpell.GetName() + " instead of the teacher's one-handed copy")
            akSpell = learnable
        endif
    endif

    String spellName = akSpell.GetName()
    String teacherName = teacher.GetDisplayName()
    String learnerName = learner.GetDisplayName()
    String school = GetSpellSchool(akSpell)
    Int difficulty = GetSpellDifficulty(akSpell)
    Bool isPartialSuccess = false

    _StartFadeToBlack()

    Utility.Wait(1.0)

    _HoldFadeToBlack()

    if IdleTeaching
        teacher.PlayIdle(IdleTeaching)
    endif
    if IdleLearning
        learner.PlayIdle(IdleLearning)
    endif

    Float duration = GetLearningDuration(difficulty)

    ; First half of the practice, then the failure roll
    Utility.Wait(duration * 0.5)

    if EnableFailureSystem && difficulty > 0
        Float failChance = CalculateFailureChance(learner, akSpell)
        Int outcome = RollOutcome(failChance)

        if outcome < 2
            ; Lift the fade so the player sees the consequence
            _ResetIdles(teacher, learner)
            _EndFadeToBlack()
            Utility.Wait(0.5)

            _ApplyFailureConsequence(teacher, learner, school, difficulty, outcome)

            String narration = _GetFailureNarration(teacherName, learnerName, spellName, school, difficulty, outcome)

            if outcome == 0
                ; Full failure: nothing learned, double exhaustion
                _ApplyExhaustion(learner, akSpell)
                _ApplyExhaustion(learner, akSpell)
                SkyrimNetApi.DirectNarration(narration, teacher, learner)
                _WaitForNarrationComplete()
                Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("spellteach.spellFailed", ("" + spellName)))
                return
            else
                ; Partial success: the lesson resumes after the narration
                isPartialSuccess = true
                SkyrimNetApi.DirectNarration(narration, teacher, learner)

                _WaitForNarrationComplete()

                _StartFadeToBlack()
                Utility.Wait(1.0)
                _HoldFadeToBlack()

                if IdleTeaching
                    teacher.PlayIdle(IdleTeaching)
                endif
                if IdleLearning
                    learner.PlayIdle(IdleLearning)
                endif
            endif
        endif
    endif

    ; Second half of the practice
    Utility.Wait(duration * 0.5)

    ; Re-check: the learner may have gained the spell meanwhile
    if !_CanLearn(learner, akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            teacherName + " attempted to teach " + spellName + " but " + learnerName + " already possesses this knowledge.", \
            teacher, learner)
        _ResetIdles(teacher, learner)
        _EndFadeToBlack()
        return
    endif

    ; Skill gate for callers that skip TransferSpell_IsEligible (the SkyrimNet actions do)
    if RequireSkillCheck && !_MeetsSkillRequirement(learner, akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            learnerName + " struggled to comprehend the " + school + " magic. The " + spellName + " spell proves too advanced for their current skill level.", \
            teacher, learner)
        _ApplyExhaustion(learner, akSpell)
        _ResetIdles(teacher, learner)
        _EndFadeToBlack()
        return
    endif

    ; Success, full or partial
    learner.AddSpell(akSpell, false)
    if isPartialSuccess
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("spellteach.spellLearnedPartial", ("" + spellName)))
    else
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("spellteach.spellLearned", ("" + spellName)))
    endif

    _ApplyExhaustion(learner, akSpell)

    ; Grant XP: full for clean success, half for partial
    if !isPartialSuccess
        _GrantSkillExperience(learner, akSpell)
    else
        ; Half of _GrantSkillExperience's amount (same formula; keep in step)
        if GrantSkillXP
            String avName = GetActorValueForSchool(school)
            if avName != ""
                Float halfXP = (SkillXPAmount * (1.0 + (difficulty * 0.5))) * 0.5
                Game.AdvanceSkill(avName, halfXP)
            endif
        endif
    endif

    _ResetIdles(teacher, learner)

    _EndFadeToBlack()

    if SpellLearnedFXS
        SpellLearnedFXS.Play(learner, 3.0)
    endif

    String difficultyDesc = ""
    if difficulty == 0
        difficultyDesc = "basic"
    elseif difficulty == 1
        difficultyDesc = "foundational"
    elseif difficulty == 2
        difficultyDesc = "complex"
    elseif difficulty == 3
        difficultyDesc = "intricate"
    else
        difficultyDesc = "masterful"
    endif

    if isPartialSuccess
        ; The failure narration already played: event only
        SkyrimNetApi.RegisterEvent("spell_learned_partial", \
            learnerName + " learned the " + difficultyDesc + " " + school + " spell " + spellName + " from " + teacherName + ", though the practice was rough and had consequences.", \
            teacher, learner)
    else
        SkyrimNetApi.RegisterEvent("spell_learned", \
            teacherName + " guided " + learnerName + " through the " + difficultyDesc + " " + school + " spell, " + spellName + ". The knowledge takes root in " + learnerName + "'s mind.", \
            teacher, learner)
    endif
EndFunction

; ===== Older public entry points (no caller in this tree); they forward to TransferSpell_* =====

; akActor = the teacher
Bool Function TeachSpell_IsEligible(Actor akActor, Actor student, Spell akSpell)
    return TransferSpell_IsEligible(akActor, student, akSpell)
EndFunction

Function TeachSpell_Execute(Actor akActor, Actor student, Spell akSpell)
    TransferSpell_Execute(akActor, student, akSpell)
EndFunction

; akActor = the learner
Bool Function LearnSpell_IsEligible(Actor akActor, Actor teacher, Spell akSpell)
    return TransferSpell_IsEligible(teacher, akActor, akSpell)
EndFunction

Function LearnSpell_Execute(Actor akActor, Actor teacher, Spell akSpell)
    TransferSpell_Execute(teacher, akActor, akSpell)
EndFunction

; ===== SkyrimNet actions (teachspell/learnspell YAMLs; also the Actions-page verbs via Loot) =====
; Each resolves the spell by name (native SpellDB) and runs TransferSpell_Execute.

; The NPC akActor teaches the player; spellName is the LLM's name for the spell.
Function TeachSpell(Actor akActor, String spellName)
    ; One 10 s cooldown across teach and learn
    SkyrimNetApi.SetActionCooldown("teachspell", 10)
    SkyrimNetApi.SetActionCooldown("learnspell", 10)

    Actor player = Game.GetPlayer()

    ; Fuzzy match against the teacher's known spells
    Form spellForm = SeverActionsNative.FindSpellOnActor(akActor, spellName)
    if !spellForm
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            akActor.GetDisplayName() + " doesn't know any spell called " + spellName + ".", \
            akActor, player)
        return
    endif

    Spell akSpell = spellForm as Spell
    if !akSpell
        return
    endif

    ; Swap to the tome variant BEFORE the already-knows check, or a player who owns it passes the
    ; check (they lack the teacher's hand-locked copy) and TransferSpell_Execute refuses at the end.
    Spell learnable = SeverActionsNative.GetLearnableSpellVariant(akSpell) as Spell
    if learnable
        akSpell = learnable
    endif

    if player.HasSpell(akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            player.GetDisplayName() + " already knows " + akSpell.GetName() + ".", \
            akActor, player)
        return
    endif

    String school = GetSpellSchool(akSpell)
    String diffName = _DifficultyName(GetSpellDifficulty(akSpell))
    String narration = akActor.GetDisplayName() + " begins teaching " + player.GetDisplayName() + \
        " the " + diffName + "-level " + school + " spell " + akSpell.GetName() + "."
    SkyrimNetApi.DirectNarration(narration, akActor, player)

    _WaitForNarrationComplete()

    TransferSpell_Execute(akActor, player, akSpell)
EndFunction

; The NPC akActor learns a spell from the player.
Function LearnSpell(Actor akActor, String spellName)
    ; One 10 s cooldown across teach and learn
    SkyrimNetApi.SetActionCooldown("teachspell", 10)
    SkyrimNetApi.SetActionCooldown("learnspell", 10)

    Actor player = Game.GetPlayer()

    ; Fuzzy match against the player's known spells
    Form spellForm = SeverActionsNative.FindSpellOnActor(player, spellName)
    if !spellForm
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            player.GetDisplayName() + " doesn't know any spell called " + spellName + ".", \
            player, akActor)
        return
    endif

    Spell akSpell = spellForm as Spell
    if !akSpell
        return
    endif

    if akActor.HasSpell(akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            akActor.GetDisplayName() + " already knows " + akSpell.GetName() + ".", \
            player, akActor)
        return
    endif

    String school = GetSpellSchool(akSpell)
    String diffName = _DifficultyName(GetSpellDifficulty(akSpell))
    String narration = player.GetDisplayName() + " begins teaching " + akActor.GetDisplayName() + \
        " the " + diffName + "-level " + school + " spell " + akSpell.GetName() + "."
    SkyrimNetApi.DirectNarration(narration, akActor, player)

    _WaitForNarrationComplete()

    TransferSpell_Execute(player, akActor, akSpell)
EndFunction

String Function _DifficultyName(Int difficulty)
    if difficulty == 0
        return "Novice"
    elseif difficulty == 1
        return "Apprentice"
    elseif difficulty == 2
        return "Adept"
    elseif difficulty == 3
        return "Expert"
    else
        return "Master"
    endif
EndFunction

; ===== Shout teaching =====
; An NPC whose effective record carries Shouts (SpellDB::EffectiveShoutSource; the
; can_teach_shouts decorator gates the action) teaches the player the next unknown word of the
; named Shout, one per lesson: TeachWord AND UnlockWord, no dragon soul (as in MQ105). Word
; state is player-global, so wall-learned and taught words combine.

Function TeachShout(Actor akActor, String shoutName)
    SkyrimNetApi.SetActionCooldown("teachshout", 10)

    Actor player = Game.GetPlayer()

    Form shoutForm = SeverActionsNativeExt.Native_FindShoutOnActor(akActor, shoutName)
    if !shoutForm
        SkyrimNetApi.RegisterEvent("shout_teach_failed", \
            akActor.GetDisplayName() + " does not know a Shout called " + shoutName + ".", \
            akActor, player)
        return
    endif
    Shout akShout = shoutForm as Shout
    if !akShout
        return
    endif

    Form wordForm = SeverActionsNativeExt.Native_Shout_GetNextWord(shoutForm)
    if !wordForm
        SkyrimNetApi.RegisterEvent("shout_teach_failed", \
            player.GetDisplayName() + " already knows all three words of " + akShout.GetName() + ".", \
            akActor, player)
        return
    endif
    WordOfPower word = wordForm as WordOfPower
    if !word
        return
    endif

    String wordName = SeverActionsNativeExt.Native_Shout_WordName(wordForm)

    ; TeachWord is a word wall's part, UnlockWord a dragon soul's
    Game.TeachWord(word)
    Game.UnlockWord(word)
    if !player.HasSpell(akShout)
        player.AddShout(akShout)
    endif

    Int known = SeverActionsNativeExt.Native_Shout_KnownWordCount(shoutForm)
    String progress = "the first word of " + akShout.GetName()
    if known >= 3
        progress = "the final word - " + akShout.GetName() + " is now wholly theirs"
    elseif known == 2
        progress = "the second word of " + akShout.GetName()
    endif

    SkyrimNetApi.DirectNarration("*" + akActor.GetDisplayName() + " speaks " + wordName + \
        ", slowly, and its meaning settles into " + player.GetDisplayName() + \
        "'s mind - " + progress + ", freely given, no dragon soul demanded.*", \
        akActor, player)
    SkyrimNetApi.RegisterEvent("shout_word_taught", \
        akActor.GetDisplayName() + " taught " + player.GetDisplayName() + " the word " + \
        wordName + " of the Shout " + akShout.GetName() + ".", \
        akActor, player)
EndFunction
