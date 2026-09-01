/**
 * PZHub - Local Mods Scanner Module (Tarkov Aesthetic)
 * Gerencia a varredura, busca, filtros e renderização dos mods instalados no computador.
 */

let allLocalMods = [];
let activeFilter = 'all'; // 'all' | 'local' | 'workshop'
let searchQuery = '';

export async function initLocalModsScanner() {
  const refreshBtn = document.getElementById('btn-refresh-local-mods');
  const searchInput = document.getElementById('input-search-local-mods');
  const filterBtns = document.querySelectorAll('.mod-filter-btn');
  const openModsFolderBtn = document.getElementById('btn-open-folder-scanner');

  if (refreshBtn) {
    refreshBtn.addEventListener('click', () => refreshLocalMods());
  }

  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      searchQuery = e.target.value.toLowerCase().trim();
      renderLocalMods();
    });
  }

  if (openModsFolderBtn) {
    openModsFolderBtn.addEventListener('click', async () => {
      if (window.__TAURI__?.core?.invoke) {
        try {
          await window.__TAURI__.core.invoke('open_zomboid_mods_dir');
        } catch (err) {
          console.error('Erro ao abrir pasta:', err);
        }
      }
    });
  }

  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeFilter = btn.dataset.filter || 'all';
      renderLocalMods();
    });
  });

  // Carrega mods pela primeira vez
  await refreshLocalMods();
}

export async function refreshLocalMods() {
  const container = document.getElementById('local-mods-grid');
  const countBadge = document.getElementById('local-mods-total-count');
  const statusBadge = document.getElementById('scanner-status-text');

  if (statusBadge) statusBadge.textContent = 'ESCANEANDO ARQUIVOS...';
  if (container) {
    container.innerHTML = `
      <div class="tarkov-loading-state">
        <div class="tarkov-spinner"></div>
        <span>ESCANEANDO DIRETÓRIOS DO PROJECT ZOMBOID & STEAM WORKSHOP...</span>
      </div>
    `;
  }

  if (window.__TAURI__?.core?.invoke) {
    try {
      const mods = await window.__TAURI__.core.invoke('scan_installed_mods');
      allLocalMods = mods || [];
      if (countBadge) countBadge.textContent = `${allLocalMods.length} MODS DETECTADOS`;
      if (statusBadge) statusBadge.textContent = 'SISTEMA PRONTO';
    } catch (err) {
      console.error('Erro ao escanear mods:', err);
      if (statusBadge) statusBadge.textContent = 'ERRO NO SCANNER';
      if (container) {
        container.innerHTML = `
          <div class="tarkov-empty-state error">
            <span class="tarkov-empty-icon">⚠️</span>
            <div class="tarkov-empty-title">FALHA AO ACESSAR DIRETÓRIOS</div>
            <div class="tarkov-empty-desc">${err}</div>
          </div>
        `;
      }
      return;
    }
  } else {
    // Modo Web / Simulação
    allLocalMods = [
      {
        id: "VICCSRadarBridge",
        name: "VICCS Radar Bridge (B42 Native)",
        description: "Módulo de telemetria tática para o Project Zomboid Build 42.",
        version_min: "42.0.0",
        poster_base64: null,
        icon_base64: null,
        source_type: "local",
        folder_path: "C:/Users/User/Zomboid/mods/VICCSRadarBridge",
        workshop_id: null,
        is_active: true
      },
      {
        id: "FilibusterRhymesUsedCars",
        name: "Filibuster Rhymes' Used Cars! B42",
        description: "Adiciona dezenas de veículos fiéis aos anos 90.",
        version_min: "41.50",
        poster_base64: null,
        icon_base64: null,
        source_type: "workshop",
        folder_path: "Steam/steamapps/workshop/content/108600/1510950729",
        workshop_id: "1510950729",
        is_active: true
      }
    ];
    if (countBadge) countBadge.textContent = `${allLocalMods.length} MODS DETECTADOS (SIMULAÇÃO)`;
  }

  renderLocalMods();
}

export function getLocalModsList() {
  return allLocalMods;
}

export function isModInstalled(modId, workshopId) {
  if (!allLocalMods || allLocalMods.length === 0) return false;
  return allLocalMods.some(m => {
    if (modId && m.id && m.id.toLowerCase() === modId.toLowerCase()) return true;
    if (workshopId && m.workshop_id && m.workshop_id === workshopId) return true;
    return false;
  });
}

function renderLocalMods() {
  const container = document.getElementById('local-mods-grid');
  if (!container) return;

  const filtered = allLocalMods.filter(m => {
    // Filtro por tipo
    if (activeFilter === 'local' && m.source_type !== 'local') return false;
    if (activeFilter === 'workshop' && m.source_type !== 'workshop') return false;

    // Filtro por busca
    if (searchQuery) {
      const nameMatch = m.name?.toLowerCase().includes(searchQuery);
      const idMatch = m.id?.toLowerCase().includes(searchQuery);
      const descMatch = m.description?.toLowerCase().includes(searchQuery);
      return nameMatch || idMatch || descMatch;
    }
    return true;
  });

  if (filtered.length === 0) {
    container.innerHTML = `
      <div class="tarkov-empty-state">
        <svg class="tarkov-empty-svg" viewBox="0 0 24 24"><path d="M20 6h-8l-2-2H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm0 12H4V8h16v10z"/></svg>
        <div class="tarkov-empty-title">NENHUM MOD ENCONTRADO</div>
        <div class="tarkov-empty-desc">Nenhum mod corresponde aos filtros ativos ou à pesquisa realizada.</div>
      </div>
    `;
    return;
  }

  container.innerHTML = filtered.map(m => {
    const isWorkshop = m.source_type === 'workshop';
    const typeLabel = isWorkshop ? 'STEAM WORKSHOP' : 'MOD LOCAL';
    const typeClass = isWorkshop ? 'badge-workshop' : 'badge-local';
    const versionLabel = m.version_min ? `B${m.version_min}` : 'UNIVERSAL';
    const iconSrc = m.icon_base64 || m.poster_base64 || './favicon-32x32.png';

    return `
      <div class="tarkov-mod-card" data-mod-id="${m.id}">
        <div class="mod-card-header">
          <div class="mod-icon-wrapper">
            <img src="${iconSrc}" class="mod-thumbnail-img" alt="${m.name}" onerror="this.src='./favicon-32x32.png';" />
          </div>
          <div class="mod-header-info">
            <div class="mod-card-title" title="${m.name}">${m.name}</div>
            <div class="mod-id-code"><code>ID: ${m.id}</code></div>
          </div>
        </div>

        <div class="mod-card-body">
          <p class="mod-card-desc">${m.description || 'Nenhuma descrição técnica fornecida no arquivo mod.info.'}</p>
        </div>

        <div class="mod-card-footer">
          <div class="mod-tags-group">
            <span class="tarkov-tag ${typeClass}">${typeLabel}</span>
            <span class="tarkov-tag badge-version">${versionLabel}</span>
          </div>
          <div class="mod-actions-group">
            ${isWorkshop && m.workshop_id ? `
              <button class="tarkov-btn-icon btn-open-workshop" data-workshop-id="${m.workshop_id}" title="Abrir página no Steam Workshop">
                <svg viewBox="0 0 24 24"><path d="M19 19H5V5h7V3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2v-7h-2v7zM14 3v2h3.59l-9.83 9.83 1.41 1.41L19 6.41V10h2V3h-7z"/></svg>
              </button>
            ` : ''}
            <button class="tarkov-btn-icon btn-open-folder" data-folder="${encodeURIComponent(m.folder_path)}" title="Abrir pasta no Windows Explorer">
              <svg viewBox="0 0 24 24"><path d="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/></svg>
            </button>
          </div>
        </div>
      </div>
    `;
  }).join('');

  // Adiciona listeners para os botões dos cards
  container.querySelectorAll('.btn-open-workshop').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const wsId = btn.dataset.workshopId;
      if (wsId && window.__TAURI__?.core?.invoke) {
        try {
          await window.__TAURI__.core.invoke('open_steam_workshop_item', { workshopId: wsId });
        } catch (err) {
          console.error('Erro ao abrir Workshop:', err);
        }
      }
    });
  });

  container.querySelectorAll('.btn-open-folder').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const folderPath = decodeURIComponent(btn.dataset.folder);
      if (folderPath && window.__TAURI__?.core?.invoke) {
        try {
          await window.__TAURI__.core.invoke('open_mod_folder', { folderPath });
        } catch (err) {
          console.error('Erro ao abrir pasta:', err);
        }
      }
    });
  });
}
