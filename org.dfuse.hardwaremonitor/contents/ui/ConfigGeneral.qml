import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

Item {
    id: page
    property alias cfg_theme: themeChoice.currentValue
    implicitWidth: 360
    implicitHeight: 160

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        QQC2.Label {
            text: i18n("Telemetry color theme")
            font.bold: true
        }
        QQC2.ComboBox {
            id: themeChoice
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("DFUSE Original"), value: "original" },
                { text: i18n("Ember"), value: "ember" },
                { text: i18n("Arctic Blue"), value: "arctic" },
                { text: i18n("Cyber Purple"), value: "cyber" },
                { text: i18n("Monochrome"), value: "mono" },
                { text: i18n("Follow Plasma Theme"), value: "plasma" }
            ]
        }
        QQC2.Label {
            text: i18n("GPU temperature always shows °F and °C together.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Item { Layout.fillHeight: true }
    }
}
