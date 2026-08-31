# Tech Stack & Ambiente — Housing Care System

## 1. Engine & Plataforma
- **Jogo-Alvo:** Project Zomboid Build 42 (42.20.x Stable).
- **Linguagem:** Lua 5.1 (Dialeto Kahlua para Java).
- **Ambiente:** Singleplayer e Multiplayer Dedicado.

## 2. APIs e Subsistemas do Jogo Utilizados
- **Engine de UI:** `ISPanel` / `ISUI` para renderização de HUD nativo.
- **Persistência de Dados:** `ModData` acoplado ao `IsoPlayer`.
- **Relógio de Jogo:** `getGameTime():getWorldAgeHours()`.
- **Grid do Mundo:** `IsoGridSquare`, `IsoRoom`, `IsoWorldInventoryObject`, `IsoLightSwitch`.
- **Multiplayer:** `Safehouse.getSafehouse(square)`.
- **Configuração:** `SandboxVars` via `sandbox-options.txt`.
