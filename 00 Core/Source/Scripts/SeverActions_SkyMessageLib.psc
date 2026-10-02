Scriptname SeverActions_SkyMessageLib Hidden
{The only script that names SkyMessage (the optional "Papyrus MessageBox" mod; DR2): the
 fallback popups economy, brawl, crafting and arrest show when the UI host is unavailable.
 Without that mod this class is dead on the stock VM (F32), so every call into it is gated by
 SeverActionsNativeExt2.Native_IsSkyMessageInstalled() on the same line or the If directly
 above (check 6, trap skymsglib-ungated) and the caller takes its no-popup path.
 Deleting the fallback outright is decision D19.}

String Function Show(String bodyText, String button1, String button2 = "", String button3 = "", String button4 = "", Bool getIndex = false) Global
    {Blocking popup; the chosen button's text (its index as text when getIndex), "" if none.}
    Return SkyMessage.Show(bodyText, button1, button2, button3, button4, getIndex = getIndex)
EndFunction

Int Function ShowNonBlocking(String bodyText, String button1, String button2 = "", String button3 = "") Global
    {Non-blocking popup; the box id to poll (0 = none shown).}
    Return SkyMessage.Show_NonBlocking(bodyText, button1, button2, button3)
EndFunction

Bool Function IsResultAvailable(Int messageBoxId) Global
    Return SkyMessage.IsMessageResultAvailable(messageBoxId)
EndFunction

Int Function GetResultIndex(Int messageBoxId, Bool deleteResultOnAccess = true) Global
    Return SkyMessage.GetResultIndex(messageBoxId, deleteResultOnAccess)
EndFunction

Function Delete(Int messageBoxId) Global
    SkyMessage.Delete(messageBoxId)
EndFunction
