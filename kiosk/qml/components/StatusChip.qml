import QtQuick
import Kiosk

// Small square status pill: icon + caps label on a flat colour (ink text, SPH rule).
Rectangle {
    id: chip
    property string text
    property string iconPath: Icons.alert
    property color tint: Theme.yellow

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 36
    color: tint
    border.width: 2
    border.color: Theme.ink

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon { anchors.verticalCenter: parent.verticalCenter; path: chip.iconPath; size: 18; color: Theme.ink }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            font.family: Theme.fontDisplay; font.pixelSize: 15 * Theme.titleScale
            font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackLabel
            color: Theme.ink
        }
    }
}
