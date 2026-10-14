param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Study", "Gaming")]
    [string]$Mode,

    [switch]$Apply
)

# -------------------------------------------------
# Mode configuration
# Process names do NOT include ".exe".
# -------------------------------------------------

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

$modeConfig = @{
    Study = @{
        CloseApps = $studyAppsToClose

        EdgeUrls = @(
            "https://www.perplexity.ai/",
            "https://onq.queensu.ca/"
        )

        LaunchApps = @()
        SettingsUri = $null
        PowerPlan = $null
    }

    Gaming = @{
        CloseApps = $gamingAppsToClose

        EdgeUrls = @()

        LaunchApps = @(
            "$env:LOCALAPPDATA\Discord\Update.exe"
        )

        SettingsUri = "ms-settings:sound"
        PowerPlan = $null
    }
}

# -------------------------------------------------
# Helper functions
# -------------------------------------------------

function Get-RunningConfiguredProcesses {
    param(
        [string[]]$ProcessNames
    )

    $foundProcesses = @()

    foreach ($name in $ProcessNames) {
        $foundProcesses += Get-Process -Name $name -ErrorAction SilentlyContinue
    }

    return $foundProcesses
}

function Get-EdgePath {
    $possiblePaths = @(
        "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
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
        Write-Host "Edge tabs that would open:" -ForegroundColor Yellow

        foreach ($url in $Config.EdgeUrls) {
            Write-Host "- $url"
        }
    }

    if ($Config.LaunchApps.Count -gt 0) {
        Write-Host ""
        Write-Host "Applications that would launch:" -ForegroundColor Yellow

        foreach ($app in $Config.LaunchApps) {
            Write-Host "- $app"
        }
    }

    if ($Config.SettingsUri) {
        Write-Host ""
        Write-Host "Windows Settings page that would open:" -ForegroundColor Yellow
        Write-Host "- $($Config.SettingsUri)"
    }

    if ($Config.PowerPlan) {
        Write-Host ""
        Write-Host "Power plan that would activate:" -ForegroundColor Yellow
        Write-Host "- $($Config.PowerPlan)"
    }
}

function Close-ConfiguredProcesses {
    param(
        [array]$Processes
    )

    foreach ($process in $Processes) {
        try {
            Stop-Process -Id $process.Id -ErrorAction Stop

            Write-Host "Closed $($process.ProcessName) (PID $($process.Id))." `
                -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not close $($process.ProcessName) (PID $($process.Id))."
        }
    }
}

function Open-StudyEdgeTabs {
    param(
        [string[]]$Urls
    )

    $edgePath = Get-EdgePath

    if (-not $edgePath) {
        Write-Warning "Microsoft Edge was not found in a standard install location."
        return
    }

    if ($Urls.Count -eq 0) {
        return
    }

    $arguments = @("--new-window") + $Urls

    Start-Process -FilePath $edgePath -ArgumentList $arguments

    Write-Host "Opened Edge with the Study Mode tabs." -ForegroundColor Green
}

function Open-ConfiguredApplications {
    param(
        [string[]]$Applications
    )

    foreach ($appPath in $Applications) {
        if (Test-Path $appPath) {
            Start-Process -FilePath $appPath
            Write-Host "Launched $appPath." -ForegroundColor Green
        }
        else {
            Write-Warning "Application was not found: $appPath"
        }
    }
}

function Open-SettingsPage {
    param(
        [string]$SettingsUri
    )

    if ($SettingsUri) {
        Start-Process $SettingsUri
        Write-Host "Opened $SettingsUri." -ForegroundColor Green
    }
}

# -------------------------------------------------
# Main script
# -------------------------------------------------

$config = $modeConfig[$Mode]

$runningProcesses = Get-RunningConfiguredProcesses `
    -ProcessNames $config.CloseApps

Show-ModePreview `
    -SelectedMode $Mode `
    -Config $config `
    -Processes $runningProcesses

if (-not $Apply) {
    Write-Host ""
    Write-Host "Dry run only: nothing was changed." -ForegroundColor Green
    Write-Host "To apply this mode, run:" -ForegroundColor Cyan
    Write-Host ".\system-mode.ps1 -Mode $Mode -Apply"
    exit
}

Write-Host ""
$confirmation = Read-Host "Apply $Mode Mode? Type YES to continue"

if ($confirmation -cne "YES") {
    Write-Host "Cancelled. Nothing was changed." -ForegroundColor Yellow
    exit
}

Close-ConfiguredProcesses -Processes $runningProcesses

if ($Mode -eq "Study") {
    Start-Sleep -Seconds 2
    Open-StudyEdgeTabs -Urls $config.EdgeUrls
}

Open-ConfiguredApplications -Applications $config.LaunchApps

Open-SettingsPage -SettingsUri $config.SettingsUri

Write-Host ""
Write-Host "$Mode Mode is now active." -ForegroundColor Green