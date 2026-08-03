param(
  [string]$DeviceId = '',
  [string]$ApiBaseUrl = 'https://backend-do-an-api-new.onrender.com',
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) {
  $flutter = 'D:\flutter\bin\flutter.bat'
}
$adb = 'D:\Android\platform-tools\adb.exe'
$apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
$applicationId = 'com.stocklite.app'

if (-not (Test-Path -LiteralPath $flutter)) {
  throw "Flutter was not found at $flutter"
}
if (-not (Test-Path -LiteralPath $adb)) {
  throw "ADB was not found at $adb"
}

Push-Location $projectRoot
try {
  if (-not $SkipBuild) {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

    & $flutter build apk --debug "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
  }

  if (-not (Test-Path -LiteralPath $apk)) {
    throw "APK was not found at $apk"
  }

  $devices = & $adb devices | Select-Object -Skip 1 |
    ForEach-Object { ($_ -split '\s+')[0] } |
    Where-Object { $_ }
  if (-not $DeviceId) {
    $DeviceId = $devices | Select-Object -First 1
  }
  if (-not $DeviceId) {
    throw 'No Android device found. Start an emulator or enable USB debugging.'
  }
  if ($DeviceId -notin $devices) {
    throw "ADB cannot find device $DeviceId"
  }

  Write-Host "Installing APK on $DeviceId..." -ForegroundColor Cyan
  & $adb -s $DeviceId install -r $apk
  if ($LASTEXITCODE -ne 0) { throw 'APK installation failed.' }

  & $adb -s $DeviceId logcat -c
  & $adb -s $DeviceId shell monkey -p $applicationId `
    -c android.intent.category.LAUNCHER 1 | Out-Null

  Write-Host 'The app is installed and running.' -ForegroundColor Green
  Write-Host "Device: $DeviceId"
  Write-Host "API: $ApiBaseUrl"
  Write-Host "APK: $apk"
  Write-Host "Live logs: & '$adb' -s $DeviceId logcat | Select-String 'flutter|FATAL EXCEPTION'"
} finally {
  Pop-Location
}
