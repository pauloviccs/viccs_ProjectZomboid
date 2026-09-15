-- =============================================================================
-- Housing Care System (Lar Vivo) - Minigame de Skill Check (LV_SkillCheckUI.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Minigame de precisao circular estilo "Dead By Daylight" (DBD) para acoes
--   de manutencao (pias, vasos, chuveiros, eletrodomesticos) e eletrica (troca
--   de lampadas).
--
--   - Alerta sonoro previo (Ding) avisando que o minigame vai comecar
--   - Agulha giratoria (Needle) que parte de 0 graus no sentido horario
--   - Zona de Sucesso Normal (Verde) e Zona Critica/Excelente (Dourada)
--   - Acionamento com a tecla [ESPACO]
--   - Acerto normal: Continua a acao e garante XP
--   - Acerto critico: Avanco bonus na acao + XP dobrado + Buff de foco
--   - Erro (apertar fora ou timeout): Cancela imediatamente a acao, emite
--     som de faisca/impacto e atrai zumbis locais pelo barulho
-- =============================================================================

require "ISUI/ISPanel"
require "LV_Config"

LV_SkillCheckUI = ISPanel:derive("LV_SkillCheckUI")

local instance = nil

-- Constantes de Cores
local COLOR_BG_PANEL     = { 0.03, 0.04, 0.06, 0.75 }
local COLOR_BORDER       = { 0.30, 0.35, 0.42, 0.50 }
local COLOR_TRACK        = { 0.22, 0.25, 0.28, 0.60 }
local COLOR_SUCCESS      = { 0.20, 0.88, 0.45, 0.95 }
local COLOR_CRITICAL     = { 1.00, 0.84, 0.20, 1.00 }
local COLOR_NEEDLE       = { 1.00, 0.22, 0.25, 1.00 }
local COLOR_CENTER       = { 0.12, 0.14, 0.18, 0.90 }
local COLOR_TEXT_AMBER   = { 0.92, 0.75, 0.30 }
local COLOR_WHITE        = { 1.00, 1.00, 1.00 }

local FONT_S = UIFont.Small
local FONT_M = UIFont.Medium

--- Retorna o texto traduzido ou fallback seguro (blindado contra chaves cruas da engine)
function LV_SkillCheckUI.getText(key, fallback)
    if not key then return fallback or "" end
    if getTextOrNull then
        local val = getTextOrNull(key)
        if val and val ~= key and val ~= "" and not string.find(val, "^UI_") then
            return val
        end
    end
    if getText then
        local val = getText(key)
        if val and val ~= key and val ~= "" and not string.find(val, "^UI_") then
            return val
        end
    end
    return fallback or key
end

function LV_SkillCheckUI:new(x, y, width, height)
    local w = width or 200
    local h = height or 200
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.width = w
    o.height = h
    o.moveWithMouse = false
    o.userHidden = true

    -- Geometria da Roleta
    o.centerX = math.floor(w / 2)
    o.centerY = math.floor(h / 2)
    o.radius = 62

    -- Estados de Operacao
    o.character = nil
    o.action = nil
    o.perkType = nil
    o.perkName = "TESTE DE HABILIDADE"
    o.difficulty = 2

    o.onSuccessCallback = nil
    o.onFailCallback = nil

    o.state = "IDLE" -- IDLE, WARNING, ACTIVE, RESOLVED
    o.warningTimer = 0
    o.resultTimer = 0
    o.resultText = ""
    o.resultColor = COLOR_WHITE

    o.currentAngle = 0.0
    o.needleSpeed = 280.0 -- graus por segundo
    o.targetAngle = 135.0
    o.successZoneSize = 45.0
    o.criticalZoneSize = 10.0

    o.prevSpaceDown = false
    o.evaluated = false

    return o
end

function LV_SkillCheckUI.getInstance()
    if not instance then
        local screenW = getCore():getScreenWidth()
        local screenH = getCore():getScreenHeight()
        local w = 200
        local h = 200
        local x = math.floor((screenW - w) / 2)
        local y = math.floor((screenH - h) / 2) - 30

        instance = LV_SkillCheckUI:new(x, y, w, h)
        instance:initialise()
        instance:instantiate()
        instance:addToUIManager()
        instance:setVisible(false)
    end
    return instance
end

--- Dispara o minigame de Skill Check
-- @param character IsoPlayer
-- @param action ISBaseTimedAction
-- @param perkType PerkFactory.Perks
-- @param perkLabel string (ex: "TESTE ELETRICO")
-- @param onSuccess function(isCritical)
-- @param onFail function()
function LV_SkillCheckUI.trigger(character, action, perkType, perkLabel, onSuccess, onFail)
    if not character or not action then
        if onSuccess then onSuccess(false) end
        return
    end

    -- Se desabilitado no Sandbox, da sucesso imediato sem abrir o minigame
    if LV_Config and LV_Config.isSkillCheckMinigameEnabled and not LV_Config.isSkillCheckMinigameEnabled() then
        if onSuccess then onSuccess(false) end
        return
    end

    local ui = LV_SkillCheckUI.getInstance()
    ui.character = character
    ui.action = action
    ui.perkType = perkType

    local resolvedName = perkLabel or "TESTE DE HABILIDADE"
    if string.find(resolvedName, "^UI_") then
        resolvedName = LV_SkillCheckUI.getText(resolvedName, "TESTE DE HABILIDADE")
    end
    ui.perkName = resolvedName

    ui.onSuccessCallback = onSuccess
    ui.onFailCallback = onFail

    -- Dificuldade do Sandbox (1=Facil, 2=Normal, 3=Dificil)
    local diff = (LV_Config and LV_Config.getSkillCheckDifficulty and LV_Config.getSkillCheckDifficulty()) or 2
    ui.difficulty = diff

    -- Pericia do jogador escala o tamanho da zona de sucesso
    local perkLevel = 0
    if perkType and character.getPerkLevel then
        perkLevel = character:getPerkLevel(perkType) or 0
    end

    -- Velocidade angular da agulha (graus por segundo)
    if diff == 1 then
        ui.needleSpeed = 220.0
    elseif diff == 3 then
        ui.needleSpeed = 360.0
    else
        ui.needleSpeed = 290.0
    end

    -- Tamanho da zona de acerto (aumenta com pericia, diminui com dificuldade)
    local baseSuccess = 44.0 + (perkLevel * 3.0) - (diff * 5.0)
    ui.successZoneSize = math.max(22.0, math.min(75.0, baseSuccess))

    -- Tamanho da zona critica (acerto perfeito no inicio da zona)
    local baseCrit = 8.0 + (perkLevel * 1.5) - (diff * 1.5)
    ui.criticalZoneSize = math.max(5.0, math.min(18.0, baseCrit))

    -- Angulo alvo: sorteado entre 110 e 240 graus (tempo de reacao justo)
    ui.targetAngle = 110.0 + ZombRand(130)

    -- Inicia o ciclo no estado de aviso sonoro (WARNING)
    ui.currentAngle = 0.0
    ui.warningTimer = 18 -- ~0.30s a 60fps
    ui.resultTimer = 0
    ui.resultText = ""
    ui.evaluated = false
    ui.prevSpaceDown = isKeyDown(Keyboard.KEY_SPACE)
    ui.state = "WARNING"

    -- Toca som de aviso de alerta (Ding caracteristico de DBD)
    pcall(function()
        if character.playSound then
            character:playSound("LightSwitch")
        elseif getSoundManager then
            getSoundManager():PlayWorldSound("LightSwitch", character:getSquare(), 0.5, 4, 1.0, false)
        end
    end)

    ui:setVisible(true)
    ui:bringToTop()
end

function LV_SkillCheckUI:update()
    if not self:getIsVisible() or self.state == "IDLE" then return end

    -- Se o jogador morreu ou a acao foi interrompida externamente, aborta
    if not self.character or self.character:isDead() or not self.action then
        self:closeMinigame()
        return
    end

    -- 1. Estado WARNING: Agulha parada, aguarda breve intervalo do aviso sonoro
    if self.state == "WARNING" then
        self.warningTimer = self.warningTimer - 1
        if self.warningTimer <= 0 then
            self.state = "ACTIVE"
        end
        return
    end

    -- 2. Estado RESOLVED: Mostra o texto de resultado e aguarda fechar
    if self.state == "RESOLVED" then
        self.resultTimer = self.resultTimer - 1
        if self.resultTimer <= 0 then
            self:closeMinigame()
        end
        return
    end

    -- 3. Estado ACTIVE: Agulha em movimento e checagem de input
    if self.state == "ACTIVE" then
        -- Avanco angular baseado no tempo de frame
        local delta = 0.0166 -- ~60 FPS padrao
        if UIManager and UIManager.getSecondsSinceLastRender then
            local sec = UIManager.getSecondsSinceLastRender()
            if sec and sec > 0 and sec < 0.1 then delta = sec end
        end

        self.currentAngle = self.currentAngle + (self.needleSpeed * delta)

        -- Checagem de Input (Barra de Espaco ou Joypad)
        local isSpaceDown = isKeyDown(Keyboard.KEY_SPACE)
        if JoypadState and JoypadState.players then
            local jp = JoypadState.players[1]
            if jp and jp.connected and jp.controller and jp.controller.isButtonPressed then
                if jp.controller:isButtonPressed(0) then -- Botao A
                    isSpaceDown = true
                end
            end
        end

        -- Detecta evento de clique na subida (edge-trigger)
        if isSpaceDown and not self.prevSpaceDown and not self.evaluated then
            self.evaluated = true
            self:evaluateHit(self.currentAngle)
        end
        self.prevSpaceDown = isSpaceDown

        -- Checagem de Timeout: Passou do final da zona de sucesso sem apertar
        local zoneEnd = self.targetAngle + self.successZoneSize
        if not self.evaluated and self.currentAngle > (zoneEnd + 5.0) then
            self.evaluated = true
            self:evaluateHit(self.currentAngle) -- Falha por atraso
        end

        -- Se a agulha deu a volta completa (360 graus) e ainda nao resolveu
        if not self.evaluated and self.currentAngle >= 360.0 then
            self.evaluated = true
            self:evaluateHit(self.currentAngle)
        end
    end
end

--- Avalia a precisao do acerto do jogador
function LV_SkillCheckUI:evaluateHit(hitAngle)
    local critEnd = self.targetAngle + self.criticalZoneSize
    local succEnd = self.targetAngle + self.successZoneSize

    if hitAngle >= self.targetAngle and hitAngle <= critEnd then
        -- ACERTO CRITICO (GREAT SKILL CHECK)
        self.state = "RESOLVED"
        self.resultText = LV_SkillCheckUI.getText("UI_LV_SkillCheck_Critical", "PERFEITO!")
        self.resultColor = COLOR_CRITICAL
        self.resultTimer = 22

        pcall(function()
            if self.character.playSound then
                self.character:playSound("LightSwitch")
            end
        end)

        if self.onSuccessCallback then
            pcall(self.onSuccessCallback, true)
        end

    elseif hitAngle >= self.targetAngle and hitAngle <= succEnd then
        -- ACERTO NORMAL (GOOD SKILL CHECK)
        self.state = "RESOLVED"
        self.resultText = LV_SkillCheckUI.getText("UI_LV_SkillCheck_Success", "BOM!")
        self.resultColor = COLOR_SUCCESS
        self.resultTimer = 18

        pcall(function()
            if self.character.playSound then
                self.character:playSound("LightSwitch")
            end
        end)

        if self.onSuccessCallback then
            pcall(self.onSuccessCallback, false)
        end

    else
        -- FALHA (TIMING ERRADO OU TIMEOUT)
        self.state = "RESOLVED"
        self.resultText = LV_SkillCheckUI.getText("UI_LV_SkillCheck_Fail", "FALHOU!")
        self.resultColor = COLOR_NEEDLE
        self.resultTimer = 25

        -- Efeitos de penalidade de erro
        self:handleFailure()

        if self.onFailCallback then
            pcall(self.onFailCallback)
        end
    end
end

--- Executa as penalidades quando o jogador erra o Skill Check
function LV_SkillCheckUI:handleFailure()
    local sq = self.character:getSquare()

    -- 1. Som de erro/impacto/faisca
    pcall(function()
        if getSoundManager and sq then
            getSoundManager():PlayWorldSound("BreakObject", sq, 0.8, 14, 1.0, false)
        end
    end)

    -- 2. Atrai zumbis locais pelo barulho da falha (Raio de 14 tiles)
    pcall(function()
        if addSound and sq then
            addSound(self.character, math.floor(self.character:getX()), math.floor(self.character:getY()), math.floor(self.character:getZ()), 14, 25)
        end
    end)

    -- 3. Frase de falha falada pelo sobrevivente
    pcall(function()
        local speeches = {
            LV_SkillCheckUI.getText("UI_LV_SkillCheck_FailSpeech1", "Droga! Escapou da mao!"),
            LV_SkillCheckUI.getText("UI_LV_SkillCheck_FailSpeech2", "Ai! Quase tomei um choque!"),
            LV_SkillCheckUI.getText("UI_LV_SkillCheck_FailSpeech3", "Faisca! Que susto!"),
            LV_SkillCheckUI.getText("UI_LV_SkillCheck_FailSpeech4", "Espirrou sujeira em tudo!")
        }
        local pick = speeches[ZombRand(#speeches) + 1]
        self.character:Say(pick)
    end)

    -- 4. Cancela imediatamente a acao em andamento e limpa a fila do PZ
    if self.action then
        self.action.skillCheckFailed = true
        self.action.skillCheckPending = false
        self.action.skillCheckSuccess = false
        pcall(function()
            if self.action.forceStop then
                self.action:forceStop()
            elseif self.action.stop then
                self.action:stop()
            end
        end)
    end
    if ISTimedActionQueue and self.character then
        pcall(function()
            ISTimedActionQueue.clear(self.character)
        end)
    end
end

function LV_SkillCheckUI:closeMinigame()
    self.state = "IDLE"
    self:setVisible(false)
    self.character = nil
    self.action = nil
    self.onSuccessCallback = nil
    self.onFailCallback = nil
end

--- Renderizacao da Roleta Circular estilo DBD
function LV_SkillCheckUI:render()
    if not self:getIsVisible() or self.state == "IDLE" then return end

    local cx = self.centerX
    local cy = self.centerY
    local R = self.radius

    -- 1. Fundo Circular / Card Dark Glass com Borda Suave
    self:drawRect(cx - 85, cy - 85, 170, 170, COLOR_BG_PANEL[4], COLOR_BG_PANEL[1], COLOR_BG_PANEL[2], COLOR_BG_PANEL[3])
    self:drawRectBorder(cx - 85, cy - 85, 170, 170, COLOR_BORDER[4], COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3])

    -- Cabecalho do Teste (Ex: "TESTE ELETRICO")
    self:drawTextCentre(self.perkName, cx, cy - 80, COLOR_TEXT_AMBER[1], COLOR_TEXT_AMBER[2], COLOR_TEXT_AMBER[3], 1.0, FONT_S)

    -- 2. Trilha Base do Circulo (0 a 360 graus) - Aro Grafite com Quads Confluentemente Sobrepostos
    for deg = 0, 359, 2 do
        local rad = math.rad(deg - 90)
        local cosR = math.cos(rad)
        local sinR = math.sin(rad)
        local px = cx + cosR * R
        local py = cy + sinR * R
        self:drawRect(px - 1.5, py - 1.5, 3, 3, COLOR_TRACK[4], COLOR_TRACK[1], COLOR_TRACK[2], COLOR_TRACK[3])
    end

    -- 3. Arco de Sucesso Normal (Verde Esmeralda)
    local succStart = self.targetAngle
    local succEnd = self.targetAngle + self.successZoneSize
    for deg = succStart, succEnd, 1.2 do
        local rad = math.rad(deg - 90)
        local cosR = math.cos(rad)
        local sinR = math.sin(rad)
        local px = cx + cosR * R
        local py = cy + sinR * R
        self:drawRect(px - 2.5, py - 2.5, 5, 5, COLOR_SUCCESS[4], COLOR_SUCCESS[1], COLOR_SUCCESS[2], COLOR_SUCCESS[3])
    end

    -- 4. Arco de Sucesso Critico (Dourado Solar - Great Skill Check)
    local critStart = self.targetAngle
    local critEnd = self.targetAngle + self.criticalZoneSize
    for deg = critStart, critEnd, 1.0 do
        local rad = math.rad(deg - 90)
        local cosR = math.cos(rad)
        local sinR = math.sin(rad)
        local px = cx + cosR * R
        local py = cy + sinR * R
        self:drawRect(px - 3.0, py - 3.0, 6, 6, COLOR_CRITICAL[4], COLOR_CRITICAL[1], COLOR_CRITICAL[2], COLOR_CRITICAL[3])
    end

    -- 5. Agulha Indicadora (Needle)
    local needleRad = math.rad(self.currentAngle - 90)
    local nCos = math.cos(needleRad)
    local nSin = math.sin(needleRad)

    -- Desenha a haste da agulha do centro ao raio externo
    for rStep = 12, R + 5, 4 do
        local hx = cx + nCos * rStep
        local hy = cy + nSin * rStep
        self:drawRect(hx - 1.5, hy - 1.5, 3, 3, COLOR_NEEDLE[4], COLOR_NEEDLE[1], COLOR_NEEDLE[2], COLOR_NEEDLE[3])
    end
    -- Cabeca da Agulha (Ponta destacada)
    local tipX = cx + nCos * (R + 4)
    local tipY = cy + nSin * (R + 4)
    self:drawRect(tipX - 3, tipY - 3, 6, 6, 1.0, 1.0, 1.0, 1.0)

    -- 6. Nucleo Central (Dark Metallic Hub)
    self:drawRect(cx - 16, cy - 16, 32, 32, COLOR_CENTER[4], COLOR_CENTER[1], COLOR_CENTER[2], COLOR_CENTER[3])
    self:drawRectBorder(cx - 16, cy - 16, 32, 32, 0.6, COLOR_TEXT_AMBER[1], COLOR_TEXT_AMBER[2], COLOR_TEXT_AMBER[3])

    -- 7. Texto Central: Indicador de Tecla ou Mensagem de Resultado
    if self.state == "RESOLVED" then
        self:drawTextCentre(self.resultText, cx, cy - 8, self.resultColor[1], self.resultColor[2], self.resultColor[3], 1.0, FONT_M)
    else
        local prompt = LV_SkillCheckUI.getText("UI_LV_SkillCheck_Prompt", "[ESPACO]")
        self:drawTextCentre(prompt, cx, cy - 7, COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3], 0.90, FONT_S)
    end
end

-- =============================================================================
-- SISTEMA DE RECOMPENSA DE XP & MULTIPLICADORES TEMPORARIOS
-- =============================================================================

--- Concede XP e multiplicador temporario de foco para a pericia correspondente
-- @param character IsoPlayer
-- @param perk PerkFactory.Perks (ex: Perks.Electricity)
-- @param baseAmount number (XP base concedido)
-- @param isCritical boolean (se acertou a zona critica)
-- @param boostHours number (duracao do multiplicador em horas de jogo, padrao 2.0)
-- @param boostMultiplier number (ex: 1.5 = +50%)
-- @param boostLabel string (nome do buff para feedback)
function LV_SkillCheckUI.grantXpAndBoost(character, perk, baseAmount, isCritical, boostHours, boostMultiplier, boostLabel)
    if not character or not perk then return end

    local xpAmount = baseAmount or 15
    if isCritical then
        xpAmount = math.floor(xpAmount * 2.0)
    end

    -- 1. Concede o XP imediato
    if character.getXp and character:getXp().AddXP then
        pcall(function()
            character:getXp():AddXP(perk, xpAmount)
        end)
    end

    -- 2. Concede o multiplicador temporario nativo do PZ
    local multiplier = boostMultiplier or 1.5
    local hours = boostHours or 2.0
    local label = boostLabel or "Foco Aprimorado"
    if string.find(label, "^UI_") then
        label = LV_SkillCheckUI.getText(label, "Foco Aprimorado")
    end

    if character.getXp and character:getXp().addXpMultiplier and getGameTime then
        pcall(function()
            character:getXp():addXpMultiplier(perk, multiplier, 0, 10)

            local pData = character:getModData()
            pData.LV_SkillCheckBoosts = pData.LV_SkillCheckBoosts or {}
            local perkKey = (perk.getIdStr and perk:getIdStr()) or tostring(perk)

            pData.LV_SkillCheckBoosts[perkKey] = {
                perk = perk,
                expireTime = getGameTime():getWorldAgeHours() + hours,
                multiplier = multiplier,
                label = label
            }
        end)
    end

    -- 3. Feedback visual (Halo Note)
    if character.setHaloNote then
        pcall(function()
            local note = string.format("+%d XP (%s)%s", xpAmount, label, isCritical and " [CRITICO!]" or "")
            character:setHaloNote(note, 120, 240, 160, 220)
        end)
    end
end

--- Varredura periodica para expirar multiplicadores de XP temporarios
local function checkExpiringBoosts()
    local character = getPlayer()
    if not character or not getGameTime then return end

    local pData = character:getModData()
    if not pData or not pData.LV_SkillCheckBoosts then return end

    local currentAge = getGameTime():getWorldAgeHours()
    local remaining = {}
    local hasExpired = false

    for perkKey, boost in pairs(pData.LV_SkillCheckBoosts) do
        if currentAge >= boost.expireTime then
            hasExpired = true
            -- Restaura o multiplicador padrao (1.0x) para a pericia
            pcall(function()
                if character.getXp and character:getXp().addXpMultiplier then
                    character:getXp():addXpMultiplier(boost.perk, 1.0, 0, 10)
                end
            end)
        else
            remaining[perkKey] = boost
        end
    end

    pData.LV_SkillCheckBoosts = remaining

    if hasExpired and character.setHaloNote then
        pcall(function()
            character:setHaloNote("O foco de aprendizado se dissipou.", 180, 180, 200, 180)
        end)
    end
end

Events.EveryTenMinutes.Add(checkExpiringBoosts)
