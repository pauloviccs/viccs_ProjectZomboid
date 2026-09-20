-- media/lua/client/VICCS/Bridge/VICCS_SpatialEmitter.lua
-- Motor Espacial 3D e Projeção Acústica Isométrica (Build 42)
-- Converte posições do mundo em eixos de tela estéreo e computa atenuação de oclusão realista

VICCS = VICCS or {}
VICCS.Spatial = {}

-- Raiz de 2 pré-calculada para conversão isométrica rápida
local SQRT_2 = 1.41421356237

--- Verifica se o veículo está acusticamente fechado (todas as portas e janelas fechadas e intactas)
function VICCS.Spatial.isVehicleEnclosed(vehicle)
    if not vehicle then return true end
    local isEnclosed = true
    pcall(function()
        local partCount = vehicle:getPartCount()
        if not partCount or partCount <= 0 then return end
        
        for i = 0, partCount - 1 do
            local part = vehicle:getPartByIndex(i)
            if part then
                local win = part:getWindow()
                if win then
                    local open = (win.isOpen and win:isOpen())
                    local destroyed = (win.isDestroyed and win:isDestroyed())
                    if open or destroyed then
                        isEnclosed = false
                        return
                    end
                end
                local door = part:getDoor()
                if door then
                    local doorOpen = (door.isOpen and door:isOpen())
                    if doorOpen then
                        isEnclosed = false
                        return
                    end
                end
            end
        end
    end)
    return isEnclosed
end

function VICCS.Spatial.calculate3D(player, deviceX, deviceY, deviceZ, extraOccl)
    if not player then 
        return 0, 1.0, 0, { walls = 0, doors = 0, windows = 0, floors = 0 }, "outdoor", 0, 0 
    end
    
    local px = player:getX()
    local py = player:getY()
    local pz = player:getZ()
    
    local dx = deviceX - px
    local dy = deviceY - py
    local dz = (deviceZ - pz) * 3.5 -- Andares verticais pesam 3.5x mais na distância percebida
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    
    -- 1. Curva de atenuação de volume por distância (Rolloff cúbico/quadrático suave)
    local maxDist = VICCS.Config and VICCS.Config.MaxAudibleDistance or 35.0
    local volFactor = 0.0
    if dist < maxDist then
        volFactor = math.max(0.0, 1.0 - (dist / maxDist))
        volFactor = volFactor * volFactor
    end
    
    -- 2. Projeção de Coordenadas Isométricas para Eixos de Tela (Screen Space)
    -- No Project Zomboid o mapa é rotacionado a 45 graus:
    -- screenX (+) = Direita da tela, screenX (-) = Esquerda da tela
    -- screenY (+) = Para baixo na tela (frontal), screenY (-) = Para cima na tela (traseiro)
    local screenX = (dx - dy) / SQRT_2
    local screenY = (dx + dy) / SQRT_2
    
    -- Normaliza o pan estéreo (-1.0 = esquerda pura, +1.0 = direita pura)
    local screenDist = math.sqrt(screenX * screenX + screenY * screenY)
    local pan = 0.0
    if screenDist > 0.001 then
        pan = screenX / screenDist
    end
    pan = math.max(-1.0, math.min(1.0, pan))
    
    -- 3. Sonda Acústica de Oclusão (Paredes, Portas e Janelas)
    local occl = { walls = 0, doors = 0, windows = 0, floors = math.abs(deviceZ - pz), isBlocked = false }
    if VICCS.AcousticProbe and VICCS.AcousticProbe.traceAcoustics then
        occl = VICCS.AcousticProbe.traceAcoustics(deviceX, deviceY, deviceZ, px, py, pz)
    end
    
    -- 4. Cálculo Psicoacústico de Perda em Decibéis (dB) - Realismo de Alvenaria e Lataria
    local dbLoss = 0.0
    
    -- Fachada externa (Dentro vs Fora): Barreira maciça de alvenaria/madeira externa
    if occl.exteriorWall then
        dbLoss = dbLoss + 18.0 -- -18 dB base para paredes externas
    elseif occl.interiorWall then
        dbLoss = dbLoss + 12.0 -- -12 dB base para paredes de divisória interna
    end
    
    -- Barreiras adicionais interceptadas pelo raio Bresenham
    if occl.walls > 1 then
        dbLoss = dbLoss + ((occl.walls - 1) * 8.0) -- +8 dB por parede extra intermediária
    elseif occl.walls == 1 and not occl.exteriorWall and not occl.interiorWall then
        dbLoss = dbLoss + 14.0
    end
    
    -- Portas fechadas
    if occl.doors > 0 then
        dbLoss = dbLoss + (occl.doors * 10.0) -- -10 dB por porta fechada
    end
    
    -- Janelas fechadas
    if occl.windows > 0 then
        dbLoss = dbLoss + (occl.windows * 6.0) -- -6 dB por janela fechada
    end
    
    -- Andares de diferença (Lajes de concreto / teto de madeira)
    if occl.floors > 0 then
        dbLoss = dbLoss + (occl.floors * 16.0) -- -16 dB por andar
    end

    -- Oclusão de Lataria e Vidros do Veículo (Dentro do carro ouvindo fora, ou fora ouvindo som do carro)
    if extraOccl and (extraOccl.vehicleEnclosure or extraOccl.listenerInVehicle) then
        occl.vehicleEnclosure = true
        occl.windows = (occl.windows or 0) + 1
        dbLoss = dbLoss + 14.0 -- -14 dB de atenuação direta da cabine fechada
    end
    
    -- Multiplicador da Sandbox para Intensidade de Oclusão (0% a 100%)
    local occlIntensity = 1.0
    if VICCS.Config and VICCS.Config.getSandboxVar then
        local pct = VICCS.Config.getSandboxVar("SpatialOcclusionIntensity", 100)
        occlIntensity = math.max(0.0, math.min(1.0, (pct or 100) / 100.0))
    end
    
    if dbLoss > 0 then
        local effectiveDb = dbLoss * occlIntensity
        -- Converte perda em dB para ganho linear: G = 10^(-dB / 20)
        local occlLinearGain = math.pow(10.0, -effectiveDb / 20.0)
        -- Limita o ganho mínimo a 0.02 (2% do volume, impedindo silêncio absoluto irreconhecível)
        volFactor = volFactor * math.max(0.02, occlLinearGain)
    end
    
    -- 5. Classificação Acústica do Cômodo do Aparelho
    local cell = getCell and getCell()
    local devSq = cell and cell:getGridSquare(math.floor(deviceX), math.floor(deviceY), math.floor(deviceZ))
    local roomClass = "outdoor"
    if VICCS.RoomClassifier and VICCS.RoomClassifier.classify then
        roomClass = VICCS.RoomClassifier.classify(devSq)
    end
    
    return dist, volFactor, pan, occl, roomClass, screenX, screenY
end

print("[VICCS] SpatialEmitter v1.2.2 (Atenuação Psicoacústica de Paredes e Veículos) carregado.")
