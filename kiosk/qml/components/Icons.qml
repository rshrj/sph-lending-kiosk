pragma Singleton
import QtQuick

// Stroke icons on a 24×24 grid (from Kiosk Lab, plus a few for lending).
// Usage: Icon { path: Icons.check }
QtObject {
    readonly property string check: "M5 12.5 L10 17.5 L19 7"
    readonly property string close: "M6 6 L18 18 M18 6 L6 18"
    readonly property string arrowRight: "M5 12 H19 M13 6 L19 12 L13 18"
    readonly property string arrowLeft: "M19 12 H5 M11 6 L5 12 L11 18"
    readonly property string chevronRight: "M9 5 L16 12 L9 19"
    readonly property string backspace: "M21 5 H9 L3 12 L9 19 H21 Z M17 9 L12 14 M12 9 L17 14"
    readonly property string clock: "M12 12 m-9 0 a9 9 0 1 0 18 0 a9 9 0 1 0 -18 0 M12 7 V12 L15.5 14"
    readonly property string refresh: "M20 11 A8 8 0 1 0 18 17 M20 4.5 V11 H13.5"
    readonly property string hand: "M8 13 V5.5 A1.5 1.5 0 0 1 11 5.5 V11 M11 10 V3.5 A1.5 1.5 0 0 1 14 3.5 V11 M14 10.5 V5 A1.5 1.5 0 0 1 17 5 V12 M17 9.5 A1.5 1.5 0 0 1 20 9.5 V14 A7 7 0 0 1 13 21 H12 A7 7 0 0 1 6.5 17 L4 12.5 A1.5 1.5 0 0 1 6.6 11 L8 13"
    readonly property string power: "M12 3 V12 M6.5 6.5 A8 8 0 1 0 17.5 6.5"
    readonly property string badge: "M3 6 H21 V18 H3 Z M8.5 10.5 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0 M5.5 15.5 A3 3 0 0 1 11.5 15.5 M14 10 H18 M14 13.5 H18"
    readonly property string contactless: "M8 8 A6 6 0 0 1 8 16 M11.5 5.5 A10 10 0 0 1 11.5 18.5 M15 3 A14 14 0 0 1 15 21"
    readonly property string logout: "M15 4 H19 V20 H15 M10 8 L6 12 L10 16 M6 12 H15"
    readonly property string box: "M3.5 7.5 L12 3 L20.5 7.5 V16.5 L12 21 L3.5 16.5 Z M3.5 7.5 L12 12 L20.5 7.5 M12 12 V21"
    readonly property string boxOut: "M3.5 9.5 L12 5 L20.5 9.5 V17.5 L12 22 L3.5 17.5 Z M3.5 9.5 L12 14 L20.5 9.5 M12 14 V22 M12 1 V5"
    readonly property string boxIn: "M3.5 9.5 L12 5 L20.5 9.5 V17.5 L12 22 L3.5 17.5 Z M3.5 9.5 L12 14 L20.5 9.5 M12 14 V22"
    readonly property string camera: "M3 8 H7 L9 5 H15 L17 8 H21 V19 H3 Z M12 13.5 m-3.5 0 a3.5 3.5 0 1 0 7 0 a3.5 3.5 0 1 0 -7 0"
    readonly property string plus: "M12 5 V19 M5 12 H19"
    readonly property string tag: "M3 12 V4 H11 L20.5 13.5 L13.5 20.5 Z M7.5 8.5 m-1 0 a1 1 0 1 0 2 0 a1 1 0 1 0 -2 0"
    readonly property string alert: "M12 3 L22 20 H2 Z M12 9.5 V14 M12 17 V17.1"
    readonly property string list: "M8 6 H20 M8 12 H20 M8 18 H20 M4 6 H4.1 M4 12 H4.1 M4 18 H4.1"
    readonly property string wifiOff: "M2 9 A15 15 0 0 1 22 9 M5.5 12.5 A10 10 0 0 1 18.5 12.5 M9 16 A5 5 0 0 1 15 16 M12 19.5 L12 19.6 M3 3 L21 21"
    readonly property string sparkle: "M12 3 L13.8 10.2 L21 12 L13.8 13.8 L12 21 L10.2 13.8 L3 12 L10.2 10.2 Z"
    readonly property string qr: "M3 3 H10 V10 H3 Z M14 3 H21 V10 H14 Z M3 14 H10 V21 H3 Z M6 6 H7 V7 H6 Z M17 6 H18 V7 H17 Z M6 17 H7 V18 H6 Z M14 14 H17 V17 H14 Z M20 14 V21 H17 M14 20 V21"
}
