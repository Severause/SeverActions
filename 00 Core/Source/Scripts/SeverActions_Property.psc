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

    ; Ownership gate (issue #12 public). The LLM picks this action freely and
    ; SkyrimNet eligibility decorators can't see the dynamic propertyName
    ; parameter at filter time, so the only place to enforce "speaker actually
    ; owns this" is here. Native_IsCellOwner accepts either a direct NPC owner
    ; or membership in the cell's faction owner (covers Hulda/Bannered Mare via
    ; BanneredMareInnFaction etc.). Empty cleanName falls back to akActor's
    ; current cell, matching the transfer fallback.
    If !SeverActionsNative.Native_IsCellOwner(akActor, cleanName)
        String rejected = cleanName
        If rejected == ""
            rejected = "this property"
        EndIf
        Debug.Notification(akActor.GetDisplayName() + " doesn't own " + rejected + ".")
        Debug.Trace("[SeverActions_Property] REJECTED transfer — " + akActor.GetDisplayName() \
            + " is not the owner of '" + rejected + "'")
        Return
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
