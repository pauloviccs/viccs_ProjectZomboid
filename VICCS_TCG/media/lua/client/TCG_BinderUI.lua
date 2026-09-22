-- =============================================================================
-- Project Zomboid TCG - Collector Binder UI (TCG_BinderUI.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Fichario de Colecionador com layout de album duplo (Double Page) Multi-Expansoes:
--   - 18 slots visiveis simultaneamente (3x3 esquerda + 3x3 direita)
--   - Sistema de Abas de Expansao Dinamico e Extensivel (Base Set, Jungle, Fossil, Rocket, Eevee Heroes)
--   - Paginacao tatica adaptativa por colecao (Base Set: 6 folhas, Jungle: 4 folhas, Fossil: 4 folhas, etc.)
--   - Deteccao de cartas obtidas vs faltantes ("???") por conjunto
--   - Destaque especial e bordas douradas para cartas Holograficas
--   - Botao de auto-guardar recursivo (varre inventario e mochilas equipadas)
--   - Clique esquerdo em carta coletada para abrir o TCG_CardInspectModal (3D Hover)
--   - Clique direito no slot para menu de saque de cartas (1 unidade ou repetidas)
--   - Controle seguro de arrasto exclusivo por botao de Grip [ [M] ]
--   - Suporte bilingue dinamico (PT-BR / EN) com botao alternador
--   - Estatisticas por colecao e totais gerais (X / 412)
-- =============================================================================

require "ISUI/ISPanel"
require "TCG_Theme"
require "TCG_Config"
require "TCG_CardRegistry"
require "TCG_CardInspectModal"

TCG_BinderUI = ISPanel:derive("TCG_BinderUI")

local instance = nil

local SLOTS_PER_PAGE = 18

-- Ordem canonica de exibicao das abas das colecoes
TCG_BinderUI.DEFAULT_SET_ORDER = { "base1", "jungle", "fossil", "rocket", "eeveeheroes" }

--- Retorna todas as colecoes registradas, comecando pela ordem canonica e incorporando novas expansoes
function TCG_BinderUI.getAvailableSets()
    local ordered = {}
    local seen = {}
    for _, sId in ipairs(TCG_BinderUI.DEFAULT_SET_ORDER) do
        if TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[sId] then
            table.insert(ordered, sId)
            seen[sId] = true
        end
    end
    if TCG_CardRegistry.Sets then
        for sId, setDef in pairs(TCG_CardRegistry.Sets) do
            if not seen[sId] and type(setDef) == "table" and setDef.cards then
                table.insert(ordered, sId)
                seen[sId] = true
            end
        end
    end
    return ordered
end

--- Retorna o rotulo curto amigavel para a aba de cada conjunto
function TCG_BinderUI.getSetTabName(sId, isPT)
    local shortNames = {
        ["base1"] = isPT and "Base '99" or "Base '99",
        ["jungle"] = "Jungle",
        ["fossil"] = "Fossil",
        ["rocket"] = isPT and "Eq. Rocket" or "Team Rocket",
        ["eeveeheroes"] = "Eevee Heroes"
    }
    if shortNames[sId] then return shortNames[sId] end
    local setDef = TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[sId]
    if setDef and setDef.name then
        return isPT and (setDef.name.pt or setDef.name.en) or (setDef.name.en or setDef.name.pt)
    end
    return string.upper(sId)
end

function TCG_BinderUI:new(binderItem)
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local w = 840
    local h = 560
    local x = math.floor((screenW - w) / 2)
    local y = math.floor((screenH - h) / 2)

    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.binderItem = binderItem
    local bData = TCG_BinderUI.getBinderDataFromItem(binderItem)
    o.activeSet = bData.activeSet or "base1"
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

    TCG_Theme.playBookOpen()
    return instance
end

--- Inicializa e garante persistencia isolada por item fisico com Auto-Heal para saves legados
function TCG_BinderUI.getBinderDataFromItem(binderItem)
    if not binderItem then return { collected = {}, activeSet = "base1" } end
    local md = binderItem:getModData()
    if not md.TCG_Binder then
        local uniqueId = tostring(getTimeInMillis()) .. "_" .. tostring(ZombRand(100000, 999999))
        md.TCG_Binder = {
            uuid = uniqueId,
            setId = "base1",
            activeSet = "base1",
            customName = "",
            themeColor = "CYAN",
            badge = "COLLECTOR",
            collected = {}
        }
    end

    local b = md.TCG_Binder
    if not b.uuid then
        b.uuid = tostring(getTimeInMillis()) .. "_" .. tostring(ZombRand(100000, 999999))
    end
    if not b.activeSet or b.activeSet == "" then
        b.activeSet = b.setId or "base1"
    end
    if not b.themeColor or b.themeColor == "" then
        b.themeColor = "CYAN"
    end
    if not b.badge or b.badge == "" then
        b.badge = "COLLECTOR"
    end
    if not b.collected then
        b.collected = {}
    end

    -- AUTO-HEAL: Migra formatos de saves anteriores (chaves numericas, sem zeros ou sem tabela)
    local hasLegacyKeys = false
    for k, v in pairs(b.collected) do
        local sk = tostring(k)
        if (type(k) == "number") or (not sk:find("-")) or (sk:match("%-(%d+)$") and #sk:match("%-(%d+)$") < 3) or (type(v) ~= "table") then
            hasLegacyKeys = true
            break
        end
    end

    if hasLegacyKeys then
        local healed = {}
        for k, v in pairs(b.collected) do
            local sk = tostring(k)
            local targetCid = sk
            if not sk:find("-") then
                local num = tonumber(sk) or 1
                targetCid = string.format("base1-%03d", num)
            else
                local sId, sNum = sk:match("^([^-]+)%-(%d+)$")
                if sId and sNum and #sNum < 3 then
                    targetCid = string.format("%s-%03d", sId, tonumber(sNum))
                end
            end

            local entry = { number = 1, isHolo = false, count = 1 }
            if type(v) == "table" then
                entry.number = tonumber(v.number) or tonumber(targetCid:match("%-(%d+)$")) or 1
                entry.isHolo = (v.isHolo == true)
                entry.count = tonumber(v.count) or 1
            elseif type(v) == "number" then
                entry.number = tonumber(targetCid:match("%-(%d+)$")) or 1
                entry.isHolo = false
                entry.count = math.max(1, v)
            elseif type(v) == "boolean" then
                entry.number = tonumber(targetCid:match("%-(%d+)$")) or 1
                entry.isHolo = v
                entry.count = 1
            end

            if healed[targetCid] then
                healed[targetCid].count = healed[targetCid].count + entry.count
                if entry.isHolo then healed[targetCid].isHolo = true end
            else
                healed[targetCid] = entry
            end
        end
        b.collected = healed
    end

    return b
end

--- Estatisticas especificas de um conjunto (ex: Jungle -> 12 de 64)
function TCG_BinderUI.getCollectionStatsForSet(binderItem, setId)
    local bData = TCG_BinderUI.getBinderDataFromItem(binderItem)
    local setDef = TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[setId]
    local setTotal = setDef and setDef.total or 102
    local count = 0

    if bData.collected then
        for cid, col in pairs(bData.collected) do
            local cidStr = tostring(cid)
            local s = cidStr:match("^([^-]+)%-") or "base1"
            if s == setId and col and col.count and col.count > 0 then
                count = count + 1
            end
        end
    end
    local pct = (count / math.max(1, setTotal)) * 100.0
    return count, setTotal, pct
end

--- Estatisticas gerais somando todas as colecoes registradas (ex: 89 de 412)
function TCG_BinderUI.getGrandTotalStats(binderItem)
    local bData = TCG_BinderUI.getBinderDataFromItem(binderItem)
    local availableSets = TCG_BinderUI.getAvailableSets()
    local grandTotal = 0
    local grandCount = 0

    for _, sId in ipairs(availableSets) do
        local setDef = TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[sId]
        if setDef and setDef.total then
            grandTotal = grandTotal + setDef.total
        end
    end

    if bData.collected then
        for _, col in pairs(bData.collected) do
            if col and col.count and col.count > 0 then
                grandCount = grandCount + 1
            end
        end
    end

    local pct = (grandCount / math.max(1, grandTotal)) * 100.0
    return grandCount, grandTotal, pct
end

--- Compatibilidade legada para chamadas externas
function TCG_BinderUI.getCollectionStatsForItem(binderItem)
    local count, total, pct = TCG_BinderUI.getGrandTotalStats(binderItem)
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
    local sId = md.setId or "base1"
    local cid = md.cardId or (md.cardNumber and string.format("%s-%03d", sId, md.cardNumber))
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
        TCG_Theme.playCardSlot()
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

function TCG_BinderUI:getActiveSetDef()
    local sId = self.activeSet or "base1"
    if TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[sId] then
        return TCG_CardRegistry.Sets[sId]
    end
    return TCG_CardRegistry.Sets and TCG_CardRegistry.Sets["base1"]
end

function TCG_BinderUI:getTotalCardsInActiveSet()
    local setDef = self:getActiveSetDef()
    return setDef and setDef.total or 102
end

function TCG_BinderUI:getTotalPagesInActiveSet()
    local totalCards = self:getTotalCardsInActiveSet()
    return math.max(1, math.ceil(totalCards / SLOTS_PER_PAGE))
end

function TCG_BinderUI:getCardIdForSlot(cardNum)
    local sId = self.activeSet or "base1"
    return string.format("%s-%03d", sId, cardNum)
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
            TCG_Theme.playButtonClick()
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
            TCG_Theme.playButtonClick()
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

        -- 2. Barra de Abas das Colecoes (y: 36 a 60)
        local availableSets = TCG_BinderUI.getAvailableSets()
        local numSets = #availableSets
        local tabW = math.floor((self.width - 40 - ((numSets - 1) * 6)) / math.max(1, numSets))
        if y >= 36 and y <= 60 then
            for idx, sId in ipairs(availableSets) do
                local tx = 20 + ((idx - 1) * (tabW + 6))
                if x >= tx and x <= (tx + tabW) then
                    if self.activeSet ~= sId then
                        self.activeSet = sId
                        self.currentPage = 1
                        self.selectedCard = nil
                        local bData = self:getBinderData()
                        bData.activeSet = sId
                        TCG_Theme.playTabSwitch()
                    end
                    return true
                end
            end
        end

        -- 3. Chips de Cor da Capa (Linha 3, x: width - 180 ate width - 20, y: 64 a 80)
        if x >= (self.width - 180) and x <= (self.width - 20) and y >= 64 and y <= 80 then
            local chipIdx = math.floor((x - (self.width - 180)) / 26) + 1
            if chipIdx >= 1 and chipIdx <= #TCG_Theme.THEME_KEYS then
                local bData = self:getBinderData()
                bData.themeColor = TCG_Theme.THEME_KEYS[chipIdx]
                TCG_Theme.playButtonClick()
                return true
            end
        end

        local totalPages = self:getTotalPagesInActiveSet()

        -- 4. Botao [< ANTERIOR] (y: 508 a 538)
        if x >= 30 and x <= 150 and y >= 508 and y <= 538 then
            if self.currentPage > 1 then
                self.currentPage = self.currentPage - 1
                self.selectedCard = nil
                TCG_Theme.playPageTurn()
            end
            return true
        end

        -- 5. Botao [PROXIMO >] (y: 508 a 538)
        if x >= (self.width - 160) and x <= (self.width - 40) and y >= 508 and y <= 538 then
            if self.currentPage < totalPages then
                self.currentPage = self.currentPage + 1
                self.selectedCard = nil
                TCG_Theme.playPageTurn()
            end
            return true
        end

        -- 6. Clique nos slots de cartas (Abre o Modal de Inspecao 3D)
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
    TCG_Theme.playBookClose()
    self:setVisible(false)
    self:removeFromUIManager()
    instance = nil
end

--- Transfere automaticamente todas as cartas do inventario e mochilas para o fichario
function TCG_BinderUI:autoStoreCards()
    local player = getPlayer()
    if not player or not self.binderItem then return end
    local inv = player:getInventory()
    local cardItems = {}

    local function scan(container)
        if not container then return end
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                local ft = it:getFullType()
                if ft == "Base.TCG_Card" or ft == "TCG_Card" then
                    table.insert(cardItems, it)
                end
                if it:IsInventoryContainer() and it:getItemContainer() then
                    scan(it:getItemContainer())
                end
            end
        end
    end

    scan(inv)

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
    local setId = (cardDef and cardDef.setId) or (cardId:match("^([^-]+)%-")) or self.activeSet or "base1"
    local setDef = TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[setId]
    local setTotal = setDef and setDef.total or 102
    local nameEN = (cardDef and type(cardDef.name) == "table") and cardDef.name.en or (cardDef and cardDef.name or "Card")
    local namePT = (cardDef and type(cardDef.name) == "table") and cardDef.name.pt or (cardDef and cardDef.name or "Carta")
    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local displayName = isPT and namePT or nameEN

    for _ = 1, amount do
        local cardItem = inv:AddItem("Base.TCG_Card")
        if cardItem then
            local md = cardItem:getModData()
            md.cardId = cardId
            md.setId = setId
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
            cardItem:setName(string.format("%s%s [#%02d/%d]", prefix, displayName, num, setTotal))
        end
    end

    colInfo.count = colInfo.count - amount
    if colInfo.count <= 0 then
        bData.collected[cardId] = nil
    end

    TCG_Theme.playCardWithdraw()
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
    local totalInSet = self:getTotalCardsInActiveSet()

    for i = 0, 17 do
        local cardNum = startNum + i
        if cardNum <= totalInSet then
            local pageIdx = (i < 9) and 0 or 1
            local localIdx = (i < 9) and i or (i - 9)
            local col = localIdx % 3
            local row = math.floor(localIdx / 3)

            local baseX = (pageIdx == 0) and 40 or 440
            local sx = baseX + (col * (slotW + 36))
            local sy = 88 + (row * (slotH + 34))

            if mx >= sx and mx <= (sx + slotW) and my >= sy and my <= (sy + slotH) then
                local cardId = self:getCardIdForSlot(cardNum)
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
    local totalInSet = self:getTotalCardsInActiveSet()

    for i = 0, 17 do
        local cardNum = startNum + i
        if cardNum <= totalInSet then
            local pageIdx = (i < 9) and 0 or 1
            local localIdx = (i < 9) and i or (i - 9)
            local col = localIdx % 3
            local row = math.floor(localIdx / 3)

            local baseX = (pageIdx == 0) and 40 or 440
            local sx = baseX + (col * (slotW + 36))
            local sy = 88 + (row * (slotH + 34))

            if mx >= sx and mx <= (sx + slotW) and my >= sy and my <= (sy + slotH) then
                local cardId = self:getCardIdForSlot(cardNum)
                local colInfo = bData.collected[cardId]
                if colInfo then
                    local cardDef = TCG_CardRegistry.getCard(cardId)
                    if cardDef then
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

    -- Cabecalho & Titulo Customizado com Badge (Linha 1)
    local badgeKey = bData.badge or "COLLECTOR"
    local badgeDef = TCG_Theme.BADGE_LABELS[badgeKey] or TCG_Theme.BADGE_LABELS["COLLECTOR"]
    local badgeStr = isPT and badgeDef.pt or badgeDef.en
    local customName = (bData.customName and bData.customName ~= "") and bData.customName or (isPT and "Fichario de Colecionador" or "Collector Binder")
    local fullTitle = string.format("%s %s", badgeStr, customName)
    self:drawText(fullTitle, 20, 10, accentCol[1], accentCol[2], accentCol[3], 1.0, UIFont.Medium)

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

    -- 2. Barra de Abas de Expansoes (Linha 2, y: 36 a 60)
    local availableSets = TCG_BinderUI.getAvailableSets()
    local numSets = #availableSets
    local tabW = math.floor((self.width - 40 - ((numSets - 1) * 6)) / math.max(1, numSets))

    for idx, sId in ipairs(availableSets) do
        local tx = 20 + ((idx - 1) * (tabW + 6))
        local ty = 36
        local isTabActive = (self.activeSet == sId)
        local isTabHover = (mx >= tx and mx <= (tx + tabW) and my >= ty and my <= (ty + 24))

        local sName = TCG_BinderUI.getSetTabName(sId, isPT)
        local sCount, sTotal = TCG_BinderUI.getCollectionStatsForSet(self.binderItem, sId)
        local tabLabel = string.format("%s (%d/%d)", sName, sCount, sTotal)

        if isTabActive then
            self:drawRect(tx, ty, tabW, 24, 0.40, accentCol[1], accentCol[2], accentCol[3])
            self:drawRectBorder(tx, ty, tabW, 24, 0.90, accentCol[1], accentCol[2], accentCol[3])
            self:drawTextCentre(tabLabel, tx + (tabW / 2), ty + 4, 1.0, 1.0, 1.0, 1.0, UIFont.Small)
        elseif isTabHover then
            self:drawRect(tx, ty, tabW, 24, 0.25, 0.3, 0.35, 0.4)
            self:drawRectBorder(tx, ty, tabW, 24, 0.60, 0.7, 0.75, 0.8)
            self:drawTextCentre(tabLabel, tx + (tabW / 2), ty + 4, 0.9, 0.95, 1.0, 1.0, UIFont.Small)
        else
            self:drawRect(tx, ty, tabW, 24, 0.15, 0.05, 0.06, 0.08)
            self:drawRectBorder(tx, ty, tabW, 24, 0.25, 0.3, 0.35, 0.4)
            self:drawTextCentre(tabLabel, tx + (tabW / 2), ty + 4, 0.65, 0.70, 0.75, 0.85, UIFont.Small)
        end
    end

    -- 3. Linha de Estatisticas & Chips de Tema (Linha 3, y: 64 a 82)
    local curSetCount, curSetTotal, curSetPct = TCG_BinderUI.getCollectionStatsForSet(self.binderItem, self.activeSet)
    local grandCount, grandTotal, grandPct = TCG_BinderUI.getGrandTotalStats(self.binderItem)
    local setDef = self:getActiveSetDef()
    local setNameFull = setDef and (isPT and setDef.name.pt or setDef.name.en) or self.activeSet

    local statsText = isPT and string.format("Aba: %s [%d/%d - %.1f%%]  |  Total no Fichario: %d/%d (%.1f%%)", setNameFull, curSetCount, curSetTotal, curSetPct, grandCount, grandTotal, grandPct)
                           or string.format("Tab: %s [%d/%d - %.1f%%]  |  Total in Binder: %d/%d (%.1f%%)", setNameFull, curSetCount, curSetTotal, curSetPct, grandCount, grandTotal, grandPct)
    self:drawText(statsText, 20, 66, 0.80, 0.85, 0.90, 1.0, UIFont.Small)

    -- Chips de Cor da Capa
    local colorLabel = isPT and "COR:" or "THEME:"
    self:drawText(colorLabel, self.width - 230, 66, 0.70, 0.75, 0.80, 1.0, UIFont.Small)
    for cIdx, cKey in ipairs(TCG_Theme.THEME_KEYS) do
        local cDef = TCG_Theme.THEMES[cKey]
        local chipX = (self.width - 180) + ((cIdx - 1) * 26)
        local chipY = 66
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

    -- Divisoria Superior das Paginas
    self:drawRect(16, 84, self.width - 32, 1, 0.20, 1, 1, 1)

    -- Divisoria Central do Fichario (Entre a folha esquerda e a folha direita)
    self:drawRect(math.floor(self.width / 2) - 1, 88, 2, 410, 0.25, 0.4, 0.4, 0.4)

    -- 4. Renderizacao dos 18 Slots
    local startNum = ((self.currentPage - 1) * SLOTS_PER_PAGE) + 1
    local slotW, slotH = 74, 104
    local totalInSet = self:getTotalCardsInActiveSet()

    for i = 0, 17 do
        local cardNum = startNum + i
        if cardNum <= totalInSet then
            local pageIdx = (i < 9) and 0 or 1
            local localIdx = (i < 9) and i or (i - 9)
            local col = localIdx % 3
            local row = math.floor(localIdx / 3)

            local baseX = (pageIdx == 0) and 40 or 440
            local sx = baseX + (col * (slotW + 36))
            local sy = 88 + (row * (slotH + 34))

            local cardId = self:getCardIdForSlot(cardNum)
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

    -- 5. Barra Inferior de Navegacao
    self:drawRect(16, 502, self.width - 32, 1, 0.20, 1, 1, 1)

    local totalPages = self:getTotalPagesInActiveSet()
    local prevLabel = isPT and "< ANTERIOR" or "< PREVIOUS"
    local isPrevHover = (mx >= 30 and mx <= 150 and my >= 508 and my <= 538)
    TCG_Theme.drawTacticalButton(self, prevLabel, 30, 508, 120, 26, isPrevHover and (self.currentPage > 1), (self.currentPage > 1) and TCG_Theme.CYAN or {0.3, 0.3, 0.3})

    local folhaLabel = isPT and "Folha" or "Page"
    local cartasLabel = isPT and "Cartas" or "Cards"
    local pageLabel = string.format("[%s] - %s %d de %d  (%s #%02d a #%02d)", setNameFull, folhaLabel, self.currentPage, totalPages, cartasLabel, startNum, math.min(totalInSet, startNum + SLOTS_PER_PAGE - 1))
    self:drawTextCentre(pageLabel, math.floor(self.width / 2), 512, 0.85, 0.90, 0.95, 1.0, UIFont.Small)

    local nextLabel = isPT and "PROXIMO >" or "NEXT >"
    local isNextHover = (mx >= (self.width - 160) and mx <= (self.width - 40) and my >= 508 and my <= 538)
    TCG_Theme.drawTacticalButton(self, nextLabel, self.width - 160, 508, 120, 26, isNextHover and (self.currentPage < totalPages), (self.currentPage < totalPages) and TCG_Theme.CYAN or {0.3, 0.3, 0.3})
end
