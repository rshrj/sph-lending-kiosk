pragma Singleton
import QtQuick
import QtCore

// Card-login session state. Enrolled cards persist in the app's settings file
// (uid → { name, enrolled, type }). A card's UID is its identity: fine for a
// test, but UIDs are clonable — the real app needs stronger credentials.
QtObject {
    id: session

    property var users: ({})
    property string uid: ""                 // signed-in card
    property date since: new Date()
    property string pendingUid: ""          // unknown card waiting to be enrolled
    property string pendingType: ""

    readonly property bool signedIn: uid.length > 0
    readonly property string name: signedIn && users[uid] ? users[uid].name : ""
    readonly property var userList: Object.keys(users).map(k => ({ uid: k, name: users[k].name, type: users[k].type || "" }))
                                                    .sort((a, b) => a.name.localeCompare(b.name))

    property Settings store: Settings {
        category: "rfid"
        property string usersJson: "{}"
    }
    Component.onCompleted: {
        try { users = JSON.parse(store.usersJson) } catch (e) { users = {} }
    }

    function initials(n) {
        const parts = n.trim().split(/\s+/)
        return (parts[0] ? parts[0][0] : "?").toUpperCase() + (parts.length > 1 ? parts[parts.length - 1][0].toUpperCase() : "")
    }

    // Returns "signedIn" | "signedOut" | "switched" | "unknown"
    function handleTap(cardUid, type) {
        if (users[cardUid]) {
            pendingUid = ""
            if (uid === cardUid) { signOut(); return "signedOut" }
            const was = signedIn
            uid = cardUid
            since = new Date()
            return was ? "switched" : "signedIn"
        }
        pendingUid = cardUid
        pendingType = type
        return "unknown"
    }

    function enrol(personName) {
        if (!pendingUid || !personName.trim()) return
        const u = Object.assign({}, users)
        u[pendingUid] = { name: personName.trim(), enrolled: Date.now(), type: pendingType }
        users = u
        store.usersJson = JSON.stringify(users)
        uid = pendingUid
        since = new Date()
        pendingUid = ""
    }

    function remove(cardUid) {
        const u = Object.assign({}, users)
        delete u[cardUid]
        users = u
        store.usersJson = JSON.stringify(users)
        if (uid === cardUid) signOut()
    }

    function signOut() { uid = "" }
    function cancelPending() { pendingUid = "" }
}
