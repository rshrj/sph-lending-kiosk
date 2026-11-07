pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Kiosk

// Touch accuracy test. A consistent offset (bias) means the touch layer is
// mis-calibrated or mapped to the wrong output; large scatter means the target
// size is too small for real fingers.
RowLayout {
    id: pane
    spacing: Theme.gap

    // 7" panel, 1024×600: 1186.8 px diagonal / 177.8 mm ≈ 6.68 px/mm
    readonly property real pxPerMm: 6.675
    readonly property var sizes: [72, 56, 40, 28]
    property int sizeIndex: 1
    readonly property int targetSize: sizes[sizeIndex]
    readonly property int roundLength: 15

    property bool running: false
    property int shown: 0
    property var hits: []       // [{dx, dy, hit, ms}]
    property double shownAt: 0

    readonly property var stats: {
        const n = hits.length
        if (n === 0) return { n: 0, hitRate: 0, meanErr: 0, biasX: 0, biasY: 0, ms: 0 }
        let h = 0, err = 0, bx = 0, by = 0, ms = 0
        for (const s of hits) {
            if (s.hit) ++h
            err += Math.hypot(s.dx, s.dy); bx += s.dx; by += s.dy; ms += s.ms
        }
        return { n: n, hitRate: h / n, meanErr: err / n, biasX: bx / n, biasY: by / n, ms: ms / n }
    }

    function start() {
        hits = []
        shown = 0
        running = true
        next()
    }
    function next() {
        if (shown >= roundLength) {
            running = false
            Notify.success("Round done — " + Math.round(stats.hitRate * 100) + "% hits")
            return
        }
        const m = targetSize / 2 + 12
        target.x = m + Math.random() * (field.width - 2 * m) - target.width / 2
        target.y = m + Math.random() * (field.height - 2 * m) - target.height / 2
        target.appear()
        shownAt = Date.now()
        shown++
    }
    function register(pos) {
        if (!running) return
        const cx = target.x + target.width / 2, cy = target.y + target.height / 2
        const dx = pos.x - cx, dy = pos.y - cy
        const hit = Math.hypot(dx, dy) <= targetSize / 2
        hits = hits.concat([{ dx: dx, dy: dy, hit: hit, ms: Date.now() - shownAt }])
        if (!hit) missFlash.restart()
        next()
    }

    // --- Playfield ---------------------------------------------------------------
    Rectangle {
        id: field
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Theme.surface
        radius: Theme.radiusL
        border.width: 1
        border.color: Theme.border
        clip: true

        Rectangle {
            id: missOverlay
            anchors.fill: parent; radius: parent.radius
            color: Theme.danger; opacity: 0
            SequentialAnimation { id: missFlash
                NumberAnimation { target: missOverlay; property: "opacity"; to: 0.12; duration: 50 }
                NumberAnimation { target: missOverlay; property: "opacity"; to: 0; duration: 250 }
            }
        }

        Item {
            id: target
            visible: pane.running
            width: pane.targetSize; height: width
            function appear() { popIn.restart() }
            Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.accentSoft; border.width: 2; border.color: Theme.accent }
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.5; height: width; radius: width / 2; color: "transparent"; border.width: 2; border.color: Theme.accent }
            Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Theme.accent }
            NumberAnimation on scale { id: popIn; running: false; from: 0.3; to: 1; duration: 220; easing.type: Easing.OutBack }
        }

        // Use the *press* position: that is where the finger actually landed.
        TapHandler {
            gesturePolicy: TapHandler.DragThreshold
            onPressedChanged: if (pressed) pane.register(point.position)
        }

        Column {
            anchors.centerIn: parent
            spacing: 18
            visible: !pane.running
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pane.stats.n > 0 ? "Round complete" : "Tap " + pane.roundLength + " targets as they appear"
                font.family: Theme.font; font.pixelSize: 21; font.weight: Font.DemiBold
                color: Theme.text
            }
            Segmented {
                anchors.horizontalCenter: parent.horizontalCenter
                model: pane.sizes.map(s => (s / pane.pxPerMm).toFixed(0) + " mm")
                segmentWidth: 84
                currentIndex: pane.sizeIndex
                onActivated: (i) => pane.sizeIndex = i
            }
            KButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pane.stats.n > 0 ? "Go again" : "Start"
                iconPath: Icons.target
                onClicked: pane.start()
            }
        }

        Text {
            anchors { right: parent.right; top: parent.top; margins: 14 }
            visible: pane.running
            text: pane.shown + " / " + pane.roundLength
            font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Theme.textDim
        }
    }

    // --- Results -----------------------------------------------------------------
    Rectangle {
        Layout.preferredWidth: 300
        Layout.fillHeight: true
        color: Theme.surface
        radius: Theme.radiusL
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            anchors { fill: parent; margins: 18 }
            spacing: 10

            Text { text: "Where your taps landed"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.text }

            // Scatter of offsets relative to the target centre (scaled 2×).
            Item {
                id: scatter
                Layout.fillWidth: true
                Layout.preferredHeight: width * 0.62
                readonly property real k: 2
                Rectangle { anchors.fill: parent; radius: Theme.radiusM; color: Theme.surface2 }
                Rectangle {
                    anchors.centerIn: parent
                    width: pane.targetSize * scatter.k; height: width; radius: width / 2
                    color: "transparent"; border.width: 1.5; border.color: Theme.withAlpha(Theme.accent, 0.6)
                }
                Rectangle { anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.border }
                Rectangle { anchors.centerIn: parent; width: 1; height: parent.height - 16; color: Theme.border }
                Repeater {
                    model: pane.hits
                    delegate: Rectangle {
                        required property var modelData
                        width: 9; height: 9; radius: 4.5
                        color: modelData.hit ? Theme.success : Theme.danger
                        x: scatter.width / 2 + Math.max(-scatter.width / 2 + 6, Math.min(scatter.width / 2 - 6, modelData.dx * scatter.k)) - 4.5
                        y: scatter.height / 2 + Math.max(-scatter.height / 2 + 6, Math.min(scatter.height / 2 - 6, modelData.dy * scatter.k)) - 4.5
                    }
                }
                Rectangle { // mean bias marker
                    visible: pane.stats.n > 2
                    width: 14; height: 14; radius: 7
                    color: "transparent"; border.width: 2.5; border.color: Theme.text
                    x: scatter.width / 2 + pane.stats.biasX * scatter.k - 7
                    y: scatter.height / 2 + pane.stats.biasY * scatter.k - 7
                }
            }

            InfoRow { label: "Hit rate"; value: pane.stats.n ? Math.round(pane.stats.hitRate * 100) + " %  (" + pane.stats.n + " taps)" : "–" }
            InfoRow { label: "Mean error"; value: pane.stats.n ? pane.stats.meanErr.toFixed(1) + " px · " + (pane.stats.meanErr / pane.pxPerMm).toFixed(1) + " mm" : "–" }
            InfoRow {
                label: "Bias (x, y)"
                value: pane.stats.n ? pane.stats.biasX.toFixed(1) + ", " + pane.stats.biasY.toFixed(1) + " px" : "–"
                valueColor: Math.hypot(pane.stats.biasX, pane.stats.biasY) > 10 ? Theme.warning : Theme.text
            }
            InfoRow { label: "Reaction"; value: pane.stats.n ? Math.round(pane.stats.ms) + " ms" : "–"; last: true }
            Item { Layout.fillHeight: true }
        }
    }
}
