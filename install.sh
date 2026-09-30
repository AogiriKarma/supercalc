#!/bin/sh
# Install SUPERCALC (sway + Quickshell) for the current user.
#
#   ./install.sh            check dependencies, link the config, install the fonts
#   ./install.sh --paquets  also install missing packages with pacman (asks for sudo)
#
# Nothing is copied: ~/.config/supercalc points at this directory, so a `git pull` is enough to
# update. An existing sway config is backed up, never overwritten without a copy.
set -eu

ici="$(cd "$(dirname "$0")" && pwd)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
donnees="${XDG_DATA_HOME:-$HOME/.local/share}"

# Arch packages (extra repository): required first, then optional
indispensables="sway quickshell foot grim slurp wl-clipboard cliphist jq libnotify xdg-utils xdg-user-dirs wireplumber"
facultatifs="swayidle brightnessctl playerctl wf-recorder wlsunset power-profiles-daemon networkmanager bluez ttf-monofur-nerd"
# Only needed to REGENERATE the generated files (fond/fond.jpg, fond/atlas.png,
# transfert/guerriers/). Those are committed, so none of this is required to install or to run
# the rice — only to rebuild them.
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
	# Reported separately and never installed by default: they only serve to rebuild the
	# generated files, which the repository already contains.
	devmanquants=""
	for p in $developpement; do
		pacman -Q "$p" >/dev/null 2>&1 || devmanquants="$devmanquants $p"
	done
	# An `if` rather than `[ ... ] && ...`: under set -e, a list whose test fails returns 1 and
	# exits the script — here as soon as nothing is missing.
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
lier() { # $1 target, $2 link
	if [ -L "$2" ] || [ ! -e "$2" ]; then ln -sfn "$1" "$2"; ok "$2 → $1"
	else mv "$2" "$2.avant-supercalc"; ln -sfn "$1" "$2"; note "$2 existait : sauvegardé en $2.avant-supercalc"; fi
}
[ "$ici" = "$config/supercalc" ] || lier "$ici" "$config/supercalc"
lier "$config/supercalc/quickshell" "$config/quickshell/supercalc"

# TRAP: Quickshell only looks for named configs in subdirectories when there is NO shell.qml at
# the root. Quoting `qs --help`:
#   "If <xdg dir>/quickshell/shell.qml exists, it will be registered as the 'default'
#    configuration, and no subdirectories will be considered."
# A pre-existing quickshell config therefore makes `qs -c supercalc` impossible to find. We move
# it into a subdirectory of its own, where it stays runnable with `qs -c <name>`.
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

# the main sway config does nothing but include supercalc's
if ! grep -qs 'supercalc/sway/config' "$config/sway/config"; then
	[ -e "$config/sway/config" ] && mv "$config/sway/config" "$config/sway/config.avant-supercalc" && note "ancienne config sway sauvegardée en config.avant-supercalc"
	printf '# sway config: everything comes from SUPERCALC.\n# Your own settings (screens, keyboard, startup applications) go in config.d/.\ninclude ~/.config/supercalc/sway/config\n' > "$config/sway/config"
	ok "$config/sway/config"
fi
# shortcut profile: the symlink names the active one, and the sway config includes it
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
