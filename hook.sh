#!/bin/bash
# Claude Code hook → AWTRIX session state writer
# Usage: hook.sh <state>
# States: active, waiting, idle, start, end
# Receives hook JSON on stdin, writes state file for renderer.py

set -euo pipefail

STATE="${1:-unknown}"
AWTRIX_DIR="${HOME}/.claude/awtrix"
SESSIONS_DIR="${AWTRIX_DIR}/sessions"
PID_FILE="${AWTRIX_DIR}/renderer.pid"
RENDERER="${AWTRIX_DIR}/.venv/bin/python3 ${AWTRIX_DIR}/renderer.py"

# Read all hook JSON from stdin (timeout after 2 seconds)
INPUT=$(timeout 2 cat 2>/dev/null || true)

# Extract fields from hook JSON
SESSION_ID=""
CWD=""
if [ -n "$INPUT" ]; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
fi

# Determine session name (priority order):
# 1. AWTRIX_SESSION env var (explicit override)
# 2. Auto-detect from cwd (working directory from hook payload)
# 3. tmux window name
# 4. First 6 chars of session_id
SESSION_NAME="${AWTRIX_SESSION:-}"

if [ -z "$SESSION_NAME" ] && [ -n "$CWD" ]; then
    # Auto-detect from working directory basename
    DIR_NAME=$(basename "$CWD")
    # Strip "Cambly-" prefix for cambly repos, then take first 2 chars
    SHORT="${DIR_NAME#Cambly-}"
    SHORT="${SHORT#cambly-}"
    SESSION_NAME=$(echo "${SHORT:0:2}" | tr '[:lower:]' '[:upper:]')
fi

if [ -z "$SESSION_NAME" ]; then
    SESSION_NAME=$(tmux display-message -p '#{window_name}' 2>/dev/null | head -c 3 || true)
fi

if [ -z "$SESSION_NAME" ]; then
    SESSION_NAME="${SESSION_ID:0:6}"
fi

if [ -z "$SESSION_NAME" ]; then
    exit 0  # Can't identify session, skip silently
fi

# Ensure sessions directory exists
mkdir -p "$SESSIONS_DIR"

# Auto-start renderer if not running
if [ "$STATE" = "start" ] || [ "$STATE" = "active" ]; then
    RENDERER_RUNNING=false
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        RENDERER_RUNNING=true
    fi
    if [ "$RENDERER_RUNNING" = false ]; then
        nohup $RENDERER >> "${AWTRIX_DIR}/renderer.log" 2>&1 &
    fi
fi

STATE_FILE="${SESSIONS_DIR}/${SESSION_NAME}.json"

if [ "$STATE" = "end" ]; then
    # Remove state file on session end
    rm -f "$STATE_FILE"
else
    # Write state file atomically (write to tmp, then move)
    TMP_FILE="${STATE_FILE}.tmp"
    cat > "$TMP_FILE" <<EOF
{"name":"${SESSION_NAME}","state":"${STATE}","session_id":"${SESSION_ID}","ts":$(date +%s)}
EOF
    mv "$TMP_FILE" "$STATE_FILE"
fi

exit 0
