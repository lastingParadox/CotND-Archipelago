local rng = require "necro.game.system.RNG"

local apDiamondUtils = {}

local digWeights = { 40, 25, 20, 15 }
local digWeightTotal = 100

-- same RNG channel as the dig event so monocle preview matches the actual drop
function apDiamondUtils.getDiamondAmountForTile(x, y)
    local channel = rng.makeChannel(rng.getDungeonSeed() + x * 10000 + y)
    local roll = rng.range(1, digWeightTotal, channel)
    local cumulative = 0
    for i, w in ipairs(digWeights) do
        cumulative = cumulative + w
        if roll <= cumulative then return i end
    end
    return 1
end

return apDiamondUtils
