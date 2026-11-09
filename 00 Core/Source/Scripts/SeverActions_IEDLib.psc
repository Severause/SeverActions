Scriptname SeverActions_IEDLib Hidden
{The only script that names IED (Immersive Equipment Displays; DR2), which draws the weapons
 and other items an NPC carries but does not hold. An Undress hides everything IED draws on the
 NPC until the undress ends. Without IED this class is dead on the stock VM (F32), so every call
 into it is gated by SeverActionsNativeExt2.Native_IsIEDInstalled() on the same line or the If
 directly above (check 6, trap iedlib-ungated). IED saves the block in its own cosave, keyed by
 our plugin, so it holds through loads and drops if SeverActions.esp leaves the load order.}

Function Hide(Actor akActor) Global
    {IED draws nothing on akActor until Show (idempotent).}
    IED.AddActorBlock(akActor, "SeverActions.esp")
EndFunction

Function Show(Actor akActor) Global
    {Lifts Hide's block (a no-op when there is none).}
    IED.RemoveActorBlock(akActor, "SeverActions.esp")
EndFunction
