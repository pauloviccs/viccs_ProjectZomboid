"""
=============================================================================
Gerador de Registros das Expansões TCG (Jungle, Fossil e Team Rocket)
Gera: media/lua/shared/TCG_CardRegistry_Expansions.lua
=============================================================================
"""
from pathlib import Path

jungle_cards = [
    (1, 'Clefable', 'Rare Holo', True), (2, 'Electrode', 'Rare Holo', True),
    (3, 'Flareon', 'Rare Holo', True), (4, 'Jolteon', 'Rare Holo', True),
    (5, 'Kangaskhan', 'Rare Holo', True), (6, 'Mr. Mime', 'Rare Holo', True),
    (7, 'Nidoqueen', 'Rare Holo', True), (8, 'Pidgeot', 'Rare Holo', True),
    (9, 'Pinsir', 'Rare Holo', True), (10, 'Scyther', 'Rare Holo', True),
    (11, 'Snorlax', 'Rare Holo', True), (12, 'Vaporeon', 'Rare Holo', True),
    (13, 'Venomoth', 'Rare Holo', True), (14, 'Victreebel', 'Rare Holo', True),
    (15, 'Vileplume', 'Rare Holo', True), (16, 'Wigglytuff', 'Rare Holo', True),
    (17, 'Clefable', 'Rare', False), (18, 'Electrode', 'Rare', False),
    (19, 'Flareon', 'Rare', False), (20, 'Jolteon', 'Rare', False),
    (21, 'Kangaskhan', 'Rare', False), (22, 'Mr. Mime', 'Rare', False),
    (23, 'Nidoqueen', 'Rare', False), (24, 'Pidgeot', 'Rare', False),
    (25, 'Pinsir', 'Rare', False), (26, 'Scyther', 'Rare', False),
    (27, 'Snorlax', 'Rare', False), (28, 'Vaporeon', 'Rare', False),
    (29, 'Venomoth', 'Rare', False), (30, 'Victreebel', 'Rare', False),
    (31, 'Vileplume', 'Rare', False), (32, 'Wigglytuff', 'Rare', False),
    (33, 'Butterfree', 'Uncommon', False), (34, 'Dodrio', 'Uncommon', False),
    (35, 'Exeggutor', 'Uncommon', False), (36, 'Fearow', 'Uncommon', False),
    (37, 'Gloom', 'Uncommon', False), (38, 'Lickitung', 'Uncommon', False),
    (39, 'Marowak', 'Uncommon', False), (40, 'Nidorina', 'Uncommon', False),
    (41, 'Parasect', 'Uncommon', False), (42, 'Persian', 'Uncommon', False),
    (43, 'Primeape', 'Uncommon', False), (44, 'Rapidash', 'Uncommon', False),
    (45, 'Rhydon', 'Uncommon', False), (46, 'Seaking', 'Uncommon', False),
    (47, 'Tauros', 'Uncommon', False), (48, 'Weepinbell', 'Uncommon', False),
    (49, 'Bellsprout', 'Common', False), (50, 'Cubone', 'Common', False),
    (51, 'Eevee', 'Common', False), (52, 'Exeggcute', 'Common', False),
    (53, 'Goldeen', 'Common', False), (54, 'Jigglypuff', 'Common', False),
    (55, 'Mankey', 'Common', False), (56, 'Meowth', 'Common', False),
    (57, 'Nidoran F', 'Common', False), (58, 'Oddish', 'Common', False),
    (59, 'Paras', 'Common', False), (60, 'Pikachu', 'Common', False),
    (61, 'Rhyhorn', 'Common', False), (62, 'Spearow', 'Common', False),
    (63, 'Venonat', 'Common', False), (64, 'Poke Ball', 'Common', False)
]

fossil_cards = [
    (1, 'Aerodactyl', 'Rare Holo', True), (2, 'Articuno', 'Rare Holo', True),
    (3, 'Ditto', 'Rare Holo', True), (4, 'Dragonite', 'Rare Holo', True),
    (5, 'Gengar', 'Rare Holo', True), (6, 'Haunter', 'Rare Holo', True),
    (7, 'Hitmonlee', 'Rare Holo', True), (8, 'Hypno', 'Rare Holo', True),
    (9, 'Kabutops', 'Rare Holo', True), (10, 'Lapras', 'Rare Holo', True),
    (11, 'Magneton', 'Rare Holo', True), (12, 'Moltres', 'Rare Holo', True),
    (13, 'Muk', 'Rare Holo', True), (14, 'Raichu', 'Rare Holo', True),
    (15, 'Zapdos', 'Rare Holo', True), (16, 'Aerodactyl', 'Rare', False),
    (17, 'Articuno', 'Rare', False), (18, 'Ditto', 'Rare', False),
    (19, 'Dragonite', 'Rare', False), (20, 'Gengar', 'Rare', False),
    (21, 'Haunter', 'Rare', False), (22, 'Hitmonlee', 'Rare', False),
    (23, 'Hypno', 'Rare', False), (24, 'Kabutops', 'Rare', False),
    (25, 'Lapras', 'Rare', False), (26, 'Magneton', 'Rare', False),
    (27, 'Moltres', 'Rare', False), (28, 'Muk', 'Rare', False),
    (29, 'Raichu', 'Rare', False), (30, 'Zapdos', 'Rare', False),
    (31, 'Arbok', 'Rare', False), (32, 'Cloyster', 'Uncommon', False),
    (33, 'Gastly', 'Uncommon', False), (34, 'Golbat', 'Uncommon', False),
    (35, 'Golduck', 'Uncommon', False), (36, 'Golem', 'Uncommon', False),
    (37, 'Graveler', 'Uncommon', False), (38, 'Kingler', 'Uncommon', False),
    (39, 'Magmar', 'Uncommon', False), (40, 'Omanyte', 'Uncommon', False),
    (41, 'Omastar', 'Uncommon', False), (42, 'Sandslash', 'Uncommon', False),
    (43, 'Seadra', 'Uncommon', False), (44, 'Slowbro', 'Uncommon', False),
    (45, 'Tentacruel', 'Uncommon', False), (46, 'Ekans', 'Common', False),
    (47, 'Geodude', 'Common', False), (48, 'Grimer', 'Common', False),
    (49, 'Horsea', 'Common', False), (50, 'Kabuto', 'Common', False),
    (51, 'Krabby', 'Common', False), (52, 'Omanyte', 'Common', False),
    (53, 'Psyduck', 'Common', False), (54, 'Shellder', 'Common', False),
    (55, 'Slowpoke', 'Common', False), (56, 'Tentacool', 'Common', False),
    (57, 'Zubat', 'Common', False), (58, 'Energy Search', 'Common', False),
    (59, 'Gambler', 'Common', False), (60, 'Recycle', 'Common', False),
    (61, 'Mysterious Fossil', 'Common', False), (62, 'Fossil Excavator', 'Uncommon', False)
]

rocket_cards = [
    (1, 'Dark Alakazam', 'Rare Holo', True), (2, 'Dark Arbok', 'Rare Holo', True),
    (3, 'Dark Blastoise', 'Rare Holo', True), (4, 'Dark Charizard', 'Rare Holo', True),
    (5, 'Dark Dragonite', 'Rare Holo', True), (6, 'Dark Dugtrio', 'Rare Holo', True),
    (7, 'Dark Golbat', 'Rare Holo', True), (8, 'Dark Gyarados', 'Rare Holo', True),
    (9, 'Dark Hypno', 'Rare Holo', True), (10, 'Dark Machamp', 'Rare Holo', True),
    (11, 'Dark Magneton', 'Rare Holo', True), (12, 'Dark Slowbro', 'Rare Holo', True),
    (13, 'Dark Vileplume', 'Rare Holo', True), (14, 'Dark Weezing', 'Rare Holo', True),
    (15, 'Here Comes Team Rocket!', 'Rare Holo', True), (16, 'Rocket Sneak Attack', 'Rare Holo', True),
    (17, 'Rainbow Energy', 'Rare Holo', True), (18, 'Dark Alakazam', 'Rare', False),
    (19, 'Dark Arbok', 'Rare', False), (20, 'Dark Blastoise', 'Rare', False),
    (21, 'Dark Charizard', 'Rare', False), (22, 'Dark Dragonite', 'Rare', False),
    (23, 'Dark Dugtrio', 'Rare', False), (24, 'Dark Golbat', 'Rare', False),
    (25, 'Dark Gyarados', 'Rare', False), (26, 'Dark Hypno', 'Rare', False),
    (27, 'Dark Machamp', 'Rare', False), (28, 'Dark Magneton', 'Rare', False),
    (29, 'Dark Slowbro', 'Rare', False), (30, 'Dark Vileplume', 'Rare', False),
    (31, 'Dark Weezing', 'Rare', False), (32, 'Dark Charmeleon', 'Uncommon', False),
    (33, 'Dark Dragonair', 'Uncommon', False), (34, 'Dark Electrode', 'Uncommon', False),
    (35, 'Dark Flareon', 'Uncommon', False), (36, 'Dark Gloom', 'Uncommon', False),
    (37, 'Dark Golduck', 'Uncommon', False), (38, 'Dark Jolteon', 'Uncommon', False),
    (39, 'Dark Kadabra', 'Uncommon', False), (40, 'Dark Machoke', 'Uncommon', False),
    (41, 'Dark Muk', 'Uncommon', False), (42, 'Dark Persian', 'Uncommon', False),
    (43, 'Dark Primeape', 'Uncommon', False), (44, 'Dark Rapidash', 'Uncommon', False),
    (45, 'Dark Vaporeon', 'Uncommon', False), (46, 'Dark Wartortle', 'Uncommon', False),
    (47, 'Magikarp', 'Uncommon', False), (48, 'Porygon', 'Uncommon', False),
    (49, 'Super Energy Retrieval', 'Uncommon', False), (50, 'Challenge!', 'Uncommon', False),
    (51, 'Abra', 'Common', False), (52, 'Charmander', 'Common', False),
    (53, 'Diglett', 'Common', False), (54, 'Drowzee', 'Common', False),
    (55, 'Eevee', 'Common', False), (56, 'Ekans', 'Common', False),
    (57, 'Grimer', 'Common', False), (58, 'Koffing', 'Common', False),
    (59, 'Machop', 'Common', False), (60, 'Magnemite', 'Common', False),
    (61, 'Mankey', 'Common', False), (62, 'Meowth', 'Common', False),
    (63, 'Oddish', 'Common', False), (64, 'Ponyta', 'Common', False),
    (65, 'Psyduck', 'Common', False), (66, 'Rattata', 'Common', False),
    (67, 'Slowpoke', 'Common', False), (68, 'Squirtle', 'Common', False),
    (69, 'Voltorb', 'Common', False), (70, 'Zubat', 'Common', False),
    (71, 'Here Comes Team Rocket!', 'Rare', False), (72, 'Rocket Sneak Attack', 'Rare', False),
    (73, 'The Boss Way', 'Uncommon', False), (74, 'Goop Gas Attack', 'Common', False),
    (75, 'Sleep!', 'Common', False), (76, 'Digger', 'Uncommon', False),
    (77, 'Nightly Garbage Run', 'Uncommon', False), (78, 'Potion Energy', 'Uncommon', False),
    (79, 'Full Heal Energy', 'Uncommon', False), (80, 'Rainbow Energy', 'Rare', False),
    (81, 'Rocket Training Gym', 'Uncommon', False), (82, 'Rocket Secret Machine', 'Uncommon', False),
    (83, 'Dark Raichu', 'Rare Holo', True)
]

rarity_pt = {
    'Common': 'Comum',
    'Uncommon': 'Incomum',
    'Rare': 'Rara',
    'Rare Holo': 'Rara Holografica'
}

eeveeheroes_cards = [
    (1, 'Oddish', 'Common', False), (2, 'Gloom', 'Uncommon', False),
    (3, 'Vileplume', 'Rare', False), (4, 'Bellsprout', 'Common', False),
    (5, 'Weepinbell', 'Uncommon', False), (6, 'Victreebel', 'Rare', False),
    (7, 'Tangela', 'Common', False), (8, 'Tangrowth', 'Uncommon', False),
    (9, 'Petilil', 'Common', False), (10, 'Lilligant', 'Uncommon', False),
    (11, 'Leafeon V', 'Rare Holo', True), (12, 'Leafeon VMAX', 'Rare Holo', True),
    (13, 'Flareon V', 'Rare Holo', True), (14, 'Vaporeon V', 'Rare Holo', True),
    (15, 'Marill', 'Common', False), (16, 'Azumarill', 'Uncommon', False),
    (17, 'Feebas', 'Common', False), (18, 'Milotic', 'Rare', False),
    (19, 'Glaceon V', 'Rare Holo', True), (20, 'Glaceon VMAX', 'Rare Holo', True),
    (21, 'Jolteon V', 'Rare Holo', True), (22, 'Chinchou', 'Common', False),
    (23, 'Lanturn', 'Uncommon', False), (24, 'Espeon V', 'Rare Holo', True),
    (25, 'Unown', 'Common', False), (26, 'Wobbuffet', 'Common', False),
    (27, 'Woobat', 'Common', False), (28, 'Swoobat', 'Uncommon', False),
    (29, 'Flabebe', 'Common', False), (30, 'Floette', 'Common', False),
    (31, 'Florges', 'Rare', False), (32, 'Sylveon V', 'Rare Holo', True),
    (33, 'Sylveon VMAX', 'Rare Holo', True), (34, 'Hitmonlee', 'Common', False),
    (35, 'Hitmonchan', 'Common', False), (36, 'Hitmontop', 'Uncommon', False),
    (37, 'Makuhita', 'Common', False), (38, 'Hariyama', 'Uncommon', False),
    (39, 'Roggenrola', 'Common', False), (40, 'Boldore', 'Common', False),
    (41, 'Gigalith', 'Rare', False), (42, 'Rockruff', 'Common', False),
    (43, 'Lycanroc', 'Rare', False), (44, 'Galarian Meowth', 'Common', False),
    (45, 'Galarian Perrserker', 'Uncommon', False), (46, 'Umbreon V', 'Rare Holo', True),
    (47, 'Umbreon VMAX', 'Rare Holo', True), (48, 'Carvanha', 'Common', False),
    (49, 'Sharpedo', 'Uncommon', False), (50, 'Zorua', 'Common', False),
    (51, 'Zoroark', 'Rare', False), (52, 'Pidgey', 'Common', False),
    (53, 'Pidgeotto', 'Common', False), (54, 'Pidgeot', 'Rare', False),
    (55, 'Eevee', 'Common', False), (56, 'Smeargle', 'Common', False),
    (57, 'Zigzagoon', 'Common', False), (58, 'Linoone', 'Common', False),
    (59, 'Obstagoon', 'Rare', False), (60, 'Aroma Lady', 'Uncommon', False),
    (61, 'Elemental Badge', 'Uncommon', False), (62, 'Gordie', 'Uncommon', False),
    (63, 'Raihan', 'Uncommon', False), (64, 'Moon and Sun Badge', 'Uncommon', False),
    (65, 'Ribbon Badge', 'Uncommon', False), (66, 'Snow Leaf Badge', 'Uncommon', False),
    (67, 'Vigor Shake', 'Uncommon', False), (68, 'Boost Shake', 'Uncommon', False),
    (69, 'Rescue Carrier', 'Uncommon', False), (70, 'Leafeon V (SR)', 'Rare Holo', True),
    (71, 'Leafeon V Alt Art (SR)', 'Rare Holo', True), (72, 'Flareon V (SR)', 'Rare Holo', True),
    (73, 'Vaporeon V (SR)', 'Rare Holo', True), (74, 'Glaceon V (SR)', 'Rare Holo', True),
    (75, 'Glaceon V Alt Art (SR)', 'Rare Holo', True), (76, 'Jolteon V (SR)', 'Rare Holo', True),
    (77, 'Espeon V (SR)', 'Rare Holo', True), (78, 'Espeon V Alt Art (SR)', 'Rare Holo', True),
    (79, 'Sylveon V (SR)', 'Rare Holo', True), (80, 'Sylveon V Alt Art (SR)', 'Rare Holo', True),
    (81, 'Umbreon V (SR)', 'Rare Holo', True), (82, 'Umbreon V Alt Art (SR)', 'Rare Holo', True),
    (83, 'Gordie (SR)', 'Rare Holo', True), (84, 'Aroma Lady (SR)', 'Rare Holo', True),
    (85, 'Raihan (SR)', 'Rare Holo', True), (86, 'Leafeon VMAX (HR)', 'Rare Holo', True),
    (87, 'Leafeon VMAX Alt Art (HR)', 'Rare Holo', True), (88, 'Glaceon VMAX (HR)', 'Rare Holo', True),
    (89, 'Glaceon VMAX Alt Art (HR)', 'Rare Holo', True), (90, 'Sylveon VMAX (HR)', 'Rare Holo', True),
    (91, 'Sylveon VMAX Alt Art (HR)', 'Rare Holo', True), (92, 'Umbreon VMAX (HR)', 'Rare Holo', True),
    (93, 'Umbreon VMAX Alt Art (HR)', 'Rare Holo', True), (94, 'Gordie (HR)', 'Rare Holo', True),
    (95, 'Aroma Lady (HR)', 'Rare Holo', True), (96, 'Raihan (HR)', 'Rare Holo', True),
    (97, 'Boost Shake (UR)', 'Rare Holo', True), (98, 'Rescue Carrier (UR)', 'Rare Holo', True),
    (99, 'Elemental Badge (UR)', 'Rare Holo', True), (100, 'Darkness Energy (UR)', 'Rare Holo', True),
    (101, 'Inteleon (UR)', 'Rare Holo', True)
]

def generate_set_lua(set_id, set_name_en, set_name_pt, cards):
    lines = []
    lines.append(f'TCG_CardRegistry.Sets["{set_id}"] = {{')
    lines.append(f'    id = "{set_id}",')
    lines.append(f'    name = {{ en = "{set_name_en}", pt = "{set_name_pt}" }},')
    lines.append(f'    total = {len(cards)},')
    lines.append('    cards = {')
    for num, name, rarity, is_holo in cards:
        cid = f'{set_id}-{num:03d}'
        holo_str = 'true' if is_holo else 'false'
        rpt = rarity_pt.get(rarity, 'Comum')
        lines.append(f'        ["{cid}"] = {{')
        lines.append(f'            id = "{cid}",')
        lines.append(f'            number = {num},')
        lines.append(f'            name = {{ en = "{name}", pt = "{name}" }},')
        lines.append(f'            rarity = {{ en = "{rarity}", pt = "{rpt}" }},')
        lines.append(f'            isHolo = {holo_str},')
        lines.append(f'            texture = "media/textures/cards/{set_id}/{num:03d}.png",')
        lines.append(f'            setId = "{set_id}"')
        lines.append('        },')
    lines.append('    }')
    lines.append('}\n')
    return '\n'.join(lines)

base_dir = Path(__file__).resolve().parent.parent
out_path = base_dir / 'media' / 'lua' / 'shared' / 'TCG_CardRegistry_Expansions.lua'
content = [
    '-- =============================================================================',
    '-- Project Zomboid TCG - Expansion Sets Registry (Jungle, Fossil, Team Rocket, Eevee Heroes)',
    '-- =============================================================================\n',
    'require "TCG_Config"\n',
    'TCG_CardRegistry = TCG_CardRegistry or {}',
    'TCG_CardRegistry.Sets = TCG_CardRegistry.Sets or {}\n',
    generate_set_lua('jungle', 'Jungle (1999)', 'Colecao Jungle (1999)', jungle_cards),
    generate_set_lua('fossil', 'Fossil (1999)', 'Colecao Fossil (1999)', fossil_cards),
    generate_set_lua('rocket', 'Team Rocket (2000)', 'Colecao Equipe Rocket (2000)', rocket_cards),
    generate_set_lua('eeveeheroes', 'Eevee Heroes (2021)', 'Colecao Eevee Heroes (Japao 2021)', eeveeheroes_cards),
]

out_path.write_text('\n'.join(content), encoding='ascii')
print('TCG_CardRegistry_Expansions.lua generated with all 4 sets and', len(jungle_cards) + len(fossil_cards) + len(rocket_cards) + len(eeveeheroes_cards), 'cards!')
