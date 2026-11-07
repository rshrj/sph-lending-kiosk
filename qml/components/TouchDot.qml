import QtQuick

// One trail particle: fades and shrinks, then deletes itself.
Rectangle {
    id: dot
    property color tint: "white"
    width: 16; height: 16; radius: 8
    color: tint
    opacity: 0.55

    ParallelAnimation {
        running: true
        NumberAnimation { target: dot; property: "opacity"; to: 0; duration: 650; easing.type: Easing.InQuad }
        NumberAnimation { target: dot; property: "scale"; to: 0.2; duration: 650 }
        onFinished: dot.destroy()
    }
}
