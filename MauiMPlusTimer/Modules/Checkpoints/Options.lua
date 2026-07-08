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
                },
            },
            text = Addon:ElementTextOptions(self, ns.E.checkpointsText, 20, { color = true }),
        },
    }
end
