param(
  [string]$Reference = 'D:\Report 5.0_TestDoc_Template.docx',
  [string]$Output = 'D:\DoAnFlutter\docs\Report_5_StockLite_Test_Documentation.docx'
)

$ErrorActionPreference = 'Stop'
$wdCollapseEnd = 0
$wdPageBreak = 7
$wdAutoFitWindow = 2
$wdFindContinue = 1
$wdReplaceAll = 2

function Replace-AllText {
  param($Document, [string]$FindText, [string]$ReplaceText)

  $range = $Document.Content
  $find = $range.Find
  $find.ClearFormatting()
  $find.Replacement.ClearFormatting()
  $find.Text = $FindText
  $find.Replacement.Text = $ReplaceText
  $find.Forward = $true
  $find.Wrap = $wdFindContinue
  [void]$find.Execute(
    $FindText,
    $false,
    $false,
    $false,
    $false,
    $false,
    $true,
    $wdFindContinue,
    $false,
    $ReplaceText,
    $wdReplaceAll
  )
}

function Add-Paragraph {
  param($Selection, [string]$Text, [string]$Style = 'Normal')

  $Selection.Style = $Style
  $Selection.TypeText($Text)
  $Selection.TypeParagraph()
}

function Add-Bullets {
  param($Selection, [string[]]$Items)

  foreach ($item in $Items) {
    Add-Paragraph -Selection $Selection -Text $item -Style 'List Bullet'
  }
  $Selection.Style = 'Normal'
}

function Add-PageBreak {
  param($Selection)
  $Selection.InsertBreak($wdPageBreak)
}

function Add-ReportTable {
  param(
    $Document,
    $Selection,
    [string[]]$Headers,
    [object[]]$Rows,
    [double[]]$Widths = @()
  )

  $script:tableCounter++
  Write-Host "Creating report table $script:tableCounter..."
  $rowCount = $Rows.Count + 1
  $columnCount = $Headers.Count
  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add(($Headers -join "`t"))
  foreach ($row in $Rows) {
    $values = @($row) | ForEach-Object {
      ([string]$_).Replace("`t", ' ').Replace("`r", ' ').Replace("`n", ' ')
    }
    while ($values.Count -lt $columnCount) { $values += '' }
    $lines.Add(($values[0..($columnCount - 1)] -join "`t"))
  }

  $start = $Selection.Start
  $Selection.TypeText(($lines -join "`r"))
  $end = $Selection.End
  $tableRange = $Document.Range($start, $end)
  $table = $tableRange.ConvertToTable(1, $rowCount, $columnCount)

  try { $table.Style = 'Table' } catch {}
  $table.Borders.Enable = 1
  $table.AllowAutoFit = $true
  $table.TopPadding = 4
  $table.BottomPadding = 4
  $table.LeftPadding = 5
  $table.RightPadding = 5

  $table.Range.Font.Size = 9.5
  $table.Rows.Item(1).Range.Bold = 1
  $table.Rows.Item(1).Range.Font.Size = 10
  $table.Rows.Item(1).Shading.BackgroundPatternColor = 14277081
  $table.Rows.Item(1).HeadingFormat = -1
  $Selection.SetRange($table.Range.End, $table.Range.End)
  $Selection.TypeParagraph()
  return $table
}

$outputDirectory = Split-Path -Parent $Output
$script:tableCounter = 0
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Copy-Item -LiteralPath $Reference -Destination $Output -Force

$word = $null
$document = $null
try {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $word.DisplayAlerts = 0
  $word.ScreenUpdating = $false
  $word.Options.CheckSpellingAsYouType = $false
  $word.Options.CheckGrammarAsYouType = $false
  try { $word.Options.Pagination = $false } catch {}
  try { $word.Options.AllowBackgroundSave = $false } catch {}
  $document = $word.Documents.Open($Output)
  $document.TrackRevisions = $false

  Replace-AllText $document '{{Project Name (CODE)}}' 'StockLite Mobile (STOCKLITE-MOBILE)'
  Replace-AllText $document '{{VERSION}}' '1.0'
  Replace-AllText $document '{{DATE}}' '21/07/2026'
  Replace-AllText $document '[DD/MM/YYYY]' '21/07/2026'
  Replace-AllText $document '[Author]' 'QA / Development Team'
  Replace-AllText $document '{{Project Code}}' 'STOCKLITE-MOBILE'

  if ($document.Tables.Count -ge 2 -and $document.Tables.Item(2).Rows.Count -ge 2) {
    $changeLog = $document.Tables.Item(2)
    $changeLog.Cell(2, 1).Range.Text = '1.0'
    $changeLog.Cell(2, 2).Range.Text = '21/07/2026'
    $changeLog.Cell(2, 3).Range.Text = 'QA / Development Team'
    $changeLog.Cell(2, 4).Range.Text = 'Replaced template examples with StockLite Mobile test scope, strategy, plan, cases, and execution results.'
  }

  $scopeStart = $null
  $scopeRange = $document.Content.Duplicate
  if ($document.TablesOfContents.Count -gt 0) {
    $scopeRange.SetRange(
      $document.TablesOfContents.Item(1).Range.End,
      $document.Content.End - 1
    )
  }
  $scopeRange.Find.Forward = $true
  $scopeRange.Find.Wrap = 0
  if ($scopeRange.Find.Execute('1. Scope of Testing')) {
    $scopeStart = $scopeRange.Start
  }
  if ($null -eq $scopeStart) {
    throw 'Cannot find the Scope of Testing heading in the template.'
  }

  $deleteRange = $document.Range($scopeStart, $document.Content.End - 1)
  $deleteRange.Delete()
  Write-Host 'Template instructional body removed.'

  $selection = $word.Selection
  $selection.SetRange($document.Content.End - 1, $document.Content.End - 1)

  Add-Paragraph $selection '1. Scope of Testing' 'Heading 1'
  Add-Paragraph $selection 'This test cycle validates the StockLite Mobile application used by field staff for purchasing, warehouse operations, delivery, stocktake, quality inspection, milling, reporting, QR scanning, and account management. The scope covers Flutter business logic, screen behavior, API integration, Android execution, and the BLE scale workflow.'

  Add-Paragraph $selection '1.1 In Scope - Functional Requirements' 'Heading 2'
  Add-ReportTable $document $selection @('Code', 'Feature / Requirement', 'Priority') @(
    @('FT-01', 'Authenticate with the REST API, retain the authenticated session, display API errors, and reject invalid credentials.', 'Must'),
    @('FT-02', 'Display Home dashboard, today summary, quick actions, and bottom navigation.', 'Must'),
    @('FT-03', 'Display the authenticated account profile, change password, operation history, and sign out.', 'Must'),
    @('FT-04', 'Load purchase schedules, open schedule details, and execute the inbound purchasing flow.', 'Must'),
    @('FT-05', 'Display only products with on-hand stock and open warehouse product details.', 'Must'),
    @('FT-06', 'Create stocktake entries and accept multi-digit actual quantities.', 'Must'),
    @('FT-07', 'Keep quality inspection separate from stocktake and display the correct workflow.', 'Must'),
    @('FT-08', 'Load delivery data, open delivery details, select customer/stock, and complete delivery.', 'Must'),
    @('FT-09', 'Run milling preparation, rice weighing, bran weighing, result confirmation, and completion.', 'Must'),
    @('FT-10', 'Scan, connect, read stable weight, tare, reset, and capture multiple bags from the StockLite BLE scale.', 'Should'),
    @('FT-11', 'Display warehouse reports and operation history from repository/API data.', 'Should'),
    @('FT-12', 'Open the QR/barcode scanner and handle camera permission safely.', 'Should'),
    @('FT-13', 'Load REST notifications and refresh them manually without realtime dependencies.', 'Could')
  ) @(14, 71, 15) | Out-Null

  Add-Paragraph $selection '1.2 In Scope - Non-Functional Requirements' 'Heading 2'
  Add-ReportTable $document $selection @('Code', 'Category', 'Description / Target') @(
    @('NFR-C01', 'Compatibility', 'Build and run on Android 15 / API 35 emulator; retain compatibility with supported physical Android devices.'),
    @('NFR-R01', 'Reliability', 'No crash or blank screen while navigating the automated smoke-test scope.'),
    @('NFR-U01', 'Usability', 'Loading, empty, success, and error states are understandable and do not require manual state selection.'),
    @('NFR-S01', 'Security', 'Credentials are not stored in test source; protected requests use the access token returned by the login API.'),
    @('NFR-B01', 'Bluetooth', 'Only stable BLE readings with weight greater than zero can create milling bag records.'),
    @('NFR-T01', 'Testability', 'All committed unit/widget tests and mobile integration smoke tests must pass before delivery.')
  ) @(16, 19, 65) | Out-Null

  Add-Paragraph $selection '1.3 Out of Scope' 'Heading 2'
  Add-ReportTable $document $selection @('Item', 'Reason') @(
    @('Firebase Cloud Messaging and SignalR realtime notifications', 'Removed from the current mobile release and scheduled for a later implementation.'),
    @('Formal load, stress, and penetration testing', 'Requires dedicated infrastructure and a controlled backend test environment.'),
    @('iOS release and App Store deployment', 'Current verification target is Android.'),
    @('Automated physical BLE hardware validation', 'An emulator cannot reliably scan the ESP32 scale; final validation is manual on a real Android phone.'),
    @('Backend internal unit tests', 'The backend repository is not modified by this mobile test cycle.')
  ) @(35, 65) | Out-Null

  Add-Paragraph $selection '1.4 Constraints' 'Heading 2'
  Add-ReportTable $document $selection @('Category', 'Constraint') @(
    @('Backend', 'The default API is hosted on Render and may have cold-start latency.'),
    @('BLE hardware', 'StockLite scale tests require ESP32/HX711 hardware and a physical Android device with Bluetooth permissions.'),
    @('Emulator', 'Android emulator supports UI/API tests but normally cannot discover the BLE scale.'),
    @('Milling API', 'The backend does not expose a dedicated endpoint for each captured bag; individual readings remain local until completion.'),
    @('Test data', 'Availability and state of schedules, stock, customers, deliveries, and milling orders depend on backend seed data.')
  ) @(25, 75) | Out-Null

  Add-Paragraph $selection '1.5 Assumptions' 'Heading 2'
  Add-ReportTable $document $selection @('#', 'Assumption') @(
    @('1', 'The external API is reachable and the supplied test account remains active.'),
    @('2', 'Test data can be changed without affecting production business records.'),
    @('3', 'Android camera and nearby-device permissions can be granted or denied during testing.'),
    @('4', 'The ESP32 firmware advertises the documented StockLite service and characteristic UUIDs.'),
    @('5', 'A failed test is rerun after confirming network, backend availability, and seed-data state.')
  ) @(10, 90) | Out-Null

  Add-PageBreak $selection
  Add-Paragraph $selection '2. Test Strategy' 'Heading 1'
  Add-Paragraph $selection 'Testing follows a risk-based approach. Must-priority field operations and authentication receive automated regression coverage first. Hardware-specific and data-dependent scenarios are completed through structured manual tests on a physical Android device.'

  Add-Paragraph $selection '2.1 Testing Types' 'Heading 2'
  Add-ReportTable $document $selection @('Type', 'Coverage', 'Execution') @(
    @('Unit testing', 'JSON conversion, milling totals/yield, copyWith behavior, and BLE payload parsing.', 'Automated with flutter_test'),
    @('Widget testing', 'Screen rendering, validation messages, account data, navigation, stocktake input, and workflow behavior.', 'Automated with flutter_test'),
    @('Mobile integration testing', 'Application startup, login form interaction, and login against the configured external API.', 'Automated on Android emulator/device'),
    @('API functional testing', 'Repository/API flows for authentication and mobile business screens.', 'Automated where deterministic; otherwise manual'),
    @('BLE testing', 'Permissions, scanning, connection, notify payload, stable capture, tare/reset, reconnect, and multiple bags.', 'Manual on physical Android device'),
    @('Regression testing', 'Full Flutter test suite and smoke integration tests after meaningful code changes.', 'Automated before handoff')
  ) @(22, 54, 24) | Out-Null

  Add-Paragraph $selection '2.2 Test Levels' 'Heading 2'
  Add-ReportTable $document $selection @('Level', 'Scope', 'Current Result', 'Exit Criteria') @(
    @('L1 - Unit', 'Pure model/helper logic without device or network.', '15 focused logic tests pass; included in 32-test Flutter suite.', 'All tests pass.'),
    @('L2 - Widget', 'Screens, inputs, states, and navigation with fake repositories/services.', 'All widget tests pass.', 'No failed widget regression.'),
    @('L3 - Mobile Integration', 'Compiled application on Android emulator/device.', 'Mobile smoke and external API login tests pass.', 'App launches and critical login path succeeds.'),
    @('L4 - System / Manual', 'End-to-end business flows with live backend and hardware.', 'Partially executed; BLE requires physical device.', 'Critical flows pass with representative data.'),
    @('L5 - UAT', 'Tester/business acceptance of field workflows.', 'Pending formal sign-off.', 'No open Critical/Major blocker and signed acceptance.')
  ) @(14, 34, 25, 27) | Out-Null

  Add-Paragraph $selection 'a. Automated Test Flow' 'Heading 3'
  Add-Bullets $selection @(
    'Run flutter test for all unit and widget tests.',
    'Run integration_test/mobile_smoke_test.dart on emulator or physical device.',
    'Run integration_test/api_login_test.dart with credentials supplied through dart-define.',
    'Build the Android debug APK and install it with ADB.',
    'Review failures with Flutter output, screenshots, and Android logcat.'
  )

  Add-Paragraph $selection 'b. Manual BLE Flow' 'Heading 3'
  Add-Bullets $selection @(
    'Use a physical Android phone; enable Bluetooth and grant Nearby Devices permission.',
    'Confirm ESP32 advertises StockLite SCALE-01 and the documented service UUID.',
    'Capture stable rice and bran readings and verify bag count and total weight.',
    'Exercise tare, reset, disconnect, reconnect, permission denial, and Bluetooth-off behavior.'
  )

  Add-Paragraph $selection '2.3 Supporting Tools' 'Heading 2'
  Add-ReportTable $document $selection @('Purpose', 'Tool', 'Version / Configuration') @(
    @('Application framework', 'Flutter', '3.41.9 stable'),
    @('Programming language', 'Dart', '3.11.5'),
    @('Unit/widget testing', 'flutter_test', 'Flutter SDK'),
    @('Mobile integration testing', 'integration_test', 'Flutter SDK'),
    @('Android device control', 'ADB / Android SDK', 'SDK 36.1; emulator API 35'),
    @('BLE communication', 'flutter_blue_plus', '2.3.10'),
    @('Runtime permissions', 'permission_handler', '12.0.3'),
    @('Static analysis', 'flutter analyze', 'Flutter SDK'),
    @('Test automation scripts', 'PowerShell', 'prepare_mobile_test.ps1 / run_mobile_tests.ps1')
  ) @(28, 32, 40) | Out-Null

  Add-PageBreak $selection
  Add-Paragraph $selection '3. Test Plan' 'Heading 1'
  Add-Paragraph $selection '3.1 Test Environment' 'Heading 2'
  Add-ReportTable $document $selection @('Area', 'Configuration', 'Purpose') @(
    @('Development host', 'Windows 11 Enterprise 64-bit', 'Build, unit/widget tests, ADB, and documentation.'),
    @('Flutter runtime', 'Flutter 3.41.9 / Dart 3.11.5', 'Compile and execute StockLite Mobile.'),
    @('Android emulator', 'Android 15, API 35, emulator-5554', 'Automated UI/API mobile integration tests.'),
    @('Physical Android phone', 'Bluetooth Low Energy capable device', 'BLE scale and permission testing.'),
    @('External API', 'https://backend-do-an-api-new.onrender.com', 'Default integrated backend.'),
    @('Local API option', '10.0.2.2:PORT for emulator; PC LAN IP for phone', 'Developer/local backend verification.'),
    @('BLE device', 'ESP32 + HX711, StockLite SCALE-01', 'Realtime milling weight readings.')
  ) @(22, 43, 35) | Out-Null

  Add-Paragraph $selection '3.2 Test Data' 'Heading 2'
  Add-Paragraph $selection 'a. Minimum Test Accounts' 'Heading 3'
  Add-ReportTable $document $selection @('Username', 'Role', 'Password Handling', 'Purpose') @(
    @('admin', 'Administrator', 'Provided securely at execution time', 'Login API, account information, and privileged flows.'),
    @('nhanvienkho', 'Warehouse staff', 'Provided securely at execution time', 'Warehouse, stocktake, delivery, and field workflows.'),
    @('invalid-user', 'None', 'Deliberately invalid', 'Negative authentication and error-message tests.')
  ) @(22, 21, 27, 30) | Out-Null

  Add-Paragraph $selection 'b. Minimum Domain Data' 'Heading 3'
  Add-ReportTable $document $selection @('Entity', 'Required State', 'Purpose') @(
    @('Purchase schedule', 'At least one accessible schedule with detail data', 'Purchase detail and inbound flow.'),
    @('Warehouse stock', 'At least one product with quantity greater than zero', 'Warehouse list, product detail, delivery, and stocktake.'),
    @('Customer', 'At least one active customer', 'Delivery creation and detail validation.'),
    @('Delivery', 'At least one completed or viewable delivery', 'Delivery detail regression.'),
    @('Milling order', 'At least one active order with input lot/location', 'Preparation, BLE weighing, and completion flow.'),
    @('ESP32 scale', 'Advertising and sending valid JSON weight payloads', 'Physical BLE validation.')
  ) @(24, 36, 40) | Out-Null

  Add-Paragraph $selection '3.3 Test Milestones' 'Heading 2'
  Add-ReportTable $document $selection @('Milestone', 'Status', 'Owner', 'Acceptance Criteria') @(
    @('M1 - Unit/widget regression', 'Completed', 'Development / QA', '32 of 32 Flutter tests pass.'),
    @('M2 - Mobile smoke integration', 'Completed', 'QA', 'Application opens and login fields work on Android emulator.'),
    @('M3 - External API login integration', 'Completed', 'QA', 'Configured account reaches Home through the hosted backend.'),
    @('M4 - Full manual business flow', 'Ready', 'Mobile tester', 'Critical purchasing, warehouse, stocktake, delivery, and milling flows pass.'),
    @('M5 - Physical BLE acceptance', 'Pending hardware execution', 'Mobile tester', 'Scale discovery, stable capture, commands, and reconnect pass.'),
    @('M6 - UAT sign-off', 'Pending', 'Product owner / tester', 'No Critical/Major blocker and written acceptance.')
  ) @(25, 20, 20, 35) | Out-Null

  Add-PageBreak $selection
  Add-Paragraph $selection '4. Test Cases' 'Heading 1'
  Add-Paragraph $selection '4.1 Automated Test Assets' 'Heading 2'
  Add-ReportTable $document $selection @('Test File', 'Cases', 'Primary Coverage') @(
    @('account_tab_test.dart', '1', 'Authenticated user name, email, avatar initial, and removal of hard-coded profile.'),
    @('all_screens_smoke_test.dart', '4', 'Reports, inbound/outbound success, and QR scanner shell.'),
    @('giao_hang_detail_test.dart', '1', 'Completed delivery detail.'),
    @('inspection_separation_test.dart', '1', 'Quality inspection and stocktake route separation.'),
    @('json_reader_test.dart', '4', 'Case-insensitive keys and safe type conversion.'),
    @('kho_inventory_test.dart', '2', 'Positive on-hand filtering and latest stocktake date.'),
    @('login_screen_error_test.dart', '2', 'Incorrect username/password handling without creating a session.'),
    @('milling_flow_test.dart', '3', 'Milling calculations and navigation through weighing/confirmation.'),
    @('milling_order_test.dart', '4', 'Rice/bran totals, yield, zero input, and copyWith.'),
    @('purchase_schedule_detail_test.dart', '1', 'Purchase schedule detail mobile layout.'),
    @('stocktake_multi_digit_input_test.dart', '1', 'Multi-digit actual quantity input.'),
    @('weight_reading_test.dart', '7', 'Valid and invalid ESP32 BLE JSON payloads.'),
    @('widget_test.dart', '1', 'Login screen branding and basic content.'),
    @('integration_test/mobile_smoke_test.dart', '1', 'Compiled mobile startup and login input.'),
    @('integration_test/api_login_test.dart', '1', 'Hosted API login and navigation to Home.')
  ) @(34, 10, 56) | Out-Null

  Add-Paragraph $selection '4.2 Requirements Coverage Matrix' 'Heading 2'
  Add-ReportTable $document $selection @('FT-ID', 'Feature', 'Unit / Widget', 'Integration', 'Manual') @(
    @('FT-01', 'Authentication', 'Covered', 'Covered', 'Required'),
    @('FT-02', 'Home/dashboard', 'Covered', 'Smoke', 'Required'),
    @('FT-03', 'Account/session', 'Covered', 'Partial', 'Required'),
    @('FT-04', 'Purchasing/inbound', 'Covered', 'Data-dependent', 'Required'),
    @('FT-05', 'Warehouse/product detail', 'Covered', 'Data-dependent', 'Required'),
    @('FT-06', 'Stocktake', 'Covered', 'Data-dependent', 'Required'),
    @('FT-07', 'Quality inspection', 'Covered', 'Data-dependent', 'Required'),
    @('FT-08', 'Delivery', 'Covered', 'Data-dependent', 'Required'),
    @('FT-09', 'Milling workflow', 'Covered', 'Data-dependent', 'Required'),
    @('FT-10', 'BLE scale', 'Parser covered', 'Not on emulator', 'Physical device required'),
    @('FT-11', 'Reports/history', 'Partial', 'Data-dependent', 'Required'),
    @('FT-12', 'QR scanning', 'Shell covered', 'Permission-dependent', 'Physical camera required'),
    @('FT-13', 'REST notifications', 'Partial', 'Data-dependent', 'Required')
  ) @(10, 31, 19, 18, 22) | Out-Null

  Add-PageBreak $selection
  Add-Paragraph $selection '5. Test Reports' 'Heading 1'
  Add-Paragraph $selection '5.1 Execution Summary' 'Heading 2'
  Add-ReportTable $document $selection @('Round', 'Level', 'Executed', 'Passed', 'Failed', 'Status') @(
    @('Round 1', 'Unit + Widget', '32', '32', '0', 'Passed'),
    @('Round 1', 'Mobile Smoke Integration', '1', '1', '0', 'Passed'),
    @('Round 1', 'External API Login Integration', '1', '1', '0', 'Passed'),
    @('Round 1', 'Physical BLE / Manual', '0', '0', '0', 'Pending'),
    @('Total executed', 'Automated', '34', '34', '0', 'Passed')
  ) @(15, 28, 14, 14, 14, 15) | Out-Null

  Add-Paragraph $selection '5.2 Defect Register' 'Heading 2'
  Add-ReportTable $document $selection @('ID', 'Observation / Defect', 'Severity', 'Status', 'Action') @(
    @('OBS-01', 'Flutter analyzer reports information-level style/deprecation notices in existing code.', 'Low', 'Open observation', 'Clean up incrementally; no compile or test failure.'),
    @('OBS-02', 'Hosted Render backend may respond slowly after an idle cold start.', 'Low', 'Known limitation', 'Allow longer timeout and distinguish cold start from functional failure.'),
    @('OBS-03', 'BLE discovery cannot be accepted on the Android emulator.', 'Expected constraint', 'Pending hardware test', 'Execute the BLE checklist on a physical Android phone.'),
    @('OBS-04', 'Backend has no endpoint dedicated to persisting every individual milling bag reading.', 'Medium', 'Backend gap', 'Keep readings local and define an API contract before production persistence.')
  ) @(13, 39, 15, 17, 16) | Out-Null

  Add-Paragraph $selection '5.3 Exit Criteria and Recommendation' 'Heading 2'
  Add-Bullets $selection @(
    'Automated status: PASS - 34 of 34 executed automated tests passed.',
    'Android build and emulator execution are operational.',
    'Proceed to structured manual testing of live backend business data.',
    'Do not mark BLE scale acceptance complete until it passes on a physical Android phone and ESP32 scale.',
    'Release recommendation: conditionally ready for tester validation; final acceptance depends on manual business-flow and BLE evidence.'
  )

  Add-Paragraph $selection 'Prepared from the StockLite Mobile codebase and automated test results available on 21/07/2026.' 'Block Text'

  try {
    Write-Host 'Updating table of contents and fields...'
    foreach ($toc in $document.TablesOfContents) { $toc.Update() }
  } catch {}
  foreach ($section in $document.Sections) {
    foreach ($footer in $section.Footers) {
      $footerFind = $footer.Range.Find
      $footerFind.Text = '{{Project Code}}'
      $footerFind.Replacement.Text = 'STOCKLITE-MOBILE'
      $footerFind.Wrap = 0
      [void]$footerFind.Execute(
        '{{Project Code}}', $false, $false, $false, $false, $false,
        $true, 0, $false, 'STOCKLITE-MOBILE', $wdReplaceAll
      )
    }
  }
  $document.Repaginate()
  try { $document.Fields.Update() } catch {}
  foreach ($section in $document.Sections) {
    foreach ($footer in $section.Footers) {
      try { $footer.Range.Fields.Update() } catch {}
    }
  }

  Write-Host 'Saving final document...'
  $document.Save()
} finally {
  if ($document) { $document.Close($true) }
  if ($word) { $word.Quit() }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}

Write-Output $Output
