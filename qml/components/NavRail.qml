pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Kiosk

// Vertical navigation rail with a sliding selection pill.
Rectangle {
    id: rail
    property int currentIndex: 0
    property var items: []          // [{ label, icon }]
    signal selected(int index)

    implicitWidth: Theme.railWidth
    color: Theme.sph ? Theme.purple : Theme.surface   // SPH: the purple header band, turned vertical
    // On the SPH purple rail all text is ink, in light and dark mode alike.
    readonly property color fg: Theme.sph ? Theme.ink : Theme.text
    readonly property color fgDim: Theme.sph ? Theme.withAlpha(Theme.ink, 0.7) : Theme.textDim

    Rectangle { // hairline separator
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: Theme.sph ? 0 : 1
        color: Theme.border
    }

    // Brand mark
    Image {
        visible: Theme.sph
        anchors.centerIn: logo
        source: Theme.sph ? "../../assets/sph/sph-logo.svg" : ""
        sourceSize.width: 74
    }
    Rectangle {
        id: logo
        anchors { top: parent.top; topMargin: 18; horizontalCenter: parent.horizontalCenter }
        opacity: Theme.sph ? 0 : 1
        width: 44; height: 44; radius: 14
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accent }
            GradientStop { position: 1; color: Qt.lighter(Theme.accent, 1.45) }
        }
        Icon { anchors.centerIn: parent; path: Icons.sparkle; color: "white"; size: 22; filled: true; strokeWidth: 1 }
    }

    Item {
        id: list
        anchors { top: logo.bottom; topMargin: 14; left: parent.left; right: parent.right }
        height: rail.items.length * itemHeight
        readonly property int itemHeight: 68

        Rectangle { // selection pill
            x: 14; width: parent.width - 28; height: 60; radius: Theme.radiusM
            y: rail.currentIndex * list.itemHeight + (list.itemHeight - height) / 2
            color: Theme.sph ? Theme.paper : Theme.accentSoft
            border.width: Theme.sph ? 2 : 0
            border.color: Theme.ink
            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        }

        Repeater {
            model: rail.items
            delegate: Item {
                id: entry
                required property int index
                required property var modelData
                readonly property bool active: rail.currentIndex === index
                y: index * list.itemHeight
                width: list.width
                height: list.itemHeight
                scale: tap.pressed ? 0.92 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast } }

                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        path: entry.modelData.icon
                        size: 26
                        color: Theme.sph ? (entry.active ? Theme.ink : rail.fgDim) : entry.active ? Theme.accent : Theme.textDim
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: entry.modelData.label
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.sph ? 15 : 12
                        font.capitalization: Theme.headingCaps
                        font.letterSpacing: Theme.trackLabel
                        font.weight: Theme.sph ? Font.Normal : entry.active ? Font.DemiBold : Font.Medium
                        color: entry.active ? rail.fg : rail.fgDim
                    }
                }
                TapHandler { id: tap; onTapped: rail.selected(entry.index) }
            }
        }
    }

    // Live clock at the bottom of the rail
    Column {
        anchors { bottom: parent.bottom; bottomMargin: 18; horizontalCenter: parent.horizontalCenter }
        spacing: 2
        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Theme.fontDisplay; font.pixelSize: 17 * Theme.titleScale; font.weight: Theme.titleWeight
            font.letterSpacing: Theme.trackLabel
            color: rail.fg
            font.features: { "tnum": 1 }
            text: Qt.formatTime(new Date(), "hh:mm")
            Timer { interval: 5000; running: true; repeat: true; onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm") }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Theme.font; font.pixelSize: 12
            color: Theme.sph ? rail.fgDim : SystemInfo.cpuTemperature > 70 ? Theme.warning : Theme.textFaint
            text: SystemInfo.cpuTemperature >= 0 ? SystemInfo.cpuTemperature.toFixed(0) + " °C" : ""
            visible: text.length > 0
        }
    }
}
