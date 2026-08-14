event.tileSchemaBuild.add("apStairs", "init", function(tiles)
    tiles.LobbyStairsInaccessible = {
        descent = false,
        dance = false,
        inherit = "Stairs",
        markers = nil,
        texture = "mods/AP/gfx/tiles/stairs_inaccessible.png",
        type = "floor"
    }

    tiles.LobbyStairsDisabled = {
        descent = false,
        dance = false,
        inherit = "Stairs",
        markers = nil,
        texture = "mods/AP/gfx/tiles/stairs_disabled.png",
        type = "floor"
    }
end)
