# capsflash

Local macOS CLI tool: flashes the caps lock LED (or keyboard backlight as fallback) as a physical "look at the terminal" signal when a Claude Code session finishes or needs input. Never changes real caps lock state. No server, no deploy, no live URL — this runs entirely on the local Mac.

GitHub: `shownmedia/capsflash` (public repo, `main` branch). No CI/CD deploy step; `.github/workflows/gitleaks.yml` only runs a secret scan (gitleaks) on push/PR.

## Code map

- `capsflash.c` -> source for the `capsflash` binary. Blinks the caps lock LED via IOKit HID without toggling the actual caps lock modifier. Rebuild: `clang -O2 -o capsflash capsflash.c -framework IOKit -framework CoreFoundation`.
- `kbflash.m` -> source for the `kbflash` binary (Objective-C). Breathes the white keyboard backlight; fallback only, used when `capsflash` exits nonzero (no Input Monitoring permission). Rebuild: `clang -O2 -fobjc-arc -o kbflash kbflash.m -framework Foundation`.
- `kbset.m` / `kbset` -> related keyboard-backlight helper binary (not wired into hooks; standalone utility).
- `flash-until-seen` -> bash wrapper invoked by Claude Code's Stop/Notification hooks. Walks up the process tree to find the hosting terminal app's pid, detaches, then blinks in bursts (`8 120` initial, then `4 150` every ~2.5s) until that app is frontmost (checked via `lsappinfo front`) or `max_seconds` elapses (default 600). Falls back to `kbflash 1 2400` if `capsflash` fails. Single-instance lock at `/tmp/capsflash-until-seen.pid` so concurrent sessions don't stack flashers.
- `install.sh` -> one-shot installer: builds both binaries into `$HOME/capsflash`, installs the `claude-notification` skill into `~/.claude/skills/claude-notification/SKILL.md` (templated from `skill/SKILL.md`, substituting `__CAPSFLASH_HOME__` -> `$HOME`), and rewrites the `Stop`/`Notification` hook entries in `~/.claude/settings.json` (backs up to `settings.json.bak-capsflash` first). Idempotent: strips any prior capsflash hook commands before adding the new one.
- `skill/SKILL.md` -> template for the `claude-notification` skill (manual/on-demand flash, e.g. "flash the light when the build finishes"). Installed copy lives outside this repo at `~/.claude/skills/claude-notification/SKILL.md` — edit the template here, then re-run `install.sh` to redeploy it, don't hand-edit the installed copy.
- `README.md` -> user-facing install/usage instructions, kept in sync with `install.sh` behavior.

Where to look for X (from git log, what people actually touch):
- Changing the flash pattern/timing or hook wiring -> `install.sh` + `flash-until-seen` (wrapper-level timing) + `capsflash.c` / `kbflash.m` (hardcoded defaults: 8 blinks/120ms, 5 breaths/2400ms respectively).
- Caps-lock-vs-backlight fallback behavior -> `flash-until-seen`'s `flash()` function + memory notes below (backlight was retired as primary, kept only as fallback).
- Making the installer portable for other machines/teammates -> `install.sh` (no hardcoded `/Users/mitchell` paths; fetches via `curl`+`tar` when piped).
- Secret-scanning -> `.github/workflows/gitleaks.yml`.

## Data

None. No database, no state file beyond the transient `/tmp/capsflash-until-seen.pid` lock (pid of the running flasher, deleted on exit). No other repo owns related data.

## Commands

- Build: `clang -O2 -o capsflash capsflash.c -framework IOKit -framework CoreFoundation` and `clang -O2 -fobjc-arc -o kbflash kbflash.m -framework Foundation` (both are also done by `install.sh`). No `package.json`/build system — this is plain C/Objective-C, no npm.
- Install/reinstall (idempotent, safe to re-run): `bash install.sh` (local clone) or `curl -fsSL https://raw.githubusercontent.com/shownmedia/capsflash/main/install.sh | bash` (no clone needed).
- Manual flash: `~/capsflash/capsflash` (8 blinks default), `~/capsflash/capsflash 20 70` (urgent strobe), `~/capsflash/capsflash 2 250` (subtle pulse).
- Test the hook path directly: `~/capsflash/flash-until-seen 600`.
- No test suite, no deploy command — this never ships anywhere but the local `$HOME/capsflash` + `~/.claude/settings.json`.

## Env vars

None.

## Gotchas

- Requires macOS **Input Monitoring** permission for the hosting terminal app (Terminal, iTerm, Warp, Cursor, VS Code...) or `capsflash` exits nonzero (`device open failed (0xe00002e2)`). Per-app grant; can silently reset after OS updates. `install.sh` opens the Privacy_ListenEvent settings pane automatically if the test flash fails.
- Caps lock LED is the **primary** signal (moved back to it 2026-07-26 after trying backlight). Backlight (`kbflash`) is fallback-only: `corebrightnessd` can silently suppress keyboard backlight while the API still reports success, and it needs System Settings -> Keyboard -> "Adjust keyboard brightness in low light" OFF, plus max brightness is too dim to see in daylight. Don't "upgrade" kbflash back to primary.
- LED colors are hardware-fixed on this hardware class (caps lock green-only, backlight white-only) — no RGB control is possible.
- Hooks only load at Claude Code session start — after running `install.sh`, start a fresh session (`/exit` then `claude`) for the new hooks to take effect.
- `flash-until-seen`'s lockfile (`/tmp/capsflash-until-seen.pid`) intentionally no-ops a second flasher if one is already running — don't remove this or concurrent Claude sessions will stack blinkers.
- Rerunning `install.sh` replaces (not stacks) any prior capsflash `Stop`/`Notification` hook entries in `~/.claude/settings.json`; a single backup is written to `settings.json.bak-capsflash` and overwritten on every run (not timestamped, not cumulative — only the pre-this-run state is recoverable).
- The installed skill at `~/.claude/skills/claude-notification/SKILL.md` is generated output — the source of truth is `skill/SKILL.md` in this repo.

## Related repos

None — self-contained local tool, no cross-repo data or API dependencies.
