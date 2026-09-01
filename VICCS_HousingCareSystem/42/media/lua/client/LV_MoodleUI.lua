-- =============================================================================
-- Housing Care System (Lar Vivo) - Native Right-Side Moodle Display (LV_MoodleUI.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Renderiza o Moodle do Lar Vivo (Conforto ou Insalubridade) na coluna lateral
--   direita da tela, exatamente no mesmo formato, posição e estilo dos Moodlets
--   vanilla do Project Zomboid, utilizando os ícones PNG próprios do mod.
-- =============================================================================

LV_MoodleUI = ISUIElement:derive("LV_MoodleUI")

local MOODLE_SIZE = 32
local MOODLE_STEP = 36
local MARGIN_RIGHT = 10
local START_TOP = 65

--- Mapeamento de texturas exclusivas do mod
local MOD_ICONS = {
    Comfort = {
        [1] = "media/ui/Moodles/LV_Comfort_1.png",
        [2] = "media/ui/Moodles/LV_Comfort_2.png",
        [3] = "media/ui/Moodles/LV_Comfort_3.png",
        [4] = "media/ui/Moodles/LV_Comfort_4.png",
    },
    Squalor = {
        [1] = "media/ui/Moodles/LV_Squalor_1.png",
        [2] = "media/ui/Moodles/LV_Squalor_2.png",
        [3] = "media/ui/Moodles/LV_Squalor_3.png",
        [4] = "media/ui/Moodles/LV_Squalor_4.png",
    }
}

function LV_MoodleUI:new()
    local o = ISUIElement:new(0, 0, MOODLE_SIZE, MOODLE_SIZE)
    setmetatable(o, self)
    self.__index = self
    o.visible = false
    o.currentTier = 0
    o.isComfort = true
    return o
end

--- Conta quantos Moodles vanilla estão atualmente ativos para empilhar logo abaixo
local function getActiveVanillaMoodlesCount(player)
    if not player then return 0 end
    local count = 0
    local moodles = player:getMoodles()
    if moodles and moodles.getNumMoodles then
        local maxMoodles = moodles:getNumMoodles()
        for i = 0, maxMoodles - 1 do
            if moodles:getMoodleLevel(i) > 0 then
                count = count + 1
            end
        end
    end
    return count
end

function LV_MoodleUI:prerender()
    -- Toda renderização ocorre no render()
end

function LV_MoodleUI:render()
    if not LV_Config or not LV_Config.isEnabled() then return end
    local player = getPlayer()
    if not player then return end

    local data = LV_BuffManager.getPlayerData(player)
    if not data then return end

    local comfortTier = data.comfortTier or 0
    local squalorTier = data.squalorTier or 0

    if comfortTier <= 0 and squalorTier <= 0 then
        self:setVisible(false)
        return
    end

    self:setVisible(true)

    local isComfort = comfortTier > 0
    local tier = isComfort and comfortTier or squalorTier
    self.isComfort = isComfort
    self.currentTier = tier

    -- 1. Calcula a posição exata na coluna da direita
    local screenW = getCore():getScreenWidth()
    local vanillaCount = getActiveVanillaMoodlesCount(player)
    local targetX = screenW - MOODLE_SIZE - MARGIN_RIGHT
    local targetY = START_TOP + (vanillaCount * MOODLE_STEP)

    self:setX(targetX)
    self:setY(targetY)
    self:setWidth(MOODLE_SIZE)
    self:setHeight(MOODLE_SIZE)

    -- 2. Carrega a textura PNG do Moodle
    local iconPath = isComfort and (MOD_ICONS.Comfort[tier] or MOD_ICONS.Comfort[1])
                                or (MOD_ICONS.Squalor[tier] or MOD_ICONS.Squalor[1])

    local texture = getTexture(iconPath)

    -- 3. Desenha a textura do Moodle
    if texture then
        self:drawTextureScaled(texture, 0, 0, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
    else
        -- Fallback de desenho vetorial caso a textura ainda esteja carregando
        local bgR = isComfort and 0.15 or 0.70
        local bgG = isComfort and 0.75 or 0.15
        local bgB = isComfort and 0.35 or 0.15
        self:drawRect(0, 0, MOODLE_SIZE, MOODLE_SIZE, 0.90, bgR, bgG, bgB)
        self:drawRectBorder(0, 0, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
    end

    -- 4. Tooltip ao passar o mouse por cima
    local mouseX = getMouseX()
    local mouseY = getMouseY()

    if mouseX >= targetX and mouseX <= (targetX + MOODLE_SIZE) and
       mouseY >= targetY and mouseY <= (targetY + MOODLE_SIZE) then
        self:renderTooltip(player, data, isComfort, tier)
    end
end

--- Renderiza o tooltip oficial idêntico ao dos Moodlets vanilla
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
        title = LV_MoodleDefs.getText(keyTitle, "Aconchego do Lar (Tier " .. tier .. ")")
        if baseName then title = baseName .. " — " .. title end
        desc = LV_MoodleDefs.getText(keyDesc, "Reduz o panico e estresse, regenera vigor.")
        timeStr = string.format("Duracao restante: %.1fh", remaining)
    else
        local keyTitle = "UI_LV_Squalor" .. tier .. "_Title"
        local keyDesc = "UI_LV_Squalor" .. tier .. "_Desc"
        title = LV_MoodleDefs.getText(keyTitle, "Ambiente Insalubre (Nivel " .. tier .. ")")
        if baseName then title = baseName .. " — " .. title end
        desc = LV_MoodleDefs.getText(keyDesc, "Gera desconforto, nauseas e infelicidade.")
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

    -- Fundo preto vanilla com borda
    self:drawRect(boxX - self:getX(), boxY - self:getY(), boxW, boxH, 0.92, 0.08, 0.08, 0.08)
    self:drawRectBorder(boxX - self:getX(), boxY - self:getY(), boxW, boxH, 0.9, 0.7, 0.7, 0.7)

    -- Textos do Tooltip
    local textR = isComfort and 0.4 or 0.9
    local textG = isComfort and 1.0 or 0.3
    local textB = isComfort and 0.5 or 0.3

    self:drawText(title, (boxX - self:getX()) + 10, (boxY - self:getY()) + 8, textR, textG, textB, 1.0, fontTitle)
    self:drawText(desc, (boxX - self:getX()) + 10, (boxY - self:getY()) + 26, 0.85, 0.85, 0.85, 1.0, fontDesc)
    self:drawText(timeStr, (boxX - self:getX()) + 10, (boxY - self:getY()) + 44, 0.65, 0.75, 0.65, 1.0, fontDesc)
end

--- Inicializador do elemento no HUD
local moodleInstance = nil
local function initMoodleUI()
    if not moodleInstance then
        moodleInstance = LV_MoodleUI:new()
        moodleInstance:initialise()
        moodleInstance:instantiate()
        moodleInstance:addToUIManager()
        print("[LarVivo] LV_MoodleUI inicializado na coluna lateral direita com texturas customizadas!")
    end
end

Events.OnGameStart.Add(initMoodleUI)
Events.OnCreatePlayer.Add(function() initMoodleUI() end)
