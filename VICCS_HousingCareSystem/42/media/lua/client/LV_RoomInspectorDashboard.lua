-- =============================================================================
-- Housing Care System (Living House) - Room & Ambient Inspector (LV_RoomInspectorDashboard.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Painel de inspeção aprofundada do cômodo e ambiente no padrão Frameless Glass:
--   - Detalhamento granular de pontuação por categoria (Mobílias, Eletrônicos, Decor, 3D)
--   - Inventário visual com pontuação individual e curva decrescente
--   - Comparativo claro de TIER DO CÔMODO vs TIER GERAL DA SAFEHOUSE
--   - Diagnóstico inteligente ELI5 indicando o que falta para subir de Tier
--   - Tecla de atalho dedicada 'K' e botão de alternância rápida para Infraestrutura [J]
-- =============================================================================

require "ISUI/ISPanel"
require "LV_Config"
require "LV_ComfortScanner"
require "LV_ItemScoreData"
require "LV_BuffManager"

LV_RoomInspectorDashboard = ISPanel:derive("LV_RoomInspectorDashboard")

local instance = nil

local FONT_S = UIFont.Small
local FONT_M = UIFont.Medium
local PAD = 10
local ACCENT_CYAN = {0.36, 0.76, 0.86}
local ACCENT_AMBER = {0.92, 0.71, 0.29}
local ACCENT_GREEN = {0.30, 0.88, 0.45}
local ACCENT_RED = {0.95, 0.25, 0.25}

--- Cria uma nova instância do painel de inspeção de cômodo
function LV_RoomInspectorDashboard:new(x, y, width, height)
    local tm = getTextManager()
    local hgt = tm:getFontHeight(FONT_S)
    local w = width or 420
    local h = height or 380

    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.fontH = hgt
    o.moveWithMouse = true
    o.userHidden = true
    o.downX, o.downY = -1, -1
    o.isDragging = false

    o.cachedBreakdown = nil
    o.lastRefreshTime = 0
    o.scrollOffset = 0
    return o
end

--- Retorna a instância única do Painel de Inspeção (Singleton)
function LV_RoomInspectorDashboard.getInstance()
    if not instance then
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        local w = 420
        local h = 380
        local x = math.floor((screenW - w) / 2) + 20
        local y = math.floor((screenH - h) / 2) - 20

        instance = LV_RoomInspectorDashboard:new(x, y, w, h)
        instance:initialise()
        instance:instantiate()
        instance:addToUIManager()
        instance:setVisible(false)
    end
    return instance
end

--- Alterna a visibilidade do painel (Toggle)
function LV_RoomInspectorDashboard.toggle()
    local dash = LV_RoomInspectorDashboard.getInstance()
    if dash then
        local isVis = dash:getIsVisible()
        dash:setVisible(not isVis)
        if not isVis then
            dash:refreshData(true)
        end
    end
end

function LV_RoomInspectorDashboard:onMouseDown(x, y)
    self.downX = x
    self.downY = y
    self.isDragging = true
    return true
end

function LV_RoomInspectorDashboard:onMouseUp(x, y)
    if self.isDragging and math.abs(x - self.downX) <= 4 and math.abs(y - self.downY) <= 4 then
        -- Botão de Fechar [X] no canto superior direito
        if x >= (self.width - 28) and y <= 24 then
            self:setVisible(false)
            return true
        end

        -- Botão rápido para alternar para Dashboard de Infraestrutura [J]
        if x >= (self.width - 105) and x <= (self.width - 32) and y <= 24 then
            if LV_HouseDashboard and LV_HouseDashboard.toggle then
                self:setVisible(false)
                LV_HouseDashboard.toggle()
                return true
            end
        end
    end
    self.isDragging = false
    return true
end

function LV_RoomInspectorDashboard:onMouseMove(dx, dy)
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

function LV_RoomInspectorDashboard:onMouseUpOutside(x, y)
    self.isDragging = false
    return true
end

function LV_RoomInspectorDashboard:onMouseWheel(del)
    self.scrollOffset = math.max(0, math.min(30, self.scrollOffset + (del * 2)))
    return true
end

--- Desenha texto com quebra de linha automática respeitando a largura máxima
function LV_RoomInspectorDashboard:drawWrappedText(text, x, y, maxW, r, g, b, a, font)
    font = font or FONT_S
    local tm = getTextManager()
    local hgt = self.fontH or tm:getFontHeight(font)
    local words = {}
    for word in string.gmatch(text or "", "%S+") do
        table.insert(words, word)
    end

    local line = ""
    local curY = y
    for _, word in ipairs(words) do
        local testLine = (line == "") and word or (line .. " " .. word)
        if tm:MeasureStringX(font, testLine) > maxW and line ~= "" then
            self:drawText(line, x, curY, r, g, b, a or 1.0, font)
            curY = curY + hgt + 2
            line = word
        else
            line = testLine
        end
    end
    if line ~= "" then
        self:drawText(line, x, curY, r, g, b, a or 1.0, font)
        curY = curY + hgt + 2
    end
    return curY
end

--- Atualiza os dados de telemetria do cômodo
function LV_RoomInspectorDashboard:refreshData(force)
    local curTime = (getGameTime and getGameTime():getWorldAgeHours()) or 0
    if not force and self.cachedBreakdown and (curTime - self.lastRefreshTime < 0.05) then
        return self.cachedBreakdown
    end

    local player = getPlayer()
    local sq = player and player:getCurrentSquare()

    local own = (LV_ComfortScanner and LV_ComfortScanner.getBuildingOwnershipStatus and LV_ComfortScanner.getBuildingOwnershipStatus(sq, player)) or nil

    -- 1. Verificação instantânea de Área Externa (ao ar livre / fora de casa)
    if (own and own.status == "OUTSIDE") or (sq and sq.isOutside and sq:isOutside()) then
        local breakdown = {
            locKey = "outside",
            roomName = "Area Externa",
            roomScore = 0,
            roomTier = 0,
            safehouseScore = 0,
            safehouseTier = 0,
            cleanPoints = 0,
            furniturePoints = 0,
            lightingPoints = 0,
            decorPoints = 0,
            craftBonus = 0,
            squalorScore = 0,
            seasonalNote = "Ao Ar Livre",
            itemsList = {},
            categoryStats = {},
            isOutside = true,
            isClaimed = false
        }
        self.cachedBreakdown = breakdown
        self.lastRefreshTime = curTime
        return breakdown
    end

    -- 2. Verificação instantânea de Imóvel Neutro / Não Reivindicado
    if own and not own.isClaimed then
        local locKey = (LV_DirtSystem and LV_DirtSystem.getCurrentLocationKey and LV_DirtSystem.getCurrentLocationKey(player, sq)) or "unclaimed"
        local breakdown = {
            locKey = locKey,
            roomName = own.roomName or "Residencia (Nao Reivindicado)",
            roomScore = 0,
            roomTier = 0,
            safehouseScore = 0,
            safehouseTier = 0,
            cleanPoints = 0,
            furniturePoints = 0,
            lightingPoints = 0,
            decorPoints = 0,
            craftBonus = 0,
            squalorScore = 0,
            seasonalNote = "Imovel Nao Reivindicado",
            itemsList = {},
            categoryStats = {},
            isUnclaimed = true,
            isClaimed = false
        }
        self.cachedBreakdown = breakdown
        self.lastRefreshTime = curTime
        return breakdown
    end

    local locKey = (LV_DirtSystem and LV_DirtSystem.getCurrentLocationKey and LV_DirtSystem.getCurrentLocationKey(player, sq)) or "room_default"
    local breakdown = (LV_ComfortScanner and LV_ComfortScanner.getRoomBreakdown and LV_ComfortScanner.getRoomBreakdown(locKey)) or {}
    self.cachedBreakdown = breakdown
    self.lastRefreshTime = curTime
    return breakdown
end

--- Desenha uma barra fina estilizada no padrão CHStatusHUD
function LV_RoomInspectorDashboard:drawGauge(x, y, w, h, percent, color, ticks)
    percent = math.max(0, math.min(1.0, percent or 0))
    self:drawRect(x, y, w, h, 0.40, 0.10, 0.12, 0.15)
    self:drawRect(x, y, w, 1, 0.20, 1, 1, 1)

    local fill = math.floor(w * percent + 0.5)
    if fill > 0 then
        self:drawRect(x, y, fill, h, 0.90, color[1], color[2], color[3])
        self:drawRect(x, y, fill, 1, 0.35, 1, 1, 1)
    end

    if ticks then
        for _, t in ipairs(ticks) do
            local tx = x + math.floor(w * t)
            self:drawRect(tx, y - 1, 1, h + 2, 0.45, 1, 1, 1)
        end
    end
end

function LV_RoomInspectorDashboard:render()
    if not self:getIsVisible() or not LV_Config or not LV_Config.isEnabled() then return end

    local data = self:refreshData(false)
    local tm = getTextManager()
    local hgt = self.fontH

    -- 1. Fundo Soft Glass Escuro e Borda Translúcida
    self:drawRect(0, 0, self.width, self.height, 0.92, 0.03, 0.035, 0.045)
    self:drawRect(0, 0, 2, self.height, 0.95, ACCENT_CYAN[1], ACCENT_CYAN[2], ACCENT_CYAN[3])
    self:drawRectBorder(0, 0, self.width, self.height, 0.25, 1, 1, 1)

    -- Cabeçalho & Ações Rápidas
    self:drawText("INSPECAO DO AMBIENTE", PAD + 4, PAD, ACCENT_CYAN[1], ACCENT_CYAN[2], ACCENT_CYAN[3], 1.0, FONT_M)
    self:drawTextRight("[INFRA (J)]", self.width - PAD - 24, PAD + 2, 0.45, 0.85, 0.90, 0.90, FONT_S)
    self:drawTextRight("[X]", self.width - PAD, PAD + 2, 0.70, 0.70, 0.70, 1.0, FONT_S)

    local roomTitle = string.format("Comodo Atual: %s", data.roomName or "Ambiente Desconhecido")
    if data.isOutside then
        roomTitle = "Comodo Atual: Area Externa"
    end
    self:drawText(roomTitle, PAD + 4, PAD + 22, 0.85, 0.90, 0.95, 1.0, FONT_S)

    -- Linha Divisória 1
    local curY = PAD + 42
    self:drawRect(PAD, curY, self.width - (PAD * 2), 1, 0.20, 1, 1, 1)
    curY = curY + 8

    -- =========================================================================
    -- SEÇÃO 1: COMPARATIVO DE TIERS (CÔMODO VS SAFEHOUSE)
    -- =========================================================================
    local roomScore = data.roomScore or 0
    local roomTier = data.roomTier or 0
    local shScore = data.safehouseScore or roomScore
    local shTier = data.safehouseTier or roomTier

    local rStr = string.format("Tier do Comodo: T%d (%d pts)", roomTier, roomScore)
    self:drawText(rStr, PAD + 4, curY, ACCENT_GREEN[1], ACCENT_GREEN[2], ACCENT_GREEN[3], 1.0, FONT_S)
    self:drawGauge(170, curY + 3, 230, 6, roomScore / 100.0, ACCENT_GREEN, {0.2, 0.4, 0.6, 0.8})
    curY = curY + hgt + 4

    local shStr = string.format("Tier da Safehouse: T%d (%d pts)", shTier, shScore)
    self:drawText(shStr, PAD + 4, curY, 0.75, 0.80, 0.90, 1.0, FONT_S)
    self:drawGauge(170, curY + 3, 230, 6, shScore / 100.0, ACCENT_CYAN, {0.2, 0.4, 0.6, 0.8})
    curY = curY + hgt + 8

    -- Linha Divisória 2
    self:drawRect(PAD, curY, self.width - (PAD * 2), 1, 0.15, 1, 1, 1)
    curY = curY + 6

    -- =========================================================================
    -- SEÇÃO 2: SUB-PONTUAÇÃO POR CATEGORIA DE AMBIENTE
    -- =========================================================================
    local cStats = data.categoryStats or {}
    local furnPts = math.floor((data.furniturePoints or 0) + (cStats.HEAVY_FURNITURE or 0))
    local elecPts = math.floor((data.lightingPoints or 0) + (cStats.APPLIANCES_ELECTRONICS or 0))
    local decorPts = math.floor(cStats.SURFACE_DECOR or 0)
    local items3DPts = math.floor((data.decorPoints or 0) + (cStats.ORGANIC_COMFORT_3D or 0) + (cStats.PANTRY_SUPPLIES_3D or 0))

    self:drawText(string.format("- Mobilias: %d pts", furnPts), PAD + 4, curY, 0.80, 0.85, 0.90, 1.0, FONT_S)
    self:drawText(string.format("- Eletronicos: %d pts", elecPts), 215, curY, 0.80, 0.85, 0.90, 1.0, FONT_S)
    curY = curY + hgt + 2

    self:drawText(string.format("- Decoracao: %d pts", decorPts), PAD + 4, curY, 0.80, 0.85, 0.90, 1.0, FONT_S)
    self:drawText(string.format("- Objetos 3D: %d pts", items3DPts), 215, curY, 0.80, 0.85, 0.90, 1.0, FONT_S)
    curY = curY + hgt + 6

    -- Linha Divisória 3
    self:drawRect(PAD, curY, self.width - (PAD * 2), 1, 0.15, 1, 1, 1)
    curY = curY + 6

    -- =========================================================================
    -- SEÇÃO 3: INVENTÁRIO DO CÔMODO & PONTUAÇÃO INDIVIDUAL
    -- =========================================================================
    self:drawText("ITENS PONTUADOS NESTE COMODO:", PAD + 4, curY, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3], 1.0, FONT_S)
    curY = curY + hgt + 2

    local itemsList = data.itemsList or {}
    if data.isOutside then
        self:drawText("- Area Externa: Sem comodo interno fechado ao redor.", PAD + 12, curY, 0.60, 0.60, 0.65, 1.0, FONT_S)
        curY = curY + hgt + 4
    elseif data.isUnclaimed then
        self:drawText("- Imovel Nao Reivindicado: Aconchego e buffs inativos.", PAD + 12, curY, 0.85, 0.60, 0.40, 1.0, FONT_S)
        curY = curY + hgt + 4
    elseif #itemsList == 0 then
        self:drawText("Nenhum movel ou objeto 3D detectado ao redor.", PAD + 12, curY, 0.60, 0.60, 0.65, 1.0, FONT_S)
        curY = curY + hgt + 4
    else
        local startIdx = math.max(1, 1 + math.floor(self.scrollOffset))
        local endIdx = math.min(#itemsList, startIdx + 4)

        for idx = startIdx, endIdx do
            local it = itemsList[idx]
            if it then
                local itemName = tostring(it.name or "Item")
                local itemScore = it.score or 0
                local sign = (itemScore >= 0) and "+" or ""
                local scoreStr = string.format("%s%.1f pts", sign, itemScore)

                local col = (itemScore >= 0) and {0.75, 0.90, 0.80} or ACCENT_RED
                self:drawText(string.format(" - %s", itemName), PAD + 6, curY, 0.85, 0.85, 0.85, 1.0, FONT_S)
                self:drawTextRight(scoreStr, self.width - PAD - 6, curY, col[1], col[2], col[3], 1.0, FONT_S)
                curY = curY + hgt + 1
            end
        end
    end

    -- Linha Divisória 4
    curY = curY + 4
    self:drawRect(PAD, curY, self.width - (PAD * 2), 1, 0.15, 1, 1, 1)
    curY = curY + 6

    -- =========================================================================
    -- SEÇÃO 4: DIAGNÓSTICO DO LAR (ELI5 - O QUE FALTA PARA SUBIR DE TIER)
    -- =========================================================================
    local nextTier = math.min(4, roomTier + 1)
    local nextThreshold = 20
    if nextTier == 2 then nextThreshold = 40
    elseif nextTier == 3 then nextThreshold = 60
    elseif nextTier == 4 then nextThreshold = 80
    end

    local ptsNeeded = math.max(0, nextThreshold - roomScore)
    local advice = ""
    if data.isOutside then
        advice = "Voce esta ao ar livre. Entre em sua base para desfrutar de conforto."
    elseif data.isUnclaimed then
        advice = "Imovel nao reivindicado. Clique com botao direito no interior para estabelecer seu Lar."
    elseif roomTier == 4 then
        advice = "Santuario Perfeito: O ambiente atingiu a pontuacao maxima de conforto!"
    elseif ptsNeeded > 0 then
        if furnPts < 15 then
            advice = string.format("Dica: Faltam %d pts para o Tier %d. Adicione uma cama acolchoada ou poltrona.", ptsNeeded, nextTier)
        elseif elecPts < 6 then
            advice = string.format("Dica: Faltam %d pts para o Tier %d. Acenda luminarias ou ligue uma TV/Radio.", ptsNeeded, nextTier)
        else
            advice = string.format("Dica: Faltam %d pts para o Tier %d. Decore as paredes com quadros e tapetes.", ptsNeeded, nextTier)
        end
    end

    local maxW = self.width - (PAD * 2) - 8
    curY = self:drawWrappedText(advice, PAD + 4, curY, maxW, 0.90, 0.85, 0.50, 1.0, FONT_S)

    -- Auto-ajuste dinâmico de altura para eliminar espaços pretos vazios no rodapé
    local targetH = math.max(260, curY + PAD)
    if math.abs(self.height - targetH) > 2 then
        self:setHeight(targetH)
    end
end

-- =============================================================================
-- Ganchos de Inicialização e Teclado (Tecla 'K')
-- =============================================================================

Events.OnGameStart.Add(function()
    LV_RoomInspectorDashboard.getInstance()
    print("[LarVivo] LV_RoomInspectorDashboard inicializado com sucesso!")
end)

Events.OnKeyPressed.Add(function(key)
    -- Tecla 'K' (Keyboard.KEY_K = 37 no PZ)
    if key == Keyboard.KEY_K then
        LV_RoomInspectorDashboard.toggle()
    end
end)
