# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A Garmin Connect IQ widget (written in Monkey C) that counts down to the end of the school year. The widget runs on Garmin watches (fr165m, fr255s, fr265, fr645m, vivoactive4s, and others listed in `manifest.xml`).

## Build and run

This project uses the **Monkey C extension for VS Code**. There is no CLI build command — all compilation and simulation is done through VS Code:

- **Build & run**: Use the VS Code command palette → `Monkey C: Run No Tests` or press F5 with a launch configuration selected.
- **Launch configs** (`.vscode/launch.json`): "Run on fr265" targets the fr265 simulator; "Run (choose device)" prompts for any device.
- **Simulator**: The Garmin Connect IQ SDK simulator opens automatically when you launch from VS Code.
- **Build output**: `bin/endyearcooldowngarmin.prg` and `bin/gen/` (generated resources).

## Architecture

The widget has five Monkey C source files:

- `source/EndyearcooldownApp.mc` — `AppBase` subclass; entry point. Reads the `cooldownSeed` property, parses it, and routes to `NoSeedView` (seed missing/invalid) or the main view/input pair.
- `source/CooldownConfig.mc` — parses the seed string produced by `web/index.html` into a plain config object; no other source of configuration exists.
- `source/EndyearcooldownView.mc` — all rendering and time logic (`WatchUi.View` subclass), driven entirely by the `CooldownConfig` passed into its constructor.
- `source/EndyearcooldownDelegate.mc` — input handling (START, NEXT/PREV, tap) forwarded to the view (`WatchUi.BehaviorDelegate` subclass).
- `source/NoSeedView.mc` — shown when no seed is configured: a QR code + link to the web setup tool, with a best-effort `Communications.openWebPage()` on show.

### Screen states

`EndyearcooldownView` manages two screens toggled by `_screen`:

- `SCREEN_YEAR` (0): wall-clock countdown to school-year end; fireworks animation + 10-second dramatic countdown at the boundary.
- `SCREEN_TODAY` (1): net school hours remaining (sum of enabled school days × their configured end times, ticking in real time).

Switching is blocked on the last school day and during summer break (`isLockedToSingleScreen()`).

During summer break both screens collapse to a single vacation countdown showing days until `nextYearStartDate`, with a summer-progress ring.

### Timer

A `Timer.Timer` fires `onTick()` which calls `WatchUi.requestUpdate()`. The period switches between `TIMER_SLOW` (1 s) and `TIMER_FAST` (100 ms) to drive fireworks and the rainbow accent color. The desired period is set in `onUpdate()` via `_wantFast` and reconciled on the next tick.

### Time handling

`momentAt()` corrects for the Garmin SDK quirk where `Gregorian.moment()` interprets values as UTC rather than local time — it subtracts `System.getClockTime().timeZoneOffset` to produce the correct local moment.

### Configuration (seed-based, no native settings UI)

All configuration comes from a single string property, `cooldownSeed` (defined in `resources/properties/properties.xml`, exposed as one `alphaNumeric` setting in `resources/settings/settings.xml`). There are no other properties — every schedule detail lives inside the seed string.

The seed is produced and edited by the static web tool at `web/index.html` (deployed to GitHub Pages via `.github/workflows/deploy-pages.yml` on push to `web/**`), then pasted by the user into the widget's Garmin Connect settings. `source/CooldownConfig.mc::parse()` decodes it on the watch:

```
1|E=<b36 epoch>|N=<b36 epoch>|W=<decimal bitmask, bit0=Sun..bit6=Sat>|T=<b36 endMinutes Sun,Mon,...,Sat>|C=<decimal 0-7>|S=<b36 startMinutes>
```

| Field | Meaning |
|---|---|
| `E` | Official last day of school (UTC-midnight epoch seconds, base36) |
| `N` | First day of next school year (UTC-midnight epoch seconds, base36) |
| `W` | Bitmask of enabled weekdays, bit 0 = Sunday .. bit 6 = Saturday |
| `T` | Seven base36 end-of-school-day minute values, Sunday..Saturday, comma-separated |
| `C` | Ring color, 0=Blue … 7=Rainbow |
| `S` | School start time (minutes since midnight, base36), applied every enabled day |

If the property is empty or fails to parse, `EndyearcooldownApp` shows `NoSeedView` (QR code + link to the web tool) instead of the countdown.

### Debug time override

`EndyearcooldownView` has a `DEBUG_ENABLED` constant (default `false`). Set it to `true` to shift the simulated clock to a fixed moment (currently June 30 13:59). **Must be `false` before releasing.**
