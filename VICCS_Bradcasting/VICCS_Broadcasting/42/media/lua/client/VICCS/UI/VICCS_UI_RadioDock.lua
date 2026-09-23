-- media/lua/client/VICCS/UI/VICCS_UI_RadioDock.lua
-- Mini-Dock Premium flutuante para Rádios, Boomboxes, CD Player Discman e Aparelhos de Som (Estilo CHStatusHUD)

require "ISUI/ISPanel"

VICCS = VICCS or {}
VICCS.UI = VICCS.UI or {}

local function getTheme()
    if VICCS.UI and VICCS.UI.Theme and VICCS.UI.Theme.Colors then
        return VICCS.UI.Theme.Colors
    end
    return {
        GlassBg = { r = 0.07, g = 0.08, b = 0.11, a = 0.88 },
        GlassBgHeader = { r = 0.11, g = 0.13, b = 0.18, a = 0.95 },
        GlassBorder = { r = 0.24, g = 0.28, b = 0.38, a = 0.85 },
        Cyan = { r = 0.0, g = 0.90, b = 1.0, a = 1.0 },
        Amber = { r = 1.0, g = 0.72, b = 0.0, a = 1.0 },
        Green = { r = 0.20, g = 0.95, b = 0.45, a = 1.0 },
        Red = { r = 1.0, g = 0.25, b = 0.25, a = 1.0 },
        TextPrimary = { r = 0.95, g = 0.96, b = 0.98, a = 1.0 },
        TextSecondary = { r = 0.70, g = 0.75, b = 0.85, a = 1.0 }
    }
end

local function getTranslated(key, default)
    local txt = getText(key)
    if not txt or txt == key or txt == "" then
        return default
    end
    return txt
end

VICCS.UI.RadioDock = ISPanel:derive("VICCSRadioDock")

function VICCS.UI.RadioDock:new(x, y, width, height, player, deviceObj, deviceType)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    
    local Theme = getTheme()
    o.player = player
    o.deviceObj = deviceObj
    o.deviceType = deviceType or "RADIO"
    o.moveWithMouse = true
    o.backgroundColor = Theme.GlassBg
    o.borderColor = Theme.GlassBorder
    
    local defaultVol = 0.7
    if VICCS.Config and VICCS.Config.getSandboxVar then
        local sVol = VICCS.Config.getSandboxVar("DefaultVolume", 70)
        if sVol then defaultVol = sVol / 100 end
    end
    o.currentVolume = defaultVol
    pcall(function()
        local dd = deviceObj and deviceObj.getDeviceData and deviceObj:getDeviceData()
        if not dd and deviceObj and deviceObj.getItem and deviceObj:getItem() and deviceObj:getItem().getDeviceData then
            dd = deviceObj:getItem():getDeviceData()
        end
        if dd and dd.getDeviceVolume then
            o.currentVolume = dd:getDeviceVolume()
        end
    end)
    
    o.isPlaying = false
    o.isPaused = false
    o.pausedOffset = 0
    o.currentUrl = ""
    
    local defaultTitle = (o.deviceType == "CDPLAYER") and (getTranslated("UI_VICCS_CDPlayer_Title", "VICCS CD Player") .. " PRONTO") or (getTranslated("UI_VICCS_NoSignal", "SEM SINAL / OFF"))
    o.currentTitle = defaultTitle
    
    if o.deviceType == "CDPLAYER" then
        local pNum = (player and player.getPlayerNum and player:getPlayerNum()) or 0
        local itemID = (deviceObj and deviceObj.getID and deviceObj:getID()) or (tostring(pNum) .. "-discman")
        o.deviceId = "cdplayer-" .. tostring(itemID)
    elseif o.deviceType == "VEHICLE" then
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
        o.vehicleObj = vehicle
        local vehId = (vehicle and vehicle.getId and vehicle:getId()) or "car"
        o.deviceId = "vehicle-" .. tostring(vehId)
    else
        local dx = deviceObj and deviceObj.getX and deviceObj:getX() or 0
        local dy = deviceObj and deviceObj.getY and deviceObj:getY() or 0
        local dz = deviceObj and deviceObj.getZ and deviceObj:getZ() or 0
        o.deviceId = "radio-" .. tostring(dx) .. "-" .. tostring(dy) .. "-" .. tostring(dz)
    end
    
    -- Sincroniza estado se o aparelho já estiver tocando no mundo
    local activeData = VICCS.Main and VICCS.Main.getPlayingDevice and VICCS.Main.getPlayingDevice(o.deviceId)
    if activeData then
        o.isPaused = activeData.isPaused or false
        o.isPlaying = not o.isPaused
        o.pausedOffset = activeData.pausedOffset or 0
        o.currentVolume = activeData.volume or o.currentVolume
        o.currentUrl = activeData.url or ""
        o.currentTitle = o.isPaused and getTranslated("UI_VICCS_Paused", "PAUSADO") or "TRANSMITINDO AUDIO..."
    elseif deviceObj and deviceObj.getModData then
        local md = deviceObj:getModData()
        if md and md.viccsMedia and (md.viccsMedia.state == "PLAYING" or md.viccsMedia.state == "PAUSED") then
            o.isPaused = (md.viccsMedia.state == "PAUSED")
            o.isPlaying = not o.isPaused
            o.currentVolume = md.viccsMedia.volume or o.currentVolume
            o.currentUrl = md.viccsMedia.url or ""
            o.currentTitle = o.isPaused and getTranslated("UI_VICCS_Paused", "PAUSADO") or "TRANSMITINDO AUDIO..."
            if VICCS.Main and VICCS.Main.registerPlayingDevice then
                local dx, dy, dz = 0, 0, 0
                if o.deviceType == "CDPLAYER" then
                    dx = player and player:getX() or 0
                    dy = player and player:getY() or 0
                    dz = player and player:getZ() or 0
                elseif o.deviceType == "VEHICLE" then
                    local veh = o.vehicleObj
                    dx = veh and veh:getX() or 0
                    dy = veh and veh:getY() or 0
                    dz = veh and veh:getZ() or 0
                else
                    dx = deviceObj and deviceObj.getX and deviceObj:getX() or 0
                    dy = deviceObj and deviceObj.getY and deviceObj:getY() or 0
                    dz = deviceObj and deviceObj.getZ and deviceObj:getZ() or 0
                end
                VICCS.Main.registerPlayingDevice(o.deviceId, deviceObj, dx, dy, dz, o.currentVolume, o.currentUrl, o.deviceType)
                if o.isPaused and VICCS.Main.pauseDevice then
                    VICCS.Main.pauseDevice(o.deviceId)
                end
            end
        end
    end
    
    return o
end

function VICCS.UI.RadioDock:initialise()
    ISPanel.initialise(self)
    self:createChildren()
end

function VICCS.UI.RadioDock:createChildren()
    local pad = 12
    local curY = 32
    local Theme = getTheme()
    
    -- Botão Fechar no topo direito
    local btnClose = VICCS.UI.GlowButton:new(self.width - 28, 6, 22, 20, "X", self, self.onClose)
    btnClose:initialise()
    self:addChild(btnClose)
    
    -- Visualizador VU-Meter
    self.visualizer = VICCS.UI.AudioVisualizer:new(pad, curY, self.width - (pad * 2), 26, 16)
    self.visualizer:initialise()
    self.visualizer.isPlaying = self.isPlaying
    self:addChild(self.visualizer)
    curY = curY + 32
    
    -- Caixa de Texto para Link / URL
    local inputW = self.width - (pad * 2) - 60
    self.urlInput = ISTextEntryBox:new(self.currentUrl or "", pad, curY, inputW, 24)
    self.urlInput:initialise()
    self.urlInput:instantiate()
    self.urlInput:setClearButton(true)
    self:addChild(self.urlInput)
    
    -- Botão Colar
    local btnPaste = VICCS.UI.GlowButton:new(self.width - pad - 54, curY, 54, 24, "Colar", self, self.onPasteClipboard)
    btnPaste:initialise()
    self:addChild(btnPaste)
    curY = curY + 32
    
    -- Controles: Play, Pause / Resume, Stop
    local btnW = math.floor((self.width - (pad * 2) - 12) / 3)
    
    self.btnPlay = VICCS.UI.GlowButton:new(pad, curY, btnW, 28, getTranslated("UI_VICCS_Play", "TOCAR"), self, self.onPlay)
    self.btnPlay:initialise()
    self.btnPlay.accentColor = Theme.Green
    if self.isPlaying then self.btnPlay.isGlowActive = true end
    self:addChild(self.btnPlay)
    
    local pauseTitle = self.isPaused and getTranslated("UI_VICCS_Resume", "RETOMAR") or getTranslated("UI_VICCS_Pause", "PAUSAR")
    self.btnPause = VICCS.UI.GlowButton:new(pad + btnW + 6, curY, btnW, 28, pauseTitle, self, self.onPause)
    self.btnPause:initialise()
    self.btnPause.accentColor = Theme.Amber
    if self.isPaused then self.btnPause.isGlowActive = true end
    self:addChild(self.btnPause)
    
    self.btnStop = VICCS.UI.GlowButton:new(pad + (btnW * 2) + 12, curY, btnW, 28, getTranslated("UI_VICCS_Stop", "PARAR"), self, self.onStop)
    self.btnStop:initialise()
    self.btnStop.accentColor = Theme.Red
    self:addChild(self.btnStop)
    curY = curY + 36
    
    -- Barra de Volume
    self.volumeSlider = VICCS.UI.VolumeSlider:new(pad, curY + 14, self.width - (pad * 2), 12, self.currentVolume, self.onVolumeChange, self)
    self.volumeSlider:initialise()
    self:addChild(self.volumeSlider)
end

function VICCS.UI.RadioDock:onPlay()
    -- 1. Checa energia antes de qualquer ação
    if VICCS.Compat and VICCS.Compat.hasDevicePower then
        local hasPower, isTurnedOn = VICCS.Compat.hasDevicePower(self.deviceObj)
        if not hasPower then
            if self.player and self.player.Say then
                self.player:Say(getTranslated("UI_VICCS_NoPower", "Sem energia ou bateria!"))
            end
            return
        end
        
        -- Liga o dispositivo no motor vanilla para consumir energia/pilha
        if not isTurnedOn and self.deviceObj and self.deviceObj.getDeviceData then
            pcall(function()
                local dd = self.deviceObj:getDeviceData()
                if dd and not dd:getIsTurnedOn() then
                    if dd.setIsTurnedOn then
                        dd:setIsTurnedOn(true)
                    end
                end
            end)
        end
    end

    -- 2. Se for CD Player, checa fones de ouvido conectados (se exigido no Sandbox)
    if self.deviceType == "CDPLAYER" then
        local requireHP = (VICCS.Config and VICCS.Config.getSandboxVar and VICCS.Config.getSandboxVar("CDPlayerRequireHeadphones", true))
        if requireHP == nil then requireHP = true end
        if requireHP then
            local dd = self.deviceObj and self.deviceObj.getDeviceData and self.deviceObj:getDeviceData()
            local hasHeadphones = dd and dd.getHeadphoneType and dd:getHeadphoneType() >= 0
            if not hasHeadphones then
                if self.player and self.player.Say then
                    self.player:Say(getTranslated("UI_VICCS_NeedHeadphones", "Requer fones de ouvido conectados!"))
                end
                return
            end
        end
    end

    local url = VICCS.Config and VICCS.Config.cleanUrl and VICCS.Config.cleanUrl(self.urlInput:getText()) or self.urlInput:getText()
    if not url or url == "" then return end
    
    -- Se estiver pausado e for a mesma URL, apenas retoma do ponto onde parou
    if self.isPaused and (url == self.currentUrl) then
        self:onResume()
        return
    end

    if VICCS.Config and VICCS.Config.isDomainAllowed and not VICCS.Config.isDomainAllowed(url) then
        if self.player and self.player.Say then
            self.player:Say("Link não suportado! Use YouTube ou SoundCloud.")
        end
        return
    end
    
    self.isPlaying = true
    self.isPaused = false
    self.pausedOffset = 0
    self.currentUrl = url
    if self.visualizer then self.visualizer.isPlaying = true end
    if self.btnPlay then self.btnPlay.isGlowActive = true end
    if self.btnPause then 
        self.btnPause.title = getTranslated("UI_VICCS_Pause", "PAUSAR")
        self.btnPause.isGlowActive = false 
    end
    self.currentTitle = "Conectando stream..."
    
    local x, y, z = 0, 0, 0
    if self.deviceType == "CDPLAYER" then
        x = self.player and self.player:getX() or 0
        y = self.player and self.player:getY() or 0
        z = self.player and self.player:getZ() or 0
    elseif self.deviceType == "VEHICLE" then
        local veh = self.vehicleObj
        if not veh and self.deviceObj then
            if instanceof(self.deviceObj, "BaseVehicle") then
                veh = self.deviceObj
            elseif self.deviceObj.getVehicle and self.deviceObj:getVehicle() then
                veh = self.deviceObj:getVehicle()
            elseif self.deviceObj.getParent and instanceof(self.deviceObj:getParent(), "BaseVehicle") then
                veh = self.deviceObj:getParent()
            end
        end
        x = veh and veh:getX() or 0
        y = veh and veh:getY() or 0
        z = veh and veh:getZ() or 0
    else
        x = self.deviceObj and self.deviceObj.getX and self.deviceObj:getX() or 0
        y = self.deviceObj and self.deviceObj.getY and self.deviceObj:getY() or 0
        z = self.deviceObj and self.deviceObj.getZ and self.deviceObj:getZ() or 0
    end
    
    -- Garante que o aparelho esteja ligado
    if self.deviceObj then
        pcall(function()
            local dd = self.deviceObj.getDeviceData and self.deviceObj:getDeviceData()
            if not dd and self.deviceObj.getItem and self.deviceObj:getItem() and self.deviceObj:getItem().getDeviceData then
                dd = self.deviceObj:getItem():getDeviceData()
            end
            if not dd and self.deviceObj.getPartById then
                local radioPart = self.deviceObj:getPartById("Radio")
                if radioPart and radioPart.getDeviceData then
                    dd = radioPart:getDeviceData()
                end
            end
            if dd and not dd:getIsTurnedOn() and dd.setIsTurnedOn then
                dd:setIsTurnedOn(true)
            end
        end)
    end
    
    if isClient() then
        sendClientCommand("VICCS", "PlayMedia", {
            deviceId = self.deviceId,
            x = x, y = y, z = z,
            url = url,
            volume = self.currentVolume,
            deviceType = self.deviceType
        })
    else
        VICCS.Main.registerPlayingDevice(self.deviceId, self.deviceObj, x, y, z, self.currentVolume, url, self.deviceType)
    end
end

function VICCS.UI.RadioDock:onResume()
    if VICCS.Compat and VICCS.Compat.hasDevicePower then
        local hasPower, isTurnedOn = VICCS.Compat.hasDevicePower(self.deviceObj)
        if not hasPower then
            if self.player and self.player.Say then
                self.player:Say(getTranslated("UI_VICCS_NoPower", "Sem energia ou bateria!"))
            end
            return
        end
        if not isTurnedOn and self.deviceObj and self.deviceObj.getDeviceData then
            pcall(function()
                local dd = self.deviceObj:getDeviceData()
                if dd and not dd:getIsTurnedOn() and dd.setIsTurnedOn then
                    dd:setIsTurnedOn(true)
                end
            end)
        end
    end

    if self.deviceType == "CDPLAYER" then
        local requireHP = (VICCS.Config and VICCS.Config.getSandboxVar and VICCS.Config.getSandboxVar("CDPlayerRequireHeadphones", true))
        if requireHP == nil then requireHP = true end
        if requireHP then
            local dd = self.deviceObj and self.deviceObj.getDeviceData and self.deviceObj:getDeviceData()
            local hasHeadphones = dd and dd.getHeadphoneType and dd:getHeadphoneType() >= 0
            if not hasHeadphones then
                if self.player and self.player.Say then
                    self.player:Say(getTranslated("UI_VICCS_NeedHeadphones", "Requer fones de ouvido conectados!"))
                end
                return
            end
        end
    end

    self.isPlaying = true
    self.isPaused = false
    if self.visualizer then self.visualizer.isPlaying = true end
    if self.btnPlay then self.btnPlay.isGlowActive = true end
    if self.btnPause then 
        self.btnPause.title = getTranslated("UI_VICCS_Pause", "PAUSAR")
        self.btnPause.isGlowActive = false 
    end
    self.currentTitle = "TRANSMITINDO AUDIO..."

    if isClient() then
        sendClientCommand("VICCS", "ResumeMedia", { deviceId = self.deviceId })
    else
        VICCS.Main.resumeDevice(self.deviceId)
    end
end

function VICCS.UI.RadioDock:onPause()
    if self.isPaused then
        self:onResume()
        return
    end

    if not self.isPlaying then return end
    
    self.isPlaying = false
    self.isPaused = true
    if self.visualizer then self.visualizer.isPlaying = false end
    if self.btnPlay then self.btnPlay.isGlowActive = false end
    if self.btnPause then 
        self.btnPause.title = getTranslated("UI_VICCS_Resume", "RETOMAR")
        self.btnPause.isGlowActive = true 
    end
    self.currentTitle = getTranslated("UI_VICCS_Paused", "PAUSADO")
    
    if isClient() then
        sendClientCommand("VICCS", "PauseMedia", { deviceId = self.deviceId })
    else
        VICCS.Main.pauseDevice(self.deviceId)
    end
end

function VICCS.UI.RadioDock:onStop()
    self.isPlaying = false
    self.isPaused = false
    self.pausedOffset = 0
    if self.visualizer then self.visualizer.isPlaying = false end
    if self.btnPlay then self.btnPlay.isGlowActive = false end
    if self.btnPause then 
        self.btnPause.title = getTranslated("UI_VICCS_Pause", "PAUSAR")
        self.btnPause.isGlowActive = false 
    end
    local defaultTitle = (self.deviceType == "CDPLAYER") and (getTranslated("UI_VICCS_CDPlayer_Title", "VICCS CD Player") .. " PRONTO") or (getTranslated("UI_VICCS_NoSignal", "SEM SINAL / OFF"))
    self.currentTitle = defaultTitle
    
    if isClient() then
        sendClientCommand("VICCS", "StopMedia", { deviceId = self.deviceId })
    else
        VICCS.Main.stopDevice(self.deviceId)
    end
end

function VICCS.UI.RadioDock:onVolumeChange(val)
    self.currentVolume = val
    if self.deviceObj then
        pcall(function()
            local dd = self.deviceObj.getDeviceData and self.deviceObj:getDeviceData()
            if not dd and self.deviceObj.getItem and self.deviceObj:getItem() and self.deviceObj:getItem().getDeviceData then
                dd = self.deviceObj:getItem():getDeviceData()
            end
            if dd and dd.setDeviceVolume then
                dd:setDeviceVolume(val)
            end
        end)
    end
    if isClient() then
        sendClientCommand("VICCS", "SetVolume", { deviceId = self.deviceId, volume = val })
    else
        VICCS.Main.updateDeviceVolume(self.deviceId, val)
    end
end

function VICCS.UI.RadioDock:onPasteClipboard()
    if Clipboard and Clipboard.getClipboard then
        local clip = Clipboard.getClipboard()
        if clip and clip ~= "" then
            self.urlInput:setText(clip)
        end
    end
end

function VICCS.UI.RadioDock:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
end

function VICCS.UI.RadioDock:prerender()
    ISPanel.prerender(self)
    local Theme = getTheme()
    
    -- Barra de cabeçalho
    self:drawRect(0, 0, self.width, 26, Theme.GlassBgHeader.a, Theme.GlassBgHeader.r, Theme.GlassBgHeader.g, Theme.GlassBgHeader.b)
    self:drawRectBorder(0, 0, self.width, 26, 0.5, Theme.GlassBorder.r, Theme.GlassBorder.g, Theme.GlassBorder.b)
    
    -- Título
    local titleText = (self.deviceType == "CDPLAYER")
        and getTranslated("UI_VICCS_CDPlayer_Title", "VICCS CD-Walkman Discman")
        or getTranslated("UI_VICCS_RadioDock_Title", "VICCS Audio Dock")
    self:drawText(titleText, 10, 6, Theme.Cyan.r, Theme.Cyan.g, Theme.Cyan.b, 1.0, UIFont.Small)
    
    -- LED Indicador de Status
    local ledColor = self.isPlaying and Theme.Green or Theme.Amber
    self:drawRect(self.width - 45, 10, 6, 6, 1.0, ledColor.r, ledColor.g, ledColor.b)
    
    -- Label de Volume & Alerta de Zumbis / Indicador Fones
    local volText = string.format("VOL: %d%%", math.floor(self.currentVolume * 100))
    self:drawText(volText, 12, 136, Theme.TextSecondary.r, Theme.TextSecondary.g, Theme.TextSecondary.b, 1.0, UIFont.Small)
    
    if self.deviceType == "CDPLAYER" then
        self:drawTextRight("[ FONES PRIVADOS ]", self.width - 12, 136, Theme.Cyan.r, Theme.Cyan.g, Theme.Cyan.b, 0.85, UIFont.Small)
    else
        if self.isPlaying and self.currentVolume > 0.4 then
            local pulseAlpha = math.abs(math.sin(getTimeInMillis() / 250))
            local warnText = getTranslated("UI_VICCS_AttractingZombies", "ATRAINDO ZUMBIS!")
            self:drawTextRight(warnText, self.width - 12, 136, Theme.Red.r, Theme.Red.g, Theme.Red.b, pulseAlpha, UIFont.Small)
        end
    end
end

function VICCS.UI.RadioDock:update()
    ISPanel.update(self)
    
    -- 1. Desliga streaming se o aparelho perdeu energia ou foi desligado
    if self.isPlaying and self.deviceObj then
        local isStillOn = true
        pcall(function()
            local dd = self.deviceObj.getDeviceData and self.deviceObj:getDeviceData()
            if dd and not dd:getIsTurnedOn() then
                isStillOn = false
            end
        end)
        
        if not isStillOn then
            self:onStop()
            if self.player and self.player.Say then
                self.player:Say(getTranslated("UI_VICCS_PowerLost", "Aparelho desligou (sem energia)!"))
            end
        end
    end
    
    -- 2. Distância máxima do jogador / Checagem de equipamento
    if self.deviceType == "CDPLAYER" then
        local isEquipped = false
        if self.player and self.deviceObj then
            local hotbar = getPlayerHotbar and getPlayerHotbar(self.player:getPlayerNum())
            isEquipped = (self.player:getPrimaryHandItem() == self.deviceObj) or
                         (self.player:getSecondaryHandItem() == self.deviceObj) or
                         (self.player.isAttachedItem and self.player:isAttachedItem(self.deviceObj)) or
                         (hotbar and hotbar.isInHotbar and hotbar:isInHotbar(self.deviceObj))
        end
        if not isEquipped then
            if self.isPlaying then
                self:onPause()
            end
            self:onClose()
        end
    else
        -- Distância máxima do jogador para aparelhos no mundo
        if self.player and self.deviceObj and self.deviceObj.getX and self.deviceObj.getY then
            local dist = IsoUtils.DistanceTo(self.player:getX(), self.player:getY(), self.deviceObj:getX(), self.deviceObj:getY())
            if dist > 3.5 then
                self:onClose()
            end
        end
    end
end
