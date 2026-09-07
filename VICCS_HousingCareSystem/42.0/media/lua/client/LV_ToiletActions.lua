-- =============================================================================
-- Housing Care System (Lar Vivo) - Toilet Actions (LV_ToiletActions.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Acoes com tempo (ISBaseTimedAction) para usar o vaso sanitario ou aliviar-se
--   na natureza, atualizando a sujeira da fixture, consumindo papel higienico
--   (inventario ou armarios proximos) e gerenciando higiene e vestimentas.
-- =============================================================================

require "TimedActions/ISBaseTimedAction"
require "LV_Config"
require "LV_DirtScoreData"
require "LV_BladderNeed"
require "LV_ComfortScanner"

LV_ToiletActions = LV_ToiletActions or {}

--------------------------------------------------------------------------------
-- Helper: Consumo Inteligente de Papel Higienico
--------------------------------------------------------------------------------
local function consumeToiletPaper(player, toiletObject)
    if not player then return false end

    local function applyPaperConsumption(tp, container, inv)
        if not tp then return false end
        local parentContainer = tp:getContainer() or container or inv
        local drainDelta = (LV_Config and LV_Config.getToiletPaperDrain and LV_Config.getToiletPaperDrain()) or 0.15
        if drainDelta <= 0 then
            return true
        end
        if tp.getUsedDelta and tp.setUsedDelta then
            local current = tp:getUsedDelta()
            local delta = drainDelta
            local newDelta = math.max(0.0, current - delta)
            if newDelta <= 0.001 then
                if parentContainer and parentContainer.Remove then
                    pcall(parentContainer.Remove, parentContainer, tp)
                end
            else
                tp:setUsedDelta(newDelta)
                if tp.syncItemFields then pcall(tp.syncItemFields, tp) end
            end
            return true
        elseif tp.Use then
            pcall(tp.Use, tp)
            if tp.syncItemFields then pcall(tp.syncItemFields, tp) end
            return true
        else
            if parentContainer and parentContainer.Remove then
                pcall(parentContainer.Remove, parentContainer, tp)
            end
            return true
        end
    end

    -- 1. Procura primeiro no inventario do jogador (e suas bolsas)
    local inv = player:getInventory()
    if inv then
        local tp = inv:getFirstTypeRecurse("Base.ToiletPaper") or inv:getFirstTypeRecurse("ToiletPaper")
        if tp and applyPaperConsumption(tp, inv, inv) then
            print("[LivingHouse] Papel higienico consumido do inventario do jogador.")
            return true
        end
    end

    -- 2. Procura em armarios, gavetas e bancadas adjacentes ao vaso (raio de 1 tile)
    if toiletObject and toiletObject.getSquare then
        local sq = toiletObject:getSquare()
        if sq and sq.getCell then
            local cell = sq:getCell()
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local tSq = cell:getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
                    if tSq then
                        local objs = tSq:getObjects()
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            local container = obj and obj.getContainer and obj:getContainer()
                            if container then
                                local cTp = container:getFirstTypeRecurse("Base.ToiletPaper") or container:getFirstTypeRecurse("ToiletPaper")
                                if cTp and applyPaperConsumption(cTp, container, inv) then
                                    print("[LivingHouse] Papel higienico consumido de armario/gaveta adjacente.")
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- Helper: Identificacao Universal de Vasos Sanitarios
--------------------------------------------------------------------------------
local function isToiletObject(v)
    if not v then return false end
    local ok, res = pcall(function()
        local sName = ""
        if v.getSprite then
            local okSp, sprite = pcall(v.getSprite, v)
            if okSp and sprite and sprite.getName then
                local okNm, rawName = pcall(sprite.getName, sprite)
                if okNm and rawName then
                    sName = tostring(rawName):lower()
                end
            end
        end

        if sName ~= "" then
            if sName:find("toilet") or sName:find("latrine") or sName:find("outhouse") or sName:find("privada") or sName:find("vaso") then
                return true
            end
            -- fixtures_bathroom_01_0 a fixtures_bathroom_01_11 (todos os modelos residenciais, comerciais e presidiais)
            for i = 0, 11 do
                if sName:find("fixtures_bathroom_01_" .. tostring(i)) then
                    return true
                end
            end
            -- fixtures_bathroom_02_* (latrinas, quimicos, outhouses)
            if sName:find("fixtures_bathroom_02_") then
                return true
            end
        end

        -- Checagem por propriedades do sprite (compativel com B42 props.get e B41 props.Val)
        if v.getSprite then
            local okSp, sprite = pcall(v.getSprite, v)
            if okSp and sprite and sprite.getProperties then
                local okProps, props = pcall(sprite.getProperties, sprite)
                if okProps and props then
                    local cName = ""
                    local gName = ""
                    if props.get then
                        local okG1, v1 = pcall(props.get, props, "CustomName")
                        local okG2, v2 = pcall(props.get, props, "GroupName")
                        if okG1 and v1 then cName = tostring(v1):lower() end
                        if okG2 and v2 then gName = tostring(v2):lower() end
                    end
                    if cName == "" and props.Val then
                        local okV1, v1 = pcall(props.Val, props, "CustomName")
                        local okV2, v2 = pcall(props.Val, props, "GroupName")
                        if okV1 and v1 then cName = tostring(v1):lower() end
                        if okV2 and v2 then gName = tostring(v2):lower() end
                    end

                    if cName:find("toilet") or cName:find("vaso") or cName:find("privada") or
                       gName:find("toilet") or gName:find("vaso") or gName:find("privada") or
                       gName == "fancy" or gName == "low" or gName == "chemical" then
                        return true
                    end
                end
            end
        end

        return false
    end)
    return ok and res == true
end

--------------------------------------------------------------------------------
-- Helper: Determina a direcao para a qual o vaso sanitario esta virado
--------------------------------------------------------------------------------
local function getToiletFacingDirection(toilet)
    if not toilet then return nil end
    local facingStr = nil
    pcall(function()
        if toilet.getFacing then
            local f = toilet:getFacing()
            if f then facingStr = tostring(f) end
        end
    end)
    if not facingStr then
        pcall(function()
            local sprite = toilet:getSprite()
            if sprite then
                local props = sprite:getProperties()
                if props then
                    if props.get and props:get("Facing") then
                        facingStr = tostring(props:get("Facing"))
                    elseif props.Val and props:Val("Facing") then
                        facingStr = tostring(props:Val("Facing"))
                    end
                end
            end
        end)
    end
    if facingStr and IsoDirections then
        if IsoDirections.fromString then
            local d = IsoDirections.fromString(facingStr)
            if d then return d end
        end
        if IsoDirections[facingStr] then
            return IsoDirections[facingStr]
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- 1. Acao com Tempo: Usar Vaso Sanitario
--------------------------------------------------------------------------------
ISUseToiletAction = ISBaseTimedAction:derive("ISUseToiletAction")

function ISUseToiletAction:isValid()
    return self.character and self.toiletObject and not self.character:isDead()
end

function ISUseToiletAction:waitToStart()
    if self.character and self.toiletObject then
        local dir = getToiletFacingDirection(self.toiletObject)
        if dir then
            self.character:faceDirection(dir)
        elseif self.character.faceThisObjectAlt then
            self.character:faceThisObjectAlt(self.toiletObject)
        elseif self.character.faceThisObject then
            self.character:faceThisObject(self.toiletObject)
        end
    end
    return (self.character and self.character.shouldBeTurning and self.character:shouldBeTurning()) or false
end

function ISUseToiletAction:update()
    if self.character and self.toiletObject then
        local dir = getToiletFacingDirection(self.toiletObject)
        if dir then
            self.character:faceDirection(dir)
        elseif self.character.faceThisObjectAlt then
            self.character:faceThisObjectAlt(self.toiletObject)
        elseif self.character.faceThisObject then
            self.character:faceThisObject(self.toiletObject)
        end
    end
end

function ISUseToiletAction:start()
    if self.character then
        self.character:setVariable("SatChairStarted", false)
    end
    -- Animacao oficial de sentar no vaso / cadeira (Bob_SatChairIn -> Bob_SatChair)
    self:setActionAnim("SatChair")
    if self.setOverrideHandModels then
        pcall(function() self:setOverrideHandModels(nil, nil) end)
    end
end

function ISUseToiletAction:stop()
    if self.character then
        self.character:setVariable("SatChairStarted", false)
        self.character:setVariable("forceGetUp", true)
    end
    ISBaseTimedAction.stop(self)
end

function ISUseToiletAction:perform()
    if self.character then
        self.character:setVariable("SatChairStarted", false)
        self.character:setVariable("forceGetUp", true)
    end
    local fixMd = self.toiletObject:getModData()
    local prevDirt = fixMd.LV_FixtureDirt or 0
    local isClean = (prevDirt <= 15)

    -- Consome papel higienico do inventario ou gaveta proxima
    local hadPaper = consumeToiletPaper(self.character, self.toiletObject)

    -- Incrementa sujeira do vaso conforme o modo e multiplicador sandbox
    local dirtMult = (LV_Config and LV_Config.getApplianceDirtGainMultiplier and LV_Config.getApplianceDirtGainMultiplier()) or 1.0
    local baseDirt = (self.mode == "poop") and (LV_DirtScoreData.FixtureDirtOnUse.ToiletPoop or 25.0) or (LV_DirtScoreData.FixtureDirtOnUse.ToiletPee or 10.0)
    local addDirt = baseDirt * dirtMult
    fixMd.LV_FixtureDirt = math.min(100.0, prevDirt + addDirt)

    -- Aplica desgaste fisico / mecanico a peca sanitaria
    local deg = (self.mode == "poop") and (LV_DirtScoreData.ApplianceHealthOnUse.ToiletPoop or 2.5) or (LV_DirtScoreData.ApplianceHealthOnUse.ToiletPee or 1.2)
    LV_DirtScoreData.degradeAppliance(self.toiletObject, deg)

    if self.toiletObject.transmitModData then
        pcall(function() self.toiletObject:transmitModData() end)
    end

    -- Consumo de agua da descarga (encanamento ou balde de agua no inventario)
    local flushed = false
    local flushWaterCost = (LV_Config and LV_Config.getToiletFlushWaterDrain and LV_Config.getToiletFlushWaterDrain()) or 1.0
    if flushWaterCost <= 0 then
        flushed = true
    else
        local hasWater = self.toiletObject.hasWater and self.toiletObject:hasWater()
        if hasWater then
            if self.toiletObject.useFluid then
                pcall(function() self.toiletObject:useFluid(flushWaterCost) end)
                flushed = true
            elseif self.toiletObject.useWater then
                pcall(function() self.toiletObject:useWater(flushWaterCost) end)
                flushed = true
            elseif self.toiletObject.getWaterAmount and self.toiletObject.setWaterAmount then
                local w = self.toiletObject:getWaterAmount()
                if w > 0 then
                    self.toiletObject:setWaterAmount(math.max(0, w - flushWaterCost))
                    flushed = true
                end
            end
        end

        -- Se o vaso nao tem agua encanada (ex: corte global de agua), consome do balde de agua no inventario
        if not flushed and self.character then
            local inv = self.character:getInventory()
            if inv then
                local waterContainers = { "Base.BucketWaterFull", "Base.WaterBucket", "Base.PotWater", "Base.PanWater", "Base.WaterBottleFull" }
                for _, wType in ipairs(waterContainers) do
                    local wItem = inv:getFirstTypeRecurse(wType)
                    if wItem then
                        local fc = wItem.getFluidContainer and wItem:getFluidContainer()
                        if fc and fc.getAmount and fc:getAmount() > 0 then
                            fc:adjustAmount(math.max(0.0, fc:getAmount() - flushWaterCost))
                            if wItem.syncItemFields then pcall(wItem.syncItemFields, wItem) end
                            flushed = true
                            break
                        elseif wItem.Use then
                            pcall(wItem.Use, wItem)
                            if wItem.syncItemFields then pcall(wItem.syncItemFields, wItem) end
                            flushed = true
                            break
                        elseif wItem.getUsedDelta and wItem.setUsedDelta then
                            local curD = wItem:getUsedDelta()
                            local stepD = (wItem.getUseDelta and wItem:getUseDelta()) or 0.1
                            local nextD = math.max(0.0, curD - (stepD * flushWaterCost))
                            wItem:setUsedDelta(nextD)
                            if nextD <= 0.001 then
                                local wCont = (wItem.getContainer and wItem:getContainer()) or inv
                                if wCont and wCont.Remove then
                                    wCont:Remove(wItem)
                                end
                            end
                            if wItem.syncItemFields then pcall(wItem.syncItemFields, wItem) end
                            flushed = true
                            break
                        end
                    end
                end
            end
        end
    end

    if flushed then
        pcall(function()
            local sq = self.toiletObject:getSquare()
            if sq then
                getSoundManager():PlayWorldSound("ToiletFlush", sq, 0.5, 10, 1.0, false)
            end
        end)
    end

    -- Alivia necessidade fisiologica com avaliacao de papel e limpeza
    LV_BladderNeed.relieve(self.character, isClean, hadPaper, false)

    -- Forca recalculo de conforto
    if LV_ComfortScanner and LV_ComfortScanner.startScan then
        LV_ComfortScanner.startScan(self.character, true)
    end

    ISBaseTimedAction.perform(self)
end

function ISUseToiletAction:new(character, toiletObject, mode, time)
    local o = ISBaseTimedAction.new(self, character)
    o.toiletObject = toiletObject
    o.mode = mode or "pee"
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = time or 90
    o.forceProgressBar = true
    return o
end

--------------------------------------------------------------------------------
-- 2. Acao com Tempo: Aliviar-se na Natureza (Fora de Casa / Arbustos)
--------------------------------------------------------------------------------
ISRelieveInNatureAction = ISBaseTimedAction:derive("ISRelieveInNatureAction")

function ISRelieveInNatureAction:isValid()
    return self.character and not self.character:isDead()
end

function ISRelieveInNatureAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    if self.setOverrideHandModels then
        self:setOverrideHandModels(nil, nil)
    end
end

function ISRelieveInNatureAction:perform()
    -- Alivio na natureza: sem papel, com sujeira nas roupas e sem buffs
    LV_BladderNeed.relieve(self.character, false, false, true)
    ISBaseTimedAction.perform(self)
end

function ISRelieveInNatureAction:new(character, time)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = time or 80
    o.forceProgressBar = true
    return o
end

--------------------------------------------------------------------------------
-- 3. Construtor de Menu de Contexto
--------------------------------------------------------------------------------
function LV_ToiletActions.onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test or not LV_Config.isBladderNeedEnabled() then return end
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local currentNeed = LV_BladderNeed.getNeed(player)
    local clickedToilet = nil
    local clickedVegetation = nil

    -- 1. Coleta exaustiva de todos os objetos tocados no clique e de seus squares
    local candidateObjects = {}
    local checkedSquares = {}

    local function addSquareObjects(sq)
        if not sq or checkedSquares[sq] then return end
        checkedSquares[sq] = true
        if sq.getObjects then
            local okObjs, objs = pcall(sq.getObjects, sq)
            if okObjs and objs and objs.size then
                for j = 0, objs:size() - 1 do
                    local okG, sObj = pcall(objs.get, objs, j)
                    if okG and sObj then
                        table.insert(candidateObjects, sObj)
                    end
                end
            end
        end
    end

    if worldObjects then
        if worldObjects.size and type(worldObjects.size) == "function" then
            for i = 0, worldObjects:size() - 1 do
                local obj = worldObjects:get(i)
                if obj then
                    table.insert(candidateObjects, obj)
                    if obj.getSquare then addSquareObjects(obj:getSquare()) end
                end
            end
        elseif type(worldObjects) == "table" then
            for _, obj in ipairs(worldObjects) do
                if obj then
                    table.insert(candidateObjects, obj)
                    if obj.getSquare then addSquareObjects(obj:getSquare()) end
                end
            end
        end
    end

    -- 2. Varredura direta dos objetos candidatos coletados
    for _, v in ipairs(candidateObjects) do
        if v then
            if not clickedToilet and isToiletObject(v) then
                clickedToilet = v
            end

            -- Deteccao de arvore ou arbusto
            if not clickedVegetation and currentNeed >= 20 then
                local isVeg = false
                if v.isTree and v:isTree() then isVeg = true end
                if not isVeg and instanceof and instanceof(v, "IsoTree") then isVeg = true end
                if not isVeg and v.getSprite then
                    local okSp, sprite = pcall(v.getSprite, v)
                    if okSp and sprite and sprite.getName then
                        local okNm, rawName = pcall(sprite.getName, sprite)
                        local sName = (okNm and rawName) and tostring(rawName):lower() or ""
                        if sName:find("vegetation") or sName:find("tree") or sName:find("bush") or
                           sName:find("f_bushes") or sName:find("e_americanholly") or sName:find("foliage") then
                            isVeg = true
                        end
                    end
                end
                if isVeg then
                    clickedVegetation = v
                end
            end
        end
    end

    -- 3. Se ainda nao encontrou o vaso, busca nos squares adjacentes (raio de 1 tile)
    -- Garante que cliques no box de vidro, batente da porta ou piso encontrem a privada ao lado!
    if not clickedToilet then
        local scanSquares = {}
        for sq, _ in pairs(checkedSquares) do
            table.insert(scanSquares, sq)
        end
        if player then
            local pSq = player:getCurrentSquare()
            if pSq then table.insert(scanSquares, pSq) end
        end

        local scannedCoords = {}
        for _, centerSq in ipairs(scanSquares) do
            if centerSq and centerSq.getCell then
                local cell = centerSq:getCell()
                local cZ = centerSq:getZ()
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        local cx = centerSq:getX() + dx
                        local cy = centerSq:getY() + dy
                        local coordKey = string.format("%d,%d,%d", cx, cy, cZ)
                        if not scannedCoords[coordKey] then
                            scannedCoords[coordKey] = true
                            local adjSq = cell:getGridSquare(cx, cy, cZ)
                            if adjSq and adjSq.getObjects then
                                local okO, objs = pcall(adjSq.getObjects, adjSq)
                                if okO and objs and objs.size then
                                    for j = 0, objs:size() - 1 do
                                        local okG, o = pcall(objs.get, objs, j)
                                        if okG and o and isToiletObject(o) then
                                            clickedToilet = o
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        if clickedToilet then break end
                    end
                    if clickedToilet then break end
                end
            end
            if clickedToilet then break end
        end
    end

    -- Menu do Vaso Sanitario
    if clickedToilet then
        local toiletSubMenu = context:getNew(context)
        context:addSubMenu(context:addOption(string.format("Usar Banheiro (Necessidade: %d%%)", math.floor(currentNeed))), toiletSubMenu)

        local onUseToilet = function(toilet, pObj, mode, time)
            if luautils and luautils.walkAdjObject then
                if not luautils.walkAdjObject(pObj, toilet, true, true) then
                    return
                end
            elseif luautils and luautils.walkAdj then
                luautils.walkAdj(pObj, toilet:getSquare(), true)
            else
                ISTimedActionQueue.add(ISWalkToTimedAction:new(pObj, toilet:getSquare()))
            end
            ISTimedActionQueue.add(ISUseToiletAction:new(pObj, toilet, mode, time))
        end

        local tHealth = LV_DirtScoreData.getApplianceHealth(clickedToilet)
        if tHealth <= 0 then
            local optClogged = toiletSubMenu:addOption("Vaso Entupido / Danificado (Requer Manutencao)", nil, nil)
            optClogged.notAvailable = true
        else
            toiletSubMenu:addOption("Aliviar-se (Rapido)", clickedToilet, onUseToilet, player, "pee", 70)
            toiletSubMenu:addOption("Aliviar-se (Completo)", clickedToilet, onUseToilet, player, "poop", 120)
        end
    end

    -- Menu em Arvore / Arbusto
    if clickedVegetation and currentNeed >= 20 then
        local onRelieveTree = function(pObj, vegObj)
            if luautils and luautils.walkAdjObject then
                luautils.walkAdjObject(pObj, vegObj, true, true)
            elseif luautils and luautils.walkAdj then
                luautils.walkAdj(pObj, vegObj:getSquare(), true)
            end
            ISTimedActionQueue.add(ISRelieveInNatureAction:new(pObj, 80))
        end
        context:addOption(string.format("Aliviar-se Atras do Arbusto / Arvore (Aperto: %d%%)", math.floor(currentNeed)), player, onRelieveTree, clickedVegetation)
    end

    -- Opcao no mato / exterior se tiver aperto acumulado (>= 20) e nao clicou em arvore
    if not clickedVegetation and currentNeed >= 20 then
        local sq = player:getCurrentSquare()
        if sq and sq:isOutside() then
            local floorSprite = sq:getFloor() and sq:getFloor():getSprite() and sq:getFloor():getSprite():getName() or ""
            floorSprite = tostring(floorSprite):lower()
            if floorSprite:find("grass") or floorSprite:find("dirt") or floorSprite:find("sand") or floorSprite:find("forest") then
                local onRelieveNature = function(pObj)
                    ISTimedActionQueue.add(ISRelieveInNatureAction:new(pObj, 80))
                end
                context:addOption(string.format("Aliviar-se no Solo da Natureza (Aperto: %d%%)", math.floor(currentNeed)), player, onRelieveNature)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(LV_ToiletActions.onFillWorldObjectContextMenu)

return LV_ToiletActions
