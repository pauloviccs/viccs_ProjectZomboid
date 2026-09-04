-- =============================================================================
-- Housing Care System (Lar Vivo) - Dental & Oral Care Need (LV_DentalNeed.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Simulação da necessidade de higiene bucal (escovação de dentes) do sobrevivente.
--   - Acumula dinamicamente a cada refeição consumida (onEatFood) proporcionalmente
--     à quantidade e tipo de alimento ingerido (fome, calorias, doces e açúcar).
--   - Acúmulo passivo leve ao longo do dia (+1.0% por hora).
--   - Se negligenciada (> 70%), causa desconforto, mau hálito e estresse leve.
--   - A escovação em pia com escova e pasta zera a necessidade para 0%, remove
--     estresse/tédio e concede o bônus "Hálito Fresco" para o streak diário.
-- =============================================================================

require "LV_Config"

LV_DentalNeed = LV_DentalNeed or {}

local localDentalSession = {}

--- Retorna o nível de sujeira/necessidade de escovação do jogador (0 a 100).
function LV_DentalNeed.getNeed(player)
    if not player then return 0 end
    local pNum = (player.getPlayerNum and player:getPlayerNum()) or 0
    local val = localDentalSession[pNum]
    if val == nil then
        local ok, md = pcall(function() return player:getModData() end)
        val = (ok and md and md.LV_DentalNeed) or 0.0
        localDentalSession[pNum] = val
    end
    return val
end

--- Define o nível de necessidade bucal do jogador (0 a 100).
function LV_DentalNeed.setNeed(player, value, forceReset)
    if not player then return end
    local pNum = (player.getPlayerNum and player:getPlayerNum()) or 0
    local current = LV_DentalNeed.getNeed(player)
    local target = math.max(0.0, math.min(100.0, tonumber(value) or 0.0))

    if not forceReset and target < current then
        target = current -- Trava: só diminui explicitamente via escovação
    end

    localDentalSession[pNum] = target

    local ok, md = pcall(function() return player:getModData() end)
    if ok and md then
        md.LV_DentalNeed = target
        if player.transmitModData then
            pcall(function() player:transmitModData() end)
        end
    end
end

--- Incrementa a necessidade bucal após consumo de alimentos ou bebidas.
function LV_DentalNeed.onEatFood(player, food)
    if not player or player:isDead() then return end

    local current = LV_DentalNeed.getNeed(player)
    local delta = 15.0 -- Ganho base padrão por refeição

    if food then
        -- 1. Avaliação pelo valor de fome saciado
        if food.getHungerChange then
            local hunger = math.abs(food:getHungerChange() or 0)
            if hunger > 0.40 then
                delta = 25.0 -- Refeição pesada / ensopado / prato cheio
            elseif hunger > 0.20 then
                delta = 20.0 -- Refeição média
            elseif hunger > 0.05 then
                delta = 14.0 -- Lanche rápido / barra de cereal
            else
                delta = 10.0 -- Petisco leve
            end
        end

        -- 2. Avaliação por doces, refrigerantes e guloseimas (alta placa bacteriana)
        local ft = (food.getFullType and food:getFullType() or ""):lower()
        local name = (food.getName and food:getName() or ""):lower()
        if ft:find("candy") or ft:find("chocolate") or ft:find("sugar") or ft:find("soda") or
           ft:find("pop") or ft:find("cake") or ft:find("pie") or ft:find("biscuit") or
           name:find("chocolate") or name:find("doce") or name:find("bolo") or name:find("refrigerante") then
            delta = delta + 12.0
        end

        -- 3. Avaliação por carnes ou conservas
        if ft:find("meat") or ft:find("canned") or ft:find("fish") or name:find("carne") or name:find("lata") then
            delta = delta + 5.0
        end
    end

    local newNeed = math.min(100.0, current + delta)
    LV_DentalNeed.setNeed(player, newNeed, true)

    -- Feedback discreto se a necessidade ultrapassar o limiar de alerta
    if newNeed >= 75.0 and current < 75.0 then
        pcall(function()
            if player.setHaloNote then
                player:setHaloNote("Higiene Bucal: Dentes precisam ser escovados (-Halito)", 220, 200, 100, 200)
            end
        end)
    end
end

--- Atualização passiva horária (acúmulo leve ao longo do dia e impacto no estresse).
function LV_DentalNeed.onEveryHours(player)
    if not player or player:isDead() then return end

    local currentNeed = LV_DentalNeed.getNeed(player)
    -- Acúmulo passivo suave (+1% por hora)
    local newNeed = math.min(100.0, currentNeed + 1.0)
    LV_DentalNeed.setNeed(player, newNeed, true)

    -- Impacto fisiológico se os dentes estiverem sujos por muito tempo
    if newNeed >= 70.0 then
        local stats = player.getStats and player:getStats()
        if stats then
            pcall(function()
                -- Acúmulo leve de estresse pelo gosto ruim e hálito pesado
                if stats.getStress and stats.setStress then
                    stats:setStress(math.min(1.0, (stats:getStress() or 0) + 0.02))
                end
            end)
        end

        local bd = player.getBodyDamage and player:getBodyDamage()
        if bd then
            pcall(function()
                if bd.getUnhappynessLevel and bd.setUnhappynessLevel then
                    bd:setUnhappynessLevel(math.min(100.0, (bd:getUnhappynessLevel() or 0) + 1.5))
                end
            end)
        end
    end
end

--- Executado ao concluir a ação de escovação de dentes na pia.
function LV_DentalNeed.brushTeeth(player)
    if not player then return end

    -- Zera a necessidade bucal imediatamente
    LV_DentalNeed.setNeed(player, 0.0, true)

    -- Alívio direto de estresse e melhora no humor
    local stats = player.getStats and player:getStats()
    if stats then
        pcall(function()
            if stats.getStress and stats.setStress then
                stats:setStress(math.max(0.0, (stats:getStress() or 0.0) - 0.20))
            end
            if stats.getBoredom and stats.setBoredom then
                stats:setBoredom(math.max(0.0, (stats:getBoredom() or 0.0) - 15.0))
            end
        end)
    end

    local bd = player.getBodyDamage and player:getBodyDamage()
    if bd then
        pcall(function()
            if bd.getUnhappynessLevel and bd.setUnhappynessLevel then
                bd:setUnhappynessLevel(math.max(0.0, (bd:getUnhappynessLevel() or 0.0) - 15.0))
            end
        end)
    end

    -- Registra no RoutineSystem para streaks e ritual matinal
    if LV_RoutineSystem and LV_RoutineSystem.recordHygieneActivity then
        LV_RoutineSystem.recordHygieneActivity(player, "BrushedTeeth")
    end

    -- Concede bônus do Homemaking Engine se presente
    if LV_HomemakingActions and LV_HomemakingActions.grantActionBonus then
        LV_HomemakingActions.grantActionBonus(player, "Higiene Bucal", 1.5)
    end

    pcall(function()
        if player.setHaloNote then
            player:setHaloNote("Halito Fresco: Dentes limpos e higienizados! (-Estresse / +Higiene)", 120, 240, 200, 240)
        end
    end)
end

print("[LarVivo] LV_DentalNeed carregado com sucesso!")
