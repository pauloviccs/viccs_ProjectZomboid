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
        self.character:faceThisObject(self.targetObject)
    end
    return (self.character and self.character.shouldBeTurning and self.character:shouldBeTurning()) or false
end

function ISCleanFixtureAction:update()
    self.character:faceThisObject(self.targetObject)
end

function ISCleanFixtureAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")

    -- Auto-Equip inteligente: localiza pano/esponja e equipa na mão secundária
    self.originalSecondary = self.character:getSecondaryHandItem()
    self.equippedTool = nil

    local inv = self.character:getInventory()
    local tool = nil

    -- Procura no inventário principal
    for itemType, _ in pairs(LV_DirtScoreData.CleaningCloths) do
        tool = inv:getFirstTypeRecurse(itemType)
        if tool then break end
    end

    if tool then
        self.equippedTool = tool
        if self.character:getSecondaryHandItem() ~= tool then
            self.character:setSecondaryHandItem(tool)
        end
    end
end

function ISCleanFixtureAction:stop()
    if self.originalSecondary and self.character:getSecondaryHandItem() == self.equippedTool then
        self.character:setSecondaryHandItem(self.originalSecondary)
    end
    ISBaseTimedAction.stop(self)
end

function ISCleanFixtureAction:perform()
    -- Restaura item original da mão
    if self.originalSecondary and self.character:getSecondaryHandItem() == self.equippedTool then
        self.character:setSecondaryHandItem(self.originalSecondary)
    end

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
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.targetObject = targetObject
    o.fixtureLabel = fixtureLabel or "Peca Sanitaria"
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or 120
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
end

function ISCleanFloorAction:perform()
    local sq = self.character:getCurrentSquare()
    if sq then
        local locKey = LV_DirtSystem.getCurrentLocationKey(self.character, sq)
        if locKey ~= "outside" then
            LV_DirtSystem.cleanFloorDirt(locKey, 50.0)
            print(string.format("[LivingHouse] Faxina de piso realizada na localizacao '%s'.", locKey))
        end

        -- Limpa fisicamente sangue vanilla e overlays de sujeira ao redor (raio de 2 tiles)
        local cell = sq.getCell and sq:getCell()
        if cell then
            local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
            for x = px - 2, px + 2 do
                for y = py - 2, py + 2 do
                    local curSq = cell:getGridSquare(x, y, pz)
                    if curSq and not curSq:isOutside() then
                        pcall(function() curSq:removeBlood(false, false) end)
                        pcall(function() curSq:removeGrime() end)

                        local objs = curSq:getObjects()
                        if objs then
                            for i = objs:size() - 1, 0, -1 do
                                local obj = objs:get(i)
                                local sp = obj and obj:getSprite() and obj:getSprite():getName()
                                if sp and sp:find("overlay_grime_floor") then
                                    pcall(function() curSq:RemoveTileObject(obj) end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Concede bônus do Homemaking Engine
    if LV_HomemakingActions and LV_HomemakingActions.grantActionBonus then
        LV_HomemakingActions.grantActionBonus(self.character, "Faxina do Piso", 1.5)
    end

    pcall(function()
        if self.character.setHaloNote then
            self.character:setHaloNote("Piso varrido e higienizado!", 120, 240, 160, 220)
        end
    end)

    LV_ComfortScanner.startScan(self.character, true)
    ISBaseTimedAction.perform(self)
end

function ISCleanFloorAction:new(character, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or 140
    return o
end

--------------------------------------------------------------------------------
-- 3. Construtor de Menu de Contexto (Botão Direito no Mundo)
--------------------------------------------------------------------------------
function LV_ChoreActions.onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test or not LV_Config.isDirtSystemEnabled() then return end
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local inv = player:getInventory()

    -- Verifica se possui ferramenta de limpeza (pano, toalha, esponja, vassoura, esfregão)
    local hasCleaningCloth = false
    for itemType, _ in pairs(LV_DirtScoreData.CleaningCloths) do
        if inv:getFirstTypeRecurse(itemType) then
            hasCleaningCloth = true
            break
        end
    end

    local clickedFixture = nil
    local fixtureLabel = nil

    for _, v in ipairs(worldObjects) do
        if v and v.getSprite and v:getSprite() then
            local sprite = v:getSprite()
            local sName = sprite:getName() and tostring(sprite:getName()):lower() or ""

            -- Verifica se é Toilet
            if (instanceof and instanceof(v, "IsoToilet")) or sName:find("toilet") or sName:find("fixtures_bathroom_01_0") or sName:find("fixtures_bathroom_01_1") or sName:find("fixtures_bathroom_01_2") or sName:find("fixtures_bathroom_01_3") then
                clickedFixture = v
                fixtureLabel = "Vaso Sanitario"
                break
            -- Pia
            elseif sName:find("sink") or sName:find("fixtures_sinks_") or sName:find("fixtures_bathroom_01_16") or sName:find("fixtures_bathroom_01_17") or sName:find("fixtures_bathroom_01_18") or sName:find("fixtures_bathroom_01_19") then
                clickedFixture = v
                fixtureLabel = "Pia"
                break
            -- Banheira
            elseif sName:find("bath") or sName:find("fixtures_bathroom_01_24") or sName:find("fixtures_bathroom_01_25") or sName:find("fixtures_bathroom_01_26") or sName:find("fixtures_bathroom_01_27") then
                clickedFixture = v
                fixtureLabel = "Banheira"
                break
            -- Chuveiro
            elseif sName:find("shower") or sName:find("fixtures_bathroom_01_32") or sName:find("fixtures_bathroom_01_33") then
                clickedFixture = v
                fixtureLabel = "Chuveiro"
                break
            end
        end
    end

    -- Se clicou em uma fixture
    if clickedFixture then
        local fixMd = clickedFixture:getModData()
        local dirt = fixMd.LV_FixtureDirt or 0

        -- Só exibe opção de faxina se estiver de fato suja (> 0)
        if dirt > 0 then
            if hasCleaningCloth then
                local opt = context:addOption(string.format("Higienizar %s (Sujeira: %d%%)", fixtureLabel, math.floor(dirt)), clickedFixture, function()
                    if luautils and luautils.walkAdj then
                        luautils.walkAdj(player, clickedFixture:getSquare())
                    else
                        ISTimedActionQueue.add(ISWalkToTimedAction:new(player, clickedFixture:getSquare()))
                    end
                    ISTimedActionQueue.add(ISCleanFixtureAction:new(player, clickedFixture, fixtureLabel, 120))
                end)
            else
                local opt = context:addOption(string.format("Higienizar %s (Necessita Pano/Esponja)", fixtureLabel), nil, nil)
                opt.notAvailable = true
            end
        end
    end

    -- Opção de Varrer Piso do Cômodo (se houver sujeira acumulada)
    local sq = player:getCurrentSquare()
    if sq and not sq:isOutside() then
        local locKey = LV_DirtSystem.getCurrentLocationKey(player, sq)
        local floorDirt = LV_DirtSystem.getFloorDirt(locKey)
        if floorDirt >= 10.0 then
            if hasCleaningCloth then
                context:addOption(string.format("Varrer e Limpar Piso (Sujeira: %d%%)", math.floor(floorDirt)), player, function()
                    ISTimedActionQueue.add(ISCleanFloorAction:new(player, 140))
                end)
            else
                local opt = context:addOption("Varrer e Limpar Piso (Necessita Pano/Vassoura)", nil, nil)
                opt.notAvailable = true
            end
        end
    end
end
