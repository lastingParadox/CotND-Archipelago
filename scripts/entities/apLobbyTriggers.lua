local commonTrap = require("necro.game.data.trap.CommonTrap")
local customEntities = require("necro.game.data.CustomEntities")
local ecs = require("system.game.Entities")
local flyaway = require("necro.game.system.Flyaway")
local gfx = require("system.gfx.GFX")
local ping = require("necro.client.Ping")
local player = require("necro.game.character.Player")
local render = require("necro.render.Render")
local sound = require("necro.audio.Sound")

local apInventory = require("AP.scripts.utils.apInventory")
local apShopSlot = require("AP.scripts.entities.apShopSlot")
local apTypes = require("AP.scripts.utils.types")
local progression = require("AP.scripts.client.progression")

local HEART_FULL  = "ext/gui/TEMP_heart_small.png"
local HEART_EMPTY = "ext/gui/TEMP_heart_empty_small.png"
local HEART_GAP   = -1   -- px between hearts
local HEART_ABOVE = -12  -- px above tile-center Y

customEntities.register({
    name = "AP_BuffHeartDisplay",
    gameObject = {},
    position = {},
    visibility = {},
    AP_buffHeartDisplay = {},
    lobbyImmunity = {},
})

do
    -- Cache image dimensions on first render frame.
    local heartW, heartH
    local visual = { rect = { 0, 0 }, texture = "", z = 0 }

    event.render.add("apBuffHeartDisplayRender", { order = "objects" }, function()
        if not heartW then
            heartW, heartH = gfx.getImageSize(HEART_FULL)
            heartW = heartW or 10
            heartH = heartH or 8
        end

        local buf = render.getBuffer(render.Buffer.HEALTH_BAR)
        local spacing = heartW + HEART_GAP

        for entity in ecs.entitiesWithComponents({ "AP_buffHeartDisplay", "position", "visibility" }) do
            if entity.visibility.visible then
                local full  = math.floor(progression.getBuffHealth() / 2)
                local total = math.max(1, math.floor(progression.getHealth() / 2))
                local px, py = render.tileCenter(entity.position.x, entity.position.y)
                local startX = px - math.ceil((spacing * total - HEART_GAP) / 2) + 1
                local heartY = py + HEART_ABOVE - heartH

                visual.z = py
                for i = 0, total - 1 do
                    visual.rect[1] = startX + i * spacing
                    visual.rect[2] = heartY
                    visual.texture = i < full and HEART_FULL or HEART_EMPTY
                    buf.draw(visual)
                end
            end
        end
    end)
end

local POTION_FULL     = "mods/AP/gfx/icons/potion_indicator.png"
local POTION_DISABLED = "mods/AP/gfx/icons/potion_disabled_indicator.png"
local POTION_GAP      = 0   -- px between indicators
local POTION_ABOVE    = -13 -- px above tile-center Y

customEntities.register({
    name = "AP_BuffPotionDisplay",
    gameObject = {},
    position = {},
    visibility = {},
    AP_buffPotionDisplay = {},
    lobbyImmunity = {},
})

do
    -- Cache image dimensions on first render frame.
    local potionW, potionH
    local visual = { rect = { 0, 0 }, texture = "", z = 0 }

    event.render.add("apBuffPotionDisplayRender", { order = "objects" }, function()
        if not potionW then
            potionW, potionH = gfx.getImageSize(POTION_FULL)
            potionW = potionW or 12
            potionH = potionH or 12
        end

        local buf = render.getBuffer(render.Buffer.HEALTH_BAR)
        local spacing = potionW + POTION_GAP

        for entity in ecs.entitiesWithComponents({ "AP_buffPotionDisplay", "position", "visibility" }) do
            if entity.visibility.visible then
                local filled = progression.getPotionMode()
                local total = math.max(1, progression.getPotionTiers())
                local px, py = render.tileCenter(entity.position.x, entity.position.y)
                local startX = px - math.ceil((spacing * total - POTION_GAP) / 2) + 1
                local potionY = py + POTION_ABOVE - potionH

                visual.z = py
                for i = 0, total - 1 do
                    visual.rect[1] = startX + i * spacing
                    visual.rect[2] = potionY
                    visual.texture = i < filled and POTION_FULL or POTION_DISABLED
                    buf.draw(visual)
                end
            end
        end
    end)
end

local function registerVisibleTrigger(name, texture, width, height, components)
    components.sprite = {
        texture = texture,
        width = width,
        height = height
    }
    components.positionalSprite = components.positionalSprite or {
        offsetY = 12
    }
    components.visibility = {}
    components.rowOrder = {
        z = -995
    }
    components.darkenToTileBrightnessEffect = {}
    components.editorHidden = {}
    components.pingable = components.pingable or {
        type = ping.Type.EXIT
    }
    components.pingableCursorOffset = {
        offsetZ = 12
    }

    return commonTrap.registerTrigger(name, components)
end

registerVisibleTrigger("AP_TriggerJanitorNext", "ext/level/TEMP_shop_next.png", 26, 26, {
    friendlyName = {
        name = "Janitor item cycling pressure plate"
    },
    trap = {
        triggerDelay = 0
    },
    AP_trapJanitorNext = {},
    soundTrapActivate = {
        sound = "teleport"
    }
})
registerVisibleTrigger("AP_TriggerJanitorReset", "ext/level/TEMP_shop_reset.png", 26, 26, {
    friendlyName = {
        name = "Janitor item reset pressure plate"
    },
    trap = {
        triggerDelay = 0.001
    },
    trapConfirmationMenu = {
        messageKey = "label.lobby.confirm.janitor"
    },
    AP_trapJanitorReset = {}
})

event.trapTrigger.add("apJanitorNext", { filter = "AP_trapJanitorNext", order = "spell" }, function(ev)
    apShopSlot.refreshShopSlots("Janitor")
end)

event.trapTrigger.add("apJanitorReset", { filter = "AP_trapJanitorReset", order = "spell" }, function(ev)
    if ev.triggerConfirmed then
        progression.clearBannedItems()
        apShopSlot.refreshShopSlots("Janitor")
    end
end)

-- Buff health triggers --

registerVisibleTrigger("AP_TriggerBuffHealthDecrease", "mods/AP/gfx/tiles/shop_back.png", 26, 26, {
    friendlyName = { name = "Buff health decrease" },
    trap = { triggerDelay = 0 },
    AP_buffHealthDecrease = {},
    soundTrapActivate = { sound = "teleport" }
})

registerVisibleTrigger("AP_TriggerBuffHealthIncrease", "ext/level/TEMP_shop_next.png", 26, 26, {
    friendlyName = { name = "Buff health increase" },
    trap = { triggerDelay = 0 },
    AP_buffHealthIncrease = {},
    soundTrapActivate = { sound = "teleport" }
})

registerVisibleTrigger("AP_TriggerBuffPotionDecrease", "mods/AP/gfx/tiles/shop_back.png", 26, 26, {
    friendlyName = { name = "Bonus potion decrease" },
    trap = { triggerDelay = 0 },
    AP_buffPotionDecrease = {},
    soundTrapActivate = { sound = "teleport" }
})

registerVisibleTrigger("AP_TriggerBuffPotionIncrease", "ext/level/TEMP_shop_next.png", 26, 26, {
    friendlyName = { name = "Bonus potion increase" },
    trap = { triggerDelay = 0 },
    AP_buffPotionIncrease = {},
    soundTrapActivate = { sound = "teleport" }
})

-- A rebuild rather than a stack edit, since lowering the count has to drop potions again.
local function setPotionMode(ev, mode)
    progression.setPotionMode(mode)

    for _, playerEntity in ipairs(player.getPlayerEntities()) do
        apInventory.applyStarterInventory(playerEntity, progression, { sanitize = true })
    end

    flyaway.create({ entity = ev.trap, text = apTypes.PotionModes[mode] })
end

event.trapTrigger.add("apBuffPotionDecrease", { filter = "AP_buffPotionDecrease", order = "spell" }, function(ev)
    local current = progression.getPotionMode()
    if current <= 0 then
        sound.playFromEntity("error", ev.trap, { deduplicationID = ev.trap.id })
        flyaway.create({ entity = ev.trap, text = "Potions already disabled!" })
        return
    end
    setPotionMode(ev, current - 1)
end)

event.trapTrigger.add("apBuffPotionIncrease", { filter = "AP_buffPotionIncrease", order = "spell" }, function(ev)
    local current = progression.getPotionMode()
    if current >= progression.getPotionTiers() then
        sound.playFromEntity("error", ev.trap, { deduplicationID = ev.trap.id })
        flyaway.create({ entity = ev.trap, text = "No further Progressive Potions received!" })
        return
    end
    setPotionMode(ev, current + 1)
end)

local function applyBuffHealthDelta(delta)
    for _, entity in ipairs(player.getPlayerEntities()) do
        if entity and entity.health then
            entity.health.maxHealth = entity.health.maxHealth + delta
            if delta > 0 then
                entity.health.health = entity.health.health + delta
            elseif entity.health.health > entity.health.maxHealth then
                entity.health.health = entity.health.maxHealth
            end
        end
    end
end

event.trapTrigger.add("apBuffHealthDecrease", { filter = "AP_buffHealthDecrease", order = "spell" }, function(ev)
    local current = progression.getBuffHealth()
    if current <= 0 then
        sound.playFromEntity("error", ev.trap, { deduplicationID = ev.trap.id })
        flyaway.create({ entity = ev.trap, text = "Already at minimum HP!" })
        return
    end
    local newValue = current - 2
    applyBuffHealthDelta(-2)
    progression.setBuffHealth(newValue)
    local hearts = math.floor(newValue / 2)
    flyaway.create({ entity = ev.trap, text = "Bonus HP: " .. hearts .. (hearts == 1 and " heart" or " hearts") })
end)

event.trapTrigger.add("apBuffHealthIncrease", { filter = "AP_buffHealthIncrease", order = "spell" }, function(ev)
    local current = progression.getBuffHealth()
    local maxHealth = progression.getHealth()
    if current >= maxHealth then
        sound.playFromEntity("error", ev.trap, { deduplicationID = ev.trap.id })
        flyaway.create({ entity = ev.trap, text = "Already at maximum HP!" })
        return
    end
    local newValue = current + 2
    applyBuffHealthDelta(2)
    progression.setBuffHealth(newValue)
    local hearts = math.floor(newValue / 2)
    flyaway.create({ entity = ev.trap, text = "Bonus HP: " .. hearts .. (hearts == 1 and " heart" or " hearts") })
end)
