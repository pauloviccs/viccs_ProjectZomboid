-- =============================================================================
-- Housing Care System (Lar Vivo) - Dirt Score Data (LV_DirtScoreData.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Tabelas de dados e parâmetros para o sistema de Sujeira Dinâmica,
--   Transferência Pé -> Chão, Fixtures Sanitárias e Materiais de Faxina.
--   Zero hardcode na lógica de varredura ou nas ações com tempo.
-- =============================================================================

LV_DirtScoreData = LV_DirtScoreData or {}

--- Taxas base de ganho de sujeira no calçado/pés por tipo de terreno
LV_DirtScoreData.FootDirtGain = {
    Grass       = 0.20,  -- Grama externa / vegetação
    DirtSand    = 0.45,  -- Terra batida / areia / cascalho
    MudPuddle   = 0.85,  -- Lama / poça de água na chuva
    BloodSplats = 1.00,  -- Poça de sangue fresco externa
    RainFactor  = 1.50,  -- Multiplicador caso esteja chovendo no momento
    BarefootAdd = 0.25,  -- Adicional se estiver descalço
}

--- Proporção de transferência do pé para o piso da casa a cada ciclo de passos
LV_DirtScoreData.FloorTransfer = {
    StepThreshold      = 10,    -- Passos acumulados antes de processar transferência
    TransferRatio      = 0.08,  -- Fração de footDirt depositada no cômodo
    CleanFloorDecay    = 0.05,  -- Decaimento natural de footDirt ao andar em piso limpo
    MaxFloorDirt       = 100.0, -- Teto de sujeira acumulada de piso por cômodo/Safehouse
}

--- Sujeira gerada por preparar pratos elaborados
LV_DirtScoreData.Cooking = {
    DefaultMealDirt = 8.0,      -- Sujeira adicionada ao cômodo da cozinha por receita
}

--- Acréscimo de sujeira por uso de fixtures sanitárias
LV_DirtScoreData.FixtureDirtOnUse = {
    ToiletPee    = 10.0,  -- Uso do vaso para urinar
    ToiletPoop   = 25.0,  -- Uso do vaso para evacuar
    Sink         = 5.0,   -- Uso da pia para lavar itens/mãos
    Shower       = 12.0,  -- Tomar banho no chuveiro
    Bathtub      = 15.0,  -- Tomar banho na banheira
}

--- Itens vanilla aceitos como ferramentas de limpeza (auto-equip)
LV_DirtScoreData.CleaningCloths = {
    ["Base.DishCloth"]      = true,
    ["Base.BathTowel"]      = true,
    ["Base.BathTowelWet"]   = true,
    ["Base.Sponge"]         = true,
    ["Base.RippedSheets"]   = true,
    ["Base.Mop"]            = true,
    ["Base.Broom"]          = true,
}

--- Itens de desinfecção / sabão que aceleram a faxina e concedem bônus extra
LV_DirtScoreData.CleaningAgents = {
    ["Base.Bleach"]         = true,
    ["Base.Soap2"]          = true,
    ["Base.CleaningLiquid"] = true,
}

--- Papel higiênico para uso no vaso
LV_DirtScoreData.ToiletPaper = {
    ["Base.ToiletPaper"]    = true,
}

--- Padrões de sprites/classes para identificar peças sanitárias
LV_DirtScoreData.FixturePatterns = {
    toilet = {
        className = "IsoToilet",
        keywords = { "toilet", "fixtures_bathroom_01_0", "fixtures_bathroom_01_1", "fixtures_bathroom_01_2", "fixtures_bathroom_01_3" },
        name = "Vaso Sanitario",
    },
    sink = {
        className = "IsoObject",
        keywords = { "sink", "fixtures_sinks_", "fixtures_bathroom_01_16", "fixtures_bathroom_01_17", "fixtures_bathroom_01_18", "fixtures_bathroom_01_19" },
        name = "Pia",
    },
    bathtub = {
        className = "IsoObject",
        keywords = { "bath", "bathtub", "fixtures_bathroom_01_24", "fixtures_bathroom_01_25", "fixtures_bathroom_01_26", "fixtures_bathroom_01_27" },
        name = "Banheira",
    },
    shower = {
        className = "IsoObject",
        keywords = { "shower", "fixtures_bathroom_01_32", "fixtures_bathroom_01_33" },
        name = "Chuveiro",
    },
}
