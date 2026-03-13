#!/bin/bash
# Stop the AWTRIX renderer daemon gracefully
set -euo pipefail

PID_FILE="${HOME}/.claude/awtrix/renderer.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping renderer (PID $PID)..."
        kill "$PID"
        # Wait up to 5 seconds for graceful shutdown
        for i in $(seq 1 10); do
            if ! kill -0 "$PID" 2>/dev/null; then
                echo "Renderer stopped."
                exit 0
            fi
            sleep 0.5
        done
        echo "Force killing..."
        kill -9 "$PID" 2>/dev/null || true
        rm -f "$PID_FILE"
        echo "Renderer killed."
    else
        echo "Renderer not running (stale PID file). Cleaning up."
        rm -f "$PID_FILE"
    fi
else
    # Try to find it by process
    PIDS=$(pgrep -f "renderer.py" 2>/dev/null || true)
    if [ -n "$PIDS" ]; then
        echo "Found renderer process(es): $PIDS"
        echo "$PIDS" | xargs kill 2>/dev/null || true
        echo "Sent SIGTERM."
    else
        echo "Renderer is not running."
    fi
fi
