$ErrorActionPreference='Stop'
$version='0.9.6'
$expected='086D9F1B5A99E643EDC2CFAAAC16051685B551E4C5AC0B32A57C58C0E529C001'
$vendor=Join-Path $PSScriptRoot 'vendor/LibreHardwareMonitor'
$archive=Join-Path $PSScriptRoot "vendor/LibreHardwareMonitor-$version.zip"
New-Item -ItemType Directory -Force (Split-Path $archive) | Out-Null
if(-not(Test-Path -LiteralPath $archive)){
    Invoke-WebRequest -Uri "https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases/download/v$version/LibreHardwareMonitor.zip" -OutFile $archive
}
if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expected){throw 'Sensor library checksum mismatch; download rejected.'}
Expand-Archive -LiteralPath $archive -DestinationPath $vendor -Force
Write-Output "Verified LibreHardwareMonitor $version"
