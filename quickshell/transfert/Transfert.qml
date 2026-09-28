import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.composants
import qs.services

// Séquence de transfert à l'ouverture de session : carte d'identité, scanner (modèle 3D réel
// en fil de fer), virtualisation, arrivée au secteur 1. Échap ou clic pour passer.
// Jouée une fois par session (témoin dans $XDG_RUNTIME_DIR), rejouable depuis les réglages.
Scope {
	id: racine

	readonly property bool actif: Etat.panneau === "transfert"
	readonly property int duree: 8000
	property real t: 0

	// --- guerrier de Lyoko tiré au sort à chaque lecture ---
	readonly property var saisons: ["s1", "s4"]
	readonly property var guerriers: ["yumi", "odd", "aelita", "ulrich", "william"]
	property string modele: "s4/yumi"
	property string forceModele: ""      // essais : qs ipc call transfert guerrier s1/odd
	function tirer() {
		if (forceModele !== "") { modele = forceModele; forceModele = ""; return; }
		modele = saisons[Math.floor(Math.random() * saisons.length)] + "/"
		       + guerriers[Math.floor(Math.random() * guerriers.length)];
	}

	NumberAnimation {
		id: horloge
		target: racine; property: "t"
		from: 0; to: racine.duree; duration: racine.duree
		onFinished: if (racine.actif) Etat.fermer()
	}
	onActifChanged: {
		if (actif) { tirer(); t = 0; horloge.restart(); }
		else horloge.stop();
	}
	function passer() { horloge.stop(); Etat.fermer(); }
	function figer(ms) { Etat.ouvrir("transfert"); horloge.stop(); t = ms; }

	// ---------------- lancement automatique, une fois par session ----------------
	Process {
		id: temoin
		command: ["sh", "-c", 'f="${XDG_RUNTIME_DIR:-/tmp}/supercalc-transfert"; [ -e "$f" ] && exit 1; : > "$f"']
		onExited: code => { if (code === 0 && Reglages.sequenceTransfert) Etat.ouvrir("transfert", Etat.ecranPrincipalObjet); }
	}
	// laisse le temps aux réglages d'être lus depuis le disque
	Timer { interval: 400; running: true; onTriggered: temoin.running = true }

	IpcHandler {
		target: "transfert"
		function jouer(): void { Etat.ouvrir("transfert", Etat.ecranPrincipalObjet); }
		function figer(ms: real): void { racine.figer(ms); }
		// force un guerrier précis, « saison/nom » (essais)
		function guerrier(nom: string): void {
			racine.forceModele = nom;
			Etat.ouvrir("transfert", Etat.ecranPrincipalObjet);
		}
	}

	// ---------------- calques, construits à la première lecture ----------------
	// LazyLoader plutôt qu'une instanciation directe : la scène ne sert que huit secondes
	// par session, inutile de la garder en mémoire le reste du temps. Elle est détruite
	// dès que la séquence se termine.
	LazyLoader {
		active: racine.actif
		component: Component {
			Calques { hote: racine }
		}
	}
}
