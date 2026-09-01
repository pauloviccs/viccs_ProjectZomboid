/**
 * VICCS_PZMap - Gerenciador de Janela, Overlay e Atalhos de Teclado
 */

export class OverlayController {
  constructor(mapEngine, squadTracker) {
    this.mapEngine = mapEngine;
    this.squadTracker = squadTracker;
    this.alwaysOnTop = false;
    this.opacity = 1.0;
    this.isTauri = typeof window.__TAURI__ !== 'undefined';
  }

  init() {
    this.setupKeyboardShortcuts();
    this.setupWindowControls();
    return this;
  }

  setupWindowControls() {
    // 1. Controle Deslizante de Opacidade
    const opacitySlider = document.getElementById('opacity-slider');
    const opacityVal = document.getElementById('opacity-val');
    if (opacitySlider) {
      opacitySlider.addEventListener('input', (e) => {
        const val = parseFloat(e.target.value);
        this.opacity = val;
        document.body.style.opacity = `${val}`;
        if (opacityVal) opacityVal.textContent = `${Math.round(val * 100)}%`;
      });
    }

    // 2. Botão Always on Top
    const btnPin = document.getElementById('btn-always-on-top');
    if (btnPin) {
      btnPin.addEventListener('click', async () => {
        this.alwaysOnTop = !this.alwaysOnTop;
        btnPin.classList.toggle('active', this.alwaysOnTop);

        if (this.isTauri && window.__TAURI__?.core?.invoke) {
          try {
            await window.__TAURI__.core.invoke('set_always_on_top', {
              enabled: this.alwaysOnTop,
            });
          } catch (err) {
            console.warn('Erro ao definir always on top:', err);
          }
        }
      });
    }

    // 3. Botão Centralizar em Mim
    const btnCenter = document.getElementById('btn-center-self');
    if (btnCenter) {
      btnCenter.addEventListener('click', () => {
        this.squadTracker.centerOnSelf();
      });
    }

    // 4. Botão Seguir Jogador
    const btnFollow = document.getElementById('btn-follow-toggle') || document.getElementById('btn-follow-self');
    if (btnFollow) {
      btnFollow.addEventListener('click', () => {
        const isFollowing = this.squadTracker.toggleFollowSelf();
        btnFollow.classList.toggle('active', isFollowing);
        const label = document.getElementById('follow-label');
        if (label) {
          label.textContent = isFollowing ? 'SEGUINDO JOGADOR' : 'SEGUIR JOGADOR';
        }
      });
    }

    // 5. Botão Alternar Painel Lateral
    const sidebar = document.querySelector('.tactical-sidebar');
    const toggleBtn = document.getElementById('sidebar-toggle');
    if (sidebar && toggleBtn) {
      toggleBtn.addEventListener('click', () => {
        sidebar.classList.toggle('collapsed');
      });
    }
  }

  setupKeyboardShortcuts() {
    window.addEventListener('keydown', (e) => {
      // Ignora se estiver digitando em inputs
      if (['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;

      switch (e.code) {
        case 'Space':
          e.preventDefault();
          this.squadTracker.centerOnSelf();
          break;

        case 'F10':
          e.preventDefault();
          const sidebar = document.querySelector('.tactical-sidebar');
          const header = document.querySelector('.tactical-header');
          if (sidebar) sidebar.classList.toggle('collapsed');
          if (header) header.style.display = header.style.display === 'none' ? 'flex' : 'none';
          break;

        case 'Digit1':
        case 'Digit2':
        case 'Digit3':
        case 'Digit4':
        case 'Digit5':
        case 'Digit6':
        case 'Digit7':
          const zoomLevel = parseInt(e.code.replace('Digit', ''), 10);
          this.mapEngine.map.setZoom(zoomLevel);
          break;

        case 'BracketLeft': // Andar abaixo
          if (this.mapEngine.currentFloor > -1) {
            this.mapEngine.setFloor(this.mapEngine.currentFloor - 1);
            this.updateFloorButtonsUI();
          }
          break;

        case 'BracketRight': // Andar acima
          if (this.mapEngine.currentFloor < 15) {
            this.mapEngine.setFloor(this.mapEngine.currentFloor + 1);
            this.updateFloorButtonsUI();
          }
          break;
      }
    });
  }

  updateFloorButtonsUI() {
    document.querySelectorAll('.z-level-btn').forEach((btn) => {
      const floor = parseInt(btn.getAttribute('data-floor'), 10);
      btn.classList.toggle('active', floor === this.mapEngine.currentFloor);
    });
    const readout = document.getElementById('telemetry-floor');
    if (readout) readout.textContent = `${this.mapEngine.currentFloor}`;
  }
}
