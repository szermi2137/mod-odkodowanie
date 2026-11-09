# Shared helpers for Mod JAR Recovery Toolkit Smart.
# Requires Windows PowerShell 5.1+ and Java 17+ (Java 21 recommended).
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:ToolkitRoot = Split-Path -Parent $PSScriptRoot
$script:MavenBase = 'https://maven.fabricmc.net'
$script:YarnMetadataUrl = "$script:MavenBase/net/fabricmc/yarn/maven-metadata.xml"
$script:IntermediaryMetaUrl = "$script:MavenBase/net/fabricmc/intermediary/maven-metadata.xml"

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-FileSha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-FileSha1([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA1).Hash.ToLowerInvariant()
}

function Invoke-DownloadFile([string]$Url, [string]$Destination, [switch]$Force) {
    Ensure-Directory (Split-Path -Parent $Destination)
    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and -not $Force) {
        if ((Get-Item -LiteralPath $Destination).Length -gt 0) { return $Destination }
    }
    $tmp = "$Destination.download"
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    Write-Host "Pobieranie: $Url" -ForegroundColor DarkCyan
    try {
        Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -TimeoutSec 180
        if (-not (Test-Path -LiteralPath $tmp) -or (Get-Item -LiteralPath $tmp).Length -le 0) {
            throw 'Pobrany plik jest pusty.'
        }
        Move-Item -LiteralPath $tmp -Destination $Destination -Force
    } catch {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        throw "Nie udało się pobrać $Url : $($_.Exception.Message)"
    }
    return $Destination
}

function Get-ZipEntryText([string]$ZipPath, [string]$EntryName) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entry = $zip.GetEntry($EntryName)
        if ($null -eq $entry) { return $null }
        $stream = $entry.Open()
        try {
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8, $true)
            try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
        } finally { $stream.Dispose() }
    } finally { $zip.Dispose() }
}

function Get-ZipEntries([string]$ZipPath) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try { return @($zip.Entries | ForEach-Object { $_.FullName }) } finally { $zip.Dispose() }
}

function Get-SourceNamespace([string]$Path) {
    $entries = Get-ZipEntries $Path
    $classEntries = @($entries | Where-Object { $_.EndsWith('.class', [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 300)
    $hasIntermediary = $false; $hasYarn = $false; $hasMojmap = $false
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($name in $classEntries) {
            $entry = $zip.GetEntry($name)
            if ($null -eq $entry -or $entry.Length -gt 4000000) { continue }
            $stream = $entry.Open()
            try {
                $mem = New-Object System.IO.MemoryStream
                try {
                    $stream.CopyTo($mem)
                    $text = [System.Text.Encoding]::GetEncoding(28591).GetString($mem.ToArray())
                } finally { $mem.Dispose() }
            } finally { $stream.Dispose() }
            if ($text -match 'net/minecraft/class_\d+') { $hasIntermediary = $true }
            if ($text -match 'net/minecraft/client/MinecraftClient|net/minecraft/client/gui/screen/Screen|net/minecraft/client/network/ClientPlayerEntity') { $hasYarn = $true }
            if ($text -match 'net/minecraft/client/gui/screens/Screen|net/minecraft/client/Minecraft;|net/minecraft/client/Minecraft\$') { $hasMojmap = $true }
            if ($hasIntermediary -and $hasYarn -and $hasMojmap) { break }
        }
    } finally { $zip.Dispose() }
    if ($hasIntermediary -and -not $hasYarn) { return 'intermediary' }
    if ($hasYarn -and -not $hasIntermediary) { return 'named' }
    if ($hasMojmap -and -not $hasIntermediary -and -not $hasYarn) { return 'mojmap' }
    return 'unknown'
}

function Expand-TinyMapping([string]$MappingJar, [string]$TinyPath) {
    if ((Test-Path -LiteralPath $TinyPath -PathType Leaf) -and (Get-Item -LiteralPath $TinyPath).Length -gt 1000) {
        return $TinyPath
    }
    Ensure-Directory (Split-Path -Parent $TinyPath)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($MappingJar)
    try {
        $entry = $zip.GetEntry('mappings/mappings.tiny')
        if ($null -eq $entry) { throw "Brak mappings/mappings.tiny w $MappingJar" }
        $source = $entry.Open()
        $target = [System.IO.File]::Create($TinyPath)
        try { $source.CopyTo($target) } finally { $target.Dispose(); $source.Dispose() }
    } finally { $zip.Dispose() }
    $header = Get-Content -LiteralPath $TinyPath -TotalCount 1
    if (-not $header.StartsWith("tiny`t2`t0`t")) { throw "Nieznany format mapowania: $header" }
    return $TinyPath
}

function Get-YarnVersionRows([switch]$Refresh) {
    $metadataCache = Join-Path $script:ToolkitRoot 'cache\metadata\yarn-maven-metadata.xml'
    if ($Refresh -or -not (Test-Path -LiteralPath $metadataCache)) {
        try { Invoke-DownloadFile $script:YarnMetadataUrl $metadataCache -Force | Out-Null } catch {
            if (-not (Test-Path -LiteralPath $metadataCache)) { throw }
            Write-Warning "Nie można odświeżyć metadanych Yarn; używam lokalnej kopii."
        }
    }
    [xml]$xml = Get-Content -LiteralPath $metadataCache -Raw
    return @($xml.metadata.versioning.versions.version | ForEach-Object { [string]$_ })
}

function Get-MinecraftVersionObject([string]$Version) {
    if ($Version -notmatch '^\d+(?:\.\d+){1,2}$') { throw "Niepoprawny numer wersji Minecrafta: $Version" }
    $parts = $Version.Split('.')
    while ($parts.Count -lt 3) { $parts += '0' }
    return [version]::new([int]$parts[0], [int]$parts[1], [int]$parts[2])
}

function Test-MinecraftVersionAtLeast([string]$Version, [string]$Minimum = '1.20.1') {
    try { return (Get-MinecraftVersionObject $Version) -ge (Get-MinecraftVersionObject $Minimum) } catch { return $false }
}

function Get-StableYarnRows([string[]]$Versions, [string]$MinimumGameVersion = '1.20.1', [string]$OnlyGameVersion = $null, [switch]$AllBuilds) {
    $rows = @()
    foreach ($versionText in $Versions) {
        # Only stable release mappings of the form 1.21.4+build.8; snapshots and RCs are excluded.
        if ($versionText -notmatch '^(\d+\.\d+(?:\.\d+)?)\+build\.(\d+)$') { continue }
        $gameVersion = $Matches[1]
        $buildNumber = [int]$Matches[2]
        if (-not (Test-MinecraftVersionAtLeast $gameVersion $MinimumGameVersion)) { continue }
        if ($OnlyGameVersion -and $gameVersion -ne $OnlyGameVersion) { continue }
        $rows += [pscustomobject]@{ GameVersion = $gameVersion; YarnVersion = $versionText; Build = $buildNumber }
    }
    if ($AllBuilds) { return @($rows | Sort-Object @{Expression={ Get-MinecraftVersionObject $_.GameVersion }}, Build) }
    $latest = @()
    foreach ($group in ($rows | Group-Object GameVersion)) {
        $latest += $group.Group | Sort-Object Build -Descending | Select-Object -First 1
    }
    return @($latest | Sort-Object @{Expression={ Get-MinecraftVersionObject $_.GameVersion }})
}

function Get-YarnArtifact([string]$GameVersion, [switch]$RefreshMetadata) {
    $cacheDir = Join-Path $script:ToolkitRoot "cache\yarn\$GameVersion"
    Ensure-Directory $cacheDir
    $row = $null

    # Cache-first: works offline when a mapping JAR for this exact MC version is bundled.
    $escape = [regex]::Escape($GameVersion)
    $cached = @(Get-ChildItem -LiteralPath $cacheDir -Filter "yarn-$GameVersion+build.*-v2.jar" -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -match ("^yarn-" + $escape + "\+build\.(\d+)-v2\.jar$")) {
            [pscustomobject]@{ File=$_.FullName; Build=[int]$Matches[1]; YarnVersion=(($_.BaseName -replace '^yarn-','') -replace '-v2$','') }
        }
    })
    if ($cached.Count -gt 0) {
        $picked = $cached | Sort-Object Build -Descending | Select-Object -First 1
        $row = [pscustomobject]@{ GameVersion=$GameVersion; YarnVersion=$picked.YarnVersion; Build=$picked.Build }
        $jarPath = $picked.File
    } else {
        $versions = Get-YarnVersionRows -Refresh:$RefreshMetadata
        $rows = @(Get-StableYarnRows -Versions $versions -MinimumGameVersion '1.20.1' -OnlyGameVersion $GameVersion)
        if ($rows.Count -eq 0) { throw "Fabric Maven nie ma stabilnych mapowań Yarn dla wersji $GameVersion (albo metadane nie są dostępne)." }
        $row = $rows[0]
        $jarPath = Join-Path $cacheDir ("yarn-{0}-v2.jar" -f $row.YarnVersion)
        $url = "$script:MavenBase/net/fabricmc/yarn/$($row.YarnVersion)/yarn-$($row.YarnVersion)-v2.jar"
        Invoke-DownloadFile $url $jarPath | Out-Null
    }

    $tinyPath = Join-Path $cacheDir ("yarn-{0}.tiny" -f $row.YarnVersion)
    Expand-TinyMapping $jarPath $tinyPath | Out-Null
    $header = (Get-Content -LiteralPath $tinyPath -TotalCount 1)
    if ($header -notmatch "^tiny`t2`t0`tintermediary`tnamed") {
        throw "Mapowania Yarn nie mają oczekiwanego układu intermediary -> named: $header"
    }
    return [pscustomobject]@{ GameVersion=$GameVersion; YarnVersion=$row.YarnVersion; Jar=$jarPath; Tiny=$tinyPath; Sha256=(Get-FileSha256 $jarPath) }
}

function Get-IntermediaryArtifact([string]$GameVersion) {
    $cacheDir = Join-Path $script:ToolkitRoot "cache\intermediary\$GameVersion"
    Ensure-Directory $cacheDir
    $jarPath = Join-Path $cacheDir "intermediary-$GameVersion-v2.jar"
    $tinyPath = Join-Path $cacheDir "intermediary-$GameVersion.tiny"
    if (-not (Test-Path -LiteralPath $jarPath -PathType Leaf)) {
        $url = "$script:MavenBase/net/fabricmc/intermediary/$GameVersion/intermediary-$GameVersion-v2.jar"
        Invoke-DownloadFile $url $jarPath | Out-Null
    }
    Expand-TinyMapping $jarPath $tinyPath | Out-Null
    $header = Get-Content -LiteralPath $tinyPath -TotalCount 1
    if ($header -notmatch "^tiny`t2`t0`tofficial`tintermediary") {
        throw "Mapowania Intermediary nie mają oczekiwanego układu official -> intermediary: $header"
    }
    return [pscustomobject]@{ GameVersion=$GameVersion; Jar=$jarPath; Tiny=$tinyPath; Sha256=(Get-FileSha256 $jarPath) }
}

function Get-MinecraftIntermediaryReference([string]$GameVersion, [string]$TinyRemapperJar, [switch]$Refresh) {
    $refsDir = Join-Path $script:ToolkitRoot "references\$GameVersion"
    Ensure-Directory $refsDir
    $bundled = Get-ChildItem -LiteralPath $refsDir -Filter "minecraft-client-intermediary-$GameVersion*.jar" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($bundled -and -not $Refresh) { return $bundled.FullName }

    $cacheDir = Join-Path $script:ToolkitRoot "cache\minecraft\$GameVersion"
    Ensure-Directory $cacheDir
    $officialJar = Join-Path $cacheDir "minecraft-client-official-$GameVersion.jar"
    $intermediaryJar = Join-Path $refsDir "minecraft-client-intermediary-$GameVersion.jar"

    $manifestPath = Join-Path $script:ToolkitRoot 'cache\metadata\mojang-version-manifest-v2.json'
    if ($Refresh -or -not (Test-Path -LiteralPath $manifestPath)) {
        Invoke-DownloadFile 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json' $manifestPath -Force:$Refresh | Out-Null
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $versionRow = $manifest.versions | Where-Object { $_.id -eq $GameVersion -and $_.type -eq 'release' } | Select-Object -First 1
    if (-not $versionRow) { throw "Nie znaleziono stabilnego wydania Minecrafta $GameVersion w manifeście Mojang." }
    $versionJsonPath = Join-Path $cacheDir "$GameVersion-version.json"
    Invoke-DownloadFile $versionRow.url $versionJsonPath -Force:$Refresh | Out-Null
    $versionJson = Get-Content -LiteralPath $versionJsonPath -Raw | ConvertFrom-Json
    $clientInfo = $versionJson.downloads.client
    if (-not $clientInfo.url) { throw "Manifest Minecrafta $GameVersion nie zawiera client JAR-a." }
    if ($Refresh -or -not (Test-Path -LiteralPath $officialJar)) {
        Invoke-DownloadFile $clientInfo.url $officialJar -Force:$Refresh | Out-Null
    }
    $actualSha1 = Get-FileSha1 $officialJar
    if ($clientInfo.sha1 -and $actualSha1 -ne $clientInfo.sha1.ToLowerInvariant()) {
        throw "SHA-1 pobranego client JAR-a Minecraft $GameVersion nie zgadza się z manifestem Mojang."
    }

    if ($Refresh -or -not (Test-Path -LiteralPath $intermediaryJar)) {
        $intermediary = Get-IntermediaryArtifact $GameVersion
        Write-Host "Przygotowuję referencyjny Minecraft ${GameVersion}: official -> intermediary..." -ForegroundColor Cyan
        & java -jar $TinyRemapperJar $officialJar $intermediaryJar $intermediary.Tiny 'official' 'intermediary'
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $intermediaryJar)) {
            throw "Tiny Remapper nie utworzył referencyjnego JAR-a Minecrafta dla $GameVersion."
        }
    }
    return $intermediaryJar
}

function Get-JavaVersionText {
    try { return ((& java -version 2>&1 | Select-Object -First 1) -join '').Trim() } catch { return 'Java not detected' }
}

function Get-JarToolVersion([string]$JarPath, [string]$Fallback) {
    try {
        $mf = Get-ZipEntryText $JarPath 'META-INF/MANIFEST.MF'
        if ($mf -match '(?im)^Implementation-Version:\s*(.+)$') { return $Matches[1].Trim() }
        if ($mf -match '(?im)^Bundle-Version:\s*(.+)$') { return $Matches[1].Trim() }
    } catch {}
    return $Fallback
}
