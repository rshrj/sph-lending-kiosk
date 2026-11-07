pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Kiosk

// Staff panel → "Teach the camera": collect training photos for the vision model.
// 1. clear the tray and photograph it empty, 2. pick a kind, 3. record: put one item on the
// tray, take your hand away, then keep moving or turning it. The server saves a photo each
// time the picture is still and the item has moved, boxed automatically (teach.py). Training
// happens elsewhere (backend/tools/train.py); a new model is picked up by the server itself.
Item {
    id: teach
    property bool active: false          // shown (drives the camera and the status refresh)
    signal back()

    property var kinds: []               // [{ label, names, count, in_model }]
    property var vision: ({})
    property bool hasBackground: false
    property string selected: ""
    property bool recording: false
    property bool inFlight: false
    property string message: ""
    property string tone: "muted"        // ok | warn | bad | muted
    property var box: null               // last found item, camera px
    property var frameSize: [1920, 1080]
    readonly property int goal: 30       // photos per kind worth aiming for

    implicitHeight: 440

    function refresh() {
        Backend.get("/teach/status", r => {
            if (!r.ok) { say(r.error, "bad"); return }
            kinds = r.data.kinds
            vision = r.data.vision
            hasBackground = r.data.background
            if (!selected && kinds.length) selected = kinds[0].label
            if (!message) say(hasBackground ? "Pick a kind, then Start." : "Clear the tray, then photograph it empty.", "muted")
        })
    }
    function say(text, t) { message = text; tone = t }
    function stop() { recording = false; box = null }
    function setCount(label, count) {
        kinds = kinds.map(k => k.label === label ? Object.assign({}, k, { count: count }) : k)
    }
    function reset() { stop(); kinds = []; selected = ""; message = ""; hasBackground = false }
    onActiveChanged: active ? refresh() : stop()

    function photographEmpty() {
        stop()
        say("Photographing the empty tray…", "muted")
        Backend.post("/teach/background", null, r => {
            if (!r.ok) { say(r.error, "bad"); return }
            console.info("flow: teach: empty tray photographed")
            hasBackground = true
            say("Empty tray saved. Pick a kind, then Start.", "ok")
        }, 10000)
    }

    function capture() {
        if (inFlight || !recording) return
        inFlight = true
        const label = selected
        Backend.post("/teach/capture", { label: label }, r => {
            inFlight = false
            if (!recording) return
            if (!r.ok) { stop(); say(r.error, "bad"); return }
            const d = r.data
            frameSize = d.image_size
            box = d.bbox
            setCount(label, d.count)
            const tones = { saved: "ok", same: "warn", moving: "muted", empty: "muted", too_big: "bad", no_background: "bad" }
            say(d.message, tones[d.status] || "muted")
            if (d.status === "saved" || d.status === "moving") IdleMonitor.wake()   // someone is working
            if (d.status === "no_background") { hasBackground = false; stop() }
        })
    }

    function undo() {
        Backend.post("/teach/undo", null, r => {
            if (!r.ok) { say(r.error, "bad"); return }
            setCount(r.data.label, r.data.count)
            say("Removed the last photo.", "muted")
        })
    }

    Timer { interval: 700; repeat: true; running: teach.recording && teach.active; onTriggered: teach.capture() }

    readonly property var current: kinds.find(k => k.label === selected) || null

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // ---- Left: camera + what the server says -----------------------------------
        ColumnLayout {
            Layout.preferredWidth: 500
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignTop
            spacing: 10

            CameraView {
                Layout.preferredWidth: 500
                Layout.preferredHeight: 281
                visible: Backend.cameraReady
                running: teach.active && Backend.cameraReady
                intervalMs: 120
                sourceSize: teach.frameSize
                detections: teach.recording && teach.box
                            ? [{ bbox: teach.box, tone: teach.tone === "ok" ? "ok" : teach.tone === "bad" ? "bad" : "warn",
                                 label: teach.current ? teach.current.names[0] : teach.selected }]
                            : []
            }
            Rectangle {
                Layout.preferredWidth: 500
                Layout.preferredHeight: 281
                visible: !Backend.cameraReady
                color: Theme.surface2
                border.width: Theme.strokeCard; border.color: Theme.ink
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; path: Icons.camera; size: 40; color: Theme.textDim }
                    Text { text: "No camera: teaching needs one"; font.family: Theme.font; font.pixelSize: 16; color: Theme.textDim }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    implicitWidth: 14; implicitHeight: 14
                    color: teach.tone === "ok" ? Theme.green : teach.tone === "warn" ? Theme.yellow
                         : teach.tone === "bad" ? Theme.red : Theme.surface3
                    border.width: 1.5; border.color: Theme.ink
                }
                Text {
                    Layout.fillWidth: true
                    text: teach.message
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold
                    color: teach.tone === "bad" ? Theme.red : Theme.text
                }
            }
            Text {
                Layout.fillWidth: true
                text: teach.vision.enabled
                      ? "Model: " + teach.vision.labels.length + " kinds" + (teach.vision.updated ? ", updated " + Fmt.day(new Date(teach.vision.updated * 1000)) : "")
                      : "No model yet. Train on a computer: backend/tools/train.py"
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: 13
                color: Theme.textFaint
            }
        }

        // ---- Right: steps, kinds, controls --------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            KButton {
                Layout.fillWidth: true
                compact: true
                kind: teach.hasBackground ? "secondary" : "primary"
                iconPath: teach.hasBackground ? Icons.check : Icons.camera
                text: teach.hasBackground ? "Empty tray: retake" : "1 · Photograph empty tray"
                enabled: Backend.cameraReady && !teach.recording
                onClicked: teach.photographEmpty()
            }

            Text {
                text: "2 · What are you teaching?"
                font.family: Theme.fontDisplay; font.pixelSize: 16 * Theme.titleScale
                font.capitalization: Theme.headingCaps; font.letterSpacing: Theme.trackLabel
                color: Theme.text
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: Theme.rule; color: Theme.ink }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: teach.kinds
                delegate: AbstractButton {
                    id: kindRow
                    required property var modelData
                    required property int index
                    readonly property bool chosen: modelData.label === teach.selected
                    width: ListView.view.width
                    implicitHeight: row.implicitHeight
                    focusPolicy: Qt.NoFocus
                    enabled: !teach.recording || chosen
                    onClicked: teach.selected = modelData.label
                    background: Rectangle { color: kindRow.chosen ? Theme.accentSoft : kindRow.pressed ? Theme.surface2 : "transparent" }
                    contentItem: ItemRow {
                        id: row
                        name: kindRow.modelData.names.join(" / ")
                        tag: kindRow.modelData.label
                        detail: kindRow.modelData.in_model ? "In the current model" : "Not in the model yet"
                        tone: kindRow.modelData.count >= teach.goal ? "ok" : kindRow.modelData.count > 0 ? "warn" : "muted"
                        markIcon: kindRow.modelData.count >= teach.goal ? Icons.check : Icons.camera
                        trailing: kindRow.modelData.count + " / " + teach.goal
                        last: kindRow.index === teach.kinds.length - 1
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                KButton {
                    Layout.fillWidth: true
                    kind: teach.recording ? "danger" : "primary"
                    iconPath: teach.recording ? Icons.close : Icons.sparkle
                    text: teach.recording ? "Stop" : "3 · Start"
                    enabled: teach.recording || (teach.hasBackground && teach.selected.length > 0 && Backend.cameraReady)
                    onClicked: {
                        if (teach.recording) { teach.stop(); teach.say("Stopped.", "muted"); return }
                        console.info("flow: teach: recording " + teach.selected)
                        teach.recording = true
                        teach.say("Put one on the tray and take your hand away.", "muted")
                    }
                }
                KButton { compact: true; kind: "secondary"; iconPath: Icons.backspace; text: "Undo"; onClicked: teach.undo() }
                KButton { compact: true; kind: "secondary"; iconPath: Icons.arrowLeft; text: "Back"; onClicked: { teach.stop(); teach.back() } }
            }
        }
    }
}
