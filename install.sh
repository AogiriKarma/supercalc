#!/bin/sh
# Installation de SUPERCALC (sway + Quickshell) pour l'utilisateur courant.
#
#   ./install.sh            vérifie les dépendances, relie la config, installe les polices
#   ./install.sh --paquets  installe aussi les paquets manquants avec pacman (demande sudo)
#
# Rien n'est copié : ~/.config/supercalc pointe vers ce dossier, un « git pull » suffit pour
# mettre à jour. Une config sway existante est sauvegardée, jamais écrasée sans copie.
set -eu

ici="$(cd "$(dirname "$0")" && pwd)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
donnees="${XDG_DATA_HOME:-$HOME/.local/share}"

# paquets Arch (dépôt extra) : indispensables puis facultatifs
indispensables="sway quickshell foot grim slurp wl-clipboard cliphist jq libnotify xdg-utils xdg-user-dirs wireplumber"
facultatifs="swayidle brightnessctl playerctl wf-recorder wlsunset power-profiles-daemon networkmanager bluez ttf-monofur-nerd"
# Uniquement pour REGÉNÉRER les fichiers produits (fond/fond.jpg, fond/atlas.png,
# transfert/guerriers/). Ceux-ci sont versionnés, donc rien de tout ça n'est nécessaire
# pour installer ni pour faire tourner le rice — seulement pour les refabriquer.
developpement="python-numpy python-pillow python-trimesh ttf-sazanami"

titre() { printf '\n\033[1;36m== %s ==\033[0m\n' "$1"; }
ok() { printf '  \033[32mok\033[0m  %s\n' "$1"; }
note() { printf '  \033[33m..\033[0m  %s\n' "$1"; }

titre "Dépendances"
manquants=""
if command -v pacman >/dev/null; then
	for p in $indispensables $facultatifs; do
		if pacman -Q "$p" >/dev/null 2>&1; then ok "$p"; else note "$p manquant"; manquants="$manquants $p"; fi
	done
	if [ -n "$manquants" ]; then
		if [ "${1:-}" = "--paquets" ]; then
			sudo pacman -S --needed $manquants
		else
			printf '\n  Pour les installer : sudo pacman -S --needed%s\n  (ou relancer avec --paquets)\n' "$manquants"
		fi
	fi
	# Signalés à part et jamais installés d'office : ils ne servent qu'à refabriquer les
	# fichiers produits, que le dépôt contient déjà.
	devmanquants=""
	for p in $developpement; do
		pacman -Q "$p" >/dev/null 2>&1 || devmanquants="$devmanquants $p"
	done
	# un « if » et non « [ ... ] && ... » : sous set -e, une liste dont le test échoue renvoie
	# 1 et fait sortir le script, ici dès que rien ne manque.
	if [ -n "$devmanquants" ]; then
		note "pour régénérer le fond, la planche de glyphes ou les guerriers :$devmanquants"
	fi
else
	note "pacman introuvable : installe l'équivalent de ces paquets avec ton gestionnaire :"
	printf '    %s\n    %s\n' "$indispensables" "$facultatifs"
	note "et, seulement pour régénérer les fichiers produits : $developpement"
fi

titre "Liens de configuration"
mkdir -p "$config/quickshell" "$config/sway/config.d"
lier() { # $1 cible, $2 lien
	if [ -L "$2" ] || [ ! -e "$2" ]; then ln -sfn "$1" "$2"; ok "$2 → $1"
	else mv "$2" "$2.avant-supercalc"; ln -sfn "$1" "$2"; note "$2 existait : sauvegardé en $2.avant-supercalc"; fi
}
[ "$ici" = "$config/supercalc" ] || lier "$ici" "$config/supercalc"
lier "$config/supercalc/quickshell" "$config/quickshell/supercalc"

# PIEGE : Quickshell ne cherche des configs nommees dans les sous-dossiers que s'il n'y a PAS
# de shell.qml a la racine. Citation de « qs --help » :
#   « If <xdg dir>/quickshell/shell.qml exists, it will be registered as the 'default'
#     configuration, and no subdirectories will be considered. »
# Une config quickshell preexistante rend donc « qs -c supercalc » introuvable. On la range dans
# son propre sous-dossier, ou elle reste lancable avec « qs -c <nom> ».
if [ -e "$config/quickshell/shell.qml" ]; then
	nom="precedent"
	i=2
	while [ -e "$config/quickshell/$nom" ]; do nom="precedent$i"; i=$((i + 1)); done
	mkdir -p "$config/quickshell/$nom"
	for f in "$config/quickshell"/* "$config/quickshell"/.[!.]*; do
		case "$f" in
			"$config/quickshell/supercalc"|"$config/quickshell/$nom"|"$config/quickshell/*"|"$config/quickshell/.[!.]*") continue ;;
		esac
		[ -e "$f" ] || continue
		mv "$f" "$config/quickshell/$nom/"
	done
	note "config quickshell existante deplacee dans $nom/ (relancable avec « qs -c $nom »)"
	note "si sa config sway lance « qs » tout court, corrige-la en « qs -c $nom »"
fi

# la config sway principale se contente d'inclure celle de supercalc
if ! grep -qs 'supercalc/sway/config' "$config/sway/config"; then
	[ -e "$config/sway/config" ] && mv "$config/sway/config" "$config/sway/config.avant-supercalc" && note "ancienne config sway sauvegardée en config.avant-supercalc"
	printf '# Config sway : tout vient de SUPERCALC.\n# Tes réglages personnels (écrans, clavier, applis au démarrage) vont dans config.d/.\ninclude ~/.config/supercalc/sway/config\n' > "$config/sway/config"
	ok "$config/sway/config"
fi
# profil de raccourcis : le lien désigne celui qui est actif, la config sway l'inclut
if [ ! -e "$config/sway/raccourcis-actif.conf" ]; then
	ln -sfn "$config/supercalc/sway/raccourcis/supercalc.conf" "$config/sway/raccourcis-actif.conf"
	ok "profil de raccourcis « supercalc » (changer avec scripts/raccourcis)"
fi

if [ ! -e "$config/sway/config.d/local.conf" ]; then
	cp "$ici/sway/exemple-local.conf" "$config/sway/config.d/local.conf"
	ok "config.d/local.conf créé (clavier, écrans : à adapter)"
fi

titre "Polices"
mkdir -p "$donnees/fonts/supercalc"
cp "$ici"/quickshell/polices/*.ttf "$donnees/fonts/supercalc/"
fc-cache -f "$donnees/fonts/supercalc" >/dev/null 2>&1 || true
ok "Gunship (3 styles) et Share Tech Mono dans $donnees/fonts/supercalc"
fc-list | grep -qi "Monofur Nerd Font" && ok "Monofur Nerd Font (terminal)" || note "Monofur Nerd Font absente : paquet ttf-monofur-nerd (le terminal se rabat sur Share Tech Mono)"

titre "Terminé"
if [ -n "${SWAYSOCK:-}" ]; then
	swaymsg reload >/dev/null && ok "sway rechargé"
	pgrep -x quickshell >/dev/null || (setsid qs -c supercalc >/dev/null 2>&1 &)
else
	printf '  Lance sway depuis un TTY (commande « sway ») : le bureau démarre avec la séquence de transfert.\n'
fi
printf '  Aide : super + F1 · réglages : super + ,\n'
