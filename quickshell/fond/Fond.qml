import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.I3
import qs.theme
import qs.composants
import qs.services

// Surcouche du fond d'écran : état du supercalculateur en haut à gauche, journal en
// haut à droite. Se pose sur le calque d'arrière-plan, donc au-dessus de l'image de
// swaybg et sous toutes les fenêtres, et ne reçoit jamais d'événement (masque vide).
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
		WlrLayershell.layer: WlrLayer.Background
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
		mask: Region {}          // aucune zone cliquable : tout passe au travers

		readonly property bool principal: Etat.nomPrincipal === modelData.name
		// le journal n'a de sens qu'une fois, sur l'écran principal
		readonly property int marge: Theme.barreHauteur + 8 + 6 + Theme.marge * 2

		// ---------------- haut gauche : état ----------------
		Column {
			x: Theme.marge * 2
			y: fenetre.marge
			spacing: 2
			opacity: 0.5

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

		// ---------------- haut droite : journal ----------------
		Column {
			visible: fenetre.principal
			anchors { right: parent.right; rightMargin: Theme.marge * 2 }
			y: fenetre.marge
			spacing: 2
			opacity: 0.42

			Texte {
				anchors.right: parent.right
				text: "JOURNAL // " + Journal.total.toLocaleString(Qt.locale("fr_FR"), "f", 0) + " ENTRÉES"
				taille: 12
				color: Theme.texteAccent
			}
			// Le modèle est un nombre fixe, pas la liste : sinon le Repeater détruit et
			// recrée ses 26 lignes à chaque battement, ce qui coûtait bien plus cher que
			// la lecture de /proc. Ici les délégués sont créés une fois et seules leurs
			// liaisons se réévaluent.
			Repeater {
				model: Journal.maximum
				Row {
					required property int index
					readonly property var ligne: Journal.lignes[index] ?? null
					visible: ligne !== null
					anchors.right: parent.right
					spacing: 8
					// les entrées anciennes s'effacent vers le haut
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
