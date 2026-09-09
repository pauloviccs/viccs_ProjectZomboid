#!/usr/bin/env python3
"""
VICCS TCG (Trading Card Game 1999) - Multi-Target MD5 Parity Checker & Deploy Tool
Autor: VICCS / UEoE
Uso:
    python tools/check_md5_parity.py            # Apenas verifica e reporta
    python tools/check_md5_parity.py --sync     # Sincroniza automaticamente 42/, 42.0/ e common/
    python tools/check_md5_parity.py --deploy   # Sincroniza e instala diretamente na pasta mods do Zomboid
"""

import os
import sys
import hashlib
import shutil

TARGET_DIRS = ["42", "42.0", "common"]
ROOT_FILES = ["mod.info", "icon.png", "poster.png"]
ZOMBOID_MODS_DIR = os.path.expanduser("~/Zomboid/mods/VICCS_TCG")

def compute_md5(file_path):
    if not os.path.exists(file_path):
        return None
    hasher = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            hasher.update(chunk)
    return hasher.hexdigest()

def get_media_files(base_dir):
    media_dir = os.path.join(base_dir, "media")
    rel_files = []
    for root, _, files in os.walk(media_dir):
        for f in files:
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, base_dir)
            rel_files.append(rel_path)
    return rel_files

def main():
    sync_mode = "--sync" in sys.argv or "-s" in sys.argv or "--deploy" in sys.argv or "-d" in sys.argv
    deploy_mode = "--deploy" in sys.argv or "-d" in sys.argv
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    
    print("=" * 70)
    print(" VICCS TCG — VERIFICADOR DE PARIDADE BINARIA (MD5) & DEPLOY B42")
    print(f" Modo: {'SINCRONIZACAO ATIVA (--sync)' if sync_mode else 'APENAS AUDITORIA'}")
    if deploy_mode:
        print(f" Deploy Zomboid: ATIVO -> {ZOMBOID_MODS_DIR}")
    print(f" Raiz: {base_dir}")
    print("=" * 70)

    media_files = get_media_files(base_dir)
    all_files_to_check = ROOT_FILES + media_files

    total_files = len(all_files_to_check)
    divergences = 0
    synced_count = 0

    for rel_path in all_files_to_check:
        src_path = os.path.join(base_dir, rel_path)
        src_hash = compute_md5(src_path)

        if not src_hash:
            print(f"[!] AVISO: Arquivo fonte nao encontrado: {rel_path}")
            continue

        for target in TARGET_DIRS:
            dst_path = os.path.join(base_dir, target, rel_path)
            dst_hash = compute_md5(dst_path)

            if src_hash != dst_hash:
                divergences += 1
                if sync_mode:
                    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
                    shutil.copy2(src_path, dst_path)
                    new_hash = compute_md5(dst_path)
                    print(f" [SYNC] {target}/{rel_path} -> Copiado ({new_hash[:8]})")
                    synced_count += 1
                else:
                    status = "FALTANDO" if dst_hash is None else f"HASH DIFERENTE ({dst_hash[:8]} vs {src_hash[:8]})"
                    print(f" [X] DIVERGENCIA: {target}/{rel_path} -> {status}")

    print("-" * 70)
    if sync_mode:
        print(f"Resultado: {synced_count} arquivo(s) sincronizados com sucesso no repositorio!")
        print("Todos os targets (42, 42.0, common) estao agora em paridade binaria de 100%!")
    else:
        if divergences == 0:
            print(f"PERFEITO! Todos os {total_files} arquivos estao 100% sincronizados entre os targets.")
        else:
            print(f"ATENCAO: Foram encontradas {divergences} divergencia(s).")
            print("Execute 'python tools/check_md5_parity.py --sync' para sincronizar automaticamente.")

    if deploy_mode:
        print("-" * 70)
        print("Iniciando Deploy para a pasta local de Mods do Project Zomboid...")
        os.makedirs(ZOMBOID_MODS_DIR, exist_ok=True)
        # Deploy targets and root
        deploy_targets = ["42", "42.0", "common", "media"]
        for target in deploy_targets:
            src_t = os.path.join(base_dir, target)
            dst_t = os.path.join(ZOMBOID_MODS_DIR, target)
            if os.path.isdir(src_t):
                if os.path.exists(dst_t):
                    shutil.rmtree(dst_t)
                shutil.copytree(src_t, dst_t)
                print(f" [DEPLOY] Copiada pasta: {target}/")
        
        for rf in ROOT_FILES:
            src_f = os.path.join(base_dir, rf)
            dst_f = os.path.join(ZOMBOID_MODS_DIR, rf)
            if os.path.exists(src_f):
                shutil.copy2(src_f, dst_f)
                print(f" [DEPLOY] Copiado arquivo raiz: {rf}")

        print(f"[OK] Mod instalado e atualizado com sucesso em: {ZOMBOID_MODS_DIR}")

    print("=" * 70)

if __name__ == "__main__":
    main()
