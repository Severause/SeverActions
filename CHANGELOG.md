# SeverActions Changelog

## v4.2.0 - Colours and Clarity

Magelight UI 0.31.2 is bundled (`98 Magelight UI`):

- Page shapes are anti-aliased again: icons, curves and the quick wheel's slices have smooth edges. `"msaa"` in `Magelight.json` sets it (1 off, 2, 4 or 8; 4 by default).
- After a save loads, pages that are not open load one per frame instead of all at once, which smooths the first seconds of play.
- A page's ordinary console output is no longer written to `Magelight.log`; warnings and errors still are, and `"consoleLog": "all"` brings the rest back.
- A second, Windows mouse pointer no longer stays on screen after closing a menu.
- VR: arrow keys, Delete, Insert, Home, End, Page Down, numpad Enter and numpad Divide type into pages; held keys repeat; the numpad types digits with NumLock on.
- `"toggleKey"` in `Magelight.json` takes a key name ("F3", "PageDown") as well as a scancode, and the log warns about a number that is not a scancode.

Five colour themes for every SeverActions page, popup and the quick wheel, picked in Settings > UI Display: The Ledger (today's look, the default), Windhelm Slate, Dwemer Verdigris, Soul Cairn and Jarl's Vellum, a light theme. With Magelight 0.31.1 or later the cursor takes the theme's colours too. Status, hold, school and money colours keep their meaning in every theme. The Enterprises popup for hiring or managing a retainer follows the theme too, with a new layout: the people to choose from beside the terms, occupation tiles, and a line at the bottom that sums up the hire.

Slot presets stay on after fast travel, sleep and waiting. SeverActions re-applied a preset when a follower loaded and never looked again, so a re-dress by the game or the follower's own mod went unnoticed, and nothing re-checked after a sleep or a wait. It now re-checks a few seconds after every load, sleep or wait, one follower per frame, and re-applies only when another outfit has been put on or a preset piece is missing. A follower's sleep outfit no longer dresses them over a preset either. Situation outfits also switch again right after you close the menu: after editing someone on the Outfits page, their outfit changes stayed paused for up to five minutes.

A follower's inventory shows the armour they carry again. The page hid every item that matched the follower's default outfit, so a piece you freed from it, or a plain copy you gave them, stayed hidden; it now hides only the game's own outfit copies, a note says how many, and a worn one can be taken off with the new Take off button on the character sheet. Giving, selling, dropping and destroying never take an outfit copy. The warmth meter now reads 100% for a full set of warm gear, so ordinary armour no longer shows as "Bare".

Turning off a spell on the Spells page now really stops a follower casting it. A spell from the NPC's own record (a mage follower's Flames) used to stay known while the page showed it off; it is now removed from the record, and turning it back on restores it. Spells from a record other NPCs share, or from a template, cannot be removed for one NPC alone: the page shows their toggle dimmed and says why. Innate spells carry an "Innate" badge.

The quick wheel holds up to twelve slots and draws only the ones you fill, evenly spaced, with every name kept inside its slice.

The Work row on the Companions page places a plain work mark again with Enterprises installed, like Home and Relax, instead of hiring the NPC as your retainer: an NPC can now work for someone else and still keep a routine. Hiring stays on the Enterprises board, which lists a work mark with no terms.

Retainer work stories can be muted: one retainer, a whole hold or a sworn camp on the Enterprises page, or every retainer in a job or on certain terms in Settings > AI. Their gold and goods still settle. Retainers who are dead, captive or gone no longer use up a story at all. Off-screen events no longer write diary entries that put you in the scene, and Settings > Off-Screen Events can turn those diary entries off.

Settings > Hotkeys: a key capture always ends (after a key, Esc, a refusal or ten seconds), clearing a key redraws its row, and in VR the page says keyboard capture is not available there and warns when the menu chord clashes with another binding.

The Life Tracker no longer marks every letter read the moment it opens: only the letter shown at the top is read, and in the Unread view the letters you read stay listed until you change the filter. The World page's first open no longer freezes the game for most of a second, and travel to a named place no longer hitches on the same lookup.

The interface reads more plainly: the over-written wording across the Dashboard, the Actions page, Survival, Enterprises, the Life Tracker, World and the help text says what each thing is, while The Hearth Ledger and Writ & Command keep their names. The hotkey names on Settings > Hotkeys are translated. The Russian translation is corrected throughout, with one word per term (спутник, униформа, управитель, подручный, задание), names no longer forced into the wrong case, and the same hotkey names in the menu and the MCM.

The installer no longer depends on how a FOMOD installer reads an unset choice: the module scripts now always install, so installs made with FOMOD Plus that came out missing scripts get all of them.

Installing this version: install it over 4.1.x with Replace. The installer's pages and choices are the same, and saves load as they are.

## v4.1.0 - Quicker Commands

Magelight UI 0.30.5 is bundled (`98 Magelight UI`):

- With DLSS or frame generation behind NVIDIA Streamline (Community Shaders' and Open Shaders' upscalers among them), SeverActions' menus no longer open invisible: they are drawn in the game's own interface pass.
- With Community Shaders' frame generation, the menus show again: Magelight no longer writes past the end of that swapchain's function table, which turned its renderer off at startup.
- With NVIDIA Smooth Motion, opening the menu no longer freezes the game: Magelight draws with the game's own graphics device there.
- If the graphics device is lost, Magelight turns itself off instead of leaving the game paused under a menu that cannot draw.
- A new mouse cursor, drawn sharp at any resolution, and only one of it: the game's own menu cursor no longer shows under or over the page.

When Magelight UI cannot draw at all, the menu key and the quick wheel key now say so on screen and point to `Magelight.log`, instead of doing nothing. A menu or popup that could not take focus no longer leaves the game half in menu mode, with other mods' hotkeys muted, until the next time a menu opened.

Wait and Follow answer at the first press. Each command used to undo everything SeverActions could have put on a follower, whether it was there or not: about forty steps that each wait for the next frame, for every follower, every time. It now checks once what is actually there and undoes only that, so a custom follower SeverActions only tracks takes about ten steps instead of forty, and Wait All and Follow All over a full party finish in a second or two. The Companions page updates when the command has finished instead of half a second after the click, when it still showed the old state. A custom follower told to wait is no longer let go for a moment in the middle of the command, which gave their own mod time to make them follow again.

Loading is faster. On a long-running save, SeverActions' start-up after a load took about a minute and now takes about twelve seconds, and a follow or wait command given right after a load no longer waits behind it for twenty seconds or more. Most of the time went on walking pools of hundreds of empty slots one by one; those walks now visit only the filled ones. The load logs also report how long each step of SeverActions' start-up took.

Companions in the follow pool are no longer pushed back onto their follow package every few seconds. The check that notices a companion drifting off their follow package did not know the pool's own copies of those packages, so it read every companion seated there as drifted and re-applied the package five times every five seconds, then every five minutes, all session.

The quick wheel and the menu key work again when bound to a mouse or gamepad button (M3, M4 or M5, for example), as they did before 4.0. Settings > Hotkeys can now capture the mouse's extra buttons, and names mouse and gamepad buttons instead of showing "Key 259".

In Tracking mode, casual follow works again for an NPC no follower framework leads: they follow, wait and resume as in SeverActions mode. Recruiting someone who was casually following you hands them over to their framework cleanly. The Companions page now shows the framework mode the game is actually using; it read an older copy of the setting, which could disagree. With Debug mode on, a notice names each follower SeverActions stops leading after a load because Tracking mode is on.

The Outfits page's live mirror, on Magelight's CPU renderer, starts the Live Stage on its own and shows the NPC there instead of an empty hole through the menu. In VR it shows a dark box with a short hint instead of whatever was behind the panel.

Installing this version: install it over 4.0.x with Replace. The installer's pages and choices are the same, and saves load as they are.

## v4.0.2 - Hotfix

Magelight UI 0.30.3 is bundled (`98 Magelight UI`). It fixes three problems in 4.0.1:

- The game crashing at startup alongside Community Shaders, or about eight minutes into play with ENB or an upscaler (an access violation in `d3d11.dll`).
- The game crashing at startup with ENB, with no crash log.
- SeverActions' menu being cut off on screens under about 1067 pixels tall (1366x768 or 1600x900, for example), where only the top-left part of the menu showed.

If you made a `Magelight.json` with `"presentHook": "vtable"` to work around the ENB crash, you can delete it. Nothing in SeverActions itself changed: install it over 4.0.1 with Replace, and saves load as they are.

## v4.0.1 - Hotfix

Magelight UI 0.30.2 is bundled (`98 Magelight UI`). It fixes two problems some players hit with 4.0.0:

- The game crashing at startup or when the menu opened, alongside some SKSE mods that hook the game window (the crash log showed USER32 calling an address like `0xFFFF...`).
- SeverActions' menus opening (the sound played and the game paused) but staying invisible with Skyrim Upscaler, frame generation included, or behind other mods that hook the game's frame output.

Nothing else changed: install it over 4.0.0 with Replace, and saves from 4.0.0 load as they are.

## v4.0.0 - Words and Deeds

Skyrim VR: loading a long-running save as the first load after starting the game no longer freezes the game for good. SeverActions' menus handed their work to the game from inside the frame Magelight UI was drawing, and on VR, right after a load, that could wait forever on the game's own background work; they now hand it over from a helper thread. A VR controller chord for the menu or the quick wheel now toggles what was open when you pressed it, and a VR controller rebind still waiting for a press when the menu closes is cancelled instead of catching your next button press in play.

SeverActions' menus and prompts: a choice made on a prompt that has meanwhile been closed and opened again is dropped instead of being applied to the new one, a diary entry picked just as the viewer closes is no longer lost, a second quick click in the diary no longer reads the entry aloud twice, and a summon, teleport or camp muster sent just as the menu closes happens at once instead of waiting for the next time you close the menu.

Companions can have portraits. On the Companions page, press Add portrait under a companion's frame and pick any picture on your computer with the menu's own file browser (with shortcuts to Pictures, Desktop, Downloads, your Skyrim folder and Steam screenshots). A resized copy (up to 2048 pixels) is kept for that NPC in every save; the original file is untouched. Adjust frames it: drag the picture inside its circle and zoom with the slider or the mouse wheel (it opens by itself after you pick a new picture). The roster shows the portrait too, and each companion's sheet now shows their health, stamina and magicka and what they are doing right now, and where.

Portraits now show wherever SeverActions lists an NPC: retainers on the Enterprises board, the Summary's top earners, Stories, the applicant, camp members and hired workers; the Outfits, Inventory and Actions lists; the Life Tracker's letters and senders; the Dashboard's chronicle and your closest companion; prisoners, guards and captives on the Arrests page; and the wanted list. A retainer's dossier on the board has the same Add portrait, Change and Adjust buttons as the Companions page, so a retainer who never followed you can have one too. An NPC without a portrait keeps the sign they had.

You can have a portrait too: press Add portrait under the circle beside your name on the Dashboard. Each playthrough keeps its own, so another character on the same install does not share it, and it shows wherever you appear beside your companions (the Inventory, Catalog and Actions lists). The NPCs you gave a home (Companions → Assigned NPCs) show their portraits on their cards, with the same Add portrait, Change and Adjust buttons, so they no longer have to be recruited again to get one.

NPCs choose actions more carefully. Talking about a plan, a maybe or a trip for later ("we could go to Whiterun some time") no longer sends them off travelling, and the same holds for every other action: an NPC acts on what they agree to, are told to do or decide to do in the line they just spoke, while promises, suggestions, questions, jokes and threats of what they will do later stay words. Every SeverActions action now sits in a category that the AI opens before it picks the action itself, which gives it a second look and a way to back out: Arrest, Brawl, Camping, Combat, Crafting, Economy, Employment, Items, Magic and Outfit as before, and the new Journeys, Furniture, Companionship, TagAlong, Captives, CampChallenge, AmbushStandoff, OutlawCamp, Taxes and Arousal (ArousalSLO for SL Aroused). Some actions are now offered only to the people who can use them: the camping actions only to your followers, the persuasion verdict only to guards, and the jarl's tax relief and tax rise only while hold taxes are on. Someone still cooling off from a fight, a surrender or a truce no longer accepts a fist-fight, and a guard no longer decides on their own to arrest you when you have no bounty in their hold. When someone hands you a house or a business, you are now asked to confirm before the deed changes hands. Smiths on an install without powerofthree's Tweaks (Skyrim VR among them) now know how to take and hand over commissions: the forge instructions looked the smith faction up by a name only that mod keeps. Someone tagging along behind you, or waiting where you told them to, now counts as a follower for the Followers Can Travel setting, so with it off (the default) they are no longer sent off on trips either. The companion Wait and Follow actions are renamed WaitForPlayerHere and ResumeFollowing: SkyrimNet's own CompanionWait and CompanionFollow replaced SeverActions' actions of the same names after every load, and SkyrimNet's wait took a SeverActions companion off their follow package, so they wandered off until SeverActions noticed a few seconds later and made them wait wherever they had got to. SkyrimNet 0.25 no longer has its own two. If you had changed either one's settings in SkyrimNet (switched it off, gave it a cooldown), set them again on the new name. Every other action keeps its name and your settings for it. The Travel Destination Popup (Settings → Travel), when it is on, is still the backstop: it asks you to confirm or redirect the destination before the NPC sets off.

Character profiles and background AI prompts were reviewed line by line. Companions now remember their life away from you: the "What You've Been Up To" section of a dismissed or home-stationed companion and the local gossip never appeared, and now do, with "yesterday" or "three days ago" ageing as time passes. The off-screen life story knows which companions travel with you, so it stops writing adventures for them, and animal companions no longer get human lives. When a kidnapped NPC comes home, their hold's gossip says they turned up instead of that they vanished.

Relationship assessments now read what you say by voice or through vanilla dialogue, and the assessment between two companions sees them talk. Spouses are now recognised: the familiarity, intimacy and reputation sections looked for your marriage in a value SkyrimNet does not provide. The intimacy and consent layer no longer applies to children in any form, and female characters are no longer written as "hers" before a noun ("hers personality"). An SL Aroused NPC whose arousal has not been read yet is no longer described as very aroused, and private arousal changes and a conception are no longer announced to everyone nearby.

The Imperial Levy's fifteen characters have their personalities again. SkyrimNet 0.25 stopped reading the folder their bios shipped in, so the General, the Legates and the twelve soldiers spoke with no background at all; the bios now ship where SkyrimNet reads them, with shorter public summaries. The twelve patrol soldiers are no longer given the Legates' orders to escort the General, their bios no longer say they patrol only in daylight, and courts are told the soldiers patrol their holds rather than wait with the General.

The Imperial Levy now keeps court in Solitude. General Cassius Vero and his two Legates are quartered at the Blue Palace as guests of Jarl Elisif's court instead of at Dragonsreach, since Whiterun stays out of the war until you pick a side. Optio Sabina Prisca's squad of four now patrols Solitude, where the General keeps court, and reports to him in person every day; Decanus Postumus Varro and Battlemage Tullia Bassa have taken over Whiterun, which now has two soldiers like the other holds. If your save already has the detail in Dragonsreach, the General and his Legates move once, while you are in neither Dragonsreach nor the Blue Palace and none of them is in sight, and the two squads trade cities once, the next time you are well away from both cities (not just outside their walls) and none of their soldiers is in sight; until then, they know where they still stand. Then Skyrim's people hear that the Treasury's detail has moved, so what they remember of the General at Dragonsreach does not contradict where he is now.

SkyrimNet's log no longer fills with "Faction with editor ID 'SexLabAnimatingFaction' not found" warnings when you do not use SexLab or OStim: the actions and prompts that stay away from an NPC mid-scene now ask SeverActions whether someone is in a SexLab or OStim scene instead of naming the two factions. On Skyrim VR the check works for the first time (it used to see no scene at all), so actions are kept away from NPCs mid-scene there too.

The StopUsingFurniture action is gone: an NPC SeverActions sat down (SitOrLayDown, a companion taking a seat beside you, a follower's bed at home) already gets up by themselves once you move away (Furniture Auto-Stand Distance in Settings), so the AI no longer has a separate action to call for it. The Stand Up hotkey and quick wheel slot stay. A copy you saved in SkyrimNet's action editor keeps it offered: delete that copy too if you want it gone.

An NPC told to cast a spell (the CastSpell action) while holding a weapon no longer has to put it away first: the spell now goes into whichever hand the game picks, instead of always the right hand.

A follower can now be kept to their own food: the Survival page's Shares food / Own food choice on each companion's card switches a follower between sharing the party's food and eating only what they carry. A follower on their own food is never fed from the player's or anyone else's pack (when hungry, by the Feed button or by Distribute rations), and nobody else is fed or cooks from theirs; the page's pantry and rations count show only the food the party shares.

The Catalog is redesigned. Click any item to open it in a new inspector beside the list: the item turns in 3D (drag to rotate, wheel to zoom, like the Inventory's), with its stats, its enchantment or potion effects, the spell a tome teaches, and the mod it comes from. The inspector has a Give button for everyone in your party, and for armor the undress-protection switch, now with a plain explanation. The list shows each item's mod under its name, so the four "Shield of Solitude" rows can be told apart, marks enchanted items with ✦, and always shows its Give button. Slot, type and quantity are chips instead of pop-up pickers, and clicking a column heading sorts by it (armor by rating, weight or value; weapons by damage or value; potions by magnitude); armor and weapons now really list by name, where they used to list in load order. The Give To list shows your companions' portraits, and the inspector lists what you have given this session.
Sever's Hearth has a small camp. Small Camp (a new button beside Set Up Camp on the Survival page, a hotkey you can bind in Settings > Hotkeys, and a quick wheel slot) makes a camp for you and one or two companions: a fire with a cooking spit, your bedroll under a small tent, two more bedrolls, a seat, the supplies pack, firewood and the stash chest (when you have no base). You place it with the same ghost as the full camp, and it can be made indoors too, in caves, dungeons, ruins and Blackreach, where it has no tent. Only you can make one indoors; a companion asked to set up camp inside still refuses. A small camp never becomes the base, and an indoor one is not marked on the map and is not a place to send companions to: they come back to it with you. Companions hear what kind of camp it is, and one indoors counts as sheltered.

The Enterprises page copes with long lists. Holds has a search box (name, trade, hold or whereabouts), filters for who needs attention, who is in jail and who has gold waiting, and each trade or hold section folds away, with Fold all and Unfold all; the page remembers what you folded. Camps puts your sworn camps first and shows the known camps as compact tiles, grouped leaderless first or by hold, with a search box and a filter by kind of camp; a camp card lists six members, chief and lieutenants first, with Show all for the rest. On the Summary, three or more alerts of one kind (retainers in jail, owed wages, asking for a raise) become one line that opens to the names. Labor has a search box and folding holds, and each employer lists five workers before Show all. Stories has a search box over the roster and shows a retainer's latest twenty entries first. On Obligations and Commissions, the infractions, the wanted list, your debts and past commissions show eight rows before Show all, and a long wanted list gets its own search box.

The Survival page is redesigned. Each companion has a card with their portrait, a bar for hunger, cold, fatigue and clothing warmth that shows how close the next stage is, a warning of when they will be famished, a Feed button, a Tracked switch and the Shares food / Own food choice. The camp and the base share one card, which is a single line with Set Up Camp while nothing is pitched, and the pantry lists each food with who carries it, its count, its weight and its share of the pack, with the recipes you can cook right now first. The three headline verdicts are coloured by how things stand. The party summary no longer says "all fed" while a companion reads Hungry: both now count from the stage the card shows. The pantry no longer ends up in a half-width corner under an empty base panel, and the plan box next to Set Up Camp is no longer squashed to a dark square.

Arrests: a released prisoner is no longer described as locked up, jailed NPCs are recognised on Skyrim VR, and one arrest anywhere no longer wipes every NPC's knowledge of bounties. Jarls, housecarls and stewards are no longer told "as a guard" that they can arrest you, and the NPC a guard is sent for learns of the arrest only once it happens. A captive led by the wrist is no longer described in a collar, a hooded captive being led is no longer told they can see, and a captive tied to furniture is described as tied. On an install without powerofthree's Tweaks (Skyrim VR among them), NPCs can now add to, reduce, forgive and repay debts, a prisoner can plead with the guard marching them to jail, and a guard in the middle of an arrest or a home search is no longer given new arrest orders or sent off travelling: these actions looked for faction names only that mod keeps. The plea is now offered only during the march, and only once per arrest.

A truce now ages on the right clock, a resolved fight stops being brought up, and NPCs in an ordinary fight are no longer told "You are currently fighting ."; a camp sworn to you by vote is no longer told its chief died at your hand. A retainer who turned on you is no longer listed as in your service or offered as a payout, the retainer hearing now offers NegotiateTerms, and a retainer's loan is no longer collected twice: paying it back in conversation or forgiving it from the ledger now lowers or ends the weekly repayment, and a save already affected corrects itself at the next weekly settlement. Hired workers read "You work for" rather than "You works for", job titles take the right article ("an Alchemist"), an untitled custom job reads "worker" rather than "Custom", and counts read "1 day" or "3 days" rather than "day(s)".

Event and narration text NPCs read now names you instead of "the player" and drops system wording such as "detected and onboarded". A brawl that turns into a real fight no longer names a winner, and Sever's Hearth narrations no longer hand the AI a raw template tag instead of a name. Only your companions are told about your Hearth camp now, where every NPC in Skyrim used to be told they shared it. Your inventory is no longer copied into every background AI prompt, and instructions to use an action (debts, forge commissions, arrests, taxes, hearings) now appear only in an NPC's conversations, not in their thoughts, diary or memories. With Outfit Actions installed, worn equipment in character profiles now shows SkyrimNet's quality tags (Fine, Flawless): SeverActions adds its notes beside SkyrimNet's own equipment section instead of replacing it.

Several action parameters have plainer names for the AI now (destination instead of placeName, and recipient, amount or item in place of the old coded names); the scripts behind them are unchanged. If you edited a SeverActions action in SkyrimNet's action editor, SkyrimNet saved a full copy of it that stands in for ours, and that copy keeps its old text, its old parameter names and its old place outside the categories: delete it and redo your edit on the new version. The lines actions leave in the history NPCs read later changed too. An action whose outcome SeverActions already records, or that can still be refused after the NPC agrees, no longer writes a line of its own that could repeat, contradict or invent what happened: recruiting or dismissing a companion, a companion walking out, telling one to wait or follow again, assigning a home, the captive actions, spell and Shout lessons, reducing or repaying a debt, a guard sent to make an arrest or search a home, appointing a hold steward, paying the Final Audit and the Sever's Hearth camp actions among them. A line is now recorded when an outlaw lets you through their camp or turns the camp on you, and when you refuse or forgive a retainer's loan.

Companions now sit down with you. When you take a chair, stool, bench or throne, the companions following you take the nearest free seats around you and get up again when you do; switch it off with Companions Sit When You Sit in Settings → Followers → Behavior (on by default). Companions who are waiting or busy are left alone, and so are followers another framework leads (NFF, Serana, custom-AI followers) unless you turn on Include Followers Led by Other Frameworks beneath it; it does nothing in the Tracking recruitment mode. A companion you sit beside right after loading a save no longer gets straight back up. NPCs are no longer offered a chair, bench or bed someone else is using (your own bed stays open to them), and an NPC who picks one that was taken in the meantime goes to the nearest free one of the same kind nearby instead of giving up. A bench with you on one end still has room for a companion on the other. The "already taken" line no longer stays in an NPC's history for good, telling a seated companion to follow you now stands them up, and someone you sent to sit before saving still gets up when you walk away after loading.

Safe Interior Sandbox: a follower you tell to wait inside an inn, home or shop now stays there when you leave. The relax treated the wait as its own and either cancelled it, bringing them out after you, or teleported them to you while they kept standing still; a wait given through the vanilla or NFF follower dialogue while they were relaxing is kept too. Turning the Safe Interior Sandbox off no longer pulls waiting followers out either.

Guards who have made an arrest or searched a home are offered the arrest actions again. Taking a guard off the job left a stray mark that SkyrimNet read as "still busy", so after one arrest or dispatch that guard could not arrest, dispatch or search again for the rest of the save. Guards in existing saves are fixed without starting over. A hired guard on a work shift, especially one assigned to guard a person, now really leaves their post to make an arrest they agree to, instead of reporting it done and staying put, and goes back to work once their part is over. The escorting guard can also accept or turn down a prisoner's mid-escort plea again; before, every plea simply waited out its timer.

A retainer's weekly work story no longer has them trading or drinking with someone who is sitting in a jail cell: the story now knows who is held in which jail, and anyone it names from that list is written as jailed - missed at work, visited in the cells, or with their business in someone else's hands. A week's story that names someone who has died is dropped, and that person is not given a memory of the meeting; a letter the week requires (a raise request, or being caught skimming) still arrives. A dismissed companion who lands in jail spends their off-screen life in the cell, with no off-screen arrests, bounties or purchases while held; other jailed companions are only ever visited, and an off-screen event shared with someone who has died is dropped.

Looting after a fight: an NPC who looted or searched a body no longer stays down on one knee when the game ignores the call that ends the kneel; a standing looter now gets a firmer reset and goes back to what they were doing. Two NPCs looting at the same time no longer send each other to the wrong body or leave one standing still until the walk gave up: each walker now heads for their own target. The line SeverActions gives SkyrimNet when a fight ends with valuables on the fallen, which is what invites NPCs to loot on their own, can now be switched off (Point Out Spoils After a Fight, Settings → Prompt Filters → Combat Context), and by default it is only given when one of your companions (not a summon) is nearby, so a fight you win alone no longer sends strangers to loot.

Brawls: a knockout now counts only when the opponent landed it. If someone outside the fight knocks a fighter down (a dragon passing overhead, a guard, or you and your followers in someone else's brawl), the brawl ends with no winner instead of handing the opponent the win, and the two fighters are not set on each other afterwards; the downed fighter is still named as the loser. An outside hit while both are standing still breaks the brawl into a real fight, as before.

The Bio Blocks page is redesigned for large libraries. Categories sit in a column on the left, the blocks in a searchable grid of cards beside them (each card shows its category colour, its opening lines and how many carry it), and the block you pick is shown in full on the right, with who carries it (each removable) and its Apply to…, Edit, Duplicate and Delete buttons always in view instead of appearing only on hover. Apply to… opens a window with people (your crosshair target, companions, nearby NPCs) beside whole factions, ticked where they already carry the block, and stays open so one block can go to several people. The factions side has its own search over every faction in your load order, not only those of the people around you, and shows each faction's EditorID and plugin so two factions of one name can be told apart. On the Rules view, + Faction Rule first asks for the faction (the same search), then opens the library with a tick on every block that faction grants; tick or untick and save once. Each rule's card has an Edit button that opens straight to its blocks. The Applied and Rules views show a card per character or faction with its blocks. Template tags in block text, such as the NPC's name, read as small tokens instead of raw code. On the Companions page, Apply from Library opens the same library in a window for that character: tick the blocks they should carry, untick ones to remove, and save once.

Other mods can now add their own Bio Blocks to your library and apply them to NPCs. A block a mod provides shows which mod it comes from and cannot be edited, since the mod keeps its text up to date; you can move it to another tab, or use Duplicate as my own to make an editable copy. Deleting one hides it: it leaves the NPCs it was applied to, the mod does not bring it back, and Hidden on the Bio Blocks page restores it. Mod authors: the guide installs to Data/SKSE/Plugins/SeverActions/API/BIO_BLOCKS_API.md.

Outlaw Truce: with the truce turned off (the default), loading a save no longer calms nearby bandits for a few seconds. Before, the first pass after a load ran before the save's truce setting was read, so it could stop a fight in progress, strip the outlaws' faction for a moment, register their camp and even send a camp challenger over. The load now reads the save's setting before that pass, so a disabled truce never pacifies anyone. A camp chief who walks over to question you no longer keeps staring at you after letting you pass or turning you away.

A retainer who defaults on a loan you gave them no longer sends hired thugs after you. The default armed the same grudge as walking out over unpaid wages, so the thugs' letter and threats claimed you had stiffed them on wages, and forgiving the loan did not call them off. A default now only costs a little renown and bars new loan requests until you forgive it. A grudge a default already armed in your save is dropped before it can fire: only a retainer who has left your service sends thugs. A retainer who already sent thugs over a default no longer turns hostile the first time they genuinely quit, and a Fence who walks out can no longer be arrested in the same week and then released back to work for you.

Sending an NPC somewhere new while they are already on a journey (a redirected TravelToPlace, or a kidnapper moving a captive on from the spot they were grabbed) no longer leaves them standing where they were. The pool seat the first journey had just given up was taken by the new one in the same moment, and the clean-up of the first journey then emptied it again a frame later, so the NPC had no travel package and never set off. A seat a running journey holds is now left alone by any clean-up of an earlier one.

Companions no longer turn on you. A Shout, a fire spell or a stray arrow that caught a follower could make them attack you, and nothing stopped it: SeverActions only kept companions from fighting each other. Now a companion who turns hostile over a hit from you or another companion is stopped at once and the hit is forgotten. This covers every follower you have, whichever framework leads them, a mustered war band and retainers guarding someone, but not someone merely tagging along, so you can still lead a stranger into harm. A follower in the vanilla follower slot, whom the game itself dismisses the moment they turn on you, is taken back at once. A companion who chooses to attack you or another companion (the AttackTarget action) now leaves your service first, so the fight they picked is a real one. A fist-fight between you and a companion, or between two companions, that a weapon or spell breaks now simply ends instead of turning into a real fight. With the Outlaw Truce on, a hit on a recruited outlaw companion no longer turns them, or the camp around you, hostile, and a mustered war band forgives your stray hits for as long as it marches with you. Turning Prevent Follower Friendly Fire off now restores your load order's own friendly-hit tolerance instead of a stricter one, and ending a fight with CeaseFighting no longer drops a companion's relationship with you to acquaintance.

Walk With Me can lead SeverActions companions. Once you add a companion to its party, SeverActions stops pulling them back onto its own follow: it no longer resets their AI every few seconds, teleports them to you on a cell change, through a door or when they fall behind (Walk With Me's own catch-up brings its party along, and a camp you told them to hold keeps them there), or makes them relax in an inn, home or shop, which outranked Walk With Me's own resting there. Telling a companion to wait, or sending them on a trip or home, through SeverActions still takes priority over Walk With Me. Release them from Walk With Me's party and SeverActions takes over their follow again within half a minute.

NPCs you give a home, a workplace or a relax spot (Companions → Assigned NPCs) stay where you put them. SeverActions' hold on them now outranks other mods' AI packages up to priority 100 (the three schedule quests in SeverActions.esp moved from priority 95 to 101), so an NPC you also gave an NFF home base keeps the SeverActions home. The hold steps aside while the NPC casts a spell or crafts something for you, while Walk With Me leads them and during a SexLab or OStim scene; a journey, an arrest and a guard's shift still come first. A Relax spot no longer needs a home: the NPC relaxes there in the relax hours and follows their own routine otherwise. A Relax spot an earlier version kept after you cleared an NPC's home is cleared once, the first time you load a save with this version, so those NPCs go on as before instead of starting to relax there; set it again on their card if you want them to. An NPC whose cell is not in memory at that moment can be missed and keep the spot: if they start relaxing there, clear it on their card. An NPC whose cell was not loaded when you loaded a save no longer loses the link to their home, work or relax spot and drifts off: it is put back when their cell loads. When a game scene they were in ends, an NPC now goes where their hours call for (work or relax) instead of being kept at home. In Tracking mode, Wait on an NPC no follower framework leads (from their card or with the hotkey) keeps them where they stand again, as in 3.9.14, instead of letting their own AI walk them off; Follow sends them back to their routine. In SeverActions mode, the Wait hotkey on an NPC SeverActions holds at home, work or a relax spot no longer makes them follow you: it took their routine for a wait and ended it.

Each Assigned NPCs card now says where the NPC is and whether SeverActions holds them for home, work or relax, or why it does not (outside their hours, in jail, in a scene, led by a follower framework and so on). It also flags a Work or Relax spot whose marker is gone, and names another mod's package when one is moving them; SeverActionsNative.log names that mod, its quest, priority and plugin, once per NPC and package. An NPC whose cell is not in memory is listed as not loaded instead of orphaned, Clear All no longer erases them, and their card keeps a Force Remove button. No new game needed.

Russian counts in the web UI now take the right form of the word (1 соратник, 2 соратника, 5 соратников). English pluralises by adding a letter, and the Russian text was left with the English suffix rule, so every count read as "5 соратник".

Asking someone who is wearing one of your outfit presets to put on or take off a single piece (the EquipArmor and UnequipArmor actions, or the equip and unequip buttons on the Actions page) now changes only that piece. The whole preset used to come off first - every piece unequipped and the copies the preset had handed them taken back - so "take off your helmet" left them in their underwear with the helmet reported as not worn, and a hood that came with the preset could not be found to put on. The rest of the outfit now stays on, and the preset stops putting itself back on them (through cell changes and save/load) until they are told to get dressed, which puts the whole preset back on, or until you apply an outfit or clear or delete that one, the situation switch applies one, or they undress. Those last ones take back the copies the preset handed out, as before.

Taking a piece off a follower with the X in the wardrobe's Currently Wearing list no longer costs you the piece. The X used to take every copy of that item out of their inventory and put plain ones back, so armor you had enchanted, tempered or renamed came back as the ordinary version and your work was gone for good. It now just takes off the piece they are wearing, which stays in their pack with its enchantment, temper and name intact; a stolen piece stays stolen, and the number they carry no longer changes.

The Equip button in the Outfits wardrobe now makes what you equip the NPC's applied outfit: it is saved as a new preset (outfit 1, outfit 2 and so on), shows as active in the Saved list and stays on them like any preset you apply, with no hidden outfit lock. Before, Equip put the pieces on under an outfit lock instead, the preset the NPC had applied before came back at the next load door, and a piece taken from the catalog could vanish from the NPC a moment after going on. The outfit now goes on a moment after the click rather than at once. With the outfit system turned off, Equip saves the outfit and leaves the pieces on, but does not make it the NPC's applied outfit; with all eight of the NPC's presets in use, it leaves the pieces on without saving them, and the preset they had on stops putting itself back until you apply one or tell them to get dressed.

Closing the SeverActions menu with Escape, or with B/Y in VR, after opening an NPC in the Outfits wardrobe now puts their outfit lock back, as closing it with the menu key already did. Before, the lock the wardrobe sets aside while it is open stayed off until the menu was next closed with the menu key.

Follower banter no longer goes quiet for good once a relationship note between two companions quotes something or runs over two lines: the note broke the context the banter is written from. Off-screen life reads its events correctly when one of them is blank: the second event of a day, usually blank, used to be filled with the leftover fields and remembered as a garbled line. An off-screen purchase only mentions the item when it actually arrived, by its in-game name, and an item a companion picked up off-screen no longer shows as "with weapon" on the Off-Screen Life page. A slow relationship or reputation reply can no longer be applied to the next companion or NPC in line, and a reputation reply padded with spaces or line breaks is no longer stored with its verdict still in it.

With Ambient NPC Actions on, an NPC who announces a give, trade, take or craft to another NPC now waits for the answer: if the other one talks them out of it, they no longer go ahead anyway. The check only ever heard lines spoken to the player, so every such deed went through after 45 seconds whatever was said.

With nine or more companions, one left behind in another cell now follows you through a load door. Companions who were already through the door used up the eight-a-door limit even though nobody had to be moved, and anyone past the limit was not tried again; after a door or fast travel, companions past the limit are now tried again a few seconds later. A custom-AI follower (Sofia, Inigo and the like) you set to Take Full Control now gets the same allowance for their own behaviours whether or not SPID is installed, so a behaviour is not mistaken for a dismissal.

Leaving the Outfits wardrobe right after staging a piece no longer leaves that piece on the NPC with a spare copy in their pack: the discard could miss a change made in the same moment.

The Outfits wardrobe has a Live Stage. The Live Stage button shows the NPC themselves in the preview instead of the model: framed, lit and drawn by the game, with the menu still open and the game running; drag to orbit and use the wheel to zoom. It needs the NPC loaded nearby and is not offered in VR. The NPC holds still while staged and can move again when the stage ends: when you turn it off, use Free Look or close the menu, or when the menu's overlay shuts down on its own. An NPC who dies or goes down while staged is left as they are. A save made with the Outfits page open (from Free Look, or by a mod's autosave while the menu runs unpaused) kept the wardrobe's try-on pieces on the NPC with their free copies in the pack, and the NPC's outfit lock cleared. Loading such a save now undoes that the way closing the menu would have, and also frees a staged NPC and removes the stage's lights. A save made before this version loads as it was saved.

Ambient banter between two NPCs who share a name (two Whiterun Guards) is now spoken by one to the other, not by one guard to himself, and never by a third guard elsewhere who happens to share the name. Ambient Actions no longer pick creatures and constructs that also carry the person keyword (Vigilant's minotaurs, a Dwarven Gear Walker), as ambient banter already did not.

Off-screen life: a reply that fills a field with nothing ("crime": null, for example) now reads it as left out, instead of risking a crash. A town rumor about the dismissed follower it was written for is dropped even when you have no other companion with you, as it already was when you had one. A stray "|" in a reply no longer scrambles the fields after it. The "how long ago" labels in a companion's off-screen history are no longer slightly early.

Loading a save made while someone was travelling a road route no longer leaves an invisible marker behind in the save for good. A courier whose sender is no longer around (a work applicant you met once) still says who the letter is from, and a ransom letter in that case comes from the captive's people, never "from" the captive.

Hold stewards no longer talk about a weekly wage or going unpaid: a steward is paid by keeping 15 of every hundred gold they collect, and the appointment notice, the hiring conversation and what the steward knows about their own pay now all say so. Sending one war band home no longer disturbs another camp's band that is still on its way to you. A mustered war band now keeps following you after you load a save: loading used to take their places in your party away, so they stood still while the camp still counted as mustered. Releasing a camp from service in conversation now sends its war band home first, as the Camps tab already did. If a save has already lost its band, send it home and muster it again.

Two trade offers in a row no longer mix up: accepting the first card settles the first trade, where a second offer arriving while it was open used to wipe it (Accept then did nothing) or take its answer. With conjured gold allowed, an NPC buyer who was short of gold no longer comes out of a failed or partly filled trade richer than before: only the coin they really paid is handed back. A payment that stops part-way is handed back instead of kept. A new charge to someone who owes an NPC on several tabs goes to the oldest ordinary tab, not an arbitrary one (and not the rent while another tab is open).

With Furniture Auto-Stand Distance set to 0 (Disabled), a seated NPC still gets up when a fight starts or they die: 0 now turns off only the walk-away check. Searching the Estate list by town ("Whiterun") now finds that town's buildings, and each row names its town. The MCM Travel page says "Showing 20 of N" when more than 20 journeys are under way. Old World-page knowledge scoped to Followers no longer reaches bandits.

A long letter, retainer story or letter title no longer ends in a broken character where it was cut to length (accented letters, non-Latin scripts, dashes and curly quotes could all be split).

Loading another save while a background AI request is still out (a companion's relationship read, an off-screen life day, a retainer's story or letter, ambient banter) no longer lets its answer land in the save you just loaded.

A guard making an arrest in front of you no longer loses their prisoner or their way to the jail when a second, dispatched arrest finishes, is cancelled or is judged at the same time. A dispatched prisoner sentenced to jail while a local arrest is under way goes straight to the cell instead of taking over the local guard's escort, and freeing a jailed NPC during an arrest no longer pulls the arresting guard off their target.

NFF's "I need to trade some things with you" works again after a Soft Reset on the Companions page: the reset took away the follower status NFF's trade line checks, and NFF only gives it back when it recruits. A follower led by NFF, a DLC or their own AI now keeps it, and is back on SeverActions' roster right after the reset rather than at the next load. Force Remove on a living NFF follower now dismisses them through NFF, so NFF frees their slot instead of keeping a follower it can no longer trade with.

A retainer who deserted can be hired back: agreeing to it in conversation used to be offered and then do nothing, and Assign Work on the Actions page now offers them the hiring card again. The new terms replace the old job.

Turning the Outfit System off (Settings → Followers → Outfit System) now also stops SeverActions re-dressing people when they load in, when you change cells and when you load a save. Before, only the outfit actions, the menus and the follower outfit watcher stood down, so an NPC wearing one of your presets or an outfit lock was still stripped and put back into it at every load door. Nothing is lost: presets and locks take hold again at the next load after you turn it back on. While it is off, Daegon's own mod looks after her outfit again (with the Daegon Kaekiri patch), and a unique NPC you had locked stays without their default outfit until you clear the lock.

Turning off the outfit auto-switch or the Outfit System no longer stops your followers relaxing when you take them into a home or an inn. Both toggles used to switch off the whole situation monitor, including the part that lets followers sandbox in safe interiors.

Situation outfits now switch for anyone you set them up for: an NPC you dressed on the Outfits page who was never your follower changes into their mapped outfit too. Before, only actors with a follower record switched.

With eleven or more followers, a dismissed follower's or another NPC's locked outfit is enforced again after a load. Followers used to take every outfit seat first, which left the others with none.

Excluding someone from the outfit system now works from the moment you start a new game. Until you had loaded a save once, SeverActions still re-dressed an excluded NPC when they loaded in or you changed cells, and could give them an outfit slot.

Excluding an NPC from the outfit system now also stops the outfit actions: undress, get dressed, equip and unequip, saving or applying a preset and the situation outfit rules all refuse an excluded NPC, whether the request comes from the LLM, the Actions page or a hotkey. Before, only the automatic enforcement stood down, so a follower whose outfit another mod manages could still be stripped, locked and re-dressed by a conversation. The AI is no longer offered those actions for an excluded NPC either.

Telling someone to undress twice, by hotkey or because the LLM repeated the action, no longer loses the outfit they took off the first time. The second undress used to throw away the remembered outfit and note only what they were still wearing (a wig, or nothing), so "get dressed" afterwards put back the wig at best and never restored their outfit lock. It now keeps what was remembered and adds anything they put on in between.

A unique NPC you undressed and later told to get dressed gets their default outfit back for good. Before, once the outfit had been put back on from the remembered pieces, the game was still told on every load that the NPC had no default outfit, so anyone who had never been outfit-locked slowly lost the gear the game itself gives them.

Asking a follower who wears an outfit lock to put on a single piece now adds that piece to the lock. The lock used to be replaced by just the piece they had put on, so a follower locked into eight pieces who was told to wear a helmet was stripped of the other seven at the next load door; and an unlocked follower asked to put on a ring became locked to the ring alone. A piece that takes the same slot, or a shield pushed off by a two-handed weapon or a torch, leaves the lock; the rest stays.

Situation outfit rules set through conversation now work when the preset is named loosely. "Wear your travel clothes when we go adventuring" used to record the rule where the automatic switch never looked, so the follower never changed. The rule now names the preset the request resolved to; a request that matches several presets is refused rather than guessed, since a rule that fires every time you enter town should not roll dice.

Presets saved from the wardrobe with more than one descriptive word in the name, such as "Heavy Armor Set", can now be saved, applied and deleted by that name. The name was being trimmed twice on its way through, so the preset was saved under one name and looked up under a shorter one: it never appeared in the wardrobe's list, Apply reported it missing, and Delete could remove a different preset that happened to carry the shorter name.

"Clear All Presets" on the Outfits page now clears everything for that NPC, including the situation rules and the copies of the presets the automatic switch reads. Before, the presets and rules survived the button, so the follower could be dressed into a "home" outfit you had just cleared the next time they walked home, this time under an outfit lock.

"Forget outfit data" on the Outfits page now sticks. The NPC used to come straight back into the Managed list on the next refresh, with an empty entry that could not be removed and was saved into the game.

A locked outfit that is put back on at a load door no longer counts its own re-equips as someone else stripping the follower, and pieces they are already wearing are left alone rather than re-equipped. Three or more of those self-inflicted events in half a second used to switch the lock's enforcement off for the rest of the session.

Telling someone who is wearing one of your outfit presets to undress and then to get dressed puts that preset back on them. Before, "get dressed" put back copies of the preset's pieces that nothing kept track of, so every undress and dress left one more set in their pack for good, and a preset applied after an undress could be undone by a later "get dressed", which put the outfit from before the preset back over it. An outfit you have applied now counts as them being dressed.

Saving an outfit preset through conversation no longer puts an outfit lock on someone who is not, and has never been, your companion, and saving while they wear nothing is refused instead of overwriting a preset of that name with an empty one. Before, with Outfit Lock on, asking a shopkeeper to remember their outfit locked them into it for good.

Asking for a saved outfit by its exact name now applies that outfit even when another preset shares a word with it. A ninth preset (the ones past the wardrobe's eight) asked for as "town" used to get "town casual" instead.

Asking someone to put on a named piece now looks for the whole name you gave first, only ever picks armor, a weapon or a torch, and puts on their own enchanted, tempered or renamed piece rather than a plain copy they also carry. "Put on the dress (blue)" could make them eat a blue mountain flower, and "wear the Wolfsbane Cuirass" put on the ordinary armor instead.

A standing outfit rule set through conversation is now refused when the situation named is not one the game watches for (town, adventure, home, sleep, combat, rain or snow); "at home" and "when we're travelling" are understood as home and adventure. A rule for "the inn" used to be stored and told to the character, and never fired.

A follower who died and was removed from your companions after the grace period now gives back their outfit slot, so a long game no longer runs out of the hundred outfit slots to the dead.

The MCM's per-NPC Outfit Lock toggle on the Outfits page now stays off, and says why, when Outfit Lock or the outfit system is off or the NPC wears nothing; it used to show as on while nothing had been locked.

The undress and dress hotkeys no longer report "undressed" or "dressed" when the outfit system is turned off.

On Skyrim VR with RaceMenu VR, the game no longer freezes when a follower wearing one of your outfit presets loads in (after fast travel, for example), when the situation switch changes someone's outfit, when outfit locks are put back on after a cell change, or when you press Equip in the Outfits wardrobe. These changes used to run at a moment RaceMenu VR could deadlock against; they now run the way the wardrobe's own changes already did.

On Skyrim VR, the Outfits page no longer offers Free Look: Skyrim VR has no free camera for it to hand you, so entering it could crash the game. The see-through viewport (Settings - Interface - Disable Mannequin Preview) still works; you frame the NPC by looking at them. On a VR install whose UI host cannot draw the live item into the headset, the inventory's Inspect view now shows the item's category glyph straight away instead of a blank stage for six seconds.

Bio Blocks no longer lets two tabs exist whose names differ only by capitals ("Combat" and "combat"). The second one was always empty, because blocks landed on the first, and deleting the empty one deleted every block of the real tab instead, with no confirmation. Manage Tabs now greys out Add, and Save when renaming, on such a name; an imported library folds its tabs onto yours, and a library that already holds a twin drops it on the next load (the log says so; no block is touched).

Dropping a worn piece from a follower's Inventory page no longer hands it back: the outfit system used to re-equip a fresh copy of a preset piece half a second later (or on the next cell load), leaving the dropped one on the ground, which duplicated it. Drop now pauses enforcement the way Sell and Destroy already did. Applying an old outfit preset that lists a Devious Device the NPC no longer holds skips the device instead of creating a keyless copy on them. "Take off Dress (Blue)" now takes off the dress: the unequip looked for the word in the brackets first and could pull off any other worn item starting with "Blue".

A forced fight (AttackTarget) that ends on its own, by a death or the two drifting apart, now takes the survivor out of the attack and target factions, and Cease Fire and Yield clear them outright (the old removal left a trace behind). With the AI Overhaul patch those factions suppress fleeing, so an NPC left in one could never run from a dragon or a fight again. The two one-time Truce migrations (necromancers, Forsworn and vampires default on; the old 4000 radius to 8000) are recorded in the save's migration ledger, so an install where PapyrusUtil loses its values no longer re-runs them on every load and turns those three toggles back on against your choice.

A brawl no longer leaves a peaceable NPC aggressive: the restore treated a recorded Aggression or Confidence of 0 (Unaggressive, Cowardly) as "not recorded" and wrote Aggressive / Brave instead, for good, so a townsperson who had brawled once charged the next dragon. It writes back exactly what it captured (the base value, so a calm or frenzy effect active at the start is not baked in). Two brawl challenges expiring in the same second no longer get each other's challenger, which left one challenger trailing their target with weapons drawn until the next load and recorded the wrong refusal.

A save made in the middle of a brawl no longer leaves its fighters changed for good. Loading it used to keep the NPC fighters on Aggression 1 and Confidence 3 (a townsperson who brawled would then charge a dragon instead of fleeing), and kept them, your pacified followers and you in the brawl's no-kill faction. The save now remembers what the brawl changed, and loading it puts those back. Loading any save during a brawl, or in the moments after one, also no longer leaves a fighter, and every NPC sharing their record, unkillable for the rest of the session, or a named NPC without their combat spells.

Giving a follower a home and then dismissing them no longer strands the bed they were given. The claim was wiped at dismissal, so clearing or moving the home later could not hand the bed back to its real owner (an inn, a camp, a household), and it stayed the ex-follower's for good. The claim now stays with the home, a home moved outdoors releases the old bed too, and an NPC who has no bed yet only takes one when they are at their own home at bedtime. Healer and Coward combat styles now survive a game restart: the healer's combat style and the coward's "never fight, never help" values were only applied when you picked them, and a relaunch put the follower back on their original style. The MCM's combat style menu now offers Coward too, and opens on it for a coward companion; its Ambient NPC Actions switch is no longer labelled Ambient Follower Actions, since it never drove your followers.

Followers who are essential in their own right (Lydia, for one) keep it when dismissed: turning Essential on for them on the Companions page made the later dismissal clear their own protection. The reverse is fixed too: a follower you made essential no longer stays essential for good after a re-recruit and a dismissal. Followers you recruit through SeverActions without NFF or SFF installed no longer keep the hunting bow and iron arrows the vanilla follower slot hands out: the one-time take-back at recruit looked for the wrong items, and a follower who had been pushed out of that slot kept them when dismissed. (This is that take-back, not the bow swap retired in 3.9.9.) A refused recruit (too many companions) no longer releases the NPC from a camp or a kidnapper's guard duty first, and re-recruiting someone already in your party is never refused for the party being full. A schedule hold on a framework-managed follower (NFF, Serana) is now actually removed when they are recalled, instead of being noticed and left. Telling an NFF-managed follower to wait now respects the Show Notifications setting, as it already did for other followers.

SeverActions menu displays. The inventory preview's slot badge names the slots an item actually occupies (a shield reads Shield, gauntlets Hands); most pieces used to get the wrong label. The Arrests page's "gold owed" counts only your own bounty, not NPC offenders'. Loading a save without a Hearth base after one with a base no longer keeps showing the old Base card.

Notifications no longer show boxes for dashes, quotation marks and ellipses: the game's notification font lacks them, and the swap to plain punctuation that was meant to handle it never matched anything. This mostly affected French, Russian and Japanese, but also two English notices. A notification that names something typed with "{0}" in it (an outfit preset, for example) no longer freezes the game.

The live outfit preview now draws TruePBR armour (its roughness, metal and ambient occlusion) and pieces with offset or scaled textures correctly. Neither live preview (outfit or item) writes past the end of a graphics buffer any more, and opening one no longer sets aside about 34 MB of video memory that nothing used.

The SeverActions menu key no longer resets itself. Once the Require Shift option had been changed in the MCM, starting a new game or loading an older save could put the menu key back to that save's binding (8 on a new game) for every save, overriding the key you had chosen.

Fertility Mode: after you restart the game, pregnancy and cycle tracking for companions no longer stays frozen for hours. A pause the bridge takes while Fertility Mode is tracking nobody was measured on a clock that restarts every launch but was kept in the save, so it could block every update until the game had run as long as the earlier session. Fertility Mode's cycle and pregnancy settings also resolve when Fertility Mode.esm is flagged as a light plugin, and a setting that can't be found falls back to Fertility Mode's own default rather than a different one.

Magic lessons that go wrong now go wrong visibly. A failed Conjuration lesson summons the hostile creature the narration describes at every level (a skeever, a skeleton, a frost atronach, and at Master a dremora); before, only one level spawned anything, and a giant frostbite spider at that. An NPC who fails an Illusion lesson badly is frightened off (or, at the higher levels, frenzied) instead of calmed, and one who half-fails is staggered, and a failed low-level Destruction lesson hits with a single firebolt instead of a stream of flame. An NPC told to cast a ward or Turn Undead no longer recasts it over and over until their magicka runs out: only spells that actually heal repeat until the target is healed.

Reading and looting. Asking an NPC to read a diary aloud when its diary can't be shown (no diary entries, or another screen open, such as the Actions page's own Read Aloud) now reads the book normally instead of doing nothing and blocking every other NPC from reading until a reload. A diary entry read aloud is no longer cut short or interrupted with requests for the reader's thoughts when the reading mode is set to Summarize. Outdoors, NPCs asked to loot a chest, search a container, or pick up or bring an item now find it even when it sits just across a cell border. Looting everything from an owned container with more than thirty kinds of item now counts all of it toward the theft, not just the first thirty.

Crafting and commissions are more dependable. A smith asked to commission something twice while the confirm is still open no longer wipes the first order: the open confirm settles it, and a different order is put off until you have answered (ask again then) instead of charging the wrong terms. When no confirm can be shown at all, the smith is no longer told you declined. An NPC sent to a forge, cooking pot or alchemy lab further than a short walk away no longer gives up after 15 seconds; the time allowed now grows with the distance. Stopping one NPC's queued craft (for example by sending them travelling) no longer pulls another NPC off the forge mid-craft, and a finished craft is no longer occasionally announced with no name.

VR (and immersive mode): Assign Work on the Actions page now sets the workplace for someone who is not yet a retainer. It used to show only a hint about the ledger and place no work marker. An NPC hired in conversation is announced as hired only once the hire goes through, and a refused hire now says so and leaves no work marker behind.

A retainer who turns on you now leads the ambush they paid for. A deserter who went hostile was meant to show up at the head of their hired thugs, but by the time the ambush set out they no longer counted as hostile, so only the thugs came. When they did lead one (the Enterprises debug button, or a kidnapped ex-retainer's search party), standing the ambush down or reloading made them vanish for good along with the thugs. Now they lead it, walk away on their own when talked down, keep their own temper afterwards, and are no longer made a bandit if it comes to blows; one of the hired blades still does the talking and carries the letter. A retainer who is in custody or travelling with you stays out of it, and a kidnapped retainer no longer leads the search party sent to rescue them.

Brawl and combat cooldowns last as long as they say, and they now stop fights. The cooldown after a brawl (30 seconds), a ceasefire or a yield (100 seconds, the Forced-Combat Cooldown setting) was counted in game time, so at the default timescale it was over in a second and a half or five seconds and a brawl challenge could be issued at once; it now counts real seconds. The Forced-Combat Cooldown also never stopped anyone being ordered to attack: while it runs, an NPC who just agreed a ceasefire, yielded or finished a brawl can no longer be ordered to attack anyone, and no other NPC can be ordered to attack them (your own cooldown does not protect you: another NPC can still be ordered to attack you); the refusal is recorded so they can say why. A healer follower no longer spends heals on your summoned atronachs and raised thralls, which they were always meant to leave alone.

A camp sworn to you stays emptied. Swearing an outdoor camp could not stop it repopulating (the camp's own encounter zone was never found outside its cells), and a freeze that did take lasted only until the next load; the camp now finds its own zone, the freeze is put back on every load, and camps already sworn on an older build are frozen the next time you load. A camp whose freeze failed no longer has its map marker left cleared, and releasing a camp that was never frozen leaves its marker alone. When a chief you appointed dies with nobody to step up, a crew kept above the fair cut grows unhappy each week again, and if the camp's own boss takes charge the crew stops saying you put them in charge. A chief who dies with no successor is no longer described as speaking for the camp. Old saves with stray camps recorded in houses or towns are now cleaned up whenever they load, not only on the first load after starting the game. A camp sworn to you stays the one its members answer to after they walk through another bandit camp or fort with you: releasing the camp or sending the war band home in conversation, and what its members know about their camp, used to be able to pick up the other lair instead.

A fight with a sworn or leaderless camp member now holds. Once their truce broke, the next check (within about three seconds) made them lay down arms again mid-swing, so a fight flickered on and off; the break now stands until they leave the area. A sworn member now turns on you only once your own blows have cost them a quarter of their health: wounds from enemies or your followers no longer count, so a war-band fighter already hurt in battle does not turn over one stray hit.

A ceasefire holds and breaks as one group. Hitting one of a group of outlaws who agreed to a ceasefire now turns the rest of their group too, instead of leaving them standing passive while the one you hit fights on. A ceasefire declared in the open also reaches allies standing a little further off, and breaking it reaches them too.

Captives stay where they are left. An NPC told to restrain or tie someone while a guard dispatch is under way no longer stops a few steps short and gives up minutes later: they now walk the rest of the way and bind, or say they could not get close enough. A captive whose leader dies or loses them is now held where they stand, instead of being sent back to the place they were first taken, and the captor is no longer pulled there with them. A captive untied, taken in hand or freed after being tied to furniture no longer keeps staring at it, and one freed in the moment they were being tied is no longer left frozen on the spot.

You can tie a captive to furniture yourself. While you lead a bound captive (Tie / Untie on someone binds and leads them), aim at a chair, bench, bed or other furniture and press Tie / Untie: you tie them to it, as an NPC's TieCaptiveToFurniture does. Tie / Untie on the captive afterwards frees them, as before. A tied captive now stands still where they are tied, instead of walking in place trying to go wherever they were headed. NPCs nearby no longer pick a captive, the captor still holding one, or anyone in the middle of an arrest for an everyday errand such as eating a meal, which undid a captive's bound hands.

NPCs know who is leading a prisoner. A captive taken in hand by someone other than their captor now knows who is actually leading them, the NPC leading them knows they have a prisoner at their heel, and the captor who handed them over no longer believes they are standing watch. An NPC who restrains someone and leads them off is no longer told the prisoner is standing bound beside them. A prisoner who was being led and is then moved to a new place of holding is no longer treated as still led by whoever had them before.

Guard dispatches keep their own business. A guard sent to arrest someone no longer walks off after the target of a guard making an arrest on the spot. A guard searching a home who walks out of view now still collects the evidence they are about to present, instead of handing over nothing. Sleeping or waiting past a day while a guard is bringing a prisoner back, or while the prisoner stands before the one who sent for them, no longer replays the whole arrest. A prisoner who dies on the way back or during judgment is no longer cuffed and "escorted to jail". Cancelling or starting another arrest in the moments a prisoner is being locked up no longer strips them of the details their release restores, and no longer wipes the new arrest.

A guard searching a suspect's home turns up evidence that fits the charge. Most of the evidence lists pointed at the wrong records, so a search could produce Void Salts for a moon sugar case, a rabbit leg as skooma, a sword where a battleaxe was meant or nothing at all, and could even try to hand over a spell; every item is now the one it names. A "contraband weapon" charge searches for weapons and Dwemer parts rather than skooma, a charge that says "theft" or "thief" counts as a theft case (a lockpick then counts against the suspect), damning evidence is recognised as damning, and an item the player already took from a chest is no longer "found" in it. A home with no bed no longer describes every container as "near the entrance", and a guard sent to find someone's home no longer settles for a chair or workbench they own at the tavern or guild hall.

Sever's Hearth sees past the edge of the cell you are standing in: the camp's threat warning on the Survival page counts hostiles in the neighbouring cells too (it used to clear with enemies still in range), and pitching a camp or base, sending everyone there and sizing a base's bedrolls now include followers standing just across a cell border. The camp distance, occupant and threat decorators a prompt can call no longer scan the world from SkyrimNet's worker threads (they read a reading the game keeps fresh), and the camp distance reads in real feet (it was about three times too small).

Sever's Hearth: a base standing on its own now restores the needs of the people living there (and yours, while you are there); the camp's survival tick used to run only while a field camp was also up. Everyone asleep in a tent now counts as at the camp: the old reach stopped short of the player's own tent and every bedroll of a grown base. Cancelling a camp reposition while a base stands no longer leaves the base without its map marker and rest stop, and a promotion that fails no longer strips the standing camp of them. A base that is full no longer drops a field-camp occupant it cannot take (sending someone to a full base is refused up front), and people whose journey to a camp ended away from it (turned back, or gave up) no longer keep a place on its list or stay parked when they rejoin you. Someone sent to a camp or the base now settles in as one of its occupants once they get there (whether you arrived with them, met them there or kept them waiting too long) and stays until you tell them to follow again, instead of standing idle by the fire.

Survival is fairer to the people it tracks. With Track Dismissed Followers on, only former followers with a home are looked after on a visit; an NPC you only gave a home to (or a retainer who never followed you) no longer gets hungry, tired and cold, takes the stat penalties, or eats food out of your pack, and one already caught up in it has those penalties removed on your next load. Turning survival off really freezes everyone's needs now: a Sever's Hearth camp, the Feed button and including a follower no longer wipe them to zero or re-roll them while it is off (which also re-rolled them at random when you turned it back on), and Feed no longer uses up food on a companion while survival is off. A drink or a plain ingredient restores the same small amount of hunger however it is eaten: auto-eating an ale no longer counts as a full meal, and eating a raw ingredient no longer does either.

Arrest confrontations hold up better across loads and overlapping standoffs. A guard's persuasion window left open when you loaded another save no longer fires into that save (ending a confrontation there, or making an ambush attack), and neither does a resist-arrest window. An ambush lead or camp challenger dying no longer ends an unrelated arrest confrontation, and a guard's timeout no longer sets off a hired-thug ambush you are talking down. A guard who dies mid-persuasion no longer leaves their follow package behind, and a rejected plea now closes the persuasion window. Bribing a guard clears only the bounty they quoted, like paying the fine: bounty added while the prompt was open stays owed. An escort whose guard is off-screen gets its full grace period after a load instead of finishing at once. A save with a great many tracked bounties no longer loads them all as empty, which the next save would have made permanent. An arrest plea, a hired-thug standoff and a camp challenge now each keep their own persuasion clock, so one starting or ending no longer cancels another's, and a camp challenger always gets a clock even while you are pleading with a guard.

A follower's quest summary that was still being written when you loaded another save no longer lands in that save: it could add a line from the old playthrough to the same follower's entry for the same quest, or leave an empty follower record behind in the new save.

Turning the Imperial Levy off now always sends the whole detail home. After loading an older save in the same session, the switch could hide only the three officials and leave the twelve seconded soldiers patrolling for good; a save already left like that is cleaned up the next time the Levy is found switched off. Jarls, stewards, housecarls, court wizards and guild leaders no longer write asking to be hired on Skyrim VR or without powerofthree's Tweaks, where the check that excludes them found none of their factions. A hold's "sold last week" figure for its merchants and fences is last week's again (each one's latest week, added up) instead of a running total since you loaded. A hold's trade depot and its fence cache are also kept apart now: a merchant no longer describes the fence's stash as the depot (or reports the fence's sales as their own), and the enterprises summary on your character no longer lists a hold's depot as sold out just because its fence cache emptied, or folds the cache's stolen stock into the depot figures every NPC you talk to can read. A retainer whose workplace name is shared by several buildings in different holds (a Hall of the Dead, say) is no longer assigned to whichever hold was indexed first. Moving a retainer off the Custom trade drops its old trade name, and clearing the name field clears it. A rare race that could skip rebuilding the NPC labor list after a load is closed.

Property transfers keep the people who live there. When an innkeeper or a household gives you a building, its residents now join the shared ownership: every named NPC whose bed or chest the transfer took over, or who lives or sleeps there (in a home, not an inn's patrons), wherever they are, and anyone else of the owning household who is inside; before, only an owner standing nearby at that moment joined, and the rest were trespassers in their own home and told each other to leave. A building given to you before this update is repaired too: in a home, everyone named who lives or sleeps there joins the first time you load a save, and the rest of the household the next time you go in while they are home. A household's building you already gave back before this update stayed under SeverActions' shared ownership with its household shut out; its household now joins the same way (if not on the first load, then the next time you go in), and it stays shared with you, since giving it back deleted the only record of whose it was. Giving a property back now returns it to an owning faction as well as to a single NPC, where a faction-owned building used to stay under SeverActions' shared ownership and drop off your property list. The people who live there also leave the shared ownership again, unless another building you were given is their home too. An NPC can no longer hand you the building you are standing in while they are somewhere else, since the ownership check looked at their building and the transfer at yours, and sharing in one building you were given no longer lets an NPC "give" you another one you already have. Entering your own house no longer quietly rewrites who owns what inside it, and house detection now recognises Breezehome, Honeyside, Vlindrel Hall, Proudspire Manor and Severin Manor by their real keys, and the three Hearthfire homes (Lakeview Manor, Windstad Manor, Heljarchen Hall) by their land charters: the old table matched five enchanted elven weapons and records that were not houses, so the property list could show homes you had never bought. Those entries are removed from existing saves once.

The background sweep that used to strip a stray follow, travel or furniture link from an NPC every few seconds is off by default. It was meant for scripts that died mid-flow, but every case it ever touched in the field was a live one (a guard stopping mid-escort, a courier frozen on arrival, a captive freed mid-march), and each system now tidies its own state on load. The one thing it did that mattered, letting a guard arrest someone a crashed earlier arrest had left tagged, now happens when the next arrest starts.

The two hired-thug standoff actions (ThugAttack, ThugStandDown) no longer live under the Employment category: they have their own AmbushStandoff category, offered only to the thugs, so they are available to them whenever the Enterprises actions are installed, whether or not the Employment category is eligible in that conversation; the Employment category's description no longer lists them. The courier and the thug ambush run from their own scripts with their own timers, which changes nothing you would see. The retainer, steward, loan, hearing, hold-tax and sworn-camp conversation actions, the Imperial Levy detail's marching orders and its walk to you, a steward's visits to their retainers, a sworn camp's war band and the upkeep that keeps retainers and camp members findable run from an Enterprises script of their own now instead of the currency, travel and follow scripts, again with nothing to see: a save made with the old layout carries over, and an audit in progress picks up where it was on the first load.

A follower sent back to the camp or the base (Sever's Hearth) now arrives at "the camp" or "the base" in the notification and the MCM's journey list, instead of the marker's internal name.

NPC travel has no five-journey limit any more. An NPC you send somewhere still walks there, waits for you (or does their errand and leaves) and keeps waiting through a save and load, but the waiting is tracked by the travel engine itself instead of five bookkeeping slots, so there is no fixed limit on how many NPCs are on the road or waiting at once (an NPC waiting beyond the fifth keeps waiting but is not held persistent while you are far away). The MCM's Travel page lists the journeys underway (click one to cancel it) in place of the five slot rows; a save with an NPC mid-journey or mid-wait is carried over on its first load.

Background conversations and assessments that lose their reply now pick themselves up again within a few minutes. Follower banter, inter-follower opinions, ambient banter and actions and the NPC reputation blurbs used to go quiet until the next load when one LLM reply never came back; the in-flight gates are native lanes now, which expire on their own and are cleared on every load.

Tracking mode now means what its name says: SeverActions registers whoever becomes a teammate - vanilla followers too - and leads nobody. Relationships, quest awareness, off-screen life and the outfit lock keep running, and a home or work you assign still applies; SeverActions' own follow package and wait sandbox go on none of your companions. If you were already in Tracking mode with a follower SeverActions was leading, it stops leading them on the first load after this update and their own follow AI (or your follower framework) takes over; to have SeverActions lead them again, switch the mode back and recruit them again. In Tracking mode SeverActions' own recruit action only registers a companion - recruit them through dialogue or your framework to have them walk with you. Asking a bystander to follow you while in Tracking mode now says so instead of quietly doing nothing (one already walking with you keeps walking until told to stop). Dismissing a companion SeverActions recruited and was leading now fully dismisses them after a switch to Tracking mode too: they stop following at once, are no longer your teammate, get their own aggression and confidence back, and go to the home you gave them, even if they were waiting. Before, a Tracking-mode dismiss left them following until the next load and then brought them back onto your roster. A follower another framework took over (NFF, for one) is still dismissed by that framework, and SeverActions now stops leading them at once.

Prisoners taken to jail by an arrest are put back in their cell again when you load a save, if something moved them out. Since 3.0 the jail they were taken to was not recorded, so the load-time check had nothing to aim at. Prisoners jailed that way are found again through their cell's anchor while they still have it: anyone jailed since 3.5 keeps it, and on older versions it could expire after about a month in game.

Settings changed in the MCM now stick across launches. Some MCM choices were saved to the settings file under a capitalised name the reload did not recognise, so the game skipped them at start-up, or an older value saved from the in-game menu won instead.

Followers' quest memories now need SkyrimNet's plugin API version 8 or newer, which every SkyrimNet since 0.25 has. On an older SkyrimNet the followers' quest summaries are switched off (on API 5 to 7 the one-line completion notes still land) and a message says so once when a game loads. The Papyrus fallback that carried those older builds is gone, and with it the small chance of a summary being filed under the wrong quest that it always carried.

Installing this version: the installer's pages and choices are the same as in 3.9.14, and every choice installs at least what it did before. Reinstall with Replace, because the zip is laid out by module now (a `10 Modules` folder per part of the pack, small marker files that tell the pack what is installed, and a `MANUAL_INSTALL.txt` at the root for installs without a mod manager - it lists everything below). Five things are gone on purpose: the web pages under PrismaUI/views (the in-game interface runs on the Magelight host now, bundled as `98 Magelight UI`); the AdjustRelationship action (it shipped disabled, and the background relationship assessment replaced it); the SetCombatStyle and SetFollowDistance actions (combat style is set on the Companions page, follow distance with Follow Distance on the Actions page); the LeashCaptive and UnleashCaptive actions (RestrainNPC and TieCaptiveToFurniture took their place); and the StopUsingFurniture action (an NPC SeverActions sat down gets up by themselves once you move away). Fifteen installer descriptions were reworded to say what each option really installs; nothing else about them changed.

The interface's Actions page reaches each part of the pack directly now: a button's verb goes from the native plugin straight to the script that owns it (followers, combat, economy, outfits, travel, items or arrests), and the eleven retainer buttons (collect, pay arrears, loans, bail, dismiss and the rest) run in the plugin without a script at all. Before, every button went through one script that switched on all eighty-four verbs. Nothing changes in what the buttons do.

The hotkeys (follow toggle, dismiss, stand up, use furniture, yield, undress, dress, set companion, companion wait, assign and clear home, set up camp, drop marker, tie/untie) are heard by the native plugin now instead of a script, so a press lands even while the scripts are still catching up after a load, and it reaches the part of the pack that owns it directly. The keys (keyboard, mouse buttons and gamepad buttons alike), their settings and the target modes are unchanged; a hotkey that shared the config-menu key is still cleared with a notice. One small difference: the "last talked to" target mode no longer remembers a partner from before the save was loaded - it answers again as soon as someone speaks to you.

The quick wheel's eight options run through the same native path as the hotkeys now, and the old UIExtensions wheel is gone: SeverActions draws its own wheel on Magelight UI, and UIExtensions is no longer needed for anything in this pack. Without the interface installed, the wheel key says so instead of doing nothing.

You choose what the quick wheel holds now. Settings > Interface > Hotkeys in the SeverActions menu lists its eight slots, clockwise from the top, and each can hold any action that has a hotkey (follow, wait, dismiss, set companion, assign or clear a home, stand up, use furniture, yield, undress, dress, tie or untie, drop a travel marker, set up camp) or be left empty, which takes that slice off the wheel and closes the gap. A wheel you never change keeps the same eight actions in the same places. The layout is kept with each save, like your action hotkeys, and a new game starts from the usual eight. Drop Marker, Set Up Camp and the furniture step of Use Furniture work from the wheel without an NPC under the crosshair. If every slot is empty, the wheel key says so instead of opening an empty wheel. The slots are set in the SeverActions menu only, not in the MCM.

The MCM no longer does any work when a game loads: the settings it used to re-push (the dialogue animation toggle, the outfit stability delay) and the two menu keys' sync with the settings file are the DLL's now, and the MCM pages read the value in force when they draw. Turning dialogue animations on or off from the web settings page takes effect at once instead of on the next load, and a hotkey can be set from the web page even on an install without the MCM.

If the native plugin is missing or comes from another build than the scripts, SeverActions now says so in a message box the moment a game loads and stops there, instead of running on and failing piece by piece; the message no longer depends on the plugin's own text table, which was exactly the thing that was missing. A game without the follower system no longer gets a false "plugin out of date" warning a minute after loading. The load-time settings replay and cosave repairs now also run on a new game in VR, which used to get them only after the first save and reload.

Your menu and quick-wheel hotkeys no longer change behind your back. The two keys the plugin handles itself (open the SeverActions menu, open the quick wheel) are kept in the shared settings file so every save and profile agrees, but every load also pushed the save's own copy of them into that file - and a new game carries the shipped defaults, so starting one in any profile rebound both keys for every profile, and for every PC the file syncs to. The file wins now: on load the keys come out of it, and only a rebind you make (in the menu or the MCM) writes it. Flipping the MCM's Shift toggle before ever rebinding the menu key could also clear the key; it no longer can. A leftover from an older build - a second, capitalised copy of the dress/undress animation setting in that file - is dropped on the next load.

SeverActions loads again on SkyrimNet 0.25 (beta25). SkyrimNet stopped reading loose action, trigger and prompt files, and only picks up content that a mod ships as its own layer; on 0.25 none of SeverActions' actions or prompts were loading. The whole pack ships as the severause.severactions layer now, the way it did briefly in 3.9.9. SkyrimNet before 0.25 does not read this layer, so 4.0 needs SkyrimNet 0.25 (beta 25) or newer: on an older SkyrimNet none of SeverActions' actions, prompts or triggers load. Reinstall with Replace so no copies of the old layout are left behind.

The camp is laid out like a real war camp now, and nothing in it floats, clips or sits where it can't be used. It follows the vanilla Legion and Stormcloak field camps: one fire every tent door faces, your tent at the back straight across the fire from where you walk in, the barracks tents on the flanks, a small tent in a back corner, and each corner with a job - the mess table and its stores front-left, the hunter's tanning rack with its pelts crate (and at the top tier a lean-to and its hay) front-right, the barrels and a crate beside your tent, and at the top tier a smithy spread the way vanilla spreads it: an anvil and a grindstone by the fire, each with room to stand at, and the armor bench by the stores beside your tent. Every station, bench, bed and chest was checked so a person can walk up to it and use it, and the walks from each tent door to the fire are kept clear. The fixes you'll notice: the cooking pot hangs from its spit (it is vanilla's cooking spit over the fire now, pot and roast included, still a cooking station); the hay bale sits on the ground; the war map lies on the war table; the bedside table is square to the tent; and the bed and the stash chest no longer clip the tent - both moved inside, the chest facing the room. The Imperial tents open toward the fire (their door is on the side, and the camp used to turn it away) and are sunk and scaled the way vanilla pitches them, so their walls reach the ground. Tree checks now refuse a spot where a tree would stand anywhere under a tent, not only near its middle. If an upgrade can't be built after the materials were taken, they go back into the stash; the upgrade also refuses when you're not really at the base (inside a building, or in another worldspace). Tiers: a bivouac (your tent and two small tents) sleeps two; an encampment (a barracks tent on each flank in place of the small tents, a banner, the mess) sleeps four; a command camp (a war tent beside yours, the small tent and lean-to, the smithy, the gate flags) sleeps six - and extra followers still get bedrolls laid out in tidy pairs facing the fire, up to twelve beds at every tier.

The camp is furnished like the Imperial camp in Eastmarch now. Your tent has a plank floor, pelts on the planks and a lit lamp on the bedside table (a lantern in the Imperial tents, a horn candle in the Nord ones). The command camp gets its own war tent, pitched in the back corner beside yours and facing the fire at the size vanilla gives its war tents: the war table and map stand in it on a plank floor, with pelts, a lamp on the table, a floor candelabra or horn candle, and spots along the table where your companions lean over the map. The mess table has a lantern. The fire is vanilla's stone-ring campfire on every install, with the cooking spit re-seated over it and a real light over the flames; the tent lamps and the mess lantern carry lights too. If you run Light Placer, the camp leaves out any light it would add to a lamp or fire that Light Placer already lights, so nothing glows twice. On a gentle slope the floor lifts a few units to clear the ground; on a steeper hillside the ground can still show through the uphill planks. Tall grass can still show through the floors and pelts - grass is baked into the ground, and nothing placed at runtime can clear it. Tree checks cover every loaded cell the camp reaches, not only the one you stand in, since the command camp reaches further out. Breaking the base no longer loses its upgrades: the next base goes up at the tier you had built, or at the largest tier that fits the spot, and upgrading back to a tier you already built costs nothing.

The company has a base, and the first camp you pitch is it. Sever's Hearth keeps two camps: the base - a persistent camp that stands whether or not anyone is there, that followers can be sent to and will stay at, and where the stash chest lives - and tonight's camp, a bivouac pitched somewhere else while the base stands. There is no extra step: Set Up Camp (or a companion's EstablishCamp) raises the base when you have none, and a plain camp when you do. While no bivouac stands the base carries the map marker, the dashboard rest stop and the location routing that the camp used to; pitch a bivouac and it takes them over for the night, break it and they return to the base. Send people to the base, reposition it - the chest and its contents come along - or strike it for good. Companions know it too: GoToBase, UpgradeBase, BreakBase and PromoteCampToBase (for a bivouac pitched after the base was struck) are actions, and the base shows up in their context.

Camps now pitch the large Nord tent - and the Imperial one, if you've joined the Legion. The tent form the camp kit used was the small Nord tent labelled as the large one. The kit picks by the civil war now (Imperial pattern for the Legion, Nord for the Stormcloaks or the undecided), with a setting to override it coming alongside the bigger camps.

Followers now know about the gear you hand them through the SeverActions inventory page and the catalog. SkyrimNet did see those moves, but only as a short-lived note that some items changed containers, which no one reacts to; the spoken Give and Take actions had always registered a proper event, and now the Inventory page and the Catalog do the same, in the same words - so a follower you dress from the UI can react to it just as they would to a vanilla trade (thanks DizzyDedman). A move reports how many items actually changed hands, and something you spawn for yourself from the Catalog is not reported at all.

Jarls and housecarls no longer make arrests in person. The authority check that let a jarl order judgment also let them see the arrest actions themselves, so they walked over and did the collaring. Guards keep Arrest, Arrest Player and the two Dispatch actions; a jarl or housecarl gets Order Arrest instead, which hands the job to the nearest guard - on the spot if the suspect is present, or as a manhunt that brings the prisoner back to them for judgment (thanks again DizzyDedman).

Guards no longer end up locked in the cell with their prisoner. When an escort to jail stalled long enough to time out, the guard was teleported into the cell alongside the prisoner and, with no key, stayed there. The prisoner is still placed; the guard stays where they were and goes back to their rounds.

Give Item and Take from Player on the Actions page now have a Count field. The spoken actions could always move a stack - the count was a parameter from the start - but the two buttons on the Actions page never asked for one and always moved a single item (thanks Forsworn).

Companion bonds have a middle again. The relationship assessment used to score nearly every conversation, was told to avoid writing anything neutral, and re-read a follower's most dramatic memories every cycle - so once a bond tipped one way, the companion played it, you answered in kind, and the next assessment read that exchange and pushed further. Followers ended up either devoted or contemptuous with nothing in between, and the same happened between companions. The assessment now treats zero as the normal result of a conversation, only moves for something it can name, finds it hard to push a bond further out past the halfway marks and easy to bring it back, and writes the companion's inner voice to match the numbers: reserved and undecided in the middle, distant rather than hostile when it sours, warm but independent when it is strong - and never spelling out what would change their mind, since you can read that page too. Companions themselves are told that cool is not cruel, that disagreeing is not disloyalty, and to let amends land. The per-assessment limits the prompt always stated are now enforced, so a model that ignores them can no longer undo a season of travel in one reply.

Saves no longer risk becoming unloadable from the relationship assessment. To give the AI context about a follower, the assessment pulled their SkyrimNet memories into a script string, and those records can run to tens of thousands of characters; saving at the wrong moment could write that string into the save, and a save carrying a string that large can crash on load. The context is now built inside the plugin, trimmed to what the prompt uses and capped, so nothing large ever reaches Papyrus. The memories also reach the AI now: the prompt had been reading field names SkyrimNet does not use, so the AI saw an unfilled placeholder where each memory should have been. (Thanks to the user who tracked it down.)

Outfit auto-switching no longer fills your follower's pack with spare armor. Since 3.9.13, every time a situation change put a preset on, the gear from the preset being left stayed behind in the follower's inventory - applying a preset by hand always took the old one's catalog copies back; the automatic switch never did. Over an evening a follower could be carrying every preset at once, taking the extras off them only lasted until the next switch put them back, and with two copies of a piece in the pack the old cleanup could grab the one you had enchanted. The switch now takes the outgoing preset's copies back exactly as the wardrobe does (your own enchanted, tempered or renamed pieces are never touched), and a switch that manages to put nothing on restores their default outfit instead of leaving them bare. Spare copies a follower is already carrying from before this fix are left alone - there is no safe way to tell a leftover from something they picked up - so take them off the follower once by hand; they will not come back.

Your enchanted gear stays on the follower wearing it. Applying an outfit preset put on a plain copy of a piece rather than the enchanted, tempered or renamed one you owned, if both were in their pack - so it looked as though your custom gear had been swapped for a generic version. The preset now picks your piece.

Gear you enchanted and renamed yourself is now safe, and findable. Skyrim keeps a custom name, an enchantment and a temper on the individual item rather than on its type, so to anything looking at the type your renamed Iron Sword is just an Iron Sword. Three things went wrong because of that. Asking a follower for the item by the name you gave it never found it - it does now. A set of custom gear handed to a follower could vanish from their SeverActions inventory while still sitting in the vanilla one, if it was built on pieces they already wore by default - it now shows, under the name you chose. And worst, tearing down an outfit preset could destroy a piece you had enchanted yourself, if the preset happened to include the same base item from the catalog; that can no longer happen, because the teardown will only ever take plain, unmodified copies and leaves anything you made alone.
NPCs no longer chat over scripted story scenes. Ambient banter picked its pair by looking around the cell itself, which meant SkyrimNet's own "Exclude Actors in Scenes" setting never got a say - it only applies when SkyrimNet chooses the speaker, and we were choosing. Anyone playing their part in a scripted scene is now left out of ambient chatter entirely, whatever that setting says.
The outfit system now has an off switch, and it turns the whole thing off. Settings > Followers > Outfit System. With it off SeverActions never dresses anyone: the outfit actions stop being offered to the AI, the buttons on the Actions page and the dress/undress hotkeys refuse, situation auto-switching stops, and the re-equip that enforces a locked outfit stands down - dress your followers the vanilla way or with another mod and nothing here interferes. This needed to cover the AI actions rather than just the outfit lock, because that was the part people were actually running into: the lock has always been off by default, but an NPC could still decide to get changed mid-conversation.

Leash Framework 1.1.1 or newer is now what SeverActions expects. Everything it does with a rope assumes the version that can tie one to a captive's bound wrists, which arrived in 1.1.1. If you have an older copy the mod now says so once, plainly, instead of quietly falling back to a collar and leaving you to wonder why your prisoners are leashed by the throat. Nothing breaks on 1.1.0 - being tugged along, dragged off their feet and tied to furniture all still work - it just looks wrong.

You can pick where the rope ties. Settings > Followers (and the MCM) now has Leash Attachment: wrists, which is the default and what everything is built around, or neck if you prefer the collar - in which case Leash Style still chooses which collar. The style setting only ever applied to the neck, so it now says so.

A bound prisoner can no longer go about their day. A restrained or kidnapped NPC could still be told to craft, trade, travel, hand over items, get dressed, pick a fight or manage a business - hands tied, held on a rope, and running a shop. Nearly every action in the pack is now closed to them while they are bound. What they keep is what a person with their hands tied still has: they can talk, they can feel however they feel about their captor, and a prisoner being marched to jail can still plead their case.

Whoever is already leading a prisoner is no longer offered the order to restrain one. Only one captive can be held at a time, so the action could only ever refuse - and an AI handed an action that does nothing will try it again every time it speaks. It comes back the moment the prisoner is set down, since taking someone in hand is now how you pick them up again.

A bound captive can be tied to a chair, a post, or an altar. Telling whoever leads a captive to tie them to something now has them walk over to it, work at it, and leave the captive chained there, standing bound beside it - so whoever was holding them is free to walk away, and the prisoner still goes nowhere. With Leash Framework installed the chain is really there, running from their tied hands to the furniture; without it the hold works the same, just without the visible rope. Telling anyone to take the prisoner in hand again unties them without being asked.

Four actions the AI could pick have been retired, and Restrain now covers what two of them did. Unleash Captive is gone - freeing a captive is what Release Captive is for, and leaving one somewhere is now the furniture tie above. Leash Captive is gone too: telling someone to restrain, seize or take hold of a prisoner does the same thing, and it now works on a captive who is already held - standing bound, or tied to a chair - so there is one way to pick a prisoner up instead of two the AI had to choose between. The AI can also no longer change a follower's combat style or following distance through conversation; combat style is still yours to set on the Companions page and in the MCM, and follow distance on the Actions page.

Binding someone and walking off with them reads as one act. The tie-and-lead hotkey filed two entries in Recent Events - one saying the NPC was held standing in plain sight, the next saying they were being led away - so the record contradicted itself a line later. It now files a single line describing what actually happened.

Arrested NPCs actually look arrested. A prisoner being marched to jail was cuffed but stood with their hands loose at their sides for the whole escort: the bound-hands pose was played and then cancelled a line later by the code that clears the animation lock. They now hold the pose the entire way, on both the guard-arrest and the dispatch routes. With Leash Framework installed the guard also leads them on a rope tied to their bound wrists, which comes off at the cell door.

Captives are led by their bound wrists rather than the throat. With Leash Framework 1.1.1 or newer the rope now runs from the captor's own hand to the captive's tied hands, and nobody wears a collar - which is what leading a prisoner actually looks like. On 1.1.0 the older neck leash is used instead, since that version can only start a rope at the collar.

Restraining someone now keeps them in hand instead of freezing everyone. Ordering an NPC to restrain someone pinned the target where they stood and posted the restrainer as their guard, so both were stuck for the rest of the scene and getting them moving needed a second order that often never came. A restraint now binds their hands and keeps them at the restrainer's heel, so the restrainer can move about with a prisoner in tow. To leave someone standing bound in a spot, have whoever holds them tie the prisoner to a chair, post or altar.

A captive leashed to their own captor can actually be led away. Ordering an NPC to restrain someone leaves that NPC standing guard over them, pinned in place - so leashing the captive to their guard produced a pair who both stood still, the captive dutifully following someone who could not move. Leashing now takes the captor off guard duty, since leading someone and standing watch over them are different jobs.

Bound captives keep their bound hands through doors. Walking a restrained or leashed NPC into another cell reset their pose and it never returned, so they arrived cuffed but standing loose. The pose is now restored on the other side of the load door, for prisoners being marched to jail as well.

A captive dragged off their feet gets their bound hands back. Hauling a leashed captive past the rope's limit ragdolls them, and standing back up cost them the hands-behind-back pose permanently - the system still believed they were posed, so it never put it back. They now recover the pose as soon as they are back on their feet, whether or not you have stopped dragging them.

Captives can wear a real leash. With the Leash Framework mod installed (Leash.esm + LeashFramework.dll, plus FSMP for the rope physics), a captive being led, marched off after a kidnap, escorted to a new place of holding, walked to jail under arrest, or chained to a piece of furniture now wears a real tether: they are tugged along when they lag, pulled through doors, and yanked off their feet if they dig in. Everything else about captivity is unchanged - the escort still does the walking, the framework adds the rope. The captive knows what is on their wrists (or, on Leash Framework 1.1.0, around their neck), and a tug on the rope (at most one every 20 seconds per captive) and every time someone digs in and gets dragged off their feet reach the conversation, so captor and captive can react to it. Settings > Followers > Behavior (and the MCM) has the toggle and the leash style; without the framework, or with the toggle off, the leash works exactly as before.
NPCs you employ, house or marry no longer treat you as a near-stranger. How well an NPC knows you was counted from spoken lines alone, so a steward running your estates, a retainer on your payroll, or a spouse could still be described as someone you had merely crossed paths with. The impression the NPC forms of you is now told what actually stands between you - marriage, employment, a stewardship, a home you gave them - along with recent events and how much you have really spoken, and its own verdict on how well they know you now replaces the line count. Those standing bonds also set a floor directly, so it holds even with background AI turned off, and forming one prompts the NPC to reconsider you instead of waiting for small talk to accumulate.

Outfits you lock on NPCs who are not your followers no longer come undone every time you load a save.

The first ten NPCs you dress with outfit presets keep their outfits enforced after a load, and they no longer take over a follower's outfit seat.

Healers you excluded from the outfit system now get the bleedout fail-safe heal too.

Followers you set to "treat as a normal follower" are treated that way from the moment a save loads, instead of briefly as custom-AI followers.

NPCs who only travelled with you, fought for you or casually followed you are no longer counted as former followers: they can apply as retainers, get reputation blurbs, and get the first-recruit welcome when you actually recruit them. Real former followers on existing saves keep their status. Retainers and other NPCs you gave a home, who never travelled with you, no longer remember their days as if you had left them.

The hotkey target mode "Last Talked To" now targets the NPC you last spoke with, in vanilla dialogue or through SkyrimNet; it never found anyone before.

Hotkeys and the quick-wheel key no longer unregister each other when either one is rebound.

The quick-wheel key no longer fires while you type in the SeverActions menu, or when it shares the menu key.

The SeverActions menu key no longer comes unbound on load if you never rebound it in the MCM.

Settings > Interface > Hotkeys in the SeverActions menu now lists Open Quick Wheel and Clear Home (Target), like the MCM does.

Settings > Outfit System, Book Reading and Spell Teaching in the SeverActions menu are now always listed. They used to appear only once the page had loaded, and not at all when the script behind them was not running; in that case they now show the default values.

The Survival and Outfits pages in the SeverActions menu no longer show a "not available - script not loaded" card when the script behind them has not loaded, or before the page has its data; they show the page itself with empty cards. The Outfits page also says "No companions with outfit data" as soon as it has its data and there is none, where it used to say "Loading" for ten seconds first.

New games start with Allow Conjured Gold off, as intended, and the MCM no longer overwrites that setting on every load; existing saves keep the value they are playing with.

The "SeverActionsNative.dll out of date" warning no longer appears when the DLL is fine, and shows readable text when the DLL really is missing.

The furniture auto-stand distance, courier events and inventory limits set in the MCM or the menu are applied again on every load.

The hold-tax switch and rate in Settings > Enterprises now show the values actually in force instead of the defaults after a reload.

A setting that cannot be applied, because the script that owns it is not loaded, is now reported as failed instead of being shown as saved.

Allow Conjured Gold shows its real value on the World page even without SkyUI.

NPCs sitting on furniture stand up before they set off on a trip again.

The pause-on-open, travel popup, trespass, yield prompt, safe-interior sandbox and follower friendly-fire toggles now always follow your saved settings on load, new games included.

Dismissing a follower mid-trip no longer turns them back into a teammate a moment later, or leaves them hanging around the destination when they arrive at the same moment you dismiss them, and a quick second trip order no longer gets cancelled by the first one finishing.

Ending a trip no longer cancels a follower's Wait.

A hostile ex-retainer leading an ambush now leaves their work post to close in.

Setting up a recurring payment, forgiving a debt and adding a charge to your debt now ask for confirmation over the conversation, like a new debt already did; before, their confirm boxes never appeared during dialogue.

Gold a companion takes from someone who owes them now counts toward the debt, and shows in the ledger under who took it.

Assessments between companions no longer re-read conversations they have already scored.

The Enterprises rail and arrow-key navigation no longer offer Camps or Wares when the page has nothing to show there.

FOMOD installer: the Basic, Travel, Combat, Outfit, Economy, Arrest, Enterprises, Kidnap, AI Overhaul Flee Patch and Sever's Hearth descriptions now match what each option installs. Economy no longer lists Extort Gold, which the AI is never offered, and Follower Actions no longer claims Extensible Follower Framework support.

A leftover web file from the old PrismaUI layout no longer ships in the package.

Re-saving or editing one of an NPC's outfit presets that they are not wearing no longer touches what they carry. It used to treat any plain copy of one of that preset's catalog pieces in their pack as the preset's own and destroy it or move it into the preset's storage, so editing 'town' while they wore 'adventure' could take the boots off them mid-outfit, or eat a pair you had given them. Only the preset they are actually wearing has its pieces taken back when it is overwritten.

An outfit preset that only partly goes on (two pieces sharing a slot, a piece their race cannot wear, a slot the blacklist keeps) now counts as applied: it is put back on them at load doors, switching to another preset or clearing it takes its pieces back, and deleting it no longer leaves those pieces in their pack for good. And a preset none of whose pieces can go on is now properly undone: their original outfit goes back on and the copies handed out are taken back, instead of leaving them naked with the copies in their pack.

Custom followers whose own mod keeps their outfit in a container (Daegon, with her patch) get that outfit back where it belongs whenever a preset is cleared or deleted, or all presets are cleared, even if a Dress, Undress or single-item change had already switched the preset off in between. Applying a second preset no longer forgets what was moved out of that container, and Clear All Presets no longer dumps its contents into their inventory.

Clearing or deleting the outfit preset an NPC is wearing from the Outfits page now finishes while the page is still open: it used to stall until the wardrobe closed, and then finish out of order, so a second click could take more of their pieces and the preset could be put back on them as it was being deleted. Their own default outfit comes back for good afterwards too, instead of being cleared again at every later load, and an NPC whose original outfit SeverActions had never recorded is no longer left with an empty one as their default. The same holds when their outfit slot is released automatically.

Applying a preset from the Actions page, the Outfits page or by asking an NPC to wear it now records which preset they have on, so the situation switch, the outfit context their character sees and deleting a preset all agree with what they are wearing; deleting the preset they have on always takes it off them first. The apply's own strips are no longer counted as an outside mod undressing them, which used to switch off enforcement for a preset wearer after one six-piece change, and a preset wearer stripped by an outside mod (a bathing mod, for instance) gets enforcement back at the next cell change instead of staying unenforced until you reload. A follower who was given their first preset mid-session no longer has every gear change counted twice.

Loading a different save, or starting a new game, in the same session no longer leaves NPCs without their default outfit. When SeverActions had switched an NPC's default outfit off for an outfit lock, an Undress or a preset in the save you were playing, the switch-off stayed on the NPC after you loaded another save where nothing held it, so the game never dressed them from their own outfit again and a later lock had nothing to restore. Their default outfit is now handed back the moment it stops being needed.

A dead NPC is no longer re-dressed. A locked outfit used to be enforced on the corpse too: loot the armor, leave, come back, and fresh copies of the locked pieces were on the body again, ready to be looted once more. The lock now stands down for anyone who has died.

Outfit presets and the situation auto-switch now leave alone anyone whose gear belongs to something else: a kidnapped or restrained captive (their hood and cuffs), an arrested or jailed NPC (the cuffs, the jail clothes) and an NPC held by a bondage mod. Before, only the plain outfit lock knew to wait; a preset came back at every load door and the auto-switch on entering combat or town stripped the restraints off.

The situation auto-switch no longer changes an NPC's clothes at the wrong moment. It used to strip and re-dress them while an Undress or a Dress was still running, while you were editing their outfit in the wardrobe, and during a SexLab or OStim scene, undoing whichever was in progress. It now waits and tries again a little later.

A worn Devious Devices restraint is no longer stripped by a locked outfit at every load door, where it turned invisible while still locked on. Nor is one captured into a preset or a lock any more, and one is never conjured back onto an NPC after its key has removed it. Every strip path now treats a device like a protected item.

Forgetting an NPC's outfit data, or the automatic cleanup of an outfit slot nobody uses any more, no longer deletes another mod's outfit container from your save. A custom follower whose outfit lives in their own mod's chest (Daegon, for one) had that chest deleted for good, along with the satchel holding the clothes SeverActions had moved out of it. The clothes now go back into the chest first and only SeverActions' own wardrobe chests are removed.

A second copy of a preset piece that you hand a follower to carry is no longer thrown away at the next cell change. Applying a preset used to trim the follower down to exactly one copy of each catalog item on every re-apply, and the extra it deleted was as often your gift as anything of its own.

Re-applying a locked outfit, and the older preset apply, now put your enchanted, tempered or renamed piece back on the follower instead of a plain copy of the same item they also happened to carry, the same way the wardrobe already did.

The Situational Auto Switching and Defer to Bondage Mods settings are now applied for each save before anything gets dressed after a load. Their values used to arrive last, so the first re-dress after loading ran on whatever the previous save, or the defaults, had set.

With Outfit Lock turned off, an outfit lock that is not one of your presets is kept but no longer put back on at load doors, wherever it was made. Before, the native re-dress ignored the toggle for those locks.

Changing a single piece of what someone is wearing from the Inventory page (the equip and unequip buttons, or moving, destroying or selling a piece they have on) and the X in the wardrobe's Currently Wearing list now stick for an NPC who is wearing one of your outfit presets. The preset used to notice the change and put itself back within a second or so, or at the next load door: a helmet you equipped came off again, gloves you took off went back on, and a cuirass you moved to your own pack or sold was handed back to them from the preset's chest, so moving it gave you both a copy and selling it paid you for a piece they kept. The rest of the preset stays on and, as with the equip and unequip actions, the preset stops putting itself back until you apply an outfit, clear or delete that one, or tell them to get dressed.

Turning Situational Auto Switching on or off from the Outfits page now stays set after you load a save, and the MCM shows the change straight away. Before, the Outfits-page toggle was forgotten at the next load (the MCM's own toggle was remembered).

Closing the wardrobe with staged pieces in the cart no longer loses the NPC's outfit lock. Switching to another follower while a staged piece covered a locked one made the lock look out of date and drop for good; the check now waits until the staged pieces have been taken back off.

Renaming an outfit preset to a name another of that NPC's presets already has is refused, with a notice on screen, instead of quietly overwriting the other preset's contents under the old name's toast, and the Outfits page no longer says "renamed" for it. A name that differs only by a trailing word preset names leave off, such as "outfit" or "gear" ("Town Outfit" when "Town" exists), counts as the same name. Pick a different name, or delete the other preset first.

An NPC's Devious Devices are no longer written into the outfit presets and outfit locks the Outfits and Inventory pages create (saving what they wear as a preset, Snapshot Lock, the wardrobe's Currently Wearing list and the Inventory-page equip). A device caught in a preset that way came back as a copy the framework did not know about, force-equipped, once the real one had been unlocked with its key, and it could not be removed. The dialogue actions already left devices out.

Equipping a piece on an NPC from the Inventory page no longer puts an outfit lock on them by itself. It used to lock anyone with a SeverActions record of any kind, even with Outfit Lock switched off, so a companion, or an NPC you had merely sent somewhere, was silently locked into what they had on and lost the next armor they were given at a cell change. Now it keeps an existing lock up to date, and starts one only when Outfit Lock is on and the NPC is or was your companion.

Giving a follower who wears one of your outfit presets a better piece of armor no longer lets it stay on. When the game swapped two pieces at once for the new gear, the outfit system read the swap as a bulk strip by another mod and stood down for the rest of the session, so the intruding armor stayed and every later change was ignored until you changed cells. Only genuine strips (three or more pieces coming off at once) make it stand down now, and the swapped-in pieces are cleaned up as intended.

A follower's own enchanted, tempered or renamed piece that you saved into a preset is no longer counted as one of the preset's supplied copies. A plain copy of the same item they picked up or were given later used to be taken away when they changed presets.

A custom follower whose mod keeps her outfit in its own container (Daegon Kaekiri) gets that container back in full when a preset is cleared. Every copy of each piece goes back where it came from; before, one of each went back and the rest ended up in her pack. The container is also found again on load: the automatic registration had been looking up the wrong record and had never worked, so without the separate Daegon patch her mod's own outfit enforcement fought every preset.

A dismissed follower, or an NPC who could follow you but never has, is no longer treated as a current follower by the outfit slot system just for having once been in the follower faction. Saving a preset for one used to take an outfit slot and spawn the slot's storage containers for someone nobody was travelling with.

Deleting an outfit preset now also removes the backup copy of its item list, so a preset you later re-create with the same name can never be refilled from the deleted one's items.

With the Outfit System turned off, the Outfits page's Apply button and the wardrobe's live preview now say so instead of pretending to work. Apply used to play the clothing sound and refresh as if the preset had gone on while nothing happened, and staging pieces in the wardrobe still dressed the NPC in them; both now show a notice that the outfit system is off, and Apply says the same when the NPC is excluded from the outfit system.

The Outfits page and its Nearby tab now honour "Disable live mannequin" wherever it was set. They used to read the setting from the SkyUI menu, so without SkyUI, or with the MCM left out of the install, the page always saw it off and started the live mannequin that the player had turned off to avoid a crash.

Equipping or unequipping a piece from the Inventory page now shows the change straight away. The page's refresh used to run before the game had actually put the piece on, so it briefly reported the piece as not worn and undid the button you had just pressed until the next refresh.

A worn piece of an NPC's own default outfit that you had enchanted, tempered or renamed now shows as worn on the Inventory page, with an Unequip button. It used to show Equip while already on, and pressing it could create an outfit lock.

Discarding a wardrobe change now puts the NPC's own enchanted, tempered or renamed piece back on. When they also carried a plain copy of the same item, the revert used to put the plain one on and leave your work in their pack.

Closing the SeverActions menu with several followers' wardrobes open no longer does every outfit revert in the same frame; they are spread one per frame, which is what removed the close-time stutter the last time, and had quietly stopped happening.

A situation outfit change now completes while you stand still. The auto-switch waits five seconds of a stable situation before it dresses anyone, and the check that ends that wait only ran while you were giving input, so a follower whose situation changed as you stopped moving (you walk into town and open the map, or talk to a guard) stayed in the old outfit until you touched a key. The same wait-out now finishes the relax-at-home entry the followers get when you arrive home and stand still.

Applying an outfit preset by hand no longer gets overwritten by the situation outfit. With the auto-switch off and a Town outfit mapped, applying Casual in town used to put Town Outfit straight back on; the re-check after a manual apply now only records the situation and dresses nobody unless the auto-switch, the outfit system and that NPC's own auto-switch are all on. Entering a situation whose outfit the NPC already wears no longer strips and re-dresses them when the mapping was saved with different capitalisation (Home against home).

NPCs now know the names of their saved outfit presets: the outfit section of their bio lists them, and a new sever_outfit_presets decorator lets the outfit actions be offered only to someone who has presets, so the model asks for the preset you actually saved instead of guessing a name (a wrong guess did nothing, a near miss picked a random preset). While the outfit system is off, or an NPC is excluded from it, their bio no longer tells them which outfit they are wearing or which outfits they change into, since none of that holds while the system stands down; the situation lines are also left out while the auto-switch is off.

Asking a follower to take off a piece you renamed (an Iron Helmet you called the Frostbite Helm) now works: the unequip actions matched only the base name, while the equip actions already matched yours. Equip & Lock from the wardrobe catalog now works for armor from ESL-flagged plugins and from high load-order slots; those FormIDs were parsed as 0 and the lock logged Armor not found. The Loot action's gold mode now actually moves the gold; it looked up the gold form in a way that always came back empty.

NPCs a bondage framework (Diary of Mine, Paradise Halls) has released are dressed by SeverActions again. The framework leaves them in its faction at a disabled rank, and the deferral read that rank-blind membership as still controlled, so their outfit lock and presets were never re-applied after release.

When a follower's plugin is removed, the wardrobe chests SeverActions had placed for their outfit slot are now deleted on the next load instead of staying in the save as orphaned persistent containers forever. A save whose equipment-blacklist record is damaged now loads with the blacklist dropped and a log line instead of crashing.

When an outfit preset puts nothing on an NPC and SeverActions falls back to dressing them in their own default outfit, that fallback now works for NPCs whose default outfit is built from leveled lists, which is most of them. It used to skip every leveled entry, log that the outfit was back on, and leave them standing there in nothing. It also wears an enchanted, tempered or renamed piece of theirs when they have one rather than a plain copy.

A locked outfit whose armor came from a mod you have since removed is now cleared when the save loads, and the NPC gets their default outfit back. Before, the empty lock stayed on: nothing could re-dress them, but SeverActions kept telling the game they had no default outfit either, at every load, until you found the lock and cleared it yourself.

Excluding an NPC from the outfit system, or soft-resetting them, now gives them their default outfit back if they had been undressed and never locked. Before, that outfit stayed switched off for the session and was switched off again at every load.

Loading an older save, from before outfit data moved into the SeverActions co-save, after a newer one in the same game session now imports that older save's outfit locks and presets. They used to be skipped, and the next save then recorded them as already imported, so they were lost for good.

A locked outfit no longer pushes off a piece you have blacklisted that shares a slot with a locked piece, such as a wet-and-cold hood or a backpack, at every cell change. And SeverActions no longer mistakes its own cell-load re-dressing of a locked NPC for another mod stripping them, which could switch its enforcement off for that NPC until the next resume.

With the player selected as the subject on the Actions page (the default), the outfit buttons no longer save a preset, an outfit lock, a situation outfit or an undress for the player. Those records were deleted at the next load anyway, and an undress had left the player's default outfit switched off on every load in between.

On Skyrim VR, and on any install without the EditorID-keeping tweak, SeverActions now recognises an OStim scene: the outfit and kidnap actions no longer strip or seize an NPC mid-scene there. The OStim faction is found by its record now rather than by a name the game does not keep.

When an outfit preset fails to put anything on an NPC, the clean-up now takes back only the pieces that apply had just handed them, whether the apply came from the situation switch, the wardrobe, the Actions page or a conversation. It used to take one copy of every piece the preset lists, so plain clothes you had given them to carry could go missing each time the situation switch retried. Re-applying the preset someone already wears still takes that preset's own copies back when it fails, so none are left behind.

A follower wearing one of your outfit presets is no longer stripped and re-dressed at load doors when they already have the whole preset on: they are left alone when they load in, when you change cells and when that preset is applied to them again, instead of having everything taken off and put back with a flicker. A missing piece, an extra piece the game put on them, or a piece a blacklisted item keeps off still gets the preset put back.

Pressing Escape straight after saving changes to the outfit a follower is wearing no longer leaves them in a mix of the old and new pieces. Closing the menu used to lift the pause on outfit enforcement while the preset was still being rebuilt, so the follower could be dressed from a half-written wardrobe; saving, applying and clearing a preset now keep that pause until they finish.

Taking a piece of a locked outfit from a follower now keeps it taken. The lock used to hand them a fresh copy at every load door, so the piece multiplied between your pack and theirs; now the lock waits and puts the piece back on only if they get it back, and in the meantime they keep whatever else they wear in that slot.

When several followers change into their situation outfits at once, or several outfit locks are put back on after a cell change, the changes are now spread over a few frames instead of all landing in one, which avoids a stutter on Skyrim VR.

Dismissing a follower from the Companions page now undoes what recruiting them changed. The page used to wipe the follower's record a moment before the dismissal read it, so an NPC whose own record makes them essential lost that status, and Serana was dismissed without her own dismissal. And no dismissal, from the page, the MCM or conversation, gave a follower back the combat style they had before you set one: the dismissal read it only after clearing it.

Force Remove and Clear Fallen on the Companions page now finish the clean-up. The follower's record was erased before the clean-up ran, so the bed claimed for them at home kept them as its owner, their places in the home, work and relax schedules were not freed, the marker for a relax spot you had set stayed in the save, and a bodyguard stayed bonded to the person they guarded. Force Remove, from the Companions page or the MCM, now also gives the follower back the combat style they had before you set one, and takes away the healer role if you had made them one, as a dismissal does.

Excluding an NPC from the outfit system, or from off-screen life, now survives dismissing them or soft-resetting them. Both used to switch the exclusion off without telling you, handing the NPC back to SeverActions. A soft reset also keeps the combat style the follower had before you recruited them, so a later dismissal still gives it back.

A dismissed follower keeps the outfit lock you gave them: they wear that outfit at home too, and they get it back if you recruit them again. Dismissing used to throw the lock away. A follower wearing one of your presets also keeps it on at home without the game's default outfit coming back in between. Force Remove, the clean-up after a follower's death and the soft reset still clear the lock.

When a follower dies, the clean-up now also clears the outfit data SeverActions kept for them, as Force Remove already did; their saved outfits and situation outfits used to stay in the save.

With more than eleven NPCs holding outfit locks, the followers travelling with you who wear a locked outfit now get the outfit watcher's places first. Dismissed followers and other locked NPCs take the places left over, and with Outfit Lock on their locks are still put back on at load doors; before, locked NPCs who were not following could take every place and leave your current followers' locks unwatched between load doors.

Equipping a staged outfit from the wardrobe no longer leaves spare copies in the NPC's pack. The pieces the preview had given them to try on were treated as their own gear when the outfit was saved, so they were never taken back when another outfit went on; they are now handled like any other piece the preset provides.

The Outfits page now sends the exact NPC with Apply and Delete on a preset, so with two NPCs of the same name the one whose card you clicked is the one dressed or whose preset is deleted.

The Outfits page's Snapshot Lock button now refuses, with a notice, while the outfit system is turned off, and no longer writes an empty lock when the NPC wears nothing it could lock. It used to write the lock anyway.

An NPC SeverActions stops managing outfits for (no preset on, no outfit lock, not following) is no longer kept loaded in their old outfit slot for the rest of the playthrough: when a save load releases the slot, the NPC is let go from it in the same load.

The live outfit preview no longer risks freezing the game when it catches an NPC's head half-rebuilt (right after an outfit preset went on, for instance). The preview survived that moment but could leave the head's data claimed, which could hang the game with no crash log the next time Skyrim updated that face. It now draws without the half-built piece and always lets go of it.

A worn piece or an inspected item whose model switches between variants (the way a model swaps its level of detail, or a plant shows whether it has been picked) now shows the variant the game shows. The live outfit preview and the item Inspect view used to draw every variant of such a model on top of each other.

The live outfit preview and the item Inspect view no longer squeeze or stretch what they show. On a 4K screen (and on some 1440p ones) the Outfits mirror drew the NPC noticeably too thin, in Skyrim VR every inspected item came out stretched sideways and the mirror figure too wide, and a mirror too tall for its frame showed an elongated NPC with the feet cut off. The picture is now rendered at the proportions it is shown at, and a mirror taller than its frame fits the whole figure into the visible part.

The live outfit preview now lights an NPC the same way whichever direction they stand facing. Only NPCs facing north or south were lit as intended: one facing east or west was lit as if from behind, so their face, body and armor came out dim and flat, and one facing a diagonal was lit from the side. Items in the Inspect view that the game turns into their display pose were lit from the wrong side the same way. An NPC's face, body and armor now look at every heading the way they always did facing north or south, and a piece of gear that hangs rigidly from them instead of bending with the body is now lit from the correct side at every heading, north and south included.

The live outfit preview and the item Inspect view now draw materials the way the game does. Armor, clothing and weapons with surface relief were lit as if the bumps were turned sideways, with hard seams where the shading flipped; they now catch the light as they do in game. In the Inspect view, see-through cutouts (fur trim, feathers, netting, leafy ingredients) came out with dark, thickened fringes, TruePBR gear had its shine backwards (rough leather glossy, polished plate dull), and some textures sat in the wrong place; they now look the way they do on the Outfits mirror. Cutouts no longer cast solid rectangular shadows, overlapping see-through pieces no longer draw the far one over the near one, a RaceMenu makeup or tattoo overlay set to partial opacity shows at that opacity, a piece the game hides by making it fully transparent stays hidden, the see-through edges of hair no longer pick up a grey sheen, glow maps now light up, cloth and leaves that let light through from behind now do, textures meant to stop at their edge no longer repeat the opposite edge, circlets, earrings and glasses stay on the head instead of floating off it when the NPC is looking aside, and a face's brightness is now matched to the NPC's body skin instead of whichever hand, foot or overlay texture was read last.

The live outfit preview and the item Inspect view no longer keep eating video memory. Every texture they loaded (the normal, glow and shine maps of each armor piece, weapon and item) stayed in memory until you quit the game, so browsing many items in the Inspect view or previewing outfits on several NPCs made the game use more and more video memory for the rest of the session. They now keep only what they are showing, and a few seconds after the last preview closes they let go of the rest along with their own drawing buffers (up to about 60 MB); the next outfit preview, and a return to an NPC you previewed earlier, then fills its textures in over a few frames, as the first one of a session always did. The outfit preview also no longer risks a crash when a mod swaps a tattoo, overlay or face texture on the NPC while the preview is open.

The live outfit preview no longer gives up on an NPC whose model reloads for a moment while you watch (another mod resetting their body or appearance, or the NPC being briefly disabled): it keeps showing the last picture for a few seconds and picks them up again once they are back, where it used to switch that NPC to the see-through fallback until you picked someone else or reopened the menu. An NPC who does not come back in that time is now reported as not nearby. Switching to an NPC whose model was still loading, just after opening the mirror on another, no longer drops the new mirror to the see-through fallback either; it waits for the model as a first opening does. Hovering an item on the SeverActions Inventory page while one of the game's own item menus is open underneath (an inventory, container, barter or crafting menu) no longer blanks that menu's 3D item preview.

The live outfit preview and the item Inspect view cost the game less while you use them. The first preview of a session no longer stalls the game for about a quarter of a second while its shaders are built: they now build in the background when a preview first opens, and the picture appears a moment later instead. Scrolling the Inventory page with an item in the Inspect view no longer redraws the item at every step of the scroll, adding a piece to the outfit cart re-reads the NPC twice instead of three times, moving from item to item no longer closes and reopens the preview's hidden menu (which other mods see as a menu opening and closing), hovering again over an item whose model cannot be drawn no longer reads its files again, and the first look at an NPC whose skin uses large textures reads a few kilobytes of each texture instead of the whole file. On a Magelight install that draws its pages without the graphics card, the Inspect view and the mirror now switch to their fallback at once, where every inspected item showed an empty stage for six seconds first; and if the graphics card refuses what the preview needs, the preview now switches to its fallback and names the refusal in the log, where it used to try again every frame and could drop the game to a few frames per second. The log no longer gets a timing line every two seconds while a preview is open (only while it runs slowly), nor a list of every part of an NPC's model each time the mirror opens on someone in a helmet or hood.

Upgrading from 3.9.14 or earlier now deletes the folder of preview pictures the old outfit preview and item Inspect view saved (Data/PrismaUI/views/SeverActions/mannequin, which under MO2 sits in the overwrite folder): nothing reads it any more. The Inventory 3D item viewer setting no longer mentions the picture fallback that went with it.

## v3.9.14 - Coming and Going

Retainers set to guard or attend someone now actually follow them. The guard-duty alias pool carried a package the engine could never select (it was owned by the wrong quest), so a bodyguard sat on the plain work routine instead of shadowing their charge - visible as a Whiterun guard told to attend Danica just standing at his post. The pool now carries the right package, and a retainer who was given a workplace first and a person to guard later is seated on guard duty at once instead of never.

Followers can now be told to wait and actually stay put. A waiting follower used to relax within about a room's width of where you left them and could wander out of sight; the new Wait In Place toggle (Settings > Followers > Movement, and the MCM Followers page) has them stand where they were left instead. Off by default, and the wide relax remains the behaviour when it is off.

Only your own followers can be told to wait or to fall back in step through conversation. The AI could previously park any NPC it was talking to — a field report had Irileth abandon the march to the Western Watchtower to relax mid-quest because "wait here" was open to everyone. The Wait and Follow actions are now offered only for someone actually travelling with you (a teammate, or anyone SeverActions is driving, casual followers included). The wheel and the Actions page still work on whoever is in front of you.

Followers no longer teleport to you moments after a save loads. A catch-up sweep dispatched just before the load could still land inside the post-load quiet window and move everyone onto the player; it is now checked again at the moment it runs. A real fast travel still brings followers along as before.

Recruiting and dismissing a follower through their own dialogue menu now behaves the same as using the wheel, a hotkey, or the Actions page. Before, SeverActions only watched the player-teammate flag to notice these dialogue recruits and dismissals, which was slow and could miss them entirely — a follower re-recruited by dialogue after being dismissed might never start following again, and a dialogue dismiss could send a homed follower to their default spot instead of the home you gave them, for about half a minute. SeverActions now also watches the follower/hireling faction the game itself stamps, which is immediate and reliable, so a dialogue recruit is picked up and set following at once; a dialogue dismiss is caught the moment the follower's package changes and confirmed in under a second, so a homed follower heads home within a couple of seconds. Dialogue-recruited followers also now get the same care as the rest — made essential, safe from your stray hits, immune to their own traps — and a returning healer heals again.

Followers run by their own AI now go to their assigned home when you dismiss them through their own dialogue. A custom follower like Sofia marks a dismissal with her own faction rather than the vanilla one, so SeverActions never noticed she had been dismissed, kept tracking her, and never sent her home; dismissal detection now recognises any framework's dismissed marker. Re-recruiting her a moment later no longer parks her at home for a minute either.

Dismissed followers reach their home routine promptly instead of standing frozen. A follower who lands on an empty engine package at home is put back on her home routine within seconds — you no longer have to wait a game hour to shake her loose.

SeverActions can now stand apart from Nether's Follower Framework. With NFF installed and Recruitment Mode set to SeverActions, followers you recruit through SeverActions are driven by SeverActions directly and never handed to NFF, so removing a follower from NFF's menu no longer also drops them from SeverActions. Followers recruited through NFF's own dialogue stay NFF's, as before.

The Imperial Levy can be switched off. Settings > Enterprises (and the MCM Enterprises page) gain an Imperial Levy toggle, on by default. Off, the Final Audit detail — the General, his two Legates and the twelve soldiers posted to the holds — never deploys, and one already in the field is stood down and removed within seconds of the change: every soldier disappears where they stand and the case closes. Turning it back on lets the case open again as it did before.

Followers are no longer made essential automatically. Essential protection is opt-in per follower from the Companions page (the Essential toggle on the Profile tab); a new recruit can die like anyone else until you turn it on. Followers who were already essential in an existing save keep that, and a follower whose own record makes them essential (Lydia, the housecarls) is never touched either way. The choice survives dismiss, re-recruit and save/load.

## v3.9.13 - Settling In

Followers no longer set off on journeys of their own just because a place came up in conversation. "I'm thinking of visiting Whiterun" could send half your party marching out the door - the travel action was open to anyone, and the AI took musings as marching orders. Followers are now excluded from the travel action by default; if you want your companions free to wander off when the conversation takes them, there is a new Followers Can Travel toggle on the Settings Travel page and in the MCM. NPCs who are not following you are unaffected either way.

Dressing a follower now leaves you a reusable outfit you can name and re-apply. On the Outfits page the Equip button used to lock that exact set onto the NPC and nothing more; now it also saves the set as an automatically-named preset — Outfit 1, Outfit 2, and so on — that you can rename, apply again later, or map to a situation. This is the last step of moving outfits off the old lock system and onto presets entirely, the same machinery that keeps what someone wears consistent across cell loads and reloads. Staging fresh pieces on someone right after you save and rename a preset works now too — for a moment it quietly didn't.

Home outfits switch at your house, not only theirs. A companion with a home assignment would change into their Home-situation outfit when they reached that home; now the same switch fires when they are inside a house you own, together with you. Map a relaxed set to the Home situation and your followers put it on when you all get home.

A follower another mod runs no longer freezes at home now and then instead of relaxing. A companion owned by its own framework — an NFF or a custom follower like Rin — would occasionally get stuck standing in place in a fallback wait pose when you came inside, rather than settling in to relax, and only some of the time. The relax hand-off was switching off their own follow behaviour as a side effect, so when the timing went wrong they had nothing left to do and the game pinned them where they stood. That side effect is gone for these followers; if anything slips now they simply keep following you rather than freezing. (Thanks to the user who noticed it happened only sometimes.)

You have more say over what NPCs make of you, and their first impressions read straight. Three changes to the ‘How they see you’ side of the Companions page. There is a new update button beside the blurb — a small circular arrow — so you can refresh a follower's read of you on demand instead of waiting for the automatic pass, which is handy right after something significant passes between you. Some followers had been stuck on a stale or empty blurb: a guard meant to avoid re-summarising the same moments had, over a long game, frozen the update for anyone you spoke with less often — that is fixed, and a stuck follower catches up on their next real conversation, or the instant you press the button. And NPCs stop insisting they have met you an exact number of times — a familiarity note was handing the AI a raw tally it would recite as ‘I have seen you three times’; the number is no longer shown to it, so a passing acquaintance sounds like one again. (Thanks to the players who reported both.)

The menu key closes the menu again. Opening the SeverActions wheel with a hotkey and then pressing that same key now closes it, the way it always had — for a while only Escape would.

VR no longer crashes when an NPC travels. On Skyrim VR, the moment any NPC set out on a journey the game threw a script-extender error ("Failed to find the id within the address library: 36812") and stopped. The travel system's stuck-detector was calling an engine function (IsPathing) that exists on flat Skyrim but was never mapped for VR, so the very first stuck-check on a traveler crashed. VR now skips that one refinement and falls back to plain distance-based stuck detection - travel works, and a slowly-pathing NPC might occasionally get a harmless nudge. Flat-screen players were never affected. (Thank you to the VR user who reported it with logs.)

Outfit auto-switching no longer freezes the game on a cell change. On a heavy load order — worst in VR — walking into a town or a house could hitch or briefly lock up as your followers changed outfit. The cause was every follower re-dressing in the same instant on the game's main thread; the re-dress work is now spread across frames a follower at a time, and the redundant inventory scans behind each change were removed, so a group changing together no longer blows the frame budget. The two re-dress passes that run on every cell load got the same treatment, and a rare reapply loop that could quietly churn after a transition was closed. As defensive hardening, a handful of location lookups that walked a home or town's parent chain without a stop are now bounded, so a malformed location record in a big modpack can no longer spin the game.

Situation outfit switches actually happen when they should now. Several changes never took at all, each for its own reason, and all are fixed. One that landed while you were standing still — weather turning, or arriving somewhere and immediately talking to someone — was waiting on input that never came; a change now completes on its own a few seconds later even if you touch nothing. A quick fight was often over before the five-second settle could arm, so combat gear now goes on the moment a fight starts and comes off once it is truly over. A follower dithering right at a city's edge, where the game kept flipping between town and wilds, used to reset the timer every second and never settle; a brief flicker is ignored now so they commit. Mapping an outfit for a situation someone is already standing in applies on the next check instead of being ignored. And a preset whose items went missing after a load-order change no longer fails silently or strips the follower bare — it is noted in the log, left alone, and retried on its own so it recovers the moment you fix it. A momentary blank cell mid-transition no longer reads as a false trip out into the wilds either. And leaving a place for somewhere with no outfit of its own and then coming back is recognised as a change again, so the right outfit goes back on when you return.

Your home is the inside of your home now, not the yard. A companion assigned to a house was treated as "home" while standing in the yard outside it too, because a player home's map location quietly covers the surrounding land. Two things came of that: a home outfit stuck to them out in the yard so an Adventure or Town outfit never took over, and a homed follower kept sitting down to relax in the yard instead of following you out (until something like a fight snapped them out of it). Home is now recognized only inside the house, so stepping outside reads as the wilds or the town as it should, and a follower you lead out the door comes with you. A follower with no assigned home was never affected.

Bio Blocks work without PrismaUI now, and arrive with a library already filled. The custom-bio system - write a trait once and hang it on anyone - used to need the web UI to manage, which a lot of VR players simply cannot run. There is now a full Bio Blocks page in the MCM: aim at someone, pick a block, apply it; grant a block to a whole faction; or remove one - all through SkyUI, no PrismaUI required. The faction picker searches your entire load order rather than only the factions of people standing near you, so you can grant something to Windhelm's court from the other side of the map. And the mod ships with a starter library of seventy-eight blocks across seven tabs, written into your save folder the first time you load - so the page has something in it when you open it instead of a blank slate, and your own edits win from then on.

Followers relax at home again - reliably, in modded homes, and without being left behind. The system that lets your companions settle in and potter about when they are home with you had been half-broken for a long time, and an audit turned up three separate faults. The relax package was being marked as applied a moment before it actually ran, so a follower looked settled but never sat down. The whole thing only recognized vanilla player homes, so any modded house did nothing at all. And leaving could strand a follower standing in the house instead of gathering them to come with you. All three are fixed: a home is recognized by who owns it now, not just the vanilla house tag, and the leave-check no longer waits on you to move around before it fires. Anyone stranded in an existing save sorts themselves out the next time they pass through a door.

Your NFF, Dawnguard and custom-quest followers get to unwind at home too. The home-relax used to skip any follower another mod owns - an NFF companion, Serana, a custom follower - to stay clear of their AI. But they should get to sit down at home like anyone else, and the only step that ever fought their framework was re-driving them on the way out, so that is the only part held back now. When you leave, one of these followers has the temporary relax package quietly lifted and simply resumes their own following, instead of being marched back onto SeverActions' leash. It also no longer matters where a follower sits in your load order: followers added by late-loading mods were being silently skipped, and now they are not.

Relaxing at home actually sticks now. Walking into your house with companions used to start a little war under the hood: the relax behaviour was applied into the storm of everything else a cell load kicks off, lost the fight, and left followers frozen in a fallback pose for up to twenty seconds - and even once settled, the game could knock them off the relax at any time and nothing put them back. Three fixes: the relax now waits a few seconds for the dust to settle and then applies cleanly on the first try; a watcher re-seats it if the engine ever knocks a relaxing follower onto that frozen fallback (and knows when to stop pushing, so it never fights another mod for control); and the relax no longer strikes up its own NPC conversations, which turned out to be what was randomly yanking followers out of it. Moving between rooms of your home works the way it always did - your followers come along and settle back in wherever you are - and leaving gathers everyone to the door and puts them back on your heels.

Sleeping no longer wakes you to followers who forgot they were relaxing. Going to bed used to end with everyone snapped back onto your heels - the wake-up pass re-asserted following on the whole roster whether or not you had parked them. Followers who are waiting or relaxing are left exactly as you left them now; only the ones actively following you get their follow refreshed.

A follower whose own mod takes her back is let go honestly. When a framework-run companion - NFF, a custom follower like Rin - was relaxing and her own mod re-asserted its follow, SeverActions kept counting her as relaxing while she was in fact walking at your shoulder, and every system that trusted that bookkeeping made wrong calls around her. That reclaim is now recognised for what it is: SeverActions quietly withdraws its relax, her framework keeps her without so much as a hitch in her stride, and after a couple of polite retries in one visit it stops offering the armchair until you next come home.

Custom followers whose own mod runs them can finally be dismissed - and stop dropping off the roster. Some followers follow through their own mod's quest rather than the shared system SeverActions can reach - Rin is one - and they were impossible to dismiss: telling them to leave let go of SeverActions' hold while their own mod kept them walking, so the game counted them dismissed while they trailed after you anyway. Those followers are hands-off now: their own mod owns recruiting and dismissing, so their dialogue works, and SeverActions keeps only the conversation layer - bio, gossip, memories, relationship. A companion of this kind was also quietly falling off the tracked list every thirty seconds, because their mod does not flag them as a teammate the way vanilla does; they are kept tracked as long as they are actually still following you, recognized by their follow faction or their follow package. (Thanks to the user who suggested watching the package they are really on.)

An NFF follower you had sent home can be brought back. Giving an NFF companion a home or a relax spot left a marker that pinned them, so afterwards a re-recruit would not take. It is read as a genuine re-recruit now, the way the work assignment already was.

Brawls stop ending themselves out from under you. Two ways a fair bout could end wrongly are fixed. As a spellcaster, the setup that is meant to empty your hands was not fully taking the spell out - it landed in a limbo state where it looked unequipped but was not, so a beat later you would re-ready it, it would fire, and the no-magic rule read that as cheating and handed your opponent the win. Your hand is cleared properly now, on every kind of brawl. Separately, the check that forfeits you when you lower your fists had been reading an ordinary lull in the fight - the brawler stance can look like "combat over" for a moment - as you giving up; it now watches for the actual sheathe animation, so only genuinely dropping your fists counts as a yield. (Thanks to the players who reported both.)

Followers come through doors behind you, not in front. The catch-up that gathers your companions after a load door had started placing them ahead of you along your heading - and even pulling same-cell followers out in front of where the game had correctly dropped them behind the door. That is the opposite of the vanilla feel most players want. Door transitions leave everyone behind you now, the way they used to; fast travel still gathers the group exactly as before.

Jarl and guard actions know who is actually a jarl or a guard. Two behind-the-scenes checks were pointed at the wrong faction. "Is this person a jarl" was matching every citizen of an Imperial hold rather than the jarl - which fed jarl-only things like granting tax relief or raising a hold's taxes - and "is this a guard or authority" was aimed at the housecarl faction. Both are corrected to the real factions, so those actions and the lines that lean on them stop misfiring on ordinary townsfolk.

A guard sent to arrest someone who has since moved elsewhere now follows them. When an arrest target had walked off to another part of the world, the redirect meant to send the guard after them was quietly aiming at the wrong internal marker and doing nothing. It points at the right one now, so the cross-area chase actually happens.

A follower you just recruited already has opinions of your other companions. Bringing someone new into the group used to leave them with no view of the others until the next relationship pass came round. Their opinions are formed the moment they join now (and when they are first noticed mid-session), and a round of assessment refreshes what the whole roster thinks of each other rather than only the person being assessed.

Two character descriptions that had gone quiet or started repeating themselves are fixed. Under the hood, a couple of the templates that describe an NPC to the AI were still reading from an old storage spot after the data itself had moved - so on a current save the "how they feel about you" line came up blank, and the relationship assessment lost track of what it had already seen and re-sent every recent event each time it ran. Both read the right source again: feelings show up, and an assessment only weighs what is genuinely new.

Off-Screen Consequences is on by default, and stays that way. The setting was meant to default on, and did - but its "reset to default" button set it off, and the tooltip claimed off was the default. Both are corrected. The in-game dashboard also stops showing a stray "1.1" where its version should be and shows the real mod version.

Hide Helmet is gone. Keeping a helmet equipped for its stats while hiding it from view is something a few established mods already do well, so there was little point carrying a thinner version of it here. The per-follower toggle has been removed from the Outfits page; nothing you are already wearing changes.

The Fertility Mode bridge got a hardening pass, with thanks to the player who sent in their own patch. Two crash windows are closed: an actor caught mid-transition between cells could reach Fertility Mode Reloaded's data handler and take the game down, and the whole scan now stands down during a cell transition and resumes on its own. The bridge also stops flooding the script log - it polled Fertility Mode every three seconds and each poll could log a burst of harmless-but-noisy cast errors (about forty lines a minute, which made real problems harder to spot and got blamed on whatever mod was mid-call); a broken none-check inherited from the original bridge is fixed and the poll runs once a minute now, which is still far faster than pregnancies progress. Verified against FM Reloaded 1.0.3 and the new 1.0.5 - both work unchanged.

Existing saves load straight into this and repair themselves where they need to - nothing here changes the save format, so there is no rollback hazard this time.

## v3.9.11 - The quartermaster's ledger

Fixed a crash on saving - including the automatic save at the start of a new game, right as the Imperial captain asks who you are. The hidden room where the Fiscal Levy waits before deployment carried a wrong flag on its cell record (the same defect the depot vault cell once had), which left everyone parked inside it without a proper cell link; the moment the game wrote a save that included them, it crashed. Players whose levy had already deployed never saw it - the soldiers had long since moved to real cells - which is exactly why it survived testing. New games hit it every time. One flag cleared; existing saves heal themselves on the next load.

## v3.9.10 - Housekeeping

You can clear a home that got stuck. There is a new Clear Home (Target) hotkey - point at any NPC and press it to wipe their home assignment, which lets go of SeverActions' home sandbox so the NPC (or NFF) takes back over. It works on anyone: a follower, a dismissed companion, an NFF-owned one, or a townsperson an errant command sent to live somewhere. And home management now lives on its own Homes page in the MCM. It used to sit at the bottom of the Followers page, which had grown long enough that SkyUI was quietly cutting off everything past a certain point - and the clear-home controls were exactly what fell off the end, so they had effectively vanished (thank you to the user who went looking for them). They have room to breathe now, and the list shows up to fifty homed NPCs.

Nearby townsfolk trade instead of wandering off. The ambient director - the occasional moment where someone near you does something of their own accord - used to send people off on journeys, which meant it kept choosing odd destinations and, now and then, picked you. Journeys are out. In their place people deal in small, believable ways: selling a mundane good to someone who needs it, handing something over, or using something they plainly carry - a traveller eating bread, a wounded sellsword downing a healing potion. The player is never the one chosen to act.

The Levy soldiers no longer set off the error checker. Anyone who ran xEdit's Check for Errors on the plugin saw nineteen warnings on the Imperial Fiscal Levy - the twelve soldiers and seven pieces of their kit. They were false alarms the whole time: the soldiers take their looks from vanilla templates rather than their own record, and their gear is deliberately plain, so xEdit read empty fields as broken links. Those are tidied away now. The patrols themselves also stopped shuffling their formation while nobody is watching - they only re-form when you are actually there to see it.

## v3.9.9 - Whose follower is this?

SeverActions and Nether's Follower Framework stop fighting over the same NPC. Recruiting, dismissing, waiting and resuming now go THROUGH NFF when NFF owns the follower, instead of around it - which is what left companions claimed by both mods and dismissable by neither. Detecting NFF switches you to Tracking mode once, and casual follow stands down only for followers something else actually owns, never for an ordinary townsperson.

Camps stopped forming where camps cannot be. A recruited bandit walking at your shoulder was registering your own house, a Dawnguard glade and an entire hold as outlaw camps - then getting elected chief of one and handing it over to you. Camp registration is now gated on the location's own type, and no designated boss means no chief: nobody is invented, so bandits can no longer name a dungeon's end boss as their leader. Taking over a camp with nobody in charge is a group decision - three of them have to agree separately, they know exactly who broke first, and what they think of that person colours what they do next.

Followers no longer trip bear traps or pressure plates, via vanilla's own LightFoot perk rather than by overriding any vanilla script. Friendly-fire protection is genuinely on by default now - the setting was read with two different defaults, so the part that keeps it anchored never ran.

Your stewards go and see the people they collect from. Twice a week or so, a hold's steward walks out to one of their retainers, spends a day or two about the place looking the work over, and goes home - so you occasionally run into them somewhere you did not expect, with a bodyguard in tow if you gave them one. Both of them know why they are standing there and will say so, the Holds pane tells you who is on the road and who they are with, and it turns up in that week's journal entry from either side. It is entirely flavour: your weekly takings settle on their own schedule regardless, so nothing you are owed ever waits on a journey finishing.

Masters of the Voice now teach what they actually know. An NPC that gets its shouts through a template - a custom follower built on a dragon or on Miraak, or Miraak's own serpentine dragon - used to shout perfectly well in combat while insisting they had nothing to teach, because we read their record instead of the one the game actually uses. Dragonborn and Dawnguard shouts translate properly now too, so a DLC dragon can teach Cyclone or Drain Vitality as the real player Shout - and Dawnguard's revered dragons no longer slip their own dialect version of Drain Vitality into your magic menu when they teach it.

The beef-stew bow swap is gone. The engine quietly hands every follower a hidden hunting bow, and we used to intercept that and leave a bowl of beef stew as the wink - but the interception could get into a tug-of-war with follower mods that enforce their own equipment, and at its worst that meant hundreds of swaps a second and a frozen game (thank you to the user who measured it). The joke was not worth anyone's save: followers keep whatever the engine gives them now, and any stew already in a pack is just lunch.

Brawls got a full overhaul. Sparring a follower no longer dismisses them mid-fight (with NFF, the release-and-rejoin now happens exactly the way NFF's own sparring does it, silently); an opponent who refuses to stay unarmed forfeits instead of being quietly excused; walking away actually ends the fight; and the loser stays down in bleedout and staggers back up as their strength returns instead of springing upright at full health. Your other followers now know a brawl when they see one and stop lunging at your sparring partner, and a spell some wardrobe mod slips back into anyone's hand mid-fight is taken away before it can end the match.

Your bio blocks became a proper library. The custom-bio system grew from its proof of concept into a full Bio Blocks page: write a snippet once - a routine, a quirk, a combat style - file it under your own tabs, and apply it to any companion or townsfolk from a picker (crosshair target included). Each card shows exactly who is carrying it, editing a block updates everyone who has it, and one click removes it from one character. The library travels with your install and can be shared as a file or by copy-paste - imports rename on collision, never overwrite - while WHO has WHAT applied now belongs to each save, so a fresh start begins clean instead of inheriting every block you ever placed. Blocks and applications you made before this update carry over on their own. The page itself got a visual pass to match the rest of the ledger - each of your tabs takes a colour that runs down the spine of its cards and marks its dot in the tab strip, the category prefix steps back so the trait name reads first, and the cards warm up with a leather ground and a lift on hover.

The Holds pane tells you where each retainer actually is. Instead of only their hold, every retainer now shows a live location - in Belethor's shop, in Dragonsreach, on the road to Whiterun, with you, at home - resolved the moment you open the page and kept honest: a place it can confirm reads plainly, while one it can only expect ("usually at the market") is marked as such rather than dressed up as fact. A retainer who works their own stall with no assigned work spot can be pinned to it by dropping one of your named markers there - the next time you pass them the marker becomes their usual place, shown even when they are a province away. And retainers no longer quietly go missing from the roster while you are elsewhere: everyone on your books is held resolvable in the background, so a hired guard built from a generic townsguard keeps their face and their place instead of dissolving back into the crowd.

You can keep a larger household. The retainer roster cap rises to 500 at the top of the renown ladder (from 200), and the behind-the-scenes pools that keep guards on post and everyone on their daily routine grew to match.

Sending someone across their own city works now. A guard told to walk to a marker inside Whiterun would set out, reach the spot, and then stand there forever - the arrival was being measured against the city gate by the stables, a good distance from where you actually sent them, so the trip never registered as finished. A journey that stays inside one city now aims at the real destination and completes on arrival; cross-country travel, which genuinely does end at the gate, is unchanged. Anyone already stuck from before sorts themselves out the next time you load.

Gear commands find the right item and the right person. Equipping or removing something by name now prefers the vanilla piece when two share a display name - the wrong Monk Robes bug, where the command reached for a mod's record instead of the one you meant - and the wardrobe selector and worn-item list show a source-plugin badge so you can tell duplicates apart at a glance. Outfit actions aimed at a specific follower now resolve that follower by their game identity rather than their name, so a command meant for one of two same-named companions can no longer land on the wrong one.

Loading a save no longer teleports your followers in front of you. Catch-up was firing on the load itself - jarring, and it ignored the off toggle because the load beat the setting to the punch. A real door or fast travel still gathers everyone exactly as before.

The General did not come to Skyrim alone. Twelve seconded soldiers of the Imperial Fiscal Levy are now visibly at work across five Empire-friendly holds - four in Whiterun where the General is quartered, and a pair each in Solitude, Markarth, Falkreath and Morthal. Each detail walks its city in daylight behind its own Decanus, settles somewhere about the streets for a couple of hours, then moves on. Ask any of them and they will tell you whose writ they are here on and that the General himself is up at Dragonsreach - not that they are standing there with him. The General, his two Legates and all twelve are ESSENTIAL for now: the Treasury's case against you is deliberately not finished yet, so nothing that happens to them can strand it. They take up their posts once your purse crosses the Treasury's threshold and the books keep counting from there.

Groundwork on the Imperial Final Audit, most of which you will not see yet because the encounter itself is still parked: when it is switched on, the Legate serves his writ the moment he reaches you instead of up to thirty seconds later, his battlemages walk home with him instead of standing in the road, they know to stay quiet unless spoken to, and paying works whichever collection action he reaches for. He also comes to you on foot now - genuinely setting out from Dragonsreach and walking the distance rather than appearing behind you, with his escort actually alongside him, and taking to the follow package only for the last stretch. If you are somewhere no road reaches, he still finds you the old way.

Outlaws holding a dungeon fight on sight again. Bandits squatting in a barrow or a crypt were standing down exactly like the ones in a camp, which made a delve into a walking tour - so **Include Dungeon Holdouts** (Settings, Outlaws) now ships off. Camps, forts, warlock lairs and the open road are untouched and stay negotiable, and a bandit camp still counts as a camp even though the game also files it as a dungeon, so nothing that swore to you can be broken by this. Turn it on if you would rather be able to talk to anyone anywhere; turning it back off releases whoever is already calmed within a few seconds.

A follower you told to wait stays where you put them. Something reading a wait as though a mod had cancelled it could release the order seconds after you gave it, and once released, two separate systems were free to drag that follower back to you. Cows and other livestock also stop being pulled into ambient conversations - they were being paired off and given opinions about banditry.

Stewards can be appointed in a hold that has ever paid tax. Those holds were showing an empty steward's seat that had never existed, with no way to appoint anyone - which quietly locked the whole feature once your ventures had paid a single septim.

Jail actually holds people with jobs now. An NPC you had jailed would clock in for their shift anyway - the work order and the jail order carried the same weight, so whichever was given last won, and the roster still listed them as locked up while they stood at their forge. Jailing someone now pulls them off the schedule on the spot, every schedule pass leaves prisoners alone until release, and anyone already mid-escape in an existing save gets marched back on the first pass. The job itself survives the sentence: they return to work once released.

Creditors bring up what you owe them. A debt going past its deadline used to produce nothing you could see; now, the first time you run into a creditor whose deadline you have blown, they will raise the matter themselves - once per creditor each session, not a nag loop. The reminder toggle in the MCM covers this too.

Paying one debt no longer risks wiping the rest. The forgive action - which cancels EVERY tab someone owes you at once - read enough like a payment acknowledgment that the AI sometimes reached for it after you settled a single debt, erasing the others as a side effect; its description now makes the distinction unmistakable. Partial payments also settle your oldest tab first instead of an arbitrary one.

The ledger's Clear button became Pay. Clear was quietly deleting every debt involving that person, in both directions, with nobody the wiser. Now each debt you owe has a Pay button that moves real gold - capped at what you carry, partial payments count - and the creditor actually hears about it, exactly as if you had paid them in conversation. Debts owed TO you get a Forgive button instead, and the debtor knows you let them off.

Serana stays where you told her to wait. If a Serana replacer removed her Dawnguard faction, SeverActions stopped recognizing her as DLC-managed - and with that one verdict wrong, every wait protection failed at once: our systems fought her own AI, read her AI's pushback as "a mod resumed her", tore down the wait, and dragged her along on the next fast travel. She is now recognized by WHO SHE IS - her record's identity, which no replacer can change - so every guard that respects DLC-managed followers holds again, waits included, and existing saves heal themselves on the first load. A second belt: a follower whose wait flag gets zeroed by another mod's scripts no longer gets force-re-followed after loading a save - our own record of the wait counts too. And our Wait/Follow buttons now speak to Serana in her own language: Dawnguard's follower brain actively cancels any wait it didn't order, so telling her to wait now goes through the same internal call her own dialogue uses - which also means a mid-story Serana who refuses to wait refuses honestly, exactly as the DLC intended. Works with Serana Dialogue Add-On too.

Your shopkeepers actually sell things now. Each hold has a trade depot you stock from a first-class Wares panel (drag goods in by item or by category); your merchants and fences sell REAL items out of it week to week, and once in a while a named local - someone with real coin from their own wages - walks in and buys the best piece they can afford, wears it if it's armor, and remembers it enough to mention. Your farmers, miners and alchemists now send their haul to their hold's depot instead of your pack, whenever that hold has a merchant to move it, so the whole thing feeds itself: producers stock, merchants sell, workers buy, wages fund the next purchase.

The Empire taxes like an empire. The flat hold tax that stopped mattering the moment your ventures got big is now a proper progressive schedule - a few percent on small takes, climbing toward half on a fortune - and it's marginal, so earning one more septim never costs you gold. Real payroll has two sides now: you're taxed on profit (wages come off first, as they should), and your workers are taxed on what they take home, both flowing to the hold's own court. And a profitable venture pays its own wages out of the week's earnings before reaching into your purse, so a thriving shop stops quietly draining your coin while its profit piles up uncollected. Coerced arrangements, camps, fences and holdless work stay off the books.

Periodic systems no longer freeze on a heavy load. The timers that drive followers, travel, arrests and survival were sharing one hidden slot and could all stall behind a single dropped signal; they now run on their own steady clock that survives a busy load, self-restarts if the first tick goes missing, and only warns you if it truly can't recover.

Every internal clock now actually keeps its own time. A sharp-eyed developer proved that all of SeverActions' periodic loops - follower upkeep, travel, arrests, brawl polling, survival, the Fertility Mode bridge and more - were unknowingly sharing a single engine timer, so whichever system set its alarm last won and everything else silently ran at that one cadence (a loop asking for 3 seconds was measured running at 32). Each system now gets a genuinely independent tick from a dedicated native timing service, so short-interval work - brawl prompts, travel pacing, arrest escorts - fires when it was actually asked to. Deepest-rooted bug fixed this cycle; enormous thanks to the developer who diagnosed it with three sessions of log evidence.

NPCs finally spend the gold they earn. Working folk were piling up wages with nothing to do but sit on them. Off-screen life events now know exactly what's in the character's purse: a wealthy companion will treat themselves to something they'd actually want - and the purchase is real, the gold leaves their inventory and the fine clothes or silver ring lands in their pack - or lose a heavy purse the old-fashioned ways: a bad night at cards, a pickpocket, a scheme that never paid off. Background workers join in too: each payday, some of the labor roster spends a slice of what they carry at the market, the tavern, or the shrine, and about a third of those come home with something to show for it. (Thanks to the user who pointed out everyone was getting rich with nowhere to put it.)

Loan requests show up on the Enterprises summary. A retainer asking to borrow now appears in the needs-attention feed right alongside raise asks, with the amount they want - previously you only found out by opening their card on the board. (Thanks to the user who asked.)

Crafters no longer get stuck in a cooking loop. Asking someone to cook or brew could trap them in a cycle of announcing the result, taking that announcement as a cue to make another, and announcing again - because both the hand-off and every failure demanded a spoken response. Outcomes now land quietly in the NPC's awareness instead: they will mention the finished dish or the missing cooking pot naturally, without being goaded into round two.

Intimacy runs on consent now, not a switch that is always on. Every NPC keeps a private stance on how open they are to you - unwilling, uncertain, receptive, willing, or withdrawn - and it is set from what has actually passed between you: your conversations, how you have treated them, what they remember. Relationship rank does not buy it (marriage is the one rank that counts, and it is read directly), and neither does how many times you have spoken. It moves both ways - someone who was warming to you pulls back after an insult, a threat, humiliation or an assault, and a withdrawal sticks until there is real evidence you have made it right. Your first conversation with anyone after updating reads their history at once, so established relationships start where they should; after that it re-checks only when enough has changed, so idle NPCs cost nothing. A master toggle and a gender filter (everyone / women only / men only) decide who it surfaces for, it obeys the Background-AI switch like every other generated line, and followers are included - romancing a companion is the whole point. NPCs also read your reputation and persona from the sexual-tab bio blocks you have applied, so a known courtesan or a feared warlord is met as what they are.

Arousal descriptions are quieter and gender-aware: below the high tiers they are one background line that states the constraint first, and no tier writes itself into an NPC's memories any more.

Very large households stop dragging on the script engine. Every thirty seconds SeverActions walked its whole list of homed NPCs over and over, asking each of them in turn whether it was their hour to change what they were doing — and on a big enough household that one pass outlived the thirty seconds it had. The two heaviest of those questions, the work-and-home routine and stepping out of a scene, are now asked once for everybody at once, and only the people whose answer actually changed are handled individually. Nothing about anyone's routine changed; ordinary households behave exactly as before, and only genuinely large ones spread the remaining work over a few of those thirty-second passes so nobody's schedule can stall the engine. Slow passes now also leave one line in the papyrus log saying which part was slow and how big the household was, so a report about stuttering can be answered instead of guessed at.

Travel got a map and real roads. World & Travel now opens on a hand-drawn map of Skyrim with your travelers drawn on it as live routes, hold sigils placed at their true map positions, and a journey to a city aimed at the gate where the road actually meets the walls. Underneath, overland travel follows Skyrim's road network instead of cutting a straight line across the terrain, and a traveler who can't get an alias slot retries for one rather than giving up. (A crash that could strike when the map opened mid-journey is fixed too.)

You can drop your own named places. Mark a spot anywhere - "the kitchen", "Whiterun Market", wherever you want someone to stand or go - give it a name, and travel to it by that name; a Markers tab under World & Travel lists them for renaming or clearing, and a journey into a building rotates through its rooms instead of piling everyone on one doorway.

Nearby characters take small deeds of their own. The new Ambient Action Orchestrator lets an idle NPC occasionally do something they plausibly would on their own, with a social check deciding whether it fits who is around to see it - background colour that does not wait on you to prompt it.

Casual follow survives a load door. Telling someone to tag along now seats them in the same alias-backed follow system your companions use, so they stop dropping the instant you cross a threshold; and the follow hotkey and wheel can turn someone OFF again - after that change a re-press kept telling you they had stopped following without ever having restarted.

Fertility Mode got quieter. The monthly cycle states now run in the background instead of narrating themselves; a pregnancy still tracks and reports its stage exactly as before.

Enterprises plumbing got tidier. A venture's premises are derived from where its work actually happens instead of being tracked as a separate thing that could drift out of sync, and a week's courier mail arrives as a single delivery rather than several.

Work letters are signed. The letters your enterprises courier to you now carry the sender's name at the foot instead of arriving anonymous.

Hiding a helmet stops shaving wig-haired followers. On a custom follower whose "hair" is really a headgear wig, Hide Helmet was stripping the wig along with the helmet - and could hang on the head rebuild that followed. It now touches only true helmet slots and leaves hair and circlets alone.

Retainer work-life stories stopped repeating themselves. The weekly vignettes had settled into the same few openings and turns of phrase; they now vary their subject and voice from week to week.

A broad pass over the mod's written text - prompts, courier letters, action descriptions - tightened wording throughout and fixed how your character's name is woven into generated lines.

You can lead a bound captive by the wrist. A restrained or kidnapped prisoner can now be told to follow you - or another NPC - on a short leash, hands still bound, the way an Imperial escort marches a prisoner through town. The follow and companion actions understand it, and their hands bind the instant the leash is set rather than half a minute later on the next upkeep pass. A new **Tie / Untie hotkey** binds whoever you are looking at and frees them again with a plain line of narration - and it works even when someone else did the tying, so when one NPC restrains another in conversation you are no longer left with no way to cut the prisoner loose.

Dropping your fists in a brawl forfeits the match - and gives your spells back. Sheathing mid-fight now reads as yielding: the bout ends cleanly, anything the brawl set aside is returned to you, and your opponent is told in as many words that you gave it up by lowering your hands. A brawl that begins with your weapons already away no longer counts that as an instant forfeit either - it only takes your sheathe as surrender once you have actually drawn.

Only your followers feel hunger, cold and exhaustion. Shopkeepers and other townsfolk had started fretting in their own thoughts about being worn out - survival needs were being described for NPCs who were never part of the system. It is companions-only again, the way it was meant to be.

VR's immersive behaviour has a switch now, and flat players can use it too. The immersion layer used to decide entirely on its own whether to engage; a three-way control (Auto / On / Off) on both the Settings page and the MCM lets you force it either way - a flat-screen player can turn the immersive touches on, a VR player can turn them off, and Auto keeps the old automatic behaviour.

The Board and Holds pages became one. The Enterprises board now lays your retainers out by hold with the same clean, clickable cards the Holds view used - each hold headed by its steward, each retainer showing where they are and what they do - and the now-redundant page is retired. From a retainer's card you can teleport straight to wherever they are standing.

The MCM got a proper reorganization. Its settings are re-sorted into thirteen clearly-themed pages - Interface, Followers, Off-Screen Life, Outfits, Survival, Combat & Outlaws, Crime & Bounty, Economy, Enterprises, Travel and the rest - with around fifty controls that previously lived only in the PrismaUI settings added so the two finally match. Every control with a twin in the in-game UI now writes through to the same place it does, so a choice you make in the MCM sticks across a reload instead of being quietly reverted on the next load.

Cosaves `'CAMP'` and `'VSTR'` both move to v6, and `'FLWD'` to v20. Existing saves load and migrate; **do not roll back to 3.9.2 after loading this**, as the older DLL cannot read the new camp record and would drop your steward vaults, hold court treasuries and Final Audit state.

---

## v3.9.2 - The camp asks your business

Hotfix for the 3.9.0 line, plus the truce's missing piece. Walking into a pacified camp's interior is no longer a free tour: someone comes over and asks what you are doing there, and the answer decides whether the truce holds. Chat spam from furniture and follow events is gone, letters remember who wrote them, and two crash classes from 3.9.0 field reports are fixed. Save-compatible.

### The challenge at the door

- **Wild camps question intruders.** Cross into a pacified camp's interior and the chief - or the nearest outlaw, if he is too deep in - walks over, steel drawn, and demands your business. Talk your way past and the truce holds for that visit; refuse, lie badly, walk off mid-question, or let the clock run out, and the whole camp turns - on BOTH sides of the door. Leaving the camp and coming back earns a fresh challenge; re-entering a cell mid-visit does not re-roll it.
- **The verdict belongs to the outlaw, not a menu.** The challenger decides in dialogue - let you pass, or run you off - and only the one actually asking can settle it. They know the decision is theirs, that stalling is an answer, and that those two calls are the only ways it ends.
- **Steel is a verdict too.** An outlaw who attacks you mid-challenge has answered for the whole camp - everyone turns at the moment of the swing, not after the fight.
- **The boss chest is not part of the tour.** Plundering a camp's treasure hoard turns the camp, challenge or no challenge - a truce means they hold their fire while you walk their ground, not that the war chest is free. Ordinary sacks and barrels stay fair game; sworn camps' goods are yours by arrangement. The betrayal is written into the record, so the crew knows exactly why they are fighting you - and can say so.
- **Breaks reach the whole camp now.** Striking or refusing one member of a registered camp turns every member by roster - a deep mine or an interior/exterior split no longer leaves half the camp calm while the other half dies.
- **Three new settings** under Outlaws: the challenge master switch, how long they will wait for an answer (30-300s, default 120), and an optional choice card (off by default - the intended feel is answering in conversation, and the card only ever states the question).

### Camps and Enterprises

- **A chief of their own ends the yoke.** A conquered camp's weekly morale drain now stops if you appoint a living chief from its own ranks - being met halfway has two currencies, gold or leadership - and an appeased camp recovers week by week instead of just holding steady. The chief dying, or the camp's own boss re-asserting, resumes the grind. Easing the cut to the fair line works exactly as before.
- **Lieutenants know what they are.** A named second now carries their own standing in conversation - the rank used to exist only in everyone else's context. Chiefs and campmates already knew; now the whole chain does.
- **Stewards for any hold.** A steward can be appointed over any hold you choose - including companions from nowhere in particular, who previously showed "Unknown" and could not take the books anywhere.
- **Job applicants are findable again.** The letter from someone seeking work now names them in the subject line, and the Enterprises dashboard shows who is asking and how many days you have to answer - previously the letter was the only copy of their name, and losing it stranded a real NPC until their window quietly expired.

### Quieter chat, better letters

- **Furniture and follow events stopped flooding the record.** Sitting, standing, waiting, following, and relaxing are scene state, not history - each companion now holds ONE short-lived line saying what they are doing right now, instead of appending a permanent entry per transition. Large followings no longer bury the event log in "got up (auto)". Genuine one-offs - a companion actually walking out, arrests, debts - stay permanent.
- **Letters keep their author.** A letter's sender is now captured when the courier is dispatched, so a retainer who is unloaded by the time the letter reaches you no longer arrives anonymous.
- **Letters no longer arrive pre-read.** The note pool recycles physical note forms, and the engine's "already read" flag lives on the form - one read letter used to mark every future letter on that slot as read. Cleared on every delivery.

### Fixes

- **Fixed a crash to desktop at the main menu, before any save is loaded.** SkyrimNet writes one character bio per NPC, named after that NPC. If your load order contains an NPC whose name uses a character your Windows language settings cannot represent, reading that filename raised an error - and because the NPC labor registry scans those bios on a background thread, that error killed the game outright, with no crash log and nothing useful in ours. Non-Latin NPC names are now read correctly instead of throwing, the same filename handling was swept across every path the DLL touches, and the background scan can no longer take the game down with it whatever it hits. Affected 3.9.0 only.
- **Fixed the live viewport crash-to-desktop.** The Ledger's 3D NPC/item viewport held a reference to the engine's render geometry but not its GPU buffers - RaceMenu-overlay rebuilds (skee64) could swap those buffers mid-draw and crash the game. The viewport now owns the buffers it draws. Reported by three users; disabling the viewport was the workaround.
- **Survival's per-NPC include/exclude no longer leaks between saves.** Excluding an NPC from survival needs was being written to the global preferences file instead of the save. Because that file holds one entry per setting name, it could only ever remember the last NPC you toggled - and it then re-applied that one NPC to every other save and every new game, failing silently on load. The toggle now lives purely in the save, where it always belonged; any stale entry already in your preferences file is cleaned out on the next launch. Nothing you had set is lost - the real state was always in the save.
- **All nine SeverActions LLM prompts could be reported missing when they were installed.** The same filename problem aborted the startup prompt scan partway through, silently disabling relationship assessment, follower and ambient banter, off-screen life, quest awareness summaries, retainer worklife vignettes and letter writing for the rest of that session. The scan now reads past a name it cannot convert instead of giving up.

### Catalog

- **The per-item undress-protection shield is back.** The armor band's rows regained the blacklist toggle the Catalog rebuild lost - click the shield to protect a specific piece from ever being stripped by outfit changes (the plugin-level blacklist in the Outfits manager never went away; this restores the only way to ADD a single item). Shielded rows show a lit gold shield; plugin-blacklisted items read shielded too.

### Display

- **Ultrawide letterboxing (21:9 / 32:9).** On displays wider than ~2.1:1 the Ledger now centers itself at a comfortable reading width instead of stretching the nav rail and inspect panel to opposite horizons - the game world stays dimly visible in the side gutters. A Display setting ("Ultrawide: Stretch Full Width") restores edge-to-edge for anyone who prefers it. No effect on 16:9 / 16:10.

## v3.9.0 - Outlaws, industry, and the Voice

The biggest release since Enterprises. Bandits stop attacking on sight - and once you can talk to them, you can deal with them: an outlaw camp can end up working for you, chief and all, managed from its own Enterprises tab, mustered as a war band at your back. Skyrim starts running its own payroll - Saadia works for Hulda whether you are involved or not - and your empire gains hold stewards who collect the take so you don't ride nine holds every week. The whole UI was redesigned ("The Ledger, Illuminated"), NPCs and items now render live in 3D inside it, the Greybeards teach Words of Power, travel keeps honest time, and every background AI call gained a master off-switch. Save-compatible.

### The Truce layer

- **On by default - actually.** The truce layer's master switch now ships enabled (a tester's fresh save caught it dark: the kinds were on but the layer itself defaulted off, so every bandit fought like vanilla). A one-time migration turns it on for existing saves; switching it off under Settings -> Outlaws sticks.
- **Outlaws hold their fire until provoked.** Bandits by default; necromancers, Forsworn and vampires are on by default too (vampires only while you are one yourself). They are not friendly and have not surrendered - it is a wary standoff, with tension that rises as you push in armed and close, and breaks the moment you or your followers swing. A one-time migration turns the extra kinds on for existing saves; turning any of them off in Settings sticks.
- **Runtime, not an ESP.** Nothing is overridden, so this composes with any load order and re-evaluates every sweep instead of baking a decision at install time.
- **Every mutation is recorded and reversible.** Aggression and faction membership both persist in a save, so a cosaved ledger restores everyone on load before the sweep re-pacifies. Turning the feature off restores the world rather than leaving it full of docile bandits.
- **Spawner mods are covered.** Fresh hostiles injected mid-session (OBIS-class spawners) used to get four unpacified seconds - enough to ignite a whole camp. New spawns are now caught the moment their 3D loads, with a retry window that survives loading-screen races.
- **Sworn crews forgive stray hits.** Once a camp works for you, a graze from your own follower, creeping tension, or contagion from a neighbour no longer flips the whole crew - only a real fight that costs someone a quarter of their health turns them. No more losing a camp to one wild swing.
- **Camp chiefs are negotiable.** Quest-alias outlaws hold their fire too - camp leaders are very often radiant quest targets, and excluding them meant the one NPC actually worth talking to was the one who charged you.
- **They no longer kill each other.** A pacified bandit reads as a NEUTRAL, and a still-hostile bandit is Very Aggressive - which attacks neutrals. Pacified bandits join vanilla's own `BanditFriendFaction`, so even a fully hostile one sees them as his own.

### Camps: takeover, leadership, muster

- **Two routes in.** Talk the chief round and the camp comes over as a **Partnership** (20% cut). Kill him and the survivors can throw in with you instead - **Vassalage** (40% cut), and everyone involved knows the difference. Talking is worth more renown than killing - and a fair fifth keeps the camp genuinely content, while the conqueror's two-fifths reads as the leash it is (ease it down to the agreed rate and you win them over).
- **A Camps tab on the Enterprises page.** Every sworn camp as a first-class holding: terms, leader status, the roster with escrow and last-week columns, collect and release right there.
- **Appoint chiefs and lieutenants.** Promote any member to lead a sworn camp; name lieutenants in succession order. When a leader dies, the first living lieutenant steps up - a sworn camp is never leaderless while a line exists.
- **Muster the camp as a war band.** The whole crew arms up and marches with you - far-flung members walk in on honest travel-time ETAs instead of teleporting, stragglers rally when you next come near, and members you meet along the way fall in on sight. Send them home and they file back to camp. Bystanders notice: other NPCs see the armed company at your back and say so.
- **Sworn members are permanent.** Swearing a camp promotes its people to persistent references - the engine can no longer regenerate them into different NPCs when the cell resets (the Imperial-turned-Argonian class of bug is gone), and the camp stops respawning fresh hostiles (encounter zone frozen on takeover, restored exactly on release).
- **Agreed camps stay agreeable.** A camp whose chief chose the arrangement no longer grinds unhappy like a conquered one: at a fair cut (40% or less) they work like consensual partners. Squeeze them past that and they sour - ease a conquered camp down to fair terms and you genuinely win them over. The cut IS the coercion measure.
- **Newcomers inherit the deal.** Fresh arrivals at a sworn camp join under the camp's standing terms automatically, the roster label can be renamed in bulk ("Mercenaries" to whatever you call your crew), and the Board honors the rename.
- **Oaths are breakable - in both directions.** A sworn chief can renounce the oath in dialogue (RenounceCampOath), and a chief who simply attacks you IS renouncing - the whole cascade (books close, camp released, truce broken) follows either way.
- **Attrition.** Camp members who die come off the books automatically, and a camp with nobody left closes itself out and releases the location.
- **The leader is the game's own.** Camp leadership reads Skyrim's `Boss` location-ref marker rather than a heuristic we invented, with strongest-present as a visible fallback.

### NPC Labor - Skyrim works for itself

Saadia works for Hulda. She always did, lorewise - but until now the game had no idea. SeverActions ships a curated registry of who works for whom across Skyrim, then runs the payroll: every in-game week, employers pay their workers real gold and keep the takings, with no player involvement anywhere.

- **A stable, curated list - nothing re-derived at runtime.** The registry ships as data (251 assignments, 141 of them base-game and DLC NPCs: nine start-of-game jarl courts with stewards, housecarls, court wizards and servants, famous shop and inn staff, and a reviewed vanilla draft; the rest name NPCs from mods and are skipped when those mods are absent). Every user with the same NPCs sees the same list. Optional bio-heuristics can seed mod-added NPCs, off by default.
- **Real weekly wages between NPCs.** One global payday: workers are paid real, carried gold (lift it off them if you're feeling criminal), employers keep the week's margin. Carried-gold caps and a tunable wage-ladder percentage keep the money supply sane. The MCM's Force Weekly Settle debug covers the NPC payday too.
- **Organized by hold, jarl's court first.** The Labor pane groups every employer under their hold's banner with the jarl's court leading, in the Board's quiet-row style: click a worker to open the editor modal - give them a custom title ("head barmaid"), move them to a new employer, set their wage, or fire them. Pickers list nearby NPCs so adding real people is two clicks. Titles you grant are spoken in dialogue.
- **Known in dialogue.** Workers know who they work for, as what, and for how much; employers know their own workforce. Your retainers stay on the retainer surface and never appear on the NPC side - hiring someone pauses their NPC wage, dismissing them resumes it.

### Hold stewards

- **One collector per hold.** Appoint a steward for each hold (from the new Holds pane or in dialogue) and your retainers' weekly earnings in that hold sweep into the steward's vault after every settle - visit one person instead of nine camps and twelve shopfronts.
- **Stewards take 25% off the top.** Real pay for real work: the cut becomes carried gold on the steward, the rest waits in the vault. Their ledger blurb tells you what's waiting - and now steers the LLM to the right action (a steward asked to hand the vault over reaches for CollectFromSteward, not CollectPayment, which would charge YOU).
- **Vacant seats keep their vault.** A steward whose venture ends auto-vacates; the vault survives for their successor. Dismissing one pays out the remainder on the spot.

### Enterprises

- **Retainers know their own money.** A retainer's dialogue now carries their loan state (a pending ask with its amount, the outstanding balance and weekly garnish, weeks behind, defaulted, or repaid in full) and when you last actually improved their pay - no more nagging days after getting the raise.
- **The loan loop closes in dialogue.** Grant, refuse, or forgive a loan in conversation, not just from board buttons. Loan letters are LLM-written now and name a concrete purpose ("my daughter's apprenticeship fee"), not a form letter.
- **Loans got discipline.** Camp members never ask (the camp IS their living); Sworn and Enslaved retainers never ask (they sit outside the economy - a kept guard on a stipend has no business begging for credit); retainers in the black don't beg; at most one ask per weekly settle. And loss weeks are real now - odds roughly one in ten, scaled losses, and a loss week jumps the story queue so the vignette explains the week the loan request arrives from.
- **Weekly stories stopped sounding samey.** Twelve rotating opening moods per retainer per week, and raw-haul jobs (miner, farmer, lumberjack) still bring goods home every week - for everyone else goods are a ~5%-of-settles event, because gold is the routine and a physical haul should feel like one.
- **Retainers know each other.** Crewmates at the same site appear in each other's weekly stories and shared memories; a bodyguard knows their charge's work, and the charge knows who shadows them - company on fair terms, a watcher on coerced ones.
- **Renown has a real surface.** The five-rung ladder shows on Summary with progress, per-tier roster caps and perks. The roster cap defaults on again - existing over-cap rosters are grandfathered to the tier that holds them, so nobody loads into a locked empire.
- **Fence jurisdiction follows the workplace.** A fence running your Whiterun operation accrues bounty with - and is jailed by - Whiterun, not their birth hold. Boards group by where the work happens, too.
- **The two life-sims stopped double-charging.** A retainer can no longer be robbed by the settlement AND the off-screen-life system in the same week, or arrested by both pipelines carrying two bounties.

### Trade and gold

- **Buy/Sell confirmation popups.** Whenever YOU are a party to BuyItem/SellItem, a non-pausing popup shows exactly what changes hands - item, count, gold, direction - with Accept / Refuse / Refuse silently. Letting it time out refuses: nothing moves your gold or goods without a click.
- **Conjured gold defaults OFF** - with retainers, camps, stewards and the NPC economy all minting real coin, the money printer is no longer the default (existing saves keep your stored choice).
- **When it's on, NPC buyers pay properly.** An NPC short on coin pays every real septim they have first and only the shortfall is minted - conjured gold backs the sale instead of replacing the NPC's own money.

### Shout teaching - the Way of the Voice

- **Masters of the Voice teach Words of Power.** Ask Arngeir (or any NPC whose record genuinely carries Shouts - Greybeards, Paarthurnax, dragons, mod-added masters) to teach a Shout: one word per lesson, always the next word you don't know, wall-learned words counted. Three lessons master a Shout.
- **A master's gift is complete.** The word arrives WITH its understanding - no dragon soul spent, exactly how the Greybeards handed you Whirlwind Sprint on the courtyard steps.
- **Gated by the game's own data.** The new can_teach_shouts decorator lists the Shouts on the NPC's base record, so a random bandit never offers Fus Ro Dah. (The Greybeards' records carry nameless combat variants; teaching translates them to the true player Shouts, so what lands in your magic menu is always the real thing.)

### The Ledger, Illuminated - the UI redesign

- **A new design language across all 19 pages.** The 12-tab top bar became a left navigation rail with sub-pages; brass hairlines, higher ink contrast, serif stacks; the Dashboard is a chronicle spread, the Inventory a real ledger with hand-inked category glyphs, the Board a muster roll with a right-hand dossier.
- **The Actions page is a verb book.** The 69-button wall became glyph-headed category cards, hand-packed to fit with no scrolling at 1080p and up - and 15 missing verbs were added, including a whole Employment category.
- **The menu hotkey is native now.** The config key used to queue behind Papyrus load-recovery for 30-60 seconds after loading a save; it's handled in C++ and works the instant the game accepts input.
- **Hotkeys are editable in PrismaUI** (Settings), synced both ways with the MCM.
- **Assigned NPCs got a register.** Dozens of assigned NPCs open in a filterable grid modal instead of an inline scroll marathon.
- **Density fixes for high-res displays.** Life Tracker no longer crushes tiles to hairlines at 4K or walls you with 37 entries; read letters collapse to a preview line. The Survival page fills its space, and followers' worded need stages ("Famished / Freezing / Sleep Deprived") actually render - they were dead code before.
- **Outfits roster, findable.** One height cap instead of two stacked ones, nearest-first Nearby sorting, auto-focused filter with arrow-key walking, crosshair target pinned on top - about 12 visible entries where there were 5.

### Portraits and items render live

- **The Inspect panel renders the actual item.** Every inventory item gets a real 3D render - a drag-rotatable orbit with proper materials, gloss, and two-light shadows. PGPatcher/ParallaxGen-mangled meshes (duplicate child refs) are sanitized and rescued instead of showing a glyph.
- **The wardrobe mirror is live.** The Outfits mannequin is a free trackball view by default - drag to turn, wheel to zoom, and it updates itself when gear changes (staging an outfit, presets, Hide Helmet). The baked orbit survives as automatic fallback for older setups.
- **Faces are right.** Scars and war paint render, dark-scalp hair is fixed, distortion effects no longer paint as blue discs, head and body tones match, and the studio look is location-independent - a dark cave no longer crushes the skin shading.
- **Uniforms from scratch.** Save any cart as a named uniform without needing an existing preset; the presets modal renders correctly at every width.

### Followers

- **Coward combat style.** A follower can be told to stay out of fights entirely - they disengage and keep their distance instead of charging in with a soup ladle.
- **Survival debuffs can reach zero.** The hunger/fatigue/cold penalty sliders now go all the way to 0% for players who want the narration without the numbers.
- **Multi-floor sandboxing.** Followers sandbox across floors now (the classic "Multiple Floors Sandboxing" tweak, done at runtime, widen-only, toggleable) - upstairs beds and chairs are finally inside the search volume, for our packages AND vanilla sandboxing.
- **Homed NPCs sleep at night.** An NPC you've assigned a home no longer sandboxes around the house 24/7: during the sleep window (default 22:00-06:00, configurable, midnight wrap supported) they lie down in the bed that was auto-claimed for them at home assignment and actually sleep. Work and relax schedules win over the window - a night-shift worker keeps working - and they wake when recruited, disturbed, or when morning comes. Toggle + window sliders in Settings.
- **Casual followers stop getting stuck at load doors.** Two root causes fixed: a leftover "waiting" faction rank that survived removal and read as waiting-forever at every door, and re-registered follow packages that the engine stopped serving after reload.
- **Bio template library, for anyone nearby.** Save any custom bio block as a template and apply it to other NPCs (copy-on-apply, no linkage); the bio editor now works on ANY nearby humanoid, not just companions; Enter inserts real newlines.

### Travel

- **Honest ETAs.** Cross-map trips take the time they should - no more "completed" journeys seventeen minutes after leaving Solitude. Distance is measured without needing both ends loaded, and off-screen travelers are never teleport-"recovered" mid-route; a still-walking traveler finishes naturally.
- **Meet them on the road.** Ride toward a mid-route traveler and they materialize walking the road where they should be, not standing at the destination early.
- **Stray travel packages are visible and strippable.** NPCs left running a travel package by an old save or crash show under Travel with a Remove button.

### Background AI controls

- **One master switch for every background LLM call.** Settings gains an AI section: relationship/reputation assessments, banter, quest summaries, off-screen life, weekly stories, courier letters - individually toggleable, and one master toggle silences them all at once (SkyrimNet's own dialogue untouched). Letters fall back to templates when off.
- **Nearby items consolidated in prompts.** Six carrots on the ground read as "Carrot x6" with one FormID instead of six lines, and furniture stays out of the item list.

### Settings

- **Enterprises and Outlaws got their own tabs.** Retainer controls live under Enterprises; the Truce/camp options under Outlaws → Truce & Camps. Retainer loan requests can be turned off separately from raise requests.
- **Free look is a free camera.** Entering free look releases the keyboard properly (no more dead SKSE hotkeys) and toggles the engine's own free camera; your own TFC state is never clobbered.

### Outfits

- **The outfit lock is now OFF by default.** It is a veto mechanism - presets do the same job declaratively, with nothing to race. The reported symptoms (partial armour after sleeping, auto-switch failing, an NPC turning up naked) were all the lock capturing a mid-undress state and then enforcing it. Still switchable for anyone relying on ad-hoc locks.
- **Fixed the Wardrobe leaving staged gear in NPC inventories permanently.** Discarding a preview now reclaims everything it added; committing keeps only what they wear. Presets saved mid-preview no longer classify staged copies as owned (the "preset strips them naked" bug), and old broken presets self-heal on next apply.
- **Fixed headless mannequins** on templated NPCs with custom skins, and the bake's frame-to-frame jitter.

### Fixes

- **Fixed pacified outlaws staying hostile after anything registered as an assault.** Skyrim files "the player attacked me" in a separate faction that survives everything else - the truce now truly erases it (the first fix layered a hidden rank instead of removing it; that's gone too).
- **Fixed outlaws turning on you at forts for no reason.** Detection-probe marker spells (zero-damage "fake hits" some mods fire from the player) no longer count as assaults.
- Fixed the couriers who stood frozen like statues until despawn - the orphan-cleanup sweep was stripping their loiter anchor seconds after arrival.
- Fixed spell teaching handing out one-handed variants instead of the spells a tome would actually teach.
- Fixed the Dismiss All button removing companions from the page without dismissing them.
- Fixed `<gone>` appearing on the Enterprises board where a name should be.
- Cell catchup now requires live follow evidence before teleporting anyone - stale roster entries stay put.
- NPCs briefly flagged as teammates by other mods are no longer silently adopted as companions (recruitment must hold ~5 seconds) - this was how strangers ended up teleporting to you at load doors.
- The book-reading rule no longer sits in every NPC's context - it appears only while actually reading, and as a brief warm-up right where the ReadBook action gets chosen.
- The jarl-recognition check used the wrong faction (it passed Legion members and failed actual jarls); property-sale gating reads the real JobJarlFaction now.
- The vampire-truce toggle no longer reads Off for non-vampires and "refuses to stick" - the Settings page was displaying the vampire-gated effective state instead of your stored choice. The toggle now shows what you set (default On); being a vampire gates only the in-game behavior.
- The survival master toggle is a true master now: with it off, an individually-included follower no longer shows up Famished/Freezing on the Survival page or the dashboard banner (those read stored needs raw, bypassing the off-switch that dialogue already honored). Off = everyone reads sated everywhere; stored needs are preserved and resume on re-enable.
- Creatures and animals can be action targets from the Actions page (user report): the nearby rail was hard-filtered to humanoids, so a dragon, horse, dog, or summon could never be picked. Wildlife now lists after the people (so the rail doesn't drown in pigeons), and duplicate-named creatures no longer collapse into one row - two wolves are two rows.
- Owned-item pickup by followers no longer raises a vanilla player bounty; thefts route through SeverActions' own witnessed, value-scaled bounty instead.

## v3.8.0 - Fullscreen UI, per-retainer schedules, the alias overhaul

A huge release. PrismaUI goes properly fullscreen with automatic per-resolution density. Retainers get individual work schedules - including 24-hour bodyguard duty, which now works for **every job, attending any NPC**. And the three most package-fragile systems in the mod (following, guard duty, captivity) all move onto quest-alias pools whose packages re-apply themselves on every cell load. Save-compatible.

### PrismaUI

- **True fullscreen menu.** The config menu was a fixed 1440x920 box with a static 1.5x transform that overflowed and cropped on common resolutions. It now fills the game window at any resolution, and the UI Scale slider became a density control (0.8-2.0) instead of a crop dial.
- **Auto-proportional density.** The default density computes from your screen height (about 135% at 1440p, ~100% at 1080p, 200% at 4K) and tracks the viewport until you move the slider yourself. A one-shot migration resets everyone to the new default on first load; your own choice is remembered from then on.
- **All-pages layout pass, twice.** Vertical flex-fills on the pages that top-aligned into a void (Dashboard, Life Tracker, Outfits, Inventory, Enterprises Summary, Companions detail), max-width and multi-column layouts where content huddled in a corner (Dashboard, Settings, Actions, Catalog), the World map scales to the screen, and the letter tiles in Life Tracker render clean 3-line previews instead of being sliced mid-glyph.
- **Outfits roster rebuild.** The Companions/Managed/Nearby tabs are now one grouped roster with collapsible sections, an always-on cross-group name filter, most-recently-used NPCs floating to the top, and per-group selection memory. Finding someone is type-two-letters-and-click.
- **Money colors were silently dead.** The ledger's green/red income/expense tokens were circular CSS self-references, so every money figure on the ledger side fell back to plain text. Fixed - the whole money language lights up.

### Enterprises

- **Per-retainer work hours.** Every retainer can override the global 8-17 schedule from their board card: custom windows, night shifts (22-6 wraps correctly), or 24 hours - the bodyguard-forever case. Work always wins over Relax on overlap.
- **Guard duty for everyone, on anyone.** Any retainer can now be assigned to a *person* instead of a place, whatever their job - a Mercenary guarding a friend, an Alchemist attending their patron. Ally rank means they still come to their charge's aid in a fight. The assignment resolves by name when a FormID has gone stale after a load-order change.
- **Board v2.** Summary is a proper cockpit (hero + KPIs + a wide needs-attention feed); the generic cashbook moved to its own Cashbook tab; Bounty and Debts merged into Obligations with hold-tinted tabs; Stories is a two-pane journal with a work-log view; the board sorts by attention/payout/name, caps long sections, and groups by trade *or by hold*.
- **Renown roster cap now defaults OFF** so existing large rosters aren't gated (one-time migration turns it off for you; re-enable in Settings if you want it).
- Assigning a Guard with no charge picked warns instead of silently keeping the old routine.

### The alias overhaul (followers, guards, captives)

- **Every follower rides a quest-alias follow package.** The old system had 21 alias slots plus a package-override overflow whose packages dropped on 3D unload and were only re-applied on sleep or save/load - overflow followers could silently stop following mid-session. A new 200-alias follow quest holds them all; packages re-apply natively on every cell load.
- **Guards follow the same way.** Guard duty used to ride the same fragile override; a 50-alias guard quest now holds it.
- **Captives too.** The captive hold (kneel) is alias-driven via a 16-alias quest instead of a priority-95 override plus a heal tick - the override stays as a backstop only.
- **"Move here" for captives.** From the Arrests view, order the kidnapper to re-take a held captive and bind them at your feet - useful when "send them to my home" put them in the wrong room.

### Fixes

- **The 511 native-function cap.** SeverActionsNativeExt silently crossed Papyrus's hard 511-native-functions-per-script limit (512), and the failure mode was ugly: native lookups on the script failed at runtime - including the is-follower check - so companions were treated as strangers and left on load. All 40 Venture natives moved to a new SeverActionsNativeExt2 script (Ext 472 / Ext2 40 / main 469), and `check_release.ps1` now fails the build if any bindings script goes near the cap again.
- **Dismissed followers kept following.** The dismiss cleanup wiped the follow/guard alias indices *before* the release paths read them, so the pool alias stayed filled and the NPC shadowed you until the next load. Indices are preserved now, and the release paths fall back to a pool scan regardless.
- **Pool packages were inert at first** - alias packages only run for aliases of their owner quest, and the generated pools attached main-quest packages. Each pool now carries its own quest-scoped clones (byte-verified).
- **Kidnap escape cadence** - was 25% per 30-second tick once past 12 unguarded hours (near-certain escape in minutes); now 5% per 6 unguarded game hours.

## v3.7.3 - Custom-AI followers no longer stuck on home/play packages

### Fixes

- **A custom-AI follower could get stuck on their relax/home package mid-follow.** The schedule system decided "is this follower dismissed?" using the vanilla teammate flag alone - but track-only / custom-AI followers (Kaidan-style mods, NFF-managed, anything whose own framework owns the teammate flag) never carry it, so an actively-following companion was misread as dismissed and dragged to their play or home spot. The follow drift-monitor then re-asserted the follow link every few seconds, the two fought, and the engine dropped to a runtime fallback package - and no amount of Clear Packages stuck, because the next schedule tick re-applied the sandbox. Both the home/play and work swaps now judge "dismissed" by actual roster registration, not the teammate flag. Already-stuck followers strip the stale sandbox automatically on the next tick - no save edit or manual clearing needed.

## v3.7.2 - Pay off NPC bounties, brawl spell-recovery

A point release adding the ability to **pay off a wanted NPC's bounty** - both from the UI and by asking a guard in conversation - plus a safety net that returns spells stripped by a brawl that ended the wrong way.

### New

- **Pay off a fence's or follower's bounty.** Any wanted NPC's bounty can now be settled from your own purse: a **Pay** button right on the fence's Enterprises card (for their illicit heat, before they're ever jailed) and on the Ledger's "Wanted - your people" rows. A fence caught in the weekly arrest roll still uses the existing Bail button.
- **Ask a guard to clear a bounty in dialogue.** Tell a guard, jarl, steward, or housecarl you'll pay off a specific person's bounty and they settle it with the law by name - covering both follower/NPC tracked bounties and Enterprises fence heat. The wanted person need not be present; the guard keys off their own hold's wanted list. A non-pausing confirm popup (matching the CollectPayment / arrest prompts) shows before any coin changes hands.

### Fixes

- **Brawl spell-recovery.** Ending a brawl with the surrender/yield hotkey (instead of the ForfeitBrawl action) used to leave your stripped spells gone for good. Spells stripped for a brawl are now recorded and automatically restored on the next load if no brawl is active - which also rescues a brawl interrupted by a crash or force-quit. (Spells lost before this build can't be recovered - there was no record of them - but no new losses.)
- The guard bounty prompt no longer routes bounty payments to the generic CollectPayment action, and a template syntax error in it (an unsupported inline conditional) is fixed.

## v3.7.1 - Custom bios, LLM trespass & the travel overhaul

NPC bios are now yours to extend: mint **custom bio sections per companion** from the Companions page - name them anything, write the content, and they blend into the character's bio and reach the LLM on their very next line, with no game restart. Breaking and entering gains an LLM brain: instead of the vanilla threat-stalking loop, **occupants learn you broke in and confront you in dialogue** - talk your way out, get thrown out, or face the guards, with sneaking preserved until they actually see you. Travel got a top-to-bottom overhaul: NPCs know whether they're **meeting you or off on their own business**, conversational and duplicate place names resolve correctly, "outside" and "beside the barrow" work, and companions who travelled beside you no longer greet you as if they'd been waiting. Plus compatibility fixes for **Simple Follower Framework** and **Swiftly Order Squad**, a diagnostic toggle for a 3.5.0 startup-crash interaction, and the engine's unkillable follower bow is now a bowl of beef stew. Save-compatible.

### Custom bio blocks (new)

- **Write your own bio sections.** Companions -> Bio -> **+ Add Block**: name it anything (Routines, Kinks, Combat Style, Religion...), write the content in a modal, and it renders inline in the character's bio in the same style. It reaches the LLM the next time that NPC's dialogue is generated - no game restart needed, ever.
- **Per-companion, no carryover.** Every companion owns their own independent set of blocks (up to 50 each); creating a block on one never shows an empty copy on the others. Built on a pre-shipped slot pool so both new blocks and edits are live at the next render. (Community suggestion by Goncalo - thank you.)

### LLM-driven trespass (new)

- **No more scripted threat-stalking.** Breaking into a home no longer summons the hardcoded vanilla loop of NPCs trailing you with scripted threats. Occupants instead learn you're not supposed to be there and confront you in dialogue - talk your way out, get thrown out, or bring the guards. A Settings toggle restores vanilla behaviour.
- **Sneaking preserved; noise wakes them.** Nothing fires until an occupant actually gets line of sight, so stealth still works. But move loudly - jogging around un-crouched - and sleepers wake, get out of bed, and come investigate, staying up (a follow-package hold) rather than climbing straight back into bed.

### Travel, overhauled

- **Wait for you, or go about their business.** A new parameter lets an NPC know whether they're travelling somewhere to meet/wait for you (greet-on-arrival, patience timeout) or simply running their own errand (arrive, do their thing, drift back to their routine) - no more everyone acting like they've been waiting for you.
- **It understands how people actually talk.** Conversational phrasings ("back to the College"), trailing qualifiers ("The Bannered Mare, Whiterun"), and duplicate names all resolve now - "Hall of the Dead" picks the hall for the hold you're standing in, or say "Hall of the Dead, Solitude" to override. An unresolvable place makes the NPC say so and ask for the proper name instead of announcing a trip and standing still.
- **"Outside" and "beside the barrow" work.** "Go outside" walks them out the door to loiter at the entrance instead of stopping at the inside of it; "meet me outside the Bannered Mare" or "beside Bleak Falls Barrow" sends them to a place's entrance without walking in.
- **Travelled together? They know.** Escort a companion the whole way and they arrive at your side - no "I've been waiting for you!" from someone who walked beside you. Arrive within a minute of them and they greet you as catching up. The canned "glad to see you!" popup is gone; arrivals are narrated in-world.
- **Vanilla "Wait here" / "Follow me" works on SA followers.** The vanilla dialogue verbs route through SeverActions' own wait/follow, so companions actually stop and resume when told through the normal dialogue tree.
- **Popup, your way.** A new setting shows the destination-confirm popup only for your own followers - a random NPC the AI sends somewhere just goes. The Actions-page Travel button also works again (it was dead and popup-less).

### Fixes & compatibility

- **Simple Follower Framework.** Recruiting a civilian through SeverActions and dismissing them no longer leaves them with an unremovable vanilla follow package (SFF parks extra followers in aliases SA couldn't see). Dismiss now clears the actor from every DialogueFollower alias - which also self-heals followers already stuck from before the fix.
- **Swiftly Order Squad.** Followers waited or resumed through SOS no longer walk off or become un-recruitable; SA adopts external wait/resume commands cleanly.
- **The follower bow is beef stew now.** The engine force-inserts a hidden hunting bow and arrows into every recruit, and deleting it just respawns it (engine behaviour, not ours). SeverActions now intercepts the insertion and swaps the bow for a bowl of beef stew.
- **Auto-Eat threshold 0 actually disables auto-eat.** The tooltip always promised it, but 0 previously meant eat at every opportunity - the exact opposite. It now stands the system down (shared party rations included); hunger still accrues and manual feeding still works.
- **Stale work assignments no longer bleed across saves.** Loading an old save where an NPC was a retainer with a work spot, then returning to your current save, no longer sends them commuting to a job they no longer have; self-healing on the next schedule tick.
- **Follower audit, round two.** A stack of roster fixes: waiting followers surviving load races, Serana recruitment routing, healer re-application, work/home schedule edge cases, and orphan-cleanup no longer flooding duplicate events on script-heavy load orders.
- **Casual-follow catch-up is now opt-in.** NPCs on a casual "follow me" (not recruited as companions) sit out the load-door catch-up teleport sweep by default; a Settings toggle re-enables it. Registered companions are unaffected. This also isolates a reported 3.5.0 startup-crash interaction - if you crashed on load, this build is the test.
- **Fences with bounties** now appear on their hold's wanted list and jail roster like any other offender.

## v3.5.0 — Abduction & restraint, morale with teeth, no more caps & the great stability pass

The biggest release since Enterprises. Two new dark-side systems — **abduction** and **ordered restraint** — let your companions seize, hold, ransom, and interrogate NPCs, with real crime consequences when it goes loud. Enterprises retainers gain **Temper**, a fast-moving morale axis where neglect alone can spiral into pilfering, ultimatums, and desertion. The old capacity ceilings are gone: **100+ followers, unlimited homes and relax spots**. Companions looting for you finally have eyes (search first, take specifically), letters now read like real vanilla letters, couriers only approach outdoors, and full **controller support** lands across every popup and menu. Underneath it all: a full-codebase audit fixed two critical and twenty high-severity defects. Save-compatible — every cosave store migrates in place.

### Abduction & restraint (new)

- **Order a kidnapping.** Send a companion to quietly abduct an NPC and bring them to a destination — a two-leg operation (walk up, seize, march them off) that keeps working even when it happens entirely off-screen. The victim ends up held bound at the destination while your companion stands guard.
- **Restrain someone on the spot.** The lighter, in-the-open variant: a companion walks over, ties the target's hands, and stands watch — no crime, no destination, done in front of everyone. Restrained captives stand bound; marched captives walk with bound hands (the arrest-march look).
- **Move, ransom, untie, interrogate, release.** Relocate a captive to a new hold, press them for what they know — interrogation cracks their resolve so their own knowledge becomes fair game in conversation — loosen their bonds for gentler holding (an untied captive keeps to the hold, watched, but escapes far more easily), or let them go and live with what they remember.
- **Ransom is a real negotiation.** Name your own price or let the kidnapper ask a fair one — the hold weighs who the captive IS (courtiers and merchants get paid for; nobody passes the hat for the town drunk) and how greedy the demand is. The answer arrives as a courier-delivered letter on fine court stock, written and SIGNED by the hold's actual steward — who remembers the decision. A refusal sends hired steel after the captive instead; survive that and the court either swallows its pride and reopens negotiation (at better odds — force already failed them) or cuts its losses and washes its hands of the matter for good. Pay honored with a prompt release settles the crime: no report, no bounty.
- **NPCs carry their own bounties.** A follower's witnessed crimes — theft on your orders, a kidnapping gone loud — land on THEIR head, not yours: per-offender tracked bounties on the Ledger and Enterprises pages, guards who know their hold's wanted list, offenders who know their own price, and Jarls, stewards, and housecarls who can speak about exactly who sits in their cells. Jailing an offender answers the crime and clears the bounty; the ledger keeps the history. Or settle it with coin: every wanted-NPC row has a **Pay** button that squares their debt from your purse — and they remember who paid it.
- **Consequences that stick.** A witnessed grab draws a real kidnapping bounty in the victim's home hold; word spreads as gossip; search parties can come looking; a released victim carries the grudge as a memory. Death in captivity is treated as the murder it is.
- **Captives are people, not props.** A held NPC knows they're bound, narrates from inside the hood or facing the room (restraint holds leave them bare-headed and watching), can attempt escape, and can't cheekily use captive-management actions to free themselves.
- **It plays nice with everything else.** Jailed prisoners, active arrests, your own followers, and children are all off-limits as targets; the arrest system and the kidnap system share apparatus without stepping on each other; captive retainers stop earning while held.

### Enterprises — Temper (morale that bites)

- **Morale is now its own fast axis, separate from loyalty.** Loyalty stays the slow trust anchor; Temper swings weekly with events — paid in full, missed wages, setbacks, raises granted or refused — and decays toward loyalty, so sustained good or bad treatment slowly drags the anchor itself.
- **Every consequence is reachable through plain neglect.** An unhappy retainer gripes and may send a courier complaint. A resentful one pilfers — even wage workers skim now — and a bitter fence draws extra heat. Push further and you get a formal **notice**: a one-settle ultimatum before they walk with the full desertion teardown (exit theft, gossip, and possibly a grudge).
- **Talk them down — or cow them.** A grieving retainer can be **reassured** in person; for coerced arrangements it reads as intimidation, which works differently than comfort. **Send word** to summon a retainer to a hearing, hash the grievance out face-to-face, and resolve it — grant, negotiate, or refuse and accept the fallout. Tribute retainers can turn openly **defiant** and withhold your cut.
- **You'll know about it.** Complaint and notice letters arrive by courier (paced — a heavy settle week arrives as a stream of couriers, not a convoy), the Enterprises board surfaces troubled retainers, and a hearing alert shows when someone is waiting on you.

### Followers — loot with eyes, uncapped rosters

- **Search first, take specifically.** New search actions let a companion rummage a container or corpse *without* taking — the contents surface in conversation (named items by value, gold, the sundry tail) and the NPC then takes what they actually want, in character.
- **Loot vocabulary.** "Grab the potions and any jewelry" now works: weapons, armor, jewelry, potions, food, ingredients, books, soul gems, ammo, scrolls, and gems are all understood as categories, alone or in lists, with plural-tolerant name matching.
- **Locked doesn't mean no.** A locked container gets a real lockpicking attempt scaled by their skill against the lock — and they kneel and work the picks while they're at it (the same idle Mercer uses at Snow Veil Sanctum). Success opens it for good, failure narrates and they can try again. Key-only locks stay shut.
- **They notice good spoils.** Companions spot notable loot they're carrying and bring it up on their own.
- **Owned-item theft is handled properly** — silent transfer plus a SeverActions tracked bounty only when actually witnessed, instead of the engine's instant player bounty.
- **Per-follower follow distance.** A close-follow variant per companion, switchable on the fly.
- **The caps are gone.** Followers past the old 21-slot ceiling (100+ supported), and home / relax assignments are now unlimited — rebuilt on runtime anchors instead of finite quest aliases, with legacy assignments migrating lazily and safely.

### One coherent off-screen life

- **A retainer's work journal and their life events now read each other.** No more jail night the journal never mentions, or a "took caravan work" event while the journal has them at the forge all week. Each generator treats the other's latest output as canon: the job anchors their days, life happens in the off-hours around it, and bigger developments are channeled through the trade — rivals, dangerous clients, guards sniffing around.

### Letters & books

- **Letters read like vanilla letters — on VR too.** Click a courier-delivered letter in your inventory and it opens in the stock book reader as handwritten parchment — no popup. This also means SkyrimNet's own book-reading event and the ReadBook action now work on letters. VR uses a community-verified engine address; if a setup misbehaves, dropping an empty `SeverActionsNoLetterHook.txt` into `Data/SKSE/Plugins` reverts to the popup reader.
- **Official letters arrive on fine paper.** A hold court's correspondence (ransom answers and the like) comes on crisp invitation-grade stock; sellsword threats and retainer notes stay on the rough scrap they deserve.
- **Companions can read books from your pack.** Ask a follower to read something you're carrying — they borrow it in place, with a small scene beat crediting whose book it is. Works on delivered letters too.

### Couriers

- **Outdoors only.** Couriers no longer materialize beside you in your home, a shop, or a cave. Letters generated while you're inside wait in a queue and a courier walks up the next time you're in the open — including a blacklist for exteriors no courier could plausibly reach (Blackreach, Soul Cairn, Sovngarde, Apocrypha, the Forgotten Vale, and friends).
- **Paced delivery.** A multi-letter settle week arrives as couriers spread out over minutes, not three at once.
- **They actually leave now.** Couriers move on within a couple of game hours of delivering (was ~15 real minutes of loitering), and couriers who were alive when you saved no longer live forever after a reload — strays from older saves get cleaned up automatically.

### Survival

- **Followers eat from the party larder.** A hungry companion with an empty pack no longer starves next to fifty loaves — auto-eat pulls the cheapest suitable ration (cooked first) from whoever in the party carries food, you included. The Feed button keeps its best-food semantics, and the starving warning only fires when the whole party is truly out.
- **Campfires warm you again.** Every burning campfire in the game — Hearth camps and vanilla bandit camps alike — was failing heat detection; fixed via model-path matching that also covers modded campfire variants.
- **Camp sandbox toggle.** Whether establishing a camp starts companions sandboxing is now a Settings-page choice.

### Controller support

- **Every SeverActions popup and menu now plays with a gamepad.** A native bridge translates controller input for all PrismaUI surfaces — main menu, diary, letters, and the six prompt popups — with sane focus defaults (the travel popup confirms with one press of A instead of trapping you in a text box).

### Dialogue quality

- **Companions keep their own voices.** Party members who travel together tend to drift into one shared way of speaking — the group-conversation guidance now tells each engaged follower to hold onto their own vocabulary, cadence, and verbal habits and never borrow a companion's phrasing. (The separate always-on anti-echo guideline was removed — it over-constrained one-on-one dialogue.)

### UI

- **Actions page reskin — Writ & Command.** The composer is now a ledger-styled writ: staged sentences on ruled paper, category inks that could sit on parchment, and a wax-seal execute (dangerous verbs press a black seal). Same interaction model underneath.
- **Enterprises assign modal fixed and extended.** Retained and Indentured no longer swap descriptions; opening Manage and saving without touching the arrangement no longer silently re-files the retainer under a coerced arrangement; and arrangement descriptions are now editable per retainer.
- **Dead buttons fixed.** The World page's jail Release button, Cancel-arrest, and Travel-to-Camp all work again (a class of receivers reading a payload field the sender never populated).
- **Wardrobe preview lifecycle fixed.** Exiting the outfit preview mid-staging can no longer leave the actor naked, and the mannequin re-renders across preset swaps.
- **Robust UI payloads.** LLM-written text containing exotic line separators no longer kills a page render.
- **Popup Scale.** The non-pausing HUD popups (travel destination, payment, commission) are ~10% larger by default and adjustable from 80–150% via a new slider in Settings → UI Display — saved globally, so it survives new games and updates.

### Fixes & stability — the great audit

A six-lens, full-codebase audit (~30 verified findings, two Critical, twenty High) plus the follow-up hunts:

- **Cosave hardening.** Every growing text field is length-clamped at write, and a single oversized legacy string can no longer abort a load mid-record and silently drop the followers serialized after it. The Enterprises store now migrates forward on version bumps instead of wiping.
- **Crash-class fixes.** Four SkyrimNet decorators were touching engine state on render worker threads (crash roulette under load); FormIDs passed through float event args could silently corrupt on high load orders; both classes eliminated.
- **Load recovery rebuilt.** Five subsystems' load-recovery handlers were dead code (a Papyrus event that never fires on quest scripts) — all recovery now routes through one router that actually runs, fixing things like the camp badge vanishing after a game restart.
- **Travel errands no longer dismiss companions**, forced-combat cleanly restores faction ranks, yields and ceasefires no longer race, and long-lived anchors (work markers, jail posts) survive the orphan cleaner.
- **Log hygiene.** Eighteen orphaned native registrations that spammed "Function will not be bound" errors at every game start are gone, along with a class of cosmetic array-cast errors.
- **The Nearby Objects prompt no longer vanishes for scene veterans.** SexLab "removes" scene actors by setting faction rank -1, which left the faction entry behind — any NPC who had ever been in a scene permanently lost their nearby-objects context (and read as [IN SCENE] in group prompts). All scene-faction gates now test rank instead of membership.
- **Employment container actually gets picked.** The LLM rarely chose Employment actions in work conversations because its container description was a prose wall; rewritten in the terse style the working categories use.

## v3.1.1 — Follower reliability, clearer retainer arrangements & base-game compatibility

A focused patch: companions reliably follow you instead of being dragged back onto a work assignment or wandering off after a tavern scene; the Enterprises retainer arrangements got clearer names and a colour cue for which ones an NPC resents; and SeverActions no longer needs the Dawnguard or Dragonborn DLC to load. Save-compatible; no migration.

### Followers

- **Recruiting a working NPC now makes them follow.** If an NPC was on a work assignment (a retainer's job, a sandbox shift) and you recruited them as a companion, they'd keep doing their job instead of falling in behind you. Their work package is now stood down the moment they join you — and the assignment is remembered, so they pick it right back up when you dismiss them.
- **Telling a worker to follow works too — not just formal recruitment.** The same fix now covers the casual "follow me" path (the wheel menu and SkyrimNet's own follow package), which previously lost out to the work assignment and left the NPC standing at their post while you walked away.
- **Followers stop wandering off after greetings and bard songs.** A companion pulled into a vanilla scene — a tavern bard's performance, a forced greeting, a quest scene — could come out the other side on their default routine and walk off (the "I had to teleport them back" problem). They now re-acquire you on their own within a few seconds. It's handled natively for snappy recovery, and it deliberately leaves alone anyone who's waiting, sandboxing, traveling, or managed by another follower framework.

### Enterprises

- **Clearer retainer arrangement names.** The confusing "Vassalage" is now **Indentured**, and "Sworn" is now **Retained** — names that say what they actually do. (Players kept choosing "Vassalage" expecting a fair deal, then were surprised the retainer resented them.) "Retained" also got a sharper description: a flat weekly wage for serving you directly — a guard, bodyguard, or household servant — running no venture.
- **Valence you can see at a glance.** The two *coerced* arrangements (Indentured, Enslaved) now render in red against the cool blue/green/teal of the fair ones (Employed, Partnership, Retained), and the picker is grouped fair-first — no more reading every line to tell which arrangements an NPC will resent. Save-safe: existing retainers keep their arrangement and simply display the new names.

### Compatibility

- **No longer requires the Dawnguard or Dragonborn DLC.** SeverActions.esp only ever pulled in those masters through two dead leftovers — an unused forge list and an orphaned script property — and both are now gone, so the plugin loads on any Skyrim install (base Special Edition included). This may also address some of the "won't load" / "SkyrimNet can't find the SeverActions quest" reports on setups missing those DLC — though we haven't confirmed that's the actual cause yet.

## v3.1.0 — Enterprises: put your NPCs to work, courier letters, player-placed camp & a batch of fixes

A big release built around a brand-new system. **Enterprises** lets you assign any tracked NPC to work for you while you're off adventuring — a trade post, a mine, an alchemy lab, a fence laundering your spoils — running a small off-screen economy that produces gold and real goods, with payroll as a real obligation so stiffing people has teeth. Because it's SkyrimNet-aware, the worker *knows* they work for you and can bring it up, negotiate, or complain in conversation. Also in this release: livelier, less-repetitive companions (richer off-screen lives and follower banter), **settings that persist across saves and updates**, physical courier-delivered letters, a player-driven camp you can place and preview yourself, Devious Devices and Diary of Mine / Paradise Halls outfit compatibility, and a stack of stability fixes. Save-compatible — existing saves gain the Enterprises cosave cleanly with no migration.

### Enterprises (new)

The core loop: assign a retainer to a job at a location under an arrangement; each in-game week their work settles off-screen into a payout you collect when you meet them or from the new money page.

- **Hire any NPC as a retainer.** Companions or ordinary townsfolk — agree a job in conversation (the LLM-driven `HireRetainer`) or assign one from the PrismaUI Actions page. Jobs include trade, mining, smithing, alchemy, farming, fencing, **guarding, and lumberjacking**, each with its own curated rewards. Home-less NPCs get a work-hours-only sandbox so they don't need a house first.
- **Three ways to be paid.** **Employed** (you pay a weekly wage), **Partnership** (you split the take), or **Tribute** (they pay *you* a cut). Each settles weekly into escrow as **real gold and real items** you Collect — and the retainer's own earnings become **actual coin in their inventory**, so off-screen labor visibly grows their wealth.
- **Payroll has teeth.** Miss wages and a retainer slides into arrears, then a two-week grace period, then **deserts** — taking some of your escrow on the way out. Pay back-wages to restore good standing (and loyalty). It's a self-balancing economy, not free money.
- **Illicit work and consequences.** A **fence** launders your spoils for profit, but accrues heat — at the threshold it becomes a real bounty and a guard may **arrest and jail** them (a guard walks up if you're nearby; otherwise they're hauled off-screen). You can **bail them out** early, and the arrest is something the world and the fence remember.
- **Grow your ventures.** Invest gold to raise a venture's **tier** for bigger output, and watch retainers ask for **raises** as their operation grows — **grant**, refuse, or **negotiate a meeting-in-the-middle**. Refuse too often and a resentful retainer may start quietly skimming.
- **They're alive about it.** Retainers know they work for you and can talk about the job, their pay, and their grievances. Significant moments (a missed payday, a desertion, a bail-out, a jail term served) become real memories and tavern gossip, and each retainer keeps a weekly **work log**. Occasional **setback weeks** and incidents keep the numbers from being too tidy.
- **Cross someone badly enough and it follows you.** A retainer wronged hard enough on the way out can leave with a **grudge** — and later send **hired thugs** to ambush you on the road. A tense standoff plays out (with dialogue options) before it comes to blows.
- **The Enterprises money page.** A new top-level PrismaUI page: a board of your retainers grouped by job with per-column and top-line totals (income, payroll, net, troubled, jailed, heat), the full Steward's Ledger (Summary · Bounty · Estate · Debts · Travel · Commissions), and per-card actions — **Collect, Pay wages, Bail, Dismiss, Collect-all**, plus an **Assign** picker and a **Manage** panel to reassign job, change the arrangement, or adjust wage/cut. Each card also has a **Log** of that retainer's history.

### Courier letters (new)

- **Retainers can write to you.** Instead of only surfacing in dialogue, a retainer's news (a raise demand, a situation update) can arrive as a **physical letter** hand-delivered by a courier who walks up to you and hands it over. Read it in a new **parchment popup**. The letters use real in-world book forms.

### Camp

- **Place your own camp, with a live preview.** You can now set up a Sever's Hearth camp yourself — a translucent **ghost preview** of the whole layout follows your aim so you can see exactly how it'll sit before committing. **Rotate** it with Q/E, confirm or cancel, and **reposition** an already-placed camp. Available from a configurable **hotkey** and from new **Set Up Camp / Reposition / Break Camp** buttons on the Survival page.
- **Camps stay outdoors.** A camp can no longer be pitched inside a building — both the manual Set Up Camp flow and an NPC's establish-camp action ask for open ground outside.

### Survival

- **Regen penalties work as intended.** Follower hunger / fatigue / cold were collapsing every severity tier into "no regen at all." They now scale properly — roughly half regen when mild, a quarter when moderate, a trickle at the worst — and regen is never fully stopped, only heavily reduced.
- **Turning survival off clears everyone.** Disabling the system used to leave penalties stuck on followers who weren't standing next to you; it now clears every follower, in your cell or not.
- **Per-follower tracking toggle.** Each follower on the Survival page has a Tracked / Paused button to opt individuals in or out, and the matching MCM toggles grey out while the whole system is off.
- **Survival page tidy-up.** Set Up Camp and the active-camp controls (Send to camp · Mark on Map · Reposition · Break Camp) now sit in the Camp Plan panel instead of off-screen at the bottom, and the per-follower toggle no longer overlaps the follower's row.

### Outfits

- **Full Devious Devices compatibility.** Outfit strip/undress operations now skip locked Devious Devices entirely, so a rendered device can't go invisible while its locked token stays on — DD-locked gear is left exactly as DD intends across every outfit path.
- **Outfit presets stick on managed non-followers.** An NPC you've given an outfit preset keeps it even after they're dismissed — for example a retainer who's now guarding another follower. They no longer revert to their default outfit on a cell change just because they're not an active follower; any "Managed" actor keeps their look by virtue of being managed.
- **Bondage / enslavement-mod compatibility (Diary of Mine, Paradise Halls).** While an NPC is captured, enslaved, or tied up by one of those mods, the outfit lock now stands aside — it won't fight the strip, the restraints, or the weapon swaps — and resumes managing their outfit once they're freed. Completely inert if you don't run those mods; toggleable on the Outfits MCM page.

### Companion life — livelier and less repetitive

- **Off-screen lives that range across the whole hold.** Dismissed companions no longer loop the same few beats by their front door. Their off-screen events now spread across the entire hold — other towns and villages, farms, mills, mines, roads, shrines, docks, the wilderness — and they remember their recent events so they stop repeating themselves. Every so often something with real stakes happens: they take paid work in another hold (a Guild or mercenary job, a caravan guard, a stint at a mill or on a boat), spend a night in the hold jail after a brawl, come into coin or get robbed, or have a falling-out — an actual life of their own, always wrapped up so you can still find them where you left them.
- **Follower banter that doesn't get stuck.** The party-banter director now keeps a real memory of recent topics, speakers, and pairs, so companions stop circling the same handful of talking points and rotate who opens, who they talk to, and what about.

### Settings

- **Your settings now follow you across saves and updates.** SeverActions preferences used to live only inside each save, so a new character meant redoing everything — and a handful of options reset on every launch. They're now also kept in a global file *outside* the save and *outside* the mod folder (`Documents\My Games\Skyrim Special Edition\SKSE\SeverActions_Settings.json`), so anything you change on the Settings page persists across new games and mod updates. Genuinely per-character details (a specific follower's combat style, outfit lock, survival opt-in, etc.) stay per-save, as they should.

### Fixes & stability

- **Brawls no longer kill NPCs.** A temporary essential status is layered on for the duration of a brawl, closing a gap where a third party (a stray spell, a custom-AI follower) could land the killing blow on someone who should only have been knocked down. The loser is also healed up before that status is cleared at the end, so they can't drop dead the instant the brawl resolves. Restored cleanly either way.
- **Brawl challenge popup shows correctly.** When an NPC challenges you to a brawl, you now reliably get the PrismaUI overlay card instead of occasionally getting the plain Papyrus message box — even when the challenge was triggered from a menu. (Also fixed a garbled character in the fallback prompt's text.)
- **Right NPC, every time (PrismaUI).** Follower and home actions from the UI now resolve the target by its form, not its display name, so duplicate-named NPCs (two "Bandit"s, two guards) no longer cause the action to land on the wrong one.
- **VR summon crash fixed.** Summoning a follower to you while you were using furniture could crash on VR; the teleport now ejects from furniture and retries safely.
- **Settings that stick.** The **auto-stand furniture** distance now persists and reloads correctly, and the **mannequin-preview** toggle is honored on a fresh game load instead of resetting.
- **Actions-page crash fixed.** Running the recurring-debt action from the PrismaUI Actions page could reliably crash; fixed.
- **Quieter banter.** Removed the debug notifications that popped in the top-right when follower banter was about to fire — banter now arrives unannounced, as intended.
- **NPCs reliably find a workstation.** Asking a follower to cook or smith would often fail with "I can't find one" even with a pot or forge nearby — the search only checked your immediate cell within a short radius. It now spans the loaded area around you and reaches farther, so the inn kitchen across the room and the forge across the courtyard both count.
- **Garbled in-game text cleaned up (mojibake).** Audited every Papyrus display string and removed the non-ASCII characters the compiler was baking into the game as garbled text (an em-dash showing up as `â€"`) — notifications, MCM labels, follower narrations, and the camp-placement banner all read cleanly now.
- Plus a quest-item retrieval fix and a quest-awareness prompt-availability fix.

## v3.0.7 — Mannequin fidelity, transparent-viewport fallback, outfit-menu crash fix & camp reliability

Another pass on the Outfits-mannequin preview — much closer skin, makeup, and warpaint rendering — a new transparent-viewport fallback for stubborn load orders, a fix for an outfit-menu crash on common NPCs, and a reliability fix for Sever's Hearth's "go to camp." Save-compatible; no migration.

### Outfits / Wardrobe renderer

More fidelity work on the mannequin preview. As before, these affect only the offscreen Outfits-window preview — never your follower's actual in-game appearance.

- **Per-pixel skin shading.** The preview now reads each skin's subsurface (`_sk`) and specular (`_s`) maps, so CBBE / 3BA skins render with proper soft subsurface tint and per-pixel highlights instead of a flat, uniform sheen.
- **Scars, freckles & body overlays show.** RaceMenu / SKEE overlay layers — scars, freckles, birthmarks, and overlay-based makeup — now render via a transparent decal pass instead of being dropped from the preview.
- **Makeup renders in its real color.** RaceMenu / SKEE makeup overlays with a chosen tint now show that color (eyeshadow, lip and blush tints) rather than the base texture color, by reading SKEE's per-overlay tint.
- **Warpaint & complexion show on baked-FaceGen followers.** Baked warpaint, makeup, and complexion (the FaceGen "FaceTint" layer) now composite onto the head, so follower replacers with bundled face paint look right in the preview. Resolved from the live head, and — when a wet-skin / SSS shader has taken over the head's tint slot — directly from the NPC's FaceTint file.
- **Fixed an outfit-menu crash on guards, bandits & generic NPCs.** Opening the outfit menu on a leveled / templated NPC (most guards, bandits, and generic townsfolk) could CTD on a bad form lookup. Those NPCs now open cleanly.
- **Transparent-viewport fallback for the mannequin.** A new **Settings → Interface → "Disable Mannequin Preview"** toggle for load orders where the preview won't render correctly. Instead of a blank box, it turns the doll window into a transparent cutout onto the **live game**, so you can still see — and dress — the NPC in the world; it also skips the preview bake entirely (a performance win on those load orders). A **Free Look** button hands camera control to the game so you can frame the NPC with your own camera (fully compatible with SmoothCam / True Directional Movement) — press your menu key to return. Dressing, presets, and all other controls keep working, and the setting persists across saves.

### Camp

- **"Go to camp" works reliably now.** Sending a companion (or any NPC) to a Sever's Hearth camp had stopped working on existing saves — they wouldn't move, could crash the game on the latest runtime, or got pulled back a few seconds after setting off. They now walk over and settle in by the campfire properly, and apply their camp behavior on arrival instead of standing frozen. Includes a crash fix on Skyrim **1.6.1170** and self-healing on saves where the system didn't initialize on load.

### Followers

- **"Follow" reliably pulls companions out of camp or waiting.** The wheel **Follow** action is now a clean context toggle — companions swap between resume-follow and wait, casual NPCs between start and stop following — replacing the old dead-end where a following companion couldn't be toggled. More importantly, resuming follow now actually **breaks a companion out of a camp or waiting sandbox**: it cancels the camp hold, releases them from the Sever's Hearth campfire, and re-applies their follow package, instead of leaving them parked by the fire. This also fixes a long-standing issue where **recruiting or calling a follower** didn't release them from a camp (the underlying "called by player" signal was malformed and never reached the camp system).

## v3.0.5 — Outfits, followers, arrest, survival & Life Tracker fixes

Everything since v3.0.1: a quality-of-life pass on the Companions / Life Tracker pages, a large batch of Outfits-mannequin renderer fixes, stronger follower catch-up (now with a track-only toggle), an arrest-eligibility fix, a survival master-switch fix, and several stability fixes. Save-compatible with v3.0+; the off-screen-life cosave gains two backward-compatible fields, so older saves load cleanly.

### Outfits / Wardrobe renderer

Robustness work on the mannequin preview — these only ever affected the offscreen Outfits-window baker, never your follower's actual in-game appearance. The harder-to-reproduce crashes below are best-effort fixes; the preview leans on a lot of third-party mesh and shader data, so more edge cases may still surface — please keep reporting them.

- **Addressed several mannequin crashes & freezes.** Opening the preview for certain NPCs (heavy NPC-overhaul modlists) could CTD on a face/eyes/hair buffer over-read; changing a follower's outfit could crash mid-swap (a use-after-free); and rapid edits could freeze the page with a storm of un-debounced 24-angle bakes. These paths are now guarded, serialized, and debounced — crashes should be far rarer, though the mesh-dependent ones may not be fully eliminated.
- **Reduced rendering artifacts.** BodySlide outfits bundling a reference/virtual body (a `VirtualCBBE`-style shape with no diffuse) could paint the whole body purple, and complex followers (glowing eyes, Spriggan/aura FX) could show as yellow/green glow blobs. Both should be largely resolved — phantom reference bodies are skipped and emissive is attenuated — but unusual mesh/shader setups may still need tuning.
- **Ghost presets cleaned up.** Legacy presets that showed blank yet still occupied slots (so saving a new one jumped to preset #5) are repaired — slots free and new presets fill them.
- **Blacklist respected on equip.** Equipping an outfit via the Sever UI no longer strips items from a blacklisted plugin you'd equipped outside SeverActions.
- **Faster reopen.** Reopening an unchanged outfit reuses the cached preview instead of re-baking all 24 angles, so the panel appears instantly.

### Followers

- **More reliable follower catch-up.** Followers now get pulled through city gates, load doors, *and* fast travel even when you stop and give no input — noticeably better at keeping up, though still being tuned. A new **"Catch Up Track-Only Followers"** setting (Settings → Follower Behavior, default On) extends it to NFF / custom-AI / DLC followers like Serana; turn it off to leave those to their own framework. *(Setting is runtime-only for now — resets to On each launch.)*
- **Surrendered-then-recruited followers stop getting stranded.** A follower you'd beaten into yielding and then recruited would refuse to follow through doors or fast travel — a lingering "surrendered" status kept the catch-up from moving them. They now keep up like any other companion, while followers genuinely told to wait stay put.
- **Essential toggle now works on any follower.** It set an ActorBase flag the engine ignores for templated/leveled NPCs; it now makes the actor essential at the reference level, so it works on every follower and applies live.
- **Work / Relax locations show outdoors.** Setting a follower's Work or Relax spot outdoors didn't show on the Companions page even though Set Home did; both now display correctly indoors or out.

### Arrest

- **Guards reliably offer arrest actions.** Fixed an eligibility bug that could stop guards from surfacing any arrest-related actions in conversation — arrests (NPC or player), adding bounty, jailing and releasing, and dispatching guards to investigate homes for evidence. The full arrest toolkit is now offered correctly across vanilla and mod-added guard factions.

### Survival

- **The master switch actually turns survival off now.** Toggling Survival off on the page (or in the MCM) didn't fully disable it — the survival prompt kept describing hunger/fatigue/cold in conversation, and followers kept their stat penalties. Off now means off: the prompt stops and penalties clear. Each follower's needs are **preserved** rather than wiped, so turning Survival back on resumes exactly where it left off.

### Life Tracker — character management

- **Remove a character.** A new remove (✕) button clears a character's letters and stats, hides them from the page, and stops generating new off-screen events for them — handy for cleaning up duplicated or deleted NPCs that lingered in the tracker.
- **Restore a removed character.** A new **Hidden** list lets you bring a removed character back with one click; they reappear and resume their off-screen life.
- **"Show Removed Characters" setting.** A toggle under **Settings → Off-Screen Life** hides the Hidden list entirely for a cleaner page, and brings it back when you want to restore someone.

### Stability

- **Fixed a world-map CTD** caused by dirty edits in the bundled Sever's Hearth ESP overriding the vanilla map-marker base static — a conflict that corrupted marker rendering on heavy map-mod load orders. The dirty edits are removed; the camp-on-map feature is unaffected.

## v3.0.1 — Skyrim VR support

Hotfix on top of v3.0. SeverActions and the bundled Sever's Hearth now build and run on **Skyrim VR** — the native DLLs are universal SE/AE/VR. Two small quality-of-life fixes round it out. Save-compatible with v3.0; no migration, no new requirements on SE/AE.

### Skyrim VR support

The native plugins are now compiled as universal SE/AE/VR binaries against CommonLibVR, fixing every crash and hang VR users hit on v3.0. No change for SE/AE players.

- **Now boots on VR.** v3.0's DLLs were SE/AE-only, so VR CTD'd at launch with *"failed to open address library file."* Both `SeverActionsNative` and `SeversHearthNative` are multi-targeted now and load on VR.
- **No more infinite load with SkyrimNet.** Our SkyrimNet decorators were registering before SkyrimNet finished standing up its own systems, which deadlocked its startup on VR — the main menu never appeared. Registration now happens at the correct point in load (kDataLoaded), so all decorators come up cleanly.
- **No main-menu crash.** A VR-incompatible fast-travel event sink (the event doesn't exist on VR) is now guarded, so the situation/cell monitors no longer crash at the main menu.
- **Outfit slots work on VR.** VR has no runtime-EditorID retention (no po3 Tweaks build), so the outfit system couldn't find its records by name and silently failed (*"Outfits/LvlItems FormLists missing"*). It now resolves its own records by FormID — all 800 outfit slots index correctly on VR.
- **Survival warmth** degrades gracefully on VR, falling back to armor-record warmth where the SE/AE engine API isn't available.

### Fixes

- **Fertility — insemination narration removed.** The `*<father> releases inside <target>.*` narrator line that fired on Fertility Mode insemination is gone. (Conception narration is unchanged.)
- **Dashboard date corrected.** The PrismaUI dashboard showed the wrong in-game date on a new game — *"Sundas, 1st of Morning Star"* with no year, instead of the canonical *"Fredas, 17th of Last Seed, 4E 201."* It now uses the save-anchored Skyrim calendar, so the date and year read correctly from day one and advance properly.

## v3.0 — Hearth Ledger, native cosave, arrest overhaul, brawl

The largest release in the mod's history. Six PrismaUI pages got the new "Hearth Ledger" visual identity, the outfit subsystem was rebuilt on a native cosave store, a full arrest pipeline shipped, a fist-fight brawl system arrived, and the travel / sandbox / follower-maintenance systems were rewritten for reliability. Save-compatible upgrade — pre-existing data migrates automatically on first load.

### PrismaUI — Hearth Ledger visual overhaul

Every page was rebuilt around a shared "parchment + brass + dark surface" design language, with rail / center / drawer layouts replacing the prior flat lists. The dashboard is the new front door.

- **Dashboard.** Frontispiece title strip, ex-libris bookplate with your character + Skyrim date, six **Portal Tiles** (Companions / Coffers / Holdings / Provisions / Tidings / Chronicle — each in its destination page's accent color so the dashboard reads as a true table of contents), illuminated Recent Entries with sigil portraits and drop-cap actor names, Steward's Dispatch slip quoting the latest gossip, and a marginalia portent list. Consecutive entries from the same actor collapse with a small ↳ continuation marker.
- **Outfits / Wardrobe.** Three-column layout (roster + active follower + builder). Mannequin renderer rebuilt: heads, hair, alpha-tested items, custom shader subclasses, helper meshes, and skin all render correctly. Cart-preview revert moved to native code so closing the menu without committing always reverts cleanly — no more "I closed the menu and my follower is still wearing the staged outfit."
- **Inventory.** Three-column rail / center / drawer layout, native drag-to-give between actors, per-category limits, item-stack count fixes.
- **Stats + Spells.** Stats tab redone as a character sheet (Skyrim-style attribute panel + perk count + skill bars). Spells tab redone as a grimoire (school filter chips, click for full effect breakdown, real magnitude/duration/area substitution).
- **Settings.** Full rail-nav rewrite with section search. World, Inventory, Outfits, Schedule, Currency, Debt, and Off-Screen settings all reachable from one rail — one place to tune everything.
- **World.** Parchment Skyrim atlas (Caro Tuts paper map) with hold sigil markers. Click a hold for a drawer with per-hold bounty, properties, travel, and debts. Map / Ledger toggle keeps the prior sectioned layout for power users.
- **Survival.** Redesigned around a Camp shell. Party Vitals on one side, Camp Plan journal on the other, with at-a-glance Rations / Warmth / Risk hero banner.
- **Active Arrests (new).** Visible feedback for the new arrest watchdog — see every active arrest, who's escorting whom, and how close each one is to timing out, color-coded by urgency.
- **Companions refinements.** Sub-tab structure (Profile / Bonds / Bio / Memories / Journal / Quest Awareness). **Bonds is editable** — drag rapport / trust / loyalty / mood values directly. **Bio** tab mirrors SkyrimNet's on-disk character bios. **Memories** tab shows the most recent 20 memories with proper Skyrim-calendar dates.
- **Actions Composer.** Rebuilt as `[Actor] → [Verb] → (target?) → (modifier…)` composer with spotlight typeahead, six pinned chips, and recents replay. **37 verbs across 8 categories** including the new Brawl and Travel categories. Required-param indicator + smarter confirm messages (`Execute Extort Gold as Lydia? Victim: Brand-Shei · Amount: 50` rather than just "Execute Extort Gold on Lydia?").
- **Per-page help tooltips.** A "?" button next to the close button opens a modal with help content for the current page. Audited for all 11 pages.
- **Page Help, Refresh, Scroll, and Confirm dialogs** now use in-app modals throughout (the previous browser-native `confirm()` returned `undefined` inside Ultralight and silently dropped actions).
- **Dashboard quest banner.** The dashboard front page now surfaces your active quests, each with its next incomplete objective.

### Brawl system (new)

Fist-fight system for player ↔ NPC and NPC ↔ NPC, fully integrated with the LLM and PrismaUI.

- **Challenge / Accept / Decline / Forfeit** action verbs and PrismaUI buttons. NPCs can challenge each other to brawl, and the loser yields cleanly.
- **Brawl prompt overlay.** When you receive a challenge, a PrismaUI prompt surfaces the accept/decline choice without pausing the game in a normal menu.
- **Native BrawlManager** handles the CS/DG cache, engagement watchdog, spectator pacification, and a friendly-fire exception so your other followers don't intervene.
- **Spells stripped and restored.** Magic-user followers don't fireball their brawl opponent; their spell list is temporarily removed and restored on brawl end.
- **Custom CombatStyle** (`BrawlerCS`) tuned for unarmed combat with no spells, no weapons, and no flee.
- **Tracking-only followers rejoin cleanly after a brawl.** An NFF / SPID custom-AI / Serana-style follower has their teammate flag briefly cleared during a brawl (so your other followers don't pile in); they're now reliably re-onboarded into tracking mode when it ends, instead of being stranded on idle AI.

### Arrest pipeline overhaul

A complete rewrite of how NPC arrests work, with a watchdog to catch stuck arrests and a player-facing FSM for confrontation + persuasion.

- **ArrestSessionStore.** Native watchdog tracking every active arrest with per-state in-game-hour timeouts. If a guard gets stuck escorting a prisoner across the map, the watchdog fires a timeout and forces a clean cancel instead of leaving the actor frozen forever.
- **Mid-escort plea.** Prisoners can appeal to their escorting guard mid-march (60-second window, single attempt). Guard halts, weapon stays drawn, and accepts or rejects via dialogue or LLM action. Accept = release + cleanup; reject = resume escort.
- **Scene-aware home suspend.** Vanilla quest scenes can pull your homed follower into scripted behavior (e.g. Serana searching her mother's lab during Soul Cairn). The home sandbox now detects active scenes and temporarily suspends itself so the quest scene plays correctly, then re-applies when the scene ends.
- **Player-confrontation FSM** (Persuasion). When a guard tries to arrest you, you can plead, bribe, intimidate, or resist via PrismaUI. Each branch has its own logic and timer.
- **Active Arrests panel** in PrismaUI (above) gives you live visibility into every in-flight arrest.
- **SkyrimNet busy state** integrated — actors involved in an arrest report `is_busy = "arrest"` so other plugins and our own action YAMLs gate eligibility correctly.
- **Sender-name canonicalization** — fixed cases where the LLM's authority picker sent `"Player"` literally and fuzzy-matched into NPCs whose names contained "Player".
- **OrphanCleanup** rewritten so stale faction memberships from a crashed prior arrest never block re-arrest forever.
- **PrismaUI Arrest prompt overlay** for when you're confronted by a guard, mirroring the brawl prompt pattern.

### Outfit system — rebuilt on native cosave

The whole outfit subsystem (locks, presets, situation mappings, dress/undress) moved off Papyrus StorageUtil and onto a versioned native C++ cosave store. Pre-existing saves migrate automatically on first load.

- **No more split-brain outfits.** Cases where PrismaUI showed one outfit but the NPC wore another, or where SkyrimNet thought the NPC was wearing preset X but the actor's armor said otherwise, are gone. One source of truth.
- **Dress / Undress survives a reload.** Undressing, saving, reloading, and re-dressing now correctly restores what they were wearing — including outfits applied via preset.
- **100 outfit slots** (was 20). NFF-style per-item ownership tracking + outfit alias hardening for large follower rosters.
- **Edit Preset (new).** Click `Edit` on any saved preset row — the staging card opens pre-filled with that preset's items and name. Add, remove, optionally rename, then save in place. Renames preserve the slot, container, leveled-item list, satchel, and catalog so SkyrimNet actions and the mannequin keep working.
- **Delete Preset works.** The `✕` button on preset rows previously appeared to do nothing inside Ultralight (browser `confirm()` returns undefined there). Now routes through the in-app confirm dialog and actually fires the delete.
- **Reset Outfit Data actually resets.** PrismaUI's red "Reset Outfit Data" button now wipes every situation mapping, the dress stash, and the follower-lock flag in one shot.
- **Mannequin viewport no longer stutters.** Rapid preset swaps were queuing 7+ piled-up rebakes that froze the cursor; now throttled to one bake per frame.
- **Daegon Kaekiri compat patch** updated to gate on `Native_Outfit_IsActivelyManaged` instead of a bare faction check, so flagging her as outfit-excluded properly hands ownership back to her mod's outfit dialogue.
- **Situation outfits.** Bind a preset to one of seven situations (city / outdoor / sleeping / combat / house / rainy / snowy). Auto-switches based on the active situation.
- **Outfit P0–P3 fixes from the tester report.** Saving a preset no longer auto-strips and re-equips; applying a preset preserves your existing lock state; "shadow" outfits in the cosave but absent from PrismaUI now surface as orphan rows with a Remove button; slot-mask sweep catches stray armor pieces (e.g. boots left over from a previous preset that didn't have them).
- **Managed NPCs tab.** Non-follower NPCs you've dressed get their own Managed tab on the Outfits page, with **Forget** / **Forget All** to prune an NPC's lock + presets from the cosave and restore their original look — replacing the old clipped "Other NPCs" strip.
- **Save preset from worn.** The left "Save Preset" button now snapshots whatever the follower is *currently wearing* straight into a real preset, instead of writing to a legacy store the slot-based list never showed — no need to re-stage an outfit you already put on them.
- **Modded armor on extended slots stays visible.** The inventory and outfit menus no longer hide legitimate armor parked on biped slots 49-61 — skirts, pauldrons, layered tops/underwear, capes, corsets (the pieces SkyUI marks with a generic "shield" icon). Only genuinely valueless body overlays (SOS/TNG, morph markers) are filtered now.
- **Smooth mannequin rotation.** Dragging to spin the preview no longer judders or flashes a blank frame.
- **Mannequin skin rendering hardened.** The outfit preview now renders skin faithfully across the full range of modded setups. Full-colour skin replacers (Bijin et al., whose `bodyTintColor` is ~0) no longer bake to a black silhouette; wardrobe mods that bundle a duplicate body no longer z-fight into gray blotches; SAM's junk skin specular no longer paints a gray metallic rim; a follower whose body texture simply isn't streamed to full-res yet is demand-loaded from disk instead of dropping to flat white/peach (the Lillith Maiden-Loom "white body" case); a body referencing a genuinely-missing texture (Lillith's "Unibody" overlay) is dropped instead of rendering purple; and alpha-blended skin overlays the opaque baker can't composite — SexLab fluids, RaceMenu scars/tattoos/dirt — are dropped rather than painting black or red over the body (the Saadia "black front + dark-red face" case). Skin overlays (scars, bodypaint, fluids) still don't *composite* into the preview, but now degrade to cleanly absent instead of artifacting.

### Companion + follower

- **Wait / Follow buttons** on every companion card (per-row Wait + Follow, plus Wait All + Follow All in the mass-actions row). Mirrors the hotkey and wheel-menu entry points 1:1.
- **Summon All** mass-action button.
- **Companion Wait / Sandbox reliability fixes.** Ported the sandbox approach from Sever's Hearth — adds `EvaluatePackage()` calls so wait/follow transitions happen immediately instead of on the next AI tick, bumps sandbox package priority above other follower-framework overrides, and uses a gentler AI-reset flag. No more "I told them to wait but they're still trailing me."
- **Schedule system.** Dismissed followers can be assigned per-hour Home / Work / Relax locations and they'll actually go there on the right schedule.
- **NFF-style follow package (V2).** Tiered priorities, idle behaviors, and dynamic stance — replaces the prior default template.
- **Healer combat style.** Set any follower to "healer" via PrismaUI dropdown, dialogue, or `setcombatstyle` action — they force-cast healing during combat with proper target priority, cooldowns, and a bleedout fail-safe.
- **Cell catchup.** Followers no longer get left behind through load doors. A native catch-up sweep runs 1.5s after the player's cell loads, moves any roster member who didn't follow through, evaluates their package, and randomizes positions slightly to avoid pile-ups.
- **Follower friendly-fire prevention.** Stray AoE / cloak / cone-spell hits between SA-followers no longer flip them hostile to each other.
- **Per-follower Essential toggle** properly persists across save/load.
- **Equipping a recruited NPC** now diff-strips the vanilla hunting bow + iron arrows starter kit so they don't permanently re-equip them.
- **Animated NPC spell casting** via UseMagic AI packages — `castSpell` action now produces the visible casting animation instead of just stat changes.
- **AttackTarget auto-cleanup** via ForcedCombatMonitor — combat ends cleanly when the target dies or surrenders, no stuck combat state.
- **Track-only followers no longer wander off when the player sleeps.** `OnSleepStart`'s package-override clear used to wipe the external framework's follow package on NFF / SPID custom-AI / Serana-style followers, leaving them on default idle AI. Now gated to skip tracking-only followers; their controller owns the package stack.
- **Fallen-comrade count fixed.** The Companions page no longer over-counts fallen comrades, and a **Clear Fallen & Orphaned** bulk action prunes dead and stale entries in one click.
- **Safe-interior sandbox no longer sticks.** A companion who sandboxed in a tavern (e.g. after sleeping) could get stuck on the interior package and wander off instead of resuming follow; the sandbox now releases cleanly on active companions.

### Travel system

- **TravelOrchestrator** — new unified high-level travel API that composes line-of-sight arrival, stuck escalation, preflight reachability, and graceful give-up into one state machine with a single completion event.
- **StuckDetector** now disambiguates "actually stuck" from "slowly pathing through a crowded inn" — the 30-second teleport no longer fires on actors who are navigating, just slowly.
- **LOS-aware arrival.** Travel destinations on the far side of a wall, on a different floor, or behind a closed door no longer trigger arrival from raw distance alone.
- **Graceful give-up.** When a destination has broken navmesh, fall back to the actor's editor location instead of teleporting them deeper into the broken area.

### Crafting commissions (new)

Order crafted gear now and collect it later, instead of standing at the forge while it's made.

- **Order now, collect later.** Ask a blacksmith to craft something; they quote a price, take a deposit, and you pick the finished piece up on a return visit. The smith remembers which commissions are outstanding and hands the item over when it's ready.
- **In-character pricing.** The smith names the deposit and total themselves, and the system charges exactly what was quoted — the spoken price and the gold actually moved always match.
- **Commissions ledger.** A Commissions sub-rail on the World → Ledger page tracks open orders and completed history.

### Performance + load-time

- **Save load is now visibly faster.** Heavy per-follower maintenance (essential flag, combat style application, healer registration, opinion rebuild) moved from a saturated Papyrus VM to native C++ at `kPostLoadGame`. The PrismaUI hotkey is now responsive within ~1–2 seconds of cosave restore (was ~25 seconds on heavy rosters).
- **Hearth-parity sandbox transitions.** `EvaluatePackage` calls added so wait/follow respond immediately.
- **Batched mass actions.** Wait All / Follow All now dispatch a single event that Papyrus iterates server-side, instead of firing one event per follower — keeps the engine sane for NFF/UFO setups with 10+ followers.
- **Companions page opens instantly on large rosters.** Each companion's Bio / Memories / Journal is now gathered lazily — only when you open that companion — instead of building all of it for every follower up front on page load.
- **More per-tick work moved to native C++.** Survival and Fertility cell scans, plus the follower-roster lookup, no longer run on the Papyrus VM every tick.

### Stability + crash fixes

- **Non-UTF-8 JSON crash fixed.** SkyrimNet payloads containing Cyrillic or other non-ASCII characters used to crash with a `nlohmann::json::type_error.316`. Now strings are sanitized on the boundary.
- **Survival page banner no longer shows stale followers from a previous save.** A frontend cache-merge bug surfaced characters from a prior load on a brand-new game (Daegon shown in the warmth banner with no party). All conditionally-emitted fields now emit cleared placeholders so the merge correctly reflects the current save.
- **PrismaUI menu hotkey no longer silently breaks.** When the native script class grew past Skyrim's 511-function-per-script limit, every native call on it failed at link time. Functions were split across a sibling class so the budget stays safe.
- **CommonLibSSE-NG v4.17 upgrade** — pinned via vcpkg overlay for reproducible builds, adopting native APIs that replaced ~180 lines of keyword-scanning warmth code, the legacy hand-rolled raycast, the Disable/Enable navmesh-snap pattern, and process-tier queries.
- **OutfitMigration log lines** in `Papyrus.0.log` show any conflicts between your old StorageUtil data and the new native store when the migrator runs on first load.
- **Dashboard no longer freezes the game on open.** A raw engine-member read for the compass-tracked quest banner spun forever on an unreliable lock, wedging the game thread the moment the dashboard opened. Removed — the banner now picks deterministically among your active quests.
- **Decorator render-thread crashes closed.** SkyrimNet renders decorators on worker threads; ours now read from main-thread snapshot caches instead of touching live engine state mid-render, eliminating a class of race-condition crashes.

### Prompts + content

- **Nearby objects prompt split.** General dialogue context no longer carries container contents (keeps payload bounded), but action-mode now gets the full container listing so the LLM can pick items from a chest properly.
- **Merchant inventory** prompts now render in `action` mode too, so the LLM has shop prices visible while picking buy/sell actions — not just during narration.
- **User-configurable Nearby Objects filters.** PrismaUI Settings → Prompt Filters lets you exclude object types (clutter, misc, furniture:bed, item:weapon, etc.) from the LLM's nearby-objects context.
- **Familiarity prompt eavesdrop filter.** Strangers no longer falsely claim to have overheard your name from a follower in places the follower has never spoken (Soul Cairn ghost scenario).
- **Bounty prompt** updated with full scene-coverage (same-cell arrest section, dispatch-escort section, prisoner mid-escort affordance) and explicit exclusion lists.
- **SkyrimNet character-bio Tier 1 audit** — 55 priority bios (vanilla followers, major quest characters, key faction figures) re-written to remove Tough-Guy-One-Liner speech_style priming and forward-looking quest spoilers in summary blocks. Ships as a parallel track outside the FOMOD.
- **Yield / surrender context toggle.** A new Settings → Prompt Filters → Combat Context switch suppresses the "just surrendered / received a surrender / surrender broken" guidance when it doesn't fit the moment. Ceasefire and active-combat awareness are unaffected.
- **Prior-companion context deferred to SkyrimNet.** Dropped the redundant "Past Relationship" block from the follower bio; SkyrimNet's own relationship decorator already surfaces that history, and the SA version could mis-fire for NPCs you'd only briefly traveled with.

### Miscellaneous polish

- **Brawl decorator** + split-prompt support so the LLM has structured awareness of brawl state.
- **OSL silencer** keeps OStim/SexLab scenes from spamming the LLM context.
- **CollectPayment** non-pausing PrismaUI overlay POC — collect debts without freezing the world.
- **Transfer Ownership** action on the Actions page.
- **Group Meeting** revived on SkyrimNet primitives.
- **MCM UI Scale slider** as a PrismaUI escape hatch for users who can't read the default size.
- **Off-Screen Life per-NPC cooldown overrides** + first-load staggering so dismissed-follower events don't all fire at once on save load.
- **Quest awareness** noise filter, new Companions sub-tab, C++ LLM pump, per-follower memory.
- **Holdings hold-resolution fix.** The Holdings portal tile no longer renders "Unknown × 1" for properties whose name doesn't contain the hold keyword (Breezehome, Vlindrel, Hjerim, etc.) — replaced with a three-tier resolver.
- **Claim a property (Estate).** The World → Ledger → Estate tab gained a search to bring any building into your name — houses, inns, halls, temples (caves / dungeons filtered out, with a "Show all interiors" toggle for modded homes). It uses the same faction co-ownership as the in-character deed transfer, so you and the original owner share it without trespass — ideal for backstory roleplay. Each property card's badge is a click-to-cycle flavor label (Transferred / Purchased / Inherited), and releasing a claimed property now fully reverts ownership (it was passing a null faction before).
- **NPCs no longer recite your holdings.** Removed the character-bio block that injected the player's full property list into every NPC's context.
- **Ownership-aware looting.** Taking an owned item through a SeverActions loot/pickup action no longer gives the *player* a vanilla theft bounty (the "my follower grabbed a tankard in a tavern and now I'm wanted" case) — owned items transfer silently instead of tripping the engine's theft alarm. Loot-corpse now targets the nearest matching body, and locked containers are refused outright.
- **No more critters in "nearby people."** Ambient animals (rabbits, foxes, etc.) are filtered out of the dashboard / nearby-actor lists.

### Sever's Hearth — AI camping (bundled, new)

A new AI-first camping mod ships alongside SeverActions as an **optional FOMOD module** ("Sever's Hearth (Camp System)"). It replaces Campfire outright — **no dependency required**. This is an early, foundational release: the core camping loop and LLM camp-awareness are in; survival, threats, and the off-screen follower-agency layers are still ahead.

- **Make camp on the trail.** A companion can pitch a camp at the player's position — a fire ring and bedroll for the party to rest, eat, or take watch. (Player-initiated camp placement isn't in yet; camps are established relative to the player by a follower.)
- **Establish / Break / Go-To camp actions.** The LLM can suggest making camp when the party needs to stop for the night, break it down to move on, or send a companion ahead to an existing camp.
- **Camp-aware companions.** While a camp is active, the `current_camp` decorator feeds the campsite into each follower's bio context, so they reference the fire, a shared meal, or resting here naturally in conversation — the camp becomes a known waypoint in the scene, not just props.

---

## v2.9.9

### SkyrimNet Bio Audit — Tier 1 (Parallel Track, Not In FOMOD)

Independent audit pass over the SkyrimNet character bios shipped at `Data/SKSE/Plugins/SkyrimNet/original_prompts/characters/` (3,146 bios total). Drove by the same lesson learned from the Kynreeve case: bio `speech_style` blocks that describe a character as "clipped, terse, blunt" prime the model to produce period-stopped Tough-Guy One-Liner output regardless of any prompt-level guardrails, because character-scoped voice instructions outweigh scene-scoped ones. Same applies to `summary` blocks that bake in forward-looking quest spoilers — a stranger meeting the NPC for the first time shouldn't have those framings driving the LLM's first-impression dialogue.

Wrote a triage script (`bio_triage.py` — temp, not in repo) that flagged 1,354 bios across 3,146 with at least one issue: 951 with speech_style priming only, 259 with summary spoilers only, 144 with both. Of those, 55 are flagged as priority NPCs (vanilla followers, major quest characters, key faction figures).

Processed all 55 priority bios in this pass:

- **Lydia** (worked example, hand-edited as the template): replaced "direct, concise sentences with minimal embellishment" with "measured rather than clipped — full thoughts, even when brief, with their joints intact." Removed Dragonborn-specific framings from summary; kept thaneship references (publicly bestowed honor, not a spoiler). Werewolf/Greybeards/Western-Watchtower references reframed.
- **54 additional bios** processed in 5 parallel agent batches, each given the handoff doc + Lydia's before/after as a worked template:
  - **Whiterun & Companions (11)**: aela_the_huntress, athis, balgruuf_the_greater, farkas, irileth, kodlak_whitemane, njada_stonearm, proventus_avenicci, skjor, uthgerd_the_unbroken, vilkas
  - **College & Mages (7)**: ancano, drevis_neloren, festus_krex, mirabelle_ervine, neloth, phinis_gestor, savos_aren
  - **Greybeards & War Factions (9)**: arngeir, borri, delphine, einarth, elenwen, esbern, galmar_stone-fist, paarthurnax, wulfgar
  - **Thieves Guild & Dark Brotherhood (6)**: arnbjorn, babette, karliah, mercer_frey, tonilia, vex
  - **Followers & Dawnguard DLC (21)**: ahtar, annekke_crag-jumper, argis_the_bulwark, borgakh_the_steel_heart, calder, florentius_baenius, frea, golldir, ingjard, iona, isran, jenassa, marcurio, mjoll_the_lioness, rayya, serana, sorine_jurard, teldryn_sero, valdimar, valerica, vorstag

**Approach per bio**:
- `speech_style`: rewritten to capture voice without priming. The replacement vocabulary pattern: "X, never clipped — full sentences with their joints intact" / "economical with words but always answers fully" / "speaks plainly, no flourish, no theater." Each character's accent, register, and personality preserved (Nord cadence, Dunmer formality, scholarly precision, etc.) — only the priming language was changed.
- `summary`: forward-looking quest spoilers stripped. Public-knowledge framings kept (Jarl titles, Harbinger, Greybeard membership for Greybeards themselves, public faction roles). Hidden identity reveals moved to the `background` block where the LLM still has the context for in-character behavior but the player isn't tipped off through summary-driven dialogue.
- All other blocks (`personality`, `appearance`, `aspirations`, `relationships`, `occupation`, `skills`, `interject_summary`, `background`) preserved verbatim, with the documented exception of `background` accepting relocated spoiler material from `summary` (per the handoff doc's explicit allowance).

**Spoiler decisions worth flagging**:
- Companions werewolves (Aela, Farkas, Skjor, Vilkas, Kodlak) — werewolf nature stripped from summary, preserved in background. Kodlak's "Harbinger" title kept as it's publicly known.
- Balgruuf's Talos worship — explicit "secretly" framing removed; reframed as "quietly worship in private" in background.
- Delphine's Blade identity — full reframe to Riverwood innkeeper in summary; Blade material in background.
- Esbern's Blades scholarship + Alduin expertise — full reframe; quest-specific material in background only.
- Paarthurnax's dragon-priest past + Alduin betrayal — full reframe to "ancient wise being who teaches the Way of the Voice"; quest-specific material in background.
- Mercer Frey's Karliah-betrayal arc — stripped from summary; kept in background.
- Karliah's Nightingale identity — stripped from summary; reframed as "Dunmer thief of the old school carrying a long-waiting grudge."
- Babette's vampire age and posing-as-child gotcha — stripped from summary; kept in background for behavioral fidelity.
- Serana's Daughter-of-Coldharbour lineage — softened to "vampire of unusual lineage" in summary.
- Valerica's Soul Cairn imprisonment + Elder Scroll + Tyranny-of-Sun prophecy — heavy summary reframe to "ancient vampire of unusual lineage with a long history rooted in old Nord nobility"; quest-specific material in background.
- Housecarls (Argis, Calder, Iona, Rayya, Valdimar) — false-positive spoiler hits on "thane" references; thaneship is publicly bestowed and is literally their job description, kept verbatim. Speech_style priming fixed where flagged.

**Codex spot-check**: ran `codex exec` over a 3-sample cross-section (Aela, Delphine, Valerica) for independent quality review. Verdict: PASS on all three, with two minor caveats noted (Aela's background got one new sentence relocating the werewolf-as-private-Circle-matter detail from summary — which is allowed per handoff; Valerica's "Serana's daughter" reference stayed in summary, which is fine since that relationship is revealed in the opening minutes of Dawnguard).

**Where the override bios live**:
- Live game (deployed): `Data/SKSE/Plugins/SkyrimNet/prompts/characters/<filename>.prompt` — SkyrimNet's override path; takes precedence over `original_prompts/characters/`
- Repo (captured for git): `Bios/SKSE/Plugins/SkyrimNet/prompts/characters/<filename>.prompt` — mirrors a future FOMOD module structure if we decide to package and ship publicly

**Tier 2 — additional 27 priority NPCs (next commit)**

Expanded the priority slug list in `bio_triage.py` to capture more high-traffic NPCs beyond the original Tier 1 hardcoded set. Re-running the triage surfaced 27 new priority candidates that weren't covered in Tier 1. Processed in 3 parallel agent batches:

- **Cities & shopkeepers (10)**: camilla_valerius, lucan_valerius, ysolda, viola_giordano, brunwulf_free-winter, brelyna_maryon, temba_wide-arm, morwen, niranye, calixto_corrium
- **Hold stewards & deeper Thieves Guild (8)**: anuriel, raerek, falk_firebeard, alessandra, sapphire, thrynn, cynric_endell, gallus
- **Daedric Princes & Volkihar vampires (9)**: malacath, boethiah_cultist_generic, boethiah_generic, fura_bloodmouth, garan_marethi, orthjolf, ronthil, vingalmo, rexus

**Key spoiler decisions in Tier 2**:
- **Calixto Corrium** — most spoiler-sensitive bio in the audit. He's the Butcher of Windhelm (Blood on the Ice murder mystery). Summary completely reframed to public-facing antiquities collector / curator of the House of Curiosities. Interject_summary also edited (original told the LLM to volunteer murder-adjacent commentary unprompted — itself a leak path). All Butcher details in background only.
- **Niranye** — Thieves Guild fence cover stripped from summary; reframed as Windhelm market vendor.
- **Anuriel** — Maven Black-Briar bribery / spy framing stripped from summary; reframed as competent Mistveil Keep steward.
- **Raerek** — covert Talos worship stripped from summary; reframed as Igmund's uncle and senior administrator.
- **Falk Firebeard** — false-positive thane_ref hit, no spoiler change needed (public Solitude steward).
- **Sapphire** — Mallory family lineage stripped from summary; reframed as guarded TG enforcer with hard past she does not discuss. Mallory hint preserved in background as in-world rumor without naming Glover/Delvin.
- **Gallus** — Nightingale role + Nocturnal pact + Skeleton Key bond stripped from summary; reframed as previous Guildmaster murdered ~25 years ago, mentor and lover of Karliah. Background keeps full Nightingale context.
- **Vingalmo** — "secretly plotting to take control" stripped from summary; relocated to background.
- **Volkihar court vampires (Fura, Garan, Orthjolf, Ronthil, Vingalmo)** — vampire status kept in summary (faction-public among Volkihar); specific schemes / future-plot framings moved to background.
- **Malacath** — Trinimac transformation kept (deep TES lore, scholar/Orc-known), summary lightly reframed; mostly speech_style fix.
- **Boethiah** — quest-mechanic preserved in lore framing (Prince of Plots, encourages betrayal as virtue); the follower-sacrifice mechanic of Boethiah's Calling not specifically tipped off.
- **Rexus** — Amaund Motierre's Dark Brotherhood contract framing stripped from summary; reframed as imperial attendant traveling with Amaund. DB association in background.

**Tier 3 — additional 30 priority NPCs (next commit)**

Further expansion of the priority slug list to capture Solstheim NPCs, Hold Jarls and court members, civil-war side cast, Daedric quest-givers, deeper TG/DB members, and spouse-able shopkeepers. Re-running the triage surfaced 30 new candidates beyond Tier 1+2. Processed in 3 parallel agent batches:

- **Solstheim & Telvanni (7)**: bujold_the_unworthy, mogrul, fethis_alor, ralis_sedarys, elynea_mothren, adril_arano, tilisu_severin
- **Holds politics & civil war side cast (10)**: igmund, hrongar, brina_merilis, faleen, vignar_gray-mane, idolaf_battle-born, olfina_gray-mane, ralof, yrsarald_thrice-pierced, hofgrir_horse-crusher
- **Daedric / TG side / Thalmor / spouse-ables (13)**: erandur, ennodius_papius, sarthis_idren_generic, rulindil, dirge, vipir_the_fleet, ravyn_imyan, dravynea_the_stoneweaver, grelka, mralki, maven_s_bodyguard, carcette_the_survivor_generic, runa_generic

**Key spoiler decisions in Tier 3**:
- **Tilisu Severin** — most spoiler-sensitive of T3. The Severin family in Raven Rock is actually a Morag Tong assassin team hiding under House Hlaalu identity to kill Councilor Lleril Morvayn ("Served Cold" Solstheim quest). Summary fully reframed to wealthy Dunmer matron of a respectable merchant household + community benefactor + polite-and-reserved public persona. All Morag Tong / assassination plot detail in background.
- **Ralis Sedarys** — Kolbjorn Barrow excavator who is being possessed by the dragon priest Ahzidal. Summary reframed to enthusiastic archaeologist looking for a backer. Possession/sacrifice arc in background.
- **Olfina Gray-Mane** — secret romance with Jon Battle-Born (Whiterun's Romeo-and-Juliet sub-plot). Romance moved from summary to background.
- **Erandur** — Vaermina cultist past stripped from summary. Reframed as kind priest of Mara helping with Dawnstar nightmares.
- **Ennodius Papius** — Dark-Brotherhood-actually-after-him reveal de-specified to "a Daedric cult has marked him for death" so the Boethiah's Calling sacrifice option isn't tipped off. Summary reframed to paranoid hermit.
- **Rulindil** — specific Etienne/Esbern Blade-interrogation framing stripped from summary. Reframed as Third Emissary / Elenwen's chief interrogator who runs informant networks. Esbern/Etienne specifics in background and aspirations.
- **Runa (generic)** — vampire status moved from summary opening to background. Reframed as "vivacious Nord woman" with vampiric nature as background-only detail.
- **Carcette the Survivor (generic)** — vampire/Vigil references kept (fighting vampires is the Vigilants' public mission). Speech_style only.
- **Holds & civil war (Igmund, Hrongar, Brina, Vignar, Idolaf, Ralof, Yrsarald)** — public political stances + family feuds are open lore. Speech_style fixes only, no spoiler reframes.
- **Daedric victims (Sarthis Idren)** — public framings as quest hooks (skooma dealer, etc.) preserved. Speech_style only.

**Tier 4 — Class generics (89 new bios)**

Tier 4 covers class-level generic bios — every Hold guard shares one, every bandit shares another, every vampire another, etc. Changes here propagate to dozens of NPCs at once. The user requested specific behavioral tweaks for the bandit family on top of the standard speech_style fix.

**Bandit family with tier-scaled yield/surrender behavior** (13 bios):

User-driven design: bandits should be less death-wish, should surrender when they see a no-win situation, AND there should be variance so they don't all sound the same. But higher-tier bandits should resist more. Implemented as a 3-tier scale across the bandit hierarchy:

- **Base tier — `bandit_generic`** (rank-and-file outlaws). Self-preservation overrides bravado. Yields readily once a clear no-win emerges. Five sub-archetypes (opportunist / desperate / hot-head / weary veteran / cruel one — last one used sparingly) so individual bandits read as different people. Speech_style describes voice variation, profanity as situational not punctuation, surrender lines explicitly modeled ("I yield" / "Take the gold, just walk" / "Mercy, traveler") rather than defiant last words.
- **Mid-tier — lieutenants** (4 bios: bandit_lieutenant, bandit_chief_lieutenant, bandit_raid_lieutenant, bandit_lieutenant_overseer). Between recruit and chief — more to prove than a recruit, less to lose than a chief. Yields more readily than a chief, less than a recruit. Same archetype variance pattern.
- **High-tier — chief / leadership** (3 bios: bandit_chief_generic, bandit_ringleader_generic, bandit_reaver_lord_generic). Authority-driven resistance. Will fight harder, longer, through more pain than rank-and-file before yielding. Bargains from strength rather than collapsing into terror — "a chief who calmly proposes terms with their gang dying around them is in character; a chief who collapses into stammered terror is not."
- **Elite/named-archetype — zealot tier** (5 bios: bandit_exalted_lieutenant, bandit_frostborn_disciple, bandit_finger_of_the_mountain, bandit_daughter_of_the_hammer, bandit_woman_of_the_hammer). Identity bound up in title. Yielding framed as "spiritual collapse, not just tactical defeat" — most would rather die than be the [archetype] who folded. Still leaves narrow archetype-variance room for rare exceptions, but the default is "rarely yield."

Codex spot-check on the three tier representatives (base / chief / Frostborn Disciple): PASS on all three, tier-scaling clearly distinguishes panic-tier from authority-tier from zealot-tier.

**Hold guard generics** (17 bios): Speech_style fixes only — public faction roles. Each Hold's regional flavor preserved (Whiterun's "I used to be an adventurer" lineage, Riften's Maven-quieting pattern, Markarth's tense Forsworn-shadow undertone, Eastmarch's Stormcloak conviction, etc.) without using priming words.

**Faction soldiers** (26 bios): Imperial (10), Stormcloak (5), Dawnguard (3), Forsworn (8). Speech_style fixes. Forsworn explicitly NOT given yield/surrender language — they ARE zealots (Reachman tribal religion, generations of bitterness against Nord/Imperial conquest) and that's their character, not a failure mode to correct.

**Predator / criminal class generics** (33 bios): Vampires (basic + elite tiers), Necromancers (novice through master), Mercenaries (East Empire, Black-Briar, Silver-Blood), Hunters (including Old Orc with culturally-accurate death-seeking PRESERVED — that's Malacath's tradition, not a death-wish bandit pattern), Thieves, Alik'r warriors, Orc raiders, Afflicted (Peryite cultists). Speech_style + minor reframes; vampire/necromancer class identity is the bio's class trait (not a spoiler).

**Tier 5 — Long-tail spoilers-first sweep (322 new bios)**

Tier 5 covers the remaining spoiler-bearing bios across the long tail — every bio whose `summary` block leaks forward-looking quest material, regardless of whether the NPC is named, generic, modded, or vanilla. Strategy was **Option A (spoilers-first)**: chase the spoiler vector, skip pure speech-style-only bios for now. Speech-style-only bios (~830 remaining) can be picked up in a Tier 6 / Option C full mechanical sweep if prioritized later.

Triage produced 339 spoiler-bearing bios across the sub-categories. Processed in 10 parallel agent batches across 2 waves:

**Wave 1 (5 batches, 154 bios)**:
- **S1-A / S1-B — supernatural reveals (~60 bios)**: hidden vampires, werewolves, lycanthropes among townsfolk and stranded NPCs. Major reframe targets: Saadia (Hammerfell noble identity stripped), Movarth Piquine, Hert/Hern (Half-Moon Mill vampires).
- **S1-C — hidden-identity reveals**: Sybille Stentor (Solitude court vampire reframed to Court Wizard role), Sam Guevenne (Sanguine in disguise — divine reveal stripped), the Nerevarine (Indoril Nerevar / Dagoth Ur reveals stripped to Dunmer warrior framing), Vyrthur, corrupt_agent, Bloodchill Manor staff.
- **S2-A / S2-B — supernatural + Solstheim hidden identities**: thrall/cattle types kept frank (in-faction), vampire naturalists kept open. Major reveals processed: Eltrys (Forsworn conspiracy investigator with impending death NOT spoiled in summary), Korrilan, Eldawyn, Aringoth (Aretino skooma identity), Balagog gro-Nolob — the Gourmet (public-facing chef in summary, Listener-of-the-Dark-Brotherhood / cookbook author context in background), Vendil Severin (Morag Tong assassination team identity reframed).

**Wave 2 (5 batches, 168 bios written + 17 false-positive skips)**:
- **S2-C — supernatural reveals third batch (33 bios)**: Volkihar in-faction NPCs kept frank, Falkreath hidden vampire (Raven) reframed to wealthy patron, Hunters of Hircine kept frank (in-faction), Sinding (lycanthropy moved to background, jail context preserved), Bloodchill Manor staff (Tilde / Vori — held as cover-staff with vampirism in background).
- **S3 — faction allegiance reveals (25 bios)**: Dark Brotherhood members reframed by cover persona (Mion, Vayne, Morrigan, Safia, etc.), DB initiates met inside the Sanctuary kept frank (player is Listener at that point), Thalmor agents kept frank when public (high_elf_*, thalmor_sentry, estormo, armion) and tightened when undercover (Captain Valmir cover identity); Nightingales (Llewellyn / Lyra / Pyrus / Zin Wythering) — all false positives, "Nightingale" was a stage name, surname, or self-styled epithet.
- **S4-A — Dragonborn references first half (49 bios)**: townsfolk whose summaries assumed player-as-Dragonborn, Auryen Morellus (4 FormIDs — Legacy of the Dragonborn curator with player-as-guildmaster relationship sanitized; "Dragonborn Gallery" institution name preserved as proper noun), Sovngarde heroes (Felldir / Hakon / Gormlaith) kept dragon-war-explicit but no Dragonborn-pre-spoiler, Helgen survivors with "the great black dragon" framing, Whiterun Watchtower guards reframed.
- **S4-B — Dragonborn references second half (49 bios)**: museum guards group treatment (10+ near-identical entries handled consistently), dragon NPCs kept dragon framing (Mirmulnir / Sahloknir / Nahagliiv / Odahviing / Vuljotnaak / Viinturuth / Silah) with player-pre-knowledge stripped, **Nerien** (Psijic Order spoiler reframing — first impression now "robed Altmer mystic of unclear origin"), **Shavari** (Thalmor assassin — assassination contract specifics moved out of aspirations/relationships), modded-NPC Dragonborn dependencies cleaned.
- **S5 — misc spoilers (29 bios, 12 written + 17 skipped as false positives)**: most `thane_ref` hits were public-title noise (Thane Charlotte, Thane Eirfa Four-Shoes — title literally in name). Real fixes on Bryling, Dengeir, Irnskar, Jordis, Gregor, Markus, Engar (player-as-Thane reframings + speech_style); Kjar, Lagdu, Svetlana (speech_style only with backstory betrayal kept); Pelagius the Suspicious (speech-only, paranoia preserved as character trait); Stig Salt-Plank (meta-bribe hint cleaned).

**Codex spot-check on Tier 5 representatives**: ran `codex exec` over a 10-sample cross-section (nerien, captain_valmir, raven, auryen_morellus_33F, klimmek, pelagius, nahagliiv, shavari, felldir, armion). Verdict: 7 PASS, 2 CONCERN, 1 FAIL. Patched the 3 flagged bios:

- **captain_valmir_5B7** (FAIL): `occupation` block was leaking the undercover Thalmor reveal explicitly ("Outwardly: ... Actually: an undercover Thalmor agent..."). Rewrote occupation to public-facing captain-at-camp persona only; aspirations reframed away from "advance Thalmor power" / "avoid exposure as a Thalmor spy" toward task-and-cover language; relationships reordered so Thalmor superiors became "his real superiors (private)" trailing entry rather than lead.
- **nerien_CC9** (CONCERN): relationships block had "The dragon-blooded warrior: Subject of prophecy and evaluation" as the lead entry. Removed; replaced with generic "Mortals of unusual potential: Watched, evaluated, and only ever addressed when the moment demands it."
- **shavari_E22** (CONCERN): aspirations + relationships blocks surfaced the active assassination contract too directly (Esbern as secondary target, target-as-Dragonborn-embarrassment). Reframed aspirations to "close her current high-priority assignment cleanly," removed Esbern entirely from relationships, trimmed `interject_summary` references.

After patches: all 10 sample bios PASS on spoiler containment + playability + speech style. Codex confirmed no `{% endml %}` typos across the sample — block markers all balanced.

**Tier 6 — Long-tail speech-style mechanical sweep (840 new bios)**

Tier 6 closes out the audit by sweeping every remaining bio whose `speech_style` block had priming language but whose `summary` had no spoilers (Tier 5 already swept the spoilers). Triage produced 840 bios across 14 batches of 60. Pattern distribution: 727 with `clipped`, 133 with `terse`, 77 with `blunt`, 13 misc (`brusque`, `concise/direct`, `short/sharp`, `minimal_sentences`, `economy_of_words`).

Processed in two stages:

**Stage 1 — Parallel agents (Wave 1 + partial Wave 2, 474 bios)**: 9 agents dispatched across batches T6-01 through T6-10, each with 60 bios. Wave 1 finished cleanly (T6-01 through T6-05, 300 bios). Wave 2 finished partially (T6-06: 36/60, T6-07: 36/60, T6-08: 30/60, T6-09: 32/60, T6-10: 40/60) before the org's monthly Anthropic API usage limit cut off the remaining work mid-flight. Agent rewrites are bespoke per character — accent, register, profession, mood preserved while the priming is removed and anti-priming language ("full sentences with their joints intact" / "complete thoughts, never chopped" / "compact but complete") is integrated into the existing voice.

**Stage 2 — Mechanical Python fallback (366 bios)**: Wrote a regex-driven script (`t6_finish.py`) that does pattern-based substitutions (`clipped` → `compact`, `terse` → `economical`, `blunt` → `plain`, deletes `Example: "..."` quoted bait, etc.) and appends a standardized anti-priming clause: "Sentences keep their joints intact — full thoughts, even when brief, never reduced to chopped fragments." Skips any file that already has an override (preserves agent work). Ran in seconds; covered the unfinished tail of T6-06 through T6-10 plus all of T6-11 through T6-14.

The mechanical pass is meaningfully more formulaic than the agent pass — Codex's QA observed that "agent passes integrate the anti-priming into character voice, while mechanical passes often read like the original sentence plus a standard clause." Acceptable tradeoff for the long tail of obscure modded NPCs that may rarely be encountered in play.

**Codex spot-check on Tier 6 representatives** (10-sample mix of agent + mechanical): 7 PASS, 2 CONCERN, 1 sampling miss (I gave Codex a non-existent filename). Both CONCERNs are mechanical-pass bios with residual priming-**adjacent** language that wasn't in the regex set — `paratus_decimius_41B` keeps "sentences more fragmented" (stress-response description), `patrizia_4CA` keeps "trail off into mumbles." These are situational behavioral descriptions, not blanket cadence directives, and the standardized anti-priming clause counters them. Documented as known soft-priming tail residue rather than re-processed.

No primary priming language (`clipped` / `terse` / `blunt` / `Example: "..."` quoted bait) survives in any of the 1363 deployed overrides per Codex's sample and per a final scan. Block markers all balanced (1 `{% endml %}` typo introduced by an agent on `kauanne_generic` was caught by the post-processing scan and patched).

**Total bios audited across all 6 tiers**: 1,363 (Tier 1: 55, Tier 2: 27, Tier 3: 30, Tier 4: 89, Tier 5: 322, Tier 6: 840).
**Audit coverage**: ~43% of the 3,146 SkyrimNet character bios. The remaining ~1,800 are the bios that were already clean on both the speech_style and summary axes — no priming language in speech_style, no forward-looking spoilers in summary — and don't need overrides.

The Tier 4 batch is the highest-leverage of the audit — each generic bio touches dozens to hundreds of NPCs at runtime via SkyrimNet's character resolution. Editing `bandit_generic` once changes how every rank-and-file bandit speaks across the whole game.

**Codex spot-check** on Tier 2 sample (Calixto / Sapphire / Vingalmo): three "concerns" returned, all false alarms — Codex's PowerShell terminal misread the UTF-8 em-dash bytes as mojibake (verified clean via Python byte inspection), and Codex's "spoiler material now in background" objection is exactly the documented pattern from the handoff doc. The interject_summary edit on Calixto was justified — original framing told the LLM to volunteer murder-adjacent commentary unprompted, which is itself a leak path.

**What's still pending**:
- Long-tail generic bios (1,272 flagged — bandits, generic guards, generic merchants, lower priority)
- A `Bios` FOMOD module if the user decides to ship publicly. Currently the override files live in the repo at `Bios/` but aren't included in `build_fomod_zip.ps1`.

Documented in detail at `handoff_bio_audit.md` (repo root) for future-session continuity. The handoff covers the full failure-mode taxonomy, replacement vocabulary, workflow, and explicit guardrails on what NOT to do.

This is a parallel deliverable to the dialogue-prompt fixes — neither blocks the other, neither requires the other. The bios layer their effect on top of any prompt-level dialogue guidance.

### Dialogue Anti-Patterns — Stripped In-Context Examples

Hypothesis-driven trim of the BAD/GOOD example pairs in `0505_severactions_personality.prompt`. The previous structure listed each anti-pattern with a `BAD: "..."` and `GOOD: "..."` quoted illustration — useful for human readers, but documented few-shot leakage means LLMs sometimes reproduce surface features of in-context examples regardless of the negative label, especially when the BAD example happens to align with a specific character's voice (terse Dremora, clipped guards, etc.). Observed in playtesting: a Dremora character whose own bio described "clipped, philosophical" speech started producing Tough-Guy One-Liner-shaped output, with the model pattern-matching against the prompt's BAD examples that demonstrated exactly that shape.

Removed all BAD example quotations across 11 anti-patterns. Kept the anti-pattern names (which are evocative pegs the model can hang behavior on) and rewrote each entry as descriptive prose explaining the failure mode. Where the name alone is genuinely ambiguous (Faux-Archaic Filter, Therapy Voice), kept short representative phrases inline as illustrations, not full sentences. Net effect: ~30% token reduction on this prompt, and removal of the strongest cadence-priming surface forms.

The "When You Are the Engaged Speaker" section had a BAD/GOOD example pair built around a real playtesting failure ("A Dremora. Of course you do." — the Daegon scene). Replaced with descriptive prose that captures the same lesson without giving the model two sample lines to pattern-match against.

The 0550 cross-reference that mentioned "uses BAD/GOOD examples to show substance" was updated to "describes substance" since the examples are now gone.

This is a hypothesis worth testing in play. If dialogue quality regresses (model loses its grip on what specific anti-patterns mean without examples), examples can be added back selectively — they're in git history. If it stays good or improves, we've also freed token budget for other prompt work.

Validated via `mcp__skyrimnet__validate_prompt` → `{"valid": true}`. No template syntax changes.

### Off-Screen Life — World Setting Inclusion + Active-Follower Exclusion

Two related fixes to off-screen life event generation:

**Issue #8 (kiloughs) — World setting now flows through to off-screen events.** Added `{{ render_template("submodules\\system_head\\0010_setting") }}` to the system block of `sever_offscreen_life.prompt`. SkyrimNet's `0010_setting.prompt` is the file users replace to inject their own world-tone, genre, NSFW preferences, or conversion-mod context (Enderal etc.); previously off-screen events bypassed it entirely and would happily generate vanilla-Skyrim flavor regardless of whatever bespoke setting the user had configured for live dialogue. Now matches the same pattern SkyrimNet uses in `character_profile_update`, `dynamic_bio_update`, `generate_profile`, and `generate_memory` — single line, no behavior change for users who haven't customized 0010_setting (the default base file is just a `# Setting` header).

**User-reported (Severause) — "events sometimes mention an NPC who's currently with the player".** Symptom: off-screen prompt fires for dismissed-with-home Lydia, LLM writes "Lydia and Jenassa shared dinner at the Bannered Mare" while Jenassa is actively following the player elsewhere. Root cause: the prompt's `socialGraph` (sourced from SkyrimNet's `GetRelatedActors` PublicAPI) includes ALL NPCs the subject has interacted with — past companions, faction contacts, the player's spouse, currently-active followers — without filtering. The LLM picks any of these names as a plausible co-actor for shared events. The existing `nearbyFollowers` array was correctly filtered to dismissed-only (line 869 of `OffScreenLifeDataStore::Papyrus_BuildContext`), but the LLM had access to the broader socialGraph and would draw on it.

Two-layer fix in `OffScreenLifeDataStore::Papyrus_BuildContext`:
- **Build `activeFollowers` array** of NPCs currently traveling with the player (FollowerStore entries with `isFollower=true`, alive, not the subject themselves) and pass it into the prompt context. Lowercased name set retained for filtering.
- **Filter socialGraph** entries against the active-follower lowercase set so currently-following NPCs no longer appear as social connections in the prompt at all. Case-insensitive match handles BSFixedString case quirks. If filtering empties the graph, drop the field entirely instead of passing `[]`.

Prompt-side changes in `sever_offscreen_life.prompt`:
- New "NPCs currently traveling WITH {player}" section in the system block listing the excluded names with explicit "do not write events that involve, reference, mention, or imply contact with any of them" instruction.
- Tightened the existing nearbyFollowers shared-event guidance: shared events MAY ONLY involve names from the dismissed-companions-nearby list. If no plausible co-actor is in that list, the LLM must write a solo event instead of inventing a partner from socialGraph or memory.

Net effect: shared events are constrained to the same dismissed-followers-with-homes list the player can see in PrismaUI's Companions page. NPCs the player can currently see standing next to them never show up as off-screen co-actors. Solo events for affected followers when no dismissed peer lives in the same hold (the existing solo-event path is unchanged — `nearbyFollowers` was already a positive filter).

Validated via `mcp__skyrimnet__validate_prompt` → `{"valid": true}`.

### Outfit Actions — `0410_equipment.prompt` rebased on SkyrimNet Beta19

User-reported (issue #7, dimadetroit): the override copy of `0410_equipment.prompt` in `Actions/Outfit/` shipped a snapshot taken one day before SkyrimNet Beta19 released. SkyrimNet Beta19 renamed the in-scope variable from `npc.UUID` → `actorUUID` in `character_bio` submodules, but our override still used `npc.UUID` in the first block. Result was ~32 missing-variable warnings per session in `SkyrimNet.log` (`'npc.UUID' not found at line 1844:47`, plus cascading `item.formID` / `item.equipment_slot` / `item.slot_body_area` warnings as Inja's graceful error handler rendered the empty equipment iteration). In-game behavior wasn't visibly broken, but the LLM context was missing equipment information for the affected actors, subtly degrading roleplay accuracy.

Fix: replaced 4 occurrences of `npc.UUID` with `actorUUID` in the first block (the `full / thoughts / transform / equipment / action` render-mode branch). All five SeverActions-specific improvements preserved — `render_mode == "action"` extension, `original_name` lookup via `get_item_customization(item.formID).originalName`, parenthesized `(original_name)` display, and the "ground truth" disclaimer. The second block (`dialogue_target`) was already correct (uses `responseTarget.UUID`) and didn't need changes.

Validated against the live SkyrimNet context engine — `mcp__skyrimnet__validate_prompt` returns `{"valid": true}`. Affected installs see the warnings stop appearing on the next prompt render after the fix lands.

### Convenient Horses 7.1 — Multi-Follower Conflict Fix

User-reported (issue #6, dimadetroit): with Convenient Horses 7.1 + AE Patch active and SA's `severactions` framework mode, recruiting Companion #2 would auto-dismiss Companion #1 within ~5 seconds. Doesn't reproduce without CH or with Convenient Horses With MCM v5.1 (a different mod). The 3-mod handshake breaks like this:

1. SA recruits NPC #1 via `dfScript.SetFollower(NPC1)` → vanilla `pFollowerAlias.ForceRefTo(NPC1)` → engine adds NPC1 to `CurrentFollowerFaction` (CFF) via the alias's CK auto-management config
2. CH 7.1's `chfollowerquestscript.OnUpdate` polls every 5s, scans `DialogueFollower` aliases 0-19, captures NPC1 via `localAlias.ForceRefTo(NPC1)` into its own CHFollowerAliasScript slot. The slot enters `Horseless` state and starts a 2s polling loop
3. SA recruits NPC #2 via `dfScript.SetFollower(NPC2)` → `pFollowerAlias.ForceRefTo(NPC2)` silently evicts NPC1 from the alias, and the engine auto-removes NPC1 from CFF
4. Within 2s, CH's `Horseless.OnUpdate` evaluates `GetFollowerRecruited()` = `FollowerRef.IsInFaction(CurrentFollowerFaction)` = false → calls `Clear()` on its alias → `OnFollowerRemoved()` → `FollowerRef.SetPlayerTeammate(GetFollowerRecruited())` = `SetPlayerTeammate(false)` on NPC1
5. SA's native `TeammateMonitor` catches the SetPlayerTeammate(false), fires `SeverActions_NativeTeammateRemoved`, the Papyrus handler queues NPC1 in `PendingDismissActor` and registers a 2.5s confirmation update
6. 2.5s later, OnUpdate confirms `!IsPlayerTeammate()` → `UnregisterFollower(NPC1)`. Total elapsed from NPC2 recruit: ~4.5s, matches the user's reported timing

**Fix**: in `SeverActions_FollowerManager.psc::RegisterFollower`, immediately after `RecruitViaVanillaDialogue(akActor)` runs in the non-NFF path, iterate `GetAllFollowers()` and re-add every prior SA-managed follower (≠ akActor) to `CurrentFollowerFaction` if their rank is < 0. This restores the CFF membership the alias auto-management evicted, so CH 7.1 (and any other mod gating "is recruited?" on CFF) keeps treating prior followers as recruited. ~20 lines, no-op when no prior followers exist (single-follower scenario unaffected). Track-only followers (SPID/EFF/NFF/custom) are untouched — they don't go through `RecruitViaVanillaDialogue` in the first place.

**Why this approach over alternatives**: independently verified by Codex against the same code — restoring CFF fixes the cause, not just the symptom (vs. a grace-period filter on `OnNativeTeammateRemoved`, which would mask the dismiss but leave NPC1 with stale `SetPlayerTeammate(false)` state). Skipping `dfScript.SetFollower()` entirely for subsequent recruits would also stop the eviction but break vanilla follower dialogue topics ("Follow me / Wait / Dismiss") and prevent CH from discovering the new follower at all — wider compat regression than the original bug.

**Affected saves**: existing saves where NPC1 already got dismissed before the patch landed will need a one-time re-recruit. Subsequent recruits won't re-trigger the dismiss.

### Outfit Builder Save → Auto-Apply + Auto-Map Standard Situations

User-reported (Oldcustard): "I'm seeing a few instances of followers wearing their default outfit on cell load, this is in a home cell. They don't seem to auto-switch." Log triage on the user's `SeverActionsNative.log` traced the chain to two compounding gaps that share the same root cause — the user had defined preset slots and added items to chests, but never **applied** any preset.

**The two gaps:**

1. **No locked items.** The cell-load enforcement in `OutfitDataStore` only fires for actors that have `lockedItems` set. `lockedItems` are populated when a preset is *applied* (Apply Preset button or the equivalent action), not when it's merely *saved* (chest filled, name registered). Followers with saved-but-never-applied presets had no lock on cell load → engine equipped DefaultOutfit → followers in default attire.
2. **No situation→preset mapping.** `SituationMonitor::SendSituationEvent` reads `outfitStore->GetSituationPreset(actorFormID, sitCopy)`. If the user named their preset "Home" but never separately mapped `home` situation → `Home` preset, this returns empty and the auto-switch silently no-ops. The user reasonably expected naming a preset "Home" to be sufficient.

Both gaps were silent — no log line told the user what was missing. Confirmed by grepping the log for `setSituationPreset` and `Auto-switching` events: zero of either fired in 30 minutes of gameplay despite SituationMonitor correctly detecting `home` transitions for 10 followers.

**Three changes:**

1. **`buildOutfitSavePreset` (`Native/src/MagelightActionHandler.h`) → save AND apply.** After the existing save-to-OutfitDataStore step and the `SeverActions_MagelightBuilderSavePreset` ModEvent that registers the preset in the slot system, the action now calls `outfitStore->ApplyPresetNative(actor, presetName)`. Same shared equip+lock+suppress-DefaultOutfit path used by the Apply button and SituationMonitor's auto-switch. Strips current armor, equips new items, locks them, sets active preset, suppresses DefaultOutfit, naked-recovery if equip fails. Builder workflow inherently means "I want to see this on her right now" — there's no longer a split between save and apply for the builder.

2. **New `SeverActions_MagelightBuilderSaveAndApply` ModEvent + Papyrus handler.** Mirrors the existing `OnPrismaBuilderEquip` StorageUtil-sync logic (rebuild lock FormList, set `SeverOutfit_LockActive=1`, track actor, ResumeOutfitLock, restore stashed items) but **preserves the active preset name**. `OnPrismaBuilderEquip` clears it (correct for ad-hoc manual outfits, wrong for named-preset save-and-apply). Without this, StorageUtil's active preset would diverge from the native store's `activePresetName` set by `ApplyPresetNative`. Three sibling handlers now exist: `OnPrismaBuilderEquip` (manual outfit, clears name), `OnPrismaBuilderSaveAndApply` (named preset, preserves name), `OnPrismaBuilderSavePreset` (legacy save-only, unchanged).

3. **Auto-map standard situation names in `buildOutfitSavePreset`.** When a saved preset's normalized name matches a known situation (`home` / `town` / `adventure` / `sleep`) AND no situation→preset mapping exists for that situation yet, the system creates the mapping automatically. Won't override a user's existing mapping (respects intent). Fires the same `SeverActions_MagelightSetSitPreset` ModEvent the explicit mapping action uses, so OutfitSlotStore + StorageUtil stay in sync. Closes the second half of Oldcustard's gap — even with apply working, auto-switch still needed the situation map.

4. **`SituationMonitor` diagnostic trace** (`Native/src/SituationMonitor.h`). When a follower's situation transitions but no preset mapping is configured, the monitor now logs:
   ```
   SituationMonitor: <Name> (FormID) transitioned to '<situation>' but no preset mapping configured — skipping auto-switch
   ```
   Self-debugging breadcrumb so future "auto-switch isn't working" reports trace immediately to the right gap (detection vs mapping vs apply).

**Net user experience after the change:** open builder → pick items → Save with name "Home" → follower is wearing the Home outfit immediately, the lock is committed, the situation map `home → home` is auto-created. Next time they enter a home cell, SituationMonitor fires `Auto-switching <Name> to 'home' for situation 'home'`. No second Apply step, no separate Map Situations step.

### Auto-Assign a Bed When a Home Is Set

User-requested (Kromryl): "Are bed assignments still being looked at? I'm reworking a few things including how homes are assigned, so I could also auto-assign an empty bed for them to actually use (assuming there's any available)."

When `AssignHome(follower, locationName)` runs, the system now scans the player's current cell for a usable bed and sets the follower as its OWNR. The follower's home sandbox sleep package finds the claimed bed at sleep hours and uses it. On `ClearHome` (or re-AssignHome to a new cell, or permanent dismiss via cosave revert), the original owner is restored — no phantom OWNR left behind.

**Bed-claim filter (in priority order):**

| Bed owner | Claim? | Reason |
|---|---|---|
| Unowned | ✅ Claim | Free for the taking |
| Specific named NPC | ❌ Skip | Don't steal personal beds |
| PlayerFaction (`0x000DB1`) | ❌ Skip | Player home — vanilla housecarl/spouse sharing already works |
| Inn faction | ✅ Claim | Per design — assigning an inn as home means renting a bed there |
| Other faction | ✅ Claim | Generic NPC factions, mod-added shared beds |

Preference order when multiple candidates exist: unowned > faction-owned. Less disruptive choice wins.

**Implementation:**

- **`Native/src/BedAssignment.h`** (new, ~200 lines) — `ClaimBedForFollower(follower, cell)`, `ReleaseBedForFollower(follower)`, `FindBestBedInCell(...)`. Bed detection via furniture-keyword check (`FurnitureBedRoll` / `IsBedRoll`) plus an editorID heuristic fallback for modded beds without standard keywords. Releases any previous claim before claiming a new one, so re-AssignHome to a different cell cleanly transfers the OWNR.
- **`Native/src/FollowerDataStore.h`** — `FollowerData` extended with `homeBedFormID` + `homeBedOriginalOwnerFormID`. Cosave bumped from v6 → v7. Both FormIDs go through `ResolveFormID` on load; if either fails (mod uninstalled, ref deleted), the field is reset to 0 — no dangling claim.
- **`Native/src/papyrus.cpp`** — registers `Native_BedAssignment_Claim`, `Native_BedAssignment_Release`, `Native_BedAssignment_GetBedFormID` on the SeverActionsNative script.
- **`SeverActions_FollowerManager.psc::AssignHome`** — calls `Native_BedAssignment_Claim(akActor)` after the home marker is moved to the player's position. Returns false silently if no usable bed is in the cell — follower will sleep on the floor or wherever the home sandbox finds, same as before.
- **`SeverActions_FollowerManager.psc::ClearHome`** — calls `Native_BedAssignment_Release(akActor)` first thing, before clearing home tracking, so the C++ side can read the bed FormID + original owner from FollowerDataStore (which still has the entry at this point) and restore the original OWNR cleanly.

**Track-only followers are NOT excluded.** Initial design proposed skipping custom AI keyword holders (Inigo, Lucien, Kaidan, Daegon-keyworded, etc.) on the theory that their mods manage sleep with custom packages. Reverted on user feedback: "If users assign them a home via my system, they'll have my package, so they should use a bed." If the player explicitly invokes AssignHome on a custom AI follower, they're opting into SeverActions managing that aspect — claim the bed. Worst case for a custom AI follower whose mod still runs its own packages: the bed sits with our OWNR record harmlessly until ClearHome releases it. The release path doesn't gate on track-only either, so no leak risk.

### CompanionWait / CompanionFollow — Track-Only Follower Fix

User-reported (severause): testing the wheel-menu Wait/Resume Follow on a custom AI follower (Daegon, with the SPID `SeverActions_CustomAIFollower` keyword) revealed that the Wait command would correctly sandbox her (via her own mod's package handling), but pressing the wheel button again to resume following would silently force SeverActions's CK alias-based follow package onto her. From that point her own mod's dismiss couldn't remove the package, and SeverActions's Tracking-mode dismiss intentionally doesn't touch packages, so she was stuck.

**Root cause:** `CompanionWait(akActor)` and `CompanionFollow(akActor)` in `SeverActions_FollowerManager.psc` checked `IsRegisteredFollower(akActor)` but NOT `IsTrackOnlyFollower(akActor)`. For a Tracking-mode follower (custom AI keyword present), `IsRegisteredFollower` returns true (she's in the FollowerStore from her Tracking-mode recruit), so the wait path called `followSys.Sandbox(akActor)` and the follow path called `followSys.CompanionStartFollowing(akActor)` — both attaching SeverActions packages on top of her own mod's packages.

The same bug surfaced via three entry points, all of which funneled through these two functions: the LLM picking `companionwait.yaml` / `companionfollow.yaml` actions during dialogue, the wheel menu's `HandleWait` / `HandleFollowToggle`, and the `HandleCompanionWait` hotkey. Single fix covers all.

**Fix:** mirrors the `RegisterFollower` track-only branch — observe-only, no SA package attachment. For track-only followers:

1. **Recovery cleanup first.** Call `followSys.CompanionStopFollowing(akActor, false)` + `followSys.StopSandbox(akActor)`. Both are safe no-ops if no SA state exists; if a prior incorrect call already attached SA's sandbox or alias-based follow package (the bug condition), this releases it. Means existing stuck Daegons recover automatically on the next wheel press — no console workaround needed.
2. **Toggle the vanilla wait flag.** `SetAV("WaitingForPlayer", 1)` for wait, `SetAV("WaitingForPlayer", 0)` for follow, then `EvaluatePackage`. The custom AI follower's own follow package respects this standard flag via the vanilla DialogueFollower hooks, so the follower transitions cleanly between wait and follow behavior under their mod's control.

Vanilla followers are unchanged — they still go through `followSys.Sandbox(akActor)` for wait and `followSys.CompanionStartFollowing(akActor)` for resume, exactly as before.

**Coverage check:** every voice/wheel/hotkey/LLM path that lets the player tell a follower to wait or resume now goes through these two patched functions. No remaining gap where a custom AI follower could pick up an SA package.

---

## v2.9.5

### Key Features

📍 **Cross-Cell Follower Teleport** — Catch-up teleport now actually fires when followers get separated by doors, exterior cell boundaries, and dungeon transitions. Previously the same-cell guard skipped exactly those cases — i.e. the most common "lost follower" scenario.

🩹 **v2.1.7 Aggression Self-Heal** — The reverted-but-not-undone v2.1.7 `AttackTarget` bug stuck the player's `Aggression` actor value at 2, causing nearby Calm-disposition NPCs to flee/cower on sight. v2.9.5 detects and resets it silently on every save load. Affected saves heal themselves the first time you load after installing.

---

### Outfit System Fixes

- **Delete preset preserved blacklisted items** — `ClearPreset` previously called `akActor.UnequipAll()`, which has no filter and stripped blacklisted gear too — directly violating the "never touch blacklisted items" contract. Replaced with a new `UnequipAllExceptBlacklisted` helper that walks worn armor via `Native_Outfit_GetWornArmor`, checks each piece against `Native_Blacklist_IsBlacklisted`, and only unequips non-blacklisted items. Same call site in `ClearPreset`, same observable behavior for non-blacklisted gear, blacklisted items now stay equipped through preset deletion as expected.
- **Outfit Builder rename support** — Pre-fix, renaming a preset in Edit mode orphaned the old name and created a duplicate under the new name with the same items. Full-stack fix: new C++ `OutfitDataStore::RenamePreset` (case-insensitive, preserves items + `activePresetName` + situation-mapping refs, rejects newName collisions), new C++ `OutfitSlotStore::RenamePresetByName` (preserves slot index, container, LvlItem, satchel, item count, catalog-supplied list — all slot-indexed not name-indexed). `buildOutfitSavePreset` action reads an optional `oldPreset` field; if present and CI-different from `preset`, runs the rename in both stores and fires `SeverActions_MagelightBuilderRenamePreset` ModEvent before falling through to the standard save (so item changes also persist under the new name in one click). New `OnPrismaBuilderRenamePreset` Papyrus handler copies the `SeverOutfit_<oldName>_<fid>` FormList to `<newName>_<fid>` and updates the per-actor StringList. Frontend Builder detects rename (CI compare against `editPresetName`) and dispatches with `oldPreset` populated; toast reads "Renamed X to Y" on rename vs. "Saved X" on save.
- **Slot orphan cleanup keeps NPCs with saved presets** — Pre-fix, building a preset on a non-follower NPC via "Save Preset" (not "Equip & Lock") wrote items to `OutfitDataStore` but did not set `lockActive`. The kPostLoadGame `ReleaseOrphanedSlots` pass criteria (`isFollower || hasExplicitLock`) failed for those NPCs, the slot got released on the next save reload, and `presetNames` / `containerFormIDs` were zeroed — while the OutfitDataStore presets (different store, untouched by orphan cleanup) survived. Symptom: PrismaUI page header showed "5 presets" against an empty slot grid, and `applyoutfitpreset` did nothing because the slot system's containers were gone. New `OutfitDataStore::HasPresets(actorID)` method (excludes synthetic `_*` names — same exclusion the UI uses) and the non-follower-lock checker in `main.cpp` now ORs `lockActive` with `HasPresets`. Any NPC the user has built outfits for survives orphan cleanup regardless of whether they were ever Equip-&-Lock'd. Existing already-orphaned saves recover by re-saving the preset; new presets persist correctly going forward.
- **Fuzzy preset name matching** — `FindPresetIndexByName` is now a two-tier ladder. Tier 1: exact CI match (preserves all prior behavior, always preferred). Tier 2: token-overlap fuzzy match — splits the query into whitespace tokens, drops stopwords (`the`, `your`, `for`, `and`, `some`, `something`, `wear`, `put`, `her`, `his`, `their`, `ours`) and tokens shorter than 3 chars, then bidirectional-prefix-checks each query token against each preset token (so `sexy` hits `sexy01`, and `sexy01` hits `sexy`). Multiple candidates → `Utility.RandomInt(0, n-1)` rolls between them. Use cases: naming presets `sexy01`/`sexy02`/`sexy03` and saying "wear something sexy" rolls between them randomly (variety-pack pattern); "wear your office outfit" matches a preset named `office attire` even when the user can't remember the full name. New helpers `TokenizeAndFilter`, `IsFillerToken`, `CountNonEmptyTokens`, `AnyTokenOverlap` live alongside `FindPresetIndexByName` in `SeverActions_OutfitSlot.psc`.

---

### Follower Catch-Up Teleport

- **Cross-cell teleport** — `SandboxManager::ProcessFollowerTeleports` now branches on cell match. Same cell + over distance threshold: existing `SetPosition` path (SMP-safe — 350u behind player's facing, no cell transition, no physics reset). Different cell: `actor->MoveTo(player)` — accepts SMP physics reset (hair/cloak pop) since the 3D was reloading anyway when the follower caught up via vanilla AI. Distance math is meaningless across cells (interiors have their own coordinate space), so the cross-cell branch teleports unconditionally subject to the global cooldown. Pre-fix, the same-cell guard skipped every cross-cell case — exactly the scenarios users actually notice (door transitions, exterior cell boundaries, dungeon-room hops). The same global cooldown (default 30s) gates both paths.
- **Teleport settings persist across game restarts** — Pre-fix, the PrismaUI Teleport Distance slider wrote to PluginConfig but `SandboxManager` never read it back at boot, so the C++ value reset to hardcoded defaults (2000u / 30s) on every restart regardless of what the user had set. The PrismaUI dashboard read from PluginConfig and displayed the saved value, so it *looked* like settings persisted while the actual gating reverted. Fix: new Papyrus property `Int Property TeleportCooldownSeconds = 30 Auto` on `SeverActions_FollowerManager`, new `SandboxManager::SyncFromPluginConfig()` reads `FollowerTeleportDistance` + `TeleportCooldownSeconds` from the FollowerManager script via VM, called via deferred `AddTask` at `kPostLoadGame`/`kNewGame` so script bindings have settled. `MagelightSettingsHandler` writes the cooldown to Papyrus alongside the in-memory write. `MagelightDataGatherer` reads cooldown from Papyrus (single source of truth for restart persistence).

---

### Dialogue Prompt Revision — Three-Pass Overhaul

User feedback: brevity is good but sometimes responses are *too* short — NPCs in 1-on-1 dialogue being asked direct questions were giving 5-word reactions that left nothing to push back against. Triggered a multi-pass review of the two SeverActions dialogue prompts (`0505_severactions_personality.prompt`, `0550_severactions_conversation_flow.prompt`) that ended up substantially expanding both, then reconciling the additions against shipping SkyrimNet base prompts to remove contradictions.

**Pass 1 — Brevity counterweight.** Both dialogue prompts had stacked brevity rules with no counterweight for the engaged-speaker case. Every "GOOD" example in `0505`'s anti-pattern catalog was 0–7 words — correct for the bystander/subordinate/threatened-Jarl framings they were paired with, but the model learned "GOOD = short" with no example of an engaged speaker actually contributing. And `0550` had four cumulative shrink-rules ("people tend to say less, not more," "Don't fixate," "Not everything deserves a response," "give a short closing line and stop") that individually were correct correctives but stacked into universal "say almost nothing" pressure. Added a "When You Are the Engaged Speaker" section to `0505` and a "Brevity vs. Substance" section to `0550`, both using a real failure case from playtesting ("A Dremora. Of course you do.") as the BAD anchor.

**Pass 2 — Codex review (broad).** Ran a 21-item review against both prompts focused on missing dimensions, overlooked anti-patterns, structural critique, and risks in the new additions. Adopted everything:
- **5 new anti-patterns added to `0505`'s catalog**: The Lore Brochure (UESP-style exposition dumps), The Faux-Archaic Filter ("indeed, traveler"-style fantasy varnish on every line), The Player-Centered Orbit (auto-mythologizing the player), The Therapy Voice (modern emotionally-fluent counsellor-speak), The Proper-Noun Drumroll (stacked named entities for trailer-voiceover weight). Each gets a BAD/GOOD pair plus a one-line guidance.
- **Sharpened the omniscience guard** at the top of `0505`: explicit framing that system knowledge (inventory, quests, faction state) shapes attitude but does NOT make the NPC omniscient. Don't reference items the player hasn't shown you, don't quote quest progress they haven't told you about, don't allude to faction membership not mentioned in your presence.
- **Tightened the "ordinary doesn't mean random" rule** to prevent the brevity counterweight from reintroducing aimless chatter.
- **Reformatted narrated-action GOOD examples** (Mutual Threat Stage Direction, Loyal Lieutenant Trope) to spoken-only lines plus parenthetical scene-design explanations — the previous prose-narration examples could leak as output templates.
- **Added a blunter GOOD example** to the engaged-speaker section alongside the writerly one — substance can be polished or rough; both are valid as long as it's not a wall.
- **Compressed the Brevity vs. Substance section in `0550`** to a precedence rule + an explicit definition of "engaged" (directly addressed, directly challenged, responsible for the decision, or uniquely positioned to know — otherwise you're a bystander), plus two guardrails ("don't ask a follow-up every turn — one opinion OR one question is usually enough"; "volunteer related context only if it changes the immediate choice, feeling, or relationship").
- **Narrowed the No Meta-Commentary rule** to OOC turn-management only — in-world boundary-setting ("Keep your private matters private") is now explicitly allowed.
- **Tightened the Overhearing rule** to "Default to silence" with named exceptions (duties, safety, loyalties, reputation), instead of the previous "you may respond once."
- **New "Other Honest Failures" section** in `0550` covering six dimensions the prompts didn't address: Unknowns/uncertainty (NPCs allowed to plainly not know things), Disagreement/refusal (without escalating into a speech), Wrong beliefs (NPCs allowed to be biased/superstitious/mistaken in-character), Humor calibration (dry, brief, situational, not performed for applause), Privacy/taboo/pain (allowed to deflect or end a line), Out-of-world questions (answer from character's frame of reference or reject the premise).

**Pass 3 — Reconcile against shipping SkyrimNet base prompts.** Pulled MinLL/SkyrimNet-GamePlugin's currently shipping `system_head/0010_instructions`, `system_head/0020_format_rules`, `system_head/0400_speech_style_bio`, `guidelines/0500_roleplay_guidelines`, `user_final_instructions/0500_response_format`, `user_final_instructions/0700_extra_instructions`, and `dialogue_response.prompt`, and diffed against our additions. Codex did a second pass on the same comparison. Four contradictions surfaced — all resolved on our side (no SkyrimNet base modifications):

- **Length cap**: SkyrimNet's `0020_format_rules` caps non-combat dialogue at 1-3 sentences (60 words max). Our engaged-speaker GOOD examples were 4-5 sentences. Compressed both examples to ≤3 sentences, ~17-19 words each. Added "say it within the active length limits set by the base format rules" to the engaged-speaker closing instruction so the model doesn't read our "have something to say" as license to ignore base length caps.
- **Narration ban**: Our `0550` line 7 said "you are not writing prose, narrating actions, or describing body language — you are talking." SkyrimNet's `0500_response_format` explicitly allows asterisk-wrapped narration in non-thoughts modes when narration is enabled. Reframed our line from absolute ban to deference: "Default to actual speech, not prose. If the base format rules allow brief narration or asterisk-wrapped action for this render mode, keep it secondary and minimal — speech is the main channel, narration is flavor." The "Stacked Dramatic Chorus" anti-pattern in `0505` is unaffected since that's about excessive narration not banning it.
- **Silence vs. advance**: SkyrimNet's `0500_response_format` ends with "Each response must advance the conversation — new question, detail, realization, or decision." Our `0550` had multiple "default to silence / not everything deserves a response" rules. Two-part reconciliation: (a) added explicit clarifier under "Brevity vs. Substance" that the advance rule applies *to the response you produce* — when our prompt says be silent, the correct output is no response at all, not a manufactured advance to satisfy the rule; (b) tightened the Overhearing line to "Default to silence **when unaddressed**" with an inline note that no-output doesn't conflict with the advance rule.
- **Small talk vs. logical next step**: Our `0505` license to "make small talk that goes nowhere" and "repeat themselves" conflicted with SkyrimNet's "introduce a logical next step." Rewrote the small-talk paragraph to keep the "ordinary is fine" license but bridge to the advance rule: "every generated response turn should still add something — a fresh reaction, a small choice, a relational signal, a redirection. Ordinary doesn't mean random."

**What we deliberately kept.** Codex suggested ultra-compressed GOOD examples ("A Dremora. You said that like weather. Bound, then?" — 9 words, 3 sentences). Within length caps, but we kept the slightly longer versions (~17-19 words, 2-3 sentences) because Codex's compression collapses back into the bystander-brevity register the engaged-speaker section was designed to correct against. Our versions still demonstrate substantive engagement (skepticism, follow-up, push-back) without breaking length caps.

**Architecture is now contradiction-clean.** SkyrimNet base owns length, format, narration mechanics, `<internal_thought>` tags, and the "must advance" rule; SeverActions overrides own voice nuance, anti-patterns, engaged-speaker substance, multi-NPC etiquette, and overhearing scope. Every place our overrides could be misread as overriding base rules now has a deference clause or explicit reconciliation. None of these edits modify base SkyrimNet — all changes stayed on our side.

---

### Player State Healing

- **v2.1.7 player aggression auto-fix** — `SeverActions_Init::Initialize` now reads the player's `Aggression` actor value at the top of every `OnPlayerLoadGame` (and first-time `OnInit`), and resets it to 0 if non-zero. The v2.1.7 `AttackTarget` change had bumped both attacker AND target aggression — when the player was the target, their value got stuck at 2 ("Very Aggressive"), which causes Calm-disposition NPCs to flee/cower on sight. The cause was reverted in v2.1.8 but the corrupted Aggression value persists in saves until something explicitly overwrites it with 0. The reset is gated on `currentAggression > 0.0` so healthy saves are silent (no log spam, no redundant `SetActorValue` call). Affected saves get one diagnostic line: `[SeverActions] Healed corrupted player aggression: X -> 0`. NPCs that already fled may need a cell reload (fast travel out and back, or a few cell transitions) to re-evaluate their AI from the corrected state.

---

## v2.9

### Key Features

👗 **Outfit Slot System (NFF-style)** — Each managed follower gets a dedicated slot with up to 8 named outfit presets. Each preset is backed by a real in-game container so items physically live somewhere instead of just being remembered as FormIDs. Build presets from the PrismaUI catalog, from items the follower already owns, or both — catalog items live in the chest until applied; items the follower already owned stay in their inventory permanently and just equip/unequip between presets. Auto-switches outfits by situation (adventure / town / home / sleep), survives save/load reliably via SKSE cosave (replaces the old StorageUtil string approach), and plays nicely with custom-follower mods that ship their own outfit-enforcement systems.

🪄 **CastSpell Action — Animated NPC Casting** — New action that lets NPCs actually charge and release spells with proper animation, instead of magic appearing from nowhere. The LLM names a spell the NPC knows, optionally picks a target (named actor, "self", or aimed-no-target), and the engine's combat-AI cast pipeline runs the cast through to projectile spawn. Restoration spells auto-repeat until the target is fully healed or the caster runs out of magicka. Up to 4 concurrent casts at once.

🛠️ **Daegon Kaekiri Compat Patch** — Standalone MO2 mod patch (ships separately, not in the FOMOD) that lets the new outfit slot system coexist with Daegon's three-script outfit-enforcement system. Without it her default clothes always come back; with it, presets apply cleanly and her custom outfit container is restored on slot release.

---

### Outfit Slot System — Detail

A wardrobe-based design that replaces the old fight-the-engine unequip-loop pattern.

**How it works**

- Up to **50 followers managed concurrently**, each in their own numbered slot (0-49).
- Each slot has **8 preset bays**, each backed by a baked-in `BGSOutfit` + `LeveledItem` + `ObjectReference` chest container — 400 (slot × preset) triplets in `SeverActions.esp`.
- Apply flow mirrors NFF's `SwitchOutfit`: stow personal items to a satchel, swap the actor's `DefaultOutfit` to the preset's outfit, and let the engine itself enforce the outfit on every cell load. No re-equip loop, no lost races against `DefaultOutfit` rebuilds.
- **Per-item ownership tracking**:
  - **Catalog-supplied items** (added from the UI catalog) live in the chest. A temp copy is issued to the actor on apply, deleted on swap-out.
  - **User-owned items** (already in actor's inventory at build time) stay in inventory. The chest holds a marker only. Equip/unequip between presets, never delete.
  - Mixed presets work — build "Daedric set" from catalog + the actor's existing favorite ring, and the ring stays in their inventory forever.
- **Situation auto-switch** — each slot has a situation→preset map. When `SituationMonitor` flips a follower's situation (adventure → town → home → sleep), the engine auto-applies the matching preset.
- **Scene awareness** — SexLab/OStim animations flip a global flag that suspends all outfit re-equip system-wide, so NPCs don't flicker back into armor mid-scene.
- **Custom-follower compat** — detects guardian outfit containers from mods like `k101Daegon.esp`, stows their contents on apply, restores on slot release. Old system fought these and lost.

**Persistence**

- Cosave record `'OSLT' v3` — assignedActor, presetNames, presetItemCounts, containerFormIDs, originalDefaultOutfit, situationToPresetIdx, guardianContainerIDs, catalogSuppliedItems.
- Transactional load — stages to local containers, commits only on full successful read. Truncated/corrupt cosave returns to clean Revert state instead of half-loading.
- v2 saves load forward-compat with empty catalog lists (treats all items as user-owned, the safer fallback).
- Case-flip defense — Skyrim's `BSFixedString` pool sometimes flips case mid-flow (`"daedric"` → `"DAEDRIC"` after the engine interns an armor keyword). All preset-name comparisons go through a unified C++/Papyrus `NormalizePresetName` (lowercase + trim + strips LLM filler like `" outfit"`/`" gear"`/`" set"`) and `StringUtils::EqualsCI`.

**Ad-hoc actions don't fight presets**

Dress / Undress / EquipItemByName / UnequipItemByName / EquipMultipleItems / UnequipMultipleItems and the PrismaUI Catalog Equip & Lock / Unequip actions all call `ClearActivePresetForAdHoc` first. Without this, the slot system's alias would silently undo the LLM-driven outfit change two seconds later.

**PrismaUI Outfits page**

Now served entirely from C++ via `OutfitSlotStore` and `OutfitDataStore`. Slot index, active preset index, and per-bay name + item count populate directly into the page JSON. Old Papyrus fallback path returned `None` half the time due to script timing — gone.

**Diagnostics**

`DirectEquip` logs PRE-APPLY / POST-APPLY armor counts with a `[delta=N]` flag and emits `WARDROBE PATTERN VIOLATED` to the SKSE log if a non-preset armor leaks in or out, so any regression surfaces immediately.

---

### CastSpell Action — Detail

Drives the engine's combat-AI cast pipeline so NPCs visibly charge and release spells via the same animation path the engine uses in normal combat.

**How it works**

- 4 reusable cast slots (caster + target alias pairs) — up to 4 concurrent casts before the dispatcher reports "too busy".
- Slots own pre-built `UseMagic` AI packages. The package's Spell slot is rewritten at runtime so a single package scaffold can cast any spell the LLM names.
- Each cast clones the source spell into a fresh runtime `SpellItem` (drops perk gates, forces `EitherHand` equip), so Requiem-distributed hand-locked spell variants still cast cleanly via the procedure.
- **Heal-to-full loop** — Restoration spells re-dispatch automatically until the target reaches `GetActorValueMax("Health")` (respects Fortify Health buffs) or the caster runs out of magicka.
- Self-target via the `"self"` keyword; aimed-no-target via an auto-placed XMarker 120 units in front of the caster (lets NPCs fire a spell at training dummies, corpses, or whatever they're looking at).
- Polling state machine on the alias detects animation start, in-flight charge, and stuck-charge recovery — if the engine leaves the caster stuck in `ChargeLoop`, the watchdog force-releases the anim graph via `MLh/MRh_SpellRelease_Event`.

**Eligibility**

Only outside combat (so it doesn't fight existing AI cast logic) and only when the actor isn't currently in a SexLab/OStim animation scene.

**Action params**

- `spellName` — must be a spell the NPC actually knows. Resolved via `SpellDB::FindSpellOnActor` (exact → prefix → contains → Levenshtein) against the actor's known spell list, then routed through their unrestricted variant if one exists.
- `targetName` — display name of an actor, `"self"` for self-cast, or `"0"` / empty for aimed.
- `bDualCasting`, `bHealToFull`, `bUseMagicka` — static parameters set by the action YAML.

---

### Smaller Things

- **ForcedCombatMonitor — AttackTarget auto-cleanup** — new C++ `TESCombatEvent` sink that fires `SeverActions_ForcedCombatEnded` ModEvent the moment a forced-combat actor exits combat. Papyrus then runs `FullCleanup` (restores Confidence, removes attack/target faction, clears StorageUtil keys, clears native InForcedCombat flag). Fixes the lingering-aggressive-state bug where dismissed followers would walk off and re-engage other NPCs because their attack-faction membership and Confidence boost from `AttackTarget` were never reverted on natural combat end (only on explicit Ceasefire/Yield calls).
- **Follower friendly-fire hostility prevention** — four-layer defense against followers attacking each other when one's stray AoE / arrow / cloak / fireball clips the other. **Layer 1 (ESP)**: `SeverActions_FollowerFaction` declares itself Friendly to itself, so the engine treats intra-faction hits as non-hostile at the faction-reaction level. **Layer 2 (Papyrus)**: `RegisterFollower` and Maintenance call `Actor.IgnoreFriendlyHits(true)` on every SeverActions follower so the actor-level flag tells combat AI to ignore friendly-source damage. **Layer 3 (C++ TESHitEvent)**: synchronous 1-HP floor on intra-follower hits + target-aware combat cancel. **Layer 4 (C++ TESCombatEvent)**: catches the case Layers 1-3 miss — hostile-flagged spells (Firebolt etc.) bypass faction friendliness and IgnoreFriendlyHits because the engine routes them through a separate combat-AI scoring path. The new combat-event sink fires at the exact moment the engine flips two followers hostile to each other, then routes through the same `CancelIntraFollowerCombat` guard as the hit path — only stops combat when the actor's CURRENT combat target IS the other follower, so a follower in legitimate combat with a real enemy isn't disrupted by a stray splash from an ally. Skipped entirely when either party is `InForcedCombat` (so deliberate AttackTarget actions still work).
- **CastSpell delivery-type guidance** — expanded the action description and `spellName` / `targetName` parameter docs in `castspell.yaml` to explicitly tell the LLM that self-delivered spells (`Healing`, `Oakflesh`) ignore the target argument and only ever affect the caster. Now when the LLM wants to heal someone other than the caster it picks `Healing Hands` / `Close Wounds` / `Grand Healing` (touch / aimed / AoE), and the cast actually lands on the intended target instead of silently self-casting.
- **Cheaper-model routing for background prompts** — re-added the SkyrimNet plugin manifest at `00 Core/SKSE/Plugins/SkyrimNet/config/plugins/SeverActions/manifest.yaml` declaring a single `sever_background` LLM variant. All six of our background `SendCustomPromptToLLM` calls (relationship assessment, reputation blurb, inter-follower opinions, banter director, off-screen life, quest awareness summaries) now route through that variant. Configure it from SkyrimNet's WebUI → Plugins page — set a custom endpoint / API key / model / temperature / max tokens / timeout to point all six prompts at a cheaper or local model and save tokens on the dialogue tier; leave it empty to inherit your base OpenRouter config (no behavior change). Live dialogue is unaffected — it still uses your main model.
- **`StopFollowing` action casing fix** — `stopfollowing.yaml` had `executionFunctionName: stopfollowing` while the Papyrus function is `StopFollowing`. Papyrus is case-insensitive at runtime so manual paths (hotkey, wheel, GameDataExplorer) worked, but SkyrimNet's `QuestScriptManager` does case-sensitive symbol lookup against the VM's function table — so any LLM-driven invocation reported `function does not exist` and the action silently failed. YAML now matches the script casing.
- **Arrest aggression/confidence restore** — `PerformArrest` and `ApplyDispatchArrestEffects` now snapshot the prisoner's pre-arrest Aggression and Confidence before zeroing them. Release paths (`ReleaseFromJailCore`, `ReleasePrisoner`) call a new `RestorePrisonerStats` helper that puts the originals back via `SetAV`. Previously the release path used `RestoreAV("Aggression", 100)` which was the wrong API for a base attribute and silently did nothing — bandits walked out of jail permanently pacified, hostile NPCs walked out friendly to everyone. Also dropped the redundant `Aggression=2` bump on guards in `HandleResistArrest` (vanilla guards baseline at 1 and `StartCombat` is sufficient; the bump risked persistence on abnormal combat-end).
- **PrismaUI Outfits page wired to slot system** — slot index, active preset, and the 8 named preset bays now populate directly from `OutfitSlotStore` in C++ (~5-20 ms vs the broken Papyrus fallback's variable latency).
- **Spookys CLI outfit-slot generator** — `scripts/generate_outfit_slots.ps1` builds the 50 × 8 preset records on `SeverActions.esp` deterministically. Replaces the xEdit script for record-creation reliability.
- **Action selector prompt** — clarified the "category vs direct action" rules and added an explicit example response line so the LLM consistently includes the required `intent` parameter when picking a category.
- **Magic category description** — updated to mention casting alongside teach / learn.
- **`.gitignore`** — excludes `*.bak.*` timestamped ESP backups and `.claude/scheduled_tasks.lock` so they stop showing as untracked.

---

## v2.7.0

### Key Features

🛡️ **Possible Cowering Fix** — A few overlapping issues that could contribute to followers or random NPCs cowering during combat have been addressed. Not a guaranteed fix since the symptom has multiple paths in the engine, but the known contributors on our side are now cleaned up.

🧠 **Familiarity Cleanup** — World knowledge about you (lore entries, witnessed events, seeded facts) now appears exactly once in every dialogue prompt instead of twice. NPCs still know everything they knew before, the LLM just stops getting the same facts double-fed and over-weighting them in responses.

💬 **Prompt Stack Simplified** — Trimmed our SkyrimNet prompt overrides down to only what's needed for SeverActions' own action pipeline. The COMPANION / ENGAGED / IN SCENE tag logic now lives in an additive submodule that extends the speaker selector instead of replacing it — your MCM/PrismaUI toggles for those tags still work identically.

🔧 **PrismaUI Survival Page Fix** — The Cold settings box on the Survival page was clipping off the right edge of the three-column grid, hiding its Enabled toggle. CSS updated so Hunger / Fatigue / Cold all fit cleanly within the viewport regardless of window size.

📦 **FOMOD Installer Fix** — The installer's `Enhanced Target Selectors` option still referenced the `Prompts/TargetSelectors` folder after both prompts inside it were removed during the prompt-stack simplification. Mod managers reported a "folder not found" warning at install time. The dead option has been removed from `ModuleConfig.xml` and the empty folder pruned; installation is now clean.

See the `v2.5` section below for the detailed technical breakdown of the cowering hunt, familiarity dedup, and prompt-stack cleanup changes that ship in this release.

## v2.5

### Cowering Regression Hunt — Multi-Layer Fix
Users reported NPCs (including followers during fights) randomly cowering starting with v2.1.7. The issue persisted in v2.5 despite the 2.1.7 AIO-patch rebuild, so the root cause wasn't just one thing. A deep audit of the ESP, AIO patch, and combat script against user-reported symptoms found three independent contributors, each addressed below.

- **AIO patch rebuilt against the user's actual AI Overhaul ESP** — previous patch was generated against a different AIO variant (author `mnikjom SpiderAkiraC`, different file size). It contained two "ghost" override records (`AIOFleeSeverinFamily` at `59720E` and `AIOFleeFromDragons` at `5CED5E`) that didn't exist in the user's installed AIO, so those overrides were injecting orphan records rather than overriding anything. Also lost a condition on `AIOFleeFromCreatures` (our source had 7 OR-flagged creature conditions, LoreRim's has 8). Spec file (`xEdit Scripts/aio-severactions-patch.psd1`) now points at LoreRim's AIO and declares only the 5 records that exist across AIO variants. Patch size: 7991 → 4653 bytes
- **V2 follow template (`SeverActions_FollowPlayerTemplate`, FormID `155C91`) condition refs repaired** — the `b4717ab` commit cloned NFF's 27-entry procedure tree (Close/Standard/Far radii + Flee sub-procedure) but didn't remaster the FormID references inside the CTDA condition blocks. 1 GLOB comparison-value ref and 8 FACT parameter-1 refs pointed at FormIDs that don't exist in `SeverActions.esp` (they were NFF local IDs pasted as self-references). At runtime those conditions evaluated unpredictably, which could fire the Flee sub-procedure on followers during combat. Mapped to SeverActions equivalents via a new binary-patch script `xEdit Scripts/patch-v2-follow-conditions.ps1`: GLOB `0x030F5D30` → new `SeverActions_FleeDistance` (Float, value 12.0, matches NFF's `nwsFleeDistance`); FACT `0x03004352` → existing `SeverActions_FollowerFaction` (`0EB708`)
- **2.1.7 Confidence/Aggression changes reverted** — the 2.1.7 addition of `Aggression=2` in `PrepareForCombat` + `StoreOriginalValues(akTarget)` + `PrepareForCombat(akTarget)` was intended to fix "civilians don't fight back when attacked" but introduced the possibility of stuck elevated Aggression values when combat terminates abnormally. Reverted to pre-2.1.7 behavior: `PrepareForCombat` only sets Confidence=3 on the attacker; `AttackTarget_Execute` no longer value-manipulates the target (`StartCombat` + relationship rank -4 is sufficient); `StoreOriginalValues`/`RestoreOriginalValues` only track Confidence. Ceasefire/yield aggression paths are pre-existing pre-2.1.7 logic, left untouched
- **Kept (unrelated to the revert)** — `SeverActions_AttackFaction` / `SeverActions_TargetFaction` property declarations and add/remove logic. The AIO flee-suppression patch gates on these factions to turn off flee packages for in-combat actors; they must remain toggled around forced-combat windows
- **Known tradeoff from the revert** — Cowardly NPCs (Confidence=0 base) and Unaggressive NPCs (Aggression=0 base) may no longer fight back when `AttackTarget` is used on them. If reported, a per-action opt-in or a separate "forced combat intensity" setting can restore it

### ESP Structural Cleanup
- **Persistent flag set on 120 schedule-system XMarkers** — 40 home + 40 work + 40 relax markers added in the schedule-system commit (`eabf3c3`) were placed in `GRUP Cell Persistent Children` groups without the Persistent flag (xEdit integrity warning on every one). Engine was lenient at runtime but save/load edge cases could misbehave. New idempotent binary-patch script `xEdit Scripts/set-persistent-flag.ps1` walks the ESP, locates every `REFR`/`ACHR` under a type-8 GRUP, and OR's the `0x400` bit into its flags field (record layout unchanged, no size shifts). 172/172 REFRs now correctly flagged
- **5 orphan records deleted** — all confirmed unreferenced in scripts, native code, or other records: `nwsFollowerFollowPKGDUPLICATE001` (`155C92`), `nwsFollowerFollowPTDUPLICATE001` (`155C90`), `SeverActions_UseMagicPackage` (`020E4F`), `SkyrimNet_FollowPlayerPackage` (`000E8E`), `SkyrimNet_FollowPlayerPackageTemplate` (`000E8D`). Saved ~10.9 KB on the ESP and removed xEdit integrity noise
- **Master list reorder** — Mutagen (the spookys-automod backend) had alphabetized masters on a prior toolkit pass, putting `Skyrim.esm` at index 2 instead of 0. Manually reordered in xEdit back to conventional order (`Skyrim.esm` first). Also confirmed that `Update.esm` and `HearthFires.esm` — which Mutagen stripped as "unreferenced" — genuinely weren't referenced by any internal FormID in the ESP, so their removal is structurally clean. The `HearthFires.esm` references in `Native/src/NearbySearch.h`, `PropertyOwnership.h`, and `RecipeDB.h` resolve at runtime via SKSE's `LookupForm<T>(formID, pluginName)` and don't need master entries
- **New `SeverActions_FleeDistance` Global** — added (`155D0F`, Float, value 12.0) to support the V2 follow template fix

### Prompt Stack — Override Cleanup + Additive Submodule
In preparation for SkyrimNet's upcoming prompt refactor, trimmed the set of SkyrimNet-base prompt overrides to only the three that actually need to be overridden (action-pipeline adapters). The remaining eight overrides' 2.1.7/2.2/2.5-era fixes targeted specific bugs in old SkyrimNet prompt versions that the refactored base will handle natively; keeping stale overrides after their refactor would lock us to worse logic than upstream.

- **Removed 8 override prompts**:
  - `dialogue_response.prompt` (DialogueStyle) — listener framing / third-person narration fix, superseded
  - `submodules/system_head/0010_instructions.prompt` (DialogueStyle) — listener framing across render modes, superseded
  - `submodules/system_head/0010_setting.prompt` (DialogueStyle) — world-framing override that hard-coded vanilla Skyrim lore, fighting conversion mods like Enderal; let SkyrimNet handle this default
  - `submodules/system_head/0020_format_rules.prompt` (DialogueStyle) — word/sentence caps per render mode, superseded
  - `submodules/system_head/0400_roleplay_guidelines.prompt` (DialogueStyle) — narration gating, superseded
  - `submodules/guidelines/0900_response_format.prompt` (DialogueStyle) — format rules / narration escape hatch, superseded
  - `target_selectors/dialogue_speaker_selector.prompt` (TargetSelectors) — replaced by the new additive submodule below
  - `target_selectors/player_dialogue_target_selector.prompt` (TargetSelectors) — superseded by SkyrimNet's updated target selector
- **Kept 3 intentional overrides** (Core, action-pipeline): `native_action_selector.prompt`, `native_action_selector_drilldown.prompt`, `submodules/user_final_instructions/0750_embedded_actions.prompt`. These directly orchestrate SeverActions' custom YAML actions and must stay in sync with our action schema; will be diffed and re-ported when SkyrimNet refactors them
- ~~**New additive submodule — `submodules/character_bio/0311_severactions_interject_hints.prompt`**~~ — staged in early v3.5 then **reverted before ship** (pending design changes; full PR #145). The previous `dialogue_speaker_selector` override behavior currently has no SeverActions replacement and will be revisited.
- **Group Meeting Awareness rewritten on SkyrimNet primitives** — `0260_severactions_engaged_participants.prompt` no longer depends on the `SeverActions_ActivelyFollowing` faction. Party detection now uses `is_follower(uuid)` + `is_in_package(uuid, "SkyrimNet_PlayerFollowPackage")` from SkyrimNet's own decorators (requires SkyrimNet build with [MinLL/SkyrimNet#807](https://github.com/MinLL/SkyrimNet/pull/807) merged for the new `is_in_package` / `get_speaker_selector_settings` surface). Tag vocabulary now mirrors upstream's `dialogue_speaker_selector.prompt`: `[COMPANION]` / `[ENGAGED]` / `[IN SCENE]` so the LLM sees one consistent ontology across selector and per-NPC system_head renders. In-scene party members surface in a dedicated sub-list with explicit "do not address" guidance (mirrors upstream "Strongly deprioritize"). Player-in-scene case handled. Block gates on the dashboard's `dialogue.speakerSelector.tagEngaged` toggle so global preferences carry through.
- **DialogueStyle FOMOD module is now purely additive** — contains only `submodules/guidelines/0550_severactions_conversation_flow.prompt` and `submodules/system_head/0505_severactions_personality.prompt`, both SeverActions-original content

### Familiarity Prompt — World Knowledge Deduplication
- **Removed `get_world_knowledge` call from `0045_severactions_familiarity.prompt`** — SkyrimNet's own conditional-knowledge prompt already injects world knowledge per-character in the LLM context, and our familiarity prompt was rendering it a second time. Net effect was the same facts appearing twice in every dialogue prompt, bloating token count and (based on anecdotal reports) causing LLMs to over-weight those facts in their responses
- **Preserved in `sever_reputation_assess.prompt`** — the per-NPC impression blurb is still generated with `get_world_knowledge(npcUUID)` + `get_relevant_memories(3)` + prior blurb as raw material, so everything an NPC "knows" still gets distilled into their personal take. Live dialogue renders only the distilled blurb; the raw world-knowledge facts come through once via SkyrimNet's own path
- **Net effect**: each piece of world knowledge appears exactly once in the LLM context per dialogue — once as raw facts (via SkyrimNet's conditional-knowledge injection) and indirectly shaped into the NPC's blurb (interpretive). No more duplication

### Follower Friendly-Fire Prevention (New)
Opt-out toggle on the PrismaUI Settings page (default **ON**) that prevents follower-vs-follower combat from escalating. Three cooperating layers address the three ways friendly fire bleeds through Skyrim's vanilla protections.

- **Ally-hit aggro thresholds raised** — Skyrim's `iAllyHitCombatAllowed` (default 3) and `iAllyHitNonCombatAllowed` (default 0) game settings count hits from "friend" actors before flipping target aggression. Raised to 100 / 50 when the toggle is on, restored to defaults when off. Applied on toggle change and re-applied on game load from Maintenance (game settings aren't cosaved). Side effect: bandit-on-bandit aggro also takes longer, which is invisible in practice
- **Periodic `IgnoreFriendlyHits(true)` refresh** — the flag we already set on recruit can drop during AI state transitions (combat↔sandbox, dismiss/recruit, save/load edge cases). New `RefreshFriendlyFireFlags()` iterates `GetAllFollowers()` every 30s in the existing OnUpdate tick and re-stamps the flag. No-op when toggle is off
- **HP-floor damage refund** — new C++ `FriendlyFireMonitor` singleton (TESHitEvent sink) catches every hit and, when both aggressor and target are in `SeverActions_FollowerFaction`, clamps the target's post-hit HP at a minimum of 1. Damage still applies (bleedout/stagger visuals preserved), but allies can't outright kill each other. Synchronous with the event handler so the floor lands in the same frame as the damage. Covers AoE spells, stray arrows, cloak procs, and other cases where the `IgnoreFriendlyHits` flag fails. Engine caveat: true one-shot kills where damage brings HP to exactly 0 can still trigger the engine's death state before our floor applies — the 1-HP floor catches the common case but isn't a hard guarantee without a perk or SKSE damage hook
- **Defaults-on for new installs, explicit off preserved for opt-outs** — StorageUtil default is `1`. Users who never touched the setting get protection; users who explicitly toggled it off keep their `0`
- **Files**: new `Native/src/FriendlyFireMonitor.h`, plugin/papyrus wiring in `plugin.cpp` / `papyrus.cpp`, settings handler + data gatherer hooks, `FriendlyFireMonitor_SetEnabled` / `_IsEnabled` natives in `SeverActionsNative.psc`, `OnFriendlyFireToggle` event + Maintenance restore in `SeverActions_Follow.psc`, `RefreshFriendlyFireFlags()` in `SeverActions_FollowerManager.psc`

### Outfit Builder Overhaul
- **Full biped-slot coverage** — the builder now exposes every Skyrim slot 30 through 60 (bits 0-30), up from 18 slots. Items on modded slots like Mouth (44), Misc (48), Leg (53), Leg 2 (54), Chest 2 (56), Shoulder (57), Arm (58), Arm 2 (59), FX01 (60) are now reachable. `ArmorCatalog::SlotMaskToString` and the "Currently Worn" labeler in `getWornArmor` both expanded to name these slots; previously anything outside bits 0-13 / 15-17 / 19 displayed as "Other" or an empty "None"
- **"All Slots" button at the top of the slot grid, selected by default on open** — the builder now jumps straight into browsing every playable armor the moment it opens. Select an item and it gets keyed by its own `slotMask` (not a fixed button mask), with automatic conflict resolution: picking a new item drops any previously selected item whose slot bits overlap, so the preview panel stays accurate without double-equip states
- **Specific-slot grid is collapsed by default** — a dashed "▼ Show specific slots" toggle below "All Slots" reveals the full 30-button grid for fine-tuning. State resets to collapsed every time the menu closes (React unmount), matching the intended "advanced UI stays hidden" UX
- **Pelvis 2 (biped slot 52) hidden everywhere** — slot used by NSFW genital/underwear body mods (SoS, CBPC, etc.) that users shouldn't need to manage from here. Filtered out of: the builder slot grid, catalog search results (`QueryArmor` server-side skip), and the Currently Worn panel. The Undress action still strips slot 52 intentionally
- **Undress action expanded from 18 → 26 slots** — now strips the newly-labeled slots 44 / 48 / 53 / 54 / 56 / 58 / 59 / 60 along with everything it stripped before. Addresses a user-reported bug where gear on slots 53, 54, and 58 wouldn't come off with the dress/undress actions. Intentional exclusions preserved: slots 31 (Hair), 38 (Calves), 41 (LongHair) to protect wigs, and 50 / 51 (decapitation FX) since they're not real gear

### Dialogue Prompts — Consolidation
Rolled up user feedback about length rules stacking and redundant guidance accumulating across multiple prompts. All dialogue-pipeline prompts now have a single source of truth for each rule type.

- **New `0020_format_rules.prompt` override** (DialogueStyle FOMOD). Owns sentence/word caps for every render mode: combat (1 sentence, 14 words), dialogue (1-3 sentences, 60 words), thoughts (8-30 words), book (8-90), transform (8-45). All other SeverActions prompts stripped of their own length declarations
- **`0400_roleplay_guidelines.prompt` trimmed** — removed the "max 2-3 sentences" clause (→ moved to 0020) and the entire `inDirectConversation` narration block (→ 0900 handles it with richer examples). 0400 is now purely character-voice roleplay per render_mode, 67 → 44 lines
- **`0550_severactions_conversation_flow.prompt` slimmed** — from 7 pillars down to 5. Removed "Vary your rhythm" and "You don't always know what to say" (LLMs do these without instruction), "One thing at a time" (conflicts with per-character `speech_style` blocks; some characters genuinely stack thoughts), and "Don't narrate yourself" (→ 0900 owns narration gating). Sharpened **When to Stop** into a bulleted trigger list plus an explicit closing-line instruction — silence after a closing line is now explicitly labeled correct behavior, not a failure to respond
- **`0900_response_format.prompt`** — removed redundant "Speak in your natural voice, respond with your own thoughts" and "Do not echo what was said" lines (→ kept only in 0550). 0900 now strictly governs FORMAT (narration, asterisks, structure); 0550 owns CONTENT mechanics
- **`0260_severactions_engaged_participants.prompt`** (Follower copy; the GroupMeeting copy was removed entirely in PR #145) — stripped "1 sentence most of the time" / "1-2 sentences" / "2-3 sentences" clauses. 0260 keeps group-scene framing only ("not performing a scene", "Use names sparingly", "comfortable silence is valid"); length is 0020's job
- **`0600_severactions_dialogue_rules.prompt` deleted** — rule was "don't echo system/action text like `[item_given]`, gold totals, etc." Redundant with 0900's "Do not describe yourself, target, or anyone else — say it as speech or not at all" and modern LLMs rarely leak system text without prompting. Removed from repo, MO2, live, and zip

### Relationship Assessment — Event Leak Fix
- **Removed 3 `SkyrimNetApi.RegisterEvent` calls** in `SeverActions_FollowerManager.psc` (lines near 2813 / 3214 / 5376) that were writing mechanics text like `"Feris relationship assessed: rapport +3 trust +1"` and `"X inter-follower: Y(aff+2 res-1)"` directly into SkyrimNet's event stream. `get_recent_events` was surfacing those strings to the diary/memory LLM, which produced gameplay-meta entries like *"Feris's rapport went up after the armor. Uthgerd's went down."* in player diaries. Deleting the event writes stops the leak at the source. The in-character `SeverFollower_PlayerBlurb` and per-pair blurb storage paths are untouched — narrative-facing outputs still flow normally

### AI Overhaul Patch — Byte-Perfect Rebuild
- **`AIO-SeverActions-Patch.esp` rebuilt from scratch** via a new binary patcher script. The previous SeverForge-generated patch triggered an xEdit "Target is not persistent" warning because SeverForge (Mutagen-based) wrote masters in a non-standard order (Dawnguard → Dragonborn → Skyrim) and re-sorted the authored ANAM/UNAM data entries alphabetically by tag. The new patch copies the original AI Overhaul.esp flee packages byte-for-byte, translates FormID master indices to a standard-ordered master list (Skyrim → Dawnguard → Dragonborn → AI Overhaul → SeverActions), and appends our 3 `GetInFaction == 0` AND conditions at the end of each package's CTDA block. ESL flag / author / description preserved. xEdit Check-for-Errors now passes clean
- **Two underlying bug fixes carried over from the earlier SeverForge patch** (both already shipped in commit `4d23e4f`, re-verified in the rebuild): (1) third faction condition now references `SeverActions_TargetFaction` (0x150B8F), not the legacy unused `SeverActions_VictimFaction` (0x150B8E); (2) our AND conditions placed AFTER the original OR-chained creature/dragon checks, not before — prepending caused the first original OR-flagged condition to absorb our last AND into its OR group and evaluate as always-true, which had nuked the creature-detection gate entirely and caused merchants to cower constantly while IntelEngine-dispatched followers got stuck mid-travel
- **New `xEdit Scripts/esp-rebuild.ps1` + spec-file pattern** — reusable PowerShell library for byte-perfect ESP override patches. Takes a `.psd1` spec describing source ESP, output path, master list, TES4 metadata, and conditions to append per record. Drop-in build for the AIO case (`aio-severactions-patch.psd1`) reproduces the current patch byte-identically. README in `xEdit Scripts/` documents spec schema and current limitations (PACK records only, conditions always appended at end). Alternative to patching SeverForge upstream — gives byte-exact output for cases where Mutagen's canonicalization is the problem

### Action YAMLs — Mass Updates
- **SexLab / OStim faction checks converted from `is_in_faction` to `get_faction_rank < 0` across 62 action YAMLs** (124 condition blocks). `SexLabAnimatingFaction` and `OStimExcitementFaction` sometimes leave NPCs stuck at faction rank -1 after animations end (a "disabled" sentinel). `is_in_faction` treats rank -1 as true (still in the faction), which wrongly blocks actions for every NPC caught in that state. `get_faction_rank < 0` correctly treats both "not in faction" and "stuck at -1" as eligible, while rank ≥ 0 (actively animating) still fails the check. Fixes a class of bugs where dismissed-follower actions would stay gated even after the animation ended
- **Action-name casing fixes** — `companionfollow.yaml` (kept `CompanionFollow`), `learnspell.yaml` → lowercase `learnspell`, `stopfollowing.yaml` → lowercase `stopfollowing`. SkyrimNet's `RegisterPapyrusQuestActionInternal` function-info lookup appears to be case-sensitive per-action (not uniformly lowercase as the previous "action casing" commit assumed), and the right casing varies per-action based on load-order timing. Settled on empirical testing results: whatever case stopped the `PapyrusQuestAction: Could not get function info` log error for each specific YAML

### Immersion Triggers — Archived (pending revamp)
- **`Triggers/Immersion/` removed from the FOMOD** and moved to `archive/immersion-triggers/SKSE-tree/` for future revamp. The 12 event-driven triggers (Dragon Slain, Player Near Death, Companion Injured, Quest Completed, New City Arrival, Dungeon Entered, Night Travel, Player Commits Crime, Witnessed Crime, Powerful Enemy Slain, Player Uses Shout, Major Quest Diary) weren't where they needed to be for the next ship and are being pulled for a redesign pass. ModuleConfig.xml's "Trigger Modules (Event Reactions)" install step removed and Compatibility Patches / Adult Content pages renumbered. Archive README documents what was there and how to restore if needed

### Build & Tooling
- **`build_fomod_zip.ps1` excludes `*.bak` and `*.bak.*` files** — timestamped ESP backups produced by `esp`/patch tools were accidentally shipping in the FOMOD zip. Added to `$excludePatterns`. Zip dropped ~160 KB and got cleaner without losing anything the user needs

### Follower Schedule System (New)
Dismissed followers now follow a daily schedule, moving between home, work, and relax locations based on the in-game clock.

**Schedule hours (12-hour):**
- **Home** — 10:00 PM to 8:00 AM. Sandboxes at the assigned home; sleep triggers naturally via the existing `AllowSleeping` flag
- **Work** — 8:00 AM to 5:00 PM. Sandboxes at the player-assigned work location
- **Relax** — 5:00 PM to 10:00 PM. Sandboxes at the player-assigned relax location

**Design:**
- **No new packages, no new factions, no new CTDAs** — reuses the existing per-slot `HomeSandbox_NN` alias system. A background tick moves the follower's `HomeMarker_NN` between three anchor markers (`TrueHomeAnchor_NN`, `WorkMarker_NN`, `PlayMarker_NN`) at 8am / 5pm / 10pm boundaries. The HomeSandbox package keeps targeting HomeMarker — follower re-paths automatically with the same radius (1000) and flags (AllowSleeping, AllowSitting, AllowEating, AllowConversation, AllowIdleMarkers)
- **Work and relax are opt-in** — if no work location is set, the follower stays home during work hours (falls through to the home anchor). Same for relax. Followers without schedule data keep behaving exactly as they did in v2.2
- **Automatic migration for existing saves** — `TrueHomeAnchor_NN` syncs to the current HomeMarker position on first tick, so existing dismissed followers don't teleport when updating

**New PrismaUI ModEvents:**
- `SeverActions_MagelightSetWorkLoc` / `ClearWorkLoc` — assign or clear the follower's work location
- `SeverActions_MagelightSetPlayLoc` / `ClearPlayLoc` — same for play

**Technical:**
- 3 new FormLists (`WorkMarkerList`, `PlayMarkerList`, `TrueHomeAnchorList`) + 120 XMarkers (40 each) in the holding cell
- Schedule logic runs in Papyrus (`ProcessScheduleSwaps` called every 30s in the existing OnUpdate loop) — only teleports when the schedule type actually transitions
- Tunable hours via `SCHEDULE_WORK_START`/`_END` and `SCHEDULE_PLAY_START`/`_END` constants

### Follow Behavior
- **V2 tiered follow package** — replaced the vanilla single-radius follow template with an NFF-style procedure tree containing Close / Standard / Far radii + a Flee sub-procedure. Fixes the "backward teleport" snapping where followers would jerkily reposition when the player moved just outside the old template's single radius
- New `SeverActions_FollowPlayerTemplate` (27-entry procedure tree) and `SeverActions_FollowPlayerPackageV2` — attached to all 20 `FollowerSlot` aliases. The V2 condition preserves V1's contract (`GetActorValue("WaitingForPlayer") == 0`) so followers still respect the wait/sandbox state. V1 package kept in the ESP for rollback safety, detached from aliases

### PrismaUI
- **Fixed spell toggles not working for follower spells** — toggling a spell off for a follower used to snap back to "active" on the next UI refresh. Root cause: `HasSpell()` returns true for spells on the base NPC record even after `RemoveSpell()`, because the base spell list is immutable — only the runtime `addedSpells` list is modified. Player spells worked fine because they're mostly runtime-added (learned in-game)
- Fix: `BuildInventoryData` now cross-references the `disabledSpells` set from `FollowerDataStore` when computing the active flag. If a spell is in the disabled set, it reports inactive regardless of `HasSpell()`. Applies to both runtime `addedSpells` and base-record spell paths
- **New "Transfer Ownership" action on the Actions page** — wires the existing `TransferOwnership` action (previously only reachable via LLM dispatch / YAML) into a new `Property` action category on the PrismaUI Actions page. Target is the NPC giving ownership; the single text param is the property name (leave blank to default to the NPC's current location). Uses the shared-faction co-ownership path — both the player and the original owner retain access to beds, containers, and the home, so the giver doesn't lose their own place

### User Experience
- **Streamlined Companions page** — inline "Set Here" / "Clear" buttons next to each Home/Work/Relax row replace the crowded bottom button bar. Rare/destructive actions (Clear Packages, Soft Reset, Force Remove) moved to an overflow `⋮` menu. Same inline pattern applied to the Assigned NPCs section for consistency
- **Pause on Open toggle** — new entry in the Settings page's UI Display section: "Pause Game When Menu Opens" (default on, preserves legacy). When off, gameplay continues while the menu is open and Summon fires immediately instead of queuing until menu close
- **Summon + schedule config for dismissed followers** — the Assigned NPCs section (where dismissed homed followers live) now exposes a Summon button alongside the full Home/Work/Relax schedule config. No need to physically find a dismissed follower to reconfigure their routine or pull them to you
- **"Play" renamed to "Relax"** — clearer labeling for the 5pm–10pm leisure window on the Companions page. Internal references, save data, and ModEvent names untouched — pure display rename

### Dialogue Quality — SkyrimNet overrides
Three prompts from SkyrimNet's core dialogue pipeline are now shipped as SeverActions-side overrides (installed via the `DialogueStyle` FOMOD module at the same relative paths SkyrimNet uses — install SeverActions below SkyrimNet in MO2 to win the overwrite). Fixes NPCs producing third-person narration inside their dialogue turns (e.g. `"Dunmer merchant. Doesn't look like she's in the mood for small talk."` said as a reply *to* the Dunmer) and generic parrot-agreement patterns (`"She's not wrong." / "Aye, that's true."`).

- **`dialogue_response.prompt`** — strengthened listener framing. Adds a dedicated paragraph immediately after the speaker identity: *"You are speaking DIRECTLY TO X. Every word you produce is heard by X. Address them — do not describe them. You are IN A CONVERSATION, not narrating one."* Also appends a final-line reminder at the end of the user block: *"Your response will be HEARD BY X — speak TO them, not ABOUT them."*
- **`submodules/system_head/0010_instructions.prompt`** — unifies the listener-framing gates across `default` and `transform` render modes (the original only framed the listener in the default-dialogue branch, leaving `transform`-mode outputs without listener awareness). Replaces `"You are speaking to X"` with the directional `"Respond as Y, speaking directly to X. Your output is addressed to X and heard by them. Speak TO them; do not describe them."`
- **`submodules/system_head/0400_roleplay_guidelines.prompt`** — when a `responseTarget` is set (i.e. NPC is in a direct conversation), narration is forced OFF regardless of the user's `is_narration_enabled()` setting. Adds concrete BAD/PREFER examples in the rule block so the LLM can pattern-match against the actual failure mode. The narration-permit path still renders normally for ambient reactions and other non-conversation contexts
- **`submodules/guidelines/0900_response_format.prompt`** — closed the narration escape hatch that 0400 alone didn't catch. This prompt renders late in the stack and previously taught a 1-in-4 narration ratio plus a worked example (`"Hello." *she smiles.* "How are you?"`) that the LLM was pattern-matching even when 0400 forbade narration. Override applies the same `responseTarget` gate: in direct conversation, narration off; otherwise SkyrimNet's ambient rules unchanged
- **`submodules/guidelines/0600_severactions_dialogue_rules.prompt`** (adopted into tree) — this file prevents NPCs from echoing system/action text in dialogue (`"Hulda gave Bread to Aevar. That's the only loaf I've got whole."`). It was already shipped in some installs but orphaned from version control; now tracked as a proper SeverActions prompt
- **`submodules/system_head/0010_setting.prompt`** — strengthened the "Character Knowledge" block to match the v2.5 familiarity rework. Enumerates the four legitimate channels for an NPC to know something about the player (direct encounter, witnessed events, world-knowledge entries, memories) and explicitly rules out auto-knowing titles like Dragonborn, Harbinger, Arch-Mage, Listener, or Guild Master unless one of those channels delivered it
- Zero changes to SeverActions' own `DialogueStyle` prompts (`0550_severactions_conversation_flow.prompt`, `0505_severactions_personality.prompt`) — those were already correct; the issue was upstream-SkyrimNet rules contradicting them

### Dialogue Target Resolution
- **Speaker selector pivot rules** — expanded the targeting-rules block in `target_selectors/dialogue_speaker_selector.prompt` to explicitly permit NPCs pivoting their target back to the player after a brief NPC-to-NPC side-exchange. Previously the rule said only *"if two NPCs are mid-conversation, keep the target between them"* — which correctly preserves NPC-to-NPC flow but also suppressed legitimate pivots when an NPC's next line was actually directed at the player. New rules: NPC-to-NPC exchanges wind down after 2-3 back-and-forths; a speaker can pivot to `player` when the speaker's reason to speak is player-focused (reacting to player action, answering a prior player question, pulling player attention to something); output must always specify a target explicitly (`[speaker]>[target]`) — never output `[speaker]>` with nothing after, never leave the target ambiguous. Partially mitigates (but does not fully fix) a separate root-cause bug in SkyrimNet's `DialogueManager.cpp::GenerateResponse()` fallback where stale event `targetActorUUID` wins when the parsed target is incomplete. Proper fix requires an upstream SkyrimNet C++ patch

### Familiarity & Reputation
- **Removed hardcoded quest/guild fame** — the familiarity prompt no longer bakes in player guild progression (Harbinger, Arch-Mage, Guild Master, Listener), Main Quest milestones (High Hrothgar, Alduin, Dragonborn DLC), or quest-stage-driven knowledge gates. Facts about the player now reach NPCs **only** through three legitimate channels: entries authored in SkyrimNet's knowledge system (PrismaUI World page), memories an NPC actually has, or recent events they witnessed. NPCs no longer magically know the player climbed the 7000 Steps unless something put that knowledge in front of them
- **Integrated SkyrimNet's world-knowledge decorator** — the familiarity prompt now pulls `get_world_knowledge(actorUUID)` alongside the LLM-generated impression blurb. Conditional knowledge entries that a user authored (or SkyrimNet's semantic retrieval matches) surface as "what this NPC has heard / knows" context without manual wiring per guild
- **New blurb regen cadence** — the per-NPC impression blurb now regenerates after the **first dialogue exchange** and **every 100 lines** thereafter. Replaces the old tier-change + fame-change triggers (both removed). Decision moved from C++ to Papyrus so the StorageUtil-persisted blurb-at-count drives the check authoritatively across save/load
- **Blurb generator rewrite** — `sever_reputation_assess.prompt` now takes `get_world_knowledge` + `get_relevant_memories(3)` + prior blurb as raw material. The LLM is explicitly told not to invent facts outside those sources, so an NPC's impression reflects what they actually have reason to know (or not know). 287 → 97 lines
- **Familiarity prompt slimmed** — `0045_severactions_familiarity.prompt` dropped ~270 lines of quest-stage/fame calculations. Shared-guild framing is kept for relationship tone ("you're both in the Companions"), but guild titles only surface if a world-knowledge entry provides them. 450 → 185 lines
- **Dead code removal** — `SkyrimNetBridge.h` no longer caches the 24 fame-relevant quest pointers or tracks a player fame hash. Removed: `FameQuests` struct, `PlayerFameCache`, `InitializeFameQuests()`, `SafeQuestStage()`, `RefreshPlayerFame()`, plus the `fameHash` / `pendingFire` fields on `FamiliarityState`. Net: -170 lines of C++
- **New Papyrus-callable Natives**: `Native_GetFamiliarityInteractions(Actor) → Int` (current line count) and `Native_QueueReputationAssessment(Actor)` (enqueue + fire event). These support the Papyrus-side milestone check in `OnFamiliarityTimestamp`

### Safe-Interior Auto-Sandbox
- **Default changed from ON to OFF** — the "auto-sandbox companions on safe-interior entry" feature (inns, homes, etc.) now defaults to disabled. Users who had it enabled keep their setting (the StorageUtil persistence key is untouched); only first-time installs and users who never touched the toggle see the new default. Can still be opted into via PrismaUI at any time
- **Reason** — user testing surfaced residual race conditions between `SituationMonitor`'s 3s scan cycle, SkyrimNet's `PackageOverrideHook` returning its own `FollowPlayer`, cell partial-load states where `IsInSafeInterior` flaps briefly during a transition, and `EvaluatePackage` timing vs SkyrimNet's package-registration queue. These occasionally left companions stuck on an engine fallback or the sandbox package after exit. Disabling by default avoids surprising behavior until a proper stability debounce is in place

---

## v2.2

### NPC Knowledge System — Rewrite
Every NPC now gets a single "What You Know" block that combines personal familiarity (have you met?) with public reputation (what have you heard?). Replaces the old separate familiarity and reputation prompts.

**Familiarity (personal relationship):**
- Rewrote the C++ decorator — replaced broken `PublicGetPlayerContext` with `PublicGetRecentDialogue` (direct per-NPC FormID query). Familiarity no longer stuck on "stranger"
- Five tiers based on dialogue line count: stranger (0), passing (1-200, name unknown), recent acquaintance (1-200, name known), known acquaintance (201-1000), familiar (1001+)
- Player name tracking via dialogue text scan + SkyrimNet memory search fallback. NPCs won't use your name until they've actually heard it
- Per-NPC caching (30s TTL) replaces the old bulk all-NPC cache
- Followers skip this entirely — they use the relationship system (rapport/trust/loyalty/mood) instead

**Reputation (public knowledge):**
- NPC role classification — innkeepers, bards, guards, merchants, jarls, bandits, fences each have a connectedness score (1-5) determining what rumors reach them
- Guild progression — tracks player rank in Companions, College, Thieves Guild, Dark Brotherhood via faction checks + quest stage fallback. Fame 1-5 per guild with descriptive titles
- Main Quest fame — five tiers from dragon slayer to world savior
- Dawnguard & Dragonborn DLC — three fame tiers each
- Knowledge filtering — guild members know at fame 1, locals at fame 1, connected NPCs at fame 3-4, everyone at fame 5
- Role-flavored text — guild members speak from direct knowledge, innkeepers relay gossip, guards cite official channels, criminals share underworld whispers
- Locality via faction checks (`TownRiftenFaction`, etc.) instead of fragile location string matching

**Interaction between the two:**
- Shared guild members get combined text — familiarity tier + rank woven together naturally
- Guild dedup prevents the reputation block from repeating what the familiarity block already covered
- Heading shows player name only when the NPC knows it; strangers see "What You Know About This Person"
- Familiar tier skips familiarity text but still shows reputation
- Removed civil war section per community feedback
- Old `0115_severactions_reputation.prompt` removed from FOMOD

### Furniture
- **Fixed auto-stand distance slider** — setting the PrismaUI slider to 0 (disabled) now actually disables distance-based auto-stand globally

### PrismaUI
- **FormID-based summon** — Summon button now passes FormID, preferring exact match over name lookup. Fixes teleporting the wrong actor for multi-form custom followers

---

## v2.0.7

### Outfit System
- **Per-follower outfit exclusion** — new "Outfit System" toggle on the PrismaUI Companions page. When disabled, the entire outfit system bypasses that follower: no lock enforcement, no DefaultOutfit suppression, no situation auto-switch, no alias re-equip events. Allows other outfit mods (NFF, SPID) to manage them freely
- **Fixed infinite re-equip loop** — equip/unequip operations could trigger `TESObjectLoadedEvent` cascades, causing the same actor to be stripped and re-equipped dozens of times in a single frame. Added per-actor re-entry guard with RAII cleanup
- **Fixed naked followers from stale lock data** — if locked items no longer resolve to valid armor forms (removed mods, lost items), the system now skips stripping instead of removing all gear with nothing to replace it
- **Fixed outfit lock completely non-functional** — OutfitDataStore's 26 Papyrus-callable functions were never registered with the SKSE VM. Every `OnObjectUnequipped` call in OutfitAlias hit "unbound native function" errors and silently failed, meaning outfit lock never re-equipped stripped items
- **Fixed manual lock outfit revert on cell change** — DefaultOutfit suppression was only applied for preset-based locks. Manual locks (lock-what-you're-wearing) now correctly suppress DefaultOutfit, preventing the engine from re-applying default gear on cell transitions. Previously caused outfit flicker and default items reappearing in inventory
- **Fixed PrismaUI outfit builder locks not persisting** — the builder left the outfit suspend flag set after committing a new lock. Cell transitions saw the suspend flag and skipped enforcement entirely, causing locked outfits to revert
- **Fixed survival prompt template error** — mismatched `{% if %}`/`{% endif %}` blocks in the cold section caused silent template failures

### Combat System
- **Aggression boost for forced combat** — `AttackTarget` now sets both Confidence (3) and Aggression (2) on attacker AND target. Previously only the attacker got Confidence — targets with Aggression 0 would flee instead of fighting back. Both values are stored and restored when combat ends
- **New factions for combat state** — `SeverActions_AttackFaction` and `SeverActions_TargetFaction` track which NPCs are in forced combat, used by the AIO flee patch

### AI Overhaul Compatibility
- **Optional AIO flee suppression patch** — new FOMOD option under "Compatibility Patches". Overrides AI Overhaul's 7 flee packages with conditions that skip fleeing for SeverActions followers and NPCs in forced combat. ESL-flagged, no load order slot used
- Without this patch, AI Overhaul gives most civilian NPCs flee packages that override all combat behavior

### NPC Familiarity System (New)
- **Player familiarity decorator** — `player_familiarity(actorUUID)` queries SkyrimNet's event database and vanilla relationship rank to determine if an NPC has actually met the player. Returns tier: stranger, met_once, acquainted, or familiar
- **First meeting prompt** — new `0045_severactions_familiarity.prompt` prevents NPCs from acting like old friends on first encounter. Strangers don't know the player's name, don't act familiar, and address them generically. Familiarity is earned through actual conversation history
- Uses multiple signals: SkyrimNet interaction count via `PublicGetPlayerContext`, vanilla relationship rank via `BGSRelationship`, and SeverActions follower status

### Dialogue Quality
- **Anti-meta-commentary rules** — NPCs no longer say "Not my business", "That has nothing to do with me", or "They weren't talking to me". These robotic dismissals are explicitly banned. NPCs either react naturally or stay silent
- **Bystander response guidance** — witnesses react once (briefly, in character), then return to their own life. No repeated commentary on the same event
- **Dialogue texture** — new guidance for mixing meaningful dialogue with mundane texture (weather complaints, idle observations, grumbles). Prevents every line from feeling dramatic
- **Emotional speech rules** — NPCs show emotion through HOW they speak (snapping, trailing off, going quiet) rather than announcing feelings ("I'm angry")
- Moved personality and conversation flow prompts out of Core — they now only exist in the DialogueStyle optional FOMOD module

### Actions
- **Arousal actions uncategorized** — ModifyArousal (OSL) and ModifyArousalSLO no longer require the adult category to be enabled. They now appear as normal actions

### Prompts
- **Removed Faction/Guild Reputation prompt** — the 374-line reputation template (`0115_severactions_reputation.prompt`) is now redundant with the conditional knowledge system. Removed from FOMOD installer

### OSL Arousal
- **Native C++ arousal decorator** — `get_arousal_state` now calls `OSLAroused.dll` directly via `GetProcAddress`, bypassing the Papyrus VM entirely. Fixes arousal data not showing up for users (Papyrus decorator had timing/reliability issues)
- **Expanded arousal prompt** — 5 tiers of arousal awareness (0-9 silent, 10-24 faint background, 25-49 low warmth, 50-74 persistent distraction, 75-89 hard to concentrate, 90-100 overwhelming). Previously only triggered at 75+
- Arousal described as a physical state that colors personality, not a personality replacement. A reserved person stays reserved but fidgets more
- Third-person observations only visible at 50+ (you can't see someone's internal state at low arousal)
- Removed `in_scene` field (handled by NSFW mod's activity prompts)

### Dialogue Quality
- **Rewrote conversation flow prompt** — removed all specific dialogue examples that LLMs were repeating as templates ("Ha. Yeah, that sounds about right." → spammed). Removed instructions to make sounds/gestures that TTS reads aloud. All guidance now describes the quality of speech rather than giving copyable examples
- **Rewrote personality prompt** — removed filler examples ("Hm.", "I suppose.") that got spammed. Emotion guidance reframed as "let mood bleed into words" rather than listing physical reactions (snapping, barking) that become stage directions
- Added "Don't narrate yourself" rule — no asterisks, no stage directions, no action descriptions. Only spoken words

### Hotkeys
- **Default PrismaUI hotkey** — Shift+8 opens PrismaUI config menu out of the box. Previously required manual MCM setup
- **MCM Shift modifier toggle** — new "Require Shift" toggle in MCM Hotkeys page. Users on existing saves can enable Shift+key for the config menu without starting a new game
- Default reset now resets to Shift+8 instead of disabled

### Prompts Removed
- **Removed Conditional Knowledge prompt** — `0130_conditional_knowledge.prompt` removed from Core. SkyrimNet's native knowledge system now handles conditional knowledge injection directly

### FOMOD
- New install page: **Compatibility Patches** (between Triggers and Adult Content)
- Removed "Faction/Guild Reputation Prompt" option from Prompts page
- Added `Patches/` directory to build system

---

## v2.0.6

### Outfit System
- Fixed intermittent naked followers on cell change — manual locks (locking default gear without applying a preset) no longer suppress DefaultOutfit, letting the engine help dress followers instead of racing with it
- Only preset-based outfit locks suppress DefaultOutfit now

### Auto-Sandbox
- Fixed crash (mutex deadlock) when entering player homes — the safe interior flag was being set under a lock that was already held
- Followers now spawn 250 units in front of the player when rescued from auto-sandbox, preventing them from walking back through the door
- Cross-cell rescues use MoveTo + deferred SetPosition offset for reliable positioning away from doors

### Dialogue
- Added direct address rule — NPCs now use "you/your" when speaking to someone directly instead of "she/he/they" (fixes NPCs talking about someone who is standing right in front of them)

### Triggers
- Disabled quest completion triggers (Quest Completed, Major Quest Diary) — will be reworked in a future update

---

## v2.0.5

### Outfit Builder
- **Inventory Only mode** — toggle between browsing the full armor catalog or only items in the follower's inventory. Prominent segmented toggle at the top of the builder (All Items / Inventory)
- **Equip/Unequip instant feedback** — Inventory page now shows optimistic UI updates when equipping or unequipping items, with toast notifications. No longer requires closing PrismaUI to see changes

### Follower System
- **Soft Reset button** — new option on the Companions page that clears factions, packages, aliases, and follow state but keeps relationship data, home, and combat style. Use to unstick followers without losing history
- **Teleport positioning fix** — catch-up teleport now places followers 350 units behind the player's facing direction instead of in front (was causing bump dialogue and collision)
- **Global teleport cooldown** — replaced per-follower cooldown with a single global cooldown, adjustable in PrismaUI Settings (5-120 seconds, default 30s)
- **Auto-sandbox rescue fix** — all followers now get tagged for rescue the moment auto-sandbox starts, fixing the timing issue where some of 8+ followers would get left behind
- Cleaned up "Recruit via vanilla dialogue" notifications — now just shows "is now being tracked"

### Survival System
- **Dismissed follower tracking** — dismissed followers at home now have survival needs that drift with each off-screen life event and tick in real-time when you visit their cell
- **Auto-initialization** — followers with zero survival values get seeded with random starting values on first tick instead of staying blank
- **Vampire blood support** — blood potions now reduce hunger for vampire followers (40 points). Detects vampires via keyword and race name
- **Track Dismissed Followers toggle** — new setting in PrismaUI Settings to enable/disable dismissed follower survival tracking
- **Fixed PrismaUI survival toggle** — toggling survival tracking on/off for individual followers in PrismaUI now properly syncs to MCM (was silently failing due to FormID parsing bug in all 3 event handlers)
- **Fixed PrismaUI display for dismissed followers** — survival page now shows actual values for dismissed followers instead of zeros

### Outfit System
- **Enhanced cell-load logging** — detailed logging for outfit lock enforcement on cell change, showing exactly why a follower's outfit state changed (lock active/inactive, suspended, items empty, stripped/re-equipped counts)

### Actions
- **Tightened category action selection** — LLMs can no longer add extra keys alongside "intent" when selecting category actions, preventing silent action failures

---

## v2.0

### Quest Awareness System (New)
- Followers now track the player's quests with presence-based awareness — companions who were there know details, those who weren't only hear vague rumors
- Three awareness tiers: **Firsthand** (actively following during quest progress), **Secondhand** (in roster but not present), and **Unaware** (not yet recruited)
- Objective-driven tracking — summaries generate only when new quest objectives appear, not on every internal stage change
- Personalized LLM-generated narratives per follower — each companion describes quest events through their own personality and voice
- Quest awareness prompt includes recent vanilla dialogue context from SkyrimNet's event system for grounded summaries
- Summaries build incrementally — each new objective adds a sentence, creating a natural narrative of the follower's quest experience
- On quest completion, the follower's quest awareness becomes a permanent SkyrimNet memory (EXPERIENCE for firsthand, KNOWLEDGE for secondhand)
- Proximity-aware: only followers loaded in the world and near the player receive awareness updates
- Recently recruited followers are seeded with knowledge of active quests but no fabricated details — summaries build naturally as objectives change

### Relationship Display Overhaul
- Follower relationship context is now a single LLM-generated paragraph instead of separate rigid threshold lines
- The assessment blurb naturally weaves together rapport, trust, loyalty, and mood into one cohesive inner monologue
- Each assessment produces a 3-5 sentence personality-rich description that references specific shared experiences
- New followers see a natural "still forming impressions" message instead of clinical default values

### Outfit Builder (New)
- Visual outfit builder — select armor pieces from the catalog by slot, preview selections, and equip on any follower
- Equip & Lock — equip selected items and lock the outfit to prevent engine resets on cell changes. Presets are exclusive — only preset items are worn, all other armor is stripped
- Save as Preset — save selected items as a named preset without equipping. Items are added to the follower's inventory for later use
- Hide Helmet toggle — hide head/hair slot armor per-follower
- Live search — outfit builder search results update as you type (300ms debounce)

### Situation Auto-Switch (New)
- Assign outfit presets to situations: adventure, town, home, sleep, combat, rain, snow
- Fully native C++ switching — no Papyrus dependency, instant response on location change
- Default outfit auto-save — captures current outfit before first switch, restores when entering unmapped situations
- Weather-aware detection — rain and snow situations trigger when outdoors in matching weather (only if mapped)
- Combat detection — auto-switches to combat preset during fights
- All 7 situation slots visible in PrismaUI Outfits page

### Outfit Lock System
- Outfit context now visible in follower prompts — active preset name and situation mappings read directly from the native C++ store via `outfit_context` decorator (previously broken due to StorageUtil sync gap)
- Exclusive presets — applying a preset strips ALL other armor, locks only the preset items
- Cell-load enforcement — strips non-locked armor and re-equips locked items on every cell transition
- DefaultOutfit suppression — prevents engine from restoring base outfit on cell load or during preset apply
- Native C++ preset apply — Apply Preset button and situation auto-switch share the same reliable code path
- Native GetWornArmor — single C++ call replaces 18-slot Papyrus loop for preset saves
- Items auto-added to inventory if missing when applying presets

### PrismaUI Overhaul
- All native dropdowns replaced with consistent modal pickers across the entire UI
- Catalog page: modal filter pickers for plugin (with search), slot (grid), and type selection
- Dedicated Blacklist Manager modal with Plugins/Items tabs for managing undress protection
- Reusable PickerModal component used across Outfits, Companions, Settings, Actions, and World pages

### Auto-Sandbox at Home (New)
- Followers automatically sandbox (wander naturally) when entering player-owned homes
- Reliably follows the player when leaving — detects player exiting safe interior even when returning to the same exterior cell (e.g., Honeyside → Riften)
- PrismaUI toggle: "Auto-Sandbox at Home" in Follower Behavior settings
- Won't override manual wait/sandbox commands

### Combat Style Overhaul
- 10 real combat styles replacing the old 5 abstract names: Melee, Berserker (dual-wield), Tank, Archer, Mage, Spellsword, Battlemage, Champion, Brawler, Companion
- Default is "No Combat Style" — doesn't interfere with an NPC's native combat behavior
- Overrides the ActorBase CombatStyle form — changes actual AI (flee thresholds, attack patterns, dual-wield), not just actor values
- Original combat style saved and restored on dismiss
- Old styles (balanced, aggressive, etc.) auto-migrate

### Follower System
- Reduced follower position jitter — removed 7 redundant EvaluatePackage calls that caused followers to snap backward when near the player
- Fixed non-followers (guards, Irileth) being teleported to the player — teleport now requires roster membership
- SMP-safe teleport — uses SetPosition instead of MoveTo for same-cell repositioning, preserving SMP hair/body physics
- Custom follower tracking fix — prevent re-registration loop, clean dismiss path for SPID/NFF followers
- Off-screen life exclusion — per-follower opt-out via PrismaUI
- Vanilla hunting bow removal — strip hunting bow/arrows automatically added on recruit
- Cowardly companions get minimum Brave confidence + Aggressive + Helps Allies on recruit
- Framework mode migration fix — Tracking mode no longer reverts to SeverActions mode on reload

### Furniture
- Native C++ lookup — fixes "furniture not found" for modded furniture from plugins with many active ESPs

### Actions & Compatibility
- Tightened category action selection prompt — LLMs can no longer add extra keys (like "target") alongside "intent" when selecting a category, which could cause the action to fail silently
- LearnSpell / CompanionFollow — fixes actions failing silently on some users' installations
- Dialogue style prompts — separated into optional FOMOD module

### Immersion Triggers
- Location/travel narrations now reference the player by name instead of "the party"
- Trigger audience narrowed to nearby NPCs only — random townsfolk no longer react to arrivals

### Performance & Stability
- Lazy-loaded databases — crafting, alchemy, spell, armor, weapon, and location databases initialize on first use instead of at startup (saves ~1-2s on game load)
- Background actor indexing — heavy NPC cell mapping runs on a background thread instead of blocking the loading screen (saves ~2-4s on game load)
- Internal code cleanup — consolidated shared utilities, removed dead code, fixed thread safety issues, and hardened cosave persistence against data corruption

### Bug Fixes
- Fixed stale "In Combat" badge persisting indefinitely on companion cards
- PrismaUI crash on Life Tracker for non-English users
- Off-screen life garbled text in follower memories
- Outfit lock race condition with SPID keyword
- ESL FormID compatibility for relationship assessments
- Float precision for high load order plugins in catalog equip
- Active outfit preset now shown in follower prompts
- Preset name casing mismatch between C++ and Papyrus — all preset names now normalized to lowercase
- Unmapped outfit situations no longer trigger jarring default outfit restore

---

## v1.95
- Follower banter system (auto-banter between followers)
- Outfit compatibility improvements
- Dialogue refinement (anti-fixation, topic passthrough)
- PrismaUI pause when open
- Relationship assessment with character bio
- LLM-generated relationship blurb
- ShowFollowerContext toggle
- Injection mode toggle (Always vs Semantic) for knowledge entries
- Spell school toggles on spell tab
- Follower teleport system
- SkyrimNet v7 knowledge migration
- Custom faction groups, SkyrimNet v7 dual-write

## v1.9
- Conditional Knowledge system (KnowledgeStore, cosave, decorator)
- World page revamp (bounties, debts, knowledge sections)
- Outfit fixes

## v1.8
- Property ownership system
- Two-mode follower refactor (SeverActions Mode vs Tracking Mode)
- Off-screen life improvements
- Essential toggle, assign home for custom followers, stats tab
- NFF-safe follower recruitment

## v1.6
- Inventory Manager with transfer, equip, destroy
- Vanilla recruitment routing
- Actions page overhaul

## v1.1
- Custom AI detection
- PrismaUI improvements

## v1.0
- PrismaUI config dashboard
- Home system
- Inter-follower relationships

## v0.99
- Loot transfer, self-healing follow, speaker selector
- Relationship assessment, group conversation rewrite

## v0.98
- Debt system, outfit lock, anti-duplicate actions

## v0.95
- Outfit persistence, consolidated wait, hotkeys, wheel menu, EFF support

## v0.91
- Follower Framework, Outfit Manager overhaul, Yield monitor

## v0.90
- Book reading, guard dispatch overhaul, NND integration

## v0.88
- Initial release
