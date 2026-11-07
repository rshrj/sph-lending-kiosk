pragma Singleton
import QtQuick

// App-wide message bus: any page can raise a toast or ask for navigation.
QtObject {
    signal toast(string message, string kind)   // kind: "info" | "success" | "error"
    signal navigate(int page)
    signal startFlow()
    property real softDim: 0   // 0..0.7 software brightness overlay
    property bool showFps: false

    function info(msg)    { toast(msg, "info") }
    function success(msg) { toast(msg, "success") }
    function error(msg)   { toast(msg, "error") }
}
