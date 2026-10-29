import QtQuick
import "Tailscale.js" as TS

// One device in the list: its dot, what it runs, its name, and one quiet line (when it was last
// there, a key ending, a relay, an exit node). A click copies its IP.
//
// `rich` is the popup's row (46 tall, the IP under the name, IP / DNS keys on hover, the active
// glyph and the relay mark); without it, the widget's (38 tall, on a tinted plate, the name and
// the line only, in the widget's shorter words).
Item {
    id: root

    required property var theme
    required property var pal
    required property var device
    property real now: Date.now()
    property bool rich: true
    // "ip" or "dns" just went to the clipboard from this row (for 1.5 s), or "".
    property string copied: ""

    signal copyRequested(string what)

    readonly property var info: TS.meta(root.device, root.now, !root.rich)
    readonly property bool hovered: area.containsMouse || ipKey.hovered || dnsKey.hovered

    implicitWidth: 320
    implicitHeight: root.rich ? 46 : 38

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.rich ? (root.hovered ? root.pal.surfaceHover : "transparent") : root.pal.surfaceHover
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.copyRequested("ip")
    }

    Row {
        id: lead
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Dot {
            theme: root.theme
            anchors.verticalCenter: parent.verticalCenter
            on: root.device.online
            size: root.rich ? 12 : 11
            offInk: root.pal.inkSub
        }

        Icon {
            theme: root.theme
            anchors.verticalCenter: parent.verticalCenter
            name: TS.osIcon(root.device.os)
            size: root.rich ? 16 : 15
            color: root.pal.inkSub
        }
    }

    Column {
        anchors.left: lead.right
        anchors.leftMargin: 10
        anchors.right: tail.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        Text {
            width: parent.width
            text: root.device.name
            elide: Text.ElideRight
            color: root.device.online ? root.pal.ink : root.pal.inkSub
            font.family: root.theme.fontFamily
            font.pixelSize: root.rich ? 14 : 14
            font.weight: Font.ExtraBold
            font.styleName: root.theme.fontStyleBold
        }

        Text {
            visible: root.rich
            width: parent.width
            text: root.device.ip
            elide: Text.ElideRight
            color: root.pal.inkSub
            font.family: "monospace"
            font.pixelSize: 11
        }
    }

    // The right end: the quiet line, or (popup, hovered) the IP and DNS keys.
    Item {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: keys.visible ? keys.implicitWidth : line.implicitWidth
        height: Math.max(keys.implicitHeight, line.implicitHeight)

        Row {
            id: line
            visible: !keys.visible
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            WarnDiamond {
                theme: root.theme
                visible: root.info.warn
                anchors.verticalCenter: parent.verticalCenter
            }

            // Traffic flowing with it right now: a slow pulse.
            Icon {
                theme: root.theme
                visible: root.rich && root.device.online && root.device.active
                anchors.verticalCenter: parent.verticalCenter
                name: "swap_vert"
                size: 13
                color: root.pal.inkSub
                SequentialAnimation on opacity {
                    running: root.rich && root.device.active && root.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
                }
            }

            Icon {
                theme: root.theme
                visible: root.rich && root.device.online && root.device.relay !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: "alt_route"
                size: 13
                color: root.pal.inkSub
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: !root.rich && root.copied === "ip" ? "IP copied" : root.info.text
                color: root.pal.inkSub
                font.family: root.theme.fontFamily
                font.pixelSize: root.rich ? 12 : 11
                font.weight: Font.Bold
            }
        }

        Row {
            id: keys
            visible: root.rich && (root.hovered || root.copied !== "")
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            KeyCap {
                id: ipKey
                readonly property bool hovered: hov.hovered
                theme: root.theme
                pal: root.pal
                keyHeight: 26
                icon: root.copied === "ip" ? "check" : "content_copy"
                text: root.copied === "ip" ? "Copied" : "IP"
                lit: root.copied === "ip"
                onClicked: root.copyRequested("ip")
                HoverHandler { id: hov }
            }

            KeyCap {
                id: dnsKey
                readonly property bool hovered: hov2.hovered
                visible: root.device.dns !== ""
                theme: root.theme
                pal: root.pal
                keyHeight: 26
                text: root.copied === "dns" ? "Copied" : "DNS"
                lit: root.copied === "dns"
                onClicked: root.copyRequested("dns")
                HoverHandler { id: hov2 }
            }
        }
    }
}
