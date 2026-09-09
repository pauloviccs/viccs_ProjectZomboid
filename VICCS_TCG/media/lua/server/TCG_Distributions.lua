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

TCG_Distributions = TCG_Distributions or {}

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
