import QtQuick
import QtQuick.Controls
import Kiosk

// Large toggle (tap or flick the knob). Whole row is the hit target.
Switch {
    id: control
    property string subtitle: ""

    implicitHeight: Math.max(Theme.touchMin, label.implicitHeight)
    font.family: Theme.font
    font.pixelSize: Theme.fsBody
    focusPolicy: Qt.NoFocus
    padding: 0
    spacing: 16

    indicator: Rectangle {
        id: track
        x: control.width - width
        anchors.verticalCenter: parent.verticalCenter
        width: 58; height: 34; radius: height / 2
        color: control.checked ? Theme.accent : Theme.surface3
        Behavior on color { ColorAnimation { duration: Theme.normal } }

        Rectangle {
            id: knob
            readonly property real travel: track.width - width - 8
            width: control.pressed ? 32 : 26
            height: 26; radius: 13
            anchors.verticalCenter: parent.verticalCenter
            x: 4 + (control.visualPosition * (track.width - width - 8))
            color: "white"
            Behavior on x { enabled: !control.pressed; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on width { NumberAnimation { duration: Theme.fast } }
        }
    }

    contentItem: Column {
        id: label
        rightPadding: control.indicator.width + control.spacing
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        spacing: 2
        Text {
            text: control.text
            font: control.font
            color: Theme.text
        }
        Text {
            visible: control.subtitle.length > 0
            text: control.subtitle
            font.family: Theme.font; font.pixelSize: Theme.fsSmall
            color: Theme.textDim
        }
    }
}
