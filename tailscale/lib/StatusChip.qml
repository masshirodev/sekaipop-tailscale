import QtQuick

// This machine's state in the header: "Connected" on the accent gradient with a dark dot, any
// other state on the plain surface with a hollow one, and a small spinner while connecting.
Item {
    id: root

    required property var theme
    required property var pal
    property string kind: "on"
    property string text: ""
    property real chipHeight: 28

    readonly property bool on: root.kind === "on"

    implicitWidth: row.implicitWidth + 22
    implicitHeight: root.chipHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.width: 2.5
        border.color: root.on ? root.theme.colBorder : root.pal.line
        color: root.pal.surface
        gradient: root.on ? accent : null

        Gradient {
            id: accent
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.theme.accentMint }
            GradientStop { position: 1; color: root.theme.accentCyan }
        }

        // the white ring inside the lit chip
        Rectangle {
            visible: root.on
            anchors.fill: parent
            anchors.margins: 2.5
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: root.pal.ringWhite
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Item {
            width: 9
            height: 9
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                visible: root.kind !== "connecting"
                anchors.fill: parent
                radius: width / 2
                color: root.on ? root.theme.colBorder : "transparent"
                border.width: root.on ? 0 : 2
                border.color: root.pal.inkSub
            }

            // connecting: a ring with a gap, turning
            Rectangle {
                visible: root.kind === "connecting"
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2.5
                border.color: root.pal.ink
                RotationAnimation on rotation {
                    running: root.kind === "connecting" && root.visible
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                }

                Rectangle {
                    width: 4
                    height: 4
                    x: parent.width - 3
                    y: parent.height / 2 - 2
                    color: root.pal.surface
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.on ? root.theme.colBorder : root.pal.ink
            font.family: root.theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: root.theme.fontStyleBold
        }
    }
}
