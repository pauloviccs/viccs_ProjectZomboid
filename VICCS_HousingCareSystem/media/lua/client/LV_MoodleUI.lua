-- =============================================================================
-- Housing Care System (Lar Vivo) - Native Right-Side Moodle Display (LV_MoodleUI.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Renderiza o Moodlet do Lar Vivo (Conforto ou Insalubridade) na coluna lateral
--   direita da tela, perfeitamente alinhado abaixo dos Moodlets vanilla do jogo.
--   Usa texturas PNG nativas com renderização em camada superior e tooltip oficial.
-- =============================================================================

LV_MoodleUI = ISUIElement:derive("LV_MoodleUI")

local MOODLE_SIZE = 32
local MOODLE_STEP = 38
local MARGIN_RIGHT = 12
local BASE_TOP = 65

--- Mapeamento de texturas exclusivas do mod (com caminhos em minúsculo e padrão)
local ICONS = {
    Comfort = {
        [1] = {"media/ui/moodles/lv_comfort_1.png", "media/ui/Moodles/LV_Comfort_1.png"},
        [2] = {"media/ui/moodles/lv_comfort_2.png", "media/ui/Moodles/LV_Comfort_2.png"},
        [3] = {"media/ui/moodles/lv_comfort_3.png", "media/ui/Moodles/LV_Comfort_3.png"},
        [4] = {"media/ui/moodles/lv_comfort_4.png", "media/ui/Moodles/LV_Comfort_4.png"},
    },
    Squalor = {
        [1] = {"media/ui/moodles/lv_squalor_1.png", "media/ui/Moodles/LV_Squalor_1.png"},
        [2] = {"media/ui/moodles/lv_squalor_2.png", "media/ui/Moodles/LV_Squalor_1.png"},
        [3] = {"media/ui/moodles/lv_squalor_3.png", "media/ui/Moodles/LV_Squalor_3.png"},
        [4] = {"media/ui/moodles/lv_squalor_4.png", "media/ui/Moodles/LV_Squalor_4.png"},
    }
}

--- Lista de moodlets vanilla conhecidos para cálculo exato de quantos estão na tela
local VANILLA_MOODLE_TYPES = {
    "Endurance", "Tired", "Hungry", "Panic", "Sick", "Bored", "Unhappy", "Bleeding",
    "Wet", "HasACold", "Injured", "Pain", "HeavyLoad", "Drunk", "Dead", "Zombie",
    "FoodEaten", "Hyperthermia", "Hypothermia", "Windchill", "Stress"
}

--- Obtém a textura de forma segura
local function fetchTexture(isComfort, tier)
    tier = math.max(1, math.min(4, tier or 1))
    local paths = isComfort and ICONS.Comfort[tier] or ICONS.Squalor[tier]
    if paths then
        for _, p in ipairs(paths) do
            local tex = getTexture(p)
            if tex then return tex end
        end
    end
    return nil
end

--- Conta quantos Moodles vanilla estão atualmente visíveis na tela
local function getActiveVanillaMoodlesCount(player)
    if not player then return 0 end
    local count = 0
    local moodles = player:getMoodles()
    if not moodles then return 0 end

    -- Método 1: Verificação direta por tipo de moodle vanilla
    for _, typeName in ipairs(VANILLA_MOODLE_TYPES) do
        if MoodleType and MoodleType[typeName] then
            pcall(function()
                local lvl = moodles:getMoodleLevel(MoodleType[typeName])
                if lvl and lvl > 0 then
                    count = count + 1
                end
            end)
        end
    end

    -- Se não conseguiu ler via MoodleType, tenta método alternativo do container
    if count == 0 and moodles.getNumMoodles then
        pcall(function()
            local total = moodles:getNumMoodles()
            for i = 0, total - 1 do
                if moodles:getMoodleLevel(i) > 0 then
                    count = count + 1
                end
            end
        end)
    end

    return count
end

function LV_MoodleUI:new()
    local o = ISUIElement:new(0, 0, MOODLE_SIZE, MOODLE_SIZE)
    setmetatable(o, self)
    self.__index = self
    o.visible = true
    o.alwaysOnTop = true
    return o
end

function LV_MoodleUI:prerender()
    -- Renderização completa tratada no render()
end

function LV_MoodleUI:render()
    if not LV_Config or not LV_Config.isEnabled() then return end
    local player = getPlayer()
    if not player then return end

    if not LV_BuffManager or not LV_BuffManager.getPlayerData then return end
    local data = LV_BuffManager.getPlayerData(player)
    if not data then return end

    local comfortTier = data.comfortTier or 0
    local squalorTier = data.squalorTier or 0

    -- Se não tem bônus de conforto nem debuff de sujeira ativo, não desenha
    if comfortTier <= 0 and squalorTier <= 0 then
        return
    end

    local isComfort = comfortTier > 0
    local tier = isComfort and comfortTier or squalorTier

    -- 1. Calcula a posição exata na coluna da direita abaixo dos moodlets vanilla
    local screenW = getCore():getScreenWidth()
    local vanillaCount = getActiveVanillaMoodlesCount(player)
    local targetX = screenW - MOODLE_SIZE - MARGIN_RIGHT
    local targetY = BASE_TOP + (vanillaCount * MOODLE_STEP)

    self:setX(targetX)
    self:setY(targetY)
    self:setWidth(MOODLE_SIZE)
    self:setHeight(MOODLE_SIZE)

    -- 2. Busca e desenha a textura PNG do Moodlet
    local texture = fetchTexture(isComfort, tier)

    if texture then
        self:drawTextureScaled(texture, 0, 0, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
    else
        -- Fallback gráfico circular impecável
        local bgR = isComfort and 0.12 or 0.75
        local bgG = isComfort and 0.80 or 0.18
        local bgB = isComfort and 0.35 or 0.18
        self:drawRect(0, 0, MOODLE_SIZE, MOODLE_SIZE, 0.95, bgR, bgG, bgB)
        self:drawRectBorder(0, 0, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
        self:drawText(tostring(tier), 12, 8, 1, 1, 1, 1.0, UIFont.Medium)
    end

    -- 3. Tooltip ao passar o mouse por cima
    local mouseX = getMouseX()
    local mouseY = getMouseY()

    if mouseX >= targetX and mouseX <= (targetX + MOODLE_SIZE) and
       mouseY >= targetY and mouseY <= (targetY + MOODLE_SIZE) then
        self:renderTooltip(player, data, isComfort, tier)
    end
end

--- Renderiza o Tooltip vanilla do Moodlet
function LV_MoodleUI:renderTooltip(player, data, isComfort, tier)
    local title = ""
    local desc = ""
    local timeStr = ""

    local currentHour = getGameTime():getWorldAgeHours()
    local expHour = isComfort and data.comfortExpiryWorldHour or data.squalorExpiryWorldHour
    local remaining = math.max(0, expHour - currentHour)
    local baseName = (data.baseName and data.baseName ~= "" and data.baseName ~= "Lar") and data.baseName or nil

    if isComfort then
        local keyTitle = "UI_LV_Tier" .. tier .. "_Title"
        local keyDesc = "UI_LV_Tier" .. tier .. "_Desc"
        title = LV_MoodleDefs and LV_MoodleDefs.getText(keyTitle, "Aconchego do Lar (Tier " .. tier .. ")") or ("Aconchego (Tier " .. tier .. ")")
        if baseName then title = baseName .. " — " .. title end
        desc = LV_MoodleDefs and LV_MoodleDefs.getText(keyDesc, "Reduz o panico e estresse, regenera vigor.") or "Corpo protegido e revigorado pelo aconchego do lar."
        timeStr = string.format("Duracao restante: %.1fh (In-Game)", remaining)
    else
        local keyTitle = "UI_LV_Squalor" .. tier .. "_Title"
        local keyDesc = "UI_LV_Squalor" .. tier .. "_Desc"
        title = LV_MoodleDefs and LV_MoodleDefs.getText(keyTitle, "Ambiente Insalubre (Nivel " .. tier .. ")") or ("Insalubridade (" .. tier .. ")")
        if baseName then title = baseName .. " — " .. title end
        desc = LV_MoodleDefs and LV_MoodleDefs.getText(keyDesc, "Gera desconforto, nauseas e infelicidade.") or "Penalidade por sujeira e podridao."
        timeStr = string.format("Efeito ativo: %.1fh", remaining)
    end

    local fontTitle = UIFont.Small
    local fontDesc = UIFont.Small
    local titleW = getTextManager():MeasureStringX(fontTitle, title)
    local descW = getTextManager():MeasureStringX(fontDesc, desc)
    local timeW = getTextManager():MeasureStringX(fontDesc, timeStr)

    local boxW = math.max(titleW, math.max(descW, timeW)) + 24
    local boxH = 65
    local boxX = self:getX() - boxW - 8
    local boxY = self:getY()

    -- Fundo preto clássico vanilla
    self:drawRect(boxX - self:getX(), boxY - self:getY(), boxW, boxH, 0.92, 0.08, 0.08, 0.08)
    self:drawRectBorder(boxX - self:getX(), boxY - self:getY(), boxW, boxH, 0.9, 0.7, 0.7, 0.7)

    -- Textos
    local textR = isComfort and 0.4 or 0.95
    local textG = isComfort and 1.0 or 0.35
    local textB = isComfort and 0.5 or 0.35

    self:drawText(title, (boxX - self:getX()) + 10, (boxY - self:getY()) + 8, textR, textG, textB, 1.0, fontTitle)
    self:drawText(desc, (boxX - self:getX()) + 10, (boxY - self:getY()) + 26, 0.85, 0.85, 0.85, 1.0, fontDesc)
    self:drawText(timeStr, (boxX - self:getX()) + 10, (boxY - self:getY()) + 44, 0.65, 0.85, 0.65, 1.0, fontDesc)
end

--- Inicialização automática e garantida do Moodlet
local moodleInstance = nil
local function initMoodleUI()
    if not moodleInstance then
        moodleInstance = LV_MoodleUI:new()
        moodleInstance:initialise()
        moodleInstance:instantiate()
        moodleInstance:addToUIManager()
        moodleInstance:setAlwaysOnTop(true)
        print("[LarVivo] LV_MoodleUI inicializado com sucesso e posicionado na coluna direita!")
    end
end

Events.OnGameStart.Add(initMoodleUI)
Events.OnCreatePlayer.Add(initMoodleUI)
