/**
 * PZHub - Public Community Workshop Module
 * Renderização do catálogo de modpacks, busca, filtros de categorias e modal de detalhes.
 */

import { fetchCommunityModpacks } from './supabaseClient.js';

let activeCategory = 'all';
let currentSearch = '';
let currentSort = 'downloads';
let cachedModpacks = [];

export async function initWorkshop() {
  const categoryBtns = document.querySelectorAll('.ws-category-btn');
  const searchInput = document.getElementById('ws-search-input');
  const sortSelect = document.getElementById('ws-sort-select');

  categoryBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      categoryBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeCategory = btn.dataset.category || 'all';
      loadAndRenderWorkshop();
    });
  });

  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      currentSearch = e.target.value.trim();
      loadAndRenderWorkshop();
    });
  }

  if (sortSelect) {
    sortSelect.addEventListener('change', (e) => {
      currentSort = e.target.value;
      loadAndRenderWorkshop();
    });
  }

  await loadAndRenderWorkshop();
}

export async function loadAndRenderWorkshop() {
  const grid = document.getElementById('workshop-cards-grid');
  const countBadge = document.getElementById('workshop-total-count');

  if (grid) {
    grid.innerHTML = `
      <div class="tarkov-loading-state" style="grid-column: 1 / -1;">
        <div class="tarkov-spinner"></div>
        <span>CONECTANDO À NUVEM PZHUB // CARREGANDO MODPACKS...</span>
      </div>
    `;
  }

  cachedModpacks = await fetchCommunityModpacks({
    category: activeCategory,
    searchQuery: currentSearch,
    sortBy: currentSort
  });

  if (countBadge) {
    countBadge.textContent = `${cachedModpacks.length} MODPACKS ENCONTRADOS`;
  }

  if (!grid) return;

  if (cachedModpacks.length === 0) {
    grid.innerHTML = `
      <div class="tarkov-empty-state" style="grid-column: 1 / -1;">
        <svg class="tarkov-empty-svg" viewBox="0 0 24 24"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-2 10h-4v4h-2v-4H7v-2h4V7h2v4h4v2z"/></svg>
        <div class="tarkov-empty-title">NENHUM MODPACK ENCONTRADO</div>
        <div class="tarkov-empty-desc">Nenhum pacote corresponde aos filtros ativos. Seja o primeiro a publicar um modpack no Estúdio do Criador!</div>
      </div>
    `;
    return;
  }

  grid.innerHTML = cachedModpacks.map(pack => {
    const totalMods = pack.mods?.length || 0;
    const banner = pack.banner_url || 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80';

    return `
      <div class="ws-modpack-card" data-slug="${pack.slug || pack.id}">
        <div class="ws-card-banner-wrap">
          <img src="${banner}" class="ws-card-banner-img" alt="${pack.name}" onerror="this.src='https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80';" />
          <div class="ws-card-banner-overlay"></div>
          <div class="ws-card-tags">
            <span class="tarkov-tag badge-amber">BUILD ${pack.zomboid_version || '42.0+'}</span>
            <span class="tarkov-tag badge-version">v${pack.version}</span>
            <span class="tarkov-tag badge-cyan">${pack.category || 'Geral'}</span>
          </div>
          <div class="ws-card-stats-strip">
            <span>📥 ${pack.downloads_count || 0}</span>
            <span>⭐ ${pack.likes_count || 0}</span>
          </div>
        </div>

        <div class="ws-card-content">
          <div class="ws-card-author">OPERADOR: <strong>${pack.author_name || 'Comunidade'}</strong></div>
          <h3 class="ws-card-title">${pack.name}</h3>
          <p class="ws-card-desc">${pack.description}</p>
          <div class="ws-card-mods-count">CONTEÚDO: <strong>${totalMods} MODS INTEGRADOS</strong></div>
        </div>

        <div class="ws-card-actions">
          <button class="tarkov-btn-action action-primary btn-open-desktop" data-slug="${pack.slug || pack.id}">
            <svg viewBox="0 0 24 24"><path d="M19 19H5V5h7V3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2v-7h-2v7zM14 3v2h3.59l-9.83 9.83 1.41 1.41L19 6.41V10h2V3h-7z"/></svg>
            <span>ABRIR NO PZHUB</span>
          </button>
          <button class="tarkov-btn btn-view-details" data-slug="${pack.slug || pack.id}">
            DETALHES
          </button>
        </div>
      </div>
    `;
  }).join('');

  // Wire actions
  grid.querySelectorAll('.btn-open-desktop').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const slug = btn.dataset.slug;
      const pack = cachedModpacks.find(p => (p.slug || p.id) === slug);
      if (pack) {
        handleOpenInDesktop(pack);
      }
    });
  });

  grid.querySelectorAll('.btn-view-details').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const slug = btn.dataset.slug;
      const pack = cachedModpacks.find(p => (p.slug || p.id) === slug);
      if (pack) {
        showModpackDetailModal(pack);
      }
    });
  });
}

function handleOpenInDesktop(pack) {
  // Gera o link de manifesto JSON ou comando deep link
  const jsonUrl = `${window.location.origin}/api/modpack/${pack.slug || pack.id}`;
  
  // Tenta disparar protocolo nativo do PZHub
  const deepLink = `pzhub://sync?manifest=${encodeURIComponent(jsonUrl)}`;
  window.location.href = deepLink;

  // Mostra aviso visual de sincronização
  setTimeout(() => {
    showSyncNotificationModal(pack, jsonUrl);
  }, 300);
}

function showSyncNotificationModal(pack, jsonUrl) {
  const modal = document.getElementById('sync-info-modal');
  const titleEl = document.getElementById('sync-modal-pack-name');
  const linkInput = document.getElementById('sync-modal-link-input');
  const copyBtn = document.getElementById('btn-copy-sync-link');
  const closeBtn = document.getElementById('sync-modal-close-btn');

  if (titleEl) titleEl.textContent = pack.name;
  if (linkInput) linkInput.value = jsonUrl;

  if (modal) modal.classList.add('visible');

  if (copyBtn && linkInput) {
    copyBtn.onclick = () => {
      linkInput.select();
      navigator.clipboard.writeText(jsonUrl);
      copyBtn.textContent = '✓ COPIADO!';
      setTimeout(() => copyBtn.textContent = 'COPIAR LINK', 2000);
    };
  }

  if (closeBtn && modal) {
    closeBtn.onclick = () => modal.classList.remove('visible');
  }
}

function showModpackDetailModal(pack) {
  const modal = document.getElementById('modpack-detail-modal');
  const titleEl = document.getElementById('detail-modal-title');
  const bannerEl = document.getElementById('detail-modal-banner');
  const authorEl = document.getElementById('detail-modal-author');
  const descEl = document.getElementById('detail-modal-desc');
  const modsListEl = document.getElementById('detail-modal-mods-list');
  const closeBtn = document.getElementById('detail-modal-close-btn');
  const installBtn = document.getElementById('detail-modal-install-btn');

  if (titleEl) titleEl.textContent = pack.name;
  if (bannerEl) bannerEl.src = pack.banner_url || 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80';
  if (authorEl) authorEl.textContent = pack.author_name || 'Comunidade';
  if (descEl) descEl.textContent = pack.description;

  if (modsListEl) {
    modsListEl.innerHTML = pack.mods?.map(m => `
      <div class="detail-mod-row">
        <div class="detail-mod-left">
          <span class="detail-mod-name">${m.name}</span>
          <span class="detail-mod-sub">${m.description || `ID: ${m.id}`}</span>
        </div>
        <div class="detail-mod-right">
          <span class="tarkov-tag ${m.mod_type === 'workshop' ? 'badge-cyan' : 'badge-amber'}">
            ${m.mod_type === 'workshop' ? `STEAM WORKSHOP [${m.workshop_id || ''}]` : (m.mod_type === 'builtin' ? 'VICCS NATIVO' : 'DOWNLOAD DIRETO')}
          </span>
        </div>
      </div>
    `).join('') || '<div>Nenhum mod listado.</div>';
  }

  if (installBtn) {
    installBtn.onclick = () => {
      modal.classList.remove('visible');
      handleOpenInDesktop(pack);
    };
  }

  if (modal) modal.classList.add('visible');
  if (closeBtn && modal) {
    closeBtn.onclick = () => modal.classList.remove('visible');
  }
}
