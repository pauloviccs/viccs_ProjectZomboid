-- media/lua/client/VICCS/VICCS_Main.lua
-- Orquestrador central: Gerencia dispositivos ativos, audio 3D, atracao de zumbis e exibicao de UIs

require "VICCS/UI/VICCS_UI_Theme"
require "VICCS/UI/VICCS_UI_Components"
require "VICCS/UI/VICCS_UI_RadioDock"
require "VICCS/UI/VICCS_UI_ScreenPlayer"
require "VICCS/Logic/VICCS_SilentChannel"

VICCS = VICCS or {}
VICCS.Main = {}

local tickCounter = 0
local activeDevices = {}
local currentActiveWindow = nil
local wasGamePaused = false
local pauseStartTime = 0

function VICCS.Main.getPlayingDevice(id)
    return activeDevices[id]
end

function VICCS.Main.isDevicePlaying(id)
    return activeDevices[id] ~= nil
end

function VICCS.Main.registerPlayingDevice(id, deviceObj, x, y, z, baseVolume, url, deviceType, offsetSec)
    local devRecord = {
        obj = deviceObj,
        x = x or 0,
        y = y or 0,
        z = z or 0,
        volume = baseVolume or 0.7,
        url = url,
        deviceType = deviceType or "RADIO",
        isHeadphones = false,
        startedAt = os.time() - (offsetSec or 0),
        pausedOffset = offsetSec or 0,
        isPaused = false,
        haloTimer = 0,
        savedChannel = nil
    }
    activeDevices[id] = devRecord
    
    -- 0. Suporte inicial dinâmico a Veículos
    if devRecord.deviceType == "VEHICLE" then
        local vehicle = nil
        if deviceObj then
            if instanceof(deviceObj, "BaseVehicle") then
                vehicle = deviceObj
            elseif deviceObj.getVehicle and deviceObj:getVehicle() then
                vehicle = deviceObj:getVehicle()
            elseif deviceObj.getParent and instanceof(deviceObj:getParent(), "BaseVehicle") then
                vehicle = deviceObj:getParent()
            end
        end
        if vehicle then
            devRecord.vehicleObj = vehicle
            devRecord.x = vehicle:getX()
            devRecord.y = vehicle:getY()
            devRecord.z = vehicle:getZ()
            local pVeh = player and player.getVehicle and player:getVehicle()
            devRecord.isListenerInside = (pVeh ~= nil and pVeh == vehicle)
        end
    end

    -- Salva o estado no ModData do objeto no mundo para persistencia total
    pcall(function()
        if deviceObj and deviceObj.getModData then
            local md = deviceObj:getModData()
            md.viccsMedia = {
                state = "PLAYING",
                url = url,
                volume = devRecord.volume,
                deviceType = devRecord.deviceType,
                startedAt = devRecord.startedAt
            }
            if deviceObj.transmitModData then deviceObj:transmitModData() end
        end
    end)
    
    -- Garante que o aparelho esteja ligado no motor vanilla para consumir energia/bateria
    pcall(function()
        local dd = deviceObj and deviceObj.getDeviceData and deviceObj:getDeviceData()
        if dd and not dd:getIsTurnedOn() then
            if dd.setIsTurnedOn then
                dd:setIsTurnedOn(true)
            end
        end
    end)
    
    -- Garante que o aparelho esteja ligado para o consumo de energia vanilla
    if devRecord.deviceType == "TELEVISION" and deviceObj then
        pcall(function()
            local dd = deviceObj.getDeviceData and deviceObj:getDeviceData()
            if dd and not dd:getIsTurnedOn() and dd.setIsTurnedOn then
                dd:setIsTurnedOn(true)
            end
        end)
    end
    
    -- Dispara Halo Notify visual no jogador e no aparelho fisico (ASCII puro sem quebra de fonte)
    local haloText = getText("UI_VICCS_NowPlaying")
    if not haloText or haloText == "UI_VICCS_NowPlaying" or string.find(haloText, "♪") then
        haloText = "[ * Em Reproducao * ]"
    end
    
    local player = getPlayer()
    if player and HaloTextHelper and HaloTextHelper.addGoodText then
        HaloTextHelper.addGoodText(player, haloText)
    end
    
    if deviceObj and devRecord.deviceType ~= "CDPLAYER" and devRecord.deviceType ~= "VEHICLE" and not instanceof(deviceObj, "VehiclePart") and deviceObj.AddDeviceText then
        pcall(function()
            deviceObj:AddDeviceText(haloText, 0.0, 0.9, 1.0, nil, nil, 10, false)
        end)
    end

    -- =========================================================================
    -- Canal "desligado" nativo (HUD Vanilla): Sintoniza sem alterar o volume da TV/Rádio
    -- =========================================================================
    pcall(function()
        local dd = nil
        if deviceObj.getDeviceData then
            dd = deviceObj:getDeviceData()
        elseif deviceObj.getItem and deviceObj:getItem() and deviceObj:getItem().getDeviceData then
            dd = deviceObj:getItem():getDeviceData()
        end
        if dd then
            if VICCS.SilentChannel and VICCS.SilentChannel.ensureSilentPreset then
                VICCS.SilentChannel.ensureSilentPreset(dd)
            end
            local silentFreq = (VICCS.SilentChannel and VICCS.SilentChannel.getSilentFrequency(dd)) or 202
            devRecord.savedChannel = dd:getChannel()
            if dd:getChannel() ~= silentFreq and dd.setChannel then
                dd:setChannel(silentFreq)
            end
            if VICCS.SilentChannel and VICCS.SilentChannel.silenceDeviceIfOnChannel then
                VICCS.SilentChannel.silenceDeviceIfOnChannel(dd)
            end
            -- Para fitas VHS ou cassetes para evitar sobreposicao de som
            if dd.isPlayingMedia and dd:isPlayingMedia() and dd.StopPlayMedia then
                dd:StopPlayMedia()
            end
        end
    end)
    
    print(string.format("[VICCS] Dispositivo ativado: %s (%s) em [%d, %d, %d] sintonizado em canal silencioso", tostring(id), tostring(deviceType), x or 0, y or 0, z or 0))
end

function VICCS.Main.stopDevice(id)
    if activeDevices[id] then
        local dev = activeDevices[id]
        
        -- Restaura canal original se sintonizado no canal "desligado"
        pcall(function()
            if dev.savedChannel and dev.obj then
                local dd = nil
                if dev.obj.getDeviceData then
                    dd = dev.obj:getDeviceData()
                elseif dev.obj.getItem and dev.obj:getItem() and dev.obj:getItem().getDeviceData then
                    dd = dev.obj:getItem():getDeviceData()
                end
                if dd and dd.setChannel then
                    dd:setChannel(dev.savedChannel)
                end
            end
        end)

        pcall(function()
            if dev.obj and dev.obj.getModData then
                local md = dev.obj:getModData()
                if md.viccsMedia then
                    md.viccsMedia.state = "STOPPED"
                end
                if dev.obj.transmitModData then dev.obj:transmitModData() end
            end
        end)
        activeDevices[id] = nil
        print(string.format("[VICCS] Dispositivo parado: %s", tostring(id)))
    end
end

function VICCS.Main.pauseDevice(id)
    if activeDevices[id] then
        local dev = activeDevices[id]
        if not dev.isPaused then
            dev.isPaused = true
            dev.pausedOffset = math.max(0, os.time() - dev.startedAt)
            pcall(function()
                if dev.obj and dev.obj.getModData then
                    local md = dev.obj:getModData()
                    if md.viccsMedia then
                        md.viccsMedia.state = "PAUSED"
                        md.viccsMedia.pausedOffset = dev.pausedOffset
                    end
                    if dev.obj.transmitModData then dev.obj:transmitModData() end
                end
            end)
            print(string.format("[VICCS] Dispositivo pausado: %s (offset: %ds)", tostring(id), dev.pausedOffset))
        end
    end
end

function VICCS.Main.resumeDevice(id)
    if activeDevices[id] then
        local dev = activeDevices[id]
        if dev.isPaused then
            dev.isPaused = false
            dev.startedAt = os.time() - (dev.pausedOffset or 0)
            pcall(function()
                if dev.obj and dev.obj.getModData then
                    local md = dev.obj:getModData()
                    if md.viccsMedia then
                        md.viccsMedia.state = "PLAYING"
                        md.viccsMedia.startedAt = dev.startedAt
                    end
                    if dev.obj.transmitModData then dev.obj:transmitModData() end
                end
            end)
            
            -- Feedback Halo ao retomar
            local haloText = getText("UI_VICCS_NowPlaying") or "[ ♪ Em reprodução ♪ ]"
            local player = getPlayer()
            if player and HaloTextHelper and HaloTextHelper.addGoodText then
                HaloTextHelper.addGoodText(player, haloText)
            end
            print(string.format("[VICCS] Dispositivo retomado: %s (a partir de %ds)", tostring(id), dev.pausedOffset or 0))
        end
    end
end

function VICCS.Main.updateDeviceVolume(id, vol)
    if activeDevices[id] then
        activeDevices[id].volume = math.max(0.0, math.min(1.0, vol))
        pcall(function()
            if activeDevices[id].obj and activeDevices[id].obj.getModData then
                local md = activeDevices[id].obj:getModData()
                if md.viccsMedia then
                    md.viccsMedia.volume = activeDevices[id].volume
                end
            end
        end)
    end
end

function VICCS.Main.openDeviceUI(player, device, deviceType)
    -- Validação de energia antes de abrir qualquer janela
    if VICCS.Compat and VICCS.Compat.hasDevicePower then
        local hasPower, isTurnedOn = VICCS.Compat.hasDevicePower(device)
        if not hasPower then
            if player and player.Say then
                player:Say(getText("UI_VICCS_NoPower") or "Sem energia ou bateria!")
            end
            return
        end
        
        -- Liga o aparelho se estava desligado mas tem carga
        if not isTurnedOn and device and device.getDeviceData then
            pcall(function()
                local dd = device:getDeviceData()
                if dd and not dd:getIsTurnedOn() then
                    if dd.setIsTurnedOn then
                        dd:setIsTurnedOn(true)
                    end
                end
            end)
        end
    end
    
    -- Se ja existe janela aberta, fecha sem destruir o estado do aparelho
    if currentActiveWindow and currentActiveWindow:isVisible() then
        currentActiveWindow:setVisible(false)
        currentActiveWindow:removeFromUIManager()
        currentActiveWindow = nil
    end
    
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    
    if deviceType == "TELEVISION" or deviceType == "COMPUTER" then
        if not VICCS.UI or not VICCS.UI.ScreenPlayer then
            print("[VICCS ERR] VICCS.UI.ScreenPlayer nao inicializado!")
            return
        end
        local w = 480
        local h = 360
        local x = math.floor((screenW - w) / 2)
        local y = math.floor((screenH - h) / 2)
        
        currentActiveWindow = VICCS.UI.ScreenPlayer:new(x, y, w, h, player, device, deviceType)
        currentActiveWindow:initialise()
        currentActiveWindow:addToUIManager()
        currentActiveWindow:setVisible(true)
    else
        if not VICCS.UI or not VICCS.UI.RadioDock then
            print("[VICCS ERR] VICCS.UI.RadioDock nao inicializado!")
            return
        end
        local w = 320
        local h = 180
        local x = math.floor((screenW - w) / 2)
        local y = math.floor(screenH * 0.65)
        
        currentActiveWindow = VICCS.UI.RadioDock:new(x, y, w, h, player, device, deviceType)
        currentActiveWindow:initialise()
        currentActiveWindow:addToUIManager()
        currentActiveWindow:setVisible(true)
    end
end

local function onKeyPressed(key)
    if key == Keyboard.KEY_ESCAPE then
        if currentActiveWindow and currentActiveWindow:isVisible() then
            currentActiveWindow:onClose()
            currentActiveWindow = nil
        end
    end
end

local function onTick()
    tickCounter = tickCounter + 1
    if not VICCS.Config or not VICCS.Config.PollIntervalTicks then return end
    if tickCounter < VICCS.Config.PollIntervalTicks then return end
    tickCounter = 0
    
    local player = getPlayer()
    if not player then return end
    
    -- Deteccao rigorosa de pausa no Single Player
    local isGamePaused = false
    if not isClient() then
        if UIManager and UIManager.getSpeedControls and UIManager.getSpeedControls() then
            if UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then
                isGamePaused = true
            end
        end
        if not isGamePaused and getGameTime then
            local gt = getGameTime()
            if gt and gt.getTrueMultiplier and gt:getTrueMultiplier() == 0 then
                isGamePaused = true
            end
        end
    end
    
    -- Compensacao temporal anti-drift quando o jogo despausar
    if isGamePaused then
        if not wasGamePaused then
            wasGamePaused = true
            pauseStartTime = os.time()
        end
    else
        if wasGamePaused then
            wasGamePaused = false
            local pausedDuration = math.max(0, os.time() - pauseStartTime)
            if pausedDuration > 0 then
                for _, dev in pairs(activeDevices) do
                    dev.startedAt = dev.startedAt + pausedDuration
                end
            end
        end
    end
    
    local pVeh = player.getVehicle and player:getVehicle()
    local listenerInClosedVehicle = false
    if pVeh then
        listenerInClosedVehicle = VICCS.Spatial and VICCS.Spatial.isVehicleEnclosed and VICCS.Spatial.isVehicleEnclosed(pVeh)
    end
    
    local listenerData = {
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
        roomClass = pVeh and "vehicle_cabin" or "outdoor",
        outdoor = (pVeh == nil)
    }
    if not pVeh and VICCS.RoomClassifier and VICCS.RoomClassifier.classify then
        local pSq = player:getCurrentSquare()
        listenerData.roomClass = VICCS.RoomClassifier.classify(pSq)
        listenerData.outdoor = (listenerData.roomClass == "outdoor")
    elseif pVeh and not listenerInClosedVehicle then
        -- Se o carro estiver com vidros/portas abertos e dentro de um galpão/construção:
        local pSq = player:getCurrentSquare()
        if VICCS.RoomClassifier and VICCS.RoomClassifier.classify then
            local extClass = VICCS.RoomClassifier.classify(pSq)
            if extClass ~= "outdoor" then
                listenerData.roomClass = extClass
            end
        end
    end
    
    local devicesPayload = {}
    local devicesToStop = {}
    
    for id, dev in pairs(activeDevices) do
        -- 0. Monitora se o aparelho ainda possui energia/esta ligado no Vanilla
        local stillPowered = true
        local vanillaVol = 1.0
        
        if dev.obj then
            pcall(function()
                local dd = dev.obj.getDeviceData and dev.obj:getDeviceData()
                if not dd and dev.obj.getItem and dev.obj:getItem() and dev.obj:getItem().getDeviceData then
                    dd = dev.obj:getItem():getDeviceData()
                end
                
                if dd then
                    if not dd:getIsTurnedOn() then
                        stillPowered = false
                    end
                    if dd.getDeviceVolume then
                        if VICCS.SilentChannel and VICCS.SilentChannel.isSilentChannel(dd) then
                            if VICCS.SilentChannel.isMuted(dd) then
                                vanillaVol = 0.0
                            else
                                vanillaVol = VICCS.SilentChannel.getUserVolume(dd)
                            end
                        else
                            vanillaVol = dd:getDeviceVolume()
                        end
                    end
                    if VICCS.SilentChannel and VICCS.SilentChannel.silenceDeviceIfOnChannel then
                        VICCS.SilentChannel.silenceDeviceIfOnChannel(dd)
                    end
                end
            end)
        end
        
        if not stillPowered then
            table.insert(devicesToStop, id)
        else
            -- 1. Suporte dinâmico a Veículos (rastreia deslocamento e presença do jogador na cabine)
            if dev.deviceType == "VEHICLE" then
                local vehicle = nil
                if dev.obj then
                    if instanceof(dev.obj, "BaseVehicle") then
                        vehicle = dev.obj
                    elseif dev.obj.getVehicle and dev.obj:getVehicle() then
                        vehicle = dev.obj:getVehicle()
                    elseif dev.obj.getParent and instanceof(dev.obj:getParent(), "BaseVehicle") then
                        vehicle = dev.obj:getParent()
                    end
                end
                
                if vehicle then
                    dev.vehicleObj = vehicle
                    dev.x = vehicle:getX()
                    dev.y = vehicle:getY()
                    dev.z = vehicle:getZ()
                    
                    dev.isListenerInside = (pVeh ~= nil and pVeh == vehicle)
                end
            end

            -- 1.1 Suporte especial a CD Player / Walkman portátil (móvel no personagem)
            if dev.deviceType == "CDPLAYER" then
                if player then
                    dev.x = player:getX()
                    dev.y = player:getY()
                    dev.z = player:getZ()
                end
                
                -- Checa se o CD Player permanece equipado (Mão, Cinto ou Vestuário)
                local isEquipped = false
                if player and dev.obj then
                    if (player.getPrimaryHandItem and player:getPrimaryHandItem() == dev.obj) or 
                       (player.getSecondaryHandItem and player:getSecondaryHandItem() == dev.obj) then
                        isEquipped = true
                    elseif player.isEquipped and player:isEquipped(dev.obj) then
                        isEquipped = true
                    elseif player.isAttachedItem and player:isAttachedItem(dev.obj) then
                        isEquipped = true
                    end
                end
                
                -- Checa se os fones de ouvido ainda estao conectados (se exigido no Sandbox)
                local requireHP = (VICCS.Config and VICCS.Config.getSandboxVar and VICCS.Config.getSandboxVar("CDPlayerRequireHeadphones", true))
                if requireHP == nil then requireHP = true end
                
                local hasHeadphones = true
                if requireHP then
                    hasHeadphones = false
                    if dev.obj and dev.obj.getDeviceData then
                        pcall(function()
                            local dd = dev.obj:getDeviceData()
                            if dd and dd.getHeadphoneType and dd:getHeadphoneType() >= 0 then
                                hasHeadphones = true
                            end
                        end)
                    end
                    if not hasHeadphones and player then
                        if player.getWornItem and (player:getWornItem("Ears") or player:getWornItem("Headphones")) then
                            hasHeadphones = true
                        end
                        local inv = player:getInventory()
                        if not hasHeadphones and inv then
                            hasHeadphones = (inv:getFirstTypeRecurse("Base.Headphones") ~= nil) or
                                            (inv:getFirstTypeRecurse("Base.Earbuds") ~= nil) or
                                            (inv:getFirstTypeRecurse("Headphones") ~= nil) or
                                            (inv:getFirstTypeRecurse("Earbuds") ~= nil)
                        end
                    end
                end
                
                if not isEquipped or not hasHeadphones then
                    if not dev.isPaused then
                        dev.isPaused = true
                        if player and HaloTextHelper and HaloTextHelper.addBadText then
                            local pauseMsg = getText("UI_VICCS_HeadphonesDisconnected") or "Fones desconectados: Reproducao pausada!"
                            HaloTextHelper.addBadText(player, pauseMsg)
                        end
                    end
                end
            end
            
            -- 2. Emissão periódica de Halo Notify no aparelho (~ a cada 15 segundos)
            if not isGamePaused and not dev.isPaused and dev.deviceType ~= "CDPLAYER" and dev.deviceType ~= "VEHICLE" then
                dev.haloTimer = (dev.haloTimer or 0) + 1
                if dev.haloTimer >= 30 then
                    dev.haloTimer = 0
                    local haloText = getText("UI_VICCS_NowPlaying")
                    if not haloText or haloText == "UI_VICCS_NowPlaying" or string.find(haloText, "♪") then
                        haloText = "[ * Em Reproducao * ]"
                    end
                    if dev.obj and not instanceof(dev.obj, "VehiclePart") and dev.obj.AddDeviceText then
                        pcall(function()
                            dev.obj:AddDeviceText(haloText, 0.0, 0.9, 1.0, nil, nil, 10, false)
                        end)
                    end
                end
            end
            
            -- 3. Cálculo de Áudio 3D integrado com Volume Vanilla e Oclusão Acústica
            local dist, volFactor, pan, occl, roomClass, screenX, screenY = 0, 1.0, 0, { walls = 0, doors = 0, windows = 0, floors = 0 }, "outdoor", 0, 0
            if dev.deviceType == "CDPLAYER" then
                -- Fone de ouvido: som direto sem atenuação por distância ou barreiras
                dist = 0
                volFactor = 1.0
                pan = 0
                occl = { walls = 0, doors = 0, windows = 0, floors = 0, isBlocked = false }
                roomClass = listenerData.roomClass
            elseif dev.deviceType == "VEHICLE" and dev.isListenerInside then
                -- Ouvinte dentro do próprio veículo onde o som toca:
                -- Som surround imersivo de cabine sem atenuação por distância
                dist = 0.5
                volFactor = 1.0
                occl = { walls = 0, doors = 0, windows = 0, floors = 0, isBlocked = false }
                roomClass = listenerData.roomClass
                
                -- Palco surround de cabine:
                -- Posiciona o áudio levemente de acordo com a posição do banco no veículo
                local vehicle = dev.vehicleObj or (dev.obj and (instanceof(dev.obj, "BaseVehicle") and dev.obj or (dev.obj.getVehicle and dev.obj:getVehicle())))
                local seat = (vehicle and vehicle.getSeat and vehicle:getSeat(player)) or 0
                if seat == 0 then -- Motorista (lado esquerdo frontal)
                    pan = -0.10
                    screenX = -0.15
                    screenY = 0.20
                elseif seat == 1 then -- Passageiro dianteiro (lado direito frontal)
                    pan = 0.10
                    screenX = 0.15
                    screenY = 0.20
                elseif seat == 2 then -- Traseiro esquerdo
                    pan = -0.12
                    screenX = -0.15
                    screenY = -0.20
                elseif seat == 3 then -- Traseiro direito
                    pan = 0.12
                    screenX = 0.15
                    screenY = -0.20
                else
                    pan = 0.0
                    screenX = 0.0
                    screenY = 0.10
                end
            elseif VICCS.Spatial and VICCS.Spatial.calculate3D then
                -- Aparelhos externos (TVs, rádios de casa, ou carro ouvido do lado de fora)
                local extraOccl = {}
                
                -- Se o som emitido vem de um carro e o ouvinte está fora:
                if dev.deviceType == "VEHICLE" then
                    local vehicle = dev.vehicleObj or (dev.obj and (instanceof(dev.obj, "BaseVehicle") and dev.obj or (dev.obj.getVehicle and dev.obj:getVehicle())))
                    if vehicle and VICCS.Spatial.isVehicleEnclosed and VICCS.Spatial.isVehicleEnclosed(vehicle) then
                        extraOccl.vehicleEnclosure = true
                    end
                end
                
                -- Se o ouvinte está dentro de um carro com vidros fechados ouvindo som de fora:
                if pVeh and listenerInClosedVehicle and dev.deviceType ~= "CDPLAYER" then
                    local vehicle = dev.vehicleObj or (dev.obj and (instanceof(dev.obj, "BaseVehicle") and dev.obj or (dev.obj.getVehicle and dev.obj:getVehicle())))
                    if vehicle ~= pVeh then
                        extraOccl.listenerInVehicle = true
                    end
                end
                
                dist, volFactor, pan, occl, roomClass, screenX, screenY = VICCS.Spatial.calculate3D(player, dev.x, dev.y, dev.z, extraOccl)
            end
            
            local effectiveDevVol = dev.volume * vanillaVol
            local finalVol = effectiveDevVol * volFactor
            
            table.insert(devicesPayload, {
                deviceId = id,
                volume = finalVol,
                rawVolume = dev.volume,
                pan = pan,
                distance = dist,
                occluded = occl.isBlocked or (occl.walls > 0 or occl.doors > 0 or occl.floors > 0 or occl.exteriorWall == true or occl.interiorWall == true),
                occl = occl,
                roomClass = roomClass,
                screenX = screenX,
                screenY = screenY,
                url = dev.url,
                deviceType = dev.deviceType,
                startedAt = dev.startedAt,
                isPaused = dev.isPaused or false
            })
            
            -- 4. Atracao de Zumbis: Somente para caixas de som e aparelhos externos (Fones = ZERO atracao se CDPlayerSilent ativo)
            if not isGamePaused and not dev.isPaused and VICCS.Zombies and VICCS.Zombies.pulseSound then
                local isCD = (dev.deviceType == "CDPLAYER")
                local cdSilent = (VICCS.Config and VICCS.Config.getSandboxVar and VICCS.Config.getSandboxVar("CDPlayerSilent", true))
                if cdSilent == nil then cdSilent = true end
                
                if not isCD then
                    VICCS.Zombies.pulseSound(dev.obj, dev.x, dev.y, dev.z, effectiveDevVol, false)
                elseif not cdSilent then
                    VICCS.Zombies.pulseSound(dev.obj, dev.x, dev.y, dev.z, effectiveDevVol * 0.3, false)
                end
            end
        end
    end
    
    -- Para aparelhos cuja bateria acabou ou que a eletricidade foi desligada
    for _, deadId in ipairs(devicesToStop) do
        print(string.format("[VICCS] Dispositivo %s desligado pelo motor vanilla (sem energia).", tostring(deadId)))
        VICCS.Main.stopDevice(deadId)
    end
    
    -- 5. Transmissao atomica de estado para o PZHub com flag de pausa e listenerData
    if VICCS.Bridge and VICCS.Bridge.writeGameState then
        VICCS.Bridge.writeGameState(devicesPayload, nil, isGamePaused, listenerData)
    end
    
    -- 6. Leitura de respostas do PZHub
    if VICCS.Bridge and VICCS.Bridge.readAppResponse then
        local response = VICCS.Bridge.readAppResponse()
        if response and response.nowPlaying then
            -- Estado retornado pelo PZHub
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
Events.OnTick.Add(onTick)

print("[VICCS Media Broadcasting] Sistema carregado com sucesso (Build 42).")
