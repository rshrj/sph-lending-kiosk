pragma Singleton
import QtQuick

// Design tokens: ETH Student Project House (sph.ethz.ch), light mode only.
// Spec: design/sph/README.md. Rules that matter most here:
//   ink #242424 text on every accent (never white), Alternate Gothic UPPERCASE for
//   headings/buttons, Proxima Nova body, radius 0, skewed −20° outline buttons.
QtObject {
    id: theme

    // ── SPH brand palette (exact values from sph.ethz.ch app.css) ───────────
    readonly property color ink:         "#242424"
    readonly property color paper:       "#FFFFFF"
    readonly property color purple:      "#C891FA"
    readonly property color purpleLight: "#E4C7FD"
    readonly property color yellow:      "#FFD200"
    readonly property color green:       "#0FDF75"
    readonly property color cyan:        "#82DCE1"
    readonly property color orange:      "#FF8C46"
    readonly property color red:         "#FE0000"

    readonly property color accent: purple

    // ── Surfaces ──────────────────────────────────────────────────────────────
    readonly property color bg:        paper
    readonly property color surface:   paper
    readonly property color surface2:  "#F7F7F7"
    readonly property color surface3:  "#EBEBEB"
    readonly property color border:    Qt.rgba(0.141, 0.141, 0.141, 0.25)
    readonly property color overlay:   Qt.rgba(0.141, 0.141, 0.141, 0.55)

    // ── Text ──────────────────────────────────────────────────────────────────
    readonly property color text:      ink
    readonly property color textDim:   "#555555"
    readonly property color textFaint: "#777777"
    readonly property color accentText: ink     // text/icons on any accent or status fill

    // ── Status ────────────────────────────────────────────────────────────────
    readonly property color success: green
    readonly property color warning: yellow
    readonly property color danger:  red

    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.25)

    // ── Line work ─────────────────────────────────────────────────────────────
    readonly property color stroke: ink              // button outlines, rules
    readonly property color cardOutline: green
    readonly property real strokeCard: 3
    readonly property real strokeButton: 3
    readonly property real rule: 2
    readonly property real skewShear: -0.36397       // tan(−20°): parallelogram buttons

    // ── Geometry (min touch target 56 px ≈ 8.5 mm on the 7" panel) ──────────
    readonly property int touchMin: 56
    readonly property int radiusL: 0
    readonly property int radiusM: 0
    readonly property int radiusS: 0
    readonly property int gap: 16
    readonly property int pad: 24
    readonly property int headerHeight: 72

    // ── Type ──────────────────────────────────────────────────────────────────
    // font: body text. fontDisplay: headings, buttons, labels — condensed, UPPERCASE,
    // one weight (never bold it).
    readonly property string font: "Proxima Nova"
    readonly property string fontDisplay: "Alternate Gothic No2 Pro"
    readonly property int headingCaps: Font.AllUppercase
    readonly property int headingWeight: Font.Normal
    readonly property int titleWeight: Font.Normal
    readonly property real trackHeading: 1.2
    readonly property real trackLabel: 0.8
    readonly property real titleScale: 1.25   // condensed caps need ~25 % more size to read the same

    readonly property int fsDisplay: 112
    readonly property int fsH1: 52
    readonly property int fsH2: 34
    readonly property int fsH3: 26
    readonly property int fsBody: 17
    readonly property int fsSmall: 14

    // ── Motion ────────────────────────────────────────────────────────────────
    readonly property int fast: 150
    readonly property int normal: 250
    readonly property int slow: 400
    readonly property int easing: Easing.InOutQuad

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // Hand-drawn marker stroke: "purple" | "yellow" | "green" | "orange"
    function brush(name) { return Qt.resolvedUrl("../assets/sph/brush-" + name + ".svg") }
}
