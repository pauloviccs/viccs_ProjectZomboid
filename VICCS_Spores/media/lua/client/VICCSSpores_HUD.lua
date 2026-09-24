-- =============================================================================
-- VICCS Spores - Monitor de Sobrevivencia & Toxicidade Pulmonar (Client)
-- Versao: 1.4.0 (Fixed-Column Premium Layout, Zero-Overlap Guarantee,
-- Drag & Drop, Minimize, Close, Shortcut 'K' & Ghost Mode)
-- =============================================================================

require "ISUI/ISPanel"
require "VICCSSpores_Grid"
require "VICCSSpores_Exposure"

local SporeHUD = ISPanel:derive("VICCSSpores_HUD")

local FONT_S = UIFont.Small
local PAD = 8
local ACCENT_CYAN  = { 0.36, 0.76, 0.86 }
local ACCENT_AMBER = { 0.92, 0.71, 0.29 }
local ACCENT_RED   = { 0.95, 0.25, 0.25 }
local ACCENT_GREEN = { 0.35, 0.82, 0.40 }

-- Icones oficiais Vanilla B42 para os medidores
local ICON_LUNGS = "media/ui/Moodles/32/Status_DifficultyBreathing.png"
local ICON_SPORES = "media/ui/Moodles/32/Mood_NoxiousSmell.png"
local ICON_MASK   = "media/ui/Moodles/32/Mood_Concentrating.png"

function SporeHUD:new(x, y, width)
    local tm = getTextManager()
    local hgt = tm:getFontHeight(FONT_S)
    -- Largura generosa de 325px para comportar barras + textos longos lado a lado
    local o = ISPanel:new(x, y, width or 325, 106)
    setmetatable(o, self)
    self.__index = self
    
    o.fontH = hgt
    o.barH = math.max(5, math.floor(hgt * 0.44))
    o.rowH = hgt + 6
    o.headerH = hgt + 6
    o.fullHeight = 106
    o.collapsedHeight = o.headerH + 6
    
    -- Estados da HUD: "expanded", "collapsed", "hidden"
    o.viewMode = "expanded"
    o.moving = false
    o.dragX = 0
    o.dragY = 0
    
    -- Transparencia adaptativa (Ghost mode)
    o.currentAlpha = 0.20
    o.targetAlpha = 0.20
    o.pulse = 0
    
    o.texLungs  = getTexture(ICON_LUNGS)
    o.texSpores = getTexture(ICON_SPORES)
    o.texMask   = getTexture(ICON_MASK)
    
    return o
end

function SporeHUD:initialise()
    ISPanel.initialise(self)
    self.background = false
end

-- =============================================================================
-- PERSISTENCIA DE POSICAO E ESTADO
-- =============================================================================
function SporeHUD:saveState()
    local player = getPlayer()
    if player then
        local md = player:getModData()
        md.viccsHUD_X = self.x
        md.viccsHUD_Y = self.y
        md.viccsHUD_Mode = self.viewMode
    end
end

function SporeHUD:loadState()
    local player = getPlayer()
    if player then
        local md = player:getModData()
        if md.viccsHUD_X and md.viccsHUD_Y then
            local sw = getCore():getScreenWidth()
            local sh = getCore():getScreenHeight()
            local nx = math.max(4, math.min(sw - self.width - 4, md.viccsHUD_X))
            local ny = math.max(4, math.min(sh - self.height - 4, md.viccsHUD_Y))
            self:setX(nx)
            self:setY(ny)
        end
        if md.viccsHUD_Mode then
            self.viewMode = md.viccsHUD_Mode
            if self.viewMode == "collapsed" then
                self:setHeight(self.collapsedHeight)
            elseif self.viewMode == "expanded" then
                self:setHeight(self.fullHeight)
            end
        end
    end
end

-- =============================================================================
-- INTERATIVIDADE: DRAG & DROP NO CABECALHO E BOTOES DE CONTROLE
-- =============================================================================
function SporeHUD:onMouseDown(x, y)
    if self.viewMode == "hidden" then return false end
    
    -- Botao Fechar [ X ] (Topo direito)
    if x >= (self.width - 20) and x <= (self.width - 4) and y >= 2 and y <= 18 then
        self.viewMode = "hidden"
        self:saveState()
        return true
    end
    
    -- Botao Minimizar / Expandir [ _ ] / [ + ]
    if x >= (self.width - 38) and x <= (self.width - 22) and y >= 2 and y <= 18 then
        if self.viewMode == "collapsed" then
            self.viewMode = "expanded"
            self:setHeight(self.fullHeight)
        else
            self.viewMode = "collapsed"
            self:setHeight(self.collapsedHeight)
        end
        self:saveState()
        return true
    end
    
    -- Drag pelo cabecalho
    if y >= 0 and y <= (self.headerH + 4) then
        self.moving = true
        self.dragX = x
        self.dragY = y
        return true
    end
    
    -- Cliques no corpo da HUD passam atraves para nao travar combate/movimento
    return false
end

function SporeHUD:onMouseMove(dx, dy)
    if self.moving then
        local mouseX = getMouseX()
        local mouseY = getMouseY()
        local newX = mouseX - self.dragX
        local newY = mouseY - self.dragY
        
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        newX = math.max(4, math.min(sw - self.width - 4, newX))
        newY = math.max(4, math.min(sh - self.height - 4, newY))
        
        self:setX(newX)
        self:setY(newY)
    end
end

function SporeHUD:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function SporeHUD:onMouseUp(x, y)
    if self.moving then
        self.moving = false
        self:saveState()
        return true
    end
    return false
end

function SporeHUD:onMouseUpOutside(x, y)
    if self.moving then
        self.moving = false
        self:saveState()
    end
end

function SporeHUD:isPointOver(x, y)
    if self.viewMode == "hidden" then return false end
    -- Apenas captura mouse se estiver sobre a barra de titulo (para botoes e drag)
    return (y >= 0 and y <= (self.headerH + 4))
end

--- Desenha texto com sombra suave para maxima legibilidade
function SporeHUD:shadowText(text, x, y, r, g, b, a)
    self:drawText(text, x + 1, y + 1, 0, 0, 0, (a or 1) * 0.75, FONT_S)
    self:drawText(text, x, y, r or 1, g or 1, b or 1, a or 1, FONT_S)
end

function SporeHUD:shadowTextRight(text, x, y, r, g, b, a)
    local tm = getTextManager()
    local w = tm:MeasureStringX(FONT_S, text)
    self:shadowText(text, x - w, y, r, g, b, a)
end

--- Desenha medidor com fundo translucido e entalhes (ticks) no estilo Living House
function SporeHUD:drawGauge(x, y, w, h, percent, color, ticks, alpha)
    local a = alpha or 1.0
    percent = math.max(0, math.min(1.0, percent or 0))

    -- Trilho da barra
    self:drawRect(x, y, w, h, 0.28 * a, 0.10, 0.12, 0.15)
    self:drawRect(x, y, w, 1, 0.15 * a, 1, 1, 1)

    -- Preenchimento suave
    local fill = math.floor(w * percent + 0.5)
    if fill > 0 then
        self:drawRect(x, y, fill, h, 0.88 * a, color[1], color[2], color[3])
        self:drawRect(x, y, fill, 1, 0.35 * a, 1, 1, 1)
    end

    -- Entalhes discretos (ticks)
    if ticks then
        for _, t in ipairs(ticks) do
            local tx = x + math.floor(w * t)
            if tx > x and tx < (x + w) then
                self:drawRect(tx, y, 1, h, 0.60 * a, 0.02, 0.02, 0.03)
            end
        end
    end
end

function SporeHUD:prerender()
    if self.viewMode == "hidden" then return end
    
    local player = getPlayer()
    if not player or player:isDead() then return end
    
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())
    
    local conc = VICCSSpores.Grid.get(px, py, pz)
    local md = player:getModData()
    local dose = (md and md.viccsDose) or 0.0
    local threshold = (VICCSSpores.Exposure and VICCSSpores.Exposure.getThreshold()) or 120.0
    local lungPercent = math.min(1.0, dose / threshold)
    local prot = (VICCSSpores.Exposure and VICCSSpores.Exposure.getProtection(player)) or 0.0
    local isInfected = (md and md.viccsSporeInfected) or false
    
    -- Auto-Fade Living House (Ghost Mode): 
    -- Super translucido (0.16) se ar puro e seguro, nitidez total (0.90) sob risco
    if conc > 1.0 or dose > 5.0 or isInfected then
        self.targetAlpha = 0.90
    else
        self.targetAlpha = 0.18
    end
    self.currentAlpha = self.currentAlpha + (self.targetAlpha - self.currentAlpha) * 0.10
    local a = self.currentAlpha
    
    -- Pulso de aviso para estados criticos
    self.pulse = (self.pulse + 1) % 60
    local p = self.pulse
    local pulseFactor = p < 30 and (p / 30) or ((60 - p) / 30)
    
    -- Determina cor de acento do painel
    local acc = ACCENT_CYAN
    if isInfected or lungPercent >= 0.75 then
        acc = { ACCENT_RED[1] * (0.8 + 0.2 * pulseFactor), ACCENT_RED[2], ACCENT_RED[3] }
    elseif conc > 2.0 or lungPercent >= 0.35 then
        acc = ACCENT_AMBER
    end
    
    local curH = (self.viewMode == "collapsed") and self.collapsedHeight or self.fullHeight
    
    -- 1. Fundo Soft Glass escuro translucido
    self:drawRect(0, 0, self.width, curH, 0.75 * a, 0.025, 0.03, 0.04)
    -- Linha de acento vertical de 2px a esquerda
    self:drawRect(0, 0, 2, curH, 0.88 * a, acc[1], acc[2], acc[3])
    
    -- 2. Cabecalho / Barra de Titulo
    local curY = PAD - 2
    local headerTitle = getText("UI_VICCS_HUD_Title")
    self:shadowText(headerTitle, PAD + 4, curY, acc[1], acc[2], acc[3], a * 0.95)
    
    -- Botoes de Controle no Cabecalho [ _ / + ] e [ X ]
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    local isOverMin = (mouseX >= (self.width - 38) and mouseX <= (self.width - 22) and mouseY >= 2 and mouseY <= 18)
    local isOverClose = (mouseX >= (self.width - 20) and mouseX <= (self.width - 4) and mouseY >= 2 and mouseY <= 18)
    
    -- Botao Minimizar
    local minLabel = (self.viewMode == "collapsed") and "+" or "_"
    local minR, minG, minB = isOverMin and 1.0 or 0.7, isOverMin and 0.9 or 0.7, isOverMin and 0.5 or 0.7
    self:drawText(minLabel, self.width - 32, curY - 2, minR, minG, minB, a * 0.9, FONT_S)
    
    -- Botao Fechar
    local closeR, closeG, closeB = isOverClose and 1.0 or 0.7, isOverClose and 0.3 or 0.7, isOverClose and 0.3 or 0.7
    self:drawText("x", self.width - 15, curY - 2, closeR, closeG, closeB, a * 0.9, FONT_S)
    
    -- Se colapsado, mostra apenas resumo de status em chip compacto
    if self.viewMode == "collapsed" then
        local summaryText = getText("UI_VICCS_Air_Pure")
        local sumColor = ACCENT_CYAN
        if isInfected then
            summaryText = "INFECTADO"
            sumColor = ACCENT_RED
        elseif conc > 0 then
            summaryText = string.format("Ar: %.1f", conc)
            sumColor = ACCENT_AMBER
        elseif dose > 0 then
            summaryText = string.format("Pulmao: %d%%", math.floor(lungPercent * 100))
            sumColor = ACCENT_AMBER
        end
        self:shadowTextRight("[" .. summaryText .. "]", self.width - 46, curY, sumColor[1], sumColor[2], sumColor[3], a * 0.95)
        return
    end
    
    curY = curY + self.headerH
    
    -- Linha divisoria sutil abaixo do cabecalho
    self:drawRect(PAD, curY - 3, self.width - (PAD * 2), 1, 0.15 * a, 1, 1, 1)
    
    -- =========================================================================
    -- DIAGRAMACAO PREMIUM EM COLUNAS FIXAS (ZERO OVERLAP GARANTIDO)
    -- =========================================================================
    -- Coluna 1: Icone (x = 8, w = 14)
    -- Coluna 2: Barra / Gauge (x = 28, w = 110 fixo, fim = 138)
    -- Margem Livre de Seguranca: 12px (x = 138 a 150)
    -- Coluna 3: Texto de Status (x = 150 alinhado a esquerda, espaco livre = 165px!)
    -- =========================================================================
    local iconSize = 14
    local iconX = PAD + 2
    local barX = PAD + iconSize + 6       -- 28
    local barW = 110                     -- Barra compacta de alta densidade
    local textX = barX + barW + 12        -- 150 (Alinhamento a esquerda limpo)
    local ticks = { 0.25, 0.50, 0.75 }
    
    -- -------------------------------------------------------------------------
    -- LINHA 1: STATUS DOS PULMOES (DOSE INALADA)
    -- -------------------------------------------------------------------------
    if self.texLungs then
        self:drawTextureScaled(self.texLungs, iconX, curY, iconSize, iconSize, a * 0.9, 1, 1, 1)
    end
    
    local lungColor = ACCENT_GREEN
    if isInfected or lungPercent >= 0.75 then
        lungColor = ACCENT_RED
    elseif lungPercent >= 0.35 then
        lungColor = ACCENT_AMBER
    end
    
    self:drawGauge(barX, curY + 4, barW, self.barH, lungPercent, lungColor, ticks, a)
    
    local lungLabel = string.format("%d%%", math.floor(lungPercent * 100))
    if isInfected then
        lungLabel = getText("UI_VICCS_Lungs_Infected")
    elseif conc <= 0 and dose > 0 then
        lungLabel = string.format("%d%% [Recup]", math.floor(lungPercent * 100))
    end
    self:shadowText(lungLabel, textX, curY, lungColor[1], lungColor[2], lungColor[3], a)
    curY = curY + self.rowH
    
    -- -------------------------------------------------------------------------
    -- LINHA 2: QUALIDADE DO AR LOCAL (CONCENTRACAO DE ESPOROS NA CELULA)
    -- -------------------------------------------------------------------------
    if self.texSpores then
        self:drawTextureScaled(self.texSpores, iconX, curY, iconSize, iconSize, a * 0.9, 1, 1, 1)
    end
    
    local airPercent = math.min(1.0, conc / VICCSSpores.MAX_CONC)
    local airColor = ACCENT_CYAN
    local airLabel = getText("UI_VICCS_Air_Pure")
    
    if conc >= 60.0 then
        airColor = ACCENT_RED
        airLabel = getText("UI_VICCS_Air_Lethal")
    elseif conc >= 30.0 then
        airColor = ACCENT_RED
        airLabel = getText("UI_VICCS_Air_Dangerous")
    elseif conc >= 10.0 then
        airColor = ACCENT_AMBER
        airLabel = getText("UI_VICCS_Air_Moderate")
    elseif conc > 0.0 then
        airColor = ACCENT_AMBER
        airLabel = getText("UI_VICCS_Air_Light")
    end
    
    self:drawGauge(barX, curY + 4, barW, self.barH, airPercent, airColor, ticks, a)
    self:shadowText(airLabel, textX, curY, airColor[1], airColor[2], airColor[3], a)
    curY = curY + self.rowH
    
    -- -------------------------------------------------------------------------
    -- LINHA 3: FILTRAGEM / MASCARA FACIAL
    -- -------------------------------------------------------------------------
    if self.texMask then
        self:drawTextureScaled(self.texMask, iconX, curY, iconSize, iconSize, a * 0.9, 1, 1, 1)
    end
    
    local maskColor = ACCENT_RED
    local maskLabel = getText("UI_VICCS_Mask_None")
    
    if prot >= 0.70 then
        maskColor = ACCENT_GREEN
        local rawText = getText("UI_VICCS_Mask_Active")
        local ok, res = pcall(string.format, rawText, math.floor(prot * 100))
        maskLabel = ok and res or string.format("Ativa (%d%%)", math.floor(prot * 100))
    elseif prot > 0.0 then
        maskColor = ACCENT_AMBER
        local rawText = getText("UI_VICCS_Mask_Partial")
        local ok, res = pcall(string.format, rawText, math.floor(prot * 100))
        maskLabel = ok and res or string.format("Parcial (%d%%)", math.floor(prot * 100))
    end
    
    self:drawGauge(barX, curY + 4, barW, self.barH, prot, maskColor, ticks, a)
    self:shadowText(maskLabel, textX, curY, maskColor[1], maskColor[2], maskColor[3], a)
end

local function initHUD()
    if SporeHUD.instance then return end
    
    local sh = getCore():getScreenHeight()
    local hud = SporeHUD:new(45, sh - 148, 325)
    hud:initialise()
    hud:instantiate()
    
    if hud.javaObject then
        hud.javaObject:setConsumeMouseEvents(false)
        hud.javaObject:setIgnoreLossControl(true)
    end
    
    hud:addToUIManager()
    hud:loadState()
    SporeHUD.instance = hud
end

-- =============================================================================
-- ATALHO DE TECLADO (SHORTCUT KEYBIND 'K')
-- Alterna entre: Expandido -> Minimizado -> Oculto -> Expandido
-- =============================================================================
local function onKeyPressed(key)
    if key == Keyboard.KEY_K then
        if SporeHUD.instance then
            local hud = SporeHUD.instance
            if hud.viewMode == "expanded" then
                hud.viewMode = "collapsed"
                hud:setHeight(hud.collapsedHeight)
            elseif hud.viewMode == "collapsed" then
                hud.viewMode = "hidden"
            else
                hud.viewMode = "expanded"
                hud:setHeight(hud.fullHeight)
            end
            hud:saveState()
        end
    end
end

Events.OnCreateUI.Add(initHUD)
Events.OnKeyPressed.Add(onKeyPressed)

print("[VICCS Spores v" .. VICCSSpores.VERSION .. "] HUD v1.4.0 (Fixed-Column Zero-Overlap Layout) ativo.")
