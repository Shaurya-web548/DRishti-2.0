# Opens the generated report in Microsoft Word, fills in the table of
# contents, saves it, and exports a PDF beside it. Needs Word installed.
param(
  [string]$Docx = (Join-Path $PSScriptRoot "out\DRishti_Project_Report.docx")
)
$ErrorActionPreference = "Stop"
$Docx = (Resolve-Path $Docx).Path
$Pdf = [System.IO.Path]::ChangeExtension($Docx, ".pdf")

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
  $doc = $word.Documents.Open($Docx)
  foreach ($toc in $doc.TablesOfContents) { $toc.Update() }
  $doc.Save()
  $doc.ExportAsFixedFormat($Pdf, 17)   # 17 = wdExportFormatPDF
  $doc.Close(0)
} finally {
  $word.Quit()
}
Write-Host "Updated $Docx"
Write-Host "Wrote   $Pdf"
