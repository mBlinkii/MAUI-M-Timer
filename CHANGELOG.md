# Changelog

All notable changes to **MAUI M+ Timer** are documented in this file.

Changes are grouped per version into **New** (features), **Updates** (improvements to existing behavior), and **Fixes** (bug fixes). Changes land under the topmost *Unreleased* version until it is released.

## [Unreleased]

### New

- The options window remembers its size and position when you move or resize it; a small reset button at the bottom-left edge of the window restores the default size.
- First-start setup wizard: on a fresh installation, a short guided setup helps you pick a starting profile and load the recommended checkpoint targets. It can be re-run anytime via `/mauimpt setup`.
- The setup wizard ships with the "MaUI" preset profile (the author's personal look, with preview screenshot) alongside the factory default.

### Fixes

- The profile Import/Export section leaked into the profile pages of OTHER addons (e.g. ElvUI): it was added to AceDBOptions' library-wide shared options table. MAUI now builds its own profiles group and no longer touches the shared table.

### Updates

- Import/export strings (profiles and checkpoints) are now tagged and validated: the import only accepts genuine MAUI export strings of the matching type and rejects foreign, mismatched, or corrupted strings. Note: strings exported with earlier versions are no longer accepted — re-export to share.
- The options window opens noticeably larger by default (900x650).
- The minimap button and the addon compartment entry now toggle the options window — a second click closes it.

## [1.1.16] - 2026-07-09

### New

- In-game changelog with the full version history (options tree and `/mauimpt changelog`); it opens once automatically after every addon update. The auto-show can be disabled on the changelog page.

### Updates

- Enemy Forces: checkpoint target percentages are now cached per dungeon and invalidated through a generation counter — the split bar no longer allocates tables/strings on every progress tick.
- Checkpoints: editor inputs (boss index, target %, PoNR %) now write through validating data-API setters instead of directly into the stored tables.
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

### Fixes

- The percentage text on the Enemy Forces bar could be covered or wrapped by bar/border textures; it now sits on a dedicated overlay above all bar frames.

## [1.0.0] - 2026-07-05

### New

- Initial public release of MAUI M+ Timer — a modular Mythic+ timer for World of Warcraft (Midnight).
