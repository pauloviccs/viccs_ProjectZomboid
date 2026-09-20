-- media/lua/client/VICCS/UI/VICCS_UI_RadioDock.lua
-- Mini-Dock Premium flutuante para Rádios, Boomboxes e Aparelhos de Som (Estilo CHStatusHUD)

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

VICCS.UI.RadioDock = ISPanel:derive("VICCSRadioDock")

function VICCS.UI.RadioDock:new(x, y, width, height, player, deviceObj)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    
    local Theme = getTheme()
    o.player = player
    o.deviceObj = deviceObj
    o.moveWithMouse = true
    o.backgroundColor = Theme.GlassBg
    o.borderColor = Theme.GlassBorder
    
    o.currentVolume = 0.7
    o.isPlaying = false
    o.currentUrl = ""
    o.currentTitle = getText("UI_VICCS_NoSignal") or "SEM SINAL / OFF"
    local dx = deviceObj and deviceObj.getX and deviceObj:getX() or 0
    local dy = deviceObj and deviceObj.getY and deviceObj:getY() or 0
    local dz = deviceObj and deviceObj.getZ and deviceObj:getZ() or 0
    o.deviceId = "radio-" .. tostring(dx) .. "-" .. tostring(dy) .. "-" .. tostring(dz)
    
    -- Sincroniza estado se o aparelho já estiver tocando no mundo
    local activeData = VICCS.Main and VICCS.Main.getPlayingDevice and VICCS.Main.getPlayingDevice(o.deviceId)
    if activeData then
        o.isPlaying = true
        o.currentVolume = activeData.volume or o.currentVolume
        o.currentUrl = activeData.url or ""
        o.currentTitle = "TRANSMITINDO AUDIO..."
    elseif deviceObj and deviceObj.getModData then
        local md = deviceObj:getModData()
        if md and md.viccsMedia and md.viccsMedia.state == "PLAYING" then
            o.isPlaying = true
            o.currentVolume = md.viccsMedia.volume or o.currentVolume
            o.currentUrl = md.viccsMedia.url or ""
            o.currentTitle = "TRANSMITINDO AUDIO..."
            if VICCS.Main and VICCS.Main.registerPlayingDevice then
                VICCS.Main.registerPlayingDevice(o.deviceId, deviceObj, dx, dy, dz, o.currentVolume, o.currentUrl, "RADIO")
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
    
    -- Controles: Play, Pause, Stop
    local btnW = math.floor((self.width - (pad * 2) - 12) / 3)
    
    self.btnPlay = VICCS.UI.GlowButton:new(pad, curY, btnW, 28, getText("UI_VICCS_Play") or "TOCAR", self, self.onPlay)
    self.btnPlay:initialise()
    self.btnPlay.accentColor = Theme.Green
    if self.isPlaying then self.btnPlay.isGlowActive = true end
    self:addChild(self.btnPlay)
    
    self.btnPause = VICCS.UI.GlowButton:new(pad + btnW + 6, curY, btnW, 28, getText("UI_VICCS_Pause") or "PAUSAR", self, self.onPause)
    self.btnPause:initialise()
    self.btnPause.accentColor = Theme.Amber
    self:addChild(self.btnPause)
    
    self.btnStop = VICCS.UI.GlowButton:new(pad + (btnW * 2) + 12, curY, btnW, 28, getText("UI_VICCS_Stop") or "PARAR", self, self.onStop)
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
                self.player:Say(getText("UI_VICCS_NoPower") or "Sem energia ou bateria!")
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

    local url = VICCS.Config and VICCS.Config.cleanUrl and VICCS.Config.cleanUrl(self.urlInput:getText()) or self.urlInput:getText()
    if not url or url == "" then return end
    
    if VICCS.Config and VICCS.Config.isDomainAllowed and not VICCS.Config.isDomainAllowed(url) then
        if self.player and self.player.Say then
            self.player:Say("Link não suportado! Use YouTube ou SoundCloud.")
        end
        return
    end
    
    self.isPlaying = true
    if self.visualizer then self.visualizer.isPlaying = true end
    if self.btnPlay then self.btnPlay.isGlowActive = true end
    self.currentTitle = "Conectando stream..."
    
    local x = self.deviceObj and self.deviceObj.getX and self.deviceObj:getX() or 0
    local y = self.deviceObj and self.deviceObj.getY and self.deviceObj:getY() or 0
    local z = self.deviceObj and self.deviceObj.getZ and self.deviceObj:getZ() or 0
    
    if isClient() then
        sendClientCommand("VICCS", "PlayMedia", {
            deviceId = self.deviceId,
            x = x, y = y, z = z,
            url = url,
            volume = self.currentVolume,
            deviceType = "RADIO"
        })
    else
        VICCS.Main.registerPlayingDevice(self.deviceId, self.deviceObj, x, y, z, self.currentVolume, url, "RADIO")
    end
end

function VICCS.UI.RadioDock:onPause()
    self.isPlaying = false
    if self.visualizer then self.visualizer.isPlaying = false end
    if self.btnPlay then self.btnPlay.isGlowActive = false end
    
    if isClient() then
        sendClientCommand("VICCS", "PauseMedia", { deviceId = self.deviceId })
    else
        VICCS.Main.stopDevice(self.deviceId)
    end
end

function VICCS.UI.RadioDock:onStop()
    self.isPlaying = false
    if self.visualizer then self.visualizer.isPlaying = false end
    if self.btnPlay then self.btnPlay.isGlowActive = false end
    self.currentTitle = getText("UI_VICCS_NoSignal") or "SEM SINAL / OFF"
    
    if isClient() then
        sendClientCommand("VICCS", "StopMedia", { deviceId = self.deviceId })
    else
        VICCS.Main.stopDevice(self.deviceId)
    end
end

function VICCS.UI.RadioDock:onVolumeChange(val)
    self.currentVolume = val
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
    local titleText = getText("UI_VICCS_RadioDock_Title") or "VICCS Audio Dock"
    self:drawText(titleText, 10, 6, Theme.Cyan.r, Theme.Cyan.g, Theme.Cyan.b, 1.0, UIFont.Small)
    
    -- LED Indicador de Status
    local ledColor = self.isPlaying and Theme.Green or Theme.Amber
    self:drawRect(self.width - 45, 10, 6, 6, 1.0, ledColor.r, ledColor.g, ledColor.b)
    
    -- Label de Volume & Alerta de Zumbis
    local volText = string.format("VOL: %d%%", math.floor(self.currentVolume * 100))
    self:drawText(volText, 12, 136, Theme.TextSecondary.r, Theme.TextSecondary.g, Theme.TextSecondary.b, 1.0, UIFont.Small)
    
    if self.isPlaying and self.currentVolume > 0.4 then
        local pulseAlpha = math.abs(math.sin(getTimeInMillis() / 250))
        local warnText = getText("UI_VICCS_AttractingZombies") or "ATRAINDO ZUMBIS!"
        self:drawTextRight(warnText, self.width - 12, 136, Theme.Red.r, Theme.Red.g, Theme.Red.b, pulseAlpha, UIFont.Small)
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
                self.player:Say(getText("UI_VICCS_PowerLost") or "Aparelho desligou (sem energia)!")
            end
        end
    end
    
    -- 2. Distância máxima do jogador
    if self.player and self.deviceObj and self.deviceObj.getX and self.deviceObj.getY then
        local dist = IsoUtils.DistanceTo(self.player:getX(), self.player:getY(), self.deviceObj:getX(), self.deviceObj:getY())
        if dist > 3.5 then
            self:onClose()
        end
    end
end
