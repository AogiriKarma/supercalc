import QtQuick
import qs.theme
import qs.composants
import qs.services

// Life points: the battery in 8 segments. Amber below 25 %, red and blinking below 15 %.
// Hidden on a machine without a battery.
Pastille {
	id: root
	visible: Systeme.aBatterie
	readonly property real n: Systeme.niveau
	readonly property color teinte: n < 0.15 ? Theme.xana : n < 0.25 ? Theme.ambre : Theme.energie
	fond: n < 0.15 && !Systeme.enCharge ? "#3a1418" : Qt.alpha(Theme.cadreInactif, 0.92)
	coupeHD: 0
	padding: Theme.dansBarre(10)

	Libelle { text: "PV"; color: Theme.texteAccent; anchors.verticalCenter: parent.verticalCenter }
	Row {
		spacing: 2
		anchors.verticalCenter: parent.verticalCenter
		Repeater {
			model: 8
			Rectangle {
				required property int index
				width: 5; height: 11
				color: index < Math.ceil(root.n * 8) ? root.teinte : Theme.pointEteint
			}
		}
		SequentialAnimation on opacity {
			running: root.n < 0.15 && !Systeme.enCharge
			loops: Animation.Infinite
			NumberAnimation { to: 0.35; duration: 500 }
			NumberAnimation { to: 1; duration: 500 }
		}
	}
	Texte {
		text: Systeme.enCharge ? "↑" + Math.round(root.n * 100) : String(Math.round(root.n * 100)).padStart(2, "0")
		taille: Theme.dansBarre(13)
		color: root.n < 0.15 ? Theme.xanaTexte : Theme.texteTitre
		anchors.verticalCenter: parent.verticalCenter
	}
}
