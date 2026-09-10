-- =============================================================================
-- Housing Care System (Lar Vivo) - Whole Safehouse & Room Scanner (LV_ComfortScanner.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Modulo de varredura inteligente em duas camadas:
--   1. Conforto do Comodo Imediato (50% do peso)
--   2. Indice Global de Higiene e Manutencao de toda a Safehouse (50% do peso)
--   Garante balanceamento justo para mansoes pre-mobiliadas exigindo manutencao ativa.
-- =============================================================================

LV_ComfortScanner = LV_ComfortScanner or {}

--- Quantidade de tiles inspecionados por frame (Time-Slicing para performance maxima)
local TILES_PER_FRAME = 25

--- Auxiliar seguro para checar flags no PropertyContainer do PZ B42 sem excecoes de reflexao
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

--- Avalia o status de propriedade e posse da base do square atual
function LV_ComfortScanner.getBuildingOwnershipStatus(square, player)
    if not square or not player then
        return {
            status = "OUTSIDE",
            isOutside = true,
            isClaimed = false,
            baseName = "Area Externa",
            roomName = "Area Externa",
            totalTiles = 0,
            roomCount = 0
        }
    end

    -- 1. Checagem de Area Externa (Ao ar livre)
    if square.isOutside and square:isOutside() then
        return {
            status = "OUTSIDE",
            isOutside = true,
            isClaimed = false,
            baseName = "Area Externa",
            roomName = "Area Externa",
            totalTiles = 0,
            roomCount = 0
        }
    end

    local username = player.getUsername and tostring(player:getUsername() or "") or ""
    local pMd = player.getModData and player:getModData()
    local building = (square.getBuilding and square:getBuilding()) or (square.getRoom and square:getRoom() and square:getRoom().getBuilding and square:getRoom():getBuilding())
    local bId = building and building.getID and building:getID()
    local bDef = building and building.getDef and building:getDef()
    local defId = bDef and bDef.getID and bDef:getID()
    local room = square.getRoom and square:getRoom()
    local roomName = (room and room.getName and room:getName()) or "Residencia"

    -- Calculo de Dimensoes / Tamanho da Base (Tiles e Comodos)
    local totalTiles = 0
    local roomCount = 0
    local bRooms = building and (building.rooms or building.Rooms)
    if bRooms and bRooms.size then
        local okCount, num = pcall(bRooms.size, bRooms)
        if okCount and num and num > 0 then
            roomCount = num
            for r = 0, num - 1 do
                local rObj = bRooms:get(r)
                if rObj and rObj.getSquares then
                    local okS, rSquares = pcall(rObj.getSquares, rObj)
                    if okS and rSquares and rSquares.size then
                        totalTiles = totalTiles + rSquares:size()
                    end
                end
            end
        end
    end
    if roomCount == 0 and bDef and bDef.getRooms then
        local okDefs, rDefs = pcall(bDef.getRooms, bDef)
        if okDefs and rDefs and rDefs.size and rDefs:size() > 0 then
            roomCount = rDefs:size()
            for rd = 0, roomCount - 1 do
                local rDef = rDefs:get(rd)
                local rObj = rDef and rDef.getIsoRoom and rDef:getIsoRoom()
                if rObj and rObj.getSquares then
                    local okS, rSquares = pcall(rObj.getSquares, rObj)
                    if okS and rSquares and rSquares.size then
                        totalTiles = totalTiles + rSquares:size()
                    end
                end
            end
        end
    end
    if totalTiles == 0 and room and room.getSquares then
        local okS, sqs = pcall(room.getSquares, room)
        if okS and sqs and sqs.size then
            totalTiles = sqs:size()
            roomCount = 1
        end
    end

    -- 2. Modo Casual: Se a exigencia de posse foi explicitamente desativada na Sandbox
    if LV_Config and LV_Config.isBaseOwnershipRequired and not LV_Config.isBaseOwnershipRequired() then
        return {
            status = "CLAIMED",
            isOutside = false,
            isClaimed = true,
            isCasual = true,
            baseName = (pMd and pMd.LV_ClaimedBaseName) or "Lar",
            roomName = tostring(roomName),
            building = building,
            buildingId = bId,
            totalTiles = totalTiles,
            roomCount = roomCount
        }
    end

    -- 3. Modo Multiplayer: Validacao oficial de Safehouse
    local shClass = SafeHouse or Safehouse
    local activeSafehouse = nil
    if (isClient and isClient()) or (isServer and isServer()) then
        if shClass then
            if shClass.getSafehouse then
                local ok, sh = pcall(shClass.getSafehouse, square)
                if ok and sh then activeSafehouse = sh end
            end
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

        if activeSafehouse then
            local isOwner = false
            local isAllowed = false
            if activeSafehouse.isOwner then
                local ok, res = pcall(activeSafehouse.isOwner, activeSafehouse, username)
                if ok and res == true then isOwner = true end
            end
            if not isOwner and activeSafehouse.getOwner then
                local ok, oName = pcall(activeSafehouse.getOwner, activeSafehouse)
                if ok and oName and tostring(oName):lower() == username:lower() then isOwner = true end
            end
            if not isOwner and activeSafehouse.playerAllowed then
                local ok, res = pcall(activeSafehouse.playerAllowed, activeSafehouse, username)
                if ok and res == true then isAllowed = true end
            end
            if not isOwner and not isAllowed and activeSafehouse.getPlayers then
                local ok, pList = pcall(activeSafehouse.getPlayers, activeSafehouse)
                if ok and pList and pList.contains then
                    local ok2, res2 = pcall(pList.contains, pList, username)
                    if ok2 and res2 == true then isAllowed = true end
                end
            end

            if isOwner or isAllowed then
                local shTitle = (activeSafehouse.getTitle and activeSafehouse:getTitle()) or ""
                if shTitle == "" and activeSafehouse.getOwner then
                    shTitle = "Base de " .. tostring(activeSafehouse:getOwner())
                end
                if shTitle == "" then shTitle = "Safehouse" end
                return {
                    status = "CLAIMED",
                    isOutside = false,
                    isClaimed = true,
                    baseName = shTitle,
                    roomName = tostring(roomName),
                    building = building,
                    buildingId = bId,
                    safehouse = activeSafehouse,
                    totalTiles = (activeSafehouse.getW and activeSafehouse.getH and (activeSafehouse:getW() * activeSafehouse:getH())) or totalTiles,
                    roomCount = roomCount
                }
            else
                return {
                    status = "OTHER_OWNER",
                    isOutside = false,
                    isClaimed = false,
                    baseName = "Safehouse de Outro Sobrevivente",
                    roomName = tostring(roomName) .. " (Nao Reivindicado)",
                    building = building,
                    buildingId = bId,
                    safehouse = activeSafehouse,
                    totalTiles = totalTiles,
                    roomCount = roomCount
                }
            end
        else
            return {
                status = "UNCLAIMED",
                isOutside = false,
                isClaimed = false,
                baseName = "Imovel Neutro",
                roomName = tostring(roomName) .. " (Nao Reivindicado)",
                building = building,
                buildingId = bId,
                totalTiles = totalTiles,
                roomCount = roomCount
            }
        end
    end

    -- 4. Modo Single Player: Posse por Reivindicacao do Sobrevivente
    local claimedBId = pMd and pMd.LV_ClaimedBaseBuildingId
    local claimedDefId = pMd and pMd.LV_ClaimedBaseDefId
    local isClaimedMatch = false
    if claimedBId and bId and claimedBId == bId then isClaimedMatch = true end
    if not isClaimedMatch and claimedDefId and defId and claimedDefId == defId then isClaimedMatch = true end
    if not isClaimedMatch and pMd and pMd.LV_ClaimedBounds and square then
        local bnds = pMd.LV_ClaimedBounds
        local sx, sy = square:getX(), square:getY()
        if sx >= bnds.x1 and sx <= bnds.x2 and sy >= bnds.y1 and sy <= bnds.y2 then
            isClaimedMatch = true
        end
    end

    if isClaimedMatch then
        local customName = pMd.LV_ClaimedBaseName or "Meu Lar"
        return {
            status = "CLAIMED",
            isOutside = false,
            isClaimed = true,
            baseName = customName,
            roomName = tostring(roomName),
            building = building,
            buildingId = bId or defId,
            totalTiles = totalTiles,
            roomCount = roomCount
        }
    end

    -- Nao e a base do jogador no SP -> Imovel Neutro
    return {
        status = "UNCLAIMED",
        isOutside = false,
        isClaimed = false,
        baseName = "Imovel Neutro",
        roomName = tostring(roomName) .. " (Nao Reivindicado)",
        building = building,
        buildingId = bId,
        totalTiles = totalTiles,
        roomCount = roomCount
    }
end

--- Ponte de retrocompatibilidade para chamadas antigas
local function checkSafehouseRequirement(square, player)
    local own = LV_ComfortScanner.getBuildingOwnershipStatus(square, player)
    return own.isClaimed, own.safehouse, own
end

--- Inicia a varredura inteligente do ambiente.
function LV_ComfortScanner.startScan(player, isManualTrigger)
    if not LV_Config or not LV_BuffManager then return end
    if not LV_Config.isEnabled() or not player then return end

    local square = player:getCurrentSquare()
    if not square then return end

    -- 1. Verificacao de Propriedade, Posse e Ambiente
    local own = LV_ComfortScanner.getBuildingOwnershipStatus(square, player)

    if own.status == "OUTSIDE" then
        print(string.format("[LarVivo] Jogador em area externa (%d, %d, %d). Conforto desativado.", square:getX(), square:getY(), square:getZ()))
        LV_ComfortScanner.RoomBreakdown = LV_ComfortScanner.RoomBreakdown or {}
        local locKey = (LV_DirtSystem and LV_DirtSystem.getCurrentLocationKey and LV_DirtSystem.getCurrentLocationKey(player, square)) or "outside"

        LV_ComfortScanner.RoomBreakdown[locKey] = {
            locKey = locKey,
            roomName = "Area Externa",
            roomScore = 0,
            roomTier = 0,
            safehouseScore = 0,
            safehouseTier = 0,
            cleanPoints = 0,
            furniturePoints = 0,
            lightingPoints = 0,
            decorPoints = 0,
            craftBonus = 0,
            squalorScore = 0,
            seasonalNote = "Ao Ar Livre",
            itemsList = {},
            categoryStats = {},
            timestamp = (getGameTime and getGameTime():getWorldAgeHours()) or 0,
            isOutside = true,
            isClaimed = false,
            baseName = "Area Externa"
        }
        LV_ComfortScanner.LastRoomBreakdown = LV_ComfortScanner.RoomBreakdown[locKey]
        LV_BuffManager.applyScanResults(player, 0, 0, "Area Externa", false, "Ao Ar Livre")
        LV_BuffManager.onUnsafeEnvironment(player)
        return
    end

    if not own.isClaimed then
        print(string.format("[LarVivo] Varredura abortada: Imovel Neutro / Nao Reivindicado em (%d, %d, %d).", square:getX(), square:getY(), square:getZ()))
        local locKey = (LV_DirtSystem and LV_DirtSystem.getCurrentLocationKey and LV_DirtSystem.getCurrentLocationKey(player, square)) or "unclaimed"
        LV_ComfortScanner.RoomBreakdown = LV_ComfortScanner.RoomBreakdown or {}
        LV_ComfortScanner.RoomBreakdown[locKey] = {
            locKey = locKey,
            roomName = own.roomName or "Residencia (Nao Reivindicado)",
            roomScore = 0,
            roomTier = 0,
            safehouseScore = 0,
            safehouseTier = 0,
            cleanPoints = 0,
            furniturePoints = 0,
            lightingPoints = 0,
            decorPoints = 0,
            craftBonus = 0,
            squalorScore = 0,
            seasonalNote = "Imovel Nao Reivindicado",
            itemsList = {},
            categoryStats = {},
            timestamp = (getGameTime and getGameTime():getWorldAgeHours()) or 0,
            isUnclaimed = true,
            isClaimed = false,
            baseName = "Imovel Neutro"
        }
        LV_ComfortScanner.LastRoomBreakdown = LV_ComfortScanner.RoomBreakdown[locKey]
        LV_BuffManager.applyScanResults(player, 0, 0, "Imovel Neutro", false, "Imovel Nao Reivindicado")
        LV_BuffManager.onUnsafeEnvironment(player)
        return
    end

    -- 2. Nome da Base
    local baseName = own.baseName or "Lar"
    local activeSafehouse = own.safehouse
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

    -- 3. Coleta de Tiles para Analise
    -- Camada A: Comodo Imediato (raio de 6 tiles)
    -- Camada B: Safehouse Global (se houver, amostra de comodos da base inteira)
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

    -- Se estiver em Safehouse grande, adiciona amostragem dos outros comodos da base para compor o Indice Global
    local isWholeBaseScan = false
    if activeSafehouse and activeSafehouse.getW and activeSafehouse:getW() > 10 and cell then
        isWholeBaseScan = true
        local sx, sy, sw, shH = activeSafehouse:getX(), activeSafehouse:getY(), activeSafehouse:getW(), activeSafehouse:getH()
        -- Amostragem estrategica (step de 3 tiles) para nao sobrecarregar
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

    -- 4. Contexto Climatico e Sazonalidade Tatica
    local climateContext = {
        seasonName = "Temperado",
        isWinter = false,
        isSummer = false,
        isFreezing = false,
        isHeatwave = false,
        temperature = 20.0,
    }

    if LV_Config and LV_Config.get and (LV_Config.get("EnableSeasonalComfort") ~= false) then
        local cm = getClimateManager and getClimateManager()
        if cm and cm.getAirTemperatureForCharacter and player then
            local ok, t = pcall(cm.getAirTemperatureForCharacter, cm, player)
            if ok and t then
                climateContext.temperature = t
                if t <= 5.0 then climateContext.isFreezing = true end
                if t >= 28.0 then climateContext.isHeatwave = true end
            end
        end

        local gt = getGameTime()
        if gt then
            local s = gt.getSeason and gt:getSeason()
            local m = gt.getMonth and gt:getMonth()
            -- Inverno no hemisferio norte: Dezembro (11), Janeiro (0), Fevereiro (1) ou frio extremo
            if s == 5 or m == 11 or m == 0 or m == 1 or climateContext.isFreezing then
                climateContext.isWinter = true
                climateContext.seasonName = "Inverno"
            -- Verao: Junho (5), Julho (6), Agosto (7) ou calor intenso
            elseif s == 2 or s == 3 or m == 5 or m == 6 or m == 7 or climateContext.isHeatwave then
                climateContext.isSummer = true
                climateContext.seasonName = "Verao"
            elseif m == 8 or m == 9 or m == 10 then
                climateContext.seasonName = "Outono"
            else
                climateContext.seasonName = "Primavera"
            end
        end
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
        discoveredItems = {},
        scoredItemsList = {},
        categoryCounts = {},
        categoryStats = {
            HEAVY_FURNITURE = 0,
            APPLIANCES_ELECTRONICS = 0,
            SURFACE_DECOR = 0,
            ORGANIC_COMFORT_3D = 0,
            PANTRY_SUPPLIES_3D = 0
        },
        climate = climateContext,
        hasActiveHeatInWinter = false,
        hasSummerCooling = false,
        hasBurntBulb = false,
        seasonalNote = "",
    }

    -- Processa imediatamente se for poucos tiles ou acionamento manual
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

--- Registra a pontuacao de um arquetipo de tile no comodo aplicando diminishing returns e tetos
local function registerTileScore(res, archetypeKey, customLabel)
    if not res or not archetypeKey then return end
    local arch = LV_ItemScoreData and LV_ItemScoreData.getTileArchetype and LV_ItemScoreData.getTileArchetype(archetypeKey)
    if not arch then return end

    res.foundTypes = res.foundTypes or {}
    local typeCount = (res.foundTypes[archetypeKey] or 0) + 1
    res.foundTypes[archetypeKey] = typeCount

    local maxArchetype = arch.maxPerRoom or 6
    if typeCount > maxArchetype then
        return -- teto atingido para este arquetipo no comodo
    end

    local cat = arch.category or "HEAVY_FURNITURE"
    res.categoryCounts = res.categoryCounts or {}
    local catCount = (res.categoryCounts[cat] or 0) + 1
    res.categoryCounts[cat] = catCount

    local maxPerCat = 12
    if catCount <= maxPerCat then
        local diminishing = (LV_Config and LV_Config.get and LV_Config.get("EnableDiminishingReturns") ~= false)
        local score = LV_ItemScoreData.getDiminishedScore(arch.score, typeCount, diminishing)

        if cat == "HEAVY_FURNITURE" then
            res.furnitureScore = res.furnitureScore + score
        elseif cat == "APPLIANCES_ELECTRONICS" then
            res.lightingScore = res.lightingScore + score
        elseif cat == "SURFACE_DECOR" then
            res.decorScore = res.decorScore + score
        end

        if res.categoryStats and res.categoryStats[cat] ~= nil then
            res.categoryStats[cat] = res.categoryStats[cat] + score
        end

        local label = customLabel or arch.label or archetypeKey
        table.insert(res.discoveredItems, label)
        if res.scoredItemsList then
            table.insert(res.scoredItemsList, {
                name = label,
                score = score,
                baseScore = arch.score,
                category = cat,
                count = typeCount
            })
        end
    end
end

--- Inspeciona um tile individual calculando metricas de conforto e squalor.
function LV_ComfortScanner.processSquare(sq, res)
    if not sq or not res then return end

    -- A. Cadaveres (Penalidade pesada de saude publica)
    if sq.getDeadBodys then
        local deadBodys = sq:getDeadBodys()
        if deadBodys and deadBodys.size and deadBodys:size() > 0 then
            local count = deadBodys:size()
            res.cleanlinessPenalty = res.cleanlinessPenalty + (count * (LV_ItemScoreData.Penalties.DeadBody or 25))
            res.squalorBodies = res.squalorBodies + (count * (LV_ItemScoreData.Penalties.DeadBody or 25))
        end
    end

    -- B. Mobilias, Decoracoes, Sangue e Sprites
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

            -- Deteccao de Sangue no Chao
            if spriteName ~= "" and spriteName:find("blood") then
                res.cleanlinessPenalty = res.cleanlinessPenalty + (LV_ItemScoreData.Penalties.BloodSplats or 4)
                res.squalorBlood = res.squalorBlood + (LV_ItemScoreData.Penalties.BloodSplats or 4)
            elseif instanceof and instanceof(obj, "IsoBloodSplat") then
                res.cleanlinessPenalty = res.cleanlinessPenalty + (LV_ItemScoreData.Penalties.BloodSplats or 4)
                res.squalorBlood = res.squalorBlood + (LV_ItemScoreData.Penalties.BloodSplats or 4)
            end

            -- Deteccao de Entulho/Lixo/Sujeira no piso
            if spriteName ~= "" and (spriteName:find("trash") or spriteName:find("rubbish") or spriteName:find("debris") or spriteName:find("dirt_") or spriteName:find("grime")) then
                res.cleanlinessPenalty = res.cleanlinessPenalty + (LV_ItemScoreData.Penalties.TrashObject or 8)
                res.squalorTrash = res.squalorTrash + (LV_ItemScoreData.Penalties.TrashObject or 8)
            end

            -- Deteccao de Lixeiras / Latas de Lixo Cheias ou com Comida Podre
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
                    local player = getPlayer and getPlayer()
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

            -- Bonus de Artesanato / Construcao Propria do Jogador
            local isCrafted = (instanceof and instanceof(obj, "IsoThumpable")) or spriteName:find("carpentry_") ~= nil
            if isCrafted and not res.foundTypes["crafted_bonus"] then
                res.craftBonusScore = res.craftBonusScore + 5
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

            if isBed then
                registerTileScore(res, "bed", "Cama de Descanso")
            end

            -- 2. Assentos (Cadeiras, Poltronas, Sofas, Bancos)
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

            if isSeating then
                if spriteName:find("sofa") or spriteName:find("couch") then
                    registerTileScore(res, "couch", "Sofa Acolchoado")
                else
                    registerTileScore(res, "chair", "Cadeira/Poltrona")
                end
            end

            -- 3. Mesas e Balcoes
            local isTable = (IsoFlagType and IsoFlagType.table and safeHasFlag(props, IsoFlagType.table)) or
                            spriteName:find("table") ~= nil or
                            spriteName:find("desk") ~= nil or
                            spriteName:find("counter") ~= nil or
                            spriteName:find("furniture_tables_") ~= nil or
                            spriteName:find("carpentry_01_2") ~= nil or
                            spriteName:find("carpentry_01_5") ~= nil or
                            (instanceof and instanceof(obj, "IsoThumpable") and obj.isTable and obj:isTable())

            if isTable then
                registerTileScore(res, "table", "Mesa/Balcao")
            end

            -- 4. Armarios, Roupeiros, Estantes, Comodas, Cristaleiras e Baus
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

            if isStorage then
                if spriteName:find("book") then
                    registerTileScore(res, "bookshelf", "Estante de Livros")
                else
                    registerTileScore(res, "storage", "Armario/Comoda")
                end
            end

            local cc = res.climate or {}
            local seasonalEnabled = (LV_Config and LV_Config.get and LV_Config.get("EnableSeasonalComfort") ~= false)

            -- 5. Tapetes e Peles no Chao (com Bonus de Isolamento no Inverno)
            local isRug = spriteName:find("rug") ~= nil or
                          spriteName:find("carpet") ~= nil or
                          spriteName:find("floors_rugs_") ~= nil or
                          spriteName:find("animal_skin") ~= nil or
                          spriteName:find("cow_skin") ~= nil or
                          spriteName:find("fur") ~= nil or
                          spriteName:find("hide") ~= nil or
                          spriteName:find("mat") ~= nil

            if isRug then
                if seasonalEnabled and cc.isWinter then
                    registerTileScore(res, "rug_winter", "Tapete Acolchoado (Isolamento Inverno)")
                else
                    registerTileScore(res, "rug", "Tapete/Pele")
                end
            end

            -- 6. Quadros, Posteres, Espelhos e Decoracoes de Parede (com Sombra Termica no Verao)
            local isWallDecor = spriteName:find("painting") ~= nil or
                                spriteName:find("poster") ~= nil or
                                spriteName:find("picture") ~= nil or
                                spriteName:find("clock") ~= nil or
                                spriteName:find("mirror") ~= nil or
                                spriteName:find("curtain") ~= nil or
                                spriteName:find("walls_decoration_") ~= nil or
                                spriteName:find("location_") ~= nil or
                                (instanceof and instanceof(obj, "IsoCurtain"))

            if isWallDecor then
                if spriteName:find("clock") then
                    registerTileScore(res, "clock", "Relogio de Parede")
                elseif spriteName:find("mirror") then
                    registerTileScore(res, "mirror", "Espelho")
                elseif spriteName:find("curtain") or (instanceof and instanceof(obj, "IsoCurtain")) then
                    registerTileScore(res, "curtain", "Cortina")
                else
                    registerTileScore(res, "wall_decor", "Quadro/Decoracao")
                end
            end

            -- Cortinas fechadas bloqueando sol direto em dias escaldantes
            if (instanceof and instanceof(obj, "IsoCurtain")) and seasonalEnabled and cc.isSummer and not res.foundTypes["sun_curtain"] then
                if obj.IsOpen and not obj:IsOpen() then
                    res.decorScore = res.decorScore + 2
                    res.foundTypes["sun_curtain"] = 1
                    table.insert(res.discoveredItems, "Sombra Termica (Cortinas Fechadas)")
                end
            end

            -- 7. Fogoes, Fornos, Lareiras, Aquecedores e Churrasqueiras com Sazonalidade Tatica
            local isFireplace = (instanceof and instanceof(obj, "IsoFireplace")) or
                                spriteName:find("fireplace") ~= nil or
                                spriteName:find("campfire") ~= nil

            local isHeater = spriteName:find("heater") ~= nil or
                             spriteName:find("radiator") ~= nil or
                             spriteName:find("appliances_heating_") ~= nil

            local isAntiqueStove = (spriteName:find("appliances_cooking_01_0") ~= nil or spriteName:find("appliances_cooking_01_1") ~= nil)

            local isCooking = (IsoFlagType and IsoFlagType.stove and safeHasFlag(props, IsoFlagType.stove)) or
                              spriteName:find("stove") ~= nil or
                              spriteName:find("oven") ~= nil or
                              spriteName:find("barbecue") ~= nil or
                              spriteName:find("grill") ~= nil or
                              spriteName:find("appliances_cooking_") ~= nil or
                              (instanceof and (instanceof(obj, "IsoStove") or instanceof(obj, "IsoBarbecue")))

            if isFireplace or isHeater or isAntiqueStove then
                local isLit = (obj.isLit and obj:isLit()) or (obj.isActivated and obj:isActivated()) or false
                if isHeater and not isLit and sq.haveElectricity and sq:haveElectricity() then
                    isLit = true
                end

                if seasonalEnabled and cc.isWinter then
                    if isLit then
                        registerTileScore(res, "heat_source_on", "Aquecimento Ativo (Inverno)")
                        res.hasActiveHeatInWinter = true
                    else
                        registerTileScore(res, "heat_source_off", "Lareira/Aquecedor Apagado")
                    end
                elseif seasonalEnabled and cc.isSummer and isLit and not sq:isOutside() then
                    res.cleanlinessPenalty = res.cleanlinessPenalty + 12
                    res.squalorTrash = res.squalorTrash + 12
                    table.insert(res.discoveredItems, "Calor Sufocante (Fogo no Verao)")
                else
                    registerTileScore(res, "heat_source_off", "Lareira/Fonte de Calor")
                end
            elseif isCooking then
                registerTileScore(res, "stove_oven", "Fogao/Cozinha")
                if LV_StovetopCooking and LV_StovetopCooking.registerStove then
                    LV_StovetopCooking.registerStove(obj, sq)
                end
            end


            -- 8. Fontes de Luz e Ventiladores (Resfriamento de Verao)
            local isFan = spriteName:find("fan") ~= nil or
                          spriteName:find("ventilador") ~= nil or
                          (spriteName:find("lighting_ceiling") ~= nil and spriteName:find("fan") ~= nil)

            if isFan and seasonalEnabled and cc.isSummer and not res.foundTypes["fan_cooling"] then
                local hasPower = (obj.isActivated and obj:isActivated()) or (sq.haveElectricity and sq:haveElectricity()) or false
                if hasPower then
                    registerTileScore(res, "fan_cooling", "Ventilacao Refrescante (Verao)")
                    res.hasSummerCooling = true
                end
            end

            local isBurnt = LV_LightingSystem and LV_LightingSystem.isBulbBurnt and LV_LightingSystem.isBulbBurnt(obj)
            if isBurnt then
                res.hasBurntBulb = true
                res.cleanlinessPenalty = res.cleanlinessPenalty + 4
                res.squalorDirt = (res.squalorDirt or 0) + 5
                table.insert(res.discoveredItems, "Lampada Queimada")
                if res.scoredItemsList then
                    table.insert(res.scoredItemsList, { name = "Lampada de Teto Queimada", score = -4, category = "APPLIANCES_ELECTRONICS" })
                end
            else
                local isLightOn = (instanceof and instanceof(obj, "IsoLightSwitch") and obj.isActivated and obj:isActivated()) or
                                  (obj.isLightSource and obj:isLightSource()) or
                                  spriteName:find("lamp") ~= nil or
                                  spriteName:find("candle") ~= nil or
                                  spriteName:find("lantern") ~= nil or
                                  spriteName:find("lighting_") ~= nil

                if isLightOn then
                    registerTileScore(res, "light_source_on", "Iluminacao Ativa")
                end
            end

            -- 9. Eletronicos (Radio, TV, Telefone, Geladeira)
            local isFridge = spriteName:find("fridge") ~= nil or spriteName:find("refrigerator") ~= nil or spriteName:find("appliances_refrigeration_") ~= nil
            local isMedia = spriteName:find("radio") ~= nil or
                            spriteName:find("television") ~= nil or
                            spriteName:find("tv") ~= nil or
                            spriteName:find("telephone") ~= nil or
                            (instanceof and (instanceof(obj, "IsoRadio") or instanceof(obj, "IsoTelevision")))

            if isFridge then
                registerTileScore(res, "fridge", "Geladeira")
            elseif isMedia then
                registerTileScore(res, "radio_tv", "TV/Radio/Telefone")
                -- Checagem de entretenimento ativo (TV/Radio ligado emitindo sinal)
                local isPlaying = false
                if obj.getDeviceData then
                    local okDd, dd = pcall(obj.getDeviceData, obj)
                    if okDd and dd and dd.getIsTurnedOn then
                        local okOn, isOn = pcall(dd.getIsTurnedOn, dd)
                        if okOn and isOn == true then
                            isPlaying = true
                        end
                    end
                end
                if isPlaying then
                    res.hasActiveMedia = true
                    if not res.foundTypes["active_media"] then
                        res.foundTypes["active_media"] = true
                        table.insert(res.discoveredItems, "Entretenimento Ativo (TV/Radio Ligado)")
                    end
                end
            end

            -- 10. Plantas Decorativas
            local isPlant = spriteName:find("plant") ~= nil or
                            spriteName:find("flower") ~= nil or
                            spriteName:find("vegetation_indoor_") ~= nil or
                            spriteName:find("fittings_indoor_") ~= nil

            if isPlant then
                registerTileScore(res, "plant", "Planta Decorativa")
            end

            -- 11. Pecas Sanitarias e Higiene (Vaso, Cabines, Pia, Banheira, Chuveiro)
            local isToilet = (instanceof and instanceof(obj, "IsoToilet")) or
                             spriteName:find("toilet") ~= nil or
                             spriteName:find("latrine") ~= nil or
                             spriteName:find("outhouse") ~= nil or
                             spriteName:find("fixtures_bathroom_02_") ~= nil
            if not isToilet then
                for idx = 0, 11 do
                    if spriteName:find("fixtures_bathroom_01_" .. tostring(idx)) ~= nil then
                        isToilet = true
                        break
                    end
                end
            end

            local isSink = spriteName:find("sink") ~= nil or
                           spriteName:find("fixtures_sinks_") ~= nil or
                           spriteName:find("fixtures_bathroom_01_16") ~= nil or
                           spriteName:find("fixtures_bathroom_01_17") ~= nil or
                           spriteName:find("fixtures_bathroom_01_18") ~= nil or
                           spriteName:find("fixtures_bathroom_01_19") ~= nil

            local isBathShower = spriteName:find("bath") ~= nil or
                                 spriteName:find("shower") ~= nil or
                                 spriteName:find("fixtures_bathroom_01_24") ~= nil or
                                 spriteName:find("fixtures_bathroom_01_25") ~= nil or
                                 spriteName:find("fixtures_bathroom_01_26") ~= nil or
                                 spriteName:find("fixtures_bathroom_01_27") ~= nil or
                                 spriteName:find("fixtures_bathroom_01_32") ~= nil or
                                 spriteName:find("fixtures_bathroom_01_33") ~= nil

            if isToilet or isSink or isBathShower then
                local fixMd = (obj.getModData and obj:getModData())
                local fixDirt = (fixMd and fixMd.LV_FixtureDirt) or 0
                local fixHealth = (fixMd and fixMd.applianceHealth ~= nil) and tonumber(fixMd.applianceHealth) or 100.0

                if fixDirt > 0 then
                    -- Fixture suja penaliza a higiene e alimenta o Squalor
                    res.cleanlinessPenalty = res.cleanlinessPenalty + (fixDirt * 0.25)
                    res.squalorDirt = (res.squalorDirt or 0) + (fixDirt * 0.35)
                end

                if fixHealth < 30.0 then
                    -- Aparelho danificado ou quebrado injeta penalidade de manutencao no Squalor
                    local healthDeficit = (30.0 - fixHealth)
                    res.cleanlinessPenalty = res.cleanlinessPenalty + (healthDeficit * 0.3)
                    res.squalorDirt = (res.squalorDirt or 0) + (healthDeficit * 0.4)
                end

                if fixDirt <= 0 and fixHealth >= 50.0 then
                    -- Fixture limpa e em bom estado pontua como conforto sanitario
                    local fixType = isToilet and "toilet" or (isSink and "sink" or "bath")
                    if not res.foundTypes["fixture_" .. fixType] then
                        local fixPts = (isToilet and 4) or (isBathShower and 4) or 3
                        res.furnitureScore = res.furnitureScore + fixPts
                        res.foundTypes["fixture_" .. fixType] = true
                        local fixLabel = isToilet and "Vaso Sanitario Higienizado" or (isSink and "Pia Limpa" or "Banheira/Chuveiro Limpo")
                        table.insert(res.discoveredItems, fixLabel)
                    end
                end
            end
        end
    end

    -- C. Itens 3D no Mundo (World Objects) com Avaliacao O(1) e Tetos de Sandbox
    if not sq.getWorldObjects then return end
    local worldObjects = sq:getWorldObjects()
    if not worldObjects or not worldObjects.size then return end
    local wCount = worldObjects:size()
    if wCount <= 0 then return end

    local maxPerTile = (LV_Config and LV_Config.getMax3DItemsPerTile and LV_Config.getMax3DItemsPerTile()) or 10
    local maxPerCategory = (LV_Config and LV_Config.getMax3DItemsPerRoomCategory and LV_Config.getMax3DItemsPerRoomCategory()) or 6
    local diminishingEnabled = (LV_Config and LV_Config.isDiminishingReturnsEnabled and LV_Config.isDiminishingReturnsEnabled()) ~= false

    if wCount > maxPerTile then
        res.squalorClutter = res.squalorClutter + ((wCount - maxPerTile) * (LV_ItemScoreData.Penalties.LooseClutter or 1))
    end

    local evalLimit = math.min(wCount, maxPerTile)
    for i = 0, evalLimit - 1 do
        local wObj = worldObjects:get(i)
        if wObj and wObj.getItem then
            local item = wObj:getItem()
            if item then
                local eval = LV_ItemScoreData and LV_ItemScoreData.evaluateItem and LV_ItemScoreData.evaluateItem(item)
                if eval then
                    if eval.isRotten then
                        res.cleanlinessPenalty = res.cleanlinessPenalty + (LV_ItemScoreData.Penalties.RottenFood or 12)
                        res.squalorRotten = res.squalorRotten + (LV_ItemScoreData.Penalties.RottenFood or 12)
                        if res.scoredItemsList then
                            table.insert(res.scoredItemsList, { name = eval.label .. " (Podre)", score = -12, category = "SQUALOR_DEBRIS" })
                        end
                    else
                        local cat = eval.category or "ORGANIC_COMFORT_3D"
                        res.categoryCounts = res.categoryCounts or {}
                        local curCount = (res.categoryCounts[cat] or 0) + 1
                        res.categoryCounts[cat] = curCount

                        if curCount <= maxPerCategory then
                            local finalItemScore = LV_ItemScoreData.getDiminishedScore(eval.score, curCount, diminishingEnabled)
                            res.decorScore = res.decorScore + finalItemScore
                            if res.categoryStats and res.categoryStats[cat] ~= nil then
                                res.categoryStats[cat] = res.categoryStats[cat] + finalItemScore
                            end
                            if res.scoredItemsList then
                                table.insert(res.scoredItemsList, {
                                    name = eval.label,
                                    score = finalItemScore,
                                    baseScore = eval.score,
                                    category = cat,
                                    count = curCount
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

--- Normaliza as pontuacoes em duas camadas (Comodo Local + Higiene Global da Base).
function LV_ComfortScanner.finalizeScore(player, res)
    if not player or not res then return end

    -- Se nao encontrou nenhum movel relevante, conforto e 0
    if res.furnitureScore == 0 and res.decorScore == 0 and res.lightingScore == 0 then
        print("[LarVivo] Nenhum elemento de base encontrado ao redor. Conforto = 0.")
        LV_BuffManager.applyScanResults(player, 0, 0, res.baseName)
        return
    end

    -- 1. Calculo de Conforto Base do Comodo (0 a 100)
    -- Base limpa comeca com 10 pontos garantidos (nerfado de 25 para exigir mobilia real)
    local cleanPoints = math.max(0, 10 - (res.cleanlinessPenalty * 0.5))

    -- Mobilias somam com tetos balanceados (teto reduzido de 50 para 40)
    local furniturePoints = math.min(40, res.furnitureScore)

    -- Bonus de "Toque Artesanal" (+5 pontos extras para moveis construidos pelo jogador)
    local craftBonus = math.min(5, res.craftBonusScore or 0)

    -- Iluminacao ativa soma ate 10 pontos (nerfado de 15)
    local lightingPoints = math.min(10, res.lightingScore)

    -- Decoracao e itens 3D somam ate 25 pontos (ampliado de 20 para recompensar clutter organizado)
    local decorPoints = math.min(25, res.decorScore)

    local roomComfort = cleanPoints + furniturePoints + craftBonus + lightingPoints + decorPoints
    local comfortScore = math.floor(math.max(0, math.min(100, roomComfort)))

    -- 2. Calculo de Squalor / Insalubridade Global da Base (0 a 100)
    local squalorScore = 0
    if LV_Config.isSqualorEnabled() then
        -- Incorpora sujeira agregada de piso da Safehouse ou comodo
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

    -- 3. Balanceamento de Mansoes: Se a base inteira acumular sujeira/cadaveres em outros comodos,
    -- a penalidade global reduz o conforto do santuario
    if squalorScore > 15 then
        local comfortReduction = math.floor(squalorScore * 0.6)
        comfortScore = math.max(0, comfortScore - comfortReduction)
    end

    -- Regra de Precedencia Critica: Insalubridade severa anula Conforto
    local overrideThreshold = (LV_Config and LV_Config.get and LV_Config.get("SqualorOverrideThreshold")) or 50
    if squalorScore >= overrideThreshold then
        comfortScore = 0
    end

    -- 4. Calculo do Tier Independente do Comodo
    local t1 = (LV_Config and LV_Config.get and LV_Config.get("Tier1Threshold")) or 20
    local t2 = (LV_Config and LV_Config.get and LV_Config.get("Tier2Threshold")) or 40
    local t3 = (LV_Config and LV_Config.get and LV_Config.get("Tier3Threshold")) or 60
    local t4 = (LV_Config and LV_Config.get and LV_Config.get("Tier4Threshold")) or 80

    local roomTier = 0
    if comfortScore >= t4 then roomTier = 4
    elseif comfortScore >= t3 then roomTier = 3
    elseif comfortScore >= t2 then roomTier = 2
    elseif comfortScore >= t1 then roomTier = 1
    end

    -- 5. Avaliacao e Feedback de Clima Sazonal
    local cc = res.climate or {}
    local seasonalEnabled = (LV_Config and LV_Config.get and LV_Config.get("EnableSeasonalComfort") ~= false)
    local seasonalNote = "Clima Estavel"

    if seasonalEnabled then
        if cc.isWinter then
            if cc.isFreezing and not res.hasActiveHeatInWinter then
                comfortScore = math.max(0, comfortScore - 10)
                seasonalNote = string.format("Inverno (%dC) - Falta Aquecimento!", math.floor(cc.temperature or 0))
            elseif res.hasActiveHeatInWinter then
                seasonalNote = string.format("Inverno (%dC) - Aquecimento Ativo (+8 pts)", math.floor(cc.temperature or 0))
            else
                seasonalNote = string.format("Inverno (%dC) - Frio Moderado", math.floor(cc.temperature or 0))
            end
        elseif cc.isSummer then
            if res.hasSummerCooling then
                seasonalNote = string.format("Verao (%dC) - Ventilacao Ativa (+4 pts)", math.floor(cc.temperature or 0))
            elseif cc.isHeatwave then
                seasonalNote = string.format("Verao (%dC) - Calor Intenso", math.floor(cc.temperature or 0))
            else
                seasonalNote = string.format("Verao (%dC) - Clima Quente", math.floor(cc.temperature or 0))
            end
        elseif cc.seasonName then
            seasonalNote = string.format("%s (%dC) - Clima Agradavel", cc.seasonName, math.floor(cc.temperature or 20))
        end
    end

    -- 6. Cache Estruturado do Detalhamento do Comodo e Agregacao da Safehouse Geral
    local pSq = player and player.getCurrentSquare and player:getCurrentSquare()
    local locKey = (LV_DirtSystem and LV_DirtSystem.getCurrentLocationKey and LV_DirtSystem.getCurrentLocationKey(player, pSq)) or "room_default"

    -- Identificacao de Safehouse para calculo do Tier Geral da Base de forma separada
    local shClass = SafeHouse or Safehouse
    local curSafehouse = nil
    if shClass and shClass.getSafehouse and pSq then
        local okSh, shObj = pcall(shClass.getSafehouse, pSq)
        if okSh and shObj then curSafehouse = shObj end
    end

    LV_ComfortScanner.SafehousesData = LV_ComfortScanner.SafehousesData or {}
    local safehouseScore = comfortScore
    local safehouseTier = roomTier

    if curSafehouse then
        local shId = (curSafehouse.getTitle and curSafehouse:getTitle()) or (curSafehouse.getId and curSafehouse:getId()) or (res.baseName or "Safehouse")
        LV_ComfortScanner.SafehousesData[shId] = LV_ComfortScanner.SafehousesData[shId] or { rooms = {} }
        local shData = LV_ComfortScanner.SafehousesData[shId]

        shData.rooms[locKey] = {
            score = comfortScore,
            tier = roomTier,
            name = res.baseName or locKey,
            squalor = squalorScore,
            time = (getGameTime and getGameTime():getWorldAgeHours()) or 0
        }

        local sumScore = 0
        local sumSqualor = 0
        local roomCount = 0
        for _, r in pairs(shData.rooms) do
            sumScore = sumScore + (r.score or 0)
            sumSqualor = sumSqualor + (r.squalor or 0)
            roomCount = roomCount + 1
        end

        local avgScore = (roomCount > 0) and (sumScore / roomCount) or comfortScore
        local avgSqualor = (roomCount > 0) and (sumSqualor / roomCount) or squalorScore

        -- Bonus de infraestrutura da Safehouse
        local infraBonus = 0
        if LV_HouseDashboard and LV_HouseDashboard.getInstance then
            local dash = LV_HouseDashboard.getInstance()
            local dData = dash and dash.cachedData
            if dData then
                if dData.hasGenerator and dData.isActivated then
                    infraBonus = infraBonus + 5
                end
                if dData.waterTotal and dData.waterTotal >= 200 then
                    infraBonus = infraBonus + 4
                end
            end
        end

        local netShScore = avgScore + infraBonus
        if avgSqualor > 15 then
            netShScore = netShScore - (avgSqualor * 0.40)
        end
        safehouseScore = math.max(0, math.min(100, math.floor(netShScore)))

        if safehouseScore >= t4 then safehouseTier = 4
        elseif safehouseScore >= t3 then safehouseTier = 3
        elseif safehouseScore >= t2 then safehouseTier = 2
        elseif safehouseScore >= t1 then safehouseTier = 1
        else safehouseTier = 0 end

        shData.safehouseScore = safehouseScore
        shData.safehouseTier = safehouseTier
    end
    
    LV_ComfortScanner.RoomBreakdown = LV_ComfortScanner.RoomBreakdown or {}
    LV_ComfortScanner.RoomBreakdown[locKey] = {
        locKey = locKey,
        roomName = res.baseName or "Comodo",
        roomScore = comfortScore,
        roomTier = roomTier,
        safehouseScore = safehouseScore,
        safehouseTier = safehouseTier,
        cleanPoints = cleanPoints,
        furniturePoints = furniturePoints,
        lightingPoints = lightingPoints,
        decorPoints = decorPoints,
        craftBonus = craftBonus,
        squalorScore = squalorScore,
        squalorDirt = math.floor(res.squalorDirt or 0),
        squalorBlood = math.floor(res.squalorBlood or 0),
        seasonalNote = seasonalNote,
        hasActiveMedia = res.hasActiveMedia or false,
        hasActiveHeatInWinter = res.hasActiveHeatInWinter or false,
        rottenFoodCount = math.floor((res.squalorRotten or 0) / 12),
        hasBurntBulb = res.hasBurntBulb or false,
        itemsList = res.scoredItemsList or {},
        categoryStats = res.categoryStats or {},
        timestamp = (getGameTime and getGameTime():getWorldAgeHours()) or 0
    }
    LV_ComfortScanner.LastRoomBreakdown = LV_ComfortScanner.RoomBreakdown[locKey]

    -- Armazena no modData do sobrevivente para consumo de outros subsistemas
    pcall(function()
        local pMd = player:getModData()
        pMd.LV_HasActiveMedia = res.hasActiveMedia or false
        pMd.LV_HasActiveHeatInWinter = res.hasActiveHeatInWinter or false
        pMd.LV_HasBurntBulb = res.hasBurntBulb or false
        pMd.LV_RoomRottenCount = math.floor((res.squalorRotten or 0) / 12)
        pMd.LV_RoomFloorDirt = math.floor(res.squalorDirt or 0)
        pMd.LV_CurrentRoomTier = roomTier
        pMd.LV_CurrentRoomScore = comfortScore
    end)

    local itemsSummary = table.concat(res.discoveredItems or {}, ", ")
    print(string.format("[LarVivo] Varredura Concluida: Comodo '%s' [Tier %d] = %d pts, Insalubridade = %d%% | Sazonal: '%s' | Itens: [%s]", tostring(res.baseName or "Lar"), roomTier, comfortScore, squalorScore, seasonalNote, itemsSummary))

    -- 7. Aplica os resultados consolidados no jogador
    LV_BuffManager.applyScanResults(player, comfortScore, squalorScore, res.baseName, false, seasonalNote)
end

--- Retorna o cache de detalhamento do comodo atual
function LV_ComfortScanner.getRoomBreakdown(locKey)
    if not LV_ComfortScanner.RoomBreakdown then return LV_ComfortScanner.LastRoomBreakdown end
    if locKey and LV_ComfortScanner.RoomBreakdown[locKey] then
        return LV_ComfortScanner.RoomBreakdown[locKey]
    end
    return LV_ComfortScanner.LastRoomBreakdown
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
