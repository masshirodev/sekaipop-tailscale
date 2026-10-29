import QtQuick
import "lib"
import "lib/Tailscale.js" as TS

// The bar entry (SekaiPop draws the pill around it, presses it while the popup is open, and
// opens the popup on a left click). The icon says this machine's state; next to it, how many
// devices are up ("5/6"), or "Off" / "Sign in". On a standing bar the count goes under the
// icon, as the weather pill's temperature does.
//
//   on          the icon, "5/6"; a small amber diamond when a device needs a look
//   off         the icon dimmed, "Off" dimmed
//   signedout   the icon, "Sign in"
//   connecting  the icon, three dots blinking
//   nodaemon    the icon dimmed and struck through
//   missing     not on the bar at all (unless "Hide without Tailscale" is off)
// "Icon only" leaves the words out and puts a status dot on the icon instead.
Item {
    id: root

    required property var host

    readonly property var svc: root.host.service
    readonly property var m: root.svc ? root.svc.model : ({ state: "connecting", peers: [] })
    readonly property real now: root.svc ? root.svc.now : Date.now()
    readonly property bool onlyMine: root.host.settings.count === "mine"
    readonly property bool iconOnly: root.host.settings.barLook === "icon"
    readonly property bool vertical: root.host.bar.vertical
    readonly property string state_: root.m.state

    readonly property string text: root.iconOnly ? "" : TS.entryText(root.m, root.onlyMine, root.vertical)
    readonly property bool dim: root.state_ === "off" || root.state_ === "nodaemon" || root.state_ === "error"
    readonly property bool struck: root.state_ === "nodaemon" || root.state_ === "error"
    readonly property bool attention: root.state_ === "on" && TS.anyAttention(root.m, root.onlyMine, root.now)
    readonly property string dot: root.iconOnly ? TS.entryDot(root.state_) : ""
    readonly property bool dots: root.state_ === "connecting" && !root.iconOnly

    // SekaiPop reads these two.
    property string tip: TS.entryTip(root.m, root.onlyMine, root.now)
    property bool present: !(root.state_ === "missing" && root.host.settings.hideWhenMissing)

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Grid {
        id: layout
        columns: root.vertical ? 1 : 3
        rowSpacing: 2
        columnSpacing: 7
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Item {
            width: 18
            height: 18

            Icon {
                theme: root.host.theme
                anchors.fill: parent
                name: "hub"
                size: 18
                color: root.dim ? root.host.bar.inkSub : root.host.bar.ink
            }

            // no tailscaled: struck through
            Rectangle {
                visible: root.struck
                anchors.centerIn: parent
                width: 22
                height: 2.5
                radius: 1.25
                rotation: -45
                antialiasing: true
                color: root.host.bar.ink
            }

            WarnDiamond {
                theme: root.host.theme
                visible: root.attention
                x: parent.width - 5
                y: -4
            }

            // icon only: this machine's state on the icon
            Rectangle {
                visible: root.dot !== ""
                x: parent.width - 5
                y: parent.height - 6
                width: 9
                height: 9
                radius: 4.5
                color: root.dot === "on" ? root.host.theme.accentMint : root.host.theme.surface
                border.width: 2
                border.color: root.dot === "on" ? root.host.theme.colBorder : root.host.bar.ink
            }
        }

        Text {
            visible: root.text !== ""
            text: root.text
            color: root.dim ? root.host.bar.inkSub : root.host.bar.ink
            font.family: root.host.theme.fontFamily
            font.pixelSize: root.vertical ? 11 : 12
            font.weight: Font.ExtraBold
            font.styleName: root.host.theme.fontStyleBold
            font.features: ({ "tnum": 1 })
        }

        // connecting: three dots, blinking one after the other
        Row {
            visible: root.dots
            spacing: 2
            height: 6

            Repeater {
                model: 3

                delegate: Rectangle {
                    required property int index
                    width: 3
                    height: 3
                    radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.host.bar.ink

                    SequentialAnimation on opacity {
                        running: root.dots
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 200 }
                        NumberAnimation { to: 0.2; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                        PauseAnimation { duration: (2 - index) * 200 }
                    }
                }
            }
        }
    }
}
