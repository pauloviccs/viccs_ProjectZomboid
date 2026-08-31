# Changelog

## [1.0.0] - 2026-08-31

### Adicionado
- **Arquitetura Base & Configuração:**
  - `LV_Config.lua` e `media/sandbox-options.txt` centralizando todas as variáveis de Sandbox com fallbacks seguros.
  - Opção `LV_RequireSafehouseClaim` para servidores dedicados no Multiplayer.
- **Scanner & Performance:**
  - `LV_ComfortScanner.lua` com Time-Slicing (10 tiles/frame no `Events.OnTick`), garantindo zero micro-stutter em bases grandes.
  - Reconhecimento automático de construções de carpintaria (`carpentry_01/02`) e cômodos vanilla.
  - Cálculo simultâneo de Conforto (0 a 100) e Squalor/Insalubridade (0 a 100).
  - Regra de precedência onde `Squalor >= 50` zera o Conforto.
- **Buffs & Debuffs:**
  - `LV_BuffManager.lua` gerenciando Tiers 1-4 de Conforto e Tiers 1-4 de Squalor.
  - Catálogo estendido com *Energizado*, *Aquecido*, *Saciado*, *Cicatrização Rápida* e *Alerta*.
  - Persistência universal no ModData via `getGameTime():getWorldAgeHours()`.
  - Resíduo de contaminação (1h) ao deixar bases imundas.
- **Interface & HUD:**
  - `LV_HUD.lua` com renderização vetorial nativa estilo The Sims / PZ 90s (Barra verde para conforto, avermelhada para sujeira).
  - Atalho de visibilidade configurado na tecla `K`.
- **Eventos & Mid-Save:**
  - `LV_ClientEvents.lua` com varredura imediata ao entrar no jogo (`Events.OnCreatePlayer`) e detecção de transição de cômodos.
- **Localização & Documentação:**
  - Traduções completas em `PTBR` e `EN`.
  - Especificação completa de assets e mídias em `.agent/assets/MEDIA_SPECIFICATIONS.md`.
  - Memória técnica sincronizada em `.agent/`.
