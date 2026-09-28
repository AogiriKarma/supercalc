#!/usr/bin/env python3
"""Rend les guerriers de Lyoko en fil de fer (PNG transparents) pour la séquence de transfert.

Modèles : « Code Lyoko Warriors Season 1 » et « Season 4 » de jackzerobear159, CC-BY 4.0
(https://skfb.ly/pLTOx et https://skfb.ly/pLTOt).

Le fichier contient les cinq guerriers côte à côte, chacun en deux maillages (corps et tête),
sans nom exploitable : les nœuds sont des hachages produits par Tripo. On les regroupe donc
par position en X, de gauche à droite — même disposition dans les deux saisons.

usage : rendre-guerriers.py <source.glb> <saison> [faces=1400] [images=36] [largeur=520] [hauteur=600]
  faces=0 désactive la décimation (le fil de fer sature alors et devient une silhouette pleine).

Sortie : quickshell/transfert/modele/<saison>/<guerrier>/corps-NN.png, tete.png, main.png
Dépendances : python-trimesh, python-numpy, python-pillow, python-fast-simplification.
"""
import sys, math, os
import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFilter

# Les deux fichiers ne rangent pas les guerriers pareil : la saison 4 les aligne sur X, la
# saison 1 les empile sur Z et dans l'ordre inverse. On regroupe donc sur l'axe de plus grande
# dispersion, puis on nomme chaque groupe par le hachage de sa tête — Tripo réutilise le même
# maillage de tête d'une saison à l'autre, sauf pour Yumi qui change de coiffure.
TETES = {
    "a30945d0": "yumi",     # saison 4
    "2e90868f": "yumi",     # saison 1
    "7cae8b98": "odd",
    "d3f93c32": "aelita",
    "4af6dfe1": "ulrich",
    "c1cfb65b": "william",
}
GUERRIERS = ["yumi", "odd", "aelita", "ulrich", "william"]

# Angle de la caméra pour le gros plan de la main. À 0 rad on la voit par la tranche, bras
# pendant : il faut tourner pour la prendre de trois quarts, pouce visible.
ANGLE_MAIN = 2.40

# densité du gros plan de main, indépendante de celle du corps (cadre 20 fois plus petit)
FACES_MAIN = 500

src = sys.argv[1]
saison = sys.argv[2]
faces = int(sys.argv[3]) if len(sys.argv) > 3 else 1400
n = int(sys.argv[4]) if len(sys.argv) > 4 else 36
L = int(sys.argv[5]) if len(sys.argv) > 5 else 520
H = int(sys.argv[6]) if len(sys.argv) > 6 else 600

racine = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "quickshell")
base = os.path.normpath(os.path.join(racine, "transfert", "modele", saison))

scene = trimesh.load(src)


def au_monde(nom):
    """Géométrie replacée par la transformation de son nœud dans le graphe de scène."""
    geo = scene.geometry[nom].copy()
    noeud = next(k for k in scene.graph.nodes_geometry if scene.graph[k][1] == nom)
    geo.apply_transform(scene.graph[noeud][0])
    return geo


# --- regroupement par guerrier ---
pieces = []
for nom in scene.geometry:
    m = au_monde(nom)
    pieces.append((nom, m, m.vertices.mean(axis=0)))

# axe de séparation = celui qui disperse le plus les centroïdes (X en saison 4, Z en saison 1)
etendues = [max(p[2][a] for p in pieces) - min(p[2][a] for p in pieces) for a in range(3)]
axe = int(np.argmax(etendues))

pieces.sort(key=lambda p: p[2][axe])
seuil = etendues[axe] / (len(GUERRIERS) * 2)   # un écart plus grand sépare deux guerriers
groupes, courant, precedent = [], [], None
for nom, m, c in pieces:
    if precedent is not None and c[axe] - precedent > seuil:
        groupes.append(courant)
        courant = []
    courant.append((nom, m))
    precedent = c[axe]
groupes.append(courant)

if len(groupes) != len(GUERRIERS):
    sys.exit(f"{len(groupes)} groupes trouvés pour {len(GUERRIERS)} guerriers sur l'axe "
             f"{'XYZ'[axe]} : disposition inattendue, vérifie le fichier source.")

# nommage par le hachage de la tête présente dans le groupe
nommes = {}
for groupe in groupes:
    trouves = {n for nom, _ in groupe for h, n in TETES.items() if h in nom}
    if len(trouves) != 1:
        sys.exit(f"groupe non identifié ({', '.join(nom for nom, _ in groupe)}) : "
                 f"têtes reconnues = {trouves or 'aucune'}")
    nommes[trouves.pop()] = [m for _, m in groupe]

manquants = set(GUERRIERS) - set(nommes)
if manquants:
    sys.exit(f"guerriers non trouvés : {', '.join(sorted(manquants))}")
print(f"  (séparation sur l'axe {'XYZ'[axe]})")


def sous_maillage(sommets, faces, centre, rayon):
    """Faces dont les trois sommets tiennent dans la boîte : isole un membre du reste du corps.

    Un simple zoom ne suffit pas : il cadre la vue mais laisse le torse et les jambes se
    projeter derrière la main, qui devient illisible dès qu'on tourne la caméra.
    """
    dans = np.all(np.abs(sommets - centre) < rayon, axis=1)
    return faces[np.all(dans[faces], axis=1)]


def rendre(maillages, centre, hauteur, largeur, hauteur_img, angle, zoom=1.0, cible=None, epaisseur=1):
    """Même rendu que rendre-modele.py : arêtes vertes, alpha selon la profondeur, halo."""
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


for nom in GUERRIERS:
    corps = trimesh.util.concatenate(nommes[nom])

    # Orientation : un corps humain est plus large d'épaule en épaule que d'avant en arrière.
    # L'axe horizontal le plus étendu est donc l'axe des épaules, et la vue de face regarde
    # perpendiculairement. En saison 1 les guerriers font face à X : on pivote d'un quart de
    # tour pour que la vue 0 soit de face, et surtout pour que la main reste l'extrémité en X.
    lo, hi = corps.vertices.min(axis=0), corps.vertices.max(axis=0)
    if (hi[2] - lo[2]) > (hi[0] - lo[0]):
        corps.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, [0, 1, 0]))

    # mise à l'échelle commune : hauteur 1.5 comme CesiumMan, pour que les constantes
    # de perspective et de cadrage d'origine restent valables
    lo, hi = corps.vertices.min(axis=0), corps.vertices.max(axis=0)
    corps.apply_translation(-(lo + hi) / 2)
    corps.apply_scale(1.5 / (hi[1] - lo[1]))

    brut = len(corps.faces)
    plein = corps.copy()          # les gros plans s'isolent dans le maillage complet
    if faces:
        corps = corps.simplify_quadric_decimation(face_count=faces)

    maillages = [(corps.vertices, corps.edges_unique)]
    lo, hi = corps.vertices.min(axis=0), corps.vertices.max(axis=0)
    centre = (lo + hi) / 2
    hauteur = hi[1] - lo[1]

    sortie = os.path.join(base, nom)
    os.makedirs(sortie, exist_ok=True)
    for i in range(n):
        a = 2 * math.pi * i / n
        img = rendre(maillages, centre, hauteur, L, H, a)
        img.quantize(96, method=Image.Quantize.FASTOCTREE).save(f"{sortie}/corps-{i:02d}.png", optimize=True)

    # --- gros plans : tête et main droite ---
    # Les guerriers sont debout, bras le long du corps : le modèle fait environ 0.57 de large
    # pour 1.5 de haut. Le x maximal est donc atteint par la main, à hauteur de hanche, et
    # retombe aux épaules comme aux jambes. Un seuil large attraperait tout le flanc, d'où
    # ces bandes étroites et ces zooms serrés (CesiumMan, bras écartés, tolérait 0.2 et 2.4).
    haut = corps.vertices[corps.vertices[:, 1] > hi[1] - 0.30]
    tete_c = haut.mean(axis=0) if len(haut) else centre
    rendre(maillages, centre, hauteur, 180, 180, 0.5, zoom=4.2, cible=tete_c).save(f"{sortie}/tete.png", optimize=True)

    # Isoler dans le maillage complet puis décimer la main seule : l'inverse donne soit une
    # main en miettes (la décimation globale ne laisse presque rien sur un membre fin), soit
    # une tache pleine (5 000 faces serrées dans 180 px). FACES_MAIN fixe la densité du gros plan.
    pv, pf = plein.vertices, plein.faces
    phi = pv.max(axis=0)
    main = pv[pv[:, 0] > phi[0] - 0.01].mean(axis=0)
    fm = sous_maillage(pv, pf, main, np.array([0.11, 0.11, 0.11]))
    if len(fm) > FACES_MAIN:
        mm = trimesh.Trimesh(pv, fm, process=True).simplify_quadric_decimation(face_count=FACES_MAIN)
        mlo, mhi = mm.vertices.min(axis=0), mm.vertices.max(axis=0)
        rendre([(mm.vertices, mm.edges_unique)], (mlo + mhi) / 2, max(mhi[1] - mlo[1], 1e-3),
               180, 180, ANGLE_MAIN, zoom=0.93).save(f"{sortie}/main.png", optimize=True)
    else:
        rendre(maillages, centre, hauteur, 180, 180, ANGLE_MAIN, zoom=8.0, cible=main).save(f"{sortie}/main.png", optimize=True)

    poids = sum(os.path.getsize(os.path.join(sortie, f)) for f in os.listdir(sortie))
    print(f"  {saison}/{nom:<8} {brut:>7} -> {len(corps.faces):>5} faces, "
          f"{len(corps.edges_unique):>5} arêtes, {n} vues + tête + main, {poids / 1024:.0f} Ko")
