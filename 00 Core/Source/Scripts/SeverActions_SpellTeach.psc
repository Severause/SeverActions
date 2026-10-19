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
    {Returns the magic school name for a spell (SpellDB's reading; "Unknown" for none)}
    if !akSpell
        return "Unknown"
    endif
    String nativeSchool = SeverActionsNativeExt2.Spell_GetSchool(akSpell)
    if nativeSchool != ""
        return nativeSchool
    endif

    ; An older DLL (or no school): the first effect's skill.
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
    {Returns difficulty tier: 0=Novice, 1=Apprentice, 2=Adept, 3=Expert, 4=Master (SpellDB's reading)}
    if !akSpell
        return 0
    endif
    return SeverActionsNativeExt2.Spell_GetTier(akSpell)
EndFunction

Int Function GetSkillRequirement(Int difficulty)
    {Returns the skill a tier starts at (0, 25, 50, 75, 100). A spell's own requirement is
     _RequiredSkill (its casting perk and its effects).}
    if difficulty == 0
        return 0   ; Novice - anyone can learn
    elseif difficulty == 1
        return 25  ; Apprentice
    elseif difficulty == 2
        return 50  ; Adept
    elseif difficulty == 3
        return 75  ; Expert
    else
        return 100 ; Master
    endif
EndFunction

Int Function _RequiredSkill(Spell akSpell)
    {The skill the spell requires (SpellDB). An older DLL reads 0: no skill gate.}
    return SeverActionsNativeExt2.Spell_GetRequiredSkill(akSpell)
EndFunction

Float Function GetLearningDuration(Int difficulty)
    {Longer learning time for more difficult spells}
    return LearningDurationBase + (difficulty * 2.0)
EndFunction

; ===== Failure chance and outcome roll =====

Float Function _LessonFailChance(Actor learner, Actor teacher, Spell akSpell)
    {The lesson's failure chance (0.0 to 0.95), from the learning rule (SpellLearnCore): the skill gap, the tier,
     the teacher's own skill and the difficulty setting.}
    return (SeverActionsNativeExt2.Spell_LessonFailChance(learner, akSpell, teacher, FailureDifficultyMult) as Float) / 100.0
EndFunction

Float Function CalculateFailureChance(Actor learner, Spell akSpell)
    {Calculate probability of failure (0.0 to 0.95) based on skill gap and difficulty. Superseded by
     _LessonFailChance (the learning rule); kept for an older caller.}
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
        Int required = _RequiredSkill(akSpell)
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
    
    Int required = _RequiredSkill(akSpell)
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
    _GrantSkillExperienceScaled(learner, akSpell, 1.0)
EndFunction

Function _GrantSkillExperienceScaled(Actor learner, Spell akSpell, Float afScale)
    {Award afScale of the lesson's skill XP. The PLAYER only: Game.AdvanceSkill advances the player's skill
     whoever learned, so an NPC learner gets none (it would have gone to the player).}
    if !GrantSkillXP || learner != Game.GetPlayer()
        return
    endif

    String school = GetSpellSchool(akSpell)
    String avName = GetActorValueForSchool(school)

    if avName == ""
        return
    endif

    Int difficulty = GetSpellDifficulty(akSpell)
    Float xpAmount = SkillXPAmount * (1.0 + (difficulty * 0.5)) * afScale

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

    ; Ghost the teacher against the splash. Not the learner: the spell must hit them for the VFX. A tome has no
    ; teacher (None).
    Bool teacherWasGhost = true
    if teacher
        teacherWasGhost = teacher.IsGhost()
        if !teacherWasGhost
            teacher.SetGhost(true)
        endif
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

    if teacher && !teacherWasGhost
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
    _ProcessStudies()
    _TendReaders()
    ; Studies are game-time: a check every 15 s keeps up with a wait or a sleep, and ends the reads.
    If !_TickRearmed && (SeverActionsNativeExt2.Spell_StudyCount() > 0 || _readerCount > 0)
        ChronoArm(15.0)
    EndIf
    If !_TickRearmed
        SeverActionsNativeExt2.Chrono_Cancel("SeverActions_Tick_SpellTeach")
    EndIf
EndEvent

; ===== Studying a spell tome (an NPC reads a tome they carry; SpellLearnStore's sessions) =====

; StudySpellTome YAML: the speaker begins studying a tome they carry; tomeName names the spell or the book.
Function StudySpellTome(Actor akActor, String tomeName)
    SkyrimNetApi.SetActionCooldown("studyspelltome", 10)
    if !akActor
        return
    endif
    Book tome = SeverActionsNativeExt2.Spell_FindTomeOnActor(akActor, tomeName)
    if !tome
        SkyrimNetApi.RegisterEvent("spell_study_failed", akActor.GetDisplayName() + " carries no spell tome called " + tomeName + ".", akActor, None)
        return
    endif
    StudyTome(akActor, tome)
EndFunction

; Begin studying akTome (StudySpellTome, and the Inventory page's Study button). The reading takes game hours
; (SpellLearnCore::StudyHours) while they are not fighting; the tick finishes it (_FinishStudy).
Function StudyTome(Actor akActor, Book akTome)
    if !akActor || !akTome || akActor == Game.GetPlayer()
        return
    endif
    String actorName = akActor.GetDisplayName()
    Spell taught = akTome.GetSpell()
    if !taught
        SkyrimNetApi.RegisterEvent("spell_study_failed", akTome.GetName() + " teaches no spell.", akActor, None)
        return
    endif
    if SeverActionsNativeExt2.Spell_IsUnteachable(taught)
        SkyrimNetApi.RegisterEvent("spell_study_failed", taught.GetName() + " is a power, not a spell: no tome can teach it to " + actorName + ".", akActor, None)
        return
    endif
    if akActor.HasSpell(taught)
        SkyrimNetApi.RegisterEvent("spell_study_failed", actorName + " already knows " + taught.GetName() + ".", akActor, None)
        return
    endif
    if RequireSkillCheck && !_MeetsSkillRequirement(akActor, taught)
        SkyrimNetApi.RegisterEvent("spell_study_failed", taught.GetName() + " is beyond " + actorName + "'s skill, and they do not try.", akActor, None)
        return
    endif
    Bool continuing = SeverActionsNativeExt2.Spell_StudyBook(akActor) == akTome
    Bool switching = !continuing && SeverActionsNativeExt2.Spell_StudyHoursLeft(akActor) >= 0.0
    Int hours = SeverActionsNativeExt2.Spell_StartStudy(akActor, akTome)
    if hours < 0
        SkyrimNetApi.RegisterEvent("spell_study_failed", actorName + " cannot study " + akTome.GetName() + ".", akActor, None)
        return
    endif
    String spellName = taught.GetName()
    String noticeKey = "spellteach.studyStarted"
    if continuing
        noticeKey = "spellteach.studyResumed"
    endif
    String notice = SeverActionsNativeExt2.Native_L10nFmt(noticeKey, actorName, spellName)
    if hours > 0
        notice += " " + SeverActionsNativeExt2.Native_L10nFmt("spellteach.studyHours", ("" + hours))
    endif
    Debug.Notification(notice)
    String hoursText = hours + " hours"
    if hours == 1
        hoursText = "an hour"
    endif
    String narration = actorName + " opens " + akTome.GetName() + " and begins to study " + taught.GetName() + \
        "; it will take about " + hoursText + " of quiet reading."
    if continuing
        narration = actorName + " goes back to " + akTome.GetName() + "; about " + hoursText + " of reading are left."
    elseif switching
        narration = actorName + " sets aside the tome they were reading. " + narration
    endif
    if !continuing
        narration += _BeyondWarning(akActor, taught)
    endif
    SkyrimNetApi.DirectNarration(narration, akActor)
    ; The next tick picks the study up; a pending creature's own tick does too, so it is not cut short.
    if !PendingCleanupCreature
        ChronoArm(1.0)
    endif
    _BeginStudyIdle(akActor)   ; last: it can wait a moment
EndFunction

; ===== Reading during a study =====
; A studying NPC is seen reading: at the start of the study (StudyTome), whenever they sit on a seat while the study
; lasts, and now and then while they stand still near the player. Up to 8 at once (the arrays' size, a literal in each
; `new`); the tick (every 15 s while a study or a read lasts) starts and ends the reads. A seated read lasts until they
; stand (getting up ends the idle); a standing one about half a minute (kStandingReadSeconds, checked on a 15 s tick).
; Maintenance forgets them on a load (an idle does not outlive one).
Float Property kStandingReadSeconds = 20.0 AutoReadOnly
Actor[] _readers
Float[] _readUntil    ; real seconds; 0 = a seated read
Int _readerCount = 0

Bool Function _InMenu()
    {A paused menu (or SeverActions' own): Utility.Wait does not run, and the player cannot see a read.}
    return Utility.IsInMenuMode() || SeverActionsNativeExt2.Magelight_IsMenuOpen()
EndFunction

Bool Function _CanRead(Actor akActor, SeverActions_Loot loot)
    {Loaded near the player and free to read: not fighting, mounted, swimming, in bed, talking to the player or with a
     weapon out, and not in another animation (a scene, a captive's pose, a paralysis, Loot's reading aloud).}
    if !akActor || !akActor.Is3DLoaded() || akActor.GetDistance(Game.GetPlayer()) > 3000.0
        return false
    endif
    if akActor.IsInCombat() || akActor.IsOnMount() || akActor.IsSwimming() || akActor.GetSleepState() != 0 || \
        akActor.IsWeaponDrawn() || akActor.IsInDialogueWithPlayer()
        return false
    endif
    if SeverActionsNative.Native_IsActorInScene(akActor) || SeverActionsNative.Native_Outfit_IsInAnimationScene(akActor) || \
        SeverActionsNativeExt.Native_Kidnap_GetPhase(akActor) > 0 || akActor.GetActorValue("Paralysis") > 0.0
        return false
    endif
    return !loot || loot.BookReader != akActor
EndFunction

Int Function _ReaderSlot(Actor akActor)
    if !_readers
        return -1
    endif
    return _readers.Find(akActor)
EndFunction

Function _StartRead(Actor akActor, SeverActions_Loot loot, Bool abSeated)
    {Plays the book idle (seated or standing) and records the read. The caller checked _CanRead and, for abSeated,
     Spell_OnReadingSeat. The slot is claimed before any call that lets another thread in (the tick and StudyTome).}
    if !loot || _ReaderSlot(akActor) >= 0
        return
    endif
    Idle reading = loot.IdleBook_Reading
    if abSeated
        reading = loot.IdleBook_ReadingSitting
    endif
    if !reading
        return
    endif
    if !_readers
        _readers = new Actor[8]
        _readUntil = new Float[8]
    endif
    Int slot = 0
    while slot < _readers.Length && _readers[slot]
        slot += 1
    endwhile
    if slot >= _readers.Length
        return
    endif
    _readers[slot] = akActor
    _readUntil[slot] = 0.0
    _readerCount += 1
    if !abSeated
        _readUntil[slot] = Utility.GetCurrentRealTime() + kStandingReadSeconds
    endif
    ; Utility.Wait does not run in a paused menu (the Inventory page's Study): no reset while one is open.
    if !abSeated && IdleForceDefaultState && !_InMenu()
        akActor.PlayIdle(IdleForceDefaultState)
        Utility.Wait(0.2)
    endif
    akActor.PlayIdle(reading)
EndFunction

Function _ClearReader(Int slot)
    _readers[slot] = None
    _readUntil[slot] = 0.0
    _readerCount -= 1
    if _readerCount < 0
        _readerCount = 0
    endif
EndFunction

Function _BeginStudyIdle(Actor akActor)
    {The read at the start of a study, so the player sees it begin.}
    SeverActions_Loot loot = (Self as Quest) as SeverActions_Loot
    if !_CanRead(akActor, loot)
        return
    endif
    Int sit = akActor.GetSitState()
    if sit >= 3 && SeverActionsNativeExt2.Spell_OnReadingSeat(akActor)
        _StartRead(akActor, loot, true)
    elseif sit == 0
        _StartRead(akActor, loot, false)
    endif   ; on the way to a seat, or in other furniture: the tick reads once they sit
EndFunction

Function _TendReaders()
    {Ends the standing reads whose time is up and forgets the seated readers who stood; then, outside a menu, starts a
     read for a studying NPC who sits, or now and then for one who stands still.}
    SeverActions_Loot loot = (Self as Quest) as SeverActions_Loot
    Float now = Utility.GetCurrentRealTime()
    Bool inMenu = _InMenu()
    Int i = 0
    while _readers && i < _readers.Length
        Actor r = _readers[i]
        if r
            if _readUntil[i] == 0.0
                if r.GetSitState() < 3 || !r.Is3DLoaded() || SeverActionsNativeExt2.Spell_StudyHoursLeft(r) < 0.0
                    _ClearReader(i)   ; a reader whose study ended reads on until they stand: no idle of ours to end
                endif
            elseif inMenu
                _readUntil[i] = now + kStandingReadSeconds   ; seen once the menu closes
            elseif now >= _readUntil[i] || !r.Is3DLoaded()
                ; Still standing where they read: hand them back to their package. Moving, the idle already ended.
                if r.Is3DLoaded() && !r.IsInCombat() && r.GetSitState() == 0 && r.GetAnimationVariableFloat("Speed") < 5.0 && \
                    loot && loot.BookReader != r
                    loot.ResetToDefaultIdle(r)
                endif
                _ClearReader(i)
            endif
        endif
        i += 1
    endwhile
    if inMenu || !loot || SeverActionsNativeExt2.Spell_StudyCount() <= 0
        return
    endif
    Actor[] near = SeverActionsNativeExt2.Spell_StudentsNearPlayer(3000.0)
    i = 0
    while near && i < near.Length
        Actor a = near[i]
        if a && _ReaderSlot(a) < 0 && SeverActionsNativeExt2.Spell_StudyHoursLeft(a) > 0.0 && _CanRead(a, loot)
            Int sit = a.GetSitState()
            if sit >= 3
                if SeverActionsNativeExt2.Spell_OnReadingSeat(a)
                    _StartRead(a, loot, true)
                endif
            elseif sit == 0 && a.GetAnimationVariableFloat("Speed") < 5.0 && Utility.RandomInt(1, 4) == 1
                _StartRead(a, loot, false)
            endif
        endif
        i += 1
    endwhile
EndFunction

Function _ProcessStudies()
    {Finish the studies whose reading is done (Spell_StudyDue credits the game time first).}
    Int guard = 0
    Actor due = SeverActionsNativeExt2.Spell_StudyDue()
    While due && guard < 4
        _FinishStudy(due)
        SeverActionsNative.Magelight_RefreshPage("inventory|" + due.GetFormID())   ; the Spells page's Learning view
        guard += 1
        due = SeverActionsNativeExt2.Spell_StudyDue()
    EndWhile
EndFunction

Function _FinishStudy(Actor learner)
    {The reading is done: the learning rule decides (no teacher). Learned = the tome is spent; a failure keeps it,
     after a mishap if they are in view.}
    Book tome = SeverActionsNativeExt2.Spell_StudyBook(learner)
    if !tome
        return   ; the study ended in between (the Spells page's Stop)
    endif
    SeverActionsNativeExt2.Spell_EndStudy(learner)
    SeverActionsNativeExt2.Spell_ForgetTomes(learner)
    String learnerName = learner.GetDisplayName()
    if learner.GetItemCount(tome) <= 0
        String goneName = tome.GetName()
        if tome.GetSpell()
            goneName = tome.GetSpell().GetName()
        endif
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("spellteach.studyTomeGone", learnerName, goneName))
        SkyrimNetApi.RegisterEvent("spell_study_failed", learnerName + " no longer has the tome they were studying.", learner, None)
        return
    endif
    Spell taught = tome.GetSpell()
    if !taught || learner.HasSpell(taught)
        return
    endif
    String spellName = taught.GetName()
    Int reach = SeverActionsNativeExt2.Spell_GetReach(learner, taught)
    ; The ending plays out (narration, a mishap) only near the player; otherwise it is only remembered.
    Bool loaded = learner.Is3DLoaded() && learner.GetDistance(Game.GetPlayer()) < 3000.0
    Int outcome = 2
    if EnableFailureSystem
        outcome = RollOutcome(_LessonFailChance(learner, None, taught))
        ; Far beyond them there is no partial success, as in a lesson.
        if reach >= 2 && outcome == 1
            outcome = 0
        endif
    endif

    if outcome == 0
        if loaded
            _ApplyFailureConsequence(None, learner, GetSpellSchool(taught), SeverActionsNativeExt2.Spell_GetMishapTier(learner, taught), 0)
        endif
        _ApplyExhaustion(learner, taught)
        String failText = learnerName + " tries the spell from the pages of " + tome.GetName() + ", and it goes wrong. The tome is still theirs to try again."
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("spellteach.studyFailed", learnerName, spellName))
        SeverActionsNativeExt2.Spell_NoteLearning(learner, None, taught, tome, 0, reach, false)
        if loaded
            SkyrimNetApi.DirectNarration(failText, learner)
        endif
        SkyrimNetApi.RegisterEvent("spell_study_failed", failText, learner, None)
        return
    endif

    ; Learned: the tome is spent, as it is for the player. A book carries no player work, so a plain copy is the
    ; tome; RemoveItem only if the native took none.
    if SeverActionsNativeExt2.RemovePlainCopies(learner, tome, 1, None) <= 0
        learner.RemoveItem(tome, 1, true)
    endif
    learner.AddSpell(taught, false)
    _ApplyExhaustion(learner, taught)
    String text = learnerName + " finished studying " + tome.GetName() + " and learned " + spellName + "; the tome is spent."
    if outcome == 1
        _ApplyExhaustion(learner, taught)
        text = learnerName + " finished studying " + tome.GetName() + " and, after a struggle, learned " + spellName + "; the tome is spent."
    endif
    if loaded
        SkyrimNetApi.DirectNarration(text, learner)
    endif
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("spellteach.studyLearned", learnerName, spellName))
    SkyrimNetApi.RegisterEvent("spell_studied", text, learner, None)
    Bool unstable = reach >= 2 && EnableFailureSystem && FailureDifficultyMult > 0.0
    SeverActionsNativeExt2.Spell_NoteLearning(learner, None, taught, tome, outcome, reach, unstable)
    if unstable
        SeverActionsNativeExt2.Spell_MarkUnstable(learner, taught)
        SkyrimNetApi.RegisterEvent("spell_learned_unstable", \
            learnerName + " learned " + spellName + " from a tome far beyond their skill: the spell is unstable in their hands and may misfire until they grow into it or practice it.", \
            learner, None)
    endif
EndFunction

; ===== Paralysis reset (see _ApplyAlterationFailure) =====

Function Maintenance()
    {Load recovery, called from SeverActions_Mod_Items stage 1. Clears every pending paralysis
     (real-time deadlines mean nothing after a load) and arms one tick for a creature left from the save.}
    _readers = new Actor[8]
    _readUntil = new Float[8]
    _readerCount = 0
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
    {Runs the lesson: fade, idles, a mid-lesson failure roll, then the spell, exhaustion and XP.
     Refused quietly while either actor is in a lesson (_ClaimLesson).}
    if !teacher || !learner || !akSpell
        return
    endif
    if !_ClaimLesson(teacher, learner)
        if learner == Game.GetPlayer()
            _RefuseInLesson(teacher)
        else
            _RefuseInLesson(learner)
        endif
        return
    endif
    _RunLesson(teacher, learner, akSpell)
    _EndLesson(teacher, learner, akSpell)
EndFunction

; ===== One lesson at a time =====
; A lesson outlasts the action's cooldown (SkyrimNet times it from the dispatch; the narration waits and the practice
; run far longer), and the NPC's reply to its narration can start the same lesson again, which then fails at its end
; with the spell already learned. Each actor holds a lane from the opening narration to the end of the lesson, and the
; learner one for the spell 15 s after it, for the reply to the lesson's own outcome.

String Function _LessonLane(Actor akActor)
    return "items.spellLesson:" + akActor.GetFormID()
EndFunction

String Function _LessonDoneLane(Actor learner, Spell akSpell)
    return "items.spellLessonDone:" + learner.GetFormID() + ":" + akSpell.GetFormID()
EndFunction

Bool Function _InLesson(Actor teacher, Actor learner)
    {True while either actor is in a lesson.}
    return SeverActionsNativeExt2.LLMLane_IsHeld(_LessonLane(teacher)) || SeverActionsNativeExt2.LLMLane_IsHeld(_LessonLane(learner))
EndFunction

Bool Function _ClaimLesson(Actor teacher, Actor learner)
    {Claim both actors' lanes from the opening narration to the end of the lesson (300 s, past its longest narration
     waits); false, holding nothing, while either is taken.}
    if !SeverActionsNativeExt2.LLMLane_TryClaim(_LessonLane(teacher), 300.0)
        return false
    endif
    if !SeverActionsNativeExt2.LLMLane_TryClaim(_LessonLane(learner), 300.0)
        SeverActionsNativeExt2.LLMLane_Release(_LessonLane(teacher))
        return false
    endif
    return true
EndFunction

Function _EndLesson(Actor teacher, Actor learner, Spell akSpell)
    {Release both actors' lanes and, when the spell was learned, hold the learner's lane for it 15 s: the reply to the
     lesson's own outcome event comes inside it. Another spell, or this one after a failure, may start at once.}
    SeverActionsNativeExt2.LLMLane_Release(_LessonLane(teacher))
    SeverActionsNativeExt2.LLMLane_Release(_LessonLane(learner))
    if learner.HasSpell(akSpell)
        SeverActionsNativeExt2.LLMLane_TryClaim(_LessonDoneLane(learner, akSpell), 15.0)
    endif
EndFunction

Function _RefuseInLesson(Actor npc)
    {A lesson with npc is under way: a HUD line for the player (an Actions-page click) and a trace, but no SkyrimNet
     event, which the reply would read as a reason to try again.}
    Debug.Trace("[SeverActions_SpellTeach] a lesson with " + npc.GetDisplayName() + " is already under way")
    Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("spellteach.lessonUnderWay", npc.GetDisplayName()))
EndFunction

Function _RunLesson(Actor teacher, Actor learner, Spell akSpell)
    {The lesson itself; the caller holds both lanes (_ClaimLesson) and ends them after.}

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
    ; How far the spell sits above the learner (SpellLearnCore): a mishap is worse the further, and a spell
    ; learned from beyond their skill is unstable.
    Int reach = SeverActionsNativeExt2.Spell_GetReach(learner, akSpell)
    Int mishapTier = SeverActionsNativeExt2.Spell_GetMishapTier(learner, akSpell)

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

    if EnableFailureSystem
        Float failChance = _LessonFailChance(learner, teacher, akSpell)
        Int outcome = RollOutcome(failChance)
        ; Far beyond them there is no partial success: a failure teaches nothing (long odds).
        if reach >= 2 && outcome == 1
            outcome = 0
        endif

        if outcome < 2
            ; Lift the fade so the player sees the consequence
            _ResetIdles(teacher, learner)
            _EndFadeToBlack()
            Utility.Wait(0.5)

            _ApplyFailureConsequence(teacher, learner, school, mishapTier, outcome)

            String narration = _GetFailureNarration(teacherName, learnerName, spellName, school, difficulty, outcome)

            if outcome == 0
                ; Full failure: nothing learned, double exhaustion
                _ApplyExhaustion(learner, akSpell)
                _ApplyExhaustion(learner, akSpell)
                SeverActionsNativeExt2.Spell_NoteLearning(learner, teacher, akSpell, None, 0, reach, false)
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
        SeverActionsNativeExt2.Spell_NoteLearning(learner, teacher, akSpell, None, 0, reach, false)
        _ApplyExhaustion(learner, akSpell)
        _ResetIdles(teacher, learner)
        _EndFadeToBlack()
        return
    endif

    ; Success, full or partial
    learner.AddSpell(akSpell, false)
    SeverActionsNativeExt2.Spell_ForgetTomes(learner)   ; a tome of it is no longer one to study
    ; Learned from far beyond their skill: it can misfire when cast until their skill catches up.
    Bool unstable = reach >= 2 && EnableFailureSystem && FailureDifficultyMult > 0.0 && learner != Game.GetPlayer()
    if unstable
        SeverActionsNativeExt2.Spell_MarkUnstable(learner, akSpell)
        SkyrimNetApi.RegisterEvent("spell_learned_unstable", \
            learnerName + " learned " + spellName + ", but it is far beyond their skill: the spell is unstable in their hands and may misfire until they grow into it or practice it.", \
            teacher, learner)
    endif
    Int learnedOutcome = 2
    if isPartialSuccess
        learnedOutcome = 1
    endif
    SeverActionsNativeExt2.Spell_NoteLearning(learner, teacher, akSpell, None, learnedOutcome, reach, unstable)
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
        _GrantSkillExperienceScaled(learner, akSpell, 0.5)
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
; Each resolves the spell by name (native SpellDB) and runs the lesson (_RunLesson) under its own claim, taken before
; the opening narration.

; The NPC akActor teaches the player; spellName is the LLM's name for the spell.
Function TeachSpell(Actor akActor, String spellName)
    ; One 10 s cooldown across teach and learn
    SkyrimNetApi.SetActionCooldown("teachspell", 10)
    SkyrimNetApi.SetActionCooldown("learnspell", 10)

    Actor player = Game.GetPlayer()
    if _InLesson(akActor, player)
        _RefuseInLesson(akActor)
        return
    endif

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
    ; check (they lack the teacher's hand-locked copy) and _RunLesson refuses at the end.
    Spell learnable = SeverActionsNative.GetLearnableSpellVariant(akSpell) as Spell
    if learnable
        akSpell = learnable
    endif

    if SeverActionsNativeExt2.Spell_IsUnteachable(akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            akSpell.GetName() + " is a power, not a spell: " + akActor.GetDisplayName() + " cannot teach it.", \
            akActor, player)
        return
    endif

    ; Just taught it: the reply to the lesson's outcome, quietly (_EndLesson).
    if SeverActionsNativeExt2.LLMLane_IsHeld(_LessonDoneLane(player, akSpell))
        Debug.Trace("[SeverActions_SpellTeach] TeachSpell: " + akSpell.GetName() + " was just taught - not again")
        return
    endif
    if player.HasSpell(akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            player.GetDisplayName() + " already knows " + akSpell.GetName() + ".", \
            akActor, player)
        return
    endif

    if RequireSkillCheck && !_MeetsSkillRequirement(player, akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            akSpell.GetName() + " is beyond " + player.GetDisplayName() + "'s skill, and the lesson is not attempted.", \
            akActor, player)
        return
    endif

    String school = GetSpellSchool(akSpell)
    String diffName = _DifficultyName(GetSpellDifficulty(akSpell))
    String narration = akActor.GetDisplayName() + " begins teaching " + player.GetDisplayName() + \
        " the " + diffName + "-level " + school + " spell " + akSpell.GetName() + "."
    narration += _BeyondWarning(player, akSpell)
    ; Claimed before the narration: the NPC's reply to it can start a second lesson.
    if !_ClaimLesson(akActor, player)
        _RefuseInLesson(akActor)
        return
    endif
    SkyrimNetApi.DirectNarration(narration, akActor, player)

    _WaitForNarrationComplete()

    _RunLesson(akActor, player, akSpell)
    _EndLesson(akActor, player, akSpell)
EndFunction

; The NPC akActor learns a spell from the player.
Function LearnSpell(Actor akActor, String spellName)
    ; One 10 s cooldown across teach and learn
    SkyrimNetApi.SetActionCooldown("teachspell", 10)
    SkyrimNetApi.SetActionCooldown("learnspell", 10)

    Actor player = Game.GetPlayer()
    if _InLesson(player, akActor)   ; see TeachSpell
        _RefuseInLesson(akActor)
        return
    endif

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

    if SeverActionsNativeExt2.Spell_IsUnteachable(akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            akSpell.GetName() + " is a power, not a spell: " + player.GetDisplayName() + " cannot teach it.", \
            player, akActor)
        return
    endif

    if SeverActionsNativeExt2.LLMLane_IsHeld(_LessonDoneLane(akActor, akSpell))   ; see TeachSpell
        Debug.Trace("[SeverActions_SpellTeach] LearnSpell: " + akSpell.GetName() + " was just taught - not again")
        return
    endif
    if akActor.HasSpell(akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            akActor.GetDisplayName() + " already knows " + akSpell.GetName() + ".", \
            player, akActor)
        return
    endif

    if RequireSkillCheck && !_MeetsSkillRequirement(akActor, akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            akSpell.GetName() + " is beyond " + akActor.GetDisplayName() + "'s skill, and the lesson is not attempted.", \
            player, akActor)
        return
    endif

    String school = GetSpellSchool(akSpell)
    String diffName = _DifficultyName(GetSpellDifficulty(akSpell))
    String narration = player.GetDisplayName() + " begins teaching " + akActor.GetDisplayName() + \
        " the " + diffName + "-level " + school + " spell " + akSpell.GetName() + "."
    narration += _BeyondWarning(akActor, akSpell)
    if !_ClaimLesson(player, akActor)   ; see TeachSpell
        _RefuseInLesson(akActor)
        return
    endif
    SkyrimNetApi.DirectNarration(narration, akActor, player)

    _WaitForNarrationComplete()

    _RunLesson(player, akActor, akSpell)
    _EndLesson(player, akActor, akSpell)
EndFunction

String Function _BeyondWarning(Actor learner, Spell akSpell)
    {" ..." when the spell is far beyond the learner (SpellLearnCore): they know it, and try anyway.}
    if SeverActionsNativeExt2.Spell_GetReach(learner, akSpell) >= 2
        return " It is far beyond " + learner.GetDisplayName() + "'s skill, and they know it; they try anyway."
    endif
    return ""
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
