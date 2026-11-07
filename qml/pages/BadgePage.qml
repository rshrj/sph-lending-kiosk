pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Kiosk

// RC522 card login test: tap → sign in, unknown card → enrol, tap again → sign out.
Item {
    id: page

    readonly property string mode: Session.pendingUid ? "enrol" : Session.signedIn ? "welcome" : "idle"
    property date now: new Date()
    Timer { interval: 1000; running: page.visible && Session.signedIn; repeat: true; onTriggered: page.now = new Date() }

    function elapsed() {
        const s = Math.max(0, Math.floor((page.now - Session.since) / 1000))
        const m = Math.floor(s / 60)
        return m > 0 ? m + " min " + (s % 60) + " s" : s + " s"
    }

    RowLayout {
        anchors { fill: parent; margins: Theme.pad }
        spacing: Theme.gap

        // ---- Main stage ------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface
            radius: Theme.radiusL
            border.width: 1
            border.color: Theme.border

            // Idle: prompt
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                opacity: page.mode === "idle" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                TapPrompt { Layout.alignment: Qt.AlignHCenter; active: page.mode === "idle" }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 12
                    text: "Tap your card to sign in"
                    font.family: Theme.fontDisplay; font.pixelSize: 30 * Theme.titleScale; font.weight: Theme.headingWeight
                    font.letterSpacing: Theme.trackHeading; font.capitalization: Theme.headingCaps
                    color: Theme.text
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Hold the card or key fob flat against the reader"
                    font.family: Theme.font; font.pixelSize: 16
                    color: Theme.textDim
                }
            }

            // Unknown card: enrol
            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 64, 440)
                spacing: 14
                opacity: page.mode === "enrol" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 72; height: 72; radius: Theme.sph ? 0 : 24
                    color: Theme.withAlpha(Theme.warning, 0.16)
                    Icon { anchors.centerIn: parent; path: Icons.userPlus; color: Theme.warning; size: 34 }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "New card"
                    font.family: Theme.fontDisplay; font.pixelSize: 30 * Theme.titleScale; font.weight: Theme.headingWeight
                    font.letterSpacing: Theme.trackHeading; font.capitalization: Theme.headingCaps
                    color: Theme.text
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Session.pendingUid + (Session.pendingType ? "  ·  " + Session.pendingType : "")
                    font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    color: Theme.textDim
                }
                TextField {
                    id: nameField
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    implicitHeight: Theme.touchMin
                    placeholderText: "Name for this card"
                    placeholderTextColor: Theme.textFaint
                    font.family: Theme.font; font.pixelSize: 18
                    color: Theme.text
                    leftPadding: 16
                    inputMethodHints: Qt.ImhNoPredictiveText
                    background: Rectangle {
                        radius: Theme.radiusM
                        color: Theme.surface2
                        border.width: nameField.activeFocus ? 2 : 1
                        border.color: nameField.activeFocus ? Theme.accent : Theme.border
                    }
                    onAccepted: enrolButton.clicked()
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    KButton {
                        Layout.fillWidth: true
                        kind: "secondary"; text: "Cancel"
                        onClicked: { nameField.text = ""; nameField.focus = false; Session.cancelPending() }
                    }
                    KButton {
                        id: enrolButton
                        Layout.fillWidth: true
                        text: "Enrol & sign in"; iconPath: Icons.check
                        enabled: nameField.text.trim().length > 0
                        onClicked: {
                            Session.enrol(nameField.text)
                            Notify.success("Card enrolled for " + Session.name)
                            nameField.text = ""
                            nameField.focus = false
                        }
                    }
                }
            }

            // Signed in
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                opacity: page.mode === "welcome" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }

                Rectangle {
                    id: avatar
                    Layout.alignment: Qt.AlignHCenter
                    width: 116; height: 116; radius: 58
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.sph ? Theme.accent : Qt.lighter(Theme.accent, 1.3) }
                        GradientStop { position: 1; color: Theme.sph ? Theme.accent : Qt.darker(Theme.accent, 1.3) }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: Session.initials(Session.name || "?")
                        font.family: Theme.fontDisplay; font.pixelSize: 42 * Theme.titleScale; font.weight: Theme.headingWeight
                        color: Theme.accentText
                    }
                    // pop when someone signs in
                    Connections {
                        target: Session
                        function onUidChanged() { if (Session.signedIn) pop.restart() }
                    }
                    SequentialAnimation on scale {
                        id: pop
                        running: false
                        NumberAnimation { from: 0.6; to: 1.08; duration: 260; easing.type: Easing.OutCubic }
                        NumberAnimation { to: 1.0; duration: 180 }
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    text: "Welcome, " + Session.name.split(" ")[0]
                    font.family: Theme.fontDisplay; font.pixelSize: 34 * Theme.titleScale; font.weight: Theme.headingWeight
                    font.letterSpacing: Theme.trackHeading; font.capitalization: Theme.headingCaps
                    color: Theme.text
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Signed in at " + Qt.formatTime(Session.since, "hh:mm") + "  ·  " + page.elapsed()
                    font.family: Theme.font; font.pixelSize: 16
                    font.features: { "tnum": 1 }
                    color: Theme.textDim
                }
                KButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 14
                    implicitWidth: 200
                    kind: "secondary"; text: "Sign out"; iconPath: Icons.logout
                    onClicked: { Session.signOut(); Notify.info("Signed out") }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Tap the same card again to sign out · another card to switch user"
                    font.family: Theme.font; font.pixelSize: 13
                    color: Theme.textFaint
                }
            }
        }

        // ---- Side panel ---------------------------------------------------------------
        ColumnLayout {
            Layout.preferredWidth: 310
            Layout.maximumWidth: 310
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: Theme.gap

            Card {
                Layout.fillWidth: true
                padding: 16
                title: "Reader"
                subtitle: Rfid.ready ? Rfid.readerInfo : Rfid.status
                iconPath: Icons.contactless

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: Rfid.cardPresent ? Theme.accent : Rfid.ready ? Theme.success : Theme.danger
                        SequentialAnimation on opacity {
                            running: Rfid.cardPresent; loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 300 }
                            NumberAnimation { to: 1; duration: 300 }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Rfid.cardPresent ? "Card in field" : Rfid.ready ? "Ready" : (Rfid.hardwareSupport ? "Not connected" : "Simulator only")
                        font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        text: Rfid.readCount + " reads"
                        font.family: Theme.font; font.pixelSize: 13
                        color: Theme.textDim
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: Rfid.lastUid.length > 0
                    text: "Last: " + Rfid.lastUid + "\n" + Rfid.lastType
                    font.family: Theme.font; font.pixelSize: 13
                    font.features: { "tnum": 1 }
                    color: Theme.textDim
                    lineHeight: 1.2
                }
                RowLayout { // simulator (always useful on the Mac; hidden once real hardware answers)
                    visible: !Rfid.ready
                    Layout.fillWidth: true
                    spacing: 8
                    KButton { Layout.fillWidth: true; compact: true; kind: "secondary"; text: "Sim card A"; onClicked: Rfid.simulateTap("DE:AD:BE:EF", "MIFARE Classic 1K") }
                    KButton { Layout.fillWidth: true; compact: true; kind: "secondary"; text: "Sim card B"; onClicked: Rfid.simulateTap("04:A2:7C:1B", "MIFARE Classic 1K") }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 16
                title: "Enrolled cards"
                subtitle: Session.userList.length === 0 ? "None yet — tap an unknown card" : Session.userList.length + " card(s)"
                iconPath: Icons.badge

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: Session.userList
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        id: entry
                        required property var modelData
                        width: ListView.view.width
                        height: 54
                        radius: Theme.radiusS
                        color: Session.uid === modelData.uid ? Theme.accentSoft : Theme.surface2
                        Rectangle {
                            id: mini
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            width: 34; height: 34; radius: 17
                            color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: Session.initials(entry.modelData.name)
                                font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Bold
                                color: Theme.accentText
                            }
                        }
                        Column {
                            anchors { left: mini.right; leftMargin: 10; right: remove.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            Text { width: parent.width; elide: Text.ElideRight; text: entry.modelData.name; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.text }
                            Text { text: entry.modelData.uid; font.family: Theme.font; font.pixelSize: 11; color: Theme.textDim }
                        }
                        AbstractButton {
                            id: remove
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 48; height: 48
                            focusPolicy: Qt.NoFocus
                            contentItem: Icon { path: Icons.close; size: 18; color: remove.pressed ? Theme.danger : Theme.textFaint }
                            leftPadding: 15; topPadding: 15
                            onClicked: { Notify.info("Removed " + entry.modelData.name); Session.remove(entry.modelData.uid) }
                        }
                    }
                }
            }
        }
    }
}
