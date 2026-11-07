import QtQuick

// Launcher: `qml6 fullscreen.qml -- --file /abs/path/Thing.qml [args]` opens a
// Window-rooted QML file full screen (the stock `qml` viewer has no such flag).
QtObject {
    id: launcher
    property var window: null
    Component.onCompleted: {
        const args = Qt.application.arguments
        const i = args.indexOf("--file")
        if (i < 0 || i + 1 >= args.length) { console.error("usage: -- --file <path.qml>"); Qt.quit(); return }
        const c = Qt.createComponent("file://" + args[i + 1])
        if (c.status !== Component.Ready) { console.error(c.errorString()); Qt.quit(); return }
        window = c.createObject(null)
        window.visibility = Window.FullScreen
    }
}
