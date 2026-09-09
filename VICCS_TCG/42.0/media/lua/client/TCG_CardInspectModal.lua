-- =============================================================================
-- Project Zomboid TCG - Card Inspect Modal (TCG_CardInspectModal.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Modal de visualizacao individual de carta colecionavel em alta definicao:
--   - Estetica Frameless Soft Glass (sem bordas solidas genericas)
--   - Efeito de inclinacao fisica 3D Hover com feixe de luz especular (glare)
--   - Efeito Foil/Holografico prismatico dinamico com particulas brilhantes
--   - Ficha tecnica de colecionador completa (Elemento, HP, Ataque, Fraqueza, Lore)
--   - Controle seguro de arrasto exclusivo por botao de Grip [ [M] ]
--   - Efeitos sonoros imersivos
-- =============================================================================

require "ISUI/ISPanel"
require "TCG_Theme"
require "TCG_Config"
require "TCG_CardRegistry"

TCG_CardInspectModal = ISPanel:derive("TCG_CardInspectModal")

local instance = nil

function TCG_CardInspectModal:new(cardDef, isHolo)
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local w = 620
    local h = 480
    local x = math.floor((screenW - w) / 2)
    local y = math.floor((screenH - h) / 2)

    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.cardDef = cardDef or TCG_CardRegistry.getCard("base1-001")
    o.isHolo = (isHolo == true) or (o.cardDef and o.cardDef.isHolo == true)
    o.moveWithMouse = false
    o.isDragging = false
    o.downX, o.downY = -1, -1
    o.mouseX, o.mouseY = -1, -1
    o.animTime = 0

    return o
end

--- Abre o modal com os dados de um InventoryItem ou CardDef
function TCG_CardInspectModal.show(target, extraHolo)
    if instance then
        instance:setVisible(false)
        instance:removeFromUIManager()
        instance = nil
    end

    local cardDef = nil
    local isHolo = false

    -- Se recebeu um InventoryItem do Project Zomboid
    if target and target.getModData then
        cardDef, isHolo = TCG_CardRegistry.getCardFromItem(target)
    else
        cardDef = target
        isHolo = (extraHolo == true) or (cardDef and cardDef.isHolo == true)
    end

    if not cardDef then
        cardDef = TCG_CardRegistry.getCard("base1-001")
    end

    instance = TCG_CardInspectModal:new(cardDef, isHolo)
    instance:initialise()
    instance:instantiate()
    instance:addToUIManager()
    instance:setVisible(true)

    -- Audio de inspecao
    if isHolo then
        TCG_Theme.playAudio("GainExperienceLevel", "UI_SelectCard")
    else
        TCG_Theme.playAudio("UI_SelectCard", "BookOpen")
    end

    return instance
end

function TCG_CardInspectModal:closeModal()
    TCG_Theme.playAudio("UI_ToggleOff", "BookClose")
    self:setVisible(false)
    self:removeFromUIManager()
    instance = nil
end

function TCG_CardInspectModal:onMouseDown(x, y)
    self.downX = x
    self.downY = y

    -- 1. Botao de Grip [[M]] (x: width - 64, y: 8, w: 26, h: 22)
    if x >= (self.width - 64) and x <= (self.width - 38) and y >= 8 and y <= 30 then
        self.isDragging = true
        return true
    end

    -- Qualquer outro clique NAO inicia arrasto
    self.isDragging = false
    return true
end

function TCG_CardInspectModal:onMouseUp(x, y)
    local wasDragging = self.isDragging
    self.isDragging = false

    if not wasDragging or (math.abs(x - self.downX) <= 6 and math.abs(y - self.downY) <= 6) then
        -- Botao [X] Fechar (x: width - 34, y: 8, w: 26, h: 22)
        if x >= (self.width - 34) and x <= (self.width - 8) and y >= 8 and y <= 30 then
            self:closeModal()
            return true
        end

        -- Botao [FECHAR INSPECAO] (x: 300, y: 430, w: 280, h: 30)
        if x >= 300 and x <= 580 and y >= 430 and y <= 460 then
            self:closeModal()
            return true
        end
    end

    return true
end

function TCG_CardInspectModal:onMouseMove(dx, dy)
    local mx = self:getMouseX()
    local my = self:getMouseY()
    self.mouseX = mx
    self.mouseY = my

    if self.isDragging then
        self:setX(self:getX() + dx)
        self:setY(self:getY() + dy)
    end
end

function TCG_CardInspectModal:update()
    ISPanel.update(self)
    self.animTime = (self.animTime or 0) + 0.05
end

function TCG_CardInspectModal:prerender()
    -- Fundo Soft Glass escuro com acento ciano lateral
    TCG_Theme.drawGlassBackdrop(self, 0, 0, self.width, self.height, true)

    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local card = self.cardDef
    local isHolo = self.isHolo
    local mx = self.mouseX or -1
    local my = self.mouseY or -1

    -- 1. Cabecalho
    local cardName = TCG_CardRegistry.getCardName(card)
    local num = card and card.number or 0
    local title = string.format("[TCG] %s: #%02d %s", isPT and "INSPECAO DE CARTA" or "CARD INSPECTOR", num, cardName)
    self:drawText(title, 16, 11, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3], 1.0, UIFont.Medium)

    -- Botoes do Topo: Grip [M] e Fechar [X]
    local isHoverGrip = (mx >= (self.width - 64) and mx <= (self.width - 38) and my >= 8 and my <= 30)
    TCG_Theme.drawDragGrip(self, self.width - 64, 8, 26, 22, isHoverGrip, self.isDragging)

    local isHoverClose = (mx >= (self.width - 34) and mx <= (self.width - 8) and my >= 8 and my <= 30)
    TCG_Theme.drawCloseButton(self, self.width - 34, 8, 26, 22, isHoverClose)

    -- Linha divisoria superior
    self:drawRect(12, 36, self.width - 24, 1, 0.20, 1, 1, 1)

    -- 2. Area da Carta com Fisica 3D Hover (Lado Esquerdo)
    local cardW = 240
    local cardH = 336
    local cardX = 32
    local cardY = 56

    local tex = nil
    if card and card.texture then
        tex = getTexture(card.texture)
    end
    if not tex then
        tex = getTexture("media/textures/tcg_card_back.png")
    end

    TCG_Theme.drawCardWith3DHover(self, tex, cardX, cardY, cardW, cardH, mx, my, isHolo, self.animTime)

    -- Dica tatil de 3D sob a carta
    local hintText = isPT and "* Mova o mouse sobre a carta para inclinar em 3D *"
                           or "* Move mouse over card to tilt in 3D *"
    self:drawTextCentre(hintText, cardX + (cardW / 2), cardY + cardH + 18, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 0.75, UIFont.Small)

    -- 3. Painel de Ficha Tecnica (Lado Direito)
    local details = TCG_CardRegistry.getCardDetails(card, isPT)
    local infoX = 295
    local infoY = 54

    -- Badge de Categoria / Supertipo
    local catText = string.format("[ %s ]", string.upper(details.category))
    self:drawText(catText, infoX, infoY, TCG_Theme.AMBER[1], TCG_Theme.AMBER[2], TCG_Theme.AMBER[3], 1.0, UIFont.Small)

    -- Nome da Carta em Fonte Grande
    infoY = infoY + 22
    self:drawText(cardName, infoX, infoY, TCG_Theme.TEXT_WHITE[1], TCG_Theme.TEXT_WHITE[2], TCG_Theme.TEXT_WHITE[3], 1.0, UIFont.Large)

    -- Colecao e Numero
    infoY = infoY + 32
    local setStr = string.format("%s - #%02d / 102", isPT and "Colecao Base (1999)" or "Base Set (1999)", num)
    self:drawText(setStr, infoX, infoY, 0.70, 0.75, 0.80, 1.0, UIFont.Small)

    -- Selo de Raridade
    infoY = infoY + 22
    local rarityName = TCG_CardRegistry.getCardRarity(card)
    if isHolo then
        rarityName = isPT and "* RARA HOLOGRAFICA FOIL *" or "* RARE HOLOGRAPHIC FOIL *"
    end
    local rarCol = TCG_Theme.getRarityColor(card and card.rarity, isHolo)
    self:drawRect(infoX, infoY, 290, 24, 0.15, rarCol[1], rarCol[2], rarCol[3])
    self:drawRectBorder(infoX, infoY, 290, 24, 0.50, rarCol[1], rarCol[2], rarCol[3])
    self:drawTextCentre(rarityName, infoX + 145, infoY + 4, rarCol[1], rarCol[2], rarCol[3], 1.0, UIFont.Small)

    -- Caixa de Ficha Tecnica de Batalha
    infoY = infoY + 34
    self:drawRect(infoX, infoY, 290, 120, 0.35, 0.02, 0.03, 0.04)
    self:drawRectBorder(infoX, infoY, 290, 120, 0.20, 1, 1, 1)

    local lineY = infoY + 10
    local labelX = infoX + 12
    local valX = infoX + 140

    -- Tipo Elemental
    self:drawText(isPT and "Elemento / Tipo:" or "Element / Type:", labelX, lineY, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 1.0, UIFont.Small)
    self:drawText(details.element, valX, lineY, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3], 1.0, UIFont.Small)

    -- Pontos de Vida (HP)
    lineY = lineY + 22
    self:drawText(isPT and "Pontos de Saude:" or "Hit Points (HP):", labelX, lineY, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 1.0, UIFont.Small)
    self:drawText(details.hp, valX, lineY, TCG_Theme.GREEN[1], TCG_Theme.GREEN[2], TCG_Theme.GREEN[3], 1.0, UIFont.Small)

    -- Ataque Principal / Habilidade
    lineY = lineY + 22
    self:drawText(isPT and "Golpe Principal:" or "Primary Attack:", labelX, lineY, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 1.0, UIFont.Small)
    self:drawText(details.mainAttack, valX, lineY, TCG_Theme.AMBER[1], TCG_Theme.AMBER[2], TCG_Theme.AMBER[3], 1.0, UIFont.Small)

    -- Tabela de Combate (Fraqueza & Recuo)
    lineY = lineY + 22
    self:drawText(isPT and "Fraqueza / Recuo:" or "Weakness / Retreat:", labelX, lineY, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 1.0, UIFont.Small)
    local combatStr = string.format("%s | %s", details.weakness, details.retreat)
    self:drawText(combatStr, valX, lineY, 0.85, 0.85, 0.85, 1.0, UIFont.Small)

    -- Descricao de Lore / Pokedex com Quebra de Linha
    infoY = infoY + 130
    self:drawRect(infoX, infoY, 290, 70, 0.25, 0.03, 0.04, 0.05)
    self:drawRectBorder(infoX, infoY, 290, 70, 0.15, 0.5, 0.6, 0.7)
    self:drawText(isPT and "Historico da Pokedex:" or "Pokedex Archive:", infoX + 10, infoY + 6, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 0.85, UIFont.Small)
    TCG_Theme.drawTextWrapped(self, details.flavor, infoX + 10, infoY + 24, 270, 0.80, 0.85, 0.90, 0.90, UIFont.Small)

    -- Botao de Fechar [FECHAR INSPECAO]
    local btnY = 430
    local isBtnHover = (mx >= infoX and mx <= (infoX + 290) and my >= btnY and my <= (btnY + 30))
    TCG_Theme.drawTacticalButton(self, isPT and "FECHAR INSPECAO" or "CLOSE INSPECTOR", infoX, btnY, 290, 30, isBtnHover, TCG_Theme.CYAN)
end
