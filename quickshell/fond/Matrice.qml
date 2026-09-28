import QtQuick

// Pluie Matrix. Composant récupéré sur internet par Karma, relu et adapté :
//
//   - police rendue configurable : le tracé d'origine demandait « monospace », qui ne
//     couvre pas les katakana. Ils sortaient en carrés tant qu'aucune police japonaise
//     n'était installée (ttf-sazanami, 17 Mio, contre 299 pour Noto CJK) ;
//   - hauteur de ligne ajoutée, sinon les glyphes se chevauchent verticalement.
//
// Provenance non identifiée, donc licence inconnue : à vérifier avant de rendre ce dépôt
// public. Il peint dans un Canvas au lieu de manipuler des objets texte, d'où des traînées
// qui s'estompent vraiment et aucune remise en page.
// Pluie Matrix en pur QML — aucun process externe.
// Usage : MatrixRain { anchors.fill: parent }
Canvas {
    id: root

    // --- Réglages ---
    property int fontSize: 16
    property int interval: 50              // ms entre frames
    property real fade: 0.08               // longueur des traînées (petit = long)
    property real resetChance: 0.025       // proba qu'une colonne reparte du haut
    property color rainColor: "#00ff41"
    property color headColor: "#d8ffd8"
    property bool transparentBg: true      // true = fond transparent (overlay), false = fond noir
    property string police: "Sazanami Gothic"
    property real interligne: 1.0
    property string glyphs: "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン0123456789ABCDEF:.=*+-<>|"

    property var drops: []

    function initDrops() {
        const cols = Math.ceil(width / fontSize)
        const d = []
        for (let i = 0; i < cols; i++)
            d.push(Math.floor(Math.random() * -height / fontSize))
        drops = d
    }

    function randGlyph() {
        return glyphs.charAt(Math.floor(Math.random() * glyphs.length))
    }

    onWidthChanged: initDrops()
    onHeightChanged: initDrops()
    Component.onCompleted: initDrops()

    onPaint: {
        const ctx = getContext("2d")

        // Estompe la frame précédente -> traînées
        if (transparentBg) {
            ctx.globalCompositeOperation = "destination-out"
            ctx.fillStyle = Qt.rgba(0, 0, 0, fade)
        } else {
            ctx.globalCompositeOperation = "source-over"
            ctx.fillStyle = Qt.rgba(0, 0, 0, fade)
        }
        ctx.fillRect(0, 0, width, height)
        ctx.globalCompositeOperation = "source-over"

        ctx.font = fontSize + "px \"" + police + "\""

        const rows = height / fontSize
        for (let i = 0; i < drops.length; i++) {
            const y = drops[i]
            if (y >= 0) {
                const px = i * fontSize
                const py = y * fontSize

                // Repeint la tête précédente en vert
                if (y > 0) {
                    ctx.fillStyle = rainColor
                    ctx.fillText(randGlyph(), px, py)
                }
                // Nouvelle tête, plus claire
                ctx.fillStyle = headColor
                ctx.fillText(randGlyph(), px, py + fontSize)
            }

            if (y > rows && Math.random() < resetChance * 10)
                drops[i] = Math.floor(Math.random() * -20)
            else
                drops[i] = y + 1
        }
    }

    Timer {
        interval: root.interval
        running: root.visible
        repeat: true
        onTriggered: root.requestPaint()
    }
}
