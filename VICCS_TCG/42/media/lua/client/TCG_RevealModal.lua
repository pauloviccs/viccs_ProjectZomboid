-- =============================================================================
-- Project Zomboid TCG - Unboxing Reveal Modal (TCG_RevealModal.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Painel de revelacao de pacotes de cartas no padrao Frameless Soft Glass:
--   - Suporte bilingue dinamico (PT-BR / EN)
--   - Revela as 10 cartas do booster sequencialmente com efeito Loot Box & suspense
--   - Fisica 3D Hover Tilt e efeito prismatico/holografico
--   - Ficha tecnica rica preenchendo todo o painel direito (sem espacos vazios)
--   - Sistema de audio imersivo (rasgar pacote, virar cartas, fanfarra holo)
--   - Controle seguro de arrasto exclusivo por botao de Grip [ [M] ]
-- =============================================================================

require "ISUI/ISPanel"
require "TCG_Theme"
require "TCG_Config"
require "TCG_CardRegistry"
require "TCG_CardInspectModal"

TCG_RevealModal = ISPanel:derive("TCG_RevealModal")

local instance = nil

function TCG_RevealModal:new(cards)
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local w = 620
    local h = 500
    local x = math.floor((screenW - w) / 2)
    local y = math.floor((screenH - h) / 2)

    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.cards = cards or {}
    o.currentIndex = 1
    o.moveWithMouse = false
    o.isDragging = false
    o.downX, o.downY = -1, -1
    o.mouseX, o.mouseY = -1, -1
    o.animTime = 0

    return o
end

function TCG_RevealModal.show(cards)
    if instance then
        instance:setVisible(false)
        instance:removeFromUIManager()
        instance = nil
    end

    instance = TCG_RevealModal:new(cards)
    instance:initialise()
    instance:instantiate()
    instance:addToUIManager()
    instance:setVisible(true)

    -- Audio de abertura do pacote (rasgo metalico)
    TCG_Theme.playAudio("BandageTear", "BookOpen")

    -- Se a primeira carta ja for holo (raro), toca fanfarra
    if cards and cards[1] and cards[1].isHolo then
        TCG_Theme.playAudio("GainExperienceLevel")
    end

    return instance
end

function TCG_RevealModal:closeModal()
    TCG_Theme.playAudio("UI_ToggleOff", "BookClose")
    self:setVisible(false)
    self:removeFromUIManager()
    instance = nil
end

function TCG_RevealModal:onMouseDown(x, y)
    self.downX = x
    self.downY = y

    -- 1. Botao de Grip [[M]] (x: width - 64, y: 8, w: 26, h: 22)
    if x >= (self.width - 64) and x <= (self.width - 38) and y >= 8 and y <= 30 then
        self.isDragging = true
        return true
    end

    self.isDragging = false
    return true
end

function TCG_RevealModal:onMouseUp(x, y)
    local wasDragging = self.isDragging
    self.isDragging = false

    if not wasDragging or (math.abs(x - self.downX) <= 6 and math.abs(y - self.downY) <= 6) then
        -- Botao [X] fechar (x: width - 34, y: 8, w: 26, h: 22)
        if x >= (self.width - 34) and x <= (self.width - 8) and y >= 8 and y <= 30 then
            self:closeModal()
            return true
        end

        -- Clique na Carta Principal (Abre o Modal de Inspecao Completo)
        local cardX = 35
        local cardY = 56
        local cardW = 220
        local cardH = 308
        if x >= cardX and x <= (cardX + cardW) and y >= cardY and y <= (cardY + cardH) then
            local curData = self.cards[self.currentIndex]
            if curData and curData.card then
                TCG_CardInspectModal.show(curData.card, curData.isHolo)
                return true
            end
        end

        -- Clique nas miniaturas da barra inferior (Slot 1 a 10)
        local thumbY = 388
        for i = 1, #self.cards do
            local tx = 35 + ((i - 1) * 56)
            if x >= tx and x <= (tx + 50) and y >= thumbY and y <= (thumbY + 54) then
                if i <= self.currentIndex or true then
                    self.currentIndex = i
                    local cur = self.cards[i]
                    if cur and cur.isHolo then
                        TCG_Theme.playAudio("GainExperienceLevel")
                    else
                        TCG_Theme.playAudio("PageTurn", "UI_SelectCard")
                    end
                    return true
                end
            end
        end

        -- Botao [REVELAR PROXIMA] (x: 35, y: 454, w: 260, h: 32)
        if x >= 35 and x <= 295 and y >= 454 and y <= 486 then
            self:revealNext()
            return true
        end

        -- Botao [GUARDAR TODAS] (x: 315, y: 454, w: 270, h: 32)
        if x >= 315 and x <= 585 and y >= 454 and y <= 486 then
            self:closeModal()
            return true
        end
    end

    return true
end

function TCG_RevealModal:onMouseMove(dx, dy)
    local mx = self:getMouseX()
    local my = self:getMouseY()
    self.mouseX = mx
    self.mouseY = my

    if self.isDragging then
        self:setX(self:getX() + dx)
        self:setY(self:getY() + dy)
    end
end

function TCG_RevealModal:revealNext()
    if self.currentIndex < #self.cards then
        self.currentIndex = self.currentIndex + 1
        local nextData = self.cards[self.currentIndex]
        if nextData and nextData.isHolo then
            TCG_Theme.playAudio("GainExperienceLevel")
        else
            TCG_Theme.playAudio("PageTurn", "UI_SelectCard")
        end
    else
        self:closeModal()
    end
end

function TCG_RevealModal:update()
    ISPanel.update(self)
    self.animTime = (self.animTime or 0) + 0.05
end

function TCG_RevealModal:render()
    if not self:getIsVisible() then return end

    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local mx = self.mouseX or -1
    local my = self.mouseY or -1

    -- 1. Fundo Soft Glass
    TCG_Theme.drawGlassBackdrop(self, 0, 0, self.width, self.height, true)

    -- Cabecalho
    local headerTitle = isPT and "ABERTURA DE BOOSTER: BASE SET 1999" or "BOOSTER PACK OPENING: BASE SET 1999"
    self:drawText(headerTitle, 16, 11, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3], 1.0, UIFont.Medium)

    -- Botoes do Topo: Grip [[M]] e Fechar [X]
    local isHoverGrip = (mx >= (self.width - 64) and mx <= (self.width - 38) and my >= 8 and my <= 30)
    TCG_Theme.drawDragGrip(self, self.width - 64, 8, 26, 22, isHoverGrip, self.isDragging)

    local isHoverClose = (mx >= (self.width - 34) and mx <= (self.width - 8) and my >= 8 and my <= 30)
    TCG_Theme.drawCloseButton(self, self.width - 34, 8, 26, 22, isHoverClose)

    -- Linha divisoria superior
    self:drawRect(12, 36, self.width - 24, 1, 0.20, 1, 1, 1)

    local currentCardData = self.cards[self.currentIndex]
    if not currentCardData then return end

    local card = currentCardData.card or {}
    local isHolo = currentCardData.isHolo

    -- 2. Area Central da Carta com Inclinacao 3D Hover
    local cardW = 220
    local cardH = 308
    local cardX = 35
    local cardY = 56

    local tex = nil
    if card.texture then
        tex = getTexture(card.texture)
    end
    if not tex then
        tex = getTexture("media/textures/tcg_card_back.png")
    end

    TCG_Theme.drawCardWith3DHover(self, tex, cardX, cardY, cardW, cardH, mx, my, isHolo, self.animTime)

    -- 3. Detalhes Ricos da Carta ao Lado Direito (Elimina qualquer espaco vazio)
    local details = TCG_CardRegistry.getCardDetails(card, isPT)
    local infoX = 280
    local infoY = 54

    -- Contador de progresso estilizado
    local progressFormat = isPT and "CARTA %d DE %d" or "CARD %d OF %d"
    self:drawText(string.format(progressFormat, self.currentIndex, #self.cards), infoX, infoY, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3], 1.0, UIFont.Small)

    -- Nome da Carta
    infoY = infoY + 20
    local cardName = TCG_CardRegistry.getCardName(card)
    self:drawText(cardName, infoX, infoY, TCG_Theme.TEXT_WHITE[1], TCG_Theme.TEXT_WHITE[2], TCG_Theme.TEXT_WHITE[3], 1.0, UIFont.Large)

    -- Numero e Categoria
    infoY = infoY + 30
    local numLabel = isPT and "Numero" or "Number"
    local numStr = string.format("%s: #%02d / 102 - %s", numLabel, card.number or 0, details.category)
    self:drawText(numStr, infoX, infoY, 0.70, 0.75, 0.80, 1.0, UIFont.Small)

    -- Raridade com Selo
    infoY = infoY + 20
    local rawRarity = card.rarity
    local rawRarityStr = (type(rawRarity) == "table") and rawRarity.en or rawRarity
    local rarityCol = TCG_Theme.getRarityColor(rawRarityStr, isHolo)
    local rarityValue = TCG_CardRegistry.getCardRarity(card)
    if isHolo then
        rarityValue = isPT and "* RARA HOLOGRAFICA FOIL *" or "* RARE HOLO FOIL HIT *"
    end
    self:drawRect(infoX, infoY, 305, 22, 0.15, rarityCol[1], rarityCol[2], rarityCol[3])
    self:drawRectBorder(infoX, infoY, 305, 22, 0.50, rarityCol[1], rarityCol[2], rarityCol[3])
    self:drawTextCentre(rarityValue, infoX + 152, infoY + 3, rarityCol[1], rarityCol[2], rarityCol[3], 1.0, UIFont.Small)

    -- Painel de Estatisticas de Batalha (Preenche todo o bloco direito)
    infoY = infoY + 28
    self:drawRect(infoX, infoY, 305, 96, 0.35, 0.02, 0.03, 0.04)
    self:drawRectBorder(infoX, infoY, 305, 96, 0.20, 1, 1, 1)

    local lineY = infoY + 7
    local lX = infoX + 10
    local vX = infoX + 135

    -- Tipo Elemental
    self:drawText(isPT and "Elemento / Tipo:" or "Element / Type:", lX, lineY, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 1.0, UIFont.Small)
    self:drawText(details.element, vX, lineY, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3], 1.0, UIFont.Small)

    -- HP
    lineY = lineY + 19
    self:drawText(isPT and "Pontos de Saude:" or "Hit Points:", lX, lineY, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 1.0, UIFont.Small)
    self:drawText(details.hp, vX, lineY, TCG_Theme.GREEN[1], TCG_Theme.GREEN[2], TCG_Theme.GREEN[3], 1.0, UIFont.Small)

    -- Golpe Principal
    lineY = lineY + 19
    self:drawText(isPT and "Golpe Principal:" or "Main Attack:", lX, lineY, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 1.0, UIFont.Small)
    self:drawText(details.mainAttack, vX, lineY, TCG_Theme.AMBER[1], TCG_Theme.AMBER[2], TCG_Theme.AMBER[3], 1.0, UIFont.Small)

    -- Fraqueza / Recuo
    lineY = lineY + 19
    self:drawText(isPT and "Fraqueza / Recuo:" or "Weakness / Retreat:", lX, lineY, TCG_Theme.TEXT_MUTED[1], TCG_Theme.TEXT_MUTED[2], TCG_Theme.TEXT_MUTED[3], 1.0, UIFont.Small)
    self:drawText(string.format("%s | %s", details.weakness, details.retreat), vX, lineY, 0.85, 0.85, 0.85, 1.0, UIFont.Small)

    -- Lore da Pokedex com Quebra de Linha Automatica
    infoY = infoY + 104
    self:drawRect(infoX, infoY, 305, 58, 0.20, 0.03, 0.04, 0.05)
    self:drawRectBorder(infoX, infoY, 305, 58, 0.15, 0.5, 0.6, 0.7)
    TCG_Theme.drawTextWrapped(self, details.flavor, infoX + 8, infoY + 6, 289, 0.80, 0.85, 0.90, 0.90, UIFont.Small)

    -- Dica de Inspecao fora da caixa de Lore
    local hintText = isPT and "* Clique na carta para inspecionar em tela cheia *" or "* Click on card to open Full Inspector *"
    self:drawText(hintText, infoX + 6, infoY + 62, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3], 0.85, UIFont.Small)

    -- 4. Miniaturas das 10 Cartas do Pacote (Strip inferior interativa)
    local thumbY = 388
    local packLabel = isPT and "Cartas do Booster (Clique para navegar):" or "Booster Cards (Click to navigate):"
    self:drawText(packLabel, 35, thumbY - 18, 0.70, 0.70, 0.70, 0.90, UIFont.Small)

    for i = 1, #self.cards do
        local tx = 35 + ((i - 1) * 56)
        local isCurrent = (i == self.currentIndex)
        local isPassed = (i <= self.currentIndex)
        local cardSlotData = self.cards[i]
        local isSlotHolo = cardSlotData and cardSlotData.isHolo

        local isThumbHover = (mx >= tx and mx <= (tx + 50) and my >= thumbY and my <= (thumbY + 48))

        if isPassed then
            local slotCol = isCurrent and TCG_Theme.CYAN or (isThumbHover and TCG_Theme.AMBER or {0.20, 0.25, 0.30})
            self:drawRect(tx, thumbY, 50, 48, isCurrent and 0.65 or 0.35, slotCol[1], slotCol[2], slotCol[3])
            
            local borderAlpha = isCurrent and 0.95 or (isThumbHover and 0.80 or 0.30)
            local borderCol = isSlotHolo and TCG_Theme.GOLD or slotCol
            self:drawRectBorder(tx, thumbY, 50, 48, borderAlpha, borderCol[1], borderCol[2], borderCol[3])

            local numDisplay = string.format("#%02d", cardSlotData and cardSlotData.card and cardSlotData.card.number or i)
            self:drawTextCentre(numDisplay, tx + 25, thumbY + 16, 1, 1, 1, 0.95, UIFont.Small)

            if isSlotHolo then
                self:drawTextCentre("*", tx + 25, thumbY + 30, TCG_Theme.GOLD[1], TCG_Theme.GOLD[2], TCG_Theme.GOLD[3], 1.0, UIFont.Small)
            end
        else
            self:drawRect(tx, thumbY, 50, 48, 0.20, 0.08, 0.08, 0.08)
            self:drawRectBorder(tx, thumbY, 50, 48, 0.15, 0.4, 0.4, 0.4)
            self:drawTextCentre("?", tx + 25, thumbY + 16, 0.5, 0.5, 0.5, 0.7, UIFont.Small)
        end
    end

    -- 5. Botoes Inferiores
    local btnY = 454
    local isNextHover = (mx >= 35 and mx <= 295 and my >= btnY and my <= (btnY + 32))
    local nextLabel = (self.currentIndex < #self.cards)
                        and (isPT and "REVELAR PROXIMA CARTA" or "REVEAL NEXT CARD")
                        or (isPT and "FINALIZAR E GUARDAR" or "FINISH & STORE")
    TCG_Theme.drawTacticalButton(self, nextLabel, 35, btnY, 260, 32, isNextHover, TCG_Theme.CYAN)

    local isStoreHover = (mx >= 315 and mx <= 585 and my >= btnY and my <= (btnY + 32))
    TCG_Theme.drawTacticalButton(self, isPT and "GUARDAR TODAS NA MOCHILA" or "STORE ALL IN BACKPACK", 315, btnY, 270, 32, isStoreHover, TCG_Theme.GREEN)
end
