# MAUI M+ Timer

A modular Mythic+ timer addon for World of Warcraft **Retail (Midnight, 12.0.x)**, built on [Ace3](https://www.wowace.com/projects/ace3).

Everything is configurable through a single central options window (no chat-based config), and every module can be enabled or disabled independently.

## Preview

<p align="center">
  <img src="preview/preview%20%281%29.png" alt="MAUI M+ Timer HUD" width="30%">
  <img src="preview/preview%20%282%29.png" alt="MAUI M+ Timer HUD, alternate theme" width="30%">
  <img src="preview/preview%20%283%29.png" alt="MAUI M+ Timer HUD, alternate theme" width="30%">
</p>

## Features

- **Dungeon** — current dungeon name, key level and affixes, with an optional (border-trimmed) dungeon icon.
- **Timer** — key timer with time-limit thresholds (+1/+2/+3) and an optional three-segment split bar, driven by the run controller so it keeps working even if other modules are disabled.
- **Enemy Forces** — aggregate (dungeon-total) forces progress with percentage and remaining count. Optional checkpoint markers on the bar, or a split bar that breaks into one segment per checkpoint with a per-segment "% still needed" countdown. Shows the completion time and the delta versus your best run. (Per-mob pull previews are not possible under Midnight's restricted unit IDs.)
- **Objectives** — boss checklist from the scenario criteria, with kill times and best-run deltas.
- **Deaths** — death counter with time penalty and a timestamped death log.
- **Splits** — records your best run per dungeon and key level and shows a live +/- comparison at each boss, with a manager panel for stored times.
- **Checkpoints** — target forces-% per boss section plus Point-of-No-Return thresholds, compared live against your current forces progress (ahead/behind display). Comes with a built-in editor, import/export, and a one-click set of curated default targets.
- **Cooldowns** — optional battle-rez charge/recharge tracker and heroism/lust availability countdown.
- **Sound** — event-triggered audio cues (deaths, forces milestones, reached checkpoints, run start/complete/time-out) with bundled sounds, your own files, and LibSharedMedia support.
- **Automation** — optionally hide Blizzard's objective tracker during a key and auto-slot your keystone at the Font of Power.
- **Changelog** — in-game changelog with the full version history; opens once automatically after every update (can be disabled).
- **Profiles** — full profile system with import/export (LibSerialize + LibDeflate).
- **Styling** — every HUD element is configurable (position, font, color, texture/statusbar) per profile, plus a demo mode (`/mauimpt demo`) to style the HUD outside a key.

## Requirements

- World of Warcraft **Retail**, Midnight (12.0.x).
- The embedded libraries listed in [`MauiMPlusTimer/Libs/README.md`](MauiMPlusTimer/Libs/README.md) (Ace3, LibSharedMedia-3.0, LibSerialize, LibDeflate). These are **not** checked into this repository — see [Installation](#installation).

## Installation

### From a release

Download the packaged zip from CurseForge, Wago Addons, or the [GitHub Releases](https://github.com/mBlinkii/MAUI-M-Timer/releases) page (all built automatically with every required library bundled in) and extract it into your `World of Warcraft/_retail_/Interface/AddOns/` folder.

### From source

1. Clone this repository.
2. Populate `MauiMPlusTimer/Libs/` with the libraries listed in `MauiMPlusTimer/Libs/README.md`.
3. Copy (or symlink) the `MauiMPlusTimer` folder into `World of Warcraft/_retail_/Interface/AddOns/`.

## Usage

Type `/mauimpt` to open the options window (or use the minimap button / addon compartment entry). Subcommands jump straight to a specific page or panel:

| Command | Action |
|---|---|
| `/mauimpt` | open the options |
| `/mauimpt demo` | toggle demo mode |
| `/mauimpt splits` | open the times manager |
| `/mauimpt checkpoints` | open the checkpoint editor |
| `/mauimpt changelog` | open the changelog |
| `/mauimpt setup` | run the setup wizard |
| `/mauimpt profiles` | open the profiles page |

## Architecture

The addon follows a strict modular architecture: the Core has no module-specific logic, modules communicate only via an internal `AceEvent` message bus (`MMT_*`), all SavedVariables access is encapsulated in `Core/DB.lua`, and all UI is separated from data logic.

## Localization

All user-facing strings are localized via `AceLocale` (`L["KEY"]`). Currently supported: English (`enUS`), German (`deDE`).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) — the same history is available in-game via `/mauimpt changelog`.

## Contributing

Issues and pull requests are welcome. Please keep changes consistent with the module contract and conventions described above (no global variables, no direct SavedVariables access outside `Core/DB.lua`, all visible text localized).

## License

[MIT](LICENSE)
