#!/usr/bin/env python3
"""
VICCS TCG - Lua ASCII Sanitizer Tool
Verifica e limpa caracteres nao-ASCII de todos os arquivos .lua do mod,
garantindo compatibilidade 100% com a VM Kahlua e fontes bitmap do Project Zomboid B42.
"""

import os
import sys

REPLACEMENTS = {
    "ã": "a", "Ã": "A",
    "á": "a", "Á": "A",
    "à": "a", "À": "A",
    "â": "a", "Â": "A",
    "é": "e", "É": "E",
    "ê": "e", "Ê": "E",
    "í": "i", "Í": "I",
    "ó": "o", "Ó": "O",
    "ô": "o", "Ô": "O",
    "õ": "o", "Õ": "O",
    "ú": "u", "Ú": "U",
    "ç": "c", "Ç": "C",
    "•": "-",
    "✦": "*",
    "★": "*",
    "✥": "[M]",
    "—": "-",
    "–": "-",
    "“": '"',
    "”": '"',
    "‘": "'",
    "’": "'",
}

def sanitize_file(file_path):
    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    original = content
    for k, v in REPLACEMENTS.items():
        content = content.replace(k, v)

    # Check for any remaining non-ASCII characters
    non_ascii = [ch for ch in content if ord(ch) > 127]
    if non_ascii:
        unique = set(non_ascii)
        print(f"[!] Caracteres nao-ASCII restantes em {os.path.basename(file_path)}: {unique}")

    if content != original:
        with open(file_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(content)
        print(f"[FIXED] Sanitizado: {file_path}")
        return True
    return False

def main():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    lua_dir = os.path.join(base_dir, "media", "lua")
    count = 0
    for root, _, files in os.walk(lua_dir):
        for f in files:
            if f.endswith(".lua"):
                fp = os.path.join(root, f)
                if sanitize_file(fp):
                    count += 1
    print(f"Total de arquivos sanitizados: {count}")

if __name__ == "__main__":
    main()
