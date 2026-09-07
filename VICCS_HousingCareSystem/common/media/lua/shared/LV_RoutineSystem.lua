-- =============================================================================
-- Housing Care System (Living House) - Routine & Habits Engine (LV_RoutineSystem.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Modulo responsavel pela simulacao de habitos humanos e rotinas taticas:
--   1. "Manha Aconchegante" (Micro-rotina: Sono reparador -> Lavar rosto -> Cafe/Cha)
--      Concede resistencia a cansaco e recuperacao de estamina ate o inicio da tarde.
--   2. "Rotina Estabelecida" (Streaks de longo prazo):
--      Manter a base em Tier 3+ por 3+ dias consecutivos concede buff permanente
--      de moral que persiste mesmo durante expedicoes de saque externas.
--   3. "Casa Impecavel" (Focus Boost):
--      Ambiente com Squalor < 5% e Tier 3+ acelera aprendizado e leitura de livros.
-- =============================================================================

require "LV_Config"
require "LV_MoodleDefs"

LV_RoutineSystem = LV_RoutineSystem or {}

--- Retorna os dados de rotina salvos no ModData do jogador
function LV_RoutineSystem.getRoutineData(player)
    if not player or not player.getModData then return {} end
    local md = player:getModData()
    if not md.LV_Routine then
        md.LV_Routine = {
            awakeHour = -1,
            washedFace = false,
            drankHotDrink = false,
            morningCozyExpiryHour = -1,
            streakDays = 0,
            lastStreakCheckDay = -1,
            streakActive = false,
            daysDegraded = 0,
            spotlessActive = false,
        }
    end
    return md.LV_Routine
end

--- Chamado pelo LV_SleepRevitalize quando o sobrevivente acorda
function LV_RoutineSystem.onWakeUp(player, hoursSlept, hadBed, hadPillow, isClean)
    if not player or not LV_Config or not LV_Config.isEnabled() then return end
    if not LV_Config.get("EnableMorningRoutine") then return end

    local currentHour = getGameTime():getWorldAgeHours()
    local data = LV_RoutineSystem.getRoutineData(player)

    -- Qualifica para o ritual matinal se dormiu ao menos 5.5h em cama e nao estava imundo
    if hoursSlept >= 5.5 and hadBed and isClean then
        data.awakeHour = currentHour
        data.washedFace = false
        data.drankHotDrink = false

        print(string.format("[LivingHouse] Sobrevivente iniciou janela de rotina matinal na hora %.2f in-game.", currentHour))

        pcall(function()
            if player.setHaloNote then
                player:setHaloNote("Living House: Despertou revigorado! Hora da higiene matinal...", 100, 230, 180, 250)
            end
        end)
    else
        data.awakeHour = -1
    end
end

--- Chamado quando o jogador lava o rosto ou toma banho
function LV_RoutineSystem.onWash(player)
    if not player or not LV_Config or not LV_Config.isEnabled() then return end
    if not LV_Config.get("EnableMorningRoutine") then return end

    local data = LV_RoutineSystem.getRoutineData(player)
    if data.awakeHour == -1 then return end

    local currentHour = getGameTime():getWorldAgeHours()
    local hoursSinceWake = currentHour - data.awakeHour

    -- Janela de ate 3 horas in-game apos acordar
    if hoursSinceWake >= 0 and hoursSinceWake <= 3.5 and not data.washedFace then
        data.washedFace = true
        print("[LivingHouse] Rotina Matinal: Higiene facial concluida com sucesso!")

        pcall(function()
            if player.setHaloNote then
                player:setHaloNote("Living House: Rosto Lavado! Sensacao de Refresco (Falta o Cafe/Cha)", 120, 240, 220, 280)
            end
        end)
    end
end

--- Verifica se um alimento/bebida e cafe, cha ou bebida quente
local function isCaffeineOrHotDrink(food)
    if not food then return false end

    local itemType = ""
    if food.getType then
        local ok, res = pcall(food.getType, food)
        if ok and res then itemType = tostring(res):lower() end
    end
    local itemFull = ""
    if food.getFullType then
        local ok, res = pcall(food.getFullType, food)
        if ok and res then itemFull = tostring(res):lower() end
    end
    local itemName = ""
    if food.getName then
        local ok, res = pcall(food.getName, food)
        if ok and res then itemName = tostring(res):lower() end
    end

    if itemType:find("coffee") or itemType:find("tea") or itemType:find("hotcup") or
       itemType:find("mugl") or itemType:find("cup") or
       itemFull:find("coffee") or itemFull:find("tea") or
       itemName:find("caf") or itemName:find("ch") or itemName:find("coffee") or itemName:find("tea") then
        return true
    end

    return false
end

--- Ativa o buff "Manha Aconchegante"
local function activateMorningCozy(player, data)
    local currentHour = getGameTime():getWorldAgeHours()
    local gt = getGameTime()
    local timeOfDay = gt:getTimeOfDay() -- hora do dia de 0 a 24

    -- Duracao ate as 14:00 ou minimo de 4 horas in-game
    local hoursUntilTwoPM = 14.0 - timeOfDay
    if hoursUntilTwoPM < 3.0 then hoursUntilTwoPM = 5.0 end
    local duration = math.max(4.0, math.min(8.0, hoursUntilTwoPM))

    data.morningCozyExpiryHour = currentHour + duration
    data.drankHotDrink = true

    -- Efeitos imediatos no sobrevivente
    local stats = player.getStats and player:getStats()
    if stats then
        pcall(function()
            if stats.getFatigue and stats.setFatigue then
                stats:setFatigue(math.max(0.0, stats:getFatigue() - 0.12))
            end
            if stats.getEndurance and stats.setEndurance then
                stats:setEndurance(math.min(1.0, stats:getEndurance() + 0.30))
            end
            if stats.getStress and stats.setStress then
                stats:setStress(math.max(0.0, stats:getStress() - 0.15))
            end
        end)
    end

    pcall(function()
        if player.playSound then player:playSound("GainExperienceLevel") end
        if player.setHaloNote then
            player:setHaloNote("Living House: Manha Aconchegante Ativada! Vigor e Foco!", 80, 255, 140, 320)
        end
    end)

    print(string.format("[LivingHouse] Buff Manha Aconchegante ativado! Valido ate a hora %.2f (duracao %.1fh).", data.morningCozyExpiryHour, duration))
end

--- Chamado ao consumir comida/bebida
function LV_RoutineSystem.onEatFood(player, food)
    if not player or not LV_Config or not LV_Config.isEnabled() then return end
    if not LV_Config.get("EnableMorningRoutine") then return end

    local data = LV_RoutineSystem.getRoutineData(player)
    if data.awakeHour == -1 then return end

    local currentHour = getGameTime():getWorldAgeHours()
    local hoursSinceWake = currentHour - data.awakeHour

    -- Janela de ate 4 horas in-game apos acordar
    if hoursSinceWake >= 0 and hoursSinceWake <= 4.0 then
        if isCaffeineOrHotDrink(food) then
            if data.washedFace then
                activateMorningCozy(player, data)
            else
                -- Bebeu cafe sem lavar o rosto: ritual incompleto, concede beneficio menor
                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote("Living House: Cafe Quente! (Ritual incompleto: faltou lavar o rosto)", 220, 200, 100, 250)
                    end
                end)
            end
        end
    end
end

--- Checagem diaria de Streaks ("Rotina Estabelecida")
function LV_RoutineSystem.checkDailyStreak(player)
    if not player or not LV_Config or not LV_Config.isEnabled() then return end
    if not LV_Config.get("EnableRoutineStreaks") then return end

    local gt = getGameTime()
    local currentDay = gt:getNightsSurvived()
    local data = LV_RoutineSystem.getRoutineData(player)

    if data.lastStreakCheckDay == currentDay then return end
    data.lastStreakCheckDay = currentDay

    local buffData = LV_BuffManager and LV_BuffManager.getPlayerData and LV_BuffManager.getPlayerData(player)
    local comfortTier = buffData and buffData.comfortTier or 0
    local squalorTier = buffData and buffData.squalorTier or 0

    -- Safehouse mantida com excelencia (Tier 3+ e sem squalor critico)
    if comfortTier >= 3 and squalorTier <= 1 then
        data.streakDays = (data.streakDays or 0) + 1
        data.daysDegraded = 0

        print(string.format("[LivingHouse] Streak de Rotina aumentado para %d dias consecutivos!", data.streakDays))

        if data.streakDays >= 3 then
            if not data.streakActive then
                data.streakActive = true
                pcall(function()
                    if player.playSound then player:playSound("GainExperienceLevel") end
                    if player.setHaloNote then
                        player:setHaloNote(string.format("Living House: Rotina Estabelecida (%d dias)! Mente Blindada", data.streakDays), 100, 255, 200, 320)
                    end
                end)
            else
                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote(string.format("Living House: Rotina Mantida (Streak: %d dias)", data.streakDays), 120, 240, 180, 220)
                    end
                end)
            end
        end
    else
        -- Base negligenciada
        data.daysDegraded = (data.daysDegraded or 0) + 1
        -- Se Squalor Tier >= 3: perda abrupta de streak com aviso sonoro/halo
        if squalorTier >= 3 then
            if data.streakActive or (data.streakDays and data.streakDays > 0) then
                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote("Living House: Lar Degradado! O abandono extremo zerou sua rotina!", 255, 60, 50, 320)
                    end
                end)
                data.streakActive = false
                data.streakDays = 0
            end
        elseif data.daysDegraded >= 2 then
            if data.streakActive then
                data.streakActive = false
                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote("Living House: Rotina Quebrada! (Base negligenciada)", 240, 100, 80, 280)
                    end
                end)
            end
            data.streakDays = math.max(0, (data.streakDays or 0) - 1)
        end
    end
end

--- Atualizacao continua dos buffs de rotina no jogador (Events.OnPlayerUpdate)
function LV_RoutineSystem.updateRoutineEffects(player)
    if not player or not LV_Config or not LV_Config.isEnabled() then return end

    local currentHour = getGameTime():getWorldAgeHours()
    local data = LV_RoutineSystem.getRoutineData(player)
    local stats = player.getStats and player:getStats()
    local bd = player.getBodyDamage and player:getBodyDamage()

    -- 1. Efeitos do buff "Manha Aconchegante" (ate expirar as 14:00 / fim da duracao)
    if data.morningCozyExpiryHour and currentHour < data.morningCozyExpiryHour then
        if stats then
            pcall(function()
                -- Atraso suave no acumulo de cansaco (Fatigue)
                if stats.getFatigue and stats.setFatigue then
                    local f = stats:getFatigue()
                    if f > 0.05 then
                        stats:setFatigue(math.max(0.0, f - 0.00008))
                    end
                end
                -- Regeneracao continua de Estamina (Endurance)
                if stats.getEndurance and stats.setEndurance then
                    local e = stats:getEndurance()
                    if e < 0.95 then
                        stats:setEndurance(math.min(1.0, e + 0.00025))
                    end
                end
            end)
        end
    end

    -- 2. Efeitos da "Rotina Estabelecida" (Streak de 3+ dias ativo)
    -- PERSISTENTE: Nao some ao sair da base em incursoes de saque!
    if data.streakActive and data.streakDays and data.streakDays >= 3 then
        if stats and bd then
            pcall(function()
                -- Reducao constante de panico
                if stats.getPanic and stats.setPanic then
                    local p = stats:getPanic()
                    if p > 0 then stats:setPanic(math.max(0.0, p - 0.10)) end
                end
                -- Reducao constante de estresse
                if stats.getStress and stats.setStress then
                    local s = stats:getStress()
                    if s > 0 then stats:setStress(math.max(0.0, s - 0.0001)) end
                end
                -- Reducao de infelicidade / depressao
                if bd.getUnhappinessLevel and bd.setUnhappinessLevel then
                    local u = bd:getUnhappinessLevel()
                    if u > 0 then bd:setUnhappinessLevel(math.max(0.0, u - 0.02)) end
                end
            end)
        end
    end

    -- 3. Efeito do buff "Casa Impecavel" (Spotless Home)
    -- Concede bonus de foco e aprendizado acelerado ao ler livros dentro de base limpa
    local buffData = LV_BuffManager and LV_BuffManager.getPlayerData and LV_BuffManager.getPlayerData(player)
    if buffData and buffData.isInShelter and buffData.comfortTier >= 3 and (buffData.squalorScore or 0) < 5.0 then
        data.spotlessActive = true

        -- Se estiver lendo livros de habilidade
        if player.isReading and player:isReading() then
            if bd and bd.setBoredomLevel and bd.getBoredomLevel then
                pcall(function()
                    bd:setBoredomLevel(math.max(0.0, bd:getBoredomLevel() - 0.10))
                end)
            end
            if stats and stats.setStress and stats.getStress then
                pcall(function()
                    stats:setStress(math.max(0.0, stats:getStress() - 0.0002))
                end)
            end
        end
    else
        data.spotlessActive = false
    end

    -- 4. Vida Social / Companhia Ativa no Lar (Multiplayer)
    if LV_Config.get("EnableSocialBonus") then
        local now = (getTimeInMillis and getTimeInMillis() / 1000.0) or os.time()
        if (now - (data.lastSocialCheckTime or 0)) >= 3.0 then
            data.lastSocialCheckTime = now
            local pSq = player:getCurrentSquare()
            local count = 0
            if pSq then
                local room = pSq:getRoom()
                pcall(function()
                    if isClient and isClient() then
                        local pList = getOnlinePlayers and getOnlinePlayers()
                        if pList and pList.size then
                            for p = 0, pList:size() - 1 do
                                local other = pList:get(p)
                                if other and not other:isDead() and other ~= player then
                                    local oSq = other:getCurrentSquare()
                                    if oSq then
                                        if room and oSq:getRoom() == room then
                                            count = count + 1
                                        elseif not room and math.abs(oSq:getX() - pSq:getX()) <= 10 and math.abs(oSq:getY() - pSq:getY()) <= 10 then
                                            count = count + 1
                                        end
                                    end
                                end
                            end
                        end
                    else
                        local numPlayers = (getNumActivePlayers and getNumActivePlayers()) or 1
                        for p = 0, numPlayers - 1 do
                            local other = (getSpecificPlayer and getSpecificPlayer(p)) or getPlayer()
                            if other and not other:isDead() and other ~= player then
                                local oSq = other:getCurrentSquare()
                                if oSq then
                                    if room and oSq:getRoom() == room then
                                        count = count + 1
                                    elseif not room and math.abs(oSq:getX() - pSq:getX()) <= 10 and math.abs(oSq:getY() - pSq:getY()) <= 10 then
                                        count = count + 1
                                    end
                                end
                            end
                        end
                    end
                end)
            end
            data.companionCount = count
        end

        -- A. Efeito de Companhia Ativa (Multiplayer / NPCs)
        if (data.companionCount or 0) >= 1 then
            if bd then
                pcall(function()
                    if bd.getBoredomLevel and bd.setBoredomLevel then
                        local b = bd:getBoredomLevel()
                        if b > 0 then bd:setBoredomLevel(math.max(0.0, b - 0.05)) end
                    end
                    if bd.getUnhappinessLevel and bd.setUnhappinessLevel then
                        local u = bd:getUnhappinessLevel()
                        if u > 0 then bd:setUnhappinessLevel(math.max(0.0, u - 0.02)) end
                    end
                end)
            end

            if not data.socialActive then
                data.socialActive = true
                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote("Living House: Boa Companhia! (Tedio e Tristeza reduzidos)", 120, 240, 180, 280)
                    end
                end)
            end
        else
            data.socialActive = false
        end

        -- B. "Noite ao Redor do Fogo" (Lareira de Inverno - Acessivel Solo e em Grupo)
        local pMd = player:getModData()
        local hasWinterFireplace = pMd and pMd.LV_HasActiveHeatInWinter
        if hasWinterFireplace then
            if not data.fireplaceNightActive then
                data.fireplaceNightActive = true
                local hasCompany = (data.companionCount or 0) >= 1
                local msg = hasCompany and "Living House: Noite ao Redor do Fogo com Companhia! (Aconchego maximo)"
                                       or "Living House: Noite ao Redor do Fogo! (Aconchego e calor no inverno)"
                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote(msg, 255, 180, 70, 320)
                    end
                end)
            end

            -- Bonus intensivo contra depressao e frio do inverno (com boost extra se houver companhia)
            local extraCompanyBoost = ((data.companionCount or 0) >= 1) and 0.03 or 0.0
            if bd and bd.getUnhappinessLevel and bd.setUnhappinessLevel then
                pcall(function() bd:setUnhappinessLevel(math.max(0.0, bd:getUnhappinessLevel() - (0.05 + extraCompanyBoost))) end)
            end
            if bd and bd.getBoredomLevel and bd.setBoredomLevel then
                pcall(function() bd:setBoredomLevel(math.max(0.0, bd:getBoredomLevel() - (0.04 + extraCompanyBoost))) end)
            end
            if stats and stats.setStress and stats.getStress then
                pcall(function() stats:setStress(math.max(0.0, stats:getStress() - 0.0003)) end)
            end
        else
            data.fireplaceNightActive = false
        end
    end
end

--- Registra qualquer atividade de higiene concluida (escovacao de dentes, banho, etc.)
function LV_RoutineSystem.recordHygieneActivity(player, activityName)
    if not player then return end
    print("[LivingHouse] Atividade de higiene registrada: " .. tostring(activityName))
    if LV_RoutineSystem.onWash then
        pcall(LV_RoutineSystem.onWash, player)
    end
end

-- =============================================================================
-- Ganchos de Eventos Nativo
-- =============================================================================

Events.OnPlayerUpdate.Add(function(player)
    LV_RoutineSystem.updateRoutineEffects(player)
end)

Events.EveryDays.Add(function()
    if isServer and isServer() then
        local playerList = getOnlinePlayers and getOnlinePlayers()
        if playerList and playerList.size then
            for i = 0, playerList:size() - 1 do
                local p = playerList:get(i)
                if p then LV_RoutineSystem.checkDailyStreak(p) end
            end
        end
    else
        local numPlayers = (getNumActivePlayers and getNumActivePlayers()) or 1
        for i = 0, numPlayers - 1 do
            local p = (getSpecificPlayer and getSpecificPlayer(i)) or (getPlayer and getPlayer())
            if p then LV_RoutineSystem.checkDailyStreak(p) end
        end
    end
end)

-- Hook seguro para alimentacao/bebidas
if Events.OnEatFood and Events.OnEatFood.Add then
    Events.OnEatFood.Add(function(player, food, percent)
        LV_RoutineSystem.onEatFood(player, food)
    end)
end

if ISEatFoodAction and ISEatFoodAction.perform then
    local original_ISEatFoodAction_perform = ISEatFoodAction.perform
    function ISEatFoodAction:perform()
        if LV_RoutineSystem and LV_RoutineSystem.onEatFood and self.character and self.item then
            pcall(LV_RoutineSystem.onEatFood, self.character, self.item)
        end
        return original_ISEatFoodAction_perform(self)
    end
end

print("[LivingHouse] LV_RoutineSystem carregado com sucesso (Manha Aconchegante, Streaks e Casa Impecavel)!")
