-- =============================================================================
-- Project Zomboid TCG - Inventory Context Menu (TCG_ContextMenu.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Menu de contexto com integracao fluida para:
--   1. Abrir Pacote de Cartas (ISOpenBoosterAction via TimedAction)
--   2. Abrir Fichario de Colecionador (TCG_BinderUI)
--   3. Inspecionar Carta Colecionavel (TCG_CardInspectModal com fisica 3D)
-- =============================================================================

require "TCG_Config"
require "TCG_CardRegistry"
require "TCG_BinderUI"
require "TCG_BoosterTimedAction"
require "TCG_CardInspectModal"

TCG_ContextMenu = TCG_ContextMenu or {}

function TCG_ContextMenu.onFillInventoryObjectContextMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    local boosterItem = nil
    local binderItem = nil
    local cardItem = nil

    for _, itemOrTable in ipairs(items) do
        local item = itemOrTable
        if not instanceof(item, "InventoryItem") and type(itemOrTable) == "table" and itemOrTable.items then
            item = itemOrTable.items[1]
        end

        if item and instanceof(item, "InventoryItem") then
            local fullType = item:getFullType()
            if fullType == "Base.TCG_Booster_Base1" or fullType == "TCG_Booster_Base1" then
                boosterItem = item
            elseif fullType == "Base.TCG_Binder" or fullType == "TCG_Binder" then
                binderItem = item
            elseif fullType == "Base.TCG_Card" or fullType == "TCG_Card" then
                cardItem = item
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

    -- Opcao 2: Abrir Fichario de Colecionador
    if binderItem then
        local label = isPT and "[TCG] Abrir Fichario de Colecionador" or "[TCG] Open Collector Binder"
        local opt = context:addOption(label, playerObj, function()
            TCG_BinderUI.open(binderItem)
        end)
        opt.iconTexture = getTexture("media/textures/tcg_binder.png")
    end

    -- Opcao 3: Inspecionar Carta (Abre o Modal 3D)
    if cardItem then
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
