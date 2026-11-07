import QtQuick
import QtQuick.Shapes

// Thin open chevron used on SPH list rows and CTA strips.
Shape {
    id: root
    property color color: Theme.stroke
    property real lineWidth: 2.5
    // Explicit size: Shape derives its implicit size from the path, so the path must not depend on it.
    property real w: 16
    property real h: 28
    width: w; height: h
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: root.color; strokeWidth: root.lineWidth
        fillColor: "transparent"; capStyle: ShapePath.SquareCap; joinStyle: ShapePath.MiterJoin
        startX: 1; startY: 1
        PathLine { x: root.w - 1; y: root.h / 2 }
        PathLine { x: 1; y: root.h - 1 }
    }
}
