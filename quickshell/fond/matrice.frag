#version 440

// Pluie de caractères, entièrement sur le GPU.
//
// Chaque fragment déduit sa colonne et sa ligne, calcule où en est la tête de sa colonne
// à cet instant, et en tire son intensité. Rien n'est stocké d'une image à l'autre : pas
// de tampon à estomper, donc pas de coût proportionnel à la surface comme avec un Canvas.
//
// Les glyphes viennent d'une planche (fond/atlas.png), un shader ne sachant pas dessiner
// du texte. Voir scripts/dev/atlas-glyphes.py.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 taille;            // dimensions de l'élément, en pixels
    float temps;            // secondes écoulées, animé depuis QML
    float cellule;          // côté d'un glyphe à l'écran, en pixels
    float longueur;         // longueur d'une traînée, en cellules
    float fondMini;         // profondeur d'arrêt minimale, en fraction de la hauteur
    vec4 couleurTrainee;
    vec4 couleurTete;
};

layout(binding = 1) uniform sampler2D atlas;

const float ATLAS_COLONNES = 8.0;
const float ATLAS_LIGNES = 7.0;
const float NB_GLYPHES = 56.0;

// bruit déterministe : même colonne, même comportement d'une image à l'autre
float hasard(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

void main() {
    vec2 p = qt_TexCoord0 * taille;
    float colonne = floor(p.x / cellule);
    float ligne = floor(p.y / cellule);
    float lignesTotal = ceil(taille.y / cellule);

    // chaque colonne a sa vitesse, son décalage de départ et sa profondeur d'arrêt
    float vitesse = 8.0 + hasard(colonne) * 16.0;
    float depart = hasard(colonne + 17.3) * 120.0;
    float fond = lignesTotal * (fondMini + hasard(colonne + 41.7) * (1.0 - fondMini));

    float cycle = fond + longueur * 2.0;
    float tete = mod(temps * vitesse + depart, cycle) - longueur;
    float derriere = tete - ligne;

    if (derriere < 0.0 || derriere > longueur || ligne > fond) {
        fragColor = vec4(0.0);
        return;
    }

    // le glyphe change de temps en temps, sans jamais dépendre de l'image précédente
    float graine = colonne * 31.0 + ligne * 7.0 + floor(temps * 6.0 + hasard(ligne) * 10.0);
    float indice = floor(hasard(graine) * NB_GLYPHES);
    vec2 caseAtlas = vec2(mod(indice, ATLAS_COLONNES), floor(indice / ATLAS_COLONNES));
    vec2 dansCellule = fract(p / cellule);
    vec2 uv = (caseAtlas + dansCellule) / vec2(ATLAS_COLONNES, ATLAS_LIGNES);

    float encre = texture(atlas, uv).a;
    float intensite = 1.0 - derriere / longueur;
    vec4 teinte = mix(couleurTrainee, couleurTete, step(derriere, 0.9));

    fragColor = vec4(teinte.rgb, 1.0) * encre * intensite * teinte.a * qt_Opacity;
}
