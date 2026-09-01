/**
 * PZHub - Tactical Live Radar & Modpack Manager
 * Controlador Principal da Aplicação com Router de Views (Escape from Tarkov UI)
 */

import { PZMapEngine } from './map_engine.js';
import { SquadTracker } from './squad_tracker.js';
import { OverlayController } from './overlay.js';
import { FriendsManager } from './friends_manager.js';
import { KNOX_TOWNS } from './pz_projection.js';
import { initLocalModsScanner, refreshLocalMods, getLocalModsList } from './local_mods_scanner.js';
import { initModpackManager } from './modpack_manager.js';

class App {
  constructor() {
    this.mapEngine = null;
    this.squadTracker = null;
    this.friendsManager = null;
    this.overlayController = null;
    this.step = 0;
    this.telemetryTimer = null;
    this.isTauri = typeof window.__TAURI__ !== 'undefined';
    this.isMiniRadar = false;
    this.activeView = 'view-hub';
  }

  async init() {
    // 1. Configura o Router de Views e Navegação Global
    this.setupViewRouter();

    // 2. Inicializa o Scanner de Mods Locais e o Gerenciador de Modpacks
    await initLocalModsScanner();
    await initModpackManager();
    this.updateHubMetrics();

    // 3. Inicializa o motor de mapa Leaflet (em segundo plano)
    this.mapEngine = new PZMapEngine('map', (telemetry) => {
      this.updateTelemetryHeader(telemetry);
    });

    // Registra listener de rota GPS
    this.mapEngine.onGpsUpdate = (gpsData) => {
      this.updateGpsHud(gpsData);
    };

    // Expõe atalhos globais de GPS para popups do Leaflet
    window.pzSetGps = (x, y, name) => {
      this.mapEngine.setGpsDestination(x, y, name);
    };
    window.pzClearGps = () => {
      this.mapEngine.clearGpsRoute();
    };

    await this.mapEngine.init();

    // 4. Inicializa o rastreador de esquadrão
    this.squadTracker = new SquadTracker(this.mapEngine, 'squad-list-container');

    // 5. Inicializa o gerenciador de amigos
    this.friendsManager = new FriendsManager(this.mapEngine, this.squadTracker, 'friends-list-container');
    await this.friendsManager.init();

    // Sincroniza amigos com o tracker
    this.squadTracker.setFriendsList(this.friendsManager.friends);

    // 6. Inicializa o controlador de overlay e atalhos
    this.overlayController = new OverlayController(this.mapEngine, this.squadTracker).init();

    // 7. Configura as abas da barra lateral do mapa
    this.setupSidebarTabs();

    // 8. Configura lista de Cidades e POIs com rotas GPS
    this.setupTownsList();

    // 9. Configura filtros de loot / categorias
    this.setupCategoryFilters();

    // 10. Configura seletor de Z-Levels (Andares)
    this.setupFloorSelector();

    // 11. Configura painel de cache e controles do mapa
    this.setupCacheAndModControls();

    // 12. Configura controle do Modo Mini-Radar
    this.setupMiniRadarControls();

    // 13. Configura GPS HUD (Barra de navegação no topo)
    this.setupGpsHudControls();

    // 14. Configura modais
    this.setupModal();

    // 15. Inicia o loop de telemetria do esquadrão
    this.startTelemetryLoop();

    // 16. Atualiza status do cache
    this.refreshCacheStats();
  }

  setupViewRouter() {
    const tabs = document.querySelectorAll('.tarkov-tab');
    const portals = document.querySelectorAll('.tarkov-portal-card');
    const brandBtn = document.getElementById('nav-brand-btn');
    const backToHubBtn = document.getElementById('btn-back-to-hub');
    const globalAotBtn = document.getElementById('btn-global-always-on-top');

    // Navegação pelas abas superiores
    tabs.forEach(tab => {
      tab.addEventListener('click', () => {
        const targetView = tab.dataset.view;
        if (targetView) this.switchView(targetView);
      });
    });

    // Navegação pelos portais da Home / Hub
    portals.forEach(portal => {
      portal.addEventListener('click', () => {
        const targetView = portal.dataset.targetView;
        if (targetView) this.switchView(targetView);
      });
    });

    if (brandBtn) {
      brandBtn.addEventListener('click', () => this.switchView('view-hub'));
    }

    if (backToHubBtn) {
      backToHubBtn.addEventListener('click', () => this.switchView('view-hub'));
    }

    if (globalAotBtn) {
      globalAotBtn.addEventListener('click', async () => {
        if (this.isTauri) {
          try {
            const config = await window.__TAURI__.core.invoke('get_user_config');
            const newState = !config.always_on_top;
            config.always_on_top = newState;
            await window.__TAURI__.core.invoke('set_user_config', { config });
            await window.__TAURI__.core.invoke('set_always_on_top', { enabled: newState });
            globalAotBtn.classList.toggle('active', newState);
          } catch (e) {
            console.error('Erro ao alternar Always-On-Top:', e);
          }
        }
      });
    }
  }

  switchView(viewId) {
    this.activeView = viewId;

    // Atualiza abas da navbar
    document.querySelectorAll('.tarkov-tab').forEach(tab => {
      tab.classList.toggle('active', tab.dataset.view === viewId);
    });

    // Atualiza views
    document.querySelectorAll('.app-view').forEach(view => {
      view.classList.toggle('active', view.id === viewId);
    });

    // Se estiver no mapa, acorda o Leaflet e redimensiona
    if (viewId === 'view-map') {
      setTimeout(() => {
        if (this.mapEngine?.map) {
          this.mapEngine.map.invalidateSize();
        }
      }, 100);
    }

    this.updateHubMetrics();
  }

  updateHubMetrics() {
    const modsCountEl = document.getElementById('hub-mods-count');
    const localMods = getLocalModsList();
    if (modsCountEl) {
      modsCountEl.textContent = `${localMods.length} INSTALADOS`;
    }
  }

  updateTelemetryHeader({ x, y, z, cell, chunk, zoom }) {
    const elX = document.getElementById('telemetry-x');
    const elY = document.getElementById('telemetry-y');
    const elFloor = document.getElementById('telemetry-floor');
    const elCell = document.getElementById('telemetry-cell');
    const elZoom = document.getElementById('telemetry-zoom');

    if (elX) elX.textContent = `${Math.round(x)}`;
    if (elY) elY.textContent = `${Math.round(y)}`;
    if (elFloor) elFloor.textContent = `${z}`;
    if (elCell) elCell.textContent = `${cell} [${chunk}]`;
    if (elZoom) elZoom.textContent = `${zoom}x`;
  }

  updateGpsHud(gpsData) {
    const hud = document.getElementById('gps-navigation-hud');
    const destName = document.getElementById('gps-hud-dest-name');
    const heading = document.getElementById('gps-hud-heading');
    const distance = document.getElementById('gps-hud-distance');
    const eta = document.getElementById('gps-hud-eta');

    if (!hud || !destName || !heading || !distance || !eta) return;

    if (!gpsData) {
      hud.classList.remove('active');
      return;
    }

    hud.classList.add('active');
    destName.textContent = gpsData.destinationName || 'Destino GPS';
    heading.textContent = `Rumo: ${gpsData.headingText} (${Math.round(gpsData.bearing)}°)`;
    distance.textContent = gpsData.formattedDistance;
    eta.textContent = `🚶 ${gpsData.etaWalk} | 🚗 ${gpsData.etaDrive}`;
  }

  setupGpsHudControls() {
    const cancelBtn = document.getElementById('gps-hud-cancel');
    if (cancelBtn) {
      cancelBtn.addEventListener('click', () => {
        if (this.mapEngine) {
          this.mapEngine.clearGpsRoute();
        }
      });
    }
  }

  setupSidebarTabs() {
    const navTabs = document.querySelectorAll('.nav-tab');
    const tabPanes = document.querySelectorAll('.tab-pane');

    navTabs.forEach((tab) => {
      tab.addEventListener('click', () => {
        const targetId = tab.dataset.tab;
        navTabs.forEach((t) => t.classList.remove('active'));
        tabPanes.forEach((p) => p.classList.remove('active'));

        tab.classList.add('active');
        const targetPane = document.getElementById(targetId);
        if (targetPane) targetPane.classList.add('active');
      });
    });

    const toggleBtn = document.getElementById('sidebar-toggle');
    const sidebar = document.querySelector('.tactical-sidebar');
    if (toggleBtn && sidebar) {
      toggleBtn.addEventListener('click', () => {
        sidebar.classList.toggle('collapsed');
      });
    }
  }

  setupTownsList() {
    const container = document.getElementById('poi-list-container');
    if (!container) return;

    container.innerHTML = '';

    KNOX_TOWNS.forEach((town) => {
      const card = document.createElement('div');
      card.className = 'tactical-btn';
      card.style.display = 'flex';
      card.style.justifyContent = 'space-between';
      card.style.alignItems = 'center';
      card.style.padding = '8px 10px';
      card.style.cursor = 'pointer';

      card.innerHTML = `
        <div style="display: flex; flex-direction: column; text-align: left;">
          <span style="font-weight: bold; color: var(--text-main);">${town.name}</span>
          <span style="font-size: 10px; color: var(--text-dim); font-family: var(--font-mono);">
            X:${Math.round(town.center.x)} Y:${Math.round(town.center.y)}
          </span>
        </div>
        <div style="display: flex; gap: 4px;">
          <button class="btn-town-gps" title="Traçar Rota GPS até ${town.name}" style="background: rgba(0, 210, 211, 0.15); border: 1px solid var(--accent-cyan); color: var(--accent-cyan); padding: 4px 8px; border-radius: 3px; font-family: var(--font-mono); font-size: 10px; cursor: pointer;">
            🧭 GPS
          </button>
          <button class="btn-town-view" title="Ver no Mapa" style="background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.15); color: var(--text-main); padding: 4px 8px; border-radius: 3px; font-family: var(--font-mono); font-size: 10px; cursor: pointer;">
            👁️ IR
          </button>
        </div>
      `;

      const gpsBtn = card.querySelector('.btn-town-gps');
      const viewBtn = card.querySelector('.btn-town-view');

      gpsBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.mapEngine.setGpsDestination(town.center.x, town.center.y, town.name);
      });

      viewBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.mapEngine.panToPZCoords(town.center.x, town.center.y, 14);
      });

      card.addEventListener('click', () => {
        this.mapEngine.panToPZCoords(town.center.x, town.center.y, 14);
      });

      container.appendChild(card);
    });
  }

  setupCategoryFilters() {
    const container = document.getElementById('category-filters-container');
    if (!container) return;

    const categories = [
      { id: 'police', label: 'Delegacias & Armarias', color: '#3498db' },
      { id: 'medical', label: 'Hospitais & Clínicas', color: '#e74c3c' },
      { id: 'food', label: 'Mercados & Restaurantes', color: '#f39c12' },
      { id: 'hardware', label: 'Ferramentas & Depósitos', color: '#95a5a6' },
      { id: 'gas', label: 'Postos de Combustível', color: '#e67e22' },
      { id: 'gunstore', label: 'Lojas de Armas', color: '#c0392b' },
    ];

    container.innerHTML = categories
      .map(
        (cat) => `
      <label class="category-toggle-item" style="display: flex; align-items: center; justify-content: space-between; padding: 6px 8px; margin-bottom: 4px; background: rgba(0,0,0,0.3); border-radius: 3px; border: 1px solid rgba(255,255,255,0.05); cursor: pointer;">
        <div style="display: flex; align-items: center; gap: 8px;">
          <span style="width: 8px; height: 8px; border-radius: 50%; background: ${cat.color};"></span>
          <span style="font-size: 11px;">${cat.label}</span>
        </div>
        <input type="checkbox" class="category-checkbox" data-cat="${cat.id}" checked style="accent-color: var(--accent-cyan); cursor: pointer;" />
      </label>
    `
      )
      .join('');

    container.querySelectorAll('.category-checkbox').forEach((chk) => {
      chk.addEventListener('change', (e) => {
        const catId = e.target.dataset.cat;
        const enabled = e.target.checked;
        if (this.overlayController) {
          this.overlayController.toggleCategory(catId, enabled);
        }
      });
    });
  }

  setupFloorSelector() {
    const buttons = document.querySelectorAll('.z-level-btn');
    buttons.forEach((btn) => {
      btn.addEventListener('click', () => {
        buttons.forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        const floor = parseInt(btn.dataset.floor, 10);
        this.mapEngine.setFloor(floor);
      });
    });
  }

  setupCacheAndModControls() {
    const installModBtn = document.getElementById('btn-install-mod');
    const openModsBtn = document.getElementById('btn-open-mods-folder');
    const refreshCacheBtn = document.getElementById('btn-refresh-cache');
    const clearCacheBtn = document.getElementById('btn-clear-cache');

    if (installModBtn) {
      installModBtn.addEventListener('click', async () => {
        if (this.isTauri) {
          try {
            const targetPath = await window.__TAURI__.core.invoke('install_zomboid_mod');
            this.showModal(
              'Mod Instalado com Sucesso!',
              `O mod <strong>VICCSRadarBridge</strong> foi gravado nas pastas padrão e Build 42:<br><br><code>${targetPath}</code><br><br>Agora abra o Project Zomboid, vá em <strong>Mods</strong> e ative-o para iniciar o radar.`
            );
          } catch (e) {
            this.showModal('Erro na Instalação', `Falha ao gravar os arquivos do mod: ${e}`);
          }
        }
      });
    }

    if (openModsBtn) {
      openModsBtn.addEventListener('click', async () => {
        if (this.isTauri) {
          try {
            await window.__TAURI__.core.invoke('open_zomboid_mods_dir');
          } catch (e) {
            console.error('Erro ao abrir pasta mods:', e);
          }
        }
      });
    }

    if (refreshCacheBtn) {
      refreshCacheBtn.addEventListener('click', () => this.refreshCacheStats());
    }

    if (clearCacheBtn) {
      clearCacheBtn.addEventListener('click', async () => {
        if (this.isTauri && confirm('Deseja realmente limpar todo o cache local de tiles do disco?')) {
          try {
            await window.__TAURI__.core.invoke('clear_tile_cache');
            this.refreshCacheStats();
          } catch (e) {
            console.error('Erro ao limpar cache:', e);
          }
        }
      });
    }

    // Configuração de opacidade da janela
    const opacitySlider = document.getElementById('opacity-slider');
    const opacityVal = document.getElementById('opacity-val');
    if (opacitySlider && opacityVal) {
      opacitySlider.addEventListener('input', (e) => {
        const val = parseFloat(e.target.value);
        opacityVal.textContent = `${Math.round(val * 100)}%`;
        document.body.style.opacity = `${val}`;
      });
    }
  }

  async refreshCacheStats() {
    if (!this.isTauri) return;

    try {
      const stats = await window.__TAURI__.core.invoke('get_cache_stats');
      const countEl = document.getElementById('cache-tiles-count');
      const sizeEl = document.getElementById('cache-size-mb');
      const pathEl = document.getElementById('cache-path-display');

      if (countEl) countEl.textContent = `${stats.total_tiles.toLocaleString('pt-BR')} arquivos`;
      if (sizeEl) sizeEl.textContent = `${stats.size_mb.toFixed(2)} MB`;
      if (pathEl) pathEl.textContent = stats.cache_dir;
    } catch (e) {
      console.warn('Erro ao consultar estatísticas do cache:', e);
    }
  }

  setupMiniRadarControls() {
    const btnMiniRadar = document.getElementById('btn-mini-radar');
    const btnExitMiniRadar = document.getElementById('btn-exit-mini-radar');
    const btnGtaMin = document.getElementById('btn-gta-minimize');
    const btnGtaClose = document.getElementById('btn-gta-close');

    const toggleMiniRadar = async () => {
      this.isMiniRadar = !this.isMiniRadar;
      document.body.classList.toggle('mini-radar-active', this.isMiniRadar);

      if (this.isTauri) {
        try {
          await window.__TAURI__.core.invoke('set_mini_radar_mode', { enabled: this.isMiniRadar });
        } catch (e) {
          console.error('Erro ao alternar modo mini-radar:', e);
        }
      }

      if (this.isMiniRadar) {
        this.mapEngine.setFollowSelf(true);
        setTimeout(() => {
          this.mapEngine.map.invalidateSize();
          this.mapEngine.centerOnSelf();
        }, 150);
      } else {
        setTimeout(() => {
          this.mapEngine.map.invalidateSize();
        }, 150);
      }
    };

    if (btnMiniRadar) btnMiniRadar.addEventListener('click', toggleMiniRadar);
    if (btnExitMiniRadar) btnExitMiniRadar.addEventListener('click', toggleMiniRadar);

    // Atalho global de teclado: F9
    window.addEventListener('keydown', (e) => {
      if (e.key === 'F9') {
        e.preventDefault();
        toggleMiniRadar();
      }
    });

    if (btnGtaMin && this.isTauri) {
      btnGtaMin.addEventListener('click', async () => {
        try {
          await window.__TAURI__.core.invoke('minimize_window');
        } catch (e) {
          console.error('Erro ao minimizar:', e);
        }
      });
    }

    if (btnGtaClose && this.isTauri) {
      btnGtaClose.addEventListener('click', async () => {
        try {
          await window.__TAURI__.core.invoke('close_window');
        } catch (e) {
          console.error('Erro ao fechar:', e);
        }
      });
    }
  }

  setupModal() {
    const modal = document.getElementById('tactical-modal');
    const closeBtn = document.getElementById('modal-close-btn');

    if (closeBtn && modal) {
      closeBtn.addEventListener('click', () => {
        modal.classList.remove('visible');
      });
    }
  }

  showModal(title, htmlBody) {
    const modal = document.getElementById('tactical-modal');
    const titleEl = document.getElementById('modal-title');
    const bodyEl = document.getElementById('modal-body');

    if (modal && titleEl && bodyEl) {
      titleEl.innerHTML = title;
      bodyEl.innerHTML = htmlBody;
      modal.classList.add('visible');
    }
  }

  startTelemetryLoop() {
    const pollTelemetry = async () => {
      this.step++;
      if (this.isTauri) {
        try {
          const squadState = await window.__TAURI__.core.invoke('get_squad_telemetry', { step: this.step });
          this.squadTracker.updateTelemetry(squadState);

          const statusIndicator = document.getElementById('status-indicator');
          const serverNameDisplay = document.getElementById('server-name-display');
          const gtaHealthFill = document.getElementById('gta-health-fill');
          const gtaArmorFill = document.getElementById('gta-armor-fill');

          if (squadState.is_live) {
            if (statusIndicator) statusIndicator.classList.add('online');
            if (serverNameDisplay) serverNameDisplay.textContent = squadState.server_name || 'Online (Live Radar)';

            if (squadState.self) {
              if (gtaHealthFill) gtaHealthFill.style.width = `${Math.max(0, Math.min(100, squadState.self.health || 100))}%`;
              if (gtaArmorFill) gtaArmorFill.style.width = `${Math.max(0, Math.min(100, (squadState.self.stamina || 1.0) * 100))}%`;
            }
          } else {
            if (statusIndicator) statusIndicator.classList.remove('online');
            if (serverNameDisplay) serverNameDisplay.textContent = 'Modo Offline (Aguardando Sinal)';
          }
        } catch (e) {
          console.warn('Erro ao obter telemetria:', e);
        }
      }

      this.telemetryTimer = setTimeout(pollTelemetry, 300);
    };

    pollTelemetry();
  }
}

// Inicializa a aplicação quando o DOM estiver pronto
document.addEventListener('DOMContentLoaded', () => {
  const app = new App();
  app.init();
});
