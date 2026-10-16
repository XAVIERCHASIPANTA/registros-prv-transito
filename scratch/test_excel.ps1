try {
  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false
  $excel.DisplayAlerts = $false
  $path = (Get-Item 'scratch\test_salida_oficial.xlsx').FullName
  $wb = $excel.Workbooks.Open($path)
  Write-Host "SUCCESS: Workbook opened cleanly! Sheet count: $($wb.Sheets.Count)"
  $wb.Close($false)
  $excel.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
} catch {
  Write-Host "ERROR: $($_.Exception.Message)"
}
