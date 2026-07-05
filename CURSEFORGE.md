# MAUI M+ Timer

A modular Mythic+ timer for World of Warcraft **Retail (Midnight, 12.0.x)**. Every part of the HUD — timer, enemy forces, deaths, splits, checkpoints, cooldowns — is its own module that can be turned on or off, and everything is configured through one clean options window. No chat commands to memorize, no config files to edit.

## Preview

![MAUI M+ Timer HUD](https://raw.githubusercontent.com/mBlinkii/MAUI-M-Timer/main/preview/preview%20%281%29.png)

## Features

**Timer** — Key timer with +1/+2/+3 time-limit thresholds, always accurate even if you turn other modules off.

**Enemy Forces** — Aggregate dungeon-wide forces progress (overall percentage and remaining count).

**Objectives** — Live boss/criteria progress straight from the scenario tracker.

**Deaths** — Death counter with a timestamped death log.

**Splits** — Best-time and route comparison per dungeon and key level, so you always know if you're ahead or behind your own record.

**Checkpoints** — Set target forces-% per boss section *and* per elapsed time (e.g. 5 min → 10%), with linear interpolation between checkpoints and a live ahead/behind comparison. Comes with a built-in editor.

**Cooldowns** — Optional battle-rez charge/recharge tracker and heroism/lust availability countdown.

**Sound** — Optional audio alerts for rez and heroism/lust, using your own sounds or LibSharedMedia.

**Profiles** — Full profile system with import/export, so you can share your setup or switch between characters instantly.

**Full styling control** — Position, font, color, and texture/statusbar are all configurable per HUD element.

## Requirements

World of Warcraft **Retail**, Midnight (12.0.x).

## Usage

Type `/mauimpt` (or `/maui`, `/mpt`) to open the options window. Subcommands jump straight to a page, e.g. `/mauimpt checkpoints`.

## Support & Source

Source code, issue tracker, and the latest builds are on [GitHub](https://github.com/mBlinkii/MAUI-M-Timer). Bug reports and feature requests are welcome there.

## License

Released under the [MIT License](https://github.com/mBlinkii/MAUI-M-Timer/blob/main/LICENSE).
