-- =============================================================================
-- VICCS Spores - Configuracoes e Constantes Compartilhadas (Shared)
-- Versao: 1.0.4 (Hotfix: OnCreatePlayer Index & ClimateManager API Fix)
-- =============================================================================

VICCSSpores = VICCSSpores or {}
VICCSSpores.VERSION = "1.1.0"

-- Tamanho da celula da grade em tiles (4x4 tiles = 1 celula)
VICCSSpores.CELL = 4

-- Concentracao maxima possivel numa celula (0 a 100)
VICCSSpores.MAX_CONC = 100.0

-- Raio em tiles ao redor dos jogadores para simulacao ativa no servidor
VICCSSpores.ACTIVE_RADIUS_TILES = 60

-- Tabela de protecao de mascaras vanilla (fracao de 0.0 a 1.0 que o item bloqueia)
VICCSSpores.Protection = {
    ["Base.Hat_GasMask"]           = 0.95, -- Mascara de Gas Militar/Civil
    ["Base.Hat_BuildersRespirator"] = 0.75, -- Respirador com cartucho
    ["Base.Hat_DustMask"]          = 0.40, -- Mascara cirurgica / poeira
    ["Base.Hat_SurgicalMask"]      = 0.40, 
    ["Base.Hat_BandanaMask"]       = 0.15, -- Pano / Bandana amarrada
}

-- Valores padrao para injecao transparente em saves antigos
VICCSSpores.DEFAULTS = {
    Enabled = true,
    CarrierChance = 0.08,
    DoseThreshold = 120.0,
    DoseRecoveryPerMinute = 1.0,
    CorpseDecayDays = 5,
    DecontamBleachPower = 50.0,
    MaxActiveCells = 400,
    SimRadiusTiles = 60,
    ReduceVisualEffects = false,
}

-- Inicializacao automatica de SandboxVars para saves existentes
function VICCSSpores.initSandboxDefaults()
    if not SandboxVars then return end
    SandboxVars.VICCSSpores = SandboxVars.VICCSSpores or {}
    
    for key, defaultValue in pairs(VICCSSpores.DEFAULTS) do
        if SandboxVars.VICCSSpores[key] == nil then
            SandboxVars.VICCSSpores[key] = defaultValue
        end
    end
end

Events.OnInitGlobalModData.Add(VICCSSpores.initSandboxDefaults)
Events.OnGameStart.Add(VICCSSpores.initSandboxDefaults)

-- Funcao segura para ler configuracoes do SandboxVars com fallback duplo
function VICCSSpores.opt(name, fallback)
    if SandboxVars and SandboxVars.VICCSSpores and SandboxVars.VICCSSpores[name] ~= nil then
        return SandboxVars.VICCSSpores[name]
    end
    if VICCSSpores.DEFAULTS[name] ~= nil then
        return VICCSSpores.DEFAULTS[name]
    end
    return fallback
end

print("[VICCS Spores v" .. VICCSSpores.VERSION .. "] Config inicializado com sucesso.")
