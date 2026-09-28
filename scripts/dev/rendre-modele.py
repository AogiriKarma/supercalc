#!/usr/bin/env python3
"""Rend le modèle 3D du scanner en fil de fer (images PNG transparentes) pour la séquence de transfert.

Modèle : CesiumMan (Cesium, CC-BY 4.0, dépôt glTF-Sample-Assets). La tête d'origine est remplacée
par une icosphère et la collerette coupée, comme dans les maquettes.
usage : rendre-modele.py CesiumMan.glb dossier-sortie [images=36] [largeur=520] [hauteur=600]
Dépendances : python-trimesh, python-numpy, python-pillow (uniquement pour régénérer les images).
"""
import sys, math, os
import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFilter

src, sortie = sys.argv[1], sys.argv[2]
n = int(sys.argv[3]) if len(sys.argv) > 3 else 36
L = int(sys.argv[4]) if len(sys.argv) > 4 else 520
H = int(sys.argv[5]) if len(sys.argv) > 5 else 600
os.makedirs(sortie, exist_ok=True)

scene = trimesh.load(src)
corps = scene.to_geometry() if hasattr(scene, "to_geometry") else scene.dump(concatenate=True)
COUPE = 1.165
garde = corps.vertices[corps.faces].max(axis=1)[:, 1] < COUPE
corps = trimesh.Trimesh(corps.vertices, corps.faces[garde], process=True)
cou = corps.vertices[corps.vertices[:, 1] > COUPE - 0.06]
centre_cou = cou.mean(axis=0) if len(cou) else np.array([0, COUPE, 0])
tete = trimesh.creation.icosphere(subdivisions=2, radius=0.115)
tete.apply_scale([0.9, 1.12, 1.0])
tete.apply_translation([centre_cou[0], COUPE + 0.115, centre_cou[2] + 0.005])

def aretes(m):
    e = m.edges_unique
    return m.vertices, e

maillages = [aretes(corps), aretes(tete)]
bmin = np.min([v.min(axis=0) for v, _ in maillages], axis=0)
bmax = np.max([v.max(axis=0) for v, _ in maillages], axis=0)
centre = (bmin + bmax) / 2
hauteur = bmax[1] - bmin[1]

def rendre(angle, largeur, hauteur_img, zoom=1.0, cible=None, epaisseur=1):
    img = Image.new("RGBA", (largeur * 2, hauteur_img * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ca, sa = math.cos(angle), math.sin(angle)
    ctr = centre if cible is None else cible
    echelle = (hauteur_img * 2) * 0.86 / hauteur * zoom
    for v, e in maillages:
        p = v - ctr
        x = p[:, 0] * ca + p[:, 2] * sa
        z = -p[:, 0] * sa + p[:, 2] * ca
        y = p[:, 1]
        persp = 3.2 / (3.2 - z)
        X = largeur + x * echelle * persp
        Y = hauteur_img - y * echelle * persp
        prof = (z - z.min()) / max(1e-6, z.max() - z.min())
        for a, b in e:
            t = (prof[a] + prof[b]) / 2
            alpha = int(70 + 160 * t)
            d.line([(X[a], Y[a]), (X[b], Y[b])], fill=(63, 224, 122, alpha), width=epaisseur * 2)
    img = img.resize((largeur, hauteur_img), Image.LANCZOS)
    halo = img.filter(ImageFilter.GaussianBlur(6))
    fond = Image.new("RGBA", img.size, (0, 0, 0, 0))
    fond.alpha_composite(halo)
    fond.alpha_composite(halo)
    fond.alpha_composite(img)
    return fond

for i in range(n):
    a = 2 * math.pi * i / n
    # palette de 96 couleurs avec transparence : bien plus léger, invisible sur ce motif
    rendre(a, L, H).quantize(96, method=Image.Quantize.FASTOCTREE).save(f"{sortie}/corps-{i:02d}.png", optimize=True)
# détails : tête et main droite
tete_c = np.array([centre_cou[0], COUPE + 0.1, centre_cou[2]])
rendre(0.5, 180, 180, zoom=4.2, cible=tete_c).save(f"{sortie}/tete.png", optimize=True)
bout = corps.vertices[:, 0].max()
main = corps.vertices[corps.vertices[:, 0] > bout - 0.2].mean(axis=0)
rendre(0.0, 180, 180, zoom=2.4, cible=main).save(f"{sortie}/main.png", optimize=True)
print(f"{n} vues + tête + main dans {sortie}")
