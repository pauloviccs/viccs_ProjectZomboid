-- =============================================================================
-- Project Zomboid TCG - Compatibility & Server Crash Prevention Hooks
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Blindagem contra excecoes nulas em acoes de rede do Project Zomboid B42.
--   Previne crash do servidor headless caso um item nulo seja processado em
--   ISDropWorldItemAction:getDuration() ou ISDropWorldItemAction:perform().
-- =============================================================================

require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISDropWorldItemAction"

if ISDropWorldItemAction then
    local original_getDuration = ISDropWorldItemAction.getDuration
    function ISDropWorldItemAction:getDuration()
        if not self.item then
            return 1
        end
        return original_getDuration(self)
    end

    local original_perform = ISDropWorldItemAction.perform
    function ISDropWorldItemAction:perform()
        if not self.item then
            ISBaseTimedAction.perform(self)
            return
        end
        return original_perform(self)
    end
end
