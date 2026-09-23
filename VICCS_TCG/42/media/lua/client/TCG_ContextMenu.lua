-- =============================================================================
-- Project Zomboid TCG - Inventory Context Menu (TCG_ContextMenu.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Menu de contexto integrado para:
--   1. Abrir Pacote de Cartas (ISOpenBoosterAction via TimedAction)
--   2. Abrir Fichario de Colecionador (TCG_BinderUI)
--   3. Renomear Fichario de Colecionador diretamente pelo inventario
--   4. Guardar Carta(s) no Fichario (1 clique direto, com suporte a multi-selecao e submenus)
--   5. Inspecionar Carta Colecionavel (TCG_CardInspectModal com fisica 3D)
-- =============================================================================

require "TCG_Config"
require "TCG_CardRegistry"
require "TCG_BinderUI"
require "TCG_BoosterTimedAction"
require "TCG_OpenBinderTimedAction"
require "TCG_CardInspectModal"
require "TCG_StoreCardsTimedAction"
require "TimedActions/ISInventoryTransferAction"

TCG_ContextMenu = TCG_ContextMenu or {}

--- Garante que um item dentro de mochilas/bolsas seja transferido para a mao/inventario principal
local function ensureItemInInventory(playerObj, item)
    if not playerObj or not item then return end
    local itemContainer = item:getContainer()
    local playerInv = playerObj:getInventory()
    if itemContainer and itemContainer ~= playerInv then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, itemContainer, playerInv))
    end
end

--- Busca recursiva de todos os pacotes de cartas de determinado tipo no inventario e mochilas
function TCG_ContextMenu.findAllPlayerBoosters(playerObj, bType)
    if not playerObj or not bType then return {} end
    local inv = playerObj:getInventory()
    if not inv then return {} end

    local cleanType = bType:gsub("^Base%.", "")
    local boosters = {}
    local function scan(container)
        if not container then return end
        local items = container:getItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                local ft = (it:getFullType() or ""):gsub("^Base%.", "")
                if ft == cleanType then
                    table.insert(boosters, it)
                end
                if it.IsInventoryContainer and it:IsInventoryContainer() and it.getItemContainer and it:getItemContainer() then
                    scan(it:getItemContainer())
                end
            end
        end
    end

    scan(inv)
    return boosters
end

TCG_ContextMenu.currentBatch = nil

--- Chamado quando o jogador conclui a janela de revelacao de um pacote em lote
function TCG_ContextMenu.onBatchPackFinished()
    local batch = TCG_ContextMenu.currentBatch
    if not batch then return end

    local player = batch.player or getPlayer()
    if not player or player:isDead() or player:getVehicle() then
        TCG_ContextMenu.currentBatch = nil
        return
    end

    if batch.openedCount >= batch.targetCount then
        -- Lote de 10 pacotes completamente finalizado!
        local totalDone = batch.targetCount
        TCG_ContextMenu.currentBatch = nil
        if player.setHaloNote then
            local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
            local msg = isPT and string.format("[TCG] Todos os %d pacotes foram abertos com sucesso!", totalDone)
                             or string.format("[TCG] All %d booster packs opened successfully!", totalDone)
            pcall(function() player:setHaloNote(msg, 90, 220, 140, 250) end)
        end
        return
    end

    -- Avanca para o proximo pacote do lote
    batch.openedCount = batch.openedCount + 1
    local remainingPacks = TCG_ContextMenu.findAllPlayerBoosters(player, batch.boosterType)
    if not remainingPacks or #remainingPacks == 0 then
        -- Se os pacotes acabaram antes de completar a meta
        local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
        if player.setHaloNote then
            local msg = isPT and string.format("[TCG] Pacotes esgotados! (%d/%d abertos)", batch.openedCount - 1, batch.targetCount)
                             or string.format("[TCG] Out of packs! (%d/%d opened)", batch.openedCount - 1, batch.targetCount)
            pcall(function() player:setHaloNote(msg, 240, 200, 80, 250) end)
        end
        TCG_ContextMenu.currentBatch = nil
        return
    end

    local nextPack = remainingPacks[1]
    ensureItemInInventory(player, nextPack)
    ISTimedActionQueue.add(TCG_BoosterTimedAction:new(player, nextPack, 60, false, batch.openedCount, batch.targetCount))
end

function TCG_ContextMenu.onFillInventoryObjectContextMenu(playerNum, context, items)
    local ok, err = pcall(function()
        local playerObj = getSpecificPlayer(playerNum)
        if not playerObj then return end

        local boosterItem = nil
        local binderItem = nil
        local selectedCards = {}
        local seenCards = {}

        local function processItem(it)
            if not it or not instanceof(it, "InventoryItem") then return end
            local fullType = it:getFullType() or ""
            if fullType == "Base.TCG_Card" or fullType == "TCG_Card" then
                if not seenCards[it] then
                    seenCards[it] = true
                    table.insert(selectedCards, it)
                end
            elseif fullType:find("TCG_Booster") and not boosterItem then
                boosterItem = it
            elseif (fullType == "Base.TCG_Binder" or fullType == "TCG_Binder") and not binderItem then
                binderItem = it
            end
        end

        for _, itemOrTable in ipairs(items) do
            if instanceof(itemOrTable, "InventoryItem") then
                processItem(itemOrTable)
            elseif type(itemOrTable) == "table" and itemOrTable.items then
                local list = itemOrTable.items
                if #list > 1 then
                    for i = 2, #list do
                        processItem(list[i])
                    end
                elseif #list == 1 then
                    processItem(list[1])
                end
            end
        end

        local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")

        -- Opcao 1: Abrir Pacote de Cartas (Dinamico para qualquer colecao)
        if boosterItem then
            local bType = boosterItem:getFullType() or ""
            local iconPath = "media/textures/tcg_booster_base1.png"
            local bTitle = isPT and "Pacote de Cartas (1999)" or "Booster Pack (1999)"

            if bType:find("Jungle") then
                iconPath = "media/textures/tcg_booster_jungle.png"
                bTitle = isPT and "Pacote Jungle (1999)" or "Jungle Booster Pack (1999)"
            elseif bType:find("Fossil") then
                iconPath = "media/textures/tcg_booster_fossil.png"
                bTitle = isPT and "Pacote Fossil (1999)" or "Fossil Booster Pack (1999)"
            elseif bType:find("TeamRocket") or bType:find("Rocket") then
                iconPath = "media/textures/tcg_booster_teamrocket.png"
                bTitle = isPT and "Pacote Equipe Rocket (2000)" or "Team Rocket Booster Pack (2000)"
            elseif bType:find("Eevee") then
                iconPath = "media/textures/tcg_booster_eeveeheroes.png"
                bTitle = isPT and "Pacote Eevee Heroes (Japao 2021)" or "Eevee Heroes Booster Pack (Japan 2021)"
            end

            -- 1.1 Abrir Pacote Individual (Com auto-transfer de mochilas)
            local label = string.format(isPT and "[TCG] Abrir %s" or "[TCG] Open %s", bTitle)
            local opt = context:addOption(label, playerObj, function()
                if playerObj:getVehicle() then
                    playerObj:Say(isPT and "Nao posso abrir cartas dirigindo!" or "I can't open cards while driving!")
                    return
                end
                ensureItemInInventory(playerObj, boosterItem)
                ISTimedActionQueue.add(TCG_BoosterTimedAction:new(playerObj, boosterItem, 60))
            end)
            opt.iconTexture = getTexture(iconPath)

            -- 1.2 Abrir 10 Pacotes em Sequencia (Tempo individual x10, animacao contínua)
            local allMatching = TCG_ContextMenu.findAllPlayerBoosters(playerObj, bType)
            local totalMatching = #allMatching

            if totalMatching >= 10 then
                local label10 = string.format(isPT and "[TCG] Abrir 10 Pacotes (%s)" or "[TCG] Open 10 Packs (%s)", bTitle)
                local opt10 = context:addOption(label10, playerObj, function()
                    if playerObj:getVehicle() then
                        playerObj:Say(isPT and "Nao posso abrir cartas dirigindo!" or "I can't open cards while driving!")
                        return
                    end
                    local freshPacks = TCG_ContextMenu.findAllPlayerBoosters(playerObj, bType)
                    if not freshPacks or #freshPacks == 0 then return end
                    local countToOpen = math.min(10, #freshPacks)

                    TCG_ContextMenu.currentBatch = {
                        player = playerObj,
                        boosterType = bType,
                        targetCount = countToOpen,
                        openedCount = 1
                    }

                    local firstPack = freshPacks[1]
                    ensureItemInInventory(playerObj, firstPack)
                    ISTimedActionQueue.add(TCG_BoosterTimedAction:new(playerObj, firstPack, 60, false, 1, countToOpen))
                end)
                opt10.iconTexture = getTexture(iconPath)
            elseif totalMatching >= 2 and totalMatching < 10 then
                local label10 = string.format(isPT and "[TCG] Abrir 10 Pacotes (%d/10)" or "[TCG] Open 10 Packs (%d/10)", totalMatching)
                local opt10 = context:addOption(label10, playerObj, nil)
                opt10.notAvailable = true
                opt10.iconTexture = getTexture(iconPath)
            end
        end

        -- Opcao 2: Fichario de Colecionador (Abrir com Barra de Progresso & Renomear)
        if binderItem then
            local openLabel = isPT and "[TCG] Abrir Fichario de Colecionador" or "[TCG] Open Collector Binder"
            local optOpen = context:addOption(openLabel, playerObj, function()
                if playerObj:getVehicle() then
                    playerObj:Say(isPT and "Nao posso abrir o fichario dirigindo!" or "I can't open the binder while driving!")
                    return
                end
                ensureItemInInventory(playerObj, binderItem)
                ISTimedActionQueue.add(TCG_OpenBinderTimedAction:new(playerObj, binderItem, 50))
            end)
            optOpen.iconTexture = getTexture("media/textures/tcg_binder.png")

            local renameLabel = isPT and "[TCG] Renomear Fichario" or "[TCG] Rename Binder"
            local optRename = context:addOption(renameLabel, playerObj, function()
                local bData = TCG_BinderUI.getBinderDataFromItem(binderItem)
                local curName = bData.customName or ""
                local title = isPT and "Renomear Fichario TCG:" or "Rename TCG Binder:"
                local modal = ISTextBox:new(0, 0, 280, 160, title, curName, nil, function(target, button)
                    if button.internal == "OK" then
                        local entry = (button.parent and button.parent.entry) or (button.target and button.target.entry)
                        local text = entry and entry:getText()
                        if text then
                            bData.customName = tostring(text)
                            local baseLabel = isPT and "Fichario TCG" or "TCG Binder"
                            if text ~= "" then
                                binderItem:setName(string.format("%s: %s", baseLabel, text))
                            else
                                binderItem:setName(baseLabel)
                            end

                            if isClient() then
                                sendClientCommand(playerObj, "TCG", "updateBinder", {
                                    binderID = binderItem:getID(),
                                    customName = text
                                })
                            end
                            TCG_Theme.playButtonClick()
                        end
                    end
                end, playerNum)
                modal:initialise()
                modal:addToUIManager()
            end)
            optRename.iconTexture = getTexture("media/textures/tcg_binder.png")
        end

        -- Opcao 3: Guardar Cartas Direto no Fichario (Sem ter que abrir o fichario)
        if #selectedCards > 0 then
            local binders = TCG_BinderUI.findPlayerBinders(playerObj)
            if #binders == 0 then
                local optNone = context:addOption(isPT and "[TCG] Guardar no Fichario (Sem Fichario)" or "[TCG] Store in Binder (No Binder)")
                optNone.notAvailable = true
                local tooltip = ISToolTip:new()
                tooltip:initialise()
                tooltip:setVisible(false)
                tooltip.description = isPT and "Voce precisa ter um Fichario de Colecionador no inventario ou mochila para guardar cartas."
                                           or "You need a Collector Binder in your inventory or backpack to store cards."
                optNone.toolTip = tooltip
            elseif #binders == 1 then
                local targetBinder = binders[1]
                local bData = TCG_BinderUI.getBinderDataFromItem(targetBinder)
                local bName = (bData.customName and bData.customName ~= "") and bData.customName or (isPT and "Fichario" or "Binder")
                local label = ""
                if #selectedCards == 1 then
                    label = isPT and string.format("[TCG] Guardar no %s", bName)
                                 or string.format("[TCG] Store in %s", bName)
                else
                    label = isPT and string.format("[TCG] Guardar %d Cartas no %s", #selectedCards, bName)
                                 or string.format("[TCG] Store %d Cards in %s", #selectedCards, bName)
                end
                local optStore = context:addOption(label, playerObj, function()
                    ensureItemInInventory(playerObj, targetBinder)
                    ISTimedActionQueue.add(TCG_StoreCardsTimedAction:new(playerObj, targetBinder, selectedCards))
                end)
                optStore.iconTexture = getTexture("media/textures/tcg_binder.png")
            else
                local rootLabel = (#selectedCards == 1)
                                    and (isPT and "[TCG] Guardar Carta no Fichario" or "[TCG] Store Card in Binder")
                                    or (isPT and string.format("[TCG] Guardar %d Cartas no Fichario", #selectedCards) or string.format("[TCG] Store %d Cards in Binder", #selectedCards))
                local optRoot = context:addOption(rootLabel)
                optRoot.iconTexture = getTexture("media/textures/tcg_binder.png")
                local subMenu = context:getNew(context)
                context:addSubMenu(optRoot, subMenu)

                for _, bIt in ipairs(binders) do
                    local bData = TCG_BinderUI.getBinderDataFromItem(bIt)
                    local bName = (bData.customName and bData.customName ~= "") and bData.customName or (isPT and "Fichario" or "Binder")
                    local count, total = TCG_BinderUI.getGrandTotalStats(bIt)
                    local subLabel = string.format("%s (%d/%d)", bName, count, total)
                    local optSub = subMenu:addOption(subLabel, playerObj, function()
                        ensureItemInInventory(playerObj, bIt)
                        ISTimedActionQueue.add(TCG_StoreCardsTimedAction:new(playerObj, bIt, selectedCards))
                    end)
                    optSub.iconTexture = getTexture("media/textures/tcg_binder.png")
                end
            end
        end

        -- Opcao 4: Inspecionar Carta (Apenas quando exatamente 1 carta for selecionada)
        if #selectedCards == 1 then
            local cardItem = selectedCards[1]
            local cardDef, isHolo = TCG_CardRegistry.getCardFromItem(cardItem)
            local cardName = TCG_CardRegistry.getCardName(cardDef)
            local num = (cardDef and cardDef.number) or 0
            local nameStr = tostring(cardName or "Carta")

            local inspectLabel = isPT and string.format("[TCG] Inspecionar Carta: #%02d %s", num, nameStr)
                                      or string.format("[TCG] Inspect Card: #%02d %s", num, nameStr)
            local opt = context:addOption(inspectLabel, playerObj, function()
                TCG_CardInspectModal.show(cardItem)
            end)
            opt.iconTexture = getTexture("media/textures/tcg_card.png")
        end
    end)
    if not ok then
        print("[TCG ERROR] onFillInventoryObjectContextMenu: " .. tostring(err))
    end
end

Events.OnFillInventoryObjectContextMenu.Add(TCG_ContextMenu.onFillInventoryObjectContextMenu)
