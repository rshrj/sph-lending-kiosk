import QtQuick
import Kiosk

// Idle / attract screen: the purple SPH band, full screen. Clock, a clear call to action.
// The first touch only wakes the kiosk; it never "clicks through". A card tap goes
// straight to borrowing (Main handles Rfid).
Rectangle {
    id: attract
    property bool active: false
    property date now: new Date()

    color: Theme.purple
    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: attract.active ? 700 : 300; easing.type: Easing.InOutQuad } }

    Timer { interval: 1000; running: attract.visible; repeat: true; triggeredOnStart: true; onTriggered: attract.now = new Date() }

    Image {
        anchors { left: parent.left; top: parent.top; margins: 36 }
        source: "../assets/sph/sph-logo.svg"
        sourceSize.width: 150
    }
    Text {
        anchors { right: parent.right; top: parent.top; margins: 36 }
        text: Qt.formatDate(attract.now, "dddd d MMMM")
        font.family: Theme.font; font.pixelSize: 22
        color: Theme.ink
    }

    Column {
        anchors { left: parent.left; leftMargin: 64; verticalCenter: parent.verticalCenter; verticalCenterOffset: -6 }
        spacing: 0
        Text {
            text: Qt.formatTime(attract.now, "hh:mm")
            font.family: Theme.fontDisplay; font.pixelSize: 200
            font.letterSpacing: 2
            color: Theme.ink
        }
        Item {
            width: title.implicitWidth; height: title.implicitHeight
            Image { // marker stroke under the title
                x: -10; width: parent.width + 20
                height: 34
                y: parent.height - height + 4
                source: Theme.brush("yellow")
                sourceSize: Qt.size(width, height)
                fillMode: Image.Stretch
            }
            Text {
                id: title
                text: "Borrow & return"
                font.family: Theme.fontDisplay; font.pixelSize: 72
                font.capitalization: Font.AllUppercase; font.letterSpacing: Theme.trackHeading
                color: Theme.ink
            }
        }
        Text {
            topPadding: 14
            text: "Tools and electronics from the makerspace"
            font.family: Theme.font; font.pixelSize: 24
            color: Theme.ink
        }
    }

    TapPrompt {
        anchors { right: parent.right; rightMargin: 70; verticalCenter: parent.verticalCenter; verticalCenterOffset: -20 }
        active: attract.visible
        tint: Theme.yellow
        scale: 1.3
    }

    Rectangle { // bottom call-to-action strip
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 76
        color: Theme.ink
        Row {
            anchors.centerIn: parent
            spacing: 18
            Icon { anchors.verticalCenter: parent.verticalCenter; path: Icons.contactless; size: 28; color: Theme.purple; strokeWidth: 2.4 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Tap your Legi to borrow  ·  Touch the screen to start"
                font.family: Theme.fontDisplay; font.pixelSize: 26 * Theme.titleScale
                font.capitalization: Font.AllUppercase; font.letterSpacing: Theme.trackLabel
                color: Theme.paper
            }
        }
    }

    // Block all input while visible (including during the fade-out).
    MouseArea {
        anchors.fill: parent
        enabled: attract.visible
        onPressed: IdleMonitor.wake()
        onWheel: (w) => w.accepted = true
    }
    MultiPointTouchArea { anchors.fill: parent; enabled: attract.visible; mouseEnabled: false; onPressed: IdleMonitor.wake() }
}
