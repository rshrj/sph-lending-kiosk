import QtQuick

// SPH ".btn": parallelogram skewed -20°, 3px ink outline, transparent fill,
// Alternate Gothic uppercase label kept upright. Press = solid ink fill with
// inverted label (the site's :hover). `filled` gives an accent-filled CTA.
Item {
    id: root
    property string text
    property bool filled: false
    property color fill: Theme.accent
    property color ink: Theme.stroke      // outline + pressed fill
    property color inverse: Theme.bg      // label colour while pressed
    signal clicked

    readonly property real slant: Math.abs(Theme.skewShear) * height / 2
    implicitHeight: Theme.touchMin
    implicitWidth: label.implicitWidth + 2 * 32 + 2 * slant
    opacity: enabled ? 1 : 0.65

    Rectangle {
        id: shape
        x: root.slant; width: root.width - 2 * root.slant; height: root.height
        color: tap.pressed ? root.ink : (root.filled ? root.fill : "transparent")
        border.width: Theme.strokeButton
        border.color: root.ink
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, Theme.skewShear, 0, -Theme.skewShear * shape.height / 2,
                                 0, 1, 0, 0,
                                 0, 0, 1, 0,
                                 0, 0, 0, 1)
        }
        Behavior on color { ColorAnimation { duration: Theme.fast; easing.type: Theme.easing } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text.toUpperCase()
        font.family: Theme.fontDisplay
        font.pixelSize: Theme.fsButton
        font.letterSpacing: Theme.trackLabel
        color: tap.pressed ? root.inverse : (root.filled ? Theme.ink : root.ink)
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    TapHandler { id: tap; gesturePolicy: TapHandler.WithinBounds; onTapped: root.clicked() }
}
