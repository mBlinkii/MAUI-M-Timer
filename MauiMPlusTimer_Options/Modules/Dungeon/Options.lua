-- Modules/Dungeon/Options.lua
-- AceConfig pages for the Dungeon blocks: name, icon, keystone level, affixes.

local _, ns = ...
local Addon = ns.Addon
local Dungeon = Addon:GetModule("Dungeon")

local ICON = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\dungeon"

local function head(blockKey)
    return { enabled = Addon:BlockEnableOption(blockKey, 1) }
end

function Dungeon:GetOptions()
    local L = ns.L
    local options = {
        type = "group",
        name = L["Dungeon name"],
        order = 5,
        icon = ICON,
        args = head("dungeon"),
    }
    options.args.name = Addon:ElementTextOptions(self, ns.E.dungeonName, 20, { color = true, name = L["Dungeon name"] })

    -- Background + border groups (border depends on the background being on).
    Addon:AddBackgroundGroups(
        options.args,
        function()
            local s = Dungeon:GetSettings()
            s.bg = s.bg or {}
            return s.bg
        end,
        function() Addon.StyleRestyle(Dungeon) end,
        50)

    return options
end

function Dungeon:GetOptionPages()
    local L = ns.L

    local iconArgs = head("dungeonicon")
    iconArgs.icon = {
        type = "group", inline = true, name = L["Dungeon icon"], order = 10,
        args = {
            size = {
                type = "range", name = L["Icon size"], order = 1, min = 8, max = 64, step = 1,
                get = function() return Dungeon:GetSettings().iconSize or 20 end,
                set = function(_, v) Dungeon:GetSettings().iconSize = v; Addon.StyleRestyle(Dungeon) end,
            },
        },
    }

    local levelArgs = head("level")
    levelArgs.color = {
        type = "group", inline = true, name = L["Keystone level"], order = 10,
        args = {
            color = {
                type = "toggle", name = L["Color by level rarity"], order = 1,
                desc = L["Color the keystone level with Blizzard's rarity color."],
                get = function() return Dungeon:GetSettings().levelColor == true end,
                set = function(_, v) Dungeon:GetSettings().levelColor = v; Addon.StyleRestyle(Dungeon) end,
            },
        },
    }
    levelArgs.text = Addon:ElementTextOptions(self, ns.E.dungeonLevel, 20, { color = true })

    local affixArgs = head("affixes")
    affixArgs.text = Addon:ElementTextOptions(self, ns.E.dungeonAffixes, 20, { color = true })

    return {
        dungeonicon = { type = "group", name = L["Dungeon icon"], order = 6, icon = ICON, args = iconArgs },
        level = { type = "group", name = L["Keystone level"], order = 7, icon = ICON, args = levelArgs },
        affixes = { type = "group", name = L["Affixes"], order = 8, icon = ICON, args = affixArgs },
    }
end
