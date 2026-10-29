import QtQuick
import QtQuick.Shapes

// "Offline · 4": the offline devices folded into one line at the end of the list, in a dashed
// outline (it is a placeholder for rows, not a row). A click opens it.
Item {
    id: root

    required property var theme
    required property var pal
    property int count: 0

    signal clicked()

    implicitWidth: 300
    implicitHeight: 46

    Item {
        id: box
        y: 2
        width: parent.width
        height: 40

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: area.containsMouse ? root.pal.inkSub : root.pal.surfaceDivider
                strokeWidth: 2
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 2]
                fillColor: "transparent"
                PathRectangle {
                    x: 1
                    y: 1
                    width: box.width - 2
                    height: box.height - 2
                    radius: 10
                }
            }
        }

        Row {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Dot {
                theme: root.theme
                on: false
                offInk: root.pal.inkSub
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Offline · " + root.count
                color: root.pal.inkSub
                font.family: root.theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.ExtraBold
            }
        }

        Icon {
            theme: root.theme
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            name: "expand_more"
            size: 16
            color: root.pal.inkSub
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
