import QtQuick

// "Worth a look": the theme's amber (warnFill), a small diamond with a dark rim. Shape says it
// as much as colour does.
Rectangle {
    required property var theme
    property real size: 9

    width: size
    height: size
    radius: 2
    rotation: 45
    antialiasing: true
    color: theme.warnFill
    border.width: 1.5
    border.color: theme.colBorder
}
