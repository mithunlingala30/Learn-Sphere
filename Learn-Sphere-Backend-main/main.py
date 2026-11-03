"""Learn Sphere backend (FastAPI, in-memory storage, no auth).

Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8000
Docs: http://localhost:8000/docs
"""
from datetime import date as date_cls
from threading import Lock
from typing import Dict, List, Literal, Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="Learn Sphere API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------- storage
# usage[date_str][package_name] = {"app_name": str, "seconds": int}
usage: Dict[str, Dict[str, dict]] = {}
# limits[package_name] = {"app_name": str, "daily_limit_minutes": int, "warn_at_percent": int}
limits: Dict[str, dict] = {}
lock = Lock()


# ---------------------------------------------------------------- schemas
class UsageLog(BaseModel):
    package_name: str = Field(..., examples=["com.instagram.android"])
    app_name: Optional[str] = Field(None, examples=["Instagram"])
    seconds: int = Field(..., gt=0, description="Seconds of use to ADD")
    date: Optional[date_cls] = None


class UsageTotal(BaseModel):
    package_name: str
    app_name: Optional[str] = None
    seconds: int = Field(..., ge=0, description="Total seconds used that day")


class UsageSync(BaseModel):
    date: Optional[date_cls] = None
    apps: List[UsageTotal]


class LimitIn(BaseModel):
    app_name: Optional[str] = None
    daily_limit_minutes: int = Field(..., gt=0, le=1440)
    warn_at_percent: int = Field(80, ge=1, le=99)


class Popup(BaseModel):
    show: bool
    title: str = ""
    message: str = ""


class LimitStatus(BaseModel):
    package_name: str
    app_name: str
    used_seconds: int
    limit_seconds: Optional[int]
    remaining_seconds: Optional[int]
    percent_used: Optional[float]
    status: Literal["no_limit", "ok", "warning", "exceeded"]
    notification: Optional[str] = None  # text for a normal notification (warning)
    popup: Popup  # centre-of-screen popup (exceeded)


# ---------------------------------------------------------------- helpers
def _day(d: Optional[date_cls]) -> str:
    return (d or date_cls.today()).isoformat()


def _fmt(seconds: int) -> str:
    h, rem = divmod(max(seconds, 0), 3600)
    m = rem // 60
    return f"{h}h {m}m" if h else f"{m}m"


def _status(package: str, day: str) -> LimitStatus:
    rec = usage.get(day, {}).get(package, {})
    used = rec.get("seconds", 0)
    lim = limits.get(package)
    name = rec.get("app_name") or (lim or {}).get("app_name") or package

    if not lim:
        return LimitStatus(
            package_name=package, app_name=name, used_seconds=used,
            limit_seconds=None, remaining_seconds=None, percent_used=None,
            status="no_limit", popup=Popup(show=False),
        )

    limit_s = lim["daily_limit_minutes"] * 60
    pct = round(used / limit_s * 100, 1)
    remaining = max(limit_s - used, 0)
    notification, popup, status = None, Popup(show=False), "ok"

    if used >= limit_s:
        status = "exceeded"
        popup = Popup(
            show=True,
            title="Time's up!",
            message=(f"You are overusing {name}. You've used it for {_fmt(used)} today "
                     f"and your limit was {_fmt(limit_s)}."),
        )
        notification = f"You've hit your daily limit for {name}."
    elif pct >= lim["warn_at_percent"]:
        status = "warning"
        notification = f"{_fmt(remaining)} left for {name} today."

    return LimitStatus(
        package_name=package, app_name=name, used_seconds=used,
        limit_seconds=limit_s, remaining_seconds=remaining, percent_used=pct,
        status=status, notification=notification, popup=popup,
    )


# ---------------------------------------------------------------- routes
@app.get("/", tags=["meta"])
def root():
    return {"app": "Learn Sphere API", "docs": "/docs"}


@app.get("/health", tags=["meta"])
def health():
    return {"status": "ok"}


# ----- usage
@app.post("/usage/log", response_model=LimitStatus, tags=["usage"])
def log_usage(body: UsageLog):
    """Add seconds of use for an app. Returns the limit status so the
    frontend can show the notification / popup straight away."""
    day = _day(body.date)
    with lock:
        rec = usage.setdefault(day, {}).setdefault(
            body.package_name, {"app_name": body.app_name, "seconds": 0})
        rec["seconds"] += body.seconds
        if body.app_name:
            rec["app_name"] = body.app_name
        return _status(body.package_name, day)


@app.put("/usage/sync", tags=["usage"])
def sync_usage(body: UsageSync):
    """Bulk SET totals (e.g. straight from Android UsageStatsManager).
    Returns statuses of every app that has a limit and is warning/exceeded."""
    day = _day(body.date)
    with lock:
        for a in body.apps:
            rec = usage.setdefault(day, {}).setdefault(
                a.package_name, {"app_name": a.app_name, "seconds": 0})
            rec["seconds"] = a.seconds
            if a.app_name:
                rec["app_name"] = a.app_name
        alerts = [s for s in (_status(p, day) for p in limits)
                  if s.status in ("warning", "exceeded")]
    return {"date": day, "synced": len(body.apps), "alerts": alerts}


@app.get("/usage/today", tags=["usage"])
def usage_today(date: Optional[date_cls] = None):
    """Per-app usage for a day (default today), most used first, with totals."""
    day = _day(date)
    with lock:
        apps = [
            {"package_name": p, "app_name": r["app_name"] or p,
             "seconds": r["seconds"], "readable": _fmt(r["seconds"]),
             "has_limit": p in limits}
            for p, r in usage.get(day, {}).items()
        ]
    apps.sort(key=lambda x: x["seconds"], reverse=True)
    total = sum(a["seconds"] for a in apps)
    return {"date": day, "total_seconds": total, "total_readable": _fmt(total), "apps": apps}


@app.get("/usage/history", tags=["usage"])
def usage_history(days: int = Query(7, ge=1, le=90)):
    """Total screen time per day, newest first (only days that have data)."""
    with lock:
        out = [{"date": d, "total_seconds": sum(r["seconds"] for r in apps.values())}
               for d, apps in usage.items()]
    out.sort(key=lambda x: x["date"], reverse=True)
    return out[:days]


@app.delete("/usage", tags=["usage"])
def clear_usage():
    with lock:
        usage.clear()
    return {"cleared": True}


# ----- limits / timers
@app.put("/limits/{package_name}", response_model=LimitStatus, tags=["limits"])
def set_limit(package_name: str, body: LimitIn):
    """Create or update the timer for an app."""
    with lock:
        limits[package_name] = {
            "app_name": body.app_name or package_name,
            "daily_limit_minutes": body.daily_limit_minutes,
            "warn_at_percent": body.warn_at_percent,
        }
        return _status(package_name, _day(None))


@app.get("/limits", tags=["limits"])
def list_limits():
    day = _day(None)
    with lock:
        return [_status(p, day) for p in limits]


@app.delete("/limits/{package_name}", tags=["limits"])
def delete_limit(package_name: str):
    with lock:
        if package_name not in limits:
            raise HTTPException(404, "No limit set for this app")
        del limits[package_name]
    return {"deleted": package_name}


@app.get("/limits/{package_name}/status", response_model=LimitStatus, tags=["limits"])
def limit_status(package_name: str):
    """Call this when an app is opened / periodically while it's in the foreground.
    If `popup.show` is true, draw the centre-screen overlay."""
    with lock:
        return _status(package_name, _day(None))


# ----- alerts
@app.get("/alerts", response_model=List[LimitStatus], tags=["alerts"])
def alerts():
    """All apps currently in warning or exceeded state (for notifications)."""
    day = _day(None)
    with lock:
        return [s for s in (_status(p, day) for p in limits)
                if s.status in ("warning", "exceeded")]
