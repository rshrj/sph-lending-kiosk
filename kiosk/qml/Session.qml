pragma Singleton
import QtQuick

// Who is signed in (borrowing needs a user; returning doesn't).
// The user comes from the backend: { id, legi, name, email, role, has_card }.
QtObject {
    id: session

    property var user: null
    property var loans: []          // the user's open loans (items with .loan)
    property date since: new Date()
    property bool pending: false    // a sign-in request is in flight

    readonly property bool signedIn: user !== null
    readonly property string name: user ? user.name : ""
    readonly property string firstName: Fmt.firstName(name)
    readonly property int overdueCount: loans.filter(i => i.loan && Fmt.isOverdue(i.loan.due_at)).length

    // cb(ok, errorMessage)
    function signInCard(uid, cb) { _signIn("/auth/card", { uid: uid }, cb) }
    function signInLegi(legi, cb) { _signIn("/auth/legi", { legi: legi }, cb) }

    function _signIn(path, body, cb) {
        pending = true
        Backend.post(path, body, r => {
            pending = false
            console.info("flow: sign-in " + (r.ok ? "ok: user " + r.data.id : "failed (" + r.status + "): " + r.error))
            if (r.ok) {
                user = r.data
                since = new Date()
                loans = []
                refreshLoans()
            }
            if (cb) cb(r.ok, r.error || "")
        })
    }

    function refreshLoans() {
        if (!user) return
        const id = user.id
        Backend.get("/users/" + id + "/loans", r => { if (r.ok && user && user.id === id) loans = r.data })
    }

    function signOut() { user = null; loans = [] }
}
