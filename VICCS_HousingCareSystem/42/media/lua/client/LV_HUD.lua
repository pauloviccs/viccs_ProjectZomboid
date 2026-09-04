-- =============================================================================
-- Housing Care System (Living House) - Frameless Glass HUD (LV_HUD.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Painel de status frameless com estética Glassmorphism inspirada no CHStatusHUD.
--   - Always-Visible com Auto-Fade LERP (25% em repouso / 100% no hover)
--   - Ícones oficiais vanilla 32x32 escalados no início de cada barra
--   - Fundo soft glass escuro translúcido (0.03, 0.035, 0.045)
--   - Linha de acento vertical de 2px à esquerda
--   - Entalhes de limiares (ticks) no estilo CHStatusHUD
--   - Alternância de modos no cabeçalho: Auto-Fade, Fixo (100%) e Recolhido
--   - Drag & Drop livre com salvamento de coordenadas
-- =============================================================================

require "ISUI/ISPanel"
require "LV_Config"
require "LV_DirtSystem"
require "LV_BladderNeed"

LV_HUD = ISPanel:derive("LV_HUD")

local instance = nil

local FONT_S = UIFont.Small
local PAD = 8
local ACCENT_CYAN = {0.36, 0.76, 0.86}
local ACCENT_AMBER = {0.92, 0.71, 0.29}

-- Texturas oficiais Vanilla B42 para ícones de barra
local ICON_COMFORT    = "media/ui/Moodles/32/Mood_Happy.png"
local ICON_ACCLIM     = "media/ui/Moodles/32/Mood_Concentrating.png"
local ICON_SQUALOR    = "media/ui/Moodles/32/Mood_NoxiousSmell.png"
local ICON_FLOOR_DIRT = "media/ui/Moodles/32/Status_Wet.png"
local ICON_BODY_DIRT  = "media/ui/Moodles/32/Status_Bleeding.png"
local ICON_BLADDER    = "media/ui/Moodles/32/Mood_Pained.png"

--- Cria uma nova instância do painel HUD.
function LV_HUD:new(x, y, width)
    local tm = getTextManager()
    local hgt = tm:getFontHeight(FONT_S)
    local o = ISPanel:new(x, y, width or 235, 100)
    setmetatable(o, self)
    self.__index = self

    o.fontH = hgt
    o.barH = math.max(4, math.floor(hgt * 0.40))
    o.rowH = hgt + 5
    o.headerH = hgt + 6
    o.moveWithMouse = true
    o.userHidden = false
    o.collapsed = false
    o.fadeMode = "auto"   -- "auto" (Fade no hover), "always" (100% nítido), "minimal"
    o.currentAlpha = 0.25 -- Inicia em repouso sutil
    o.targetAlpha = 0.25
    o.onlyProblems = false
    o.pulse = 0
    o.downX, o.downY = -1, -1
    o.isDragging = false
    return o
end

function LV_HUD:onMouseDown(x, y)
    self.downX = x
    self.downY = y
    self.isDragging = true
    return true
end

function LV_HUD:onMouseUp(x, y)
    if self.isDragging and math.abs(x - self.downX) <= 4 and math.abs(y - self.downY) <= 4 then
        -- Clique rápido no cabeçalho alterna modos
        if y <= self.headerH + PAD then
            if self.fadeMode == "auto" then
                self.fadeMode = "always"
            elseif self.fadeMode == "always" then
                self.collapsed = not self.collapsed
                if not self.collapsed then
                    self.fadeMode = "auto"
                end
            else
                self.collapsed = false
                self.fadeMode = "auto"
            end
        end
    end
    self.isDragging = false
    return true
end

function LV_HUD:onMouseMove(dx, dy)
    if self.isDragging then
        local newX = self:getX() + dx
        local newY = self:getY() + dy
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        newX = math.max(0, math.min(screenW - self.width, newX))
        newY = math.max(0, math.min(screenH - self.height, newY))
        self:setX(newX)
        self:setY(newY)
    end
end

function LV_HUD:onMouseUpOutside(x, y)
    self.isDragging = false
    return true
end

--- Desenha texto com sombra suave para máxima legibilidade
function LV_HUD:shadowText(text, x, y, r, g, b, a)
    self:drawText(text, x + 1, y + 1, 0, 0, 0, (a or 1) * 0.75, FONT_S)
    self:drawText(text, x, y, r or 1, g or 1, b or 1, a or 1, FONT_S)
end

function LV_HUD:shadowTextRight(text, x, y, r, g, b, a)
    local tm = getTextManager()
    local w = tm:MeasureStringX(FONT_S, text)
    self:shadowText(text, x - w, y, r, g, b, a)
end

--- Desenha uma barra fina no estilo CHStatusHUD com fundo translúcido e ticks
function LV_HUD:drawGauge(x, y, w, h, percent, color, ticks, alpha)
    local a = alpha or 1.0
    percent = math.max(0, math.min(1.0, percent or 0))

    -- Fundo do trilho da barra
    self:drawRect(x, y, w, h, 0.28 * a, 0.10, 0.12, 0.15)
    self:drawRect(x, y, w, 1, 0.15 * a, 1, 1, 1)

    -- Preenchimento suave
    local fill = math.floor(w * percent + 0.5)
    if fill > 0 then
        self:drawRect(x, y, fill, h, 0.90 * a, color[1], color[2], color[3])
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

function LV_HUD:prerender()
    -- Renderização tratada no render()
end

function LV_HUD:render()
    if self.userHidden or not LV_Config or not LV_Config.isEnabled() then return end
    local player = getPlayer()
    if not player or player:isDead() then return end

    local data = LV_BuffManager and LV_BuffManager.getPlayerData and LV_BuffManager.getPlayerData(player)
    if not data then return end

    local comfortTier = data.comfortTier or 0
    local comfortScore = data.comfortScore or 0
    local squalorTier = data.squalorTier or 0
    local squalorScore = data.squalorScore or 0
    local bladderNeed = (LV_BladderNeed and LV_BladderNeed.getNeed and LV_BladderNeed.getNeed(player)) or 0
    local sq = player:getCurrentSquare()
    local locKey = (sq and LV_DirtSystem and LV_DirtSystem.getCurrentLocationKey and LV_DirtSystem.getCurrentLocationKey(player, sq)) or "outside"
    local floorDirt = (locKey ~= "outside" and LV_DirtSystem and LV_DirtSystem.getFloorDirt and LV_DirtSystem.getFloorDirt(locKey)) or 0
    local footDirt = (LV_DirtSystem and LV_DirtSystem.getFootDirt and LV_DirtSystem.getFootDirt(player)) or 0
    local bodyDirt = (LV_DirtSystem and LV_DirtSystem.getPlayerBodyDirt and LV_DirtSystem.getPlayerBodyDirt(player)) or 0

    local isAcclimatizing = (data.isInShelter and comfortTier == 0 and data.targetComfortScore and data.targetComfortScore > 0)

    -- Controle de Interpolação Linear (LERP) de Transparência (Auto-Fade)
    local isOver = self:isMouseOver()
    if self.fadeMode == "always" then
        self.targetAlpha = 1.0
    elseif isOver then
        self.targetAlpha = 1.0
    else
        self.targetAlpha = 0.25 -- Repouso translúcido sutil
    end

    self.currentAlpha = self.currentAlpha + (self.targetAlpha - self.currentAlpha) * 0.15
    local a = self.currentAlpha

    self.pulse = (self.pulse + 1) % 60
    local p = self.pulse
    local tri = p < 30 and (p / 30) or ((60 - p) / 30)

    local acc = ACCENT_CYAN
    if squalorTier > 0 or bladderNeed >= 80 or bodyDirt >= 75 then
        acc = ACCENT_AMBER
    end

    -- 1. Fundo Soft Glass escuro translúcido
    self:drawRect(0, 0, self.width, self.height, 0.75 * a, 0.03, 0.035, 0.045)
    -- Linha de acento vertical de 2px à esquerda
    self:drawRect(0, 0, 2, self.height, 0.85 * a, acc[1], acc[2], acc[3])

    -- 2. Cabeçalho / Título (Living House + Modo)
    local curY = PAD
    local modeTag = self.fadeMode == "always" and "[FIXO]" or "[AUTO]"
    local title = "LIVING HOUSE " .. modeTag
    if data.baseName and data.baseName ~= "" and data.baseName ~= "Lar" and data.baseName ~= "Living House" then
        title = string.format("LIVING HOUSE - %s %s", data.baseName, modeTag)
    end
    self:shadowText(title, PAD + 4, curY, acc[1], acc[2], acc[3], 0.95 * a)

    if self.collapsed then
        self:shadowTextRight("[+]", self.width - PAD, curY, 0.7, 0.7, 0.7, 0.8 * a)
        self:setHeight(curY + self.fontH + PAD)
        return
    else
        self:shadowTextRight("[-]", self.width - PAD, curY, 0.7, 0.7, 0.7, 0.6 * a)
    end

    curY = curY + self.fontH + 3
    self:drawRect(PAD, curY, self.width - PAD * 2, 1, 0.20 * a, acc[1], acc[2], acc[3])
    curY = curY + 4

    local barW = self.width - (PAD * 2)
    local iconSz = math.max(14, self.fontH - 2)

    -- Helper de renderização de linha com ícone
    local function drawBarLine(iconPath, label, valStr, pct, color, ticks, lr, lg, lb, vr, vg, vb)
        local iconTex = getTexture(iconPath)
        if iconTex then
            self:drawTextureScaled(iconTex, PAD, curY + 1, iconSz, iconSz, 0.95 * a, 1, 1, 1)
        end
        self:shadowText(label, PAD + iconSz + 4, curY, lr or 0.75, lg or 0.80, lb or 0.85, 1.0 * a)
        self:shadowTextRight(valStr, self.width - PAD, curY, vr or 0.85, vg or 0.85, vb or 0.85, 1.0 * a)
        curY = curY + self.fontH + 1
        self:drawGauge(PAD, curY, barW, self.barH, pct, color, ticks, a)
        curY = curY + self.barH + 6
    end

    -- Barra Especial: Aclimatando ao Lar (Carregamento enquanto permanece dentro da base)
    if isAcclimatizing then
        local reqAcclim = (LV_Config and LV_Config.get and LV_Config.get("AcclimatizationMinutes")) or 30
        local curDwell = data.shelterDwellMinutes or 0
        local acclimPct = math.min(1.0, math.max(0.0, curDwell / reqAcclim))
        local acclimStr = string.format("%d%%", math.floor(acclimPct * 100))
        local acclimColor = {0.20, 0.85 + 0.15 * tri, 0.85}
        drawBarLine(ICON_ACCLIM, "Aclimatando ao Lar", acclimStr, acclimPct, acclimColor, {0.25, 0.50, 0.75},
            0.55, 0.90, 0.95, 0.30, 0.95, 0.90)

        -- Conforto Estimado que será concedido ao completar o carregamento
        local estTier = (LV_BuffManager and LV_BuffManager.getComfortTierFromScore and LV_BuffManager.getComfortTierFromScore(data.targetComfortScore or 0)) or 1
        local estLabel = string.format("Conforto Estimado (T%d)", estTier)
        local estValStr = string.format("%d pts", data.targetComfortScore or 0)
        local estColor = {0.30, 0.75, 0.50}
        drawBarLine(ICON_COMFORT, estLabel, estValStr, (data.targetComfortScore or 0) / 100.0, estColor, {0.2, 0.4, 0.6, 0.8},
            0.70, 0.80, 0.75, 0.35, 0.85, 0.45)
    elseif comfortTier > 0 or not self.onlyProblems then
        -- Linha 1: Conforto do Lar (Buff Ativo)
        local label = string.format("Conforto (Tier %d)", comfortTier)
        local valStr = string.format("%d pts", comfortScore)
        local color = {0.30, 0.88, 0.42}
        drawBarLine(ICON_COMFORT, label, valStr, comfortScore / 100.0, color, {0.2, 0.4, 0.6, 0.8},
            0.75, 0.80, 0.85, 0.35, 0.90, 0.45)
    end

    -- Linha 2: Squalor / Insalubridade
    if squalorScore > 0 or squalorTier > 0 or not self.onlyProblems then
        local label = string.format("Insalubridade (Nivel %d)", squalorTier)
        local valStr = string.format("%d pts", squalorScore)
        local color = {0.92, 0.38, 0.22}
        drawBarLine(ICON_SQUALOR, label, valStr, squalorScore / 100.0, color, {0.2, 0.4, 0.6, 0.8},
            0.95, 0.65, 0.45, 0.95, 0.40, 0.20)
    end

    -- Linha 3: Higiene da Base (Piso e Calçados)
    if floorDirt >= 10 or footDirt >= 15 or not self.onlyProblems then
        local label = "Sujeira Piso / Calcado"
        local valStr = string.format("%d%% | %d%%", math.floor(floorDirt), math.floor(footDirt))
        local floorPercent = math.min(1.0, (floorDirt + footDirt * 0.5) / 100.0)
        local color = (floorPercent >= 0.5) and {0.90, 0.50, 0.20} or {0.70, 0.75, 0.40}
        drawBarLine(ICON_FLOOR_DIRT, label, valStr, floorPercent, color, {0.5},
            0.70, 0.75, 0.80, 0.80, 0.70, 0.40)
    end

    -- Linha 4: Sujeira Corporal / Higiene do Sobrevivente
    if bodyDirt >= 15 or not self.onlyProblems then
        local isCrit = (bodyDirt >= 75)
        local label = isCrit and "Necessita Banho!" or "Sujeira Corporal"
        local valStr = string.format("%d%%", math.floor(bodyDirt))
        local color = isCrit and {0.90, 0.32, 0.22} or {0.78, 0.58, 0.30}
        local lr, lg, lb = isCrit and 1.0 or 0.75, isCrit and (0.30 + 0.4 * tri) or 0.80, isCrit and 0.20 or 0.85
        local vr, vg, vb = isCrit and 1.0 or 0.85, isCrit and 0.30 or 0.65, isCrit and 0.20 or 0.35
        drawBarLine(ICON_BODY_DIRT, label, valStr, bodyDirt / 100.0, color, {0.5, 0.75},
            lr, lg, lb, vr, vg, vb)
    end

    -- Linha 5: Necessidade de Banheiro / Bexiga
    if bladderNeed >= 20 or not self.onlyProblems then
        local isCrit = (bladderNeed >= 80)
        local label = isCrit and "Aperto / Banheiro!" or "Necessidade Banheiro"
        local valStr = string.format("%d%%", math.floor(bladderNeed))
        local color = isCrit and {0.95, 0.25, 0.20} or {0.85, 0.75, 0.28}
        local lr, lg, lb = isCrit and 1.0 or 0.75, isCrit and (0.30 + 0.4 * tri) or 0.80, isCrit and 0.20 or 0.85
        local vr, vg, vb = isCrit and 1.0 or 0.85, isCrit and 0.30 or 0.80, isCrit and 0.20 or 0.30
        drawBarLine(ICON_BLADDER, label, valStr, bladderNeed / 100.0, color, {0.6, 0.8, 0.95},
            lr, lg, lb, vr, vg, vb)
    end

    self:setHeight(curY + PAD)
end

--- Exibe ou inicializa a HUD para ficar sempre visível
function LV_HUD.showHUD()
    if not instance then
        local screenW = getCore():getScreenWidth()
        local hudW = 235
        local x = screenW - hudW - 20
        local y = 200
        instance = LV_HUD:new(x, y, hudW)
        instance:initialise()
        instance:instantiate()
        instance:addToUIManager()
        instance:setAlwaysOnTop(true)
        print("[LivingHouse] LV_HUD frameless glass inicializado e visivel!")
    else
        instance.userHidden = false
        instance:setVisible(true)
    end
end

--- Alterna visibilidade da HUD (tecla K)
function LV_HUD.toggleHUD()
    if not instance then
        LV_HUD.showHUD()
    else
        instance.userHidden = not instance.userHidden
        instance:setVisible(not instance.userHidden)
    end
end
