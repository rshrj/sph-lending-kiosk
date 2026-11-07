import QtQuick

// Dev/CI helper (--screenshot <dir>): runs each step, waits for animations to
// settle, saves <dir>/<name>.png, then emits done().
QtObject {
    id: tour
    property bool enabled: false
    property string dir
    property Item target
    property var steps: []
    property int settleMs: 900
    property int index: -1
    signal done()

    function next() {
        index++
        if (index >= steps.length) { done(); return }
        steps[index].run()
        timer.restart()
    }

    property Timer timer: Timer {
        interval: tour.settleMs
        onTriggered: {
            const step = tour.steps[tour.index]
            tour.target.grabToImage(result => {
                const path = tour.dir + "/" + step.name + ".png"
                if (!result.saveToFile(path)) console.warn("could not save", path)
                else console.info("saved", path)
                tour.next()
            })
        }
    }
    property Timer kickoff: Timer { interval: 1200; running: tour.enabled; onTriggered: tour.next() }
}
