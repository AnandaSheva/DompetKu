[CmdletBinding()]
param(
    [string]$AndroidSdkPath = $env:ANDROID_HOME
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

Push-Location $projectRoot
try {
    $pubspec = Get-Content -LiteralPath 'pubspec.yaml' -Raw
    $versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$')
    if (-not $versionMatch.Success) {
        throw 'pubspec.yaml must contain version: major.minor.patch+build.'
    }
    $versionName = $versionMatch.Groups[1].Value
    $buildNumber = $versionMatch.Groups[2].Value

    if (-not (Test-Path -LiteralPath 'android/key.properties')) {
        throw 'Configure the release signing key in android/key.properties before building release APKs.'
    }

    if (-not $AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_SDK_ROOT }
    if (-not $AndroidSdkPath -and (Test-Path -LiteralPath 'android/local.properties')) {
        $sdkMatch = [regex]::Match(
            (Get-Content -LiteralPath 'android/local.properties' -Raw),
            '(?m)^sdk\.dir=(.+)$'
        )
        if ($sdkMatch.Success) {
            $AndroidSdkPath = $sdkMatch.Groups[1].Value.Trim().Replace('\\', '\').Replace('\:', ':')
        }
    }
    if (-not $AndroidSdkPath) { throw 'Set ANDROID_HOME or pass -AndroidSdkPath.' }

    $buildTools = Get-ChildItem -LiteralPath (Join-Path $AndroidSdkPath 'build-tools') -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if (-not $buildTools) { throw 'Install Android SDK build-tools before building release APKs.' }
    $aapt = Join-Path $buildTools.FullName 'aapt.exe'
    $apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
    if (-not (Test-Path -LiteralPath $aapt) -or -not (Test-Path -LiteralPath $apksigner)) {
        throw 'Android SDK build-tools must include aapt and apksigner.'
    }
    if (-not $env:JAVA_HOME -and -not (Get-Command java -ErrorAction SilentlyContinue)) {
        throw 'Set JAVA_HOME to your JDK (for example, Android Studio jbr) so apksigner can verify release signatures.'
    }

    # Always rebuild with the pubspec version; renaming an old APK does not update its manifest.
    & flutter build apk --release --split-per-abi --build-name $versionName --build-number $buildNumber
    if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed.' }

    $metadataPath = 'build/app/outputs/apk/release/output-metadata.json'
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    $apkVariants = [ordered]@{
        'armeabi-v7a' = 'armeabi-v7a'
        'arm64-v8a' = 'arm64'
        'x86_64' = 'x86_64'
    }
    # Flutter split APKs add ABI-specific offsets to the pubspec build number.
    $abiVersionOffsets = @{ 'armeabi-v7a' = 1000; 'arm64-v8a' = 2000; 'x86_64' = 4000 }
    $verifiedApks = @()
    foreach ($abi in $apkVariants.Keys) {
        $expectedVersionCode = [long]$buildNumber + $abiVersionOffsets[$abi]
        $element = @($metadata.elements | Where-Object {
            @($_.filters | Where-Object { $_.filterType -eq 'ABI' -and $_.value -eq $abi }).Count -eq 1
        })
        if ($element.Count -ne 1 -or $element[0].versionName -cne $versionName -or
            [long]$element[0].versionCode -ne $expectedVersionCode) {
            throw "Build metadata for $abi does not match pubspec.yaml. No release APKs were copied."
        }

        $apkPath = Join-Path (Split-Path -Parent $metadataPath) $element[0].outputFile
        $badging = & $aapt dump badging $apkPath
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect APK: $apkPath" }
        $packageLine = $badging | Where-Object { $_ -like 'package:*' } | Select-Object -First 1
        $apkVersion = [regex]::Match($packageLine, "versionName='([^']+)'").Groups[1].Value
        $apkBuild = [regex]::Match($packageLine, "versionCode='(\d+)'").Groups[1].Value
        $apkId = [regex]::Match($packageLine, "name='([^']+)'").Groups[1].Value
        if ($apkVersion -cne $versionName -or $apkBuild -ne [string]$element[0].versionCode -or
            $apkId -cne 'com.sheva.dompetku') {
            throw "APK manifest for $abi does not match the release. No release APKs were copied."
        }

        $signature = & $apksigner verify --print-certs $apkPath
        if ($LASTEXITCODE -ne 0 -or ($signature -match 'CN=Android Debug')) {
            throw "APK for $abi must have a valid release signature. No release APKs were copied."
        }
        $verifiedApks += [pscustomobject]@{
            Path = $apkPath
            Name = "DompetSheva-v$versionName-$($apkVariants[$abi]).apk"
        }
    }

    # Copy only after every ABI has passed manifest and signature verification.
    $releaseDir = Join-Path $projectRoot "build/releases/$versionName+$buildNumber"
    New-Item -Path $releaseDir -ItemType Directory -Force | Out-Null
    $checksums = foreach ($apk in $verifiedApks) {
        $destination = Join-Path $releaseDir $apk.Name
        Copy-Item -LiteralPath $apk.Path -Destination $destination -Force
        $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        "$hash  $($apk.Name)"
    }
    $checksums | Set-Content -LiteralPath (Join-Path $releaseDir 'SHA256SUMS.txt') -Encoding ascii
    Write-Host "Verified release APKs: $releaseDir"
    $checksums | ForEach-Object { Write-Host $_ }
} finally {
    Pop-Location
}
