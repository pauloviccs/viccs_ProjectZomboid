-- =============================================================================
-- Project Zomboid TCG - Expansion Sets Registry (Jungle, Fossil, Team Rocket, Eevee Heroes)
-- =============================================================================

require "TCG_Config"

TCG_CardRegistry = TCG_CardRegistry or {}
TCG_CardRegistry.Sets = TCG_CardRegistry.Sets or {}

TCG_CardRegistry.Sets["jungle"] = {
    id = "jungle",
    name = { en = "Jungle (1999)", pt = "Colecao Jungle (1999)" },
    total = 64,
    cards = {
        ["jungle-001"] = {
            id = "jungle-001",
            number = 1,
            name = { en = "Clefable", pt = "Clefable" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/001.png",
            setId = "jungle"
        },
        ["jungle-002"] = {
            id = "jungle-002",
            number = 2,
            name = { en = "Electrode", pt = "Electrode" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/002.png",
            setId = "jungle"
        },
        ["jungle-003"] = {
            id = "jungle-003",
            number = 3,
            name = { en = "Flareon", pt = "Flareon" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/003.png",
            setId = "jungle"
        },
        ["jungle-004"] = {
            id = "jungle-004",
            number = 4,
            name = { en = "Jolteon", pt = "Jolteon" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/004.png",
            setId = "jungle"
        },
        ["jungle-005"] = {
            id = "jungle-005",
            number = 5,
            name = { en = "Kangaskhan", pt = "Kangaskhan" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/005.png",
            setId = "jungle"
        },
        ["jungle-006"] = {
            id = "jungle-006",
            number = 6,
            name = { en = "Mr. Mime", pt = "Mr. Mime" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/006.png",
            setId = "jungle"
        },
        ["jungle-007"] = {
            id = "jungle-007",
            number = 7,
            name = { en = "Nidoqueen", pt = "Nidoqueen" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/007.png",
            setId = "jungle"
        },
        ["jungle-008"] = {
            id = "jungle-008",
            number = 8,
            name = { en = "Pidgeot", pt = "Pidgeot" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/008.png",
            setId = "jungle"
        },
        ["jungle-009"] = {
            id = "jungle-009",
            number = 9,
            name = { en = "Pinsir", pt = "Pinsir" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/009.png",
            setId = "jungle"
        },
        ["jungle-010"] = {
            id = "jungle-010",
            number = 10,
            name = { en = "Scyther", pt = "Scyther" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/010.png",
            setId = "jungle"
        },
        ["jungle-011"] = {
            id = "jungle-011",
            number = 11,
            name = { en = "Snorlax", pt = "Snorlax" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/011.png",
            setId = "jungle"
        },
        ["jungle-012"] = {
            id = "jungle-012",
            number = 12,
            name = { en = "Vaporeon", pt = "Vaporeon" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/012.png",
            setId = "jungle"
        },
        ["jungle-013"] = {
            id = "jungle-013",
            number = 13,
            name = { en = "Venomoth", pt = "Venomoth" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/013.png",
            setId = "jungle"
        },
        ["jungle-014"] = {
            id = "jungle-014",
            number = 14,
            name = { en = "Victreebel", pt = "Victreebel" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/014.png",
            setId = "jungle"
        },
        ["jungle-015"] = {
            id = "jungle-015",
            number = 15,
            name = { en = "Vileplume", pt = "Vileplume" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/015.png",
            setId = "jungle"
        },
        ["jungle-016"] = {
            id = "jungle-016",
            number = 16,
            name = { en = "Wigglytuff", pt = "Wigglytuff" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/jungle/016.png",
            setId = "jungle"
        },
        ["jungle-017"] = {
            id = "jungle-017",
            number = 17,
            name = { en = "Clefable", pt = "Clefable" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/017.png",
            setId = "jungle"
        },
        ["jungle-018"] = {
            id = "jungle-018",
            number = 18,
            name = { en = "Electrode", pt = "Electrode" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/018.png",
            setId = "jungle"
        },
        ["jungle-019"] = {
            id = "jungle-019",
            number = 19,
            name = { en = "Flareon", pt = "Flareon" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/019.png",
            setId = "jungle"
        },
        ["jungle-020"] = {
            id = "jungle-020",
            number = 20,
            name = { en = "Jolteon", pt = "Jolteon" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/020.png",
            setId = "jungle"
        },
        ["jungle-021"] = {
            id = "jungle-021",
            number = 21,
            name = { en = "Kangaskhan", pt = "Kangaskhan" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/021.png",
            setId = "jungle"
        },
        ["jungle-022"] = {
            id = "jungle-022",
            number = 22,
            name = { en = "Mr. Mime", pt = "Mr. Mime" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/022.png",
            setId = "jungle"
        },
        ["jungle-023"] = {
            id = "jungle-023",
            number = 23,
            name = { en = "Nidoqueen", pt = "Nidoqueen" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/023.png",
            setId = "jungle"
        },
        ["jungle-024"] = {
            id = "jungle-024",
            number = 24,
            name = { en = "Pidgeot", pt = "Pidgeot" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/024.png",
            setId = "jungle"
        },
        ["jungle-025"] = {
            id = "jungle-025",
            number = 25,
            name = { en = "Pinsir", pt = "Pinsir" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/025.png",
            setId = "jungle"
        },
        ["jungle-026"] = {
            id = "jungle-026",
            number = 26,
            name = { en = "Scyther", pt = "Scyther" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/026.png",
            setId = "jungle"
        },
        ["jungle-027"] = {
            id = "jungle-027",
            number = 27,
            name = { en = "Snorlax", pt = "Snorlax" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/027.png",
            setId = "jungle"
        },
        ["jungle-028"] = {
            id = "jungle-028",
            number = 28,
            name = { en = "Vaporeon", pt = "Vaporeon" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/028.png",
            setId = "jungle"
        },
        ["jungle-029"] = {
            id = "jungle-029",
            number = 29,
            name = { en = "Venomoth", pt = "Venomoth" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/029.png",
            setId = "jungle"
        },
        ["jungle-030"] = {
            id = "jungle-030",
            number = 30,
            name = { en = "Victreebel", pt = "Victreebel" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/030.png",
            setId = "jungle"
        },
        ["jungle-031"] = {
            id = "jungle-031",
            number = 31,
            name = { en = "Vileplume", pt = "Vileplume" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/031.png",
            setId = "jungle"
        },
        ["jungle-032"] = {
            id = "jungle-032",
            number = 32,
            name = { en = "Wigglytuff", pt = "Wigglytuff" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/jungle/032.png",
            setId = "jungle"
        },
        ["jungle-033"] = {
            id = "jungle-033",
            number = 33,
            name = { en = "Butterfree", pt = "Butterfree" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/033.png",
            setId = "jungle"
        },
        ["jungle-034"] = {
            id = "jungle-034",
            number = 34,
            name = { en = "Dodrio", pt = "Dodrio" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/034.png",
            setId = "jungle"
        },
        ["jungle-035"] = {
            id = "jungle-035",
            number = 35,
            name = { en = "Exeggutor", pt = "Exeggutor" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/035.png",
            setId = "jungle"
        },
        ["jungle-036"] = {
            id = "jungle-036",
            number = 36,
            name = { en = "Fearow", pt = "Fearow" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/036.png",
            setId = "jungle"
        },
        ["jungle-037"] = {
            id = "jungle-037",
            number = 37,
            name = { en = "Gloom", pt = "Gloom" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/037.png",
            setId = "jungle"
        },
        ["jungle-038"] = {
            id = "jungle-038",
            number = 38,
            name = { en = "Lickitung", pt = "Lickitung" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/038.png",
            setId = "jungle"
        },
        ["jungle-039"] = {
            id = "jungle-039",
            number = 39,
            name = { en = "Marowak", pt = "Marowak" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/039.png",
            setId = "jungle"
        },
        ["jungle-040"] = {
            id = "jungle-040",
            number = 40,
            name = { en = "Nidorina", pt = "Nidorina" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/040.png",
            setId = "jungle"
        },
        ["jungle-041"] = {
            id = "jungle-041",
            number = 41,
            name = { en = "Parasect", pt = "Parasect" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/041.png",
            setId = "jungle"
        },
        ["jungle-042"] = {
            id = "jungle-042",
            number = 42,
            name = { en = "Persian", pt = "Persian" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/042.png",
            setId = "jungle"
        },
        ["jungle-043"] = {
            id = "jungle-043",
            number = 43,
            name = { en = "Primeape", pt = "Primeape" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/043.png",
            setId = "jungle"
        },
        ["jungle-044"] = {
            id = "jungle-044",
            number = 44,
            name = { en = "Rapidash", pt = "Rapidash" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/044.png",
            setId = "jungle"
        },
        ["jungle-045"] = {
            id = "jungle-045",
            number = 45,
            name = { en = "Rhydon", pt = "Rhydon" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/045.png",
            setId = "jungle"
        },
        ["jungle-046"] = {
            id = "jungle-046",
            number = 46,
            name = { en = "Seaking", pt = "Seaking" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/046.png",
            setId = "jungle"
        },
        ["jungle-047"] = {
            id = "jungle-047",
            number = 47,
            name = { en = "Tauros", pt = "Tauros" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/047.png",
            setId = "jungle"
        },
        ["jungle-048"] = {
            id = "jungle-048",
            number = 48,
            name = { en = "Weepinbell", pt = "Weepinbell" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/048.png",
            setId = "jungle"
        },
        ["jungle-049"] = {
            id = "jungle-049",
            number = 49,
            name = { en = "Bellsprout", pt = "Bellsprout" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/049.png",
            setId = "jungle"
        },
        ["jungle-050"] = {
            id = "jungle-050",
            number = 50,
            name = { en = "Cubone", pt = "Cubone" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/050.png",
            setId = "jungle"
        },
        ["jungle-051"] = {
            id = "jungle-051",
            number = 51,
            name = { en = "Eevee", pt = "Eevee" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/051.png",
            setId = "jungle"
        },
        ["jungle-052"] = {
            id = "jungle-052",
            number = 52,
            name = { en = "Exeggcute", pt = "Exeggcute" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/052.png",
            setId = "jungle"
        },
        ["jungle-053"] = {
            id = "jungle-053",
            number = 53,
            name = { en = "Goldeen", pt = "Goldeen" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/053.png",
            setId = "jungle"
        },
        ["jungle-054"] = {
            id = "jungle-054",
            number = 54,
            name = { en = "Jigglypuff", pt = "Jigglypuff" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/054.png",
            setId = "jungle"
        },
        ["jungle-055"] = {
            id = "jungle-055",
            number = 55,
            name = { en = "Mankey", pt = "Mankey" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/055.png",
            setId = "jungle"
        },
        ["jungle-056"] = {
            id = "jungle-056",
            number = 56,
            name = { en = "Meowth", pt = "Meowth" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/056.png",
            setId = "jungle"
        },
        ["jungle-057"] = {
            id = "jungle-057",
            number = 57,
            name = { en = "Nidoran F", pt = "Nidoran F" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/057.png",
            setId = "jungle"
        },
        ["jungle-058"] = {
            id = "jungle-058",
            number = 58,
            name = { en = "Oddish", pt = "Oddish" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/058.png",
            setId = "jungle"
        },
        ["jungle-059"] = {
            id = "jungle-059",
            number = 59,
            name = { en = "Paras", pt = "Paras" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/059.png",
            setId = "jungle"
        },
        ["jungle-060"] = {
            id = "jungle-060",
            number = 60,
            name = { en = "Pikachu", pt = "Pikachu" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/060.png",
            setId = "jungle"
        },
        ["jungle-061"] = {
            id = "jungle-061",
            number = 61,
            name = { en = "Rhyhorn", pt = "Rhyhorn" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/061.png",
            setId = "jungle"
        },
        ["jungle-062"] = {
            id = "jungle-062",
            number = 62,
            name = { en = "Spearow", pt = "Spearow" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/062.png",
            setId = "jungle"
        },
        ["jungle-063"] = {
            id = "jungle-063",
            number = 63,
            name = { en = "Venonat", pt = "Venonat" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/063.png",
            setId = "jungle"
        },
        ["jungle-064"] = {
            id = "jungle-064",
            number = 64,
            name = { en = "Poke Ball", pt = "Poke Ball" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/jungle/064.png",
            setId = "jungle"
        },
    }
}

TCG_CardRegistry.Sets["fossil"] = {
    id = "fossil",
    name = { en = "Fossil (1999)", pt = "Colecao Fossil (1999)" },
    total = 62,
    cards = {
        ["fossil-001"] = {
            id = "fossil-001",
            number = 1,
            name = { en = "Aerodactyl", pt = "Aerodactyl" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/001.png",
            setId = "fossil"
        },
        ["fossil-002"] = {
            id = "fossil-002",
            number = 2,
            name = { en = "Articuno", pt = "Articuno" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/002.png",
            setId = "fossil"
        },
        ["fossil-003"] = {
            id = "fossil-003",
            number = 3,
            name = { en = "Ditto", pt = "Ditto" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/003.png",
            setId = "fossil"
        },
        ["fossil-004"] = {
            id = "fossil-004",
            number = 4,
            name = { en = "Dragonite", pt = "Dragonite" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/004.png",
            setId = "fossil"
        },
        ["fossil-005"] = {
            id = "fossil-005",
            number = 5,
            name = { en = "Gengar", pt = "Gengar" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/005.png",
            setId = "fossil"
        },
        ["fossil-006"] = {
            id = "fossil-006",
            number = 6,
            name = { en = "Haunter", pt = "Haunter" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/006.png",
            setId = "fossil"
        },
        ["fossil-007"] = {
            id = "fossil-007",
            number = 7,
            name = { en = "Hitmonlee", pt = "Hitmonlee" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/007.png",
            setId = "fossil"
        },
        ["fossil-008"] = {
            id = "fossil-008",
            number = 8,
            name = { en = "Hypno", pt = "Hypno" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/008.png",
            setId = "fossil"
        },
        ["fossil-009"] = {
            id = "fossil-009",
            number = 9,
            name = { en = "Kabutops", pt = "Kabutops" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/009.png",
            setId = "fossil"
        },
        ["fossil-010"] = {
            id = "fossil-010",
            number = 10,
            name = { en = "Lapras", pt = "Lapras" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/010.png",
            setId = "fossil"
        },
        ["fossil-011"] = {
            id = "fossil-011",
            number = 11,
            name = { en = "Magneton", pt = "Magneton" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/011.png",
            setId = "fossil"
        },
        ["fossil-012"] = {
            id = "fossil-012",
            number = 12,
            name = { en = "Moltres", pt = "Moltres" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/012.png",
            setId = "fossil"
        },
        ["fossil-013"] = {
            id = "fossil-013",
            number = 13,
            name = { en = "Muk", pt = "Muk" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/013.png",
            setId = "fossil"
        },
        ["fossil-014"] = {
            id = "fossil-014",
            number = 14,
            name = { en = "Raichu", pt = "Raichu" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/014.png",
            setId = "fossil"
        },
        ["fossil-015"] = {
            id = "fossil-015",
            number = 15,
            name = { en = "Zapdos", pt = "Zapdos" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/fossil/015.png",
            setId = "fossil"
        },
        ["fossil-016"] = {
            id = "fossil-016",
            number = 16,
            name = { en = "Aerodactyl", pt = "Aerodactyl" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/016.png",
            setId = "fossil"
        },
        ["fossil-017"] = {
            id = "fossil-017",
            number = 17,
            name = { en = "Articuno", pt = "Articuno" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/017.png",
            setId = "fossil"
        },
        ["fossil-018"] = {
            id = "fossil-018",
            number = 18,
            name = { en = "Ditto", pt = "Ditto" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/018.png",
            setId = "fossil"
        },
        ["fossil-019"] = {
            id = "fossil-019",
            number = 19,
            name = { en = "Dragonite", pt = "Dragonite" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/019.png",
            setId = "fossil"
        },
        ["fossil-020"] = {
            id = "fossil-020",
            number = 20,
            name = { en = "Gengar", pt = "Gengar" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/020.png",
            setId = "fossil"
        },
        ["fossil-021"] = {
            id = "fossil-021",
            number = 21,
            name = { en = "Haunter", pt = "Haunter" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/021.png",
            setId = "fossil"
        },
        ["fossil-022"] = {
            id = "fossil-022",
            number = 22,
            name = { en = "Hitmonlee", pt = "Hitmonlee" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/022.png",
            setId = "fossil"
        },
        ["fossil-023"] = {
            id = "fossil-023",
            number = 23,
            name = { en = "Hypno", pt = "Hypno" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/023.png",
            setId = "fossil"
        },
        ["fossil-024"] = {
            id = "fossil-024",
            number = 24,
            name = { en = "Kabutops", pt = "Kabutops" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/024.png",
            setId = "fossil"
        },
        ["fossil-025"] = {
            id = "fossil-025",
            number = 25,
            name = { en = "Lapras", pt = "Lapras" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/025.png",
            setId = "fossil"
        },
        ["fossil-026"] = {
            id = "fossil-026",
            number = 26,
            name = { en = "Magneton", pt = "Magneton" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/026.png",
            setId = "fossil"
        },
        ["fossil-027"] = {
            id = "fossil-027",
            number = 27,
            name = { en = "Moltres", pt = "Moltres" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/027.png",
            setId = "fossil"
        },
        ["fossil-028"] = {
            id = "fossil-028",
            number = 28,
            name = { en = "Muk", pt = "Muk" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/028.png",
            setId = "fossil"
        },
        ["fossil-029"] = {
            id = "fossil-029",
            number = 29,
            name = { en = "Raichu", pt = "Raichu" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/029.png",
            setId = "fossil"
        },
        ["fossil-030"] = {
            id = "fossil-030",
            number = 30,
            name = { en = "Zapdos", pt = "Zapdos" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/030.png",
            setId = "fossil"
        },
        ["fossil-031"] = {
            id = "fossil-031",
            number = 31,
            name = { en = "Arbok", pt = "Arbok" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/fossil/031.png",
            setId = "fossil"
        },
        ["fossil-032"] = {
            id = "fossil-032",
            number = 32,
            name = { en = "Cloyster", pt = "Cloyster" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/032.png",
            setId = "fossil"
        },
        ["fossil-033"] = {
            id = "fossil-033",
            number = 33,
            name = { en = "Gastly", pt = "Gastly" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/033.png",
            setId = "fossil"
        },
        ["fossil-034"] = {
            id = "fossil-034",
            number = 34,
            name = { en = "Golbat", pt = "Golbat" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/034.png",
            setId = "fossil"
        },
        ["fossil-035"] = {
            id = "fossil-035",
            number = 35,
            name = { en = "Golduck", pt = "Golduck" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/035.png",
            setId = "fossil"
        },
        ["fossil-036"] = {
            id = "fossil-036",
            number = 36,
            name = { en = "Golem", pt = "Golem" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/036.png",
            setId = "fossil"
        },
        ["fossil-037"] = {
            id = "fossil-037",
            number = 37,
            name = { en = "Graveler", pt = "Graveler" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/037.png",
            setId = "fossil"
        },
        ["fossil-038"] = {
            id = "fossil-038",
            number = 38,
            name = { en = "Kingler", pt = "Kingler" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/038.png",
            setId = "fossil"
        },
        ["fossil-039"] = {
            id = "fossil-039",
            number = 39,
            name = { en = "Magmar", pt = "Magmar" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/039.png",
            setId = "fossil"
        },
        ["fossil-040"] = {
            id = "fossil-040",
            number = 40,
            name = { en = "Omanyte", pt = "Omanyte" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/040.png",
            setId = "fossil"
        },
        ["fossil-041"] = {
            id = "fossil-041",
            number = 41,
            name = { en = "Omastar", pt = "Omastar" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/041.png",
            setId = "fossil"
        },
        ["fossil-042"] = {
            id = "fossil-042",
            number = 42,
            name = { en = "Sandslash", pt = "Sandslash" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/042.png",
            setId = "fossil"
        },
        ["fossil-043"] = {
            id = "fossil-043",
            number = 43,
            name = { en = "Seadra", pt = "Seadra" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/043.png",
            setId = "fossil"
        },
        ["fossil-044"] = {
            id = "fossil-044",
            number = 44,
            name = { en = "Slowbro", pt = "Slowbro" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/044.png",
            setId = "fossil"
        },
        ["fossil-045"] = {
            id = "fossil-045",
            number = 45,
            name = { en = "Tentacruel", pt = "Tentacruel" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/045.png",
            setId = "fossil"
        },
        ["fossil-046"] = {
            id = "fossil-046",
            number = 46,
            name = { en = "Ekans", pt = "Ekans" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/046.png",
            setId = "fossil"
        },
        ["fossil-047"] = {
            id = "fossil-047",
            number = 47,
            name = { en = "Geodude", pt = "Geodude" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/047.png",
            setId = "fossil"
        },
        ["fossil-048"] = {
            id = "fossil-048",
            number = 48,
            name = { en = "Grimer", pt = "Grimer" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/048.png",
            setId = "fossil"
        },
        ["fossil-049"] = {
            id = "fossil-049",
            number = 49,
            name = { en = "Horsea", pt = "Horsea" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/049.png",
            setId = "fossil"
        },
        ["fossil-050"] = {
            id = "fossil-050",
            number = 50,
            name = { en = "Kabuto", pt = "Kabuto" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/050.png",
            setId = "fossil"
        },
        ["fossil-051"] = {
            id = "fossil-051",
            number = 51,
            name = { en = "Krabby", pt = "Krabby" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/051.png",
            setId = "fossil"
        },
        ["fossil-052"] = {
            id = "fossil-052",
            number = 52,
            name = { en = "Omanyte", pt = "Omanyte" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/052.png",
            setId = "fossil"
        },
        ["fossil-053"] = {
            id = "fossil-053",
            number = 53,
            name = { en = "Psyduck", pt = "Psyduck" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/053.png",
            setId = "fossil"
        },
        ["fossil-054"] = {
            id = "fossil-054",
            number = 54,
            name = { en = "Shellder", pt = "Shellder" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/054.png",
            setId = "fossil"
        },
        ["fossil-055"] = {
            id = "fossil-055",
            number = 55,
            name = { en = "Slowpoke", pt = "Slowpoke" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/055.png",
            setId = "fossil"
        },
        ["fossil-056"] = {
            id = "fossil-056",
            number = 56,
            name = { en = "Tentacool", pt = "Tentacool" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/056.png",
            setId = "fossil"
        },
        ["fossil-057"] = {
            id = "fossil-057",
            number = 57,
            name = { en = "Zubat", pt = "Zubat" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/057.png",
            setId = "fossil"
        },
        ["fossil-058"] = {
            id = "fossil-058",
            number = 58,
            name = { en = "Energy Search", pt = "Energy Search" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/058.png",
            setId = "fossil"
        },
        ["fossil-059"] = {
            id = "fossil-059",
            number = 59,
            name = { en = "Gambler", pt = "Gambler" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/059.png",
            setId = "fossil"
        },
        ["fossil-060"] = {
            id = "fossil-060",
            number = 60,
            name = { en = "Recycle", pt = "Recycle" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/060.png",
            setId = "fossil"
        },
        ["fossil-061"] = {
            id = "fossil-061",
            number = 61,
            name = { en = "Mysterious Fossil", pt = "Mysterious Fossil" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/061.png",
            setId = "fossil"
        },
        ["fossil-062"] = {
            id = "fossil-062",
            number = 62,
            name = { en = "Fossil Excavator", pt = "Fossil Excavator" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/fossil/062.png",
            setId = "fossil"
        },
    }
}

TCG_CardRegistry.Sets["rocket"] = {
    id = "rocket",
    name = { en = "Team Rocket (2000)", pt = "Colecao Equipe Rocket (2000)" },
    total = 83,
    cards = {
        ["rocket-001"] = {
            id = "rocket-001",
            number = 1,
            name = { en = "Dark Alakazam", pt = "Dark Alakazam" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/001.png",
            setId = "rocket"
        },
        ["rocket-002"] = {
            id = "rocket-002",
            number = 2,
            name = { en = "Dark Arbok", pt = "Dark Arbok" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/002.png",
            setId = "rocket"
        },
        ["rocket-003"] = {
            id = "rocket-003",
            number = 3,
            name = { en = "Dark Blastoise", pt = "Dark Blastoise" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/003.png",
            setId = "rocket"
        },
        ["rocket-004"] = {
            id = "rocket-004",
            number = 4,
            name = { en = "Dark Charizard", pt = "Dark Charizard" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/004.png",
            setId = "rocket"
        },
        ["rocket-005"] = {
            id = "rocket-005",
            number = 5,
            name = { en = "Dark Dragonite", pt = "Dark Dragonite" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/005.png",
            setId = "rocket"
        },
        ["rocket-006"] = {
            id = "rocket-006",
            number = 6,
            name = { en = "Dark Dugtrio", pt = "Dark Dugtrio" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/006.png",
            setId = "rocket"
        },
        ["rocket-007"] = {
            id = "rocket-007",
            number = 7,
            name = { en = "Dark Golbat", pt = "Dark Golbat" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/007.png",
            setId = "rocket"
        },
        ["rocket-008"] = {
            id = "rocket-008",
            number = 8,
            name = { en = "Dark Gyarados", pt = "Dark Gyarados" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/008.png",
            setId = "rocket"
        },
        ["rocket-009"] = {
            id = "rocket-009",
            number = 9,
            name = { en = "Dark Hypno", pt = "Dark Hypno" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/009.png",
            setId = "rocket"
        },
        ["rocket-010"] = {
            id = "rocket-010",
            number = 10,
            name = { en = "Dark Machamp", pt = "Dark Machamp" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/010.png",
            setId = "rocket"
        },
        ["rocket-011"] = {
            id = "rocket-011",
            number = 11,
            name = { en = "Dark Magneton", pt = "Dark Magneton" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/011.png",
            setId = "rocket"
        },
        ["rocket-012"] = {
            id = "rocket-012",
            number = 12,
            name = { en = "Dark Slowbro", pt = "Dark Slowbro" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/012.png",
            setId = "rocket"
        },
        ["rocket-013"] = {
            id = "rocket-013",
            number = 13,
            name = { en = "Dark Vileplume", pt = "Dark Vileplume" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/013.png",
            setId = "rocket"
        },
        ["rocket-014"] = {
            id = "rocket-014",
            number = 14,
            name = { en = "Dark Weezing", pt = "Dark Weezing" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/014.png",
            setId = "rocket"
        },
        ["rocket-015"] = {
            id = "rocket-015",
            number = 15,
            name = { en = "Here Comes Team Rocket!", pt = "Here Comes Team Rocket!" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/015.png",
            setId = "rocket"
        },
        ["rocket-016"] = {
            id = "rocket-016",
            number = 16,
            name = { en = "Rocket Sneak Attack", pt = "Rocket Sneak Attack" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/016.png",
            setId = "rocket"
        },
        ["rocket-017"] = {
            id = "rocket-017",
            number = 17,
            name = { en = "Rainbow Energy", pt = "Rainbow Energy" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/017.png",
            setId = "rocket"
        },
        ["rocket-018"] = {
            id = "rocket-018",
            number = 18,
            name = { en = "Dark Alakazam", pt = "Dark Alakazam" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/018.png",
            setId = "rocket"
        },
        ["rocket-019"] = {
            id = "rocket-019",
            number = 19,
            name = { en = "Dark Arbok", pt = "Dark Arbok" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/019.png",
            setId = "rocket"
        },
        ["rocket-020"] = {
            id = "rocket-020",
            number = 20,
            name = { en = "Dark Blastoise", pt = "Dark Blastoise" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/020.png",
            setId = "rocket"
        },
        ["rocket-021"] = {
            id = "rocket-021",
            number = 21,
            name = { en = "Dark Charizard", pt = "Dark Charizard" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/021.png",
            setId = "rocket"
        },
        ["rocket-022"] = {
            id = "rocket-022",
            number = 22,
            name = { en = "Dark Dragonite", pt = "Dark Dragonite" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/022.png",
            setId = "rocket"
        },
        ["rocket-023"] = {
            id = "rocket-023",
            number = 23,
            name = { en = "Dark Dugtrio", pt = "Dark Dugtrio" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/023.png",
            setId = "rocket"
        },
        ["rocket-024"] = {
            id = "rocket-024",
            number = 24,
            name = { en = "Dark Golbat", pt = "Dark Golbat" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/024.png",
            setId = "rocket"
        },
        ["rocket-025"] = {
            id = "rocket-025",
            number = 25,
            name = { en = "Dark Gyarados", pt = "Dark Gyarados" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/025.png",
            setId = "rocket"
        },
        ["rocket-026"] = {
            id = "rocket-026",
            number = 26,
            name = { en = "Dark Hypno", pt = "Dark Hypno" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/026.png",
            setId = "rocket"
        },
        ["rocket-027"] = {
            id = "rocket-027",
            number = 27,
            name = { en = "Dark Machamp", pt = "Dark Machamp" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/027.png",
            setId = "rocket"
        },
        ["rocket-028"] = {
            id = "rocket-028",
            number = 28,
            name = { en = "Dark Magneton", pt = "Dark Magneton" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/028.png",
            setId = "rocket"
        },
        ["rocket-029"] = {
            id = "rocket-029",
            number = 29,
            name = { en = "Dark Slowbro", pt = "Dark Slowbro" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/029.png",
            setId = "rocket"
        },
        ["rocket-030"] = {
            id = "rocket-030",
            number = 30,
            name = { en = "Dark Vileplume", pt = "Dark Vileplume" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/030.png",
            setId = "rocket"
        },
        ["rocket-031"] = {
            id = "rocket-031",
            number = 31,
            name = { en = "Dark Weezing", pt = "Dark Weezing" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/031.png",
            setId = "rocket"
        },
        ["rocket-032"] = {
            id = "rocket-032",
            number = 32,
            name = { en = "Dark Charmeleon", pt = "Dark Charmeleon" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/032.png",
            setId = "rocket"
        },
        ["rocket-033"] = {
            id = "rocket-033",
            number = 33,
            name = { en = "Dark Dragonair", pt = "Dark Dragonair" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/033.png",
            setId = "rocket"
        },
        ["rocket-034"] = {
            id = "rocket-034",
            number = 34,
            name = { en = "Dark Electrode", pt = "Dark Electrode" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/034.png",
            setId = "rocket"
        },
        ["rocket-035"] = {
            id = "rocket-035",
            number = 35,
            name = { en = "Dark Flareon", pt = "Dark Flareon" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/035.png",
            setId = "rocket"
        },
        ["rocket-036"] = {
            id = "rocket-036",
            number = 36,
            name = { en = "Dark Gloom", pt = "Dark Gloom" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/036.png",
            setId = "rocket"
        },
        ["rocket-037"] = {
            id = "rocket-037",
            number = 37,
            name = { en = "Dark Golduck", pt = "Dark Golduck" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/037.png",
            setId = "rocket"
        },
        ["rocket-038"] = {
            id = "rocket-038",
            number = 38,
            name = { en = "Dark Jolteon", pt = "Dark Jolteon" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/038.png",
            setId = "rocket"
        },
        ["rocket-039"] = {
            id = "rocket-039",
            number = 39,
            name = { en = "Dark Kadabra", pt = "Dark Kadabra" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/039.png",
            setId = "rocket"
        },
        ["rocket-040"] = {
            id = "rocket-040",
            number = 40,
            name = { en = "Dark Machoke", pt = "Dark Machoke" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/040.png",
            setId = "rocket"
        },
        ["rocket-041"] = {
            id = "rocket-041",
            number = 41,
            name = { en = "Dark Muk", pt = "Dark Muk" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/041.png",
            setId = "rocket"
        },
        ["rocket-042"] = {
            id = "rocket-042",
            number = 42,
            name = { en = "Dark Persian", pt = "Dark Persian" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/042.png",
            setId = "rocket"
        },
        ["rocket-043"] = {
            id = "rocket-043",
            number = 43,
            name = { en = "Dark Primeape", pt = "Dark Primeape" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/043.png",
            setId = "rocket"
        },
        ["rocket-044"] = {
            id = "rocket-044",
            number = 44,
            name = { en = "Dark Rapidash", pt = "Dark Rapidash" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/044.png",
            setId = "rocket"
        },
        ["rocket-045"] = {
            id = "rocket-045",
            number = 45,
            name = { en = "Dark Vaporeon", pt = "Dark Vaporeon" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/045.png",
            setId = "rocket"
        },
        ["rocket-046"] = {
            id = "rocket-046",
            number = 46,
            name = { en = "Dark Wartortle", pt = "Dark Wartortle" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/046.png",
            setId = "rocket"
        },
        ["rocket-047"] = {
            id = "rocket-047",
            number = 47,
            name = { en = "Magikarp", pt = "Magikarp" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/047.png",
            setId = "rocket"
        },
        ["rocket-048"] = {
            id = "rocket-048",
            number = 48,
            name = { en = "Porygon", pt = "Porygon" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/048.png",
            setId = "rocket"
        },
        ["rocket-049"] = {
            id = "rocket-049",
            number = 49,
            name = { en = "Super Energy Retrieval", pt = "Super Energy Retrieval" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/049.png",
            setId = "rocket"
        },
        ["rocket-050"] = {
            id = "rocket-050",
            number = 50,
            name = { en = "Challenge!", pt = "Challenge!" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/050.png",
            setId = "rocket"
        },
        ["rocket-051"] = {
            id = "rocket-051",
            number = 51,
            name = { en = "Abra", pt = "Abra" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/051.png",
            setId = "rocket"
        },
        ["rocket-052"] = {
            id = "rocket-052",
            number = 52,
            name = { en = "Charmander", pt = "Charmander" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/052.png",
            setId = "rocket"
        },
        ["rocket-053"] = {
            id = "rocket-053",
            number = 53,
            name = { en = "Diglett", pt = "Diglett" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/053.png",
            setId = "rocket"
        },
        ["rocket-054"] = {
            id = "rocket-054",
            number = 54,
            name = { en = "Drowzee", pt = "Drowzee" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/054.png",
            setId = "rocket"
        },
        ["rocket-055"] = {
            id = "rocket-055",
            number = 55,
            name = { en = "Eevee", pt = "Eevee" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/055.png",
            setId = "rocket"
        },
        ["rocket-056"] = {
            id = "rocket-056",
            number = 56,
            name = { en = "Ekans", pt = "Ekans" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/056.png",
            setId = "rocket"
        },
        ["rocket-057"] = {
            id = "rocket-057",
            number = 57,
            name = { en = "Grimer", pt = "Grimer" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/057.png",
            setId = "rocket"
        },
        ["rocket-058"] = {
            id = "rocket-058",
            number = 58,
            name = { en = "Koffing", pt = "Koffing" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/058.png",
            setId = "rocket"
        },
        ["rocket-059"] = {
            id = "rocket-059",
            number = 59,
            name = { en = "Machop", pt = "Machop" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/059.png",
            setId = "rocket"
        },
        ["rocket-060"] = {
            id = "rocket-060",
            number = 60,
            name = { en = "Magnemite", pt = "Magnemite" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/060.png",
            setId = "rocket"
        },
        ["rocket-061"] = {
            id = "rocket-061",
            number = 61,
            name = { en = "Mankey", pt = "Mankey" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/061.png",
            setId = "rocket"
        },
        ["rocket-062"] = {
            id = "rocket-062",
            number = 62,
            name = { en = "Meowth", pt = "Meowth" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/062.png",
            setId = "rocket"
        },
        ["rocket-063"] = {
            id = "rocket-063",
            number = 63,
            name = { en = "Oddish", pt = "Oddish" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/063.png",
            setId = "rocket"
        },
        ["rocket-064"] = {
            id = "rocket-064",
            number = 64,
            name = { en = "Ponyta", pt = "Ponyta" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/064.png",
            setId = "rocket"
        },
        ["rocket-065"] = {
            id = "rocket-065",
            number = 65,
            name = { en = "Psyduck", pt = "Psyduck" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/065.png",
            setId = "rocket"
        },
        ["rocket-066"] = {
            id = "rocket-066",
            number = 66,
            name = { en = "Rattata", pt = "Rattata" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/066.png",
            setId = "rocket"
        },
        ["rocket-067"] = {
            id = "rocket-067",
            number = 67,
            name = { en = "Slowpoke", pt = "Slowpoke" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/067.png",
            setId = "rocket"
        },
        ["rocket-068"] = {
            id = "rocket-068",
            number = 68,
            name = { en = "Squirtle", pt = "Squirtle" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/068.png",
            setId = "rocket"
        },
        ["rocket-069"] = {
            id = "rocket-069",
            number = 69,
            name = { en = "Voltorb", pt = "Voltorb" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/069.png",
            setId = "rocket"
        },
        ["rocket-070"] = {
            id = "rocket-070",
            number = 70,
            name = { en = "Zubat", pt = "Zubat" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/070.png",
            setId = "rocket"
        },
        ["rocket-071"] = {
            id = "rocket-071",
            number = 71,
            name = { en = "Here Comes Team Rocket!", pt = "Here Comes Team Rocket!" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/071.png",
            setId = "rocket"
        },
        ["rocket-072"] = {
            id = "rocket-072",
            number = 72,
            name = { en = "Rocket Sneak Attack", pt = "Rocket Sneak Attack" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/072.png",
            setId = "rocket"
        },
        ["rocket-073"] = {
            id = "rocket-073",
            number = 73,
            name = { en = "The Boss Way", pt = "The Boss Way" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/073.png",
            setId = "rocket"
        },
        ["rocket-074"] = {
            id = "rocket-074",
            number = 74,
            name = { en = "Goop Gas Attack", pt = "Goop Gas Attack" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/074.png",
            setId = "rocket"
        },
        ["rocket-075"] = {
            id = "rocket-075",
            number = 75,
            name = { en = "Sleep!", pt = "Sleep!" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/075.png",
            setId = "rocket"
        },
        ["rocket-076"] = {
            id = "rocket-076",
            number = 76,
            name = { en = "Digger", pt = "Digger" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/076.png",
            setId = "rocket"
        },
        ["rocket-077"] = {
            id = "rocket-077",
            number = 77,
            name = { en = "Nightly Garbage Run", pt = "Nightly Garbage Run" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/077.png",
            setId = "rocket"
        },
        ["rocket-078"] = {
            id = "rocket-078",
            number = 78,
            name = { en = "Potion Energy", pt = "Potion Energy" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/078.png",
            setId = "rocket"
        },
        ["rocket-079"] = {
            id = "rocket-079",
            number = 79,
            name = { en = "Full Heal Energy", pt = "Full Heal Energy" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/079.png",
            setId = "rocket"
        },
        ["rocket-080"] = {
            id = "rocket-080",
            number = 80,
            name = { en = "Rainbow Energy", pt = "Rainbow Energy" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = false,
            texture = "media/textures/cards/rocket/080.png",
            setId = "rocket"
        },
        ["rocket-081"] = {
            id = "rocket-081",
            number = 81,
            name = { en = "Rocket Training Gym", pt = "Rocket Training Gym" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/081.png",
            setId = "rocket"
        },
        ["rocket-082"] = {
            id = "rocket-082",
            number = 82,
            name = { en = "Rocket Secret Machine", pt = "Rocket Secret Machine" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/rocket/082.png",
            setId = "rocket"
        },
        ["rocket-083"] = {
            id = "rocket-083",
            number = 83,
            name = { en = "Dark Raichu", pt = "Dark Raichu" },
            rarity = { en = "Rare Holo", pt = "Rara Holografica" },
            isHolo = true,
            texture = "media/textures/cards/rocket/083.png",
            setId = "rocket"
        },
    }
}

TCG_CardRegistry.Sets["eeveeheroes"] = {
    id = "eeveeheroes",
    name = { en = "Eevee Heroes (2021)", pt = "Colecao Eevee Heroes (Japao 2021)" },
    total = 101,
    cards = {
        ["eeveeheroes-001"] = {
            id = "eeveeheroes-001",
            number = 1,
            name = { en = "Pinsir", pt = "Pinsir" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/001.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-002"] = {
            id = "eeveeheroes-002",
            number = 2,
            name = { en = "Leafeon V", pt = "Leafeon V" },
            rarity = { en = "Double Rare", pt = "Dupla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/002.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-003"] = {
            id = "eeveeheroes-003",
            number = 3,
            name = { en = "Leafeon VMAX", pt = "Leafeon VMAX" },
            rarity = { en = "Triple Rare", pt = "Tripla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/003.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-004"] = {
            id = "eeveeheroes-004",
            number = 4,
            name = { en = "Sewaddle", pt = "Sewaddle" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/004.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-005"] = {
            id = "eeveeheroes-005",
            number = 5,
            name = { en = "Swadloon", pt = "Swadloon" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/005.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-006"] = {
            id = "eeveeheroes-006",
            number = 6,
            name = { en = "Leavanny", pt = "Leavanny" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/006.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-007"] = {
            id = "eeveeheroes-007",
            number = 7,
            name = { en = "Dewpider", pt = "Dewpider" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/007.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-008"] = {
            id = "eeveeheroes-008",
            number = 8,
            name = { en = "Araquanid", pt = "Araquanid" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/008.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-009"] = {
            id = "eeveeheroes-009",
            number = 9,
            name = { en = "Gossifleur", pt = "Gossifleur" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/009.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-010"] = {
            id = "eeveeheroes-010",
            number = 10,
            name = { en = "Eldegoss", pt = "Eldegoss" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/010.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-011"] = {
            id = "eeveeheroes-011",
            number = 11,
            name = { en = "Flareon V", pt = "Flareon V" },
            rarity = { en = "Double Rare", pt = "Dupla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/011.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-012"] = {
            id = "eeveeheroes-012",
            number = 12,
            name = { en = "Slugma", pt = "Slugma" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/012.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-013"] = {
            id = "eeveeheroes-013",
            number = 13,
            name = { en = "Magcargo", pt = "Magcargo" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/013.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-014"] = {
            id = "eeveeheroes-014",
            number = 14,
            name = { en = "Entei", pt = "Entei" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/014.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-015"] = {
            id = "eeveeheroes-015",
            number = 15,
            name = { en = "Vaporeon V", pt = "Vaporeon V" },
            rarity = { en = "Double Rare", pt = "Dupla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/015.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-016"] = {
            id = "eeveeheroes-016",
            number = 16,
            name = { en = "Marill", pt = "Marill" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/016.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-017"] = {
            id = "eeveeheroes-017",
            number = 17,
            name = { en = "Azumarill", pt = "Azumarill" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/017.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-018"] = {
            id = "eeveeheroes-018",
            number = 18,
            name = { en = "Mantine", pt = "Mantine" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/018.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-019"] = {
            id = "eeveeheroes-019",
            number = 19,
            name = { en = "Mudkip", pt = "Mudkip" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/019.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-020"] = {
            id = "eeveeheroes-020",
            number = 20,
            name = { en = "Marshtomp", pt = "Marshtomp" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/020.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-021"] = {
            id = "eeveeheroes-021",
            number = 21,
            name = { en = "Swampert", pt = "Swampert" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/021.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-022"] = {
            id = "eeveeheroes-022",
            number = 22,
            name = { en = "Feebas", pt = "Feebas" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/022.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-023"] = {
            id = "eeveeheroes-023",
            number = 23,
            name = { en = "Milotic", pt = "Milotic" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/023.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-024"] = {
            id = "eeveeheroes-024",
            number = 24,
            name = { en = "Glaceon V", pt = "Glaceon V" },
            rarity = { en = "Double Rare", pt = "Dupla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/024.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-025"] = {
            id = "eeveeheroes-025",
            number = 25,
            name = { en = "Glaceon VMAX", pt = "Glaceon VMAX" },
            rarity = { en = "Triple Rare", pt = "Tripla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/025.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-026"] = {
            id = "eeveeheroes-026",
            number = 26,
            name = { en = "Pikachu", pt = "Pikachu" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/026.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-027"] = {
            id = "eeveeheroes-027",
            number = 27,
            name = { en = "Raichu", pt = "Raichu" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/027.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-028"] = {
            id = "eeveeheroes-028",
            number = 28,
            name = { en = "Voltorb", pt = "Voltorb" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/028.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-029"] = {
            id = "eeveeheroes-029",
            number = 29,
            name = { en = "Electrode", pt = "Electrode" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/029.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-030"] = {
            id = "eeveeheroes-030",
            number = 30,
            name = { en = "Jolteon V", pt = "Jolteon V" },
            rarity = { en = "Double Rare", pt = "Dupla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/030.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-031"] = {
            id = "eeveeheroes-031",
            number = 31,
            name = { en = "Rotom", pt = "Rotom" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/031.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-032"] = {
            id = "eeveeheroes-032",
            number = 32,
            name = { en = "Tynamo", pt = "Tynamo" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/032.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-033"] = {
            id = "eeveeheroes-033",
            number = 33,
            name = { en = "Eelektrik", pt = "Eelektrik" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/033.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-034"] = {
            id = "eeveeheroes-034",
            number = 34,
            name = { en = "Eelektross", pt = "Eelektross" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/034.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-035"] = {
            id = "eeveeheroes-035",
            number = 35,
            name = { en = "Espeon V", pt = "Espeon V" },
            rarity = { en = "Double Rare", pt = "Dupla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/035.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-036"] = {
            id = "eeveeheroes-036",
            number = 36,
            name = { en = "Mawile", pt = "Mawile" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/036.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-037"] = {
            id = "eeveeheroes-037",
            number = 37,
            name = { en = "Flabebe", pt = "Flabebe" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/037.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-038"] = {
            id = "eeveeheroes-038",
            number = 38,
            name = { en = "Floette", pt = "Floette" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/038.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-039"] = {
            id = "eeveeheroes-039",
            number = 39,
            name = { en = "Florges", pt = "Florges" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/039.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-040"] = {
            id = "eeveeheroes-040",
            number = 40,
            name = { en = "Sylveon V", pt = "Sylveon V" },
            rarity = { en = "Double Rare", pt = "Dupla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/040.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-041"] = {
            id = "eeveeheroes-041",
            number = 41,
            name = { en = "Sylveon VMAX", pt = "Sylveon VMAX" },
            rarity = { en = "Triple Rare", pt = "Tripla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/041.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-042"] = {
            id = "eeveeheroes-042",
            number = 42,
            name = { en = "Sandygast", pt = "Sandygast" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/042.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-043"] = {
            id = "eeveeheroes-043",
            number = 43,
            name = { en = "Palossand", pt = "Palossand" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/043.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-044"] = {
            id = "eeveeheroes-044",
            number = 44,
            name = { en = "Marshadow", pt = "Marshadow" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/044.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-045"] = {
            id = "eeveeheroes-045",
            number = 45,
            name = { en = "Indeedee", pt = "Indeedee" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/045.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-046"] = {
            id = "eeveeheroes-046",
            number = 46,
            name = { en = "Pancham", pt = "Pancham" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/046.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-047"] = {
            id = "eeveeheroes-047",
            number = 47,
            name = { en = "Umbreon V", pt = "Umbreon V" },
            rarity = { en = "Double Rare", pt = "Dupla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/047.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-048"] = {
            id = "eeveeheroes-048",
            number = 48,
            name = { en = "Umbreon VMAX", pt = "Umbreon VMAX" },
            rarity = { en = "Triple Rare", pt = "Tripla Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/048.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-049"] = {
            id = "eeveeheroes-049",
            number = 49,
            name = { en = "Zorua", pt = "Zorua" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/049.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-050"] = {
            id = "eeveeheroes-050",
            number = 50,
            name = { en = "Zoroark", pt = "Zoroark" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/050.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-051"] = {
            id = "eeveeheroes-051",
            number = 51,
            name = { en = "Pangoro", pt = "Pangoro" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/051.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-052"] = {
            id = "eeveeheroes-052",
            number = 52,
            name = { en = "Impidimp", pt = "Impidimp" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/052.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-053"] = {
            id = "eeveeheroes-053",
            number = 53,
            name = { en = "Morgrem", pt = "Morgrem" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/053.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-054"] = {
            id = "eeveeheroes-054",
            number = 54,
            name = { en = "Grimmsnarl", pt = "Grimmsnarl" },
            rarity = { en = "Rare", pt = "Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/054.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-055"] = {
            id = "eeveeheroes-055",
            number = 55,
            name = { en = "Meowth", pt = "Meowth" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/055.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-056"] = {
            id = "eeveeheroes-056",
            number = 56,
            name = { en = "Persian", pt = "Persian" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/056.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-057"] = {
            id = "eeveeheroes-057",
            number = 57,
            name = { en = "Kangaskhan", pt = "Kangaskhan" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/057.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-058"] = {
            id = "eeveeheroes-058",
            number = 58,
            name = { en = "Eevee", pt = "Eevee" },
            rarity = { en = "Common", pt = "Comum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/058.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-059"] = {
            id = "eeveeheroes-059",
            number = 59,
            name = { en = "Smeargle", pt = "Smeargle" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/059.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-060"] = {
            id = "eeveeheroes-060",
            number = 60,
            name = { en = "Boost Shake", pt = "Frasco de Impulso" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/060.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-061"] = {
            id = "eeveeheroes-061",
            number = 61,
            name = { en = "Dream Ball", pt = "Bola dos Sonhos" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/061.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-062"] = {
            id = "eeveeheroes-062",
            number = 62,
            name = { en = "Elemental Badge", pt = "Insignia Elemental" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/062.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-063"] = {
            id = "eeveeheroes-063",
            number = 63,
            name = { en = "Snow Leaf Badge", pt = "Insignia Folha de Neve" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/063.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-064"] = {
            id = "eeveeheroes-064",
            number = 64,
            name = { en = "Moon & Sun Badge", pt = "Insignia Lua e Sol" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/064.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-065"] = {
            id = "eeveeheroes-065",
            number = 65,
            name = { en = "Ribbon Badge", pt = "Insignia de Fita" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/065.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-066"] = {
            id = "eeveeheroes-066",
            number = 66,
            name = { en = "Aroma Lady", pt = "Dama dos Aromas" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/066.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-067"] = {
            id = "eeveeheroes-067",
            number = 67,
            name = { en = "Gordie", pt = "Gordie" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/067.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-068"] = {
            id = "eeveeheroes-068",
            number = 68,
            name = { en = "Shopping Center", pt = "Centro Comercial" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/068.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-069"] = {
            id = "eeveeheroes-069",
            number = 69,
            name = { en = "Treasure Energy", pt = "Energia do Tesouro" },
            rarity = { en = "Uncommon", pt = "Incomum" },
            isHolo = false,
            texture = "media/textures/cards/eeveeheroes/069.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-070"] = {
            id = "eeveeheroes-070",
            number = 70,
            name = { en = "Leafeon V (SR)", pt = "Leafeon V (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/070.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-071"] = {
            id = "eeveeheroes-071",
            number = 71,
            name = { en = "Leafeon V Alt Art (SR)", pt = "Leafeon V Arte Alternativa (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/071.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-072"] = {
            id = "eeveeheroes-072",
            number = 72,
            name = { en = "Flareon V (SR)", pt = "Flareon V (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/072.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-073"] = {
            id = "eeveeheroes-073",
            number = 73,
            name = { en = "Flareon V Alt Art (SR)", pt = "Flareon V Arte Alternativa (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/073.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-074"] = {
            id = "eeveeheroes-074",
            number = 74,
            name = { en = "Vaporeon V (SR)", pt = "Vaporeon V (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/074.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-075"] = {
            id = "eeveeheroes-075",
            number = 75,
            name = { en = "Vaporeon V Alt Art (SR)", pt = "Vaporeon V Arte Alternativa (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/075.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-076"] = {
            id = "eeveeheroes-076",
            number = 76,
            name = { en = "Glaceon V (SR)", pt = "Glaceon V (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/076.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-077"] = {
            id = "eeveeheroes-077",
            number = 77,
            name = { en = "Glaceon V Alt Art (SR)", pt = "Glaceon V Arte Alternativa (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/077.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-078"] = {
            id = "eeveeheroes-078",
            number = 78,
            name = { en = "Jolteon V (SR)", pt = "Jolteon V (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/078.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-079"] = {
            id = "eeveeheroes-079",
            number = 79,
            name = { en = "Jolteon V Alt Art (SR)", pt = "Jolteon V Arte Alternativa (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/079.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-080"] = {
            id = "eeveeheroes-080",
            number = 80,
            name = { en = "Espeon V (SR)", pt = "Espeon V (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/080.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-081"] = {
            id = "eeveeheroes-081",
            number = 81,
            name = { en = "Espeon V Alt Art (SR)", pt = "Espeon V Arte Alternativa (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/081.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-082"] = {
            id = "eeveeheroes-082",
            number = 82,
            name = { en = "Sylveon V (SR)", pt = "Sylveon V (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/082.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-083"] = {
            id = "eeveeheroes-083",
            number = 83,
            name = { en = "Sylveon V Alt Art (SR)", pt = "Sylveon V Arte Alternativa (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/083.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-084"] = {
            id = "eeveeheroes-084",
            number = 84,
            name = { en = "Umbreon V (SR)", pt = "Umbreon V (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/084.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-085"] = {
            id = "eeveeheroes-085",
            number = 85,
            name = { en = "Umbreon V Alt Art (SR)", pt = "Umbreon V Arte Alternativa (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/085.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-086"] = {
            id = "eeveeheroes-086",
            number = 86,
            name = { en = "Aroma Lady (SR)", pt = "Dama dos Aromas (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/086.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-087"] = {
            id = "eeveeheroes-087",
            number = 87,
            name = { en = "Gordie (SR)", pt = "Gordie (SR)" },
            rarity = { en = "Super Rare", pt = "Super Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/087.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-088"] = {
            id = "eeveeheroes-088",
            number = 88,
            name = { en = "Leafeon VMAX (HR)", pt = "Leafeon VMAX (HR)" },
            rarity = { en = "Hyper Rare", pt = "Hiper Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/088.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-089"] = {
            id = "eeveeheroes-089",
            number = 89,
            name = { en = "Leafeon VMAX Alt Art (HR)", pt = "Leafeon VMAX Arte Alternativa (HR)" },
            rarity = { en = "Hyper Rare", pt = "Hiper Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/089.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-090"] = {
            id = "eeveeheroes-090",
            number = 90,
            name = { en = "Glaceon VMAX (HR)", pt = "Glaceon VMAX (HR)" },
            rarity = { en = "Hyper Rare", pt = "Hiper Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/090.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-091"] = {
            id = "eeveeheroes-091",
            number = 91,
            name = { en = "Glaceon VMAX Alt Art (HR)", pt = "Glaceon VMAX Arte Alternativa (HR)" },
            rarity = { en = "Hyper Rare", pt = "Hiper Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/091.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-092"] = {
            id = "eeveeheroes-092",
            number = 92,
            name = { en = "Sylveon VMAX (HR)", pt = "Sylveon VMAX (HR)" },
            rarity = { en = "Hyper Rare", pt = "Hiper Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/092.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-093"] = {
            id = "eeveeheroes-093",
            number = 93,
            name = { en = "Sylveon VMAX Alt Art (HR)", pt = "Sylveon VMAX Arte Alternativa (HR)" },
            rarity = { en = "Hyper Rare", pt = "Hiper Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/093.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-094"] = {
            id = "eeveeheroes-094",
            number = 94,
            name = { en = "Umbreon VMAX (HR)", pt = "Umbreon VMAX (HR)" },
            rarity = { en = "Hyper Rare", pt = "Hiper Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/094.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-095"] = {
            id = "eeveeheroes-095",
            number = 95,
            name = { en = "Umbreon VMAX Alt Art (HR)", pt = "Umbreon VMAX Arte Alternativa (HR)" },
            rarity = { en = "Hyper Rare", pt = "Hiper Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/095.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-096"] = {
            id = "eeveeheroes-096",
            number = 96,
            name = { en = "Aroma Lady (HR)", pt = "Dama dos Aromas (HR)" },
            rarity = { en = "Hyper Rare", pt = "Hiper Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/096.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-097"] = {
            id = "eeveeheroes-097",
            number = 97,
            name = { en = "Gordie (HR)", pt = "Gordie (HR)" },
            rarity = { en = "Hyper Rare", pt = "Hiper Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/097.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-098"] = {
            id = "eeveeheroes-098",
            number = 98,
            name = { en = "Inteleon (UR)", pt = "Inteleon Dourado (UR)" },
            rarity = { en = "Ultra Rare", pt = "Ultra Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/098.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-099"] = {
            id = "eeveeheroes-099",
            number = 99,
            name = { en = "Boost Shake (UR)", pt = "Frasco de Impulso Dourado (UR)" },
            rarity = { en = "Ultra Rare", pt = "Ultra Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/099.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-100"] = {
            id = "eeveeheroes-100",
            number = 100,
            name = { en = "Turffield Stadium (UR)", pt = "Estadio Turffield Dourado (UR)" },
            rarity = { en = "Ultra Rare", pt = "Ultra Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/100.png",
            setId = "eeveeheroes"
        },
        ["eeveeheroes-101"] = {
            id = "eeveeheroes-101",
            number = 101,
            name = { en = "Darkness Energy (UR)", pt = "Energia Sombria Dourada (UR)" },
            rarity = { en = "Ultra Rare", pt = "Ultra Rara" },
            isHolo = true,
            texture = "media/textures/cards/eeveeheroes/101.png",
            setId = "eeveeheroes"
        }
    }
}
