import QtQuick

// SPH collapsible / news row: 2px ink rules, Alternate Gothic uppercase title,
// optional Proxima meta line, thin chevron on the right.
Item {
    id: root
    property string title
    property string meta
    property bool topRule: true
    property color ink: Theme.text
    signal clicked

    implicitWidth: 400
    implicitHeight: Math.max(Theme.touchMin + 8, col.implicitHeight + 24)

    Rectangle { anchors.fill: parent; color: Theme.withAlpha(root.ink, tap.pressed ? 0.08 : 0)
        Behavior on color { ColorAnimation { duration: Theme.fast } } }
    Rectangle { visible: root.topRule; width: parent.width; height: Theme.strokeRule; color: Theme.withAlpha(root.ink, 0.8) }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.strokeRule; color: Theme.withAlpha(root.ink, 0.8) }

    Column {
        id: col
        anchors { left: parent.left; right: chev.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 2
        Text {
            visible: root.meta.length > 0
            text: root.meta
            font.family: Theme.font; font.bold: true; font.pixelSize: Theme.fsSmall
            color: root.ink
        }
        Text {
            width: parent.width
            text: root.title
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fsH3
            font.letterSpacing: Theme.trackDisplay * 0.6
            font.capitalization: Font.AllUppercase
            elide: Text.ElideRight
            color: root.ink
        }
    }
    Chevron { id: chev; color: root.ink; anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } }

    TapHandler { id: tap; gesturePolicy: TapHandler.WithinBounds; onTapped: root.clicked() }
}
