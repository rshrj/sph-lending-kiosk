pragma ComponentBehavior: Bound
import QtQuick
import Kiosk

// iOS-style segmented control with a sliding thumb.
Rectangle {
    id: root
    property var model: []
    property int currentIndex: 0
    property int segmentWidth: 0          // 0 = auto (equal split of width)
    signal activated(int index)

    readonly property real segW: segmentWidth > 0 ? segmentWidth : (width - 8) / Math.max(1, model.length)

    implicitHeight: 48
    implicitWidth: segmentWidth > 0 ? segmentWidth * model.length + 8 : 320
    radius: Theme.sph ? 0 : 14
    color: Theme.surface2

    Rectangle {
        id: thumb
        x: 4 + root.currentIndex * root.segW
        y: 4
        width: root.segW
        height: root.height - 8
        radius: Theme.sph ? 0 : 11
        color: Theme.sph ? Theme.accent : (Theme.dark ? Theme.surface3 : "white")
        border.width: Theme.sph ? 2 : (Theme.dark ? 0 : 1)
        border.color: Theme.sph ? Theme.stroke : Theme.border
        Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }

    Row {
        x: 4; y: 4
        Repeater {
            model: root.model
            delegate: Item {
                id: seg
                required property int index
                required property string modelData
                width: root.segW
                height: root.height - 8
                Text {
                    anchors.centerIn: parent
                    text: seg.modelData
                    font.family: Theme.fontDisplay
                    font.pixelSize: 15 * Theme.titleScale
                    font.capitalization: Theme.headingCaps
                    font.letterSpacing: Theme.trackLabel
                    font.weight: Theme.sph ? Font.Normal : (root.currentIndex === seg.index ? Font.DemiBold : Font.Medium)
                    color: root.currentIndex === seg.index ? (Theme.sph ? Theme.accentText : Theme.text) : Theme.textDim
                    scale: tap.pressed ? 0.92 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.fast } }
                }
                TapHandler {
                    id: tap
                    onTapped: {
                        root.currentIndex = seg.index
                        root.activated(seg.index)
                    }
                }
            }
        }
    }
}
