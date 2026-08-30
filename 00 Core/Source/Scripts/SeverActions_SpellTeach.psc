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
{Internal: creature spawned by failed Conjuration, auto-cleaned after 10s (partial success) / 30s (full failure)}

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
    ; MAX magicka is what we want here -- GetActorValue returns CURRENT (already-drained) magicka; GetBaseActorValue is the vanilla-safe maximum.
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

; =============================================================================
; FADE TO BLACK FUNCTIONS
; =============================================================================

; Fade-to-black via Game.FadeOutGame with a long-duration animation.
; The three-IMOD pattern works under stock Skyrim but Community Shaders'
; replacement post-process drops the IMOD stage (Apply calls fire but never
; reach the final tonemap). FadeOutGame routes through Bethesda's high-level
; fade machinery (sleep / wait / hit-the-bed path), which CS lets through,
; but it doesn't hold black — the screen releases when the animation
; duration elapses.
;
; The trick: make the fade-out duration LONG enough to span the whole
; spell-teach sequence. While the animation is in-flight the screen is held
; in its interpolated state — never completes, never releases; _EndFadeToBlack
; interrupts with the reverse animation to bring it back. The screen
; progressively darkens over LongFadeOutSeconds rather than snapping at 1s,
; reading as "the scene dims while the teacher concentrates".
;
; Do not reach for the alternatives: a snap-and-hold doesn't hold, and an
; OnUpdate refresh loop re-animates every refresh (flicker). FadeOutGame
; locks player controls during the transition, which is correct here — the
; player shouldn't be wandering mid-lesson.
;
; The IMOD properties stay declared and bindable in CK for a future revert;
; they're not referenced by the current bodies.

; Long enough to cover the full lesson at default difficulty (~5-15s).
; If the lesson runs longer than this, the animation will complete and
; the screen will release mid-lesson — tunable property so we can
; lengthen for hard-difficulty spells.
Float Property LongFadeOutSeconds = 30.0 Auto Hidden
Float Property FadeBackSeconds    = 1.5  Auto Hidden

Function _StartFadeToBlack()
    {Begin the fade to black effect}
    if !UseFadeToBlack
        return
    endif
    ; bFadingOut=true → fade TO black; bBlackFade=true → black (vs white)
    ; Long animation duration acts as the hold mechanism — the screen
    ; stays in its in-flight interpolated state until we interrupt
    ; with _EndFadeToBlack.
    Game.FadeOutGame(true, true, 0.0, LongFadeOutSeconds)
EndFunction

Function _HoldFadeToBlack()
    {No-op — the long fade-out duration handles the hold. Kept as a
     function so the call sites don't need to change shape.}
    ; intentionally empty
EndFunction

Function _EndFadeToBlack()
    {Interrupt the in-flight fade-out and reverse direction to clear}
    if !UseFadeToBlack
        return
    endif
    Game.FadeOutGame(false, true, 0.0, FadeBackSeconds)
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
            ChronoArm(30.0)
        else
            ; Partial success: non-hostile, brief apparition before lesson resumes
            PendingCleanupCreature = creature as ObjectReference
            ChronoArm(10.0)
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
        ; Crash safety: persist the pending reset BEFORE paralyzing. A bare
        ; SetActorValue + blocking Wait + reset bakes Paralysis=1 into the
        ; actor (possibly the PLAYER) forever if the game crashes, quits, or
        ; a save is loaded from inside the window -- a suspended Utility.Wait
        ; stack is not guaranteed to survive, but a registered single update
        ; is, and Maintenance() force-clears leftovers on load.
        StorageUtil.FormListAdd(Self, "SeverSpellTeach_PendingParalyze", learner, false)
        StorageUtil.SetFloatValue(learner, "SeverSpellTeach_ParalyzeUntil", Utility.GetCurrentRealTime() + paralyzeTime)
        learner.SetActorValue("Paralysis", 1.0)
        ChronoArm(paralyzeTime + 0.5)
        Utility.Wait(paralyzeTime)
        ; Normal path: reset + unpersist. The OnUpdate sweep then no-ops.
        _ClearPendingParalysis(learner)
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

Function ChronoArm(Float afSeconds)
    {Arm this script's one-shot chronometer tick - replaces the FORM-keyed
     RegisterForSingleUpdate (canonical explanation: the Chronometer block in
     SeverActionsNativeExt2.psc + the CLAUDE.md lesson). Event name AND
     callback name are unique per script - both, always. Re-arm replaces the
     pending tick; ticks do NOT survive save/load (load paths re-arm); at
     most one already-in-flight wake can land after Cancel/Clear, so keep
     the handler state-guarded.}
    RegisterForModEvent("SeverActions_Tick_SpellTeach", "OnChronoTick_SpellTeach")
    SeverActionsNativeExt2.Chrono_Request("SeverActions_Tick_SpellTeach", afSeconds)
EndFunction

Event OnChronoTick_SpellTeach(String eventName, String strArg, Float numArg, Form sender)
    ; Shared single-update channel: the conjuration-creature despawn AND the
    ; paralysis-reset safety net both arm this event. Both passes are
    ; idempotent, so whichever deadline fires first can safely run both.
    _CleanupSpawnedCreature()
    _SweepPendingParalysis(false)
EndEvent

; =============================================================================
; PARALYSIS RESET SAFETY NET - crash-safe recovery for _ApplyAlterationFailure
; =============================================================================

Function Maintenance()
    {Load-time recovery. Force-clears any paralysis reset left pending by a
     crash/quit/save made inside the failure-paralysis window. Real-time
     deadlines from a previous session are meaningless after a load, so
     sweep everything rather than leave an actor stuck at Paralysis=1.
     Called by SeverActions_Init's load path (InitializeSpellTeachSystem).}
    ; Chronometer: one idempotent wake on load - runs the creature-despawn
    ; and paralysis sweeps once in case their deadline tick was pending at
    ; the save (chronometer ticks do not survive save/load).
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
            ; Entry went stale (actor unloaded/deleted) - drop it.
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
        ; A window is still open (this update fired early, e.g. armed by the
        ; creature-cleanup path) - keep the safety net armed for it.
        ChronoArm(nextWait + 0.1)
    endif
EndFunction

Function _ClearPendingParalysis(Actor akActor)
    {Reset the failure paralysis and unpersist its pending marker. Safe to
     call more than once for the same actor.}
    if !akActor
        return
    endif
    akActor.SetActorValue("Paralysis", 0.0)
    StorageUtil.UnsetFloatValue(akActor, "SeverSpellTeach_ParalyzeUntil")
    StorageUtil.FormListRemove(Self, "SeverSpellTeach_PendingParalyze", akActor, true)
EndFunction

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

    ; --- One-handed-spell fix -------------------------------------------------
    ; The spell was resolved by NAME against the TEACHER's known spells, and
    ; magic overhauls distribute NPCs hand-locked copies: MAG_FireboltRightHand
    ; carries the RightHand equip slot while the tome's MAG_Firebolt carries
    ; EitherHand - and BOTH display as Firebolt. Handing the teacher's copy
    ; straight to the player gave them a spell they could only ever hold in one
    ; hand (no off-hand, no dual-cast). Swap to the tome-taught version.
    ;
    ; PLAYER ONLY on purpose. For an NPC learner the teacher's exact variant is
    ; the right thing to copy: overhauls pair a hand-locked spell with the perk
    ; that lets that NPC cast it, and substituting a different variant pulls in
    ; a perk requirement they do not have. NPC casting already routes through
    ; GetUnrestrictedVariantForCast, which grants the perk alongside.
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
                Debug.Notification("[SeverActions] Spell failed: " + spellName)
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
    if isPartialSuccess
        Debug.Notification("[SeverActions] Spell learned (partial): " + spellName)
    else
        Debug.Notification("[SeverActions] Spell learned: " + spellName)
    endif

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

    ; Resolve to the tome-taught, either-hand version BEFORE the already-knows
    ; check - otherwise a player who owns the real Firebolt still passed this
    ; gate (they lack the teacher's RightHand copy) and sat through a whole
    ; lesson that TransferSpell_Execute then refused.
    Spell learnable = SeverActionsNative.GetLearnableSpellVariant(akSpell) as Spell
    if learnable
        akSpell = learnable
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

; =============================================================================
; SHOUT TEACHING (dev142) - the way of the Voice, freely given
; -----------------------------------------------------------------------------
; The Greybeards (or any NPC whose EFFECTIVE record carries Shouts - own
; record, or the template chain's when the NPC is templated for Spells;
; SpellDB::EffectiveShoutSource resolves it and the can_teach_shouts
; decorator gates the action on exactly that, issue #411) teach the
; player ONE Word of Power per lesson: the next word of the named Shout the
; player does not yet know. A master's gift includes the understanding -
; TeachWord AND UnlockWord, no dragon soul spent - mirroring MQ105, where
; the Greybeards share their knowledge of Whirlwind Sprint outright. Word
; state is player-global (the same flags word walls set), so wall-learned
; and master-taught words compose; three lessons complete a Shout.
; =============================================================================

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

    ; The gift: the word AND its understanding. TeachWord is what a wall
    ; does; UnlockWord is what a dragon soul does - a master grants both.
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
