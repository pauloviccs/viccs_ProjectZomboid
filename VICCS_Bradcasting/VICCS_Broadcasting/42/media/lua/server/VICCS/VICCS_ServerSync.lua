-- media/lua/server/VICCS/VICCS_ServerSync.lua
-- Servidor Autoritativo: Sincroniza estado de reprodução no Multiplayer sem consumir banda de áudio

VICCS = VICCS or {}
VICCS.Server = {}

local activeServerDevices = {}

local function findDeviceOnSquare(square, deviceId)
    if not square then return nil end
    local objs = square:getObjects()
    if not objs then return nil end
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj and (instanceof(obj, "IsoWaveSignal") or instanceof(obj, "IsoRadio") or instanceof(obj, "IsoTelevision") or (obj.getDeviceData and obj:getDeviceData())) then
            return obj
        end
    end
    return nil
end

local function onClientCommand(module, command, player, args)
    if module ~= "VICCS" then return end
    if not args or not args.deviceId then return end
    
    if command == "PlayMedia" then
        if not args.url or not VICCS.Config.isDomainAllowed(args.url) then
            print("[VICCS Server] URL rejeitada por seguranca: " .. tostring(args.url))
            return
        end
        
        -- Validação de energia no servidor (anti-exploit e consistência multiplayer)
        local cell = getCell()
        local devObj = nil
        if cell and args.x and args.y and args.z then
            local sq = cell:getGridSquare(args.x, args.y, args.z)
            devObj = findDeviceOnSquare(sq, args.deviceId)
        end
        
        if devObj then
            local hasPower = false
            pcall(function()
                local dd = devObj:getDeviceData()
                if dd then
                    if dd.getIsTurnedOn and dd:getIsTurnedOn() then
                        hasPower = true
                    else
                        local isBat = dd.getIsBatteryPowered and dd:getIsBatteryPowered()
                        local hasBat = (dd.getHasBattery and dd:getHasBattery()) or (dd.hasBattery and dd:hasBattery())
                        local pwr = (dd.getPower and dd:getPower()) or 0
                        local canBePowered = dd.canBePoweredHere and dd:canBePoweredHere()
                        local sq = devObj:getSquare()
                        local hasGridPower = sq and sq.haveElectricity and sq:haveElectricity()
                        
                        if (isBat and hasBat and pwr > 0) or canBePowered or hasGridPower then
                            hasPower = true
                            if dd.setIsTurnedOn then
                                dd:setIsTurnedOn(true)
                            end
                        end
                    end
                end
            end)
            
            if not hasPower then
                print("[VICCS Server] PlayMedia recusado para " .. tostring(args.deviceId) .. ": dispositivo sem energia no servidor.")
                return
            end
        end
        
        local serverTime = os.time()
        local record = {
            deviceId = args.deviceId,
            x = args.x,
            y = args.y,
            z = args.z,
            url = args.url,
            volume = args.volume or VICCS.Config.DefaultVolume,
            deviceType = args.deviceType or "RADIO",
            startedAtServerTime = serverTime,
            state = "PLAYING",
            owner = player and player:getUsername() or "Unknown"
        }
        activeServerDevices[args.deviceId] = record
        
        -- Salva no ModData do objeto no mundo para persistir no save do servidor
        if devObj then
            local md = devObj:getModData()
            md.viccsMedia = record
            devObj:transmitModData()
        end
        
        -- Propaga para todos os clientes conectados (buffer e timestamp sincronizados)
        sendServerCommand("VICCS", "SyncMedia", record)
        print("[VICCS Server] Transmissao iniciada para " .. args.deviceId .. " por " .. record.owner)
        
    elseif command == "ResumeMedia" then
        local record = activeServerDevices[args.deviceId]
        if record then
            record.state = "PLAYING"
            record.startedAtServerTime = os.time() - (record.pausedOffset or 0)
            
            local cell = getCell()
            if cell and record.x and record.y and record.z then
                local sq = cell:getGridSquare(record.x, record.y, record.z)
                local devObj = findDeviceOnSquare(sq, args.deviceId)
                if devObj then
                    local md = devObj:getModData()
                    if md.viccsMedia then
                        md.viccsMedia.state = "PLAYING"
                        md.viccsMedia.startedAtServerTime = record.startedAtServerTime
                        devObj:transmitModData()
                    end
                end
            end
            
            sendServerCommand("VICCS", "SyncMedia", record)
            print("[VICCS Server] Transmissao retomada para " .. args.deviceId)
        end
        
    elseif command == "PauseMedia" or command == "StopMedia" then
        local record = activeServerDevices[args.deviceId]
        if record then
            if command == "PauseMedia" then
                record.state = "PAUSED"
                record.pausedOffset = math.max(0, os.time() - (record.startedAtServerTime or os.time()))
            else
                record.state = "STOPPED"
                record.pausedOffset = 0
            end
        else
            record = { deviceId = args.deviceId, state = "STOPPED" }
        end
        
        local cell = getCell()
        if cell and args.x and args.y and args.z then
            local sq = cell:getGridSquare(args.x, args.y, args.z)
            local devObj = findDeviceOnSquare(sq, args.deviceId)
            if devObj then
                local md = devObj:getModData()
                if md.viccsMedia then
                    md.viccsMedia.state = record.state
                    md.viccsMedia.pausedOffset = record.pausedOffset
                    devObj:transmitModData()
                end
            end
        end
        
        sendServerCommand("VICCS", "SyncMedia", record)
        print("[VICCS Server] Estado atualizado para " .. record.state .. " no device: " .. args.deviceId)
        
    elseif command == "SetVolume" then
        local record = activeServerDevices[args.deviceId]
        if record then
            record.volume = math.max(VICCS.Config.MinVolume, math.min(VICCS.Config.MaxVolume, args.volume or 0.7))
            sendServerCommand("VICCS", "SetVolume", { deviceId = args.deviceId, volume = record.volume })
        end
    end
end

-- Varredura periódica para encerrar dispositivos que perderam energia no servidor
local function checkServerDevicePower()
    local cell = getCell()
    if not cell then return end
    
    for id, record in pairs(activeServerDevices) do
        if record.state == "PLAYING" and record.x and record.y and record.z then
            local sq = cell:getGridSquare(record.x, record.y, record.z)
            local devObj = findDeviceOnSquare(sq, id)
            if devObj then
                local stillOn = true
                pcall(function()
                    local dd = devObj:getDeviceData()
                    if dd and not dd:getIsTurnedOn() then
                        stillOn = false
                    end
                end)
                
                if not stillOn then
                    record.state = "STOPPED"
                    local md = devObj:getModData()
                    if md.viccsMedia then
                        md.viccsMedia.state = "STOPPED"
                        devObj:transmitModData()
                    end
                    sendServerCommand("VICCS", "SyncMedia", record)
                    print("[VICCS Server] Dispositivo " .. id .. " perdeu energia. Transmissao encerrada.")
                end
            end
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.EveryOneMinute.Add(checkServerDevicePower)

print("[VICCS ServerSync] Servidor inicializado para sincronia multiplayer (Build 42).")
