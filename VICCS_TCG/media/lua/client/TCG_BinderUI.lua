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

--- Inicializa e garante persistencia isolada por item fisico (Anti-Shared State com UUID)
function TCG_BinderUI.getBinderDataFromItem(binderItem)
    if not binderItem then return { collected = {} } end
    local md = binderItem:getModData()
    if not md.TCG_Binder then
        local uniqueId = tostring(getTimeInMillis()) .. "_" .. tostring(ZombRand(100000, 999999))
        md.TCG_Binder = {
            uuid = uniqueId,
            setId = "base1",
            customName = "",
            themeColor = "CYAN",
            badge = "COLLECTOR",
            collected = {}
        }
    end

    if not md.TCG_Binder.uuid then
        md.TCG_Binder.uuid = tostring(getTimeInMillis()) .. "_" .. tostring(ZombRand(100000, 999999))
    end
    if not md.TCG_Binder.themeColor then
        md.TCG_Binder.themeColor = "CYAN"
    end
    if not md.TCG_Binder.badge then
        md.TCG_Binder.badge = "COLLECTOR"
    end
    if not md.TCG_Binder.collected then
        md.TCG_Binder.collected = {}
    end

    return md.TCG_Binder
end

function TCG_BinderUI.getCollectionStatsForItem(binderItem)
    local bData = TCG_BinderUI.getBinderDataFromItem(binderItem)
    local count = 0
    for _ in pairs(bData.collected) do
        count = count + 1
    end
    local pct = (count / TOTAL_CARDS) * 100.0
    return count, pct
end

--- Varre o inventario e mochilas/bolsas equipadas do jogador em busca de ficharios fisicos
function TCG_BinderUI.findPlayerBinders(playerObj)
    if not playerObj then return {} end
    local binders = {}
    local inv = playerObj:getInventory()

    local function scan(container)
        if not container then return end
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                local fullType = it:getFullType()
                if fullType == "Base.TCG_Binder" or fullType == "TCG_Binder" then
                    table.insert(binders, it)
                end
                if it:IsInventoryContainer() and it:getItemContainer() then
                    scan(it:getItemContainer())
                end
            end
        end
    end

    scan(inv)
    return binders
end

--- Transfere uma carta de forma atomica para o fichario fisico especificado
function TCG_BinderUI.storeCard(binderItem, cardItem, playerObj)
    if not binderItem or not cardItem then return false end
    local bData = TCG_BinderUI.getBinderDataFromItem(binderItem)
    local md = cardItem:getModData()
    local cid = md.cardId or (md.cardNumber and string.format("base1-%03d", md.cardNumber))
    if not cid then return false end

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

    local container = cardItem:getContainer()
    if container then
        container:Remove(cardItem)
    elseif playerObj then
        playerObj:getInventory():Remove(cardItem)
    end
    return true
end

--- Transfere uma lista de cartas para o fichario com efeito sonoro e feedback visual
function TCG_BinderUI.storeCardsList(binderItem, cardItems, playerObj)
    if not binderItem or not cardItems or #cardItems == 0 then return 0 end
    local storedCount = 0
    for _, cardIt in ipairs(cardItems) do
        if TCG_BinderUI.storeCard(binderItem, cardIt, playerObj) then
            storedCount = storedCount + 1
        end
    end

    if storedCount > 0 then
        TCG_Theme.playAudio("ItemPlacement", "PutItemInBag")
        local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
        local bData = TCG_BinderUI.getBinderDataFromItem(binderItem)
        local binderTitle = (bData.customName and bData.customName ~= "") and bData.customName or (isPT and "Fichario" or "Binder")
        local msg = isPT and string.format("%d carta(s) guardada(s) no %s!", storedCount, binderTitle)
                          or string.format("%d card(s) stored in %s!", storedCount, binderTitle)
        if playerObj and playerObj.setHaloNote then
            pcall(function() playerObj:setHaloNote(msg, 90, 220, 140, 250) end)
        end
    end
    return storedCount
end

function TCG_BinderUI:getBinderData()
    return TCG_BinderUI.getBinderDataFromItem(self.binderItem)
end

function TCG_BinderUI:getCollectionStats()
    return TCG_BinderUI.getCollectionStatsForItem(self.binderItem)
end

function TCG_BinderUI:cycleBadge()
    local bData = self:getBinderData()
    local current = bData.badge or "COLLECTOR"
    local nextBadge = "COLLECTOR"
    for i, k in ipairs(TCG_Theme.BADGES) do
        if k == current then
            nextBadge = TCG_Theme.BADGES[(i % #TCG_Theme.BADGES) + 1]
            break
        end
    end
    bData.badge = nextBadge
    TCG_Theme.playAudio("UI_ButtonSelect")
end

function TCG_BinderUI:onRenameClick()
    local player = getPlayer()
    local playerNum = player and player:getPlayerNum() or 0
    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local bData = self:getBinderData()
    local curName = bData.customName or ""
    local title = isPT and "Renomear Fichario TCG:" or "Rename TCG Binder:"

    local modal = ISTextBox:new(0, 0, 280, 160, title, curName, self, TCG_BinderUI.onRenameConfirm, playerNum)
    modal:initialise()
    modal:addToUIManager()
end

function TCG_BinderUI:onRenameConfirm(button)
    if button.internal == "OK" then
        local entry = (button.parent and button.parent.entry) or (button.target and button.target.entry)
        local text = entry and entry:getText()
        if text then
            local bData = self:getBinderData()
            bData.customName = tostring(text)
            if self.binderItem then
                local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
                local baseLabel = isPT and "Fichario TCG" or "TCG Binder"
                if text ~= "" then
                    self.binderItem:setName(string.format("%s: %s", baseLabel, text))
                else
                    self.binderItem:setName(baseLabel)
                end
            end
            TCG_Theme.playAudio("UI_ButtonSelect")
        end
    end
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

        -- Botao [AUTO-GUARDAR DA MOCHILA] (x: width - 230 a width - 70, y: 8 a 32)
        if x >= (self.width - 230) and x <= (self.width - 70) and y >= 8 and y <= 32 then
            self:autoStoreCards()
            return true
        end

        -- Botao [IDIOMA: PT / EN] (x: width - 325 a width - 235, y: 8 a 32)
        if x >= (self.width - 325) and x <= (self.width - 235) and y >= 8 and y <= 32 then
            TCG_Config.toggleLanguage()
            TCG_Theme.playAudio("UI_ButtonSelect")
            return true
        end

        -- Botao [RENOMEAR] (x: width - 415 a width - 330, y: 8 a 32)
        if x >= (self.width - 415) and x <= (self.width - 330) and y >= 8 and y <= 32 then
            self:onRenameClick()
            return true
        end

        -- Botao [TAG] (x: width - 530 a width - 420, y: 8 a 32)
        if x >= (self.width - 530) and x <= (self.width - 420) and y >= 8 and y <= 32 then
            self:cycleBadge()
            return true
        end

        -- Chips de Cor da Capa (Linha 2, x: width - 180 ate width - 20, y: 34 a 52)
        if x >= (self.width - 180) and x <= (self.width - 20) and y >= 34 and y <= 52 then
            local chipIdx = math.floor((x - (self.width - 180)) / 26) + 1
            if chipIdx >= 1 and chipIdx <= #TCG_Theme.THEME_KEYS then
                local bData = self:getBinderData()
                bData.themeColor = TCG_Theme.THEME_KEYS[chipIdx]
                TCG_Theme.playAudio("UI_ButtonSelect")
                return true
            end
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
    if not player or not self.binderItem then return end
    local inv = player:getInventory()

    local items = inv:getItems()
    local cardItems = {}
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and (it:getFullType() == "Base.TCG_Card" or it:getFullType() == "TCG_Card") then
            table.insert(cardItems, it)
        end
    end

    if #cardItems > 0 then
        TCG_BinderUI.storeCardsList(self.binderItem, cardItems, player)
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

    -- 1. Fundo Soft Glass com cor tematica da capa
    local bData = self:getBinderData()
    local themeKey = bData.themeColor or "CYAN"
    local themeDef = TCG_Theme.THEMES[themeKey] or TCG_Theme.THEMES["CYAN"]
    local accentCol = themeDef.col

    TCG_Theme.drawGlassBackdrop(self, 0, 0, self.width, self.height, true, accentCol)

    -- Cabecalho & Titulo Customizado com Badge
    local badgeKey = bData.badge or "COLLECTOR"
    local badgeDef = TCG_Theme.BADGE_LABELS[badgeKey] or TCG_Theme.BADGE_LABELS["COLLECTOR"]
    local badgeStr = isPT and badgeDef.pt or badgeDef.en
    local customName = (bData.customName and bData.customName ~= "") and bData.customName or (isPT and "Fichario Base Set 1999" or "Base Set 1999 Binder")
    local fullTitle = string.format("%s %s", badgeStr, customName)
    self:drawText(fullTitle, 20, 11, accentCol[1], accentCol[2], accentCol[3], 1.0, UIFont.Medium)

    -- Botoes do Topo: Grip [M] e Fechar [X]
    local isHoverGrip = (mx >= (self.width - 64) and mx <= (self.width - 38) and my >= 8 and my <= 30)
    TCG_Theme.drawDragGrip(self, self.width - 64, 8, 26, 22, isHoverGrip, self.isDragging)

    local isHoverClose = (mx >= (self.width - 34) and mx <= (self.width - 8) and my >= 8 and my <= 30)
    TCG_Theme.drawCloseButton(self, self.width - 34, 8, 26, 22, isHoverClose)

    -- Botoes de Acao do Topo
    -- Botao [AUTO-GUARDAR DA MOCHILA]
    local autoStoreBtn = isPT and "AUTO-GUARDAR" or "AUTO-STORE"
    local isStoreHover = (mx >= (self.width - 230) and mx <= (self.width - 70) and my >= 8 and my <= 32)
    TCG_Theme.drawTacticalButton(self, autoStoreBtn, self.width - 230, 8, 160, 24, isStoreHover, TCG_Theme.GREEN)

    -- Botao [IDIOMA: PT] / [LANG: EN]
    local langBtn = isPT and "IDIOMA: PT" or "LANG: EN"
    local isLangHover = (mx >= (self.width - 325) and mx <= (self.width - 235) and my >= 8 and my <= 32)
    TCG_Theme.drawTacticalButton(self, langBtn, self.width - 325, 8, 90, 24, isLangHover, TCG_Theme.AMBER)

    -- Botao [RENOMEAR]
    local renameBtn = isPT and "RENOMEAR" or "RENAME"
    local isRenameHover = (mx >= (self.width - 415) and mx <= (self.width - 330) and my >= 8 and my <= 32)
    TCG_Theme.drawTacticalButton(self, renameBtn, self.width - 415, 8, 85, 24, isRenameHover, accentCol)

    -- Botao [TAG]
    local tagBtn = isPT and "TAG" or "BADGE"
    local isTagHover = (mx >= (self.width - 530) and mx <= (self.width - 420) and my >= 8 and my <= 32)
    TCG_Theme.drawTacticalButton(self, tagBtn, self.width - 530, 8, 110, 24, isTagHover, accentCol)

    -- Estatisticas da Colecao (Linha 2, esquerda)
    local collectedCount, pct = self:getCollectionStats()
    local statsText = isPT and string.format("Colecao: %d / %d (%.1f%%) | Esq: Inspecionar | Dir: Retirar", collectedCount, TOTAL_CARDS, pct)
                           or string.format("Collection: %d / %d (%.1f%%) | Left: Inspect | Right: Withdraw", collectedCount, TOTAL_CARDS, pct)
    self:drawText(statsText, 20, 36, 0.80, 0.85, 0.90, 1.0, UIFont.Small)

    -- Chips de Cor da Capa (Linha 2, direita)
    local colorLabel = isPT and "COR:" or "THEME:"
    self:drawText(colorLabel, self.width - 230, 36, 0.70, 0.75, 0.80, 1.0, UIFont.Small)
    for cIdx, cKey in ipairs(TCG_Theme.THEME_KEYS) do
        local cDef = TCG_Theme.THEMES[cKey]
        local chipX = (self.width - 180) + ((cIdx - 1) * 26)
        local chipY = 36
        local isChipSelected = (cKey == themeKey)
        local isChipHover = (mx >= chipX and mx <= (chipX + 20) and my >= chipY and my <= (chipY + 14))

        self:drawRect(chipX, chipY, 20, 14, 0.90, cDef.col[1], cDef.col[2], cDef.col[3])
        if isChipSelected then
            self:drawRectBorder(chipX - 1, chipY - 1, 22, 16, 1.0, 1.0, 1.0, 1.0)
        elseif isChipHover then
            self:drawRectBorder(chipX, chipY, 20, 14, 0.60, 1.0, 1.0, 1.0)
        else
            self:drawRectBorder(chipX, chipY, 20, 14, 0.25, 0.0, 0.0, 0.0)
        end
    end

    -- Divisoria do Cabecalho
    self:drawRect(16, 54, self.width - 32, 1, 0.20, 1, 1, 1)

    -- Divisoria Central do Fichario (Entre a folha esquerda e a folha direita)
    self:drawRect(math.floor(self.width / 2) - 1, 60, 2, 420, 0.25, 0.4, 0.4, 0.4)

    -- 2. Renderizacao dos 18 Slots
    local startNum = ((self.currentPage - 1) * SLOTS_PER_PAGE) + 1
    local slotW, slotH = 74, 104

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
                    self:drawRectBorder(sx - 2, sy - 2, slotW + 4, slotH + 4, 0.95, accentCol[1], accentCol[2], accentCol[3])
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
