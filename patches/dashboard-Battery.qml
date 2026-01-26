pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    readonly property int padding: Appearance.padding.large
    readonly property var bat: UPower.displayDevice
    readonly property bool isCharging: !UPower.onBattery

    // Find physical battery's sysfs path from UPower
    readonly property string batPath: {
        const devs = UPower.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].isLaptopBattery)
                return `/sys/class/power_supply/${devs[i].nativePath}`;
        }
        return "";
    }

    // Sysfs data
    property real energyFullDesign: -1
    property int chargeCycles: -1

    // Try energy_full_design first (Wh batteries), then charge_full_design (Ah batteries)
    Loader {
        active: root.batPath !== "" && root.energyFullDesign < 0
        sourceComponent: FileView {
            path: `${root.batPath}/energy_full_design`
            onLoaded: {
                if (root.energyFullDesign >= 0) return;
                const val = parseInt(text().trim());
                if (val > 0) root.energyFullDesign = val / 1000000;
            }
        }
    }

    Loader {
        active: root.batPath !== "" && root.energyFullDesign < 0
        sourceComponent: FileView {
            path: `${root.batPath}/charge_full_design`
            onLoaded: {
                if (root.energyFullDesign >= 0) return;
                // charge_full_design is in µAh, need voltage to convert to Wh
                // Use nominal 11.4V (typical 3-cell) as fallback
                const val = parseInt(text().trim());
                const voltage = root.bat.voltage > 0 ? root.bat.voltage : 11.4;
                if (val > 0) root.energyFullDesign = (val / 1000000) * voltage;
            }
        }
    }

    Loader {
        active: root.batPath !== ""
        sourceComponent: FileView {
            path: `${root.batPath}/cycle_count`
            onLoaded: {
                const val = parseInt(text().trim());
                if (!isNaN(val) && val >= 0) root.chargeCycles = val;
            }
        }
    }

    // Computed properties
    readonly property real health: energyFullDesign > 0 ? bat.energyCapacity / energyFullDesign : -1
    readonly property bool hasHealth: health > 0

    // Color helpers - returns [foreground, background] based on thresholds
    function levelColor(value: real, greenThreshold: real, yellowThreshold: real): var {
        if (value >= greenThreshold) return [Colours.palette.m3primary, Colours.palette.m3primaryContainer];
        if (value >= yellowThreshold) return [Colours.palette.m3tertiary, Colours.palette.m3tertiaryContainer];
        return [Colours.palette.m3error, Colours.palette.m3errorContainer];
    }

    function cyclesColor(cycles: int): var {
        if (cycles >= 500) return [Colours.palette.m3error, Colours.palette.m3errorContainer];
        if (cycles >= 300) return [Colours.palette.m3tertiary, Colours.palette.m3tertiaryContainer];
        return [Colours.palette.m3secondary, Colours.palette.m3secondaryContainer];
    }

    function profileColor(profile: int): var {
        if (profile === PowerProfile.PowerSaver) return [Colours.palette.m3tertiary, Colours.palette.m3tertiaryContainer];
        if (profile === PowerProfile.Balanced) return [Colours.palette.m3primary, Colours.palette.m3primaryContainer];
        return [Colours.palette.m3error, Colours.palette.m3errorContainer];
    }

    function profileValue(profile: int): real {
        if (profile === PowerProfile.PowerSaver) return 0.33;
        if (profile === PowerProfile.Balanced) return 0.66;
        return 1;
    }

    function profileLabel(profile: int): string {
        if (profile === PowerProfile.PowerSaver) return qsTr("Saver");
        if (profile === PowerProfile.Balanced) return qsTr("Balanced");
        return qsTr("Perf");
    }

    function formatTime(seconds: real): string {
        if (seconds <= 0) return UPower.onBattery ? "..." : qsTr("Full");
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? `${h}h${m}m` : `${m}m`;
    }

    spacing: Appearance.spacing.large

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Appearance.spacing.large * 3

        // Health & Cycles (left)
        Resource {
            Layout.alignment: Qt.AlignVCenter
            Layout.margins: root.padding
            Layout.leftMargin: root.padding * 2

            readonly property var healthColors: root.levelColor(root.health, 0.8, 0.5)
            readonly property var cycleColors: root.cyclesColor(root.chargeCycles)

            value1: root.hasHealth ? root.health : 0
            value2: root.chargeCycles >= 0 ? Math.min(1, root.chargeCycles / 500) : 0

            label1: root.hasHealth ? `${Math.round(root.health * 100)}%` : "--"
            label2: root.chargeCycles >= 0 ? `${root.chargeCycles}` : "--"

            sublabel1: root.hasHealth ? qsTr("Health") + ` (${root.bat.energyCapacity.toFixed(0)}/${root.energyFullDesign.toFixed(0)})` : qsTr("Health")
            sublabel2: qsTr("Cycles")

            fg1: root.hasHealth ? healthColors[0] : Colours.palette.m3primary
            bg1: root.hasHealth ? healthColors[1] : Colours.palette.m3primaryContainer
            fg2: cycleColors[0]
            bg2: cycleColors[1]
        }

        // Battery & Time (center)
        Resource {
            Layout.alignment: Qt.AlignVCenter
            Layout.margins: root.padding

            primary: true

            value1: bat.percentage
            value2: UPower.onBattery ? Math.min(1, bat.timeToEmpty / 14400) : (bat.timeToFull > 0 ? Math.max(0, 1 - bat.timeToFull / 7200) : 1)

            label1: bat.isLaptopBattery ? `${Math.round(bat.percentage * 100)}%` : "--"
            label2: bat.isLaptopBattery ? root.formatTime(UPower.onBattery ? bat.timeToEmpty : bat.timeToFull) : "--"

            sublabel1: qsTr("Battery")
            sublabel2: UPower.onBattery ? qsTr("Remaining") : qsTr("To full")

            fg1: bat.percentage > 0.2 ? Colours.palette.m3primary : Colours.palette.m3error
            bg1: bat.percentage > 0.2 ? Colours.palette.m3primaryContainer : Colours.palette.m3errorContainer
            fg2: UPower.onBattery ? Colours.palette.m3secondary : Colours.palette.m3tertiary
            bg2: UPower.onBattery ? Colours.palette.m3secondaryContainer : Colours.palette.m3tertiaryContainer
        }

        // Power & Profile (right)
        Resource {
            Layout.alignment: Qt.AlignVCenter
            Layout.margins: root.padding
            Layout.rightMargin: root.padding * 2

            readonly property real powerRate: root.bat.changeRate
            readonly property var profColors: root.profileColor(PowerProfiles.profile)

            value1: powerRate > 0 ? Math.min(1, powerRate / 45) : 0
            value2: root.profileValue(PowerProfiles.profile)

            label1: powerRate > 0 ? (root.isCharging ? `+${powerRate.toFixed(1)}W` : `${powerRate.toFixed(1)}W`) : "--"
            label2: root.profileLabel(PowerProfiles.profile)

            sublabel1: root.isCharging ? qsTr("Charging") : qsTr("Draw")
            sublabel2: qsTr("Profile")

            fg1: root.isCharging ? Colours.palette.m3tertiary : Colours.palette.m3secondary
            bg1: root.isCharging ? Colours.palette.m3tertiaryContainer : Colours.palette.m3secondaryContainer
            fg2: profColors[0]
            bg2: profColors[1]
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

                ProfileButton { profile: PowerProfile.PowerSaver; icon: "energy_savings_leaf"; label: qsTr("Saver") }
                ProfileButton { profile: PowerProfile.Balanced; icon: "balance"; label: qsTr("Balanced") }
                ProfileButton { profile: PowerProfile.Performance; icon: "rocket_launch"; label: qsTr("Performance") }
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

    // Reusable components
    component ProfileButton: StyledRect {
        id: btn
        required property int profile
        required property string icon
        required property string label
        readonly property bool active: PowerProfiles.profile === profile

        implicitWidth: content.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: content.implicitHeight + Appearance.padding.small * 2
        color: active ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
        radius: Appearance.rounding.full

        Row {
            id: content
            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.icon
                color: btn.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                fill: btn.active ? 1 : 0
                Behavior on fill { Anim {} }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                color: btn.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.small
            }
        }

        StateLayer {
            radius: parent.radius
            color: btn.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            function onClicked(): void { PowerProfiles.profile = btn.profile; }
        }

        Behavior on color { CAnim {} }
    }

    component Resource: Item {
        id: res
        required property real value1
        required property real value2
        required property string label1
        required property string label2
        required property string sublabel1
        required property string sublabel2
        property bool primary: false
        property color fg1: Colours.palette.m3primary
        property color fg2: Colours.palette.m3secondary
        property color bg1: Colours.palette.m3primaryContainer
        property color bg2: Colours.palette.m3secondaryContainer

        readonly property real mult: primary ? 1.2 : 1
        readonly property real thickness: Config.dashboard.sizes.resourceProgessThickness * mult

        implicitWidth: Config.dashboard.sizes.resourceSize * mult
        implicitHeight: Config.dashboard.sizes.resourceSize * mult

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
                font.pointSize: Appearance.font.size.extraLarge * res.mult
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: res.sublabel1
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.smaller * res.mult
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
                font.pointSize: Appearance.font.size.smaller * res.mult
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: res.sublabel2
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small * res.mult
            }
        }

        Canvas {
            id: canvas
            anchors.fill: parent

            readonly property real cx: width / 2
            readonly property real cy: height / 2
            readonly property real a1s: 45 * Math.PI / 180
            readonly property real a1e: 220 * Math.PI / 180
            readonly property real a2s: 230 * Math.PI / 180
            readonly property real a2e: 360 * Math.PI / 180

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = res.thickness;
                ctx.lineCap = Appearance.rounding.scale === 0 ? "square" : "round";
                const r = (Math.min(width, height) - ctx.lineWidth) / 2;

                // Arc 1 background + foreground
                ctx.beginPath(); ctx.arc(cx, cy, r, a1s, a1e); ctx.strokeStyle = res.bg1; ctx.stroke();
                ctx.beginPath(); ctx.arc(cx, cy, r, a1s, a1s + (a1e - a1s) * res.value1); ctx.strokeStyle = res.fg1; ctx.stroke();

                // Arc 2 background + foreground
                ctx.beginPath(); ctx.arc(cx, cy, r, a2s, a2e); ctx.strokeStyle = res.bg2; ctx.stroke();
                ctx.beginPath(); ctx.arc(cx, cy, r, a2s, a2s + (a2e - a2s) * res.value2); ctx.strokeStyle = res.fg2; ctx.stroke();
            }
        }

        Behavior on value1 { Anim {} }
        Behavior on value2 { Anim {} }
        Behavior on fg1 { CAnim {} }
        Behavior on fg2 { CAnim {} }
        Behavior on bg1 { CAnim {} }
        Behavior on bg2 { CAnim {} }
    }
}
