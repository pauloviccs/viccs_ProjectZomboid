-- =============================================================================
-- VICCS Spores - Rede Multiplayer Seamless & Sincronizacao Local (Server / SP)
-- Versao: 1.2.0 (High-Performance Spatial Filtering & Pre-parsed Cell Structs)
-- =============================================================================

require "VICCSSpores_Grid"

VICCSSpores.Net = VICCSSpores.Net or {}
local Net = VICCSSpores.Net

function Net.syncAirToPlayers()
    -- Modo Single Player: Sincroniza apenas celulas no raio visual ativo do jogador
    if not isServer() and not isClient() then
        local player = getPlayer()
        if player then
            local px = player:getX()
            local py = player:getY()
            local pz = math.floor(player:getZ())
            local syncRadiusSq = 28 * 28 -- Raio de 28 tiles (cobre qualquer resolucao/zoom)
            
            local d = VICCSSpores.Grid.data()
            local nearby = {}
            for k, c in pairs(d.cells or {}) do
                if c and type(c.v) == "number" and c.v >= 0.5 and math.abs(c.z - pz) <= 1 then
                    local cellX = c.cx * VICCSSpores.CELL + 2
                    local cellY = c.cy * VICCSSpores.CELL + 2
                    local dx = cellX - px
                    local dy = cellY - py
                    if (dx * dx + dy * dy) <= syncRadiusSq then
                        nearby[k] = { cx = c.cx, cy = c.cy, z = c.z, v = c.v }
                    end
                end
            end
            VICCSSpores.Grid.clientCache = nearby
        end
        return
    end
    
    -- Modo Servidor Dedicado / Host MP
    if isServer() then
        local players = getOnlinePlayers()
        if not players then return end
        
        local d = VICCSSpores.Grid.data()
        local allCells = d.cells or {}
        
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p then
                local px = p:getX()
                local py = p:getY()
                local pz = math.floor(p:getZ())
                local syncRadiusSq = 28 * 28
                
                local nearbyCells = {}
                
                for k, cell in pairs(allCells) do
                    if cell.v >= 0.5 and math.abs(cell.z - pz) <= 1 then
                        local cellX = cell.cx * VICCSSpores.CELL + 2
                        local cellY = cell.cy * VICCSSpores.CELL + 2
                        local dx = cellX - px
                        local dy = cellY - py
                        if (dx * dx + dy * dy) <= syncRadiusSq then
                            nearbyCells[k] = { cx = cell.cx, cy = cell.cy, z = cell.z, v = cell.v }
                        end
                    end
                end
                
                sendServerCommand(p, "VICCSSpores", "syncNearby", { cells = nearbyCells })
            end
        end
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= "VICCSSpores" or not player then return end
    
    if command == "cleanArea" and args then
        local x = args.x or player:getX()
        local y = args.y or player:getY()
        local z = args.z or player:getZ()
        local power = args.power or VICCSSpores.opt("DecontamBleachPower", 50.0)
        
        local dx = player:getX() - x
        local dy = player:getY() - y
        if (dx * dx + dy * dy) <= 25 then
            VICCSSpores.Grid.clean(x, y, z, power)
            
            local cx, cy = VICCSSpores.Grid.cellOf(x, y)
            local cz = math.floor(z)
            local newConc = VICCSSpores.Grid.get(x, y, cz)
            local key = VICCSSpores.Grid.makeKey(cx, cy, cz)
            
            sendServerCommand("VICCSSpores", "cellUpdated", { key = key, conc = newConc })
        end
    elseif command == "debugAdd" and args and (isDebugEnabled() or player:isAccessLevel("admin")) then
        local x = args.x or player:getX()
        local y = args.y or player:getY()
        local z = args.z or player:getZ()
        local amt = args.amount or 50.0
        VICCSSpores.Grid.add(x, y, z, amt)
        Net.syncAirToPlayers()
    elseif command == "debugClearAll" and (isDebugEnabled() or player:isAccessLevel("admin")) then
        local d = VICCSSpores.Grid.data()
        d.cells = {}
        Net.syncAirToPlayers()
    end
end

if isServer() then
    Events.OnClientCommand.Add(onClientCommand)
end

print("[VICCS Spores v" .. VICCSSpores.VERSION .. "] Rede Multiplayer Seamless v1.2.0 (High-Perf Spatial Filter) inicializada.")
