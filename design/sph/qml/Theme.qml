pragma Singleton
import QtQuick

// ETH Student Project House (sph.ethz.ch) design tokens, adapted for the
// 1024×600 kiosk. Drop-in replacement for qml/Theme.qml: every property the
// demo app reads keeps its name; SPH-specific tokens are added below them.
// Source values and rationale: design/sph/README.md.
QtObject {
    id: theme

    // ── Mode ────────────────────────────────────────────────────────────
    // SPH is a light, white-paper site. Dark is our own extension: the SPH
    // ink (#242424) becomes the page and the accents stay unchanged.
    property bool dark: false

    // ── SPH brand palette (exact values from sph.ethz.ch app.css) ───────
    readonly property color ink:         "#242424"   // --black: all text, rules, button strokes
    readonly property color paper:       "#FFFFFF"
    readonly property color purple:      "#C891FA"   // --primary: header, intro bands
    readonly property color purpleLight: "#E4C7FD"   // breadcrumb strip / tint
    readonly property color yellow:      "#FFD200"   // --secondary / --warning: announcement bands, highlights
    readonly property color green:       "#0FDF75"   // --success: card outlines, positive state
    readonly property color cyan:        "#82DCE1"   // --info: location / info bands
    readonly property color orange:      "#FF8C46"   // --orange (also --pink): call-to-action strips
    readonly property color red:         "#FE0000"   // --danger: errors only
    readonly property color grayLight:   "#EBEBEB"
    readonly property color gray:        "#777777"   // --darker

    // ── Accent (demo-app API) ───────────────────────────────────────────
    property color accent: accents[0]
    readonly property var accents: [purple, yellow, green, cyan, orange]

    // ── Surfaces (demo-app API) ─────────────────────────────────────────
    readonly property color bg:        dark ? ink       : paper
    readonly property color surface:   dark ? "#2E2E2E" : paper
    readonly property color surface2:  dark ? "#383838" : "#F7F7F7"
    readonly property color surface3:  dark ? "#444444" : grayLight
    readonly property color border:    dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0.141, 0.141, 0.141, 0.25)
    readonly property color overlay:   dark ? Qt.rgba(0, 0, 0, 0.7) : Qt.rgba(0.141, 0.141, 0.141, 0.8)

    // ── Text (demo-app API) ─────────────────────────────────────────────
    readonly property color text:      dark ? paper     : ink        // 15.5:1
    readonly property color textDim:   dark ? "#C4C4C4" : "#555555"  //  7.5:1
    readonly property color textFaint: dark ? "#8F8F8F" : gray       //  4.5:1
    // Text on ANY accent fill is ink, never white (white on these is 1.5–2.4:1).
    readonly property color accentText: ink

    // ── Status (demo-app API) ───────────────────────────────────────────
    // Fills / outlines / icons. Green & yellow fail as text on white; pair them with ink.
    readonly property color success: green
    readonly property color warning: yellow
    readonly property color danger:  red

    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.22 : 0.25)
    readonly property color accentHi: Qt.tint(accent, Qt.rgba(1, 1, 1, 0.35))

    // ── SPH line work ───────────────────────────────────────────────────
    readonly property color rule: dark ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(0.141, 0.141, 0.141, 0.8)
    readonly property color stroke: dark ? paper : ink           // button outlines, chevrons
    readonly property int strokeButton: 3                        // .btn border: 3px
    readonly property int strokeCard: 3                          // .o-info-boxes__item: 4.5px @1440 → 3px here
    readonly property int strokeRule: 2                          // .o-collapsible__item: 2px
    readonly property real skew: -20                             // .btn transform: skew(-20deg)
    readonly property real skewShear: -0.36397                   // tan(-20°), for Matrix4x4 xy

    // ── Geometry (demo-app API) ─────────────────────────────────────────
    // SPH is square-cornered everywhere (border-radius: 0). Circles only for avatars.
    readonly property int touchMin: 56
    readonly property int radiusL: 0
    readonly property int radiusM: 0
    readonly property int radiusS: 0
    readonly property int gap: 16
    readonly property int pad: 24
    readonly property int railWidth: 92
    readonly property int headerHeight: 64

    // ── Type ────────────────────────────────────────────────────────────
    // font        = body (Proxima Nova: Regular 400, Bold 700 only)
    // fontDisplay = headings, buttons, links, labels (Alternate Gothic No2: one weight,
    //               always UPPERCASE with positive tracking; never bold it)
    readonly property string font: "Proxima Nova"
    readonly property string fontDisplay: "Alternate Gothic No2 Pro"

    readonly property int fsDisplay: 96   // attract screen / hero number   (site h1 100px)
    readonly property int fsH1: 48        // page title                     (site h2 80px)
    readonly property int fsH2: 32        // section / band headline        (site h3 49px)
    readonly property int fsH3: 26        // card titles, list rows         (site h4 32px)
    readonly property int fsButton: 20    // skew buttons                   (site .btn 17px)
    readonly property int fsLabel: 17     // underlined links, small caps labels
    readonly property int fsBody: 18      // body copy                      (site 24px desktop / 17px mobile)
    readonly property int fsSmall: 14

    readonly property real lineHeightBody: 1.25      // body line-height: 1.25
    readonly property real lineHeightDisplay: 1.0    // headings line-height: 1
    readonly property real trackDisplay: 1.2         // h1 letter-spacing 1.2px
    readonly property real trackLabel: 0.8           // .link letter-spacing .8px

    // ── Motion (demo-app API) ───────────────────────────────────────────
    // Site: colours .15s ease-in-out, transforms .25s ease-in-out, reveals .3s.
    readonly property int fast: 150
    readonly property int normal: 250
    readonly property int slow: 400
    readonly property int easing: Easing.InOutQuad
    readonly property real pressScale: 1.15          // .link:hover transform: scale(1.15)

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // Asset for a brush-stroke highlight: "purple" | "yellow" | "green" | "cyan" | "orange" | "black" | "white"
    function brush(name) { return Qt.resolvedUrl("../assets/brush-" + name + ".svg") }
}
