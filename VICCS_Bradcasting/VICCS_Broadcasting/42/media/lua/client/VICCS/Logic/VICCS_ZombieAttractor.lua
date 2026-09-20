VICCS = VICCS or {}
VICCS.Zombies = {}

-- Chamado periodicamente a cada ciclo de ticks enquanto o aparelho estiver tocando
function VICCS.Zombies.pulseSound(deviceObj, x, y, z, masterVolume, isHeadphones)
    if not deviceObj or not masterVolume or masterVolume <= 0 then return end
    
    -- Se o jogador estiver usando fone de ouvido plugado no walkman, nao atrai zumbis externos
    if isHeadphones then return end
    
    -- Calcula o raio de atracao proporcional ao volume (0.0 a 1.0)
    local radius = math.floor(masterVolume * VICCS.Config.ZombieMaxRadius)
    local intensity = math.floor(masterVolume * VICCS.Config.ZombieSoundIntensity)
    
    if radius > 2 and WorldSoundManager and WorldSoundManager.instance then
        -- addSound(sourceObject, x, y, z, radius, volumeIntensity)
        WorldSoundManager.instance:addSound(deviceObj, math.floor(x), math.floor(y), math.floor(z), radius, intensity)
    end
end
