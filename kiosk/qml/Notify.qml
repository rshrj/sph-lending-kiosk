pragma Singleton
import QtQuick

// App-wide message bus: any screen can raise a toast.
QtObject {
    signal toast(string message, string kind)   // kind: "info" | "success" | "error"

    function info(msg)    { toast(msg, "info") }
    function success(msg) { toast(msg, "success") }
    function error(msg)   { toast(msg, "error") }
}
