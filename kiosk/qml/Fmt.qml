pragma Singleton
import QtQuick

// Formatting helpers shared by the screens. Dates from the backend are ISO 8601 UTC.
QtObject {
    readonly property int dayMs: 24 * 3600 * 1000

    // "21912345" (or a prefix while typing) → "21-912-345"
    function legi(digits) {
        const d = String(digits || "")
        return d.slice(0, 2) + (d.length > 2 ? "-" + d.slice(2, 5) : "") + (d.length > 5 ? "-" + d.slice(5, 8) : "")
    }

    function toDate(v) { return v instanceof Date ? v : new Date(v) }

    // Fri 14 Nov
    function day(v) { return Qt.formatDate(toDate(v), "ddd d MMM") }

    // Due date for an item borrowed now
    function dueFromNow(loanDays) { return new Date(Date.now() + loanDays * dayMs) }

    function isOverdue(due) { return toDate(due).getTime() < Date.now() }

    // Whole calendar days from today to `v` (negative = in the past)
    function daysUntil(v) {
        const a = new Date(); a.setHours(0, 0, 0, 0)
        const b = toDate(v); const bb = new Date(b.getFullYear(), b.getMonth(), b.getDate())
        return Math.round((bb - a) / dayMs)
    }

    // "due today" / "due tomorrow" / "due Fri 14 Nov" / "3 days overdue"
    function due(v) {
        const n = daysUntil(v)
        if (isOverdue(v)) return n >= 0 ? "overdue" : (-n === 1 ? "1 day overdue" : -n + " days overdue")
        if (n === 0) return "due today"
        if (n === 1) return "due tomorrow"
        return "due " + day(v)
    }

    function plural(n, one, many) { return n + " " + (n === 1 ? one : (many || one + "s")) }

    function cap(s) { s = String(s || ""); return s.charAt(0).toUpperCase() + s.slice(1) }

    function firstName(name) { return String(name || "").trim().split(/\s+/)[0] }
}
