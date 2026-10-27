# Diccionario "programa" de GoldenDict: recibe la palabra como argumento y
# devuelve en HTML su romaji (Hepburn) y su lectura en hiragana
word="$1"
romaji=$(printf '%s' "$word" | kakasi -i utf8 -o utf8 -Ja -Ha -Ka -Ea -s)
kana=$(printf '%s' "$word" | kakasi -i utf8 -o utf8 -JH -KH)
printf '<div style="font-size:1.8em;font-weight:bold">%s</div>\n' "$romaji"
printf '<div style="font-size:1.2em;opacity:.7">%s</div>\n' "$kana"
