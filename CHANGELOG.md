# Changelog

All notable changes to **MAUI M+ Timer** are documented in this file.

Changes are grouped per version into **New** (features), **Updates** (improvements to existing behavior), and **Fixes** (bug fixes). Changes land under the topmost *Unreleased* version until it is released.

## [Unreleased]

### Fixes

- Release workflow: the Wago upload sent the metadata JSON inline via `curl -F`, which corrupted it (commas/newlines are `-F` syntax); it is now passed from a file, fixing the "metadata must be a valid JSON string" error.

## [1.1.16] - 2026-07-09

### New

- In-game changelog with the full version history (options tree and `/mauimpt changelog`); it opens once automatically after every addon update. The auto-show can be disabled on the changelog page.

### Updates

- Enemy Forces: checkpoint target percentages are now cached per dungeon and invalidated through a generation counter — the split bar no longer allocates tables/strings on every progress tick.
- Checkpoints: editor inputs (boss index, target %, PoNR %) now write through validating data-API setters instead of directly into the stored tables.
- Release workflow: the Wago upload step logs the HTTP status and response body, and fails cleanly (with output) on network-level errors.
- Release workflow: the released version's changelog section is now extracted from CHANGELOG.md and published as the release notes on GitHub, CurseForge, and Wago; releases fail if the section is missing.
- Dungeon: the dungeon icon is now cropped so Blizzard's baked-in icon border is no longer visible.
- About: the command list now includes `/mauimpt changelog`.

### Fixes

- Checkpoint editor: the "Export as Lua table" toggle showed the profile-export description instead of a checkpoint-specific one.
- `Utils.SerializeTable` is now guarded against accidental cycles / runaway nesting (depth limit with a marker comment instead of a stack overflow).

## [1.1.15] - 2026-07-08

### New

- Enemy Forces: optional **split bar** — the progress bar can be split into segments at each checkpoint, with a configurable segment gap (the 100% target is ignored).
- Enemy Forces: per-segment **countdown** showing the still-needed percentage on each segment; it counts down and hides once the checkpoint is reached. Own style element ("Segment percentage") with font, size, offset, and color options.
- Checkpoints: **"Load default checkpoints"** button that loads author-curated per-dungeon targets (8 dungeons) with one click.
- Profile & checkpoint export: **"Export as Lua table"** option that outputs readable Lua source (developer format, not re-importable).

### Updates

- Enemy Forces: checkpoint markers are hidden in split mode, where the segment gaps already mark every checkpoint.
- Added the Wago project ID to the addon metadata.

### Fixes

- The percentage text on the Enemy Forces bar could be covered or wrapped by bar/border textures; it now sits on a dedicated overlay above all bar frames.

## [1.1.9] - 2026-07-06

### Updates

- Release pipeline reworked: plain zip packaging with explicit library fetch (replaces the BigWigs packager), plus fixes for the CurseForge, GitHub, and Wago upload steps.

## [1.0.0] - 2026-07-05

### New

- Initial public release of MAUI M+ Timer — a modular Mythic+ timer for World of Warcraft (Midnight).
