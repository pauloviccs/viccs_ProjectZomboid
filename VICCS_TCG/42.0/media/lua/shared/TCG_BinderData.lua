-- =============================================================================
-- Project Zomboid TCG - Shared Binder Data Model & Utilities (TCG_BinderData.lua)
-- =============================================================================
-- Autor: VICCS
-- Descricao:
--   Modulo de dados compartilhado (Shared: Server e Client).
--   Livre de dependencias de interface grafica (Zero ISPanel / Zero TextManager).
--   Fornece persistencia, estrutura de dados dos ficharios, Auto-Heal retroativo
--   e buscas recursivas seguras em inventarios e recipientes.
-- =============================================================================

TCG_BinderData = TCG_BinderData or {}

TCG_BinderData.THEME_KEYS = { "CYAN", "RUBY", "SAPPHIRE", "EMERALD", "GOLD", "AMETHYST" }
TCG_BinderData.BADGES = { "COLLECTOR", "MASTER", "HOLO", "TRADES", "VINTAGE", "CUSTOM" }

--- Busca recursiva de um item por ID em um container e suas sub-mochilas/bolsas
function TCG_BinderData.findItemRecursive(container, itemID)
    if not container or itemID == nil then return nil end
    local wantId = tonumber(itemID)
    if not wantId then return nil end

    if container.getItemWithID then
        local found = container:getItemWithID(wantId)
        if found then return found, container end
    end

    local items = container:getItems()
    if not items then return nil end

    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it then
            if it.getID and it:getID() == wantId then
                return it, container
            end
            if it.IsInventoryContainer and it:IsInventoryContainer() and it.getItemContainer and it:getItemContainer() then
                local nested, nestedContainer = TCG_BinderData.findItemRecursive(it:getItemContainer(), wantId)
                if nested then
                    return nested, nestedContainer
                end
            end
        end
    end
    return nil
end

--- Inicializa e garante persistencia isolada por item fisico com Auto-Heal para saves legados
function TCG_BinderData.getBinderDataFromItem(binderItem)
    if not binderItem then return { collected = {}, activeSet = "base1" } end
    local md = binderItem:getModData()
    if not md.TCG_Binder then
        local uniqueId = tostring(getTimeInMillis()) .. "_" .. tostring(ZombRand(100000, 999999))
        md.TCG_Binder = {
            uuid = uniqueId,
            setId = "base1",
            activeSet = "base1",
            customName = "",
            themeColor = "CYAN",
            badge = "COLLECTOR",
            collected = {}
        }
    end

    local b = md.TCG_Binder
    if not b.uuid then
        b.uuid = tostring(getTimeInMillis()) .. "_" .. tostring(ZombRand(100000, 999999))
    end
    if not b.activeSet or b.activeSet == "" then
        b.activeSet = b.setId or "base1"
    end
    if not b.themeColor or b.themeColor == "" then
        b.themeColor = "CYAN"
    end
    if not b.badge or b.badge == "" then
        b.badge = "COLLECTOR"
    end
    if not b.collected then
        b.collected = {}
    end

    -- AUTO-HEAL: Migra formatos de saves anteriores (chaves numericas, sem zeros ou sem tabela)
    local hasLegacyKeys = false
    for k, v in pairs(b.collected) do
        local sk = tostring(k)
        if (type(k) == "number") or (not sk:find("-")) or (sk:match("%-(%d+)$") and #sk:match("%-(%d+)$") < 3) or (type(v) ~= "table") then
            hasLegacyKeys = true
            break
        end
    end

    if hasLegacyKeys then
        local migrated = {}
        for k, v in pairs(b.collected) do
            local num = nil
            local sId = b.activeSet or "base1"
            local isHolo = false
            local count = 1

            if type(k) == "number" then
                num = k
            elseif type(k) == "string" then
                local prefix, suffix = k:match("^([^-]+)%-(%d+)$")
                if prefix and suffix then
                    sId = prefix
                    num = tonumber(suffix)
                else
                    num = tonumber(k:match("%d+"))
                end
            end

            num = num or 1

            if type(v) == "table" then
                isHolo = v.isHolo or false
                count = v.count or 1
            elseif type(v) == "boolean" then
                isHolo = v
                count = 1
            elseif type(v) == "number" then
                isHolo = false
                count = v
            end

            local newKey = string.format("%s-%03d", sId, num)
            if not migrated[newKey] then
                migrated[newKey] = {
                    number = num,
                    isHolo = isHolo,
                    count = count
                }
            else
                migrated[newKey].count = migrated[newKey].count + count
                if isHolo then migrated[newKey].isHolo = true end
            end
        end
        b.collected = migrated
    end

    return b
end

--- Encontra todos os ficharios no inventario principal ou em recipientes/mochilas equipadas
function TCG_BinderData.findPlayerBinders(playerObj)
    if not playerObj then return {} end
    local inv = playerObj:getInventory()
    if not inv then return {} end

    local binders = {}
    local function scan(container)
        if not container then return end
        local items = container:getItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                local ft = it:getFullType()
                if ft == "Base.TCG_Binder" or ft == "TCG_Binder" then
                    table.insert(binders, it)
                end
                if it.IsInventoryContainer and it:IsInventoryContainer() and it.getItemContainer and it:getItemContainer() then
                    scan(it:getItemContainer())
                end
            end
        end
    end

    scan(inv)
    return binders
end

--- Retorna estatisticas de colecao para uma expansao especifica (sCount, sTotal, sPct)
function TCG_BinderData.getCollectionStatsForSet(binderItem, setId)
    if not binderItem then return 0, 102, 0.0 end
    local bData = TCG_BinderData.getBinderDataFromItem(binderItem)
    local sId = setId or bData.activeSet or "base1"
    local setDef = (TCG_CardRegistry and TCG_CardRegistry.Sets) and TCG_CardRegistry.Sets[sId]
    local totalInSet = (setDef and setDef.total) or 102
    local count = 0

    if bData.collected then
        for cid, info in pairs(bData.collected) do
            if cid:match("^" .. sId .. "%-") and info.count and info.count > 0 then
                count = count + 1
            end
        end
    end
    local pct = (totalInSet > 0) and ((count / totalInSet) * 100.0) or 0.0
    return count, totalInSet, pct
end

--- Alias de conveniencia para o set ativo de um fichario fisico
function TCG_BinderData.getCollectionStatsForItem(binderItem)
    return TCG_BinderData.getCollectionStatsForSet(binderItem)
end

--- Retorna contagem geral total de cartas distintas no fichario e total somado de todas as colecoes
function TCG_BinderData.getGrandTotalStats(binderItem)
    if not binderItem then return 0, 102, 0.0 end
    local bData = TCG_BinderData.getBinderDataFromItem(binderItem)
    local grandTotal = 0
    if TCG_CardRegistry and TCG_CardRegistry.Sets then
        for _, sDef in pairs(TCG_CardRegistry.Sets) do
            grandTotal = grandTotal + (sDef.total or 0)
        end
    end
    if grandTotal <= 0 then grandTotal = 102 end

    local grandCount = 0
    if bData.collected then
        for _, info in pairs(bData.collected) do
            if info.count and info.count > 0 then
                grandCount = grandCount + 1
            end
        end
    end
    local grandPct = (grandTotal > 0) and ((grandCount / grandTotal) * 100.0) or 0.0
    return grandCount, grandTotal, grandPct
end

