Scriptname SeverActions_Crafting extends Quest
{Crafting system using native DLL databases for fast item lookup.
RecipeDB scans all COBJ records, AlchemyDB scans all AlchemyItem records.
No JSON or JContainers needed - all data comes from game forms.}

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

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    ; Native databases auto-initialize on kDataLoaded in the DLL
    ; No JSON loading needed
    Debug.Trace("SeverActions_Crafting: Initialized (native databases)")
EndEvent

; No JSON database loading needed - native DLL scans all game forms on kDataLoaded

; =============================================================================
; ITEM LOOKUP FUNCTIONS
; =============================================================================

Form Function FindCraftableByName(string itemName)
    {Find a craftable item by name using native databases.
    Searches RecipeDB (smithing + cooking) and AlchemyDB (potions + poisons).
    Returns None if not found.}

    ; Try smithing recipes (forge items)
    if SeverActionsNative.IsRecipeDBLoaded()
        Form result = SeverActionsNative.FindSmithingRecipe(itemName)
        if result
            Debug.Trace("SeverActions_Crafting: Found '" + itemName + "' via native RecipeDB (smithing)")
            return result
        endif

        ; Try cooking recipes
        result = SeverActionsNative.FindCookingRecipe(itemName)
        if result
            Debug.Trace("SeverActions_Crafting: Found '" + itemName + "' via native RecipeDB (cooking)")
            return result
        endif
    endif

    ; Try potions
    if SeverActionsNative.IsAlchemyDBLoaded()
        Form result = SeverActionsNative.FindPotion(itemName)
        if result
            Debug.Trace("SeverActions_Crafting: Found '" + itemName + "' via native AlchemyDB (potion)")
            return result
        endif

        ; Try poisons
        result = SeverActionsNative.FindPoison(itemName)
        if result
            Debug.Trace("SeverActions_Crafting: Found '" + itemName + "' via native AlchemyDB (poison)")
            return result
        endif
    endif

    Debug.Trace("SeverActions_Crafting: '" + itemName + "' not found in any native database")
    return None
EndFunction

int Function HexToInt(string hexStr)
    {Convert hex string (with or without 0x prefix) to integer}
    return SeverActionsNative.HexToInt(hexStr)
EndFunction

Form Function GetFormFromHexString(string hexString)
    {Convert a hex string like "Skyrim.esm|0x00012EB7" to a Form.
    Returns None if the plugin isn't loaded or form doesn't exist.
    Used by native dispatch functions (CraftItemNative, CookMealNative, etc.)}

    int pipeIndex = StringUtil.Find(hexString, "|")

    if pipeIndex >= 0
        string pluginName = StringUtil.Substring(hexString, 0, pipeIndex)
        string formIdPart = StringUtil.Substring(hexString, pipeIndex + 1)

        if !Game.IsPluginInstalled(pluginName)
            return None
        endif

        int formId = HexToInt(formIdPart)
        return Game.GetFormFromFile(formId, pluginName)
    else
        int formId = HexToInt(hexString)
        return Game.GetForm(formId)
    endif
EndFunction

string Function StringToLower(string text)
    {Convert string to lowercase for case-insensitive comparison}
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

ObjectReference Function FindNearbyOven(Actor akActor)
    {Find the nearest oven within search radius - for baked goods}
    return SeverActionsNative.FindNearbyOven(akActor, SEARCH_RADIUS)
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

    ; Check if item exists in native databases
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

    ; Direct narration: Item already transferred (past tense so LLM doesn't repeat the give)
    if itemCount > 1
        SkyrimNetApi.DirectNarration(recipientName + " has received " + itemCount + " " + itemDisplayName + " from " + crafterName + ". The item is now in " + recipientName + "'s inventory.", akActor, recipient)
    else
        SkyrimNetApi.DirectNarration(recipientName + " has received " + itemDisplayName + " from " + crafterName + ". The item is now in " + recipientName + "'s inventory.", akActor, recipient)
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

    ; Check if this recipe needs an oven (baked goods) or a cooking pot
    bool needsOven = SeverActionsNative.IsOvenRecipe(recipeName)

    ; Find the appropriate workstation
    ObjectReference cookingPot = None
    if needsOven
        cookingPot = FindNearbyOven(akActor)
        if !cookingPot
            ; Fallback: try a regular cooking pot if no oven found
            cookingPot = FindNearbyCookingPot(akActor)
        endif
    else
        cookingPot = FindNearbyCookingPot(akActor)
    endif

    if !cookingPot
        if needsOven
            Debug.Notification("No oven nearby!")
        else
            Debug.Notification("No cooking pot nearby!")
        endif
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

    if needsOven
        Debug.Trace("SeverActions_Crafting: CookMeal - Walking to oven")
    else
        Debug.Trace("SeverActions_Crafting: CookMeal - Walking to cooking pot")
    endif

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

    ; Direct narration (past tense so LLM doesn't repeat the give)
    if itemCount > 1
        SkyrimNetApi.DirectNarration(recipientName + " has received " + itemCount + " " + itemDisplayName + " from " + crafterName + ". The item is now in " + recipientName + "'s inventory.", akActor, recipient)
        Debug.Notification("Received: " + itemDisplayName + " x" + itemCount)
    else
        SkyrimNetApi.DirectNarration(recipientName + " has received " + itemDisplayName + " from " + crafterName + ". The item is now in " + recipientName + "'s inventory.", akActor, recipient)
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

    ; Direct narration (past tense so LLM doesn't repeat the give)
    if itemCount > 1
        SkyrimNetApi.DirectNarration(recipientName + " has received " + itemCount + " " + itemDisplayName + " from " + crafterName + ". The item is now in " + recipientName + "'s inventory.", akActor, recipient)
        Debug.Notification("Received: " + itemDisplayName + " x" + itemCount)
    else
        SkyrimNetApi.DirectNarration(recipientName + " has received " + itemDisplayName + " from " + crafterName + ". The item is now in " + recipientName + "'s inventory.", akActor, recipient)
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

    SkyrimNetApi.DirectNarration(recipientName + " has received " + itemDisplayName + " from " + crafterName + ". The item is now in " + recipientName + "'s inventory.", akActor, recipient)

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

    ; Direct narration (past tense so LLM doesn't repeat the give)
    SkyrimNetApi.DirectNarration(recipientName + " has received " + itemDisplayName + " from " + crafterName + ". The item is now in " + recipientName + "'s inventory.", akActor, recipient)

    ; Notify
    Debug.Notification("Received: " + itemDisplayName)

    Debug.Trace("SeverActions_Crafting: Delivery complete")
EndFunction

; =============================================================================
; DEBUG / UTILITY
; =============================================================================

string Function GetDatabaseStats()
    {Get statistics about the native databases}

    string result = ""
    if SeverActionsNative.IsRecipeDBLoaded()
        result += "RecipeDB: loaded"
    else
        result += "RecipeDB: NOT loaded"
    endif

    if SeverActionsNative.IsAlchemyDBLoaded()
        result += ", AlchemyDB: loaded"
    else
        result += ", AlchemyDB: NOT loaded"
    endif

    return result
EndFunction