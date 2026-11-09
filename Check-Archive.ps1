param([Parameter(Mandatory=$true)][string]$JarPath)
. (Join-Path $PSScriptRoot 'Common.ps1')
try {
    if (-not (Test-Path -LiteralPath $JarPath -PathType Leaf)) { throw "Nie znaleziono pliku: $JarPath" }
    $entries = Get-ZipEntries $JarPath
    $classes = @($entries | Where-Object { $_.EndsWith('.class', [StringComparison]::OrdinalIgnoreCase) }).Count
    $fabric = Get-ZipEntryText $JarPath 'fabric.mod.json'
    $quilt = Get-ZipEntryText $JarPath 'quilt.mod.json'
    $forge = Get-ZipEntryText $JarPath 'META-INF/mods.toml'
    $info = Get-Item -LiteralPath $JarPath
    Write-Host "Plik: $($info.FullName)"
    Write-Host "Rozmiar: $($info.Length) bajtów"
    Write-Host "SHA-256: $(Get-FileSha256 $JarPath)"
    Write-Host "Wpisy: $($entries.Count); klasy Java: $classes"
    Write-Host "Fabric metadata: $([bool]$fabric); Quilt metadata: $([bool]$quilt); mods.toml: $([bool]$forge)"
    if ($fabric) {
        try {
            $meta = $fabric | ConvertFrom-Json
            Write-Host "Mod ID/version: $($meta.id) / $($meta.version)"
            if ($meta.depends.minecraft) { Write-Host "Minecraft constraint: $($meta.depends.minecraft)" }
        } catch { Write-Warning "fabric.mod.json ma niepoprawny JSON: $($_.Exception.Message)" }
    }
    $ns = Get-SourceNamespace $JarPath
    Write-Host "Namespace heuristic: $ns"
    Write-Host 'Uwaga: namespace jest określany heurystycznie; sprawdź także mixiny i refmapy.'
} catch { Write-Host "BŁĄD: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
