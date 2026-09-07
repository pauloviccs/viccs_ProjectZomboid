-- =============================================================================
-- Housing Care System (Lar Vivo) - Appliance Telemetry & Care Dashboard (LV_ApplianceDashboard.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Painel de monitoramento e telemetria de aparelhos domesticos e pecas sanitarias:
--   - Deteccao granular por comodo (Modo Comodo Atual vs Toda a Casa)
--   - Abas interativas de filtragem rapida por comodo (Cozinha, Banheiro, etc.)
--   - Varredura profunda de toda a residencia (IsoBuilding, Rooms e Safehouse)
--   - Deduplicacao inteligente por tile (evita repeticao de pecas compostas)
--   - Semaforo visual de 3 segundos (Sistemas Operacionais / Alerta / Critico)
--   - Integridade fisica / Durabilidade (%) e Sujeira acumulada (%)
--   - Diagnostico ELI5 indicando ferramentas necessarias para manutencao preventiva
--   - Painel Draggable (arraste livre com mouse) e rolagem suave (Mouse Wheel)
--   - Atalho dedicado 'U' e alternancia fluida com [INFRA] (J) e [COMODO] (K)
-- =============================================================================

require "ISUI/ISPanel"
require "LV_Config"
require "LV_DirtScoreData"
require "LV_ComfortScanner"
require "LV_BuffManager"

LV_ApplianceDashboard = ISPanel:derive("LV_ApplianceDashboard")

local instance = nil

local FONT_S = UIFont.Small
local FONT_M = UIFont.Medium
local PAD = 10
local ACCENT_CYAN = {0.36, 0.76, 0.86}
local ACCENT_AMBER = {0.92, 0.71, 0.29}
local ACCENT_GREEN = {0.30, 0.85, 0.50}
local ACCENT_RED = {0.95, 0.25, 0.25}
local ACCENT_DIRT = {0.80, 0.45, 0.20}

--- Traduz e formata o nome de um comodo a partir de um square
local function getSquareRoomName(sq)
    if not sq then return "Ambiente Geral" end
    local r = sq.getRoom and sq:getRoom()
    if r and r.getName and r:getName() then
        local raw = tostring(r:getName()):lower()
        if raw:find("kitchen") then return "Cozinha"
        elseif raw:find("bath") then return "Banheiro"
        elseif raw:find("bedroom") then return "Quarto"
        elseif raw:find("living") then return "Sala de Estar"
        elseif raw:find("laundry") then return "Lavanderia"
        elseif raw:find("hall") then return "Corredor"
        elseif raw:find("garage") then return "Garagem"
        elseif raw:find("closet") or raw:find("storage") then return "Despensa"
        elseif raw ~= "" then
            return raw:gsub("^%l", string.upper)
        end
    end
    return "Ambiente Geral"
end

--- Cria uma nova instancia do painel de telemetria de aparelhos
function LV_ApplianceDashboard:new(x, y, width, height)
    local tm = getTextManager()
    local hgt = tm:getFontHeight(FONT_S)
    local w = width or 460
    local h = height or 450

    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.fontH = hgt
    o.moveWithMouse = true
    o.userHidden = true
    o.downX, o.downY = -1, -1
    o.isDragging = false

    o.selectedFilter = "CURRENT" -- Padrao: detecta por comodo atual ("CURRENT"), "ALL", ou nome do comodo
    o.tabBounds = {}

    o.lastScanTime = 0
    o.cachedAppliances = {}
    o.summary = { total = 0, critical = 0, warning = 0, clean = 0, currentRoom = "Ambiente Geral", rooms = {} }
    o.scrollOffset = 0
    o.maxScroll = 0

    return o
end

--- Retorna a instancia unica (Singleton)
function LV_ApplianceDashboard.getInstance()
    if not instance then
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        local w = 460
        local h = 450
        local x = math.floor((screenW - w) / 2) + 30
        local y = math.floor((screenH - h) / 2) + 30

        instance = LV_ApplianceDashboard:new(x, y, w, h)
        instance:initialise()
        instance:instantiate()
        instance:addToUIManager()
        instance:setVisible(false)
    end
    return instance
end

--- Alterna a visibilidade do painel (Toggle)
function LV_ApplianceDashboard.toggle()
    local dash = LV_ApplianceDashboard.getInstance()
    if dash then
        local isVis = dash:getIsVisible()
        dash:setVisible(not isVis)
        if not isVis then
            dash:refreshData(true)
        end
    end
end

function LV_ApplianceDashboard:onMouseDown(x, y)
    self.downX = x
    self.downY = y
    self.isDragging = true
    return true
end

function LV_ApplianceDashboard:onMouseUp(x, y)
    if self.isDragging and math.abs(x - self.downX) <= 4 and math.abs(y - self.downY) <= 4 then
        -- Botao de fechar [X]
        if x >= (self.width - 26) and y <= 24 then
            self:setVisible(false)
            return true
        end
        -- Botao de alternancia rapida para Infraestrutura [INFRA (J)]
        if x >= (self.width - 105) and x <= (self.width - 30) and y <= 24 then
            self:setVisible(false)
            if LV_HouseDashboard and LV_HouseDashboard.getInstance then
                local hd = LV_HouseDashboard.getInstance()
                if hd then hd:setVisible(true); hd:refreshData(true) end
            end
            return true
        end

        -- Cliques nas Abas de Filtro por Comodo
        if self.tabBounds then
            for _, tb in ipairs(self.tabBounds) do
                if x >= tb.x and x <= (tb.x + tb.w) and y >= tb.y and y <= (tb.y + tb.h) then
                    if self.selectedFilter ~= tb.key then
                        self.selectedFilter = tb.key
                        self.scrollOffset = 0
                    end
                    self.isDragging = false
                    return true
                end
            end
        end
    end
    self.isDragging = false
    return true
end

function LV_ApplianceDashboard:onMouseMove(dx, dy)
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

function LV_ApplianceDashboard:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function LV_ApplianceDashboard:onMouseUpOutside(x, y)
    self.isDragging = false
    return true
end

function LV_ApplianceDashboard:onMouseWheel(del)
    self.scrollOffset = math.max(0, math.min(self.maxScroll, self.scrollOffset + (del * 30)))
    return true
end

--- Varre profundamente todos os squares e comodos da residencia do jogador
function LV_ApplianceDashboard:refreshData(force)
    local curTime = getTimeInMillis()
    if not force and (curTime - self.lastScanTime) < 2000 then
        return self.cachedAppliances, self.summary
    end
    self.lastScanTime = curTime

    local player = getPlayer()
    if not player or player:isDead() then
        return {}, { total = 0, critical = 0, warning = 0, clean = 0, isOutside = true, currentRoom = "Desconhecido", rooms = {} }
    end

    local pSq = player:getCurrentSquare()
    if not pSq then
        return {}, { total = 0, critical = 0, warning = 0, clean = 0, isOutside = true, currentRoom = "Desconhecido", rooms = {} }
    end

    local currentRoomName = getSquareRoomName(pSq)

    -- 1. Avalia o status de propriedade e posse da base do square atual
    local own = (LV_ComfortScanner and LV_ComfortScanner.getBuildingOwnershipStatus and LV_ComfortScanner.getBuildingOwnershipStatus(pSq, player)) or nil
    local isOutside = (own and own.isOutside == true) or (pSq.isOutside and pSq:isOutside())
    local isClaimed = (own and own.isClaimed == true)

    -- 2. Se o jogador estiver ao ar livre / fora de casa (sem safehouse), nao varre
    if isOutside then
        local emptySummary = {
            total = 0, critical = 0, warning = 0, clean = 0,
            isOutside = true,
            isClaimed = false,
            currentRoom = "Area Externa",
            rooms = {},
            baseName = "Area Externa",
            statusText = "Voce esta ao ar livre. O painel monitora apenas os aparelhos da sua casa/safehouse."
        }
        self.cachedAppliances = {}
        self.summary = emptySummary
        return {}, emptySummary
    end

    -- 3. Se for um imovel nao reivindicado em modo estrito
    if own and not isClaimed and not (LV_Config and LV_Config.isBaseOwnershipRequired and not LV_Config.isBaseOwnershipRequired()) then
        local unclaimSummary = {
            total = 0, critical = 0, warning = 0, clean = 0,
            isOutside = false,
            isClaimed = false,
            isUnclaimed = true,
            currentRoom = currentRoomName,
            rooms = {},
            baseName = own.baseName or "Imovel Nao Reivindicado",
            statusText = "Imovel nao reivindicado. Reivindique a base para monitorar instalacoes."
        }
        self.cachedAppliances = {}
        self.summary = unclaimSummary
        return {}, unclaimSummary
    end

    -- 4. Coleta exaustiva de TODOS os squares da casa/predio
    local squaresToScan = {}
    local seenSquares = {}

    local building = (pSq.getBuilding and pSq:getBuilding()) or (own and own.building)
    if not building and pSq.getRoom and pSq:getRoom() then
        local r = pSq:getRoom()
        if r.getBuilding then building = r:getBuilding() end
    end

    if building then
        -- A) Colecao Java IsoBuilding.rooms / IsoBuilding.Rooms
        local bRooms = building.rooms or building.Rooms
        if bRooms and bRooms.size then
            local okCount, numRooms = pcall(bRooms.size, bRooms)
            if okCount and numRooms and numRooms > 0 then
                for r = 0, numRooms - 1 do
                    local rObj = bRooms:get(r)
                    if rObj and rObj.getSquares then
                        local okS, rSquares = pcall(rObj.getSquares, rObj)
                        if okS and rSquares and rSquares.size then
                            for s = 0, rSquares:size() - 1 do
                                local sq = rSquares:get(s)
                                if sq and not seenSquares[sq] then
                                    seenSquares[sq] = true
                                    table.insert(squaresToScan, sq)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- B) BuildingDef (definicao persistente da planta do edificio no mapa)
        local bDef = building.getDef and building:getDef()
        if bDef then
            if bDef.getRooms then
                local okRDefs, rDefs = pcall(bDef.getRooms, bDef)
                if okRDefs and rDefs and rDefs.size and rDefs:size() > 0 then
                    for rd = 0, rDefs:size() - 1 do
                        local rDef = rDefs:get(rd)
                        local rObj = rDef and rDef.getIsoRoom and rDef:getIsoRoom()
                        if rObj and rObj.getSquares then
                            local okS, rSquares = pcall(rObj.getSquares, rObj)
                            if okS and rSquares and rSquares.size then
                                for s = 0, rSquares:size() - 1 do
                                    local sq = rSquares:get(s)
                                    if sq and not seenSquares[sq] then
                                        seenSquares[sq] = true
                                        table.insert(squaresToScan, sq)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Bounding Box do Predio no Z atual (garante comodos abertos ou sem tag IsoRoom)
            if bDef.getX and bDef.getY and bDef.getX2 and bDef.getY2 then
                local cell = pSq:getCell() or getCell()
                local pZ = pSq:getZ()
                local bx1 = math.max(0, bDef:getX())
                local by1 = math.max(0, bDef:getY())
                local bx2 = math.min(bx1 + 80, bDef:getX2())
                local by2 = math.min(by1 + 80, bDef:getY2())
                for x = bx1, bx2 do
                    for y = by1, by2 do
                        local sq = cell and cell:getGridSquare(x, y, pZ)
                        if sq and not seenSquares[sq] then
                            local sqB = (sq.getBuilding and sq:getBuilding()) or (sq.getRoom and sq:getRoom() and sq:getRoom().getBuilding and sq:getRoom():getBuilding())
                            if sqB == building then
                                seenSquares[sq] = true
                                table.insert(squaresToScan, sq)
                            end
                        end
                    end
                end
            end
        end
    end

    -- C) Safehouse Oficial (Multiplayer ou Claimed)
    local shClass = SafeHouse or (zombie and zombie.iso and zombie.iso.areas and zombie.iso.areas.SafeHouse)
    local activeSafehouse = nil
    if shClass and shClass.getSafehouse then
        local ok, sh = pcall(shClass.getSafehouse, pSq)
        if ok and sh then activeSafehouse = sh end
    end

    if activeSafehouse and activeSafehouse.getX and activeSafehouse.getY and activeSafehouse.getW and activeSafehouse.getH then
        local cell = pSq:getCell() or getCell()
        local sx = activeSafehouse:getX()
        local sy = activeSafehouse:getY()
        local sw = math.min(60, activeSafehouse:getW())
        local shH = math.min(60, activeSafehouse:getH())
        local pZ = pSq:getZ()
        for x = sx, sx + sw - 1 do
            for y = sy, sy + shH - 1 do
                local sq = cell:getGridSquare(x, y, pZ)
                if sq and not seenSquares[sq] then
                    seenSquares[sq] = true
                    table.insert(squaresToScan, sq)
                end
            end
        end
    end

    -- D) Fallback para casas inteiramente construidas por jogadores (sem BuildingDef)
    if #squaresToScan == 0 then
        local cell = pSq:getCell() or getCell()
        local px, py, pz = pSq:getX(), pSq:getY(), pSq:getZ()
        local radius = 25
        for x = px - radius, px + radius do
            for y = py - radius, py + radius do
                local sq = cell and cell:getGridSquare(x, y, pz)
                if sq and not sq:isOutside() and not seenSquares[sq] then
                    seenSquares[sq] = true
                    table.insert(squaresToScan, sq)
                end
            end
        end
    end

    -- 5. Inspecao dos objetos com deduplicacao estrita por tile
    local appliances = {}
    local seenObjects = {}
    local seenTileAppliance = {} -- Chave: appType_x_y (evita que o mesmo fogao ou pia apareca 3x)
    local roomCounts = {}

    local summary = {
        total = 0, critical = 0, warning = 0, clean = 0,
        isOutside = false,
        isClaimed = true,
        baseName = (own and own.baseName) or "Lar",
        currentRoom = currentRoomName,
        rooms = {}
    }

    for _, sq in ipairs(squaresToScan) do
        local objs = sq:getObjects()
        if objs and objs.size then
            for i = 0, objs:size() - 1 do
                local obj = objs:get(i)
                if obj and not seenObjects[obj] then
                    seenObjects[obj] = true
                    local appType = LV_DirtScoreData.identifyApplianceType(obj)
                    if appType then
                        local objSq = (obj.getSquare and obj:getSquare()) or sq
                        local ox = objSq and objSq:getX() or sq:getX()
                        local oy = objSq and objSq:getY() or sq:getY()
                        local tileKey = tostring(appType) .. "_" .. tostring(ox) .. "_" .. tostring(oy)

                        if not seenTileAppliance[tileKey] then
                            seenTileAppliance[tileKey] = true

                            local md = obj.getModData and obj:getModData()
                            local dirt = (md and md.LV_FixtureDirt) or 0
                            local health = LV_DirtScoreData.getApplianceHealth(obj)
                            local label = (LV_DirtScoreData.FixturePatterns[appType] and LV_DirtScoreData.FixturePatterns[appType].name) or "Aparelho"

                            -- Determinacao do Comodo do Aparelho
                            local roomName = getSquareRoomName(objSq)
                            if roomName == "Ambiente Geral" then
                                -- Fallback inteligente por arquetipo
                                if appType == "toilet" or appType == "bathtub" or appType == "shower" then
                                    roomName = "Banheiro"
                                elseif appType == "stove" then
                                    roomName = "Cozinha"
                                end
                            end

                            -- Gravidade
                            local isCritical = (health <= 0 or health < 25 or dirt >= 80)
                            local isWarning = not isCritical and (health < 60 or dirt >= 40)

                            if isCritical then
                                summary.critical = summary.critical + 1
                            elseif isWarning then
                                summary.warning = summary.warning + 1
                            else
                                summary.clean = summary.clean + 1
                            end
                            summary.total = summary.total + 1
                            roomCounts[roomName] = (roomCounts[roomName] or 0) + 1

                            table.insert(appliances, {
                                object = obj,
                                type = appType,
                                label = label,
                                room = roomName,
                                health = health,
                                dirt = dirt,
                                isCritical = isCritical,
                                isWarning = isWarning,
                                x = ox,
                                y = oy,
                            })
                        end
                    end
                end
            end
        end
    end

    -- Ordena priorizando problemas criticos no topo
    table.sort(appliances, function(a, b)
        if a.isCritical ~= b.isCritical then return a.isCritical end
        if a.isWarning ~= b.isWarning then return a.isWarning end
        return a.health < b.health
    end)

    summary.rooms = roomCounts
    self.cachedAppliances = appliances
    self.summary = summary
    return appliances, summary
end

--- Desenha barra de progresso estilizada com rotulo interno
function LV_ApplianceDashboard:drawMiniBar(x, y, w, h, percent, r, g, b, label)
    percent = math.max(0.0, math.min(1.0, percent))
    self:drawRect(x, y, w, h, 0.50, 0.08, 0.08, 0.08)
    self:drawRectBorder(x, y, w, h, 0.40, 0.35, 0.35, 0.35)

    local fillW = math.floor(w * percent)
    if fillW > 0 then
        self:drawRect(x + 1, y + 1, fillW - 2, h - 2, 0.85, r, g, b)
    end

    if label then
        local tm = getTextManager()
        local tw = tm:MeasureStringX(FONT_S, label)
        local tx = x + math.floor((w - tw) / 2)
        local ty = y - 1
        self:drawText(label, tx, ty, 0.95, 0.95, 0.95, 1.0, FONT_S)
    end
end

function LV_ApplianceDashboard:prerender()
    -- Renderizacao tratada no render()
end

function LV_ApplianceDashboard:render()
    if not self:getIsVisible() or not LV_Config or not LV_Config.isEnabled() then return end

    local appliances, summary = self:refreshData(false)
    local tm = getTextManager()
    local hgt = self.fontH

    -- 1. Fundo Frameless Dark Glass
    self:drawRect(0, 0, self.width, self.height, 0.92, 0.03, 0.035, 0.045)
    self:drawRect(0, 0, 2, self.height, 0.95, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3])
    self:drawRectBorder(0, 0, self.width, self.height, 0.25, 1, 1, 1)

    -- Cabecalho Principal
    self:drawText("APARELHOS & INSTALACOES", PAD + 4, PAD, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3], 1.0, FONT_M)
    self:drawTextRight("[INFRA (J)]", self.width - PAD - 26, PAD + 2, 0.45, 0.85, 0.90, 0.90, FONT_S)
    self:drawTextRight("[X]", self.width - PAD, PAD + 2, 0.70, 0.70, 0.70, 1.0, FONT_S)

    local cy = PAD + 26

    -- 2. Semaforo de 3 Segundos
    local statusText = "SISTEMAS OPERACIONAIS (Instalacoes Integras)"
    local statusColor = ACCENT_GREEN
    if summary.isOutside then
        statusText = "AREA EXTERNA (Fora da Base)"
        statusColor = {0.50, 0.65, 0.80}
    elseif summary.isUnclaimed then
        statusText = "IMOVEL NAO REIVINDICADO"
        statusColor = ACCENT_AMBER
    elseif summary.critical > 0 then
        statusText = string.format("CRITICO: %d Aparelho(s) com Defeito / Quebrado(s)!", summary.critical)
        statusColor = ACCENT_RED
    elseif summary.warning > 0 then
        statusText = string.format("ATENCAO: %d Aparelho(s) Requerem Manutencao / Limpeza", summary.warning)
        statusColor = ACCENT_AMBER
    elseif summary.total == 0 then
        statusText = "Nenhuma instalacao detectada na residencia"
        statusColor = {0.6, 0.6, 0.6}
    end

    self:drawRect(PAD, cy, self.width - (PAD * 2), 22, 0.50, statusColor[1] * 0.2, statusColor[2] * 0.2, statusColor[3] * 0.2)
    self:drawRectBorder(PAD, cy, self.width - (PAD * 2), 22, 0.60, statusColor[1], statusColor[2], statusColor[3])
    self:drawText(statusText, PAD + 8, cy + 3, statusColor[1], statusColor[2], statusColor[3], 1.0, FONT_S)

    cy = cy + 28

    -- 3. ABAS DE FILTRAGEM POR COMODO (Deteccao Inteligente)
    self.tabBounds = {}
    local tabY = cy
    local tabH = 20
    local tabX = PAD

    -- Lista de abas: 1. COMODO ATUAL, 2. TODA A CASA, 3+ Cada comodo com aparelhos
    local tabsList = {
        { key = "CURRENT", label = string.format("Atual: %s", summary.currentRoom) },
        { key = "ALL", label = string.format("Toda a Casa (%d)", summary.total) },
    }

    -- Adiciona abas para os comodos detectados que possuam aparelhos
    if summary.rooms then
        local sortedRooms = {}
        for rName, count in pairs(summary.rooms) do
            table.insert(sortedRooms, { name = rName, count = count })
        end
        table.sort(sortedRooms, function(a, b) return a.count > b.count end)

        for _, rData in ipairs(sortedRooms) do
            table.insert(tabsList, {
                key = rData.name,
                label = string.format("%s (%d)", rData.name, rData.count)
            })
        end
    end

    for _, tData in ipairs(tabsList) do
        local tw = tm:MeasureStringX(FONT_S, tData.label) + 12
        if (tabX + tw) > (self.width - PAD) then
            -- Se estourar a linha, nao empilha para manter layout limpo
            break
        end

        local isSelected = (self.selectedFilter == tData.key)
        if isSelected then
            self:drawRect(tabX, tabY, tw, tabH, 0.65, ACCENT_AMBER[1] * 0.35, ACCENT_AMBER[2] * 0.35, ACCENT_AMBER[3] * 0.35)
            self:drawRectBorder(tabX, tabY, tw, tabH, 0.90, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3])
            self:drawText(tData.label, tabX + 6, tabY + 2, 1.0, 1.0, 1.0, 1.0, FONT_S)
        else
            self:drawRect(tabX, tabY, tw, tabH, 0.25, 0.12, 0.14, 0.16)
            self:drawRectBorder(tabX, tabY, tw, tabH, 0.35, 0.50, 0.55, 0.60)
            self:drawText(tData.label, tabX + 6, tabY + 2, 0.70, 0.75, 0.80, 0.90, FONT_S)
        end

        table.insert(self.tabBounds, { x = tabX, y = tabY, w = tw, h = tabH, key = tData.key })
        tabX = tabX + tw + 4
    end

    cy = cy + tabH + 6

    -- 4. Filtragem da Lista de Aparelhos
    local displayAppliances = {}
    for _, app in ipairs(appliances) do
        local match = false
        if self.selectedFilter == "ALL" then
            match = true
        elseif self.selectedFilter == "CURRENT" then
            match = (app.room == summary.currentRoom)
        elseif self.selectedFilter == app.room then
            match = true
        end

        if match then
            table.insert(displayAppliances, app)
        end
    end

    -- Contagem de resumo do filtro ativo
    local activeCrit = 0
    local activeWarn = 0
    local activeClean = 0
    for _, a in ipairs(displayAppliances) do
        if a.isCritical then activeCrit = activeCrit + 1
        elseif a.isWarning then activeWarn = activeWarn + 1
        else activeClean = activeClean + 1 end
    end

    local filterTitle = "Toda a Residencia"
    if self.selectedFilter == "CURRENT" then
        filterTitle = string.format("Comodo Atual [%s]", summary.currentRoom)
    elseif self.selectedFilter ~= "ALL" then
        filterTitle = string.format("Comodo [%s]", self.selectedFilter)
    end

    local countStr = string.format("%s | Total: %d | Integras: %d | Alerta: %d | Criticas: %d", filterTitle, #displayAppliances, activeClean, activeWarn, activeCrit)
    self:drawText(countStr, PAD + 2, cy, 0.75, 0.75, 0.75, 0.90, FONT_S)

    cy = cy + 16
    self:drawRect(PAD, cy, self.width - (PAD * 2), 1, 0.25, 1, 1, 1)
    cy = cy + 6

    -- 5. Lista de Aparelhos com Scroll e Stencil Clipping
    local listY = cy
    local listH = self.height - listY - 28
    local itemH = 58
    local totalH = #displayAppliances * itemH

    self.maxScroll = math.max(0, totalH - listH)
    if self.scrollOffset > self.maxScroll then self.scrollOffset = self.maxScroll end

    self:setStencilRect(PAD, listY, self.width - (PAD * 2), listH)

    if #displayAppliances == 0 then
        local emptyMsg = "Nenhuma instalacao ou aparelho encontrado neste filtro."
        if summary.isOutside then
            emptyMsg = "Voce esta ao ar livre. O painel monitora apenas os aparelhos da sua casa/safehouse."
        elseif summary.isUnclaimed then
            emptyMsg = "Imovel nao reivindicado. Reivindique este local para ativar a telemetria."
        elseif self.selectedFilter == "CURRENT" then
            emptyMsg = string.format("Nenhum aparelho sanitario/fogao detectado no %s.", summary.currentRoom)
        end
        self:drawText(emptyMsg, PAD + 8, listY + 24, 0.65, 0.70, 0.75, 0.95, FONT_S)
        if self.selectedFilter == "CURRENT" and summary.total > 0 then
            self:drawText("Dica: Clique na aba [Toda a Casa] acima para inspecionar os outros comodos.", PAD + 8, listY + 42, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3], 0.95, FONT_S)
        end
    else
        local startY = listY - self.scrollOffset
        for idx, app in ipairs(displayAppliances) do
            local iy = startY + ((idx - 1) * itemH)
            if (iy + itemH) >= listY and iy <= (listY + listH) then
                -- Fundo do card
                local bgAlpha = (idx % 2 == 0) and 0.25 or 0.15
                if app.isCritical then
                    self:drawRect(PAD, iy, self.width - (PAD * 2) - 8, itemH - 4, 0.40, 0.30, 0.05, 0.05)
                    self:drawRect(PAD, iy, 2, itemH - 4, 0.90, ACCENT_RED[1], ACCENT_RED[2], ACCENT_RED[3])
                elseif app.isWarning then
                    self:drawRect(PAD, iy, self.width - (PAD * 2) - 8, itemH - 4, 0.30, 0.25, 0.18, 0.04)
                    self:drawRect(PAD, iy, 2, itemH - 4, 0.90, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3])
                else
                    self:drawRect(PAD, iy, self.width - (PAD * 2) - 8, itemH - 4, bgAlpha, 0.08, 0.10, 0.12)
                end
                self:drawRectBorder(PAD, iy, self.width - (PAD * 2) - 8, itemH - 4, 0.15, 1, 1, 1)

                -- Titulo e Localizacao
                local titleStr = string.format("%s (%s)", app.label, app.room)
                self:drawText(titleStr, PAD + 8, iy + 4, 0.95, 0.95, 0.95, 1.0, FONT_S)

                -- Barra 1: Durabilidade / Saude
                local barW = 120
                local barH = 12
                local barX = self.width - (PAD * 2) - barW - 14

                local hColor = ACCENT_GREEN
                if app.health < 25 then hColor = ACCENT_RED
                elseif app.health < 60 then hColor = ACCENT_AMBER end

                local hLabel = string.format("Vida: %d%%", math.floor(app.health))
                self:drawMiniBar(barX, iy + 4, barW, barH, app.health / 100.0, hColor[1], hColor[2], hColor[3], hLabel)

                -- Barra 2: Sujeira
                local dColor = {0.35, 0.70, 0.90}
                if app.dirt >= 75 then dColor = {0.75, 0.25, 0.20}
                elseif app.dirt >= 35 then dColor = ACCENT_DIRT end

                local dLabel = string.format("Sujeira: %d%%", math.floor(app.dirt))
                self:drawMiniBar(barX, iy + 19, barW, barH, app.dirt / 100.0, dColor[1], dColor[2], dColor[3], dLabel)

                -- Diagnostico ELI5
                local diagText = "Operacional e limpo"
                local diagCol = {0.55, 0.85, 0.55}
                if app.health <= 0 then
                    diagText = "QUEBRADO / ENTUPIDO (Requer Reparo com Chave)"
                    diagCol = ACCENT_RED
                elseif app.health < 30 then
                    diagText = "DESGASTADO: Vazamento iminente (Requer Chave/Fita)"
                    diagCol = ACCENT_RED
                elseif app.dirt >= 60 then
                    diagText = "MUITO SUJO: Higienize com Pano/Esponja"
                    diagCol = ACCENT_AMBER
                elseif app.health < 60 then
                    diagText = "Desgaste moderado (Manutencao recomendada)"
                    diagCol = ACCENT_AMBER
                elseif app.dirt > 0 then
                    diagText = "Sujeira leve presente"
                    diagCol = {0.70, 0.70, 0.70}
                end

                self:drawText(diagText, PAD + 8, iy + 34, diagCol[1], diagCol[2], diagCol[3], 0.90, FONT_S)
            end
        end
    end

    self:clearStencilRect()

    -- Barra de rolagem simples
    if self.maxScroll > 0 then
        local sbH = math.max(16, math.floor(listH * (listH / totalH)))
        local sbY = listY + math.floor((listH - sbH) * (self.scrollOffset / self.maxScroll))
        local sbX = self.width - PAD - 5
        self:drawRect(sbX, listY, 4, listH, 0.20, 0.2, 0.2, 0.2)
        self:drawRect(sbX, sbY, 4, sbH, 0.70, ACCENT_AMBER[1], ACCENT_AMBER[2], ACCENT_AMBER[3])
    end

    -- Rodape com Dica
    local footY = self.height - 22
    self:drawText("Dica: Clique nas abas para filtrar por comodo | Clique com botao direito no aparelho para limpar/reparar.", PAD + 4, footY, 0.55, 0.60, 0.65, 0.85, FONT_S)
end

Events.OnGameStart.Add(function()
    LV_ApplianceDashboard.getInstance()
    print("[LivingHouse] LV_ApplianceDashboard inicializado com sucesso!")
end)

Events.OnKeyPressed.Add(function(key)
    -- Tecla 'U' (Keyboard.KEY_U = 22 no PZ)
    if (Keyboard and Keyboard.KEY_U and key == Keyboard.KEY_U) or key == 22 then
        LV_ApplianceDashboard.toggle()
    end
end)

return LV_ApplianceDashboard
