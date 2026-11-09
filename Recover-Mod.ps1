param(
    [string]$JarPath,
    [string]$GameVersion,
    [ValidateSet('auto','intermediary','named','mojmap','unknown')]
    [string]$SourceNamespace = 'auto',
    [switch]$Remap,
    [switch]$NoEmbeddedManifest,
    [switch]$RefreshReference
)
. (Join-Path $PSScriptRoot 'Common.ps1')

function Read-JarJson([string]$Path, [string]$Name) {
    $raw = Get-ZipEntryText $Path $Name
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    try { return ($raw | ConvertFrom-Json) } catch { return $null }
}
function Get-ModInfo([string]$Path) {
    $fabric = Read-JarJson $Path 'fabric.mod.json'
    $quilt = Read-JarJson $Path 'quilt.mod.json'
    $id = ''; $version = ''; $mcConstraint = ''; $loader = 'unknown'
    if ($fabric) {
        $loader = 'Fabric'
        $id = [string]$fabric.id
        $version = [string]$fabric.version
        if ($fabric.depends -and $fabric.depends.minecraft) { $mcConstraint = [string]$fabric.depends.minecraft }
    } elseif ($quilt) {
        $loader = 'Quilt'
        if ($quilt.quilt_loader) { $id = [string]$quilt.quilt_loader.id; $version = [string]$quilt.quilt_loader.version }
        if ($quilt.quilt_loader.depends) {
            $depends = @($quilt.quilt_loader.depends)
            foreach ($d in $depends) { if ($d.id -eq 'minecraft' -and $d.versions) { $mcConstraint = (@($d.versions) -join ', ') } }
        }
    } else {
        $modsToml = Get-ZipEntryText $Path 'META-INF/mods.toml'
        if ($modsToml) {
            $loader = 'Forge/NeoForge'
            if ($modsToml -match '(?is)modId\s*=\s*["'']([^"'']+)') { $id = $Matches[1] }
            if ($modsToml -match '(?is)version\s*=\s*["'']([^"'']+)') { $version = $Matches[1] }
            if ($modsToml -match '(?is)versionRange\s*=\s*["'']([^"'']+)') { $mcConstraint = $Matches[1] }
        }
    }
    return [pscustomobject]@{ Loader=$loader; Id=$id; ModVersion=$version; MinecraftConstraint=$mcConstraint }
}
function Get-GameVersionSuggestion([string]$Path, $Info) {
    $filename = [System.IO.Path]::GetFileName($Path)
    # First filter candidate strings to plausible Minecraft releases >= 1.20.1,
    # so a mod version like 0.9.3 does not get mistaken for a Minecraft version.
    $rawCandidates = @([regex]::Matches($filename, '(?<![\d.])(\d+\.\d+\.\d+)(?!\d)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    $fileVersions = @($rawCandidates | Where-Object { Test-MinecraftVersionAtLeast $_ '1.20.1' })
    if ($fileVersions.Count -eq 1) { return [pscustomobject]@{ Version=$fileVersions[0]; Reason='nazwa pliku' } }
    if ($fileVersions.Count -gt 1) { return [pscustomobject]@{ Version=''; Reason=('wiele wersji Minecrafta w nazwie: ' + ($fileVersions -join ', ')) } }
    $c = [string]$Info.MinecraftConstraint
    if ($c -match '^\s*[~^=]?\s*(\d+\.\d+\.\d+)\s*$') { return [pscustomobject]@{ Version=$Matches[1]; Reason='fabric.mod.json (wartość ograniczenia; wymaga potwierdzenia)' } }
    return [pscustomobject]@{ Version=''; Reason=('brak jednoznacznej wersji; ograniczenie metadanych: ' + $c) }
}
function Extract-NonClassResources([string]$Jar, [string]$Destination) {
    Ensure-Directory $Destination
    $issues = @()
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Jar)
    try {
        foreach ($entry in $zip.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name) -or $entry.FullName.EndsWith('/')) { continue }
            if ($entry.FullName.EndsWith('.class', [StringComparison]::OrdinalIgnoreCase)) { continue }
            $relative = $entry.FullName.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $target = [System.IO.Path]::GetFullPath((Join-Path $Destination $relative))
            $base = [System.IO.Path]::GetFullPath($Destination).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
            if (-not $target.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { continue }
            Ensure-Directory (Split-Path -Parent $target)
            $src = $entry.Open()
            $dst = [System.IO.File]::Create($target)
            try { $src.CopyTo($dst) } finally { $dst.Dispose(); $src.Dispose() }
            if ($entry.FullName -match '\.(json|mcmeta)$') {
                try { Get-Content -LiteralPath $target -Raw | ConvertFrom-Json | Out-Null }
                catch { $issues += [pscustomobject]@{ Path=$entry.FullName; Error=$_.Exception.Message } }
            }
        }
    } finally { $zip.Dispose() }
    return ,$issues
}
function Add-ToolchainManifestToJar([string]$SourceJar, [string]$OutputJar, [string]$JsonText) {
    Copy-Item -LiteralPath $SourceJar -Destination $OutputJar -Force
    $fs = [System.IO.File]::Open($OutputJar, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
    $archive = $null
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($fs, [System.IO.Compression.ZipArchiveMode]::Update, $false)
        $old = $archive.GetEntry('META-INF/RECOVERY_TOOLCHAIN.json')
        if ($old) { $old.Delete() }
        $entry = $archive.CreateEntry('META-INF/RECOVERY_TOOLCHAIN.json', [System.IO.Compression.CompressionLevel]::Optimal)
        $stream = $entry.Open()
        try {
            $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
            try { $writer.Write($JsonText) } finally { $writer.Dispose() }
        } finally { $stream.Dispose() }
    } finally {
        if ($archive) { $archive.Dispose() }
        $fs.Dispose()
    }
}

try {
    if (-not $JarPath) {
        $JarPath = Read-Host 'Podaj pełną ścieżkę do pliku moda .jar (lub przeciągnij plik do okna i wciśnij Enter)'
        $JarPath = $JarPath.Trim().Trim('"')
    }
    if (-not (Test-Path -LiteralPath $JarPath -PathType Leaf)) { throw "Nie znaleziono pliku: $JarPath" }
    $JarPath = (Resolve-Path -LiteralPath $JarPath).Path
    if ([IO.Path]::GetExtension($JarPath) -ne '.jar') { throw 'Plik wejściowy nie ma rozszerzenia .jar.' }

    $originalEntries = Get-ZipEntries $JarPath
    $classCount = @($originalEntries | Where-Object { $_.EndsWith('.class', [StringComparison]::OrdinalIgnoreCase) }).Count
    if ($classCount -eq 0) { throw 'W JAR-ze nie znaleziono plików .class.' }
    $modInfo = Get-ModInfo $JarPath
    $suggestion = Get-GameVersionSuggestion $JarPath $modInfo
    if (-not $GameVersion) {
        if ($suggestion.Version) {
            $reply = Read-Host "Wersja Minecrafta sugerowana na podstawie $($suggestion.Reason): $($suggestion.Version). Enter = zaakceptuj, wpisz inną wersję albo 0 aby pominąć remapowanie"
            if ($reply -eq '0') { $GameVersion = '' }
            elseif ([string]::IsNullOrWhiteSpace($reply)) { $GameVersion = $suggestion.Version }
            else { $GameVersion = $reply.Trim() }
        } else {
            Write-Host "Nie ustalono jednoznacznej wersji Minecrafta ($($suggestion.Reason))." -ForegroundColor Yellow
            $reply = Read-Host 'Wpisz dokładną wersję (np. 1.21.4) albo 0, aby pominąć remapowanie'
            if ($reply -ne '0') { $GameVersion = $reply.Trim() }
        }
    }
    if ($GameVersion -and -not (Test-MinecraftVersionAtLeast $GameVersion '1.20.1')) {
        Write-Warning 'Wybrana wersja jest starsza niż 1.20.1. Toolkit może wykonać surową dekompilację, ale automatyczne pobieranie mapowań ograniczono do 1.20.1+.'
    }

    if ($SourceNamespace -eq 'auto') {
        $SourceNamespace = Get-SourceNamespace $JarPath
        Write-Host "Heurystycznie wykryta przestrzeń nazw: $SourceNamespace" -ForegroundColor Cyan
    }
    if ($SourceNamespace -eq 'unknown') {
        Write-Host 'Nie da się wiarygodnie rozpoznać przestrzeni nazw z klas.' -ForegroundColor Yellow
        $choose = Read-Host 'Wpisz I tylko gdy wiesz, że JAR używa intermediary; N dla Yarn named; Enter aby pominąć remapowanie'
        if ($choose -match '(?i)^i$') { $SourceNamespace = 'intermediary' }
        elseif ($choose -match '(?i)^n$') { $SourceNamespace = 'named' }
    }

    $baseName = [IO.Path]::GetFileNameWithoutExtension($JarPath) -replace '[^A-Za-z0-9._+-]', '_'
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $outputDir = Join-Path $script:ToolkitRoot "output\$baseName-$stamp"
    Ensure-Directory $outputDir
    $unchangedJar = Join-Path $outputDir ('00-ORIGINAL-UNCHANGED-' + [IO.Path]::GetFileName($JarPath))
    Copy-Item -LiteralPath $JarPath -Destination $unchangedJar
    $sourceOriginal = Join-Path $outputDir '01-source-original'
    $resourcesOut = Join-Path $outputDir '04-resources-original'
    $vfOriginalExit = $null
    $vfNamedExit = $null
    $trExit = $null
    $cp = @()

    $vf = Join-Path $script:ToolkitRoot 'tools\vineflower-1.12.0.jar'
    $tr = Join-Path $script:ToolkitRoot 'tools\tiny-remapper-0.10.4-fat.jar'
    if (-not (Test-Path $vf) -or -not (Test-Path $tr)) { throw 'Brakuje narzędzi w folderze tools. Uruchom Check-Tools.bat.' }

    Write-Host "`n[1/5] Dekompilacja oryginalnego JAR-a..." -ForegroundColor Cyan
    $vfArgs = @('--folder', $JarPath, $sourceOriginal)
    & java -jar $vf @vfArgs
    $vfOriginalExit = $LASTEXITCODE
    if ($vfOriginalExit -ne 0) { Write-Warning "Vineflower zakończył oryginalną dekompilację kodem $vfOriginalExit." }
    $sourceOriginalCount = 0
    if (Test-Path -LiteralPath $sourceOriginal) { $sourceOriginalCount = @(Get-ChildItem -LiteralPath $sourceOriginal -Recurse -File -Filter '*.java').Count }

    Write-Host "`n[2/5] Zbieranie zasobów i walidacja JSON..." -ForegroundColor Cyan
    $jsonIssues = Extract-NonClassResources $JarPath $resourcesOut
    if ($jsonIssues.Count -gt 0) { $jsonIssues | Export-Csv -LiteralPath (Join-Path $outputDir 'JSON_VALIDATION_ISSUES.csv') -NoTypeInformation -Encoding UTF8 }

    $remapStatus = 'SKIPPED'
    $yarnInfo = $null
    $intermediaryInfo = $null
    $referencePath = ''
    $remappedJar = ''
    $namedSourceCount = 0

    if ($Remap) { $doRemap = $true }
    elseif ($SourceNamespace -eq 'intermediary' -and $GameVersion) {
        $remapReply = Read-Host 'JAR wygląda na intermediary. Próbować remapowania do Yarn named? [T/n]'
        $doRemap = ($remapReply -notmatch '(?i)^n$')
    } else { $doRemap = $false }

    if ($doRemap) {
        if (-not $GameVersion) {
            $remapStatus = 'SKIPPED_NO_EXACT_GAME_VERSION'
            Write-Warning 'Nie wybrano dokładnej wersji Minecrafta; pomijam remapowanie.'
        }
        elseif (-not (Test-MinecraftVersionAtLeast $GameVersion '1.20.1')) {
            $remapStatus = 'SKIPPED_YARN_SUPPORT_STARTS_AT_1.20.1'
            Write-Warning 'Automatyczne pobieranie Yarn w tym pakiecie obejmuje stabilne wydania od 1.20.1. Zachowano surową dekompilację.'
        }
        elseif ($SourceNamespace -ne 'intermediary') {
            $remapStatus = 'SKIPPED_UNSUPPORTED_NAMESPACE'
            Write-Warning "Automatyczny przebieg obsługuje tylko intermediary -> named. Namespace '$SourceNamespace' pozostaje do osobnej analizy."
        }
        else {
            try {
                Write-Host "`n[3/5] Dobieranie dokładnych mapowań Yarn..." -ForegroundColor Cyan
                $yarnInfo = Get-YarnArtifact $GameVersion
                Write-Host "Mapowania: Yarn $($yarnInfo.YarnVersion)" -ForegroundColor Green

                Write-Host "`n[4/5] Przygotowanie referencji Minecrafta (może pobrać client JAR)..." -ForegroundColor Cyan
                $referencePath = Get-MinecraftIntermediaryReference $GameVersion $tr -Refresh:$RefreshReference
                try {
                    $intermediaryInfo = Get-IntermediaryArtifact $GameVersion
                } catch {
                    Write-Warning "Nie udało się pobrać mapowań Intermediary do raportu: $($_.Exception.Message)"
                    $intermediaryInfo = $null
                }

                $remappedJar = Join-Path $outputDir ("02-remapped-class-analysis-{0}.jar" -f $GameVersion)
                $refDir = Join-Path $script:ToolkitRoot "references\$GameVersion"
                if (Test-Path -LiteralPath $refDir) {
                    $cp = @(Get-ChildItem -LiteralPath $refDir -File -Filter '*.jar' |
                        Where-Object { $_.FullName -ne $JarPath -and $_.Name -notmatch '^yarn-.*-v2' } |
                        ForEach-Object { $_.FullName })
                }
                if ($cp -notcontains $referencePath) { $cp += $referencePath }

                $trArgs = @($JarPath, $remappedJar, $yarnInfo.Tiny, 'intermediary', 'named') + $cp
                & java -jar $tr @trArgs
                $trExit = $LASTEXITCODE
                if ($trExit -eq 0 -and (Test-Path -LiteralPath $remappedJar)) {
                    $remapStatus = 'SUCCESS_STATIC_ONLY'
                    Write-Host "`n[5/5] Dekompilacja JAR-a po remapowaniu..." -ForegroundColor Cyan
                    $namedDir = Join-Path $outputDir '03-source-named'
                    $vfNamedArgs = @('--folder', $remappedJar, $namedDir)
                    & java -jar $vf @vfNamedArgs
                    $vfNamedExit = $LASTEXITCODE
                    if ($vfNamedExit -eq 0) {
                        $namedSourceCount = @(Get-ChildItem -LiteralPath $namedDir -Recurse -File -Filter '*.java').Count
                    } else {
                        $remapStatus = 'REMAPPED_BUT_DECOMPILE_FAILED'
                    }
                } else {
                    $remapStatus = "FAILED_TINY_REMAPPER_EXIT_$trExit"
                    Write-Warning 'Remapowanie nie powiodło się; zachowano oryginalną dekompilację.'
                }
            } catch {
                $remapStatus = 'FAILED_MAPPING_OR_REFERENCE_PREPARATION'
                Write-Warning "Nie udało się przygotować mapowań/referencji. Oryginalna dekompilacja i zasoby zostały zachowane. Powód: $($_.Exception.Message)"
            }
        }
    }

    $selectedGameVersion = $null
    if ($GameVersion) { $selectedGameVersion = $GameVersion }
    $mappingManifest = $null
    if ($yarnInfo) {
        $referenceHash = $null
        $referenceFilename = $null
        if ($referencePath -and (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
            $referenceHash = Get-FileSha256 $referencePath
            $referenceFilename = [IO.Path]::GetFileName($referencePath)
        }
        $mappingManifest = [ordered]@{
            yarnVersion = $yarnInfo.YarnVersion
            jar = [IO.Path]::GetFileName($yarnInfo.Jar)
            sha256 = $yarnInfo.Sha256
            namespace = 'intermediary -> named'
            intermediaryMappingJar = $(if ($intermediaryInfo) { [IO.Path]::GetFileName($intermediaryInfo.Jar) } else { $null })
            intermediaryMappingSha256 = $(if ($intermediaryInfo) { $intermediaryInfo.Sha256 } else { $null })
            minecraftReference = $referenceFilename
            minecraftReferenceSha256 = $referenceHash
        }
    }
    $referenceManifest = @()
    foreach ($referenceJar in $cp) {
        if (Test-Path -LiteralPath $referenceJar -PathType Leaf) {
            $referenceManifest += [ordered]@{
                filename = [IO.Path]::GetFileName($referenceJar)
                sizeBytes = (Get-Item -LiteralPath $referenceJar).Length
                sha256 = (Get-FileSha256 $referenceJar)
            }
        }
    }
    $toolchain = [ordered]@{
        schemaVersion = 1
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        purpose = 'Recovery provenance; does not certify compile or runtime compatibility.'
        originalJar = [ordered]@{ filename = [IO.Path]::GetFileName($JarPath); sizeBytes = (Get-Item -LiteralPath $JarPath).Length; sha256 = (Get-FileSha256 $JarPath) }
        detectedMod = $modInfo
        gameVersion = $selectedGameVersion
        sourceNamespace = $SourceNamespace
        classCountOriginal = $classCount
        sourceCountOriginal = $sourceOriginalCount
        sourceCountNamed = $namedSourceCount
        remapStatus = $remapStatus
        processExitCodes = [ordered]@{ originalDecompile = $vfOriginalExit; remapper = $trExit; namedDecompile = $vfNamedExit }
        referenceLibraries = $referenceManifest
        tools = [ordered]@{
            java = (Get-JavaVersionText)
            vineflower = [ordered]@{ version = (Get-JarToolVersion $vf '1.12.0'); filename = [IO.Path]::GetFileName($vf); sha256 = (Get-FileSha256 $vf) }
            tinyRemapper = [ordered]@{ version = (Get-JarToolVersion $tr '0.10.4'); filename = [IO.Path]::GetFileName($tr); sha256 = (Get-FileSha256 $tr) }
        }
        mapping = $mappingManifest
        jsonIssues = @($jsonIssues)
        warning = 'Decompilation and remapping are static analysis. Output JAR is not an installable replacement unless its resources, refmaps, signatures, dependencies and runtime behavior are independently validated.'
    }
    $jsonText = $toolchain | ConvertTo-Json -Depth 12
    $toolchainPath = Join-Path $outputDir 'RECOVERY_TOOLCHAIN.json'
    [IO.File]::WriteAllText($toolchainPath, $jsonText, [System.Text.UTF8Encoding]::new($false))
    if (-not $NoEmbeddedManifest) {
        try {
            $annotated = Join-Path $outputDir ('00-ANNOTATED-ARCHIVE-ONLY-' + [IO.Path]::GetFileName($JarPath))
            Add-ToolchainManifestToJar $JarPath $annotated $jsonText
            Write-Host 'Utworzono kopię z META-INF/RECOVERY_TOOLCHAIN.json (tylko archiwalna; podpisy JAR mogą być nieważne).' -ForegroundColor Yellow
        } catch { Write-Warning "Nie udało się osadzić metadanych w kopii JAR-a: $($_.Exception.Message)" }
    }

    $report = @(
        'MOD JAR RECOVERY TOOLKIT SMART - RAPORT',
        ('Generated UTC: ' + [DateTime]::UtcNow.ToString('o')),
        ('Input filename: ' + [IO.Path]::GetFileName($JarPath)),
        ('SHA-256: ' + (Get-FileSha256 $JarPath)),
        ('Loader: ' + $modInfo.Loader),
        ('Mod id/version: ' + $modInfo.Id + ' / ' + $modInfo.ModVersion),
        ('Minecraft constraint: ' + $modInfo.MinecraftConstraint),
        ('Selected Minecraft version: ' + $GameVersion),
        ('Source namespace: ' + $SourceNamespace),
        ('Original class count: ' + $classCount),
        ('Original decompiled .java count: ' + $sourceOriginalCount),
        ('Remap status: ' + $remapStatus),
        ('Named-source .java count: ' + $namedSourceCount),
        ('Invalid JSON/resources: ' + $jsonIssues.Count),
        '',
        'CAUTION: Output is for analysis, not a verified installable mod. Runtime testing is still required.'
    )
    [IO.File]::WriteAllLines((Join-Path $outputDir 'RECOVERY_REPORT.txt'), $report, [System.Text.UTF8Encoding]::new($false))
    Write-Host ''
    Write-Host "Gotowe. Wynik: $outputDir" -ForegroundColor Green
    Write-Host "Oryginalna dekompilacja: $sourceOriginalCount plików Java; po remapowaniu: $namedSourceCount plików Java. Status remapowania: $remapStatus"
    Write-Host 'Czytaj RECOVERY_REPORT.txt i RECOVERY_TOOLCHAIN.json. Oryginalny JAR pozostał bez zmian.'
} catch {
    Write-Host "BŁĄD: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
