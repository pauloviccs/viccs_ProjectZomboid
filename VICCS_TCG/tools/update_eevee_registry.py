import re

# Authentic Pokellector cards map for Eevee Heroes S6a (1 to 101)
# With appropriate rarities (Common, Uncommon, Rare, RR, RRR, SR, HR, UR)
# and Portuguese translations

EEVEE_CARDS_DATA = {
    1: {"name_en": "Pinsir", "name_pt": "Pinsir", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    2: {"name_en": "Leafeon V", "name_pt": "Leafeon V", "rarity_en": "Double Rare", "rarity_pt": "Dupla Rara", "holo": True},
    3: {"name_en": "Leafeon VMAX", "name_pt": "Leafeon VMAX", "rarity_en": "Triple Rare", "rarity_pt": "Tripla Rara", "holo": True},
    4: {"name_en": "Sewaddle", "name_pt": "Sewaddle", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    5: {"name_en": "Swadloon", "name_pt": "Swadloon", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    6: {"name_en": "Leavanny", "name_pt": "Leavanny", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    7: {"name_en": "Dewpider", "name_pt": "Dewpider", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    8: {"name_en": "Araquanid", "name_pt": "Araquanid", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    9: {"name_en": "Gossifleur", "name_pt": "Gossifleur", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    10: {"name_en": "Eldegoss", "name_pt": "Eldegoss", "rarity_en": "Rare", "rarity_pt": "Rara", "holo": True},
    11: {"name_en": "Flareon V", "name_pt": "Flareon V", "rarity_en": "Double Rare", "rarity_pt": "Dupla Rara", "holo": True},
    12: {"name_en": "Slugma", "name_pt": "Slugma", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    13: {"name_en": "Magcargo", "name_pt": "Magcargo", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    14: {"name_en": "Entei", "name_pt": "Entei", "rarity_en": "Rare", "rarity_pt": "Rara", "holo": True},
    15: {"name_en": "Vaporeon V", "name_pt": "Vaporeon V", "rarity_en": "Double Rare", "rarity_pt": "Dupla Rara", "holo": True},
    16: {"name_en": "Marill", "name_pt": "Marill", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    17: {"name_en": "Azumarill", "name_pt": "Azumarill", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    18: {"name_en": "Mantine", "name_pt": "Mantine", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    19: {"name_en": "Mudkip", "name_pt": "Mudkip", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    20: {"name_en": "Marshtomp", "name_pt": "Marshtomp", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    21: {"name_en": "Swampert", "name_pt": "Swampert", "rarity_en": "Rare", "rarity_pt": "Rara", "holo": True},
    22: {"name_en": "Feebas", "name_pt": "Feebas", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    23: {"name_en": "Milotic", "name_pt": "Milotic", "rarity_en": "Rare", "rarity_pt": "Rara", "holo": True},
    24: {"name_en": "Glaceon V", "name_pt": "Glaceon V", "rarity_en": "Double Rare", "rarity_pt": "Dupla Rara", "holo": True},
    25: {"name_en": "Glaceon VMAX", "name_pt": "Glaceon VMAX", "rarity_en": "Triple Rare", "rarity_pt": "Tripla Rara", "holo": True},
    26: {"name_en": "Pikachu", "name_pt": "Pikachu", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    27: {"name_en": "Raichu", "name_pt": "Raichu", "rarity_en": "Rare", "rarity_pt": "Rara", "holo": True},
    28: {"name_en": "Voltorb", "name_pt": "Voltorb", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    29: {"name_en": "Electrode", "name_pt": "Electrode", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    30: {"name_en": "Jolteon V", "name_pt": "Jolteon V", "rarity_en": "Double Rare", "rarity_pt": "Dupla Rara", "holo": True},
    31: {"name_en": "Rotom", "name_pt": "Rotom", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    32: {"name_en": "Tynamo", "name_pt": "Tynamo", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    33: {"name_en": "Eelektrik", "name_pt": "Eelektrik", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    34: {"name_en": "Eelektross", "name_pt": "Eelektross", "rarity_en": "Rare", "rarity_pt": "Rara", "holo": True},
    35: {"name_en": "Espeon V", "name_pt": "Espeon V", "rarity_en": "Double Rare", "rarity_pt": "Dupla Rara", "holo": True},
    36: {"name_en": "Mawile", "name_pt": "Mawile", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    37: {"name_en": "Flabebe", "name_pt": "Flabebe", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    38: {"name_en": "Floette", "name_pt": "Floette", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    39: {"name_en": "Florges", "name_pt": "Florges", "rarity_en": "Rare", "rarity_pt": "Rara", "holo": True},
    40: {"name_en": "Sylveon V", "name_pt": "Sylveon V", "rarity_en": "Double Rare", "rarity_pt": "Dupla Rara", "holo": True},
    41: {"name_en": "Sylveon VMAX", "name_pt": "Sylveon VMAX", "rarity_en": "Triple Rare", "rarity_pt": "Tripla Rara", "holo": True},
    42: {"name_en": "Sandygast", "name_pt": "Sandygast", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    43: {"name_en": "Palossand", "name_pt": "Palossand", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    44: {"name_en": "Marshadow", "name_pt": "Marshadow", "rarity_en": "Rare", "rarity_pt": "Rara", "holo": True},
    45: {"name_en": "Indeedee", "name_pt": "Indeedee", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    46: {"name_en": "Pancham", "name_pt": "Pancham", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    47: {"name_en": "Umbreon V", "name_pt": "Umbreon V", "rarity_en": "Double Rare", "rarity_pt": "Dupla Rara", "holo": True},
    48: {"name_en": "Umbreon VMAX", "name_pt": "Umbreon VMAX", "rarity_en": "Triple Rare", "rarity_pt": "Tripla Rara", "holo": True},
    49: {"name_en": "Zorua", "name_pt": "Zorua", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    50: {"name_en": "Zoroark", "name_pt": "Zoroark", "rarity_en": "Rare", "rarity_pt": "Rara", "holo": True},
    51: {"name_en": "Pangoro", "name_pt": "Pangoro", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    52: {"name_en": "Impidimp", "name_pt": "Impidimp", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    53: {"name_en": "Morgrem", "name_pt": "Morgrem", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    54: {"name_en": "Grimmsnarl", "name_pt": "Grimmsnarl", "rarity_en": "Rare", "rarity_pt": "Rara", "holo": True},
    55: {"name_en": "Meowth", "name_pt": "Meowth", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    56: {"name_en": "Persian", "name_pt": "Persian", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    57: {"name_en": "Kangaskhan", "name_pt": "Kangaskhan", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    58: {"name_en": "Eevee", "name_pt": "Eevee", "rarity_en": "Common", "rarity_pt": "Comum", "holo": False},
    59: {"name_en": "Smeargle", "name_pt": "Smeargle", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    60: {"name_en": "Boost Shake", "name_pt": "Frasco de Impulso", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    61: {"name_en": "Dream Ball", "name_pt": "Bola dos Sonhos", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    62: {"name_en": "Elemental Badge", "name_pt": "Insignia Elemental", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    63: {"name_en": "Snow Leaf Badge", "name_pt": "Insignia Folha de Neve", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    64: {"name_en": "Moon & Sun Badge", "name_pt": "Insignia Lua e Sol", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    65: {"name_en": "Ribbon Badge", "name_pt": "Insignia de Fita", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    66: {"name_en": "Aroma Lady", "name_pt": "Dama dos Aromas", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    67: {"name_en": "Gordie", "name_pt": "Gordie", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    68: {"name_en": "Shopping Center", "name_pt": "Centro Comercial", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    69: {"name_en": "Treasure Energy", "name_pt": "Energia do Tesouro", "rarity_en": "Uncommon", "rarity_pt": "Incomum", "holo": False},
    70: {"name_en": "Leafeon V (SR)", "name_pt": "Leafeon V (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    71: {"name_en": "Leafeon V Alt Art (SR)", "name_pt": "Leafeon V Arte Alternativa (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    72: {"name_en": "Flareon V (SR)", "name_pt": "Flareon V (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    73: {"name_en": "Flareon V Alt Art (SR)", "name_pt": "Flareon V Arte Alternativa (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    74: {"name_en": "Vaporeon V (SR)", "name_pt": "Vaporeon V (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    75: {"name_en": "Vaporeon V Alt Art (SR)", "name_pt": "Vaporeon V Arte Alternativa (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    76: {"name_en": "Glaceon V (SR)", "name_pt": "Glaceon V (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    77: {"name_en": "Glaceon V Alt Art (SR)", "name_pt": "Glaceon V Arte Alternativa (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    78: {"name_en": "Jolteon V (SR)", "name_pt": "Jolteon V (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    79: {"name_en": "Jolteon V Alt Art (SR)", "name_pt": "Jolteon V Arte Alternativa (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    80: {"name_en": "Espeon V (SR)", "name_pt": "Espeon V (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    81: {"name_en": "Espeon V Alt Art (SR)", "name_pt": "Espeon V Arte Alternativa (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    82: {"name_en": "Sylveon V (SR)", "name_pt": "Sylveon V (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    83: {"name_en": "Sylveon V Alt Art (SR)", "name_pt": "Sylveon V Arte Alternativa (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    84: {"name_en": "Umbreon V (SR)", "name_pt": "Umbreon V (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    85: {"name_en": "Umbreon V Alt Art (SR)", "name_pt": "Umbreon V Arte Alternativa (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    86: {"name_en": "Aroma Lady (SR)", "name_pt": "Dama dos Aromas (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    87: {"name_en": "Gordie (SR)", "name_pt": "Gordie (SR)", "rarity_en": "Super Rare", "rarity_pt": "Super Rara", "holo": True},
    88: {"name_en": "Leafeon VMAX (HR)", "name_pt": "Leafeon VMAX (HR)", "rarity_en": "Hyper Rare", "rarity_pt": "Hiper Rara", "holo": True},
    89: {"name_en": "Leafeon VMAX Alt Art (HR)", "name_pt": "Leafeon VMAX Arte Alternativa (HR)", "rarity_en": "Hyper Rare", "rarity_pt": "Hiper Rara", "holo": True},
    90: {"name_en": "Glaceon VMAX (HR)", "name_pt": "Glaceon VMAX (HR)", "rarity_en": "Hyper Rare", "rarity_pt": "Hiper Rara", "holo": True},
    91: {"name_en": "Glaceon VMAX Alt Art (HR)", "name_pt": "Glaceon VMAX Arte Alternativa (HR)", "rarity_en": "Hyper Rare", "rarity_pt": "Hiper Rara", "holo": True},
    92: {"name_en": "Sylveon VMAX (HR)", "name_pt": "Sylveon VMAX (HR)", "rarity_en": "Hyper Rare", "rarity_pt": "Hiper Rara", "holo": True},
    93: {"name_en": "Sylveon VMAX Alt Art (HR)", "name_pt": "Sylveon VMAX Arte Alternativa (HR)", "rarity_en": "Hyper Rare", "rarity_pt": "Hiper Rara", "holo": True},
    94: {"name_en": "Umbreon VMAX (HR)", "name_pt": "Umbreon VMAX (HR)", "rarity_en": "Hyper Rare", "rarity_pt": "Hiper Rara", "holo": True},
    95: {"name_en": "Umbreon VMAX Alt Art (HR)", "name_pt": "Umbreon VMAX Arte Alternativa (HR)", "rarity_en": "Hyper Rare", "rarity_pt": "Hiper Rara", "holo": True},
    96: {"name_en": "Aroma Lady (HR)", "name_pt": "Dama dos Aromas (HR)", "rarity_en": "Hyper Rare", "rarity_pt": "Hiper Rara", "holo": True},
    97: {"name_en": "Gordie (HR)", "name_pt": "Gordie (HR)", "rarity_en": "Hyper Rare", "rarity_pt": "Hiper Rara", "holo": True},
    98: {"name_en": "Inteleon (UR)", "name_pt": "Inteleon Dourado (UR)", "rarity_en": "Ultra Rare", "rarity_pt": "Ultra Rara", "holo": True},
    99: {"name_en": "Boost Shake (UR)", "name_pt": "Frasco de Impulso Dourado (UR)", "rarity_en": "Ultra Rare", "rarity_pt": "Ultra Rara", "holo": True},
    100: {"name_en": "Turffield Stadium (UR)", "name_pt": "Estadio Turffield Dourado (UR)", "rarity_en": "Ultra Rare", "rarity_pt": "Ultra Rara", "holo": True},
    101: {"name_en": "Darkness Energy (UR)", "name_pt": "Energia Sombria Dourada (UR)", "rarity_en": "Ultra Rare", "rarity_pt": "Ultra Rara", "holo": True}
}

def generate_eevee_lua_block():
    lines = []
    lines.append('TCG_CardRegistry.Sets["eeveeheroes"] = {')
    lines.append('    id = "eeveeheroes",')
    lines.append('    name = { en = "Eevee Heroes (2021)", pt = "Colecao Eevee Heroes (Japao 2021)" },')
    lines.append('    total = 101,')
    lines.append('    cards = {')
    
    for num in range(1, 102):
        d = EEVEE_CARDS_DATA[num]
        card_id = f"eeveeheroes-{num:03d}"
        tex = f"media/textures/cards/eeveeheroes/{num:03d}.png"
        is_holo_str = "true" if d["holo"] else "false"
        
        lines.append(f'        ["{card_id}"] = {{')
        lines.append(f'            id = "{card_id}",')
        lines.append(f'            number = {num},')
        lines.append(f'            name = {{ en = "{d["name_en"]}", pt = "{d["name_pt"]}" }},')
        lines.append(f'            rarity = {{ en = "{d["rarity_en"]}", pt = "{d["rarity_pt"]}" }},')
        lines.append(f'            isHolo = {is_holo_str},')
        lines.append(f'            texture = "{tex}",')
        lines.append('            setId = "eeveeheroes"')
        if num == 101:
            lines.append('        }')
        else:
            lines.append('        },')
    
    lines.append('    }')
    lines.append('}')
    return '\n'.join(lines)

def update_file():
    path = "media/lua/shared/TCG_CardRegistry_Expansions.lua"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    marker = 'TCG_CardRegistry.Sets["eeveeheroes"] = {'
    idx = content.find(marker)
    if idx == -1:
        print("[!] Marker not found")
        return
    
    prefix = content[:idx]
    new_eevee = generate_eevee_lua_block()
    full_new = prefix + new_eevee + "\n"
    
    with open(path, "w", encoding="utf-8") as f:
        f.write(full_new)
    print("[+] Successfully updated Eevee Heroes registry with authentic cards!")

if __name__ == "__main__":
    update_file()
