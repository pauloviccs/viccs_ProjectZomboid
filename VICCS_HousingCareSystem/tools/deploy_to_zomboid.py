#!/usr/bin/env python3
"""
Living House (VICCS Housing Care System) - Automated Local Deploy Tool
Autor: VICCS / UEoE
Uso:
    python tools/deploy_to_zomboid.py
    npm run deploy

Copia e sincroniza automaticamente os arquivos compilados do repositorio Git
para a pasta oficial de mods do Project Zomboid (C:\\Users\\<user>\\Zomboid\\mods\\VICCS_HousingCareSystem).
"""

import os
import sys
import shutil
import subprocess

TARGET_ITEMS = [
    "mod.info",
    "icon.png",
    "poster.png",
    "media",
    "42",
    "42.0",
    "common"
]

def get_zomboid_mods_dir():
    # 1. Checa variavel de ambiente ou parametro CLI
    if len(sys.argv) > 1 and os.path.isdir(sys.argv[1]):
        return sys.argv[1]

    # 2. Local padrao no Windows: %USERPROFILE%\\Zomboid\\mods\\VICCS_HousingCareSystem
    user_profile = os.environ.get("USERPROFILE")
    if user_profile:
        target = os.path.join(user_profile, "Zomboid", "mods", "VICCS_HousingCareSystem")
        return target

    # Fallback
    return r"C:\Users\oldga\Zomboid\mods\VICCS_HousingCareSystem"

def main():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    dest_dir = get_zomboid_mods_dir()

    print("=" * 70)
    print(" LIVING HOUSE — DEPLOY AUTOMATICO PARA PROJECT ZOMBOID")
    print(f" Origem (Git Repo):  {base_dir}")
    print(f" Destino (Zomboid):  {dest_dir}")
    print("=" * 70)

    # 1. Garantir paridade MD5 nos mirrors internos antes do deploy
    print("\n[1/3] Verificando e sincronizando paridade MD5 interna...")
    parity_script = os.path.join(base_dir, "tools", "check_md5_parity.py")
    res = subprocess.run([sys.executable, parity_script, "--sync"], cwd=base_dir)
    if res.returncode != 0:
        print("[X] ERRO: Falha na verificacao de paridade MD5. Abortando deploy.")
        sys.exit(1)

    # 2. Validar sintaxe Lua
    print("\n[2/3] Validando sintaxe de todos os scripts Lua...")
    validate_script = os.path.join(base_dir, "tools", "validate_lua.py")
    res = subprocess.run([sys.executable, validate_script], cwd=base_dir)
    if res.returncode != 0:
        print("[X] ERRO: Falha na validacao de sintaxe Lua. Abortando deploy.")
        sys.exit(1)

    # 3. Copiar e sincronizar arquivos para a pasta de mods do Zomboid
    print(f"\n[3/3] Propagando arquivos para: {dest_dir}...")
    os.makedirs(dest_dir, exist_ok=True)

    copied_files = 0
    for item in TARGET_ITEMS:
        src = os.path.join(base_dir, item)
        dst = os.path.join(dest_dir, item)

        if not os.path.exists(src):
            print(f"[!] Item ignorado (nao encontrado): {item}")
            continue

        if os.path.isdir(src):
            # Se for diretorio, copia a arvore
            shutil.copytree(src, dst, dirs_exist_ok=True)
            for _, _, files in os.walk(src):
                copied_files += len(files)
            print(f" [DIR]  {item}/ copiado com sucesso.")
        else:
            # Se for arquivo
            shutil.copy2(src, dst)
            copied_files += 1
            print(f" [FILE] {item} copiado com sucesso.")

    print("\n" + "=" * 70)
    print(f" DEPLOY CONCLUIDO COM SUCESSO! ({copied_files} arquivos atualizados)")
    print(" O mod esta 100% pronto para testes imediatos in-game no Project Zomboid.")
    print("=" * 70)

if __name__ == "__main__":
    main()
