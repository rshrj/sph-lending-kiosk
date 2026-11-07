import QtQuick
import Kiosk

// Bottom toast. Listens to Notify.toast(); newer messages replace older ones.
Rectangle {
    id: toast
    property string kind: "info"
    property alias message: label.text

    anchors.horizontalCenter: parent.horizontalCenter
    y: shown ? parent.height - height - 28 : parent.height + 10
    property bool shown: false
    Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    width: row.implicitWidth + 40
    height: 52
    radius: 0
    color: Theme.ink
    z: 1000

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26; radius: 0
            color: toast.kind === "success" ? Theme.success : toast.kind === "error" ? Theme.danger : Theme.accent
            Icon {
                anchors.centerIn: parent
                path: toast.kind === "error" ? Icons.close : toast.kind === "success" ? Icons.check : Icons.sparkle
                color: Theme.accentText; size: 15; strokeWidth: 2.6
            }
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Medium
            color: Theme.paper
        }
    }

    Timer { id: hideTimer; interval: 2600; onTriggered: toast.shown = false }
    TapHandler { onTapped: toast.shown = false }

    Connections {
        target: Notify
        function onToast(message, kind) {
            toast.message = message
            toast.kind = kind
            toast.shown = true
            hideTimer.restart()
        }
    }
}
