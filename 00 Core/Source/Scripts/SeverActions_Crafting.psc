Scriptname SeverActions_Crafting extends Quest
{Crafting system with JContainers JSON database integration.
Replaces FormLists with a JSON-based item lookup system.}

; =============================================================================
; PROPERTIES - Set in Creation Kit
; =============================================================================

; Packages
Package Property CraftAtForgePackage Auto
{The AI package that makes the NPC use the forge}

Package Property ApproachRecipientPackage Auto
{The AI package that makes the NPC walk to the recipient}

; Aliases for package targeting
ReferenceAlias Property CrafterAlias Auto
{Alias for the NPC doing the crafting - used with forge package}

ReferenceAlias Property ForgeAlias Auto  
{Alias for the target forge}

ReferenceAlias Property CrafterApproachAlias Auto
{Alias for the NPC walking to recipient - used with approach package (separate from CrafterAlias)}

ReferenceAlias Property RecipientAlias Auto
{Alias for who receives the crafted item}

Idle Property IdleGive Auto
{Give item animation}

; NOTE: Cooking and alchemy reuse ForgeAlias and CraftAtForgePackage
; All workstations (forge, cooking pot, alchemy lab) work the same way:
; - They're furniture that NPCs use via UseFurniture package procedure
; - The package just needs a target reference, doesn't matter what type



; =============================================================================
; CONFIGURATION - Tunable via MCM or here
; =============================================================================

float Property CRAFT_TIME = 5.0 Auto
{How long the crafting animation plays}

float Property SEARCH_RADIUS = 2000.0 Auto
{Radius to search for forges (in game units, ~28 meters)}

float Property INTERACTION_DISTANCE = 150.0 Auto
{How close NPC must be to forge to start crafting}

int Property CRAFT_PACKAGE_PRIORITY = 100 Auto
{Priority for craft package - must be higher than dialogue (usually 50-80)}

string Property DATABASE_FOLDER = "Data/SKSE/Plugins/SeverActions/CraftingDB/" Auto
{Folder containing craftable item JSON databases. All .json files in this folder will be loaded and merged.}

; =============================================================================
; INTERNAL VARIABLES
; =============================================================================

int craftableDB = 0          ; JContainers handle to the database
bool isInitialized = false   ; Whether database has been loaded

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    LoadDatabase()
EndEvent

Function LoadDatabase()
    {Load all craftable items databases from the database folder and merge them}
    
    ; Create the master database structure
    craftableDB = JMap.object()
    JMap.setObj(craftableDB, "weapons", JMap.object())
    JMap.setObj(craftableDB, "armor", JMap.object())
    JMap.setObj(craftableDB, "misc", JMap.object())
    
    bool loadedAny = false
    
    ; Try to load from the folder using readFromDirectory
    ; JContainers returns a JMap of {filename: parsed_json_object} pairs
    int fileMap = JValue.readFromDirectory(DATABASE_FOLDER, ".json")
    
    if fileMap != 0 && JValue.isMap(fileMap)
        int fileCount = JMap.count(fileMap)
        Debug.Trace("SeverActions_Crafting: Found " + fileCount + " database files in " + DATABASE_FOLDER)
        
        ; Iterate through the map using nextKey
        string fileName = JMap.nextKey(fileMap)
        while fileName != ""
            Debug.Trace("SeverActions_Crafting: Loading " + fileName)
            
            ; Get the already-parsed JSON object for this file
            int fileDB = JMap.getObj(fileMap, fileName)
            if fileDB != 0
                MergeDatabaseInto(fileDB, craftableDB)
                loadedAny = true
                Debug.Trace("SeverActions_Crafting: Successfully merged " + fileName)
            else
                Debug.Trace("SeverActions_Crafting: Failed to get object for " + fileName)
            endif
            
            fileName = JMap.nextKey(fileMap, fileName)
        endwhile
        
        ; Release the file map (individual file objects are owned by it)
        JValue.release(fileMap)
    else
        Debug.Trace("SeverActions_Crafting: readFromDirectory returned nothing for " + DATABASE_FOLDER)
    endif
    
    ; If folder scan didn't work, try loading known filenames directly
    if !loadedAny
        Debug.Trace("SeverActions_Crafting: Trying direct file paths...")
        
        ; Try common filenames
        string[] tryFiles = new string[6]
        tryFiles[0] = DATABASE_FOLDER + "00_vanilla.json"
        tryFiles[1] = DATABASE_FOLDER + "10_requiem.json"
        tryFiles[2] = DATABASE_FOLDER + "craftable_items.json"
        tryFiles[3] = DATABASE_FOLDER + "vanilla.json"
        tryFiles[4] = "Data/SKSE/Plugins/SeverActions/craftable_items.json"
        tryFiles[5] = "Data/SKSE/Plugins/SeverActions/CraftingDB/00_vanilla.json"
        
        int idx = 0
        while idx < tryFiles.Length
            if tryFiles[idx] != ""
                int fileDB = JValue.readFromFile(tryFiles[idx])
                if fileDB != 0
                    Debug.Trace("SeverActions_Crafting: Successfully loaded " + tryFiles[idx])
                    MergeDatabaseInto(fileDB, craftableDB)
                    JValue.release(fileDB)
                    loadedAny = true
                endif
            endif
            idx += 1
        endwhile
    endif
    
    if !loadedAny
        Debug.Notification("SeverActions: No crafting databases found!")
        Debug.Trace("SeverActions_Crafting: No databases found. Checked folder: " + DATABASE_FOLDER)
        isInitialized = false
        return
    endif
    
    ; Retain the master database so it doesn't get garbage collected
    JValue.retain(craftableDB)
    isInitialized = true
    
    ; Log stats
    int weaponsObj = JMap.getObj(craftableDB, "weapons")
    int armorObj = JMap.getObj(craftableDB, "armor")
    int miscObj = JMap.getObj(craftableDB, "misc")
    
    int weaponCount = JMap.count(weaponsObj)
    int armorCount = JMap.count(armorObj)
    int miscCount = JMap.count(miscObj)
    
    Debug.Trace("SeverActions_Crafting: Database loaded successfully!")
    Debug.Trace("SeverActions_Crafting: " + weaponCount + " weapons, " + armorCount + " armor, " + miscCount + " misc items")
EndFunction

Function MergeDatabaseInto(int sourceDB, int targetDB)
    {Merge a source database into the target database. Later entries override earlier ones.}
    
    ; Merge each category
    MergeCategoryInto(JMap.getObj(sourceDB, "weapons"), JMap.getObj(targetDB, "weapons"))
    MergeCategoryInto(JMap.getObj(sourceDB, "armor"), JMap.getObj(targetDB, "armor"))
    MergeCategoryInto(JMap.getObj(sourceDB, "misc"), JMap.getObj(targetDB, "misc"))
EndFunction

Function MergeCategoryInto(int sourceCategory, int targetCategory)
    {Merge all entries from source category into target category.
    Stores multiple FormIDs per item as an array for fallback support.}
    
    if sourceCategory == 0 || targetCategory == 0
        return
    endif
    
    int keysArray = JMap.allKeys(sourceCategory)
    int keyCount = JArray.count(keysArray)
    
    int idx = 0
    while idx < keyCount
        string keyName = JArray.getStr(keysArray, idx)
        
        ; Skip comment keys (start with underscore)
        if StringUtil.Find(keyName, "_") != 0
            string newValue = JMap.getStr(sourceCategory, keyName)
            
            ; Get or create array for this item
            int formIdArray = JMap.getObj(targetCategory, keyName)
            if formIdArray == 0
                ; First entry for this item - create new array
                formIdArray = JArray.object()
                JMap.setObj(targetCategory, keyName, formIdArray)
            endif
            
            ; Add this FormID to the array (later entries go first for priority)
            JArray.addStr(formIdArray, newValue, 0)
        endif
        
        idx += 1
    endwhile
EndFunction

Function ReloadDatabase()
    {Reload database from disk - useful after editing JSON}
    
    if craftableDB != 0
        JValue.release(craftableDB)
    endif
    
    LoadDatabase()
    Debug.Notification("SeverActions: Crafting database reloaded")
EndFunction

; =============================================================================
; ITEM LOOKUP FUNCTIONS
; =============================================================================

Form Function FindCraftableByName(string itemName)
    {Find a craftable item by name.
    Uses native RecipeDB first (auto-scanned from COBJ records), falls back to JContainers database.
    Returns None if not found.}

    ; Try native RecipeDB first - this is auto-populated from game data
    ; and includes all vanilla + mod smithing recipes
    if SeverActionsNative.IsRecipeDBLoaded()
        Form nativeResult = SeverActionsNative.FindSmithingRecipe(itemName)
        if nativeResult
            Debug.Trace("SeverActions_Crafting: Found '" + itemName + "' via native RecipeDB")
            return nativeResult
        endif
    endif

    ; Fallback to JContainers database for custom/non-COBJ items
    if !isInitialized
        LoadDatabase()
        if !isInitialized
            return None
        endif
    endif

    string searchName = StringToLower(itemName)

    ; Try exact match first in each category
    Form result = SearchCategory("weapons", searchName)
    if result
        return result
    endif

    result = SearchCategory("armor", searchName)
    if result
        return result
    endif

    result = SearchCategory("misc", searchName)
    if result
        return result
    endif

    ; Try fuzzy search if exact match failed
    result = FuzzySearch(searchName)
    return result
EndFunction

Form Function FindCraftableByNameJContainersOnly(string itemName)
    {Search ONLY the JContainers database - no native fallback.
    Used by CraftItem_Internal after native databases have already been checked.}

    if !isInitialized
        LoadDatabase()
        if !isInitialized
            return None
        endif
    endif

    string searchName = StringToLower(itemName)

    ; Try exact match first in each category
    Form result = SearchCategory("weapons", searchName)
    if result
        return result
    endif

    result = SearchCategory("armor", searchName)
    if result
        return result
    endif

    result = SearchCategory("misc", searchName)
    if result
        return result
    endif

    ; Try fuzzy search if exact match failed
    result = FuzzySearch(searchName)
    return result
EndFunction

Form Function SearchCategory(string category, string searchName)
    {Search a specific category for an item by name.
    Tries each registered FormID until one succeeds (for mod fallback support).}
    
    int categoryObj = JMap.getObj(craftableDB, category)
    if categoryObj == 0
        return None
    endif
    
    ; Get the array of FormIDs for this item
    int formIdArray = JMap.getObj(categoryObj, searchName)
    if formIdArray == 0
        return None
    endif
    
    ; Try each FormID in order (higher priority mods first)
    int arrayCount = JArray.count(formIdArray)
    int idx = 0
    while idx < arrayCount
        string formIdStr = JArray.getStr(formIdArray, idx)
        Form result = GetFormFromHexString(formIdStr)
        if result
            return result
        endif
        ; Plugin not loaded, try next one
        idx += 1
    endwhile
    
    return None
EndFunction

Form Function FuzzySearch(string searchTerm)
    {Search all categories for partial name matches}
    
    string[] categories = new string[3]
    categories[0] = "weapons"
    categories[1] = "armor"
    categories[2] = "misc"
    
    int idx = 0
    while idx < categories.Length
        Form result = FuzzySearchCategory(categories[idx], searchTerm)
        if result
            return result
        endif
        idx += 1
    endwhile
    
    return None
EndFunction

Form Function FuzzySearchCategory(string category, string searchTerm)
    {Search a category for partial matches. Tries each FormID until one works.}
    
    int categoryObj = JMap.getObj(craftableDB, category)
    if categoryObj == 0
        return None
    endif
    
    ; Get all keys in this category
    int keysArray = JMap.allKeys(categoryObj)
    int keyCount = JArray.count(keysArray)
    
    ; Search for partial match
    int idx = 0
    while idx < keyCount
        string keyName = JArray.getStr(keysArray, idx)
        
        ; Check if search term is contained in the key
        if StringUtil.Find(keyName, searchTerm) >= 0
            ; Get the array of FormIDs for this item
            int formIdArray = JMap.getObj(categoryObj, keyName)
            if formIdArray != 0
                ; Try each FormID until one works
                int formCount = JArray.count(formIdArray)
                int formIdx = 0
                while formIdx < formCount
                    string formIdStr = JArray.getStr(formIdArray, formIdx)
                    Form result = GetFormFromHexString(formIdStr)
                    if result
                        return result
                    endif
                    formIdx += 1
                endwhile
            endif
        endif
        
        idx += 1
    endwhile
    
    return None
EndFunction

Form Function GetFormFromHexString(string hexString)
    {Convert a hex string like "Skyrim.esm|0x00012EB7" to a Form.
    Returns None if the plugin isn't loaded or form doesn't exist.}
    
    ; Expected format: "PluginName.esp|0x00012EB7" or just "0x00012EB7"
    
    int pipeIndex = StringUtil.Find(hexString, "|")
    
    if pipeIndex >= 0
        ; Has plugin specification
        string pluginName = StringUtil.Substring(hexString, 0, pipeIndex)
        string formIdPart = StringUtil.Substring(hexString, pipeIndex + 1)
        
        ; Check if plugin is loaded first
        if !Game.IsPluginInstalled(pluginName)
            return None
        endif
        
        int formId = HexToInt(formIdPart)
        return Game.GetFormFromFile(formId, pluginName)
    else
        ; No plugin - try to parse as raw form ID
        ; This assumes it's a runtime form ID
        int formId = HexToInt(hexString)
        return Game.GetForm(formId)
    endif
EndFunction

int Function HexToInt(string hexStr)
    {Convert hex string (with or without 0x prefix) to integer}
    ; Native implementation: ~2000x faster
    return SeverActionsNative.HexToInt(hexStr)
EndFunction

string Function StringToLower(string text)
    {Convert string to lowercase for case-insensitive comparison}
    ; Native implementation: ~2000-10000x faster
    return SeverActionsNative.StringToLower(text)
EndFunction

; =============================================================================
; FORGE FINDING
; =============================================================================

ObjectReference Function FindNearbyForge(Actor akActor)
    {Find the nearest forge within search radius - uses native function}
    return SeverActionsNative.FindNearbyForge(akActor, SEARCH_RADIUS)
EndFunction

ObjectReference Function FindNearbyCookingPot(Actor akActor)
    {Find the nearest cooking pot within search radius - uses native function}
    return SeverActionsNative.FindNearbyCookingPot(akActor, SEARCH_RADIUS)
EndFunction

ObjectReference Function FindNearbyAlchemyLab(Actor akActor)
    {Find the nearest alchemy lab within search radius - uses native function}
    return SeverActionsNative.FindNearbyAlchemyLab(akActor, SEARCH_RADIUS)
EndFunction

; =============================================================================
; ELIGIBILITY CHECKS
; =============================================================================

bool Function CraftWeapon_IsEligible(Actor akActor, string weaponName)
    {Check if actor can craft the specified weapon}
    
    ; Check if database is loaded
    if !isInitialized
        return false
    endif
    
    ; Check if item exists in database
    Form item = FindCraftableByName(weaponName)
    if !item
        return false
    endif
    
    ; Check if actor is valid and not busy
    if !akActor || akActor.IsDead() || akActor.IsInCombat()
        return false
    endif
    
    ; Check if there's a forge nearby
    ObjectReference forge = FindNearbyForge(akActor)
    if !forge
        return false
    endif
    
    return true
EndFunction

bool Function CraftArmor_IsEligible(Actor akActor, string armorName)
    {Check if actor can craft the specified armor}
    return CraftWeapon_IsEligible(akActor, armorName)
EndFunction

bool Function CraftItem_IsEligible(Actor akActor, string itemName)
    {Check if actor can craft any item by name}
    return CraftWeapon_IsEligible(akActor, itemName)
EndFunction

; =============================================================================
; MAIN CRAFTING FUNCTIONS
; =============================================================================

Function CraftWeapon_Execute(Actor akActor, string weaponName, Actor akRecipient, bool requireMaterials)
    {Execute weapon crafting action}
    CraftItem_Internal(akActor, weaponName, akRecipient, requireMaterials)
EndFunction

Function CraftArmor_Execute(Actor akActor, string armorName, Actor akRecipient, bool requireMaterials)
    {Execute armor crafting action}
    CraftItem_Internal(akActor, armorName, akRecipient, requireMaterials)
EndFunction

Function CraftItem_Execute(Actor akActor, string itemName, Actor akRecipient, bool requireMaterials)
    {Execute generic item crafting action}
    CraftItem_Internal(akActor, itemName, akRecipient, requireMaterials)
EndFunction

Function CraftItem_Internal(Actor akActor, string itemName, Actor akRecipient, bool requireMaterials, int itemCount = 1)
    {Unified crafting function - automatically detects item type and routes to appropriate workstation.
    Supports: smithing (forge), cooking (cooking pot), potions/poisons (alchemy lab).
    Uses native databases for fast lookup of all vanilla + modded items.
    itemCount: Number of items to craft (default 1)}

    ; Validate item count
    if itemCount < 1
        itemCount = 1
    endif

    ; Set recipient (default to player if not specified)
    Actor recipient = akRecipient
    if !recipient
        recipient = Game.GetPlayer()
    endif

    ; Try to find the item in each database, in order of priority
    ; This determines both the item AND the workstation type
    Form itemForm = None
    ObjectReference workstation = None
    string workstationType = ""
    string actionVerb = "crafting"

    ; Debug: Check database status
    bool recipeDBLoaded = SeverActionsNative.IsRecipeDBLoaded()
    bool alchemyDBLoaded = SeverActionsNative.IsAlchemyDBLoaded()
    Debug.Trace("SeverActions_Crafting: CraftItem_Internal called for '" + itemName + "'")
    Debug.Trace("SeverActions_Crafting: RecipeDB loaded: " + recipeDBLoaded + ", AlchemyDB loaded: " + alchemyDBLoaded)

    ; 1. Try smithing recipes (forge)
    if recipeDBLoaded
        itemForm = SeverActionsNative.FindSmithingRecipe(itemName)
        if itemForm
            workstation = FindNearbyForge(akActor)
            workstationType = "forge"
            actionVerb = "crafting"
            Debug.Trace("SeverActions_Crafting: FOUND '" + itemName + "' as SMITHING recipe -> " + itemForm.GetName())
        else
            Debug.Trace("SeverActions_Crafting: Not found in smithing recipes")
        endif
    endif

    ; 2. Try cooking recipes (cooking pot)
    if !itemForm && recipeDBLoaded
        itemForm = SeverActionsNative.FindCookingRecipe(itemName)
        if itemForm
            workstation = FindNearbyCookingPot(akActor)
            workstationType = "cooking pot"
            actionVerb = "cooking"
            Debug.Trace("SeverActions_Crafting: FOUND '" + itemName + "' as COOKING recipe -> " + itemForm.GetName())
        else
            Debug.Trace("SeverActions_Crafting: Not found in cooking recipes")
        endif
    endif

    ; 3. Try potions (alchemy lab)
    if !itemForm && alchemyDBLoaded
        itemForm = SeverActionsNative.FindPotion(itemName)
        if itemForm
            workstation = FindNearbyAlchemyLab(akActor)
            workstationType = "alchemy lab"
            actionVerb = "brewing"
            Debug.Trace("SeverActions_Crafting: FOUND '" + itemName + "' as POTION -> " + itemForm.GetName())
        else
            Debug.Trace("SeverActions_Crafting: Not found in potions")
        endif
    endif

    ; 4. Try poisons (alchemy lab)
    if !itemForm && alchemyDBLoaded
        itemForm = SeverActionsNative.FindPoison(itemName)
        if itemForm
            workstation = FindNearbyAlchemyLab(akActor)
            workstationType = "alchemy lab"
            actionVerb = "concocting"
            Debug.Trace("SeverActions_Crafting: FOUND '" + itemName + "' as POISON -> " + itemForm.GetName())
        else
            Debug.Trace("SeverActions_Crafting: Not found in poisons")
        endif
    endif

    ; 5. Fallback to JContainers database (for custom items not in COBJ/alchemy)
    if !itemForm
        Debug.Trace("SeverActions_Crafting: Trying JContainers fallback...")
        itemForm = FindCraftableByNameJContainersOnly(itemName)
        if itemForm
            workstation = FindNearbyForge(akActor)
            workstationType = "forge"
            actionVerb = "crafting"
            Debug.Trace("SeverActions_Crafting: FOUND '" + itemName + "' in JContainers -> " + itemForm.GetName())
        else
            Debug.Trace("SeverActions_Crafting: Not found in JContainers either")
        endif
    endif

    ; Check if we found the item
    if !itemForm
        Debug.Notification("Cannot craft: " + itemName + " (not found in any database)")
        return
    endif

    ; Check if we found a workstation
    if !workstation
        Debug.Notification("No " + workstationType + " nearby!")
        return
    endif

    ; Get names for event descriptions
    string crafterName = akActor.GetDisplayName()
    string itemDisplayName = itemForm.GetName()
    string recipientName = recipient.GetDisplayName()

    ; =========================================================================
    ; PHASE 1: Walk to workstation and craft/cook/brew
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: Walking to " + workstationType)

    ; Register persistent event: Started action
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " begins " + actionVerb + " " + itemDisplayName + ".", akActor, recipient)

    ; Try to unregister TalkToPlayer
    SkyrimNetApi.UnregisterPackage(akActor, "TalkToPlayer")

    ; Set up aliases for workstation package (works for any workstation type)
    ForgeAlias.ForceRefTo(workstation)
    CrafterAlias.ForceRefTo(akActor)

    ; Use ActorUtil to add package with HIGH priority and INTERRUPT flag
    ActorUtil.AddPackageOverride(akActor, CraftAtForgePackage, 100, 1)
    akActor.EvaluatePackage()

    ; Calculate max wait time based on distance
    float maxWait = (SEARCH_RADIUS / 200.0) + CRAFT_TIME

    ; Wait for NPC to reach the workstation
    WaitForArrival(akActor, workstation, maxWait)

    ; Wait for crafting/cooking/brewing animation
    Utility.Wait(CRAFT_TIME)

    ; =========================================================================
    ; PHASE 2: Exit workstation and create item
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: Exiting " + workstationType)
    
    ; Remove the package override we added
    ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)
    
    ; Clear forge alias to exit furniture
    ForgeAlias.Clear()
    akActor.EvaluatePackage()
    
    ; Wait for NPC to fully exit furniture
    Utility.Wait(2.0)
    
    ; Clear crafter alias (done with forge package)
    CrafterAlias.Clear()
    
    ; Add crafted item(s) to the NPC's inventory
    akActor.AddItem(itemForm, itemCount, true)

    ; Register persistent event: Finished action
    string countStr = ""
    if itemCount > 1
        countStr = " x" + itemCount
    endif
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " finishes " + actionVerb + " " + itemDisplayName + countStr + ".", akActor, recipient)

    Debug.Trace("SeverActions_Crafting: Item added to NPC inventory")

    ; =========================================================================
    ; PHASE 3: Walk to recipient
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: Walking to recipient: " + recipientName)
    
    ; Simple alias assignment - this is how the OLD WORKING VERSION did it
    RecipientAlias.ForceRefTo(recipient)
    CrafterApproachAlias.ForceRefTo(akActor)
    akActor.EvaluatePackage()
    
    ; Wait for NPC to reach the recipient
    WaitForArrival(akActor, recipient as ObjectReference, 20.0)
    
    ; Clear approach aliases
    CrafterApproachAlias.Clear()
    RecipientAlias.Clear()
    akActor.EvaluatePackage()
    
    ; =========================================================================
    ; PHASE 4: Face recipient and do give animation
    ; =========================================================================
    
    Debug.Trace("SeverActions_Crafting: Phase 4 - Giving item")
    
    ; Small pause to let NPC settle
    Utility.Wait(0.3)
    
    ; Face the recipient
    FaceActor(akActor, recipient)
    
    ; Play give animation
    DoGiveAnimation(akActor)
    
    ; =========================================================================
    ; PHASE 5: Transfer item to recipient
    ; =========================================================================

    ; Remove from NPC and add to recipient
    akActor.RemoveItem(itemForm, itemCount, false, recipient)

    ; Direct narration: Item handed over (triggers NPC response)
    if itemCount > 1
        SkyrimNetApi.DirectNarration(crafterName + " hands " + itemCount + " " + itemDisplayName + " to " + recipientName + ".", akActor, recipient)
    else
        SkyrimNetApi.DirectNarration(crafterName + " hands " + itemDisplayName + " to " + recipientName + ".", akActor, recipient)
    endif

    ; Notify
    if itemCount > 1
        Debug.Notification("Received: " + itemDisplayName + " x" + itemCount)
    else
        Debug.Notification("Received: " + itemDisplayName)
    endif

    Debug.Trace("SeverActions_Crafting: " + actionVerb + " complete")
EndFunction

Function CookMeal_Internal(Actor akActor, string recipeName, Actor akRecipient, int itemCount = 1)
    {Internal cooking implementation - uses native RecipeDB for cooking recipes.
    Works the same as CraftItem_Internal but at a cooking pot.
    itemCount: Number of items to cook (default 1)}

    ; Validate item count
    if itemCount < 1
        itemCount = 1
    endif

    ; Find the cooking recipe using native RecipeDB
    Form itemForm = None
    if SeverActionsNative.IsRecipeDBLoaded()
        itemForm = SeverActionsNative.FindCookingRecipe(recipeName)
    endif

    if !itemForm
        Debug.Notification("Cannot cook: " + recipeName + " (recipe not found)")
        return
    endif

    ; Find nearby cooking pot
    ObjectReference cookingPot = FindNearbyCookingPot(akActor)
    if !cookingPot
        Debug.Notification("No cooking pot nearby!")
        return
    endif

    ; Set recipient (default to player if not specified)
    Actor recipient = akRecipient
    if !recipient
        recipient = Game.GetPlayer()
    endif

    ; Get names for event descriptions
    string crafterName = akActor.GetDisplayName()
    string itemDisplayName = itemForm.GetName()
    string recipientName = recipient.GetDisplayName()
    string countStr = ""
    if itemCount > 1
        countStr = " x" + itemCount
    endif

    ; =========================================================================
    ; PHASE 1: Walk to cooking pot and cook
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: CookMeal - Walking to cooking pot")

    ; Register persistent event: Started cooking
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " begins cooking " + itemDisplayName + countStr + ".", akActor, recipient)

    ; Try to unregister TalkToPlayer
    SkyrimNetApi.UnregisterPackage(akActor, "TalkToPlayer")

    ; Set up aliases - reuse forge aliases (works for any workstation)
    ForgeAlias.ForceRefTo(cookingPot)
    CrafterAlias.ForceRefTo(akActor)

    ; Use ActorUtil to add package with HIGH priority and INTERRUPT flag
    ActorUtil.AddPackageOverride(akActor, CraftAtForgePackage, 100, 1)
    akActor.EvaluatePackage()

    ; Calculate max wait time based on distance
    float maxWait = (SEARCH_RADIUS / 200.0) + CRAFT_TIME

    ; Wait for NPC to reach the cooking pot
    WaitForArrival(akActor, cookingPot, maxWait)

    ; Wait for cooking animation to play
    Utility.Wait(CRAFT_TIME)

    ; =========================================================================
    ; PHASE 2: Exit cooking pot and create item
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: CookMeal - Exiting cooking pot")

    ; Remove the package override
    ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)

    ; Clear alias to exit furniture
    ForgeAlias.Clear()
    akActor.EvaluatePackage()

    ; Wait for NPC to fully exit furniture
    Utility.Wait(2.0)

    ; Clear crafter alias
    CrafterAlias.Clear()

    ; Add cooked item(s) to the NPC's inventory
    akActor.AddItem(itemForm, itemCount, true)

    ; Register persistent event: Finished cooking
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " finishes cooking " + itemDisplayName + countStr + ".", akActor, recipient)

    ; =========================================================================
    ; PHASE 3: Walk to recipient and give item
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: CookMeal - Walking to recipient: " + recipientName)

    RecipientAlias.ForceRefTo(recipient)
    CrafterApproachAlias.ForceRefTo(akActor)
    akActor.EvaluatePackage()

    ; Wait for NPC to reach the recipient
    WaitForArrival(akActor, recipient as ObjectReference, 20.0)

    ; Clear approach aliases
    CrafterApproachAlias.Clear()
    RecipientAlias.Clear()
    akActor.EvaluatePackage()

    ; =========================================================================
    ; PHASE 4: Face recipient and give item
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: CookMeal - Giving item")

    Utility.Wait(0.3)
    FaceActor(akActor, recipient)
    DoGiveAnimation(akActor)

    ; Transfer item(s) to recipient
    akActor.RemoveItem(itemForm, itemCount, false, recipient)

    ; Direct narration
    if itemCount > 1
        SkyrimNetApi.DirectNarration(crafterName + " hands " + itemCount + " " + itemDisplayName + " to " + recipientName + ".", akActor, recipient)
        Debug.Notification("Received: " + itemDisplayName + " x" + itemCount)
    else
        SkyrimNetApi.DirectNarration(crafterName + " hands " + itemDisplayName + " to " + recipientName + ".", akActor, recipient)
        Debug.Notification("Received: " + itemDisplayName)
    endif

    Debug.Trace("SeverActions_Crafting: CookMeal complete")
EndFunction

Function BrewPotion_Internal(Actor akActor, string potionName, Actor akRecipient, int itemCount = 1)
    {Internal potion brewing implementation - uses native AlchemyDB.
    Works at an alchemy lab.
    itemCount: Number of potions to brew (default 1)}

    ; Validate item count
    if itemCount < 1
        itemCount = 1
    endif

    ; Find the potion using native AlchemyDB
    Potion itemForm = None
    if SeverActionsNative.IsAlchemyDBLoaded()
        itemForm = SeverActionsNative.FindPotion(potionName)
    endif

    if !itemForm
        Debug.Notification("Cannot brew: " + potionName + " (potion not found)")
        return
    endif

    ; Find nearby alchemy lab
    ObjectReference alchemyLab = FindNearbyAlchemyLab(akActor)
    if !alchemyLab
        Debug.Notification("No alchemy lab nearby!")
        return
    endif

    ; Set recipient (default to player if not specified)
    Actor recipient = akRecipient
    if !recipient
        recipient = Game.GetPlayer()
    endif

    ; Get names for event descriptions
    string crafterName = akActor.GetDisplayName()
    string itemDisplayName = itemForm.GetName()
    string recipientName = recipient.GetDisplayName()
    string countStr = ""
    if itemCount > 1
        countStr = " x" + itemCount
    endif

    ; =========================================================================
    ; PHASE 1: Walk to alchemy lab and brew
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: BrewPotion - Walking to alchemy lab")

    ; Register persistent event: Started brewing
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " begins brewing " + itemDisplayName + countStr + ".", akActor, recipient)

    ; Try to unregister TalkToPlayer
    SkyrimNetApi.UnregisterPackage(akActor, "TalkToPlayer")

    ; Set up aliases - reuse forge aliases (works for any workstation)
    ForgeAlias.ForceRefTo(alchemyLab)
    CrafterAlias.ForceRefTo(akActor)

    ; Use ActorUtil to add package with HIGH priority and INTERRUPT flag
    ActorUtil.AddPackageOverride(akActor, CraftAtForgePackage, 100, 1)
    akActor.EvaluatePackage()

    ; Calculate max wait time
    float maxWait = (SEARCH_RADIUS / 200.0) + CRAFT_TIME

    ; Wait for NPC to reach the alchemy lab
    WaitForArrival(akActor, alchemyLab, maxWait)

    ; Wait for brewing animation
    Utility.Wait(CRAFT_TIME)

    ; =========================================================================
    ; PHASE 2: Exit alchemy lab and create potion
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: BrewPotion - Exiting alchemy lab")

    ; Remove the package override
    ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)

    ; Clear alias to exit furniture
    ForgeAlias.Clear()
    akActor.EvaluatePackage()

    ; Wait for NPC to fully exit
    Utility.Wait(2.0)

    ; Clear crafter alias
    CrafterAlias.Clear()

    ; Add brewed potion(s) to the NPC's inventory
    akActor.AddItem(itemForm, itemCount, true)

    ; Register persistent event: Finished brewing
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " finishes brewing " + itemDisplayName + countStr + ".", akActor, recipient)

    ; =========================================================================
    ; PHASE 3: Walk to recipient and give item
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: BrewPotion - Walking to recipient: " + recipientName)

    RecipientAlias.ForceRefTo(recipient)
    CrafterApproachAlias.ForceRefTo(akActor)
    akActor.EvaluatePackage()

    WaitForArrival(akActor, recipient as ObjectReference, 20.0)

    CrafterApproachAlias.Clear()
    RecipientAlias.Clear()
    akActor.EvaluatePackage()

    ; =========================================================================
    ; PHASE 4: Face recipient and give item
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: BrewPotion - Giving item")

    Utility.Wait(0.3)
    FaceActor(akActor, recipient)
    DoGiveAnimation(akActor)

    ; Transfer item(s) to recipient
    akActor.RemoveItem(itemForm, itemCount, false, recipient)

    ; Direct narration
    if itemCount > 1
        SkyrimNetApi.DirectNarration(crafterName + " hands " + itemCount + " " + itemDisplayName + " to " + recipientName + ".", akActor, recipient)
        Debug.Notification("Received: " + itemDisplayName + " x" + itemCount)
    else
        SkyrimNetApi.DirectNarration(crafterName + " hands " + itemDisplayName + " to " + recipientName + ".", akActor, recipient)
        Debug.Notification("Received: " + itemDisplayName)
    endif

    Debug.Trace("SeverActions_Crafting: BrewPotion complete")
EndFunction

Function BrewPoison_Internal(Actor akActor, string poisonName, Actor akRecipient)
    {Internal poison brewing implementation - uses native AlchemyDB.
    Works at an alchemy lab.}

    ; Find the poison using native AlchemyDB
    Potion itemForm = None
    if SeverActionsNative.IsAlchemyDBLoaded()
        itemForm = SeverActionsNative.FindPoison(poisonName)
    endif

    if !itemForm
        Debug.Notification("Cannot brew: " + poisonName + " (poison not found)")
        return
    endif

    ; Find nearby alchemy lab
    ObjectReference alchemyLab = FindNearbyAlchemyLab(akActor)
    if !alchemyLab
        Debug.Notification("No alchemy lab nearby!")
        return
    endif

    ; Set recipient (default to player if not specified)
    Actor recipient = akRecipient
    if !recipient
        recipient = Game.GetPlayer()
    endif

    ; Get names for event descriptions
    string crafterName = akActor.GetDisplayName()
    string itemDisplayName = itemForm.GetName()
    string recipientName = recipient.GetDisplayName()

    ; =========================================================================
    ; PHASE 1: Walk to alchemy lab and brew
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: BrewPoison - Walking to alchemy lab")

    ; Register persistent event: Started concocting
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " begins concocting " + itemDisplayName + ".", akActor, recipient)

    ; Try to unregister TalkToPlayer
    SkyrimNetApi.UnregisterPackage(akActor, "TalkToPlayer")

    ; Set up aliases
    ForgeAlias.ForceRefTo(alchemyLab)
    CrafterAlias.ForceRefTo(akActor)

    ActorUtil.AddPackageOverride(akActor, CraftAtForgePackage, 100, 1)
    akActor.EvaluatePackage()

    float maxWait = (SEARCH_RADIUS / 200.0) + CRAFT_TIME
    WaitForArrival(akActor, alchemyLab, maxWait)
    Utility.Wait(CRAFT_TIME)

    ; =========================================================================
    ; PHASE 2: Exit alchemy lab and create poison
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: BrewPoison - Exiting alchemy lab")

    ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)
    ForgeAlias.Clear()
    akActor.EvaluatePackage()
    Utility.Wait(2.0)
    CrafterAlias.Clear()

    ; Add brewed poison to inventory
    akActor.AddItem(itemForm, 1, true)

    ; Register persistent event: Finished concocting
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " finishes concocting " + itemDisplayName + ".", akActor, recipient)

    ; =========================================================================
    ; PHASE 3: Walk to recipient and give item
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: BrewPoison - Walking to recipient: " + recipientName)

    RecipientAlias.ForceRefTo(recipient)
    CrafterApproachAlias.ForceRefTo(akActor)
    akActor.EvaluatePackage()

    WaitForArrival(akActor, recipient as ObjectReference, 20.0)

    CrafterApproachAlias.Clear()
    RecipientAlias.Clear()
    akActor.EvaluatePackage()

    ; =========================================================================
    ; PHASE 4: Face recipient and give item
    ; =========================================================================

    Debug.Trace("SeverActions_Crafting: BrewPoison - Giving item")

    Utility.Wait(0.3)
    FaceActor(akActor, recipient)
    DoGiveAnimation(akActor)

    akActor.RemoveItem(itemForm, 1, false, recipient)

    SkyrimNetApi.DirectNarration(crafterName + " hands " + itemDisplayName + " to " + recipientName + ".", akActor, recipient)

    Debug.Notification("Received: " + itemDisplayName)
    Debug.Trace("SeverActions_Crafting: BrewPoison complete")
EndFunction

; =============================================================================
; UTILITY FUNCTIONS
; =============================================================================

Function WaitForArrival(Actor akActor, ObjectReference akTarget, float maxWaitTime)
    {Wait for actor to reach target location}
    
    float startTime = Utility.GetCurrentRealTime()
    float timeout = startTime + maxWaitTime
    
    while Utility.GetCurrentRealTime() < timeout
        float dist = akActor.GetDistance(akTarget)
        if dist <= INTERACTION_DISTANCE
            return
        endif
        Utility.Wait(0.5)
    endwhile
    
    ; Timeout reached - teleport as fallback
    Debug.Trace("SeverActions_Crafting: Arrival timeout, actor may not have reached target")
EndFunction

Function DoGiveAnimation(Actor akGiver)
    {Play the give item animation}
    
    if IdleGive
        akGiver.PlayIdle(IdleGive)
        Utility.Wait(1.5)
    endif
EndFunction

Function FaceActor(Actor akActor, Actor akTarget)
    {Make actor face the target}
    
    akActor.SetLookAt(akTarget)
    Utility.Wait(0.5)
    akActor.ClearLookAt()
EndFunction

; =============================================================================
; NATIVE ACTION DISPATCH FUNCTIONS
; These are called by the native DLL when SkyrimNet triggers crafting/cooking/alchemy actions
; The native code does fast item lookup, then dispatches to these for game execution
; =============================================================================

Function CraftItemNative(Actor akActor, string itemName, string formIdStr)
    {Called by native NativeCraftItem action - craft an item at a forge
    itemName: Display name of the item to craft
    formIdStr: FormID string like "0x00012EB7"}

    Debug.Trace("SeverActions_Crafting: CraftItemNative called - " + itemName)

    ; Get the form from the provided FormID string
    Form itemForm = GetFormFromHexString(formIdStr)
    if !itemForm
        Debug.Notification("Cannot craft: " + itemName + " (form not found)")
        return
    endif

    ; Find nearby forge
    ObjectReference forge = FindNearbyForge(akActor)
    if !forge
        Debug.Notification("No forge nearby!")
        return
    endif

    ; Set recipient to player
    Actor recipient = Game.GetPlayer()

    ; Get names for event descriptions
    string crafterName = akActor.GetDisplayName()
    string itemDisplayName = itemForm.GetName()
    string recipientName = recipient.GetDisplayName()

    ; Register persistent event: Started crafting
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " begins crafting " + itemDisplayName + ".", akActor, recipient)

    ; Try to unregister TalkToPlayer
    SkyrimNetApi.UnregisterPackage(akActor, "TalkToPlayer")

    ; Set up forge aliases/package
    ForgeAlias.ForceRefTo(forge)
    CrafterAlias.ForceRefTo(akActor)

    ; Use the crafting package
    ActorUtil.AddPackageOverride(akActor, CraftAtForgePackage, 100, 1)
    akActor.EvaluatePackage()

    ; Wait for NPC to reach the forge
    float maxWait = (SEARCH_RADIUS / 200.0) + CRAFT_TIME
    WaitForArrival(akActor, forge, maxWait)

    ; Wait for crafting animation
    Utility.Wait(CRAFT_TIME)

    ; Remove the package
    ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)

    ; Clear aliases
    ForgeAlias.Clear()
    CrafterAlias.Clear()
    akActor.EvaluatePackage()

    ; Wait for NPC to exit
    Utility.Wait(1.5)

    ; Add crafted item to NPC
    akActor.AddItem(itemForm, 1, true)

    ; Register persistent event: Finished crafting
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " finishes crafting " + itemDisplayName + ".", akActor, recipient)

    ; Walk to recipient and give item
    DeliverItemToRecipient(akActor, itemForm, recipient)
EndFunction

Function CookMealNative(Actor akActor, string recipeName, string formIdStr)
    {Called by native NativeCookMeal action - cook a meal at a cooking pot
    recipeName: Display name of the recipe
    formIdStr: FormID string like "Skyrim.esm|0x00012EB7"}

    Debug.Trace("SeverActions_Crafting: CookMealNative called - " + recipeName)

    ; Get the form from the provided FormID string
    Form itemForm = GetFormFromHexString(formIdStr)
    if !itemForm
        Debug.Notification("Cannot cook: " + recipeName + " (form not found)")
        return
    endif

    ; Find nearby cooking pot
    ObjectReference cookingPot = FindNearbyCookingPot(akActor)
    if !cookingPot
        Debug.Notification("No cooking pot nearby!")
        return
    endif

    ; Set recipient to player
    Actor recipient = Game.GetPlayer()

    ; Get names for event descriptions
    string crafterName = akActor.GetDisplayName()
    string itemDisplayName = itemForm.GetName()
    string recipientName = recipient.GetDisplayName()

    ; Register persistent event: Started cooking
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " begins cooking " + itemDisplayName + ".", akActor, recipient)

    ; Try to unregister TalkToPlayer
    SkyrimNetApi.UnregisterPackage(akActor, "TalkToPlayer")

    ; Reuse forge aliases/package - all workstations work the same way
    ForgeAlias.ForceRefTo(cookingPot)
    CrafterAlias.ForceRefTo(akActor)

    ; Use the same package as forge crafting
    ActorUtil.AddPackageOverride(akActor, CraftAtForgePackage, 100, 1)
    akActor.EvaluatePackage()

    ; Wait for NPC to reach the cooking pot
    float maxWait = (SEARCH_RADIUS / 200.0) + CRAFT_TIME
    WaitForArrival(akActor, cookingPot, maxWait)

    ; Wait for cooking animation
    Utility.Wait(CRAFT_TIME)

    ; Remove the package
    ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)

    ; Clear aliases
    ForgeAlias.Clear()
    CrafterAlias.Clear()
    akActor.EvaluatePackage()

    ; Wait for NPC to exit
    Utility.Wait(1.5)

    ; Add cooked item to NPC
    akActor.AddItem(itemForm, 1, true)

    ; Register persistent event: Finished cooking
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " finishes cooking " + itemDisplayName + ".", akActor, recipient)

    ; Walk to recipient and give item
    DeliverItemToRecipient(akActor, itemForm, recipient)
EndFunction

Function BrewPotionNative(Actor akActor, string potionName, string formIdStr)
    {Called by native NativeBrewPotion action - brew a potion at alchemy lab
    potionName: Display name of the potion
    formIdStr: FormID string}

    Debug.Trace("SeverActions_Crafting: BrewPotionNative called - " + potionName)
    BrewAtAlchemyLab(akActor, potionName, formIdStr, false)
EndFunction

Function BrewPoisonNative(Actor akActor, string poisonName, string formIdStr)
    {Called by native NativeBrewPoison action - brew a poison at alchemy lab
    poisonName: Display name of the poison
    formIdStr: FormID string}

    Debug.Trace("SeverActions_Crafting: BrewPoisonNative called - " + poisonName)
    BrewAtAlchemyLab(akActor, poisonName, formIdStr, true)
EndFunction

Function BrewAtAlchemyLab(Actor akActor, string itemName, string formIdStr, bool isPoison)
    {Internal function for brewing potions/poisons at alchemy lab}

    ; Get the form from the provided FormID string
    Form itemForm = GetFormFromHexString(formIdStr)
    if !itemForm
        Debug.Notification("Cannot brew: " + itemName + " (form not found)")
        return
    endif

    ; Find nearby alchemy lab
    ObjectReference alchemyLab = FindNearbyAlchemyLab(akActor)
    if !alchemyLab
        Debug.Notification("No alchemy lab nearby!")
        return
    endif

    ; Set recipient to player
    Actor recipient = Game.GetPlayer()

    ; Get names for event descriptions
    string crafterName = akActor.GetDisplayName()
    string itemDisplayName = itemForm.GetName()
    string recipientName = recipient.GetDisplayName()
    string actionVerb = "brewing"
    if isPoison
        actionVerb = "concocting"
    endif

    ; Register persistent event: Started brewing
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " begins " + actionVerb + " " + itemDisplayName + ".", akActor, recipient)

    ; Try to unregister TalkToPlayer
    SkyrimNetApi.UnregisterPackage(akActor, "TalkToPlayer")

    ; Reuse forge aliases/package - all workstations work the same way
    ForgeAlias.ForceRefTo(alchemyLab)
    CrafterAlias.ForceRefTo(akActor)

    ; Use the same package as forge crafting
    ActorUtil.AddPackageOverride(akActor, CraftAtForgePackage, 100, 1)
    akActor.EvaluatePackage()

    ; Wait for NPC to reach the alchemy lab
    float maxWait = (SEARCH_RADIUS / 200.0) + CRAFT_TIME
    WaitForArrival(akActor, alchemyLab, maxWait)

    ; Wait for brewing animation
    Utility.Wait(CRAFT_TIME)

    ; Remove the package
    ActorUtil.RemovePackageOverride(akActor, CraftAtForgePackage)

    ; Clear aliases
    ForgeAlias.Clear()
    CrafterAlias.Clear()
    akActor.EvaluatePackage()

    ; Wait for NPC to exit
    Utility.Wait(1.5)

    ; Add brewed item to NPC
    akActor.AddItem(itemForm, 1, true)

    ; Register persistent event: Finished brewing
    SkyrimNetApi.RegisterPersistentEvent(crafterName + " finishes " + actionVerb + " " + itemDisplayName + ".", akActor, recipient)

    ; Walk to recipient and give item
    DeliverItemToRecipient(akActor, itemForm, recipient)
EndFunction

Function DeliverItemToRecipient(Actor akActor, Form itemForm, Actor recipient)
    {Common function to walk to recipient and give item}

    string crafterName = akActor.GetDisplayName()
    string itemDisplayName = itemForm.GetName()
    string recipientName = recipient.GetDisplayName()

    ; Walk to recipient using approach aliases
    RecipientAlias.ForceRefTo(recipient)
    CrafterApproachAlias.ForceRefTo(akActor)
    akActor.EvaluatePackage()

    ; Wait for NPC to reach the recipient
    WaitForArrival(akActor, recipient as ObjectReference, 20.0)

    ; Clear approach aliases
    CrafterApproachAlias.Clear()
    RecipientAlias.Clear()
    akActor.EvaluatePackage()

    ; Small pause to let NPC settle
    Utility.Wait(0.3)

    ; Face the recipient
    FaceActor(akActor, recipient)

    ; Play give animation
    DoGiveAnimation(akActor)

    ; Transfer item
    akActor.RemoveItem(itemForm, 1, false, recipient)

    ; Direct narration: Item handed over
    SkyrimNetApi.DirectNarration(crafterName + " hands " + itemDisplayName + " to " + recipientName + ".", akActor, recipient)

    ; Notify
    Debug.Notification("Received: " + itemDisplayName)

    Debug.Trace("SeverActions_Crafting: Delivery complete")
EndFunction

; =============================================================================
; DEBUG / UTILITY
; =============================================================================

Function ListAllCraftableItems()
    {Debug function to list all items in database}
    
    if !isInitialized
        Debug.Notification("Database not loaded!")
        return
    endif
    
    string[] categories = new string[3]
    categories[0] = "weapons"
    categories[1] = "armor"
    categories[2] = "misc"
    
    int catIdx = 0
    while catIdx < categories.Length
        int categoryObj = JMap.getObj(craftableDB, categories[catIdx])
        if categoryObj != 0
            Debug.Trace("=== " + categories[catIdx] + " ===")
            int keysArray = JMap.allKeys(categoryObj)
            int keyCount = JArray.count(keysArray)
            
            int keyIdx = 0
            while keyIdx < keyCount && keyIdx < 20  ; Limit to first 20
                string keyName = JArray.getStr(keysArray, keyIdx)
                int formIdArray = JMap.getObj(categoryObj, keyName)
                int formCount = JArray.count(formIdArray)
                string firstValue = JArray.getStr(formIdArray, 0)
                Debug.Trace("  " + keyName + " -> " + firstValue + " (+" + (formCount - 1) + " fallbacks)")
                keyIdx += 1
            endwhile
            
            if keyCount > 20
                Debug.Trace("  ... and " + (keyCount - 20) + " more")
            endif
        endif
        catIdx += 1
    endwhile
EndFunction

string Function GetDatabaseStats()
    {Get statistics about the loaded database}
    
    if !isInitialized
        return "Database not loaded"
    endif
    
    int weaponsCount = JMap.count(JMap.getObj(craftableDB, "weapons"))
    int armorCount = JMap.count(JMap.getObj(craftableDB, "armor"))
    int miscCount = JMap.count(JMap.getObj(craftableDB, "misc"))
    
    return "Weapons: " + weaponsCount + ", Armor: " + armorCount + ", Misc: " + miscCount
EndFunction