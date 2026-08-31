-- =============================================================================
-- Housing Care System (Lar Vivo) - Score Data Layer (LV_ItemScoreData.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Tabela de dados e regras de pontuação para o cálculo de conforto e insalubridade.
--   Para garantir máxima compatibilidade com outros mods e evitar quebras com
--   DLCs/patches do PZ B42, as regras de pontuação utilizam PRIORITARIAMENTE
--   IsoFlags e Tags de itens (ex: "Weapon", "Cooking", "Literature").
-- =============================================================================

LV_ItemScoreData = LV_ItemScoreData or {}

--- Pesos relativos de cada pilar no cálculo do Comfort Score (0 a 100).
LV_ItemScoreData.Weights = {
    Cleanliness = 0.25,  -- 25%: Limpeza geral
    Furniture   = 0.35,  -- 35%: Mobília funcional e estruturada
    Lighting    = 0.10,  -- 10%: Iluminação ativa (fontes de luz acesas)
    DecorWorld  = 0.20,  -- 20%: Itens 3D no mundo como decoração
    Dedication  = 0.10,  -- 10%: Decoração dedicada (quadros, tapetes, plantas)
}

--- Pesos relativos de cada pilar no cálculo do Squalor Score (0 a 100).
LV_ItemScoreData.SqualorWeights = {
    DirtAndBlood  = 0.40,  -- 40%: Sangue, sujeira e entulho
    Corpses       = 0.30,  -- 30%: Cadáveres acumulados dentro do cômodo
    RottenAndTrash= 0.20,  -- 20%: Comida podre e lixo largado
    ChaosDisorder = 0.10,  -- 10%: Bagunça excessiva no chão
}

--- Pontuação por categorias de mobília identificadas no ambiente.
LV_ItemScoreData.FurnitureScore = {
    bed = 25,              -- Camas (conforto de descanso essencial)
    chair = 10,            -- Cadeiras simples
    couch = 15,            -- Sofás / Poltronas acolchoadas
    table = 10,            -- Mesas e escrivaninhas
    bookshelf = 10,        -- Estantes de livros / armários decorados
    stove_oven = 10,       -- Fogão / Forno funcional
    radio_tv = 10,         -- Rádio / TV
    rug = 8,               -- Tapetes no piso
    painting = 8,          -- Quadros e pôsteres na parede
    plant = 8,             -- Vasos de plantas decorativas
    light_source_on = 15,  -- Fontes de luz ativas (lâmpadas, velas acesas, lareira)
    light_source_off = 5,  -- Fontes de luz apagadas
}

--- Tags de itens que pontuam como "decoração orgânica 3D" quando colocados no chão ou móveis.
LV_ItemScoreData.WorldItemTags = {
    ["Weapon"]     = 5,    -- Armas brancas (machados, katanas, facas de caça)
    ["Firearm"]    = 5,    -- Armas de fogo (rifles, espingardas, pistolas)
    ["Ammo"]       = 2,    -- Caixas de munição organizadas
    ["Cooking"]    = 3,    -- Utensílios culinários (panelas, chaleiras)
    ["Literature"] = 4,    -- Livros, revistas, guias de sobrevivência
    ["Book"]       = 4,    -- Livros genéricos
    ["Medical"]    = 3,    -- Suprimentos médicos (kits, bandagens)
    ["Tool"]       = 4,    -- Ferramentas manuais (martelos, serras)
    ["Drink"]      = 2,    -- Bebidas lacradas (refrigerante, bourbon, cerveja)
    ["Food"]       = 2,    -- Comidas não-perecíveis / enlatados
    ["Plant"]      = 3,    -- Flores e plantas colhidas
    ["Toy"]        = 3,    -- Brinquedos / itens colecionáveis
}

--- Penalidades aplicadas para o cálculo de Squalor (Insalubridade).
LV_ItemScoreData.Penalties = {
    BloodSplats = 4,       -- Pontos de squalor por nível de sangue em cada tile
    DeadBody = 25,         -- Pontos de squalor por cada cadáver no cômodo
    RottenFood = 12,       -- Pontos de squalor por item podre deixado no local
    TrashObject = 8,       -- Pontos de squalor por entulho / sprite de lixo no chão
    LooseClutter = 1,      -- Pontos de squalor por item solto em excesso no chão
}
