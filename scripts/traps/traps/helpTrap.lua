local makeMenuTrap = (require "AP.scripts.traps.factories.makeMenuTrap").makeMenuTrap
local TrapHandler  = require "AP.scripts.traps.trapHandler"

local helpTips = {
    "Helpful Tip: Moving on the beat increases your\nGroove Chain! You already knew this.",
    "Helpful Tip: Enemies also move on the beat.\nHopefully this is not news to you.",
    "Helpful Tip: Taking damage resets your Groove Chain.\nPerhaps try to avoid that.",
    "Helpful Tip: The shopkeeper sells items for gold.\nGold is obtained by killing enemies. Good luck!",
    "Helpful Tip: These tips have been brought to you\nby the Archipelago Redux Mod. You're welcome.",
}

TrapHandler.register("HelpTrap", makeMenuTrap({
    menuName    = "archipelagoHelpTrap",
    flyawayText = "Help trap!",
    title       = "Helpful Tips",
    messages    = helpTips,
    buttonLabel = function(index, total)
        return "Got it! (" .. index .. "/" .. total .. ")"
    end,
}))
