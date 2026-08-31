# ESPECIFICAÇÃO COMPLETA DE MÍDIAS & ASSETS GRÁFICOS
> **Mod:** Housing Care System (Lar Vivo) — Project Zomboid Build 42  
> **Diretório Alvo:** `.agent/assets/` e estrutura do mod `media/`

Este documento lista **todas as imagens, ícones e mídias visuais** necessárias para o mod, com dimensões exatas, formatos, caminhos de destino e orientações de direção de arte para você produzir as artes com facilidade.

---

## 1. Diretrizes Visuais & Direção de Arte do Project Zomboid

- **Estilo Geral:** Pixel Art com iluminação direcional (luz vindo do canto superior esquerdo).
- **Paleta de Cores:** Cores levemente dessaturadas, com estética anos 90, evitando tons fluorescentes ou vetoriais "lisos".
- **Formato dos Moodlets:** Ícone central em pixel art envolvido pela clássica moldura circular com fundo transparente (Alpha Channel).

---

## 2. Imagens de Apresentação e Capa (Workshop & Mod Loader)

| Arquivo | Destino no Mod | Formato | Dimensões | Descrição / Ideia Visual |
|---|---|---|---|---|
| `poster.png` | `VICCS_HousingCareSystem/poster.png` | `.PNG` (RGB, sem canal alfa obrigatório) | **512 × 512 px** *(ou 256 × 256 px)* | **Capa Principal do Mod:** Título "Housing Care System - Lar Vivo" com logo. Arte mostrando o contraste de uma base bem cuidada, aconchegante e iluminada (com lareira, sofá, quadros) enquanto zumbis observam pela janela na chuva. |
| `preview.png` | `VICCS_HousingCareSystem/preview.png` | `.PNG` ou `.JPG` | **1920 × 1080 px** *(16:9)* | **Banner da Steam Workshop:** Imagem promocional em widescreen destacando os pilares do mod: "Conforto", "Limpeza", "Decoração" e "Sobrevivência". |

---

## 3. Ícones de Moodlets — Conforto (Buffs Positivos)

> **Resolução Padrão:** `32 × 32 px` (Resolução nativa clássica) ou `64 × 64 px` (Alta definição para monitores 4K no B42).  
> **Formato:** `.PNG` com canal alfa (transparência de fundo).  
> **Destino:** `VICCS_HousingCareSystem/media/moodles/`

| Arquivo | Nome do Moodlet | Moldura / Cor | Sugestão de Ícone Central |
|---|---|---|---|
| `Moodle_LV_Comfort_1.png` | **Aconchego Básico (Tier I)** | Borda Verde Claro | Uma poltrona acolchoada simples ou uma vela acesa emitindo calor suave. |
| `Moodle_LV_Comfort_2.png` | **Lar Organizado (Tier II)** | Borda Verde Viva | Uma estante de livros organizada com uma caneca de café soltando fumaça. |
| `Moodle_LV_Comfort_3.png` | **Refúgio Confortável (Tier III)** | Borda Verde Esmeralda | Uma cama arrumada ao lado de um quadro decorativo e iluminação quente. |
| `Moodle_LV_Comfort_4.png` | **Santuário (Tier IV)** | Borda Verde Brilhante / Dourada | Uma casa/abrigo fortificado com escudo dourado ou um coração brilhante no centro. |

---

## 4. Ícones de Moodlets — Squalor (Debuffs de Insalubridade)

> **Resolução Padrão:** `32 × 32 px` ou `64 × 64 px` | **Formato:** `.PNG` transparente | **Destino:** `VICCS_HousingCareSystem/media/moodles/`

| Arquivo | Nome do Moodlet | Moldura / Cor | Sugestão de Ícone Central |
|---|---|---|---|
| `Moodle_LV_Squalor_1.png` | **Ambiente Desagradável (Nível I)** | Borda Amarela | Uma vassoura quebrada com poeira ou uma mancha cinza no piso. |
| `Moodle_LV_Squalor_2.png` | **Ambiente Insalubre (Nível II)** | Borda Laranja | Uma poça de sangue seco com moscas voando ao redor. |
| `Moodle_LV_Squalor_3.png` | **Antro Imundo (Nível III)** | Borda Vermelho-Escuro | Um pedaço de carne podre com ossos e vapor esverdeado de odor. |
| `Moodle_LV_Squalor_4.png` | **Foco de Doença (Nível IV)** | Borda Roxa / Tóxica | Uma caveira com símbolo biológico/vírus envolto em fumaça fétida. |
| `Moodle_LV_Contaminated.png` | **Contaminado (Resíduo 1h)** | Borda Amarelo-Ocre | Pegadas de lama/sangue com odor residual ao redor do personagem. |

---

## 5. Ícones de Moodlets — Catálogo Estendido (Específicos)

> **Resolução Padrão:** `32 × 32 px` ou `64 × 64 px` | **Formato:** `.PNG` transparente | **Destino:** `VICCS_HousingCareSystem/media/moodles/`

| Arquivo | Nome do Buff | Moldura / Cor | Sugestão de Ícone Central |
|---|---|---|---|
| `Moodle_LV_Energized.png` | **Energizado** | Borda Azul Claro | Um raio amarelo/azul estilizado com símbolo de vigor/energia. |
| `Moodle_LV_Warm.png` | **Aquecido** | Borda Laranja Quente | Uma chama de fogueira estilizada ou um termômetro em temperatura agradável. |
| `Moodle_LV_Satiated.png` | **Saciado** | Borda Verde Oliva | Um prato com garfo e faca e um pão fresco (refeição bem preparada). |
| `Moodle_LV_FastHealing.png` | **Cicatrização Rápida** | Borda Vermelho Suave / Cruz | Uma bandagem médica limpa com um brilho de regeneração. |
| `Moodle_LV_Alert.png` | **Alerta** | Borda Dourada | Um olho aberto e vigilante focado. |

---

## 6. Ícones de Interface do HUD (Opcionais / Decorativos)

> **Resolução:** `16 × 16 px` ou `24 × 24 px` | **Formato:** `.PNG` transparente | **Destino:** `VICCS_HousingCareSystem/media/ui/`

| Arquivo | Finalidade | Descrição Visual |
|---|---|---|
| `LV_HUD_Comfort_Icon.png` | Ícone ao lado da barra de Conforto | Uma casinha estilizada em pixel art verde (estilo The Sims / Plumbob aconchegante). |
| `LV_HUD_Squalor_Icon.png` | Ícone ao lado da barra de Squalor | Um símbolo de biohazard ou mosca estilizada em tom âmbar/vermelho. |

---

## 7. Checklist Rápido de Produção

- [ ] `poster.png` (512x512 PNG)
- [ ] `Moodle_LV_Comfort_1.png` a `4.png` (32x32 ou 64x64 PNG)
- [ ] `Moodle_LV_Squalor_1.png` a `4.png` (32x32 ou 64x64 PNG)
- [ ] `Moodle_LV_Contaminated.png` (32x32 ou 64x64 PNG)
- [ ] `Moodle_LV_Energized.png`, `Warm.png`, `Satiated.png`, `FastHealing.png`, `Alert.png`
