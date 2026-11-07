pragma ComponentBehavior: Bound
import QtQuick
import Kiosk

// Idle / attract loop. Drifting light, a clock and a clear call to action.
// The first touch only wakes the kiosk — it never "clicks through".
Rectangle {
    id: attract
    property bool active: false
    property date now: new Date()

    color: "#07080C"
    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: attract.active ? 900 : 350; easing.type: Easing.InOutQuad } }

    Timer { interval: 1000; running: attract.visible; repeat: true; triggeredOnStart: true; onTriggered: attract.now = new Date() }

    component Drifter: SoftBlob {
        id: d
        property real ax: 0.5
        property real ay: 0.5
        property real phase: 0
        property int period: 14000
        property real t: 0
        x: attract.width * (ax + 0.22 * Math.sin(t + phase)) - diameter / 2
        y: attract.height * (ay + 0.22 * Math.cos(t * 0.8 + phase)) - diameter / 2
        NumberAnimation on t { from: 0; to: Math.PI * 2; duration: d.period; loops: Animation.Infinite; running: attract.visible }
    }

    Drifter { color: Theme.accent; diameter: 620; ax: 0.25; ay: 0.35; period: 17000 }
    Drifter { color: "#F43F5E"; diameter: 520; ax: 0.75; ay: 0.6; phase: 2; period: 21000 }
    Drifter { color: "#2DD4BF"; diameter: 460; ax: 0.55; ay: 0.25; phase: 4; period: 25000 }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(attract.now, "hh:mm")
            font.family: Theme.fontDisplay; font.pixelSize: Theme.sph ? 170 : 140; font.weight: Theme.displayWeight
            font.letterSpacing: Theme.sph ? 2 : -5
            font.features: { "tnum": 1 }
            color: "white"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(attract.now, "dddd d MMMM")
            font.family: Theme.font; font.pixelSize: 24
            color: Qt.rgba(1, 1, 1, 0.7)
        }
    }

    Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 56 }
        spacing: 14
        Rectangle {
            width: 52; height: 52; radius: 26
            color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
            Icon { anchors.centerIn: parent; path: Icons.hand; color: "white"; size: 26 }
            SequentialAnimation on scale {
                running: attract.visible; loops: Animation.Infinite
                NumberAnimation { to: 1.12; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Touch anywhere to begin"
            font.family: Theme.font; font.pixelSize: 24; font.weight: Font.Medium
            color: "white"
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
