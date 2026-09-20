-- media/lua/client/VICCS/VICCS_Main.lua
-- Orquestrador central: Gerencia dispositivos ativos, audio 3D, atracao de zumbis e exibicao de UIs

require "VICCS/UI/VICCS_UI_Theme"
require "VICCS/UI/VICCS_UI_Components"
require "VICCS/UI/VICCS_UI_RadioDock"
require "VICCS/UI/VICCS_UI_ScreenPlayer"

VICCS = VICCS or {}
VICCS.Main = {}

local tickCounter = 0
local activeDevices = {}
local currentActiveWindow = nil

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
        startedAt = os.time() - (offsetSec or 0)
    }
    activeDevices[id] = devRecord
    
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
    
    print(string.format("[VICCS] Dispositivo ativado: %s (%s) em [%d, %d, %d]", tostring(id), tostring(deviceType), x or 0, y or 0, z or 0))
end

function VICCS.Main.stopDevice(id)
    if activeDevices[id] then
        local dev = activeDevices[id]
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
        
        currentActiveWindow = VICCS.UI.RadioDock:new(x, y, w, h, player, device)
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
    
    local devicesPayload = {}
    local devicesToStop = {}
    
    for id, dev in pairs(activeDevices) do
        -- 0. Monitora se o aparelho ainda possui energia/está ligado no Vanilla
        local stillPowered = true
        if dev.obj then
            pcall(function()
                local dd = dev.obj.getDeviceData and dev.obj:getDeviceData()
                if dd and not dd:getIsTurnedOn() then
                    stillPowered = false
                end
            end)
        end
        
        if not stillPowered then
            table.insert(devicesToStop, id)
        else
            -- 1. Cálculo de Áudio 3D (Distância, Pan Estéreo e Oclusão por Paredes)
            local dist, volFactor, pan, isOccluded = 0, 1, 0, false
            if VICCS.Spatial and VICCS.Spatial.calculate3D then
                dist, volFactor, pan, isOccluded = VICCS.Spatial.calculate3D(player, dev.x, dev.y, dev.z)
            end
            
            local finalVol = dev.volume * volFactor
            
            table.insert(devicesPayload, {
                deviceId = id,
                volume = finalVol,
                pan = pan,
                distance = dist,
                occluded = isOccluded,
                url = dev.url,
                deviceType = dev.deviceType,
                startedAt = dev.startedAt
            })
            
            -- 2. Atração de Zumbis: emite pulso acústico no WorldSoundManager
            if VICCS.Zombies and VICCS.Zombies.pulseSound then
                VICCS.Zombies.pulseSound(dev.obj, dev.x, dev.y, dev.z, dev.volume, dev.isHeadphones)
            end
        end
    end
    
    -- Para aparelhos cuja bateria acabou ou que a eletricidade foi desligada
    for _, deadId in ipairs(devicesToStop) do
        print(string.format("[VICCS] Dispositivo %s desligado pelo motor vanilla (sem energia).", tostring(deadId)))
        VICCS.Main.stopDevice(deadId)
    end
    
    -- 3. Transmissão atômica de estado para o PZHub
    if VICCS.Bridge and VICCS.Bridge.writeGameState then
        VICCS.Bridge.writeGameState(devicesPayload, nil)
    end
    
    -- 4. Leitura de respostas do PZHub
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
