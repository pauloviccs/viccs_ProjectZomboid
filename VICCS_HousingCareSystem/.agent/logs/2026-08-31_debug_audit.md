# Audit Log — 2026-08-31T17:10 — Sessão de Debug Crítico

## Problema Reportado
- 23.000+ erros em 5 minutos de jogo MP
- Sandbox options NÃO aparecem no menu do servidor
- Erro persistente: `call nil in processSquare (LV_ComfortScanner.lua:239)`

## Root Cause Identificada

### 🔴 CAUSA PRINCIPAL: TRIPLICAÇÃO DE CÓDIGO + ARQUIVOS DESATUALIZADOS

O mod possui **3 cópias idênticas** de cada arquivo Lua:

| Local | Tamanho LV_ComfortScanner | Contém Fix? |
|---|---|---|
| `media/lua/shared/` | 16.263 bytes | ✅ SIM (editado) |
| `42.0/media/lua/shared/` | 14.770 bytes | ❌ NÃO (original) |
| `common/media/lua/shared/` | 14.770 bytes | ❌ NÃO (original) |

Na Build 42, o PZ carrega os arquivos de `42.0/` com prioridade. Os fixes
aplicados em `media/lua/shared/` **NUNCA FORAM LIDOS PELO JOGO**.

Além disso, como existem 3 cópias com o mesmo nome de tabela global
(`LV_ComfortScanner`, `LV_BuffManager`, etc.), o jogo carrega as 3 cópias,
e a última sobrescreve as anteriores — resultando em comportamento
imprevisível.

### 🔴 CAUSA DO SPAM DE 23.000 ERROS

O `onTickScanner()` roda em `Events.OnTick` = **a cada frame** (~60fps).

A versão em `42.0/` NÃO tinha pcall, então:
- Cada tile que falhava lançava uma exceção Java
- O scanner continuava ativo porque o erro não desativava `scanQueue.active`
- A cada frame, 10 tiles = 10 erros
- 60fps × 10 erros = **600 erros/segundo** = 180.000 erros em 5 min

### 🟡 CAUSA DO SANDBOX NÃO APARECER

O `sandbox-options.txt` está em:
- `42.0/media/sandbox-options.txt` ✅
- `common/media/sandbox-options.txt` ✅
- `media/sandbox-options.txt` ✅

MAS o formato está usando prefixo `LV_` nos nomes das opções (ex: `option LV_SystemEnabled`),
enquanto o `LV_Config.lua` busca em `SandboxVars.HousingCareSystem.SystemEnabled`.

O PZ B42 usa o formato: `option HousingCareSystem.NomeDaOpcao` para agrupar
automaticamente em `SandboxVars.HousingCareSystem.NomeDaOpcao`.

O formato atual (`option LV_SystemEnabled`) cria `SandboxVars.LV_SystemEnabled`
— que é o fallback da linha 64 do Config. Mas se o PZ não reconhecer o formato,
nem isso funciona.

## Solução Aplicada

1. **ELIMINAR `42.0/` e `common/`** — A estrutura multi-versão é desnecessária
   quando `versionMin=42.0` já está no mod.info. O PZ B42 carrega `media/lua/`
   diretamente da raiz do mod.

2. **Reescrever `sandbox-options.txt`** com formato correto do PZ B42:
   `option HousingCareSystem.NomeDaOpcao { ... }`

3. **Código Lua fica APENAS em `media/lua/`** — fonte única de verdade.

4. **processSquare hardened** com pcall, instanceof, e tostring.
