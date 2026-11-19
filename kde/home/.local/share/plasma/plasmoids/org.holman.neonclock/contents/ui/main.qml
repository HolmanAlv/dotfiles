import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.calendar as PlasmaCalendar

PlasmoidItem {
    id: root

    property date now: new Date()
    readonly property string day: Qt.formatDate(now, "yyyy-MM-dd")

    preferredRepresentation: compactRepresentation
    toolTipMainText: Qt.formatDate(now, Qt.locale(), Locale.LongFormat)

    Timer {
        interval: 1000 - root.now.getMilliseconds()  // on the second, whatever a busy moment delayed
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    compactRepresentation: MouseArea {
        Layout.minimumWidth: label.implicitWidth + 12
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth

        onClicked: root.expanded = !root.expanded

        Text {
            id: label
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.now, "ddd, dd MMM yyyy HH:mm:ss")
            font.family: "DotGothic16 Neon"
            font.pixelSize: 16  // its native size: anything else blurs the dots
            color: Kirigami.Theme.textColor
            renderType: Text.NativeRendering
        }
    }

    fullRepresentation: PlasmaCalendar.MonthView {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: Kirigami.Units.gridUnit * 20
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: {
            root.day;  // a new date only when the day changes, so an open calendar is not rebuilt every second
            return new Date();
        }
    }
}
