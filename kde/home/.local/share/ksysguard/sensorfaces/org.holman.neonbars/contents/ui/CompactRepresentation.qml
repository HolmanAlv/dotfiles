// The panel view of org.kde.ksysguard.horizontalbars, one sensor per widget. install.sh copies the rest of that face.
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.faces as Faces

Faces.CompactSensorFace {
    id: root

    readonly property string sensorId: controller.highPrioritySensorIds[0] ?? ""
    readonly property color barColor: colorSource.map[sensorId] ?? Kirigami.Theme.textColor

    // Room for "CPU 100%", and the gap to the next one
    Layout.minimumWidth: 62
    Layout.preferredWidth: 62
    Layout.maximumWidth: 62

    Sensors.Sensor {
        id: sensor
        sensorId: root.sensorId
        updateRateLimit: root.controller.updateRateLimit
    }

    component SmallText: Text {
        font.family: "M PLUS 1 Neon"
        font.pixelSize: 11
        color: Kirigami.Theme.textColor
        renderType: Text.NativeRendering
    }

    contentItem: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 8
            spacing: 2

            RowLayout {
                spacing: 0
                SmallText { text: root.controller.title }
                Item { Layout.fillWidth: true }
                SmallText { text: Math.round(sensor.value || 0) + "%" }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 3
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                    width: parent.width * Math.min(Math.max((sensor.value || 0) / 100, 0), 1)
                    height: parent.height
                    color: root.barColor
                }
            }
        }
    }
}
