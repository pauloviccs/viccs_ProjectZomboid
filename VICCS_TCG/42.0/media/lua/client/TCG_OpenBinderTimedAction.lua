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
require "TCG_Theme"

TCG_OpenBinderTimedAction = ISBaseTimedAction:derive("TCG_OpenBinderTimedAction")

function TCG_OpenBinderTimedAction:isValid()
    if not self.item or not self.character then return false end
    local inv = self.character:getInventory()
    return inv:contains(self.item) or inv:containsRecursive(self.item)
end

function TCG_OpenBinderTimedAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function TCG_OpenBinderTimedAction:start()
    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local jobText = isPT and "Abrindo Fichario de Colecionador..." or "Opening Collector Binder..."
    self.item:setJobType(jobText)
    self.item:setJobDelta(0.0)

    -- Animacao imersiva de leitura/abertura de livro
    self:setActionAnim("Read")
    self:setAnimVariable("ReadType", "book")

    -- 1. Efeito sonoro customizado da capa se abrindo
    TCG_Theme.playAudio("TCG_OpenBinder", "BookOpen")

    -- 2. Efeito sonoro continuo vanilla de folhear papel / leitura durante o carregamento da barra
    if self.character.playSoundLocal then
        self.sound = self.character:playSoundLocal("ReadBook")
    end
    if not self.sound or self.sound == 0 then
        self.sound = self.character:playSound("ReadBook")
    end
end

function TCG_OpenBinderTimedAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)

    -- Interrompe o som de leitura continuo com seguranca absoluta
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
        self.sound = nil
    end

    -- Som customizado de fechar a capa ao interromper a acao
    TCG_Theme.playAudio("TCG_CloseBinder", "BookClose")
end

function TCG_OpenBinderTimedAction:perform()
    self.item:setJobDelta(0.0)

    -- Interrompe o som de leitura continuo
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
        self.sound = nil
    end

    -- Som customizado de folheamento/virar pagina ao completar a barra
    TCG_Theme.playAudio("TCG_TurnPageBinder", "PageTurn")

    TCG_BinderUI.open(self.item)
    ISBaseTimedAction.perform(self)
end

function TCG_OpenBinderTimedAction:new(character, item, time)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or 50 -- aprox. 1.2 a 1.5s: tempo tatil perfeito para apreciar o audio de folheamento
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end
