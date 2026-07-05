-- Modules/Timer/Options.lua
-- AceConfig options for the Timer module: enable, alignment, the time text and
-- the bar (with split-bar controls, dividers and the section countdown). Section
-- fill colors live on the central Colors page.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Timer = Addon:GetModule("Timer")

function Timer:GetOptions()
    local L = ns.L

    -- Time text: the shared text controls plus the best-time size (next to the
    -- font size) and the "/ max" reference color (next to the text color).
    local textOpts = Addon:ElementTextOptions(self, ns.E.timerText, 10, { color = true, name = L["Time text"] })
    textOpts.args.bestSize = {
        type = "range", name = L["Best time size"], order = 5, min = 8, max = 64, step = 1,
        get = function()
            return Addon:GetElementSetting(ns.E.timerBest).fontSize
                or Addon.Widgets.ResolveStyle(ns.E.timerText).fontSize
        end,
        set = function(_, v)
            Addon:GetElementSetting(ns.E.timerBest).fontSize = v
            Addon.StyleRestyle(Timer)
        end,
    }
    textOpts.args.maxColor = Addon:ElementColorOption(self, ns.E.timerText, "maxColor", L["Max time color"], 14)

    -- Bar: shared bar controls (no single color -- the fill is colored per section
    -- on the Colors page) plus split-bar layout, dividers and countdown subgroups.
    local barOpts = Addon:ElementBarOptions(self, ns.E.timerBar, 20, { noColor = true })
    barOpts.args.barTextGap = {
        type = "range", name = L["Bar-text spacing"], order = 6,
        desc = L["Vertical space between the time text and the bar."],
        min = 0, max = 40, step = 1,
        get = function() return Timer:GetSettings().barTextGap or 0 end,
        set = function(_, v) Timer:GetSettings().barTextGap = v; Addon.StyleRestyle(Timer) end,
    }
    barOpts.args.nlBarTextGap = Addon:OptLine(6.5)
    barOpts.args.splitBar = {
        type = "toggle", name = L["Split bar into three"], order = 7,
        desc = L["Show three segments (+3 large, +2 and +1 small) instead of one bar."],
        get = function() return Timer:GetSettings().splitBar == true end,
        set = function(_, v) Timer:GetSettings().splitBar = v; Addon.StyleRestyle(Timer) end,
    }
    barOpts.args.nlSplit = Addon:OptLine(8)
    barOpts.args.splitGap = {
        type = "range", name = L["Segment gap"], order = 9, min = 0, max = 20, step = 1,
        disabled = function() return Timer:GetSettings().splitBar ~= true end,
        get = function() return Timer:GetSettings().splitGap or 2 end,
        set = function(_, v) Timer:GetSettings().splitGap = v; Addon.StyleRestyle(Timer) end,
    }
    barOpts.args.dividers = {
        type = "group", inline = true, name = L["Dividers"], order = 30,
        disabled = function() return Timer:GetSettings().splitBar == true end,
        args = {
            color = Addon:ElementColorOption(self, ns.E.timerBar, "sectionDividerColor", L["Divider color"], 1),
            width = {
                type = "range", name = L["Divider width"], order = 2, min = 1, max = 6, step = 1,
                get = function() return Addon:GetElementSetting(ns.E.timerBar).dividerWidth or 1 end,
                set = function(_, v)
                    Addon:GetElementSetting(ns.E.timerBar).dividerWidth = v
                    Addon.StyleRestyle(Timer)
                end,
            },
        },
    }

    -- Countdown label: the two countdown toggles + position, then the shared text
    -- controls (merged flat, orders 11+) for the label's own font/offset/color.
    local countdownArgs = {
        sectionCountdown = {
            type = "toggle", name = L["Section countdown"], order = 1,
            desc = L["Show the remaining time until the current +3/+2 threshold on its marker."],
            get = function() return Timer:GetSettings().sectionCountdown == true end,
            set = function(_, v) Timer:GetSettings().sectionCountdown = v; Addon.StyleRestyle(Timer) end,
        },
        sectionCountdownAll = {
            type = "toggle", name = L["All section countdowns"], order = 2,
            desc = L["Show a countdown to every section threshold (+3/+2/+1) at once, not just the next."],
            disabled = function() return Timer:GetSettings().sectionCountdown ~= true end,
            get = function() return Timer:GetSettings().sectionCountdownAll == true end,
            set = function(_, v) Timer:GetSettings().sectionCountdownAll = v; Addon.StyleRestyle(Timer) end,
        },
        position = {
            type = "select", name = L["Position"], order = 3,
            values = {
                above    = L["Above"],
                below    = L["Below"],
                left     = L["Left of divider"],
                right    = L["Right of divider"],
                barLeft  = L["In bar, left of divider"],
                barRight = L["In bar, right of divider"],
            },
            sorting = { "above", "below", "left", "right", "barLeft", "barRight" },
            get = function() return Addon:GetElementSetting(ns.E.timerSection).countdownPos or "above" end,
            set = function(_, v)
                Addon:GetElementSetting(ns.E.timerSection).countdownPos = v
                Addon.StyleRestyle(Timer)
            end,
        },
        nl = Addon:OptLine(4),
    }
    for k, v in pairs(Addon:ElementTextArgs(self, ns.E.timerSection, 10, { color = true })) do
        countdownArgs[k] = v
    end
    barOpts.args.countdown = {
        type = "group", inline = true, name = L["Countdown label"], order = 40, args = countdownArgs,
    }

    return {
        type = "group",
        name = L["Timer"],
        order = 10,
        icon = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\timer",
        args = {
            enabled = Addon:ModuleEnableOption(self, 1),
            settings = {
                type = "group", inline = true, name = L["Settings"], order = 2,
                args = {
                    align = Addon:ModuleAlignOption(self, 1),
                },
            },
            text = textOpts,
            bar = barOpts,
        },
    }
end
