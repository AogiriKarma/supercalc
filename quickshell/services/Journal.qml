pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3

// Journal du supercalculateur, affiché en fond d'écran.
//
// Aucun fichier de log ne « mitraille » sur une machine saine : mesuré ici, le journal
// utilisateur sort 0,6 ligne par seconde et le journal système zéro. Un log qui défile
// vraiment, c'est un système qui va mal. Le débit vient donc d'un échantillonnage rapide
// de l'état réel — /proc, /sys — et non d'un fichier.
//
// PIEGE : un FileView par fichier, jamais un seul dont on change le chemin. Affecter
// « path » relance une lecture asynchrone, et text() rend alors le contenu du fichier
// précédent : les sondes lisent les données de leur voisine.
//
// Singleton : Variants crée une fenêtre par écran, il ne doit exister qu'un « -f ».
Singleton {
	id: root

	property int maximum: 26            // lignes gardées à l'écran
	property int total: 0               // lignes émises depuis le démarrage, jamais bornées
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

	// Débit par seconde, calculé sur le temps réellement écoulé entre deux passages de la
	// MÊME sonde — pas sur la période du battement. Chaque sonde ne passe qu'un tour sur
	// treize : rapporter son écart au battement surestimait le réseau d'un facteur treize.
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

	// ---------------------------------------------------------------- fichiers
	FileView { id: fStat; path: "/proc/stat"; blockLoading: true }
	FileView { id: fNet; path: "/proc/net/dev"; blockLoading: true }
	FileView { id: fDisque; path: "/proc/diskstats"; blockLoading: true }
	FileView { id: fCharge; path: "/proc/loadavg"; blockLoading: true }
	FileView { id: fMemoire; path: "/proc/meminfo"; blockLoading: true }

	// une sonde thermique par capteur : même raison, chacune garde son chemin
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

	// ---------------------------------------------------------------- sondes
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

	// interruptions et commutations de contexte : la ligne « intr » de /proc/stat évite
	// de relire /proc/interrupts, qui fait 24 colonnes par IRQ.
	function sondeNoyau() {
		fStat.reload();
		const t = fStat.text();
		const intr = t.match(/^intr (\d+)/m), ctxt = t.match(/^ctxt (\d+)/m);
		if (!intr || !ctxt) return;
		const di = taux("intr", Number(intr[1]));
		const dc = taux("ctxt", Number(ctxt[1]));
		ajouter("noyau", `${Math.round(di)} irq/s · ${Math.round(dc)} commutations/s`);
	}

	// la rotation donne sa densité au flux : les cœurs dominent, le reste ponctue
	readonly property var sondes: [
		sondeCoeur, sondeCoeur, sondeReseau, sondeCoeur, sondeThermique,
		sondeCoeur, sondeDisque, sondeCoeur, sondeNoyau, sondeCoeur,
		sondeCharge, sondeCoeur, sondeMemoire
	]
	property int pas: 0
	property int battement: 100           // ms entre deux lignes : ~10 par seconde
	Timer {
		// le mode jeu coupe le sondage : dix lectures de /proc par seconde pour un décor
		running: !Reglages.modeJeu
		interval: root.battement
		repeat: true
		onTriggered: {
			root.sondes[root.pas % root.sondes.length]();
			root.pas++;
		}
	}

	// --- découverte des capteurs thermiques, une fois au démarrage ---
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

	// ---------------------------------------------------------------- événements
	// Ceux-ci ne sont pas des mesures : ils ne doivent apparaître qu'au changement,
	// sinon ils se répètent à chaque tour de rotation.
	readonly property string secteur: I3.focusedWorkspace?.name ?? ""
	onSecteurChanged: if (secteur) ajouter("transfert", "secteur " + Sway.nomAffiche(secteur).toUpperCase())

	readonly property string fenetre: Sway.titreFocus
	onFenetreChanged: if (fenetre) ajouter("tour", `focus « ${fenetre.slice(0, 46)} »`)

	readonly property string liaison: Controle.enLigne
	onLiaisonChanged: ajouter("liaison", liaison)

	// vrai journal systemd : rare, donc marqué pour se distinguer du bruit de fond
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
