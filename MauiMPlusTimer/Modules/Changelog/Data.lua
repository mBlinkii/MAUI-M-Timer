-- Modules/Changelog/Data.lua
-- Version history shown on the in-game changelog page. Mirrors CHANGELOG.md
-- (always English by project policy) and must be updated together with it.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Changelog = Addon:GetModule("Changelog")

local Data = {}
Changelog.Data = Data

-- Ordered list, NEWEST FIRST. Each entry:
--   version          "x.y.z", matching the .toc version / release tag
--   date             release date ("YYYY-MM-DD") or "Unreleased"
--   new/updates/fixes  arrays of plain lines; sections may be omitted
Data.entries = {
    {
        version = "Unreleased",
        date = "",
        new = {
            "Simplified Chinese (zhCN) and Traditional Chinese (zhTW) localizations. All interface strings are translated using Blizzard's official Chinese client terminology; untranslated keys still fall back to English.",
            "First-start setup wizard: on a fresh installation, a short guided setup helps you pick a starting profile and load the recommended checkpoint targets. Re-run it anytime via /mauimpt setup.",
            "The setup wizard ships with the 'MaUI' preset profile (the author's personal look, with preview screenshot) alongside the factory default.",
        },
        updates = {
            "The setup wizard can now be reopened from the options: General -> Other has a 'Run setup wizard' button, next to the /mauimpt setup slash command.",
            "Setup wizard redesign: a consistent footer pinned to the bottom bar (level with the Close button) with a left button (Skip on step 1, Back afterwards), a 'Steps 1 - 2 - 3' progress indicator that highlights the current step, and the Next/Finish button next to Close. The welcome step now shows the addon logo; profile presets are laid out with the preview on the left, the description on the right, and the apply button in the bottom-right corner; and the checkpoint box places its apply button in the bottom-right corner too. A preset can also show a secondary note under its description (the MaUI preset points out its !mMT_MediaPack font dependency).",
            "Demo mode now varies its samples each time it is turned on: the timer shows a random elapsed time (5/12/20/28 min) and the Enemy Forces bar a random percentage (5/30/50/65/95%), so the different display states can be styled.",
        },
    },
    {
        version = "1.2.0",
        date = "2026-07-10",
        new = {
            "The options window remembers its size and position when you move or resize it; a small reset button at the bottom-left edge of the window restores the default size.",
            "Objectives: optional 'Enemy Forces' entry at the end of the boss list - the live percentage sits directly beside the label, and like the boss rows it shows the best time plus completion time with +/- delta (following the split-times visibility).",
            "Free HUD layout: under General -> Element order, every row has dropdowns to place any module - and a row can hold TWO modules side by side (left/right), e.g. Deaths next to Splits. Wide elements (Timer, Enemy Forces, Objectives, separator lines) always occupy a full row. Enabled separator lines appear in the list as well. Changes apply live, are stored per profile, and a reset button restores the default layout.",
            "The Enemy Forces 'Bar position' option and the separator 'After element' anchor were replaced by the free layout; saved settings are migrated automatically.",
        },
        updates = {
            "Splits and Checkpoints can replace their text labels ('Run vs best', 'Boss', 'PoNR') with compact icons - per-module toggle in the options. The icons scale with the font size and each icon has its own configurable color.",
            "Enemy Forces: the checkpoint countdown now behaves exactly like the timer bar's countdown - the labels anchor at the checkpoint boundaries (markers on the single bar, gap centers on the split bar) with the same position modes plus an in-bar section-centered one, and by default only the next checkpoint counts down; a new option shows all at once. Works with and without the split bar. 0% and 100% targets draw no divider or marker at the bar's ends, but the final section still counts down to 100% (label only, like the timer's limit countdown).",
            "Enemy Forces: the main percentage text got its own position setting (above/below the bar, or inside - centered/left/right) and can be hidden entirely; the module's alignment option was removed in its favor.",
            "Placing two modules into one row automatically aligns them to their side (left half -> left, right half -> right). This happens only at the moment of placement in the element order - manual alignment changes afterwards are kept, and full-width elements are unaffected.",
            "The changelog page got its own icon and color in the options tree, and the profile Import/Export page its own icon.",
            "Import/export strings (profiles and checkpoints) are now tagged and validated: the import only accepts genuine MAUI export strings of the matching type. Strings exported with earlier versions are no longer accepted - re-export to share.",
            "Importing a profile no longer overwrites the current one: the profile is created under its exported name and activated. Confirmation is only asked when that name already exists; invalid strings are rejected immediately.",
            "The options window opens noticeably larger by default.",
            "The minimap button and the addon compartment entry now toggle the options window - a second click closes it.",
            "'Lock display' now also applies in demo mode: a locked HUD can no longer be dragged while styling.",
        },
        fixes = {
            "The profile Import/Export section no longer leaks into the profile pages of other addons (e.g. ElvUI).",
        },
    },
    {
        version = "1.1.16",
        date = "2026-07-09",
        new = {
            "This in-game changelog with the full version history: pick any version from the dropdown above. It opens once automatically after every addon update (can be turned off on this page) and is also available via /mauimpt changelog.",
        },
        updates = {
            "Enemy Forces: checkpoint target percentages are now cached per dungeon - the split bar no longer allocates memory on every progress tick.",
            "Checkpoints: editor inputs (boss index, target %, PoNR %) now go through validating data-API setters.",
            "Dungeon: the dungeon icon is now cropped so Blizzard's baked-in icon border is no longer visible.",
            "About: the command list now includes /mauimpt changelog.",
        },
        fixes = {
            "Checkpoint editor: the 'Export as Lua table' toggle showed the profile-export description instead of a checkpoint-specific one.",
            "Table serialization is now guarded against accidental cycles.",
        },
    },
    {
        version = "1.1.15",
        date = "2026-07-08",
        new = {
            "Enemy Forces: optional split bar - the progress bar splits into segments at each checkpoint, with a configurable segment gap.",
            "Enemy Forces: per-segment countdown showing the still-needed percentage on each segment; it hides once the checkpoint is reached.",
            "Checkpoints: 'Load default checkpoints' button that loads author-curated targets for 8 dungeons with one click.",
            "'Export as Lua table' option for profiles and checkpoints (developer format, not re-importable).",
        },
        updates = {
            "Enemy Forces: checkpoint markers are hidden in split mode, where the segment gaps already mark every checkpoint.",
        },
        fixes = {
            "The percentage text on the Enemy Forces bar could be covered by bar or border textures; it now sits on a dedicated overlay.",
        },
    },
    {
        version = "1.0.0",
        date = "2026-07-05",
        new = {
            "Initial public release of MAUI M+ Timer - a modular Mythic+ timer for World of Warcraft (Midnight).",
        },
    },
}
