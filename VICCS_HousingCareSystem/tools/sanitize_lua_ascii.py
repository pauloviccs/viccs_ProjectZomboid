import os
import unicodedata

# Tabela explícita de substituição para preservar termos técnicos em português
REPLACEMENTS = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'ê': 'e', 'è': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
    'Á': 'A', 'À': 'A', 'Ã': 'A', 'Â': 'A', 'Ä': 'A',
    'É': 'E', 'Ê': 'E', 'È': 'E', 'Ë': 'E',
    'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
    'Ó': 'O', 'Ò': 'O', 'Õ': 'O', 'Ô': 'O', 'Ö': 'O',
    'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
    'Ç': 'C',
    '°': 'C',
    '•': '-',
    '–': '-', '—': '-',
    '’': "'", '‘': "'",
    '“': '"', '”': '"',
}

def clean_text(text):
    for k, v in REPLACEMENTS.items():
        text = text.replace(k, v)
    # Remove qualquer outro caractere não-ascii que possa ter sobrado
    cleaned = []
    for ch in text:
        if ord(ch) < 128:
            cleaned.append(ch)
        else:
            # tenta desmembrar acento se houver
            decomposed = unicodedata.normalize('NFD', ch)
            ascii_equiv = ''.join(c for c in decomposed if ord(c) < 128)
            cleaned.append(ascii_equiv if ascii_equiv else '?')
    return ''.join(cleaned)

def main():
    target_dir = os.path.join('media', 'lua')
    modified_files = 0
    total_non_ascii = 0

    for root, _, files in os.walk(target_dir):
        for f in files:
            if f.endswith('.lua'):
                p = os.path.join(root, f)
                with open(p, 'r', encoding='utf-8', errors='replace') as fl:
                    content = fl.read()

                # Verifica se há caracteres não-ASCII
                has_non_ascii = any(ord(ch) >= 128 for ch in content)
                if has_non_ascii:
                    cleaned_content = clean_text(content)
                    with open(p, 'w', encoding='utf-8', newline='\n') as fl:
                        fl.write(cleaned_content)
                    print(f"Sanitized: {p}")
                    modified_files += 1

    print(f"\nConcluido! {modified_files} arquivos sanitizados para ASCII limpo.")

if __name__ == '__main__':
    main()
