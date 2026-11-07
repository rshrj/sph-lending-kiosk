import QtQuick
import Kiosk

// Press and hold for `holdMs` to trigger — used for destructive / exit actions.
Rectangle {
    id: root
    property string text: "Hold to confirm"
    property string iconPath: Icons.power
    property int holdMs: 1500
    property color tint: Theme.danger
    property real progress: 0
    signal triggered()

    implicitWidth: 260
    implicitHeight: Theme.touchMin
    radius: Theme.radiusM
    color: Theme.withAlpha(tint, Theme.dark ? 0.14 : 0.10)
    border.width: 1.5
    border.color: Theme.withAlpha(tint, 0.45)
    clip: true

    Rectangle {
        width: parent.width * root.progress
        height: parent.height
        color: Theme.withAlpha(root.tint, 0.45)
    }

    Row {
        anchors.centerIn: parent
        spacing: 10
        Icon { anchors.verticalCenter: parent.verticalCenter; path: root.iconPath; color: root.tint; size: 20 }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.progress > 0 && root.progress < 1 ? "Keep holding…" : root.text
            font.family: Theme.font; font.pixelSize: Theme.fsBody; font.weight: Font.DemiBold
            color: Theme.text
        }
    }

    NumberAnimation {
        id: fill
        target: root; property: "progress"
        to: 1
        duration: root.holdMs * (1 - root.progress)
        onFinished: if (root.progress >= 1) { root.triggered(); drain.start() }
    }
    NumberAnimation { id: drain; target: root; property: "progress"; to: 0; duration: 300; easing.type: Easing.OutCubic }

    TapHandler {
        id: tap
        gesturePolicy: TapHandler.WithinBounds
        onPressedChanged: {
            if (pressed) { drain.stop(); fill.start() }
            else if (root.progress < 1) { fill.stop(); drain.start() }
        }
    }
}
