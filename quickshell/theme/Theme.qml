pragma Singleton
import QtQuick
import Quickshell
import qs.services

// Jetons du thème SUPERCALC. Toute la config lit ces valeurs, rien n'est codé en dur ailleurs.
Singleton {
	id: root

	// --- fonds ---
	readonly property color fondHaut: "#0f4b5a"
	readonly property color fondBas: "#040d12"
	readonly property color corps: "#05111a"
	readonly property color champ: "#081c27"
	readonly property color tuile: "#0c2733"
	readonly property color separateur: "#16404f"

	// --- cadres ---
	readonly property color cadreFocus: "#2f86b0"
	readonly property color cadreInactif: "#1c5572"
	readonly property color bouton: "#2f7697"
	readonly property color boutonSombre: "#1d5673"
	readonly property color lisere: "#d4f4ff"
	readonly property color bordure: "#2f6f8f"
	readonly property color bordureVive: "#6cc6e6"

	// --- texte ---
	readonly property color texteTitre: "#eafaff"
	readonly property color texte: "#c6ecf8"
	readonly property color texteAccent: "#8fdcf5"
	readonly property color texteDiscret: "#5f93ab"
	readonly property color texteEteint: "#4b7f95"
	readonly property color encre: "#062230"

	// --- signaux ---
	readonly property color ambre: "#ffb13b"
	readonly property color ambreSombre: "#2a1d08"
	readonly property color energie: "#5be07c"
	readonly property color xana: "#e5484d"
	readonly property color xanaCadre: "#b33a3f"
	readonly property color xanaCorps: "#1a080c"
	readonly property color xanaTexte: "#ff8a8e"
	readonly property color filDeFer: "#3fe07a"
	readonly property color pointEteint: "#12323f"

	// --- accent réglable (réglages → apparence) ---
	readonly property string accentNom: Reglages.accent
	readonly property var accents: ({ ambre: "#ffb13b", energie: "#5be07c", holomap: "#8fdcf5", xana: "#e5484d" })
	readonly property color accent: accents[accentNom] ?? ambre
	readonly property color accentSombre: Qt.tint(corps, Qt.alpha(accent, 0.2))

	// --- polices ---
	readonly property string policeAffiche: "Gunship Expanded"
	readonly property string policeTitre: "Gunship"
	readonly property string policeLibelle: "Gunship Condensed"
	readonly property string policeTexte: "Share Tech Mono"

	// --- tailles (px logiques ; Qt applique l'échelle de chaque écran) ---
	// Épaisseur des pastilles de la barre — le seul nombre à toucher pour la redimensionner.
	// Tout ce qu'elle contient en dérive par « echelleBarre », comme le faisait l'ancienne
	// barre de Karma : sans ça, agrandir la barre laisse un texte minuscule au milieu du vide.
	readonly property int barreHauteur: 26
	// Taille du CONTENU de la barre, volontairement indépendante de sa hauteur : on peut
	// vouloir un texte plus lisible sans épaissir la barre. Ne s'applique qu'au texte et
	// aux marges — les icônes, elles, sont bornées par la hauteur des pastilles.
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
