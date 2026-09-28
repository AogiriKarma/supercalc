pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3

// État d'interface partagé : quel panneau est ouvert, quel écran est principal.
Singleton {
	id: root

	// Écran principal (zone système, journal, dock, lanceur) :
	// 1. SUPERCALC_ECRAN_PRINCIPAL s'il est défini et branché ;
	// 2. sinon l'écran interne d'un portable (eDP, LVDS, DSI) ;
	// 3. sinon l'écran le plus à gauche (puis le plus haut).
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

	// Écran qui a le focus sway : c'est là que s'ouvrent OSD, bulles, lanceur et panneaux.
	readonly property var ecranActif: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) ?? ecranPrincipalObjet

	// un seul panneau à la fois : "" | lanceur | panneau | holomap | manuel | power | reglages | presse-papiers
	property string panneau: ""

	// conservé à travers les rechargements de la config : modifier un fichier ne déverrouille jamais
	property alias verrouille: persistant.verrouille
	PersistentProperties {
		id: persistant
		reloadableId: "supercalc-etat"
		property bool verrouille: false
	}
	function verrouiller() { panneau = ""; verrouille = true; }

	// écran où s'ouvre le panneau : celui du clic dans la barre s'il y en a un, sinon l'écran actif
	property var ecranDemande: null
	readonly property var ecranCible: ecranDemande ?? ecranActif

	function basculer(nom, ecran) { ecranDemande = ecran ?? null; panneau = (panneau === nom) ? "" : nom; }
	function ouvrir(nom, ecran) { ecranDemande = ecran ?? null; panneau = nom; }
	function fermer() { panneau = ""; }
}
