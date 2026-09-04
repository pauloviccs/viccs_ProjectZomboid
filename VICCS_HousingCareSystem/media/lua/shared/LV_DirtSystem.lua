-- =============================================================================
-- Housing Care System (Lar Vivo) - Dirt Simulation Engine (LV_DirtSystem.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Simulador de sujeira corporal nos pés/calçados e transferência orgânica
--   para o piso de cômodos e Safehouses.
--   Zero escrita de ModData em IsoGridSquares: a sujeira de piso é agregada
--   no cache do cômodo/Safehouse para não degradar o I/O do servidor.
-- =============================================================================

require "LV_Config"
require "LV_DirtScoreData"
require "LV_ComfortScanner"

LV_DirtSystem = LV_DirtSystem or {}

local stepAccumulator = {}
local lastPlayerSquares = {}

--- Retorna a chave única da Safehouse ou do cômodo onde o jogador se encontra.
function LV_DirtSystem.getCurrentLocationKey(player, square)
    if not square then return "global" end

    -- Se estiver em área externa (ao ar livre/jardim/rua), a localização é estritamente "outside"
    if square.isOutside and square:isOutside() then
        return "outside"
    end

    -- 1. Tenta identificar Safehouse
    local shClass = SafeHouse or Safehouse
    if shClass and shClass.getSafehouse then
        local ok, sh = pcall(shClass.getSafehouse, square)
        if ok and sh then
            local id = (sh.getId and sh:getId()) or (sh.getTitle and sh:getTitle()) or (sh:getX() .. "_" .. sh:getY())
            return "sh_" .. tostring(id)
        end
    end

    -- 2. Tenta identificar Cômodo fechado
    local room = square.getRoom and square:getRoom()
    if room then
        local rName = (room.getName and room:getName()) or "room"
        local rx, ry = 0, 0
        if room.getSquares and room:getSquares() and room:getSquares():size() > 0 then
            local fSq = room:getSquares():get(0)
            if fSq then rx, ry = fSq:getX(), fSq:getY() end
        else
            rx, ry = square:getX(), square:getY()
        end
        return string.format("room_%s_%d_%d", rName, rx, ry)
    end

    return "outside"
end

--- Retorna a sujeira acumulada nos pés/calçados do personagem (0 a 100).
function LV_DirtSystem.getFootDirt(player)
    if not player or not player.getModData then return 0 end
    local md = player:getModData()
    return md.LV_FootDirt or 0
end

--- Define a sujeira acumulada nos pés/calçados do personagem.
function LV_DirtSystem.setFootDirt(player, value)
    if not player or not player.getModData then return end
    local md = player:getModData()
    md.LV_FootDirt = math.max(0, math.min(100.0, tonumber(value) or 0))
end

local playerBodyDirtCache = {}
local lastBodyDirtScanTime = {}

--- Retorna a pontuação normalizada de sujeira e sangue corporal/vestimentas (0 a 100%)
--- Executa sob throttle de 1500ms para zero impacto em CPU/render.
function LV_DirtSystem.getPlayerBodyDirt(player, forceRefresh)
    if not player then return 0.0 end
    local pNum = player.getPlayerNum and player:getPlayerNum() or 0

    local now = getTimestampMs and getTimestampMs() or (os.time() * 1000)
    local lastTime = lastBodyDirtScanTime[pNum] or 0

    if not forceRefresh and (now - lastTime < 1500) and playerBodyDirtCache[pNum] ~= nil then
        return playerBodyDirtCache[pNum]
    end

    lastBodyDirtScanTime[pNum] = now

    local totalScore = 0.0
    local maxPossible = 0.0

    -- 1. Avalia pele do personagem (HumanVisual)
    local visual = player.getHumanVisual and player:getHumanVisual()
    if visual and BloodBodyPartType and BloodBodyPartType.MAX then
        local maxParts = BloodBodyPartType.MAX:index()
        for i = 0, maxParts - 1 do
            local part = BloodBodyPartType.FromIndex(i)
            if part then
                local d = (visual.getDirt and visual:getDirt(part)) or 0
                local b = (visual.getBlood and visual:getBlood(part)) or 0
                -- No B42, valores de dirt e blood retornam unitários (0.0 a 1.0)
                if d > 1.0 then d = d / 100.0 end
                if b > 1.0 then b = b / 100.0 end
                totalScore = totalScore + (d * 0.5) + (b * 0.5)
                maxPossible = maxPossible + 1.0
            end
        end
    end

    -- 2. Avalia roupas vestidas (WornItems)
    local worn = player.getWornItems and player:getWornItems()
    if worn and worn.size then
        for i = 0, worn:size() - 1 do
            local wItem = worn:get(i)
            local item = wItem and wItem:getItem()
            if item and instanceof(item, "Clothing") then
                local bLvl = (item.getBloodLevel and item:getBloodLevel()) or 0
                local dLvl = (item.getDirtyness and item:getDirtyness()) or 0
                if bLvl > 1.0 then bLvl = bLvl / 100.0 end
                if dLvl > 1.0 then dLvl = dLvl / 100.0 end
                totalScore = totalScore + (dLvl * 0.5) + (bLvl * 0.5)
                maxPossible = maxPossible + 1.0
            end
        end
    end

    if maxPossible <= 0 then
        playerBodyDirtCache[pNum] = 0.0
        return 0.0
    end

    -- Normalização correta 0 a 100%
    local finalPct = math.min(100.0, math.max(0.0, (totalScore / maxPossible) * 100.0))
    playerBodyDirtCache[pNum] = finalPct
    return finalPct
end

--- Invalida o cache para recálculo imediato (ex: após banho)
function LV_DirtSystem.invalidatePlayerBodyDirtCache(player)
    if not player then return end
    local pNum = player.getPlayerNum and player:getPlayerNum() or 0
    playerBodyDirtCache[pNum] = nil
    lastBodyDirtScanTime[pNum] = 0
end


--- Retorna a sujeira de piso acumulada em uma Safehouse ou cômodo (0 a 100).
function LV_DirtSystem.getFloorDirt(locationKey)
    if not locationKey or locationKey == "outside" then return 0 end
    LV_ComfortScanner.safehouseCache = LV_ComfortScanner.safehouseCache or {}
    local cache = LV_ComfortScanner.safehouseCache[locationKey]
    if not cache then return 0 end
    return cache.floorDirt or 0
end

--- Adiciona sujeira ao piso de uma localização (Safehouse ou cômodo).
function LV_DirtSystem.addFloorDirt(locationKey, amount)
    if not locationKey or locationKey == "outside" or amount <= 0 then return end
    LV_ComfortScanner.safehouseCache = LV_ComfortScanner.safehouseCache or {}
    local cache = LV_ComfortScanner.safehouseCache[locationKey]
    if not cache then
        cache = { floorDirt = 0, lastScanHour = 0 }
        LV_ComfortScanner.safehouseCache[locationKey] = cache
    end
    local maxLimit = LV_DirtScoreData.FloorTransfer.MaxFloorDirt or 100.0
    cache.floorDirt = math.max(0, math.min(maxLimit, (cache.floorDirt or 0) + amount))
end

--- Limpa/reduz sujeira do piso de uma localização.
function LV_DirtSystem.cleanFloorDirt(locationKey, amount)
    if not locationKey or locationKey == "outside" or amount <= 0 then return end
    LV_ComfortScanner.safehouseCache = LV_ComfortScanner.safehouseCache or {}
    local cache = LV_ComfortScanner.safehouseCache[locationKey]
    if cache and cache.floorDirt then
        cache.floorDirt = math.max(0, cache.floorDirt - amount)
    end
end

--- Zera a sujeira dos pés ao tomar banho.
function LV_DirtSystem.onShowerOrBath(player)
    if not player then return end
    LV_DirtSystem.setFootDirt(player, 0)
    print("[LarVivo] Pés e calçados higienizados após banho.")
end

--- Adiciona sujeira de piso na cozinha ao preparar alimentos elaborados.
function LV_DirtSystem.onCooking(player)
    if not LV_Config.isDirtSystemEnabled() or not player then return end
    local sq = player:getCurrentSquare()
    if not sq then return end

    local locKey = LV_DirtSystem.getCurrentLocationKey(player, sq)
    if locKey ~= "outside" then
        local mult = LV_Config.get("CookingDirtAmount") or 1.0
        local baseDirt = LV_DirtScoreData.Cooking.DefaultMealDirt or 8.0
        local added = baseDirt * mult
        LV_DirtSystem.addFloorDirt(locKey, added)
        print(string.format("[LarVivo] Culinária caseira: +%.1f de sujeira acumulada na cozinha/cômodo (%s).", added, locKey))
    end
end

--- Helper seguro para calçado compatível com B41 e enum ItemBodyLocation do B42
local function getWornShoes(player)
    if not player then return nil end
    local shoes = nil
    if player.getWornItem and ItemBodyLocation and ItemBodyLocation.SHOES then
        local ok, item = pcall(function() return player:getWornItem(ItemBodyLocation.SHOES) end)
        if ok and item then shoes = item end
    end
    if not shoes and player.getWornItems then
        local worn = player:getWornItems()
        if worn and worn.size then
            for i = 0, worn:size() - 1 do
                local wItem = worn:get(i)
                if wItem then
                    local loc = tostring(wItem:getLocation() or ""):lower()
                    if loc:find("shoes") or loc:find("feet") then
                        shoes = wItem:getItem()
                        break
                    end
                end
            end
        end
    end
    return shoes
end

--- Tenta adicionar mancha de sujeira visual oficial (overlay_grime_floor) com Hard Cap
local function trySpawnFloorGrime(sq, locKey, currentFloorDirt)
    if not sq or sq:isOutside() then return end
    if not LV_Config or not LV_Config.isVisualDirtEnabled or not LV_Config.isVisualDirtEnabled() then return end

    -- 1. Não adiciona se o tile já tem mancha de grime
    local objs = sq:getObjects()
    if not objs then return end
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local sp = obj and obj:getSprite() and obj:getSprite():getName()
        if sp and sp:find("overlay_grime_floor") then
            return
        end
    end

    -- 2. Hard Cap de Cômodo: Máximo de 15% de tiles com grime
    local room = sq:getRoom()
    local roomSquares = room and room.getSquares and room:getSquares()
    if roomSquares and roomSquares.size then
        local totalSquares = roomSquares:size()
        local maxAllowed = math.max(1, math.floor(totalSquares * 0.15))
        local currentGrimeCount = 0
        for s = 0, totalSquares - 1 do
            local rSq = roomSquares:get(s)
            if rSq and rSq.getObjects then
                local rObjs = rSq:getObjects()
                if rObjs then
                    for o = 0, rObjs:size() - 1 do
                        local rObj = rObjs:get(o)
                        local rSp = rObj and rObj:getSprite() and rObj:getSprite():getName()
                        if rSp and rSp:find("overlay_grime_floor") then
                            currentGrimeCount = currentGrimeCount + 1
                            break
                        end
                    end
                end
            end
        end
        if currentGrimeCount >= maxAllowed then
            return
        end
    end

    -- 3. Spawna mancha oficial vanilla (overlay_grime_floor_01_0 a 48)
    local grimeIndex = ZombRand(0, 48)
    local spriteName = "overlay_grime_floor_01_" .. tostring(grimeIndex)
    pcall(function()
        local grimeObj = IsoObject.new(sq, spriteName)
        sq:AddTileObject(grimeObj)
    end)
end

--- Processamento de movimentação do jogador com throttle inteligente.
function LV_DirtSystem.onPlayerMove(player)
    if not LV_Config.isDirtSystemEnabled() or not player then return end

    local sq = player:getCurrentSquare()
    if not sq then return end

    local pNum = player.getPlayerNum and player:getPlayerNum() or 0
    local lastSq = lastPlayerSquares[pNum]
    if lastSq and lastSq.x == sq:getX() and lastSq.y == sq:getY() and lastSq.z == sq:getZ() then
        return
    end

    lastPlayerSquares[pNum] = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
    stepAccumulator[pNum] = (stepAccumulator[pNum] or 0) + 1

    local threshold = LV_DirtScoreData.FloorTransfer.StepThreshold or 10
    if stepAccumulator[pNum] < threshold then return end
    stepAccumulator[pNum] = 0

    local isOutside = sq:isOutside()
    local footDirt = LV_DirtSystem.getFootDirt(player)

    if isOutside then
        -- 1. Acúmulo de sujeira externa
        local gainRate = LV_Config.get("FootDirtGainRate") or 1.0
        local floorSprite = sq:getFloor() and sq:getFloor():getSprite() and sq:getFloor():getSprite():getName() or ""
        floorSprite = tostring(floorSprite):lower()

        local baseGain = LV_DirtScoreData.FootDirtGain.Grass
        if floorSprite:find("dirt") or floorSprite:find("sand") or floorSprite:find("gravel") then
            baseGain = LV_DirtScoreData.FootDirtGain.DirtSand
        elseif floorSprite:find("mud") or floorSprite:find("puddle") then
            baseGain = LV_DirtScoreData.FootDirtGain.MudPuddle
        elseif floorSprite:find("street") or floorSprite:find("road") or floorSprite:find("asphalt") or floorSprite:find("concrete") or floorSprite:find("pavement") or floorSprite:find("sidewalk") then
            -- Ruas da cidade: asfalto sujo e poeira urbana
            baseGain = baseGain + 0.35
            if ZombRand(100) < 20 and BloodBodyPartType and BloodBodyPartType.LowerLeg_L then
                pcall(function() player:addDirt(BloodBodyPartType.LowerLeg_L, nil, false) end)
            end
        end

        -- Floresta / Mata densa
        if floorSprite:find("forest") or (sq.getTree and sq:getTree() ~= nil) then
            baseGain = baseGain + 0.60
            if ZombRand(100) < 30 and BloodBodyPartType and BloodBodyPartType.LowerLeg_R then
                pcall(function() player:addDirt(BloodBodyPartType.LowerLeg_R, nil, false) end)
            end
        end

        -- Checa se está pisando em cadáveres de zumbis no chão
        local deadBodies = sq.getDeadBodys and sq:getDeadBodys()
        if deadBodies and deadBodies:size() > 0 then
            baseGain = baseGain + 2.0
            pcall(function()
                if BloodBodyPartType and BloodBodyPartType.LowerLeg_L and BloodBodyPartType.LowerLeg_R then
                    player:addBlood(BloodBodyPartType.LowerLeg_L, true, true, false)
                    player:addBlood(BloodBodyPartType.LowerLeg_R, true, true, false)
                    player:addDirt(BloodBodyPartType.LowerLeg_L, nil, false)
                    player:addDirt(BloodBodyPartType.LowerLeg_R, nil, false)
                end
            end)
        end

        -- Checa se há sangue no chão externo
        local blood = sq.getBlood and sq:getBlood() or 0
        if blood > 0 then
            baseGain = baseGain + LV_DirtScoreData.FootDirtGain.BloodSplats
            pcall(function()
                if BloodBodyPartType and BloodBodyPartType.Foot_L then
                    player:addBlood(BloodBodyPartType.Foot_L, true, true, false)
                end
            end)
        end

        -- Clima / Chuva
        local cm = getClimateManager and getClimateManager()
        if cm and cm.getPrecipitationIntensity and cm:getPrecipitationIntensity() > 0.05 then
            baseGain = baseGain * (LV_DirtScoreData.FootDirtGain.RainFactor or 1.5)
        end

        -- Descalço? (Usa helper seguro compatível com B42)
        local shoes = getWornShoes(player)
        if not shoes then
            baseGain = baseGain + (LV_DirtScoreData.FootDirtGain.BarefootAdd or 0.25)
        end

        local totalGain = baseGain * gainRate
        LV_DirtSystem.setFootDirt(player, footDirt + totalGain)
        LV_DirtSystem.invalidatePlayerBodyDirtCache(player)
    else
        -- 2. Transferência para o interior da base / decaimento
        local locKey = LV_DirtSystem.getCurrentLocationKey(player, sq)
        if locKey ~= "outside" then
            -- A. Sangramento / Pés Ensanguentados
            local isBleeding = false
            local bd = player.getBodyDamage and player:getBodyDamage()
            if bd and bd.getNumPartsBleeding and bd:getNumPartsBleeding() > 0 then
                isBleeding = true
            end

            if isBleeding and addBloodSplat and sq.getBlood and sq:getBlood() < 3 then
                pcall(function() addBloodSplat(sq, 1) end)
            end

            -- B. Transferência de sujeira dos pés para o piso
            if footDirt > 5.0 then
                local transMult = LV_Config.get("FloorDirtTransferRate") or 1.0
                local ratio = (LV_DirtScoreData.FloorTransfer.TransferRatio or 0.08) * transMult
                local transferred = footDirt * ratio

                LV_DirtSystem.setFootDirt(player, footDirt - transferred)
                LV_DirtSystem.addFloorDirt(locKey, transferred)

                local newFloorDirt = LV_DirtSystem.getFloorDirt(locKey)
                if newFloorDirt >= 25.0 and ZombRand(100) < 35 then
                    trySpawnFloorGrime(sq, locKey, newFloorDirt)
                end
            else
                -- Decaimento natural por caminhar em piso limpo
                local decay = LV_DirtScoreData.FloorTransfer.CleanFloorDecay or 0.05
                LV_DirtSystem.setFootDirt(player, math.max(0, footDirt - decay))
            end
        end
    end
end

-- Invalida o cache de sujeira corporal e notifica a rotina matinal ao concluir o banho/lavagem
Events.OnGameStart.Add(function()
    if ISWashYourself and ISWashYourself.perform and not ISWashYourself._LV_hooked then
        ISWashYourself._LV_hooked = true
        local orig_ISWashYourself_perform = ISWashYourself.perform
        function ISWashYourself:perform()
            orig_ISWashYourself_perform(self)
            if self.character then
                if LV_DirtSystem and LV_DirtSystem.invalidatePlayerBodyDirtCache then
                    LV_DirtSystem.invalidatePlayerBodyDirtCache(self.character)
                end
                if LV_RoutineSystem and LV_RoutineSystem.onWash then
                    LV_RoutineSystem.onWash(self.character)
                end
            end
        end
    end
end)

-- Acúmulo sutil de poeira passiva por passagem de dias (Housekeeping)
Events.EveryDays.Add(function()
    if not LV_Config or not LV_Config.isEnabled() then return end
    if not LV_Config.get("EnablePassiveDust") then return end

    if LV_ComfortScanner and LV_ComfortScanner.safehouseCache then
        local dustRate = (LV_Config.get and LV_Config.get("PassiveDustDailyAmount")) or 0.8
        for locKey, cache in pairs(LV_ComfortScanner.safehouseCache) do
            if locKey ~= "outside" and cache then
                cache.floorDirt = math.min(100.0, (cache.floorDirt or 0) + dustRate)
            end
        end
    end
end)


