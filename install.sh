#!/bin/bash
# capsflash installer: builds the binary, installs the claude-notification skill,
# and wires Claude Code Stop/Notification hooks so the caps lock LED flashes
# whenever a Claude session finishes or needs attention.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/capsflash"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools required. Run: xcode-select --install (then re-run this)"
  exit 1
fi

mkdir -p "$DEST"
cp "$SRC_DIR/capsflash.c" "$DEST/"
clang -O2 -o "$DEST/capsflash" "$DEST/capsflash.c" -framework IOKit -framework CoreFoundation
echo "built $DEST/capsflash"

mkdir -p "$HOME/.claude/skills/claude-notification"
sed "s|__CAPSFLASH_HOME__|$HOME|g" "$SRC_DIR/skill/SKILL.md" > "$HOME/.claude/skills/claude-notification/SKILL.md"
echo "installed skill: claude-notification"

SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
if grep -q "capsflash" "$SETTINGS"; then
  echo "hooks already present in $SETTINGS, skipping"
else
  python3 - "$SETTINGS" "$DEST/capsflash 8 120 2>/dev/null || true" <<'EOF'
import json, sys
path, cmd = sys.argv[1], sys.argv[2]
with open(path) as f:
    settings = json.load(f)
entry = {"hooks": [{"type": "command", "command": cmd, "async": True}]}
hooks = settings.setdefault("hooks", {})
for event in ("Stop", "Notification"):
    hooks.setdefault(event, []).append(entry)
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
EOF
  echo "added Stop + Notification hooks to $SETTINGS"
fi

echo
echo "Testing flash..."
if "$DEST/capsflash" 3 100; then
  echo "Done! Your caps lock light should have just blinked."
else
  echo "macOS needs you to grant Input Monitoring to your terminal app."
  echo "Opening the settings pane now - enable your terminal (Terminal/iTerm/etc),"
  echo "then run: $DEST/capsflash"
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
fi
