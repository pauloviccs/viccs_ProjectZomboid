-- =============================================================================
-- VICCS Spores - Exposicao e Infeccao do Jogador (Client)
-- Versao: 1.1.1 (Calibracao de Inalacao, Spawn Grace Period & Strict ASCII)
-- =============================================================================

require "VICCSSpores_Config"
require "VICCSSpores_Grid"

VICCSSpores.Exposure = VICCSSpores.Exposure or {}
local Exposure = VICCSSpores.Exposure

Exposure.spawnGraceUntil = 0

function Exposure.getProtection(player)
    if not player then return 0.0 end
    
    local wornItems = player:getWornItems()
    if not wornItems then return 0.0 end
    
    local bestProt = 0.0
    
    for i = 0, wornItems:size() - 1 do
        local worn = wornItems:get(i)
        local item = worn and worn:getItem()
        if item then
            local fullType = item:getFullType()
            local prot = VICCSSpores.Protection[fullType]
            if prot and prot > bestProt then
                bestProt = prot
            end
        end
    end
    
    return bestProt
end

function Exposure.getCurrentDose(player)
    player = player or getPlayer()
    if not player then return 0.0 end
    local md = player:getModData()
    return md and md.viccsDose or 0.0
end

function Exposure.getThreshold()
    return VICCSSpores.opt("DoseThreshold", 120.0)
end

function Exposure.tickDose()
    local player = getPlayer()
    if not player or player:isDead() then return end
    
    -- Imunidade de Spawn (30 segundos reais para dar tempo do mapa carregar)
    local nowMs = (getTimestampMs and getTimestampMs()) or (getGameTime() and getGameTime():getWorldAgeHours() * 3600000) or 0
    if Exposure.spawnGraceUntil and nowMs < Exposure.spawnGraceUntil then
        return
    end
    
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())
    
    local conc = VICCSSpores.Grid.get(px, py, pz)
    local md = player:getModData()
    
    if type(md.viccsDose) ~= "number" then
        md.viccsDose = 0.0
    end
    
    local prot = Exposure.getProtection(player)
    
    local breath = 1.0
    if player:isSprinting() then
        breath = 2.0
    elseif player:isRunning() then
        breath = 1.5
    elseif player:isPlayerMoving() then
        breath = 1.2
    end
    
    local threshold = Exposure.getThreshold()
    
    if conc > 0 then
        -- Calibracao B42: (conc * 0.10) por minuto de jogo.
        -- Uma nuvem densa (50.0 conc) gera 5.0 pontos/min.
        -- Sem mascara, demora 24 min de jogo (~48 seg reais) para atingir 120 de dose.
        local doseRate = (conc * 0.10) * (1.0 - prot) * breath
        md.viccsDose = math.min(threshold, md.viccsDose + doseRate)
    else
        local recovery = VICCSSpores.opt("DoseRecoveryPerMinute", 1.0)
        md.viccsDose = math.max(0.0, md.viccsDose - recovery)
    end
    
    -- Avisos e reacoes graduais conforme o acumulo nos pulmoes
    if md.viccsDose >= (threshold * 0.75) and md.viccsDose < threshold then
        if ZombRand(4) == 0 then
            player:Say("*asfixia grave com esporos*")
        end
    elseif md.viccsDose >= (threshold * 0.50) and md.viccsDose < (threshold * 0.75) then
        if ZombRand(6) == 0 then
            player:Say("*tosse pesada*")
        end
    elseif md.viccsDose >= (threshold * 0.25) and md.viccsDose < (threshold * 0.50) then
        if ZombRand(10) == 0 then
            player:Say("*ardencia na garganta*")
        end
    end
    
    -- Infeccao Letal
    if md.viccsDose >= threshold then
        local bd = player:getBodyDamage()
        if bd and not bd:IsInfected() then
            bd:setInfected(true)
            md.viccsSporeInfected = true
            
            if HaloTextHelper and HaloTextHelper.addBadText then
                HaloTextHelper.addBadText(player, getText("UI_VICCS_Lungs_Infected"))
            else
                player:Say(getText("UI_VICCS_Lungs_Infected"))
            end
        end
    end
end

local function onServerCommand(module, command, args)
    if module ~= "VICCSSpores" or not args then return end
    
    if command == "syncNearby" and args.cells then
        VICCSSpores.Grid.clientCache = args.cells
    elseif command == "cellUpdated" and args.key then
        if args.conc and args.conc >= 0.5 then
            VICCSSpores.Grid.clientCache[args.key] = args.conc
        else
            VICCSSpores.Grid.clientCache[args.key] = nil
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)

Events.EveryOneMinute.Add(function()
    local ok, err = pcall(Exposure.tickDose)
    if not ok then
        print("[VICCS Spores ERROR Exposure.tickDose]: " .. tostring(err))
    end
end)

local function onPlayerLoad(playerNum, player)
    player = player or getSpecificPlayer(playerNum) or getPlayer()
    if not player then return end
    
    local md = player:getModData()
    if type(md.viccsDose) ~= "number" then
        md.viccsDose = 0.0
    end
    
    -- Ativa Grace Period de 30 segundos reais
    local nowMs = (getTimestampMs and getTimestampMs()) or (getGameTime() and getGameTime():getWorldAgeHours() * 3600000) or 0
    Exposure.spawnGraceUntil = nowMs + 30000
end
Events.OnCreatePlayer.Add(onPlayerLoad)

print("[VICCS Spores v" .. VICCSSpores.VERSION .. "] Modulo de Exposicao v1.1.1 (Calibrado & Strict ASCII) ativo.")
