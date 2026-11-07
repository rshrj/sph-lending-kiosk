import QtQuick
import QtQuick.Controls
import Kiosk

// One item in a list: status square · name + tag · status line · optional remove (×).
// tone: "ok" | "warn" | "bad" | "muted"
Item {
    id: row
    property string name
    property string tag
    property string detail
    property string tone: "ok"
    property bool removable: false
    property bool last: false
    property string trailing: ""     // right-aligned text instead of the × (e.g. a due date)
    signal removeClicked()

    readonly property color toneColor: tone === "ok" ? Theme.green : tone === "warn" ? Theme.yellow
                                     : tone === "bad" ? Theme.red : Theme.surface3
    implicitWidth: 320
    implicitHeight: Math.max(64, textCol.implicitHeight + 18)

    Rectangle {
        id: mark
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: 28; height: 28
        color: row.toneColor
        border.width: 2; border.color: Theme.ink
        Icon {
            anchors.centerIn: parent
            path: row.tone === "ok" ? Icons.check : row.tone === "bad" ? Icons.close : row.tone === "warn" ? Icons.clock : Icons.qr
            size: 16; strokeWidth: 2.6
            color: Theme.ink
        }
    }

    Column {
        id: textCol
        anchors { left: mark.right; leftMargin: 14; right: side.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 2
        Row {
            width: parent.width
            spacing: 8
            Text {
                id: nameText
                width: Math.min(implicitWidth, parent.width - tagText.implicitWidth - 8)
                text: row.name
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold
                color: Theme.text
            }
            Text {
                id: tagText
                anchors.baseline: nameText.baseline
                text: row.tag
                font.family: Theme.font; font.pixelSize: 13
                color: Theme.textFaint
            }
        }
        Text {
            width: parent.width
            visible: row.detail.length > 0
            text: row.detail
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Theme.font; font.pixelSize: 14
            color: row.tone === "bad" ? Theme.red : Theme.textDim
        }
    }

    Item {
        id: side
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: row.removable ? 48 : trailingText.implicitWidth
        height: 48
        AbstractButton {
            id: removeBtn
            anchors.fill: parent
            visible: row.removable
            focusPolicy: Qt.NoFocus
            onClicked: row.removeClicked()
            contentItem: Item {}
            background: Item {
                Icon { anchors.centerIn: parent; path: Icons.close; size: 20; color: removeBtn.pressed ? Theme.red : Theme.textFaint }
            }
        }
        Text {
            id: trailingText
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: !row.removable
            text: row.trailing
            font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Bold
            color: Theme.text
        }
    }

    Rectangle {
        visible: !row.last
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Theme.rule
        color: Theme.ink
        opacity: 0.85
    }
}
