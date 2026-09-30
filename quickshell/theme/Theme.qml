pragma Singleton
import QtQuick
import Quickshell
import qs.services

// SUPERCALC theme tokens. The whole config reads these values; nothing is hard-coded elsewhere.
Singleton {
	id: root

	// --- backgrounds ---
	readonly property color fondHaut: "#0f4b5a"
	readonly property color fondBas: "#040d12"
	readonly property color corps: "#05111a"
	readonly property color champ: "#081c27"
	readonly property color tuile: "#0c2733"
	readonly property color separateur: "#16404f"

	// --- frames ---
	readonly property color cadreFocus: "#2f86b0"
	readonly property color cadreInactif: "#1c5572"
	readonly property color bouton: "#2f7697"
	readonly property color boutonSombre: "#1d5673"
	readonly property color lisere: "#d4f4ff"
	readonly property color bordure: "#2f6f8f"
	readonly property color bordureVive: "#6cc6e6"

	// --- text ---
	readonly property color texteTitre: "#eafaff"
	readonly property color texte: "#c6ecf8"
	readonly property color texteAccent: "#8fdcf5"
	readonly property color texteDiscret: "#5f93ab"
	readonly property color texteEteint: "#4b7f95"
	readonly property color encre: "#062230"

	// --- signals ---
	readonly property color ambre: "#ffb13b"
	readonly property color ambreSombre: "#2a1d08"
	readonly property color energie: "#5be07c"
	readonly property color xana: "#e5484d"
	readonly property color xanaCadre: "#b33a3f"
	readonly property color xanaCorps: "#1a080c"
	readonly property color xanaTexte: "#ff8a8e"
	readonly property color filDeFer: "#3fe07a"
	readonly property color pointEteint: "#12323f"

	// --- adjustable accent (settings -> appearance) ---
	readonly property string accentNom: Reglages.accent
	readonly property var accents: ({ ambre: "#ffb13b", energie: "#5be07c", holomap: "#8fdcf5", xana: "#e5484d" })
	readonly property color accent: accents[accentNom] ?? ambre
	readonly property color accentSombre: Qt.tint(corps, Qt.alpha(accent, 0.2))

	// --- fonts ---
	readonly property string policeAffiche: "Gunship Expanded"
	readonly property string policeTitre: "Gunship"
	readonly property string policeLibelle: "Gunship Condensed"
	readonly property string policeTexte: "Share Tech Mono"

	// --- sizes (logical px; Qt applies each screen's scale) ---
	// Thickness of the bar's pills — the only number to touch to resize it. Everything it holds
	// derives from it through `echelleBarre`: without that, making the bar taller leaves tiny text
	// floating in the middle of the empty space.
	readonly property int barreHauteur: 26
	// Size of the bar's CONTENT, deliberately independent of its height: one may want more
	// readable text without a thicker bar. It only applies to text and margins — the icons are
	// bounded by the height of the pills.
	readonly property real echelleBarre: 1.25
	function dansBarre(px) { return Math.round(px * echelleBarre); }
	readonly property int marge: 12
	readonly property int biseau: Reglages.biseau
	readonly property int biseauPetit: Math.round(Reglages.biseau / 2)
	readonly property int titreHauteur: 26
	readonly property int bandeHauteur: 14
	readonly property int epaisseurCadre: 3

	readonly property real halo: Reglages.modeJeu ? 0 : Reglages.halo
	readonly property real opacitePanneau: Reglages.opacite
	readonly property bool animations: Reglages.animations && !Reglages.modeJeu
	readonly property int dureeCourte: animations ? 140 : 0
	readonly property int dureeMoyenne: animations ? 220 : 0
}
