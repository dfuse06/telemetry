#Requires -RunAsAdministrator
param([switch]$SkipAutostart,[switch]$ReplacePreview)
$ErrorActionPreference='Stop'
$appSource=Join-Path $PSScriptRoot 'app/bin'
$modSource=Join-Path $PSScriptRoot 'windhawk/build/telemetry-taskbar_1.0.0.dll'
if(-not(Test-Path (Join-Path $appSource 'Telemetry.exe')) -or -not(Test-Path $modSource)){throw 'Run build-windows.ps1 first.'}
if(-not(Test-Path 'HKLM:/SOFTWARE/Windhawk')){throw 'Install Windhawk first: winget install RamenSoftware.Windhawk'}
$install=Join-Path $env:LOCALAPPDATA 'Programs/DFUSE/Telemetry'
$existing=Get-Process -Name Telemetry -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq (Join-Path $install 'Telemetry.exe')}
foreach($process in $existing){$process.Kill();$process.WaitForExit(5000) | Out-Null}
New-Item -ItemType Directory -Force $install | Out-Null
Copy-Item (Join-Path $appSource '*.dll'),(Join-Path $appSource 'Telemetry.exe') $install -Force
Copy-Item (Join-Path $PSScriptRoot 'LICENSE'),(Join-Path $PSScriptRoot 'THIRD-PARTY-NOTICES.md') $install -Force
$modName='telemetry-taskbar_1.0.0_'+(Get-Date -Format 'yyyyMMddHHmmss')+'.dll'
$modDir=Join-Path $env:ProgramData 'Windhawk/Engine/Mods/64'
New-Item -ItemType Directory -Force $modDir | Out-Null
Copy-Item $modSource (Join-Path $modDir $modName)
$sourceDir=Join-Path $env:ProgramData 'Windhawk/ModsSource'
New-Item -ItemType Directory -Force $sourceDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'windhawk/taskbar-system-info.wh.cpp') (Join-Path $sourceDir 'telemetry-taskbar.wh.cpp') -Force
$key='HKLM:/SOFTWARE/Windhawk/Engine/Mods/telemetry-taskbar'
if(-not(Test-Path $key)){New-Item -Path $key -Force | Out-Null}
foreach($entry in @{LibraryFileName=$modName;Include='explorer.exe';Architecture='x86-64';Version='1.0.0'}.GetEnumerator()){
    New-ItemProperty -Path $key -Name $entry.Key -Value $entry.Value -PropertyType String -Force | Out-Null
}
New-ItemProperty -Path $key -Name Disabled -Value 0 -PropertyType DWord -Force | Out-Null
if(-not(Test-Path "$key/Settings")){New-Item -Path "$key/Settings" | Out-Null}
$settingsKey=Get-Item "$key/Settings"
# Preserve existing user settings on subsequent installs.
$ints=@{width=410;leftOffset=800;monitor=1;allMonitors=0;reserveSpace=0;showNetwork=0;fontSize=11;adaptiveColors=0;textOpacity=96;showCpuGraph=1;showGpuGraph=1;updateInterval=1;historySeconds=60;cpuWarningTemp=75;cpuCriticalTemp=85;gpuWarningTemp=80;gpuCriticalTemp=90;memoryWarningPercent=80;memoryCriticalPercent=90;reserveGap=8}
$strings=@{preferredLayout='full';moveHotkey='Ctrl+Alt+T';fontFamily='Segoe UI Variable Text';textColor='#75E6FF';graphColor='#427CFF';warningColor='#FFFFB900';criticalColor='#FFFF6B6B';temperatureSource='auto';gpuAdapter='';gpuMemoryMode='auto';networkUnit='bytes'}
foreach($entry in $ints.GetEnumerator()){if($null -eq (Get-ItemPropertyValue -Path $settingsKey.PSPath -Name $entry.Key -ErrorAction SilentlyContinue)){New-ItemProperty -Path $settingsKey.PSPath -Name $entry.Key -Value $entry.Value -PropertyType DWord | Out-Null}}
foreach($entry in $strings.GetEnumerator()){if($null -eq (Get-ItemPropertyValue -Path $settingsKey.PSPath -Name $entry.Key -ErrorAction SilentlyContinue)){New-ItemProperty -Path $settingsKey.PSPath -Name $entry.Key -Value $entry.Value -PropertyType String | Out-Null}}
New-ItemProperty -Path $key -Name SettingsChangeTime -Value ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -PropertyType DWord -Force | Out-Null
$exe=Join-Path $install 'Telemetry.exe'
if(-not $SkipAutostart){
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action=New-ScheduledTaskAction -Execute $exe -Argument '--tray'
    $trigger=New-ScheduledTaskTrigger -AtLogOn -User $identity
    $principal=New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Highest
    $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName 'DFUSE Telemetry' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
}
Start-Process -FilePath $exe -WindowStyle Hidden
if($ReplacePreview){
    $oldKey='HKLM:/SOFTWARE/Windhawk/Engine/Mods/taskbar-system-info'
    $old=Get-ItemProperty -Path $oldKey -ErrorAction SilentlyContinue
    if($old -and $old.LibraryFileName -in @('taskbar-system-info_1.9.0.dll','taskbar-system-info_1.9.0_move1.dll')){
        Set-ItemProperty -Path $oldKey -Name Disabled -Value 1
    }
}
Write-Output "Installed Telemetry: $exe"
