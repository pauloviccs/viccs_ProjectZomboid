import os
import re

media_dir = 'media/lua'
all_good = True

for root, _, files in os.walk(media_dir):
    for f in files:
        if f.endswith('.lua'):
            fpath = os.path.join(root, f)
            with open(fpath, 'r', encoding='utf-8') as file:
                lines = file.readlines()
            
            stack = []
            for i, line in enumerate(lines, 1):
                cleaned = line.split('--')[0]
                cleaned = re.sub(r'"[^"\\]*(?:\\.[^"\\]*)*"', '', cleaned)
                cleaned = re.sub(r"'[^'\\]*(?:\\.[^'\\]*)*'", '', cleaned)
                tokens = re.findall(r'\b(?:function|if|for|while|repeat|end|until)\b', cleaned)
                for t in tokens:
                    if t in ('function', 'if', 'for', 'while', 'repeat'):
                        stack.append((i, t, line.strip()))
                    elif t in ('end', 'until'):
                        if stack:
                            stack.pop()
                        else:
                            print(f"[ERROR] Extra {t} at line {i} in {fpath}")
                            all_good = False
            if len(stack) > 0:
                print(f"[ERROR] {len(stack)} unclosed blocks in {fpath}:")
                for item in stack:
                    print(f"  Line {item[0]}: {item[1]} -> {item[2]}")
                all_good = False

if all_good:
    print("[SUCCESS] All Lua files in media/lua/ have perfectly balanced blocks!")
