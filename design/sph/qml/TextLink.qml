import QtQuick

// SPH ".link": Alternate Gothic, uppercase, underlined, .8px tracking.
// The site scales it 1.15× on hover; here that is the press feedback.
// Touch target is padded out to Theme.touchMin.
Item {
    id: root
    property string text
    property color color: Theme.text
    property int pixelSize: Theme.fsLabel
    signal clicked

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text.toUpperCase()
        font.family: Theme.fontDisplay
        font.pixelSize: root.pixelSize
        font.letterSpacing: Theme.trackLabel
        font.underline: true
        color: root.color
        scale: tap.pressed ? Theme.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
    }

    // Generous hit area without changing layout size.
    Item {
        anchors.centerIn: parent
        width: Math.max(root.width + 24, Theme.touchMin)
        height: Math.max(root.height + 24, Theme.touchMin)
        TapHandler { id: tap; gesturePolicy: TapHandler.WithinBounds; onTapped: root.clicked() }
    }
}
