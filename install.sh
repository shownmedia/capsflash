#!/bin/bash
# capsflash installer: builds the binaries, installs the claude-notification skill,
# and wires Claude Code Stop/Notification hooks so the caps lock LED flashes
# whenever a Claude session finishes or needs attention.
#
# One-liner (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/shownmedia/capsflash/main/install.sh | bash
#
# Safe to re-run: it replaces any older capsflash hooks instead of skipping them.
set -euo pipefail

DEST="$HOME/capsflash"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. A popup is opening now: click Install,"
  echo "wait for it to finish, then run this same command again."
  xcode-select --install >/dev/null 2>&1 || true
  exit 1
fi

# Piped through curl: no source files next to us, so fetch them.
if [ -z "$SRC_DIR" ] || [ ! -f "$SRC_DIR/capsflash.c" ]; then
  SRC_DIR="$(mktemp -d)/capsflash-main"
  curl -fsSL https://github.com/shownmedia/capsflash/archive/refs/heads/main.tar.gz \
    | tar -xz -C "$(dirname "$SRC_DIR")"
fi

mkdir -p "$DEST"
if [ "$SRC_DIR" != "$DEST" ]; then
  cp "$SRC_DIR/capsflash.c" "$SRC_DIR/kbflash.m" "$SRC_DIR/flash-until-seen" "$DEST/"
fi
chmod +x "$DEST/flash-until-seen"
clang -O2 -o "$DEST/capsflash" "$DEST/capsflash.c" -framework IOKit -framework CoreFoundation
clang -O2 -fobjc-arc -o "$DEST/kbflash" "$DEST/kbflash.m" -framework Foundation
echo "built $DEST/capsflash"

mkdir -p "$HOME/.claude/skills/claude-notification"
sed "s|__CAPSFLASH_HOME__|$HOME|g" "$SRC_DIR/skill/SKILL.md" > "$HOME/.claude/skills/claude-notification/SKILL.md"
echo "installed skill: claude-notification"

SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
[ -s "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-capsflash"
python3 - "$SETTINGS" "$DEST/flash-until-seen 600 2>/dev/null || true" <<'PY'
import json, sys
path, cmd = sys.argv[1], sys.argv[2]
with open(path) as f:
    settings = json.load(f)
hooks = settings.setdefault("hooks", {})
for event in ("Stop", "Notification"):
    # Drop any older capsflash hooks (stale paths, old commands), keep everything else.
    kept = []
    for group in hooks.get(event, []):
        group["hooks"] = [h for h in group.get("hooks", []) if "capsflash" not in h.get("command", "")]
        if group["hooks"]:
            kept.append(group)
    kept.append({"hooks": [{"type": "command", "command": cmd, "async": True}]})
    hooks[event] = kept
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
PY
echo "hooked Stop + Notification in $SETTINGS (backup: $SETTINGS.bak-capsflash)"

echo
echo "Testing flash..."
if "$DEST/capsflash" 6 120; then
  echo "Done! Your caps lock light should have just blinked."
  echo "Start a NEW Claude Code session (type /exit, then run claude again) and it will"
  echo "flash every time Claude finishes or needs you."
else
  echo "Almost there. macOS needs one permission (Input Monitoring) for the app you run"
  echo "Claude Code in. A settings window is opening now:"
  echo "  1. Turn ON the switch next to your app (Terminal, iTerm, Warp, Cursor, VS Code...)."
  echo "     Not listed? Click +, open Applications, pick it."
  echo "  2. Fully quit that app with Cmd+Q and open it again."
  echo "  3. Test with: $DEST/capsflash"
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
fi
