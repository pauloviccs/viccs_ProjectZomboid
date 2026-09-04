-- =============================================================================
-- Housing Care System (Lar Vivo) - Config Layer (LV_Config.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Módulo central responsável por isolar a leitura de SandboxVars e preferências
--   do jogo. Nunca acesse 'SandboxVars' diretamente em outros arquivos; use sempre
--   os getters desta classe para garantir compatibilidade total.
-- =============================================================================

LV_Config = LV_Config or {}

--- Valores padrão (fallback) caso o jogo ou servidor não defina SandboxVars
local DEFAULTS = {
    -- Geral & Aclimatação
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

    -- Duração e Força dos Buffs
    BuffDurationBaseHours = 8.0,
    BuffDurationPerComfortPoint = 0.05,
    BuffDurationMaxHours = 12.0,
    BuffMagnitudeMultiplier = 1.0,

    -- Catálogo Estendido de Buffs (Habilitados por padrão)
    Enable_Energizado = true,
    Enable_Aquecido = true,
    Enable_Saciado = true,
    Enable_CicatrizacaoRapida = true,
    Enable_Alerta = false,
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
    BladderGainPerHour = 2.5,
    BladderGainAfterEatingMultiplier = 1.5,
    BladderNotifyThreshold = 60,
    ToiletDirtPerUsePee = 10.0,
    ToiletDirtPerUsePoop = 25.0,

    -- Manchas Visuais nos Tiles (Sangue e Overlays de Sujeira)
    EnableVisualDirtTiles = true,

    -- Hábitos, Rotinas Táticas & Sazonalidade (Update 2)
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
}

--- Obtém o valor de uma opção de configuração de forma segura com fallback.
function LV_Config.get(key)
    -- 1. Tenta formato de página SandboxVars.HousingCareSystem.Opcao (Padrão B42)
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

--- Verifica se o mod inteiro está ligado.
function LV_Config.isEnabled()
    return LV_Config.get("SystemEnabled") == true
end

--- Verifica se o sistema de conforto/buffs está ativo.
function LV_Config.isComfortEnabled()
    return LV_Config.isEnabled()
end

--- Verifica se o sistema de squalor/insalubridade está ativo.
function LV_Config.isSqualorEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("SqualorSystemEnabled") == true)
end

--- Verifica se o sistema de tarefas domésticas (Homemaking) está ativo.
function LV_Config.isHomemakingEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("HomemakingEnabled") == true)
end

--- Verifica se a exigência de posse/reivindicação de base está ativa (Padrão: True)
function LV_Config.isBaseOwnershipRequired()
    if not LV_Config.isEnabled() then return false end
    if SandboxVars and SandboxVars.HousingCareSystem then
        if SandboxVars.HousingCareSystem.RequireBaseOwnership ~= nil then
            return SandboxVars.HousingCareSystem.RequireBaseOwnership == true
        end
    end
    -- Padrão inegociável: SEMPRE EXIGIR BASE REIVINDICADA (Evita que casas aleatórias dêem buffs)
    return true
end

--- Verifica se o sistema de sujeira dinâmica e faxina está ativo.
function LV_Config.isDirtSystemEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("DirtSystemEnabled") == true)
end

--- Verifica se a necessidade fisiológica está ativa.
function LV_Config.isBladderNeedEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("BladderNeedEnabled") == true)
end

--- Verifica se a geração visual de manchas no piso (sangue e sujeira) está ativa.
function LV_Config.isVisualDirtEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("EnableVisualDirtTiles") == true)
end

--- Retorna o teto máximo de itens 3D por categoria que pontuam em um mesmo cômodo.
function LV_Config.getMax3DItemsPerRoomCategory()
    return tonumber(LV_Config.get("Max3DItemsPerRoomCategory")) or 6
end

--- Retorna o limite de itens 3D inspecionados por tile para otimização de performance.
function LV_Config.getMax3DItemsPerTile()
    return tonumber(LV_Config.get("Max3DItemsPerTile")) or 10
end

--- Verifica se a notificação passiva flutuante de ganho de ambiente está ativa.
function LV_Config.isAmbientItemDropNoticeEnabled()
    return LV_Config.isEnabled() and (LV_Config.get("EnableAmbientItemDropNotice") == true)
end

--- Verifica se a curva de rendimento decrescente está ativa para mobílias e decorações.
function LV_Config.isDiminishingReturnsEnabled()
    return LV_Config.get("EnableDiminishingReturns") ~= false
end


