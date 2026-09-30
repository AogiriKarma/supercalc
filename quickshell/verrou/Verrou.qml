import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services

// Session locking (ext-session-lock): one surface per screen, PAM authentication.
// The form only appears on the active screen; the others show the clock.
Scope {
	id: root

	property string saisie: ""
	property string etat: "carte"          // carte -> code -> verification -> acces | refus
	property string message: ""
	property int refus: 0
	property date depuis: new Date()
	property date dernierRefus: new Date(0)
	property bool majVerrouillee: false
	readonly property string ecranFormulaire: Etat.ecranActif?.name ?? ""

	Connections {
		target: Etat
		function onVerrouilleChanged() {
			if (Etat.verrouille) { root.saisie = ""; root.etat = "carte"; root.message = ""; root.refus = 0; root.depuis = new Date(); carteLue.restart(); }
		}
	}
	// a short `card read` step before typing, for the staging
	Timer { id: carteLue; interval: 650; onTriggered: if (root.etat === "carte") root.etat = "code" }

	function taper(t) { if (etat === "code" || etat === "refus") { etat = "code"; message = ""; saisie += t; } }
	function effacer() { if (etat === "code" || etat === "refus") saisie = saisie.slice(0, -1); }
	function valider() {
		if (etat !== "code" || saisie === "" || pam.active) return;
		etat = "verification";
		message = "";
		pam.start();
	}

	PamContext {
		id: pam
		// the `login` PAM stack from /etc/pam.d (the one swaylock also uses, via `auth include login`)
		config: "login"
		onResponseRequiredChanged: {
			if (!responseRequired) return;
			respond(root.saisie);
		}
		onPamMessage: { if (messageIsError) root.message = message; }
		onCompleted: resultat => {
			if (resultat === PamResult.Success) {
				root.etat = "acces";
				deverrouiller.restart();
			} else {
				root.refus += 1;
				root.dernierRefus = new Date();
				root.etat = "refus";
				root.message = resultat === PamResult.MaxTries ? "trop d'essais, patiente un moment" : "code refusé";
				root.saisie = "";
			}
		}
	}
	Timer { id: deverrouiller; interval: 450; onTriggered: { Etat.verrouille = false; root.saisie = ""; } }

	// caps lock: read from the kernel LEDs while the screen is locked
	Process {
		id: lectureMaj
		command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -r | head -n1"]
		stdout: StdioCollector { onStreamFinished: root.majVerrouillee = text.trim() !== "" && text.trim() !== "0" }
	}
	Timer { interval: 700; repeat: true; running: Etat.verrouille; triggeredOnStart: true; onTriggered: lectureMaj.running = true }

	WlSessionLock {
		id: verrou
		locked: Etat.verrouille
		SurfaceVerrou { verrou: root }
	}
}
