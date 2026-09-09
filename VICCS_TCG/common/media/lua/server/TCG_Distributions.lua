-- =============================================================================
-- Project Zomboid TCG - World Loot Distribution (Build 42 Sandbox Aware)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Injeta pacotes de cartas, ficharios e cartas avulsas nos locais tematicos
--   do mapa de Kentucky respeitando as SandboxVars (Frequencia e Locais de Spawn).
-- =============================================================================

require "Items/ProceduralDistributions"
require "TCG_Config"
require "TCG_CardRegistry"
require "TCG_Theme"
require "TCG_BinderUI"

TCG_Distributions = TCG_Distributions or {}

--- Inicializa e preenche um fichario abandonado com cartas autenticas
function TCG_Distributions.rollPreFilledBinder(binderItem)
    if not binderItem then return end
    local md = binderItem:getModData()
    if md.TCG_PreFillChecked then return end
    md.TCG_PreFillChecked = true

    local chance = TCG_Config.getPreFilledBinderChance()
    if chance <= 0 then return end

    local roll = ZombRand(100) + 1
    if roll > chance then return end

    local cMin = TCG_Config.getPreFilledCardsMin()
    local cMax = TCG_Config.getPreFilledCardsMax()
    local minVal = math.min(cMin, cMax)
    local maxVal = math.max(cMin, cMax)
    local cardCount = ZombRand(minVal, maxVal + 1)
    if cardCount < 1 then cardCount = 1 end

    local bData = TCG_BinderUI.getBinderDataFromItem(binderItem)

    -- Sorteia uma cor de capa retro
    local themes = TCG_Theme.THEME_KEYS
    if themes and #themes > 0 then
        bData.themeColor = themes[ZombRand(#themes) + 1]
    end

    local badges = { "COLLECTOR", "VINTAGE", "TRADES" }
    bData.badge = badges[ZombRand(#badges) + 1]

    local vintageNames = {
        "Colecao de Billy (1999)",
        "Album Antigo de Cartas",
        "Fichario do Clube TCG",
        "Colecao da Infancia",
        "Album de Trocas",
        "Fichario de Knox County"
    }
    local chosenName = vintageNames[ZombRand(#vintageNames) + 1]
    bData.customName = chosenName
    binderItem:setName(string.format("Fichario TCG: %s", chosenName))

    local holoChance = TCG_Config.getHoloChance()
    for _ = 1, cardCount do
        local randNum = ZombRand(1, 103) -- 1 a 102
        local cid = string.format("base1-%03d", randNum)
        local cardDef = TCG_CardRegistry.getCard(cid)
        if cardDef then
            local isHolo = false
            if cardDef.rarity and (cardDef.rarity.en == "Rare Holo" or cardDef.rarity == "Rare Holo") then
                isHolo = (ZombRand(100) + 1 <= holoChance)
            end

            if not bData.collected[cid] then
                bData.collected[cid] = {
                    number = randNum,
                    isHolo = isHolo,
                    count = 1
                }
            else
                bData.collected[cid].count = (bData.collected[cid].count or 1) + 1
                if isHolo then
                    bData.collected[cid].isHolo = true
                end
            end
        end
    end
end

local function onFillContainer(roomName, containerType, itemContainer)
    if not itemContainer then return end
    local items = itemContainer:getItems()
    if not items then return end
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and (it:getFullType() == "Base.TCG_Binder" or it:getFullType() == "TCG_Binder") then
            TCG_Distributions.rollPreFilledBinder(it)
        end
    end
end

if Events.OnFillContainer then
    Events.OnFillContainer.Add(onFillContainer)
end

if Events.OnPostDistributionMerge then
    Events.OnPostDistributionMerge.Add(TCG_Distributions.init)
end

local function insertLoot(distName, itemType, baseWeight, mult)
    if not ProceduralDistributions or not ProceduralDistributions.list then return end
    if not mult or mult <= 0 then return end

    local dist = ProceduralDistributions.list[distName]
    if dist and dist.items then
        -- Evita insercao duplicada
        for i = 1, #dist.items, 2 do
            if dist.items[i] == itemType then
                return
            end
        end
        local finalWeight = baseWeight * mult
        table.insert(dist.items, itemType)
        table.insert(dist.items, finalWeight)
    end
end

function TCG_Distributions.init()
    local mult = TCG_Config.getSpawnMultiplier()
    if mult <= 0 then return end -- Desativado totalmente via Sandbox

    -- 1. Lojas e Livrarias (Comercial)
    if TCG_Config.isCommercialAllowed() then
        insertLoot("BookstoreComics", "Base.TCG_Booster_Base1", 10.0, mult)
        insertLoot("BookstoreComics", "Base.TCG_Binder", 5.0, mult)
        insertLoot("BookstoreBooks", "Base.TCG_Booster_Base1", 4.0, mult)
        insertLoot("ToyStoreShelves", "Base.TCG_Booster_Base1", 15.0, mult)
        insertLoot("ToyStoreShelves", "Base.TCG_Binder", 8.0, mult)
    end

    -- 2. Escolas e Quartos Infantis
    if TCG_Config.isSchoolAllowed() then
        insertLoot("SchoolLockers", "Base.TCG_Booster_Base1", 5.0, mult)
        insertLoot("SchoolLockers", "Base.TCG_Card", 8.0, mult)
        insertLoot("WardrobeChild", "Base.TCG_Booster_Base1", 3.0, mult)
        insertLoot("WardrobeChild", "Base.TCG_Binder", 2.0, mult)
    end

    -- 3. Mesinhas Residenciais
    if TCG_Config.isResidentialAllowed() then
        insertLoot("LivingRoomSideTable", "Base.TCG_Booster_Base1", 1.5, mult)
        insertLoot("LivingRoomSideTable", "Base.TCG_Card", 3.0, mult)
        insertLoot("BedroomSideTable", "Base.TCG_Booster_Base1", 1.0, mult)
    end
end

if Events.OnPostDistributionMerge then
    Events.OnPostDistributionMerge.Add(TCG_Distributions.init)
end
