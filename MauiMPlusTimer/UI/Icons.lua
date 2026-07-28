-- UI/Icons.lua
-- Catalog of selectable status icons and the dropdown builder for them.

local ADDON_NAME, ns = ...

local ASSET = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\"

-- Index 1 is the default. Custom art is referenced without a file extension.
local catalog = {
    done    = { "Interface\\RaidFrame\\ReadyCheck-Ready" },
    pending = { "Interface\\RaidFrame\\ReadyCheck-Waiting" },
    death   = { "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    ready   = { "Interface\\RaidFrame\\ReadyCheck-Ready" }, -- reuses the done art
}

for i = 1, 9 do
    local n = string.format("%02d", i)
    table.insert(catalog.done,    ASSET .. "Done\\finished_" .. n)
    table.insert(catalog.pending, ASSET .. "Pending\\open_" .. n)
    table.insert(catalog.ready,   ASSET .. "Done\\finished_" .. n)
end
table.insert(catalog.death, ASSET .. "Death\\skull_01")

ns.Icons = {}

-- category: "done" | "pending" | "death" | "ready".
function ns.Icons:Default(category)
    local list = catalog[category]
    return list and list[1] or nil
end

-- Returns (values, sorting) for an AceConfig select; the labels embed an inline
-- preview of the art.
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
