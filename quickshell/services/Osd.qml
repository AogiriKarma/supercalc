pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.theme

// Affichage à l'écran (volume, micro, luminosité, clavier) : une jauge à la fois, 1,5 s.
// Volume et micro sont suivis en direct via PipeWire ; la luminosité est demandée par
// sway après brightnessctl (qs ipc call osd luminosite) ; le clavier suit Sway.disposition.
Singleton {
	id: root

	property bool visible: false
	property string nom: ""
	property string icone: ""
	property real valeur: 0          // 0..1
	property string texte: ""
	property bool alerte: false      // micro coupé, son coupé : cadre XANA

	function montrer(n, ic, v, t, a) {
		if (!pret) return;
		nom = n; icone = ic; valeur = v; texte = t; alerte = !!a;
		visible = true;
		minuteur.restart();
	}

	// pas d'OSD pendant le démarrage (les valeurs initiales arrivent en rafale)
	property bool pret: false
	Timer { interval: 2500; running: true; onTriggered: root.pret = true }
	Timer { id: minuteur; interval: 1500; onTriggered: root.visible = false }

	// --- son ---
	readonly property var sortie: Pipewire.defaultAudioSink
	readonly property var entree: Pipewire.defaultAudioSource
	PwObjectTracker { objects: [root.sortie, root.entree].filter(o => o) }

	function montrerVolume() {
		const a = sortie?.audio; if (!a) return;
		const v = Math.round(a.volume * 100);
		montrer("volume", a.muted ? Icones.volumeMuet : Icones.volume, a.volume, a.muted ? "MUET" : String(v), a.muted);
	}
	function montrerMicro() {
		const a = entree?.audio; if (!a) return;
		montrer("micro", a.muted ? Icones.microCoupe : Icones.micro, a.muted ? 0 : a.volume, a.muted ? "OFF" : String(Math.round(a.volume * 100)), a.muted);
	}
	Connections {
		target: root.sortie?.audio ?? null
		function onVolumesChanged() { root.montrerVolume(); }
		function onMutedChanged() { root.montrerVolume(); }
	}
	Connections {
		target: root.entree?.audio ?? null
		function onMutedChanged() { root.montrerMicro(); }
	}

	// --- luminosité : brightnessctl -m → "intel_backlight,backlight,4800,50%,9600" ---
	Process {
		id: lecteurLuminosite
		command: ["brightnessctl", "-m", "-c", "backlight"]
		stdout: StdioCollector {
			onStreamFinished: {
				const champs = text.trim().split("\n")[0]?.split(",") ?? [];
				if (champs.length < 5) return;
				const v = Number(champs[2]) / Number(champs[4]);
				root.montrer("écran", Icones.ecran, v, String(Math.round(v * 100)), false);
			}
		}
	}
	function luminosite() { lecteurLuminosite.running = true; }

	// --- clavier ---
	Connections {
		target: Sway
		function onDispositionChanged() { root.montrer("clavier", Icones.clavier, 1, Sway.dispositionCourte, false); }
	}
}
