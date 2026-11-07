pragma Singleton
import QtQuick

// Stroke icons on a 24×24 grid (hand-drawn for this project).
// Usage: Icon { path: Icons.home }
QtObject {
    readonly property string home: "M3 11 L12 3.5 L21 11 M5.5 9 V20.5 H18.5 V9 M10 20.5 V14.5 H14 V20.5"
    readonly property string touch: "M12 9 m-3 0 a3 3 0 1 0 6 0 a3 3 0 1 0 -6 0 M5.6 13.5 A7.5 7.5 0 1 1 18.4 13.5 M12 12 V21"
    readonly property string sliders: "M4 6 H8 M12 6 H20 M4 12 H14 M18 12 H20 M4 18 H6 M10 18 H20 M10 6 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0 M16 12 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0 M8 18 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0"
    readonly property string cpu: "M7 7 H17 V17 H7 Z M10 10 H14 V14 H10 Z M9.5 3 V7 M14.5 3 V7 M9.5 17 V21 M14.5 17 V21 M3 9.5 H7 M3 14.5 H7 M17 9.5 H21 M17 14.5 H21"
    readonly property string gear: "M12 12 m-3 0 a3 3 0 1 0 6 0 a3 3 0 1 0 -6 0 M12 2.5 V5 M12 19 V21.5 M2.5 12 H5 M19 12 H21.5 M5.3 5.3 L7 7 M17 17 L18.7 18.7 M5.3 18.7 L7 17 M17 7 L18.7 5.3"
    readonly property string check: "M5 12.5 L10 17.5 L19 7"
    readonly property string close: "M6 6 L18 18 M18 6 L6 18"
    readonly property string arrowRight: "M5 12 H19 M13 6 L19 12 L13 18"
    readonly property string arrowLeft: "M19 12 H5 M11 6 L5 12 L11 18"
    readonly property string chevronRight: "M9 5 L16 12 L9 19"
    readonly property string backspace: "M21 5 H9 L3 12 L9 19 H21 Z M17 9 L12 14 M12 9 L17 14"
    readonly property string sun: "M12 12 m-4 0 a4 4 0 1 0 8 0 a4 4 0 1 0 -8 0 M12 2 V4 M12 20 V22 M2 12 H4 M20 12 H22 M4.9 4.9 L6.3 6.3 M17.7 17.7 L19.1 19.1 M4.9 19.1 L6.3 17.7 M17.7 6.3 L19.1 4.9"
    readonly property string moon: "M20 14.5 A8.5 8.5 0 1 1 9.5 4 A6.5 6.5 0 0 0 20 14.5 Z"
    readonly property string thermometer: "M14 14.5 V5 A2 2 0 0 0 10 5 V14.5 A4 4 0 1 0 14 14.5 Z"
    readonly property string clock: "M12 12 m-9 0 a9 9 0 1 0 18 0 a9 9 0 1 0 -18 0 M12 7 V12 L15.5 14"
    readonly property string wifi: "M2 9 A15 15 0 0 1 22 9 M5.5 12.5 A10 10 0 0 1 18.5 12.5 M9 16 A5 5 0 0 1 15 16 M12 19.5 L12 19.6"
    readonly property string play: "M7 4.5 L19 12 L7 19.5 Z"
    readonly property string refresh: "M20 11 A8 8 0 1 0 18 17 M20 4.5 V11 H13.5"
    readonly property string target: "M12 12 m-9 0 a9 9 0 1 0 18 0 a9 9 0 1 0 -18 0 M12 12 m-5 0 a5 5 0 1 0 10 0 a5 5 0 1 0 -10 0 M12 12 m-1 0 a1 1 0 1 0 2 0 a1 1 0 1 0 -2 0"
    readonly property string hand: "M8 13 V5.5 A1.5 1.5 0 0 1 11 5.5 V11 M11 10 V3.5 A1.5 1.5 0 0 1 14 3.5 V11 M14 10.5 V5 A1.5 1.5 0 0 1 17 5 V12 M17 9.5 A1.5 1.5 0 0 1 20 9.5 V14 A7 7 0 0 1 13 21 H12 A7 7 0 0 1 6.5 17 L4 12.5 A1.5 1.5 0 0 1 6.6 11 L8 13"
    readonly property string sparkle: "M12 3 L13.8 10.2 L21 12 L13.8 13.8 L12 21 L10.2 13.8 L3 12 L10.2 10.2 Z"
    readonly property string keyboard: "M3 6 H21 V18 H3 Z M7 10 H7.1 M11 10 H11.1 M15 10 H15.1 M19 10 H19.1 M7 14 H17"
    readonly property string power: "M12 3 V12 M6.5 6.5 A8 8 0 1 0 17.5 6.5"
    readonly property string grid: "M4 4 H10 V10 H4 Z M14 4 H20 V10 H14 Z M4 14 H10 V20 H4 Z M14 14 H20 V20 H14 Z"
    readonly property string badge: "M3 6 H21 V18 H3 Z M8.5 10.5 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0 M5.5 15.5 A3 3 0 0 1 11.5 15.5 M14 10 H18 M14 13.5 H18"
    readonly property string contactless: "M8 8 A6 6 0 0 1 8 16 M11.5 5.5 A10 10 0 0 1 11.5 18.5 M15 3 A14 14 0 0 1 15 21"
    readonly property string logout: "M15 4 H19 V20 H15 M10 8 L6 12 L10 16 M6 12 H15"
    readonly property string userPlus: "M10 8 m-4 0 a4 4 0 1 0 8 0 a4 4 0 1 0 -8 0 M3 20 A7 7 0 0 1 15 17 M19 14 V20 M16 17 H22"
    readonly property string box: "M3.5 7.5 L12 3 L20.5 7.5 V16.5 L12 21 L3.5 16.5 Z M3.5 7.5 L12 12 L20.5 7.5 M12 12 V21"
}
