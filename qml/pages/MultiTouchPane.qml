pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Kiosk

// Raw multi-touch visualiser. Mouse also works (as a single point) on the Mac.
Rectangle {
    id: pane
    color: Theme.surface
    radius: Theme.radiusL
    border.width: 1
    border.color: Theme.border
    clip: true

    readonly property var colors: ["#6C7BFF", "#2DD4BF", "#F59E0B", "#F43F5E", "#A78BFA",
                                    "#38BDF8", "#22C55E", "#FB923C", "#E879F9", "#FACC15"]
    property int activeCount: 0
    property int maxSeen: 0
    property int totalTouches: 0
    property var lastSpawn: ({})

    // Dotted grid background (painted once, cached as a texture).
    Canvas {
        id: grid
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = Theme.dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.10)"
            for (let x = 20; x < width; x += 32)
                for (let y = 20; y < height; y += 32)
                    ctx.fillRect(x - 1, y - 1, 2, 2)
        }
        Connections { target: Theme; function onDarkChanged() { grid.requestPaint() } }
    }

    Column {
        anchors.centerIn: parent
        spacing: 12
        opacity: pane.activeCount === 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        Icon { anchors.horizontalCenter: parent.horizontalCenter; path: Icons.hand; size: 54; color: Theme.textFaint; strokeWidth: 1.5 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Put several fingers on the screen"
            font.family: Theme.font; font.pixelSize: 20; font.weight: Font.Medium
            color: Theme.textDim
        }
    }

    Item { id: trailLayer; anchors.fill: parent }

    Component { id: dotComponent; TouchDot {} }

    // Line + distance between the first two fingers (what a pinch "sees").
    Shape {
        anchors.fill: parent
        visible: tp0.pressed && tp1.pressed
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.withAlpha(Theme.text, 0.35); strokeWidth: 2; fillColor: "transparent"
            strokeStyle: ShapePath.DashLine; dashPattern: [4, 4]
            startX: tp0.x; startY: tp0.y
            PathLine { x: tp1.x; y: tp1.y }
        }
    }
    Rectangle {
        visible: tp0.pressed && tp1.pressed
        x: (tp0.x + tp1.x) / 2 - width / 2
        y: (tp0.y + tp1.y) / 2 - height / 2
        width: distText.implicitWidth + 16; height: 26; radius: 13
        color: Theme.text
        Text {
            id: distText
            anchors.centerIn: parent
            text: Math.round(Math.hypot(tp1.x - tp0.x, tp1.y - tp0.y)) + " px"
            font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
            color: Theme.bg
        }
    }

    MultiPointTouchArea {
        id: mpta
        anchors.fill: parent
        mouseEnabled: true
        maximumTouchPoints: 10
        touchPoints: [
            TouchPoint { id: tp0 }, TouchPoint { id: tp1 }, TouchPoint {}, TouchPoint {}, TouchPoint {},
            TouchPoint {}, TouchPoint {}, TouchPoint {}, TouchPoint {}, TouchPoint {}
        ]

        function countActive() {
            let n = 0
            for (let i = 0; i < touchPoints.length; ++i) if (touchPoints[i].pressed) ++n
            pane.activeCount = n
            pane.maxSeen = Math.max(pane.maxSeen, n)
        }
        onPressed: (points) => { pane.totalTouches += points.length; countActive() }
        onReleased: countActive()
        onCanceled: countActive()
        onUpdated: (points) => {
            for (const p of points) {
                const idx = mpta.touchPoints.indexOf(p)
                const last = pane.lastSpawn[p.pointId]
                if (last && Math.hypot(p.x - last.x, p.y - last.y) < 9) continue
                pane.lastSpawn[p.pointId] = { x: p.x, y: p.y }
                const d = dotComponent.createObject(trailLayer, { tint: pane.colors[Math.max(0, idx) % 10] })
                d.x = p.x - d.width / 2
                d.y = p.y - d.height / 2
            }
        }
    }

    // Finger markers
    Repeater {
        model: mpta.touchPoints
        delegate: Item {
            id: marker
            required property int index
            required property var modelData
            readonly property color tint: pane.colors[index]
            x: modelData.x
            y: modelData.y
            visible: modelData.pressed
            onVisibleChanged: if (visible) { ring.scale = 0.4; ring.opacity = 0.9; pulse.restart() }

            Rectangle { // expanding ring on touch-down
                id: ring
                anchors.centerIn: parent
                width: 150; height: 150; radius: 75
                color: "transparent"
                border.width: 3
                border.color: marker.tint
                ParallelAnimation {
                    id: pulse
                    NumberAnimation { target: ring; property: "scale"; to: 1.1; duration: 500; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 500 }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 86; height: 86; radius: 43
                color: Theme.withAlpha(marker.tint, 0.25)
                border.width: 3
                border.color: marker.tint
                Text {
                    anchors.centerIn: parent
                    text: marker.index + 1
                    font.family: Theme.font; font.pixelSize: 24; font.weight: Font.Bold
                    color: Theme.text
                }
            }
            Rectangle { // coordinate label
                anchors { left: parent.left; leftMargin: 50; bottom: parent.top; bottomMargin: 30 }
                width: coordText.implicitWidth + 14; height: 24; radius: 8
                color: marker.tint
                Text {
                    id: coordText
                    anchors.centerIn: parent
                    text: Math.round(marker.modelData.x) + ", " + Math.round(marker.modelData.y)
                    font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: "white"
                }
            }
        }
    }

    // Stats strip
    Row {
        anchors { left: parent.left; bottom: parent.bottom; margins: 14 }
        spacing: 8
        Repeater {
            model: [["Active", pane.activeCount], ["Max seen", pane.maxSeen], ["Touches", pane.totalTouches]]
            delegate: Rectangle {
                required property var modelData
                width: statText.implicitWidth + 22; height: 32; radius: Theme.sph ? 0 : 10
                color: Theme.surface2
                Text {
                    id: statText
                    anchors.centerIn: parent
                    textFormat: Text.StyledText
                    text: modelData[0] + "  <b>" + modelData[1] + "</b>"
                    font.family: Theme.font; font.pixelSize: 13
                    color: Theme.text
                }
            }
        }
    }
    KButton {
        anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
        compact: true
        kind: "secondary"
        text: "Reset"
        iconPath: Icons.refresh
        onClicked: { pane.maxSeen = 0; pane.totalTouches = 0 }
    }
}
