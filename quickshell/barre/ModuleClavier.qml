import QtQuick
import Quickshell.I3
import qs.theme
import qs.composants
import qs.services

// Disposition clavier active. Clic : disposition suivante.
Pastille {
	visible: Sway.dispositionCourte !== ""
	fond: Qt.alpha(Theme.cadreInactif, 0.92)
	coupeHD: 0
	padding: 10
	texte: Sway.dispositionCourte
	cliquable: true
	onClique: I3.dispatch("input type:keyboard xkb_switch_layout next")
}
