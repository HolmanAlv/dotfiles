#!/usr/bin/env python3
"""Genera el tema xfwm4 "Square" a partir del Default de xfwm4.

Default ya toma sus colores del tema GTK (XPM simbólicos): barra oscura, botones x □ _.
Aquí solo se cuadran las esquinas y se añade un contorno de 1px oscuro (*_shadow_2).
Los PNG de sombreado de Default se descartan: look plano.
Los botones (salvo el menú, que muestra el icono de la app) son los círculos de Fausto (Everforest-GTK-Theme).

uso: make-xfwm4-square.py [origen] [destino]
"""
import pathlib
import sys

SRC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/usr/share/themes/Default/xfwm4")
DST = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else
                   pathlib.Path(__file__).resolve().parent.parent / "home/.local/share/themes/Square/xfwm4")
OUT = "%"  # carácter libre para el color del contorno
TITLE = 22  # alto de la barra de título (Default trae 29)
CIRCLE_ON_HOVER = True  # en reposo solo el símbolo; el círculo gris sale al pasar el ratón. False: siempre círculo
FAUSTO = pathlib.Path.home() / ".themes/Everforest-Dark/xfwm4"  # botones redondos (los PNG quedan en el repo)
BUTTONS = {"close", "hide", "maximize", "maximize-toggled", "shade", "shade-toggled", "stick", "stick-toggled"}


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
    if "top" in side and h > TITLE:  # barra más fina: recorte centrado (las filas son lisas; los glifos quedan en medio)
        cut = (h - TITLE) // 2
        rows, h = rows[cut:cut + TITLE], TITLE
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


def circle(png):
    """Botón redondo del Everforest-Dark de Fausto: PNG sin su fondo encima de un XPM con el color de la barra."""
    im = Image.open(png).convert("RGBA").crop((0, 2, 36, 31))  # 34px -> los 29 de la barra de Default
    bg = im.getpixel((1, 15))
    px = im.load()
    for x in range(im.width):
        for y in range(im.height):
            if sum(abs(a - b) for a, b in zip(px[x, y][:3], bg[:3])) < 6:
                px[x, y] = (0, 0, 0, 0)
    if CIRCLE_ON_HOVER and png.stem.rsplit("-", 1)[1] in ("active", "inactive"):
        # el símbolo es lo más claro que el círculo: opacidad proporcional a cuánto lo aclara (conserva el antialias)
        lum = lambda p: p[0] + p[1] + p[2]
        opaque = [px[x, y] for x in range(im.width) for y in range(im.height) if px[x, y][3]]
        disc = max(set(opaque), key=opaque.count)
        glyph = max(opaque, key=lum)
        for x in range(im.width if lum(glyph) > lum(disc) else 0):  # los "stick" de Fausto no llevan círculo
            for y in range(im.height):
                a = (lum(px[x, y]) - lum(disc)) / (lum(glyph) - lum(disc)) if px[x, y][3] else 0
                px[x, y] = glyph[:3] + (round(255 * min(max(a, 0), 1)),)
    im = im.resize((round(im.width * TITLE / im.height), TITLE), Image.LANCZOS)  # Pillow premultiplica el alfa
    im.save(DST / png.name)
    w, h = im.size
    state = "inactive" if "inactive" in png.stem else "active"
    fill = "inactive_color_2" if state == "inactive" else "active_mid_2"  # lo mismo que title-*.xpm
    rows = ["%" * w] + ["." * w] * (h - 1)
    (DST / f"{png.stem}.xpm").write_text("\n".join(
        ["/* XPM */", f"static char * {png.stem.replace('-', '_')}_xpm[] = {{", f'"{w} {h} 2 1",',
         f'".      c #C0C0FF s {fill}",', f'"%      c #000000 s {state}_shadow_2",']
        + [f'"{r}",' for r in rows[:-1]] + [f'"{rows[-1]}"}};']) + "\n")


DST.mkdir(parents=True, exist_ok=True)
for f in sorted(SRC.glob("*.xpm")):
    (DST / f.name).write_text(square(f.read_text(), f.stem))
if FAUSTO.is_dir():  # sin él se quedan los botones _ □ x de Default
    from PIL import Image
    for png in FAUSTO.glob("*.png"):
        if png.stem.rsplit("-", 1)[0] in BUTTONS:
            circle(png)
themerc = (SRC / "themerc").read_text().replace("button_spacing=2", "button_spacing=0")
(DST / "themerc").write_text("# Generado por extras/make-xfwm4-square.py desde el Default de xfwm4\n" + themerc)
print(f"{len(list(DST.glob('*.xpm')))} xpm -> {DST}")
