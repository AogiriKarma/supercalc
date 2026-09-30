import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.I3
import qs.theme
import qs.composants
import qs.services

// The wallpaper overlay: the supercomputer's state top left, the log top right. It sits on the
// background layer, so above swaybg's image and below every window, and never receives an event
// (empty mask).
Variants {
	model: Quickshell.screens

	PanelWindow {
		id: fenetre
		required property var modelData
		screen: modelData

		anchors { top: true; bottom: true; left: true; right: true }
		exclusionMode: ExclusionMode.Ignore
		color: "transparent"
		WlrLayershell.namespace: "supercalc-fond"
		// Bottom and not Background: swaybg occupies Background, and sway restarts it on every
		// `reload`, which recreates its surface ON TOP of ours — the whole layer then vanished
		// behind the wallpaper. Bottom is above the wallpaper and below every window, which is
		// exactly the place we want.
		WlrLayershell.layer: WlrLayer.Bottom
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
		mask: Region {}          // no clickable area: everything passes through

		readonly property bool principal: Etat.nomPrincipal === modelData.name
		readonly property int marge: Theme.barreHauteur + 8 + 6 + Theme.marge * 2

		// ---------------- top left: state ----------------
		Column {
			x: Theme.marge * 2
			y: fenetre.marge
			spacing: 2
			// plainly readable: this text is read on top of an animated rain
			opacity: 0.95

			Texte {
				text: "SUPERCALC // " + (fenetre.principal ? "TERMINAL PRINCIPAL" : "TERMINAL SECONDAIRE")
				taille: 12
				color: Theme.texteAccent
			}
			Repeater {
				model: [
					{ c: "secteur", v: () => Sway.nomAffiche(I3.focusedWorkspace?.name ?? "—").toUpperCase() },
					{ c: "écran", v: () => fenetre.modelData.name + " " + fenetre.modelData.width + "×" + fenetre.modelData.height },
					{ c: "proc", v: () => Math.round(Systeme.cpu * 100) + " %" },
					{ c: "mémoire", v: () => Systeme.memoireUtilisee.toFixed(1) + " / " + Systeme.memoireTotale.toFixed(1) + " Gio" },
					{ c: "liaison", v: () => Controle.enLigne },
					{ c: "énergie", v: () => Systeme.aBatterie ? Math.round(Systeme.niveau * 100) + " %" + (Systeme.enCharge ? " (charge)" : "") : "secteur" },
				]
				Row {
					required property var modelData
					spacing: 8
					Texte { text: "·"; taille: 12; color: Theme.texteEteint }
					Texte {
						width: 74
						text: modelData.c
						taille: 12
						color: Theme.texteEteint
					}
					Texte { text: modelData.v(); taille: 12; color: Theme.texteDiscret }
				}
			}
		}

		// ---------------- character rain ----------------
		// Across the full width, from the top down to 70 % of the height. The columns stop within
		// 5 % of one another, so the bottom does not form a straight line.
		//
		// Expensive: Qt's Canvas is painted by the CPU and its cost follows the pixel count — most
		// of it goes into the fading rectangle that covers the whole surface on every frame. Half
		// resolution scaled up by the GPU was tried: half the price, but the glyphs become
		// unreadable. An optimisation to revisit differently.
		MatriceGPU {
			z: -1
			anchors { left: parent.left; right: parent.right; top: parent.top }
			height: parent.height * 0.70
			cellule: 16
			longueur: 18
			fondMini: 0.95
			couleurTrainee: Theme.accent
			couleurTete: Theme.lisere
			opacity: 0.8
		}


		// ---------------- top right: log ----------------
		Column {
			anchors { right: parent.right; rightMargin: Theme.marge * 2 }
			y: fenetre.marge
			spacing: 2
			opacity: 0.95

			Texte {
				anchors.right: parent.right
				text: "JOURNAL // " + Journal.total.toLocaleString(Qt.locale("fr_FR"), "f", 0) + " ENTRÉES"
				taille: 12
				color: Theme.texteAccent
			}
			// The model is a fixed number, not the list: otherwise the Repeater destroys and
			// recreates its 26 rows on every tick, which cost far more than reading /proc. Here the
			// delegates are created once and only their bindings are re-evaluated.
			Repeater {
				model: Journal.maximum
				Row {
					required property int index
					readonly property var ligne: Journal.lignes[index] ?? null
					visible: ligne !== null
					anchors.right: parent.right
					spacing: 8
					// older entries fade out towards the top
					opacity: 0.35 + 0.65 * ((index + 1) / Math.max(1, Journal.lignes.length))
					Texte { text: parent.ligne?.h ?? ""; taille: 12; color: Theme.texteEteint }
					Texte { text: parent.ligne?.src ?? ""; taille: 12; color: Theme.texteDiscret }
					Texte {
						text: parent.ligne?.txt ?? ""
						taille: 12
						color: Theme.texteEteint
						elide: Text.ElideRight
						width: Math.min(implicitWidth, fenetre.width * 0.34)
					}
				}
			}
		}
	}
}
