import QtQuick
import QtQuick.Shapes

// Soft glowing orb (radial gradient → transparent). No blur pass needed.
Shape {
    id: blob
    property color color: "#6C7BFF"
    property real diameter: 400
    width: diameter
    height: diameter
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: "transparent"
        fillGradient: RadialGradient {
            centerX: blob.diameter / 2; centerY: blob.diameter / 2; centerRadius: blob.diameter / 2
            focalX: centerX; focalY: centerY
            GradientStop { position: 0.0; color: Qt.rgba(blob.color.r, blob.color.g, blob.color.b, 0.55) }
            GradientStop { position: 0.45; color: Qt.rgba(blob.color.r, blob.color.g, blob.color.b, 0.22) }
            GradientStop { position: 1.0; color: Qt.rgba(blob.color.r, blob.color.g, blob.color.b, 0.0) }
        }
        PathAngleArc {
            centerX: blob.diameter / 2; centerY: blob.diameter / 2
            radiusX: blob.diameter / 2; radiusY: blob.diameter / 2
            startAngle: 0; sweepAngle: 360
        }
    }
}
