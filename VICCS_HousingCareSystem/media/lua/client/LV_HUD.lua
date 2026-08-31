-- =============================================================================
-- Housing Care System (Lar Vivo) - The Sims-Style HUD (LV_HUD.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Interface gráfica sutil, limpa e adaptável para Comfort e Squalor.
--   Renderiza a barra verde quando há conforto ativo e barra de alerta quando
--   o ambiente for insalubre. Oculta-se completamente quando sem efeitos ativos.
--   Atalho padrão de visibilidade: Tecla 'K'.
-- =============================================================================

require "ISUI/ISPanel"

LV_HUD = ISPanel:derive("LV_HUD")

local instance = nil

--- Construtor do painel do HUD.
-- @param x (number): Posição X
-- @param y (number): Posição Y
-- @param width (number): Largura
-- @param height (number): Altura
function LV_HUD:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0.06, g=0.08, b=0.10, a=0.85}
    o.borderColor = {r=0.20, g=0.25, b=0.30, a=0.90}
    o.visible = true
    o.userHidden = false
    return o
end

--- Sobrescreve o prerender do ISPanel para evitar desenhar fundo cinza vazio.
function LV_HUD:prerender()
    -- Não desenha nada no prerender padrão do ISPanel. Toda renderização ocorre no render()
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

    -- Se não houver nenhum status ativo, o HUD fica 100% oculto e transparente
    if not hasComfort and not hasSqualor then return end

    local currentHour = getGameTime():getWorldAgeHours()
    local margin = 8
    local barWidth = self.width - (margin * 2)
    local barHeight = 8

    -- 1. Moldura e Fundo Translúcido Moderno
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    -- 2. Renderização de Estado: Squalor (Insalubridade) ou Comfort
    if hasSqualor then
        local score = math.max(0, math.min(100, data.squalorScore or 0))
        local fillWidth = math.max(2, barWidth * (score / 100))
        local remainingHours = math.max(0, (data.squalorExpiryWorldHour or 0) - currentHour)

        -- Barra de Fundo e Preenchimento Âmbar/Tóxico
        self:drawRect(margin, margin, barWidth, barHeight, 0.6, 0.25, 0.08, 0.08)
        self:drawRect(margin, margin, fillWidth, barHeight, 0.95, 0.90, 0.35, 0.15)
        self:drawRectBorder(margin, margin, barWidth, barHeight, 0.8, 0.45, 0.20, 0.15)

        -- Título do Nível de Insalubridade
        local def = LV_MoodleDefs and LV_MoodleDefs.SqualorTiers and LV_MoodleDefs.SqualorTiers[data.squalorTier]
        local title = def and LV_MoodleDefs.getText(def.titleKey, def.defaultTitle) or "Ambiente Insalubre"
        self:drawText(title, margin, 20, 0.95, 0.65, 0.50, 1.0, UIFont.Small)

        -- Texto de Status
        local statusText = ""
        if data.isInSqualorArea then
            statusText = LV_MoodleDefs and LV_MoodleDefs.getText("UI_LV_HUD_Exposed", "Exposto a Sujeira") or "Exposto a Sujeira"
        else
            local fmt = LV_MoodleDefs and LV_MoodleDefs.getText("UI_LV_HUD_Contaminated", "Contaminado: %sh") or "Contaminado: %sh"
            statusText = string.format(fmt, string.format("%.1f", remainingHours))
        end
        self:drawText(statusText, margin, 34, 0.85, 0.45, 0.35, 1.0, UIFont.Small)

    elseif hasComfort then
        local score = math.max(0, math.min(100, data.comfortScore or 0))
        local fillWidth = math.max(2, barWidth * (score / 100))
        local remainingHours = math.max(0, (data.comfortExpiryWorldHour or 0) - currentHour)

        -- Barra de Fundo e Preenchimento Verde Esmeralda
        self:drawRect(margin, margin, barWidth, barHeight, 0.6, 0.10, 0.20, 0.12)
        self:drawRect(margin, margin, fillWidth, barHeight, 0.95, 0.20, 0.85, 0.40)
        self:drawRectBorder(margin, margin, barWidth, barHeight, 0.8, 0.25, 0.50, 0.30)

        -- Título do Tier de Conforto
        local def = LV_MoodleDefs and LV_MoodleDefs.ComfortTiers and LV_MoodleDefs.ComfortTiers[data.comfortTier]
        local title = def and LV_MoodleDefs.getText(def.titleKey, def.defaultTitle) or "Lar Aconchegante"
        self:drawText(title, margin, 20, 0.95, 0.95, 0.95, 1.0, UIFont.Small)

        -- Tempo Restante / Status na Base
        local fmt = LV_MoodleDefs and LV_MoodleDefs.getText("UI_LV_HUD_Remaining", "Restante: %sh") or "Restante: %sh"
        local statusText = string.format(fmt, string.format("%.1f", remainingHours))
        self:drawText(statusText, margin, 34, 0.70, 0.90, 0.70, 1.0, UIFont.Small)
    end
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
    instance = LV_HUD:new(screenW - 190, 55, 180, 52)
    instance:initialise()
    instance:addToUIManager()
end

Events.OnGameStart.Add(initHUD)
