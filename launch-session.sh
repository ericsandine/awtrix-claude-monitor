#!/bin/bash
# Launch a Claude Code session in a named tmux window with AWTRIX tracking
#
# Usage:
#   launch-session.sh <SESSION_NAME> <DIRECTORY> [claude args...]
#
# Examples:
#   launch-session.sh BE ~/cambly/Cambly-Backend
#   launch-session.sh FE ~/cambly/Cambly-Frontend
#   launch-session.sh FS ~/cambly --add-dir ./Cambly-Backend --add-dir ./Cambly-Frontend
#
# Sessions are created as windows in the "claude-work" tmux session.

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <SESSION_NAME> <DIRECTORY> [claude args...]"
    echo ""
    echo "Examples:"
    echo "  $0 BE ~/cambly/Cambly-Backend"
    echo "  $0 FE ~/cambly/Cambly-Frontend"
    echo "  $0 FS ~/cambly --add-dir ./Cambly-Backend --add-dir ./Cambly-Frontend"
    exit 1
fi

SESSION_NAME="$1"
DIRECTORY="$2"
shift 2
CLAUDE_ARGS="$*"

TMUX_SESSION="claude-work"

# Resolve directory
DIRECTORY=$(cd "$DIRECTORY" 2>/dev/null && pwd || echo "$DIRECTORY")

if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory '$DIRECTORY' does not exist"
    exit 1
fi

# Create tmux session if it doesn't exist
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    tmux new-session -d -s "$TMUX_SESSION" -n "$SESSION_NAME" -c "$DIRECTORY"
    tmux send-keys -t "${TMUX_SESSION}:${SESSION_NAME}" \
        "export AWTRIX_SESSION='${SESSION_NAME}' && claude ${CLAUDE_ARGS}" Enter
    echo "Created tmux session '$TMUX_SESSION' with window '$SESSION_NAME'"
else
    # Check if window already exists
    if tmux list-windows -t "$TMUX_SESSION" -F '#{window_name}' | grep -q "^${SESSION_NAME}$"; then
        echo "Window '$SESSION_NAME' already exists in session '$TMUX_SESSION'"
        echo "Attach with: tmux attach -t ${TMUX_SESSION}"
        exit 0
    fi

    # Create new window in existing session
    tmux new-window -t "$TMUX_SESSION" -n "$SESSION_NAME" -c "$DIRECTORY"
    tmux send-keys -t "${TMUX_SESSION}:${SESSION_NAME}" \
        "export AWTRIX_SESSION='${SESSION_NAME}' && claude ${CLAUDE_ARGS}" Enter
    echo "Added window '$SESSION_NAME' to session '$TMUX_SESSION'"
fi

echo ""
echo "Attach with: tmux attach -t ${TMUX_SESSION}"
echo "Or in iTerm2: tmux -CC attach -t ${TMUX_SESSION}"
