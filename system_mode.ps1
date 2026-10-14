param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Study", "Gaming")]
    [string]$Mode,

    [switch]$Apply
)

# =============================================
# System Mode Manager - Windows-only v1
# =============================================

$studyAppsToClose = @(
    "msedge",
    "outlook",
    "olk",
    "winword",
    "excel",
    "powerpnt",
    "onenote",
    "teams",
    "discord",
    "steam",
    "steamwebhelper",
    "spotify"
)

$gamingAppsToClose = @(
    "msedge",
    "outlook",
    "olk",
    "winword",
    "excel",
    "powerpnt",
    "onenote",
    "teams",
    "spotify"
)
$appsToAskBeforeClosing = @(
    "code"
)

$modeConfig = @{
    Study = @{
        CloseApps = $studyAppsToClose

        EdgeUrls = @(
            "https://www.perplexity.ai/",
            "https://onq.queensu.ca/"
        )

        LaunchDiscord = $false
        OpenSoundSettings = $false
    }

    Gaming = @{
        CloseApps = $gamingAppsToClose

        EdgeUrls = @()

        LaunchDiscord = $true
        OpenSoundSettings = $true
    }
}

function Get-ConfiguredRunningProcesses {
    param(
        [string[]]$ProcessNames
    )

    $processes = @()

    foreach ($name in $ProcessNames) {
        $processes += Get-Process -Name $name -ErrorAction SilentlyContinue
    }

    return $processes
}

function Show-ModePreview {
    param(
        [string]$SelectedMode,
        [hashtable]$Config,
        [array]$Processes
    )

    Write-Host ""
    Write-Host "$SelectedMode Mode Preview" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan

    if ($Processes.Count -gt 0) {
        Write-Host ""
        Write-Host "Processes that would close:" -ForegroundColor Yellow

        $Processes |
            Sort-Object ProcessName, Id |
            Select-Object ProcessName, Id, @{
                Name = "MemoryMB"
                Expression = {
                    [math]::Round($_.WorkingSet64 / 1MB, 1)
                }
            } |
            Format-Table -AutoSize
    }
    else {
        Write-Host ""
        Write-Host "No configured applications are currently running." -ForegroundColor Green
    }

    if ($Config.EdgeUrls.Count -gt 0) {
        Write-Host ""
        Write-Host "Edge pages that would open:" -ForegroundColor Yellow

        foreach ($url in $Config.EdgeUrls) {
            Write-Host "- $url"
        }
    }

    if ($Config.LaunchDiscord) {
        Write-Host ""
        Write-Host "Application that would open:" -ForegroundColor Yellow
        Write-Host "- Discord"
    }

    if ($Config.OpenSoundSettings) {
        Write-Host ""
        Write-Host "Windows Settings page that would open:" -ForegroundColor Yellow
        Write-Host "- Sound"
    }
}

function Close-ConfiguredProcesses {
    param(
        [array]$Processes
    )

    foreach ($process in $Processes) {
        try {
            Stop-Process -Id $process.Id -ErrorAction Stop
            Write-Host "Closed $($process.ProcessName) (PID $($process.Id))." -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not close $($process.ProcessName) (PID $($process.Id))."
        }
    }
}

function Open-StudyEdgePages {
    param(
        [string[]]$Urls
    )

    foreach ($url in $Urls) {
        try {
            Start-Process "microsoft-edge:$url" -ErrorAction Stop
            Write-Host "Opened $url in Edge." -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not open $url in Edge."
        }
    }
}

function Start-Discord {
    $discordPaths = @(
        "$env:LOCALAPPDATA\Discord\Update.exe",
        "$env:APPDATA\Discord\Update.exe"
    )

    foreach ($path in $discordPaths) {
        if (Test-Path $path) {
            Start-Process -FilePath $path -ArgumentList "--processStart Discord.exe"
            Write-Host "Opened Discord." -ForegroundColor Green
            return
        }
    }

    Write-Warning "Discord was not found in the standard locations."
}

function Open-SoundSettings {
    try {
        Start-Process "ms-settings:sound" -ErrorAction Stop
        Write-Host "Opened Windows Sound Settings." -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not open Windows Sound Settings."
    }
}
function Get-ProcessMemoryMB {
    param(
        [array]$Processes
    )

    $totalBytes = 0

    foreach ($process in $Processes) {
        try {
            $process.Refresh()
            $totalBytes += $process.WorkingSet64
        }
        catch {
            Write-Warning "Could not read memory for $($process.ProcessName)."
        }
    }

    return [math]::Round($totalBytes / 1MB, 1)
}

function Confirm-AndCloseOptionalApps {
    param(
        [string[]]$ProcessNames
    )

    $closedMemoryMB = 0

    foreach ($name in $ProcessNames) {
        $processes = @(Get-Process -Name $name -ErrorAction SilentlyContinue)

        if ($processes.Count -eq 0) {
            continue
        }

        $memoryMB = [math]::Round(
            (($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB),
            1
        )

        $answer = Read-Host `
            "VS Code has $($processes.Count) processes using $memoryMB MB. Close all VS Code processes? Type Y or N"

        if ($answer -match "^(Y|YES)$") {
            try {
                Stop-Process -Name $name -ErrorAction Stop
                $closedMemoryMB += $memoryMB

                Write-Host "Closed all VS Code processes." -ForegroundColor Green
            }
            catch {
                Write-Warning "Could not close all VS Code processes."
            }
        }
        else {
            Write-Host "Kept VS Code open." -ForegroundColor Yellow
        }
    }

    return $closedMemoryMB
}
# =============================================
# Main
# =============================================

$config = $modeConfig[$Mode]

$runningProcesses = Get-ConfiguredRunningProcesses -ProcessNames $config.CloseApps

Show-ModePreview `
    -SelectedMode $Mode `
    -Config $config `
    -Processes $runningProcesses

if (-not $Apply) {
    Write-Host ""
    Write-Host "Dry run only: nothing was changed." -ForegroundColor Green
    Write-Host "Run this to apply the selected mode:" -ForegroundColor Cyan
    Write-Host ".\system-mode.ps1 -Mode $Mode -Apply"
    exit
}

Write-Host ""
$confirmation = Read-Host "Apply $Mode Mode? Type YES to continue"

if ($confirmation -cne "YES") {
    Write-Host "Cancelled. Nothing was changed." -ForegroundColor Yellow
    exit
}

$estimatedFreedMB = Get-ProcessMemoryMB -Processes $runningProcesses

Write-Host ""
Write-Host "Estimated RAM to be released: $estimatedFreedMB MB" -ForegroundColor Cyan

Close-ConfiguredProcesses -Processes $runningProcesses
$optionalFreedMB = Confirm-AndCloseOptionalApps `
    -ProcessNames $appsToAskBeforeClosing

$estimatedFreedMB += $optionalFreedMB

Start-Sleep -Seconds 2

if ($Mode -eq "Study") {
    Open-StudyEdgePages -Urls $config.EdgeUrls
}

if ($config.LaunchDiscord) {
    Start-Discord
}

if ($config.OpenSoundSettings) {
    Open-SoundSettings
}

Write-Host "Estimated RAM released: $estimatedFreedMB MB" -ForegroundColor Cyan
Write-Host ""
Write-Host "$Mode Mode is active." -ForegroundColor Green