from __future__ import annotations

import csv
from datetime import datetime
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
EVENTS_FILE = DATA_DIR / "mode-events.csv"
STATIC_DIR = BASE_DIR / "static"

FIELDNAMES = [
    "timestamp",
    "mode",
    "estimatedfreedmb",
    "estimatedfreedgb",
    "computername",
]

app = FastAPI(title="PC Mode Manager Dashboard")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


class ModeEvent(BaseModel):
    timestamp: datetime
    mode: Literal["Study", "Gaming"]
    estimatedfreedmb: float = Field(ge=0)
    estimatedfreedgb: float = Field(ge=0)
    computername: str = Field(min_length=1, max_length=100)


def ensure_events_file() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    if not EVENTS_FILE.exists():
        with EVENTS_FILE.open("w", newline="", encoding="utf-8") as file:
            csv.DictWriter(file, fieldnames=FIELDNAMES).writeheader()


def read_events() -> list[dict]:
    ensure_events_file()

    with EVENTS_FILE.open("r", newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


@app.get("/")
def dashboard() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/api/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/api/mode-events")
def create_mode_event(event: ModeEvent) -> dict:
    ensure_events_file()

    row = {
        "timestamp": event.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
        "mode": event.mode,
        "estimatedfreedmb": f"{event.estimatedfreedmb:.1f}",
        "estimatedfreedgb": f"{event.estimatedfreedgb:.2f}",
        "computername": event.computername,
    }

    with EVENTS_FILE.open("a", newline="", encoding="utf-8") as file:
        csv.DictWriter(file, fieldnames=FIELDNAMES).writerow(row)

    return {"received": True, "event": row}


@app.get("/api/mode-events")
def get_mode_events(limit: int = 50) -> dict:
    if limit < 1 or limit > 500:
        raise HTTPException(status_code=400, detail="limit must be between 1 and 500")

    events = read_events()
    events.reverse()

    return {"events": events[:limit]}


@app.get("/api/summary")
def get_summary() -> dict:
    events = read_events()
    study_count = sum(event["mode"] == "Study" for event in events)
    gaming_count = sum(event["mode"] == "Gaming" for event in events)

    return {
        "total_activations": len(events),
        "study_activations": study_count,
        "gaming_activations": gaming_count,
        "latest_event": events[-1] if events else None,
    }