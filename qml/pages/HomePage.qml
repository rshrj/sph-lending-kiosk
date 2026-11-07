import QtQuick
import QtQuick.Layouts
import Kiosk

Item {
    id: page

    property date now: new Date()
    Timer { interval: 1000; running: page.visible; repeat: true; triggeredOnStart: true; onTriggered: page.now = new Date() }

    readonly property string greeting: {
        const h = now.getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
    readonly property bool hasTouch: {
        const devs = SystemInfo.inputDevices
        for (let i = 0; i < devs.length; ++i)
            if (devs[i].type === "Touchscreen") return true
        return false
    }

    component StatusChip: Rectangle {
        id: chip
        property string iconPath
        property string text
        property color tint: Theme.textDim
        implicitHeight: 38
        implicitWidth: chipRow.implicitWidth + 26
        radius: Theme.sph ? 0 : 19
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8
            Icon { anchors.verticalCenter: parent.verticalCenter; path: chip.iconPath; size: 17; color: chip.tint }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium
                color: Theme.text
            }
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: Theme.pad }
        spacing: 20

        // --- Clock header ----------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                spacing: 0
                Text {
                    text: page.greeting
                    font.family: Theme.font; font.pixelSize: 19; font.weight: Font.Medium
                    color: Theme.textDim
                }
                Row {
                    spacing: 6
                    Text {
                        id: bigTime
                        text: Qt.formatTime(page.now, "hh:mm")
                        font.family: Theme.fontDisplay; font.pixelSize: Theme.fsDisplay; font.weight: Theme.displayWeight
                        font.letterSpacing: Theme.sph ? 1 : -3
                        font.features: { "tnum": 1 }
                        color: Theme.text
                    }
                    Text {
                        anchors.baseline: bigTime.baseline
                        text: Qt.formatTime(page.now, "ss")
                        font.family: Theme.font; font.pixelSize: 28; font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                        color: Theme.sph ? Theme.textDim : Theme.accent
                    }
                }
                Text {
                    text: Qt.formatDate(page.now, "dddd, d MMMM")
                    font.family: Theme.font; font.pixelSize: 19
                    color: Theme.textDim
                }
            }

            Item { Layout.fillWidth: true }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                spacing: 10
                StatusChip {
                    Layout.alignment: Qt.AlignRight
                    iconPath: Icons.hand
                    tint: page.hasTouch ? Theme.success : Theme.warning
                    text: page.hasTouch ? "Touchscreen ready" : "No touchscreen (mouse mode)"
                }
                StatusChip {
                    Layout.alignment: Qt.AlignRight
                    visible: SystemInfo.cpuTemperature >= 0
                    iconPath: Icons.thermometer
                    tint: SystemInfo.cpuTemperature > 70 ? Theme.warning : Theme.success
                    text: "CPU " + SystemInfo.cpuTemperature.toFixed(1) + " °C"
                }
                StatusChip {
                    Layout.alignment: Qt.AlignRight
                    iconPath: Icons.wifi
                    tint: SystemInfo.ipAddresses.length > 0 ? Theme.success : Theme.danger
                    text: SystemInfo.ipAddresses.length > 0 ? SystemInfo.ipAddresses[0].split(" ")[0] : "Offline"
                }
            }
        }

        // --- Tiles -------------------------------------------------------------
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rows: 2
            columnSpacing: Theme.gap
            rowSpacing: Theme.gap

            ActionTile {
                Layout.rowSpan: 2
                Layout.fillHeight: true
                Layout.preferredWidth: 330
                featured: true
                iconPath: Icons.play
                text: "Start guided flow"
                subtitle: "Keypad → confirm → done. A typical kiosk transaction, end to end."
                onClicked: Notify.startFlow()
            }
            ActionTile {
                Layout.fillWidth: true; Layout.fillHeight: true
                iconPath: Icons.hand
                tint: Theme.sph ? Theme.cyan : "#2DD4BF"
                text: "Touch lab"
                subtitle: "Multi-touch, gestures, accuracy"
                onClicked: Notify.navigate(1)
            }
            ActionTile {
                Layout.fillWidth: true; Layout.fillHeight: true
                iconPath: Icons.sliders
                tint: Theme.sph ? Theme.yellow : "#F59E0B"
                text: "Controls"
                subtitle: "Sliders, dial, keyboard, swipes"
                onClicked: Notify.navigate(2)
            }
            ActionTile {
                Layout.fillWidth: true; Layout.fillHeight: true
                iconPath: Icons.cpu
                tint: Theme.sph ? Theme.orange : "#38BDF8"
                text: "System"
                subtitle: "Live load, temperature, devices"
                onClicked: Notify.navigate(3)
            }
            ActionTile {
                Layout.fillWidth: true; Layout.fillHeight: true
                iconPath: Icons.badge
                tint: Theme.sph ? Theme.green : "#A78BFA"
                text: "Card login"
                subtitle: "RC522 reader: tap, enrol, sign in"
                onClicked: Notify.navigate(4)
            }
        }
    }
}
