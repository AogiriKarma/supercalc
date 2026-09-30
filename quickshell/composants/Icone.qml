import QtQuick
import QtQuick.Shapes

// A line icon, drawn from an SVG path in a 16×16 viewBox (see theme/Icones.qml).
Item {
	id: root
	property string chemin: ""
	property color couleur: "white"
	property real trait: 1.3
	// Some symbols are filled rather than line art (XANA's sigil, with its hollow rings).
	// The even-odd rule hollows out the inner subpaths.
	property bool remplir: false
	property real taille: 16
	implicitWidth: taille
	implicitHeight: taille

	Shape {
		anchors.fill: parent
		preferredRendererType: Shape.CurveRenderer
		ShapePath {
			strokeColor: root.remplir ? "transparent" : root.couleur
			strokeWidth: root.remplir ? 0 : root.trait
			fillColor: root.remplir ? root.couleur : "transparent"
			fillRule: ShapePath.OddEvenFill
			capStyle: ShapePath.RoundCap
			joinStyle: ShapePath.RoundJoin
			scale: Qt.size(root.taille / 16, root.taille / 16)
			PathSvg { path: root.chemin }
		}
	}
}
