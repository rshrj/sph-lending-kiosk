import QtQuick
import QtQuick.Shapes
import Kiosk

// Ring that empties over `seconds`, then emits finished().
Item {
    id: root
    property int seconds: 6
    property real fraction: 1
    property bool running: false
    signal finished()

    implicitWidth: 56
    implicitHeight: 56

    function restart() { fraction = 1; anim.restart() }
    function stop() { anim.stop() }

    NumberAnimation {
        id: anim
        target: root; property: "fraction"; from: 1; to: 0
        duration: root.seconds * 1000
        onFinished: root.finished()
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.surface3; strokeWidth: 5; fillColor: "transparent"
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width / 2 - 4; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: Theme.accent; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width / 2 - 4; radiusY: radiusX; startAngle: -90; sweepAngle: Math.max(0.01, 360 * root.fraction) }
        }
    }
    Text {
        anchors.centerIn: parent
        text: Math.ceil(root.fraction * root.seconds)
        font.family: Theme.font; font.pixelSize: 18; font.weight: Font.DemiBold
        color: Theme.text
    }
}
