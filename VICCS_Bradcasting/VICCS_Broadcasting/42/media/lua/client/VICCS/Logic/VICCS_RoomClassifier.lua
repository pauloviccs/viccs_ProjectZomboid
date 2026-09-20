-- media/lua/client/VICCS/Logic/VICCS_RoomClassifier.lua
-- Classificador Acústico de Ambientes (Build 42)
-- Identifica o tipo e dimensão volumétrica do cômodo para definir presets de RT60 (reverberação)

VICCS = VICCS or {}
VICCS.RoomClassifier = {}

local roomCache = {}

function VICCS.RoomClassifier.classify(square)
    if not square then return "outdoor" end
    
    -- 1. Se estiver ao ar livre (rua, quintal, floresta)
    local isOut = true
    pcall(function()
        if square.isOutside then
            isOut = square:isOutside()
        end
    end)
    if isOut then return "outdoor" end
    
    -- 2. Identifica o objeto de cômodo nativo do Project Zomboid
    local room = nil
    pcall(function()
        if square.getRoom then
            room = square:getRoom()
        end
    end)
    
    if not room then
        local bld = nil
        pcall(function() if square.getBuilding then bld = square:getBuilding() end end)
        return bld and "medium" or "outdoor"
    end
    
    -- Cache por referência do cômodo
    if roomCache[room] then
        return roomCache[room]
    end
    
    local rName = ""
    pcall(function()
        if room.getName then
            rName = string.lower(tostring(room:getName() or ""))
        end
    end)
    
    -- 3. Análise semântica por nome do cômodo
    if string.find(rName, "bathroom") or string.find(rName, "washroom") or string.find(rName, "closet") or string.find(rName, "toilet") then
        roomCache[room] = "small"
        return "small"
    elseif string.find(rName, "warehouse") or string.find(rName, "storage") or string.find(rName, "garage") or string.find(rName, "factory") or string.find(rName, "hangar") then
        roomCache[room] = "industrial"
        return "industrial"
    elseif string.find(rName, "church") or string.find(rName, "gym") or string.find(rName, "cinema") or string.find(rName, "mall") or string.find(rName, "hall") then
        roomCache[room] = "large"
        return "large"
    end
    
    -- 4. Análise métrica pelo número de quadrados do cômodo
    local sqCount = 0
    pcall(function()
        local sqs = room.getSquares and room:getSquares()
        if sqs and sqs.size then
            sqCount = sqs:size()
        end
    end)
    
    local classification = "medium"
    if sqCount > 0 then
        if sqCount <= 16 then
            classification = "small"
        elseif sqCount <= 64 then
            classification = "medium"
        elseif sqCount <= 180 then
            classification = "large"
        else
            classification = "industrial"
        end
    end
    
    roomCache[room] = classification
    return classification
end

print("[VICCS] RoomClassifier (Acústica de Cômodos) inicializado.")
