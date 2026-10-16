# Uso: set-default-compat-tool <config.vdf> <directorio de la herramienta>
# Pone la herramienta como compatibilidad por defecto ("0" en
# CompatToolMapping). Steam tiene que estar cerrado.
#
# config.vdf se edita como texto: reescribirlo con vdf.dump convierte los
# saltos de línea de valores como SDL_GamepadBind en "\n" literales.
import re
import shutil
import sys

import vdf

path, tool_dir = sys.argv[1], sys.argv[2]

# Nombre interno: primera clave de compat_tools en compatibilitytool.vdf
with open(f"{tool_dir}/compatibilitytool.vdf", encoding="utf-8") as f:
    tools = vdf.load(f)
tools = next(v for k, v in tools.items() if k.lower() == "compatibilitytools")
name = next(iter(tools["compat_tools"]))

with open(path, encoding="utf-8") as f:
    lines = f.readlines()


def key_of(line):
    m = re.match(r'\s*"([^"]*)"\s*$', line)
    return m and m.group(1)


def block_end(start):
    # start apunta a la línea "{"; devuelve el índice de su "}"
    depth = 0
    for i in range(start, len(lines)):
        s = lines[i].strip()
        depth += (s == "{") - (s == "}")
        if depth == 0:
            return i
    sys.exit("config.vdf: llaves sin cerrar")


mapping = next((i for i, line in enumerate(lines)
                if (key_of(line) or "").lower() == "compattoolmapping"), None)
if mapping is None or lines[mapping + 1].strip() != "{":
    sys.exit("config.vdf: no hay CompatToolMapping")

indent = re.match(r"\s*", lines[mapping]).group(0) + "\t"
entry = [
    f'{indent}"0"\n', f"{indent}{{\n",
    f'{indent}\t"name"\t\t"{name}"\n',
    f'{indent}\t"config"\t\t""\n',
    f'{indent}\t"priority"\t\t"75"\n',
    f"{indent}}}\n",
]

# Sustituye la entrada "0" (directamente bajo CompatToolMapping) o la añade
i, end = mapping + 2, block_end(mapping + 1)
while i < end:
    if key_of(lines[i]) == "0" and lines[i + 1].strip() == "{":
        lines[i:block_end(i + 1) + 1] = entry
        break
    i = block_end(i + 1) + 1 if lines[i + 1].strip() == "{" else i + 1
else:
    lines[mapping + 2:mapping + 2] = entry

shutil.copy2(path, path + ".bak")
with open(path, "w", encoding="utf-8") as f:
    f.writelines(lines)
