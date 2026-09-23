VICCS = VICCS or {}
VICCS.Config = {
    Version = "1.2.3",
    Protocol = 2,
    
    -- Caminhos de troca no disco (<User>/Zomboid/Lua/PZMusic/)
    OutPath = "PZMusic/game_to_app.json",
    InPath  = "PZMusic/app_to_game.json",
    
    -- Intervalo de processamento de áudio 3D e atração de zumbis
    PollIntervalTicks = 30, -- ~0.5s a 60 FPS
    
    -- Alcance de escuta humana em tiles (para cálculo de atenuação cúbica)
    MaxAudibleDistance = 35.0,
    
    -- Multiplicador do raio de atração de zumbis (WorldSoundManager)
    ZombieMaxRadius = 75,
    ZombieSoundIntensity = 80,
    
    -- Limites de Volume
    MinVolume = 0.0,
    MaxVolume = 1.0,
    DefaultVolume = 0.7,
    
    -- Domínios autorizados para reprodução segura
    AllowedDomains = {
        "youtube.com",
        "youtu.be",
        "music.youtube.com",
        "soundcloud.com"
    },
    
    -- Tipos de Aparelho
    DeviceTypes = {
        RADIO = "RADIO",
        TELEVISION = "TELEVISION",
        COMPUTER = "COMPUTER",
        CAR_RADIO = "CAR_RADIO"
    }
}

function VICCS.Config.getSandboxVar(varName, defaultValue)
    if SandboxVars and SandboxVars.VICCS_Broadcasting and SandboxVars.VICCS_Broadcasting[varName] ~= nil then
        return SandboxVars.VICCS_Broadcasting[varName]
    end
    return defaultValue
end

function VICCS.Config.isDomainAllowed(url)
    if not url or type(url) ~= "string" then return false end
    
    local trustedOnly = VICCS.Config.getSandboxVar("TrustedDomainsOnly", true)
    if not trustedOnly then
        -- Modo livre: aceita qualquer URL HTTP/HTTPS
        local lower = string.lower(url)
        return (string.find(lower, "^https?://") ~= nil) or (string.find(lower, "www%.") ~= nil)
    end
    
    local lower = string.lower(url)
    for _, domain in ipairs(VICCS.Config.AllowedDomains) do
        if string.find(lower, domain, 1, true) then
            return true
        end
    end
    return false
end

function VICCS.Config.cleanUrl(url)
    if not url then return "" end
    -- Remove espaços antes e depois
    return string.match(url, "^%s*(.-)%s*$") or url
end

