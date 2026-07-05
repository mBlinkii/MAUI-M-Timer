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

- **Timer** — key timer with time-limit thresholds (+1/+2/+3), driven by the run controller so it keeps working even if other modules are disabled.
- **Enemy Forces** — aggregate (dungeon-total) forces progress. Per-mob pull previews are not possible under Midnight's restricted unit IDs, so this shows overall percentage/remaining count only.
- **Objectives** — boss/criteria progress from the scenario step info.
- **Deaths** — death counter and death log with timestamps, tracked via polling + death/rez events.
- **Splits** — best-time and route comparison per dungeon and key level, with a cleanup/detail panel.
- **Checkpoints** — target forces-% per boss section *and* per elapsed time (e.g. 5 min → 10 %, with linear interpolation), plus a built-in editor and live ahead/behind comparison.
- **Cooldowns** — optional battle-rez charge/recharge tracker and heroism/lust availability countdown.
- **Sound** — optional audio alerts (own files + LibSharedMedia) for rez and heroism/lust.
- **Profiles** — full profile system with import/export (LibSerialize + LibDeflate).
- **Styling** — every HUD element is configurable (position, font, color, texture/statusbar) per profile.

## Requirements

- World of Warcraft **Retail**, Midnight (12.0.x).
- The embedded libraries listed in [`MauiMPlusTimer/Libs/README.md`](MauiMPlusTimer/Libs/README.md) (Ace3, LibSharedMedia-3.0, LibSerialize, LibDeflate, optionally LibDataBroker-1.1 + LibDBIcon-1.0). These are **not** checked into this repository — see [Installation](#installation).

## Installation

### From a release

Download the packaged zip from the [Releases](https://github.com/mBlinkii/MAUI-M-Timer/releases) page (built via the CurseForge/BigWigs packager, which bundles all required libraries) and extract it into your `World of Warcraft/_retail_/Interface/AddOns/` folder.

### From source

1. Clone this repository.
2. Populate `MauiMPlusTimer/Libs/` with the libraries listed in `MauiMPlusTimer/Libs/README.md`, either manually or by running the [BigWigs packager](https://github.com/BigWigsMods/packager) against the repo-root `.pkgmeta`.
3. Copy (or symlink) the `MauiMPlusTimer` folder into `World of Warcraft/_retail_/Interface/AddOns/`.

## Usage

Type `/mauimpt` (or `/maui`, `/mpt`) to open the options window. Subcommands jump straight to a specific page, e.g. `/mauimpt checkpoints`.

## Architecture

The addon follows a strict modular architecture: the Core has no module-specific logic, modules communicate only via an internal `AceEvent` message bus (`MMT_*`), all SavedVariables access is encapsulated in `Core/DB.lua`, and all UI is separated from data logic. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full design document, including the module data flow, per-module WoW API surface, and instructions for adding a new module.

## Localization

All user-facing strings are localized via `AceLocale` (`L["KEY"]`). Currently supported: English (`enUS`), German (`deDE`).

## Contributing

Issues and pull requests are welcome. Please keep changes consistent with the module contract and conventions described in `ARCHITECTURE.md` (no global variables, no direct SavedVariables access outside `Core/DB.lua`, all visible text localized).

## License

[MIT](LICENSE)
