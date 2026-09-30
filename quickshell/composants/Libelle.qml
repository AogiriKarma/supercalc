import QtQuick
import qs.theme

// Text in Gunship Condensed, spaced capitals: labels, frame titles, buttons.
Text {
	property real taille: 11
	font.family: Theme.policeLibelle
	font.pixelSize: taille
	font.letterSpacing: taille * 0.17
	font.capitalization: Font.AllUppercase
	color: Theme.texteTitre
	renderType: Text.NativeRendering
	verticalAlignment: Text.AlignVCenter
}
