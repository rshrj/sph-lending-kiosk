import QtQuick
import QtQuick.Layouts

// SPH full-bleed colour band (announcement / intro / CTA strip). Text is always ink.
// Put an action on the right with `action` (skew button) or `chevron: true`.
Rectangle {
    id: root
    property string title
    property string body
    property string action
    property bool chevron: false
    property int titleSize: Theme.fsH2
    property int padding: Theme.pad
    signal clicked

    color: Theme.yellow
    implicitHeight: Math.max(Theme.touchMin, lay.implicitHeight) + 2 * (body.length > 0 ? padding : padding * 0.6)

    RowLayout {
        id: lay
        anchors { fill: parent; leftMargin: root.padding; rightMargin: root.padding }
        spacing: Theme.gap
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: root.title
                font.family: Theme.fontDisplay
                font.pixelSize: root.titleSize
                font.letterSpacing: Theme.trackDisplay
                font.capitalization: Font.AllUppercase
                lineHeight: Theme.lineHeightDisplay
                wrapMode: Text.WordWrap
                color: Theme.ink
            }
            Text {
                Layout.fillWidth: true
                visible: root.body.length > 0
                text: root.body
                font.family: Theme.font
                font.pixelSize: Theme.fsBody
                lineHeight: Theme.lineHeightBody
                wrapMode: Text.WordWrap
                color: Theme.ink
            }
        }
        SkewButton {
            visible: root.action.length > 0
            Layout.alignment: Qt.AlignVCenter
            text: root.action
            ink: Theme.ink; inverse: Theme.paper
            onClicked: root.clicked()
        }
        Chevron { visible: root.chevron; color: Theme.ink; Layout.alignment: Qt.AlignVCenter }
    }
    TapHandler { enabled: root.chevron; onTapped: root.clicked() }
}
