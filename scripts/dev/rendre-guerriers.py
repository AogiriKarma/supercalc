#!/usr/bin/env python3
"""Render the Lyoko warriors as wireframes (transparent PNGs) for the transfer sequence.

Models: "Code Lyoko Warriors Season 1" and "Season 4" by jackzerobear159, CC-BY 4.0
(https://skfb.ly/pLTOx and https://skfb.ly/pLTOt).

The file holds the five warriors side by side, each as two meshes (body and head), with no usable
names: the nodes are hashes produced by Tripo. They are therefore grouped by position, left to
right — the same arrangement in both seasons.

usage: rendre-guerriers.py <source.glb> <season> [faces=1400] [frames=36] [width=520] [height=600]
  faces=0 disables decimation (the wireframe then saturates into a solid silhouette).

Output: quickshell/transfert/modele/<season>/<warrior>/corps-NN.png, tete.png, main.png
Dependencies: python-trimesh, python-numpy, python-pillow, python-fast-simplification.
"""
import sys, math, os
import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFilter

# The two files do not lay the warriors out the same way: season 4 aligns them along X, season 1
# stacks them along Z and in the reverse order. So they are grouped along whichever axis spreads
# them most, then each group is named by the hash of its head — Tripo reuses the same head mesh
# from one season to the next, except for Yumi, whose hair changes.
TETES = {
    "a30945d0": "yumi",     # season 4
    "2e90868f": "yumi",     # season 1
    "7cae8b98": "odd",
    "d3f93c32": "aelita",
    "4af6dfe1": "ulrich",
    "c1cfb65b": "william",
}
GUERRIERS = ["yumi", "odd", "aelita", "ulrich", "william"]

# Camera angle for the close-up of the hand. At 0 rad it is seen edge-on, arm hanging down: the
# camera has to turn to catch it three-quarters on, with the thumb visible.
ANGLE_MAIN = 2.40

# density of the hand close-up, independent of the body's (a frame 20 times smaller)
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
    """Geometry put back in place by its node's transform in the scene graph."""
    geo = scene.geometry[nom].copy()
    noeud = next(k for k in scene.graph.nodes_geometry if scene.graph[k][1] == nom)
    geo.apply_transform(scene.graph[noeud][0])
    return geo


# --- grouping by warrior ---
pieces = []
for nom in scene.geometry:
    m = au_monde(nom)
    pieces.append((nom, m, m.vertices.mean(axis=0)))

# separating axis = the one that spreads the centroids most (X in season 4, Z in season 1)
etendues = [max(p[2][a] for p in pieces) - min(p[2][a] for p in pieces) for a in range(3)]
axe = int(np.argmax(etendues))

pieces.sort(key=lambda p: p[2][axe])
seuil = etendues[axe] / (len(GUERRIERS) * 2)   # a larger gap separates two warriors
groupes, courant, precedent = [], [], None
for nom, m, c in pieces:
    if precedent is not None and c[axe] - precedent > seuil:
        groupes.append(courant)
        courant = []
    courant.append((nom, m))
    precedent = c[axe]
groupes.append(courant)

if len(groupes) != len(GUERRIERS):
    sys.exit(f"{len(groupes)} groups found for {len(GUERRIERS)} warriors along axis "
             f"{'XYZ'[axe]}: unexpected layout, check the source file.")

# named by the hash of the head found in the group
nommes = {}
for groupe in groupes:
    trouves = {n for nom, _ in groupe for h, n in TETES.items() if h in nom}
    if len(trouves) != 1:
        sys.exit(f"unidentified group ({', '.join(nom for nom, _ in groupe)}): "
                 f"heads recognised = {trouves or 'none'}")
    nommes[trouves.pop()] = [m for _, m in groupe]

manquants = set(GUERRIERS) - set(nommes)
if manquants:
    sys.exit(f"warriors not found: {', '.join(sorted(manquants))}")
print(f"  (separated along axis {'XYZ'[axe]})")


def sous_maillage(sommets, faces, centre, rayon):
    """Faces whose three vertices all fit in the box: isolates a limb from the rest of the body.

    Zooming alone is not enough: it frames the view but leaves the torso and the legs projecting
    behind the hand, which becomes unreadable as soon as the camera turns.
    """
    dans = np.all(np.abs(sommets - centre) < rayon, axis=1)
    return faces[np.all(dans[faces], axis=1)]


def rendre(maillages, centre, hauteur, largeur, hauteur_img, angle, zoom=1.0, cible=None, epaisseur=1):
    """Same rendering as rendre-modele.py: green edges, alpha by depth, halo."""
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

    # Orientation: a human body is wider shoulder to shoulder than front to back. The widest
    # horizontal axis is therefore the shoulder axis, and the front view looks perpendicular to it.
    # In season 1 the warriors face along X, so a quarter turn puts view 0 at the front — and, more
    # importantly, keeps the hand as the extremity along X.
    lo, hi = corps.vertices.min(axis=0), corps.vertices.max(axis=0)
    if (hi[2] - lo[2]) > (hi[0] - lo[0]):
        corps.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, [0, 1, 0]))

    # common scaling: height 1.5 like CesiumMan, so the original perspective and framing
    # constants stay valid
    lo, hi = corps.vertices.min(axis=0), corps.vertices.max(axis=0)
    corps.apply_translation(-(lo + hi) / 2)
    corps.apply_scale(1.5 / (hi[1] - lo[1]))

    brut = len(corps.faces)
    plein = corps.copy()          # close-ups are isolated from the full mesh
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

    # --- close-ups: head and right hand ---
    # The warriors stand with their arms down: the model is about 0.57 wide for 1.5 tall. The
    # largest x is therefore reached by the hand, at hip height, and falls back at the shoulders
    # as at the legs. A wide threshold would catch the whole flank, hence these narrow bands and
    # tight zooms (CesiumMan, arms spread, tolerated 0.2 and 2.4).
    haut = corps.vertices[corps.vertices[:, 1] > hi[1] - 0.30]
    tete_c = haut.mean(axis=0) if len(haut) else centre
    rendre(maillages, centre, hauteur, 180, 180, 0.5, zoom=4.2, cible=tete_c).save(f"{sortie}/tete.png", optimize=True)

    # Isolate from the full mesh, then decimate the hand alone: the other way round gives either a
    # hand in shards (global decimation leaves almost nothing on a thin limb) or a solid blob
    # (5,000 faces crammed into 180 px). FACES_MAIN sets the density of the close-up.
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
          f"{len(corps.edges_unique):>5} edges, {n} views + head + hand, {poids / 1024:.0f} KB")
