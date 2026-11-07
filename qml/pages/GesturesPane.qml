pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Kiosk

RowLayout {
    id: pane
    spacing: Theme.gap

    // --- Pinch / rotate / drag playground --------------------------------------
    Rectangle {
        id: arena
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Theme.surface
        radius: Theme.radiusL
        border.width: 1
        border.color: Theme.border
        clip: true

        function resetCard() { resetAnim.restart() }

        Rectangle {
            id: photo
            width: 260; height: 180
            x: (arena.width - width) / 2
            y: (arena.height - height) / 2
            radius: 20
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.accent }
                GradientStop { position: 1; color: "#F43F5E" }
            }
            Rectangle { // glossy highlight
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: parent.height / 2; radius: parent.radius
                color: Qt.rgba(1, 1, 1, 0.12)
            }
            Column {
                anchors.centerIn: parent
                spacing: 6
                Icon { anchors.horizontalCenter: parent.horizontalCenter; path: Icons.box; color: "white"; size: 40 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Pinch · rotate · drag"
                    font.family: Theme.font; font.pixelSize: 18; font.weight: Font.DemiBold
                    color: "white"
                }
            }
            Behavior on scale { enabled: !pinch.active && !resetAnim.running; NumberAnimation { duration: 90 } } // smooth wheel zoom
        }

        PinchHandler {
            id: pinch
            target: photo
            scaleAxis.minimum: 0.4
            scaleAxis.maximum: 3.5
        }
        DragHandler { target: photo }
        WheelHandler { // trackpad / mouse-wheel zoom for testing on the Mac
            target: photo
            property: "scale"
            acceptedModifiers: Qt.NoModifier
        }
        TapHandler {
            acceptedButtons: Qt.LeftButton
            onDoubleTapped: arena.resetCard()
        }

        ParallelAnimation {
            id: resetAnim
            NumberAnimation { target: photo; property: "x"; to: (arena.width - photo.width) / 2; duration: Theme.slow; easing.type: Easing.OutBack }
            NumberAnimation { target: photo; property: "y"; to: (arena.height - photo.height) / 2; duration: Theme.slow; easing.type: Easing.OutBack }
            NumberAnimation { target: photo; property: "scale"; to: 1; duration: Theme.slow; easing.type: Easing.OutBack }
            NumberAnimation { target: photo; property: "rotation"; to: 0; duration: Theme.slow; easing.type: Easing.OutCubic }
        }

        Row {
            anchors { left: parent.left; bottom: parent.bottom; margins: 14 }
            spacing: 8
            Repeater {
                model: [["Scale", "×" + photo.scale.toFixed(2)],
                        ["Rotate", Math.round(photo.rotation) + "°"],
                        ["Pinch", pinch.active ? "active" : "–"]]
                delegate: Rectangle {
                    required property var modelData
                    width: t.implicitWidth + 22; height: 32; radius: Theme.sph ? 0 : 10
                    color: Theme.surface2
                    Text {
                        id: t
                        anchors.centerIn: parent
                        textFormat: Text.StyledText
                        text: modelData[0] + "  <b>" + modelData[1] + "</b>"
                        font.family: Theme.font; font.pixelSize: 13
                        font.features: { "tnum": 1 }
                        color: Theme.text
                    }
                }
            }
        }
        KButton {
            anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
            compact: true; kind: "secondary"
            text: "Reset"; iconPath: Icons.refresh
            onClicked: arena.resetCard()
        }
    }

    // --- Kinetic list with swipe actions ---------------------------------------
    Rectangle {
        Layout.preferredWidth: 330
        Layout.fillHeight: true
        color: Theme.surface
        radius: Theme.radiusL
        border.width: 1
        border.color: Theme.border
        clip: true

        ListModel {
            id: inbox
            Component.onCompleted: {
                const names = ["Parcel #4821", "Laptop dock", "Library book", "Camera kit", "Tripod",
                               "Projector", "Badge reader", "Headset", "Tablet", "Power bank",
                               "Charger", "Keyboard", "Monitor arm", "Drone", "Speaker", "VR headset",
                               "Microscope", "3D printer spool", "Router", "Label printer"]
                for (let i = 0; i < names.length; ++i)
                    append({ name: names[i], detail: "Slot " + String.fromCharCode(65 + i % 6) + (1 + i % 9) + " · " + (2 + i * 7 % 50) + " min ago" })
            }
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 8
            model: inbox
            spacing: 6
            boundsBehavior: Flickable.OvershootBounds
            flickDeceleration: 2500
            maximumFlickVelocity: 4000
            header: Item {
                width: list.width; height: 44
                Text {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "Flick · swipe ← to remove"
                    font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
                    color: Theme.textDim
                }
            }
            ScrollIndicator.vertical: ScrollIndicator {}

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: Theme.normal }
                    NumberAnimation { property: "x"; to: -list.width; duration: Theme.normal; easing.type: Easing.InCubic }
                }
            }
            displaced: Transition { NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }

            delegate: SwipeDelegate {
                id: row
                required property int index
                required property string name
                required property string detail
                width: list.width
                height: 66
                focusPolicy: Qt.NoFocus
                padding: 0

                background: Rectangle {
                    radius: Theme.radiusS
                    color: row.pressed ? Theme.surface3 : Theme.surface2
                }
                contentItem: Item {
                    Rectangle {
                        id: avatar
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 40; height: 40; radius: Theme.sph ? 0 : 12
                        color: Theme.accentSoft
                        Text {
                            anchors.centerIn: parent
                            text: row.name.charAt(0)
                            font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold
                            color: Theme.accent
                        }
                    }
                    Column {
                        anchors { left: avatar.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        Text { text: row.name; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.text }
                        Text { text: row.detail; font.family: Theme.font; font.pixelSize: 12; color: Theme.textDim }
                    }
                }
                swipe.right: Rectangle {
                    width: 96; height: row.height
                    anchors.right: parent.right
                    radius: Theme.radiusS
                    color: Theme.danger
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; path: Icons.close; color: "white"; size: 20 }
                        Text { text: "Remove"; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold; color: "white" }
                    }
                    TapHandler {
                        onTapped: {
                            Notify.info("Removed “" + row.name + "”")
                            inbox.remove(row.index)
                        }
                    }
                }
                onClicked: Notify.info(row.name)
            }
        }
    }
}
