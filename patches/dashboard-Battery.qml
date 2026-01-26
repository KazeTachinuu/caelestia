pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    readonly property int padding: Appearance.padding.large

    spacing: Appearance.spacing.large

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Appearance.spacing.large * 3

        // Battery health (left) - calculated from energyCapacity / design capacity
        Resource {
            Layout.alignment: Qt.AlignVCenter
            Layout.topMargin: root.padding
            Layout.bottomMargin: root.padding
            Layout.leftMargin: root.padding * 2

            // Design capacity is 57 Wh for this battery
            readonly property real designCapacity: 57.0
            readonly property real healthCalc: UPower.displayDevice.energyCapacity > 0 ? (UPower.displayDevice.energyCapacity / designCapacity) * 100 : 0

            value1: healthCalc / 100
            value2: {
                const rate = Math.abs(UPower.displayDevice.changeRate);
                return rate > 0 ? Math.min(1, rate / 45) : 0;
            }

            label1: healthCalc > 0 ? `${Math.round(healthCalc)}%` : "--"
            label2: {
                const rate = Math.abs(UPower.displayDevice.changeRate);
                return rate > 0 ? `${rate.toFixed(1)}W` : "--";
            }

            sublabel1: qsTr("Health")
            sublabel2: qsTr("Power")

            fg1: {
                if (healthCalc >= 80) return Colours.palette.m3primary;
                if (healthCalc >= 50) return Colours.palette.m3tertiary;
                return Colours.palette.m3error;
            }
            bg1: {
                if (healthCalc >= 80) return Colours.palette.m3primaryContainer;
                if (healthCalc >= 50) return Colours.palette.m3tertiaryContainer;
                return Colours.palette.m3errorContainer;
            }
            fg2: Colours.palette.m3secondary
            bg2: Colours.palette.m3secondaryContainer
        }

        // Battery percentage (center, primary)
        Resource {
            Layout.alignment: Qt.AlignVCenter
            Layout.topMargin: root.padding
            Layout.bottomMargin: root.padding

            primary: true

            value1: UPower.displayDevice.percentage
            value2: {
                if (UPower.onBattery) {
                    const timeRemaining = UPower.displayDevice.timeToEmpty;
                    // 4 hours max (14400 seconds)
                    return Math.min(1, timeRemaining / 14400);
                } else {
                    const timeToFull = UPower.displayDevice.timeToFull;
                    // 2 hours to full charge
                    return timeToFull > 0 ? Math.max(0, 1 - timeToFull / 7200) : 1;
                }
            }

            label1: UPower.displayDevice.isLaptopBattery ? `${Math.round(UPower.displayDevice.percentage * 100)}%` : "--"
            label2: {
                function formatTime(seconds) {
                    if (seconds <= 0) return UPower.onBattery ? "..." : qsTr("Full");
                    const h = Math.floor(seconds / 3600);
                    const m = Math.floor((seconds % 3600) / 60);
                    if (h > 0) return `${h}h${m}m`;
                    return `${m}m`;
                }
                if (!UPower.displayDevice.isLaptopBattery) return "--";
                return UPower.onBattery ? formatTime(UPower.displayDevice.timeToEmpty) : formatTime(UPower.displayDevice.timeToFull);
            }

            sublabel1: qsTr("Battery")
            sublabel2: UPower.onBattery ? qsTr("Remaining") : qsTr("To full")

            fg1: UPower.displayDevice.percentage > 0.2 ? Colours.palette.m3primary : Colours.palette.m3error
            bg1: UPower.displayDevice.percentage > 0.2 ? Colours.palette.m3primaryContainer : Colours.palette.m3errorContainer
            fg2: UPower.onBattery ? Colours.palette.m3secondary : Colours.palette.m3tertiary
            bg2: UPower.onBattery ? Colours.palette.m3secondaryContainer : Colours.palette.m3tertiaryContainer
        }

        // Power profile (right)
        Resource {
            Layout.alignment: Qt.AlignVCenter
            Layout.topMargin: root.padding
            Layout.bottomMargin: root.padding
            Layout.rightMargin: root.padding * 2

            value1: {
                const profile = PowerProfiles.profile;
                if (profile === PowerProfile.PowerSaver) return 0.33;
                if (profile === PowerProfile.Balanced) return 0.66;
                return 1;
            }
            value2: {
                const state = UPower.displayDevice.state;
                if (state === UPowerDeviceState.Charging) return 0.75;
                if (state === UPowerDeviceState.FullyCharged) return 1;
                if (state === UPowerDeviceState.Discharging) return 0.5;
                return 0.25;
            }

            label1: {
                const profile = PowerProfiles.profile;
                if (profile === PowerProfile.PowerSaver) return qsTr("Saver");
                if (profile === PowerProfile.Balanced) return qsTr("Balanced");
                return qsTr("Perf");
            }
            label2: {
                const state = UPower.displayDevice.state;
                if (state === UPowerDeviceState.Charging) return qsTr("Charging");
                if (state === UPowerDeviceState.FullyCharged) return qsTr("Full");
                if (state === UPowerDeviceState.Discharging) return qsTr("Draining");
                if (state === UPowerDeviceState.PendingCharge) return qsTr("Pending");
                return qsTr("Unknown");
            }

            sublabel1: qsTr("Profile")
            sublabel2: qsTr("Status")

            fg1: {
                const profile = PowerProfiles.profile;
                if (profile === PowerProfile.PowerSaver) return Colours.palette.m3tertiary;
                if (profile === PowerProfile.Balanced) return Colours.palette.m3primary;
                return Colours.palette.m3error;
            }
            bg1: {
                const profile = PowerProfiles.profile;
                if (profile === PowerProfile.PowerSaver) return Colours.palette.m3tertiaryContainer;
                if (profile === PowerProfile.Balanced) return Colours.palette.m3primaryContainer;
                return Colours.palette.m3errorContainer;
            }
            fg2: Colours.palette.m3secondary
            bg2: Colours.palette.m3secondaryContainer
        }
    }

    // Power profile selector
    StyledRect {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: profileRow.implicitWidth + Appearance.padding.large * 2
        implicitHeight: profileRow.implicitHeight + Appearance.padding.normal * 2
        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.large

        Row {
            id: profileRow
            anchors.centerIn: parent
            spacing: Appearance.spacing.large

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Power profile:")
                color: Colours.palette.m3onSurfaceVariant
            }

            Row {
                spacing: Appearance.spacing.small

                ProfileButton {
                    profile: PowerProfile.PowerSaver
                    icon: "energy_savings_leaf"
                    label: qsTr("Saver")
                }

                ProfileButton {
                    profile: PowerProfile.Balanced
                    icon: "balance"
                    label: qsTr("Balanced")
                }

                ProfileButton {
                    profile: PowerProfile.Performance
                    icon: "rocket_launch"
                    label: qsTr("Performance")
                }
            }
        }
    }

    // Degradation warning
    Loader {
        Layout.alignment: Qt.AlignHCenter
        active: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

        sourceComponent: StyledRect {
            implicitWidth: degradeRow.implicitWidth + Appearance.padding.large * 2
            implicitHeight: degradeRow.implicitHeight + Appearance.padding.normal * 2
            color: Colours.palette.m3errorContainer
            radius: Appearance.rounding.normal

            Row {
                id: degradeRow
                anchors.centerIn: parent
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "warning"
                    color: Colours.palette.m3onErrorContainer
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Performance degraded: %1").arg(PerformanceDegradationReason.toString(PowerProfiles.degradationReason))
                    color: Colours.palette.m3onErrorContainer
                }
            }
        }
    }

    component ProfileButton: StyledRect {
        id: profileBtn

        required property int profile
        required property string icon
        required property string label

        readonly property bool active: PowerProfiles.profile === profile

        implicitWidth: btnContent.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: btnContent.implicitHeight + Appearance.padding.small * 2
        color: active ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
        radius: Appearance.rounding.full

        Row {
            id: btnContent
            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: profileBtn.icon
                color: profileBtn.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                fill: profileBtn.active ? 1 : 0

                Behavior on fill {
                    Anim {}
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: profileBtn.label
                color: profileBtn.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.small
            }
        }

        StateLayer {
            radius: parent.radius
            color: profileBtn.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

            function onClicked(): void {
                PowerProfiles.profile = profileBtn.profile;
            }
        }

        Behavior on color {
            CAnim {}
        }
    }

    component Resource: Item {
        id: res

        required property real value1
        required property real value2
        required property string sublabel1
        required property string sublabel2
        required property string label1
        required property string label2

        property bool primary
        readonly property real primaryMult: primary ? 1.2 : 1

        readonly property real thickness: Config.dashboard.sizes.resourceProgessThickness * primaryMult

        property color fg1: Colours.palette.m3primary
        property color fg2: Colours.palette.m3secondary
        property color bg1: Colours.palette.m3primaryContainer
        property color bg2: Colours.palette.m3secondaryContainer

        implicitWidth: Config.dashboard.sizes.resourceSize * primaryMult
        implicitHeight: Config.dashboard.sizes.resourceSize * primaryMult

        onValue1Changed: canvas.requestPaint()
        onValue2Changed: canvas.requestPaint()
        onFg1Changed: canvas.requestPaint()
        onFg2Changed: canvas.requestPaint()
        onBg1Changed: canvas.requestPaint()
        onBg2Changed: canvas.requestPaint()

        Column {
            anchors.centerIn: parent

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: res.label1
                font.pointSize: Appearance.font.size.extraLarge * res.primaryMult
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: res.sublabel1
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.smaller * res.primaryMult
            }
        }

        Column {
            anchors.horizontalCenter: parent.right
            anchors.top: parent.verticalCenter
            anchors.horizontalCenterOffset: -res.thickness / 2
            anchors.topMargin: res.thickness / 2 + Appearance.spacing.small

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: res.label2
                font.pointSize: Appearance.font.size.smaller * res.primaryMult
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: res.sublabel2
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small * res.primaryMult
            }
        }

        Canvas {
            id: canvas

            readonly property real centerX: width / 2
            readonly property real centerY: height / 2

            readonly property real arc1Start: degToRad(45)
            readonly property real arc1End: degToRad(220)
            readonly property real arc2Start: degToRad(230)
            readonly property real arc2End: degToRad(360)

            function degToRad(deg: int): real {
                return deg * Math.PI / 180;
            }

            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();

                ctx.lineWidth = res.thickness;
                ctx.lineCap = Appearance.rounding.scale === 0 ? "square" : "round";

                const radius = (Math.min(width, height) - ctx.lineWidth) / 2;
                const cx = centerX;
                const cy = centerY;
                const a1s = arc1Start;
                const a1e = arc1End;
                const a2s = arc2Start;
                const a2e = arc2End;

                ctx.beginPath();
                ctx.arc(cx, cy, radius, a1s, a1e, false);
                ctx.strokeStyle = res.bg1;
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(cx, cy, radius, a1s, (a1e - a1s) * res.value1 + a1s, false);
                ctx.strokeStyle = res.fg1;
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(cx, cy, radius, a2s, a2e, false);
                ctx.strokeStyle = res.bg2;
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(cx, cy, radius, a2s, (a2e - a2s) * res.value2 + a2s, false);
                ctx.strokeStyle = res.fg2;
                ctx.stroke();
            }
        }

        Behavior on value1 {
            Anim {}
        }

        Behavior on value2 {
            Anim {}
        }

        Behavior on fg1 {
            CAnim {}
        }

        Behavior on fg2 {
            CAnim {}
        }

        Behavior on bg1 {
            CAnim {}
        }

        Behavior on bg2 {
            CAnim {}
        }
    }
}
