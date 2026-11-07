import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Shapes
import Kiosk

// Rotary control: put a finger on the ring and drag around it.
QQC.Dial {
    id: control
    property string suffix: "°"
    property int decimals: 1

    implicitWidth: 190
    implicitHeight: 190
    inputMode: QQC.Dial.Circular
    focusPolicy: Qt.NoFocus
    from: 16; to: 28; value: 21.5
    stepSize: 0.5
    snapMode: QQC.Dial.SnapAlways

    readonly property real ringRadius: Math.min(width, height) / 2 - 14

    background: Item {
        width: control.width
        height: control.height
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { // track
                strokeColor: Theme.surface3; strokeWidth: 12; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: control.width / 2; centerY: control.height / 2
                    radiusX: control.ringRadius; radiusY: control.ringRadius
                    startAngle: 130; sweepAngle: 280
                }
            }
            ShapePath { // value
                strokeColor: Theme.accent; strokeWidth: 12; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: control.width / 2; centerY: control.height / 2
                    radiusX: control.ringRadius; radiusY: control.ringRadius
                    startAngle: 130; sweepAngle: Math.max(0.01, 280 * control.position)
                }
            }
        }
        Column {
            anchors.centerIn: parent
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: control.value.toFixed(control.decimals) + control.suffix
                font.family: Theme.font; font.pixelSize: 34; font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Theme.text
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: control.pressed ? "adjusting…" : "setpoint"
                font.family: Theme.font; font.pixelSize: 12
                color: Theme.textDim
            }
        }
    }

    handle: Rectangle {
        id: knob
        width: 30; height: 30; radius: 15
        color: "white"
        border.width: 3; border.color: Theme.accent
        x: control.width / 2 - width / 2
        y: control.height / 2 - height / 2
        scale: control.pressed ? 1.2 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        transform: [
            Translate { y: -control.ringRadius },
            Rotation { angle: control.angle; origin.x: knob.width / 2; origin.y: knob.height / 2 }
        ]
    }
}
