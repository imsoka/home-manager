# Convierte un JSON de jmdict-simplified en un diccionario DSL de GoldenDict.
# Uso: jmdict2dsl.py <jmdict.json> <nombre> <idioma> <salida.dsl>
import json
import sys

src, name, language, out = sys.argv[1:]

# Kana a romaji Hepburn. No se usa kakasi porque se cuelga en el sandbox de Nix
KANA = dict(zip(
    "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめも"
    "やゆよらりるれろわゐゑをんがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽゔ"
    "ぁぃぅぇぉゃゅょゎ",
    "a i u e o ka ki ku ke ko sa shi su se so ta chi tsu te to na ni nu ne no "
    "ha hi fu he ho ma mi mu me mo ya yu yo ra ri ru re ro wa i e o n "
    "ga gi gu ge go za ji zu ze zo da ji zu de do ba bi bu be bo pa pi pu pe po vu "
    "a i u e o ya yu yo wa".split(),
))
MACRON = dict(zip("aeiou", "āēīōū"))


def to_romaji(word):
    # Katakana a hiragana (mismo orden en Unicode, desplazado 0x60)
    word = "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in word)
    out = ""
    i = 0
    while i < len(word):
        c = word[i]
        nxt = word[i + 1] if i + 1 < len(word) else ""
        if c == "っ":
            r = to_romaji(word[i + 1:i + 3])[:3] if nxt else ""
            out += ("t" if r.startswith("ch") else r[:1]) if r[:1] not in "aeiou" else ""
        elif c == "ー":
            if out and out[-1] in MACRON:
                out = out[:-1] + MACRON[out[-1]]
        elif c in KANA and nxt in "ゃゅょ" and nxt and KANA[c].endswith("i") and c != "い":
            base = KANA[c][:-1]
            out += base + KANA[nxt][1:] if base[-1:] in ("h", "j") else base + KANA[nxt]
            i += 1
        elif c in KANA and nxt in "ぁぃぅぇぉ" and nxt and c in "ふゔてでうしじちつ":
            # ティ/ディ conservan la consonante; ウィ/ウェ llevan "w"
            base = {"て": "t", "で": "d", "う": "w"}.get(c, KANA[c][:-1])
            out += base + KANA[nxt]
            i += 1
        elif c == "ん":
            out += "n'" if nxt and KANA.get(nxt, "x")[0] in "aeiouy" else "n"
        elif c in KANA:
            out += KANA[c]
        else:
            return ""
        i += 1
    return out


def esc_body(s):
    return "".join("\\" + c if c in "\\[]{}~@^<>" else c for c in s)


def esc_head(s):
    return "".join("\\" + c if c in "\\[]{}()~@^<>" else c for c in s)


with open(src, encoding="utf-8") as f:
    words = json.load(f)["words"]

lines = [
    f'#NAME "{name}"',
    '#INDEX_LANGUAGE "Japanese"',
    f'#CONTENTS_LANGUAGE "{language}"',
    "",
]

for w in words:
    kanji = [k["text"] for k in w["kanji"]]
    kana = [k["text"] for k in w["kana"]]
    senses = [s for s in w["sense"] if s["gloss"]]
    if not senses:
        continue

    lines += [esc_head(h) for h in dict.fromkeys(kanji + kana)]

    # La cabecera ya muestra la forma buscada: las demás solo si hay varias
    if len(kanji) > 1:
        lines.append(f"\t[m0][b]{esc_body('・'.join(kanji))}[/b][/m]")
    readings = "・".join(
        f"{esc_body(k)} [c gray]{esc_body(to_romaji(k))}[/c]" if to_romaji(k) else esc_body(k)
        for k in kana
    )
    lines.append(f"\t[m0]{readings}[/m]")

    for i, s in enumerate(senses, 1):
        tags = ", ".join(s["partOfSpeech"] + s["misc"] + s["field"])
        gloss = "; ".join(g["text"] for g in s["gloss"])
        line = f"\t[m1]{i}. "
        if tags:
            line += f"[i][c green]{esc_body(tags)}[/c][/i] "
        line += esc_body(gloss)
        if s["info"]:
            line += f" [c gray]({esc_body('; '.join(s['info']))})[/c]"
        lines.append(line + "[/m]")
    lines.append("")

with open(out, "w", encoding="utf-16") as f:
    f.write("\n".join(lines))
