-- media/lua/client/VICCS/VICCS_ClientSync.lua
-- Cliente Multiplayer: Recebe comandos do servidor e sincroniza reprodução local

VICCS = VICCS or {}
VICCS.ClientSync = {}

local function onServerCommand(module, command, args)
    if module ~= "VICCS" or not args then return end
    
    if command == "SyncMedia" then
        local deviceId = args.deviceId
        if not deviceId then return end
        
        if args.state == "PLAYING" and args.url then
            local offsetSec = math.max(0, os.time() - (args.startedAtServerTime or os.time()))
            
            -- Busca objeto local se estiver na cell carregada
            local cell = getCell()
            local devObj = nil
            if cell and args.x and args.y and args.z then
                if args.deviceType == "VEHICLE" then
                    local sq = cell:getGridSquare(args.x, args.y, args.z)
                    if sq and sq.getVehicleContainer and sq:getVehicleContainer() then
                        local veh = sq:getVehicleContainer()
                        devObj = (veh.getPartById and veh:getPartById("Radio")) or veh
                    end
                    if not devObj and cell.getVehicles then
                        local vehList = cell:getVehicles()
                        if vehList then
                            for i = 0, vehList:size() - 1 do
                                local v = vehList:get(i)
                                if v and (string.find(tostring(deviceId), tostring(v:getId())) or 
                                   (math.abs(v:getX() - args.x) < 4.0 and math.abs(v:getY() - args.y) < 4.0)) then
                                    devObj = (v.getPartById and v:getPartById("Radio")) or v
                                    break
                                end
                            end
                        end
                    end
                else
                    local sq = cell:getGridSquare(args.x, args.y, args.z)
                    if sq then
                        local objs = sq:getObjects()
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            if obj and (instanceof(obj, "IsoRadio") or instanceof(obj, "IsoTelevision") or (obj.getDeviceData and obj:getDeviceData())) then
                                devObj = obj
                                break
                            end
                        end
                    end
                end
            end
            
            VICCS.Main.registerPlayingDevice(deviceId, devObj, args.x or 0, args.y or 0, args.z or 0, args.volume or 0.7, args.url, args.deviceType or "RADIO", offsetSec)
            print(string.format("[VICCS ClientSync] Aparelho %s sincronizado no tempo +%ds", tostring(deviceId), offsetSec))
            
        elseif args.state == "PAUSED" then
            if VICCS.Main.pauseDevice then
                VICCS.Main.pauseDevice(deviceId)
            else
                VICCS.Main.stopDevice(deviceId)
            end
            print(string.format("[VICCS ClientSync] Aparelho %s pausado pelo servidor", tostring(deviceId)))
        elseif args.state == "STOPPED" then
            VICCS.Main.stopDevice(deviceId)
            print(string.format("[VICCS ClientSync] Aparelho %s parado pelo servidor", tostring(deviceId)))
        end
        
    elseif command == "SetVolume" then
        if args.deviceId and args.volume then
            VICCS.Main.updateDeviceVolume(args.deviceId, args.volume)
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)
