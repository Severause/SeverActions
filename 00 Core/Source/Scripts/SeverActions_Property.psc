Scriptname SeverActions_Property extends Quest

{
    Property ownership: an NPC hands a cell or building to the player through native C++,
    as co-ownership through a shared faction.
}

Faction Property SeverActions_PropertyFaction Auto
{The co-ownership faction: the player and the residents whose ownership a transfer took join it,
 so each can use the beds and containers without a theft or trespass flag. It is shared by every
 transferred property.}

Function TransferOwnership(Actor akActor, String propertyName)
    {akActor (the speaker, who must own it or be its hold's jarl) gives propertyName to the
     player; an empty name means the current cell.}

    If akActor == None
        Debug.Trace("[SeverActions_Property] ERROR: TransferOwnership called with None actor")
        Return
    EndIf

    If SeverActions_PropertyFaction == None
        Debug.Trace("[SeverActions_Property] ERROR: SeverActions_PropertyFaction not filled - create in CK")
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("property.systemErrorFaction"))
        Return
    EndIf

    String cleanName = propertyName
    If cleanName != ""
        cleanName = SeverActionsNative.TrimString(cleanName)
    EndIf

    ; Eligibility decorators cannot see propertyName, so ownership is enforced here.
    ; Native_IsCellOwner accepts the cell's NPC owner, a member of its owning faction (Hulda
    ; through BanneredMareInnFaction) or the hold's jarl. With "" it checks the SPEAKER's cell
    ; while the transfer takes the PLAYER's, so an unnamed transfer needs both in one cell.
    Bool owns = SeverActionsNative.Native_IsCellOwner(akActor, cleanName)
    If owns && cleanName == "" && akActor.GetParentCell() != Game.GetPlayer().GetParentCell()
        owns = False
    EndIf
    If !owns
        String rejected = cleanName
        If rejected == ""
            rejected = "this property"
        EndIf
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("property.doesntOwn", ("" + akActor.GetDisplayName()), ("" + rejected)))
        Debug.Trace("[SeverActions_Property] REJECTED transfer - " + akActor.GetDisplayName() \
            + " is not the owner of '" + rejected + "'")
        Return
    EndIf

    Bool success = SeverActionsNative.Native_TransferCellOwnership(Game.GetPlayer(), cleanName, SeverActions_PropertyFaction)

    String displayName = cleanName
    If displayName == ""
        displayName = "this property"
    EndIf

    If success
        Debug.Notification(SeverActionsNativeExt2.Native_L10nFmt("property.transferredToYou", ("" + akActor.GetDisplayName()), ("" + displayName)))
        Debug.Trace("[SeverActions_Property] " + akActor.GetDisplayName() + " transferred '" + displayName + "' to player")
    Else
        Debug.Notification(SeverActionsNativeExt2.Native_L10n("property.failedToTransfer"))
        Debug.Trace("[SeverActions_Property] Failed to transfer '" + displayName + "' from " + akActor.GetDisplayName())
    EndIf
EndFunction
