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
    if not self.item or not self.character then return false end
    local inv = self.character:getInventory()
    return inv:contains(self.item) or inv:containsRecursive(self.item)
end

function TCG_BoosterTimedAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function TCG_BoosterTimedAction:start()
    local isPT = (TCG_Config.getLanguage() == "PT")
    local jobText = isPT and "Abrindo Pacote de Cartas..." or "Opening Booster Pack..."
    if self.batchTotal and self.batchTotal > 1 then
        jobText = isPT and string.format("Abrindo Pacote %d/%d...", self.batchIndex or 1, self.batchTotal)
                       or string.format("Opening Booster Pack %d/%d...", self.batchIndex or 1, self.batchTotal)
    end
    self.item:setJobType(jobText)
    self.item:setJobDelta(0.0)
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "Mid")
    -- Som tatil customizado de rasgar o lacre metalizado / plastico do booster
    if self.character.playSoundLocal then
        self.sound = self.character:playSoundLocal("TCG_OpenBoosterpack")
    end
    if not self.sound or self.sound == 0 then
        self.sound = self.character:playSound("TCG_OpenBoosterpack")
    end
    if not self.sound or self.sound == 0 then
        self.sound = self.character:playSound("BandageTear")
    end
end

function TCG_BoosterTimedAction:stop()
    ISBaseTimedAction.stop(self)
    self.item:setJobDelta(0.0)
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end
    -- Se a acao for interrompida (movimento/ataque), cancela o lote ativo por seguranca
    if TCG_ContextMenu and TCG_ContextMenu.currentBatch then
        TCG_ContextMenu.currentBatch = nil
    end
end

function TCG_BoosterTimedAction:perform()
    local inv = self.character:getInventory()

    -- 1. Identifica o setId da colecao a partir do item
    local fullType = self.item and self.item:getFullType() or ""
    local setId = "base1"
    if fullType:find("Jungle") then
        setId = "jungle"
    elseif fullType:find("Fossil") then
        setId = "fossil"
    elseif fullType:find("TeamRocket") or fullType:find("Rocket") then
        setId = "rocket"
    elseif fullType:find("Eevee") then
        setId = "eeveeheroes"
    end

    -- 2. Modo Multiplayer: delega abertura autoritativa para o servidor
    if isClient() then
        sendClientCommand(self.character, "TCG", "openBooster", {
            boosterID = self.item:getID(),
            setId = setId,
            skipModal = self.skipModal,
            batchIndex = self.batchIndex,
            batchTotal = self.batchTotal
        })
        ISBaseTimedAction.perform(self)
        return
    end

    -- 3. Modo Singleplayer: execucao local direta e instantanea
    local container = (self.item and self.item:getContainer()) or inv
    container:Remove(self.item)

    -- 4. Rola as 10 cartas no DropTable do conjunto
    local pulled = TCG_DropTables.openBooster(setId)
    local isPT = (TCG_Config.getLanguage() == "PT")
    local setDef = TCG_CardRegistry.Sets and TCG_CardRegistry.Sets[setId]
    local totalInSet = setDef and setDef.total or 102

    -- 5. Adiciona as cartas com seu respectivo ModData bilingue
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
            md.setId = setId
            md.cardNumber = card.number
            md.totalInSet = totalInSet
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

            cardItem:setName(string.format("%s%s [#%02d/%d]", prefix, displayName, card.number, totalInSet))
            table.insert(spawnedCards, cardItem)
        end
    end

    -- 6. Exibe a interface de revelacao Frameless Soft Glass individual para cada pacote
    TCG_RevealModal.show(pulled, self.character, spawnedCards)

    -- 7. Conclui a Timed Action
    ISBaseTimedAction.perform(self)
end

function TCG_BoosterTimedAction:new(character, item, time, skipModal, batchIndex, batchTotal)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.skipModal = skipModal or false
    o.batchIndex = batchIndex
    o.batchTotal = batchTotal
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or 60 -- aprox. 1.5 a 2 segundos
    if character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end
