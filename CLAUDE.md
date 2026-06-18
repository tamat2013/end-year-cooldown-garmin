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

The widget has three Monkey C source files:

- `source/EndyearcooldownApp.mc` — `AppBase` subclass; entry point, delegates to the view/input pair.
- `source/EndyearcooldownView.mc` — all rendering and time logic (`WatchUi.View` subclass).
- `source/EndyearcooldownDelegate.mc` — input handling (START, NEXT/PREV, tap) forwarded to the view (`WatchUi.BehaviorDelegate` subclass).

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

### Settings (user-configurable via Garmin Connect)

All settings use `Application.Properties` (not the deprecated `AppBase.getProperty`). Defined in `resources/properties/properties.xml`, exposed via `resources/settings/settings.xml`:

| Property | Type | Purpose |
|---|---|---|
| `officialEndDate` | date (epoch s) | Last official school day |
| `adjoiningDaysOff` | number | Days before the official end date that are already off |
| `nextYearStartDate` | date (epoch s) | First day of the next school year |
| `{weekday}Enabled` | boolean | Whether that weekday is a school day |
| `{weekday}End` | string `HH:MM` | End-of-school-day time for that weekday |
| `accentColor` | list 0–7 | Ring color (0=Blue … 7=Rainbow) |

Saturday defaults off; all other weekdays default on. Friday defaults to 12:00 end; other days 14:00.

### Debug time override

`EndyearcooldownView` has a `DEBUG_ENABLED` constant (default `false`). Set it to `true` to shift the simulated clock to a fixed moment (currently June 30 13:59). **Must be `false` before releasing.**
