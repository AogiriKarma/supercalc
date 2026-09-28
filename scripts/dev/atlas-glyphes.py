#!/usr/bin/env python3
"""Planche de glyphes pour la pluie en shader.

    atlas-glyphes.py [cellule=32] [colonnes=8]

Un shader ne sait pas dessiner du texte : il échantillonne une image. On rend donc une
fois pour toutes les katakana et quelques chiffres dans une grille régulière, en blanc sur
fond transparent — le shader les teinte ensuite comme il veut.

Sortie : quickshell/fond/atlas.png, et le nombre de glyphes que le shader doit connaître.
Dépendances : python-pillow, ttf-sazanami (seulement pour régénérer la planche).
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
    sys.exit(f"police introuvable : {police} (paquet ttf-sazanami)")

lignes = (len(GLYPHES) + colonnes - 1) // colonnes
img = Image.new("RGBA", (colonnes * cellule, lignes * cellule), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
f = ImageFont.truetype(police, int(cellule * 0.88))

for i, g in enumerate(GLYPHES):
    x, y = (i % colonnes) * cellule, (i // colonnes) * cellule
    # centré dans sa cellule : le shader suppose une grille parfaitement régulière
    lo = d.textbbox((0, 0), g, font=f)
    d.text((x + (cellule - (lo[2] - lo[0])) / 2 - lo[0],
            y + (cellule - (lo[3] - lo[1])) / 2 - lo[1]),
           g, font=f, fill=(255, 255, 255, 255))

img.save(sortie)
print(f"{len(GLYPHES)} glyphes en {colonnes}x{lignes} cellules de {cellule} px "
       f"-> {sortie} ({os.path.getsize(sortie) / 1024:.0f} Kio)")
print(f"le shader doit connaître : colonnes={colonnes} lignes={lignes} nombre={len(GLYPHES)}")
