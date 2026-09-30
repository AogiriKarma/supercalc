import QtQuick
import Quickshell
import qs.theme
import qs.composants
import qs.services

// The central clock. Click for the calendar.
Item {
	id: root
	property bool compact: false
	property var ecran: null
	implicitWidth: fond.width
	implicitHeight: Theme.barreHauteur

	SystemClock { id: horloge; precision: SystemClock.Minutes }

	Pastille {
		id: fond
		fond: Etat.panneau === "calendrier" && Etat.ecranCible === root.ecran ? Theme.bouton : Qt.alpha(Theme.cadreInactif, 0.92)
		coupeHG: Theme.biseauPetit
		padding: Theme.dansBarre(14)
		cliquable: true
		onClique: Etat.basculer("calendrier", root.ecran)

		Libelle {
			visible: !root.compact
			text: horloge.date.toLocaleDateString(Qt.locale("fr_FR"), "ddd d MMM").replace(/\./g, "")
			color: Theme.texteAccent
			anchors.verticalCenter: parent.verticalCenter
		}
		Texte {
			text: Qt.formatTime(horloge.date, "hh:mm")
			// the same size as the other modules: the difference showed too much once everything grew
			taille: Theme.dansBarre(13)
			color: "#ffffff"
			font.letterSpacing: 1
			anchors.verticalCenter: parent.verticalCenter
		}
	}
}
