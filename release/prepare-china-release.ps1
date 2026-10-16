[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$EnvFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manifestPath = Join-Path $PSScriptRoot 'china-public-files.txt'
$resolvedEnvFile = [System.IO.Path]::GetFullPath($EnvFile)
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)

if ($resolvedOutputRoot.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    $repoRoot.StartsWith($resolvedOutputRoot.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputRoot must be a separate artifact directory, not the repository or one of its parents.'
}
if ((Test-Path -LiteralPath $resolvedOutputRoot) -and
    (Get-ChildItem -LiteralPath $resolvedOutputRoot -Force | Select-Object -First 1)) {
    throw 'OutputRoot must not contain existing files.'
}

if (-not (Test-Path -LiteralPath $resolvedEnvFile -PathType Leaf)) {
    throw "Environment file not found: $resolvedEnvFile"
}

$keyLine = Get-Content -LiteralPath $resolvedEnvFile -Encoding UTF8 |
    Where-Object { $_ -match '^\s*(TENCENT_MAP_API|TENCENT_MAP_KEY)\s*=' } |
    Select-Object -First 1
if (-not $keyLine) {
    throw 'Expected TENCENT_MAP_API=<browser key> or TENCENT_MAP_KEY=<browser key> in the environment file.'
}

$tencentMapKey = ($keyLine -split '=', 2)[1].Trim().Trim('"').Trim("'")
if ([string]::IsNullOrWhiteSpace($tencentMapKey)) {
    throw 'Tencent Map browser key is empty.'
}

$cartoKeyLine = Get-Content -LiteralPath $resolvedEnvFile -Encoding UTF8 |
    Where-Object { $_ -match '^\s*(CARTO_BASEMAP_API|CARTO_BASEMAP_KEY)\s*=' } |
    Select-Object -First 1
$cartoBasemapKey = if ($cartoKeyLine) { ($cartoKeyLine -split '=', 2)[1].Trim().Trim('"').Trim("'") } else { '' }

$manifestEntries = Get-Content -LiteralPath $manifestPath -Encoding UTF8 |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }
if ($manifestEntries.Count -ne ($manifestEntries | Sort-Object -Unique).Count) {
    throw 'China release manifest contains duplicate paths.'
}

New-Item -ItemType Directory -Force -Path $resolvedOutputRoot | Out-Null
foreach ($relativePath in $manifestEntries) {
    if ($relativePath -eq 'tencent-map-config.js') { continue }
    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $relativePath))
    if (-not $sourcePath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest path escapes the repository: $relativePath"
    }
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Manifest file not found: $relativePath"
    }
    $destinationPath = Join-Path $resolvedOutputRoot $relativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destinationPath) | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

$configPath = Join-Path $resolvedOutputRoot 'tencent-map-config.js'
$escapedKey = $tencentMapKey.Replace('\', '\\').Replace("'", "\'")
$escapedCartoKey = $cartoBasemapKey.Replace('\', '\\').Replace("'", "\'")
$config = @"
// Generated public browser configuration. Restrict this key to the production domain.
window.SHANGHAI_VENUE_MAP_CONFIG = Object.freeze({
    tencentMapKey: '$escapedKey',
    cartoBasemapKey: '$escapedCartoKey'
});
"@
[System.IO.File]::WriteAllText($configPath, $config, $utf8NoBom)

$forbiddenPatterns = @('trace.source_id', 'source_id', 'docs/debate-transcripts', 'raw-transcript')
$textExtensions = @('.html', '.css', '.js', '.csv', '.json', '.geojson', '.svg', '.txt')
foreach ($file in Get-ChildItem -LiteralPath $resolvedOutputRoot -Recurse -File) {
    if ($textExtensions -notcontains $file.Extension.ToLowerInvariant()) { continue }
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    foreach ($pattern in $forbiddenPatterns) {
        if ($content.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "Forbidden public-release pattern '$pattern' found in $($file.FullName)"
        }
    }
}

$files = Get-ChildItem -LiteralPath $resolvedOutputRoot -Recurse -File
if ($files.Count -ne $manifestEntries.Count) {
    throw "Expected $($manifestEntries.Count) release files but prepared $($files.Count)."
}

[pscustomobject]@{
    OutputRoot = $resolvedOutputRoot
    FileCount = $files.Count
    TencentKeyConfigured = $true
    CartoKeyConfigured = -not [string]::IsNullOrWhiteSpace($cartoBasemapKey)
} | ConvertTo-Json
