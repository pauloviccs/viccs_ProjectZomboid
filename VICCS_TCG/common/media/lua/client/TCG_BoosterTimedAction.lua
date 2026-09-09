-- =============================================================================
-- Project Zomboid TCG - Booster Opening Timed Action
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Gerencia a acao temporal segura de abrir um pacote de cartas.
--   Previne perda acidental ou duplicacao se interrompido por zumbi/movimento.
--   Apoia internacionalizacao com nomes bilingues salvos no ModData.
-- =============================================================================

require "TimedActions/ISBaseTimedAction"
require "TCG_Config"
require "TCG_CardRegistry"
require "TCG_DropTables"
require "TCG_RevealModal"

TCG_BoosterTimedAction = ISBaseTimedAction:derive("TCG_BoosterTimedAction")

function TCG_BoosterTimedAction:isValid()
    return self.character:getInventory():contains(self.item)
end

function TCG_BoosterTimedAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function TCG_BoosterTimedAction:start()
    local isPT = (TCG_Config.getLanguage() == "PT")
    local jobText = isPT and "Abrindo Pacote de Cartas..." or "Opening Booster Pack..."
    self.item:setJobType(jobText)
    self.item:setJobDelta(0.0)
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Mid")
    self.sound = self.character:playSound("PutItemInBag")
end

function TCG_BoosterTimedAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function TCG_BoosterTimedAction:perform()
    local inv = self.character:getInventory()

    -- 1. Remove o booster consumido de forma segura
    inv:Remove(self.item)

    -- 2. Rola as 10 cartas no DropTable
    local pulled = TCG_DropTables.openBooster("base1")
    local isPT = (TCG_Config.getLanguage() == "PT")

    -- 3. Adiciona as cartas com seu respectivo ModData bilingue
    local spawnedCards = {}
    for _, itemData in ipairs(pulled) do
        local card = itemData.card
        local cardItem = inv:AddItem("Base.TCG_Card")
        if cardItem then
            local md = cardItem:getModData()
            local nameEN = (type(card.name) == "table") and card.name.en or card.name
            local namePT = (type(card.name) == "table") and card.name.pt or card.name
            local displayName = isPT and namePT or nameEN

            md.cardId = card.id
            md.setId = "base1"
            md.cardNumber = card.number
            md.name_en = nameEN
            md.name_pt = namePT
            md.cardName = displayName
            md.rarity = TCG_CardRegistry.getCardRarity(card)
            md.isHolo = itemData.isHolo
            md.condition = itemData.condition or 100

            local prefix = ""
            if isPT then
                prefix = itemData.isHolo and "* Carta TCG (Holo): " or "Carta TCG: "
            else
                prefix = itemData.isHolo and "* TCG Card (Holo): " or "TCG Card: "
            end

            cardItem:setName(string.format("%s%s [#%02d/102]", prefix, displayName, card.number))
            table.insert(spawnedCards, cardItem)
        end
    end

    -- 4. Exibe a interface de revelacao Frameless Soft Glass
    TCG_RevealModal.show(pulled, self.character, spawnedCards)

    -- 5. Conclui a Timed Action
    ISBaseTimedAction.perform(self)
end

function TCG_BoosterTimedAction:new(character, item, time)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or 60 -- aprox. 1.5 a 2 segundos
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end
