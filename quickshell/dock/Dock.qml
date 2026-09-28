import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.theme
import qs.composants
import qs.services

// Dock bas-centre, sur l'écran principal : applis + lecteur en cours.
PanelWindow {
	id: dock
	screen: Etat.ecranPrincipalObjet

	anchors.bottom: true
	margins.bottom: 6
	implicitWidth: cadre.implicitWidth + 40
	implicitHeight: 46 + 20
	exclusiveZone: 46 + 6
	color: "transparent"
	WlrLayershell.namespace: "supercalc-dock"

	readonly property var lecteur: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

	Item {
		id: cadre
		anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
		implicitWidth: rangee.implicitWidth + 24
		width: implicitWidth
		height: 46

		Chanfrein {
			anchors.fill: parent
			couleur: Theme.cadreFocus
			hg: 12; hd: 12
			layer.enabled: Theme.halo > 0
			layer.effect: MultiEffect {
				shadowEnabled: true
				shadowColor: Theme.bordureVive
				shadowOpacity: Theme.halo * 0.6
				shadowBlur: 1.0
				blurMax: 24
				shadowHorizontalOffset: 0
				shadowVerticalOffset: 0
			}
		}
		Chanfrein {
			anchors { fill: parent; margins: 3 }
			couleur: Qt.alpha(Theme.corps, Theme.opacitePanneau)
			hg: 10; hd: 10
		}

		Row {
			id: rangee
			anchors.centerIn: parent
			spacing: 4

			Repeater {
				model: Applis.dock
				Item {
					required property var modelData
					width: 38; height: 36
					readonly property bool active: modelData.fenetres.some(t => t.activated)
					Rectangle { anchors.fill: parent; color: active ? "#123f52" : survol.containsMouse ? "#0c2733" : "transparent" }
					Icone {
						anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
						chemin: modelData.icone
						couleur: active ? "#ffffff" : Theme.texteAccent
						taille: 18
					}
					Rectangle {
						anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 3 }
						width: Math.min(24, 6 * modelData.fenetres.length + 6); height: 2
						visible: modelData.fenetres.length > 0
						color: Theme.accent
					}
					MouseArea {
						id: survol
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: Applis.lancer(modelData)
					}
				}
			}

			Rectangle { visible: dock.lecteur !== null; width: 1; height: 24; color: Theme.separateur; anchors.verticalCenter: parent.verticalCenter }

			Item {
				visible: dock.lecteur !== null
				width: 260; height: 36
				Column {
					anchors { left: parent.left; leftMargin: 6; right: bouton.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
					spacing: 4
					Texte {
						width: parent.width
						taille: 12
						text: dock.lecteur ? (dock.lecteur.trackTitle || dock.lecteur.identity) + (dock.lecteur.trackArtist ? "  ·  " + dock.lecteur.trackArtist : "") : ""
					}
					Rectangle {
						width: parent.width; height: 3; color: Theme.separateur
						Rectangle {
							height: 3; color: Theme.accent
							width: dock.lecteur && dock.lecteur.lengthSupported && dock.lecteur.length > 0 ? parent.width * dock.lecteur.position / dock.lecteur.length : 0
						}
					}
				}
				Rectangle {
					id: bouton
					anchors { right: parent.right; verticalCenter: parent.verticalCenter }
					width: 28; height: 28
					color: Theme.boutonSombre
					border { color: Theme.lisere; width: 1 }
					Icone { anchors.centerIn: parent; chemin: dock.lecteur && dock.lecteur.isPlaying ? Icones.pause : Icones.lecture; couleur: "#ffffff"; taille: 12 }
					MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dock.lecteur.togglePlaying() }
				}
			}
		}
	}

	// MPRIS ne pousse pas la position : on la relit chaque seconde pendant la lecture
	Timer { interval: 1000; repeat: true; running: dock.lecteur?.isPlaying ?? false; onTriggered: dock.lecteur.positionChanged() }
}
