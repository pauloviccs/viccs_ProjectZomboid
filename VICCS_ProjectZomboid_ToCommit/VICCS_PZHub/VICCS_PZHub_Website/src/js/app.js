/**
 * PZHub Website - Main App Orchestrator
 */

import { initAuth } from './auth.js';
import { initWorkshop } from './workshop.js';
import { initModpackBuilder } from './modpackBuilder.js';
import { saveApiCredentials, isConfigured } from './supabaseClient.js';

class WebsiteApp {
  constructor() {
    this.currentView = 'workshop';
  }

  async init() {
    this.setupNavigation();
    this.setupConfigModal();

    await initAuth();
    await initWorkshop();
    initModpackBuilder();

    // Roteamento inicial por Hash
    this.handleHashChange();
    window.addEventListener('hashchange', () => this.handleHashChange());
  }

  setupNavigation() {
    const navTabs = document.querySelectorAll('.site-nav-tab');
    navTabs.forEach(tab => {
      tab.addEventListener('click', () => {
        const view = tab.dataset.view;
        if (view) {
          window.location.hash = `#${view}`;
        }
      });
    });
  }

  handleHashChange() {
    const hash = window.location.hash.replace('#', '') || 'workshop';
    this.switchView(hash);
  }

  switchView(viewName) {
    this.currentView = viewName;

    // Atualiza tabs
    document.querySelectorAll('.site-nav-tab').forEach(tab => {
      tab.classList.toggle('active', tab.dataset.view === viewName);
    });

    // Atualiza sections
    document.querySelectorAll('.site-view').forEach(sec => {
      sec.classList.toggle('active', sec.id === `view-${viewName}`);
    });

    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  setupConfigModal() {
    const setupBtn = document.getElementById('btn-setup-supabase');
    const modal = document.getElementById('supabase-config-modal');
    const closeBtn = document.getElementById('config-modal-close');
    const form = document.getElementById('config-form');

    const statusBadge = document.getElementById('cloud-status-badge');
    if (statusBadge) {
      statusBadge.textContent = isConfigured ? 'SUPABASE CONECTADO' : 'MODO DEMO / OFFLINE';
      statusBadge.className = `tarkov-tag ${isConfigured ? 'badge-emerald' : 'badge-amber'}`;
    }

    if (setupBtn && modal) {
      setupBtn.addEventListener('click', () => {
        modal.classList.add('visible');
      });
    }

    if (closeBtn && modal) {
      closeBtn.addEventListener('click', () => {
        modal.classList.remove('visible');
      });
    }

    if (form) {
      form.addEventListener('submit', (e) => {
        e.preventDefault();
        const url = document.getElementById('config-supabase-url').value;
        const key = document.getElementById('config-supabase-key').value;
        if (url && key) {
          saveApiCredentials(url, key);
        }
      });
    }
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const app = new WebsiteApp();
  app.init();
});
