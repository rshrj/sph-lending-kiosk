pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Kiosk

// Full-screen, three-step transaction: enter code → confirm → done.
// Shows the patterns a real kiosk flow needs: progress, back/cancel, input
// validation with feedback, a deliberate confirm gesture, and auto-return.
Rectangle {
    id: flow
    property bool open: false
    property int step: 0
    property string code: ""
    readonly property int codeLength: 6

    signal closed()

    function start() { step = 0; code = ""; swipe.reset(); open = true }
    function playDone() { mark.play(); ring.restart() }
    function close() { open = false; ring.stop(); closed() }
    function submitCode() {
        if (code.length !== codeLength) return
        if (code === "000000") {
            shake.restart()
            Notify.error("Code not recognised")
            code = ""
            return
        }
        step = 1
    }

    color: Theme.bg
    visible: y < parent.height
    y: open ? 0 : parent.height
    Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }

    // Swallow input so nothing underneath reacts.
    MouseArea { anchors.fill: parent; onWheel: (w) => w.accepted = true }

    // --- Header: cancel / progress / back --------------------------------------
    RowLayout {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.pad }
        height: 56
        spacing: 16

        KButton {
            kind: "secondary"
            iconPath: flow.step === 1 ? Icons.arrowLeft : Icons.close
            text: flow.step === 1 ? "Back" : "Cancel"
            opacity: flow.step < 2 ? 1 : 0
            enabled: flow.step < 2
            Layout.preferredWidth: 130
            onClicked: flow.step === 1 ? flow.step = 0 : flow.close()
        }
        Item { Layout.fillWidth: true }
        Row {
            spacing: 8
            Repeater {
                model: ["Code", "Confirm", "Done"]
                delegate: Row {
                    id: crumb
                    required property int index
                    required property string modelData
                    readonly property bool reached: flow.step >= index
                    spacing: 8
                    Rectangle {
                        width: 30; height: 30; radius: 15
                        color: crumb.reached ? Theme.accent : Theme.surface2
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                        Text {
                            anchors.centerIn: parent
                            visible: flow.step <= crumb.index
                            text: crumb.index + 1
                            font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Bold
                            color: crumb.reached ? Theme.accentText : Theme.textDim
                        }
                        Icon { anchors.centerIn: parent; visible: flow.step > crumb.index; path: Icons.check; color: Theme.accentText; size: 16; strokeWidth: 3 }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: crumb.modelData
                        font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Medium
                        color: crumb.reached ? Theme.text : Theme.textDim
                    }
                    Rectangle {
                        visible: crumb.index < 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 2; radius: 1
                        color: flow.step > crumb.index ? Theme.accent : Theme.surface3
                    }
                }
            }
        }
        Item { Layout.fillWidth: true }
        Item { Layout.preferredWidth: 130 } // balances the Cancel button
    }

    // --- Steps (slide horizontally) ------------------------------------------------
    Item {
        id: stage
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; topMargin: 8 }
        clip: true

        Row {
            x: -flow.step * stage.width
            Behavior on x { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }

            // Step 1 — code entry
            Item {
                width: stage.width; height: stage.height
                RowLayout {
                    anchors { fill: parent; leftMargin: 48; rightMargin: 48; bottomMargin: Theme.pad }
                    spacing: 40
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        Text {
                            text: "Enter your code"
                            font.family: Theme.fontDisplay; font.pixelSize: 38 * Theme.titleScale; font.weight: Theme.headingWeight
                            font.letterSpacing: Theme.sph ? Theme.trackHeading : -0.8; font.capitalization: Theme.headingCaps
                            color: Theme.text
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "It's the 6-digit number on your receipt. Any code works in this demo — try 000000 to see the error state."
                            wrapMode: Text.WordWrap
                            font.family: Theme.font; font.pixelSize: 17
                            color: Theme.textDim
                            lineHeight: 1.15
                        }
                        Row {
                            id: dots
                            Layout.topMargin: 18
                            spacing: 14
                            transform: Translate { id: shakeX }
                            SequentialAnimation {
                                id: shake
                                loops: 1
                                NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 50 }
                                NumberAnimation { target: shakeX; property: "x"; to: 12; duration: 70 }
                                NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 70 }
                                NumberAnimation { target: shakeX; property: "x"; to: 5; duration: 70 }
                                NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
                            }
                            Repeater {
                                model: flow.codeLength
                                delegate: Rectangle {
                                    id: slot
                                    required property int index
                                    readonly property bool filled: index < flow.code.length
                                    width: 50; height: 62; radius: Theme.sph ? 0 : 14
                                    color: Theme.surface
                                    border.width: index === flow.code.length ? 2 : 1
                                    border.color: index === flow.code.length ? Theme.accent : Theme.border
                                    Text {
                                        anchors.centerIn: parent
                                        text: slot.filled ? flow.code.charAt(slot.index) : ""
                                        font.family: Theme.font; font.pixelSize: 28; font.weight: Font.DemiBold
                                        color: Theme.text
                                        scale: slot.filled ? 1 : 0.4
                                        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutBack } }
                                    }
                                }
                            }
                        }
                    }
                    Keypad {
                        Layout.alignment: Qt.AlignVCenter
                        acceptEnabled: flow.code.length === flow.codeLength
                        onDigit: (d) => { if (flow.code.length < flow.codeLength) flow.code += d }
                        onBackspace: flow.code = flow.code.slice(0, -1)
                        onAccept: flow.submitCode()
                    }
                }
            }

            // Step 2 — confirm
            Item {
                width: stage.width; height: stage.height
                ColumnLayout {
                    anchors.centerIn: parent
                    width: 560
                    spacing: 22
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Check & confirm"
                        font.family: Theme.fontDisplay; font.pixelSize: 38 * Theme.titleScale; font.weight: Theme.headingWeight
                            font.letterSpacing: Theme.sph ? Theme.trackHeading : -0.8; font.capitalization: Theme.headingCaps
                        color: Theme.text
                    }
                    Card {
                        Layout.fillWidth: true
                        InfoRow { label: "Reference"; value: "#" + flow.code }
                        InfoRow { label: "Item"; value: "Demo item · 1 piece" }
                        InfoRow { label: "Slot"; value: "B3 (opens after confirming)" }
                        InfoRow { label: "Time"; value: Qt.formatDateTime(new Date(), "d MMM, hh:mm"); last: true }
                    }
                    SwipeToConfirm {
                        id: swipe
                        Layout.fillWidth: true
                        onAccepted: confirmDelay.start()
                    }
                    Timer { id: confirmDelay; interval: 450; onTriggered: { flow.step = 2; flow.playDone() } }
                }
            }

            // Step 3 — done
            Item {
                width: stage.width; height: stage.height
                ColumnLayout {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -20
                    spacing: 18
                    SuccessMark { id: mark; Layout.alignment: Qt.AlignHCenter; size: 150 }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "All set!"
                        font.family: Theme.fontDisplay; font.pixelSize: 40 * Theme.titleScale; font.weight: Theme.headingWeight
                        font.letterSpacing: Theme.sph ? Theme.trackHeading : 0; font.capitalization: Theme.headingCaps
                        color: Theme.text
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Slot B3 is open. Thanks for using the kiosk."
                        font.family: Theme.font; font.pixelSize: 18
                        color: Theme.textDim
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        spacing: 18
                        CountdownRing { id: ring; seconds: 6; onFinished: flow.close() }
                        KButton { text: "Done"; iconPath: Icons.check; implicitWidth: 180; onClicked: flow.close() }
                    }
                }
            }
        }
    }
}
