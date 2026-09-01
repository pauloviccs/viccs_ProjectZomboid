/**
 * VICCS_PZMap - Gerenciador de Lista de Amigos e Destaque Tático no Mapa
 */

export class FriendsManager {
  constructor(mapEngine, squadTracker, containerId) {
    this.mapEngine = mapEngine;
    this.squadTracker = squadTracker;
    this.container = document.getElementById(containerId);
    this.friends = [];
    this.isTauri = typeof window.__TAURI__ !== 'undefined';
  }

  async init() {
    await this.loadFriends();
    this.setupForm();
    this.render();
    return this;
  }

  async loadFriends() {
    if (this.isTauri && window.__TAURI__?.core?.invoke) {
      try {
        this.friends = await window.__TAURI__.core.invoke('get_friends');
      } catch (err) {
        console.warn('Erro ao carregar amigos do Rust:', err);
        this.loadLocal();
      }
    } else {
      this.loadLocal();
    }
  }

  loadLocal() {
    try {
      const stored = localStorage.getItem('viccs_friends_list');
      this.friends = stored ? JSON.parse(stored) : [];
    } catch {
      this.friends = [];
    }
  }

  async saveFriends() {
    try {
      localStorage.setItem('viccs_friends_list', JSON.stringify(this.friends));
    } catch (e) {
      console.warn(e);
    }
  }

  setupForm() {
    const btnAdd = document.getElementById('btn-add-friend');
    const inputName = document.getElementById('input-friend-name');
    const inputNick = document.getElementById('input-friend-nick');
    const selectColor = document.getElementById('select-friend-color');

    if (btnAdd && inputName) {
      btnAdd.addEventListener('click', async () => {
        const username = inputName.value.trim();
        const nickname = inputNick ? inputNick.value.trim() : '';
        const color = selectColor ? selectColor.value : '#ffdd59';

        if (!username) return;

        const newFriend = {
          username,
          nickname: nickname || null,
          steam_id: null,
          color,
        };

        if (this.isTauri && window.__TAURI__?.core?.invoke) {
          try {
            this.friends = await window.__TAURI__.core.invoke('add_friend', { friend: newFriend });
          } catch (err) {
            this.addLocal(newFriend);
          }
        } else {
          this.addLocal(newFriend);
        }

        inputName.value = '';
        if (inputNick) inputNick.value = '';
        this.render();
        this.squadTracker.setFriendsList(this.friends);
      });
    }
  }

  addLocal(friend) {
    this.friends = this.friends.filter((f) => f.username.toLowerCase() !== friend.username.toLowerCase());
    this.friends.push(friend);
    this.saveFriends();
  }

  async removeFriend(username) {
    if (this.isTauri && window.__TAURI__?.core?.invoke) {
      try {
        this.friends = await window.__TAURI__.core.invoke('remove_friend', { username });
      } catch (err) {
        this.friends = this.friends.filter((f) => f.username.toLowerCase() !== username.toLowerCase());
        this.saveFriends();
      }
    } else {
      this.friends = this.friends.filter((f) => f.username.toLowerCase() !== username.toLowerCase());
      this.saveFriends();
    }
    this.render();
    this.squadTracker.setFriendsList(this.friends);
  }

  render() {
    if (!this.container) return;

    if (this.friends.length === 0) {
      this.container.innerHTML = `
        <div style="text-align: center; color: var(--text-dim); padding: 14px 0; font-size: 11px; line-height: 1.5;">
          Nenhum amigo adicionado ainda.<br>Adicione o <strong>Nick do Project Zomboid</strong> do seu amigo acima para rastreá-lo com destaque no radar!
        </div>
      `;
      return;
    }

    const onlinePlayers = this.squadTracker.players || [];
    let html = '';

    this.friends.forEach((friend) => {
      // Verifica se o amigo está atualmente online no jogo
      const detected = onlinePlayers.find(
        (p) => p.name.toLowerCase() === friend.username.toLowerCase() && !p.is_self
      );

      const isOnline = !!detected;
      const displayName = friend.nickname ? `${friend.nickname} (${friend.username})` : friend.username;

      let statusHtml = '';
      let actionButtons = '';

      if (isOnline) {
        const dist = Math.round(
          Math.hypot(
            detected.x - (this.squadTracker.selfPlayer ? this.squadTracker.selfPlayer.x : 0),
            detected.y - (this.squadTracker.selfPlayer ? this.squadTracker.selfPlayer.y : 0)
          )
        );

        statusHtml = `
          <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 4px;">
            <span style="font-size: 10px; color: var(--accent-green); font-weight: 700;">🟢 ONLINE NO RADAR</span>
            <span style="font-family: var(--font-mono); font-size: 10px; color: #ffdd59;">${dist}m de você</span>
          </div>
          <div style="font-family: var(--font-mono); font-size: 9px; color: var(--text-muted); margin-top: 2px;">
            X: ${Math.round(detected.x)} | Y: ${Math.round(detected.y)} | Andar: ${detected.z}
          </div>
        `;

        actionButtons = `
          <button class="friend-gps-btn" data-x="${detected.x}" data-y="${detected.y}" data-name="${displayName}" title="Traçar rota GPS até seu amigo">
            🧭 GPS
          </button>
        `;
      } else {
        statusHtml = `
          <div style="font-size: 10px; color: var(--text-dim); margin-top: 4px;">
            ⚪ Não detectado no servidor no momento
          </div>
        `;
      }

      html += `
        <div class="friend-card" style="border-left: 3px solid ${friend.color};">
          <div style="display: flex; justify-content: space-between; align-items: flex-start;">
            <div style="display: flex; align-items: center; gap: 6px;">
              <span style="font-size: 12px; color: ${friend.color};">⭐</span>
              <span class="friend-card-name">${displayName}</span>
            </div>
            <div style="display: flex; align-items: center; gap: 6px;">
              ${actionButtons}
              <button class="friend-remove-btn" data-user="${friend.username}" title="Remover amigo">
                ✖
              </button>
            </div>
          </div>
          ${statusHtml}
        </div>
      `;
    });

    this.container.innerHTML = html;

    // Listeners para botões de remoção
    this.container.querySelectorAll('.friend-remove-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const username = btn.getAttribute('data-user');
        this.removeFriend(username);
      });
    });

    // Listeners para botões de GPS
    this.container.querySelectorAll('.friend-gps-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const x = parseFloat(btn.getAttribute('data-x'));
        const y = parseFloat(btn.getAttribute('data-y'));
        const name = btn.getAttribute('data-name');
        this.mapEngine.setGpsDestination(x, y, `Amigo: ${name}`);
      });
    });
  }
}
