# cc - Claude Code session launcher with persistent tab labeling + coloring
# Source this file in your ~/.zshrc:  source /path/to/awtrix-claude-monitor/cc.sh
#
# Usage:
#   cc                   # Auto-detect label from cwd, runs: cambly claude
#   cc backend           # Label "BA", runs: cambly claude backend
#   cc frontend          # Label "FR", runs: cambly claude frontend
#   cc BA backend        # Explicit label "BA", runs: cambly claude backend
#   cc ~/my-project      # Auto-label "MY", runs: claude in that directory
#
# The label is used for:
#   - iTerm2 tab title (locked — Claude Code can't overwrite it)
#   - iTerm2 tab color (unique per session)
#   - AWTRIX_SESSION env var (Ulanzi display)
#
# Requires: iTerm2 with Python API enabled (Settings > General > Magic > Enable Python API)

CC_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]:-$0}" 2>/dev/null || echo "${0:A}")")"
CC_ITERM2_SCRIPT="${CC_DIR}/iterm2-set-title.py"
CC_VENV_PYTHON="${HOME}/.claude/awtrix/.venv/bin/python3"

# Known cambly targets → auto-labels
declare -A CC_TARGET_LABELS=(
    [backend]=BA [be]=BA
    [frontend]=FR [fe]=FR
    [root]=CA [parent]=CA
)

# Tab color palette (R G B) — one per session, visually distinct
CC_TAB_COLORS=(
    "80 180 255"   # blue
    "180 130 255"  # purple
    "100 220 180"  # teal
    "255 170 80"   # orange
    "255 120 150"  # pink
    "140 220 90"   # lime
)

_cc_auto_label() {
    local dir="${1:-$PWD}"
    local name
    name=$(basename "$dir")
    name="${name#Cambly-}"
    name="${name#cambly-}"
    echo "${name:0:2}" | tr '[:lower:]' '[:upper:]'
}

_cc_set_tab_color() {
    local r g b
    # Pick color from palette based on label hash
    local idx=$(( $(printf '%d' "'${1:0:1}") % ${#CC_TAB_COLORS[@]} ))
    read -r r g b <<< "${CC_TAB_COLORS[$idx]}"
    printf "\033]6;1;bg;red;brightness;%s\a" "$r"
    printf "\033]6;1;bg;green;brightness;%s\a" "$g"
    printf "\033]6;1;bg;blue;brightness;%s\a" "$b"
}

_cc_set_title() {
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]] && [[ -f "$CC_ITERM2_SCRIPT" ]] && [[ -x "$CC_VENV_PYTHON" ]]; then
        "$CC_VENV_PYTHON" "$CC_ITERM2_SCRIPT" "$1" 2>/dev/null
    else
        printf "\033]1;%s\007" "$1"
    fi
}

cc() {
    local label=""
    local target=""

    case $# in
        0)
            # cc → auto-detect everything
            label=$(_cc_auto_label)
            ;;
        1)
            if [[ -n "${CC_TARGET_LABELS[$1]+x}" ]]; then
                # cc backend → known cambly target
                label="${CC_TARGET_LABELS[$1]}"
                target="$1"
            elif [[ -d "$1" ]]; then
                # cc ~/some-dir → directory
                label=$(_cc_auto_label "$1")
                target="$1"
            else
                # cc BA → explicit label, no target
                label="$1"
            fi
            ;;
        *)
            if [[ -n "${CC_TARGET_LABELS[$1]+x}" ]]; then
                # cc backend (extra args ignored, treat as target)
                label="${CC_TARGET_LABELS[$1]}"
                target="$1"
            elif [[ -n "${CC_TARGET_LABELS[$2]+x}" ]]; then
                # cc BA backend → explicit label + cambly target
                label="$1"
                target="$2"
            elif [[ -d "$2" ]]; then
                # cc MY ~/dir → explicit label + directory
                label="$1"
                target="$2"
            else
                label="$1"
                target="$2"
            fi
            ;;
    esac

    label=$(echo "$label" | tr '[:lower:]' '[:upper:]')

    # Set iTerm2 tab title (locked) + tab color
    _cc_set_title "$label"
    _cc_set_tab_color "$label"

    # Set AWTRIX session name for the Ulanzi display
    export AWTRIX_SESSION="$label"

    # Launch
    case "$target" in
        backend|be|frontend|fe|root|parent)
            cambly claude "$target"
            ;;
        "")
            if type cambly &>/dev/null; then
                cambly claude
            else
                claude
            fi
            ;;
        *)
            if [[ -d "$target" ]]; then
                cd "$target" && claude
            else
                echo "Error: '$target' is not a valid cambly target or directory"
                return 1
            fi
            ;;
    esac
}
