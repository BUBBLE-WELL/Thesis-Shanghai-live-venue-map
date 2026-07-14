Set-Location $PSScriptRoot
Write-Host 'Local demo: http://localhost:8765/index.html'
py -m http.server 8765
