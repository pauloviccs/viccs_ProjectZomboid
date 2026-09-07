import os
import re

def check_lua_blocks(path):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()

    # Remove block comments --[[ ... ]]
    content = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)
    # Remove single line comments
    content = re.sub(r'--.*$', '', content, flags=re.MULTILINE)
    # Remove strings
    content = re.sub(r'"(\\.|[^"\\])*"', '""', content)
    content = re.sub(r"'(\\.|[^'\\])*'", "''", content)
    # Remove [[ multiline strings ]]
    content = re.sub(r'\[\[.*?\]\]', '""', content, flags=re.DOTALL)

    # Substitui 'elseif ... then' por nada
    content = re.sub(r'\belseif\b[^\n]*?\bthen\b', ' ', content)

    tokens = re.findall(r'\b(function|then|do|repeat|until|end)\b', content)
    opens = 0
    for t in tokens:
        if t in ('function', 'then', 'do', 'repeat'):
            opens += 1
        elif t in ('until', 'end'):
            opens -= 1
            if opens < 0:
                return False, 'End or until without open token'
    if opens != 0:
        return False, f'Unbalanced tokens: opens={opens}'
    return True, 'OK'

def main():
    errors = []
    checked = 0
    for root, _, files in os.walk('media/lua'):
        for f in files:
            if f.endswith('.lua'):
                p = os.path.join(root, f)
                ok, msg = check_lua_blocks(p)
                checked += 1
                if not ok:
                    errors.append((p, msg))

    if not errors:
        print(f"SINTAXE LUA PERFEITA: Todos os {checked} arquivos Lua estao com blocos 100% balanceados!")
    else:
        print(f"Erros detectados em {len(errors)} arquivos:")
        for p, msg in errors:
            print(f"  {p}: {msg}")

if __name__ == '__main__':
    main()
