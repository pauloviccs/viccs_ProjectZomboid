-- =============================================================================
-- Housing Care System (Lar Vivo) - Buff & Moodlet Engine (LV_BuffManager.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Gerencia os estados de Conforto, Squalor e Aclimatacao na Base.
--   Aplica buffs/debuffs nas estatisticas do personagem de forma 100% segura.
--   Garante persistencia de 8 horas in-game fora da base.
-- =============================================================================

LV_BuffManager = LV_BuffManager or {}

--- Tabela interna com dados de sessao do jogador local
local localPlayerData = {
    comfortScore = 0,
    comfortTier = 0,
    comfortExpiryWorldHour = 0,
    squalorScore = 0,
    squalorTier = 0,
    squalorExpiryWorldHour = 0,
    isInSqualorArea = false,
    isInShelter = false,
    shelterDwellMinutes = 0,
    targetComfortScore = 0,
    targetSqualorScore = 0,
    lastDwellWorldHour = -1,
    baseName = "Lar",
    lastScanHour = -1,

    -- Dados do Motor de Tarefas Domesticas (Homemaking)
    homemakingBonusHours = 0.0,
    homemakingDailyHours = 0.0,
    homemakingDailyActions = 0,
    homemakingLastDay = -1,

    -- Sazonalidade Tatica & Clima
    seasonalNote = "Clima Estavel"
}

local function resetLocalPlayerData()
    localPlayerData.comfortScore = 0
    localPlayerData.comfortTier = 0
    localPlayerData.comfortExpiryWorldHour = 0
    localPlayerData.squalorScore = 0
    localPlayerData.squalorTier = 0
    localPlayerData.squalorExpiryWorldHour = 0
    localPlayerData.isInSqualorArea = false
    localPlayerData.isInShelter = false
    localPlayerData.shelterDwellMinutes = 0
    localPlayerData.targetComfortScore = 0
    localPlayerData.targetSqualorScore = 0
    localPlayerData.lastDwellWorldHour = -1
    localPlayerData.baseName = "Lar"
    localPlayerData.lastScanHour = -1
    localPlayerData.homemakingBonusHours = 0.0
    localPlayerData.homemakingDailyHours = 0.0
    localPlayerData.homemakingDailyActions = 0
    localPlayerData.homemakingLastDay = -1
    localPlayerData.seasonalNote = "Clima Estavel"
end

local loadedPlayer = nil
local function ensureModDataLoaded(player, force)
    if not player then return end
    if not force and loadedPlayer == player then return end

    resetLocalPlayerData()
    loadedPlayer = player

    local ok, md = pcall(function() return player:getModData() end)
    if ok and md and md.LV_Homemaking then
        local hm = md.LV_Homemaking
        local currentHour = getGameTime():getWorldAgeHours()
        localPlayerData.homemakingBonusHours = hm.bonusHours or 0
        localPlayerData.homemakingDailyHours = hm.dailyHours or 0
        localPlayerData.homemakingDailyActions = hm.dailyActions or 0
        localPlayerData.homemakingLastDay = hm.lastDay or -1
        if hm.comfortExpiryWorldHour and hm.comfortExpiryWorldHour > currentHour then
            localPlayerData.comfortExpiryWorldHour = hm.comfortExpiryWorldHour
        end
    end
end

--- Retorna os dados do jogador ativo de forma segura (puro e direto para a UI).
function LV_BuffManager.getPlayerData(player)
    return localPlayerData
end

Events.OnGameStart.Add(function()
    if isServer and isServer() then return end
    local player = getPlayer and getPlayer()
    if player then ensureModDataLoaded(player, true) end
end)

Events.OnCreatePlayer.Add(function(pNum, player)
    if isServer and isServer() then return end
    if not player and getPlayer then player = getPlayer() end
    if player then ensureModDataLoaded(player, true) end
end)

--- Modificadores diretos e 100% seguros para o PZ B42 sem reflexao dinamica
local function modifyPanic(stats, delta)
    if not stats or not stats.getPanic or not stats.setPanic then return end
    local cur = stats:getPanic()
    stats:setPanic(math.max(0.0, math.min(100.0, cur + delta)))
end

local function modifyEndurance(stats, delta)
    if not stats or not stats.getEndurance or not stats.setEndurance then return end
    local cur = stats:getEndurance()
    stats:setEndurance(math.max(0.0, math.min(1.0, cur + delta)))
end

local function modifyFatigue(stats, delta)
    if not stats or not stats.getFatigue or not stats.setFatigue then return end
    local cur = stats:getFatigue()
    stats:setFatigue(math.max(0.0, math.min(1.0, cur + delta)))
end

local function modifyHunger(stats, delta)
    if not stats or not stats.getHunger or not stats.setHunger then return end
    local cur = stats:getHunger()
    stats:setHunger(math.max(0.0, math.min(1.0, cur + delta)))
end

local function modifyStress(stats, delta)
    if not stats or not stats.getStress or not stats.setStress then return end
    local cur = stats:getStress()
    stats:setStress(math.max(0.0, math.min(1.0, cur + delta)))
end

local function modifySickness(stats, delta)
    if not stats or not stats.getSickness or not stats.setSickness then return end
    local cur = stats:getSickness()
    stats:setSickness(math.max(0.0, math.min(100.0, cur + delta)))
end

--- Auxiliar seguro para ajustar o nivel de infelicidade (Unhappiness) sem quebrar no B42.
local function modifyUnhappiness(bodyDamage, delta)
    if not bodyDamage or not bodyDamage.getUnhappinessLevel or not bodyDamage.setUnhappinessLevel then return end
    local cur = bodyDamage:getUnhappinessLevel()
    bodyDamage:setUnhappinessLevel(math.max(0.0, math.min(100.0, cur + delta)))
end

--- Converte uma pontuacao de Conforto (0-100) no Tier correspondente (0-4).
function LV_BuffManager.getComfortTierFromScore(score)
    if not score or score <= 0 then return 0 end

    local t1 = (LV_Config and LV_Config.get and LV_Config.get("Tier1Threshold")) or 20
    local t2 = (LV_Config and LV_Config.get and LV_Config.get("Tier2Threshold")) or 40
    local t3 = (LV_Config and LV_Config.get and LV_Config.get("Tier3Threshold")) or 60
    local t4 = (LV_Config and LV_Config.get and LV_Config.get("Tier4Threshold")) or 80

    if score >= t4 then return 4
    elseif score >= t3 then return 3
    elseif score >= t2 then return 2
    elseif score >= t1 then return 1
    else return 0 end
end

--- Converte uma pontuacao de Squalor (0-100) no Tier de Debuff correspondente (0-4).
function LV_BuffManager.getSqualorTierFromScore(score)
    if not score or score <= 0 then return 0 end

    local t1 = (LV_Config and LV_Config.get and LV_Config.get("SqualorTier1Threshold")) or 20
    local t2 = (LV_Config and LV_Config.get and LV_Config.get("SqualorTier2Threshold")) or 40
    local t3 = (LV_Config and LV_Config.get and LV_Config.get("SqualorTier3Threshold")) or 60
    local t4 = (LV_Config and LV_Config.get and LV_Config.get("SqualorTier4Threshold")) or 80

    if score >= t4 then return 4
    elseif score >= t3 then return 3
    elseif score >= t2 then return 2
    elseif score >= t1 then return 1
    else return 0 end
end

--- Ativacao dos beneficios apos aclimatacao ou trigger manual
local function activateBuffs(player, comfortScore, squalorScore, duration)
    local currentHour = getGameTime():getWorldAgeHours()
    local newComfortTier = LV_BuffManager.getComfortTierFromScore(comfortScore)
    local newSqualorTier = LV_BuffManager.getSqualorTierFromScore(squalorScore)
    local oldComfortTier = localPlayerData.comfortTier
    local oldSqualorTier = localPlayerData.squalorTier

    localPlayerData.comfortScore = comfortScore
    localPlayerData.comfortTier = newComfortTier
    if newComfortTier > 0 then
        local extraPerPt = (LV_Config and LV_Config.get and LV_Config.get("BuffDurationPerComfortPoint")) or 0.05
        local extraTime = comfortScore * extraPerPt
        local maxDuration = (LV_Config and LV_Config.get and LV_Config.get("BuffDurationMaxHours")) or 12.0
        local totalDuration = math.min(maxDuration, duration + extraTime)
        localPlayerData.comfortExpiryWorldHour = currentHour + totalDuration
    else
        localPlayerData.comfortExpiryWorldHour = 0
    end

    local lingerHours = (LV_Config and LV_Config.get and LV_Config.get("SqualorLingerHours")) or 1.0
    localPlayerData.squalorScore = squalorScore
    localPlayerData.squalorTier = newSqualorTier
    if newSqualorTier > 0 then
        localPlayerData.isInSqualorArea = true
        localPlayerData.squalorExpiryWorldHour = currentHour + lingerHours
    else
        localPlayerData.isInSqualorArea = false
        localPlayerData.squalorExpiryWorldHour = 0
    end

    if newComfortTier > oldComfortTier and newComfortTier >= 2 then
        pcall(function()
            local text = LV_MoodleDefs.getText("UI_LV_Notification_Comfort", "Lar Aconchegante") .. " (" .. newComfortTier .. ")"
            if player.setHaloNote then
                player:setHaloNote(text, 80, 240, 120, 250)
            end
        end)
    end
end

--- Aplica o resultado consolidado da varredura de ambiente no jogador.
function LV_BuffManager.applyScanResults(player, comfortScore, squalorScore, baseName, isManualTrigger, seasonalNote)
    if not player then return end

    local currentHour = getGameTime():getWorldAgeHours()
    local duration = (LV_Config and LV_Config.get and LV_Config.get("BuffDurationBaseHours")) or 8.0
    local reqAcclimatization = (LV_Config and LV_Config.get and LV_Config.get("AcclimatizationMinutes")) or 30

    if baseName and baseName ~= "" then
        localPlayerData.baseName = baseName
    end

    if seasonalNote and seasonalNote ~= "" then
        localPlayerData.seasonalNote = seasonalNote
    end

    local isSafeShelter = (baseName ~= "Imovel Neutro" and baseName ~= "Area Externa" and not tostring(baseName):find("Nao Reivindicado"))

    if isSafeShelter then
        localPlayerData.isInShelter = true
        localPlayerData.targetComfortScore = comfortScore
        localPlayerData.targetSqualorScore = squalorScore

        -- Sincronizacao Imediata de Squalor (Insalubridade decai e atualiza mesmo com Conforto = 0)
        local newSqualorTier = LV_BuffManager.getSqualorTierFromScore(squalorScore)
        localPlayerData.squalorScore = squalorScore
        localPlayerData.squalorTier = newSqualorTier
        if newSqualorTier > 0 then
            localPlayerData.isInSqualorArea = true
            local lingerHours = (LV_Config and LV_Config.get and LV_Config.get("SqualorLingerHours")) or 1.0
            localPlayerData.squalorExpiryWorldHour = currentHour + lingerHours
        else
            localPlayerData.isInSqualorArea = false
            localPlayerData.squalorExpiryWorldHour = 0
        end

        if comfortScore > 0 then
            -- Se a aclimatacao for 0 ou se for trigger manual (K) ou se ja estiver aclimatado
            if reqAcclimatization <= 0 or isManualTrigger or localPlayerData.shelterDwellMinutes >= reqAcclimatization or localPlayerData.comfortTier > 0 then
                localPlayerData.shelterDwellMinutes = reqAcclimatization
                activateBuffs(player, comfortScore, squalorScore, duration)
            else
                -- Inicializa contador de aclimatacao
                if localPlayerData.lastDwellWorldHour == -1 then
                    localPlayerData.lastDwellWorldHour = currentHour
                end
            end
        else
            -- Conforto nulo (comodo sem moveis ou anulado por insalubridade severa)
            localPlayerData.comfortScore = 0
            localPlayerData.comfortTier = 0
            localPlayerData.comfortExpiryWorldHour = 0
        end
    else
        localPlayerData.isInShelter = false
        localPlayerData.targetComfortScore = 0
        localPlayerData.targetSqualorScore = 0
        localPlayerData.shelterDwellMinutes = 0
        localPlayerData.lastDwellWorldHour = -1
        LV_BuffManager.onUnsafeEnvironment(player)
    end

    localPlayerData.lastScanHour = currentHour
end

--- Disparado quando o jogador esta em area externa/selvagem fora de abrigo ou em imovel neutro.
function LV_BuffManager.onUnsafeEnvironment(player)
    local currentHour = getGameTime():getWorldAgeHours()
    localPlayerData.isInShelter = false
    localPlayerData.targetComfortScore = 0
    localPlayerData.targetSqualorScore = 0
    localPlayerData.shelterDwellMinutes = 0
    localPlayerData.lastDwellWorldHour = -1

    -- Ao sair de abrigo, o debuff de squalor nao zera instantaneamente: persiste por SqualorLingerHours
    if localPlayerData.isInSqualorArea then
        localPlayerData.isInSqualorArea = false
        local lingerHours = (LV_Config and LV_Config.get and LV_Config.get("SqualorLingerHours")) or 1.0
        if lingerHours > 0 then
            localPlayerData.squalorExpiryWorldHour = currentHour + lingerHours
        else
            localPlayerData.squalorScore = 0
            localPlayerData.squalorTier = 0
            localPlayerData.squalorExpiryWorldHour = 0
        end
    elseif currentHour >= localPlayerData.squalorExpiryWorldHour then
        localPlayerData.squalorScore = 0
        localPlayerData.squalorTier = 0
        localPlayerData.squalorExpiryWorldHour = 0
    end

    -- Se o jogador nao possui base oficial no SP, anula buffs remanescentes imediatamente
    local pMd = player and player.getModData and player:getModData()
    local hasClaimedBase = (pMd and pMd.LV_ClaimedBaseBuildingId ~= nil)
    if not hasClaimedBase and (not isClient or not isClient()) then
        localPlayerData.comfortScore = 0
        localPlayerData.comfortTier = 0
        localPlayerData.comfortExpiryWorldHour = 0
        local traits = player and player.getTraits and player:getTraits()
        if traits and pMd and pMd.LV_GrantedLuckyTrait then
            traits:remove("Lucky")
            pMd.LV_GrantedLuckyTrait = nil
        end
    elseif currentHour >= localPlayerData.comfortExpiryWorldHour then
        localPlayerData.comfortScore = 0
        localPlayerData.comfortTier = 0
        localPlayerData.comfortExpiryWorldHour = 0
        local traits = player and player.getTraits and player:getTraits()
        if traits and pMd and pMd.LV_GrantedLuckyTrait then
            traits:remove("Lucky")
            pMd.LV_GrantedLuckyTrait = nil
        end
    end
    localPlayerData.isInSqualorArea = false
end

--- Concede bonus de extensao de tempo e reforco de conforto por tarefas domesticas no lar.
function LV_BuffManager.addHomemakingBonus(player, category, bonusPercent)
    if not player or not LV_Config or not LV_Config.isHomemakingEnabled() then return 0 end
    bonusPercent = bonusPercent or 15

    local currentHour = getGameTime():getWorldAgeHours()
    local scale = (LV_Config and LV_Config.get and LV_Config.get("HomemakingBonusScale")) or 1.0
    local maxBonusCap = (LV_Config and LV_Config.get and LV_Config.get("HomemakingMaxBonusHours")) or 8.0
    local baseDuration = (LV_Config and LV_Config.get and LV_Config.get("BuffDurationBaseHours")) or 8.0

    -- 1. Verifica virada de dia in-game para reset do cap diario
    local currentDay = math.floor(currentHour / 24)
    if localPlayerData.homemakingLastDay ~= currentDay then
        localPlayerData.homemakingLastDay = currentDay
        localPlayerData.homemakingDailyHours = 0.0
        localPlayerData.homemakingDailyActions = 0
    end

    -- 2. Se ja atingiu o teto diario de bonus por tarefas
    if localPlayerData.homemakingDailyHours >= maxBonusCap then
        return 0
    end

    -- 3. Calcula o incremento em horas
    local rawIncrement = baseDuration * (bonusPercent / 100.0) * scale
    local allowedIncrement = math.min(rawIncrement, maxBonusCap - localPlayerData.homemakingDailyHours)
    if allowedIncrement <= 0 then return 0 end

    -- 4. Se o jogador ainda nao tem expiracao ativa, mas esta em abrigo com pontuacao
    if localPlayerData.comfortExpiryWorldHour <= currentHour then
        if localPlayerData.targetComfortScore > 0 or localPlayerData.comfortScore > 0 then
            local score = math.max(localPlayerData.targetComfortScore, localPlayerData.comfortScore)
            activateBuffs(player, score, localPlayerData.squalorScore, baseDuration)
        elseif localPlayerData.comfortTier > 0 then
            localPlayerData.comfortExpiryWorldHour = currentHour + baseDuration
        else
            -- Ativa ao menos Tier 1 temporario pelo cuidado com a base
            activateBuffs(player, 25, 0, baseDuration)
        end
    end

    -- 5. Estende a expiracao com teto seguro
    local maxDurationAbsolute = (LV_Config and LV_Config.get and LV_Config.get("BuffDurationMaxHours")) or 12.0
    local maxAllowedExpiry = currentHour + maxDurationAbsolute + maxBonusCap
    local baseExpiry = math.max(currentHour, localPlayerData.comfortExpiryWorldHour)
    local newExpiry = math.min(maxAllowedExpiry, baseExpiry + allowedIncrement)
    local actualAdded = math.max(0, newExpiry - baseExpiry)

    if actualAdded > 0 then
        localPlayerData.comfortExpiryWorldHour = newExpiry
        localPlayerData.homemakingBonusHours = (localPlayerData.homemakingBonusHours or 0) + actualAdded
        localPlayerData.homemakingDailyHours = (localPlayerData.homemakingDailyHours or 0) + actualAdded
        localPlayerData.homemakingDailyActions = (localPlayerData.homemakingDailyActions or 0) + 1

        -- Sincroniza com ModData do personagem para persistencia universal
        pcall(function()
            local modData = player:getModData()
            if modData then
                modData.LV_Homemaking = {
                    bonusHours = localPlayerData.homemakingBonusHours,
                    dailyHours = localPlayerData.homemakingDailyHours,
                    dailyActions = localPlayerData.homemakingDailyActions,
                    lastDay = localPlayerData.homemakingLastDay,
                    comfortExpiryWorldHour = localPlayerData.comfortExpiryWorldHour
                }
            end
        end)
        return actualAdded
    end

    return 0
end

--- Retorna os dados consolidados de Homemaking para UI e diagnosticos.
function LV_BuffManager.getHomemakingData(player)
    return {
        bonusHours = localPlayerData.homemakingBonusHours or 0,
        dailyHours = localPlayerData.homemakingDailyHours or 0,
        dailyActions = localPlayerData.homemakingDailyActions or 0,
        maxDailyCap = (LV_Config and LV_Config.get and LV_Config.get("HomemakingMaxBonusHours")) or 8.0
    }
end


--- Acelera cicatrizacao natural de ferimentos leves em tiers altos.
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

--- Atualiza a concessao da trait nativa Lucky caso o buff Foco na Exploracao esteja ativo.
local function updateLuckyTrait(player, cTier)
    if not player or player:isDead() then return end
    local traits = player.getTraits and player:getTraits()
    if not traits then return end

    local pMd = player.getModData and player:getModData()
    if not pMd then return end

    local lootLuckEnabled = (LV_Config and LV_Config.isLootLuckEnabled and LV_Config.isLootLuckEnabled())
    if lootLuckEnabled and cTier >= 2 then
        if not player:HasTrait("Lucky") then
            traits:add("Lucky")
            pMd.LV_GrantedLuckyTrait = true
        end
    else
        if pMd.LV_GrantedLuckyTrait then
            traits:remove("Lucky")
            pMd.LV_GrantedLuckyTrait = nil
        end
    end
end

--- Regula a temperatura corporal e reduz a progressao de resfriados (Tier 2+: Conforto Termico / Aquecido).
local function applyThermalBuff(player, bodyDamage)
    if not player or not bodyDamage then return end
    pcall(function()
        -- 1. Regula temperatura corporal em direcao a 37.0C apenas se estiver com frio.
        -- Evita hipertermia: nunca adiciona calor se ja estiver a 37.0C ou mais.
        if bodyDamage.getTemperature and bodyDamage.setTemperature then
            local curTemp = bodyDamage:getTemperature()
            if curTemp and curTemp < 37.0 then
                bodyDamage:setTemperature(math.min(37.0, curTemp + 0.015))
            end
        end

        -- Thermoregulator (Project Zomboid B41 / B42)
        local thermo = bodyDamage.getThermoregulator and bodyDamage:getThermoregulator()
        if thermo and thermo.setCoreTemperature and thermo.getCoreTemperature then
            local coreT = thermo:getCoreTemperature()
            if coreT and coreT < 37.0 then
                thermo:setCoreTemperature(math.min(37.0, coreT + 0.015))
            end
        end

        -- 2. Mitiga progressao e severidade de resfriados / gripe
        if bodyDamage.getCatchACold and bodyDamage.setCatchACold then
            local coldProg = bodyDamage:getCatchACold()
            if coldProg and coldProg > 0 then
                bodyDamage:setCatchACold(math.max(0.0, coldProg - 0.05))
            end
        end

        if bodyDamage.getColdStrength and bodyDamage.setColdStrength then
            local coldStr = bodyDamage:getColdStrength()
            if coldStr and coldStr > 0 then
                bodyDamage:setColdStrength(math.max(0.0, coldStr - 0.03))
            end
        end
    end)
end

--- Reduz estresse agudo e panico em situacao de combate/mira (Tier 4: Foco e Calma em Combate / Alerta).
local function applyCombatAlertnessBuff(player, stats, buffMult)
    if not player or not stats then return end
    buffMult = buffMult or 1.0
    pcall(function()
        local isAiming = player.isAiming and player:isAiming()
        local curPanic = (stats.getPanic and stats:getPanic()) or 0

        -- Se estiver em postura de combate (mirando) ou sob ataque com panico ativo
        if isAiming or curPanic > 0 then
            -- Drena panico para estabilizar as maos e recuperar precisao/dano critico
            modifyPanic(stats, -(0.45 * buffMult))
            -- Reduz estresse agudo de combate
            modifyStress(stats, -(0.005 * buffMult))
        end
    end)
end

--- Loop de atualizacao continua dos efeitos no jogador (Events.OnPlayerUpdate).
local function onPlayerUpdateBuffs(player)
    if not LV_Config or not LV_Config.isEnabled() or not player then return end
    local data = localPlayerData
    if not data then return end

    local currentHour = getGameTime():getWorldAgeHours()

    -- 1. Gerenciamento de Aclimatacao Continua na Base
    if data.isInShelter and data.comfortTier == 0 and data.targetComfortScore > 0 then
        local reqAcclimatization = (LV_Config and LV_Config.get and LV_Config.get("AcclimatizationMinutes")) or 30
        if data.lastDwellWorldHour ~= -1 then
            local deltaHours = math.max(0, currentHour - data.lastDwellWorldHour)
            data.shelterDwellMinutes = data.shelterDwellMinutes + (deltaHours * 60.0)
            data.lastDwellWorldHour = currentHour

            if data.shelterDwellMinutes >= reqAcclimatization then
                local duration = (LV_Config and LV_Config.get and LV_Config.get("BuffDurationBaseHours")) or 8.0
                activateBuffs(player, data.targetComfortScore, data.targetSqualorScore, duration)
                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote("Living House: Corpo Relaxado! Bonus de Lar Ativado", 80, 255, 140, 250)
                    end
                end)
            end
        else
            data.lastDwellWorldHour = currentHour
        end
    end

    local stats = player:getStats()
    local bodyDamage = player:getBodyDamage()
    if not stats or not bodyDamage then return end

    local buffMult = (LV_Config and LV_Config.get and LV_Config.get("BuffMagnitudeMultiplier")) or 1.0
    local squalorMult = (LV_Config and LV_Config.get and LV_Config.get("SqualorMagnitudeMultiplier")) or 1.0

    -- =========================================================================
    -- A. EFEITOS POSITIVOS (BUFFS DE CONFORTO DURANTE O RELOGIO DO JOGO)
    -- =========================================================================
    if data.comfortTier > 0 and currentHour < data.comfortExpiryWorldHour then
        local cTier = data.comfortTier

        -- Tier 1+: Reducao de Panico
        modifyPanic(stats, -(0.15 * buffMult))

        -- Tier 2+: Regeneracao de Endurance & Menor Cansaco & Conforto Termico
        if cTier >= 2 then
            modifyEndurance(stats, (0.0002 * buffMult))

            if LV_Config.get("Enable_Energizado") then
                modifyFatigue(stats, -(0.00005 * buffMult))
            end

            if LV_Config.get("Enable_Aquecido") then
                applyThermalBuff(player, bodyDamage)
            end
        end

        -- Tier 3+: Reducao de Infelicidade & Saciado
        if cTier >= 3 then
            modifyUnhappiness(bodyDamage, -(0.05 * buffMult))

            if LV_Config.get("Enable_Saciado") then
                modifyHunger(stats, -(0.00004 * buffMult))
            end

            if LV_Config.get("Enable_CicatrizacaoRapida") then
                applyHealingBuff(player)
            end
        end

        -- Tier 4: Santuario (Reducao continua de Estresse, Cura Avancada & Foco/Alerta em Combate)
        if cTier >= 4 then
            modifyStress(stats, -(0.02 * buffMult))
            applyHealingBuff(player)

            if LV_Config.get("Enable_Alerta") then
                applyCombatAlertnessBuff(player, stats, buffMult)
            end
        end

        -- Buff Opcional: Foco na Exploracao (Loot Luck Nativo)
        updateLuckyTrait(player, cTier)
    else
        data.comfortTier = 0
        updateLuckyTrait(player, 0)
    end

    -- =========================================================================
    -- B. EFEITOS NEGATIVOS (DEBUFFS DE SQUALOR)
    -- =========================================================================
    if data.squalorTier > 0 and (data.isInSqualorArea or currentHour < data.squalorExpiryWorldHour) then
        local sTier = data.squalorTier

        if sTier >= 1 then
            modifyUnhappiness(bodyDamage, (0.02 * squalorMult))
        end

        if sTier >= 2 then
            modifyStress(stats, (0.0003 * squalorMult))
            modifyEndurance(stats, -(0.0001 * squalorMult))
        end

        if sTier >= 3 then
            modifySickness(stats, (0.03 * squalorMult))
        end

        if sTier >= 4 then
            modifySickness(stats, (0.08 * squalorMult))
        end
    else
        data.squalorTier = 0
        data.squalorScore = 0
        data.isInSqualorArea = false
        data.squalorExpiryWorldHour = 0
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdateBuffs)

print("[LarVivo] LV_BuffManager carregado e ativo com sistema de aclimatacao e persistencia in-game!")
