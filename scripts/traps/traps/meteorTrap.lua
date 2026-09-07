local color       = require "system.utils.Color"
local damage      = require "necro.game.system.Damage"
local objectMap   = require "necro.game.object.Map"
local overlay     = require "necro.render.Overlay"
local rng         = require "necro.game.system.RNG"
local screenShake = require "necro.render.ScreenShake"
local sound       = require "necro.audio.Sound"
local tile        = require "necro.game.tile.Tile"
local timer       = require "system.utils.Timer"

local apFlags    = require "AP.scripts.utils.flags"
local trapSystem = require "AP.scripts.traps.trapSystem"

trapSystem.define({
    name    = "MeteorTrap",
    flyaway = "Meteor!",
    start   = function(ctx)
        overlay.add({
            color   = color.rgba(255, 255, 255, 230),
            fadeIn  = timer.milliseconds(0),
            sustain = timer.milliseconds(400),
            fadeOut = timer.milliseconds(500),
            layer   = overlay.Layer.HIGH,
        })
        sound.playUI("dragonRoar")
        sound.playUI("ogreDownswing")

        ctx.state.damaged = {}
    end,
    apply   = function(ctx)
        local entity = ctx.entity
        screenShake.createOnEntity(entity, 0.5, 50)

        local px = entity.position.x
        local py = entity.position.y

        for dx = -5, 5 do
            for dy = -5, 5 do
                local d2 = dx * dx + dy * dy
                local r = rng.range(3, 4, ctx.channel)
                if d2 <= r * r then
                    local tx = px + dx
                    local ty = py + dy
                    local info = tile.getInfo(tx, ty)
                    if info.isFloor and not info.immutable then
                        tile.setType(tx, ty, "HotCoals")
                    end
                    for _, target in objectMap.entitiesWithComponent(tx, ty, "killable") do
                        if target and target.killable and not target.killable.dead
                                and not ctx.state.damaged[target.id] then
                            ctx.state.damaged[target.id] = true
                            damage.inflict({
                                victim     = target,
                                damage     = 5,
                                type       = apFlags.DAMAGE_DEATH_LINK,
                                killerName = "Meteor",
                            })
                        end
                    end
                end
            end
        end
    end,
})
