-- UI/Icons.lua
-- Central catalog of selectable status icons. Each category lists the texture
-- paths offered in its options dropdown; the first entry is the default (the
-- Blizzard texture used before custom art existed). Custom art lives under
-- Assets/Icons/<Folder>/ and is referenced without the file extension, as WoW
-- texture paths require.
--
-- Public API (ns.Icons):
--   :Default(category)      -> the default texture path for a category
--   :BuildSelect(category)  -> (values, sorting) tables for an AceConfig select,
--                              each value labelled with an inline icon preview

local ADDON_NAME, ns = ...

local ASSET = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\"

-- Category -> ordered list of texture paths (index 1 = default).
local catalog = {
    done    = { "Interface\\RaidFrame\\ReadyCheck-Ready" },
    pending = { "Interface\\RaidFrame\\ReadyCheck-Waiting" },
    death   = { "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    -- The "Heroism ready" check reuses the custom completion checkmarks.
    ready   = { "Interface\\RaidFrame\\ReadyCheck-Ready" },
}

-- Append the custom art (finished_/open_/skull_ NN) created in Assets/Icons.
for i = 1, 9 do
    local n = string.format("%02d", i)
    table.insert(catalog.done,    ASSET .. "Done\\finished_" .. n)
    table.insert(catalog.pending, ASSET .. "Pending\\open_" .. n)
    table.insert(catalog.ready,   ASSET .. "Done\\finished_" .. n)
end
table.insert(catalog.death, ASSET .. "Death\\skull_01")

ns.Icons = {}

--- Return the default texture path for a category.
-- @param category string one of "done"|"pending"|"death"|"ready"
-- @return string texture path
function ns.Icons:Default(category)
    local list = catalog[category]
    return list and list[1] or nil
end

--- Build AceConfig select tables for a category. The display label embeds an
--- inline preview of each icon so the dropdown shows the actual art.
-- @param category string
-- @return table values  path -> display label, table sorting  ordered paths
function ns.Icons:BuildSelect(category)
    local L = ns.L
    local list = catalog[category] or {}
    local values, sorting = {}, {}
    for idx, path in ipairs(list) do
        local label = (idx == 1) and L["Default"] or ("#" .. (idx - 1))
        values[path] = "|T" .. path .. ":20|t  " .. label
        sorting[idx] = path
    end
    return values, sorting
end
