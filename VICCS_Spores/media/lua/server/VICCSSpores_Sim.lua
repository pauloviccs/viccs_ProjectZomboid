-- =============================================================================
-- VICCS Spores - Motor de Simulacao Otimizado (Server / SP)
-- Versao: 1.0.4 (Hotfix: Metodo correto cm:getWindIntensity() com checagem segura)
-- =============================================================================

require "VICCSSpores_Grid"

local Sim = {}
VICCSSpores.Sim = Sim

local NEIGHBORS = {
    { -1,  0 },
    {  1,  0 },
    {  0, -1 },
    {  0,  1 }
}

local function getCellIndoors(cell)
    if cell.indoors ~= nil then
        return cell.indoors
    end
    
    local cellPixelX = cell.cx * VICCSSpores.CELL + 2
    local cellPixelY = cell.cy * VICCSSpores.CELL + 2
    local sq = getCell():getGridSquare(cellPixelX, cellPixelY, cell.z)
    
    if not sq then
        return nil
    end
    
    local indoors = not sq:isOutside() or sq:getRoom() ~= nil
    cell.indoors = indoors
    return indoors
end

local function getActivePlayerPositions()
    local positions = {}
    
    if isServer() then
        local players = getOnlinePlayers()
        if players then
            for i = 0, players:size() - 1 do
                local p = players:get(i)
                if p then
                    table.insert(positions, { x = p:getX(), y = p:getY(), z = p:getZ() })
                end
            end
        end
    else
        local p = getPlayer()
        if p then
            table.insert(positions, { x = p:getX(), y = p:getY(), z = p:getZ() })
        end
    end
    
    return positions
end

local function isNearAnyPlayer(cx, cy, z, playerPositions, radius)
    local cellCenterX = cx * VICCSSpores.CELL + 2
    local cellCenterY = cy * VICCSSpores.CELL + 2
    local radiusSq = radius * radius
    
    for _, pos in ipairs(playerPositions) do
        if math.abs(pos.z - z) <= 1 then
            local dx = cellCenterX - pos.x
            local dy = cellCenterY - pos.y
            if (dx * dx + dy * dy) <= radiusSq then
                return true
            end
        end
    end
    
    return false
end

function Sim.tick()
    if not VICCSSpores.opt("Enabled", true) then return end
    
    local d = VICCSSpores.Grid.data()
    if not d.cells then return end
    
    local playerPositions = getActivePlayerPositions()
    if #playerPositions == 0 then return end
    
    local currentCells = d.cells
    local nextCells = {}
    local activeCount = 0
    local maxCells = VICCSSpores.opt("MaxActiveCells", 400)
    local simRadius = VICCSSpores.opt("SimRadiusTiles", VICCSSpores.ACTIVE_RADIUS_TILES)
    local currentHour = getGameTime() and getGameTime():getWorldAgeHours() or 0
    
    -- Leitura segura do clima no B42
    local cm = getClimateManager()
    local isRaining = false
    local windSpeed = 0.0
    if cm then
        if cm.isRaining then isRaining = cm:isRaining() end
        if cm.getWindIntensity then
            windSpeed = cm:getWindIntensity()
        elseif cm.getWindSpeedMovement then
            windSpeed = cm:getWindSpeedMovement()
        end
    end
    
    for k, cell in pairs(currentCells) do
        if cell.v >= 0.5 then
            local cx, cy, z = cell.cx, cell.cy, cell.z
            
            if not isNearAnyPlayer(cx, cy, z, playerPositions, simRadius) then
                nextCells[k] = cell
            else
                local indoors = getCellIndoors(cell)
                
                if indoors == nil then
                    nextCells[k] = cell
                else
                    local val = cell.v
                    
                    -- Difusao horizontal
                    local spreadPerNeighbor = val * 0.12
                    val = val - (spreadPerNeighbor * 4)
                    
                    for _, n in ipairs(NEIGHBORS) do
                        local ncx = cx + n[1]
                        local ncy = cy + n[2]
                        local nk = VICCSSpores.Grid.makeKey(ncx, ncy, z)
                        local nc = nextCells[nk] or currentCells[nk] or {
                            cx = ncx, cy = ncy, z = z, v = 0.0,
                            t = currentHour, indoors = nil
                        }
                        nc.v = math.min(VICCSSpores.MAX_CONC, nc.v + spreadPerNeighbor)
                        nextCells[nk] = nc
                    end
                    
                    -- Gravidade
                    if z > -2 then
                        local lowerZ = z - 1
                        local downSpread = val * 0.08
                        val = val - downSpread
                        local downKey = VICCSSpores.Grid.makeKey(cx, cy, lowerZ)
                        local downCell = nextCells[downKey] or currentCells[downKey] or {
                            cx = cx, cy = cy, z = lowerZ, v = 0.0,
                            t = currentHour, indoors = nil
                        }
                        downCell.v = math.min(VICCSSpores.MAX_CONC, downCell.v + downSpread)
                        nextCells[downKey] = downCell
                    end
                    
                    -- Decaimento
                    local decayRate = indoors and 0.985 or 0.92
                    if not indoors then
                        if windSpeed > 0.3 then decayRate = decayRate - (windSpeed * 0.04) end
                        if isRaining then decayRate = decayRate - 0.03 end
                    end
                    
                    val = val * math.max(0.5, decayRate)
                    
                    if val >= 0.5 and activeCount < maxCells then
                        cell.v = val
                        cell.t = currentHour
                        nextCells[k] = cell
                        activeCount = activeCount + 1
                    end
                end
            end
        end
    end
    
    d.cells = nextCells
    
    if VICCSSpores.Net and VICCSSpores.Net.syncAirToPlayers then
        VICCSSpores.Net.syncAirToPlayers()
    end
end

Events.EveryOneMinute.Add(function()
    local ok, err = pcall(Sim.tick)
    if not ok then
        print("[VICCS Spores ERROR no Sim.tick]: " .. tostring(err))
    end
end)

print("[VICCS Spores v" .. VICCSSpores.VERSION .. "] Simulacao Server-Side v1.0.4 carregada.")
