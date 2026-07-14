-- Modules/Splits/UI.lua
-- HUD block showing the live +/- delta versus the best run (green = ahead,
-- red = behind). A single-line text block: Build/Restyle/Show/Hide come from the
-- shared text-block base, so this file only defines the content (Update).

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Splits = Addon:GetModule("Splits")

local UI = Addon:NewTextBlockUI({ name = "Splits", element = ns.E.splitsText, order = 50 })
Splits.UI = UI

-- Inline icon that can replace the "Run vs best" label (module option
-- "labelIcon"); it scales with the font and is tinted via "labelIconColor".
local ICON_PATH = "Interface\\AddOns\\MauiMPlusTimer\\Assets\\Icons\\Labels\\vsbest.tga"

-- Overall run standing vs best (delta in seconds, negative = ahead). When nil
-- (no best time available yet) the block hides itself entirely.
function UI:Update(delta)
    self:Build()
    -- The whole line can be hidden (module option / element order "showText")
    -- while the module keeps recording best times for the other displays.
    if delta == nil or Splits:GetSettings().showText == false then
        self.frame:Hide()
    else
        self.frame:Show()
        -- The label follows the configurable text color; only the +/- delta
        -- keeps its semantic green/red coloring. The label can be replaced by a
        -- compact icon (labelIcon) or hidden entirely (showLabel = false), in
        -- which case only the delta is shown.
        local settings = Splits:GetSettings()
        local label
        if settings.showLabel == false then
            label = nil
        elseif settings.labelIcon == true then
            label = Addon.Utils.IconTag(ICON_PATH, settings.labelIconColor)
        else
            label = ns.L["Run vs best"] .. ":"
        end
        local deltaStr = Addon.Utils.FormatDelta(delta)
        self.text:SetText(label and (label .. " " .. deltaStr) or deltaStr)
    end
    Addon.MainWindow:Layout()
end
