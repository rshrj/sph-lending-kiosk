pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Kiosk

// What the signed-in user currently has, soonest due first.
Modal {
    id: modal
    title: "Your loans"
    panelWidth: 620

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 340)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Session.loans
        delegate: ItemRow {
            required property var modelData
            required property int index
            readonly property bool late: Fmt.isOverdue(modelData.loan.due_at)
            width: ListView.view.width
            name: modelData.name
            tag: modelData.asset_tag
            tone: late ? "bad" : "ok"
            detail: "Borrowed " + Fmt.day(modelData.loan.loaned_at)
            trailing: Fmt.cap(Fmt.due(modelData.loan.due_at))
            last: index === Session.loans.length - 1
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Returning something? Use Return on the start screen. No sign-in needed."
        wrapMode: Text.WordWrap
        font.family: Theme.font; font.pixelSize: 15
        color: Theme.textDim
    }
}
