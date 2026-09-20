-- media/lua/client/VICCS/UI/VICCS_UI_Theme.lua
-- Alias/Require para garantir que o Theme esteja carregado

require "VICCS/VICCS_UI_Theme"

VICCS = VICCS or {}
VICCS.UI = VICCS.UI or {}
if not VICCS.UI.Theme then
    VICCS.UI.Theme = {
        Colors = {
            GlassBg = { r = 0.07, g = 0.08, b = 0.11, a = 0.88 },
            GlassBgHeader = { r = 0.11, g = 0.13, b = 0.18, a = 0.95 },
            GlassBorder = { r = 0.24, g = 0.28, b = 0.38, a = 0.85 },
            GlassBorderGlow = { r = 0.0, g = 0.85, b = 1.0, a = 0.40 },
            ScreenInner = { r = 0.03, g = 0.04, b = 0.05, a = 0.96 },
            ScreenBorder = { r = 0.18, g = 0.20, b = 0.25, a = 0.90 },
            Cyan = { r = 0.0, g = 0.90, b = 1.0, a = 1.0 },
            Amber = { r = 1.0, g = 0.72, b = 0.0, a = 1.0 },
            Green = { r = 0.20, g = 0.95, b = 0.45, a = 1.0 },
            Red = { r = 1.0, g = 0.25, b = 0.25, a = 1.0 },
            TextPrimary = { r = 0.95, g = 0.96, b = 0.98, a = 1.0 },
            TextSecondary = { r = 0.70, g = 0.75, b = 0.85, a = 1.0 },
            TextMuted = { r = 0.45, g = 0.48, b = 0.55, a = 1.0 },
            ButtonBg = { r = 0.14, g = 0.17, b = 0.24, a = 0.90 },
            ButtonBgHover = { r = 0.20, g = 0.25, b = 0.35, a = 0.95 },
            ButtonBorder = { r = 0.30, g = 0.36, b = 0.48, a = 0.90 },
            ButtonBorderActive = { r = 0.0, g = 0.90, b = 1.0, a = 1.0 },
            SliderTrack = { r = 0.12, g = 0.14, b = 0.18, a = 1.0 },
            SliderFill = { r = 0.0, g = 0.85, b = 1.0, a = 1.0 },
            SliderKnob = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
        }
    }
end
