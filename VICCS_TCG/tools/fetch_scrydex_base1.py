"""
=============================================================================
Scrydex Base Set 1999 Ingestion & Pre-processor Tool (Bilingual Edition)
Mod: VICCS_TCG (Project Zomboid)
=============================================================================
Descricao:
  - Catalogo oficial bilingue (Ingles e Portugues do Brasil - Devir/Copag 1999).
  - Gera media/lua/shared/TCG_CardRegistry.lua com nomes e raridades em PT e EN.
  - Baixa texturas das cartas e otimiza para 240x336 pixels.
=============================================================================
"""

import os
import sys
import json
import argparse
import urllib.request
import urllib.error
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
OUTPUT_LUA = BASE_DIR / "media" / "lua" / "shared" / "TCG_CardRegistry.lua"
TEXTURES_DIR = BASE_DIR / "media" / "textures" / "cards" / "base1"

# Dicionario oficial de traducao PT-BR (Devir/Copag) para as cartas de 1999
PT_TRANSLATIONS = {
    # Treinadores (70-95)
    70: "Boneca de Clefairy",
    71: "Pesquisa no Computador",
    72: "Spray de Devolucao",
    73: "Falso Professor Carvalho",
    74: "Localizador de Itens",
    75: "Garota",
    76: "Criador de Pokemon",
    77: "Negociador de Pokemon",
    78: "Recolhida",
    79: "Super Remocao de Energia",
    80: "Defensor",
    81: "Recuperacao de Energia",
    82: "Cura Total",
    83: "Manutencao",
    84: "Forca Extra",
    85: "Centro Pokemon",
    86: "Flauta Pokemon",
    87: "Pokedex",
    88: "Professor Carvalho",
    89: "Reviver",
    90: "Superpocao",
    91: "Beto (Bill)",
    92: "Remocao de Energia",
    93: "Golpe de Vento",
    94: "Pocao",
    95: "Troca",
    # Energias (96-102)
    96: "Energia Dupla Incolor",
    97: "Energia de Luta",
    98: "Energia de Fogo",
    99: "Energia de Planta",
    100: "Energia de Relampago",
    101: "Energia Psiquica",
    102: "Energia de Agua"
}

RARITY_TRANSLATIONS = {
    "Common": "Comum",
    "Uncommon": "Incomum",
    "Rare": "Rara",
    "Rare Holo": "Rara Holografica"
}

BASE1_SEED_CATALOG = [
    {"num": 1, "name": "Alakazam", "rarity": "Rare Holo"},
    {"num": 2, "name": "Blastoise", "rarity": "Rare Holo"},
    {"num": 3, "name": "Chansey", "rarity": "Rare Holo"},
    {"num": 4, "name": "Charizard", "rarity": "Rare Holo"},
    {"num": 5, "name": "Clefairy", "rarity": "Rare Holo"},
    {"num": 6, "name": "Gyarados", "rarity": "Rare Holo"},
    {"num": 7, "name": "Hitmonchan", "rarity": "Rare Holo"},
    {"num": 8, "name": "Machamp", "rarity": "Rare Holo"},
    {"num": 9, "name": "Magneton", "rarity": "Rare Holo"},
    {"num": 10, "name": "Mewtwo", "rarity": "Rare Holo"},
    {"num": 11, "name": "Nidoking", "rarity": "Rare Holo"},
    {"num": 12, "name": "Ninetales", "rarity": "Rare Holo"},
    {"num": 13, "name": "Poliwrath", "rarity": "Rare Holo"},
    {"num": 14, "name": "Raichu", "rarity": "Rare Holo"},
    {"num": 15, "name": "Venusaur", "rarity": "Rare Holo"},
    {"num": 16, "name": "Zapdos", "rarity": "Rare Holo"},
    {"num": 17, "name": "Beedrill", "rarity": "Rare"},
    {"num": 18, "name": "Dragonair", "rarity": "Rare"},
    {"num": 19, "name": "Dugtrio", "rarity": "Rare"},
    {"num": 20, "name": "Electabuzz", "rarity": "Rare"},
    {"num": 21, "name": "Electrode", "rarity": "Rare"},
    {"num": 22, "name": "Pidgeotto", "rarity": "Rare"},
    {"num": 23, "name": "Arcanine", "rarity": "Uncommon"},
    {"num": 24, "name": "Charmeleon", "rarity": "Uncommon"},
    {"num": 25, "name": "Dewgong", "rarity": "Uncommon"},
    {"num": 26, "name": "Dratini", "rarity": "Uncommon"},
    {"num": 27, "name": "Farfetch'd", "rarity": "Uncommon"},
    {"num": 28, "name": "Growlithe", "rarity": "Uncommon"},
    {"num": 29, "name": "Haunter", "rarity": "Uncommon"},
    {"num": 30, "name": "Ivysaur", "rarity": "Uncommon"},
    {"num": 31, "name": "Jynx", "rarity": "Uncommon"},
    {"num": 32, "name": "Kadabra", "rarity": "Uncommon"},
    {"num": 33, "name": "Kakuna", "rarity": "Uncommon"},
    {"num": 34, "name": "Machoke", "rarity": "Uncommon"},
    {"num": 35, "name": "Magikarp", "rarity": "Uncommon"},
    {"num": 36, "name": "Magmar", "rarity": "Uncommon"},
    {"num": 37, "name": "Nidorino", "rarity": "Uncommon"},
    {"num": 38, "name": "Poliwhirl", "rarity": "Uncommon"},
    {"num": 39, "name": "Porygon", "rarity": "Uncommon"},
    {"num": 40, "name": "Raticate", "rarity": "Uncommon"},
    {"num": 41, "name": "Seel", "rarity": "Uncommon"},
    {"num": 42, "name": "Wartortle", "rarity": "Uncommon"},
    {"num": 43, "name": "Abra", "rarity": "Common"},
    {"num": 44, "name": "Bulbasaur", "rarity": "Common"},
    {"num": 45, "name": "Caterpie", "rarity": "Common"},
    {"num": 46, "name": "Charmander", "rarity": "Common"},
    {"num": 47, "name": "Diglett", "rarity": "Common"},
    {"num": 48, "name": "Doduo", "rarity": "Common"},
    {"num": 49, "name": "Drowzee", "rarity": "Common"},
    {"num": 50, "name": "Gastly", "rarity": "Common"},
    {"num": 51, "name": "Koffing", "rarity": "Common"},
    {"num": 52, "name": "Machop", "rarity": "Common"},
    {"num": 53, "name": "Magnemite", "rarity": "Common"},
    {"num": 54, "name": "Metapod", "rarity": "Common"},
    {"num": 55, "name": "Nidoran M", "rarity": "Common"},
    {"num": 56, "name": "Onix", "rarity": "Common"},
    {"num": 57, "name": "Pidgey", "rarity": "Common"},
    {"num": 58, "name": "Pikachu", "rarity": "Common"},
    {"num": 59, "name": "Poliwag", "rarity": "Common"},
    {"num": 60, "name": "Ponyta", "rarity": "Common"},
    {"num": 61, "name": "Rattata", "rarity": "Common"},
    {"num": 62, "name": "Sandshrew", "rarity": "Common"},
    {"num": 63, "name": "Squirtle", "rarity": "Common"},
    {"num": 64, "name": "Starmie", "rarity": "Common"},
    {"num": 65, "name": "Staryu", "rarity": "Common"},
    {"num": 66, "name": "Tangela", "rarity": "Common"},
    {"num": 67, "name": "Voltorb", "rarity": "Common"},
    {"num": 68, "name": "Vulpix", "rarity": "Common"},
    {"num": 69, "name": "Weedle", "rarity": "Common"},
    {"num": 70, "name": "Clefairy Doll", "rarity": "Rare"},
    {"num": 71, "name": "Computer Search", "rarity": "Rare"},
    {"num": 72, "name": "Devolution Spray", "rarity": "Rare"},
    {"num": 73, "name": "Imposter Professor Oak", "rarity": "Rare"},
    {"num": 74, "name": "Item Finder", "rarity": "Rare"},
    {"num": 75, "name": "Lass", "rarity": "Rare"},
    {"num": 76, "name": "Pokemon Breeder", "rarity": "Rare"},
    {"num": 77, "name": "Pokemon Trader", "rarity": "Rare"},
    {"num": 78, "name": "Scoop Up", "rarity": "Rare"},
    {"num": 79, "name": "Super Energy Removal", "rarity": "Rare"},
    {"num": 80, "name": "Defender", "rarity": "Uncommon"},
    {"num": 81, "name": "Energy Retrieval", "rarity": "Uncommon"},
    {"num": 82, "name": "Full Heal", "rarity": "Uncommon"},
    {"num": 83, "name": "Maintenance", "rarity": "Uncommon"},
    {"num": 84, "name": "PlusPower", "rarity": "Uncommon"},
    {"num": 85, "name": "Pokemon Center", "rarity": "Uncommon"},
    {"num": 86, "name": "Pokemon Flute", "rarity": "Uncommon"},
    {"num": 87, "name": "Pokedex", "rarity": "Uncommon"},
    {"num": 88, "name": "Professor Oak", "rarity": "Uncommon"},
    {"num": 89, "name": "Revive", "rarity": "Uncommon"},
    {"num": 90, "name": "Super Potion", "rarity": "Uncommon"},
    {"num": 91, "name": "Bill", "rarity": "Common"},
    {"num": 92, "name": "Energy Removal", "rarity": "Common"},
    {"num": 93, "name": "Gust of Wind", "rarity": "Common"},
    {"num": 94, "name": "Potion", "rarity": "Common"},
    {"num": 95, "name": "Switch", "rarity": "Common"},
    {"num": 96, "name": "Double Colorless Energy", "rarity": "Uncommon"},
    {"num": 97, "name": "Fighting Energy", "rarity": "Common"},
    {"num": 98, "name": "Fire Energy", "rarity": "Common"},
    {"num": 99, "name": "Grass Energy", "rarity": "Common"},
    {"num": 100, "name": "Lightning Energy", "rarity": "Common"},
    {"num": 101, "name": "Psychic Energy", "rarity": "Common"},
    {"num": 102, "name": "Water Energy", "rarity": "Common"}
]

def generate_lua_registry(cards):
    OUTPUT_LUA.parent.mkdir(parents=True, exist_ok=True)
    TEXTURES_DIR.mkdir(parents=True, exist_ok=True)

    lua_lines = [
        "-- =============================================================================",
        "-- Project Zomboid TCG - Base Set (1999) Card Registry (Bilingual PT/EN)",
        "-- Auto-gerado via tools/fetch_scrydex_base1.py",
        "-- =============================================================================",
        "",
        'require "TCG_Config"',
        "",
        "TCG_CardRegistry = TCG_CardRegistry or {}",
        "TCG_CardRegistry.Sets = TCG_CardRegistry.Sets or {}",
        "",
        'TCG_CardRegistry.Sets["base1"] = {',
        '    id = "base1",',
        '    name = { en = "Base Set (1999)", pt = "Colecao Basica (1999)" },',
        '    total = 102,',
        "    cards = {",
    ]

    for c in cards:
        num = int(c.get("number", c.get("num", 0)))
        card_id = f"base1-{num:03d}"
        name_en = c.get("name", "Unknown").replace('"', '\\"')
        name_pt = PT_TRANSLATIONS.get(num, name_en).replace('"', '\\"')
        rarity_en = c.get("rarity", "Common")
        rarity_pt = RARITY_TRANSLATIONS.get(rarity_en, rarity_en)
        is_holo = "Holo" in rarity_en or num <= 16

        texture_rel = f"media/textures/cards/base1/{num:03d}.png"
        lua_lines.append(f'        ["{card_id}"] = {{')
        lua_lines.append(f'            id = "{card_id}",')
        lua_lines.append(f'            number = {num},')
        lua_lines.append(f'            name = {{ en = "{name_en}", pt = "{name_pt}" }},')
        lua_lines.append(f'            rarity = {{ en = "{rarity_en}", pt = "{rarity_pt}" }},')
        lua_lines.append(f'            isHolo = {"true" if is_holo else "false"},')
        lua_lines.append(f'            texture = "{texture_rel}",')
        lua_lines.append(f'            setId = "base1"')
        lua_lines.append("        },")

    lua_lines.extend([
        "    }",
        "}",
        "",
        "--- Retorna a definicao de uma carta pelo ID",
        "function TCG_CardRegistry.getCard(cardId)",
        "    if not cardId then return nil end",
        '    local setId = cardId:match("^([^-]+)%-")',
        "    if setId and TCG_CardRegistry.Sets[setId] and TCG_CardRegistry.Sets[setId].cards then",
        "        return TCG_CardRegistry.Sets[setId].cards[cardId]",
        "    end",
        "    return nil",
        "end",
        "",
        "--- Retorna o nome da carta respeitando o idioma ativo (ou parametro explicito)",
        "function TCG_CardRegistry.getCardName(cardDef, lang)",
        "    if not cardDef then return \"Carta TCG\" end",
        "    lang = lang or (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage()) or \"PT\"",
        "    local langKey = string.lower(lang)",
        "    if type(cardDef.name) == \"table\" then",
        "        return cardDef.name[langKey] or cardDef.name[\"pt\"] or cardDef.name[\"en\"]",
        "    end",
        "    return tostring(cardDef.name or \"Carta TCG\")",
        "end",
        "",
        "--- Retorna a raridade da carta respeitando o idioma ativo",
        "function TCG_CardRegistry.getCardRarity(cardDef, lang)",
        "    if not cardDef then return \"Common\" end",
        "    lang = lang or (TCG_Config and TCG_Config.getLanguage and TCG_Config.getLanguage()) or \"PT\"",
        "    local langKey = string.lower(lang)",
        "    if type(cardDef.rarity) == \"table\" then",
        "        return cardDef.rarity[langKey] or cardDef.rarity[\"pt\"] or cardDef.rarity[\"en\"]",
        "    end",
        "    return tostring(cardDef.rarity or \"Common\")",
        "end",
        "",
        "--- Retorna todas as cartas de uma raridade especifica no Set",
        "function TCG_CardRegistry.getCardsByRarity(setId, rarity)",
        "    local setDef = TCG_CardRegistry.Sets[setId]",
        "    if not setDef then return {} end",
        "    local matched = {}",
        "    for _, card in pairs(setDef.cards) do",
        "        local r = card.rarity",
        "        local match = false",
        "        if type(r) == \"table\" then",
        "            match = (r.en == rarity or r.pt == rarity)",
        "        else",
        "            match = (r == rarity)",
        "        end",
        "        if match then",
        "            table.insert(matched, card)",
        "        end",
        "    end",
        "    return matched",
        "end",
        ""
    ])

    with open(OUTPUT_LUA, "w", encoding="utf-8") as f:
        f.write("\n".join(lua_lines))

    print(f"[OK] Tabela Lua bilingue gerada com sucesso em: {OUTPUT_LUA}")

def main():
    cards = BASE1_SEED_CATALOG
    generate_lua_registry(cards)

if __name__ == "__main__":
    main()
