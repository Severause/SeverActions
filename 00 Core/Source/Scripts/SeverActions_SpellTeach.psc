Scriptname SeverActions_SpellTeach extends Quest
{Handles teaching and learning spells between actors - by Severause
 Improved version with unified transfer function and ISL-inspired mechanics}

; =============================================================================
; PROPERTIES
; =============================================================================

Idle Property IdleTeaching Auto
Idle Property IdleLearning Auto
Idle Property IdleForceDefaultState Auto

; Fade to black effect
ImageSpaceModifier Property FadeToBlackImod Auto
{ISFadeToBlackImod - fades screen to black}

ImageSpaceModifier Property FadeToBlackHoldImod Auto
{ISFadeToBlackHoldImod - holds the black screen}

ImageSpaceModifier Property FadeToBlackBackImod Auto
{ISFadeToBlackBackImod - fades screen back from black}

; Optional: Configurable settings (could be tied to MCM or globals)
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

; Failure System Settings
Bool Property EnableFailureSystem = True Auto Hidden
{If true, spell learning can fail with school-specific consequences}

Float Property FailureDifficultyMult = 1.0 Auto Hidden
{Multiplier for failure chance (0.5 = easier, 2.0 = harder). MCM adjustable.}

ObjectReference Property PendingCleanupCreature = None Auto Hidden
{Internal: creature spawned by failed Conjuration, auto-cleaned after 30s}

; Visual FX
EffectShader Property SpellLearnedFXS Auto
{Optional: EffectShader played on learner when a spell is successfully learned.
 Fill in CK with any EFSH — e.g. search for EnchantHeal, AbsorbHealth, Reanimate, Ward.}

; =============================================================================
; SPELL SCHOOL DETECTION (for XP and difficulty)
; =============================================================================

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
    
    ; Rough mapping based on spell tome costs
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

; =============================================================================
; FAILURE SYSTEM - Chance Calculation & Outcome Roll
; =============================================================================

Float Function CalculateFailureChance(Actor learner, Spell akSpell)
    {Calculate probability of failure (0.0 to 0.95) based on skill gap and difficulty}
    Int difficulty = GetSpellDifficulty(akSpell)

    ; Novice spells always succeed
    if difficulty == 0
        return 0.0
    endif

    ; Base rate: difficulty * 5% (keeps tension even when meeting the requirement)
    Float failChance = difficulty * 0.05

    ; Gap rate: +1% per skill point below requirement
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

    ; Apply MCM multiplier
    failChance = failChance * FailureDifficultyMult

    ; Cap at 95% - never impossible
    if failChance > 0.95
        failChance = 0.95
    endif

    return failChance
EndFunction

Int Function RollOutcome(Float failChance)
    {Roll for outcome: 0=Full Failure, 1=Partial Success, 2=Full Success}
    if failChance <= 0.0
        return 2  ; Full success
    endif

    Float roll = Utility.RandomFloat(0.0, 1.0)

    if roll <= failChance * 0.5
        return 0  ; Full failure - worst outcome
    elseif roll <= failChance
        return 1  ; Partial success - learn but suffer consequence
    else
        return 2  ; Full success
    endif
EndFunction

; =============================================================================
; INTERNAL HELPERS
; =============================================================================

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
        return True  ; Unknown school, allow learning
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
    Float maxMagicka = learner.GetActorValue("Magicka")
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

; =============================================================================
; FADE TO BLACK FUNCTIONS
; =============================================================================

Function _StartFadeToBlack()
    {Begin the fade to black effect}
    if !UseFadeToBlack
        return
    endif
    
    if FadeToBlackImod
        FadeToBlackImod.Apply()
    endif
EndFunction

Function _HoldFadeToBlack()
    {Hold at full black}
    if !UseFadeToBlack
        return
    endif
    
    if FadeToBlackImod
        FadeToBlackImod.Remove()
    endif
    if FadeToBlackHoldImod
        FadeToBlackHoldImod.Apply()
    endif
EndFunction

Function _EndFadeToBlack()
    {Fade back from black}
    if !UseFadeToBlack
        return
    endif
    
    if FadeToBlackHoldImod
        FadeToBlackHoldImod.Remove()
    endif
    if FadeToBlackBackImod
        FadeToBlackBackImod.Apply()
    endif
EndFunction

; =============================================================================
; FAILURE CONSEQUENCES - School-specific effects when spells go wrong
; =============================================================================

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

    ; Pick a destruction spell to cast for the explosion visual
    ; Firebolt = small impact, Fireball = big AoE explosion
    Spell explosionSpell = None
    if difficulty <= 2
        explosionSpell = Game.GetFormFromFile(0x00012FCD, "Skyrim.esm") as Spell  ; Firebolt
    else
        explosionSpell = Game.GetFormFromFile(0x0001C789, "Skyrim.esm") as Spell  ; Fireball
    endif

    ; Ghost teacher to protect from splash damage
    ; Learner is NOT ghosted — the spell must impact them to create the explosion VFX
    Bool teacherWasGhost = teacher.IsGhost()
    if !teacherWasGhost
        teacher.SetGhost(true)
    endif

    ; Place invisible marker above learner as spell origin
    ; This avoids any casting animation on actors — the spell just appears
    ObjectReference marker = None
    Form xMarker = Game.GetFormFromFile(0x0000003B, "Skyrim.esm")  ; XMarker
    if xMarker
        marker = learner.PlaceAtMe(xMarker)
        if marker
            marker.MoveTo(learner, 0.0, 0.0, 200.0)  ; 200 units above
        endif
    endif

    ; Cast spell from marker toward learner — projectile impacts and creates explosion
    if explosionSpell && marker
        explosionSpell.Cast(marker, learner)
    endif

    ; Camera shake scales with difficulty
    Game.ShakeCamera(None, 1.0 + (difficulty as Float))

    ; Stagger the learner
    Debug.SendAnimationEvent(learner, "staggerStart")

    ; Wait for spell projectile to travel and impact
    Utility.Wait(1.0)

    ; Restore teacher ghost state
    if !teacherWasGhost
        teacher.SetGhost(false)
    endif

    ; Clean up marker
    if marker
        marker.Disable()
        marker.Delete()
    endif

    ; Apply controlled HP damage to learner (on top of any spell damage)
    Float maxHP = learner.GetBaseActorValue("Health")
    Float damagePercent = 0.10 + (difficulty * 0.05)  ; 10% to 30%
    if outcome == 0  ; Full failure = more damage
        damagePercent = damagePercent * 1.5
    endif
    Float damage = maxHP * damagePercent

    ; Safety cap: never reduce below 10% HP (covers both spell + our damage)
    Float currentHP = learner.GetActorValue("Health")
    Float minHP = maxHP * 0.10
    if (currentHP - damage) < minHP
        damage = currentHP - minHP
    endif
    if damage > 0.0
        learner.DamageActorValue("Health", damage)
    endif

    ; Final safety: if spell damage alone pushed below 10%, heal back up
    currentHP = learner.GetActorValue("Health")
    if currentHP < minHP
        learner.RestoreActorValue("Health", minHP - currentHP)
    endif
EndFunction

Function _ApplyConjurationFailure(Actor learner, Int difficulty, Int outcome)
    {A hostile creature tears through the failed conjuration with purple vortex VFX}
    ; Clean up any existing creature first
    _CleanupSpawnedCreature()

    ; Determine creature type based on difficulty
    ; Using vanilla Skyrim.esm ActorBase (Enc*) forms
    Form creatureForm = None
    if difficulty <= 1
        creatureForm = Game.GetFormFromFile(0x000829B4, "Skyrim.esm")  ; EncSkeever
    elseif difficulty == 2
        creatureForm = Game.GetFormFromFile(0x0002D770, "Skyrim.esm")  ; EncSkeleton
    elseif difficulty == 3
        creatureForm = Game.GetFormFromFile(0x00023AAB, "Skyrim.esm")  ; EncAtronachFrost
    else
        creatureForm = Game.GetFormFromFile(0x0010DDDC, "Skyrim.esm")  ; DremoraMerchant (hostile)
    endif

    if !creatureForm
        ; Fallback: just stagger + magicka drain if forms not found
        Debug.SendAnimationEvent(learner, "staggerStart")
        learner.DamageActorValue("Magicka", learner.GetActorValue("Magicka") * 0.3)
        return
    endif

    ActorBase creatureBase = creatureForm as ActorBase
    if !creatureBase
        Debug.SendAnimationEvent(learner, "staggerStart")
        return
    endif

    ; === Conjuration Portal VFX ===
    ; Place vanilla SummonTargetFXActivator at learner's position — this is the purple
    ; swirling vortex from vanilla conjuration spells. It auto-disables/deletes itself.
    ; Same pattern used by MGRitual03EffectScript and dunMiddenHandSculptureSCRIPT.
    Form portalForm = Game.GetFormFromFile(0x0007CD55, "Skyrim.esm")  ; SummonTargetFXActivator
    if portalForm
        learner.PlaceAtMe(portalForm)
    endif

    ; Wait for portal animation to appear before spawning creature (vanilla uses 0.33s)
    Utility.Wait(0.5)

    ; Spawn creature at learner's location — emerges from the portal
    Actor creature = learner.PlaceActorAtMe(creatureBase)
    if creature
        if outcome == 0
            ; Full failure: hostile creature, player must deal with it
            creature.StartCombat(learner)
            PendingCleanupCreature = creature as ObjectReference
            RegisterForSingleUpdate(30.0)
        else
            ; Partial success: non-hostile, brief apparition before lesson resumes
            PendingCleanupCreature = creature as ObjectReference
            RegisterForSingleUpdate(10.0)
        endif
    endif

    ; Camera shake
    Game.ShakeCamera(None, 1.5)
EndFunction

Function _ApplyRestorationFailure(Actor learner, Int difficulty, Int outcome)
    {Healing energy inverts - drains HP and Stamina}
    Debug.SendAnimationEvent(learner, "staggerStart")

    ; HP drain (inverted healing) - scales with difficulty
    Float maxHP = learner.GetBaseActorValue("Health")
    Float hpDrain = maxHP * (0.08 + (difficulty * 0.04))  ; 8% to 24%
    if outcome == 0  ; Full failure = more drain
        hpDrain = hpDrain * 1.5
    endif

    ; Safety cap: never reduce below 10% HP
    Float currentHP = learner.GetActorValue("Health")
    if (currentHP - hpDrain) < (maxHP * 0.10)
        hpDrain = currentHP - (maxHP * 0.10)
    endif
    if hpDrain > 0.0
        learner.DamageActorValue("Health", hpDrain)
    endif

    ; Stamina drain
    Float maxStamina = learner.GetBaseActorValue("Stamina")
    Float staminaDrain = maxStamina * (0.15 + (difficulty * 0.10))  ; 15% to 55%
    learner.DamageActorValue("Stamina", staminaDrain)
EndFunction

Function _ApplyIllusionFailure(Actor learner, Int difficulty, Int outcome)
    {Mental backlash - stagger + stamina drain for player, fear/frenzy for NPCs}
    Actor player = Game.GetPlayer()

    if learner == player
        ; Player safety: just stagger + stamina drain (no fear/frenzy on player)
        Debug.SendAnimationEvent(learner, "staggerStart")
        Float maxStamina = learner.GetBaseActorValue("Stamina")
        Float drain = maxStamina * (0.20 + (difficulty * 0.15))  ; 20% to 80%
        learner.DamageActorValue("Stamina", drain)
        ; Also drain some magicka from the mental strain
        learner.DamageActorValue("Magicka", learner.GetActorValue("Magicka") * 0.2)
    else
        ; NPC learner: apply actual fear (low tier) or frenzy (high tier)
        if difficulty <= 2
            Spell fearSpell = Game.GetFormFromFile(0x0004DEED, "Skyrim.esm") as Spell
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
        ; Low tier: stagger + stamina drain
        Debug.SendAnimationEvent(learner, "staggerStart")
        Game.ShakeCamera(None, 1.0)
        Actor player = Game.GetPlayer()
        if learner != player
            ; Push NPC away
            player.PushActorAway(learner, 2.0)
        else
            ; Player just gets stamina drain
            learner.DamageActorValue("Stamina", learner.GetActorValue("Stamina") * 0.3)
        endif
    else
        ; High tier: brief paralysis (3-5 seconds)
        Float paralyzeTime = 3.0
        if difficulty >= 4
            paralyzeTime = 5.0
        endif
        learner.SetActorValue("Paralysis", 1.0)
        Utility.Wait(paralyzeTime)
        learner.SetActorValue("Paralysis", 0.0)
    endif
EndFunction

; =============================================================================
; FAILURE NARRATION - Generate descriptive text for SkyrimNet events
; =============================================================================

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

; =============================================================================
; CREATURE CLEANUP - Auto-despawn conjuration failure creatures
; =============================================================================

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

Event OnUpdate()
    _CleanupSpawnedCreature()
EndEvent

; =============================================================================
; NARRATION SYNC - Wait for DirectNarration audio to finish before continuing
; =============================================================================

Function _WaitForNarrationComplete()
    {Wait for DirectNarration TTS audio to finish playing.
     Two-phase: first wait for audio to enter the queue, then wait for it to drain.
     This prevents failures/consequences from firing while the teacher is still talking.}

    ; Phase 1: Wait for TTS to process and audio to enter the queue
    ; Typical TTS takes 1-5 seconds. Timeout at 10 seconds.
    int waitForQueue = 0
    while SkyrimNetApi.GetSpeechQueueSize() == 0 && waitForQueue < 20
        Utility.Wait(0.5)
        waitForQueue += 1
    endwhile

    ; Phase 2: Wait for audio to finish playing
    ; Typical narration is 5-15 seconds. Timeout at 60 seconds.
    int waitForDrain = 0
    while SkyrimNetApi.GetSpeechQueueSize() > 0 && waitForDrain < 120
        Utility.Wait(0.5)
        waitForDrain += 1
    endwhile
EndFunction

; =============================================================================
; UNIFIED SPELL TRANSFER FUNCTION
; This consolidates TeachSpell and LearnSpell into a single function
; =============================================================================

Bool Function TransferSpell_IsEligible(Actor teacher, Actor learner, Spell akSpell)
    {Unified eligibility check for spell transfer}
    if !teacher || !learner || !akSpell
        return false
    endif
    
    ; Basic checks
    if !teacher.HasSpell(akSpell)
        return false  ; Teacher must know the spell
    endif
    
    if !_CanLearn(learner, akSpell)
        return false  ; Learner already knows it or invalid
    endif
    
    if teacher.IsInCombat() || learner.IsInCombat()
        return false  ; Neither can be in combat
    endif
    
    ; Optional skill requirement check
    if RequireSkillCheck && !_MeetsSkillRequirement(learner, akSpell)
        return false
    endif
    
    return true
EndFunction

Function TransferSpell_Execute(Actor teacher, Actor learner, Spell akSpell)
    {Unified spell transfer execution with failure system}
    if !teacher || !learner || !akSpell
        return
    endif

    String spellName = akSpell.GetName()
    String teacherName = teacher.GetDisplayName()
    String learnerName = learner.GetDisplayName()
    String school = GetSpellSchool(akSpell)
    Int difficulty = GetSpellDifficulty(akSpell)
    Bool isPartialSuccess = false

    ; Start fade to black
    _StartFadeToBlack()

    ; Brief pause for fade to take effect
    Utility.Wait(1.0)

    ; Hold at black and start animations
    _HoldFadeToBlack()

    if IdleTeaching
        teacher.PlayIdle(IdleTeaching)
    endif
    if IdleLearning
        learner.PlayIdle(IdleLearning)
    endif

    ; Calculate learning duration based on difficulty
    Float duration = GetLearningDuration(difficulty)

    ; === Wait first half of practice ===
    Utility.Wait(duration * 0.5)

    ; === MID-PRACTICE FAILURE CHECK ===
    if EnableFailureSystem && difficulty > 0
        Float failChance = CalculateFailureChance(learner, akSpell)
        Int outcome = RollOutcome(failChance)

        if outcome < 2  ; Not full success — something went wrong
            ; End fade so player sees the consequence
            _ResetIdles(teacher, learner)
            _EndFadeToBlack()
            Utility.Wait(0.5)

            ; Apply school-specific consequence
            _ApplyFailureConsequence(teacher, learner, school, difficulty, outcome)

            ; Generate narration
            String narration = _GetFailureNarration(teacherName, learnerName, spellName, school, difficulty, outcome)

            if outcome == 0
                ; FULL FAILURE: no spell learned, double exhaustion
                _ApplyExhaustion(learner, akSpell)
                _ApplyExhaustion(learner, akSpell)
                SkyrimNetApi.RegisterEvent("spell_transfer_failed", narration, teacher, learner)
                SkyrimNetApi.DirectNarration(narration, teacher, learner)
                _WaitForNarrationComplete()
                return
            else
                ; PARTIAL SUCCESS: suffer consequence but continue learning
                isPartialSuccess = true
                SkyrimNetApi.DirectNarration(narration, teacher, learner)

                ; Wait for the failure narration to finish before resuming lesson
                _WaitForNarrationComplete()

                ; Re-fade and resume the lesson
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

    ; === Wait second half of practice ===
    Utility.Wait(duration * 0.5)

    ; Re-verify eligibility after wait
    if !_CanLearn(learner, akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            teacherName + " attempted to teach " + spellName + " but " + learnerName + " already possesses this knowledge.", \
            teacher, learner)
        _ResetIdles(teacher, learner)
        _EndFadeToBlack()
        return
    endif

    ; Check skill requirement (can fail even after animation if enabled)
    if RequireSkillCheck && !_MeetsSkillRequirement(learner, akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            learnerName + " struggled to comprehend the " + school + " magic. The " + spellName + " spell proves too advanced for their current skill level.", \
            teacher, learner)
        _ApplyExhaustion(learner, akSpell)
        _ResetIdles(teacher, learner)
        _EndFadeToBlack()
        return
    endif

    ; Success (full or partial)! Transfer the spell
    learner.AddSpell(akSpell, false)

    ; Apply exhaustion (normal amount for both full and partial)
    _ApplyExhaustion(learner, akSpell)

    ; Grant XP: full for clean success, half for partial
    if !isPartialSuccess
        _GrantSkillExperience(learner, akSpell)
    else
        ; Partial success: grant half XP
        if GrantSkillXP
            String avName = GetActorValueForSchool(school)
            if avName != ""
                Float halfXP = (SkillXPAmount * (1.0 + (difficulty * 0.5))) * 0.5
                Game.AdvanceSkill(avName, halfXP)
            endif
        endif
    endif

    ; Reset animations before fading back
    _ResetIdles(teacher, learner)

    ; Fade back from black
    _EndFadeToBlack()

    ; Play visual effect on learner to mark successful spell acquisition
    if SpellLearnedFXS
        SpellLearnedFXS.Play(learner, 3.0)
    endif

    ; Generate appropriate event message based on difficulty
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
        ; Partial success: narration was already sent, just register the event
        SkyrimNetApi.RegisterEvent("spell_learned_partial", \
            learnerName + " learned the " + difficultyDesc + " " + school + " spell " + spellName + " from " + teacherName + ", though the practice was rough and had consequences.", \
            teacher, learner)
    else
        SkyrimNetApi.RegisterEvent("spell_learned", \
            teacherName + " guided " + learnerName + " through the " + difficultyDesc + " " + school + " spell, " + spellName + ". The knowledge takes root in " + learnerName + "'s mind.", \
            teacher, learner)
    endif
EndFunction

; =============================================================================
; WRAPPER FUNCTIONS FOR BACKWARDS COMPATIBILITY
; These call the unified function but maintain the original API
; =============================================================================

; ACTION: TeachSpell (Actor = Teacher, student = Learner)
Bool Function TeachSpell_IsEligible(Actor akActor, Actor student, Spell akSpell)
    return TransferSpell_IsEligible(akActor, student, akSpell)
EndFunction

Function TeachSpell_Execute(Actor akActor, Actor student, Spell akSpell)
    TransferSpell_Execute(akActor, student, akSpell)
EndFunction

; ACTION: LearnSpell (Actor = Learner, teacher = Teacher)
Bool Function LearnSpell_IsEligible(Actor akActor, Actor teacher, Spell akSpell)
    return TransferSpell_IsEligible(teacher, akActor, akSpell)
EndFunction

Function LearnSpell_Execute(Actor akActor, Actor teacher, Spell akSpell)
    TransferSpell_Execute(teacher, akActor, akSpell)
EndFunction

; =============================================================================
; SKYRIMNET ACTION ENTRY POINTS
; These are called by SkyrimNet action YAMLs via executionFunctionName.
; They resolve spell names to forms using the native SpellDB, then delegate
; to TransferSpell_Execute for the actual teaching sequence.
; =============================================================================

; ACTION: TeachSpell — NPC teaches a spell to the player
; Called by teachspell.yaml: akActor = the NPC teacher, spellName = LLM-provided name
Function TeachSpell(Actor akActor, String spellName)
    ; Prevent action spam — 10 second cooldown on both teach/learn
    SkyrimNetApi.SetActionCooldown("teachspell", 10)
    SkyrimNetApi.SetActionCooldown("learnspell", 10)

    Actor player = Game.GetPlayer()

    ; Resolve spell name to form via native fuzzy search on the NPC's known spells
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

    ; Check if player already knows it
    if player.HasSpell(akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            player.GetDisplayName() + " already knows " + akSpell.GetName() + ".", \
            akActor, player)
        return
    endif

    ; Narrate the start of the lesson with school info
    String school = GetSpellSchool(akSpell)
    String diffName = _DifficultyName(GetSpellDifficulty(akSpell))
    String narration = akActor.GetDisplayName() + " begins teaching " + player.GetDisplayName() + \
        " the " + diffName + "-level " + school + " spell " + akSpell.GetName() + "."
    SkyrimNetApi.RegisterEvent("spell_teaching_started", narration, akActor, player)
    SkyrimNetApi.DirectNarration(narration, akActor, player)

    ; Wait for the teaching narration to finish before starting practice
    _WaitForNarrationComplete()

    TransferSpell_Execute(akActor, player, akSpell)
EndFunction

; ACTION: LearnSpell — NPC learns a spell from the player
; Called by learnspell.yaml: akActor = the NPC learner, spellName = LLM-provided name
Function LearnSpell(Actor akActor, String spellName)
    ; Prevent action spam — 10 second cooldown on both teach/learn
    SkyrimNetApi.SetActionCooldown("teachspell", 10)
    SkyrimNetApi.SetActionCooldown("learnspell", 10)

    Actor player = Game.GetPlayer()

    ; Resolve spell name to form via native fuzzy search on the player's known spells
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

    ; Check if NPC already knows it
    if akActor.HasSpell(akSpell)
        SkyrimNetApi.RegisterEvent("spell_transfer_failed", \
            akActor.GetDisplayName() + " already knows " + akSpell.GetName() + ".", \
            player, akActor)
        return
    endif

    ; Narrate the start of the lesson with school info
    String school = GetSpellSchool(akSpell)
    String diffName = _DifficultyName(GetSpellDifficulty(akSpell))
    String narration = player.GetDisplayName() + " begins teaching " + akActor.GetDisplayName() + \
        " the " + diffName + "-level " + school + " spell " + akSpell.GetName() + "."
    SkyrimNetApi.RegisterEvent("spell_learning_started", narration, player, akActor)
    SkyrimNetApi.DirectNarration(narration, akActor, player)

    ; Wait for the teaching narration to finish before starting practice
    _WaitForNarrationComplete()

    TransferSpell_Execute(player, akActor, akSpell)
EndFunction

; Helper: Convert difficulty tier to readable name
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
