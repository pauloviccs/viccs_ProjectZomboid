-- =============================================================================
-- Housing Care System (Lar Vivo) - Toilet Actions (LV_ToiletActions.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Ações com tempo (ISBaseTimedAction) para usar o vaso sanitário ou aliviar-se
--   na natureza, atualizando a sujeira da fixture e aliviando a necessidade
--   fisiológica do sobrevivente.
-- =============================================================================

require "TimedActions/ISBaseTimedAction"
require "LV_Config"
require "LV_DirtScoreData"
require "LV_BladderNeed"
require "LV_ComfortScanner"

LV_ToiletActions = LV_ToiletActions or {}

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
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    if self.setOverrideHandModels then
        self:setOverrideHandModels(nil, nil)
    end
end

function ISUseToiletAction:perform()
    local fixMd = self.toiletObject:getModData()
    local prevDirt = fixMd.LV_FixtureDirt or 0
    local isClean = (prevDirt <= 15)

    -- Incrementa sujeira do vaso conforme o modo
    local addDirt = (self.mode == "poop") and (LV_DirtScoreData.FixtureDirtOnUse.ToiletPoop or 25.0) or (LV_DirtScoreData.FixtureDirtOnUse.ToiletPee or 10.0)
    fixMd.LV_FixtureDirt = math.min(100.0, prevDirt + addDirt)

    if self.toiletObject.transmitModData then
        pcall(function() self.toiletObject:transmitModData() end)
    end

    -- Tenta tocar som de descarga se houver água
    pcall(function()
        local sq = self.toiletObject:getSquare()
        local hasWater = self.toiletObject.hasWater and self.toiletObject:hasWater()
        if hasWater and sq then
            getSoundManager():PlayWorldSound("ToiletFlush", sq, 0.5, 10, 1.0, false)
        end
    end)

    -- Zera necessidade fisiológica e concede buff se limpo
    LV_BladderNeed.relieve(self.character, isClean)

    -- Força recálculo de conforto
    LV_ComfortScanner.startScan(self.character, true)

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
-- 2. Ação com Tempo: Aliviar-se na Natureza (Fora de Casa)
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
    LV_BladderNeed.relieve(self.character, false)
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

    for _, v in ipairs(worldObjects) do
        if v and v.getSprite and v:getSprite() then
            local sprite = v:getSprite()
            local sName = sprite:getName() and tostring(sprite:getName()):lower() or ""
            if (instanceof and instanceof(v, "IsoToilet")) or sName:find("toilet") or sName:find("fixtures_bathroom_01_0") or sName:find("fixtures_bathroom_01_1") or sName:find("fixtures_bathroom_01_2") or sName:find("fixtures_bathroom_01_3") then
                clickedToilet = v
                break
            end
        end
    end

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

    -- Opção no mato / exterior se tiver aperto acumulado (>= 20)
    local sq = player:getCurrentSquare()
    if sq and sq:isOutside() and currentNeed >= 20 then
        local floorSprite = sq:getFloor() and sq:getFloor():getSprite() and sq:getFloor():getSprite():getName() or ""
        floorSprite = tostring(floorSprite):lower()
        if floorSprite:find("grass") or floorSprite:find("dirt") or floorSprite:find("sand") or floorSprite:find("forest") then
            local onRelieveNature = function(pObj)
                ISTimedActionQueue.add(ISRelieveInNatureAction:new(pObj, 80))
            end
            context:addOption(string.format("Aliviar-se na Natureza (Aperto: %d%%)", math.floor(currentNeed)), player, onRelieveNature)
        end
    end
end
