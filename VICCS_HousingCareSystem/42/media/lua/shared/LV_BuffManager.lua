-- =============================================================================
-- Housing Care System (Lar Vivo) - Buff & State Lifecycle (LV_BuffManager.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Módulo responsável por gerenciar a aplicação, persistência e decaimento de
--   todos os Tiers de Conforto (1 a 4) e Insalubridade/Squalor (1 a 4).
--
-- Persistência Resiliente (WorldAgeHours):
--   Salva no ModData do jogador os timestamps universais para cálculo de expiração,
--   imune a fast-forward, sono ou desconexão em Multiplayer.
-- =============================================================================

LV_BuffManager = LV_BuffManager or {}

local MODDATA_KEY = "LV_HousingCare"

--- Obtém ou inicializa a tabela de ModData persistente do jogador.
-- @param player (IsoPlayer): Personagem do jogador
-- @return table: Estrutura de dados persistente
function LV_BuffManager.getPlayerData(player)
    if not player then return nil end
    local modData = player:getModData()
    if not modData[MODDATA_KEY] then
        modData[MODDATA_KEY] = {
            comfortScore = 0,
            comfortTier = 0,
            comfortExpiryWorldHour = 0,
            squalorScore = 0,
            squalorTier = 0,
            squalorExpiryWorldHour = 0,
            isInSqualorArea = false,
            lastScanWorldHour = 0,
        }
    end
    return modData[MODDATA_KEY]
end

--- Aplica os resultados consolidados de uma varredura (Comfort e Squalor).
-- @param player (IsoPlayer): Personagem avaliado
-- @param comfortScore (number): Score de 0 a 100
-- @param squalorScore (number): Score de 0 a 100
function LV_BuffManager.applyScanResults(player, comfortScore, squalorScore)
    if not player then return end
    local data = LV_BuffManager.getPlayerData(player)
    local currentHour = getGameTime():getWorldAgeHours()

    data.lastScanWorldHour = currentHour
    data.comfortScore = comfortScore
    data.squalorScore = squalorScore

    local oldComfortTier = data.comfortTier
    local oldSqualorTier = data.squalorTier

    -- 1. Determina o Tier de Conforto (1 a 4)
    local cT1 = LV_Config.get("Tier1Threshold") or 20
    local cT2 = LV_Config.get("Tier2Threshold") or 40
    local cT3 = LV_Config.get("Tier3Threshold") or 60
    local cT4 = LV_Config.get("Tier4Threshold") or 80

    local newComfortTier = 0
    if comfortScore >= cT4 then
        newComfortTier = 4
    elseif comfortScore >= cT3 then
        newComfortTier = 3
    elseif comfortScore >= cT2 then
        newComfortTier = 2
    elseif comfortScore >= cT1 then
        newComfortTier = 1
    end

    data.comfortTier = newComfortTier

    if newComfortTier > 0 then
        -- Calcula duração com teto
        local baseHours = LV_Config.get("BuffDurationBaseHours") or 2.0
        local perPoint = LV_Config.get("BuffDurationPerComfortPoint") or 0.05
        local maxHours = LV_Config.get("BuffDurationMaxHours") or 12.0
        local duration = math.min(maxHours, baseHours + (comfortScore * perPoint))
        data.comfortExpiryWorldHour = currentHour + duration
    else
        data.comfortExpiryWorldHour = 0
    end

    -- 2. Determina o Tier de Squalor (1 a 4)
    local newSqualorTier = 0
    if LV_Config.isSqualorEnabled() then
        local sT1 = LV_Config.get("SqualorTier1Threshold") or 20
        local sT2 = LV_Config.get("SqualorTier2Threshold") or 40
        local sT3 = LV_Config.get("SqualorTier3Threshold") or 60
        local sT4 = LV_Config.get("SqualorTier4Threshold") or 80

        if squalorScore >= sT4 then
            newSqualorTier = 4
        elseif squalorScore >= sT3 then
            newSqualorTier = 3
        elseif squalorScore >= sT2 then
            newSqualorTier = 2
        elseif squalorScore >= sT1 then
            newSqualorTier = 1
        end
    end

    data.squalorTier = newSqualorTier
    data.isInSqualorArea = (newSqualorTier > 0)

    if newSqualorTier > 0 then
        local linger = LV_Config.get("SqualorLingerHours") or 1.0
        data.squalorExpiryWorldHour = currentHour + linger
    else
        data.squalorExpiryWorldHour = 0
    end

    -- 3. Notificações e Animações ao mudar de Tier
    if newComfortTier > oldComfortTier and newComfortTier >= 2 then
        pcall(function()
            local text = LV_MoodleDefs.getText("UI_LV_Notification_Comfort", "Lar Aconchegante") .. " (" .. newComfortTier .. ")"
            if player.setHaloNote then
                player:setHaloNote(text, 80, 240, 120, 250)
            elseif HaloTextHelper and HaloTextHelper.addText then
                HaloTextHelper.addText(player, text)
            end
        end)
    elseif newSqualorTier > oldSqualorTier and newSqualorTier >= 2 then
        pcall(function()
            local text = LV_MoodleDefs.getText("UI_LV_Notification_Squalor", "Ambiente Insalubre") .. " (" .. newSqualorTier .. ")"
            if player.setHaloNote then
                player:setHaloNote(text, 240, 90, 70, 250)
            elseif HaloTextHelper and HaloTextHelper.addText then
                HaloTextHelper.addText(player, text)
            end
        end)
    end
end

--- Reseta imediatamente os buffs caso o jogador esteja em ambiente violado ou inseguro.
-- @param player (IsoPlayer): Personagem afetado
function LV_BuffManager.onUnsafeEnvironment(player)
    local data = LV_BuffManager.getPlayerData(player)
    if not data then return end
    data.comfortScore = 0
    data.comfortTier = 0
    data.comfortExpiryWorldHour = 0
    data.isInSqualorArea = false
end

--- Aplica aceleração na cicatrização de ferimentos leves (Buff Cicatrização Rápida / Resiliente).
-- @param player (IsoPlayer): Personagem
local function applyHealingBuff(player)
    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end
    local bodyParts = bodyDamage:getBodyParts()
    if not bodyParts then return end

    for i = 0, bodyParts:size() - 1 do
        local part = bodyParts:get(i)
        if part then
            pcall(function()
                if part.scratched and part:scratched() then
                    local sTime = part:getScratchTime()
                    if sTime > 0 then part:setScratchTime(math.max(0, sTime - 0.02)) end
                end
                if part.isCut and part:isCut() then
                    local cTime = part:getCutTime()
                    if cTime > 0 then part:setCutTime(math.max(0, cTime - 0.01)) end
                end
                if part.isInfected and part:isInfected() then
                    local iTime = part:getInfectionTime()
                    if iTime and iTime > 0 then part:setInfectionTime(math.max(0, iTime - 0.05)) end
                end
            end)
        end
    end
end

--- Loop de atualização contínua dos efeitos no jogador (Events.OnPlayerUpdate).
-- @param player (IsoPlayer): Personagem ativo
local function onPlayerUpdateBuffs(player)
    if not LV_Config.isEnabled() or not player then return end
    local data = LV_BuffManager.getPlayerData(player)
    if not data then return end

    local currentHour = getGameTime():getWorldAgeHours()
    local stats = player:getStats()
    local bodyDamage = player:getBodyDamage()
    if not stats or not bodyDamage then return end

    local buffMult = LV_Config.get("BuffMagnitudeMultiplier") or 1.0
    local squalorMult = LV_Config.get("SqualorMagnitudeMultiplier") or 1.0

    -- =========================================================================
    -- A. EFEITOS POSITIVOS (BUFFS DE CONFORTO)
    -- =========================================================================
    if data.comfortTier > 0 and currentHour < data.comfortExpiryWorldHour then
        local cTier = data.comfortTier

        -- Tier 1+: Redução de Pânico (Confiante I)
        local panic = stats:getPanic()
        if panic > 0 then
            stats:setPanic(math.max(0, panic - (0.15 * buffMult)))
        end

        -- Tier 2+: Regeneração de Endurance (Descansado I)
        if cTier >= 2 then
            local endurance = stats:getEndurance()
            if endurance < 1.0 then
                stats:setEndurance(math.min(1.0, endurance + (0.0002 * buffMult)))
            end

            -- Catálogo Estendido: Energizado (Menor cansaço)
            if LV_Config.get("Enable_Energizado") then
                local fatigue = stats:getFatigue()
                if fatigue > 0 then
                    stats:setFatigue(math.max(0, fatigue - (0.00005 * buffMult)))
                end
            end
        end

        -- Tier 3+: Redução de Infelicidade / Estabilização (Focado)
        if cTier >= 3 then
            local unhap = bodyDamage:getUnhappynessLevel()
            if unhap > 0 then
                bodyDamage:setUnhappynessLevel(math.max(0, unhap - (0.05 * buffMult)))
            end

            -- Catálogo Estendido: Saciado (Menor ganho de fome)
            if LV_Config.get("Enable_Saciado") then
                local hunger = stats:getHunger()
                if hunger > 0 then
                    stats:setHunger(math.max(0, hunger - (0.00004 * buffMult)))
                end
            end

            -- Catálogo Estendido: Cicatrização Rápida
            if LV_Config.get("Enable_CicatrizacaoRapida") then
                applyHealingBuff(player)
            end
        end

        -- Tier 4: Santuário (Resiliente / Imunidade a estresse)
        if cTier >= 4 then
            local stress = stats:getStress()
            if stress > 0 then
                stats:setStress(math.max(0, stress - (0.02 * buffMult)))
            end
            applyHealingBuff(player)
        end
    else
        data.comfortTier = 0
    end

    -- =========================================================================
    -- B. EFEITOS NEGATIVOS (DEBUFFS DE SQUALOR)
    -- =========================================================================
    if data.squalorTier > 0 and (data.isInSqualorArea or currentHour < data.squalorExpiryWorldHour) then
        local sTier = data.squalorTier

        -- Squalor Tier 1: Enojado I (Leve ganho de infelicidade)
        if sTier >= 1 then
            local unhap = bodyDamage:getUnhappynessLevel()
            if unhap < 100 then
                bodyDamage:setUnhappynessLevel(math.min(100, unhap + (0.02 * squalorMult)))
            end
        end

        -- Squalor Tier 2: Ambiente Insalubre (Infelicidade + Estresse + Queda de Stamina)
        if sTier >= 2 then
            local stress = stats:getStress()
            if stress < 1.0 then
                stats:setStress(math.min(1.0, stress + (0.0003 * squalorMult)))
            end
        end

        -- Squalor Tier 3: Antro Imundo (Náusea e Cansaço)
        if sTier >= 3 then
            local sickness = stats:getSickness()
            if sickness < 50 then
                stats:setSickness(math.min(50, sickness + (0.03 * squalorMult)))
            end
        end

        -- Squalor Tier 4: Foco de Doença (Penalidade severa de saúde geral)
        if sTier >= 4 then
            local sickness = stats:getSickness()
            if sickness < 90 then
                stats:setSickness(math.min(90, sickness + (0.06 * squalorMult)))
            end
        end
    else
        data.squalorTier = 0
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdateBuffs)
