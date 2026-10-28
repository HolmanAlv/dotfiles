#!/usr/bin/env python3
"""Iconos -symbolic para cualquier icono de bandeja, sacados del tema de iconos Everforest-Dark (Papirus).

Las apps de bandeja piden un nombre (redshift-status-on, vlc...). La bandeja (symbolic-icons) y los
GtkStatusIcon (`window > image` en gtk.css) buscan antes "<nombre>-symbolic" en todos los temas y GTK
los recolorea al color del panel. hicolor es el último tema, así que esto solo rellena huecos.
Prioridad: panel/16, panel/22 recortado a su caja de 16px (misma altura), apps/symbolic.
Las apps que mandan imagen en vez de nombre (Electron) no pasan por aquí: se configuran en la app.

uso: make-tray-symbolic.py [Everforest-Dark]  ->  extras/icons/tray-symbolic.tar.zst (symbolic/apps/)
"""
import io
import pathlib
import re
import subprocess
import sys
import tempfile

from PIL import Image

SRC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path.home() / ".local/share/icons/Everforest-Dark")
REPO = pathlib.Path(__file__).resolve().parent.parent
OWN = {p.stem for p in (REPO / "home/.local/share/icons/hicolor/scalable/apps").glob("*.svg")}  # hechos a mano: mandan
ALIASES = {  # nombre que pide la app -> icono que se usa
    "barrier": "synergy-symbolic",  # Barrier es un fork de Synergy
    "org.xfce.notes.tray": "xfce4-notes-plugin-symbolic",
}


def crop16(svg, path):
    """Los iconos de panel de 22px dejan 3px de margen: viewBox a la caja interior si el dibujo cabe."""
    png = subprocess.run(["rsvg-convert", "-w", "22", "-h", "22", path], capture_output=True).stdout
    box = Image.open(io.BytesIO(png)).getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox() if png else None
    tag = re.search(r"<svg\b[^>]*>", svg).group(0)
    vb = re.search(r'viewBox="([^"]*)"', tag)
    if not box or min(box[:2]) < 3 or max(box[2:]) > 19 or (vb and vb.group(1).split() != ["0", "0", "22", "22"]):
        return svg
    new = re.sub(r'\s(width|height|viewBox)="[^"]*"', "", tag).replace(
        "<svg", '<svg width="16" height="16" viewBox="3 3 16 16"', 1)
    return svg.replace(tag, new, 1)


icons = {}  # nombre de salida -> contenido
for f in sorted((SRC / "panel/16").glob("*.svg")):
    icons[f"{f.stem}-symbolic"] = f.read_text()
for f in sorted((SRC / "panel/22").glob("*.svg")):
    if f"{f.stem}-symbolic" not in icons:
        icons[f"{f.stem}-symbolic"] = crop16(f.read_text(), f)
for f in sorted((SRC / "apps/symbolic").glob("*-symbolic.svg")):
    if f.exists():  # enlaces rotos fuera
        icons.setdefault(f.stem, f.read_text())
for name, target in ALIASES.items():
    icons[f"{name}-symbolic"] = icons[target]
for name in OWN:
    icons.pop(name, None)

with tempfile.TemporaryDirectory() as tmp:
    out = pathlib.Path(tmp, "symbolic/apps")
    out.mkdir(parents=True)
    for name, svg in icons.items():
        (out / f"{name}.svg").write_text(svg)
    tar = REPO / "extras/icons/tray-symbolic.tar.zst"
    subprocess.run(["tar", "-C", tmp, "--zstd", "-cf", tar, "symbolic"], check=True)
print(f"{len(icons)} iconos -> {tar} ({tar.stat().st_size // 1024} KiB)")
