/**
 * VICCS_PZMap - Rastreador de Esquadrão e Amigos em Tempo Real
 * Gerencia marcadores táticos no Leaflet, destaque de amigos com ⭐ e cards na UI lateral
 */

import { pzToLatLng } from './pz_projection.js';

export class SquadTracker {
  constructor(mapEngine, sidebarContainerId) {
    this.mapEngine = mapEngine;
    this.container = document.getElementById(sidebarContainerId);
    this.players = [];
    this.selfPlayer = null;
    this.markers = new Map(); // id -> L.Marker
    this.followSelf = false;
    this.friendsList = [];
  }

  setFriendsList(friends) {
    this.friendsList = friends || [];
    this.updateMapMarkers();
    this.renderSidebarCards();
  }

  getFriendMeta(username) {
    if (!username) return null;
    return this.friendsList.find((f) => f.username.toLowerCase() === username.toLowerCase()) || null;
  }

  /**
   * Atualiza todo o estado do esquadrão a partir de dados de telemetria
   */
  updateSquad(squadState) {
    if (!squadState || !squadState.players) {
      this.players = [];
      this.selfPlayer = null;
      this.updateMapMarkers();
      this.renderSidebarCards();
      return;
    }

    this.players = squadState.players;
    this.selfPlayer = this.players.find((p) => p.is_self) || null;

    // Atualiza ou cria marcadores no mapa
    this.updateMapMarkers();

    // Atualiza a lista na UI lateral
    this.renderSidebarCards();

    // Atualiza o cálculo da rota de navegação GPS ativa
    if (this.selfPlayer) {
      this.mapEngine.updateGpsRoute(this.selfPlayer.x, this.selfPlayer.y);
    }

    // Se o modo Seguir Jogador estiver ativado, recentraliza a câmera
    if (this.followSelf && this.selfPlayer && this.selfPlayer.is_alive) {
      this.mapEngine.panToPz(this.selfPlayer.x, this.selfPlayer.y);
    }
  }

  /**
   * Atualiza a renderização de marcadores no mapa Leaflet
   */
  updateMapMarkers() {
    const currentIds = new Set();

    this.players.forEach((player) => {
      currentIds.add(player.id);
      const latlng = pzToLatLng(player.x, player.y, player.z);
      const friendMeta = this.getFriendMeta(player.name);

      if (this.markers.has(player.id)) {
        // Atualiza posição do marcador existente
        const marker = this.markers.get(player.id);
        marker.setLatLng(latlng);
        this.updateMarkerPopup(marker, player, friendMeta);
      } else {
        // Cria novo marcador tático
        const marker = this.createPlayerMarker(player, latlng, friendMeta);
        marker.addTo(this.mapEngine.map);
        this.markers.set(player.id, marker);
      }
    });

    // Remove marcadores de jogadores que desconectaram
    for (const [id, marker] of this.markers.entries()) {
      if (!currentIds.has(id)) {
        this.mapEngine.map.removeLayer(marker);
        this.markers.delete(id);
      }
    }
  }

  /**
   * Cria o elemento visual do marcador no mapa
   */
  createPlayerMarker(player, latlng, friendMeta) {
    let iconHtml = '';
    let iconClass = '';
    let zIndex = 500;

    if (player.is_self) {
      // 1. Marcador do Jogador Local (Você)
      iconClass = 'player-marker-self';
      zIndex = 1000;
      iconHtml = `
        <div class="player-radar-ping"></div>
        <div class="player-radar-ping-inner"></div>
        <div class="self-icon-circle"></div>
        <div class="self-label-badge">
          <span>🟢 VOCÊ (${player.name})</span>
        </div>
      `;
    } else if (friendMeta) {
      // 2. Marcador de Amigo Cadastrado (Destaque Especial ⭐)
      iconClass = 'player-marker-friend';
      zIndex = 900;
      const customColor = friendMeta.color || '#ffdd59';
      const displayName = friendMeta.nickname || player.name;
      iconHtml = `
        <div class="friend-radar-ping" style="border-color: ${customColor};"></div>
        <div class="friend-icon-circle" style="background-color: ${customColor}; box-shadow: 0 0 12px ${customColor};">
          <span style="font-size: 9px; color: #000;">⭐</span>
        </div>
        <div class="friend-label-badge" style="border-color: ${customColor};">
          <span>${displayName}</span>
        </div>
      `;
    } else if (!player.is_alive) {
      // 3. Jogador Morto
      iconClass = 'player-marker-dead';
      zIndex = 200;
      iconHtml = `
        <svg class="dead-skull-icon" viewBox="0 0 24 24">
          <path d="M12 2C7.58 2 4 5.58 4 10c0 2.78 1.42 5.23 3.58 6.69V19c0 .55.45 1 1 1h6c.55 0 1-.45 1-1v-2.31c2.16-1.46 3.58-3.91 3.58-6.69 0-4.42-3.58-8-8-8zm-2 11c-.83 0-1.5-.67-1.5-1.5S9.17 10 10 10s1.5.67 1.5 1.5S10.83 13 10 13zm4 0c-.83 0-1.5-.67-1.5-1.5S13.17 10 14 10s1.5.67 1.5 1.5S14.83 13 14 13z"/>
        </svg>
      `;
    } else {
      // 4. Aliado / Membro de Facção Padrão
      iconClass = 'player-marker-ally';
      zIndex = 600;
      iconHtml = `
        <div class="ally-icon-circle"></div>
        <div class="ally-label-badge">
          <span>${player.name}</span>
        </div>
      `;
    }

    const icon = L.divIcon({
      className: iconClass,
      html: iconHtml,
      iconSize: [28, 28],
      iconAnchor: [14, 14],
    });

    const marker = L.marker(latlng, { icon, zIndexOffset: zIndex });
    this.updateMarkerPopup(marker, player, friendMeta);
    return marker;
  }

  /**
   * Atualiza o popup do marcador
   */
  updateMarkerPopup(marker, player, friendMeta) {
    const friendBadge = friendMeta ? `<div style="color: ${friendMeta.color || '#ffdd59'}; font-size: 10px; font-weight: 800;">⭐ AMIGO CADASTRADO</div>` : '';
    const isSelfText = player.is_self ? '<span style="color: var(--accent-green);"> (VOCÊ)</span>' : '';
    const statusText = player.is_alive ? `❤️ Saúde: ${Math.round(player.health)}%` : '<span style="color: var(--accent-red);">💀 MORTO / SINAL PERDIDO</span>';
    
    let gpsButton = '';
    if (!player.is_self && player.is_alive) {
      gpsButton = `
        <button class="gps-route-btn" onclick="window.pzSetGps(${player.x}, ${player.y}, '${player.name}')">
          🧭 TRAÇAR ROTA GPS ATÉ ELE
        </button>
      `;
    }

    marker.bindPopup(`
      <div class="tactical-popup">
        ${friendBadge}
        <div class="popup-name">${player.name}${isSelfText}</div>
        <div class="popup-faction">🏴 Facção: ${player.faction || 'Neutro / Sobrevivente'}</div>
        <div style="font-size: 11px; margin: 2px 0;">${statusText}</div>
        <div class="popup-coords">X: ${Math.round(player.x)} | Y: ${Math.round(player.y)} | Andar: ${player.z}</div>
        ${gpsButton}
      </div>
    `);
  }

  /**
   * Renderiza a lista de cartões na barra lateral
   */
  renderSidebarCards() {
    if (!this.container) return;

    if (this.players.length === 0) {
      this.container.innerHTML = `
        <div class="squad-empty-state">
          <div style="font-size: 24px; margin-bottom: 6px;">📡</div>
          <div style="font-weight: 700; color: var(--text-main); margin-bottom: 4px;">RADAR EM ESPERA</div>
          <div style="color: var(--text-dim); font-size: 11px; line-height: 1.5;">
            Nenhum jogador detectado no momento.<br>
            Abra o <strong>Project Zomboid</strong> com o mod ativo para sincronizar sua localização em tempo real.
          </div>
        </div>
      `;
      return;
    }

    let html = '';

    this.players.forEach((player) => {
      const friendMeta = this.getFriendMeta(player.name);
      const isFriend = !!friendMeta;
      const isAliveClass = player.is_alive ? '' : 'dead';
      const selfTag = player.is_self
        ? '<span class="squad-card-badge">VOCÊ</span>'
        : isFriend
        ? `<span class="squad-card-badge" style="background: rgba(255, 221, 89, 0.2); color: ${friendMeta.color || '#ffdd59'}; border-color: ${friendMeta.color || '#ffdd59'};">⭐ AMIGO</span>`
        : '';

      const healthColor = player.health > 70 ? 'var(--accent-green)' : player.health > 30 ? 'var(--accent-gold)' : 'var(--accent-red)';
      const displayName = friendMeta?.nickname ? `${friendMeta.nickname} (${player.name})` : player.name;

      let distanceText = '';
      if (!player.is_self && this.selfPlayer) {
        const dist = Math.round(Math.hypot(player.x - this.selfPlayer.x, player.y - this.selfPlayer.y));
        distanceText = `<span style="font-family: var(--font-mono); font-size: 10px; color: var(--accent-cyan);">${dist}m</span>`;
      }

      html += `
        <div class="squad-card ${isAliveClass}" data-player-id="${player.id}" data-x="${player.x}" data-y="${player.y}">
          <div class="squad-card-header">
            <div>
              <span class="squad-card-name">${displayName}</span>
              <span class="squad-card-faction">${player.faction || 'Sobrevivente'}</span>
            </div>
            <div style="display: flex; align-items: center; gap: 6px;">
              ${distanceText}
              ${selfTag}
            </div>
          </div>

          <div class="squad-health-bar">
            <div class="squad-health-fill" style="width: ${player.health}%; background-color: ${healthColor};"></div>
          </div>

          <div class="squad-card-meta">
            <span>X: ${Math.round(player.x)} Y: ${Math.round(player.y)}</span>
            <span>Andar: ${player.z}</span>
            <span>${player.is_alive ? '● ONLINE' : '✖ MORTO'}</span>
          </div>
        </div>
      `;
    });

    this.container.innerHTML = html;

    // Adiciona evento de clique para focar no player no mapa
    this.container.querySelectorAll('.squad-card').forEach((card) => {
      card.addEventListener('click', () => {
        const x = parseFloat(card.getAttribute('data-x'));
        const y = parseFloat(card.getAttribute('data-y'));
        this.mapEngine.panToPz(x, y, 17);
      });
    });
  }

  centerOnSelf() {
    if (this.selfPlayer && this.selfPlayer.is_alive) {
      this.mapEngine.panToPz(this.selfPlayer.x, this.selfPlayer.y, 16);
    }
  }

  toggleFollowSelf() {
    this.followSelf = !this.followSelf;
    if (this.followSelf) {
      this.centerOnSelf();
    }
    return this.followSelf;
  }
}
