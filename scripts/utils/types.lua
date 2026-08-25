-- Names rather than indices, so an option gaining a member shifts nothing.
local PriceRandomization = {
    VANILLA = "Vanilla",
    VANILLA_RAND = "Vanilla Rand",
    ITEM_CLASS = "Item Class",
    COMPLETE = "Complete",
}

local MessageTypes = {
    STATE = "State",
    ITEMS = "Items",
    LOCATIONS = "Locations",
    DEATH = "Death",
    SETDEATHLINK = "SetDeathLink",
    DISCONNECTED = "Disconnected",
    LOCATION_INFO = "LocationInfo",
    CHAT = "Chat"
}

local DeathlinkTypes = {
    ABSOLUTE = "Absolute",
    TEMPO = "Tempo",
    MARV = "Marv"
}

local PotionModes = {
    [0] = "Bonus Potions Disabled!",
    [1] = "1 Potion on Run Start!",
    [2] = "2 Potions on Run Start!",
    [3] = "3 Potions on Run Start!",
}

return {
    PotionModes = PotionModes,
    PriceRandomization = PriceRandomization,
    MessageTypes = MessageTypes,
    DeathlinkTypes = DeathlinkTypes
}
