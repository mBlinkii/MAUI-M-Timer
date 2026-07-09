-- Modules/Changelog/Options.lua
-- AceConfig options page for the in-game changelog: the auto-show toggle, a
-- version dropdown (newest first) and the selected version's New/Updates/
-- Fixes sections rendered below it.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Changelog = Addon:GetModule("Changelog")

-- Section order, localization keys, header colors (match the addon logo:
-- green = new, blue = updates, orange = fixes) and header icons (built-in
-- Blizzard textures, so no extra asset files are needed).
local SECTIONS = {
    { key = "new",     label = "New",     color = "|cff33ff99",
      icon = "Interface\\PaperDollInfoFrame\\Character-Plus" },
    { key = "updates", label = "Updates", color = "|cff29a8f0",
      icon = "Interface\\Buttons\\UI-RefreshButton" },
    { key = "fixes",   label = "Fixes",   color = "|cfff09020",
      icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
}

-- Index into Data.entries currently shown in the dropdown (1 = newest).
-- Session-only view state, intentionally not saved.
local selected = 1

local function selectedEntry()
    return Changelog.Data.entries[selected] or Changelog.Data.entries[1]
end

-- Join a section's lines into one bullet-list description block.
local function sectionText(lines)
    local out = {}
    for i, line in ipairs(lines) do
        out[i] = "\226\128\162  " .. line -- UTF-8 bullet
    end
    return table.concat(out, "\n\n") .. "\n"
end

-- Dropdown labels, e.g. "v1.1.15 (2026-07-08)". Numeric keys keep the
-- newest-first order of Data.entries in the dropdown.
local function versionValues()
    local values = {}
    for i, entry in ipairs(Changelog.Data.entries) do
        values[i] = string.format("v%s (%s)", entry.version, entry.date or "")
    end
    return values
end

-- One section block of the selected version; hidden when that version has no
-- entries for it. name/args resolve lazily so the dropdown switches the
-- content without any tree rebuild.
local function sectionGroup(section, order)
    local L = ns.L
    return {
        type = "group", inline = true, order = order,
        name = "|T" .. section.icon .. ":14:14|t  " .. section.color .. L[section.label] .. "|r",
        hidden = function()
            local lines = selectedEntry()[section.key]
            return not (lines and #lines > 0)
        end,
        args = {
            text = {
                type = "description", order = 1, fontSize = "medium",
                name = function()
                    local lines = selectedEntry()[section.key]
                    return lines and sectionText(lines) or ""
                end,
            },
        },
    }
end

-- Root changelog page: auto-show toggle, version dropdown, sections.
function Changelog:GetOptions()
    local L = ns.L

    local args = {
        autoShow = {
            type = "toggle", order = 1, width = "full",
            name = L["Show changelog after updates"],
            desc = L["Automatically open the changelog once after the addon has been updated to a new version."],
            get = function() return Changelog:GetSettings().autoShow ~= false end,
            set = function(_, v) Changelog:GetSettings().autoShow = v end,
        },
        version = {
            type = "select", order = 2,
            name = L["Version"],
            values = versionValues,
            get = function() return selected end,
            set = function(_, v) selected = v end,
        },
        spacer = {
            type = "description", order = 3, fontSize = "medium",
            name = "\n",
        },
    }

    for i, section in ipairs(SECTIONS) do
        args[section.key] = sectionGroup(section, 10 + i)
    end

    return {
        type = "group",
        name = L["Changelog"],
        args = args,
    }
end
