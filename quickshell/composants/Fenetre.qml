import QtQuick
import QtQuick.Effects
import qs.theme

// Le cadre IFSCL commun à toutes les surfaces Quickshell :
// onglets à gauche, titre à droite, carré, corps sombre, bande ||| ▲▼, coins biseautés, halo.
Item {
	id: root
	property string titre: ""
	property string sousTitre: ""           // texte mono discret à gauche du titre (optionnel)
	property string variante: "focus"       // focus | inactif | xana | energie
	property bool bande: true
	property bool halo: true
	property real biseau: Theme.biseau
	default property alias contenu: zone.data
	readonly property alias zoneContenu: zone

	readonly property color cadre: variante === "xana" ? Theme.xanaCadre
		: variante === "inactif" ? Theme.cadreInactif
		: variante === "energie" ? "#e39a2c" : Theme.cadreFocus
	readonly property color fondCorps: variante === "xana" ? Theme.xanaCorps : Theme.corps
	readonly property color encreTitre: variante === "inactif" ? "#bfe3f0" : "#ffffff"
	readonly property color couleurHalo: variante === "xana" ? Theme.xana
		: variante === "energie" ? Theme.ambre : Theme.bordureVive

	Chanfrein {
		id: fond
		anchors.fill: parent
		couleur: root.cadre
		hg: root.biseau
		bd: root.biseau
		layer.enabled: root.halo && Theme.halo > 0
		layer.effect: MultiEffect {
			shadowEnabled: true
			shadowColor: root.couleurHalo
			shadowOpacity: Theme.halo * 0.6
			shadowBlur: 1.0
			blurMax: 24
			shadowHorizontalOffset: 0
			shadowVerticalOffset: 0
		}
	}

	// --- barre de titre ---
	Item {
		id: barreTitre
		anchors { left: parent.left; right: parent.right; top: parent.top }
		height: Theme.titreHauteur
		Row {
			anchors { left: parent.left; leftMargin: root.biseau + 4; verticalCenter: parent.verticalCenter }
			spacing: 4
			Rectangle { width: 20; height: 6; color: Theme.lisere; opacity: 0.85 }
			Rectangle { width: 8; height: 6; color: "transparent"; border.color: Theme.lisere; border.width: 1 }
			Rectangle { width: 4; height: 6; color: Theme.lisere; opacity: 0.5 }
			Texte {
				visible: root.sousTitre !== ""
				text: root.sousTitre
				taille: 12
				color: Theme.lisere
				leftPadding: 8
				anchors.verticalCenter: parent.verticalCenter
			}
		}
		Row {
			anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
			spacing: 6
			Libelle { text: root.titre; color: root.encreTitre; anchors.verticalCenter: parent.verticalCenter }
			Rectangle { width: 9; height: 9; color: Theme.lisere; anchors.verticalCenter: parent.verticalCenter }
		}
	}

	// --- corps ---
	Chanfrein {
		id: corps
		x: Theme.epaisseurCadre
		y: barreTitre.height
		width: parent.width - Theme.epaisseurCadre * 2
		height: parent.height - barreTitre.height - (root.bande ? Theme.bandeHauteur : Theme.epaisseurCadre)
		couleur: Qt.alpha(root.fondCorps, Theme.opacitePanneau)
		bd: root.bande ? 0 : Math.max(0, root.biseau - Theme.epaisseurCadre)
	}
	Item {
		id: zone
		anchors.fill: corps
	}

	// --- bande du bas ---
	Item {
		visible: root.bande
		anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
		height: Theme.bandeHauteur
		Texte { text: "|||"; taille: 9; color: Theme.lisere; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } }
		Texte { text: "▲ ▼"; taille: 9; color: Theme.lisere; anchors { right: parent.right; rightMargin: root.biseau + 8; verticalCenter: parent.verticalCenter } }
	}
}
