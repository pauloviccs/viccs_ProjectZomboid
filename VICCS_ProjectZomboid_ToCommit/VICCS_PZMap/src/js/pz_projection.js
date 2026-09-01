/**
 * VICCS_PZMap - Projeção Isométrica DZI Oficial do Project Zomboid (B41 / B42)
 * Mapeamento Exato 1:1 entre coordenadas do jogo (X, Y, Z) e tiles DZI do pzmap.org
 */

export const PZ_MAP_CONFIG = {
  worldW: 19968,
  worldH: 16128,
  cellSize: 300,
  x0: 1036288,
  y0: -139296,
  sqr: 128,
  scale: 4,
  refLevel: 20,
  tileSize: 1024,
  minZoom: 11,  // Limite ideal de Zoom Out (Visão panorâmica de todo o estado sem distorcer tiles)
  maxZoom: 20,  // Zoom In Máximo (Visão detalhada de casas, cercas e cômodos)
  defaultZoom: 15,
  defaultCenter: [10754, 9926], // Muldraugh
};

const D = Math.pow(2, PZ_MAP_CONFIG.refLevel);

/**
 * Converte coordenadas (X, Y, Floor) do Project Zomboid para LatLng no Leaflet
 */
export function pzToLatLng(x, y, floor = 0) {
  const rawPx = PZ_MAP_CONFIG.x0 + (x - y) * PZ_MAP_CONFIG.sqr / 2;
  const rawPy = PZ_MAP_CONFIG.y0 + (x + y) * PZ_MAP_CONFIG.sqr / 4 - 1.5 * floor * PZ_MAP_CONFIG.sqr;
  const px = rawPx / PZ_MAP_CONFIG.scale;
  const py = rawPy / PZ_MAP_CONFIG.scale;
  return L.latLng(-py / D, px / D);
}

/**
 * Converte LatLng do Leaflet para coordenadas (X, Y) do Project Zomboid
 */
export function latLngToPz(latlng, floor = 0) {
  const px = latlng.lng * D;
  const py = -latlng.lat * D;
  const dx = px * PZ_MAP_CONFIG.scale - PZ_MAP_CONFIG.x0;
  const dy = py * PZ_MAP_CONFIG.scale - PZ_MAP_CONFIG.y0 + 1.5 * floor * PZ_MAP_CONFIG.sqr;
  const fgx = dx / PZ_MAP_CONFIG.sqr;
  const fgy = (2 * dy) / PZ_MAP_CONFIG.sqr;
  const x = fgx + fgy;
  const y = fgy - fgx;
  return {
    x: Math.round(x),
    y: Math.round(y),
  };
}

/**
 * Retorna Cell e Chunk do PZ
 */
export function getPzCellInfo(x, y) {
  const cellX = Math.floor(x / PZ_MAP_CONFIG.cellSize);
  const cellY = Math.floor(y / PZ_MAP_CONFIG.cellSize);
  const chunkX = Math.floor((x % PZ_MAP_CONFIG.cellSize) / 10);
  const chunkY = Math.floor((y % PZ_MAP_CONFIG.cellSize) / 10);

  return {
    cell: `${cellX}x${cellY}`,
    chunk: `${chunkX}x${chunkY}`,
    cellX,
    cellY,
  };
}

/**
 * Cidades e Regiões de Knox County
 */
export const KNOX_TOWNS = [
  { name: "Muldraugh", x: 10754, y: 9926, desc: "Highway industrial, armazéns e Spiffo's." },
  { name: "West Point", x: 11654, y: 6864, desc: "Alta densidade de loot, delegacia e lojas de armas." },
  { name: "Rosewood", x: 8159, y: 11661, desc: "Penitenciária estadual, bombeiros e delegacia." },
  { name: "Riverside", x: 6450, y: 5430, desc: "Cidade no Rio Ohio, escola, farmácia e lojas." },
  { name: "Louisville (Metrópole)", x: 13077, y: 2238, desc: "Zona militar de quarentena, grandes hospitais e shoppings." },
  { name: "March Ridge", x: 10130, y: 12801, desc: "Dormitórios militares de alta densidade." },
  { name: "Fallas Lake", x: 7253, y: 8279, desc: "Vila rural perto do lago." },
  { name: "Valley Station", x: 13447, y: 5278, desc: "Shopping Mall e pistas de corrida." },
  { name: "Brandenburg", x: 2056, y: 6070, desc: "Cidade histórica à margem do rio." },
  { name: "Ekron", x: 634, y: 9746, desc: "Vila rural oeste." },
  { name: "Echo Creek", x: 4200, y: 10400, desc: "Vila ribeirinha." },
  { name: "Coalfield", x: 4800, y: 6800, desc: "Zona de mineração e campos." }
];
