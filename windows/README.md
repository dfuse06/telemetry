# Telemetry for Windows

Windows companion to the original KDE Plasma Telemetry widget. The Windows app
keeps the dual Fahrenheit/Celsius CPU gauges, CPU-load gauge, activity graph,
resource meters and Original/Arctic/Ember/Cyber/Mono themes. The taskbar component
shows CPU/GPU usage, temperatures, RAM/GPU-memory use and activity lines.

Telemetry owns its sensor process. **TRCC and HWiNFO are not required.** CPU
package sensors use LibreHardwareMonitor 0.9.6 with the signed PawnIO driver.
GPU temperature uses that library or the Windows display-driver query matched
to the selected GPU name. Unsupported readings display unavailable, never a
motherboard sensor mislabeled as CPU temperature.

## Requirements

- Windows 11 x64 and .NET Framework 4.7.2 or later.
- Windhawk for native taskbar XAML integration.
- PawnIO 2.2 or later for direct CPU sensors. Install its official signed edition.
- Administrator access for the collector and installation. No security settings
  need to be disabled.

```powershell
winget install --id RamenSoftware.Windhawk --exact
winget install --id namazso.PawnIO --exact
```

## Build and install

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\build-windows.ps1 -Test
```

The build downloads a pinned official LibreHardwareMonitor release and verifies
its SHA-256 before extracting it. Libraries and binaries stay out of Git.

Then, from an Administrator PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1
```

The installer copies the app to `%LOCALAPPDATA%\Programs\DFUSE\Telemetry`,
registers its own `telemetry-taskbar` Windhawk component, and starts Telemetry.
It creates an elevated **DFUSE Telemetry** scheduled task at sign-in for the
current interactive user; no password is stored. Use `-SkipAutostart` to omit it.
Subsequent installs preserve taskbar settings. `-ReplacePreview` disables the earlier `taskbar-system-info` mod so only the new
Telemetry taskbar component remains active.

This is a taskbar extension loaded by Windhawk, not a replacement for Microsoft's
weather/Widgets button. Explorer updates and other taskbar modifications can
change compatibility. The Plasma implementation is unchanged.

## Use

- Click taskbar readings, or double-click Telemetry's tray icon, to open the dashboard.
- Select a theme in the dashboard. The Fahrenheit checkbox changes taskbar units;
  the dashboard always shows both temperature scales.
- Ctrl+Alt+T enters move mode. Drag to an open gap and release to save; Esc cancels.
  A red outline means there is insufficient room. Enter also saves a valid preview.
- In Windhawk, Full layout shows activity lines when space permits. Compact modes
  hide graphs; the widget automatically adapts when available space changes.
- Closing the dashboard keeps collection running. Use the tray's Exit Telemetry
  item to stop it. Disable the Windhawk mod and scheduled task to stop at sign-in.

The collector refreshes once per second on a background worker. It publishes an
atomic, versioned snapshot at `%LOCALAPPDATA%\DFUSE\Telemetry\sensors.json`.
The taskbar rejects snapshots older than eight seconds, future timestamps,
malformed input and invalid temperatures. Data stays on this PC; there is no
telemetry upload or network listener. Windhawk independently gathers ordinary
Windows usage counters; it does not load the sensor driver inside Explorer.

## Validation and current limits

The native regression suite covers placement, persistence, adaptive layouts,
provider freshness and the independent collector protocol. Its synthetic tests
are not proof of every physical monitor/fullscreen combination. The collector
has JSON/freshness/missing-sensor checks and a `--probe` option for actual hardware.
A probe also writes a local sensor report for diagnosis; reports are not committed.

Direct CPU package and Windows GPU temperatures were verified on a Ryzen 9 9900X
with AMD Radeon integrated graphics. Other hardware may expose different sensors.
The Windows dashboard is a WinForms port of the Plasma layout, not a QML binary;
Plasma-specific theme following is not available. Taskbar metrics/graphs are
provided by an attributed adaptation of Taskbar System Info, not written entirely
from scratch. The collector, protocol, dashboard and Windows packaging live here.

## Licenses

Windows sources and adapted taskbar/tests: GPL-3.0; see LICENSE and
THIRD-PARTY-NOTICES.md. LibreHardwareMonitor is an unmodified MPL-2.0 dependency;
its source is available at https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/tree/v0.9.6.
The signed PawnIO driver and Windhawk are installed separately.
