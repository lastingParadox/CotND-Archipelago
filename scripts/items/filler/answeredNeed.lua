local apGrants = require("AP.scripts.items.apGrants")

-- The scroll itself, not its effect: reading a Scroll of Need blind can glass your own
-- inventory, so when it goes off is the player's call.
apGrants.defineItemFiller("APScrollNeed", "ScrollNeed")
