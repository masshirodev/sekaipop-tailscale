import QtQuick
import Quickshell
import Quickshell.Io
import "lib/Tailscale.js" as TS

// The one place that asks Tailscale (SekaiPop's plugin service, docs/PLUGINS.md there): the bar
// entry on every monitor, the popup and the widget all read `model` from here, so they agree and
// `tailscale status` runs once per check, not once per surface.
//
// It asks only while something shows it (host.working): every 30 s for the bar alone, at the
// "Check every" setting while the popup or the widget is up (host.wanted), and at once when the
// popup opens. `tailscale status --json` needs no root and no token.
QtObject {
    id: root

    required property var host

    // TS.model(): { state, message, authUrl, tailnet, self, peers }. "connecting" until the
    // first answer, which reads as "asking tailscaled…".
    property var model: ({ state: "connecting", message: "", authUrl: "", tailnet: "", self: null, peers: [] })
    // When the last answer came (ms), 0 before the first.
    property real checkedAt: 0
    // A clock for "2 h ago" and "checked 2 s ago", ticking once a second while a popup or the
    // widget shows (the bar has no ages to keep fresh).
    property real now: Date.now()

    readonly property var wanted: root.host.wanted
    readonly property bool looking: root.wanted.indexOf("popup") >= 0 || root.wanted.indexOf("widget") >= 0
    readonly property bool popupUp: root.wanted.indexOf("popup") >= 0

    function check() {
        if (!root.proc.running)
            root.proc.running = true
    }

    // Opening the popup asks at once, so it never opens on an answer half a minute old.
    onPopupUpChanged: {
        if (root.popupUp)
            root.check()
    }

    property Timer poll: Timer {
        running: root.host.working
        repeat: true
        triggeredOnStart: true
        interval: TS.pollMs(root.wanted, root.host.settings.checkSeconds)
        onTriggered: root.check()
    }

    property Timer clock: Timer {
        running: root.looking
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: root.now = Date.now()
    }

    // stdout and stderr together: an error ("failed to connect to local tailscaled") is read
    // the same way as an answer (TS.classify). A missing command says so with a marker of its own.
    property Process proc: Process {
        command: ["sh", "-c", "command -v tailscale >/dev/null 2>&1 || { echo " + TS.MISSING_MARK + "; exit 0; }; exec tailscale status --json 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = Date.now()
                root.model = TS.model(text, t)
                root.checkedAt = t
                root.now = t
            }
        }
    }

    // ===== actions the surfaces share =====
    function copy(text) {
        if (text)
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text])
    }

    function open(url) {
        if (url)
            Quickshell.execDetached(["xdg-open", url])
    }

    readonly property string adminUrl: "https://login.tailscale.com/admin/machines"

    // Signed out: the sign-in page tailscale gave. (Without one there is nothing a browser can
    // do for this machine; the popup shows the command instead.)
    function signIn() {
        root.open(root.model.authUrl)
    }
}
