#version 440

// Character rain, entirely on the GPU.
//
// Each fragment works out its column and its row, computes where its column's head is at this
// instant, and derives its intensity from that. Nothing is kept from one frame to the next: no
// buffer to fade, hence no cost proportional to the surface as with a Canvas.
//
// The glyphs come from a sheet (fond/atlas.png), a shader being unable to draw text.
// See scripts/dev/atlas-glyphes.py.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 taille;            // size of the item, in pixels
    float temps;            // seconds elapsed, animated from QML
    float cellule;          // side of a glyph on screen, in pixels
    float longueur;         // length of a trail, in cells
    float fondMini;         // minimum stopping depth, as a fraction of the height
    vec4 couleurTrainee;
    vec4 couleurTete;
};

layout(binding = 1) uniform sampler2D atlas;

const float ATLAS_COLONNES = 8.0;
const float ATLAS_LIGNES = 7.0;
const float NB_GLYPHES = 56.0;

// deterministic noise: the same column behaves the same from one frame to the next
float hasard(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

void main() {
    vec2 p = qt_TexCoord0 * taille;
    float colonne = floor(p.x / cellule);
    float ligne = floor(p.y / cellule);
    float lignesTotal = ceil(taille.y / cellule);

    // each column has its own speed, starting offset and stopping depth
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

    // the glyph changes now and then, never depending on the previous frame
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
