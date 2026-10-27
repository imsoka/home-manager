# Diccionario "programa" de GoldenDict: recibe la palabra como argumento y
# devuelve en HTML su romaji (Hepburn) y su lectura en hiragana
word="$1"
# kakasi marca las vocales largas de katakana con "^" (ko^hi^): macrón (kōhī)
romaji=$(printf '%s' "$word" | kakasi -i utf8 -o utf8 -Ja -Ha -Ka -Ea -s \
  | sed 's/a\^/ā/g; s/e\^/ē/g; s/i\^/ī/g; s/o\^/ō/g; s/u\^/ū/g')
kana=$(printf '%s' "$word" | kakasi -i utf8 -o utf8 -JH -KH)
printf '<div style="font-size:1.8em;font-weight:bold">%s</div>\n' "$romaji"
printf '<div style="font-size:1.2em;opacity:.7">%s</div>\n' "$kana"
