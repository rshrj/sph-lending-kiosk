import QtQuick
import QtQuick.Layouts
import Kiosk

// SPH info box: square, 3 px green outline, optional caps title. Children stack vertically.
Rectangle {
    id: card
    property string title: ""
    property int padding: 20
    default property alias content: body.data

    color: Theme.surface
    border.width: Theme.strokeCard
    border.color: Theme.cardOutline
    implicitWidth: 300
    implicitHeight: column.implicitHeight + 2 * padding

    ColumnLayout {
        id: column
        anchors { fill: parent; margins: card.padding }
        spacing: 12
        Text {
            visible: card.title.length > 0
            Layout.fillWidth: true
            text: card.title
            font.family: Theme.fontDisplay; font.pixelSize: 20 * Theme.titleScale
            font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackLabel
            color: Theme.text
            elide: Text.ElideRight
        }
        ColumnLayout {
            id: body
            spacing: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
