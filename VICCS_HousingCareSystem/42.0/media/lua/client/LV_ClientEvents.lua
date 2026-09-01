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

    local interval = LV_Config.get("ComfortCheckIntervalHours") or 6
    local currentHour = getGameTime():getWorldAgeHours()

    if lastCheckHour == -1 or (currentHour - lastCheckHour) >= interval then
        lastCheckHour = currentHour
        LV_ComfortScanner.startScan(player)
    end
end

--- Monitora movimentação entre cômodos ou deslocamento na base.
local function onPlayerPositionUpdate(player)
    if not LV_Config or not LV_Config.isEnabled() or not player then return end

    local sq = player:getCurrentSquare()
    if not sq then return end

    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    local room = sq.getRoom and sq:getRoom()

    if room ~= lastRoom then
        lastRoom = room
        lastSquareCoord.x = px
        lastSquareCoord.y = py
        lastSquareCoord.z = pz
        LV_ComfortScanner.startScan(player)
    else
        local distSq = (px - lastSquareCoord.x)^2 + (py - lastSquareCoord.y)^2
        if pz ~= lastSquareCoord.z or distSq > 9 then -- Atualiza a cada 3 blocos de movimento
            lastSquareCoord.x = px
            lastSquareCoord.y = py
            lastSquareCoord.z = pz
            LV_ComfortScanner.startScan(player)
        end
    end
end

--- Inicialização e varredura forçada ao carregar o personagem no mundo.
local function onGameReady()
    local player = getPlayer()
    if not player then return end

    print("[LarVivo] OnGameStart disparado. Agendando primeira varredura da base...")
    lastCheckHour = getGameTime():getWorldAgeHours()
    LV_ComfortScanner.startScan(player, true)
end

--- Captura de atalhos de teclado (Tecla 'K' = Keycode 37).
local function onKeyPressed(key)
    if key == 37 then
        local player = getPlayer()
        if player then
            print("[LarVivo] Tecla 'K' pressionada. Forçando varredura manual e alternando HUD...")
            LV_ComfortScanner.startScan(player, true)
            LV_HUD.toggleHUD()

            local data = LV_BuffManager.getPlayerData(player)
            local baseStr = (data and data.baseName and data.baseName ~= "" and data.baseName ~= "Lar") and (data.baseName .. " — ") or ""
            if data and data.comfortTier and data.comfortTier > 0 then
                local msg = string.format("Lar Vivo: %sConforto %d pts (Tier %d)", baseStr, data.comfortScore or 0, data.comfortTier or 0)
                showNotification(player, msg, 80, 240, 120)
            else
                showNotification(player, "Lar Vivo: Varredura Concluída (Sem bônus)", 220, 220, 220)
            end
        end
    end
end

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

print("[LarVivo] LV_ClientEvents carregado e escutando eventos de jogo!")
