#!/usr/bin/env python3
"""
Gera texturas organicas para a nevoa e esporos do VICCS Spores (estilo The Last of Us).
"""
import os
import math
from PIL import Image, ImageDraw

def create_spore_puff():
    size = 128
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    center = size / 2.0
    max_radius = size / 2.0 - 2.0
    
    # Gera gradiente radial suave com curva cos/gaussiana para evitar qualquer borda dura
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            dx = x - center
            dy = y - center
            dist = math.sqrt(dx * dx + dy * dy)
            if dist < max_radius:
                # Normaliza de 0 (centro) a 1 (borda)
                norm = dist / max_radius
                # Curva cos: suave no centro e suave na transicao para zero
                alpha_factor = 0.5 * (1.0 + math.cos(norm * math.pi))
                # Suavizacao extra nas pontas
                alpha_factor = math.pow(alpha_factor, 1.4)
                
                # Leve variacao angular orgânica (3 lobos sutis para parecer nuvem/gas fúngico)
                angle = math.atan2(dy, dx)
                organic_mod = 1.0 + 0.08 * math.sin(angle * 3.0 + dist * 0.1)
                
                alpha = int(min(255, max(0, 255 * alpha_factor * organic_mod)))
                # Base branca para permitir tinting dinamico no jogo via shader/engine
                pixels[x, y] = (255, 255, 255, alpha)
            else:
                pixels[x, y] = (255, 255, 255, 0)
                
    return img

def create_spore_mote():
    size = 32
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    center = size / 2.0
    max_radius = size / 2.0 - 1.0
    
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            dx = x - center
            dy = y - center
            dist = math.sqrt(dx * dx + dy * dy)
            if dist < max_radius:
                norm = dist / max_radius
                # Ponto de luz: brilho muito intenso no centro, decaindo rapidamente
                alpha_factor = math.pow(1.0 - norm, 2.5)
                alpha = int(min(255, max(0, 255 * alpha_factor)))
                pixels[x, y] = (255, 255, 255, alpha)
            else:
                pixels[x, y] = (255, 255, 255, 0)
                
    return img

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.join(base_dir, "..", "42", "media", "textures", "spores")
    os.makedirs(out_dir, exist_ok=True)
    
    puff_img = create_spore_puff()
    puff_path = os.path.join(out_dir, "spore_puff.png")
    puff_img.save(puff_path, "PNG")
    print(f"[+] Textura de Puff gerada: {puff_path}")
    
    mote_img = create_spore_mote()
    mote_path = os.path.join(out_dir, "spore_mote.png")
    mote_img.save(mote_path, "PNG")
    print(f"[+] Textura de Mote gerada: {mote_path}")

if __name__ == "__main__":
    main()
