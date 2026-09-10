-- =============================================================================
-- Housing Care System (Lar Vivo) - Lighting & Bulb Maintenance (LV_LightingSystem.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Mecanica inedita de desgaste e queima de lampadas residenciais (teto/parede).
--   No Project Zomboid vanilla, lampadas embutidas de arquitetura nunca queimam.
--   Este modulo introduz ciclo de vida para iluminacao residencial:
--   - Lampadas acesas na Safehouse acumulam horas de uso e podem queimar (burn out).
--   - Quando queima, a luz apaga, emite som de estalo ("pop") e penaliza o conforto.
--   - Exige que o sobrevivente substitua por uma 'Base.LightBulb' nova via menu de contexto.
--   100% compativel com SP e Servidores Multiplayer.
-- =============================================================================

require "LV_Config"

LV_LightingSystem = LV_LightingSystem or {}

--- Identifica se um item do inventario e uma lampada valida (LightBulb)
function LV_LightingSystem.isLightBulbItem(item)
    if not item then return false end
    local ftype = tostring(item:getFullType() or ""):lower()
    if ftype:find("lightbulb") or ftype:find("light_bulb") or ftype == "base.lightbulb" then
        return true
    end
    local name = tostring(item:getName() or ""):lower()
    if name:find("light bulb") or name:find("lampada") or name:find("bombilla") then
        return true
    end
    return false
end

--- Identifica se um objeto de cenario e um interruptor ou luminaria residencial
function LV_LightingSystem.isLightSwitch(obj)
    if not obj then return false end
    if instanceof and instanceof(obj, "IsoLightSwitch") then
        return true
    end
    local sprite = obj.getSprite and obj:getSprite()
    local sName = (sprite and sprite.getName and sprite:getName()) or (obj.getSpriteName and obj:getSpriteName()) or ""
    sName = tostring(sName):lower()
    if sName:find("lighting_") or sName:find("lightswitch") or sName:find("fixtures_lighting") or sName:find("wall_lighting") then
        return true
    end
    return false
end

--- Verifica se a lampada do objeto esta queimada
function LV_LightingSystem.isBulbBurnt(obj)
    if not obj then return false end
    local md = obj.getModData and obj:getModData()
    return (md and md.LV_LightBulbBurnt == true) or false
end

--- Define o estado de queima da lampada do objeto
function LV_LightingSystem.setBulbBurnt(obj, isBurnt)
    if not obj then return end
    local md = obj.getModData and obj:getModData()
    if md then
        md.LV_LightBulbBurnt = isBurnt and true or nil
    end
    if obj.transmitModData then
        pcall(function() obj:transmitModData() end)
    end
end

--- Desliga forcadamente o interruptor e apaga a luz
function LV_LightingSystem.turnOffSwitch(obj)
    if not obj then return end
    pcall(function()
        if obj.setActive then
            obj:setActive(false)
        elseif obj.setActivated then
            obj:setActivated(false)
        end
        if obj.syncIsoObject then
            obj:syncIsoObject(false, 0, nil, nil)
        end
    end)
end

--- Liga o interruptor apos troca de lampada
function LV_LightingSystem.turnOnSwitch(obj)
    if not obj then return end
    pcall(function()
        if obj.setActive then
            obj:setActive(true)
        elseif obj.setActivated then
            obj:setActivated(true)
        end
        if obj.syncIsoObject then
            obj:syncIsoObject(true, 1, nil, nil)
        end
    end)
end

-- =============================================================================
-- TIMED ACTION: Substituicao da Lampada Queimada
-- =============================================================================

require "TimedActions/ISBaseTimedAction"

ISReplaceLightBulbAction = ISBaseTimedAction:derive("ISReplaceLightBulbAction")

function ISReplaceLightBulbAction:isValid()
    if not self.character or not self.lightObj then return false end
    local inv = self.character:getInventory()
    if not inv then return false end
    local hasBulb = false
    local items = inv:getItems()
    if items then
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if LV_LightingSystem.isLightBulbItem(it) then
                hasBulb = true
                break
            end
        end
    end
    return hasBulb
end

function ISReplaceLightBulbAction:waitToStart()
    self.character:faceThisObject(self.lightObj)
    return self.character:shouldBeTurning()
end

function ISReplaceLightBulbAction:update()
    self.character:faceThisObject(self.lightObj)
end

function ISReplaceLightBulbAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "High")
    local sq = self.lightObj:getSquare()
    if sq and getSoundManager then
        pcall(function()
            getSoundManager():PlayWorldSound("LightSwitch", sq, 0.3, 5, 1.0, false)
        end)
    end
end

function ISReplaceLightBulbAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISReplaceLightBulbAction:perform()
    local inv = self.character:getInventory()
    if inv then
        local bulbItem = nil
        local items = inv:getItems()
        if items then
            for i = 0, items:size() - 1 do
                local it = items:get(i)
                if LV_LightingSystem.isLightBulbItem(it) then
                    bulbItem = it
                    break
                end
            end
        end
        if bulbItem then
            inv:Remove(bulbItem)
        end
    end

    -- Limpa o estado de queimada e reativa a luz
    LV_LightingSystem.setBulbBurnt(self.lightObj, false)
    LV_LightingSystem.turnOnSwitch(self.lightObj)

    -- Feedback sonoro e visual
    local sq = self.lightObj:getSquare()
    if sq and getSoundManager then
        pcall(function()
            getSoundManager():PlayWorldSound("LightSwitch", sq, 0.5, 6, 1.0, false)
        end)
    end

    if self.character.setHaloNote then
        pcall(function()
            local note = (getText and getText("UI_LV_Halo_BulbReplaced")) or "Living House: Lampada substituida com sucesso!"
            if note == "UI_LV_Halo_BulbReplaced" then note = "Living House: Lampada substituida com sucesso!" end
            self.character:setHaloNote(note, 100, 240, 140, 200)
        end)
    end

    -- Bonus de tarefas domesticas no lar
    if LV_HomemakingActions and LV_HomemakingActions.onChoreCompleted then
        LV_HomemakingActions.onChoreCompleted(self.character, "Cleaning", 15)
    end

    -- Forca recalculado de conforto do comodo
    if LV_ComfortScanner and LV_ComfortScanner.startScan then
        LV_ComfortScanner.startScan(self.character, true)
    end

    ISBaseTimedAction.perform(self)
end

function ISReplaceLightBulbAction:new(character, lightObj, time)
    local o = ISBaseTimedAction.new(self, character)
    o.lightObj = lightObj
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.maxTime = time or 80
    return o
end

-- =============================================================================
-- CICLO HORARIO: Processamento de Desgaste e Queima de Lampadas
-- =============================================================================

--- Checa periodicamente lampadas ativas em safehouses reivindicadas
function LV_LightingSystem.onHourBurnoutCheck()
    if not LV_Config or not LV_Config.isLightBulbBurnoutEnabled or not LV_Config.isLightBulbBurnoutEnabled() then
        return
    end

    local player = getPlayer and getPlayer()
    if not player or player:isDead() then return end

    local sq = player:getCurrentSquare()
    if not sq then return end

    -- Apenas em safehouses/residencias habitadas
    local own = LV_ComfortScanner and LV_ComfortScanner.getBuildingOwnershipStatus and LV_ComfortScanner.getBuildingOwnershipStatus(sq, player)
    if not own or own.isOutside or not own.isClaimed then return end

    local building = (sq.getBuilding and sq:getBuilding()) or (sq.getRoom and sq:getRoom() and sq:getRoom().getBuilding and sq:getRoom():getBuilding())
    if not building then return end

    local burnoutChance = (LV_Config and LV_Config.getLightBulbBurnoutChance and LV_Config.getLightBulbBurnoutChance()) or 1.5
    local bDef = building.getDef and building:getDef()
    if not bDef then return end

    local cell = sq:getCell()
    if not cell then return end

    local minX = bDef:getX()
    local minY = bDef:getY()
    local maxX = minX + bDef:getW()
    local maxY = minY + bDef:getH()

    -- Amostragem segura de tiles do edificio
    for x = minX, maxX do
        for y = minY, maxY do
            local tSq = cell:getGridSquare(x, y, sq:getZ())
            if tSq and tSq.getObjects then
                local objs = tSq:getObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if obj and LV_LightingSystem.isLightSwitch(obj) then
                        local isLightActive = false
                        if obj.isActivated and obj:isActivated() then
                            isLightActive = true
                        end

                        if isLightActive and not LV_LightingSystem.isBulbBurnt(obj) then
                            -- Sorteio de queima com base na chance configurada (ex: 1.5% = 15 em 1000)
                            local roll = ZombRand(1000)
                            if roll < math.floor(burnoutChance * 10) then
                                -- Lampada queima!
                                LV_LightingSystem.setBulbBurnt(obj, true)
                                LV_LightingSystem.turnOffSwitch(obj)

                                -- Som caracteristico de queima eletrica
                                if getSoundManager then
                                    pcall(function()
                                        getSoundManager():PlayWorldSound("LightBulbPop", tSq, 0.7, 12, 1.0, false)
                                    end)
                                end

                                -- Notificacao sutil se o jogador estiver proximo (ate 14 tiles)
                                local dx = math.abs(player:getX() - x)
                                local dy = math.abs(player:getY() - y)
                                if dx <= 14 and dy <= 14 and player.setHaloNote then
                                    pcall(function()
                                        local note = (getText and getText("UI_LV_Halo_BulbBurnt")) or "Living House: Uma lampada de teto queimou!"
                                        if note == "UI_LV_Halo_BulbBurnt" then note = "Living House: Uma lampada de teto queimou!" end
                                        player:setHaloNote(note, 240, 180, 60, 250)
                                    end)
                                end

                                print(string.format("[LarVivo] Lampada queimou na posicao (%d, %d, %d). Exige substituicao.", x, y, sq:getZ()))
                            end
                        end
                    end
                end
            end
        end
    end
end

Events.EveryHours.Add(LV_LightingSystem.onHourBurnoutCheck)

-- =============================================================================
-- MENU DE CONTEXTO: Interacao com Interruptores e Lampadas
-- =============================================================================

function LV_LightingSystem.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test or not context or not worldobjects then return end

    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end

    local clickedLight = nil
    for _, obj in ipairs(worldobjects) do
        if obj and LV_LightingSystem.isLightSwitch(obj) then
            clickedLight = obj
            break
        end
    end

    if not clickedLight then return end

    local isBurnt = LV_LightingSystem.isBulbBurnt(clickedLight)
    if isBurnt then
        local inv = player:getInventory()
        local hasBulb = false
        if inv then
            local items = inv:getItems()
            if items then
                for i = 0, items:size() - 1 do
                    local it = items:get(i)
                    if LV_LightingSystem.isLightBulbItem(it) then
                        hasBulb = true
                        break
                    end
                end
            end
        end

        local onReplaceAction = function(pObj, lightObj)
            if luautils and luautils.walkAdjObject then
                luautils.walkAdjObject(pObj, lightObj, true, true)
            elseif luautils and luautils.walkAdj then
                luautils.walkAdj(pObj, lightObj:getSquare(), true)
            end
            ISTimedActionQueue.add(ISReplaceLightBulbAction:new(pObj, lightObj, 80))
        end

        local optText = (getText and getText("UI_LV_ReplaceBurntBulb")) or "Substituir Lampada Queimada"
        if optText == "UI_LV_ReplaceBurntBulb" then optText = "Substituir Lampada Queimada" end
        local opt = context:addOption(optText, player, onReplaceAction, clickedLight)
        if not hasBulb then
            opt.notAvailable = true
            local tooltip = ISToolTip:new()
            tooltip:initialise()
            tooltip:setVisible(false)
            local tipText = (getText and getText("UI_LV_ReplaceBurntBulb_Tooltip")) or "Requer uma Lampada nova (LightBulb) no inventario."
            if tipText == "UI_LV_ReplaceBurntBulb_Tooltip" then tipText = "Requer uma Lampada nova (LightBulb) no inventario." end
            tooltip.description = tipText
            opt.toolTip = tooltip
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(LV_LightingSystem.onFillWorldObjectContextMenu)

print("[LarVivo] LV_LightingSystem carregado com sucesso (Desgaste e Queima de Lampadas Ativo).")

return LV_LightingSystem
