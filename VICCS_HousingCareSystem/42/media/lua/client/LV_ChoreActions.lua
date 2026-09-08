-- =============================================================================
-- Housing Care System (Lar Vivo) - Chore Actions & Auto-Equip (LV_ChoreActions.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Acoes com tempo (ISBaseTimedAction) para higienizacao de pecas sanitarias
--   (Vaso, Pia, Banheira, Chuveiro) e limpeza de piso da Safehouse.
--   Inclui Auto-Equip inteligente de panos/esponjas da mochila e integracao
--   direta com o Homemaking Engine para concessao de buffs de aconchego.
-- =============================================================================

require "TimedActions/ISBaseTimedAction"
require "LV_Config"
require "LV_DirtScoreData"
require "LV_DirtSystem"
require "LV_ComfortScanner"
require "LV_DentalNeed"

LV_ChoreActions = LV_ChoreActions or {}

-- Forward declarations de funcoes utilitarias usadas pelos TimedActions e menus de contexto
local findCleaningTool
local findWaterOrCleaningContainer
local isCleaningToolItem

--------------------------------------------------------------------------------
-- 1. Acao com Tempo: Limpeza de Fixture Sanitaria (Vaso, Pia, Banheira, Chuveiro)
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

    -- Localiza pano/esponja no inventario para exibir na mao secundaria via override
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

    -- Consome agente de limpeza (Bleach, Soap2, CleaningLiquid) e suja o pano utilizado
    local inv = self.character and self.character:getInventory()
    if inv then
        local agentDrain = (LV_Config and LV_Config.getCleanFixtureCleanerDrain and LV_Config.getCleanFixtureCleanerDrain()) or 0.05
        local clothDirtGain = (LV_Config and LV_Config.getCleanFixtureClothDirtGain and LV_Config.getCleanFixtureClothDirtGain()) or 15
        if agentDrain > 0 then
            local agentTypes = { "Base.Bleach", "Base.CleaningLiquid", "Base.Soap2" }
            for _, aType in ipairs(agentTypes) do
                local agent = inv:getFirstTypeRecurse(aType)
                if agent then
                    local fc = agent.getFluidContainer and agent:getFluidContainer()
                    if fc and fc.getAmount and fc:getAmount() > 0 then
                        fc:adjustAmount(math.max(0.0, fc:getAmount() - (agentDrain * 2.0)))
                        if agent.syncItemFields then pcall(agent.syncItemFields, agent) end
                        break
                    elseif agent.getUsedDelta and agent.setUsedDelta then
                        local curD = agent:getUsedDelta()
                        local nextD = math.max(0.0, curD - agentDrain)
                        agent:setUsedDelta(nextD)
                        if nextD <= 0.001 then
                            local agentCont = (agent.getContainer and agent:getContainer()) or inv
                            if agentCont and agentCont.Remove then
                                agentCont:Remove(agent)
                            end
                        end
                        if agent.syncItemFields then pcall(agent.syncItemFields, agent) end
                        break
                    elseif agent.Use then
                        pcall(agent.Use, agent)
                        if agent.syncItemFields then pcall(agent.syncItemFields, agent) end
                        break
                    end
                end
            end
        end

        for itemType, _ in pairs(LV_DirtScoreData.CleaningCloths) do
            local cloth = inv:getFirstTypeRecurse(itemType)
            if cloth then
                local fType = cloth.getFullType and cloth:getFullType() or ""
                if fType == "Base.RippedSheets" then
                    local container = cloth:getContainer() or inv
                    if container and container.Remove then
                        container:Remove(cloth)
                        if inv.AddItem then inv:AddItem("Base.RippedSheetsDirty") end
                    end
                else
                    if cloth.setDirtyness and clothDirtGain > 0 then
                        local curD = (cloth.getDirtiness and cloth:getDirtiness()) or 0.0
                        cloth:setDirtyness(math.min(100.0, curD + clothDirtGain))
                    end
                    if cloth.setWetness then
                        local curW = (cloth.getWetness and cloth:getWetness()) or 0.0
                        cloth:setWetness(math.min(100.0, curW + 30.0))
                    end
                    if cloth.syncItemFields then pcall(cloth.syncItemFields, cloth) end
                end
                break
            end
        end
    end

    -- Concede bonus do Homemaking Engine se ativo
    if LV_HomemakingActions and LV_HomemakingActions.grantActionBonus then
        LV_HomemakingActions.grantActionBonus(self.character, "Limpeza Sanitaria", 1.5)
    end

    -- Halo text de confirmacao (ASCII limpo)
    local fixName = self.fixtureLabel or "Peca Sanitaria"
    pcall(function()
        if self.character.setHaloNote then
            self.character:setHaloNote(string.format("%s higienizado(a) com sucesso!", fixName), 120, 240, 160, 220)
        end
    end)

    -- Forca recalculo do conforto imediato
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
-- 1B. Acao com Tempo: Manutencao e Reparo de Aparelhos (Pia, Vaso, Chuveiro, Banheira, Fogao)
--------------------------------------------------------------------------------
ISMaintainApplianceAction = ISBaseTimedAction:derive("ISMaintainApplianceAction")

function ISMaintainApplianceAction:isValid()
    return self.character and self.targetObject and not self.character:isDead()
end

function ISMaintainApplianceAction:waitToStart()
    if self.character and self.targetObject then
        if self.character.faceThisObjectAlt then
            self.character:faceThisObjectAlt(self.targetObject)
        elseif self.character.faceThisObject then
            self.character:faceThisObject(self.targetObject)
        end
    end
    return (self.character and self.character.shouldBeTurning and self.character:shouldBeTurning()) or false
end

function ISMaintainApplianceAction:update()
    if self.character and self.targetObject then
        if self.character.faceThisObjectAlt then
            self.character:faceThisObjectAlt(self.targetObject)
        elseif self.character.faceThisObject then
            self.character:faceThisObject(self.targetObject)
        end
    end
end

function ISMaintainApplianceAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")

    if self.tool and self.setOverrideHandModels then
        pcall(function() self:setOverrideHandModels(self.tool, nil) end)
    end

    pcall(function()
        local sq = self.targetObject:getSquare()
        if sq then
            getSoundManager():PlayWorldSound("RepairDoor", sq, 0.5, 10, 1.0, false)
        end
    end)
end

function ISMaintainApplianceAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISMaintainApplianceAction:perform()
    -- Restaura a integridade/saude do aparelho
    LV_DirtScoreData.setApplianceHealth(self.targetObject, 100.0)

    -- Consome fita adesiva (subtracao correta), desgasta ferramenta duravel ou consome sucata
    if self.tool then
        if self.toolData and self.toolData.usesDelta then
            local tapeDrain = (LV_Config and LV_Config.getMaintainDuctTapeDrain and LV_Config.getMaintainDuctTapeDrain()) or self.toolData.deltaCost or 0.15
            if tapeDrain > 0 then
                if self.tool.getUsedDelta and self.tool.setUsedDelta then
                    local current = self.tool:getUsedDelta()
                    local newDelta = math.max(0.0, current - tapeDrain)
                    if newDelta <= 0.001 then
                        local inv = self.character:getInventory()
                        local toolCont = (self.tool.getContainer and self.tool:getContainer()) or inv
                        if toolCont and toolCont.Remove then
                            toolCont:Remove(self.tool)
                        end
                    else
                        self.tool:setUsedDelta(newDelta)
                    end
                elseif self.tool.Use then
                    pcall(self.tool.Use, self.tool)
                end
                if self.tool.syncItemFields then pcall(self.tool.syncItemFields, self.tool) end
            end
        elseif self.tool.getCondition and self.tool.setCondition then
            local wearChance = (LV_Config and LV_Config.getMaintainToolWearChance and LV_Config.getMaintainToolWearChance()) or 5
            if wearChance > 0 and ZombRand(100) < wearChance then
                local newCond = math.max(0, self.tool:getCondition() - 1)
                self.tool:setCondition(newCond)
                if self.tool.syncItemFields then pcall(self.tool.syncItemFields, self.tool) end
            end
        else
            local fType = self.tool.getFullType and self.tool:getFullType() or ""
            if fType == "Base.ElectronicsScrap" or fType == "Base.ScrapMetal" then
                local scrapAmount = (LV_Config and LV_Config.getMaintainScrapAmount and LV_Config.getMaintainScrapAmount()) or 1
                if scrapAmount > 0 then
                    local inv = self.character:getInventory()
                    local container = self.tool:getContainer() or inv
                    if container and container.Remove then
                        container:Remove(self.tool)
                        if scrapAmount > 1 and inv then
                            for k = 2, scrapAmount do
                                local extra = inv:getFirstTypeRecurse(fType)
                                if extra then
                                    local extraCont = (extra.getContainer and extra:getContainer()) or inv
                                    if extraCont and extraCont.Remove then
                                        extraCont:Remove(extra)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Concede bonus do Homemaking Engine se ativo
    if LV_HomemakingActions and LV_HomemakingActions.grantActionBonus then
        LV_HomemakingActions.grantActionBonus(self.character, "Manutencao Residencial", 2.0)
    end

    -- Halo text de confirmacao (ASCII puro)
    local fixName = self.fixtureLabel or "Aparelho"
    pcall(function()
        if self.character.setHaloNote then
            self.character:setHaloNote(string.format("Manutencao concluida: %s restaurado!", fixName), 120, 240, 160, 220)
        end
    end)

    -- Forca recalculo do conforto imediato
    if LV_ComfortScanner and LV_ComfortScanner.startScan then
        LV_ComfortScanner.startScan(self.character, true)
    end

    ISBaseTimedAction.perform(self)
end

function ISMaintainApplianceAction:new(character, targetObject, tool, toolData, fixtureLabel, time)
    local o = ISBaseTimedAction.new(self, character)
    o.targetObject = targetObject
    o.tool = tool
    o.toolData = toolData
    o.fixtureLabel = fixtureLabel or "Aparelho"
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = time or 150
    o.forceProgressBar = true
    return o
end

--- Busca ferramenta ou insumo de manutencao valido no inventario do jogador
local function findMaintenanceTool(player)
    if not player then return nil, nil end
    local inv = player:getInventory()
    if not inv then return nil, nil end

    -- 1. Primeiro verifica o item equipado na mao principal
    local primary = player:getPrimaryHandItem()
    if primary then
        local fullType = (primary.getFullType and primary:getFullType()) or ""
        if LV_DirtScoreData.MaintenanceTools[fullType] then
            return primary, LV_DirtScoreData.MaintenanceTools[fullType]
        end
    end

    -- 2. Busca no inventario e recipientes internos
    for itemType, toolInfo in pairs(LV_DirtScoreData.MaintenanceTools) do
        local item = inv:getFirstTypeRecurse(itemType)
        if item then
            return item, toolInfo
        end
    end

    return nil, nil
end

local function isTwoHandedCleaningTool(item)
    if not item then return false end
    local fullType = (item.getFullType and item:getFullType() or item.getType and item:getType() or ""):lower()
    local name = (item.getName and item:getName() or ""):lower()

    -- Panos, toalhas, esponjas e lencois sao ESTRITAMENTE de uma mao (abaixado)
    if fullType:find("dishcloth") or fullType:find("sponge") or fullType:find("bathtowel")
       or fullType:find("towel") or fullType:find("rippedsheets") or fullType:find("cloth")
       or name:find("pano") or name:find("esponja") or name:find("toalha") or name:find("lencol") then
        return false
    end

    -- Vassouras e esfregoes (Broom, Mop, etc.)
    if fullType:find("broom") or fullType:find("mop")
       or name:find("broom") or name:find("mop")
       or name:find("vassoura") or name:find("esfregao") then
        return true
    end

    -- Arma de duas maos com tag de limpeza
    if item.isTwoHandWeapon and item:isTwoHandWeapon() then
        if ItemTag and item.hasTag and item:hasTag(ItemTag.CLEAN_STAINS) then
            return true
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- 2. Acao com Tempo: Varrer / Esfregar Piso da Base e Remover Sangue
--------------------------------------------------------------------------------
ISCleanFloorAction = ISBaseTimedAction:derive("ISCleanFloorAction")

function ISCleanFloorAction:isValid()
    return self.character and not self.character:isDead()
end

function ISCleanFloorAction:waitToStart()
    if self.targetSquare and self.character then
        self.character:faceLocation(self.targetSquare:getX(), self.targetSquare:getY())
    end
    return (self.character and self.character.shouldBeTurning and self.character:shouldBeTurning()) or false
end

function ISCleanFloorAction:update()
    if self.targetSquare and self.character then
        self.character:faceLocation(self.targetSquare:getX(), self.targetSquare:getY())
    end
end

function ISCleanFloorAction:start()
    local tool = self.toolItem
    if not tool and self.character then
        tool = self.character:getPrimaryHandItem()
    end

    local isTwoHanded = isTwoHandedCleaningTool(tool)

    if isTwoHanded then
        -- Animacao vanilla de varrer/mop em pe!
        self:setActionAnim("ScrubFloor_Mop")
        local primaryItem = (self.character and self.character:getPrimaryHandItem()) or tool
        if self.setOverrideHandModels and primaryItem then
            pcall(function() self:setOverrideHandModels(primaryItem, nil) end)
        end
        pcall(function()
            if self.character and self.character.reportEvent then
                self.character:reportEvent("EventCleanBlood")
            end
        end)
        self.sound = nil
        if self.character and self.character.playSound then
            pcall(function() self.sound = self.character:playSound("CleanBloodScrub") end)
        end
    else
        -- Animacao vanilla de esfregar piso abaixado com pano/esponja
        self:setActionAnim("ScrubFloor")
        local primaryItem = (self.character and self.character:getPrimaryHandItem()) or tool
        if self.setOverrideHandModels and primaryItem then
            pcall(function() self:setOverrideHandModels(primaryItem, self.secondaryCleaner) end)
        end
        self.sound = nil
        if self.character and self.character.playSound then
            pcall(function() self.sound = self.character:playSound("CleanBloodBleach") end)
            if not self.sound then
                pcall(function() self.sound = self.character:playSound("CleanBloodScrub") end)
            end
        end
    end
end

function ISCleanFloorAction:stop()
    if self.sound and self.character then
        pcall(function()
            if self.character.stopOrTriggerSound then
                self.character:stopOrTriggerSound(self.sound)
            elseif self.character.stopSound then
                self.character:stopSound(self.sound)
            end
        end)
    end
    ISBaseTimedAction.stop(self)
end

function ISCleanFloorAction:perform()
    if self.sound and self.character then
        pcall(function()
            if self.character.stopOrTriggerSound then
                self.character:stopOrTriggerSound(self.sound)
            elseif self.character.stopSound then
                self.character:stopSound(self.sound)
            end
        end)
    end

    local centerSq = self.targetSquare or (self.character and self.character:getCurrentSquare())
    if centerSq and centerSq.getCell then
        local cell = centerSq:getCell()
        -- Limpa o tile alvo e arredores imediatos (raio de 1 tile)
        for dx = -1, 1 do
            for dy = -1, 1 do
                local sq = cell:getGridSquare(centerSq:getX() + dx, centerSq:getY() + dy, centerSq:getZ())
                if sq then
                    -- 1. Remove manchas de sangue vanilla e do floor
                    pcall(function()
                        if sq.removeBlood then sq:removeBlood(false, false) end
                        if sq.removeGrime then sq:removeGrime() end
                        local floor = sq.getFloor and sq:getFloor()
                        if floor and floor.removeBlood then floor:removeBlood() end
                    end)

                    -- 2. Remove overlays visuais de sujeira (overlay_grime_floor_*)
                    local objs = sq:getObjects()
                    if objs then
                        for i = objs:size() - 1, 0, -1 do
                            local obj = objs:get(i)
                            if obj then
                                local sName = (obj.getSprite and obj:getSprite() and obj:getSprite():getName())
                                    or (obj.getSpriteName and obj:getSpriteName())
                                    or obj.spriteName
                                if sName and sName:find("overlay_grime_floor") then
                                    sq:RemoveTileObject(obj)
                                    if isClient and isClient() and sq.transmitRemoveItemFromSquare then
                                        pcall(function() sq:transmitRemoveItemFromSquare(obj) end)
                                    end
                                end
                            end
                        end
                    end

                    -- 3. Zera nivel de poeira e sujeira logica do square no modData
                    local sqMd = sq:getModData()
                    if sqMd and sqMd.LV_DirtLevel then
                        sqMd.LV_DirtLevel = 0
                        if sq.transmitModData then pcall(function() sq:transmitModData() end) end
                    end
                end
            end
        end

        -- 4. Zera sujeira acumulada do comodo no sistema do mod
        local locKey = LV_DirtSystem.getCurrentLocationKey(self.character, centerSq)
        if locKey and LV_DirtSystem.setFloorDirt then
            LV_DirtSystem.setFloorDirt(locKey, 0)
        end

        -- 5. Consome agua do balde / desinfetante (Compativel com B42 FluidContainer e itens legados)
        local cleaner = self.secondaryCleaner
        if not cleaner and self.character then
            cleaner = findWaterOrCleaningContainer(self.character)
        end
        if cleaner then
            local waterCost = (LV_Config and LV_Config.getCleanFloorWaterDrain and LV_Config.getCleanFloorWaterDrain()) or 0.25
            local cleanerCost = (LV_Config and LV_Config.getCleanFloorCleanerDrain and LV_Config.getCleanFloorCleanerDrain()) or 0.15
            local fc = cleaner.getFluidContainer and cleaner:getFluidContainer()
            if fc and fc.getAmount and fc:getAmount() > 0 then
                if waterCost > 0 then
                    fc:adjustAmount(math.max(0.0, fc:getAmount() - waterCost))
                    if cleaner.syncItemFields then pcall(cleaner.syncItemFields, cleaner) end
                end
            elseif cleaner.Use then
                if cleanerCost > 0 then
                    pcall(cleaner.Use, cleaner)
                    if cleaner.syncItemFields then pcall(cleaner.syncItemFields, cleaner) end
                end
            elseif cleaner.getUsedDelta and cleaner.setUsedDelta then
                if cleanerCost > 0 then
                    local curD = cleaner:getUsedDelta()
                    local nextD = math.max(0.0, curD - cleanerCost)
                    cleaner:setUsedDelta(nextD)
                    if nextD <= 0.001 then
                        local inv = self.character:getInventory()
                        local cleanerCont = (cleaner.getContainer and cleaner:getContainer()) or inv
                        if cleaner.getReplaceOnDeplete and cleaner:getReplaceOnDeplete() then
                            local repType = cleaner:getReplaceOnDeplete()
                            if cleanerCont and cleanerCont.Remove then
                                cleanerCont:Remove(cleaner)
                            end
                            if inv and inv.AddItem then inv:AddItem(repType) end
                        else
                            if cleanerCont and cleanerCont.Remove then
                                cleanerCont:Remove(cleaner)
                            end
                        end
                    end
                    if cleaner.syncItemFields then pcall(cleaner.syncItemFields, cleaner) end
                end
            end
        end

        -- 6. Desgaste e sujidade da ferramenta / pano de chao
        local tool = self.toolItem
        if not tool and self.character then
            tool = self.character:getPrimaryHandItem() or findCleaningTool(self.character)
        end
        if tool then
            local inv = self.character and self.character:getInventory()
            local fType = tool.getFullType and tool:getFullType() or ""

            if fType == "Base.RippedSheets" then
                local container = tool:getContainer() or inv
                if container and container.Remove then
                    container:Remove(tool)
                    if inv and inv.AddItem then inv:AddItem("Base.RippedSheetsDirty") end
                end
            else
                local clothDirt = (LV_Config and LV_Config.getCleanFloorClothDirtGain and LV_Config.getCleanFloorClothDirtGain()) or 30
                local clothBlood = (LV_Config and LV_Config.getCleanFloorClothBloodGain and LV_Config.getCleanFloorClothBloodGain()) or 25
                local clothWet = (LV_Config and LV_Config.getCleanFloorClothWetnessGain and LV_Config.getCleanFloorClothWetnessGain()) or 60
                local toolWearChance = (LV_Config and LV_Config.getCleanFloorToolWearChance and LV_Config.getCleanFloorToolWearChance()) or 10

                if tool.setDirtyness and clothDirt > 0 then
                    local curDirt = (tool.getDirtiness and tool:getDirtiness()) or 0.0
                    tool:setDirtyness(math.min(100.0, curDirt + clothDirt))
                end
                if tool.setBloodLevel and clothBlood > 0 then
                    local curBlood = (tool.getBloodLevel and tool:getBloodLevel()) or 0.0
                    tool:setBloodLevel(math.min(100.0, curBlood + clothBlood))
                end
                if tool.setWetness and clothWet > 0 then
                    local curWet = (tool.getWetness and tool:getWetness()) or 0.0
                    tool:setWetness(math.min(100.0, curWet + clothWet))
                end
                if tool.getCondition and tool.setCondition and toolWearChance > 0 then
                    if ZombRand(100) < toolWearChance then
                        tool:setCondition(math.max(0, tool:getCondition() - 1))
                    end
                end
                if tool.syncItemFields then pcall(tool.syncItemFields, tool) end
            end
        end

        -- 7. Notifica motor de tarefas domesticas e concede estatisticas
        pcall(function()
            local pMd = self.character:getModData()
            pMd.LV_FloorsCleaned = (pMd.LV_FloorsCleaned or 0) + 1
            if LV_HomemakingActions and LV_HomemakingActions.onChoreCompleted then
                LV_HomemakingActions.onChoreCompleted(self.character, "CleanFloor")
            end
        end)

        -- 8. Feedback visual HaloNote (ASCII limpo)
        pcall(function()
            if self.character.setHaloNote then
                self.character:setHaloNote("Living House: Piso e manchas higienizados com sucesso!", 120, 220, 160, 200)
            end
        end)

        -- 9. Forca recalculado imediato de conforto do comodo
        if LV_ComfortScanner and LV_ComfortScanner.startScan then
            LV_ComfortScanner.startScan(self.character, true)
        end
    end

    ISBaseTimedAction.perform(self)
end

function ISCleanFloorAction:new(character, targetSquare, toolItem, secondaryCleaner, time)
    local o = ISBaseTimedAction.new(self, character)
    o.targetSquare = targetSquare or (character and character:getCurrentSquare())
    o.toolItem = toolItem
    o.secondaryCleaner = secondaryCleaner
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = time or 140
    o.forceProgressBar = true
    return o
end

--------------------------------------------------------------------------------
-- Acao com Tempo: Higiene Bucal / Escovar os Dentes na Pia
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

    -- 1. Consumo configuravel de pasta de dente via Sandbox
    if self.toothpaste then
        local USE_COST = (LV_Config and LV_Config.getToothpasteDrain and LV_Config.getToothpasteDrain()) or 0.10
        local consumed = false

        if USE_COST > 0 then
            -- Se for Drainable / DrainableComboItem
            if self.toothpaste.getUsedDelta and self.toothpaste.setUsedDelta then
                local okD, curDelta = pcall(self.toothpaste.getUsedDelta, self.toothpaste)
                if okD and type(curDelta) == "number" then
                    local step = USE_COST

                    local newDelta = math.max(0.0, curDelta - step)
                    pcall(self.toothpaste.setUsedDelta, self.toothpaste, newDelta)
                    consumed = true

                    -- Sincroniza tambem com ModData para maxima integridade
                    if self.toothpaste.getModData then
                        local okM, md = pcall(self.toothpaste.getModData, self.toothpaste)
                        if okM and md then
                            md.LV_ToothpasteUses = math.floor(newDelta * 20 + 0.5)
                            if self.toothpaste.transmitModData then
                                pcall(self.toothpaste.transmitModData, self.toothpaste)
                            end
                        end
                    end

                    if self.toothpaste.syncItemFields then pcall(self.toothpaste.syncItemFields, self.toothpaste) end

                    if newDelta <= 0.001 then
                        -- Tubo esgotado: remove do inventario
                        if self.character and self.character.setHaloNote then
                            pcall(function() self.character:setHaloNote("Tubo de pasta de dente esgotado!", 240, 180, 80, 260) end)
                        end
                        local inv = self.character:getInventory()
                        if inv and inv.Remove then
                            pcall(inv.Remove, inv, self.toothpaste)
                        end
                    elseif newDelta <= 0.10 then
                        -- Alerta suave de que esta acabando
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
                    local stepUses = math.max(1, math.floor(USE_COST * 20 + 0.5))
                    local newUses = math.max(0, tonumber(curUses) - stepUses)
                    md.LV_ToothpasteUses = newUses
                    if self.toothpaste.transmitModData then
                        pcall(self.toothpaste.transmitModData, self.toothpaste)
                    end
                    if self.toothpaste.setUsedDelta then
                        pcall(self.toothpaste.setUsedDelta, self.toothpaste, newUses / 20.0)
                    end
                    if self.toothpaste.syncItemFields then pcall(self.toothpaste.syncItemFields, self.toothpaste) end

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
    end

    -- 2. Consome 1 unidade de agua da pia se disponivel e acumula sujeira/desgaste na pia
    if self.targetSink then
        if self.targetSink.getFluidAmount and self.targetSink.useFluid then
            pcall(function() self.targetSink:useFluid(1) end)
        elseif self.targetSink.getWaterAmount and self.targetSink.setWaterAmount then
            local curWater = self.targetSink:getWaterAmount()
            if curWater > 0 then
                self.targetSink:setWaterAmount(math.max(0, curWater - 1))
            end
        end

        local sMd = self.targetSink.getModData and self.targetSink:getModData()
        if sMd then
            local prevD = sMd.LV_FixtureDirt or 0
            local dMult = (LV_Config and LV_Config.getApplianceDirtGainMultiplier and LV_Config.getApplianceDirtGainMultiplier()) or 1.0
            local addD = (LV_DirtScoreData.FixtureDirtOnUse.Sink or 5.0) * dMult
            sMd.LV_FixtureDirt = math.min(100.0, prevD + addD)
            if self.targetSink.transmitModData then pcall(function() self.targetSink:transmitModData() end) end
        end
        LV_DirtScoreData.degradeAppliance(self.targetSink, LV_DirtScoreData.ApplianceHealthOnUse.Sink or 0.6)
    end

    -- 3. Integracao com LV_DentalNeed (Zera a necessidade bucal e concede bonus)
    if LV_DentalNeed and LV_DentalNeed.brushTeeth then
        LV_DentalNeed.brushTeeth(self.character)
    else
        -- Fallback de alivio
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

    -- 1. Verifica itens equipados nas maos do personagem
    if character.getPrimaryHandItem then
        local ok, pHand = pcall(character.getPrimaryHandItem, character)
        if ok and pHand then checkItem(pHand) end
    end
    if character.getSecondaryHandItem then
        local ok, sHand = pcall(character.getSecondaryHandItem, character)
        if ok and sHand then checkItem(sHand) end
    end

    -- 2. Busca direta por tipos oficiais vanilla no inventario
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

    -- 3. Varredura recursiva completa em todas as bolsas, slots e containers do inventario
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

    -- Prioriza o tubo que ja esta aberto/em uso com menor quantidade restante > 0
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

        -- 5. Pias de construcao ou encanadas (IsoThumpable com agua encanada)
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

        -- Fallback seguro para periodo pre-corte de agua no mundo
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

isCleaningToolItem = function(item)
    if not item or (item.isBroken and item:isBroken()) then return false end
    local fullType = (item.getFullType and item:getFullType() or item.getType and item:getType() or ""):lower()
    local name = (item.getName and item:getName() or ""):lower()

    if fullType:find("broom") or fullType:find("mop") or fullType:find("dishcloth") or
       fullType:find("bathtowel") or fullType:find("sponge") or fullType:find("rippedsheets") or
       name:find("vassoura") or name:find("esfregao") or name:find("pano") or name:find("toalha") or name:find("esponja") then
        return true
    end

    if ItemTag and item.hasTag then
        local ok, res = pcall(function()
            if ItemTag.CLEAN_STAINS and item:hasTag(ItemTag.CLEAN_STAINS) then return true end
            return false
        end)
        if ok and res then return true end
    end

    if LV_DirtScoreData and LV_DirtScoreData.CleaningCloths then
        local rawType = item.getFullType and item:getFullType() or item:getType()
        if LV_DirtScoreData.CleaningCloths[rawType] then return true end
    end

    return false
end

findCleaningTool = function(player)
    if not player then return nil end
    local inv = player:getInventory()

    -- 1. Se o jogador ja estiver segurando vassoura ou mop nas maos, usa imediatamente!
    local primary = player.getPrimaryHandItem and player:getPrimaryHandItem()
    if primary and isTwoHandedCleaningTool(primary) and not (primary.isBroken and primary:isBroken()) then
        return primary
    end

    if not inv then return nil end

    -- 2. PRIORIDADE MAXIMA PARA VARRER: Procurar Vassouras ou Mops (inventario/costas/mochila)
    local twoHandTypes = { "Base.Broom", "Base.Mop", "Broom", "Mop", "Base.Broom_Twig", "Broom_Twig" }
    for _, t in ipairs(twoHandTypes) do
        if inv.getFirstTypeRecurse then
            local it = inv:getFirstTypeRecurse(t)
            if it and not (it.isBroken and it:isBroken()) then
                return it
            end
        end
    end
    if inv.getFirstTagEvalRecurse and ItemTag and ItemTag.CLEAN_STAINS then
        local it = inv:getFirstTagEvalRecurse(ItemTag.CLEAN_STAINS, function(item)
            return isTwoHandedCleaningTool(item) and not (item.isBroken and item:isBroken())
        end)
        if it then return it end
    end

    -- 3. Se o jogador ja estiver com pano/esponja na mao, usa ele
    if primary and isCleaningToolItem(primary) and not (primary.isBroken and primary:isBroken()) then
        return primary
    end
    local secondary = player.getSecondaryHandItem and player:getSecondaryHandItem()
    if secondary and isCleaningToolItem(secondary) and not (secondary.isBroken and secondary:isBroken()) then
        return secondary
    end

    -- 4. TERCEIRA PRIORIDADE: Panos, toalhas e esponjas no inventario/mochila
    local clothTypes = { "Base.DishCloth", "Base.BathTowel", "Base.BathTowelWet", "Base.Sponge", "Base.RippedSheets", "DishCloth", "BathTowel", "Sponge" }
    for _, t in ipairs(clothTypes) do
        if inv.getFirstTypeRecurse then
            local it = inv:getFirstTypeRecurse(t)
            if it and not (it.isBroken and it:isBroken()) then
                return it
            end
        end
    end

    return nil
end

findWaterOrCleaningContainer = function(player)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    -- Verifica na mao secundaria primeiro
    local sec = player.getSecondaryHandItem and player:getSecondaryHandItem()
    if sec then
        local isWaterOrBleach = false
        if sec.getFluidContainer then
            local fc = sec:getFluidContainer()
            if fc and fc.getAmount and fc:getAmount() > 0 then
                isWaterOrBleach = true
            end
        end
        if not isWaterOrBleach and sec.isWaterSource and sec:isWaterSource() then
            isWaterOrBleach = true
        end
        if isWaterOrBleach then return sec end
    end

    -- Procura no inventario balde de agua ou recipiente com fluido/agua
    local waterTypes = { "Base.BucketWaterFull", "Base.WaterBucket", "Base.Bleach", "Base.CleaningLiquid", "Base.PotWater", "Base.PanWater", "Base.WaterBottleFull" }
    for _, t in ipairs(waterTypes) do
        local it = inv:getFirstTypeRecurse(t)
        if it then return it end
    end

    return nil
end

local function hasEmptyBucket(player)
    if not player then return false end
    local inv = player:getInventory()
    if not inv then return false end
    local it = inv:getFirstTypeRecurse("Base.BucketEmpty") or inv:getFirstTypeRecurse("BucketEmpty")
    return it ~= nil
end

--------------------------------------------------------------------------------
-- 3. Construtor de Menu de Contexto (Botao Direito no Mundo)
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

        -- Identifica ferramenta de limpeza valida (pano, toalha, esponja, vassoura, esfregao)
        local cleaningTool = findCleaningTool(player)
        local hasCleaningCloth = (cleaningTool ~= nil)

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

        local clickedSquare = nil
        for _, obj in ipairs(candidateObjects) do
            if obj and obj.getSquare then
                local okSq, sq = pcall(obj.getSquare, obj)
                if okSq and sq then
                    clickedSquare = sq
                    break
                end
            end
        end
        if not clickedSquare and player then
            clickedSquare = player:getCurrentSquare()
        end

        local clickedFixture = nil
        local fixtureLabel = nil
        local sinkObject = nil

        -- Varre todos os objetos candidatos
        for _, v in ipairs(candidateObjects) do
            if v then
                -- Identificacao infalivel de Pia
                if not sinkObject and isSinkObject(v) then
                    sinkObject = v
                end

                -- Identificacao de pecas sanitarias para faxina
                if not clickedFixture and v.getSprite then
                    local okSp, sprite = pcall(v.getSprite, v)
                    if okSp and sprite and sprite.getName then
                        local okNm, rawName = pcall(sprite.getName, sprite)
                        local sName = (okNm and rawName) and tostring(rawName):lower() or ""

                        if isToiletObject(v) then
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
                        elseif (instanceof and instanceof(v, "IsoStove")) or sName:find("stove") or sName:find("oven") or sName:find("appliances_cooking_") then
                            clickedFixture = v
                            fixtureLabel = "Fogao / Forno"
                        end
                    end
                end
            end
        end

        -- A. OPCAO DE ESCOVAR OS DENTES (Higiene Pessoal)
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
                        ISTimedActionQueue.add(ISBrushTeethAction:new(pObj, sink, brushItem, pasteItem, 160))
                    end
                    context:addOption(string.format("Escovar os Dentes (Pasta: %d%%)", pct), sinkObject, onBrushTeeth, player, brush, paste)
                else
                    local opt = context:addOption("Escovar os Dentes (Sem Agua na Pia)", nil, nil)
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

        -- B. OPCAO DE HIGIENIZACAO DE PECAS SANITARIAS (Se o sistema de sujeira estiver ativo)
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

        -- B2. OPCAO DE MANUTENCAO E REPARO DE APARELHOS
        if clickedFixture then
            local currentHealth = LV_DirtScoreData.getApplianceHealth(clickedFixture)
            if currentHealth < 95.0 then
                local mTool, mToolInfo = findMaintenanceTool(player)
                if mTool then
                    local onMaintain = function(fixture, pObj, tool, toolData, label)
                        local inv = pObj:getInventory()
                        if tool and tool.getContainer and tool:getContainer() ~= inv then
                            ISInventoryPaneContextMenu.transferIfNeeded(pObj, tool)
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
                        ISTimedActionQueue.add(ISMaintainApplianceAction:new(pObj, fixture, tool, toolData, label, 150))
                    end

                    local toolLabel = (mToolInfo and mToolInfo.label) or (mTool.getName and mTool:getName()) or "Ferramenta"
                    context:addOption(string.format("Fazer Manutencao em %s (Condicao: %d%% - %s)", fixtureLabel or "Aparelho", math.floor(currentHealth), toolLabel), clickedFixture, onMaintain, player, mTool, mToolInfo, fixtureLabel or "Aparelho")
                else
                    local opt = context:addOption(string.format("Fazer Manutencao em %s (Condicao: %d%% - Requer Chave/Fita)", fixtureLabel or "Aparelho", math.floor(currentHealth)), nil, nil)
                    opt.notAvailable = true
                end
            end
        end

        -- C. Opcao de Varrer Piso do Comodo e Remover Sangue
        local targetFloorSquare = clickedSquare or (player and player:getCurrentSquare())
        if targetFloorSquare then
            local hasBloodOrStains = false
            pcall(function()
                if targetFloorSquare.haveStains and targetFloorSquare:haveStains() then hasBloodOrStains = true end
                if targetFloorSquare.haveBloodFloor and targetFloorSquare:haveBloodFloor() then hasBloodOrStains = true end
                if targetFloorSquare.haveGrimeFloor and targetFloorSquare:haveGrimeFloor() then hasBloodOrStains = true end
                local fl = targetFloorSquare.getFloor and targetFloorSquare:getFloor()
                if fl and fl.getBlood and fl:getBlood() > 0 then hasBloodOrStains = true end
            end)

            local locKey = LV_DirtSystem.getCurrentLocationKey(player, targetFloorSquare)
            local floorDirt = locKey and LV_DirtSystem.getFloorDirt(locKey) or 0
            local sqMd = targetFloorSquare.getModData and targetFloorSquare:getModData()
            local sqDirt = sqMd and sqMd.LV_DirtLevel or 0
            local isIndoor = not targetFloorSquare:isOutside()

            -- A opcao de limpeza aparece se houver sangue/manchas, sujeira acumulada ou se o jogador estiver em piso interior
            if hasBloodOrStains or floorDirt > 0 or sqDirt > 0 or isIndoor then
                if cleaningTool then
                    local secCleaner = findWaterOrCleaningContainer(player)
                    local isTwoHanded = isTwoHandedCleaningTool(cleaningTool)

                    local onCleanFloor = function(targetSq, pObj, tool, secondary)
                        local inv = pObj:getInventory()
                        if tool and tool.getContainer and tool:getContainer() ~= inv then
                            ISInventoryPaneContextMenu.transferIfNeeded(pObj, tool)
                        end
                        if secondary and secondary.getContainer and secondary:getContainer() ~= inv then
                            ISInventoryPaneContextMenu.transferIfNeeded(pObj, secondary)
                        end

                        local isTwoHanded = isTwoHandedCleaningTool(tool)
                        local pNum = (pObj.getPlayerNum and pObj:getPlayerNum()) or 0

                        if isTwoHanded then
                            ISInventoryPaneContextMenu.equipWeapon(tool, true, true, pNum)
                        else
                            ISInventoryPaneContextMenu.equipWeapon(tool, true, false, pNum)
                            if secondary then
                                ISInventoryPaneContextMenu.equipWeapon(secondary, false, false, pNum)
                            end
                        end

                        if luautils and luautils.walkAdj then
                            luautils.walkAdj(pObj, targetSq, true)
                        else
                            ISTimedActionQueue.add(ISWalkToTimedAction:new(pObj, targetSq))
                        end
                        local cleanDuration = math.floor(100 + (floorDirt * 1.2))
                        if hasBloodOrStains then cleanDuration = cleanDuration + 40 end
                        ISTimedActionQueue.add(ISCleanFloorAction:new(pObj, targetSq, tool, secondary, cleanDuration))
                    end

                    local actionVerb = isTwoHanded and "Varrer" or "Passar Pano no"
                    local label = hasBloodOrStains and string.format("%s Piso e Remover Sangue", actionVerb) or string.format("%s Piso (Sujeira: %d%%)", actionVerb, math.floor(floorDirt))
                    context:addOption(label, targetFloorSquare, onCleanFloor, player, cleaningTool, secCleaner)
                else
                    local msg = "Varrer e Limpar Piso (Necessita: Pano, Esponja, Vassoura ou Esfregao)"
                    if hasEmptyBucket(player) then
                        msg = "Varrer e Limpar Piso (Necessita Pano, Esponja ou Vassoura - Balde esta vazio)"
                    end
                    local opt = context:addOption(msg, nil, nil)
                    opt.notAvailable = true
                end
            end
        end

        -- D. Opcao de Reivindicar Residencia como Meu Lar (Single Player / SP Claim)
        local sq = targetFloorSquare or (player and player:getCurrentSquare())
        if sq and not sq:isOutside() and (not isClient() or not SafeHouse) then
            local building = (sq.getBuilding and sq:getBuilding()) or (sq.getRoom and sq:getRoom() and sq:getRoom().getBuilding and sq:getRoom():getBuilding())
            if building then
                local bId = building.getID and building:getID()
                local bDef = building.getDef and building:getDef()
                local defId = bDef and bDef.getID and bDef:getID()
                local pMd = player.getModData and player:getModData()
                if (bId or defId) and pMd then
                    local isClaimedHere = false
                    if pMd.LV_ClaimedBaseBuildingId and bId and pMd.LV_ClaimedBaseBuildingId == bId then
                        isClaimedHere = true
                    elseif pMd.LV_ClaimedBaseDefId and defId and pMd.LV_ClaimedBaseDefId == defId then
                        isClaimedHere = true
                    end
                    if not isClaimedHere and pMd.LV_ClaimedBounds and sq then
                        local bnds = pMd.LV_ClaimedBounds
                        local sx, sy = sq:getX(), sq:getY()
                        if sx >= bnds.x1 and sx <= bnds.x2 and sy >= bnds.y1 and sy <= bnds.y2 then
                            isClaimedHere = true
                        end
                    end

                    if isClaimedHere then
                        local onUnclaimHome = function(pObj)
                            local md = pObj:getModData()
                            md.LV_ClaimedBaseBuildingId = nil
                            md.LV_ClaimedBaseDefId = nil
                            md.LV_ClaimedBounds = nil
                            if pObj.setHaloNote then
                                pcall(function() pObj:setHaloNote("Residencia desocupada. Voce nao possui mais uma base oficial.", 220, 180, 80, 260) end)
                            end
                            if LV_ComfortScanner and LV_ComfortScanner.startScan then
                                LV_ComfortScanner.startScan(pObj, true)
                            end
                            if LV_HouseDashboard and LV_HouseDashboard.getInstance then
                                pcall(function() LV_HouseDashboard.getInstance():refreshData(true) end)
                            end
                            if LV_ApplianceDashboard and LV_ApplianceDashboard.getInstance then
                                pcall(function() LV_ApplianceDashboard.getInstance():refreshData(true) end)
                            end
                        end
                        context:addOption("Living House: Desocupar Base / Abandonar Lar", player, onUnclaimHome)
                    else
                        local onClaimHome = function(pObj)
                            local md = pObj:getModData()
                            md.LV_ClaimedBaseBuildingId = bId
                            md.LV_ClaimedBaseDefId = defId
                            if bDef and bDef.getX and bDef.getY and bDef.getX2 and bDef.getY2 then
                                md.LV_ClaimedBounds = { x1 = bDef:getX(), y1 = bDef:getY(), x2 = bDef:getX2(), y2 = bDef:getY2() }
                            end
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
                            if LV_ApplianceDashboard and LV_ApplianceDashboard.getInstance then
                                pcall(function() LV_ApplianceDashboard.getInstance():refreshData(true) end)
                            end
                        end
                        context:addOption("Living House: Estabelecer Residencia como Meu Lar", player, onClaimHome)
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
-- HOOK: Renderizacao da Barra "Restante:" (Remaining) no Painel de Inventario e Tooltip
-- Garante que a barra verde com a durabilidade seja exibida tanto no ISInventoryPane
-- quanto no ISToolTipInv, mesmo para itens ja existentes em saves previos.
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
                -- Se nao for Drainable nativo no Java, o DoTooltip nao desenha a barra.
                -- Desenhamos a barra de Restante no rodape do tooltip:
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


