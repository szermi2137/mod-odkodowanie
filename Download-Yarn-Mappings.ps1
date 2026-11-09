param(
    [string]$GameVersion,
    [switch]$AllBuilds
)
. (Join-Path $PSScriptRoot 'Common.ps1')

try {
    $versions = Get-YarnVersionRows -Refresh
    if ($GameVersion) {
        $rows = @(Get-StableYarnRows -Versions $versions -MinimumGameVersion '1.20.1' -OnlyGameVersion $GameVersion -AllBuilds:$AllBuilds)
    } else {
        $rows = @(Get-StableYarnRows -Versions $versions -MinimumGameVersion '1.20.1' -AllBuilds:$AllBuilds)
    }
    if (-not $rows -or $rows.Count -eq 0) {
        throw 'Nie znaleziono mapowań Yarn spełniających kryteria. Sprawdź numer wersji i połączenie z internetem.'
    }

    $indexPath = Join-Path $script:ToolkitRoot 'cache\yarn\YARN_DOWNLOAD_INDEX.csv'
    $result = @()
    $total = $rows.Count
    $i = 0
    foreach ($row in $rows) {
        $i++
        Write-Progress -Activity 'Pobieranie mapowań Yarn' -Status ("{0}/{1}: Minecraft {2}, Yarn {3}" -f $i,$total,$row.GameVersion,$row.YarnVersion) -PercentComplete ([int](100*$i/$total))
        $cacheDir = Join-Path $script:ToolkitRoot "cache\yarn\$($row.GameVersion)"
        Ensure-Directory $cacheDir
        $jarPath = Join-Path $cacheDir ("yarn-{0}-v2.jar" -f $row.YarnVersion)
        $url = "$script:MavenBase/net/fabricmc/yarn/$($row.YarnVersion)/yarn-$($row.YarnVersion)-v2.jar"
        $ok = $false
        $reason = ''
        try {
            Invoke-DownloadFile $url $jarPath | Out-Null
            $tinyPath = Join-Path $cacheDir ("yarn-{0}.tiny" -f $row.YarnVersion)
            Expand-TinyMapping $jarPath $tinyPath | Out-Null
            $header = Get-Content -LiteralPath $tinyPath -TotalCount 1
            if ($header -notmatch "^tiny`t2`t0`tintermediary`tnamed") { throw "Nieoczekiwany nagłówek Tiny: $header" }
            $ok = $true
        } catch {
            $reason = $_.Exception.Message
            Write-Warning ("Błąd dla {0}: {1}" -f $row.YarnVersion,$reason)
        }
        $statusText = 'FAILED'
        $outPath = ''
        $sha = ''
        if ($ok) { $statusText = 'OK'; $outPath = $jarPath; $sha = Get-FileSha256 $jarPath }
        $result += [pscustomobject]@{
            GameVersion = $row.GameVersion
            YarnVersion = $row.YarnVersion
            Build = $row.Build
            Status = $statusText
            JarPath = $outPath
            SHA256 = $sha
            Error = $reason
        }
    }
    Write-Progress -Activity 'Pobieranie mapowań Yarn' -Completed
    Ensure-Directory (Split-Path -Parent $indexPath)
    $result | Export-Csv -LiteralPath $indexPath -NoTypeInformation -Encoding UTF8
    $success = @($result | Where-Object Status -eq 'OK').Count
    $failed = @($result | Where-Object Status -eq 'FAILED').Count
    Write-Host ''
    Write-Host "Pobieranie zakończone. Sukces: $success; błędy: $failed; razem: $total." -ForegroundColor Green
    Write-Host "Indeks: $indexPath"
    if ($failed -gt 0) { exit 2 }
} catch {
    Write-Host "BŁĄD: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
