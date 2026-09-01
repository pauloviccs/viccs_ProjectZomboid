import os
from PIL import Image, ImageDraw, ImageFont

out_dir = r"g:\GitHub\Vibecoding\VICCS_Git\VICCS_ProjectZomboid\VICCS_HousingCareSystem\media\ui\Moodles"
os.makedirs(out_dir, exist_ok=True)

size = (64, 64)

# Paletas de Conforto (Tiers 1 a 4)
comfort_palettes = [
    {"bg": (34, 139, 34, 230), "border": (144, 238, 144, 255), "roof": (255, 255, 255, 255)},
    {"bg": (46, 160, 67, 240), "border": (173, 255, 47, 255), "roof": (255, 255, 255, 255)},
    {"bg": (0, 180, 100, 245), "border": (127, 255, 212, 255), "roof": (255, 255, 255, 255)},
    {"bg": (20, 200, 160, 255), "border": (255, 215, 0, 255), "roof": (255, 248, 220, 255)},
]

# Paletas de Squalor (Tiers 1 a 4)
squalor_palettes = [
    {"bg": (160, 120, 40, 230), "border": (218, 165, 32, 255)},
    {"bg": (180, 80, 30, 240), "border": (255, 127, 80, 255)},
    {"bg": (160, 30, 30, 245), "border": (255, 69, 0, 255)},
    {"bg": (120, 10, 50, 255), "border": (220, 20, 60, 255)},
]

# 1. Gerar Ícones de Conforto
for i, pal in enumerate(comfort_palettes, 1):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Círculo base
    draw.ellipse([2, 2, 61, 61], fill=pal["bg"], outline=pal["border"], width=3)
    
    # Telhado da Casa
    draw.polygon([(32, 14), (16, 28), (48, 28)], fill=pal["roof"])
    # Corpo da Casa
    draw.rectangle([20, 28, 44, 46], fill=pal["roof"])
    # Porta
    draw.rectangle([28, 36, 36, 46], fill=pal["bg"])
    # Janela
    draw.rectangle([23, 31, 27, 35], fill=pal["bg"])
    draw.rectangle([37, 31, 41, 35], fill=pal["bg"])
    
    # Indicador de Nível (Pontos/Estrelas no topo)
    for dot in range(i):
        dx = 32 - ((i - 1) * 6) + (dot * 12)
        draw.ellipse([dx - 2, 50, dx + 2, 54], fill=pal["border"])
        
    img.save(os.path.join(out_dir, f"LV_Comfort_{i}.png"))
    # Salva também minúsculo
    img.save(os.path.join(out_dir, f"lv_comfort_{i}.png"))

# 2. Gerar Ícones de Squalor
for i, pal in enumerate(squalor_palettes, 1):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Círculo base
    draw.ellipse([2, 2, 61, 61], fill=pal["bg"], outline=pal["border"], width=3)
    
    # Símbolo de Alerta / Mancha
    draw.polygon([(32, 14), (16, 46), (48, 46)], fill=(255, 255, 255, 240))
    # Exclamação central
    draw.rectangle([30, 24, 34, 36], fill=pal["bg"])
    draw.ellipse([30, 39, 34, 43], fill=pal["bg"])
    
    # Indicadores de Nível
    for dot in range(i):
        dx = 32 - ((i - 1) * 6) + (dot * 12)
        draw.ellipse([dx - 2, 50, dx + 2, 54], fill=pal["border"])
        
    img.save(os.path.join(out_dir, f"LV_Squalor_{i}.png"))
    img.save(os.path.join(out_dir, f"lv_squalor_{i}.png"))

print("Todos os ícones PNG de Moodlets gerados com sucesso!")
