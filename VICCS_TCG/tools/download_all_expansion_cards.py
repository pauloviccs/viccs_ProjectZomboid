import os
import io
import re
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from PIL import Image

TARGET_WIDTH = 240
TARGET_HEIGHT = 336
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"

CARDS_DIR = os.path.join("media", "textures", "cards")

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def fetch_image_bytes(url, referer=None, retries=3):
    headers = {"User-Agent": USER_AGENT}
    if referer:
        headers["Referer"] = referer
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=15) as resp:
                return resp.read()
        except Exception as e:
            if attempt == retries - 1:
                raise e
            time.sleep(1.0 + attempt)
    raise RuntimeError(f"Failed to fetch {url}")

def process_and_save_card(img_bytes, dest_path):
    im = Image.open(io.BytesIO(img_bytes))
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    im_resized = im.resize((TARGET_WIDTH, TARGET_HEIGHT), Image.Resampling.LANCZOS)
    im_resized.save(dest_path, format="PNG", optimize=True)

def download_tcgdex_set(set_id, folder_name, total_cards):
    dest_dir = os.path.join(CARDS_DIR, folder_name)
    ensure_dir(dest_dir)
    print(f"\n[+] Ingesting {folder_name.upper()} ({total_cards} cards) from TCGDex...")
    
    tasks = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        for num in range(1, total_cards + 1):
            dest_file = os.path.join(dest_dir, f"{num:03d}.png")
            if os.path.exists(dest_file) and os.path.getsize(dest_file) > 1000:
                continue
            
            url_png = f"https://assets.tcgdex.net/en/base/{set_id}/{num}/high.png"
            url_webp = f"https://assets.tcgdex.net/en/base/{set_id}/{num}/high.webp"
            
            def dl(n=num, dest=dest_file, p_url=url_png, w_url=url_webp):
                try:
                    data = fetch_image_bytes(p_url)
                except Exception:
                    data = fetch_image_bytes(w_url)
                process_and_save_card(data, dest)
                return n
            
            tasks.append(executor.submit(dl))
            
        completed = 0
        for f in as_completed(tasks):
            try:
                card_num = f.result()
                completed += 1
                if completed % 10 == 0 or completed == len(tasks):
                    print(f"  [{folder_name}] Progress: {completed}/{len(tasks)} downloaded.")
            except Exception as e:
                print(f"  [!] Error downloading card: {e}")
                raise e

def download_eevee_heroes():
    folder_name = "eeveeheroes"
    dest_dir = os.path.join(CARDS_DIR, folder_name)
    ensure_dir(dest_dir)
    print(f"\n[+] Ingesting EEVEE HEROES (101 cards) from Pokellector...")
    
    # 1. Scrape Pokellector page
    catalog_url = "https://www.pokellector.com/Eevee-Heroes-Expansion/"
    html = fetch_image_bytes(catalog_url).decode("utf-8")
    
    # Extract each card: <div class="card "> ... <div class="plaque">#(\d+) - (.*?)</div>
    card_divs = re.findall(r'<div class="card\s*">.*?data-src="([^"]+)".*?<div class="plaque">#(\d+)\s*-\s*(.*?)</div>', html, re.DOTALL)
    print(f"  Pokellector matched {len(card_divs)} card definitions.")
    
    cards_map = {}
    for thumb_url, num_str, name in card_divs:
        num = int(num_str)
        # thumb_url: https://den-cards.pokellector.com/322/Pinsir.S6A.1.38923.thumb.png
        # full url: https://den-cards.pokellector.com/322/Pinsir.S6A.1.38923.png
        full_url = thumb_url.replace(".thumb.png", ".png")
        cards_map[num] = {
            "name": name.strip(),
            "full_url": full_url,
            "thumb_url": thumb_url
        }
    
    tasks = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        for num in range(1, 102):
            dest_file = os.path.join(dest_dir, f"{num:03d}.png")
            if os.path.exists(dest_file) and os.path.getsize(dest_file) > 1000:
                continue
            
            card_info = cards_map.get(num)
            if not card_info:
                raise RuntimeError(f"Missing card #{num} in Pokellector map!")
            
            def dl_eevee(n=num, dest=dest_file, info=card_info):
                try:
                    data = fetch_image_bytes(info["full_url"], referer="https://www.pokellector.com/")
                except Exception:
                    data = fetch_image_bytes(info["thumb_url"], referer="https://www.pokellector.com/")
                process_and_save_card(data, dest)
                return n
            
            tasks.append(executor.submit(dl_eevee))
            
        completed = 0
        for f in as_completed(tasks):
            try:
                card_num = f.result()
                completed += 1
                if completed % 10 == 0 or completed == len(tasks):
                    print(f"  [eeveeheroes] Progress: {completed}/{len(tasks)} downloaded.")
            except Exception as e:
                print(f"  [!] Error downloading Eevee Heroes card: {e}")
                raise e
    
    return cards_map

def verify_all():
    print("\n[+] Verifying all downloaded expansion card textures...")
    sets = {
        "jungle": 64,
        "fossil": 62,
        "rocket": 83,
        "eeveeheroes": 101
    }
    all_ok = True
    total_checked = 0
    for s_name, count in sets.items():
        s_dir = os.path.join(CARDS_DIR, s_name)
        if not os.path.exists(s_dir):
            print(f"  [!] Missing directory: {s_dir}")
            all_ok = False
            continue
        files = os.listdir(s_dir)
        print(f"  Checking {s_name}: found {len(files)}/{count} files.")
        if len(files) != count:
            all_ok = False
        for num in range(1, count + 1):
            fpath = os.path.join(s_dir, f"{num:03d}.png")
            if not os.path.exists(fpath):
                print(f"    [!] Missing {fpath}")
                all_ok = False
                continue
            try:
                im = Image.open(fpath)
                if im.size != (TARGET_WIDTH, TARGET_HEIGHT) or im.mode != "RGBA":
                    print(f"    [!] Invalid spec {fpath}: size={im.size} mode={im.mode}")
                    all_ok = False
                total_checked += 1
            except Exception as e:
                print(f"    [!] Corrupt image {fpath}: {e}")
                all_ok = False
    
    if all_ok:
        print(f"\n[OK] All {total_checked} cards verified successfully! Spec 240x336 RGBA PNG 100% compliant.")
    else:
        print(f"\n[FAIL] Some cards failed verification.")
    return all_ok

if __name__ == "__main__":
    print("=== TCG Expansion Cards Downloader & Ingestion ===")
    download_tcgdex_set("base2", "jungle", 64)
    download_tcgdex_set("base3", "fossil", 62)
    download_tcgdex_set("base5", "rocket", 83)
    download_eevee_heroes()
    ok = verify_all()
    if not ok:
        sys.exit(1)
