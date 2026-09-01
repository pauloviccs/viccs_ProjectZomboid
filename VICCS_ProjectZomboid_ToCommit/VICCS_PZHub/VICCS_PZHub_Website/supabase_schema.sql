-- ==============================================================================
-- PZHub Community Workshop & Creator Platform - Supabase PostgreSQL Schema
-- Execute este script no SQL Editor do seu projeto Supabase (100% Gratuito)
-- ==============================================================================

-- 1. Criação da Tabela de Perfis de Usuários/Criadores
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  avatar_url text,
  discord_tag text,
  bio text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Criação da Tabela Principal de Modpacks
create table if not exists public.modpacks (
  id uuid default gen_random_uuid() primary key,
  slug text unique not null,
  name text not null,
  description text not null,
  banner_url text default 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80',
  author_id uuid references public.profiles(id) on delete set null,
  author_name text not null default 'Operador PZHub',
  version text not null default '1.0.0',
  zomboid_version text not null default '42.0+',
  category text not null default 'Militar',
  is_public boolean not null default true,
  downloads_count integer not null default 0,
  likes_count integer not null default 0,
  mods jsonb not null default '[]'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Habilitar Segurança por Linha (Row Level Security - RLS)
alter table public.profiles enable row level security;
alter table public.modpacks enable row level security;

-- Políticas de Acesso para Perfis
create policy "Perfis são visíveis publicamente"
  on public.profiles for select
  using (true);

create policy "Usuários podem criar seu próprio perfil"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Usuários podem atualizar seu próprio perfil"
  on public.profiles for update
  using (auth.uid() = id);

-- Políticas de Acesso para Modpacks
create policy "Modpacks públicos são visíveis para qualquer pessoa"
  on public.modpacks for select
  using (is_public = true);

create policy "Usuários autenticados podem criar modpacks"
  on public.modpacks for insert
  with check (auth.uid() = author_id);

create policy "Criadores podem atualizar seus próprios modpacks"
  on public.modpacks for update
  using (auth.uid() = author_id);

create policy "Criadores podem excluir seus próprios modpacks"
  on public.modpacks for delete
  using (auth.uid() = author_id);

-- 4. Função e Trigger para Auto-criar Perfil após Cadastro no Auth
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'avatar_url', 'https://api.dicebear.com/7.x/bottts/svg?seed=' || new.id)
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 5. Inserção de Modpacks Oficiais de Demonstração
insert into public.modpacks (slug, name, description, banner_url, author_name, version, zomboid_version, category, downloads_count, likes_count, mods)
values
(
  'viccs-tactical-b42',
  'VICCS TACTICAL OPERATIONS PACK (B42)',
  'Modpack oficial militar e balanceado para Project Zomboid Build 42. Contém radar de esquadrão com telemetria ao vivo, veículos militares blindados autênticos dos anos 90, uniformes camuflados e armas balísticas.',
  'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80',
  'VICCS Tactical Command',
  '1.4.0',
  '42.0+',
  'Militar',
  1420,
  388,
  '[
    {"id": "VICCSRadarBridge", "name": "VICCS Radar Bridge (B42 Native)", "mod_type": "builtin", "required": true, "description": "Módulo Lua transmissor de telemetria para o Radar Tático"},
    {"id": "1510950729", "name": "Filibuster Rhymes'' Used Cars! B42", "mod_type": "workshop", "workshop_id": "1510950729", "required": true, "description": "Veículos militares e civis realistas"},
    {"id": "CustomMilitaryGear", "name": "VICCS Custom Military Gear Pack", "mod_type": "builtin", "required": false, "description": "Uniformes, mochilas e coletes balísticos"}
  ]'::jsonb
),
(
  'vanilla-plus-qol-b42',
  'VANILLA+ QUALITY OF LIFE & EXPANSION',
  'Coleção essencial para quem quer a experiência original do Zomboid B42 aprimorada. Inclui leitura de mapa avançada, indicadores de status imersivos e sons de passos táticos.',
  'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80',
  'Survivor Alliance',
  '2.1.0',
  '42.0+',
  'Hardcore',
  890,
  245,
  '[
    {"id": "VICCSRadarBridge", "name": "VICCS Radar Bridge", "mod_type": "builtin", "required": true, "description": "Radar integrado"},
    {"id": "2392709985", "name": "Minimal Display Bars", "mod_type": "workshop", "workshop_id": "2392709985", "required": true, "description": "Barras sutis de status do personagem"}
  ]'::jsonb
),
(
  'apocalypse-roleplay-heavy',
  'OVERHAUL APOCALIPSE TOTAL (B41 & B42)',
  'Experiência brutal de sobrevivência para servidores de facção. Hordas inteligentes, escassez severa de loot e clima radioativo com tempestades ácidas.',
  'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=1200&q=80',
  'Knox County Outpost',
  '1.0.5',
  '42.0+',
  'Roleplay',
  2105,
  512,
  '[
    {"id": "VICCSRadarBridge", "name": "VICCS Radar Bridge", "mod_type": "builtin", "required": true, "description": "Transmissor do Radar PZHub"},
    {"id": "2703664356", "name": "True Actions (Dancing & Sitting)", "mod_type": "workshop", "workshop_id": "2703664356", "required": false, "description": "Animações e interações sociais imersivas"}
  ]'::jsonb
)
on conflict (slug) do nothing;
