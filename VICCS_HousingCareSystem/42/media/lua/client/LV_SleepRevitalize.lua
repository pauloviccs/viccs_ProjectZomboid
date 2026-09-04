-- =============================================================================
-- Housing Care System (Lar Vivo) - Sleep & Revitalize Engine (LV_SleepRevitalize.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Mecânica imersiva de sono e descanso.
--   Ao dormir por 6+ horas in-game em uma cama com travesseiro (equipado, no
--   inventário ou no azulejo da cama), o sobrevivente acorda com sono reparador:
--   zera tristeza, tédio e estresse, e recebe o bônus de Revigorado!
-- =============================================================================

LV_SleepRevitalize = LV_SleepRevitalize or {}

local wasSleeping = false
local sleepStartWorldHour = -1
local hadPillowAtSleep = false
local hadBedAtSleep = false

--- Verifica se há travesseiro no inventário, nas mãos ou no azulejo da cama.
local function checkPillowPresence(player, square)
    if not player then return false end

    -- 1. No inventário do jogador ou equipado
    local inv = player:getInventory()
    if inv then
        if inv:contains("Pillow", true) or inv:contains("Base.Pillow", true) or (inv.containsTypeRecurse and inv:containsTypeRecurse("Pillow")) then
            return true
        end
        local items = inv:getItems()
        if items and items.size then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item then
                    local itemType = item.getType and tostring(item:getType()):lower() or ""
                    local itemName = item.getName and tostring(item:getName()):lower() or ""
                    local hasTag = false
                    if item.hasTag then
                        local ok1, t1 = pcall(item.hasTag, item, "Pillow")
                        local ok2, t2 = pcall(item.hasTag, item, "pillow")
                        hasTag = (ok1 and t1) or (ok2 and t2)
                    end
                    if hasTag or itemType:find("pillow") or itemName:find("travesseiro") or itemName:find("pillow") then
                        return true
                    end
                end
            end
        end
    end

    -- 2. Colocado como objeto 3D sobre a cama ou chão ao lado
    if square and square.getWorldObjects then
        local wObjs = square:getWorldObjects()
        if wObjs and wObjs.size then
            for i = 0, wObjs:size() - 1 do
                local wObj = wObjs:get(i)
                if wObj and wObj.getItem then
                    local item = wObj:getItem()
                    if item then
                        local itemType = tostring(item:getType()):lower()
                        local itemName = tostring(item:getName()):lower()
                        if itemType:find("pillow") or itemName:find("travesseiro") or itemName:find("pillow") then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

--- Verifica se o jogador está sobre uma cama ou sofá
local function checkBedPresence(square)
    if not square or not square.getObjects then return false end
    local objects = square:getObjects()
    if not objects or not objects.size then return false end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            local sprite = obj.getSprite and obj:getSprite()
            local spriteName = (sprite and sprite.getName and sprite:getName()) and tostring(sprite:getName()):lower() or ""
            local props = sprite and sprite.getProperties and sprite:getProperties()

            if spriteName:find("bed") ~= nil or
               spriteName:find("furniture_bedding_") ~= nil or
               spriteName:find("furniture_seating_") ~= nil or
               spriteName:find("couch") ~= nil or
               spriteName:find("sofa") ~= nil or
               spriteName:find("carpentry_02_5") ~= nil or
               spriteName:find("carpentry_02_6") ~= nil or
               (instanceof and instanceof(obj, "IsoThumpable") and obj.isBed and obj:isBed()) then
                return true
            end
        end
    end

    return false
end

--- Monitoramento de ciclo de sono (Events.OnPlayerUpdate).
local function onSleepUpdate(player)
    if not player or not LV_Config or not LV_Config.isEnabled() then return end

    local isAsleep = player.isAsleep and player:isAsleep()
    local currentHour = getGameTime():getWorldAgeHours()

    -- 1. Início do Sono
    if isAsleep and not wasSleeping then
        wasSleeping = true
        sleepStartWorldHour = currentHour
        local sq = player:getCurrentSquare()
        hadBedAtSleep = checkBedPresence(sq)
        hadPillowAtSleep = checkPillowPresence(player, sq)

        print(string.format("[LarVivo] Sobrevivente adormeceu na hora %.2f. Cama: %s | Travesseiro: %s",
            sleepStartWorldHour, tostring(hadBedAtSleep), tostring(hadPillowAtSleep)))

    -- 2. Término do Sono (Acordou)
    elseif not isAsleep and wasSleeping then
        wasSleeping = false
        local hoursSlept = math.max(0, currentHour - sleepStartWorldHour)
        print(string.format("[LarVivo] Sobrevivente acordou! Tempo dormido: %.1f horas in-game.", hoursSlept))

        -- Se dormiu pelo menos 6 horas no relógio do jogo
        if hoursSlept >= 5.5 and hadBedAtSleep then
            local bodyDamage = player:getBodyDamage()
            local stats = player:getStats()

            local bodyDirt = (LV_DirtSystem and LV_DirtSystem.getPlayerBodyDirt and LV_DirtSystem.getPlayerBodyDirt(player, true)) or 0
            if bodyDirt >= 70 then
                -- Dormiu com o corpo imundo: sono ruim, estresse residual e contaminação do quarto
                if bodyDamage and bodyDamage.getUnhappinessLevel and bodyDamage.setUnhappinessLevel then
                    pcall(function()
                        bodyDamage:setUnhappinessLevel(math.min(100, bodyDamage:getUnhappinessLevel() + 20))
                    end)
                end
                if stats and stats.Stress ~= nil then
                    stats.Stress = math.min(1.0, stats.Stress + 0.25)
                end

                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote("Living House: Sono Desconfortavel (Corpo e Roupas Imundas)", 230, 120, 80, 280)
                    end
                end)

                -- Suja o piso do cômodo
                local sq = player:getCurrentSquare()
                if sq and LV_DirtSystem and LV_DirtSystem.addFloorDirt then
                    local locKey = LV_DirtSystem.getCurrentLocationKey(player, sq)
                    if locKey ~= "outside" then
                        LV_DirtSystem.addFloorDirt(locKey, 15.0)
                    end
                end
            elseif hadPillowAtSleep then
                -- Sono Perfeito com Travesseiro
                if bodyDamage then
                    pcall(function()
                        if bodyDamage.setUnhappinessLevel then bodyDamage:setUnhappinessLevel(0) end
                        if bodyDamage.setBoredomLevel then bodyDamage:setBoredomLevel(0) end
                    end)
                end

                if stats then
                    pcall(function()
                        if stats.Stress ~= nil then stats.Stress = 0.0 end
                        if stats.Panic ~= nil then stats.Panic = 0.0 end
                    end)
                end

                -- Renova bônus de energia do Lar Vivo por 8 horas do relógio do jogo
                LV_BuffManager.applyScanResults(player, 100, 0)

                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote("Living House: Sono Reparador (Acordou Revigorado!)", 80, 255, 140, 300)
                    end
                end)
            else
                -- Sono em Cama sem Travesseiro
                if bodyDamage then
                    pcall(function()
                        if bodyDamage.getUnhappinessLevel and bodyDamage.setUnhappinessLevel then
                            bodyDamage:setUnhappinessLevel(math.max(0, bodyDamage:getUnhappinessLevel() * 0.5))
                        end
                    end)
                end

                pcall(function()
                    if player.setHaloNote then
                        player:setHaloNote("Living House: Bom Descanso (Cama Confortavel)", 120, 240, 160, 250)
                    end
                end)
            end
        end

        sleepStartWorldHour = -1
    end
end

Events.OnPlayerUpdate.Add(onSleepUpdate)

print("[LarVivo] LV_SleepRevitalize carregado e pronto para monitorar descanso e travesseiros!")
