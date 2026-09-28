pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3

// Journal affiché en fond d'écran. Deux sources, mêlées dans un même flux :
//
//   - journalctl --user, le vrai journal systemd de la session ;
//   - la télémétrie du bureau : secteur, fenêtre, processeur, mémoire, réseau, énergie.
//
// La seconde existe parce que le journal utilisateur est calme — quelques lignes par
// heure — et qu'un journal figé ne ressemble à rien. Tout ce qui est écrit ici est
// mesuré, rien n'est inventé : ce sont les mêmes valeurs que la barre affiche.
//
// Singleton : Variants crée une fenêtre par écran, il ne doit exister qu'un « -f ».
Singleton {
	id: root

	property int maximum: 22
	property var lignes: []

	function horodate() {
		const d = new Date();
		const n = v => (v < 10 ? "0" + v : String(v));
		return n(d.getHours()) + ":" + n(d.getMinutes()) + ":" + n(d.getSeconds());
	}

	function ajouter(source, texte) {
		const suite = root.lignes.concat([{ h: horodate(), src: source, txt: texte }]);
		root.lignes = suite.slice(-root.maximum);
	}

	// ---------------------------------------------------------------- journal systemd
	Process {
		running: true
		command: ["journalctl", "--user", "-f", "-n", "8", "-o", "short", "--no-hostname", "-q"]
		stdout: SplitParser {
			onRead: brut => {
				// « Sep 28 07:15:31 unite[pid]: message »
				const m = brut.match(/^\w+\s+\d+\s+\d\d:\d\d:\d\d\s+([^:]+):\s*(.*)$/);
				if (!m || !m[2]) return;
				root.ajouter(m[1].replace(/\[\d+\]$/, "").split("/").pop(), m[2]);
			}
		}
	}

	// ---------------------------------------------------------------- télémétrie
	readonly property string secteur: I3.focusedWorkspace?.name ?? ""
	onSecteurChanged: if (secteur) ajouter("transfert", "secteur " + Sway.nomAffiche(secteur).toUpperCase())

	readonly property string fenetre: Sway.titreFocus
	onFenetreChanged: if (fenetre) ajouter("tour", "focus « " + fenetre.slice(0, 48) + " »")

	readonly property string liaison: Controle.enLigne
	onLiaisonChanged: ajouter("liaison", liaison)

	readonly property bool charge: Systeme.enCharge
	onChargeChanged: ajouter("énergie", charge ? "alimentation secteur rétablie" : "sur batterie")

	// relevé périodique : le flux ne s'arrête jamais complètement
	Timer {
		interval: 4000
		running: true
		repeat: true
		onTriggered: {
			const c = Math.round(Systeme.cpu * 100);
			const m = Systeme.memoireTotale > 0
				? Math.round(Systeme.memoireUtilisee / Systeme.memoireTotale * 100) : 0;
			root.ajouter("supercalc", `charge ${c} % · mémoire ${m} % · ${Sway.fenetres.length} fenêtres actives`);
		}
	}
}
