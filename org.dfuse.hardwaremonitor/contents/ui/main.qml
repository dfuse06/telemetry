import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    implicitWidth: 440
    implicitHeight: 660
    Layout.minimumWidth: 420
    Layout.minimumHeight: 640
    Layout.preferredWidth: 440
    Layout.preferredHeight: 660
    property real cpuTemp: 0
    property real gpuTemp: 0
    property int cpuLoad: 0
    property string cpuName: "CPU"
    property string gpuName: "GPU"
    property int gpuLoad: -1
    property int vramPercent: -1
    property real vramUsedGiB: 0
    property real vramTotalGiB: 0
    property int ram: 0
    property int disk: 0
    property real frequency: 0
    property var lastCounters: [0, 0]
    property bool sensorReady: false
    property bool gpuReady: false
    property var history: Array(48).fill(0)
    property string statusText: "CONNECTING"
    property string selectedTheme: plasmoid.configuration.theme || "original"
    property bool followPlasma: selectedTheme === "plasma"
    property color cyan: selectedTheme === "ember" ? "#FF9B43" : selectedTheme === "arctic" ? "#43D9FF" : selectedTheme === "cyber" ? "#DF75FF" : selectedTheme === "mono" ? "#E5E9F0" : followPlasma ? Kirigami.Theme.highlightColor : "#00F0E4"
    property color purple: selectedTheme === "ember" ? "#FF5964" : selectedTheme === "arctic" ? "#478AFF" : selectedTheme === "cyber" ? "#FF59CC" : selectedTheme === "mono" ? "#9DA6B2" : followPlasma ? Kirigami.Theme.linkColor : "#B16CFF"
    property color muted: followPlasma ? Kirigami.Theme.disabledTextColor : "#8395B6"
    property color panelBackground: followPlasma ? Kirigami.Theme.backgroundColor : selectedTheme === "ember" ? "#DD1F1114" : selectedTheme === "arctic" ? "#DD081C30" : selectedTheme === "cyber" ? "#DD1C102B" : selectedTheme === "mono" ? "#DD181B20" : "#66080E1D"
    property color tileBackground: followPlasma ? Kirigami.Theme.alternateBackgroundColor : "#55121C31"
    property color outline: followPlasma ? Kirigami.Theme.highlightColor : selectedTheme === "ember" ? "#AE5237" : selectedTheme === "arctic" ? "#3273B9" : selectedTheme === "cyber" ? "#9146D1" : selectedTheme === "mono" ? "#747B85" : "#7449BA"
    property color primaryText: followPlasma ? Kirigami.Theme.textColor : "#DCE6F5"
    function gpuCelsius() { return (gpuTemp - 32) * 5 / 9 }
    function gpuBarPercent() { return Math.max(0, Math.min(100, gpuCelsius())) }
    function gpuHeatColor() { return gpuCelsius() >= 85 ? "#FF647C" : gpuCelsius() >= 70 ? "#FFB65E" : cyan }

    Plasma5Support.DataSource {
        id: source
        engine: "executable"
        connectedSources: []
        onNewData: function(name, data) {
            if (data.stdout) {
                try {
                    const s = JSON.parse(data.stdout)
                    root.sensorReady = s.cpuTemp !== null && s.cpuTemp !== undefined
                    root.gpuReady = s.gpuTemp !== null && s.gpuTemp !== undefined
                    root.cpuTemp = root.sensorReady ? s.cpuTemp : 0
                    root.gpuTemp = root.gpuReady ? s.gpuTemp : 0
                    root.cpuName = s.cpuName || "CPU"
                    root.gpuName = s.gpuName || "GPU"
                    root.gpuLoad = (s.gpuLoad === null || s.gpuLoad === undefined) ? -1 : s.gpuLoad
                    root.vramPercent = (s.vramPercent === null || s.vramPercent === undefined) ? -1 : s.vramPercent
                    root.vramUsedGiB = s.vramUsedGiB || 0
                    root.vramTotalGiB = s.vramTotalGiB || 0
                    root.ram = s.ram || 0
                    root.disk = s.disk || 0
                    root.frequency = s.frequency || 0
                    if (root.lastCounters[0] > 0 && s.cpuCounters) {
                        const dt = s.cpuCounters[0] - root.lastCounters[0]
                        const di = s.cpuCounters[1] - root.lastCounters[1]
                        if (dt > 0) root.cpuLoad = Math.max(0, Math.min(100, Math.round(100 * (dt - di) / dt)))
                    }
                    root.lastCounters = s.cpuCounters || [0, 0]
                    const next = root.history.slice(1)
                    next.push(root.cpuLoad)
                    root.history = next
                    root.statusText = root.sensorReady ? "SYSTEM ONLINE" : "CPU SENSOR UNAVAILABLE"
                } catch(e) {
                    root.statusText = "SENSOR ERROR"
                    console.warn("Telemetry parse error", e)
                }
            }
            source.disconnectSource(name)
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (source.connectedSources.length === 0)
                source.connectSource("python3 " + Qt.resolvedUrl("../scripts/sensors.py").toString().replace("file://", ""))
        }
    }

    fullRepresentation: Rectangle {
        id: panel
        color: root.panelBackground
        radius: 22
        border.color: root.outline
        border.width: 1
        clip: true
        implicitWidth: 440
        implicitHeight: 660
        Layout.minimumWidth: 420
        Layout.minimumHeight: 640

        Rectangle {
            width: parent.width * 0.8
            height: 180
            x: parent.width * 0.4
            y: -120
            radius: 100
            color: "#3314214C"
            opacity: 0.28
        }
        Rectangle {
            width: parent.width * 0.8
            height: 160
            x: -parent.width * 0.5
            y: parent.height - 70
            radius: 100
            color: "#33362050"
            opacity: 0.23
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.width < 460 ? 14 : 18
            spacing: root.height < 690 ? 8 : 11
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 3
                    Text { text: "TELEMETRY"; color: root.purple; font.bold: true; font.pixelSize: 20; font.letterSpacing: 1.1 }
                    Text { text: root.cpuName; color: root.muted; font.pixelSize: 10; font.letterSpacing: 1 }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 9; height: 9; radius: 5
                    color: root.sensorReady ? root.cyan : "#FFB65E"
                    SequentialAnimation on opacity {
                        running: true; loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 850 }
                        NumberAnimation { to: 1; duration: 850 }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#293B58" }
            // Restore the original three circular gauges with a dedicated,
            // fixed-height row so the activity chart never overlaps them.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.height >= 730 ? 142 : 126
                Layout.minimumHeight: 126
                Layout.maximumHeight: 142
                spacing: 6
                Gauge {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "CPU TEMP"
                    value: root.sensorReady ? root.cpuTemp : 0
                    maxValue: 212
                    displayValue: root.sensorReady ? root.cpuTemp.toFixed(1) + "°" : "N/A"
                    accent: root.cpuTemp >= 185 ? "#FF647C" : root.cyan
                    sublabel: "FAHRENHEIT"
                }
                Gauge {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "CPU TEMP"
                    value: root.sensorReady ? Math.max(0, (root.cpuTemp - 32) * 5 / 9) : 0
                    maxValue: 100
                    displayValue: root.sensorReady ? ((root.cpuTemp - 32) * 5 / 9).toFixed(1) + "°" : "N/A"
                    accent: root.cpuTemp >= 185 ? "#FF647C" : root.purple
                    sublabel: "CELSIUS"
                }
                Gauge {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "CPU LOAD"
                    value: root.cpuLoad
                    maxValue: 100
                    displayValue: root.cpuLoad + "%"
                    accent: root.purple
                    sublabel: "UTILIZATION"
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(94, Math.min(115, root.height * 0.155))
                radius: 12
                color: "#55111B30"
                border.color: "#253550"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    RowLayout {
                        Text { text: "CPU ACTIVITY"; color: "#CFD9ED"; font.bold: true; font.pixelSize: 11; font.letterSpacing: 1 }
                        Item { Layout.fillWidth: true }
                        Text { text: root.cpuLoad + "% LIVE"; color: root.cyan; font.bold: true; font.pixelSize: 11 }
                    }
                    Canvas {
                        id: graph
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const w = width, h = height, data = root.history
                            ctx.strokeStyle = "#253650"
                            ctx.lineWidth = 1
                            for (let j = 1; j <= 3; j++) {
                                ctx.beginPath(); ctx.moveTo(0, h*j/4); ctx.lineTo(w, h*j/4); ctx.stroke()
                            }
                            ctx.beginPath()
                            for (let i = 0; i < data.length; i++) {
                                const x = i*w/(data.length-1), y = h - data[i]*h/100
                                if (i === 0) ctx.moveTo(x,y); else ctx.lineTo(x,y)
                            }
                            ctx.strokeStyle = root.cyan
                            ctx.lineWidth = 2
                            ctx.stroke()
                            ctx.lineTo(w,h); ctx.lineTo(0,h); ctx.closePath()
                            ctx.fillStyle = "#1800F0E4"
                            ctx.fill()
                        }
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Connections { target: root; function onHistoryChanged() { graph.requestPaint() } }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "SYSTEM RESOURCES"; color: root.purple; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1 }
                Item { Layout.fillWidth: true }
                Text { text: "LIVE / 2 SEC"; color: root.muted; font.pixelSize: 10 }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                Meter { Layout.fillWidth: true; label: "MEMORY"; value: root.ram; accent: root.cyan }
                Meter { Layout.fillWidth: true; label: "STORAGE"; value: root.disk; accent: root.purple }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    radius: 11
                    color: root.tileBackground
                    border.color: root.outline
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 7
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "GPU TEMP"; color: root.primaryText; font.pixelSize: 11; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.gpuReady ? root.gpuTemp.toFixed(1) + "°F / " + root.gpuCelsius().toFixed(1) + "°C" : "N/A"
                                color: root.gpuReady ? root.gpuHeatColor() : root.muted
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 9
                            radius: 5
                            color: "#27364E"
                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                color: root.gpuHeatColor()
                                width: root.gpuReady ? parent.width * root.gpuBarPercent() / 100 : 0
                                Behavior on width { NumberAnimation { duration: 500 } }
                            }
                        }
                    }
                }
                StatTile {
                    Layout.fillWidth: true
                    title: "CPU CLOCK"
                    valueText: root.frequency.toFixed(2) + " GHz"
                    accent: root.cyan
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(112, Math.min(138, root.height * 0.18))
                radius: 12
                color: "#55111B30"
                border.color: "#253550"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 6
                    Text {
                        text: "GPU  /  " + root.gpuName
                        color: root.purple
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9
                        Meter { Layout.fillWidth: true; label: "GPU LOAD"; value: root.gpuLoad; accent: root.purple }
                        Meter { Layout.fillWidth: true; label: "VRAM"; value: root.vramPercent; accent: root.cyan }
                    }
                    Text {
                        text: root.vramTotalGiB > 0 ? root.vramUsedGiB.toFixed(2) + " / " + root.vramTotalGiB.toFixed(2) + " GiB VRAM" : "VRAM DATA UNAVAILABLE"
                        color: root.muted
                        font.pixelSize: 10
                    }
                }
            }
            Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                Rectangle { width: 5; height: 5; radius: 3; color: root.sensorReady ? root.cyan : "#FFB65E" }
                Text { text: root.statusText; color: root.muted; font.pixelSize: 10; font.letterSpacing: 0.5 }
            }
        }
    }

    component Gauge: Item {
        property string label: ""
        property string sublabel: ""
        property real value: 0
        property real maxValue: 100
        property string displayValue: ""
        property color accent: root.cyan
        property real animatedValue: value
        Behavior on animatedValue { NumberAnimation { duration: 550; easing.type: Easing.OutCubic } }
        Canvas {
            id: arc
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                const cx = w / 2, cy = h * 0.45
                const r = Math.max(12, Math.min(w * 0.38, h * 0.34))
                const start = Math.PI * 0.75, sweep = Math.PI * 1.5
                ctx.lineCap = "round"
                ctx.lineWidth = Math.max(5, Math.min(9, w * 0.065))
                ctx.strokeStyle = "#293852"
                ctx.beginPath(); ctx.arc(cx, cy, r, start, start + sweep); ctx.stroke()
                ctx.strokeStyle = accent
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + sweep * Math.max(0, Math.min(1, animatedValue / Math.max(1, maxValue))))
                ctx.stroke()
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
        onAnimatedValueChanged: arc.requestPaint()
        onAccentChanged: arc.requestPaint()
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -6
            spacing: 3
            Text {
                text: displayValue
                color: "#FFFFFF"
                font.pixelSize: Math.min(17, Math.max(13, parent.parent.width * 0.135))
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: label
                color: "#D6E2F7"
                font.pixelSize: 9
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: sublabel
                color: root.muted
                font.pixelSize: 8
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
    component Meter: Rectangle {
        property string label: ""
        property int value: 0
        property color accent: root.cyan
        Layout.preferredHeight: 80
        radius: 11
        color: root.tileBackground
        border.color: "#4A2A3A57"
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 11
          spacing: 8
        RowLayout {
            Text { text: label; color: root.primaryText; font.pixelSize: 11; font.bold: true }
            Item { Layout.fillWidth: true }
            Text { text: value < 0 ? "N/A" : value + "%"; color: accent; font.pixelSize: 13; font.bold: true }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 9
            radius: 5; color: "#27364E"
            Rectangle {
                height: parent.height; radius: parent.radius; color: accent
                width: parent.width*Math.max(0,Math.min(100,value))/100
                Behavior on width { NumberAnimation { duration: 500 } }
            }
        }
        }
    }
    component StatTile: Rectangle {
        property string title: ""
        property string valueText: ""
        property color accent: root.cyan
        Layout.preferredHeight: 80
        radius: 11
        color: root.tileBackground
        border.color: "#2A3A57"
        Column {
            anchors.centerIn: parent
            spacing: 5
            Text { text: title; color: root.muted; font.pixelSize: 10; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: valueText; color: accent; font.pixelSize: 17; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
}
