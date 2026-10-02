Scriptname SeverActions_Mod_Followers extends SeverActions_ModuleBase
{Provider of the "followers" module: alias 260 of quest 0x000D62 (plan 3.0 M-P). Init K3 runs
 its idempotent OnModuleLoad stages on every load (DR20); they forward to the module's host
 scripts, which register their own events (DR16). Homes live in FollowerManager.
 ServiceBool services (False without this module; see ServiceBool): "jailStrip", "leaveSchedule",
 "rerecruit", "sandbox", "stopSandbox", "dismiss", "leaveToAttack", "assignHome", "clearHome",
 "purge" take akA as the actor;
 "resetAll" and "schedPoolExhausted" take none. The MCM calls them synchronously, since its
 page redraws from the result (DR13).}

String Function BundleId()
    Return "followers"
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
    If aiStage == 1
        ; Follow's Maintenance, then FollowerManager's (roster, detection, the tick chain).
        SeverActions_Follow followSys = q as SeverActions_Follow
        If followSys
            followSys.Maintenance()
            Debug.Trace("[SeverActions] Follow System initialized successfully")
        Else
            Debug.Trace("[SeverActions] Follow System not found (optional)")
        EndIf
        SeverActions_FollowerManager fmSys = q as SeverActions_FollowerManager
        If fmSys
            fmSys.Maintenance()
            Int count = fmSys.GetFollowerCount()
            Debug.Trace("[SeverActions] Follower Manager initialized - " + count + " companions tracked")
        Else
            Debug.Trace("[SeverActions] Follower Manager not found (optional)")
        EndIf
    EndIf
    If aiStage == 2
        ; Stage 2: the custom-AI reconcile runs after Arrest's and Travel's recoveries.
        SeverActions_FollowerManager fmRecovery = q as SeverActions_FollowerManager
        If fmRecovery
            fmRecovery.OnGameLoaded()
            Debug.Trace("[SeverActions] FollowerManager load recovery complete")
        EndIf
    EndIf
EndFunction

String[] Function ChronoTickNames()
    {The always-on tick chain the Init K4 watchdog heals; on-demand ticks are not listed.}
    String[] names = new String[1]
    names[0] = "SeverActions_Tick_FollowerManager"
    Return names
EndFunction

Function OnChronoDead(String asTickName)
    {Re-arm the chain the watchdog found unacknowledged since load.}
    If asTickName == "SeverActions_Tick_FollowerManager"
        SeverActions_FollowerManager fmKick = GetOwningQuest() as SeverActions_FollowerManager
        If fmKick
            fmKick.ChronoArm(0.1)
        EndIf
    EndIf
EndFunction

Bool Function ServiceBool(String asSvc, Form akA, Form akB, String asArg, Float afArg)
    {Each answers True once forwarded, False without the module or a needed actor.
     "jailStrip" (Arrest): pull akA off the schedule, whose holds would otherwise fight the
     jail sandbox (a just-jailed prisoner) or outrank the arrest packages (a retainer going
     on task as a guard).
     "leaveSchedule" (SpellCast, Crafting): YieldSchedule(akA) for an NPC the schedule holds, whose
     alias packages outrank the caller's crafter or caster alias; False when she holds none.
     "rerecruit" (Brawl, the MCM's Re-Recruit): RegisterFollower(akA). A caller without this
     module reseats them in their own framework instead.
     "sandbox" / "stopSandbox" (Kidnap): Follow's wait sandbox on / off, for a kidnapper
     guarding a hold.
     "dismiss": DismissCompanion(akA) - sends home, a deliberate exit (so NFF dismisses too).
     "leaveToAttack" (Combat's AttackTarget, Enterprises' RenounceCampOath): LeaveToAttack(akA,
     akB) - akA leaves the player's service before turning on akB, the player or another
     companion; False when akA was not on the roster.
     "assignHome": AssignHome(akA, asArg), asArg the location name; False when it is "".
     "clearHome": ClearHome(akA). "purge": ForceRemoveFollower(akA), the MCM's Force Remove.
     "resetAll" (no actor): UnregisterFollower(x, false) for every follower - the ordinary
     dismiss (SA's own recruits lose SA's flags) without send-home or NFF's dismiss.
     "schedPoolExhausted" (no actor): answers GetSchedPoolExhausted(afArg), afArg the pool
     (0 home, 1 work, 2 relax) - set when that alias pool ran out, cleared when a slot frees.
     An unanswered name gets the base default, never another service's work.}
    ; The actor-less services, before the actor early-out.
    If asSvc == "resetAll" || asSvc == "schedPoolExhausted"
        SeverActions_FollowerManager fmAll = GetOwningQuest() as SeverActions_FollowerManager
        If !fmAll
            Return False
        EndIf
        If asSvc == "schedPoolExhausted"
            Return fmAll.GetSchedPoolExhausted(afArg as Int)
        EndIf
        Actor[] managed = fmAll.GetAllFollowers()
        If managed
            Int j = 0
            While j < managed.Length
                If managed[j]
                    ; sendHome false; abDeliberateExit keeps its false default
                    fmAll.UnregisterFollower(managed[j], false)
                EndIf
                j += 1
            EndWhile
        EndIf
        Return True
    EndIf
    If asSvc != "jailStrip" && asSvc != "leaveSchedule" && asSvc != "rerecruit" && asSvc != "sandbox" && asSvc != "stopSandbox" && asSvc != "dismiss" && asSvc != "leaveToAttack" && asSvc != "assignHome" && asSvc != "clearHome" && asSvc != "purge"
        Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
    EndIf
    Actor a = akA as Actor
    If !a
        Return False
    EndIf
    If asSvc == "sandbox" || asSvc == "stopSandbox"
        SeverActions_Follow follow = GetOwningQuest() as SeverActions_Follow
        If !follow
            Return False
        EndIf
        If asSvc == "sandbox"
            follow.Sandbox(a)
        Else
            follow.StopSandbox(a)
        EndIf
        Return True
    EndIf
    SeverActions_FollowerManager fm = GetOwningQuest() as SeverActions_FollowerManager
    If !fm
        Return False
    EndIf
    If asSvc == "jailStrip"
        fm.StripScheduleForJail(a)
        Return True
    ElseIf asSvc == "leaveSchedule"
        If !fm.HoldsAnySchedAlias(a)
            Return False
        EndIf
        fm.YieldSchedule(a)
        Return True
    ElseIf asSvc == "rerecruit"
        fm.RegisterFollower(a)
        Return True
    ElseIf asSvc == "dismiss"
        fm.DismissCompanion(a)
        Return True
    ElseIf asSvc == "leaveToAttack"
        Return fm.LeaveToAttack(a, akB as Actor)
    ElseIf asSvc == "assignHome"
        If asArg == ""
            Return False
        EndIf
        fm.AssignHome(a, asArg)
        Return True
    ElseIf asSvc == "clearHome"
        fm.ClearHome(a)
        Return True
    ElseIf asSvc == "purge"
        fm.ForceRemoveFollower(a)
        Return True
    EndIf
    Return Parent.ServiceBool(asSvc, akA, akB, asArg, afArg)
EndFunction

Event OnInit()
    ; Log only: setup runs from the load stages, since a re-added script gets no OnInit (DR20, F35).
    Debug.Trace("[SeverActions] provider followers: bound (alias 260)")
EndEvent
