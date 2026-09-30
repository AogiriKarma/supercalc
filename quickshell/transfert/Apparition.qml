import QtQuick
import qs.theme

// A window that pops in at a given moment of the sequence: a slight scale plus a fade, both
// computed from the sequence's clock (no animation of its own, so any instant can be frozen).
Item {
	id: root
	property real t: 0            // the sequence's clock (ms)
	property real debut: 0        // the moment it appears
	property real duree: 200
	readonly property real p: Math.max(0, Math.min(1, (t - debut) / duree))
	readonly property real ease: 1 - Math.pow(1 - p, 3)
	visible: t >= debut
	opacity: ease
	scale: 0.9 + 0.1 * ease
	transformOrigin: Item.Center
}
