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

	// --- dépliage à l'ouverture ---
	// Comme dans IFSCL : la barre de titre et la bande du bas apparaissent collées, puis le
	// corps s'ouvre entre les deux en les écartant. Les panneaux gardent leur propre fondu ;
	// ici on ne joue que sur la hauteur, pour ne pas se battre avec leur opacité.
	property bool ouvre: true               // à lier au booléen d'ouverture du panneau
	property real deploiement: 1            // 0 = replié sur ses deux bandeaux, 1 = ouvert
	readonly property real hauteurBas: root.bande ? Theme.bandeHauteur : Theme.epaisseurCadre
	readonly property real hauteurCorps: Math.max(0, height - barreTitre.height - hauteurBas)

	Component.onCompleted: {
		if (animeALaCreation && ouvre && Theme.animations) { opacity = 0; deploiement = 0; ouverture.start(); }
		else { opacity = ouvre ? 1 : 0; deploiement = ouvre ? 1 : 0; }
	}
	onOuvreChanged: {
		ouverture.stop();
		fermeture.stop();
		if (!Theme.animations) { opacity = ouvre ? 1 : 0; deploiement = ouvre ? 1 : 0; return; }
		if (ouvre) { opacity = 0; deploiement = 0; ouverture.start(); }
		else fermeture.start();
	}
	// Durées propres au dépliage, volontairement plus longues que dureeCourte/dureeMoyenne :
	// c'est un effet qu'on veut voir, pas une transition qu'on veut escamoter.
	// Même durée dans les deux sens, et les deux temps s'enchaînent au lieu de se superposer :
	// à l'ouverture les deux bandeaux apparaissent d'abord, puis le corps s'ouvre ; à la
	// fermeture le corps se referme d'abord, puis les bandeaux s'effacent.
	readonly property int dureeFondu: Theme.animations ? 200 : 0
	readonly property int dureeDepliage: Theme.animations ? 420 : 0
	readonly property bool anime: ouverture.running || fermeture.running
	property int retard: 0                  // échelonne plusieurs cadres ouverts ensemble
	// Pour les cadres créés déjà ouverts (une bulle de notification qui arrive). Laissé à
	// false par défaut : la scène de transfert calcule tout depuis son horloge pour que
	// « figer » reste reproductible, une animation propre casserait ça.
	property bool animeALaCreation: false

	SequentialAnimation {
		id: ouverture
		PauseAnimation { duration: root.retard }
		NumberAnimation { target: root; property: "opacity"; to: 1; duration: root.dureeFondu }
		NumberAnimation {
			target: root; property: "deploiement"
			to: 1; duration: root.dureeDepliage; easing.type: Easing.OutCubic
		}
	}
	SequentialAnimation {
		id: fermeture
		NumberAnimation {
			target: root; property: "deploiement"
			to: 0; duration: root.dureeDepliage; easing.type: Easing.InCubic
		}
		NumberAnimation { target: root; property: "opacity"; to: 0; duration: root.dureeFondu }
	}

	Chanfrein {
		id: fond
		width: parent.width
		height: barreTitre.height + corps.height + root.hauteurBas
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
		height: root.hauteurCorps * root.deploiement
		couleur: Qt.alpha(root.fondCorps, Theme.opacitePanneau)
		bd: root.bande ? 0 : Math.max(0, root.biseau - Theme.epaisseurCadre)
	}
	Item {
		id: zone
		anchors.fill: corps
		// pendant le dépliage le corps est plus court que son contenu : sans rognage,
		// celui-ci déborderait du cadre au lieu d'être découvert progressivement.
		clip: true
	}

	// --- bande du bas ---
	Item {
		visible: root.bande
		y: barreTitre.height + corps.height
		width: parent.width
		height: Theme.bandeHauteur
		Texte { text: "|||"; taille: 9; color: Theme.lisere; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } }
		Texte { text: "▲ ▼"; taille: 9; color: Theme.lisere; anchors { right: parent.right; rightMargin: root.biseau + 8; verticalCenter: parent.verticalCenter } }
	}
}
