import QtQuick
import QtQuick.Shapes
import Kiosk

// Resolution-independent stroke icon. Uses the curve renderer so it is
// antialiased without multisampling (cheap on the Pi's GPU).
Item {
    id: root
    property string path
    property color color: Theme.text
    property real size: 24
    property real strokeWidth: 2
    property bool filled: false

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: root.filled ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.path }
        }
    }
}
