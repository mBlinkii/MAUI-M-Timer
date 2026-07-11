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
    if delta == nil then
        self.frame:Hide()
    else
        self.frame:Show()
        -- The label follows the configurable text color; only the +/- delta
        -- keeps its semantic green/red coloring. Optionally the label text is
        -- replaced by a compact icon.
        local settings = Splits:GetSettings()
        local label = settings.labelIcon == true
            and Addon.Utils.IconTag(ICON_PATH, settings.labelIconColor)
            or (ns.L["Run vs best"] .. ":")
        self.text:SetText(label .. " " .. Addon.Utils.FormatDelta(delta))
    end
    Addon.MainWindow:Layout()
end
