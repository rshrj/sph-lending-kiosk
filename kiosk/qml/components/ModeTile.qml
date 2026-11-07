import QtQuick
import QtQuick.Controls
import Kiosk

// Big start-screen choice: a flat accent block with a 3 px ink frame (SPH colour band as a
// button). Press = quick ink tint + slight scale.
AbstractButton {
    id: tile
    property string iconPath
    property string subtitle
    property color tint: Theme.purple

    focusPolicy: Qt.NoFocus
    scale: pressed ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }

    background: Rectangle {
        color: tile.tint
        border.width: Theme.strokeButton
        border.color: Theme.ink
        Rectangle {
            anchors.fill: parent
            color: Theme.ink
            opacity: tile.pressed ? 0.12 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        }
    }

    contentItem: Item {
        Rectangle {
            anchors { left: parent.left; top: parent.top; margins: 26 }
            width: 72; height: 72
            color: "transparent"
            border.width: 3; border.color: Theme.ink
            Icon { anchors.centerIn: parent; path: tile.iconPath; size: 38; color: Theme.ink; strokeWidth: 2.2 }
        }
        Icon {
            anchors { right: parent.right; top: parent.top; margins: 30 }
            path: Icons.arrowRight
            size: 32
            strokeWidth: 2.5
            color: Theme.ink
        }
        Column {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 26 }
            spacing: 6
            Text {
                width: parent.width
                text: tile.text
                font.family: Theme.fontDisplay; font.pixelSize: 64
                font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackHeading
                color: Theme.ink
            }
            Text {
                width: parent.width
                text: tile.subtitle
                font.family: Theme.font; font.pixelSize: 18
                lineHeight: 1.15
                color: Theme.ink
                wrapMode: Text.WordWrap
            }
        }
    }
}
