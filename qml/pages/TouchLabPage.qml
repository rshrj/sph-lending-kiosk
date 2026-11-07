import QtQuick
import QtQuick.Layouts
import Kiosk

Item {
    id: page
    property alias tab: tabs.currentIndex

    ColumnLayout {
        anchors { fill: parent; margins: Theme.pad }
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            SectionHeader {
                title: "Touch lab"
                subtitle: ["Up to 10 simultaneous points, with trails",
                           "Drag · pinch · rotate · double-tap to reset",
                           "Tap the targets — measures offset & bias"][tabs.currentIndex]
                Layout.fillWidth: true
            }
            Segmented {
                id: tabs
                model: ["Multi-touch", "Gestures", "Accuracy"]
                segmentWidth: 132
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex
            MultiTouchPane {}
            GesturesPane {}
            AccuracyPane {}
        }
    }
}
