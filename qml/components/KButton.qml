import QtQuick
import QtQuick.Controls
import Kiosk

// Touch-first button: press = scale-down + tint, never a hover-only cue.
// SPH style: parallelogram (skew −20°) with a 3 px ink outline; press fills it ink
// and inverts the label (the site's .btn).
AbstractButton {
    id: control
    property string iconPath: ""
    property string kind: "primary"   // primary | secondary | ghost | danger
    property bool compact: false

    readonly property bool solid: kind === "primary" || kind === "danger"
    readonly property color fg: Theme.sph ? (control.pressed ? Theme.bg : solid ? Theme.accentText : Theme.text)
                              : solid ? Theme.accentText
                              : kind === "ghost" ? Theme.accent : Theme.text
    readonly property color bgColor: kind === "primary" ? Theme.accent
                                   : kind === "danger" ? Theme.danger
                                   : kind === "secondary" && !Theme.sph ? Theme.surface2 : "transparent"
    readonly property real slant: Math.abs(Theme.skewShear) * height / 2

    implicitHeight: compact ? 44 : Theme.touchMin
    implicitWidth: Math.max(implicitHeight, contentRow.implicitWidth + (compact ? 28 : 44) + 2 * slant)
    font.family: Theme.fontDisplay
    font.pixelSize: (compact ? 14 : Theme.fsBody) * Theme.titleScale
    font.weight: Theme.titleWeight
    font.capitalization: Theme.headingCaps
    font.letterSpacing: Theme.trackLabel
    opacity: enabled ? 1 : 0.4
    focusPolicy: Qt.NoFocus

    scale: pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad } }

    background: Item {
        Rectangle {
            id: shape
            x: control.slant
            width: parent.width - 2 * control.slant
            height: parent.height
            radius: control.compact ? Theme.radiusS : Theme.radiusM
            color: Theme.sph && control.pressed ? Theme.stroke : control.bgColor
            border.width: Theme.sph ? Theme.strokeButton : control.kind === "ghost" ? 1.5 : 0
            border.color: Theme.sph ? Theme.stroke : Theme.withAlpha(Theme.accent, 0.5)
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, Theme.skewShear, 0, -Theme.skewShear * shape.height / 2,
                                     0, 1, 0, 0,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1)
            }
            Rectangle { // lab-style press tint
                visible: !Theme.sph
                anchors.fill: parent
                radius: parent.radius
                color: control.solid ? "black" : Theme.text
                opacity: control.pressed ? 0.14 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
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
