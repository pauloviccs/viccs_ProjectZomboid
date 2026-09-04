-- =============================================================================
-- Housing Care System (Lar Vivo) - Client Events & Scheduler (LV_ClientEvents.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Orquestrador de eventos do cliente com suporte total a saves em andamento.
--   Dispara varredura imediata ao entrar no jogo, transições de cômodos e tecla 'K'.
require "LV_Config"
require "LV_RoutineSystem"
require "LV_HouseDashboard"
require "LV_DentalNeed"


local lastCheckHour = -1
local lastRoom = nil
local lastSquareCoord = { x = -1, y = -1, z = -1 }

--- Exibe notificação flutuante de forma 100% segura e compatível com todas as builds do PZ.
local function showNotification(player, text, r, g, b)
    if not player then return end
    r = r or 255
    g = g or 255
    b = b or 255
    pcall(function()
        if player.setHaloNote then
            player:setHaloNote(tostring(text), r, g, b, 250)
        elseif HaloTextHelper and HaloTextHelper.addText then
            HaloTextHelper.addText(player, tostring(text))
        end
    end)
end

--- Disparado a cada hora de tempo de jogo (Events.EveryHours).
local function onEveryHoursCheck()
    if not LV_Config or not LV_Config.isEnabled() then return end
    local player = getPlayer()
    if not player then return end

    -- Atualização de necessidade fisiológica
    if LV_BladderNeed and LV_BladderNeed.onEveryHours then
        pcall(LV_BladderNeed.onEveryHours, player)
    end

    -- Atualização de necessidade de higiene bucal
    if LV_DentalNeed and LV_DentalNeed.onEveryHours then
        pcall(LV_DentalNeed.onEveryHours, player)
    end

    local interval = LV_Config.get("ComfortCheckIntervalHours") or 6
    local currentHour = getGameTime():getWorldAgeHours()

    if lastCheckHour == -1 or (currentHour - lastCheckHour) >= interval then
        lastCheckHour = currentHour
        LV_ComfortScanner.startScan(player)
    end
end

local lastMoveScanTime = 0
local lastOwnershipClaimed = nil
local lastBaseName = nil
local lastEntryExitNoticeTime = 0

--- Monitora movimentação entre cômodos ou deslocamento na base com throttle inteligente.
local function onPlayerPositionUpdate(player)
    if not LV_Config or not LV_Config.isEnabled() or not player then return end

    -- Simulação e acúmulo de sujeira nos pés/piso
    if LV_DirtSystem and LV_DirtSystem.onPlayerMove then
        pcall(LV_DirtSystem.onPlayerMove, player)
    end

    -- Processamento de dano/cólicas e moodlets vanilla de bexiga
    if LV_BladderNeed and LV_BladderNeed.updateHealthImpact then
        pcall(LV_BladderNeed.updateHealthImpact, player)
    end

    local sq = player:getCurrentSquare()
    if not sq then return end

    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    local room = sq.getRoom and sq:getRoom()
    local now = (getTimeInMillis and getTimeInMillis() / 1000.0) or (getGameTime():getWorldAgeHours() * 3600.0)

    -- Telemetria e Notificações em Halo de Entrada / Saída da Residência Oficial
    if LV_ComfortScanner and LV_ComfortScanner.getBuildingOwnershipStatus then
        local own = LV_ComfortScanner.getBuildingOwnershipStatus(sq, player)
        local isCurrentlyClaimed = (own and own.isClaimed == true and own.status == "CLAIMED")
        local currentBaseName = (own and own.baseName) or "Seu Refugio"

        if lastOwnershipClaimed == nil then
            lastOwnershipClaimed = isCurrentlyClaimed
            lastBaseName = currentBaseName
        elseif lastOwnershipClaimed ~= isCurrentlyClaimed then
            if (now - lastEntryExitNoticeTime) >= 4.0 then
                lastEntryExitNoticeTime = now
                if isCurrentlyClaimed then
                    local note = string.format("Entrando em: %s (Seu Refugio)", currentBaseName)
                    showNotification(player, note, 80, 230, 120)
                else
                    local note = string.format("Saindo de: %s", lastBaseName or "Seu Refugio")
                    showNotification(player, note, 230, 180, 80)
                end
            end
            lastOwnershipClaimed = isCurrentlyClaimed
            if isCurrentlyClaimed then
                lastBaseName = currentBaseName
            end
        end
    end

    if room ~= lastRoom then
        lastRoom = room
        lastSquareCoord.x = px
        lastSquareCoord.y = py
        lastSquareCoord.z = pz
        lastMoveScanTime = now
        LV_ComfortScanner.startScan(player)
    else
        local distSq = (px - lastSquareCoord.x)^2 + (py - lastSquareCoord.y)^2
        -- Só dispara se moveu 6+ tiles (distSq >= 36) e após pelo menos 4 segundos da última varredura
        if (pz ~= lastSquareCoord.z or distSq >= 36) and (now - lastMoveScanTime >= 4.0) then
            lastSquareCoord.x = px
            lastSquareCoord.y = py
            lastSquareCoord.z = pz
            lastMoveScanTime = now
            LV_ComfortScanner.startScan(player)
        end
    end
end

--- Listener para consumo de comida e aumento de necessidade fisiológica
local function onEatFood(player, food)
    if LV_BladderNeed and LV_BladderNeed.onEatFood then
        pcall(LV_BladderNeed.onEatFood, player, food)
    end
    if LV_DentalNeed and LV_DentalNeed.onEatFood then
        pcall(LV_DentalNeed.onEatFood, player, food)
    end
end

--- Listener para menus de contexto no mundo (Faxina e Banheiro)
local function onFillContextMenu(playerNum, context, worldObjects, test)
    if LV_ChoreActions and LV_ChoreActions.onFillWorldObjectContextMenu then
        pcall(LV_ChoreActions.onFillWorldObjectContextMenu, playerNum, context, worldObjects, test)
    end
    if LV_ToiletActions and LV_ToiletActions.onFillWorldObjectContextMenu then
        pcall(LV_ToiletActions.onFillWorldObjectContextMenu, playerNum, context, worldObjects, test)
    end
end

--- Inicialização e varredura forçada ao carregar o personagem no mundo.
local function onGameReady()
    local player = getPlayer()
    if not player then return end

    print("[LivingHouse] OnGameStart disparado. Agendando primeira varredura da base...")
    lastCheckHour = getGameTime():getWorldAgeHours()
    LV_ComfortScanner.startScan(player, true)

    -- Inicializa HUD para ficar sempre visível (estilo CHStatusHUD)
    if LV_HUD and LV_HUD.showHUD then
        pcall(LV_HUD.showHUD)
    end
end

--- Captura de atalhos de teclado (Tecla 'K' = Keycode 37).
local function onKeyPressed(key)
    if key == 37 then
        local player = getPlayer()
        if player then
            print("[LarVivo] Tecla 'K' pressionada. Alternando Painel de Inspecao do Comodo...")
            LV_ComfortScanner.startScan(player, true)
            if LV_RoomInspectorDashboard and LV_RoomInspectorDashboard.toggle then
                LV_RoomInspectorDashboard.toggle()
            else
                LV_HUD.toggleHUD()
            end
        end
    end
end

--- Listener passivo de colocacao ou soltura de itens 3D no comodo (Zero Cliques)
local lastDropNoticeTime = 0
local function onWorldObjectAdded(object)
    if not object or not LV_Config or not LV_Config.isAmbientItemDropNoticeEnabled() then return end
    local player = getPlayer()
    if not player or player:isDead() then return end

    if instanceof and instanceof(object, "IsoWorldInventoryObject") then
        local itm = object.getItem and object:getItem()
        if itm and LV_ItemScoreData and LV_ItemScoreData.evaluateItem then
            local eval = LV_ItemScoreData.evaluateItem(itm)
            if eval and eval.score and eval.score > 0 then
                local sq = object.getSquare and object:getSquare()
                local pSq = player:getCurrentSquare()
                if sq and pSq and sq:getRoom() and sq:getRoom() == pSq:getRoom() then
                    local now = (getTimeInMillis and getTimeInMillis() / 1000.0) or (getGameTime():getWorldAgeHours() * 3600.0)
                    if now - lastDropNoticeTime >= 1.0 then
                        lastDropNoticeTime = now
                        local note = string.format("[Ambiente +%.1f pts: %s]", eval.score, eval.label or itm:getName() or "Item")
                        showNotification(player, note, 100, 240, 180)
                        pcall(function() LV_ComfortScanner.startScan(player, false) end)
                    end
                end
            end
        end
    end
end

--- Configuração de hooks seguros em ações de consumo de comida e água
local function setupActionHooks()
    if ISEatFoodAction and not ISEatFoodAction._LV_hooked then
        ISEatFoodAction._LV_hooked = true
        local orig_perform = ISEatFoodAction.perform
        function ISEatFoodAction:perform()
            orig_perform(self)
            if self.character and self.item and LV_BladderNeed and LV_BladderNeed.onEatFood then
                pcall(LV_BladderNeed.onEatFood, self.character, self.item)
            end
            if self.character and self.item and LV_DentalNeed and LV_DentalNeed.onEatFood then
                pcall(LV_DentalNeed.onEatFood, self.character, self.item)
            end
        end
    end

    if ISTakeWaterAction and not ISTakeWaterAction._LV_hooked then
        ISTakeWaterAction._LV_hooked = true
        local orig_perform = ISTakeWaterAction.perform
        function ISTakeWaterAction:perform()
            orig_perform(self)
            if self.character and not self.item and LV_BladderNeed and LV_BladderNeed.onEatFood then
                pcall(LV_BladderNeed.onEatFood, self.character, nil)
            end
        end
    end
end

setupActionHooks()

Events.EveryHours.Add(onEveryHoursCheck)
Events.OnPlayerUpdate.Add(onPlayerPositionUpdate)
Events.OnGameStart.Add(onGameReady)
Events.OnCreatePlayer.Add(function(pNum, player)
    if not player then player = getPlayer() end
    if player then
        pcall(function() LV_ComfortScanner.startScan(player, true) end)
    end
end)
Events.OnKeyPressed.Add(onKeyPressed)
if Events.OnObjectAdded then
    Events.OnObjectAdded.Add(onWorldObjectAdded)
end
if Events.OnEatFood then
    Events.OnEatFood.Add(onEatFood)
end
Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

print("[LarVivo] LV_ClientEvents carregado e escutando eventos de jogo!")


