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
    {Unified spell transfer execution}
    if !teacher || !learner || !akSpell
        return
    endif
    
    String spellName = akSpell.GetName()
    String teacherName = teacher.GetDisplayName()
    String learnerName = learner.GetDisplayName()
    String school = GetSpellSchool(akSpell)
    Int difficulty = GetSpellDifficulty(akSpell)
    
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
    Utility.Wait(duration)
    
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
        _ApplyExhaustion(learner, akSpell)  ; Still drain magicka for the attempt
        _ResetIdles(teacher, learner)
        _EndFadeToBlack()
        return
    endif
    
    ; Success! Transfer the spell
    learner.AddSpell(akSpell, false)
    
    ; Apply effects
    _ApplyExhaustion(learner, akSpell)
    _GrantSkillExperience(learner, akSpell)
    
    ; Reset animations before fading back
    _ResetIdles(teacher, learner)
    
    ; Fade back from black
    _EndFadeToBlack()
    
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
    
    SkyrimNetApi.RegisterEvent("spell_learned", \
        teacherName + " guided " + learnerName + " through the " + difficultyDesc + " " + school + " spell, " + spellName + ". The knowledge takes root in " + learnerName + "'s mind.", \
        teacher, learner)
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
