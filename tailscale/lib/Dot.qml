import QtQuick

// A device's state, by shape as well as colour: online is a filled accent dot with a dark
// rim, offline a hollow ring in the quiet ink. It fills or empties in 150 ms.
Item {
    id: root

    required property var theme
    property bool on: true
    property real size: 12
    // The quiet ink of the surface it sits on (inkSub in the bar's family, pInkSub on a card).
    property color offInk: root.theme.inkSub

    implicitWidth: root.size
    implicitHeight: root.size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.on ? root.theme.accentMint : "transparent"
        border.width: 2.5
        border.color: root.on ? root.theme.colBorder : root.offInk

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }
}
