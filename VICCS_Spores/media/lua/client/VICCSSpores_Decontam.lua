-- =============================================================================
-- VICCS Spores - Menu de Contexto de Descontaminacao (Client)
-- Versao: 1.0.5 (Hotfix: Extracao resiliente de square a partir de worldobjects)
-- =============================================================================

require "VICCSSpores_Grid"
require "TimedActions/ISDecontaminateAction"

local function findBleachItem(player)
    local inv = player:getInventory()
    if not inv then return nil end
    
    local item = inv:getFirstTypeRecurse("Base.Bleach")
    if not item then
        item = inv:getFirstTypeRecurse("Base.GardeningSprayBleach")
    end
    
    -- Valida se o item tem liquido/doses restantes
    if item then
        if item:IsDrainable() and item:getCurrentUsesFloat() <= 0 then
            return nil
        end
        return item
    end
    
    return nil
end

local function getClickedSquare(worldobjects, player)
    if worldobjects then
        for _, obj in ipairs(worldobjects) do
            if obj and obj:getSquare() then
                return obj:getSquare()
            end
        end
    end
    return player and player:getCurrentSquare()
end

local function onFillWorldObjectContextMenu(playerIndex, context, worldobjects, test)
    if test then return true end
    
    local player = getSpecificPlayer(playerIndex)
    if not player then return end
    
    local sq = getClickedSquare(worldobjects, player)
    if not sq then return end
    
    local sx, sy, sz = sq:getX(), sq:getY(), sq:getZ()
    local conc = VICCSSpores.Grid.get(sx, sy, sz)
    
    if conc >= 1.0 then
        local bleachItem = findBleachItem(player)
        
        if bleachItem then
            local option = context:addOption(getText("UI_ContextMenu_VICCS_Decontaminate"), worldobjects, function()
                if luautils.walkAdj(player, sq) then
                    ISTimedActionQueue.add(ISDecontaminateAction:new(player, sq, bleachItem, 120))
                end
            end)
            option.toolTip = ISToolTip:new()
            option.toolTip:initialise()
            option.toolTip.description = getText("UI_VICCS_Action_Decontaminating")
        else
            local option = context:addOption(getText("UI_ContextMenu_VICCS_Decontaminate_NoBleach"), nil, nil)
            option.notAvailable = true
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

print("[VICCS Spores v" .. VICCSSpores.VERSION .. "] Contexto de Descontaminacao v1.0.5 ativo.")
