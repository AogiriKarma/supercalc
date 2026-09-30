import QtQuick
import QtQuick.Effects
import qs.theme

// The IFSCL frame shared by every Quickshell surface: tabs on the left, title on the right,
// square, dark body, ||| ▲▼ band, bevelled corners, halo.
Item {
	id: root
	property string titre: ""
	property string sousTitre: ""           // discreet mono text left of the title (optional)
	property string variante: "focus"       // focus | inactif | xana | energie
	property bool bande: true
	property bool halo: true
	property real biseau: Theme.biseau
	property real opaciteCorps: Theme.opacitePanneau   // overridable: a more discreet background
	default property alias contenu: zone.data
	readonly property alias zoneContenu: zone

	readonly property color cadre: variante === "xana" ? Theme.xanaCadre
		: variante === "inactif" ? Theme.cadreInactif
		: variante === "energie" ? "#e39a2c" : Theme.cadreFocus
	readonly property color fondCorps: variante === "xana" ? Theme.xanaCorps : Theme.corps
	readonly property color encreTitre: variante === "inactif" ? "#bfe3f0" : "#ffffff"
	readonly property color couleurHalo: variante === "xana" ? Theme.xana
		: variante === "energie" ? Theme.ambre : Theme.bordureVive

	// --- unfolding on open ---
	// As in IFSCL: the title bar and the bottom band appear stuck together, then the body opens
	// between them and pushes them apart. The panels keep their own fade; here only the height is
	// animated, so as not to fight with their opacity.
	property bool ouvre: true               // bind this to the panel's open flag
	property real deploiement: 1            // 0 = folded onto its two bands, 1 = open
	readonly property real hauteurBas: root.bande ? Theme.bandeHauteur : Theme.epaisseurCadre
	readonly property real hauteurCorps: Math.max(0, height - barreTitre.height - hauteurBas)

	// Turning animations off mid-flight sets the durations to zero without finishing what is
	// running: `anime` then stayed true forever, and the windows whose visibility depends on it
	// never closed again. So the state is snapped back into place on the change.
	readonly property bool avecAnimations: Theme.animations
	onAvecAnimationsChanged: if (!avecAnimations) {
		ouverture.stop();
		fermeture.stop();
		opacity = ouvre ? 1 : 0;
		deploiement = ouvre ? 1 : 0;
	}

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
	// Durations of the unfolding proper, deliberately longer than dureeCourte/dureeMoyenne: this
	// is an effect meant to be seen, not a transition meant to be got out of the way.
	// The same duration both ways, and the two stages follow one another instead of overlapping:
	// on opening the two bands appear first, then the body opens; on closing the body folds back
	// first, then the bands fade out.
	readonly property int dureeFondu: Theme.animations ? 200 : 0
	readonly property int dureeDepliage: Theme.animations ? 420 : 0
	readonly property bool anime: ouverture.running || fermeture.running
	property int retard: 0                  // staggers several frames opened together
	// For frames created already open (a notification bubble coming in). Left false by default:
	// the transfer scene computes everything from its own clock so that `figer` stays
	// reproducible, and an animation of its own would break that.
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

	// --- title bar ---
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

	// --- body ---
	Chanfrein {
		id: corps
		x: Theme.epaisseurCadre
		y: barreTitre.height
		width: parent.width - Theme.epaisseurCadre * 2
		height: root.hauteurCorps * root.deploiement
		couleur: Qt.alpha(root.fondCorps, root.opaciteCorps)
		bd: root.bande ? 0 : Math.max(0, root.biseau - Theme.epaisseurCadre)
	}
	Item {
		id: zone
		anchors.fill: corps
		// while unfolding, the body is shorter than its content: without clipping, that content
		// would spill out of the frame instead of being uncovered progressively.
		clip: true
	}

	// --- bottom band ---
	Item {
		visible: root.bande
		y: barreTitre.height + corps.height
		width: parent.width
		height: Theme.bandeHauteur
		Texte { text: "|||"; taille: 9; color: Theme.lisere; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } }
		Texte { text: "▲ ▼"; taille: 9; color: Theme.lisere; anchors { right: parent.right; rightMargin: root.biseau + 8; verticalCenter: parent.verticalCenter } }
	}
}
