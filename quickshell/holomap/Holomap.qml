import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.I3
import qs.theme
import qs.composants
import qs.services

// Holomap (Super+Tab): every sector on every screen, windows drawn to scale.
// Click = go to the sector / the window · drag = move · middle click = close.
PanelWindow {
	id: fenetre
	screen: Etat.ecranCible
	visible: ouvert || fondu.running
	anchors { top: true; bottom: true; left: true; right: true }
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.namespace: "supercalc-holomap"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: ouvert ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	readonly property bool ouvert: Etat.panneau === "holomap"
	property string filtre: ""
	property int choix: 0                  // index into secteursOrdonnes (keyboard navigation)
	property var glisse: null              // the window currently being dragged

	onOuvertChanged: if (ouvert) {
		filtre = ""; champ.text = ""; glisse = null;
		const i = secteursOrdonnes.findIndex(s => s.focus);
		choix = Math.max(0, i);
		champ.forceActiveFocus();
	}

	// screens, and their sectors in numeric order
	readonly property var ecrans: Sway.sorties.length ? Sway.sorties : [...new Set(Sway.secteurs.map(s => s.sortie))].map(n => ({ nom: n, largeur: 16, hauteur: 9 }))
	function secteursDe(nom) { return Sway.secteurs.filter(s => s.sortie === nom).sort((a, b) => a.num - b.num); }
	readonly property var secteursOrdonnes: ecrans.reduce((acc, e) => acc.concat(secteursDe(e.nom)), [])
	readonly property var scratch: Sway.fenetres.filter(f => f.secteur === "")
	readonly property int nbFenetres: Sway.fenetres.filter(f => f.secteur !== "").length
	readonly property int nbUrgents: Sway.secteurs.filter(s => s.urgent).length

	function correspond(f) {
		if (!filtre) return true;
		const t = (f.appId + " " + f.titre).toLowerCase();
		return t.includes(filtre.toLowerCase());
	}

	// card size: fill the width, then shrink if the height is not enough
	readonly property real zoneL: width - 2 * marge
	readonly property real marge: Math.max(24, width * 0.033)
	readonly property int colonnesMax: Math.max(1, ...ecrans.map(e => secteursDe(e.nom).length + 1))
	readonly property real hauteurFixe: 64 + 30 * ecrans.length + (scratch.length ? 110 : 0) + 60
	readonly property real carteL: {
		const parLargeur = (zoneL - (colonnesMax - 1) * 22) / colonnesMax;
		// total height if each screen fits on one row
		const rapportMax = Math.max(...ecrans.map(e => (e.logiqueH ?? e.hauteur) / (e.logiqueL ?? e.largeur)));
		const parHauteur = ((height - hauteurFixe) / ecrans.length - 28 - 22) / rapportMax;
		return Math.max(140, Math.min(620, parLargeur, parHauteur));
	}

	// ---------------- background ----------------
	Rectangle {
		anchors.fill: parent
		color: "#020a0e"
		opacity: fenetre.ouvert ? 0.72 : 0
		Behavior on opacity { NumberAnimation { id: fondu; duration: 700; easing.type: Easing.OutCubic } }
		MouseArea { anchors.fill: parent; onClicked: Etat.fermer() }
	}

	Item {
		id: contenu
		anchors.fill: parent
		// The container's scale and fade are gone: each card is a Fenetre and unfolds on its own,
		// staggered. Stacking the two would bring the overlap back.
		opacity: fenetre.ouvert ? 1 : 0
		Behavior on opacity { NumberAnimation { duration: Theme.dureeCourte } }

		Column {
			id: colonne
			x: fenetre.marge
			y: Math.max(Theme.barreHauteur + 18, (fenetre.height - height) / 2)
			width: fenetre.zoneL
			spacing: 22

			// ---------------- header ----------------
			Item {
				width: parent.width; height: 32
				Row {
					spacing: 8
					anchors.verticalCenter: parent.verticalCenter
					Pastille {
						implicitHeight: 30; coupeHD: 8
						fond: Theme.lisere; encre: Theme.encre
						Icone { chemin: Icones.secteur; taille: 14; couleur: Theme.encre; anchors.verticalCenter: parent.verticalCenter }
						Text { text: "HOLOMAP"; font.family: Theme.policeTitre; font.pixelSize: 13; font.letterSpacing: 2; color: Theme.encre; anchors.verticalCenter: parent.verticalCenter }
					}
					Pastille { implicitHeight: 30; coupeHD: 0; texte: `${Sway.secteurs.length} ${Sway.secteurs.length > 1 ? "secteurs" : "secteur"}` }
					Pastille { implicitHeight: 30; coupeHD: 0; texte: `${fenetre.nbFenetres} ${fenetre.nbFenetres > 1 ? "fenêtres" : "fenêtre"}` }
					Pastille { implicitHeight: 30; coupeHD: 0; texte: `${fenetre.ecrans.length} ${fenetre.ecrans.length > 1 ? "écrans" : "écran"}` }
					Pastille {
						visible: fenetre.nbUrgents > 0
						implicitHeight: 30; coupeHD: 0
						fond: Theme.xana; encre: "#ffffff"
						texte: `${fenetre.nbUrgents} ${fenetre.nbUrgents > 1 ? "tours activées" : "tour activée"}`
						Rectangle { width: 6; height: 6; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
					}
				}
				Rectangle {
					anchors { right: parent.right; verticalCenter: parent.verticalCenter }
					width: Math.min(320, parent.width * 0.3); height: 32
					color: Qt.alpha(Theme.champ, 0.92)
					border { width: 1; color: Theme.bordureVive }
					Icone { id: loupe; x: 12; anchors.verticalCenter: parent.verticalCenter; chemin: Icones.recherche; taille: 14; couleur: Theme.texteAccent }
					TextInput {
						id: champ
						anchors { left: loupe.right; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
						font.family: Theme.policeTexte; font.pixelSize: 14
						color: Theme.texteTitre
						clip: true
						onTextChanged: fenetre.filtre = text
						Keys.onPressed: e => fenetre.clavier(e)
						Texte { visible: champ.text === ""; text: "filtrer les fenêtres…"; taille: 14; color: Theme.texteEteint; anchors.verticalCenter: parent.verticalCenter }
					}
				}
			}

			// ---------------- one block per screen ----------------
			Repeater {
				model: fenetre.ecrans
				Column {
					id: blocEcran
					required property var modelData
					required property int index
					readonly property var secs: fenetre.secteursDe(modelData.nom)
					readonly property real carteH: fenetre.carteL * (modelData.logiqueH ?? modelData.hauteur) / (modelData.logiqueL ?? modelData.largeur) + 28
					width: parent.width
					spacing: 8

					Item {
						width: parent.width; height: 20
						Row {
							id: titreEcran
							spacing: 12
							anchors.verticalCenter: parent.verticalCenter
							Icone { chemin: Icones.moniteur; taille: 14; couleur: Theme.texteAccent; anchors.verticalCenter: parent.verticalCenter }
							Libelle { text: `Écran ${blocEcran.index + 1} // ${blocEcran.modelData.nom}`; color: Theme.texteAccent; anchors.verticalCenter: parent.verticalCenter }
							Texte {
								anchors.verticalCenter: parent.verticalCenter
								taille: 12; color: Theme.texteEteint
								text: {
									const e = blocEcran.modelData;
									const parts = [`${e.largeur} × ${e.hauteur}`];
									if (e.frequence) parts.push(`${e.frequence} Hz`);
									if (e.echelle && e.echelle !== 1) parts.push(`échelle ${e.echelle}`);
									if (e.rotation && e.rotation !== "normal") parts.push(e.rotation.startsWith("flipped") ? "miroir" + (e.rotation.includes("-") ? ` · pivoté ${e.rotation.split("-")[1]}°` : "") : `pivoté ${e.rotation}°`);
									if (/^(eDP|LVDS|DSI)/.test(e.nom)) parts.push("interne");
									else if (e.modele) parts.push([e.marque, e.modele].filter(x => x && x !== "Unknown").join(" ") || "externe");
									return parts.join(" · ");
								}
							}
						}
						Rectangle { anchors { left: titreEcran.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter } height: 1; color: Theme.separateur }
					}

					Flow {
						width: parent.width
						spacing: 22
						Repeater {
							model: blocEcran.secs
							CarteSecteur {
								id: carteSecteur
								required property var modelData
								required property int index
								ouvre: fenetre.ouvert
								retard: index * 70
								survol: fenetre.survol
								Component.onCompleted: fenetre.cibles = fenetre.cibles.concat([{ item: carteSecteur, secteur: modelData.nom, sortie: modelData.sortie }])
								Component.onDestruction: fenetre.cibles = fenetre.cibles.filter(c => c.item !== carteSecteur)
								secteur: modelData
								width: fenetre.carteL
								height: blocEcran.carteH
								choisi: fenetre.secteursOrdonnes[fenetre.choix]?.nom === modelData.nom
								filtre: fenetre.correspond
								glisse: fenetre.glisse
								onAller: { I3.dispatch(`workspace "${modelData.nom}"`); Etat.fermer(); }
								onAllerFenetre: f => { Sway.focaliser(f.id); Etat.fermer(); }
								onFermerFenetre: f => Sway.fermer(f.id)
								onDebutGlisse: (f, x, y) => fenetre.debutGlisse(f, x, y)
								onSuiteGlisse: (x, y) => fenetre.suiteGlisse(x, y)
								onFinGlisse: (x, y) => fenetre.finGlisse(x, y)
							}
						}
						// new sector
						Rectangle {
							id: nouveau
							width: fenetre.carteL; height: blocEcran.carteH
							property bool survole: fenetre.glisse !== null && fenetre.survol === nouveau
							color: survole ? Qt.alpha(Theme.bouton, 0.3) : Qt.alpha(Theme.champ, 0.5)
							border { width: 1; color: survole ? Theme.lisere : "#4b9dbf" }
							Column {
								anchors.centerIn: parent
								spacing: 10
								Icone { anchors.horizontalCenter: parent.horizontalCenter; chemin: "M8 3v10 M3 8h10"; taille: 22; couleur: Theme.texteAccent }
								Libelle { anchors.horizontalCenter: parent.horizontalCenter; text: "Nouveau secteur"; taille: 12; color: Theme.texteAccent }
								Texte { anchors.horizontalCenter: parent.horizontalCenter; text: `glisser une fenêtre ici · super + ${Sway.secteurLibre()}`; taille: 13; color: Theme.texteEteint; visible: fenetre.carteL > 260 }
							}
							Component.onCompleted: fenetre.cibles = fenetre.cibles.concat([{ item: nouveau, secteur: "", sortie: blocEcran.modelData.nom }])
							Component.onDestruction: fenetre.cibles = fenetre.cibles.filter(c => c.item !== nouveau)
							MouseArea {
								anchors.fill: parent
								onClicked: { I3.dispatch(`focus output ${blocEcran.modelData.nom}; workspace number ${Sway.secteurLibre()}`); Etat.fermer(); }
							}
						}
					}
				}
			}

			// ---------------- scratchpad ----------------
			Fenetre {
				visible: fenetre.scratch.length > 0
				width: parent.width; height: 92
				titre: "Scratchpad // hors secteur"
				sousTitre: "super + − pour rappeler"
				variante: "inactif"
				bande: false
				biseau: 12
				Row {
					x: 12; anchors.verticalCenter: parent.verticalCenter
					spacing: 8
					Repeater {
						model: fenetre.scratch
						Rectangle {
							required property var modelData
							visible: fenetre.correspond(modelData)
							height: 38; width: ligneScratch.implicitWidth + 28
							color: zoneScratch.containsMouse ? Theme.bouton : Theme.tuile
							border { width: 1; color: Theme.bordure }
							Row {
								id: ligneScratch
								anchors.centerIn: parent
								spacing: 10
								Icone { chemin: Applis.icone(Applis.entree(modelData.appId), modelData.appId); taille: 14; couleur: Theme.texteAccent; anchors.verticalCenter: parent.verticalCenter }
								Libelle { text: modelData.appId || "fenêtre"; anchors.verticalCenter: parent.verticalCenter }
								Texte { text: modelData.titre; taille: 12; color: Theme.texteDiscret; width: Math.min(implicitWidth, 220); anchors.verticalCenter: parent.verticalCenter }
							}
							MouseArea {
								id: zoneScratch
								anchors.fill: parent; hoverEnabled: true
								acceptedButtons: Qt.LeftButton | Qt.MiddleButton
								onClicked: m => {
									if (m.button === Qt.MiddleButton) Sway.fermer(modelData.id);
									else { I3.dispatch(`[con_id=${modelData.id}] scratchpad show`); Etat.fermer(); }
								}
							}
						}
					}
				}
			}

			// ---------------- help ----------------
			Row {
				spacing: 22
				Repeater {
					model: [
						{ k: "Clic", t: "aller au secteur" }, { k: "Glisser", t: "déplacer la fenêtre" }, { k: "Clic milieu", t: "fermer" },
						{ k: "← → ↑ ↓", t: "naviguer" }, { k: "Échap", t: "fermer la holomap" }
					]
					Row {
						required property var modelData
						spacing: 8
						Rectangle {
							width: cle.implicitWidth + 14; height: 22
							color: Theme.tuile
							border { width: 1; color: "#4b9dbf" }
							Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: "#4b9dbf" }
							Libelle { id: cle; anchors.centerIn: parent; text: modelData.k; taille: 10 }
						}
						Texte { text: modelData.t; taille: 13; color: Theme.texteAccent; anchors.verticalCenter: parent.verticalCenter }
					}
				}
			}
		}

		// ---------------- dragged window ----------------
		Rectangle {
			id: fantome
			visible: fenetre.glisse !== null
			width: 160; height: 34
			color: Qt.alpha(Theme.bouton, 0.9)
			border { width: 2; color: Theme.lisere }
			Row {
				anchors.centerIn: parent
				spacing: 8
				Icone { chemin: fenetre.glisse ? Applis.icone(Applis.entree(fenetre.glisse.appId), fenetre.glisse.appId) : ""; taille: 14; couleur: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
				Libelle { text: fenetre.glisse?.appId || "fenêtre"; anchors.verticalCenter: parent.verticalCenter }
			}
		}
	}

	// ---------------- drag and drop ----------------
	property var cibles: []                 // [{ item, secteur, sortie }] — cards and `new sector`
	property var survol: null
	function cibleSous(x, y) {
		for (const c of cibles) {
			const p = c.item.mapFromItem(contenu, x, y);
			if (p.x >= 0 && p.y >= 0 && p.x <= c.item.width && p.y <= c.item.height) return c;
		}
		return null;
	}
	function debutGlisse(f, x, y) { glisse = f; suiteGlisse(x, y); }
	function suiteGlisse(x, y) {
		fantome.x = x - fantome.width / 2; fantome.y = y - fantome.height / 2;
		survol = cibleSous(x, y)?.item ?? null;
	}
	function finGlisse(x, y) {
		const c = cibleSous(x, y), f = glisse;
		glisse = null; survol = null;
		if (!c || !f || c.secteur === f.secteur) return;
		if (c.secteur) I3.dispatch(`[con_id=${f.id}] move container to workspace "${c.secteur}"`);
		else I3.dispatch(`[con_id=${f.id}] move container to workspace number ${Sway.secteurLibre()}; workspace number ${Sway.secteurLibre()}; move workspace to output ${c.sortie}`);
	}

	// ---------------- keyboard ----------------
	function clavier(e) {
		const n = secteursOrdonnes.length;
		if (e.key === Qt.Key_Escape) Etat.fermer();
		else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) choix = (choix + 1) % Math.max(1, n);
		else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) choix = (choix - 1 + n) % Math.max(1, n);
		else if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
			// next / previous screen, same row if possible
			const s = secteursOrdonnes[choix]; if (!s) return;
			const ie = ecrans.findIndex(x => x.nom === s.sortie), rang = secteursDe(s.sortie).indexOf(s);
			const autre = ecrans[(ie + (e.key === Qt.Key_Down ? 1 : -1) + ecrans.length) % ecrans.length];
			const liste = secteursDe(autre.nom);
			if (liste.length) choix = secteursOrdonnes.indexOf(liste[Math.min(rang, liste.length - 1)]);
		}
		else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
			const s = secteursOrdonnes[choix];
			if (filtre) {
				const f = Sway.fenetres.find(x => x.secteur && correspond(x));
				if (f) { Sway.focaliser(f.id); Etat.fermer(); return; }
			}
			if (s) { I3.dispatch(`workspace "${s.nom}"`); Etat.fermer(); }
		}
		else return;
		e.accepted = true;
	}
}
