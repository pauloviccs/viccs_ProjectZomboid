/**
 * PZHub - Visual Modpack Builder (Creator Studio)
 * Formulário interativo para criação de modpacks, lista dinâmica de mods e live preview tático.
 */

import { publishModpack } from './supabaseClient.js';
import { getCurrentUser } from './auth.js';

let builderModsList = [
  {
    id: "VICCSRadarBridge",
    name: "VICCS Radar Bridge (B42 Native)",
    mod_type: "builtin",
    required: true,
    description: "Transmissor de telemetria ao vivo para o Radar PZHub"
  }
];

export function initModpackBuilder() {
  const form = document.getElementById('modpack-builder-form');
  const addWorkshopBtn = document.getElementById('btn-add-workshop-mod');
  const addDirectBtn = document.getElementById('btn-add-direct-mod');
  const addBuiltinBtn = document.getElementById('btn-add-builtin-mod');
  const presetBannerBtns = document.querySelectorAll('.banner-preset-btn');

  // Input listeners para atualizar o Live Preview em tempo real
  const nameInput = document.getElementById('builder-name');
  const categoryInput = document.getElementById('builder-category');
  const versionInput = document.getElementById('builder-version');
  const zomboidVerInput = document.getElementById('builder-zomboid-ver');
  const bannerInput = document.getElementById('builder-banner-url');
  const descInput = document.getElementById('builder-desc');

  [nameInput, categoryInput, versionInput, zomboidVerInput, bannerInput, descInput].forEach(input => {
    if (input) {
      input.addEventListener('input', () => updateLivePreview());
    }
  });

  presetBannerBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      if (bannerInput) {
        bannerInput.value = btn.dataset.url;
        updateLivePreview();
      }
    });
  });

  if (addWorkshopBtn) {
    addWorkshopBtn.addEventListener('click', () => {
      builderModsList.push({
        id: `mod_${Date.now()}`,
        name: 'Novo Mod da Steam Workshop',
        mod_type: 'workshop',
        workshop_id: '',
        required: true,
        description: ''
      });
      renderBuilderModsList();
      updateLivePreview();
    });
  }

  if (addDirectBtn) {
    addDirectBtn.addEventListener('click', () => {
      builderModsList.push({
        id: `direct_${Date.now()}`,
        name: 'Mod Direto (.zip)',
        mod_type: 'direct_download',
        download_url: '',
        folder_name: '',
        required: false,
        description: ''
      });
      renderBuilderModsList();
      updateLivePreview();
    });
  }

  if (addBuiltinBtn) {
    addBuiltinBtn.addEventListener('click', () => {
      builderModsList.push({
        id: `builtin_${Date.now()}`,
        name: 'Módulo Especial PZHub',
        mod_type: 'builtin',
        required: true,
        description: ''
      });
      renderBuilderModsList();
      updateLivePreview();
    });
  }

  if (form) {
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      await handlePublishModpack();
    });
  }

  renderBuilderModsList();
  updateLivePreview();
}

function renderBuilderModsList() {
  const container = document.getElementById('builder-mods-items-container');
  if (!container) return;

  if (builderModsList.length === 0) {
    container.innerHTML = `
      <div class="builder-empty-mods">
        <span>Nenhum mod adicionado ao pacote ainda. Clique em um dos botões acima para adicionar.</span>
      </div>
    `;
    return;
  }

  container.innerHTML = builderModsList.map((mod, index) => {
    const isWorkshop = mod.mod_type === 'workshop';
    const isDirect = mod.mod_type === 'direct_download';
    const typeLabel = isWorkshop ? 'STEAM WORKSHOP' : (isDirect ? 'DOWNLOAD DIRETO (.ZIP)' : 'MOD NATIVO');

    return `
      <div class="builder-mod-row" data-index="${index}">
        <div class="mod-row-header">
          <span class="row-type-tag type-${mod.mod_type}">${typeLabel}</span>
          <button type="button" class="btn-remove-row" data-index="${index}" title="Remover este mod">✕</button>
        </div>

        <div class="mod-row-fields">
          <div class="field-group" style="flex: 2;">
            <label>Nome do Mod:</label>
            <input type="text" class="tarkov-input-sm input-mod-name" data-index="${index}" value="${mod.name}" placeholder="Ex: Filibuster Rhymes Used Cars" required />
          </div>

          ${isWorkshop ? `
            <div class="field-group" style="flex: 2;">
              <label>Link ou ID da Oficina Steam:</label>
              <input type="text" class="tarkov-input-sm input-workshop-id" data-index="${index}" value="${mod.workshop_id || ''}" placeholder="Ex: 1510950729 ou link da Steam" required />
            </div>
          ` : ''}

          ${isDirect ? `
            <div class="field-group" style="flex: 2;">
              <label>URL Direta de Download (.zip):</label>
              <input type="url" class="tarkov-input-sm input-download-url" data-index="${index}" value="${mod.download_url || ''}" placeholder="https://exemplo.com/mod.zip" required />
            </div>
          ` : ''}

          <div class="field-group" style="flex: 1; max-width: 120px;">
            <label>Obrigatório?</label>
            <label class="tarkov-checkbox-label">
              <input type="checkbox" class="chk-required" data-index="${index}" ${mod.required ? 'checked' : ''} />
              <span>Sim</span>
            </label>
          </div>
        </div>
      </div>
    `;
  }).join('');

  // Wire row listeners
  container.querySelectorAll('.btn-remove-row').forEach(btn => {
    btn.addEventListener('click', () => {
      const idx = parseInt(btn.dataset.index, 10);
      builderModsList.splice(idx, 1);
      renderBuilderModsList();
      updateLivePreview();
    });
  });

  container.querySelectorAll('.input-mod-name').forEach(input => {
    input.addEventListener('input', (e) => {
      const idx = parseInt(input.dataset.index, 10);
      builderModsList[idx].name = e.target.value;
      updateLivePreview();
    });
  });

  container.querySelectorAll('.input-workshop-id').forEach(input => {
    input.addEventListener('input', (e) => {
      const idx = parseInt(input.dataset.index, 10);
      let val = e.target.value.trim();
      // Extrai ID automaticamente se o usuário colar o link inteiro
      if (val.includes('id=')) {
        val = val.split('id=')[1].split('&')[0];
      }
      builderModsList[idx].workshop_id = val;
      builderModsList[idx].id = val || `mod_${Date.now()}`;
      updateLivePreview();
    });
  });

  container.querySelectorAll('.input-download-url').forEach(input => {
    input.addEventListener('input', (e) => {
      const idx = parseInt(input.dataset.index, 10);
      builderModsList[idx].download_url = e.target.value.trim();
      updateLivePreview();
    });
  });

  container.querySelectorAll('.chk-required').forEach(chk => {
    chk.addEventListener('change', (e) => {
      const idx = parseInt(chk.dataset.index, 10);
      builderModsList[idx].required = e.target.checked;
      updateLivePreview();
    });
  });
}

function updateLivePreview() {
  const name = document.getElementById('builder-name')?.value || 'NOME DO MODPACK';
  const category = document.getElementById('builder-category')?.value || 'Militar';
  const version = document.getElementById('builder-version')?.value || '1.0.0';
  const zomboidVer = document.getElementById('builder-zomboid-ver')?.value || '42.0+';
  const bannerUrl = document.getElementById('builder-banner-url')?.value || 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80';
  const desc = document.getElementById('builder-desc')?.value || 'Descrição do modpack configurada pelo operador.';

  const user = getCurrentUser();
  const authorName = user?.user_metadata?.username || user?.email?.split('@')[0] || 'Seu Nick de Criador';

  const previewTitle = document.getElementById('preview-card-title');
  const previewAuthor = document.getElementById('preview-card-author');
  const previewDesc = document.getElementById('preview-card-desc');
  const previewBanner = document.getElementById('preview-card-banner');
  const previewTagVer = document.getElementById('preview-card-tag-ver');
  const previewTagB42 = document.getElementById('preview-card-tag-b42');
  const previewTotalMods = document.getElementById('preview-card-total-mods');
  const previewModsList = document.getElementById('preview-card-mods-list');

  if (previewTitle) previewTitle.textContent = name;
  if (previewAuthor) previewAuthor.textContent = authorName;
  if (previewDesc) previewDesc.textContent = desc;
  if (previewBanner) previewBanner.src = bannerUrl;
  if (previewTagVer) previewTagVer.textContent = `v${version}`;
  if (previewTagB42) previewTagB42.textContent = `BUILD ${zomboidVer}`;
  if (previewTotalMods) previewTotalMods.textContent = `${builderModsList.length} MODS INCLUSOS`;

  if (previewModsList) {
    previewModsList.innerHTML = builderModsList.slice(0, 4).map(m => `
      <div class="preview-mini-mod-row">
        <span>• ${m.name}</span>
        <span class="mini-tag">${m.mod_type === 'workshop' ? 'WORKSHOP' : (m.mod_type === 'builtin' ? 'VICCS' : 'ZIP')}</span>
      </div>
    `).join('') + (builderModsList.length > 4 ? `<div style="font-size: 10px; color: var(--accent-amber);">+ ${builderModsList.length - 4} outros mods...</div>` : '');
  }
}

async function handlePublishModpack() {
  const publishBtn = document.getElementById('btn-submit-publish');
  const publishStatus = document.getElementById('builder-publish-status');

  const name = document.getElementById('builder-name').value.trim();
  const category = document.getElementById('builder-category').value;
  const version = document.getElementById('builder-version').value.trim();
  const zomboidVer = document.getElementById('builder-zomboid-ver').value.trim();
  const bannerUrl = document.getElementById('builder-banner-url').value.trim();
  const description = document.getElementById('builder-desc').value.trim();

  const user = getCurrentUser();
  const authorName = user?.user_metadata?.username || user?.email?.split('@')[0] || 'Operador PZHub';

  if (!name || !description) {
    alert('Preencha o nome e a descrição do modpack.');
    return;
  }

  if (builderModsList.length === 0) {
    alert('Adicione pelo menos 1 mod à lista do pacote.');
    return;
  }

  if (publishBtn) publishBtn.disabled = true;
  if (publishStatus) publishStatus.textContent = 'PUBLICANDO NA NUVEM...';

  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-') + '-' + Math.floor(Math.random() * 1000);

  const modpackData = {
    slug,
    name,
    description,
    banner_url: bannerUrl,
    author_id: user?.id || null,
    author_name: authorName,
    version,
    zomboid_version: zomboidVer,
    category,
    is_public: true,
    mods: builderModsList
  };

  const result = await publishModpack(modpackData);

  if (publishBtn) publishBtn.disabled = false;

  if (result.success) {
    if (publishStatus) publishStatus.textContent = '✓ PUBLICADO COM SUCESSO!';
    showPublishSuccessModal(result.data);
  } else {
    if (publishStatus) publishStatus.textContent = `❌ Falha: ${result.error}`;
  }
}

function showPublishSuccessModal(modpack) {
  const modal = document.getElementById('publish-success-modal');
  const titleEl = document.getElementById('success-modpack-name');
  const syncLinkInput = document.getElementById('success-sync-link');
  const closeBtn = document.getElementById('btn-close-success-modal');

  if (titleEl) titleEl.textContent = modpack.name;
  if (syncLinkInput) {
    const rawUrl = `${window.location.origin}/api/modpack/${modpack.slug || modpack.id}`;
    syncLinkInput.value = rawUrl;
  }

  if (modal) modal.classList.add('visible');

  if (closeBtn && modal) {
    closeBtn.onclick = () => {
      modal.classList.remove('visible');
      window.location.hash = '#workshop';
      window.location.reload();
    };
  }
}
