-- =============================================================================
-- Project Zomboid TCG - Server Command Handlers (TCG_ServerCommands.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Servidor de autoridade para o VICCS Trading Card Game (Build 42 MP).
--   Processa requisicoes de clientes, gerencia geracao e destruicao autoritativa
--   de itens no inventario do servidor, e sincroniza via pacotes nativos:
--   - sendAddItemToContainer
--   - sendRemoveItemFromContainer
--   - sendItemStats
--   - sendServerCommand
-- =============================================================================

if isClient() then return end

require "TCG_Config"
require "TCG_CardRegistry"
require "TCG_DropTables"
require "TCG_BinderData"

local Commands = {}

--- 1. openBooster: Consome o booster e gera as 10 cartas autoritativas no servidor
Commands.openBooster = function(player, args)
    if not player or not args then return end
    local boosterID = args.boosterID
    local setId = args.setId or "base1"

    local boosterItem, container = TCG_BinderData.findItemRecursive(player:getInventory(), boosterID)
    if not boosterItem then
        print("[TCG SERVER ERROR] openBooster: Booster ID " .. tostring(boosterID) .. " nao encontrado no inventario do jogador.")
        return
    end

    -- Remove o booster no servidor de forma autoritativa
    local boosterContainer = container or player:getInventory()
    if sendRemoveItemFromContainer then
        pcall(function() sendRemoveItemFromContainer(boosterContainer, boosterItem) end)
    end
    boosterContainer:Remove(boosterItem)

    -- Rola as 10 cartas usando as tabelas de drop
    local pulled = TCG_DropTables.openBooster(setId)
    local setDef = TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[setId]
    local totalInSet = setDef and setDef.total or 102
    local inv = player:getInventory()
    local spawnedCardIDs = {}
    local networkPulled = {}

    for _, itemData in ipairs(pulled) do
        local card = itemData.card
        local cardItem = inv:AddItem("Base.TCG_Card")
        if cardItem then
            local md = cardItem:getModData()
            local nameEN = (type(card.name) == "table") and card.name.en or card.name
            local namePT = (type(card.name) == "table") and card.name.pt or card.name
            local displayName = namePT or nameEN

            md.cardId = card.id
            md.setId = setId
            md.cardNumber = card.number
            md.totalInSet = totalInSet
            md.name_en = nameEN
            md.name_pt = namePT
            md.cardName = displayName
            md.rarity = TCG_CardRegistry.getCardRarity(card)
            md.isHolo = itemData.isHolo
            md.condition = itemData.condition or 100

            local prefix = itemData.isHolo and "* Carta TCG (Holo): " or "Carta TCG: "
            cardItem:setName(string.format("%s%s [#%02d/%d]", prefix, displayName, card.number, totalInSet))

            if sendAddItemToContainer then
                pcall(function() sendAddItemToContainer(inv, cardItem) end)
            end
            if sendItemStats then
                pcall(function() sendItemStats(cardItem) end)
            end

            table.insert(spawnedCardIDs, cardItem:getID())
            table.insert(networkPulled, {
                cardId = card.id,
                isHolo = itemData.isHolo,
                condition = itemData.condition or 100,
                itemId = cardItem:getID()
            })
        end
    end

    -- Notifica o cliente autoritativamente com os IDs reais do servidor
    if sendServerCommand then
        sendServerCommand(player, "TCG", "boosterOpened", {
            pulled = networkPulled,
            cardIDs = spawnedCardIDs,
            setId = setId,
            skipModal = (args.skipModal == true),
            batchIndex = args.batchIndex,
            batchTotal = args.batchTotal
        })
    end
end

--- 2. storeCards: Armazena cartas no fichario e remove os itens fisicos no servidor
-- Suporta 'Auto-Heal' para limpar cartas fantasmas remanescentes de versoes anteriores
Commands.storeCards = function(player, args)
    if not player or not args or not args.binderID then return end
    local binderItem = TCG_BinderData.findItemRecursive(player:getInventory(), args.binderID)
    if not binderItem then
        print("[TCG SERVER ERROR] storeCards: Fichario ID " .. tostring(args.binderID) .. " nao encontrado.")
        return
    end

    local bData = TCG_BinderData.getBinderDataFromItem(binderItem)
    local cardsToStore = args.cards or {}
    local storedCount = 0
    local phantomItemIDs = {}

    for _, cInfo in ipairs(cardsToStore) do
        local cid = cInfo.cardId
        if cid then
            -- Armazena no ModData do fichario
            if not bData.collected[cid] then
                bData.collected[cid] = {
                    number = cInfo.cardNumber or 1,
                    isHolo = (cInfo.isHolo == true),
                    count = 1
                }
            else
                bData.collected[cid].count = (bData.collected[cid].count or 1) + 1
                if cInfo.isHolo then
                    bData.collected[cid].isHolo = true
                end
            end
            storedCount = storedCount + 1

            -- Remove o item fisico do inventario do servidor se existir
            local physicalCard, cardContainer = TCG_BinderData.findItemRecursive(player:getInventory(), cInfo.itemID)
            if physicalCard and cardContainer then
                if sendRemoveItemFromContainer then
                    pcall(function() sendRemoveItemFromContainer(cardContainer, physicalCard) end)
                end
                cardContainer:Remove(physicalCard)
            else
                -- Caso o item fisico nao exista no servidor (carta fantasma de versao antiga do cliente),
                -- sinaliza para o cliente purgar da sua memoria local.
                table.insert(phantomItemIDs, cInfo.itemID)
            end
        end
    end

    -- Sincroniza o fichario atualizado
    if sendItemStats then
        pcall(function() sendItemStats(binderItem) end)
    end

    if sendServerCommand then
        sendServerCommand(player, "TCG", "cardsStored", {
            binderID = args.binderID,
            count = storedCount,
            phantomItemIDs = phantomItemIDs
        })
    end
end

--- 3. withdrawCard: Retira cartas do fichario e adiciona ao inventario autoritativo
Commands.withdrawCard = function(player, args)
    if not player or not args or not args.binderID or not args.cardId then return end
    local binderItem = TCG_BinderData.findItemRecursive(player:getInventory(), args.binderID)
    if not binderItem then
        print("[TCG SERVER ERROR] withdrawCard: Fichario ID " .. tostring(args.binderID) .. " nao encontrado.")
        return
    end

    local bData = TCG_BinderData.getBinderDataFromItem(binderItem)
    local cardId = args.cardId
    local colInfo = bData.collected[cardId]
    if not colInfo or not colInfo.count or colInfo.count < 1 then
        print("[TCG SERVER WARN] withdrawCard: Carta " .. tostring(cardId) .. " nao disponivel no fichario.")
        return
    end

    local requestedAmount = tonumber(args.amount) or 1
    local amount = math.min(requestedAmount, colInfo.count)
    if amount <= 0 then return end

    local cardDef = TCG_CardRegistry.getCard(cardId)
    local num = (cardDef and cardDef.number) or colInfo.number or 1
    local setId = (cardDef and cardDef.setId) or (cardId:match("^([^-]+)%-")) or bData.activeSet or "base1"
    local setDef = TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[setId]
    local setTotal = setDef and setDef.total or 102
    local nameEN = (cardDef and type(cardDef.name) == "table") and cardDef.name.en or (cardDef and cardDef.name or "Card")
    local namePT = (cardDef and type(cardDef.name) == "table") and cardDef.name.pt or (cardDef and cardDef.name or "Carta")
    local displayName = namePT or nameEN

    local inv = player:getInventory()
    local spawnedIDs = {}

    for _ = 1, amount do
        local cardItem = inv:AddItem("Base.TCG_Card")
        if cardItem then
            local md = cardItem:getModData()
            md.cardId = cardId
            md.setId = setId
            md.cardNumber = num
            md.totalInSet = setTotal
            md.name_en = nameEN
            md.name_pt = namePT
            md.cardName = displayName
            md.rarity = TCG_CardRegistry.getCardRarity(cardDef)
            md.isHolo = colInfo.isHolo
            md.condition = 100

            local prefix = colInfo.isHolo and "* Carta TCG (Holo): " or "Carta TCG: "
            cardItem:setName(string.format("%s%s [#%02d/%d]", prefix, displayName, num, setTotal))

            if sendAddItemToContainer then
                pcall(function() sendAddItemToContainer(inv, cardItem) end)
            end
            if sendItemStats then
                pcall(function() sendItemStats(cardItem) end)
            end
            table.insert(spawnedIDs, cardItem:getID())
        end
    end

    colInfo.count = colInfo.count - amount
    if colInfo.count <= 0 then
        bData.collected[cardId] = nil
    end

    if sendItemStats then
        pcall(function() sendItemStats(binderItem) end)
    end

    if sendServerCommand then
        sendServerCommand(player, "TCG", "cardWithdrawn", {
            binderID = args.binderID,
            cardId = cardId,
            amount = amount,
            num = num,
            displayName = displayName,
            spawnedIDs = spawnedIDs
        })
    end
end

--- 4. updateBinder: Atualiza metadados do fichario (Nome, Capa, Badge, Aba)
Commands.updateBinder = function(player, args)
    if not player or not args or not args.binderID then return end
    local binderItem = TCG_BinderData.findItemRecursive(player:getInventory(), args.binderID)
    if not binderItem then return end

    local bData = TCG_BinderData.getBinderDataFromItem(binderItem)
    local changed = false

    if args.customName ~= nil then
        bData.customName = tostring(args.customName)
        if bData.customName ~= "" then
            binderItem:setName(string.format("Fichario TCG: %s", bData.customName))
        else
            binderItem:setName("Fichario TCG")
        end
        changed = true
    end

    if args.themeColor ~= nil then
        bData.themeColor = args.themeColor
        changed = true
    end

    if args.badge ~= nil then
        bData.badge = args.badge
        changed = true
    end

    if args.activeSet ~= nil then
        bData.activeSet = args.activeSet
        changed = true
    end

    if changed and sendItemStats then
        pcall(function() sendItemStats(binderItem) end)
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= "TCG" then return end
    if Commands[command] then
        Commands[command](player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
