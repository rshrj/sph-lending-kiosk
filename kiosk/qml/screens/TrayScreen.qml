pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Kiosk

// Put items on the tray: live camera on the left, what we recognised on the right.
// Without a camera, a simulator panel stands in (tap items to "place" them).
Item {
    id: screen
    property bool live: false          // this screen is showing (drives camera + scanning)
    signal proceed()
    signal addByHand()
    signal showLoans()

    readonly property bool borrowing: Tray.mode === "borrow"
    readonly property bool cameraMode: Backend.cameraReady
    readonly property var rows: Tray.entries.map(e => {
        const s = Tray.status(e)
        return { key: e.key, name: e.item.name, tag: e.item.asset_tag, detail: s.text, tone: s.tone }
    }).concat(Tray.unknown.map(u => ({
        key: u.key, name: "Unknown label", tag: u.code, detail: "Not part of the SPH inventory, ignored.", tone: "muted"
    })))

    RowLayout {
        anchors { fill: parent; margins: Theme.pad }
        spacing: Theme.pad

        // ---- Left: camera / simulator + instructions -----------------------------
        ColumnLayout {
            Layout.preferredWidth: 560
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 14

            CameraView {
                Layout.preferredWidth: 560
                Layout.preferredHeight: 315
                visible: screen.cameraMode
                running: screen.live && screen.cameraMode
                detections: Tray.detections
                sourceSize: Tray.frameSize
            }

            Rectangle { // simulator
                id: sim
                Layout.preferredWidth: 560
                Layout.preferredHeight: 315
                visible: !screen.cameraMode
                color: Theme.surface2
                border.width: Theme.strokeCard
                border.color: Theme.ink
                property var items: []
                function load() { Backend.get("/items", r => { if (r.ok) sim.items = r.data }) }
                onVisibleChanged: if (visible && screen.live) load()
                Connections { target: screen; function onLiveChanged() { if (screen.live && sim.visible) sim.load() } }

                ColumnLayout {
                    anchors { fill: parent; margins: 16 }
                    spacing: 10
                    Row {
                        spacing: 10
                        Icon { anchors.verticalCenter: parent.verticalCenter; path: Icons.camera; size: 22; color: Theme.text }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Backend.online ? "No camera · tap items to put them on the tray" : "Waiting for the inventory server…"
                            font.family: Theme.fontDisplay; font.pixelSize: 17 * Theme.titleScale
                            font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackLabel
                            color: Theme.text
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8
                        Repeater {
                            model: sim.items
                            delegate: AbstractButton {
                                id: chip
                                required property var modelData
                                readonly property bool placed: Tray.entries.some(e => e.item.id === chip.modelData.id)
                                Layout.fillWidth: true
                                implicitHeight: 52
                                focusPolicy: Qt.NoFocus
                                onClicked: {
                                    if (placed) { Tray.remove("item:" + modelData.id); return }
                                    const id = modelData.id
                                    Backend.get("/items/" + id, r => r.ok ? Tray.addManual(r.data) : Notify.error(r.error))
                                }
                                background: Rectangle {
                                    color: chip.pressed ? Theme.surface3 : chip.placed ? Theme.green : Theme.paper
                                    border.width: 2; border.color: Theme.ink
                                }
                                contentItem: Column {
                                    leftPadding: 12
                                    topPadding: 7
                                    Text { text: chip.modelData.name; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.ink; width: 240; elide: Text.ElideRight }
                                    Text {
                                        text: chip.modelData.asset_tag + (chip.modelData.state === "loaned" ? " · on loan" : "")
                                        font.family: Theme.font; font.pixelSize: 12; color: Theme.ink; opacity: 0.7
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Heading { level: 2; text: screen.borrowing ? "Put what you're taking on the tray" : "Put your returns on the tray"; Layout.fillWidth: true; elide: Text.ElideRight }
            Text {
                Layout.fillWidth: true
                text: "QR labels facing up. Items appear on the right as they're recognised."
                wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 17
                color: Theme.textDim
            }
            Item { Layout.fillHeight: true }
        }

        // ---- Right: who + what's on the tray + actions ------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // Borrowing: who you are and what you already have
            Rectangle {
                Layout.fillWidth: true
                visible: screen.borrowing && Session.signedIn
                implicitHeight: 74
                color: Theme.purpleLight
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 6 }
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Heading { level: 3; text: "Hi " + Session.firstName; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text {
                            Layout.fillWidth: true
                            text: Session.loans.length === 0 ? "Nothing on loan right now"
                                  : Fmt.plural(Session.loans.length, "item") + " on loan" + (Session.overdueCount > 0 ? " · " + Session.overdueCount + " overdue" : "")
                            elide: Text.ElideRight
                            font.family: Theme.font; font.pixelSize: 15
                            font.weight: Session.overdueCount > 0 ? Font.Bold : Font.Normal
                            color: Theme.ink
                        }
                    }
                    KButton {
                        visible: Session.loans.length > 0
                        compact: true; kind: "secondary"
                        text: "My loans"
                        onClicked: screen.showLoans()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Text {
                    Layout.fillWidth: true
                    text: "On the tray"
                    font.family: Theme.fontDisplay; font.pixelSize: 20 * Theme.titleScale
                    font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackLabel
                    color: Theme.text
                }
                Row {
                    spacing: 6
                    visible: screen.cameraMode
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; radius: 5
                        color: Theme.green
                        SequentialAnimation on opacity {
                            running: screen.live && screen.cameraMode; loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 600 }
                            NumberAnimation { to: 1; duration: 600 }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Scanning"
                        font.family: Theme.font; font.pixelSize: 14
                        color: Theme.textDim
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: Theme.rule; color: Theme.ink }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: screen.rows
                boundsBehavior: Flickable.StopAtBounds
                delegate: ItemRow {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    name: modelData.name
                    tag: modelData.tag
                    detail: modelData.detail
                    tone: modelData.tone
                    removable: true
                    last: index === screen.rows.length - 1
                    onRemoveClicked: Tray.remove(modelData.key)
                }
                Text {
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 20 }
                    visible: screen.rows.length === 0
                    text: screen.cameraMode ? "Nothing recognised yet." : "Nothing on the tray yet."
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.font; font.pixelSize: 16
                    color: Theme.textFaint
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                KButton {
                    compact: true
                    kind: "secondary"
                    iconPath: Icons.plus
                    text: "Add by hand"
                    onClicked: screen.addByHand()
                }
                Item { Layout.fillWidth: true }
                KButton {
                    enabled: Tray.canContinue
                    iconPath: Icons.arrowRight
                    text: Tray.readyCount > 0 ? "Continue (" + Tray.readyCount + ")" : "Continue"
                    onClicked: screen.proceed()
                }
            }
        }
    }
}
