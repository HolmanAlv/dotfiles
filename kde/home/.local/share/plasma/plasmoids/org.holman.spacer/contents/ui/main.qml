import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// The stock panelspacer pairs up with a second one and centers on the panel's middle.
// This one has no such logic, so the layout splits the free room evenly between them.
PlasmoidItem {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: 1
    Layout.minimumHeight: 1
    Layout.preferredWidth: 1
    Layout.preferredHeight: 1

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {}
}
