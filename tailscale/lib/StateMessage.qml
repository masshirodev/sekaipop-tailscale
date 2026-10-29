import QtQuick

// What the popup says when this machine is off the tailnet: one plain sentence, a quieter one
// on what to do, and the command to copy (or the key to press) that does it.
Column {
    id: root

    required property var theme
    required property var pal
    property string title: ""
    property var lines: []
    // A command to copy (turning Tailscale on needs root, so it is a command, not a button).
    property string command: ""
    property string after: ""
    // A key that does it instead (Sign in).
    property string action: ""
    property string actionIcon: ""

    signal copyCommand(string text)
    signal activated()

    property bool copied: false

    x: 16
    width: (parent ? parent.width : 354) - 32
    topPadding: 8
    bottomPadding: 6
    spacing: 10

    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: root.title
        color: root.pal.ink
        font.family: root.theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
        lineHeight: 1.3
    }

    Repeater {
        model: root.lines

        delegate: Text {
            required property var modelData
            width: root.width
            wrapMode: Text.Wrap
            text: modelData
            color: root.pal.inkSub
            font.family: root.theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            lineHeight: 1.3
        }
    }

    Rectangle {
        visible: root.command !== ""
        width: parent.width
        // A long command wraps rather than hiding its end (the key copies it whole either way).
        height: Math.max(44, cmdText.implicitHeight + 20)
        radius: 10
        color: root.pal.surfaceHover

        Text {
            id: cmdText
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: key.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.WrapAnywhere
            text: root.command
            color: root.pal.ink
            font.family: "monospace"
            font.pixelSize: 12
        }

        KeyCap {
            id: key
            theme: root.theme
            pal: root.pal
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            icon: root.copied ? "check" : "content_copy"
            lit: root.copied
            onClicked: {
                root.copyCommand(root.command)
                root.copied = true
                copiedTimer.restart()
            }
        }

        Timer {
            id: copiedTimer
            interval: 1500
            onTriggered: root.copied = false
        }
    }

    Text {
        visible: root.after !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: root.after
        color: root.pal.inkSub
        font.family: root.theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    KeyCap {
        visible: root.action !== ""
        theme: root.theme
        pal: root.pal
        big: true
        icon: root.actionIcon
        text: root.action
        onClicked: root.activated()
    }
}
