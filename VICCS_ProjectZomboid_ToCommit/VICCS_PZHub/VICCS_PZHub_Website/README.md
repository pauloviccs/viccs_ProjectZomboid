# PZHub Community Workshop & Creator Platform

Plataforma Web Oficial para Criação, Publicação e Sincronização de Modpacks do **Project Zomboid (Build 42 & Build 41)** com UI/UX inspirada em **Escape from Tarkov**.

---

## 🛠️ Stack Tecnológica (100% Gratuita)

- **Frontend:** Vite + Vanilla JS + HTML5 + CSS3 (Tarkov UI Design System)
- **Hospedagem & CDN:** Vercel (Free Tier)
- **Banco de Dados & Auth:** Supabase (PostgreSQL Gratuito + Auth + REST API)

---

## 🚀 Como Executar Localmente

1. Navegue até esta pasta:
   ```bash
   cd VICCS_PZHub/VICCS_PZHub_Website
   ```

2. Instale as dependências:
   ```bash
   npm install
   ```

3. Inicie o servidor de desenvolvimento:
   ```bash
   npm run dev
   ```

---

## ☁️ Como Configurar o Supabase & Vercel (100% Free)

1. Crie um projeto gratuito em [supabase.com](https://supabase.com).
2. Acesse o **SQL Editor** no painel do Supabase e execute o conteúdo do arquivo `supabase_schema.sql`.
3. No painel do Supabase, vá em **Project Settings $\rightarrow$ API** e copie:
   - `Project URL`
   - `anon public key`
4. Na plataforma web (ou na Vercel), configure as variáveis de ambiente:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
5. Para fazer deploy na Vercel:
   - Basta conectar este repositório no [vercel.com](https://vercel.com) e clicar em **Deploy**!
