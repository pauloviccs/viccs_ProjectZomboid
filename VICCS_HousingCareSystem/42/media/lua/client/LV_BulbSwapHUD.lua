-- =============================================================================
-- Housing Care System (Lar Vivo) - Mini-HUD de Substituicao de Lampadas (LV_BulbSwapHUD.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Mini-HUD flutuante e minimalista (Frameless Soft Glass) exibido ao interagir
--   com uma luminaria residencial para troca de lampada:
--   - Slot 1 (Esquerda): Lampada atual no bocal (Queimada ou Em Uso)
--   - Slot 2 (Direita): Lampada nova selecionada do inventario do sobrevivente
--   - Checagem visual de requisitos: Chave de Fenda e Lampada Reserva
--   - Botao central [EFETUAR TROCA] que enfileira a Timed Action de substituicao
-- =============================================================================

require "ISUI/ISPanel"
require "LV_Config"
require "LV_LightingSystem"

LV_BulbSwapHUD = ISPanel:derive("LV_BulbSwapHUD")

local instance = nil

local FONT_S = UIFont.Small
local FONT_M = UIFont.Medium
local PAD = 10
local ACCENT_AMBER = {0.92, 0.71, 0.29}
local ACCENT_GREEN = {0.30, 0.85, 0.50}
local ACCENT_RED   = {0.95, 0.25, 0.25}

function LV_BulbSwapHUD:new(x, y, width, height)
    local w = width or 320
    local h = height or 180
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.moveWithMouse = true
    o.userHidden = true
    o.downX, o.downY = -1, -1
    o.isDragging = false

    o.character = nil
    o.targetLight = nil
    o.selectedBulb = nil
    o.hasScrewdriver = false
    o.hasBulb = false

    return o
end

function LV_BulbSwapHUD.getInstance()
    if not instance then
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        local w = 320
        local h = 180
        local x = math.floor((screenW - w) / 2)
        local y = math.floor((screenH - h) / 2) - 60

        instance = LV_BulbSwapHUD:new(x, y, w, h)
        instance:initialise()
        instance:instantiate()
        instance:addToUIManager()
        instance:setVisible(false)
    end
    return instance
end

function LV_BulbSwapHUD.openFor(character, lightObj)
    if not character or not lightObj then return end
    local hud = LV_BulbSwapHUD.getInstance()
    hud.character = character
    hud.targetLight = lightObj

    -- Varre ferramentas no inventario
    local inv = character:getInventory()
    hud.hasScrewdriver = false
    hud.hasBulb = false
    hud.selectedBulb = nil

    if inv then
        local sd = inv:getFirstTypeRecurse("Base.Screwdriver") or inv:getFirstTypeRecurse("Screwdriver")
        if sd then hud.hasScrewdriver = true end

        local items = inv:getItems()
        if items then
            for i = 0, items:size() - 1 do
                local it = items:get(i)
                if LV_LightingSystem.isLightBulbItem(it) then
                    hud.hasBulb = true
                    hud.selectedBulb = it
                    break
                end
            end
        end
    end

    hud:setVisible(true)
    hud:bringToTop()
end

function LV_BulbSwapHUD.close()
    if instance then
        instance:setVisible(false)
        instance.targetLight = nil
    end
end

function LV_BulbSwapHUD:onMouseDown(x, y)
    if not self:getIsVisible() then return false end

    -- Botao Fechar [X]
    if x >= (self.width - 24) and x <= self.width and y <= 24 then
        LV_BulbSwapHUD.close()
        return true
    end

    -- Botao [EFETUAR TROCA]
    local btnX = PAD + 20
    local btnY = self.height - 34
    local btnW = self.width - (PAD * 2) - 40
    local btnH = 24

    if x >= btnX and x <= (btnX + btnW) and y >= btnY and y <= (btnY + btnH) then
        if self.hasScrewdriver and self.hasBulb and self.character and self.targetLight then
            local pObj = self.character
            local lObj = self.targetLight
            LV_BulbSwapHUD.close()

            if luautils and luautils.walkAdjObject then
                luautils.walkAdjObject(pObj, lObj, true, true)
            elseif luautils and luautils.walkAdj then
                luautils.walkAdj(pObj, lObj:getSquare(), true)
            end
            ISTimedActionQueue.add(ISReplaceLightBulbAction:new(pObj, lObj, 80))
            return true
        end
    end

    if y <= 26 then
        self.downX = x
        self.downY = y
        self.isDragging = true
        return true
    end

    return true
end

function LV_BulbSwapHUD:onMouseMove(dx, dy)
    if self.isDragging then
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        local newX = math.max(0, math.min(screenW - self.width, self:getX() + dx))
        local newY = math.max(0, math.min(screenH - self.height, self:getY() + dy))
        self:setX(newX)
        self:setY(newY)
    end
end

function LV_BulbSwapHUD:onMouseUp(x, y)
    self.isDragging = false
    return true
end

function LV_BulbSwapHUD:render()
    if not self:getIsVisible() then return end

    -- 1. Fundo Frameless Dark Glass
    self:drawRect(0, 0, self.width, self.height, 0.94, 0.03, 0.04, 0.05)
    self:drawRect(0, 0, 2, self.height, 0.95, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3])
    self:drawRectBorder(0, 0, self.width, self.height, 0.30, 1, 1, 1)

    -- Cabecalho Principal
    self:drawText("SUBSTITUICAO DE LAMPADA", PAD + 4, PAD, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3], 1.0, FONT_M)
    self:drawTextRight("[X]", self.width - PAD, PAD + 2, 0.70, 0.70, 0.70, 1.0, FONT_S)

    local cy = PAD + 24
    self:drawRect(PAD, cy, self.width - (PAD * 2), 1, 0.25, 1, 1, 1)
    cy = cy + 6

    -- Status do Bocal e Inspecao
    local isBurnt = false
    if self.targetLight and LV_LightingSystem and LV_LightingSystem.isBulbBurnt then
        isBurnt = LV_LightingSystem.isBulbBurnt(self.targetLight)
    end

    -- Slot 1: Bocal Atual
    local boxW = 100
    local boxH = 50
    local box1X = PAD + 14
    local boxY = cy + 4

    self:drawRect(box1X, boxY, boxW, boxH, 0.40, 0.08, 0.09, 0.10)
    self:drawRectBorder(box1X, boxY, boxW, boxH, 0.50, isBurnt and ACCENT_RED[1] or 0.5, isBurnt and ACCENT_RED[2] or 0.6, isBurnt and ACCENT_RED[3] or 0.7)
    self:drawText("Bocal Atual", box1X + 16, boxY + 4, 0.70, 0.75, 0.80, 0.90, FONT_S)
    if isBurnt then
        self:drawText("[QUEIMADA]", box1X + 10, boxY + 22, ACCENT_RED[1], ACCENT_RED[2], ACCENT_RED[3], 1.0, FONT_S)
    else
        self:drawText("[OPERANTE]", box1X + 12, boxY + 22, ACCENT_GREEN[1], ACCENT_GREEN[2], ACCENT_GREEN[3], 1.0, FONT_S)
    end

    -- Seta central
    local arrowX = box1X + boxW + 18
    self:drawText("-->", arrowX, boxY + 16, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3], 1.0, FONT_M)

    -- Slot 2: Lampada Nova
    local box2X = self.width - PAD - boxW - 14
    self:drawRect(box2X, boxY, boxW, boxH, 0.40, 0.08, 0.09, 0.10)
    local b2Col = self.hasBulb and ACCENT_GREEN or ACCENT_RED
    self:drawRectBorder(box2X, boxY, boxW, boxH, 0.50, b2Col[1], b2Col[2], b2Col[3])
    self:drawText("Lampada Nova", box2X + 12, boxY + 4, 0.70, 0.75, 0.80, 0.90, FONT_S)
    if self.hasBulb and self.selectedBulb then
        local bName = (self.selectedBulb.getName and self.selectedBulb:getName()) or "LightBulb"
        if #bName > 13 then bName = bName:sub(1, 11) .. ".." end
        self:drawText(bName, box2X + 8, boxY + 22, ACCENT_GREEN[1], ACCENT_GREEN[2], ACCENT_GREEN[3], 1.0, FONT_S)
    else
        self:drawText("[SEM BULBO]", box2X + 10, boxY + 22, ACCENT_RED[1], ACCENT_RED[2], ACCENT_RED[3], 1.0, FONT_S)
    end

    -- Requisitos de Ferramentas
    local reqY = boxY + boxH + 8
    local sdText = self.hasScrewdriver and "Chave de Fenda: OK" or "Falta: Chave de Fenda!"
    local sdCol = self.hasScrewdriver and ACCENT_GREEN or ACCENT_RED
    self:drawText(sdText, PAD + 16, reqY, sdCol[1], sdCol[2], sdCol[3], 0.95, FONT_S)

    local bText = self.hasBulb and "Lampada Reserva: OK" or "Falta: Lampada Reserva!"
    local bCol = self.hasBulb and ACCENT_GREEN or ACCENT_RED
    self:drawTextRight(bText, self.width - PAD - 16, reqY, bCol[1], bCol[2], bCol[3], 0.95, FONT_S)

    -- Botao de Acao Primaria [EFETUAR TROCA]
    local btnX = PAD + 20
    local btnY = self.height - 34
    local btnW = self.width - (PAD * 2) - 40
    local btnH = 24
    local canSwap = self.hasScrewdriver and self.hasBulb

    if canSwap then
        self:drawRect(btnX, btnY, btnW, btnH, 0.70, ACCENT_AMBER[1] * 0.40, ACCENT_AMBER[2] * 0.40, ACCENT_AMBER[3] * 0.40)
        self:drawRectBorder(btnX, btnY, btnW, btnH, 0.90, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3])
        self:drawTextCentre("EFETUAR TROCA DE LAMPADA", btnX + (btnW / 2), btnY + 4, 1.0, 1.0, 1.0, 1.0, FONT_S)
    else
        self:drawRect(btnX, btnY, btnW, btnH, 0.30, 0.15, 0.15, 0.15)
        self:drawRectBorder(btnX, btnY, btnW, btnH, 0.40, 0.40, 0.40, 0.40)
        self:drawTextCentre("FERRAMENTAS INSUFICIENTES", btnX + (btnW / 2), btnY + 4, 0.60, 0.60, 0.60, 0.80, FONT_S)
    end
end

Events.OnGameStart.Add(function()
    LV_BulbSwapHUD.getInstance()
end)

return LV_BulbSwapHUD
