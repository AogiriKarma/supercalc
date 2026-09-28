import QtQuick
import qs.theme

// Réglage en segments (volume, micro, luminosité) : clic ou glisser pour régler,
// molette par pas de 5 %, clic sur l'icône pour couper.
Item {
	id: root
	property string nom: ""
	property string icone: ""
	property real valeur: 0
	property bool coupe: false
	property bool dispo: true
	signal regle(real v)
	signal iconeClique()

	implicitHeight: 24
	opacity: dispo ? 1 : 0.45

	Rectangle {
		id: boutonIcone
		width: 24; height: 24
		color: zoneIcone.containsMouse ? Theme.tuile : "transparent"
		Icone { anchors.centerIn: parent; chemin: root.icone; taille: 16; couleur: root.coupe ? Theme.xanaTexte : Theme.texteAccent }
		MouseArea { id: zoneIcone; anchors.fill: parent; enabled: root.dispo; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.iconeClique() }
	}
	Libelle {
		id: libelle
		anchors { left: boutonIcone.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
		width: 62
		text: root.nom
		taille: 10
		color: Theme.texteTitre
	}
	Item {
		id: piste
		anchors { left: libelle.right; right: chiffre.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
		height: 12
		Segments {
			anchors.fill: parent
			nombre: 20
			hauteur: 12
			valeur: root.dispo ? Math.min(1, root.valeur) : 0
			couleur: root.coupe ? Qt.alpha(Theme.xana, 0.6) : Theme.accent
			couleurVide: root.coupe ? "#2a0f14" : Theme.accentSombre
		}
		MouseArea {
			anchors { fill: parent; margins: -6 }
			enabled: root.dispo
			cursorShape: Qt.PointingHandCursor
			function depuis(x) { return Math.max(0, Math.min(1, (x - 6) / piste.width)); }
			onPressed: m => root.regle(Math.ceil(depuis(m.x) * 20) / 20)
			onPositionChanged: m => { if (pressed) root.regle(Math.ceil(depuis(m.x) * 20) / 20); }
			onWheel: w => root.regle(Math.max(0, Math.min(1, Math.round((root.valeur + (w.angleDelta.y > 0 ? 0.05 : -0.05)) * 20) / 20)))
		}
	}
	Texte {
		id: chiffre
		anchors { right: parent.right; verticalCenter: parent.verticalCenter }
		width: 34
		horizontalAlignment: Text.AlignRight
		text: !root.dispo ? "—" : root.coupe ? "OFF" : String(Math.round(root.valeur * 100))
		taille: 13
		color: root.coupe ? Theme.xanaTexte : Theme.texteTitre
	}
}
