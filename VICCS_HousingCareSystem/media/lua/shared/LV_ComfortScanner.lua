-- =============================================================================
-- Housing Care System (Lar Vivo) - Whole Safehouse & Room Scanner (LV_ComfortScanner.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Módulo de varredura inteligente em duas camadas:
--   1. Conforto do Cômodo Imediato (50% do peso)
--   2. Índice Global de Higiene e Manutenção de toda a Safehouse (50% do peso)
--   Garante balanceamento justo para mansões pré-mobiliadas exigindo manutenção ativa.
-- =============================================================================

LV_ComfortScanner = LV_ComfortScanner or {}

--- Quantidade de tiles inspecionados por frame (Time-Slicing para performance máxima)
local TILES_PER_FRAME = 25

--- Auxiliar seguro para checar flags no PropertyContainer do PZ B42 sem exceções de reflexão
local function safeHasFlag(props, flag)
    if not props or not flag then return false end
    if props.Is then
        local ok, res = pcall(props.Is, props, flag)
        if ok and res == true then return true end
    end
    if props.have then
        local ok, res = pcall(props.have, props, flag)
        if ok and res == true then return true end
    end
    return false
end

--- Fila interna de varredura
local scanQueue = {
    active = false,
    squares = {},
    index = 1,
    total = 0,
    player = nil,
    results = {}
}

--- Cache de resultados globais da Safehouse para evitar processamento redundante
local safehouseCache = {}
LV_ComfortScanner.safehouseCache = safehouseCache

--- Verifica se o jogador atende ao requisito de Safehouse no MP e retorna a SafeHouse ativa se houver.
local function checkSafehouseRequirement(square, player)
    if not square or not player then return true, nil end

    local username = player.getUsername and tostring(player:getUsername() or "") or ""
    local shClass = SafeHouse or Safehouse
    local activeSafehouse = nil

    if shClass then
        -- 1. Checagem nativa da engine com pcall
        if shClass.getSafehouse then
            local ok, sh = pcall(shClass.getSafehouse, square)
            if ok and sh then
                activeSafehouse = sh
            elseif square:getZ() > 0 then
                local cell = getCell()
                if cell then
                    local groundSq = cell:getGridSquare(square:getX(), square:getY(), 0)
                    if groundSq then
                        local ok2, sh2 = pcall(shClass.getSafehouse, groundSq)
                        if ok2 and sh2 then activeSafehouse = sh2 end
                    end
                end
            end
        end

        -- 2. Checagem por Bounding Box 2D na lista global
        if not activeSafehouse and shClass.getSafehouseList then
            local ok, list = pcall(shClass.getSafehouseList)
            if ok and list and list.size then
                local px, py = square:getX(), square:getY()
                for i = 0, list:size() - 1 do
                    local sh = list:get(i)
                    if sh and sh.getX and sh.getY and sh.getW and sh.getH then
                        local sx, sy, sw, shH = sh:getX(), sh:getY(), sh:getW(), sh:getH()
                        if px >= sx and px < (sx + sw) and py >= sy and py < (sy + shH) then
                            activeSafehouse = sh
                            break
                        end
                    end
                end
            end
        end
    end

    -- Se o sandbox não exige claim, permite mesmo sem safehouse oficial
    if not LV_Config.get("RequireSafehouseClaim") then
        return true, activeSafehouse
    end

    if not isClient() and not isServer() then
        return true, activeSafehouse
    end

    if activeSafehouse and username ~= "" then
        local sh = activeSafehouse
        local isOwner = false
        local isAllowed = false

        if sh.isOwner then
            local ok, res = pcall(sh.isOwner, sh, username)
            if ok and res == true then isOwner = true end
        end

        if not isOwner and sh.getOwner then
            local ok, ownerName = pcall(sh.getOwner, sh)
            if ok and ownerName and tostring(ownerName):lower() == username:lower() then
                isOwner = true
            end
        end

        if not isOwner and sh.playerAllowed then
            local ok, res = pcall(sh.playerAllowed, sh, username)
            if ok and res == true then isAllowed = true end
        end

        if not isOwner and not isAllowed and sh.getPlayers then
            local ok, playersList = pcall(sh.getPlayers, sh)
            if ok and playersList and playersList.contains then
                local ok2, res2 = pcall(playersList.contains, playersList, username)
                if ok2 and res2 == true then isAllowed = true end
            end
        end

        if isOwner or isAllowed then
            return true, activeSafehouse
        end
    end

    return false, nil
end

--- Inicia a varredura inteligente do ambiente.
function LV_ComfortScanner.startScan(player, isManualTrigger)
    if not LV_Config or not LV_BuffManager then return end
    if not LV_Config.isEnabled() or not player then return end

    local square = player:getCurrentSquare()
    if not square then return end

    -- 1. Verificação e detecção de Safehouse
    local isAllowed, activeSafehouse = checkSafehouseRequirement(square, player)
    if not isAllowed then
        print("[LarVivo] Varredura abortada: Safehouse claim exigida mas não atendida.")
        LV_BuffManager.onUnsafeEnvironment(player)
        return
    end

    -- 2. Nome da Base
    local baseName = "Lar"
    if activeSafehouse then
        if activeSafehouse.getTitle and activeSafehouse:getTitle() and activeSafehouse:getTitle() ~= "" then
            baseName = activeSafehouse:getTitle()
        elseif activeSafehouse.getOwner and activeSafehouse:getOwner() and activeSafehouse:getOwner() ~= "" then
            baseName = "Base (" .. tostring(activeSafehouse:getOwner()) .. ")"
        end
    end

    local room = square.getRoom and square:getRoom()
    if baseName == "Lar" and room and room.getName and room:getName() then
        baseName = tostring(room:getName())
    end

    print(string.format("[LarVivo] Iniciando varredura em '%s' no square (%d, %d, %d)...", baseName, square:getX(), square:getY(), square:getZ()))

    -- 3. Coleta de Tiles para Análise
    -- Camada A: Cômodo Imediato (raio de 6 tiles)
    -- Camada B: Safehouse Global (se houver, amostra de cômodos da base inteira)
    local squaresToScan = {}
    local px, py, pz = square:getX(), square:getY(), square:getZ()
    local cell = getCell()

    if room and room.getSquares then
        local jSquares = room:getSquares()
        for i = 0, jSquares:size() - 1 do
            local sq = jSquares:get(i)
            if sq then table.insert(squaresToScan, sq) end
        end
    else
        local radius = math.min(8, LV_Config.get("ComfortRadiusTiles") or 6)
        if cell then
            for x = px - radius, px + radius do
                for y = py - radius, py + radius do
                    local sq = cell:getGridSquare(x, y, pz)
                    if sq then table.insert(squaresToScan, sq) end
                end
            end
        end
    end

    -- Se estiver em Safehouse grande, adiciona amostragem dos outros cômodos da base para compor o Índice Global
    local isWholeBaseScan = false
    if activeSafehouse and activeSafehouse.getW and activeSafehouse:getW() > 10 and cell then
        isWholeBaseScan = true
        local sx, sy, sw, shH = activeSafehouse:getX(), activeSafehouse:getY(), activeSafehouse:getW(), activeSafehouse:getH()
        -- Amostragem estratégica (step de 3 tiles) para não sobrecarregar
        for x = sx, sx + sw - 1, 3 do
            for y = sy, sy + shH - 1, 3 do
                local sq = cell:getGridSquare(x, y, pz)
                if sq and not sq:isOutside() then
                    table.insert(squaresToScan, sq)
                end
            end
        end
    end

    if #squaresToScan == 0 then
        print("[LarVivo] Nenhum tile encontrado ao redor.")
        LV_BuffManager.onUnsafeEnvironment(player)
        return
    end

    local initialResults = {
        furnitureScore = 0,
        craftBonusScore = 0,
        decorScore = 0,
        lightingScore = 0,
        cleanlinessPenalty = 0,
        squalorBlood = 0,
        squalorBodies = 0,
        squalorRotten = 0,
        squalorTrash = 0,
        squalorClutter = 0,
        squareCount = #squaresToScan,
        baseName = baseName,
        isWholeBaseScan = isWholeBaseScan,
        foundTypes = {},
        discoveredItems = {}
    }

    -- Processa imediatamente se for poucos tiles ou acionamento manual (K)
    if #squaresToScan <= 80 or isManualTrigger then
        for _, sq in ipairs(squaresToScan) do
            pcall(LV_ComfortScanner.processSquare, sq, initialResults)
        end
        LV_ComfortScanner.finalizeScore(player, initialResults)
        return
    end

    -- Varredura time-sliced para bases gigantes
    scanQueue.active = true
    scanQueue.squares = squaresToScan
    scanQueue.index = 1
    scanQueue.total = #squaresToScan
    scanQueue.player = player
    scanQueue.results = initialResults
end

--- Inspeciona um tile individual calculando métricas de conforto e squalor.
function LV_ComfortScanner.processSquare(sq, res)
    if not sq or not res then return end

    -- A. Cadáveres (Penalidade pesada de saúde pública)
    if sq.getDeadBodys then
        local deadBodys = sq:getDeadBodys()
        if deadBodys and deadBodys.size and deadBodys:size() > 0 then
            local count = deadBodys:size()
            res.cleanlinessPenalty = res.cleanlinessPenalty + (count * (LV_ItemScoreData.Penalties.DeadBody or 25))
            res.squalorBodies = res.squalorBodies + (count * (LV_ItemScoreData.Penalties.DeadBody or 25))
        end
    end

    -- B. Mobílias, Decorações, Sangue e Sprites
    if not sq.getObjects then return end
    local objects = sq:getObjects()
    if not objects or not objects.size then return end
    local objCount = objects:size()

    for i = 0, objCount - 1 do
        local obj = objects:get(i)
        if obj then
            local sprite = obj.getSprite and obj:getSprite()
            local spriteName = ""
            if sprite and sprite.getName then
                local rawName = sprite:getName()
                if rawName then
                    spriteName = tostring(rawName):lower()
                end
            end

            -- Detecção de Sangue no Chão
            if spriteName ~= "" and spriteName:find("blood") then
                res.cleanlinessPenalty = res.cleanlinessPenalty + (LV_ItemScoreData.Penalties.BloodSplats or 4)
                res.squalorBlood = res.squalorBlood + (LV_ItemScoreData.Penalties.BloodSplats or 4)
            elseif instanceof and instanceof(obj, "IsoBloodSplat") then
                res.cleanlinessPenalty = res.cleanlinessPenalty + (LV_ItemScoreData.Penalties.BloodSplats or 4)
                res.squalorBlood = res.squalorBlood + (LV_ItemScoreData.Penalties.BloodSplats or 4)
            end

            -- Detecção de Entulho/Lixo/Sujeira no piso
            if spriteName ~= "" and (spriteName:find("trash") or spriteName:find("rubbish") or spriteName:find("debris") or spriteName:find("dirt_") or spriteName:find("grime")) then
                res.cleanlinessPenalty = res.cleanlinessPenalty + (LV_ItemScoreData.Penalties.TrashObject or 8)
                res.squalorTrash = res.squalorTrash + (LV_ItemScoreData.Penalties.TrashObject or 8)
            end

            -- Detecção de Lixeiras / Latas de Lixo Cheias ou com Comida Podre
            local container = obj.getContainer and obj:getContainer()
            local isBin = (container and (container:getType() == "bin" or container:getType() == "trashcan" or container:getType() == "garbageeater")) or
                          spriteName:find("trashbin") or spriteName:find("trash_can") or spriteName:find("garbage")
            if container and isBin then
                local w = (container.getContentsWeight and container:getContentsWeight()) or 0
                local hasRotten = false
                local itms = container.getItems and container:getItems()
                if itms and itms.size then
                    for it = 0, math.min(20, itms:size() - 1) do
                        local curItm = itms:get(it)
                        if curItm and curItm.isRotten and curItm:isRotten() then
                            hasRotten = true
                            break
                        end
                    end
                end

                if w > 1.5 or hasRotten then
                    local trashPenalty = hasRotten and 20 or 12
                    res.cleanlinessPenalty = res.cleanlinessPenalty + trashPenalty
                    res.squalorTrash = res.squalorTrash + trashPenalty

                    -- Se o jogador estiver no raio de proximidade (<= 3 tiles), emite mau cheiro e enjoo
                    local pSq = player and player.getCurrentSquare and player:getCurrentSquare()
                    if pSq then
                        local dx = math.abs(pSq:getX() - sq:getX())
                        local dy = math.abs(pSq:getY() - sq:getY())
                        if dx <= 3 and dy <= 3 then
                            local stats = player.getStats and player:getStats()
                            if stats and CharacterStat and stats.set and stats.get then
                                pcall(function()
                                    if CharacterStat.DISCOMFORT then
                                        stats:set(CharacterStat.DISCOMFORT, math.min(100, (stats:get(CharacterStat.DISCOMFORT) or 0) + 20))
                                    end
                                    if CharacterStat.FOOD_SICKNESS then
                                        stats:set(CharacterStat.FOOD_SICKNESS, math.min(45, (stats:get(CharacterStat.FOOD_SICKNESS) or 0) + 4))
                                    end
                                end)
                            end
                        end
                    end
                end
            end

            -- Bônus de Artesanato / Construção Própria do Jogador
            local isCrafted = (instanceof and instanceof(obj, "IsoThumpable")) or spriteName:find("carpentry_") ~= nil
            if isCrafted and not res.foundTypes["crafted_bonus"] then
                res.craftBonusScore = res.craftBonusScore + 10
                res.foundTypes["crafted_bonus"] = true
                table.insert(res.discoveredItems, "Toque Artesanal")
            end

            local props = sprite and sprite.getProperties and sprite:getProperties()

            -- 1. Camas e Descanso
            local isBed = (IsoFlagType and IsoFlagType.bed and safeHasFlag(props, IsoFlagType.bed)) or
                          spriteName:find("bed") ~= nil or
                          spriteName:find("furniture_bedding_") ~= nil or
                          spriteName:find("carpentry_02_5") ~= nil or
                          spriteName:find("carpentry_02_6") ~= nil or
                          (instanceof and instanceof(obj, "IsoThumpable") and obj.isBed and obj:isBed())

            if isBed and not res.foundTypes["bed"] then
                res.furnitureScore = res.furnitureScore + 25
                res.foundTypes["bed"] = true
                table.insert(res.discoveredItems, "Cama")
            end

            -- 2. Assentos (Cadeiras, Poltronas, Sofás, Bancos)
            local isSeating = (IsoFlagType and IsoFlagType.chair and safeHasFlag(props, IsoFlagType.chair)) or
                              spriteName:find("chair") ~= nil or
                              spriteName:find("sofa") ~= nil or
                              spriteName:find("couch") ~= nil or
                              spriteName:find("bench") ~= nil or
                              spriteName:find("stool") ~= nil or
                              spriteName:find("furniture_seating_") ~= nil or
                              spriteName:find("carpentry_01_3") ~= nil or
                              spriteName:find("carpentry_01_4") ~= nil or
                              (instanceof and instanceof(obj, "IsoThumpable") and obj.isChair and obj:isChair())

            if isSeating and not res.foundTypes["seating"] then
                res.furnitureScore = res.furnitureScore + 15
                res.foundTypes["seating"] = true
                table.insert(res.discoveredItems, "Assento/Sofa")
            end

            -- 3. Mesas e Balcões
            local isTable = (IsoFlagType and IsoFlagType.table and safeHasFlag(props, IsoFlagType.table)) or
                            spriteName:find("table") ~= nil or
                            spriteName:find("desk") ~= nil or
                            spriteName:find("counter") ~= nil or
                            spriteName:find("furniture_tables_") ~= nil or
                            spriteName:find("carpentry_01_2") ~= nil or
                            spriteName:find("carpentry_01_5") ~= nil or
                            (instanceof and instanceof(obj, "IsoThumpable") and obj.isTable and obj:isTable())

            if isTable and not res.foundTypes["table"] then
                res.furnitureScore = res.furnitureScore + 15
                res.foundTypes["table"] = true
                table.insert(res.discoveredItems, "Mesa/Balcao")
            end

            -- 4. Armários, Roupeiros, Estantes, Cômodas, Cristaleiras e Baús
            local isStorage = spriteName:find("storage") ~= nil or
                              spriteName:find("wardrobe") ~= nil or
                              spriteName:find("dresser") ~= nil or
                              spriteName:find("closet") ~= nil or
                              spriteName:find("shelf") ~= nil or
                              spriteName:find("shelves") ~= nil or
                              spriteName:find("shelving") ~= nil or
                              spriteName:find("bookcase") ~= nil or
                              spriteName:find("bookshelf") ~= nil or
                              spriteName:find("cabinet") ~= nil or
                              spriteName:find("cupboard") ~= nil or
                              spriteName:find("furniture_storage_") ~= nil or
                              spriteName:find("furniture_shelving_") ~= nil or
                              spriteName:find("carpentry_02_0") ~= nil or
                              spriteName:find("carpentry_02_1") ~= nil or
                              (obj.getContainer and obj:getContainer() ~= nil)

            if isStorage and not res.foundTypes["storage"] then
                res.furnitureScore = res.furnitureScore + 15
                res.foundTypes["storage"] = true
                table.insert(res.discoveredItems, "Armario/Comoda/Cristaleira")
            end

            -- 5. Tapetes e Peles no Chão
            local isRug = spriteName:find("rug") ~= nil or
                          spriteName:find("carpet") ~= nil or
                          spriteName:find("floors_rugs_") ~= nil or
                          spriteName:find("animal_skin") ~= nil or
                          spriteName:find("cow_skin") ~= nil or
                          spriteName:find("fur") ~= nil or
                          spriteName:find("hide") ~= nil or
                          spriteName:find("mat") ~= nil

            if isRug and not res.foundTypes["rug"] then
                res.furnitureScore = res.furnitureScore + 12
                res.foundTypes["rug"] = true
                table.insert(res.discoveredItems, "Tapete/Pele")
            end

            -- 6. Quadros, Pôsteres, Espelhos e Decorações de Parede
            local isWallDecor = spriteName:find("painting") ~= nil or
                                spriteName:find("poster") ~= nil or
                                spriteName:find("picture") ~= nil or
                                spriteName:find("clock") ~= nil or
                                spriteName:find("mirror") ~= nil or
                                spriteName:find("curtain") ~= nil or
                                spriteName:find("walls_decoration_") ~= nil or
                                spriteName:find("location_") ~= nil or
                                (instanceof and instanceof(obj, "IsoCurtain"))

            if isWallDecor and not res.foundTypes["wall_decor"] then
                res.furnitureScore = res.furnitureScore + 12
                res.foundTypes["wall_decor"] = true
                table.insert(res.discoveredItems, "Quadro/Decoracao")
            end

            -- 7. Fogões, Fornos, Lareiras e Churrasqueiras
            local isCooking = (IsoFlagType and IsoFlagType.stove and safeHasFlag(props, IsoFlagType.stove)) or
                              spriteName:find("stove") ~= nil or
                              spriteName:find("oven") ~= nil or
                              spriteName:find("fireplace") ~= nil or
                              spriteName:find("barbecue") ~= nil or
                              spriteName:find("campfire") ~= nil or
                              spriteName:find("grill") ~= nil or
                              spriteName:find("appliances_cooking_") ~= nil or
                              (instanceof and (instanceof(obj, "IsoStove") or instanceof(obj, "IsoFireplace") or instanceof(obj, "IsoBarbecue")))

            if isCooking and not res.foundTypes["cooking"] then
                res.furnitureScore = res.furnitureScore + 12
                res.foundTypes["cooking"] = true
                table.insert(res.discoveredItems, "Fogao/Lareira")
            end

            -- 8. Fontes de Luz
            local isLightOn = (instanceof and instanceof(obj, "IsoLightSwitch") and obj.isActivated and obj:isActivated()) or
                              (obj.isLightSource and obj:isLightSource()) or
                              spriteName:find("lamp") ~= nil or
                              spriteName:find("candle") ~= nil or
                              spriteName:find("lantern") ~= nil or
                              spriteName:find("lighting_") ~= nil

            if isLightOn and not res.foundTypes["light"] then
                res.lightingScore = res.lightingScore + 15
                res.foundTypes["light"] = true
                table.insert(res.discoveredItems, "Iluminacao")
            end

            -- 9. Eletrônicos (Rádio, TV, Telefone)
            local isMedia = spriteName:find("radio") ~= nil or
                            spriteName:find("television") ~= nil or
                            spriteName:find("tv") ~= nil or
                            spriteName:find("telephone") ~= nil or
                            (instanceof and (instanceof(obj, "IsoRadio") or instanceof(obj, "IsoTelevision")))

            if isMedia and not res.foundTypes["media"] then
                res.furnitureScore = res.furnitureScore + 10
                res.foundTypes["media"] = true
                table.insert(res.discoveredItems, "TV/Radio/Telefone")
            end

            -- 10. Plantas Decorativas
            local isPlant = spriteName:find("plant") ~= nil or
                            spriteName:find("flower") ~= nil or
                            spriteName:find("vegetation_indoor_") ~= nil or
                            spriteName:find("fittings_indoor_") ~= nil

            if isPlant and not res.foundTypes["plant"] then
                res.furnitureScore = res.furnitureScore + 10
                res.foundTypes["plant"] = true
                table.insert(res.discoveredItems, "Planta Decorativa")
            end

            -- 11. Peças Sanitárias e Higiene (Vaso, Pia, Banheira, Chuveiro)
            local isToilet = (instanceof and instanceof(obj, "IsoToilet")) or
                             spriteName:find("toilet") ~= nil or
                             spriteName:find("fixtures_bathroom_01_0") ~= nil or
                             spriteName:find("fixtures_bathroom_01_1") ~= nil or
                             spriteName:find("fixtures_bathroom_01_2") ~= nil or
                             spriteName:find("fixtures_bathroom_01_3") ~= nil

            local isSink = spriteName:find("sink") ~= nil or
                           spriteName:find("fixtures_sinks_") ~= nil or
                           spriteName:find("fixtures_bathroom_01_16") ~= nil or
                           spriteName:find("fixtures_bathroom_01_17") ~= nil or
                           spriteName:find("fixtures_bathroom_01_18") ~= nil or
                           spriteName:find("fixtures_bathroom_01_19") ~= nil

            local isBathShower = spriteName:find("bath") ~= nil or
                                 spriteName:find("shower") ~= nil or
                                 spriteName:find("fixtures_bathroom_01_2") ~= nil or
                                 spriteName:find("fixtures_bathroom_01_3") ~= nil

            if isToilet or isSink or isBathShower then
                local fixMd = (obj.getModData and obj:getModData())
                local fixDirt = (fixMd and fixMd.LV_FixtureDirt) or 0
                if fixDirt > 0 then
                    -- Fixture suja penaliza a higiene e alimenta o Squalor
                    res.cleanlinessPenalty = res.cleanlinessPenalty + (fixDirt * 0.25)
                    res.squalorDirt = (res.squalorDirt or 0) + (fixDirt * 0.35)
                else
                    -- Fixture limpa e higienizada pontua como conforto sanitário
                    local fixType = isToilet and "toilet" or (isSink and "sink" or "bath")
                    if not res.foundTypes["fixture_" .. fixType] then
                        res.furnitureScore = res.furnitureScore + 10
                        res.foundTypes["fixture_" .. fixType] = true
                        local fixLabel = isToilet and "Vaso Sanitario Higienizado" or (isSink and "Pia Limpa" or "Banheira/Chuveiro Limpo")
                        table.insert(res.discoveredItems, fixLabel)
                    end
                end
            end
        end
    end

    -- C. Itens 3D no Mundo (World Objects)
    if not sq.getWorldObjects then return end
    local worldObjects = sq:getWorldObjects()
    if not worldObjects or not worldObjects.size then return end
    local wCount = worldObjects:size()
    if wCount <= 0 then return end

    if wCount > 5 then
        res.squalorClutter = res.squalorClutter + ((wCount - 5) * (LV_ItemScoreData.Penalties.LooseClutter or 1))
    end

    for i = 0, wCount - 1 do
        local wObj = worldObjects:get(i)
        if wObj and wObj.getItem then
            local item = wObj:getItem()
            if item then
                if instanceof and instanceof(item, "Food") and item.isRotten and item:isRotten() then
                    res.cleanlinessPenalty = res.cleanlinessPenalty + (LV_ItemScoreData.Penalties.RottenFood or 12)
                    res.squalorRotten = res.squalorRotten + (LV_ItemScoreData.Penalties.RottenFood or 12)
                else
                    local itemTypeLua = item.getType and tostring(item:getType() or ""):lower() or ""
                    local itemCatLua = item.getDisplayCategory and tostring(item:getDisplayCategory() or ""):lower() or ""
                    local itemNameLua = item.getName and tostring(item:getName() or ""):lower() or ""

                    for tag, score in pairs(LV_ItemScoreData.WorldItemTags or {}) do
                        local tagLower = tag:lower()
                        local matched = false

                        if itemCatLua:find(tagLower) or itemTypeLua:find(tagLower) or itemNameLua:find(tagLower) then
                            matched = true
                        end

                        if matched then
                            local count = res.foundTypes[tag] or 0
                            if count < 3 then
                                res.decorScore = res.decorScore + (score / (count + 1))
                                res.foundTypes[tag] = count + 1
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end

--- Normaliza as pontuações em duas camadas (Cômodo Local + Higiene Global da Base).
function LV_ComfortScanner.finalizeScore(player, res)
    if not player or not res then return end

    -- Se não encontrou nenhum móvel relevante, conforto é 0
    if res.furnitureScore == 0 and res.decorScore == 0 and res.lightingScore == 0 then
        print("[LarVivo] Nenhum elemento de base encontrado ao redor. Conforto = 0.")
        LV_BuffManager.applyScanResults(player, 0, 0, res.baseName)
        return
    end

    -- 1. Cálculo de Conforto Base do Cômodo (0 a 100)
    -- Base limpa começa com 25 pontos garantidos
    local cleanPoints = math.max(0, 25 - (res.cleanlinessPenalty * 0.5))

    -- Mobílias somam diretamente (Cama=25, Assento=15, Mesa=15, Armário=15, Tapete=12, Quadros=12, etc.)
    local furniturePoints = math.min(50, res.furnitureScore)

    -- Bônus de "Toque Artesanal" (+10 pontos extras para móveis construídos pelo jogador)
    local craftBonus = math.min(10, res.craftBonusScore or 0)

    -- Iluminação ativa soma até 15 pontos
    local lightingPoints = math.min(15, res.lightingScore)

    -- Decoração soma até 15 pontos
    local decorPoints = math.min(15, res.decorScore)

    local roomComfort = cleanPoints + furniturePoints + craftBonus + lightingPoints + decorPoints
    local comfortScore = math.floor(math.max(0, math.min(100, roomComfort)))

    -- 2. Cálculo de Squalor / Insalubridade Global da Base (0 a 100)
    local squalorScore = 0
    if LV_Config.isSqualorEnabled() then
        -- Incorpora sujeira agregada de piso da Safehouse ou cômodo
        local locKey = (LV_DirtSystem and LV_DirtSystem.getCurrentLocationKey and LV_DirtSystem.getCurrentLocationKey(player, player:getCurrentSquare())) or "outside"
        local floorDirt = (LV_DirtSystem and LV_DirtSystem.getFloorDirt and LV_DirtSystem.getFloorDirt(locKey)) or 0
        if floorDirt > 0 then
            res.cleanlinessPenalty = res.cleanlinessPenalty + (floorDirt * 0.20)
            res.squalorDirt = (res.squalorDirt or 0) + (floorDirt * 0.40)
        end

        local dirtWeight = (LV_Config and LV_Config.get and LV_Config.get("DirtToSqualorWeight")) or 1.0
        local totalDirtAndBlood = (res.squalorBlood * 3) + ((res.squalorDirt or 0) * dirtWeight)
        local rawBlood = math.min(100, totalDirtAndBlood)
        local rawBodies = math.min(100, res.squalorBodies * 2)
        local rawRotten = math.min(100, (res.squalorRotten + res.squalorTrash) * 3)
        local rawClutter = math.min(100, res.squalorClutter * 5)

        squalorScore = (rawBlood * 0.40) + (rawBodies * 0.30) + (rawRotten * 0.20) + (rawClutter * 0.10)
        squalorScore = math.floor(math.max(0, math.min(100, squalorScore)))
    end

    -- 3. Balanceamento de Mansões: Se a base inteira acumular sujeira/cadáveres em outros cômodos,
    -- a penalidade global reduz o conforto do santuário
    if squalorScore > 15 then
        local comfortReduction = math.floor(squalorScore * 0.6)
        comfortScore = math.max(0, comfortScore - comfortReduction)
    end

    -- Regra de Precedência Crítica: Insalubridade severa anula Conforto
    local overrideThreshold = (LV_Config and LV_Config.get and LV_Config.get("SqualorOverrideThreshold")) or 50
    if squalorScore >= overrideThreshold then
        comfortScore = 0
    end

    local itemsSummary = table.concat(res.discoveredItems or {}, ", ")
    print(string.format("[LarVivo] Varredura Concluída: Conforto = %d, Insalubridade = %d | Base: '%s' | Itens: [%s]", comfortScore, squalorScore, tostring(res.baseName or "Lar"), itemsSummary))

    -- 4. Aplica os resultados consolidados no jogador
    LV_BuffManager.applyScanResults(player, comfortScore, squalorScore, res.baseName)
end

--- Handler no OnTick para varredura suave sem micro-stutter
local function onTickScanner()
    if not scanQueue.active then return end
    if not LV_ItemScoreData or not LV_ComfortScanner.finalizeScore then return end

    local processed = 0
    while scanQueue.active and processed < TILES_PER_FRAME do
        if scanQueue.index > scanQueue.total then
            scanQueue.active = false
            local ok, err = pcall(LV_ComfortScanner.finalizeScore, scanQueue.player, scanQueue.results)
            if not ok then
                print("[LarVivo] ERRO em finalizeScore: " .. tostring(err))
            end
            return
        end

        local sq = scanQueue.squares[scanQueue.index]
        local ok, err = pcall(LV_ComfortScanner.processSquare, sq, scanQueue.results)
        if not ok then
            print("[LarVivo] AVISO em processSquare (tile " .. scanQueue.index .. "): " .. tostring(err))
        end
        scanQueue.index = scanQueue.index + 1
        processed = processed + 1
    end
end

Events.OnTick.Add(onTickScanner)
