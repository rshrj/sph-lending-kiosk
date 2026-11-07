pragma Singleton
import QtQuick

// Design tokens for two switchable styles. Everything visual reads from here.
//   style "lab" — the original Kiosk Lab look (values unchanged)
//   style "sph" — ETH Student Project House (sph.ethz.ch), see design/sph/README.md
// Components only branch on `sph` where SPH needs something the lab style has no
// token for (skewed outline buttons, uppercase display type, ink-on-accent text).
QtObject {
    id: theme

    property string style: "lab"
    readonly property bool sph: style === "sph"
    readonly property var styles: [{ id: "lab", name: "Kiosk Lab" }, { id: "sph", name: "ETH SPH" }]

    property bool dark: true
    property color accent: accents[0]
    readonly property var labAccents: ["#6C7BFF", "#2DD4BF", "#F59E0B", "#F43F5E", "#A78BFA", "#38BDF8"]
    readonly property var sphAccents: [purple, yellow, green, cyan, orange]
    readonly property var accents: sph ? sphAccents : labAccents

    // Switching style picks that style's natural mode and first accent.
    function setStyle(s) {
        if (s === style) return
        style = s
        dark = !sph
        accent = accents[0]
    }

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

    // ── Surfaces ──────────────────────────────────────────────────────────────
    readonly property color bg:        sph ? (dark ? ink : paper)       : (dark ? "#0B0D12" : "#F3F5F9")
    readonly property color surface:   sph ? (dark ? "#2E2E2E" : paper) : (dark ? "#141821" : "#FFFFFF")
    readonly property color surface2:  sph ? (dark ? "#383838" : "#F7F7F7") : (dark ? "#1C2130" : "#EBEEF4")
    readonly property color surface3:  sph ? (dark ? "#444444" : "#EBEBEB") : (dark ? "#262C3D" : "#DDE2EB")
    readonly property color border:    sph ? (dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0.141, 0.141, 0.141, 0.25))
                                           : (dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.08))
    readonly property color overlay:   dark ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0.05, 0.07, 0.12, 0.35)

    // ── Text ──────────────────────────────────────────────────────────────────
    readonly property color text:      sph ? (dark ? paper : ink)       : (dark ? "#F2F4F8" : "#0E1220")
    readonly property color textDim:   sph ? (dark ? "#C4C4C4" : "#555555") : (dark ? "#9AA3B2" : "#5B6475")
    readonly property color textFaint: sph ? (dark ? "#8F8F8F" : "#777777") : (dark ? "#5D6677" : "#9AA1AE")
    // Text/icons on an accent or status fill. SPH: always ink (white fails contrast there).
    readonly property color accentText: sph ? ink : "#FFFFFF"

    // ── Status ────────────────────────────────────────────────────────────────
    readonly property color success: sph ? green  : "#22C55E"
    readonly property color warning: sph ? yellow : "#F59E0B"
    readonly property color danger:  sph ? red    : "#EF4444"

    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, sph ? (dark ? 0.22 : 0.25) : (dark ? 0.16 : 0.12))
    readonly property color accentHi: sph ? Qt.tint(accent, Qt.rgba(1, 1, 1, 0.35)) : Qt.lighter(accent, 1.18)

    // ── Line work ─────────────────────────────────────────────────────────────
    readonly property color stroke: text                     // SPH button outlines, chevrons
    readonly property color cardOutline: sph ? green : border
    readonly property real strokeCard: sph ? 3 : 1
    readonly property real strokeButton: sph ? 3 : 0
    readonly property real skewShear: sph ? -0.36397 : 0     // tan(-20°): SPH parallelogram buttons

    // ── Geometry (min touch target 56 px ≈ 8.5 mm on the 7" panel) ──────────
    readonly property int touchMin: 56
    readonly property int radiusL: sph ? 0 : 22
    readonly property int radiusM: sph ? 0 : 16
    readonly property int radiusS: sph ? 0 : 12
    readonly property int gap: 16
    readonly property int pad: 24
    readonly property int railWidth: 92

    // ── Type ──────────────────────────────────────────────────────────────────
    // font: body text. fontDisplay: headings, buttons, labels (SPH: condensed, UPPERCASE,
    // one weight — never bold it).
    readonly property string font: sph ? "Proxima Nova" : "Inter"
    readonly property string fontDisplay: sph ? "Alternate Gothic No2 Pro" : "Inter"
    readonly property int headingCaps: sph ? Font.AllUppercase : Font.MixedCase
    readonly property int headingWeight: sph ? Font.Normal : Font.Bold
    readonly property int titleWeight: sph ? Font.Normal : Font.DemiBold   // card / tile / button titles
    readonly property int displayWeight: sph ? Font.Normal : Font.Light    // big clock numbers
    readonly property real trackHeading: sph ? 1.2 : -0.5
    readonly property real trackLabel: sph ? 0.8 : 0
    readonly property real titleScale: sph ? 1.25 : 1   // condensed caps need ~25 % more size to read the same

    readonly property int fsDisplay: sph ? 112 : 92
    readonly property int fsH1: sph ? 46 : 30
    readonly property int fsH2: 21
    readonly property int fsBody: sph ? 17 : 16
    readonly property int fsSmall: 13

    // ── Motion ────────────────────────────────────────────────────────────────
    readonly property int fast: sph ? 150 : 120
    readonly property int normal: sph ? 250 : 220
    readonly property int slow: 420
    readonly property int easing: sph ? Easing.InOutQuad : Easing.OutCubic

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // Gradient end stops: SPH is flat colour only, so both ends collapse to the base colour.
    function gradTop(c) { return sph ? c : Qt.lighter(c, 1.25) }
    function gradBottom(c) { return sph ? c : Qt.darker(c, 1.35) }
    // SPH hand-drawn marker stroke: "purple" | "yellow" | "green" | "cyan" | "orange" | "black" | "white"
    function brush(name) { return Qt.resolvedUrl("../assets/sph/brush-" + name + ".svg") }
}
