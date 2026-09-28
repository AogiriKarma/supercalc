pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Réglages persistants (appli Réglages, ou à la main) :
// ~/.local/state/quickshell/by-shell/<id>/reglages.json — relu à chaud s'il change sur le disque.
Singleton {
	id: root
	property alias accent: adaptateur.accent
	property alias halo: adaptateur.halo
	property alias opacite: adaptateur.opacite
	property alias animations: adaptateur.animations
	property alias sequenceTransfert: adaptateur.sequenceTransfert
	property alias dock: adaptateur.dock
	property alias ecranPrincipal: adaptateur.ecranPrincipal
	property alias modeJeu: adaptateur.modeJeu
	property alias biseau: adaptateur.biseau

	// valeurs d'origine (bouton « par défaut » des réglages)
	function parDefaut() {
		accent = "ambre"; halo = 0.6; opacite = 0.96; animations = true; sequenceTransfert = true; biseau = 14; modeJeu = false;
	}

	FileView {
		path: Quickshell.statePath("reglages.json")
		watchChanges: true
		onFileChanged: reload()
		onAdapterUpdated: writeAdapter()
		onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

		JsonAdapter {
			id: adaptateur
			property string accent: "ambre"
			property real halo: 0.6
			property real opacite: 0.96
			property bool animations: true
			property bool sequenceTransfert: true
			property list<string> dock: ["foot"]
			property string ecranPrincipal: ""
			property bool modeJeu: false
			property int biseau: 14
		}
	}
}
