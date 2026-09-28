import QtQuick
import Quickshell
import qs.theme

// Pluie de caractères dessinée par le GPU (matrice.frag).
//
// Contrairement à la version Canvas, rien n'est peint par le processeur et rien n'est
// conservé d'une image à l'autre : chaque fragment recalcule son état à partir du temps.
// Le coût cesse donc de suivre la surface, et la densité devient gratuite.
Item {
	id: racine

	property real cellule: 16          // côté d'un glyphe, en pixels
	property real longueur: 18         // longueur d'une traînée, en cellules
	property real fondMini: 0.95       // profondeur d'arrêt minimale des colonnes
	property int imagesParSeconde: 20
	property color couleurTrainee: Theme.accent
	property color couleurTete: Theme.lisere

	// la planche de glyphes : un shader ne sait pas dessiner du texte
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

		// Le temps est la seule chose qui bouge ; tout le reste en découle. Il avance par
		// paliers plutôt qu'en continu : une animation fluide ferait redessiner la surface
		// soixante fois par seconde, et c'est cette recomposition qui coûte — pas le calcul
		// du shader, qui est gratuit.
		Timer {
			interval: 1000 / racine.imagesParSeconde
			running: Theme.animations && racine.visible
			repeat: true
			onTriggered: parent.temps += 1.0 / racine.imagesParSeconde
		}
	}
}
