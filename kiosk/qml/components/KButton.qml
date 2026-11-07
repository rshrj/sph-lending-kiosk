import QtQuick
import QtQuick.Controls
import Kiosk

// SPH button (the site's .btn): a parallelogram (skew −20°) with a 3 px ink outline and an
// upright label. primary = accent fill; secondary = outline only; danger = red fill.
// Press fills the shape ink and inverts the label. Never a hover-only cue.
AbstractButton {
    id: control
    property string iconPath: ""
    property string kind: "primary"   // primary | secondary | danger
    property bool compact: false
    property color fill: kind === "primary" ? Theme.accent : kind === "danger" ? Theme.danger : "transparent"

    readonly property color fg: control.pressed ? Theme.paper : Theme.ink
    readonly property real slant: Math.abs(Theme.skewShear) * height / 2

    implicitHeight: compact ? 46 : Theme.touchMin
    implicitWidth: Math.max(implicitHeight, contentRow.implicitWidth + (compact ? 28 : 44) + 2 * slant)
    font.family: Theme.fontDisplay
    font.pixelSize: (compact ? 15 : Theme.fsBody) * Theme.titleScale
    font.weight: Theme.titleWeight
    font.capitalization: Theme.headingCaps
    font.letterSpacing: Theme.trackLabel
    opacity: enabled ? 1 : 0.35
    focusPolicy: Qt.NoFocus

    scale: pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }

    background: Item {
        Rectangle {
            id: shape
            x: control.slant
            width: parent.width - 2 * control.slant
            height: parent.height
            color: control.pressed ? Theme.ink : control.fill
            border.width: Theme.strokeButton
            border.color: Theme.ink
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, Theme.skewShear, 0, -Theme.skewShear * shape.height / 2,
                                     0, 1, 0, 0,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1)
            }
        }
    }

    contentItem: Item {
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 10
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: control.iconPath.length > 0
                path: control.iconPath
                color: control.fg
                size: control.compact ? 18 : 20
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: control.text.length > 0
                text: control.text
                font: control.font
                color: control.fg
            }
        }
    }
}
