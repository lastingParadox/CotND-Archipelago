local menu   = require "necro.menu.Menu"
local player = require "necro.game.character.Player"

local apFlyaways = require "AP.scripts.ui.apFlyaways"

---Creates a sequential-dialog-chain trap and returns its trigger function.
---
---On trigger the trap shows a flyaway to the first local player, then opens a
---series of popup dialogs that must each be dismissed before the next appears.
---The trap returns false (stays queued) while a chain is already open.
---
---@param opts table
---  Required:
---    menuName    string   Registry key for event.menu.add (must be unique per trap).
---    flyawayText string   Shown to the first player on trigger.
---    title       string   Popup window title for every dialog in the chain.
---    messages    table    Ordered array of message strings (one popup per entry).
---  Optional:
---    buttonLabel string | function(index, total) -> string
---                         Label for the dismiss button. When a function, receives the
---                         1-based dialog index and total count. Default: "Got it!"
---@return function trapFn
local function makeMenuTrap(opts)
    assert(opts.menuName,    "makeMenuTrap: opts.menuName is required")
    assert(opts.flyawayText, "makeMenuTrap: opts.flyawayText is required")
    assert(opts.title,       "makeMenuTrap: opts.title is required")
    assert(opts.messages and #opts.messages > 0,
        "makeMenuTrap: opts.messages must be a non-empty table")

    local buttonLabel = opts.buttonLabel or "Got it!"
    local total       = #opts.messages

    local chainActive = false
    chainActive = script.persist(function() return chainActive end)

    local function openDialog(remaining)
        if remaining <= 0 then
            chainActive = false
            return
        end

        local index   = total - remaining + 1
        local bLabel  = type(buttonLabel) == "function"
            and buttonLabel(index, total)
            or  buttonLabel

        local function onClose()
            openDialog(remaining - 1)
        end

        menu.open(opts.menuName, {
            message     = opts.messages[index],
            buttonLabel = bLabel,
            onClose     = onClose,
        })
    end

    -- Register the menu renderer once at factory-call time.
    event.menu.add(opts.menuName, opts.menuName, function(ev)
        local arg     = ev.arg or {}
        local entries = {}

        for line in (arg.message or ""):gmatch("[^\n]+") do
            entries[#entries + 1] = { label = line }
        end

        entries[#entries + 1] = {}  -- spacer

        local function dismiss()
            menu.close()
            if arg.onClose then arg.onClose() end
        end

        entries[#entries + 1] = {
            label  = arg.buttonLabel or "Got it!",
            action = dismiss,
        }

        ev.menu = {
            label        = opts.title,
            entries      = entries,
            escapeAction = dismiss,
            popup        = true,
        }
    end)

    -- Clear the active flag on level transition (menu force-closed by the game).
    event.gameStateLevel.add("AP" .. opts.menuName .. "Clear",
        { order = "splitScreen" },
        function()
            chainActive = false
        end
    )

    return function(ev)
        if chainActive then return false end

        local trapSuccess = false
        local notified    = false

        for _, entity in ipairs(player.getPlayerEntities()) do
            if entity and entity.playableCharacter then
                if not notified then
                    apFlyaways.addToFlyawayQueue({ entity = entity, text = opts.flyawayText })
                    notified = true
                end
                trapSuccess = true
            end
        end

        if trapSuccess then
            chainActive = true
            openDialog(total)
        end

        return trapSuccess
    end
end

return { makeMenuTrap = makeMenuTrap }
