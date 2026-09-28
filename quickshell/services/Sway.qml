pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3

// État de sway au-delà de ce que fournit Quickshell.I3 :
// nombre de fenêtres par secteur, titre focalisé, disposition clavier.
Singleton {
	id: root

	// { "1:foret": 3, ... }
	property var fenetresParSecteur: ({})
	// [{ id, titre, appId, secteur, focus, flottante }] — toutes les fenêtres, pour le lanceur et l'holomap
	property var fenetres: []
	// [{ nom, num, sortie, rect, focus, visible, urgent, fenetres: [...] }] — les secteurs avec leurs fenêtres (holomap)
	property var secteurs: []
	// [{ nom, largeur, hauteur, frequence, echelle, marque, modele, x, y }] — les écrans actifs
	property var sorties: []
	property string titreFocus: ""
	property string appFocus: ""
	property string disposition: ""        // ex. "French"
	readonly property string dispositionCourte: {
		const d = disposition.toLowerCase();
		if (d.startsWith("french")) return "FR";
		if (d.startsWith("english")) return "US";
		return disposition.slice(0, 2).toUpperCase();
	}
	readonly property var secteurUrgent: {
		for (const w of I3.workspaces.values) if (w.urgent) return w;
		return null;
	}

	function nomAffiche(nom) {
		// "1:foret" → "FORÊT" ; "5" → "5" ; les noms sont libres, seul l'affichage est traduit
		const brut = nom.includes(":") ? nom.split(":").slice(1).join(":") : nom;
		const table = { foret: "Forêt", montagne: "Montagne", banquise: "Banquise", desert: "Désert", secteur5: "Secteur 5", carthage: "Carthage" };
		return table[brut] ?? brut;
	}

	property string sortieCourante: ""
	property var _secteurs: []
	function compter(noeud, secteur, acc, liste) {
		if (noeud.type === "output") sortieCourante = noeud.name;
		if (noeud.type === "workspace") {
			secteur = noeud.name;
			if (noeud.name !== "__i3_scratch") root._secteurs.push({ nom: noeud.name, num: noeud.num ?? -1, sortie: sortieCourante, rect: noeud.rect,
				focus: !!noeud.focused, visible: !!noeud.visible, urgent: !!noeud.urgent, fenetres: [] });
		}
		const estFenetre = (noeud.type === "con" || noeud.type === "floating_con") && (noeud.pid !== undefined && noeud.pid !== null);
		if (estFenetre && secteur && secteur !== "__i3_scratch") acc[secteur] = (acc[secteur] ?? 0) + 1;
		if (estFenetre) liste.push({
			id: noeud.id, titre: noeud.name ?? "", appId: noeud.app_id ?? noeud.window_properties?.class ?? "",
			secteur: secteur === "__i3_scratch" ? "" : secteur, focus: !!noeud.focused, flottante: noeud.type === "floating_con",
			rect: noeud.rect, sortie: sortieCourante
		});
		if (estFenetre && noeud.focused) { root.titreFocus = noeud.name ?? ""; root.appFocus = noeud.app_id ?? ""; }
		for (const n of (noeud.nodes ?? [])) compter(n, secteur, acc, liste);
		for (const n of (noeud.floating_nodes ?? [])) compter(n, secteur, acc, liste);
	}

	Process {
		id: arbre
		command: ["swaymsg", "-r", "-t", "get_tree"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const acc = {}, liste = [];
					root._secteurs = [];
					root.compter(JSON.parse(text), "", acc, liste);
					for (const f of liste) {
						const sec = root._secteurs.find(w => w.nom === f.secteur);
						if (sec) sec.fenetres.push(f);
					}
					for (const sec of root._secteurs) sec.focus = sec.focus || sec.fenetres.some(f => f.focus);
					root.secteurs = root._secteurs;
					root.fenetresParSecteur = acc;
					root.fenetres = liste;
				} catch (e) { console.warn("sway: arbre illisible", e); }
			}
		}
	}

	Process {
		id: ecrans
		command: ["swaymsg", "-r", "-t", "get_outputs"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.sorties = JSON.parse(text).filter(o => o.active).map(o => ({
						nom: o.name, largeur: o.current_mode?.width ?? o.rect.width, hauteur: o.current_mode?.height ?? o.rect.height,
						frequence: Math.round((o.current_mode?.refresh ?? 0) / 1000), echelle: o.scale ?? 1,
						marque: o.make ?? "", modele: o.model ?? "", x: o.rect.x, y: o.rect.y,
						// taille logique (après échelle et rotation) : c'est elle qui donne la forme de l'écran
						logiqueL: o.rect.width, logiqueH: o.rect.height, rotation: o.transform ?? "normal"
					})).sort((a, b) => (a.x - b.x) || (a.y - b.y));
				} catch (e) { console.warn("sway: écrans illisibles", e); }
			}
		}
	}

	Process {
		id: entrees
		command: ["swaymsg", "-r", "-t", "get_inputs"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					for (const i of JSON.parse(text)) {
						if (i.type === "keyboard" && i.xkb_active_layout_name) { root.disposition = i.xkb_active_layout_name; return; }
					}
				} catch (e) { console.warn("sway: entrées illisibles", e); }
			}
		}
	}

	// regroupe les rafales d'événements en une seule lecture de l'arbre
	Timer { id: differe; interval: 60; onTriggered: arbre.running = true }

	I3IpcListener {
		subscriptions: ["window", "workspace", "input", "output"]
		onIpcEvent: event => {
			if (event.type === "input") entrees.running = true;
			else if (event.type === "output") { ecrans.running = true; differe.restart(); }
			else differe.restart();
		}
	}

	function focaliser(id) { I3.dispatch(`[con_id=${id}] focus`); }
	function amener(id) { I3.dispatch(`[con_id=${id}] move container to workspace current; [con_id=${id}] focus`); }
	function fermer(id) { I3.dispatch(`[con_id=${id}] kill`); }
	// premier numéro de secteur libre (1..9), pour « lancer dans un nouveau secteur »
	function secteurLibre() {
		const pris = new Set(I3.workspaces.values.map(w => w.number));
		for (let i = 1; i <= 9; i++) if (!pris.has(i)) return i;
		return 10;
	}

	Component.onCompleted: { arbre.running = true; entrees.running = true; ecrans.running = true; }
}
