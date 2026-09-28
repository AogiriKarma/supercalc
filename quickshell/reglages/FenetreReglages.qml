import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.composants
import qs.services

// Réglages (Super+,) : tout est appliqué en direct et écrit dans reglages.json.
PanelWindow {
	id: fenetre
	screen: Etat.ecranCible
	visible: ouvert || fondu.running
	anchors { top: true; bottom: true; left: true; right: true }
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.namespace: "supercalc-reglages"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: ouvert ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

	readonly property bool ouvert: Etat.panneau === "reglages"
	property string section: "apparence"
	onOuvertChanged: if (ouvert) { cadre.forceActiveFocus(); versionSway.running = true; versionQs.running = true; }

	readonly property var sections: [
		{ id: "apparence", n: "Apparence", ic: "M8 2a6 6 0 1 0 0 12c1 0 1.5-.8 1.2-1.6-.4-1 .3-1.9 1.3-1.9H12a2 2 0 0 0 2-2A6 6 0 0 0 8 2z M5 7h.01 M8 5h.01 M11 7h.01" },
		{ id: "ecrans", n: "Écrans", ic: Icones.moniteur },
		{ id: "dock", n: "Barre et dock", ic: "M2 3h12v3H2z M2 9h12v4H2z" },
		{ id: "session", n: "Session", ic: Icones.lecture },
		{ id: "apropos", n: "À propos", ic: "M8 2a6 6 0 1 0 0 12A6 6 0 0 0 8 2z M8 7v4 M8 5v.01" },
	]

	property string sway: ""
	property string qs: ""
	Process { id: versionSway; command: ["swaymsg", "-r", "-t", "get_version"]; stdout: StdioCollector { onStreamFinished: { try { fenetre.sway = JSON.parse(text).human_readable; } catch (e) {} } } }
	Process { id: versionQs; command: ["qs", "--version"]; stdout: StdioCollector { onStreamFinished: fenetre.qs = text.trim().split("\n")[0] } }

	Rectangle {
		anchors.fill: parent
		color: "#020a0e"
		opacity: fenetre.ouvert ? 0.6 : 0
		Behavior on opacity { NumberAnimation { id: fondu; duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }
		MouseArea { anchors.fill: parent; onClicked: Etat.fermer() }
	}

	Fenetre {
		id: cadre
		titre: "Réglages // supercalc"
		width: Math.min(1000, fenetre.width - 48)
		height: Math.min(640, fenetre.height - Theme.barreHauteur - 60)
		x: (fenetre.width - width) / 2
		y: Math.max(Theme.barreHauteur + 24, (fenetre.height - height) / 2)
		opacity: fenetre.ouvert ? 1 : 0
		scale: fenetre.ouvert ? 1 : 0.98
		Behavior on opacity { NumberAnimation { duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }
		Behavior on scale { NumberAnimation { duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }
		focus: true
		Keys.onEscapePressed: Etat.fermer()
		Keys.onUpPressed: { const i = fenetre.sections.findIndex(s => s.id === fenetre.section); fenetre.section = fenetre.sections[Math.max(0, i - 1)].id; }
		Keys.onDownPressed: { const i = fenetre.sections.findIndex(s => s.id === fenetre.section); fenetre.section = fenetre.sections[Math.min(fenetre.sections.length - 1, i + 1)].id; }
		MouseArea { anchors.fill: parent }

		// ---------------- navigation ----------------
		Item {
			id: nav
			anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
			width: cadre.width >= 720 ? 220 : 60
			Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.separateur }
			Column {
				x: 10; y: 14
				width: parent.width - 20
				spacing: 2
				Repeater {
					model: fenetre.sections
					Item {
						required property var modelData
						readonly property bool actif: fenetre.section === modelData.id
						width: parent.width; height: 36
						Rectangle {
							anchors.fill: parent
							visible: parent.actif
							gradient: Gradient {
								orientation: Gradient.Horizontal
								GradientStop { position: 0; color: Qt.alpha(Theme.bouton, 0.5) }
								GradientStop { position: 1; color: "transparent" }
							}
						}
						Rectangle { width: 3; height: parent.height; color: parent.actif ? Theme.accent : "transparent" }
						Icone { x: 14; anchors.verticalCenter: parent.verticalCenter; chemin: modelData.ic; taille: 15; couleur: parent.actif ? Theme.accent : Theme.texteDiscret }
						Texte { x: 40; anchors.verticalCenter: parent.verticalCenter; visible: nav.width > 100; text: modelData.n; taille: 14; color: parent.actif ? "#ffffff" : "#9fd0e4" }
						MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fenetre.section = modelData.id }
					}
				}
			}
			Texte {
				visible: nav.width > 100
				anchors { left: parent.left; leftMargin: 20; bottom: parent.bottom; bottomMargin: 14 }
				text: "config : ~/.config/supercalc"
				taille: 11; color: Theme.texteEteint
			}
		}

		// ---------------- contenu ----------------
		Flickable {
			id: defil
			anchors { left: nav.right; right: parent.right; top: parent.top; bottom: pied.top; margins: 22 }
			contentHeight: pile.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			Column {
				id: pile
				width: defil.width
				spacing: 22

				Item {
					width: parent.width; height: 20
					Libelle { text: fenetre.sections.find(s => s.id === fenetre.section)?.n ?? ""; taille: 13; color: Theme.texteTitre }
					Texte { anchors.right: parent.right; text: "● appliqué en direct"; taille: 12; color: Theme.energie }
				}

				// ======== apparence ========
				Column {
					visible: fenetre.section === "apparence"
					width: parent.width
					spacing: 22

					Column {
						width: parent.width; spacing: 10
						Libelle { text: "Couleur d'accent"; taille: 10; color: Theme.texteEteint }
						Row {
							spacing: 8
							Repeater {
								model: [
									{ id: "ambre", n: "Ambre", h: "supercalc" }, { id: "energie", n: "Énergie", h: "vert" },
									{ id: "holomap", n: "Holomap", h: "cyan" }, { id: "xana", n: "XANA", h: "rouge" }
								]
								Rectangle {
									required property var modelData
									readonly property bool choisi: Reglages.accent === modelData.id
									width: 140; height: 46
									color: choisi ? Qt.alpha(Theme.bouton, 0.35) : "transparent"
									border { width: 1; color: choisi ? Theme.lisere : Theme.separateur }
									Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; color: Theme.accents[modelData.id] }
									Column {
										x: 40; anchors.verticalCenter: parent.verticalCenter
										Libelle { text: modelData.n; taille: 10 }
										Texte { text: modelData.h; taille: 11; color: Theme.texteDiscret }
									}
									MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Reglages.accent = modelData.id }
								}
							}
						}
					}

					Reglette {
						width: parent.width
						nom: "Halo des panneaux"
						valeur: Reglages.halo
						aide: "lueur autour des surfaces · 0 pour la désactiver"
						onRegle: v => Reglages.halo = v
					}
					Reglette {
						width: parent.width
						nom: "Opacité des panneaux"
						valeur: Reglages.opacite
						min: 0.6
						aide: "sway ne floute pas l'arrière-plan : garde une opacité haute pour la lisibilité"
						onRegle: v => Reglages.opacite = v
					}

					Column {
						width: parent.width; spacing: 10
						Libelle { text: "Biseaux des cadres"; taille: 10; color: Theme.texteEteint }
						Row {
							spacing: 8
							Repeater {
								model: [{ v: 0, n: "Aucun" }, { v: 8, n: "8 px" }, { v: 14, n: "14 px" }]
								Pastille {
									required property var modelData
									readonly property bool choisi: Reglages.biseau === modelData.v
									implicitHeight: 30
									coupeHD: modelData.v / 2
									fond: choisi ? Theme.lisere : Theme.tuile
									encre: choisi ? Theme.encre : "#9fd0e4"
									texte: modelData.n
									cliquable: true
									onClique: Reglages.biseau = modelData.v
								}
							}
						}
					}

					Column {
						width: parent.width; spacing: 4
						Libelle { text: "Animations"; taille: 10; color: Theme.texteEteint; bottomPadding: 6 }
						Interrupteur { width: parent.width; nom: "Animations des surfaces"; aide: "ouverture, fondu et glissement des panneaux"; actif: Reglages.animations; onBascule: Reglages.animations = !Reglages.animations }
						Interrupteur { width: parent.width; nom: "Mode jeu"; aide: "coupe halo et animations (super + g)"; actif: Reglages.modeJeu; onBascule: Reglages.modeJeu = !Reglages.modeJeu }
					}
				}

				// ======== écrans ========
				Column {
					visible: fenetre.section === "ecrans"
					width: parent.width
					spacing: 12
					Texte { width: parent.width; wrapMode: Text.Wrap; text: "L'écran principal reçoit la zone système de la barre et le dock. En automatique : l'écran interne d'un portable, sinon le plus à gauche."; taille: 13; color: Theme.texteDiscret }
					Repeater {
						model: [{ nom: "", auto: true }].concat(Sway.sorties)
						Rectangle {
							required property var modelData
							readonly property bool choisi: Reglages.ecranPrincipal === (modelData.auto ? "" : modelData.nom)
							width: pile.width; height: 50
							color: choisi ? Qt.alpha(Theme.bouton, 0.35) : "transparent"
							border { width: 1; color: choisi ? Theme.lisere : Theme.separateur }
							Icone { x: 14; anchors.verticalCenter: parent.verticalCenter; chemin: modelData.auto ? Icones.secteur : Icones.moniteur; taille: 18; couleur: choisi ? Theme.accent : Theme.texteAccent }
							Column {
								x: 46; anchors.verticalCenter: parent.verticalCenter
								Libelle { text: modelData.auto ? "Automatique" : modelData.nom; taille: 11 }
								Texte {
									taille: 12; color: Theme.texteDiscret
									text: modelData.auto ? `actuellement ${Etat.nomPrincipal}`
										: [`${modelData.largeur} × ${modelData.hauteur}`, modelData.frequence ? `${modelData.frequence} Hz` : "", modelData.echelle !== 1 ? `échelle ${modelData.echelle}` : "", [modelData.marque, modelData.modele].filter(x => x && x !== "Unknown").join(" ")].filter(x => x).join(" · ")
								}
							}
							Libelle { anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } text: choisi ? "principal" : ""; taille: 9; color: Theme.accent }
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Reglages.ecranPrincipal = modelData.auto ? "" : modelData.nom }
						}
					}
					Texte { width: parent.width; wrapMode: Text.Wrap; text: "Résolution, position et échelle se règlent dans sway (« output … » dans ~/.config/sway/config.d/)."; taille: 12; color: Theme.texteEteint }
				}

				// ======== dock ========
				Column {
					visible: fenetre.section === "dock"
					width: parent.width
					spacing: 8
					Texte { width: parent.width; wrapMode: Text.Wrap; text: "Applications épinglées au dock, dans l'ordre. Épingler : ctrl + p dans le lanceur."; taille: 13; color: Theme.texteDiscret }
					Repeater {
						model: Reglages.dock
						Rectangle {
							required property string modelData
							required property int index
							readonly property var entree: Applis.entree(modelData)
							width: pile.width; height: 42
							color: "transparent"
							border { width: 1; color: Theme.separateur }
							Icone { x: 14; anchors.verticalCenter: parent.verticalCenter; chemin: Applis.icone(entree, modelData); taille: 16; couleur: Theme.texteAccent }
							Texte { x: 44; anchors.verticalCenter: parent.verticalCenter; text: entree ? `${entree.name}  ·  ${modelData}` : modelData; taille: 13 }
							Row {
								anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
								spacing: 4
								Repeater {
									model: [{ t: "▲", d: -1 }, { t: "▼", d: 1 }, { t: "×", d: 0 }]
									Rectangle {
										required property var modelData
										width: 26; height: 26
										color: zoneD.containsMouse ? Theme.bouton : Theme.tuile
										Texte { anchors.centerIn: parent; text: modelData.t; taille: 12; color: modelData.d === 0 ? Theme.xanaTexte : Theme.texteTitre }
										MouseArea {
											id: zoneD
											anchors.fill: parent; hoverEnabled: true
											onClicked: {
												const d = Reglages.dock.slice(), i = index;
												if (modelData.d === 0) d.splice(i, 1);
												else { const j = i + modelData.d; if (j < 0 || j >= d.length) return; [d[i], d[j]] = [d[j], d[i]]; }
												Reglages.dock = d;
											}
										}
									}
								}
							}
						}
					}
				}

				// ======== session ========
				Column {
					visible: fenetre.section === "session"
					width: parent.width
					spacing: 4
					Interrupteur { width: parent.width; nom: "Séquence de transfert"; aide: "carte d'identité, scanner et virtualisation à l'ouverture de session"; actif: Reglages.sequenceTransfert; onBascule: Reglages.sequenceTransfert = !Reglages.sequenceTransfert }
					Interrupteur { width: parent.width; nom: "Mode silencieux"; aide: "seules les notifications critiques s'affichent"; actif: Notifs.silencieux; onBascule: Notifs.silencieux = !Notifs.silencieux }
					Interrupteur { width: parent.width; nom: "Veille automatique"; aide: `verrouiller après ${Controle.delaiVeille} d'inactivité (swayidle)`; actif: Controle.veille; onBascule: Controle.basculerVeille() }
					Interrupteur { width: parent.width; nom: "Lumière nuit"; aide: `écran plus chaud jusqu'à ${Controle.finNuit} (wlsunset)`; actif: Controle.nuit; onBascule: Controle.basculerNuit() }
					Pastille {
						implicitHeight: 30
						texte: "Revoir la séquence de transfert"
						cliquable: true
						onClique: { Etat.fermer(); Etat.ouvrir("transfert"); }
					}
				}

				// ======== à propos ========
				Column {
					visible: fenetre.section === "apropos"
					width: parent.width
					spacing: 8
					Text { text: "SUPERCALC"; font.family: Theme.policeAffiche; font.pixelSize: 28; font.letterSpacing: 4; color: Theme.accent }
					Texte { text: "bureau sway + Quickshell inspiré du supercalculateur de Code Lyoko et d'IFSCL"; taille: 13; color: Theme.texteDiscret }
					Item { width: 1; height: 8 }
					Repeater {
						model: [
							{ c: "compositeur", v: fenetre.sway || "…" },
							{ c: "shell", v: fenetre.qs || "…" },
							{ c: "écrans", v: Sway.sorties.map(s => `${s.nom} ${s.largeur}×${s.hauteur}`).join(" · ") },
							{ c: "polices", v: "Gunship (Iconian Fonts) · Share Tech Mono (OFL)" },
							{ c: "réglages", v: Quickshell.statePath("reglages.json") },
						]
						Item {
							required property var modelData
							width: pile.width; height: 22
							Texte { text: modelData.c; taille: 13; color: Theme.texteDiscret }
							Texte { x: 130; width: parent.width - 130; text: modelData.v; taille: 13; color: Theme.texte }
						}
					}
				}
			}
		}

		Item {
			id: pied
			anchors { left: nav.right; right: parent.right; bottom: parent.bottom; margins: 22; bottomMargin: 12 }
			height: 30
			Texte { anchors.verticalCenter: parent.verticalCenter; text: "écrit dans reglages.json · appliqué sans redémarrer"; taille: 12; color: Theme.texteEteint; width: parent.width - boutonDefaut.width - 20 }
			Pastille {
				id: boutonDefaut
				anchors { right: parent.right; verticalCenter: parent.verticalCenter }
				implicitHeight: 28
				fond: Theme.boutonSombre
				texte: "Par défaut"
				cliquable: true
				onClique: Reglages.parDefaut()
			}
		}
	}

	// ---------------- petits composants locaux ----------------
	component Reglette: Column {
		id: reglette
		property string nom
		property string aide
		property real valeur
		property real min: 0
		signal regle(real v)
		spacing: 8
		Item {
			width: parent.width; height: 14
			Libelle { text: reglette.nom; taille: 10; color: Theme.texteEteint }
			Texte { anchors.right: parent.right; text: Math.round(reglette.valeur * 100) + " %"; taille: 13; color: Theme.accent }
		}
		Item {
			width: parent.width; height: 12
			Segments { anchors.fill: parent; nombre: 24; hauteur: 12; valeur: (reglette.valeur - reglette.min) / (1 - reglette.min) }
			MouseArea {
				anchors { fill: parent; margins: -6 }
				cursorShape: Qt.PointingHandCursor
				function v(x) { return reglette.min + (1 - reglette.min) * Math.max(0, Math.min(1, Math.ceil((x - 6) / (width - 12) * 24) / 24)); }
				onPressed: m => reglette.regle(v(m.x))
				onPositionChanged: m => { if (pressed) reglette.regle(v(m.x)); }
			}
		}
		Texte { text: reglette.aide; taille: 12; color: Theme.texteDiscret }
	}

	component Interrupteur: Item {
		id: inter
		property string nom
		property string aide
		property bool actif
		signal bascule()
		height: 50
		Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(Theme.separateur, 0.6) }
		Column {
			anchors.verticalCenter: parent.verticalCenter
			spacing: 3
			Texte { text: inter.nom; taille: 14; color: Theme.texteTitre }
			Texte { text: inter.aide; taille: 12; color: Theme.texteDiscret }
		}
		Rectangle {
			anchors { right: parent.right; verticalCenter: parent.verticalCenter }
			width: 44; height: 22
			color: inter.actif ? Theme.bouton : Theme.champ
			border { width: 1; color: inter.actif ? Theme.lisere : Theme.bordure }
			Rectangle {
				width: 16; height: 16; y: 3
				x: inter.actif ? parent.width - width - 3 : 3
				color: inter.actif ? "#ffffff" : Theme.texteEteint
				Behavior on x { NumberAnimation { duration: Theme.dureeCourte } }
			}
		}
		MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: inter.bascule() }
	}
}
