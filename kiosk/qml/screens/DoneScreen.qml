pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Kiosk

// Receipt. Borrow: what's due when. Return: thanks, and where each item lives.
// Counts down, then the kiosk resets (and signs you out).
Item {
    id: screen
    property var result: null           // POST /loans or /returns response
    property string mode: "borrow"
    property string who: ""
    signal finished()

    readonly property bool borrowing: mode === "borrow"
    readonly property var lines: !result ? [] : (borrowing ? result.items : result.returned) || []  // mode and result change one at a time
    readonly property var firstDue: borrowing && lines.length ? lines.map(i => i.loan.due_at).sort()[0] : ""
    readonly property int lateCount: borrowing ? 0 : lines.filter(r => r.overdue).length

    function play() { mark.play(); ring.restart() }
    function stop() { ring.stop() }

    RowLayout {
        anchors { fill: parent; leftMargin: 48; rightMargin: 48; topMargin: 24; bottomMargin: 24 }
        spacing: 40

        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignVCenter
            spacing: 14
            SuccessMark { id: mark; size: 132 }
            Heading {
                Layout.fillWidth: true
                text: screen.borrowing ? "Enjoy, " + Fmt.firstName(screen.who) + "!" : "Thanks, all returned!"
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: screen.borrowing
                      ? (screen.lines.length === 1 ? "Bring it back by " : "Bring them back by ") + (screen.firstDue ? Fmt.day(screen.firstDue) : "") + "."
                      : screen.lateCount > 0 ? Fmt.plural(screen.lateCount, "item was", "items were") + " overdue. Please return on time next time."
                      : "Everything came back on time."
                wrapMode: Text.WordWrap
                font.family: Theme.font; font.pixelSize: 20
                color: Theme.text
            }
            Text {
                Layout.fillWidth: true
                visible: screen.borrowing
                text: "You've been signed out."
                font.family: Theme.font; font.pixelSize: 15
                color: Theme.textDim
            }
            RowLayout {
                Layout.topMargin: 10
                spacing: 18
                CountdownRing { id: ring; seconds: 10; onFinished: screen.finished() }
                KButton { text: "Done"; iconPath: Icons.check; implicitWidth: 170; onClicked: screen.finished() }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 8
            Text {
                text: screen.borrowing ? "Your loan" : "Please put each item back"
                font.family: Theme.fontDisplay; font.pixelSize: 20 * Theme.titleScale
                font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackLabel
                color: Theme.text
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: Theme.rule; color: Theme.ink }
            Repeater {
                model: screen.lines.slice(0, 5)
                delegate: ItemRow {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    name: modelData.name
                    tag: modelData.asset_tag || ""   // loan rows have a tag, return rows don't
                    tone: screen.borrowing || !modelData.overdue ? "ok" : "warn"
                    // Rows are typed by shape, not by `mode`: bindings can see the old mode for a frame.
                    readonly property string borrower: modelData.borrower ? modelData.borrower.name : ""
                    detail: !borrower ? "" : modelData.overdue ? "Was overdue (borrowed by " + borrower + ")" : "Borrowed by " + borrower
                    trailing: modelData.loan ? "Due " + Fmt.day(modelData.loan.due_at) : (screen.locations[modelData.item_id] || "")
                    last: index === Math.min(screen.lines.length, 5) - 1
                }
            }
            Text {
                visible: screen.lines.length > 5
                text: "and " + (screen.lines.length - 5) + " more"
                font.family: Theme.font; font.pixelSize: 15
                color: Theme.textDim
            }
        }
    }

    // /returns doesn't say where things live; the tray entries do.
    property var locations: ({})
}
