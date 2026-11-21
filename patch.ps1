<#
.SYNOPSIS
    Skrip patch manual untuk mengisi/menambal commit streak dev-heart yang bolong.

.DESCRIPTION
    Skrip ini menerima rentang tanggal (-Start dan -End), memeriksa kondisi git working tree,
    melakukan git pull --rebase, membuat 8-12 commit per hari dengan timestamp jam 23:00 WIB,
    lalu melakukan push ke remote repository.

.PARAMETER Start
    Tanggal mulai (format: yyyy-MM-dd, contoh: "2026-11-16").

.PARAMETER End
    Tanggal akhir (format: yyyy-MM-dd, contoh: "2026-11-16"). 
    Jika tidak diisi, otomatis bernilai sama dengan parameter -Start.

.EXAMPLE
    .\patch.ps1 -Start "2026-11-16"
    Menambal commit untuk satu tanggal: 16 November 2026.

.EXAMPLE
    .\patch.ps1 -Start "2026-11-14" -End "2026-11-16"
    Menambal commit dari tanggal 14 sampai 16 November 2026.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Start,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$End
)

$ErrorActionPreference = "Stop"

# Set encoding konsisten
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Validasi tanggal
try {
    $parsedStart = [datetime]::ParseExact($Start, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
} catch {
    Write-Error "Format parameter -Start tidak valid. Gunakan format 'yyyy-MM-dd' (contoh: '2026-11-16')."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($End)) {
    $parsedEnd = $parsedStart
} else {
    try {
        $parsedEnd = [datetime]::ParseExact($End, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
        Write-Error "Format parameter -End tidak valid. Gunakan format 'yyyy-MM-dd' (contoh: '2026-11-16')."
        exit 1
    }
}

if ($parsedEnd -lt $parsedStart) {
    Write-Error "Tanggal -End ($End) tidak boleh lebih awal dari -Start ($Start)."
    exit 1
}

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  dev-heart Streak Patcher" -ForegroundColor Green
Write-Host "  Rentang: $($parsedStart.ToString('yyyy-MM-dd')) s/d $($parsedEnd.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Cyan

# 1. Cek status working tree
$stashed = $false
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Host "[1/5] Working tree tidak bersih. Melakukan git stash..." -ForegroundColor Yellow
    git stash push -u -m "dev-heart patch.ps1 auto-stash $(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $stashed = $true
} else {
    Write-Host "[1/5] Working tree bersih." -ForegroundColor Green
}

try {
    # 2. Rebase pull dari origin
    Write-Host "[2/5] Melakukan git pull --rebase origin main..." -ForegroundColor Cyan
    git pull --rebase origin main
    if ($LASTEXITCODE -ne 0) {
        throw "Gagal melakukan git pull --rebase. Silakan selesaikan konflik terlebih dahulu."
    }

    # 3. Loop commit tanggal
    Write-Host "[3/5] Memulai pembuatan commit..." -ForegroundColor Cyan
    $currentDate = $parsedStart
    $totalCommitsMade = 0
    $patchFile = Join-Path $PSScriptRoot "patch.txt"

    # Pastikan file patch ada
    if (-not (Test-Path $patchFile)) {
        New-Item -ItemType File -Path $patchFile -Force | Out-Null
    }

    while ($currentDate -le $parsedEnd) {
        $dateStr = $currentDate.ToString("yyyy-MM-dd")
        # Commit acak 8-12 kali
        $commitCount = Get-Random -Minimum 8 -Maximum 13
        Write-Host "  -> Tanggal $dateStr: membuat $commitCount commit..." -ForegroundColor Magenta

        for ($i = 1; $i -le $commitCount; $i++) {
            # Format waktu: 23:00 WIB (+0700) dengan detik berurutan
            $secStr = ($i * 2).ToString("D2")
            if ($i * 2 -ge 60) {
                $secStr = "59"
            }
            $customDate = "$dateStr 23:00:$secStr +0700"

            # Tulis ke patch.txt
            $patchLogLine = "[$customDate] dev-heart patch batch $i of $commitCount for $dateStr"
            Add-Content -Path $patchFile -Value $patchLogLine -Encoding UTF8

            git add patch.txt

            # Set baik Author Date maupun Committer Date agar sinkron di GitHub
            $env:GIT_AUTHOR_DATE = $customDate
            $env:GIT_COMMITTER_DATE = $customDate

            $commitMsg = "chore(patch): streak restore $dateStr part $i of $commitCount [dev-heart]"
            git commit --date="$customDate" -m "$commitMsg" --quiet

            if ($LASTEXITCODE -ne 0) {
                throw "Gagal melakukan commit untuk batch $i pada tanggal $dateStr"
            }

            $totalCommitsMade++
        }

        $currentDate = $currentDate.AddDays(1)
    }

    # Bersihkan env vars
    Remove-Item env:GIT_AUTHOR_DATE -ErrorAction SilentlyContinue
    Remove-Item env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue

    Write-Host "[4/5] Berhasil membuat $totalCommitsMade commit lokal." -ForegroundColor Green

    # 4. Pull rebase terakhir dan Push ke remote
    Write-Host "[5/5] Mengunggah perubahan ke remote..." -ForegroundColor Cyan
    git pull --rebase origin main
    git push origin main
    if ($LASTEXITCODE -ne 0) {
        throw "Gagal melakukan git push origin main."
    }

    Write-Host "=====================================================" -ForegroundColor Green
    Write-Host "  SELESAI! $totalCommitsMade commit berhasil di-push ke GitHub." -ForegroundColor Green
    Write-Host "=====================================================" -ForegroundColor Green

} catch {
    Write-Error "Terjadi kesalahan: $_"
} finally {
    # Bersihkan env vars jika ada sisa
    Remove-Item env:GIT_AUTHOR_DATE -ErrorAction SilentlyContinue
    Remove-Item env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue

    # Kembalikan stash jika ada
    if ($stashed) {
        Write-Host "Mengembalikan status working tree dari stash..." -ForegroundColor Yellow
        git stash pop
    }
}
