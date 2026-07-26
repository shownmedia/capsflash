---
name: claude-notification
description: Flash the Mac's caps lock LED to get Mitchell's physical attention, without changing caps lock state. Use when asked to "flash the light", "notify me", "get my attention", "ping me when done", or after finishing a long-running task Mitchell asked to be alerted about. Purely visual, no sound, no notification center.
---

# Claude Notification (caps lock LED flash)

Flash the caps lock LED as a physical "look at the terminal" signal. The real caps lock state is never changed; on exit the LED is restored to the true modifier state.

## Usage

```bash
/Users/mitchell/capsflash/capsflash [blinks] [period_ms]   # green caps lock LED blink — PRIMARY
```

- No args → 8 blinks at 120ms half-period (standard "done, look here").
- `blinks`: number of on/off cycles; `period_ms`: half-period in ms (min 20).

(`kbflash`/`kbset`, the white keyboard-backlight variants, are retired — kbflash reported success while corebrightnessd silently suppressed the light, so flashes went missing. Mitchell moved back to caps lock 2026-07-26. The binaries remain in the repo but nothing should call them.)

## Patterns

| Intent | Command |
|---|---|
| Standard "done, look here" | `capsflash` (8 blinks) |
| Urgent strobe | `capsflash 20 70` |
| Subtle pulse | `capsflash 2 250` |

For "ping me when X finishes", chain it after the long command:

```bash
long_command; /Users/mitchell/capsflash/capsflash
```

Run flashes in the background (`&` or `run_in_background`) if the flash shouldn't block further work.

## Flash until seen

```bash
/Users/mitchell/capsflash/flash-until-seen [max_seconds]   # default 600
```

Keeps blinking the caps lock LED in short bursts until the terminal app that launched it becomes the frontmost app (Mitchell switched back to check it), then stops immediately. Detaches itself, so it never blocks; a lockfile at `/tmp/capsflash-until-seen.pid` prevents stacked flashers from concurrent sessions. Use this for "keep flashing until I look" requests.

## Notes and troubleshooting

- Automatic flash-until-seen when a session finishes or is blocked waiting on input is already wired via Stop/Notification hooks in `~/.claude/settings.json` — only invoke this skill for extra, manual, or custom-pattern flashes.
- `capsflash` exiting with `device open failed (0xe00002e2)` means the hosting terminal app lacks **Input Monitoring** permission: `open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"` and have Mitchell enable that app, then quit and reopen it. The grant is per-app and can be reset by OS updates.
- Rebuild after editing sources: `clang -O2 -o /Users/mitchell/capsflash/capsflash /Users/mitchell/capsflash/capsflash.c -framework IOKit -framework CoreFoundation`
- LED colors are fixed in hardware: caps lock is green-only, no RGB anywhere on this MacBook Pro. The camera's green LED cannot be used either — it's hardwired to camera sensor power.
