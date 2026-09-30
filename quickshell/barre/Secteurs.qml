import QtQuick
import Quickshell.I3
import qs.theme
import qs.composants
import qs.services

// The sector pills (sway workspaces) of the given screen.
// One dot per window; click to go there; wheel for the neighbouring sector.
Row {
	id: root
	property string ecran: ""          // sway output name, e.g. "eDP-1"
	spacing: 6

	readonly property var liste: I3.workspaces.values
		.filter(w => w.monitor && w.monitor.name === root.ecran)
		.sort((a, b) => (a.number - b.number) || a.name.localeCompare(b.name))

	Repeater {
		model: root.liste
		Pastille {
			required property var modelData
			readonly property int nb: Sway.fenetresParSecteur[modelData.name] ?? 0
			readonly property bool actif: modelData.focused
			readonly property bool visibleIci: modelData.active && !modelData.focused

			prefixe: modelData.number > 0 ? String(modelData.number) : ""
			texte: Sway.nomAffiche(modelData.name)
			fond: modelData.urgent ? Theme.xana : actif ? Theme.lisere : visibleIci ? Theme.boutonSombre : Theme.bouton
			encre: actif ? Theme.encre : Theme.texteTitre
			cliquable: true
			onClique: modelData.activate()

			Row {
				spacing: 2
				anchors.verticalCenter: parent.verticalCenter
				Repeater {
					model: Math.min(nb, 6)
					Rectangle { width: 4; height: 4; color: actif ? Theme.encre : Theme.texteTitre; opacity: 0.8 }
				}
			}
		}
	}

	WheelHandler {
		onWheel: ev => I3.dispatch(ev.angleDelta.y > 0 ? "workspace prev_on_output" : "workspace next_on_output")
	}
}
