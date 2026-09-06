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
    bed              = 10,  -- Camas (conforto de descanso essencial - era 25)
    couch            = 7,   -- Sofás acolchoados (era 15)
    chair            = 3,   -- Poltronas e cadeiras confortáveis (era 12)
    table            = 4,   -- Mesas de jantar e escrivaninhas (era 15)
    storage          = 4,   -- Armários, roupeiros, cristaleiras e cômodas (era 15)
    bookshelf        = 5,   -- Estantes de livros (era 12)
    stove_oven       = 6,   -- Fogão / Forno funcional (era 12)
    fridge           = 6,   -- Geladeira residencial (era 12)
    radio_tv         = 5,   -- Televisão ou Rádio (era 12)
    light_source_on  = 5,   -- Fontes de luz ativas (lâmpadas, velas acesas, lareira - era 15)
    light_source_off = 1,   -- Fontes de luz apagadas (era 5)
    rug              = 4,   -- Tapetes e peles no piso (era 12)
    painting         = 3,   -- Quadros, pôsteres e decorações de parede (era 8)
    plant            = 3,   -- Vasos de plantas decorativas (era 10)
    curtain          = 2,   -- Cortinas em janelas (era 6)
    clock            = 3,   -- Relógios de parede (era 8)
    mirror           = 3,   -- Espelhos decorativos (era 8)
    fan              = 4,   -- Ventiladores residenciais (era 8)
}

--- Arquétipos de pontuação balanceada para Tiles de Mobílias, Eletrônicos e Decoração
LV_ItemScoreData.TileArchetypes = {
    bed              = { score = 10, category = "HEAVY_FURNITURE", label = "Cama de Descanso", maxPerRoom = 2 },
    couch            = { score = 7,  category = "HEAVY_FURNITURE", label = "Sofa Acolchoado", maxPerRoom = 3 },
    chair            = { score = 3,  category = "HEAVY_FURNITURE", label = "Cadeira/Poltrona", maxPerRoom = 6 },
    table            = { score = 4,  category = "HEAVY_FURNITURE", label = "Mesa/Balcao", maxPerRoom = 4 },
    storage          = { score = 4,  category = "HEAVY_FURNITURE", label = "Armario/Comoda", maxPerRoom = 6 },
    bookshelf        = { score = 5,  category = "HEAVY_FURNITURE", label = "Estante de Livros", maxPerRoom = 4 },
    stove_oven       = { score = 6,  category = "APPLIANCES_ELECTRONICS", label = "Fogao/Forno", maxPerRoom = 2 },
    fridge           = { score = 6,  category = "APPLIANCES_ELECTRONICS", label = "Geladeira", maxPerRoom = 2 },
    radio_tv         = { score = 5,  category = "APPLIANCES_ELECTRONICS", label = "Televisao/Radio", maxPerRoom = 2 },
    light_source_on  = { score = 5,  category = "APPLIANCES_ELECTRONICS", label = "Luz Ativa", maxPerRoom = 6 },
    light_source_off = { score = 1,  category = "APPLIANCES_ELECTRONICS", label = "Luz Apagada", maxPerRoom = 6 },
    heat_source_on   = { score = 8,  category = "APPLIANCES_ELECTRONICS", label = "Aquecimento Ativo (Inverno)", maxPerRoom = 2 },
    heat_source_off  = { score = 2,  category = "APPLIANCES_ELECTRONICS", label = "Lareira/Aquecedor", maxPerRoom = 2 },
    fan_cooling      = { score = 4,  category = "APPLIANCES_ELECTRONICS", label = "Ventilador (Verao)", maxPerRoom = 2 },
    rug              = { score = 4,  category = "SURFACE_DECOR", label = "Tapete/Pele", maxPerRoom = 4 },
    rug_winter       = { score = 6,  category = "SURFACE_DECOR", label = "Tapete Isolante (Inverno)", maxPerRoom = 4 },
    wall_decor       = { score = 3,  category = "SURFACE_DECOR", label = "Quadro/Decoracao Parede", maxPerRoom = 6 },
    plant            = { score = 3,  category = "SURFACE_DECOR", label = "Vaso de Planta", maxPerRoom = 4 },
    curtain          = { score = 2,  category = "SURFACE_DECOR", label = "Cortina", maxPerRoom = 6 },
    clock            = { score = 3,  category = "SURFACE_DECOR", label = "Relogio de Parede", maxPerRoom = 2 },
    mirror           = { score = 3,  category = "SURFACE_DECOR", label = "Espelho", maxPerRoom = 2 },
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

--- Retorna a pontuação ajustada pela Curva de Rendimento Decrescente (Mais rigorosa anti-spam)
function LV_ItemScoreData.getDiminishedScore(baseScore, itemCount, isEnabled)
    if not isEnabled or itemCount <= 1 then
        return baseScore
    elseif itemCount == 2 then
        return baseScore * 0.60
    elseif itemCount == 3 then
        return baseScore * 0.35
    elseif itemCount == 4 then
        return baseScore * 0.15
    else
        return baseScore * 0.05
    end
end

--- Tabela Hash O(1) direta por FullType de Itens 3D Comuns
LV_ItemScoreData.TypeLookup = {
    -- Despensa / Alimentos 3D (Micro-pontuação balanceada: 0.1 a 0.25 pts)
    ["Base.Cereal"]                 = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Caixa de Cereal" },
    ["Base.Crisps"]                 = { score = 0.10, category = "PANTRY_SUPPLIES_3D", label = "Salgadinho de Batata" },
    ["Base.Crisps2"]                = { score = 0.10, category = "PANTRY_SUPPLIES_3D", label = "Salgadinho Tortilha" },
    ["Base.Crisps3"]                = { score = 0.10, category = "PANTRY_SUPPLIES_3D", label = "Salgadinho de Milho" },
    ["Base.Crisps4"]                = { score = 0.10, category = "PANTRY_SUPPLIES_3D", label = "Batata Palha" },
    ["Base.Popcorn"]                = { score = 0.10, category = "PANTRY_SUPPLIES_3D", label = "Pipoca de Micro-ondas" },
    ["Base.CookiesChocolate"]       = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Biscoitos de Chocolate" },
    ["Base.Chocolate"]              = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Barra de Chocolate" },
    ["Base.CandyFruitSlices"]       = { score = 0.10, category = "PANTRY_SUPPLIES_3D", label = "Guloseimas Frutadas" },
    ["Base.CannedCorn"]             = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Milho em Lata" },
    ["Base.CannedPeas"]             = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Ervilha em Lata" },
    ["Base.CannedPotato2"]          = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Batatas em Lata" },
    ["Base.CannedTomato"]           = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Tomate em Lata" },
    ["Base.CannedCarrots2"]         = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Cenouras em Lata" },
    ["Base.CannedChili"]            = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Chili em Lata" },
    ["Base.CannedBolognese"]        = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Bolonhesa em Lata" },
    ["Base.TinnedSoup"]             = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Sopa Enlatada" },
    ["Base.TunaTin"]                = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Atum em Lata" },
    ["Base.CannedSardines"]         = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Sardinhas em Lata" },
    ["Base.PeanutButter"]           = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Manteiga de Amendoim" },
    ["Base.JamFruit"]               = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Geleia de Frutas" },
    ["Base.Coffee2"]                = { score = 0.25, category = "PANTRY_SUPPLIES_3D", label = "Lata de Cafe em Po" },
    ["Base.TeaBag"]                 = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Caixa de Cha" },
    ["Base.Sugar"]                  = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Pacote de Acucar" },
    ["Base.Flour"]                  = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Saco de Farinha" },
    ["Base.Rice"]                   = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Saco de Arroz" },
    ["Base.Pasta"]                  = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Pacote de Macarrao" },

    -- Bebidas Lacradas / Garrafas (0.15 a 0.35 pts)
    ["Base.Pop"]                    = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Lata de Refrigerante" },
    ["Base.Pop2"]                   = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Lata de Refrigerante Diet" },
    ["Base.Pop3"]                   = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Lata de Refrigerante Limao" },
    ["Base.WaterBottleFull"]        = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Garrafa de Agua Mineral" },
    ["Base.BeerBottle"]             = { score = 0.25, category = "PANTRY_SUPPLIES_3D", label = "Garrafa de Cerveja" },
    ["Base.BeerCan"]                = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Lata de Cerveja" },
    ["Base.Wine"]                   = { score = 0.35, category = "PANTRY_SUPPLIES_3D", label = "Garrafa de Vinho Tinto" },
    ["Base.Wine2"]                  = { score = 0.35, category = "PANTRY_SUPPLIES_3D", label = "Garrafa de Vinho Branco" },
    ["Base.WhiskeyFull"]            = { score = 0.40, category = "PANTRY_SUPPLIES_3D", label = "Garrafa de Whiskey" },

    -- Conforto Orgânico 3D (Livros, Louças, Colecionáveis, Brinquedos: 0.2 a 1.2 pts)
    ["Base.Book"]                   = { score = 0.60, category = "ORGANIC_COMFORT_3D", label = "Livro de Leitura" },
    ["Base.BookCarpentry1"]         = { score = 0.50, category = "ORGANIC_COMFORT_3D", label = "Manual de Carpintaria" },
    ["Base.BookCooking1"]           = { score = 0.50, category = "ORGANIC_COMFORT_3D", label = "Guia de Culinaria" },
    ["Base.ComicBook"]              = { score = 0.40, category = "ORGANIC_COMFORT_3D", label = "Revista em Quadrinhos" },
    ["Base.Magazine"]               = { score = 0.40, category = "ORGANIC_COMFORT_3D", label = "Revista Informativa" },
    ["Base.Newspaper"]              = { score = 0.20, category = "ORGANIC_COMFORT_3D", label = "Jornal do Dia" },
    ["Base.Notebook"]               = { score = 0.30, category = "ORGANIC_COMFORT_3D", label = "Caderno de Anotacoes" },
    ["Base.Journal"]                = { score = 0.40, category = "ORGANIC_COMFORT_3D", label = "Diario Pessoal" },
    ["Base.Spiffo"]                 = { score = 1.00, category = "ORGANIC_COMFORT_3D", label = "Pelucia Oficial do Spiffo" },
    ["Base.SpiffoBig"]              = { score = 1.50, category = "ORGANIC_COMFORT_3D", label = "Spiffo de Pelucia Gigante" },
    ["Base.TeddyBear"]              = { score = 0.80, category = "ORGANIC_COMFORT_3D", label = "Ursinho de Pelucia" },
    ["Base.Doll"]                   = { score = 0.60, category = "ORGANIC_COMFORT_3D", label = "Boneca Decorativa" },
    ["Base.ToyBear"]                = { score = 0.70, category = "ORGANIC_COMFORT_3D", label = "Bichinho de Pelucia" },
    ["Base.Mugl"]                   = { score = 0.30, category = "ORGANIC_COMFORT_3D", label = "Caneca de Ceramica" },
    ["Base.MugWhite"]               = { score = 0.30, category = "ORGANIC_COMFORT_3D", label = "Caneca de Cafe Branca" },
    ["Base.MugRed"]                 = { score = 0.30, category = "ORGANIC_COMFORT_3D", label = "Caneca de Cafe Vermelha" },
    ["Base.Teacup"]                 = { score = 0.30, category = "ORGANIC_COMFORT_3D", label = "Xicara de Porcelana" },
    ["Base.Teapot"]                 = { score = 0.40, category = "ORGANIC_COMFORT_3D", label = "Bule de Cha" },
    ["Base.Kettle"]                 = { score = 0.40, category = "ORGANIC_COMFORT_3D", label = "Chaleira Esmaltada" },
    ["Base.Pot"]                    = { score = 0.35, category = "ORGANIC_COMFORT_3D", label = "Panela de Cozinha" },
    ["Base.Saucepan"]               = { score = 0.30, category = "ORGANIC_COMFORT_3D", label = "Frigideira / Cacarola" },
    ["Base.Pan"]                    = { score = 0.30, category = "ORGANIC_COMFORT_3D", label = "Frigideira de Ferro" },
    ["Base.GuitarAcoustic"]         = { score = 1.20, category = "ORGANIC_COMFORT_3D", label = "Violao Acustico" },
    ["Base.GuitarElectricBassBlack"]= { score = 1.20, category = "ORGANIC_COMFORT_3D", label = "Baixo Eletrico" },
    ["Base.GuitarElectricBlack"]    = { score = 1.20, category = "ORGANIC_COMFORT_3D", label = "Guitarra Eletrica" },
    ["Base.Violin"]                 = { score = 1.20, category = "ORGANIC_COMFORT_3D", label = "Violino Classico" },
    ["Base.Dice"]                   = { score = 0.25, category = "ORGANIC_COMFORT_3D", label = "Dados de Jogo" },
    ["Base.Cards"]                  = { score = 0.30, category = "ORGANIC_COMFORT_3D", label = "Baralho de Cartas" },
    ["Base.ChessWhiteKing"]         = { score = 0.25, category = "ORGANIC_COMFORT_3D", label = "Peca de Xadrez" },

    -- Ferramentas Manuais & Equipamentos de Bancada (0.2 a 0.4 pts)
    ["Base.Hammer"]                 = { score = 0.25, category = "PANTRY_SUPPLIES_3D", label = "Martelo de Bancada" },
    ["Base.Saw"]                    = { score = 0.25, category = "PANTRY_SUPPLIES_3D", label = "Serrote Manual" },
    ["Base.Screwdriver"]            = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Chave de Fenda" },
    ["Base.Wrench"]                 = { score = 0.25, category = "PANTRY_SUPPLIES_3D", label = "Chave Inglesa" },
    ["Base.Needle"]                 = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Kit de Costura / Agulha" },
    ["Base.FirstAidKit"]            = { score = 0.40, category = "PANTRY_SUPPLIES_3D", label = "Maleta de Primeiros Socorros" },
    ["Base.Toolbox"]                = { score = 0.40, category = "PANTRY_SUPPLIES_3D", label = "Caixa de Ferramentas" },
    ["Base.Flashlight"]             = { score = 0.25, category = "PANTRY_SUPPLIES_3D", label = "Lanterna Eletrica" },
    ["Base.Candle"]                 = { score = 0.30, category = "PANTRY_SUPPLIES_3D", label = "Vela Aromatica" },
}

--- Tabela Hash O(1) de Tags e Categorias de Exibição
LV_ItemScoreData.TagLookup = {
    ["Literature"]  = { score = 0.60, category = "ORGANIC_COMFORT_3D", label = "Material de Leitura" },
    ["Book"]        = { score = 0.50, category = "ORGANIC_COMFORT_3D", label = "Livro" },
    ["Toy"]         = { score = 0.80, category = "ORGANIC_COMFORT_3D", label = "Brinquedo / Pelucia" },
    ["Cooking"]     = { score = 0.30, category = "ORGANIC_COMFORT_3D", label = "Utensilio Culinario" },
    ["Food"]        = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Alimento / Suprimento" },
    ["Drink"]       = { score = 0.20, category = "PANTRY_SUPPLIES_3D", label = "Bebida Lacrada" },
    ["Medical"]     = { score = 0.30, category = "PANTRY_SUPPLIES_3D", label = "Suprimento Medico" },
    ["Tool"]        = { score = 0.25, category = "PANTRY_SUPPLIES_3D", label = "Ferramenta de Bancada" },
    ["Ammo"]        = { score = 0.15, category = "PANTRY_SUPPLIES_3D", label = "Municao em Caixa" },
    ["Weapon"]      = { score = 0.35, category = "PANTRY_SUPPLIES_3D", label = "Armamento Decorativo" },
    ["Firearm"]     = { score = 0.35, category = "PANTRY_SUPPLIES_3D", label = "Arma de Fogo em Exibicao" },
}

--- Avalia um item em tempo O(1) retornando sua pontuação, categoria e se está estragado
function LV_ItemScoreData.evaluateItem(item)
    if not item then return nil end

    -- 1. Detecção Robusta de Alimento Estragado (Higiene e Degradação 3D)
    local isRottenFood = false
    if item.isRotten then
        local okR, r = pcall(item.isRotten, item)
        if okR and r == true then isRottenFood = true end
    end
    if not isRottenFood and item.getAge and item.getOffAge then
        pcall(function()
            local off = item:getOffAge()
            if off and off > 0 and item:getAge() > off then
                isRottenFood = true
            end
        end)
    end

    if isRottenFood then
        return {
            score = 0,
            squalor = (LV_ItemScoreData.Penalties and LV_ItemScoreData.Penalties.RottenFood) or 12,
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

