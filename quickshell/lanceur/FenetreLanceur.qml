import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.composants
import qs.services

// Launcher (Super+D): the SEARCH frame centred on the active screen, over a darkened background.
PanelWindow {
	id: fenetre
	screen: Etat.ecranCible
	visible: Etat.panneau === "lanceur" || fondu.running || cadre.anime
	anchors { top: true; bottom: true; left: true; right: true }
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.namespace: "supercalc-lanceur"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: Etat.panneau === "lanceur" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	readonly property bool ouvert: Etat.panneau === "lanceur"
	property int courant: 0
	property bool focusActions: false
	property int actionCourante: 0

	readonly property var resultats: Lanceur.resultats
	readonly property var selection: resultats[courant] ?? null

	onOuvertChanged: {
		if (ouvert) { Lanceur.reinitialiser(); champ.text = ""; courant = premierElement(0, 1); focusActions = false; champ.forceActiveFocus(); }
	}
	onResultatsChanged: { courant = premierElement(0, 1); focusActions = false; }

	function premierElement(depart, sens) {
		let i = depart;
		while (i >= 0 && i < resultats.length && resultats[i].type === "entete") i += sens;
		return i >= 0 && i < resultats.length ? i : (sens > 0 ? premierElement(resultats.length - 1, -1) : Math.max(0, depart));
	}
	function deplacer(sens) {
		let i = courant + sens;
		while (i >= 0 && i < resultats.length && resultats[i].type === "entete") i += sens;
		if (i >= 0 && i < resultats.length) courant = i;
	}
	function actionsDe(r) {
		if (!r) return [];
		const a = [];
		if (r.type === "appli") {
			a.push({ n: r.ouvertes.length ? "Aller à la fenêtre" : "Ouvrir", k: "ENTRÉE", f: () => Lanceur.executer(r, "") });
			if (r.ouvertes.length) a.push({ n: "Nouvelle fenêtre", k: "", f: () => { Lanceur.noter(r.cle); Applis.lancerEntree(r.entree); Etat.fermer(); } });
			a.push({ n: "Nouveau secteur", k: "CTRL ENTRÉE", f: () => Lanceur.executer(r, "secteur") });
			const epinglee = Reglages.dock.includes(r.cle);
			a.push({ n: epinglee ? "Retirer du dock" : "Épingler au dock", k: "CTRL P", f: () => basculerEpingle(r) });
			for (const act of r.entree.actions) a.push({ n: act.name, k: "", f: () => { act.execute(); Etat.fermer(); } });
		} else if (r.type === "fenetre") {
			a.push({ n: "Aller à la fenêtre", k: "ENTRÉE", f: () => Lanceur.executer(r, "") });
			a.push({ n: "Amener ici", k: "", f: () => { Sway.amener(r.fenetre.id); Etat.fermer(); } });
			a.push({ n: "Fermer la fenêtre", k: "", f: () => { Sway.fermer(r.fenetre.id); } });
		} else if (r.type === "fichier") {
			a.push({ n: "Ouvrir", k: "ENTRÉE", f: () => Lanceur.executer(r, "") });
			a.push({ n: "Ouvrir le dossier", k: "", f: () => { Quickshell.execDetached(["xdg-open", r.chemin.slice(0, r.chemin.lastIndexOf("/"))]); Etat.fermer(); } });
			a.push({ n: "Copier le chemin", k: "", f: () => { Quickshell.execDetached(["wl-copy", r.chemin]); Etat.fermer(); } });
		} else {
			const nom = { calcul: "Copier le résultat", shell: "Exécuter dans foot", web: "Rechercher" }[r.type] ?? "Exécuter";
			a.push({ n: nom, k: "ENTRÉE", f: () => Lanceur.executer(r, "") });
		}
		return a;
	}
	readonly property var actions: actionsDe(selection)

	function basculerEpingle(r) {
		const d = Reglages.dock.slice();
		const i = d.indexOf(r.cle);
		if (i >= 0) d.splice(i, 1); else d.push(r.cle);
		Reglages.dock = d;
	}

	// --- darkened background; a click outside closes ---
	Rectangle {
		anchors.fill: parent
		color: "#02080c"
		opacity: fenetre.ouvert ? 0.62 : 0
		Behavior on opacity { NumberAnimation { id: fondu; duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }
		MouseArea { anchors.fill: parent; onClicked: Etat.fermer() }
	}

	Item {
		id: bloc
		// adapts to the screen: 880 × 600 at most, and never more than 88 % × 80 %
		width: Math.min(880, fenetre.width * 0.88)
		height: Math.min(600, fenetre.height * 0.8 - 60)
		x: (fenetre.width - width) / 2
		y: Math.max(Theme.barreHauteur + 24, (fenetre.height - height - 60) * 0.38)
		// opacity and scale removed: Fenetre drives the opening, and stacking the two would bring
		// back the overlap we have just got rid of

		Fenetre {
			id: cadre
			ouvre: fenetre.ouvert
			anchors.fill: parent
			titre: "Recherche"
			sousTitre: Lanceur.prefixe === "=" ? "calcul" : Lanceur.prefixe === ">" ? "shell" : Lanceur.prefixe === "/" ? "fichiers" : Lanceur.prefixe === "?" ? "web" : ""

			// ---------------- header: field plus tabs ----------------
			Column {
				id: entete
				x: 20; y: 18
				width: parent.width - 40
				spacing: 12

				Rectangle {
					width: parent.width; height: 50
					color: Theme.champ
					border { width: 1; color: Theme.bordureVive }
					Rectangle { anchors { fill: parent; margins: -3 } color: "transparent"; border { width: 3; color: Qt.alpha(Theme.bordureVive, 0.12) } }
					Icone { id: loupe; x: 16; anchors.verticalCenter: parent.verticalCenter; chemin: Icones.recherche; taille: 20; couleur: Theme.texteAccent }
					TextInput {
						id: champ
						anchors { left: loupe.right; leftMargin: 14; right: infos.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
						font.family: Theme.policeTexte
						font.pixelSize: 22
						color: Theme.texteTitre
						selectionColor: Theme.bouton
						selectedTextColor: "#ffffff"
						clip: true
						focus: true
						onTextChanged: Lanceur.requete = text
						Connections {
							target: Lanceur
							function onRequeteChanged() { if (champ.text !== Lanceur.requete) { champ.text = Lanceur.requete; champ.cursorPosition = champ.text.length; } }
						}
						Texte {
							visible: champ.text === ""
							text: "applications, fenêtres, fichiers, commandes…"
							taille: 20
							color: Theme.texteEteint
							anchors.verticalCenter: parent.verticalCenter
						}
						Keys.onPressed: e => clavier(e)
					}
					Texte {
						id: infos
						anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
						taille: 13
						color: Theme.texteDiscret
						text: {
							const n = fenetre.resultats.filter(r => r.type !== "entete").length;
							return n === 0 ? (champ.text ? "aucun résultat" : "") : n + (n > 1 ? " résultats" : " résultat");
						}
					}
				}

				Item {
					width: parent.width; height: 24
					Row {
						spacing: 6
						visible: Lanceur.prefixe === ""
						Repeater {
							model: Lanceur.categories
							Pastille {
								id: onglet
								required property string modelData
								readonly property bool actif: Lanceur.categorie === modelData
								implicitHeight: 24
								coupeHD: 6
								fond: actif ? Theme.lisere : Theme.bouton
								encre: actif ? Theme.encre : "#e6f8ff"
								texte: Lanceur.nomsCategories[modelData]
								cliquable: true
								onClique: { Lanceur.categorie = modelData; champ.forceActiveFocus(); }
								Texte { text: Lanceur.comptes[modelData] ?? ""; taille: 11; color: onglet.encre; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
							}
						}
					}
					Text {
						anchors { right: parent.right; verticalCenter: parent.verticalCenter }
						textFormat: Text.StyledText
						font.family: Theme.policeTexte
						font.pixelSize: 13
						color: Theme.texteDiscret
						text: `<font color="${Theme.accent}">=</font> calcul  <font color="${Theme.accent}">&gt;</font> shell  <font color="${Theme.accent}">/</font> fichiers  <font color="${Theme.accent}">?</font> web`
					}
				}
			}
			Rectangle { id: filet; y: entete.y + entete.height + 14; width: parent.width; height: 1; color: Theme.separateur }

			// ---------------- results ----------------
			ListView {
				id: liste
				anchors { top: filet.bottom; bottom: parent.bottom; left: parent.left; right: detail.left; leftMargin: 20; rightMargin: 12; topMargin: 8; bottomMargin: 8 }
				clip: true
				model: fenetre.resultats
				currentIndex: fenetre.courant
				highlightFollowsCurrentItem: false
				boundsBehavior: Flickable.StopAtBounds
				spacing: 2
				onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

				delegate: Item {
					id: ligne
					required property var modelData
					required property int index
					readonly property bool entete: modelData.type === "entete"
					readonly property bool choisi: index === fenetre.courant
					width: liste.width
					height: entete ? 30 : 46

					// group header
					Item {
						visible: ligne.entete
						anchors.fill: parent
						Libelle { anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 5 } text: ligne.modelData.titre ?? ""; taille: 10; color: Theme.texteEteint }
						Libelle { anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 5 } text: String(ligne.modelData.compte ?? ""); taille: 10; color: Theme.texteEteint }
					}

					// item
					Item {
						visible: !ligne.entete
						anchors.fill: parent
						Rectangle {
							anchors.fill: parent
							visible: ligne.choisi || survol.containsMouse
							gradient: Gradient {
								orientation: Gradient.Horizontal
								GradientStop { position: 0; color: Qt.alpha(Theme.bouton, ligne.choisi ? 0.55 : 0.25) }
								GradientStop { position: 1; color: Qt.alpha(Theme.bouton, 0.06) }
							}
						}
						Rectangle { width: 3; height: parent.height; color: ligne.choisi ? Theme.accent : "transparent" }
						Chanfrein {
							id: tuile
							x: 12; width: 32; height: 32
							anchors.verticalCenter: parent.verticalCenter
							hd: 7
							couleur: ligne.choisi ? Theme.accent : Theme.bordure
							Chanfrein {
								anchors { fill: parent; margins: 1 }
								hd: 6
								couleur: ligne.choisi ? Theme.accent : Theme.tuile
							}
							Icone {
								anchors.centerIn: parent
								chemin: ligne.modelData.icone ?? ""
								taille: 16
								couleur: ligne.choisi ? Theme.encre : Theme.texteAccent
							}
						}
						Column {
							anchors { left: tuile.right; leftMargin: 14; right: touche.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
							spacing: 1
							Text {
								width: parent.width
								textFormat: Text.StyledText
								elide: Text.ElideRight
								font.family: Theme.policeTexte
								font.pixelSize: 15
								color: ligne.choisi ? "#ffffff" : Theme.texte
								text: ligne.entete ? "" : (ligne.modelData.type === "fichier" ? `<font color="${Theme.texteDiscret}">${ligne.modelData.dossier}</font>` : "") + Lanceur.surligner(ligne.modelData.titre, ligne.modelData.correspondance, Theme.accent)
							}
							Texte {
								width: parent.width
								visible: ligne.modelData.type !== "fichier"
								text: ligne.modelData.sous ?? ""
								taille: 12
								color: Theme.texteDiscret
							}
						}
						Libelle {
							id: touche
							anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
							taille: 10
							color: Theme.lisere
							text: ligne.choisi ? "Entrée" : (ligne.modelData.touche ?? "")
						}
						MouseArea {
							id: survol
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: { fenetre.courant = ligne.index; Lanceur.executer(ligne.modelData, ""); }
						}
					}
				}

				// the calculation's result, in large type
				Item {
					visible: Lanceur.prefixe === "=" && Lanceur.calcul !== null
					anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
					height: 70
					Rectangle { anchors.fill: parent; color: Theme.tuile; border { width: 1; color: Theme.separateur } }
					Texte { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "résultat"; taille: 13; color: Theme.texteDiscret }
					Text {
						anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
						font.family: Theme.policeTitre
						font.pixelSize: 26
						font.letterSpacing: 2
						color: Lanceur.calcul?.ok ? Theme.accent : Theme.xanaTexte
						text: Lanceur.calcul?.texte ?? ""
					}
				}
			}

			// ---------------- detail panel ----------------
			Item {
				id: detail
				anchors { top: filet.bottom; bottom: parent.bottom; right: parent.right }
				width: bloc.width >= 720 ? 260 : 0
				visible: width > 0 && fenetre.selection !== null
				clip: true

				Rectangle { width: 1; height: parent.height; color: Theme.separateur }
				Rectangle {
					anchors { fill: parent; leftMargin: 1 }
					gradient: Gradient {
						GradientStop { position: 0; color: Qt.alpha(Theme.bouton, 0.12) }
						GradientStop { position: 0.5; color: "transparent" }
					}
				}

				Column {
					id: haut
					x: 20; y: 20
					width: parent.width - 40
					spacing: 14
					Chanfrein {
						width: 72; height: 72
						hd: 14
						couleur: Theme.accent
						Icone { anchors.centerIn: parent; chemin: fenetre.selection?.icone ?? ""; taille: 34; trait: 1.6; couleur: Theme.encre }
					}
					Column {
						width: parent.width
						spacing: 3
						Text {
							width: parent.width
							wrapMode: Text.Wrap
							maximumLineCount: 2
							elide: Text.ElideRight
							font.family: Theme.policeTitre
							font.pixelSize: 15
							font.letterSpacing: 2
							font.capitalization: Font.AllUppercase
							color: Theme.texteTitre
							text: fenetre.selection?.type === "fenetre" ? (fenetre.selection.fenetre.appId || "fenêtre") : (fenetre.selection?.entree?.name ?? fenetre.selection?.titre ?? "")
						}
						Texte {
							width: parent.width
							wrapMode: Text.Wrap
							maximumLineCount: 3
							taille: 13
							color: Theme.texteAccent
							text: {
								const s = fenetre.selection; if (!s) return "";
								if (s.entree) return [s.entree.genericName || s.entree.comment, s.entree.id].filter(x => x).join(" · ");
								if (s.type === "fenetre") return s.fenetre.titre;
								if (s.type === "fichier") return s.chemin;
								return s.sous ?? "";
							}
						}
					}
					Column {
						width: parent.width
						spacing: 6
						visible: lignesInfo.count > 0
						Rectangle { width: parent.width; height: 1; color: Theme.separateur }
						Item { width: 1; height: 4 }
						Repeater {
							id: lignesInfo
							model: {
								const s = fenetre.selection; if (!s) return [];
								const u = Lanceur.usage[s.cle];
								if (s.type === "appli") {
									const o = s.ouvertes;
									return [
										{ c: "état", v: o.length ? `ouvert · secteur ${o[0].secteur.split(":")[0]}` : "fermé", ok: o.length > 0 },
										{ c: "lancements", v: String(u?.n ?? 0) },
										{ c: "dernier", v: Lanceur.ilYa(u?.t) },
										{ c: "terminal", v: s.entree.runInTerminal ? "oui" : "non" },
									];
								}
								if (s.type === "fenetre") return [
									{ c: "secteur", v: s.fenetre.secteur ? Sway.nomAffiche(s.fenetre.secteur).toLowerCase() : "scratchpad" },
									{ c: "écran", v: s.fenetre.sortie },
									{ c: "mode", v: s.fenetre.flottante ? "flottante" : "mosaïque" },
									{ c: "taille", v: `${s.fenetre.rect.width} × ${s.fenetre.rect.height}` },
								];
								if (s.type === "fichier" || s.type === "commande") return [{ c: "ouvertures", v: String(u?.n ?? 0) }, { c: "dernier", v: Lanceur.ilYa(u?.t) }];
								return [];
							}
							Item {
								required property var modelData
								width: parent.width; height: 16
								Texte { text: modelData.c; taille: 13; color: Theme.texteDiscret }
								Texte { anchors.right: parent.right; text: modelData.v; taille: 13; color: modelData.ok ? Theme.energie : Theme.texte }
							}
						}
					}
				}

				Column {
					id: blocActions
					// as many actions as the height allows below the info (small screens)
					readonly property int place: Math.max(1, Math.min(6, Math.floor((detail.height - haut.y - haut.height - 20 - 44) / 32)))
					anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20 }
					spacing: 4
					Libelle { text: "Actions"; taille: 10; color: Theme.texteEteint; bottomPadding: 2 }
					Repeater {
						model: fenetre.actions.slice(0, blocActions.place)
						Rectangle {
							required property var modelData
							required property int index
							readonly property bool choisie: fenetre.focusActions && index === fenetre.actionCourante
							width: parent.width; height: 28
							color: choisie ? Qt.alpha(Theme.bouton, 0.55) : zoneAction.containsMouse ? Qt.alpha(Theme.bouton, 0.25) : "transparent"
							border { width: 1; color: choisie ? Theme.bordureVive : Theme.separateur }
							Texte { x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20 - cleAction.width; text: modelData.n; taille: 13; color: Theme.texte }
							Libelle { id: cleAction; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: modelData.k; taille: 9; color: Theme.texteAccent }
							MouseArea { id: zoneAction; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.f() }
						}
					}
				}
			}
		}

		// ---------------- keyboard help below the frame ----------------
		Row {
			anchors { top: cadre.bottom; topMargin: 16; horizontalCenter: parent.horizontalCenter }
			spacing: 18
			Repeater {
				model: [
					{ k: "↑ ↓", t: "naviguer" }, { k: "Tab", t: "catégorie" }, { k: "Entrée", t: "lancer" },
					{ k: "→", t: "actions" }, { k: "Échap", t: "fermer" }
				]
				Row {
					required property var modelData
					spacing: 8
					Rectangle {
						width: cle.implicitWidth + 14; height: 22
						color: Theme.tuile
						border { width: 1; color: "#4b9dbf" }
						Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: "#4b9dbf" }
						Libelle { id: cle; anchors.centerIn: parent; text: modelData.k; taille: 9 }
					}
					Texte { text: modelData.t; taille: 13; color: Theme.texteAccent; anchors.verticalCenter: parent.verticalCenter }
				}
			}
		}
	}

	// ---------------- keyboard ----------------
	function clavier(e) {
		const ctrl = e.modifiers & Qt.ControlModifier;
		if (e.key === Qt.Key_Escape) { if (focusActions) focusActions = false; else Etat.fermer(); e.accepted = true; return; }
		if (focusActions) {
			if (e.key === Qt.Key_Down) actionCourante = Math.min(actionCourante + 1, Math.min(actions.length, blocActions.place) - 1);
			else if (e.key === Qt.Key_Up) actionCourante = Math.max(0, actionCourante - 1);
			else if (e.key === Qt.Key_Left) focusActions = false;
			else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) actions[actionCourante]?.f();
			else return;
			e.accepted = true; return;
		}
		if (e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_J)) deplacer(1);
		else if (e.key === Qt.Key_Up || (ctrl && e.key === Qt.Key_K)) deplacer(-1);
		else if (e.key === Qt.Key_PageDown) for (let i = 0; i < 6; i++) deplacer(1);
		else if (e.key === Qt.Key_PageUp) for (let i = 0; i < 6; i++) deplacer(-1);
		else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
			const c = Lanceur.categories, i = c.indexOf(Lanceur.categorie);
			const sens = (e.key === Qt.Key_Backtab || (e.modifiers & Qt.ShiftModifier)) ? -1 : 1;
			Lanceur.categorie = c[(i + sens + c.length) % c.length];
		}
		else if (e.key === Qt.Key_Right && champ.cursorPosition === champ.text.length && actions.length) { focusActions = true; actionCourante = 0; }
		else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) Lanceur.executer(selection, ctrl ? "secteur" : "");
		else if (ctrl && e.key === Qt.Key_P && selection?.type === "appli") basculerEpingle(selection);
		else return;
		e.accepted = true;
	}
}
