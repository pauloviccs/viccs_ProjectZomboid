-- media/lua/client/VICCS/Logic/VICCS_AcousticProbe.lua
-- Sonda Acústica com Algoritmo Bresenham 2D e Detecção Nativa de Paredes/Cômodos (Build 42)
-- Calcula a oclusão sonora causada por paredes, portas fechadas, janelas e andares

VICCS = VICCS or {}
VICCS.AcousticProbe = {}

local probeCache = {}
local CACHE_TTL_SECONDS = 1.5 -- Validade do cache de raio acústico
local MAX_RAY_STEPS = 30      -- Limite rígido de passos no grid para garantir 0 impacto no FPS

-- Limpa entradas antigas do cache periodicamente
local lastCleanupTime = 0
local function cleanOldCache(currentTime)
    if currentTime - lastCleanupTime < 5.0 then return end
    lastCleanupTime = currentTime
    for key, entry in pairs(probeCache) do
        if currentTime - entry.time > CACHE_TTL_SECONDS then
            probeCache[key] = nil
        end
    end
end

-- Traça o raio acústico discreto entre o emissor e o ouvinte
function VICCS.AcousticProbe.traceAcoustics(devX, devY, devZ, playerX, playerY, playerZ)
    local x0 = math.floor(devX or 0)
    local y0 = math.floor(devY or 0)
    local z0 = math.floor(devZ or 0)
    
    local x1 = math.floor(playerX or 0)
    local y1 = math.floor(playerY or 0)
    local z1 = math.floor(playerZ or 0)
    
    local currentTime = getTimestamp and getTimestamp() or os.time()
    cleanOldCache(currentTime)
    
    -- Chave estável para reutilização imediata entre frames
    local cacheKey = string.format("%d_%d_%d_%d_%d_%d", x0, y0, z0, x1, y1, z1)
    local cached = probeCache[cacheKey]
    if cached and (currentTime - cached.time < CACHE_TTL_SECONDS) then
        return cached.data
    end
    
    local occl = {
        walls = 0,
        exteriorWall = false,
        interiorWall = false,
        doors = 0,
        windows = 0,
        floors = math.abs(z0 - z1),
        isBlocked = false
    }
    
    local cell = getCell and getCell()
    if not cell then
        probeCache[cacheKey] = { time = currentTime, data = occl }
        return occl
    end
    
    -- Se estiverem no mesmo quadrado exato e mesmo andar
    if x0 == x1 and y0 == y1 and z0 == z1 then
        probeCache[cacheKey] = { time = currentTime, data = occl }
        return occl
    end
    
    local devSq = cell:getGridSquare(x0, y0, z0)
    local playerSq = cell:getGridSquare(x1, y1, z1)
    
    -- 1. Detecção Estrutural por Limites de Cômodo (Infalível para dentro/fora e salas)
    if devSq and playerSq then
        local devRoom = nil
        local playerRoom = nil
        pcall(function() devRoom = devSq:getRoom() end)
        pcall(function() playerRoom = playerSq:getRoom() end)
        
        -- Caso A: Um está dentro de uma casa/quarto e o outro está no jardim/rua
        if (devRoom == nil and playerRoom ~= nil) or (devRoom ~= nil and playerRoom == nil) then
            occl.exteriorWall = true
            occl.walls = occl.walls + 1
        -- Caso B: Ambos estão dentro de construções, mas em cômodos diferentes
        elseif devRoom ~= nil and playerRoom ~= nil and devRoom ~= playerRoom then
            occl.interiorWall = true
            occl.walls = occl.walls + 1
        end
    end
    
    -- 2. Bresenham 2D Line Drawing (Varredura Discreta de Colisões no Grid)
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = (x0 < x1) and 1 or -1
    local sy = (y0 < y1) and 1 or -1
    local err = dx - dy
    
    local cx = x0
    local cy = y0
    local steps = 0
    
    local prevSq = devSq
    
    while steps < MAX_RAY_STEPS do
        steps = steps + 1
        
        local currSq = cell:getGridSquare(cx, cy, z0)
        
        if prevSq and currSq and (prevSq ~= currSq) then
            -- A. Checa se há parede entre os blocos adjacentes (API nativa do PZ)
            local hasWallBetween = false
            pcall(function()
                if prevSq.isWallTo and prevSq:isWallTo(currSq) then
                    hasWallBetween = true
                elseif currSq.isWallTo and currSq:isWallTo(prevSq) then
                    hasWallBetween = true
                end
            end)
            if hasWallBetween then
                occl.walls = occl.walls + 1
            end
            
            -- B. Checa se há porta entre os blocos
            local hasDoorBetween = false
            pcall(function()
                if prevSq.isDoorTo and prevSq:isDoorTo(currSq) then
                    hasDoorBetween = true
                elseif currSq.isDoorTo and currSq:isDoorTo(prevSq) then
                    hasDoorBetween = true
                end
            end)
            if hasDoorBetween then
                local isDoorClosed = true
                pcall(function()
                    if prevSq.isDoorBlockedTo and not prevSq:isDoorBlockedTo(currSq) then
                        isDoorClosed = false
                    end
                end)
                if isDoorClosed then
                    occl.doors = occl.doors + 1
                end
            end
            
            -- C. Checa se há janela entre os blocos
            local hasWindowBetween = false
            pcall(function()
                if (prevSq.isWindowTo and prevSq:isWindowTo(currSq)) or 
                   (currSq.isWindowTo and currSq:isWindowTo(prevSq)) then
                    hasWindowBetween = true
                end
            end)
            if hasWindowBetween then
                occl.windows = occl.windows + 1
            end
        end
        
        -- Inspeciona objetos montados no quadrado atual (portas, janelas, barricadas)
        if currSq and (cx ~= x0 or cy ~= y0) then
            local objs = currSq.getObjects and currSq:getObjects()
            if objs then
                local count = objs:size()
                for i = 0, count - 1 do
                    local obj = objs:get(i)
                    if obj then
                        if instanceof(obj, "IsoDoor") then
                            local isOpen = false
                            pcall(function() isOpen = obj:IsOpen() end)
                            if not isOpen then
                                occl.doors = occl.doors + 1
                            end
                        elseif instanceof(obj, "IsoWindow") then
                            local isPassable = false
                            pcall(function()
                                isPassable = (obj.IsOpen and obj:IsOpen()) or (obj.isSmashed and obj:isSmashed())
                            end)
                            if not isPassable then
                                occl.windows = occl.windows + 1
                            end
                        elseif instanceof(obj, "IsoThumpable") then
                            pcall(function()
                                if obj:isDoor() and not obj:IsOpen() then
                                    occl.doors = occl.doors + 1
                                elseif obj:isWindow() then
                                    occl.windows = occl.windows + 1
                                end
                            end)
                        end
                    end
                end
            end
        end
        
        prevSq = currSq
        
        -- Chegou ao quadrado do ouvinte
        if cx == x1 and cy == y1 then
            break
        end
        
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            cx = cx + sx
        end
        if e2 < dx then
            err = err + dx
            cy = cy + sy
        end
    end
    
    -- Marca como bloqueado caso haja pelo menos uma barreira física real
    occl.isBlocked = (occl.walls > 0 or occl.doors > 0 or occl.windows > 0 or occl.floors > 0 or occl.exteriorWall or occl.interiorWall)
    
    probeCache[cacheKey] = { time = currentTime, data = occl }
    return occl
end

-- Limpa todo o cache caso o jogador mude de nível ou teleporte
function VICCS.AcousticProbe.invalidateCache()
    probeCache = {}
end

print("[VICCS] AcousticProbe v1.2.3 (Bresenham + Paredes Nativas + Limites de Cômodo) inicializado.")
