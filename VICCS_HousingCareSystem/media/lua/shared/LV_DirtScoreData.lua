-- =============================================================================
-- Housing Care System (Lar Vivo) - Dirt Score Data (LV_DirtScoreData.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Tabelas de dados e parametros para o sistema de Sujeira Dinamica,
--   Transferencia Pe -> Chao, Fixtures Sanitarias e Materiais de Faxina.
--   Zero hardcode na logica de varredura ou nas acoes com tempo.
-- =============================================================================

LV_DirtScoreData = LV_DirtScoreData or {}

--- Taxas base de ganho de sujeira no calcado/pes por tipo de terreno
LV_DirtScoreData.FootDirtGain = {
    Grass       = 0.20,  -- Grama externa / vegetacao
    DirtSand    = 0.45,  -- Terra batida / areia / cascalho
    MudPuddle   = 0.85,  -- Lama / poca de agua na chuva
    BloodSplats = 1.00,  -- Poca de sangue fresco externa
    RainFactor  = 1.50,  -- Multiplicador caso esteja chovendo no momento
    BarefootAdd = 0.25,  -- Adicional se estiver descalco
}

--- Proporcao de transferencia do pe para o piso da casa a cada ciclo de passos
LV_DirtScoreData.FloorTransfer = {
    StepThreshold      = 10,    -- Passos acumulados antes de processar transferencia
    TransferRatio      = 0.08,  -- Fracao de footDirt depositada no comodo
    CleanFloorDecay    = 0.05,  -- Decaimento natural de footDirt ao andar em piso limpo
    MaxFloorDirt       = 100.0, -- Teto de sujeira acumulada de piso por comodo/Safehouse
}

--- Sujeira gerada por preparar pratos elaborados
LV_DirtScoreData.Cooking = {
    DefaultMealDirt = 8.0,      -- Sujeira adicionada ao comodo da cozinha por receita
}

--- Acrescimo de sujeira por uso de fixtures sanitarias
LV_DirtScoreData.FixtureDirtOnUse = {
    ToiletPee    = 10.0,  -- Uso do vaso para urinar
    ToiletPoop   = 25.0,  -- Uso do vaso para evacuar
    Sink         = 5.0,   -- Uso da pia para lavar itens/maos
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

--- Itens de desinfeccao / sabao que aceleram a faxina e concedem bonus extra
LV_DirtScoreData.CleaningAgents = {
    ["Base.Bleach"]         = true,
    ["Base.Soap2"]          = true,
    ["Base.CleaningLiquid"] = true,
}

--- Papel higienico para uso no vaso
LV_DirtScoreData.ToiletPaper = {
    ["Base.ToiletPaper"]    = true,
}

--- Padroes de sprites/classes para identificar pecas sanitarias
LV_DirtScoreData.FixturePatterns = {
    toilet = {
        className = "IsoToilet",
        keywords = { 
            "toilet", "latrine", "outhouse",
            "fixtures_bathroom_01_0", "fixtures_bathroom_01_1", "fixtures_bathroom_01_2", "fixtures_bathroom_01_3",
            "fixtures_bathroom_01_4", "fixtures_bathroom_01_5", "fixtures_bathroom_01_6", "fixtures_bathroom_01_7",
            "fixtures_bathroom_01_8", "fixtures_bathroom_01_9", "fixtures_bathroom_01_10", "fixtures_bathroom_01_11",
            "fixtures_bathroom_02_"
        },
        name = "Vaso Sanitario",
    },
    sink = {
        keywords = { "sink", "fixtures_sinks_", "fixtures_bathroom_01_16", "fixtures_bathroom_01_17", "fixtures_bathroom_01_18", "fixtures_bathroom_01_19" },
        name = "Pia",
    },
    bathtub = {
        keywords = { "bathtub", "fixtures_bathroom_01_24", "fixtures_bathroom_01_25", "fixtures_bathroom_01_26", "fixtures_bathroom_01_27", "fixtures_bathroom_01_28", "fixtures_bathroom_01_29", "fixtures_bathroom_01_30", "fixtures_bathroom_01_31" },
        name = "Banheira",
    },
    shower = {
        keywords = { "shower", "fixtures_bathroom_01_32", "fixtures_bathroom_01_33" },
        name = "Chuveiro",
    },
    stove = {
        className = "IsoStove",
        keywords = { "stove", "oven", "range", "cooktop", "appliances_cooking_" },
        name = "Fogao / Forno",
    },
}

--- Desgaste fisico/mecanico das instalacoes e eletrodomesticos por uso
LV_DirtScoreData.ApplianceHealthOnUse = {
    ToiletPee    = 1.2,   -- Desgaste do vaso ao urinar
    ToiletPoop   = 2.5,   -- Desgaste do vaso ao evacuar
    Sink         = 0.6,   -- Desgaste da pia por uso
    Shower       = 1.5,   -- Desgaste do chuveiro por banho
    Bathtub      = 1.8,   -- Desgaste da banheira por banho
    Stove        = 1.0,   -- Desgaste do fogao por preparo
}

--- Ferramentas e suprimentos vanilla aceitos para manutencao e reparos
LV_DirtScoreData.MaintenanceTools = {
    ["Base.PipeWrench"]       = { label = "Chave de Cano", effectiveness = 100, usesDelta = false },
    ["Base.Wrench"]           = { label = "Chave Inglesa", effectiveness = 85, usesDelta = false },
    ["Base.DuctTape"]         = { label = "Fita Adesiva", effectiveness = 50, usesDelta = true, deltaCost = 0.1 },
    ["Base.Screwdriver"]      = { label = "Chave de Fenda", effectiveness = 60, usesDelta = false },
    ["Base.ElectronicsScrap"] = { label = "Pecas Eletronicas", effectiveness = 70, usesDelta = false },
    ["Base.ScrapMetal"]       = { label = "Sucata Metalica", effectiveness = 65, usesDelta = false },
}

--- Penalidade por comida estragada no chao fora de recipientes
LV_DirtScoreData.RottenFoodPenalty = {
    PerItem = -6.0,    -- Reducao de conforto por alimento estragado solto no comodo
    MaxItems = 5,      -- Teto de protecao de performance da Kahlua VM (max -30.0 pts)
}

--------------------------------------------------------------------------------
-- Helpers Globais de Integridade de Aparelhos (Appliance Health & Telemetry)
--------------------------------------------------------------------------------

--- Identifica a categoria do aparelho sanitario ou eletrodomestico
function LV_DirtScoreData.identifyApplianceType(obj)
    if not obj then return nil end
    local spriteName = ""
    pcall(function()
        local sp = obj:getSprite()
        if sp and sp.getName then
            spriteName = tostring(sp:getName() or ""):lower()
        end
    end)

    -- 1. Classes nativas seguras e especificas (NUNCA IsoObject generico)
    if instanceof then
        if instanceof(obj, "IsoToilet") then return "toilet" end
        if instanceof(obj, "IsoStove") then return "stove" end
    end

    -- 2. Keywords no nome do sprite (Ordem de prioridade estrita)
    if spriteName ~= "" then
        local priorityOrder = { "toilet", "sink", "shower", "stove", "bathtub" }
        for _, fType in ipairs(priorityOrder) do
            local data = LV_DirtScoreData.FixturePatterns[fType]
            if data and data.keywords then
                for _, kw in ipairs(data.keywords) do
                    if spriteName:find(kw) then
                        return fType
                    end
                end
            end
        end
    end

    -- 3. Checagem por propriedades do sprite (CustomName / GroupName)
    local propType = nil
    pcall(function()
        local sp = obj:getSprite()
        local props = sp and sp.getProperties and sp:getProperties()
        if props then
            local cName = ""
            local gName = ""
            if props.get then
                local okG, v = pcall(props.get, props, "CustomName")
                if okG and v then cName = tostring(v):lower() end
                local okG2, v2 = pcall(props.get, props, "GroupName")
                if okG2 and v2 then gName = tostring(v2):lower() end
            end
            if cName == "" and props.Val then
                local okV, v = pcall(props.Val, props, "CustomName")
                if okV and v then cName = tostring(v):lower() end
                local okV2, v2 = pcall(props.Val, props, "GroupName")
                if okV2 and v2 then gName = tostring(v2):lower() end
            end
            local checkStr = cName .. " " .. gName
            if checkStr:find("toilet") or checkStr:find("vaso") then propType = "toilet"
            elseif checkStr:find("sink") or checkStr:find("pia") then propType = "sink"
            elseif checkStr:find("shower") or checkStr:find("chuveiro") then propType = "shower"
            elseif checkStr:find("bathtub") or checkStr:find("banheira") then propType = "bathtub"
            elseif checkStr:find("stove") or checkStr:find("oven") or checkStr:find("fogao") then propType = "stove"
            end
        end
    end)
    if propType then return propType end

    return nil
end

--- Retorna a saude/durabilidade atual do aparelho (0 a 100%)
function LV_DirtScoreData.getApplianceHealth(obj)
    if not obj or not obj.getModData then return 100.0 end
    local md = obj:getModData()
    if md.applianceHealth == nil then
        md.applianceHealth = 100.0
    end
    return math.max(0.0, math.min(100.0, tonumber(md.applianceHealth) or 100.0))
end

--- Define a saude/durabilidade do aparelho
function LV_DirtScoreData.setApplianceHealth(obj, val)
    if not obj or not obj.getModData then return end
    local md = obj:getModData()
    md.applianceHealth = math.max(0.0, math.min(100.0, tonumber(val) or 100.0))
    if obj.transmitModData then obj:transmitModData() end
end

--- Aplica desgaste fisico ao aparelho
function LV_DirtScoreData.degradeAppliance(obj, delta)
    if not obj or not obj.getModData then return end
    local wearMult = (LV_Config and LV_Config.getApplianceWearMultiplier and LV_Config.getApplianceWearMultiplier()) or 1.0
    if wearMult <= 0 then return end
    local current = LV_DirtScoreData.getApplianceHealth(obj)
    local actualCost = (tonumber(delta) or 1.0) * wearMult
    local newVal = math.max(0.0, current - actualCost)
    LV_DirtScoreData.setApplianceHealth(obj, newVal)
end

