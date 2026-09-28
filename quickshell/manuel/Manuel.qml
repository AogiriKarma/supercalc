import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.composants
import qs.services

// Manuel de l'opérateur (Super+F1) : construit en lisant sway/raccourcis.conf, puis
// ~/.config/sway/config.d/local.conf pour les raccourcis propres à la machine.
// Chaque « #: catégorie | description [| touches] » documente la ligne bind qui suit.
PanelWindow {
	id: fenetre
	screen: Etat.ecranCible
	visible: ouvert || fondu.running || cadre.anime
	anchors { top: true; bottom: true; left: true; right: true }
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.namespace: "supercalc-manuel"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: ouvert ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	readonly property bool ouvert: Etat.panneau === "manuel"
	onOuvertChanged: if (ouvert) { champ.text = ""; fichier.reload(); champ.forceActiveFocus(); }

	// ---------------- lecture de la config ----------------
	FileView {
		id: fichier
		path: Quickshell.env("HOME") + "/.config/supercalc/sway/raccourcis.conf"
		watchChanges: true
		onFileChanged: reload()
	}
	// Raccourcis propres à la machine : ceux annotés d'un « #: » y sont lus aussi, pour que
	// le manuel reste complet. Le fichier peut ne pas exister, d'où le repli silencieux.
	FileView {
		id: fichierLocal
		path: Quickshell.env("HOME") + "/.config/sway/config.d/local.conf"
		watchChanges: true
		onFileChanged: reload()
		onLoadFailed: () => {}
	}

	readonly property var noms: ({
		"$mod": "SUPER", "Mod4": "SUPER", "Shift": "MAJ", "Alt": "ALT", "Mod1": "ALT", "Ctrl": "CTRL", "Control": "CTRL",
		"Return": "ENTRÉE", "Escape": "ÉCHAP", "BackSpace": "RETOUR", "space": "ESPACE", "Tab": "TAB", "Print": "IMPR",
		"equal": "=", "comma": ",", "period": ".", "minus": "−", "slash": "/", "Left": "←", "Right": "→", "Up": "↑", "Down": "↓"
	})
	function touches(combo) { return combo.split("+").map(t => noms[t] ?? t.toUpperCase()); }

	readonly property var raccourcis: {
		const res = [];
		let note = null;
		for (const brut of (fichier.text() + "\n" + fichierLocal.text()).split("\n")) {
			const l = brut.trim();
			const m = l.match(/^#:\s*([^|]+)\|([^|]+)(?:\|(.+))?$/);
			if (m) { note = { cat: m[1].trim(), desc: m[2].trim(), touches: m[3] ? m[3].trim().split(/\s+/) : null }; continue; }
			const b = l.match(/^(bindsym|bindcode)\s+(?:--\S+\s+)*(\S+)/);
			if (b && note) {
				res.push({ cat: note.cat, desc: note.desc, touches: note.touches ?? touches(b[2]) });
				note = null;
			}
		}
		return res;
	}
	readonly property var categories: {
		const ordre = ["fenêtres", "secteurs", "outils", "système"];
		const vues = [...new Set(raccourcis.map(r => r.cat))];
		return vues.sort((a, b) => ((ordre.indexOf(a) + 1) || 99) - ((ordre.indexOf(b) + 1) || 99));
	}
	property string filtre: ""
	function garde(r) {
		if (!filtre) return true;
		const q = filtre.toLowerCase();
		return r.desc.toLowerCase().includes(q) || r.cat.toLowerCase().includes(q) || r.touches.join(" ").toLowerCase().includes(q);
	}
	readonly property int nbVisibles: raccourcis.filter(garde).length
	readonly property var icones: ({ "fenêtres": Icones.fenetre, "secteurs": Icones.secteur, "outils": Icones.crayon, "système": Icones.reglages })

	// ---------------- rendu ----------------
	Rectangle {
		anchors.fill: parent
		color: "#020a0e"
		opacity: fenetre.ouvert ? 0.7 : 0
		Behavior on opacity { NumberAnimation { id: fondu; duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }
		MouseArea { anchors.fill: parent; onClicked: Etat.fermer() }
	}

	Fenetre {
		id: cadre
		ouvre: fenetre.ouvert
		titre: "Manuel de l'opérateur"
		width: Math.min(1340, fenetre.width - 64)
		height: Math.min(contenu.implicitHeight + Theme.titreHauteur + Theme.bandeHauteur + 40, fenetre.height - Theme.barreHauteur - 60)
		x: (fenetre.width - width) / 2
		y: Math.max(Theme.barreHauteur + 24, (fenetre.height - height) / 2)
		// opacité pilotée par Fenetre, pour l'enchaîner avec le dépliage
		MouseArea { anchors.fill: parent }

		Flickable {
			anchors { fill: parent; margins: 20 }
			contentHeight: contenu.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			Column {
				id: contenu
				width: parent.width
				spacing: 18

				// en-tête : filtre + légende
				Item {
					width: parent.width; height: 34
					Rectangle {
						id: boite
						width: Math.min(380, parent.width * 0.45); height: 34
						color: Theme.champ
						border { width: 1; color: Theme.bordureVive }
						Icone { id: loupe; x: 12; anchors.verticalCenter: parent.verticalCenter; chemin: Icones.recherche; taille: 14; couleur: Theme.texteAccent }
						TextInput {
							id: champ
							anchors { left: loupe.right; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
							font.family: Theme.policeTexte; font.pixelSize: 14
							color: Theme.texteTitre
							clip: true
							onTextChanged: fenetre.filtre = text
							Keys.onEscapePressed: Etat.fermer()
							Texte { visible: champ.text === ""; text: "filtrer : capture, secteur, volume…"; taille: 14; color: Theme.texteEteint; anchors.verticalCenter: parent.verticalCenter }
						}
					}
					Pastille {
						anchors { left: boite.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
						implicitHeight: 26
						fond: Theme.lisere; encre: Theme.encre
						texte: `Tout · ${fenetre.nbVisibles}`
					}
					Row {
						anchors { right: parent.right; verticalCenter: parent.verticalCenter }
						spacing: 8
						Touche { texte: "SUPER"; anchors.verticalCenter: parent.verticalCenter }
						Texte { text: "= touche logo"; taille: 13; color: Theme.texteDiscret; anchors.verticalCenter: parent.verticalCenter }
					}
				}

				// colonnes par catégorie
				Grid {
					id: grille
					width: parent.width
					columns: Math.max(1, Math.min(fenetre.categories.length, Math.floor(width / 290)))
					columnSpacing: 28
					rowSpacing: 18
					Repeater {
						model: fenetre.categories
						Column {
							id: colonne
							required property string modelData
							readonly property var lignes: fenetre.raccourcis.filter(r => r.cat === modelData && fenetre.garde(r))
							width: (grille.width - (grille.columns - 1) * grille.columnSpacing) / grille.columns
							spacing: 2
							visible: lignes.length > 0
							Item {
								width: parent.width; height: 28
								Row {
									id: tete
									spacing: 8
									anchors.verticalCenter: parent.verticalCenter
									Icone { chemin: fenetre.icones[colonne.modelData] ?? Icones.secteur; taille: 14; couleur: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
									Libelle { text: colonne.modelData; color: Theme.texteAccent; anchors.verticalCenter: parent.verticalCenter }
								}
								Rectangle { anchors { left: tete.right; leftMargin: 10; right: compte.left; rightMargin: 10; verticalCenter: parent.verticalCenter } height: 1; color: Theme.separateur }
								Texte { id: compte; anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: String(colonne.lignes.length); taille: 12; color: Theme.texteEteint }
							}
							Repeater {
								model: colonne.lignes
								Item {
									required property var modelData
									width: colonne.width; height: 30
									Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Qt.alpha(Theme.separateur, 0.5) }
									Texte {
										anchors { left: parent.left; right: rangee.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
										text: modelData.desc; taille: 13; color: Theme.texte
									}
									Row {
										id: rangee
										anchors { right: parent.right; verticalCenter: parent.verticalCenter }
										spacing: 4
										Repeater {
											model: modelData.touches.filter(t => t !== "·")
											Touche { required property string modelData; texte: modelData }
										}
									}
								}
							}
						}
					}
				}

				// astuces
				Grid {
					width: parent.width
					columns: Math.max(1, Math.min(3, Math.floor(width / 360)))
					spacing: 12
					Repeater {
						model: [
							{ t: "Souris", b: "super + clic gauche déplace une fenêtre flottante, super + clic droit la redimensionne." },
							{ t: "Holomap", b: "glisser une fenêtre sur un autre secteur la déplace ; clic milieu la ferme." },
							{ t: "Urgence", b: "un clic sur le témoin XANA de la barre mène à la fenêtre qui réclame ton attention." },
						]
						Rectangle {
							required property var modelData
							width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
							height: 58
							color: Qt.alpha(Theme.bouton, 0.12)
							border { width: 1; color: Theme.separateur }
							Rectangle { width: 2; height: parent.height; color: Theme.accent }
							Column {
								anchors { fill: parent; leftMargin: 14; rightMargin: 12; topMargin: 9 }
								spacing: 4
								Libelle { text: modelData.t; taille: 10; color: Theme.accent }
								Texte { width: parent.width; text: modelData.b; taille: 12; color: Theme.texteDiscret; wrapMode: Text.Wrap; maximumLineCount: 2 }
							}
						}
					}
				}
			}
		}
	}
}
