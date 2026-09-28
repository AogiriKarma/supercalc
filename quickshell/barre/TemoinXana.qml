import QtQuick
import qs.theme
import qs.composants
import qs.services

// Sigle de XANA : ouvre le panneau de contrôle, qui porte le journal des notifications.
// Pas de signal d'alerte ici — les secteurs passent déjà en rouge quand une fenêtre
// réclame l'attention, un second témoin pour la même chose n'apprenait rien.
Pastille {
	id: root
	readonly property bool ouvert: Etat.panneau === "panneau"
	// l'écran qui porte cette barre : le panneau s'ouvre là où on a cliqué, pas sur le principal
	property var ecran: null

	fond: ouvert ? Theme.lisere : Qt.alpha(Theme.cadreInactif, 0.92)
	encre: ouvert ? Theme.encre : "#6f9fb5"
	coupeHD: 0
	coupeHG: Theme.biseauPetit
	padding: 10
	cliquable: true
	onClique: Etat.basculer("panneau", root.ecran)

	// 20 px : en dessous, l'anneau intérieur et le point du sigle se confondent en une tache.
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
		taille: 13
		color: root.ouvert ? Theme.encre : Theme.accent
		anchors.verticalCenter: parent.verticalCenter
	}
}
