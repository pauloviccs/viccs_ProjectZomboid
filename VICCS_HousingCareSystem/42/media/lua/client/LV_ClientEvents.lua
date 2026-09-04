-- =============================================================================
-- Housing Care System (Lar Vivo) - Client Events & Scheduler (LV_ClientEvents.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Orquestrador de eventos do cliente com suporte total a saves em andamento.
--   Dispara varredura imediata ao entrar no jogo, transições de cômodos e tecla 'K'.
-- =============================================================================

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

    local interval = LV_Config.get("ComfortCheckIntervalHours") or 6
    local currentHour = getGameTime():getWorldAgeHours()

    if lastCheckHour == -1 or (currentHour - lastCheckHour) >= interval then
        lastCheckHour = currentHour
        LV_ComfortScanner.startScan(player)
    end
end

local lastMoveScanTime = 0

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
            print("[LarVivo] Tecla 'K' pressionada. Forçando varredura manual e alternando HUD...")
            LV_ComfortScanner.startScan(player, true)
            LV_HUD.toggleHUD()

            local baseStr = (data and data.baseName and data.baseName ~= "" and data.baseName ~= "Lar" and data.baseName ~= "Living House") and (data.baseName .. " - ") or ""
            if data and data.comfortTier and data.comfortTier > 0 then
                local msg = string.format("Living House: %sConforto %d pts (Tier %d)", baseStr, data.comfortScore or 0, data.comfortTier or 0)
                showNotification(player, msg, 80, 240, 120)
            else
                showNotification(player, "Living House: Varredura Concluida (Sem bonus)", 220, 220, 220)
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
if Events.OnEatFood then
    Events.OnEatFood.Add(onEatFood)
end
Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

print("[LarVivo] LV_ClientEvents carregado e escutando eventos de jogo!")

