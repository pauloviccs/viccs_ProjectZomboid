-- =============================================================================
-- Project Zomboid TCG - Visual Theme & Design Tokens (Frameless Soft Glass)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Padrao visual unificado inspirado em LV_HouseDashboard e CHStatusHUD.
--   Fornece paleta de cores HSL adaptada, anti-overlap e utilitarios de desenho,
--   incluindo renderizacao com fisica de inclinacao 3D (Hover Tilt),
--   shimmer prismatico/holografico e sistema de audio tatico.
-- =============================================================================

TCG_Theme = TCG_Theme or {}

-- Paleta Soft Glass
TCG_Theme.BG_ALPHA      = 0.92
TCG_Theme.BG_R          = 0.03
TCG_Theme.BG_G          = 0.035
TCG_Theme.BG_B          = 0.045

TCG_Theme.CYAN          = {0.36, 0.76, 0.86}
TCG_Theme.AMBER         = {0.92, 0.71, 0.29}
TCG_Theme.GREEN         = {0.30, 0.85, 0.50}
TCG_Theme.PURPLE        = {0.72, 0.45, 0.92}
TCG_Theme.RED           = {0.95, 0.25, 0.25}
TCG_Theme.GOLD          = {0.98, 0.82, 0.32}

TCG_Theme.TEXT_WHITE    = {0.88, 0.92, 0.96}
TCG_Theme.TEXT_MUTED    = {0.55, 0.60, 0.65}
TCG_Theme.BORDER_ALPHA  = 0.22

-- Paletas Tematicas de Cores do Fichario
TCG_Theme.THEMES = {
    CYAN     = { name = "Ciano",     col = {0.36, 0.76, 0.86} },
    RUBY     = { name = "Rubi",      col = {0.95, 0.28, 0.25} },
    SAPPHIRE = { name = "Safira",    col = {0.22, 0.58, 0.98} },
    EMERALD  = { name = "Esmeralda", col = {0.25, 0.85, 0.45} },
    GOLD     = { name = "Ouro",      col = {0.98, 0.82, 0.25} },
    AMETHYST = { name = "Ametista",  col = {0.75, 0.38, 0.95} }
}

TCG_Theme.THEME_KEYS = { "CYAN", "RUBY", "SAPPHIRE", "EMERALD", "GOLD", "AMETHYST" }

TCG_Theme.BADGES = {
    "COLLECTOR",
    "MASTER",
    "HOLO",
    "TRADES",
    "VINTAGE",
    "COMPLETE"
}

TCG_Theme.BADGE_LABELS = {
    COLLECTOR = { pt = "[COLECIONADOR]", en = "[COLLECTOR]" },
    MASTER    = { pt = "[* MESTRE]",      en = "[* MASTER]" },
    HOLO      = { pt = "[+ HOLO ONLY]",  en = "[+ HOLO ONLY]" },
    TRADES    = { pt = "[= TROCAS]",     en = "[= TRADES]" },
    VINTAGE   = { pt = "[1999 VINTAGE]", en = "[1999 VINTAGE]" },
    COMPLETE  = { pt = "[# COMPLETO]",   en = "[# COMPLETE]" }
}

--- Desenha o fundo Soft Glass escuro com a linha de destaque lateral personalizada
function TCG_Theme.drawGlassBackdrop(panel, x, y, w, h, showAccent, customAccentColor)
    -- Fundo translucido escuro
    panel:drawRect(x, y, w, h, TCG_Theme.BG_ALPHA, TCG_Theme.BG_R, TCG_Theme.BG_G, TCG_Theme.BG_B)
    
    -- Borda fina esbranquicada suave
    panel:drawRectBorder(x, y, w, h, TCG_Theme.BORDER_ALPHA, 1.0, 1.0, 1.0)

    -- Linha de acento lateral esquerda (2px)
    if showAccent ~= false then
        local c = customAccentColor or TCG_Theme.CYAN
        panel:drawRect(x, y, 2, h, 0.95, c[1], c[2], c[3])
    end
end

--- Desenha o botao de fechar [X] elegante
function TCG_Theme.drawCloseButton(panel, x, y, w, h, isHovered)
    local col = isHovered and TCG_Theme.RED or TCG_Theme.TEXT_MUTED
    local alpha = isHovered and 1.0 or 0.75
    local bgAlpha = isHovered and 0.20 or 0.0
    if bgAlpha > 0 then
        panel:drawRect(x, y, w, h, bgAlpha, col[1], col[2], col[3])
        panel:drawRectBorder(x, y, w, h, 0.40, col[1], col[2], col[3])
    end
    panel:drawTextCentre("[X]", x + (w / 2), y + 2, col[1], col[2], col[3], alpha, UIFont.Small)
end

--- Desenha o botao de Grip/Arrasto dedicado [M]
function TCG_Theme.drawDragGrip(panel, x, y, w, h, isHovered, isDragging)
    local col = isDragging and TCG_Theme.GOLD or (isHovered and TCG_Theme.CYAN or TCG_Theme.TEXT_MUTED)
    local alpha = (isDragging or isHovered) and 1.0 or 0.60
    local bgAlpha = (isDragging or isHovered) and 0.25 or 0.05
    panel:drawRect(x, y, w, h, bgAlpha, col[1], col[2], col[3])
    panel:drawRectBorder(x, y, w, h, (isDragging or isHovered) and 0.50 or 0.15, col[1], col[2], col[3])
    panel:drawTextCentre("[M]", x + (w / 2), y + 2, col[1], col[2], col[3], alpha, UIFont.Small)
end

--- Desenha um botao no estilo tatica [NOME] com efeito de hover
function TCG_Theme.drawTacticalButton(panel, label, x, y, w, h, isHovered, customColor)
    local col = customColor or TCG_Theme.CYAN
    local bgAlpha = isHovered and 0.25 or 0.08
    local textAlpha = isHovered and 1.0 or 0.85

    -- Fundo sutil do botao
    panel:drawRect(x, y, w, h, bgAlpha, col[1], col[2], col[3])
    panel:drawRectBorder(x, y, w, h, isHovered and 0.50 or 0.18, col[1], col[2], col[3])

    -- Texto centralizado
    local formatted = "[" .. tostring(label) .. "]"
    local tm = getTextManager()
    local textW = tm:MeasureStringX(UIFont.Small, formatted)
    local textH = tm:getFontHeight(UIFont.Small)
    local textX = x + math.floor((w - textW) / 2)
    local textY = y + math.floor((h - textH) / 2)

    panel:drawText(formatted, textX, textY, col[1], col[2], col[3], textAlpha, UIFont.Small)
end

--- Desenha texto com quebra de linha automatica dentro de maxW
function TCG_Theme.drawTextWrapped(panel, text, x, y, maxW, r, g, b, a, font)
    if not text or text == "" then return y end
    font = font or UIFont.Small
    local tm = getTextManager()
    local fontH = tm:getFontHeight(font)
    local curY = y
    local curLine = ""

    for word in string.gmatch(text, "%S+") do
        local testLine = (curLine == "") and word or (curLine .. " " .. word)
        local testW = tm:MeasureStringX(font, testLine)
        if testW > maxW and curLine ~= "" then
            panel:drawText(curLine, x, curY, r, g, b, a, font)
            curY = curY + fontH + 2
            curLine = word
        else
            curLine = testLine
        end
    end

    if curLine ~= "" then
        panel:drawText(curLine, x, curY, r, g, b, a, font)
        curY = curY + fontH + 2
    end

    return curY
end

--- Retorna a cor de destaque para uma determinada raridade
function TCG_Theme.getRarityColor(rarity, isHolo)
    if isHolo then
        return TCG_Theme.GOLD
    end
    if rarity == "Rare" or rarity == "Rara" then
        return TCG_Theme.PURPLE
    elseif rarity == "Uncommon" or rarity == "Incomum" then
        return TCG_Theme.CYAN
    end
    return TCG_Theme.TEXT_MUTED
end

--- Executa efeito sonoro do jogo de forma segura e encapsulada
function TCG_Theme.playAudio(soundName, fallbackSound)
    pcall(function()
        local player = getPlayer()
        if player and player.playSoundLocal then
            local snd = player:playSoundLocal(soundName)
            if snd and snd ~= 0 then return end
        end
        if player and player.playSound then
            local snd = player:playSound(soundName)
            if snd and snd ~= 0 then return end
        end
        local sm = getSoundManager()
        if sm and sm.playUISound then
            sm:playUISound(soundName)
            return
        end
        if fallbackSound then
            if player and player.playSoundLocal then
                player:playSoundLocal(fallbackSound)
            elseif player and player.playSound then
                player:playSound(fallbackSound)
            elseif sm and sm.playUISound then
                sm:playUISound(fallbackSound)
            end
        end
    end)
end

--- Toca som de folhear folha / virar pagina
function TCG_Theme.playPageTurn()
    TCG_Theme.playAudio("TCG_TurnPageBinder", "PageTurn")
end

-- Alias de compatibilidade para chamadas invertidas
TCG_Theme.playTurnPage = TCG_Theme.playPageTurn

--- Toca som de abrir o fichario / livro
function TCG_Theme.playBookOpen()
    TCG_Theme.playAudio("TCG_OpenBinder", "BookOpen")
end

--- Toca som de fechar o fichario / livro
function TCG_Theme.playBookClose()
    TCG_Theme.playAudio("TCG_CloseBinder", "BookClose")
end

--- Toca som de colocar / encaixar carta no sleeve ou auto-guardar
function TCG_Theme.playCardSlot()
    TCG_Theme.playAudio("TCG_StoreAllCards", "ItemPlacement")
end

--- Toca som de retirar carta do fichario
function TCG_Theme.playCardTake()
    TCG_Theme.playAudio("TCG_WithdrawCard", "ItemPickup")
end

--- Toca som de trocar de aba de expansao (folheamento de divisoria)
function TCG_Theme.playTabSwitch()
    TCG_Theme.playAudio("TCG_NextCategoryBinder", "PageTurn")
end

--- Toca som de clique tatica em botao
function TCG_Theme.playButtonClick()
    TCG_Theme.playAudio("TCG_ButtonDefault", "UI_ButtonSelect")
end

--- Toca som de inspecionar carta
function TCG_Theme.playInspectCard(isHolo)
    if isHolo then
        TCG_Theme.playAudio("TCG_PrismaticCard", "GainExperienceLevel")
    else
        TCG_Theme.playAudio("TCG_InspectCard", "PageTurn")
    end
end

--- Toca som de abrir pacote de booster
function TCG_Theme.playBoosterOpen()
    TCG_Theme.playAudio("TCG_BoosterOpen", "OpenBag")
end

--- Toca som de deslizar para a proxima carta do booster
function TCG_Theme.playNextCard()
    TCG_Theme.playAudio("TCG_NextCardBoosterpack", "PageTurn")
end

--- Toca som de revelacao baseado na raridade da carta
function TCG_Theme.playRarityReveal(rarity, isHolo)
    if isHolo then
        TCG_Theme.playAudio("TCG_PrismaticCard", "GainExperienceLevel")
        return
    end
    if rarity == "Rare Holo" or rarity == "Secret Rare" then
        TCG_Theme.playAudio("TCG_PrismaticHolo", "Sparkle")
    elseif rarity == "Rare" then
        TCG_Theme.playAudio("TCG_CardThreeStar", "LevelUp")
    elseif rarity == "Uncommon" then
        TCG_Theme.playAudio("TCG_CardTwoStar", "GainExperience")
    else
        TCG_Theme.playAudio("TCG_CardOneStar", "UI_ToggleOff")
    end
end

-- Aliases de compatibilidade total para invocacao de audio segura (previne crashes por chamada de nil)
TCG_Theme.playTurnPage = TCG_Theme.playPageTurn
TCG_Theme.playOpenBinder = TCG_Theme.playBookOpen
TCG_Theme.playCloseBinder = TCG_Theme.playBookClose
TCG_Theme.playCardWithdraw = TCG_Theme.playCardTake
TCG_Theme.playTakeCard = TCG_Theme.playCardTake
TCG_Theme.playNextCategory = TCG_Theme.playTabSwitch
TCG_Theme.playOpenBooster = TCG_Theme.playBoosterOpen

--- Desenha um segmento de reta geometricamente fechado e com espessura uniforme,
--- eliminando quaisquer artefatos de projecao ou linhas espelhadas na tela do jogo (DrawTexture degenerate quad bug).
function TCG_Theme.drawSegment(panel, x1, y1, x2, y2, thickness, r, g, b, a)
    if not panel or not panel.drawPolygon or not a or a <= 0.001 then return end
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then return end
    local halfW = (thickness or 1.0) * 0.5
    local nx = (-dy / len) * halfW
    local ny = (dx / len) * halfW
    panel:drawPolygon(nil,
        x1 - nx, y1 - ny,
        x2 - nx, y2 - ny,
        x2 + nx, y2 + ny,
        x1 + nx, y1 + ny,
        r, g, b, a
    )
end


--- Renderiza uma carta com fisica 3D solida e rigida (Scrydex Rigid Card Engine),
--- espessura fisica de cardstock chanfrada (3D bevel), brilho especular diagonal suave,
--- dispersao de arco-iris holografica e particulas estelares.
function TCG_Theme.drawCardWith3DHover(panel, texture, cardX, cardY, cardW, cardH, mouseX, mouseY, isHolo, time)
    time = time or 0
    local cx = cardX + (cardW / 2)
    local cy = cardY + (cardH / 2)

    -- 1. Deteccao de Hover e coordenadas normalizadas (-1.0 a +1.0)
    local isHovered = (mouseX >= cardX and mouseX <= (cardX + cardW) and mouseY >= cardY and mouseY <= (cardY + cardH))
    local targetPX = 0.0
    local targetPY = 0.0

    if isHovered then
        targetPX = math.max(-1.0, math.min(1.0, (mouseX - cx) / (cardW / 2)))
        targetPY = math.max(-1.0, math.min(1.0, (mouseY - cy) / (cardH / 2)))
    end

    -- Amortecimento suave de inercia (Spring Lerp) para transicao fluida e estavel
    panel._tcgCurrentPX = (panel._tcgCurrentPX or 0.0) + ((targetPX - (panel._tcgCurrentPX or 0.0)) * 0.20)
    panel._tcgCurrentPY = (panel._tcgCurrentPY or 0.0) + ((targetPY - (panel._tcgCurrentPY or 0.0)) * 0.20)
    local hoverTarget = isHovered and 1.0 or 0.0
    panel._tcgCurrentHover = (panel._tcgCurrentHover or 0.0) + ((hoverTarget - (panel._tcgCurrentHover or 0.0)) * 0.18)

    local px = panel._tcgCurrentPX
    local py = panel._tcgCurrentPY
    local hFactor = panel._tcgCurrentHover

    if not isHovered and math.abs(px) < 0.001 and math.abs(py) < 0.001 and hFactor < 0.005 then
        px = 0.0
        py = 0.0
        hFactor = 0.0
    end

    -- 2. Transformacao 3D Rigida (Rigid Planar Card - Scrydex Engine)
    -- Angulo sutil e refinado: ~7.5 graus maximos (0.13 rad). 
    -- Usa projecao afim linear pura (ortografica 3D):
    -- Mantem bordas opostas rigorosamente paralelas.
    -- Elimina 100% qualquer distorcao diagonal de tecido/borracha
    -- causada pela interpolacao afim dos 2 triangulos do SpriteRenderer do PZ.
    local maxAngle = 0.13
    local rotX = py * maxAngle
    local rotY = -px * maxAngle
    
    local cosX, sinX = math.cos(rotX), math.sin(rotX)
    local cosY, sinY = math.cos(rotY), math.sin(rotY)

    local scale = 1.0 + (hFactor * 0.035)

    local function project3D(X, Y, Z)
        -- Rotacao pura Yaw (eixo Y)
        local x1 = X * cosY + Z * sinY
        local y1 = Y
        local z1 = -X * sinY + Z * cosY

        -- Rotacao pura Pitch (eixo X)
        local x2 = x1
        local y2 = y1 * cosX - z1 * sinX
        local z2 = y1 * sinX + z1 * cosX

        -- Projecao afim estritamente linear (Zero distorcao diagonal de tecido)
        return cx + (x2 * scale), cy + (y2 * scale), z2
    end

    local w2 = cardW / 2
    local h2 = cardH / 2
    local cardThickness = 2.5 -- Espessura fina e precisa de cardstock em pixels 3D

    -- 4 vertices da face frontal (Z = 0)
    -- Ordem nativa PZ UIElement: Top-Left, Top-Right, Bottom-Right, Bottom-Left
    local f1x, f1y = project3D(-w2, -h2, 0)
    local f2x, f2y = project3D( w2, -h2, 0)
    local f3x, f3y = project3D( w2,  h2, 0)
    local f4x, f4y = project3D(-w2,  h2, 0)

    -- 4 vertices da face traseira (Z = -cardThickness)
    local b1x, b1y = project3D(-w2, -h2, -cardThickness)
    local b2x, b2y = project3D( w2, -h2, -cardThickness)
    local b3x, b3y = project3D( w2,  h2, -cardThickness)
    local b4x, b4y = project3D(-w2,  h2, -cardThickness)

    -- 3. Sombra Dinamica Projetada (Floating Drop Shadow)
    -- A sombra se desloca no sentido oposto a inclinacao da carta
    local sOffX = -px * 14
    local sOffY = -py * 14 + (10 * hFactor)
    local sAlpha = (0.22 + (0.22 * hFactor))

    -- Sombra difusa externa
    panel:drawPolygon(nil,
        f1x + sOffX - 4, f1y + sOffY - 4,
        f2x + sOffX + 4, f2y + sOffY - 4,
        f3x + sOffX + 4, f3y + sOffY + 6,
        f4x + sOffX - 4, f4y + sOffY + 6,
        0, 0, 0, sAlpha * 0.45)

    -- Sombra oclusiva de contato
    panel:drawPolygon(nil,
        f1x + sOffX, f1y + sOffY,
        f2x + sOffX, f2y + sOffY,
        f3x + sOffX, f3y + sOffY,
        f4x + sOffX, f4y + sOffY,
        0, 0, 0, sAlpha)

    -- 4. Borda Chanfrada de Cardstock 3D (Physical Edge Bevel)
    -- Desenhadas antes da face frontal (Painter's Algorithm)
    if px > 0.02 then
        -- Borda Esquerda exposta (relevo escurecido)
        panel:drawPolygon(nil, f1x, f1y, b1x, b1y, b4x, b4y, f4x, f4y, 0.10, 0.11, 0.14, 0.95)
    elseif px < -0.02 then
        -- Borda Direita exposta (relevo escurecido)
        panel:drawPolygon(nil, b2x, b2y, f2x, f2y, f3x, f3y, b3x, b3y, 0.10, 0.11, 0.14, 0.95)
    end
    if py > 0.02 then
        -- Borda Superior exposta a iluminacao zenital
        panel:drawPolygon(nil, f1x, f1y, f2x, f2y, b2x, b2y, b1x, b1y, 0.22, 0.24, 0.28, 0.95)
    elseif py < -0.02 then
        -- Borda Inferior sombreada
        panel:drawPolygon(nil, b4x, b4y, b3x, b3y, f3x, f3y, f4x, f4y, 0.08, 0.09, 0.11, 0.95)
    end

    -- 5. Face Frontal da Carta (Mapeamento de Textura no Poligono 3D)
    if texture then
        panel:drawPolygon(texture, f1x, f1y, f2x, f2y, f3x, f3y, f4x, f4y, 1.0, 1.0, 1.0, 1.0)
    else
        panel:drawPolygon(nil, f1x, f1y, f2x, f2y, f3x, f3y, f4x, f4y, 0.08, 0.09, 0.12, 1.0)
    end

    -- Funcao utilitaria de interpolacao bilinear na malha trapezoidal 3D
    local function interpUV(u, v)
        local topX = f1x + (f2x - f1x) * u
        local topY = f1y + (f2y - f1y) * u
        local botX = f4x + (f3x - f4x) * u
        local botY = f4y + (f3y - f4y) * u
        return topX + (botX - topX) * v, topY + (botY - topY) * v
    end

    -- 6. Brilho Especular Diagonal (Scrydex Glass Glare)
    if hFactor > 0.05 then
        local centerU = (px + 1.0) * 0.5
        local glareW = 0.16
        local gU1 = math.max(0.0, math.min(1.0, centerU - 0.08 - glareW))
        local gU2 = math.max(0.0, math.min(1.0, centerU - 0.08 + glareW))
        local gU3 = math.max(0.0, math.min(1.0, centerU + 0.08 + glareW))
        local gU4 = math.max(0.0, math.min(1.0, centerU + 0.08 - glareW))

        local g1x, g1y = interpUV(gU1, 0.0)
        local g2x, g2y = interpUV(gU2, 0.0)
        local g3x, g3y = interpUV(gU3, 1.0)
        local g4x, g4y = interpUV(gU4, 1.0)
        panel:drawPolygon(nil, g1x, g1y, g2x, g2y, g3x, g3y, g4x, g4y, 1.0, 1.0, 1.0, 0.12 * hFactor)

        -- Feixe central de alta intensidade (Core Glare)
        local coreW = 0.04
        local c1x, c1y = interpUV(math.max(0.0, math.min(1.0, centerU - 0.08 - coreW)), 0.0)
        local c2x, c2y = interpUV(math.max(0.0, math.min(1.0, centerU - 0.08 + coreW)), 0.0)
        local c3x, c3y = interpUV(math.max(0.0, math.min(1.0, centerU + 0.08 + coreW)), 1.0)
        local c4x, c4y = interpUV(math.max(0.0, math.min(1.0, centerU + 0.08 - coreW)), 1.0)
        panel:drawPolygon(nil, c1x, c1y, c2x, c2y, c3x, c3y, c4x, c4y, 1.0, 1.0, 1.0, 0.18 * hFactor)
    end

    -- 7. Efeito Holografico Foil Prismatico (Scrydex Holofoil)
    if isHolo then
        local bandCount = 4
        for k = 1, bandCount do
            local phase = (time * 2.5) + (px * 2.5) + (py * 1.2) + (k * 1.3)
            local r = 0.5 + 0.48 * math.sin(phase)
            local g = 0.5 + 0.48 * math.sin(phase + 2.094)
            local b = 0.5 + 0.48 * math.sin(phase + 4.188)

            local bPos = ((k - 1) / (bandCount - 1)) + (px * 0.12)
            local bU1 = math.max(0.0, math.min(1.0, bPos - 0.16))
            local bU2 = math.max(0.0, math.min(1.0, bPos - 0.03))
            local bU3 = math.max(0.0, math.min(1.0, bPos + 0.10))
            local bU4 = math.max(0.0, math.min(1.0, bPos - 0.03))

            local bk1x, bk1y = interpUV(bU1, 0.0)
            local bk2x, bk2y = interpUV(bU2, 0.0)
            local bk3x, bk3y = interpUV(bU3, 1.0)
            local bk4x, bk4y = interpUV(bU4, 1.0)

            local holoAlpha = (0.09 + (0.10 * hFactor))
            panel:drawPolygon(nil, bk1x, bk1y, bk2x, bk2y, bk3x, bk3y, bk4x, bk4y, r, g, b, holoAlpha)
        end

        -- Particulas estelares cintilantes (Glimmer Stars)
        local sparkCount = 5
        for i = 1, sparkCount do
            local uStar = 0.15 + (0.70 * ((i * 37) % 100) / 100)
            local vStar = 0.12 + (0.50 * ((i * 59) % 100) / 100)
            local phase = (time * 4.0) + (i * 1.57) + (px * 2.0)
            local sAlpha = math.max(0.0, math.sin(phase))
            if sAlpha > 0.35 then
                local sx, sy = interpUV(uStar, vStar)
                panel:drawPolygon(nil, sx - 3, sy, sx, sy - 3, sx + 3, sy, sx, sy + 3, 1.0, 1.0, 0.85, sAlpha * 0.85)
                panel:drawPolygon(nil, sx - 1, sy - 1, sx + 1, sy - 1, sx + 1, sy + 1, sx - 1, sy + 1, 1.0, 1.0, 1.0, sAlpha)
            end
        end

        -- Moldura dourada exterior conectando os vertices projetados da carta holografica
        local pulse = 0.65 + 0.35 * math.sin(time * 3.0)
        local gr, gg, gb = TCG_Theme.GOLD[1], TCG_Theme.GOLD[2], TCG_Theme.GOLD[3]
        local rimAlpha = math.min(1.0, pulse * 0.75)
        TCG_Theme.drawSegment(panel, f1x, f1y, f2x, f2y, 1.2, gr, gg, gb, rimAlpha)
        TCG_Theme.drawSegment(panel, f2x, f2y, f3x, f3y, 1.2, gr, gg, gb, rimAlpha)
        TCG_Theme.drawSegment(panel, f3x, f3y, f4x, f4y, 1.2, gr, gg, gb, rimAlpha)
        TCG_Theme.drawSegment(panel, f4x, f4y, f1x, f1y, 1.2, gr, gg, gb, rimAlpha)
    end
end
