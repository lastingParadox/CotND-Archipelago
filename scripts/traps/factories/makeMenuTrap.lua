local menu = require "necro.menu.Menu"

local trapSystem = require "AP.scripts.traps.trapSystem"

---Defines a trap that opens a chain of popup dialogs, each dismissed before the next.
---@param opts table
---  Required:
---    name        string   Trap id.
---    menuName    string   Registry key for event.menu.add (must be unique per trap).
---    flyaway     string   Shown to the first player on trigger.
---    title       string   Popup window title for every dialog in the chain.
---    messages    table    Ordered array of message strings (one popup per entry).
---  Optional:
---    buttonLabel string | function(index, total) -> string   Dismiss label, default "Got it!".
---@return table spec
local function makeMenuTrap(opts)
    assert(opts.name,        "makeMenuTrap: opts.name is required")
    assert(opts.menuName,    "makeMenuTrap: opts.menuName is required")
    assert(opts.flyaway,     "makeMenuTrap: opts.flyaway is required")
    assert(opts.title,       "makeMenuTrap: opts.title is required")
    assert(opts.messages and #opts.messages > 0,
        "makeMenuTrap: opts.messages must be a non-empty table")

    local buttonLabel = opts.buttonLabel or "Got it!"
    local total       = #opts.messages

    local function openDialog(remaining)
        if remaining <= 0 then
            trapSystem.stop(opts.name)
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

    return trapSystem.define({
        name     = opts.name,
        flyaway  = opts.flyaway,
        announce = trapSystem.Announce.FIRST,
        storage  = trapSystem.Storage.VOLATILE,
        stateful = true,
        finish   = function() openDialog(total) end,
    })
end

return { makeMenuTrap = makeMenuTrap }
