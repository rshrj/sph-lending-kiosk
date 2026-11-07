import QtQuick
import QtQuick.Controls
import Kiosk

// Big tappable tile for the home screen.
AbstractButton {
    id: tile
    property string iconPath
    property string subtitle
    property bool featured: false
    property color tint: Theme.accent

    focusPolicy: Qt.NoFocus
    scale: pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad } }

    background: Rectangle {
        radius: Theme.radiusL
        color: tile.featured ? tile.tint : Theme.surface
        border.width: tile.featured ? (Theme.sph ? Theme.strokeButton : 0) : Theme.strokeCard
        border.color: tile.featured ? Theme.stroke : Theme.cardOutline
        Rectangle { // gradient as its own item: Qt 6.8 won't take a conditional `gradient:` binding
            visible: tile.featured
            anchors.fill: parent
            anchors.margins: parent.border.width
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.gradTop(tile.tint) }
                GradientStop { position: 1; color: Theme.gradBottom(tile.tint) }
            }
        }
        Rectangle { // press tint
            anchors.fill: parent; radius: parent.radius
            color: tile.featured ? "black" : Theme.text
            opacity: tile.pressed ? 0.10 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        }
    }

    contentItem: Item {
        Rectangle {
            id: bubble
            anchors { left: parent.left; top: parent.top; margins: 20 }
            width: tile.featured ? 56 : 46; height: width; radius: Theme.sph ? 0 : width / 3.2
            color: Theme.sph ? (tile.featured ? "transparent" : tile.tint)
                 : tile.featured ? Qt.rgba(1, 1, 1, 0.2) : Theme.withAlpha(tile.tint, Theme.dark ? 0.18 : 0.13)
            border.width: Theme.sph ? 2 : 0
            border.color: Theme.stroke
            Icon {
                anchors.centerIn: parent
                path: tile.iconPath
                size: tile.featured ? 28 : 24
                color: tile.featured || Theme.sph ? Theme.accentText : tile.tint
            }
        }
        Icon {
            anchors { right: parent.right; top: parent.top; margins: 22 }
            path: Icons.arrowRight
            size: 22
            color: tile.featured ? Theme.accentText : Theme.sph ? Theme.text : Theme.textFaint
            opacity: tile.featured ? 0.9 : 1
        }
        Column {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20 }
            spacing: 4
            Text {
                width: parent.width
                text: tile.text
                font.family: Theme.fontDisplay
                font.pixelSize: (tile.featured ? 26 : 19) * Theme.titleScale
                font.weight: Theme.titleWeight
                font.capitalization: Theme.headingCaps
                font.letterSpacing: Theme.trackLabel
                color: tile.featured ? Theme.accentText : Theme.text
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: tile.subtitle
                font.family: Theme.font; font.pixelSize: 14
                color: tile.featured ? (Theme.sph ? Theme.ink : Qt.rgba(1, 1, 1, 0.82)) : Theme.textDim
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
