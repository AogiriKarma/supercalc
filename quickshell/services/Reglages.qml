pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent settings (the Settings window, or edited by hand):
// ~/.local/state/quickshell/by-shell/<id>/reglages.json — reread live when it changes on disk.
Singleton {
	id: root
	property alias accent: adaptateur.accent
	property alias halo: adaptateur.halo
	property alias opacite: adaptateur.opacite
	property alias animations: adaptateur.animations
	property alias sequenceTransfert: adaptateur.sequenceTransfert
	property alias dock: adaptateur.dock
	property alias dockAffiche: adaptateur.dockAffiche
	property alias ecranPrincipal: adaptateur.ecranPrincipal
	property alias modeJeu: adaptateur.modeJeu
	property alias biseau: adaptateur.biseau

	// the original values (the settings' `default` button)
	function parDefaut() {
		accent = "ambre"; dockAffiche = true; halo = 0.6; opacite = 0.96; animations = true; sequenceTransfert = true; biseau = 14; modeJeu = false;
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
			property bool dockAffiche: true
			property string ecranPrincipal: ""
			property bool modeJeu: false
			property int biseau: 14
		}
	}
}
