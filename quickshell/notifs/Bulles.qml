import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.theme
import qs.composants
import qs.services

// Notification bubbles, top right of the active screen, below the bar.
PanelWindow {
	id: fenetre
	screen: Etat.ecranActif
	visible: Notifs.bulles.length > 0
	anchors { top: true; right: true }
	margins { top: 4; right: Theme.marge - 6 }
	implicitWidth: 400 + 24
	implicitHeight: Math.max(1, pile.implicitHeight + 24)
	color: "transparent"
	WlrLayershell.namespace: "supercalc-notifications"
	WlrLayershell.layer: WlrLayer.Overlay
	mask: Region { item: pile }

	Column {
		id: pile
		x: 12; y: 12
		width: 400
		spacing: 10

		Repeater {
			model: Notifs.bulles
			delegate: Item {
				id: bulle
				required property var modelData
				readonly property var n: modelData
				readonly property int niveau: n.urgency === NotificationUrgency.Critical ? 2 : n.urgency === NotificationUrgency.Low ? 0 : 1
				readonly property int duree: Notifs.duree(n)
				property real restant: 1

				width: pile.width
				height: cadre.height
				// the fade is left to the frame, which unfolds as it arrives
				Component.onCompleted: if (duree > 0) decompte.start();

				NumberAnimation on restant {
					id: decompte
					running: false
					from: 1; to: 0
					duration: bulle.duree
					paused: survol.hovered
					onFinished: Notifs.retirerBulle(bulle.n)
				}
				HoverHandler { id: survol }

				Fenetre {
					animeALaCreation: true
					id: cadre
					width: parent.width
					height: Theme.titreHauteur + corps.implicitHeight + 20 + Theme.bandeHauteur
					titre: bulle.n.appName || "SYSTÈME"
					sousTitre: bulle.niveau === 1 ? "" : ["basse", "", "critique"][bulle.niveau]
					variante: bulle.niveau === 2 ? "xana" : bulle.niveau === 0 ? "inactif" : "focus"
					halo: bulle.niveau > 0
					biseau: 12

					Row {
						id: corps
						x: 12; y: 10
						width: parent.width - 24
						spacing: 12
						// A notification's image is almost always an avatar: it belongs here, in place of
						// the generic icon, rather than as a block below the text.
						Rectangle {
							id: vignette
							width: 44; height: 44
							color: bulle.niveau === 2 ? "#2a0f14" : Theme.tuile
							border { width: 1; color: bulle.niveau === 2 ? Theme.xana : bulle.niveau === 0 ? Theme.bordure : Theme.bordureVive }
							clip: true
							Image {
								anchors { fill: parent; margins: 1 }
								visible: bulle.n.image !== ""
								source: bulle.n.image
								fillMode: Image.PreserveAspectCrop
								asynchronous: true
								sourceSize.width: 88
							}
							Icone {
								visible: bulle.n.image === ""
								anchors.centerIn: parent
								taille: 20
								chemin: Notifs.icone(bulle.n)
								couleur: bulle.niveau === 2 ? Theme.xanaTexte : bulle.niveau === 0 ? "#9fd0e4" : Theme.lisere
							}
						}
						Column {
							width: parent.width - vignette.width - parent.spacing
							spacing: 6
							Texte {
								width: parent.width
								text: bulle.n.summary
								taille: 14
								color: bulle.niveau === 2 ? "#ffe0e0" : Theme.texteTitre
							}
							Texte {
								width: parent.width
								visible: text !== ""
								text: bulle.n.body
								taille: 13
								wrapMode: Text.Wrap
								maximumLineCount: 4
								color: bulle.niveau === 2 ? "#f3d7d8" : bulle.niveau === 0 ? "#9fd0e4" : Theme.texte
							}
							Row {
								visible: bulle.n.actions.length > 0
								spacing: 6
								topPadding: 2
								Repeater {
									model: bulle.n.actions
									Pastille {
										required property var modelData
										texte: modelData.text
										cliquable: true
										implicitHeight: 22
										padding: 10
										fond: bulle.niveau === 2 ? Theme.xanaCadre : Theme.boutonSombre
										onClique: modelData.invoke()
									}
								}
							}
						}
					}

					// remaining-time bar, in the bottom band
					Rectangle {
						parent: cadre
						anchors { left: parent.left; right: parent.right; bottom: parent.bottom
							leftMargin: 34; rightMargin: 46; bottomMargin: 6 }
						height: 2
						color: Qt.alpha(Theme.lisere, 0.2)
						visible: bulle.duree > 0
						Rectangle { width: parent.width * bulle.restant; height: parent.height; color: Theme.lisere }
					}
				}

				TapHandler {
					acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
					onTapped: (point, bouton) => {
						if (bouton === Qt.RightButton) Notifs.retirerBulle(bulle.n);        // hide (stays in the log)
						else if (bouton === Qt.MiddleButton) bulle.n.dismiss();             // remove
						else {
							const def = bulle.n.actions.find(a => a.identifier === "default");
							if (def) def.invoke(); else Notifs.retirerBulle(bulle.n);
						}
					}
				}
			}
		}
	}
}
