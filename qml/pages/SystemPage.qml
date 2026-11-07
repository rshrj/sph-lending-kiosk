pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Kiosk

Item {
    id: page

    readonly property string graphicsApi: {
        switch (GraphicsInfo.api) {
        case GraphicsInfo.OpenGL: return "OpenGL / GLES (RHI)"
        case GraphicsInfo.Vulkan: return "Vulkan (RHI)"
        case GraphicsInfo.Metal: return "Metal (RHI)"
        case GraphicsInfo.Software: return "Software"
        case GraphicsInfo.Direct3D11: return "Direct3D 11"
        default: return "Unknown"
        }
    }

    component Metric: ColumnLayout {
        id: metric
        property string label
        property string value
        property string unit
        property color tint: Theme.accent
        property var series: []
        property real maxValue: 100
        property real minValue: 0
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            Text { text: metric.label; font.family: Theme.font; font.pixelSize: 14; color: Theme.textDim; Layout.fillWidth: true }
            Text {
                text: metric.value
                font.family: Theme.font; font.pixelSize: 26; font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Theme.text
            }
            Text { text: metric.unit; font.family: Theme.font; font.pixelSize: 14; color: Theme.textDim; Layout.alignment: Qt.AlignBaseline }
        }
        Sparkline {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            values: metric.series
            minValue: metric.minValue
            maxValue: metric.maxValue
            color: metric.tint
        }
    }

    RowLayout {
        anchors { fill: parent; margins: Theme.pad }
        spacing: Theme.gap

        // --- Live metrics --------------------------------------------------------
        ColumnLayout {
            Layout.preferredWidth: 360
            Layout.maximumWidth: 360
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 18

            SectionHeader { title: "System"; subtitle: SystemInfo.deviceModel; Layout.fillWidth: true }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Metric {
                    Layout.fillWidth: true
                    label: "CPU load"
                    value: SystemInfo.cpuLoad >= 0 ? SystemInfo.cpuLoad.toFixed(0) : "–"
                    unit: "%"
                    series: SystemInfo.loadHistory
                }
                Metric {
                    Layout.fillWidth: true
                    label: "SoC temperature"
                    value: SystemInfo.cpuTemperature >= 0 ? SystemInfo.cpuTemperature.toFixed(1) : "n/a"
                    unit: SystemInfo.cpuTemperature >= 0 ? "°C" : ""
                    tint: SystemInfo.cpuTemperature > 70 ? Theme.warning : "#2DD4BF"
                    series: SystemInfo.tempHistory
                    minValue: 30; maxValue: 85
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Memory"; font.family: Theme.font; font.pixelSize: 14; color: Theme.textDim; Layout.fillWidth: true }
                        Text {
                            text: SystemInfo.memoryTotalMiB > 0
                                  ? (SystemInfo.memoryUsedMiB / 1024).toFixed(1) + " / " + (SystemInfo.memoryTotalMiB / 1024).toFixed(1) + " GiB"
                                  : "n/a"
                            font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: Theme.text
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 10; radius: 5
                        color: Theme.surface3
                        Rectangle {
                            height: parent.height; radius: 5
                            width: SystemInfo.memoryTotalMiB > 0 ? parent.width * SystemInfo.memoryUsedMiB / SystemInfo.memoryTotalMiB : 0
                            color: "#A78BFA"
                            Behavior on width { NumberAnimation { duration: Theme.slow } }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // --- Facts -----------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface
            radius: Theme.radiusL
            border.width: 1
            border.color: Theme.border
            clip: true

            Flickable {
                id: facts
                anchors { fill: parent; margins: 6 }
                contentHeight: factsCol.implicitHeight + 28
                boundsBehavior: Flickable.OvershootBounds
                ScrollIndicator.vertical: ScrollIndicator {}

                ColumnLayout {
                    id: factsCol
                    x: 16; y: 14
                    width: facts.width - 32
                    spacing: 0

                    Text { text: "Device"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.text; Layout.bottomMargin: 4 }
                    InfoRow { label: "Host"; value: SystemInfo.hostName }
                    InfoRow { label: "IP"; value: SystemInfo.ipAddresses.length ? SystemInfo.ipAddresses.join("\n") : "offline" }
                    InfoRow { label: "OS"; value: SystemInfo.osName }
                    InfoRow { label: "Kernel"; value: SystemInfo.kernel }
                    InfoRow { label: "CPU arch"; value: SystemInfo.cpuArch }
                    InfoRow { label: "Uptime"; value: SystemInfo.uptime; last: true }

                    Text { text: "Graphics & Qt"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.text; Layout.topMargin: 18; Layout.bottomMargin: 4 }
                    InfoRow { label: "Qt"; value: SystemInfo.qtVersion }
                    InfoRow { label: "Build"; value: SystemInfo.buildInfo }
                    InfoRow { label: "QPA platform"; value: SystemInfo.platformName }
                    InfoRow { label: "Renderer"; value: page.graphicsApi }
                    InfoRow { label: "Window"; value: page.width > 0 ? Window.width + " × " + Window.height + " px" : "" }
                    InfoRow {
                        label: "Screen"
                        value: Screen.width + " × " + Screen.height + " @" + Screen.devicePixelRatio + "x · " + Screen.name
                        last: true
                    }

                    Text { text: "Input devices"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.text; Layout.topMargin: 18; Layout.bottomMargin: 4 }
                    Repeater {
                        model: SystemInfo.inputDevices
                        delegate: InfoRow {
                            required property var modelData
                            required property int index
                            label: modelData.type
                            value: modelData.name + (modelData.points > 1 ? "  · " + modelData.points + " pts" : "")
                            valueColor: modelData.type === "Touchscreen" ? Theme.success : Theme.text
                            last: index === SystemInfo.inputDevices.length - 1
                        }
                    }
                }
            }
        }
    }
}
