-- Modules/Changelog/Options.lua
-- Changelog page: auto-show toggle, version dropdown and the section blocks.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Changelog = Addon:GetModule("Changelog")

-- Header colors match the addon logo; the icons are Blizzard textures, so no
-- extra assets are needed.
local SECTIONS = {
    { key = "new",     label = "New",     color = "|cff33ff99",
      icon = "Interface\\PaperDollInfoFrame\\Character-Plus" },
    { key = "updates", label = "Updates", color = "|cff29a8f0",
      icon = "Interface\\Buttons\\UI-RefreshButton" },
    { key = "fixes",   label = "Fixes",   color = "|cfff09020",
      icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
}

-- Scope label color. Deliberately none of the three section colors, since
-- scopes appear under all of them.
local SCOPE_COLOR = "|cffb653ff"

-- View state only, deliberately not persisted.
local selected = 1

local function selectedEntry()
    return Changelog.Data.entries[selected] or Changelog.Data.entries[1]
end

-- Highlights the leading "[Scope]" of an entry. Anchored, so a later bracket in
-- the description text is left alone.
local function renderLine(line)
    return (line:gsub("^%[([^%]]+)%]", SCOPE_COLOR .. "[%1]|r"))
end

local function sectionText(lines)
    local out = {}
    for i, line in ipairs(lines) do
        out[i] = "\226\128\162  " .. renderLine(line) -- UTF-8 bullet
    end
    return table.concat(out, "\n\n") .. "\n"
end

-- "v1.1.15 (08.07.2026)".
local function versionLabel(entry)
    local label = entry.version
    if label ~= "Unreleased" then label = "v" .. label end
    if entry.date and entry.date ~= "" then
        label = label .. " (" .. entry.date .. ")"
    end
    return label
end

local function versionValues()
    local values = {}
    for i, entry in ipairs(Changelog.Data.entries) do
        values[i] = versionLabel(entry)
    end
    return values
end

-- name and args resolve lazily, so the dropdown switches the content without
-- rebuilding the tree.
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
