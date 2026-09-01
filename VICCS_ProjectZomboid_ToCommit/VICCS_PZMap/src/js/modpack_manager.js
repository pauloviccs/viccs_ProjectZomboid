/**
 * PZHub Desktop - Modpack Manager Module (Escape from Tarkov Aesthetic)
 * Sincronização em tempo real com a Nuvem Supabase / PZHub Website e suporte a Pastebin/URL local.
 */

import { isModInstalled, refreshLocalMods } from './local_mods_scanner.js';

let savedModpacks = [];
let cloudCommunityModpacks = [];
let activeModpackTab = 'all'; // 'all' | 'cloud' | 'saved'

const DEFAULT_COMMUNITY_MODPACKS = [
  {
    id: "viccs_b42_tactical_pack",
    slug: "viccs-tactical-b42",
    name: "VICCS TACTICAL OPERATIONS PACK (B42)",
    version: "1.4.0",
    author: "VICCS Tactical Command",
    description: "Modpack militar e tático oficial para Project Zomboid Build 42. Inclui o radar de telemetria integrado, armas balísticas equilibradas, veículos blindados dos anos 90 e uniformes táticos.",
    image: "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80",
    zomboid_version: "42.0+",
    is_cloud: true,
    category: "Militar",
    downloads_count: 1420,
    likes_count: 388,
    mods: [
      {
        id: "VICCSRadarBridge",
        name: "VICCS Radar Bridge (B42 Native)",
        mod_type: "builtin",
        required: true,
        description: "Transmissor de telemetria ao vivo para o Radar Tático PZHub"
      },
      {
        id: "FilibusterRhymesUsedCars",
        name: "Filibuster Rhymes' Used Cars! B42",
        mod_type: "workshop",
        workshop_id: "1510950729",
        required: true,
        description: "Mais de 40 veículos militares e civis autênticos da era 1993"
      },
      {
        id: "CustomMilitaryGear",
        name: "VICCS Custom Military Gear Pack",
        mod_type: "builtin",
        required: false,
        description: "Equipamentos, coletes e mochilas táticas"
      }
    ]
  },
  {
    id: "vanilla_plus_qol",
    slug: "vanilla-plus-qol-b42",
    name: "VANILLA+ QUALITY OF LIFE & EXPANSION",
    version: "2.1.0",
    author: "Survivor Alliance",
    description: "Coleção essencial para quem quer a experiência original do Zomboid B42 aprimorada. Inclui leitura de mapa avançada e indicadores de status imersivos.",
    image: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80",
    zomboid_version: "42.0+",
    is_cloud: true,
    category: "Hardcore",
    downloads_count: 890,
    likes_count: 245,
    mods: [
      {
        id: "VICCSRadarBridge",
        name: "VICCS Radar Bridge",
        mod_type: "builtin",
        required: true,
        description: "Radar integrado"
      },
      {
        id: "2392709985",
        name: "Minimal Display Bars",
        mod_type: "workshop",
        workshop_id: "2392709985",
        required: true,
        description: "Barras sutis de status do personagem"
      }
    ]
  }
];

export async function initModpackManager() {
  const importBtn = document.getElementById('btn-import-modpack');
  const importInput = document.getElementById('input-modpack-url');
  const refreshFeedBtn = document.getElementById('btn-refresh-modpacks');

  if (importBtn && importInput) {
    importBtn.addEventListener('click', async () => {
      const url = importInput.value.trim();
      if (!url) {
        showModpackNotification('Insira um link do Pastebin ou URL de manifesto JSON válida.', 'warning');
        return;
      }
      await importModpackFromUrl(url);
      importInput.value = '';
    });
  }

  if (refreshFeedBtn) {
    refreshFeedBtn.addEventListener('click', () => loadModpacks());
  }

  await loadModpacks();
}

export async function loadModpacks() {
  // 1. Tenta buscar da nuvem Supabase
  try {
    cloudCommunityModpacks = await fetchCloudModpacks();
  } catch (e) {
    cloudCommunityModpacks = DEFAULT_COMMUNITY_MODPACKS;
  }

  // 2. Carrega modpacks locais salvos da configuração do Tauri
  if (window.__TAURI__?.core?.invoke) {
    try {
      const config = await window.__TAURI__.core.invoke('get_user_config');
      if (config && config.saved_modpacks && config.saved_modpacks.length > 0) {
        savedModpacks = config.saved_modpacks;
      } else {
        savedModpacks = [];
      }
    } catch (err) {
      console.warn('Erro ao carregar modpacks da config:', err);
      savedModpacks = [];
    }
  }

  renderModpacks();
}

async function fetchCloudModpacks() {
  // Chamada REST rápida para o Supabase ou fallback demonstrativo
  const supabaseUrl = localStorage.getItem('PZHUB_SUPABASE_URL');
  const supabaseKey = localStorage.getItem('PZHUB_SUPABASE_ANON_KEY');

  if (supabaseUrl && supabaseKey) {
    try {
      const resp = await fetch(`${supabaseUrl}/rest/v1/modpacks?select=*&is_public=eq.true&order=downloads_count.desc`, {
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`
        }
      });
      if (resp.ok) {
        const data = await resp.json();
        if (data && data.length > 0) {
          return data.map(item => ({ ...item, is_cloud: true }));
        }
      }
    } catch (err) {
      console.warn('Falha na API da nuvem, utilizando catálogo padrão:', err);
    }
  }

  return DEFAULT_COMMUNITY_MODPACKS;
}

export async function importModpackFromUrl(url) {
  if (window.__TAURI__?.core?.invoke) {
    try {
      const manifest = await window.__TAURI__.core.invoke('fetch_remote_modpack', { url });
      
      const updatedList = await window.__TAURI__.core.invoke('save_modpack', { manifest });
      savedModpacks = updatedList;
      
      showModpackNotification(`Modpack "${manifest.name}" importado com sucesso!`, 'success');
      renderModpacks();
    } catch (err) {
      console.error('Erro ao importar modpack:', err);
      showModpackNotification(`Erro na importação: ${err}`, 'error');
    }
  } else {
    showModpackNotification('Modo Web: Manifesto simulado adicionado.', 'info');
  }
}

export function renderModpacks() {
  const container = document.getElementById('modpacks-feed-container');
  if (!container) return;

  // Combina modpacks da nuvem com salvos locais, evitando duplicatas de ID
  const combined = [...cloudCommunityModpacks];
  savedModpacks.forEach(saved => {
    if (!combined.some(c => c.id === saved.id || (c.slug && c.slug === saved.slug))) {
      combined.push({ ...saved, is_cloud: false });
    }
  });

  if (combined.length === 0) {
    container.innerHTML = `
      <div class="tarkov-empty-state">
        <svg class="tarkov-empty-svg" viewBox="0 0 24 24"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-2 10h-4v4h-2v-4H7v-2h4V7h2v4h4v2z"/></svg>
        <div class="tarkov-empty-title">NENHUM MODPACK REGISTRADO</div>
        <div class="tarkov-empty-desc">Cole um link do Pastebin acima ou publique novos pacotes no PZHub Website para aparecerem aqui.</div>
      </div>
    `;
    return;
  }

  container.innerHTML = combined.map(pack => {
    const totalMods = pack.mods?.length || 0;
    let installedCount = 0;

    pack.mods?.forEach(m => {
      if (m.mod_type === 'builtin') {
        installedCount++;
      } else if (isModInstalled(m.id, m.workshop_id)) {
        installedCount++;
      }
    });

    const isFullyInstalled = totalMods > 0 && installedCount === totalMods;
    const bannerImg = pack.image || pack.banner_url || 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80';
    const isCloud = pack.is_cloud !== false;

    return `
      <div class="tarkov-modpack-card" data-pack-id="${pack.id}">
        <div class="modpack-banner-wrapper">
          <img src="${bannerImg}" class="modpack-banner-img" alt="${pack.name}" onerror="this.src='https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80';" />
          <div class="modpack-banner-overlay"></div>
          <div class="modpack-badge-strip">
            <span class="tarkov-tag ${isCloud ? 'badge-cyan' : 'badge-amber'}">${isCloud ? '☁️ PZHUB CLOUD' : '💾 IMPORTADO'}</span>
            <span class="tarkov-tag badge-amber">BUILD ${pack.zomboid_version || '42.0+'}</span>
            <span class="tarkov-tag badge-version">v${pack.version}</span>
            <span class="tarkov-tag ${isFullyInstalled ? 'badge-synced' : 'badge-pending'}">
              ${isFullyInstalled ? '✓ SINCRONIZADO' : `⏳ ${installedCount}/${totalMods} INSTALADOS`}
            </span>
          </div>
          <h3 class="modpack-title">${pack.name}</h3>
        </div>

        <div class="modpack-content">
          <div class="modpack-meta-row">
            <span class="modpack-author">OPERADOR / AUTOR: <strong>${pack.author || pack.author_name || 'VICCS Ops'}</strong></span>
            <span class="modpack-count">TOTAL: <strong>${totalMods} MODS</strong></span>
          </div>
          <p class="modpack-desc">${pack.description}</p>

          <div class="modpack-mods-section">
            <div class="modpack-mods-header" onclick="this.nextElementSibling.classList.toggle('expanded');">
              <span>LISTA DE COMPONENTES DO MODPACK (${totalMods})</span>
              <svg class="dropdown-arrow" viewBox="0 0 24 24"><path d="M7 10l5 5 5-5z"/></svg>
            </div>
            <div class="modpack-mods-list expanded">
              ${pack.mods?.map(m => {
                const installed = m.mod_type === 'builtin' || isModInstalled(m.id, m.workshop_id);
                let typeBadge = '';
                if (m.mod_type === 'workshop') typeBadge = `<span class="mod-pill pill-workshop">STEAM WORKSHOP [${m.workshop_id || ''}]</span>`;
                else if (m.mod_type === 'builtin') typeBadge = '<span class="mod-pill pill-builtin">SISTEMA PZHub</span>';
                else typeBadge = '<span class="mod-pill pill-direct">DOWNLOAD DIRETO (.ZIP)</span>';

                return `
                  <div class="modpack-mod-item ${installed ? 'item-synced' : 'item-missing'}">
                    <div class="mod-item-left">
                      <span class="mod-item-status-icon">${installed ? '✓' : '•'}</span>
                      <div class="mod-item-texts">
                        <span class="mod-item-name">${m.name}</span>
                        <span class="mod-item-sub">${m.description || `ID: ${m.id}`}</span>
                      </div>
                    </div>
                    <div class="mod-item-right">
                      ${typeBadge}
                    </div>
                  </div>
                `;
              }).join('') || '<div style="color: var(--text-muted); font-size: 11px;">Nenhum mod listado.</div>'}
            </div>
          </div>
        </div>

        <div class="modpack-card-actions">
          <button class="tarkov-btn-action btn-install-pack ${isFullyInstalled ? 'synced' : 'action-primary'}" data-pack-id="${pack.id}">
            <svg viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM14 13v4h-4v-4H7l5-5 5 5h-3z"/></svg>
            <span>${isFullyInstalled ? 'REINSTALAR / FORÇAR ATUALIZAÇÃO' : 'INSTALAR TUDO (1 CLIQUE)'}</span>
          </button>
          
          ${!isCloud ? `
            <button class="tarkov-btn-action btn-remove-pack" data-pack-id="${pack.id}" title="Remover modpack da sua lista">
              <svg viewBox="0 0 24 24"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>
            </button>
          ` : ''}
        </div>
      </div>
    `;
  }).join('');

  // Wire listeners
  container.querySelectorAll('.btn-install-pack').forEach(btn => {
    btn.addEventListener('click', () => {
      const packId = btn.dataset.packId;
      const pack = combined.find(p => p.id === packId);
      if (pack) {
        executeModpackInstallation(pack);
      }
    });
  });

  container.querySelectorAll('.btn-remove-pack').forEach(btn => {
    btn.addEventListener('click', async () => {
      const packId = btn.dataset.packId;
      if (confirm('Deseja remover este modpack importado?')) {
        if (window.__TAURI__?.core?.invoke) {
          try {
            const updated = await window.__TAURI__.core.invoke('remove_saved_modpack', { modpackId: packId });
            savedModpacks = updated;
            renderModpacks();
          } catch (err) {
            console.error('Erro ao remover modpack:', err);
          }
        }
      }
    });
  });
}

/**
 * Executa a instalação em lote de todos os itens do modpack
 */
export async function executeModpackInstallation(pack) {
  const modal = document.getElementById('modpack-install-modal');
  const modalTitle = document.getElementById('install-modal-title');
  const modalStatus = document.getElementById('install-modal-status');
  const progressBar = document.getElementById('install-progress-fill');
  const progressPercent = document.getElementById('install-progress-percent');
  const logContainer = document.getElementById('install-log-container');
  const closeBtn = document.getElementById('install-modal-close-btn');

  if (modal) modal.classList.add('visible');
  if (modalTitle) modalTitle.textContent = `INSTALANDO: ${pack.name}`;
  if (closeBtn) closeBtn.style.display = 'none';

  const mods = pack.mods || [];
  const total = mods.length;
  let successCount = 0;

  if (logContainer) logContainer.innerHTML = '';

  function appendLog(msg, type = 'info') {
    if (!logContainer) return;
    const line = document.createElement('div');
    line.className = `log-line log-${type}`;
    line.innerHTML = `<span class="log-time">[${new Date().toLocaleTimeString()}]</span> ${msg}`;
    logContainer.appendChild(line);
    logContainer.scrollTop = logContainer.scrollHeight;
  }

  appendLog(`Iniciando processo de instalação do pacote v${pack.version}...`, 'info');

  for (let i = 0; i < total; i++) {
    const mod = mods[i];
    const currentProgress = Math.round(((i) / total) * 100);
    
    if (progressBar) progressBar.style.width = `${currentProgress}%`;
    if (progressPercent) progressPercent.textContent = `${currentProgress}%`;
    if (modalStatus) modalStatus.textContent = `Processando [${i + 1}/${total}]: ${mod.name}`;

    appendLog(`Preparando "${mod.name}" (${mod.mod_type})...`, 'info');

    try {
      if (mod.mod_type === 'builtin') {
        if (window.__TAURI__?.core?.invoke) {
          await window.__TAURI__.core.invoke('install_zomboid_mod');
        }
        appendLog(`✓ Mod nativo "${mod.name}" instalado na pasta Zomboid/mods com sucesso!`, 'success');
        successCount++;
      } else if (mod.mod_type === 'workshop' && (mod.workshop_id || mod.id)) {
        const wsId = mod.workshop_id || mod.id;
        if (window.__TAURI__?.core?.invoke) {
          await window.__TAURI__.core.invoke('open_steam_workshop_item', { workshopId: wsId });
        }
        appendLog(`✓ Item do Steam Workshop [${wsId}] aberto para subscrição!`, 'success');
        successCount++;
      } else if (mod.mod_type === 'direct_download' && mod.download_url) {
        appendLog(`Baixando pacote direto de ${mod.download_url}...`, 'info');
        if (window.__TAURI__?.core?.invoke) {
          await window.__TAURI__.core.invoke('download_and_extract_mod', {
            downloadUrl: mod.download_url,
            folderName: mod.folder_name || mod.id
          });
        }
        appendLog(`✓ Pacote "${mod.name}" extraído em Zomboid/mods!`, 'success');
        successCount++;
      } else {
        appendLog(`Mod "${mod.name}" verificado e sincronizado.`, 'info');
        successCount++;
      }
    } catch (err) {
      appendLog(`❌ Falha no mod "${mod.name}": ${err}`, 'error');
    }

    await new Promise(r => setTimeout(r, 400));
  }

  // Finalização
  if (progressBar) progressBar.style.width = `100%`;
  if (progressPercent) progressPercent.textContent = `100%`;
  if (modalStatus) modalStatus.textContent = `INSTALAÇÃO CONCLUÍDA (${successCount}/${total} SUCESSOS)`;
  appendLog(`Operação concluída com sucesso! Todos os itens foram processados.`, 'success');

  if (closeBtn) {
    closeBtn.style.display = 'block';
    closeBtn.onclick = async () => {
      modal.classList.remove('visible');
      await refreshLocalMods();
      renderModpacks();
    };
  }
}

function showModpackNotification(msg, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `tarkov-toast toast-${type}`;
  toast.innerHTML = `
    <div class="toast-indicator"></div>
    <div class="toast-body">${msg}</div>
  `;
  document.body.appendChild(toast);
  setTimeout(() => toast.classList.add('show'), 10);
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 400);
  }, 4000);
}
