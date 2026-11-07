pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Kiosk

// Borrowing needs to know who you are: tap the Legi card, or type the Legi number.
Item {
    id: screen
    property string digits: ""
    property string error: ""
    readonly property int legiLength: 8

    function reset() { digits = ""; error = "" }
    function submit() {
        if (digits.length !== legiLength || Session.pending) return
        error = ""
        Session.signInLegi(digits, (ok, msg) => {
            if (ok) { digits = ""; return }
            error = msg
            digits = ""
            shake.restart()
        })
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 40; rightMargin: 40; topMargin: 20; bottomMargin: 20 }
        spacing: 36

        // ---- Tap -----------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 10
            TapPrompt { Layout.alignment: Qt.AlignHCenter; active: screen.visible; tint: Theme.purple }
            Heading { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6; text: "Tap your Legi" }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Hold your ETH card flat against the reader."
                wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 18
                color: Theme.textDim
            }
        }

        // ---- "or" divider ----------------------------------------------------------
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: false
            spacing: 10
            Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.fillHeight: true; implicitWidth: Theme.rule; color: Theme.ink }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "or"
                font.family: Theme.fontDisplay; font.pixelSize: 26; font.capitalization: Theme.headingCaps
                color: Theme.text
            }
            Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.fillHeight: true; implicitWidth: Theme.rule; color: Theme.ink }
        }

        // ---- Type ------------------------------------------------------------------
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: false
            spacing: 14
            Heading { level: 3; text: "Type your Legi number" }

            Item {
                Layout.fillWidth: true
                implicitHeight: 58
                Row {
                    id: slots
                    spacing: 4
                    transform: Translate { id: shakeX }
                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 50 }
                        NumberAnimation { target: shakeX; property: "x"; to: 12; duration: 70 }
                        NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 70 }
                        NumberAnimation { target: shakeX; property: "x"; to: 5; duration: 70 }
                        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
                    }
                    Repeater {
                        model: screen.legiLength
                        delegate: Row {
                            id: slot
                            required property int index
                            spacing: 4
                            Rectangle {
                                width: 34; height: 52
                                color: Theme.surface
                                border.width: slot.index === screen.digits.length ? 3 : 2
                                border.color: slot.index === screen.digits.length ? Theme.purple : Theme.ink
                                Text {
                                    anchors.centerIn: parent
                                    text: slot.index < screen.digits.length ? screen.digits.charAt(slot.index) : ""
                                    font.family: Theme.font; font.pixelSize: 26; font.weight: Font.Bold
                                    color: Theme.text
                                }
                            }
                            Text { // dashes after the 2nd and 5th digit: 21-912-345
                                visible: slot.index === 1 || slot.index === 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: "–"
                                font.family: Theme.font; font.pixelSize: 22
                                color: Theme.textDim
                            }
                        }
                    }
                }
            }

            Text {
                Layout.preferredWidth: keypad.width
                text: screen.error.length > 0 ? screen.error : Session.pending ? "Checking…" : "8 digits, printed on your Legi"
                wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 15; font.weight: screen.error.length > 0 ? Font.Bold : Font.Normal
                color: screen.error.length > 0 ? Theme.red : Theme.textDim
            }

            Keypad {
                id: keypad
                keyWidth: 104
                keyHeight: 62
                acceptEnabled: screen.digits.length === screen.legiLength && !Session.pending
                onDigit: (d) => { screen.error = ""; if (screen.digits.length < screen.legiLength) screen.digits += d }
                onBackspace: screen.digits = screen.digits.slice(0, -1)
                onAccept: screen.submit()
            }
        }
    }
}
