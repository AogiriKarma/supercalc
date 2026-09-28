import QtQuick
import qs.theme

// Bouton-pastille de la barre : fond plein, coin haut-droit coupé, texte en capitales.
Item {
	id: root
	property string texte: ""
	property string prefixe: ""          // ex. numéro de secteur, en mono discret
	property color fond: Theme.bouton
	property color encre: Theme.texteTitre
	property real coupeHD: Theme.biseauPetit
	property real coupeHG: 0
	property real coupeBG: 0
	property bool cliquable: false
	property real padding: 12
	default property alias contenu: rangee.data
	signal clique(var souris)

	implicitHeight: Theme.barreHauteur
	implicitWidth: rangee.implicitWidth + padding * 2

	Chanfrein {
		anchors.fill: parent
		couleur: souris.containsMouse && root.cliquable ? Qt.lighter(root.fond, 1.15) : root.fond
		hd: root.coupeHD; hg: root.coupeHG; bg: root.coupeBG
	}

	Row {
		id: rangee
		anchors.centerIn: parent
		spacing: 8
		Texte {
			visible: root.prefixe !== ""
			text: root.prefixe
			taille: 12
			color: root.encre
			opacity: 0.65
			anchors.verticalCenter: parent.verticalCenter
		}
		Libelle {
			visible: root.texte !== ""
			text: root.texte
			color: root.encre
			anchors.verticalCenter: parent.verticalCenter
		}
	}

	MouseArea {
		id: souris
		anchors.fill: parent
		enabled: root.cliquable
		hoverEnabled: root.cliquable
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		cursorShape: root.cliquable ? Qt.PointingHandCursor : Qt.ArrowCursor
		onClicked: souris => root.clique(souris)
	}
}
