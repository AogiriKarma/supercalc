import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.theme
import qs.composants
import qs.services

// One screen's lock surface: background, clock, and on the active screen the identification scanner.
WlSessionLockSurface {
	id: surface
	required property var verrou
	color: Theme.fondBas

	readonly property bool formulaire: screen?.name === verrou.ecranFormulaire || Quickshell.screens.length === 1
	readonly property var lecteur: Mpris.players.values.find(p => p.isPlaying) ?? null

	SystemClock { id: horloge; precision: SystemClock.Minutes }

	// keyboard input: over the whole surface (the compositor gives the keyboard to the lock surface)
	Item {
		id: clavier
		anchors.fill: parent
		focus: true
		Component.onCompleted: forceActiveFocus()
		Keys.onPressed: e => {
			if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) surface.verrou.valider();
			else if (e.key === Qt.Key_Backspace) surface.verrou.effacer();
			else if (e.key === Qt.Key_Escape) surface.verrou.saisie = "";
			else if (e.text && e.text.charCodeAt(0) >= 32) surface.verrou.taper(e.text);
			e.accepted = true;
		}
	}

	// ---------------- background ----------------
	Image {
		anchors.fill: parent
		source: Quickshell.env("HOME") + "/.config/supercalc/fond/fond.jpg"
		fillMode: Image.PreserveAspectCrop
		asynchronous: true
		sourceSize.width: surface.width
	}
	Rectangle { anchors.fill: parent; color: "#02080c"; opacity: 0.72 }

	// ---------------- status band ----------------
	Row {
		visible: surface.formulaire
		anchors { top: parent.top; topMargin: 18; left: parent.left; leftMargin: 24 }
		spacing: 8
		Pastille {
			implicitHeight: 26
			fond: Theme.lisere; encre: Theme.encre
			Icone { chemin: Icones.verrou; taille: 13; couleur: Theme.encre; anchors.verticalCenter: parent.verticalCenter }
			Libelle { text: "Session verrouillée"; color: Theme.encre; anchors.verticalCenter: parent.verticalCenter }
		}
		Pastille {
			visible: Notifs.nonLues > 0
			implicitHeight: 26; coupeHD: 0
			fond: Theme.boutonSombre
			prefixe: String(Notifs.nonLues)
			texte: Notifs.nonLues > 1 ? "notifications masquées" : "notification masquée"
		}
	}
	Row {
		visible: surface.formulaire
		anchors { top: parent.top; topMargin: 18; right: parent.right; rightMargin: 24 }
		spacing: 8
		Pastille {
			visible: Controle.reseauWifi !== null
			implicitHeight: 26; coupeHD: 0
			fond: Theme.boutonSombre
			Icone { chemin: Icones.wifi; taille: 13; couleur: Theme.texteTitre; anchors.verticalCenter: parent.verticalCenter }
			Libelle { text: Controle.reseauWifi?.name ?? ""; anchors.verticalCenter: parent.verticalCenter }
		}
		Pastille {
			visible: Systeme.aBatterie
			implicitHeight: 26
			fond: Theme.boutonSombre
			Libelle { text: "PV"; anchors.verticalCenter: parent.verticalCenter }
			Segments { width: 64; nombre: 8; hauteur: 10; valeur: Systeme.niveau; couleur: Theme.energie; couleurVide: Theme.pointEteint; anchors.verticalCenter: parent.verticalCenter }
			Texte { text: String(Math.round(Systeme.niveau * 100)); taille: 13; color: Theme.texteTitre; anchors.verticalCenter: parent.verticalCenter }
		}
	}

	// ---------------- clock ----------------
	Column {
		id: heure
		anchors { horizontalCenter: parent.horizontalCenter }
		y: surface.formulaire ? surface.height * 0.12 : (surface.height - height) / 2
		spacing: 6
		Text {
			anchors.horizontalCenter: parent.horizontalCenter
			text: Qt.formatTime(horloge.date, "hh:mm")
			font.family: Theme.policeAffiche
			font.pixelSize: Math.min(128, surface.height * 0.11)
			font.letterSpacing: 8
			color: Theme.texteTitre
		}
		Libelle {
			anchors.horizontalCenter: parent.horizontalCenter
			text: horloge.date.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM")
			taille: 14
			color: Theme.texteAccent
		}
	}

	// ---------------- identification scanner ----------------
	Fenetre {
		id: scanner
		ouvre: surface.formulaire
		titre: "Scanner // identification"
		variante: surface.verrou.etat === "refus" ? "xana" : surface.verrou.etat === "acces" ? "energie" : "focus"
		width: Math.min(520, surface.width - 48)
		height: 300
		anchors.horizontalCenter: parent.horizontalCenter
		y: Math.max(heure.y + heure.height + 36, (surface.height - height) / 2 + 30)

		Column {
			x: 20; y: 18
			width: parent.width - 40
			spacing: 16

			// identity card
			Row {
				width: parent.width
				spacing: 14
				Chanfrein {
					width: 58; height: 58; hd: 10
					couleur: Theme.tuile
					Icone { anchors.centerIn: parent; chemin: Icones.secteur; taille: 30; trait: 1.4; couleur: surface.verrou.etat === "refus" ? Theme.xanaTexte : Theme.accent }
					// the scanner's sweep
					Rectangle {
						width: parent.width; height: 2
						color: Theme.lisere
						opacity: surface.verrou.etat === "carte" || surface.verrou.etat === "verification" ? 0.9 : 0
						NumberAnimation on y { from: 4; to: 52; duration: 900; loops: Animation.Infinite; running: surface.verrou.etat === "carte" || surface.verrou.etat === "verification" }
					}
				}
				Column {
					width: parent.width - 58 - etape.width - 28
					anchors.verticalCenter: parent.verticalCenter
					spacing: 3
					Text { text: Controle.utilisateur; font.family: Theme.policeTitre; font.pixelSize: 18; font.letterSpacing: 2; color: Theme.texteTitre }
					Texte { text: `${Controle.machine} · verrouillé depuis ${Qt.formatTime(surface.verrou.depuis, "hh:mm")}`; taille: 12; color: Theme.texteDiscret; width: parent.width }
					Texte {
						visible: surface.verrou.refus > 0
						text: `${surface.verrou.refus} ${surface.verrou.refus > 1 ? "essais refusés" : "essai refusé"} · dernier à ${Qt.formatTime(surface.verrou.dernierRefus, "hh:mm")}`
						taille: 12; color: Theme.xanaTexte
					}
				}
				Pastille {
					id: etape
					anchors.verticalCenter: parent.verticalCenter
					implicitHeight: 22; padding: 8; coupeHD: 0
					fond: surface.verrou.etat === "refus" ? Theme.xana : surface.verrou.etat === "acces" ? Theme.energie : Theme.accentSombre
					encre: surface.verrou.etat === "refus" || surface.verrou.etat === "acces" ? Theme.encre : Theme.accent
					texte: ({ carte: "lecture", code: "saisie", verification: "analyse", acces: "accès", refus: "refus" })[surface.verrou.etat]
				}
			}

			// access code
			Column {
				width: parent.width
				spacing: 8
				Libelle { text: "Code d'accès"; taille: 10; color: Theme.texteEteint }
				Rectangle {
					width: parent.width; height: 46
					color: Theme.champ
					border { width: 1; color: surface.verrou.etat === "refus" ? Theme.xana : Theme.bordureVive }
					Row {
						x: 14; anchors.verticalCenter: parent.verticalCenter
						spacing: 6
						Repeater {
							model: Math.max(8, Math.min(24, surface.verrou.saisie.length + 1))
							Rectangle {
								required property int index
								width: 14; height: 14
								anchors.verticalCenter: parent.verticalCenter
								color: index < surface.verrou.saisie.length ? (surface.verrou.etat === "acces" ? Theme.energie : Theme.accent) : Theme.separateur
								Behavior on color { ColorAnimation { duration: 90 } }
							}
						}
						Rectangle {
							width: 2; height: 20
							anchors.verticalCenter: parent.verticalCenter
							color: Theme.lisere
							visible: surface.verrou.etat === "code"
							SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
						}
					}
					Texte {
						anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
						text: surface.verrou.message || (surface.verrou.saisie.length ? `${surface.verrou.saisie.length} caractère${surface.verrou.saisie.length > 1 ? "s" : ""}` : "")
						taille: 12
						color: surface.verrou.etat === "refus" ? Theme.xanaTexte : Theme.texteDiscret
					}
				}
			}

			// steps
			Row {
				spacing: 8
				Repeater {
					model: [
						{ n: "Carte lue", ok: surface.verrou.etat !== "carte", on: surface.verrou.etat === "carte" },
						{ n: "Code", ok: surface.verrou.etat === "acces" || surface.verrou.etat === "verification", on: surface.verrou.etat === "code" || surface.verrou.etat === "refus" },
						{ n: "Accès", ok: surface.verrou.etat === "acces", on: surface.verrou.etat === "verification" },
					]
					Rectangle {
						required property var modelData
						width: nomEtape.implicitWidth + 24; height: 24
						color: modelData.on ? Theme.accent : "transparent"
						border { width: 1; color: modelData.ok ? Theme.energie : modelData.on ? Theme.accent : Theme.separateur }
						Libelle { id: nomEtape; anchors.centerIn: parent; text: modelData.n; taille: 10; color: modelData.ok ? Theme.energie : modelData.on ? Theme.encre : Theme.texteEteint }
					}
				}
			}

			Item {
				width: parent.width; height: 14
				Texte { text: "entrée : valider · échap : effacer"; taille: 12; color: Theme.texteEteint }
				Texte {
					anchors.right: parent.right
					text: `verr. maj : ${surface.verrou.majVerrouillee ? "ON" : "off"} · clavier : ${Sway.dispositionCourte || "?"}`
					taille: 12
					color: surface.verrou.majVerrouillee ? Theme.accent : Theme.texteEteint
				}
			}
		}
	}

	// ---------------- bottom: media and power ----------------
	Rectangle {
		visible: surface.formulaire && surface.lecteur !== null
		anchors { left: parent.left; leftMargin: 24; bottom: parent.bottom; bottomMargin: 24 }
		width: Math.min(380, surface.width * 0.3); height: 52
		color: Qt.rgba(5 / 255, 17 / 255, 26 / 255, 0.85)
		border { width: 1; color: Theme.bordure }
		Icone { id: noteM; x: 14; anchors.verticalCenter: parent.verticalCenter; chemin: Icones.musique; taille: 16; couleur: Theme.texteAccent }
		Column {
			anchors { left: noteM.right; leftMargin: 12; right: ctrlM.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
			Texte { width: parent.width; text: surface.lecteur?.trackTitle ?? ""; taille: 13; color: Theme.texteTitre }
			Texte { width: parent.width; text: surface.lecteur?.trackArtist ?? ""; taille: 12; color: Theme.texteDiscret }
		}
		Row {
			id: ctrlM
			anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
			spacing: 4
			Repeater {
				model: [{ t: "◂◂", f: () => surface.lecteur.previous() }, { t: "▮▮", f: () => surface.lecteur.togglePlaying() }, { t: "▸▸", f: () => surface.lecteur.next() }]
				Rectangle {
					required property var modelData
					width: 26; height: 26; color: Theme.boutonSombre
					Texte { anchors.centerIn: parent; text: modelData.t; taille: 10; color: "#ffffff" }
					MouseArea { anchors.fill: parent; onClicked: modelData.f() }
				}
			}
		}
	}
	Row {
		visible: surface.formulaire
		anchors { right: parent.right; rightMargin: 24; bottom: parent.bottom; bottomMargin: 24 }
		spacing: 8
		Repeater {
			model: [
				{ n: "Veille", ic: Icones.lune, xana: false, cmd: ["systemctl", "suspend"] },
				{ n: "Retour vers le passé", ic: Icones.retour, xana: false, cmd: ["systemctl", "reboot"] },
				{ n: "Arrêt", ic: Icones.arret, xana: true, cmd: ["systemctl", "poweroff"] },
			]
			Rectangle {
				required property var modelData
				width: ligneB.implicitWidth + 24; height: 36
				color: modelData.xana ? Qt.rgba(26 / 255, 8 / 255, 12 / 255, 0.85) : Qt.rgba(5 / 255, 17 / 255, 26 / 255, 0.85)
				border { width: 1; color: modelData.xana ? "#7a2a2e" : Theme.bordure }
				Row {
					id: ligneB
					anchors.centerIn: parent
					spacing: 8
					Icone { chemin: modelData.ic; taille: 14; couleur: modelData.xana ? Theme.xanaTexte : "#9fd0e4"; anchors.verticalCenter: parent.verticalCenter }
					Libelle { text: modelData.n; taille: 10; color: modelData.xana ? Theme.xanaTexte : "#9fd0e4"; anchors.verticalCenter: parent.verticalCenter }
				}
				MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(modelData.cmd) }
			}
		}
	}
}
