.pragma library

// What the Tailscale plugin shows, worked out from `tailscale status --json`: pure functions on
// plain objects, so they are tested in node (tests/tailscale_unit.js) and every surface (the bar
// entry, the popup, the widget) says the same thing. doc/DESIGN.md says where each rule comes
// from in the design.

// How soon a key's expiry is worth a look.
var KEY_WARN_DAYS = 7
// More offline devices than this fold under one "Offline · N" line (when the setting is "fold").
var FOLD_AFTER = 3

// The states of this machine, by what the user can do about each:
//   on          Running: on the tailnet
//   off         Stopped: signed in, not connected (`tailscale up`)
//   signedout   NeedsLogin / NeedsMachineAuth: sign in (AuthURL)
//   connecting  Starting, NoState
//   nodaemon    the command is there, tailscaled is not
//   missing     no `tailscale` command at all
//   error       anything else the command said; `message` has it
var STATES = ["on", "off", "signedout", "connecting", "nodaemon", "missing", "error"]

// What the status chip in the popup and the widget says, per state.
var STATE_WORDS = {
    on: "Connected",
    off: "Off",
    signedout: "Signed out",
    connecting: "Connecting",
    nodaemon: "Not running",
    missing: "Not installed",
    error: "Not answering"
}

// The line the service prints when the command is not on the PATH (Service.qml).
var MISSING_MARK = "__tailscale_missing__"

// classify(output) -> { kind: "status", status } | { kind: "nodaemon" } | { kind: "missing" }
//                   | { kind: "error", message }
// `output` is what `tailscale status --json` printed, stdout and stderr together.
function classify(output) {
    var text = String(output || "").trim()
    if (text.indexOf(MISSING_MARK) >= 0)
        return { kind: "missing" }
    var brace = text.indexOf("{")
    if (brace >= 0) {
        try {
            var status = JSON.parse(text.slice(brace))
            if (status && typeof status === "object" && typeof status.BackendState === "string")
                return { kind: "status", status: status }
        } catch (e) {
            // not JSON after all: read it as a message below
        }
    }
    if (/failed to connect to local tailscaled|tailscaled.*(not running|doesn't appear to be running)|connect: no such file or directory|connection refused/i.test(text))
        return { kind: "nodaemon" }
    return { kind: "error", message: firstLine(text) || "tailscale said nothing" }
}

function firstLine(text) {
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].trim()
        if (l !== "")
            return l
    }
    return ""
}

function stateOf(backend) {
    switch (backend) {
    case "Running": return "on"
    case "Stopped": return "off"
    case "NeedsLogin":
    case "NeedsMachineAuth": return "signedout"
    default: return "connecting"
    }
}

// Go's zero time, which tailscale sends for "never" / "not applicable".
function timeOf(s) {
    if (typeof s !== "string" || s === "" || s.indexOf("0001-01-01") === 0)
        return 0
    var t = Date.parse(s)
    return isFinite(t) ? t : 0
}

function ipv4(ips) {
    if (!Array.isArray(ips))
        return ""
    for (var i = 0; i < ips.length; i++)
        if (String(ips[i]).indexOf(".") >= 0)
            return String(ips[i])
    return ips.length > 0 ? String(ips[0]) : ""
}

function dnsName(n) {
    var s = typeof n === "string" ? n : ""
    return s.charAt(s.length - 1) === "." ? s.slice(0, -1) : s
}

// One device, as the surfaces use it.
//
// `relay` is set only while traffic flows through a DERP relay (Active, a Relay, no direct
// CurAddr). An idle device has no direct address either, and tailscale still names its home
// relay, so without Active every idle device would read "via relay", which says nothing.
function device(p, selfUser) {
    var relayed = p.Active === true && typeof p.Relay === "string" && p.Relay !== ""
        && (typeof p.CurAddr !== "string" || p.CurAddr === "")
    return {
        id: String(p.ID || p.PublicKey || p.HostName || ""),
        name: String(p.HostName || dnsName(p.DNSName).split(".")[0] || "unknown"),
        os: String(p.OS || ""),
        online: p.Online === true,
        ip: ipv4(p.TailscaleIPs),
        dns: dnsName(p.DNSName),
        lastSeen: timeOf(p.LastSeen),
        lastHandshake: timeOf(p.LastHandshake),
        active: p.Active === true,
        relay: relayed ? String(p.Relay) : "",
        exitNode: p.ExitNode === true,
        exitNodeOption: p.ExitNodeOption === true,
        keyExpiry: timeOf(p.KeyExpiry),
        mine: selfUser === undefined || p.UserID === selfUser
    }
}

// model(output, now) -> everything the surfaces show, for one `tailscale status --json`.
//   { state, message, authUrl, tailnet, self, peers }
// `self` is null when there is no machine to speak of (no daemon, not installed).
function model(output, now) {
    var c = classify(output)
    if (c.kind !== "status")
        return { state: c.kind, message: c.message || "", authUrl: "", tailnet: "", self: null, peers: [] }
    var s = c.status
    var state = stateOf(s.BackendState)
    var self = s.Self && typeof s.Self === "object" ? device(s.Self, undefined) : null
    if (self)
        self.online = state === "on"
    var selfUser = s.Self ? s.Self.UserID : undefined
    var peers = []
    var map = s.Peer && typeof s.Peer === "object" ? s.Peer : {}
    for (var k in map)
        peers.push(device(map[k], selfUser))
    var tailnet = s.CurrentTailnet && typeof s.CurrentTailnet.Name === "string" ? s.CurrentTailnet.Name : ""
    return {
        state: state,
        message: "",
        authUrl: typeof s.AuthURL === "string" ? s.AuthURL : "",
        tailnet: state === "signedout" ? "" : tailnet,
        self: state === "signedout" ? null : self,
        peers: state === "on" ? peers : []
    }
}

// The devices the count and the list are about: every peer, or only the user's own (a device
// shared into the tailnet by someone else is left out).
function counted(m, onlyMine) {
    return onlyMine ? m.peers.filter(function (p) { return p.mine }) : m.peers.slice()
}

// { online, total }: this machine is not counted (the icon says its state).
function count(m, onlyMine) {
    var list = counted(m, onlyMine)
    var on = 0
    for (var i = 0; i < list.length; i++)
        if (list[i].online)
            on++
    return { online: on, total: list.length }
}

// Days until a key expires, rounded up; null when it does not expire or is far off.
function keyDays(d, now) {
    if (!d || !d.keyExpiry)
        return null
    var days = Math.ceil((d.keyExpiry - now) / 86400000)
    return days <= KEY_WARN_DAYS ? days : null
}

function needsLook(d, now) {
    return keyDays(d, now) !== null
}

// Any device, this machine included, wants a look (the bar icon's small diamond).
function anyAttention(m, onlyMine, now) {
    if (m.self && needsLook(m.self, now))
        return true
    var list = counted(m, onlyMine)
    for (var i = 0; i < list.length; i++)
        if (needsLook(list[i], now))
            return true
    return false
}

function keyText(days, short) {
    if (days < 0)
        return "key expired"
    if (days === 0)
        return short ? "key today" : "key ends today"
    return (short ? "key " : "key ends in ") + days + (days === 1 ? " day" : " days")
}

// "just now", "4 min ago", "2 h ago", "3 d ago".
function ago(t, now) {
    if (!t)
        return "offline"
    var s = Math.max(0, Math.floor((now - t) / 1000))
    if (s < 60)
        return "just now"
    if (s < 3600)
        return Math.floor(s / 60) + " min ago"
    if (s < 86400)
        return Math.floor(s / 3600) + " h ago"
    return Math.floor(s / 86400) + " d ago"
}

// The one quiet line beside a device, and whether it carries the amber diamond. One thing at a
// time, the most useful first: when it was last there (offline), a key ending, a relay, an exit
// node. `short` is the widget's narrower wording ("key 3 days").
function meta(d, now, short) {
    if (!d.online)
        return { text: ago(d.lastSeen, now), warn: needsLook(d, now) }
    var days = keyDays(d, now)
    if (days !== null)
        return { text: keyText(days, short), warn: true }
    if (d.relay !== "")
        return { text: "via relay " + d.relay, warn: false }
    if (d.exitNode)
        return { text: "exit node", warn: false }
    if (d.exitNodeOption)
        return { text: short ? "exit node" : "offers exit node", warn: false }
    return { text: "", warn: false }
}

function byName(a, b) {
    var x = a.name.toLowerCase(), y = b.name.toLowerCase()
    return x < y ? -1 : x > y ? 1 : 0
}

// The list's order. This machine is never in it (it has its own block, on top).
//   "online"    online by name, then offline by last seen, newest first (the default)
//   "name"      by name, online or not
//   "lastseen"  online by the latest handshake (the one you talked to last first), then
//               offline by last seen
// Attention never moves a row, so nothing jumps while you look.
function sorted(list, order) {
    var on = list.filter(function (d) { return d.online })
    var off = list.filter(function (d) { return !d.online })
    var bySeen = function (a, b) { return (b.lastSeen - a.lastSeen) || byName(a, b) }
    if (order === "name")
        return list.slice().sort(byName)
    if (order === "lastseen")
        on.sort(function (a, b) { return (b.lastHandshake - a.lastHandshake) || byName(a, b) })
    else
        on.sort(byName)
    off.sort(bySeen)
    return on.concat(off)
}

// rows(m, opts, now) -> { rows: [device], folded: N }
// opts: { onlyMine, offline: "show" | "fold" | "hide", order, unfolded }
// With "fold", more than FOLD_AFTER offline devices are left out and counted in `folded`
// (the "Offline · N" line), unless the user opened it (`unfolded`).
function rows(m, opts, now) {
    var o = opts || {}
    var list = sorted(counted(m, o.onlyMine), o.order || "online")
    var offline = list.filter(function (d) { return !d.online })
    if (o.offline === "hide")
        return { rows: list.filter(function (d) { return d.online }), folded: 0 }
    if (o.offline === "fold" && offline.length > FOLD_AFTER && !o.unfolded)
        return { rows: list.filter(function (d) { return d.online }), folded: offline.length }
    return { rows: list, folded: 0 }
}

// "5 of 6 online", "all 6 online", "just this one".
function countText(c) {
    if (c.total === 0)
        return "just this one"
    if (c.online === c.total)
        return "all " + c.total + " online"
    return c.online + " of " + c.total + " online"
}

// What the bar entry says next to its icon: "5/6", "Off", "Sign in", or "" (connecting, no
// daemon: the icon says it). A standing bar is narrow: "off".
function entryText(m, onlyMine, vertical) {
    switch (m.state) {
    case "on":
        var c = count(m, onlyMine)
        return c.online + "/" + c.total
    case "off": return vertical ? "off" : "Off"
    case "signedout": return "Sign in"
    default: return ""
    }
}

// The hover tag (and the entry's accessible name).
function entryTip(m, onlyMine, now) {
    switch (m.state) {
    case "on":
        var c = count(m, onlyMine)
        var t = "Tailscale: on, " + (c.total === 0 ? "no other devices"
            : c.online === c.total ? "all " + c.total + " devices online" : c.online + " of " + c.total + " devices online")
        return anyAttention(m, onlyMine, now) ? t + ", a device needs a look" : t
    case "off": return "Tailscale is off"
    case "signedout": return "Tailscale: signed out"
    case "connecting": return "Tailscale: connecting"
    case "nodaemon": return "Tailscale: tailscaled isn't running"
    case "missing": return "Tailscale isn't installed"
    default: return "Tailscale: " + (m.message || "not answering")
    }
}

// The status dot on the entry in "icon only": on, off, or none (connecting, no daemon).
function entryDot(state) {
    if (state === "on")
        return "on"
    if (state === "off" || state === "signedout")
        return "off"
    return ""
}

// A Material Symbols name for a device's operating system.
function osIcon(os) {
    switch (String(os || "").toLowerCase()) {
    case "android": return "smartphone"
    case "ios": return "phone_iphone"
    case "macos": return "laptop_mac"
    case "windows": return "desktop_windows"
    case "linux": return "computer"
    default: return "devices"
    }
}

// "checked 2 s ago", "checked 3 min ago", "asking tailscaled…" before the first answer.
function checkedText(at, now) {
    if (!at)
        return "asking tailscaled…"
    var s = Math.max(0, Math.floor((now - at) / 1000))
    if (s < 60)
        return "checked " + s + " s ago"
    return "checked " + Math.floor(s / 60) + " min ago"
}

// How often the service asks, in ms: at the user's pace while a popup or the widget shows,
// every 30 s for the bar alone.
var BAR_ONLY_MS = 30000

function pollMs(wanted, seconds) {
    var w = Array.isArray(wanted) ? wanted : []
    if (w.indexOf("popup") >= 0 || w.indexOf("widget") >= 0)
        return Math.max(1, Math.min(60, Number(seconds) || 5)) * 1000
    return BAR_ONLY_MS
}
