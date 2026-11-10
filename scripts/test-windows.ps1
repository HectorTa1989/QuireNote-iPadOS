$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent $PSScriptRoot
$cacheRoot = Join-Path $workspace '.build\ModuleCache'
$tempRoot = Join-Path $workspace '.swift-tmp'
New-Item -ItemType Directory -Force $cacheRoot, $tempRoot | Out-Null

$env:CLANG_MODULE_CACHE_PATH = $cacheRoot
$env:SWIFTPM_MODULECACHE_OVERRIDE = $cacheRoot
$env:TEMP = $tempRoot
$env:TMP = $tempRoot

if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) {
        throw 'Visual Studio 2022 Build Tools with the Desktop development with C++ workload is required.'
    }

    $installation = & $vswhere -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath
    $devShell = Join-Path $installation 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
    if (-not (Test-Path $devShell)) {
        throw 'Visual Studio C++ developer shell was not found.'
    }

    Import-Module $devShell
    Enter-VsDevShell -VsInstallPath $installation -SkipAutomaticLocation -DevCmdArguments '-arch=x64'
}

Push-Location $workspace
try {
    swift test
} finally {
    Pop-Location
}
