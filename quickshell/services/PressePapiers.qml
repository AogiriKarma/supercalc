pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Historique du presse-papiers, lu dans cliphist (rempli par « wl-paste --watch cliphist store »).
// Les épingles sont gardées à part (cliphist n'en a pas) dans l'état de la config.
Singleton {
	id: root

	property var entrees: []          // [{ ligne, id, apercu, type: texte|lien|image|couleur, image: {format, l, h, taille}, fichier }]
	property bool disponible: true
	readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") ?? Quickshell.env("HOME") + "/.cache") + "/supercalc/presse-papiers"

	// ---------------- épingles ----------------
	property var epingles: []         // textes épinglés
	FileView {
		id: fichierEpingles
		path: Quickshell.statePath("epingles.json")
		onLoaded: { try { root.epingles = JSON.parse(text()) ?? []; } catch (e) { root.epingles = []; } }
		onLoadFailed: root.epingles = []
	}
	function basculerEpingle(texte) {
		const l = epingles.includes(texte) ? epingles.filter(t => t !== texte) : [texte].concat(epingles);
		epingles = l;
		fichierEpingles.setText(JSON.stringify(l));
	}

	// ---------------- lecture ----------------
	function typeDe(apercu) {
		// cliphist ≥ 0.5 : « [[ binary data 12 KiB png 588x388 ]] » ; versions plus anciennes : « binary data image/png »
		if (/^\[\[ binary data .* \]\]$/.test(apercu) || /^binary data image\//.test(apercu)) return "image";
		if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(apercu.trim())) return "couleur";
		if (/^(https?|ftp|file):\/\//.test(apercu.trim())) return "lien";
		return "texte";
	}
	function relire() { liste.running = true; }

	Process {
		id: liste
		command: ["cliphist", "list"]
		stdout: StdioCollector {
			onStreamFinished: {
				const res = [];
				for (const ligne of text.split("\n")) {
					const t = ligne.indexOf("\t");
					if (t < 0) continue;
					const apercu = ligne.slice(t + 1);
					const type = root.typeDe(apercu);
					const e = { ligne, id: ligne.slice(0, t), apercu, type };
					if (type === "image") {
						// « [[ binary data 12 KiB png 588x388 ]] »
						const m = apercu.match(/binary data (.+?) (\w+) (\d+)x(\d+)/);
						const ancien = apercu.match(/binary data image\/(\w+)/);
						e.image = m ? { taille: m[1], format: m[2], l: +m[3], h: +m[4] } : { taille: "", format: ancien ? ancien[1] : "png", l: 0, h: 0 };
						e.fichier = `${root.cache}/${e.id}.${e.image.format || "png"}`;
						e.apercu = m ? `image ${m[3]} × ${m[4]} · ${m[1]}` : `image ${e.image.format}`;
					}
					res.push(e);
				}
				root.entrees = res;
				root.miniatures();
			}
		}
		onExited: code => root.disponible = code === 0
	}

	// miniatures : les 12 premières images sont décodées une fois dans le cache
	property int generation: 0        // change quand de nouvelles miniatures sont prêtes
	Process { id: decodeImages; onExited: root.generation += 1 }
	function miniatures() {
		const imgs = entrees.filter(e => e.type === "image").slice(0, 12);
		if (!imgs.length) return;
		const script = `mkdir -p "${cache}"; ` + imgs.map(e => `[ -s "${e.fichier}" ] || printf '%s\\n' "$${imgs.indexOf(e) + 1}" | cliphist decode > "${e.fichier}"`).join("; ");
		decodeImages.command = ["sh", "-c", script, "sh"].concat(imgs.map(e => e.ligne));
		decodeImages.running = true;
	}

	// ---------------- actions ----------------
	function copier(e) {
		if (e.texteEpingle !== undefined) Quickshell.execDetached(["wl-copy", "--", e.texteEpingle]);
		else Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist decode | wl-copy', "sh", e.ligne]);
	}
	function supprimer(e) {
		if (e.texteEpingle !== undefined) { basculerEpingle(e.texteEpingle); return; }
		Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", e.ligne]);
		entrees = entrees.filter(x => x !== e);
	}
	// le texte complet est nécessaire pour épingler (l'aperçu est tronqué à 100 caractères)
	Process {
		id: lecturePourEpingle
		property string ligne
		command: ["sh", "-c", 'printf "%s\\n" "$1" | cliphist decode', "sh", ligne]
		stdout: StdioCollector { onStreamFinished: if (text) root.basculerEpingle(text) }
	}
	function epingler(e) {
		if (e.texteEpingle !== undefined) basculerEpingle(e.texteEpingle);
		else if (e.type !== "image") { lecturePourEpingle.ligne = e.ligne; lecturePourEpingle.running = true; }
	}
	function toutEffacer() { Quickshell.execDetached(["cliphist", "wipe"]); entrees = []; }
}
