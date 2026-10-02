Scriptname SeverActions_LeashLib Hidden
{Leash Framework support library (M-L), called statically by kidnap and arrest: the only
 script naming LeashFramework (API stub in Source/BuildStubs, never deployed; DR2). Dead on
 the stock VM without the framework (F32), so every call into it sits behind
 Native_IsLeashFrameworkInstalled() on the same line or the If directly above (check 6,
 trap leashlib-ungated). Settings: the leashlib Authority rows leashFrameworkEnabled /
 leashAttachment / leashStyle (DR19). Consumers keep their own LeashFramework_* ModEvent
 handlers and filter by their own subjects. Kidnap-entry mirror bits:
 128 PHYSLEASH, 256 LEASH_CHAIN, 512 LEASH_RUNES (SeverActions_Kidnap's KIDNAP_FLAG_*),
 a no-op for an actor with no entry, which the arrest escort relies on. Rope lengths
 120 / 350 are FollowerManager's LeashMinLength / LeashMaxLength runtime values (DR18).}

; --- Presence and version ---

Bool Function Active() Global
    {Setting on AND the framework present (DLL loaded + Leash.esm).}
    Return SeverActionsNativeExt2.Settings_GetBool("leashFrameworkEnabled") && SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
EndFunction

Bool Function WristAvailable() Global
    {Leash Framework 1.1.1's hand leash is installed (lead by the wrists, not the
     neck). Not cached: the player can update the framework mid-playthrough.}
    Return SeverActionsNativeExt2.Native_LeashHasHandLeash()
EndFunction

Function WarnIfOutdated() Global
    {Once per playthrough, tell a player whose Leash Framework is older than 1.1.1
     (the stated requirement: every rope assumes its wrist attachment) that they get
     the neck collar. Gated on the framework being installed, not on
     leashFrameworkEnabled (they should know before turning it back on). The
     sentinel clears once the wrist chain appears, re-arming the notice.}
    If !SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        Return
    EndIf
    If WristAvailable()
        StorageUtil.UnsetIntValue(None, "SeverActions_LeashVerWarned")
        Return
    EndIf
    If StorageUtil.GetIntValue(None, "SeverActions_LeashVerWarned", 0) == 1
        Return
    EndIf
    StorageUtil.SetIntValue(None, "SeverActions_LeashVerWarned", 1)
    String verMsg = "SeverActions has found Leash Framework, but an older version than it needs. "
    verMsg += "Captives are meant to be led by a rope from the leader's hand to their BOUND WRISTS, and that attachment arrived in Leash Framework 1.1.1. "
    verMsg += "On this version the framework can only put a collar on the captive, so every rope runs from the neck instead. "
    verMsg += "Everything still works - being tugged along, dragged off their feet, and tied to furniture - it just looks wrong. "
    verMsg += "Update Leash Framework to 1.1.1 or newer (Nexus 187303) for the intended behaviour."
    Debug.Notification("SeverActions: update Leash Framework to 1.1.1 or newer.")
    Debug.MessageBox(verMsg)
    Debug.Trace("[SeverActions_LeashLib] LeashFramework: installed but pre-1.1.1 (no Leash_hand_chain) - neck collar in use")
EndFunction

; --- The meshes ---

Armor Function ArmorForStyle(Int aiStyle) Global
    {The Leash.esm collar for a style (0 rope / 1 chain / 2 runes). Framework must be
     installed: GetFormFromFile on an absent plugin logs an error.}
    Int fid = 0x000804 ; Leash_neck (rope)
    If aiStyle == 1
        fid = 0x000806 ; Leash_neck_chain
    ElseIf aiStyle == 2
        fid = 0x0002CE ; Leash_neck_runic
    EndIf
    Return Game.GetFormFromFile(fid, "Leash.esm") as Armor
EndFunction

Function RemoveHandLeashFrom(Actor akHolder) Global
    {Take the hand chain (Leash_hand_chain 0x000D69) off a holder. Unconditional: the
     caller first checks they lead nobody else (one chain leads several captives). No-op
     when they carry none, or on 1.1.0 where the armor does not exist.}
    If !akHolder || !SeverActionsNativeExt2.Native_LeashHasHandLeash()
        Return
    EndIf
    Armor handChain = Game.GetFormFromFile(0x000D69, "Leash.esm") as Armor
    If handChain && akHolder.GetItemCount(handChain) > 0
        akHolder.UnequipItem(handChain, false, true)
        akHolder.RemoveItem(handChain, akHolder.GetItemCount(handChain), true)
    EndIf
EndFunction

Function RemoveLeashArmor(Actor akVictim) Global
    {Strip every collar variant (the style may have changed mid-leash).}
    Int s = 0
    While s < 3
        Armor a = ArmorForStyle(s)
        If a && akVictim.GetItemCount(a) > 0
            akVictim.UnequipItem(a, false, true)
            akVictim.RemoveItem(a, akVictim.GetItemCount(a), true)
        EndIf
        s += 1
    EndWhile
EndFunction

; --- Rope from a holder to a captive ---

Bool Function Attach(Actor akVictim, Actor akHolder) Global
    {Rope from a holder to a captive; False when refused. WRIST (leashAttachment 0 on
     1.1.1+): the holder wears Leash_hand_chain, tied to the captive's hand bone, with a
     closed fist, and is recorded as SeverKidnap_LeashHandHolder; one mesh, so leashStyle
     is ignored and the flags report 'chain'. NECK
     (collar chosen, or 1.1.0): the captive wears the leashStyle collar and either holder
     gets the grip (ApplyLeashToHand). persistent=true, so the framework restores the rope
     on load; the tick reconciles either way. SeverKidnap_PhysLeash marks the rope as ours.}
    If !akVictim || !akHolder || akVictim == akHolder || !Active()
        Return False
    EndIf
    ; WRIST unless the collar was chosen; on 1.1.0 only the neck path works, whatever the
    ; setting.
    If SeverActionsNativeExt2.Settings_GetInt("leashAttachment") == 0 && WristAvailable()
        Armor handChain = Game.GetFormFromFile(0x000D69, "Leash.esm") as Armor
        If !handChain
            Debug.Trace("[SeverActions_LeashLib] LeashFramework: hand leash armor missing despite the version gate")
            Return False
        EndIf
        If akHolder.GetItemCount(handChain) == 0
            akHolder.AddItem(handChain, 1, true)
        EndIf
        If !akHolder.IsEquipped(handChain)
            akHolder.EquipItem(handChain, true, true)  ; abPreventRemoval, abSilent
            ; EquipItem attaches the 3D asynchronously and the bind reads the live
            ; skeleton: binding this frame finds no leash nodes. Let the armor land.
            Utility.Wait(0.75)
        EndIf
        ; Tied at the captive's LEFT hand (bound hands sit behind the back). The holder's
        ; chain hangs from the Shield node on the left arm, hence closedHand 2.
        Bool okWrist = LeashFramework.ApplyHolderOwnedLeashToBone(akHolder, akVictim, \
            "NPC L Hand [LHnd]", "Shield", "Leash1_1", 120.0, 350.0, True, \
            0.0, 0.0, 0.0, 2)
        If okWrist
            StorageUtil.SetIntValue(akVictim, "SeverKidnap_PhysLeash", 1)
            StorageUtil.SetIntValue(akVictim, "SeverKidnap_PhysLeashFails", 0)
            StorageUtil.SetFormValue(akVictim, "SeverKidnap_LeashHandHolder", akHolder)
            SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, 128, True)
            SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, 256, True)
            SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, 512, False)
            Debug.Trace("[SeverActions_LeashLib] LeashFramework: " + akVictim.GetDisplayName() \
                + " led by the wrists from " + akHolder.GetDisplayName() + "'s hand")
        Else
            RemoveHandLeashFrom(akHolder)
            StorageUtil.SetIntValue(akVictim, "SeverKidnap_PhysLeashFails", StorageUtil.GetIntValue(akVictim, "SeverKidnap_PhysLeashFails", 0) + 1)
            Debug.Trace("[SeverActions_LeashLib] LeashFramework: hand-leash apply refused for " \
                + akVictim.GetDisplayName() + " <- " + akHolder.GetDisplayName())
        EndIf
        Return okWrist
    EndIf

    ; NECK (collar chosen, or 1.1.0): the captive wears the collar.
    Armor leashArmor = ArmorForStyle(SeverActionsNativeExt2.Settings_GetInt("leashStyle"))
    If !leashArmor
        Debug.Trace("[SeverActions_LeashLib] LeashFramework: collar armor for style " + SeverActionsNativeExt2.Settings_GetInt("leashStyle") + " missing from Leash.esm")
        Return False
    EndIf
    If akVictim.GetItemCount(leashArmor) == 0
        akVictim.AddItem(leashArmor, 1, true)
    EndIf
    If !akVictim.IsEquipped(leashArmor)
        akVictim.EquipItem(leashArmor, true, true)  ; abPreventRemoval, abSilent
        ; Same async 3D as the hand chain above.
        Utility.Wait(0.75)
    EndIf
    ; Bone arguments, read from the collar NIFs: every collar parents 'Leash1_0' under
    ; 'NPC Spine2 [Spn2]', merged into that skeleton bone at equip. The framework searches
    ; the parent's descendants for names containing the match, so the parent is that bone
    ; and the match the chain prefix 'Leash1_1' (a substring survives SMP renames). As
    ; parent, 'Leash1_0' is never found and 'NPC Neck [Neck]' has no chain beneath it:
    ; either leaves the rope unbound on the floor. The framework retries the bind every
    ; frame; the equip wait only spares a warning.
    ; Both holders use ApplyLeashToHand: ApplyLeashToBone's parameters differ between 1.1.0
    ; and 1.1.1 (the stub has 1.1.1's three trailing offsets and Papyrus fills defaults at
    ; the call site, which a 1.1.0 install cannot satisfy). ApplyLeashToHand is stable.
    Bool ok = LeashFramework.ApplyLeashToHand(akHolder, akVictim, "NPC Spine2 [Spn2]", "Leash1_1", 120.0, 350.0, True, True)
    If ok
        StorageUtil.SetIntValue(akVictim, "SeverKidnap_PhysLeash", 1)
        StorageUtil.SetIntValue(akVictim, "SeverKidnap_PhysLeashFails", 0)
        ; Mirror for the decorators (worker threads cannot read StorageUtil).
        SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, 128, True)
        SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, 256, SeverActionsNativeExt2.Settings_GetInt("leashStyle") == 1)
        SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, 512, SeverActionsNativeExt2.Settings_GetInt("leashStyle") == 2)
        Debug.Trace("[SeverActions_LeashLib] LeashFramework: " + akVictim.GetDisplayName() + " leashed to " + akHolder.GetDisplayName() + " (style " + SeverActionsNativeExt2.Settings_GetInt("leashStyle") + ")")
    Else
        ; Refused: drop the collar and count the refusal so the tick's retry is bounded.
        RemoveLeashArmor(akVictim)
        StorageUtil.SetIntValue(akVictim, "SeverKidnap_PhysLeashFails", StorageUtil.GetIntValue(akVictim, "SeverKidnap_PhysLeashFails", 0) + 1)
        Debug.Trace("[SeverActions_LeashLib] LeashFramework: ApplyLeash refused for " + akVictim.GetDisplayName() + " -> " + akHolder.GetDisplayName())
    EndIf
    Return ok
EndFunction

Function Detach(Actor akVictim) Global
    {Rope off, collar removed (and the holder's hand chain once they lead nobody), marks
     and mirror bits cleared. Ignores the setting (it can flip mid-leash). No-op when
     nothing was attached.}
    If !akVictim
        Return
    EndIf
    If SeverActionsNativeExt2.Native_IsLeashFrameworkInstalled()
        ; Fast path: Kidnap's _BindCaptive calls this on every pin, so sweep the armors
        ; only when a rope is live or marked.
        Bool hadRope = LeashFramework.IsLeashed(akVictim)
        If hadRope
            LeashFramework.UnleashAll(akVictim)
        EndIf
        If hadRope || StorageUtil.GetIntValue(akVictim, "SeverKidnap_PhysLeash", 0) == 1
            RemoveLeashArmor(akVictim)
            ; Hand chain off only once its holder leads nobody: one chain can lead
            ; several captives.
            Actor handHolder = StorageUtil.GetFormValue(akVictim, "SeverKidnap_LeashHandHolder") as Actor
            If handHolder
                Actor[] stillLed = LeashFramework.GetLeashedActors(handHolder)
                If !stillLed || stillLed.Length == 0
                    RemoveHandLeashFrom(handHolder)
                EndIf
            EndIf
        EndIf
    EndIf
    StorageUtil.UnsetFormValue(akVictim, "SeverKidnap_LeashHandHolder")
    StorageUtil.UnsetIntValue(akVictim, "SeverKidnap_PhysLeash")
    StorageUtil.UnsetIntValue(akVictim, "SeverKidnap_PhysLeashFails")
    ; No-op when the kidnap entry is already gone.
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, 128, False)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, 256, False)
    SeverActionsNativeExt.Native_Kidnap_SetFlag(akVictim, 512, False)
EndFunction

; --- The furniture tie (holderless rope) and framework reads ---

Bool Function AnchorAtPosition(Actor akVictim, Cell akCell, Float afX, Float afY, Float afZ, String asParentBone, Float afSlack, Float afLength) Global
    {A holderless rope from the captive (who wears the mesh) to a world position: the
     furniture tie. afSlack is the framework's MIN, where pulling stops: it must exceed
     where the captive stands, or the rope hauls at a pinned prisoner forever.}
    If !akVictim || !akCell
        Return False
    EndIf
    Return LeashFramework.ApplyLeashAtPosition(akVictim, akCell, afX, afY, afZ, asParentBone, "Leash1_1", afSlack, afLength, True)
EndFunction

Function DisconnectHolderless(Actor akVictim) Global
    {Cut a holderless (anchored) rope: DisconnectLeash with a None holder.}
    If akVictim
        LeashFramework.DisconnectLeash(None, akVictim)
    EndIf
EndFunction

Actor Function HolderOf(Actor akVictim) Global
    {Who the framework says holds this actor's rope, or None.}
    If !akVictim
        Return None
    EndIf
    Return LeashFramework.GetLeashHolder(akVictim)
EndFunction

; --- Pull narration ---
; Shared by the kidnap and arrest pull handlers. Only called from a framework event, so
; the framework is present.

String Function TetherWord(Actor akVictim) Global
    {What is on them, from the mirror bits - not the setting, which may have changed
     since the rope went on.}
    If SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, 512)        ; LEASH_RUNES
        Return "the rune tether"
    ElseIf SeverActionsNativeExt.Native_Kidnap_GetFlag(akVictim, 256)    ; LEASH_CHAIN
        Return "the chain"
    EndIf
    Return "the rope"
EndFunction

Function NarratePull(Actor akVictim, Bool abRagdoll, Float afDistance, Actor akFallbackHolder, String asHolderNoun) Global
    {Turn a pull on the caller's own subject into a SkyrimNet event. A plain tug is
     limited to one line per 20 real seconds (digging in starts a new pull every few
     seconds); a ragdoll drag always lands. akFallbackHolder (the caller's kidnapper or
     guard) is used when neither the framework nor a recorded hand holder names one;
     asHolderNoun ("the guard") when no holder resolves at all.}
    If !akVictim || StorageUtil.GetIntValue(akVictim, "SeverKidnap_PhysLeash", 0) != 1
        Return
    EndIf
    Float nowRT = Utility.GetCurrentRealTime()
    If !abRagdoll && nowRT - StorageUtil.GetFloatValue(akVictim, "SeverKidnap_PhysLeashNarr", -100.0) < 20.0
        Return
    EndIf
    StorageUtil.SetFloatValue(akVictim, "SeverKidnap_PhysLeashNarr", nowRT)

    ; Only Attach's wrist branch records a real hand holder. The furniture tie records the
    ; captive as holder of their own chain (a teardown handle, not a leader): ignore it, or
    ; an anchored rope narrates "X hauls X along".
    Actor handHolder = StorageUtil.GetFormValue(akVictim, "SeverKidnap_LeashHandHolder") as Actor
    Bool ledByHand = handHolder && handHolder != akVictim
    Actor holder = HolderOf(akVictim)
    If !holder && ledByHand
        holder = handHolder
    EndIf
    If !holder
        holder = akFallbackHolder
    EndIf
    String holderName = asHolderNoun
    If holder
        holderName = holder.GetDisplayName()
    EndIf

    ; The grip was fixed when the rope went on (leashAttachment can flip without a
    ; re-attach): the recorded hand holder says wrists, not the live setting.
    String grip = "by the neck"
    If ledByHand
        grip = "by the wrists"
    EndIf

    String tether = TetherWord(akVictim)
    String line
    If abRagdoll
        line = akVictim.GetDisplayName() + " dug in against " + tether + " and " + holderName + " hauled them off their feet - dragged bodily along the ground " + grip + "."
    Else
        line = tether + " snaps taut and " + holderName + " hauls " + akVictim.GetDisplayName() + " along " + grip + "."
    EndIf
    SkyrimNetApi.RegisterShortLivedEvent("leash_pull_" + akVictim.GetFormID(), "leash_pull", line, "", 60000, holder, akVictim)
    Debug.Trace("[SeverActions_LeashLib] LeashFramework: pull on " + akVictim.GetDisplayName() + " (ragdoll=" + abRagdoll + ", dist=" + afDistance + ")")
EndFunction

Function RestoreBoundPose(Actor akVictim, Idle akBoundStanding) Global
    {Restore the hands-behind-back offset a ragdoll pull reset (the landing resets the
     behaviour graph; the owning tick replays it only on a moving->stopped edge, 30s
     wide). The offset survives walking, so this does not wait for a halt. The caller
     passes its own bound idle: a script property this library must not reach for.}
    If !akVictim || akVictim.IsDead() || !akBoundStanding
        Return
    EndIf
    ; The pose is gone: a stale posed flag makes the tick's edge check never replay it.
    StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 0)
    ; One poller per subject: repeated pulls would stack loops fighting over the idle.
    If StorageUtil.GetIntValue(akVictim, "SeverKidnap_ReposeLoop", 0) == 1
        Return
    EndIf
    StorageUtil.SetIntValue(akVictim, "SeverKidnap_ReposeLoop", 1)

    ; Forced ragdoll recovery takes ~2.5-3s and posing mid-recovery fails.
    Utility.Wait(3.5)
    Int tries = 0
    While tries < 6
        If !akVictim || akVictim.IsDead() || StorageUtil.GetIntValue(akVictim, "SeverKidnap_PhysLeash", 0) != 1
            ; Released, untied or dead mid-drag.
            StorageUtil.UnsetIntValue(akVictim, "SeverKidnap_ReposeLoop")
            Return
        EndIf
        ; No speed gate (see the doc). Retry only on a PlayIdle refusal, which comes
        ; while they are still prone.
        If akVictim.Is3DLoaded() && akVictim.PlayIdle(akBoundStanding)
            StorageUtil.SetIntValue(akVictim, "SeverRestrain_Posed", 1)
            Debug.Trace("[SeverActions_LeashLib] bound pose restored after ragdoll for " + akVictim.GetDisplayName())
            StorageUtil.UnsetIntValue(akVictim, "SeverKidnap_ReposeLoop")
            Return
        EndIf
        Utility.Wait(1.5)
        tries += 1
    EndWhile
    ; Refused six times (~12s): leave the flag clear so the owning tick retries at a halt.
    StorageUtil.UnsetIntValue(akVictim, "SeverKidnap_ReposeLoop")
EndFunction
