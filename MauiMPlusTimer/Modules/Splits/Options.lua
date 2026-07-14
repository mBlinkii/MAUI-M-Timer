-- Modules/Splits/Options.lua
-- AceConfig options group for the Splits module: enable, the times manager, the
-- best-time display options (global: show + bracket style) and text styling.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Splits = Addon:GetModule("Splits")

-- Bracket presets for the best time. Each maps the dropdown choice to the
-- prefix/suffix characters stored in profile.ui (read by Widgets:FormatBest).
local BRACKETS = {
    none   = { "", "" },
    paren  = { "(", ")" },
    square = { "[", "]" },
    dash2  = { "--", "--" },
    dash1  = { "-", "-" },
    brace  = { "{", "}" },
}
local BRACKET_SORT = { "none", "paren", "square", "dash2", "dash1", "brace" }

-- Resolve the current prefix/suffix back to a preset key (legacy custom values
-- fall back to the parenthesis preset).
local function currentBracket()
    local ui = Addon.db.profile.ui
    local pre, suf = ui.bestPrefix or "(", ui.bestSuffix or ")"
    for key, pair in pairs(BRACKETS) do
        if pair[1] == pre and pair[2] == suf then return key end
    end
    return "paren"
end

function Splits:GetOptions()
    local L = ns.L

    local function showBestOff() return Addon.db.profile.ui.showBest ~= true end

    return {
        type = "group",
        name = L["Splits"],
        order = 50,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\splits",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            manage = {
                type = "execute", name = L["Manage times"], order = 2,
                func = function() Splits.Manager:Toggle() end,
            },
            settings = {
                type = "group", inline = true, name = L["Settings"], order = 3,
                args = {
                    align = Addon:ModuleAlignOption(self, 1),
                    showLabel = {
                        type = "toggle", name = L["Show label"], order = 1.4,
                        desc = L["Show the 'Run vs best' label before the delta. When off, only the +/- delta is shown."],
                        get = function() return Splits:GetSettings().showLabel ~= false end,
                        set = function(_, v)
                            Splits:GetSettings().showLabel = v
                            Addon.MainWindow:Refresh()
                        end,
                    },
                    labelIcon = {
                        type = "toggle", name = L["Icon instead of label"], order = 1.5,
                        desc = L["Replace the 'Run vs best' text with a compact icon."],
                        disabled = function() return Splits:GetSettings().showLabel == false end,
                        get = function() return Splits:GetSettings().labelIcon == true end,
                        set = function(_, v)
                            Splits:GetSettings().labelIcon = v
                            Addon.MainWindow:Refresh()
                        end,
                    },
                    labelIconColor = {
                        type = "color", name = L["Icon color"], order = 1.6,
                        disabled = function()
                            local s = Splits:GetSettings()
                            return s.showLabel == false or s.labelIcon ~= true
                        end,
                        get = function()
                            local c = Splits:GetSettings().labelIconColor or { 1, 1, 1 }
                            return c[1], c[2], c[3]
                        end,
                        set = function(_, r, g, b)
                            Splits:GetSettings().labelIconColor = { r, g, b }
                            Addon.MainWindow:Refresh()
                        end,
                    },
                    storeMode = {
                        type = "select", name = L["Storage mode"], order = 2,
                        desc = L["Keep only the best time per dungeon/level, or a full history."],
                        values = { best = L["Best time only"], all = L["Full history"] },
                        get = function() return Splits:GetSettings().storeMode or "best" end,
                        set = function(_, v)
                            Splits:GetSettings().storeMode = v
                            if v == "best" then Splits.Data.TrimToBest() end
                        end,
                    },
                },
            },
            best = {
                type = "group", inline = true, name = L["Best times"], order = 10,
                args = {
                    show = {
                        type = "toggle", name = L["Show best times"], order = 1,
                        desc = L["Show the stored best run's split times behind each element during a run."],
                        get = function() return Addon.db.profile.ui.showBest == true end,
                        set = function(_, v) Addon.db.profile.ui.showBest = v; Addon.MainWindow:Refresh() end,
                    },
                    bracket = {
                        type = "select", name = L["Best time bracket"], order = 2,
                        disabled = showBestOff,
                        values = {
                            none = L["No bracket"], paren = "( )", square = "[ ]",
                            dash2 = "--", dash1 = "-", brace = "{ }",
                        },
                        sorting = BRACKET_SORT,
                        get = currentBracket,
                        set = function(_, v)
                            local pair = BRACKETS[v] or BRACKETS.paren
                            Addon.db.profile.ui.bestPrefix = pair[1]
                            Addon.db.profile.ui.bestSuffix = pair[2]
                            Addon.MainWindow:Refresh()
                        end,
                    },
                },
            },
            text = Addon:ElementTextOptions(self, ns.E.splitsText, 20, { color = true }),
        },
    }
end
