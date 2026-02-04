Scriptname SeverActions_Currency extends Quest
{Currency/gold action handlers for SkyrimNet integration - by Severause}

; =============================================================================
; PROPERTIES
; =============================================================================

MiscObject Property Gold001 Auto
{Gold coin - set to Gold001 (0x0000000F) in CK, or leave empty for auto-lookup}

Idle Property IdleGive Auto
{Animation for giving gold}

Idle Property IdleTake Auto
{Animation for taking/receiving gold}

Idle Property IdleThreaten Auto
{Animation for threatening/demanding (optional)}

Sound Property GoldSound Auto
{Sound effect for gold transactions}

Bool Property UseGiveAnimation = True Auto
Bool Property UseTakeAnimation = True Auto
Bool Property UseThreatenAnimation = True Auto
Bool Property UseGoldSound = True Auto
Float Property AnimDelay = 0.6 Auto

; Conjured Gold - allows NPCs to give gold they don't have
Bool Property AllowConjuredGold = True Auto

; =============================================================================
; INITIALIZATION
; =============================================================================

Event OnInit()
    Debug.Trace("[SeverActions_Currency] Initialized")
    Maintenance()
EndEvent

Function Maintenance()
    if Gold001 == None
        Gold001 = Game.GetFormFromFile(0x0000000F, "Skyrim.esm") as MiscObject
        if Gold001 == None
            Debug.Trace("[SeverActions_Currency] ERROR: Could not find Gold001!")
        else
            Debug.Trace("[SeverActions_Currency] Gold001 found via auto-lookup")
        endif
    endif
EndFunction

; =============================================================================
; HELPER FUNCTIONS
; =============================================================================

Function PlayGiveAnimation(Actor akActor)
    if akActor && UseGiveAnimation && IdleGive
        akActor.PlayIdle(IdleGive)
        Utility.Wait(AnimDelay)
    endif
EndFunction

Function PlayTakeAnimation(Actor akActor)
    if akActor && UseTakeAnimation && IdleTake
        akActor.PlayIdle(IdleTake)
        Utility.Wait(AnimDelay)
    endif
EndFunction

Function PlayThreatenAnimation(Actor akActor)
    if akActor && UseThreatenAnimation && IdleThreaten
        akActor.PlayIdle(IdleThreaten)
        Utility.Wait(AnimDelay)
    endif
EndFunction

Function PlayGoldSound(Actor akActor)
    if akActor && UseGoldSound && GoldSound
        GoldSound.Play(akActor)
    endif
EndFunction

Int Function TransferGold(Actor akFrom, Actor akTo, Int aiAmount, Bool abAllowConjure = False)
    if !akFrom || !akTo || aiAmount <= 0 || !Gold001
        return 0
    endif
    if akFrom.IsDead() || akTo.IsDead()
        return 0
    endif

    Int available = akFrom.GetItemCount(Gold001)
    Int moved = aiAmount
    
    if abAllowConjure && AllowConjuredGold
        akTo.AddItem(Gold001, moved, False)
        PlayGoldSound(akTo)
        return moved
    endif
    
    if moved > available
        moved = available
    endif
    if moved <= 0
        return 0
    endif

    akFrom.RemoveItem(Gold001, moved, False, akTo)
    PlayGoldSound(akTo)
    return moved
EndFunction

; =============================================================================
; ACTION: GiveGold - NPC voluntarily gives gold to another actor
; Use for: gifts, tips, charity, rewards, generosity
; =============================================================================

Bool Function GiveGold_IsEligible(Actor akGiver, Actor akRecipient, Int aiAmount)
    if !akGiver || !akRecipient || aiAmount <= 0 || !Gold001
        return False
    endif
    if akGiver == akRecipient
        return False
    endif
    if akGiver.IsDead() || akRecipient.IsDead()
        return False
    endif
    
    if AllowConjuredGold
        return True
    endif
    
    return (akGiver.GetItemCount(Gold001) >= aiAmount)
EndFunction

Function GiveGold_Execute(Actor akGiver, Actor akRecipient, Int aiAmount)
    if !akGiver || !akRecipient || !Gold001
        return
    endif
    
    Debug.Trace("[SeverActions_Currency] GiveGold: " + akGiver.GetDisplayName() + " giving " + aiAmount + " gold to " + akRecipient.GetDisplayName())
    
    PlayGiveAnimation(akGiver)
    Int moved = TransferGold(akGiver, akRecipient, aiAmount, True)
    
    if moved > 0
        SkyrimNetApi.RegisterEvent("gold_given", akGiver.GetDisplayName() + " gave " + moved + " gold to " + akRecipient.GetDisplayName(), akGiver, akRecipient)
    else
        SkyrimNetApi.RegisterEvent("gold_failed", akGiver.GetDisplayName() + " has no gold to give", akGiver, akRecipient)
    endif
EndFunction

; =============================================================================
; ACTION: CollectPayment - NPC receives gold owed to them
; Use for: receiving payment after sales, services, trades, settling debts
; The PAYER (target) gives gold to the COLLECTOR (actor)
; If payer is the player, shows a confirmation popup
; =============================================================================

Bool Function CollectPayment_IsEligible(Actor akCollector, Actor akPayer, Int aiAmount)
    if !akCollector || !akPayer || aiAmount <= 0 || !Gold001
        return False
    endif
    if akCollector == akPayer
        return False
    endif
    if akCollector.IsDead() || akPayer.IsDead()
        return False
    endif
    
    ; Payer needs to have gold
    return (akPayer.GetItemCount(Gold001) > 0)
EndFunction

Function CollectPayment_Execute(Actor akCollector, Actor akPayer, Int aiAmount)
    if !akCollector || !akPayer || !Gold001
        return
    endif
    
    Debug.Trace("[SeverActions_Currency] CollectPayment: " + akCollector.GetDisplayName() + " collecting " + aiAmount + " gold from " + akPayer.GetDisplayName())
    
    ; If payer is the player, show confirmation popup
    Actor player = Game.GetPlayer()
    if akPayer == player
        String collectorName = akCollector.GetDisplayName()
        String promptText = collectorName + " is requesting " + aiAmount + " gold.\n\nPay them?"
        
        String result = SkyMessage.Show(promptText, "Yes", "No", "No (Silent)")
        
        if result == "Yes"
            ; Player agrees to pay
            PlayTakeAnimation(akCollector)
            Int moved = TransferGold(akPayer, akCollector, aiAmount, False)
            
            if moved > 0
                if moved < aiAmount
                    SkyrimNetApi.RegisterEvent("payment_collected", collectorName + " collected " + moved + " gold from " + akPayer.GetDisplayName() + " (partial payment)", akCollector, akPayer)
                else
                    SkyrimNetApi.RegisterEvent("payment_collected", collectorName + " collected " + moved + " gold from " + akPayer.GetDisplayName(), akCollector, akPayer)
                endif
            else
                SkyrimNetApi.RegisterEvent("payment_failed", akPayer.GetDisplayName() + " has no gold to pay", akCollector, akPayer)
            endif
            
        elseif result == "No"
            ; Player refuses - send direct narration so NPC reacts
            SkyrimNetApi.DirectNarration(akPayer.GetDisplayName() + " refused to pay " + collectorName, akCollector)
            
        else
            ; "No (Silent)" or timeout - just silently cancel, no event
            Debug.Trace("[SeverActions_Currency] CollectPayment: Player silently declined payment to " + collectorName)
        endif
        
        return
    endif
    
    ; Non-player payer - proceed as normal
    PlayTakeAnimation(akCollector)
    Int moved = TransferGold(akPayer, akCollector, aiAmount, False)
    
    if moved > 0
        if moved < aiAmount
            SkyrimNetApi.RegisterEvent("payment_collected", akCollector.GetDisplayName() + " collected " + moved + " gold from " + akPayer.GetDisplayName() + " (partial payment)", akCollector, akPayer)
        else
            SkyrimNetApi.RegisterEvent("payment_collected", akCollector.GetDisplayName() + " collected " + moved + " gold from " + akPayer.GetDisplayName(), akCollector, akPayer)
        endif
    else
        SkyrimNetApi.RegisterEvent("payment_failed", akPayer.GetDisplayName() + " has no gold to pay", akCollector, akPayer)
    endif
EndFunction

; =============================================================================
; ACTION: ExtortGold - NPC forcibly takes gold through intimidation/threats
; Use for: robbery, mugging, demanding tribute, protection money, coercion
; =============================================================================

Bool Function ExtortGold_IsEligible(Actor akExtorter, Actor akVictim, Int aiAmount)
    if !akExtorter || !akVictim || aiAmount <= 0 || !Gold001
        return False
    endif
    if akExtorter == akVictim
        return False
    endif
    if akExtorter.IsDead() || akVictim.IsDead()
        return False
    endif
    
    ; Victim needs to have gold to extort
    return (akVictim.GetItemCount(Gold001) > 0)
EndFunction

Function ExtortGold_Execute(Actor akExtorter, Actor akVictim, Int aiAmount)
    if !akExtorter || !akVictim || !Gold001
        return
    endif
    
    Debug.Trace("[SeverActions_Currency] ExtortGold: " + akExtorter.GetDisplayName() + " extorting " + aiAmount + " gold from " + akVictim.GetDisplayName())
    
    ; Threaten first, then take
    PlayThreatenAnimation(akExtorter)
    PlayTakeAnimation(akExtorter)
    Int moved = TransferGold(akVictim, akExtorter, aiAmount, False)
    
    if moved > 0
        if moved < aiAmount
            SkyrimNetApi.RegisterEvent("gold_extorted", akExtorter.GetDisplayName() + " extorted " + moved + " gold from " + akVictim.GetDisplayName() + " (all they had)", akExtorter, akVictim)
        else
            SkyrimNetApi.RegisterEvent("gold_extorted", akExtorter.GetDisplayName() + " extorted " + moved + " gold from " + akVictim.GetDisplayName(), akExtorter, akVictim)
        endif
    else
        SkyrimNetApi.RegisterEvent("extortion_failed", akVictim.GetDisplayName() + " has no gold to take", akExtorter, akVictim)
    endif
EndFunction