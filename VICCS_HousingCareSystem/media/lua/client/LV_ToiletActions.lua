-- =============================================================================
-- Housing Care System (Lar Vivo) - Toilet Actions (LV_ToiletActions.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Ações com tempo (ISBaseTimedAction) para usar o vaso sanitário ou aliviar-se
--   na natureza, atualizando a sujeira da fixture, consumindo papel higiênico
--   (inventário ou armários próximos) e gerenciando higiene e vestimentas.
-- =============================================================================

require "TimedActions/ISBaseTimedAction"
require "LV_Config"
require "LV_DirtScoreData"
require "LV_BladderNeed"
require "LV_ComfortScanner"

LV_ToiletActions = LV_ToiletActions or {}

--------------------------------------------------------------------------------
-- Helper: Consumo Inteligente de Papel Higiênico
--------------------------------------------------------------------------------
local function consumeToiletPaper(player, toiletObject)
    if not player then return false end

    -- 1. Procura primeiro no inventário do jogador (e suas bolsas)
    local inv = player:getInventory()
    if inv then
        local tp = inv:getFirstTypeRecurse("Base.ToiletPaper") or inv:getFirstTypeRecurse("ToiletPaper")
        if tp then
            if tp.getUsedDelta and tp.setUsedDelta then
                local current = tp:getUsedDelta()
                local delta = (tp.getUseDelta and tp:getUseDelta()) or 0.0625
                if (current + delta) >= 0.999 then
                    inv:Remove(tp)
                else
                    tp:setUsedDelta(current + delta)
                end
            else
                inv:Remove(tp)
            end
            print("[LivingHouse] Papel higienico consumido do inventario do jogador.")
            return true
        end
    end

    -- 2. Procura em armários, gavetas e bancadas adjacentes ao vaso (raio de 1 tile)
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
                                if cTp then
                                    if cTp.getUsedDelta and cTp.setUsedDelta then
                                        local current = cTp:getUsedDelta()
                                        local delta = (cTp.getUseDelta and cTp:getUseDelta()) or 0.0625
                                        if (current + delta) >= 0.999 then
                                            container:Remove(cTp)
                                        else
                                            cTp:setUsedDelta(current + delta)
                                        end
                                    else
                                        container:Remove(cTp)
                                    end
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
-- Helper: Identificação Universal de Vasos Sanitários
--------------------------------------------------------------------------------
local function isToiletObject(v)
    if not v then return false end
    local ok, res = pcall(function()
        if instanceof and instanceof(v, "IsoToilet") then return true end

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
            if sName:find("toilet") or sName:find("latrine") or sName:find("outhouse") then
                return true
            end
            -- fixtures_bathroom_01_0 a 11 (residenciais, comerciais/cabines, presidio)
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

        -- Checagem por propriedades do sprite
        if v.getSprite then
            local okSp, sprite = pcall(v.getSprite, v)
            if okSp and sprite and sprite.getProperties then
                local okProps, props = pcall(sprite.getProperties, sprite)
                if okProps and props and props.Val then
                    local ok1, cName = pcall(props.Val, props, "CustomName")
                    local ok2, gName = pcall(props.Val, props, "GroupName")
                    cName = ok1 and cName and tostring(cName):lower() or ""
                    gName = ok2 and gName and tostring(gName):lower() or ""
                    if cName:find("toilet") or cName:find("vaso") or cName:find("privada") or
                       gName:find("toilet") or gName:find("vaso") or gName:find("privada") then
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
-- 1. Ação com Tempo: Usar Vaso Sanitário
--------------------------------------------------------------------------------
ISUseToiletAction = ISBaseTimedAction:derive("ISUseToiletAction")

function ISUseToiletAction:isValid()
    return self.character and self.toiletObject and not self.character:isDead()
end

function ISUseToiletAction:waitToStart()
    if self.character and self.toiletObject then
        if self.character.faceThisObjectAlt then
            self.character:faceThisObjectAlt(self.toiletObject)
        elseif self.character.faceThisObject then
            self.character:faceThisObject(self.toiletObject)
        end
    end
    return (self.character and self.character.shouldBeTurning and self.character:shouldBeTurning()) or false
end

function ISUseToiletAction:update()
    if self.character and self.toiletObject then
        if self.character.faceThisObjectAlt then
            self.character:faceThisObjectAlt(self.toiletObject)
        elseif self.character.faceThisObject then
            self.character:faceThisObject(self.toiletObject)
        end
    end
end

function ISUseToiletAction:start()
    -- Animação de descanso sentado no vaso em vez de se abaixar como loot
    self:setActionAnim("Bob_SitGround")
    if not self.character:isCurrentActionAnim("Bob_SitGround") then
        self:setActionAnim("Rest")
    end
    if self.setOverrideHandModels then
        self:setOverrideHandModels(nil, nil)
    end
end

function ISUseToiletAction:perform()
    local fixMd = self.toiletObject:getModData()
    local prevDirt = fixMd.LV_FixtureDirt or 0
    local isClean = (prevDirt <= 15)

    -- Consome papel higiênico do inventário ou gaveta próxima
    local hadPaper = consumeToiletPaper(self.character, self.toiletObject)

    -- Incrementa sujeira do vaso conforme o modo
    local addDirt = (self.mode == "poop") and (LV_DirtScoreData.FixtureDirtOnUse.ToiletPoop or 25.0) or (LV_DirtScoreData.FixtureDirtOnUse.ToiletPee or 10.0)
    fixMd.LV_FixtureDirt = math.min(100.0, prevDirt + addDirt)

    if self.toiletObject.transmitModData then
        pcall(function() self.toiletObject:transmitModData() end)
    end

    -- Toca som de descarga se houver água
    pcall(function()
        local sq = self.toiletObject:getSquare()
        local hasWater = self.toiletObject.hasWater and self.toiletObject:hasWater()
        if hasWater and sq then
            getSoundManager():PlayWorldSound("ToiletFlush", sq, 0.5, 10, 1.0, false)
        end
    end)

    -- Alivia necessidade fisiológica com avaliação de papel e limpeza
    LV_BladderNeed.relieve(self.character, isClean, hadPaper, false)

    -- Força recálculo de conforto
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
-- 2. Ação com Tempo: Aliviar-se na Natureza (Fora de Casa / Arbustos)
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
    -- Alívio na natureza: sem papel, com sujeira nas roupas e sem buffs
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

    for _, v in ipairs(worldObjects) do
        if v then
            -- Detecção de vaso sanitário
            if not clickedToilet and isToiletObject(v) then
                clickedToilet = v
            end

            -- Detecção de árvore ou arbusto
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

    -- Menu do Vaso Sanitário
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

        toiletSubMenu:addOption("Aliviar-se (Rapido)", clickedToilet, onUseToilet, player, "pee", 70)
        toiletSubMenu:addOption("Aliviar-se (Completo)", clickedToilet, onUseToilet, player, "poop", 120)
    end

    -- Menu em Árvore / Arbusto
    if clickedVegetation and currentNeed >= 20 then
        local onRelieveTree = function(pObj, vegObj)
            if luautils and luautils.walkAdjObject then
                luautils.walkAdjObject(pObj, vegObj, true, true)
            elseif luautils and luautils.walkAdj then
                luautils.walkAdj(pObj, vegObj:getSquare(), true)
            end
            ISTimedActionQueue.add(ISRelieveInNatureAction:new(pObj, 80))
        end
        context:addOption(string.format("Aliviar-se Atrás do Arbusto/Árvore (Aperto: %d%%)", math.floor(currentNeed)), player, onRelieveTree, clickedVegetation)
    end

    -- Opção no mato / exterior se tiver aperto acumulado (>= 20) e não clicou em árvore
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
