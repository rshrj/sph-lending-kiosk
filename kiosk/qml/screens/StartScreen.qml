import QtQuick
import QtQuick.Layouts
import Kiosk

// Borrow or return? A card tap anywhere also starts borrowing (handled in Main).
Item {
    id: screen
    signal borrow()
    signal giveBack()

    ColumnLayout {
        anchors { fill: parent; leftMargin: 32; rightMargin: 32; topMargin: 26; bottomMargin: 24 }
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Heading { Layout.fillWidth: true; text: "Borrow & return" }
                Text {
                    text: "Tools and electronics from the SPH makerspace."
                    font.family: Theme.font; font.pixelSize: 19
                    color: Theme.textDim
                }
            }
            Text {
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                text: Qt.formatTime(clock.now, "hh:mm")
                font.family: Theme.fontDisplay; font.pixelSize: 56
                font.letterSpacing: Theme.trackHeading
                color: Theme.text
                Timer { id: clock; property date now: new Date(); interval: 5000; running: screen.visible; repeat: true; triggeredOnStart: true; onTriggered: now = new Date() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20
            ModeTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: "Borrow"
                subtitle: "Tap your Legi, put the items on the tray, done."
                iconPath: Icons.boxOut
                tint: Theme.purple
                onClicked: screen.borrow()
            }
            ModeTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: "Return"
                subtitle: "No sign-in needed. Just put the items on the tray."
                iconPath: Icons.boxIn
                tint: Theme.orange
                onClicked: screen.giveBack()
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Icon { anchors.verticalCenter: parent.verticalCenter; path: Icons.contactless; size: 24; color: Theme.text; strokeWidth: 2.4 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Got your Legi? Tap it on the reader to start borrowing right away."
                font.family: Theme.font; font.pixelSize: 17
                color: Theme.text
            }
        }
    }
}
