pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtCore
import Kiosk

ApplicationWindow {
    id: win
    required property bool kioskMode
    required property int idleTimeout   // -1 = use the saved setting
    required property string screenshotDir

    property int currentPage: 0
    property bool startDark: true
    property string startStyle: "lab"
    property string startAccent: ""

    // The Pi's panel is 1024×600; the Mac window opens at the same size.
    width: 1024
    height: 600
    minimumWidth: 800
    minimumHeight: 480
    visible: true
    visibility: kioskMode ? Window.FullScreen : Window.Windowed
    flags: kioskMode ? (Qt.Window | Qt.FramelessWindowHint) : Qt.Window
    title: "Kiosk Lab"
    color: Theme.bg
    font.family: Theme.font

    // ---- Persistent preferences ----------------------------------------------
    Settings {
        id: prefs
        category: "ui"
        property string style: "lab"
        property bool dark: true
        property string accent: "#6C7BFF"
        property int idleTimeout: 45
        property bool showFps: false
        property real softDim: 0
    }
    Component.onCompleted: {
        Theme.style = prefs.style
        Theme.dark = prefs.dark
        startDark = prefs.dark
        startStyle = prefs.style
        // A saved accent from the other style falls back to this style's default.
        Theme.accent = Theme.accents.some(a => Qt.colorEqual(a, prefs.accent)) ? prefs.accent : Theme.accents[0]
        startAccent = Theme.accent.toString()
        Notify.showFps = prefs.showFps
        Notify.softDim = prefs.softDim
        IdleMonitor.timeout = idleTimeout >= 0 ? idleTimeout : prefs.idleTimeout
    }
    Connections {
        target: Theme
        function onStyleChanged() { prefs.style = Theme.style }
        function onDarkChanged() { prefs.dark = Theme.dark }
        function onAccentChanged() { prefs.accent = Theme.accent.toString() }
    }
    Connections {
        target: Notify
        function onShowFpsChanged() { prefs.showFps = Notify.showFps }
        function onSoftDimChanged() { prefs.softDim = Notify.softDim }
        function onNavigate(page) { win.currentPage = page }
        function onStartFlow() { flow.start() }
    }
    Connections {
        target: IdleMonitor
        function onTimeoutChanged() { if (win.idleTimeout < 0) prefs.idleTimeout = IdleMonitor.timeout }
        // Kiosk reset: whatever the last user left behind is cleared.
        function onIdleChanged() {
            if (!IdleMonitor.idle) return
            if (flow.open) flow.close()
            Session.signOut()
            Session.cancelPending()
            win.currentPage = 0
            Qt.inputMethod.hide()
            win.contentItem.forceActiveFocus()
        }
    }

    // A card tap works from anywhere (even the attract screen): jump to the login page.
    Connections {
        target: Rfid
        function onTapped(uid, type) {
            IdleMonitor.wake()
            if (flow.open) flow.close()
            win.currentPage = 4
            const r = Session.handleTap(uid, type)
            if (r === "signedIn" || r === "switched") Notify.success("Signed in as " + Session.name)
            else if (r === "signedOut") Notify.info("Signed out")
        }
    }

    Shortcut { sequences: [StandardKey.Quit]; onActivated: Qt.quit() }
    Shortcut {
        sequence: "F11"
        onActivated: win.visibility = win.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
    }

    // ---- Shell ---------------------------------------------------------------------
    component PageSlot: Loader {
        id: slot
        required property int index
        readonly property bool current: win.currentPage === index
        property bool visited: current
        onCurrentChanged: if (current) visited = true
        active: visited
        anchors.fill: parent
        opacity: current ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        transform: Translate {
            y: slot.current ? 0 : 18
            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        }
    }

    // Everything visible lives in `scene` (also what --screenshot grabs).
    Item {
        id: scene
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: Theme.bg }

        Item {
            id: appRoot
            property real shift: 0      // lifts the UI so a focused field clears the keyboard
            width: parent.width
            height: parent.height
            y: -shift
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            NavRail {
                id: rail
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                currentIndex: win.currentPage
                items: [
                    { label: "Home", icon: Icons.home },
                    { label: "Touch", icon: Icons.hand },
                    { label: "Controls", icon: Icons.sliders },
                    { label: "System", icon: Icons.cpu },
                    { label: "Card", icon: Icons.badge },
                    { label: "Settings", icon: Icons.gear }
                ]
                onSelected: (index) => win.currentPage = index
            }

            Item {
                id: pages
                anchors { left: rail.right; right: parent.right; top: parent.top; bottom: parent.bottom }
                PageSlot { id: slot0; index: 0; sourceComponent: HomePage {} }
                PageSlot { id: slot1; index: 1; sourceComponent: TouchLabPage {} }
                PageSlot { id: slot2; index: 2; sourceComponent: ControlsPage {} }
                PageSlot { id: slot3; index: 3; sourceComponent: SystemPage {} }
                PageSlot { id: slot4; index: 4; sourceComponent: BadgePage {} }
                    PageSlot { id: slot5; index: 5; sourceComponent: SettingsPage {} }
            }
        }

        GuidedFlow { id: flow; width: parent.width; height: parent.height }

        // ---- On-screen keyboard (optional module) -------------------------------------
        Loader {
            id: keyboard   // not sized: a sized Loader would stretch the panel to fill it
            source: "VirtualKeyboard.qml"
            onStatusChanged: if (status === Loader.Error) console.warn("Qt Virtual Keyboard not available – text fields will need a hardware keyboard")
        }

        Toast {}

        AttractScreen { anchors.fill: parent; active: IdleMonitor.idle }

        FpsMeter {
            anchors { top: parent.top; right: parent.right; margins: 10 }
            window: win
            visible: Notify.showFps
        }

        Rectangle { // software brightness
            anchors.fill: parent
            color: "black"
            opacity: Notify.softDim
            visible: opacity > 0.001
            enabled: false
        }
    }

    function updateKeyboardShift() {
        const kb = keyboard.item
        const f = win.activeFocusItem
        if (!kb || !kb.active || !f) { appRoot.shift = 0; return }
        // Measure in appRoot's own coordinates so the (animated) shift itself doesn't skew it.
        const bottom = f.mapToItem(appRoot, 0, f.height).y
        appRoot.shift = Math.max(0, bottom - (win.height - kb.height) + 20)
    }
    Connections {
        target: keyboard.item
        ignoreUnknownSignals: true
        function onActiveChanged() { win.updateKeyboardShift() }
        function onHeightChanged() { win.updateKeyboardShift() }
    }
    onActiveFocusItemChanged: updateKeyboardShift()

    ScreenshotTour {
        enabled: win.screenshotDir.length > 0
        dir: win.screenshotDir
        target: scene
        steps: [
            { name: "01-home",          run: () => win.currentPage = 0 },
            { name: "02-touch-multi",   run: () => win.currentPage = 1 },
            { name: "03-touch-gestures", run: () => slot1.item.tab = 1 },
            { name: "04-touch-accuracy", run: () => slot1.item.tab = 2 },
            { name: "05-controls",      run: () => win.currentPage = 2 },
            { name: "06-system",        run: () => win.currentPage = 3 },
            { name: "07-settings",      run: () => win.currentPage = 5 },
            { name: "07b-card-idle",    run: () => win.currentPage = 4 },
            { name: "07c-card-new",     run: () => Rfid.simulateTap("TO:UR:00:01", "MIFARE Classic 1K") },
            { name: "07d-card-welcome", run: () => { Session.enrol("Ada Lovelace") } },
            { name: "08-flow-code",     run: () => { Session.remove("TO:UR:00:01"); win.currentPage = 0; flow.start(); flow.code = "4821" } },
            { name: "09-flow-confirm",  run: () => { flow.code = "482193"; flow.step = 1 } },
            { name: "10-flow-done",     run: () => { flow.step = 2; flow.playDone() } },
            { name: "11-attract",       run: () => { flow.close(); IdleMonitor.goIdle() } },
            { name: "12-home-light",    run: () => { IdleMonitor.wake(); Theme.dark = false } },
            { name: "13-controls-light", run: () => win.currentPage = 2 },
            { name: "14-keyboard",      run: () => { win.currentPage = 2; Qt.callLater(() => win.focusFirstTextField()) } },
            // Same screens in the ETH SPH style
            { name: "s01-home",         run: () => { win.contentItem.forceActiveFocus(); Qt.inputMethod.hide(); Theme.setStyle("sph"); win.currentPage = 0 } },
            { name: "s02-touch",        run: () => { win.currentPage = 1; slot1.item.tab = 0 } },
            { name: "s03-accuracy",     run: () => slot1.item.tab = 2 },
            { name: "s04-controls",     run: () => win.currentPage = 2 },
            { name: "s05-system",       run: () => win.currentPage = 3 },
            { name: "s06-card",         run: () => win.currentPage = 4 },
            { name: "s07-settings",     run: () => win.currentPage = 5 },
            { name: "s08-flow-code",    run: () => { win.currentPage = 0; flow.start(); flow.code = "4821" } },
            { name: "s09-flow-confirm", run: () => { flow.code = "482193"; flow.step = 1 } },
            { name: "s10-flow-done",    run: () => { flow.step = 2; flow.playDone() } },
            { name: "s11-home-dark",    run: () => { flow.close(); Theme.dark = true } },
            { name: "s12-controls-dark", run: () => win.currentPage = 2 },
            { name: "s13-attract",      run: () => IdleMonitor.goIdle() }
        ]
        onDone: { Theme.style = win.startStyle; Theme.dark = win.startDark; Theme.accent = win.startAccent; Qt.quit() }
    }

    function focusFirstTextField() {
        const find = (item) => {
            if (item.hasOwnProperty("placeholderText") && item.visible) return item
            for (let i = 0; i < item.children.length; ++i) {
                const r = find(item.children[i]); if (r) return r
            }
            return null
        }
        const tf = find(slot2.item)
        if (tf) tf.forceActiveFocus()
    }

}
