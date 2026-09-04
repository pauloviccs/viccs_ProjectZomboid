-- =============================================================================
-- Housing Care System (Living House) - Infrastructure Dashboard (LV_HouseDashboard.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Painel de gerenciamento de infraestrutura da base no padrão Frameless Glass:
--   - Telemetria de Geradores elétricos (Combustível %, Condição %, Status Ativo)
--   - Gestão Hídrica de Barris de Chuva (Volume total em Litros e Capacidade)
--   - Governança da Base (Conforto, Insalubridade, Streaks e Bônus de Companhia)
--   - Tecla de atalho dedicada 'J' e botão rápido '[INFRA]' na HUD flutuante
--   - Varredura sob demanda com cache inteligente para zero impacto no FPS
-- =============================================================================

require "ISUI/ISPanel"
require "LV_Config"
require "LV_ComfortScanner"
require "LV_BuffManager"
require "LV_RoutineSystem"

LV_HouseDashboard = ISPanel:derive("LV_HouseDashboard")

local instance = nil

local FONT_S = UIFont.Small
local FONT_M = UIFont.Medium
local PAD = 10
local ACCENT_CYAN = {0.36, 0.76, 0.86}
local ACCENT_AMBER = {0.92, 0.71, 0.29}
local ACCENT_GREEN = {0.30, 0.85, 0.50}
local ACCENT_RED = {0.95, 0.25, 0.25}

--- Cria uma nova instância da janela de Dashboard de Infraestrutura
function LV_HouseDashboard:new(x, y, width, height)
    local tm = getTextManager()
    local hgt = tm:getFontHeight(FONT_S)
    local w = width or 370
    local h = height or 330

    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.fontH = hgt
    o.moveWithMouse = true
    o.userHidden = true -- Inicia fechado até o jogador pressionar 'J' ou clicar na HUD
    o.downX, o.downY = -1, -1
    o.isDragging = false

    -- Cache de telemetria (atualiza a cada 5 segundos quando aberto)
    o.lastScanTime = 0
    o.cachedData = nil

    return o
end

--- Retorna a instância única do Dashboard (Singleton)
function LV_HouseDashboard.getInstance()
    if not instance then
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        local w = 370
        local h = 330
        local x = math.floor((screenW - w) / 2)
        local y = math.floor((screenH - h) / 2)

        instance = LV_HouseDashboard:new(x, y, w, h)
        instance:initialise()
        instance:instantiate()
        instance:addToUIManager()
        instance:setVisible(false)
    end
    return instance
end

--- Alterna a visibilidade do painel (Toggle)
function LV_HouseDashboard.toggle()
    local dash = LV_HouseDashboard.getInstance()
    if dash then
        local isVis = dash:getIsVisible()
        dash:setVisible(not isVis)
        if not isVis then
            dash:refreshData(true)
        end
    end
end

function LV_HouseDashboard:onMouseDown(x, y)
    self.downX = x
    self.downY = y
    self.isDragging = true
    return true
end

function LV_HouseDashboard:onMouseUp(x, y)
    if self.isDragging and math.abs(x - self.downX) <= 4 and math.abs(y - self.downY) <= 4 then
        -- Clique no botão de fechar [X] no canto superior direito
        if x >= (self.width - 28) and y <= 24 then
            self:setVisible(false)
            return true
        end

        -- Clique no botão [CÔMODO (K)] abre o painel de inspeção
        if x >= (self.width - 125) and x <= (self.width - 32) and y <= 24 then
            if LV_RoomInspectorDashboard and LV_RoomInspectorDashboard.toggle then
                self:setVisible(false)
                LV_RoomInspectorDashboard.toggle()
                return true
            end
        end
    end
    self.isDragging = false
    return true
end

function LV_HouseDashboard:onMouseMove(dx, dy)
    if self.isDragging then
        local newX = self:getX() + dx
        local newY = self:getY() + dy
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        newX = math.max(0, math.min(screenW - self.width, newX))
        newY = math.max(0, math.min(screenH - self.height, newY))
        self:setX(newX)
        self:setY(newY)
    end
end

function LV_HouseDashboard:onMouseUpOutside(x, y)
    self.isDragging = false
    return true
end

--- Varre o perímetro da base em busca de geradores e coletores de chuva (com cache)
function LV_HouseDashboard:refreshData(force)
    local now = (getTimeInMillis and getTimeInMillis() / 1000.0) or (os.time())
    if not force and (now - self.lastScanTime) < 5.0 and self.cachedData then
        return self.cachedData
    end
    self.lastScanTime = now

    local player = getPlayer()
    local res = {
        hasGenerator = false,
        generatorCount = 0,
        fuel = 0.0,
        condition = 0,
        isActivated = false,
        isConnected = false,
        waterTotal = 0.0,
        waterMax = 0.0,
        barrelCount = 0,
        survivorCount = 1,
        safehouseName = "Refugio Pessoal",
        comfortTier = 0,
        comfortScore = 0,
        squalorScore = 0,
        streakDays = 0,
        isSpotless = false,
        seasonalNote = "Clima Estavel",
    }

    if not player or player:isDead() then
        self.cachedData = res
        return res
    end

    local pSq = player:getCurrentSquare()
    local cell = getCell()

    -- 1. Dados Básicos da Safehouse / Cômodo
    local buffData = LV_BuffManager and LV_BuffManager.getPlayerData and LV_BuffManager.getPlayerData(player)
    if buffData then
        res.comfortTier = buffData.comfortTier or 0
        res.comfortScore = buffData.comfortScore or 0
        res.squalorScore = buffData.squalorScore or 0
        res.seasonalNote = buffData.seasonalNote or "Clima Estavel"
        if buffData.baseName and buffData.baseName ~= "" and buffData.baseName ~= "Lar" then
            res.safehouseName = buffData.baseName
        end
    end

    local routineData = LV_RoutineSystem and LV_RoutineSystem.getRoutineData and LV_RoutineSystem.getRoutineData(player)
    if routineData then
        res.streakDays = routineData.streakDays or 0
        res.isSpotless = routineData.spotlessActive or false
    end

    -- 2. Limites do Perímetro para Varredura (Raio de 20 tiles ao redor do jogador/Safehouse)
    local minX, maxX, minY, maxY = 0, 0, 0, 0
    if pSq then
        local px, py = pSq:getX(), pSq:getY()
        local r = 20
        minX, maxX, minY, maxY = px - r, px + r, py - r, py + r

        local shClass = SafeHouse or Safehouse
        if shClass and shClass.getSafehouse then
            local ok, sh = pcall(shClass.getSafehouse, pSq)
            if ok and sh and sh.getX and sh.getY and sh.getW and sh.getH then
                minX = math.min(minX, sh:getX() - 6)
                maxX = math.max(maxX, sh:getX() + sh:getW() + 6)
                minY = math.min(minY, sh:getY() - 6)
                maxY = math.max(maxY, sh:getY() + sh:getH() + 6)
                if sh.getTitle and sh:getTitle() and sh:getTitle() ~= "" then
                    res.safehouseName = sh:getTitle()
                end
            end
        end
    end

    -- 3. Varredura Segura de Geradores (IsoGenerator)
    if cell and pSq then
        local step = 1
        if (maxX - minX) > 40 or (maxY - minY) > 40 then
            step = 2 -- Amostragem rápida em mansões gigantescas
        end

        for x = minX, maxX, step do
            for y = minY, maxY, step do
                local sq = cell:getGridSquare(x, y, 0)
                if sq then
                    local objs = sq:getObjects()
                    if objs and objs.size then
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            if obj and (instanceof(obj, "IsoGenerator") or (obj.getObjectName and obj:getObjectName() == "IsoGenerator")) then
                                res.hasGenerator = true
                                res.generatorCount = res.generatorCount + 1
                                local f = (obj.getFuel and obj:getFuel()) or 0
                                local c = (obj.getCondition and obj:getCondition()) or 0
                                res.fuel = math.max(res.fuel, f)
                                res.condition = math.max(res.condition, c)
                                if obj.isActivated and obj:isActivated() then
                                    res.isActivated = true
                                end
                                if obj.isConnected and obj:isConnected() then
                                    res.isConnected = true
                                end
                            end
                        end
                    end
                end
            end
            if res.generatorCount >= 4 then break end
        end
    end

    -- 4. Varredura Instantânea de Barris de Chuva via CGlobalObjects
    if CGlobalObjects then
        local ok, sys = pcall(CGlobalObjects.getSystemByName, "rainbarrel")
        if ok and sys and sys.getLuaObjectCount then
            local count = sys:getLuaObjectCount() or 0
            for i = 0, count - 1 do
                local luaObj = sys:getLuaObjectByIndex(i)
                if luaObj and luaObj.x and luaObj.y then
                    if luaObj.x >= minX and luaObj.x <= maxX and luaObj.y >= minY and luaObj.y <= maxY then
                        res.barrelCount = res.barrelCount + 1
                        local isoObj = luaObj.getIsoObject and luaObj:getIsoObject()
                        if isoObj then
                            local w = (isoObj.getWaterAmount and isoObj:getWaterAmount()) or (isoObj.getModData and isoObj:getModData().waterAmount) or 0
                            local maxW = (isoObj.getWaterMax and isoObj:getWaterMax()) or 400
                            res.waterTotal = res.waterTotal + w
                            res.waterMax = res.waterMax + maxW
                        else
                            res.waterMax = res.waterMax + 400
                        end
                    end
                end
            end
        end
    end

    -- 5. Contagem de Sobreviventes para Vida Social / Companhia
    if pSq then
        local room = pSq:getRoom()
        local count = 0
        pcall(function()
            if isClient and isClient() then
                local pList = getOnlinePlayers and getOnlinePlayers()
                if pList and pList.size then
                    for p = 0, pList:size() - 1 do
                        local other = pList:get(p)
                        if other and not other:isDead() then
                            local oSq = other:getCurrentSquare()
                            if room and oSq and oSq:getRoom() == room then
                                count = count + 1
                            elseif not room and oSq and math.abs(oSq:getX() - pSq:getX()) <= 12 and math.abs(oSq:getY() - pSq:getY()) <= 12 then
                                count = count + 1
                            end
                        end
                    end
                end
            else
                local numPlayers = (getNumActivePlayers and getNumActivePlayers()) or 1
                for p = 0, numPlayers - 1 do
                    local other = (getSpecificPlayer and getSpecificPlayer(p)) or getPlayer()
                    if other and not other:isDead() then
                        local oSq = other:getCurrentSquare()
                        if room and oSq and oSq:getRoom() == room then
                            count = count + 1
                        elseif not room and oSq and math.abs(oSq:getX() - pSq:getX()) <= 12 and math.abs(oSq:getY() - pSq:getY()) <= 12 then
                            count = count + 1
                        end
                    end
                end
            end
        end)
        res.survivorCount = math.max(1, count)
    end


    self.cachedData = res
    return res
end

--- Desenha uma barra fina estilizada no padrão CHStatusHUD
function LV_HouseDashboard:drawGauge(x, y, w, h, percent, color)
    percent = math.max(0, math.min(1.0, percent or 0))
    self:drawRect(x, y, w, h, 0.40, 0.10, 0.12, 0.15)
    self:drawRect(x, y, w, 1, 0.20, 1, 1, 1)

    local fill = math.floor(w * percent + 0.5)
    if fill > 0 then
        self:drawRect(x, y, fill, h, 0.90, color[1], color[2], color[3])
        self:drawRect(x, y, fill, 1, 0.35, 1, 1, 1)
    end
end

function LV_HouseDashboard:prerender()
    -- Renderização tratada no render()
end

function LV_HouseDashboard:render()
    if not self:getIsVisible() or not LV_Config or not LV_Config.isEnabled() then return end

    local data = self:refreshData(false)
    local tm = getTextManager()
    local hgt = self.fontH

    -- 1. Fundo Soft Glass Escuro e Borda Translúcida
    self:drawRect(0, 0, self.width, self.height, 0.90, 0.03, 0.035, 0.045)
    self:drawRect(0, 0, 2, self.height, 0.95, ACCENT_CYAN[1], ACCENT_CYAN[2], ACCENT_CYAN[3])
    self:drawRectBorder(0, 0, self.width, self.height, 0.25, 1, 1, 1)

    -- Cabeçalho & Botões
    self:drawText("INFRAESTRUTURA DA BASE", PAD + 4, PAD, ACCENT_CYAN[1], ACCENT_CYAN[2], ACCENT_CYAN[3], 1.0, FONT_M)
    self:drawTextRight("[COMODO (K)]", self.width - PAD - 26, PAD + 2, 0.45, 0.85, 0.90, 0.90, FONT_S)
    self:drawTextRight("[X]", self.width - PAD, PAD + 2, 0.70, 0.70, 0.70, 1.0, FONT_S)

    local subTitle = string.format("Local: %s", data.safehouseName or "Refugio")
    self:drawText(subTitle, PAD + 4, PAD + 22, 0.70, 0.75, 0.80, 1.0, FONT_S)

    -- Linha Divisória 1
    local curY = PAD + 42
    self:drawRect(PAD, curY, self.width - (PAD * 2), 1, 0.20, 1, 1, 1)
    curY = curY + 8

    -- =========================================================================
    -- SEÇÃO 1: REDE ELÉTRICA & GERADOR
    -- =========================================================================
    local genTitle = "Rede Eletrica (Gerador)"
    if data.hasGenerator then
        local statusStr = data.isActivated and " [LIGADO]" or " [DESLIGADO]"
        local statusCol = data.isActivated and ACCENT_GREEN or {0.7, 0.7, 0.7}
        self:drawText(genTitle, PAD + 4, curY, 0.90, 0.90, 0.90, 1.0, FONT_S)
        self:drawTextRight(statusStr, self.width - PAD, curY, statusCol[1], statusCol[2], statusCol[3], 1.0, FONT_S)
        curY = curY + hgt + 3

        -- Barra de Combustível
        local fuelPct = (data.fuel or 0) / 100.0
        local fuelText = string.format("Combustivel: %d%%", math.floor(data.fuel or 0))
        self:drawText(fuelText, PAD + 12, curY, 0.80, 0.85, 0.90, 1.0, FONT_S)
        self:drawGauge(140, curY + 4, 200, 6, fuelPct, ACCENT_AMBER)
        curY = curY + hgt + 2

        -- Barra de Condição
        local condPct = (data.condition or 0) / 100.0
        local condCol = (data.condition < 50) and ACCENT_RED or ACCENT_GREEN
        local condText = string.format("Condicao: %d%%", math.floor(data.condition or 0))
        self:drawText(condText, PAD + 12, curY, condCol[1], condCol[2], condCol[3], 1.0, FONT_S)
        self:drawGauge(140, curY + 4, 200, 6, condPct, condCol)
        curY = curY + hgt + 4
    else
        self:drawText("Rede Eletrica:", PAD + 4, curY, 0.80, 0.80, 0.80, 1.0, FONT_S)
        self:drawTextRight("Nenhum gerador detectado no perimetro", self.width - PAD, curY, 0.60, 0.60, 0.60, 1.0, FONT_S)
        curY = curY + hgt + 8
    end

    -- Linha Divisória 2
    self:drawRect(PAD, curY, self.width - (PAD * 2), 1, 0.15, 1, 1, 1)
    curY = curY + 8

    -- =========================================================================
    -- SEÇÃO 2: RESERVA HÍDRICA (BARRIS DE CHUVA)
    -- =========================================================================
    self:drawText("Reserva Hidrica (Barris de Chuva)", PAD + 4, curY, 0.90, 0.90, 0.90, 1.0, FONT_S)
    local barrelStr = string.format("%d barris", data.barrelCount or 0)
    self:drawTextRight(barrelStr, self.width - PAD, curY, 0.70, 0.80, 0.90, 1.0, FONT_S)
    curY = curY + hgt + 3

    local waterPct = (data.waterMax > 0) and (data.waterTotal / data.waterMax) or 0.0
    local waterText = string.format("Agua: %d / %d L", math.floor(data.waterTotal or 0), math.floor(data.waterMax or 0))
    self:drawText(waterText, PAD + 12, curY, 0.70, 0.85, 0.95, 1.0, FONT_S)
    self:drawGauge(140, curY + 4, 200, 6, waterPct, ACCENT_CYAN)
    curY = curY + hgt + 8

    -- Linha Divisória 3
    self:drawRect(PAD, curY, self.width - (PAD * 2), 1, 0.15, 1, 1, 1)
    curY = curY + 8

    -- =========================================================================
    -- SEÇÃO 3: GOVERNANÇA, ROTINA, CLIMA & VIDA SOCIAL
    -- =========================================================================
    local streakStr = string.format("Rotina: %d dias seguidos", data.streakDays or 0)
    self:drawText(streakStr, PAD + 4, curY, 0.20, 0.90, 0.75, 1.0, FONT_S)

    if data.isSpotless then
        self:drawTextRight("Status: Casa Impecavel", self.width - PAD, curY, 0.30, 0.85, 0.95, 1.0, FONT_S)
    else
        local squalorStr = string.format("Insalubridade: %d%%", math.floor(data.squalorScore or 0))
        local sqCol = (data.squalorScore >= 50) and ACCENT_RED or {0.8, 0.7, 0.5}
        self:drawTextRight(squalorStr, self.width - PAD, curY, sqCol[1], sqCol[2], sqCol[3], 1.0, FONT_S)
    end
    curY = curY + hgt + 6

    -- Sazonalidade Tática do Clima
    local seasonStr = string.format("Sazonalidade: %s", data.seasonalNote or "Clima Estavel")
    self:drawText(seasonStr, PAD + 4, curY, 0.88, 0.78, 0.45, 1.0, FONT_S)
    curY = curY + hgt + 6

    -- Vida Social / Companhia
    if data.survivorCount and data.survivorCount >= 2 then
        local compText = string.format("Companhia Ativa (%d sobreviventes)", data.survivorCount)
        self:drawText(compText, PAD + 4, curY, 0.40, 0.95, 0.50, 1.0, FONT_S)
        self:drawTextRight("Bonus: -Tedio e -Tristeza", self.width - PAD, curY, 0.60, 0.90, 0.60, 1.0, FONT_S)
    else
        self:drawText("Vida Social: Sobrevivente Solitario", PAD + 4, curY, 0.60, 0.60, 0.65, 1.0, FONT_S)
        self:drawTextRight("Dica: Convide aliados para o lar", self.width - PAD, curY, 0.50, 0.50, 0.55, 1.0, FONT_S)
    end
end

--- Imprime o relatório de infraestrutura da base no Chat e console do servidor
function LV_HouseDashboard.printStatusReport(player)
    local dash = LV_HouseDashboard.getInstance()
    local data = dash:refreshData(true)

    local lines = {}
    table.insert(lines, string.format("[Living House] === STATUS DO REFUGIO: %s ===", data.safehouseName or "Refugio"))
    if data.hasGenerator then
        local state = data.isActivated and "LIGADO" or "DESLIGADO"
        table.insert(lines, string.format(" - Rede Eletrica: Gerador %s | Combustivel: %d%% | Condicao: %d%%", state, math.floor(data.fuel or 0), math.floor(data.condition or 0)))
    else
        table.insert(lines, " - Rede Eletrica: Nenhum gerador detectado no perimetro")
    end
    table.insert(lines, string.format(" - Reserva Hidrica: %d barris (%d / %d Litros)", data.barrelCount or 0, math.floor(data.waterTotal or 0), math.floor(data.waterMax or 0)))
    table.insert(lines, string.format(" - Conforto do Lar: Tier %d (%d pts) | Insalubridade: %d%%", data.comfortTier or 0, data.comfortScore or 0, math.floor(data.squalorScore or 0)))
    table.insert(lines, string.format(" - Clima & Sazonalidade: %s", data.seasonalNote or "Clima Estavel"))
    table.insert(lines, string.format(" - Rotina & Social: Streak de %d dias | Companhia: %d sobrevivente(s)", data.streakDays or 0, data.survivorCount or 1))

    for _, line in ipairs(lines) do
        if ISChat then
            if ISChat.instance and ISChat.instance.addLineInChat then
                pcall(function() ISChat.instance:addLineInChat(line, 0) end)
            elseif ISChat.addLineInChat then
                pcall(ISChat.addLineInChat, line, 0)
            end
        end
        print(line)
    end

    if player and player.setHaloNote then
        pcall(function()
            player:setHaloNote("Living House: Relatorio enviado ao Chat! [Pressione J]", 90, 230, 240, 280)
        end)
    end

    dash:setVisible(true)
end

-- =============================================================================
-- Ganchos de Inicialização, Teclado e Comando no Chat (/lv_status)
-- =============================================================================

Events.OnGameStart.Add(function()
    LV_HouseDashboard.getInstance()
    print("[LivingHouse] LV_HouseDashboard inicializado com sucesso!")
end)

Events.OnKeyPressed.Add(function(key)
    -- Tecla 'J' (Keyboard.KEY_J = 36 no PZ)
    if key == Keyboard.KEY_J then
        LV_HouseDashboard.toggle()
    end
end)

--- Interceptador passivo de comandos de chat (/lv_status, /lv, /livinghouse)
local function onAddChatMessage(chatMessage, tabId)
    if not chatMessage then return end
    local text = nil
    if type(chatMessage) == "string" then
        text = chatMessage
    elseif type(chatMessage) == "table" or type(chatMessage) == "userdata" then
        if chatMessage.getText then
            text = chatMessage:getText()
        end
    end

    if text and LV_Config and LV_Config.get("ServerTelemetryEnabled") then
        local lower = text:lower()
        local trimmed = lower:match("^%s*(.-)%s*$")
        if trimmed == "/lv_status" or trimmed == "/lv" or trimmed == "/livinghouse" then
            local player = getPlayer()
            if player then
                LV_HouseDashboard.printStatusReport(player)
            end
        end
    end
end

if Events.OnAddMessage then
    Events.OnAddMessage.Add(onAddChatMessage)
end
