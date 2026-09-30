import QtQuick
import Quickshell.I3
import qs.theme
import qs.composants
import qs.services

// The active keyboard layout. Click for the next one.
Pastille {
	visible: Sway.dispositionCourte !== ""
	fond: Qt.alpha(Theme.cadreInactif, 0.92)
	coupeHD: 0
	padding: Theme.dansBarre(10)
	texte: Sway.dispositionCourte
	cliquable: true
	onClique: I3.dispatch("input type:keyboard xkb_switch_layout next")
}
