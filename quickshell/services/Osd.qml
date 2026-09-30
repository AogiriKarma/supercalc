pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.theme

// On-screen display (volume, microphone, brightness, keyboard): one gauge at a time, 1.5 s.
// Volume and microphone are followed live through PipeWire; brightness is requested by sway after
// brightnessctl (qs ipc call osd luminosite); the keyboard follows Sway.disposition.
Singleton {
	id: root

	property bool visible: false
	property string nom: ""
	property string icone: ""
	property real valeur: 0          // 0..1
	property string texte: ""
	property bool alerte: false      // microphone muted, sound muted: XANA frame

	function montrer(n, ic, v, t, a) {
		if (!pret) return;
		nom = n; icone = ic; valeur = v; texte = t; alerte = !!a;
		visible = true;
		minuteur.restart();
	}

	// no OSD during startup (the initial values arrive in a burst)
	property bool pret: false
	Timer { interval: 2500; running: true; onTriggered: root.pret = true }
	Timer { id: minuteur; interval: 1500; onTriggered: root.visible = false }

	// --- sound ---
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

	// --- brightness: brightnessctl -m -> "intel_backlight,backlight,4800,50%,9600" ---
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

	// --- keyboard ---
	Connections {
		target: Sway
		function onDispositionChanged() { root.montrer("clavier", Icones.clavier, 1, Sway.dispositionCourte, false); }
	}
}
