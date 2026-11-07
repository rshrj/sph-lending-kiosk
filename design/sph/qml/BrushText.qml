import QtQuick

// SPH "span.drawer": a hand-drawn marker stroke behind a word or short phrase.
// brush: "purple" | "yellow" | "green" | "cyan" | "orange" | "black" | "white"
Item {
    id: root
    property alias text: label.text
    property alias font: label.font
    property alias color: label.color
    property string brush: "yellow"

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Image {
        // CSS: width calc(100% + 20px), left -10px, bottom 0, behind the text.
        x: -10; width: root.width + 20
        height: Math.max(10, Math.round(label.font.pixelSize * 0.55))
        y: label.y + label.height - height + Math.round(label.font.pixelSize * 0.05)
        source: Theme.brush(root.brush)
        sourceSize: Qt.size(width, height)
        fillMode: Image.Stretch
        smooth: true
    }
    Text {
        id: label
        font.family: Theme.fontDisplay
        font.pixelSize: Theme.fsH2
        font.letterSpacing: Theme.trackDisplay
        font.capitalization: Font.AllUppercase
        color: Theme.text
    }
}
