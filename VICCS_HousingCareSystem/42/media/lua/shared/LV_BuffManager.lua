-- =============================================================================
-- Housing Care System (Lar Vivo) - Buff & Moodlet Engine (LV_BuffManager.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Gerencia os estados de Conforto e Squalor no cliente e servidor.
--   Aplica buffs/debuffs nas estatísticas do personagem de forma 100% segura.
-- =============================================================================

LV_BuffManager = LV_BuffManager or {}

--- Tabela interna com dados de sessão do jogador local
local localPlayerData = {
    comfortScore = 0,
    comfortTier = 0,
    comfortExpiryWorldHour = 0,
    squalorScore = 0,
    squalorTier = 0,
    squalorExpiryWorldHour = 0,
    isInSqualorArea = false,
    baseName = "Lar",
    lastScanHour = -1
}

--- Retorna os dados do jogador ativo de forma segura.
function LV_BuffManager.getPlayerData(player)
    return localPlayerData
end

--- Auxiliar seguro para ler e ajustar campos de Stats no PZ B42.
local function modifyStat(stats, name, delta, minVal, maxVal)
    if not stats then return end
    minVal = minVal or 0.0
    maxVal = maxVal or 1.0

    pcall(function()
        if stats[name] ~= nil then
            local current = stats[name]
            local newval = math.max(minVal, math.min(maxVal, current + delta))
            stats[name] = newval
            return
        end

        local getter = stats["get" .. name]
        local setter = stats["set" .. name]
        if getter and setter then
            local current = getter(stats)
            local newval = math.max(minVal, math.min(maxVal, current + delta))
            setter(stats, newval)
        end
    end)
end

--- Auxiliar seguro para ajustar o nível de infelicidade (Unhappiness) sem quebrar no B42.
local function modifyUnhappiness(bodyDamage, delta)
    if not bodyDamage then return end
    pcall(function()
        if bodyDamage.getUnhappinessLevel and bodyDamage.setUnhappinessLevel then
            local cur = bodyDamage:getUnhappinessLevel()
            bodyDamage:setUnhappinessLevel(math.max(0, math.min(100, cur + delta)))
        elseif bodyDamage.getUnhappynessLevel and bodyDamage.setUnhappynessLevel then
            local cur = bodyDamage:getUnhappynessLevel()
            bodyDamage:setUnhappynessLevel(math.max(0, math.min(100, cur + delta)))
        elseif bodyDamage.UnhappynessLevel ~= nil then
            bodyDamage.UnhappynessLevel = math.max(0, math.min(100, bodyDamage.UnhappynessLevel + delta))
        end
    end)
end

--- Converte uma pontuação de Conforto (0-100) no Tier correspondente (0-4).
function LV_BuffManager.getComfortTierFromScore(score)
    if not score or score <= 0 then return 0 end

    local t1 = (LV_Config and LV_Config.get and LV_Config.get("ComfortTier1Threshold")) or 25
    local t2 = (LV_Config and LV_Config.get and LV_Config.get("ComfortTier2Threshold")) or 50
    local t3 = (LV_Config and LV_Config.get and LV_Config.get("ComfortTier3Threshold")) or 75
    local t4 = (LV_Config and LV_Config.get and LV_Config.get("ComfortTier4Threshold")) or 90

    if score >= t4 then return 4
    elseif score >= t3 then return 3
    elseif score >= t2 then return 2
    elseif score >= t1 then return 1
    else return 0 end
end

--- Converte uma pontuação de Squalor (0-100) no Tier de Debuff correspondente (0-4).
function LV_BuffManager.getSqualorTierFromScore(score)
    if not score or score <= 0 then return 0 end

    local t1 = (LV_Config and LV_Config.get and LV_Config.get("SqualorTier1Threshold")) or 25
    local t2 = (LV_Config and LV_Config.get and LV_Config.get("SqualorTier2Threshold")) or 50
    local t3 = (LV_Config and LV_Config.get and LV_Config.get("SqualorTier3Threshold")) or 75
    local t4 = (LV_Config and LV_Config.get and LV_Config.get("SqualorTier4Threshold")) or 90

    if score >= t4 then return 4
    elseif score >= t3 then return 3
    elseif score >= t2 then return 2
    elseif score >= t1 then return 1
    else return 0 end
end

--- Aplica o resultado consolidado da varredura de ambiente no jogador.
function LV_BuffManager.applyScanResults(player, comfortScore, squalorScore, baseName)
    if not player then return end

    local newComfortTier = LV_BuffManager.getComfortTierFromScore(comfortScore)
    local newSqualorTier = LV_BuffManager.getSqualorTierFromScore(squalorScore)

    local currentHour = getGameTime():getWorldAgeHours()
    local duration = (LV_Config and LV_Config.get and LV_Config.get("BuffBaseDurationHours")) or 8
    local oldComfortTier = localPlayerData.comfortTier
    local oldSqualorTier = localPlayerData.squalorTier

    -- 1. Atualização de Conforto
    localPlayerData.comfortScore = comfortScore
    localPlayerData.comfortTier = newComfortTier
    if baseName and baseName ~= "" then
        localPlayerData.baseName = baseName
    end

    if newComfortTier > 0 then
        localPlayerData.comfortExpiryWorldHour = currentHour + duration
    else
        localPlayerData.comfortExpiryWorldHour = 0
    end

    -- 2. Atualização de Insalubridade (Squalor)
    localPlayerData.squalorScore = squalorScore
    localPlayerData.squalorTier = newSqualorTier
    if newSqualorTier > 0 then
        localPlayerData.isInSqualorArea = true
        localPlayerData.squalorExpiryWorldHour = currentHour + math.floor(duration * 0.5)
    else
        localPlayerData.isInSqualorArea = false
        localPlayerData.squalorExpiryWorldHour = 0
    end

    localPlayerData.lastScanHour = currentHour

    -- 3. Notificações seguras ao mudar de Tier
    if newComfortTier > oldComfortTier and newComfortTier >= 2 then
        pcall(function()
            local text = LV_MoodleDefs.getText("UI_LV_Notification_Comfort", "Lar Aconchegante") .. " (" .. newComfortTier .. ")"
            if player.setHaloNote then
                player:setHaloNote(text, 80, 240, 120, 250)
            end
        end)
    elseif newSqualorTier > oldSqualorTier and newSqualorTier >= 2 then
        pcall(function()
            local text = LV_MoodleDefs.getText("UI_LV_Notification_Squalor", "Ambiente Insalubre") .. " (" .. newSqualorTier .. ")"
            if player.setHaloNote then
                player:setHaloNote(text, 240, 90, 70, 250)
            end
        end)
    end
end

--- Disparado quando o jogador está em área externa/selvagem sem abrigo.
function LV_BuffManager.onUnsafeEnvironment(player)
    localPlayerData.comfortScore = 0
    localPlayerData.comfortTier = 0
    localPlayerData.comfortExpiryWorldHour = 0
    localPlayerData.squalorScore = 0
    localPlayerData.squalorTier = 0
    localPlayerData.isInSqualorArea = false
end

--- Acelera cicatrização natural de ferimentos leves em tiers altos.
local function applyHealingBuff(player)
    if not player then return end
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
local function onPlayerUpdateBuffs(player)
    if not LV_Config or not LV_Config.isEnabled() or not player then return end
    local data = localPlayerData
    if not data then return end

    local currentHour = getGameTime():getWorldAgeHours()
    local stats = player:getStats()
    local bodyDamage = player:getBodyDamage()
    if not stats or not bodyDamage then return end

    local buffMult = (LV_Config and LV_Config.get and LV_Config.get("BuffMagnitudeMultiplier")) or 1.0
    local squalorMult = (LV_Config and LV_Config.get and LV_Config.get("SqualorMagnitudeMultiplier")) or 1.0

    -- =========================================================================
    -- A. EFEITOS POSITIVOS (BUFFS DE CONFORTO)
    -- =========================================================================
    if data.comfortTier > 0 and currentHour < data.comfortExpiryWorldHour then
        local cTier = data.comfortTier

        -- Tier 1+: Redução de Pânico
        modifyStat(stats, "Panic", -(0.15 * buffMult), 0.0, 100.0)

        -- Tier 2+: Regeneração de Endurance & Menor Cansaço
        if cTier >= 2 then
            modifyStat(stats, "Endurance", (0.0002 * buffMult), 0.0, 1.0)

            if LV_Config.get("Enable_Energizado") then
                modifyStat(stats, "Fatigue", -(0.00005 * buffMult), 0.0, 1.0)
            end
        end

        -- Tier 3+: Redução de Infelicidade & Saciado
        if cTier >= 3 then
            modifyUnhappiness(bodyDamage, -(0.05 * buffMult))

            if LV_Config.get("Enable_Saciado") then
                modifyStat(stats, "Hunger", -(0.00004 * buffMult), 0.0, 1.0)
            end

            if LV_Config.get("Enable_CicatrizacaoRapida") then
                applyHealingBuff(player)
            end
        end

        -- Tier 4: Santuário (Redução contínua de Estresse & Cura Avançada)
        if cTier >= 4 then
            modifyStat(stats, "Stress", -(0.02 * buffMult), 0.0, 1.0)
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
            modifyUnhappiness(bodyDamage, (0.02 * squalorMult))
        end

        -- Squalor Tier 2: Ambiente Insalubre (Infelicidade + Estresse + Queda de Stamina)
        if sTier >= 2 then
            modifyStat(stats, "Stress", (0.0003 * squalorMult), 0.0, 1.0)
            modifyStat(stats, "Endurance", -(0.0001 * squalorMult), 0.0, 1.0)
        end

        -- Squalor Tier 3: Antro Imundo (Náusea e Cansaço)
        if sTier >= 3 then
            modifyStat(stats, "Sickness", (0.03 * squalorMult), 0.0, 50.0)
        end

        -- Squalor Tier 4: Foco de Doença (Penalidade severa de saúde geral)
        if sTier >= 4 then
            modifyStat(stats, "Sickness", (0.08 * squalorMult), 0.0, 90.0)
        end
    else
        data.squalorTier = 0
        data.isInSqualorArea = false
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdateBuffs)

print("[LarVivo] LV_BuffManager carregado e ativo!")
