import QtQuick
import QtQuick.Layouts
import Kiosk

// Surface container with optional icon/title header. Children stack vertically.
Rectangle {
    id: card
    property string title: ""
    property string subtitle: ""
    property string iconPath: ""
    property int padding: 20
    default property alias content: body.data

    color: Theme.surface
    radius: Theme.radiusL
    border.width: Theme.strokeCard
    border.color: Theme.cardOutline
    implicitWidth: 300
    implicitHeight: column.implicitHeight + 2 * padding

    ColumnLayout {
        id: column
        anchors { fill: parent; margins: card.padding }
        spacing: 16

        RowLayout {
            visible: card.title.length > 0
            spacing: 12
            Layout.fillWidth: true
            Rectangle {
                visible: card.iconPath.length > 0
                width: 36; height: 36; radius: Theme.sph ? 0 : 11
                color: Theme.accentSoft
                Icon { anchors.centerIn: parent; path: card.iconPath; color: Theme.sph ? Theme.text : Theme.accent; size: 20 }
            }
            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                Text {
                    text: card.title
                    font.family: Theme.fontDisplay; font.pixelSize: 17 * Theme.titleScale; font.weight: Theme.titleWeight
                    font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackLabel
                    color: Theme.text
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    visible: card.subtitle.length > 0
                    text: card.subtitle
                    font.family: Theme.font; font.pixelSize: Theme.fsSmall
                    color: Theme.textDim
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }

        ColumnLayout {
            id: body
            spacing: 12
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
