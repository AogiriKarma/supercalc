import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.composants
import qs.services

// The transfer sequence played when the session opens: identity card, scanner (a real 3D model as
// a wireframe), virtualisation, arrival in sector 1. Escape or a click skips it.
// Played once per session (a flag in $XDG_RUNTIME_DIR), replayable from the settings.
Scope {
	id: racine

	readonly property bool actif: Etat.panneau === "transfert"
	readonly property int duree: 8000
	property real t: 0

	// --- a Lyoko warrior drawn at random on each play ---
	readonly property var saisons: ["s1", "s4"]
	readonly property var guerriers: ["yumi", "odd", "aelita", "ulrich", "william"]
	property string modele: "s4/yumi"
	property string forceModele: ""      // for testing: qs ipc call transfert guerrier s1/odd
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

	// ---------------- automatic start, once per session ----------------
	Process {
		id: temoin
		command: ["sh", "-c", 'f="${XDG_RUNTIME_DIR:-/tmp}/supercalc-transfert"; [ -e "$f" ] && exit 1; : > "$f"']
		onExited: code => { if (code === 0 && Reglages.sequenceTransfert) Etat.ouvrir("transfert", Etat.ecranPrincipalObjet); }
	}
	// gives the settings time to be read from disk
	Timer { interval: 400; running: true; onTriggered: temoin.running = true }

	IpcHandler {
		target: "transfert"
		function jouer(): void { Etat.ouvrir("transfert", Etat.ecranPrincipalObjet); }
		function figer(ms: real): void { racine.figer(ms); }
		// forces a particular warrior, `season/name` (for testing)
		function guerrier(nom: string): void {
			racine.forceModele = nom;
			Etat.ouvrir("transfert", Etat.ecranPrincipalObjet);
		}
	}

	// ---------------- layers, built on first play ----------------
	// A LazyLoader rather than a direct instantiation: the scene is only used for eight seconds per
	// session, so there is no point keeping it in memory the rest of the time. It is destroyed as
	// soon as the sequence ends.
	LazyLoader {
		active: racine.actif
		component: Component {
			Calques { hote: racine }
		}
	}
}
