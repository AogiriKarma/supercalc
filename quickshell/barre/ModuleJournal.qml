import QtQuick
import qs.theme
import qs.composants
import qs.services

// Cloche : nombre de notifications non lues. Clic : panneau de contrôle.
Pastille {
	fond: Etat.panneau === "panneau" ? Theme.lisere : Qt.alpha(Theme.cadreInactif, 0.92)
	encre: Etat.panneau === "panneau" ? Theme.encre : Theme.lisere
	coupeHD: 0
	padding: 10
	cliquable: true
	onClique: Etat.basculer("panneau", Etat.ecranPrincipalObjet)

	Icone { chemin: Icones.cloche; couleur: parent.parent.encre; taille: 14; anchors.verticalCenter: parent.verticalCenter }
	Texte {
		visible: Notifs.nonLues > 0
		text: String(Notifs.nonLues)
		taille: 13
		color: Theme.accent
		anchors.verticalCenter: parent.verticalCenter
	}
}
