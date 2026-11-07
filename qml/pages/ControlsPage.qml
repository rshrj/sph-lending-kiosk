import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Kiosk

// A scrolling board of touch controls. Also exercises kinetic scrolling with
// nested horizontal gestures (sliders/swipe inside a vertical Flickable).
Item {
    id: page

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: board.implicitHeight + 2 * Theme.pad
        boundsBehavior: Flickable.OvershootBounds
        flickDeceleration: 2200
        maximumFlickVelocity: 3500
        ScrollIndicator.vertical: ScrollIndicator {}

        ColumnLayout {
            id: board
            x: Theme.pad; y: Theme.pad
            width: flick.width - 2 * Theme.pad
            spacing: 18

            SectionHeader { title: "Controls"; subtitle: "Every control here is sized for a finger, not a cursor. Scroll for more ↓"; Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                Layout.alignment: Qt.AlignTop

                // ---- column 1
                ColumnLayout {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.gap

                    Card {
                        Layout.fillWidth: true
                        title: "Switches"; iconPath: Icons.power
                        KSwitch { Layout.fillWidth: true; text: "Wi-Fi"; subtitle: "Connected"; checked: true }
                        KSwitch { Layout.fillWidth: true; text: "Sound"; subtitle: "Key clicks & alerts" }
                        KSwitch { Layout.fillWidth: true; text: "Night mode"; subtitle: "Dim after 22:00"; checked: true }
                    }
                    Card {
                        Layout.fillWidth: true
                        title: "Stepper"; subtitle: "Hold +/− to auto-repeat"; iconPath: Icons.grid
                        Stepper { Layout.fillWidth: true; value: 3; unit: "items" }
                    }
                    Card {
                        Layout.fillWidth: true
                        title: "Buttons"; iconPath: Icons.check
                        KButton { Layout.fillWidth: true; text: "Primary"; onClicked: Notify.success("Primary tapped") }
                        KButton { Layout.fillWidth: true; kind: "secondary"; text: "Secondary"; onClicked: Notify.info("Secondary tapped") }
                        KButton { Layout.fillWidth: true; kind: "ghost"; text: "Ghost"; onClicked: Notify.info("Ghost tapped") }
                    }
                }

                // ---- column 2
                ColumnLayout {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.gap

                    Card {
                        Layout.fillWidth: true
                        title: "Brightness"; subtitle: "Software dimming (HDMI has no backlight API)"; iconPath: Icons.sun
                        KSlider {
                            Layout.fillWidth: true
                            from: 30; to: 100; suffix: " %"
                            value: Math.round((1 - Notify.softDim) * 100)
                            onMoved: Notify.softDim = 1 - value / 100
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        title: "Dial"; subtitle: "Drag around the ring"; iconPath: Icons.thermometer
                        Dial { Layout.alignment: Qt.AlignHCenter }
                    }
                    Card {
                        Layout.fillWidth: true
                        title: "Segmented"; iconPath: Icons.sliders
                        Segmented { Layout.fillWidth: true; model: ["S", "M", "L", "XL"]; currentIndex: 1 }
                        Segmented { Layout.fillWidth: true; model: ["Day", "Week", "Month"] }
                    }
                }

                // ---- column 3
                ColumnLayout {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.gap

                    Card {
                        Layout.fillWidth: true
                        title: "Text input"; subtitle: "Opens the on-screen keyboard"; iconPath: Icons.keyboard
                        TextField {
                            id: nameField
                            Layout.fillWidth: true
                            implicitHeight: Theme.touchMin
                            placeholderText: "Your name"
                            placeholderTextColor: Theme.textFaint
                            font.family: Theme.font; font.pixelSize: 17
                            color: Theme.text
                            leftPadding: 16
                            inputMethodHints: Qt.ImhNoPredictiveText
                            background: Rectangle {
                                radius: Theme.radiusM
                                color: Theme.surface2
                                border.width: nameField.activeFocus ? 2 : 1
                                border.color: nameField.activeFocus ? Theme.accent : Theme.border
                                Behavior on border.color { ColorAnimation { duration: Theme.fast } }
                            }
                            onAccepted: { Notify.success("Hello, " + (text || "stranger") + "!"); focus = false }
                        }
                        TextField {
                            id: pinField
                            Layout.fillWidth: true
                            implicitHeight: Theme.touchMin
                            placeholderText: "Numeric (PIN)"
                            placeholderTextColor: Theme.textFaint
                            font.family: Theme.font; font.pixelSize: 17
                            color: Theme.text
                            leftPadding: 16
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle {
                                radius: Theme.radiusM
                                color: Theme.surface2
                                border.width: pinField.activeFocus ? 2 : 1
                                border.color: pinField.activeFocus ? Theme.accent : Theme.border
                            }
                            onAccepted: focus = false
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        title: "Swipe to confirm"; subtitle: "Can't be triggered by an accidental tap"; iconPath: Icons.arrowRight
                        SwipeToConfirm {
                            id: swipe
                            Layout.fillWidth: true
                            onAccepted: { Notify.success("Confirmed"); resetTimer.start() }
                            Timer { id: resetTimer; interval: 1800; onTriggered: swipe.reset() }
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        title: "Hold to confirm"; subtitle: "For destructive actions"; iconPath: Icons.clock
                        HoldButton {
                            Layout.fillWidth: true
                            text: "Hold to reset"
                            iconPath: Icons.refresh
                            onTriggered: Notify.error("Reset triggered (demo)")
                        }
                    }
                }
            }
        }
    }
}
