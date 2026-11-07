import QtQuick
import QtQuick.Layouts
import Kiosk

// The camera missed something? Type the number from its label (DAIM-007 → 7).
Modal {
    id: modal
    title: "Add by hand"
    panelWidth: 640
    property string digits: ""
    property string error: ""
    property bool looking: false
    // Label format: DAIM-001 … DAIM-999 (the backend also accepts unpadded numbers).
    readonly property string prefix: "DAIM-"
    readonly property int tagDigits: 3
    readonly property string padded: ("000000" + digits).slice(-tagDigits)
    readonly property string tag: prefix + padded

    function openFresh() { digits = ""; error = ""; looking = false; open = true }
    function lookup() {
        if (!digits.length || looking) return
        looking = true
        error = ""
        const tag = modal.tag
        Backend.get("/items/by-tag/" + tag, r => {
            looking = false
            if (!r.ok) { error = r.status === 404 ? "There's no item " + tag + "." : r.error; digits = ""; return }
            if (Tray.addManual(r.data)) Notify.success("Added " + r.data.name)
            else Notify.info(r.data.name + " is already on the list")
            modal.close()
        })
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 28
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: "Type the number from the item's label."
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
                Row {
                    anchors.centerIn: parent
                    Text { text: modal.prefix; font.family: Theme.font; font.pixelSize: 36; font.weight: Font.Bold; color: Theme.textFaint }
                    Text {
                        text: modal.padded
                        font.family: Theme.font; font.pixelSize: 36; font.weight: Font.Bold
                        color: modal.digits.length ? Theme.text : Theme.textFaint
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: modal.error.length ? modal.error : modal.looking ? "Looking it up…" : "e.g. 7 for " + modal.prefix + "007"
                wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 15; font.weight: modal.error.length ? Font.Bold : Font.Normal
                color: modal.error.length ? Theme.red : Theme.textDim
            }
        }
        Keypad {
            keyWidth: 92
            keyHeight: 60
            acceptEnabled: modal.digits.length > 0 && !modal.looking
            onDigit: (d) => { modal.error = ""; if (modal.digits.length < modal.tagDigits) modal.digits = (modal.digits + d).replace(/^0+/, "") }
            onBackspace: modal.digits = modal.digits.slice(0, -1)
            onAccept: modal.lookup()
        }
    }
}
