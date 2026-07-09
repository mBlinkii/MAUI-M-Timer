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
