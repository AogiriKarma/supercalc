import QtQuick
import QtQuick.Shapes

// Icône au trait, dessinée depuis un chemin SVG en viewBox 16×16 (voir theme/Icones.qml).
Item {
	id: root
	property string chemin: ""
	property color couleur: "white"
	property real trait: 1.3
	property real taille: 16
	implicitWidth: taille
	implicitHeight: taille

	Shape {
		anchors.fill: parent
		preferredRendererType: Shape.CurveRenderer
		ShapePath {
			strokeColor: root.couleur
			strokeWidth: root.trait
			fillColor: "transparent"
			capStyle: ShapePath.RoundCap
			joinStyle: ShapePath.RoundJoin
			scale: Qt.size(root.taille / 16, root.taille / 16)
			PathSvg { path: root.chemin }
		}
	}
}
