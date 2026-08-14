local currency = require "necro.game.item.Currency"

local apItemFactory = require("AP.scripts.items.apItemFactory")

apItemFactory.define({
    name = "AP_Gold",
    texture = "Gold.png",
    hint = L("Earn Gold", "AP.item.gold"),
    data = { flyaway = "Gold" },
    components = {
        AP_currency = {
            currencyType = currency.Type.GOLD,
            value = 50,
        },
    },
})

--- NOTES FOR NEXT SESSION:
---
--- Look into the new item room changes. There's some kinks that need to be worked out to make it more presentable, particularly with the displayed
--- mode shrines displaying the "AP_ModeShrine" item instead of the mode shrine itself. Honestly, we should display "APModeShrine" objects like
--- the shrines, similarly to APCharacter which renders the character instead of a hovering item. (See below for item entity condensing)
---
--- Look into bug reported related to client losing connection to the server (e.g., Internet being spotty). A user reported the following:
--- """
--- in a multiworld with some friends, my wifi blipped and my connection timed out, i dont have logs or anything but
--- i have reason to believe that after i reconnected automatically i just kinda... stopped receiving items in the client?
--- for instance i got a shop restock but it didnt restock anything
--- i had to disconnect and reconnect to see the items in the shop
--- """
---
--- Upon being asked, the user specified that the client was receiving items from the ap server, but the items were not being received on the
--- mod side until they disconnected and reconnected. The mod, despite the client being disconnected from the AP Server temporarily, did not
--- receive a packet specifying a disconnect, which is the main issue here.
---
--- Look into bug reported related to Ensemble mode: When soft unlocks is enabled and you don't have that character's logically required items
--- (e.g., Dove's Flower), that character doesn't spawn with the item as expected. However, after changing from that character, all future characters
--- have their logically required items equipped.
---
--- """
--- Bug with Ensemble Mode that I've not mentioned:
--- In 1-1, the character you play as won't have the unlocked items you don't have, which is normal
--- But from 1-2 onwards, every character does (including that one)
--- So if you have no flower as Dove on 1-1, you will on 1-2
--- And basically everyone has their default kits
--- If you don't have a Spear unlocked they'll still start with it and so on
--- Aria will have a potion, Dove will have a ring of peace, etc
--- """
---
--- The same user reports also being able to access unaccessible characters in Ensemble mode when hard unlocks is turned on as well. They say
--- they believe they experienced this in the past, though they need to double check. My assumption is that Ensemble Mode only checks having the
--- character item and NOT their required items in this case, which shouldn't be the case; it should share the same requirements the character
--- selectors do: Character item and their required items. Reminder this is only for HARD unlock requirements.
---
--- """
--- Okay wait now -I'm- confused, I'll make sure that's (being able to access unaccessible characters in ensemble with hard unlocks)
--- not a thing that's happened later lmao. We've just done so many runs lately I've not really kept track,
--- it's all mental stuff and me just doing Ensemble Mode every time as goal
--- but I'm still p sure I've played as locked chars, though again I'll check later to see if I'm right or wrong
--- """
---
--- Look into bug reported related to Melody's Buff, which adds a throwing charm on run start to your inventory, having the throwing charm removed
--- on lunging trap activation. This is probably not entirely related to Melody's buff, but more of an issue with the Leaping Trap removing unintended
--- items?
---
--- We really need to condense all of the AP-only items into a single entity. They all essentially do the same thing: exist only to send
--- a check (when in APShopSlot) or act as a gate for a certain apworld functionality. Realistically the following items should be condensable,
--- bar some specific rendering and acquisition functionalities that exist with each item:
--- - APBuffItem (Requires special rendering)
--- - APCharacter (Requires special rendering)
--- - APGold
--- - APGoldenLuteShard
--- - APItem (Requires special property to change the shown sprite in the spritesheet)
--- - APMaterial
--- - APModeShrine (Requires special rendering/sprite change logic)
--- - APShopStock
--- - APTrapItem (Requires special rendering logic, possibly too unique to include in a generic "APItem" entity)
--- - APVictoryItem
---
--- There are possibly other items that can fit in a generic item as well. Don't be afraid to push back on any of these.
---
--- Also, if the player has Amplified disabled in logic but doesn't have the Amplified DLC disabled, its impossible to access the following, as they
--- don't spawn naturally:
--- Ring of Phasing
--- Shrine of Phasing
--- Shrine of No Return
--- Shrine of Pace
---
--- We need to make sure the item and shrines spawn, especially if shrines are logical locations in the apworld. Otherwise it's impossible to get
--- these checks. We could just add the RingPhasing to the poolless items list and use the same chest/shop spawns as specified in the xml.
