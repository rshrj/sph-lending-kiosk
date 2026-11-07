pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Kiosk

// The purple SPH header band: logo · back · step crumbs · who's signed in · cancel.
// Long-pressing the logo opens the staff panel.
Rectangle {
    id: header
    property var steps: []            // crumb labels; empty = no crumbs
    property int step: 0
    property string title: ""         // shown instead of crumbs when there are none
    property bool backVisible: false
    property bool cancelVisible: false
    property string cancelText: "Cancel"
    property string userText: ""
    signal back()
    signal cancel()
    signal logoHeld()

    implicitHeight: Theme.headerHeight
    color: Theme.purple

    Item {
        id: logoBox
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 128
        Image {
            anchors.centerIn: parent
            source: "../../assets/sph/sph-logo.svg"
            sourceSize.width: 96
            scale: logoTap.pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: Theme.normal } }
        }
        TapHandler {
            id: logoTap
            longPressThreshold: 1.5
            onLongPressed: header.logoHeld()
        }
    }

    KButton {
        anchors { left: logoBox.right; verticalCenter: parent.verticalCenter }
        visible: header.backVisible
        compact: true
        kind: "secondary"
        iconPath: Icons.arrowLeft
        text: "Back"
        onClicked: header.back()
    }

    // Crumbs (or a title), centred on the screen
    Row {
        anchors.centerIn: parent
        spacing: 10
        visible: header.steps.length > 0
        Repeater {
            model: header.steps
            delegate: Row {
                id: crumb
                required property int index
                required property string modelData
                readonly property bool reached: header.step >= index
                readonly property bool done: header.step > index
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30; radius: 15
                    color: crumb.reached ? Theme.ink : "transparent"
                    border.width: 2
                    border.color: Theme.ink
                    opacity: crumb.reached ? 1 : 0.45
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                    Text {
                        anchors.centerIn: parent
                        visible: !crumb.done
                        text: crumb.index + 1
                        font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Bold
                        color: crumb.reached ? Theme.purple : Theme.ink
                    }
                    Icon { anchors.centerIn: parent; visible: crumb.done; path: Icons.check; color: Theme.purple; size: 16; strokeWidth: 3 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: crumb.modelData
                    font.family: Theme.fontDisplay; font.pixelSize: 17 * Theme.titleScale
                    font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackLabel
                    color: Theme.ink
                    opacity: crumb.reached ? 1 : 0.55
                }
                Rectangle {
                    visible: crumb.index < header.steps.length - 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 2
                    color: Theme.ink
                    opacity: crumb.done ? 1 : 0.35
                }
            }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: header.steps.length === 0 && header.title.length > 0
        text: header.title
        font.family: Theme.fontDisplay; font.pixelSize: 22 * Theme.titleScale
        font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackHeading
        color: Theme.ink
    }

    RowLayout {
        anchors { right: parent.right; rightMargin: Theme.pad; verticalCenter: parent.verticalCenter }
        spacing: 14
        Row {
            visible: header.userText.length > 0
            spacing: 8
            Icon { anchors.verticalCenter: parent.verticalCenter; path: Icons.badge; size: 20; color: Theme.ink }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: header.userText
                font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Bold
                color: Theme.ink
            }
        }
        KButton {
            visible: header.cancelVisible
            compact: true
            kind: "secondary"
            iconPath: Icons.close
            text: header.cancelText
            onClicked: header.cancel()
        }
    }
}
