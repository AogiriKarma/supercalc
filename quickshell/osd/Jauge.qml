import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.composants
import qs.services

// Jauge OSD en bas de l'écran actif, au-dessus du dock.
PanelWindow {
	id: fenetre
	screen: Etat.ecranActif
	visible: Osd.visible || fondu.running
	anchors.bottom: true
	margins.bottom: 6 + 46 + 18
	exclusionMode: ExclusionMode.Ignore
	implicitWidth: 420
	implicitHeight: 64
	color: "transparent"
	WlrLayershell.namespace: "supercalc-osd"
	WlrLayershell.layer: WlrLayer.Overlay
	mask: Region {}   // ne capte pas la souris

	readonly property color cadre: Osd.alerte ? Theme.xanaCadre : Theme.cadreFocus
	readonly property color encre: Osd.alerte ? Theme.xanaTexte : Theme.texteTitre

	Item {
		id: contenu
		width: 380; height: 44
		anchors.centerIn: parent
		opacity: Osd.visible ? 1 : 0
		scale: Osd.visible ? 1 : 0.96
		Behavior on opacity { NumberAnimation { id: fondu; duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }
		Behavior on scale { NumberAnimation { duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }

		Chanfrein {
			anchors.fill: parent
			couleur: fenetre.cadre
			hg: 10; bd: 10
		}
		Chanfrein {
			anchors { fill: parent; margins: 2 }
			couleur: Qt.alpha(Osd.alerte ? Theme.xanaCorps : Theme.corps, Theme.opacitePanneau)
			hg: 9; bd: 9
		}
		Row {
			anchors { fill: parent; leftMargin: 8; rightMargin: 14 }
			spacing: 12
			Rectangle {
				width: 30; height: 30
				anchors.verticalCenter: parent.verticalCenter
				color: Osd.alerte ? "#2a0f14" : Theme.tuile
				Icone { anchors.centerIn: parent; chemin: Osd.icone; taille: 16; couleur: Osd.alerte ? Theme.xanaTexte : Theme.texteAccent }
			}
			Libelle {
				width: 64
				anchors.verticalCenter: parent.verticalCenter
				text: Osd.nom
				color: fenetre.encre
			}
			Segments {
				width: parent.width - 30 - 64 - 44 - parent.spacing * 3
				anchors.verticalCenter: parent.verticalCenter
				nombre: 20
				valeur: Osd.nom === "clavier" ? 1 : Osd.valeur
				hauteur: 12
				couleur: Osd.alerte ? Theme.xana : Osd.nom === "clavier" ? "#123f52" : Theme.accent
				couleurVide: Osd.alerte ? "#2a0f14" : Theme.accentSombre
			}
			Texte {
				width: 44
				horizontalAlignment: Text.AlignRight
				anchors.verticalCenter: parent.verticalCenter
				text: Osd.texte
				taille: 15
				color: fenetre.encre
			}
		}
	}
}
