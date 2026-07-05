-- Modules/Deaths/Options.lua
-- AceConfig options group for the Deaths module.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Deaths = Addon:GetModule("Deaths")

function Deaths:GetOptions()
    local L = ns.L

    -- Text styling + a dedicated color for the time-penalty "(+mm:ss)" part.
    local textOpts = Addon:ElementTextOptions(self, ns.E.deathsText, 20, { color = true })
    textOpts.args.penaltyColor = Addon:ElementColorOption(
        self, ns.E.deathsText, "penaltyColor", L["Time penalty color"], 14, { 1, 0.38, 0.38, 1 })

    return {
        type = "group",
        name = L["Deaths"],
        order = 40,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\deaths",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            settings = {
                type = "group", inline = true, name = L["Settings"], order = 2,
                args = {
                    align = Addon:ModuleAlignOption(self, 1),
                },
            },
            symbols = {
                type = "group", inline = true, name = L["Symbols"], order = 10,
                args = {
                    icon = Addon:IconSelectOption(self, "death", "icon", L["Death icon"], 1),
                    nl = Addon:OptLine(2),
                    iconColor = Addon:IconColorOption(self, "iconColor", L["Death icon color"], 3),
                },
            },
            text = textOpts,
        },
    }
end
