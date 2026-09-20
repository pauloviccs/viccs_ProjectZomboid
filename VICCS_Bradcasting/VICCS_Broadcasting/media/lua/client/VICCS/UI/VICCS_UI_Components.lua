-- media/lua/client/VICCS/UI/VICCS_UI_Components.lua
-- Componentes reutilizáveis de UI: Botões com Glow, Sliders de Volume e Visualizador de Áudio VU-Meter

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "VICCS/VICCS_UI_Theme"

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
        GlassBorderGlow = { r = 0.0, g = 0.85, b = 1.0, a = 0.40 },
        ScreenInner = { r = 0.03, g = 0.04, b = 0.05, a = 0.96 },
        ScreenBorder = { r = 0.18, g = 0.20, b = 0.25, a = 0.90 },
        Cyan = { r = 0.0, g = 0.90, b = 1.0, a = 1.0 },
        Amber = { r = 1.0, g = 0.72, b = 0.0, a = 1.0 },
        Green = { r = 0.20, g = 0.95, b = 0.45, a = 1.0 },
        Red = { r = 1.0, g = 0.25, b = 0.25, a = 1.0 },
        TextPrimary = { r = 0.95, g = 0.96, b = 0.98, a = 1.0 },
        TextSecondary = { r = 0.70, g = 0.75, b = 0.85, a = 1.0 },
        TextMuted = { r = 0.45, g = 0.48, b = 0.55, a = 1.0 },
        ButtonBg = { r = 0.14, g = 0.17, b = 0.24, a = 0.90 },
        ButtonBgHover = { r = 0.20, g = 0.25, b = 0.35, a = 0.95 },
        ButtonBorder = { r = 0.30, g = 0.36, b = 0.48, a = 0.90 },
        ButtonBorderActive = { r = 0.0, g = 0.90, b = 1.0, a = 1.0 },
        SliderTrack = { r = 0.12, g = 0.14, b = 0.18, a = 1.0 },
        SliderFill = { r = 0.0, g = 0.85, b = 1.0, a = 1.0 },
        SliderKnob = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
    }
end

-- ==========================================================
-- 1. VICCSGlowButton: Botão estilizado com Hover e Glow Neon
-- ==========================================================
VICCS.UI.GlowButton = ISButton:derive("VICCSGlowButton")

function VICCS.UI.GlowButton:new(x, y, width, height, title, target, onclick)
    local o = ISButton:new(x, y, width, height, title, target, onclick)
    setmetatable(o, self)
    self.__index = self
    o.isGlowActive = false
    local Theme = getTheme()
    o.accentColor = Theme.Cyan
    return o
end

function VICCS.UI.GlowButton:prerender()
    local Theme = getTheme()
    local bg = self.mouseOver and Theme.ButtonBgHover or Theme.ButtonBg
    self:drawRect(0, 0, self.width, self.height, bg.a, bg.r, bg.g, bg.b)
    
    local border = self.isGlowActive and self.accentColor or (self.mouseOver and Theme.Cyan or Theme.ButtonBorder)
    self:drawRectBorder(0, 0, self.width, self.height, border.a, border.r, border.g, border.b)
    
    if self.mouseOver or self.isGlowActive then
        self:drawRect(1, 1, self.width - 2, 2, 0.4, border.r, border.g, border.b)
    end
end

function VICCS.UI.GlowButton:render()
    local Theme = getTheme()
    local txtColor = self.mouseOver and Theme.TextPrimary or Theme.TextSecondary
    local font = self.font or UIFont.Small
    local textHgt = getTextManager():getFontHeight(font)
    local textY = math.floor((self.height - textHgt) / 2)
    self:drawTextCentre(self.title, self.width / 2, textY, txtColor.r, txtColor.g, txtColor.b, txtColor.a, font)
end

-- ==========================================================
-- 2. VICCSSlider: Barra de Volume com Preenchimento Dinâmico
-- ==========================================================
VICCS.UI.VolumeSlider = ISPanel:derive("VICCSVolumeSlider")

function VICCS.UI.VolumeSlider:new(x, y, width, height, initialValue, onValueChange, target)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.value = math.max(0.0, math.min(1.0, initialValue or 0.7))
    o.onValueChange = onValueChange
    o.target = target
    o.isDragging = false
    return o
end

function VICCS.UI.VolumeSlider:onMouseDown(x, y)
    self.isDragging = true
    self:updateValueFromMouse(x)
    return true
end

function VICCS.UI.VolumeSlider:onMouseMove(dx, dy)
    if self.isDragging then
        local x = self:getMouseX()
        self:updateValueFromMouse(x)
    end
    return true
end

function VICCS.UI.VolumeSlider:onMouseUp(x, y)
    self.isDragging = false
    return true
end

function VICCS.UI.VolumeSlider:onMouseUpOutside(x, y)
    self.isDragging = false
    return true
end

function VICCS.UI.VolumeSlider:updateValueFromMouse(mouseX)
    local clampedX = math.max(0, math.min(self.width, mouseX))
    self.value = clampedX / self.width
    if self.onValueChange and self.target then
        self.onValueChange(self.target, self.value)
    end
end

function VICCS.UI.VolumeSlider:prerender()
    local Theme = getTheme()
    self:drawRect(0, 0, self.width, self.height, Theme.SliderTrack.a, Theme.SliderTrack.r, Theme.SliderTrack.g, Theme.SliderTrack.b)
    self:drawRectBorder(0, 0, self.width, self.height, 0.4, Theme.GlassBorder.r, Theme.GlassBorder.g, Theme.GlassBorder.b)
    
    local fillWidth = math.floor(self.width * self.value)
    if fillWidth > 0 then
        self:drawRect(1, 1, fillWidth, self.height - 2, 0.85, Theme.SliderFill.r, Theme.SliderFill.g, Theme.SliderFill.b)
    end
    
    local knobX = math.max(0, math.min(self.width - 4, fillWidth - 2))
    self:drawRect(knobX, 0, 4, self.height, 1.0, Theme.SliderKnob.r, Theme.SliderKnob.g, Theme.SliderKnob.b)
end

-- ==========================================================
-- 3. VICCSAudioVisualizer: Barras de Espectro VU-Meter Animadas
-- ==========================================================
VICCS.UI.AudioVisualizer = ISPanel:derive("VICCSAudioVisualizer")

function VICCS.UI.AudioVisualizer:new(x, y, width, height, numBars)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.numBars = numBars or 14
    o.isPlaying = false
    o.barHeights = {}
    for i = 1, o.numBars do
        o.barHeights[i] = 0.1
    end
    o.animTick = 0
    return o
end

function VICCS.UI.AudioVisualizer:prerender()
    local Theme = getTheme()
    self:drawRect(0, 0, self.width, self.height, Theme.ScreenInner.a, Theme.ScreenInner.r, Theme.ScreenInner.g, Theme.ScreenInner.b)
    self:drawRectBorder(0, 0, self.width, self.height, Theme.ScreenBorder.a, Theme.ScreenBorder.r, Theme.ScreenBorder.g, Theme.ScreenBorder.b)
    
    local barW = math.floor((self.width - (self.numBars + 1) * 2) / self.numBars)
    self.animTick = (self.animTick + 0.1) % 100
    
    for i = 1, self.numBars do
        local targetH = 0.08
        if self.isPlaying then
            local wave = math.sin(self.animTick * 2.5 + (i * 0.7)) * 0.4 + math.cos(self.animTick * 1.8 + i) * 0.4
            targetH = math.max(0.12, math.min(0.95, 0.5 + wave))
        end
        
        local curH = math.floor((self.height - 4) * targetH)
        local barX = 2 + (i - 1) * (barW + 2)
        local barY = self.height - 2 - curH
        
        local color = Theme.Green
        if targetH > 0.75 then
            color = Theme.Red
        elseif targetH > 0.50 then
            color = Theme.Amber
        end
        
        self:drawRect(barX, barY, barW, curH, 0.9, color.r, color.g, color.b)
    end
end
