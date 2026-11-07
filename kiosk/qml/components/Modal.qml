import QtQuick
import QtQuick.Layouts
import Kiosk

// Centered panel over a dimmed backdrop. Tap the backdrop (or ×) to close.
// Children go into the panel's column.
Item {
    id: modal
    property bool open: false
    property string title
    property int panelWidth: 640
    default property alias content: body.data
    signal closed()

    function close() { open = false; closed() }

    anchors.fill: parent
    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlay
        MouseArea { anchors.fill: parent; onClicked: modal.close(); onWheel: (w) => w.accepted = true }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: modal.panelWidth
        height: Math.min(parent.height - 40, column.implicitHeight + 48)
        color: Theme.paper
        border.width: Theme.strokeCard
        border.color: Theme.ink
        scale: modal.open ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
        MouseArea { anchors.fill: parent }   // don't let taps fall through to the backdrop

        ColumnLayout {
            id: column
            anchors { fill: parent; margins: 24 }
            spacing: 16
            RowLayout {
                Layout.fillWidth: true
                Heading { level: 2; text: modal.title; Layout.fillWidth: true; elide: Text.ElideRight }
                KButton { compact: true; kind: "secondary"; iconPath: Icons.close; text: "Close"; onClicked: modal.close() }
            }
            ColumnLayout {
                id: body
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
            }
        }
    }
}
