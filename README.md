# PC Mode Manager

A Windows PowerShell tool for switching between Study and Gaming modes. It closes selected applications, estimates released RAM, logs each activation locally, and optionally sends mode events to a Raspberry Pi dashboard.

## Features

- Study and Gaming modes
- Preview before applying changes
- Confirmation required before closing applications
- Optional confirmation before closing Visual Studio Code
- Local CSV event history
- Optional Raspberry Pi dashboard event delivery
- Private per-device configuration through `config.local.ps1`

## Requirements

- Windows PowerShell
- Microsoft Edge
- Optional: Discord
- Optional: Raspberry Pi API endpoint

## Setup

1. Clone the repository.
2. Create a private file named `config.local.ps1` in the project root:

   ```powershell
   $PiApiUrl = "http://YOUR_PI_TAILSCALE_IP:8000/api/mode-events"
   ```

3. Run a preview:

   ```powershell
   .\system_mode.ps1 -Mode Study
   ```

4. Apply a mode:

   ```powershell
   .\system_mode.ps1 -Mode Study -Apply
   ```

## Privacy

`config.local.ps1` and generated files in `logs/` are ignored by Git. Do not commit real device names, timestamps, private IP addresses, hostnames, or telemetry logs.

## Notes

RAM values are estimates based on process working-set memory. Windows may not immediately report the same amount as free RAM.