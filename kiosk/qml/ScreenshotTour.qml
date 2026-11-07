import QtQuick

// Dev helper (--screenshot <dir>): runs each step, waits for it to settle (step.wait or
// settleMs), saves <dir>/<name>.png, then emits done().
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
        timer.interval = steps[index].wait || settleMs
        timer.restart()
    }

    property Timer timer: Timer {
        onTriggered: {
            const step = tour.steps[tour.index]
            if (step.skipShot) { tour.next(); return }
            tour.target.grabToImage(result => {
                const path = tour.dir + "/" + step.name + ".png"
                if (!result.saveToFile(path)) console.warn("could not save", path)
                else console.info("saved", path)
                tour.next()
            })
        }
    }
    property Timer kickoff: Timer { interval: 1500; running: tour.enabled; onTriggered: tour.next() }
}
