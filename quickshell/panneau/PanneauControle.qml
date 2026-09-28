import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import qs.theme
import qs.composants
import qs.services

// Panneau de contrôle (Super+N ou clic sur la cloche) : à droite de l'écran actif, sous la barre.
PanelWindow {
	id: fenetre
	screen: Etat.ecranCible
	visible: ouvert || fondu.running
	anchors { top: true; bottom: true; left: true; right: true }
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.namespace: "supercalc-panneau"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: ouvert ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

	readonly property bool ouvert: Etat.panneau === "panneau"
	onOuvertChanged: if (ouvert) { Controle.relire(); Notifs.marquerLues(); cadre.forceActiveFocus(); }

	readonly property var lecteur: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

	// clic en dehors : fermer
	MouseArea { anchors.fill: parent; enabled: fenetre.ouvert; onClicked: Etat.fermer() }

	Fenetre {
		id: cadre
		titre: "Panneau de contrôle"
		width: Math.min(420, fenetre.width - 2 * Theme.marge)
		height: Math.min(colonne.implicitHeight + Theme.titreHauteur + Theme.bandeHauteur + 36, fenetre.height - y - Theme.marge)
		x: fenetre.width - width - Theme.marge + (fenetre.ouvert ? 0 : 24)
		y: Theme.barreHauteur + 16
		opacity: fenetre.ouvert ? 1 : 0
		Behavior on opacity { NumberAnimation { id: fondu; duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }
		Behavior on x { NumberAnimation { duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }
		focus: true
		Keys.onEscapePressed: Etat.fermer()

		MouseArea { anchors.fill: parent }   // les clics dans le cadre ne ferment pas

		Flickable {
			anchors { fill: parent; margins: 18 }
			contentHeight: colonne.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			Column {
				id: colonne
				width: parent.width
				spacing: 16

				// ---------------- session ----------------
				Row {
					width: parent.width
					spacing: 12
					Chanfrein {
						width: 42; height: 42; hd: 9
						couleur: Theme.accent
						Icone { anchors.centerIn: parent; chemin: Icones.secteur; taille: 22; trait: 1.6; couleur: Theme.encre }
					}
					Column {
						width: parent.width - 42 - 3 * 34 - 4 * parent.spacing
						anchors.verticalCenter: parent.verticalCenter
						spacing: 2
						Text { text: Controle.utilisateur; font.family: Theme.policeTitre; font.pixelSize: 16; font.letterSpacing: 2; color: Theme.texteTitre; elide: Text.ElideRight; width: parent.width }
						Texte { text: `${Controle.machine} · en ligne ${Controle.enLigne}`; taille: 12; color: Theme.texteDiscret; width: parent.width }
					}
					Repeater {
						model: [
							{ n: "Verrouiller", ic: Icones.verrou, xana: false, f: () => Etat.verrouiller() },
							{ n: "Réglages", ic: Icones.reglages, xana: false, f: () => Etat.ouvrir("reglages") },
							{ n: "Menu d'énergie", ic: Icones.arret, xana: true, f: () => Etat.ouvrir("power") },
						]
						Rectangle {
							required property var modelData
							width: 34; height: 34
							anchors.verticalCenter: parent.verticalCenter
							color: modelData.xana ? Theme.xanaCorps : zone.containsMouse ? Theme.tuile : "transparent"
							border { width: 1; color: modelData.xana ? "#7a2a2e" : Theme.bordure }
							Icone { anchors.centerIn: parent; chemin: modelData.ic; taille: 16; couleur: modelData.xana ? Theme.xanaTexte : "#bfeefc" }
							MouseArea { id: zone; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.f() }
						}
					}
				}

				// ---------------- bascules ----------------
				Grid {
					id: grille
					width: parent.width
					columns: 2
					spacing: 8
					Repeater {
						model: [
							{ n: "Wifi", s: Controle.etatWifi, ic: Icones.wifi, on: Controle.reseauDispo && wifiActif(), dispo: Controle.reseauDispo && Controle.carteWifi !== null, f: () => Controle.basculerWifi() },
							{ n: "Bluetooth", s: Controle.etatBt, ic: Icones.bluetooth, on: !!Controle.adaptateur?.enabled, dispo: Controle.adaptateur !== null, f: () => Controle.basculerBt() },
							{ n: "Silencieux", s: Notifs.silencieux ? "critiques seulement" : "désactivé", ic: Icones.silence, on: Notifs.silencieux, dispo: true, f: () => { Notifs.silencieux = !Notifs.silencieux; } },
							{ n: "Lumière nuit", s: Controle.nuit ? `active → ${Controle.finNuit}` : "désactivée", ic: Icones.lune, on: Controle.nuit, dispo: true, f: () => Controle.basculerNuit() },
							{ n: "Veille auto", s: Controle.veille ? `après ${Controle.delaiVeille}` : "désactivée", ic: Icones.veille, on: Controle.veille, dispo: true, f: () => Controle.basculerVeille() },
							{ n: "Mode jeu", s: Reglages.modeJeu ? "effets coupés" : "désactivé", ic: Icones.eclair, on: Reglages.modeJeu, dispo: true, f: () => { Reglages.modeJeu = !Reglages.modeJeu; } },
						]
						Item {
							id: tuile
							required property var modelData
							width: (grille.width - grille.spacing) / 2
							height: 52
							opacity: modelData.dispo ? 1 : 0.5
							Chanfrein {
								anchors.fill: parent
								hd: 8
								couleur: tuile.modelData.on ? "#bfeefc" : Theme.separateur
								Chanfrein {
									anchors { fill: parent; margins: 1 }
									hd: 7
									couleur: tuile.modelData.on ? Theme.bouton : Theme.corps
									Rectangle {
										anchors.fill: parent
										visible: tuile.modelData.on
										gradient: Gradient {
											orientation: Gradient.Horizontal
											GradientStop { position: 0; color: Theme.bouton }
											GradientStop { position: 1; color: Theme.boutonSombre }
										}
									}
									Rectangle { anchors.fill: parent; color: "white"; opacity: zoneTuile.containsMouse ? 0.05 : 0 }
								}
							}
							Row {
								anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
								spacing: 10
								Rectangle {
									width: 30; height: 30
									anchors.verticalCenter: parent.verticalCenter
									color: tuile.modelData.on ? Theme.lisere : Theme.tuile
									Icone { anchors.centerIn: parent; chemin: tuile.modelData.ic; taille: 16; couleur: tuile.modelData.on ? Theme.encre : Theme.texteDiscret }
								}
								Column {
									width: parent.width - 40
									anchors.verticalCenter: parent.verticalCenter
									spacing: 3
									Libelle { text: tuile.modelData.n; taille: 10; color: tuile.modelData.on ? "#ffffff" : "#8fc3d8" }
									Texte { text: tuile.modelData.s; taille: 12; color: tuile.modelData.on ? "#bfeefc" : Theme.texteEteint; width: parent.width }
								}
							}
							MouseArea {
								id: zoneTuile
								anchors.fill: parent
								enabled: tuile.modelData.dispo
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: tuile.modelData.f()
							}
						}
					}
				}

				// ---------------- curseurs ----------------
				Column {
					width: parent.width
					spacing: 10
					Curseur {
						width: parent.width
						nom: "Volume"
						icone: Controle.sortie?.audio?.muted ? Icones.volumeMuet : Icones.volume
						dispo: !!Controle.sortie?.audio
						valeur: Controle.sortie?.audio?.volume ?? 0
						coupe: !!Controle.sortie?.audio?.muted
						onRegle: v => { Controle.sortie.audio.muted = false; Controle.sortie.audio.volume = v; }
						onIconeClique: Controle.sortie.audio.muted = !Controle.sortie.audio.muted
					}
					Curseur {
						width: parent.width
						nom: "Micro"
						icone: Controle.entree?.audio?.muted ? Icones.microCoupe : Icones.micro
						dispo: !!Controle.entree?.audio
						valeur: Controle.entree?.audio?.volume ?? 0
						coupe: !!Controle.entree?.audio?.muted
						onRegle: v => { Controle.entree.audio.muted = false; Controle.entree.audio.volume = v; }
						onIconeClique: Controle.entree.audio.muted = !Controle.entree.audio.muted
					}
					Curseur {
						width: parent.width
						nom: "Écran"
						icone: Icones.ecran
						dispo: Controle.luminosite >= 0
						valeur: Math.max(0, Controle.luminosite)
						onRegle: v => Controle.reglerLuminosite(v)
					}
					// sortie audio : clic = suivante
					Rectangle {
						width: parent.width; height: 30
						color: zoneSortie.containsMouse ? Theme.tuile : Theme.champ
						border { width: 1; color: Theme.separateur }
						Libelle { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "Sortie"; taille: 10; color: Theme.texteEteint }
						Texte {
							anchors { left: parent.left; leftMargin: 80; right: fleche.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
							text: Controle.nomNoeud(Controle.sortie); taille: 13; color: Theme.texte
						}
						Texte { id: fleche; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: Controle.sorties.length > 1 ? "▸" : ""; color: Theme.texteAccent }
						MouseArea { id: zoneSortie; anchors.fill: parent; hoverEnabled: true; onClicked: Controle.sortieSuivante() }
					}
				}

				// ---------------- énergie ----------------
				Rectangle {
					visible: Controle.aBatterie
					width: parent.width; height: 46
					color: Theme.champ
					border { width: 1; color: Theme.separateur }
					Icone { id: icBat; x: 12; anchors.verticalCenter: parent.verticalCenter; chemin: Systeme.enCharge ? Icones.eclair : Icones.batterie; taille: 18; couleur: Theme.energie }
					Column {
						anchors { left: icBat.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
						spacing: 2
						Libelle { text: `${Math.round(Systeme.niveau * 100)} PV · ${Systeme.enCharge ? "sur secteur" : "sur batterie"}`; taille: 10; color: Theme.energie }
						Texte {
							taille: 12; color: Theme.texteDiscret
							text: {
								const s = Systeme.secondesRestantes;
								if (!s) return Systeme.enCharge ? "en charge" : "estimation en cours";
								const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
								const w = Controle.batterie?.changeRate ? ` · ${Math.abs(Controle.batterie.changeRate).toFixed(1)} W` : "";
								return `${h} h ${String(m).padStart(2, "0")} ${Systeme.enCharge ? "avant la charge complète" : "restantes"}${w}`;
							}
						}
					}
					Pastille {
						anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
						implicitHeight: 24
						texte: Controle.profil + " ▸"
						fond: Theme.boutonSombre
						cliquable: true
						onClique: Controle.profilSuivant()
					}
				}

				// ---------------- média ----------------
				Rectangle {
					visible: fenetre.lecteur !== null
					width: parent.width; height: 64
					color: Theme.champ
					border { width: 1; color: Theme.separateur }
					Chanfrein {
						id: pochette
						x: 10; width: 44; height: 44; hd: 8
						anchors.verticalCenter: parent.verticalCenter
						couleur: Theme.tuile
						Image {
							anchors.fill: parent
							source: fenetre.lecteur?.trackArtUrl ?? ""
							fillMode: Image.PreserveAspectCrop
							visible: status === Image.Ready
							asynchronous: true
						}
						Icone { anchors.centerIn: parent; visible: !(fenetre.lecteur?.trackArtUrl); chemin: Icones.musique; taille: 18; couleur: Theme.texteAccent }
					}
					Column {
						anchors { left: pochette.right; leftMargin: 12; right: boutons.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
						spacing: 3
						Texte { width: parent.width; text: fenetre.lecteur?.trackTitle || "—"; taille: 13; color: Theme.texteTitre }
						Texte { width: parent.width; text: [fenetre.lecteur?.trackArtist, fenetre.lecteur?.identity].filter(x => x).join(" · "); taille: 12; color: Theme.texteDiscret }
						Rectangle {
							width: parent.width; height: 3; color: Theme.separateur
							Rectangle { height: 3; color: Theme.accent; width: fenetre.lecteur && fenetre.lecteur.lengthSupported && fenetre.lecteur.length > 0 ? parent.width * fenetre.lecteur.position / fenetre.lecteur.length : 0 }
						}
					}
					Row {
						id: boutons
						anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
						spacing: 4
						Repeater {
							model: [
								{ t: "◂◂", f: () => fenetre.lecteur.previous(), ok: fenetre.lecteur?.canGoPrevious },
								{ t: fenetre.lecteur?.isPlaying ? "▮▮" : "▶", f: () => fenetre.lecteur.togglePlaying(), ok: fenetre.lecteur?.canTogglePlaying },
								{ t: "▸▸", f: () => fenetre.lecteur.next(), ok: fenetre.lecteur?.canGoNext },
							]
							Rectangle {
								required property var modelData
								width: 28; height: 28
								color: Theme.boutonSombre
								opacity: modelData.ok ? 1 : 0.4
								border { width: 1; color: Theme.bordure }
								Texte { anchors.centerIn: parent; text: modelData.t; taille: 11; color: "#ffffff" }
								MouseArea { anchors.fill: parent; enabled: !!modelData.ok; cursorShape: Qt.PointingHandCursor; onClicked: modelData.f() }
							}
						}
					}
				}

				// ---------------- journal ----------------
				Column {
					width: parent.width
					spacing: 6
					Item {
						width: parent.width; height: 22
						Libelle { anchors.verticalCenter: parent.verticalCenter; text: `Journal // ${Notifs.journal.length}`; taille: 10; color: Theme.texteEteint }
						Pastille {
							visible: Notifs.journal.length > 0
							anchors { right: parent.right; verticalCenter: parent.verticalCenter }
							implicitHeight: 22; padding: 10
							texte: "Tout effacer"
							fond: Theme.boutonSombre
							cliquable: true
							onClique: Notifs.effacerTout()
						}
					}
					Texte {
						visible: Notifs.journal.length === 0
						text: "aucune notification"
						taille: 13; color: Theme.texteEteint
						topPadding: 4; bottomPadding: 4
					}
					Repeater {
						model: Notifs.journal.slice().reverse().slice(0, 12)
						Rectangle {
							id: entree
							required property var modelData
							readonly property bool critique: modelData.urgency === NotificationUrgency.Critical
							width: parent.width
							height: Math.max(48, texteEntree.implicitHeight + 16)
							color: critique ? Qt.rgba(40 / 255, 10 / 255, 14 / 255, 0.7) : Qt.rgba(18 / 255, 63 / 255, 82 / 255, 0.35)
							Rectangle { width: 2; height: parent.height; color: entree.critique ? Theme.xanaTexte : Theme.bordureVive }
							Icone { x: 12; y: 12; chemin: Notifs.icone(entree.modelData); taille: 16; couleur: entree.critique ? Theme.xanaTexte : Theme.texteAccent }
							Column {
								id: texteEntree
								anchors { left: parent.left; leftMargin: 40; right: croix.left; rightMargin: 6; top: parent.top; topMargin: 8 }
								spacing: 3
								Item {
									width: parent.width; height: 14
									Libelle { text: (entree.modelData.appName || "système") + " // " + entree.modelData.summary; taille: 10; color: entree.critique ? Theme.xanaTexte : Theme.texteTitre; width: parent.width - 50; elide: Text.ElideRight }
									Texte { anchors.right: parent.right; text: Notifs.heure(entree.modelData); taille: 11; color: Theme.texteEteint }
								}
								Texte { width: parent.width; text: entree.modelData.body; taille: 12; color: Theme.texteDiscret; wrapMode: Text.Wrap; maximumLineCount: 2; visible: text !== "" }
							}
							Texte {
								id: croix
								anchors { right: parent.right; rightMargin: 8; top: parent.top; topMargin: 6 }
								text: "×"; taille: 16; color: zoneCroix.containsMouse ? Theme.texteTitre : Theme.texteEteint
								MouseArea { id: zoneCroix; anchors { fill: parent; margins: -6 } hoverEnabled: true; onClicked: entree.modelData.dismiss() }
							}
						}
					}
				}
			}
		}
	}

	function wifiActif() { return Controle.reseauDispo && Controle.carteWifi !== null && Controle.etatWifi !== "désactivé"; }

	// MPRIS ne pousse pas la position : on la relit chaque seconde pendant la lecture
	Timer { interval: 1000; repeat: true; running: fenetre.lecteur?.isPlaying ?? false; onTriggered: fenetre.lecteur.positionChanged() }
}
