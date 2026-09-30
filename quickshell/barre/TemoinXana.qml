import QtQuick
import qs.theme
import qs.composants
import qs.services

// XANA's sigil: opens the control panel, which carries the notification log.
// No alert signal here — the sectors already turn red when a window asks for attention, and a
// second indicator for the same thing taught nothing.
Pastille {
	id: root
	readonly property bool ouvert: Etat.panneau === "panneau"
	// the screen this bar belongs to: the panel opens where the click happened, not on the main one
	property var ecran: null

	fond: ouvert ? Theme.lisere : Qt.alpha(Theme.cadreInactif, 0.92)
	encre: ouvert ? Theme.encre : "#6f9fb5"
	coupeHD: 0
	coupeHG: Theme.biseauPetit
	padding: Theme.dansBarre(10)
	cliquable: true
	onClique: Etat.basculer("panneau", root.ecran)

	// 20 px: below that, the sigil's inner ring and dot merge into a blob.
	Icone {
		chemin: Icones.xana
		remplir: true
		couleur: root.encre
		taille: 20
		anchors.verticalCenter: parent.verticalCenter
	}
	Texte {
		visible: Notifs.nonLues > 0
		text: String(Notifs.nonLues)
		taille: Theme.dansBarre(13)
		color: root.ouvert ? Theme.encre : Theme.accent
		anchors.verticalCenter: parent.verticalCenter
	}
}
