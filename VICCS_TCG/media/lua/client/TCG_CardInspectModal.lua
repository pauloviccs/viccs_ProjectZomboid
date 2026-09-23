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

function TCG_CardInspectModal:new(cardDef, isHolo, binderItem, cardCount, binderUI)
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
    o.binderItem = binderItem
    o.cardCount = cardCount or 0
    o.binderUI = binderUI
    o.moveWithMouse = false
    o.isDragging = false
    o.downX, o.downY = -1, -1
    o.mouseX, o.mouseY = -1, -1
    o.animTime = 0

    return o
end

--- Abre o modal com os dados de um InventoryItem ou CardDef
function TCG_CardInspectModal.show(target, extraHolo, binderItem, cardCount, binderUI)
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

    instance = TCG_CardInspectModal:new(cardDef, isHolo, binderItem, cardCount, binderUI)
    instance:initialise()
    instance:instantiate()
    instance:addToUIManager()
    instance:setVisible(true)

    -- Audio customizado de inspecao tatil
    TCG_Theme.playInspectCard(isHolo)

    return instance
end

function TCG_CardInspectModal:closeModal()
    TCG_Theme.playBookClose()
    self:setVisible(false)
    self:removeFromUIManager()
    instance = nil
end

function TCG_CardInspectModal:onMouseDown(x, y)
    self.downX = x
    self.downY = y

    -- 1. Botao de Grip [M] (x: width - 64, y: 8, w: 26, h: 22)
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

        -- Clique na Carta: Alterna entre Modo Normal e Modo Expandido (Full 3D Showcase)
        local cX = self.isExpanded and math.floor((self.width - 300) / 2) or 32
        local cY = self.isExpanded and 46 or 56
        local cW = self.isExpanded and 300 or 240
        local cH = self.isExpanded and 420 or 336
        if x >= cX and x <= (cX + cW) and y >= cY and y <= (cY + cH) then
            self.isExpanded = not self.isExpanded
            TCG_Theme.playPageTurn()
            -- Reseta inercia de angulo para evitar saltos visuais na troca de modo
            self._tcgCurrentPX = 0.0
            self._tcgCurrentPY = 0.0
            self._tcgCurrentHover = 0.0
            return true
        end

        local infoX = 295
        local btnY = 430

        -- Se estiver no modo expandido
        if self.isExpanded then
            local btnBackW = 280
            local btnBackX = math.floor((self.width - btnBackW) / 2)
            local btnBackY = 442
            local isBackHover = (x >= btnBackX and x <= (btnBackX + btnBackW) and y >= btnBackY and y <= (btnBackY + 28))
            if isBackHover then
                self.isExpanded = false
                TCG_Theme.playPageTurn()
                self._tcgCurrentPX = 0.0
                self._tcgCurrentPY = 0.0
                self._tcgCurrentHover = 0.0
                return true
            end
        else
            -- Se a carta esta sendo inspecionada de dentro do fichario
            if self.binderItem and self.cardCount and self.cardCount >= 1 then
                -- Botao [SACAR CARTA] (x: infoX, y: btnY, w: 138, h: 30)
                if x >= infoX and x <= (infoX + 138) and y >= btnY and y <= (btnY + 30) then
                    if self.binderUI and self.binderUI.withdrawCard then
                        local cid = self.cardDef and self.cardDef.id
                        if cid then
                            local removed = self.binderUI:withdrawCard(cid, 1)
                            if removed > 0 then
                                self.cardCount = self.cardCount - 1
                                if self.cardCount <= 0 then
                                    self:closeModal()
                                end
                            end
                        end
                    end
                    return true
                end

                -- Botao [FECHAR] (x: infoX + 148, y: btnY, w: 142, h: 30)
                if x >= (infoX + 148) and x <= (infoX + 290) and y >= btnY and y <= (btnY + 30) then
                    self:closeModal()
                    return true
                end
            else
                -- Botao [FECHAR INSPECAO] (x: infoX, y: btnY, w: 290, h: 30)
                if x >= infoX and x <= (infoX + 290) and y >= btnY and y <= (btnY + 30) then
                    self:closeModal()
                    return true
                end
            end
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
    local mx = self:getMouseX()
    local my = self:getMouseY()

    -- 1. Cabecalho (com protecao contra colisao nos botoes da direita)
    local cardName = TCG_CardRegistry.getCardName(card)
    local num = card and card.number or 0
    local title = string.format("[TCG] %s: #%02d %s", isPT and "INSPECAO DE CARTA" or "CARD INSPECTOR", num, cardName)
    local titleW = getTextManager():MeasureStringX(UIFont.Medium, title)
    local titleFont = UIFont.Medium
    if titleW > (self.width - 80) then
        title = string.format("[TCG] #%02d %s", num, cardName)
        titleFont = UIFont.Small
    end
    self:drawText(title, 16, 11, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3], 1.0, titleFont)

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

    if self.isExpanded then
        -- 2. Modo Expandido (Full Showcase 3D Centralizado em Alta Definicao)
        local cardW = 300
        local cardH = 420
        local cardX = math.floor((self.width - cardW) / 2)
        local cardY = 46

        TCG_Theme.drawCardWith3DHover(self, tex, cardX, cardY, cardW, cardH, mx, my, isHolo, self.animTime)

        -- Botao central para retornar a ficha tecnica
        local btnBackW = 280
        local btnBackX = math.floor((self.width - btnBackW) / 2)
        local btnBackY = 442
        local isBackHover = (mx >= btnBackX and mx <= (btnBackX + btnBackW) and my >= btnBackY and my <= (btnBackY + 28))
        local backLabel = isPT and "[ VOLTAR PARA FICHA TECNICA ]" or "[ RETURN TO DETAILS ]"
        TCG_Theme.drawTacticalButton(self, backLabel, btnBackX, btnBackY, btnBackW, 28, isBackHover, TCG_Theme.CYAN)
    else
        -- 2. Area da Carta com Fisica 3D Hover (Lado Esquerdo)
        local cardW = 240
        local cardH = 336
        local cardX = 32
        local cardY = 56

        TCG_Theme.drawCardWith3DHover(self, tex, cardX, cardY, cardW, cardH, mx, my, isHolo, self.animTime)

        -- Dica tatil de 3D sob a carta em 2 linhas contidas e centralizadas (previne vazamento lateral)
        local hintTilt = isPT and "* Mova o mouse para inclinar 3D *"
                               or "* Move mouse to tilt in 3D *"
        local hintExpand = isPT and "[ Clique na carta para expandir ]"
                                 or "[ Click card to expand ]"
        self:drawTextCentre(hintTilt, cardX + (cardW / 2), cardY + cardH + 10, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 0.75, UIFont.Small)
        self:drawTextCentre(hintExpand, cardX + (cardW / 2), cardY + cardH + 26, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3], 0.75, UIFont.Small)

        -- 3. Painel de Ficha Tecnica (Lado Direito)
        local details = TCG_CardRegistry.getCardDetails(card, isPT)
        local infoX = 295
        local infoY = 54

        -- Badge de Categoria / Supertipo
        local catText = string.format("[ %s ]", string.upper(details.category))
        self:drawText(catText, infoX, infoY, TCG_Theme.AMBER[1], TCG_Theme.AMBER[2], TCG_Theme.AMBER[3], 1.0, UIFont.Small)

        -- Nome da Carta em Fonte Grande (com protecao contra overflow horizontal)
        infoY = infoY + 22
        local cardFont = UIFont.Large
        local nameW = getTextManager():MeasureStringX(cardFont, cardName)
        if nameW > 280 then
            cardFont = UIFont.Medium
        end
        self:drawText(cardName, infoX, infoY, TCG_Theme.TEXT_WHITE[1], TCG_Theme.TEXT_WHITE[2], TCG_Theme.TEXT_WHITE[3], 1.0, cardFont)

        -- Colecao e Numero com Alinhamento Protegido do Contador
        infoY = infoY + 30
        local setId = (card and card.setId) or "base1"
        local setDef = TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[setId]
        local setName = setDef and (isPT and setDef.name.pt or setDef.name.en) or (isPT and "Colecao Base (1999)" or "Base Set (1999)")
        local totalInSet = setDef and setDef.total or 102
        local setStr = string.format("%s - #%02d / %d", setName, num, totalInSet)
        self:drawText(setStr, infoX, infoY, 0.70, 0.75, 0.80, 1.0, UIFont.Small)

        if self.binderItem and self.cardCount and self.cardCount > 0 then
            local inBinderStr = isPT and string.format("[ Fichario: x%d ]", self.cardCount)
                                     or string.format("[ Binder: x%d ]", self.cardCount)
            local badgeW = getTextManager():MeasureStringX(UIFont.Small, inBinderStr)
            self:drawText(inBinderStr, (infoX + 290) - badgeW, infoY, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3], 0.90, UIFont.Small)
        end

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

        -- Botoes de Acao (Saque e Fechar)
        local btnY = 430
        if self.binderItem and self.cardCount and self.cardCount >= 1 then
            local isSacarHover = (mx >= infoX and mx <= (infoX + 138) and my >= btnY and my <= (btnY + 30))
            local sacarLabel = isPT and "SACAR CARTA" or "WITHDRAW"
            TCG_Theme.drawTacticalButton(self, sacarLabel, infoX, btnY, 138, 30, isSacarHover, TCG_Theme.GREEN)

            local isCloseHover = (mx >= (infoX + 148) and mx <= (infoX + 290) and my >= btnY and my <= (btnY + 30))
            local closeLabel = isPT and "FECHAR" or "CLOSE"
            TCG_Theme.drawTacticalButton(self, closeLabel, infoX + 148, btnY, 142, 30, isCloseHover, TCG_Theme.CYAN)
        else
            local isBtnHover = (mx >= infoX and mx <= (infoX + 290) and my >= btnY and my <= (btnY + 30))
            TCG_Theme.drawTacticalButton(self, isPT and "FECHAR INSPECAO" or "CLOSE INSPECTOR", infoX, btnY, 290, 30, isBtnHover, TCG_Theme.CYAN)
        end
    end
end
