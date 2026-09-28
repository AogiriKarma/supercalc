import QtQuick
import qs.theme

// Texte courant en Share Tech Mono.
Text {
	property real taille: 13
	font.family: Theme.policeTexte
	font.pixelSize: taille
	color: Theme.texte
	renderType: Text.NativeRendering
	verticalAlignment: Text.AlignVCenter
	elide: Text.ElideRight
}
