pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Kiosk

// SPH lending kiosk. One linear flow per transaction:
//   borrow:  start → sign in → tray → confirm → done
//   return:  start → tray → confirm → done           (no sign-in needed)
// A card tap anywhere signs in and starts borrowing. Idle → attract screen + full reset.
// Public kiosk: idle (60 s) or a session older than maxSessionSec signs out; the staff panel
// needs a PIN and locks again on close/idle; the screen never shows Legi numbers.
ApplicationWindow {
    id: win
    required property bool kioskMode
    required property int idleTimeout
    required property string screenshotDir
    required property string tour          // screenshot tour: "full" | "camera"
    required property string tourStaffPin  // screenshot tour only ($KIOSK_STAFF_PIN)
    readonly property int maxSessionSec: 300   // hard cap on a signed-in session, whatever the activity

    property string screen: "start"     // start | signin | tray | confirm | done
    property string mode: "borrow"      // borrow | return

    readonly property var steps: mode === "borrow" ? ["Sign in", "Items", "Confirm", "Done"] : ["Items", "Confirm", "Done"]
    readonly property int stepIndex: {
        const order = mode === "borrow" ? ["signin", "tray", "confirm", "done"] : ["tray", "confirm", "done"]
        return order.indexOf(screen)
    }

    // The Pi's panel is 1024×600; the Mac window opens at the same size.
    width: 1024
    height: 600
    minimumWidth: 1024
    minimumHeight: 600
    visible: true
    visibility: kioskMode ? Window.FullScreen : Window.Windowed
    flags: kioskMode ? (Qt.Window | Qt.FramelessWindowHint) : Qt.Window
    title: "SPH Kiosk"
    color: Theme.bg
    font.family: Theme.font

    Component.onCompleted: IdleMonitor.timeout = idleTimeout

    // ---- Flow ------------------------------------------------------------------------
    // Flow log → journal (sudo journalctl _SYSTEMD_USER_UNIT=sph-kiosk.service). Users by id only.
    function flow(msg) { console.info("flow: " + msg) }
    function trayTags() {
        return Tray.entries.map(e => e.item.asset_tag + (e.source === "manual" ? " (by hand)" : "")).join(", ") || "empty"
    }
    onScreenChanged: flow("screen " + screen + " (" + mode + ")")
    function closeModals() { addByTag.close(); myLoans.close() }

    function startBorrow() {
        closeModals()
        doneScreen.stop()
        mode = "borrow"
        Tray.mode = "borrow"
        Tray.reset()
        signIn.reset()
        confirmScreen.reset()
        screen = Session.signedIn ? "tray" : "signin"
    }

    function startReturn() {
        closeModals()
        Session.signOut()           // returning is anonymous; don't leave someone signed in
        mode = "return"
        Tray.mode = "return"
        Tray.reset()
        confirmScreen.reset()
        screen = "tray"
    }

    function proceed() {
        if (!Tray.canContinue) return
        flow(mode + ": continue with " + trayTags())
        confirmScreen.reset()
        screen = "confirm"
    }

    function finish(result) {
        flow(mode + " done" + (mode === "borrow" && Session.user ? " for user " + Session.user.id : ""))
        const locations = {}
        for (const e of Tray.entries) locations[e.item.id] = e.item.location
        doneScreen.result = null
        doneScreen.mode = mode
        doneScreen.who = Session.name
        doneScreen.locations = locations
        doneScreen.result = result
        if (mode === "borrow") Session.signOut()
        Tray.reset()
        screen = "done"
        doneScreen.play()
    }

    // Back to a clean start screen (cancel, idle, after "done").
    function reset(reason) {
        flow("reset: " + (reason || "cancel") + (Session.signedIn ? ", signing out user " + Session.user.id : ""))
        closeModals()
        staff.close()               // and lock it
        doneScreen.stop()
        Session.signOut()
        Tray.reset()
        Tray.mode = "borrow"
        mode = "borrow"
        signIn.reset()
        confirmScreen.reset()
        screen = "start"
    }

    Connections {
        target: Session
        // Typed Legi accepted on the sign-in screen → on to the tray.
        function onUserChanged() { if (Session.signedIn && win.screen === "signin") win.screen = "tray" }
    }
    Connections {
        target: Tray
        function onContentsChanged() {
            win.flow("tray: " + win.trayTags())
            if (win.screen === "tray") IdleMonitor.wake() // placing items is activity
        }
    }
    Connections {
        target: IdleMonitor
        function onIdleChanged() { if (IdleMonitor.idle) win.reset("idle") }
    }
    // Camera changes count as activity, so a flickering tray could keep someone signed in
    // forever; cap the session no matter what.
    Timer {
        interval: 5000
        repeat: true
        running: Session.signedIn
        onTriggered: {
            if (Date.now() - Session.since.getTime() < win.maxSessionSec * 1000 || confirmScreen.submitting) return
            win.reset("session limit")
            Notify.info("Signed out for your safety. Tap your Legi to start again.")
        }
    }

    // A card tap works from anywhere (even the attract screen): sign in and borrow.
    Connections {
        target: Rfid
        function onTapped(uid, type) {
            win.flow("card tapped (" + type + ")")
            IdleMonitor.wake()
            if (confirmScreen.submitting || Session.pending) return
            const prevId = Session.user ? Session.user.id : -1
            Session.signInCard(uid, (ok, msg) => {
                if (!ok) { Notify.error(msg); return }
                const sameUser = Session.user.id === prevId
                if (sameUser && win.mode === "borrow" && (win.screen === "tray" || win.screen === "confirm")) {
                    Notify.info("You're signed in as " + Session.name)
                    return
                }
                Notify.success("Signed in as " + Session.name)
                win.startBorrow()
            })
        }
    }

    Shortcut { sequences: [StandardKey.Quit]; onActivated: Qt.quit() }
    Shortcut {
        sequence: "F11"
        onActivated: win.visibility = win.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
    }
    // Dev conveniences (Mac): F2 = simulated card tap, F3 = staff panel
    Shortcut { sequence: "F2"; onActivated: Rfid.simulateTap("DE:AD:BE:EF", "Simulated card") }
    Shortcut { sequence: "F3"; onActivated: staff.openFresh() }

    // ---- Shell -----------------------------------------------------------------------
    component Page: Item {
        id: page
        required property string name
        readonly property bool current: win.screen === name
        anchors.fill: parent
        opacity: current ? 1 : 0
        visible: opacity > 0
        enabled: current
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
        transform: Translate {
            x: page.current ? 0 : 24
            Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
        }
    }

    // Everything visible lives in `scene` (also what --screenshot grabs).
    Item {
        id: scene
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: Theme.bg }

        Header {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top }
            steps: win.screen === "start" ? [] : win.steps
            step: win.stepIndex
            title: win.screen === "start" ? "Student Project House · Makerspace" : ""
            backVisible: win.screen === "confirm" && !confirmScreen.submitting
            cancelVisible: win.screen !== "start" && win.screen !== "done" && !confirmScreen.submitting
            onBack: win.screen = "tray"
            onCancel: win.reset()
            onLogoHeld: staff.openFresh()
        }

        Row { // only when something is wrong
            anchors { right: parent.right; rightMargin: Theme.pad; verticalCenter: header.verticalCenter }
            visible: win.screen === "start"
            spacing: 10
            StatusChip { visible: Backend.online && !Backend.cameraReady; text: "No camera"; iconPath: Icons.camera }
            StatusChip { visible: Rfid.hardwareSupport && !Rfid.ready; text: "Card reader off"; iconPath: Icons.contactless }
        }

        Item {
            id: content
            anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }

            Page {
                name: "start"
                StartScreen { anchors.fill: parent; onBorrow: win.startBorrow(); onGiveBack: win.startReturn() }
            }
            Page {
                name: "signin"
                SignInScreen { id: signIn; anchors.fill: parent }
            }
            Page {
                name: "tray"
                TrayScreen {
                    id: trayScreen
                    anchors.fill: parent
                    live: win.screen === "tray" && !IdleMonitor.idle
                    onProceed: win.proceed()
                    onAddByHand: addByTag.openFresh()
                    onShowLoans: myLoans.open = true
                }
            }
            Page {
                name: "confirm"
                ConfirmScreen {
                    id: confirmScreen
                    anchors.fill: parent
                    onSucceeded: (result) => win.finish(result)
                    onFailed: win.screen = "tray"
                }
            }
            Page {
                name: "done"
                DoneScreen { id: doneScreen; anchors.fill: parent; onFinished: win.reset("done") }
            }

            // Server down: nothing works, so say so plainly (debounced against blips).
            Rectangle {
                anchors.fill: parent
                color: Theme.yellow
                visible: offlineDelay.offline
                MouseArea { anchors.fill: parent }
                Column {
                    anchors.centerIn: parent
                    spacing: 14
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; path: Icons.wifiOff; size: 64; color: Theme.ink; strokeWidth: 2.2 }
                    Heading { anchors.horizontalCenter: parent.horizontalCenter; text: "Kiosk temporarily offline" }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "The inventory server isn't answering. Please try again in a minute\nor ask a member of staff."
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.font; font.pixelSize: 20
                        color: Theme.ink
                    }
                }
            }
            Timer {
                id: offlineDelay
                property bool offline: false
                interval: 4000
                running: !Backend.online && !offline
                onTriggered: offline = true
            }
            Connections { target: Backend; function onHealthChanged() { if (Backend.online) offlineDelay.offline = false } }
        }

        Binding { target: Tray; property: "active"; value: trayScreen.live }

        AddByTag { id: addByTag }
        MyLoans { id: myLoans }
        StaffPanel { id: staff; onResetDone: win.reset("staff reset") }

        Toast {}

        AttractScreen { anchors.fill: parent; active: IdleMonitor.idle }
    }

    // ---- Screenshot tour (--screenshot <dir>) -------------------------------------------
    // Drives the real flows against the backend, so it RESETS the inventory first and last.
    function tag(t, cb) { Backend.get("/items/by-tag/" + t, r => { if (r.ok) cb(r.data) }) }
    function place(tags) { for (const t of tags) tag(t, item => Tray.addManual(item)) }
    function tourReset() {
        Backend.staffPin = win.tourStaffPin
        Backend.post("/admin/reset", null, () => { Backend.staffPin = "" })
    }
    property string realBackend: ""

    ScreenshotTour {
        enabled: win.screenshotDir.length > 0
        dir: win.screenshotDir
        target: scene
        steps: win.tour === "camera" ? cameraSteps : fullSteps
        // Read-only: the live tray view (needs a backend with a camera, e.g. the Pi's via a tunnel).
        readonly property var cameraSteps: [
            { name: "c01-start",        wait: 2500, run: () => win.reset() },
            { name: "c02-return-tray",  wait: 4000, run: () => win.startReturn() },
            { name: "c03-return-tray-later", wait: 3000, run: () => {} },
            { name: "c04-back",         skipShot: true, run: () => win.reset() }
        ]
        readonly property var fullSteps: [
            { name: "reset",            skipShot: true, wait: 600, run: () => win.tourReset() },
            { name: "01-start",         run: () => win.reset() },
            { name: "02-signin",        run: () => { win.startBorrow(); signIn.digits = "21912" } },
            { name: "03-signin-error",  run: () => { signIn.digits = "99999999"; signIn.submit() } },
            { name: "04-tray-empty",    run: () => { signIn.digits = "21912345"; signIn.submit() } },
            { name: "05-tray-items",    wait: 1200, run: () => win.place(["DAIM-001", "DAIM-003", "DAIM-005"]) },
            { name: "06-add-by-tag",    run: () => { addByTag.openFresh(); addByTag.digits = "7" } },
            { name: "07-confirm-borrow", run: () => { addByTag.close(); win.proceed() } },
            { name: "08-done-borrow",   wait: 1600, run: () => confirmScreen.submit() },
            { name: "09-return-tray",   wait: 1200, run: () => { win.startReturn(); win.place(["DAIM-001", "DAIM-003", "DAIM-002"]) } },
            { name: "10-confirm-return", run: () => { Tray.remove(Tray.entries.find(e => e.item.state !== "loaned").key); win.proceed() } },
            { name: "11-done-return",   wait: 1600, run: () => confirmScreen.submit() },
            { name: "12-borrow-blocked", wait: 1400, run: () => {
                win.reset(); win.startBorrow(); signIn.digits = "21912345"; signIn.submit()
                Qt.callLater(() => win.place(["DAIM-005", "DAIM-006"]))
            } },
            { name: "13-my-loans",      run: () => myLoans.open = true },
            { name: "14-staff-locked",  run: () => { myLoans.close(); staff.openFresh(); staff.digits = "1234" } },
            { name: "14-staff",         wait: 1200, run: () => staff.unlock(win.tourStaffPin) },
            { name: "15-offline",       wait: 5500, run: () => { staff.close(); win.reset(); win.realBackend = Backend.baseUrl; Backend.baseUrl = "http://127.0.0.1:9" } },
            { name: "16-attract",       wait: 1500, run: () => { Backend.baseUrl = win.realBackend; IdleMonitor.goIdle() } },
            { name: "reset-end",        skipShot: true, wait: 600, run: () => win.tourReset() }
        ]
        onDone: Qt.quit()
    }
}
