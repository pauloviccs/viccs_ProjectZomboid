-- =============================================================================
-- Project Zomboid TCG - Open Binder Timed Action (TCG_OpenBinderTimedAction.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Acao temporal com barra de progresso ao abrir o fichario de colecionador.
--   Previne abertura instantanea e traz imersao tatica ao jogo.
-- =============================================================================

require "TimedActions/ISBaseTimedAction"
require "TCG_Config"
require "TCG_BinderUI"

TCG_OpenBinderTimedAction = ISBaseTimedAction:derive("TCG_OpenBinderTimedAction")

function TCG_OpenBinderTimedAction:isValid()
    return self.character:getInventory():contains(self.item)
end

function TCG_OpenBinderTimedAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function TCG_OpenBinderTimedAction:start()
    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local jobText = isPT and "Abrindo Fichario de Colecionador..." or "Opening Collector Binder..."
    self.item:setJobType(jobText)
    self.item:setJobDelta(0.0)
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Mid")
    self.sound = self.character:playSound("BookOpen")
end

function TCG_OpenBinderTimedAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function TCG_OpenBinderTimedAction:perform()
    self.item:setJobDelta(0.0)
    TCG_BinderUI.open(self.item)
    ISBaseTimedAction.perform(self)
end

function TCG_OpenBinderTimedAction:new(character, item, time)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or 40 -- aprox. 1 segundo
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end
