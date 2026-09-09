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

TCG_ContextMenu = TCG_ContextMenu or {}

function TCG_ContextMenu.onFillInventoryObjectContextMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    local boosterItem = nil
    local binderItem = nil
    local selectedCards = {}
    local seenCards = {}

    local function processItem(it)
        if not it or not instanceof(it, "InventoryItem") then return end
        local fullType = it:getFullType()
        if fullType == "Base.TCG_Card" or fullType == "TCG_Card" then
            if not seenCards[it] then
                seenCards[it] = true
                table.insert(selectedCards, it)
            end
        elseif (fullType == "Base.TCG_Booster_Base1" or fullType == "TCG_Booster_Base1") and not boosterItem then
            boosterItem = it
        elseif (fullType == "Base.TCG_Binder" or fullType == "TCG_Binder") and not binderItem then
            binderItem = it
        end
    end

    for _, itemOrTable in ipairs(items) do
        if instanceof(itemOrTable, "InventoryItem") then
            processItem(itemOrTable)
        elseif type(itemOrTable) == "table" and itemOrTable.items then
            -- No PZ, se o grupo contiver mais de 1 elemento, o indice 1 e o cabecalho representativo (header)
            -- e os indices de 2 em diante sao os itens reais da pilha.
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

    -- Opcao 1: Abrir Pacote de Cartas 1999
    if boosterItem then
        local label = isPT and "[TCG] Abrir Pacote de Cartas (1999)" or "[TCG] Open Booster Pack (1999)"
        local opt = context:addOption(label, playerObj, function()
            if playerObj:getVehicle() then
                playerObj:Say(isPT and "Nao posso abrir cartas dirigindo!" or "I can't open cards while driving!")
                return
            end
            ISTimedActionQueue.add(TCG_BoosterTimedAction:new(playerObj, boosterItem, 60))
        end)
        opt.iconTexture = getTexture("media/textures/tcg_booster_base1.png")
    end

    -- Opcao 2: Fichario de Colecionador (Abrir com Barra de Progresso & Renomear)
    if binderItem then
        local openLabel = isPT and "[TCG] Abrir Fichario de Colecionador" or "[TCG] Open Collector Binder"
        local optOpen = context:addOption(openLabel, playerObj, function()
            if playerObj:getVehicle() then
                playerObj:Say(isPT and "Nao posso abrir o fichario dirigindo!" or "I can't open the binder while driving!")
                return
            end
            ISTimedActionQueue.add(TCG_OpenBinderTimedAction:new(playerObj, binderItem, 40))
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
                        TCG_Theme.playAudio("UI_ButtonSelect")
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
                TCG_BinderUI.storeCardsList(targetBinder, selectedCards, playerObj)
            end)
            optStore.iconTexture = getTexture("media/textures/tcg_binder.png")
        else
            -- Multiplos ficharios encontrados: cria submenu organizado
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
                local count, _ = TCG_BinderUI.getCollectionStatsForItem(bIt)
                local subLabel = string.format("%s (%d/102)", bName, count)
                local optSub = subMenu:addOption(subLabel, playerObj, function()
                    TCG_BinderUI.storeCardsList(bIt, selectedCards, playerObj)
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
end

Events.OnFillInventoryObjectContextMenu.Add(TCG_ContextMenu.onFillInventoryObjectContextMenu)
