import QtQuick
import "lib"
import "lib/Tailscale.js" as TS

// The card under the bar entry (SekaiPop draws the card, places it, pops it in and out, and
// closes it on a click away or Escape; this is its face, 354 wide inside the card's outline).
//
//   header      the diamond, "Tailscale", the tailnet, and this machine's state
//   this one    its name, its IP and MagicDNS name with a copy key each (when on)
//   devices     every other device: online by name, then offline by last seen; 9 rows, then it
//               scrolls under a fade; more than 3 offline fold under "Offline · N"
//   or          what to do about the state this machine is in (off, signed out, no daemon)
//   footer      Admin console, and when it last checked
//
// Clicking a row copies its IP; hovering it shows IP and DNS keys. doc/DESIGN.md has the rest.
Item {
    id: root

    required property var host

    readonly property var t: root.host.theme
    readonly property var svc: root.host.service
    readonly property var m: root.svc ? root.svc.model : ({ state: "connecting", message: "", authUrl: "", tailnet: "", self: null, peers: [] })
    readonly property real now: root.svc ? root.svc.now : Date.now()
    readonly property string st: root.m.state
    readonly property bool onlyMine: root.host.settings.count === "mine"

    // The bar's family of colours (a popup sits on the bar's surface, not a card's).
    readonly property var pal: ({
        surface: root.t.surface,
        surfaceHover: root.t.surfaceHover,
        surfaceDivider: root.t.surfaceDivider,
        ink: root.t.ink,
        inkSub: root.t.inkSub,
        line: root.t.line,
        lineShadow: root.t.lineShadow,
        ringWhite: root.t.ringWhite
    })

    readonly property var counts: TS.count(root.m, root.onlyMine)
    property bool unfolded: false
    readonly property var list: TS.rows(root.m, {
        onlyMine: root.onlyMine,
        offline: root.host.settings.offline,
        order: root.host.settings.order,
        unfolded: root.unfolded
    }, root.now)

    // What was just copied, as "<device id>:ip" (for 1.5 s), so its key can say "Copied".
    property string copied: ""

    function copy(id, what, text) {
        if (!root.svc || !text)
            return
        root.svc.copy(text)
        root.copied = id + ":" + what
        copiedTimer.restart()
    }

    Timer {
        id: copiedTimer
        interval: 1500
        onTriggered: root.copied = ""
    }

    // Folded again whenever the popup opens.
    Connections {
        target: root.host.popup
        function onOpenChanged() {
            if (!root.host.popup.open)
                root.unfolded = false
        }
    }

    readonly property int rowH: 46
    readonly property int maxRows: 9

    implicitWidth: 354
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width

        // ===== header =====
        Item {
            width: parent.width
            height: 60

            HubBadge {
                id: badge
                theme: root.t
                x: 13
                anchors.verticalCenter: parent.verticalCenter
                rim: root.t.line
            }

            Column {
                anchors.left: badge.right
                anchors.leftMargin: 9
                anchors.right: chip.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "Tailscale"
                    color: root.t.ink
                    font.family: root.t.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.m.tailnet !== "" ? root.m.tailnet : "no tailnet"
                    color: root.t.inkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            StatusChip {
                id: chip
                theme: root.t
                pal: root.pal
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                kind: root.st
                text: TS.STATE_WORDS[root.st] || ""
            }
        }

        // ===== this machine =====
        Item {
            visible: root.st === "on" && !!root.m.self
            width: parent.width
            height: me.height

            Rectangle {
                id: me
                x: 12
                width: parent.width - 24
                height: meCol.implicitHeight + 20
                radius: 12
                color: root.t.surfaceHover

                Column {
                    id: meCol
                    x: 12
                    y: 10
                    width: parent.width - 24
                    spacing: 6

                    Row {
                        spacing: 8

                        Icon {
                            theme: root.t
                            anchors.verticalCenter: parent.verticalCenter
                            name: root.m.self ? TS.osIcon(root.m.self.os) : "devices"
                            size: 16
                            color: root.t.ink
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.m.self ? root.m.self.name : ""
                            color: root.t.ink
                            font.family: root.t.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.ExtraBold
                            font.styleName: root.t.fontStyleBold
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: tag.implicitWidth + 14
                            height: 20
                            radius: 6
                            color: root.t.surface
                            border.width: 2
                            border.color: root.t.line

                            Text {
                                id: tag
                                anchors.centerIn: parent
                                text: "THIS MACHINE"
                                color: root.t.inkSub
                                font.family: root.t.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.ExtraBold
                                font.letterSpacing: 0.6
                            }
                        }
                    }

                    Repeater {
                        model: root.m.self ? [{ what: "ip", text: root.m.self.ip }, { what: "dns", text: root.m.self.dns }].filter(x => x.text !== "") : []

                        delegate: Item {
                            required property var modelData
                            width: meCol.width
                            height: 31

                            Text {
                                anchors.left: parent.left
                                anchors.right: copyKey.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: modelData.text
                                color: root.t.ink
                                font.family: "monospace"
                                font.pixelSize: 13
                            }

                            KeyCap {
                                id: copyKey
                                theme: root.t
                                pal: root.pal
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                icon: root.copied === "self:" + modelData.what ? "check" : "content_copy"
                                lit: root.copied === "self:" + modelData.what
                                onClicked: root.copy("self", modelData.what, modelData.text)
                            }
                        }
                    }
                }
            }
        }

        // ===== devices =====
        SectionHead {
            visible: root.st === "on" || root.st === "connecting"
            theme: root.t
            label: "Devices"
            value: root.st === "connecting" ? "connecting…" : TS.countText(root.counts)
        }

        Item {
            id: listBox
            visible: root.st === "on" && (root.list.rows.length > 0 || root.list.folded > 0)
            width: parent.width
            readonly property real full: rows.implicitHeight
            readonly property real cap: Math.min(root.rowH * root.maxRows, Math.max(root.rowH * 3,
                root.host.popup.maxHeight - 300))
            readonly property bool scrolls: listBox.full > listBox.cap
            height: Math.min(listBox.full, listBox.cap)
            clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                contentHeight: rows.implicitHeight
                interactive: listBox.scrolls
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: rows
                    width: flick.width

                    Repeater {
                        model: root.list.rows

                        delegate: DeviceRow {
                            required property var modelData
                            width: rows.width
                            theme: root.t
                            pal: root.pal
                            device: modelData
                            now: root.now
                            rich: true
                            copied: root.copied.indexOf(modelData.id + ":") === 0 ? root.copied.slice(modelData.id.length + 1) : ""
                            onCopyRequested: what => root.copy(modelData.id, what, what === "dns" ? modelData.dns : modelData.ip)
                        }
                    }

                    FoldRow {
                        visible: root.list.folded > 0
                        width: rows.width
                        theme: root.t
                        pal: root.pal
                        count: root.list.folded
                        onClicked: root.unfolded = true
                    }
                }
            }

            // the scroll bar, and the fade that says there is more below
            Rectangle {
                visible: listBox.scrolls
                x: parent.width - 7
                y: 6 + (listBox.height - 12 - height) * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
                width: 5
                height: Math.max(24, (listBox.height - 12) * listBox.height / Math.max(1, listBox.full))
                radius: 3
                color: root.t.line
                opacity: 0.6
            }

            Rectangle {
                visible: listBox.scrolls && !flick.atYEnd
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 34
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: root.t.surface }
                }
            }
        }

        // a tailnet of one
        Text {
            visible: root.st === "on" && root.counts.total === 0
            x: 16
            width: parent.width - 32
            topPadding: 6
            bottomPadding: 4
            wrapMode: Text.Wrap
            text: "No other devices on this tailnet yet. Sign in to Tailscale on another one and it shows up here."
            color: root.t.inkSub
            font.family: root.t.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            lineHeight: 1.3
        }

        // connecting: three rows in outline
        Column {
            visible: root.st === "connecting"
            x: 18
            topPadding: 10
            bottomPadding: 8
            spacing: 18

            Repeater {
                model: [130, 96, 150]

                delegate: Row {
                    required property var modelData
                    spacing: 12

                    Dot {
                        theme: root.t
                        on: false
                        offInk: root.t.inkSub
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: modelData
                        height: 12
                        radius: 6
                        color: root.t.surfaceDivider
                    }
                }
            }
        }

        // ===== this machine is off the tailnet: what to do =====
        StateMessage {
            visible: root.st === "off"
            theme: root.t
            pal: root.pal
            title: "Tailscale is off on this machine."
            lines: ["It's signed in, just not connected. Turning it on needs root, so it's a command for now:"]
            command: "tailscale up"
            after: "Your devices show here again once it's on."
            onCopyCommand: text => root.svc && root.svc.copy(text)
        }

        StateMessage {
            visible: root.st === "signedout"
            theme: root.t
            pal: root.pal
            title: "This machine is signed out of Tailscale."
            lines: [root.m.authUrl !== ""
                ? "Sign in to see your devices. It opens Tailscale's sign-in page in your browser."
                : "Sign in to see your devices. Signing this machine in needs root, so it's a command for now:"]
            command: root.m.authUrl !== "" ? "" : "sudo tailscale up"
            action: root.m.authUrl !== "" ? "Sign in" : ""
            actionIcon: "login"
            onCopyCommand: text => root.svc && root.svc.copy(text)
            onActivated: {
                if (root.svc)
                    root.svc.signIn()
                root.host.popup.close()
            }
        }

        StateMessage {
            visible: root.st === "nodaemon"
            theme: root.t
            pal: root.pal
            title: "tailscaled isn't running."
            lines: ["The tailscale command is here, but the service it talks to is stopped. Start it, and keep it on after a restart, with:"]
            command: "sudo systemctl enable --now tailscaled"
            onCopyCommand: text => root.svc && root.svc.copy(text)
        }

        StateMessage {
            visible: root.st === "missing"
            theme: root.t
            pal: root.pal
            title: "Tailscale isn't installed."
            lines: ["There is no tailscale command on the PATH of the shell. Install Tailscale, then sign this machine in."]
        }

        StateMessage {
            visible: root.st === "error"
            theme: root.t
            pal: root.pal
            title: "Tailscale didn't answer."
            lines: [root.m.message || "tailscale status said nothing."]
        }

        // ===== footer =====
        Item {
            width: parent.width
            height: 8
        }

        Rectangle {
            width: parent.width
            height: 2.5
            color: root.t.surfaceDivider
        }

        Item {
            width: parent.width
            height: admin.implicitHeight + 22

            KeyCap {
                id: admin
                theme: root.t
                pal: root.pal
                x: 14
                y: 10
                keyHeight: 32
                fontSize: 12
                iconSize: 14
                icon: "open_in_new"
                text: "Admin console"
                onClicked: {
                    if (root.svc)
                        root.svc.open(root.svc.adminUrl)
                    root.host.popup.close()
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: admin.verticalCenter
                text: root.svc ? TS.checkedText(root.svc.checkedAt, root.now) : ""
                color: root.t.inkSub
                font.family: root.t.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }
}
