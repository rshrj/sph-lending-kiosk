import QtQuick
import Kiosk

// Page title: Alternate Gothic, uppercase. `level` 1 = page, 2 = section, 3 = card/row.
Text {
    property int level: 1
    font.family: Theme.fontDisplay
    font.pixelSize: level === 1 ? Theme.fsH1 : level === 2 ? Theme.fsH2 : Theme.fsH3
    font.weight: Theme.headingWeight
    font.capitalization: Theme.headingCaps
    font.letterSpacing: Theme.trackHeading
    lineHeight: 1.0
    color: Theme.text
}
