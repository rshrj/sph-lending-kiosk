import QtQuick
import QtQuick.Layouts
import Kiosk

// "Label ........ value" row with a hairline divider.
Item {
    id: root
    property string label
    property string value
    property bool last: false
    property color valueColor: Theme.text

    implicitHeight: Math.max(44, valueText.implicitHeight + 20)
    Layout.fillWidth: true

    Text {
        id: labelText
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: 130
        text: root.label
        font.family: Theme.font; font.pixelSize: 14
        color: Theme.textDim
    }
    Text {
        id: valueText
        anchors { left: labelText.right; right: parent.right; verticalCenter: parent.verticalCenter }
        text: root.value
        horizontalAlignment: Text.AlignRight
        wrapMode: Text.Wrap
        font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium
        color: root.valueColor
    }
    Rectangle {
        visible: !root.last
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.border
    }
}
