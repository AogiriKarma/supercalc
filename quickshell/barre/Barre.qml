import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.I3
import qs.theme
import qs.composants
import qs.services

// One bar per screen. No screen dimension is assumed: width = the screen's, height fixed.
PanelWindow {
	id: barre
	required property var modelData
	screen: modelData

	anchors { top: true; left: true; right: true }
	implicitHeight: Theme.barreHauteur + 8 + 6
	exclusiveZone: Theme.barreHauteur + 8
	color: "transparent"
	WlrLayershell.namespace: "supercalc-barre"
	WlrLayershell.layer: WlrLayer.Top

	Item {
		anchors { fill: parent; leftMargin: Theme.marge; rightMargin: Theme.marge; topMargin: 8; bottomMargin: 6 }

		Row {
			id: gauche
			anchors { left: parent.left; verticalCenter: parent.verticalCenter }
			spacing: 6

			Pastille {
				cliquable: true
				padding: Theme.dansBarre(7)
				onClique: Etat.basculer("lanceur", barre.modelData)
				Icone { chemin: Icones.xana; remplir: true; couleur: Theme.lisere; taille: 20; anchors.verticalCenter: parent.verticalCenter }
			}

			Secteurs { ecran: barre.modelData.name }
		}

		Horloge {
			anchors.centerIn: parent
			ecran: barre.modelData
		}

		Row {
			anchors { right: parent.right; verticalCenter: parent.verticalCenter }
			spacing: 6
			layoutDirection: Qt.LeftToRight

			// Both bars are identical: every screen gets its own readings and its own way into the
			// panel, rather than one complete screen and one cut-down screen.
			ModuleCpu {}
			ModuleClavier {}
			ModuleEnergie {}
			TemoinXana { ecran: barre.modelData }
		}
	}
}
