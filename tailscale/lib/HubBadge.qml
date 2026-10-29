import QtQuick

// The header's diamond with the plugin's icon (a Material Symbol stands for Tailscale; its logo
// is theirs).
Item {
    id: root

    required property var theme
    property color fill: root.theme.chipFill
    property color ink: root.theme.chipInk
    property color rim: root.theme.line
    property real size: 30

    implicitWidth: root.size + 6
    implicitHeight: root.size + 6

    Rectangle {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        radius: 8
        rotation: 45
        antialiasing: true
        color: root.fill
        border.width: 2.5
        border.color: root.rim
    }

    Icon {
        theme: root.theme
        anchors.centerIn: parent
        name: "hub"
        size: root.size * 0.57
        color: root.ink
    }
}
