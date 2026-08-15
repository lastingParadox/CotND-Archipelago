local color = require "system.utils.Color"
local components = require "necro.game.data.Components"
local currency = require "necro.game.item.Currency"
local extraMode = require "necro.game.data.modifier.ExtraMode"
local damage = require "necro.game.system.Damage"
local textPool = require("necro.config.i18n.TextPool")

local APFlags = require("AP.scripts.utils.flags")

components.register({
    AP_currency = {
        components.constant.string("currencyType", currency.Type.GOLD),
        components.field.float("value", 0),
    },
    AP_damageCountdown = {
        components.field.int("damage", 999),
        components.field.int("type", APFlags.DAMAGE_DEATH_LINK),
        components.field.int("countdownReset", 0),
        components.field.string("killerName", "DeathLink"),
        components.field.int("countdown", 24),
        components.field.bool("active", false)
    },
    AP_deathlinkShrine = {},
    AP_exchanger = {},
    AP_traplinkShrine = {},
    AP_victoryItem = {},
    AP_victorySlot = {},
    AP_flyaway = {
        components.field.string("text", "AP Item Obtained"),
    },
    AP_followerChain = {
        components.field.entityID("parent"),
        components.field.entityID("child"),
        components.field.entityID("root"),
        components.field.bool("temporary", true)
    },
    AP_followerDamageParentWhileDead = {
        components.constant.float("damageRatio", 0.2),
        components.field.enum("type", damage.Flag, APFlags.DAMAGE_DEATH_LINK),
        components.field.table("sounds"),
        components.field.string("killerName"),
        components.field.int("stage")
    },
    AP_character = {
        components.field.string("name", ""),
    },
    AP_hintItem = {
        components.field.string("type", ""),
    },
    AP_hintTrap = {},
    AP_interactable = {
        components.field.bool("ap", false),
        components.field.bool("active", false)
    },
    AP_interactableExtraModeLobby = {
        components.field.int("extraMode", extraMode.Type.HARD),
    },
    AP_interactableSelectCharacterLobby = {
        components.field.string("characterType", ""),
        components.field.bool("resetPosition", false),
    },
    AP_item = {},
    AP_itemClass = {
        components.field.int("classification", 0), -- 0 = filler, 1 = progression, 2 = useful, 4 = trap
    },
    AP_hintLabel = {
        components.field.string("text", ""),
        components.field.float("offsetX", 0),
        components.field.float("offsetY", -26),
    },
    AP_itemPoolChest = {
        components.constant.table("weights")
    },
    AP_itemPoolRedChest = {
        components.constant.table("weights")
    },
    AP_itemPoolPurpleChest = {
        components.constant.table("weights")
    },
    AP_itemPoolBlackChest = {
        components.constant.table("weights")
    },
    AP_itemPoolLockedChest = {
        components.constant.table("weights")
    },
    AP_itemPoolShop = {
        components.constant.table("weights")
    },
    AP_itemPoolLockedShop = {
        components.constant.table("weights")
    },
    AP_itemPoolUrn = {
        components.constant.table("weights")
    },
    AP_itemPoolSecret = {
        components.constant.table("weights")
    },
    AP_itemPoolFood = {
        components.constant.table("weights")
    },
    AP_itemPoolHearts = {
        components.constant.table("weights")
    },
    AP_itemPoolCrate = {
        components.constant.table("weights")
    },
    AP_itemPoolCrateMimic = {
        components.constant.table("weights")
    },
    AP_itemPoolWar = {
        components.constant.table("weights", {
            1
        })
    },
    AP_itemPoolUncertainty = {
        components.constant.table("weights", {
            1
        })
    },
    AP_itemPoolEnchant = {
        components.constant.table("weights", {
            1
        })
    },
    AP_itemPoolNeed = {
        components.constant.table("weights", {
            1
        })
    },
    AP_itemPoolVault = {
        components.constant.int("key"),
        components.constant.int("priority")
    },
    AP_itemShowcase = {
        components.field.bool("active", false),
        components.field.string("item", "")
    },
    AP_labelLobby = {
        components.field.entityID("topLabel"),
        components.field.entityID("bottomLabel"),
    },
    AP_progressionDoor = {
        components.field.table("npc", { "Merlin" }),
        components.field.string("orientation", "Horizontal")
    },
    AP_npcUnlockable = {
        components.field.int("keyType", 0),
        components.field.string("cagedFlyaway1", "Help me!"),
        components.field.string("cagedFlyaway2", "Buy the golden key!"),
        components.field.string("freedFlyaway1", "Thank you!!!"),
        components.field.string("freedFlyaway2", "See you in the AP Lobby!"),
        components.field.bool("caged", false),
        components.field.bool("freed", false)
    },
    AP_player = {
        components.field.string("name", ""),
    },
    AP_shrinePoolWeight = {
        components.constant.float("weight", 0),
    },
    AP_editorCategory = {},
    AP_preview = {
        components.field.float("offsetX", 0),
        components.field.float("offsetY", 0),
        components.field.float("offsetZ", 0),
        components.field.float("offsetH", 0),
        components.field.int("outlineColor", color.TRANSPARENT),
        components.field.bool("shadowCopyZ", false),
    },
    AP_shopItem = {
        components.field.entityID("slot")
    },
    AP_locationItem = {
        components.field.string("locationName", ""),
        components.field.string("locationCode", ""),
    },
    AP_chestKind = {
        components.constant.string("kind", ""),
    },
    AP_chestUpgrade = {
        components.constant.string("chest", ""),
        components.constant.string("chanceType", ""),
        components.constant.int("order", 0),
    },
    AP_npc = {
        components.constant.string("apName", ""),
    },
    AP_shopLabel = {
        components.field.string("npc", "Hephaestus"),
        components.field.float("offsetY", -26),
        components.field.entityID("label")
    },
    AP_shopSlot = {
        components.field.string("npc", "Hephaestus"),
        components.field.string("position", "Left"),
        components.field.string("type", ""),
        components.field.entityID("item")
    },
    AP_shopStock = {},
    AP_spellResonanceMode = {
        components.constant.string("type", "kills")
    },
    AP_trapItem = {
        components.field.string("trap", ""),
        components.field.string("locationCode", ""),
    },
    AP_trapJanitorNext = {},
    AP_trapJanitorReset = {},
    AP_uncertainWeapon = {},
    AP_pawnbrokerPricing = {},
    AP_trapUnlock = {
        components.field.string("lockType", "none"),
        components.field.string("lockedText", "Complete zone %d to unlock!"),
        components.constant.string("apConnectionText", "AP Disconnected!"),
        components.constant.string("lockedTileType", "LobbyLockedStairs")
    },
    AP_worldLabelCharacterStats = {
        components.field.string("characterType", "")
    },
    AP_zweihaenderTransform = {
        components.constant.bool("isWielder", false),
        components.constant.string("targetType", "Cadence")
    },
    AP_diamondCounter = {
        components.field.int("amount"),
    },
    AP_klarinettaWeaponScroll = {},
    AP_material = {},
    AP_buffCharacterShrine = {},
    AP_buffItem = {
        components.constant.string("character", ""),
    },
    AP_buffHealthDecrease = {},
    AP_marvDeathLinkTag = {
        components.field.string("text", ""),
    },
    AP_buffHealthIncrease = {},
    AP_buffHeartDisplay = {},
    AP_buffPotionDecrease = {},
    AP_buffPotionIncrease = {},
    AP_buffPotionDisplay = {},
    AP_buffPotionTitle = {},
})


textPool.register("Archipelago", "mod.AP.lobby.stair")
textPool.register("AP Zones\nMode", "mod.AP.lobby.stair.zones")
textPool.register("Back to\nArchipelago", "mod.AP.lobby.stairBack")
textPool.register("Item Room", "mod.AP.lobby.itemRoom")
textPool.register("Archipelago Item Pool", "mod.AP.lobby.itemHub")
textPool.register("Here you can find all items you've\nreceived in your AP World", "mod.AP.lobby.itemHubHint")
textPool.register("Archipelago", "mod.AP.lobby.itemHub.apSection")
textPool.register("Back to\nItem Hub", "mod.AP.lobby.stairBackHub")

textPool.register("Characters", "mod.AP.lobby.itemCat.character")
textPool.register("Weapons", "mod.AP.lobby.itemCat.weapon")
textPool.register("Shovels", "mod.AP.lobby.itemCat.shovel")
textPool.register("Shields", "mod.AP.lobby.itemCat.shield")
textPool.register("Armors", "mod.AP.lobby.itemCat.armor")
textPool.register("Headwear", "mod.AP.lobby.itemCat.head")
textPool.register("Footwear", "mod.AP.lobby.itemCat.feet")
textPool.register("Torches", "mod.AP.lobby.itemCat.torch")
textPool.register("Rings", "mod.AP.lobby.itemCat.ring")
textPool.register("Spells", "mod.AP.lobby.itemCat.spell")
textPool.register("Scrolls &\nTomes", "mod.AP.lobby.itemCat.scroll")
textPool.register("Actions", "mod.AP.lobby.itemCat.action")
textPool.register("Misc", "mod.AP.lobby.itemCat.misc")
textPool.register("Shrines", "mod.AP.lobby.itemCat.shrine")
textPool.register("Modes", "mod.AP.lobby.itemCat.mode")
textPool.register("Buffs", "mod.AP.lobby.itemCat.buff")
textPool.register("Upgrades", "mod.AP.lobby.itemCat.upgrade")
textPool.register("Materials", "mod.AP.lobby.itemCat.material")
textPool.register("NPCs", "mod.AP.lobby.itemCat.npc")
textPool.register("Hint Mode", "mod.AP.lobby.hintRun")
textPool.register("Archipelago Mode!\nBeat All Zones with %s characters\nto unlock %s!", "mod.AP.lobby.allZonesHint")
textPool.register("Archipelago Mode!\nBeat Ensemble Mode\nto complete your game!", "mod.AP.lobby.ensembleHint")
textPool.register("Archipelago Mode!\nBeat %s separate zones\nto unlock %s!", "mod.AP.lobby.zonesHint")
textPool.register("Archipelago Mode!\nCollect %s Golden Lute Shards\nto unlock %s!", "mod.AP.lobby.shardsHint")
textPool.register("Archipelago Mode!\nBeat all %s story bosses\nto unlock %s!", "mod.AP.lobby.storyHint")
textPool.register("Archipelago Mode!\nGoal met!\nYour game is complete!", "mod.AP.lobby.noCatalystHint")
textPool.register("These items will show up in runs!", "mod.AP.lobby.shopHint")
textPool.register("Out of Stock! Find a Shop Restock!", "mod.AP.lobby.shopRestockHint")
textPool.register("Out of Stock! All items were sold!", "mod.AP.lobby.shopSoldOutHint")
textPool.register("Remove items from the\n AP item pool?", "mod.AP.lobby.janitorHint")
textPool.register("Take these on your\n next AP run!", "mod.AP.lobby.dealerHint")
textPool.register("Get hints from random runs!", "mod.AP.lobby.hintmasterHint")
textPool.register("Settings", "mod.AP.lobby.settingsmasterHint")
textPool.register("Ensemble\n", "mod.AP.lobby.stair.ensemble")
textPool.register("Boss Rush\n", "mod.AP.lobby.stair.bossRush")
textPool.register("Archipelago Mode!\nDefeat all bosses in Boss Rush\nto complete your game!", "mod.AP.lobby.bossRushHint")
textPool.register("Configure permanent\nrun buffs!", "mod.AP.lobby.buffmasterHint")
textPool.register("Buff Room", "mod.AP.lobby.buffRoom")
textPool.register("These buffs apply\nto all AP runs!", "mod.AP.lobby.buffRoomHint")
textPool.register("Archipelago Mode!\nBuy the Victory Item\nto complete your game!", "mod.AP.lobby.expensivePurchaseHint")
