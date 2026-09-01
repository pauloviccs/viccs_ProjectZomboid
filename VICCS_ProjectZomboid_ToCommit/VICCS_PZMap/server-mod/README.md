# VICCS PZMap Live Squad Radar Bridge (Mod para Project Zomboid)

Mini-mod oficial ultraleve de sincronização de telemetria de posições, esquadrões e facções em tempo real para o aplicativo desktop **VICCS PZMap**.

---

## 🎮 Compatibilidade
- **Project Zomboid Build 42 (Unstable & Stable):** Compatibilidade total garantida com o novo sistema de subsolos e arranha-céus (Z-Levels de **-32 a +32**).
- **Project Zomboid Build 41 (41.78+):** Retrocompatibilidade total garantida.
- **Modos Suportados:** Singleplayer, Host Local (Co-op) e Servidores Dedicados Multiplayer.

---

## 🚀 Como Instalar

### Método 1: Automático pelo Aplicativo VICCS PZMap (Recomendado)
1. Abra o aplicativo **VICCS PZMap**.
2. Vá até a aba **Config (⚙️)**.
3. Clique em **"Instalar Mod no Project Zomboid"**.
4. Abra o **Project Zomboid**, clique em **MODS** no menu principal e ative o **VICCS PZMap Live Squad Radar Bridge**.

---

### Método 2: Instalação Manual

#### Para Jogadores (Singleplayer / Cliente Multiplayer):
1. Copie a pasta `server-mod` para:
   - **Windows:** `C:\Users\<SeuUsuario>\Zomboid\mods\VICCSRadarBridge`
   - **Linux:** `~/.Zomboid/mods/VICCSRadarBridge`
2. No menu principal do jogo, clique em **MODS** e marque o mod como **Ativo**.

#### Para Servidores Dedicados:
1. Copie a pasta `server-mod` para o diretório de mods do servidor.
2. Abra o arquivo `.ini` do servidor (`Zomboid/Server/<NomeDoServidor>.ini`) e adicione:
   ```ini
   Mods=VICCSRadarBridge;
   ```
3. Inicie o servidor.

---

## ⚡ Desempenho e Segurança
- **Zero Risco de Ban:** Não injeta código de memória nem altera executáveis. Usa exclusivamente o sistema oficial de I/O do motor Kahlua / Java do próprio Project Zomboid.
- **Consumo de CPU:** Menos de 0.001% de uso de CPU com taxa de atualização de 500ms.
