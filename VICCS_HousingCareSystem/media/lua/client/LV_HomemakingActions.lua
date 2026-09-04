-- =============================================================================
-- Housing Care System (Lar Vivo) - Homemaking & Active Habitation Engine (LV_HomemakingActions.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Sistema 100% não-invasivo baseado no Padrão Observador (Observer Pattern).
--   Monitora as ações do jogador em tempo real através de Events.OnPlayerUpdate e
--   Events.OnCraftComplete sem substituir nenhuma função do jogo ou de outros mods.
--   Zero risco de quebra na máquina virtual Kahlua e 100% de compatibilidade multiplayer.
-- =============================================================================

LV_HomemakingActions = LV_HomemakingActions or {}

--- Categorias de Tarefas Domésticas e seus pesos padrão
local CATEGORIES = {
    Cleaning = {
        name = "Cleaning",
        defaultPercent = 15,
        cooldownSeconds = 40,
        haloKey = "UI_LV_Halo_Cleaning",
        defaultHalo = "+15% Duracao do Lar (Limpeza)"
    },
    Cooking = {
        name = "Cooking",
        defaultPercent = 20,
        cooldownSeconds = 90,
        haloKey = "UI_LV_Halo_Cooking",
        defaultHalo = "+20% Duracao do Lar (Culinaria)"
    },
    Farming = {
        name = "Farming",
        defaultPercent = 15,
        cooldownSeconds = 30,
        haloKey = "UI_LV_Halo_Farming",
        defaultHalo = "+15% Duracao do Lar (Jardinagem)"
    },
    Building = {
        name = "Building",
        defaultPercent = 25,
        cooldownSeconds = 60,
        haloKey = "UI_LV_Halo_Building",
        defaultHalo = "+25% Duracao do Lar (Construcao)"
    },
    Decorating = {
        name = "Decorating",
        defaultPercent = 15,
        cooldownSeconds = 120,
        haloKey = "UI_LV_Halo_Decorating",
        defaultHalo = "+15% Duracao do Lar (Decoracao)"
    }
}

--- Mapeamento de palavras-chave para identificar categorias de ações
local KEYWORD_CATEGORY_MAP = {
    -- Limpeza
    clean = "Cleaning",
    blood = "Cleaning",
    graffiti = "Cleaning",
    trash = "Cleaning",
    wash = "Cleaning",
    mop = "Cleaning",

    -- Culinária
    cook = "Cooking",
    bake = "Cooking",
    roast = "Cooking",
    fry = "Cooking",
    food = "Cooking",
    salad = "Cooking",
    soup = "Cooking",
    sandwich = "Cooking",
    meat = "Cooking",
    stew = "Cooking",

    -- Jardinagem
    water = "Farming",
    plant = "Farming",
    fertilize = "Farming",
    harvest = "Farming",
    seed = "Farming",
    cure = "Farming",
    crop = "Farming",
    shovel = "Farming",

    -- Construção
    build = "Building",
    paint = "Building",
    plaster = "Building",
    barricade = "Building",
    carpentry = "Building",
    wall = "Building",
    door = "Building",
    window = "Building",

    -- Decoração & Organização
    moveable = "Decorating",
    furniture = "Decorating",
    place3d = "Decorating",
    rotate = "Decorating",
    curtain = "Decorating"
}

--- Rastreamento de tempo real para cooldowns anti-spam
local lastActionTimestamps = {}

--- Rastreamento de estado de ação ativa do jogador local
local lastObservedActionName = nil
local lastObservedProgress = 0.0

--- Obtém o tempo do sistema em segundos de forma segura.
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
    local shClass = SafeHouse or Safehouse
    if shClass and shClass.getSafehouse and sq then
        local ok, sh = pcall(shClass.getSafehouse, sq)
        if ok and sh then return true end
    end

    return false
end

--- Identifica a categoria a partir do nome ou tipo de ação
local function detectCategoryFromActionName(actionStr)
    if not actionStr or actionStr == "" then return nil end
    local lower = tostring(actionStr):lower()

    for keyword, catName in pairs(KEYWORD_CATEGORY_MAP) do
        if lower:find(keyword) then
            return catName
        end
    end
    return nil
end

--- Concede o bônus para uma categoria específica após validações completas
function LV_HomemakingActions.triggerCompletedCategory(character, categoryName, bonusPercent)
    if not character or not LV_Config or not LV_Config.isHomemakingEnabled() then
        return
    end

    local localPlayer = getPlayer()
    if character ~= localPlayer then
        return
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
    local percent = bonusPercent or catDef.defaultPercent
    local addedHours = LV_BuffManager.addHomemakingBonus(character, categoryName, percent)

    -- Se for culinária, adiciona sujeira orgânica na cozinha/cômodo
    if categoryName == "Cooking" and LV_DirtSystem and LV_DirtSystem.onCooking then
        pcall(function() LV_DirtSystem.onCooking(character) end)
    end

    if addedHours and addedHours > 0 then
        local haloText = LV_MoodleDefs and LV_MoodleDefs.getText(catDef.haloKey, catDef.defaultHalo) or catDef.defaultHalo
        if HaloTextHelper and HaloTextHelper.addGoodText then
            pcall(function() HaloTextHelper.addGoodText(character, tostring(haloText)) end)
        elseif HaloTextHelper and HaloTextHelper.addText then
            pcall(function() HaloTextHelper.addText(character, tostring(haloText)) end)
        elseif character.setHaloNote then
            pcall(function() character:setHaloNote(tostring(haloText), 80, 240, 130, 250) end)
        end
    end
end

-- =============================================================================
-- OBSERVADOR NATIVO DE AÇÕES VIA OnPlayerUpdate (100% SEGURO VIA ISTimedActionQueue)
-- =============================================================================
local function onPlayerUpdateObserver(player)
    if not player or not LV_Config or not LV_Config.isHomemakingEnabled() then
        return
    end

    local localPlayer = getPlayer()
    if player ~= localPlayer then
        return
    end

    local queue = ISTimedActionQueue and ISTimedActionQueue.getTimedActionQueue(player)
    local activeAction = (queue and queue.queue and #queue.queue > 0) and queue.queue[1] or nil

    if activeAction then
        local actName = activeAction.Type or (activeAction.action and tostring(activeAction.action)) or tostring(activeAction)
        local progress = 0.0

        if activeAction.getJobDelta then
            local ok, d = pcall(activeAction.getJobDelta, activeAction)
            if ok and type(d) == "number" then progress = d end
        elseif activeAction.time and activeAction.time > 0 and activeAction.currentTime then
            progress = activeAction.currentTime / activeAction.time
        end

        lastObservedActionName = actName
        lastObservedProgress = progress
    else
        -- Ação acabou de terminar! Se atingiu pelo menos 80% do progresso antes de sair da fila:
        if lastObservedActionName and lastObservedProgress >= 0.80 then
            local cat = detectCategoryFromActionName(lastObservedActionName)
            if cat then
                LV_HomemakingActions.triggerCompletedCategory(player, cat)
            end
        end
        lastObservedActionName = nil
        lastObservedProgress = 0.0
    end
end

-- =============================================================================
-- OBSERVADOR DE RECEITAS CULINÁRIAS / CARPINTARIA VIA OnCraftComplete
-- =============================================================================
local function onCraftCompleteObserver(recipe, player)
    if not player or not recipe or not LV_Config or not LV_Config.isHomemakingEnabled() then
        return
    end

    local rCat = tostring(recipe.getCategory and recipe:getCategory() or ""):lower()
    local rName = tostring(recipe.getName and recipe:getName() or ""):lower()

    if rCat:find("cook") or rCat:find("food") or rName:find("salad") or rName:find("soup") or rName:find("sandwich") or rName:find("cook") or rName:find("bake") then
        LV_HomemakingActions.triggerCompletedCategory(player, "Cooking", 20)
    elseif rCat:find("carpentry") or rCat:find("build") or rName:find("plank") or rName:find("door") then
        LV_HomemakingActions.triggerCompletedCategory(player, "Building", 20)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdateObserver)
if Events.OnCraftComplete then
    Events.OnCraftComplete.Add(onCraftCompleteObserver)
end

print("[LarVivo] LV_HomemakingActions: Motor Observador de Tarefas Domésticas carregado com sucesso!")
