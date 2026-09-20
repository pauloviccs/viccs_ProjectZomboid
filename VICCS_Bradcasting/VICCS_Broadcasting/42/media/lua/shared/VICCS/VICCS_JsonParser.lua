VICCS = VICCS or {}
VICCS.JSON = {}

-- Decodificador JSON seguro e leve para Kahlua (Lua 5.1)
local function parse_error(str, idx, msg)
    return nil, string.format("JSON parse error at char %d: %s", idx, msg)
end

local function skip_whitespace(str, idx)
    local len = #str
    while idx <= len do
        local b = string.byte(str, idx)
        if b == 32 or b == 9 or b == 10 or b == 13 then
            idx = idx + 1
        else
            break
        end
    end
    return idx
end

local parse_value -- pre-declaracao

local function parse_string(str, idx)
    idx = idx + 1 -- pula a aspa inicial
    local res = {}
    local len = #str
    while idx <= len do
        local c = string.sub(str, idx, idx)
        if c == '"' then
            return table.concat(res), idx + 1
        elseif c == '\\' then
            idx = idx + 1
            local next_c = string.sub(str, idx, idx)
            if next_c == 'n' then table.insert(res, '\n')
            elseif next_c == 'r' then table.insert(res, '\r')
            elseif next_c == 't' then table.insert(res, '\t')
            elseif next_c == '"' or next_c == '\\' or next_c == '/' then table.insert(res, next_c)
            else table.insert(res, next_c) end
        else
            table.insert(res, c)
        end
        idx = idx + 1
    end
    return nil, idx, "Unterminated string"
end

local function parse_number(str, idx)
    local s, e = string.find(str, "^%-?%d+%.?%d*[eE]?[%+%-]?%d*", idx)
    if not s then return nil, idx, "Invalid number" end
    local num = tonumber(string.sub(str, s, e))
    return num, e + 1
end

local function parse_array(str, idx)
    idx = idx + 1
    local arr = {}
    idx = skip_whitespace(str, idx)
    if string.sub(str, idx, idx) == ']' then return arr, idx + 1 end
    while true do
        local val, next_idx = parse_value(str, idx)
        if next_idx == nil then return nil, idx, "Error in array value" end
        table.insert(arr, val)
        idx = skip_whitespace(str, next_idx)
        local c = string.sub(str, idx, idx)
        if c == ']' then return arr, idx + 1
        elseif c == ',' then idx = skip_whitespace(str, idx + 1)
        else return nil, idx, "Expected comma or closing bracket in array" end
    end
end

local function parse_object(str, idx)
    idx = idx + 1
    local obj = {}
    idx = skip_whitespace(str, idx)
    if string.sub(str, idx, idx) == '}' then return obj, idx + 1 end
    while true do
        if string.sub(str, idx, idx) ~= '"' then return nil, idx, "Expected string key in object" end
        local key, next_idx = parse_string(str, idx)
        if not key then return nil, idx, "Error reading key" end
        idx = skip_whitespace(str, next_idx)
        if string.sub(str, idx, idx) ~= ':' then return nil, idx, "Expected ':' after key" end
        idx = skip_whitespace(str, idx + 1)
        local val, val_idx = parse_value(str, idx)
        if val_idx == nil then return nil, idx, "Error reading object value" end
        obj[key] = val
        idx = skip_whitespace(str, val_idx)
        local c = string.sub(str, idx, idx)
        if c == '}' then return obj, idx + 1
        elseif c == ',' then idx = skip_whitespace(str, idx + 1)
        else return nil, idx, "Expected comma or closing brace in object" end
    end
end

parse_value = function(str, idx)
    idx = skip_whitespace(str, idx)
    local c = string.sub(str, idx, idx)
    if c == '"' then return parse_string(str, idx)
    elseif c == '{' then return parse_object(str, idx)
    elseif c == '[' then return parse_array(str, idx)
    elseif c == 't' and string.sub(str, idx, idx + 3) == "true" then return true, idx + 4
    elseif c == 'f' and string.sub(str, idx, idx + 4) == "false" then return false, idx + 5
    elseif c == 'n' and string.sub(str, idx, idx + 3) == "null" then return nil, idx + 4
    else return parse_number(str, idx) end
end

function VICCS.JSON.decode(str)
    if not str or type(str) ~= "string" or str == "" then return nil, "Empty input" end
    local ok, res, idx = pcall(parse_value, str, 1)
    if not ok or not res then return nil, "Failed to decode JSON" end
    return res
end

-- Codificador para envio de comandos do Mod para o Companion App
function VICCS.JSON.encode(val)
    local t = type(val)
    if t == "nil" then return "null"
    elseif t == "boolean" then return tostring(val)
    elseif t == "number" then return tostring(val)
    elseif t == "string" then
        return string.format("%q", val):gsub("\\\n", "\\n")
    elseif t == "table" then
        -- Checa se e array (indices numericos sequenciais)
        local isArray = true
        local n = 0
        for k, _ in pairs(val) do
            n = n + 1
            if type(k) ~= "number" or k ~= n then
                isArray = false
                break
            end
        end
        local parts = {}
        if isArray then
            for i = 1, #val do
                table.insert(parts, VICCS.JSON.encode(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                table.insert(parts, string.format("%q:%s", tostring(k), VICCS.JSON.encode(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end
