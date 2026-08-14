local PriceRandomization = {
    VANILLA = 0,
    VANILLA_RAND = 1,
    ITEM_CLASS = 2,
    COMPLETE = 3,
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
    [0] = "Bonus Potion Disabled!",
    [1] = "Bonus Potion Every Run!",
    [2] = "Bonus Potion Every Zone!",
    [3] = "Bonus Potion Every Floor!",
}

-- Station title; PotionModes above is the flyaway announcement.
local PotionModeTitles = {
    [0] = "Potion Disabled",
    [1] = "Potion Every Run",
    [2] = "Potion Every Zone",
    [3] = "Potion Every Floor",
}

return {
    PotionModes = PotionModes,
    PotionModeTitles = PotionModeTitles,
    PriceRandomization = PriceRandomization,
    MessageTypes = MessageTypes,
    DeathlinkTypes = DeathlinkTypes
}
