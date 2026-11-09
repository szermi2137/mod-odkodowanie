param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sumFile = Join-Path $root 'SHA256SUMS.txt'
$failures = New-Object System.Collections.Generic.List[string]
$checked = 0
Write-Host 'Smart Recovery - kontrola integralności paczki' -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $sumFile)) { throw "Brak pliku sum kontrolnych: $sumFile" }
foreach ($line in Get-Content -LiteralPath $sumFile) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line -notmatch '^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$') {
        $failures.Add("Nieprawidlowy wpis SHA256SUMS.txt: $line")
        continue
    }
    $expected = $Matches[1].ToLowerInvariant()
    $relative = $Matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("BRAK: $relative")
        continue
    }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $checked++
    if ($actual -ne $expected) { $failures.Add("HASH NIEZGODNY: $relative") }
    else { Write-Host "OK  $relative" -ForegroundColor Green }
}
# Test the bundled tool and reference JAR files as ZIP archives.
$jarPaths = @(
    (Join-Path $root 'tools\vineflower-1.12.0.jar'),
    (Join-Path $root 'tools\tiny-remapper-0.10.4-fat.jar')
) + @(Get-ChildItem -LiteralPath (Join-Path $root 'cache') -Recurse -File -Filter '*.jar' -ErrorAction SilentlyContinue | ForEach-Object FullName) + @(Get-ChildItem -LiteralPath (Join-Path $root 'references') -Recurse -File -Filter '*.jar' -ErrorAction SilentlyContinue | ForEach-Object FullName)
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($jar in ($jarPaths | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $jar -PathType Leaf)) { $failures.Add("BRAK JAR: $jar"); continue }
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($jar)
        try { if ($archive.Entries.Count -lt 1) { throw 'Archiwum nie zawiera wpisow.' } }
        finally { $archive.Dispose() }
        Write-Host ("JAR OK  " + [IO.Path]::GetRelativePath($root, $jar)) -ForegroundColor Green
    } catch { $failures.Add("USZKODZONY JAR: $jar -- $($_.Exception.Message)") }
}
Write-Host "`nSprawdzone sumy SHA-256: $checked" -ForegroundColor Cyan
if ($failures.Count -gt 0) {
    Write-Host "Wykryte problemy: $($failures.Count)" -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host " - $failure" -ForegroundColor Red }
    exit 1
}
Write-Host 'Wynik: wszystkie kontrole zakonczone powodzeniem.' -ForegroundColor Green
exit 0
