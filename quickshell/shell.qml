//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.barre
import qs.fond
import qs.dock
import qs.osd
import qs.notifs
import qs.lanceur
import qs.panneau
import qs.holomap
import qs.manuel
import qs.energie
import qs.verrou
import qs.pressepapiers
import qs.calendrier
import qs.reglages
import qs.transfert
import qs.autorisation
import qs.services
import qs.theme

// SUPERCALC — a sway + Quickshell desktop in the style of the supercomputer.
// Everything adapts to the screens present: one bar per screen, created and removed live.
ShellRoot {
	FontLoader { source: Quickshell.shellPath("polices/gunship.ttf") }
	FontLoader { source: Quickshell.shellPath("polices/gunshipcond.ttf") }
	FontLoader { source: Quickshell.shellPath("polices/gunshipexpand.ttf") }
	FontLoader { source: Quickshell.shellPath("polices/ShareTechMono-Regular.ttf") }

	Fond {}

	Variants {
		model: Quickshell.screens
		Barre {}
	}

	Dock {}
	Jauge {}
	Bulles {}
	FenetreLanceur {}
	PanneauControle {}
	Holomap {}
	Manuel {}
	MenuEnergie {}
	Verrou {}
	PanneauPressePapiers {}
	Calendrier {}
	FenetreReglages {}
	Transfert {}
	AgentPolkit {}

	// --- entry points for the sway binds (qs -c supercalc ipc call …) ---
	IpcHandler {
		target: "panneaux"
		function basculer(nom: string): void { Etat.basculer(nom); }
		function ouvrir(nom: string): void { Etat.ouvrir(nom); }
		function fermer(): void { Etat.fermer(); }
		function courant(): string { return Etat.panneau; }
	}
	IpcHandler {
		target: "notifs"
		function basculerSilence(): void { Notifs.silencieux = !Notifs.silencieux; }
		function fermerDerniere(): void { if (Notifs.bulles.length) Notifs.retirerBulle(Notifs.bulles[0]); }
	}
	IpcHandler {
		target: "lanceur"
		// opens the launcher with text already typed (e.g. "=" for the calculator)
		function ouvrir(texte: string): void { Etat.ouvrir("lanceur"); Lanceur.requete = texte; }
	}
	IpcHandler {
		target: "osd"
		function luminosite(): void { Osd.luminosite(); }
		function afficher(nom: string, valeur: real, texte: string): void {
			const ic = { volume: Icones.volume, micro: Icones.micro, "écran": Icones.ecran, clavier: Icones.clavier }[nom] ?? Icones.secteur;
			Osd.montrer(nom, ic, valeur, texte, false);
		}
	}
	IpcHandler {
		target: "session"
		function verrouiller(): void { Etat.verrouiller(); }
		function rechargerTheme(): void { Quickshell.reload(false); }
		function basculerModeJeu(): void { Reglages.modeJeu = !Reglages.modeJeu; }
	}
}
