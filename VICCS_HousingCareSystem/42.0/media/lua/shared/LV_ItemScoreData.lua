-- =============================================================================
-- Housing Care System (Lar Vivo) - Score Data Layer (LV_ItemScoreData.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Matriz de pontuação ambiental com avaliação granular balanceada para tiles,
--   eletrônicos e objetos 3D no mundo.
--   - Lookup em tempo O(1) via tabelas Hash pré-indexadas em memória (zero GC lag)
--   - Curva de Rendimento Decrescente (Diminishing Returns) por categoria
--   - Cap de Saturação por Categoria em Cômodos
--   - Higiene e Degradação 3D (alimento podre = 0 ambiente e +12 squalor)
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
    DirtAndBlood   = 0.40,  -- 40%: Sangue, sujeira e entulho
    Corpses        = 0.30,  -- 30%: Cadáveres acumulados dentro do cômodo
    RottenAndTrash = 0.20,  -- 20%: Comida podre e lixo largado
    ChaosDisorder  = 0.10,  -- 10%: Bagunça excessiva no chão
}

--- Arquétipos de pontuação para Mobílias, Eletrônicos e Decoração de Superfície.
LV_ItemScoreData.FurnitureScore = {
    bed              = 25,  -- Camas (conforto de descanso essencial)
    couch            = 15,  -- Sofás acolchoados
    chair            = 12,  -- Poltronas e cadeiras confortáveis
    table            = 15,  -- Mesas de jantar e escrivaninhas
    storage          = 15,  -- Armários, roupeiros, cristaleiras e cômodas
    bookshelf        = 12,  -- Estantes de livros
    stove_oven       = 12,  -- Fogão / Forno funcional
    fridge           = 12,  -- Geladeira residencial
    radio_tv         = 12,  -- Televisão ou Rádio
    light_source_on  = 15,  -- Fontes de luz ativas (lâmpadas, velas acesas, lareira)
    light_source_off = 5,   -- Fontes de luz apagadas
    rug              = 12,  -- Tapetes e peles no piso
    painting         = 8,   -- Quadros, pôsteres e decorações de parede
    plant            = 10,  -- Vasos de plantas decorativas
    curtain          = 6,   -- Cortinas em janelas
    clock            = 8,   -- Relógios de parede
    mirror           = 8,   -- Espelhos decorativos
    fan              = 8,   -- Ventiladores residenciais
}

--- Arquétipos de pontuação balanceada para Tiles de Mobílias, Eletrônicos e Decoração
LV_ItemScoreData.TileArchetypes = {
    bed              = { score = 25, category = "HEAVY_FURNITURE", label = "Cama de Descanso", maxPerRoom = 3 },
    couch            = { score = 15, category = "HEAVY_FURNITURE", label = "Sofa Acolchoado", maxPerRoom = 4 },
    chair            = { score = 10, category = "HEAVY_FURNITURE", label = "Cadeira/Poltrona", maxPerRoom = 8 },
    table            = { score = 12, category = "HEAVY_FURNITURE", label = "Mesa/Balcao", maxPerRoom = 6 },
    storage          = { score = 12, category = "HEAVY_FURNITURE", label = "Armario/Comoda", maxPerRoom = 8 },
    bookshelf        = { score = 12, category = "HEAVY_FURNITURE", label = "Estante de Livros", maxPerRoom = 6 },
    stove_oven       = { score = 15, category = "APPLIANCES_ELECTRONICS", label = "Fogao/Forno", maxPerRoom = 3 },
    fridge           = { score = 15, category = "APPLIANCES_ELECTRONICS", label = "Geladeira", maxPerRoom = 3 },
    radio_tv         = { score = 12, category = "APPLIANCES_ELECTRONICS", label = "Televisao/Radio", maxPerRoom = 4 },
    light_source_on  = { score = 15, category = "APPLIANCES_ELECTRONICS", label = "Luz Ativa", maxPerRoom = 8 },
    light_source_off = { score = 4,  category = "APPLIANCES_ELECTRONICS", label = "Luz Apagada", maxPerRoom = 8 },
    heat_source_on   = { score = 24, category = "APPLIANCES_ELECTRONICS", label = "Aquecimento Ativo (Inverno)", maxPerRoom = 2 },
    heat_source_off  = { score = 10, category = "APPLIANCES_ELECTRONICS", label = "Lareira/Aquecedor", maxPerRoom = 2 },
    fan_cooling      = { score = 10, category = "APPLIANCES_ELECTRONICS", label = "Ventilador (Verao)", maxPerRoom = 4 },
    rug              = { score = 12, category = "SURFACE_DECOR", label = "Tapete/Pele", maxPerRoom = 6 },
    rug_winter       = { score = 18, category = "SURFACE_DECOR", label = "Tapete Isolante (Inverno)", maxPerRoom = 6 },
    wall_decor       = { score = 8,  category = "SURFACE_DECOR", label = "Quadro/Decoracao Parede", maxPerRoom = 8 },
    plant            = { score = 10, category = "SURFACE_DECOR", label = "Vaso de Planta", maxPerRoom = 6 },
    curtain          = { score = 6,  category = "SURFACE_DECOR", label = "Cortina", maxPerRoom = 8 },
    clock            = { score = 8,  category = "SURFACE_DECOR", label = "Relogio de Parede", maxPerRoom = 4 },
    mirror           = { score = 8,  category = "SURFACE_DECOR", label = "Espelho", maxPerRoom = 4 },
}

--- Retorna os dados do arquétipo de tile
function LV_ItemScoreData.getTileArchetype(key)
    if not key then return nil end
    return LV_ItemScoreData.TileArchetypes[key]
end

--- Interface unificada de EnvironmentScore solicitada pela arquitetura
LV_ItemScoreData.EnvironmentScore = {
    TileArchetypes = LV_ItemScoreData.TileArchetypes,
    Categories = nil, -- Atribuído abaixo
    getDiminishedScore = nil, -- Atribuído abaixo
    evaluateItem = nil, -- Atribuído abaixo
}

--- Categorias de Ambiente para Curva de Rendimento Decrescente
LV_ItemScoreData.Categories = {
    HEAVY_FURNITURE        = "Mobilias Principais",
    APPLIANCES_ELECTRONICS = "Eletronicos & Eletrodomesticos",
    SURFACE_DECOR          = "Decoracao de Superficie",
    ORGANIC_COMFORT_3D     = "Conforto Organico 3D",
    PANTRY_SUPPLIES_3D     = "Despensa & Suprimentos 3D",
}
LV_ItemScoreData.EnvironmentScore.Categories = LV_ItemScoreData.Categories

--- Retorna a pontuação ajustada pela Curva de Rendimento Decrescente
function LV_ItemScoreData.getDiminishedScore(baseScore, itemCount, isEnabled)
    if not isEnabled or itemCount <= 1 then
        return baseScore
    elseif itemCount == 2 then
        return baseScore * 0.75
    elseif itemCount == 3 then
        return baseScore * 0.50
    elseif itemCount == 4 then
        return baseScore * 0.25
    else
        return baseScore * 0.10
    end
end

--- Tabela Hash O(1) direta por FullType de Itens 3D Comuns
LV_ItemScoreData.TypeLookup = {
    -- Despensa / Alimentos 3D (Micro-pontuação balanceada)
    ["Base.Cereal"]                 = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Caixa de Cereal" },
    ["Base.Crisps"]                 = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Salgadinho de Batata" },
    ["Base.Crisps2"]                = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Salgadinho Tortilha" },
    ["Base.Crisps3"]                = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Salgadinho de Milho" },
    ["Base.Crisps4"]                = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Batata Palha" },
    ["Base.Popcorn"]                = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Pipoca de Micro-ondas" },
    ["Base.CookiesChocolate"]       = { score = 0.6, category = "PANTRY_SUPPLIES_3D", label = "Biscoitos de Chocolate" },
    ["Base.Chocolate"]              = { score = 0.6, category = "PANTRY_SUPPLIES_3D", label = "Barra de Chocolate" },
    ["Base.CandyFruitSlices"]       = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Guloseimas Frutadas" },
    ["Base.CannedCorn"]             = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Milho em Lata" },
    ["Base.CannedPeas"]             = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Ervilha em Lata" },
    ["Base.CannedPotato2"]          = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Batatas em Lata" },
    ["Base.CannedTomato"]           = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Tomate em Lata" },
    ["Base.CannedCarrots2"]         = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Cenouras em Lata" },
    ["Base.CannedChili"]            = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Chili em Lata" },
    ["Base.CannedBolognese"]        = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Bolonhesa em Lata" },
    ["Base.TinnedSoup"]             = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Sopa Enlatada" },
    ["Base.TunaTin"]                = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Atum em Lata" },
    ["Base.CannedSardines"]         = { score = 0.4, category = "PANTRY_SUPPLIES_3D", label = "Sardinhas em Lata" },
    ["Base.PeanutButter"]           = { score = 0.6, category = "PANTRY_SUPPLIES_3D", label = "Manteiga de Amendoim" },
    ["Base.JamFruit"]               = { score = 0.6, category = "PANTRY_SUPPLIES_3D", label = "Geleia de Frutas" },
    ["Base.Coffee2"]                = { score = 0.8, category = "PANTRY_SUPPLIES_3D", label = "Lata de Cafe em Po" },
    ["Base.TeaBag"]                 = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Caixa de Cha" },
    ["Base.Sugar"]                  = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Pacote de Acucar" },
    ["Base.Flour"]                  = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Saco de Farinha" },
    ["Base.Rice"]                   = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Saco de Arroz" },
    ["Base.Pasta"]                  = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Pacote de Macarrao" },

    -- Bebidas Lacradas / Garrafas
    ["Base.Pop"]                    = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Lata de Refrigerante" },
    ["Base.Pop2"]                   = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Lata de Refrigerante Diet" },
    ["Base.Pop3"]                   = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Lata de Refrigerante Limao" },
    ["Base.WaterBottleFull"]        = { score = 0.6, category = "PANTRY_SUPPLIES_3D", label = "Garrafa de Agua Mineral" },
    ["Base.BeerBottle"]             = { score = 0.7, category = "PANTRY_SUPPLIES_3D", label = "Garrafa de Cerveja" },
    ["Base.BeerCan"]                = { score = 0.6, category = "PANTRY_SUPPLIES_3D", label = "Lata de Cerveja" },
    ["Base.Wine"]                   = { score = 1.0, category = "PANTRY_SUPPLIES_3D", label = "Garrafa de Vinho Tinto" },
    ["Base.Wine2"]                  = { score = 1.0, category = "PANTRY_SUPPLIES_3D", label = "Garrafa de Vinho Branco" },
    ["Base.WhiskeyFull"]            = { score = 1.2, category = "PANTRY_SUPPLIES_3D", label = "Garrafa de Whiskey" },

    -- Conforto Orgânico 3D (Livros, Louças, Colecionáveis, Brinquedos)
    ["Base.Book"]                   = { score = 2.5, category = "ORGANIC_COMFORT_3D", label = "Livro de Leitura" },
    ["Base.BookCarpentry1"]         = { score = 2.0, category = "ORGANIC_COMFORT_3D", label = "Manual de Carpintaria" },
    ["Base.BookCooking1"]           = { score = 2.0, category = "ORGANIC_COMFORT_3D", label = "Guia de Culinaria" },
    ["Base.ComicBook"]              = { score = 1.5, category = "ORGANIC_COMFORT_3D", label = "Revista em Quadrinhos" },
    ["Base.Magazine"]               = { score = 1.5, category = "ORGANIC_COMFORT_3D", label = "Revista Informativa" },
    ["Base.Newspaper"]              = { score = 0.8, category = "ORGANIC_COMFORT_3D", label = "Jornal do Dia" },
    ["Base.Notebook"]               = { score = 1.2, category = "ORGANIC_COMFORT_3D", label = "Caderno de Anotacoes" },
    ["Base.Journal"]                = { score = 1.5, category = "ORGANIC_COMFORT_3D", label = "Diario Pessoal" },
    ["Base.Spiffo"]                 = { score = 3.5, category = "ORGANIC_COMFORT_3D", label = "Pelucia Oficial do Spiffo" },
    ["Base.SpiffoBig"]              = { score = 5.0, category = "ORGANIC_COMFORT_3D", label = "Spiffo de Pelucia Gigante" },
    ["Base.TeddyBear"]              = { score = 3.0, category = "ORGANIC_COMFORT_3D", label = "Ursinho de Pelucia" },
    ["Base.Doll"]                   = { score = 2.0, category = "ORGANIC_COMFORT_3D", label = "Boneca Decorativa" },
    ["Base.ToyBear"]                = { score = 2.5, category = "ORGANIC_COMFORT_3D", label = "Bichinho de Pelucia" },
    ["Base.Mugl"]                   = { score = 1.5, category = "ORGANIC_COMFORT_3D", label = "Caneca de Ceramica" },
    ["Base.MugWhite"]               = { score = 1.5, category = "ORGANIC_COMFORT_3D", label = "Caneca de Cafe Branca" },
    ["Base.MugRed"]                 = { score = 1.5, category = "ORGANIC_COMFORT_3D", label = "Caneca de Cafe Vermelha" },
    ["Base.Teacup"]                 = { score = 1.5, category = "ORGANIC_COMFORT_3D", label = "Xicara de Porcelana" },
    ["Base.Teapot"]                 = { score = 2.0, category = "ORGANIC_COMFORT_3D", label = "Bule de Cha" },
    ["Base.Kettle"]                 = { score = 2.0, category = "ORGANIC_COMFORT_3D", label = "Chaleira Esmaltada" },
    ["Base.Pot"]                    = { score = 1.8, category = "ORGANIC_COMFORT_3D", label = "Panela de Cozinha" },
    ["Base.Saucepan"]               = { score = 1.5, category = "ORGANIC_COMFORT_3D", label = "Frigideira / Cacarola" },
    ["Base.Pan"]                    = { score = 1.5, category = "ORGANIC_COMFORT_3D", label = "Frigideira de Ferro" },
    ["Base.GuitarAcoustic"]         = { score = 3.5, category = "ORGANIC_COMFORT_3D", label = "Violao Acustico" },
    ["Base.GuitarElectricBassBlack"]= { score = 3.5, category = "ORGANIC_COMFORT_3D", label = "Baixo Eletrico" },
    ["Base.GuitarElectricBlack"]    = { score = 3.5, category = "ORGANIC_COMFORT_3D", label = "Guitarra Eletrica" },
    ["Base.Violin"]                 = { score = 3.5, category = "ORGANIC_COMFORT_3D", label = "Violino Classico" },
    ["Base.Dice"]                   = { score = 1.0, category = "ORGANIC_COMFORT_3D", label = "Dados de Jogo" },
    ["Base.Cards"]                  = { score = 1.2, category = "ORGANIC_COMFORT_3D", label = "Baralho de Cartas" },
    ["Base.ChessWhiteKing"]         = { score = 1.0, category = "ORGANIC_COMFORT_3D", label = "Peca de Xadrez" },

    -- Ferramentas Manuais & Equipamentos de Bancada
    ["Base.Hammer"]                 = { score = 0.8, category = "PANTRY_SUPPLIES_3D", label = "Martelo de Bancada" },
    ["Base.Saw"]                    = { score = 0.8, category = "PANTRY_SUPPLIES_3D", label = "Serrote Manual" },
    ["Base.Screwdriver"]            = { score = 0.6, category = "PANTRY_SUPPLIES_3D", label = "Chave de Fenda" },
    ["Base.Wrench"]                 = { score = 0.8, category = "PANTRY_SUPPLIES_3D", label = "Chave Inglesa" },
    ["Base.Needle"]                 = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Kit de Costura / Agulha" },
    ["Base.FirstAidKit"]            = { score = 1.5, category = "PANTRY_SUPPLIES_3D", label = "Maleta de Primeiros Socorros" },
    ["Base.Toolbox"]                = { score = 1.5, category = "PANTRY_SUPPLIES_3D", label = "Caixa de Ferramentas" },
    ["Base.Flashlight"]             = { score = 1.0, category = "PANTRY_SUPPLIES_3D", label = "Lanterna Eletrica" },
    ["Base.Candle"]                 = { score = 1.2, category = "PANTRY_SUPPLIES_3D", label = "Vela Aromatica" },
}

--- Tabela Hash O(1) de Tags e Categorias de Exibição
LV_ItemScoreData.TagLookup = {
    ["Literature"]  = { score = 2.0, category = "ORGANIC_COMFORT_3D", label = "Material de Leitura" },
    ["Book"]        = { score = 2.0, category = "ORGANIC_COMFORT_3D", label = "Livro" },
    ["Toy"]         = { score = 2.5, category = "ORGANIC_COMFORT_3D", label = "Brinquedo / Pelucia" },
    ["Cooking"]     = { score = 1.5, category = "ORGANIC_COMFORT_3D", label = "Utensilio Culinario" },
    ["Food"]        = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Alimento / Suprimento" },
    ["Drink"]       = { score = 0.6, category = "PANTRY_SUPPLIES_3D", label = "Bebida Lacrada" },
    ["Medical"]     = { score = 1.0, category = "PANTRY_SUPPLIES_3D", label = "Suprimento Medico" },
    ["Tool"]        = { score = 0.8, category = "PANTRY_SUPPLIES_3D", label = "Ferramenta de Bancada" },
    ["Ammo"]        = { score = 0.5, category = "PANTRY_SUPPLIES_3D", label = "Municao em Caixa" },
    ["Weapon"]      = { score = 1.2, category = "PANTRY_SUPPLIES_3D", label = "Armamento Decorativo" },
    ["Firearm"]     = { score = 1.2, category = "PANTRY_SUPPLIES_3D", label = "Arma de Fogo em Exibicao" },
}

--- Avalia um item em tempo O(1) retornando sua pontuação, categoria e se está estragado
function LV_ItemScoreData.evaluateItem(item)
    if not item then return nil end

    -- 1. Detecção de Alimento Estragado (Higiene e Degradação 3D)
    if instanceof and instanceof(item, "Food") and item.isRotten and item:isRotten() then
        return {
            score = 0,
            squalor = 12,
            isRotten = true,
            label = (item.getName and item:getName()) or "Comida Podre",
            category = "SQUALOR_DEBRIS"
        }
    end

    -- 2. Lookup direto por FullType O(1)
    local fullType = item.getFullType and item:getFullType()
    if fullType and LV_ItemScoreData.TypeLookup[fullType] then
        local entry = LV_ItemScoreData.TypeLookup[fullType]
        return {
            score = entry.score,
            category = entry.category,
            label = entry.label or item:getName(),
            isRotten = false,
            squalor = 0
        }
    end

    -- 3. Lookup por Categoria de Exibição / Tags O(1)
    local displayCat = item.getDisplayCategory and item:getDisplayCategory()
    if displayCat and LV_ItemScoreData.TagLookup[displayCat] then
        local entry = LV_ItemScoreData.TagLookup[displayCat]
        return {
            score = entry.score,
            category = entry.category,
            label = item.getName and item:getName() or entry.label,
            isRotten = false,
            squalor = 0
        }
    end

    return nil
end

--- Penalidades aplicadas para o cálculo de Squalor (Insalubridade).
LV_ItemScoreData.Penalties = {
    BloodSplats  = 4,   -- Pontos de squalor por nível de sangue em cada tile
    DeadBody     = 25,  -- Pontos de squalor por cada cadáver no cômodo
    RottenFood   = 12,  -- Pontos de squalor por item podre deixado no local
    TrashObject  = 8,   -- Pontos de squalor por entulho / sprite de lixo no chão
    LooseClutter = 1,   -- Pontos de squalor por item solto em excesso no chão
}

-- Amarrações de compatibilidade da interface EnvironmentScore
LV_ItemScoreData.EnvironmentScore.getDiminishedScore = LV_ItemScoreData.getDiminishedScore
LV_ItemScoreData.EnvironmentScore.evaluateItem = LV_ItemScoreData.evaluateItem
LV_ItemScoreData.EnvironmentScore.getTileArchetype = LV_ItemScoreData.getTileArchetype

