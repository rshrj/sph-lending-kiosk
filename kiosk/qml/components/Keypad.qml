pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Kiosk

// Numeric keypad sized for thumbs (3×4, ~11 mm keys).
Grid {
    id: pad
    signal digit(string d)
    signal backspace()
    signal accept()
    property bool acceptEnabled: true
    property int keyWidth: 96
    property int keyHeight: 66

    columns: 3
    spacing: 10

    Repeater {
        model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "back", "0", "ok"]
        delegate: AbstractButton {
            id: key
            required property string modelData
            readonly property bool isOk: modelData === "ok"
            readonly property bool isBack: modelData === "back"
            width: pad.keyWidth
            height: pad.keyHeight
            focusPolicy: Qt.NoFocus
            enabled: !isOk || pad.acceptEnabled
            autoRepeat: isBack
            opacity: enabled ? 1 : 0.35

            onClicked: {
                if (isOk) pad.accept()
                else if (isBack) pad.backspace()
                else pad.digit(modelData)
            }

            background: Rectangle {
                radius: Theme.radiusM
                color: key.isOk ? Theme.accent : Theme.surface2
                border.width: 1
                border.color: Theme.border
                scale: key.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    color: key.isOk ? "black" : Theme.accent
                    opacity: key.pressed ? (key.isOk ? 0.15 : 0.22) : 0
                    Behavior on opacity { NumberAnimation { duration: key.pressed ? 40 : 260 } }
                }
            }
            contentItem: Item {
                Text {
                    anchors.centerIn: parent
                    visible: !key.isOk && !key.isBack
                    text: key.modelData
                    font.family: Theme.font; font.pixelSize: 28; font.weight: Font.Medium
                    color: Theme.text
                }
                Icon {
                    anchors.centerIn: parent
                    visible: key.isOk || key.isBack
                    path: key.isOk ? Icons.check : Icons.backspace
                    color: key.isOk ? Theme.accentText : Theme.text
                    size: 26
                }
            }
        }
    }
}
