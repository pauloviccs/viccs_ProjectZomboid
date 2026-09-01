/**
 * =============================================================================
 * VICCS PZMap - Real Road Network GPS Router (A* Pathfinding)
 * Converte streets.json em uma malha viária navegável estilo Waze / Google Maps
 * =============================================================================
 */

export class GpsRoadRouter {
  constructor() {
    this.nodes = [];
    this.nodeMap = new Map();
    this.adj = [];
    this.isReady = false;
  }

  /**
   * Carrega os dados de streets.json e inicializa o grafo rodoviário de Knox County
   */
  async init() {
    if (this.isReady) return;
    try {
      const resp = await fetch('./data/streets.json');
      if (!resp.ok) return;
      const data = await resp.json();
      if (data && data.streets) {
        this.buildGraph(data.streets);
        this.isReady = true;
      }
    } catch (err) {
      console.warn('[GpsRouter] Erro ao carregar malha de estradas:', err);
    }
  }

  coordKey(x, y) {
    const qx = Math.round(x / 8) * 8;
    const qy = Math.round(y / 8) * 8;
    return `${qx},${qy}`;
  }

  getOrCreateNode(x, y) {
    const key = this.coordKey(x, y);
    if (this.nodeMap.has(key)) {
      return this.nodeMap.get(key);
    }
    const id = this.nodes.length;
    const qx = Math.round(x / 8) * 8;
    const qy = Math.round(y / 8) * 8;
    this.nodes.push({ x: qx, y: qy });
    this.adj.push([]);
    this.nodeMap.set(key, id);
    return id;
  }

  addEdge(u, v) {
    if (u === v) return;
    const n1 = this.nodes[u];
    const n2 = this.nodes[v];
    const dist = Math.hypot(n1.x - n2.x, n1.y - n2.y);
    if (dist < 0.1) return;

    if (!this.adj[u].some((e) => e.to === v)) {
      this.adj[u].push({ to: v, cost: dist });
    }
    if (!this.adj[v].some((e) => e.to === u)) {
      this.adj[v].push({ to: u, cost: dist });
    }
  }

  buildGraph(streets) {
    for (const street of streets) {
      const pts = street.pts;
      if (!pts || pts.length < 2) continue;

      for (let i = 0; i < pts.length - 1; i++) {
        const [x1, y1] = pts[i];
        const [x2, y2] = pts[i + 1];
        const dist = Math.hypot(x2 - x1, y2 - y1);

        // Subdivide segmentos longos a cada ~40 unidades para permitir ingressar na rodovia em qualquer ponto
        const steps = Math.max(1, Math.floor(dist / 40));
        let prevNode = this.getOrCreateNode(x1, y1);

        for (let s = 1; s <= steps; s++) {
          const t = s / steps;
          const sx = x1 + (x2 - x1) * t;
          const sy = y1 + (y2 - y1) * t;
          const currNode = this.getOrCreateNode(sx, sy);
          this.addEdge(prevNode, currNode);
          prevNode = currNode;
        }
      }
    }

    // Interseção e união espacial de cruzamentos: Conecta nós adjacentes a menos de 28 unidades
    const spatialGrid = new Map();
    const cellSize = 100;
    for (let i = 0; i < this.nodes.length; i++) {
      const n = this.nodes[i];
      const cx = Math.floor(n.x / cellSize);
      const cy = Math.floor(n.y / cellSize);
      const cellKey = `${cx},${cy}`;
      if (!spatialGrid.has(cellKey)) spatialGrid.set(cellKey, []);
      spatialGrid.get(cellKey).push(i);
    }

    for (let i = 0; i < this.nodes.length; i++) {
      const n1 = this.nodes[i];
      const cx = Math.floor(n1.x / cellSize);
      const cy = Math.floor(n1.y / cellSize);

      for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
          const neighborCell = spatialGrid.get(`${cx + dx},${cy + dy}`);
          if (!neighborCell) continue;
          for (const j of neighborCell) {
            if (i < j) {
              const n2 = this.nodes[j];
              const d = Math.hypot(n1.x - n2.x, n1.y - n2.y);
              if (d <= 28) {
                this.addEdge(i, j);
              }
            }
          }
        }
      }
    }
  }

  findNearestNode(x, y, maxRadius = 2500) {
    let bestId = -1;
    let minDist = maxRadius;
    for (let i = 0; i < this.nodes.length; i++) {
      const n = this.nodes[i];
      const d = Math.hypot(n.x - x, n.y - y);
      if (d < minDist) {
        minDist = d;
        bestId = i;
      }
    }
    return { id: bestId, dist: minDist };
  }

  /**
   * Calcula a rota ótima navegando pelas ruas e rodovias com A*
   */
  findRoute(startX, startY, endX, endY) {
    if (!this.isReady || this.nodes.length === 0) {
      return {
        path: [{ x: startX, y: startY }, { x: endX, y: endY }],
        distance: Math.hypot(endX - startX, endY - startY),
      };
    }

    const startNearest = this.findNearestNode(startX, startY);
    const endNearest = this.findNearestNode(endX, endY);

    if (startNearest.id === -1 || endNearest.id === -1) {
      return {
        path: [{ x: startX, y: startY }, { x: endX, y: endY }],
        distance: Math.hypot(endX - startX, endY - startY),
      };
    }

    const startNode = startNearest.id;
    const targetNode = endNearest.id;

    if (startNode === targetNode) {
      const mid = this.nodes[startNode];
      const d = Math.hypot(mid.x - startX, mid.y - startY) + Math.hypot(endX - mid.x, endY - mid.y);
      return {
        path: [{ x: startX, y: startY }, mid, { x: endX, y: endY }],
        distance: d,
      };
    }

    // A* Pathfinding
    const target = this.nodes[targetNode];
    const openSet = new Set([startNode]);
    const cameFrom = new Map();
    const gScore = new Float64Array(this.nodes.length).fill(Infinity);
    const fScore = new Float64Array(this.nodes.length).fill(Infinity);

    gScore[startNode] = 0;
    fScore[startNode] = Math.hypot(this.nodes[startNode].x - target.x, this.nodes[startNode].y - target.y);

    let found = false;

    while (openSet.size > 0) {
      let current = -1;
      let lowestF = Infinity;
      for (const id of openSet) {
        if (fScore[id] < lowestF) {
          lowestF = fScore[id];
          current = id;
        }
      }

      if (current === targetNode) {
        found = true;
        break;
      }

      openSet.delete(current);

      for (const edge of this.adj[current]) {
        const neighbor = edge.to;
        const tentativeG = gScore[current] + edge.cost;

        if (tentativeG < gScore[neighbor]) {
          cameFrom.set(neighbor, current);
          gScore[neighbor] = tentativeG;
          const h = Math.hypot(this.nodes[neighbor].x - target.x, this.nodes[neighbor].y - target.y);
          fScore[neighbor] = tentativeG + h;
          openSet.add(neighbor);
        }
      }
    }

    if (found) {
      const rawPath = [];
      let curr = targetNode;
      while (curr !== undefined) {
        rawPath.push(this.nodes[curr]);
        curr = cameFrom.get(curr);
      }
      rawPath.reverse();

      const finalPath = [{ x: startX, y: startY }, ...rawPath, { x: endX, y: endY }];

      // Calcula a distância total percorrida ao longo de todas as curvas das ruas
      let totalDist = 0;
      for (let i = 0; i < finalPath.length - 1; i++) {
        totalDist += Math.hypot(finalPath[i + 1].x - finalPath[i].x, finalPath[i + 1].y - finalPath[i].y);
      }

      return {
        path: finalPath,
        distance: totalDist,
      };
    }

    // Se não houver conexão na malha de ruas, traça linha direta
    return {
      path: [{ x: startX, y: startY }, { x: endX, y: endY }],
      distance: Math.hypot(endX - startX, endY - startY),
    };
  }
}
