-- =============================================================================
-- Project Zomboid TCG - Store Cards Timed Action (TCG_StoreCardsTimedAction.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Gerencia a acao temporal segura e imersiva de guardar uma ou multiplas cartas
--   no Fichario de Colecionador (Binder). O tempo da barra de carregamento escala
--   de acordo com a quantidade de cartas selecionadas pelo jogador, integrando-se
--   aos traits vanilla do Project Zomboid (Organizado / Desajeitado / Agil).
-- =============================================================================

require "TimedActions/ISBaseTimedAction"
require "TCG_Config"
require "TCG_BinderUI"
require "TCG_Theme"

TCG_StoreCardsTimedAction = ISBaseTimedAction:derive("TCG_StoreCardsTimedAction")

function TCG_StoreCardsTimedAction:isValid()
    if not self.character or not self.binderItem or not self.cardsList or #self.cardsList == 0 then
        return false
    end
    local inv = self.character:getInventory()
    -- Garante que o fichario ainda esta com o jogador (no bolso ou em mochila)
    if not inv:contains(self.binderItem) and not inv:containsRecursive(self.binderItem) then
        return false
    end
    -- Garante que pelo menos uma das cartas selecionadas ainda existe
    local hasAnyCard = false
    for _, cardIt in ipairs(self.cardsList) do
        if cardIt and (inv:contains(cardIt) or inv:containsRecursive(cardIt)) then
            hasAnyCard = true
            break
        end
    end
    return hasAnyCard
end

function TCG_StoreCardsTimedAction:update()
    if self.binderItem then
        self.binderItem:setJobDelta(self:getJobDelta())
    end

    -- Feedback sonoro sutil de folhear/encaixar plasticos a cada ciclo
    local currentStep = math.floor(self:getJobDelta() * (#self.cardsList))
    if currentStep > (self.lastStep or 0) then
        self.lastStep = currentStep
        if currentStep % 5 == 0 then
            TCG_Theme.playCardSlot()
        end
    end
end

function TCG_StoreCardsTimedAction:start()
    local count = #self.cardsList
    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local jobText = ""
    if count == 1 then
        jobText = isPT and "Guardando Carta no Fichario..." or "Storing Card in Binder..."
    else
        jobText = isPT and string.format("Guardando %d Cartas no Fichario...", count)
                       or string.format("Storing %d Cards in Binder...", count)
    end

    if self.binderItem then
        self.binderItem:setJobType(jobText)
        self.binderItem:setJobDelta(0.0)
    end

    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Mid")
    self.lastStep = 0

    -- Som tatil de abertura do fichario / encaixe de carta
    if count > 3 then
        TCG_Theme.playPageTurn()
    else
        TCG_Theme.playCardSlot()
    end
end

function TCG_StoreCardsTimedAction:stop()
    ISBaseTimedAction.stop(self)
    if self.binderItem then
        self.binderItem:setJobDelta(0.0)
    end
end

function TCG_StoreCardsTimedAction:perform()
    if self.binderItem then
        self.binderItem:setJobDelta(0.0)
    end

    -- Executa o armazenamento autoritativo de todas as cartas validas
    TCG_BinderUI.storeCardsList(self.binderItem, self.cardsList, self.character)

    ISBaseTimedAction.perform(self)
end

function TCG_StoreCardsTimedAction:new(character, binderItem, cardsList, duration)
    local o = ISBaseTimedAction.new(self, character)
    o.binderItem = binderItem
    o.cardsList = cardsList or {}
    o.stopOnWalk = true
    o.stopOnRun = true

    -- Calculo dinamico de duracao:
    -- Base de 15 ticks (~0.5s) + 12 ticks por carta (~0.4s por carta).
    -- Exemplo:
    --   1 carta  = 27 ticks (~0.9s)
    --   5 cartas = 75 ticks (~2.5s)
    --  10 cartas = 135 ticks (~4.5s)
    --  50 cartas = 615 ticks (~20s)
    if not duration or duration <= 0 then
        local count = math.max(1, #o.cardsList)
        local baseTime = 15 + (count * 12)

        -- Integracao segura com Traits Vanilla do Project Zomboid (Build 42 e Build 41)
        if character then
            local isDextrous = false
            local isAllThumbs = false
            pcall(function()
                if CharacterTrait and CharacterTrait.DEXTROUS and character.hasTrait then
                    isDextrous = character:hasTrait(CharacterTrait.DEXTROUS)
                    isAllThumbs = character:hasTrait(CharacterTrait.ALL_THUMBS)
                elseif character.hasTrait then
                    isDextrous = character:hasTrait("Dextrous")
                    isAllThumbs = character:hasTrait("AllThumbs")
                end
            end)
            if isDextrous then
                baseTime = math.max(15, math.floor(baseTime * 0.5))
            elseif isAllThumbs then
                baseTime = math.floor(baseTime * 2.0)
            end
        end
        duration = baseTime
    end

    o.maxTime = duration
    if character and character.isTimedActionInstant and character:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end
