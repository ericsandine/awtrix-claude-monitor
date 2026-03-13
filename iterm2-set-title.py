#!/usr/bin/env python3
"""Set iTerm2 session name and lock it so child processes can't overwrite it.

Usage: iterm2-set-title.py <TITLE>

Requires: pip install iterm2
Requires: iTerm2 > Settings > General > Magic > Enable Python API (checked)
"""

import sys

import iterm2


async def main(connection):
    title = sys.argv[1] if len(sys.argv) > 1 else "CC"

    app = await iterm2.async_get_app(connection)
    window = app.current_terminal_window
    if not window:
        print("Error: No iTerm2 window found", file=sys.stderr)
        return

    session = window.current_tab.current_session

    update = iterm2.LocalWriteOnlyProfile()
    update.set_allow_title_setting(False)
    update.set_name(title)
    await session.async_set_profile_properties(update)


iterm2.run_until_complete(main)
