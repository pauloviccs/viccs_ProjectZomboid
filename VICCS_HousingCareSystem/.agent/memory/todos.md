# TODOs

## Concluído (v1.0 Ready)
- [x] Configuração centralizada e segura via `LV_Config.lua` e `sandbox-options.txt`
- [x] Suporte à opção de Sandbox `LV_RequireSafehouseClaim` para servidores Multiplayer
- [x] Tabela de pontuação baseada em Tags e IsoFlags em `LV_ItemScoreData.lua`
- [x] Scanner assíncrono com Time-Slicing (10 tiles/frame) em `LV_ComfortScanner.lua`
- [x] Avaliação de Conforto (Tiers 1-4) e Squalor (Tiers 1-4) com regra de precedência (Squalor >= 50 suprime Conforto)
- [x] Catálogo Estendido de Moodlets e registro em `LV_MoodleDefs.lua`
- [x] Gerenciador de ciclo de vida de status com persistência universal (`getWorldAgeHours`) em `LV_BuffManager.lua`
- [x] HUD visual adaptativo minimalista em `LV_HUD.lua` com atalho de teclado na tecla `K`
- [x] Agendador horário, listener de carregamento inicial e troca de sala em `LV_ClientEvents.lua`
- [x] Compatibilidade 100% blindada para saves em andamento (Mid-Save) em SP e MP
- [x] Localização completa em Português do Brasil (`PTBR`) e Inglês (`EN`)
- [x] Documentação de requisitos visuais em `.agent/assets/MEDIA_SPECIFICATIONS.md`

## Pendente (Ações Externas / Lançamento)
- [ ] Criação do `poster.png` na raiz do mod
- [ ] Execução dos testes de stress em jogo
- [ ] Publicação na Steam Workshop
