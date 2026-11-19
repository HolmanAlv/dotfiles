#!/usr/bin/env python3
"""make-fonts.py DIR: writes the Neon copies of M PLUS 1 and DotGothic16 next to the originals in DIR.

M PLUS 1 asks for 1.448 lines where Inter and Moralerspace ask for 1.2, and sits low in them. Plasma sizes its
panels, menus and rows from the font's line height, so with it everything grew 25 % around text of the same size.
Only the vertical metrics change, and the families get their own names, as these are modified fonts (SIL OFL).
"""
import os, re, sys
from fontTools.ttLib import TTFont

# file, family, its name without spaces, new name's suffix for files, ascent, descent
FONTS = (
    ('MPLUS1[wght].ttf', 'M PLUS 1', 'MPLUS1', 'MPLUS1Neon[wght].ttf', 950, -250),  # the same 1.2 as Moralerspace Neon
    ('DotGothic16-Regular.ttf', 'DotGothic16', 'DotGothic16', 'DotGothic16Neon-Regular.ttf', 875, -125),  # at 16 px, exactly 16 px
)


def neon(path, family, compact, target, ascent, descent):
    font = TTFont(path)
    hhea, os2 = font['hhea'], font['OS/2']
    hhea.ascent, hhea.descent, hhea.lineGap = ascent, descent, 0
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = ascent, descent, 0
    os2.usWinAscent, os2.usWinDescent = ascent, -descent
    os2.fsSelection |= 1 << 7  # USE_TYPO_METRICS
    for record in font['name'].names:
        if record.nameID in (1, 3, 4, 6, 16, 18, 21, 25):
            text = record.toUnicode().replace(family, f'{family} Neon')
            record.string = re.sub(rf'^{compact}(?= Neon)?', f'{compact}Neon', text) if record.nameID in (6, 25) else text
    font.save(target)


if __name__ == '__main__':
    root = sys.argv[1]
    for file, family, compact, new, ascent, descent in FONTS:
        neon(os.path.join(root, file), family, compact, os.path.join(root, new), ascent, descent)
        check = TTFont(os.path.join(root, new))
        assert check['hhea'].ascent == ascent and check['hhea'].descent == descent
        assert any(f'{family} Neon' in r.toUnicode() for r in check['name'].names if r.nameID in (1, 16))
