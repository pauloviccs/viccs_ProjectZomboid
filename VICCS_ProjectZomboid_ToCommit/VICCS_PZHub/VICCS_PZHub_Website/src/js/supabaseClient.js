/**
 * PZHub - Supabase Client & Data Layer
 * Gerencia conexão com Supabase ou modo fallback local com dados demonstrativos em caso de chaves pendentes.
 */

import { createClient } from '@supabase/supabase-js';

// Configuração padrão ou lida das variáveis de ambiente / localStorage
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || localStorage.getItem('PZHUB_SUPABASE_URL') || 'https://demo-pzhub.supabase.co';
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || localStorage.getItem('PZHUB_SUPABASE_ANON_KEY') || 'demo-anon-key';

export const isConfigured = Boolean(
  import.meta.env.VITE_SUPABASE_URL || (localStorage.getItem('PZHUB_SUPABASE_URL') && localStorage.getItem('PZHUB_SUPABASE_ANON_KEY'))
);

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Catálogo demonstrativo para quando não houver backend conectado ainda
const MOCK_MODPACKS = [
  {
    id: "viccs-tactical-b42",
    slug: "viccs-tactical-b42",
    name: "VICCS TACTICAL OPERATIONS PACK (B42)",
    description: "Modpack militar e balanceado oficial para Project Zomboid Build 42. Contém radar de esquadrão com telemetria ao vivo, veículos blindados dos anos 90, uniformes camuflados e armas balísticas.",
    banner_url: "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80",
    author_name: "VICCS Tactical Command",
    version: "1.4.0",
    zomboid_version: "42.0+",
    category: "Militar",
    downloads_count: 1420,
    likes_count: 388,
    mods: [
      { id: "VICCSRadarBridge", name: "VICCS Radar Bridge (B42 Native)", mod_type: "builtin", required: true, description: "Transmissor de telemetria para o Radar PZHub" },
      { id: "1510950729", name: "Filibuster Rhymes' Used Cars! B42", mod_type: "workshop", workshop_id: "1510950729", required: true, description: "Veículos militares e civis realistas" },
      { id: "CustomMilitaryGear", name: "VICCS Custom Military Gear Pack", mod_type: "builtin", required: false, description: "Uniformes, mochilas e coletes balísticos" }
    ]
  },
  {
    id: "vanilla-plus-qol-b42",
    slug: "vanilla-plus-qol-b42",
    name: "VANILLA+ QUALITY OF LIFE & EXPANSION",
    description: "Coleção essencial para quem quer a experiência original do Zomboid B42 aprimorada. Inclui leitura de mapa avançada, indicadores sutis de status e melhorias de áudio.",
    banner_url: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80",
    author_name: "Survivor Alliance",
    version: "2.1.0",
    zomboid_version: "42.0+",
    category: "Hardcore",
    downloads_count: 890,
    likes_count: 245,
    mods: [
      { id: "VICCSRadarBridge", name: "VICCS Radar Bridge", mod_type: "builtin", required: true, description: "Radar integrado" },
      { id: "2392709985", name: "Minimal Display Bars", mod_type: "workshop", workshop_id: "2392709985", required: true, description: "Barras sutis de status do personagem" }
    ]
  },
  {
    id: "apocalypse-roleplay-heavy",
    slug: "apocalypse-roleplay-heavy",
    name: "OVERHAUL APOCALIPSE TOTAL (B41 & B42)",
    description: "Experiência brutal de sobrevivência para servidores de facção. Hordas inteligentes, escassez severa de loot, clima radioativo e interações sociais completas.",
    banner_url: "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=1200&q=80",
    author_name: "Knox County Outpost",
    version: "1.0.5",
    zomboid_version: "42.0+",
    category: "Roleplay",
    downloads_count: 2105,
    likes_count: 512,
    mods: [
      { id: "VICCSRadarBridge", name: "VICCS Radar Bridge", mod_type: "builtin", required: true, description: "Transmissor do Radar PZHub" },
      { id: "2703664356", name: "True Actions (Dancing & Sitting)", mod_type: "workshop", workshop_id: "2703664356", required: false, description: "Animações sociais e sentar em cadeiras" }
    ]
  }
];

export async function fetchCommunityModpacks({ category = 'all', searchQuery = '', sortBy = 'downloads' } = {}) {
  if (isConfigured) {
    try {
      let query = supabase
        .from('modpacks')
        .select('*')
        .eq('is_public', true);

      if (category !== 'all') {
        query = query.eq('category', category);
      }

      if (searchQuery) {
        query = query.ilike('name', `%${searchQuery}%`);
      }

      if (sortBy === 'downloads') query = query.order('downloads_count', { ascending: false });
      else if (sortBy === 'likes') query = query.order('likes_count', { ascending: false });
      else query = query.order('created_at', { ascending: false });

      const { data, error } = await query;
      if (error) throw error;
      if (data && data.length > 0) return data;
    } catch (err) {
      console.warn('Erro ao consultar Supabase, usando dados locais de fallback:', err);
    }
  }

  // Fallback em memória
  let localData = JSON.parse(localStorage.getItem('PZHUB_LOCAL_MODPACKS')) || MOCK_MODPACKS;

  return localData.filter(pack => {
    if (category !== 'all' && pack.category !== category) return false;
    if (searchQuery) {
      const matchName = pack.name.toLowerCase().includes(searchQuery.toLowerCase());
      const matchDesc = pack.description.toLowerCase().includes(searchQuery.toLowerCase());
      return matchName || matchDesc;
    }
    return true;
  });
}

export async function publishModpack(modpackData) {
  if (isConfigured) {
    try {
      const { data, error } = await supabase
        .from('modpacks')
        .insert([modpackData])
        .select();

      if (error) throw error;
      return { success: true, data: data[0] };
    } catch (err) {
      console.error('Falha ao publicar no Supabase:', err);
      return { success: false, error: err.message };
    }
  }

  // Gravação local caso Supabase não esteja configurado
  let localData = JSON.parse(localStorage.getItem('PZHUB_LOCAL_MODPACKS')) || [...MOCK_MODPACKS];
  const newPack = {
    ...modpackData,
    id: `modpack-${Date.now()}`,
    slug: modpackData.name.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
    downloads_count: 0,
    likes_count: 0,
    created_at: new Date().toISOString()
  };
  localData.unshift(newPack);
  localStorage.setItem('PZHUB_LOCAL_MODPACKS', JSON.stringify(localData));
  return { success: true, data: newPack };
}

export function saveApiCredentials(url, anonKey) {
  localStorage.setItem('PZHUB_SUPABASE_URL', url.trim());
  localStorage.setItem('PZHUB_SUPABASE_ANON_KEY', anonKey.trim());
  window.location.reload();
}
