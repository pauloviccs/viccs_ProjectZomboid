# Project Overview

## Project Name
Housing Care System (Lar Vivo) — Project Zomboid Build 42

## Description
Sistema completo, orgânico e imersivo de avaliação de conforto, habitabilidade e insalubridade de bases para o **Project Zomboid Build 42** (42.20.x+), inspirado na mecânica de Conforto do *Valheim*. 

O mod avalia minuciosamente o ambiente onde o sobrevivente reside:
- **Conforto (Tiers 1 a 4 + Catálogo Estendido):** Recompensa bases limpas, decoradas, iluminadas e bem mobiliadas com buffs de redução de estresse, tédio, fadiga, dor e bônus de sono reparador.
- **Insalubridade / Squalor (Tiers 1 a 4):** Penaliza bases degradadas, sujas de sangue/lixo e com cadáveres com debuffs de estresse, náusea e tédio.
- **Sono Reparador (Sleep Revitalize):** Sistema que detecta qualidade de sono (travesseiros no inventário/cama, tipo de leito, conforto do cômodo) para conceder o buff *Revigorado* ao acordar.
- **Performance & Time-Slicing:** Scanner distribuído em fatias temporais (10 tiles/frame) garantindo 0 impacto no FPS.
- **Multiplayer & Mid-Save:** Suporte integral a servidores dedicados com verificação de Safehouse (`LV_RequireSafehouseClaim`) e integração 100% segura para saves em andamento sem risco de corrupção.

## Tech Stack
- Languages: Lua 5.1 (Kahlua / Project Zomboid Java-Lua Bridge), Python 3 (Assets automation)
- Frameworks / APIs: Project Zomboid B42 API (`ISUIElement`, `ISPanel`, `ModData`, `Events`, `IsoGridSquare`, `IsoRoom`, `Safehouse`, `HaloTextHelper`)
- Tools: VSCode / Antigravity IDE, LuaLS (`.luarc.json`), Pillow / Python (`generate_moodles.py`), Git
- Services / Platforms: Steam Workshop (target Build 42)

## Folder Structure
```text
VICCS_HousingCareSystem/
├── .agent/
│   ├── assets/
│   │   └── MEDIA_SPECIFICATIONS.md
│   ├── context/
│   │   ├── architecture.md
│   │   ├── moodles_catalog.md
│   │   └── stack.md
│   ├── logs/
│   ├── memory/
│   │   ├── active_task.md
│   │   ├── changelog.md
│   │   └── todos.md
│   ├── overview/
│   │   └── PROJECT_STATUS.md
│   └── roadmap/
│       └── Context_HousingCareSystemMod.md
├── 42/                                  # Compatibilidade de workshop B42
│   ├── icon.png
│   ├── mod.info
│   ├── poster.png
│   └── media/
├── 42.0/                                # Compatibilidade de workshop B42.0
│   ├── icon.png
│   ├── mod.info
│   ├── poster.png
│   └── media/
├── common/                              # Fallback legado para versões comuns
│   ├── icon.png
│   ├── mod.info
│   ├── poster.png
│   └── media/
├── media/
│   ├── sandbox-options.txt              # Opções completas de Sandbox integradas
│   ├── ui/
│   │   └── Moodles/                     # Ícones PNG de moodlets (Comfort 1-4 & Squalor 1-4)
│   │       ├── LV_Comfort_1.png ... LV_Comfort_4.png
│   │       └── LV_Squalor_1.png ... LV_Squalor_4.png
│   └── lua/
│       ├── shared/
│       │   ├── LV_Config.lua            # Configurações padrão, thresholds e timers
│       │   ├── LV_ItemScoreData.lua     # Catálogo de pontuação por Tags, tipos e IsoFlags
│       │   ├── LV_MoodleDefs.lua        # Definições estruturais de Moodlets e cores
│       │   ├── LV_ComfortScanner.lua    # Scanner assíncrono com Time-Slicing e algoritmo de flood-fill de sala
│       │   ├── LV_BuffManager.lua       # Gerenciador de aplicação/remoção de buffs e persistência universal
│       │   └── Translate/               # Localização em 5 idiomas
│       │       ├── CH/ (Sandbox_CH.txt, UI_CH.txt)
│       │       ├── CN/ (Sandbox_CN.txt, UI_CN.txt)
│       │       ├── EN/ (Sandbox_EN.txt, UI_EN.txt)
│       │       ├── ES/ (Sandbox_ES.txt, UI_ES.txt)
│       │       └── PTBR/ (Sandbox_PTBR.txt, UI_PTBR.txt)
│       └── client/
│           ├── LV_ClientEvents.lua      # Handlers de inicialização, eventos de pulso horário e troca de cômodo
│           ├── LV_HUD.lua               # Painel ISUI de diagnóstico/depuração com toggle na tecla 'K'
│           ├── LV_MoodleUI.lua          # Renderizador de moodlets na lateral direita da tela (alinhamento nativo com vanilla)
│           └── LV_SleepRevitalize.lua   # Sistema de sono reparador e verificação de travesseiro/leito
├── .luarc.json                          # Configurações de tipagem e diagnósticos LuaLS
├── generate_moodles.py                  # Script Python utilitário para compilar ícones de moodlets
├── icon.png                             # Ícone do mod
├── poster.png                           # Arte de capa do mod
└── mod.info                             # Metadados de registro do mod
```

## Current Features Implemented
1. **Core Scoring & Detection System:**
   - Detecção de cômodos fechados (`IsoRoom`), interiores e estruturas de carpintaria construídas por jogadores.
   - Pontuação por categorias: Iluminação natural/artificial, Mobília de descanso (camas, poltronas), Decoração (quadros, tapetes, cortinas), Entretenimento (rádio, TV, jukebox), Higiene e Conforto Térmico.
   - Detecção de insalubridade: Cadáveres, poças de sangue, sujeira/fuligem, lixo e comida estragada no chão.
   - Precedência de Squalor: Níveis críticos de sujeira/cadáveres suprimem completamente os benefícios de conforto.

2. **Async Time-Slicing Scanner:**
   - Varredura de grids distribuída em múltiplos frames (10 tiles por tick) eliminando congelamentos ou stuttering.

3. **Status Life-Cycle & Buff Engine:**
   - Aplicação orgânica e contínua de modificadores de status nos sobreviventes baseada em tempo de permanência e carência de saída (`Buffer Time`).
   - Persistência à prova de desyncs com `getWorldAgeHours()` no `ModData` do jogador.

4. **Native UI & Moodles:**
   - `LV_MoodleUI`: Exibição visual de moodlet na coluna lateral direita da HUD oficial, posicionando-se abaixo dos moodlets ativos do jogo com tooltips descritivos.
   - `LV_HUD`: Painel flutuante de inspeção detalhada do ambiente ativado/desativado com a tecla **`K`**.
   - Conjunto completo de ícones de moodlet (Comfort Tiers 1-4 e Squalor Tiers 1-4) compilados em `media/ui/Moodles/`.

5. **Mecânica de Sono Reparador (Sleep Revitalize):**
   - Rastreamento do ciclo de sono; detecta se o sobrevivente dormiu 6+ horas com travesseiro (no inventário, mãos ou superfície da cama) em ambiente confortável para zerar tédio/tristeza/estresse e aplicar vigor extra.

6. **Customização & Internacionalização:**
   - Todas as variáveis ajustáveis via Sandbox (`sandbox-options.txt`).
   - Suporte completo a 5 idiomas: Português (`PTBR`), Inglês (`EN`), Espanhol (`ES`), Chinês Tradicional (`CH`) e Chinês Simplificado (`CN`).

## Work-in-Progress & Next Steps
- [ ] Validação prática em testes de stress em sessão in-game (Singleplayer e Servidor Dedicado Multiplayer).
- [ ] Ajuste fino do balanceamento dos valores de pontuação de mobília modded/especial.
- [ ] Empacotamento final e publicação oficial na Steam Workshop.
