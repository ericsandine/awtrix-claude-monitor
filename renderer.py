#!/usr/bin/env python3
"""
AWTRIX Claude Code Session Monitor - Display Renderer

Reads session state files from ~/.claude/awtrix/sessions/ and pushes
a live dashboard to the Ulanzi TC001 via AWTRIX 3 HTTP API.

Run: python3 ~/.claude/awtrix/renderer.py
Stop: Ctrl+C or kill the process (clears display on exit)
"""

import json
import os
import signal
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:
    print("Error: 'requests' package required. Install with: pip3 install requests")
    sys.exit(1)

# --- Configuration ---

AWTRIX_DIR = Path.home() / ".claude" / "awtrix"
SESSIONS_DIR = AWTRIX_DIR / "sessions"
CONFIG_FILE = AWTRIX_DIR / "config.env"
PID_FILE = AWTRIX_DIR / "renderer.pid"


def load_config():
    config = {
        "AWTRIX_IP": os.environ.get("AWTRIX_IP", "192.168.1.100"),
        "RENDER_INTERVAL": 1,
        "STALE_TIMEOUT": 300,
        "MAX_SESSIONS": 3,
    }
    if CONFIG_FILE.exists():
        for line in CONFIG_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip().split("#")[0].strip()
                if key in config:
                    if key in ("RENDER_INTERVAL", "STALE_TIMEOUT", "MAX_SESSIONS"):
                        config[key] = int(value)
                    else:
                        config[key] = value
    # Environment overrides config file
    if os.environ.get("AWTRIX_IP"):
        config["AWTRIX_IP"] = os.environ["AWTRIX_IP"]
    return config


# --- Status Colors ---

STATUS_COLORS = {
    "active": {"bg": "#00CC00", "bg_dim": "#00CC00", "text": "#000000"},
    "waiting": {"bg": "#FF0000", "bg_dim": "#550000", "text": "#FFFFFF"},
    "idle": {"bg": "#FF8800", "bg_dim": "#FF8800", "text": "#000000"},
    "start": {"bg": "#0088FF", "bg_dim": "#0088FF", "text": "#FFFFFF"},
    "offline": {"bg": "#222222", "bg_dim": "#222222", "text": "#555555"},
}


# --- Session State ---


def read_sessions(stale_timeout):
    """Read all session state files, marking stale ones as offline."""
    sessions = []
    now = int(time.time())

    if not SESSIONS_DIR.exists():
        return sessions

    for state_file in sorted(SESSIONS_DIR.glob("*.json")):
        try:
            data = json.loads(state_file.read_text())
            age = now - data.get("ts", 0)
            if age > stale_timeout:
                data["state"] = "offline"
            sessions.append(data)
        except (json.JSONDecodeError, KeyError):
            continue

    return sessions


# --- Display Rendering ---


def build_draw_commands(sessions, max_sessions, tick):
    """Build AWTRIX draw commands for the session dashboard."""
    draw = []
    num_slots = min(len(sessions), max_sessions)

    # Always fill entire display background first (avoids leftover pixels)
    draw.append({"df": [0, 0, 32, 8, "#000000"]})

    if num_slots == 0:
        # No sessions - show dim "no sessions" indicator
        draw.append({"dt": [4, 1, "IDLE", "#333333"]})
        return draw

    # Distribute full 32px width across slots with no gaps
    # e.g. 3 slots: 11 + 11 + 10 = 32, 2 slots: 16 + 16 = 32
    slot_widths = []
    base_width = 32 // num_slots
    remainder = 32 % num_slots
    for i in range(num_slots):
        slot_widths.append(base_width + (1 if i < remainder else 0))

    x_offset = 0
    for i, session in enumerate(sessions[:max_sessions]):
        w = slot_widths[i]
        state = session.get("state", "offline")
        colors = STATUS_COLORS.get(state, STATUS_COLORS["offline"])

        # Pulse effect for "waiting" state
        if state == "waiting" and tick % 2 == 0:
            bg = colors["bg_dim"]
        else:
            bg = colors["bg"]

        text_color = colors["text"]
        name = session.get("name", "??")[:2].upper()

        # Draw filled rectangle - full height, edge to edge
        draw.append({"df": [x_offset, 0, w, 8, bg]})

        # Center the text label in the slot
        # AWTRIX default font is ~5px per char, ~7px tall
        char_width = 5
        text_width = len(name) * char_width
        text_x = x_offset + max(0, (w - text_width) // 2)
        text_y = 1  # 1px from top for vertical centering

        draw.append({"dt": [text_x, text_y, name, text_color]})

        x_offset += w

    return draw


# --- AWTRIX API ---


def awtrix_post(base_url, endpoint, payload, timeout=3):
    """POST JSON to AWTRIX API. Silently handles connection errors."""
    try:
        url = f"{base_url}{endpoint}"
        resp = requests.post(url, json=payload, timeout=timeout)
        return resp.status_code == 200
    except requests.exceptions.RequestException:
        return False


def update_display(base_url, sessions, max_sessions, tick):
    """Push full display update to AWTRIX."""
    draw_commands = build_draw_commands(sessions, max_sessions, tick)

    payload = {
        "text": " ",
        "draw": draw_commands,
        "noScroll": True,
        "lifetime": 0,
    }

    awtrix_post(base_url, "/api/custom?name=claude", payload)

    # Keep the claude app pinned as long as sessions exist
    if sessions and tick % 5 == 0:
        awtrix_post(base_url, "/api/switch", {"name": "claude"})


def clear_display(base_url):
    """Clear the claude app and indicators on exit."""
    # Remove custom app by sending empty payload
    awtrix_post(base_url, "/api/custom?name=claude", {})


# --- Main Loop ---


def write_pid_file():
    PID_FILE.write_text(str(os.getpid()))


def remove_pid_file():
    if PID_FILE.exists():
        PID_FILE.unlink(missing_ok=True)


def main():
    config = load_config()
    base_url = f"http://{config['AWTRIX_IP']}"

    print(f"AWTRIX Claude Monitor starting...")
    print(f"  AWTRIX IP:    {config['AWTRIX_IP']}")
    print(f"  Interval:     {config['RENDER_INTERVAL']}s")
    print(f"  Stale after:  {config['STALE_TIMEOUT']}s")
    print(f"  Max sessions: {config['MAX_SESSIONS']}")
    print(f"  Sessions dir: {SESSIONS_DIR}")
    print(f"  PID file:     {PID_FILE}")
    print()

    write_pid_file()

    # Graceful shutdown
    running = True

    def handle_signal(_signum, _frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    tick = 0
    last_sessions_hash = None

    try:
        while running:
            sessions = read_sessions(config["STALE_TIMEOUT"])

            # Build a hash to detect changes (for logging)
            sessions_hash = json.dumps(
                [(s.get("name"), s.get("state")) for s in sessions], sort_keys=True
            )

            if sessions_hash != last_sessions_hash:
                states = ", ".join(
                    f"{s.get('name', '?')}={s.get('state', '?')}"
                    for s in sessions
                )
                print(f"[{time.strftime('%H:%M:%S')}] Sessions: {states or '(none)'}")
                last_sessions_hash = sessions_hash

            update_display(base_url, sessions, config["MAX_SESSIONS"], tick)

            tick += 1
            time.sleep(config["RENDER_INTERVAL"])

    finally:
        print("\nShutting down, clearing display...")
        clear_display(base_url)
        remove_pid_file()
        print("Done.")


if __name__ == "__main__":
    main()
