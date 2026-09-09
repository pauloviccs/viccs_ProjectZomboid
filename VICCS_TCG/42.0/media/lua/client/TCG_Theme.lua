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
        local sm = getSoundManager()
        if sm and sm.playUISound then
            sm:playUISound(soundName)
            return
        end
        local player = getPlayer()
        if player and player.playSound then
            player:playSound(soundName)
            return
        end
        if fallbackSound and sm and sm.playUISound then
            sm:playUISound(fallbackSound)
        end
    end)
end

--- Renderiza uma carta com simulacao fisica de perspectiva 3D, iluminacao especular e shimmer holografico
function TCG_Theme.drawCardWith3DHover(panel, texture, cardX, cardY, cardW, cardH, mouseX, mouseY, isHolo, time)
    time = time or 0
    local cx = cardX + (cardW / 2)
    local cy = cardY + (cardH / 2)

    -- Detecta se o mouse esta em cima da carta
    local isHovered = (mouseX >= cardX and mouseX <= (cardX + cardW) and mouseY >= cardY and mouseY <= (cardY + cardH))
    local normX = 0
    local normY = 0

    if isHovered then
        normX = math.max(-1.0, math.min(1.0, (mouseX - cx) / (cardW / 2)))
        normY = math.max(-1.0, math.min(1.0, (mouseY - cy) / (cardH / 2)))
    end

    -- Deslocamento 3D sutil baseado na inclinacao
    local tiltX = math.floor(normX * 7)
    local tiltY = math.floor(normY * 7)
    local renderX = cardX + tiltX
    local renderY = cardY + tiltY

    -- 1. Sombra Dinamica Projetada
    local shadowOffset = isHovered and 10 or 4
    local shadowAlpha = isHovered and 0.45 or 0.25
    panel:drawRect(renderX + (shadowOffset / 2), renderY + shadowOffset, cardW, cardH, shadowAlpha, 0, 0, 0)

    -- 2. Renderizacao da Textura da Carta
    if texture then
        panel:drawTextureScaled(texture, renderX, renderY, cardW, cardH, 1.0)
    else
        panel:drawRect(renderX, renderY, cardW, cardH, 0.90, 0.08, 0.09, 0.12)
        panel:drawRectBorder(renderX, renderY, cardW, cardH, 0.40, 1, 1, 1)
    end

    -- 3. Efeito de Brilho Especular (Gloss Glare)
    if isHovered then
        local glareX = renderX + (cardW * 0.5) + (normX * (cardW * 0.35)) - 30
        local glareY = renderY + (cardH * 0.5) + (normY * (cardH * 0.35)) - 40
        panel:drawRect(math.max(renderX, glareX), math.max(renderY, glareY), 60, 80, 0.12, 1.0, 1.0, 1.0)
    end

    -- 4. Efeito Foil / Holografico Prismatico
    if isHolo then
        -- Cores prismaticas do arco-iris
        local r = 0.5 + 0.45 * math.sin(time * 2.5 + normX * 2.0)
        local g = 0.5 + 0.45 * math.sin(time * 2.5 + normX * 2.0 + 2.09)
        local b = 0.5 + 0.45 * math.sin(time * 2.5 + normX * 2.0 + 4.18)

        -- Shimmer sobre a arte da carta (area superior da carta)
        local artX = renderX + 16
        local artY = renderY + 34
        local artW = cardW - 32
        local artH = math.floor(cardH * 0.48)
        local shimmerAlpha = isHovered and 0.32 or 0.18

        panel:drawRect(artX, artY, artW, artH, shimmerAlpha, r, g, b)
        panel:drawRectBorder(artX, artY, artW, artH, 0.45, r, g, b)

        -- Particulas de brilho estelar (Glimmer Sparks)
        local sparkCount = 4
        for i = 1, sparkCount do
            local phase = time * 4.0 + (i * 1.57)
            local sparkAlpha = math.max(0.0, math.sin(phase))
            if sparkAlpha > 0.3 then
                local sx = artX + math.floor((artW * (0.2 + (0.6 * ((i * 37) % 100) / 100))))
                local sy = artY + math.floor((artH * (0.2 + (0.6 * ((i * 59) % 100) / 100))))
                panel:drawRect(sx, sy, 3, 3, sparkAlpha * 0.90, 1.0, 1.0, 1.0)
                panel:drawRect(sx - 1, sy + 1, 5, 1, sparkAlpha * 0.60, 1.0, 1.0, 0.8)
                panel:drawRect(sx + 1, sy - 1, 1, 5, sparkAlpha * 0.60, 1.0, 1.0, 0.8)
            end
        end

        -- Moldura dourada pulsante
        local pulse = 0.65 + 0.35 * math.sin(time * 3.0)
        panel:drawRectBorder(renderX - 2, renderY - 2, cardW + 4, cardH + 4, pulse, TCG_Theme.GOLD[1], TCG_Theme.GOLD[2], TCG_Theme.GOLD[3])
    else
        -- Borda suave comum
        panel:drawRectBorder(renderX, renderY, cardW, cardH, isHovered and 0.45 or 0.20, 1.0, 1.0, 1.0)
    end
end
