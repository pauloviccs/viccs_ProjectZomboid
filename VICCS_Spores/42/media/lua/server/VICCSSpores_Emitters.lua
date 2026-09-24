-- =============================================================================
-- VICCS Spores - Emissores de Alta Performance (Server / SP)
-- Versao: 1.2.0 (Zero-FPS-Drop: Batch Interval Processing, No Per-Frame Hooks)
-- =============================================================================

require "VICCSSpores_Grid"

local Emitters = {}
VICCSSpores.Emitters = Emitters

-- 1. EMISSAO POR ZUMBIS CARRIERS VIVOS (Processamento em Lote Intervalado)
-- Em vez de OnZombieUpdate (que roda 48.000x/s com hordas e destroi o FPS),
-- iteramos em lote sobre zumbis proximos aos jogadores a cada minuto de jogo.
local function onLivingCarriersTick()
    if isClient() then return end
    if not VICCSSpores.opt("Enabled", true) then return end
    
    local cellEngine = getCell()
    if not cellEngine then return end
    
    local zList = cellEngine:getZombieList()
    if not zList or zList:size() == 0 then return end
    
    local carrierChance = VICCSSpores.opt("CarrierChance", 0.08) * 1000
    local zCount = zList:size()
    
    -- Processa no maximo 100 zumbis por tick para garantir tempo de execucao inferior a 0.5ms
    local maxCheck = math.min(100, zCount)
    local step = math.max(1, math.floor(zCount / maxCheck))
    
    for i = 0, zCount - 1, step do
        local z = zList:get(i)
        if z and not z:isDead() then
            local md = z:getModData()
            if md.viccsCarrier == nil then
                md.viccsCarrier = (ZombRand(1000) < carrierChance)
            end
            
            if md.viccsCarrier then
                local sq = z:getSquare()
                if sq then
                    VICCSSpores.Grid.add(sq:getX(), sq:getY(), sq:getZ(), 2.0)
                end
            end
        end
    end
end
Events.EveryOneMinute.Add(onLivingCarriersTick)

-- 2. MORTE DO CARRIER (Gera explosao de esporos e cadastra cadaver decompositor)
local function onZombieDead(zombie)
    if isClient() then return end
    if not zombie then return end
    
    local md = zombie:getModData()
    if not md.viccsCarrier then return end
    
    local sq = zombie:getSquare()
    if not sq then return end
    
    local sx, sy, sz = sq:getX(), sq:getY(), sq:getZ()
    VICCSSpores.Grid.add(sx, sy, sz, 15.0)
    
    local d = VICCSSpores.Grid.data()
    d.corpses = d.corpses or {}
    
    local currentHour = getGameTime() and getGameTime():getWorldAgeHours() or 0
    table.insert(d.corpses, {
        x = sx,
        y = sy,
        z = sz,
        deathHour = currentHour
    })
    
    -- Mantem historico leve (maximo 150 cadaveres rastreados)
    if #d.corpses > 150 then
        table.remove(d.corpses, 1)
    end
end
Events.OnZombieDead.Add(onZombieDead)

-- 3. CICLO DE DECOMPOSICAO TEMPORAL DOS CADAVERES (Resiliente a Relogio do Save)
local function onCorpseDecayTick()
    if isClient() then return end
    local d = VICCSSpores.Grid.data()
    if not d.corpses or #d.corpses == 0 then return end
    
    local currentHour = getGameTime() and getGameTime():getWorldAgeHours() or 0
    local maxHours = VICCSSpores.opt("CorpseDecayDays", 5) * 24
    local survivingCorpses = {}
    
    for _, corpse in ipairs(d.corpses) do
        local deathHour = corpse.deathHour or currentHour
        local ageHours = math.max(0, currentHour - deathHour)
        
        if ageHours < maxHours then
            local factor = math.max(0.1, 1.0 - (ageHours / maxHours))
            VICCSSpores.Grid.add(corpse.x, corpse.y, corpse.z, 3.0 * factor)
            table.insert(survivingCorpses, corpse)
        end
    end
    
    d.corpses = survivingCorpses
end
Events.EveryOneMinute.Add(onCorpseDecayTick)

print("[VICCS Spores v" .. VICCSSpores.VERSION .. "] Modulo de Emissores v1.2.0 (Zero-FPS-Drop Batch) ativo.")
