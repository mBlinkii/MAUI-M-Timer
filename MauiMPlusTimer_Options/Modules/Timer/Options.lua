-- Modules/Timer/Options.lua
-- AceConfig pages for the Timer blocks: the time text, and the bar (with
-- split-bar controls, dividers and the section countdown). Section fill colors
-- live on the central Colors page.

local _, ns = ...
local Addon = ns.Addon
local Timer = Addon:GetModule("Timer")

local ICON = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Modules\\timer"

local PREVIEW_PAD = 8
-- Fixed, so a size change never moves the page under a dragged slider; larger
-- text is scaled down to fit instead.
local PREVIEW_H = 96
-- Sample values: 20:50 of 30:00, best 25:00.
local SAMPLE_ELAPSED, SAMPLE_LIMIT, SAMPLE_BEST = 1250, 1800, 1500

-- The time text drawn by the HUD's own layout code, at the width and in the
-- alignment the timer block has right now.
local preview
local function drawPreview(width)
    if not preview then
        local frame = CreateFrame("Frame")
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.35)
        local block = CreateFrame("Frame", nil, frame)
        preview = {
            frame = frame, block = block,
            parts = {
                frame = block,
                main = Addon.Widgets:CreateText(block, ns.E.timerText),
                second = Addon.Widgets:CreateText(block, ns.E.timerText),
                best = Addon.Widgets:CreateText(block, ns.E.timerText),
            },
        }
    end
    local hudBlock = Timer.UI.frame
    local blockW = (hudBlock and hudBlock:GetWidth() or 0) > 1 and hudBlock:GetWidth() or Addon.MainWindow:GetWidth()

    Addon.Widgets:InvalidateStyle()
    local t = preview.parts
    preview.block:SetWidth(blockW)
    Timer.UI:ApplyTextFonts(t)
    Timer.UI:FillText(t, SAMPLE_ELAPSED, SAMPLE_LIMIT, SAMPLE_BEST)
    local h = Timer.UI:PlaceText(t, Addon.MainWindow:GetJustifyH("Timer"))
    preview.block:SetHeight(h)
    preview.block:SetScale(math.min(1, (width - PREVIEW_PAD * 2) / blockW, (PREVIEW_H - PREVIEW_PAD * 2) / h))
    preview.block:ClearAllPoints()
    preview.block:SetPoint("CENTER")
    preview.frame:SetSize(width, PREVIEW_H)
    return preview.frame, PREVIEW_H
end

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
    textOpts.args.maxSize = {
        type = "range", name = L["Max/remaining time size"], order = 5.5, min = 8, max = 64, step = 1,
        get = function()
            return Addon:GetElementSetting(ns.E.timerMax).fontSize
                or Addon.Widgets.ResolveStyle(ns.E.timerText).fontSize
        end,
        set = function(_, v)
            Addon:GetElementSetting(ns.E.timerMax).fontSize = v
            Addon.StyleRestyle(Timer)
        end,
    }
    textOpts.args.maxColor = Addon:ElementColorOption(self, ns.E.timerText, "maxColor", L["Max time color"], 14)

    local layoutLabels = {
        inline = L["Time and max"], elapsedRemaining = L["Time and remaining"],
        elapsed = L["Time only"], remaining = L["Remaining only"], remainingMax = L["Remaining and max"],
    }
    local positions = { left = L["Left"], right = L["Right"], above = L["Above"], below = L["Below"] }
    local function position(key, name, order)
        return {
            type = "select", name = name, order = order,
            values = positions, sorting = Timer.UI.PART_POSITIONS,
            get = function() return Timer:GetSettings()[key] or "right" end,
            set = function(_, v)
                Timer:GetSettings()[key] = v
                Addon.StyleRestyle(Timer)
            end,
        }
    end
    local layout = {
        type = "group", inline = true, name = L["Layout"], order = 5,
        args = {
            preview = {
                type = "description", order = 1, width = "full", name = "",
                arg = { preview = drawPreview },
            },
            textLayout = {
                type = "select", name = L["Layout"], order = 2,
                values = layoutLabels, sorting = Timer.UI.TEXT_LAYOUT_ORDER,
                get = function() return Timer:GetSettings().textLayout or "inline" end,
                set = function(_, v)
                    Timer:GetSettings().textLayout = v
                    Addon.StyleRestyle(Timer)
                end,
            },
            secondPos = position("secondPos", L["Max/remaining time position"], 3),
            bestPos = position("bestPos", L["Best time position"], 4),
        },
    }

    return {
        type = "group",
        name = L["Timer"],
        order = 10,
        icon = ICON,
        args = {
            enabled = Addon:BlockEnableOption("timer", 1),
            layout = layout,
            text = textOpts,
        },
    }
end

function Timer:GetOptionPages()
    local L = ns.L

    -- Bar: shared bar controls (no single color -- the fill is colored per section
    -- on the Colors page) plus split-bar layout, dividers and countdown subgroups.
    local barOpts = Addon:ElementBarOptions(self, ns.E.timerBar, 20, { noColor = true })
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
        timerbar = {
            type = "group",
            name = L["Timer bar"],
            order = 11,
            icon = ICON,
            args = {
                enabled = Addon:BlockEnableOption("timerbar", 1),
                bar = barOpts,
            },
        },
    }
end
