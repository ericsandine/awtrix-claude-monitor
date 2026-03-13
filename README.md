# AWTRIX Claude Code Monitor

Display your [Claude Code](https://claude.ai/code) session statuses on a [Ulanzi TC001](https://www.ulanzi.com/products/ulanzi-smart-pixel-clock-2882) LED matrix running [AWTRIX 3](https://blueforcer.github.io/awtrix3/) firmware.

See at a glance which sessions are actively working, waiting for your input, or idle.

![Display Layout](docs/layout.png)

## How It Works

```
Claude Code sessions  →  hooks  →  state files  →  renderer  →  AWTRIX display
```

1. **Claude Code hooks** fire on session events (tool use, completion, idle, start, end)
2. **`hook.sh`** writes a small JSON state file per session to `~/.claude/awtrix/sessions/`
3. **`renderer.py`** polls those files every second and pushes draw commands to AWTRIX
4. The **Ulanzi display** shows full-screen colored blocks with 2-character session labels

The renderer auto-starts on your first Claude Code session. No manual setup needed after install.

## Display

The 32x8 pixel display fills edge-to-edge, dividing evenly across active sessions:

| Sessions | Layout |
|----------|--------|
| 1 | `[████████████ BA ████████████]` |
| 2 | `[██████ BA ██████][██████ FR ██████]` |
| 3 | `[████ BA ████][████ FR ████][████ CA ████]` |

### Status Colors

| Color | State | Meaning |
|-------|-------|---------|
| 🟢 Green | `active` | Claude is using tools / working |
| 🔴 Red (pulsing) | `waiting` | Claude finished — waiting for your input |
| 🟠 Amber | `idle` | Session has been waiting a while |
| 🔵 Blue | `starting` | Session just launched |
| ⚫ Dark gray | `offline` | Session ended or stale (>5 min) |

The 3 AWTRIX indicator LEDs (corner pixels) also mirror the first 3 sessions for at-a-glance status.

### Session Naming

Labels are auto-detected from the working directory:

| Directory | Label |
|-----------|-------|
| `~/project/Cambly-Backend` | **BA** |
| `~/project/Cambly-Frontend` | **FR** |
| `~/myapp` | **MY** |

Override with an env var: `AWTRIX_SESSION=BE claude`

## Requirements

- **Ulanzi TC001** (or compatible) running [AWTRIX 3](https://blueforcer.github.io/awtrix3/) firmware
- **Claude Code** CLI
- **Python 3.8+** (for the renderer)
- **jq** (for the hook script)
- macOS or Linux

## Install

```bash
git clone https://github.com/YOUR_USERNAME/awtrix-claude-monitor.git
cd awtrix-claude-monitor
./install.sh
```

Then edit `~/.claude/awtrix/config.env` and set your Ulanzi's IP:

```bash
AWTRIX_IP=192.168.1.26
```

That's it. Next time you launch `claude`, the display will light up.

## What `install.sh` Does

1. Creates `~/.claude/awtrix/` with `sessions/` and `icons/` subdirectories
2. Symlinks `hook.sh`, `renderer.py`, `launch-session.sh`, `stop-renderer.sh` from the repo
3. Creates a Python venv and installs `requests`
4. Merges Claude Code hooks into `~/.claude/settings.json`
5. Copies the Claude icon GIF

## Uninstall

```bash
./uninstall.sh
```

Removes hooks from `settings.json` and optionally deletes `~/.claude/awtrix/`.

## Configuration

Edit `~/.claude/awtrix/config.env`:

```bash
AWTRIX_IP=192.168.1.26    # Your Ulanzi's IP address
RENDER_INTERVAL=1          # Seconds between display updates
STALE_TIMEOUT=300          # Seconds before a session is marked offline
MAX_SESSIONS=3             # Max sessions shown (display auto-adjusts width)
```

Environment variables override config file values (e.g., `AWTRIX_IP=10.0.0.5 renderer.py`).

## Manual Usage

```bash
# Start renderer manually (auto-starts with Claude Code by default)
~/.claude/awtrix/.venv/bin/python3 ~/.claude/awtrix/renderer.py

# Stop renderer
~/.claude/awtrix/stop-renderer.sh

# View renderer logs
tail -f ~/.claude/awtrix/renderer.log

# Launch Claude Code in a named tmux window (optional helper)
~/.claude/awtrix/launch-session.sh BE ~/my-project
```

## File Structure

```
~/.claude/awtrix/           # Install directory
├── .venv/                  # Python venv (requests)
├── config.env              # Your configuration (not in repo)
├── hook.sh        → repo   # Claude Code hook script
├── renderer.py    → repo   # Display daemon
├── launch-session.sh → repo
├── stop-renderer.sh   → repo
├── icons/
│   └── claude.gif          # 8x8 icon for AWTRIX app
└── sessions/               # Auto-managed state files
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Hooks not firing | Restart Claude Code (hooks load at startup) |
| Display shows clock | Renderer may not be running: `tail ~/.claude/awtrix/renderer.log` |
| Can't connect to AWTRIX | Verify IP: `curl http://YOUR_IP/api/stats` |
| Wrong session label | Set `AWTRIX_SESSION=XX` before launching claude |

## License

MIT
