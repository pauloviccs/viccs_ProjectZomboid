# VISÃO DO MOD — "Housing Care System - by VICCS" (nome provisório)
> Sistema de conforto/organização de base para Project Zomboid Build 42 Stable, inspirado no sistema de Comfort do Valheim.
> Este documento é a fonte de verdade para qualquer agente de IA (Claude Code, Antigravity, OpenCode etc.) que for implementar, revisar ou evoluir este mod. Leia-o por completo antes de gerar qualquer código.

---

## 1. Pitch

A maioria dos mods de PZ adiciona conteúdo novo (itens, armas, mapas). Este mod não adiciona nada de novo ao mundo do jogador — ele **avalia o que o jogador já construiu com conteúdo vanilla** (paredes, mobília, decoração, limpeza) e recompensa bases bem cuidadas com buffs temporários que o jogador carrega ao sair de casa.

Referência direta de design: o sistema de **Comfort** do Valheim (Comfort level → efeito "Rested" com bônus e duração escaláveis).

Pilar de design: **nunca punir quem simplesmente não construiu nada** (sem debuff por não ter base) — mas quem **tem** uma base e a mantém imunda, suja ou largada também não deve ficar em zona neutra: isso quebra a imersão de "sobreviver bem". Ou seja: ausência de base = neutro; base ruim/insalubre = penalizado; base bem cuidada = recompensado. Ver seções 4.4 e 5.3.

---

## 2. Requisitos técnicos e compatibilidade

- **Jogo-alvo:** Project Zomboid, branch **Stable**, build **42.20.x** (atual: 42.20.4). Build 41 **não** é suportado — a engine de Lua, o sistema de moodles e a API de Sandbox/Mod Options mudaram entre B41 e B42, e não vale a pena manter compatibilidade dupla na v1.
- **Linguagem de script:** Lua via Kahlua (implementação Java do PZ, baseada em Lua 5.1 com extensões próprias — **não é Lua 5.4 puro**, cuidado com sintaxe ao gerar código).
- **APIs novas do B42 a usar:**
  - `ModOptions` (PZAPI) — para preferências client-side (não afeta gameplay: HUD, notificações, keybind).
  - **Sandbox Options** (arquivo `sandbox-options.txt` + traduções) — para tudo que afeta gameplay/servidor, incluindo multiplayer. **Nunca** usar ModOptions para algo que muda regras do jogo — é a diretriz oficial do próprio wiki do PZ.
- **Observação importante:** a Indie Stone anunciou uma "Build 42 Support Update" ainda ao longo de 2026 focada em, entre outras coisas, **mais suporte de modding** — inclusive um novo guia de modding oficial. Antes de fechar detalhes finos de API (nomes exatos de hooks, formato de `mod.info`), o agente deve **verificar a documentação atual no PZwiki** (pzwiki.net) e no changelog oficial, pois pode ter mudado desde a escrita deste documento.
- Sempre que uma sessão de trabalho começar, o agente deve conferir a versão estável atual do jogo antes de assumir que ainda é a 42.20.x.

---

## 3. Estrutura de pastas do mod

```
LarVivo/
├── mod.info
├── poster.png
├── workshop.txt
├── media/
│   ├── lua/
│   │   ├── client/
│   │   │   ├── LV_HUD.lua              -- HUD opcional de conforto (ModOptions)
│   │   │   └── LV_ClientEvents.lua
│   │   ├── server/                     -- (se necessário, lógica autoritativa em MP)
│   │   └── shared/
│   │       ├── LV_Config.lua           -- única fonte de leitura das Sandbox Options
│   │       ├── LV_ItemScoreData.lua    -- tabela de pontuação por tag/item (fácil de estender)
│   │       ├── LV_ComfortScanner.lua   -- lógica de varredura do cômodo/score (comfort E squalor)
│   │       ├── LV_MoodleDefs.lua       -- definição dos moodlets custom (buffs e debuffs)
│   │       └── LV_BuffManager.lua      -- aplica/decai buffs e debuffs, persiste via ModData
│   ├── sandbox-options.txt
│   ├── sandbox-options_PT_BR.txt
│   └── moodles/                        -- ícones dos moodlets customizados
└── common/
    └── (assets adicionais se necessário)
```

**Regra de ouro para facilitar atualização futura:** toda pontuação de item/mobília fica em `LV_ItemScoreData.lua`, como tabela de dados por **tag** (não por nome de item fixo, sempre que possível), para não quebrar a cada DLC/patch que adiciona móveis novos. Toda leitura de configuração passa por `LV_Config.lua` — nenhum outro arquivo deve chamar `SandboxVars` diretamente.

---

## 4. Sistema de pontuação de conforto (Comfort Score)

Score de 0 a 100, recalculado periodicamente (não a cada tick — custo de performance).

### 4.1 Pré-requisito (gate, não pontua)
- Cômodo fechado: paredes + teto + pelo menos uma porta (via `IsoRoom`/verificação de squares). Configurável via sandbox (`LV_RequireRoofedRoom`).
- Opcionalmente, em multiplayer, exigir que a construção seja um **Safehouse reivindicado** (`LV_RequireSafehouseClaim`, default `false`).

### 4.2 Componentes do score (pesos default, todos configuráveis)
| Componente | Peso | O que avalia |
|---|---|---|
| Limpeza | 15% | Ausência de lixo, sangue, corpos, mato/entulho no piso |
| Mobília funcional | 25% | Cama, cadeiras, mesas, armários por m² do cômodo |
| Iluminação | 10% | Lampiões/velas acesos, geração de energia ativa |
| Decoração dedicada | 20% | Quadros, tapetes, plantas, rádio, TV — bônus por **tipos diferentes**, não por repetição |
| Itens do mundo exibidos (world items) | 15% | Itens comuns do jogo (armas, ferramentas, munição, comida embalada, livros, etc.) colocados no chão ou sobre mobília, contando pelo seu **modelo 3D** como decoração informal — ver 4.2.1 |
| Organização | 15% | Contêineres com itens categorizados vs. bagunça (heurística: baixa dispersão de itens duplicados pelo chão) |

O agente responsável pela implementação deve propor a fórmula exata de normalização (ex.: pontuação por m² com teto de diminuição de retorno) e documentar no próprio código — este arquivo fixa os **pesos e a intenção**, não a fórmula matemática final.

#### 4.2.1 Itens do mundo (world items) como decoração

Muitos itens comuns do jogo — armas, munição, ferramentas, caixas de comida, livros, roupas — têm modelo 3D próprio quando estão largados no chão ou apoiados em mobília, e visualmente funcionam como decoração mesmo sem serem "itens de decoração" oficiais. Esse componente contabiliza isso, com regras anti-abuso para não virar "spam de loot no chão":

- **Diminishing returns por tipo:** o 1º item de um tipo (ex.: 1 machado) pontua cheio; cópias adicionais do mesmo tipo no mesmo cômodo pontuam com retorno decrescente (evita empilhar 50 machados pra farmar score).
- **Bônus por posicionamento:** itens apoiados sobre mobília (mesa, estante, prateleira) pontuam mais que itens soltos direto no chão — incentiva composição deliberada em vez de derrubar o inventário.
- **Itens sujos/estragados não contam:** comida podre, itens ensanguentados ou em mau estado não pontuam aqui (já são penalizados em Limpeza).
- Tabela de tags elegíveis (armas, ferramentas, literatura, contêineres de comida, etc.) fica em `LV_ItemScoreData.lua`, junto com a pontuação de mobília — mesma regra de usar **tags** em vez de nomes fixos de item.

### 4.3 Frequência de recálculo
- Recalcular a cada N horas de jogo (`LV_ComfortCheckIntervalHours`, default 6), não em tempo real, e apenas quando o jogador estiver dentro do raio da base.

### 4.4 Squalor Score (pontuação de insalubridade — o lado ruim)

Independente do Comfort Score, o mesmo cômodo também gera um **Squalor Score** (0 a 100, 0 = impecável, 100 = extremamente imundo). Ele só é avaliado se o pré-requisito da seção 4.1 for atendido (existe um cômodo fechado reconhecido como base) — ou seja, **quem não tem base construída não é avaliado por nenhum dos dois scores**, mantendo o pilar de design da seção 1.

| Componente | Peso | O que avalia |
|---|---|---|
| Sujeira acumulada | 40% | Sangue, mato/entulho no piso, poeira/grime acumulado sem limpeza |
| Corpos e restos | 30% | Cadáveres (zumbis ou NPCs) não removidos de dentro do cômodo |
| Lixo e itens podres | 20% | Comida podre, lixo genérico, itens estragados largados |
| Bagunça/desorganização | 10% | Itens comuns espalhados de forma caótica pelo chão (o oposto do componente Organização do Comfort Score) |

Squalor e Comfort **não se cancelam automaticamente**: uma base pode ter mobília boa e ainda assim ter squalor alto (ex.: sala bem mobiliada mas cheia de corpos e sangue). Regra de precedência sugerida: se `squalor_score >= LV_SqualorOverrideThreshold` (default 50), o Comfort Score daquele cômodo é **zerado/suprimido** para efeito de buffs (não faz sentido ganhar bônus de "lar aconchegante" num ambiente insalubre), e só os debuffs da seção 5.3 se aplicam.

---

## 5. Moodlets customizados e tiers de buff

Buffs só existem enquanto o jogador está **fora** do raio da base (`LV_ComfortRadiusTiles`, default 15 tiles a partir da cama/ponto-âncora). Duração escala com tempo de permanência prévia na base + tier atingido, com teto máximo.

| Score | Tier | Moodlets base concedidos | Efeito sugerido |
|---|---|---|---|
| 0–19 | Sem bônus | — | — |
| 20–39 | Aconchego Básico | Confiante I | −10% ganho de Pânico |
| 40–59 | Lar Organizado | Confiante II + Descansado I | −20% Pânico; +10% regeneração de Endurance |
| 60–79 | Refúgio Confortável | Confiante III + Descansado II + Focado | −25% ganho de Infelicidade; +15% regen. Endurance; leve redução de sway na mira |
| 80–100 | Santuário | Todos acima, no máximo + Resiliente | Menor chance/tempo de infecção em ferimentos leves; efeitos anteriores amplificados |

**Fórmula de duração (ponto de partida, ajustável):**
```
duracao_horas = min(
  LV_BuffDurationMaxHours,
  LV_BuffDurationBaseHours + (LV_BuffDurationPerComfortPoint * comfort_score)
)
```

### 5.1 Catálogo estendido de moodlets (opcionais, além dos 4 base)

Além dos 4 moodlets base da tabela acima, o mod deve trazer um catálogo maior de moodlets opcionais, para dar variedade e permitir que cada servidor monte sua própria combinação. Cada um tem um tier mínimo de elegibilidade e nasce **habilitado ou não por padrão**, mas tudo é alternável:

| Moodlet | Tier mínimo | Efeito sugerido | Default no catálogo |
|---|---|---|---|
| Energizado | 2 | Reduz taxa de ganho de Fadiga (Tired) | Ativado |
| Aquecido | 2 | Menor perda de temperatura corporal em ambientes frios | Ativado |
| Saciado | 3 | Reduz taxa de ganho de Fome | Ativado |
| Cicatrização Rápida | 3 | Bônus na velocidade de cicatrização de cortes/arranhões leves (diferente de Resiliente, que foca em infecção) | Ativado |
| Alerta | 4 | Leve redução no ganho de Stress em combate | Desativado |
| Sortudo (loot) | 4 | Pequeno bônus de sorte em rolagens de loot | **Desativado** — mexe em economia do jogo, deixar como opt-in explícito do servidor |

Esse catálogo deve ser fácil de estender: novos moodlets entram em `LV_MoodleDefs.lua` (seção 8) sem exigir mudanças em outros arquivos.

### 5.2 Quem controla o quê: sandbox (servidor) vs. ModOptions (jogador)

Dois níveis de controle, para não confundir "regra do servidor" com "preferência pessoal":

- **Nível servidor (Sandbox Options):** decide **quais moodlets existem** naquela partida/servidor — uma opção booleana por moodlet do catálogo (`LV_Enable_<NomeDoMoodlet>`), mais os 4 moodlets base que também podem ser desligados individualmente. Isso afeta todos os jogadores igualmente, então fica em sandbox, seguindo a diretriz oficial do PZ.
- **Nível jogador (Mod Options):** dentro do que o servidor permitiu, cada jogador pode desligar no cliente moodlets específicos que **não quer receber** (ex.: alguém que não gosta do bônus de loot por motivos de imersão, ou não quer notificação de um moodlet específico). É uma preferência pessoal que só afeta o próprio jogador, não o mundo — por isso fica em ModOptions, não em sandbox.

### 5.3 Debuffs de insalubridade (o lado ruim)

Diferente dos buffs (que o jogador "leva com ele" ao sair, tipo o Rested do Valheim), os debuffs de squalor representam **estar exposto ao ambiente imundo** — por isso se aplicam principalmente enquanto o jogador está **dentro** do cômodo insalubre, com um pequeno resíduo ("cheiro/contaminação") por um período curto após sair, bem mais curto que a duração dos buffs positivos.

| Squalor Score | Tier | Moodlets aplicados | Efeito sugerido |
|---|---|---|---|
| 0–19 | Sem penalidade | — | — |
| 20–39 | Ambiente Insalubre I | Enojado I | Pequeno aumento no ganho de Infelicidade enquanto dentro do cômodo |
| 40–59 | Ambiente Insalubre II | Enojado II + Incomodado | Aumento moderado de Infelicidade/Stress; leve redução na regeneração de Endurance |
| 60–79 | Antro Imundo | Enojado III + Nauseado | Chance de náusea aumentada; ganho de Stress mais alto; leve penalidade de Fadiga |
| 80–100 | Foco de Doença | Todos acima no máximo + Vulnerável | Maior chance/gravidade de infecção em ferimentos; efeitos anteriores amplificados |

**Resíduo ao sair (opcional, configurável):** moodlet leve "Contaminado" por `LV_SqualorLingerHours` (default 1h, bem menor que a duração dos buffs positivos), representando o jogador carregando o cheiro/sujeira por um tempo curto após deixar o ambiente.

Assim como os buffs positivos, os debuffs de squalor são **totalmente opcionais** — servidor pode desligar o sistema inteiro (`LV_SqualorSystemEnabled`) sem afetar o funcionamento dos buffs de conforto.

---

## 6. Painel de configuração (Sandbox Options)

Tudo abaixo deve aparecer no `sandbox-options.txt` (com tradução PT-BR), visível no painel de sandbox do host/servidor dedicado, igual a outros mods de gameplay:

| Opção | Tipo | Default | Descrição |
|---|---|---|---|
| `LV_SystemEnabled` | bool | true | Liga/desliga o mod inteiro |
| `LV_ComfortCheckIntervalHours` | int | 6 | Intervalo de recálculo do score |
| `LV_ComfortRadiusTiles` | int | 15 | Raio considerado "base" a partir da âncora |
| `LV_RequireRoofedRoom` | bool | true | Exige cômodo fechado para contar pontuação |
| `LV_RequireSafehouseClaim` | bool | false | Exige safehouse reivindicado (MP) |
| `LV_Tier1Threshold`..`LV_Tier4Threshold` | int (0–100) | 20/40/60/80 | Limiares customizáveis de cada tier |
| `LV_BuffDurationBaseHours` | float | 2.0 | Duração mínima do buff |
| `LV_BuffDurationPerComfortPoint` | float | 0.05 | Incremento de duração por ponto de score |
| `LV_BuffDurationMaxHours` | float | 12.0 | Teto de duração |
| `LV_BuffMagnitudeMultiplier` | float | 1.0 | Multiplicador global de força dos efeitos (ajuste fino do servidor) |
| `LV_Enable_Confiante` / `LV_Enable_Descansado` / `LV_Enable_Focado` / `LV_Enable_Resiliente` | bool | true | Liga/desliga individualmente cada moodlet base |
| `LV_Enable_Energizado` / `LV_Enable_Aquecido` / `LV_Enable_Saciado` / `LV_Enable_CicatrizacaoRapida` | bool | true | Liga/desliga cada moodlet opcional (ver seção 5.1) |
| `LV_Enable_Alerta` | bool | false | Liga/desliga o moodlet opcional "Alerta" |
| `LV_AllowLootLuckBuff` | bool | false | Habilita o moodlet opcional "Sortudo" (sorte em loot) — mexe em economia do jogo, fica off por padrão |
| `LV_SqualorSystemEnabled` | bool | true | Liga/desliga o sistema de debuffs de insalubridade (independente do sistema de buffs) |
| `LV_SqualorOverrideThreshold` | int (0–100) | 50 | A partir de qual Squalor Score o Comfort Score do cômodo é suprimido (sem buff, só debuff) |
| `LV_SqualorTier1Threshold`..`LV_SqualorTier4Threshold` | int (0–100) | 20/40/60/80 | Limiares customizáveis de cada tier de squalor |
| `LV_SqualorMagnitudeMultiplier` | float | 1.0 | Multiplicador global de força dos debuffs (ajuste fino do servidor) |
| `LV_SqualorLingerHours` | float | 1.0 | Duração do resíduo "Contaminado" após sair do ambiente insalubre |
| `LV_Enable_Enojado` / `LV_Enable_Incomodado` / `LV_Enable_Nauseado` / `LV_Enable_Vulneravel` | bool | true | Liga/desliga individualmente cada moodlet de squalor |

### Mod Options (client-side, via `ModOptions` API — não afeta gameplay)
- `ShowComfortHUD` (checkbox) — mostra indicador de score na tela
- `ComfortNotifications` (checkbox) — notifica ao subir/descer de tier
- `HUDPosition` (dropdown) — posição do indicador na tela
- Keybind opcional para abrir um painel detalhado do score atual
- **Opt-out pessoal por moodlet:** um checkbox por moodlet disponível no servidor — de buff **ou de debuff** — (`LV_Personal_<NomeDoMoodlet>`), permitindo que o próprio jogador recuse receber um moodlet específico mesmo que o servidor o tenha habilitado — preferência individual, não regra de mundo

---

## 7. Roadmap de versões

- **v0.1 (MVP):** score básico (limpeza + mobília), 2 tiers, 1 moodlet custom (Confiante), sandbox options mínimas, sem HUD.
- **v0.2:** todos os 4 tiers de Comfort, todos os moodlets base + catálogo estendido da seção 5.1, persistência via ModData entre saves.
- **v0.3:** Squalor Score e os 4 tiers de debuff (seção 5.3), incluindo a regra de precedência squalor-suprime-comfort.
- **v0.4:** HUD opcional (ModOptions), notificações de mudança de tier (tanto de comfort quanto de squalor).
- **v1.0:** suporte a multiplayer com safehouse claim, tradução PT-BR/EN completa, testes em servidor dedicado.
- **Pós-1.0:** revisar contra o "Build 42 Support Update" da Indie Stone quando lançado (pode trazer hooks de modding melhores para detecção de cômodo/mobília).

---

## 8. Convenções para manter fácil de atualizar

1. Prefixo único `LV_` em todas as variáveis globais, sandbox options e nomes de arquivo, para evitar colisão com outros mods.
2. Nenhuma lógica de pontuação hardcoded fora de `LV_ItemScoreData.lua`.
3. Nenhuma leitura direta de `SandboxVars` fora de `LV_Config.lua`.
4. Todo moodlet novo se registra em `LV_MoodleDefs.lua` com id, ícone, e efeito — nunca inline no `LV_BuffManager.lua`.
5. Manter um `CHANGELOG.md` na raiz do mod, com uma entrada por versão do Workshop.
6. Antes de cada atualização, checar a versão estável atual do PZ e o PZwiki para mudanças de API do B42.

---

## 9. Referências
- PZwiki — Modding: https://pzwiki.net/wiki/Modding
- PZwiki — ModOptions: https://pzwiki.net/wiki/ModOptions
- PZwiki — Lua (API): https://pzwiki.net/wiki/Lua_(API)
- Blog oficial de patches do B42: https://projectzomboid.com/blog/
