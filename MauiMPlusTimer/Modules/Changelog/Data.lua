-- Modules/Changelog/Data.lua
-- Version history for the in-game page. Mirrors CHANGELOG.md, always English,
-- and must be updated together with it.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Changelog = Addon:GetModule("Changelog")

local Data = {}
Changelog.Data = Data

-- Newest first. version matches the .toc, date is "DD.MM.YYYY" as in
-- CHANGELOG.md, and the new/updates/fixes arrays may each be omitted.
--
-- Each line mirrors its CHANGELOG.md entry verbatim, keeping the "[Scope]: "
-- prefix and dropping only the leading "- TYPE - ". Two mechanical
-- substitutions are applied for the in-game font: the arrow and em dash become
-- "->" and "-", and straight double quotes are escaped.
Data.entries = {
    {
        version = "1.6.0",
        date = "29.09.2026",
        new = {
            "[Options]: A new settings window in the addon's own design replaces the classic dialog, with a searchable sidebar, a counter of this session's changes with a button to discard them, and a button to reset its size and position; /mauimpt renderer switches back to the classic dialog.",
            "[Options]: The font, opacity and accent color of the settings window can be set under General -> Interface, with the accent following the class color, the default or a custom color.",
            "[System]: The settings window and the HUD draw text with the Slug font renderer, which keeps small text sharp; it can be switched off under General -> Interface.",
        },
        updates = {
            "[Splits]: The \"Manage times\" window has a new design, with a summary banner for the selected dungeon, stored runs as cards with a time bar, and the delete action pinned to the bottom.",
            "[Checkpoints]: The checkpoint editor has the same new design as the \"Manage times\" window.",
            "[Profiles]: A pasted import string is replaced by its details, showing the profile name, the exporting character, the addon version and the export date, and the import asks before it overwrites an existing profile.",
            "[Checkpoints]: A pasted import string is replaced by its details, showing the dungeons it contains, how many of them are already configured, the exporting character, the addon version and the export date, and the import asks before it overwrites configured dungeons.",
            "[Profiles]: A generated export string is selected right away, ready to copy.",
            "[HUD]: Split-bar gaps, section dividers and checkpoint markers snap to whole screen pixels, so every gap has the same width and thin lines stay sharp at any HUD scale.",
            "[HUD]: Icons inside HUD texts, such as the boss status icons, the battle res and Bloodlust icons and the forces check mark, follow the font size instead of a fixed size.",
            "[HUD]: Long boss and dungeon names are shortened with \"...\" instead of running into the time column or past the edge of the HUD.",
            "[Cooldowns]: The battle res and Bloodlust icons no longer show Blizzard's rounded icon border and turn grey instead of dark while unavailable.",
            "[HUD]: The border of the HUD and dungeon backgrounds defaults to a flat 1-pixel line instead of the rounded tooltip border.",
            "[Options]: Dungeon icons in the \"Manage times\" window and the checkpoint editor no longer show Blizzard's rounded icon border.",
            "[Checkpoints]: The recommended checkpoint targets are updated and now cover sixteen dungeons, including those of earlier seasons, two of them with a point of no return.",
        },
    },
    {
        version = "1.5.0",
        date = "20.08.2026",
        updates = {
            "[Checkpoints]: The recommended checkpoint targets cover the current season's eight dungeons and no longer ship the previous season's.",
        },
    },
    {
        version = "1.4.0",
        date = "28.07.2026",
        new = {
            "[System]: The timer and forces bars can show an edge line at the moving end of the fill, with its own width, height and color.",
            "[System]: The timer and forces bars can fade their fill as a gradient, either to the bar color scaled by a multiplier or to a custom end color, with an option to swap both ends.",
            "[System]: A gradient on a split bar runs continuously across all segments instead of restarting in each one.",
        },
        updates = {
            "[Splits]: Dungeons from earlier seasons move into an \"Outdated\" group in the \"Manage times\" window, which offers a button to delete all of their stored times at once.",
            "[Checkpoints]: Configured dungeons from earlier seasons move into an \"Outdated\" group in the checkpoint editor, keeping the main list to the current season.",
            "[Changelog]: Entries carry a scope label that is highlighted on the changelog page, matching the format of CHANGELOG.md.",
        },
        fixes = {
            "[Splits]: The \"Manage times\" window lists the current season's dungeons sorted by name, instead of only the ones with stored runs in map-ID order.",
            "[System]: The challenge map cache is requested at login, so the dungeon lists are no longer empty right after a fresh start.",
        },
    },
    {
        version = "1.3.0",
        date = "14.07.2026",
        new = {
            "[Setup]: First-start wizard that helps you pick a starting profile and load the recommended checkpoint targets, re-runnable via /mauimpt setup.",
            "[Setup]: Three preset profiles with preview screenshots - MaUI, Simple and Compact - each applying a complete look in one click.",
            "[Setup]: Presets that need the Blinkiis Media Pack fonts offer a download button with the copyable CurseForge link.",
            "[Timer]: The timer bar is its own orderable block now, so it can be positioned or hidden independently of the timer text.",
            "[Localization]: Simplified Chinese (zhCN) and Traditional Chinese (zhTW) translations for all interface strings, following Blizzard's official client terminology.",
        },
        updates = {
            "[HUD]: Element order doubles as the module on/off control, so placing a module enables it and clearing its slot disables it.",
            "[HUD]: The timer text can share a row with another module, while the timer bar always occupies a full row.",
            "[Splits]: New \"Show label\" option hides the \"Run vs best\" label and shows only the +/- delta.",
            "[Splits]: Removing Splits from the element order now hides only its HUD line; best-time recording continues for the other displays.",
            "[Setup]: The wizard can be reopened from the options via General -> Other -> \"Run setup wizard\".",
            "[Setup]: Redesigned wizard with a pinned footer, a \"Steps 1 - 2 - 3\" progress indicator, the addon logo on the welcome step and preset previews beside their descriptions.",
            "[Enemy-Forces]: New \"Percentage only\" option reduces the main text to just the percentage.",
            "[Enemy-Forces]: New \"Hide first segment countdown\" option keeps the first label from overlapping the main text.",
            "[System]: Demo mode varies its samples on every activation, so the timer and forces bar can be styled in different display states.",
        },
        fixes = {
            "[HUD]: Separator lines no longer stay visible outside a key and now follow the modules, showing only during a run or in demo mode.",
            "[Profiles]: Switching profiles refreshes the display fully without a /reload, including module states, layout, position, scale and demo mode.",
            "[Options]: The Category and License labels on the About page are localized instead of always showing English.",
            "[Objectives]: The sample boss names in demo mode are localized instead of always appearing in English.",
        },
    },
    {
        version = "1.2.0",
        date = "10.07.2026",
        new = {
            "[HUD]: Free layout under General -> Element order, where dropdowns place any module per row and a row can hold two modules side by side.",
            "[Objectives]: Optional \"Enemy Forces\" row at the end of the boss list, showing the live percentage plus best and completion time like a boss row.",
            "[Options]: The options window remembers its size and position, with a reset button at the bottom-left edge restoring the default.",
        },
        updates = {
            "[HUD]: The Enemy Forces \"Bar position\" option and the separator \"After element\" anchor were replaced by the free layout, with saved settings migrated automatically.",
            "[HUD]: Placing two modules in one row aligns them to their side automatically, only at the moment of placement.",
            "[HUD]: \"Lock display\" also applies in demo mode, so a locked HUD cannot be dragged while styling.",
            "[Enemy-Forces]: The checkpoint countdown matches the timer bar's, anchoring labels at the checkpoint boundaries with the same position modes and an option to show all checkpoints at once.",
            "[Enemy-Forces]: The main percentage text got its own position setting and can be hidden, replacing the module's alignment option.",
            "[Splits]: The \"Run vs best\" label can be replaced by a compact icon that scales with the font and has its own color.",
            "[Checkpoints]: The \"Boss\" and \"PoNR\" labels can be replaced by compact icons with their own colors.",
            "[Profiles]: Import strings are tagged and validated, so foreign, mismatched or corrupted strings are rejected and strings from earlier versions have to be re-exported.",
            "[Profiles]: Importing a profile creates it under its exported name instead of overwriting the current one, asking for confirmation only on a name collision.",
            "[Options]: The options window opens at 900x650 by default.",
            "[Options]: The changelog and Import/Export pages got their own icons and colors in the options tree.",
            "[System]: The minimap button and the addon compartment entry toggle the options window, so a second click closes it.",
        },
        fixes = {
            "[Profiles]: The Import/Export section no longer leaks into other addons' profile pages, because MAUI builds its own profiles group instead of touching AceDBOptions' shared table.",
        },
    },
    {
        version = "1.1.16",
        date = "09.07.2026",
        new = {
            "[Changelog]: In-game version history in the options tree and via /mauimpt changelog, opening once automatically after each update.",
        },
        updates = {
            "[Enemy-Forces]: Checkpoint target percentages are cached per dungeon, so the split bar allocates nothing on a progress tick.",
            "[Checkpoints]: Editor inputs write through validating data-API setters instead of directly into the stored tables.",
            "[Dungeon]: The dungeon icon is cropped so Blizzard's baked-in icon border is no longer visible.",
            "[Options]: The About page command list includes /mauimpt changelog.",
        },
        fixes = {
            "[Checkpoints]: The \"Export as Lua table\" toggle showed the profile-export description instead of a checkpoint-specific one.",
            "[System]: Profile serialization is guarded against cycles and runaway nesting with a depth limit instead of overflowing the stack.",
        },
    },
    {
        version = "1.1.15",
        date = "08.07.2026",
        new = {
            "[Enemy-Forces]: Optional split bar that divides the progress bar into segments at each checkpoint, with a configurable segment gap.",
            "[Enemy-Forces]: Per-segment countdown showing the still-needed percentage, with its own font, size, offset and color options.",
            "[Checkpoints]: \"Load default checkpoints\" button that loads author-curated targets for eight dungeons in one click.",
            "[Profiles]: \"Export as Lua table\" option that outputs readable Lua source as a developer format.",
        },
        updates = {
            "[Enemy-Forces]: Checkpoint markers are hidden in split mode, where the segment gaps already mark every checkpoint.",
        },
        fixes = {
            "[Enemy-Forces]: The percentage text could be covered or wrapped by bar and border textures and now sits on a dedicated overlay above all bar frames.",
        },
    },
    {
        version = "1.0.0",
        date = "05.07.2026",
        new = {
            "[System]: Initial public release of MAUI M+ Timer, a modular Mythic+ timer for World of Warcraft (Midnight).",
        },
    },
}
