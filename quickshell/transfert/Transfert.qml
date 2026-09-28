import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.composants
import qs.services

// Séquence de transfert à l'ouverture de session : carte d'identité, scanner (modèle 3D réel
// en fil de fer), virtualisation, arrivée au secteur 1. Échap ou clic pour passer.
// Jouée une fois par session (témoin dans $XDG_RUNTIME_DIR), rejouable depuis les réglages.
Scope {
	id: racine

	readonly property bool actif: Etat.panneau === "transfert"
	readonly property int duree: 8000
	property real t: 0

	NumberAnimation {
		id: horloge
		target: racine; property: "t"
		from: 0; to: racine.duree; duration: racine.duree
		onFinished: if (racine.actif) Etat.fermer()
	}
	onActifChanged: {
		if (actif) { t = 0; horloge.restart(); }
		else horloge.stop();
	}
	function passer() { horloge.stop(); Etat.fermer(); }
	function figer(ms) { Etat.ouvrir("transfert"); horloge.stop(); t = ms; }

	// ---------------- lancement automatique, une fois par session ----------------
	Process {
		id: temoin
		command: ["sh", "-c", 'f="${XDG_RUNTIME_DIR:-/tmp}/supercalc-transfert"; [ -e "$f" ] && exit 1; : > "$f"']
		onExited: code => { if (code === 0 && Reglages.sequenceTransfert) Etat.ouvrir("transfert", Etat.ecranPrincipalObjet); }
	}
	// laisse le temps aux réglages d'être lus depuis le disque
	Timer { interval: 400; running: true; onTriggered: temoin.running = true }

	IpcHandler {
		target: "transfert"
		function jouer(): void { Etat.ouvrir("transfert", Etat.ecranPrincipalObjet); }
		function figer(ms: real): void { racine.figer(ms); }
	}

	// ---------------- un calque par écran ----------------
	Variants {
		model: Quickshell.screens
		PanelWindow {
			id: fenetre
			required property var modelData
			screen: modelData
			readonly property bool principal: modelData === (Etat.ecranCible ?? Etat.ecranPrincipalObjet)
			visible: racine.actif
			anchors { top: true; bottom: true; left: true; right: true }
			exclusionMode: ExclusionMode.Ignore
			color: "transparent"
			WlrLayershell.namespace: "supercalc-transfert"
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.keyboardFocus: racine.actif && principal ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

			readonly property real t: racine.t
			readonly property real sortie: Math.max(0, Math.min(1, (t - 7300) / 600))    // fondu final
			readonly property int etape: t < 1600 ? 1 : t < 4300 ? 2 : t < 6300 ? 3 : 4
			readonly property string nom: Controle.utilisateur || "OPÉRATEUR"

			Item {
				anchors.fill: parent
				focus: true
				Keys.onPressed: e => { racine.passer(); e.accepted = true; }
			}
			MouseArea { anchors.fill: parent; onClicked: racine.passer() }

			// fond : terrain en fil de fer, assombri
			Item {
				anchors.fill: parent
				opacity: Math.min(1, fenetre.t / 250) * (1 - fenetre.sortie)
				Rectangle { anchors.fill: parent; color: Theme.fondBas }
				Image {
					anchors.fill: parent
					source: Quickshell.env("HOME") + "/.config/supercalc/fond/fond.jpg"
					fillMode: Image.PreserveAspectCrop
					sourceSize.width: fenetre.width
					asynchronous: true
				}
				Rectangle { anchors.fill: parent; color: "#020a0e"; opacity: fenetre.principal ? 0.45 : 0.8 }
			}

			// écrans secondaires : un simple bandeau
			Libelle {
				visible: !fenetre.principal
				anchors.centerIn: parent
				opacity: (1 - fenetre.sortie) * Math.min(1, fenetre.t / 400)
				text: "Transfert en cours…"
				taille: 14
				color: Theme.texteAccent
			}

			// ---------------- scène 1440 × 900, mise à l'échelle de l'écran ----------------
			Item {
				id: scene
				visible: fenetre.principal
				width: 1440; height: 900
				anchors.centerIn: parent
				scale: Math.min(fenetre.width / 1440, fenetre.height / 900)
				// masquée au pic du flash : l'arrivée s'affiche sur un fond propre
				opacity: fenetre.t < 6420 ? 1 : 0
				readonly property real t: fenetre.t

				// --- rangées de boutons en haut ---
				Row {
					x: 150; y: 18
					spacing: 8
					opacity: Math.min(1, Math.max(0, (scene.t - 150) / 200))
					Repeater {
						model: ["Transfert", "Scanner", "Virtualisation"]
						Rectangle {
							required property string modelData
							required property int index
							readonly property int k: index + 1
							readonly property bool fait: k < fenetre.etape
							readonly property bool enCours: k === fenetre.etape
							width: 150; height: 20
							color: enCours ? Theme.ambre : fait ? "#5fb3d6" : "#3b8db3"
							layer.enabled: enCours
							layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.ambre; shadowOpacity: 0.6; shadowBlur: 0.8; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
							Libelle { anchors.centerIn: parent; text: modelData; taille: 10; color: parent.enCours ? "#2a1a06" : fait ? "#ffffff" : "#bfe3f0" }
						}
					}
					Rectangle { width: 110; height: 20; color: "#3b8db3"; opacity: 0.8 }
				}
				Rectangle {
					x: 466; y: 44; width: 260; height: 20
					color: "#3b8db3"
					opacity: Math.min(1, Math.max(0, (scene.t - 250) / 200))
					Libelle { anchors.centerIn: parent; text: "Supercalculateur · " + Qt.formatTime(new Date(), "hh:mm"); taille: 10; color: "#e6f8ff" }
				}
				Grid {
					x: 944; y: 18
					columns: 3; spacing: 8
					opacity: Math.min(1, Math.max(0, (scene.t - 300) / 200))
					Repeater { model: 6; Rectangle { required property int index; visible: index !== 3; width: 110; height: 20; color: "#3b8db3"; opacity: 0.75 } }
				}

				// --- carte d'identité ---
				Apparition {
					t: scene.t; debut: 400
					x: 56; y: 132; width: 270; height: 420
					Fenetre {
						anchors.fill: parent
						titre: "Sélection // ID"
						variante: fenetre.etape === 1 ? "energie" : "focus"
						Column {
							anchors.centerIn: parent
							anchors.verticalCenterOffset: -8
							spacing: 14
							Rectangle {
								id: carte
								width: 200; height: 232
								color: Theme.ambre
								border { width: 3; color: "#ffd699" }
								layer.enabled: true
								layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.ambre; shadowOpacity: 0.7; shadowBlur: 1.0; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
								Rectangle {
									x: 12; y: 12; width: parent.width - 24; height: 136
									color: "#fff1dc"
									Texte { x: 6; y: 4; text: "002"; taille: 10; color: "#b8741a" }
									Icone { anchors.centerIn: parent; chemin: Icones.secteur; taille: 76; trait: 0.9; couleur: "#8a4f10" }
									Text { anchors.centerIn: parent; text: fenetre.nom.charAt(0); font.family: Theme.policeTitre; font.pixelSize: 30; color: "#8a4f10" }
								}
								Column {
									y: 158; width: parent.width
									spacing: 8
									Text { anchors.horizontalCenter: parent.horizontalCenter; text: fenetre.nom; font.family: Theme.policeTitre; font.pixelSize: 15; font.letterSpacing: 2; color: "#3a2206" }
									Row {
										anchors.horizontalCenter: parent.horizontalCenter
										spacing: 4
										Repeater { model: 10; Rectangle { required property int index; width: 11; height: 11; radius: 6; color: scene.t > 700 + index * 60 ? "#3fbf5f" : "#e0c9a0" } }
									}
									Row {
										anchors.horizontalCenter: parent.horizontalCenter
										spacing: 6
										Rectangle { width: 146; height: 6; color: "#b8741a"; anchors.verticalCenter: parent.verticalCenter }
										Texte { text: "100"; taille: 11; color: "#3a2206" }
									}
								}
							}
							Rectangle {
								anchors.horizontalCenter: parent.horizontalCenter
								width: 130; height: 28
								color: "transparent"
								border { width: 1; color: Theme.ambre }
								Libelle { anchors.centerIn: parent; text: "▸ Scanner 02"; taille: 10; color: Theme.ambre }
							}
						}
					}
				}

				// --- scanner ---
				Apparition {
					id: scanner
					t: scene.t; debut: 1600
					x: 350; y: 100; width: 704; height: 580
					readonly property real prog: Math.max(0, Math.min(1, (scene.t - 1800) / 2400))
					Fenetre {
						anchors.fill: parent
						titre: "Scanner 02 // analyse"

						// onglets
						Row {
							x: 4; y: 4
							spacing: 3
							Repeater {
								model: ["ID", "Bio", "Forme", "Code", "Scan", "ADN", "Trans", "Lyoko"]
								Rectangle {
									required property string modelData
									required property int index
									// l'onglet courant avance avec l'analyse : ID … SCAN pendant le scan, TRANS puis LYOKO
									readonly property int enCours: fenetre.etape === 1 ? 0 : fenetre.etape === 2 ? 1 + Math.min(3, Math.floor(scanner.prog * 4)) : fenetre.etape === 3 ? 6 : 7
									readonly property bool courant: index === enCours
									readonly property bool fait: index < enCours
									width: (698 - 3 * 7 - 6) / 8; height: 22
									color: courant ? Theme.ambre : fait ? Theme.cadreFocus : "#123f52"
									Libelle { anchors.centerIn: parent; text: modelData; taille: 9; color: parent.courant ? "#2a1a06" : "#e6f8ff" }
								}
							}
						}

						// barres verticales
						Row {
							x: 10; y: 36; height: 452
							spacing: 5
							Repeater {
								model: [0.82, 0.58, 0.71]
								Rectangle {
									required property real modelData
									required property int index
									width: 20; height: 452
									color: Theme.tuile
									Rectangle {
										anchors.bottom: parent.bottom
										width: parent.width
										height: parent.height * (fenetre.etape >= 3 ? 1 : modelData * scanner.prog + 0.05 * Math.sin(scene.t / 180 + index * 2))
										gradient: Gradient {
											GradientStop { position: 0; color: "#d4f4ff" }
											GradientStop { position: 1; color: "#3b8db3" }
										}
									}
								}
							}
						}

						// vue du modèle
						Rectangle {
							id: vue
							x: 94; y: 36; width: 490; height: 452
							color: "#06141c"
							border { width: 1; color: Theme.separateur }
							clip: true
							Texte { x: 14; y: 12; text: "MODÈLE 3D // " + fenetre.nom; taille: 11; color: Theme.lisere }
							Texte { x: 14; y: 28; text: "poly 4 700 · rév 4.2"; taille: 10; color: Theme.texteDiscret }
							Texte { x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; text: "maillage : CesiumMan (CC-BY 4.0 Cesium)"; taille: 10; color: Theme.texteEteint }
							// repères de coin
							Repeater {
								model: [[10, 50, false, false], [470, 50, true, false], [10, 422, false, true], [470, 422, true, true]]
								Item {
									required property var modelData
									x: modelData[0]; y: modelData[1]; width: 10; height: 10
									Rectangle { width: 10; height: 1; color: Theme.lisere; y: modelData[3] ? 9 : 0 }
									Rectangle { width: 1; height: 10; color: Theme.lisere; x: modelData[2] ? 9 : 0 }
								}
							}
							// sol
							Canvas {
								anchors.fill: parent
								opacity: 0.35
								onPaint: {
									const c = getContext("2d"); c.reset();
									c.strokeStyle = "#2f86b0"; c.lineWidth = 1;
									c.beginPath(); c.moveTo(90, 385); c.lineTo(400, 385); c.stroke();
									c.beginPath(); c.moveTo(20, 450); c.lineTo(470, 450); c.stroke();
									c.beginPath(); c.moveTo(180, 330); c.lineTo(80, 452); c.stroke();
									c.beginPath(); c.moveTo(310, 330); c.lineTo(410, 452); c.stroke();
								}
							}
							// le modèle tourne (36 vues précalculées, 10° chacune)
							Image {
								id: modele
								anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 34 }
								width: 380; height: 438
								fillMode: Image.PreserveAspectFit
								readonly property int vueCourante: Math.floor(scene.t / 70) % 36
								source: Quickshell.shellPath(`transfert/modele/corps-${String(vueCourante).padStart(2, "0")}.png`)
								cache: true
								smooth: true
								// révélation de bas en haut pendant le scan
								layer.enabled: fenetre.etape === 2
								layer.effect: MultiEffect {
									maskEnabled: true
									maskSource: masque
									maskThresholdMin: 0.5
									maskSpreadAtMin: 0.2
								}
							}
							Item {
								id: masque
								visible: false
								width: modele.width; height: modele.height
								layer.enabled: true
								Rectangle {
									anchors.bottom: parent.bottom
									width: parent.width
									height: parent.height * Math.min(1, 0.08 + scanner.prog * 1.05)
									color: "white"
								}
							}
							// bande de scan
							Item {
								visible: fenetre.etape === 2
								x: 60; width: 370; height: 30
								y: modele.y + modele.height * (1 - Math.min(1, 0.08 + scanner.prog * 1.05)) - 15
								Rectangle {
									anchors.fill: parent
									gradient: Gradient {
										GradientStop { position: 0; color: "transparent" }
										GradientStop { position: 0.5; color: Qt.alpha(Theme.ambre, 0.35) }
										GradientStop { position: 1; color: "transparent" }
									}
								}
								Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 2; color: "#ffd699" }
							}
						}

						// détails à droite
						Column {
							x: 596; y: 36
							spacing: 8
							Repeater {
								model: [{ f: "tete.png", n: "tête", d: 2400 }, { f: "main.png", n: "main", d: 3000 }]
								Rectangle {
									required property var modelData
									width: 96; height: 96
									color: "#06141c"
									border { width: 1; color: Theme.separateur }
									Image {
										anchors { fill: parent; margins: 4 }
										source: Quickshell.shellPath("transfert/modele/" + modelData.f)
										fillMode: Image.PreserveAspectFit
										opacity: Math.max(0, Math.min(1, (scene.t - modelData.d) / 300))
									}
									Texte { x: 4; anchors.bottom: parent.bottom; text: modelData.n; taille: 10; color: Theme.texteDiscret }
								}
							}
							Rectangle {
								width: 96; height: 244
								color: "#06141c"
								border { width: 1; color: Theme.separateur }
								Column {
									x: 8; y: 10
									spacing: 6
									Repeater {
										model: [
											{ c: "bio", ok: scene.t > 2200 },
											{ c: "forme", ok: scene.t > 2900 },
											{ c: "code", ok: scene.t > 3800 },
											{ c: "lien", ok: fenetre.etape >= 4, attente: fenetre.etape < 3 },
										]
										Row {
											required property var modelData
											spacing: 6
											Texte { text: modelData.c; taille: 12; color: Theme.texte }
											Texte {
												text: modelData.ok ? "ok" : modelData.attente ? "attente" : "…"
												taille: 12
												color: modelData.ok ? Theme.energie : modelData.attente ? Theme.texteEteint : Theme.ambre
											}
										}
									}
								}
							}
						}

						// commandes du bas
						Row {
							x: 10; y: 500
							spacing: 6
							Repeater {
								model: ["◂◂", "▮▮", "▶", "▸▸"]
								Rectangle {
									required property string modelData
									required property int index
									width: 30; height: 22
									color: index === 2 ? "#2f86b0" : "transparent"
									border { width: 1; color: Theme.bordure }
									Texte { anchors.centerIn: parent; text: modelData; taille: 10; color: Theme.texteTitre }
								}
							}
						}
						Rectangle {
							x: 160; y: 509; width: 440; height: 4
							color: Theme.separateur
							Rectangle { width: parent.width * (fenetre.etape >= 3 ? 1 : scanner.prog); height: parent.height; color: Theme.energie }
						}
						Libelle {
							x: 614; y: 505
							text: `Scan ${Math.round((fenetre.etape >= 3 ? 1 : scanner.prog) * 100)} %`
							taille: 10; color: Theme.energie
						}
					}
				}

				// --- étape 3 : données bio, chrono, scanners ---
				Apparition {
					t: scene.t; debut: 4300
					x: 1080; y: 100; width: 310; height: 270
					Fenetre {
						anchors.fill: parent
						titre: "Données bio"
						Column {
							x: 16; y: 14
							spacing: 5
							Libelle { text: "Séquence " + fenetre.nom; taille: 11; color: Theme.ambre; bottomPadding: 4 }
							Repeater {
								model: ["lecture carte 002", "profil chargé", "forme virtuelle v4.2", "compilation avatar", "analyse terminée", "transmission…"]
								Texte {
									required property string modelData
									required property int index
									visible: scene.t > 4400 + index * 230
									text: "- " + modelData
									taille: 13
									color: index === 4 ? Theme.energie : index === 5 ? Theme.ambre : Theme.texte
								}
							}
						}
					}
				}
				Apparition {
					t: scene.t; debut: 4600
					x: 1080; y: 392; width: 310; height: 120
					Fenetre {
						anchors.fill: parent
						titre: "Chrono"
						bande: false
						Text {
							anchors.centerIn: parent
							readonly property real s: Math.max(0, scene.t - 1600) / 1000
							text: `00:00:${String(Math.floor(s)).padStart(2, "0")}:${String(Math.floor((s % 1) * 100)).padStart(2, "0")}`
							font.family: Theme.policeTitre; font.pixelSize: 28; font.letterSpacing: 2
							color: Theme.texteTitre
						}
					}
				}
				Apparition {
					t: scene.t; debut: 4900
					x: 1080; y: 534; width: 310; height: 146
					Fenetre {
						anchors.fill: parent
						titre: "Scanners"
						bande: false
						Column {
							x: 16; y: 14
							spacing: 8
							Repeater {
								model: [{ n: "01", e: "libre" }, { n: "02 " + fenetre.nom.toLowerCase(), e: fenetre.etape >= 4 ? "transféré" : "transfert", actif: true }, { n: "03", e: "libre" }]
								Row {
									required property var modelData
									spacing: 10
									Texte { width: 110; text: modelData.n; taille: 13; color: modelData.actif ? Theme.ambre : Theme.texteDiscret }
									Rectangle {
										width: 90; height: 6
										anchors.verticalCenter: parent.verticalCenter
										color: Theme.separateur
										Rectangle { visible: !!modelData.actif; height: parent.height; width: parent.width * Math.min(1, Math.max(0, (scene.t - 4900) / 1300)); color: Theme.ambre }
									}
									Texte { text: modelData.e; taille: 12; color: modelData.actif ? Theme.texteTitre : Theme.texteEteint }
								}
							}
						}
					}
				}

				// --- bas : étapes et matérialisation ---
				Apparition {
					t: scene.t; debut: 500
					x: 350; y: 705; width: 300; height: 46
					Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.corps, 0.9); border { width: 2; color: Theme.cadreFocus } }
					Row {
						anchors.centerIn: parent
						spacing: 6
						Repeater {
							model: ["Transfert", "Scanner", "Virtu."]
							Rectangle {
								required property string modelData
								required property int index
								readonly property int k: index + 1
								width: 88; height: 26; radius: 13
								color: k === fenetre.etape ? Theme.ambre : "transparent"
								border { width: 1; color: k < fenetre.etape ? Theme.energie : k === fenetre.etape ? Theme.ambre : Theme.bordure }
								Libelle { anchors.centerIn: parent; text: modelData; taille: 9; color: parent.k < fenetre.etape ? Theme.energie : parent.k === fenetre.etape ? "#2a1a06" : Theme.texteDiscret }
							}
						}
					}
				}
				Apparition {
					t: scene.t; debut: 600
					x: 656; y: 714; width: 734; height: 36
					readonly property real mat: Math.max(0, Math.min(1, (scene.t - 600) / 5600))
					Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.corps, 0.9); border { width: 2; color: Theme.cadreFocus } }
					Libelle { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "Matérialisation"; taille: 11 }
					Segments {
						x: 196; width: 430; anchors.verticalCenter: parent.verticalCenter
						nombre: 40; hauteur: 10; valeur: parent.mat
						couleur: Theme.ambre; couleurVide: "#123f52"
					}
					Texte { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: `${String(Math.round(parent.mat * 100)).padStart(4, "0")} / 0100`; taille: 13; color: Theme.texteTitre }
				}

				// --- libellé de l'étape ---
				Column {
					x: 56; y: 776
					spacing: 4
					opacity: Math.min(1, Math.max(0, (scene.t - 400) / 300))
					Libelle { text: `Étape 0${Math.min(3, fenetre.etape)} / 03`; taille: 12; color: Theme.ambre }
					Text {
						text: fenetre.etape === 1 ? "Transfert " + fenetre.nom : fenetre.etape === 2 ? "Scanner " + fenetre.nom : "Virtualisation"
						font.family: Theme.policeAffiche; font.pixelSize: 46; font.letterSpacing: 4
						font.capitalization: Font.AllUppercase
						color: "#fff3df"
						layer.enabled: true
						layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.ambre; shadowOpacity: 0.5; shadowBlur: 0.7; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
					}
				}
				Texte {
					x: 1180; y: 812
					text: "échap : passer la séquence"
					taille: 13; color: Theme.texteAccent
					opacity: Math.min(1, Math.max(0, (scene.t - 800) / 300))
				}
			}

			// ---------------- étape 4 : flash de virtualisation puis arrivée ----------------
			Rectangle {
				anchors.fill: parent
				color: "#e8fbff"
				visible: fenetre.principal
				opacity: {
					const d = fenetre.t - 6300;
					if (d < 0) return 0;
					if (d < 120) return d / 120;
					return Math.max(0, 1 - (d - 120) / 500);
				}
			}
			Column {
				visible: fenetre.principal && fenetre.etape === 4
				anchors.centerIn: parent
				spacing: 6
				opacity: Math.min(1, Math.max(0, (fenetre.t - 6450) / 300)) * (1 - fenetre.sortie)
				Libelle { anchors.horizontalCenter: parent.horizontalCenter; text: "Arrivée"; taille: 14; color: Theme.texteAccent }
				Text {
					anchors.horizontalCenter: parent.horizontalCenter
					text: Sway.nomAffiche(Sway.secteurs.find(s => s.focus)?.nom ?? "1:foret")
					font.family: Theme.policeAffiche; font.pixelSize: 54; font.letterSpacing: 6
					font.capitalization: Font.AllUppercase
					color: "#ffffff"
				}
			}
		}
	}
}
