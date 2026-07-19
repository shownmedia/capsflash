# capsflash

Flashes your Mac's caps lock LED when a Claude Code session finishes or is waiting on you, so you get a physical "look at the terminal" signal. It never changes the actual caps lock state, the light just blinks and then goes back to normal.

## Install

Unzip, then in Terminal:

```bash
cd capsflash
bash install.sh
```

The installer:

1. Compiles the tiny C binary to `~/capsflash/capsflash` (needs Xcode Command Line Tools, it tells you if they're missing)
2. Installs a `claude-notification` skill so Claude can also flash on demand ("flash the light when the build finishes")
3. Adds Stop and Notification hooks to `~/.claude/settings.json` so **every Claude Code session flashes automatically** when it finishes or needs input, nothing to remember
4. Runs a test flash

## One-time permission

macOS requires the **Input Monitoring** permission for the app your terminal runs in (Terminal, iTerm, etc). If the test flash fails, the installer opens the right settings pane, flip your terminal app on, then run `~/capsflash/capsflash` to confirm.

## Manual use

```bash
~/capsflash/capsflash            # 8 blinks, standard
~/capsflash/capsflash 20 70      # urgent strobe
~/capsflash/capsflash 2 250      # subtle pulse
```
