#!/usr/bin/env python3
"""
Living House (VICCS Housing Care System) - Multi-Target MD5 Parity Checker & Sync Tool
Autor: VICCS / UEoE
Uso:
    python tools/check_md5_parity.py         # Apenas verifica e reporta
    python tools/check_md5_parity.py --sync  # Sincroniza automaticamente 42/, 42.0/ e common/
"""

import os
import sys
import hashlib
import shutil

TARGET_DIRS = ["42", "42.0", "common"]
ROOT_FILES = ["mod.info", "icon.png", "poster.png"]

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
    sync_mode = "--sync" in sys.argv or "-s" in sys.argv
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    
    print("=" * 70)
    print(" LIVING HOUSE — VERIFICADOR DE PARIDADE BINARIA (MD5)")
    print(f" Modo: {'SINCRONIZACAO ATIVA (--sync)' if sync_mode else 'APENAS AUDITORIA'}")
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
                    print(f" [SYNC] {target}/{rel_path} -> Copiado e verificado ({new_hash[:8]})")
                    synced_count += 1
                else:
                    status = "FALTANDO" if dst_hash is None else f"HASH DIFERENTE ({dst_hash[:8]} vs {src_hash[:8]})"
                    print(f" [X] DIVERGENCIA: {target}/{rel_path} -> {status}")

    print("-" * 70)
    if sync_mode:
        print(f"Resultado: {synced_count} arquivo(s) sincronizados com sucesso!")
        print("Todos os 4 targets estao agora em paridade binaria de 100%!")
    else:
        if divergences == 0:
            print(f"PERFEITO! Todos os {total_files} arquivos estao 100% sincronizados entre os 4 targets.")
        else:
            print(f"ATENCAO: Foram encontradas {divergences} divergencia(s).")
            print("Execute 'python tools/check_md5_parity.py --sync' para sincronizar automaticamente.")
    print("=" * 70)

if __name__ == "__main__":
    main()
