-- =============================================================================
-- Housing Care System (Lar Vivo) - Moodle Definitions (LV_MoodleDefs.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Dicionário central e catálogo de metadados para todos os Tiers de Conforto
--   e Insalubridade (Squalor), além dos buffs estendidos opcionais.
--   Mapeia títulos, descrições e ícones do vanilla para renderização nativa.
-- =============================================================================

LV_MoodleDefs = LV_MoodleDefs or {}

--- Tiers de Conforto (Buffs positivos)
LV_MoodleDefs.ComfortTiers = {
    [1] = {
        id = "LV_Tier1",
        titleKey = "UI_LV_Tier1_Title",
        descKey = "UI_LV_Tier1_Desc",
        defaultTitle = "Aconchego Basico (Tier I)",
        defaultDesc = "Reduz o ganho de panico em 10%.",
        color = {r=0.4, g=0.8, b=0.4},
        vanillaIcon = "media/ui/Moodle_Bored_Good.png",
    },
    [2] = {
        id = "LV_Tier2",
        titleKey = "UI_LV_Tier2_Title",
        descKey = "UI_LV_Tier2_Desc",
        defaultTitle = "Lar Organizado (Tier II)",
        defaultDesc = "Reduz o panico em 20% e acelera a regeneracao de resistencia (Endurance) em 10%.",
        color = {r=0.3, g=0.9, b=0.3},
        vanillaIcon = "media/ui/Moodle_Endurance_Good.png",
    },
    [3] = {
        id = "LV_Tier3",
        titleKey = "UI_LV_Tier3_Title",
        descKey = "UI_LV_Tier3_Desc",
        defaultTitle = "Refugio Confortavel (Tier III)",
        defaultDesc = "Reduz o ganho de infelicidade em 25%, regenera endurance +15% e estabiliza a mira.",
        color = {r=0.2, g=1.0, b=0.5},
        vanillaIcon = "media/ui/Moodle_Happy.png",
    },
    [4] = {
        id = "LV_Tier4",
        titleKey = "UI_LV_Tier4_Title",
        descKey = "UI_LV_Tier4_Desc",
        defaultTitle = "Santuario (Tier IV)",
        defaultDesc = "Maximo conforto: imunidade parcial a panico, alta resistencia e menor risco de infeccao em ferimentos.",
        color = {r=0.1, g=1.0, b=0.8},
        vanillaIcon = "media/ui/Moodle_Hyperthermia_Good.png",
    },
}

--- Tiers de Squalor (Debuffs de insalubridade)
LV_MoodleDefs.SqualorTiers = {
    [1] = {
        id = "LV_Squalor1",
        titleKey = "UI_LV_Squalor1_Title",
        descKey = "UI_LV_Squalor1_Desc",
        defaultTitle = "Ambiente Desagradavel (Nivel I)",
        defaultDesc = "O ambiente sujo comeca a incomodar, gerando leve infelicidade.",
        color = {r=0.8, g=0.7, b=0.2},
        vanillaIcon = "media/ui/Moodle_Unhappy_1.png",
    },
    [2] = {
        id = "LV_Squalor2",
        titleKey = "UI_LV_Squalor2_Title",
        descKey = "UI_LV_Squalor2_Desc",
        defaultTitle = "Ambiente Insalubre (Nivel II)",
        defaultDesc = "Cheiro forte de sujeira: aumento de estresse e menor regeneracao de resistencia.",
        color = {r=0.9, g=0.5, b=0.1},
        vanillaIcon = "media/ui/Moodle_Unhappy_2.png",
    },
    [3] = {
        id = "LV_Squalor3",
        titleKey = "UI_LV_Squalor3_Title",
        descKey = "UI_LV_Squalor3_Desc",
        defaultTitle = "Antro Imundo (Nivel III)",
        defaultDesc = "O cheiro de podridao e sangue causa enjoo frequente e cansaco mental.",
        color = {r=0.9, g=0.3, b=0.1},
        vanillaIcon = "media/ui/Moodle_Sick_2.png",
    },
    [4] = {
        id = "LV_Squalor4",
        titleKey = "UI_LV_Squalor4_Title",
        descKey = "UI_LV_Squalor4_Desc",
        defaultTitle = "Foco de Doenca (Nivel IV)",
        defaultDesc = "Ambiente altamente contaminado! Risco severo de febre, infeccao e nauseas continuas.",
        color = {r=0.8, g=0.1, b=0.1},
        vanillaIcon = "media/ui/Moodle_Sick_4.png",
    },
}

--- Catálogo de Buffs Específicos Adicionais
LV_MoodleDefs.ExtendedCatalog = {
    Energizado = {
        minTier = 2,
        sandboxKey = "Enable_Energizado",
        title = "Energizado",
        desc = "Reduz a taxa com que seu personagem fica cansado (Fatigue).",
    },
    Aquecido = {
        minTier = 2,
        sandboxKey = "Enable_Aquecido",
        title = "Aquecido",
        desc = "Mantem o corpo termicamente confortavel em dias frios.",
    },
    Saciado = {
        minTier = 3,
        sandboxKey = "Enable_Saciado",
        title = "Saciado",
        desc = "Reduz a velocidade com que o personagem ganha fome.",
    },
    CicatrizacaoRapida = {
        minTier = 3,
        sandboxKey = "Enable_CicatrizacaoRapida",
        title = "Cicatrizacao Rapida",
        desc = "Acelera a recuperacao natural de arranhoes e cortes leves.",
    },
    Alerta = {
        minTier = 4,
        sandboxKey = "Enable_Alerta",
        title = "Alerta",
        desc = "Reduz o estresse sofrido em situacoes de combate intenso.",
    },
}

--- Retorna o texto traduzido ou o default seguro
function LV_MoodleDefs.getText(key, default)
    if getTextOrNull and getTextOrNull(key) then
        return getText(key)
    end
    return default or key
end
