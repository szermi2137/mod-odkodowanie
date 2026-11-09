. (Join-Path $PSScriptRoot 'Common.ps1')
$failed = $false
Write-Host 'Mod JAR Recovery Toolkit Smart — kontrola narzędzi' -ForegroundColor Cyan
Write-Host ('Folder: ' + $script:ToolkitRoot)
Write-Host ''

$javaText = Get-JavaVersionText
Write-Host ('Java: ' + $javaText)
try {
    $javaOut = (& java -version 2>&1 | Out-String)
    if ($javaOut -match 'version "(?<v>\d+)') {
        $javaMajor = [int]$Matches['v']
        if ($javaMajor -lt 17) { Write-Host '  BŁĄD: Vineflower 1.12.0 wymaga Java 17+.' -ForegroundColor Red; $failed = $true }
        else { Write-Host '  OK: wersja Javy jest wystarczająca.' -ForegroundColor Green }
    } else { Write-Host '  UWAGA: nie udało się rozpoznać wersji Java.' -ForegroundColor Yellow }
} catch { Write-Host '  BŁĄD: nie znaleziono java.exe. Zainstaluj JDK 21 i dodaj do PATH.' -ForegroundColor Red; $failed = $true }

$toolRows = @(
    [pscustomobject]@{ Name='Vineflower'; Path=(Join-Path $script:ToolkitRoot 'tools\vineflower-1.12.0.jar'); Expected='1.12.0' },
    [pscustomobject]@{ Name='Tiny Remapper'; Path=(Join-Path $script:ToolkitRoot 'tools\tiny-remapper-0.10.4-fat.jar'); Expected='0.10.4' }
)
foreach ($tool in $toolRows) {
    if (Test-Path -LiteralPath $tool.Path -PathType Leaf) {
        $hash = Get-FileSha256 $tool.Path
        Write-Host ("  OK: {0} {1} (SHA-256 {2})" -f $tool.Name,$tool.Expected,$hash.Substring(0,12)) -ForegroundColor Green
    } else {
        Write-Host ("  BRAK: {0} — {1}" -f $tool.Name,$tool.Path) -ForegroundColor Red
        $failed = $true
    }
}

$knownMappings = @(
    [pscustomobject]@{ Version='1.21.4'; Pattern='yarn-1.21.4+build.*-v2.jar' },
    [pscustomobject]@{ Version='1.21.8'; Pattern='yarn-1.21.8+build.*-v2.jar' }
)
foreach ($m in $knownMappings) {
    $found = Get-ChildItem -LiteralPath (Join-Path $script:ToolkitRoot "cache\yarn\$($m.Version)") -Filter $m.Pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { Write-Host ("  OK: Yarn {0} ({1})" -f $m.Version,$found.Name) -ForegroundColor Green }
    else { Write-Host ("  INFO: brak cache Yarn {0}; skrypt może pobrać go online." -f $m.Version) -ForegroundColor Yellow }
}

Write-Host ''
if ($failed) { Write-Host 'Kontrola zakończona z błędami. Napraw pozycje oznaczone BRAK.' -ForegroundColor Red; exit 1 }
Write-Host 'Kontrola zakończona. Toolkit jest gotowy do próby odzyskiwania.' -ForegroundColor Green
