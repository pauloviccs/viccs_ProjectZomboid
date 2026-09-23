-- =============================================================================
-- Project Zomboid TCG - World Loot Distribution (Build 42 Sandbox Aware)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Injeta pacotes de cartas, ficharios e cartas avulsas nos locais tematicos
--   do mapa de Kentucky respeitando as SandboxVars (Frequencia e Locais de Spawn).
--   Compativel com Servidores Dedicados Headless (Sem imports de UI/ISPanel).
-- =============================================================================

require "Items/ProceduralDistributions"
require "TCG_Config"
require "TCG_CardRegistry"
require "TCG_BinderData"
require "TCG_CompatHooks"

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

    local bData = TCG_BinderData.getBinderDataFromItem(binderItem)

    -- Sorteia uma cor de capa retro
    local themes = TCG_BinderData.THEME_KEYS
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

    if isServer and isServer() and sendItemStats then
        pcall(function() sendItemStats(binderItem) end)
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

local function insertSuburbsLoot(room, container, itemType, weight)
    if not SuburbsDistributions then return end
    local roomDef = SuburbsDistributions[room]
    if not roomDef then return end
    local contDef = roomDef[container]
    if not contDef or not contDef.items then return end

    for i = 1, #contDef.items, 2 do
        if contDef.items[i] == itemType then
            return
        end
    end
    table.insert(contDef.items, itemType)
    table.insert(contDef.items, weight)
end

function TCG_Distributions.init()
    local mult = TCG_Config.getSpawnMultiplier()
    if mult <= 0 then return end -- Desativado totalmente via Sandbox

    -- 1. Lojas e Livrarias (Comercial)
    if TCG_Config.isCommercialAllowed() then
        insertLoot("BookstoreComics", "Base.TCG_Booster_Base1", 10.0, mult)
        insertLoot("BookstoreComics", "Base.TCG_Booster_Jungle", 8.0, mult)
        insertLoot("BookstoreComics", "Base.TCG_Booster_Fossil", 8.0, mult)
        insertLoot("BookstoreComics", "Base.TCG_Booster_TeamRocket", 6.0, mult)
        insertLoot("BookstoreComics", "Base.TCG_Booster_EeveeHeroes", 4.0, mult)
        insertLoot("BookstoreComics", "Base.TCG_Binder", 5.0, mult)

        insertLoot("BookstoreBooks", "Base.TCG_Booster_Base1", 4.0, mult)
        insertLoot("BookstoreBooks", "Base.TCG_Booster_Jungle", 3.0, mult)
        insertLoot("BookstoreBooks", "Base.TCG_Booster_Fossil", 3.0, mult)
        insertLoot("BookstoreBooks", "Base.TCG_Booster_TeamRocket", 2.0, mult)
        insertLoot("BookstoreBooks", "Base.TCG_Booster_EeveeHeroes", 1.5, mult)

        insertLoot("ToyStoreShelves", "Base.TCG_Booster_Base1", 15.0, mult)
        insertLoot("ToyStoreShelves", "Base.TCG_Booster_Jungle", 12.0, mult)
        insertLoot("ToyStoreShelves", "Base.TCG_Booster_Fossil", 12.0, mult)
        insertLoot("ToyStoreShelves", "Base.TCG_Booster_TeamRocket", 10.0, mult)
        insertLoot("ToyStoreShelves", "Base.TCG_Booster_EeveeHeroes", 6.0, mult)
        insertLoot("ToyStoreShelves", "Base.TCG_Binder", 8.0, mult)
    end

    -- 2. Escolas e Quartos Infantis
    if TCG_Config.isSchoolAllowed() then
        insertLoot("SchoolLockers", "Base.TCG_Booster_Base1", 5.0, mult)
        insertLoot("SchoolLockers", "Base.TCG_Booster_Jungle", 4.0, mult)
        insertLoot("SchoolLockers", "Base.TCG_Booster_Fossil", 4.0, mult)
        insertLoot("SchoolLockers", "Base.TCG_Booster_TeamRocket", 3.0, mult)
        insertLoot("SchoolLockers", "Base.TCG_Booster_EeveeHeroes", 1.5, mult)
        insertLoot("SchoolLockers", "Base.TCG_Card", 8.0, mult)

        insertLoot("WardrobeChild", "Base.TCG_Booster_Base1", 3.0, mult)
        insertLoot("WardrobeChild", "Base.TCG_Booster_Jungle", 2.5, mult)
        insertLoot("WardrobeChild", "Base.TCG_Booster_Fossil", 2.5, mult)
        insertLoot("WardrobeChild", "Base.TCG_Booster_TeamRocket", 2.0, mult)
        insertLoot("WardrobeChild", "Base.TCG_Booster_EeveeHeroes", 1.5, mult)
        insertLoot("WardrobeChild", "Base.TCG_Binder", 2.0, mult)
    end

    -- 3. Mesinhas Residenciais
    if TCG_Config.isResidentialAllowed() then
        insertLoot("LivingRoomSideTable", "Base.TCG_Booster_Base1", 1.5, mult)
        insertLoot("LivingRoomSideTable", "Base.TCG_Booster_Jungle", 1.0, mult)
        insertLoot("LivingRoomSideTable", "Base.TCG_Booster_Fossil", 1.0, mult)
        insertLoot("LivingRoomSideTable", "Base.TCG_Booster_TeamRocket", 0.8, mult)
        insertLoot("LivingRoomSideTable", "Base.TCG_Booster_EeveeHeroes", 0.4, mult)
        insertLoot("LivingRoomSideTable", "Base.TCG_Card", 3.0, mult)

        insertLoot("BedroomSideTable", "Base.TCG_Booster_Base1", 1.0, mult)
        insertLoot("BedroomSideTable", "Base.TCG_Booster_Jungle", 0.7, mult)
        insertLoot("BedroomSideTable", "Base.TCG_Booster_Fossil", 0.7, mult)
        insertLoot("BedroomSideTable", "Base.TCG_Booster_TeamRocket", 0.5, mult)
        insertLoot("BedroomSideTable", "Base.TCG_Booster_EeveeHeroes", 0.3, mult)
    end

    -- 4. Bolsos de Zumbis Nativos (Loot procedimental em zumbis spawnados pelo mapa)
    insertSuburbsLoot("all", "inventorymale", "Base.TCG_Booster_Base1", 0.3 * mult)
    insertSuburbsLoot("all", "inventorymale", "Base.TCG_Booster_Jungle", 0.25 * mult)
    insertSuburbsLoot("all", "inventorymale", "Base.TCG_Booster_Fossil", 0.25 * mult)
    insertSuburbsLoot("all", "inventorymale", "Base.TCG_Booster_TeamRocket", 0.2 * mult)
    insertSuburbsLoot("all", "inventorymale", "Base.TCG_Booster_EeveeHeroes", 0.1 * mult)
    insertSuburbsLoot("all", "inventorymale", "Base.TCG_Card", 0.8 * mult)

    insertSuburbsLoot("all", "inventoryfemale", "Base.TCG_Booster_Base1", 0.3 * mult)
    insertSuburbsLoot("all", "inventoryfemale", "Base.TCG_Booster_Jungle", 0.25 * mult)
    insertSuburbsLoot("all", "inventoryfemale", "Base.TCG_Booster_Fossil", 0.25 * mult)
    insertSuburbsLoot("all", "inventoryfemale", "Base.TCG_Booster_TeamRocket", 0.2 * mult)
    insertSuburbsLoot("all", "inventoryfemale", "Base.TCG_Booster_EeveeHeroes", 0.1 * mult)
    insertSuburbsLoot("all", "inventoryfemale", "Base.TCG_Card", 0.8 * mult)
end

if Events.OnPostDistributionMerge then
    Events.OnPostDistributionMerge.Add(TCG_Distributions.init)
end

--- Hook de salvaguarda para mundos existentes (Saves antigos com cidades ja looteadas)
--- Permite encontrar cartas e boosters raros nos bolsos de zumbis eliminados.
--- Executa exclusivamente no servidor autoritativo (ou singleplayer) com sincronizacao completa de rede.
local function onZombieDead(zombie)
    if not zombie then return end
    -- Em multiplayer, apenas o servidor gera itens autoritativos em corpos
    if isClient and isClient() then return end

    local mult = TCG_Config.getSpawnMultiplier()
    if mult <= 0 then return end

    -- 1. Drop de Booster Packs (Configuravel via Sandbox)
    local boosterChance = TCG_Config.getZombieBoosterChance()
    if boosterChance > 0 then
        local effectiveChance = boosterChance * mult
        local rollBooster = (ZombRand(10000) + 1) / 100.0 -- Precisao de 0.01% ate 100.0%
        local success = (rollBooster <= effectiveChance)

        local isDebug = (isDebugEnabled and isDebugEnabled()) or (getDebug and getDebug())
        if isDebug then
            print(string.format("[VICCS TCG] Morte de Zumbi -> Rolou: %.2f%% | Alvo: %.2f%% | %s",
                rollBooster, effectiveChance, success and "SUCESSO (Dropou)" or "FALHA"))
        end

        if success then
            local inv = zombie:getInventory()
            if inv then
                local cMin = TCG_Config.getZombieBoosterMin()
                local cMax = TCG_Config.getZombieBoosterMax()
                local minVal = math.max(1, math.min(cMin, cMax))
                local maxVal = math.max(1, math.max(cMin, cMax))
                local count = (minVal == maxVal) and minVal or ZombRand(minVal, maxVal + 1)

                local boosterTypes = {
                    "Base.TCG_Booster_Base1",
                    "Base.TCG_Booster_Jungle",
                    "Base.TCG_Booster_Fossil",
                    "Base.TCG_Booster_TeamRocket",
                    "Base.TCG_Booster_EeveeHeroes"
                }

                for _ = 1, count do
                    local chosenBooster = boosterTypes[ZombRand(#boosterTypes) + 1]
                    local boosterItem = inv:AddItem(chosenBooster)
                    if boosterItem and isServer and isServer() and sendAddItemToContainer then
                        pcall(function() sendAddItemToContainer(inv, boosterItem) end)
                    end
                end
                print(string.format("[VICCS TCG] Drop de Booster confirmado: %d pacote(s) adicionado(s) ao corpo do zumbi.", count))
            end
        end
    end


    -- 2. Chance de carta avulsa no bolso do zumbi (~0.8% * multiplicador)
    local rollCard = ZombRand(1000) + 1
    if rollCard <= math.floor(8 * mult) then
        local inv = zombie:getInventory()
        if inv then
            local cardItem = inv:AddItem("Base.TCG_Card")
            if cardItem then
                local sets = { "base1", "jungle", "fossil", "rocket", "eeveeheroes" }
                local chosenSet = sets[ZombRand(#sets) + 1]
                local setDef = TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[chosenSet]
                local total = setDef and setDef.total or 102
                local randNum = ZombRand(total) + 1
                local cid = string.format("%s-%03d", chosenSet, randNum)
                local cardDef = TCG_CardRegistry.getCard(cid)
                if cardDef then
                    local md = cardItem:getModData()
                    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
                    local nameEN = (type(cardDef.name) == "table") and cardDef.name.en or cardDef.name
                    local namePT = (type(cardDef.name) == "table") and cardDef.name.pt or cardDef.name
                    local displayName = isPT and namePT or nameEN
                    local isHolo = false
                    if cardDef.rarity and (cardDef.rarity.en == "Rare Holo" or cardDef.rarity == "Rare Holo") then
                        isHolo = (ZombRand(100) + 1 <= TCG_Config.getHoloChance())
                    end

                    md.cardId = cardDef.id
                    md.setId = chosenSet
                    md.cardNumber = cardDef.number
                    md.totalInSet = total
                    md.name_en = nameEN
                    md.name_pt = namePT
                    md.cardName = displayName
                    md.rarity = TCG_CardRegistry.getCardRarity(cardDef)
                    md.isHolo = isHolo
                    md.condition = ZombRand(30, 95)

                    local prefix = isPT and (isHolo and "* Carta TCG (Holo): " or "Carta TCG: ")
                                        or (isHolo and "* TCG Card (Holo): " or "TCG Card: ")
                    cardItem:setName(string.format("%s%s [#%02d/%d]", prefix, displayName, cardDef.number, total))

                    if isServer and isServer() then
                        if sendAddItemToContainer then
                            pcall(function() sendAddItemToContainer(inv, cardItem) end)
                        end
                        if sendItemStats then
                            pcall(function() sendItemStats(cardItem) end)
                        end
                    end
                end
            end
        end
    end
end

if Events.OnZombieDead then
    Events.OnZombieDead.Add(onZombieDead)
end
