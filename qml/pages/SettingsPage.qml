pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Kiosk

Item {
    id: page
    readonly property var idleChoices: [0, 15, 45, 120]

    RowLayout {
        anchors { fill: parent; margins: Theme.pad }
        spacing: Theme.gap

        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            Layout.fillHeight: true
            spacing: Theme.gap

            SectionHeader { id: header; title: "Settings"; subtitle: "Saved automatically"; Layout.fillWidth: true }

            Card {
                Layout.fillWidth: true
                title: "Appearance"; iconPath: Theme.dark ? Icons.moon : Icons.sun
                Segmented {
                    Layout.fillWidth: true
                    model: Theme.styles.map(s => s.name)
                    currentIndex: Theme.sph ? 1 : 0
                    onActivated: (i) => Theme.setStyle(Theme.styles[i].id)
                }
                Segmented {
                    Layout.fillWidth: true
                    model: ["Dark", "Light"]
                    currentIndex: Theme.dark ? 0 : 1
                    onActivated: (i) => Theme.dark = (i === 0)
                }
                Text { text: "Accent"; font.family: Theme.font; font.pixelSize: 14; color: Theme.textDim; Layout.topMargin: 4 }
                Row {
                    spacing: 12
                    Repeater {
                        model: Theme.accents
                        delegate: Item {
                            id: swatch
                            required property color modelData
                            readonly property bool selected: Qt.colorEqual(Theme.accent, modelData)
                            width: 48; height: 48
                            Rectangle {
                                anchors.centerIn: parent
                                width: 48; height: 48; radius: 24
                                color: "transparent"
                                border.width: 3
                                border.color: swatch.selected ? swatch.modelData : "transparent"
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: swatch.selected ? 34 : 40; height: width; radius: width / 2
                                color: swatch.modelData
                                scale: tap.pressed ? 0.85 : 1
                                Behavior on width { NumberAnimation { duration: Theme.fast } }
                                Behavior on scale { NumberAnimation { duration: Theme.fast } }
                            }
                            TapHandler { id: tap; onTapped: Theme.accent = swatch.modelData }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                title: "Diagnostics"; iconPath: Icons.cpu
                KSwitch {
                    Layout.fillWidth: true
                    text: "FPS overlay"
                    subtitle: "Frames presented per second"
                    checked: Notify.showFps
                    onToggled: Notify.showFps = checked
                }
            }
            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 1
            Layout.fillHeight: true
            spacing: Theme.gap
            Item { Layout.preferredHeight: header.height }

            Card {
                Layout.fillWidth: true
                title: "Kiosk behaviour"; subtitle: "After the idle timeout the attract screen appears and the app resets to Home."
                iconPath: Icons.clock
                Segmented {
                    Layout.fillWidth: true
                    model: ["Off", "15 s", "45 s", "2 min"]
                    currentIndex: Math.max(0, page.idleChoices.indexOf(IdleMonitor.timeout))
                    onActivated: (i) => IdleMonitor.timeout = page.idleChoices[i]
                }
                KButton {
                    Layout.fillWidth: true
                    kind: "secondary"
                    text: "Preview attract screen"
                    iconPath: Icons.play
                    onClicked: IdleMonitor.goIdle()
                }
            }

            Card {
                Layout.fillWidth: true
                title: "Exit"; subtitle: "Kiosk mode has no window controls; this is the escape hatch."
                iconPath: Icons.power
                HoldButton {
                    Layout.fillWidth: true
                    text: "Hold to quit app"
                    holdMs: 2000
                    onTriggered: Qt.quit()
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
