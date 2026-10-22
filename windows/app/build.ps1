param([string]$LibraryDirectory=(Join-Path $PSScriptRoot '../vendor/LibreHardwareMonitor'),[switch]$Test)
$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$output=Join-Path $PSScriptRoot 'bin'
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item (Join-Path $LibraryDirectory '*.dll') $output -Force
$library=Join-Path $output 'LibreHardwareMonitorLib.dll'
$sources=Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.cs' | ForEach-Object FullName
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll "/reference:$library" "/win32manifest:$(Join-Path $PSScriptRoot 'app.manifest')" "/out:$(Join-Path $output 'Telemetry.exe')" @sources
if($LASTEXITCODE -ne 0){throw 'Telemetry build failed'}
if($Test){
    $testExe=Join-Path $output 'Telemetry.Tests.exe'
    & $compiler /nologo /target:exe /platform:x64 /optimize+ /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll "/reference:$library" "/out:$testExe" @sources
    if($LASTEXITCODE -ne 0){throw 'Collector test build failed'}
    & $testExe --test
    if($LASTEXITCODE -ne 0){throw 'Collector tests failed'}
    Get-Content (Join-Path $output 'test-result.txt')
}
Write-Output "Built $output/Telemetry.exe"
