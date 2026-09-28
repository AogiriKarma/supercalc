import QtQuick
import qs.theme

// Fenêtre qui « pope » à un instant donné de la séquence : légère mise à l'échelle + fondu,
// calculés depuis l'horloge de la séquence (pas d'animation propre : on peut figer n'importe quel instant).
Item {
	id: root
	property real t: 0            // horloge de la séquence (ms)
	property real debut: 0        // instant d'apparition
	property real duree: 200
	readonly property real p: Math.max(0, Math.min(1, (t - debut) / duree))
	readonly property real ease: 1 - Math.pow(1 - p, 3)
	visible: t >= debut
	opacity: ease
	scale: 0.9 + 0.1 * ease
	transformOrigin: Item.Center
}
