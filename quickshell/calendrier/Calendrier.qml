import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.composants
import qs.services

// Calendar (a click on the clock): a month with ISO week numbers, navigated with the wheel, the
// arrow keys or the buttons.
PanelWindow {
	id: fenetre
	screen: Etat.ecranCible
	visible: ouvert || cadre.anime
	anchors { top: true; bottom: true; left: true; right: true }
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.namespace: "supercalc-calendrier"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: ouvert ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

	readonly property bool ouvert: Etat.panneau === "calendrier"
	SystemClock { id: horloge; precision: SystemClock.Minutes }
	readonly property date aujourdhui: horloge.date
	property int decalage: 0                       // month shown, relative to the current one
	onOuvertChanged: if (ouvert) { decalage = 0; cadre.forceActiveFocus(); }

	readonly property date premier: new Date(aujourdhui.getFullYear(), aujourdhui.getMonth() + decalage, 1)
	readonly property var locale: Qt.locale("fr_FR")

	// ISO 8601 week
	function semaine(d) {
		const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
		const j = t.getUTCDay() || 7;
		t.setUTCDate(t.getUTCDate() + 4 - j);
		const debut = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
		return Math.ceil(((t - debut) / 86400000 + 1) / 7);
	}
	function memeJour(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
	function cle(d) { return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`; }

	// 6 rows of 7 days, Monday first
	readonly property var jours: {
		const res = [];
		const decal = (premier.getDay() + 6) % 7;
		const debut = new Date(premier.getFullYear(), premier.getMonth(), 1 - decal);
		for (let i = 0; i < 42; i++) res.push(new Date(debut.getFullYear(), debut.getMonth(), debut.getDate() + i));
		return res;
	}

	MouseArea { anchors.fill: parent; onClicked: Etat.fermer() }

	Fenetre {
		id: cadre
		ouvre: fenetre.ouvert
		titre: fenetre.premier.toLocaleDateString(fenetre.locale, "MMMM yyyy")
		width: 360
		height: colonne.implicitHeight + Theme.titreHauteur + Theme.bandeHauteur + 32
		x: (fenetre.width - width) / 2
		y: Theme.barreHauteur + 16
		// opacity driven by Fenetre, so it follows the unfolding
		focus: true
		Keys.onPressed: e => {
			if (e.key === Qt.Key_Escape) Etat.fermer();
			else if (e.key === Qt.Key_Left || e.key === Qt.Key_PageUp) fenetre.decalage -= 1;
			else if (e.key === Qt.Key_Right || e.key === Qt.Key_PageDown) fenetre.decalage += 1;
			else if (e.key === Qt.Key_Home || e.key === Qt.Key_T) fenetre.decalage = 0;
			else return;
			e.accepted = true;
		}
		MouseArea { anchors.fill: parent; onWheel: w => fenetre.decalage += w.angleDelta.y > 0 ? -1 : 1 }

		Column {
			id: colonne
			x: 16; y: 14
			width: parent.width - 32
			spacing: 12

			// today in large type plus navigation
			Item {
				width: parent.width; height: 44
				Text {
					id: grandJour
					anchors.verticalCenter: parent.verticalCenter
					text: fenetre.aujourdhui.getDate()
					font.family: Theme.policeAffiche; font.pixelSize: 34
					color: Theme.accent
				}
				Column {
					anchors { left: grandJour.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
					Libelle { text: fenetre.aujourdhui.toLocaleDateString(fenetre.locale, "dddd"); taille: 12 }
					Texte { text: `semaine ${fenetre.semaine(fenetre.aujourdhui)} · ${Qt.formatTime(fenetre.aujourdhui, "hh:mm")}`; taille: 12; color: Theme.texteDiscret }
				}
				Row {
					anchors { right: parent.right; verticalCenter: parent.verticalCenter }
					spacing: 4
					Repeater {
						model: [{ t: "◂", d: -1 }, { t: "•", d: 0 }, { t: "▸", d: 1 }]
						Rectangle {
							required property var modelData
							width: 26; height: 26
							color: zoneNav.containsMouse ? Theme.bouton : Theme.tuile
							border { width: 1; color: Theme.bordure }
							Texte { anchors.centerIn: parent; text: modelData.t; taille: 13; color: Theme.texteTitre }
							MouseArea { id: zoneNav; anchors.fill: parent; hoverEnabled: true; onClicked: fenetre.decalage = modelData.d === 0 ? 0 : fenetre.decalage + modelData.d }
						}
					}
				}
			}

			// grid
			Grid {
				id: grille
				columns: 8
				width: parent.width
				readonly property real case_: width / 8
				Repeater {
					model: ["sem", "L", "M", "M", "J", "V", "S", "D"]
					Item {
						required property string modelData
						required property int index
						width: grille.case_; height: 22
						Libelle { anchors.centerIn: parent; text: modelData; taille: 10; color: index >= 6 ? Theme.accent : index === 0 ? Theme.texteEteint : Theme.texteAccent }
					}
				}
				Repeater {
					model: 48
					Item {
						required property int index
						readonly property int col: index % 8
						readonly property int rang: Math.floor(index / 8)
						readonly property var jour: col > 0 ? fenetre.jours[rang * 7 + col - 1] : null
						readonly property bool horsMois: jour !== null && jour.getMonth() !== fenetre.premier.getMonth()
						readonly property bool estAujourdhui: jour !== null && fenetre.memeJour(jour, fenetre.aujourdhui)
						readonly property bool weekEnd: col >= 6
						width: grille.case_; height: 30
						Rectangle {
							anchors { fill: parent; margins: 2 }
							visible: parent.estAujourdhui
							color: Theme.lisere
						}
						Texte {
							anchors.centerIn: parent
							text: parent.col === 0 ? String(fenetre.semaine(fenetre.jours[parent.rang * 7])) : String(parent.jour.getDate())
							taille: parent.col === 0 ? 12 : 14
							color: parent.col === 0 ? Theme.bordure : parent.estAujourdhui ? Theme.encre : parent.horsMois ? Theme.bordure : parent.weekEnd ? Theme.accent : Theme.texte
						}
					}
				}
			}
		}
	}
}
