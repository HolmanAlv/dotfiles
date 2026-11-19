#!/usr/bin/env python3
"""Writes the Plasma style "Square" to kde/home: the color scheme's colors, straight corners, no blur.

Every frame is the same nine tiles. What is not written here comes from Breeze, always the last fallback.
Run it again after changing this file; the result is what install.sh copies.
"""
import json
import pathlib
import shutil

OUT = pathlib.Path(__file__).resolve().parent / 'home/.local/share/plasma/desktoptheme/Square'
TILE = 4  # px; the thickest line must fit in it
TASK_ICON_MARGIN = (48 - 22) // 2  # the bar's height less the icon size: task buttons fill the bar, down to the screen's edge

BG, TEXT, ACCENT, VIEW, BUTTON = 'Background', 'Text', 'Highlight', 'ViewBackground', 'ButtonBackground'
STYLE = ('<style type="text/css" id="current-color-scheme">'
         '.ColorScheme-Background{color:#0b0b10;}.ColorScheme-Text{color:#d5d6e0;}.ColorScheme-Highlight{color:#ff2e4d;}'
         '.ColorScheme-ViewBackground{color:#0b0b10;}.ColorScheme-ButtonBackground{color:#1e1e27;}</style>')


def rect(x, y, w, h, color, opacity, extra=''):
    return (f'<rect {extra}x="{x}" y="{y}" width="{w}" height="{h}" class="ColorScheme-{color}" '
            f'style="fill:currentColor;fill-opacity:{opacity}"/>')


def frame(prefix, top, fill=None, line=None, sides='tlrb', width=1, margin=2, tb=None):
    """One frame at height `top`. fill and line are (color, opacity); margin is the hint for all sides, tb for top and bottom."""
    tb = margin if tb is None else tb
    p = f'{prefix}-' if prefix else ''
    out = []
    names = ['topleft', 'top', 'topright', 'left', 'center', 'right', 'bottomleft', 'bottom', 'bottomright']
    for n, name in enumerate(names):
        col, row = n % 3, n // 3
        x, y = col * (TILE + 2), top + row * (TILE + 2)
        parts = [rect(x, y, TILE, TILE, *(fill or (BG, 0)))]
        if line:
            if 't' in sides and row == 0:
                parts.append(rect(x, y, TILE, width, *line))
            if 'b' in sides and row == 2:
                parts.append(rect(x, y + TILE - width, TILE, width, *line))
            if 'l' in sides and col == 0:
                parts.append(rect(x, y, width, TILE, *line))
            if 'r' in sides and col == 2:
                parts.append(rect(x + TILE - width, y, width, TILE, *line))
        out.append(f'<g id="{p}{name}">{"".join(parts)}</g>')
    x = 3 * (TILE + 2)
    for side, size in (('top', (1, tb)), ('bottom', (1, tb)), ('left', (margin, 1)), ('right', (margin, 1))):
        out.append(f'<rect id="{p}hint-{side}-margin" x="{x}" y="{top}" width="{size[0]}" height="{size[1]}" fill="none"/>')
    return out


def write(path, frames):
    """frames: a list of keyword sets for frame(), the first argument being the prefix."""
    body, top = [], 0
    for args in frames:
        body += frame(args[0], top, **args[1])
        top += 3 * (TILE + 2) + 2
    f = OUT / f'{path}.svg'
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="40" height="{top}" viewBox="0 0 40 {top}">{STYLE}\n'
                 + '\n'.join(body) + '\n</svg>\n')


def tasks():
    for location, side in (('', 'b'), ('north-', 't'), ('east-', 'r'), ('west-', 'l')):
        tb = TASK_ICON_MARGIN if side in 'bt' else None
        yield f'{location}normal', dict(line=(TEXT, 0.35), sides=side, tb=tb)
        yield f'{location}focus', dict(fill=(TEXT, 0.07), line=(ACCENT, 1), sides=side, width=3, tb=tb)
        yield f'{location}hover', dict(fill=(TEXT, 0.12), line=(ACCENT, 0.5), sides=side, width=3, tb=tb)
        yield f'{location}attention', dict(fill=(ACCENT, 0.3), line=(ACCENT, 1), sides=side, width=3, tb=tb)
        yield f'{location}minimized', dict(line=(TEXT, 0.15), sides=side, tb=tb)
        yield f'{location}progress', dict(fill=(ACCENT, 0.25), tb=tb)


FRAMES = {
    # The bar is opaque in solid/ (when a window touches it, if set to adaptive) and 60 % otherwise.
    # A margin this big makes Plasma pad the bar so that what is in it is exactly 22 px high, like the tray: the panel's
    # getMargins clamps it to that. Plain frames are for the bar's ends, thick for its middle. Only top and bottom, so the
    # vertical dock keeps its icons' size.
    'widgets/panel-background': [('', dict(fill=(BG, 0.6), line=(TEXT, 0.1), tb=30)), ('thick', dict(tb=30))],
    'solid/widgets/panel-background': [('', dict(fill=(BG, 1), line=(TEXT, 0.1), tb=30)), ('thick', dict(tb=30))],
    'dialogs/background': [('', dict(fill=(BG, 1), line=(TEXT, 0.18), margin=4))],
    'solid/dialogs/background': [('', dict(fill=(BG, 1), line=(TEXT, 0.18), margin=4))],
    'widgets/tooltip': [('', dict(fill=(BG, 1), line=(TEXT, 0.18), margin=4))],
    'solid/widgets/tooltip': [('', dict(fill=(BG, 1), line=(TEXT, 0.18), margin=4))],
    'widgets/background': [('', dict(fill=(BG, 0.85), line=(TEXT, 0.12), margin=8))],
    'widgets/translucentbackground': [('', dict(fill=(BG, 0.6), line=(TEXT, 0.12), margin=8))],
    'widgets/tasks': list(tasks()),
    'widgets/viewitem': [
        ('normal', dict(margin=4)),
        ('hover', dict(fill=(TEXT, 0.08), line=(TEXT, 0.15), margin=4)),
        ('selected', dict(fill=(ACCENT, 0.25), line=(ACCENT, 0.7), margin=4)),
        ('selected+hover', dict(fill=(ACCENT, 0.35), line=(ACCENT, 1), margin=4)),
    ],
    'widgets/button': [
        ('normal', dict(fill=(BUTTON, 1), line=(TEXT, 0.2), margin=5)),
        ('hover', dict(fill=(BUTTON, 1), line=(ACCENT, 0.7), margin=5)),
        ('pressed', dict(fill=(ACCENT, 0.3), line=(ACCENT, 1), margin=5)),
        ('focus', dict(line=(ACCENT, 1), margin=5)),
        ('shadow', dict()),
        ('toolbutton-hover', dict(fill=(TEXT, 0.1), margin=3)),
        ('toolbutton-pressed', dict(fill=(ACCENT, 0.3), margin=3)),
        ('toolbutton-focus', dict(line=(ACCENT, 0.6), margin=3)),
    ],
    'widgets/lineedit': [
        ('base', dict(fill=(VIEW, 1), line=(TEXT, 0.2), margin=5)),
        ('hover', dict(line=(ACCENT, 0.5), margin=5)),
        ('focus', dict(line=(ACCENT, 1), margin=5)),
        ('focusframe', dict(line=(ACCENT, 1), margin=5)),
    ],
    'widgets/frame': [(p, dict(line=(TEXT, 0.12))) for p in ('plain', 'raised', 'sunken')],
    'widgets/listitem': [
        ('normal', dict(margin=4)),
        ('hover', dict(fill=(TEXT, 0.08), margin=4)),
        ('pressed', dict(fill=(ACCENT, 0.25), margin=4)),
        ('section', dict(fill=(TEXT, 0.05), margin=4)),
    ],
    'widgets/menubaritem': [
        ('normal', dict(margin=3)),
        ('hover', dict(fill=(TEXT, 0.1), margin=3)),
        ('pressed', dict(fill=(ACCENT, 0.3), margin=3)),
    ],
    'widgets/tabbar': [(f'{name}-active-tab', dict(line=(ACCENT, 1), sides=side, width=2, margin=4))
                       for name, side in (('north', 'b'), ('south', 't'), ('east', 'l'), ('west', 'r'))],
    'widgets/plasmoidheading': [
        ('header', dict(fill=(TEXT, 0.04), line=(TEXT, 0.1), sides='b', margin=4)),
        ('footer', dict(fill=(TEXT, 0.04), line=(TEXT, 0.1), sides='t', margin=4)),
    ],
    'widgets/pager': [
        ('normal', dict(line=(TEXT, 0.2))),
        ('hover', dict(line=(ACCENT, 0.6))),
        ('active', dict(fill=(ACCENT, 0.3), line=(ACCENT, 1))),
    ],
}

if __name__ == '__main__':
    shutil.rmtree(OUT, ignore_errors=True)
    for path, frames in FRAMES.items():
        write(path, frames)
    (OUT / 'metadata.json').write_text(json.dumps({
        'KPlugin': {'Authors': [{'Name': 'Holman Alvarado'}], 'Category': 'Plasma Theme', 'Id': 'Square', 'License': 'MIT',
                    'Name': 'Square', 'Description': 'Straight corners, the color scheme\'s colors, no blur', 'Version': '1'},
        'X-Plasma-API': '5.0'}, indent=2) + '\n')
    (OUT / 'plasmarc').write_text('[BlurBehindEffect]\nenabled=false\n\n[ContrastEffect]\nenabled=false\n\n'
                                  '[AdaptiveTransparency]\nenabled=true\n')
