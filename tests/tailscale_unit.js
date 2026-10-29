// The Tailscale plugin's rules (tailscale/lib/Tailscale.js), in node.
// Run: node --test tests/   (with --experimental-test-coverage for the coverage floor)
const { test } = require("node:test")
const assert = require("node:assert")
const load = require("./load")

const TS = load("tailscale/lib/Tailscale.js", ["KEY_WARN_DAYS", "FOLD_AFTER", "STATES", "STATE_WORDS", "MISSING_MARK",
    "classify", "model", "count", "counted", "keyDays", "anyAttention", "meta", "ago", "sorted", "rows", "countText",
    "entryText", "entryTip", "entryDot", "osIcon", "checkedText", "pollMs", "BAR_ONLY_MS"])

const NOW = Date.parse("2026-10-29T21:00:00Z")
const H = 3600000, D = 86400000
const iso = t => new Date(t).toISOString()
const ZERO = "0001-01-01T00:00:00Z"
const ME = 111, FRIEND = 222

function peer(name, o) {
    const e = o || {}
    return {
        ID: "id-" + name, HostName: name, DNSName: name + ".tail1234.ts.net.", OS: e.os || "linux",
        UserID: e.user || ME, TailscaleIPs: ["100.64.0." + name.length, "fd7a::" + name.length],
        Online: e.online !== false, LastSeen: e.lastSeen ? iso(e.lastSeen) : ZERO,
        LastHandshake: e.handshake ? iso(e.handshake) : ZERO, Active: !!e.active,
        Relay: e.relay || "", CurAddr: e.direct ? "1.2.3.4:41641" : "",
        ExitNode: !!e.exitNode, ExitNodeOption: !!e.exitNodeOption, KeyExpiry: e.key ? iso(e.key) : undefined
    }
}

// The sample tailnet of the brief: 6 devices besides this one, 5 online.
function status(over) {
    const s = {
        Version: "1.102.4", BackendState: "Running", AuthURL: "",
        CurrentTailnet: { Name: "me@example.org", MagicDNSSuffix: "tail1234.ts.net" },
        Self: Object.assign(peer("deskbox", { direct: true }), { TailscaleIPs: ["fd7a::1", "100.71.8.4"] }),
        Peer: {
            a: peer("vps", { direct: true, exitNodeOption: true, handshake: NOW - 5000 }),
            b: peer("steamdeck", { active: true, relay: "fra", handshake: NOW - 1000 }),
            c: peer("fold-phone", { os: "android", direct: true, handshake: NOW - 60000 }),
            d: peer("tab-s6", { os: "android", direct: true }),
            e: peer("pad5", { os: "android", direct: true, key: NOW + 3 * D - H }),
            f: peer("old-tablet", { os: "android", online: false, lastSeen: NOW - 2 * H })
        }
    }
    return JSON.stringify(Object.assign(s, over || {}))
}

test("classify: JSON, no daemon, not installed, anything else", () => {
    assert.strictEqual(TS.classify(status()).kind, "status")
    assert.strictEqual(TS.classify("warning: something\n" + status()).kind, "status", "a line before the JSON is skipped")
    assert.strictEqual(TS.classify("failed to connect to local tailscaled; it doesn't appear to be running (sudo systemctl start tailscaled ?)").kind, "nodaemon")
    assert.strictEqual(TS.classify("dial unix /var/run/tailscale/tailscaled.sock: connect: no such file or directory").kind, "nodaemon")
    assert.strictEqual(TS.classify(TS.MISSING_MARK + "\n").kind, "missing")
    assert.deepStrictEqual(TS.classify("\n  permission denied\nmore"), { kind: "error", message: "permission denied" })
    assert.deepStrictEqual(TS.classify(""), { kind: "error", message: "tailscale said nothing" })
    assert.strictEqual(TS.classify("{ not json").kind, "error")
    assert.strictEqual(TS.classify('{"Peer": {}}').kind, "error", "JSON without BackendState is not a status")
})

test("model: the states, from BackendState", () => {
    const st = b => TS.model(status({ BackendState: b }), NOW)
    assert.strictEqual(st("Running").state, "on")
    assert.strictEqual(st("Stopped").state, "off")
    assert.strictEqual(st("NeedsLogin").state, "signedout")
    assert.strictEqual(st("NeedsMachineAuth").state, "signedout")
    assert.strictEqual(st("Starting").state, "connecting")
    assert.strictEqual(st("NoState").state, "connecting")
    assert.deepStrictEqual(st("Stopped").peers, [], "only a running machine lists devices")
    const out = st("NeedsLogin")
    assert.deepStrictEqual([out.self, out.tailnet], [null, ""], "signed out: no machine block, no tailnet")
    assert.strictEqual(TS.model(status({ BackendState: "NeedsLogin", AuthURL: "https://login.tailscale.com/a/x" }), NOW).authUrl, "https://login.tailscale.com/a/x")
    for (const s of ["nodaemon", "missing"])
        assert.deepStrictEqual(TS.model(s === "missing" ? TS.MISSING_MARK : "failed to connect to local tailscaled", NOW),
            { state: s, message: "", authUrl: "", tailnet: "", self: null, peers: [] })
    assert.strictEqual(TS.model("boom", NOW).message, "boom")
    for (const s of TS.STATES)
        assert.ok(TS.STATE_WORDS[s], "the chip has a word for " + s)
})

test("model: this machine and a device", () => {
    const m = TS.model(status(), NOW)
    assert.strictEqual(m.tailnet, "me@example.org")
    assert.deepStrictEqual([m.self.name, m.self.ip, m.self.dns, m.self.online], ["deskbox", "100.71.8.4", "deskbox.tail1234.ts.net", true], "the IPv4 address is the one shown, wherever it is in the list")
    const deck = m.peers.find(p => p.name === "steamdeck")
    assert.deepStrictEqual([deck.relay, deck.active, deck.mine, deck.lastSeen], ["fra", true, true, 0], "a zero time reads as none")
    assert.strictEqual(m.peers.find(p => p.name === "vps").relay, "", "a device with a direct address is not relayed")
    const idle = TS.model(status({ Peer: { a: peer("phone", { relay: "sao" }) } }), NOW)
    assert.strictEqual(idle.peers[0].relay, "", "an idle device names its home relay but is not relayed: no word")
    const odd = TS.model(JSON.stringify({ BackendState: "Running", Peer: { x: { DNSName: "ghost.ts.net.", TailscaleIPs: ["fd7a::9"] }, y: {} } }), NOW)
    assert.deepStrictEqual(odd.peers.map(p => [p.name, p.ip]), [["ghost", "fd7a::9"], ["unknown", ""]], "names and addresses fall back")
    assert.strictEqual(odd.self, null)
})

test("count: online of all, this machine left out, or only mine", () => {
    const m = TS.model(status(), NOW)
    assert.deepStrictEqual(TS.count(m, false), { online: 5, total: 6 })
    const shared = TS.model(status({ Peer: { a: peer("vps"), b: peer("friends-nas", { user: FRIEND }), c: peer("off", { user: FRIEND, online: false }) } }), NOW)
    assert.deepStrictEqual(TS.count(shared, false), { online: 2, total: 3 })
    assert.deepStrictEqual(TS.count(shared, true), { online: 1, total: 1 }, "only mine: devices of the same user as this machine")
    assert.strictEqual(TS.countText({ online: 5, total: 6 }), "5 of 6 online")
    assert.strictEqual(TS.countText({ online: 6, total: 6 }), "all 6 online")
    assert.strictEqual(TS.countText({ online: 0, total: 0 }), "just this one")
})

test("attention: a key ending within 7 days, quietly", () => {
    const m = TS.model(status(), NOW)
    const pad = m.peers.find(p => p.name === "pad5")
    assert.strictEqual(TS.keyDays(pad, NOW), 3)
    assert.deepStrictEqual(TS.meta(pad, NOW, false), { text: "key ends in 3 days", warn: true })
    assert.deepStrictEqual(TS.meta(pad, NOW, true), { text: "key 3 days", warn: true })
    assert.strictEqual(TS.keyDays(Object.assign({}, pad, { keyExpiry: NOW + 30 * D }), NOW), null, "far off: no word")
    assert.strictEqual(TS.keyDays(Object.assign({}, pad, { keyExpiry: 0 }), NOW), null, "a key that does not expire")
    assert.strictEqual(TS.meta(Object.assign({}, pad, { keyExpiry: NOW + H }), NOW, false).text, "key ends in 1 day")
    assert.strictEqual(TS.meta(Object.assign({}, pad, { keyExpiry: NOW }), NOW, false).text, "key ends today")
    assert.strictEqual(TS.meta(Object.assign({}, pad, { keyExpiry: NOW }), NOW, true).text, "key today")
    assert.strictEqual(TS.meta(Object.assign({}, pad, { keyExpiry: NOW - 2 * D }), NOW, false).text, "key expired")
    assert.strictEqual(TS.anyAttention(m, false, NOW), true)
    const calm = TS.model(status({ Peer: { a: peer("vps") } }), NOW)
    assert.strictEqual(TS.anyAttention(calm, false, NOW), false)
    const selfKey = TS.model(status({ Peer: {}, Self: peer("deskbox", { key: NOW + D }) }), NOW)
    assert.strictEqual(TS.anyAttention(selfKey, false, NOW), true, "this machine's own key counts too")
    const offKey = Object.assign({}, pad, { online: false, lastSeen: NOW - 3 * 60000 })
    assert.deepStrictEqual(TS.meta(offKey, NOW, false), { text: "3 min ago", warn: true }, "offline says when, and keeps the diamond")
})

test("meta: one thing at a time, the most useful first", () => {
    const m = TS.model(status(), NOW)
    const by = n => TS.meta(m.peers.find(p => p.name === n), NOW, false).text
    assert.strictEqual(by("steamdeck"), "via relay fra")
    assert.strictEqual(by("vps"), "offers exit node")
    assert.strictEqual(TS.meta(m.peers.find(p => p.name === "vps"), NOW, true).text, "exit node")
    assert.strictEqual(by("old-tablet"), "2 h ago")
    assert.strictEqual(by("tab-s6"), "")
    const exit = TS.model(status({ Peer: { a: peer("vps", { direct: true, exitNode: true, exitNodeOption: true }) } }), NOW)
    assert.strictEqual(TS.meta(exit.peers[0], NOW, false).text, "exit node", "the exit node in use, not the offer")
})

test("ago and checked", () => {
    assert.strictEqual(TS.ago(NOW - 10000, NOW), "just now")
    assert.strictEqual(TS.ago(NOW - 5 * 60000, NOW), "5 min ago")
    assert.strictEqual(TS.ago(NOW - 3 * H, NOW), "3 h ago")
    assert.strictEqual(TS.ago(NOW - 4 * D, NOW), "4 d ago")
    assert.strictEqual(TS.ago(0, NOW), "offline")
    assert.strictEqual(TS.ago(NOW + 5000, NOW), "just now", "a clock a little ahead is not the future")
    assert.strictEqual(TS.checkedText(0, NOW), "asking tailscaled…")
    assert.strictEqual(TS.checkedText(NOW - 2000, NOW), "checked 2 s ago")
    assert.strictEqual(TS.checkedText(NOW - 125000, NOW), "checked 2 min ago")
})

test("order: online by name, then offline by last seen; or by name; or by handshake", () => {
    const m = TS.model(status({ Peer: Object.assign(JSON.parse(status()).Peer, {
        g: peer("older-laptop", { online: false, lastSeen: NOW - 5 * D }),
        h: peer("Alpha", { handshake: NOW - 100 })
    }) }), NOW)
    const names = order => TS.sorted(m.peers, order).map(p => p.name)
    assert.deepStrictEqual(names("online"), ["Alpha", "fold-phone", "pad5", "steamdeck", "tab-s6", "vps", "old-tablet", "older-laptop"])
    assert.deepStrictEqual(names(undefined), names("online"), "online first is the default")
    assert.deepStrictEqual(names("name"), ["Alpha", "fold-phone", "old-tablet", "older-laptop", "pad5", "steamdeck", "tab-s6", "vps"])
    assert.deepStrictEqual(names("lastseen"), ["Alpha", "steamdeck", "vps", "fold-phone", "pad5", "tab-s6", "old-tablet", "older-laptop"])
    const ties = TS.sorted([{ name: "b", online: false, lastSeen: 5, lastHandshake: 0 }, { name: "a", online: false, lastSeen: 5, lastHandshake: 0 }], "online")
    assert.deepStrictEqual(ties.map(d => d.name), ["a", "b"], "a tie goes by name, so the order never flickers")
})

test("rows: offline shown, folded past three, or hidden", () => {
    const offs = {}
    for (const [i, n] of ["o1", "o2", "o3", "o4"].entries())
        offs[n] = peer(n, { online: false, lastSeen: NOW - (i + 1) * H })
    const m = TS.model(status({ Peer: Object.assign({ a: peer("vps"), b: peer("nas") }, offs) }), NOW)
    assert.deepStrictEqual(TS.rows(m, { offline: "show" }, NOW).rows.length, 6)
    assert.deepStrictEqual(TS.rows(m, { offline: "fold" }, NOW), { rows: TS.sorted(m.peers, "online").slice(0, 2), folded: 4 })
    assert.strictEqual(TS.rows(m, { offline: "fold", unfolded: true }, NOW).rows.length, 6, "the fold opens")
    assert.deepStrictEqual(TS.rows(m, { offline: "hide" }, NOW), { rows: TS.sorted(m.peers, "online").slice(0, 2), folded: 0 })
    const few = TS.model(status(), NOW)
    assert.strictEqual(TS.rows(few, { offline: "fold" }, NOW).folded, 0, "one offline device is not worth a fold")
    assert.strictEqual(TS.rows(few, undefined, NOW).rows.length, 6)
    assert.strictEqual(TS.FOLD_AFTER, 3)
})

test("the bar entry: text, tip and dot", () => {
    const m = TS.model(status(), NOW)
    assert.strictEqual(TS.entryText(m, false, false), "5/6")
    const st = b => TS.model(status({ BackendState: b }), NOW)
    assert.strictEqual(TS.entryText(st("Stopped"), false, false), "Off")
    assert.strictEqual(TS.entryText(st("Stopped"), false, true), "off", "a standing bar")
    assert.strictEqual(TS.entryText(st("NeedsLogin"), false, false), "Sign in", "signed out keeps its words")
    assert.strictEqual(TS.entryText(st("Starting"), false, false), "")
    assert.strictEqual(TS.entryTip(m, false, NOW), "Tailscale: on, 5 of 6 devices online, a device needs a look")
    const calm = TS.model(status({ Peer: { a: peer("vps") } }), NOW)
    assert.strictEqual(TS.entryTip(calm, false, NOW), "Tailscale: on, all 1 devices online")
    assert.strictEqual(TS.entryTip(TS.model(status({ Peer: {} }), NOW), false, NOW), "Tailscale: on, no other devices")
    const tips = ["Stopped", "NeedsLogin", "Starting"].map(b => TS.entryTip(st(b), false, NOW))
    assert.deepStrictEqual(tips, ["Tailscale is off", "Tailscale: signed out", "Tailscale: connecting"])
    assert.strictEqual(TS.entryTip(TS.model("failed to connect to local tailscaled", NOW), false, NOW), "Tailscale: tailscaled isn't running")
    assert.strictEqual(TS.entryTip(TS.model(TS.MISSING_MARK, NOW), false, NOW), "Tailscale isn't installed")
    assert.strictEqual(TS.entryTip(TS.model("permission denied", NOW), false, NOW), "Tailscale: permission denied")
    assert.strictEqual(TS.entryTip({ state: "error", message: "" }, false, NOW), "Tailscale: not answering")
    assert.deepStrictEqual(["on", "off", "signedout", "connecting", "nodaemon"].map(TS.entryDot), ["on", "off", "off", "", ""])
})

test("os icons and the polling pace", () => {
    assert.deepStrictEqual(["android", "iOS", "macOS", "windows", "linux", "plan9", undefined].map(TS.osIcon),
        ["smartphone", "phone_iphone", "laptop_mac", "desktop_windows", "computer", "devices", "devices"])
    assert.strictEqual(TS.pollMs(["bar"], 5), TS.BAR_ONLY_MS, "the bar alone checks every 30 s")
    assert.strictEqual(TS.pollMs(["bar", "popup"], 5), 5000)
    assert.strictEqual(TS.pollMs(["widget"], 120), 60000, "kept within 1 to 60 s")
    assert.strictEqual(TS.pollMs(["widget"], "x"), 5000)
    assert.strictEqual(TS.pollMs(undefined, 5), TS.BAR_ONLY_MS)
})
