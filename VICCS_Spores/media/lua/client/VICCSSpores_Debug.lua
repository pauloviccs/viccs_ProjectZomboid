-- =============================================================================
-- VICCS Spores - Ferramentas de Teste e Inspecao (Client Debug)
-- Versao: 1.1.1 (Strict ASCII Compliance - Sem caracteres quebrados na JVM)
-- =============================================================================

require "VICCSSpores_Grid"

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
    if not isDebugEnabled() then return end
    if test then return true end
    
    local player = getSpecificPlayer(playerIndex)
    if not player then return end
    
    local sq = getClickedSquare(worldobjects, player)
    if not sq then return end
    
    local sx, sy, sz = sq:getX(), sq:getY(), sq:getZ()
    local currentConc = VICCSSpores.Grid.get(sx, sy, sz)
    local cx, cy = VICCSSpores.Grid.cellOf(sx, sy)
    
    local debugOption = context:addOption("[VICCS DEBUG] Esporos")
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(debugOption, subMenu)
    
    -- 1. Status da celula (Strict ASCII)
    local statusText = string.format("Info: Celula [%d,%d,z:%d] | Conc: %.1f", cx, cy, sz, currentConc)
    subMenu:addOption(statusText, nil, nil)
    
    -- 2. Criar nuvem (+50)
    subMenu:addOption("Criar Nuvem de Esporos (+50)", nil, function()
        if isClient() then
            sendClientCommand(player, "VICCSSpores", "debugAdd", { x = sx, y = sy, z = sz, amount = 50.0 })
        else
            VICCSSpores.Grid.add(sx, sy, sz, 50.0)
            if VICCSSpores.Net and VICCSSpores.Net.syncAirToPlayers then
                VICCSSpores.Net.syncAirToPlayers()
            end
        end
        player:Say(string.format("[VICCS] Nuvem +50 injetada na celula (%d,%d)!", cx, cy))
    end)
    
    -- 3. Limpar Esporos desta celula (-50)
    subMenu:addOption("Limpar Esporos desta Celula (-50)", nil, function()
        if isClient() then
            sendClientCommand(player, "VICCSSpores", "cleanArea", { x = sx, y = sy, z = sz, power = 50.0 })
        else
            VICCSSpores.Grid.clean(sx, sy, sz, 50.0)
            if VICCSSpores.Net and VICCSSpores.Net.syncAirToPlayers then
                VICCSSpores.Net.syncAirToPlayers()
            end
        end
        player:Say("[VICCS] Area descontaminada!")
    end)
    
    -- 4. Zerar Todos os Esporos
    subMenu:addOption("Zerar Todos os Esporos do Mapa", nil, function()
        if isClient() then
            sendClientCommand(player, "VICCSSpores", "debugClearAll", {})
        else
            local d = VICCSSpores.Grid.data()
            d.cells = {}
            if VICCSSpores.Net and VICCSSpores.Net.syncAirToPlayers then
                VICCSSpores.Net.syncAirToPlayers()
            end
        end
        player:Say("[VICCS] Todas as celulas de esporo foram limpas!")
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

print("[VICCS Spores v" .. VICCSSpores.VERSION .. "] Modulo de Debug v1.1.1 (Strict ASCII) pronto.")
