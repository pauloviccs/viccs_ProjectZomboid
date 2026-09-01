-- =============================================================================
-- VICCS PZMap - Client Telemetry Bridge (Lua)
-- Compatibilidade Oficial com Project Zomboid Build 41 e Build 42 (Unstable/Stable)
-- Grava telemetria em <User>/Zomboid/Lua/viccs_telemetry.json a cada ~500ms
-- =============================================================================

local VICCS_Client = {}
VICCS_Client.lastWriteTime = 0
VICCS_Client.writeIntervalMs = 450 -- Atualiza ~2x por segundo (0% impacto de FPS)
VICCS_Client.squadData = {}

--- Escapa caracteres especiais para formato JSON seguro
local function escapeJSON(str)
    if not str then return "" end
    str = tostring(str)
    str = str:gsub('\\', '\\\\')
    str = str:gsub('"', '\\"')
    str = str:gsub('\n', ' ')
    str = str:gsub('\r', '')
    str = str:gsub('\t', ' ')
    return str
end

--- Obtém o timestamp atual em milissegundos de forma segura
local function getCurrentTimeMs()
    if getTimeInMillis then
        return getTimeInMillis()
    end
    if getGameTime and getGameTime() and getGameTime().getCalender then
        local cal = getGameTime():getCalender()
        if cal and cal.getTimeInMillis then
            return cal:getTimeInMillis()
        end
    end
    if os and os.time then
        return os.time() * 1000
    end
    return 0
end

--- Grava o JSON de telemetria no diretório local do Zomboid de forma segura
function VICCS_Client.writeTelemetryFile(payload)
    if not getFileWriter then return end
    pcall(function()
        local file = getFileWriter("viccs_telemetry.json", true, false)
        if file then
            file:write(payload)
            file:close()
        end
    end)
end

--- Serializa a tabela de jogadores para JSON compatível com Rust / Tauri
function VICCS_Client.serializeJSON(players, serverName)
    local nowSec = math.floor(getCurrentTimeMs() / 1000)
    local json = '{"server_name":"' .. escapeJSON(serverName) .. '","is_connected":true,"timestamp":' .. nowSec .. ',"players":['
    
    for i, p in ipairs(players) do
        local comma = (i > 1) and "," or ""
        json = json .. comma .. '{'
        json = json .. '"id":"' .. escapeJSON(p.id) .. '",'
        json = json .. '"name":"' .. escapeJSON(p.name) .. '",'
        json = json .. '"steam_id":"' .. escapeJSON(p.steam_id) .. '",'
        json = json .. '"x":' .. string.format("%.2f", p.x or 0) .. ','
        json = json .. '"y":' .. string.format("%.2f", p.y or 0) .. ','
        json = json .. '"z":' .. math.floor(p.z or 0) .. ','
        json = json .. '"health":' .. string.format("%.1f", p.health or 100) .. ','
        json = json .. '"faction":"' .. escapeJSON(p.faction) .. '",'
        json = json .. '"is_alive":' .. (p.is_alive and "true" or "false") .. ','
        json = json .. '"is_self":' .. (p.is_self and "true" or "false")
        json = json .. '}'
    end
    
    json = json .. ']}'
    return json
end

--- Atualiza a telemetria do jogador local (Build 41 e Build 42)
function VICCS_Client.updateLocalPlayer()
    local player = (getSpecificPlayer and getSpecificPlayer(0)) or (getPlayer and getPlayer())
    if not player then return end

    local username = "Survivor"
    if player.getUsername and player:getUsername() then
        username = player:getUsername()
    elseif player.getDisplayName and player:getDisplayName() then
        username = player:getDisplayName()
    end

    local steamID = ""
    if player.getSteamID and player:getSteamID() then
        steamID = tostring(player:getSteamID())
    elseif player.getOnlineID and player:getOnlineID() then
        steamID = tostring(player:getOnlineID())
    end

    local x = (player.getX and player:getX()) or 0.0
    local y = (player.getY and player:getY()) or 0.0
    -- Em B42, Z-Levels vão de -32 (subsolos) até +32 (arranha-céus)
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

    local localEntry = {
        id = "p_local",
        name = username,
        steam_id = steamID,
        x = x,
        y = y,
        z = z,
        health = health,
        faction = factionName,
        is_alive = not isDead,
        is_self = true
    }

    -- Mescla o jogador local com a lista de aliados recebidos do servidor
    local allPlayers = { localEntry }
    if VICCS_Client.squadData then
        for _, ally in pairs(VICCS_Client.squadData) do
            if ally.name and ally.name ~= username then
                table.insert(allPlayers, ally)
            end
        end
    end

    local serverName = "Project Zomboid (Singleplayer / Local)"
    if isClient and isClient() then
        if getServerName and getServerName() then
            serverName = getServerName()
        else
            serverName = "Servidor Multiplayer"
        end
    end

    local jsonString = VICCS_Client.serializeJSON(allPlayers, serverName)
    VICCS_Client.writeTelemetryFile(jsonString)
end

--- Recebe atualização de esquadrão enviada pelo servidor multiplayer
function VICCS_Client.onServerCommand(module, command, args)
    if module == "VICCSRadar" and command == "UpdateTelemetry" and args and args.players then
        VICCS_Client.squadData = args.players
    end
end

--- Hook de ciclo no cliente (throttled para ~500ms)
function VICCS_Client.onTick()
    local now = getCurrentTimeMs()
    if (now - VICCS_Client.lastWriteTime) >= VICCS_Client.writeIntervalMs then
        VICCS_Client.lastWriteTime = now
        VICCS_Client.updateLocalPlayer()
    end
end

-- Registra os eventos no Project Zomboid
Events.OnTick.Add(VICCS_Client.onTick)
Events.OnServerCommand.Add(VICCS_Client.onServerCommand)

print("[VICCS PZMap] Client Tracker carregado e ativo (B41 / B42)! Telemetria em Zomboid/Lua/viccs_telemetry.json")
