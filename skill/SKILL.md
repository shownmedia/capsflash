---
name: claude-notification
description: Flash the Mac's caps lock LED to get the user's physical attention, without changing caps lock state. Use when asked to "flash the light", "notify me", "get my attention", "ping me when done", or after finishing a long-running task the user asked to be alerted about. Purely visual, no sound, no notification center.
---

# Claude Notification (caps lock LED flash)

Flash the caps lock LED as a physical "look at the terminal" signal. The binary drives the LED directly over HID and restores the real caps lock state afterward, so typing is never affected.

Automatic flashes on every session finish are already wired via Stop/Notification hooks in `~/.claude/settings.json` — only invoke this skill for extra, manual, or custom-pattern flashes.

## Usage

```bash
__CAPSFLASH_HOME__/capsflash/capsflash [blinks] [period_ms]
```

- No args → 8 blinks at 120ms (~2 seconds), the standard attention pattern.
- `blinks`: number of on/off cycles.
- `period_ms`: half-period in ms (smaller = faster strobe, min 20).

## Patterns

| Intent | Command |
|---|---|
| Standard "done, look here" | `capsflash 8 120` |
| Urgent / hard to miss | `capsflash 20 70` |
| Subtle single pulse | `capsflash 2 250` |

For "ping me when X finishes", chain it after the long command:

```bash
long_command; __CAPSFLASH_HOME__/capsflash/capsflash 12 100
```

Run flashes in the background (`&` or `run_in_background`) if the flash shouldn't block further work.

## Notes and troubleshooting

- Exit with `device open failed (0xe00002e2)` means the hosting terminal app lacks **Input Monitoring** permission: `open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"` and enable the terminal app.
- Rebuild after editing the source: `clang -O2 -o __CAPSFLASH_HOME__/capsflash/capsflash __CAPSFLASH_HOME__/capsflash/capsflash.c -framework IOKit -framework CoreFoundation`
- The camera's green LED cannot be used for this — it's hardwired to camera sensor power.
