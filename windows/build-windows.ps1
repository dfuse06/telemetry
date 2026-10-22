param([switch]$Test)
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'restore-sensors.ps1')
& (Join-Path $PSScriptRoot 'app/build.ps1') -Test:$Test
& (Join-Path $PSScriptRoot 'windhawk/build.ps1')
if($Test){
    & (Join-Path $PSScriptRoot 'windhawk/tests/run-regression.ps1')
}
