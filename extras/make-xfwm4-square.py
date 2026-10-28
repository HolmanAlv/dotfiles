#!/usr/bin/env python3
"""Genera el tema xfwm4 "Square" a partir del Default de xfwm4.

Default ya toma sus colores del tema GTK (XPM simbólicos): barra oscura, botones x □ _.
Aquí solo se cuadran las esquinas y se añade un contorno de 1px oscuro (*_shadow_2).
Los PNG de sombreado de Default se descartan: look plano.

uso: make-xfwm4-square.py [origen] [destino]
"""
import pathlib
import sys

SRC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/usr/share/themes/Default/xfwm4")
DST = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else
                   pathlib.Path(__file__).resolve().parent.parent / "home/.local/share/themes/Square/xfwm4")
OUT = "%"  # carácter libre para el color del contorno


def edges(name):
    """Qué lados de la pieza tocan el exterior de la ventana."""
    part = name.rsplit("-", 1)[0]  # top-left-active -> top-left
    if part in ("left", "right", "bottom"):
        return {part}
    if part.startswith("bottom-"):
        return {"bottom", part.split("-")[1]}
    if part.startswith("top-"):
        return {"top", part.split("-")[1]}
    return {"top"}  # título y botones


def square(xpm, name):
    lines = xpm.splitlines()
    start = next(i for i, l in enumerate(lines) if l.lstrip().startswith('"'))
    w, h, ncolors, cpp = map(int, lines[start].strip('",').split()[:4])
    assert cpp == 1, name
    colors = lines[start + 1:start + 1 + ncolors]
    rows = [l.strip().rstrip(",").rstrip("};").strip('"') for l in lines[start + 1 + ncolors:start + 1 + ncolors + h]]
    none = next((c[1] for c in colors if c.rstrip('",').endswith("c None")), None)
    state = "inactive" if "inactive" in name else "active"
    side = edges(name)
    grid = [list(r) for r in rows]
    if name.startswith("top-") and none:  # esquina redondeada: rellenar todo lo transparente
        fill = next(c[1] for c in colors if "c None" not in c)
        grid = [[fill if ch == none else ch for ch in r] for r in grid]
    for y in range(h):
        for x in range(w):
            outer = ("top" in side and y == 0) or ("bottom" in side and y == h - 1) or \
                    ("left" in side and x == 0) or ("right" in side and x == w - 1)
            # en las esquinas inferiores el píxel exterior redondeado también es contorno
            if outer and (grid[y][x] != none or name.startswith("bottom-")):
                grid[y][x] = OUT
    colors.append(f'"{OUT}      c #000000 s {state}_shadow_2",')
    head = f'"{w} {h} {ncolors + 1} 1",'
    body = [f'"{"".join(r)}",' for r in grid]
    body[-1] = body[-1].rstrip(",") + "};"
    return "\n".join(lines[:start] + [head] + colors + body) + "\n"


DST.mkdir(parents=True, exist_ok=True)
for f in sorted(SRC.glob("*.xpm")):
    (DST / f.name).write_text(square(f.read_text(), f.stem))
themerc = (SRC / "themerc").read_text()
(DST / "themerc").write_text("# Generado por extras/make-xfwm4-square.py desde el Default de xfwm4\n" + themerc)
print(f"{len(list(DST.glob('*.xpm')))} xpm -> {DST}")
