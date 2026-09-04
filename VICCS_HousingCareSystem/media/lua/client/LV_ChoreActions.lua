-- =============================================================================
-- Housing Care System (Lar Vivo) - Chore Actions & Auto-Equip (LV_ChoreActions.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Ações com tempo (ISBaseTimedAction) para higienização de peças sanitárias
--   (Vaso, Pia, Banheira, Chuveiro) e limpeza de piso da Safehouse.
--   Inclui Auto-Equip inteligente de panos/esponjas da mochila e integração
--   direta com o Homemaking Engine para concessão de buffs de aconchego.
-- =============================================================================

require "TimedActions/ISBaseTimedAction"
require "LV_Config"
require "LV_DirtScoreData"
require "LV_DirtSystem"
require "LV_ComfortScanner"
require "LV_DentalNeed"

LV_ChoreActions = LV_ChoreActions or {}

--------------------------------------------------------------------------------
-- 1. Ação com Tempo: Limpeza de Fixture Sanitária (Vaso, Pia, Banheira, Chuveiro)
--------------------------------------------------------------------------------
ISCleanFixtureAction = ISBaseTimedAction:derive("ISCleanFixtureAction")

function ISCleanFixtureAction:isValid()
    return self.character and self.targetObject and not self.character:isDead()
end

function ISCleanFixtureAction:waitToStart()
    if self.character and self.targetObject then
        if self.character.faceThisObjectAlt then
            self.character:faceThisObjectAlt(self.targetObject)
        elseif self.character.faceThisObject then
            self.character:faceThisObject(self.targetObject)
        end
    end
    return (self.character and self.character.shouldBeTurning and self.character:shouldBeTurning()) or false
end

function ISCleanFixtureAction:update()
    if self.character and self.targetObject then
        if self.character.faceThisObjectAlt then
            self.character:faceThisObjectAlt(self.targetObject)
        elseif self.character.faceThisObject then
            self.character:faceThisObject(self.targetObject)
        end
    end
end

function ISCleanFixtureAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")

    -- Localiza pano/esponja no inventário para exibir na mão secundária via override
    local inv = self.character:getInventory()
    local tool = nil
    if inv then
        for itemType, _ in pairs(LV_DirtScoreData.CleaningCloths) do
            tool = inv:getFirstTypeRecurse(itemType)
            if tool then break end
        end
    end

    if self.setOverrideHandModels then
        pcall(function() self:setOverrideHandModels(nil, tool) end)
    end
end

function ISCleanFixtureAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISCleanFixtureAction:perform()
    -- Zera a sujeira da fixture
    local md = self.targetObject:getModData()
    md.LV_FixtureDirt = 0
    if self.targetObject.transmitModData then
        pcall(function() self.targetObject:transmitModData() end)
    end

    -- Concede bônus do Homemaking Engine se ativo
    if LV_HomemakingActions and LV_HomemakingActions.grantActionBonus then
        LV_HomemakingActions.grantActionBonus(self.character, "Limpeza Sanitaria", 1.5)
    end

    -- Halo text de confirmação (ASCII limpo)
    local fixName = self.fixtureLabel or "Peca Sanitaria"
    pcall(function()
        if self.character.setHaloNote then
            self.character:setHaloNote(string.format("%s higienizado(a) com sucesso!", fixName), 120, 240, 160, 220)
        end
    end)

    -- Força recálculo do conforto imediato
    LV_ComfortScanner.startScan(self.character, true)

    ISBaseTimedAction.perform(self)
end

function ISCleanFixtureAction:new(character, targetObject, fixtureLabel, time)
    local o = ISBaseTimedAction.new(self, character)
    o.targetObject = targetObject
    o.fixtureLabel = fixtureLabel or "Peca Sanitaria"
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = time or 120
    o.forceProgressBar = true
    return o
end

--------------------------------------------------------------------------------
-- 2. Ação com Tempo: Varrer / Esfregar Piso da Base
--------------------------------------------------------------------------------
ISCleanFloorAction = ISBaseTimedAction:derive("ISCleanFloorAction")

function ISCleanFloorAction:isValid()
    return self.character and not self.character:isDead()
end

function ISCleanFloorAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    if self.setOverrideHandModels then
        self:setOverrideHandModels(nil, nil)
    end
end

function ISCleanFloorAction:new(character, time)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = time or 140
    o.forceProgressBar = true
    return o
end

--------------------------------------------------------------------------------
-- Ação com Tempo: Higiene Bucal / Escovar os Dentes na Pia
--------------------------------------------------------------------------------
ISBrushTeethAction = ISBaseTimedAction:derive("ISBrushTeethAction")

function ISBrushTeethAction:isValid()
    return self.character and not self.character:isDead() and self.targetSink ~= nil
end

function ISBrushTeethAction:waitToStart()
    if self.character and self.targetSink then
        if self.character.faceThisObjectAlt then
            self.character:faceThisObjectAlt(self.targetSink)
        elseif self.character.faceThisObject then
            self.character:faceThisObject(self.targetSink)
        end
    end
    return (self.character and self.character.shouldBeTurning and self.character:shouldBeTurning()) or false
end

function ISBrushTeethAction:update()
    if self.character and self.targetSink then
        if self.character.faceThisObjectAlt then
            self.character:faceThisObjectAlt(self.targetSink)
        elseif self.character.faceThisObject then
            self.character:faceThisObject(self.targetSink)
        end
    end
end

function ISBrushTeethAction:start()
    self:setActionAnim("WashFace")
    if self.setOverrideHandModels then
        pcall(function() self:setOverrideHandModels(self.toothbrush, self.toothpaste) end)
    end

    self.sound = nil
    if self.character and self.character.playSound then
        pcall(function() self.sound = self.character:playSound("BrushTeeth") end)
        if not self.sound then
            pcall(function() self.sound = self.character:playSound("SinkWaterStream") end)
        end
    end
end

function ISBrushTeethAction:stopSound()
    if self.sound and self.character then
        if self.character.stopOrTriggerSound then
            pcall(function() self.character:stopOrTriggerSound(self.sound) end)
        elseif self.character.stopSound then
            pcall(function() self.character:stopSound(self.sound) end)
        end
        self.sound = nil
    end
end

function ISBrushTeethAction:stop()
    self:stopSound()
    ISBaseTimedAction.stop(self)
end

function ISBrushTeethAction:perform()
    self:stopSound()

    -- 1. Consumo balanceado de pasta de dente (5% por escovação = 20 usos)
    if self.toothpaste then
        local USE_COST = 0.05
        local consumed = false

        -- Se for Drainable / DrainableComboItem
        if self.toothpaste.getUsedDelta and self.toothpaste.setUsedDelta then
            local okD, curDelta = pcall(self.toothpaste.getUsedDelta, self.toothpaste)
            if okD and type(curDelta) == "number" then
                local step = USE_COST
                if self.toothpaste.getUseDelta then
                    local okS, customStep = pcall(self.toothpaste.getUseDelta, self.toothpaste)
                    if okS and type(customStep) == "number" and customStep > 0 then
                        step = customStep
                    end
                end

                local newDelta = math.max(0.0, curDelta - step)
                pcall(self.toothpaste.setUsedDelta, self.toothpaste, newDelta)
                consumed = true

                -- Sincroniza também com ModData para máxima integridade
                if self.toothpaste.getModData then
                    local okM, md = pcall(self.toothpaste.getModData, self.toothpaste)
                    if okM and md then
                        md.LV_ToothpasteUses = math.floor(newDelta * 20 + 0.5)
                        if self.toothpaste.transmitModData then
                            pcall(self.toothpaste.transmitModData, self.toothpaste)
                        end
                    end
                end

                if newDelta <= 0.001 then
                    -- Tubo esgotado: remove do inventário
                    if self.character and self.character.setHaloNote then
                        pcall(function() self.character:setHaloNote("Tubo de pasta de dente esgotado!", 240, 180, 80, 260) end)
                    end
                    local inv = self.character:getInventory()
                    if inv and inv.Remove then
                        pcall(inv.Remove, inv, self.toothpaste)
                    end
                elseif newDelta <= 0.10 then
                    -- Alerta suave de que está acabando
                    if self.character and self.character.setHaloNote then
                        pcall(function() self.character:setHaloNote(string.format("Pasta de dente quase no fim (%d%% restante)!", math.ceil(newDelta * 100)), 220, 220, 100, 240) end)
                    end
                end
            end
        end

        -- Fallback de ModData para itens sem Drainable nativo
        if not consumed and self.toothpaste.getModData then
            local okMd, md = pcall(self.toothpaste.getModData, self.toothpaste)
            if okMd and md then
                local curUses = md.LV_ToothpasteUses
                if curUses == nil then curUses = 20 end
                local newUses = math.max(0, tonumber(curUses) - 1)
                md.LV_ToothpasteUses = newUses
                if self.toothpaste.transmitModData then
                    pcall(self.toothpaste.transmitModData, self.toothpaste)
                end
                if self.toothpaste.setUsedDelta then
                    pcall(self.toothpaste.setUsedDelta, self.toothpaste, newUses / 20.0)
                end

                if newUses <= 0 then
                    if self.character and self.character.setHaloNote then
                        pcall(function() self.character:setHaloNote("Tubo de pasta de dente esgotado!", 240, 180, 80, 260) end)
                    end
                    local inv = self.character:getInventory()
                    if inv and inv.Remove then
                        pcall(inv.Remove, inv, self.toothpaste)
                    end
                elseif newUses <= 2 then
                    if self.character and self.character.setHaloNote then
                        pcall(function() self.character:setHaloNote(string.format("Pasta de dente quase no fim (%d/20 usos)!", newUses), 220, 220, 100, 240) end)
                    end
                end
            end
        end
    end

    -- 2. Consome 1 unidade de água da pia se disponível
    if self.targetSink then
        if self.targetSink.getFluidAmount and self.targetSink.useFluid then
            pcall(function() self.targetSink:useFluid(1) end)
        elseif self.targetSink.getWaterAmount and self.targetSink.setWaterAmount then
            local curWater = self.targetSink:getWaterAmount()
            if curWater > 0 then
                self.targetSink:setWaterAmount(math.max(0, curWater - 1))
            end
        end
    end

    -- 3. Integração com LV_DentalNeed (Zera a necessidade bucal e concede bônus)
    if LV_DentalNeed and LV_DentalNeed.brushTeeth then
        LV_DentalNeed.brushTeeth(self.character)
    else
        -- Fallback de alívio
        local stats = self.character.getStats and self.character:getStats()
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
        if LV_RoutineSystem and LV_RoutineSystem.recordHygieneActivity then
            LV_RoutineSystem.recordHygieneActivity(self.character, "BrushedTeeth")
        end
        pcall(function()
            if self.character.setHaloNote then
                self.character:setHaloNote("Dentes escovados e halito fresco! (-Estresse / +Higiene)", 120, 240, 220, 260)
            end
        end)
    end

    ISBaseTimedAction.perform(self)
end

function ISBrushTeethAction:new(character, targetSink, toothbrush, toothpaste, time)
    local o = ISBaseTimedAction.new(self, character)
    o.targetSink = targetSink
    o.toothbrush = toothbrush
    o.toothpaste = toothpaste
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = time or 120
    o.forceProgressBar = true
    return o
end

local function isToothbrushItem(it)
    if not it then return false end
    local ft = ""
    if it.getFullType then
        local ok, res = pcall(it.getFullType, it)
        if ok and res then ft = tostring(res):lower() end
    elseif it.getType then
        local ok, res = pcall(it.getType, it)
        if ok and res then ft = tostring(res):lower() end
    end
    local name = ""
    if it.getName then
        local ok, res = pcall(it.getName, it)
        if ok and res then name = tostring(res):lower() end
    end
    local disp = ""
    if it.getDisplayName then
        local ok, res = pcall(it.getDisplayName, it)
        if ok and res then disp = tostring(res):lower() end
    end

    if ft:find("toothbrush") or ft:find("escova") or
       name:find("toothbrush") or name:find("escova") or
       disp:find("toothbrush") or disp:find("escova") then
        return true
    end
    return false
end

local function isToothpasteItem(it)
    if not it then return false end
    local ft = ""
    if it.getFullType then
        local ok, res = pcall(it.getFullType, it)
        if ok and res then ft = tostring(res):lower() end
    elseif it.getType then
        local ok, res = pcall(it.getType, it)
        if ok and res then ft = tostring(res):lower() end
    end
    local name = ""
    if it.getName then
        local ok, res = pcall(it.getName, it)
        if ok and res then name = tostring(res):lower() end
    end
    local disp = ""
    if it.getDisplayName then
        local ok, res = pcall(it.getDisplayName, it)
        if ok and res then disp = tostring(res):lower() end
    end

    if ft:find("toothpaste") or ft:find("pasta") or ft:find("creme") or ft:find("dentifric") or
       name:find("toothpaste") or name:find("pasta") or name:find("creme") or name:find("dentifric") or
       disp:find("toothpaste") or disp:find("pasta") or disp:find("creme") or disp:find("dentifric") then
        return true
    end
    return false
end

local function getToothpasteRemaining(it)
    if not it then return 0.0 end
    if it.getCurrentUsesFloat then
        local ok, uses = pcall(it.getCurrentUsesFloat, it)
        if ok and type(uses) == "number" then
            return math.max(0.0, math.min(1.0, uses))
        end
    end
    if it.getUsedDelta then
        local ok, delta = pcall(it.getUsedDelta, it)
        if ok and type(delta) == "number" then
            return math.max(0.0, math.min(1.0, delta))
        end
    end
    if it.getModData then
        local ok, md = pcall(it.getModData, it)
        if ok and md and md.LV_ToothpasteUses ~= nil then
            return math.max(0.0, math.min(1.0, (tonumber(md.LV_ToothpasteUses) or 0) / 20.0))
        end
    end
    return 1.0
end

local function findToothbrushAndPaste(character)
    if not character then return nil, nil, false, 0 end
    local inv = character:getInventory()
    local brush = nil
    local candidatePastes = {}

    local function checkItem(it)
        if not it then return end
        if not brush and isToothbrushItem(it) then
            brush = it
        end
        if isToothpasteItem(it) then
            table.insert(candidatePastes, it)
        end
    end

    -- 1. Verifica itens equipados nas mãos do personagem
    if character.getPrimaryHandItem then
        local ok, pHand = pcall(character.getPrimaryHandItem, character)
        if ok and pHand then checkItem(pHand) end
    end
    if character.getSecondaryHandItem then
        local ok, sHand = pcall(character.getSecondaryHandItem, character)
        if ok and sHand then checkItem(sHand) end
    end

    -- 2. Busca direta por tipos oficiais vanilla no inventário
    if inv then
        if not brush and inv.getFirstTypeRecurse then
            local ok, b = pcall(inv.getFirstTypeRecurse, inv, "Base.Toothbrush")
            if ok and b then brush = b end
            if not brush then
                local ok2, b2 = pcall(inv.getFirstTypeRecurse, inv, "Toothbrush")
                if ok2 and b2 then brush = b2 end
            end
        end
    end

    -- 3. Varredura recursiva completa em todas as bolsas, slots e containers do inventário
    if inv then
        local visited = {}
        local function scanContainer(cont)
            if not cont or visited[cont] then return end
            visited[cont] = true
            local items = nil
            if cont.getItems then
                local ok, itms = pcall(cont.getItems, cont)
                if ok and itms then items = itms end
            end
            if items and items.size then
                local size = 0
                local okSize, sVal = pcall(items.size, items)
                if okSize and sVal then size = sVal end
                for i = 0, size - 1 do
                    local it = nil
                    local okIt, itVal = pcall(items.get, items, i)
                    if okIt and itVal then it = itVal end
                    if it then
                        checkItem(it)
                        if it.getInventory then
                            local okInv, subInv = pcall(it.getInventory, it)
                            if okInv and subInv then
                                scanContainer(subInv)
                            end
                        end
                    end
                end
            end
        end
        scanContainer(inv)
    end

    -- 4. Avaliar as pastas candidatas encontradas
    local bestPaste = nil
    local bestRemaining = 0
    local hasAnyPaste = (#candidatePastes > 0)

    -- Prioriza o tubo que já está aberto/em uso com menor quantidade restante > 0
    local lowestNonZero = 999
    for _, p in ipairs(candidatePastes) do
        local rem = getToothpasteRemaining(p)
        if rem > 0.001 then
            if rem < lowestNonZero then
                lowestNonZero = rem
                bestPaste = p
                bestRemaining = rem
            end
        end
    end

    return brush, bestPaste, hasAnyPaste, bestRemaining
end

local function safeCheckProp(props, propName)
    if not props then return false end
    if props.Val then
        local ok, val = pcall(props.Val, props, propName)
        if ok and val and val ~= "" and val ~= "0" and val ~= "false" then
            return true
        end
    end
    if props.Is then
        local ok, res = pcall(props.Is, props, propName)
        if ok and res == true then return true end
    end
    return false
end

local function isSinkObject(v)
    if not v then return false end
    local ok, res = pcall(function()
        -- 1. Check IsoSink instanceof se existir
        if instanceof and instanceof(v, "IsoSink") then
            return true
        end

        -- 2. Checagem por Sprite Name (Pias de banheiro, cozinha e bancadas)
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
            if sName:find("sink") or sName:find("fixtures_sinks_") or
               sName:find("fixtures_bathroom_01_16") or sName:find("fixtures_bathroom_01_17") or
               sName:find("fixtures_bathroom_01_18") or sName:find("fixtures_bathroom_01_19") or
               sName:find("fixtures_bathroom_01_20") or sName:find("fixtures_bathroom_01_21") or
               sName:find("fixtures_bathroom_01_22") or sName:find("fixtures_bathroom_01_23") then
                return true
            end
        end

        -- 3. Checagem por Propriedades de Moveable (CustomName / GroupName / IsSink)
        if v.getSprite then
            local okSp, sprite = pcall(v.getSprite, v)
            if okSp and sprite and sprite.getProperties then
                local okProps, props = pcall(sprite.getProperties, sprite)
                if okProps and props then
                    if props.Val then
                        local ok1, cName = pcall(props.Val, props, "CustomName")
                        local ok2, gName = pcall(props.Val, props, "GroupName")
                        cName = ok1 and cName and tostring(cName):lower() or ""
                        gName = ok2 and gName and tostring(gName):lower() or ""
                        if cName:find("pia") or cName:find("sink") or gName:find("pia") or gName:find("sink") then
                            return true
                        end
                    end
                    if safeCheckProp(props, "IsSink") or safeCheckProp(props, "sink") then
                        if not sName:find("toilet") and not sName:find("bath") and not sName:find("shower") then
                            return true
                        end
                    end
                end
            end
        end

        -- 4. Checagem por nomes do objeto
        local objName = ""
        if v.getName then
            local okN, n = pcall(v.getName, v)
            if okN and n then objName = tostring(n):lower() end
        end
        local typeName = ""
        if v.getObjectName then
            local okO, o = pcall(v.getObjectName, v)
            if okO and o then typeName = tostring(o):lower() end
        end
        if objName:find("pia") or objName:find("sink") or typeName:find("sink") or typeName:find("pia") then
            return true
        end

        -- 5. Pias de construção ou encanadas (IsoThumpable com água encanada)
        if v.isWaterPiped ~= nil then
            local isPiped = false
            if type(v.isWaterPiped) == "boolean" then
                isPiped = v.isWaterPiped
            elseif type(v.isWaterPiped) == "function" then
                local okW, resW = pcall(v.isWaterPiped, v)
                if okW and resW == true then isPiped = true end
            end
            if isPiped then
                if not sName:find("toilet") and not sName:find("bath") and not sName:find("shower") then
                    if sName:find("counter") or sName:find("sink") or objName:find("counter") or objName:find("sink") then
                        return true
                    end
                end
            end
        end

        -- 6. Suporte a FluidContainer da Build 42
        if v.getFluidContainer then
            local okFc, fc = pcall(v.getFluidContainer, v)
            if okFc and fc then
                if not sName:find("toilet") and not sName:find("barrel") and not sName:find("bath") and not sName:find("shower") then
                    if sName:find("counter") or sName:find("sink") or objName:find("counter") or objName:find("sink") then
                        return true
                    end
                end
            end
        end

        return false
    end)

    return ok and res == true
end

local function hasWaterInSink(sinkObj)
    if not sinkObj then return false end
    local ok, res = pcall(function()
        if sinkObj.hasWater then
            local ok1, w = pcall(sinkObj.hasWater, sinkObj)
            if ok1 and w == true then return true end
        end
        if sinkObj.getWaterAmount then
            local ok2, amt = pcall(sinkObj.getWaterAmount, sinkObj)
            if ok2 and type(amt) == "number" and amt > 0 then return true end
        end
        if sinkObj.getFluidAmount then
            local ok3, amt = pcall(sinkObj.getFluidAmount, sinkObj)
            if ok3 and type(amt) == "number" and amt > 0 then return true end
        end
        if sinkObj.hasFluid then
            local okHf, hf = pcall(sinkObj.hasFluid, sinkObj)
            if okHf and hf == true then return true end
        end
        if sinkObj.isWaterPiped ~= nil then
            if type(sinkObj.isWaterPiped) == "boolean" and sinkObj.isWaterPiped == true then
                return true
            elseif type(sinkObj.isWaterPiped) == "function" then
                local ok4, p = pcall(sinkObj.isWaterPiped, sinkObj)
                if ok4 and p == true then return true end
            end
        end

        local sq = sinkObj.getSquare and sinkObj:getSquare()
        if sq then
            if sq.hasWater then
                local ok5, w = pcall(sq.hasWater, sq)
                if ok5 and w == true then return true end
            end
            if sq.isWaterPiped ~= nil then
                if type(sq.isWaterPiped) == "boolean" and sq.isWaterPiped == true then
                    return true
                elseif type(sq.isWaterPiped) == "function" then
                    local ok6, p = pcall(sq.isWaterPiped, sq)
                    if ok6 and p == true then return true end
                end
            end
        end

        -- Fallback seguro para período pré-corte de água no mundo
        if getGameTime and SandboxVars and SandboxVars.WaterShutModifier then
            local okGt, gt = pcall(getGameTime)
            if okGt and gt and gt.getNightsSurvived then
                local okN, nights = pcall(gt.getNightsSurvived, gt)
                if okN and type(nights) == "number" and nights < (SandboxVars.WaterShutModifier or 14) then
                    return true
                end
            end
        end

        return true
    end)

    return ok and res == true
end

--------------------------------------------------------------------------------
-- 3. Construtor de Menu de Contexto (Botão Direito no Mundo)
--------------------------------------------------------------------------------
function LV_ChoreActions.onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return end

    local okMaster, errMaster = pcall(function()
        local player = nil
        if type(playerNum) == "number" then
            player = getSpecificPlayer(playerNum)
        elseif type(playerNum) == "userdata" or type(playerNum) == "table" then
            player = playerNum
        end
        if not player and getPlayer then
            player = getPlayer()
        end
        if not player or player:isDead() then return end

        local inv = player:getInventory()

        -- Verifica se possui ferramenta de limpeza (pano, toalha, esponja, vassoura, esfregão)
        local hasCleaningCloth = false
        if LV_DirtScoreData and LV_DirtScoreData.CleaningCloths and inv then
            for itemType, _ in pairs(LV_DirtScoreData.CleaningCloths) do
                if inv.getFirstTypeRecurse then
                    local okC, cl = pcall(inv.getFirstTypeRecurse, inv, itemType)
                    if okC and cl then
                        hasCleaningCloth = true
                        break
                    end
                end
            end
        end

        -- Coleta exaustiva de candidatos do raio de clique + todos os objetos do square
        local candidateObjects = {}
        local checkedSquares = {}

        if worldObjects then
            if worldObjects.size and type(worldObjects.size) == "function" then
                local okSz, sz = pcall(worldObjects.size, worldObjects)
                if okSz and sz then
                    for i = 0, sz - 1 do
                        local okG, obj = pcall(worldObjects.get, worldObjects, i)
                        if okG and obj then table.insert(candidateObjects, obj) end
                    end
                end
            elseif type(worldObjects) == "table" then
                for _, obj in ipairs(worldObjects) do
                    if obj then table.insert(candidateObjects, obj) end
                end
            end
        end

        local extraObjects = {}
        for _, obj in ipairs(candidateObjects) do
            if obj and obj.getSquare then
                local okSq, sq = pcall(obj.getSquare, obj)
                if okSq and sq and not checkedSquares[sq] then
                    checkedSquares[sq] = true
                    local sqObjs = nil
                    if sq.getObjects then
                        local okObjs, objsVal = pcall(sq.getObjects, sq)
                        if okObjs and objsVal then sqObjs = objsVal end
                    end
                    if sqObjs and sqObjs.size then
                        local okSz2, sz2 = pcall(sqObjs.size, sqObjs)
                        if okSz2 and sz2 then
                            for j = 0, sz2 - 1 do
                                local okG2, sObj = pcall(sqObjs.get, sqObjs, j)
                                if okG2 and sObj and sObj ~= obj then
                                    table.insert(extraObjects, sObj)
                                end
                            end
                        end
                    end
                end
            end
        end
        for _, obj in ipairs(extraObjects) do
            table.insert(candidateObjects, obj)
        end

        local clickedFixture = nil
        local fixtureLabel = nil
        local sinkObject = nil

        -- Varre todos os objetos candidatos
        for _, v in ipairs(candidateObjects) do
            if v then
                -- Identificação infalível de Pia
                if not sinkObject and isSinkObject(v) then
                    sinkObject = v
                end

                -- Identificação de peças sanitárias para faxina
                if not clickedFixture and v.getSprite then
                    local okSp, sprite = pcall(v.getSprite, v)
                    if okSp and sprite and sprite.getName then
                        local okNm, rawName = pcall(sprite.getName, sprite)
                        local sName = (okNm and rawName) and tostring(rawName):lower() or ""

                        if (instanceof and instanceof(v, "IsoToilet")) or sName:find("toilet") or sName:find("fixtures_bathroom_01_0") or sName:find("fixtures_bathroom_01_1") or sName:find("fixtures_bathroom_01_2") or sName:find("fixtures_bathroom_01_3") then
                            clickedFixture = v
                            fixtureLabel = "Vaso Sanitario"
                        elseif isSinkObject(v) then
                            clickedFixture = v
                            fixtureLabel = "Pia"
                        elseif sName:find("bath") or sName:find("fixtures_bathroom_01_24") or sName:find("fixtures_bathroom_01_25") or sName:find("fixtures_bathroom_01_26") or sName:find("fixtures_bathroom_01_27") then
                            clickedFixture = v
                            fixtureLabel = "Banheira"
                        elseif sName:find("shower") or sName:find("fixtures_bathroom_01_32") or sName:find("fixtures_bathroom_01_33") then
                            clickedFixture = v
                            fixtureLabel = "Chuveiro"
                        end
                    end
                end
            end
        end

        -- A. OPÇÃO DE ESCOVAR OS DENTES (Higiene Pessoal)
        if sinkObject then
            local brush, paste, hasAnyPaste, remaining = findToothbrushAndPaste(player)
            local hasWater = hasWaterInSink(sinkObject)

            if brush and paste then
                local pct = math.floor((remaining * 100) + 0.5)
                if pct > 100 then pct = 100 end
                if pct <= 0 then pct = 1 end

                if hasWater then
                    local onBrushTeeth = function(sink, pObj, brushItem, pasteItem)
                        local inv = pObj:getInventory()
                        if brushItem and brushItem.getContainer and brushItem:getContainer() ~= inv then
                            ISInventoryPaneContextMenu.transferIfNeeded(pObj, brushItem)
                        end
                        if pasteItem and pasteItem.getContainer and pasteItem:getContainer() ~= inv then
                            ISInventoryPaneContextMenu.transferIfNeeded(pObj, pasteItem)
                        end
                        if luautils and luautils.walkAdjObject then
                            if not luautils.walkAdjObject(pObj, sink, true, true) then
                                return
                            end
                        elseif luautils and luautils.walkAdj then
                            luautils.walkAdj(pObj, sink:getSquare(), true)
                        else
                            ISTimedActionQueue.add(ISWalkToTimedAction:new(pObj, sink:getSquare()))
                        end
                        ISTimedActionQueue.add(ISBrushTeethAction:new(pObj, sink, brushItem, pasteItem, 120))
                    end
                    context:addOption(string.format("Escovar os Dentes (Pasta: %d%%)", pct), sinkObject, onBrushTeeth, player, brush, paste)
                else
                    local opt = context:addOption(string.format("Escovar os Dentes (Sem Agua na Pia) [Pasta: %d%%]", pct), nil, nil)
                    opt.notAvailable = true
                end
            elseif brush and hasAnyPaste and not paste then
                local opt = context:addOption("Escovar os Dentes (Tubo de Pasta Vazio)", nil, nil)
                opt.notAvailable = true
            elseif brush and not hasAnyPaste then
                local opt = context:addOption("Escovar os Dentes (Necessita Pasta de Dente)", nil, nil)
                opt.notAvailable = true
            elseif not brush and (paste or hasAnyPaste) then
                local opt = context:addOption("Escovar os Dentes (Necessita Escova de Dentes)", nil, nil)
                opt.notAvailable = true
            else
                local opt = context:addOption("Escovar os Dentes (Necessita Escova e Pasta)", nil, nil)
                opt.notAvailable = true
            end
        end

        -- B. OPÇÃO DE HIGIENIZAÇÃO DE PEÇAS SANITÁRIAS (Se o sistema de sujeira estiver ativo)
        if LV_Config and LV_Config.isDirtSystemEnabled and LV_Config.isDirtSystemEnabled() and clickedFixture then
            local fixMd = clickedFixture.getModData and clickedFixture:getModData()
            local dirt = fixMd and fixMd.LV_FixtureDirt or 0

            if dirt > 0 then
                if hasCleaningCloth then
                    local onCleanFixture = function(fixture, pObj, label)
                        local inv = pObj:getInventory()
                        local cloth = nil
                        if inv then
                            for itemType, _ in pairs(LV_DirtScoreData.CleaningCloths) do
                                cloth = inv:getFirstTypeRecurse(itemType)
                                if cloth then break end
                            end
                        end
                        if cloth and cloth.getContainer and cloth:getContainer() ~= inv then
                            ISInventoryPaneContextMenu.transferIfNeeded(pObj, cloth)
                        end
                        if luautils and luautils.walkAdjObject then
                            if not luautils.walkAdjObject(pObj, fixture, true, true) then
                                return
                            end
                        elseif luautils and luautils.walkAdj then
                            luautils.walkAdj(pObj, fixture:getSquare(), true)
                        else
                            ISTimedActionQueue.add(ISWalkToTimedAction:new(pObj, fixture:getSquare()))
                        end
                        ISTimedActionQueue.add(ISCleanFixtureAction:new(pObj, fixture, label, 120))
                    end
                    context:addOption(string.format("Higienizar %s (Sujeira: %d%%)", fixtureLabel or "Objeto", math.floor(dirt)), clickedFixture, onCleanFixture, player, fixtureLabel or "Objeto")
                else
                    local opt = context:addOption(string.format("Higienizar %s (Necessita Pano/Esponja)", fixtureLabel or "Objeto"), nil, nil)
                    opt.notAvailable = true
                end
            end
        end

        -- C. Opção de Varrer Piso do Cômodo (se houver sujeira acumulada)
        local sq = player:getCurrentSquare()
        if sq and not sq:isOutside() then
            local locKey = LV_DirtSystem.getCurrentLocationKey(player, sq)
            local floorDirt = LV_DirtSystem.getFloorDirt(locKey)
            if floorDirt >= 10.0 then
                if hasCleaningCloth then
                    local onCleanFloor = function(pObj)
                        local inv = pObj:getInventory()
                        local cloth = nil
                        if inv then
                            for itemType, _ in pairs(LV_DirtScoreData.CleaningCloths) do
                                cloth = inv:getFirstTypeRecurse(itemType)
                                if cloth then break end
                            end
                        end
                        if cloth and cloth.getContainer and cloth:getContainer() ~= inv then
                            ISInventoryPaneContextMenu.transferIfNeeded(pObj, cloth)
                        end
                        ISTimedActionQueue.add(ISCleanFloorAction:new(pObj, 140))
                    end
                    context:addOption(string.format("Varrer e Limpar Piso (Sujeira: %d%%)", math.floor(floorDirt)), player, onCleanFloor)
                else
                    local opt = context:addOption("Varrer e Limpar Piso (Necessita Pano/Vassoura)", nil, nil)
                    opt.notAvailable = true
                end
            end
        end

        -- D. Opção de Reivindicar Residência como Meu Lar (Single Player / SP Claim)
        if sq and not sq:isOutside() and (not isClient() or not SafeHouse) then
            local building = sq.getBuilding and sq:getBuilding()
            if building then
                local bId = building.getID and building:getID()
                local pMd = player.getModData and player:getModData()
                if bId and pMd then
                    if pMd.LV_ClaimedBaseBuildingId == bId then
                        local onUnclaimHome = function(pObj)
                            local md = pObj:getModData()
                            md.LV_ClaimedBaseBuildingId = nil
                            if pObj.setHaloNote then
                                pcall(function() pObj:setHaloNote("Residencia desocupada. Voce nao possui mais uma base oficial.", 220, 180, 80, 260) end)
                            end
                            if LV_ComfortScanner and LV_ComfortScanner.startScan then
                                LV_ComfortScanner.startScan(pObj, true)
                            end
                            if LV_HouseDashboard and LV_HouseDashboard.getInstance then
                                pcall(function() LV_HouseDashboard.getInstance():refreshData(true) end)
                            end
                        end
                        context:addOption("Living House: Desocupar Base / Abandonar Lar", player, onUnclaimHome)
                    else
                        local onClaimHome = function(pObj, buildingId)
                            local md = pObj:getModData()
                            md.LV_ClaimedBaseBuildingId = buildingId
                            md.LV_ClaimedBaseName = md.LV_ClaimedBaseName or "Meu Lar"
                            if pObj.setHaloNote then
                                pcall(function() pObj:setHaloNote("Residencia estabelecida como seu Lar Oficial!", 80, 240, 140, 260) end)
                            end
                            if LV_ComfortScanner and LV_ComfortScanner.startScan then
                                LV_ComfortScanner.startScan(pObj, true)
                            end
                            if LV_HouseDashboard and LV_HouseDashboard.getInstance then
                                pcall(function() LV_HouseDashboard.getInstance():refreshData(true) end)
                            end
                        end
                        context:addOption("Living House: Estabelecer Residencia como Meu Lar", player, onClaimHome, bId)
                    end
                end
            end
        end
    end)

    if not okMaster and errMaster then
        print("[LivingHouse] Aviso seguro em onFillWorldObjectContextMenu: " .. tostring(errMaster))
    end
end

-- =============================================================================
-- HOOK: Renderização da Barra "Restante:" (Remaining) no Painel de Inventário e Tooltip
-- Garante que a barra verde com a durabilidade seja exibida tanto no ISInventoryPane
-- quanto no ISToolTipInv, mesmo para itens já existentes em saves prévios.
-- =============================================================================
local function setupToothpasteUIHooks()
    if ISInventoryPane and ISInventoryPane.drawItemDetails and not ISInventoryPane._lv_toothpaste_hooked then
        ISInventoryPane._lv_toothpaste_hooked = true
        local orig_drawItemDetails = ISInventoryPane.drawItemDetails
        function ISInventoryPane:drawItemDetails(item, y, xoff, yoff, red)
            if item and isToothpasteItem(item) then
                local hdrHgt = self.headerHgt
                local top = hdrHgt + y * self.itemHgt + yoff
                local hc = getCore():getGoodHighlitedColor()
                local fgBar = {r=hc:getR(), g=hc:getG(), b=hc:getB(), a=1}
                local fgText = {r=0.6, g=0.8, b=0.5, a=0.6}
                if red then fgText = {r=0.0, g=0.0, b=0.5, a=0.7} end
                local text = getText("IGUI_invpanel_Remaining") .. ":"
                local fraction = getToothpasteRemaining(item)
                self:drawTextAndProgressBar(text, fraction, xoff, top, fgText, fgBar)
                return
            end
            return orig_drawItemDetails(self, item, y, xoff, yoff, red)
        end
    end

    if ISToolTipInv and ISToolTipInv.render and not ISToolTipInv._lv_toothpaste_hooked then
        ISToolTipInv._lv_toothpaste_hooked = true
        local orig_ISToolTipInv_render = ISToolTipInv.render
        function ISToolTipInv:render()
            orig_ISToolTipInv_render(self)
            if self.item and isToothpasteItem(self.item) and self:getIsVisible() then
                local isDrainable = false
                if instanceof then
                    local okI, resI = pcall(instanceof, self.item, "Drainable")
                    if okI and resI then isDrainable = true end
                end
                -- Se não for Drainable nativo no Java, o DoTooltip não desenha a barra.
                -- Desenhamos a barra de Restante no rodapé do tooltip:
                if not isDrainable then
                    local fraction = getToothpasteRemaining(self.item)
                    local text = getText("IGUI_invpanel_Remaining") .. ":"
                    local textWid = getTextManager():MeasureStringX(UIFont.Small, text)
                    local y = self:getHeight() - 16
                    local hc = getCore():getGoodHighlitedColor()
                    local fgBar = {r=hc:getR(), g=hc:getG(), b=hc:getB(), a=1}
                    self:drawText(text, 10, y, 0.6, 0.8, 0.5, 0.9, UIFont.Small)
                    local barX = 10 + textWid + 8
                    local barW = math.max(60, self:getWidth() - barX - 12)
                    self:drawProgressBar(barX, y + 4, barW, 4, fraction, fgBar)
                end
            end
        end
    end
end

setupToothpasteUIHooks()
Events.OnGameStart.Add(setupToothpasteUIHooks)


