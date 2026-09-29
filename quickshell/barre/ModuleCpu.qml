import QtQuick
import Quickshell
import qs.theme
import qs.composants
import qs.services

// CPU : mini-historique de 8 s + pourcentage. Clic : btop dans foot.
Pastille {
	fond: Qt.alpha(Theme.cadreInactif, 0.92)
	coupeHD: 0
	padding: Theme.dansBarre(10)
	cliquable: true
	onClique: Quickshell.execDetached(["foot", "-T", "btop", "btop"])

	Libelle { text: "CPU"; color: Theme.texteAccent; anchors.verticalCenter: parent.verticalCenter }
	Row {
		spacing: 1
		height: 12
		anchors.verticalCenter: parent.verticalCenter
		Repeater {
			model: Systeme.historiqueCpu
			Rectangle {
				required property var modelData
				width: 3
				height: Math.max(2, modelData * 12)
				anchors.bottom: parent.bottom
				color: modelData > 0.85 ? Theme.xana : Theme.accent
			}
		}
	}
	Texte {
		text: Math.round(Systeme.cpu * 100) + "%"
		taille: Theme.dansBarre(13)
		color: Theme.texteTitre
		width: 34
		horizontalAlignment: Text.AlignRight
		anchors.verticalCenter: parent.verticalCenter
	}
}
