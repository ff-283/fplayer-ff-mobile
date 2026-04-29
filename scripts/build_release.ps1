param(
    [string]$BuildName = "",
    [string]$BuildVersionName = "",
    [string]$BuildVersionNumber = "",
    [switch]$SkipWindows,
    [switch]$SkipAndroid,
    [switch]$SkipApk,
    [switch]$SkipAab,
    [switch]$RunAnalyze,
    [switch]$RunTest
)

$ErrorActionPreference = "Stop"

function Ensure-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Command not found: $Name. Please install it and add to PATH."
    }
}

function New-StageDir {
    param([string]$Name)
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $finalName = if ([string]::IsNullOrWhiteSpace($Name)) { $timestamp } else { $Name }
    $distRoot = Join-Path $PSScriptRoot "..\dist"
    $stageDir = Join-Path $distRoot $finalName
    New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
    return (Resolve-Path $stageDir).Path
}

function New-ReleaseNotesTemplate {
    param(
        [string]$OutputDir,
        [string]$VersionName,
        [string]$VersionNumber
    )

    $templatePath = Join-Path $OutputDir "release-notes-template.md"
    $today = Get-Date -Format "yyyy-MM-dd"
    $content = @"
# Release Notes

- Date: $today
- Version Name: $VersionName
- Version Number: $VersionNumber

## Highlights
- 

## Bug Fixes
- 

## Known Issues
- 

## Test Checklist
- [ ] Smoke test on Windows
- [ ] Install and playback test on Android
- [ ] API compatibility checked
"@
    Set-Content -Path $templatePath -Value $content -Encoding utf8
}

function Write-Checksums {
    param([string]$OutputDir)
    $checksumPath = Join-Path $OutputDir "checksums.txt"
    $artifactFiles = Get-ChildItem -Path $OutputDir -File | Where-Object { $_.Name -notin @("checksums.txt", "release-notes-template.md") }
    if ($artifactFiles.Count -eq 0) {
        return
    }

    $lines = @()
    foreach ($file in $artifactFiles) {
        $hash = Get-FileHash -Algorithm SHA256 -Path $file.FullName
        $lines += "$($hash.Hash)  $($file.Name)"
    }
    Set-Content -Path $checksumPath -Value $lines -Encoding ascii
}

Write-Host "==> Check environment"
Ensure-Command "flutter"
Ensure-Command "dart"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $projectRoot

Write-Host "==> Fetch dependencies"
flutter pub get

$buildArgs = @("--release")
if (-not [string]::IsNullOrWhiteSpace($BuildVersionName)) {
    $buildArgs += "--build-name"
    $buildArgs += $BuildVersionName
}
if (-not [string]::IsNullOrWhiteSpace($BuildVersionNumber)) {
    $buildArgs += "--build-number"
    $buildArgs += $BuildVersionNumber
}

if ($RunAnalyze) {
    Write-Host "==> Run flutter analyze"
    flutter analyze
}

if ($RunTest) {
    Write-Host "==> Run flutter test"
    flutter test
}

if (-not $SkipWindows) {
    Write-Host "==> Build Windows release"
    flutter config --enable-windows-desktop | Out-Null
    if (-not (Test-Path (Join-Path $projectRoot "windows"))) {
        flutter create --platforms=windows .
    }
    flutter build windows @buildArgs
}

if (-not $SkipAndroid) {
    if (-not $SkipApk) {
        Write-Host "==> Build Android APK release"
        flutter build apk @buildArgs
    }
    if (-not $SkipAab) {
        Write-Host "==> Build Android AAB release"
        flutter build appbundle @buildArgs
    }
}

$outputDir = New-StageDir -Name $BuildName
Write-Host "==> Collect artifacts to: $outputDir"

if (-not $SkipWindows) {
    $windowsReleaseDir = Join-Path $projectRoot "build\windows\x64\runner\Release"
    if (Test-Path $windowsReleaseDir) {
        $zipPath = Join-Path $outputDir "fplayer-ff-mobile-windows.zip"
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        Compress-Archive -Path (Join-Path $windowsReleaseDir "*") -DestinationPath $zipPath
        Write-Host "Windows package: $zipPath"
    } else {
        Write-Warning "Windows build directory not found: $windowsReleaseDir"
    }
}

if (-not $SkipAndroid) {
    if (-not $SkipApk) {
        $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apkPath) {
            $targetApkPath = Join-Path $outputDir "fplayer-ff-mobile-android.apk"
            Copy-Item $apkPath $targetApkPath -Force
            Write-Host "Android APK: $targetApkPath"
        } else {
            Write-Warning "APK artifact not found: $apkPath"
        }
    }

    if (-not $SkipAab) {
        $aabPath = Join-Path $projectRoot "build\app\outputs\bundle\release\app-release.aab"
        if (Test-Path $aabPath) {
            $targetAabPath = Join-Path $outputDir "fplayer-ff-mobile-android.aab"
            Copy-Item $aabPath $targetAabPath -Force
            Write-Host "Android AAB: $targetAabPath"
        } else {
            Write-Warning "AAB artifact not found: $aabPath"
        }
    }
}

New-ReleaseNotesTemplate -OutputDir $outputDir -VersionName $BuildVersionName -VersionNumber $BuildVersionNumber
Write-Checksums -OutputDir $outputDir

Write-Host "==> Done"
