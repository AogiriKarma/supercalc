#!/usr/bin/env python3
"""Glyph sheet for the shader rain.

    atlas-glyphes.py [cell=32] [columns=8]

A shader cannot draw text: it samples an image. So the katakana and a few digits are rendered
once and for all into a regular grid, white on a transparent background — the shader then tints
them however it likes.

Output: quickshell/fond/atlas.png, and the glyph count the shader has to know.
Dependencies: python-pillow, ttf-sazanami (only to regenerate the sheet).
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

cellule = int(sys.argv[1]) if len(sys.argv) > 1 else 32
colonnes = int(sys.argv[2]) if len(sys.argv) > 2 else 8

GLYPHES = ("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモ"
           "ヤユヨラリルレロワヲン0123456789")

ici = os.path.dirname(os.path.abspath(__file__))
sortie = os.path.normpath(os.path.join(ici, "..", "..", "quickshell", "fond", "atlas.png"))

police = "/usr/share/fonts/TTF/sazanami-gothic.ttf"
if not os.path.exists(police):
    sys.exit(f"font not found: {police} (package ttf-sazanami)")

lignes = (len(GLYPHES) + colonnes - 1) // colonnes
img = Image.new("RGBA", (colonnes * cellule, lignes * cellule), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
f = ImageFont.truetype(police, int(cellule * 0.88))

for i, g in enumerate(GLYPHES):
    x, y = (i % colonnes) * cellule, (i // colonnes) * cellule
    # centred in its cell: the shader assumes a perfectly regular grid
    lo = d.textbbox((0, 0), g, font=f)
    d.text((x + (cellule - (lo[2] - lo[0])) / 2 - lo[0],
            y + (cellule - (lo[3] - lo[1])) / 2 - lo[1]),
           g, font=f, fill=(255, 255, 255, 255))

img.save(sortie)
print(f"{len(GLYPHES)} glyphs in {colonnes}x{lignes} cells of {cellule} px "
       f"-> {sortie} ({os.path.getsize(sortie) / 1024:.0f} KiB)")
print(f"the shader must know: columns={colonnes} rows={lignes} count={len(GLYPHES)}")
