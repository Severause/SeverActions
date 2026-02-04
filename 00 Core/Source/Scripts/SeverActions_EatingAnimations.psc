Scriptname SeverActions_EatingAnimations Hidden
;{Helper script for playing eating animations from TaberuAnimation.esp (Eating Animations and Sounds)}
;{Optional dependency - gracefully skips if mod not installed}
;{Note: Keywords like EASkey_* are distributed at runtime by Keyword Item Distributor}

; ESP name for the animation mod
String Function GetESPName() Global
    return "TaberuAnimation.esp"
EndFunction

; Check if Eating Animations mod is installed
Bool Function IsInstalled() Global
    return Game.GetModByName(GetESPName()) != 255
EndFunction

; Main function - plays appropriate eating animation for the food item
; Returns true if animation was played, false if skipped
Bool Function PlayEatingAnimation(Actor akActor, Form foodItem) Global
    if !akActor || !foodItem
        return false
    endif
    
    if !IsInstalled()
        return false
    endif
    
    if akActor.IsInCombat() || !akActor.Is3DLoaded()
        return false
    endif
    
    ; Check if item has the master keyword (distributed by KID at runtime)
    if !foodItem.HasKeywordString("EASKID_All")
        return false
    endif
    
    ; Get the animation spell based on food keywords
    Spell animSpell = GetAnimationSpell(foodItem)
    
    if animSpell
        ; Cast the animation spell on the actor
        animSpell.RemoteCast(akActor, None, None)
        return true
    endif
    
    return false
EndFunction

; Stop the eating animation and return to idle
Function StopEatingAnimation(Actor akActor) Global
    if !akActor
        return
    endif
    
    Debug.SendAnimationEvent(akActor, "IdleForceDefaultState")
EndFunction

; Check if item is a drink (for duration calculation)
Bool Function IsDrinkItem(Form foodItem) Global
    if foodItem.HasKeywordString("EASkey_Ale")
        return true
    elseif foodItem.HasKeywordString("EASkey_Wine01")
        return true
    elseif foodItem.HasKeywordString("EASkey_Wine02")
        return true
    elseif foodItem.HasKeywordString("EASkey_AltoWine01")
        return true
    elseif foodItem.HasKeywordString("EASkey_AltoWine02")
        return true
    elseif foodItem.HasKeywordString("EASkey_HonningbrewMead")
        return true
    elseif foodItem.HasKeywordString("EASkey_BlackBriarMead")
        return true
    elseif foodItem.HasKeywordString("EASkey_BlackBriarMeadPrivateReserve")
        return true
    elseif foodItem.HasKeywordString("EASkey_FirebrandWine")
        return true
    elseif foodItem.HasKeywordString("EASkey_SurilieBrothersWine")
        return true
    elseif foodItem.HasKeywordString("EASkey_ArgonianBloodWine")
        return true
    elseif foodItem.HasKeywordString("EASkey_SpicedWine")
        return true
    elseif foodItem.HasKeywordString("EASkey_JugOfMilk")
        return true
    elseif foodItem.HasKeywordString("EASkey_Sujamma")
        return true
    elseif foodItem.HasKeywordString("EASkey_Shein")
        return true
    elseif foodItem.HasKeywordString("EASkey_Suitou")
        return true
    elseif foodItem.HasKeywordString("EASkey_Flin")
        return true
    elseif foodItem.HasKeywordString("EASkey_VelvetLeChance")
        return true
    endif
    return false
EndFunction

; Get the appropriate animation spell for a food item
; Uses EASkey_* keywords which are distributed by Keyword Item Distributor at runtime
Spell Function GetAnimationSpell(Form foodItem) Global
    String esp = GetESPName()
    
    ; ==================== GROUP 01 ====================
    if foodItem.HasKeywordString("EASkey_Ale")
        return Game.GetFormFromFile(0x02AD41E, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_AltoWine01")
        return Game.GetFormFromFile(0x02AD41F, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_AltoWine02")
        return Game.GetFormFromFile(0x02AD455, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_AppleCabbageStew")
        return Game.GetFormFromFile(0x02AD423, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_ArgonianBloodWine")
        return Game.GetFormFromFile(0x02AD425, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_AshHopperLeg")
        return Game.GetFormFromFile(0x02AD427, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_AshHopperMeat")
        return Game.GetFormFromFile(0x02AD429, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_AshYam")
        return Game.GetFormFromFile(0x02AD42B, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_BakedPotatoes")
        return Game.GetFormFromFile(0x02AD42D, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_BeefStew")
        return Game.GetFormFromFile(0x02AD42F, esp) as Spell
    
    ; ==================== GROUP 02 ====================
    elseif foodItem.HasKeywordString("EASkey_BlackBriarMead")
        return Game.GetFormFromFile(0x02AD431, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_BlackBriarMeadPrivateReserve")
        return Game.GetFormFromFile(0x02AD433, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_BoarMeat")
        return Game.GetFormFromFile(0x02AD435, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_BoiledCremeTreat")
        return Game.GetFormFromFile(0x02AD437, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_BraidedBread")
        return Game.GetFormFromFile(0x02AD439, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Bread")
        return Game.GetFormFromFile(0x02AD43B, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_BreadHalf")
        return Game.GetFormFromFile(0x02AD43D, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Butter")
        return Game.GetFormFromFile(0x02AD43F, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Cabbage")
        return Game.GetFormFromFile(0x02AD441, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_CabbagePotatoSoup")
        return Game.GetFormFromFile(0x02AD443, esp) as Spell
    
    ; ==================== GROUP 03 ====================
    elseif foodItem.HasKeywordString("EASkey_CabbageSoup")
        return Game.GetFormFromFile(0x02AD445, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Carrot")
        return Game.GetFormFromFile(0x02AD447, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_CharredSkeeverMeat")
        return Game.GetFormFromFile(0x02AD449, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_ChickenBreast")
        return Game.GetFormFromFile(0x02AD44B, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_ClamChowder")
        return Game.GetFormFromFile(0x02AD44D, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_ClamMeat")
        return Game.GetFormFromFile(0x02AD44F, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_CookedBeef")
        return Game.GetFormFromFile(0x02AD451, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_CookedBoarMeat")
        return Game.GetFormFromFile(0x02AD453, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_DogMeat")
        return Game.GetFormFromFile(0x02AD457, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Dumpling")
        return Game.GetFormFromFile(0x02AD458, esp) as Spell
    
    ; ==================== GROUP 04 ====================
    elseif foodItem.HasKeywordString("EASkey_EidarCheeseWedge")
        return Game.GetFormFromFile(0x02AD45B, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_EidarCheeseWheel")
        return Game.GetFormFromFile(0x02AD45D, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_ElsweyrFondue")
        return Game.GetFormFromFile(0x02AD45F, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_FirebrandWine")
        return Game.GetFormFromFile(0x02AD461, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Flin")
        return Game.GetFormFromFile(0x02AD463, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_GarlicBread")
        return Game.GetFormFromFile(0x02AD465, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_GoatCheeseWedge")
        return Game.GetFormFromFile(0x02AD467, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_GoatCheeseWheel")
        return Game.GetFormFromFile(0x02AD469, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Gourd")
        return Game.GetFormFromFile(0x02AD46B, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_GreenApple")
        return Game.GetFormFromFile(0x02AD46D, esp) as Spell
    
    ; ==================== GROUP 05 ====================
    elseif foodItem.HasKeywordString("EASkey_GrilledChickenBreast")
        return Game.GetFormFromFile(0x02AD46F, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_GrilledLeeks")
        return Game.GetFormFromFile(0x02AD471, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Honey")
        return Game.GetFormFromFile(0x02AD473, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_HoneyNutTreat")
        return Game.GetFormFromFile(0x02AD475, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_HonningbrewMead")
        return Game.GetFormFromFile(0x02AD477, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_HorkerAndAshYamStew")
        return Game.GetFormFromFile(0x02AD479, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_HorkerLoaf")
        return Game.GetFormFromFile(0x02AD47B, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_HorkerMeat")
        return Game.GetFormFromFile(0x02AD47D, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_HorkerStew")
        return Game.GetFormFromFile(0x02AD47F, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_HorseHaunch")
        return Game.GetFormFromFile(0x02AD481, esp) as Spell
    
    ; ==================== GROUP 06 ====================
    elseif foodItem.HasKeywordString("EASkey_HorseMeat")
        return Game.GetFormFromFile(0x02AD483, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_JazbayCrostata")
        return Game.GetFormFromFile(0x02AD485, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_JugOfMilk")
        return Game.GetFormFromFile(0x02AD487, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_JuniperBerryCrostata")
        return Game.GetFormFromFile(0x02AD489, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Leek")
        return Game.GetFormFromFile(0x02AD48B, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_LegOfGoat")
        return Game.GetFormFromFile(0x02AD48D, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_LegofGoatRoast")
        return Game.GetFormFromFile(0x02AD48F, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_LongTaffyTreat")
        return Game.GetFormFromFile(0x02AD491, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_MammothCheeseBowl")
        return Game.GetFormFromFile(0x02AD493, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_MammothSnout")
        return Game.GetFormFromFile(0x02AD495, esp) as Spell
    
    ; ==================== GROUP 07 ====================
    elseif foodItem.HasKeywordString("EASkey_MammothSteak")
        return Game.GetFormFromFile(0x02AD497, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Matze")
        return Game.GetFormFromFile(0x02AD499, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_MudcrabLegs")
        return Game.GetFormFromFile(0x02AD49B, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_PheasantBreast")
        return Game.GetFormFromFile(0x02AD49D, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_PheasantRoast")
        return Game.GetFormFromFile(0x02AD49F, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Pie")
        return Game.GetFormFromFile(0x02AD4A1, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Potato")
        return Game.GetFormFromFile(0x02AD4A3, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_PotatoBread")
        return Game.GetFormFromFile(0x02AD4A5, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_PotatoSoup")
        return Game.GetFormFromFile(0x02AD4A7, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_RabbitHaunch")
        return Game.GetFormFromFile(0x02AD4A9, esp) as Spell
    
    ; ==================== GROUP 08 ====================
    elseif foodItem.HasKeywordString("EASkey_RawBeef")
        return Game.GetFormFromFile(0x02AD4AB, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_RawRabbitLeg")
        return Game.GetFormFromFile(0x02AD4AD, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_RedApple")
        return Game.GetFormFromFile(0x02AD4AF, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SackOfFlour")
        return Game.GetFormFromFile(0x02AD4B1, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SalmonMeat")
        return Game.GetFormFromFile(0x02AD4B3, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SalmonSteak")
        return Game.GetFormFromFile(0x02AD4B5, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SalmonSteakHF")
        return Game.GetFormFromFile(0x02AD4B7, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SearedSlaughterfish")
        return Game.GetFormFromFile(0x02AD4B9, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Shein")
        return Game.GetFormFromFile(0x02AD4BB, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SlicedEidarCheese")
        return Game.GetFormFromFile(0x02AD4BD, esp) as Spell
    
    ; ==================== GROUP 09 ====================
    elseif foodItem.HasKeywordString("EASkey_SlicedGoatCheese")
        return Game.GetFormFromFile(0x02AD4BF, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SnowberryCrostata")
        return Game.GetFormFromFile(0x02AD4C1, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SoulHusk")
        return Game.GetFormFromFile(0x02AD4C3, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SpicedWine")
        return Game.GetFormFromFile(0x02AD4C5, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SteamedMudcrabLegs")
        return Game.GetFormFromFile(0x02AD4C7, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Suitou")
        return Game.GetFormFromFile(0x0330FFF, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Sujamma")
        return Game.GetFormFromFile(0x02AD4C9, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SurilieBrothersWine")
        return Game.GetFormFromFile(0x02AD4CB, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_SweetRoll")
        return Game.GetFormFromFile(0x02AD4CD, esp) as Spell
    
    ; ==================== GROUP 10 ====================
    elseif foodItem.HasKeywordString("EASkey_Tomato")
        return Game.GetFormFromFile(0x02AD4CF, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_TomatoSoup")
        return Game.GetFormFromFile(0x02AD4D1, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_VegetableSoup")
        return Game.GetFormFromFile(0x02AD4D3, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_VelvetLeChance")
        return Game.GetFormFromFile(0x0317AFA, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Venison")
        return Game.GetFormFromFile(0x02AD4D5, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_VenisonChop")
        return Game.GetFormFromFile(0x02AD4D7, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_VenisonStew")
        return Game.GetFormFromFile(0x02AD4D9, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Wine01")
        return Game.GetFormFromFile(0x02AD4DB, esp) as Spell
    elseif foodItem.HasKeywordString("EASkey_Wine02")
        return Game.GetFormFromFile(0x02AD4DD, esp) as Spell
    endif
    
    ; No matching animation found
    return None
EndFunction

; Get animation duration for proper timing
Float Function GetAnimationDuration(Form foodItem) Global
    ; Drinks are slightly shorter
    if IsDrinkItem(foodItem)
        return 4.0
    endif
    ; Soups/stews take longer
    if foodItem.HasKeywordString("EASkey_BeefStew") || foodItem.HasKeywordString("EASkey_VenisonStew") || foodItem.HasKeywordString("EASkey_HorkerStew")
        return 6.0
    elseif foodItem.HasKeywordString("EASkey_CabbageSoup") || foodItem.HasKeywordString("EASkey_TomatoSoup") || foodItem.HasKeywordString("EASkey_PotatoSoup") || foodItem.HasKeywordString("EASkey_VegetableSoup")
        return 6.0
    endif
    ; Default eating duration
    return 5.0
EndFunction