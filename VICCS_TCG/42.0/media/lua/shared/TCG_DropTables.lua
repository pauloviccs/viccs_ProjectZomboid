-- =============================================================================
-- Project Zomboid TCG - Drop Tables & Booster Distribution Engine
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Calcula deterministica e fidedignamente a abertura de um pacote de cartas
--   seguindo o padrao classico de 10 cartas do Base Set de 1999:
--   - 5 Cartas Comuns
--   - 3 Cartas Incomuns
--   - 1 Carta Energia / Treinador
--   - 1 Carta Rara / Holo Foil (com chance de upgrade holografico)
-- =============================================================================

require "TCG_CardRegistry"

TCG_DropTables = TCG_DropTables or {}

--- Retorna um indice aleatorio valido para um array Lua (1 ate #list)
local function getRandomFromList(list)
    if not list or #list == 0 then return nil end
    local randFunc = ZombRand or math.random
    local idx = randFunc(1, #list + 1)
    return list[idx]
end

--- Separa as cartas de um Set em pools de raridade cacheados
local cachedPools = {}
function TCG_DropTables.getPools(setId)
    setId = setId or "base1"
    if cachedPools[setId] then
        return cachedPools[setId]
    end

    local setDef = TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[setId]
    if not setDef then return nil end

    local pools = {
        commons = {},
        uncommons = {},
        rares = {},
        holos = {},
        energies = {}
    }

    for _, card in pairs(setDef.cards) do
        local r = card.rarity or "Common"
        if type(r) == "table" then
            r = r.en or "Common"
        end
        local num = card.number or 0

        if num >= 97 and num <= 102 then
            table.insert(pools.energies, card)
        end

        if card.isHolo or (num >= 1 and num <= 16) then
            table.insert(pools.holos, card)
        elseif r == "Rare" then
            table.insert(pools.rares, card)
        elseif r == "Uncommon" then
            table.insert(pools.uncommons, card)
        else
            table.insert(pools.commons, card)
        end
    end

    cachedPools[setId] = pools
    return pools
end

--- Simula a abertura de 1 Booster Pack e retorna 10 cartas sorteadas
function TCG_DropTables.openBooster(setId)
    setId = setId or "base1"
    local pools = TCG_DropTables.getPools(setId)
    if not pools then return {} end

    local rand = ZombRand or math.random
    local pulled = {}

    -- 1. Cinco Cartas Comuns
    for i = 1, 5 do
        local c = getRandomFromList(pools.commons)
        if c then
            table.insert(pulled, {
                card = c,
                isHolo = false,
                condition = 100
            })
        end
    end

    -- 2. Tres Cartas Incomuns
    for i = 1, 3 do
        local c = getRandomFromList(pools.uncommons)
        if c then
            table.insert(pulled, {
                card = c,
                isHolo = false,
                condition = 100
            })
        end
    end

    -- 3. Uma Carta Energia Basica / Treinador
    local energyCard = getRandomFromList(pools.energies) or getRandomFromList(pools.commons)
    if energyCard then
        table.insert(pulled, {
            card = energyCard,
            isHolo = false,
            condition = 100
        })
    end

    -- 4. Uma Carta Rara ou Holo Foil (probabilidade configuravel via Sandbox)
    local holoChance = (TCG_Config and TCG_Config.getHoloChance and TCG_Config.getHoloChance()) or 33
    local rollHolo = rand(100) < holoChance
    local rareCard = nil
    if rollHolo and #pools.holos > 0 then
        rareCard = getRandomFromList(pools.holos)
    else
        rareCard = getRandomFromList(pools.rares) or getRandomFromList(pools.holos)
    end

    if rareCard then
        table.insert(pulled, {
            card = rareCard,
            isHolo = rareCard.isHolo or rollHolo,
            condition = 100
        })
    end

    return pulled
end
