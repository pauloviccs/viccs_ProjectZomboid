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
    RequireSafehouseClaim = false,

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
