import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.composants
import qs.services

// Power menu (Super+Shift+E): lock, reload, suspend, log out, reboot, shut down.
// Every action except lock and suspend is confirmed by holding the key (or the click) for a
// second.
PanelWindow {
	id: fenetre
	screen: Etat.ecranCible
	visible: ouvert || fondu.running || cadre.anime
	anchors { top: true; bottom: true; left: true; right: true }
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.namespace: "supercalc-energie"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: ouvert ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	readonly property bool ouvert: Etat.panneau === "power"
	property int choix: 0
	property real maintien: 0          // 0..1 while an action awaiting confirmation is held
	property int enMaintien: -1

	onOuvertChanged: if (ouvert) { choix = 4; maintien = 0; enMaintien = -1; cadre.forceActiveFocus(); Controle.relire(); }

	// Reloading the shell. The transfer sequence's `already played` flag lives in
	// XDG_RUNTIME_DIR, so it survives a reload: without clearing it first, the desktop would come
	// back in silence. We wait for the rm to finish before reloading.
	Process {
		id: rechargement
		command: ["sh", "-c", 'rm -f "${XDG_RUNTIME_DIR:-/tmp}/supercalc-transfert"']
		onExited: Quickshell.reload(true)
	}

	readonly property var actions: [
		{ n: "Verrouiller", s: "scanner d'identification", ic: Icones.verrou, k: "L", f: () => Etat.verrouiller() },
		{ n: "Recharger l'interface", s: "relance le bureau et rejoue le transfert", ic: Icones.synchro, k: "C", confirmer: true, f: () => { Etat.fermer(); rechargement.running = true; } },
		{ n: "Mise en veille", s: "la session reste ouverte", ic: Icones.lune, k: "V", f: () => { Etat.fermer(); Quickshell.execDetached(["systemctl", "suspend"]); } },
		{ n: "Dévirtualiser", s: "fermer la session sway", ic: Icones.sortie, k: "E", confirmer: true, f: () => Quickshell.execDetached(["swaymsg", "exit"]) },
		{ n: "Retour vers le passé", s: "redémarrer le supercalculateur", ic: Icones.retour, k: "R", confirmer: true, f: () => Quickshell.execDetached(["systemctl", "reboot"]) },
		{ n: "Arrêt du supercalculateur", s: "éteindre complètement", ic: Icones.arret, k: "S", confirmer: true, xana: true, f: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
	]

	function lancer(i) {
		const a = actions[i]; if (!a) return;
		if (a.confirmer) { enMaintien = i; animMaintien.restart(); }
		else a.f();
	}
	function relacher() { if (maintien < 1) { animMaintien.stop(); maintien = 0; enMaintien = -1; } }
	NumberAnimation {
		id: animMaintien
		target: fenetre; property: "maintien"
		from: 0; to: 1; duration: 900
		onFinished: if (fenetre.maintien >= 1) fenetre.actions[fenetre.enMaintien]?.f()
	}

	Rectangle {
		anchors.fill: parent
		color: "#020a0e"
		opacity: fenetre.ouvert ? 0.8 : 0
		Behavior on opacity { NumberAnimation { id: fondu; duration: Theme.dureeMoyenne; easing.type: Easing.OutCubic } }
		MouseArea { anchors.fill: parent; onClicked: Etat.fermer() }
	}

	// clock and session above
	Column {
		anchors { horizontalCenter: parent.horizontalCenter; bottom: cadre.top; bottomMargin: 34 }
		spacing: 8
		opacity: fenetre.ouvert ? 1 : 0
		Behavior on opacity { NumberAnimation { duration: Theme.dureeMoyenne } }
		Text {
			anchors.horizontalCenter: parent.horizontalCenter
			text: Qt.formatTime(horloge.date, "hh:mm")
			font.family: Theme.policeAffiche; font.pixelSize: Math.min(96, fenetre.height * 0.09); font.letterSpacing: 6
			color: Theme.texteTitre
			SystemClock { id: horloge; precision: SystemClock.Minutes }
		}
		Libelle {
			anchors.horizontalCenter: parent.horizontalCenter
			text: `Session ${Controle.utilisateur} · en ligne ${Controle.enLigne}`
			taille: 12; color: Theme.texteAccent
		}
	}

	Fenetre {
		id: cadre
		ouvre: fenetre.ouvert
		titre: "Commandes système"
		width: Math.min(560, fenetre.width - 48)
		height: liste.implicitHeight + Theme.titreHauteur + Theme.bandeHauteur + 36
		anchors.centerIn: parent
		anchors.verticalCenterOffset: fenetre.height * 0.06
		// opacity driven by Fenetre, so it follows the unfolding
		focus: true
		MouseArea { anchors.fill: parent }

		Keys.onPressed: e => {
			if (e.isAutoRepeat) { e.accepted = true; return; }
			const i = fenetre.actions.findIndex(a => a.k === e.text.toUpperCase());
			if (e.key === Qt.Key_Escape) Etat.fermer();
			else if (e.key === Qt.Key_Down || e.key === Qt.Key_J || e.key === Qt.Key_Tab) fenetre.choix = (fenetre.choix + 1) % fenetre.actions.length;
			else if (e.key === Qt.Key_Up || e.key === Qt.Key_K || e.key === Qt.Key_Backtab) fenetre.choix = (fenetre.choix - 1 + fenetre.actions.length) % fenetre.actions.length;
			else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) fenetre.lancer(fenetre.choix);
			else if (i >= 0) { fenetre.choix = i; fenetre.lancer(i); }
			else return;
			e.accepted = true;
		}
		Keys.onReleased: e => { if (!e.isAutoRepeat) fenetre.relacher(); }

		Column {
			id: liste
			x: 18; y: 18
			width: parent.width - 36
			spacing: 6
			Repeater {
				model: fenetre.actions
				Item {
					id: ligne
					required property var modelData
					required property int index
					readonly property bool choisi: index === fenetre.choix
					readonly property bool xana: !!modelData.xana
					width: liste.width
					height: choisi ? 62 : 56
					Behavior on height { NumberAnimation { duration: Theme.dureeCourte } }

					Rectangle {
						anchors.fill: parent
						color: ligne.xana ? Qt.rgba(40 / 255, 10 / 255, 14 / 255, ligne.choisi ? 0.95 : 0.8) : "transparent"
						border { width: 1; color: ligne.choisi ? (ligne.xana ? Theme.xanaTexte : Theme.lisere) : (ligne.xana ? "#7a2a2e" : Theme.separateur) }
						Rectangle {
							anchors { fill: parent; margins: 1 }
							visible: ligne.choisi && !ligne.xana
							gradient: Gradient {
								orientation: Gradient.Horizontal
								GradientStop { position: 0; color: Theme.bouton }
								GradientStop { position: 1; color: Theme.boutonSombre }
							}
						}
						// hold gauge
						Rectangle {
							anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1 }
							width: fenetre.enMaintien === ligne.index ? (parent.width - 2) * fenetre.maintien : 0
							color: ligne.xana ? Qt.alpha(Theme.xana, 0.35) : Qt.alpha(Theme.accent, 0.3)
						}
						Rectangle { width: 3; height: parent.height; color: ligne.choisi ? (ligne.xana ? Theme.xana : Theme.accent) : "transparent" }
					}
					Row {
						anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
						spacing: 14
						Rectangle {
							width: 34; height: 34
							anchors.verticalCenter: parent.verticalCenter
							color: ligne.xana ? "#2a0f14" : ligne.choisi ? Theme.accent : Theme.tuile
							Icone { anchors.centerIn: parent; chemin: ligne.modelData.ic; taille: 18; couleur: ligne.xana ? Theme.xanaTexte : ligne.choisi ? Theme.encre : Theme.texteAccent }
						}
						Column {
							anchors.verticalCenter: parent.verticalCenter
							spacing: 3
							Libelle { text: ligne.modelData.n; taille: 12; color: ligne.xana ? Theme.xanaTexte : ligne.choisi ? "#ffffff" : Theme.texte }
							Texte {
								text: fenetre.enMaintien === ligne.index ? "maintenir pour confirmer…" : ligne.modelData.s
								taille: 12; color: ligne.xana ? "#b86a6e" : ligne.choisi ? "#bfeefc" : Theme.texteDiscret
							}
						}
					}
					Touche {
						anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
						texte: ligne.modelData.k
					}
					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onEntered: fenetre.choix = ligne.index
						onPressed: fenetre.lancer(ligne.index)
						onReleased: fenetre.relacher()
						onCanceled: fenetre.relacher()
					}
				}
			}
			Item {
				width: parent.width; height: 26
				Texte { anchors { left: parent.left; bottom: parent.bottom } text: "↑ ↓ naviguer · entrée valider"; taille: 12; color: Theme.texteEteint }
				Texte { anchors { right: parent.right; bottom: parent.bottom } text: "recharger, quitter, redémarrer, éteindre : maintenir"; taille: 12; color: Theme.texteEteint }
			}
		}
	}
}
