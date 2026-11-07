import QtQuick
import QtQuick.VirtualKeyboard

// Loaded lazily by Main.qml so the app still runs if the keyboard module is missing.
InputPanel {
    id: panel
    width: Window.width
    y: active ? Window.height - height : Window.height
    visible: y < Window.height
    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
}
