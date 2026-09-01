-- =============================================================================
-- Housing Care System (Lar Vivo) - Homemaking & Active Habitation Engine (LV_HomemakingActions.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Intercepta de forma não-invasiva as ações rotineiras do sobrevivente no lar
--   (Limpeza, Culinária, Jardinagem, Construção e Decoração).
--   Recompensa o cuidado ativo com a base, concedendo bônus percentuais de extensão
--   da duração dos buffs do lar, com proteção anti-exploit e rendimentos decrescentes.
-- =============================================================================

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

--- Rastreamento de tempo real (timestamp do sistema) para cooldowns anti-spam
local lastActionTimestamps = {}

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
        if sq:getRoom() ~= nil or sq:isInARoom() then
            return true
        end
        if sq:haveRoof() then
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

--- Manipulador central invocado quando uma ação doméstica é concluída com sucesso.
function LV_HomemakingActions.onActionCompleted(character, categoryName, bonusPercent, actionName)
    if not character or not LV_Config or not LV_Config.isHomemakingEnabled() then return end

    -- Apenas processa para o jogador local
    local localPlayer = getPlayer()
    if character ~= localPlayer then return end

    local catDef = CATEGORIES[categoryName]
    if not catDef then return end

    -- Validação de abrigo/base
    if not isCharacterInValidHomeArea(character) then
        return
    end

    -- Verificação de Cooldown Anti-Spam
    local now = getTimestampMs and (getTimestampMs() / 1000.0) or (getGameTime():getWorldAgeHours() * 3600.0)
    local configuredCd = (LV_Config and LV_Config.get and LV_Config.get("HomemakingCooldownSeconds")) or catDef.cooldownSeconds
    local lastTime = lastActionTimestamps[categoryName] or 0

    if (now - lastTime) < configuredCd then
        return
    end
    lastActionTimestamps[categoryName] = now

    -- Aplica o bônus no BuffManager
    local percentToApply = bonusPercent or catDef.defaultPercent
    local addedHours = LV_BuffManager.addHomemakingBonus(character, categoryName, percentToApply)

    if addedHours and addedHours > 0 then
        pcall(function()
            local scale = (LV_Config and LV_Config.get and LV_Config.get("HomemakingBonusScale")) or 1.0
            local displayPercent = math.floor(percentToApply * scale)
            local haloText = LV_MoodleDefs and LV_MoodleDefs.getText(catDef.haloKey, catDef.defaultHalo) or catDef.defaultHalo

            -- Feedback visual suave com Halo Text
            if character.setHaloNote then
                character:setHaloNote(haloText, 70, 240, 130, 260)
            end
        end)
    end
end

-- =============================================================================
-- HOOKS SEGUROS EM TIMED ACTIONS NATIVAS DO PROJECT ZOMBOID (BUILD 42)
-- =============================================================================

local function wrapTimedAction(className, category, bonusPercent, extraCondition)
    local cls = _G[className]
    if cls and type(cls.perform) == "function" and not cls._LV_Hooked then
        local originalPerform = cls.perform
        cls.perform = function(self, ...)
            local res = { originalPerform(self, ...) }
            pcall(function()
                if self and self.character then
                    if not extraCondition or extraCondition(self) then
                        LV_HomemakingActions.onActionCompleted(self.character, category, bonusPercent, className)
                    end
                end
            end)
            return unpack(res)
        end
        cls._LV_Hooked = true
    end
end

--- Inicializa os hooks de todas as ações elegíveis após o carregamento dos scripts.
local function initializeHomemakingHooks()
    -- 1. LIMPEZA & HIGIENE
    wrapTimedAction("ISCleanBloodAction", "Cleaning", 15)
    wrapTimedAction("ISCleanGraffitiAction", "Cleaning", 15)
    wrapTimedAction("ISTakeTrashAction", "Cleaning", 15)

    -- 2. CULINÁRIA & PREPARO
    wrapTimedAction("ISCookAction", "Cooking", 20)
    wrapTimedAction("ISCraftAction", "Cooking", 20, function(action)
        if action and action.recipe then
            local rName = tostring(action.recipe:getName() or ""):lower()
            local rCat = tostring(action.recipe:getCategory() or ""):lower()
            if rCat:find("cook") or rCat:find("food") or rName:find("salad") or rName:find("soup") or rName:find("sandwich") or rName:find("cook") then
                return true
            end
        end
        return false
    end)

    -- 3. JARDINAGEM & CULTIVO
    wrapTimedAction("ISWaterPlantAction", "Farming", 15)
    wrapTimedAction("ISFertilizeAction", "Farming", 15)
    wrapTimedAction("ISHarvestPlantAction", "Farming", 20)
    wrapTimedAction("ISPlantAction", "Farming", 15)
    wrapTimedAction("ISSeedAction", "Farming", 15)
    wrapTimedAction("ISCureFliesAction", "Farming", 15)
    wrapTimedAction("ISCureMildewAction", "Farming", 15)

    -- 4. CONSTRUÇÃO & CARPINTARIA
    wrapTimedAction("ISBuildAction", "Building", 25)
    wrapTimedAction("ISPaintAction", "Building", 20)
    wrapTimedAction("ISPlasterAction", "Building", 20)
    wrapTimedAction("ISBarricadeAction", "Building", 15)

    -- 5. DECORAÇÃO & ORGANIZAÇÃO
    wrapTimedAction("ISMoveablesAction", "Decorating", 15, function(action)
        if action and action.mode then
            -- Recompensa colocar ou mover mobílias/decorações
            return action.mode == "place" or action.mode == "rotate" or action.mode == "pickup"
        end
        return true
    end)
    wrapTimedAction("ISPlace3DItemAction", "Decorating", 15)

    print("[LarVivo] LV_HomemakingActions: Hooks não-invasivos em TimedActions inicializados com sucesso!")
end

Events.OnGameStart.Add(initializeHomemakingHooks)
