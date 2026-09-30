pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3

// The supercomputer's log, shown on the wallpaper.
//
// No log file ever pours out on a healthy machine: measured here, the user journal produces
// 0.6 lines per second and the system journal none at all. A log that really scrolls is a system
// in trouble. The throughput therefore comes from sampling the real state quickly — /proc, /sys —
// and not from a file.
//
// TRAP: one FileView per file, never a single one whose path is reassigned. Assigning `path`
// starts a fresh asynchronous read, and text() then returns the PREVIOUS file's contents: the
// probes read their neighbour's data.
//
// Singleton: Variants creates one window per screen, and there must be only one `-f`.
Singleton {
	id: root

	property int maximum: 26            // lines kept on screen
	property int total: 0               // lines emitted since startup, never capped
	property var lignes: []

	function horodate() {
		const d = new Date();
		const n = v => (v < 10 ? "0" + v : String(v));
		return n(d.getHours()) + ":" + n(d.getMinutes()) + ":" + n(d.getSeconds());
	}

	function ajouter(source, texte) {
		root.total++;
		root.lignes = root.lignes.concat([{ h: horodate(), src: source, txt: texte }]).slice(-root.maximum);
	}

	// Rate per second, computed over the time actually elapsed between two passes of the SAME
	// probe — not over the tick period. Each probe only comes round one turn in thirteen:
	// dividing its delta by the tick overstated the network by a factor of thirteen.
	property var precedent: ({})
	function taux(cle, valeur) {
		const maintenant = Date.now();
		const avant = precedent[cle];
		precedent[cle] = { v: valeur, t: maintenant };
		if (!avant) return 0;
		const dt = (maintenant - avant.t) / 1000;
		return dt > 0 ? Math.max(0, (valeur - avant.v) / dt) : 0;
	}

	function octets(n) {
		if (n > 1048576) return (n / 1048576).toFixed(1) + " Mio/s";
		if (n > 1024) return Math.round(n / 1024) + " kio/s";
		return Math.round(n) + " o/s";
	}

	// ---------------------------------------------------------------- files
	FileView { id: fStat; path: "/proc/stat"; blockLoading: true }
	FileView { id: fNet; path: "/proc/net/dev"; blockLoading: true }
	FileView { id: fDisque; path: "/proc/diskstats"; blockLoading: true }
	FileView { id: fCharge; path: "/proc/loadavg"; blockLoading: true }
	FileView { id: fMemoire; path: "/proc/meminfo"; blockLoading: true }

	// one thermal probe per sensor: same reason, each keeps its own path
	property var thermiques: []
	Instantiator {
		id: capteurs
		model: root.thermiques
		delegate: FileView {
			required property var modelData
			path: modelData.chemin
			blockLoading: true
		}
	}

	// ---------------------------------------------------------------- probes
	property int coeur: 0

	function sondeCoeur() {
		fStat.reload();
		const cpus = fStat.text().split("\n").filter(l => /^cpu\d/.test(l));
		if (!cpus.length) return;
		root.coeur = (root.coeur + 1) % cpus.length;
		const v = cpus[root.coeur].trim().split(/\s+/).slice(1).map(Number);
		const dt = taux("t" + root.coeur, v.reduce((a, b) => a + b, 0));
		const di = taux("i" + root.coeur, v[3] + (v[4] ?? 0));
		if (dt <= 0) return;
		const charge = Math.max(0, Math.min(100, Math.round((1 - di / dt) * 100)));
		ajouter("cœur " + String(root.coeur).padStart(2, "0"),
			String(charge).padStart(3) + " % " + "█".repeat(Math.round(charge / 6)));
	}

	function sondeReseau() {
		fNet.reload();
		for (const l of fNet.text().split("\n").slice(2)) {
			const p = l.trim().split(/[:\s]+/);
			if (p.length < 10 || p[0] === "lo" || p[0] === "") continue;
			const rx = taux("rx" + p[0], Number(p[1])), tx = taux("tx" + p[0], Number(p[9]));
			if (rx + tx === 0) continue;
			ajouter(p[0], `↓ ${octets(rx)}   ↑ ${octets(tx)}`);
			return;
		}
		ajouter("liaison", "aucun flux");
	}

	function sondeDisque() {
		fDisque.reload();
		for (const l of fDisque.text().split("\n")) {
			const p = l.trim().split(/\s+/);
			if (p.length < 10 || !/^(nvme\d+n\d+|sd[a-z]|mmcblk\d+)$/.test(p[2])) continue;
			const lus = taux("dr" + p[2], Number(p[5]) * 512);
			const ecr = taux("dw" + p[2], Number(p[9]) * 512);
			ajouter(p[2], `lecture ${octets(lus)}   écriture ${octets(ecr)}`);
			return;
		}
	}

	function sondeCharge() {
		fCharge.reload();
		const p = fCharge.text().trim().split(/\s+/);
		if (p.length < 4) return;
		ajouter("charge", `${p[0]} ${p[1]} ${p[2]} · ${p[3].split("/")[1]} tâches`);
	}

	function sondeMemoire() {
		fMemoire.reload();
		const m = {};
		for (const l of fMemoire.text().split("\n")) {
			const p = l.split(/:\s+/);
			if (p.length === 2) m[p[0]] = parseInt(p[1]);
		}
		if (!m.MemTotal) return;
		const gio = v => (v / 1048576).toFixed(1);
		ajouter("mémoire", `${gio(m.MemTotal - m.MemAvailable)} / ${gio(m.MemTotal)} Gio · cache ${gio(m.Cached)}`);
	}

	property int capteur: 0
	function sondeThermique() {
		if (!root.thermiques.length) return;
		root.capteur = (root.capteur + 1) % root.thermiques.length;
		const vue = capteurs.objectAt(root.capteur);
		if (!vue) return;
		vue.reload();
		const t = parseInt(vue.text());
		if (isNaN(t)) return;
		ajouter(root.thermiques[root.capteur].nom, Math.round(t / 1000) + " °C");
	}

	// interrupts and context switches: the `intr` line of /proc/stat saves rereading
	// /proc/interrupts, which is 24 columns per IRQ.
	function sondeNoyau() {
		fStat.reload();
		const t = fStat.text();
		const intr = t.match(/^intr (\d+)/m), ctxt = t.match(/^ctxt (\d+)/m);
		if (!intr || !ctxt) return;
		const di = taux("intr", Number(intr[1]));
		const dc = taux("ctxt", Number(ctxt[1]));
		ajouter("noyau", `${Math.round(di)} irq/s · ${Math.round(dc)} commutations/s`);
	}

	// the rotation gives the stream its density: the cores dominate, the rest punctuates
	readonly property var sondes: [
		sondeCoeur, sondeCoeur, sondeReseau, sondeCoeur, sondeThermique,
		sondeCoeur, sondeDisque, sondeCoeur, sondeNoyau, sondeCoeur,
		sondeCharge, sondeCoeur, sondeMemoire
	]
	property int pas: 0
	property int battement: 100           // ms between lines: ~10 per second
	Timer {
		// game mode cuts the sampling: ten /proc reads per second, for scenery
		running: !Reglages.modeJeu
		interval: root.battement
		repeat: true
		onTriggered: {
			root.sondes[root.pas % root.sondes.length]();
			root.pas++;
		}
	}

	// --- discovery of the thermal sensors, once at startup ---
	Process {
		running: true
		command: ["sh", "-c",
			'for d in /sys/class/hwmon/hwmon*; do [ -r "$d/temp1_input" ] && printf "%s\\t%s/temp1_input\\n" "$(cat "$d/name")" "$d"; done']
		stdout: StdioCollector {
			onStreamFinished: root.thermiques = text.split("\n").filter(l => l).map(l => {
				const p = l.split("\t");
				return { nom: p[0], chemin: p[1] };
			})
		}
	}

	// ---------------------------------------------------------------- events
	// These are not measurements: they must only appear when something changes, otherwise they
	// repeat on every turn of the rotation.
	readonly property string secteur: I3.focusedWorkspace?.name ?? ""
	onSecteurChanged: if (secteur) ajouter("transfert", "secteur " + Sway.nomAffiche(secteur).toUpperCase())

	readonly property string fenetre: Sway.titreFocus
	onFenetreChanged: if (fenetre) ajouter("tour", `focus « ${fenetre.slice(0, 46)} »`)

	readonly property string liaison: Controle.enLigne
	onLiaisonChanged: ajouter("liaison", liaison)

	// the real systemd journal: rare, so marked to stand out from the background noise
	Process {
		running: true
		command: ["journalctl", "--user", "-f", "-n", "0", "-o", "short", "--no-hostname", "-q"]
		stdout: SplitParser {
			onRead: brut => {
				const m = brut.match(/^\w+\s+\d+\s+\d\d:\d\d:\d\d\s+([^:]+):\s*(.*)$/);
				if (!m || !m[2]) return;
				root.ajouter("⚠ " + m[1].replace(/\[\d+\]$/, "").split("/").pop(), m[2]);
			}
		}
	}
}
