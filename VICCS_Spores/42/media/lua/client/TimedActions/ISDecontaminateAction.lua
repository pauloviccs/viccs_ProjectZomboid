-- =============================================================================
-- VICCS Spores - Timed Action de Descontaminacao de Ar (Client)
-- Versao: 1.0.4 (Hotfix: Metodo correto cm:getWindIntensity())
-- =============================================================================

require "TimedActions/ISBaseTimedAction"

ISDecontaminateAction = ISBaseTimedAction:derive("ISDecontaminateAction")

function ISDecontaminateAction:isValid()
    if not self.character or not self.bleachItem then return false end
    return self.character:getInventory():contains(self.bleachItem)
end

function ISDecontaminateAction:update()
    if self.square then
        self.character:faceLocation(self.square:getX(), self.square:getY())
    end
end

function ISDecontaminateAction:start()
    self:setActionAnim("Pour")
    self:setOverrideHandModels(self.bleachItem, nil)
end

function ISDecontaminateAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISDecontaminateAction:perform()
    if self.bleachItem:IsDrainable() then
        self.bleachItem:Use()
    else
        self.character:getInventory():Remove(self.bleachItem)
    end
    
    local x = self.square:getX()
    local y = self.square:getY()
    local z = self.square:getZ()
    local power = VICCSSpores.opt("DecontamBleachPower", 50.0)
    
    local cm = getClimateManager()
    local windIntensity = (cm and cm.getWindIntensity and cm:getWindIntensity()) or 0.0
    
    if self.square:isOutside() and windIntensity > 0.4 then
        power = power * 0.3
        if HaloTextHelper and HaloTextHelper.addBadText then
            HaloTextHelper.addBadText(self.character, getText("UI_VICCS_Warning_WindDispersion"))
        else
            self.character:Say(getText("UI_VICCS_Warning_WindDispersion"))
        end
    end
    
    VICCSSpores.Grid.clean(x, y, z, power)
    
    if isClient() then
        sendClientCommand(self.character, "VICCSSpores", "cleanArea", { x = x, y = y, z = z, power = power })
    else
        if VICCSSpores.Net and VICCSSpores.Net.syncAirToPlayers then
            VICCSSpores.Net.syncAirToPlayers()
        end
    end
    
    if HaloTextHelper and HaloTextHelper.addGoodText then
        HaloTextHelper.addGoodText(self.character, getText("UI_ContextMenu_VICCS_Decontaminate"))
    else
        self.character:Say("Area Descontaminada.")
    end
    
    ISBaseTimedAction.perform(self)
end

function ISDecontaminateAction:new(character, square, bleachItem, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.square = square
    o.bleachItem = bleachItem
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or 120
    return o
end
