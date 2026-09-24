-- =============================================================================
-- VICCS Spores - Renderizacao Visual de Nevoa 3D & Efeitos Atmosfericos (Client)
-- Versao: 1.5.0 (Volumetric Organic Spore Clouds & TLOU Golden Motes - 180+ FPS Engine)
-- =============================================================================

require "ISUI/ISUIElement"
require "VICCSSpores_Grid"

local FogUI = ISUIElement:derive("VICCSSpores_FogUI")

-- Offsets fixos dos sub-puffs para dar volume organico e amorfo a celula
local PUFF_OFFSETS = {
    { -1.0, -0.7 },
    {  1.1, -0.5 },
    { -0.2,  1.0 }
}

function FogUI:initialise()
    ISUIElement.initialise(self)
    self.width = getCore():getScreenWidth()
    self.height = getCore():getScreenHeight()
    self.background = false
    self.currentAlpha = 0.0
    self.targetAlpha = 0.0
    self.animTick = 0
    
    self.screenWidth = getCore():getScreenWidth()
    self.screenHeight = getCore():getScreenHeight()
end

function FogUI:getPuffTexture()
    if self.puffTex then return self.puffTex end
    self.puffTex = getTexture("media/ui/spores/spore_puff.png")
        or getTexture("media/textures/spores/spore_puff.png")
        or getTexture("media/textures/spore_puff.png")
        or getTexture("spore_puff.png")
        or getTexture("media/textures/weather/fogcircle_tex.png")
        or getTexture("media/textures/weather/fogwhite_tex.png")
    return self.puffTex
end

function FogUI:getMoteTexture()
    if self.moteTex then return self.moteTex end
    self.moteTex = getTexture("media/ui/spores/spore_mote.png")
        or getTexture("media/textures/spores/spore_mote.png")
        or getTexture("media/textures/spore_mote.png")
        or getTexture("spore_mote.png")
    return self.moteTex
end

-- =============================================================================
-- BLINDAGEM TOTAL DE EVENTOS DE MOUSE: Nunca consumir cliques do mundo 3D
-- =============================================================================
function FogUI:onMouseDown(x, y) return false end
function FogUI:onMouseUp(x, y) return false end
function FogUI:onRightMouseDown(x, y) return false end
function FogUI:onRightMouseUp(x, y) return false end
function FogUI:onMouseMove(dx, dy) return false end
function FogUI:onMouseWheel(del) return false end
function FogUI:isPointOver(x, y) return false end

function FogUI:update()
    ISUIElement.update(self)
    self.animTick = (self.animTick + 1) % 100000
    
    local player = getPlayer()
    if not player or player:isDead() then
        self.targetAlpha = 0.0
    else
        local px = math.floor(player:getX())
        local py = math.floor(player:getY())
        local pz = math.floor(player:getZ())
        local conc = VICCSSpores.Grid.get(px, py, pz)
        
        if conc > 1.5 and not VICCSSpores.opt("ReduceVisualEffects", false) then
            self.targetAlpha = math.min(0.42, (conc / VICCSSpores.MAX_CONC) * 0.48)
        else
            self.targetAlpha = 0.0
        end
    end
    
    self.currentAlpha = self.currentAlpha + (self.targetAlpha - self.currentAlpha) * 0.08
    self.screenWidth = getCore():getScreenWidth()
    self.screenHeight = getCore():getScreenHeight()
end

function FogUI:renderSporesSafe(player, sw, sh, zoom, pz, reduceFX)
    if reduceFX or not VICCSSpores.Grid then return end
    
    -- Fonte resiliente de dados: no SP acessa Grid.data().cells diretamente; no MP usa clientCache
    local cellSource = nil
    if isClient() then
        cellSource = VICCSSpores.Grid.clientCache
    else
        local d = VICCSSpores.Grid.data and VICCSSpores.Grid.data()
        cellSource = (d and d.cells) or VICCSSpores.Grid.clientCache
    end
    if not cellSource then return end
    
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pcx = math.floor(px / VICCSSpores.CELL)
    local pcy = math.floor(py / VICCSSpores.CELL)
    
    local cm = getClimateManager()
    local windSpeed = 0.12
    local windDirX = 0.8
    local windDirY = 0.6
    if cm then
        if cm.getWindIntensity then windSpeed = cm:getWindIntensity() or 0.12 end
        if cm.getWindAngleIntensity then
            local ang = cm:getWindAngleIntensity() or 0.0
            windDirX = math.cos(ang)
            windDirY = math.sin(ang)
        end
    end
    
    local baseFogSize = math.floor(300 / zoom)
    local tick = self.animTick
    local totalMotesDrawn = 0
    local MAX_MOTES_GLOBAL = 60
    
    local puffTex = self:getPuffTexture()
    local moteTex = self:getMoteTexture()
    
    local cellsToRender = {}
    local cellCount = 0
    
    -- 1. FILTRAGEM ESPACIAL EM GRADE (Raio visual de 8 celulas = 32 tiles ao redor do player)
    for key, rawCell in pairs(cellSource) do
        local cx, cy, cz, conc
        
        if type(rawCell) == "table" then
            cx = rawCell.cx
            cy = rawCell.cy
            cz = rawCell.z
            conc = rawCell.v
        elseif type(rawCell) == "number" then
            conc = rawCell
        end
        
        if (not cx or not cy or not cz) and type(key) == "string" then
            local c1 = string.find(key, ",")
            if c1 then
                local c2 = string.find(key, ",", c1 + 1)
                if c2 then
                    cx = tonumber(string.sub(key, 1, c1 - 1))
                    cy = tonumber(string.sub(key, c1 + 1, c2 - 1))
                    cz = tonumber(string.sub(key, c2 + 1))
                end
            end
        end
        
        if cx and cy and cz and conc and conc >= 1.0 then
            if cz == pz or cz == (pz - 1) then
                local distCellX = math.abs(cx - pcx)
                local distCellY = math.abs(cy - pcy)
                
                if distCellX <= 8 and distCellY <= 8 then
                    cellCount = cellCount + 1
                    cellsToRender[cellCount] = { cx = cx, cy = cy, cz = cz, conc = conc }
                    if cellCount >= 24 then break end
                end
            end
        end
    end
    
    if cellCount == 0 then return end
    
    -- 2. RENDERIZACAO VISUAL DE ALTA FIDELIDADE (THE LAST OF US STYLE)
    for cIdx = 1, cellCount do
        local c = cellsToRender[cIdx]
        local wx = c.cx * VICCSSpores.CELL + 2
        local wy = c.cy * VICCSSpores.CELL + 2
        local cz = c.cz
        local conc = c.conc
        
        local centerSX = isoToScreenX(0, wx, wy, cz)
        local centerSY = isoToScreenY(0, wx, wy, cz)
        
        if centerSX and centerSY and centerSX >= -360 and centerSX <= (sw + 360) and centerSY >= -360 and centerSY <= (sh + 360) then
            local isLowerFloor = (cz < pz)
            local floorDimFactor = isLowerFloor and 0.45 or 1.0
            
            local concRatio = math.min(1.0, conc / VICCSSpores.MAX_CONC)
            local cloudBaseAlpha = math.min(0.72, (0.24 + concRatio * 0.48)) * floorDimFactor
            
            -- Paleta TLOU: Amarelo-ouro fungico evidente / mostarda rica
            local rCloud = 0.78 - (concRatio * 0.08)
            local gCloud = 0.72 - (concRatio * 0.06)
            local bCloud = 0.22 - (concRatio * 0.04)
            
            -- CAMADA A: Puffs Volumetricos Organicos e Amorfos
            if puffTex then
                for pIdx = 1, 3 do
                    local po = PUFF_OFFSETS[pIdx]
                    local puffWX = wx + po[1]
                    local puffWY = wy + po[2]
                    
                    local psx = isoToScreenX(0, puffWX, puffWY, cz)
                    local psy = isoToScreenY(0, puffWX, puffWY, cz)
                    
                    if psx and psy then
                        local breath = 1.0 + 0.12 * math.sin((tick * 0.03) + (c.cx * 1.5) + (c.cy * 1.8) + pIdx)
                        local currentPuffSize = math.floor(baseFogSize * breath)
                        
                        local drift = math.sin((tick * 0.035) + pIdx) * 10
                        local finalPX = psx - (currentPuffSize / 2) + (windDirX * windSpeed * 20) + (drift * 0.4)
                        local finalPY = psy - (currentPuffSize / 2) + (windDirY * windSpeed * 14) + (drift * 0.3)
                        
                        local puffAlpha = cloudBaseAlpha * 0.52
                        self:drawTextureScaled(puffTex, finalPX, finalPY, currentPuffSize, currentPuffSize, puffAlpha, rCloud, gCloud, bCloud)
                    end
                end
            end
            
            -- CAMADA B: Esporos Flutuantes Dourados (Dual-Layer: Ascendentes e Assentamento)
            if totalMotesDrawn < MAX_MOTES_GLOBAL then
                local motesForThisCell = math.floor(5 + (concRatio * 7))
                local moteSize = math.max(4, math.floor(6 / zoom))
                
                for mIdx = 1, motesForThisCell do
                    if totalMotesDrawn >= MAX_MOTES_GLOBAL then break end
                    
                    local seed = (c.cx * 73856093 + c.cy * 19349663 + c.cz * 83492791 + mIdx * 1274126177)
                    if seed < 0 then seed = -seed end
                    
                    local ox = ((seed % 360) / 90.0) - 2.0
                    local oy = (((seed / 360) % 360) / 90.0) - 2.0
                    
                    local isSettling = ((seed % 10) < 3)
                    local elev = 0.0
                    
                    if isSettling then
                        local fallProgress = ((tick * 0.02) + (seed % 100)) % 100
                        elev = math.max(0.0, (100 - fallProgress) / 75.0)
                    else
                        local vSpeed = 0.5 + ((seed % 40) / 80.0)
                        elev = (((tick * 0.03 * vSpeed) + (seed % 100)) % 100) / 55.0
                    end
                    
                    local wobble = math.sin((tick * 0.06) + (seed % 30)) * 0.25
                    local mTileX = wx + ox + (windDirX * windSpeed * 1.0) + wobble
                    local mTileY = wy + oy + (windDirY * windSpeed * 1.0) + wobble
                    
                    local msx = isoToScreenX(0, mTileX, mTileY, cz)
                    local msy = isoToScreenY(0, mTileX, mTileY, cz)
                    
                    if msx and msy then
                        msy = msy - math.floor(elev * 32.0 / zoom)
                        
                        if msx >= 0 and msx <= sw and msy >= 0 and msy <= sh then
                            local pulse = 0.60 + 0.40 * math.sin((tick * 0.09) + (seed % 50))
                            local moteAlpha = math.min(0.98, (0.45 + concRatio * 0.55) * pulse * floorDimFactor)
                            
                            local mr, mg, mb = 0.98, 0.92, 0.35
                            if (seed % 4) == 0 then
                                mr, mg, mb = 1.0, 0.96, 0.60
                            end
                            
                            if isSettling and elev < 0.15 then
                                moteAlpha = moteAlpha * 0.70
                            end
                            
                            if moteTex then
                                self:drawTextureScaled(moteTex, msx - (moteSize / 2), msy - (moteSize / 2), moteSize, moteSize, moteAlpha, mr, mg, mb)
                            else
                                self:drawRect(msx, msy, moteSize, moteSize, moteAlpha, mr, mg, mb)
                            end
                            
                            totalMotesDrawn = totalMotesDrawn + 1
                        end
                    end
                end
            end
        end
    end
end

function FogUI:prerender()
    local player = getPlayer()
    if not player or player:isDead() then return end
    
    local sw = self.screenWidth or getCore():getScreenWidth()
    local sh = self.screenHeight or getCore():getScreenHeight()
    local zoom = getCore():getZoom(0) or 1.0
    if not zoom or zoom <= 0 then zoom = 1.0 end
    
    local pz = math.floor(player:getZ())
    local reduceFX = VICCSSpores.opt("ReduceVisualEffects", false)
    
    local ok, err = pcall(self.renderSporesSafe, self, player, sw, sh, zoom, pz, reduceFX)
    if not ok and isDebugEnabled() then
        print("[VICCS Spores FX WARN]: " .. tostring(err))
    end
    
    -- Vinheta periferica suave de opressao pulmonar quando imerso
    if self.currentAlpha > 0.01 then
        local border = math.floor(math.min(sw, sh) * 0.16)
        local a = self.currentAlpha
        local r, g, b = 0.10, 0.14, 0.04
        
        self:drawRect(0, 0, sw, border, a, r, g, b)
        self:drawRect(0, sh - border, sw, border, a, r, g, b)
        self:drawRect(0, border, border, sh - (border * 2), a, r, g, b)
        self:drawRect(sw - border, border, border, sh - (border * 2), a, r, g, b)
    end
end

local function initFogUI()
    if FogUI.instance then return end
    
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local ui = FogUI:new(0, 0, sw, sh)
    ui:initialise()
    ui:instantiate()
    
    if ui.javaObject then
        ui.javaObject:setConsumeMouseEvents(false)
        ui.javaObject:setIgnoreLossControl(true)
    end
    
    ui:addToUIManager()
    FogUI.instance = ui
end

Events.OnCreateUI.Add(initFogUI)

print("[VICCS Spores v" .. VICCSSpores.VERSION .. "] Modulo Visual v1.5.0 (TLOU Volumetric Spores & Motes) ativo.")
