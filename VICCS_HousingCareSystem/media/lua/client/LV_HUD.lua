-- =============================================================================
-- Housing Care System (Lar Vivo) - Custom HUD Component (LV_HUD.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Painel de interface moderno, discreto e translúcido para exibição em tempo
--   real dos índices de Conforto, Squalor e Aclimatação na Base.
--   Suporta arrasto livre com o mouse (Drag & Drop) e limites de tela.
-- =============================================================================

require "ISUI/ISPanel"

LV_HUD = ISPanel:derive("LV_HUD")

local instance = nil

--- Cria uma nova instância do painel HUD.
function LV_HUD:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.backgroundColor = {r = 0.08, g = 0.10, b = 0.12, a = 0.78}
    o.borderColor = {r = 0.25, g = 0.35, b = 0.45, a = 0.85}
    o.anchorLeft = true
    o.anchorRight = false
    o.anchorTop = true
    o.anchorBottom = false
    o.moveWithMouse = true
    o.userHidden = false
    o.isDragging = false
    o.dragStartX = 0
    o.dragStartY = 0
    return o
end

--- Eventos de clique e arrasto com o mouse (Drag and Drop)
function LV_HUD:onMouseDown(x, y)
    self.isDragging = true
    self.dragStartX = x
    self.dragStartY = y
    return true
end

function LV_HUD:onMouseUp(x, y)
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

function LV_HUD:onMouseMoveOutside(dx, dy)
    if self.isDragging then
        self:onMouseMove(dx, dy)
    end
end

function LV_HUD:onMouseUpOutside(x, y)
    self.isDragging = false
    return true
end

--- Sobrescreve o prerender do ISPanel para evitar desenhar fundo cinza vazio.
function LV_HUD:prerender()
    -- Toda renderização ocorre no render()
end

--- Renderização de cada quadro do widget na tela.
function LV_HUD:render()
    if self.userHidden or not LV_Config or not LV_Config.isEnabled() then return end

    local player = getPlayer()
    if not player then return end

    if not LV_BuffManager or not LV_BuffManager.getPlayerData then return end
    local data = LV_BuffManager.getPlayerData(player)
    if not data then return end

    local hasComfort = (data.comfortTier and data.comfortTier > 0)
    local hasSqualor = (data.squalorTier and data.squalorTier > 0)
    local isAcclimatizing = (data.isInShelter and data.comfortTier == 0 and data.targetComfortScore and data.targetComfortScore > 0)

    -- Se não houver nenhum status ativo e não estiver aclimatando, o HUD fica 100% oculto
    if not hasComfort and not hasSqualor and not isAcclimatizing then return end

    local currentHour = getGameTime():getWorldAgeHours()
    local margin = 8
    local barWidth = self.width - (margin * 2)
    local barHeight = 8

    -- 1. Moldura e Fundo Translúcido Moderno
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    -- Alça sutil de arrasto no canto superior direito
    self:drawRect(self.width - 12, 3, 2, 2, 0.6, 0.8, 0.8, 0.8)
    self:drawRect(self.width - 8, 3, 2, 2, 0.6, 0.8, 0.8, 0.8)
    self:drawRect(self.width - 4, 3, 2, 2, 0.6, 0.8, 0.8, 0.8)
    self:drawRect(self.width - 12, 6, 2, 2, 0.6, 0.8, 0.8, 0.8)
    self:drawRect(self.width - 8, 6, 2, 2, 0.6, 0.8, 0.8, 0.8)
    self:drawRect(self.width - 4, 6, 2, 2, 0.6, 0.8, 0.8, 0.8)

    -- Determina textos a serem exibidos
    local title = ""
    local statusText = ""
    local barColor = {r = 0.20, g = 0.85, b = 0.40, a = 0.95}
    local barBgColor = {r = 0.10, g = 0.20, b = 0.12, a = 0.60}
    local barBorderColor = {r = 0.25, g = 0.50, b = 0.30, a = 0.80}
    local titleColor = {r = 0.95, g = 0.95, b = 0.95}
    local statusColor = {r = 0.70, g = 0.90, b = 0.70}
    local fillProgress = 1.0

    if hasSqualor then
        local score = math.max(0, math.min(100, data.squalorScore or 0))
        fillProgress = score / 100
        local remainingHours = math.max(0, (data.squalorExpiryWorldHour or 0) - currentHour)
        barColor = {r = 0.90, g = 0.35, b = 0.15, a = 0.95}
        barBgColor = {r = 0.25, g = 0.08, b = 0.08, a = 0.60}
        barBorderColor = {r = 0.45, g = 0.20, b = 0.15, a = 0.80}
        titleColor = {r = 0.95, g = 0.65, b = 0.50}
        statusColor = {r = 0.85, g = 0.45, b = 0.35}

        local def = LV_MoodleDefs and LV_MoodleDefs.SqualorTiers and LV_MoodleDefs.SqualorTiers[data.squalorTier]
        title = def and LV_MoodleDefs.getText(def.titleKey, def.defaultTitle) or "Ambiente Insalubre"
        if baseName then title = baseName .. " | " .. title end
        if data.isInSqualorArea then
            statusText = LV_MoodleDefs and LV_MoodleDefs.getText("UI_LV_HUD_Exposed", "Exposto a Sujeira") or "Exposto a Sujeira"
        else
            statusText = string.format("Contaminado: %.1fh", remainingHours)
        end

    elseif isAcclimatizing then
        local req = (LV_Config and LV_Config.get and LV_Config.get("AcclimatizationMinutes")) or 30
        local cur = math.max(0, math.min(req, data.shelterDwellMinutes or 0))
        fillProgress = req > 0 and (cur / req) or 1.0
        barColor = {r = 0.25, g = 0.70, b = 0.95, a = 0.95}
        barBgColor = {r = 0.08, g = 0.18, b = 0.28, a = 0.60}
        barBorderColor = {r = 0.20, g = 0.50, b = 0.75, a = 0.80}
        titleColor = {r = 0.85, g = 0.92, b = 1.0}
        statusColor = {r = 0.65, g = 0.85, b = 0.95}

        title = baseName and (baseName .. " | Relaxando...") or "Relaxando no Lar..."
        statusText = string.format("Aclimatando: %d%% (%d/%d min)", math.floor(fillProgress * 100), math.floor(cur), math.floor(req))

    elseif hasComfort then
        local score = math.max(0, math.min(100, data.comfortScore or 0))
        fillProgress = score / 100
        local remainingHours = math.max(0, (data.comfortExpiryWorldHour or 0) - currentHour)

        local def = LV_MoodleDefs and LV_MoodleDefs.ComfortTiers and LV_MoodleDefs.ComfortTiers[data.comfortTier]
        title = def and LV_MoodleDefs.getText(def.titleKey, def.defaultTitle) or "Lar Aconchegante"
        if baseName then title = baseName .. " | " .. title end

        local hmData = LV_BuffManager.getHomemakingData and LV_BuffManager.getHomemakingData(player)
        local hmBonus = (hmData and hmData.dailyHours and hmData.dailyHours > 0) and string.format(" (+%.1fh Tarefas)", hmData.dailyHours) or ""
        statusText = string.format("Restante: %.1fh%s", remainingHours, hmBonus)
    end

    -- Ajuste dinâmico de largura para ZERO vazamento de texto
    local textMgr = getTextManager()
    local titleW = textMgr and textMgr:MeasureStringX(UIFont.Small, title) or 120
    local statusW = textMgr and textMgr:MeasureStringX(UIFont.Small, statusText) or 100
    local neededW = math.max(220, math.max(titleW, statusW) + (margin * 2) + 20)

    if self.width ~= neededW then
        self:setWidth(neededW)
    end

    local actualBarWidth = self.width - (margin * 2)

    -- 1. Moldura e Fundo Translúcido Moderno
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    -- Alça sutil de arrasto no canto superior direito
    self:drawRect(self.width - 12, 3, 2, 2, 0.6, 0.8, 0.8, 0.8)
    self:drawRect(self.width - 8, 3, 2, 2, 0.6, 0.8, 0.8, 0.8)
    self:drawRect(self.width - 4, 3, 2, 2, 0.6, 0.8, 0.8, 0.8)
    self:drawRect(self.width - 12, 6, 2, 2, 0.6, 0.8, 0.8, 0.8)
    self:drawRect(self.width - 8, 6, 2, 2, 0.6, 0.8, 0.8, 0.8)
    self:drawRect(self.width - 4, 6, 2, 2, 0.6, 0.8, 0.8, 0.8)

    -- Barra de Progresso
    local fillW = math.max(2, actualBarWidth * math.max(0.02, math.min(1.0, fillProgress)))
    self:drawRect(margin, margin + 2, actualBarWidth, barHeight, barBgColor.a, barBgColor.r, barBgColor.g, barBgColor.b)
    self:drawRect(margin, margin + 2, fillW, barHeight, barColor.a, barColor.r, barColor.g, barColor.b)
    self:drawRectBorder(margin, margin + 2, actualBarWidth, barHeight, barBorderColor.a, barBorderColor.r, barBorderColor.g, barBorderColor.b)

    -- Textos perfeitamente contidos
    self:drawText(title, margin, 22, titleColor.r, titleColor.g, titleColor.b, 1.0, UIFont.Small)
    self:drawText(statusText, margin, 36, statusColor.r, statusColor.g, statusColor.b, 1.0, UIFont.Small)
end

--- Alterna a visibilidade manual do HUD via tecla 'K'.
function LV_HUD.toggleHUD()
    if instance then
        instance.userHidden = not instance.userHidden
    end
end

--- Inicialização automática na tela após o jogo carregar.
local function initHUD()
    if instance then return end
    local screenW = getCore():getScreenWidth()
    instance = LV_HUD:new(screenW - 220, 12, 210, 54)
    instance:initialise()
    instance:instantiate()
    instance:addToUIManager()
    instance:setVisible(true)
    instance.userHidden = false
end

Events.OnGameStart.Add(initHUD)
Events.OnCreatePlayer.Add(initHUD)
