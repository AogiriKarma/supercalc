import QtQuick
import Quickshell
import qs.theme

// Character rain drawn by the GPU (matrice.frag).
//
// Unlike the Canvas version, nothing is painted by the CPU and nothing is kept from one frame to
// the next: each fragment recomputes its state from the time. The cost therefore stops following
// the surface, and density becomes free.
Item {
	id: racine

	property real cellule: 16          // side of a glyph, in pixels
	property real longueur: 18         // length of a trail, in cells
	property real fondMini: 0.95       // minimum stopping depth of the columns
	property int imagesParSeconde: 20
	property color couleurTrainee: Theme.accent
	property color couleurTete: Theme.lisere

	// the glyph sheet: a shader cannot draw text
	Image {
		id: planche
		source: Quickshell.shellPath("fond/atlas.png")
		visible: false
		smooth: true
	}

	ShaderEffect {
		anchors.fill: parent
		fragmentShader: Qt.resolvedUrl("matrice.frag.qsb")
		blending: true

		property vector2d taille: Qt.vector2d(width, height)
		property real temps: 0
		property real cellule: racine.cellule
		property real longueur: racine.longueur
		property real fondMini: racine.fondMini
		property color couleurTrainee: racine.couleurTrainee
		property color couleurTete: racine.couleurTete
		property variant atlas: planche

		// Time is the only thing that moves; everything else follows from it. It advances in steps
		// rather than continuously: a smooth animation would redraw the surface sixty times a
		// second, and it is that recomposition which costs — not the shader's own work, which is
		// free.
		Timer {
			interval: 1000 / racine.imagesParSeconde
			running: Theme.animations && racine.visible
			repeat: true
			onTriggered: parent.temps += 1.0 / racine.imagesParSeconde
		}
	}
}
