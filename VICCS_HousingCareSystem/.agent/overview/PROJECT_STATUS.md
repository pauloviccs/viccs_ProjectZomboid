# Project Overview

## Project Name
Housing Care System (Lar Vivo) — Project Zomboid Build 42

## Description
Sistema completo e orgânico de avaliação de conforto e insalubridade de bases para o Project Zomboid Build 42 (42.20.x+), inspirado no sistema de Comfort do Valheim. Recompensa bases limpas, bem mobiliadas e organizadas com buffs acumulativos (Tiers 1 a 4 + Catálogo Estendido) e penaliza bases degradadas, imundas e com cadáveres (Squalor Tiers 1 a 4). Desenvolvido com Time-Slicing para zero lag, suporte nativo a saves em andamento (Mid-Save) e compatibilidade com Safehouses em servidores Multiplayer.

## Tech Stack
- Languages: Lua (Kahlua / PZ Java Lua 5.1 dialect)
- Frameworks / APIs: Project Zomboid B42 API (ISUI Panel, ModData, Events, IsoGridSquare, IsoRoom, Safehouse API)
- Tools: VSCode / Antigravity IDE, Git
- Services: Steam Workshop (target)

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
│   ├── memory/
│   │   ├── active_task.md
│   │   ├── changelog.md
│   │   └── todos.md
│   ├── overview/
│   │   └── PROJECT_STATUS.md
│   └── roadmap/
│       └── Context_HousingCareSystemMod.md
├── media/
│   ├── sandbox-options.txt
│   └── lua/
│       ├── shared/
│       │   ├── LV_Config.lua
│       │   ├── LV_ItemScoreData.lua
│       │   ├── LV_MoodleDefs.lua
│       │   ├── LV_ComfortScanner.lua
│       │   ├── LV_BuffManager.lua
│       │   └── Translate/
│       │       ├── PTBR/
│       │       │   ├── Sandbox_PTBR.txt
│       │       │   └── UI_PTBR.txt
│       │       └── EN/
│       │           ├── Sandbox_EN.txt
│       │           └── UI_EN.txt
│       └── client/
│           ├── LV_HUD.lua
│           └── LV_ClientEvents.lua
└── mod.info
```
