VICCS = VICCS or {}
VICCS.Spatial = {}

-- Calcula os dados 3D de um aparelho em relacao ao jogador
function VICCS.Spatial.calculate3D(player, deviceX, deviceY, deviceZ)
    if not player then return 0, 0, false end
    
    local px = player:getX()
    local py = player:getY()
    local pz = player:getZ()
    
    -- Distancia Euclidiana 3D (Z tem peso 3x maior para representar andares de predio)
    local dx = deviceX - px
    local dy = deviceY - py
    local dz = (deviceZ - pz) * 3.0
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    
    -- Curva de atenuacao de volume por distancia (Rolloff suave)
    local maxDist = VICCS.Config.MaxAudibleDistance
    local volFactor = 0.0
    if dist < maxDist then
        volFactor = math.max(0.0, 1.0 - (dist / maxDist))
        -- Curva quadratica para sensacao acustica natural
        volFactor = volFactor * volFactor
    end
    
    -- Pan Estereo (-1.0 = esquerda, +1.0 = direita)
    -- No PZ a orientacao e isometrica (45 graus)
    local playerDir = player:getDirectionAngle() -- angulo em graus (0 a 360)
    local soundAngle = math.deg(math.atan2(dy, dx))
    local relAngle = (soundAngle - playerDir) % 360
    if relAngle > 180 then relAngle = relAngle - 360 end
    
    -- Converte o angulo relativo em pan estéreo
    local pan = math.sin(math.rad(relAngle))
    pan = math.max(-1.0, math.min(1.0, pan))
    
    -- Deteccao de oclusao (se ha paredes/portas entre o jogador e o aparelho)
    local playerSquare = player:getCurrentSquare()
    local cell = getCell()
    local deviceSquare = cell and cell:getGridSquare(deviceX, deviceY, deviceZ) or nil
    
    local isOccluded = false
    if playerSquare and deviceSquare then
        -- Se estiverem em salas (rooms) diferentes ou um dentro e outro fora
        local pRoom = playerSquare:getRoom()
        local dRoom = deviceSquare:getRoom()
        if pRoom ~= dRoom then
            isOccluded = true
        end
    end
    
    return dist, volFactor, pan, isOccluded
end
