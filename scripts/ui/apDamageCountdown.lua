local currentLevel = require("necro.game.level.CurrentLevel")
local hud = require("necro.render.hud.HUD")
local ui = require("necro.render.UI")

event.renderPlayerHUD.add("damageCountdown", {
	filter = "AP_damageCountdown",
	order = "damageCountdown"
}, function (entity)
	if not currentLevel.isSafe() and entity.AP_damageCountdown.active then
		return hud.drawText({
			alignX = 0.5,
			alignY = 1,
			element = "damageCountdown",
			text = tostring(entity.AP_damageCountdown.countdown),
			font = ui.Font.MEDIUM
		})
	end
end)
