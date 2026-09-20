-- media/lua/client/VICCS/Logic/VICCS_CompatHook.lua
-- Hook universal para Build 42: Compatível com saves existentes, TVRadio Reinvented, True Music e Vanilla

VICCS = VICCS or {}
VICCS.Compat = VICCS.Compat or {}

-- =========================================================================
-- Verificação Blindada de Energia e Bateria (Proteção Total Java / Kahlua)
-- =========================================================================
function VICCS.Compat.hasDevicePower(deviceObj)
    if not deviceObj then return false, false end
    
    local hasPower = false
    local isTurnedOn = false
    
    pcall(function()
        local dd = nil
        if deviceObj.getDeviceData then
            dd = deviceObj:getDeviceData()
        elseif deviceObj.getItem and deviceObj:getItem() and deviceObj:getItem().getDeviceData then
            dd = deviceObj:getItem():getDeviceData()
        end
        
        if dd then
            -- 1. Se já está ligado, a energia está 100% ativa
            pcall(function()
                if dd:getIsTurnedOn() then
                    hasPower = true
                    isTurnedOn = true
                end
            end)
            if isTurnedOn then return end
            
            -- 2. Regra nativa oficial do Project Zomboid (ISRadioAction / RWMGridPower)
            pcall(function()
                if dd.canBePoweredHere and dd:canBePoweredHere() then
                    hasPower = true
                end
            end)
            if hasPower then return end
            
            -- 3. Se for aparelho a bateria (rádio portátil, walkie-talkie)
            pcall(function()
                local isBatPowered = false
                if dd.getIsBatteryPowered then
                    isBatPowered = dd:getIsBatteryPowered()
                end
                
                if isBatPowered then
                    local hasBat = true
                    if dd.getHasBattery then
                        hasBat = dd:getHasBattery()
                    end
                    local pwr = 0
                    if dd.getPower then
                        pwr = dd:getPower() or 0
                    end
                    if hasBat and pwr > 0.001 then
                        hasPower = true
                    end
                end
            end)
            if hasPower then return end
            
            -- 4. Fallback de quadrado / gerador no mundo
            local sq = nil
            if deviceObj.getSquare then
                sq = deviceObj:getSquare()
            elseif deviceObj.getWorldItem and deviceObj:getWorldItem() and deviceObj:getWorldItem().getSquare then
                sq = deviceObj:getWorldItem():getSquare()
            end
            
            if sq then
                pcall(function()
                    if sq.haveElectricity and sq:haveElectricity() then
                        hasPower = true
                    end
                end)
                if hasPower then return end
                
                pcall(function()
                    local gen = sq.getGenerator and sq:getGenerator()
                    if gen and gen.isActivated and gen:isActivated() then
                        hasPower = true
                    end
                end)
            end
        else
            -- Objetos decorativos por sprite
            local sq = nil
            if deviceObj.getSquare then sq = deviceObj:getSquare() end
            if sq and sq.haveElectricity and sq:haveElectricity() then
                hasPower = true
                isTurnedOn = true
            end
        end
    end)
    
    return hasPower, isTurnedOn
end

-- =========================================================================
-- Detecção Universal de Dispositivos (Saves Antigos, B41 Migrada, B42 e Mods)
-- =========================================================================
function VICCS.Compat.detectDeviceType(obj)
    if not obj then return nil end
    
    -- 1. Classes nativas de Rádio e Televisão no mundo (IsoWaveSignal / IsoRadio / IsoTelevision)
    if instanceof(obj, "IsoWaveSignal") or instanceof(obj, "IsoRadio") or instanceof(obj, "IsoTelevision") then
        local isTV = false
        pcall(function()
            local dd = obj:getDeviceData()
            if dd and dd:getIsTelevision() then
                isTV = true
            end
        end)
        if not isTV and obj.getSprite and obj:getSprite() then
            local sName = string.lower(obj:getSprite():getName() or "")
            if string.find(sName, "tv") or string.find(sName, "television") then
                isTV = true
            end
        end
        return isTV and "TELEVISION" or "RADIO"
    end
    
    -- 2. Item solto no chão do mundo (IsoWorldInventoryItem)
    if instanceof(obj, "IsoWorldInventoryItem") then
        local item = obj:getItem()
        if item then
            if (item.isTwoWayRadio and item:isTwoWayRadio()) or (item.getDeviceData and item:getDeviceData()) then
                return "RADIO"
            end
        end
    end
    
    -- 3. Item de rádio em inventário ou container
    if instanceof(obj, "Radio") then
        return "RADIO"
    end
    
    -- 4. Qualquer objeto do jogo que possua DeviceData (Retrocompatibilidade Total)
    local hasDevData = false
    local isTV = false
    pcall(function()
        if obj.getDeviceData and obj:getDeviceData() then
            hasDevData = true
            isTV = obj:getDeviceData():getIsTelevision()
        end
    end)
    if hasDevData then
        return isTV and "TELEVISION" or "RADIO"
    end
    
    -- 5. Busca ampla por nomes de sprites de tilesets do Vanilla e de mapas customizados
    if obj.getSprite and obj:getSprite() then
        local sName = string.lower(obj:getSprite():getName() or "")
        if string.find(sName, "appliances_television") or string.find(sName, "television") or string.find(sName, "tv") then
            return "TELEVISION"
        elseif string.find(sName, "appliances_radio") or string.find(sName, "radio") or string.find(sName, "boombox") 
            or string.find(sName, "stereo") or string.find(sName, "jukebox") or string.find(sName, "recreation_01_") then
            return "RADIO"
        elseif string.find(sName, "computer") or string.find(sName, "terminal") or string.find(sName, "pc") then
            return "COMPUTER"
        end
    end
    
    return nil
end

-- =========================================================================
-- ESTRATÉGIA B: Hook no evento OnFillWorldObjectContextMenu (Mundo B42)
-- =========================================================================
local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    
    local player = nil
    if type(playerNum) == "number" then
        player = getSpecificPlayer(playerNum)
    elseif instanceof(playerNum, "IsoPlayer") then
        player = playerNum
    end
    if not player then player = getPlayer() end
    if not player or not context then return end
    
    local label = getText("UI_VICCS_MediaHub")
    if not label or label == "UI_VICCS_MediaHub" then
        label = "VICCS Media Hub"
    end
    
    -- Evita opções duplicadas no mesmo menu de contexto
    if context.options then
        for _, opt in pairs(context.options) do
            if opt and (opt.name == label or (opt.name and string.find(opt.name, "VICCS Media Hub"))) then 
                return 
            end
        end
    end
    
    local candidates = {}
    local added = {}
    
    local function addCandidate(o)
        if o and not added[o] then
            added[o] = true
            table.insert(candidates, o)
        end
    end
    
    -- 1. Varre a lista de objetos do clique (Java List ou Lua table)
    if worldobjects then
        if worldobjects.size and type(worldobjects.size) == "function" then
            for i = 0, worldobjects:size() - 1 do
                addCandidate(worldobjects:get(i))
            end
        else
            for _, o in pairs(worldobjects) do
                if type(o) == "table" or type(o) == "userdata" then
                    addCandidate(o)
                end
            end
        end
    end
    
    -- 2. Varre todos os objetos do Tile correspondente
    local sq = nil
    for _, obj in ipairs(candidates) do
        if obj and obj.getSquare and obj:getSquare() then
            sq = obj:getSquare()
            break
        end
    end
    
    -- Fallback: obtém coordenada do cursor se o clique não trouxe quadrado
    if not sq and ISCoordConversion and ISCoordConversion.ToWorld then
        pcall(function()
            local pNum = player.getPlayerNum and player:getPlayerNum() or 0
            local zoom = (getCore and getCore().getZoom and getCore():getZoom(pNum)) or 1
            local wx, wy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), player:getZ())
            sq = getCell():getGridSquare(math.floor(wx), math.floor(wy), player:getZ())
        end)
    end
    
    if sq and sq.getObjects then
        local sqObjs = sq:getObjects()
        if sqObjs then
            for i = 0, sqObjs:size() - 1 do
                addCandidate(sqObjs:get(i))
            end
        end
    end
    
    -- 3. Identifica se há aparelho multimídia e valida energia
    for _, obj in ipairs(candidates) do
        local devType = VICCS.Compat.detectDeviceType(obj)
        if devType then
            local hasPower, isTurnedOn = VICCS.Compat.hasDevicePower(obj)
            
            if hasPower then
                local openCallback = function(device)
                    -- Se o aparelho estava desligado no botão, liga para ativar o consumo vanilla
                    if not isTurnedOn and device and device.getDeviceData then
                        pcall(function()
                            local dd = device:getDeviceData()
                            if dd and not dd:getIsTurnedOn() then
                                if dd.setIsTurnedOn then
                                    dd:setIsTurnedOn(true)
                                end
                            end
                        end)
                    end
                    VICCS.Main.openDeviceUI(player, device, devType)
                end
                
                local opt = context:addOption(label, obj, openCallback)
                
                -- Ícone nativo vanilla
                pcall(function()
                    if devType == "TELEVISION" then
                        opt.iconTexture = getTexture("media/ui/Item_Television.png") or getTexture("media/ui/Item_Radio.png")
                    else
                        opt.iconTexture = getTexture("media/ui/Item_Radio.png")
                    end
                end)
                
                print(string.format("[VICCS] Menu ativo '%s' adicionado para %s em [%d, %d, %d] (Power: OK, Ligado: %s)",
                    label, devType, obj:getX() or 0, obj:getY() or 0, obj:getZ() or 0, tostring(isTurnedOn)))
                break
            else
                -- Em saves antigos sem energia no grid: mostra a opção desabilitada com Tooltip
                local disabledLabel = label .. " (" .. (getText("UI_VICCS_NoPower_Short") or "Sem Energia") .. ")"
                local opt = context:addOption(disabledLabel, obj, nil)
                opt.notAvailable = true
                
                local tooltipText = getText("UI_VICCS_NoPower_Tooltip") or "Este aparelho precisa de eletricidade (rede/gerador) ou bateria para funcionar."
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip.description = tooltipText
                opt.toolTip = tooltip
                
                print(string.format("[VICCS] Menu desabilitado adicionado para %s em [%d, %d] (Aparelho sem energia no save).",
                    devType, obj:getX() or 0, obj:getY() or 0))
                break
            end
        end
    end
end

-- =========================================================================
-- ESTRATÉGIA C: Hook de Inventário (Walkman e Rádio Portátil)
-- =========================================================================
local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = nil
    if type(playerNum) == "number" then
        player = getSpecificPlayer(playerNum)
    elseif instanceof(playerNum, "IsoPlayer") then
        player = playerNum
    end
    if not player then player = getPlayer() end
    if not player or not context then return end
    
    for _, item in ipairs(items) do
        local realItem = item
        if not instanceof(item, "InventoryItem") and item.items then
            realItem = item.items[1]
        end
        
        if realItem and ((realItem.isTwoWayRadio and realItem:isTwoWayRadio()) or (realItem.getDeviceData and realItem:getDeviceData())) then
            local hasPower, isTurnedOn = VICCS.Compat.hasDevicePower(realItem)
            local label = getText("UI_VICCS_MediaHub") or "VICCS Media Hub"
            
            if hasPower then
                context:addOption(label, realItem, function(target)
                    if not isTurnedOn and target and target.getDeviceData then
                        pcall(function()
                            local dd = target:getDeviceData()
                            if dd and not dd:getIsTurnedOn() then
                                if dd.setIsTurnedOn then
                                    dd:setIsTurnedOn(true)
                                end
                            end
                        end)
                    end
                    VICCS.Main.openDeviceUI(player, target, "RADIO")
                end)
                break
            else
                local disabledLabel = label .. " (" .. (getText("UI_VICCS_NoPower_Short") or "Sem Energia") .. ")"
                local opt = context:addOption(disabledLabel, realItem, nil)
                opt.notAvailable = true
                break
            end
        end
    end
end

-- =========================================================================
-- ESTRATÉGIA D: Injeção defensiva no ISRadioWindow (Vanilla & TVRadio Reinvented)
-- =========================================================================
local function hookRadioWindow()
    pcall(function()
        if not ISRadioWindow then return end
        local original_activate = ISRadioWindow.activate
        if not original_activate then return end
        
        ISRadioWindow.activate = function(_player, _deviceObject, _isIso)
            local window = original_activate(_player, _deviceObject, _isIso)
            
            if window and not window.viccsMediaButtonInjected then
                window.viccsMediaButtonInjected = true
                
                local btnW = 90
                local btnH = 22
                local btnX = math.max(10, window.width - btnW - 35)
                local btnY = 2
                
                local btnWeb = ISButton:new(btnX, btnY, btnW, btnH, "Web Link", window, function(self)
                    local devType = VICCS.Compat.detectDeviceType(_deviceObject) or "RADIO"
                    VICCS.Main.openDeviceUI(_player, _deviceObject, devType)
                end)
                btnWeb:initialise()
                btnWeb.borderColor = { r = 0.0, g = 0.85, b = 1.0, a = 0.8 }
                window:addChild(btnWeb)
                print("[VICCS] Botao Web Link injetado no painel vanilla ISRadioWindow.")
            end
            
            return window
        end
    end)
end

-- =========================================================================
-- Registro de Eventos da B42
-- =========================================================================
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
Events.OnGameStart.Add(hookRadioWindow)

print("[VICCS] CompatHook (Build 42) carregado com sucesso — menus de contexto registrados.")
