#!/bin/bash
# Install AWTRIX Claude Code Monitor
# Creates ~/.claude/awtrix/ with symlinks to repo files, sets up venv, and adds hooks.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${HOME}/.claude/awtrix"
SETTINGS_FILE="${HOME}/.claude/settings.json"

echo "AWTRIX Claude Code Monitor - Install"
echo "====================================="
echo "Repo:    $REPO_DIR"
echo "Install: $INSTALL_DIR"
echo ""

# --- Create directory structure ---
mkdir -p "$INSTALL_DIR/sessions" "$INSTALL_DIR/icons"

# --- Symlink scripts from repo ---
for file in hook.sh renderer.py launch-session.sh stop-renderer.sh; do
    if [ -L "$INSTALL_DIR/$file" ]; then
        rm "$INSTALL_DIR/$file"
    elif [ -f "$INSTALL_DIR/$file" ]; then
        echo "Backing up existing $file → ${file}.bak"
        mv "$INSTALL_DIR/$file" "$INSTALL_DIR/${file}.bak"
    fi
    ln -s "$REPO_DIR/$file" "$INSTALL_DIR/$file"
    echo "  Linked $file"
done

# --- Copy icon (not symlinked, needs to be uploaded to AWTRIX) ---
cp "$REPO_DIR/icons/claude.gif" "$INSTALL_DIR/icons/claude.gif"
echo "  Copied claude.gif icon"

# --- Create config.env if it doesn't exist ---
if [ ! -f "$INSTALL_DIR/config.env" ]; then
    cp "$REPO_DIR/config.env.example" "$INSTALL_DIR/config.env"
    echo "  Created config.env (edit AWTRIX_IP!)"
else
    echo "  config.env already exists (skipping)"
fi

# --- Create Python venv ---
if [ ! -d "$INSTALL_DIR/.venv" ]; then
    echo ""
    echo "Creating Python venv..."
    python3 -m venv "$INSTALL_DIR/.venv"
    "$INSTALL_DIR/.venv/bin/pip" install --quiet requests iterm2
    echo "  Installed Python dependencies"
else
    # Ensure iterm2 package is installed in existing venv
    "$INSTALL_DIR/.venv/bin/pip" install --quiet iterm2 2>/dev/null
    echo "  Python venv already exists (ensuring iterm2 package installed)"
fi

# --- Add hooks to settings.json ---
echo ""
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Warning: $SETTINGS_FILE not found. Create it or add hooks manually."
    echo "See hooks.json in the repo for the required configuration."
else
    if grep -q "awtrix/hook.sh" "$SETTINGS_FILE" 2>/dev/null; then
        echo "Hooks already configured in settings.json (skipping)"
    else
        echo "Adding hooks to $SETTINGS_FILE..."

        # Use python to safely merge hooks into existing settings
        "$INSTALL_DIR/.venv/bin/python3" << 'PYEOF'
import json
from pathlib import Path

settings_path = Path.home() / ".claude" / "settings.json"
settings = json.loads(settings_path.read_text())

hooks = {
    "PreToolUse": [{"hooks": [{"type": "command", "command": "~/.claude/awtrix/hook.sh active", "async": True}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "~/.claude/awtrix/hook.sh waiting", "async": True}]}],
    "Notification": [
        {"matcher": "idle_prompt", "hooks": [{"type": "command", "command": "~/.claude/awtrix/hook.sh idle", "async": True}]},
        {"matcher": "permission_prompt", "hooks": [{"type": "command", "command": "~/.claude/awtrix/hook.sh waiting", "async": True}]},
    ],
    "SessionStart": [{"hooks": [{"type": "command", "command": "~/.claude/awtrix/hook.sh start", "async": True}]}],
    "SessionEnd": [{"hooks": [{"type": "command", "command": "~/.claude/awtrix/hook.sh end", "async": True}]}],
}

existing_hooks = settings.get("hooks", {})
for key, value in hooks.items():
    if key in existing_hooks:
        existing_hooks[key].extend(value)
    else:
        existing_hooks[key] = value
settings["hooks"] = existing_hooks

settings_path.write_text(json.dumps(settings, indent=2) + "\n")
print("  Hooks added successfully")
PYEOF
    fi
fi

# --- Add cc() shell function ---
echo ""
ZSHRC="${HOME}/.zshrc"
if [ -f "$ZSHRC" ]; then
    if grep -q "awtrix-claude-monitor/cc.sh" "$ZSHRC" 2>/dev/null; then
        echo "cc() function already sourced in .zshrc (skipping)"
    else
        echo "" >> "$ZSHRC"
        echo "# AWTRIX Claude Code session launcher (tab titles + Ulanzi display)" >> "$ZSHRC"
        echo "source ${REPO_DIR}/cc.sh" >> "$ZSHRC"
        echo "  Added cc() function to .zshrc"
    fi
else
    echo "Warning: ~/.zshrc not found. Add this to your shell config manually:"
    echo "  source ${REPO_DIR}/cc.sh"
fi

echo ""
echo "Install complete!"
echo ""
echo "Next steps:"
echo "  1. Edit ~/.claude/awtrix/config.env and set AWTRIX_IP to your Ulanzi's IP"
echo "  2. In iTerm2: Settings > General > Magic > Enable Python API"
echo "  3. Reload your shell: source ~/.zshrc"
echo "  4. Launch sessions with: cc BA backend"
echo ""
echo "Usage:"
echo "  cc BA backend        # Tab title 'BA', runs: cambly claude backend"
echo "  cc FE frontend       # Tab title 'FE', runs: cambly claude frontend"
echo "  cc CA                # Tab title 'CA', runs: cambly claude (root)"
echo "  cc MY ~/my-project   # Tab title 'MY', runs: claude in that directory"
echo ""
echo "  Stop renderer: ~/.claude/awtrix/stop-renderer.sh"
echo "  View logs:     tail -f ~/.claude/awtrix/renderer.log"
