import QtQuick

// "DEVICES · 5 of 6 online": the list's heading, the count in full ink.
Item {
    id: root

    required property var theme
    property string label: ""
    property string value: ""

    width: parent ? parent.width : 300
    implicitHeight: 38

    Row {
        x: 16
        y: 14
        spacing: 8

        Text {
            text: root.label.toUpperCase()
            color: root.theme.inkSub
            font.family: root.theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.letterSpacing: 1.1
        }

        Text {
            text: "·"
            color: root.theme.inkSub
            font.family: root.theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
        }

        Text {
            text: root.value.toUpperCase()
            color: root.theme.ink
            font.family: root.theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.letterSpacing: 1.1
        }
    }
}
