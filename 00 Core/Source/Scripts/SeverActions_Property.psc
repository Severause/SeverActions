Scriptname SeverActions_Property extends Quest

{
    Property Ownership System for SeverActions

    Transfers cell/building ownership via native C++ functions with
    faction-based co-ownership. Both the player and original owner are
    added to a shared faction so neither gets theft/trespass flags.
}

Faction Property SeverActions_PropertyFaction Auto
{Shared faction for property co-ownership. Both player and original
 owner are added so both can use beds, containers, etc. without theft.
 Create in CK — just a new faction, no special setup needed.}

Function TransferOwnership(Actor akActor, String propertyName)
    {An NPC transfers ownership of a property to the player via shared faction.
     akActor is the NPC giving away ownership (the speaker).
     If propertyName is empty, transfers the current location.}

    If akActor == None
        Debug.Trace("[SeverActions_Property] ERROR: TransferOwnership called with None actor")
        Return
    EndIf

    If SeverActions_PropertyFaction == None
        Debug.Trace("[SeverActions_Property] ERROR: SeverActions_PropertyFaction not filled — create in CK")
        Debug.Notification("Property system error — faction not configured.")
        Return
    EndIf

    String cleanName = propertyName
    If cleanName != ""
        cleanName = SeverActionsNative.TrimString(cleanName)
    EndIf

    Bool success = SeverActionsNative.Native_TransferCellOwnership(Game.GetPlayer(), cleanName, SeverActions_PropertyFaction)

    String displayName = cleanName
    If displayName == ""
        displayName = "this property"
    EndIf

    If success
        Debug.Notification(akActor.GetDisplayName() + " transferred " + displayName + " to you.")
        Debug.Trace("[SeverActions_Property] " + akActor.GetDisplayName() + " transferred '" + displayName + "' to player")
    Else
        Debug.Notification("Failed to transfer ownership.")
        Debug.Trace("[SeverActions_Property] Failed to transfer '" + displayName + "' from " + akActor.GetDisplayName())
    EndIf
EndFunction
