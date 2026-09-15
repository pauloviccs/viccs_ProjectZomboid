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

local function getSafeText(key, fallback)
    if LV_SkillCheckUI and LV_SkillCheckUI.getText then
        return LV_SkillCheckUI.getText(key, fallback)
    end
    if getTextOrNull then
        local val = getTextOrNull(key)
        if val and val ~= key and val ~= "" and not string.find(val, "^UI_") then
            return val
        end
    end
    if getText then
        local val = getText(key)
        if val and val ~= key and val ~= "" and not string.find(val, "^UI_") then
            return val
        end
    end
    return fallback or key
end

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
        if isBurnt then
            local curBulb = (obj.getBulbItem and obj:getBulbItem())
            if curBulb and curBulb ~= "" then
                md.LV_OriginalBulbItem = curBulb
            end
            md.LV_LightBulbBurnt = true
        else
            md.LV_LightBulbBurnt = nil
        end
    end
    if isBurnt then
        LV_LightingSystem.turnOffSwitch(obj)
    end
    if obj.transmitModData then
        pcall(function() obj:transmitModData() end)
    end
end

--- Desliga forcadamente o interruptor e apaga completamente a luz em todos os niveis da engine PZ
function LV_LightingSystem.turnOffSwitch(obj)
    if not obj then return end
    pcall(function()
        -- 1. Zera bulbItem no Java IsoLightSwitch (garante que hasLightBulb() e canSwitchLight() retornem false)
        if obj.setBulbItemRaw then
            obj:setBulbItemRaw(nil)
        end

        -- 2. Desativa flag e interruptores fisicos
        if obj.setActive then
            obj:setActive(false, false, true)
            obj:setActive(false)
        elseif obj.setActivated then
            obj:setActivated(false)
        end

        -- 3. Desliga a iluminacao do comodo (RoomDef.lightsActive = false)
        if obj.switchLight then
            obj:switchLight(false)
        end

        -- 4. Remove lampposts de luz ativos associados a esta luminaria
        local lights = obj.getLights and obj:getLights()
        if lights then
            for i = 0, lights:size() - 1 do
                local ls = lights:get(i)
                if ls then
                    ls:setActive(false)
                    local cell = getCell() or (IsoWorld and IsoWorld.instance and IsoWorld.instance.currentCell)
                    if cell and cell.removeLamppost then
                        pcall(function() cell:removeLamppost(ls) end)
                    end
                end
            end
        end

        -- 5. Forca a engine Java do PZ a invalidar o mapa de luz global (GPU / LightMap)
        if LightingJNI and LightingJNI.doInvalidateGlobalLights and IsoPlayer and IsoPlayer.getPlayerIndex then
            pcall(function() LightingJNI.doInvalidateGlobalLights(IsoPlayer.getPlayerIndex()) end)
        end

        -- 6. Sincroniza em rede / multiplayer
        if obj.syncIsoObject then
            obj:syncIsoObject(false, 0, nil, nil)
        end
    end)
end

--- Liga o interruptor apos troca de lampada e restaura iluminacao
function LV_LightingSystem.turnOnSwitch(obj, newBulbType)
    if not obj then return end
    pcall(function()
        local md = obj.getModData and obj:getModData()
        local bType = newBulbType or (md and md.LV_OriginalBulbItem) or "Base.LightBulb"

        -- 1. Restaura bulbItem no Java IsoLightSwitch
        if obj.setBulbItemRaw then
            obj:setBulbItemRaw(bType)
        end

        -- 2. Ativa o switch
        if obj.setActive then
            obj:setActive(true, false, true)
            obj:setActive(true)
        elseif obj.setActivated then
            obj:setActivated(true)
        end

        -- 3. Liga a iluminacao do comodo
        if obj.switchLight then
            obj:switchLight(true)
        end

        -- 4. Recria as fontes de luz
        if obj.createLights then
            pcall(function() obj:createLights(true) end)
        end
        if obj.addLightSourceFromSprite then
            pcall(function() obj:addLightSourceFromSprite() end)
        end

        -- 5. Reativa lampposts
        local lights = obj.getLights and obj:getLights()
        if lights then
            for i = 0, lights:size() - 1 do
                local ls = lights:get(i)
                if ls then
                    ls:setActive(true)
                    local cell = getCell() or (IsoWorld and IsoWorld.instance and IsoWorld.instance.currentCell)
                    if cell and cell.addLamppost then
                        pcall(function() cell:addLamppost(ls) end)
                    end
                end
            end
        end

        -- 6. Invalida mapa de luz global para iluminar a sala imediatamente
        if LightingJNI and LightingJNI.doInvalidateGlobalLights and IsoPlayer and IsoPlayer.getPlayerIndex then
            pcall(function() LightingJNI.doInvalidateGlobalLights(IsoPlayer.getPlayerIndex()) end)
        end

        -- 7. Sincroniza em rede
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

    -- Se o teste falhou, aborta imediatamente
    if self.skillCheckFailed then
        self:forceStop()
        return
    end

    -- Acionamento do minigame DBD de Skill Check (se habilitado)
    if not self.skillCheckTriggered and self:getJobDelta() >= 0.25 then
        self.skillCheckTriggered = true
        local isEnabled = (LV_Config and LV_Config.isSkillCheckMinigameEnabled and LV_Config.isSkillCheckMinigameEnabled())
        if isEnabled and (isClient() or not isServer()) and LV_SkillCheckUI and LV_SkillCheckUI.trigger then
            if self.character and (not self.character.isLocalPlayer or self.character:isLocalPlayer()) then
                self.skillCheckPending = true
                local pType = (Perks and Perks.Electricity) or nil
                local pLabel = getSafeText("UI_LV_SkillCheck_Electricity", "TESTE ELETRICO")
                LV_SkillCheckUI.trigger(self.character, self, pType, pLabel,
                    function(isCrit)
                        self.skillCheckPending = false
                        self.skillCheckSuccess = true
                        self.isCritical = isCrit
                        if isCrit and self.setCurrentTime and self.maxTime then
                            self:setCurrentTime(self.maxTime * 0.90)
                        end
                    end,
                    function()
                        self.skillCheckPending = false
                        self.skillCheckFailed = true
                        self.skillCheckSuccess = false
                        self:forceStop()
                    end
                )
            else
                self.skillCheckSuccess = true
            end
        else
            self.skillCheckSuccess = true
        end
    end

    -- TRAVA DE SEGURANCA: Enquanto o minigame estiver em andamento, congela a barra nos 30%
    if self.skillCheckPending then
        if self:getJobDelta() >= 0.30 then
            self:setCurrentTime(self.maxTime * 0.30)
        end
    end
end

function ISReplaceLightBulbAction:start()
    self.skillCheckTriggered = false
    self.skillCheckPending = false
    self.skillCheckSuccess = false
    self.skillCheckFailed = false
    self.isCritical = false
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
    self.skillCheckPending = false
    self.skillCheckFailed = true
    ISBaseTimedAction.stop(self)
end

function ISReplaceLightBulbAction:perform()
    -- TRAVA DE FERRO: Se o teste falhou ou se o teste ativo nao foi concluido com sucesso, aborta sem trocar nada!
    if self.skillCheckFailed or (self.skillCheckTriggered and not self.skillCheckSuccess) then
        return
    end

    local inv = self.character:getInventory()
    local bulbItem = nil
    local bulbFullType = "Base.LightBulb"

    if inv then
        -- 1. Prioriza o bulbo especifico selecionado pelo jogador no painel
        if self.targetBulbItem and inv:contains(self.targetBulbItem) then
            bulbItem = self.targetBulbItem
            bulbFullType = (bulbItem.getFullType and bulbItem:getFullType()) or "Base.LightBulb"
        else
            -- 2. Fallback: primeira lampada valida no inventario
            local items = inv:getItems()
            if items then
                for i = 0, items:size() - 1 do
                    local it = items:get(i)
                    if LV_LightingSystem.isLightBulbItem(it) then
                        bulbItem = it
                        bulbFullType = (it.getFullType and it:getFullType()) or "Base.LightBulb"
                        break
                    end
                end
            end
        end

        if bulbItem then
            inv:Remove(bulbItem)
        else
            return
        end
    end

    -- Limpa o estado de queimada e reativa a luz com o bulbo correto
    LV_LightingSystem.setBulbBurnt(self.lightObj, false)
    LV_LightingSystem.turnOnSwitch(self.lightObj, bulbFullType)

    -- Feedback sonoro e visual
    local sq = self.lightObj:getSquare()
    if sq and getSoundManager then
        pcall(function()
            getSoundManager():PlayWorldSound("LightSwitch", sq, 0.5, 6, 1.0, false)
        end)
    end

    if self.character.setHaloNote then
        pcall(function()
            local note = getSafeText("UI_LV_Halo_BulbReplaced", "Living House: Lampada substituida com sucesso!")
            self.character:setHaloNote(note, 100, 240, 140, 200)
        end)
    end

    -- Recompensa de XP e multiplicador temporario de eletrica
    if (isClient() or not isServer()) and LV_SkillCheckUI and LV_SkillCheckUI.grantXpAndBoost then
        local pType = (Perks and Perks.Electricity) or nil
        if pType then
            local buffName = getSafeText("UI_LV_SkillCheck_BuffElectricity", "Mente Conectada (+50% XP Eletrica)")
            LV_SkillCheckUI.grantXpAndBoost(self.character, pType, 20, self.isCritical, 2.0, 1.5, buffName)
        end
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

function ISReplaceLightBulbAction:new(character, lightObj, targetBulbItemOrTime, time)
    local o = ISBaseTimedAction.new(self, character)
    o.lightObj = lightObj

    if type(targetBulbItemOrTime) == "number" then
        o.targetBulbItem = nil
        o.maxTime = targetBulbItemOrTime
    else
        o.targetBulbItem = targetBulbItemOrTime
        o.maxTime = time
    end

    o.skillCheckTriggered = false
    o.skillCheckPending = false
    o.skillCheckSuccess = false
    o.skillCheckFailed = false
    o.isCritical = false
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true

    local inv = character and character:getInventory()
    local hasSd = inv and (inv:getFirstTypeRecurse("Base.Screwdriver") or inv:getFirstTypeRecurse("Screwdriver"))
    o.maxTime = o.maxTime or (hasSd and 130 or 170)
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
                                        local note = getSafeText("UI_LV_Halo_BulbBurnt", "Living House: Uma lampada de teto queimou!")
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
            ISTimedActionQueue.add(ISReplaceLightBulbAction:new(pObj, lightObj, nil, nil))
        end

        local optText = getSafeText("UI_LV_ReplaceBurntBulb", "Substituir Lampada Queimada")
        local opt = context:addOption(optText, player, onReplaceAction, clickedLight)
        if not hasBulb then
            opt.notAvailable = true
            local tooltip = ISToolTip:new()
            tooltip:initialise()
            tooltip:setVisible(false)
            local tipText = getSafeText("UI_LV_ReplaceBurntBulb_Tooltip", "Requer uma Lampada nova (LightBulb) no inventario.")
            tooltip.description = tipText
            opt.toolTip = tooltip
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(LV_LightingSystem.onFillWorldObjectContextMenu)

-- =============================================================================
-- ENFORCEMENT & HOOKS: Garantia de Apagamento Real e Interceptacao de Cliques
-- =============================================================================

--- Varre periodicamente para garantir que nenhuma lampada queimada no edificio fique acesa
function LV_LightingSystem.enforceBurntBulbsDarkness()
    local player = getPlayer and getPlayer()
    if not player or player:isDead() then return end
    local sq = player:getCurrentSquare()
    if not sq then return end
    local building = (sq.getBuilding and sq:getBuilding()) or (sq.getRoom and sq:getRoom() and sq:getRoom().getBuilding and sq:getRoom():getBuilding())
    if not building then return end
    local bDef = building.getDef and building:getDef()
    if not bDef then return end
    local cell = sq:getCell()
    if not cell then return end

    local minX = bDef:getX()
    local minY = bDef:getY()
    local maxX = minX + bDef:getW()
    local maxY = minY + bDef:getH()

    for x = minX, maxX do
        for y = minY, maxY do
            local tSq = cell:getGridSquare(x, y, sq:getZ())
            if tSq and tSq.getObjects then
                local objs = tSq:getObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if obj and LV_LightingSystem.isLightSwitch(obj) then
                        if LV_LightingSystem.isBulbBurnt(obj) then
                            local isLit = (obj.isActivated and obj:isActivated()) or (obj.hasLightBulb and obj:hasLightBulb())
                            if isLit then
                                LV_LightingSystem.turnOffSwitch(obj)
                            end
                        end
                    end
                end
            end
        end
    end
end

Events.EveryOneMinute.Add(LV_LightingSystem.enforceBurntBulbsDarkness)

-- Hook em ISToggleLightAction para impedir que o jogador acenda uma lampada queimada
require "TimedActions/ISToggleLightAction"
if ISToggleLightAction and not ISToggleLightAction._LV_Hooked then
    ISToggleLightAction._LV_Hooked = true
    local original_complete = ISToggleLightAction.complete
    function ISToggleLightAction:complete()
        if self.object and LV_LightingSystem and LV_LightingSystem.isBulbBurnt and LV_LightingSystem.isBulbBurnt(self.object) then
            LV_LightingSystem.turnOffSwitch(self.object)
            if self.character and self.character.setHaloNote then
                pcall(function()
                    local note = getSafeText("UI_LV_Halo_BulbIsBurnt", "Living House: *Clic* A lampada esta queimada!")
                    self.character:setHaloNote(note, 240, 90, 90, 220)
                end)
            end
            return true
        end
        return original_complete(self)
    end
end

-- Hook no menu de contexto do mundo (Turn On / Turn Off)
if ISWorldObjectContextMenu and not ISWorldObjectContextMenu._LV_LightHooked then
    ISWorldObjectContextMenu._LV_LightHooked = true
    local original_onToggleLight = ISWorldObjectContextMenu.onToggleLight
    ISWorldObjectContextMenu.onToggleLight = function(worldobjects, light, player)
        if light and LV_LightingSystem and LV_LightingSystem.isBulbBurnt and LV_LightingSystem.isBulbBurnt(light) then
            LV_LightingSystem.turnOffSwitch(light)
            local pObj = getSpecificPlayer(player)
            if pObj and pObj.setHaloNote then
                pcall(function()
                    local note = getSafeText("UI_LV_Halo_BulbIsBurnt", "Living House: *Clic* A lampada esta queimada!")
                    pObj:setHaloNote(note, 240, 90, 90, 220)
                end)
            end
            return
        end
        return original_onToggleLight(worldobjects, light, player)
    end
end

print("[LarVivo] LV_LightingSystem carregado com sucesso (Desgaste e Queima de Lampadas Ativo).")

return LV_LightingSystem
