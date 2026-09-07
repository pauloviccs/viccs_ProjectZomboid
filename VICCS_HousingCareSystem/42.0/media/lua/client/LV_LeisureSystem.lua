-- =============================================================================
-- Housing Care System (Living House) - Leisure & Active Entertainment (LV_LeisureSystem.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Modulo unificado de entretenimento ativo e lazer:
--   1. TV / Radio Ativo: Multiplica a perda de tedio e infelicidade ao relaxar
--      num comodo com Comfort Tier >= 1 e aparelho ligado emitindo sinal.
--   2. Sinergia de Relaxamento: Reducao constante de estresse durante a transmissao.
-- =============================================================================

require "LV_Config"

LV_LeisureSystem = LV_LeisureSystem or {}

local lastHaloTime = 0

--- Disparado a cada minuto in-game (Events.EveryOneMinute)
function LV_LeisureSystem.onEveryOneMinute()
    if not LV_Config or not LV_Config.isEnabled() then return end
    local player = getPlayer()
    if not player or player:isDead() then return end

    local pMd = player:getModData()
    local hasMedia = pMd and pMd.LV_HasActiveMedia
    local roomTier = (pMd and pMd.LV_CurrentRoomTier) or 0
    local bd = player:getBodyDamage()
    local stats = player:getStats()

    -- 1. Efeito de Entretenimento Ativo (TV ou Radio Ligado em comodo com conforto)
    if hasMedia and roomTier >= 1 then
        if bd then
            pcall(function()
                -- Drena tedio ativamente (multiplicador sobre o vanilla)
                if bd.getBoredomLevel and bd.setBoredomLevel then
                    local b = bd:getBoredomLevel()
                    if b > 0 then
                        local drop = 0.5 * (1 + (roomTier * 0.25))
                        bd:setBoredomLevel(math.max(0.0, b - drop))
                    end
                end
                -- Drena infelicidade
                if bd.getUnhappynessLevel and bd.setUnhappynessLevel then
                    local u = bd:getUnhappynessLevel()
                    if u > 0 then
                        bd:setUnhappynessLevel(math.max(0.0, u - 0.25))
                    end
                end
            end)
        end

        if stats and stats.getStress and stats.setStress then
            pcall(function()
                local s = stats:getStress()
                if s > 0 then
                    stats:setStress(math.max(0.0, s - 0.002))
                end
            end)
        end

        -- Feedback sutil espacado
        local now = (getTimeInMillis and getTimeInMillis() / 1000.0) or os.time()
        if (now - lastHaloTime) >= 180.0 then
            lastHaloTime = now
            pcall(function()
                if player.setHaloNote and ZombRand(3) == 0 then
                    player:setHaloNote("Living House: Relaxando com a TV/Radio...", 140, 200, 255, 200)
                end
            end)
        end
    end
end

Events.EveryOneMinute.Add(LV_LeisureSystem.onEveryOneMinute)

return LV_LeisureSystem
