-- media/lua/client/VICCS/Bridge/VICCS_FileBridge.lua
-- Ponte de Comunicação em Disco com o PZHub Desktop (Protocolo v2)

VICCS = VICCS or {}
VICCS.Bridge = {}

local sequenceOut = 0
local lastSeqProcessed = 0

function VICCS.Bridge.writeGameState(devicesList, activeCommand, isPaused, listenerData)
    sequenceOut = sequenceOut + 1
    local nowSec = os.time()
    pcall(function()
        if getTimestamp then
            local ts = getTimestamp()
            if ts and ts > 1000000000000 then
                nowSec = ts / 1000.0
            elseif ts and ts > 0 then
                nowSec = ts
            end
        end
    end)

    local payload = {
        protocol = 2,
        seq = sequenceOut,
        timestamp = nowSec,
        command = activeCommand,
        isPaused = isPaused or false,
        listener = listenerData or { x = 0, y = 0, z = 0, roomClass = "outdoor", outdoor = true },
        devices = devicesList or {}
    }
    
    local ok, jsonStr = pcall(VICCS.JSON.encode, payload)
    if not ok or not jsonStr then return false end
    
    local writer = getFileWriter(VICCS.Config.OutPath, true, false)
    if not writer then return false end
    
    writer:write(jsonStr)
    writer:close()
    return true
end

function VICCS.Bridge.readAppResponse()
    local reader = getFileReader(VICCS.Config.InPath, false)
    if not reader then return nil end
    
    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()
    
    local fullContent = table.concat(lines, "\n")
    if fullContent == "" then return nil end
    
    local ok, data = pcall(VICCS.JSON.decode, fullContent)
    if not ok or not data or type(data) ~= "table" then return nil end
    
    if data.seq and data.seq > lastSeqProcessed then
        lastSeqProcessed = data.seq
        return data
    end
    
    return nil
end

local function onDisconnect()
    pcall(function()
        print("[VICCS] Desconexao detectada: enviando sinal STOP para PZHub.")
        VICCS.Bridge.writeGameState({}, "STOP", false, nil)
    end)
end
Events.OnDisconnect.Add(onDisconnect)

print("[VICCS] FileBridge v1.2.3 (Protocol v2) pronto.")
