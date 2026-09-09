-- =============================================================================
-- Project Zomboid TCG - Configuration & Language Manager (TCG_Config.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Gerencia as configuracoes do mod com suporte bilingue (Portugues PT-BR / Ingles EN).
--   - Salva em arquivo local 'TCG_Config.ini'
--   - Integra com ModOptions (se o jogador tiver instalado)
--   - Permite troca dinamica em tempo real via UI do Fichario
-- =============================================================================

TCG_Config = TCG_Config or {}

TCG_Config.CONFIG_FILE = "TCG_Config.ini"
TCG_Config.Language = "PT" -- Padrao inicial: Portugues do Brasil

--- Carrega a configuracao do disco
function TCG_Config.load()
    if not getFileReader then return end
    local reader = getFileReader(TCG_Config.CONFIG_FILE, true)
    if not reader then return end

    local line = reader:readLine()
    while line do
        line = line:match("^%s*(.-)%s*$") -- trim
        if line and line ~= "" and not line:match("^#") and not line:match("^%[") then
            local k, v = line:match("^([^=]+)=(.*)$")
            if k and v then
                k = k:match("^%s*(.-)%s*$")
                v = v:match("^%s*(.-)%s*$")
                if k == "Language" then
                    if v == "EN" or v == "PT" then
                        TCG_Config.Language = v
                    end
                end
            end
        end
        line = reader:readLine()
    end
    reader:close()
end

--- Salva a configuracao no disco
function TCG_Config.save()
    if not getFileWriter then return end
    local writer = getFileWriter(TCG_Config.CONFIG_FILE, true, false)
    if not writer then return end

    writer:writeln("# =============================================================================")
    writer:writeln("# VICCS TCG Configuration File")
    writer:writeln("# =============================================================================")
    writer:writeln("Language=" .. tostring(TCG_Config.Language))
    writer:close()
end

--- Retorna o idioma ativo ("PT" ou "EN")
function TCG_Config.getLanguage()
    return TCG_Config.Language or "PT"
end

--- Define o idioma ativo ("PT" ou "EN") e persiste no disco
function TCG_Config.setLanguage(lang)
    if lang == "EN" or lang == "PT" then
        TCG_Config.Language = lang
        TCG_Config.save()
    end
end

--- Alterna rapidamente entre PT e EN
function TCG_Config.toggleLanguage()
    if TCG_Config.Language == "PT" then
        TCG_Config.setLanguage("EN")
    else
        TCG_Config.setLanguage("PT")
    end
    return TCG_Config.Language
end

-- Inicializa ao carregar o arquivo
TCG_Config.load()

-- Integracao com ModOptions (se disponivel no jogo)
local function initModOptions()
    if ModOptions and ModOptions.getInstance then
        local opt = ModOptions:getInstance({
            name = "VICCS_TCG",
            title = "VICCS - Trading Card Game"
        })
        if opt then
            local langOptions = { "Portugues (Brasil)", "English (US)" }
            local defaultIdx = (TCG_Config.Language == "EN") and 2 or 1

            local dropdown = opt:addDropdown("TCG_Language", "Idioma das Cartas / Card Language", langOptions, defaultIdx, "Alterne entre nomes em Portugues e Ingles")
            dropdown.onChange = function(newVal)
                if newVal == 2 then
                    TCG_Config.setLanguage("EN")
                else
                    TCG_Config.setLanguage("PT")
                end
            end
        end
    end
end

--- Retorna o multiplicador de spawn com base nas SandboxVars (0.0x ate 4.0x)
function TCG_Config.getSpawnMultiplier()
    if SandboxVars and SandboxVars.VICCS_TCG and SandboxVars.VICCS_TCG.SpawnRate then
        local val = tonumber(SandboxVars.VICCS_TCG.SpawnRate) or 3
        if val == 1 then return 0.25 end
        if val == 2 then return 0.50 end
        if val == 3 then return 1.00 end
        if val == 4 then return 2.00 end
        if val == 5 then return 4.00 end
        if val == 6 then return 0.00 end
    end
    return 1.0
end

--- Verifica se o spawn em residencias esta habilitado
function TCG_Config.isResidentialAllowed()
    if SandboxVars and SandboxVars.VICCS_TCG and SandboxVars.VICCS_TCG.AllowResidential ~= nil then
        return SandboxVars.VICCS_TCG.AllowResidential == true
    end
    return true
end

--- Verifica se o spawn em escolas e quartos infantis esta habilitado
function TCG_Config.isSchoolAllowed()
    if SandboxVars and SandboxVars.VICCS_TCG and SandboxVars.VICCS_TCG.AllowSchool ~= nil then
        return SandboxVars.VICCS_TCG.AllowSchool == true
    end
    return true
end

--- Verifica se o spawn em lojas e livrarias esta habilitado
function TCG_Config.isCommercialAllowed()
    if SandboxVars and SandboxVars.VICCS_TCG and SandboxVars.VICCS_TCG.AllowCommercial ~= nil then
        return SandboxVars.VICCS_TCG.AllowCommercial == true
    end
    return true
end

--- Retorna a probabilidade percentual (0 a 100) de vir carta Holografica
function TCG_Config.getHoloChance()
    if SandboxVars and SandboxVars.VICCS_TCG and SandboxVars.VICCS_TCG.HoloChancePercent ~= nil then
        return tonumber(SandboxVars.VICCS_TCG.HoloChancePercent) or 33
    end
    return 33
end

Events.OnGameStart.Add(initModOptions)

