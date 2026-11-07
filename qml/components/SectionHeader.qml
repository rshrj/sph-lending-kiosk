import QtQuick
import QtQuick.Layouts
import Kiosk

// Page title. SPH style: condensed uppercase with the hand-drawn marker stroke
// behind it (one per screen, as on sph.ethz.ch).
ColumnLayout {
    id: root
    property string title
    property string subtitle
    spacing: 2

    Item {
        implicitWidth: titleText.implicitWidth
        implicitHeight: titleText.implicitHeight
        Image {
            visible: Theme.sph
            x: -8; width: parent.width + 16
            height: Math.round(titleText.font.pixelSize * 0.5)
            y: titleText.height - height + 2
            source: Theme.sph ? Theme.brush(Theme.dark ? "purple" : "yellow") : ""
            sourceSize: Qt.size(width, height)
            fillMode: Image.Stretch
        }
        Text {
            id: titleText
            text: root.title
            font.family: Theme.fontDisplay; font.pixelSize: Theme.fsH1; font.weight: Theme.headingWeight
            font.letterSpacing: Theme.trackHeading
            font.capitalization: Theme.headingCaps
            color: Theme.text
        }
    }
    Text {
        visible: root.subtitle.length > 0
        text: root.subtitle
        font.family: Theme.font; font.pixelSize: 15
        color: Theme.textDim
        Layout.fillWidth: true
        elide: Text.ElideRight
    }
}
