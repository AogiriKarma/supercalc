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

	// L'écran « principal » porte la zone système et le journal ; les autres n'affichent que leurs secteurs.
	readonly property bool principal: Etat.nomPrincipal === modelData.name

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
				padding: 9
				onClique: Etat.basculer("lanceur", barre.modelData)
				Icone { chemin: Icones.secteur; couleur: Theme.lisere; taille: 16; anchors.verticalCenter: parent.verticalCenter }
			}

			Secteurs { ecran: barre.modelData.name }
		}

		Horloge {
			anchors.centerIn: parent
			ecran: barre.modelData
			compact: !barre.principal
		}

		Row {
			anchors { right: parent.right; verticalCenter: parent.verticalCenter }
			spacing: 6
			layoutDirection: Qt.LeftToRight

			Loader { active: barre.principal; sourceComponent: Component { ModuleCpu {} } }
			Loader { active: barre.principal; sourceComponent: Component { ModuleClavier {} } }
			Loader { active: barre.principal; sourceComponent: Component { ModuleJournal {} } }
			ModuleEnergie {}
			TemoinXana {}
		}
	}
}
