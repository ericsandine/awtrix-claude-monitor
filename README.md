# AWTRIX Claude Code Monitor

Display your [Claude Code](https://claude.ai/code) session statuses on a [Ulanzi TC001](https://www.ulanzi.com/products/ulanzi-smart-pixel-clock-2882) LED matrix running [AWTRIX 3](https://blueforcer.github.io/awtrix3/) firmware, with matching labeled + color-coded iTerm2 tabs.

See at a glance which sessions are actively working, waiting for your input, or idle.

## How It Works

```
cc backend  →  locks iTerm2 tab title "BA" + colors the tab
             →  sets AWTRIX_SESSION=BA
             →  launches: cambly claude backend
                              ↓
             Claude Code hooks fire on events
                              ↓
             hook.sh writes state file
                              ↓
             renderer.py pushes to AWTRIX display
```

1. **`cc` command** launches Claude Code with a locked, color-coded iTerm2 tab
2. **Claude Code hooks** fire on session events (tool use, completion, idle)
3. **`hook.sh`** writes a JSON state file per session
4. **`renderer.py`** polls those files every second and pushes draw commands to AWTRIX
5. The **Ulanzi display** shows full-screen colored blocks with 2-character session labels

The renderer auto-starts on your first session. No manual setup needed after install.

## Usage

```bash
cc                   # Auto-detect label from cwd, runs: cambly claude
cc backend           # Tab "BA" (blue), runs: cambly claude backend
cc frontend          # Tab "FR" (purple), runs: cambly claude frontend
cc BA backend        # Explicit label, runs: cambly claude backend
cc ~/my-project      # Tab "MY", runs: claude in that directory
```

Each session gets:
- **iTerm2 tab title** — locked 2-char label that Claude Code can't overwrite
- **iTerm2 tab color** — unique color per session for visual distinction
- **Ulanzi display** — colored block showing session status (green/red/amber)

Labels auto-detect from known targets (`backend` → BA, `frontend` → FR) or from the directory name. You can always pass an explicit label as the first argument.

## Display

The 32x8 pixel display fills edge-to-edge, dividing evenly across active sessions:

| Sessions | Layout |
|----------|--------|
| 1 | `[████████████ BA ████████████]` |
| 2 | `[██████ BA ██████][██████ FR ██████]` |
| 3 | `[████ BA ████][████ FR ████][████ CA ████]` |

### Status Colors (Ulanzi)

| Color | State | Meaning |
|-------|-------|---------|
| Green | `active` | Claude is using tools / working |
| Red (pulsing) | `waiting` | Claude finished — waiting for your input |
| Amber | `idle` | Session has been waiting a while |
| Blue | `starting` | Session just launched |
| Dark gray | `offline` | Session ended or stale (>5 min) |

### Tab Colors (iTerm2)

Each label gets a consistent color from a 6-color palette so you can visually distinguish sessions in your tab bar.

## Requirements

- **Ulanzi TC001** (or compatible) running [AWTRIX 3](https://blueforcer.github.io/awtrix3/) firmware
- **Claude Code** CLI
- **iTerm2** with Python API enabled (Settings > General > Magic > Enable Python API)
- **Python 3.8+**
- **jq**
- macOS or Linux

## Install

```bash
git clone https://github.com/YOUR_USERNAME/awtrix-claude-monitor.git
cd awtrix-claude-monitor
./install.sh
```

Then:

1. Edit `~/.claude/awtrix/config.env` and set `AWTRIX_IP` to your Ulanzi's IP
2. In iTerm2: **Settings > General > Magic > Enable Python API**
3. Reload your shell: `source ~/.zshrc`
4. Launch a session: `cc backend`

## What `install.sh` Does

1. Creates `~/.claude/awtrix/` with `sessions/` and `icons/` subdirectories
2. Symlinks `hook.sh`, `renderer.py`, helper scripts from the repo
3. Creates a Python venv and installs `requests` + `iterm2`
4. Merges Claude Code hooks into `~/.claude/settings.json`
5. Adds the `cc` function to `~/.zshrc`
6. Copies the Claude icon GIF

## Uninstall

```bash
./uninstall.sh
```

Removes hooks from `settings.json` and optionally deletes `~/.claude/awtrix/`. You'll want to manually remove the `source .../cc.sh` line from `~/.zshrc`.

## Configuration

Edit `~/.claude/awtrix/config.env`:

```bash
AWTRIX_IP=192.168.1.26    # Your Ulanzi's IP address
RENDER_INTERVAL=1          # Seconds between display updates
STALE_TIMEOUT=300          # Seconds before a session is marked offline
MAX_SESSIONS=3             # Max sessions shown (display auto-adjusts width)
```

Environment variables override config file values (e.g., `AWTRIX_IP=10.0.0.5 renderer.py`).

## Session Naming

Labels are auto-detected from known targets or directory names:

| Input | Label | How |
|-------|-------|-----|
| `cc backend` | **BA** | Known target mapping |
| `cc frontend` | **FR** | Known target mapping |
| `cc` (from ~/cambly) | **CA** | First 2 chars of dir |
| `cc ~/myapp` | **MY** | First 2 chars of dir |
| `cc XY backend` | **XY** | Explicit label |

The `Cambly-` prefix is stripped automatically.

## How It Works (Details)

### Hooks (in `~/.claude/settings.json`)

All hooks run with `async: true` so they never block Claude:

- **PreToolUse** → `hook.sh active` (Claude is using tools)
- **Stop** → `hook.sh waiting` (Claude finished responding)
- **Notification (idle_prompt)** → `hook.sh idle` (been waiting a while)
- **SessionStart** → `hook.sh start` (new session, auto-starts renderer)
- **SessionEnd** → `hook.sh end` (removes state file)

### Hook Script (`hook.sh`)

1. Reads JSON from stdin (Claude Code hook payload with `session_id` and `cwd`)
2. Gets session name from `$AWTRIX_SESSION` env var or auto-detects from `cwd`
3. Writes `~/.claude/awtrix/sessions/<NAME>.json` atomically
4. Auto-starts the renderer if it's not already running

### Renderer (`renderer.py`)

Runs as a background process, auto-started by the first hook:
1. Reads all `*.json` state files from `sessions/`
2. Marks sessions older than `STALE_TIMEOUT` as `offline`
3. Builds AWTRIX draw commands (full-width colored blocks with 2-char labels)
4. POSTs to AWTRIX `/api/custom?name=claude`
5. Pins the claude app to the display
6. Sleeps 1 second, repeats
7. On SIGTERM/SIGINT: clears display and exits cleanly

## Manual Usage

```bash
# Start renderer manually
~/.claude/awtrix/.venv/bin/python3 ~/.claude/awtrix/renderer.py

# Stop renderer
~/.claude/awtrix/stop-renderer.sh

# View renderer logs
tail -f ~/.claude/awtrix/renderer.log
```

## File Structure

```
awtrix-claude-monitor/          # Git repo
├── cc.sh                       # Shell function (sourced in ~/.zshrc)
├── iterm2-set-title.py         # iTerm2 Python API title locker
├── hook.sh                     # Claude Code hook script
├── renderer.py                 # Display renderer daemon
├── launch-session.sh           # tmux launcher (optional)
├── stop-renderer.sh            # Stop the renderer
├── install.sh / uninstall.sh   # Setup scripts
├── config.env.example          # Config template
├── hooks.json                  # Hook config reference
└── icons/
    └── claude.gif              # 8x8 Claude sparkle icon

~/.claude/awtrix/               # Install directory
├── .venv/                      # Python venv (requests, iterm2)
├── config.env                  # Your config (not in repo)
├── hook.sh         → repo
├── renderer.py     → repo
├── sessions/                   # Auto-managed state files
└── icons/
    └── claude.gif
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Hooks not firing | Restart Claude Code (hooks load at startup) |
| Display shows clock | Renderer may not be running: `tail ~/.claude/awtrix/renderer.log` |
| Can't connect to AWTRIX | Verify IP: `curl http://YOUR_IP/api/stats` |
| Tab title gets overwritten | Enable iTerm2 Python API: Settings > General > Magic > Enable Python API |
| `cc` command not found | Run: `source ~/.zshrc` |
| Wrong session label | Pass explicit label: `cc MY backend` |

## License

MIT
