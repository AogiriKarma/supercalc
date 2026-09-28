import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.theme
import qs.composants
import qs.services

// Agent polkit : les demandes d'autorisation (pkexec, montage de disque, réglages système…)
// s'affichent dans un cadre XANA au centre de l'écran actif.
Scope {
	id: racine

	PolkitAgent { id: agent }
	readonly property var flux: agent.flow
	readonly property bool actif: agent.isActive && flux !== null

	PanelWindow {
		id: fenetre
		screen: Etat.ecranActif
		visible: racine.actif
		anchors { top: true; bottom: true; left: true; right: true }
		exclusionMode: ExclusionMode.Ignore
		color: "transparent"
		WlrLayershell.namespace: "supercalc-autorisation"
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: racine.actif ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

		onVisibleChanged: if (visible) { champ.text = ""; champ.forceActiveFocus(); }
		Connections {
			target: racine.flux
			// après un échec, une nouvelle tentative démarre : on vide le champ
			function onIsResponseRequiredChanged() { if (racine.flux?.isResponseRequired) { champ.text = ""; champ.forceActiveFocus(); } }
		}

		function valider() { if (racine.flux && racine.flux.isResponseRequired) racine.flux.submit(champ.text); }
		function annuler() { racine.flux?.cancelAuthenticationRequest(); }

		Rectangle { anchors.fill: parent; color: "#02080c"; opacity: 0.7 }

		Fenetre {
			id: cadre
			titre: "Autorisation // système"
			variante: racine.flux?.failed ? "xana" : "energie"
			width: Math.min(560, fenetre.width - 48)
			height: colonne.implicitHeight + Theme.titreHauteur + Theme.bandeHauteur + 40
			anchors.centerIn: parent

			Column {
				id: colonne
				x: 22; y: 20
				width: parent.width - 44
				spacing: 14

				Row {
					width: parent.width
					spacing: 14
					Chanfrein {
						width: 48; height: 48; hd: 10
						couleur: racine.flux?.failed ? Theme.xana : Theme.ambre
						Icone { anchors.centerIn: parent; chemin: Icones.verrou; taille: 24; trait: 1.6; couleur: Theme.encre }
					}
					Column {
						width: parent.width - 62
						anchors.verticalCenter: parent.verticalCenter
						spacing: 4
						Libelle { text: "Accès privilégié demandé"; taille: 12; color: Theme.texteTitre }
						Texte { width: parent.width; text: racine.flux?.actionId ?? ""; taille: 11; color: Theme.texteEteint }
					}
				}

				Texte {
					width: parent.width
					text: racine.flux?.message ?? ""
					taille: 14
					color: Theme.texte
					wrapMode: Text.Wrap
					maximumLineCount: 5
				}

				// identité (plusieurs administrateurs possibles)
				Row {
					visible: (racine.flux?.identities.length ?? 0) > 1
					spacing: 6
					Repeater {
						model: racine.flux?.identities ?? []
						Pastille {
							required property var modelData
							implicitHeight: 26
							texte: modelData.displayName || modelData.string
							fond: racine.flux?.selectedIdentity === modelData ? Theme.lisere : Theme.tuile
							encre: racine.flux?.selectedIdentity === modelData ? Theme.encre : Theme.texte
							cliquable: true
							onClique: racine.flux.selectedIdentity = modelData
						}
					}
				}

				Column {
					width: parent.width
					spacing: 6
					Libelle { text: (racine.flux?.inputPrompt || "Mot de passe").replace(/:\s*$/, ""); taille: 10; color: Theme.texteEteint }
					Rectangle {
						width: parent.width; height: 42
						color: Theme.champ
						border { width: 1; color: racine.flux?.failed ? Theme.xana : Theme.bordureVive }
						TextInput {
							id: champ
							anchors { left: parent.left; right: parent.right; margins: 14; verticalCenter: parent.verticalCenter }
							font.family: Theme.policeTexte; font.pixelSize: 16
							color: Theme.texteTitre
							echoMode: racine.flux?.responseVisible ? TextInput.Normal : TextInput.Password
							passwordCharacter: "■"
							enabled: racine.flux?.isResponseRequired ?? false
							clip: true
							Keys.onReturnPressed: fenetre.valider()
							Keys.onEnterPressed: fenetre.valider()
							Keys.onEscapePressed: fenetre.annuler()
						}
					}
					Texte {
						visible: text !== ""
						width: parent.width
						text: racine.flux?.supplementaryMessage || (racine.flux?.failed ? "mot de passe refusé" : "")
						taille: 12
						color: racine.flux?.supplementaryIsError || racine.flux?.failed ? Theme.xanaTexte : Theme.texteDiscret
						wrapMode: Text.Wrap
					}
				}

				Row {
					anchors.right: parent.right
					spacing: 8
					Pastille { implicitHeight: 30; texte: "Annuler"; fond: Theme.boutonSombre; cliquable: true; onClique: fenetre.annuler() }
					Pastille { implicitHeight: 30; texte: "Autoriser"; fond: Theme.ambre; encre: Theme.encre; cliquable: true; onClique: fenetre.valider() }
				}
			}
		}
	}
}
