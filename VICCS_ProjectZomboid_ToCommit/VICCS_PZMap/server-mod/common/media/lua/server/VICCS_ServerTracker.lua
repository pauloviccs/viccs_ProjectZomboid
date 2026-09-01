-- =============================================================================
-- VICCS PZMap - Server Telemetry Bridge (Lua)
-- Compatibilidade Oficial com Project Zomboid Build 41 e Build 42
-- Transmite membros da facção e aliados para clientes autorizados
-- =============================================================================

if not isServer or not isServer() then return end

local VICCS_Server = {}
VICCS_Server.intervalTicks = 30 -- ~1 vez por segundo
VICCS_Server.tickCounter = 0

--- Coleta e formata a telemetria de todos os jogadores online no servidor
function VICCS_Server.collectTelemetry()
    if not getOnlinePlayers then return nil end
    local players = getOnlinePlayers()
    if not players or players:size() == 0 then return nil end

    local payload = {}

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            local username = (player.getUsername and player:getUsername()) or "Unknown"
            local steamID = ""
            if player.getSteamID and player:getSteamID() then
                steamID = tostring(player:getSteamID())
            elseif player.getOnlineID and player:getOnlineID() then
                steamID = tostring(player:getOnlineID())
            end

            local x = (player.getX and player:getX()) or 0.0
            local y = (player.getY and player:getY()) or 0.0
            local z = (player.getZ and player:getZ()) or 0

            local health = 100.0
            if player.getBodyDamage then
                local bodyDamage = player:getBodyDamage()
                if bodyDamage and bodyDamage.getOverallBodyHealth then
                    health = bodyDamage:getOverallBodyHealth()
                end
            end

            local isDead = false
            if player.isDead then
                isDead = player:isDead()
            end

            local factionName = "Survivors"
            if Faction and Faction.getPlayerFaction then
                local status, faction = pcall(Faction.getPlayerFaction, username)
                if status and faction and faction.getName then
                    factionName = faction:getName() or "Survivors"
                end
            end

            table.insert(payload, {
                id = "p_" .. username,
                name = username,
                steam_id = steamID,
                x = x,
                y = y,
                z = z,
                health = health,
                faction = factionName,
                is_alive = not isDead,
                is_self = false
            })
        end
    end

    return payload
end

--- Envia os dados de telemetria para os clientes via Server Command
function VICCS_Server.broadcast()
    local telemetry = VICCS_Server.collectTelemetry()
    if telemetry and #telemetry > 0 then
        sendServerCommand("VICCSRadar", "UpdateTelemetry", { players = telemetry })
    end
end

--- Hook de ciclo no loop do servidor
function VICCS_Server.onTick()
    VICCS_Server.tickCounter = VICCS_Server.tickCounter + 1
    if VICCS_Server.tickCounter >= VICCS_Server.intervalTicks then
        VICCS_Server.tickCounter = 0
        VICCS_Server.broadcast()
    end
end

Events.OnTick.Add(VICCS_Server.onTick)
print("[VICCS PZMap] Server Radar Bridge ativo no servidor dedicado (B41 / B42)!")
