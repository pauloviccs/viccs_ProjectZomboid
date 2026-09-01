-- =============================================================================
-- Housing Care System (Lar Vivo) - Time-Sliced Room Scanner (LV_ComfortScanner.lua)
-- =============================================================================
-- Autor: VICCS
-- Descrição:
--   Módulo de varredura inteligente para bases de jogadores, safehouses e casas vanilla.
-- =============================================================================

LV_ComfortScanner = LV_ComfortScanner or {}

--- Quantidade de tiles inspecionados por frame (Time-Slicing)
local TILES_PER_FRAME = 25

--- Fila interna de varredura
local scanQueue = {
    active = false,
    squares = {},
    index = 1,
    total = 0,
    player = nil,
    results = {}
}

--- Verifica se o jogador atende ao requisito de Safehouse no MP (Suporte nativo a SafeHouse com H maiúsculo).
local function checkSafehouseRequirement(square, player)
    if not LV_Config.get("RequireSafehouseClaim") then
        return true
    end

    if not isClient() and not isServer() then
        return true
    end

    if not square or not player then return true end

    local username = player.getUsername and player:getUsername() or ""
    local shClass = SafeHouse or Safehouse

    if shClass then
        -- 1. Checagem nativa da engine: isSafehouseAllowInteract ou isSafeHouse
        if shClass.isSafehouseAllowInteract and shClass.isSafehouseAllowInteract(square, player) then
            return true
        end

        if shClass.isSafeHouse and shClass.isSafeHouse(square, username, true) then
            return true
        end

        -- 2. Checagem por getSafehouse(square) com suporte a múltiplos andares
        if shClass.getSafehouse then
            local sh = shClass.getSafehouse(square)
            if not sh and square:getZ() > 0 then
                local cell = getCell()
                if cell then
                    local groundSq = cell:getGridSquare(square:getX(), square:getY(), 0)
                    if groundSq then sh = shClass.getSafehouse(groundSq) end
                end
            end

            if sh then
                if (sh.isOwner and (sh:isOwner(username) or sh:isOwner(player))) or
                   (sh.playerAllowed and (sh:playerAllowed(username) or sh:playerAllowed(player))) or
                   (sh.getPlayers and sh:getPlayers() and sh:getPlayers():contains(username)) or
                   (sh.getOwner and tostring(sh:getOwner()):lower() == tostring(username):lower()) then
                    return true
                end
            end
        end

        -- 3. Checagem por Bounding Box 2D na lista global de safehouses
        if shClass.getSafehouseList then
            local list = shClass.getSafehouseList()
            if list and list.size then
                local px, py = square:getX(), square:getY()
                for i = 0, list:size() - 1 do
                    local sh = list:get(i)
                    if sh and sh.getX and sh.getY and sh.getW and sh.getH then
                        local sx, sy, sw, shH = sh:getX(), sh:getY(), sh:getW(), sh:getH()
                        if px >= sx and px < (sx + sw) and py >= sy and py < (sy + shH) then
                            if (sh.isOwner and (sh:isOwner(username) or sh:isOwner(player))) or
                               (sh.playerAllowed and (sh:playerAllowed(username) or sh:playerAllowed(player))) or
                               (sh.getPlayers and sh:getPlayers() and sh:getPlayers():contains(username)) or
                               (sh.getOwner and tostring(sh:getOwner()):lower() == tostring(username):lower()) then
                                return true
                            end
                        end
                    end
                end
            end
        end

        -- 4. Fallback: se o jogador tem Safehouse no nome dele
        if shClass.hasSafehouse and (shClass.hasSafehouse(player) or shClass.hasSafehouse(username)) then
            return true
        end
    end

    return true
end

--- Inicia a varredura de ambiente para o jogador.
function LV_ComfortScanner.startScan(player, isManualTrigger)
    if not LV_Config or not LV_BuffManager then return end
    if not LV_Config.isEnabled() or not player then return end

    local square = player:getCurrentSquare()
    if not square then return end

    print(string.format("[LarVivo] Iniciando varredura no square (%d, %d, %d)...", square:getX(), square:getY(), square:getZ()))

    -- 1. Verificação de Safehouse Claim (se exigido no MP)
    if not checkSafehouseRequirement(square, player) then
        print("[LarVivo] Varredura abortada: Safehouse claim exigida mas não atendida.")
        LV_BuffManager.onUnsafeEnvironment(player)
        return
    end

    local room = square.getRoom and square:getRoom()

    -- 2. Coleta de Squares a serem processados
    local squaresToScan = {}
    if room and room.getSquares then
        local jSquares = room:getSquares()
        for i = 0, jSquares:size() - 1 do
            local sq = jSquares:get(i)
            if sq then table.insert(squaresToScan, sq) end
        end
    else
        -- Raio de 6 tiles ao redor do jogador (cobre salas de até 13x13 com precisão e velocidade)
        local radius = math.min(8, LV_Config.get("ComfortRadiusTiles") or 6)
        local px, py, pz = square:getX(), square:getY(), square:getZ()
        local cell = getCell()
        if cell then
            for x = px - radius, px + radius do
                for y = py - radius, py + radius do
                    local sq = cell:getGridSquare(x, y, pz)
                    if sq then
                        table.insert(squaresToScan, sq)
                    end
                end
            end
        end
    end

    if #squaresToScan == 0 then
        print("[LarVivo] Nenhum tile encontrado ao redor.")
        LV_BuffManager.onUnsafeEnvironment(player)
        return
    end

    -- Extrai o nome da Safehouse / Cômodo para exibição
    local baseName = "Lar"
    local shClass = SafeHouse or Safehouse
    if shClass and shClass.getSafehouse then
        local sh = shClass.getSafehouse(square)
        if not sh and square:getZ() > 0 then
            local cell = getCell()
            if cell then
                local groundSq = cell:getGridSquare(square:getX(), square:getY(), 0)
                if groundSq then sh = shClass.getSafehouse(groundSq) end
            end
        end
        if sh and sh.getTitle and sh:getTitle() and sh:getTitle() ~= "" then
            baseName = sh:getTitle()
        elseif sh and sh.getOwner and sh:getOwner() and sh:getOwner() ~= "" then
            baseName = "Base (" .. tostring(sh:getOwner()) .. ")"
        end
    end

    if baseName == "Lar" and room and room.getName and room:getName() then
        baseName = tostring(room:getName())
    end

    local initialResults = {
        furnitureScore = 0,
        craftBonusScore = 0, -- Bônus de "Toque Pessoal" por mobílias artesanais
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
        foundTypes = {},
        discoveredItems = {}
    }

    -- Se for poucos tiles (< 80) ou acionamento manual (K), processa instantaneamente
    if #squaresToScan <= 80 or isManualTrigger then
        for _, sq in ipairs(squaresToScan) do
            pcall(LV_ComfortScanner.processSquare, sq, initialResults)
        end
        LV_ComfortScanner.finalizeScore(player, initialResults)
        return
    end

    -- 3. Inicializa o estado do scanner time-sliced
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

    -- A. Cadáveres
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

            -- Detecção de Entulho/Lixo no piso
            if spriteName ~= "" and (spriteName:find("trash") or spriteName:find("rubbish") or spriteName:find("debris") or spriteName:find("dirt_") or spriteName:find("grime")) then
                res.cleanlinessPenalty = res.cleanlinessPenalty + (LV_ItemScoreData.Penalties.TrashObject or 8)
                res.squalorTrash = res.squalorTrash + (LV_ItemScoreData.Penalties.TrashObject or 8)
            end

            -- Bônus de Carpintaria / Artesanato (Móveis construídos manualmente pelo jogador)
            local isCrafted = (instanceof and instanceof(obj, "IsoThumpable")) or spriteName:find("carpentry_") ~= nil
            if isCrafted and not res.foundTypes["crafted_bonus"] then
                res.craftBonusScore = res.craftBonusScore + 10
                res.foundTypes["crafted_bonus"] = true
                table.insert(res.discoveredItems, "Toque Artesanal")
            end

            -- Checagem de IsoFlags via Properties
            local props = sprite and sprite.getProperties and sprite:getProperties()
            local hasProps = props and props.has ~= nil

            -- 1. Camas e Descanso
            local isBed = (hasProps and props:has(IsoFlagType.bed)) or
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
            local isSeating = (hasProps and props:has(IsoFlagType.chair)) or
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
                table.insert(res.discoveredItems, "Assento/Sofá")
            end

            -- 3. Mesas e Balcões
            local isTable = (hasProps and props:has(IsoFlagType.table)) or
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
                table.insert(res.discoveredItems, "Mesa/Balcão")
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
                table.insert(res.discoveredItems, "Armário/Cômoda/Cristaleira")
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
                table.insert(res.discoveredItems, "Quadro/Decoração")
            end

            -- 7. Fogões, Fornos, Lareiras e Churrasqueiras
            local isCooking = (hasProps and props:has(IsoFlagType.stove)) or
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
                table.insert(res.discoveredItems, "Fogão/Lareira")
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
                table.insert(res.discoveredItems, "Iluminação")
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
                table.insert(res.discoveredItems, "TV/Rádio/Telefone")
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
                    local itemType = item.getType and item:getType()
                    local itemTypeLua = itemType and tostring(itemType) or ""
                    for tag, score in pairs(LV_ItemScoreData.WorldItemTags or {}) do
                        local matched = false
                        if item.hasTag then
                            local tagOk, hasIt = pcall(item.hasTag, item, tag)
                            matched = tagOk and hasIt
                        end
                        if not matched and itemTypeLua ~= "" then
                            matched = itemTypeLua:find(tag) ~= nil
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

--- Normaliza as pontuações e consolida Comfort e Squalor Scores.
function LV_ComfortScanner.finalizeScore(player, res)
    if not player or not res then return end

    -- Se não encontrou nenhum móvel relevante, conforto é 0
    if res.furnitureScore == 0 and res.decorScore == 0 and res.lightingScore == 0 then
        print("[LarVivo] Nenhum elemento de base encontrado ao redor. Conforto = 0.")
        LV_BuffManager.applyScanResults(player, 0, 0)
        return
    end

    -- 1. Cálculo de Conforto (0 a 100)
    -- Base limpa começa com 25 pontos garantidos
    local cleanPoints = math.max(0, 25 - (res.cleanlinessPenalty * 0.5))

    -- Mobílias somam diretamente (Cama=25, Assento=15, Mesa=15, Armário=15, Tapete=12, Quadros=12, etc.)
    local furniturePoints = math.min(50, res.furnitureScore)

    -- Bônus de "Toque Artesanal" (Móveis construídos pelo próprio jogador somam até 10 pontos extras)
    local craftBonus = math.min(10, res.craftBonusScore or 0)

    -- Iluminação ativa soma até 15 pontos
    local lightingPoints = math.min(15, res.lightingScore)

    -- Decoração soma até 15 pontos
    local decorPoints = math.min(15, res.decorScore)

    local totalComfort = cleanPoints + furniturePoints + craftBonus + lightingPoints + decorPoints
    local comfortScore = math.floor(math.max(0, math.min(100, totalComfort)))

    -- 2. Cálculo de Squalor (Insalubridade 0 a 100)
    local squalorScore = 0
    if LV_Config.isSqualorEnabled() then
        local rawBlood = math.min(100, res.squalorBlood * 3)
        local rawBodies = math.min(100, res.squalorBodies * 2)
        local rawRotten = math.min(100, (res.squalorRotten + res.squalorTrash) * 3)
        local rawClutter = math.min(100, res.squalorClutter * 5)

        squalorScore = (rawBlood * 0.40) + (rawBodies * 0.30) + (rawRotten * 0.20) + (rawClutter * 0.10)
        squalorScore = math.floor(math.max(0, math.min(100, squalorScore)))
    end

    -- 3. Regra de Precedência: Squalor alto anula Conforto
    local overrideThreshold = LV_Config.get("SqualorOverrideThreshold") or 50
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
