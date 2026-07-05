-- Modules/Dungeon/Options.lua
-- AceConfig options group for the Dungeon module.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Dungeon = Addon:GetModule("Dungeon")

function Dungeon:GetOptions()
    local L = ns.L

    -- Affixes group: the show toggle plus the shared text-style controls merged
    -- in flat (orders 11+) so the toggle sits above its own styling.
    local affixesArgs = {
        show = {
            type = "toggle", name = L["Show affixes"], order = 1,
            get = function() return Dungeon:GetSettings().showAffixes ~= false end,
            set = function(_, v) Dungeon:GetSettings().showAffixes = v; Addon.StyleRestyle(Dungeon) end,
        },
        nl = Addon:OptLine(2),
    }
    for k, v in pairs(Addon:ElementTextArgs(self, ns.E.dungeonAffixes, 10, { color = true })) do
        affixesArgs[k] = v
    end

    local options = {
        type = "group",
        name = L["Dungeon"],
        order = 5,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\dungeon",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            settings = {
                type = "group", inline = true, name = L["Settings"], order = 2,
                args = {
                    align = Addon:ModuleAlignOption(self, 1),
                },
            },
            icon = {
                type = "group", inline = true, name = L["Dungeon icon"], order = 10,
                args = {
                    show = {
                        type = "toggle", name = L["Show dungeon icon"], order = 1,
                        get = function() return Dungeon:GetSettings().showIcon == true end,
                        set = function(_, v) Dungeon:GetSettings().showIcon = v; Addon.StyleRestyle(Dungeon) end,
                    },
                    nl = Addon:OptLine(2),
                    position = {
                        type = "select", name = L["Icon position"], order = 3,
                        values = { left = L["Left"], right = L["Right"] },
                        sorting = { "left", "right" },
                        disabled = function() return Dungeon:GetSettings().showIcon ~= true end,
                        get = function() return Dungeon:GetSettings().iconPos == "right" and "right" or "left" end,
                        set = function(_, v) Dungeon:GetSettings().iconPos = v; Addon.StyleRestyle(Dungeon) end,
                    },
                    size = {
                        type = "range", name = L["Icon size"], order = 4, min = 8, max = 64, step = 1,
                        disabled = function() return Dungeon:GetSettings().showIcon ~= true end,
                        get = function() return Dungeon:GetSettings().iconSize or 20 end,
                        set = function(_, v) Dungeon:GetSettings().iconSize = v; Addon.StyleRestyle(Dungeon) end,
                    },
                },
            },
            name = Addon:ElementTextOptions(self, ns.E.dungeonName, 20, { color = true, name = L["Dungeon name"] }),
            affixes = {
                type = "group", inline = true, name = L["Affixes"], order = 30, args = affixesArgs,
            },
            level = {
                type = "group", inline = true, name = L["Keystone level"], order = 40,
                args = {
                    show = {
                        type = "toggle", name = L["Show keystone level"], order = 1,
                        desc = L["Show the keystone level next to the dungeon name."],
                        get = function() return Dungeon:GetSettings().showLevel ~= false end,
                        set = function(_, v) Dungeon:GetSettings().showLevel = v; Addon.StyleRestyle(Dungeon) end,
                    },
                    nl = Addon:OptLine(2),
                    position = {
                        type = "select", name = L["Level position"], order = 3,
                        values = { left = L["Left of name"], right = L["Right of name"] },
                        sorting = { "left", "right" },
                        disabled = function() return Dungeon:GetSettings().showLevel == false end,
                        get = function() return Dungeon:GetSettings().levelPos == "right" and "right" or "left" end,
                        set = function(_, v) Dungeon:GetSettings().levelPos = v; Addon.StyleRestyle(Dungeon) end,
                    },
                    separator = {
                        type = "toggle", name = L["Separator line"], order = 4,
                        desc = L["Show a separator between the dungeon name and the level."],
                        disabled = function() return Dungeon:GetSettings().showLevel == false end,
                        get = function() return Dungeon:GetSettings().levelSep ~= false end,
                        set = function(_, v) Dungeon:GetSettings().levelSep = v; Addon.StyleRestyle(Dungeon) end,
                    },
                    color = {
                        type = "toggle", name = L["Color by level rarity"], order = 5,
                        desc = L["Color the keystone level with Blizzard's rarity color."],
                        disabled = function() return Dungeon:GetSettings().showLevel == false end,
                        get = function() return Dungeon:GetSettings().levelColor == true end,
                        set = function(_, v) Dungeon:GetSettings().levelColor = v; Addon.StyleRestyle(Dungeon) end,
                    },
                },
            },
        },
    }

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
