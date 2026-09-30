pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme

// Applications: pinned (settings) plus open ones (Wayland windows), line icon chosen by category.
Singleton {
	id: root

	function entree(id) {
		if (!id) return null;
		return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
	}

	function icone(e, appId) {
		const c = e ? e.categories : [];
		const id = (appId || (e ? e.id : "")).toLowerCase();
		const a = x => c.includes(x);
		if (a("TerminalEmulator") || id.includes("foot") || id.includes("term")) return Icones.terminal;
		if (a("WebBrowser")) return Icones.web;
		if (a("IDE") || a("TextEditor") || a("Development")) return Icones.code;
		if (a("FileManager")) return Icones.fichiers;
		if (a("InstantMessaging") || a("Chat")) return Icones.chat;
		if (a("Game")) return Icones.jeu;
		if (a("Audio") && a("Player")) return Icones.musique;
		if (a("Video") || a("AudioVideo")) return Icones.lecture;
		if (a("Office")) return Icones.notes;
		if (a("Settings") || a("System")) return Icones.reglages;
		return Icones.secteur;
	}

	// open windows grouped by appId
	readonly property var ouvertes: {
		const vus = {};
		for (const t of ToplevelManager.toplevels.values) {
			if (!t.appId) continue;
			(vus[t.appId] = vus[t.appId] ?? []).push(t);
		}
		return vus;
	}

	// the dock's list: pinned first, then the other open applications
	readonly property var dock: {
		const res = [];
		const pris = new Set();
		for (const id of Reglages.dock) {
			const e = entree(id);
			const cle = e ? (e.startupClass || e.id) : id;
			const fen = ouvertes[id] ?? ouvertes[cle] ?? [];
			res.push({ id, nom: e ? e.name : id, entree: e, fenetres: fen, epinglee: true, icone: icone(e, id) });
			pris.add(id); pris.add(cle);
		}
		for (const appId of Object.keys(ouvertes)) {
			if (pris.has(appId)) continue;
			const e = entree(appId);
			res.push({ id: appId, nom: e ? e.name : appId, entree: e, fenetres: ouvertes[appId], epinglee: false, icone: icone(e, appId) });
		}
		return res;
	}

	// launches a .desktop entry; Terminal=true -> inside foot with the supercalc theme
	function lancerEntree(e) {
		if (!e) return;
		if (e.runInTerminal) Quickshell.execDetached({
			command: ["foot", "-c", Quickshell.env("HOME") + "/.config/supercalc/foot/foot.ini"].concat(e.command),
			workingDirectory: e.workingDirectory || Quickshell.env("HOME")
		});
		else e.execute();
	}

	function lancer(item) {
		if (item.fenetres.length) item.fenetres[0].activate();
		else if (item.entree) { Lanceur.noter(item.entree.id); lancerEntree(item.entree); }
		else Quickshell.execDetached([item.id]);
	}
}
