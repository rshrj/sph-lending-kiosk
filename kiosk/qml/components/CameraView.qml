pragma ComponentBehavior: Bound
import QtQuick
import Kiosk

// Live tray preview: polls /camera/frame.jpg into two Images and swaps them when the next
// frame has fully loaded (no flicker), then draws the last scan's detections on top.
Rectangle {
    id: view
    property bool running: false
    property int frameWidth: 640            // what we ask the server for
    property int intervalMs: 200            // pause between frames
    property var detections: []             // [{ bbox: [x, y, w, h] in camera px, tone, label }]
    property var sourceSize: [1920, 1080]   // camera frame size the bboxes refer to

    color: Theme.ink
    clip: true

    property int seq: 0
    property Image front: imgA
    readonly property Image back: front === imgA ? imgB : imgA

    function loadNext() {
        if (!running) return
        back.source = Backend.url("/camera/frame.jpg?width=" + frameWidth + "&n=" + (++seq))
    }
    onRunningChanged: if (running) loadNext()
    Component.onCompleted: if (running) loadNext()

    Timer { id: pause; interval: view.intervalMs; onTriggered: view.loadNext() }

    component Frame: Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        cache: false
        smooth: true
        visible: view.front === img && status === Image.Ready
        onStatusChanged: {
            if (view.front === img) return
            if (status === Image.Ready) { view.front = img; pause.restart() }
            else if (status === Image.Error) pause.restart()
        }
    }
    Frame { id: imgA }
    Frame { id: imgB }

    // Detections, mapped from camera pixels into the painted (letterboxed) frame.
    Item {
        id: overlay
        readonly property real sx: view.front.paintedWidth / view.sourceSize[0]
        readonly property real sy: view.front.paintedHeight / view.sourceSize[1]
        x: (view.width - view.front.paintedWidth) / 2
        y: (view.height - view.front.paintedHeight) / 2
        width: view.front.paintedWidth
        height: view.front.paintedHeight
        visible: view.front.status === Image.Ready

        Repeater {
            model: view.detections
            delegate: Rectangle {
                id: box
                required property var modelData
                readonly property color tc: modelData.tone === "ok" ? Theme.green : modelData.tone === "warn" ? Theme.yellow
                                          : modelData.tone === "bad" ? Theme.red : Theme.paper
                x: modelData.bbox[0] * overlay.sx - 6
                y: modelData.bbox[1] * overlay.sy - 6
                width: modelData.bbox[2] * overlay.sx + 12
                height: modelData.bbox[3] * overlay.sy + 12
                color: "transparent"
                border.width: 4
                border.color: tc
                Rectangle {
                    anchors { left: parent.left; bottom: parent.top }
                    width: Math.min(label.implicitWidth + 12, 220); height: 22
                    color: box.tc
                    Text {
                        id: label
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        verticalAlignment: Text.AlignVCenter
                        text: box.modelData.label
                        elide: Text.ElideRight
                        font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Bold
                        color: Theme.ink
                    }
                }
            }
        }
    }

    // Before the first frame arrives
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: view.front.status !== Image.Ready
        Icon { anchors.horizontalCenter: parent.horizontalCenter; path: Icons.camera; size: 40; color: Theme.paper }
        Text {
            text: "Starting camera…"
            font.family: Theme.font; font.pixelSize: 16
            color: Theme.paper
        }
    }
}
