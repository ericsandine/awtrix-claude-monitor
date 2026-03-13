#!/bin/bash
# Uninstall AWTRIX Claude Code Monitor
# Removes hooks from settings.json and cleans up ~/.claude/awtrix/
set -euo pipefail

INSTALL_DIR="${HOME}/.claude/awtrix"
SETTINGS_FILE="${HOME}/.claude/settings.json"

echo "AWTRIX Claude Code Monitor - Uninstall"
echo "======================================="

# --- Stop renderer if running ---
if [ -f "$INSTALL_DIR/renderer.pid" ]; then
    PID=$(cat "$INSTALL_DIR/renderer.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping renderer (PID $PID)..."
        kill "$PID" 2>/dev/null || true
        sleep 1
    fi
fi

# --- Remove hooks from settings.json ---
if [ -f "$SETTINGS_FILE" ] && grep -q "awtrix/hook.sh" "$SETTINGS_FILE" 2>/dev/null; then
    echo "Removing hooks from settings.json..."
    VENV_PYTHON="$INSTALL_DIR/.venv/bin/python3"
    if [ -x "$VENV_PYTHON" ]; then
        "$VENV_PYTHON" << 'PYEOF'
import json
from pathlib import Path

settings_path = Path.home() / ".claude" / "settings.json"
settings = json.loads(settings_path.read_text())

if "hooks" in settings:
    for key in list(settings["hooks"].keys()):
        settings["hooks"][key] = [
            entry for entry in settings["hooks"][key]
            if not any(
                h.get("command", "").startswith("~/.claude/awtrix/")
                for h in entry.get("hooks", [])
            )
        ]
        if not settings["hooks"][key]:
            del settings["hooks"][key]
    if not settings["hooks"]:
        del settings["hooks"]

settings_path.write_text(json.dumps(settings, indent=2) + "\n")
print("  Hooks removed")
PYEOF
    else
        echo "  Warning: Python venv not found, remove hooks manually from $SETTINGS_FILE"
    fi
fi

# --- Remove install directory ---
echo ""
read -p "Remove $INSTALL_DIR? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$INSTALL_DIR"
    echo "  Removed $INSTALL_DIR"
else
    echo "  Kept $INSTALL_DIR (you can remove it manually)"
fi

echo ""
echo "Uninstall complete. Restart any running Claude Code sessions to clear hooks."
