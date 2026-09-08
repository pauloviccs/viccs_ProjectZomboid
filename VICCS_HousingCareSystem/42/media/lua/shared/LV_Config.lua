-- =============================================================================
-- Housing Care System (Lar Vivo) - Config Layer (LV_Config.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Modulo central responsavel por isolar a leitura de SandboxVars e preferencias
--   do jogo. Nunca acesse 'SandboxVars' diretamente em outros arquivos; use sempre
--   os getters desta classe para garantir compatibilidade total.
-- =============================================================================

LV_Config = LV_Config or {}

--- Valores padrao (fallback) caso o jogo ou servidor nao defina SandboxVars
local DEFAULTS = {
    -- Geral & Aclimatacao
    SystemEnabled = true,
    AcclimatizationMinutes = 30,
    ComfortCheckIntervalHours = 6,
    ComfortRadiusTiles = 15,
    RequireRoofedRoom = true,
    RequireSafehouseClaim = true,
    RequireBaseOwnership = true,

    -- Tiers de Conforto
    Tier1Threshold = 20,
    Tier2Threshold = 40,
    Tier3Threshold = 60,
    Tier4Threshold = 80,

    -- Duracao e Forca dos Buffs
    BuffDurationBaseHours = 8.0,
    BuffDurationPerComfortPoint = 0.05,
    BuffDurationMaxHours = 12.0,
    BuffMagnitudeMultiplier = 1.0,

    -- Catalogo Estendido de Buffs (Habilitados por padrao)
    Enable_Energizado = true,
    Enable_Aquecido = true,
    Enable_Saciado = true,
    Enable_CicatrizacaoRapida = true,
    Enable_Alerta = true,
    AllowLootLuckBuff = false,

    -- Sistema de Squalor (Insalubridade)
    SqualorSystemEnabled = true,
    SqualorOverrideThreshold = 50,
    SqualorTier1Threshold = 20,
    SqualorTier2Threshold = 40,
    SqualorTier3Threshold = 60,
    SqualorTier4Threshold = 80,
    SqualorMagnitudeMultiplier = 1.0,
    SqualorLingerHours = 1.0,

    -- Tarefas Domesticas & Vida Ativa no Lar (Homemaking Engine)
    HomemakingEnabled = true,
    HomemakingBonusScale = 1.0,
    HomemakingMaxBonusHours = 8.0,
    HomemakingCooldownSeconds = 45,

    -- Ciclo de Higiene, Sujeira Dinamica e Faxina (Chores)
    DirtSystemEnabled = true,
    FootDirtGainRate = 1.0,
    FloorDirtTransferRate = 1.0,
    CookingDirtAmount = 1.0,
    ChoreCooldownSeconds = 45,
    DirtToSqualorWeight = 1.0,

    -- Necessidades Fisiologicas (Bladder / Toilet Need)
    BladderNeedEnabled = true,
    BladderGainPerHour = 0.8,
    BladderGainAfterEatingMultiplier = 0.5,
    BladderNotifyThreshold = 70,
    ToiletDirtPerUsePee = 10.0,
    ToiletDirtPerUsePoop = 25.0,

    -- Manchas Visuais nos Tiles (Sangue e Overlays de Sujeira)
    EnableVisualDirtTiles = true,

    -- Habitos, Rotinas Taticas & Sazonalidade (Update 2)
    EnableMorningRoutine = true,
    EnableRoutineStreaks = true,
    EnablePassiveDust = true,
    PassiveDustDailyAmount = 0.8,
    EnableSpotlessBonus = true,
    EnableSeasonalComfort = true,

    -- Infraestrutura, Comunidade & Servidor (Fase 2)
    EnableSocialBonus = true,
    ServerTelemetryEnabled = true,

    -- Matriz de Ambiente, Tetos 3D e Rendimento Decrescente
    Max3DItemsPerRoomCategory = 6,
    Max3DItemsPerTile = 10,
    EnableAmbientItemDropNotice = true,
    EnableDiminishingReturns = true,

    -- Cozimento Real sobre o Fogao (Stovetop Cooking)
    StovetopCookingEnabled = true,
    StovetopCheckIntervalSeconds = 30,
    StovetopFireRiskEnabled = true,
    StovetopCookingSpeedMultiplier = 1.0,

    -- Consumo e Desgaste de Itens e Aparelhos (Sandbox)
    ToiletPaperDrainPercent = 15,
    ToiletFlushWaterDrain = 1.0,
    CleanFloorWaterDrain = 0.25,
    CleanFloorCleanerDrainPercent = 15,
    CleanFloorClothDirtGain = 30,
    CleanFloorClothBloodGain = 25,
    CleanFloorClothWetnessGain = 60,
    CleanFloorToolWearChance = 10,
    CleanFixtureCleanerDrainPercent = 5,
    CleanFixtureClothDirtGain = 15,
    ToothpasteDrainPercent = 10,
    MaintainDuctTapeDrainPercent = 15,
    MaintainScrapAmount = 1,
    MaintainToolWearChance = 5,
    ApplianceWearMultiplier = 1.0,
    ApplianceDirtGainMultiplier = 1.0,
}

--- Obtem o valor de uma opcao de configuracao de forma segura com fallback.
function LV_Config.get(key)
    -- 1. Tenta formato de pagina SandboxVars.HousingCareSystem.Opcao (Padrao B42)
    if SandboxVars and SandboxVars.HousingCareSystem and SandboxVars.HousingCareSystem[key] ~= nil then
        return SandboxVars.HousingCareSystem[key]
    end

    -- 2. Tenta formato plano SandboxVars.LV_Opcao
    if SandboxVars and SandboxVars["LV_" .. key] ~= nil then
        return SandboxVars["LV_" .. key]
    end

    -- 3. Retorna o valor default seguro
    return DEFAULTS[key]
end

--- Verifica se o mod inteiro esta ligado.
function LV_Config.isEnabled()
    return LV_Config.get("SystemEnabled") == true
end

--- Verifica se o sistema de conforto/buffs esta ativo.
function LV_Config.isComfortEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("ComfortEnabled") == true)
end

--- Verifica se o sistema de squalor/insalubridade esta ativo.
function LV_Config.isSqualorEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("SqualorSystemEnabled") == true)
end

--- Verifica se o sistema de tarefas domesticas (Homemaking) esta ativo.
function LV_Config.isHomemakingEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("HomemakingEnabled") == true)
end

--- Verifica se a exigencia de posse/reivindicacao de base esta ativa (Padrao: True)
function LV_Config.isBaseOwnershipRequired()
    if not LV_Config.isEnabled() then return false end
    if SandboxVars and SandboxVars.HousingCareSystem then
        if SandboxVars.HousingCareSystem.RequireBaseOwnership ~= nil then
            return SandboxVars.HousingCareSystem.RequireBaseOwnership == true
        end
    end
    -- Padrao inegociavel: SEMPRE EXIGIR BASE REIVINDICADA (Evita que casas aleatorias deem buffs)
    return true
end

--- Verifica se o sistema de sujeira dinamica e faxina esta ativo.
function LV_Config.isDirtSystemEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("DirtSystemEnabled") == true)
end

--- Verifica se a necessidade fisiologica esta ativa.
function LV_Config.isBladderNeedEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("BladderNeedEnabled") == true)
end

--- Retorna a taxa de ganho passivo de aperto por hora in-game.
function LV_Config.getBladderGainPerHour()
    return math.max(0.0, tonumber(LV_Config.get("BladderGainPerHour")) or 0.8)
end

--- Retorna o multiplicador de ganho de aperto por consumo de comida e agua.
function LV_Config.getBladderGainAfterEatingMultiplier()
    return math.max(0.0, tonumber(LV_Config.get("BladderGainAfterEatingMultiplier")) or 0.5)
end

--- Retorna o limiar percentual de notificacao de aperto.
function LV_Config.getBladderNotifyThreshold()
    return math.max(10, math.min(100, tonumber(LV_Config.get("BladderNotifyThreshold")) or 70))
end

--- Verifica se o bonus de sorte e percepcao de loot (Foco na Exploracao) esta ativo.
function LV_Config.isLootLuckEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("AllowLootLuckBuff") == true)
end

--- Verifica se a geracao visual de manchas no piso (sangue e sujeira) esta ativa.
function LV_Config.isVisualDirtEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("EnableVisualDirtTiles") == true)
end

--- Retorna o teto maximo de itens 3D por categoria que pontuam em um mesmo comodo.
function LV_Config.getMax3DItemsPerRoomCategory()
    return tonumber(LV_Config.get("Max3DItemsPerRoomCategory")) or 6
end

--- Retorna o limite de itens 3D inspecionados por tile para otimizacao de performance.
function LV_Config.getMax3DItemsPerTile()
    return tonumber(LV_Config.get("Max3DItemsPerTile")) or 10
end

--- Verifica se a notificacao passiva flutuante de ganho de ambiente esta ativa.
function LV_Config.isAmbientItemDropNoticeEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("EnableAmbientItemDropNotice") == true)
end

--- Verifica se a curva de rendimento decrescente esta ativa para mobilias e decoracoes.
function LV_Config.isDiminishingReturnsEnabled()
    return LV_Config.get("EnableDiminishingReturns") ~= false
end

--- Verifica se o cozimento real sobre o fogao esta ativo.
function LV_Config.isStovetopCookingEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("StovetopCookingEnabled") ~= false)
end

--- Verifica se o risco de incendio ao queimar comida sobre o fogao esta ativo.
function LV_Config.isStovetopFireRiskEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("StovetopFireRiskEnabled") ~= false)
end

-- =============================================================================
-- Getters de Consumo de Itens, Desgaste e Recursos (Sandbox)
-- =============================================================================

--- Retorna a fracao delta (0.0 a 1.0) consumida de papel higienico por uso.
function LV_Config.getToiletPaperDrain()
    local pct = tonumber(LV_Config.get("ToiletPaperDrainPercent")) or 15
    return math.max(0.0, math.min(1.0, pct / 100.0))
end

--- Retorna a quantidade de agua (litros/unidades) gasta na descarga do vaso.
function LV_Config.getToiletFlushWaterDrain()
    return math.max(0.0, tonumber(LV_Config.get("ToiletFlushWaterDrain")) or 1.0)
end

--- Retorna a quantidade de agua (litros) gasta do balde ao limpar piso.
function LV_Config.getCleanFloorWaterDrain()
    return math.max(0.0, tonumber(LV_Config.get("CleanFloorWaterDrain")) or 0.25)
end

--- Retorna a fracao delta (0.0 a 1.0) consumida de desinfetante ao limpar piso.
function LV_Config.getCleanFloorCleanerDrain()
    local pct = tonumber(LV_Config.get("CleanFloorCleanerDrainPercent")) or 15
    return math.max(0.0, math.min(1.0, pct / 100.0))
end

--- Retorna a quantidade de sujeira adicionada ao pano ao limpar piso.
function LV_Config.getCleanFloorClothDirtGain()
    return math.max(0, math.min(100, tonumber(LV_Config.get("CleanFloorClothDirtGain")) or 30))
end

--- Retorna a quantidade de sangue adicionada ao pano ao limpar piso.
function LV_Config.getCleanFloorClothBloodGain()
    return math.max(0, math.min(100, tonumber(LV_Config.get("CleanFloorClothBloodGain")) or 25))
end

--- Retorna a quantidade de umidade adicionada ao pano ao limpar piso.
function LV_Config.getCleanFloorClothWetnessGain()
    return math.max(0, math.min(100, tonumber(LV_Config.get("CleanFloorClothWetnessGain")) or 60))
end

--- Retorna a chance percentual (0 a 100) de desgaste de vassouras/esfregoes ao limpar piso.
function LV_Config.getCleanFloorToolWearChance()
    return math.max(0, math.min(100, tonumber(LV_Config.get("CleanFloorToolWearChance")) or 10))
end

--- Retorna a fracao delta (0.0 a 1.0) consumida de produto ao higienizar instalacoes/loucas.
function LV_Config.getCleanFixtureCleanerDrain()
    local pct = tonumber(LV_Config.get("CleanFixtureCleanerDrainPercent")) or 5
    return math.max(0.0, math.min(1.0, pct / 100.0))
end

--- Retorna a quantidade de sujeira adicionada ao pano ao higienizar loucas/pias.
function LV_Config.getCleanFixtureClothDirtGain()
    return math.max(0, math.min(100, tonumber(LV_Config.get("CleanFixtureClothDirtGain")) or 15))
end

--- Retorna a fracao delta (0.0 a 1.0) consumida de pasta de dente por escovacao.
function LV_Config.getToothpasteDrain()
    local pct = tonumber(LV_Config.get("ToothpasteDrainPercent")) or 10
    return math.max(0.0, math.min(1.0, pct / 100.0))
end

--- Retorna a fracao delta (0.0 a 1.0) consumida de fita adesiva por manutencao.
function LV_Config.getMaintainDuctTapeDrain()
    local pct = tonumber(LV_Config.get("MaintainDuctTapeDrainPercent")) or 15
    return math.max(0.0, math.min(1.0, pct / 100.0))
end

--- Retorna a quantidade de pecas/sucata consumidas por reparo de aparelho.
function LV_Config.getMaintainScrapAmount()
    return math.max(0, math.min(10, tonumber(LV_Config.get("MaintainScrapAmount")) or 1))
end

--- Retorna a chance percentual (0 a 100) de ferramentas sofrerem desgaste na manutencao.
function LV_Config.getMaintainToolWearChance()
    return math.max(0, math.min(100, tonumber(LV_Config.get("MaintainToolWearChance")) or 5))
end

--- Retorna o multiplicador de desgaste fisico/durabilidade dos aparelhos por uso.
function LV_Config.getApplianceWearMultiplier()
    return math.max(0.0, tonumber(LV_Config.get("ApplianceWearMultiplier")) or 1.0)
end

--- Retorna o multiplicador de sujeira acumulada nos aparelhos por uso.
function LV_Config.getApplianceDirtGainMultiplier()
    return math.max(0.0, tonumber(LV_Config.get("ApplianceDirtGainMultiplier")) or 1.0)
end

