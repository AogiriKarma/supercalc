pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.theme

// État système lu par le panneau de contrôle : session, réseau, bluetooth, son, luminosité,
// lumière nuit, veille auto. Chaque source absente (pas de NetworkManager, pas de bluez…)
// laisse simplement sa tuile en « indisponible ».
Singleton {
	id: root

	// --- session ---
	property string utilisateur: (Quickshell.env("USER") ?? Quickshell.env("LOGNAME") ?? "").toUpperCase()
	Process { running: root.utilisateur === ""; command: ["id", "-un"]; stdout: StdioCollector { onStreamFinished: root.utilisateur = text.trim().toUpperCase() } }
	property string machine: ""
	property int secondes: 0
	readonly property string enLigne: {
		const h = Math.floor(secondes / 3600), m = Math.floor(secondes % 3600 / 60);
		return h > 0 ? `${h} h ${String(m).padStart(2, "0")}` : `${m} min`;
	}
	FileView { id: nomMachine; path: "/proc/sys/kernel/hostname"; onLoaded: root.machine = text().trim() }
	FileView { id: dureeMarche; path: "/proc/uptime"; onLoaded: root.secondes = Math.floor(Number(text().split(" ")[0])) }
	Timer { interval: 30000; running: true; repeat: true; onTriggered: dureeMarche.reload() }

	// --- réseau (NetworkManager) ---
	readonly property bool reseauDispo: Networking.backend === NetworkBackendType.NetworkManager
	readonly property var carteWifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
	readonly property var reseauWifi: carteWifi ? carteWifi.networks.values.find(n => n.connected) ?? null : null
	readonly property bool filaire: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)
	readonly property string etatWifi: {
		if (!reseauDispo || !carteWifi) return filaire ? "câble branché" : "indisponible";
		if (!Networking.wifiEnabled) return "désactivé";
		if (reseauWifi) return `${reseauWifi.name} · ${Math.round(reseauWifi.signalStrength * 100)} %`;
		return "aucun réseau";
	}
	function basculerWifi() { if (reseauDispo) Networking.wifiEnabled = !Networking.wifiEnabled; }

	// --- bluetooth (bluez) ---
	readonly property var adaptateur: Bluetooth.defaultAdapter
	readonly property var appareilsBt: adaptateur ? adaptateur.devices.values.filter(d => d.connected) : []
	readonly property string etatBt: !adaptateur ? "indisponible" : !adaptateur.enabled ? "désactivé"
		: appareilsBt.length === 1 ? appareilsBt[0].name + (appareilsBt[0].batteryAvailable ? ` · ${Math.round(appareilsBt[0].battery * 100)} %` : "")
		: appareilsBt.length > 1 ? `${appareilsBt.length} appareils` : "aucun appareil"
	function basculerBt() { if (adaptateur) adaptateur.enabled = !adaptateur.enabled; }

	// --- son ---
	readonly property var sortie: Pipewire.defaultAudioSink
	readonly property var entree: Pipewire.defaultAudioSource
	readonly property var sorties: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
	PwObjectTracker { objects: [root.sortie, root.entree].concat(root.sorties).filter(o => o) }
	function nomNoeud(n) { return n ? (n.nickname || n.description || n.name) : "aucune"; }
	function sortieSuivante() {
		if (sorties.length < 2) return;
		const i = sorties.indexOf(sortie);
		Pipewire.preferredDefaultAudioSink = sorties[(i + 1) % sorties.length];
	}

	// --- luminosité (brightnessctl) ---
	property real luminosite: -1          // -1 = pas de rétroéclairage
	Process {
		id: lectureLum
		command: ["brightnessctl", "-m", "-c", "backlight"]
		stdout: StdioCollector {
			onStreamFinished: {
				const c = text.trim().split("\n")[0]?.split(",") ?? [];
				root.luminosite = c.length >= 5 ? Number(c[2]) / Number(c[4]) : -1;
			}
		}
	}
	function lireLuminosite() { lectureLum.running = true; }
	function reglerLuminosite(v) {
		luminosite = Math.max(0.01, Math.min(1, v));
		Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", Math.round(luminosite * 100) + "%"]);
	}

	// --- lumière nuit et veille auto (scripts/nuit, scripts/veille) ---
	readonly property string scripts: Quickshell.env("HOME") + "/.config/supercalc/scripts/"
	property bool nuit: false
	property bool veille: false
	Process { id: etatNuit; command: ["pgrep", "-x", "wlsunset"]; onExited: code => root.nuit = code === 0 }
	Process { id: etatVeille; command: ["pgrep", "-x", "swayidle"]; onExited: code => root.veille = code === 0 }
	function relire() { etatNuit.running = true; etatVeille.running = true; lireLuminosite(); dureeMarche.reload(); }
	Timer { id: relecture; interval: 400; onTriggered: root.relire() }
	function basculerNuit() { nuit = !nuit; Quickshell.execDetached([scripts + "nuit", "basculer"]); relecture.restart(); }
	function basculerVeille() { veille = !veille; Quickshell.execDetached([scripts + "veille", "basculer"]); relecture.restart(); }
	readonly property string finNuit: Quickshell.env("SUPERCALC_NUIT_FIN") ?? "07:00"
	readonly property string delaiVeille: Math.round(Number(Quickshell.env("SUPERCALC_VERROU") ?? 600) / 60) + " min"

	// --- énergie ---
	readonly property var batterie: UPower.displayDevice
	readonly property bool aBatterie: Systeme.aBatterie
	readonly property string profil: {
		const p = PowerProfiles.profile;
		return p === PowerProfile.PowerSaver ? "économie" : p === PowerProfile.Performance ? "performance" : "équilibré";
	}
	function profilSuivant() {
		const ordre = [PowerProfile.PowerSaver, PowerProfile.Balanced].concat(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : []);
		const i = ordre.indexOf(PowerProfiles.profile);
		PowerProfiles.profile = ordre[(i + 1) % ordre.length];
	}

	Component.onCompleted: relire()
}
