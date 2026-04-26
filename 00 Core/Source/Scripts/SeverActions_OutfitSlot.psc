Scriptname SeverActions_OutfitSlot extends Quest
{
    NFF-style outfit slot system.

    Each managed NPC is assigned a slot index 0-49. Each slot has 8 preset
    indices, each backed by:
        - A BGSOutfit record (points to a LeveledItem)
        - A LeveledItem placeholder (populated at apply-time from container)
        - An ObjectReference container (player-editable storage)
    Plus one satchel container per slot (holds personal items while a preset
    is active).

    Preset apply flow (mirrors NFF's SwitchOutfit):
        1. Move personal items to satchel (first-time only)
        2. SetOutfit(BlankOutfit) â€” break old outfit assertion
        3. UnequipAll â€” strip actor
        4. PopulateLvlItem â€” Revert() + AddForm() loop from container
        5. SetOutfit(presetOutfit) â€” engine auto-equips the LeveledItem contents

    After apply, the engine re-enforces the outfit on every cell load
    automatically via the DefaultOutfit mechanism. No re-equip loop needed.

    Author: Severause
}

; =============================================================================
; LOGGING HELPER â€” writes to BOTH Papyrus.0.log and SeverActionsNative.log
; Replaces direct Debug.Trace calls so messages appear in the SKSE log even
; when Papyrus logging is disabled in the modlist.
; =============================================================================

Function Log(String msg)
    SeverActionsNative.Native_OutfitSlot_Log(msg)
    Debug.Trace("[SeverOutfit] " + msg)
EndFunction

; =============================================================================
; SINGLETON
; =============================================================================

SeverActions_OutfitSlot Function GetInstance() Global
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_OutfitSlot
EndFunction

; =============================================================================
; STORAGEUTIL KEYS
; =============================================================================

String Property KEY_PRESET_ACTIVE = "SeverOutfit_PresetActive" AutoReadOnly Hidden
{Int: 1 if actor has an active preset, 0 if not. Read by OutfitAlias for short-circuit.}

String Property KEY_SLOT_MIGRATION_VERSION = "SeverOutfit_SlotMigrationVersion" AutoReadOnly Hidden
{Int: migration schema version. 0 = not migrated. 1 = migrated from legacy StorageUtil.}

; =============================================================================
; SLOT LIFECYCLE
; =============================================================================

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
        Log("AssignSlotToActor: All 50 slots occupied, cannot assign " + akActor.GetDisplayName())
        return -1
    endif

    ; Snapshot original outfit for later restore
    SeverActionsNative.Native_OutfitSlot_SaveOriginalOutfit(akActor)

    ; Bind actor to the corresponding "OutfitSlotNN" ReferenceAlias so that
    ; SeverActions_OutfitAlias OnLoad/OnCellLoad/OnObjectUnequipped events fire
    ; for this specific NPC. Without this binding the alias is idle.
    ReferenceAlias targetAlias = SeverActionsNative.Native_OutfitSlot_GetAliasForSlot(slotIdx)
    if targetAlias
        targetAlias.ForceRefTo(akActor)
        Log("Assigned slot " + slotIdx + " to " + akActor.GetDisplayName() + " (alias bound)")
    else
        Log("WARNING: Slot " + slotIdx + " assigned but alias OutfitSlot" + PadSlotStr(slotIdx) + " not found in ESP")
    endif
    return slotIdx
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
        Log("EnsureContainer: ChestBase record missing â€” ESP scaffolding not applied")
        return None
    endif

    ; Spawn anchored to player, persistent, initially disabled (invisible)
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
    {Full slot release â€” restores original outfit, empties and deletes dynamic refs,
     clears all preset data. Only call on force-remove or user "Clear All Presets".
     Do NOT call on dismiss (slot persists through dismiss/re-recruit).}
    if !akActor
        return
    endif

    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        return
    endif

    ; 1. Clear any active preset â€” restores original outfit + satchel
    if SeverActionsNative.Native_OutfitSlot_IsPresetActive(akActor)
        ClearPreset(akActor)
    endif

    ; 2. Empty + delete all spawned preset containers
    ;
    ; OWNERSHIP-AWARE: chest contents now mix CATALOG-supplied items (real
    ; copies the slot system "owns") with USER-OWNED MARKER copies (the user
    ; already has these in their inventory; the chest just records that the
    ; FormID is part of this preset). We do NOT want to dump user-owned
    ; markers anywhere — the user already has the originals; giving them
    ; more would be a duplicate. Just delete chest contents (None destination).
    ;
    ; Catalog items get destroyed too. If the user wanted to recover them,
    ; they should do so before releasing the slot. Releasing is a "burn it
    ; all down" operation by definition.
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

    ; 4. Clear the alias binding (unforce the actor from the slot alias)
    ReferenceAlias slotAlias = SeverActionsNative.Native_OutfitSlot_GetAliasForSlot(slotIdx)
    if slotAlias
        slotAlias.Clear()
    endif

    ; 5. Release the native slot
    SeverActionsNative.Native_OutfitSlot_ReleaseSlot(akActor)

    ; 6. Clear Papyrus state flags
    StorageUtil.UnsetIntValue(akActor, KEY_PRESET_ACTIVE)

    Log("Released slot " + slotIdx + " from " + akActor.GetDisplayName())
EndFunction

; =============================================================================
; PRESET BUILD
; =============================================================================

Int Function BuildPreset(Actor akActor, Int presetIdx, Form[] items, String presetName)
    {Populate preset container with given items, store name, cache item count.
     Does NOT apply the preset â€” call ApplyPresetBySlot afterward.
     presetIdx must be 0-7. Items beyond 32 are silently dropped (matches storage limits).
     Returns the number of items committed, or -1 on error.}
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

    ; Overwriting an existing preset: DELETE the old chest contents AND clean
    ; up any temp-copies of those items currently in the actor's inventory.
    ;
    ; Rationale:
    ;   - Old chest contents are deleted (intentional replace by the user)
    ;   - If the actor was actively wearing the OLD preset, the temp-copies
    ;     in their inventory would become "orphans" pointing to a wardrobe
    ;     that no longer exists. Delete 1 of each from the actor too, so
    ;     the wardrobe contract holds: "preset items only exist in chests
    ;     plus temp-copies WHILE the preset is active". Once the preset
    ;     is overwritten, those temp-copies are no longer valid.
    ;   - User-owned duplicates are preserved: we only delete 1 per FormID.
    ;     If the follower legitimately owned a matching armor item, they
    ;     keep it.
    ;
    ; akOtherContainer=None means delete (CK: "RemoveAllItems with no
    ; transfer destination removes items from the inventory"). No drop,
    ; no actor pollution, no satchel mixing, no player leak.
    Int oldChestCount = chest.GetNumItems()
    if oldChestCount > 0
        ; Snapshot the old chest's distinct FormIDs BEFORE deletion. We need
        ; this list to clean up CATALOG temp-copies on the actor (not user-
        ; owned items — those stay in the actor's inventory regardless).
        Form[] oldFormIDs = Utility.CreateFormArray(oldChestCount)
        Int snapI = 0
        While snapI < oldChestCount
            oldFormIDs[snapI] = chest.GetNthForm(snapI)
            snapI += 1
        EndWhile

        ; Delete chest contents (intentional overwrite).
        chest.RemoveAllItems(None)

        ; Ownership-aware cleanup: for each old preset FormID, only delete
        ; from actor if it was catalog-supplied. User-owned items stay.
        Int cleanedCatalog = 0
        Int preservedUserOwned = 0
        Int ci = 0
        While ci < oldChestCount
            Form oldItem = oldFormIDs[ci]
            if oldItem
                Int actorHasOld = akActor.GetItemCount(oldItem)
                if actorHasOld > 0
                    Bool wasCatalog = SeverActionsNative.Native_OutfitSlot_IsCatalogSupplied(akActor, presetIdx, oldItem)
                    if wasCatalog
                        akActor.RemoveItem(oldItem, 1, true, None)
                        cleanedCatalog += 1
                    else
                        preservedUserOwned += 1
                    endif
                endif
            endif
            ci += 1
        EndWhile

        ; Clear catalog metadata for the overwritten preset (will be
        ; re-populated below for the new preset's catalog items).
        SeverActionsNative.Native_OutfitSlot_ClearCatalogSupplied(akActor, presetIdx)

        ; If we just overwrote the currently-active preset, clear the active
        ; flag — the actor isn't wearing the catalog temp-copies anymore.
        ; User-owned items may still be equipped but are no longer "the preset".
        Int currentActive = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
        if currentActive == presetIdx
            SeverActionsNative.Native_OutfitSlot_SetActivePreset(akActor, -1)
            StorageUtil.UnsetIntValue(akActor, KEY_PRESET_ACTIVE)
            Log("BuildPreset: cleared active state — overwrite affected the currently-active preset")
        endif

        Log("BuildPreset: overwrite deleted " + oldChestCount + " old chest items, cleaned " + cleanedCatalog + " catalog temp-copies, preserved " + preservedUserOwned + " user-owned items (slot=" + slotIdx + " preset=" + presetIdx + ")")
    endif

    ; OWNERSHIP-AWARE BUILD:
    ;
    ; Pop the catalog-supplied list that C++ buildOutfitSavePreset recorded for
    ; this (actor, preset name). This is the set of FormIDs C++ ADDED to the
    ; actor's inventory because they weren't already there. Anything else in
    ; `items` was already in the actor's inventory at build time = user-owned.
    ;
    ;   - Catalog-supplied items: MOVE from actor to chest (treats them as
    ;     temporary preset gear; will be restored on apply, deleted on swap).
    ;     ALSO mark them in Native_OutfitSlot_AddCatalogSupplied so apply/swap
    ;     can do the right thing.
    ;
    ;   - User-owned items: COPY a marker into chest (chest.AddItem) WITHOUT
    ;     removing from actor inventory. The user keeps their item; the chest
    ;     just records "this item is part of preset N". On apply, we equip the
    ;     existing copy; on swap, we just unequip — never delete.
    ;
    ; Net: actor inventory is preserved across builds. Catalog items live in
    ; chest only (until first apply); user items live in actor only (chest
    ; just has a marker copy that we DON'T duplicate on apply).
    String normalizedName = presetName
    if normalizedName == ""
        normalizedName = "preset" + presetIdx
    endif

    ; Clear stale catalog metadata for this preset slot before re-populating
    SeverActionsNative.Native_OutfitSlot_ClearCatalogSupplied(akActor, presetIdx)

    Form[] catalogList = SeverActionsNative.Native_OutfitSlot_PopPendingCatalog(akActor, normalizedName)
    Int catalogListLen = 0
    if catalogList
        catalogListLen = catalogList.Length
    endif

    Form[] committedItems = Utility.CreateFormArray(32)
    Int committed = 0
    Int catalogTagged = 0
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

            if isCatalog
                ; Catalog-supplied: MOVE from actor to chest (clean temp-copy
                ; pattern). C++ added it 1 to actor; move that 1 to chest.
                Int npcCount = akActor.GetItemCount(items[i])
                if npcCount > 0
                    akActor.RemoveItem(items[i], 1, true, chest)
                else
                    ; Fallback if not in actor (shouldn't happen if C++ ran)
                    chest.AddItem(items[i], 1, true)
                endif
                SeverActionsNative.Native_OutfitSlot_AddCatalogSupplied(akActor, presetIdx, items[i])
                catalogTagged += 1
            else
                ; User-owned: COPY a marker into chest WITHOUT touching actor.
                ; The user keeps their copy in inventory.
                chest.AddItem(items[i], 1, true)
                userOwnedTagged += 1
            endif

            committedItems[committed] = items[i]
            committed += 1
        endif
        i += 1
    EndWhile

    Log("BuildPreset: " + akActor.GetDisplayName() + " slot=" + slotIdx + " preset=" + presetIdx + " '" + normalizedName + "' (" + committed + " items: " + catalogTagged + " catalog, " + userOwnedTagged + " user-owned)")

    ; Repopulate the LeveledItem from the container
    PopulateLvlItemFromContainer(slotIdx, presetIdx)

    ; Store metadata (name + item count)
    SeverActionsNative.Native_OutfitSlot_SetPresetName(akActor, presetIdx, normalizedName)
    SeverActionsNative.Native_OutfitSlot_SetPresetItemCount(akActor, presetIdx, committed)

    ; === DUAL-WRITE TO LEGACY STORES (resilience backup) ===
    ; Mirror the COMMITTED slice (not the original array) so a future migration
    ; resurrects the exact preset the slot system applied. Trims trailing None
    ; entries and respects the 32-item cap.
    MirrorPresetToLegacyStores(akActor, normalizedName, committedItems, committed)

    return committed
EndFunction

Function MirrorPresetToLegacyStores(Actor akActor, String presetName, Form[] items, Int itemCount)
    {Mirror a slot-built preset to the legacy StorageUtil + native OutfitDataStore.
     Resilience backup: if slot-system cosave is ever dropped, migration can
     recover from this. Silent on errors (best-effort).}
    if !akActor || presetName == ""
        return
    endif

    Int actorFormID = akActor.GetFormID()
    String presetKey = "SeverOutfit_" + presetName + "_" + (actorFormID as String)

    ; Actor tracker — make sure this NPC is in the global preset list
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
    {Wardrobe pattern, swap-out / clear path. OWNERSHIP-AWARE:

     - Catalog-supplied items (added by C++ at build time): DELETE 1 from
       actor (the temp copy). Chest still holds the source for next apply.
     - User-owned items (already in actor inventory at build time): just
       UNEQUIP. Never delete — the user's item stays in their inventory.

     Catalog-supplied flag is per-(actor, presetIdx, formID), tracked in
     OutfitSlotStore::catalogSuppliedItems. Items not flagged are user-owned
     by default (safer fallback for legacy v2 saves with no flag data).}
    if !akActor || slotIdx < 0 || presetIdx < 0 || presetIdx >= 8
        return
    endif

    ObjectReference chest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, presetIdx)
    if !chest
        return
    endif

    ; Iterate distinct forms in the container — those are the preset items.
    Int n = chest.GetNumItems()
    Int deletedCatalog = 0
    Int unequippedUserOwned = 0
    Int i = 0
    While i < n
        Form item = chest.GetNthForm(i)
        if item
            Int npcHas = akActor.GetItemCount(item)
            if npcHas > 0
                Bool isCatalog = SeverActionsNative.Native_OutfitSlot_IsCatalogSupplied(akActor, presetIdx, item)
                if isCatalog
                    ; Catalog temp-copy: delete from actor. Chest still has source.
                    akActor.RemoveItem(item, 1, true, None)
                    deletedCatalog += 1
                else
                    ; User-owned: just unequip if equipped, leave in inventory.
                    if akActor.IsEquipped(item)
                        akActor.UnequipItem(item, true, true)
                    endif
                    unequippedUserOwned += 1
                endif
            endif
        endif
        i += 1
    EndWhile

    if deletedCatalog > 0 || unequippedUserOwned > 0
        Log("RemovePresetItemsFromActor: preset " + presetIdx + " — deleted " + deletedCatalog + " catalog temp copies, unequipped " + unequippedUserOwned + " user-owned items (chest preserved)")
    endif
EndFunction

Function PopulateLvlItemFromContainer(Int slotIdx, Int presetIdx)
    {Clear the LeveledItem and re-add one of each item in the container.
     Flags UseAll + CalculateForEachItemInCount on the LvlItem ensure the engine
     adds every entry when it resolves the outfit's LvlItem reference.
     This is the function that must run on every kPostLoadGame â€” the ESP's
     baseline LvlItem entries are empty, container contents are what persist.}
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
            lvl.AddForm(item, 1, 1)   ; level=1, count=1 â€” matches NFF pattern
        endif
        i += 1
    EndWhile
EndFunction

Function RepopulateAllLvlItemsForActor(Actor akActor)
    {Call on kPostLoadGame â€” repopulates all 8 preset LvlItems from their
     containers so the engine re-resolves the outfits correctly.
     Safe to call unconditionally; no-ops if slot not assigned.}
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

; =============================================================================
; PRESET APPLY (the crown jewel)
; =============================================================================

Function ApplyPresetBySlot(Actor akActor, Int presetIdx)
    {Apply a preset via SetOutfit trick. After this, the engine re-enforces
     the preset on every cell load automatically â€” no re-equip loop needed.

     Flow (mirrors NFF's SwitchOutfit):
        1. Move personal items to satchel (first-time only)
        2. SetOutfit(BlankOutfit) + UnequipAll
        3. PopulateLvlItem from container
        4. SetOutfit(presetOutfit)
        5. Mark preset active
    }
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

    ; Defense in depth: trust the runtime, not just the cached metadata.
    ; If the container ref vanished or got emptied (mod uninstall, save corruption,
    ; user manually emptied via console), the cached count is stale. Calling
    ; SetOutfit with an empty LvlItem would strip the actor naked.
    ObjectReference verifyChest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, presetIdx)
    if !verifyChest
        Log("ApplyPresetBySlot: Container ref is None for slot=" + slotIdx + " preset=" + presetIdx + " (cached count=" + storedItemCount + ") — refusing to apply ghost preset")
        return
    endif
    Int actualNumItems = verifyChest.GetNumItems()
    if actualNumItems <= 0
        Log("ApplyPresetBySlot: Container is empty (cached count=" + storedItemCount + ") for slot=" + slotIdx + " preset=" + presetIdx + " — refusing to apply ghost preset")
        return
    endif
    Log("ApplyPresetBySlot: Found preset record (storedCount=" + storedItemCount + ", containerActual=" + actualNumItems + ") for slot=" + slotIdx + " preset=" + presetIdx)

    Int currentActive = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)

    ; Suspend legacy outfit lock during swap
    SeverActions_Outfit outfitSys = GetOutfitScript()
    if outfitSys
        outfitSys.SuspendOutfitLock(akActor)
    endif

    ; First-time apply: stow any guardian containers (e.g. Daegon's custom
    ; outfit container) so their enforcing alias stops fighting our equip.
    ;
    ; We DELIBERATELY no longer call MovePersonalItemsToSatchel here. Reason:
    ; with the wardrobe pattern, the chest is the source of truth for preset
    ; items — there's no need to stash the actor's other armor in a hidden
    ; satchel. DirectEquipPreset's strip phase unequips everything; items
    ; stay in the actor's visible inventory. This eliminates two failure modes:
    ;   1. Items appearing to "disappear" (they were just hidden in the satchel)
    ;   2. Mid-strip engine auto-equip races where UnequipItem on each personal
    ;      armor triggered NPC auto-equip cycling through inventory before our
    ;      atomic DirectEquipPreset could run, causing partial/wrong equips
    ;
    ; Switching from another preset: delete the old preset's temp copies
    ; from actor inventory (chest already has the source); guardian stowage
    ; remains in place from the first apply (don't restore until full clear).
    if currentActive < 0
        StowGuardianContainers(akActor, slotIdx)
    elseif currentActive != presetIdx
        RemovePresetItemsFromActor(akActor, slotIdx, currentActive)
    endif

    ; Clear PresetActive flag at swap start. If the apply below fails partway
    ; through, the alias short-circuit (which checks this flag) won't claim
    ; the preset is still active. The flag is re-set to 1 only on full
    ; success below. Native side's activePresetIdx is also reset inside
    ; DirectEquipPreset, then re-set on full success.
    StorageUtil.UnsetIntValue(akActor, KEY_PRESET_ACTIVE)

    ; === NO SetOutfit CALL ===
    ; We deliberately do NOT call SetOutfit() here, neither blank nor the
    ; preset outfit. SetOutfit's queued engine work (especially the implicit
    ; UnequipAll on outfit change) fires OnObjectUnequipped events 0.5–1.5s
    ; later, which then trigger our debounce → reapply cascade — running
    ; DirectEquipPreset 2-3 times for a single user click.
    ;
    ; Cell-load re-application is handled by the OutfitAlias OnLoad handler,
    ; which calls DirectEquipPreset directly using the slot's chest contents.
    ; The chest is the persistent wardrobe, so we don't need the engine to
    ; remember an outfit for us.

    ; === ATOMIC C++ EQUIP (wardrobe pattern) ===
    ; Snapshots chest contents, strips ALL worn armor, deletes any duplicate
    ; copies of preset items in actor inventory (legacy cleanup), adds exactly
    ; 1 fresh copy of each from native, equips synchronously (applyNow=true),
    ; verifies IsWorn after the call.
    ;
    ; The chest stays untouched: it's the persistent wardrobe. Actor inventory
    ; gets temp copies that live only while the preset is active.
    ;
    ; Return values:
    ;   -1            : hard error (no chest / no equip manager / chest empty)
    ;   0             : nothing equipped
    ;   < expected    : partial equip (body-slot conflict between preset items)
    ;   == expected   : success
    Int verifiedEquipped = SeverActionsNative.Native_OutfitSlot_DirectEquipPreset(akActor, presetIdx)
    Log("ApplyPresetBySlot: DirectEquipPreset verifiedEquipped=" + verifiedEquipped + " expected=" + storedItemCount)

    if outfitSys
        outfitSys.ResumeOutfitLock(akActor)
    endif

    String presetName = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, presetIdx)

    ; === COMMIT or REPORT ===
    ; Only mark the preset active when EVERY expected item is verified worn.
    ; Marking active on a partial would make the alias short-circuit treat a
    ; half-naked NPC as "preset is on" — exactly the silent-corruption path
    ; we just spent a sprint hunting.
    if verifiedEquipped == storedItemCount && verifiedEquipped > 0
        ; DirectEquipPreset already set activePresetIdx in the slot store on
        ; full success; mirror to StorageUtil for legacy alias fast-paths.
        StorageUtil.SetIntValue(akActor, KEY_PRESET_ACTIVE, 1)
        Log("Applied preset " + presetIdx + " ('" + presetName + "') to " + akActor.GetDisplayName() + " (" + verifiedEquipped + "/" + storedItemCount + " items equipped) [OK]")
    elseif verifiedEquipped < 0
        ; Hard native failure — chest gone, equip mgr unavailable, etc.
        ; Do NOT mark active. NPC stays in whatever state we left them
        ; (probably partial worn from any pre-strip). User can retry; alias
        ; system will not short-circuit because PresetActive is unset.
        Log("ApplyPresetBySlot: HARD FAILURE applying '" + presetName + "' to " + akActor.GetDisplayName() + " — DirectEquip returned " + verifiedEquipped + " — preset NOT marked active")
    else
        ; Partial equip — most likely body-slot conflict between two preset
        ; items, or engine dropped one. Surface loudly, don't mark active.
        Log("ApplyPresetBySlot: PARTIAL apply for '" + presetName + "' on " + akActor.GetDisplayName() + " — " + verifiedEquipped + "/" + storedItemCount + " worn — preset NOT marked active")
    endif
EndFunction

Function ClearPreset(Actor akActor)
    {Return actor to their original outfit â€” unsets active preset, restores
     satchel items, SetOutfit to the saved original (or engine default).}
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

    SeverActions_Outfit outfitSys = GetOutfitScript()
    if outfitSys
        outfitSys.SuspendOutfitLock(akActor)
    endif

    ; Move the active preset's items back to its container before breaking
    ; the outfit — prevents duplication when original outfit is restored and
    ; engine re-adds items. Items return to the preset wardrobe, ready for
    ; next apply.
    RemovePresetItemsFromActor(akActor, slotIdx, active)

    ; Break current outfit enforcement
    Outfit blankOutfit = SeverActionsNative.Native_OutfitSlot_GetBlankOutfit()
    if blankOutfit
        akActor.SetOutfit(blankOutfit, false)
    endif
    Utility.Wait(0.1)
    akActor.UnequipAll()
    Utility.Wait(0.1)

    ; ORDER MATTERS: guardian restoration reads from the satchel (it was used
    ; as the staging area on first apply). RestoreSatchelToActor empties the
    ; satchel wholesale, so guardian restoration MUST run first.
    ; Without this order, custom-follower outfits (e.g. Daegon) lose their
    ; original guardian-container contents and the actor accumulates them
    ; instead.

    ; Restore guardian container contents (if any were stowed during first apply).
    ; Reads from the satchel, returns items to their original guardian container
    ; AND into the actor's inventory.
    RestoreGuardianContainers(akActor, slotIdx)

    ; Now safe to drain the rest of the satchel (everything not claimed by the
    ; guardian restore step) back to the actor.
    RestoreSatchelToActor(akActor, slotIdx)

    ; Restore original outfit if we have one saved
    Outfit origOutfit = SeverActionsNative.Native_OutfitSlot_GetOriginalOutfit(akActor)
    if origOutfit
        akActor.SetOutfit(origOutfit, false)
    endif

    Outfit origSleep = SeverActionsNative.Native_OutfitSlot_GetOriginalSleepOutfit(akActor)
    if origSleep
        akActor.SetOutfit(origSleep, true)   ; sleep outfit
    endif

    SeverActionsNative.Native_OutfitSlot_SetActivePreset(akActor, -1)
    StorageUtil.SetIntValue(akActor, KEY_PRESET_ACTIVE, 0)

    if outfitSys
        outfitSys.ResumeOutfitLock(akActor)
    endif

    Log("Cleared preset from " + akActor.GetDisplayName())
EndFunction

; =============================================================================
; GUARDIAN CONTAINER HELPERS
; For custom followers whose mods enforce an outfit via a container-backed
; guardian alias (e.g. Daegon's k101DaegonCustomOutfitContainer).
; =============================================================================

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
    {Remove a previously-registered guardian container. Before unregistering,
     RESTORE any stowed items back to the guardian — otherwise those items
     would be orphaned in the satchel with no routing metadata, and future
     ClearPreset / Maintenance passes would dump them into the actor's
     inventory instead of back to the guardian (breaking the custom follower
     mod's expected state).}
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
                            ; Move 1 copy from satchel back to guardian
                            satchel.RemoveItem(item, 1, true, guardianContainer)
                            restored += 1
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
    {Before applying a preset on an actor with guardian containers, empty each
     guardian's contents into the satchel and record what was moved. The guardian
     mod's OnItemRemoved typically propagates to the NPC, so by the time the
     preset is applied the guardian alias's "GetItemCount > 0" check fails and
     it won't fight our outfit changes.}
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
            ; Snapshot the guardian's contents BEFORE moving (so we know what to restore).
            Int n = guardian.GetNumItems()
            Form[] stowed = Utility.CreateFormArray(n)
            Int i = 0
            While i < n
                stowed[i] = guardian.GetNthForm(i)
                i += 1
            EndWhile

            ; Register the snapshot BEFORE the move (OnItemRemoved cascade may mutate state)
            SeverActionsNative.Native_OutfitSlot_SetStowedItems(akActor, guardian, stowed)

            ; Empty guardian into satchel. Guardian's OnItemRemoved script (if present)
            ; will propagate to the NPC, removing matching items from their inventory.
            ; This is what breaks the guardian alias's "fight on unequip" check.
            guardian.RemoveAllItems(satchel)

            Log("Stowed " + n + " items from guardian " + guardian.GetFormID() + " for " + akActor.GetDisplayName())
        endif
        g += 1
    EndWhile
EndFunction

Function RestoreGuardianContainers(Actor akActor, Int slotIdx)
    {Reverse of StowGuardianContainers — moves items from the satchel back to
     each registered guardian container AND re-adds them to the actor's inventory
     so their mod's normal equip flow can proceed.}
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
                            ; Move 1 copy from satchel back to guardian container.
                            ; Guardian's OnItemAdded (if it has filtering) decides whether to keep.
                            satchel.RemoveItem(item, 1, true, guardian)
                            ; Also re-add to actor so their mod can equip on next cell load/dialogue.
                            akActor.AddItem(item, 1, true)
                            restored += 1
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

; =============================================================================
; SATCHEL HELPERS
; =============================================================================

Function MovePersonalItemsToSatchel(Actor akActor, Int slotIdx)
    {Walk actor's inventory, move all armor items that AREN'T in the DefaultOutfit
     to the satchel. Keeps 1 copy of each DefaultOutfit item (matches NFF behavior).
     Non-armor items are left alone. Called once per "first apply" cycle.}
    if !akActor || slotIdx < 0
        return
    endif

    ObjectReference satchel = EnsureSatchel(akActor, slotIdx)
    if !satchel
        return
    endif

    ; Collect DefaultOutfit parts to preserve at count>=1
    Outfit origOutfit = SeverActionsNative.Native_OutfitSlot_GetOriginalOutfit(akActor)
    Form[] defaultParts = None
    if origOutfit
        Int partCount = origOutfit.GetNumParts()
        defaultParts = Utility.CreateFormArray(partCount)
        Int dp = 0
        While dp < partCount
            defaultParts[dp] = origOutfit.GetNthPart(dp)
            dp += 1
        EndWhile
    endif

    Int itemCount = akActor.GetNumItems()
    Int moved = 0
    Int i = 0
    While i < itemCount && moved < 500   ; sanity cap
        Form item = akActor.GetNthForm(i)
        Armor armorItem = item as Armor
        if armorItem
            Int keepCount = 0
            if defaultParts && FindFormInArray(defaultParts, armorItem as Form) >= 0
                keepCount = 1   ; preserve 1 copy of DefaultOutfit pieces
            endif
            Int haveCount = akActor.GetItemCount(armorItem)
            Int moveCount = haveCount - keepCount
            if moveCount > 0
                ; Unequip first (in case worn), then transfer
                if akActor.IsEquipped(armorItem)
                    akActor.UnequipItem(armorItem, true, true)
                endif
                akActor.RemoveItem(armorItem, moveCount, true, satchel)
                moved += 1
            endif
        endif
        i += 1
    EndWhile

    Log("Moved " + moved + " personal armor items to satchel for " + akActor.GetDisplayName())
EndFunction

Function RestoreSatchelToActor(Actor akActor, Int slotIdx)
    {Dump satchel contents back to actor's inventory. Called by ClearPreset.}
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

; =============================================================================
; NAME <-> INDEX HELPERS (for LLM-facing API compat)
; =============================================================================

Int Function FindPresetIndexByName(Actor akActor, String name)
    {Look up preset index 0-7 by name. Returns -1 if not found.
     Case-INSENSITIVE match — defends against BSFixedString pool case flips
     (e.g. "daedric" being returned as "DAEDRIC" because Skyrim has interned
     the uppercase form via an armor keyword).}
    if !akActor || name == ""
        Log("FindPresetIndexByName: bad input akActor=" + akActor + " name='" + name + "'")
        return -1
    endif
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        Log("FindPresetIndexByName: actor " + akActor.GetDisplayName() + " has no slot (looking for '" + name + "')")
        return -1
    endif

    ; Normalize query to lowercase once, compare each slot name lowercased.
    String queryLower = SeverActionsNative.StringToLower(name)
    String dump = "slot=" + slotIdx + " names=["
    Int p = 0
    While p < 8
        String existing = SeverActionsNative.Native_OutfitSlot_GetPresetName(akActor, p)
        dump = dump + "'" + existing + "'"
        if p < 7
            dump = dump + ","
        endif
        String existingLower = SeverActionsNative.StringToLower(existing)
        if existingLower == queryLower && existingLower != ""
            Log("FindPresetIndexByName: " + akActor.GetDisplayName() + " '" + name + "' -> idx " + p + " (" + dump + "])")
            return p
        endif
        p += 1
    EndWhile
    Log("FindPresetIndexByName: " + akActor.GetDisplayName() + " '" + name + "' NOT FOUND " + dump + "]")
    return -1
EndFunction

Int Function FindFreeOrReusableIndex(Actor akActor, String name)
    {Return index to save a preset into:
        - If name matches an existing preset (case-INSENSITIVE), return that index (overwrite).
        - Else, return first empty index.
        - If all 8 full with different names, return -1 (caller must evict or error).
     Case-insensitive overwrite-match prevents the BSFixedString pool case-flip
     from accidentally consuming a second slot ('daedric' vs 'DAEDRIC').}
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

    ; First pass: look for name match (overwrite) — case-insensitive
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

    ; Second pass: first empty
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
    {Remove a preset by name from the slot system: empty + delete the container,
     revert the LeveledItem, clear the name+itemCount metadata.
     Case-INSENSITIVE name match.
     Returns True if a preset was deleted, False if not found.

     If the preset being deleted is currently active, also call ClearPreset()
     to restore the original outfit before we wipe its container — otherwise
     the engine would auto-equip from a now-deleted LvlItem reference.}
    if !akActor || presetName == ""
        return false
    endif

    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        return false
    endif

    Int presetIdx = FindPresetIndexByName(akActor, presetName)
    if presetIdx < 0
        return false
    endif

    ; If this preset is currently active, restore original outfit first.
    Int activeIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
    if activeIdx == presetIdx
        ClearPreset(akActor)
    endif

    ; Empty + delete the container.
    ; OWNERSHIP-AWARE: chest contents are a mix of catalog-supplied items
    ; (real copies the slot system owns) and user-owned marker copies (the
    ; user already has these — chest just records FormID membership). Dumping
    ; user-owned markers to the player would create duplicates of items the
    ; user/follower already has. Just delete (None destination).
    ObjectReference chest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, presetIdx)
    if chest
        if chest.GetNumItems() > 0
            chest.RemoveAllItems(None)  ; destroy, don't dump to player
        endif
        chest.Delete()
        SeverActionsNative.Native_OutfitSlot_SetContainerRef(akActor, presetIdx, None)
    endif

    ; Revert the LvlItem so it can be repopulated cleanly on a future save
    LeveledItem lvl = SeverActionsNative.Native_OutfitSlot_GetLvlItem(slotIdx, presetIdx)
    if lvl
        lvl.Revert()
    endif

    ; Clear name + item count metadata, plus any situation mappings pointing to this idx
    SeverActionsNative.Native_OutfitSlot_ClearPreset(akActor, presetIdx)
    ClearSituationsPointingTo(akActor, presetIdx)

    Log("DeletePresetFromSlot: removed '" + presetName + "' from slot " + slotIdx + " preset " + presetIdx + " for " + akActor.GetDisplayName())
    return true
EndFunction

Function ClearSituationsPointingTo(Actor akActor, Int presetIdx)
    {Clear any situation mappings (adventure/town/home/sleep/combat/rain/snow)
     that point to the given preset index. Called after a preset is deleted
     so situation auto-switch doesn't try to apply a vanished preset.}
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
    {Called by ad-hoc outfit actions (Dress, Undress, EquipItemByName, catalog
     Equip & Lock) before they modify the actor's worn state. If a slot preset
     is currently active, deactivate it so the legacy outfit lock can take
     effect — otherwise the alias's slot-preset enforcement would silently
     undo the ad-hoc change.

     Does NOT touch the chest, name, item count, or catalog ownership data.
     The preset can be re-applied later via UI/LLM and will resume cleanly.

     Returns True if a preset was deactivated, False if none was active.}
    if !akActor
        return false
    endif

    Int activeIdx = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
    Int storageActive = StorageUtil.GetIntValue(akActor, KEY_PRESET_ACTIVE, 0)

    if activeIdx < 0 && storageActive == 0
        return false
    endif

    ; Deactivate without destroying the preset's chest/metadata.
    SeverActionsNative.Native_OutfitSlot_SetActivePreset(akActor, -1)
    StorageUtil.UnsetIntValue(akActor, KEY_PRESET_ACTIVE)

    Log("ClearActivePresetForAdHoc: deactivated slot preset " + activeIdx + " on " + akActor.GetDisplayName() + " (ad-hoc action takes over; preset chest preserved for re-apply)")
    return true
EndFunction

Bool Function IsSlotEligible(Actor akActor)
    {Check if actor should use the slot system.
     Eligible if any of:
        - Already has a slot assigned
        - Registered as a SeverActions follower
        - Has the explicit non-follower lock flag set
        - Is a player teammate (covers custom followers like Daegon who are
          recruited via their own mod rather than SeverActions)
        - Is in the vanilla CurrentFollowerFaction (catch-all for vanilla followers)
     This is intentionally permissive. If you don't want a particular NPC to
     use the slot system, mark them outfit-excluded via FollowerDataStore.}
    if !akActor
        return false
    endif
    if SeverActionsNative.Native_OutfitSlot_GetSlot(akActor) >= 0
        return true
    endif
    if StorageUtil.GetIntValue(akActor, "SeverFollower_IsFollower", 0) == 1
        return true
    endif
    if StorageUtil.GetIntValue(akActor, "SeverOutfit_NonFollowerLock", 0) == 1
        return true
    endif
    if akActor.IsPlayerTeammate()
        return true
    endif
    ; Vanilla CurrentFollowerFaction (0x00000528CE) — belt-and-suspenders for
    ; vanilla followers whose teammate flag temporarily drops (sandboxing etc.)
    Faction cff = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
    if cff && akActor.IsInFaction(cff)
        return true
    endif
    return false
EndFunction

; =============================================================================
; SITUATION INTEGRATION
; =============================================================================

Function OnSituationChangedForActor(Actor akActor, String situation)
    {Called by SeverActions_Outfit.OnSituationChanged. Looks up the mapped
     preset index for this situation and applies it via ApplyPresetBySlot.
     Short-circuits if auto-switch disabled or no preset mapped.}
    if !akActor || akActor.IsDead()
        return
    endif

    if !SeverActionsNative.Native_OutfitSlot_GetAutoSwitch(akActor)
        return
    endif

    Int presetIdx = SeverActionsNative.Native_OutfitSlot_GetSituationPreset(akActor, situation)
    if presetIdx < 0
        return   ; no mapping for this situation â€” keep current
    endif

    Int currentActive = SeverActionsNative.Native_OutfitSlot_GetActivePreset(akActor)
    if currentActive == presetIdx
        return   ; already wearing
    endif

    ApplyPresetBySlot(akActor, presetIdx)
EndFunction

; =============================================================================
; HELPERS
; =============================================================================

SeverActions_Outfit Function GetOutfitScript()
    return Game.GetFormFromFile(0x000D62, "SeverActions.esp") as SeverActions_Outfit
EndFunction

; =============================================================================
; MIGRATION FROM LEGACY STORAGE (one-shot on first load after upgrade)
; =============================================================================

Function MigrateToOutfitSlotSystem()
    {Incremental migration from StorageUtil/OutfitDataStore-based presets into
     the new slot system. Runs on every game load and migrates only legacy
     presets that don't already exist in the slot system. Handles:
       - Initial migration (first load after upgrade)
       - Actors whose slot-eligibility changed after the initial migration
       - New legacy presets saved while actor was not slot-eligible

     Per-preset idempotent: skips presets whose names already exist in the
     actor's slot system. Never overwrites existing slot-system presets.

     Does NOT auto-apply any preset on migration - slots start with
     activePresetIdx=-1. Next manual apply or situation change kicks in the
     new enforcement.}
    Log("MigrateToOutfitSlotSystem: Starting incremental migration scan...")

    SeverActions_Outfit outfitSys = GetOutfitScript()
    if !outfitSys
        Log("MigrateToOutfitSlotSystem: OutfitScript not found, aborting")
        return
    endif

    ; Gather all actors with legacy presets — combine StorageUtil-tracked + native OutfitDataStore.
    ; The native store catches actors whose presets were saved via the C++ direct path
    ; before the StorageUtil mirror was wired (e.g. Daegon's case).
    Actor[] storageActors = outfitSys.GetPresetActors()
    Actor[] nativeActors = SeverActionsNative.Native_Outfit_GetActorsWithPresets()
    Actor[] presetActors = MergeActorArraysUnique(storageActors, nativeActors)
    Int migratedActors = 0
    Int migratedPresets = 0
    Int migratedSituations = 0

    Int ai = 0
    While ai < presetActors.Length
        Actor akActor = presetActors[ai]
        if akActor && !akActor.IsDead()
            ; Assign slot if not already
            Int slotIdx = AssignSlotToActor(akActor)
            if slotIdx >= 0
                ; Combine preset names from both legacy StorageUtil and native OutfitDataStore
                String[] storageNames = outfitSys.GetPresetNames(akActor)
                ; Use index-based iteration for native names (avoids string-array return marshalling)
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
                        ; Decide what to do based on slot-system state for this name:
                        ;   - Name not in slot: register it, then commit items (NEW preset).
                        ;   - Name in slot AND chest has items: already migrated, skip.
                        ;   - Name in slot but chest EMPTY: refill chest from legacy mirror
                        ;     (RECOVERY PATH — handles cosave drops / chest corruption).
                        Int existingSlotIdx = FindPresetIndexByName(akActor, name)
                        Bool needsItemCommit = false
                        Int targetIdx = -1

                        if existingSlotIdx >= 0
                            ; Name exists. Check if chest is healthy.
                            ObjectReference existingChest = SeverActionsNative.Native_OutfitSlot_GetContainer(slotIdx, existingSlotIdx)
                            Int existingChestNumItems = 0
                            if existingChest
                                existingChestNumItems = existingChest.GetNumItems()
                            endif
                            if existingChestNumItems == 0
                                ; Chest empty — recover from legacy mirror.
                                targetIdx = existingSlotIdx
                                needsItemCommit = true
                                Log("Migration: name '" + name + "' exists at preset " + existingSlotIdx + " but chest empty — refilling from legacy mirror")
                            endif
                            ; else: chest has items, fully migrated, skip silently.
                        else
                            ; === PHASE 1: NEW PRESET — REGISTER NAME FIRST ===
                            ; Independent of item commit. Name is the slot's identity —
                            ; FindPresetIndexByName must succeed even if items fail to
                            ; commit. Without this, LLM apply and PrismaUI can never find it.
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
                            ; === PHASE 2: ITEM COMMIT (best-effort) ===
                            ; Try StorageUtil first, fall back to native OutfitDataStore
                            String presetKey = "SeverOutfit_" + name + "_" + (akActor.GetFormID() as String)
                            Int itemCount = StorageUtil.FormListCount(None, presetKey)
                            Form[] presetItems = None
                            if itemCount > 0
                                presetItems = Utility.CreateFormArray(itemCount)
                                Int ii = 0
                                While ii < itemCount
                                    presetItems[ii] = StorageUtil.FormListGet(None, presetKey, ii)
                                    ii += 1
                                EndWhile
                            else
                                ; Native OutfitDataStore fallback
                                presetItems = SeverActionsNative.Native_Outfit_GetPresetItems(akActor, name)
                            endif

                            Int presetItemCount = 0
                            if presetItems
                                presetItemCount = presetItems.Length
                            endif

                            if presetItemCount > 0
                                ObjectReference chest = EnsureContainer(akActor, slotIdx, targetIdx)
                                if chest
                                    ; Clear any stale contents — destroy (None dest)
                                    ; rather than dump to player. Mixed user-owned/
                                    ; catalog markers shouldn't go to the player.
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
                                    ; Repopulate LvlItem
                                    PopulateLvlItemFromContainer(slotIdx, targetIdx)
                                    ; Store item count metadata (name already set above)
                                    SeverActionsNative.Native_OutfitSlot_SetPresetItemCount(akActor, targetIdx, committed)
                                    Log("Migration: committed " + committed + " items for '" + name + "' slot=" + slotIdx + " preset=" + targetIdx)
                                else
                                    Log("Migration: EnsureContainer failed for slot=" + slotIdx + " preset=" + targetIdx + " name='" + name + "' — name registered but items not committed")
                                endif
                            else
                                Log("Migration: no items found for '" + name + "' in either StorageUtil or native store — name registered but items empty (user can rebuild via builder)")
                            endif
                        elseif existingSlotIdx < 0 && targetIdx < 0
                            Log("Migration: no empty preset slots available for '" + name + "' on " + akActor.GetDisplayName() + " (all 8 full)")
                        endif
                    endif
                    p += 1
                EndWhile

                ; Migrate situation mappings â€” translate preset name to index
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
                        Int idx = FindPresetIndexByName(akActor, sitPreset)
                        if idx >= 0
                            SeverActionsNative.Native_OutfitSlot_SetSituationPreset(akActor, situations[si], idx)
                            migratedSituations += 1
                        endif
                    endif
                    si += 1
                EndWhile

                ; Migrate per-actor auto-switch
                Int autoSwitchVal = StorageUtil.GetIntValue(akActor, "SeverOutfit_AutoSwitch", 1)
                if autoSwitchVal == 0
                    SeverActionsNative.Native_OutfitSlot_SetAutoSwitch(akActor, false)
                endif

                if committedPresets > 0
                    migratedActors += 1
                endif
            endif
        endif
        ai += 1
    EndWhile

    ; Track cumulative migration count. Informational only - migration is now
    ; incremental (runs every load), so no hard gate here.
    Int cumulative = StorageUtil.GetIntValue(None, KEY_SLOT_MIGRATION_VERSION, 0) + migratedActors
    StorageUtil.SetIntValue(None, KEY_SLOT_MIGRATION_VERSION, cumulative)

    if migratedActors > 0 || migratedPresets > 0 || migratedSituations > 0
        Log("MigrateToOutfitSlotSystem: Migrated " + migratedActors + " actors, " + migratedPresets + " presets, " + migratedSituations + " situation mappings this pass")
    endif
EndFunction

Int Function FindFirstEmptyPresetIdx(Actor akActor)
    {Return the first preset index (0-7) in the actor's slot that has no name set.
     Returns -1 if all 8 slots are occupied.}
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

; =============================================================================
; MAINTENANCE (call from SeverActions_Init on every game load)
; =============================================================================

Function Maintenance()
    {Called from SeverActions_Init on game load. Rebuilds all LvlItem contents
     from their containers. Auto-registers known guardian containers. Recovers
     stranded items from old satchels (legacy MovePersonalItemsToSatchel).

     ORDER MATTERS: AutoRegisterKnownGuardians MUST run BEFORE
     DrainStrandedSatchelItems. The drain skips actors with registered
     guardians (their satchel holds guardian-stowed items, not personal
     items). If we drained first on an upgrade-from-old-version load, a
     Daegon-like custom follower would have an empty guardian list at drain
     time and we'd dump their guardian items into their actor inventory,
     breaking the custom follower mod.}

    ; STEP 1: Rebuild LvlItems for all assigned actors
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

    ; STEP 2: Register known guardian containers BEFORE the drain runs.
    ; Without this order, guardian-using actors would be misclassified as
    ; non-guardian during drain and have their guardian-stowed satchel
    ; contents dumped to their actor inventory.
    AutoRegisterKnownGuardians()

    ; STEP 3: Now safe to drain stranded satchel items. The drain skips
    ; actors with registered guardians.
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

Int Function DrainStrandedSatchelItems(Actor akActor)
    {Recovery for items stashed by the legacy MovePersonalItemsToSatchel path.
     Drains satchel contents back to the actor's inventory.

     CAUTION: actors with guardian containers (custom followers like Daegon)
     also use the satchel as a staging area for guardian-stowed items. We
     skip those actors entirely — they recover via the ClearPreset path,
     which correctly routes guardian items back to their original container
     before draining the rest. Auto-draining a guardian-using actor's satchel
     would dump guardian items into the actor's inventory, breaking that mod.

     Returns the count of items moved back to the actor (0 for guardian actors
     and actors with empty satchels).}
    if !akActor
        return 0
    endif
    Int slotIdx = SeverActionsNative.Native_OutfitSlot_GetSlot(akActor)
    if slotIdx < 0
        return 0
    endif

    ; Skip guardian-using actors — their satchel contents include guardian
    ; stash, which must be routed via ClearPreset, not dumped wholesale.
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
    {Pre-registers guardian containers for custom followers with known conflict
     patterns. Each registration is null-safe; if the mod isn't loaded, the
     Form lookup returns None and the registration is skipped.

     Only auto-registers if the actor already has a slot assigned (i.e., they
     were recruited via the SeverActions system). This prevents us from
     creating slots for NPCs the user hasn't onboarded yet.}

    ; ----- Daegon (k101Daegon.esp) -----
    ; Her k101DaegonQuestAliasScript enforces her native outfit via container
    ; re-equip in OnObjectUnequipped. Registering her container lets us stow
    ; it during preset apply, breaking the enforcement loop.
    Actor daegon = Game.GetFormFromFile(0x005900, "k101Daegon.esp") as Actor
    ObjectReference daegonContainer = Game.GetFormFromFile(0x5F4FB7, "k101Daegon.esp") as ObjectReference
    if daegon && daegonContainer
        if SeverActionsNative.Native_OutfitSlot_GetSlot(daegon) >= 0
            RegisterGuardianContainer(daegon, daegonContainer)
        endif
    endif

    ; ----- Add more known mods here as users report them -----
    ; Template:
    ;   Actor someActor = Game.GetFormFromFile(0xXX, "SomeMod.esp") as Actor
    ;   ObjectReference someContainer = Game.GetFormFromFile(0xYY, "SomeMod.esp") as ObjectReference
    ;   if someActor && someContainer && SeverActionsNative.Native_OutfitSlot_GetSlot(someActor) >= 0
    ;       RegisterGuardianContainer(someActor, someContainer)
    ;   endif
EndFunction

Actor[] Function GetAllAssignedActors()
    {Return all actors currently holding a slot. Reads directly from the native store.}
    Actor[] result = SeverActionsNative.Native_OutfitSlot_GetAssignedActors()
    if !result
        return PapyrusUtil.ActorArray(0)
    endif
    return result
EndFunction

; =============================================================================
; FORM ARRAY HELPER
; =============================================================================

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
                ; Check if already in result
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
