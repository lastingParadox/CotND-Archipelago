local function apLog(message, sev)
    local severity = sev or "info"
    print(string.format("[Archipelago]: [%s] %s", severity:upper(), message))
end

return {
    apLog = apLog,
}
