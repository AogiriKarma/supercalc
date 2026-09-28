import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services

// Verrouillage de session (ext-session-lock) : une surface par écran, authentification PAM.
// Le formulaire n'apparaît que sur l'écran actif ; les autres affichent l'heure.
Scope {
	id: root

	property string saisie: ""
	property string etat: "carte"          // carte → code → verification → acces | refus
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
	// petite étape « carte lue » avant la saisie, pour la mise en scène
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
		// pile PAM « login » de /etc/pam.d (celle qu'utilise aussi swaylock via « auth include login »)
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

	// verrouillage majuscules : lu sur les LED du noyau pendant que l'écran est verrouillé
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
