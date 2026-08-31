# Arquitetura Técnica — Housing Care System (Lar Vivo)

## 1. Princípios Arquiteturais
- **Zero-Lag Scanning (Time-Slicing):** Varreduras de grid squares distribuídas ao longo de múltiplos quadros (`Events.OnTick`), processando 10 tiles por frame.
- **Persistência Imutável ao Tempo Local:** Uso de `getGameTime():getWorldAgeHours()` no `ModData` para calcular expiração de buffs, imune a sono acelerado, fast-forward ou desconexão MP.
- **Desacoplamento de Dados:** Regras de pontuação baseadas em Tags de itens e `IsoFlagType` em `LV_ItemScoreData.lua`.
- **Acesso Único de Configuração:** Leitura exclusiva de `SandboxVars` através de `LV_Config.lua`.

## 2. Camadas do Sistema
1. `LV_Config`: Abstração de SandboxVars com fallback robusto.
2. `LV_ItemScoreData`: Matriz de pontuação, pesos e penalidades.
3. `LV_ComfortScanner`: Coleta e processamento assíncrono de tiles.
4. `LV_BuffManager`: ModData, cálculo de tier e aplicação de status no personagem.
5. `LV_HUD`: Renderização do widget minimalista de conforto.
6. `LV_ClientEvents`: Orquestração de loops de verificação e atalhos de teclado.
