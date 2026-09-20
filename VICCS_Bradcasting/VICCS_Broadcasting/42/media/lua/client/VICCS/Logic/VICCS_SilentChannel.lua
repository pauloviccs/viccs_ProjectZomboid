-- media/lua/client/VICCS/Logic/VICCS_SilentChannel.lua
-- Canal nativo "Silenciar canais" para o sistema vanilla de Televisores e Radios (Build 42)
-- Remove 100% de ruidos de frequencia, estatica e vozes vanilla sem alterar a aparencia do volume na HUD

VICCS = VICCS or {}
VICCS.SilentChannel = {}

-- 202 fica exatamente entre 201 (WBLN) e 203 (Life & Living), sem nenhuma transmissao vanilla
VICCS.SilentChannel.TV_FREQ = 202
-- 107900 (107.9 MHz) esta dentro da faixa de todos os radios civis e militares, sem broadcast
VICCS.SilentChannel.RADIO_FREQ = 107900

-- Tabela interna em memoria Lua para mapear dados virtuais de objetos Java (evita Kahlua tableSet runtime crash)
local deviceVirtualData = {}

local function getDeviceKey(deviceData)
    if not deviceData then return nil end
    return tostring(deviceData)
end

function VICCS.SilentChannel.getUserVolume(deviceData)
    local key = getDeviceKey(deviceData)
    if key and deviceVirtualData[key] and deviceVirtualData[key].userVol ~= nil then
        return deviceVirtualData[key].userVol
    end
    return 0.7
end

function VICCS.SilentChannel.hasUserVolume(deviceData)
    local key = getDeviceKey(deviceData)
    return (key and deviceVirtualData[key] and deviceVirtualData[key].userVol ~= nil)
end

function VICCS.SilentChannel.setUserVolume(deviceData, vol)
    local key = getDeviceKey(deviceData)
    if not key then return end
    deviceVirtualData[key] = deviceVirtualData[key] or {}
    deviceVirtualData[key].userVol = vol
end

function VICCS.SilentChannel.clearUserVolume(deviceData)
    local key = getDeviceKey(deviceData)
    if key and deviceVirtualData[key] then
        deviceVirtualData[key].userVol = nil
    end
end

function VICCS.SilentChannel.isMuted(deviceData)
    local key = getDeviceKey(deviceData)
    if key and deviceVirtualData[key] then
        return deviceVirtualData[key].isMuted == true
    end
    return false
end

function VICCS.SilentChannel.setMuted(deviceData, muted)
    local key = getDeviceKey(deviceData)
    if not key then return end
    deviceVirtualData[key] = deviceVirtualData[key] or {}
    deviceVirtualData[key].isMuted = muted
end

--- Retorna o nome localizado do canal de acordo com o idioma ativo
function VICCS.SilentChannel.getChannelName()
    local name = getText("UI_VICCS_SilentChannel")
    if not name or name == "UI_VICCS_SilentChannel" or name == "" then
        return "Silenciar canais"
    end
    return name
end

--- Retorna a frequencia silenciosa adequada para o aparelho
function VICCS.SilentChannel.getSilentFrequency(deviceData)
    if not deviceData then return VICCS.SilentChannel.TV_FREQ end
    
    local isTV = false
    pcall(function() isTV = deviceData:getIsTelevision() end)
    if isTV then
        return VICCS.SilentChannel.TV_FREQ
    end
    
    local minR = 88000
    local maxR = 108000
    pcall(function()
        minR = deviceData:getMinChannelRange() or 88000
        maxR = deviceData:getMaxChannelRange() or 108000
    end)
    
    local target = VICCS.SilentChannel.RADIO_FREQ
    if target >= minR and target <= maxR then
        return target
    else
        return maxR
    end
end

--- Verifica se o aparelho esta sintonizado no canal silencioso
function VICCS.SilentChannel.isSilentChannel(deviceData)
    if not deviceData then return false end
    local currentChannel = nil
    pcall(function() currentChannel = deviceData:getChannel() end)
    if not currentChannel then return false end
    
    local silentFreq = VICCS.SilentChannel.getSilentFrequency(deviceData)
    return currentChannel == silentFreq
end

--- Garante que o canal "Silenciar canais" esteja adicionado nos presets nativos do aparelho
function VICCS.SilentChannel.ensureSilentPreset(deviceData)
    if not deviceData then return end
    pcall(function()
        local presets = deviceData:getDevicePresets()
        if not presets then return end
        
        local silentFreq = VICCS.SilentChannel.getSilentFrequency(deviceData)
        local channelName = VICCS.SilentChannel.getChannelName()
        local list = presets:getPresets()
        if not list then return end
        
        local hasSilent = false
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            if p then
                local pName = p:getName()
                local pFreq = p:getFrequency()
                -- Detecta preset antigo ("desligado", "Desligado", frequencia antiga 999) e atualiza
                if pName == "desligado" or pName == "Desligado" or pName == "Silenciar canal" or 
                   pName == "Silenciar canais" or pName == "Mute channels" or pFreq == silentFreq or pFreq == 999 then
                    hasSilent = true
                    p:setName(channelName)
                    p:setFrequency(silentFreq)
                    break
                end
            end
        end
        
        if not hasSilent then
            if list:size() >= presets:getMaxPresets() then
                presets:setMaxPresets(presets:getMaxPresets() + 5)
            end
            presets:addPreset(channelName, silentFreq)
            if deviceData.transmitPresets then
                deviceData:transmitPresets()
            end
        end
    end)
end

--- Silencia completamente qualquer ruido vanilla (RadioStatic, RadioTalk, TelevisionTestBeep)
-- mantendo o volume visual do jogador intacto
function VICCS.SilentChannel.silenceDeviceIfOnChannel(deviceData)
    if not deviceData then return end
    pcall(function()
        local onSilent = VICCS.SilentChannel.isSilentChannel(deviceData)
        local rawVol = 1.0
        if deviceData.getDeviceVolume then
            rawVol = deviceData:getDeviceVolume()
        end
        
        if onSilent then
            -- Se esta no canal silencioso:
            -- 1. Preserva o volume que o usuario tinha antes na tabela Lua interna
            if rawVol > 0.0 then
                VICCS.SilentChannel.setUserVolume(deviceData, rawVol)
            elseif not VICCS.SilentChannel.hasUserVolume(deviceData) then
                VICCS.SilentChannel.setUserVolume(deviceData, 0.7)
            end
            
            -- 2. Define o volume do motor Java para 0.0 (cala o FMOD ParameterDeviceVolume)
            if rawVol > 0.0 then
                if deviceData.setDeviceVolumeRaw then
                    deviceData:setDeviceVolumeRaw(0.0)
                else
                    deviceData:setDeviceVolume(0.0)
                end
            end
            
            -- 3. Interrompe imediatamente qualquer som residual de estatica ou dialogo
            local emitter = deviceData:getEmitter()
            if emitter then
                if emitter.stopSoundByName then
                    emitter:stopSoundByName("RadioStatic")
                    emitter:stopSoundByName("VehicleRadioStatic")
                    emitter:stopSoundByName("TelevisionTestBeep")
                    emitter:stopSoundByName("TelevisionStatic")
                    emitter:stopSoundByName("RadioTalk")
                    emitter:stopSoundByName("VehicleRadioProgram")
                    emitter:stopSoundByName("BroadcastEmergency")
                    emitter:stopSoundByName("RadioZap")
                    emitter:stopSoundByName("VehicleRadioZap")
                    emitter:stopSoundByName("TelevisionZap")
                end
                if emitter.stopAll then
                    emitter:stopAll()
                end
            end
            
            -- 4. Para transmissao de fitas VHS ou cassetes para nao falar ao fundo
            if deviceData.isPlayingMedia and deviceData:isPlayingMedia() and deviceData.StopPlayMedia then
                deviceData:StopPlayMedia()
            end
        else
            -- Se saiu do canal silencioso e voltou para estacao vanilla normal:
            -- Restaura o volume real do aparelho
            if VICCS.SilentChannel.hasUserVolume(deviceData) and rawVol == 0.0 and not VICCS.SilentChannel.isMuted(deviceData) then
                local restoredVol = VICCS.SilentChannel.getUserVolume(deviceData)
                VICCS.SilentChannel.clearUserVolume(deviceData)
                if deviceData.setDeviceVolumeRaw then
                    deviceData:setDeviceVolumeRaw(restoredVol)
                else
                    deviceData:setDeviceVolume(restoredVol)
                end
            end
        end
    end)
end

-- =========================================================================
-- Hooks na Interface Vanilla (HUD de TV, Radio e Volume)
-- =========================================================================
local function installSilentChannelHooks()
    pcall(function()
        -- 1. Hook no RWMChannelTV (Modulo de canais de Televisao)
        if RWMChannelTV and not RWMChannelTV._viccsSilentHooked then
            RWMChannelTV._viccsSilentHooked = true
            local orig_tv_readPresets = RWMChannelTV.readPresets
            RWMChannelTV.readPresets = function(self, _selected)
                if self.deviceData then
                    VICCS.SilentChannel.ensureSilentPreset(self.deviceData)
                end
                orig_tv_readPresets(self, _selected)
            end
            
            local orig_tv_doTuneIn = RWMChannelTV.doTuneInButton
            RWMChannelTV.doTuneInButton = function(self)
                orig_tv_doTuneIn(self)
                if self.deviceData then
                    VICCS.SilentChannel.silenceDeviceIfOnChannel(self.deviceData)
                end
            end
            print("[VICCS] Hook em RWMChannelTV ('Silenciar canais') instalado com sucesso.")
        end

        -- 2. Hook no RWMChannel (Modulo de canais de Radio)
        if RWMChannel and not RWMChannel._viccsSilentHooked then
            RWMChannel._viccsSilentHooked = true
            local orig_radio_readPresets = RWMChannel.readPresets
            RWMChannel.readPresets = function(self, _selected)
                if self.deviceData then
                    VICCS.SilentChannel.ensureSilentPreset(self.deviceData)
                end
                orig_radio_readPresets(self, _selected)
            end
            
            local orig_radio_doTuneIn = RWMChannel.doTuneInButton
            RWMChannel.doTuneInButton = function(self)
                orig_radio_doTuneIn(self)
                if self.deviceData then
                    VICCS.SilentChannel.silenceDeviceIfOnChannel(self.deviceData)
                end
            end
            print("[VICCS] Hook em RWMChannel ('Silenciar canais') instalado com sucesso.")
        end

        -- 3. Hook no RWMGeneral (Cabecalho 'Geral' onde exibe 'Canal: <Nome>')
        if RWMGeneral and not RWMGeneral._viccsSilentHooked then
            RWMGeneral._viccsSilentHooked = true
            local orig_general_setInfoLines = RWMGeneral.setInfoLines
            RWMGeneral.setInfoLines = function(self)
                if self.deviceData and VICCS.SilentChannel.isSilentChannel(self.deviceData) then
                    self.infoLines = {}
                    self.isTv = self.deviceData:getIsTelevision()
                    local chName = VICCS.SilentChannel.getChannelName()
                    self:addInfoLine(getText("IGUI_RadioChannel")..":   ", chName)
                    if not self.isTv then
                        self:addInfoLine(getText("IGUI_RadioFrequency")..":   ", tostring(self.deviceData:getChannel()/1000).." MHz")
                        self:addInfoLine(getText("IGUI_RadioFreqRange")..":   ", tostring(self.deviceData:getMinChannelRange()/1000).." MHz - " .. tostring(self.deviceData:getMaxChannelRange()/1000).." MHz")
                        self:addInfoLine(getText("IGUI_RadioTwoway")..":   ", self.deviceData:getIsTwoWay() and getText("IGUI_RadioYes") or getText("IGUI_RadioNo"))
                    end
                    return
                end
                orig_general_setInfoLines(self)
            end
            print("[VICCS] Hook em RWMGeneral ('Silenciar canais') instalado com sucesso.")
        end

        -- 4. Hook no RWMVolume (Preserva as barrinhas verdes visuais mesmo com som FMOD silenciado)
        if RWMVolume and not RWMVolume._viccsSilentHooked then
            RWMVolume._viccsSilentHooked = true
            
            local orig_volume_update = RWMVolume.update
            RWMVolume.update = function(self)
                if self.deviceData and VICCS.SilentChannel.isSilentChannel(self.deviceData) then
                    ISPanel.update(self)
                    
                    local userVol = VICCS.SilentChannel.getUserVolume(self.deviceData)
                    local isMuted = VICCS.SilentChannel.isMuted(self.deviceData)
                    
                    self.speakerButton:setEnableControls(self.deviceData:getIsTurnedOn())
                    self.speakerButton.isMute = isMuted
                    self.volumeBar:setEnableControls(self.deviceData:getIsTurnedOn() and not isMuted)
                    
                    local dispVol = isMuted and 0.0 or userVol
                    local devVol = dispVol + 0.05
                    self.volumeBar:setVolume(math.floor(devVol * self.volumeBar:getVolumeSteps()))
                    
                    if self.deviceData:getHeadphoneType() >= 0 then
                        if self.deviceData:getHeadphoneType() == 0 then
                            self.itemDropBox:setStoredItemFake(self.headphonesTex)
                        elseif self.deviceData:getHeadphoneType() == 1 then
                            self.itemDropBox:setStoredItemFake(self.earbudsTex)
                        end
                    else
                        self.itemDropBox:setStoredItemFake(nil)
                    end
                    return
                end
                orig_volume_update(self)
            end
            
            local orig_volume_onVolumeChange = RWMVolume.onVolumeChange
            RWMVolume.onVolumeChange = function(self, _newVol)
                if self.deviceData and VICCS.SilentChannel.isSilentChannel(self.deviceData) then
                    self.volume = _newVol / self.volumeBar:getVolumeSteps()
                    VICCS.SilentChannel.setUserVolume(self.deviceData, self.volume)
                    VICCS.SilentChannel.setMuted(self.deviceData, false)
                    -- Mantem o som vanilla zerado internamente
                    VICCS.SilentChannel.silenceDeviceIfOnChannel(self.deviceData)
                    return
                end
                orig_volume_onVolumeChange(self, _newVol)
            end
            
            local orig_volume_onSpeakerButton = RWMVolume.onSpeakerButton
            RWMVolume.onSpeakerButton = function(self, _ismute)
                if self.deviceData and VICCS.SilentChannel.isSilentChannel(self.deviceData) then
                    VICCS.SilentChannel.setMuted(self.deviceData, _ismute)
                    return
                end
                orig_volume_onSpeakerButton(self, _ismute)
            end
            
            print("[VICCS] Hook em RWMVolume (Volume visual preservado) instalado com sucesso.")
        end

        -- 5. Hook no ISRadioWindow.readFromObject (Ao carregar qualquer objeto na janela)
        if ISRadioWindow and not ISRadioWindow._viccsSilentHooked then
            ISRadioWindow._viccsSilentHooked = true
            local orig_readFromObject = ISRadioWindow.readFromObject
            ISRadioWindow.readFromObject = function(self, _player, _deviceObject)
                pcall(function()
                    if _deviceObject and _deviceObject.getDeviceData then
                        local dd = _deviceObject:getDeviceData()
                        if dd then
                            VICCS.SilentChannel.ensureSilentPreset(dd)
                            VICCS.SilentChannel.silenceDeviceIfOnChannel(dd)
                        end
                    end
                end)
                orig_readFromObject(self, _player, _deviceObject)
            end
            print("[VICCS] Hook em ISRadioWindow.readFromObject instalado com sucesso.")
        end
    end)
end

-- =========================================================================
-- Monitor Leve OnTick: Garante silenciamento continuo sem delay
-- =========================================================================
local function onSilentChannelTick()
    pcall(function()
        -- Monitora a janela de radio aberta atualmente pelo jogador
        local radioWin = ISRadioWindow and ISRadioWindow.instances and ISRadioWindow.instances[1]
        if radioWin and radioWin.deviceData then
            VICCS.SilentChannel.silenceDeviceIfOnChannel(radioWin.deviceData)
        end
    end)
end

Events.OnGameStart.Add(installSilentChannelHooks)
Events.OnTick.Add(onSilentChannelTick)

print("[VICCS] Modulo de Canal 'Silenciar canais' (HUD Vanilla B42) carregado com sucesso.")
