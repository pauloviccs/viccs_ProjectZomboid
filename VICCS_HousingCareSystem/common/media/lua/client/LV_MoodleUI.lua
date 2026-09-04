-- =============================================================================
-- Housing Care System (Lar Vivo) - Native Right-Side Moodle Display (LV_MoodleUI.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Renderiza os Moodlets do Lar Vivo (Conforto, Insalubridade, Necessidade
--   de Banheiro e Aliviado) na coluna lateral direita da tela, perfeitamente
--   alinhados abaixo dos Moodlets vanilla do jogo.
-- =============================================================================

require "LV_Config"
require "LV_MoodleDefs"
require "LV_BladderNeed"

LV_MoodleUI = ISUIElement:derive("LV_MoodleUI")

local MOODLE_SIZE = 32
local MOODLE_STEP = 38
local MARGIN_RIGHT = 12
local BASE_TOP = 65

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

local VANILLA_MOODLE_TYPES = {
    "Endurance", "Tired", "Hungry", "Panic", "Sick", "Bored", "Unhappy", "Bleeding",
    "Wet", "HasACold", "Injured", "Pain", "HeavyLoad", "Drunk", "Dead", "Zombie",
    "FoodEaten", "Hyperthermia", "Hypothermia", "Windchill", "Stress"
}

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

local cachedVanillaCount = 0
local lastVanillaCheckTime = 0

local function getActiveVanillaMoodlesCount(player)
    if not player then return 0 end
    local now = (getTimeInMillis and getTimeInMillis() / 1000.0) or (getGameTime():getWorldAgeHours() * 3600.0)
    if (now - lastVanillaCheckTime) < 0.2 then
        return cachedVanillaCount
    end
    lastVanillaCheckTime = now

    local moodles = player:getMoodles()
    if not moodles or not MoodleType then return cachedVanillaCount end

    local count = 0
    for i = 1, #VANILLA_MOODLE_TYPES do
        local mt = MoodleType[VANILLA_MOODLE_TYPES[i]]
        if mt then
            local lvl = moodles:getMoodleLevel(mt)
            if lvl and lvl > 0 then
                count = count + 1
            end
        end
    end
    cachedVanillaCount = count
    return count
end

function LV_MoodleUI:new()
    local o = ISUIElement:new(0, 0, MOODLE_SIZE, MOODLE_SIZE * 3)
    setmetatable(o, self)
    self.__index = self
    o.visible = true
    o.alwaysOnTop = true
    return o
end

function LV_MoodleUI:prerender()
    -- Renderização tratada no render()
end

function LV_MoodleUI:render()
    if not LV_Config or not LV_Config.isEnabled() then return end
    local player = getPlayer()
    if not player or player:isDead() then return end

    local data = LV_BuffManager and LV_BuffManager.getPlayerData and LV_BuffManager.getPlayerData(player)
    if not data then return end

    -- 1. Coleta a lista de moodlets ativos para renderizar
    local activeMoodles = {}

    local comfortTier = data.comfortTier or 0
    local squalorTier = data.squalorTier or 0
    if comfortTier > 0 then
        table.insert(activeMoodles, {
            kind = "comfort",
            tier = comfortTier,
            data = data,
        })
    elseif squalorTier > 0 then
        table.insert(activeMoodles, {
            kind = "squalor",
            tier = squalorTier,
            data = data,
        })
    end

    local toiletTier = (LV_BladderNeed and LV_BladderNeed.getTier and LV_BladderNeed.getTier(player)) or 0
    if toiletTier > 0 then
        table.insert(activeMoodles, {
            kind = "toilet",
            tier = toiletTier,
            need = LV_BladderNeed.getNeed(player),
        })
    elseif LV_BladderNeed and LV_BladderNeed.isRelievedActive and LV_BladderNeed.isRelievedActive(player) then
        table.insert(activeMoodles, {
            kind = "relieved",
        })
    end

    -- Novos Moodlets de Rotina, Hábitos e Produtividade (Update 2)
    local routineData = LV_RoutineSystem and LV_RoutineSystem.getRoutineData and LV_RoutineSystem.getRoutineData(player)
    local currentHour = getGameTime():getWorldAgeHours()

    if routineData then
        if routineData.morningCozyExpiryHour and currentHour < routineData.morningCozyExpiryHour then
            table.insert(activeMoodles, {
                kind = "morningCozy",
                remaining = math.max(0, routineData.morningCozyExpiryHour - currentHour),
            })
        end

        if routineData.streakActive and routineData.streakDays and routineData.streakDays >= 3 then
            table.insert(activeMoodles, {
                kind = "routineStreak",
                days = routineData.streakDays,
            })
        end

        if routineData.spotlessActive then
            table.insert(activeMoodles, {
                kind = "spotlessHome",
            })
        end
    end

    if #activeMoodles == 0 then return end

    local screenW = getCore():getScreenWidth()
    local vanillaCount = getActiveVanillaMoodlesCount(player)
    local targetX = screenW - MOODLE_SIZE - MARGIN_RIGHT
    local startY = BASE_TOP + (vanillaCount * MOODLE_STEP)

    self:setX(targetX)
    self:setY(startY)
    self:setWidth(MOODLE_SIZE)
    self:setHeight(#activeMoodles * MOODLE_STEP)

    local mouseX = getMouseX()
    local mouseY = getMouseY()

    for idx, item in ipairs(activeMoodles) do
        local relY = (idx - 1) * MOODLE_STEP

        if item.kind == "comfort" or item.kind == "squalor" then
            local isComfort = (item.kind == "comfort")
            local tex = fetchTexture(isComfort, item.tier)
            if tex then
                self:drawTextureScaled(tex, 0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            else
                local bgR = isComfort and 0.12 or 0.75
                local bgG = isComfort and 0.80 or 0.18
                local bgB = isComfort and 0.35 or 0.18
                self:drawRect(0, relY, MOODLE_SIZE, MOODLE_SIZE, 0.95, bgR, bgG, bgB)
                self:drawRectBorder(0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
                self:drawText(tostring(item.tier), 12, relY + 8, 1, 1, 1, 1.0, UIFont.Medium)
            end

            -- Tooltip
            if mouseX >= targetX and mouseX <= (targetX + MOODLE_SIZE) and
               mouseY >= (startY + relY) and mouseY <= (startY + relY + MOODLE_SIZE) then
                self:renderBaseTooltip(player, item.data, isComfort, item.tier, relY)
            end

        elseif item.kind == "toilet" then
            local def = LV_MoodleDefs.NeedToiletTiers[item.tier]
            local tex = def and def.vanillaIcon and getTexture(def.vanillaIcon)
            if tex then
                self:drawTextureScaled(tex, 0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            else
                local c = (def and def.color) or {r=0.9, g=0.3, b=0.2}
                self:drawRect(0, relY, MOODLE_SIZE, MOODLE_SIZE, 0.92, c.r, c.g, c.b)
                self:drawRectBorder(0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            end

            -- Tooltip
            if mouseX >= targetX and mouseX <= (targetX + MOODLE_SIZE) and
               mouseY >= (startY + relY) and mouseY <= (startY + relY + MOODLE_SIZE) then
                self:renderToiletTooltip(def, item.need, relY)
            end

        elseif item.kind == "relieved" then
            local def = LV_MoodleDefs.Relieved
            local tex = def and def.vanillaIcon and getTexture(def.vanillaIcon)
            if tex then
                self:drawTextureScaled(tex, 0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            else
                self:drawRect(0, relY, MOODLE_SIZE, MOODLE_SIZE, 0.92, 0.3, 0.85, 0.5)
                self:drawRectBorder(0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            end

            -- Tooltip
            if mouseX >= targetX and mouseX <= (targetX + MOODLE_SIZE) and
               mouseY >= (startY + relY) and mouseY <= (startY + relY + MOODLE_SIZE) then
                self:renderRelievedTooltip(def, relY)
            end

        elseif item.kind == "morningCozy" then
            local def = LV_MoodleDefs.MorningCozy
            local tex = def and def.vanillaIcon and getTexture(def.vanillaIcon)
            if tex then
                self:drawTextureScaled(tex, 0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            else
                self:drawRect(0, relY, MOODLE_SIZE, MOODLE_SIZE, 0.92, 0.95, 0.75, 0.3)
                self:drawRectBorder(0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            end
            if mouseX >= targetX and mouseX <= (targetX + MOODLE_SIZE) and
               mouseY >= (startY + relY) and mouseY <= (startY + relY + MOODLE_SIZE) then
                local timeStr = string.format("Duracao restante: %.1fh", item.remaining or 0)
                self:drawTooltipBox(def.defaultTitle, def.defaultDesc, timeStr, {0.95, 0.75, 0.3}, relY)
            end

        elseif item.kind == "routineStreak" then
            local def = LV_MoodleDefs.RoutineStreak
            local tex = def and def.vanillaIcon and getTexture(def.vanillaIcon)
            if tex then
                self:drawTextureScaled(tex, 0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            else
                self:drawRect(0, relY, MOODLE_SIZE, MOODLE_SIZE, 0.92, 0.2, 0.9, 0.75)
                self:drawRectBorder(0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            end
            if mouseX >= targetX and mouseX <= (targetX + MOODLE_SIZE) and
               mouseY >= (startY + relY) and mouseY <= (startY + relY + MOODLE_SIZE) then
                local streakStr = string.format("Streak Ativo: %d dias consecutivos", item.days or 3)
                self:drawTooltipBox(def.defaultTitle, def.defaultDesc, streakStr, {0.2, 0.9, 0.75}, relY)
            end

        elseif item.kind == "spotlessHome" then
            local def = LV_MoodleDefs.SpotlessHome
            local tex = def and def.vanillaIcon and getTexture(def.vanillaIcon)
            if tex then
                self:drawTextureScaled(tex, 0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            else
                self:drawRect(0, relY, MOODLE_SIZE, MOODLE_SIZE, 0.92, 0.3, 0.85, 0.95)
                self:drawRectBorder(0, relY, MOODLE_SIZE, MOODLE_SIZE, 1.0, 1, 1, 1)
            end
            if mouseX >= targetX and mouseX <= (targetX + MOODLE_SIZE) and
               mouseY >= (startY + relY) and mouseY <= (startY + relY + MOODLE_SIZE) then
                self:drawTooltipBox(def.defaultTitle, def.defaultDesc, "Ambiente focado (XP de estudo acelerado)", {0.3, 0.85, 0.95}, relY)
            end
        end
    end
end

function LV_MoodleUI:renderBaseTooltip(player, data, isComfort, tier, relY)
    local currentHour = getGameTime():getWorldAgeHours()
    local expHour = isComfort and data.comfortExpiryWorldHour or data.squalorExpiryWorldHour
    local remaining = math.max(0, expHour - currentHour)
    local baseName = (data.baseName and data.baseName ~= "" and data.baseName ~= "Lar") and data.baseName or nil

    local title, desc
    if isComfort then
        local def = LV_MoodleDefs.ComfortTiers and LV_MoodleDefs.ComfortTiers[tier]
        local keyTitle = "UI_LV_Tier" .. tier .. "_Title"
        local keyDesc = "UI_LV_Tier" .. tier .. "_Desc"
        title = LV_MoodleDefs.getText(keyTitle, (def and def.defaultTitle) or ("Aconchego do Lar (Tier " .. tier .. ")"))
        if baseName then title = baseName .. " - " .. title end
        desc = LV_MoodleDefs.getText(keyDesc, (def and def.defaultDesc) or "Reduz o panico e estresse, regenera vigor.")
    else
        local def = LV_MoodleDefs.SqualorTiers and LV_MoodleDefs.SqualorTiers[tier]
        local keyTitle = "UI_LV_Squalor" .. tier .. "_Title"
        local keyDesc = "UI_LV_Squalor" .. tier .. "_Desc"
        title = LV_MoodleDefs.getText(keyTitle, (def and def.defaultTitle) or ("Ambiente Insalubre (Nivel " .. tier .. ")"))
        if baseName then title = baseName .. " - " .. title end
        desc = LV_MoodleDefs.getText(keyDesc, (def and def.defaultDesc) or "Gera desconforto, nauseas e infelicidade.")
    end
    local timeStr = string.format("Duracao restante: %.1fh (In-Game)", remaining)

    self:drawTooltipBox(title, desc, timeStr, isComfort and {0.4, 1.0, 0.5} or {0.95, 0.4, 0.3}, relY)
end

function LV_MoodleUI:renderToiletTooltip(def, need, relY)
    local title = def and def.defaultTitle or "Necessidade de Banheiro"
    local desc = def and def.defaultDesc or "Seu corpo precisa de alivio sanitario."
    local valStr = string.format("Intensidade do Aperto: %d%%", math.floor(need or 0))
    self:drawTooltipBox(title, desc, valStr, {0.95, 0.75, 0.25}, relY)
end

function LV_MoodleUI:renderRelievedTooltip(def, relY)
    local title = def and def.defaultTitle or "Aliviado"
    local desc = def and def.defaultDesc or "Sensacao de bem-estar apos usar um banheiro higienizado."
    local valStr = "Estresse e tedio aliviados."
    self:drawTooltipBox(title, desc, valStr, {0.35, 0.90, 0.55}, relY)
end

function LV_MoodleUI:drawTooltipBox(title, desc, footer, titleColor, relY)
    local font = UIFont.Small
    local tm = getTextManager()
    local titleW = tm:MeasureStringX(font, title)
    local descW = tm:MeasureStringX(font, desc)
    local footerW = tm:MeasureStringX(font, footer)

    local boxW = math.max(titleW, math.max(descW, footerW)) + 24
    local boxH = 65
    local boxX = -boxW - 8
    local boxY = relY

    self:drawRect(boxX, boxY, boxW, boxH, 0.92, 0.08, 0.08, 0.08)
    self:drawRectBorder(boxX, boxY, boxW, boxH, 0.90, 0.7, 0.7, 0.7)

    self:drawText(title, boxX + 10, boxY + 8, titleColor[1], titleColor[2], titleColor[3], 1.0, font)
    self:drawText(desc, boxX + 10, boxY + 26, 0.85, 0.85, 0.85, 1.0, font)
    self:drawText(footer, boxX + 10, boxY + 44, 0.65, 0.85, 0.65, 1.0, font)
end

local moodleInstance = nil
local function initMoodleUI()
    if not moodleInstance then
        moodleInstance = LV_MoodleUI:new()
        moodleInstance:initialise()
        moodleInstance:instantiate()
        moodleInstance:addToUIManager()
        moodleInstance:setAlwaysOnTop(true)
        print("[LarVivo] LV_MoodleUI multi-moodle inicializado com sucesso!")
    end
end

Events.OnGameStart.Add(initMoodleUI)
Events.OnCreatePlayer.Add(initMoodleUI)
