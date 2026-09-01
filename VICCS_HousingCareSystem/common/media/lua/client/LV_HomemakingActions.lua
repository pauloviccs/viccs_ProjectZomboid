-- =============================================================================
-- Housing Care System (Lar Vivo) - Homemaking & Active Habitation Engine (LV_HomemakingActions.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Escuta de forma 100% segura o encerramento de ações no ISTimedActionQueue
--   (Limpeza, Culinária, Jardinagem, Construção e Decoração).
--   Não modifica perform() de subclasses individuais, eliminando qualquer risco
--   de quebra na pilha Kahlua/Java e garantindo compatibilidade total com NeatUI,
--   CleanUI, Item Arrange e qualquer outro mod de interface/inventário.
-- =============================================================================

require "TimedActions/ISTimedActionQueue"

LV_HomemakingActions = LV_HomemakingActions or {}

--- Categorias de Tarefas Domésticas e seus pesos padrão
local CATEGORIES = {
    Cleaning = {
        name = "Cleaning",
        defaultPercent = 15,
        cooldownSeconds = 40,
        haloKey = "UI_LV_Halo_Cleaning",
        defaultHalo = "+15% Duração do Lar (Limpeza)"
    },
    Cooking = {
        name = "Cooking",
        defaultPercent = 20,
        cooldownSeconds = 90,
        haloKey = "UI_LV_Halo_Cooking",
        defaultHalo = "+20% Duração do Lar (Culinária)"
    },
    Farming = {
        name = "Farming",
        defaultPercent = 15,
        cooldownSeconds = 30,
        haloKey = "UI_LV_Halo_Farming",
        defaultHalo = "+15% Duração do Lar (Jardinagem)"
    },
    Building = {
        name = "Building",
        defaultPercent = 25,
        cooldownSeconds = 60,
        haloKey = "UI_LV_Halo_Building",
        defaultHalo = "+25% Duração do Lar (Construção)"
    },
    Decorating = {
        name = "Decorating",
        defaultPercent = 15,
        cooldownSeconds = 120,
        haloKey = "UI_LV_Halo_Decorating",
        defaultHalo = "+15% Duração do Lar (Decoração)"
    }
}

--- Mapeamento direto de tipos de TimedAction para suas categorias
local ACTION_TYPE_MAP = {
    -- 1. Limpeza
    ["ISCleanBloodAction"] = { category = "Cleaning", percent = 15 },
    ["ISCleanGraffitiAction"] = { category = "Cleaning", percent = 15 },
    ["ISTakeTrashAction"] = { category = "Cleaning", percent = 15 },

    -- 2. Culinária
    ["ISCookAction"] = { category = "Cooking", percent = 20 },
    ["ISCraftAction"] = { category = "Cooking", percent = 20 },

    -- 3. Jardinagem
    ["ISWaterPlantAction"] = { category = "Farming", percent = 15 },
    ["ISFertilizeAction"] = { category = "Farming", percent = 15 },
    ["ISHarvestPlantAction"] = { category = "Farming", percent = 20 },
    ["ISPlantAction"] = { category = "Farming", percent = 15 },
    ["ISSeedAction"] = { category = "Farming", percent = 15 },
    ["ISCureFliesAction"] = { category = "Farming", percent = 15 },
    ["ISCureMildewAction"] = { category = "Farming", percent = 15 },

    -- 4. Construção & Carpintaria
    ["ISBuildAction"] = { category = "Building", percent = 25 },
    ["ISPaintAction"] = { category = "Building", percent = 20 },
    ["ISPlasterAction"] = { category = "Building", percent = 20 },
    ["ISBarricadeAction"] = { category = "Building", percent = 15 },

    -- 5. Decoração & Arranjo
    ["ISMoveablesAction"] = { category = "Decorating", percent = 15 },
    ["ISPlace3DItemAction"] = { category = "Decorating", percent = 15 },
}

--- Rastreamento de tempo real para cooldowns anti-spam
local lastActionTimestamps = {}

local function getSystemSeconds()
    if getTimeInMillis then
        return getTimeInMillis() / 1000.0
    end
    return getGameTime():getWorldAgeHours() * 3600.0
end

--- Verifica se o personagem está em uma área de base ou abrigo válida.
local function isCharacterInValidHomeArea(character)
    if not character then return false end

    -- 1. Verifica estado do BuffManager (se já reconheceu o abrigo)
    if LV_BuffManager and LV_BuffManager.getPlayerData then
        local data = LV_BuffManager.getPlayerData(character)
        if data and (data.isInShelter or (data.comfortScore and data.comfortScore > 0)) then
            return true
        end
    end

    -- 2. Verifica se o azulejo atual é interior (Room) ou possui teto
    local sq = character:getCurrentSquare()
    if sq then
        if sq:getRoom() ~= nil or sq:isInARoom() or sq:haveRoof() then
            return true
        end
    end

    -- 3. Verifica Safehouse oficial se aplicável
    if Safehouse and Safehouse.isSafeHouse and sq then
        local sh = Safehouse.getSafeHouse(sq)
        if sh then return true end
    end

    return false
end

--- Processa a conclusão de uma ação doméstica
function LV_HomemakingActions.handleActionCompleted(action)
    if not action or not action.character or not LV_Config or not LV_Config.isHomemakingEnabled() then
        return
    end

    local character = action.character
    local localPlayer = getPlayer()
    if character ~= localPlayer then
        return
    end

    local actionType = action.Type
    if not actionType then
        return
    end

    local mapped = ACTION_TYPE_MAP[actionType]
    if not mapped then
        return
    end

    local categoryName = mapped.category
    local bonusPercent = mapped.percent

    -- Tratamento especial para ISCraftAction (distinguir culinária de carpintaria)
    if actionType == "ISCraftAction" and action.recipe then
        local rName = tostring(action.recipe:getName() or ""):lower()
        local rCat = tostring(action.recipe:getCategory() or ""):lower()
        if rCat:find("cook") or rCat:find("food") or rName:find("salad") or rName:find("soup") or rName:find("sandwich") or rName:find("cook") then
            categoryName = "Cooking"
            bonusPercent = 20
        elseif rCat:find("carpentry") or rCat:find("build") or rName:find("plank") or rName:find("door") then
            categoryName = "Building"
            bonusPercent = 20
        else
            return
        end
    end

    -- Tratamento especial para ISMoveablesAction (apenas pontua colocar/mover)
    if actionType == "ISMoveablesAction" and action.mode then
        if action.mode ~= "place" and action.mode ~= "rotate" and action.mode ~= "pickup" then
            return
        end
    end

    local catDef = CATEGORIES[categoryName]
    if not catDef then
        return
    end

    -- Validação de abrigo/base
    if not isCharacterInValidHomeArea(character) then
        return
    end

    -- Cooldown Anti-Spam
    local now = getSystemSeconds()
    local configuredCd = (LV_Config and LV_Config.get and LV_Config.get("HomemakingCooldownSeconds")) or catDef.cooldownSeconds
    local lastTime = lastActionTimestamps[categoryName] or 0

    if (now - lastTime) < configuredCd then
        return
    end
    lastActionTimestamps[categoryName] = now

    -- Concede o bônus no BuffManager
    local addedHours = LV_BuffManager.addHomemakingBonus(character, categoryName, bonusPercent)

    if addedHours and addedHours > 0 then
        local haloText = LV_MoodleDefs and LV_MoodleDefs.getText(catDef.haloKey, catDef.defaultHalo) or catDef.defaultHalo
        if HaloTextHelper and HaloTextHelper.addText then
            HaloTextHelper.addText(character, haloText, 80, 240, 130)
        elseif character.setHaloNote then
            character:setHaloNote(haloText, 80, 240, 130, 250)
        end
    end
end

-- =============================================================================
-- INTERCEPTAÇÃO CENTRAL E SEGURA VIA ISTimedActionQueue.onCompleted
-- =============================================================================
if ISTimedActionQueue and not ISTimedActionQueue._LV_HomemakingHooked then
    local original_onCompleted = ISTimedActionQueue.onCompleted
    ISTimedActionQueue.onCompleted = function(action)
        pcall(function()
            LV_HomemakingActions.handleActionCompleted(action)
        end)
        return original_onCompleted(action)
    end
    ISTimedActionQueue._LV_HomemakingHooked = true
    print("[LarVivo] LV_HomemakingActions: Hook central em ISTimedActionQueue.onCompleted inicializado com sucesso!")
end
