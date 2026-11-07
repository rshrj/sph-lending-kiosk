import QtQuick
import Kiosk

// "Slide to confirm" – a deliberate gesture that can't be triggered by a stray tap.
Rectangle {
    id: root
    property string text: "Slide to confirm"
    property string doneText: "Confirmed"
    readonly property bool confirmed: state === "done"
    signal accepted()

    function reset() { state = ""; knob.x = knob.minX }

    implicitWidth: 360
    implicitHeight: 68
    radius: height / 2
    color: Theme.surface2
    border.width: 1
    border.color: Theme.border
    clip: true

    Rectangle { // progress fill
        height: parent.height
        width: knob.x + knob.width + 6
        radius: height / 2
        color: root.confirmed ? Theme.success : Theme.accentSoft
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.confirmed ? 0 : knob.width / 2
        text: root.confirmed ? root.doneText : root.text
        font.family: Theme.font; font.pixelSize: 17; font.weight: Font.DemiBold
        color: root.confirmed ? Theme.accentText : Theme.textDim
        opacity: root.confirmed ? 1 : 1 - (knob.x - knob.minX) / (knob.maxX - knob.minX) * 1.4
        // gentle shimmer to hint at the gesture
        SequentialAnimation on anchors.horizontalCenterOffset {
            running: !root.confirmed && !drag.active
            loops: Animation.Infinite
            NumberAnimation { from: knob.width / 2; to: knob.width / 2 + 8; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { from: knob.width / 2 + 8; to: knob.width / 2; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        id: knob
        readonly property real minX: 6
        readonly property real maxX: root.width - width - 6
        x: minX
        y: 6
        width: root.height - 12
        height: width
        radius: width / 2
        color: root.confirmed ? Theme.paper : Theme.accent
        scale: drag.active ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }

        Icon {
            anchors.centerIn: parent
            path: root.confirmed ? Icons.check : Icons.arrowRight
            color: root.confirmed ? Theme.success : Theme.accentText
            size: 26
            strokeWidth: 2.5
        }

        DragHandler {
            id: drag
            enabled: !root.confirmed
            yAxis.enabled: false
            xAxis.minimum: knob.minX
            xAxis.maximum: knob.maxX
            onActiveChanged: {
                if (active) return
                if (knob.x > knob.maxX - 12) {
                    snapEnd.start()
                    root.state = "done"
                    root.accepted()
                } else {
                    snapBack.start()
                }
            }
        }
        NumberAnimation on x { id: snapBack; running: false; to: knob.minX; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        NumberAnimation on x { id: snapEnd; running: false; to: knob.maxX; duration: 120 }
    }

    states: State { name: "done" }
}
