import QtQuick
import "lib"
import "lib/Tailscale.js" as TS

// The desktop widget, inside SekaiPop's card frame (so it uses the card family of colours,
// pSurface / pInk, like the built-in cards).
//
//   full      (default) the diamond, "Tailscale", this machine and the count, its state; then
//             a row per device, a click copying its IP. 374 wide with the frame.
//   compact   a 182 square: the icon, the count large, a dot per device, this machine's state.
//
// The header and the margins are plain card, which SekaiPop keeps as the handle for dragging.
Item {
    id: root

    required property var host

    readonly property var t: root.host.theme
    readonly property var svc: root.host.service
    readonly property var m: root.svc ? root.svc.model : ({ state: "connecting", message: "", authUrl: "", tailnet: "", self: null, peers: [] })
    readonly property real now: root.svc ? root.svc.now : Date.now()
    readonly property string st: root.m.state
    readonly property bool onlyMine: root.host.settings.count === "mine"
    readonly property bool compact: root.host.settings.look === "compact"

    // The card's family of colours.
    readonly property var pal: ({
        surface: root.t.pSurface,
        surfaceHover: root.t.pSurfaceHover,
        surfaceDivider: root.t.pSurfaceDivider,
        ink: root.t.pInk,
        inkSub: root.t.pInkSub,
        line: root.t.pLine,
        lineShadow: root.t.pLineShadow,
        ringWhite: root.t.pRingWhite
    })

    readonly property var counts: TS.count(root.m, root.onlyMine)
    readonly property string selfName: root.m.self ? root.m.self.name : "this machine"

    readonly property var list: TS.rows(root.m, {
        onlyMine: root.onlyMine,
        offline: root.host.settings.offline,
        order: root.host.settings.order,
        unfolded: root.unfolded
    }, root.now)
    property bool unfolded: false

    // More than this many rows, and the rest is one "+N more" line: a desktop card that grows
    // with the tailnet would push everything else off the screen.
    readonly property int maxRows: 10
    readonly property var shownRows: root.list.rows.slice(0, root.maxRows)
    readonly property int moreRows: Math.max(0, root.list.rows.length - root.maxRows)

    property string copied: ""

    Timer {
        id: copiedTimer
        interval: 1500
        onTriggered: root.copied = ""
    }

    implicitWidth: root.compact ? 148 : 340
    implicitHeight: root.compact ? 148 : full.implicitHeight

    // ===== full =====
    Column {
        id: full
        visible: !root.compact
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: 44

            HubBadge {
                id: badge
                theme: root.t
                size: 28
                fill: root.t.pSurfaceDivider
                ink: root.t.pInk
                rim: root.t.pLine
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.left: badge.right
                anchors.leftMargin: 8
                anchors.right: chip.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "Tailscale"
                    color: root.t.pInk
                    font.family: root.t.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.st === "on" ? root.selfName + " · " + TS.countText(root.counts) : TS.entryTip(root.m, root.onlyMine, root.now).replace(/^Tailscale: /, "")
                    color: root.t.pInkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            StatusChip {
                id: chip
                theme: root.t
                pal: root.pal
                chipHeight: 26
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                kind: root.st
                text: root.st === "on" ? "On" : (TS.STATE_WORDS[root.st] || "")
            }
        }

        Repeater {
            model: root.st === "on" ? root.shownRows : []

            delegate: DeviceRow {
                required property var modelData
                width: full.width
                theme: root.t
                pal: root.pal
                device: modelData
                now: root.now
                rich: false
                copied: root.copied === modelData.id ? "ip" : ""
                onCopyRequested: {
                    if (root.svc)
                        root.svc.copy(modelData.ip)
                    root.copied = modelData.id
                    copiedTimer.restart()
                }
            }
        }

        Text {
            visible: root.st === "on" && root.moreRows > 0
            x: 10
            text: "+" + root.moreRows + " more in the bar's popup"
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
        }

        FoldRow {
            visible: root.st === "on" && root.list.folded > 0
            width: full.width
            theme: root.t
            pal: root.pal
            count: root.list.folded
            onClicked: root.unfolded = true
        }

        // a tailnet of one, or this machine off the tailnet: one quiet line (the popup says more)
        Text {
            visible: root.st !== "on" || root.counts.total === 0
            x: 4
            width: parent.width - 8
            topPadding: 2
            wrapMode: Text.Wrap
            text: root.st === "on" ? "No other devices on this tailnet yet."
                : root.st === "off" ? "Tailscale is off on this machine. Turn it on with tailscale up."
                : root.st === "signedout" ? "This machine is signed out of Tailscale."
                : root.st === "nodaemon" ? "tailscaled isn't running. Start it with sudo systemctl enable --now tailscaled."
                : root.st === "missing" ? "Tailscale isn't installed."
                : root.st === "error" ? (root.m.message || "Tailscale didn't answer.")
                : "Asking tailscaled…"
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            lineHeight: 1.3
        }

        KeyCap {
            visible: root.st === "signedout" && root.m.authUrl !== ""
            x: 4
            theme: root.t
            pal: root.pal
            big: true
            icon: "login"
            text: "Sign in"
            onClicked: root.svc && root.svc.signIn()
        }

        Item {
            width: 1
            height: 4
        }
    }

    // ===== compact =====
    Column {
        visible: root.compact
        anchors.centerIn: parent
        width: parent.width
        spacing: 6

        Icon {
            theme: root.t
            anchors.horizontalCenter: parent.horizontalCenter
            name: "hub"
            size: 22
            color: root.st === "on" ? root.t.pInk : root.t.pInkSub
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.st === "on" ? root.counts.online + "/" + root.counts.total : (TS.STATE_WORDS[root.st] || "")
            color: root.st === "on" ? root.t.pInk : root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: root.st === "on" ? 36 : 18
            font.weight: Font.ExtraBold
            font.styleName: root.t.fontStyleBold
            font.features: ({ "tnum": 1 })
        }

        Flow {
            id: dotFlow
            readonly property var devices: root.st === "on" ? TS.sorted(TS.counted(root.m, root.onlyMine), "online").slice(0, 24) : []
            visible: dotFlow.devices.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            // As wide as its dots, up to 120 (seven to a line); a Flow cannot size itself.
            width: Math.min(120, dotFlow.devices.length * 16 - 5)
            spacing: 5

            Repeater {
                // online first, so the dots read as a bar filling up
                model: dotFlow.devices

                delegate: Dot {
                    required property var modelData
                    theme: root.t
                    on: modelData.online
                    size: 11
                    offInk: root.t.pInkSub
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.selfName + " · " + (root.st === "on" ? "on" : (TS.STATE_WORDS[root.st] || "").toLowerCase())
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
        }
    }
}
