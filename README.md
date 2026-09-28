# SUPERCALC

Bureau sway + Quickshell inspiré du supercalculateur de *Code Lyoko* et d'IFSCL : fenêtres à coins
biseautés, secteurs à la place des espaces de travail, témoin XANA, scanner d'identification au
verrouillage et séquence de transfert à l'ouverture de session. Un vrai bureau de tous les jours :
tout s'adapte aux écrans branchés (taille, nombre, échelle, orientation) et se règle en direct.

Testé avec les versions d'Arch Linux du 28 septembre 2026 : sway 1.12 (wlroots 0.20.2),
Quickshell 0.3.1, Qt 6.11.2, foot 1.28.0.

## Installation

```sh
# copie (ou clone) ce dossier dans ~/.config/supercalc, puis :
~/.config/supercalc/install.sh --paquets
```

Le script vérifie les paquets (et les installe avec `--paquets`), relie `~/.config/quickshell/supercalc`,
installe les polices et remplace `~/.config/sway/config` par une ligne `include` (l'ancienne est
sauvegardée en `config.avant-supercalc`). Tes réglages de machine vont dans
`~/.config/sway/config.d/local.conf` (clavier, écrans, applis au démarrage), jamais touché ensuite.

Paquets (dépôt *extra*) :

| rôle | paquets |
|---|---|
| indispensables | `sway quickshell foot grim slurp wl-clipboard cliphist jq libnotify xdg-utils xdg-user-dirs wireplumber` |
| selon le matériel | `brightnessctl` (rétroéclairage), `power-profiles-daemon` (profils d'énergie), `networkmanager` (wifi), `bluez` (bluetooth) |
| confort | `swayidle` (veille auto), `wlsunset` (lumière nuit), `playerctl` (touches média), `wf-recorder` (vidéo d'écran), `ttf-monofur-nerd` (police du terminal) |

Chaque tuile du panneau de contrôle se grise simplement si son service manque.

## Utilisation

`super + F1` affiche le manuel, construit à partir de `sway/raccourcis.conf` (toujours à jour).
Les essentiels :

| | |
|---|---|
| `super + D` | recherche : applis, fenêtres, fichiers, commandes · préfixes `=` calcul, `>` shell, `/` fichiers, `?` web |
| `super + Tab` | holomap : tous les secteurs de tous les écrans ; glisser une fenêtre pour la déplacer |
| `super + N` | panneau de contrôle (wifi, bluetooth, son, luminosité, énergie, média, journal) |
| `super + V` | presse-papiers (épingles avec ctrl + P) |
| `super + ,` | réglages |
| `super + Échap` | verrouiller · `super + Maj + E` menu d'énergie |
| `Impr` / `super + Impr` | capture de zone / d'écran · `super + Maj + Impr` vidéo |
| `super + 1…9` | secteurs (touches physiques : identique en AZERTY et QWERTY) |

## Organisation

```
sway/          config, thème des fenêtres, raccourcis (documentés), règles, démarrage
quickshell/    le bureau : barre, dock, lanceur, holomap, panneaux, verrouillage, transfert…
  services/    état partagé (sway, système, notifications, réglages, applis…)
  composants/  cadre IFSCL, pastilles, icônes, jauges
foot/          thème du terminal
fond/          fond d'écran (généré par scripts/generer-fond.py)
scripts/       capture, pipette, veille, nuit ; dev/ pour régénérer les images
```

Les réglages sont écrits dans `~/.local/state/quickshell/by-shell/<id>/reglages.json` et relus à chaud.
La séquence de transfert se joue une fois par session ; elle se désactive ou se rejoue dans
Réglages → Session, ou avec `qs -c supercalc ipc call transfert jouer`.

## Crédits

- Polices : *Gunship* © Iconian Fonts (Daniel Zadorozny), gratuite pour un usage non commercial
  (`quickshell/polices/gunship.txt`) ; *Share Tech Mono* © Carrois Apostrophe, licence OFL.
- Modèle du scanner : *CesiumMan* © Cesium, CC-BY 4.0 (Khronos glTF Sample Assets), tête remplacée.
- *Code Lyoko* est une marque de ses ayants droit ; ce projet est une création de fan non officielle.
