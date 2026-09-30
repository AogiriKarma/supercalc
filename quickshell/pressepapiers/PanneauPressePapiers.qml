import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.composants
import qs.services

// Clipboard (Super+V): pins, then the cliphist history, filterable, with image previews.
PanelWindow {
	id: fenetre
	screen: Etat.ecranCible
	visible: ouvert || fondu.running || cadre.anime
	anchors { top: true; bottom: true; left: true; right: true }
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.namespace: "supercalc-presse-papiers"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: ouvert ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	readonly property bool ouvert: Etat.panneau === "presse-papiers"
	property string filtre: ""
	property int courant: 0

	onOuvertChanged: if (ouvert) { champ.text = ""; courant = 0; PressePapiers.relire(); champ.forceActiveFocus(); }

	readonly property var elements: {
		const q = filtre.toLowerCase();
		const pins = PressePapiers.epingles.map(t => ({ texteEpingle: t, apercu: t.replace(/\s+/g, " ").slice(0, 200), type: PressePapiers.typeDe(t), epingle: true }));
		const hist = PressePapiers.entrees.filter(e => !PressePapiers.epingles.some(p => p.replace(/\s+/g, " ").slice(0, 100).trim() === e.apercu.trim()));
		return pins.concat(hist).filter(e => !q || e.apercu.toLowerCase().includes(q));
	}
	readonly property var selection: elements[courant] ?? null

	function iconeDe(e) {
		return e.epingle ? Icones.epingle : ({ image: Icones.image, lien: Icones.lien, couleur: Icones.goutte })[e.type] ?? Icones.texteLignes;
	}
	function copier(e) { if (!e) return; PressePapiers.copier(e); Etat.fermer(); }

	Rectangle {
		anchors.fill: parent
		color: "#020a0e"
		opacity: fenetre.ouvert ? 0.55 : 0
		Behavior on opacity { NumberAnimation { id: fondu; duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }
		MouseArea { anchors.fill: parent; onClicked: Etat.fermer() }
	}

	Fenetre {
		id: cadre
		ouvre: fenetre.ouvert
		titre: "Mémoire tampon"
		sousTitre: `${PressePapiers.entrees.length} entrées`
		width: Math.min(560, fenetre.width - 48)
		height: Math.min(620, fenetre.height - Theme.barreHauteur - 80,
			Math.max(260, Theme.titreHauteur + Theme.bandeHauteur + 14 + 38 + 10 + liste.contentHeight + 16 + 8 + 28))
		x: (fenetre.width - width) / 2
		y: Math.max(Theme.barreHauteur + 24, (fenetre.height - height) * 0.35)
		// opacity driven by Fenetre, so it follows the unfolding
		MouseArea { anchors.fill: parent }

		Rectangle {
			id: boite
			x: 16; y: 14
			width: parent.width - 32; height: 38
			color: Theme.champ
			border { width: 1; color: Theme.bordureVive }
			Icone { id: loupe; x: 12; anchors.verticalCenter: parent.verticalCenter; chemin: Icones.recherche; taille: 15; couleur: Theme.texteAccent }
			TextInput {
				id: champ
				anchors { left: loupe.right; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
				font.family: Theme.policeTexte; font.pixelSize: 15
				color: Theme.texteTitre
				clip: true
				onTextChanged: { fenetre.filtre = text; fenetre.courant = 0; }
				Texte { visible: champ.text === ""; text: "filtrer…"; taille: 15; color: Theme.texteEteint; anchors.verticalCenter: parent.verticalCenter }
				Keys.onPressed: e => {
					const ctrl = e.modifiers & Qt.ControlModifier;
					if (e.key === Qt.Key_Escape) Etat.fermer();
					else if (e.key === Qt.Key_Down) fenetre.courant = Math.min(fenetre.courant + 1, fenetre.elements.length - 1);
					else if (e.key === Qt.Key_Up) fenetre.courant = Math.max(0, fenetre.courant - 1);
					else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) fenetre.copier(fenetre.selection);
					else if (e.key === Qt.Key_Delete && fenetre.selection) PressePapiers.supprimer(fenetre.selection);
					else if (ctrl && e.key === Qt.Key_P && fenetre.selection) PressePapiers.epingler(fenetre.selection);
					else return;
					e.accepted = true;
				}
			}
		}

		ListView {
			id: liste
			anchors { top: boite.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: pied.top; margins: 16; bottomMargin: 8 }
			clip: true
			spacing: 2
			model: fenetre.elements
			currentIndex: fenetre.courant
			onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
			boundsBehavior: Flickable.StopAtBounds

			delegate: Item {
				id: ligne
				required property var modelData
				required property int index
				readonly property bool choisi: index === fenetre.courant
				readonly property bool image: modelData.type === "image"
				width: liste.width
				height: image ? 58 : 36

				Rectangle {
					anchors.fill: parent
					color: ligne.modelData.epingle ? Qt.alpha(Theme.bouton, ligne.choisi ? 0.55 : 0.4) : ligne.choisi ? Qt.alpha(Theme.bouton, 0.45) : zone.containsMouse ? Qt.alpha(Theme.bouton, 0.18) : "transparent"
				}
				Rectangle { width: 3; height: parent.height; color: ligne.modelData.epingle ? Theme.accent : ligne.choisi ? Theme.lisere : "transparent" }
				Icone {
					id: ic
					x: 12; anchors.verticalCenter: parent.verticalCenter
					chemin: fenetre.iconeDe(ligne.modelData)
					taille: 15
					couleur: ligne.modelData.epingle ? Theme.accent : Theme.texteAccent
				}
				Rectangle {
					id: vignette
					visible: ligne.image
					anchors { left: ic.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
					width: visible ? 70 : 0; height: 44
					color: Theme.tuile
					border { width: 1; color: Theme.bordure }
					Image {
						anchors { fill: parent; margins: 1 }
						source: ligne.image ? `file://${ligne.modelData.fichier}?g=${PressePapiers.generation}` : ""
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
						cache: false
						sourceSize.width: 140
					}
				}
				Rectangle {
					id: pastilleCouleur
					visible: ligne.modelData.type === "couleur"
					anchors { left: ic.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
					width: visible ? 16 : 0; height: 16
					color: visible ? ligne.modelData.apercu.trim() : "transparent"
					border { width: 1; color: Theme.lisere }
				}
				Texte {
					anchors {
						left: ligne.image ? vignette.right : pastilleCouleur.visible ? pastilleCouleur.right : ic.right; leftMargin: 12
						right: etiquette.left; rightMargin: 10; verticalCenter: parent.verticalCenter
					}
					text: ligne.modelData.apercu
					taille: 14
					color: ligne.modelData.epingle || ligne.choisi ? "#ffffff" : Theme.texte
				}
				Libelle {
					id: etiquette
					anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
					text: ligne.modelData.epingle ? "épinglé" : ligne.choisi ? "entrée" : ""
					taille: 9
					color: ligne.modelData.epingle ? Theme.accent : Theme.lisere
				}
				MouseArea {
					id: zone
					anchors.fill: parent
					hoverEnabled: true
					acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
					cursorShape: Qt.PointingHandCursor
					onClicked: m => {
						if (m.button === Qt.MiddleButton) PressePapiers.supprimer(ligne.modelData);
						else if (m.button === Qt.RightButton) PressePapiers.epingler(ligne.modelData);
						else fenetre.copier(ligne.modelData);
					}
				}
			}

			Texte {
				visible: fenetre.elements.length === 0
				anchors.centerIn: parent
				text: !PressePapiers.disponible ? "cliphist introuvable : installe cliphist et wl-clipboard" : fenetre.filtre ? "rien ne correspond" : "historique vide"
				taille: 14; color: Theme.texteEteint
			}
		}

		Item {
			id: pied
			anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16; bottomMargin: 10 }
			height: 18
			Texte { text: "entrée copier · suppr retirer · ctrl p épingler"; taille: 12; color: Theme.texteEteint }
			Texte {
				anchors.right: parent.right
				text: "tout effacer"
				taille: 12
				color: zoneEffacer.containsMouse ? Theme.xanaTexte : Theme.texteDiscret
				MouseArea { id: zoneEffacer; anchors { fill: parent; margins: -4 } hoverEnabled: true; onClicked: PressePapiers.toutEffacer() }
			}
		}
	}
}
