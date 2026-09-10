-- =============================================================================
-- Housing Care System (Lar Vivo) - Stovetop Cooking Engine (LV_StovetopCooking.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Permite que panelas, frigideiras e alimentos posicionados como objetos 3D soltos
--   no mundo (world items) sobre a boca de um fogao ou fonte de calor ligada cozinhem
--   fisicamente, avancem o cozimento, cheguem ao ponto de cozido ou queimado, e
--   concedam o bonus do Homemaking Engine ("Culinaria Caseira").
--   100% nao invasivo, zero monkey-patching, compativel com SP e MP.
-- =============================================================================

require "LV_Config"

LV_StovetopCooking = LV_StovetopCooking or {}

--- Registro leve de coordenadas de fogoes e fontes de calor conhecidas/ativas
-- Chave: "x,y,z" -> { x = x, y = y, z = z }
LV_StovetopCooking.registeredStoves = LV_StovetopCooking.registeredStoves or {}

--- Cache de itens em cozimento para telemetria e HUD
-- Chave: "x,y,z" -> { items = { { name = "...", progress = 0.5, isCooked = bool, isBurnt = bool } } }
LV_StovetopCooking.activeCookingState = LV_StovetopCooking.activeCookingState or {}

--- Controle de tempo in-game
local lastWorldAgeMinutes = nil
local lastCheckSystemTime = 0

--- Conjunto de tipos de recipientes culinarios validos
local COOKWARE_PATTERNS = {
    "pot", "pan", "kettle", "griddle", "wok", "baking", "cauldron", "saucepan", "roasting"
}

--- Verifica se um InventoryItem e um recipiente culinario
local function isCookwareContainer(item)
    if not item then return false end
    local ftype = tostring(item:getFullType() or ""):lower()
    local name = tostring(item:getName() or ""):lower()

    -- Verificacao segura PZ B42 de ItemTag (hasTag em Java requer objeto ItemTag, nao aceita String)
    if ItemTag and ItemTag.COOKABLE and item.hasTag then
        local ok, res = pcall(function() return item:hasTag(ItemTag.COOKABLE) end)
        if ok and res then return true end
    end

    -- Verificacao segura se getTags() retornar um Set java
    if item.getTags then
        local ok, tags = pcall(function() return item:getTags() end)
        if ok and tags then
            local tagsStr = tostring(tags):lower()
            if tagsStr:find("cook") or tagsStr:find("pan") or tagsStr:find("pot") then
                return true
            end
        end
    end

    for _, pat in ipairs(COOKWARE_PATTERNS) do
        if ftype:find(pat) or name:find(pat) then
            return true
        end
    end

    if item.IsInventoryContainer and item:IsInventoryContainer() then
        return true
    end

    return false
end

--- Registra a coordenada de um fogao ativo ou inspecionado
function LV_StovetopCooking.registerStove(stoveObj, square)
    if not square then
        if stoveObj and stoveObj.getSquare then square = stoveObj:getSquare() end
    end
    if not square then return end

    local key = string.format("%d,%d,%d", square:getX(), square:getY(), square:getZ())
    LV_StovetopCooking.registeredStoves[key] = {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ()
    }
end

--- Verifica se um objeto do mapa e um fogao, forno, lareira ou churrasqueira
function LV_StovetopCooking.isHeatSourceObject(obj)
    if not obj then return false end
    local spriteName = (obj.getSprite and obj:getSprite() and obj:getSprite():getName()) or ""
    spriteName = tostring(spriteName):lower()

    if instanceof and (instanceof(obj, "IsoStove") or instanceof(obj, "IsoBarbecue") or instanceof(obj, "IsoFireplace")) then
        return true
    end

    if spriteName:find("stove") or spriteName:find("oven") or spriteName:find("barbecue") or
       spriteName:find("grill") or spriteName:find("appliances_cooking_") or spriteName:find("fireplace") then
        return true
    end

    return false
end

--- Verifica se uma fonte de calor especifica esta ligada/ativa
function LV_StovetopCooking.isHeatSourceActive(obj, square)
    if not obj then return false end

    -- 1. Fogao eletrico ou a gas vanilla (IsoStove)
    if obj.Activated then
        local isAct = obj:Activated()
        if isAct then
            -- Se for eletrico, precisa de energia no quadrado ou no container
            local container = obj.getContainer and obj:getContainer()
            if container and container.isPowered and not container:isPowered() then
                if square and square.haveElectricity and not square:haveElectricity() then
                    return false
                end
            end
            return true
        end
    end

    -- 2. Fontes acesas (Lareira, Churrasqueira, Fogao Antigo a Lenha)
    if obj.isLit and obj:isLit() then
        return true
    end

    -- 3. Metodos genericos de ativacao
    if obj.isActivated and obj:isActivated() then
        return true
    end

    return false
end

--- Processa o cozimento de um alimento individual (Food)
local function processFoodItem(food, square, deltaMinutes, containerName)
    if not food then return nil end

    local isCookable = false
    if food.isIsCookable and food:isIsCookable() then isCookable = true end
    if not isCookable and food.isCookable and food:isCookable() then isCookable = true end

    -- Se nao for cookable, mas for Food comum comestivel cru, ainda podemos aquecer
    if not isCookable and not (instanceof and instanceof(food, "Food")) then
        return nil
    end

    -- 1. Descongelamento caso esteja congelado
    if food.isFrozen and food:isFrozen() then
        local ft = (food.getFreezingTime and food:getFreezingTime()) or 0.0
        if food.setFreezingTime then
            food:setFreezingTime(math.max(0, ft - (deltaMinutes * 2.0)))
        end
        if food.setHeat then
            food:setHeat(1.2)
        end
        return {
            name = (food.getName and food:getName()) or "Alimento",
            container = containerName,
            progress = 0.0,
            isFrozen = true,
            isCooked = false,
            isBurnt = false
        }
    end

    -- 2. Aquecimento ativo do alimento (acima de 1.6 a engine considera quente/cozinhando)
    if food.setHeat then
        food:setHeat(3.0)
    end
    if food.setItemHeat then
        food:setItemHeat(3.0)
    end

    local ct = (food.getCookingTime and food:getCookingTime()) or 0.0
    local mtc = (food.getMinutesToCook and food:getMinutesToCook()) or 10.0
    if mtc <= 0 then mtc = 10.0 end
    local mtb = (food.getMinutesToBurn and food:getMinutesToBurn()) or (mtc * 2.2)
    if mtb <= mtc then mtb = mtc * 2.2 end

    -- Avanca o progresso de cozimento em minutos in-game
    local speedMult = (LV_Config and LV_Config.get and LV_Config.get("StovetopCookingSpeedMultiplier")) or 1.0
    local newCt = ct + (deltaMinutes * speedMult)

    if food.setCookingTime then
        food:setCookingTime(newCt)
    end

    local foodName = (food.getName and food:getName()) or "Alimento"
    local wasCooked = (food.isCooked and food:isCooked()) or false
    local wasBurnt = (food.isBurnt and food:isBurnt()) or false

    -- 3. Ponto de Cozido
    local justCooked = false
    if newCt >= mtc and not wasCooked and not wasBurnt then
        if food.setCooked then
            food:setCooked(true)
        end
        justCooked = true

        -- Dispara recompensa do Homemaking Engine ("Culinaria Caseira") para sobreviventes proximos
        pcall(function()
            local player = getPlayer()
            if player and square then
                local pSq = player:getCurrentSquare()
                if pSq then
                    local dist = math.abs(pSq:getX() - square:getX()) + math.abs(pSq:getY() - square:getY())
                    if dist <= 12 and pSq:getZ() == square:getZ() then
                        if LV_HomemakingActions and LV_HomemakingActions.triggerCompletedCategory then
                            LV_HomemakingActions.triggerCompletedCategory(player, "Cooking", 20)
                        end
                        if LV_DirtSystem and LV_DirtSystem.onCooking then
                            LV_DirtSystem.onCooking(player)
                        end
                    end
                end
            end
        end)
    end

    -- 4. Ponto de Queimado
    local justBurnt = false
    if newCt >= mtb and not wasBurnt then
        if food.setBurnt then
            food:setBurnt(true)
        end
        justBurnt = true

        pcall(function()
            local player = getPlayer()
            if player and square then
                local pSq = player:getCurrentSquare()
                if pSq and math.abs(pSq:getX() - square:getX()) <= 15 and pSq:getZ() == square:getZ() then
                    local alertText = string.format("[Alerta] %s queimou no fogao!", foodName)
                    if player.setHaloNote then
                        player:setHaloNote(alertText, 240, 70, 70, 250)
                    elseif HaloTextHelper and HaloTextHelper.addText then
                        HaloTextHelper.addText(player, alertText)
                    end
                end
            end
        end)
    end

    -- 5. Risco de Incendio se abandonado queimando
    if newCt >= (mtb + 12.0) and wasBurnt then
        local fireRiskEnabled = (LV_Config and LV_Config.get and LV_Config.get("StovetopFireRiskEnabled")) ~= false
        if fireRiskEnabled and square and not square:isOutside() then
            pcall(function()
                if IsoFireManager and IsoFireManager.StartFire then
                    local cell = square:getCell() or getCell()
                    IsoFireManager.StartFire(cell, square, true, 100, 500)
                end
            end)
        end
    end

    -- 6. Sincronizacao em multiplayer
    if food.syncItemFields then
        pcall(food.syncItemFields, food)
    end

    local progress = math.min(1.0, newCt / mtc)
    local isNowCooked = (food.isCooked and food:isCooked()) or false
    local isNowBurnt = (food.isBurnt and food:isBurnt()) or false

    return {
        name = foodName,
        container = containerName,
        progress = progress,
        isFrozen = false,
        isCooked = isNowCooked,
        isBurnt = isNowBurnt,
        justCooked = justCooked,
        justBurnt = justBurnt
    }
end

--- Processa todos os objetos 3D sobre o quadrado de um fogao aceso
function LV_StovetopCooking.processStoveSquare(square, deltaMinutes)
    if not square then return nil end

    local worldObjects = square:getWorldObjects()
    if not worldObjects or worldObjects:isEmpty() then
        return nil
    end

    local activeFoodList = {}

    for i = 0, worldObjects:size() - 1 do
        local wobj = worldObjects:get(i)
        if wobj and wobj.getItem then
            local item = wobj:getItem()
            if item then
                local isContainer = isCookwareContainer(item)
                local container = item.getItemContainer and item:getItemContainer()

                if isContainer and container then
                    -- Aquece a panela/frigideira no mundo
                    if item.setItemHeat then item:setItemHeat(3.0) end
                    if item.setHeat then item:setHeat(3.0) end

                    local subItems = container:getItems()
                    if subItems and not subItems:isEmpty() then
                        for j = 0, subItems:size() - 1 do
                            local subFood = subItems:get(j)
                            local res = processFoodItem(subFood, square, deltaMinutes, item:getName())
                            if res then
                                table.insert(activeFoodList, res)
                            end
                        end
                    end
                else
                    -- Alimento colocado diretamente sobre a boca/chapa do fogao
                    local res = processFoodItem(item, square, deltaMinutes, nil)
                    if res then
                        table.insert(activeFoodList, res)
                    end
                end
            end
        end
    end

    return activeFoodList
end

--- Ciclo periodico de atualizacao do motor de cozimento
function LV_StovetopCooking.updateCycle()
    if not LV_Config or not LV_Config.isEnabled() then return end
    if LV_Config.get("StovetopCookingEnabled") == false then return end

    local gt = getGameTime()
    if not gt then return end

    local currentWorldMinutes = gt:getWorldAgeHours() * 60.0
    if lastWorldAgeMinutes == nil then
        lastWorldAgeMinutes = currentWorldMinutes
        return
    end

    local deltaMinutes = currentWorldMinutes - lastWorldAgeMinutes
    local checkSecs = (LV_Config and LV_Config.get and LV_Config.get("StovetopCheckIntervalSeconds")) or 30.0
    local minDeltaMinutes = math.max(0.05, checkSecs / 60.0)
    if deltaMinutes < minDeltaMinutes then
        -- Aguarda o intervalo configurado na Sandbox (StovetopCheckIntervalSeconds) para agrupar e economizar CPU
        return
    end
    lastWorldAgeMinutes = currentWorldMinutes

    -- Limita delta em caso de avanco extremo (ex.: dormir muitas horas seguidas)
    if deltaMinutes > 180.0 then
        deltaMinutes = 180.0
    end

    local cell = getCell()
    if not cell then return end

    local updatedState = {}

    -- Itera todos os fogoes registrados
    for key, coord in pairs(LV_StovetopCooking.registeredStoves) do
        local sq = getSquare(coord.x, coord.y, coord.z)
        if sq then
            local hasActiveHeat = false
            local objs = sq:getObjects()
            if objs then
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if LV_StovetopCooking.isHeatSourceObject(obj) then
                        if LV_StovetopCooking.isHeatSourceActive(obj, sq) then
                            hasActiveHeat = true
                            break
                        end
                    end
                end
            end

            if hasActiveHeat then
                local activeFoods = LV_StovetopCooking.processStoveSquare(sq, deltaMinutes)
                if activeFoods and #activeFoods > 0 then
                    updatedState[key] = {
                        x = coord.x,
                        y = coord.y,
                        z = coord.z,
                        foods = activeFoods
                    }
                end
            end
        end
    end

    LV_StovetopCooking.activeCookingState = updatedState
end

--- Retorna o estado atual de cozimento em um comodo especifico (para o Room Inspector Dashboard)
function LV_StovetopCooking.getCookingInfoForRoom(room)
    if not room or not LV_StovetopCooking.activeCookingState then
        return nil
    end

    local roomFoods = {}
    for key, state in pairs(LV_StovetopCooking.activeCookingState) do
        local sq = getSquare(state.x, state.y, state.z)
        if sq and sq.getRoom and sq:getRoom() == room then
            for _, f in ipairs(state.foods) do
                table.insert(roomFoods, f)
            end
        end
    end

    if #roomFoods == 0 then return nil end
    return roomFoods
end

-- =============================================================================
-- HOOKS E EVENTOS GLOBAIS
-- =============================================================================

--- Monitora acao de ligar/desligar fogao do jogador vanilla
local function hookToggleStoveAction()
    if ISToggleStoveAction and not ISToggleStoveAction._LV_StoveHooked then
        ISToggleStoveAction._LV_StoveHooked = true
        local orig_perform = ISToggleStoveAction.perform
        function ISToggleStoveAction:perform()
            orig_perform(self)
            if self.object and self.object.getSquare then
                local sq = self.object:getSquare()
                if sq then
                    LV_StovetopCooking.registerStove(self.object, sq)
                end
            end
        end
    end
end

hookToggleStoveAction()

-- Atualizacao periodica baseada no relogio do Project Zomboid
if Events.EveryOneMinute then
    Events.EveryOneMinute.Add(function()
        pcall(LV_StovetopCooking.updateCycle)
    end)
end

-- Observador de objetos adicionados no mundo (ex: ao colocar panela sobre o fogao)
if Events.OnObjectAdded then
    Events.OnObjectAdded.Add(function(obj)
        if obj and LV_StovetopCooking.isHeatSourceObject(obj) then
            pcall(function()
                LV_StovetopCooking.registerStove(obj, obj:getSquare())
            end)
        end
    end)
end

print("[LarVivo] LV_StovetopCooking: Motor de Cozimento Real sobre o Fogao carregado com sucesso!")
