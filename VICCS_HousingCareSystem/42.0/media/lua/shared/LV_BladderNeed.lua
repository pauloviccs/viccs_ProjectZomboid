-- =============================================================================
-- Housing Care System (Lar Vivo) - Bladder & Physiological Need (LV_BladderNeed.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Simulacao de necessidade fisiologica (banheiro/bexiga) integrada ao
--   consumo de alimentos e rotina diaria.
--   Aplica moodlets de desconforto caso ignorada e concede bonus ao usar
--   um vaso sanitario limpo.
-- =============================================================================

require "LV_Config"
require "LV_MoodleDefs"

LV_BladderNeed = LV_BladderNeed or {}

local localBladderSession = {}
local lastDamageTick = 0

--- Retorna o nivel de necessidade fisiologica do jogador (0 a 100).
function LV_BladderNeed.getNeed(player)
    if not player then return 0 end
    local pNum = player.getPlayerNum and player:getPlayerNum() or 0
    local val = localBladderSession[pNum]
    if val == nil then
        local ok, md = pcall(function() return player:getModData() end)
        val = (ok and md and md.LV_BladderNeed) or 0.0
        localBladderSession[pNum] = val
    end
    return val
end

--- Define o nivel de necessidade fisiologica do jogador.
--- Trava de mao unica: o valor NUNCA decai sozinho. Apenas relieve() pode diminuir.
function LV_BladderNeed.setNeed(player, value, forceReset)
    if not player then return end
    local pNum = player.getPlayerNum and player:getPlayerNum() or 0
    local current = LV_BladderNeed.getNeed(player)
    local target = math.max(0.0, math.min(100.0, tonumber(value) or 0.0))

    if not forceReset and target < current then
        target = current -- Trava absoluta: jamais diminui passivamente
    end

    localBladderSession[pNum] = target

    local ok, md = pcall(function() return player:getModData() end)
    if ok and md then
        md.LV_BladderNeed = target
        if player.transmitModData then
            pcall(function() player:transmitModData() end)
        end
    end
end

--- Retorna o Tier atual de aperto do sobrevivente (0 a 3).
function LV_BladderNeed.getTier(player)
    local need = LV_BladderNeed.getNeed(player)
    local notifyThreshold = (LV_Config and LV_Config.getBladderNotifyThreshold and LV_Config.getBladderNotifyThreshold()) or 70
    if need >= 95 then
        return 3 -- Urgente / Critico
    elseif need >= 80 then
        return 2 -- Moderado / Desconforto
    elseif need >= notifyThreshold then
        return 1 -- Leve / Comeco de vontade
    end
    return 0
end

--- Processa impactos fisicos no corpo e injecao em stats vanilla
function LV_BladderNeed.updateHealthImpact(player)
    if not player or player:isDead() or not LV_Config.isBladderNeedEnabled() then return end

    local need = LV_BladderNeed.getNeed(player)
    local stats = player.getStats and player:getStats()
    local bd = player.getBodyDamage and player:getBodyDamage()

    -- 1. Injecao nos status vanilla para acender moodlets oficiais na HUD nativa
    if stats and CharacterStat then
        if need >= 60 then
            pcall(function()
                if CharacterStat.DISCOMFORT and stats.set and stats.get then
                    local disc = math.min(100, math.max(stats:get(CharacterStat.DISCOMFORT) or 0, (need - 50) * 1.8))
                    stats:set(CharacterStat.DISCOMFORT, disc)
                end
            end)
        end
    end

    -- 2. Punicao severa ao atingir 100% de aperto (Dano leve, colica, febre e infeccao)
    if need >= 100.0 then
        local now = (getTimeInMillis and getTimeInMillis() / 1000.0) or (getGameTime():getWorldAgeHours() * 3600.0)
        if (now - lastDamageTick) >= 1.0 then
            lastDamageTick = now

            -- Aplica dor abdominal continua
            if stats then
                pcall(function()
                    if stats.setPain and stats.getPain then
                        stats:setPain(math.min(100, (stats:getPain() or 0) + 5))
                    end
                    if stats.setStress and stats.getStress then
                        stats:setStress(math.min(1.0, (stats:getStress() or 0) + 0.05))
                    end
                end)
            end

            -- Injeta enjoo/sickness e febre
            if stats and CharacterStat and stats.set and stats.get then
                pcall(function()
                    if CharacterStat.FOOD_SICKNESS then
                        local sick = math.min(50, (stats:get(CharacterStat.FOOD_SICKNESS) or 0) + 2)
                        stats:set(CharacterStat.FOOD_SICKNESS, sick)
                    end
                    if CharacterStat.PAIN then
                        stats:set(CharacterStat.PAIN, math.min(100, (stats:get(CharacterStat.PAIN) or 0) + 10))
                    end
                end)
            end

            -- Dano fisico leve continuo (Retencao extrema / colica renal)
            if bd and bd.ReduceGeneralHealth then
                pcall(function()
                    bd:ReduceGeneralHealth(0.04)
                end)
            end

            -- Halo note de alerta a cada 30 segundos
            if ZombRand(30) == 0 then
                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote("Living House: Dor Aguda de Bexiga! Encontre um banheiro urgente!", 255, 60, 50, 250)
                    end
                end)
            end
        end
    end
end

--- Atualizacao horaria passiva da necessidade.
function LV_BladderNeed.onEveryHours(player)
    if not LV_Config.isBladderNeedEnabled() or not player then return end

    local currentHour = getGameTime():getWorldAgeHours()
    local md = player:getModData()
    local lastHour = md.LV_BladderLastHour or currentHour
    local delta = math.max(0, math.min(12, currentHour - lastHour))
    md.LV_BladderLastHour = currentHour

    local gainPerHour = (LV_Config and LV_Config.getBladderGainPerHour and LV_Config.getBladderGainPerHour()) or 0.8
    local currentNeed = LV_BladderNeed.getNeed(player)
    local newNeed = math.min(100.0, currentNeed + (delta * gainPerHour))
    LV_BladderNeed.setNeed(player, newNeed)

    -- Efeito de estresse se estiver na urgencia maxima (95+)
    if newNeed >= 95 then
        local stats = player.getStats and player:getStats()
        if stats and stats.setStress and stats.getStress then
            stats:setStress(math.min(1.0, stats:getStress() + 0.05))
        end
    end
end

--- Disparado quando o personagem consome comida ou bebida.
function LV_BladderNeed.onEatFood(player, food)
    if not LV_Config or not LV_Config.isBladderNeedEnabled() or not player then return end

    -- Debounce anti-duplicacao (evita contagem dupla por Events.OnEatFood + ISEatFoodAction)
    local nowMs = (getTimeInMillis and getTimeInMillis()) or 0
    local pMd = player.getModData and player:getModData()
    if pMd and nowMs > 0 then
        if pMd.LV_LastBladderEatMs and (nowMs - pMd.LV_LastBladderEatMs) < 600 then
            return
        end
        pMd.LV_LastBladderEatMs = nowMs
    end

    local mult = (LV_Config and LV_Config.getBladderGainAfterEatingMultiplier and LV_Config.getBladderGainAfterEatingMultiplier()) or 0.5
    local hunger = 0.0
    local thirst = 0.0

    if food then
        if food.getHungerChange then
            hunger = math.abs(food:getHungerChange())
        end
        if food.getThirstChange then
            thirst = math.abs(food:getThirstChange())
        end
    else
        thirst = 0.08 -- Gole de agua basico de torneira/recipiente
    end

    local added = math.max(1.0, math.min(15.0, (hunger * 15.0 + thirst * 12.0) * mult))
    local currentNeed = LV_BladderNeed.getNeed(player)
    local newNeed = math.min(100.0, currentNeed + added)
    LV_BladderNeed.setNeed(player, newNeed)

    print(string.format("[LivingHouse] Alimento consumido: +%.1f de necessidade fisiologica. Total: %.1f%%", added, newNeed))

    -- Notificacao / Halo text se cruzar o limiar de alerta
    local notifyThreshold = (LV_Config and LV_Config.getBladderNotifyThreshold and LV_Config.getBladderNotifyThreshold()) or 70
    if currentNeed < notifyThreshold and newNeed >= notifyThreshold then
        pcall(function()
            if player.setHaloNote then
                player:setHaloNote("Living House: Vontade de ir ao banheiro...", 220, 200, 80, 200)
            end
        end)
    end
end

--- Alivia a necessidade fisiologica (ao usar vaso sanitario ou na natureza).
--- @param player IsoPlayer
--- @param isCleanToilet boolean
--- @param hasToiletPaper boolean|nil
--- @param isNature boolean|nil
function LV_BladderNeed.relieve(player, isCleanToilet, hasToiletPaper, isNature)
    if not player then return end
    if hasToiletPaper == nil then hasToiletPaper = true end
    if isNature == nil then isNature = false end

    -- Zera a necessidade com forceReset = true
    LV_BladderNeed.setNeed(player, 0.0, true)
    local md = player:getModData()
    md.LV_BladderLastHour = getGameTime():getWorldAgeHours()

    local stats = player.getStats and player:getStats()
    if stats and stats.setPain then
        stats:setPain(0)
    end

    -- CASO 1: Alivio na Natureza (atras de arvores/arbustos)
    if isNature then
        -- Suja virilha, pernas e roupas
        pcall(function()
            if player.addDirt and BloodBodyPartType and BloodBodyPartType.Groin then
                player:addDirt(BloodBodyPartType.Groin, 30)
                if BloodBodyPartType.LowerLeg_L then player:addDirt(BloodBodyPartType.LowerLeg_L, 15) end
                if BloodBodyPartType.LowerLeg_R then player:addDirt(BloodBodyPartType.LowerLeg_R, 15) end
            end
            local wornItems = player:getWornItems()
            if wornItems then
                for i = 0, wornItems:size() - 1 do
                    local item = wornItems:getItemByIndex(i)
                    if item and item.getBodyLocation then
                        local loc = tostring(item:getBodyLocation()):lower()
                        if loc:find("pants") or loc:find("underwear") or loc:find("legs") or loc:find("shoes") then
                            if item.setDirtyness and item.getDirtyness then
                                item:setDirtyness(math.min(100, item:getDirtyness() + 25))
                            end
                        end
                    end
                end
            end
        end)

        print("[LivingHouse] Necessidade aliviada na natureza (arvore/arbusto). Roupas sujas.")
        pcall(function()
            if player.setHaloNote then
                player:setHaloNote("Living House: Aliviado na natureza... roupas e calcados sujos.", 220, 180, 90, 220)
            end
        end)
        return
    end

    -- CASO 2: Vaso Sanitario SEM Papel Higienico (Edge case grave)
    if not hasToiletPaper then
        -- Aumenta estresse e aplica desconforto vanilla
        if stats then
            if stats.setStress and stats.getStress then
                stats:setStress(math.min(1.0, stats:getStress() + 0.30))
            end
            if CharacterStat and CharacterStat.DISCOMFORT and stats.set and stats.get then
                local disc = math.min(100, (stats:get(CharacterStat.DISCOMFORT) or 0) + 40)
                stats:set(CharacterStat.DISCOMFORT, disc)
            end
        end

        -- Suja diretamente as roupas intimas e calcas do personagem
        pcall(function()
            if player.addDirt and BloodBodyPartType and BloodBodyPartType.Groin then
                player:addDirt(BloodBodyPartType.Groin, 45)
            end
            local wornItems = player:getWornItems()
            if wornItems then
                for i = 0, wornItems:size() - 1 do
                    local item = wornItems:getItemByIndex(i)
                    if item and item.getBodyLocation then
                        local loc = tostring(item:getBodyLocation()):lower()
                        if loc:find("pants") or loc:find("underwear") or loc:find("legs") then
                            if item.setDirtyness and item.getDirtyness then
                                item:setDirtyness(math.min(100, item:getDirtyness() + 35))
                            end
                        end
                    end
                end
            end
        end)

        print("[LivingHouse] Necessidade aliviada no vaso SEM papel higienico! Penalidade aplicada.")
        pcall(function()
            if player.setHaloNote then
                player:setHaloNote("Living House: Sem papel higienico! Desconforto extremo e roupas sujas.", 240, 70, 60, 250)
            end
        end)
        return
    end

    -- CASO 3: Vaso Sanitario COM Papel Higienico (Happy Path)
    if stats and stats.setStress and stats.getStress then
        stats:setStress(math.max(0, stats:getStress() - 0.20))
    end

    local bd = player.getBodyDamage and player:getBodyDamage()
    if bd then
        if bd.setBoredomLevel and bd.getBoredomLevel then
            bd:setBoredomLevel(math.max(0, bd:getBoredomLevel() - 10.0))
        end
        if bd.setUnhappynessLevel and bd.getUnhappynessLevel then
            bd:setUnhappynessLevel(math.max(0, bd:getUnhappynessLevel() - 5.0))
        end
    end

    if isCleanToilet then
        md.LV_RelievedUntilHour = getGameTime():getWorldAgeHours() + 1.5
        print("[LivingHouse] Necessidade aliviada em banheiro higienizado! Buff 'Aliviado' ativo.")
        pcall(function()
            if player.setHaloNote then
                player:setHaloNote("Living House: Aliviado! Banheiro limpo faz toda a diferenca.", 100, 230, 140, 250)
            end
        end)
    else
        print("[LivingHouse] Necessidade aliviada em instalacao basica/suja.")
        pcall(function()
            if player.setHaloNote then
                player:setHaloNote("Living House: Aliviado.", 200, 200, 200, 200)
            end
        end)
    end
end

--- Verifica se o buff 'Aliviado' esta ativo.
function LV_BladderNeed.isRelievedActive(player)
    if not player or not player.getModData then return false end
    local md = player:getModData()
    local untilHour = md.LV_RelievedUntilHour or 0
    return getGameTime():getWorldAgeHours() < untilHour
end
