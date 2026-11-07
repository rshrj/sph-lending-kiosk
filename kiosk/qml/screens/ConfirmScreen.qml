pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Kiosk

// Check & confirm, then commit the loan/return. Slide to confirm: a stray tap can't do it.
Item {
    id: screen
    property bool submitting: false
    signal succeeded(var result)
    signal failed()

    readonly property bool borrowing: Tray.mode === "borrow"
    readonly property var items: Tray.okEntries.map(e => e.item)

    function reset() { swipe.reset(); submitting = false }

    function submit() {
        if (submitting || items.length === 0) return
        submitting = true
        const ids = items.map(i => i.id)
        const done = r => {
            submitting = false
            console.info("flow: " + (borrowing ? "loan" : "return") + " of " + ids.length + " item(s) " + (r.ok ? "ok" : "refused (" + r.status + "): " + r.error))
            if (r.ok) { screen.succeeded(r.data); return }
            swipe.reset()
            Notify.error(r.error)
            if (r.problems && r.problems.length) Tray.applyProblems(r.problems)
            if (r.status === 409) { Tray.refreshItems(); screen.failed() }
        }
        if (borrowing) Backend.post("/loans", { user_id: Session.user.id, item_ids: ids }, done)
        else Backend.post("/returns", { item_ids: ids }, done)
    }

    ColumnLayout {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 24; bottom: parent.bottom; bottomMargin: 28 }
        width: 640
        spacing: 16

        Heading {
            Layout.alignment: Qt.AlignHCenter
            text: screen.borrowing ? "Check & borrow" : "Check & return"
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: screen.borrowing
                  ? "Borrowing as " + Session.name
                  : Fmt.plural(screen.items.length, "item") + " going back"
            font.family: Theme.font; font.pixelSize: 18
            color: Theme.textDim
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.preferredHeight: Math.min(list.contentHeight + 2 * 8 + 2 * Theme.strokeCard, 4 * 64 + 22)
            color: Theme.surface
            border.width: Theme.strokeCard
            border.color: Theme.cardOutline
            ListView {
                id: list
                anchors { fill: parent; leftMargin: 20; rightMargin: 20; topMargin: 8; bottomMargin: 8 }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: screen.items
                delegate: ItemRow {
                    required property var modelData
                    required property int index
                    readonly property bool late: !screen.borrowing && modelData.loan && Fmt.isOverdue(modelData.loan.due_at)
                    width: ListView.view.width
                    name: modelData.name
                    tag: modelData.asset_tag
                    tone: late ? "warn" : "ok"
                    detail: screen.borrowing ? Fmt.plural(modelData.loan_days, "day") + " loan"
                            : late ? "Overdue, " + Fmt.due(modelData.loan.due_at).replace("overdue", "late") : "Back on time"
                    trailing: screen.borrowing ? "Due " + Fmt.day(Fmt.dueFromNow(modelData.loan_days)) : (modelData.location || "")
                    last: index === screen.items.length - 1
                }
            }
        }

        Item { Layout.fillHeight: true }

        SwipeToConfirm {
            id: swipe
            Layout.fillWidth: true
            text: screen.submitting ? "Saving…" : (screen.borrowing ? "Slide to borrow " : "Slide to return ") + Fmt.plural(screen.items.length, "item")
            doneText: screen.submitting ? "Saving…" : "Done"
            onAccepted: screen.submit()
        }
    }
}
