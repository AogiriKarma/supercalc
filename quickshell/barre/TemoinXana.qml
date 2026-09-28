import QtQuick
import Quickshell.I3
import qs.theme
import qs.composants
import qs.services

// Témoin XANA : rouge et pulsant quand une fenêtre réclame l'attention. Clic : y aller.
Pastille {
	id: root
	readonly property bool actif: Sway.secteurUrgent !== null
	fond: actif ? Theme.xana : Qt.alpha(Theme.cadreInactif, 0.92)
	encre: actif ? "#ffffff" : "#6f9fb5"
	coupeHD: 0
	coupeHG: Theme.biseauPetit
	padding: 14
	texte: "XANA"
	cliquable: actif
	onClique: I3.dispatch("[urgent=latest] focus")

	Rectangle { width: 6; height: 6; color: root.encre; anchors.verticalCenter: parent.verticalCenter }

	SequentialAnimation on opacity {
		running: root.actif && Theme.animations
		loops: Animation.Infinite
		onRunningChanged: if (!running) root.opacity = 1
		NumberAnimation { to: 0.45; duration: 600; easing.type: Easing.InOutSine }
		NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
	}
}
