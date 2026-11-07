import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../qml"

// Standalone SPH theme preview at the kiosk resolution.
//   qml preview/Preview.qml                         interactive (tap things)
//   qml preview/Preview.qml -- --page specimen --dark --out /tmp/x.png
Window {
    id: win
    width: 1024; height: 600
    visible: true
    title: "SPH theme preview"
    color: Theme.bg

    readonly property var args: Qt.application.arguments
    function arg(name, dflt) { const i = args.indexOf(name); return i >= 0 && i + 1 < args.length ? args[i + 1] : dflt }
    property string page: arg("--page", "home")

    FontLoader { source: "../fonts/ProximaNova-Regular.ttf" }
    FontLoader { source: "../fonts/ProximaNova-Bold.ttf" }
    FontLoader { source: "../fonts/AlternateGothicNo2Pro-Regular.ttf" }

    Component.onCompleted: {
        Theme.dark = args.indexOf("--dark") >= 0
        const out = arg("--out", "")
        if (out) shot.start()
    }
    Timer {
        id: shot; interval: 600
        onTriggered: content.grabToImage(r => { r.saveToFile(win.arg("--out", "")); Qt.quit() })
    }

    Item {
        id: content
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: Theme.bg }
        Loader { anchors.fill: parent; sourceComponent: win.page === "specimen" ? specimen : home }
    }

    // ── Mock kiosk home screen in SPH style ───────────────────────────────
    Component {
        id: home
        ColumnLayout {
            spacing: 0
            Rectangle {   // header: purple, black logo, uppercase nav
                Layout.fillWidth: true; Layout.preferredHeight: Theme.headerHeight
                color: Theme.purple
                Image { source: "../assets/sph-logo.svg"; sourceSize.height: 34; anchors { left: parent.left; leftMargin: Theme.pad; verticalCenter: parent.verticalCenter } }
                Row {
                    anchors { right: parent.right; rightMargin: Theme.pad; verticalCenter: parent.verticalCenter }
                    spacing: 28
                    Repeater { model: ["Makerspace", "Locations", "Opening hours", "14:32"]
                        Text { text: modelData.toUpperCase(); font.family: Theme.fontDisplay; font.pixelSize: 20; font.letterSpacing: Theme.trackLabel; color: Theme.ink } }
                }
            }
            ColorBand { Layout.fillWidth: true; color: Theme.yellow; title: "“Try &” – event on 6 & 7 November"; action: "Explore"; padding: 20 }
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                ColumnLayout {
                    anchors { fill: parent; margins: Theme.pad; topMargin: 22; bottomMargin: 18 }
                    spacing: 14
                    Row {
                        spacing: 14
                        Text { text: "WHAT DO YOU WANT TO"; font.family: Theme.fontDisplay; font.pixelSize: Theme.fsH1; font.letterSpacing: Theme.trackDisplay; color: Theme.text }
                        BrushText { text: "do today?"; brush: "purple"; font.pixelSize: Theme.fsH1 }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        spacing: 20
                        OutlineCard { Layout.fillWidth: true; Layout.fillHeight: true; title: "Makerspace & Lab"; body: "Book a machine, check in for a workshop, or borrow tools for your project."; action: "Use the makerspace" }
                        OutlineCard { Layout.fillWidth: true; Layout.fillHeight: true; title: "Project support"; body: "Seven coaches from diverse backgrounds help with project development and skills."; action: "Get support" }
                        OutlineCard { Layout.fillWidth: true; Layout.fillHeight: true; title: "Events & workshops"; body: "Learn new topics, celebrate the community, and get inspired."; action: "Browse events" }
                    }
                }
            }
            ColorBand { Layout.fillWidth: true; color: Theme.orange; title: "Not sure where to start? Tap your ETH card"; chevron: true; padding: 20 }
        }
    }

    // ── Specimen: palette, type ramp, components ──────────────────────────
    Component {
        id: specimen
        RowLayout {
            spacing: 0
            Column {   // palette
                Layout.preferredWidth: 260; Layout.fillHeight: true
                Repeater {
                    model: [["Purple · primary", Theme.purple], ["Yellow · secondary", Theme.yellow], ["Green · success", Theme.green],
                            ["Cyan · info", Theme.cyan], ["Orange · CTA", Theme.orange], ["Red · danger", Theme.red], ["Ink", Theme.ink]]
                    Rectangle {
                        width: 260; height: 600 / 7; color: modelData[1]
                        readonly property color fg: index === 6 ? Theme.paper : Theme.ink
                        Column { anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Text { text: modelData[0].toUpperCase(); font.family: Theme.fontDisplay; font.pixelSize: 24; font.letterSpacing: Theme.trackDisplay; color: parent.parent.fg }
                            Text { text: String(modelData[1]).toUpperCase(); font.family: Theme.font; font.pixelSize: 14; color: parent.parent.fg } }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: Theme.pad
                spacing: 6
                Text { text: "SPH 96"; font.family: Theme.fontDisplay; font.pixelSize: Theme.fsDisplay; font.letterSpacing: Theme.trackDisplay; lineHeight: 0.9; color: Theme.text }
                Text { text: "PAGE TITLE · H1 48"; font.family: Theme.fontDisplay; font.pixelSize: Theme.fsH1; font.letterSpacing: Theme.trackDisplay; color: Theme.text }
                BrushText { text: "Section headline · H2 32"; brush: "yellow"; font.pixelSize: Theme.fsH2 }
                Text { text: "CARD / ROW TITLE · H3 26"; font.family: Theme.fontDisplay; font.pixelSize: Theme.fsH3; font.letterSpacing: Theme.trackDisplay * 0.6; color: Theme.text }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; lineHeight: Theme.lineHeightBody
                    text: "Body 18 · Proxima Nova Regular. Welcome to the Student Project House, a space for the creative community at ETH. <b>Bold 700 for emphasis.</b>"
                    font.family: Theme.font; font.pixelSize: Theme.fsBody; color: Theme.text }
                Text { text: "Small 14 · secondary info, timestamps, captions"; font.family: Theme.font; font.pixelSize: Theme.fsSmall; color: Theme.textDim }
                Item { Layout.preferredHeight: 6 }
                Row { spacing: 18
                    SkewButton { text: "Explore" }
                    SkewButton { text: "Check in"; filled: true; fill: Theme.green }
                    SkewButton { text: "Book"; filled: true; fill: Theme.purple }
                    TextLink { text: "Get support"; anchors.verticalCenter: parent.verticalCenter } }
                Item { Layout.preferredHeight: 4 }
                ListRow { Layout.fillWidth: true; meta: "16 Oct 2026"; title: "Building & makerspace open studio" }
                ListRow { Layout.fillWidth: true; topRule: false; title: "Materials shop" }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
