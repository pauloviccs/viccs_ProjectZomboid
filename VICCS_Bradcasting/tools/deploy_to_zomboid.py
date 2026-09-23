#!/usr/bin/env python3
"""
VICCS Media Broadcasting - Automated Local Deploy Tool
Autor: VICCS / UEoE 1
Uso:
    python tools/deploy_to_zomboid.py

Copia e sincroniza automaticamente os arquivos do mod VICCS Media Broadcasting
para a pasta oficial de mods do Project Zomboid (%USERPROFILE%\\Zomboid\\mods\\VICCS_Broadcasting).
"""

import os
import sys
import shutil
import hashlib

def get_hash(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def get_target_dirs():
    if len(sys.argv) > 1 and os.path.isdir(sys.argv[1]):
        return [sys.argv[1]]
    targets = []
    user_profile = os.environ.get("USERPROFILE")
    if user_profile:
        targets.append(os.path.join(user_profile, "Zomboid", "mods", "VICCS_Broadcasting"))
    else:
        targets.append(r"C:\Users\oldga\Zomboid\mods\VICCS_Broadcasting")
    
    # Se existir servidor dedicado em C:\pzserver, sincroniza também em C:\pzserver\mods\VICCS_Broadcasting
    if os.path.isdir(r"C:\pzserver"):
        targets.append(r"C:\pzserver\mods\VICCS_Broadcasting")
    
    return targets

def sync_internal_mirrors(mod_dir):
    """Garante paridade entre media/ e 42/media/."""
    media_src = os.path.join(mod_dir, "media")
    mirror_42_media = os.path.join(mod_dir, "42", "media")
    if not os.path.exists(media_src):
        return
    os.makedirs(mirror_42_media, exist_ok=True)
    
    # Sincroniza arquivos de media para 42/media
    for root, _, files in os.walk(media_src):
        for f in files:
            src_f = os.path.join(root, f)
            rel = os.path.relpath(src_f, media_src)
            dst_f = os.path.join(mirror_42_media, rel)
            os.makedirs(os.path.dirname(dst_f), exist_ok=True)
            if not os.path.exists(dst_f) or get_hash(src_f) != get_hash(dst_f):
                shutil.copy2(src_f, dst_f)
                
    # Sincroniza mod.info e poster.png se existirem
    for extra in ["mod.info", "poster.png"]:
        src_extra = os.path.join(mod_dir, extra)
        dst_extra = os.path.join(mod_dir, "42", extra)
        if os.path.exists(src_extra):
            if not os.path.exists(dst_extra) or get_hash(src_extra) != get_hash(dst_extra):
                shutil.copy2(src_extra, dst_extra)

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    src_dir = os.path.join(root_dir, "VICCS_Broadcasting")
    dest_dirs = get_target_dirs()

    print("=" * 70)
    print(" VICCS MEDIA BROADCASTING — DEPLOY AUTOMATICO PARA O PROJECT ZOMBOID")
    print(f" Origem (Git Repo):  {src_dir}")
    for d in dest_dirs:
        print(f" Destino:            {d}")
    print("=" * 70)

    if not os.path.exists(src_dir):
        print(f"[X] ERRO: Diretorio fonte nao encontrado: {src_dir}")
        sys.exit(1)

    # 1. Paridade interna
    print("\n[1/3] Verificando paridade entre media/ e 42/media/...")
    sync_internal_mirrors(src_dir)
    print("      [OK] Mirrors internos sincronizados.")

    items_to_copy = ["mod.info", "poster.png", "media", "42"]

    for dest_dir in dest_dirs:
        print(f"\n[2/3] Copiando arquivos para: {dest_dir}...")
        os.makedirs(dest_dir, exist_ok=True)
        deployed_count = 0

        for item in items_to_copy:
            s_item = os.path.join(src_dir, item)
            d_item = os.path.join(dest_dir, item)
            if not os.path.exists(s_item):
                continue

            if os.path.isdir(s_item):
                for root, _, files in os.walk(s_item):
                    for f in files:
                        src_f = os.path.join(root, f)
                        rel = os.path.relpath(src_f, src_dir)
                        dst_f = os.path.join(dest_dir, rel)
                        os.makedirs(os.path.dirname(dst_f), exist_ok=True)
                        shutil.copy2(src_f, dst_f)
                        deployed_count += 1
            else:
                shutil.copy2(s_item, d_item)
                deployed_count += 1

        # 3. Validacao de integridade MD5
        print(f"[3/3] Validando integridade binaria (MD5) em: {dest_dir}...")
        mismatches = 0
        verified_files = 0
        for root, _, files in os.walk(src_dir):
            for f in files:
                src_f = os.path.join(root, f)
                rel = os.path.relpath(src_f, src_dir)
                dst_f = os.path.join(dest_dir, rel)
                verified_files += 1
                if not os.path.exists(dst_f):
                    print(f"      [!] Ausente no destino: {rel}")
                    mismatches += 1
                elif get_hash(src_f) != get_hash(dst_f):
                    print(f"      [!] Divergencia MD5: {rel}")
                    mismatches += 1

        if mismatches == 0:
            print(f"      [OK] {verified_files} arquivos verificados com 100% de paridade MD5!")
        else:
            print(f"      [X] ATENCAO: {mismatches} arquivos apresentaram divergencias no deploy.")
            sys.exit(1)

    print("-" * 70)
    print(" SUCESSO ABSOLUTO: Deploy concluido em todos os destinos!")
    print("=" * 70)

if __name__ == "__main__":
    main()
