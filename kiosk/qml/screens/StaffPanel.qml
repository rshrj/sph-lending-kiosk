pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Kiosk

// Hidden staff panel (long-press the SPH logo): health, open loans, demo reset, quit.
// Locked behind the staff PIN (backend/deploy.sh pin); the backend checks it and also
// requires it (X-Staff-Pin) for the loans list and the reset. Closing it locks it again.
Modal {
    id: modal
    title: unlocked ? "Staff" : "Staff access"
    panelWidth: unlocked ? 900 : 620
    property var openLoans: []
    property bool unlocked: false
    property string digits: ""
    property string error: ""
    property bool checking: false
    readonly property int maxDigits: 8
    signal resetDone()

    function openFresh() { lock(); open = true }
    function lock() {
        unlocked = false; digits = ""; error = ""; checking = false
        openLoans = []
        Backend.staffPin = ""
    }
    function unlock(pin) {
        if (!pin.length || checking) return
        checking = true
        error = ""
        Backend.post("/staff/unlock", { pin: pin }, r => {
            checking = false
            digits = ""
            console.info("flow: staff unlock " + (r.ok ? "ok" : "failed (" + r.status + ")"))
            if (!r.ok) { error = r.error; return }
            Backend.staffPin = pin
            unlocked = true
            refresh()
        })
    }
    function refresh() {
        Backend.checkHealth()
        Backend.get("/loans", r => { if (r.ok) modal.openLoans = r.data })
    }
    onClosed: lock()

    // ---- locked: PIN pad -----------------------------------------------------------
    RowLayout {
        visible: !modal.unlocked
        Layout.fillWidth: true
        spacing: 28
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: "Enter the staff PIN."
                wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 18
                color: Theme.textDim
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                implicitHeight: 74
                color: Theme.surface2
                border.width: 3
                border.color: Theme.ink
                Text {
                    anchors.centerIn: parent
                    text: modal.digits.length ? "\u25CF".repeat(modal.digits.length) : "PIN"
                    font.family: Theme.font; font.pixelSize: 30; font.weight: Font.Bold
                    font.letterSpacing: 6
                    color: modal.digits.length ? Theme.text : Theme.textFaint
                }
            }
            Text {
                Layout.fillWidth: true
                text: modal.error.length ? modal.error : modal.checking ? "Checking…" : " "
                wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 15; font.weight: modal.error.length ? Font.Bold : Font.Normal
                color: modal.error.length ? Theme.red : Theme.textDim
            }
        }
        Keypad {
            keyWidth: 88
            keyHeight: 58
            acceptEnabled: modal.digits.length >= 4 && !modal.checking
            onDigit: (d) => { modal.error = ""; if (modal.digits.length < modal.maxDigits) modal.digits += d }
            onBackspace: modal.digits = modal.digits.slice(0, -1)
            onAccept: modal.unlock(modal.digits)
        }
    }

    component Status: RowLayout {
        id: st
        property string label
        property string value
        property bool good: true
        Layout.fillWidth: true
        spacing: 10
        Rectangle { implicitWidth: 12; implicitHeight: 12; radius: 6; color: st.good ? Theme.green : Theme.red; border.width: 1.5; border.color: Theme.ink }
        Text { text: st.label; Layout.preferredWidth: 110; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.text }
        Text { text: st.value; Layout.fillWidth: true; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: 15; color: Theme.textDim }
    }

    // ---- unlocked -------------------------------------------------------------------
    RowLayout {
        visible: modal.unlocked
        Layout.fillWidth: true
        spacing: 28

        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignTop
            spacing: 10
            Status { label: "Server"; good: Backend.online; value: (Backend.online ? "online · " : "offline · ") + Backend.baseUrl }
            Status { label: "Camera"; good: Backend.cameraReady; value: Backend.cameraReady ? Backend.cameraDevice : (Backend.cameraDevice || "n/a") + " · not ready" }
            Status { label: "Card reader"; good: Rfid.ready; value: Rfid.ready ? Rfid.readerInfo : Rfid.status }
            Status { label: "Vision"; good: Tray.visionEnabled; value: Tray.visionEnabled ? "model on" : "stub (QR labels only)" }
            Item { implicitHeight: 6 }
            HoldButton {
                Layout.fillWidth: true
                text: "Hold to reset the demo"
                iconPath: Icons.refresh
                tint: Theme.orange
                onTriggered: Backend.post("/admin/reset", null, r => {
                    if (!r.ok) { Notify.error(r.error); return }
                    Notify.success("Inventory reset: all items back, loans cleared")
                    modal.refresh()
                    modal.resetDone()
                })
            }
            HoldButton {
                Layout.fillWidth: true
                text: "Hold to quit the kiosk"
                iconPath: Icons.power
                onTriggered: { console.info("flow: staff quit the kiosk"); Backend.staffPin = ""; Qt.quit() }
            }
            Text {
                text: "SPH Kiosk " + Qt.application.version
                font.family: Theme.font; font.pixelSize: 13
                color: Theme.textFaint
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 6
            Text {
                text: "Open loans (" + modal.openLoans.length + ")"
                font.family: Theme.fontDisplay; font.pixelSize: 18 * Theme.titleScale
                font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackLabel
                color: Theme.text
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: Theme.rule; color: Theme.ink }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: modal.openLoans
                delegate: ItemRow {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    name: modelData.item_name
                    tag: modelData.asset_tag
                    detail: modelData.user_name
                    tone: modelData.overdue ? "bad" : "ok"
                    trailing: Fmt.cap(Fmt.due(modelData.due_at))
                    last: index === modal.openLoans.length - 1
                }
                Text {
                    visible: modal.openLoans.length === 0
                    anchors { left: parent.left; top: parent.top; topMargin: 12 }
                    text: "Nothing on loan."
                    font.family: Theme.font; font.pixelSize: 15
                    color: Theme.textFaint
                }
            }
        }
    }
}
