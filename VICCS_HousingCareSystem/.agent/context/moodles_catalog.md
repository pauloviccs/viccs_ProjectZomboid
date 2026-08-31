# Catálogo de Moodlets & Referência Gráfica — Housing Care System

> Atualmente o mod está configurado para utilizar **100% de assets e ícones nativos (vanilla)** do Project Zomboid Build 42 através dos modificadores estatísticos e do HUD adaptativo (`LV_HUD.lua`).
> Caso você decida desenhar ícones customizados no futuro (pixel art 32x32 com a moldura circular clássica do PZ), utilize a tabela abaixo como referência de nomes e arquivos.

---

## 1. Moodlets de Conforto (Buffs Positivos)

| ID do Moodlet | Nome de Exibição | Arquivo Recomendado (`media/moodles/`) | Asset Vanilla Atual | Descrição do Efeito |
|---|---|---|---|---|
| `LV_Tier1` | Aconchego Básico | `Moodle_LV_Comfort_1.png` | `Moodle_Bored_Good.png` | −10% no ganho de pânico |
| `LV_Tier2` | Lar Organizado | `Moodle_LV_Comfort_2.png` | `Moodle_Endurance_Good.png` | −20% pânico; +10% regen. endurance; *Energizado* |
| `LV_Tier3` | Refúgio Confortável | `Moodle_LV_Comfort_3.png` | `Moodle_Happy.png` | −25% infelicidade; +15% stamina; *Saciado* e *Cicatrização* |
| `LV_Tier4` | Santuário | `Moodle_LV_Comfort_4.png` | `Moodle_Hyperthermia_Good.png` | Imunidade a pânico leve, cura acelerada e proteção a infecção |

---

## 2. Moodlets de Squalor (Debuffs de Insalubridade)

| ID do Moodlet | Nome de Exibição | Arquivo Recomendado (`media/moodles/`) | Asset Vanilla Atual | Descrição do Efeito |
|---|---|---|---|---|
| `LV_Squalor1` | Ambiente Desagradável | `Moodle_LV_Squalor_1.png` | `Moodle_Unhappy_1.png` | Leve aumento contínuo de infelicidade |
| `LV_Squalor2` | Ambiente Insalubre | `Moodle_LV_Squalor_2.png` | `Moodle_Unhappy_2.png` | Aumento de estresse e perda de resistência física |
| `LV_Squalor3` | Antro Imundo | `Moodle_LV_Squalor_3.png` | `Moodle_Sick_2.png` | Náuseas frequentes e fadiga mental constante |
| `LV_Squalor4` | Foco de Doença | `Moodle_LV_Squalor_4.png` | `Moodle_Sick_4.png` | Estado crítico de febre, alta chance de infecção em cortes |
| `LV_Contaminated` | Contaminado (Resíduo) | `Moodle_LV_Contaminated.png` | `Moodle_Sick_1.png` | Debuff transitório que persiste por 1h após sair da sujeira |

---

## 3. Especificação Gráfica para Ícones Customizados
- **Formato:** PNG com fundo transparente.
- **Dimensões:** 32x32 pixels (ou 64x64 em resoluções altas da B42).
- **Estilo:** Pixel art com paleta de cores sóbrias/dessaturadas, iluminação no canto superior esquerdo e borda circular com leve gradiente.
