param(
  [string]$DeviceId = 'emulator-5554',
  [string]$ApiBaseUrl = 'https://backend-do-an-api-new.onrender.com',
  [string]$TestUsername = '',
  [string]$TestPassword = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) {
  $flutter = 'D:\flutter\bin\flutter.bat'
}

if (-not (Test-Path -LiteralPath $flutter)) {
  throw "Flutter was not found at $flutter"
}

function Invoke-FlutterTest {
  param([string[]]$Arguments)

  & $flutter @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Test command failed: flutter $($Arguments -join ' ')"
  }
}

Push-Location $projectRoot
try {
  Write-Host '1/3 Running unit and widget tests...' -ForegroundColor Cyan
  Invoke-FlutterTest -Arguments @('test')

  Write-Host '2/3 Running mobile smoke integration test...' -ForegroundColor Cyan
  Invoke-FlutterTest -Arguments @(
    'test',
    'integration_test\mobile_smoke_test.dart',
    '-d',
    $DeviceId
  )

  if ($TestUsername -and $TestPassword) {
    Write-Host '3/3 Running real API login integration test...' -ForegroundColor Cyan
    Invoke-FlutterTest -Arguments @(
      'test',
      'integration_test\api_login_test.dart',
      '-d',
      $DeviceId,
      "--dart-define=API_BASE_URL=$ApiBaseUrl",
      "--dart-define=TEST_USERNAME=$TestUsername",
      "--dart-define=TEST_PASSWORD=$TestPassword"
    )
  } else {
    Write-Host '3/3 API login test skipped because credentials were not provided.' -ForegroundColor Yellow
  }

  Write-Host 'All requested mobile tests passed.' -ForegroundColor Green
} finally {
  Pop-Location
}
