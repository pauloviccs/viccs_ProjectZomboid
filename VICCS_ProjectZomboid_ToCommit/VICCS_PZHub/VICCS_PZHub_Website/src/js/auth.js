/**
 * PZHub - Authentication Module (Supabase Auth)
 */

import { supabase, isConfigured } from './supabaseClient.js';

let currentUser = null;

export async function initAuth() {
  const authBtn = document.getElementById('nav-auth-btn');
  const authModal = document.getElementById('auth-modal');
  const authCloseBtn = document.getElementById('auth-modal-close');
  const authForm = document.getElementById('auth-form');
  const toggleAuthModeBtn = document.getElementById('btn-toggle-auth-mode');
  const logoutBtn = document.getElementById('nav-logout-btn');

  let isRegisterMode = false;

  if (isConfigured) {
    const { data: { session } } = await supabase.auth.getSession();
    currentUser = session?.user || null;

    supabase.auth.onAuthStateChange((_event, session) => {
      currentUser = session?.user || null;
      updateAuthUI();
    });
  } else {
    // Modo simulação local
    const savedLocalUser = localStorage.getItem('PZHUB_DEMO_USER');
    if (savedLocalUser) currentUser = JSON.parse(savedLocalUser);
  }

  updateAuthUI();

  if (authBtn) {
    authBtn.addEventListener('click', () => {
      if (currentUser) {
        // Redireciona para o Creator Studio
        window.location.hash = '#studio';
      } else {
        if (authModal) authModal.classList.add('visible');
      }
    });
  }

  if (authCloseBtn && authModal) {
    authCloseBtn.addEventListener('click', () => {
      authModal.classList.remove('visible');
    });
  }

  if (toggleAuthModeBtn) {
    toggleAuthModeBtn.addEventListener('click', () => {
      isRegisterMode = !isRegisterMode;
      const titleEl = document.getElementById('auth-modal-title');
      const submitBtn = document.getElementById('auth-submit-btn');
      const usernameGroup = document.getElementById('auth-username-group');

      if (titleEl) titleEl.textContent = isRegisterMode ? 'CADASTRO DE OPERADOR' : 'AUTENTICAÇÃO TÁTICA';
      if (submitBtn) submitBtn.textContent = isRegisterMode ? 'CRIAR CONTA DE CRIADOR' : 'ENTRAR NO PZHUB';
      if (usernameGroup) usernameGroup.style.display = isRegisterMode ? 'block' : 'none';
      toggleAuthModeBtn.textContent = isRegisterMode ? 'Já possui conta? Faça Login' : 'Não tem conta? Cadastre-se como Criador';
    });
  }

  if (authForm) {
    authForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = document.getElementById('auth-email').value.trim();
      const password = document.getElementById('auth-password').value.trim();
      const username = document.getElementById('auth-username')?.value.trim() || email.split('@')[0];
      const statusMsg = document.getElementById('auth-status-msg');

      if (statusMsg) statusMsg.textContent = 'Processando...';

      if (isConfigured) {
        try {
          if (isRegisterMode) {
            const { data, error } = await supabase.auth.signUp({
              email,
              password,
              options: { data: { username } }
            });
            if (error) throw error;
            currentUser = data.user;
            if (statusMsg) statusMsg.textContent = 'Cadastro realizado com sucesso!';
          } else {
            const { data, error } = await supabase.auth.signInWithPassword({
              email,
              password
            });
            if (error) throw error;
            currentUser = data.user;
          }
          if (authModal) authModal.classList.remove('visible');
          updateAuthUI();
        } catch (err) {
          if (statusMsg) statusMsg.textContent = `Erro: ${err.message}`;
        }
      } else {
        // Simulação instantânea
        currentUser = {
          id: 'demo-user-1',
          email,
          user_metadata: { username }
        };
        localStorage.setItem('PZHUB_DEMO_USER', JSON.stringify(currentUser));
        if (authModal) authModal.classList.remove('visible');
        updateAuthUI();
      }
    });
  }

  if (logoutBtn) {
    logoutBtn.addEventListener('click', async () => {
      if (isConfigured) {
        await supabase.auth.signOut();
      }
      currentUser = null;
      localStorage.removeItem('PZHUB_DEMO_USER');
      updateAuthUI();
      window.location.hash = '#workshop';
    });
  }
}

export function getCurrentUser() {
  return currentUser;
}

function updateAuthUI() {
  const authBtn = document.getElementById('nav-auth-btn');
  const userProfileStrip = document.getElementById('nav-user-profile');
  const userNameEl = document.getElementById('nav-username');

  if (currentUser) {
    if (authBtn) authBtn.style.display = 'none';
    if (userProfileStrip) userProfileStrip.style.display = 'flex';
    if (userNameEl) {
      userNameEl.textContent = currentUser.user_metadata?.username || currentUser.email?.split('@')[0] || 'Operador';
    }
  } else {
    if (authBtn) authBtn.style.display = 'flex';
    if (userProfileStrip) userProfileStrip.style.display = 'none';
  }
}
