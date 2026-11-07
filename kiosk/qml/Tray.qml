pragma Singleton
import QtQuick

// What is on the tray right now, for the current transaction.
//
// While `active`, the camera is asked (POST /identify) about once a second. The list mirrors
// the tray: an item appears when seen, and drops off after it has been missing for a few
// scans. QR labels name the exact unit; a vision hit only names the kind, so we pick a
// suitable unit of that kind. Items can also be added by hand (typed tag, or the simulator
// when there is no camera); those stay until removed.
QtObject {
    id: tray

    property string mode: "borrow"     // "borrow" | "return"
    property bool active: false        // scanning on/off (the tray screen sets this)

    property var entries: []           // [{ key, item, source: "camera"|"manual", misses, problem }]
    property var unknown: []           // QR codes that aren't ours: [{ key, code, misses }]
    property var detections: []        // last scan, for the camera overlay: [{ bbox, tone }]
    property var frameSize: [1920, 1080]
    property bool visionEnabled: false
    property bool scanning: false      // request in flight
    property int scans: 0
    property var ignored: ({})         // keys the user removed: don't re-add from the camera

    readonly property int missesToDrop: 3
    readonly property var okEntries: entries.filter(e => status(e).ok)
    readonly property int readyCount: okEntries.length
    readonly property int blockedCount: entries.length - readyCount
    readonly property bool canContinue: readyCount > 0 && blockedCount === 0
    readonly property var itemIds: okEntries.map(e => e.item.id)

    signal contentsChanged()   // items came or went (counts as activity for the idle timer)

    function reset() {
        entries = []; unknown = []; detections = []; ignored = ({}); scans = 0
    }

    // ---- status of one entry, for the current mode/user -----------------------------
    // { ok, tone: "ok" | "warn" | "bad", text }
    function status(e) {
        const it = e.item
        if (e.problem) return { ok: false, tone: "bad", text: e.problem }
        if (mode === "borrow") {
            if (it.state === "available")
                return { ok: true, tone: "ok", text: "Due back " + Fmt.day(Fmt.dueFromNow(it.loan_days)) }
            if (it.state === "loaned" && Session.user && it.loan.user_id === Session.user.id)
                return { ok: false, tone: "bad", text: "You already have this one. Take it off the tray." }
            if (it.state === "loaned")
                return { ok: false, tone: "bad", text: "Already on loan to someone else. Take it off the tray." }
            return { ok: false, tone: "bad", text: "Not available (" + it.state + "). Take it off the tray." }
        }
        // return
        if (it.state === "loaned") {
            const late = Fmt.isOverdue(it.loan.due_at)
            return { ok: true, tone: late ? "warn" : "ok", text: late ? "Returning late: " + Fmt.due(it.loan.due_at) : "On loan, " + Fmt.due(it.loan.due_at) }
        }
        return { ok: false, tone: "bad", text: "Not on loan, so there's nothing to return." }
    }

    // ---- manual entries --------------------------------------------------------------
    function has(itemId) { return entries.some(e => e.item.id === itemId) }

    function addManual(item) {
        const key = "item:" + item.id
        const ign = Object.assign({}, ignored); delete ign[key]; ignored = ign
        if (has(item.id)) {
            entries = entries.map(e => e.key === key ? Object.assign({}, e, { item: item, source: "manual", problem: "" }) : e)
            return false
        }
        entries = entries.concat([{ key: key, item: item, source: "manual", misses: 0, problem: "" }])
        contentsChanged()
        return true
    }

    function remove(key) {
        entries = entries.filter(e => e.key !== key)
        unknown = unknown.filter(u => u.key !== key)
        const ign = Object.assign({}, ignored); ign[key] = true; ignored = ign
        contentsChanged()
    }

    // Server said no (409): pin its reasons on the entries.
    function applyProblems(problems) {
        const byId = {}
        for (const p of problems || []) byId[p.item_id] = p.reason.charAt(0).toUpperCase() + p.reason.slice(1) + "."
        entries = entries.map(e => byId[e.item.id] ? Object.assign({}, e, { problem: byId[e.item.id] }) : e)
    }

    // Re-fetch every entry's item (after a failed transaction the states may have moved on).
    function refreshItems() {
        for (const e of entries) {
            const id = e.item.id
            Backend.get("/items/" + id, r => {
                if (r.ok) entries = entries.map(x => x.item.id === id ? Object.assign({}, x, { item: r.data, problem: "" }) : x)
            })
        }
    }

    // ---- camera scanning ---------------------------------------------------------------
    property Timer timer: Timer {
        interval: 900
        repeat: true
        triggeredOnStart: true
        running: tray.active && Backend.online && Backend.cameraReady
        onTriggered: tray.scan()
    }

    function scan() {
        if (scanning) return
        scanning = true
        Backend.post("/identify", null, r => {
            scanning = false
            if (!active) return
            if (r.ok) ingest(r.data)
        }, 6000)
    }

    // Pick which unit a vision hit means: one already on the tray, else one that suits the mode.
    function pickUnit(units, claimed) {
        const free = units.filter(u => !claimed[u.id])
        const onTray = free.find(u => has(u.id))
        if (onTray) return onTray
        const want = mode === "borrow" ? "available" : "loaned"
        return free.find(u => u.state === want) || free[0] || null
    }

    function ingest(res) {
        scans++
        frameSize = res.image_size
        visionEnabled = res.vision_enabled
        const seen = {}          // key → item
        const seenCodes = {}     // key → code
        const claimed = {}
        const boxes = []

        for (const d of res.detections) {
            let item = null
            if (d.method === "qr") item = d.items.length ? d.items[0] : null
            else item = pickUnit(d.items, claimed)

            if (item) {
                claimed[item.id] = true
                const key = "item:" + item.id
                if (!ignored[key]) seen[key] = item
                const st = status({ item: item, problem: "" })
                boxes.push({ bbox: d.bbox, tone: ignored[key] ? "muted" : st.tone, label: item.name })
            } else if (d.method === "qr") {
                const key = "code:" + d.code
                if (!ignored[key]) seenCodes[key] = d.code
                boxes.push({ bbox: d.bbox, tone: "muted", label: d.code })
            }
        }
        detections = boxes

        let changedAny = false
        const next = []
        for (const e of entries) {
            if (seen[e.key]) {
                // Keep a server-reported problem only while the item's state is unchanged.
                const same = e.item.state === seen[e.key].state
                next.push(Object.assign({}, e, { item: seen[e.key], misses: 0, problem: same ? e.problem : "" }))
                delete seen[e.key]
            } else if (e.source === "camera" && e.misses + 1 >= missesToDrop) {
                changedAny = true            // gone from the tray
            } else {
                next.push(e.source === "camera" ? Object.assign({}, e, { misses: e.misses + 1 }) : e)
            }
        }
        for (const key in seen) {
            next.push({ key: key, item: seen[key], source: "camera", misses: 0, problem: "" })
            changedAny = true
        }
        entries = next

        const nextUnknown = []
        for (const u of unknown) {
            if (seenCodes[u.key]) { nextUnknown.push(Object.assign({}, u, { misses: 0 })); delete seenCodes[u.key] }
            else if (u.misses + 1 < missesToDrop) nextUnknown.push(Object.assign({}, u, { misses: u.misses + 1 }))
        }
        for (const key in seenCodes) nextUnknown.push({ key: key, code: seenCodes[key], misses: 0 })
        unknown = nextUnknown

        if (changedAny) contentsChanged()
    }
}
