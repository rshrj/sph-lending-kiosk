import QtQuick
import Kiosk

// Counts frames actually presented by the scene graph. Qt Quick only renders
// when something changes, so an idle UI legitimately reads 0.
Rectangle {
    id: meter
    property int frames: 0
    property int fps: 0
    property Window window: null

    width: label.implicitWidth + 24
    height: 30
    radius: 15
    color: Qt.rgba(0, 0, 0, 0.65)

    Text {
        id: label
        anchors.centerIn: parent
        text: meter.fps > 0 ? meter.fps + " fps" : "idle"
        font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: meter.fps >= 55 || meter.fps === 0 ? "#86EFAC" : meter.fps >= 30 ? "#FCD34D" : "#FCA5A5"
    }

    Connections {
        target: meter.window
        enabled: meter.visible
        function onFrameSwapped() { meter.frames++ }
    }
    Timer {
        interval: 1000; running: meter.visible; repeat: true
        onTriggered: { meter.fps = meter.frames; meter.frames = 0 }
    }
}
