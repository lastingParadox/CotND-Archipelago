local currency = require "necro.game.item.Currency"

local apDiamondUtils = require("AP.scripts.utils.apDiamondUtils")
local apFlags = require("AP.scripts.utils.flags")

event.tileSchemaBuild.add("APDirtWallWithAPDiamonds", "init", function(tiles)
    tiles.DirtWallWithAPDiamonds = {
        digAPDiamonds = true,
        digEntity = false,
        inherit = "DirtWallWithGold",
    }
end)

event.tileDig.add("digAPDiamonds", "digEntity", function(ev)
    if not ev.suppressed and ev.tileInfo.digAPDiamonds then
        currency.create(apFlags.CURRENCY_AP_DIAMOND, ev.x, ev.y, apDiamondUtils.getDiamondAmountForTile(ev.x, ev.y))
    end
end)
