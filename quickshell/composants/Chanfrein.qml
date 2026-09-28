import QtQuick
import QtQuick.Shapes

// Polygone rectangulaire aux coins coupés. Sert de fond aux cadres, pastilles et boutons.
Shape {
	id: root
	property color couleur: "transparent"
	property color bordure: "transparent"
	property real bordureLargeur: 0
	// taille de coupe par coin : haut-gauche, haut-droit, bas-droit, bas-gauche
	property real hg: 0
	property real hd: 0
	property real bd: 0
	property real bg: 0

	preferredRendererType: Shape.CurveRenderer
	antialiasing: true

	ShapePath {
		id: chemin
		readonly property real o: root.bordureLargeur / 2
		fillColor: root.couleur
		strokeColor: root.bordureLargeur > 0 ? root.bordure : "transparent"
		strokeWidth: root.bordureLargeur > 0 ? root.bordureLargeur : -1
		joinStyle: ShapePath.MiterJoin
		startX: root.hg + chemin.o
		startY: chemin.o
		PathLine { x: root.width - root.hd - chemin.o; y: chemin.o }
		PathLine { x: root.width - chemin.o; y: root.hd + chemin.o }
		PathLine { x: root.width - chemin.o; y: root.height - root.bd - chemin.o }
		PathLine { x: root.width - root.bd - chemin.o; y: root.height - chemin.o }
		PathLine { x: root.bg + chemin.o; y: root.height - chemin.o }
		PathLine { x: chemin.o; y: root.height - root.bg - chemin.o }
		PathLine { x: chemin.o; y: root.hg + chemin.o }
		PathLine { x: root.hg + chemin.o; y: chemin.o }
	}
}
