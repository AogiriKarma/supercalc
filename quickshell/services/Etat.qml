pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3

// Shared interface state: which panel is open, which screen is the main one.
Singleton {
	id: root

	// Main screen (system area, log, dock, launcher):
	// 1. SUPERCALC_ECRAN_PRINCIPAL if it is set and plugged in;
	// 2. otherwise a laptop's internal panel (eDP, LVDS, DSI);
	// 3. otherwise the leftmost screen (then the topmost).
	readonly property string ecranPrincipal: Quickshell.env("SUPERCALC_ECRAN_PRINCIPAL") ?? Reglages.ecranPrincipal
	readonly property string nomPrincipal: {
		const ecrans = Quickshell.screens;
		if (!ecrans.length) return "";
		if (ecranPrincipal && ecrans.some(s => s.name === ecranPrincipal)) return ecranPrincipal;
		const interne = ecrans.find(s => /^(eDP|LVDS|DSI)/.test(s.name));
		if (interne) return interne.name;
		return ecrans.slice().sort((a, b) => (a.x - b.x) || (a.y - b.y))[0].name;
	}
	readonly property var ecranPrincipalObjet: Quickshell.screens.find(s => s.name === nomPrincipal) ?? null

	// The screen sway has focused: that is where the OSD, bubbles, launcher and panels open.
	readonly property var ecranActif: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) ?? ecranPrincipalObjet

	// one panel at a time: "" | lanceur | panneau | holomap | manuel | power | reglages | presse-papiers
	property string panneau: ""

	// preserved across config reloads: editing a file never unlocks the session
	property alias verrouille: persistant.verrouille
	PersistentProperties {
		id: persistant
		reloadableId: "supercalc-etat"
		property bool verrouille: false
	}
	function verrouiller() { panneau = ""; verrouille = true; }

	// the screen a panel opens on: the one clicked in the bar if any, otherwise the active screen
	property var ecranDemande: null
	readonly property var ecranCible: ecranDemande ?? ecranActif

	// the section requested when opening the settings: lets anywhere else jump straight to it,
	// for example a right click on a control panel tile
	property string sectionReglages: ""
	function ouvrirReglages(section, ecran) { sectionReglages = section; ouvrir("reglages", ecran); }

	function basculer(nom, ecran) { ecranDemande = ecran ?? null; panneau = (panneau === nom) ? "" : nom; }
	function ouvrir(nom, ecran) { ecranDemande = ecran ?? null; panneau = nom; }
	function fermer() { panneau = ""; }
}
