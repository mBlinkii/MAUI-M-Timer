# Changelog

All notable changes to **MAUI M+ Timer** are documented in this file.

Changes are grouped per version into **New** (features), **Updates** (improvements to existing behavior), and **Fixes** (bug fixes). Changes land under the topmost *Unreleased* version until it is released.

## [Unreleased]

### New

- The options window remembers its size and position when you move or resize it; a small reset button at the bottom-left edge of the window restores the default size.
- Objectives: optional "Enemy Forces" entry at the end of the boss list — the live percentage sits directly beside the label, and like the boss rows it shows the best time plus completion time with +/- delta (following the split-times visibility).
- Free HUD layout: under General -> Element order, every row has dropdowns to place any module — and a row can hold TWO modules side by side (left/right), e.g. Deaths next to Splits. Wide elements (Timer, Enemy Forces, Objectives, separator lines) always occupy a full row. Enabled separator lines appear in the list as well and are placed like any other element. Changes apply live, are stored per profile, and a reset button restores the default layout.
- The Enemy Forces "Bar position" option and the separator "After element" anchor were replaced by the free layout; saved settings are migrated automatically.

### Fixes

- The profile Import/Export section leaked into the profile pages of OTHER addons (e.g. ElvUI): it was added to AceDBOptions' library-wide shared options table. MAUI now builds its own profiles group and no longer touches the shared table.

### Updates

- Splits and Checkpoints can replace their text labels ("Run vs best", "Boss", "PoNR") with compact icons — per-module toggle in the options. The icons scale with the font size and each icon has its own configurable color.
- Enemy Forces: the checkpoint countdown now behaves exactly like the timer bar's countdown — the labels anchor at the checkpoint boundaries (markers on the single bar, gap centers on the split bar) with the same position modes (above/below, left/right of the line, or inside the bar — including centered in the section), and by default only the next checkpoint counts down; a new option shows all at once. Works with and without the split bar. 0% and 100% targets draw no divider or marker at the bar's ends, but the final section still counts down to 100% (label only, like the timer's limit countdown).
- Enemy Forces: the main percentage text got its own position setting (above/below the bar, or inside — centered/left/right) and can be hidden entirely; the module's alignment option was removed in its favor.
- Placing two modules into one row automatically aligns them to their side (left half → left, right half → right). This happens only at the moment of placement in the element order — manual alignment changes afterwards are kept, and full-width elements are unaffected.
- The changelog page got its own icon and color in the options tree, and the profile Import/Export page its own icon.
- Import/export strings (profiles and checkpoints) are now tagged and validated: the import only accepts genuine MAUI export strings of the matching type and rejects foreign, mismatched, or corrupted strings. Note: strings exported with earlier versions are no longer accepted — re-export to share.
- Importing a profile no longer overwrites the current one: the profile is created under its exported name and activated. You are only asked for confirmation when a profile with that name already exists; invalid strings are rejected immediately without a confirmation popup.
- The options window opens noticeably larger by default (900x650).
- The minimap button and the addon compartment entry now toggle the options window — a second click closes it.
- "Lock display" now also applies in demo mode: a locked HUD can no longer be dragged while styling.

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
