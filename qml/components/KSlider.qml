import QtQuick
import QtQuick.Controls
import Kiosk

// Thick, finger-sized slider with a value bubble while dragging.
Slider {
    id: control
    property string suffix: ""
    property int decimals: 0

    implicitHeight: 64
    focusPolicy: Qt.NoFocus
    leftPadding: 16
    rightPadding: 16

    background: Item {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 10

        Rectangle { anchors.fill: parent; radius: 5; color: Theme.surface3 }
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height; radius: 5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.darker(Theme.accent, 1.15) }
                GradientStop { position: 1; color: Theme.accentHi }
            }
        }
    }

    handle: Rectangle {
        id: knob
        x: control.leftPadding + control.visualPosition * (control.availableWidth) - width / 2
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 32; height: 32; radius: 16
        color: "white"
        border.width: 3
        border.color: Theme.accent
        scale: control.pressed ? 1.2 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutBack } }

        Rectangle { // value bubble
            anchors { bottom: parent.top; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
            width: bubbleText.implicitWidth + 20; height: 30; radius: 10
            color: Theme.text
            opacity: control.pressed ? 1 : 0
            scale: control.pressed ? 1 / knob.scale : 0.6 / knob.scale
            transformOrigin: Item.Bottom
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            Behavior on scale { NumberAnimation { duration: Theme.fast } }
            Text {
                id: bubbleText
                anchors.centerIn: parent
                text: control.value.toFixed(control.decimals) + control.suffix
                font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Theme.bg
            }
        }
    }
}
