-- =============================================================================
-- Project Zomboid TCG - Collector Binder UI (TCG_BinderUI.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Fichario de Colecionador com layout de album duplo (Double Page):
--   - 18 slots visiveis simultaneamente (3x3 esquerda + 3x3 direita)
--   - Paginacao tatica (6 folhas para as 102 cartas do Base Set 1999)
--   - Deteccao de cartas obtidas vs faltantes ("???")
--   - Destaque especial e bordas douradas para cartas Holograficas
--   - Botao de auto-guardar [AUTO-GUARDAR DA MOCHILA]
--   - Clique em qualquer carta coletada para abrir o TCG_CardInspectModal (3D Hover)
--   - Controle seguro de arrasto exclusivo por botao de Grip [ [M] ]
--   - Suporte bilingue dinamico (PT-BR / EN) com botao alternador
-- =============================================================================

require "ISUI/ISPanel"
require "TCG_Theme"
require "TCG_Config"
require "TCG_CardRegistry"
require "TCG_CardInspectModal"

TCG_BinderUI = ISPanel:derive("TCG_BinderUI")

local instance = nil

local SLOTS_PER_PAGE = 18
local TOTAL_CARDS = 102
local TOTAL_PAGES = math.ceil(TOTAL_CARDS / SLOTS_PER_PAGE) -- 6 folhas

function TCG_BinderUI:new(binderItem)
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local w = 820
    local h = 540
    local x = math.floor((screenW - w) / 2)
    local y = math.floor((screenH - h) / 2)

    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.binderItem = binderItem
    o.currentPage = 1
    o.selectedCard = nil
    o.moveWithMouse = false
    o.isDragging = false
    o.downX, o.downY = -1, -1
    o.mouseX, o.mouseY = -1, -1
    o.animTime = 0

    return o
end

function TCG_BinderUI.open(binderItem)
    if instance then
        instance:setVisible(false)
        instance:removeFromUIManager()
        instance = nil
    end

    instance = TCG_BinderUI:new(binderItem)
    instance:initialise()
    instance:instantiate()
    instance:addToUIManager()
    instance:setVisible(true)

    TCG_Theme.playAudio("BookOpen", "UI_SelectCard")
    return instance
end

function TCG_BinderUI:getBinderData()
    if not self.binderItem then return { collected = {} } end
    local md = self.binderItem:getModData()
    if not md.TCG_Binder then
        md.TCG_Binder = {
            setId = "base1",
            collected = {}
        }
    end
    return md.TCG_Binder
end

function TCG_BinderUI:getCollectionStats()
    local bData = self:getBinderData()
    local count = 0
    for _ in pairs(bData.collected) do
        count = count + 1
    end
    local pct = (count / TOTAL_CARDS) * 100.0
    return count, pct
end

function TCG_BinderUI:onMouseDown(x, y)
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

function TCG_BinderUI:onMouseUp(x, y)
    local wasDragging = self.isDragging
    self.isDragging = false

    if not wasDragging or (math.abs(x - self.downX) <= 6 and math.abs(y - self.downY) <= 6) then
        -- Botao [X] fechar (x: width - 34, y: 8, w: 26, h: 22)
        if x >= (self.width - 34) and x <= (self.width - 8) and y >= 8 and y <= 30 then
            self:closeUI()
            return true
        end

        -- Botao [IDIOMA: PT / EN]
        if x >= (self.width - 390) and x <= (self.width - 275) and y >= 8 and y <= 32 then
            TCG_Config.toggleLanguage()
            TCG_Theme.playAudio("UI_ButtonSelect")
            return true
        end

        -- Botao [AUTO-GUARDAR DA MOCHILA]
        if x >= (self.width - 265) and x <= (self.width - 70) and y >= 8 and y <= 32 then
            self:autoStoreCards()
            return true
        end

        -- Botao [< ANTERIOR]
        if x >= 30 and x <= 150 and y >= 496 and y <= 526 then
            if self.currentPage > 1 then
                self.currentPage = self.currentPage - 1
                self.selectedCard = nil
                TCG_Theme.playAudio("PageTurn", "BookOpen")
            end
            return true
        end

        -- Botao [PROXIMO >]
        if x >= (self.width - 160) and x <= (self.width - 40) and y >= 496 and y <= 526 then
            if self.currentPage < TOTAL_PAGES then
                self.currentPage = self.currentPage + 1
                self.selectedCard = nil
                TCG_Theme.playAudio("PageTurn", "BookOpen")
            end
            return true
        end

        -- Clique nos slots de cartas (Abre o Modal de Inspecao 3D)
        self:checkSlotClick(x, y)
    end

    return true
end

function TCG_BinderUI:onMouseMove(dx, dy)
    local mx = self:getMouseX()
    local my = self:getMouseY()
    self.mouseX = mx
    self.mouseY = my

    if self.isDragging then
        self:setX(self:getX() + dx)
        self:setY(self:getY() + dy)
    end
end

function TCG_BinderUI:closeUI()
    TCG_Theme.playAudio("BookClose", "UI_ToggleOff")
    self:setVisible(false)
    self:removeFromUIManager()
    instance = nil
end

--- Transfere automaticamente todas as cartas Base Set do inventario para o fichario
function TCG_BinderUI:autoStoreCards()
    local player = getPlayer()
    if not player then return end
    local inv = player:getInventory()
    local bData = self:getBinderData()

    local items = inv:getItems()
    local storedCount = 0
    local toRemove = {}

    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it:getFullType() == "Base.TCG_Card" then
            local md = it:getModData()
            local cid = md.cardId or (md.cardNumber and string.format("base1-%03d", md.cardNumber))
            if cid then
                if not bData.collected[cid] then
                    bData.collected[cid] = {
                        number = md.cardNumber or 1,
                        isHolo = md.isHolo or false,
                        count = 1
                    }
                else
                    bData.collected[cid].count = (bData.collected[cid].count or 1) + 1
                    if md.isHolo then
                        bData.collected[cid].isHolo = true
                    end
                end
                table.insert(toRemove, it)
                storedCount = storedCount + 1
            end
        end
    end

    for _, it in ipairs(toRemove) do
        inv:Remove(it)
    end

    if storedCount > 0 then
        TCG_Theme.playAudio("ItemPlacement", "PutItemInBag")
        local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
        local msg = isPT and string.format("%d cartas organizadas no fichario!", storedCount)
                          or string.format("%d cards stored in binder!", storedCount)
        if player.setHaloNote then
            pcall(function() player:setHaloNote(msg, 90, 220, 140, 250) end)
        end
    else
        TCG_Theme.playAudio("UI_ToggleOff")
    end
end

--- Retira uma ou mais cartas do fichario e devolve ao inventario do jogador
function TCG_BinderUI:withdrawCard(cardId, amount)
    local player = getPlayer()
    if not player then return 0 end
    local inv = player:getInventory()
    local bData = self:getBinderData()
    local colInfo = bData.collected[cardId]
    if not colInfo or not colInfo.count or colInfo.count < 1 then
        TCG_Theme.playAudio("UI_ToggleOff")
        return 0
    end

    amount = math.min(tonumber(amount) or 1, colInfo.count)
    if amount <= 0 then return 0 end

    local cardDef = TCG_CardRegistry.getCard(cardId)
    local num = (cardDef and cardDef.number) or colInfo.number or 1
    local nameEN = (cardDef and type(cardDef.name) == "table") and cardDef.name.en or (cardDef and cardDef.name or "Card")
    local namePT = (cardDef and type(cardDef.name) == "table") and cardDef.name.pt or (cardDef and cardDef.name or "Carta")
    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local displayName = isPT and namePT or nameEN

    for _ = 1, amount do
        local cardItem = inv:AddItem("Base.TCG_Card")
        if cardItem then
            local md = cardItem:getModData()
            md.cardId = cardId
            md.setId = "base1"
            md.cardNumber = num
            md.name_en = nameEN
            md.name_pt = namePT
            md.cardName = displayName
            md.rarity = TCG_CardRegistry.getCardRarity(cardDef)
            md.isHolo = colInfo.isHolo
            md.condition = 100

            local prefix = ""
            if isPT then
                prefix = colInfo.isHolo and "* Carta TCG (Holo): " or "Carta TCG: "
            else
                prefix = colInfo.isHolo and "* TCG Card (Holo): " or "TCG Card: "
            end
            cardItem:setName(string.format("%s%s [#%02d/102]", prefix, displayName, num))
        end
    end

    colInfo.count = colInfo.count - amount
    if colInfo.count <= 0 then
        bData.collected[cardId] = nil
    end

    TCG_Theme.playAudio("PageTurn", "PutItemInBag")
    local msg = ""
    if amount > 1 then
        msg = isPT and string.format("%dx Carta #%02d %s retiradas do fichario!", amount, num, displayName)
                   or string.format("%dx Card #%02d %s removed from binder!", amount, num, displayName)
    else
        msg = isPT and string.format("Carta #%02d %s retirada do fichario!", num, displayName)
                   or string.format("Card #%02d %s removed from binder!", num, displayName)
    end

    if player.setHaloNote then
        pcall(function() player:setHaloNote(msg, 90, 220, 140, 250) end)
    end

    return amount
end

function TCG_BinderUI:onRightMouseDown(x, y)
    return true
end

function TCG_BinderUI:onRightMouseUp(x, y)
    self:checkSlotRightClick(x, y)
    return true
end

function TCG_BinderUI:checkSlotRightClick(mx, my)
    local startNum = ((self.currentPage - 1) * SLOTS_PER_PAGE) + 1
    local slotW, slotH = 74, 104
    local bData = self:getBinderData()

    for i = 0, 17 do
        local cardNum = startNum + i
        if cardNum <= TOTAL_CARDS then
            local pageIdx = (i < 9) and 0 or 1
            local localIdx = (i < 9) and i or (i - 9)
            local col = localIdx % 3
            local row = math.floor(localIdx / 3)

            local baseX = (pageIdx == 0) and 40 or 420
            local sx = baseX + (col * (slotW + 30))
            local sy = 68 + (row * (slotH + 34))

            if mx >= sx and mx <= (sx + slotW) and my >= sy and my <= (sy + slotH) then
                local cardId = string.format("base1-%03d", cardNum)
                local colInfo = bData.collected[cardId]
                if colInfo and colInfo.count and colInfo.count >= 1 then
                    local cardDef = TCG_CardRegistry.getCard(cardId)
                    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
                    local cardName = TCG_CardRegistry.getCardName(cardDef)
                    local count = colInfo.count

                    local player = getPlayer()
                    local playerNum = player and player:getPlayerNum() or 0
                    local absX = self:getAbsoluteX() + mx
                    local absY = self:getAbsoluteY() + my
                    local context = ISContextMenu.get(playerNum, absX, absY)

                    if context then
                        -- Cabecalho informativo
                        local headerText = string.format("#%02d %s (x%d)", cardNum, tostring(cardName), count)
                        local optHeader = context:addOption(headerText, nil, nil)
                        optHeader.notAvailable = true

                        -- Opcao 1: Inspecionar em 3D
                        local optInspect = isPT and "[TCG] Inspecionar Carta em 3D" or "[TCG] Inspect Card in 3D"
                        context:addOption(optInspect, self, function()
                            TCG_CardInspectModal.show(cardDef, colInfo.isHolo, self.binderItem, count, self)
                        end)

                        -- Opcao 2: Retirar 1 Carta para a Mochila
                        local optWithdrawOne = isPT and "[TCG] Retirar 1 para a Mochila" or "[TCG] Withdraw 1 to Bag"
                        context:addOption(optWithdrawOne, self, function()
                            self:withdrawCard(cardId, 1)
                        end)

                        -- Opcao 3: Retirar Todas as Repetidas
                        if count > 1 then
                            local optWithdrawDup = isPT and string.format("[TCG] Retirar Repetidas (x%d)", count - 1)
                                                        or string.format("[TCG] Withdraw Duplicates (x%d)", count - 1)
                            context:addOption(optWithdrawDup, self, function()
                                self:withdrawCard(cardId, count - 1)
                            end)
                        end
                    end
                else
                    TCG_Theme.playAudio("UI_ToggleOff")
                end
                return
            end
        end
    end
end

function TCG_BinderUI:checkSlotClick(mx, my)
    local startNum = ((self.currentPage - 1) * SLOTS_PER_PAGE) + 1
    local slotW, slotH = 74, 104
    local bData = self:getBinderData()

    for i = 0, 17 do
        local cardNum = startNum + i
        if cardNum <= TOTAL_CARDS then
            local pageIdx = (i < 9) and 0 or 1
            local localIdx = (i < 9) and i or (i - 9)
            local col = localIdx % 3
            local row = math.floor(localIdx / 3)

            local baseX = (pageIdx == 0) and 40 or 420
            local sx = baseX + (col * (slotW + 30))
            local sy = 68 + (row * (slotH + 34))

            if mx >= sx and mx <= (sx + slotW) and my >= sy and my <= (sy + slotH) then
                local cardId = string.format("base1-%03d", cardNum)
                local colInfo = bData.collected[cardId]
                if colInfo then
                    local cardDef = TCG_CardRegistry.getCard(cardId)
                    if cardDef then
                        -- Abre o modal de inspecao rico com 3D hover e opcoes de saque
                        TCG_CardInspectModal.show(cardDef, colInfo.isHolo, self.binderItem, colInfo.count, self)
                    end
                else
                    TCG_Theme.playAudio("UI_ToggleOff")
                end
                return
            end
        end
    end
end

function TCG_BinderUI:update()
    ISPanel.update(self)
    self.animTime = (self.animTime or 0) + 0.05
end

function TCG_BinderUI:render()
    if not self:getIsVisible() then return end

    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local mx = self.mouseX or -1
    local my = self.mouseY or -1

    -- 1. Fundo Soft Glass
    TCG_Theme.drawGlassBackdrop(self, 0, 0, self.width, self.height, true)

    -- Cabecalho
    local titleText = isPT and "FICHARIO DE COLECIONADOR: BASE SET 1999" or "COLLECTOR BINDER: BASE SET 1999"
    self:drawText(titleText, 20, 11, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3], 1.0, UIFont.Medium)

    -- Botoes do Topo: Grip [M] e Fechar [X]
    local isHoverGrip = (mx >= (self.width - 64) and mx <= (self.width - 38) and my >= 8 and my <= 30)
    TCG_Theme.drawDragGrip(self, self.width - 64, 8, 26, 22, isHoverGrip, self.isDragging)

    local isHoverClose = (mx >= (self.width - 34) and mx <= (self.width - 8) and my >= 8 and my <= 30)
    TCG_Theme.drawCloseButton(self, self.width - 34, 8, 26, 22, isHoverClose)

    -- Estatisticas da Colecao
    local collectedCount, pct = self:getCollectionStats()
    local statsText = isPT and string.format("Colecao: %d / %d (%.1f%%) - Botao Esq: Inspecionar | Botao Dir: Retirar para Mochila", collectedCount, TOTAL_CARDS, pct)
                           or string.format("Collection: %d / %d (%.1f%%) - Left Click: Inspect | Right Click: Withdraw to Bag", collectedCount, TOTAL_CARDS, pct)
    self:drawText(statsText, 20, 36, 0.80, 0.85, 0.90, 1.0, UIFont.Small)

    -- Botao [IDIOMA: PT] / [LANG: EN]
    local langBtn = isPT and "IDIOMA: PT" or "LANG: EN"
    local isLangHover = (mx >= (self.width - 390) and mx <= (self.width - 275) and my >= 8 and my <= 32)
    TCG_Theme.drawTacticalButton(self, langBtn, self.width - 390, 8, 115, 24, isLangHover, TCG_Theme.AMBER)

    -- Botao [AUTO-GUARDAR DA MOCHILA]
    local autoStoreBtn = isPT and "AUTO-GUARDAR DA MOCHILA" or "AUTO-STORE FROM BAG"
    local isStoreHover = (mx >= (self.width - 265) and mx <= (self.width - 70) and my >= 8 and my <= 32)
    TCG_Theme.drawTacticalButton(self, autoStoreBtn, self.width - 265, 8, 195, 24, isStoreHover, TCG_Theme.GREEN)

    -- Divisoria do Cabecalho
    self:drawRect(16, 54, self.width - 32, 1, 0.20, 1, 1, 1)

    -- Divisoria Central do Fichario (Entre a folha esquerda e a folha direita)
    self:drawRect(math.floor(self.width / 2) - 1, 60, 2, 420, 0.25, 0.4, 0.4, 0.4)

    -- 2. Renderizacao dos 18 Slots
    local startNum = ((self.currentPage - 1) * SLOTS_PER_PAGE) + 1
    local slotW, slotH = 74, 104
    local bData = self:getBinderData()

    for i = 0, 17 do
        local cardNum = startNum + i
        if cardNum <= TOTAL_CARDS then
            local pageIdx = (i < 9) and 0 or 1
            local localIdx = (i < 9) and i or (i - 9)
            local col = localIdx % 3
            local row = math.floor(localIdx / 3)

            local baseX = (pageIdx == 0) and 40 or 420
            local sx = baseX + (col * (slotW + 30))
            local sy = 68 + (row * (slotH + 34))

            local cardId = string.format("base1-%03d", cardNum)
            local colInfo = bData.collected[cardId]
            local isSlotHover = (mx >= sx and mx <= (sx + slotW) and my >= sy and my <= (sy + slotH))

            if colInfo then
                -- Slot Ocupado (Carta Coletada)
                local cardDef = TCG_CardRegistry.getCard(cardId)
                local tex = cardDef and cardDef.texture and getTexture(cardDef.texture)
                if not tex then tex = getTexture("media/textures/tcg_card_back.png") end

                if tex then
                    self:drawTextureScaled(tex, sx, sy, slotW, slotH, 1.0)
                else
                    self:drawRect(sx, sy, slotW, slotH, 0.70, 0.12, 0.14, 0.18)
                    local displayName = TCG_CardRegistry.getCardName(cardDef)
                    self:drawTextCentre(displayName, sx + (slotW / 2), sy + 40, 1, 1, 1, 0.9, UIFont.Small)
                end

                -- Efeito Hover / Selecao
                if isSlotHover then
                    self:drawRectBorder(sx - 2, sy - 2, slotW + 4, slotH + 4, 0.95, TCG_Theme.CYAN[1], TCG_Theme.CYAN[2], TCG_Theme.CYAN[3])
                end

                -- Destaque se for Holografica
                if colInfo.isHolo then
                    local pulse = 0.70 + 0.30 * math.sin((self.animTime or 0) * 3.0 + i)
                    self:drawRectBorder(sx - 1, sy - 1, slotW + 2, slotH + 2, pulse, TCG_Theme.GOLD[1], TCG_Theme.GOLD[2], TCG_Theme.GOLD[3])
                    self:drawTextCentre("*", sx + (slotW / 2), sy + slotH - 16, TCG_Theme.GOLD[1], TCG_Theme.GOLD[2], TCG_Theme.GOLD[3], 1.0, UIFont.Small)
                else
                    if not isSlotHover then
                        self:drawRectBorder(sx, sy, slotW, slotH, 0.35, 1, 1, 1)
                    end
                end

                -- Tag de Quantidade (ex: x2)
                if colInfo.count and colInfo.count > 1 then
                    local countStr = "x" .. tostring(colInfo.count)
                    self:drawRect(sx + slotW - 20, sy + slotH - 14, 20, 14, 0.80, 0, 0, 0)
                    self:drawText(countStr, sx + slotW - 18, sy + slotH - 14, 1, 1, 1, 1.0, UIFont.Small)
                end

                -- Nome traduzido abaixo do slot
                local cardName = TCG_CardRegistry.getCardName(cardDef)
                if string.len(cardName) > 13 then cardName = string.sub(cardName, 1, 11) .. ".." end
                local nameCol = isSlotHover and TCG_Theme.CYAN or {0.85, 0.90, 0.95}
                self:drawTextCentre(cardName, sx + (slotW / 2), sy + slotH + 4, nameCol[1], nameCol[2], nameCol[3], 0.95, UIFont.Small)
            else
                -- Slot Vazio (Ainda Nao Obtida)
                self:drawRect(sx, sy, slotW, slotH, 0.40, 0.05, 0.06, 0.08)
                self:drawRectBorder(sx, sy, slotW, slotH, isSlotHover and 0.45 or 0.18, 0.5, 0.5, 0.5)

                local numLabel = string.format("#%02d", cardNum)
                self:drawTextCentre(numLabel, sx + (slotW / 2), sy + 36, 0.40, 0.45, 0.50, 0.70, UIFont.Small)
                self:drawTextCentre("???", sx + (slotW / 2), sy + 54, 0.30, 0.35, 0.40, 0.60, UIFont.Small)
            end
        end
    end

    -- 3. Barra Inferior de Navegacao
    self:drawRect(16, 490, self.width - 32, 1, 0.20, 1, 1, 1)

    local prevLabel = isPT and "< ANTERIOR" or "< PREVIOUS"
    local isPrevHover = (mx >= 30 and mx <= 150 and my >= 498 and my <= 526)
    TCG_Theme.drawTacticalButton(self, prevLabel, 30, 498, 120, 26, isPrevHover and (self.currentPage > 1), (self.currentPage > 1) and TCG_Theme.CYAN or {0.3, 0.3, 0.3})

    local folhaLabel = isPT and "Folha" or "Page"
    local cartasLabel = isPT and "Cartas" or "Cards"
    local pageLabel = string.format("%s %d de %d  (%s #%02d a #%02d)", folhaLabel, self.currentPage, TOTAL_PAGES, cartasLabel, startNum, math.min(TOTAL_CARDS, startNum + SLOTS_PER_PAGE - 1))
    self:drawTextCentre(pageLabel, math.floor(self.width / 2), 502, 0.85, 0.90, 0.95, 1.0, UIFont.Small)

    local nextLabel = isPT and "PROXIMO >" or "NEXT >"
    local isNextHover = (mx >= (self.width - 160) and mx <= (self.width - 40) and my >= 498 and my <= 526)
    TCG_Theme.drawTacticalButton(self, nextLabel, self.width - 160, 498, 120, 26, isNextHover and (self.currentPage < TOTAL_PAGES), (self.currentPage < TOTAL_PAGES) and TCG_Theme.CYAN or {0.3, 0.3, 0.3})
end
