# Changelog - MAUI M+ Timer

## [ver. 1.4.0] - 28.07.2026
### 🐛 FIX
- FIX - [Splits]: The "Manage times" window lists the current season's dungeons sorted by name, instead of only the ones with stored runs in map-ID order.
- FIX - [System]: The challenge map cache is requested at login, so the dungeon lists are no longer empty right after a fresh start.
### 🔧 UPDATE
- UPDATE - [Splits]: Dungeons from earlier seasons move into an "Outdated" group in the "Manage times" window, which offers a button to delete all of their stored times at once.
- UPDATE - [Checkpoints]: Configured dungeons from earlier seasons move into an "Outdated" group in the checkpoint editor, keeping the main list to the current season.
- UPDATE - [Changelog]: Entries carry a scope label that is highlighted on the changelog page, matching the format of CHANGELOG.md.
### ✨ NEW
- NEW - [System]: The timer and forces bars can show an edge line at the moving end of the fill, with its own width, height and color.
- NEW - [System]: The timer and forces bars can fade their fill as a gradient, either to the bar color scaled by a multiplier or to a custom end color, with an option to swap both ends.
- NEW - [System]: A gradient on a split bar runs continuously across all segments instead of restarting in each one.

## [ver. 1.3.0] - 14.07.2026
### 🐛 FIX
- FIX - [HUD]: Separator lines no longer stay visible outside a key and now follow the modules, showing only during a run or in demo mode.
- FIX - [Profiles]: Switching profiles refreshes the display fully without a /reload, including module states, layout, position, scale and demo mode.
- FIX - [Options]: The Category and License labels on the About page are localized instead of always showing English.
- FIX - [Objectives]: The sample boss names in demo mode are localized instead of always appearing in English.
### 🔧 UPDATE
- UPDATE - [HUD]: Element order doubles as the module on/off control, so placing a module enables it and clearing its slot disables it.
- UPDATE - [HUD]: The timer text can share a row with another module, while the timer bar always occupies a full row.
- UPDATE - [Splits]: New "Show label" option hides the "Run vs best" label and shows only the +/- delta.
- UPDATE - [Splits]: Removing Splits from the element order now hides only its HUD line; best-time recording continues for the other displays.
- UPDATE - [Setup]: The wizard can be reopened from the options via General → Other → "Run setup wizard".
- UPDATE - [Setup]: Redesigned wizard with a pinned footer, a "Steps 1 - 2 - 3" progress indicator, the addon logo on the welcome step and preset previews beside their descriptions.
- UPDATE - [Enemy-Forces]: New "Percentage only" option reduces the main text to just the percentage.
- UPDATE - [Enemy-Forces]: New "Hide first segment countdown" option keeps the first label from overlapping the main text.
- UPDATE - [System]: Demo mode varies its samples on every activation, so the timer and forces bar can be styled in different display states.
### ✨ NEW
- NEW - [Setup]: First-start wizard that helps you pick a starting profile and load the recommended checkpoint targets, re-runnable via /mauimpt setup.
- NEW - [Setup]: Three preset profiles with preview screenshots — MaUI, Simple and Compact — each applying a complete look in one click.
- NEW - [Setup]: Presets that need the Blinkiis Media Pack fonts offer a download button with the copyable CurseForge link.
- NEW - [Timer]: The timer bar is its own orderable block now, so it can be positioned or hidden independently of the timer text.
- NEW - [Localization]: Simplified Chinese (zhCN) and Traditional Chinese (zhTW) translations for all interface strings, following Blizzard's official client terminology.

## [ver. 1.2.0] - 10.07.2026
### 🐛 FIX
- FIX - [Profiles]: The Import/Export section no longer leaks into other addons' profile pages, because MAUI builds its own profiles group instead of touching AceDBOptions' shared table.
### 🔧 UPDATE
- UPDATE - [HUD]: The Enemy Forces "Bar position" option and the separator "After element" anchor were replaced by the free layout, with saved settings migrated automatically.
- UPDATE - [HUD]: Placing two modules in one row aligns them to their side automatically, only at the moment of placement.
- UPDATE - [HUD]: "Lock display" also applies in demo mode, so a locked HUD cannot be dragged while styling.
- UPDATE - [Enemy-Forces]: The checkpoint countdown matches the timer bar's, anchoring labels at the checkpoint boundaries with the same position modes and an option to show all checkpoints at once.
- UPDATE - [Enemy-Forces]: The main percentage text got its own position setting and can be hidden, replacing the module's alignment option.
- UPDATE - [Splits]: The "Run vs best" label can be replaced by a compact icon that scales with the font and has its own color.
- UPDATE - [Checkpoints]: The "Boss" and "PoNR" labels can be replaced by compact icons with their own colors.
- UPDATE - [Profiles]: Import strings are tagged and validated, so foreign, mismatched or corrupted strings are rejected and strings from earlier versions have to be re-exported.
- UPDATE - [Profiles]: Importing a profile creates it under its exported name instead of overwriting the current one, asking for confirmation only on a name collision.
- UPDATE - [Options]: The options window opens at 900x650 by default.
- UPDATE - [Options]: The changelog and Import/Export pages got their own icons and colors in the options tree.
- UPDATE - [System]: The minimap button and the addon compartment entry toggle the options window, so a second click closes it.
### ✨ NEW
- NEW - [HUD]: Free layout under General → Element order, where dropdowns place any module per row and a row can hold two modules side by side.
- NEW - [Objectives]: Optional "Enemy Forces" row at the end of the boss list, showing the live percentage plus best and completion time like a boss row.
- NEW - [Options]: The options window remembers its size and position, with a reset button at the bottom-left edge restoring the default.

## [ver. 1.1.16] - 09.07.2026
### 🐛 FIX
- FIX - [Checkpoints]: The "Export as Lua table" toggle showed the profile-export description instead of a checkpoint-specific one.
- FIX - [System]: Profile serialization is guarded against cycles and runaway nesting with a depth limit instead of overflowing the stack.
### 🔧 UPDATE
- UPDATE - [Enemy-Forces]: Checkpoint target percentages are cached per dungeon, so the split bar allocates nothing on a progress tick.
- UPDATE - [Checkpoints]: Editor inputs write through validating data-API setters instead of directly into the stored tables.
- UPDATE - [Dungeon]: The dungeon icon is cropped so Blizzard's baked-in icon border is no longer visible.
- UPDATE - [Options]: The About page command list includes /mauimpt changelog.
### ✨ NEW
- NEW - [Changelog]: In-game version history in the options tree and via /mauimpt changelog, opening once automatically after each update.

## [ver. 1.1.15] - 08.07.2026
### 🐛 FIX
- FIX - [Enemy-Forces]: The percentage text could be covered or wrapped by bar and border textures and now sits on a dedicated overlay above all bar frames.
### 🔧 UPDATE
- UPDATE - [Enemy-Forces]: Checkpoint markers are hidden in split mode, where the segment gaps already mark every checkpoint.
### ✨ NEW
- NEW - [Enemy-Forces]: Optional split bar that divides the progress bar into segments at each checkpoint, with a configurable segment gap.
- NEW - [Enemy-Forces]: Per-segment countdown showing the still-needed percentage, with its own font, size, offset and color options.
- NEW - [Checkpoints]: "Load default checkpoints" button that loads author-curated targets for eight dungeons in one click.
- NEW - [Profiles]: "Export as Lua table" option that outputs readable Lua source as a developer format.

## [ver. 1.0.0] - 05.07.2026
### ✨ NEW
- NEW - [System]: Initial public release of MAUI M+ Timer, a modular Mythic+ timer for World of Warcraft (Midnight).
