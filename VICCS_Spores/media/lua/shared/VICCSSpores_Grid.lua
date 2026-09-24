-- =============================================================================
-- VICCS Spores - Gerenciador da Grade de Esporos (Shared)
-- Versao: 1.0.3 (Sanitizacao de ModData & Tolerancia a Falhas em Saves Antigos)
-- =============================================================================

require "VICCSSpores_Config"

local Grid = {}
VICCSSpores.Grid = Grid

Grid.clientCache = Grid.clientCache or {}

function Grid.makeKey(cx, cy, z)
    return cx .. "," .. cy .. "," .. z
end

function Grid.cellOf(x, y)
    local c = VICCSSpores.CELL
    return math.floor(x / c), math.floor(y / c)
end

-- Retorna a tabela persistente de celulas com auto-migracao para saves existentes
function Grid.data()
    local md = ModData.getOrCreate("VICCSSpores")
    
    -- Inicializacao e sanitizacao de chaves caso seja a primeira vez no save antigo
    if md.cells == nil then md.cells = {} end
    if md.corpses == nil then md.corpses = {} end
    if md.version == nil then md.version = VICCSSpores.VERSION end
    
    return md
end

function Grid.get(x, y, z)
    local cx, cy = Grid.cellOf(x, y)
    local k = Grid.makeKey(cx, cy, z)
    
    if isClient() then
        return Grid.clientCache[k] or 0.0
    end
    
    local d = Grid.data()
    local c = d.cells and d.cells[k]
    return (c and type(c.v) == "number") and c.v or 0.0
end

function Grid.add(x, y, z, amount)
    if isClient() then return end
    if amount <= 0 then return end
    
    local cx, cy = Grid.cellOf(x, y)
    local d = Grid.data()
    local k = Grid.makeKey(cx, cy, z)
    
    local currentHour = getGameTime() and getGameTime():getWorldAgeHours() or 0
    local c = d.cells[k] or {
        cx = cx,
        cy = cy,
        z = z,
        v = 0.0,
        t = currentHour,
        indoors = nil
    }
    
    c.v = math.min(VICCSSpores.MAX_CONC, (c.v or 0.0) + amount)
    c.t = currentHour
    d.cells[k] = c
end

function Grid.clean(x, y, z, amount)
    local cx, cy = Grid.cellOf(x, y)
    local k = Grid.makeKey(cx, cy, z)
    
    if isClient() then
        if Grid.clientCache[k] then
            Grid.clientCache[k] = math.max(0.0, Grid.clientCache[k] - amount)
            if Grid.clientCache[k] < 0.5 then Grid.clientCache[k] = nil end
        end
        return true
    end
    
    local d = Grid.data()
    local c = d.cells and d.cells[k]
    if not c or (c.v or 0) <= 0 then return false end
    
    c.v = math.max(0.0, c.v - amount)
    
    if c.v < 0.5 then
        d.cells[k] = nil
    else
        d.cells[k] = c
    end
    
    return true
end

print("[VICCS Spores v" .. VICCSSpores.VERSION .. "] Grid & ModData sanitizados para saves existentes.")
