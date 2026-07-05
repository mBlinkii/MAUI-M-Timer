-- Modules/EnemyForces/Options.lua
-- AceConfig options group for the Enemy Forces module.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Forces = Addon:GetModule("EnemyForces")

function Forces:GetOptions()
    local L = ns.L

    -- Text styling plus a dedicated color for the remaining-count number.
    local textOpts = Addon:ElementTextOptions(self, ns.E.forcesText, 20, { color = true })
    textOpts.args.countColor = Addon:ElementColorOption(
        self, ns.E.forcesText, "countColor", L["Remaining count color"], 14, { 0.6, 0.6, 0.6, 1 })

    -- Bar styling plus a nested Checkpoint markers group.
    local barOpts = Addon:ElementBarOptions(self, ns.E.forcesBar, 30)
    barOpts.args.markers = {
        type = "group", inline = true, name = L["Checkpoint markers"], order = 30,
        args = {
            show = {
                type = "toggle", name = L["Show checkpoint markers"], order = 1,
                desc = L["Mark the checkpoint target percentages on the bar."],
                get = function() return Forces:GetSettings().showMarkers == true end,
                set = function(_, v) Forces:GetSettings().showMarkers = v; Addon.StyleRestyle(Forces) end,
            },
            nl = Addon:OptLine(2),
            color = Addon:ElementColorOption(self, ns.E.forcesBar, "markerColor", L["Marker color"], 3),
        },
    }

    return {
        type = "group",
        name = L["Enemy Forces"],
        order = 20,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\enemyforces",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            settings = {
                type = "group", inline = true, name = L["Settings"], order = 2,
                args = {
                    align = Addon:ModuleAlignOption(self, 1),
                    position = {
                        type = "select", name = L["Bar position"], order = 2,
                        values = { top = L["Above objectives"], bottom = L["Below objectives"] },
                        sorting = { "top", "bottom" },
                        get = function() return Forces:GetSettings().position == "bottom" and "bottom" or "top" end,
                        set = function(_, v) Forces:GetSettings().position = v; Forces.UI:UpdatePosition() end,
                    },
                    showCount = {
                        type = "toggle", name = L["Show remaining count"], order = 3,
                        desc = L["Show the remaining absolute mob count next to the percentage."],
                        get = function() return Forces:GetSettings().showCount ~= false end,
                        set = function(_, v) Forces:GetSettings().showCount = v; Addon.StyleRestyle(Forces) end,
                    },
                },
            },
            text = textOpts,
            bar = barOpts,
        },
    }
end
