import QtQuick

// SPH ".o-info-boxes__item": square card, thick accent outline (green by default),
// Alternate Gothic uppercase title, Proxima body, underlined action link bottom-right.
// Press tints the background with the outline colour (site: background-color transition).
Rectangle {
    id: root
    property string title
    property string body
    property string action
    property color outline: Theme.green
    signal clicked

    implicitWidth: 300
    implicitHeight: 220
    color: tap.pressed ? Theme.withAlpha(outline, 0.25) : Theme.surface
    border.width: Theme.strokeCard
    border.color: outline
    Behavior on color { ColorAnimation { duration: Theme.fast; easing.type: Theme.easing } }

    TapHandler { id: tap; gesturePolicy: TapHandler.WithinBounds; onTapped: root.clicked() }

    Column {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 10
        Text {
            width: parent.width
            text: root.title
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fsH3
            font.letterSpacing: Theme.trackDisplay * 0.6
            font.capitalization: Font.AllUppercase
            lineHeight: Theme.lineHeightDisplay
            wrapMode: Text.WordWrap
            color: Theme.text
        }
        Text {
            width: parent.width
            text: root.body
            visible: text.length > 0
            font.family: Theme.font
            font.pixelSize: Theme.fsSmall + 1
            lineHeight: Theme.lineHeightBody
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
            color: Theme.text
        }
    }

    TextLink {
        visible: root.action.length > 0
        text: root.action
        anchors { right: parent.right; bottom: parent.bottom; margins: 18 }
        onClicked: root.clicked()
    }
}
