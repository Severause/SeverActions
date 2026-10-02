Scriptname SeverActions_OutfitSlot extends Quest
{
    NFF-style outfit slot system (wardrobe pattern). Each managed NPC gets a
    slot 0-99 (one OutfitSlotNN alias each) with 8 presets; a preset is a
    wardrobe chest, plus a BGSOutfit and a LeveledItem that are vestigial ESP
    scaffolding, never used to equip. One satchel per slot holds stowed
    guardian-container items. SetOutfit is never called on apply: its implicit
    UnequipAll re-triggers the alias debounce and re-runs the apply. Cell-load
    re-application is SeverActions_OutfitAlias.OnLoad calling DirectEquipPreset.

    Author: Severause
}

; Logs to Papyrus.0.log AND SeverActionsNative.log (the latter works with Papyrus logging off).
Function Log(String msg)
    SeverActionsNative.Native_OutfitSlot_Log(msg)
    Debug.Trace("[SeverOutfit] " + msg)
EndFunction

SeverActions_OutfitSlot Function GetInstance() Global
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_OutfitSlot
EndFunction

String Property KEY_PRESET_ACTIVE = "SeverOutfit_PresetActive" AutoReadOnly Hidden
{Int legacy mirror: 1 while a preset is active. Written for old saves and
 external readers only; OutfitAlias reads the native active index.}

; === SLOT LIFECYCLE ===

Int Function AssignSlotToActor(Actor akActor)
    {Assign actor to first free slot. Idempotent. Returns slot index or -1.
     On new assignment, snapshots the actor's original DefaultOutfit+sleepOutfit.
     Satchel + preset containers are spawned lazily on first use.}
    if !akActor
        return -1
    endif

    Int existingSlot = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if existingSlot >= 0
        return existingSlot
    endif

    Int slotIdx = SeverActionsNative.Native_OutfitSlot_AssignSlot(akActor)
    if slotIdx < 0
        Log("AssignSlotToActor: All 100 slots occupied, cannot assign " + akActor.GetDisplayName())
        return -1
    endif

    ; Snapshot original outfit for later restore
    SeverActionsNative.Native_OutfitSlot_SaveOriginalOutfit(akActor)

    ; Bind the OutfitSlotNN alias: SeverActions_OutfitAlias's events fire only for its bound actor.
    ReferenceAlias targetAlias = SeverActionsNative.Native_OutfitSlot_GetAliasForSlot(slotIdx)
    if targetAlias
        BindSlotAlias(akActor, targetAlias)
        Log("Assigned slot " + slotIdx + " to " + akActor.GetDisplayName() + " (alias bound)")
    else
        Log("WARNING: Slot " + slotIdx + " assigned but alias OutfitSlot" + PadSlotStr(slotIdx) + " not found in ESP")
    endif
    return slotIdx
EndFunction

Function BindSlotAlias(Actor akOwner, ReferenceAlias akAlias)
    {Bind a slot's alias to its owner. OutfitSlot00-09 are also in
     SeverActions_Outfit's follower alias pool: the slot owner wins and the
     displaced occupant is handed back through SeverActions_OutfitAliasDisplaced.
     The owner's own pool seat is dropped - both aliases run
     SeverActions_OutfitAlias, so each equip would be recorded twice and latch
     burst suppression. ClearOutfitSlot never clears an actor's own slot alias,
     so it is safe after the ForceRefTo.}
    if !akOwner || !akAlias
        return
    endif
    Actor occupant = akAlias.GetActorRef()
    if occupant == akOwner
        return
    endif
    akAlias.ForceRefTo(akOwner)
    SeverActions_Outfit poolSys = GetOutfitScript()
    if poolSys
        poolSys.ClearOutfitSlot(akOwner)
    endif
    if occupant
        Log("BindSlotAlias: " + occupant.GetDisplayName() + " held " + akOwner.GetDisplayName() + "'s slot alias - handed back to the follower outfit pool")
        Int handle = ModEvent.Create("SeverActions_OutfitAliasDisplaced")
        if handle
            ; Handler shape (eventName, strArg, numArg, sender): all four pushed.
            ModEvent.PushString(handle, "SeverActions_OutfitAliasDisplaced")
            ModEvent.PushString(handle, "")
            ModEvent.PushFloat(handle, 0.0)
            ModEvent.PushForm(handle, occupant)
            ModEvent.Send(handle)
        endif
    endif
EndFunction

String Function PadSlotStr(Int n)
    {Zero-pad to 2 digits to match the ESP alias naming convention "OutfitSlotNN".}
    if n < 10
        return "0" + n
    endif
    return "" + n
EndFunction

ObjectReference Function EnsureContainer(Actor akActor, Int slotIdx, Int presetIdx)
    {Lazy-spawn the preset container via PlaceAtMe if not already created.
     Returns the container ref (existing or newly spawned), or None on error.}
    ObjectReference chest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, presetIdx)
    if chest
        return chest
    endif

    Container chestBase = SeverActionsNative.Native_OutfitSlot_GetChestBase()
    if !chestBase
        Log("EnsureContainer: ChestBase record missing - ESP scaffolding not applied")
        return None
    endif

    Actor playerRef = Game.GetPlayer()
    chest = playerRef.PlaceAtMe(chestBase, 1, true, true)   ; forcePersist=true, initiallyDisabled=true
    if !chest
        Log("EnsureContainer: PlaceAtMe returned None for slot=" + slotIdx + " preset=" + presetIdx)
        return None
    endif

    ; Register with native store so it survives save/load
    SeverActionsNative.Native_OutfitSlot_SetContainerRef(akActor, presetIdx, chest)
    Log("Spawned container for slot=" + slotIdx + " preset=" + presetIdx + " formID=" + chest.GetFormID())
    return chest
EndFunction

ObjectReference Function EnsureSatchel(Actor akActor, Int slotIdx)
    {Lazy-spawn the satchel container via PlaceAtMe if not already created.}
    ObjectReference satchel = SeverActionsNative.Native_OutfitSlot_GetSatchel(slotIdx)
    if satchel
        return satchel
    endif

    Container chestBase = SeverActionsNative.Native_OutfitSlot_GetChestBase()
    if !chestBase
        Log("EnsureSatchel: ChestBase record missing")
        return None
    endif

    Actor playerRef = Game.GetPlayer()
    satchel = playerRef.PlaceAtMe(chestBase, 1, true, true)
    if !satchel
        Log("EnsureSatchel: PlaceAtMe returned None for slot=" + slotIdx)
        return None
    endif

    SeverActionsNative.Native_OutfitSlot_SetSatchelRef(akActor, satchel)
    Log("Spawned satchel for slot=" + slotIdx + " formID=" + satchel.GetFormID())
    return satchel
EndFunction

Function ReleaseSlotFromActor(Actor akActor)
    {Full slot release: restores the original outfit, empties and deletes the
     dynamic refs, clears all preset data. Only for force-remove or "Clear All
     Presets", never on dismiss (the slot persists through dismiss/re-recruit).}
    if !akActor
        return
    endif

    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        return
    endif

    ; 1. Clear any active preset (restores the original outfit + satchel)
    if SeverActionsNative.Native_OutfitSlot_IsPresetActive(akActor)
        ClearPreset(akActor)
    endif

    ; 1b. Restore guardians left stowed with NO preset active (an ad-hoc op, an
    ;     overwrite of the active preset) BEFORE step 3 drains the satchel into
    ;     the pack. A no-op when ClearPreset above restored them.
    RestoreGuardianContainers(akActor, slotIdx)

    ; 2. Empty + delete the preset containers. Contents are destroyed, not
    ;    given back: catalog items are the slot system's copies, and user-owned
    ;    entries are only markers (the actor holds the originals).
    Int p = 0
    While p < 8
        ObjectReference chest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, p)
        if chest
            if chest.GetNumItems() > 0
                chest.RemoveAllItems(None)  ; destroy, don't dump to player
            endif
            chest.Delete()   ; dynamic refs can be deleted
            SeverActionsNative.Native_OutfitSlot_SetContainerRef(akActor, p, None)
        endif
        LeveledItem lvl = SeverActionsNative.Native_OutfitSlot_GetLvlItem(slotIdx, p)
        if lvl
            lvl.Revert()
        endif
        SeverActionsNative.Native_OutfitSlot_ClearPreset(akActor, p)
        p += 1
    EndWhile

    ; 3. Empty + delete satchel
    ObjectReference satchel = SeverActionsNative.Native_OutfitSlot_GetSatchel(slotIdx)
    if satchel
        if satchel.GetNumItems() > 0
            satchel.RemoveAllItems(akActor)
        endif
        satchel.Delete()
        SeverActionsNative.Native_OutfitSlot_SetSatchelRef(akActor, None)
    endif

    ; 4. Unforce the slot alias only if it holds THIS actor (slots 0-9 share
    ;    their alias with FollowerManager's pool).
    ReferenceAlias slotAlias = SeverActionsNative.Native_OutfitSlot_GetAliasForSlot(slotIdx)
    if slotAlias && slotAlias.GetActorRef() == akActor
        slotAlias.Clear()
    endif

    ; 5. Release the native slot
    SeverActionsNative.Native_OutfitSlot_ReleaseSlot(akActor)

    ; 6. Clear Papyrus state flags
    StorageUtil.UnsetIntValue(akActor, KEY_PRESET_ACTIVE)

    Log("Released slot " + slotIdx + " from " + akActor.GetDisplayName())
EndFunction

; === PRESET BUILD ===

Int Function BuildPreset(Actor akActor, Int presetIdx, Form[] items, String presetName)
    {Fill preset presetIdx (0-7) from items (at most 32 kept) and store its
     name and item count. Re-applies it only when it was the active preset;
     otherwise call ApplyPresetBySlot. Returns the count committed, or -1.}
    if !akActor || presetIdx < 0 || presetIdx >= 8
        return -1
    endif

    Int slotIdx = AssignSlotToActor(akActor)
    if slotIdx < 0
        return -1
    endif

    ObjectReference chest = EnsureContainer(akActor, slotIdx, presetIdx)
    if !chest
        Log("BuildPreset: Could not spawn container for slot=" + slotIdx + " preset=" + presetIdx)
        return -1
    endif

    ; Owned suspend before any inventory mutation: the overwrite cleanup's
    ; removals fire OnObjectUnequipped -> debounce -> re-apply against a
    ; half-built chest (see _BeginOwnedOutfitOp). No Return between here and
    ; its end below.
    Int opToken = _BeginOwnedOutfitOp(akActor)

    ; Read before the cleanup clears the active index: an overwritten ACTIVE
    ; preset is re-applied at the end.
    Bool wasActive = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor) == presetIdx

    ; Overwrite: delete the old chest contents (RemoveAllItems(None) deletes).
    ; Catalog temp-copies are on the actor only while their preset is worn, so
    ; only an ACTIVE preset's overwrite takes one plain copy of each back. With
    ; it inactive, a matching copy on the actor is a gift, loot or the active
    ; preset's piece - a catalog tag is a build-time property of the preset,
    ; not a claim on the pack (the ReclaimPresetCopies rule) - so the actor is
    ; left alone and the chest is rebuilt from the pending catalog.
    ; EDIT MODE: an old catalog item that is also in the new preset stays on
    ; the actor and keeps its tag (retainedCatalogItems). buildOutfitSavePreset
    ; sees it in inventory and classes it user-owned, so without this the
    ; cleanup strips it, the chest gets only a marker, and the apply finds
    ; nothing to equip.
    Form[] retainedCatalogItems = Utility.CreateFormArray(32)
    Int retainedCatalogCount = 0
    Int oldChestCount = chest.GetNumItems()
    if oldChestCount > 0 && !wasActive
        ; Inactive: nothing on the actor belongs to this preset.
        chest.RemoveAllItems(None)
        SeverActionsNative.Native_OutfitSlot_ClearCatalogSupplied(akActor, presetIdx)
        Log("BuildPreset: overwrite deleted " + oldChestCount + " old chest items of INACTIVE preset " + presetIdx + " - actor inventory untouched (slot=" + slotIdx + ")")
    elseif oldChestCount > 0
        ; Snapshot the old forms before deleting them, for the actor cleanup.
        Form[] oldFormIDs = Utility.CreateFormArray(oldChestCount)
        Int snapI = 0
        While snapI < oldChestCount
            oldFormIDs[snapI] = chest.GetNthForm(snapI)
            snapI += 1
        EndWhile

        chest.RemoveAllItems(None)

        ; Per old form on the actor: blacklisted = never touched; catalog and
        ; in the new preset = retained (re-tagged below); other catalog = one
        ; plain copy deleted; user-owned = kept.
        Int cleanedCatalog = 0
        Int playerWorkSparedEdit = 0
        Int preservedUserOwned = 0
        Int retainedAcrossEdit = 0
        Int blacklistPreserved = 0
        Int ci = 0
        While ci < oldChestCount
            Form oldItem = oldFormIDs[ci]
            if oldItem
                Int actorHasOld = akActor.GetItemCount(oldItem)
                if actorHasOld > 0
                    if SeverActionsNative.Native_Blacklist_IsBlacklisted(oldItem)
                        ; Blacklist wins. A catalog item surviving the edit still
                        ; keeps its tag, or its temp copy leaks on the next swap.
                        Bool wasCatalogB = SeverActionsNative.Native_OutfitSlot_IsCatalogSupplied(akActor, presetIdx, oldItem)
                        if wasCatalogB
                            Bool survivesEditB = false
                            Int skb = 0
                            Int newCountB = items.Length
                            While skb < newCountB && !survivesEditB
                                if items[skb] == oldItem
                                    survivesEditB = true
                                endif
                                skb += 1
                            EndWhile
                            if survivesEditB && retainedCatalogCount < 32
                                retainedCatalogItems[retainedCatalogCount] = oldItem
                                retainedCatalogCount += 1
                            endif
                        endif
                        blacklistPreserved += 1
                    else
                        Bool wasCatalog = SeverActionsNative.Native_OutfitSlot_IsCatalogSupplied(akActor, presetIdx, oldItem)
                        if wasCatalog
                            Bool survivesEdit = false
                            Int sk = 0
                            Int newCount = items.Length
                            While sk < newCount && !survivesEdit
                                if items[sk] == oldItem
                                    survivesEdit = true
                                endif
                                sk += 1
                            EndWhile

                            if survivesEdit && retainedCatalogCount < 32
                                retainedCatalogItems[retainedCatalogCount] = oldItem
                                retainedCatalogCount += 1
                                retainedAcrossEdit += 1
                            else
                                ; Plain copies only (see RemovePresetItemsFromActor).
                                If SeverActionsNativeExt2.RemovePlainCopies(akActor, oldItem, 1, None) > 0
                                    cleanedCatalog += 1
                                Else
                                    playerWorkSparedEdit += 1
                                EndIf
                            endif
                        else
                            preservedUserOwned += 1
                        endif
                    endif
                endif
            endif
            ci += 1
        EndWhile

        ; The build loop below re-tags the retained items.
        SeverActionsNative.Native_OutfitSlot_ClearCatalogSupplied(akActor, presetIdx)

        ; (Only with wasActive.) The preset is no longer worn: clear the active
        ; index and OutfitDataStore's name tracker, which follows it. The
        ; re-apply at the end sets both again.
        SeverActionsNative.Native_OutfitSlot_SetActivePreset(akActor, -1)
        SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")
        StorageUtil.UnsetIntValue(akActor, KEY_PRESET_ACTIVE)
        Log("BuildPreset: cleared active state - overwrite affected the currently-active preset")

        Log("BuildPreset: overwrite deleted " + oldChestCount + " old chest items, cleaned " + cleanedCatalog + " catalog temp-copies, spared " + playerWorkSparedEdit + " player-modified, preserved " + preservedUserOwned + " user-owned items, retained " + retainedAcrossEdit + " across edit, preserved " + blacklistPreserved + " blacklisted (slot=" + slotIdx + " preset=" + presetIdx + ")")
    endif

    ; OWNERSHIP-AWARE BUILD. The pending catalog from C++ buildOutfitSavePreset
    ; lists the forms it ADDED to the actor because they were missing; every
    ; other item was already theirs (user-owned).
    ;   - Catalog: MOVE that copy to the chest and tag it catalog-supplied
    ;     (granted on apply, deleted on swap-out).
    ;   - User-owned: a MARKER copy into the chest, actor untouched (apply
    ;     equips their copy, swap-out only unequips).
    String normalizedName = presetName
    if normalizedName == ""
        normalizedName = "preset" + presetIdx
    endif

    ; Clear stale catalog tags before re-populating
    SeverActionsNative.Native_OutfitSlot_ClearCatalogSupplied(akActor, presetIdx)

    Form[] catalogList = SeverActionsNative.Native_OutfitSlot_PopPendingCatalog(akActor, normalizedName)
    Int catalogListLen = 0
    if catalogList
        catalogListLen = catalogList.Length
    endif

    Form[] committedItems = Utility.CreateFormArray(32)
    Int committed = 0
    Int catalogTagged = 0
    Int playerWorkSparedBuild = 0
    Int userOwnedTagged = 0
    Int i = 0
    Int count = items.Length
    While i < count && committed < 32
        if items[i]
            ; Is this item in the catalog list (C++ spawned it)?
            Bool isCatalog = false
            if catalogList && catalogListLen > 0
                Int ck = 0
                While ck < catalogListLen && !isCatalog
                    if catalogList[ck] == items[i]
                        isCatalog = true
                    endif
                    ck += 1
                EndWhile
            endif

            ; EDIT-MODE CARRYOVER: items retained across the edit stay catalog.
            if !isCatalog && retainedCatalogCount > 0
                Int rk = 0
                While rk < retainedCatalogCount && !isCatalog
                    if retainedCatalogItems[rk] == items[i]
                        isCatalog = true
                    endif
                    rk += 1
                EndWhile
            endif

            if isCatalog
                ; Catalog: MOVE the actor's copy (C++'s grant, or one retained
                ; across the edit) to the chest.
                Int npcCount = akActor.GetItemCount(items[i])
                if npcCount > 0
                    ; Plain copies only: a player-enchanted piece never goes
                    ; into the chest.
                    If SeverActionsNativeExt2.RemovePlainCopies(akActor, items[i], 1, chest) <= 0
                        ; Only the player's own modified copy is left: record it
                        ; as USER-OWNED (marker copy, the actor keeps theirs) and
                        ; do NOT tag it - the catalog tag licenses the teardown
                        ; to delete a plain copy of the same base form.
                        chest.AddItem(items[i], 1, true)
                        playerWorkSparedBuild += 1
                        isCatalog = false
                    EndIf
                else
                    ; Fallback if not in actor (shouldn't happen if C++ ran)
                    chest.AddItem(items[i], 1, true)
                endif
                if isCatalog
                    SeverActionsNative.Native_OutfitSlot_AddCatalogSupplied(akActor, presetIdx, items[i])
                    catalogTagged += 1
                endif
            else
                ; User-owned: marker copy into the chest, actor untouched.
                chest.AddItem(items[i], 1, true)
                userOwnedTagged += 1
            endif

            committedItems[committed] = items[i]
            committed += 1
        endif
        i += 1
    EndWhile

    Log("BuildPreset: " + akActor.GetDisplayName() + " slot=" + slotIdx + " preset=" + presetIdx + " '" + normalizedName + "' (" + committed + " items: " + catalogTagged + " catalog, " + userOwnedTagged + " user-owned, " + playerWorkSparedBuild + " player-modified kept)")

    PopulateLvlItemFromContainer(slotIdx, presetIdx)

    SeverActionsNative.Native_OutfitSlot_SetPresetName(akActor, presetIdx, normalizedName)
    SeverActionsNative.Native_OutfitSlot_SetPresetItemCount(akActor, presetIdx, committed)

    ; Mirror the COMMITTED slice to the legacy stores (a migration backup).
    MirrorPresetToLegacyStores(akActor, normalizedName, committedItems, committed)

    ; End the owned suspend before the re-apply, which takes its own (one owner
    ; per actor). After an active preset's cleanup, keep a 2 s grace for the
    ; alias handlers still queued for its unequips.
    if wasActive
        _EndOwnedOutfitOp(akActor, opToken, 2000)
    else
        _EndOwnedOutfitOp(akActor, opToken, 0)
    endif

    ; Re-apply an overwritten active preset so the new outfit shows at once.
    if wasActive && committed > 0
        Log("BuildPreset: re-applying preset " + presetIdx + " - was active before overwrite")
        ApplyPresetBySlot(akActor, presetIdx)
    elseif wasActive
        ; The worn preset was overwritten with nothing: give the base back the
        ; DefaultOutfit its apply parked. Stowed guardians stay stowed until a
        ; clear or the next apply.
        SeverActionsNativeExt2.Native_Outfit_ReleaseDefaultOutfitSuppression(akActor)
    endif

    ; Refresh the Outfits page: the frontend's 1 s post-save refresh fires
    ; before this returns (2+ s with the re-apply) and would show stale counts.
    SeverActionsNative.Magelight_RefreshPage("outfits")

    return committed
EndFunction

Function MirrorPresetToLegacyStores(Actor akActor, String presetName, Form[] items, Int itemCount)
    {Mirror a slot-built preset to the legacy StorageUtil lists and the native
     OutfitDataStore, a backup a migration can recover from if the slot
     cosave is lost. Best-effort, silent on errors.}
    if !akActor || presetName == ""
        return
    endif

    Int actorFormID = akActor.GetFormID()
    String presetKey = "SeverOutfit_" + presetName + "_" + (actorFormID as String)

    ; Global preset-actor list
    Int trackerIdx = StorageUtil.FormListFind(None, "SeverOutfit_PresetActors", akActor)
    if trackerIdx < 0
        StorageUtil.FormListAdd(None, "SeverOutfit_PresetActors", akActor, false)
    endif

    ; Per-actor name list — add if not present
    String perActorNames = "SeverOutfit_Presets_" + (actorFormID as String)
    Int nameIdx = StorageUtil.StringListFind(None, perActorNames, presetName)
    if nameIdx < 0
        StorageUtil.StringListAdd(None, perActorNames, presetName, false)
    endif

    ; Per-preset item FormList — clear and repopulate from items
    StorageUtil.FormListClear(None, presetKey)
    Int i = 0
    While i < itemCount
        if items[i]
            StorageUtil.FormListAdd(None, presetKey, items[i], false)
        endif
        i += 1
    EndWhile

    ; Native OutfitDataStore mirror (so Native_Outfit_GetActorsWithPresets sees this actor)
    SeverActions_Outfit outfitSys = GetOutfitScript()
    if outfitSys
        outfitSys.SavePresetToNativeStore(akActor, presetName, items, itemCount)
    endif
EndFunction

Function RemovePresetItemsFromActor(Actor akActor, Int slotIdx, Int presetIdx)
    {Swap-out / clear take-back of one preset, ownership-aware: a
     catalog-supplied item loses ONE plain copy (the chest keeps the source),
     a user-owned item is only unequipped, a blacklisted or Devious Devices
     item is not touched (a catalog copy of it stays in the pack). Catalog
     flags are per (actor, preset, FormID) in OutfitSlotStore; an unflagged
     item counts as user-owned (the safe default).}
    if !akActor || slotIdx < 0 || presetIdx < 0 || presetIdx >= 8
        return
    endif

    ObjectReference chest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, presetIdx)
    if !chest
        return
    endif

    ; The chest's distinct forms are the preset items.
    Int n = chest.GetNumItems()
    Int deletedCatalog = 0
    Int playerWorkSpared = 0
    Int unequippedUserOwned = 0
    Int blacklistSkipped = 0
    Int i = 0
    While i < n
        Form item = chest.GetNthForm(i)
        if item
            Int npcHas = akActor.GetItemCount(item)
            if npcHas > 0
                if SeverActionsNative.Native_Blacklist_IsBlacklisted(item) || SeverActionsNativeExt.Native_IsDeviousDevice(item)
                    ; Never delete or unequip. For Devious Devices, removing the
                    ; rendered item outside the DD framework desyncs it from its
                    ; locked token (invisible but still locked).
                    blacklistSkipped += 1
                else
                    Bool isCatalog = SeverActionsNative.Native_OutfitSlot_IsCatalogSupplied(akActor, presetIdx, item)
                    if isCatalog
                        ; Catalog temp copy. Unequip-now first: RemoveItem's implicit
                        ; unequip can defer under menu pause.
                        if akActor.IsEquipped(item)
                            SeverActionsNativeExt.Native_UnequipItemNow(akActor, item)
                        endif
                        ; NEVER Actor.RemoveItem: the catalog tag is a bare FormID,
                        ; the player's enchanted/tempered/renamed copy shares the
                        ; base form, and RemoveItem cannot choose the stack.
                        ; RemovePlainCopies takes only unmodified copies.
                        If SeverActionsNativeExt2.RemovePlainCopies(akActor, item, 1, None) > 0
                            deletedCatalog += 1
                        Else
                            ; Only player-modified copies left: nothing taken. The
                            ; tag stays (it is per FormID and the clear is
                            ; whole-list); the next teardown spares it again.
                            playerWorkSpared += 1
                        EndIf
                    else
                        ; User-owned: unequip only. MUST be the pause-safe native:
                        ; Papyrus UnequipItem defers under menu pause and fires at
                        ; menu CLOSE, stripping whatever preset was re-applied meanwhile.
                        if akActor.IsEquipped(item)
                            SeverActionsNativeExt.Native_UnequipItemNow(akActor, item)
                        endif
                        unequippedUserOwned += 1
                    endif
                endif
            endif
        endif
        i += 1
    EndWhile

    if deletedCatalog > 0 || unequippedUserOwned > 0 || blacklistSkipped > 0 || playerWorkSpared > 0
        Log("RemovePresetItemsFromActor: preset " + presetIdx + " - deleted " + deletedCatalog + " catalog temp copies, unequipped " + unequippedUserOwned + " user-owned items, spared " + playerWorkSpared + " player-modified, preserved " + blacklistSkipped + " blacklisted items (chest preserved)")
    endif
EndFunction

Function PopulateLvlItemFromContainer(Int slotIdx, Int presetIdx)
    {Rebuild the preset's LeveledItem from its chest (one of each). Vestigial
     ESP scaffolding: DirectEquipPreset reads the chest, never this.}
    LeveledItem lvl = SeverActionsNative.Native_OutfitSlot_GetLvlItem(slotIdx, presetIdx)
    ObjectReference chest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, presetIdx)
    if !lvl || !chest
        return
    endif

    lvl.Revert()

    Int n = chest.GetNumItems()
    Int i = 0
    While i < n
        Form item = chest.GetNthForm(i)
        if item
            lvl.AddForm(item, 1, 1)   ; level=1, count=1 (NFF pattern)
        endif
        i += 1
    EndWhile
EndFunction

Function RepopulateAllLvlItemsForActor(Actor akActor)
    {Rebuild all 8 preset LvlItems from their chests (Maintenance, every load).
     Vestigial scaffolding (see PopulateLvlItemFromContainer). A no-op without
     a slot.}
    if !akActor
        return
    endif
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        return
    endif

    Int p = 0
    While p < 8
        if SeverActionsNative.Native_OutfitSlot_GetPresetItemCount(akActor, p) > 0
            PopulateLvlItemFromContainer(slotIdx, p)
        endif
        p += 1
    EndWhile
EndFunction

; === PRESET APPLY ===

Function ApplyPresetBySlot(Actor akActor, Int presetIdx)
    {Apply a preset via the wardrobe pattern (no SetOutfit): stow guardians,
     take the outgoing preset off, DirectEquipPreset (native strip + equip +
     verify, marks the preset active if anything went on), then sync the
     OutfitDataStore name tracker. A zero equip runs the naked recovery.}
    if !akActor || akActor.IsDead() || presetIdx < 0 || presetIdx >= 8
        Log("ApplyPresetBySlot: Bad input (akActor=" + akActor + " presetIdx=" + presetIdx + ")")
        return
    endif

    Log("ApplyPresetBySlot: ENTER actor=" + akActor.GetDisplayName() + " presetIdx=" + presetIdx)

    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        slotIdx = AssignSlotToActor(akActor)
        if slotIdx < 0
            Log("ApplyPresetBySlot: Cannot assign slot for " + akActor.GetDisplayName())
            return
        endif
    endif

    Outfit presetOutfit = SeverActionsNative.Native_OutfitSlot_GetOutfitForm(slotIdx, presetIdx)
    if !presetOutfit
        Log("ApplyPresetBySlot: No outfit record for slot=" + slotIdx + " preset=" + presetIdx)
        return
    endif

    Int storedItemCount = SeverActionsNative.Native_OutfitSlot_GetPresetItemCount(akActor, presetIdx)
    if storedItemCount == 0
        Log("ApplyPresetBySlot: Preset " + presetIdx + " has 0 stored items, refusing to apply naked outfit")
        return
    endif

    ; The cached count can be stale (chest gone or emptied). DirectEquipPreset
    ; refuses an empty chest too, but refusing HERE keeps the guardian stow and
    ; the outgoing teardown from running for an apply that cannot dress anyone.
    ObjectReference verifyChest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, presetIdx)
    if !verifyChest
        Log("ApplyPresetBySlot: Container ref is None for slot=" + slotIdx + " preset=" + presetIdx + " (cached count=" + storedItemCount + ") - refusing to apply ghost preset")
        return
    endif
    Int actualNumItems = verifyChest.GetNumItems()
    if actualNumItems <= 0
        Log("ApplyPresetBySlot: Container is empty (cached count=" + storedItemCount + ") for slot=" + slotIdx + " preset=" + presetIdx + " - refusing to apply ghost preset")
        return
    endif
    Log("ApplyPresetBySlot: Found preset record (storedCount=" + storedItemCount + ", containerActual=" + actualNumItems + ") for slot=" + slotIdx + " preset=" + presetIdx)

    Int currentActive = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)

    ; Owned suspend over the swap (see _BeginOwnedOutfitOp). No Return between
    ; here and its end; every refusal is above.
    Int opToken = _BeginOwnedOutfitOp(akActor)

    ; Stow guardian containers (e.g. Daegon's custom outfit container) so their
    ; alias stops fighting the equip. Runs on EVERY apply: the stow is
    ; idempotent per guardian, never keyed on the active index (-1 after an
    ; ad-hoc op, an overwrite or a zero equip with guardians still stowed).
    ; The actor's other armor is NOT stashed: DirectEquipPreset's strip leaves
    ; it in their visible inventory, with no per-item Papyrus unequips to
    ; start NPC auto-equip races.
    StowGuardianContainers(akActor, slotIdx)

    ; Switching presets: take the outgoing (possibly partial) preset's copies
    ; back. Guardians stay stowed until a full clear.
    if currentActive >= 0 && currentActive != presetIdx
        RemovePresetItemsFromActor(akActor, slotIdx, currentActive)
    endif

    ; Clear the legacy mirror at swap start; it is set again below only when
    ; the native marked the preset active (DirectEquipPreset resets and re-sets
    ; the native index itself).
    StorageUtil.UnsetIntValue(akActor, KEY_PRESET_ACTIVE)

    ; No SetOutfit here, blank or preset (see the script header).

    ; DirectEquipPreset: snapshots the chest, strips all worn armor (blacklisted
    ; and devious pieces kept) and equips each item ownership-aware - a catalog
    ; item is granted one plain copy only if the actor holds none, a user-owned
    ; item equips the actor's copy (a missing one gets a catalog copy and is
    ; promoted). Synchronous, verifies IsWorn, never touches the chest. Returns
    ; -1 hard error (no chest / no equip manager / empty chest / an apply in
    ; flight), 0 nothing equipped, < expected partial, == expected success; a
    ; re-apply of the active, un-held preset already worn in full returns the
    ; full count and touches nothing.
    ;
    ; First snapshot what the actor holds of each chest item, so a zero-equip
    ; recovery takes back only what this apply GRANTED. After the outgoing
    ; teardown on purpose: it does not spare the incoming preset's items, so an
    ; earlier snapshot would count copies it just took as held.
    Int grantN = verifyChest.GetNumItems()
    if grantN > 128
        grantN = 128
    endif
    Form[] grantItems = Utility.CreateFormArray(grantN)
    Int[] grantBefore = Utility.CreateIntArray(grantN)
    Int gi = 0
    While gi < grantN
        Form gForm = verifyChest.GetNthForm(gi)
        grantItems[gi] = gForm
        if gForm
            grantBefore[gi] = akActor.GetItemCount(gForm)
        endif
        gi += 1
    EndWhile

    Int verifiedEquipped = SeverActionsNative.Native_OutfitSlot_DirectEquipPreset(akActor, presetIdx)
    Log("ApplyPresetBySlot: DirectEquipPreset verifiedEquipped=" + verifiedEquipped + " expected=" + storedItemCount)

    ; End the owned suspend with a 2 s grace: the OutfitAlias handlers for the
    ; apply's own strips and equips are still queued and must read "suspended"
    ; (a plain ResumeOutfitLock clears the deadline, so they count as external
    ; unequips: burst suppression or a second apply). Before the result
    ; branches, so the zero-equip teardown's owned suspend is not nested.
    _EndOwnedOutfitOp(akActor, opToken, 2000)

    String presetName = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, presetIdx)

    ; A short count is a blacklist-overlap skip (expected) or an engine slot
    ; cascade. > 0 = applied, full or partial (the native marked it active);
    ; 0 = the actor is naked, recover; < 0 = hard failure, not marked active.
    if verifiedEquipped > 0
        ; Mirror the native index: active once anything went on, partial included.
        StorageUtil.SetIntValue(akActor, KEY_PRESET_ACTIVE, 1)
        if verifiedEquipped == storedItemCount
            Log("Applied preset " + presetIdx + " ('" + presetName + "') to " + akActor.GetDisplayName() + " (" + verifiedEquipped + "/" + storedItemCount + " items equipped) [OK]")
        else
            Log("Applied preset " + presetIdx + " ('" + presetName + "') to " + akActor.GetDisplayName() + " (" + verifiedEquipped + "/" + storedItemCount + " items - slot conflicts or blacklist filtered the rest) [partial - marked active]")
        endif
    elseif verifiedEquipped < 0
        ; Not marked active; the actor stays as they are and the user can retry.
        Log("ApplyPresetBySlot: HARD FAILURE applying '" + presetName + "' to " + akActor.GetDisplayName() + " - DirectEquip returned " + verifiedEquipped + " - preset NOT marked active")
    else
        ; Zero equip: the actor is naked, the native index is already -1 and
        ; the copies are in their pack. Tear down BY INDEX (ClearPreset would
        ; find nothing active). A FRESH or SWAPPED apply takes back only what it
        ; GRANTED, so a gift of the same base form survives; a RE-APPLY of the
        ; already-active preset takes back by tag, since its copies predate the
        ; snapshot and nothing will key on the preset once the index is -1.
        ; The native twin (OutfitSlot_ApplyPresetByName) makes the same split.
        Log("ApplyPresetBySlot: ZERO-EQUIP failure for '" + presetName + "' on " + akActor.GetDisplayName() + " - restoring default outfit (preset NOT marked active)")
        _TeardownPresetForIdx(akActor, slotIdx, presetIdx, currentActive != presetIdx, grantItems, grantBefore)
    endif

    ; Keep OutfitDataStore's name tracker (SituationMonitor's "already
    ; wearing" test, outfit_context, delete) in step with the slot index, with
    ; the stored name. Another preset still active means the apply was refused
    ; (one in flight) and the old name is still true.
    Int activeNow = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
    if activeNow == presetIdx
        SeverActionsNative.Native_Outfit_SetActivePreset(akActor, presetName)
    elseif activeNow < 0
        SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")
    endif
EndFunction

Function ClearPreset(Actor akActor)
    {Return the actor to their original outfit: tears down the active preset
     (_ClearPresetForIdx). A no-op when no preset is active.}
    if !akActor
        return
    endif

    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        return
    endif

    Int active = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
    if active < 0
        return  ; already cleared
    endif

    _ClearPresetForIdx(akActor, slotIdx, active)
EndFunction

Function _ClearPresetForIdx(Actor akActor, Int slotIdx, Int presetIdx)
    {Tag-based teardown of presetIdx (_TeardownPresetForIdx). Caller:
     ClearPreset. Keep the signature: a save can hold a suspended frame that
     calls it (F7).}
    Form[] noItems
    Int[] noCounts
    _TeardownPresetForIdx(akActor, slotIdx, presetIdx, false, noItems, noCounts)
EndFunction

Function _TeardownPresetForIdx(Actor akActor, Int slotIdx, Int presetIdx, Bool abGrantedOnly, Form[] akGranted, Int[] aiHeldBefore)
    {Tear down presetIdx whether or not it is still marked active: take its
     copies back, restore guardians and satchel, restore the original outfit,
     release the parked DefaultOutfit. abGrantedOnly False = take back by
     catalog tag (RemovePresetItemsFromActor); True = only what a failed apply
     granted (_TakeBackGrantedCopies over akGranted / aiHeldBefore). Callers:
     _ClearPresetForIdx and ApplyPresetBySlot's zero-equip recovery. Runs from
     the PAUSED wardrobe too, so nothing may block on the pause (WaitMenuMode,
     pause-safe unequips); one owned suspend covers it all, no Return inside.}
    if !akActor || slotIdx < 0 || presetIdx < 0 || presetIdx >= 8
        return
    endif

    Int opToken = _BeginOwnedOutfitOp(akActor)

    ; Un-mark FIRST: a second Delete or Clear click landing meanwhile finds
    ; nothing active instead of eating more plain copies.
    SeverActionsNative.Native_OutfitSlot_SetActivePreset(akActor, -1)
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")
    StorageUtil.SetIntValue(akActor, KEY_PRESET_ACTIVE, 0)

    ; Take the preset's items off before breaking the outfit.
    if abGrantedOnly
        _TakeBackGrantedCopies(akActor, akGranted, aiHeldBefore)
    else
        RemovePresetItemsFromActor(akActor, slotIdx, presetIdx)
    endif

    ; SaveOriginalOutfit falls back to the DefaultOutfit OutfitDataStore parked
    ; and never records Blank or Naked. Without an original, NO SetOutfit at
    ; all: the blank outfit is only a step toward it, and left on the base it
    ; writes an empty DefaultOutfit into the save.
    Outfit origOutfit = SeverActionsNative.Native_OutfitSlot_GetOriginalOutfit(akActor)

    ; Break current outfit enforcement
    Outfit blankOutfit = SeverActionsNative.Native_OutfitSlot_GetBlankOutfit()
    if origOutfit && blankOutfit
        akActor.SetOutfit(blankOutfit, false)
    endif
    Utility.WaitMenuMode(0.1)
    ; Strip everything EXCEPT blacklisted items (UnequipAll takes no filter).
    UnequipAllExceptBlacklisted(akActor)
    Utility.WaitMenuMode(0.1)

    ; ORDER MATTERS: guardians restore from the satchel first, then
    ; RestoreSatchelToActor drains the rest wholesale into the actor's pack.
    RestoreGuardianContainers(akActor, slotIdx)

    RestoreSatchelToActor(akActor, slotIdx)

    ; Restore original outfit if we have one saved
    if origOutfit
        akActor.SetOutfit(origOutfit, false)
    endif

    Outfit origSleep = SeverActionsNative.Native_OutfitSlot_GetOriginalSleepOutfit(akActor)
    if origSleep
        akActor.SetOutfit(origSleep, true)   ; sleep outfit
    endif

    ; Release the DefaultOutfit the apply parked in OutfitDataStore, so the load
    ; pass stops re-nulling the base. Refused while a legacy lock or slot preset
    ; is active - hence after the index went to -1.
    SeverActionsNativeExt2.Native_Outfit_ReleaseDefaultOutfitSuppression(akActor)

    ; 2 s grace for the alias handlers queued by the strip and the SetOutfits.
    _EndOwnedOutfitOp(akActor, opToken, 2000)

    Log("Cleared preset " + presetIdx + " from " + akActor.GetDisplayName())
EndFunction

Int Function _TakeBackGrantedCopies(Actor akActor, Form[] akItems, Int[] aiHeldBefore)
    {Zero-equip take-back after a FRESH apply: for each chest item the actor
     held none of before (aiHeldBefore[i] == 0) and holds now, unequip it
     (pause-safe) and remove ONE plain copy - DirectEquipPreset grants exactly
     one, only to an actor holding none. No blacklist or device filter, like
     the native twin. Returns the count taken.}
    if !akActor || !akItems || !aiHeldBefore
        return 0
    endif
    Int n = akItems.Length
    if aiHeldBefore.Length < n
        n = aiHeldBefore.Length
    endif
    Int taken = 0
    Int i = 0
    While i < n
        Form item = akItems[i]
        if item && aiHeldBefore[i] == 0 && akActor.GetItemCount(item) > 0
            if (item as Armor) && akActor.IsEquipped(item)
                SeverActionsNativeExt.Native_UnequipItemNow(akActor, item)
            endif
            taken += SeverActionsNativeExt2.RemovePlainCopies(akActor, item, 1, None)
        endif
        i += 1
    EndWhile
    Log("_TakeBackGrantedCopies: took back " + taken + " granted cop(ies) from " + akActor.GetDisplayName())
    return taken
EndFunction

Int Function _BeginOwnedOutfitOp(Actor akActor)
    {Begin a long outfit op with an OWNED suspend: untokened resumes (the
     menu-close OnPrismaResumeLock, the pane's resume, ResumeOutfitLock and
     ResumeOutfitLockKeepGrace) leave the actor suspended; only
     _EndOwnedOutfitOp with the returned token (or the 5-minute watchdog) ends
     it. Token 0 = an older DLL: the plain suspend is taken. One owner per
     actor - a second begin replaces the first, so end yours before calling
     another op.}
    Int tok = SeverActionsNativeExt2.Native_Outfit_SuspendLockOwned(akActor)
    if tok == 0
        SeverActionsNativeExt.Native_Outfit_SuspendLock(akActor)
    endif
    return tok
EndFunction

Function _EndOwnedOutfitOp(Actor akActor, Int aiToken, Int aiGraceMs)
    {End a _BeginOwnedOutfitOp op: drop the owned suspend with a grace of
     aiGraceMs ms (0 = none; 2000 after strips or equips), then clear the
     burst state. A token another op has replaced is refused (logged). Token 0
     (older DLL) takes the plain resume with the same grace.}
    if aiToken != 0
        if !SeverActionsNativeExt2.Native_Outfit_ResumeLockOwned(akActor, aiToken, aiGraceMs)
            Log("_EndOwnedOutfitOp: a newer op owns the outfit suspend of " + akActor.GetDisplayName() + " - left it in place for that op to end")
        endif
    elseif aiGraceMs > 0
        SeverActionsNativeExt2.Native_Outfit_ResumeLockKeepGrace(akActor, aiGraceMs)
    else
        SeverActionsNativeExt.Native_Outfit_ResumeLock(akActor)
    endif
    SeverActionsNative.Native_Outfit_ClearBurstSuppression(akActor)
EndFunction

; === GUARDIAN CONTAINERS ===
; For custom followers whose mod enforces an outfit via a container-backed
; guardian alias (e.g. Daegon's k101DaegonCustomOutfitContainer).

Function RegisterGuardianContainer(Actor akActor, ObjectReference guardianContainer)
    {Register a guardian container for an actor. If the actor doesn't have a
     slot yet, they'll be assigned one. Safe to call multiple times.}
    if !akActor || !guardianContainer
        return
    endif
    Int slotIdx = AssignSlotToActor(akActor)
    if slotIdx < 0
        Log("RegisterGuardianContainer: No slot for " + akActor.GetDisplayName())
        return
    endif
    Bool added = SeverActionsNative.Native_OutfitSlot_AddGuardian(akActor, guardianContainer)
    if added
        Log("Registered guardian container " + guardianContainer.GetFormID() + " for " + akActor.GetDisplayName())
    endif
EndFunction

Function UnregisterGuardianContainer(Actor akActor, ObjectReference guardianContainer)
    {Unregister a guardian container, first moving its stowed items back from
     the satchel - unrouted, a later clear would dump them into the actor's pack.}
    if !akActor || !guardianContainer
        return
    endif

    ; Step 1: Read this guardian's stowed-items list (FormIDs).
    Form[] stowedItems = SeverActionsNative.Native_OutfitSlot_GetStowedItems(akActor, guardianContainer)
    if stowedItems && stowedItems.Length > 0
        ; Step 2: Find the satchel and move stowed items back to the guardian.
        Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
        if slotIdx >= 0
            ObjectReference satchel = SeverActionsNative.Native_OutfitSlot_GetSatchel(slotIdx)
            if satchel
                Int restored = 0
                Int i = 0
                While i < stowedItems.Length
                    Form item = stowedItems[i]
                    if item
                        Int satchelHas = satchel.GetItemCount(item)
                        if satchelHas > 0
                            ; Every copy: the stow moved whole stacks and
                            ; recorded distinct forms.
                            satchel.RemoveItem(item, satchelHas, true, guardianContainer)
                            restored += satchelHas
                        endif
                    endif
                    i += 1
                EndWhile
                if restored > 0
                    Log("UnregisterGuardianContainer: restored " + restored + " items from satchel back to guardian " + guardianContainer.GetFormID())
                endif
            endif
        endif
        ; Step 3: Clear the per-guardian stowed-items metadata.
        SeverActionsNative.Native_OutfitSlot_ClearStowedItems(akActor, guardianContainer)
    endif

    ; Step 4: Now safe to remove from the registry.
    SeverActionsNative.Native_OutfitSlot_RemoveGuardian(akActor, guardianContainer)
EndFunction

Function StowGuardianContainers(Actor akActor, Int slotIdx)
    {Empty each guardian container into the satchel and record what moved, so
     the guardian alias's "GetItemCount > 0" check fails and it stops fighting
     the preset. IDEMPOTENT: a guardian whose stowed record is non-empty is
     skipped (re-stowing would replace the record, its only route home, with
     []), and so is an empty one. ApplyPresetBySlot calls this on every apply.}
    if !akActor || slotIdx < 0
        return
    endif

    ObjectReference[] guardians = SeverActionsNative.Native_OutfitSlot_GetGuardians(akActor)
    if !guardians || guardians.Length == 0
        return
    endif

    ObjectReference satchel = EnsureSatchel(akActor, slotIdx)
    if !satchel
        Log("StowGuardianContainers: No satchel available for " + akActor.GetDisplayName())
        return
    endif

    Int g = 0
    While g < guardians.Length
        ObjectReference guardian = guardians[g]
        if guardian
            Form[] alreadyStowed = SeverActionsNative.Native_OutfitSlot_GetStowedItems(akActor, guardian)
            Int n = guardian.GetNumItems()
            if alreadyStowed && alreadyStowed.Length > 0
                Log("StowGuardianContainers: guardian " + guardian.GetFormID() + " of " + akActor.GetDisplayName() + " is already stowed (" + alreadyStowed.Length + " recorded) - left as it is")
            elseif n <= 0
                Log("StowGuardianContainers: guardian " + guardian.GetFormID() + " of " + akActor.GetDisplayName() + " is empty - nothing to stow")
            else
                ; Snapshot the guardian's contents BEFORE moving (so we know what to restore).
                Form[] stowed = Utility.CreateFormArray(n)
                Int i = 0
                While i < n
                    stowed[i] = guardian.GetNthForm(i)
                    i += 1
                EndWhile

                ; Register the snapshot BEFORE the move (OnItemRemoved cascade may mutate state)
                SeverActionsNative.Native_OutfitSlot_SetStowedItems(akActor, guardian, stowed)

                ; The guardian's OnItemRemoved (if any) also takes the items off
                ; the NPC, which breaks its alias's re-equip check.
                guardian.RemoveAllItems(satchel)

                Log("Stowed " + n + " items from guardian " + guardian.GetFormID() + " for " + akActor.GetDisplayName())
            endif
        endif
        g += 1
    EndWhile
EndFunction

Function RestoreGuardianContainers(Actor akActor, Int slotIdx)
    {Reverse of StowGuardianContainers: every stowed copy goes back to its
     guardian, and the actor gets one plain copy of each piece they hold none
     of (Daegon's re-equip needs both her and the container to hold it).
     Keyed on each guardian's stowed record, not the active index, so it also
     restores guardians left stowed with no preset active.}
    if !akActor || slotIdx < 0
        return
    endif

    ObjectReference[] guardians = SeverActionsNative.Native_OutfitSlot_GetGuardians(akActor)
    if !guardians || guardians.Length == 0
        return
    endif

    ObjectReference satchel = SeverActionsNative.Native_OutfitSlot_GetSatchel(slotIdx)
    if !satchel
        Log("RestoreGuardianContainers: No satchel for " + akActor.GetDisplayName())
        return
    endif

    Int g = 0
    While g < guardians.Length
        ObjectReference guardian = guardians[g]
        if guardian
            Form[] stowed = SeverActionsNative.Native_OutfitSlot_GetStowedItems(akActor, guardian)
            if stowed && stowed.Length > 0
                Int i = 0
                Int restored = 0
                While i < stowed.Length
                    Form item = stowed[i]
                    if item
                        Int countInSatchel = satchel.GetItemCount(item)
                        if countInSatchel > 0
                            ; EVERY copy: the stow moved whole stacks but recorded
                            ; distinct forms. The guardian's OnItemAdded may filter
                            ; (Daegon's keeps one of each armor form).
                            satchel.RemoveItem(item, countInSatchel, true, guardian)
                            ; One plain copy to the actor only if they hold none
                            ; (the stow's propagation took theirs), as the guardian
                            ; mod's own EquipCustomOutfit does.
                            if akActor.GetItemCount(item) == 0
                                akActor.AddItem(item, 1, true)
                            endif
                            restored += countInSatchel
                        endif
                    endif
                    i += 1
                EndWhile
                if restored > 0
                    Log("Restored " + restored + " items to guardian " + guardian.GetFormID() + " for " + akActor.GetDisplayName())
                endif
                SeverActionsNative.Native_OutfitSlot_ClearStowedItems(akActor, guardian)
            endif
        endif
        g += 1
    EndWhile
EndFunction

; === SATCHEL ===

Function RestoreSatchelToActor(Actor akActor, Int slotIdx)
    {Dump satchel contents back to the actor's inventory (the preset teardown).}
    if !akActor || slotIdx < 0
        return
    endif
    ObjectReference satchel = SeverActionsNative.Native_OutfitSlot_GetSatchel(slotIdx)
    if !satchel
        return
    endif
    if satchel.GetNumItems() > 0
        satchel.RemoveAllItems(akActor)
        Log("Restored satchel contents to " + akActor.GetDisplayName())
    endif
EndFunction

; === NAME <-> INDEX (LLM-facing API) ===

Int Function FindPresetIndexByName(Actor akActor, String name)
    {Preset index 0-7 by name, or -1. Tier 1: exact match with both sides
     lowercased (a BSFixedString can come back re-cased). Tier 2: token
     overlap after stopword filtering, by bidirectional prefix ("sexy" ~
     "sexy01"); several matches pick one at RANDOM, so presets named
     sexy01/sexy02/... roll variety.}
    if !akActor || name == ""
        Log("FindPresetIndexByName: bad input akActor=" + akActor + " name='" + name + "'")
        return -1
    endif
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        Log("FindPresetIndexByName: actor " + akActor.GetDisplayName() + " has no slot (looking for '" + name + "')")
        return -1
    endif

    String queryLower = SeverActionsNative.StringToLower(name)

    ; Build a debug dump of the actor's slot names once for all log paths.
    String dump = "slot=" + slotIdx + " names=["
    Int dp = 0
    While dp < 8
        String dexisting = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, dp)
        dump = dump + "'" + dexisting + "'"
        if dp < 7
            dump = dump + ","
        endif
        dp += 1
    EndWhile
    dump = dump + "]"

    ; --- Tier 1: exact CI match (always preferred over fuzzy) ---
    Int p = 0
    While p < 8
        String existing = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, p)
        String existingLower = SeverActionsNative.StringToLower(existing)
        if existingLower == queryLower && existingLower != ""
            Log("FindPresetIndexByName: " + akActor.GetDisplayName() + " '" + name + "' -> idx " + p + " (exact match) " + dump)
            return p
        endif
        p += 1
    EndWhile

    ; --- Tier 2: token-overlap fuzzy match ---
    String[] queryTokens = TokenizeAndFilter(queryLower)
    if CountNonEmptyTokens(queryTokens) == 0
        Log("FindPresetIndexByName: " + akActor.GetDisplayName() + " '" + name + "' NOT FOUND (no usable query tokens after stopword filter) " + dump)
        return -1
    endif

    Int[] candidates = new Int[8]
    Int candidateCount = 0
    p = 0
    While p < 8
        String existing = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, p)
        if existing != ""
            String existingLower = SeverActionsNative.StringToLower(existing)
            String[] presetTokens = TokenizeAndFilter(existingLower)
            if AnyTokenOverlap(queryTokens, presetTokens)
                candidates[candidateCount] = p
                candidateCount += 1
            endif
        endif
        p += 1
    EndWhile

    if candidateCount == 0
        Log("FindPresetIndexByName: " + akActor.GetDisplayName() + " '" + name + "' NOT FOUND (no fuzzy candidates) " + dump)
        return -1
    endif

    if candidateCount == 1
        Log("FindPresetIndexByName: " + akActor.GetDisplayName() + " '" + name + "' -> idx " + candidates[0] + " (fuzzy single match) " + dump)
        return candidates[0]
    endif

    ; Several candidates: roll one (variety pack).
    Int pick = Utility.RandomInt(0, candidateCount - 1)
    String dumpCandidates = ""
    Int ci = 0
    While ci < candidateCount
        dumpCandidates = dumpCandidates + candidates[ci]
        if ci < candidateCount - 1
            dumpCandidates = dumpCandidates + ","
        endif
        ci += 1
    EndWhile
    Log("FindPresetIndexByName: " + akActor.GetDisplayName() + " '" + name + "' -> idx " + candidates[pick] + " (fuzzy random pick from [" + dumpCandidates + "]) " + dump)
    return candidates[pick]
EndFunction

Int Function FindPresetIndexExact(Actor akActor, String name)
    {Tier 1 of FindPresetIndexByName only (exact, case-insensitive; no fuzzy
     tier, no random pick), or -1. Use it for DESTRUCTIVE or IDENTITY ops
     (delete, the migration existence probe): the fuzzy tier could resolve
     "casual" to "casualwear" and delete the wrong chest or skip a migration.}
    if !akActor || name == ""
        return -1
    endif
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        return -1
    endif
    String queryLower = SeverActionsNative.StringToLower(name)
    Int p = 0
    While p < 8
        String existing = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, p)
        String existingLower = SeverActionsNative.StringToLower(existing)
        if existingLower == queryLower && existingLower != ""
            return p
        endif
        p += 1
    EndWhile
    return -1
EndFunction

String[] Function TokenizeAndFilter(String s)
    {Split a lowercased string on spaces, dropping filler tokens (IsFillerToken),
     for FindPresetIndexByName's fuzzy tier. Returns a fixed 8-slot array (tokens
     past the eighth are dropped); unused slots are "" and callers must skip them.}
    String[] result = new String[8]
    if s == ""
        return result
    endif
    Int writeIdx = 0
    Int start = 0
    Int len = StringUtil.GetLength(s)
    Int i = 0
    While i <= len && writeIdx < 8
        Bool atEnd = (i == len)
        Bool atSpace = false
        if !atEnd
            atSpace = (StringUtil.GetNthChar(s, i) == " ")
        endif
        if atEnd || atSpace
            if i > start
                String tok = StringUtil.Substring(s, start, i - start)
                if !IsFillerToken(tok)
                    result[writeIdx] = tok
                    writeIdx += 1
                endif
            endif
            start = i + 1
        endif
        i += 1
    EndWhile
    return result
EndFunction

Bool Function IsFillerToken(String tok)
    {True for stopwords LLMs wrap requests in and tokens under 3 chars, which
     would produce spurious prefix matches.}
    if tok == ""
        return true
    endif
    if StringUtil.GetLength(tok) < 3
        return true
    endif
    if tok == "the" || tok == "your" || tok == "for" || tok == "and"
        return true
    endif
    if tok == "some" || tok == "something" || tok == "wear" || tok == "put"
        return true
    endif
    if tok == "her" || tok == "his" || tok == "their" || tok == "ours"
        return true
    endif
    return false
EndFunction

Int Function CountNonEmptyTokens(String[] arr)
    Int n = 0
    Int i = 0
    While i < arr.Length
        if arr[i] != ""
            n += 1
        endif
        i += 1
    EndWhile
    return n
EndFunction

Bool Function AnyTokenOverlap(String[] a, String[] b)
    {True if a non-empty token of `a` is a prefix of one in `b`, or the reverse
     ("sexy" and "sexy01" match either way). StringUtil.Find == 0 is the prefix test.}
    Int ai = 0
    While ai < a.Length
        if a[ai] != ""
            Int bi = 0
            While bi < b.Length
                if b[bi] != ""
                    if StringUtil.Find(b[bi], a[ai]) == 0
                        return true
                    endif
                    if StringUtil.Find(a[ai], b[bi]) == 0
                        return true
                    endif
                endif
                bi += 1
            EndWhile
        endif
        ai += 1
    EndWhile
    return false
EndFunction

Int Function FindFreeOrReusableIndex(Actor akActor, String name)
    {Preset index to save into: the preset with the same name (case-insensitive,
     so a re-cased BSFixedString cannot take a second index), else the first
     empty one, else -1. Assigns the actor a slot if they have none.}
    if !akActor
        return -1
    endif
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        slotIdx = AssignSlotToActor(akActor)
        if slotIdx < 0
            return -1
        endif
    endif

    String queryLower = SeverActionsNative.StringToLower(name)
    Int p = 0
    While p < 8
        String existing = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, p)
        if existing != ""
            String existingLower = SeverActionsNative.StringToLower(existing)
            if existingLower == queryLower
                return p
            endif
        endif
        p += 1
    EndWhile

    p = 0
    While p < 8
        String existing = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, p)
        if existing == ""
            return p
        endif
        p += 1
    EndWhile

    return -1
EndFunction

Bool Function DeletePresetFromSlot(Actor akActor, String presetName)
    {Delete a preset by exact, case-insensitive name: tear it down if active
     (ClearPreset), destroy its chest, revert its LvlItem, drop its StorageUtil
     mirror and clear its metadata and situation mappings. False if not found.}
    if !akActor || presetName == ""
        return false
    endif

    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        return false
    endif

    ; Exact match: a fuzzy hit would destroy a same-prefix sibling's chest (N3).
    Int presetIdx = FindPresetIndexExact(akActor, presetName)
    if presetIdx < 0
        return false
    endif

    ; Tear an active preset down first (copies back, original outfit restored),
    ; or its worn catalog copies outlive the chest. The slot store's index is
    ; the truth (every apply sets it, every teardown clears it); OutfitDataStore's
    ; name tracker can lag.
    Int activeIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
    if activeIdx == presetIdx
        ClearPreset(akActor)
    endif

    ; Destroy the chest's contents (None destination): they mix catalog sources
    ; with markers for items the actor already owns, so dumping them to the
    ; player would duplicate items.
    ObjectReference chest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, presetIdx)
    if chest
        if chest.GetNumItems() > 0
            chest.RemoveAllItems(None)
        endif
        chest.Delete()
        SeverActionsNative.Native_OutfitSlot_SetContainerRef(akActor, presetIdx, None)
    endif

    LeveledItem lvl = SeverActionsNative.Native_OutfitSlot_GetLvlItem(slotIdx, presetIdx)
    if lvl
        lvl.Revert()
    endif

    ; Drop the StorageUtil mirror under the STORED name (BuildPreset's key;
    ; presetName may differ in case): the migration refills an empty chest from
    ; that list first, so a stale one would refill a re-created preset with the
    ; deleted one's items. Outfit.DeletePreset drops the OutfitDataStore half.
    String storedName = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, presetIdx)
    if storedName != ""
        String actorFid = akActor.GetFormID() as String
        StorageUtil.FormListClear(None, "SeverOutfit_" + storedName + "_" + actorFid)
        String namesKey = "SeverOutfit_Presets_" + actorFid
        StorageUtil.StringListRemove(None, namesKey, storedName, true)
        if StorageUtil.StringListCount(None, namesKey) <= 0
            StorageUtil.FormListRemove(None, "SeverOutfit_PresetActors", akActor, true)
        endif
    endif

    SeverActionsNative.Native_OutfitSlot_ClearPreset(akActor, presetIdx)
    ClearSituationsPointingTo(akActor, presetIdx)

    Log("DeletePresetFromSlot: removed '" + presetName + "' from slot " + slotIdx + " preset " + presetIdx + " for " + akActor.GetDisplayName())
    return true
EndFunction

Function UnequipAllExceptBlacklisted(Actor akActor)
    {Unequip every worn armor piece except blacklisted items and Devious Devices.
     Stands in for UnequipAll in the preset teardown: UnequipAll takes no filter
     and would break the "never touch blacklisted items" contract.}
    if !akActor
        return
    endif

    Form[] worn = SeverActionsNative.Native_Outfit_GetWornArmor(akActor)
    if !worn || worn.Length == 0
        return
    endif

    Int kept = 0
    Int unequipped = 0
    Int i = 0
    While i < worn.Length
        Form item = worn[i]
        if item
            ; Devious Devices are never stripped: unequipping one outside the DD
            ; framework leaves it invisible while its locked token stays.
            if SeverActionsNative.Native_Blacklist_IsBlacklisted(item) || SeverActionsNativeExt.Native_IsDeviousDevice(item)
                kept += 1
            else
                ; The pause-safe native: from the paused wardrobe (delete, Clear
                ; All Presets) a Papyrus UnequipItem fires at menu close, after
                ; the original outfit is back on. It locks nothing, so the
                ; teardown's SetOutfit still re-equips.
                SeverActionsNativeExt.Native_UnequipItemNow(akActor, item)
                unequipped += 1
            endif
        endif
        i += 1
    EndWhile

    if kept > 0
        Log("UnequipAllExceptBlacklisted: " + akActor.GetDisplayName() + " - unequipped " + unequipped + " items, preserved " + kept + " blacklisted")
    endif
EndFunction

Function ClearSituationsPointingTo(Actor akActor, Int presetIdx)
    {Unmap every situation that points at presetIdx, so the auto-switch never
     applies a deleted preset.}
    if !akActor || presetIdx < 0
        return
    endif
    String[] situations = new String[7]
    situations[0] = "adventure"
    situations[1] = "town"
    situations[2] = "home"
    situations[3] = "sleep"
    situations[4] = "combat"
    situations[5] = "rain"
    situations[6] = "snow"

    Int si = 0
    While si < situations.Length
        Int mapped = SeverActionsNative.Native_OutfitSlot_GetSituationPreset(akActor, situations[si])
        if mapped == presetIdx
            SeverActionsNative.Native_OutfitSlot_SetSituationPreset(akActor, situations[si], -1)
        endif
        si += 1
    EndWhile
EndFunction

Bool Function ClearActivePresetForAdHoc(Actor akActor)
    {Deactivate the active slot preset and take its catalog copies back (owned
     and blacklisted items stay) before a WHOLE-OUTFIT ad-hoc action, through
     SeverActions_Outfit.BeginAdHocOutfitOp: Undress, Dress with no preset held,
     the legacy ApplyOutfitPreset. A per-item change must not come here: it holds
     the preset instead (Native_OutfitSlot_HoldActivePreset).
     The chest, name, item count and ownership data stay, so the preset can be
     re-applied. Guardian containers stay stowed (a restored one would fight the
     ad-hoc op; a clear, a delete or Clear All restores them) and a parked
     DefaultOutfit stays parked for the ad-hoc op to decide.
     Returns True if a preset was deactivated.}
    if !akActor
        return false
    endif

    ; The native slot index alone is the truth; a KEY_PRESET_ACTIVE fallback
    ; would mask drift instead of resolving it.
    Int activeIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
    if activeIdx < 0
        return false
    endif

    ; Take the copies back BEFORE clearing the active index: once it is -1
    ; nothing (ApplyPresetBySlot's cleanup included) knows which preset's copies
    ; to remove, and they pile up. The lock is suspended so the alias's debounced
    ; re-apply cannot race the half-cleared inventory.
    if activeIdx >= 0
        Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
        if slotIdx >= 0
            ; SuspendOutfitLock, so the watchdog timestamp is set.
            SeverActions_Outfit outfitSysClear = GetOutfitScript()
            if outfitSysClear
                outfitSysClear.SuspendOutfitLock(akActor)
            endif
            RemovePresetItemsFromActor(akActor, slotIdx, activeIdx)
            ; Resume keeping a 2 s grace for the alias handlers that unequip loop
            ; queued; the caller (BeginAdHocOutfitOp) suspends again right after.
            SeverActionsNativeExt2.Native_Outfit_ResumeLockKeepGrace(akActor, 2000)
            SeverActionsNative.Native_Outfit_ClearBurstSuppression(akActor)
        endif
    endif

    ; Deactivate; OutfitDataStore's name tracker follows the index.
    SeverActionsNative.Native_OutfitSlot_SetActivePreset(akActor, -1)
    SeverActionsNative.Native_Outfit_SetActivePreset(akActor, "")
    StorageUtil.UnsetIntValue(akActor, KEY_PRESET_ACTIVE)

    Log("ClearActivePresetForAdHoc: deactivated slot preset " + activeIdx + " on " + akActor.GetDisplayName() + " (ad-hoc action takes over; preset chest preserved for re-apply)")
    return true
EndFunction

Bool Function IsSlotEligible(Actor akActor)
    {True if the actor should use the slot system: holds a slot, is an SA
     follower, has a non-follower outfit lock, is a player teammate (custom
     followers recruited by their own mod) or a current CurrentFollowerFaction
     member. Deliberately permissive; the outfit exclusion (checked by
     SeverActions_Outfit's entry points, not here) is how an NPC is kept out.}
    if !akActor
        return false
    endif
    if SeverActionsNative.Native_OutfitSlot_GetSlot(akActor) >= 0
        return true
    endif
    if SeverActionsNativeExt.Native_GetIsFollower(akActor)
        return true
    endif
    ; A non-follower outfit lock.
    if SeverActionsNativeExt.Native_Outfit_IsLockActive(akActor) \
        && !SeverActionsNativeExt.Native_Outfit_IsFollowerLock(akActor)
        return true
    endif
    if akActor.IsPlayerTeammate()
        return true
    endif
    ; Vanilla CurrentFollowerFaction (0x0005C84E), for a vanilla follower whose
    ; teammate flag drops while sandboxing. Rank >= 0 only, as in FollowerManager:
    ; IsInFaction is also true at the -1 a dismissed or potential follower carries.
    Faction cff = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    if cff && akActor.GetFactionRank(cff) >= 0
        return true
    endif
    return false
EndFunction

; === SITUATION INTEGRATION ===

Function OnSituationChangedForActor(Actor akActor, String situation)
    {Safe-exit stub: its only caller, SeverActions_Outfit.OnSituationChanged, is
     deleted (the auto-switch applies natively).}
    ; M-I-STUB 3.9.14-beta25 (P10-02): dead code (the Papyrus situation route is gone)
EndFunction
; === HELPERS ===

SeverActions_Outfit Function GetOutfitScript()
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Outfit
EndFunction

; === MIGRATION FROM LEGACY STORAGE (every load, per-actor sentinel) ===

Function MigrateToOutfitSlotSystem()
    {Migrate legacy presets (StorageUtil lists and OutfitDataStore) of
     slot-eligible actors into the slot system; runs on every load. Idempotent
     per preset: a name already in the slot with a filled chest is skipped, one
     with an empty chest is refilled from the legacy stores. Applies nothing:
     migrated slots start with no active preset.}
    Log("MigrateToOutfitSlotSystem: Starting incremental migration scan...")

    SeverActions_Outfit outfitSys = GetOutfitScript()
    if !outfitSys
        Log("MigrateToOutfitSlotSystem: OutfitScript not found, aborting")
        return
    endif

    ; Actors with legacy presets in either store: the native one also holds
    ; presets the C++ direct path saved before the StorageUtil mirror existed.
    Actor[] storageActors = outfitSys.GetPresetActors()
    Actor[] nativeActors = SeverActionsNative.Native_Outfit_GetActorsWithPresets()
    Actor[] presetActors = MergeActorArraysUnique(storageActors, nativeActors)
    Int migratedActors = 0
    Int migratedPresets = 0
    Int migratedSituations = 0

    Int ai = 0
    While ai < presetActors.Length
        Actor akActor = presetActors[ai]
        ; Per-actor sentinel (version 1) skips a migrated actor: BuildPreset
        ; mirrors every save into both legacy stores, so they never hold a preset
        ; the slot lacks. Not proof alone: a dropped OSLT record loses every slot
        ; while the sentinel stands, so an actor with no slot migrates again.
        ; Clearing the key forces a re-migration.
        Bool alreadyMigrated = akActor && StorageUtil.GetIntValue(akActor, "SeverActions_OutfitSlotMigDone", 0) >= 1 && SeverActionsNative.Native_OutfitSlot_GetSlot(akActor) >= 0
        ; Only a slot-eligible actor: a stranger's legacy-only preset stays legacy
        ; rather than taking a slot, an alias and chests.
        if akActor && !akActor.IsDead() && !alreadyMigrated && IsSlotEligible(akActor)
            Int slotIdx = AssignSlotToActor(akActor)
            if slotIdx >= 0
                String[] storageNames = outfitSys.GetPresetNames(akActor)
                ; Native names by index (avoids marshalling a String[] return).
                Int nativeCount = SeverActionsNative.Native_Outfit_GetPresetCount(akActor)
                String[] nativeNames = PapyrusUtil.StringArray(nativeCount)
                Int ni = 0
                While ni < nativeCount
                    nativeNames[ni] = SeverActionsNative.Native_Outfit_GetPresetNameAt(akActor, ni)
                    ni += 1
                EndWhile
                String[] names = MergeStringArraysUnique(storageNames, nativeNames)
                Int nameCount = names.Length
                Log("Migration: actor=" + akActor.GetDisplayName() + " storageNames=" + storageNames.Length + " nativeNames=" + nativeCount + " merged=" + nameCount)
                Int p = 0
                Int committedPresets = 0
                While p < nameCount && p < 8
                    String name = names[p]
                    if name != ""
                        ; Not in the slot: register the name, then commit items. In
                        ; the slot with a filled chest: done. With an EMPTY chest:
                        ; refill from the legacy stores (a dropped cosave or chest).
                        ; Exact match: a fuzzy hit on a migrated same-prefix sibling
                        ; would drop this preset (N3).
                        Int existingSlotIdx = FindPresetIndexExact(akActor, name)
                        Bool needsItemCommit = false
                        Int targetIdx = -1

                        if existingSlotIdx >= 0
                            ObjectReference existingChest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, existingSlotIdx)
                            Int existingChestNumItems = 0
                            if existingChest
                                existingChestNumItems = existingChest.GetNumItems()
                            endif
                            if existingChestNumItems == 0
                                targetIdx = existingSlotIdx
                                needsItemCommit = true
                                Log("Migration: name '" + name + "' exists at preset " + existingSlotIdx + " but chest empty - refilling from legacy mirror")
                            endif
                        else
                            ; Register the name first: it is the preset's identity, and
                            ; FindPresetIndexByName (LLM apply, the UI) must find it even
                            ; if the item commit fails.
                            targetIdx = FindFirstEmptyPresetIdx(akActor)
                            if targetIdx >= 0
                                SeverActionsNative.Native_OutfitSlot_SetPresetName(akActor, targetIdx, name)
                                Log("Migration: registered name '" + name + "' -> slot " + slotIdx + " preset " + targetIdx + " for " + akActor.GetDisplayName())
                                committedPresets += 1
                                migratedPresets += 1
                                needsItemCommit = true
                            endif
                        endif

                        if needsItemCommit && targetIdx >= 0
                            ; Item commit, best effort: the StorageUtil list first, else
                            ; the OutfitDataStore preset.
                            String presetKey = "SeverOutfit_" + name + "_" + (akActor.GetFormID() as String)
                            Int itemCount = StorageUtil.FormListCount(None, presetKey)
                            Form[] presetItems   ; no `= None`: that casts None to Form[] at runtime (B-37)
                            if itemCount > 0
                                presetItems = Utility.CreateFormArray(itemCount)
                                Int ii = 0
                                While ii < itemCount
                                    presetItems[ii] = StorageUtil.FormListGet(None, presetKey, ii)
                                    ii += 1
                                EndWhile
                            else
                                presetItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, name)
                            endif

                            Int presetItemCount = 0
                            if presetItems
                                presetItemCount = presetItems.Length
                            endif

                            if presetItemCount > 0
                                ObjectReference chest = EnsureContainer(akActor, slotIdx, targetIdx)
                                if chest
                                    ; Destroy stale contents, never dump them to the
                                    ; player (see DeletePresetFromSlot).
                                    if chest.GetNumItems() > 0
                                        chest.RemoveAllItems(None)
                                    endif
                                    Int k = 0
                                    Int committed = 0
                                    While k < presetItemCount && committed < 32
                                        Form item = presetItems[k]
                                        if item
                                            chest.AddItem(item, 1, true)
                                            committed += 1
                                        endif
                                        k += 1
                                    EndWhile
                                    PopulateLvlItemFromContainer(slotIdx, targetIdx)
                                    SeverActionsNative.Native_OutfitSlot_SetPresetItemCount(akActor, targetIdx, committed)
                                    Log("Migration: committed " + committed + " items for '" + name + "' slot=" + slotIdx + " preset=" + targetIdx)
                                else
                                    Log("Migration: EnsureContainer failed for slot=" + slotIdx + " preset=" + targetIdx + " name='" + name + "' - name registered but items not committed")
                                endif
                            elseif existingSlotIdx < 0
                                ; Registered above but no store has items: roll the name
                                ; back so a blank ghost does not hold the index
                                ; (RepairGhostPresets handles older ones).
                                SeverActionsNative.Native_OutfitSlot_ClearPreset(akActor, targetIdx)
                                committedPresets -= 1
                                migratedPresets -= 1
                                Log("Migration: no items for '" + name + "' anywhere - rolled back empty name registration (slot freed)")
                            else
                                Log("Migration: no items found for '" + name + "' in either StorageUtil or native store - name registered but items empty (user can rebuild via builder)")
                            endif
                        elseif existingSlotIdx < 0 && targetIdx < 0
                            Log("Migration: no empty preset slots available for '" + name + "' on " + akActor.GetDisplayName() + " (all 8 full)")
                        endif
                    endif
                    p += 1
                EndWhile

                ; Situation mappings: stored preset name -> index.
                String[] situations = new String[7]
                situations[0] = "adventure"
                situations[1] = "town"
                situations[2] = "home"
                situations[3] = "sleep"
                situations[4] = "combat"
                situations[5] = "rain"
                situations[6] = "snow"

                Int si = 0
                While si < situations.Length
                    String sitPreset = StorageUtil.GetStringValue(akActor, "SeverOutfit_Sit_" + situations[si], "")
                    if sitPreset != ""
                        ; Exact: a fuzzy sibling would mis-map it (N3).
                        Int idx = FindPresetIndexExact(akActor, sitPreset)
                        if idx >= 0
                            SeverActionsNative.Native_OutfitSlot_SetSituationPreset(akActor, situations[si], idx)
                            migratedSituations += 1
                        endif
                    endif
                    si += 1
                EndWhile

                ; Per-actor auto-switch (default on).
                Int autoSwitchVal = StorageUtil.GetIntValue(akActor, "SeverOutfit_AutoSwitch", 1)
                if autoSwitchVal == 0
                    SeverActionsNative.Native_OutfitSlot_SetAutoSwitch(akActor, false)
                endif

                if committedPresets > 0
                    migratedActors += 1
                endif

                ; Stamp the sentinel even when nothing was committed: that means
                ; everything was already in order.
                StorageUtil.SetIntValue(akActor, "SeverActions_OutfitSlotMigDone", 1)
            endif
        endif
        ai += 1
    EndWhile

    if migratedActors > 0 || migratedPresets > 0 || migratedSituations > 0
        Log("MigrateToOutfitSlotSystem: Migrated " + migratedActors + " actors, " + migratedPresets + " presets, " + migratedSituations + " situation mappings this pass")
    endif
EndFunction

Int Function FindFirstEmptyPresetIdx(Actor akActor)
    {First preset index (0-7) with no name, or -1 if all 8 are taken.}
    if !akActor
        return -1
    endif
    Int p = 0
    While p < 8
        String existing = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, p)
        if existing == ""
            return p
        endif
        p += 1
    EndWhile
    return -1
EndFunction

; === MAINTENANCE ===

Function Maintenance()
    {Run by the outfit provider's stage 2 on every load and new game, after the
     migration: rebuilds the LvlItems, empties and re-binds slot aliases, repairs
     ghost presets once, registers known guardians and drains stranded satchels.
     AutoRegisterKnownGuardians MUST run before DrainStrandedSatchelItems: the
     drain skips guardian actors, and one not yet registered would have its
     guardian-stowed items dumped into its inventory.}

    ; 1: rebuild the LvlItems.
    Actor[] assigned = GetAllAssignedActors()
    Int i = 0
    Int rebuilt = 0
    While i < assigned.Length
        if assigned[i]
            RepopulateAllLvlItemsForActor(assigned[i])
            rebuilt += 1
        endif
        i += 1
    EndWhile
    Log("Maintenance: Rebuilt LvlItems for " + rebuilt + " actors")

    ; 1.2: empty a slot alias its occupant no longer owns. The native releases
    ; (ReleaseOrphanedSlots at kPostLoadGame, a purge) free the slot but cannot
    ; empty a quest alias, which keeps the released actor persistent. Before the
    ; re-bind, so a stale occupant is emptied rather than displaced. Slots 10-99
    ; only: 00-09 are shared with the outfit alias pool, which
    ; SeverActions_Outfit.ReassignOutfitSlots settles.
    Int sweptAliases = 0
    Int si = 10
    While si < 100
        ReferenceAlias slotAlias = SeverActionsNative.Native_OutfitSlot_GetAliasForSlot(si)
        if slotAlias
            Actor occupant = slotAlias.GetActorRef()
            if occupant && SeverActionsNative.Native_OutfitSlot_GetSlot(occupant) != si
                slotAlias.Clear()
                sweptAliases += 1
            endif
        endif
        si += 1
    EndWhile
    if sweptAliases > 0
        Log("Maintenance: emptied " + sweptAliases + " slot alias(es) whose occupant no longer owns the slot")
    endif

    ; 1.25: re-bind every slot owner to their slot alias (an unbound owner gets no
    ; OutfitAlias events, so no re-equip of their preset; older saves can hold
    ; unbound owners of slots 0-9). An actor displaced here is re-seated by
    ; SeverActions_Outfit.ReassignOutfitSlots, which runs next in stage 2.
    Int rebound = 0
    Int bi = 0
    While bi < assigned.Length
        Actor owner = assigned[bi]
        if owner
            Int ownerSlot = SeverActionsNative.Native_OutfitSlot_GetSlot(owner)
            ReferenceAlias ownerAlias = None
            if ownerSlot >= 0
                ownerAlias = SeverActionsNative.Native_OutfitSlot_GetAliasForSlot(ownerSlot)
            endif
            if ownerAlias && ownerAlias.GetActorRef() != owner
                BindSlotAlias(owner, ownerAlias)
                rebound += 1
            endif
        endif
        bi += 1
    EndWhile
    if rebound > 0
        Log("Maintenance: re-bound " + rebound + " slot owner(s) to their slot alias")
    endif

    ; 1.5: one-time ghost-preset repair (see RepairGhostPresets). Raise the
    ; version (1, in the test and the stamp) to run it again.
    if StorageUtil.GetIntValue(None, "SeverActions_OutfitGhostRepairDone", 0) < 1
        Int ghostsCleared = 0
        Int gi = 0
        While gi < assigned.Length
            if assigned[gi]
                ghostsCleared += RepairGhostPresets(assigned[gi])
            endif
            gi += 1
        EndWhile
        StorageUtil.SetIntValue(None, "SeverActions_OutfitGhostRepairDone", 1)
        if ghostsCleared > 0
            Log("Maintenance: ghost-preset repair cleared " + ghostsCleared + " empty/blank presets")
        endif
    endif

    ; 2: register known guardians BEFORE the drain (see the doc above).
    AutoRegisterKnownGuardians()

    ; 3: drain stranded satchels.
    Int stranded = 0
    Int j = 0
    While j < assigned.Length
        if assigned[j]
            stranded += DrainStrandedSatchelItems(assigned[j])
        endif
        j += 1
    EndWhile
    if stranded > 0
        Log("Maintenance: recovered " + stranded + " stranded satchel items")
    endif
EndFunction

Int Function RepairGhostPresets(Actor akActor)
    {Handle "ghost" presets: a name with no items (empty chest, itemCount 0), left
     by an older migration; it holds its index and shows blank. A ghost whose
     items still sit in a legacy store stays and the actor's migration sentinel
     is reset so the migration refills it; the rest are cleared. Returns the
     number cleared.}
    if !akActor
        return 0
    endif
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        return 0
    endif

    Int cleared = 0
    Bool needsRemigrate = false
    Int p = 0
    While p < 8
        String name = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, p)
        if name != ""
            Int itemCount = SeverActionsNative.Native_OutfitSlot_GetPresetItemCount(akActor, p)
            ObjectReference chest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, p)
            Int chestItems = 0
            if chest
                chestItems = chest.GetNumItems()
            endif
            if itemCount <= 0 && chestItems == 0
                ; A ghost: recoverable only if a legacy store still holds its items.
                String presetKey = "SeverOutfit_" + name + "_" + (akActor.GetFormID() as String)
                Int suCount = StorageUtil.FormListCount(None, presetKey)
                Int nativeCount = 0
                Form[] nativeItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, name)
                if nativeItems
                    nativeCount = nativeItems.Length
                endif
                if suCount > 0 || nativeCount > 0
                    needsRemigrate = true
                    Log("RepairGhostPresets: '" + name + "' on " + akActor.GetDisplayName() + " empty but recoverable (su=" + suCount + " native=" + nativeCount + ") - re-queued for migration")
                else
                    SeverActionsNative.Native_OutfitSlot_ClearPreset(akActor, p)
                    cleared += 1
                    Log("RepairGhostPresets: cleared empty ghost preset '" + name + "' (idx " + p + ") on " + akActor.GetDisplayName())
                endif
            endif
        endif
        p += 1
    EndWhile

    if needsRemigrate
        ; The migration's empty-chest path refills them on the next load.
        StorageUtil.SetIntValue(akActor, "SeverActions_OutfitSlotMigDone", 0)
    endif
    return cleared
EndFunction

Int Function DrainStrandedSatchelItems(Actor akActor)
    {Return the items a legacy satchel-stashing path left in the actor's satchel
     to their inventory; returns the count moved. Skips an actor with guardian
     containers: their satchel stages guardian-stowed items, which only
     RestoreGuardianContainers routes back (in _TeardownPresetForIdx and
     ReleaseSlotFromActor), and dumping them would break that follower's mod.}
    if !akActor
        return 0
    endif
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        return 0
    endif

    ObjectReference[] guardians = SeverActionsNative.Native_OutfitSlot_GetGuardians(akActor)
    if guardians && guardians.Length > 0
        return 0
    endif

    ObjectReference satchel = SeverActionsNative.Native_OutfitSlot_GetSatchel(slotIdx)
    if !satchel
        return 0
    endif
    Int n = satchel.GetNumItems()
    if n <= 0
        return 0
    endif
    satchel.RemoveAllItems(akActor)
    Log("DrainStrandedSatchelItems: returned " + n + " stranded items to " + akActor.GetDisplayName())
    return n
EndFunction

Function AutoRegisterKnownGuardians()
    {Register the guardian containers of custom followers known to enforce their
     own outfit. Skipped when the mod is absent, and only for an actor who
     already holds a slot, so no NPC gets a slot before being onboarded.}

    ; ----- Daegon (k101Daegon.esp) -----
    ; Her quest alias re-equips from this container in OnObjectUnequipped;
    ; stowing it during a preset apply breaks that loop. 0x005902 is her PLACED
    ; reference (the NPC_ base 0x005900 cast to Actor is None); 0x5F4FB7 is
    ; k101DaegonCustomOutfitContainerRef.
    Actor daegon = Game.GetFormFromFile(0x005902, "k101Daegon.esp") as Actor
    ObjectReference daegonContainer = Game.GetFormFromFile(0x5F4FB7, "k101Daegon.esp") as ObjectReference
    if daegonContainer && !daegon
        ; The plugin is loaded but the reference did not resolve (a replacer
        ; re-placed her, or the FormID changed): log it, never fail silently.
        Log("AutoRegisterKnownGuardians: k101Daegon.esp is loaded but 0x005902 did not resolve as an Actor - Daegon's guardian container not registered")
    elseif daegon && daegonContainer
        if SeverActionsNative.Native_OutfitSlot_GetSlot(daegon) >= 0
            RegisterGuardianContainer(daegon, daegonContainer)
        endif
    endif

    ; ----- More known mods go here -----
    ; Template (the NPC's PLACED reference; an NPC_ base cast to Actor is None):
    ;   Actor someActor = Game.GetFormFromFile(0xXX, "SomeMod.esp") as Actor
    ;   ObjectReference someContainer = Game.GetFormFromFile(0xYY, "SomeMod.esp") as ObjectReference
    ;   if someActor && someContainer && SeverActionsNative.Native_OutfitSlot_GetSlot(someActor) >= 0
    ;       RegisterGuardianContainer(someActor, someContainer)
    ;   endif
EndFunction

Actor[] Function GetAllAssignedActors()
    {All actors holding a slot, from the native store; never None.}
    Actor[] result = SeverActionsNative.Native_OutfitSlot_GetAssignedActors()
    if !result
        return PapyrusUtil.ActorArray(0)
    endif
    return result
EndFunction

; === ARRAY HELPERS ===

Int Function FindFormInArray(Form[] arr, Form needle)
    {Linear search for a Form in a Form array. Returns index or -1.}
    if !arr || !needle
        return -1
    endif
    Int i = 0
    Int n = arr.Length
    While i < n
        if arr[i] == needle
            return i
        endif
        i += 1
    EndWhile
    return -1
EndFunction

Actor[] Function MergeActorArraysUnique(Actor[] a, Actor[] b)
    {Combine two Actor arrays, deduplicating. Returns a new array.}
    Actor[] result = PapyrusUtil.ActorArray(0)
    if a
        Int i = 0
        While i < a.Length
            if a[i]
                result = PapyrusUtil.PushActor(result, a[i])
            endif
            i += 1
        EndWhile
    endif
    if b
        Int i = 0
        While i < b.Length
            if b[i]
                Bool found = false
                Int j = 0
                While j < result.Length && !found
                    if result[j] == b[i]
                        found = true
                    endif
                    j += 1
                EndWhile
                if !found
                    result = PapyrusUtil.PushActor(result, b[i])
                endif
            endif
            i += 1
        EndWhile
    endif
    return result
EndFunction

String[] Function MergeStringArraysUnique(String[] a, String[] b)
    {Combine two String arrays, deduplicating (exact match). Returns a new array.}
    String[] result = PapyrusUtil.StringArray(0)
    if a
        Int i = 0
        While i < a.Length
            if a[i] != ""
                result = PapyrusUtil.PushString(result, a[i])
            endif
            i += 1
        EndWhile
    endif
    if b
        Int i = 0
        While i < b.Length
            if b[i] != ""
                Bool found = false
                Int j = 0
                While j < result.Length && !found
                    if result[j] == b[i]
                        found = true
                    endif
                    j += 1
                EndWhile
                if !found
                    result = PapyrusUtil.PushString(result, b[i])
                endif
            endif
            i += 1
        EndWhile
    endif
    return result
EndFunction
