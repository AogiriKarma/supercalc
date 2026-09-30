import QtQuick
import qs.theme

// A drawn keyboard key (manual, help lines): SUPER in amber, the others in blue.
Rectangle {
	id: root
	property string texte: ""
	readonly property bool superTouche: texte === "SUPER"
	// Gunship only has the common letters and digits: symbols fall back to the mono font
	readonly property bool mot: /^[A-Z0-9ÉÈÀ]+$/.test(texte)
	implicitWidth: Math.max(22, libelle.implicitWidth + 14)
	implicitHeight: 22
	width: implicitWidth; height: implicitHeight
	color: superTouche ? Theme.accentSombre : Theme.tuile
	border { width: 1; color: superTouche ? Qt.darker(Theme.accent, 1.5) : "#4b9dbf" }
	Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: parent.border.color }
	Libelle {
		id: libelle
		anchors { centerIn: parent; verticalCenterOffset: -1 }
		text: root.texte
		taille: root.mot ? 9 : 12
		font.family: root.mot ? Theme.policeLibelle : Theme.policeTexte
		font.letterSpacing: root.mot ? 1 : 0
		font.capitalization: Font.MixedCase
		color: root.superTouche ? Theme.accent : Theme.texteTitre
	}
}
