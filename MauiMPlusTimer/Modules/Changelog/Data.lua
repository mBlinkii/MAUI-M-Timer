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
            "The options window remembers its size and position when you move or resize it; a small reset button at the bottom-left edge of the window restores the default size.",
            "First-start setup wizard: on a fresh installation, a short guided setup helps you pick a starting profile and load the recommended checkpoint targets. Re-run it anytime via /mauimpt setup.",
            "The setup wizard ships with the 'MaUI' preset profile (the author's personal look, with preview screenshot) alongside the factory default.",
            "Free HUD layout: under General -> Element order, every row has dropdowns to place any module - and a row can hold TWO modules side by side (left/right), e.g. Deaths next to Splits. Enabled separator lines appear in the list as well. Changes apply live and are stored per profile.",
            "The Enemy Forces 'Bar position' option and the separator 'After element' anchor were replaced by the free layout; saved settings are migrated automatically.",
        },
        updates = {
            "Import/export strings (profiles and checkpoints) are now tagged and validated: the import only accepts genuine MAUI export strings of the matching type. Strings exported with earlier versions are no longer accepted - re-export to share.",
            "Importing a profile no longer overwrites the current one: the profile is created under its exported name and activated. Confirmation is only asked when that name already exists; invalid strings are rejected immediately.",
            "The options window opens noticeably larger by default.",
            "The minimap button and the addon compartment entry now toggle the options window - a second click closes it.",
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
