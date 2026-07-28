-- Modules/Deaths/UI.lua
-- One-line block with the death count and the time penalty.

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Deaths = Addon:GetModule("Deaths")

local UI = Addon:NewTextBlockUI({ name = "Deaths", element = ns.E.deathsText, order = 40 })
Deaths.UI = UI

local DEFAULT_SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

-- A tint forces the long escape form, which needs an explicit size; without one
-- 0 keeps the icon auto-sized to the line height.
local function skull()
    local s = Deaths:GetSettings()
    local size = s.iconColor and math.floor(Addon.Widgets.ResolveStyle(ns.E.deathsText).fontSize or 16) or 0
    return Addon.Widgets:IconEscape(s.icon, DEFAULT_SKULL, size, s.iconColor)
end

function UI:Update(count, timeLost)
    if not self.frame then return end
    count = count or 0
    timeLost = timeLost or 0
    if count <= 0 then
        self.text:SetText(skull() .. " 0")
    else
        local penHex = Addon.Utils.ColorHex(
            Addon:GetElementSetting(ns.E.deathsText).penaltyColor or { 1, 0.38, 0.38, 1 })
        self.text:SetText(string.format(
            "%s %d  |c%s(+%s)|r",
            skull(), count, penHex, Addon.Utils.FormatTime(timeLost)))
    end
end
