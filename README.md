# PC Mode Manager

PC Mode Manager is a Windows PowerShell automation project that switches a computer between Study and Gaming modes. It closes selected applications, estimates released RAM, saves a local event log, and sends each activation to a Raspberry Pi dashboard.

## Features

- Study and Gaming modes
- Preview before making changes
- Confirmation required before closing applications
- Optional prompt before closing Visual Studio Code
- Estimated process working-set memory released
- Local CSV logging
- Raspberry Pi dashboard for event history and activation totals
- Tailscale-friendly private communication between the Windows PC and Raspberry Pi

## Project Structure

```text
PC-mode-manager/
├─ system_mode.ps1
├─ modes.json
├─ config.local.ps1              # Local only; ignored by Git
├─ logs/
│  ├─ mode-history.example.csv
│  └─ mode-history.csv           # Local only; ignored by Git
└─ pi-dashboard/
   ├─ app.py
   ├─ requirements.txt
   ├─ system-mode-dashboard.service.example
   ├─ data/
   │  ├─ .gitkeep
   │  └─ mode-events.csv         # Local only; ignored by Git
   └─ static/
      ├─ index.html
      ├─ app.js
      └─ styles.css
```

## Windows Setup

### Requirements

- Windows PowerShell
- Microsoft Edge
- Optional: Discord
- Optional: Raspberry Pi running the dashboard service
- Optional: Tailscale on both devices

### Configure the Pi endpoint

Create `config.local.ps1` in the repository root. This file is private and must not be committed.

```powershell
$PiApiUrl = "http://YOUR_PI_TAILSCALE_IP:8000/api/mode-events"
```

For a local Wi-Fi-only setup, a local Pi hostname or LAN IP can be used instead.

### Preview a mode

A preview lists affected applications without changing the computer:

```powershell
.\system_mode.ps1 -Mode Study
```

```powershell
.\system_mode.ps1 -Mode Gaming
```

### Apply a mode

Add `-Apply`, then type `YES` when asked:

```powershell
.\system_mode.ps1 -Mode Study -Apply
```

```powershell
.\system_mode.ps1 -Mode Gaming -Apply
```

## Raspberry Pi Setup

The following commands assume the repository is cloned to:

```text
/home/YOUR_PI_USERNAME/system_mode-dashboard
```

### Install the application

```bash
cd /home/YOUR_PI_USERNAME/system_mode-dashboard
python3 -m venv .venv
source .venv/bin/activate
pip install -r pi-dashboard/requirements.txt
```

### Test the dashboard manually

```bash
cd /home/YOUR_PI_USERNAME/system_mode-dashboard/pi-dashboard
../.venv/bin/python -m uvicorn app:app --host 0.0.0.0 --port 8000
```

Open this address from a device that can reach the Pi:

```text
http://YOUR_PI_TAILSCALE_IP:8000
```

Check the API health endpoint:

```text
http://YOUR_PI_TAILSCALE_IP:8000/api/health
```

### Run with systemd

Copy the example service file and replace `YOUR_PI_USERNAME` with the real Linux username:

```bash
sudo cp pi-dashboard/system-mode-dashboard.service.example /etc/systemd/system/system-mode-dashboard.service
sudo nano /etc/systemd/system/system-mode-dashboard.service
```

Enable and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now system-mode-dashboard
sudo systemctl status system-mode-dashboard
```

View service logs:

```bash
journalctl -u system-mode-dashboard -f
```

## Dashboard API

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/` | Dashboard page |
| `GET` | `/api/health` | Service health check |
| `POST` | `/api/mode-events` | Receive a mode activation from Windows |
| `GET` | `/api/mode-events?limit=50` | Recent dashboard events |
| `GET` | `/api/summary` | Activation counts and latest event |

A posted event includes:

```json
{
  "timestamp": "2026-10-14 19:20:44",
  "mode": "Study",
  "estimatedfreedmb": 1868.7,
  "estimatedfreedgb": 1.82,
  "computername": "EXAMPLE-PC"
}
```

## Privacy and Security

- Do not commit `config.local.ps1`.
- Do not commit generated CSV files, real device names, usage timestamps, local paths, private IP addresses, hostnames, or credentials.
- Tailscale keeps the dashboard reachable only within your private tailnet when you use its Tailscale address.
- The dashboard API has no authentication. Only expose it to trusted devices and networks. Add authentication before exposing it beyond your private network.

## Notes

The RAM value is an estimate based on process working-set memory. Closing a process does not guarantee Windows immediately reports the same amount as free RAM.