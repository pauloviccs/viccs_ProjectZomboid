#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Living House (Housing Care System) - Translation Updater & Parity Validator
Adiciona chaves faltantes de Sandbox e UI para todas as linguas suportadas.
"""

import os
import json
import re

UI_TRANSLATIONS = {
    'EN': {
        'UI_optionscreen_binding_[Living House]': '[Living House]',
        'UI_optionscreen_binding_Toggle Living House HUD': 'Toggle Living House HUD',
        'UI_LV_HUD_HiddenNote': 'Living House: HUD hidden. Press [%s] or type /lv_hud to show.',
        'UI_LV_HUD_ShownNote': 'Living House: HUD shown.'
    },
    'PTBR': {
        'UI_optionscreen_binding_[Living House]': '[Living House]',
        'UI_optionscreen_binding_Toggle Living House HUD': 'Alternar HUD do Living House',
        'UI_LV_HUD_HiddenNote': 'Living House: HUD oculta. Pressione [%s] ou digite /lv_hud para reexibir.',
        'UI_LV_HUD_ShownNote': 'Living House: HUD reexibida.'
    },
    'PT': {
        'UI_optionscreen_binding_[Living House]': '[Living House]',
        'UI_optionscreen_binding_Toggle Living House HUD': 'Alternar HUD do Living House',
        'UI_LV_HUD_HiddenNote': 'Living House: HUD oculta. Pressione [%s] ou digite /lv_hud para reexibir.',
        'UI_LV_HUD_ShownNote': 'Living House: HUD reexibida.'
    },
    'ES': {
        'UI_optionscreen_binding_[Living House]': '[Living House]',
        'UI_optionscreen_binding_Toggle Living House HUD': 'Alternar HUD de Living House',
        'UI_LV_HUD_HiddenNote': 'Living House: HUD oculta. Presione [%s] o escriba /lv_hud para mostrar.',
        'UI_LV_HUD_ShownNote': 'Living House: HUD mostrada.'
    },
    'CN': {
        'UI_optionscreen_binding_[Living House]': '[Living House]',
        'UI_optionscreen_binding_Toggle Living House HUD': '切换 Living House HUD',
        'UI_LV_HUD_HiddenNote': 'Living House: HUD 已隐藏。按 [%s] 或输入 /lv_hud 重新显示。',
        'UI_LV_HUD_ShownNote': 'Living House: HUD 已显示。'
    },
    'CH': {
        'UI_optionscreen_binding_[Living House]': '[Living House]',
        'UI_optionscreen_binding_Toggle Living House HUD': '切換 Living House HUD',
        'UI_LV_HUD_HiddenNote': 'Living House: HUD 已隱藏。按 [%s] 或輸入 /lv_hud 重新顯示。',
        'UI_LV_HUD_ShownNote': 'Living House: HUD 已顯示。'
    }
}

# Dicionario completo de chaves de sandbox com textos refinados
SANDBOX_DEFINITIONS = {
    'RequireBaseOwnership': {
        'EN': ('Require Base Ownership (My Home)', 'If enabled (recommended), only your officially claimed Home provides comfort. Neighbor houses and neutral buildings are treated as neutral properties (0 comfort points).'),
        'PTBR': ('Exigir Posse da Base (Meu Lar)', 'Se ativado (recomendado), apenas o seu Lar oficial reivindicado concede conforto. Casas de vizinhos e imoveis neutros sao tratados como imovel neutro (0 pts de conforto).'),
        'PT': ('Exigir Posse da Base (Meu Lar)', 'Se ativado (recomendado), apenas o seu Lar oficial reivindicado concede conforto. Casas de vizinhos e imoveis neutros sao tratados como imovel neutro (0 pts de conforto).'),
        'ES': ('Exigir Propiedad de la Base (Mi Hogar)', 'Si esta activado (recomendado), solo su hogar oficialmente reclamado otorga confort. Los edificios vecinos y neutrales no otorgan puntos de confort.'),
        'CN': ('要求基地所有权（我的家）', '启用后（推荐），只有您官方声明的家园才提供舒适度。邻居家和中立建筑被视为中立房产（0 舒适点）。'),
        'CH': ('要求基地所有權（我的家）', '啟用後（推薦），只有您官方聲明的家園才提供舒適度。鄰居家和中立建築被視為中立房產（0 舒適點）。')
    },
    'AcclimatizationMinutes': {
        'EN': ('Acclimatization Minutes', 'In-game minutes required resting inside the home before comfort buffs start applying.'),
        'PTBR': ('Minutos de Aclimatacao', 'Minutos em tempo de jogo necessarios descansando dentro do lar antes dos beneficios de conforto iniciarem.'),
        'PT': ('Minutos de Aclimatacao', 'Minutos em tempo de jogo necessarios descansando dentro do lar antes dos beneficios de conforto iniciarem.'),
        'ES': ('Minutos de Climatización', 'Minutos en el juego descansando dentro del hogar antes de recibir comodidades.'),
        'CN': ('适应分钟数', '在舒适增益开始生效前，必须在居所内休息的游戏内分钟数。'),
        'CH': ('適應分鐘數', '在舒適增益開始生效前，必須在居所內休息的遊戲內分鐘數。')
    },
    'Max3DItemsPerRoomCategory': {
        'EN': ('3D Item Category Cap per Room', 'Maximum number of 3D items in the same category (e.g., food, books, tools) that contribute to ambient score before saturating.'),
        'PTBR': ('Teto de Itens 3D por Categoria no Cômodo', 'Quantidade maxima de itens 3D da mesma categoria (ex: comidas, livros, ferramentas) que somam pontos de ambiente por comodo antes de saturar.'),
        'PT': ('Teto de Itens 3D por Categoria no Cômodo', 'Quantidade maxima de itens 3D da mesma categoria (ex: comidas, livros, ferramentas) que somam pontos de ambiente por comodo antes de saturar.'),
        'ES': ('Límite de Objetos 3D por Categoría', 'Cantidad máxima de objetos 3D de la misma categoría que suman confort por habitación.'),
        'CN': ('房间单类3D物品上限', '在同类3D物品（如食物、书本、工具）达到饱和前，每个房间贡献环境分数的最大数量。'),
        'CH': ('房間單類3D物品上限', '在同類3D物品（如食物、書本、工具）達到飽和前，每個房間貢獻環境分數的最大數量。')
    },
    'Max3DItemsPerTile': {
        'EN': ('Max 3D Items Evaluated per Tile', 'Maximum number of 3D objects placed on floor/counter on each tile evaluated for comfort calculation.'),
        'PTBR': ('Limite de Itens 3D Avaliados por Bloco (Tile)', 'Quantidade maxima de objetos 3D no chão ou bancada de cada tile considerados no calculo para otimizar desempenho.'),
        'PT': ('Limite de Itens 3D Avaliados por Bloco (Tile)', 'Quantidade maxima de objetos 3D no chão ou bancada de cada tile considerados no calculo para otimizar desempenho.'),
        'ES': ('Máx Objetos 3D por Casilla', 'Cantidad máxima de objetos 3D en el suelo evaluados por casilla para optimizar rendimiento.'),
        'CN': ('每格最多评估3D物品数', '为了优化性能，每个地块表面评估的最大3D物件数量。'),
        'CH': ('每格最多評估3D物品數', '為了優化性能，每個地塊表面評估的最大3D物件數量。')
    },
    'EnableAmbientItemDropNotice': {
        'EN': ('Ambient Item Placement Notice', 'Displays a discreet floating note above the character showing ambient score gains when placing items.'),
        'PTBR': ('Aviso Visual ao Colocar Item no Cômodo', 'Exibe uma nota flutuante discreta sobre o personagem indicando o ganho de ambiente ao soltar ou posicionar itens na base.'),
        'PT': ('Aviso Visual ao Colocar Item no Cômodo', 'Exibe uma nota flutuante discreta sobre o personagem indicando o ganho de ambiente ao soltar ou posicionar itens na base.'),
        'ES': ('Aviso al Colocar Objeto 3D', 'Muestra una nota flotante sobre el personaje al colocar objetos decorativos en el hogar.'),
        'CN': ('放置3D物品环境提示', '在地面放置或丢弃物品增加环境舒适度时，在角色头顶显示浮动提示。'),
        'CH': ('放置3D物品環境提示', '在地面放置或丟棄物品增加環境舒適度時，在角色頭頂顯示浮動提示。')
    },
    'EnableDiminishingReturns': {
        'EN': ('Enable Furniture Diminishing Returns', 'Repeated furniture or decoration items provide diminishing score returns to encourage diverse room decoration.'),
        'PTBR': ('Ativar Rendimento Decrescente de Mobílias', 'Itens repetidos da mesma categoria rendem pontuacoes progressivamente menores, incentivando decoracao variada.'),
        'PT': ('Ativar Rendimento Decrescente de Mobílias', 'Itens repetidos da mesma categoria rendem pontuacoes progressivamente menores, incentivando decoracao variada.'),
        'ES': ('Activar Rendimientos Decrecientes', 'Muebles repetidos aportan puntuaciones menores para fomentar decoraciones variadas.'),
        'CN': ('启用家具收益递减', '同类重复家具或装饰品提供的环境分数将逐渐递减，鼓励多样化装饰。'),
        'CH': ('啟用家具收益遞減', '同類重複家具或裝飾品提供的環境分數將逐漸遞減，鼓勵多樣化裝飾。')
    },
    'EnableSkillCheckMinigame': {
        'EN': ('Enable Domestic Skill Check Minigame', 'Enables an active rhythm skill check minigame during maintenance and appliance repair tasks.'),
        'PTBR': ('Ativar Minigame de Teste de Habilidade Doméstica', 'Ativa um teste de reflexo e sincronismo durante tarefas de manutencao, limpeza pesada e reparos eletricos.'),
        'PT': ('Ativar Minigame de Teste de Habilidade Doméstica', 'Ativa um teste de reflexo e sincronismo durante tarefas de manutencao, limpeza pesada e reparos eletricos.'),
        'ES': ('Activar Minijuego de Habilidad Doméstica', 'Activa una prueba de reflejos rítmicos durante reparaciones y mantenimiento de electrodomésticos.'),
        'CN': ('启用家务检定小游戏', '在进行维护和家电修理等任务时触发节奏检定小游戏。'),
        'CH': ('啟用家務檢定小遊戲', '在進行維護和家電修理等任務時觸發節奏檢定小遊戲。')
    },
    'SkillCheckDifficulty': {
        'EN': ('Skill Check Difficulty', 'Adjusts speed and margin of the skill check pointer (1 = Easy, 2 = Normal, 3 = Hard).'),
        'PTBR': ('Dificuldade do Teste de Habilidade', 'Define a velocidade do ponteiro e a largura da zona de acerto (1 = Facil, 2 = Normal, 3 = Dificil).'),
        'PT': ('Dificuldade do Teste de Habilidade', 'Define a velocidade do ponteiro e a largura da zona de acerto (1 = Facil, 2 = Normal, 3 = Dificil).'),
        'ES': ('Dificultad del Minijuego', 'Ajusta la velocidad y el tamaño de la zona de éxito (1 = Fácil, 2 = Normal, 3 = Difícil).'),
        'CN': ('检定小游戏难度', '调节检定指针移动速度与命中判定区域（1 = 简单, 2 = 普通, 3 = 困难）。'),
        'CH': ('檢定小遊戲難度', '調節檢定指針移動速度與命中判定區域（1 = 簡單, 2 = 普通, 3 = 困難）。')
    },
    'EnableMorningRoutine': {
        'EN': ('Enable Morning Routine System', 'Awards comfort and motivation bonuses for waking up early, brushing teeth, and eating breakfast at home.'),
        'PTBR': ('Ativar Rotina Matinal', 'Concede bonus de conforto e motivacao ao acordar cedo, escovar dentes e tomar cafe em casa.'),
        'PT': ('Ativar Rotina Matinal', 'Concede bonus de conforto e motivacao ao acordar cedo, escovar dentes e tomar cafe em casa.'),
        'ES': ('Activar Rutina Matutina', 'Otorga bonificaciones de comodidad y motivación por levantarse temprano, cepillarse los dientes y desayunar en casa.'),
        'CN': ('启用早晨日常系统', '在清晨醒来、刷牙并在家吃早餐时提供舒适感和动力加成。'),
        'CH': ('啟用早晨日常系統', '在清晨醒來、刷牙並在家吃早餐時提供舒適感和動力加成。')
    },
    'EnableRoutineStreaks': {
        'EN': ('Enable Routine Streaks', 'Maintains a daily consecutive streak of completed morning routines with multiplying bonuses.'),
        'PTBR': ('Ativar Sequência de Hábitos (Streaks)', 'Mantem uma sequencia diaria de rotinas concluidas com bonus multiplicativos progressivos.'),
        'PT': ('Ativar Sequência de Hábitos (Streaks)', 'Mantem uma sequencia diaria de rotinas concluidas com bonus multiplicativos progressivos.'),
        'ES': ('Activar Rachas de Hábitos', 'Mantiene una racha diaria de rutinas completadas con bonificaciones multiplicativas.'),
        'CN': ('启用连续日常加成', '保持每日连续完成早晨习惯以获得递增倍数加成。'),
        'CH': ('啟用連續日常加成', '保持每日連續完成早晨習慣以獲得遞增倍數加成。')
    },
    'EnablePassiveDust': {
        'EN': ('Enable Passive Dust Accumulation', 'Closed rooms slowly accumulate a light layer of dust over days if uninhabited or uncleaned.'),
        'PTBR': ('Ativar Poeira Passiva Contínua', 'Comodos acumulam lentamente poeira suave ao longo dos dias caso fiquem sem limpeza.'),
        'PT': ('Ativar Poeira Passiva Contínua', 'Comodos acumulam lentamente poeira suave ao longo dos dias caso fiquem sem limpeza.'),
        'ES': ('Activar Acumulación Pasiva de Polvo', 'Las habitaciones acumulan polvo gradualmente con el paso de los días si no se limpian.'),
        'CN': ('启用被动积灰', '未清洁或无人居住的房间会随着时间缓慢积累灰尘。'),
        'CH': ('啟用被動積灰', '未清潔或無人居住的房間會隨著時間緩慢積累灰塵。')
    },
    'PassiveDustDailyAmount': {
        'EN': ('Daily Dust Accumulation Rate', 'Amount of passive dust percentage generated per game day in rooms.'),
        'PTBR': ('Taxa Diária de Poeira', 'Quantidade percentual de poeira passiva gerada por dia de jogo em cada comodo.'),
        'PT': ('Taxa Diária de Poeira', 'Quantidade percentual de poeira passiva gerada por dia de jogo em cada comodo.'),
        'ES': ('Tasa Diaria de Acumulación de Polvo', 'Porcentaje de polvo pasivo generado por día dentro de las habitaciones.'),
        'CN': ('每日积灰速率', '每个游戏日房间内产生的被动积灰百分比。'),
        'CH': ('每日積灰速率', '每個遊戲日房間內產生的被動積灰百分比。')
    },
    'EnableSpotlessBonus': {
        'EN': ('Enable Spotless Home Bonus', 'Grants extra happiness and mental resilience when the entire residence is 100% clean.'),
        'PTBR': ('Ativar Bônus de Casa Impecável', 'Concede bonus extra de felicidade e resiliencia mental quando o lar esta 100% limpo e higienizado.'),
        'PT': ('Ativar Bônus de Casa Impecável', 'Concede bonus extra de felicidade e resiliencia mental quando o lar esta 100% limpo e higienizado.'),
        'ES': ('Activar Bonificación de Casa Impecable', 'Otorga felicidad adicional y resistencia mental cuando el hogar está 100% limpio.'),
        'CN': ('启用一尘不染加成', '当整个居所达到100%干净时，获得额外的快乐与精神抗性。'),
        'CH': ('啟用一塵不染加成', '當整個居所達到100%乾淨時，獲得額外的快樂與精神抗性。')
    },
    'EnableSeasonalComfort': {
        'EN': ('Enable Seasonal Comfort Modifiers', 'Weather, rain outside, and ambient temperature modulate the psychological comfort of being indoors.'),
        'PTBR': ('Ativar Conforto Sazonal e Clima', 'Chuva externa, tempestades e frio aumentam a sensacao de seguranca e aconchego ao estar protegido dentro de casa.'),
        'PT': ('Ativar Conforto Sazonal e Clima', 'Chuva externa, tempestades e frio aumentam a sensacao de seguranca e aconchego ao estar protegido dentro de casa.'),
        'ES': ('Activar Confort Estacional y Clima', 'El clima exterior, la lluvia y el frío intensifican la sensación de confort al estar protegido bajo techo.'),
        'CN': ('启用季节与天气舒适度调整', '外部的风雨和寒冷天气会增强室内安全与温馨的心理舒适感。'),
        'CH': ('啟用季節與天氣舒適度調整', '外部的風雨和寒冷天氣會增強室內安全與溫馨的心理舒適感。')
    },
    'EnableSocialBonus': {
        'EN': ('Enable Multiplayer Social Comfort Bonus', 'Multiple survivors sharing meals, campfires, or living in the same home gain shared morale boosts.'),
        'PTBR': ('Ativar Bônus Social em Multiplayer', 'Sobreviventes que convivem, cozinham ou dormem na mesma residencia recebem bonus moral compartilhado.'),
        'PT': ('Ativar Bônus Social em Multiplayer', 'Sobreviventes que convivem, cozinham ou dormem na mesma residencia recebem bonus moral compartilhado.'),
        'ES': ('Activar Bonificación Social Multijugador', 'Múltiples supervivientes compartiendo comida o viviendo en el mismo hogar obtienen bonificación compartida.'),
        'CN': ('启用多人社交舒适加成', '在同一居所内共同生活、进餐或围炉的幸存者将获得共享士气加成。'),
        'CH': ('啟用多人社交舒適加成', '在同一居所內共同生活、進餐或圍爐的倖存者將獲得共享士氣加成。')
    },
    'ServerTelemetryEnabled': {
        'EN': ('Enable Server Performance Telemetry', 'Logs periodic performance diagnostics and housing care stats in server console.'),
        'PTBR': ('Ativar Telemetria de Desempenho do Servidor', 'Gera relatorios periodicos de diagnostico e metricas no console do servidor para monitoramento de latencia.'),
        'PT': ('Ativar Telemetria de Desempenho do Servidor', 'Gera relatorios periodicos de diagnostico e metricas no console do servidor para monitoramento de latencia.'),
        'ES': ('Activar Telemetría del Servidor', 'Registra diagnósticos de rendimiento y estadísticas de alojamiento en la consola del servidor.'),
        'CN': ('启用服务器性能遥测', '在服务器控制台中记录定期的性能诊断与住房照护统计。'),
        'CH': ('啟用伺服器性能遙測', '在伺服器控制台中記錄定期的性能診斷與住房照護統計。')
    }
}

def update_ui():
    print("Atualizando traduções de UI...")
    for lang, keys in UI_TRANSLATIONS.items():
        txt_path = f'media/lua/shared/Translate/{lang}/UI_{lang}.txt'
        if os.path.exists(txt_path):
            with open(txt_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
            last_brace = content.rfind('}')
            if last_brace != -1:
                lines_to_add = []
                for k, v in keys.items():
                    if k not in content:
                        lines_to_add.append(f'    ["{k}"] = "{v}",')
                if lines_to_add:
                    new_content = content[:last_brace] + '\n' + '\n'.join(lines_to_add) + '\n' + content[last_brace:]
                    with open(txt_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f'  [+] Atualizado {txt_path} (+{len(lines_to_add)} chaves)')

        json_path = f'media/lua/shared/Translate/{lang}/UI.json'
        if os.path.exists(json_path):
            with open(json_path, 'r', encoding='utf-8', errors='replace') as f:
                try:
                    data = json.load(f)
                except:
                    data = {}
            for k, v in keys.items():
                data[k] = v
            with open(json_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=4, ensure_ascii=False)
            print(f'  [+] Atualizado {json_path}')

def update_sandbox():
    print("Atualizando traduções de Sandbox...")
    langs = ['EN', 'PTBR', 'PT', 'ES', 'CN', 'CH']
    for lang in langs:
        txt_path = f'media/lua/shared/Translate/{lang}/Sandbox_{lang}.txt'
        if not os.path.exists(txt_path):
            continue

        with open(txt_path, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()

        last_brace = content.rfind('}')
        if last_brace == -1:
            continue

        lines_to_add = []
        for opt_key, trans_map in SANDBOX_DEFINITIONS.items():
            name_text, tooltip_text = trans_map.get(lang, trans_map['EN'])
            # Duas chaves: Sandbox_<Key> e Sandbox_HousingCareSystem_<Key>
            k_direct = f'Sandbox_{opt_key}'
            k_pref = f'Sandbox_HousingCareSystem_{opt_key}'

            if k_direct not in content:
                lines_to_add.append(f'    {k_direct} = "{name_text}",')
                lines_to_add.append(f'    {k_direct}_tooltip = "{tooltip_text}",')

            if k_pref not in content:
                lines_to_add.append(f'    {k_pref} = "{name_text}",')
                lines_to_add.append(f'    {k_pref}_tooltip = "{tooltip_text}",')

        if lines_to_add:
            new_content = content[:last_brace] + '\n' + '\n'.join(lines_to_add) + '\n' + content[last_brace:]
            with open(txt_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f'  [+] Atualizado {txt_path} (+{len(lines_to_add)} linhas)')

        # Atualizar Sandbox.json se existir
        json_path = f'media/lua/shared/Translate/{lang}/Sandbox.json'
        if os.path.exists(json_path):
            with open(json_path, 'r', encoding='utf-8', errors='replace') as f:
                try:
                    data = json.load(f)
                except:
                    data = {}
            for opt_key, trans_map in SANDBOX_DEFINITIONS.items():
                name_text, tooltip_text = trans_map.get(lang, trans_map['EN'])
                data[f'Sandbox_{opt_key}'] = name_text
                data[f'Sandbox_{opt_key}_tooltip'] = tooltip_text
                data[f'Sandbox_HousingCareSystem_{opt_key}'] = name_text
                data[f'Sandbox_HousingCareSystem_{opt_key}_tooltip'] = tooltip_text

            with open(json_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=4, ensure_ascii=False)
            print(f'  [+] Atualizado {json_path}')

if __name__ == '__main__':
    update_ui()
    update_sandbox()
    print("Processo de atualização de traduções finalizado com sucesso!")
