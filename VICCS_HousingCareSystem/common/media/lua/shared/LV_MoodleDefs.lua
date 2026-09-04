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
        defaultTitle = "Desagradavel (Nivel I)",
        defaultDesc = "O ambiente sujo comeca a incomodar, gerando leve infelicidade.",
        color = {r=0.8, g=0.7, b=0.2},
        vanillaIcon = "media/ui/Moodles/32/Mood_NoxiousSmell.png",
    },
    [2] = {
        id = "LV_Squalor2",
        titleKey = "UI_LV_Squalor2_Title",
        descKey = "UI_LV_Squalor2_Desc",
        defaultTitle = "Ambiente Insalubre (Nivel II)",
        defaultDesc = "Cheiro forte de sujeira: aumento de estresse e menor regeneracao de resistencia.",
        color = {r=0.9, g=0.5, b=0.1},
        vanillaIcon = "media/ui/Moodles/32/Mood_NoxiousSmell.png",
    },
    [3] = {
        id = "LV_Squalor3",
        titleKey = "UI_LV_Squalor3_Title",
        descKey = "UI_LV_Squalor3_Desc",
        defaultTitle = "Antro Imundo (Nivel III)",
        defaultDesc = "O cheiro de podridao e sangue causa enjoo frequente e cansaco mental.",
        color = {r=0.9, g=0.3, b=0.1},
        vanillaIcon = "media/ui/Moodles/32/Mood_Nauseous.png",
    },
    [4] = {
        id = "LV_Squalor4",
        titleKey = "UI_LV_Squalor4_Title",
        descKey = "UI_LV_Squalor4_Desc",
        defaultTitle = "Foco de Doenca (Nivel IV)",
        defaultDesc = "Ambiente altamente contaminado! Risco severo de febre, infeccao e nauseas continuas.",
        color = {r=0.8, g=0.1, b=0.1},
        vanillaIcon = "media/ui/Moodles/32/Mood_Ill.png",
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

--- Moodlets de Necessidade Fisiológica (Banheiro / Bexiga)
LV_MoodleDefs.NeedToiletTiers = {
    [1] = {
        id = "LV_NeedToilet1",
        titleKey = "UI_LV_NeedToilet1_Title",
        descKey = "UI_LV_NeedToilet1_Desc",
        defaultTitle = "Vontade de ir ao Banheiro",
        defaultDesc = "Seu corpo comeca a pedir atencao fisiologica.",
        color = {r=0.85, g=0.80, b=0.30},
        vanillaIcon = "media/ui/Moodles/32/Mood_Discomfort.png",
    },
    [2] = {
        id = "LV_NeedToilet2",
        titleKey = "UI_LV_NeedToilet2_Title",
        descKey = "UI_LV_NeedToilet2_Desc",
        defaultTitle = "Aperto Crescente",
        defaultDesc = "Desconforto abdominal moderado. Procure um banheiro em breve.",
        color = {r=0.90, g=0.55, b=0.20},
        vanillaIcon = "media/ui/Moodles/32/Mood_Pained.png",
    },
    [3] = {
        id = "LV_NeedToilet3",
        titleKey = "UI_LV_NeedToilet3_Title",
        descKey = "UI_LV_NeedToilet3_Desc",
        defaultTitle = "Urgencia Fisiologica!",
        defaultDesc = "Aperto insuportavel! Causando estresse e dor de barriga.",
        color = {r=0.95, g=0.20, b=0.20},
        vanillaIcon = "media/ui/Moodles/32/Mood_Ill.png",
    },
}

--- Moodle Positivo de Banheiro Limpo
LV_MoodleDefs.Relieved = {
    id = "LV_Relieved",
    titleKey = "UI_LV_Relieved_Title",
    descKey = "UI_LV_Relieved_Desc",
    defaultTitle = "Aliviado",
    defaultDesc = "Sensacao de leveza e tranquilidade apos usar um banheiro higienizado.",
    color = {r=0.30, g=0.85, b=0.50},
    vanillaIcon = "media/ui/Moodles/32/Mood_Happy.png",
}

--- Moodlets da Rotina Tática e Hábitos Humanos (Update 2)
LV_MoodleDefs.MorningCozy = {
    id = "LV_MorningCozy",
    titleKey = "UI_LV_MorningCozy_Title",
    descKey = "UI_LV_MorningCozy_Desc",
    defaultTitle = "Manha Aconchegante",
    defaultDesc = "Ritual matinal completo: corpo descansado, rosto lavado e cafe quente. Fadiga reduzida e resistencia elevada!",
    color = {r=0.95, g=0.75, b=0.30},
    vanillaIcon = "media/ui/Moodles/32/Mood_Happy.png",
}

LV_MoodleDefs.RoutineStreak = {
    id = "LV_RoutineStreak",
    titleKey = "UI_LV_RoutineStreak_Title",
    descKey = "UI_LV_RoutineStreak_Desc",
    defaultTitle = "Rotina Estabelecida",
    defaultDesc = "Constancia e cuidado com o lar criaram uma mente resiliente. Panico e estresse reduzidos mesmo fora da base!",
    color = {r=0.20, g=0.90, b=0.75},
    vanillaIcon = "media/ui/Moodles/32/Mood_Endurance_Good.png",
}

LV_MoodleDefs.SpotlessHome = {
    id = "LV_SpotlessHome",
    titleKey = "UI_LV_SpotlessHome_Title",
    descKey = "UI_LV_SpotlessHome_Desc",
    defaultTitle = "Casa Impecavel",
    defaultDesc = "Ambiente perfeitamente higienizado e acolhedor. Proporciona foco absoluto para leitura e estudo!",
    color = {r=0.30, g=0.85, b=0.95},
    vanillaIcon = "media/ui/Moodles/32/Mood_Concentrating.png",
}

--- Retorna o texto traduzido ou o default seguro
function LV_MoodleDefs.getText(key, default)
    if getTextOrNull and getTextOrNull(key) then
        return getText(key)
    end
    return default or key
end
