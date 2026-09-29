import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.I3
import qs.theme
import qs.composants
import qs.services

// Une barre par écran. Aucune dimension d'écran supposée : largeur = celle de l'écran, hauteur fixe.
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

			// Les deux barres sont identiques : chaque écran a ses mesures et son accès au
			// panneau, plutôt qu'un écran complet et un écran diminué.
			ModuleCpu {}
			ModuleClavier {}
			ModuleEnergie {}
			TemoinXana { ecran: barre.modelData }
		}
	}
}
