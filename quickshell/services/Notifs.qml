pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.theme

// Serveur de notifications (remplace mako). Garde un journal et une file de bulles à afficher.
Singleton {
	id: root

	readonly property var journal: serveur.trackedNotifications.values
	property int nonLues: 0
	property bool silencieux: false
	// bulles actuellement affichées (les plus récentes en premier)
	property var bulles: []

	function effacerTout() {
		for (const n of serveur.trackedNotifications.values.slice()) n.dismiss();
		nonLues = 0;
	}
	function marquerLues() { nonLues = 0; }

	// heure de réception (le protocole ne la transmet pas : on la note à l'arrivée)
	property var recues: ({})
	function heure(n) {
		const d = recues[n.id];
		return d ? Qt.formatTime(d, "hh:mm") : "";
	}
	function retirerBulle(n) { bulles = bulles.filter(b => b !== n); }

	// durée d'affichage d'une bulle en ms (0 = reste jusqu'à action) ; expireTimeout est en ms, -1 = défaut
	function duree(n) {
		if (n.urgency === NotificationUrgency.Critical) return 0;
		if (n.expireTimeout > 0) return n.expireTimeout;
		if (n.expireTimeout === 0) return 0;
		return n.urgency === NotificationUrgency.Low ? 4000 : 6500;
	}
	// icône au trait selon l'appli émettrice
	function icone(n) {
		const cle = ((n.desktopEntry || "") + " " + (n.appName || "") + " " + (n.hints?.category ?? "")).toLowerCase();
		const table = [
			[/grim|capture|screenshot|flameshot|satty/, Icones.capture],
			[/sync|nextcloud|dropbox|rclone/, Icones.synchro],
			[/batter|energie|énergie|power|upower/, Icones.batterie],
			[/network|wifi|nm-applet|iwd/, Icones.wifi],
			[/bluetooth|blueman/, Icones.bluetooth],
			[/volume|audio|pipewire|pulse/, Icones.volume],
			[/spotify|mpd|music|musique|player/, Icones.musique],
			[/mail|thunderbird|aerc/, Icones.chat],
			[/pacman|yay|paru|update|mise à jour/, Icones.paquet],
			[/clipboard|cliphist|presse/, Icones.copier],
			[/transfer|device\.|usb|udisk/, Icones.fichiers],
		];
		for (const [motif, ic] of table) if (motif.test(cle)) return ic;
		const e = Applis.entree(n.desktopEntry || n.appName);
		const ic = Applis.icone(e, n.desktopEntry || n.appName);
		return ic === Icones.secteur ? (n.urgency === NotificationUrgency.Critical ? Icones.alerte : Icones.cloche) : ic;
	}

	NotificationServer {
		id: serveur
		keepOnReload: true
		bodySupported: true
		bodyMarkupSupported: false
		actionsSupported: true
		imageSupported: true
		persistenceSupported: true

		onNotification: n => {
			n.tracked = true;
			root.recues[n.id] = new Date();
			n.closed.connect(() => root.retirerBulle(n));
			root.nonLues += 1;
			const critique = n.urgency === NotificationUrgency.Critical;
			if (!root.silencieux || critique) root.bulles = [n].concat(root.bulles).slice(0, 4);
		}
	}
}
