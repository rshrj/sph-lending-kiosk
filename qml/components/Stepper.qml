import QtQuick
import QtQuick.Controls
import Kiosk

// − value + with auto-repeat while held (press-and-hold accelerates).
Rectangle {
    id: root
    property int value: 1
    property int from: 0
    property int to: 99
    property string unit: ""

    implicitWidth: 240
    implicitHeight: 64
    radius: Theme.radiusM
    color: Theme.surface2

    component StepButton: AbstractButton {
        id: b
        property string glyph
        width: 64; height: root.height
        autoRepeat: true
        autoRepeatDelay: 380
        autoRepeatInterval: 70
        focusPolicy: Qt.NoFocus
        background: Rectangle {
            radius: Theme.radiusM
            color: b.pressed ? Theme.accentSoft : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }
        contentItem: Icon {
            path: b.glyph; size: 26; color: b.enabled ? (Theme.sph ? Theme.text : Theme.accent) : Theme.textFaint
            scale: b.pressed ? 0.85 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast } }
        }
        leftPadding: 19; topPadding: (height - 26) / 2
    }

    StepButton {
        anchors.left: parent.left
        glyph: "M5 12 H19"
        enabled: root.value > root.from
        onClicked: root.value = Math.max(root.from, root.value - 1)
    }
    Column {
        anchors.centerIn: parent
        Text {
            id: valueText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.value
            font.family: Theme.font; font.pixelSize: 26; font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Theme.text
            // Little "tick" each time the value changes
            onTextChanged: bump.restart()
            SequentialAnimation on scale {
                id: bump
                running: false
                NumberAnimation { to: 1.15; duration: 50 }
                NumberAnimation { to: 1.0; duration: 120; easing.type: Easing.OutBack }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.unit.length > 0
            text: root.unit
            font.family: Theme.font; font.pixelSize: 12
            color: Theme.textDim
        }
    }
    StepButton {
        anchors.right: parent.right
        glyph: "M5 12 H19 M12 5 V19"
        enabled: root.value < root.to
        onClicked: root.value = Math.min(root.to, root.value + 1)
    }
}
