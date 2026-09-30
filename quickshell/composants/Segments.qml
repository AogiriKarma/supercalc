import QtQuick
import qs.theme

// A segmented gauge (volume, brightness, memory…). `valeur` between 0 and 1.
Row {
	id: root
	property int nombre: 20
	property real valeur: 0.5
	property color couleur: Theme.accent
	property color couleurVide: Theme.accentSombre
	property real hauteur: 12
	spacing: 2

	Repeater {
		model: root.nombre
		Rectangle {
			required property int index
			width: (root.width - root.spacing * (root.nombre - 1)) / root.nombre
			height: root.hauteur
			color: index < Math.round(root.valeur * root.nombre) ? root.couleur : root.couleurVide
			Behavior on color { ColorAnimation { duration: Theme.dureeCourte } }
		}
	}
}
