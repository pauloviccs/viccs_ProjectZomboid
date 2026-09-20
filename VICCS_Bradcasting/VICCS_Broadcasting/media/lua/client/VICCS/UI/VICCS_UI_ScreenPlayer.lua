-- media/lua/client/VICCS/UI/VICCS_UI_ScreenPlayer.lua
-- Interface de Monitor CRT e Computador Retro dos anos 90 para Televisores e PCs (Fase 5)

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
        ScreenInner = { r = 0.03, g = 0.04, b = 0.05, a = 0.96 },
        ScreenBorder = { r = 0.18, g = 0.20, b = 0.25, a = 0.90 },
        Cyan = { r = 0.0, g = 0.90, b = 1.0, a = 1.0 },
        Amber = { r = 1.0, g = 0.72, b = 0.0, a = 1.0 },
        Green = { r = 0.20, g = 0.95, b = 0.45, a = 1.0 },
        Red = { r = 1.0, g = 0.25, b = 0.25, a = 1.0 },
        TextPrimary = { r = 0.95, g = 0.96, b = 0.98, a = 1.0 },
        TextSecondary = { r = 0.70, g = 0.75, b = 0.85, a = 1.0 },
        TextMuted = { r = 0.45, g = 0.48, b = 0.55, a = 1.0 }
    }
end

VICCS.UI.ScreenPlayer = ISPanel:derive("VICCSScreenPlayer")

function VICCS.UI.ScreenPlayer:new(x, y, width, height, player, deviceObj, deviceType)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    
    local Theme = getTheme()
    o.player = player
    o.deviceObj = deviceObj
    o.deviceType = deviceType or "TELEVISION"
    o.moveWithMouse = true
    o.backgroundColor = Theme.GlassBg
    o.borderColor = Theme.GlassBorder
    
    o.currentVolume = 0.8
    o.isPlaying = false
    o.currentUrl = ""
    o.currentTitle = "CANAL 03 - SINAL AV"
    
    local dx = deviceObj and deviceObj.getX and deviceObj:getX() or 0
    local dy = deviceObj and deviceObj.getY and deviceObj:getY() or 0
    local dz = deviceObj and deviceObj.getZ and deviceObj:getZ() or 0
    o.deviceId = "screen-" .. tostring(dx) .. "-" .. tostring(dy) .. "-" .. tostring(dz)
    
    -- Sincroniza estado se o aparelho já estiver tocando no mundo
    local activeData = VICCS.Main and VICCS.Main.getPlayingDevice and VICCS.Main.getPlayingDevice(o.deviceId)
    if activeData then
        o.isPlaying = true
        o.currentVolume = activeData.volume or o.currentVolume
        o.currentUrl = activeData.url or ""
        o.currentTitle = "SINTONIZANDO TRANSMISSAO..."
    elseif deviceObj and deviceObj.getModData then
        local md = deviceObj:getModData()
        if md and md.viccsMedia and md.viccsMedia.state == "PLAYING" then
            o.isPlaying = true
            o.currentVolume = md.viccsMedia.volume or o.currentVolume
            o.currentUrl = md.viccsMedia.url or ""
            o.currentTitle = "SINTONIZANDO TRANSMISSAO..."
            if VICCS.Main and VICCS.Main.registerPlayingDevice then
                VICCS.Main.registerPlayingDevice(o.deviceId, deviceObj, dx, dy, dz, o.currentVolume, o.currentUrl, o.deviceType)
            end
        end
    end
    
    return o
end

function VICCS.UI.ScreenPlayer:initialise()
    ISPanel.initialise(self)
    self:createChildren()
end

function VICCS.UI.ScreenPlayer:createChildren()
    local pad = 16
    local curY = 32
    local Theme = getTheme()
    
    -- Botão Fechar no topo direito
    local btnClose = VICCS.UI.GlowButton:new(self.width - 32, 6, 26, 20, "X", self, self.onClose)
    btnClose:initialise()
    self:addChild(btnClose)
    
    -- 1. Moldura da Tela CRT / Monitor
    local screenW = self.width - (pad * 2)
    local screenH = 160
    self.screenX = pad
    self.screenY = curY
    self.screenW = screenW
    self.screenH = screenH
    
    -- Visualizador de Espectro dentro da tela da TV
    self.visualizer = VICCS.UI.AudioVisualizer:new(pad + 8, curY + screenH - 50, screenW - 16, 42, 22)
    self.visualizer:initialise()
    self.visualizer.isPlaying = self.isPlaying
    self:addChild(self.visualizer)
    
    curY = curY + screenH + 12
    
    -- 2. Input de URL do YouTube
    local inputW = self.width - (pad * 2) - 70
    self.urlInput = ISTextEntryBox:new(self.currentUrl or "", pad, curY, inputW, 26)
    self.urlInput:initialise()
    self.urlInput:instantiate()
    self.urlInput:setClearButton(true)
    self:addChild(self.urlInput)
    
    local btnPaste = VICCS.UI.GlowButton:new(self.width - pad - 64, curY, 64, 26, "Colar", self, self.onPasteClipboard)
    btnPaste:initialise()
    self:addChild(btnPaste)
    
    curY = curY + 36
    
    -- 3. Controles de Transporte: Play, Pause, Stop
    local btnW = math.floor((self.width - (pad * 2) - 16) / 3)
    
    self.btnPlay = VICCS.UI.GlowButton:new(pad, curY, btnW, 30, getText("UI_VICCS_Play") or "TOCAR", self, self.onPlay)
    self.btnPlay:initialise()
    self.btnPlay.accentColor = Theme.Green
    self.btnPlay.isGlowActive = self.isPlaying
    self:addChild(self.btnPlay)
    
    self.btnPause = VICCS.UI.GlowButton:new(pad + btnW + 8, curY, btnW, 30, getText("UI_VICCS_Pause") or "PAUSAR", self, self.onPause)
    self.btnPause:initialise()
    self.btnPause.accentColor = Theme.Amber
    self:addChild(self.btnPause)
    
    self.btnStop = VICCS.UI.GlowButton:new(pad + (btnW * 2) + 16, curY, btnW, 30, getText("UI_VICCS_Stop") or "PARAR", self, self.onStop)
    self.btnStop:initialise()
    self.btnStop.accentColor = Theme.Red
    self:addChild(self.btnStop)
    
    curY = curY + 40
    
    -- 4. Barra de Volume Estilizada
    self.volumeSlider = VICCS.UI.VolumeSlider:new(pad, curY + 16, self.width - (pad * 2), 14, self.currentVolume, self.onVolumeChange, self)
    self.volumeSlider:initialise()
    self:addChild(self.volumeSlider)
end

function VICCS.UI.ScreenPlayer:onPlay()
    -- 1. Checa energia antes de qualquer ação
    if VICCS.Compat and VICCS.Compat.hasDevicePower then
        local hasPower, isTurnedOn = VICCS.Compat.hasDevicePower(self.deviceObj)
        if not hasPower then
            if self.player and self.player.Say then
                self.player:Say(getText("UI_VICCS_NoPower") or "Sem energia ou bateria!")
            end
            return
        end
        
        -- Liga o dispositivo no motor vanilla para consumir energia
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
            self.player:Say("Sinal nao compativel! Insira um link valido do YouTube.")
        end
        return
    end
    
    self.isPlaying = true
    self.currentUrl = url
    if self.visualizer then self.visualizer.isPlaying = true end
    if self.btnPlay then self.btnPlay.isGlowActive = true end
    self.currentTitle = "SINTONIZANDO TRANSMISSAO..."
    
    local x = self.deviceObj and self.deviceObj.getX and self.deviceObj:getX() or 0
    local y = self.deviceObj and self.deviceObj.getY and self.deviceObj:getY() or 0
    local z = self.deviceObj and self.deviceObj.getZ and self.deviceObj:getZ() or 0
    
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

function VICCS.UI.ScreenPlayer:onPause()
    self.isPlaying = false
    if self.visualizer then self.visualizer.isPlaying = false end
    if self.btnPlay then self.btnPlay.isGlowActive = false end
    
    if isClient() then
        sendClientCommand("VICCS", "PauseMedia", { deviceId = self.deviceId })
    else
        VICCS.Main.stopDevice(self.deviceId)
    end
end

function VICCS.UI.ScreenPlayer:onStop()
    self.isPlaying = false
    self.currentUrl = ""
    if self.visualizer then self.visualizer.isPlaying = false end
    if self.btnPlay then self.btnPlay.isGlowActive = false end
    self.currentTitle = "CANAL 03 - SINAL AV"
    
    if isClient() then
        sendClientCommand("VICCS", "StopMedia", { deviceId = self.deviceId })
    else
        VICCS.Main.stopDevice(self.deviceId)
    end
end

function VICCS.UI.ScreenPlayer:onVolumeChange(val)
    self.currentVolume = val
    if isClient() then
        sendClientCommand("VICCS", "SetVolume", { deviceId = self.deviceId, volume = val })
    else
        VICCS.Main.updateDeviceVolume(self.deviceId, val)
    end
end

function VICCS.UI.ScreenPlayer:onPasteClipboard()
    if Clipboard and Clipboard.getClipboard then
        local clip = Clipboard.getClipboard()
        if clip and clip ~= "" then
            self.urlInput:setText(clip)
        end
    end
end

-- Fechar a janela apenas esconde a UI: o som e a transmissão continuam no mundo!
function VICCS.UI.ScreenPlayer:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
end

function VICCS.UI.ScreenPlayer:prerender()
    ISPanel.prerender(self)
    local Theme = getTheme()
    
    -- Cabeçalho
    self:drawRect(0, 0, self.width, 28, Theme.GlassBgHeader.a, Theme.GlassBgHeader.r, Theme.GlassBgHeader.g, Theme.GlassBgHeader.b)
    self:drawRectBorder(0, 0, self.width, 28, 0.5, Theme.GlassBorder.r, Theme.GlassBorder.g, Theme.GlassBorder.b)
    
    local titleText = (self.deviceType == "COMPUTER") and "VICCS Terminal PC-98 Media" or (getText("UI_VICCS_TVPlayer_Title") or "VICCS Video & Broadcast Monitor")
    self:drawText(titleText, 12, 6, Theme.Cyan.r, Theme.Cyan.g, Theme.Cyan.b, 1.0, UIFont.Small)
    
    -- Fundo da Tela CRT
    self:drawRect(self.screenX, self.screenY, self.screenW, self.screenH, Theme.ScreenInner.a, Theme.ScreenInner.r, Theme.ScreenInner.g, Theme.ScreenInner.b)
    self:drawRectBorder(self.screenX, self.screenY, self.screenW, self.screenH, Theme.ScreenBorder.a, Theme.ScreenBorder.r, Theme.ScreenBorder.g, Theme.ScreenBorder.b)
    
    -- Efeito de Scanlines CRT sutis
    for lineY = self.screenY + 2, self.screenY + self.screenH - 2, 4 do
        self:drawRect(self.screenX + 2, lineY, self.screenW - 4, 1, 0.12, 0.0, 0.8, 1.0)
    end
    
    -- Display do Canal / Faixa na tela CRT (Texto ASCII limpo)
    local statusColor = self.isPlaying and Theme.Green or Theme.Amber
    self:drawText(self.currentTitle, self.screenX + 14, self.screenY + 12, statusColor.r, statusColor.g, statusColor.b, 0.95, UIFont.Medium)
    
    if not self.isPlaying then
        self:drawText("COLE A URL DO VIDEO ABAIXO PARA TRANSMITIR", self.screenX + 14, self.screenY + 36, Theme.TextMuted.r, Theme.TextMuted.g, Theme.TextMuted.b, 0.8, UIFont.Small)
    end
    
    -- Volume Label & Alerta de Zumbis
    local volY = self.screenY + self.screenH + 12 + 36 + 40
    local volText = string.format("VOLUME MESTRE: %d%%", math.floor(self.currentVolume * 100))
    self:drawText(volText, 16, volY, Theme.TextSecondary.r, Theme.TextSecondary.g, Theme.TextSecondary.b, 1.0, UIFont.Small)
    
    if self.isPlaying and self.currentVolume > 0.4 then
        local pulseAlpha = math.abs(math.sin(getTimeInMillis() / 250))
        local warnText = getText("UI_VICCS_AttractingZombies") or "ATRAINDO ZUMBIS!"
        self:drawTextRight(warnText, self.width - 16, volY, Theme.Red.r, Theme.Red.g, Theme.Red.b, pulseAlpha, UIFont.Small)
    end
end

function VICCS.UI.ScreenPlayer:update()
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
    
    -- 2. Distância máxima do jogador (fecha o controle remoto sem parar o som)
    if self.player and self.deviceObj and self.deviceObj.getX and self.deviceObj.getY then
        local dist = IsoUtils.DistanceTo(self.player:getX(), self.player:getY(), self.deviceObj:getX(), self.deviceObj:getY())
        if dist > 4.0 then
            self:onClose()
        end
    end
end
