import QtQuick
import QtQuick.Shapes
import Kiosk

// Animated "done" mark: the disc pops in, then the tick draws itself.
Item {
    id: root
    property real size: 140
    property real progress: 0   // 0..1 tick draw progress
    implicitWidth: size
    implicitHeight: size

    function play() { anim.restart() }

    Rectangle {
        id: halo
        anchors.centerIn: parent
        width: root.size; height: width; radius: width / 2
        color: Theme.withAlpha(Theme.success, 0.18)
        scale: 0
    }
    Rectangle {
        id: disc
        anchors.centerIn: parent
        width: root.size * 0.72; height: width; radius: width / 2
        color: Theme.success
        scale: 0
    }

    // Tick: two segments A→B→C whose end points are interpolated by `progress`.
    readonly property real s: root.size / 140
    readonly property point a: Qt.point(46 * s, 72 * s)
    readonly property point b: Qt.point(63 * s, 88 * s)
    readonly property point c: Qt.point(96 * s, 54 * s)
    readonly property real p1: Math.min(1, progress * 2.2)
    readonly property real p2: Math.max(0, (progress * 2.2 - 1) / 1.2)
    readonly property point e1: Qt.point(a.x + (b.x - a.x) * p1, a.y + (b.y - a.y) * p1)
    readonly property point e2: p2 > 0 ? Qt.point(b.x + (c.x - b.x) * p2, b.y + (c.y - b.y) * p2) : e1

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.progress > 0
        ShapePath {
            strokeColor: Theme.accentText; strokeWidth: 9 * root.s; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            startX: root.a.x; startY: root.a.y
            PathLine { x: root.e1.x; y: root.e1.y }
            PathLine { x: root.e2.x; y: root.e2.y }
        }
    }

    SequentialAnimation {
        id: anim
        PropertyAction { target: root; property: "progress"; value: 0 }
        PropertyAction { targets: [disc, halo]; property: "scale"; value: 0 }
        ParallelAnimation {
            NumberAnimation { target: disc; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2 }
            NumberAnimation { target: halo; property: "scale"; to: 1; duration: 700; easing.type: Easing.OutCubic }
        }
        NumberAnimation { target: root; property: "progress"; to: 1; duration: 420; easing.type: Easing.OutCubic }
    }
}
