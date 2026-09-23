-- =============================================================================
-- Project Zomboid TCG - Client Command Handlers (TCG_ClientCommands.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Processa respostas autoritativas do servidor no cliente multiplayer (PZ B42).
--   Sincroniza UI de revelacao de pacotes, atualizacoes do fichario e mensagens halo.
-- =============================================================================

if isServer() and not isClient() then return end

require "TCG_Config"
require "TCG_CardRegistry"
require "TCG_Theme"
require "TCG_RevealModal"
require "TCG_BinderUI"
require "TCG_BinderData"

local Commands = {}

--- 1. boosterOpened: Recebe cartas geradas pelo servidor e abre a UI de revelacao
Commands.boosterOpened = function(args)
    if not args then return end
    local player = getPlayer()
    if not player then return end

    local pulled = {}
    local spawnedCards = {}
    local inv = player:getInventory()

    if args.pulled then
        for _, pData in ipairs(args.pulled) do
            local cardDef = TCG_CardRegistry.getCard(pData.cardId)
            if cardDef then
                table.insert(pulled, {
                    card = cardDef,
                    isHolo = (pData.isHolo == true),
                    condition = pData.condition or 100
                })
            end

            if pData.itemId then
                local cardItem = TCG_BinderData.findItemRecursive(inv, pData.itemId)
                if cardItem then
                    table.insert(spawnedCards, cardItem)
                end
            end
        end
    end

    -- Abre a janela de revelacao com os dados reais sincronizados do servidor
    TCG_RevealModal.show(pulled, player, spawnedCards)
end

--- 2. cardsStored: Confirmacao de que as cartas foram arquivadas no servidor
Commands.cardsStored = function(args)
    if not args then return end
    local player = getPlayer()
    if not player then return end

    -- Limpa cartas fantasmas locais de versoes legadas (Auto-Heal)
    if args.phantomItemIDs and #args.phantomItemIDs > 0 then
        local inv = player:getInventory()
        for _, phantomID in ipairs(args.phantomItemIDs) do
            local item, container = TCG_BinderData.findItemRecursive(inv, phantomID)
            if item and container then
                container:Remove(item)
            end
        end
    end

    TCG_Theme.playCardSlot()
    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local count = args.count or 1
    local msg = isPT and string.format("%d carta(s) guardada(s) no fichario!", count)
                      or string.format("%d card(s) stored in binder!", count)
    if player.setHaloNote then
        pcall(function() player:setHaloNote(msg, 90, 220, 140, 250) end)
    end
end

--- 3. cardWithdrawn: Confirmacao de saque de carta do fichario
Commands.cardWithdrawn = function(args)
    if not args then return end
    local player = getPlayer()
    if not player then return end

    if TCG_Theme.playCardTake then
        TCG_Theme.playCardTake()
    elseif TCG_Theme.playCardWithdraw then
        TCG_Theme.playCardWithdraw()
    end
    local isPT = (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage() == "PT")
    local amount = args.amount or 1
    local num = args.num or 1
    local displayName = args.displayName or "Carta"

    local msg = ""
    if amount > 1 then
        msg = isPT and string.format("%dx Carta #%02d %s retiradas do fichario!", amount, num, displayName)
                   or string.format("%dx Card #%02d %s removed from binder!", amount, num, displayName)
    else
        msg = isPT and string.format("Carta #%02d %s retirada do fichario!", num, displayName)
                   or string.format("Card #%02d %s removed from binder!", num, displayName)
    end

    if player.setHaloNote then
        pcall(function() player:setHaloNote(msg, 90, 220, 140, 250) end)
    end
end

local function onServerCommand(module, command, args)
    if module ~= "TCG" then return end
    if Commands[command] then
        Commands[command](args)
    end
end

Events.OnServerCommand.Add(onServerCommand)
