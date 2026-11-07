import QtQuick
import QtQuick.Shapes
import Kiosk

// Tiny area chart for a rolling series.
Item {
    id: root
    property var values: []
    property real minValue: 0
    property real maxValue: 100
    property int capacity: 60
    property color color: Theme.accent

    implicitHeight: 70

    readonly property var points: {
        const out = []
        const n = values.length
        if (n < 2) return out
        const span = Math.max(0.0001, maxValue - minValue)
        const step = width / (capacity - 1)
        const x0 = width - (n - 1) * step
        for (let i = 0; i < n; ++i) {
            const v = Math.max(minValue, Math.min(maxValue, values[i]))
            out.push(Qt.point(x0 + i * step, height - 2 - (v - minValue) / span * (height - 4)))
        }
        return out
    }
    readonly property var areaPoints: points.length < 2 ? []
        : points.concat([Qt.point(points[points.length - 1].x, height), Qt.point(points[0].x, height)])

    Shape {
        anchors.fill: parent
        visible: root.points.length > 1
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: root.height
                GradientStop { position: 0; color: Theme.withAlpha(root.color, 0.35) }
                GradientStop { position: 1; color: Theme.withAlpha(root.color, 0.0) }
            }
            PathPolyline { path: root.areaPoints }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: root.points }
        }
    }
}
