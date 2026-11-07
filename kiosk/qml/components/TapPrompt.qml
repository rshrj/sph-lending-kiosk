import QtQuick
import Kiosk

// "Hold your card here" illustration: a card with radiating rings.
Item {
    id: root
    property bool active: true
    property color tint: Theme.accent
    implicitWidth: 220
    implicitHeight: 170

    Repeater {
        model: 3
        delegate: Rectangle {
            id: ring
            required property int index
            anchors.centerIn: card
            width: 120; height: width; radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: root.tint
            opacity: 0
            SequentialAnimation {
                running: root.active && root.visible
                loops: Animation.Infinite
                PauseAnimation { duration: ring.index * 600 }
                ParallelAnimation {
                    NumberAnimation { target: ring; property: "scale"; from: 0.7; to: 1.6; duration: 1800; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ring; property: "opacity"; from: 0.6; to: 0; duration: 1800 }
                }
                PauseAnimation { duration: (2 - ring.index) * 600 }
            }
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 128; height: 84; radius: 0
        border.width: Theme.strokeButton; border.color: Theme.stroke
        rotation: -8
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.tint }
            GradientStop { position: 1; color: root.tint }
        }
        Rectangle { // chip
            x: 16; y: 24; width: 26; height: 20; radius: 4
            color: "#F5D78A"
        }
        Icon {
            anchors { right: parent.right; top: parent.top; margins: 12 }
            path: Icons.contactless; color: Theme.accentText; size: 22
        }
        Rectangle { x: 16; y: 58; width: 64; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.55) }
        SequentialAnimation on y {
            running: root.active && root.visible
            loops: Animation.Infinite
            NumberAnimation { from: (root.height - 84) / 2; to: (root.height - 84) / 2 - 8; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { from: (root.height - 84) / 2 - 8; to: (root.height - 84) / 2; duration: 1200; easing.type: Easing.InOutSine }
        }
    }
}
