-- Modules/Splits/UI.lua
-- One-line block with the live +/- delta versus the best run.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Splits = Addon:GetModule("Splits")

local UI = Addon:NewTextBlockUI({ name = "Splits", element = ns.E.splitsText, order = 50 })
Splits.UI = UI

-- Optional replacement for the "Run vs best" label.
local ICON_PATH = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Labels\\vsbest.tga"
local WHITE = { 1, 1, 1 }

-- delta in seconds, negative is ahead. nil hides the block.
function UI:Update(delta)
    self:Build()
    self:Remember(delta)
    -- showText only hides the line; recording continues for the other displays.
    if delta == nil or Splits:GetSettings().showText == false then
        self.frame:Hide()
    else
        self.frame:Show()
        -- Only the delta keeps the semantic green/red; the label follows the
        -- element text color.
        local settings = Splits:GetSettings()
        local label
        if settings.showLabel == false then
            label = nil
        elseif settings.labelIcon == true then
            label = Addon.Widgets:IconEscape(ICON_PATH, ICON_PATH, Addon.Widgets:IconSize(ns.E.splitsText),
                settings.labelIconColor or WHITE)
        else
            label = ns.L["Run vs best"] .. ":"
        end
        local deltaStr = Addon.Utils.FormatDelta(delta)
        self.text:SetText(label and (label .. " " .. deltaStr) or deltaStr)
    end
    Addon.MainWindow:Layout()
end
