param(
  [string]$DocumentPath = 'D:\DoAnFlutter\docs\Report_5_StockLite_Test_Documentation.docx',
  [string]$OutputDirectory = 'D:\DoAnFlutter\tmp_testdoc_analysis\page_previews'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$word = $null
$document = $null
try {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $true
  $word.DisplayAlerts = 0
  $document = $word.Documents.Open($DocumentPath, $false, $true)
  $word.ActiveWindow.WindowState = 0
  $word.Activate()
  $pageCount = $document.ComputeStatistics(2)

  for ($page = 1; $page -le $pageCount; $page++) {
    $startRange = $document.GoTo(1, 1, $page)
    $start = $startRange.Start
    if ($page -lt $pageCount) {
      $endRange = $document.GoTo(1, 1, $page + 1)
      $end = $endRange.Start - 1
    } else {
      $end = $document.Content.End - 1
    }

    $pageRange = $document.Range($start, $end)
    [System.Windows.Forms.Clipboard]::Clear()
    $pageRange.Select()
    $word.Selection.CopyAsPicture()
    Start-Sleep -Milliseconds 900
    $image = [System.Windows.Forms.Clipboard]::GetImage()
    if ($null -eq $image) {
      throw "Clipboard did not contain page $page."
    }
    $path = Join-Path $OutputDirectory ('page-{0:D2}.png' -f $page)
    $image.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $image.Dispose()
    Write-Output $path
  }
} finally {
  if ($document) { $document.Close($false) }
  if ($word) { $word.Quit() }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
