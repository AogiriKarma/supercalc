import QtQuick
import QtQuick.Effects
import qs.theme
import qs.composants
import qs.services

// Une carte de la holomap : un secteur, ses fenêtres dessinées à l'échelle de l'écran.
Item {
	id: carte
	property var secteur: ({ nom: "", num: 0, rect: { x: 0, y: 0, width: 16, height: 9 }, fenetres: [] })
	property bool choisi: false
	property var filtre: f => true
	property var glisse: null

	signal aller()
	signal allerFenetre(var f)
	signal fermerFenetre(var f)
	signal debutGlisse(var f, real x, real y)
	signal suiteGlisse(real x, real y)
	signal finGlisse(real x, real y)

	property var survol: null             // cible survolée pendant un glisser (fourni par la holomap)
	readonly property bool cible: glisse !== null && survol === carte

	readonly property bool actif: secteur.focus
	readonly property string variante: secteur.urgent ? "xana" : (actif || choisi || cible) ? "focus" : "inactif"
	readonly property int nb: secteur.fenetres.length

	Fenetre {
		id: cadre
		anchors.fill: parent
		variante: carte.variante
		halo: carte.actif || carte.secteur.urgent || carte.choisi
		bande: false
		titre: (carte.secteur.num >= 0 && !/^\d+$/.test(Sway.nomAffiche(carte.secteur.nom)) ? carte.secteur.num + "  " : "") + Sway.nomAffiche(carte.secteur.nom)
		sousTitre: [
			carte.nb === 0 ? "vide" : `${carte.nb} ${carte.nb > 1 ? "fenêtres" : "fenêtre"}`,
			carte.secteur.urgent ? "urgent" : carte.actif ? "actif" : carte.secteur.visible ? "visible" : ""
		].filter(x => x).join(" · ")

		// quadrillage
		Canvas {
			anchors.fill: parent
			opacity: 0.05
			onPaint: {
				const c = getContext("2d");
				c.reset(); c.strokeStyle = "#8fdcf5"; c.lineWidth = 1;
				for (let x = 0.5; x < width; x += 16) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x, height); c.stroke(); }
				for (let y = 0.5; y < height; y += 16) { c.beginPath(); c.moveTo(0, y); c.lineTo(width, y); c.stroke(); }
			}
			onWidthChanged: requestPaint()
			onHeightChanged: requestPaint()
		}

		MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: carte.aller() }

		// fenêtres à l'échelle
		Item {
			id: plan
			anchors { fill: parent; margins: 6 }
			readonly property real ex: width / Math.max(1, carte.secteur.rect.width)
			readonly property real ey: height / Math.max(1, carte.secteur.rect.height)

			Repeater {
				model: carte.secteur.fenetres
				Rectangle {
					id: tuile
					required property var modelData
					readonly property var f: modelData
					readonly property bool enFocus: f.focus
					readonly property bool urgent: carte.secteur.urgent && !f.focus
					readonly property bool garde: carte.filtre(f)
					x: (f.rect.x - carte.secteur.rect.x) * plan.ex
					y: (f.rect.y - carte.secteur.rect.y) * plan.ey
					width: Math.max(24, f.rect.width * plan.ex - 3)
					height: Math.max(18, f.rect.height * plan.ey - 3)
					z: f.flottante ? 2 : 1
					opacity: carte.glisse && carte.glisse.id === f.id ? 0.3 : garde ? 1 : 0.25
					clip: true
					color: carte.secteur.urgent ? Qt.rgba(229 / 255, 72 / 255, 77 / 255, 0.1) : enFocus ? Qt.rgba(47 / 255, 118 / 255, 151 / 255, 0.3) : Qt.rgba(8 / 255, 28 / 255, 39 / 255, 0.85)
					border { width: enFocus ? 2 : 1; color: carte.secteur.urgent ? Theme.xanaTexte : enFocus ? Theme.lisere : Theme.bordure }

					Rectangle {
						id: barreT
						width: parent.width; height: 18
						color: carte.secteur.urgent ? "#7a2a2e" : tuile.enFocus ? Theme.cadreFocus : "#123f52"
						Row {
							x: 6; spacing: 6
							anchors.verticalCenter: parent.verticalCenter
							Icone { chemin: Applis.icone(Applis.entree(tuile.f.appId), tuile.f.appId); taille: 10; couleur: tuile.enFocus ? "#ffffff" : "#9fd0e4"; anchors.verticalCenter: parent.verticalCenter }
							Libelle { text: tuile.f.appId || "fenêtre"; taille: 9; color: tuile.enFocus ? "#ffffff" : "#9fd0e4"; anchors.verticalCenter: parent.verticalCenter }
						}
					}
					// lignes de contenu stylisées
					Column {
						x: 8; y: 24
						spacing: 4
						visible: tuile.height > 60
						Repeater {
							model: Math.max(0, Math.min(6, Math.floor((tuile.height - 44) / 7)))
							Rectangle {
								required property int index
								height: 3
								width: (tuile.width - 16) * [0.7, 0.45, 0.6, 0.3, 0.8, 0.5][index]
								color: carte.secteur.urgent ? Qt.rgba(1, 138 / 255, 142 / 255, 0.3) : tuile.enFocus ? Qt.rgba(212 / 255, 244 / 255, 1, 0.35) : Qt.rgba(143 / 255, 220 / 255, 245 / 255, 0.22)
							}
						}
					}
					Texte {
						visible: tuile.height > 40
						anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; bottom: parent.bottom; bottomMargin: 4 }
						text: tuile.f.titre
						taille: 11
						color: carte.secteur.urgent ? "#f3d7d8" : Theme.texteDiscret
					}

					MouseArea {
						anchors.fill: parent
						acceptedButtons: Qt.LeftButton | Qt.MiddleButton
						cursorShape: Qt.PointingHandCursor
						hoverEnabled: true
						property point depart
						property bool enGlisse: false
						property bool aGlisse: false
						onEntered: tuile.border.color = carte.secteur.urgent ? "#ffd0d0" : Theme.lisere
						onExited: tuile.border.color = Qt.binding(() => carte.secteur.urgent ? Theme.xanaTexte : tuile.enFocus ? Theme.lisere : Theme.bordure)
						onPressed: m => { depart = Qt.point(m.x, m.y); enGlisse = false; aGlisse = false; }
						onPositionChanged: m => {
							if (!pressed || m.buttons !== Qt.LeftButton) return;
							const p = mapToItem(null, m.x, m.y);
							if (!enGlisse && Math.hypot(m.x - depart.x, m.y - depart.y) > 8) { enGlisse = true; carte.debutGlisse(tuile.f, p.x, p.y); }
							else if (enGlisse) carte.suiteGlisse(p.x, p.y);
						}
						onReleased: m => {
							if (enGlisse) { const p = mapToItem(null, m.x, m.y); enGlisse = false; aGlisse = true; carte.finGlisse(p.x, p.y); }
						}
						onClicked: m => {
							if (aGlisse) return;
							if (m.button === Qt.MiddleButton) carte.fermerFenetre(tuile.f);
							else carte.allerFenetre(tuile.f);
						}
					}
				}
			}
		}

		// contour de dépôt
		Rectangle {
			anchors.fill: parent
			visible: carte.cible
			color: Qt.alpha(Theme.lisere, 0.08)
			border { width: 2; color: Theme.lisere }
		}
	}
}
