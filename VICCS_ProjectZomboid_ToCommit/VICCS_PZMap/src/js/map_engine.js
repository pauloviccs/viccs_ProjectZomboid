/**
 * VICCS_PZMap - Motor de Mapa Isométrico Original (PZMap DZI), Sistema GPS e HUD
 * Renderiza tiles isométricos (1024x1024) com cache local em Rust e Rotas Estilo GTA V / Waze
 */

import { PZ_MAP_CONFIG, pzToLatLng, latLngToPz, getPzCellInfo, KNOX_TOWNS } from './pz_projection.js';
import { GpsRoadRouter } from './gps_router.js';

export class PZMapEngine {
  constructor(mapContainerId, onCoordinatesUpdate) {
    this.containerId = mapContainerId;
    this.onCoordinatesUpdate = onCoordinatesUpdate;
    this.currentFloor = 0;
    this.map = null;
    this.canvasRenderer = null;

    // Camadas de Tiles
    this.dziTileLayer = null;
    this.townsLayer = null;
    this.buildingsLayer = null;

    // Roteador de Estradas GPS (A* Pathfinding)
    this.gpsRouter = new GpsRoadRouter();

    // Sistema de GPS / Rota GTA V / Waze
    this.gpsDestination = null; // { x, y, name }
    this.gpsRouteLine = null;
    this.gpsRouteGlow = null;
    this.gpsWaypointMarker = null;
    this.onGpsUpdate = null;
    this.lastPlayerPos = null;

    // Estado do Mapa
    this.showIsoTiles = true;
    this.activeCategories = new Set(['police', 'gun', 'medical', 'pharmacy', 'gas', 'hardware', 'grocery', 'fire', 'prison']);
    this.allBuildingsData = [];
    this.categoriesMeta = {};
  }

  async init() {
    // Inicializa o roteador de estradas
    this.gpsRouter.init();
    // 1. Inicializa o mapa com Leaflet CRS.Simple com limite ideal de zoom (11 a 20)
    this.map = L.map(this.containerId, {
      crs: L.CRS.Simple,
      minZoom: PZ_MAP_CONFIG.minZoom,
      maxZoom: PZ_MAP_CONFIG.maxZoom,
      zoomControl: false,
      attributionControl: false,
      preferCanvas: true,
      fadeAnimation: false,
      zoomAnimation: true,
      wheelPxPerZoomLevel: 120,
    });

    this.canvasRenderer = L.canvas({ padding: 0.5 });

    // 2. Cria a camada de Tiles Isométricos Originais (DZI)
    this.createDziTileLayer();

    // 3. Define o centro inicial em Muldraugh com zoom 15
    const startLatLng = pzToLatLng(PZ_MAP_CONFIG.defaultCenter[0], PZ_MAP_CONFIG.defaultCenter[1], 0);
    this.map.setView(startLatLng, PZ_MAP_CONFIG.defaultZoom);

    // 4. Carrega os dados vetoriais (Cidades e Prédios)
    await this.loadMapData();

    // 5. Escuta zoom do mapa para ajustar Level-of-Detail (LOD)
    this.map.on('zoomend', () => {
      this.updateLOD();
    });

    // 6. Escuta movimentação do cursor para telemetria de coordenadas
    this.map.on('mousemove', (e) => {
      const pzCoords = latLngToPz(e.latlng, this.currentFloor);
      const cellInfo = getPzCellInfo(pzCoords.x, pzCoords.y);
      if (this.onCoordinatesUpdate) {
        this.onCoordinatesUpdate({
          x: pzCoords.x,
          y: pzCoords.y,
          z: this.currentFloor,
          cell: cellInfo.cell,
          chunk: cellInfo.chunk,
          zoom: this.map.getZoom(),
        });
      }
    });

    // 7. Clique no mapa com botão direito ou duplo clique permite marcar destino GPS
    this.map.on('contextmenu', (e) => {
      const pzCoords = latLngToPz(e.latlng, this.currentFloor);
      this.setGpsDestination(pzCoords.x, pzCoords.y, `Destino Marcado (${pzCoords.x}, ${pzCoords.y})`);
    });

    return this;
  }

  /**
   * Cria a camada de Tiles Isométricos DZI (1024x1024) do Project Zomboid
   */
  createDziTileLayer() {
    if (this.dziTileLayer) {
      this.map.removeLayer(this.dziTileLayer);
    }

    const self = this;
    const isTauri = typeof window.__TAURI__ !== 'undefined';

    const DZILayerClass = L.TileLayer.extend({
      getTileUrl(coords) {
        const floor = self.currentFloor;
        const ext = floor === 0 ? 'jpg' : 'webp';
        return `https://tiles.pzmap.net/base/layer${floor}_files/${coords.z}/${coords.x}_${coords.y}.${ext}`;
      },
      createTile(coords, done) {
        const tile = document.createElement('img');
        tile.alt = '';
        tile.setAttribute('role', 'presentation');
        tile.style.pointerEvents = 'none';

        const floor = self.currentFloor;
        const ext = floor === 0 ? 'jpg' : 'webp';
        const cdnUrl = `https://tiles.pzmap.net/base/layer${floor}_files/${coords.z}/${coords.x}_${coords.y}.${ext}`;

        // Tenta carregar do cache local Rust se estiver no Tauri
        if (isTauri && window.__TAURI__?.core?.invoke) {
          window.__TAURI__.core.invoke('get_tile', {
            layer: `layer${floor}`,
            z: coords.z,
            x: coords.x,
            y: coords.y,
          }).then((dataUrl) => {
            tile.src = dataUrl;
            done(null, tile);
          }).catch(() => {
            tile.src = cdnUrl;
            tile.onload = () => done(null, tile);
            tile.onerror = () => {
              tile.style.display = 'none';
              done(null, tile);
            };
          });
        } else {
          tile.src = cdnUrl;
          tile.onload = () => done(null, tile);
          tile.onerror = () => {
            tile.style.display = 'none';
            done(null, tile);
          };
        }

        return tile;
      }
    });

    this.dziTileLayer = new DZILayerClass('', {
      tileSize: 1024,
      noWrap: true,
      minZoom: PZ_MAP_CONFIG.minZoom,
      maxZoom: PZ_MAP_CONFIG.maxZoom,
      maxNativeZoom: 20,
      zIndex: 1,
    });

    if (this.showIsoTiles) {
      this.dziTileLayer.addTo(this.map);
    }
  }

  /**
   * Controla a densidade de ícones com base no nível de Zoom (Level-of-Detail)
   */
  updateLOD() {
    const currentZoom = this.map.getZoom();
    if (this.buildingsLayer) {
      // Esconde ícones pequenos de prédios se estiver muito distante (zoom < 14) para não poluir
      if (currentZoom < 14) {
        if (this.map.hasLayer(this.buildingsLayer)) {
          this.map.removeLayer(this.buildingsLayer);
        }
      } else {
        if (!this.map.hasLayer(this.buildingsLayer)) {
          this.map.addLayer(this.buildingsLayer);
        }
      }
    }
  }

  /**
   * Carrega metadados e arquivos de apoio
   */
  async loadMapData() {
    try {
      const metaRes = await fetch('./data/meta.json');
      if (metaRes.ok) {
        const meta = await metaRes.json();
        this.categoriesMeta = meta.categories || {};
      }

      // Cidades
      this.renderTowns();

      // Prédios e Pontos de Loot
      const bldRes = await fetch('./data/buildings_index.json');
      if (bldRes.ok) {
        const bldData = await bldRes.json();
        this.allBuildingsData = bldData.buildings || [];
        this.renderBuildings();
      }

      this.updateLOD();
    } catch (err) {
      console.error('Erro ao carregar dados do mapa:', err);
    }
  }

  /**
   * Renderiza os rótulos das cidades com botão rápido de GPS
   */
  renderTowns() {
    if (this.townsLayer) this.map.removeLayer(this.townsLayer);
    this.townsLayer = L.layerGroup();

    KNOX_TOWNS.forEach((town) => {
      const latlng = pzToLatLng(town.x, town.y, 0);

      const icon = L.divIcon({
        className: 'town-label-marker',
        html: `
          <div class="town-label-inner">
            <span class="town-name">${town.name}</span>
          </div>
        `,
        iconSize: [120, 24],
        iconAnchor: [60, 12],
      });

      const marker = L.marker(latlng, { icon, zIndexOffset: 200 }).addTo(this.townsLayer);
      
      marker.bindPopup(`
        <div class="tactical-popup">
          <div class="popup-name">🏙 ${town.name}</div>
          <div class="popup-faction">${town.desc}</div>
          <div class="popup-coords">X: ${town.x} | Y: ${town.y}</div>
          <button class="gps-route-btn" onclick="window.pzSetGps(${town.x}, ${town.y}, '${town.name}')">
            🧭 TRAÇAR ROTA GPS
          </button>
        </div>
      `);
    });

    this.townsLayer.addTo(this.map);
  }

  /**
   * Renderiza prédios e pontos de loot categorizados com botão de rota
   */
  renderBuildings() {
    if (this.buildingsLayer) this.map.removeLayer(this.buildingsLayer);
    this.buildingsLayer = L.layerGroup();

    const categoryIcons = {
      police: '🚓',
      prison: '🔒',
      fire: '🚒',
      medical: '🏥',
      pharmacy: '💊',
      gun: '🔫',
      grocery: '🛒',
      hardware: '🛠',
      gas: '⛽',
      library: '📚',
      school: '🎓',
      church: '⛪',
      bank: '💰',
      restaurant: '🍔',
      bar: '🍺',
      motel: '🛏',
      warehouse: '🏭',
    };

    this.allBuildingsData.forEach((bld) => {
      if (!this.activeCategories.has(bld.cat)) return;

      const latlng = pzToLatLng(bld.x, bld.y, 0);
      const emoji = categoryIcons[bld.cat] || '📍';
      const label = this.categoriesMeta[bld.cat]?.label || bld.cat;

      const icon = L.divIcon({
        className: 'poi-building-marker',
        html: `<span class="poi-emoji">${emoji}</span>`,
        iconSize: [22, 22],
        iconAnchor: [11, 11],
      });

      const marker = L.marker(latlng, { icon, zIndexOffset: 100 });
      marker.bindPopup(`
        <div class="tactical-popup">
          <div class="popup-name">${emoji} ${label}</div>
          <div class="popup-faction">Localização Estratégica de Loot</div>
          <div class="popup-coords">X: ${Math.round(bld.x)} | Y: ${Math.round(bld.y)}</div>
          <button class="gps-route-btn" onclick="window.pzSetGps(${bld.x}, ${bld.y}, '${label}')">
            🧭 TRAÇAR ROTA GPS
          </button>
        </div>
      `);

      this.buildingsLayer.addLayer(marker);
    });

    if (this.map.getZoom() >= 14) {
      this.buildingsLayer.addTo(this.map);
    }
  }

  // =========================================================================
  // SISTEMA DE NAVEGAÇÃO GPS (ESTILO GTA V / WAZE)
  // =========================================================================

  /**
   * Define um destino e traça a rota neon animada
   */
  setGpsDestination(targetX, targetY, destinationName = 'Destino GPS') {
    this.gpsDestination = { x: targetX, y: targetY, name: destinationName };

    // Remove marcadores antigos de waypoint
    if (this.gpsWaypointMarker) this.map.removeLayer(this.gpsWaypointMarker);

    const targetLatLng = pzToLatLng(targetX, targetY, this.currentFloor);

    // Cria o marcador animado de Waypoint (Estilo GTA V / Waze)
    const icon = L.divIcon({
      className: 'gps-waypoint-marker',
      html: `
        <div class="gps-waypoint-ring"></div>
        <div class="gps-waypoint-core">📍</div>
      `,
      iconSize: [36, 36],
      iconAnchor: [18, 18],
    });

    this.gpsWaypointMarker = L.marker(targetLatLng, { icon, zIndexOffset: 3000 }).addTo(this.map);
    this.gpsWaypointMarker.bindPopup(`
      <div class="tactical-popup">
        <div class="popup-name">🎯 ${destinationName}</div>
        <div class="popup-coords">X: ${Math.round(targetX)} | Y: ${Math.round(targetY)}</div>
        <button class="gps-cancel-btn" onclick="window.pzClearGps()">❌ CANCELAR ROTA</button>
      </div>
    `);

    // Atualiza a linha se já soubermos a posição do jogador
    if (this.lastPlayerPos) {
      this.updateGpsRoute(this.lastPlayerPos.x, this.lastPlayerPos.y);
    }
  }

  /**
   * Atualiza a linha do GPS conforme o player se move
   */
  updateGpsRoute(playerX, playerY) {
    this.lastPlayerPos = { x: playerX, y: playerY };
    if (!this.gpsDestination) return;

    // Calcula rota real pelas ruas e rodovias de Knox County (A* Pathfinding)
    const routeResult = this.gpsRouter.findRoute(
      playerX,
      playerY,
      this.gpsDestination.x,
      this.gpsDestination.y
    );

    // Converte os pontos PZ (X, Y) para LatLng isométrico do Leaflet
    const pathPoints = routeResult.path.map((pt) =>
      pzToLatLng(pt.x, pt.y, this.currentFloor)
    );

    // Remove camadas anteriores
    if (this.gpsRouteGlow) this.map.removeLayer(this.gpsRouteGlow);
    if (this.gpsRouteLine) this.map.removeLayer(this.gpsRouteLine);

    // 1. Linha de Brilho Neon (Glow)
    this.gpsRouteGlow = L.polyline(pathPoints, {
      color: '#00d2d3',
      weight: 8,
      opacity: 0.4,
      lineCap: 'round',
      lineJoin: 'round',
    }).addTo(this.map);

    // 2. Linha Principal Pontilhada Animada (GPS GTA V)
    this.gpsRouteLine = L.polyline(pathPoints, {
      color: '#ffdd59',
      weight: 3.5,
      opacity: 0.95,
      dashArray: '8, 8',
      className: 'gps-animated-line',
      lineCap: 'round',
      lineJoin: 'round',
    }).addTo(this.map);

    const distanceMeters = Math.round(routeResult.distance);

    // Calcula rumo inicial da rota (para o próximo nó do trajeto)
    let nextX = this.gpsDestination.x;
    let nextY = this.gpsDestination.y;
    if (routeResult.path.length > 1) {
      nextX = routeResult.path[1].x;
      nextY = routeResult.path[1].y;
    }
    const dx = nextX - playerX;
    const dy = nextY - playerY;

    // Ângulo / Rumo Cardeal (N, NE, E, SE, S, SW, W, NW)
    let angleDeg = Math.round((Math.atan2(dy, dx) * 180) / Math.PI + 90);
    if (angleDeg < 0) angleDeg += 360;

    const directions = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    const headingIndex = Math.round(angleDeg / 45) % 8;
    const heading = directions[headingIndex];

    // Estimativas de tempo (a pé: ~4m/s, correndo: ~8m/s, carro: ~25m/s)
    const runSeconds = Math.round(distanceMeters / 7.5);
    const carSeconds = Math.round(distanceMeters / 22.0);

    const etaText = distanceMeters > 500
      ? `🚗 ${Math.ceil(carSeconds / 60)} min | 🏃 ${Math.ceil(runSeconds / 60)} min`
      : `🏃 ${runSeconds}s a pé`;

    if (this.onGpsUpdate) {
      this.onGpsUpdate({
        active: true,
        destinationName: this.gpsDestination.name,
        distanceMeters,
        heading,
        angleDeg,
        etaText,
        isArrived: distanceMeters < 25,
      });
    }
  }

  /**
   * Cancela o destino GPS ativo
   */
  clearGpsRoute() {
    this.gpsDestination = null;
    if (this.gpsWaypointMarker) {
      this.map.removeLayer(this.gpsWaypointMarker);
      this.gpsWaypointMarker = null;
    }
    if (this.gpsRouteGlow) {
      this.map.removeLayer(this.gpsRouteGlow);
      this.gpsRouteGlow = null;
    }
    if (this.gpsRouteLine) {
      this.map.removeLayer(this.gpsRouteLine);
      this.gpsRouteLine = null;
    }
    if (this.onGpsUpdate) {
      this.onGpsUpdate({ active: false });
    }
  }

  toggleCategory(categoryName, isEnabled) {
    if (isEnabled) {
      this.activeCategories.add(categoryName);
    } else {
      this.activeCategories.delete(categoryName);
    }
    this.renderBuildings();
  }

  setFloor(floorLevel) {
    this.currentFloor = floorLevel;
    this.createDziTileLayer();
  }

  panToPz(x, y, zoom = null) {
    const targetLatLng = pzToLatLng(x, y, this.currentFloor);
    if (zoom !== null) {
      this.map.flyTo(targetLatLng, zoom, { duration: 0.8 });
    } else {
      this.map.panTo(targetLatLng, { animate: true, duration: 0.6 });
    }
  }
}
