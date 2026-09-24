#!/usr/bin/env python3
"""
VICCS Spores - Automated Local Deploy Tool
Autor: VICCS / UEoE
Uso:
    python tools/deploy_to_zomboid.py

Copia e sincroniza automaticamente os arquivos compilados do repositorio Git
para a pasta oficial de mods do Project Zomboid (C:\\Users\\oldga\\Zomboid\\mods\\VICCS_Spores).
"""

import os
import sys
import shutil

TARGET_ITEMS = [
    "mod.info",
    "icon.png",
    "poster.png",
    "media",
    "42",
    "common"
]

def get_zomboid_mods_dir():
    if len(sys.argv) > 1 and os.path.isdir(sys.argv[1]):
        return sys.argv[1]

    user_profile = os.environ.get("USERPROFILE")
    if user_profile:
        return os.path.join(user_profile, "Zomboid", "mods", "VICCS_Spores")

    return r"C:\Users\oldga\Zomboid\mods\VICCS_Spores"

def deploy():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    dest_dir = get_zomboid_mods_dir()

    print(f"[*] Repositorio Git: {repo_root}")
    print(f"[*] Destino PZ Mods: {dest_dir}")

    os.makedirs(dest_dir, exist_ok=True)

    for item in TARGET_ITEMS:
        src = os.path.join(repo_root, item)
        dst = os.path.join(dest_dir, item)

        if not os.path.exists(src):
            print(f"[-] Item ignorado (inexistente): {item}")
            continue

        if os.path.isdir(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
            print(f"[+] Diretorio sincronizado: {item} -> {dst}")
        else:
            shutil.copy2(src, dst)
            print(f"[+] Arquivo sincronizado: {item} -> {dst}")

    # Também espelha a pasta media na raiz do destino para compatibilidade total de modloaders
    media_42 = os.path.join(dest_dir, "42", "media")
    media_root = os.path.join(dest_dir, "media")
    if os.path.exists(media_42):
        if os.path.exists(media_root):
            shutil.rmtree(media_root)
        shutil.copytree(media_42, media_root)
        print(f"[+] Mirror de compatibilidade: media -> {media_root}")

    print("[OK] Deploy concluido com sucesso no Project Zomboid!")

if __name__ == "__main__":
    deploy()
