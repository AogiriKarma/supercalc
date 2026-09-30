pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3
import qs.theme

// The launcher engine (Super+D): applications, open windows, files, system commands.
// Prefixes: "=" calculation · ">" shell command · "/" files · "?" web search.
Singleton {
	id: root

	property string requete: ""
	property string categorie: "tout"          // tout | applis | fenetres | fichiers | commandes
	readonly property var categories: ["tout", "applis", "fenetres", "fichiers", "commandes"]
	readonly property var nomsCategories: ({ tout: "Tout", applis: "Applis", fenetres: "Fenêtres", fichiers: "Fichiers", commandes: "Commandes" })

	readonly property string prefixe: /^[=>\/?]/.test(requete) ? requete[0] : ""
	readonly property string termes: (prefixe ? requete.slice(1) : requete).trim()

	function reinitialiser() { requete = ""; categorie = "tout"; fichiers = []; }

	// ---------------------------------------------------------------- matching
	// score > 0 if q matches t; debut/fin = the span to highlight (-1 for a subsequence)
	function correspondre(t, q, strict) {
		if (!q) return { s: 1, d: -1, f: -1 };
		const a = t.toLowerCase(), b = q.toLowerCase();
		const i = a.indexOf(b);
		if (i === 0) return { s: 100 - a.length * 0.1, d: 0, f: b.length };
		if (i > 0) {
			const debutMot = /[\s\-_.\/·—]/.test(a[i - 1]);
			return { s: (debutMot ? 70 : 45) - i * 0.5, d: i, f: i + b.length };
		}
		if (strict) return { s: 0, d: -1, f: -1 };
		// subsequence (ff → firefox), on names only
		let j = 0;
		for (let k = 0; k < a.length && j < b.length; k++) if (a[k] === b[j]) j++;
		return j === b.length && b.length >= 2 ? { s: 15, d: -1, f: -1 } : { s: 0, d: -1, f: -1 };
	}

	// HTML (StyledText) with the matched part underlined in the accent colour
	function surligner(t, m, couleur) {
		const e = x => x.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
		if (!m || m.d < 0) return e(t);
		return e(t.slice(0, m.d)) + `<u><font color="${couleur}">` + e(t.slice(m.d, m.f)) + "</font></u>" + e(t.slice(m.f));
	}

	// ---------------------------------------------------------------- usage statistics
	// ~/.local/state/quickshell/by-shell/<id>/lanceur.json : { "firefox.desktop": { n: 142, t: 1790000000000 } }
	property var usage: ({})
	FileView {
		id: fichierUsage
		path: Quickshell.statePath("lanceur.json")
		onLoaded: { try { root.usage = JSON.parse(text()) ?? {}; } catch (e) { root.usage = {}; } }
		onLoadFailed: root.usage = {}
	}
	function noter(cle) {
		const u = Object.assign({}, usage);
		u[cle] = { n: (u[cle]?.n ?? 0) + 1, t: Date.now() };
		usage = u;
		fichierUsage.setText(JSON.stringify(u));
	}
	// recent frequency: launches count for less as time passes
	function frecence(cle) {
		const u = usage[cle]; if (!u) return 0;
		const jours = (Date.now() - u.t) / 86400000;
		return Math.log2(1 + u.n) * (jours < 1 ? 4 : jours < 7 ? 2 : jours < 30 ? 1 : 0.5);
	}
	function ilYa(ms) {
		if (!ms) return "jamais";
		const m = Math.round((Date.now() - ms) / 60000);
		if (m < 1) return "à l'instant";
		if (m < 60) return `il y a ${m} min`;
		const h = Math.round(m / 60);
		if (h < 24) return `il y a ${h} h`;
		const j = Math.round(h / 24);
		return j === 1 ? "hier" : `il y a ${j} jours`;
	}

	// ---------------------------------------------------------------- sources
	function applis(q) {
		const res = [];
		for (const e of DesktopEntries.applications.values) {
			if (e.noDisplay) continue;
			const m = [correspondre(e.name, q), correspondre(e.genericName || "", q, true), correspondre((e.keywords ?? []).join(" "), q, true), correspondre(e.id, q, true)];
			const meilleur = Math.max(m[0].s, m[1].s * 0.6, m[2].s * 0.5, m[3].s * 0.4);
			if (meilleur <= 0) continue;
			const ouvertes = Sway.fenetres.filter(f => f.appId && (f.appId === e.startupClass || f.appId === e.id.replace(/\.desktop$/, "") || f.appId.toLowerCase() === e.name.toLowerCase()));
			res.push({
				type: "appli", cle: e.id, titre: e.name, correspondance: m[0].s > 0 ? m[0] : null,
				sous: e.genericName || e.comment || e.id, icone: Applis.icone(e, e.id), entree: e, ouvertes,
				score: meilleur + frecence(e.id) * 6
			});
			// the application's actions (`private window`…) only when the search aims at them
			if (q) for (const a of e.actions) {
				const ma = correspondre(e.name + " — " + a.name, q);
				if (ma.s > 0 && correspondre(a.name, q).s > 0 || (m[0].s > 0 && q.length >= 3))
					res.push({ type: "action", cle: e.id + "#" + a.id, titre: e.name + " — " + a.name, correspondance: ma.d >= 0 ? ma : null,
						sous: "action de l'application", icone: Applis.icone(e, e.id), entree: e, action: a, ouvertes: [], score: meilleur * 0.5 });
			}
		}
		return res.sort((a, b) => (b.score - a.score) || a.titre.localeCompare(b.titre));
	}

	function fenetres(q) {
		const res = [];
		for (const f of Sway.fenetres) {
			const t = (f.appId ? f.appId + " — " : "") + f.titre;
			const m = correspondre(t, q);
			if (m.s <= 0) continue;
			const e = Applis.entree(f.appId);
			const num = f.secteur.split(":")[0];
			res.push({ type: "fenetre", cle: "con:" + f.id, titre: t, correspondance: m, fenetre: f,
				sous: f.secteur ? `secteur ${num} ${Sway.nomAffiche(f.secteur).toLowerCase()} · aller à la fenêtre` : "scratchpad · aller à la fenêtre",
				touche: /^\d$/.test(num) ? "SUPER " + num : "", icone: Applis.icone(e, f.appId), score: m.s + (f.focus ? -5 : 0) });
		}
		return res.sort((a, b) => b.score - a.score);
	}

	readonly property var listeCommandes: [
		{ titre: "Verrouiller", sous: "session · super échap", icone: Icones.verrou, faire: () => Etat.verrouiller() },
		{ titre: "Mise en veille", sous: "session · systemctl suspend", icone: Icones.lune, faire: () => Quickshell.execDetached(["systemctl", "suspend"]) },
		{ titre: "Éteindre", sous: "session · menu d'énergie", icone: Icones.arret, faire: () => Etat.ouvrir("power") },
		{ titre: "Redémarrer", sous: "session · menu d'énergie", icone: Icones.retour, faire: () => Etat.ouvrir("power") },
		{ titre: "Se déconnecter", sous: "session · quitter sway", icone: Icones.sortie, faire: () => Etat.ouvrir("power") },
		{ titre: "Recharger sway", sous: "sway · reload", icone: Icones.synchro, faire: () => Quickshell.execDetached(["swaymsg", "reload"]) },
		{ titre: "Capture de zone", sous: "capture · impr", icone: Icones.zone, faire: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/supercalc/scripts/capture", "zone"]) },
		{ titre: "Capture d'écran", sous: "capture · super impr", icone: Icones.moniteur, faire: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/supercalc/scripts/capture", "ecran"]) },
		{ titre: "Pipette", sous: "couleur sous le curseur · super c", icone: Icones.goutte, faire: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/supercalc/scripts/pipette"]) },
		{ titre: "Presse-papiers", sous: "historique · super v", icone: Icones.copier, faire: () => Etat.ouvrir("presse-papiers") },
		{ titre: "Holomap", sous: "vue des secteurs · super tab", icone: Icones.secteur, faire: () => Etat.ouvrir("holomap") },
		{ titre: "Manuel des raccourcis", sous: "aide · super /", icone: Icones.clavier, faire: () => Etat.ouvrir("manuel") },
		{ titre: "Réglages", sous: "apparence, écrans, dock", icone: Icones.reglages, faire: () => Etat.ouvrir("reglages") },
		{ titre: "Mode silence", sous: "notifications · ne garder que les critiques", icone: Icones.silence, faire: () => { Notifs.silencieux = !Notifs.silencieux; } },
	]
	function commandes(q) {
		const res = [];
		for (const c of listeCommandes) {
			const m = correspondre(c.titre, q);
			const ms = correspondre(c.sous, q, true);
			const s = Math.max(m.s, ms.s * 0.5);
			if (s <= 0) continue;
			res.push({ type: "commande", cle: "cmd:" + c.titre, titre: c.titre, correspondance: m.s > 0 ? m : null, sous: c.sous, icone: c.icone, commande: c, score: s + frecence("cmd:" + c.titre) * 4 });
		}
		return res.sort((a, b) => b.score - a.score);
	}

	// files: fd if installed, otherwise find; started after a delay on each keystroke
	property var fichiers: []
	property string requeteFichiers: ""
	readonly property bool chercheFichiers: termes.length >= 2 && (prefixe === "/" || (prefixe === "" && (categorie === "tout" || categorie === "fichiers")))
	onTermesChanged: { if (chercheFichiers) differeFichiers.restart(); else fichiers = []; }
	onCategorieChanged: { if (chercheFichiers) differeFichiers.restart(); }
	Timer { id: differeFichiers; interval: 140; onTriggered: { rechercheFichiers.running = false; root.requeteFichiers = root.termes; rechercheFichiers.running = true; } }
	Process {
		id: rechercheFichiers
		command: ["sh", "-c",
			'cd "$HOME" && if command -v fd >/dev/null; then fd --type f --ignore-case --max-results 30 --fixed-strings -- "$1"; ' +
			'else find . -maxdepth 5 -type f -not -path "*/.*" -iname "*$1*" 2>/dev/null | head -n 30 | sed "s|^\\./||"; fi', "sh", root.requeteFichiers]
		stdout: StdioCollector {
			onStreamFinished: {
				const q = root.requeteFichiers;
				root.fichiers = text.split("\n").filter(l => l).map(chemin => {
					const i = chemin.lastIndexOf("/");
					const dossier = "~/" + chemin.slice(0, i + 1), nom = chemin.slice(i + 1);
					const m = root.correspondre(nom, q);
					const ext = nom.includes(".") ? nom.split(".").pop().toLowerCase() : "";
					const code = ["qml", "js", "ts", "py", "rs", "c", "cpp", "h", "go", "sh", "lua", "json", "toml", "conf", "ini"].includes(ext);
					const img = ["png", "jpg", "jpeg", "webp", "gif", "svg"].includes(ext);
					return { type: "fichier", cle: "fichier:" + chemin, titre: nom, dossier, correspondance: m.s > 0 ? m : null, chemin: Quickshell.env("HOME") + "/" + chemin,
						sous: dossier, icone: code ? Icones.code : img ? Icones.image : Icones.notes, score: m.s - chemin.split("/").length };
				}).sort((a, b) => b.score - a.score).slice(0, 12);
			}
		}
	}

	// ---------------------------------------------------------------- calculation
	readonly property var calcul: {
		if (prefixe !== "=" || !termes) return null;
		// The Unicode superscripts come from the `^` dead key: on a Swiss or French keyboard,
		// `^` followed by a digit composes ⁴ instead of letting ^4 through.
		const exposants = "⁰¹²³⁴⁵⁶⁷⁸⁹";
		const expr = termes.replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-").replace(/,/g, ".")
			.replace(/[⁰¹²³⁴⁵⁶⁷⁸⁹]+/g, m => "**" + Array.from(m).map(c => exposants.indexOf(c)).join(""))
			.replace(/\^/g, "**").replace(/(\d+(?:\.\d+)?)%/g, "($1/100)");
		if (!/^[\d\s+\-*/().]+$/.test(expr)) return { ok: false, texte: "expression invalide" };
		try {
			const v = Function(`"use strict"; return (${expr});`)();
			if (typeof v !== "number" || !isFinite(v)) return { ok: false, texte: "résultat indéfini" };
			const r = Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-6 && v !== 0) ? v.toExponential(6) : String(Math.round(v * 1e10) / 1e10);
			return { ok: true, texte: r };
		} catch (e) { return { ok: false, texte: "…" }; }
	}

	// ---------------------------------------------------------------- results
	// a flat list: headers { type: "entete" } plus items; `compte` for the tabs
	readonly property var resultats: {
		const q = termes;
		if (prefixe === "=") return calcul ? [{ type: "calcul", cle: "calcul", titre: termes, sous: calcul.ok ? "entrée copie le résultat" : calcul.texte, icone: Icones.texteLignes, calcul }] : [];
		if (prefixe === ">") return q ? [{ type: "shell", cle: "shell", titre: q, sous: "exécuter dans foot", icone: Icones.terminal }] : [];
		if (prefixe === "?") return q ? [{ type: "web", cle: "web", titre: q, sous: "rechercher sur le web (navigateur par défaut)", icone: Icones.web }] : [];
		if (prefixe === "/") return fichiers;

		const groupes = [];
		const limite = categorie === "tout" ? 4 : 50;
		const aj = (nom, liste) => { if (liste.length) groupes.push({ nom, liste }); };
		if (categorie === "tout" || categorie === "applis") aj("Applications", q ? applis(q) : applis("").slice(0, categorie === "tout" ? 8 : 200));
		if ((categorie === "tout" && q) || categorie === "fenetres") aj("Fenêtres ouvertes", fenetres(q));
		if ((categorie === "tout" && q) || categorie === "fichiers") aj("Fichiers", fichiers);
		if ((categorie === "tout" && q) || categorie === "commandes") aj("Commandes", commandes(q));

		const res = [];
		for (const g of groupes) {
			const l = categorie === "tout" && q ? g.liste.slice(0, limite) : g.liste;
			res.push({ type: "entete", titre: g.nom, compte: g.liste.length });
			for (const r of l) res.push(r);
		}
		return res;
	}
	readonly property var comptes: {
		const q = termes;
		if (prefixe) return {};
		const c = { applis: applis(q).length, fenetres: fenetres(q).length, fichiers: fichiers.length, commandes: q ? commandes(q).length : listeCommandes.length };
		c.tout = q ? c.applis + c.fenetres + c.fichiers + c.commandes : c.applis;
		return c;
	}

	// ---------------------------------------------------------------- running
	// mode: "" normal · "secteur" (in a new sector)
	function executer(r, mode) {
		if (!r || r.type === "entete") return;
		if (mode === "secteur") I3.dispatch(`workspace number ${Sway.secteurLibre()}`);
		switch (r.type) {
		case "appli":
			noter(r.cle);
			if (r.ouvertes.length && mode !== "secteur") Sway.focaliser(r.ouvertes[0].id);
			else Applis.lancerEntree(r.entree);
			break;
		case "action": noter(r.cle); r.action.execute(); break;
		case "fenetre": Sway.focaliser(r.fenetre.id); break;
		case "fichier": noter(r.cle); Quickshell.execDetached(["xdg-open", r.chemin]); break;
		case "commande": noter(r.cle); r.commande.faire(); break;
		case "calcul": if (r.calcul.ok) Quickshell.execDetached(["wl-copy", r.calcul.texte]); break;
		case "shell": Quickshell.execDetached(["foot", "-c", Quickshell.env("HOME") + "/.config/supercalc/foot/foot.ini", "--hold", "sh", "-c", r.titre]); break;
		case "web": Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(r.titre)]); break;
		}
		if (r.type !== "commande" || !["Éteindre", "Redémarrer", "Se déconnecter", "Presse-papiers", "Holomap", "Manuel des raccourcis", "Réglages"].includes(r.titre)) Etat.fermer();
	}
}
