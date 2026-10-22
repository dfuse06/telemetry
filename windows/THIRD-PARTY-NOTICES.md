# Third-party components

The Windows application and adapted taskbar code are provided under GPL-3.0;
see LICENSE. This license applies to windows/ and does not change the license of
the separate Plasma code elsewhere in this repository.

Taskbar host and tests: Yevhenii Starychenko's Taskbar System Info 1.9.0,
commit dbb8d21ea48f8c2e0d6c0716ff56f9448f6ddac7, GPL-3.0.
https://github.com/starychenko/windhawk-taskbar-system-info
Original attribution comments remain in the adapted source. Changes add the
Telemetry collector protocol, dashboard action and save-on-release behavior.

LibreHardwareMonitor 0.9.6 is downloaded unmodified from its official release.
Its library is MPL-2.0, with additional notices for components it includes.
Source and license:
https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/tree/v0.9.6
https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/blob/v0.9.6/LICENSE
The release's unmodified runtime dependencies retain their original licenses.
They are restored locally and are not checked into this repository.

PawnIO is a separately installed, signed hardware-access driver. It is not
embedded in the application or included in this repository.
https://pawnio.eu/

Windhawk is installed separately. https://github.com/ramensoftware/windhawk
