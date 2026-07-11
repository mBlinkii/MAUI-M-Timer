-- Modules/Checkpoints/Options.lua
-- AceConfig options group for the Checkpoints module.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Checkpoints = Addon:GetModule("Checkpoints")

function Checkpoints:GetOptions()
    local L = ns.L
    return {
        type = "group",
        name = L["Checkpoints"],
        order = 60,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\checkpoints",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            edit = {
                type = "execute", name = L["Edit checkpoints"], order = 2,
                func = function() Checkpoints.Editor:Toggle() end,
            },
            loadPreset = {
                type = "execute", name = L["Load default checkpoints"], order = 3,
                desc = L["Load the author's curated checkpoint targets. Matching dungeons will be overwritten."],
                confirm = function() return L["Overwrite matching dungeons with the built-in checkpoints?"] end,
                func = function()
                    local ok, count = Checkpoints.Data.ImportAuthorPreset()
                    if ok then
                        Addon:Info(L["Imported checkpoints for %d dungeon(s)."], count or 0)
                        if Checkpoints.Editor then Checkpoints.Editor:Refresh() end
                    end
                end,
            },
            settings = {
                type = "group", inline = true, name = L["Settings"], order = 4,
                args = {
                    align = Addon:ModuleAlignOption(self, 1),
                    labelIcons = {
                        type = "toggle", name = L["Icons instead of labels"], order = 2,
                        desc = L["Replace the 'Boss' and 'PoNR' texts with compact icons."],
                        get = function() return Checkpoints:GetSettings().labelIcons == true end,
                        set = function(_, v)
                            Checkpoints:GetSettings().labelIcons = v
                            Addon.MainWindow:Refresh()
                        end,
                    },
                    bossIconColor = {
                        type = "color", name = L["Boss icon color"], order = 3,
                        disabled = function() return Checkpoints:GetSettings().labelIcons ~= true end,
                        get = function()
                            local c = Checkpoints:GetSettings().bossIconColor or { 1, 1, 1 }
                            return c[1], c[2], c[3]
                        end,
                        set = function(_, r, g, b)
                            Checkpoints:GetSettings().bossIconColor = { r, g, b }
                            Addon.MainWindow:Refresh()
                        end,
                    },
                    ponrIconColor = {
                        type = "color", name = L["PoNR icon color"], order = 4,
                        disabled = function() return Checkpoints:GetSettings().labelIcons ~= true end,
                        get = function()
                            local c = Checkpoints:GetSettings().ponrIconColor or { 1, 1, 1 }
                            return c[1], c[2], c[3]
                        end,
                        set = function(_, r, g, b)
                            Checkpoints:GetSettings().ponrIconColor = { r, g, b }
                            Addon.MainWindow:Refresh()
                        end,
                    },
                },
            },
            text = Addon:ElementTextOptions(self, ns.E.checkpointsText, 20, { color = true }),
        },
    }
end
