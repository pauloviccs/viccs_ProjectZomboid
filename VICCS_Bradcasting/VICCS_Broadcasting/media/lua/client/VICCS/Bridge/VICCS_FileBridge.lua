VICCS = VICCS or {}
VICCS.Bridge = {}

local sequenceOut = 0
local lastSeqProcessed = 0

function VICCS.Bridge.writeGameState(devicesList, activeCommand)
    sequenceOut = sequenceOut + 1
    local payload = {
        protocol = VICCS.Config.Protocol,
        seq = sequenceOut,
        timestamp = os.time(),
        command = activeCommand,
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
